local _, BUI = ...
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

local LEGACY_UNIT_KEYS = { "player", "target", "focus", "pet", "targettarget", "focustarget", "boss" }

local function MigrateLegacyKeysInUnitFrames(data)
    if not data.unitFrames then return end
    for _, unitKey in ipairs(LEGACY_UNIT_KEYS) do
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
    powerBar = { "powerScope", "powerVariants" },
    secondaryPower = { "powerScope", "powerVariants" },
    datatextBars = { "datatextBarsInit", "datatextEnabled", "datatextMinimap" },
    datatext = { "datatextEnabled", "datatextMinimap" },
    skinning = { "chatGeometry" },
    social = { "socialShowBattleTag", "socialAdvancedView", "socialCollapsedSections", "datatextSortState", "guildTooltipScore", "guildTooltipRanks" },
}

local function MigrationMarkers(general)
    local markers = {}
    for key, value in pairs(general) do
        if type(key) == "string" and key:match("^_") then markers[key] = value end
    end
    return markers
end

local function RestoreMigrationMarkers(profile, data)
    if not data._migrations then return end
    for key, value in pairs(data._migrations) do profile.general[key] = value end
end

local function FindSavedTheme(name)
    for _, saved in ipairs(BUI.db.global.savedThemes) do
        if saved.name == name then return saved end
    end
end

local function ActiveSavedTheme(db)
    local name = db.windowTheme.name
    local saved = name and FindSavedTheme(name)
    if saved then return { name = name, theme = DeepCopyClean(saved.theme) } end
end

