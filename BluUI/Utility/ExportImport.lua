local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('Util.ExportImport')
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")
local DeepCopy = BUI.Tools.DeepCopy

local LegacyKeyMigrations = {
    { from = "hideName",       to = "showName" },
    { from = "hideHealthText", to = "showHealthText" },
    { from = "hidePower",      to = "showPower" },
}

local function StripLegacyHideKeys(unitSettings)
    if not unitSettings then return end
    for _, migration in ipairs(LegacyKeyMigrations) do
        if unitSettings[migration.from] ~= nil then
            if unitSettings[migration.to] == nil then unitSettings[migration.to] = not unitSettings[migration.from] end
            unitSettings[migration.from] = nil
        end
    end
end

local function MigrateLegacyKeysInUnitFrames(data)
    if not data.unitFrames then return end
    for _, unitKey in ipairs({"player", "target", "focus", "pet", "targettarget", "focustarget", "boss"}) do
        StripLegacyHideKeys(data.unitFrames[unitKey])
    end
end

local function ProfileExists(aceDB, name)
    for _, profile in pairs(aceDB:GetProfiles()) do
        if profile == name then return true end
    end
    return false
end

local function MergeDefaults(dest, defaults)
    for key, value in pairs(defaults) do
        if type(value) == 'table' then
            if dest[key] == nil then
                dest[key] = DeepCopy(value)
            elseif type(dest[key]) == 'table' then
                MergeDefaults(dest[key], value)
            end
        elseif dest[key] == nil then
            dest[key] = value
        end
    end
end

local function CompletePartialArrays(node, defaults)
    if type(node) ~= 'table' or type(defaults) ~= 'table' then return end
    for key, defaultValue in pairs(defaults) do
        local current = node[key]
        if type(current) == 'table' and type(defaultValue) == 'table' then
            for index, value in pairs(defaultValue) do
                if type(index) == 'number' and current[index] == nil then
                    current[index] = value
                end
            end
            CompletePartialArrays(current, defaultValue)
        end
    end
end

local function DeepCopyClean(source)
    if type(source) ~= 'table' then return source end
    local copy = {}
    for key, value in pairs(source) do
        if type(key) ~= 'string' or not key:match('^_') then
            copy[key] = DeepCopyClean(value)
        end
    end
    return copy
end

local ImportCompanionKeys = {
    powerBar = { "powerBar2", "powerScope", "powerVariants" },
    secondaryPower = { "powerScope", "powerVariants" },
    datatextBars = { "datatextBarsInit", "datatextEnabled", "datatextMinimap" },
    datatext = { "datatextEnabled", "datatextMinimap", "datatextHideHoversInCombat", "datatextRosterTooltips" },
    social = { "socialShowBattleTag", "socialAdvancedView", "socialCollapsedSections", "datatextSortState" },
}

local function ApplyImportData(db, data, selectedKeys)
    MigrateLegacyKeysInUnitFrames(data)
    local keySet
    if selectedKeys then
        keySet = {}
        for _, key in ipairs(selectedKeys) do keySet[key] = true end
        local extra = {}
        for key in pairs(keySet) do
            local companions = ImportCompanionKeys[key]
            if companions then
                for _, companionKey in ipairs(companions) do extra[companionKey] = true end
            end
        end
        for key in pairs(extra) do keySet[key] = true end
    end
    for key, value in pairs(data) do
        if type(key) == "string" and not key:match("^_") and (not keySet or keySet[key]) then
            db[key] = DeepCopyClean(value)
        end
    end
    MergeDefaults(db, BUI.Defaults.profile)
    if (not keySet or keySet.customBars) and data.customBars and BUI.CustomBars and BUI.CustomBars.AdoptProfileSpells then
        BUI.CustomBars.AdoptProfileSpells()
    end
end

local function SerializeProfile(db, profileName)
    local exportData = { _version = 2, _addon = "BluUI", _profileName = profileName }
    for key, value in pairs(db) do
        if type(key) == "string" and not key:match("^_") then
            exportData[key] = DeepCopyClean(value)
        end
    end
    MigrateLegacyKeysInUnitFrames(exportData)
    CompletePartialArrays(exportData, BUI.Defaults.profile)
    local Profiles = BUI.CDM and BUI.CDM.Profiles
    if Profiles and Profiles.ExportCurrent then
        exportData._cdmLayoutData = Profiles.ExportCurrent()
    end
    local serialized = LibSerialize:Serialize(exportData)
    return "BUI2=" .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(serialized))
