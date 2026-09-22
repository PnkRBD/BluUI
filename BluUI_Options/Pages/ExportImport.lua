local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals, Toast = BUILib.Controls, BUILib.Layout, BUILib.Modals, BUILib.Toast
local PageKit = BUILib.PageKit
local Widget = BUILib.Widget

local DEFAULT_NAME = 'Default'
local SEPARATOR = '  -  '
local MENU_WIDTH = 260

local function Trim(text)
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function ToastOptions()
    return {
        style = 'bar',
        position = 'bottom',
        parent = BUI.PageEngine.window.frame,
    }
end

local function Notify(title, message)
    Toast.Success(title, message, ToastOptions())
end

local function Warn(title, message)
    Toast.Error(title, message, ToastOptions())
end

local function ReclaimScratch()
    collectgarbage('collect')
end

local function ProfileUsage(profileName)
    local myKey = BUI.db.keys.char
    local count, isMine = 0, false
    for charKey, value in pairs(BUI.db.sv.profileKeys) do
        if value == profileName then
            count = count + 1
            if charKey == myKey then isMine = true end
        end
    end
    return count, isMine
end

local function SpecsUsing(profileName)
    local SpecProfiles = BUI.SpecProfiles
    if not SpecProfiles.IsEnabled() then return nil end
    local names
    for _, spec in ipairs(SpecProfiles.GetPlayerSpecs()) do
        if SpecProfiles.GetProfileForSpec(spec.id) == profileName then
            names = names and (names .. ', ' .. spec.name) or spec.name
        end
    end
    return names
end

