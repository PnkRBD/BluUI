local _, BUI = ...

BUI.Power = {}
local Power = BUI.Power

local ClassPowers = BUI.ClassPowers
local DeepCopy = BUI.Tools.DeepCopy

local VALID = { profile = true, class = true, spec = true }

local specKey, specKeyID, classKey

local function SpecKey()
    local specID = ClassPowers.GetSpecID()
    if specID and specID ~= specKeyID then
        specKeyID = specID
        specKey = 'spec:' .. specID
    end
    return specKey
end

local function ClassKey()
    if not classKey then classKey = 'class:' .. ClassPowers.GetPlayerClass() end
    return classKey
end

local function ScopeOf(profile)
    local scope = profile.powerScope
    return VALID[scope] and scope or 'spec'
end

function Power.GetScope()
    return ScopeOf(BUI.GetDB())
end

local completedVariants = setmetatable({}, { __mode = 'k' })

local function FillMissing(target, defaults)
    for key, value in pairs(defaults) do
        local current = target[key]
        if current == nil then
            target[key] = DeepCopy(value)
        elseif type(current) == 'table' and type(value) == 'table' then
            FillMissing(current, value)
        end
    end
end

local function EnsureVariant(profile, key)
    local variants = profile.powerVariants
    local variant = variants[key]
    if not variant then
        variant = {
            powerBar = DeepCopy(profile.powerBar),
            secondaryPower = DeepCopy(profile.secondaryPower),
        }
        variants[key] = variant
    else
        if not variant.powerBar then variant.powerBar = DeepCopy(profile.powerBar) end
        if not variant.secondaryPower then variant.secondaryPower = DeepCopy(profile.secondaryPower) end
    end
    if not completedVariants[variant] then
        completedVariants[variant] = true
        FillMissing(variant.powerBar, BUI.Defaults.profile.powerBar)
        FillMissing(variant.secondaryPower, BUI.Defaults.profile.secondaryPower)
    end
    return variant
end

local function Resolve(profile)
    local scope = ScopeOf(profile)
    if scope == 'profile' then return profile.powerBar, profile.secondaryPower end
    local key = (scope == 'spec') and SpecKey() or ClassKey()
    if not key then return profile.powerBar, profile.secondaryPower end
    local variant = EnsureVariant(profile, key)
    return variant.powerBar, variant.secondaryPower
end

function Power.GetPrimaryDB()
    return (Resolve(BUI.GetDB()))
end

function Power.GetSecondaryDB()
    local _, secondaryDB = Resolve(BUI.GetDB())
    return secondaryDB
end

function Power.ReapplyAll()
    Power.Primary.Apply()
    Power.Secondary.Apply()
end

function Power.SetScope(scope)
    local profile = BUI.GetDB()
    if not VALID[scope] then scope = 'spec' end
    profile.powerScope = scope
    Power.ReapplyAll()
end

local function VariantLabel(key)
    local specID = key:match('^spec:(%d+)$')
    if specID then
        local _, name, _, _, _, _, className = GetSpecializationInfoByID(tonumber(specID))
        if name and name ~= '' then
            return className and (name .. ' ' .. className) or name
        end
    end
    local classToken = key:match('^class:(%u+)$')
    if classToken then
        local localizedName = LOCALIZED_CLASS_NAMES_MALE[classToken]
        return (localizedName or classToken) .. ' (Class)'
    end
    return key
end

local function CurrentVariantKey()
    local scope = Power.GetScope()
    if scope == 'spec' then return SpecKey() end
    if scope == 'class' then return ClassKey() end
    return nil
end

function Power.ListCopySources()
    local profile = BUI.GetDB()
    local currentKey = CurrentVariantKey()
    local items = {}
    if currentKey then
        items[#items + 1] = { value = 'profile', text = 'Full Profile' }
    end
    for key in pairs(profile.powerVariants) do
        if key ~= currentKey then
            items[#items + 1] = { value = key, text = VariantLabel(key) }
        end
    end
    table.sort(items, function(left, right)
        if left.value == 'profile' then return true end
        if right.value == 'profile' then return false end
        return left.text < right.text
    end)
    return items
end

function Power.CopyFrom(sourceKey)
    local profile = BUI.GetDB()
    local source = sourceKey == 'profile' and profile or profile.powerVariants[sourceKey]
    if not source or not (source.powerBar and source.secondaryPower) then return false end
    local powerBarCopy = DeepCopy(source.powerBar)
    local secondaryCopy = DeepCopy(source.secondaryPower)
    local currentKey = CurrentVariantKey()
    if currentKey then
        if currentKey == sourceKey then return false end
        local variant = EnsureVariant(profile, currentKey)
        variant.powerBar, variant.secondaryPower = powerBarCopy, secondaryCopy
    else
        if sourceKey == 'profile' then return false end
        profile.powerBar, profile.secondaryPower = powerBarCopy, secondaryCopy
    end
    Power.ReapplyAll()
    return true
end

BUI.Events:OnLogin('PowerScope', function()
    BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'PowerScope', function(_, unit)
        if unit and unit ~= 'player' then return end
        ClassPowers.UpdateSpecID()
        if Power.GetScope() == 'spec' then Power.ReapplyAll() end
    end)
end)