end

local function ExportSettings()
    local aceDB = BUI.GetAceDB()
    if not aceDB then return nil, "Database not available" end
    local profileName = aceDB:GetCurrentProfile()
    local db = BUI.GetDB()
    if not db then return nil, "Profile data not found" end
    return SerializeProfile(db, profileName), profileName
end

local function DecodeImportString(importString)
    if not importString or importString == "" then return nil, "Empty import string" end

    importString = importString:gsub("^%s+", ""):gsub("%s+$", "")
    if not (importString:match("^BUI2=") or importString:match("^AUI2=")) then return nil, "Not a BUI2 string" end

    local decoded = LibDeflate:DecodeForPrint(importString:sub(6))
    if not decoded then return nil, "Failed to decode string" end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return nil, "Failed to decompress" end

    local success, data = LibSerialize:Deserialize(decompressed)
    if not success then return nil, "Failed to deserialize: " .. tostring(data) end

    if type(data) ~= "table" then return nil, "Invalid data format" end
    if data._addon ~= "BluUI" and data._addon ~= "AzortharionUI" then return nil, "Not a BluUI or AzortharionUI profile" end

    BUI.FixLegacyValues(data)

    return data
end

local function ImportSettings(importString, forceOverwrite)
    local data, errorMessage = DecodeImportString(importString)
    if not data then return false, errorMessage end

    local profileName = data._profileName or "Imported"
    local aceDB = BUI.GetAceDB()
    if not aceDB then return false, "Database not available" end

    if ProfileExists(aceDB, profileName) and not forceOverwrite then
        return "conflict", profileName, data
    end
    return "chooser", profileName, data
end