local function DescribeProfile(profileName)
    local parts = {}
    local count, isMine = ProfileUsage(profileName)
    local others = count - (isMine and 1 or 0)
    if others == 0 then
        parts[#parts + 1] = 'Used by this character only'
    elseif others == 1 then
        parts[#parts + 1] = 'Shared with 1 other character'
    else
        parts[#parts + 1] = 'Shared with ' .. others .. ' other characters'
    end
    local specs = SpecsUsing(profileName)
    if specs then parts[#parts + 1] = 'paired with ' .. specs end
    return table.concat(parts, SEPARATOR)
end

local function ForEachSpecMap(callback)
    for _, data in pairs(BUI.db.sv.char) do
        local store = type(data) == 'table' and data.specProfiles
        if type(store) == 'table' and type(store.map) == 'table' then callback(store.map) end
    end
end

local function RepointReferences(oldName, newName, charKeys)
    local keys = BUI.db.sv.profileKeys
    for _, charKey in ipairs(charKeys) do keys[charKey] = newName end
    if BUI.db.global.defaultProfile == oldName then
        BUI.db.global.defaultProfile = newName
    end
    ForEachSpecMap(function(map)
        for specID, value in pairs(map) do
            if value == oldName then map[specID] = newName end
        end
    end)
end

local function DropReferences(profileName)
    if BUI.db.global.defaultProfile == profileName then
        BUI.db.global.defaultProfile = nil
    end
    ForEachSpecMap(function(map)
        for specID, value in pairs(map) do
            if value == profileName then map[specID] = nil end
        end
    end)
end

BUI.PageEngine.RegisterPage("exportimport", {
    title = "Profiles",
    buttonText = "Profiles",
    OnBuild = function(pageFrame)
        local ExportImport = BUI.ExportImport
        local aceDB = BUI.GetAceDB()
        local SpecProfiles = BUI.SpecProfiles
        local profileDropdown

        local function SortedProfiles()
            local names = {}
            for _, name in pairs(aceDB:GetProfiles()) do names[#names + 1] = name end
            table.sort(names, function(first, second) return first:lower() < second:lower() end)
            return names
        end

        local function ProfileItems()
            local items = {}
            for _, name in ipairs(SortedProfiles()) do items[#items + 1] = { value = name, text = name } end
            return items
        end

        local function Exists(name)
            for _, existing in pairs(aceDB:GetProfiles()) do
                if existing == name then return true end
            end
            return false
        end

        local function RebuildPage()
            BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
        end

        local function RebuildAllPages()
            BUILib.Defer(function() BUI.PageEngine.RebuildAllPages() end)
        end

        local function ResetDropdown()
            profileDropdown:SetValue(aceDB:GetCurrentProfile())
        end

        local function SwitchTo(name)
            aceDB:SetProfile(name)
            Notify('Now using "' .. name .. '"', DescribeProfile(name))
        end

        local function RequestSwitch(name)
            if name == aceDB:GetCurrentProfile() then return end
            if SpecProfiles.IsEnabled() then
                Modals.Confirm({
                    title = 'Spec Profiles Are On',
                    message = 'This character picks its profile from your specialization.\n\nSwitching to "' .. name ..
                        '" works now, but the next spec change will override it.',
                    confirmText = 'Switch Anyway', cancelText = 'Cancel',
                    onConfirm = function() SwitchTo(name) end,
                    onCancel = ResetDropdown,
                })
                return
            end
            SwitchTo(name)
        end

        local function CreateProfile(name, copyFrom, switchToIt)
            local previous = aceDB:GetCurrentProfile()
            BUI._suppressProfileCallback = true
            aceDB:SetProfile(name)
            if copyFrom and copyFrom ~= name then aceDB:CopyProfile(copyFrom, true) else ExportImport.ApplyDefaultProfile(BUI.GetDB()) end
            BUI.MigrateProfile(BUI.GetDB())
            if not switchToIt and previous ~= name then aceDB:SetProfile(previous) end
            BUI._suppressProfileCallback = nil
            if switchToIt then
                ExportImport.RefreshAllModules()
                RebuildAllPages()
            else
                RebuildPage()
            end
        end

        local function RenameProfile(oldName, newName)
            local affected = {}
            for charKey, value in pairs(aceDB.sv.profileKeys) do
                if value == oldName then affected[#affected + 1] = charKey end
            end
            local previous = aceDB:GetCurrentProfile()
            BUI._suppressProfileCallback = true
            aceDB:SetProfile(newName)
            aceDB:CopyProfile(oldName, true)
            if previous ~= oldName then aceDB:SetProfile(previous) end
            aceDB:DeleteProfile(oldName, true)
            RepointReferences(oldName, newName, affected)
            BUI._suppressProfileCallback = nil
            Notify('Renamed to "' .. newName .. '"', 'Was "' .. oldName .. '"')
            RebuildPage()
        end

        local function DeleteProfile(name)
            aceDB:DeleteProfile(name, true)
            DropReferences(name)
            Notify('Deleted "' .. name .. '"', 'Characters that used it fall back to Default')
            RebuildPage()
        end

        local function UseEverywhere(name)
            local keys = aceDB.sv.profileKeys
            for charKey in pairs(keys) do keys[charKey] = name end
            aceDB.global.defaultProfile = name
            Notify('"' .. name .. '" set on every character', 'New characters will start on it too')
            RebuildPage()
        end

        local function PromptName(config)
            Modals.Input({
                title = config.title,
                message = config.message,
                defaultText = config.defaultText,
                confirmText = config.confirmText,
                cancelText = 'Cancel',
                onConfirm = function(text)
                    local name = Trim(text)
                    if name == '' or name == config.unchanged then return end
                    if Exists(name) then
                        Warn('Name already taken', 'A profile called "' .. name .. '" already exists.')
                        return
                    end
                    config.onName(name)
                end,
            })
        end

        local function OpenMenu(items, anchorFrame)
            Controls.ContextMenu(items, {
                width = MENU_WIDTH, anchor = anchorFrame,
                point = 'TOPRIGHT', relPt = 'BOTTOMRIGHT', offsetY = -4,
            })
        end

        local function OpenPicker(anchorFrame, config)
            local items = { { text = config.title, title = true } }
            for _, name in ipairs(SortedProfiles()) do
                if config.include(name) then
                    items[#items + 1] = { text = name, callback = function() config.onPick(name) end }
                end
            end
            if #items == 1 then
                items[#items + 1] = { text = config.emptyText, disabled = true }
            end
            OpenMenu(items, anchorFrame)
        end

        local function OpenNewMenu(anchorFrame)
            local current = aceDB:GetCurrentProfile()
            OpenMenu({
                { text = 'Create A Profile', title = true },
                { text = 'Empty profile', callback = function()
                    PromptName({
                        title = 'New Profile',
                        message = 'Starts from BluUI defaults.',
                        defaultText = '', confirmText = 'Create',
                        onName = function(name)
                            CreateProfile(name, nil, true)
                            Notify('Now using "' .. name .. '"', 'Started from BluUI defaults')
                        end,
                    })
                end },
                { text = 'Copy of "' .. current .. '"', callback = function()
                    PromptName({
                        title = 'New Profile',
                        message = 'Starts as a copy of "' .. current .. '".',
                        defaultText = current .. ' Copy', confirmText = 'Create',
                        onName = function(name)
                            CreateProfile(name, current, true)
                            Notify('Now using "' .. name .. '"', 'Copied from "' .. current .. '"')
                        end,
                    })
                end },
            }, anchorFrame)
        end

        local function OpenManageMenu(anchorFrame)
            local current = aceDB:GetCurrentProfile()
            local isDefault = current == DEFAULT_NAME

            OpenMenu({
                { text = current, title = true },

                { text = 'Duplicate...', callback = function()
                    PromptName({
                        title = 'Duplicate Profile',
                        message = 'Name the copy of "' .. current .. '".',
                        defaultText = current .. ' Copy', confirmText = 'Create',
                        onName = function(name)
                            CreateProfile(name, current, false)
                            Notify('Created "' .. name .. '"', 'Copy of "' .. current .. '"')
                        end,
                    })
                end },

                { text = 'Rename...', disabled = isDefault, sub = isDefault and 'locked' or nil, callback = function()
                    PromptName({
                        title = 'Rename Profile',
                        message = 'New name for "' .. current .. '".',
                        defaultText = current, confirmText = 'Rename', unchanged = current,
                        onName = function(name) RenameProfile(current, name) end,
                    })
                end },

                { text = 'Reset to defaults', callback = function()
                    Modals.Confirm({
                        title = 'Reset Profile',
                        message = 'Put every setting in "' .. current .. '" back to BluUI defaults?\n\nThis cannot be undone.',
                        confirmText = 'Reset', cancelText = 'Cancel',
                        onConfirm = function()
                            aceDB:ResetProfile()
                            Notify('Reset "' .. current .. '"', 'Back to BluUI defaults')
                        end,
                    })
                end },

                { separator = true },

                { text = 'Copy another profile in...', callback = function()
                    BUILib.Defer(function()
                        OpenPicker(anchorFrame, {
                            title = 'COPY INTO ' .. current:upper(),
                            emptyText = 'No other profiles',
                            include = function(name) return name ~= current end,
                            onPick = function(name)
                                Modals.Confirm({
                                    title = 'Copy Settings',
                                    message = 'Replace everything in "' .. current .. '" with the settings from "' .. name ..
                                        '"?\n\n"' .. name .. '" itself is left alone.',
                                    confirmText = 'Copy', cancelText = 'Cancel',
                                    onConfirm = function()
                                        aceDB:CopyProfile(name, true)
                                        Notify('Copied "' .. name .. '"', 'Into "' .. current .. '"')
                                    end,
                                })
                            end,
                        })
                    end)
                end },

                { text = 'Use on every character', callback = function()
                    Modals.Confirm({
                        title = 'Use Everywhere',
                        message = 'Put all of your characters on "' .. current ..
                            '", including ones you create later?\n\nTo undo this, set each character back by hand.',
                        confirmText = 'Apply', cancelText = 'Cancel',
                        onConfirm = function() UseEverywhere(current) end,
                    })
                end },

                { separator = true },

                { text = '|cffff6060Delete a profile...|r', callback = function()
                    BUILib.Defer(function()
                        OpenPicker(anchorFrame, {
                            title = 'DELETE A PROFILE',
                            emptyText = 'Nothing can be deleted',
                            include = function(name) return name ~= current and name ~= DEFAULT_NAME end,
                            onPick = function(name)
                                Modals.Confirm({
                                    title = 'Delete Profile',
                                    message = 'Delete "' .. name .. '" and every setting stored in it?\n\nThis cannot be undone.',
                                    confirmText = 'Delete', cancelText = 'Cancel',
                                    onConfirm = function() DeleteProfile(name) end,
                                })
                            end,
                        })
                    end)
                end },
            }, anchorFrame)
        end

        local function BuildManageTab(tab)
            local current = aceDB:GetCurrentProfile()

            Layout.Section(tab, 'Profiles',
                'A profile is one complete set of BluUI settings. Every character uses one at a time.')

            local grid = PageKit.RowGrid(tab)

            grid:Add({
                spanFull = true,
                plain = true,
                title = 'New Profile',
                description = 'Create another profile and switch this character to it.',
                accessoryWidth = 120,
                accessories = function(row)
                    local newButton = Controls.GhostButton(row, 'Create', 100)
                    local newFrame = Widget.Unwrap(newButton)
                    newButton:SetCallback(function() OpenNewMenu(newFrame) end)
                    return { newButton }
                end,
            })

            grid:Add({
                spanFull = true,
                plain = true,
                title = 'Active Profile',
                description = DescribeProfile(current),
                accessoryWidth = 330,
                accessories = function(row)
                    profileDropdown = Controls.Dropdown(row, nil, ProfileItems(), current, function(profileName)
                        RequestSwitch(profileName)
                    end, nil, 220)
                    local manageButton = Controls.GhostButton(row, 'Manage', 100)
                    local manageFrame = Widget.Unwrap(manageButton)
                    manageButton:SetCallback(function() OpenManageMenu(manageFrame) end)
                    return { manageButton, profileDropdown }
                end,
            })

            grid:Flush()

            local specs = SpecProfiles.GetPlayerSpecs()
            if #specs > 0 then
                Layout.Section(tab, 'Spec Profiles',
                    'Let your specialization choose the profile instead of picking one by hand.')

                local specGrid
                local toggleGrid = PageKit.RowGrid(tab)
                toggleGrid:Add({
                    spanFull = true,
                    title = 'Switch Profile With Spec',
                    description = 'Changing specialization loads the profile you pair with it below.',
                    checked = SpecProfiles.IsEnabled(),
                    callback = function(enabled)
                        SpecProfiles.SetEnabled(enabled)
                        specGrid:SyncDim(enabled)
                    end,
                })
                toggleGrid:Flush()

                specGrid = PageKit.RowGrid(tab)
                for _, spec in ipairs(specs) do
                    local specID = spec.id
                    specGrid:Add({
                        spanFull = true,
                        icon = spec.icon,
                        title = spec.name,
                        description = 'Loaded whenever you play ' .. spec.name .. '.',
                        controlWidth = 190,
                        control = function(row)
                            return Controls.Dropdown(row, nil, ProfileItems(),
                                SpecProfiles.GetProfileForSpec(specID) or current,
                                function(profileName) SpecProfiles.SetSpecProfile(specID, profileName) end, nil, 180)
                        end,
                    })
                end
                specGrid:Flush()
                specGrid:SyncDim(SpecProfiles.IsEnabled())
            end
        end

        local function BuildTransferTab(tab)
            local transferBox

            local function DoImport(importString, forceOverwrite)
                local outcome, result, data = ExportImport.ImportSettings(importString, forceOverwrite)
                if outcome == "conflict" then
                    Modals.Confirm({
                        title = "Profile Exists",
                        message = "You already have a profile called '" .. result .. "'.\n\nOverwrite it with the pasted one?",
                        confirmText = "Overwrite", cancelText = "Cancel",
                        onConfirm = function() DoImport(importString, true) end,
                    })
                elseif outcome == "chooser" then
                    ExportImport.StartImport(data, result)
                else
                    Warn('Import failed', result or 'That string could not be read.')
                end
            end

            Layout.Section(tab, 'Export / Import',
                'Profiles travel as a block of text. Export writes one into the box; Import reads one back in.')

            transferBox = Layout.TextArea(tab, nil, 160)

            local grid = PageKit.RowGrid(tab)

            grid:Add({
                spanFull = true,
                plain = true,
                title = 'Export "' .. aceDB:GetCurrentProfile() .. '"',
                description = 'Writes your active profile into the box above and selects it, ready for Ctrl+C.',
                accessoryWidth = 110,
                accessories = function(row)
                    return { Controls.GhostButton(row, 'Export', 100, function()
                        local exportString, profileName = ExportImport.ExportSettings()
                        if not exportString then
                            Warn('Export failed', profileName or 'Profile data not found.')
                            return
                        end
                        transferBox.editbox:SetText(exportString)
                        transferBox.editbox:SetFocus()
                        transferBox.editbox:HighlightText()
                        local exported = profileName or aceDB:GetCurrentProfile()
                        exportString, profileName = nil, nil
                        ReclaimScratch()
                        Notify('Exported "' .. exported .. '"', 'Press Ctrl+C to copy it')
                    end) }
                end,
            })

            grid:Add({
                spanFull = true,
                plain = true,
                title = 'Import A Profile',
                description = 'Paste a string into the box above. You choose which sections to take before anything changes.',
                accessoryWidth = 330,
                accessories = function(row)
                    local importButton = Controls.GhostButton(row, 'Import', 100, function()
                        local importString = transferBox.editbox:GetText()
                        if Trim(importString) == '' then
                            Warn('Nothing to import', 'Paste a profile string into the box first.')
                            return
                        end
                        DoImport(importString, false)
                        importString = nil
                        ReclaimScratch()
                    end)
                    local inspectButton = Controls.GhostButton(row, 'Inspect', 100, function()
                        local text, errorMessage = BUI.ImportInspector.Inspect(transferBox.editbox:GetText())
                        if not text then
                            Warn('Could not read that string', errorMessage or 'It is not a BluUI profile string.')
                            return
                        end
                        transferBox.editbox:SetText(text)
                        transferBox.editbox:SetCursorPosition(0)
                        text = nil
                        ReclaimScratch()
                    end, 'Show what the pasted string holds without importing it')
                    local clearButton = Controls.GhostButton(row, 'Clear', 100, function()
                        transferBox.editbox:SetText('')
                    end)
                    return { importButton, inspectButton, clearButton }
                end,
            })
            grid:Flush()

            local azorInstalled = C_AddOns.DoesAddOnExist('AzortharionUI')
            local azorPending = type(AzortharionUI_DB) == 'table'
                or (BluUI_DB.__azorImportDeclined
                    and not (BluUI_DB.__adoptedLegacySettings or BluUI_DB.__adoptedLegacySettings_v2))
            if azorInstalled or azorPending then
                Layout.Section(tab, 'AzortharionUI', 'Bring your old AzortharionUI setup across.')
                local azorGrid = PageKit.RowGrid(tab)
                if azorInstalled then
                    azorGrid:Add({
                        spanFull = true,
                        plain = true,
                        title = 'Copy AzortharionUI Profiles',
                        description = 'Replaces ALL BluUI profiles with a fresh copy of your AzortharionUI ones, then reloads the UI.',
                        accessoryWidth = 110,
                        accessories = function(row)
                            return { Controls.GhostButton(row, 'Copy Profiles', 100, function()
                                Modals.Confirm({
                                    title = 'Copy AzortharionUI Profiles',
                                    message = 'Replace ALL BluUI profiles with your current AzortharionUI profiles?\n\nThe UI will reload.',
                                    confirmText = 'Copy & Reload', cancelText = 'Cancel',
                                    onConfirm = BUI.ImportAzorProfiles,
                                })
                            end) }
                        end,
                    })
                else
                    azorGrid:Add({
                        spanFull = true,
                        plain = true,
                        title = 'Import Unavailable',
                        description = 'AzortharionUI is uninstalled. Reinstall it to import.',
                    })
                end
                azorGrid:Flush()
            end

            if Platynator and Platynator.API and Platynator.API.ImportString then
                Layout.Section(tab, 'Platynator Nameplates', 'BluUI ships a matching nameplate profile for Platynator.')
                local platyGrid = PageKit.RowGrid(tab)
                platyGrid:Add({
                    spanFull = true,
                    plain = true,
                    title = 'Import BluUI Nameplates',
                    description = 'Adds the BluUI profile to Platynator. Updated ' .. BUI.PlatynatorProfileDate .. '.',
                    accessoryWidth = 110,
                    accessories = function(row)
                        return { Controls.GhostButton(row, 'Import', 100, BUI.ImportPlatynatorProfile) }
                    end,
                })
                platyGrid:Flush()
            end
        end

        PageKit.Scaffold(pageFrame, {
            title = 'Profiles',
            titleDesc = 'Keep separate sets of BluUI settings, switch between them, and share them as text.',
            watermark = BUI.Tools.GetLogo(),
            hostTabs = {
                defs = {
                    { key = 'manage', title = 'PROFILES', image = 'Interface\\Icons\\INV_Misc_Note_01',
                      footerLabel = 'Switch, copy, delete' },
                    { key = 'export', title = 'EXPORT / IMPORT', image = 'Interface\\Icons\\INV_Inscription_Scroll',
                      footerLabel = 'Share as text' },
                },
                defaultKey = 'manage',
                build = function(def, tab)
                    if def.key == 'manage' then BuildManageTab(tab) else BuildTransferTab(tab) end
                end,
            },
        })
    end,
})