local function AdoptSavedTheme(entry)
    if type(entry) ~= "table" or type(entry.name) ~= "string" or type(entry.theme) ~= "table" then return end
    if FindSavedTheme(entry.name) then return end
    local saved = BUI.db.global.savedThemes
    saved[#saved + 1] = { name = entry.name, theme = DeepCopyClean(entry.theme), time = time() }
end

local IMPORTED_THEME_NAME = "%s (imported)"

local function IsCustomLook(look)
    for key, value in pairs(look) do
        if key ~= "name" and key ~= "mode" and (type(value) ~= "table" or next(value) ~= nil) then return true end
    end
    return false
end

local function UniqueThemeName(base)
    local name, copy = base, 1
    while FindSavedTheme(name) do
        copy = copy + 1
        name = ("%s %d"):format(base, copy)
    end
    return name
end

local function KeepImportedLook(look, profileName)
    if look.name or not IsCustomLook(look) then return end
    local saved = BUI.db.global.savedThemes
    for _, entry in ipairs(saved) do
        if BUI.SameThemeLook(entry.theme, look) then
            look.name = entry.name
            return
        end
    end
    local name = UniqueThemeName(IMPORTED_THEME_NAME:format(profileName or "Profile"))
    saved[#saved + 1] = { name = name, theme = DeepCopyClean(look), time = time() }
    look.name = name
end

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
    RestoreMigrationMarkers(db, data)
    if (not keySet or keySet.customBars) and data.customBars then
        BUI.CustomBars.AdoptProfileSpells()
    end
    if not keySet or keySet.windowTheme then
        AdoptSavedTheme(data._savedTheme)
        KeepImportedLook(db.windowTheme, data._profileName)
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
    exportData._migrations = MigrationMarkers(db.general)
    exportData._savedTheme = ActiveSavedTheme(db)
    exportData._cdmLayoutData = BUI.CDM.Profiles.ExportCurrent()
    local serialized = LibSerialize:Serialize(exportData)
    return "BUI2=" .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(serialized))
end

local function ExportSettings()
    local aceDB = BUI.GetAceDB()
    if not aceDB then return nil, "Database not available" end
    local profileName = aceDB:GetCurrentProfile()
    return SerializeProfile(BUI.GetDB(), profileName), profileName
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
    local profile = BUI.GetDB()
    local modules = profile.modules
    local function on(key) return modules[key] ~= false end

    if on('unitFrames') then
        BUI.UnitFrames.InvalidateFilterCache()
        BUI.UnitFrames.InvalidateSettingsCache()
        BUI.UnitFrames:Refresh()
    end

    if on('groupFrames') then BUI.GroupFrames.OnProfileChanged() end
    if on('actionBars') then BUI.ActionBars.OnProfileChanged() end

    if on('cdm') then
        BUI.CDM.RefreshAll(true)
        BUI.CDM.RefreshAssistHighlight()
        BUI.CDM.PressHighlight.Refresh()
        BUI.CDM.RefreshProcMsgWatcher()
        BUI.CDM.Detached.UpdateModifierWatcher()
    end

    local powerOn = on('power')
    BUI.Power.Primary.Toggle(powerOn and BUI.Power.GetPrimaryDB().enabled and true or false)
    BUI.Power.Secondary.Toggle(powerOn and BUI.Power.GetSecondaryDB().enabled and true or false)
    if powerOn and BUI.Power.Stack.IsEnabled() then BUI.Power.Stack.Apply() end

    BUI.GCDHistory.Toggle(on('streamerTools') and profile.gcdHistory.enabled and true or false)

    local aurasOn = on('auras')
    if aurasOn then
        BUI.Auras.Update()
        BUI.Auras.UpdateLowHp()
        BUI.Auras.UpdateMark()
        BUI.Crosshair.Refresh()
        BUI.Auras.GatewayAlert.Refresh()
    end

    if aurasOn and profile.combatMessage.enabled then
        BUI.CombatMessage.Enable()
    else
        BUI.CombatMessage.Disable()
    end
    if aurasOn then BUI.CombatMessage.Refresh() end

    BUI.CombatTimer.Toggle(aurasOn and profile.combatTimer.enabled and true or false)
    BUI.CombatRes.Toggle(aurasOn and profile.combatRes.enabled and true or false)

    if on('datatext') then
        BUI.Datatext.Initialize()
        BUI.Datatext.Apply()
    end

    if on('cursor') then BUI.MouseCursor.Initialize() end
    if on('minimap') then BUI.Minimap.Initialize() end

    if on('cdm') then
        BUI.CustomBars.Initialize()
        BUI.CustomBars.RefreshAllBars()
    end

    if on('buffTracking') then
        for _, tracker in pairs(BUI.BuffTracking.Display.GetTrackers()) do
            tracker.Refresh()
            tracker.RecheckActive()
        end
    end

    BUI.Skinning.RefreshAll()
    BUI.MoveFrames.Refresh()

    BUI.ApplyScale()
    BUI.Scale.SyncButtons()
    BUI.PageEngine.RebuildAllPages()
    BUI.BUILibClient.SetFont(BUI.WindowFont())
    if BUI.PageEngine.window then BUI.PageEngine.window:ApplyTheme(profile.windowTheme) end
    BUI.Painter.Repaint()

    if on('cdm') then
        BUI.CDM.ApplyAllPositions()
        BUI.CDM.NotifyDependents()
    end
    BUI.CombatLogging.Refresh()
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

local factoryProfile

local function FactoryProfile()
    if not factoryProfile then
        factoryProfile = {}
        for key, value in pairs(GetDefaultProfileData() or {}) do
            if type(key) == 'string' and not key:match('^_') then factoryProfile[key] = DeepCopy(value) end
        end
        MergeDefaults(factoryProfile, BUI.Defaults.profile)
    end
    return factoryProfile
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
    RestoreMigrationMarkers(profile, data)
    if profile.customBars then
        BUI.CustomBars.AdoptProfileSpells()
    end
    return true
end

local THEME_PREFIX = "BUITHEME="

local function CleanColor(value)
    if type(value) ~= "table" then return nil end
    for index = 1, 3 do
        if type(value[index]) ~= "number" then return nil end
    end
    return { value[1], value[2], value[3], type(value[4]) == "number" and value[4] or 1 }
end

local function CleanTheme(source)
    local theme = { mode = "dark" }
    if type(source.dark) == "table" then
        theme.dark = {}
        for role, value in pairs(source.dark) do
            if type(role) == "string" then theme.dark[role] = CleanColor(value) end
        end
    end
    if type(source.fonts) == "table" then
        theme.fonts = {}
        for role, name in pairs(source.fonts) do
            if type(role) == "string" and type(name) == "string" then theme.fonts[role] = name end
        end
    end
    if source.edgeAccent == false then theme.edgeAccent = false end
    if source.separators == "solid" then theme.separators = "solid" end
    return theme
end

local function ExportTheme(name, theme)
    local serialized = LibSerialize:Serialize({ name = name, theme = CleanTheme(theme) })
    return THEME_PREFIX .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(serialized))