local function RefreshAllModules()
    local modules = BUI.GetDB().modules
    local function on(key) return modules[key] ~= false end
    local Measure = BUI.Prof.Measure

    if on('unitFrames') and BUI.UnitFrames then
        Measure('refresh#UnitFrames', function()
            if BUI.UnitFrames.InvalidateFilterCache then BUI.UnitFrames.InvalidateFilterCache() end
            if BUI.UnitFrames.InvalidateSettingsCache then BUI.UnitFrames.InvalidateSettingsCache() end
            if BUI.UnitFrames.Refresh then BUI.UnitFrames:Refresh() end
        end)
    end

    if on('groupFrames') and BUI.GroupFrames and BUI.GroupFrames.OnProfileChanged then
        Measure('refresh#GroupFrames', BUI.GroupFrames.OnProfileChanged)
    end

    if on('actionBars') and BUI.ActionBars and BUI.ActionBars.OnProfileChanged then
        Measure('refresh#ActionBars', BUI.ActionBars.OnProfileChanged)
    end

    if on('cdm') and BUI.CDM then
        Measure('refresh#CDM', function()
            if BUI.CDM.RefreshAll then BUI.CDM.RefreshAll(true) end
            if BUI.CDM.RefreshAssistHighlight then BUI.CDM.RefreshAssistHighlight() end
        end)
    end

    if on('castBars') and BUI.CastBar then
        BUI.Prof.After('Util.ExportImport', 0.05, function()
            for _, unit in ipairs({ "Player", "Target", "Focus", "Boss" }) do
                local bar = BUI.CastBar[unit]
                if bar and bar.Refresh then bar:Refresh() end
            end
        end)
    end

    if BUI.Power then
        Measure('refresh#Power', function()
        local powerOn = on('power')
        local powerDB = (BUI.Power.GetPrimaryDB and BUI.Power.GetPrimaryDB()) or BUI.GetDB().powerBar
        if BUI.Power.Primary and BUI.Power.Primary.Toggle then
            BUI.Power.Primary.Toggle(powerOn and powerDB and powerDB.enabled and true or false)
        elseif powerOn and BUI.Power.Primary and BUI.Power.Primary.Apply then
            BUI.Power.Primary.Apply()
        end

        local secondaryPowerDB = (BUI.Power.GetSecondaryDB and BUI.Power.GetSecondaryDB()) or BUI.GetDB().secondaryPower
        if BUI.Power.Secondary and BUI.Power.Secondary.Toggle then
            BUI.Power.Secondary.Toggle(powerOn and secondaryPowerDB and secondaryPowerDB.enabled and true or false)
        elseif powerOn and BUI.Power.Secondary and BUI.Power.Secondary.Apply then
            BUI.Power.Secondary.Apply()
        end

        if powerOn and BUI.Power.Stack and BUI.Power.Stack.IsEnabled and BUI.Power.Stack.IsEnabled() and BUI.Power.Stack.Apply then
            BUI.Power.Stack.Apply()
        end
        end)
    end

    Measure('refresh#StreamerTools', function()
        local streamerToolsOn = on('streamerTools')
        local gcdDB = BUI.GetDB().gcdHistory
        if BUI.GCDHistory then BUI.GCDHistory.Toggle(streamerToolsOn and gcdDB and gcdDB.enabled and true or false) end
    end)

    Measure('refresh#Auras', function()
        local aurasOn = on('auras')
        if aurasOn and BUI.Auras then
            BUI.Auras.Update()
            if BUI.Auras.UpdateLowHp then BUI.Auras.UpdateLowHp() end
            if BUI.Auras.UpdateMark then BUI.Auras.UpdateMark() end
            if BUI.Crosshair then BUI.Crosshair.Refresh() end
            if BUI.Auras.GatewayAlert then BUI.Auras.GatewayAlert.Refresh() end
        end

        local combatMessageDB = BUI.GetDB().combatMessage
        if BUI.CombatMessage then
            if aurasOn and combatMessageDB and combatMessageDB.enabled then
                if BUI.CombatMessage.Enable then BUI.CombatMessage.Enable() end
            elseif BUI.CombatMessage.Disable then
                BUI.CombatMessage.Disable()
            end
            if aurasOn and BUI.CombatMessage.Refresh then BUI.CombatMessage.Refresh() end
        end

        local combatTimerDB = BUI.GetDB().combatTimer
        if BUI.CombatTimer then BUI.CombatTimer.Toggle(aurasOn and combatTimerDB and combatTimerDB.enabled and true or false) end
    end)

    if on('datatext') and BUI.Datatext then
        Measure('refresh#Datatext', function()
            if BUI.Datatext.Initialize then BUI.Datatext.Initialize() end
            if BUI.Datatext.Apply then BUI.Datatext.Apply() end
        end)
    end

    if on('cursor') and BUI.MouseCursor and BUI.MouseCursor.Initialize then Measure('refresh#Cursor', BUI.MouseCursor.Initialize) end
    if on('minimap') and BUI.Minimap and BUI.Minimap.Initialize then Measure('refresh#Minimap', BUI.Minimap.Initialize) end

    if on('customBars') and BUI.CustomBars then
        Measure('refresh#CustomBars', function()
            if BUI.CustomBars.Initialize then BUI.CustomBars.Initialize() end
            if BUI.CustomBars.RefreshAllBars then BUI.CustomBars.RefreshAllBars() end
        end)
    end

    if on('buffTracking') and BUI.BuffTracking and BUI.BuffTracking.Display then
        Measure('refresh#BuffTracking', function()
            for _, tracker in pairs(BUI.BuffTracking.Display.GetTrackers()) do
                if tracker.Refresh then tracker.Refresh() end
                if tracker.RecheckActive then tracker.RecheckActive() end
            end
        end)
    end

    if BUI.Skinning.RefreshAll then Measure('refresh#Skinning', BUI.Skinning.RefreshAll) end
    if BUI.MoveFrames and BUI.MoveFrames.Refresh then Measure('refresh#MoveFrames', BUI.MoveFrames.Refresh) end

    Measure('refresh#ApplyScale', BUI.ApplyScale)
    Measure('refresh#SyncButtons', BUI.Scale.SyncButtons)
    Measure('refresh#RebuildAllPages', BUI.PageEngine.RebuildAllPages)

    if on('cdm') and BUI.CDM and BUI.CDM.ApplyAllPositions then Measure('refresh#CDMPositions', BUI.CDM.ApplyAllPositions) end
end

local function HasStringKeys(candidate)
    for key in pairs(candidate) do
        if type(key) == 'string' then return true end
    end
    return false
end

