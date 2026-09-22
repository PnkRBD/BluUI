local _, BUI = ...
BUI.SpecProfiles = {}
local SpecProfiles = BUI.SpecProfiles

local switching = false

local stateCallbacks = {}
local function FireStateChange()
    for _, callback in pairs(stateCallbacks) do
        callback()
    end
end

function SpecProfiles.RegisterStateCallback(key, callback)
    stateCallbacks[key] = callback
end

local function Store()
    local char = BUI.db and BUI.db.char
    if not char then return nil end
    local store = char.specProfiles
    if not store then
        store = { enabled = false, map = {} }
        char.specProfiles = store
    end
    store.map = store.map or {}
    return store
end

local function CurrentSpecID()
    local index = GetSpecialization()
    return index and GetSpecializationInfo(index) or nil
end

local function ProfileExists(name)
    for _, existing in pairs(BUI.db:GetProfiles()) do
        if existing == name then return true end
    end
    return false
end

local function ApplyForCurrentSpec(announce)
    if switching then return end
    local store = Store()
    if not store or not store.enabled then return end
    local specID = CurrentSpecID()
    local target = specID and store.map[specID]
    if not target then return end
    if not ProfileExists(target) then
        store.map[specID] = nil
        FireStateChange()
        return
    end
    if target == BUI.db:GetCurrentProfile() then return end
    switching = true
    BUI.db:SetProfile(target)
    switching = false
    if announce then
        BUI.Print('Spec profile: |cff' .. BUI.C.COLOR_PINK .. target .. '|r')
    end
end

function SpecProfiles.IsEnabled()
    local store = Store()
    return (store and store.enabled) or false
end

function SpecProfiles.SetEnabled(value)
    local store = Store()
    if not store then return end
    store.enabled = value and true or false
    if store.enabled then
        local specID = CurrentSpecID()
        if specID and not store.map[specID] then
            store.map[specID] = BUI.db:GetCurrentProfile()
        end
        ApplyForCurrentSpec(true)
    end
    FireStateChange()
end

function SpecProfiles.SetSpecProfile(specID, profileName)
    local store = Store()
    if not store or not specID then return end
    store.map[specID] = profileName
    if store.enabled then ApplyForCurrentSpec(true) end
    FireStateChange()
end

function SpecProfiles.GetProfileForSpec(specID)
    local store = Store()
    return store and store.map[specID] or nil
end

function SpecProfiles.GetPlayerSpecs()
    local numSpecs = GetNumSpecializations()
    local specs = {}
    for specIndex = 1, numSpecs do
        local specID, name, _, icon = GetSpecializationInfo(specIndex)
        if specID then
            specs[#specs + 1] = { index = specIndex, id = specID, name = name, icon = icon }
        end
    end
    return specs
end

local function MigrateOldData(store)
    local charKey = UnitName('player') .. ' - ' .. GetRealmName()
    local libDualSpec = BluUI_DB and BluUI_DB.namespaces and BluUI_DB.namespaces['LibDualSpec-1.0']
    local libDualSpecChar = libDualSpec and libDualSpec.char and libDualSpec.char[charKey]
    if type(libDualSpecChar) == 'table' then
        store.enabled = libDualSpecChar.enabled and true or false
        for specIndex = 1, GetNumSpecializations() do
            local profile = libDualSpecChar[specIndex]
            local specID = GetSpecializationInfo(specIndex)
            if type(profile) == 'string' and specID then
                store.map[specID] = profile
            end
        end
        return
    end
    local oldData = BUI.db.global.specProfiles
    if type(oldData) == 'table' and type(oldData.map) == 'table' then
        store.enabled = oldData.enabled and true or false
        for specID, profile in pairs(oldData.map) do
            if type(profile) == 'string' then store.map[specID] = profile end
        end
    end
end

function SpecProfiles.ApplyOnLogin()
    local char = BUI.db and BUI.db.char
    if char and char.specProfiles == nil and GetNumSpecializations() > 0 then
        MigrateOldData(Store())
    end

    if not CurrentSpecID() then
        BUI.Events:Once('PLAYER_ENTERING_WORLD', 'SpecProfiles.LateLogin', function()
            ApplyForCurrentSpec(true)
        end)
        return
    end

    local before = BUI.db:GetCurrentProfile()
    BUI._suppressProfileCallback = true
    ApplyForCurrentSpec(false)
    BUI._suppressProfileCallback = false
    if BUI.db:GetCurrentProfile() ~= before then
        BUI.MigrateProfile(BUI.GetDB())
        BUI.Print('Spec profile: |cff' .. BUI.C.COLOR_PINK .. BUI.db:GetCurrentProfile() .. '|r')
    end
end

local function OnSpecChanged()
    if InCombatLockdown() then
        BUI.Events:AfterCombat(function() ApplyForCurrentSpec(true) end, 'SpecProfiles.Apply')
    else
        ApplyForCurrentSpec(true)
    end
end

BUI.Events:RegisterUnit('PLAYER_SPECIALIZATION_CHANGED', 'player', 'SpecProfiles', OnSpecChanged)
