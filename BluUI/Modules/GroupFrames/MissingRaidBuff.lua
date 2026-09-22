local _, BUI = ...

local GroupFrames    = BUI.GroupFrames
local Pixel = BUI.Pixel

local CreateFrame      = CreateFrame
local UnitClassBase    = UnitClassBase
local UnitIsConnected  = UnitIsConnected
local UnitIsVisible    = UnitIsVisible

local GetUnitAuras         = C_UnitAuras.GetUnitAuras
local GetUnitAuraBySpellID = C_UnitAuras.GetUnitAuraBySpellID
local GetSpellTexture      = C_Spell.GetSpellTexture
local CanAccess            = GroupFrames.Util.CanAccess
local IsSecretValue        = BUI.Tools.IsSecretValue

local playerClass = UnitClassBase("player")

local function expectedBuffID(unit)
	if not playerClass then return nil end
	local registry = GroupFrames.AuraRegistry
	local direct = registry.classRaidBuff[playerClass]
	if direct then return direct end
	if playerClass == "EVOKER" then
		local targetClass = UnitClassBase(unit)
		if targetClass == nil or IsSecretValue(targetClass) then return nil end
		return registry.evokerBuffByClass[targetClass]
	end
	return nil
end

local iconCache = {}
local function fetchIcon(spellID)
	local cached = iconCache[spellID]
	if cached ~= nil then return cached or nil end
	local texture = GetSpellTexture(spellID)
	iconCache[spellID] = texture or false
	return texture
end

local function unitHasBuff(unit, spellID)
	if GetUnitAuraBySpellID then
		local ok, aura = pcall(GetUnitAuraBySpellID, unit, spellID)
		if ok then return aura ~= nil, false end
		GetUnitAuraBySpellID = nil
	end
	local ok, auras = pcall(GetUnitAuras, unit, "HELPFUL", 40, 0, 0)
	if not ok or not auras then return true, true end
	local sawSecret = false
	for auraIndex = 1, #auras do
		local spellId = auras[auraIndex].spellId
		if spellId then
			if not CanAccess(spellId) then
				sawSecret = true
			elseif spellId == spellID then
				return true, false
			end
		end
	end
	return sawSecret, sawSecret
end

local function buffMode(config)
	return config.mode
end

local function providesBuff()
	if not playerClass then return false end
	local registry = GroupFrames.AuraRegistry
	return registry.classRaidBuff[playerClass] ~= nil or playerClass == "EVOKER"
end

local function updateFrame(frame)
	if frame.MissingRaidBuff and frame.MissingRaidBuff._buiPreview then return end
	local icon = frame.MissingRaidBuff
	if not icon then return end
	local unit = frame.unit
	local config  = icon._cfg
	if not unit or not config then icon:Hide(); return end
	if buffMode(config) == "never" then icon:Hide(); return end
	if not UnitIsVisible(unit) or not UnitIsConnected(unit) then icon:Hide(); return end

	if InCombatLockdown() then
		icon:Hide()
		frame._missingBuffStale = true
		return
	end
	if BUI.Tools.AuraQueriesBlocked() then
		frame._missingBuffStale = true
		return
	end
	frame._missingBuffStale = nil

	local spellID = expectedBuffID(unit)
	if not spellID then icon:Hide(); return end
	local hasBuff, uncertain = unitHasBuff(unit, spellID)
	if uncertain then frame._missingBuffStale = true end
	if hasBuff then icon:Hide(); return end

	local texture = fetchIcon(spellID)
	if not texture then icon:Hide(); return end
	icon.texture:SetTexture(texture)
	icon:Show()
end
GroupFrames.UpdateMissingRaidBuff = updateFrame

local function RecheckStale(child)
	if child._missingBuffWatch and child._missingBuffStale then updateFrame(child) end
end

local function RecheckAll(child)
	if child._missingBuffWatch then updateFrame(child) end
end

local function HideForCombat(child)
	local icon = child.MissingRaidBuff
	if icon and icon:IsShown() then
		icon:Hide()
		child._missingBuffStale = true
	end
end

local function EachWatched(callback)
	if not providesBuff() then return end
	GroupFrames.EachChild(callback)
end

BUI.Tools.OnAuraQueriesUnblocked(function() EachWatched(RecheckStale) end)
BUI.Events:Register("PLAYER_REGEN_DISABLED", "GroupFrames.MissingRaidBuff", function() EachWatched(HideForCombat) end)
BUI.Events:Register("PLAYER_REGEN_ENABLED", "GroupFrames.MissingRaidBuff", function()
	BUI.Events:AfterCombatSettled(function() EachWatched(RecheckAll) end, "GroupFrames.MissingRaidBuff")
end)

local function position(icon, config, parent)
	icon._cfg = config
	icon:SetSize(Pixel.Scale(config.size), Pixel.Scale(config.size))
	icon:SetFrameStrata(parent:GetFrameStrata())
	icon:ClearAllPoints()
	icon:SetPoint(config.anchor, parent, config.anchor, Pixel.Scale(config.offsetX), Pixel.Scale(config.offsetY))
	parent._missingBuffWatch = providesBuff() and buffMode(config) ~= "never"
end

function GroupFrames.BuildMissingRaidBuff(frame, unit)
	local config = GroupFrames.SettingsForFrame(frame).missingRaidBuff

	local icon = CreateFrame("Frame", nil, frame)
	icon:SetFrameLevel(frame:GetFrameLevel() + GroupFrames.Layers.missingBuff)
	icon:EnableMouse(false)
	Pixel.SetTemplate(icon, 0, 0, 0, 1, 0, 0, 0, 1, 1)

	local texture = icon:CreateTexture(nil, "ARTWORK")
	texture:SetPoint("TOPLEFT", 1, -1)
	texture:SetPoint("BOTTOMRIGHT", -1, 1)
	texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.texture = texture

	position(icon, config, frame)
	icon:Hide()
	frame.MissingRaidBuff = icon
end

function GroupFrames.ApplyMissingRaidBuffToChild(child, settings)
	local icon = child.MissingRaidBuff
	if not icon then return end
	local config = settings.missingRaidBuff
	position(icon, config, child)
	if buffMode(config) == "never" then icon:Hide() else xpcall(updateFrame, geterrorhandler(), child) end
end

function GroupFrames.RefreshMissingRaidBuff()
	GroupFrames.EachChild(function(child)
		GroupFrames.ApplyMissingRaidBuffToChild(child, GroupFrames.SettingsForFrame(child))
	end)
end