local function GetNumericTemplate(defaults)
    local template = defaults[1]
    if type(template) == 'table' and HasStringKeys(template) then return template end
    return nil
end

local function WalkKeys(saved, defaults, prefix, result, nilKeys, deprecatedSet, protectedSet, doDelete)
    local deleted = 0

    for key, value in pairs(saved) do
        if type(key) == 'string' and not key:match('^_') then
            local path = prefix and (prefix .. '.' .. key) or key
            local defaultValue = defaults and defaults[key]

            if protectedSet[path] then
                result.protected[#result.protected + 1] = path
            elseif deprecatedSet[path] then
                result.deprecated[#result.deprecated + 1] = path
                if doDelete then
                    saved[key] = nil
                    deleted = deleted + 1
                end
            elseif defaultValue == nil and not nilKeys[key] then
                result.unknown[#result.unknown + 1] = path
            elseif type(value) == 'table' and type(defaultValue) == 'table' and HasStringKeys(defaultValue) then
                deleted = deleted + WalkKeys(value, defaultValue, path, result, nilKeys, deprecatedSet, protectedSet, doDelete)
            end
        end
    end

    if defaults then
        local template = GetNumericTemplate(defaults)
        if template then
            for key, value in pairs(saved) do
                if type(key) == 'number' and type(value) == 'table' then
                    local path = prefix and (prefix .. '[' .. key .. ']') or ('[' .. key .. ']')
                    deleted = deleted + WalkKeys(value, template, path, result, nilKeys, deprecatedSet, protectedSet, doDelete)
                end
            end
        end
    end

    return deleted
end

local function ClassifyData(data)
    local result = { deprecated = {}, protected = {}, unknown = {} }
    if not data then return result end
    WalkKeys(data, BUI.Defaults.profile, nil, result,
        BUI.NilDefaultKeys,
        BUI.DeprecatedKeys,
        BUI.LiveOverrideKeys,
        false)
    table.sort(result.deprecated)
    table.sort(result.protected)
    table.sort(result.unknown)
    return result
end

local defaultProfileData

local function GetDefaultProfileData()
    if defaultProfileData == nil then
        local data = DecodeImportString(BUI.DefaultProfileString)
        if data then
            data._version, data._addon, data._profileName, data._cdmLayoutData = nil, nil, nil, nil
            MigrateLegacyKeysInUnitFrames(data)
        end
        defaultProfileData = data or false
    end
    return defaultProfileData or nil
end

local function ApplyDefaultProfile(profile)
    local data = GetDefaultProfileData()
    if not data or type(profile) ~= 'table' then return false end
    for key, value in pairs(data) do
        if type(key) == 'string' and not key:match('^_') then
            profile[key] = DeepCopy(value)
        end
    end
    MergeDefaults(profile, BUI.Defaults.profile)
    if profile.customBars and BUI.CustomBars and BUI.CustomBars.AdoptProfileSpells then
        BUI.CustomBars.AdoptProfileSpells()
    end
    return true
end

BUI.ExportImport = {
    ExportSettings = ExportSettings,
    ImportSettings = ImportSettings,
    DecodeImportString = DecodeImportString,
    RefreshAllModules = RefreshAllModules,
    ClassifyData = ClassifyData,
    MergeDefaults = MergeDefaults,
    ApplyDefaultProfile = ApplyDefaultProfile,
}

BUIG = {}

function BUIG:Export(profileKey)
    local aceDB = BUI.GetAceDB()
    if not aceDB then return nil, "Database not available" end

    local currentProfile = aceDB:GetCurrentProfile()
    profileKey = profileKey or currentProfile

    local switched = false
    if profileKey ~= currentProfile then
        aceDB:SetProfile(profileKey)
        switched = true
    end

    local db = BUI.GetDB()
    if not db then
        if switched then aceDB:SetProfile(currentProfile) end
        return nil, "Profile not found"
    end

    local result = SerializeProfile(db, profileKey)
    if switched then aceDB:SetProfile(currentProfile) end
    return result
end

local importPending = false

local function SwitchProfileAndApply(aceDB, profileKey, applyCallback)
    BUI._suppressProfileCallback = true
    aceDB:SetProfile(profileKey)
    BUI._suppressProfileCallback = nil
    local db = BUI.GetDB()
    if not db then
        importPending = false
        return false
    end
    applyCallback(db)
    importPending = false
    RefreshAllModules()
    return true
end

local function ShowImportResult(message)
    BUI.Modals.Confirm({
        title = "Import Complete",
        message = message,
        confirmText = "Reload Now",
        cancelText = "Later",
        fullscreen = true,
        onConfirm = function() ReloadUI() end,
    })
end

local function OfferCDMLayouts(data, andThen)
    local blob = data and data._cdmLayoutData
    local Profiles = BUI.CDM and BUI.CDM.Profiles
    if not blob or blob == "" or not Profiles or not Profiles.IsAvailable() then
        andThen()
        return
    end
    BUI.Modals.Confirm({
        title = "Cooldown Manager Layouts",
        message = "This profile includes Cooldown Manager layouts.",
        confirmText = "Add to Mine", laterText = "Replace Everything", cancelText = "Skip", fullscreen = true,
        onConfirm = function()
            local ok, result = Profiles.ImportLayoutString(blob)
            BUI.Print(ok and ("Added " .. result .. " Cooldown Manager layout(s) next to your existing ones.") or (result or "Could not add the Cooldown Manager layouts."))
            andThen()
        end,
        onLater = function()
            local backed, backupName = Profiles.AutoBackupSnapshot()
            local ok, errorMessage = Profiles.ApplyLayoutData(blob)
            if ok then
                BUI.Print(backed and ("Cooldown Manager layouts applied. Your previous layouts were saved as snapshot '" .. backupName .. "'.") or "Cooldown Manager layouts applied.")
            else
                BUI.Print(errorMessage or "Could not apply Cooldown Manager layouts.")
            end
            andThen()
        end,
        onCancel = andThen,
    })
end

local function DoImport(data, profileKey)
    local aceDB = BUI.GetAceDB()
    if not aceDB then return false, "Database not available" end

    data._version, data._addon, data._profileName = nil, nil, nil

    local currentRaw = DeepCopy(aceDB.profiles[profileKey] or {})

    BUI.ImportChooser.ShowChooser(data, currentRaw, function(selectedKeys)
        if #selectedKeys == 0 then
            importPending = false
            return
        end
        if not SwitchProfileAndApply(aceDB, profileKey, function(db)
            ApplyImportData(db, data, selectedKeys)
        end) then return end
        OfferCDMLayouts(data, function()
            ShowImportResult("Now on '" .. profileKey .. "'. " .. #selectedKeys .. " section(s) imported. Reload to apply.")
        end)
    end, function()
        importPending = false
    end)
    return "pending"
end

BUI.ExportImport.StartImport = DoImport

function BUIG:Import(importString)
    if importPending then return false, "Import already in progress" end

    local data, errorMessage = DecodeImportString(importString)
    if not data then return false, errorMessage end

    local aceDB = BUI.GetAceDB()
    if not aceDB then return false, "Database not available" end

    local profileKey = "BluUI"

    if ProfileExists(aceDB, profileKey) then
        importPending = true
        local modalOverlay = BUI.Modals.Custom({
            title = "Profile Already Exists",
            message = "'" .. profileKey .. "' profile already exists.",
            width = 560, height = 240, fullscreen = true,
            buttons = {
                {
                    text = "Create Backup",
                    color = {0.3, 1, 0.3, 1}, width = 130,
                    onClick = function(close)
                        close()
                        importPending = false
                        if BUI.PageEngine then
                            BUI.PageEngine.Show()
                            for index, pageId in ipairs(BUI.PageEngine.pageOrder) do
                                if pageId == "exportimport" then
                                    BUI.PageEngine.ShowPage(index)
                                    break
                                end
                            end
                        end
                    end
                },
                {
                    text = "Continue",
                    color = {1, 0.8, 0.2, 1}, width = 130,
                    onClick = function(close) close(); DoImport(data, profileKey) end
                },
                {
                    text = "Cancel",
                    color = {0.5, 0.5, 0.5, 1}, width = 130,
                    onClick = function(close) close(); importPending = false end
                }
            }
        })
        if modalOverlay then
            HookScript(modalOverlay, "OnHide", function() importPending = false end)
        end
        return "pending", profileKey
    end

    importPending = true
    return DoImport(data, profileKey)
end
