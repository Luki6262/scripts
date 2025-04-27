local httpService = game:GetService('HttpService')

local SaveManager = {} do
    SaveManager.Folder = 'LinoriaLibSettings'
    SaveManager.Ignore = {}
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object) 
                return { type = 'Toggle', idx = idx, value = object.Value } 
            end,
            Load = function(idx, data)
                if Toggles[idx] then 
                    Toggles[idx]:SetValue(data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = 'Slider', idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                if Options[idx] then 
                    Options[idx]:SetValue(data.value)
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
            end,
            Load = function(idx, data)
                if Options[idx] then 
                    Options[idx]:SetValue(data.value)
                end
            end,
        },
        ColorPicker = {
            Save = function(idx, object)
                return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
            end,
            Load = function(idx, data)
                if Options[idx] then 
                    Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
                end
            end,
        },
        KeyPicker = {
            Save = function(idx, object)
                return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
            end,
            Load = function(idx, data)
                if Options[idx] then 
                    Options[idx]:SetValue({ data.key, data.mode })
                end
            end,
        },

        Input = {
            Save = function(idx, object)
                return { type = 'Input', idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                if Options[idx] and type(data.text) == 'string' then
                    Options[idx]:SetValue(data.text)
                end
            end,
        },
    }

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder;
        self:BuildFolderTree()
    end

    function SaveManager:Save(name)
        if (not name) then
            return false, 'no config file is selected'
        end

        local fullPath = self.Folder .. '/settings/' .. name .. '.json'

        local data = {
            objects = {}
        }

        for idx, toggle in next, Toggles do
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
        end

        for idx, option in next, Options do
            if not self.Parser[option.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
        end	

        local success, encoded = pcall(httpService.JSONEncode, httpService, data)
        if not success then
            return false, 'failed to encode data'
        end

        writefile(fullPath, encoded)
        return true, encoded
    end

    function SaveManager:Load(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        
        local file = self.Folder .. '/settings/' .. name .. '.json'
        if not isfile(file) then return false, 'invalid file' end

        local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
        if not success then return false, 'decode error' end

        for _, option in next, decoded.objects do
            if self.Parser[option.type] then
                task.spawn(function() self.Parser[option.type].Load(option.idx, option) end) -- task.spawn() so the config loading wont get stuck.
            end
        end

        return true
    end
    
    function SaveManager:LoadFromString(jsonString)
        if not jsonString or jsonString == "" then
            return false, 'empty config string'
        end
        
        local success, decoded = pcall(httpService.JSONDecode, httpService, jsonString)
        if not success then return false, 'decode error' end
        
        for _, option in next, decoded.objects do
            if self.Parser[option.type] then
                task.spawn(function() self.Parser[option.type].Load(option.idx, option) end)
            end
        end
        
        return true
    end
    
    function SaveManager:GetConfigAsString()
        local data = {
            objects = {}
        }

        for idx, toggle in next, Toggles do
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
        end

        for idx, option in next, Options do
            if not self.Parser[option.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
        end	

        local success, encoded = pcall(httpService.JSONEncode, httpService, data)
        if not success then
            return false, 'failed to encode data'
        end

        return true, encoded
    end

    function SaveManager:DisableAllToggles()
        for idx, toggle in next, Toggles do
            if self.Ignore[idx] then continue end
            
            task.spawn(function()
                toggle:SetValue(false)
            end)
        end
        return true
    end

    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({ 
            "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
            "ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
        })
    end

    function SaveManager:BuildFolderTree()
        local paths = {
            self.Folder,
            self.Folder .. '/themes',
            self.Folder .. '/settings'
        }

        for i = 1, #paths do
            local str = paths[i]
            if not isfolder(str) then
                makefolder(str)
            end
        end
    end

    function SaveManager:RefreshConfigList()
        local list = listfiles(self.Folder .. '/settings')

        local out = {}
        for i = 1, #list do
            local file = list[i]
            if file:sub(-5) == '.json' then
                -- i hate this but it has to be done ...

                local pos = file:find('.json', 1, true)
                local start = pos

                local char = file:sub(pos, pos)
                while char ~= '/' and char ~= '\\' and char ~= '' do
                    pos = pos - 1
                    char = file:sub(pos, pos)
                end

                if char == '/' or char == '\\' then
                    table.insert(out, file:sub(pos + 1, start - 1))
                end
            end
        end
        
        return out
    end

    function SaveManager:SetLibrary(library)
        self.Library = library
    end

    function SaveManager:LoadAutoloadConfig()
        if isfile(self.Folder .. '/settings/autoload.txt') then
            local name = readfile(self.Folder .. '/settings/autoload.txt')

            local success, err = self:Load(name)
            if not success then
                return self.Library:Notify('Failed to load autoload config: ' .. err)
            end

            self.Library:Notify(string.format('Auto loaded config %q', name))
        end
    end

    function SaveManager:SaveTheme(name)
        if (not name) then
            return false, 'no theme name is provided'
        end
        
        local fullPath = self.Folder .. '/themes/' .. name .. '.json'
        
        -- Get current theme data
        local theme = {}
        if self.Library and self.Library.CurrentTheme then
            theme.themeName = self.Library.CurrentTheme
        end
        
        -- If using custom theme colors, save those too
        if self.Library and self.Library.CustomTheme then
            theme.customColors = {}
            for key, color in pairs(self.Library.CustomTheme) do
                if typeof(color) == "Color3" then
                    theme.customColors[key] = {
                        R = color.R,
                        G = color.G,
                        B = color.B
                    }
                elseif type(color) == "number" then
                    theme.customColors[key] = color
                end
            end
        end
        
        local success, encoded = pcall(httpService.JSONEncode, httpService, theme)
        if not success then
            return false, 'failed to encode theme data'
        end
        
        writefile(fullPath, encoded)
        return true, encoded
    end
    
    -- Add a function to load a saved theme
    function SaveManager:LoadTheme(name)
        if (not name) then
            return false, 'no theme name is provided'
        end
        
        local file = self.Folder .. '/themes/' .. name .. '.json'
        if not isfile(file) then return false, 'invalid theme file' end
        
        local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
        if not success then return false, 'theme decode error' end
        
        -- Apply the theme
        if decoded.themeName and self.Library then
            self.Library:SetTheme(decoded.themeName)
        end
        
        -- Apply custom colors if they exist
        if decoded.customColors and self.Library then
            local customTheme = {}
            for key, colorData in pairs(decoded.customColors) do
                if colorData.R then
                    customTheme[key] = Color3.new(colorData.R, colorData.G, colorData.B)
                elseif type(colorData) == "number" then
                    customTheme[key] = colorData
                end
            end
            
            self.Library:SetTheme(customTheme)
        end
        
        return true
    end
    
    function SaveManager:RefreshThemeList()
        local list = listfiles(self.Folder .. '/themes')
        
        local out = {}
        for i = 1, #list do
            local file = list[i]
            if file:sub(-5) == '.json' then
                local pos = file:find('.json', 1, true)
                local start = pos
                
                local char = file:sub(pos, pos)
                while char ~= '/' and char ~= '\\' and char ~= '' do
                    pos = pos - 1
                    char = file:sub(pos, pos)
                end
                
                if char == '/' or char == '\\' then
                    table.insert(out, file:sub(pos + 1, start - 1))
                end
            end
        end
        
        return out
    end


    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, 'Must set SaveManager.Library')

        local section = tab:AddRightGroupbox('Configuration')

        section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
        section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

        section:AddDivider()

        section:AddButton('Create config', function()
            local name = Options.SaveManager_ConfigName.Value

            if name:gsub(' ', '') == '' then 
                return self.Library:Notify('Invalid config name (empty)', 2)
            end

            local success, err = self:Save(name)
            if not success then
                return self.Library:Notify('Failed to save config: ' .. err)
            end

            self.Library:Notify(string.format('Created config %q', name))

            Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            Options.SaveManager_ConfigList:SetValue(nil)
        end):AddButton('Load config', function()
            local name = Options.SaveManager_ConfigList.Value

            local success, err = self:Load(name)
            if not success then
                return self.Library:Notify('Failed to load config: ' .. err)
            end

            self.Library:Notify(string.format('Loaded config %q', name))
        end)
        
        section:AddButton('Delete config', function()
            local name = Options.SaveManager_ConfigList.Value
            
            if not name then
                return self.Library:Notify('No config selected')
            end
            
            local file = self.Folder .. '/settings/' .. name .. '.json'
            if not isfile(file) then 
                return self.Library:Notify('Invalid config file')
            end
            
            delfile(file)
            self.Library:Notify(string.format('Deleted config %q', name))
            
            if isfile(self.Folder .. '/settings/autoload.txt') then
                local autoloadName = readfile(self.Folder .. '/settings/autoload.txt')
                if autoloadName == name then
                    delfile(self.Folder .. '/settings/autoload.txt')
                    SaveManager.AutoloadLabel:SetText('Current autoload config: none')
                end
            end
            
            -- Refresh the config list
            Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddButton('Overwrite config', function()
            local name = Options.SaveManager_ConfigList.Value

            local success, err = self:Save(name)
            if not success then
                return self.Library:Notify('Failed to overwrite config: ' .. err)
            end

            self.Library:Notify(string.format('Overwrote config %q', name))
        end)

        section:AddButton('Refresh list', function()
            Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddButton('Set as autoload', function()
            local name = Options.SaveManager_ConfigList.Value
            writefile(self.Folder .. '/settings/autoload.txt', name)
            SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
            self.Library:Notify(string.format('Set %q to auto load', name))
        end):AddButton('Remove autoload', function()
            if isfile(self.Folder .. '/settings/autoload.txt') then
                delfile(self.Folder .. '/settings/autoload.txt')
                SaveManager.AutoloadLabel:SetText('Current autoload config: none')
                self.Library:Notify('Removed autoload config')
            else
                self.Library:Notify('No autoload config is set')
            end
        end)



        SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

        if isfile(self.Folder .. '/settings/autoload.txt') then
            local name = readfile(self.Folder .. '/settings/autoload.txt')
            SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
        end
        
        section:AddDivider()
        
        section:AddButton('Copy settings', function()
            local success, encoded = self:GetConfigAsString()
            if not success then
                return self.Library:Notify('Failed to copy settings: ' .. encoded)
            end
            
            setclipboard(encoded)
            self.Library:Notify('Copied settings to clipboard')
        end)
        
        section:AddLabel('Paste config JSON below:')
        section:AddInput('SaveManager_ConfigPaste', {
            Text = 'Paste config here and press Enter',
            Placeholder = 'Paste JSON config here...',
            Finished = true,
            Callback = function(value)
                if value and value ~= "" then
                    local success, err = self:LoadFromString(value)
                    if not success then
                        return self.Library:Notify('Failed to load pasted config: ' .. err)
                    end
                    
                    self.Library:Notify('Successfully loaded pasted config')
                    Options.SaveManager_ConfigPaste:SetValue('')
                end
            end
        })

        SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName', 'SaveManager_ConfigPaste' })
    end

    function SaveManager:BuildThemeSection(tab)
        assert(self.Library, 'Must set SaveManager.Library')
        
        local section = tab:AddRightGroupbox('Theme Settings')
        
        local builtInThemes = {}
        for themeName, _ in pairs(self.Library:GetThemes()) do
            table.insert(builtInThemes, themeName)
        end
        
        section:AddDropdown('ThemeManager_ThemeList', {
            Text = 'Built-in Themes',
            Values = builtInThemes,
            Default = self.Library.CurrentTheme,
            Callback = function(Value)
                self.Library:SetTheme(Value)
            end
        })
        
        section:AddDivider()
        
        -- Add input for custom theme name
        section:AddInput('ThemeManager_CustomThemeName', {
            Text = 'Custom theme name',
            Placeholder = 'Enter name here...'
        })
        
        -- Add dropdown for saved custom themes
        section:AddDropdown('ThemeManager_CustomThemeList', {
            Text = 'Custom Themes',
            Values = self:RefreshThemeList(),
            AllowNull = true,
            Callback = function(Value)
                if Value then
                    self:LoadTheme(Value)
                end
            end
        })
        
        section:AddButton('Save Current Theme', function()
            local name = Options.ThemeManager_CustomThemeName.Value
            
            if name:gsub(' ', '') == '' then 
                return self.Library:Notify('Invalid theme name (empty)', 2)
            end
            
            local success, err = self:SaveTheme(name)
            if not success then
                return self.Library:Notify('Failed to save theme: ' .. err)
            end
            
            self.Library:Notify(string.format('Saved theme %q', name))
            
            Options.ThemeManager_CustomThemeList:SetValues(self:RefreshThemeList())
            Options.ThemeManager_CustomThemeList:SetValue(nil)
        end)
        
        section:AddButton('Delete Theme', function()
            local name = Options.ThemeManager_CustomThemeList.Value
            
            if not name then
                return self.Library:Notify('No theme selected')
            end
            
            local file = self.Folder .. '/themes/' .. name .. '.json'
            if not isfile(file) then 
                return self.Library:Notify('Invalid theme file')
            end
            
            delfile(file)
            self.Library:Notify(string.format('Deleted theme %q', name))
            
            -- If this was the autoload theme, remove the autoload setting
            if isfile(self.Folder .. '/themes/autoload.txt') then
                local autoloadName = readfile(self.Folder .. '/themes/autoload.txt')
                if autoloadName == name then
                    delfile(self.Folder .. '/themes/autoload.txt')
                    SaveManager.ThemeAutoloadLabel:SetText('Current autoload theme: none')
                end
            end
            
            Options.ThemeManager_CustomThemeList:SetValues(self:RefreshThemeList())
            Options.ThemeManager_CustomThemeList:SetValue(nil)
        end)
        
        section:AddButton('Set as autoload theme', function()
            local name = Options.ThemeManager_CustomThemeList.Value
            
            if not name then
                return self.Library:Notify('No theme selected')
            end
            
            writefile(self.Folder .. '/themes/autoload.txt', name)
            SaveManager.ThemeAutoloadLabel:SetText('Current autoload theme: ' .. name)
            self.Library:Notify(string.format('Set %q as autoload theme', name))
        end):AddButton('Remove autoload theme', function()
            if isfile(self.Folder .. '/themes/autoload.txt') then
                delfile(self.Folder .. '/themes/autoload.txt')
                SaveManager.ThemeAutoloadLabel:SetText('Current autoload theme: none')
                self.Library:Notify('Removed autoload theme')
            else
                self.Library:Notify('No autoload theme is set')
            end
        end)
        
        SaveManager.ThemeAutoloadLabel = section:AddLabel('Current autoload theme: none', true)
        
        if isfile(self.Folder .. '/themes/autoload.txt') then
            local name = readfile(self.Folder .. '/themes/autoload.txt')
            SaveManager.ThemeAutoloadLabel:SetText('Current autoload theme: ' .. name)
        end
        
        section:AddButton('Refresh List', function()
            Options.ThemeManager_CustomThemeList:SetValues(self:RefreshThemeList())
            Options.ThemeManager_CustomThemeList:SetValue(nil)
        end)
    end

    function SaveManager:RefreshThemeList()
        local list = listfiles(self.Folder .. '/themes')
        
        local out = {}
        for i = 1, #list do
            local file = list[i]
            if file:sub(-5) == '.json' then
                local pos = file:find('.json', 1, true)
                local start = pos
                
                local char = file:sub(pos, pos)
                while char ~= '/' and char ~= '\\' and char ~= '' do
                    pos = pos - 1
                    char = file:sub(pos, pos)
                end
                
                if char == '/' or char == '\\' then
                    table.insert(out, file:sub(pos + 1, start - 1))
                end
            end
        end
        
        return out
    end

    SaveManager:BuildFolderTree()
end

return SaveManager