end

local function DecodeTheme(text)
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #THEME_PREFIX) ~= THEME_PREFIX then return nil, "Not a BluUI theme string" end
    local decoded = LibDeflate:DecodeForPrint(text:sub(#THEME_PREFIX + 1))
    local decompressed = decoded and LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return nil, "Could not read the theme string" end
    local success, data = LibSerialize:Deserialize(decompressed)
    if not success or type(data) ~= "table" or type(data.theme) ~= "table" then return nil, "Not a BluUI theme string" end
    return CleanTheme(data.theme), type(data.name) == "string" and data.name or nil
end

BUI.ExportImport = {
    ExportTheme = ExportTheme,
    DecodeTheme = DecodeTheme,
    ExportSettings = ExportSettings,
    ImportSettings = ImportSettings,
    DecodeImportString = DecodeImportString,
    RefreshAllModules = RefreshAllModules,
    ClassifyData = ClassifyData,
    MergeDefaults = MergeDefaults,
    ApplyDefaultProfile = ApplyDefaultProfile,
    FactoryProfile = FactoryProfile,
    CompanionKeys = ImportCompanionKeys,
}

local function ShowImportResult(message)
    BUI.Modals.Confirm({
        title = "Import Complete",
        message = message,
        confirmText = "Reload Now",
        cancelText = "Later",
        fullscreen = true,
        onConfirm = ReloadUI,
    })
end

local function OfferCDMLayouts(data, andThen)
    local blob = data._cdmLayoutData
    local Profiles = BUI.CDM.Profiles
    if not blob or blob == "" then
        andThen()
        return
    end
    BUI.Modals.Confirm({
        title = "Cooldown Manager Layouts",
        message = "This profile includes Cooldown Manager layouts.",
        confirmText = "Add to Mine", laterText = "Replace Everything", cancelText = "Skip", fullscreen = true,
        onConfirm = function()
            local ok, result = Profiles.ImportLayoutString(blob)
            andThen(ok and ("Added " .. result .. " Cooldown Manager layout(s) next to your existing ones.") or result)
        end,
        onLater = function()
            local backed, backupName = Profiles.AutoBackupSnapshot()
            local ok, errorMessage = Profiles.ApplyLayoutData(blob)
            if ok then
                andThen(backed and ("Cooldown Manager layouts applied, the previous ones were saved as snapshot '" .. backupName .. "'.") or "Cooldown Manager layouts applied.")
            else
                andThen(errorMessage)
            end
        end,
        onCancel = andThen,
    })
end

local function DoImport(data, profileKey)
    local aceDB = BUI.GetAceDB()
    data._version, data._addon, data._profileName = nil, nil, nil

    local currentRaw = DeepCopy(aceDB.profiles[profileKey] or {})

    BUI.ImportChooser.ShowChooser(data, currentRaw, function(selectedKeys)
        if #selectedKeys == 0 then return end
        BUI._suppressProfileCallback = true
        aceDB:SetProfile(profileKey)
        BUI._suppressProfileCallback = nil
        ApplyImportData(BUI.GetDB(), data, selectedKeys)
        RefreshAllModules()
        OfferCDMLayouts(data, function(note)
            ShowImportResult("Now on '" .. profileKey .. "'. " .. #selectedKeys .. " section(s) imported. " .. (note and (note .. " ") or "") .. "Reload to apply.")
        end)
    end)
end

BUI.ExportImport.StartImport = DoImport
