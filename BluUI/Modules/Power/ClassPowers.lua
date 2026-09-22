local _, BUI = ...

BUI.ClassPowers = {}
local ClassPowers = BUI.ClassPowers

local Specs = {
    BALANCE       = 102,
    ARCANE        = 62,
    FROST_MAGE    = 64,
    BREWMASTER    = 268,
    WINDWALKER    = 269,
    SHADOW        = 258,
    ELEMENTAL     = 262,
    ENHANCEMENT   = 263,
    DESTRUCTION   = 267,
    DEVOURER_DH   = 1480,
    VENGEANCE_DH  = 581,
}
ClassPowers.Specs = Specs

local playerClass, specID, isDruid

function ClassPowers.UpdateSpecID()
    local specIndex = GetSpecialization()
    local newSpec = specIndex and GetSpecializationInfo(specIndex)
    if newSpec then specID = newSpec end
    return specID
end

function ClassPowers.GetPlayerClass()
    if not playerClass then
        _, playerClass = BUI.Tools.SafeUnitClass("player")
        isDruid = playerClass == "DRUID"
    end
    return playerClass
end

function ClassPowers.GetSpecID()
    return ClassPowers.UpdateSpecID()
end

local PrimaryOverrides = {
    [Specs.SHADOW]    = Enum.PowerType.Insanity,
    [Specs.ELEMENTAL] = Enum.PowerType.Maelstrom,
}

local MOONKIN_FORM, ASTRAL_FORM = 31, 35

function ClassPowers.NormalizeDruidForm(formID)
    formID = formID or 0
    if formID == 1 then return 1 end
    if formID == 5 then return 5 end
    if formID == 3 or formID == 4 or formID == 27 or formID == 29 then return 3 end
    if formID >= MOONKIN_FORM and formID <= ASTRAL_FORM then return MOONKIN_FORM end
    return 0
end

function ClassPowers.IsFormDataReady()
    return not ClassPowers.IsDruid() or GetNumShapeshiftForms() > 0
end

local function DruidFormOverride()
    if not ClassPowers.IsFormDataReady() then return nil end
    local formOverrides = BUI.Power.GetPrimaryDB().formPowerOverrides
    return formOverrides and formOverrides[ClassPowers.NormalizeDruidForm(GetShapeshiftFormID())]
end

local function DruidAutoPower(form, spec)
    if form == 1 then return Enum.PowerType.Energy end
    if form == 5 then return Enum.PowerType.Rage end
    return spec == Specs.BALANCE and Enum.PowerType.LunarPower or Enum.PowerType.Mana
end

function ClassPowers.GetDruidAutoPowerForForm(formID)
    return DruidAutoPower(ClassPowers.NormalizeDruidForm(formID), ClassPowers.GetSpecID())
end

function ClassPowers.GetAutoPowerType()
    local spec = ClassPowers.GetSpecID()

    if ClassPowers.IsDruid() then
        local override = DruidFormOverride()
        if type(override) == "number" then return override end
        if ClassPowers.IsFormDataReady() then
            return DruidAutoPower(ClassPowers.NormalizeDruidForm(GetShapeshiftFormID()), spec)
        end
        local powerType = UnitPowerType("player")
        if powerType == Enum.PowerType.LunarPower and spec ~= Specs.BALANCE then
            powerType = Enum.PowerType.Mana
        end
        return powerType
    end

    return PrimaryOverrides[spec] or UnitPowerType("player")
end

function ClassPowers.IsPrimaryHiddenForForm()
    return ClassPowers.IsDruid() and DruidFormOverride() == 'none'
end

function ClassPowers.GetPrimaryPowerType()
    local userSource = BUI.Power.GetPrimaryDB().source
    if type(userSource) == "number" then
        return userSource, userSource == Enum.PowerType.Mana
    end

    local powerType = ClassPowers.GetAutoPowerType()
    local isMana = powerType == Enum.PowerType.Mana
    return powerType, isMana
end

local function ClassIs(classToken) return ClassPowers.GetPlayerClass() == classToken end
local function SpecIs(targetSpecID) return ClassPowers.GetSpecID() == targetSpecID end

function ClassPowers.IsRogue()        return ClassIs("ROGUE") end
function ClassPowers.IsPaladin()      return ClassIs("PALADIN") end
function ClassPowers.IsWarlock()      return ClassIs("WARLOCK") end
function ClassPowers.IsHunter()       return ClassIs("HUNTER") end
function ClassPowers.IsEvoker()       return ClassIs("EVOKER") end
function ClassPowers.IsDeathKnight()  return ClassIs("DEATHKNIGHT") end

function ClassPowers.IsShadow()       return SpecIs(Specs.SHADOW) end
function ClassPowers.IsElemental()    return SpecIs(Specs.ELEMENTAL) end
function ClassPowers.IsEnhancement()  return SpecIs(Specs.ENHANCEMENT) end
function ClassPowers.IsFrostMage()    return SpecIs(Specs.FROST_MAGE) end
function ClassPowers.IsArcane()       return SpecIs(Specs.ARCANE) end
function ClassPowers.IsBrewmaster()   return SpecIs(Specs.BREWMASTER) end
function ClassPowers.IsWindwalker()   return SpecIs(Specs.WINDWALKER) end
function ClassPowers.IsDevourer()     return SpecIs(Specs.DEVOURER_DH) end
function ClassPowers.IsVengeance()    return SpecIs(Specs.VENGEANCE_DH) end
function ClassPowers.IsBalance()      return SpecIs(Specs.BALANCE) end

function ClassPowers.IsDruid()
    if isDruid == nil then ClassPowers.GetPlayerClass() end
    return isDruid == true
end

function ClassPowers.IsDruidInCatForm()
    return ClassPowers.IsDruid() and GetShapeshiftFormID() == 1
end
