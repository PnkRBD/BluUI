local _, BUI = ...

local Pixel = BUI.Pixel
local sharedMedia = LibStub('LibSharedMedia-3.0')

local CreateFrame = CreateFrame

local UIParent = UIParent
local UnitClass = UnitClass
local UnitIsPlayer = UnitIsPlayer
local UnitPowerType = UnitPowerType
local UnitReaction = UnitReaction

local SetColorTex = BUI.Tools.SetColorTex
local UnitFrames = {}
BUI.UnitFrames = UnitFrames

UnitFrames.UNIT_CONFIG = {
	player = {
		width = 271, height = 41, textSize = 12, showPower = true,
		showPowerDefault = true, hasCombatBorder = true, hasAuras = true,
	},
	target = {
		width = 271, height = 41, textSize = 12, showPower = true,
		showPowerDefault = true, hasAuras = true,
	},
	targettarget = {
		width = 110, height = 30, textSize = 10, showPower = false,
		showPowerDefault = false, hasAuras = true,
	},
	focus = {
		width = 186, height = 80, textSize = 10, showPower = true,
		showPowerDefault = true, hasAuras = true,
	},
	pet = {
		width = 105, height = 41, textSize = 10, showPower = true,
		showPowerDefault = false,
	},
	boss = {
		width = 180, height = 40, textSize = 11, showPower = true,
		showPowerDefault = false, hasAuras = true,
		spacing = 2,
	},
}

local unitConfigCache = {}
function UnitFrames.GetUnitConfig(unit)
	local key = unitConfigCache[unit]
	if not key then
		key = unit:gsub('%d+$', '')
		unitConfigCache[unit] = key
	end
	return UnitFrames.UNIT_CONFIG[key]
end

local WHITE_TEX = [[Interface\Buttons\WHITE8x8]]
local FILL_TEXTURES = {
	Solid = WHITE_TEX,
}
local OVERLAY_TEXTURES = {
	Stripes = BUI.C.MEDIA_PATH .. 'stripes.tga',
}

local function ResolveAbsorbTexture(config, default)
	if config.texture == 'Solid' then return 'Solid' end
	if config.texture == 'Stripes' then return 'Stripes' end

	return default
end

local function ApplyAbsorbStyle(bar, config, default)
	local key = ResolveAbsorbTexture(config, default)
	local color = config.color

	bar:SetStatusBarTexture(FILL_TEXTURES[key] or WHITE_TEX)
	bar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
	local base = bar:GetStatusBarTexture()
	if base and base.SetBlendMode then base:SetBlendMode('BLEND') end

	if bar._absBg then bar._absBg:Hide() end

	local overlayTexture = OVERLAY_TEXTURES[key]
	if overlayTexture then
		local overlay = bar._absOverlay
		if not overlay then overlay = bar:CreateTexture(nil, 'OVERLAY'); bar._absOverlay = overlay end
		overlay:SetTexture(overlayTexture, 'REPEAT', 'REPEAT')
		overlay:SetHorizTile(true); overlay:SetVertTile(true)
		overlay:SetBlendMode('BLEND')
		overlay:SetVertexColor(1, 1, 1)
		overlay:SetAlpha(1)
		overlay:ClearAllPoints()
		overlay:SetAllPoints(base)
		overlay:Show()
	elseif bar._absOverlay then
		bar._absOverlay:Hide()
	end
end

function UnitFrames.ApplyAbsorbVisual(bar, config)
	ApplyAbsorbStyle(bar, config, 'Stripes')
end

function UnitFrames.ApplyHealAbsorbVisual(bar, config)
	ApplyAbsorbStyle(bar, config, 'Stripes')
end

function UnitFrames.BuildAbsorbCfg(settings)
	return {
		texture = settings.shieldOverlay,
		color   = settings.shieldColor,
	}
end

function UnitFrames.BuildHealAbsorbCfg(settings)
	return {
		texture = settings.healAbsorbOverlay,
		color   = settings.healAbsorbColor,
	}
end

function UnitFrames.AnchorAbsorb(absorb, health, healthTexture, direction)
	absorb:ClearAllPoints()
	if direction == 'left' then
		absorb:SetReverseFill(true)
		absorb:SetPoint('TOPRIGHT', healthTexture, 'TOPRIGHT')
		absorb:SetPoint('BOTTOMRIGHT', healthTexture, 'BOTTOMRIGHT')
	elseif direction == 'edge' then
		absorb:SetReverseFill(true)
		absorb:SetPoint('TOPRIGHT', health, 'TOPRIGHT', 0, 0)
		absorb:SetPoint('BOTTOMRIGHT', health, 'BOTTOMRIGHT', 0, 0)
	else
		absorb:SetReverseFill(false)
		absorb:SetPoint('LEFT', healthTexture, 'RIGHT')
		absorb:SetPoint('TOP', health, 'TOP')
		absorb:SetPoint('BOTTOM', health, 'BOTTOM')
	end
end

local settingsCache
local unitCache = {}

function UnitFrames.InvalidateSettingsCache()
	settingsCache = nil
	wipe(unitCache)
	UnitFrames.InvalidateMedia()
end

function UnitFrames.GetSettings()
	if settingsCache then return settingsCache end
	local db = BUI.GetDB()
	settingsCache = db and db.unitFrames or BUI.Defaults.profile.unitFrames
	return settingsCache
end

function UnitFrames.TextSetting(unitSettings, key)
	local value = unitSettings[key]
	if value == nil then value = UnitFrames.GetSettings()[key] end
	return value
end

function UnitFrames.GetUnitSettings(unitType)
	if unitCache[unitType] then return unitCache[unitType] end
	local settings = UnitFrames.GetSettings()

	local saved = settings and settings[unitType] or BUI.Defaults.profile.unitFrames[unitType]
	unitCache[unitType] = saved
	return saved
end

function UnitFrames.ApplyClickToTarget()
	local oUF = BUI.oUF
	local enabled = UnitFrames.GetSettings().clickToTarget ~= false
	BUI.Events:AfterCombat(function()
		for _, frame in ipairs(oUF.objects) do
			frame:SetAttribute('*type1*', enabled and 'target' or nil)
		end
	end, 'UF.ClickToTarget')
end

local cachedFont, cachedTexture

function UnitFrames.InvalidateMedia()
	cachedFont = nil
	cachedTexture = nil
end

function UnitFrames.GetTexture()
	if not cachedTexture then
		local settings = UnitFrames.GetSettings()
		cachedTexture = settings.texture == 'GLOBAL'
			and BUI.GetGlobalTexture()
			or (sharedMedia:Fetch('statusbar', settings.texture) or BUI.GetGlobalTexture())
	end
	return cachedTexture
end

function UnitFrames.GetFont()
	if not cachedFont then
		local settings = UnitFrames.GetSettings()
		cachedFont = settings.font == 'GLOBAL'
			and BUI.GetGlobalFont()
			or (sharedMedia:Fetch('font', settings.font) or BUI.GetGlobalFont())
	end
	return cachedFont
end

local IsPetUnit = {
	pet = true, pet1 = true, pet2 = true, pet3 = true, pet4 = true, pet5 = true,
}

function UnitFrames.GetHealthColor(unit, settings)
	local isPet = IsPetUnit[unit]
	if settings.classColorHealth and not isPet then
		if UnitIsPlayer(unit) then
			local red, green, blue = BUI.Tools.GetUnitClassColor(unit)
			if red then return red, green, blue, 1 end
		end
		local reaction = UnitReaction(unit, 'player')
		if reaction then
			if reaction >= 5 then return 0.2, 0.8, 0.2, 1
			elseif reaction >= 4 then return 0.8, 0.8, 0.2, 1
			else return 0.8, 0.2, 0.2, 1 end
		end
	end
	local healthColor = isPet and settings.petHealthColor or settings.healthColor
	return healthColor[1], healthColor[2], healthColor[3], healthColor[4] or 1
end

function UnitFrames.GetPowerColor(unit, settings, unitSettings)
	local isPet = IsPetUnit[unit]
	if settings.useClassColorPowerBar and not isPet then
		if UnitIsPlayer(unit) then
			local red, green, blue = BUI.Tools.GetUnitClassColor(unit)
			if red then return red, green, blue, 1 end
		else
			local reaction = UnitReaction(unit, 'player')
			if reaction and unitSettings then
				local key = reaction >= 5 and 'friendlyNameColor'
					or reaction >= 4 and 'neutralNameColor'
					or 'hostileNameColor'
				local reactionColor = unitSettings[key]
				if reactionColor then return reactionColor[1], reactionColor[2], reactionColor[3], 1 end
			end
		end
	end
	if settings.classColorPower and not isPet then
		local powerType, powerToken = UnitPowerType(unit)
		local powerTypeColor = PowerBarColor[powerToken or powerType]
		if powerTypeColor then return powerTypeColor.r, powerTypeColor.g, powerTypeColor.b, 1 end
	end
	local powerColor
	if isPet then
		powerColor = settings.petPowerColor
	else
		powerColor = (unitSettings and unitSettings.powerColor) or settings.powerColor
	end
	return powerColor[1], powerColor[2], powerColor[3], powerColor[4] or 1
end

function UnitFrames.GetNameColor(unit, unitSettings)
	if unitSettings.classColorName and not IsPetUnit[unit] then
		if UnitIsPlayer(unit) then
			local red, green, blue = BUI.Tools.GetUnitClassColor(unit)
			if red then return red, green, blue end
		end
		local reaction = UnitReaction(unit, 'player')
		if reaction then
			local key = reaction >= 5 and 'friendlyNameColor'
				or reaction >= 4 and 'neutralNameColor'
				or 'hostileNameColor'
			local reactionColor = unitSettings[key]
			if reactionColor then return reactionColor[1], reactionColor[2], reactionColor[3] end
		end
	end
	local color = UnitFrames.GetSettings().nameColor
	return color[1], color[2], color[3]
end

local function PlaceCentered(frame, x, y)
	BUI.Anchor.SetCentered(frame, x, y)
end

local ANCHOR_LAYOUT_FIELDS = {
	'_topEdgeOffset', '_bottomEdgeOffset', '_row1CenterOffsetX', '_topRowCenterOffsetX', '_bottomRowCenterOffsetX',
	'_topRowW', '_bottomRowW', '_row1W', '_layoutW', '_castbarIconWidth', '_cachedScaledH',
}
local ANCHOR_GEOMETRY_SLOTS = #ANCHOR_LAYOUT_FIELDS + 5
local ANCHOR_EXTRA_SLOT = ANCHOR_GEOMETRY_SLOTS + 1
local anchorProbe = {}

function UnitFrames.AnchorGeometryChanged(holder, target, extra)
	anchorProbe[1] = target
	if target then
		anchorProbe[2], anchorProbe[3] = target:GetLeft(), target:GetBottom()
		anchorProbe[4], anchorProbe[5] = target:GetSize()
		for fieldIndex = 1, #ANCHOR_LAYOUT_FIELDS do
			anchorProbe[fieldIndex + 5] = target[ANCHOR_LAYOUT_FIELDS[fieldIndex]]
		end
	else
		for slot = 2, ANCHOR_GEOMETRY_SLOTS do anchorProbe[slot] = nil end
	end
	anchorProbe[ANCHOR_EXTRA_SLOT] = extra

	local signature = holder._anchorSignature
	if not signature then
		signature = {}
		holder._anchorSignature = signature
	end
	local changed = false
	for slot = 1, ANCHOR_EXTRA_SLOT do
		local value = anchorProbe[slot]
		if signature[slot] ~= value then
			signature[slot] = value
			changed = true
		end
	end
	return changed
end

function UnitFrames.ApplyPosition(frame, unitType, index)
	local unitSettings = UnitFrames.GetUnitSettings(unitType)

	if unitType == 'targettarget' or unitType == 'focus' or unitType == 'pet'
	   or unitType == 'player' or unitType == 'target' then
		local anchorFrameName = unitSettings.anchorFrame
		local anchorTarget = BUI.ResolveAnchorFrame(anchorFrameName)
		UnitFrames.AnchorGeometryChanged(frame, anchorTarget, BUI.Anchor.GetAnchorHeight(unitSettings))
		if anchorTarget then
			local anchorSettings = {
				anchorFrame = anchorFrameName,
				anchorPoint = unitSettings.anchorPoint,
				anchorOffsetX = unitSettings.anchorOffsetX,
				anchorOffsetY = unitSettings.anchorOffsetY,
				matchAnchorWidth = unitSettings.matchAnchorWidth,
				horizontalMode = true, scaleOffsets = true,
			}
			BUI.Anchor.ApplyPosition(frame, anchorSettings)
			local anchorWidth = BUI.Anchor.GetAnchorWidth(frame, anchorSettings)
			if anchorWidth then frame:SetWidth(anchorWidth) end

			return
		end
	end

	local savedPosition = unitSettings.position
	local x = savedPosition.x
	local y = savedPosition.y
	local point = savedPosition.point
	local relPoint = savedPosition.relPoint

	if index and index > 1 then
		local castbarSettings = BUI.CastBar.GetSettings('boss')
		local castbarExtra = (castbarSettings and castbarSettings.enabled) and (castbarSettings.height + 1) or 0
		local offset = unitSettings.height + castbarExtra + unitSettings.spacing
		if unitSettings.growthDirection == 'UP' then
			y = y + ((index - 1) * offset)
		else
			y = y - ((index - 1) * offset)
		end
	end

	if point == 'CENTER' and relPoint == 'CENTER' then
		PlaceCentered(frame, Pixel.Scale(x), Pixel.Scale(y))
	else
		frame:ClearAllPoints()
		BUI.Anchor.PlaceOnPixels(frame, point, UIParent, relPoint, Pixel.Scale(x), Pixel.Scale(y))
	end
end

function UnitFrames.GetContextualOpacity()
	return BUI.Visibility.GetContextualOpacity("UnitFrames")
end

local function SetFrameOpacity(frame, opacity)
	frame._ufOpacity = opacity
	frame:SetAlpha(opacity)
end

BUI.Animation.RegisterProperty('ufOpacity',
	function(frame) return frame._ufOpacity or 1 end,
	function(frame, value) SetFrameOpacity(frame, value) end
)

local OPACITY_UNITS = {'player', 'target', 'targettarget', 'focus', 'pet'}

function UnitFrames.UpdateOpacity(instant)
	local opacity = UnitFrames.GetContextualOpacity() / 100
	local Animation = BUI.Animation
	local duration = instant and 0 or 0.3
	for _, unitType in ipairs(OPACITY_UNITS) do
		local unitFrame = UnitFrames[unitType]
		if unitFrame then Animation.To(unitFrame, 'ufOpacity', opacity, duration) end
	end
	for bossIndex = 1, 5 do
		local unitFrame = UnitFrames['boss' .. bossIndex]
		if unitFrame then Animation.To(unitFrame, 'ufOpacity', opacity, duration) end
	end
end

function UnitFrames.UpdateCombatBorder(frame, unitType, inCombat)
	if not frame then return end
	local settings = UnitFrames.GetSettings()
	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	local borderColor

	if unitSettings.aggroBorder and inCombat then
		local unit = frame.unit or unitType
		local threat = UnitThreatSituation(unit)
		if threat and threat >= 2 then
			borderColor = unitSettings.aggroBorderColor
		end
	end
	if not borderColor and unitSettings.combatBorder and inCombat then
		borderColor = unitSettings.combatBorderColor
	end
	if not borderColor then
		borderColor = (unitType == 'pet') and settings.petBorderColor or settings.borderColor
	end

	Pixel.SetBorderColor(frame, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	if frame.PowerBorder then
		SetColorTex(frame.PowerBorder, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
	end
end

do
	local GetDebuffDataByIndex = C_UnitAuras.GetDebuffDataByIndex
	local Engine = BUI.AuraEngine

	local DISPEL_BADGE_ATLAS = {
		Magic   = 'RaidFrame-Icon-DebuffMagic',
		Curse   = 'RaidFrame-Icon-DebuffCurse',
		Disease = 'RaidFrame-Icon-DebuffDisease',
		Poison  = 'RaidFrame-Icon-DebuffPoison',
		Bleed   = 'RaidFrame-Icon-DebuffBleed',
	}

	local _, playerClass = UnitClass('player')
	local IS_HUNTER = playerClass == 'HUNTER'
	local EMERGENCY_SALVE_SPELL_ID = 459517

	local feignSalveAuras = {}
	BUI._feignSalveAuras = feignSalveAuras
	local feignFirstID
	local feignSignature = 0

	local function ScanFeignSalveSet(unit)
		local count = 0
		for auraIndex = 1, 40 do
			local auraData = GetDebuffDataByIndex(unit, auraIndex)
			if not auraData then break end
			local dispelName, instanceID = auraData.dispelName, BUI.Tools.SafeNum(auraData.auraInstanceID)
			if instanceID and dispelName and not issecretvalue(dispelName) and (dispelName == 'Poison' or dispelName == 'Disease') then
				feignSalveAuras[instanceID] = true
				if not feignFirstID then feignFirstID = instanceID end
				count = count + 1
				feignSignature = bit.bxor(feignSignature, instanceID)
			end
		end
		feignSignature = feignSignature + count * 0x1000000
	end

	local function RefreshFeignSalveSet(unit)
		if unit ~= 'player' then return false end
		wipe(feignSalveAuras)
		feignFirstID, feignSignature = nil, 0
		if not (IS_HUNTER and C_SpellBook.IsSpellKnown(EMERGENCY_SALVE_SPELL_ID)) then return false end
		if BUI.Tools.ShouldAurasBeSecret() or BUI.Tools.AuraQueriesBlocked() then return false end
		ScanFeignSalveSet(unit)
		return feignFirstID ~= nil
	end

	local GetSelfCleanseTypes

	local function BuildCleanseCallouts()
		local list = {}

		if IS_HUNTER and C_SpellBook.IsSpellKnown(EMERGENCY_SALVE_SPELL_ID) then
			list[#list + 1] = { word = 'FD', spellID = 5384, types = { 'Poison', 'Disease' } }
			list[#list + 1] = { word = 'TURT', spellID = 186265, types = { 'Poison', 'Disease' } }
		end
		if playerClass == 'ROGUE' then
			list[#list + 1] = { word = 'CLOAK', spellID = 31224, types = { 'Magic' } }
		end
		if playerClass == 'DEATHKNIGHT' and C_SpellBook.IsSpellKnown(457574) then
			list[#list + 1] = { word = 'AMS', spellID = 48707, types = { 'Magic' } }
		end
		if playerClass == 'PALADIN' then
			list[#list + 1] = { word = 'BUBBLE', spellID = 642, types = { 'Magic' } }
		end
		local _, raceToken = UnitRace('player')
		if raceToken == 'Dwarf' then
			list[#list + 1] = { word = 'SF', spellID = 20594, types = { 'Magic', 'Curse', 'Disease', 'Poison', 'Bleed' } }
		end
		return list
	end

	local selfCleanseTypes, selfCleanseSignature, selfCleanseKeys = {}, nil, ''
	function GetSelfCleanseTypes()
		local signature = (C_SpellBook.IsSpellKnown(EMERGENCY_SALVE_SPELL_ID) and 1 or 0) + (C_SpellBook.IsSpellKnown(457574) and 2 or 0)
		if signature ~= selfCleanseSignature then
			selfCleanseSignature = signature
			wipe(selfCleanseTypes)
			for _, callout in ipairs(BuildCleanseCallouts()) do
				for _, dispelType in ipairs(callout.types) do selfCleanseTypes[dispelType] = true end
			end
			selfCleanseKeys = Engine.SortedKeys(selfCleanseTypes)
		end
		return selfCleanseTypes, selfCleanseKeys
	end

	local function IsCleanseReady(spellID)
		if not spellID then return true end
		local cooldown = C_Spell.GetSpellCooldown(spellID)
		if not cooldown then return true end
		local enabled, active = cooldown.isEnabled, cooldown.isActive
		if issecretvalue(enabled) or issecretvalue(active) then return nil end
		if enabled == false then return false end
		return not active
	end

	UnitFrames.DispelViaEngine = Engine.Available and true or false

	local HL_TYPES = { 'Magic', 'Curse', 'Disease', 'Poison', 'Bleed' }
	local TYPE_ICON_GAP = 6
	function UnitFrames.DispelTypeColor(typeName)
		return Engine.DispelColorRGB(typeName)
	end

	local typeRowHost, typeRowContainer
	local typeRowKits = {}
	local typeRowRestylePending = false

	local TYPE_ROW_BASE_Y = 44

	local function PlaceTypeRowHost()
		if not typeRowHost then return end
		local unitSettings = UnitFrames.GetUnitSettings('player')
		typeRowHost:ClearAllPoints()
		typeRowHost:SetPoint('CENTER', UIParent, 'CENTER',
			Pixel.Scale(unitSettings.debuffHighlightBadgeOffsetX),
			Pixel.Scale(TYPE_ROW_BASE_Y + unitSettings.debuffHighlightBadgeOffsetY))
	end

	local function TypeRowHost()
		if typeRowHost then return typeRowHost end
		typeRowHost = CreateFrame('Frame', nil, UIParent)
		typeRowHost:SetSize(Pixel.Scale(1), Pixel.Scale(1))
		typeRowHost:SetFrameStrata('HIGH')
		typeRowHost:EnableMouse(false)
		PlaceTypeRowHost()
		return typeRowHost
	end

	local function TypeRowIconSize()
		local unitSettings = UnitFrames.GetUnitSettings('player')
		return unitSettings.debuffHighlightBadgeSize
	end

	local function StyleTypeRowKit(kit)
		local settings = UnitFrames.GetSettings()
		local size = Pixel.Scale(TypeRowIconSize())
		kit.button:SetSize(size, size)
		kit.icon:ClearAllPoints()
		kit.icon:SetAllPoints(kit.button)
		if settings.dispelRecolor then
			kit.icon:SetDesaturated(true)
			kit.icon:SetVertexColor(UnitFrames.DispelTypeColor(kit.typeName))
		else
			kit.icon:SetDesaturated(false)
			kit.icon:SetVertexColor(1, 1, 1)
		end
	end

	local function RestyleTypeRow()
		if BUI.Tools.ShouldAurasBeSecret() then
			typeRowRestylePending = true
			return
		end
		typeRowRestylePending = false
		for kitIndex = 1, #typeRowKits do
			StyleTypeRowKit(typeRowKits[kitIndex])
		end
	end

	local function DrainTypeRowRestyle()
		if typeRowRestylePending then RestyleTypeRow() end
	end

	local function TypeRowInitializer(typeName, slot)
		return function(button)
			local kit = { typeName = typeName, slot = slot, button = button }
			kit.icon = button:CreateTexture(nil, 'OVERLAY', nil, 7)
			kit.icon:SetAtlas(DISPEL_BADGE_ATLAS[typeName])
			typeRowKits[#typeRowKits + 1] = kit
			StyleTypeRowKit(kit)
			if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
			if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
		end
	end

	local function EnsureTypeRowGroups(container)
		if not container.AddAuraGroup then return end
		local unitSettings = UnitFrames.GetUnitSettings('player')
		local byMe = unitSettings.debuffHighlightClassFilter ~= false
		local covered = byMe and GetSelfCleanseTypes() or nil
		local groups = container._rowGroups
		for slot = 1, #HL_TYPES do
			local typeName = HL_TYPES[slot]
			local wantByme = byMe and not (covered and covered[typeName])
			local plainKey, bymeKey = typeName, typeName .. '#byme'
			local activeKey = wantByme and bymeKey or plainKey
			local function SyncVariant(variantKey)
				local info = groups[variantKey]
				local wantActive = variantKey == activeKey
				if info then
					if info.active ~= wantActive then
						info.active = wantActive
						if container.SetAuraGroupMaxFrameCount then
							container:SetAuraGroupMaxFrameCount(info.key, wantActive and 1 or 0)
						end
					end
				elseif wantActive then
					container._rowSeq = (container._rowSeq or 0) + 1
					local key = 'row' .. container._rowSeq
					local filter = variantKey == bymeKey and 'HARMFUL|RAID_PLAYER_DISPELLABLE' or 'HARMFUL'
					local size = TypeRowIconSize()
					container:AddAuraGroup(key, filter, {
						maxFrameCount = 1,
						initializeFrame = TypeRowInitializer(typeName, slot),
						candidateFilters = { includeDispelTypes = { [typeName] = true } },
						layout = {
							elementWidth = size, elementHeight = size,
							elementSpacing = TYPE_ICON_GAP, lineSpacing = TYPE_ICON_GAP,
							layoutIndex = slot,
						},
					})
					groups[variantKey] = { key = key, active = true }
				end
			end
			SyncVariant(plainKey)
			SyncVariant(bymeKey)
		end
	end

	local HIGHLIGHT_SETTING_INPUTS = 12
	local HIGHLIGHT_INPUT_COUNT = HIGHLIGHT_SETTING_INPUTS + #HL_TYPES * 3
	local highlightInputs = {}

	local function GatherHighlightInputs(unitSettings)
		local settings = UnitFrames.GetSettings()
		local classFilter = unitSettings.debuffHighlightClassFilter ~= false
		highlightInputs[1] = classFilter
		highlightInputs[2] = unitSettings.debuffHighlightBadgeSize
		highlightInputs[3] = unitSettings.debuffHighlightBadgeOffsetX
		highlightInputs[4] = unitSettings.debuffHighlightBadgeOffsetY
		highlightInputs[5] = settings.dispelRecolor and true or false
		highlightInputs[6] = settings.dispelBlend and true or false
		highlightInputs[7] = settings.dispelOpacity
		highlightInputs[8] = unitSettings.debuffHighlightBar and true or false
		highlightInputs[9] = unitSettings.debuffHighlightStyle
		highlightInputs[10] = settings.dispelFadeMiddle
		highlightInputs[11] = settings.dispelFadeFar
		highlightInputs[12] = classFilter and select(2, GetSelfCleanseTypes()) or ''
		for typeIndex = 1, #HL_TYPES do
			local slot = HIGHLIGHT_SETTING_INPUTS + (typeIndex - 1) * 3
			highlightInputs[slot + 1], highlightInputs[slot + 2], highlightInputs[slot + 3] = UnitFrames.DispelTypeColor(HL_TYPES[typeIndex])
		end
	end

	local function HighlightInputsChanged(snapshot)
		local changed = false
		for inputIndex = 1, HIGHLIGHT_INPUT_COUNT do
			local value = highlightInputs[inputIndex]
			if snapshot[inputIndex] ~= value then
				snapshot[inputIndex] = value
				changed = true
			end
		end
		return changed
	end

	local function ConfigureTypeRow(wanted)
		if not wanted then
			if typeRowContainer then
				typeRowContainer:Hide()
				Engine.BindUnit(typeRowContainer, nil)
				wipe(typeRowContainer._highlightInputs)
			end
			return
		end
		if not typeRowContainer then
			local host = TypeRowHost()
			typeRowContainer = Engine.NewContainer(host, true, 1)
			typeRowContainer:SetPoint('CENTER', host, 'CENTER')
			typeRowContainer._rowGroups = {}
			typeRowContainer._highlightInputs = {}
		end
		if HighlightInputsChanged(typeRowContainer._highlightInputs) then
			PlaceTypeRowHost()
			local size = TypeRowIconSize()
			Engine.ApplyFlowLayout(typeRowContainer, {
				growX = 'RIGHT', growY = 'DOWN',
				gap = TYPE_ICON_GAP, size = size, perRow = #HL_TYPES,
			})
			EnsureTypeRowGroups(typeRowContainer)
			RestyleTypeRow()
		end
		typeRowContainer:Show()
		Engine.BindUnit(typeRowContainer, 'player')
	end

	local WHITE8X8 = [[Interface\Buttons\WHITE8X8]]
	local FADE_TEXTURE = BUI.C.FADE_TEXTURE
	local frameKits = setmetatable({}, { __mode = 'k' })
	local framePending = {}

	local function OverlappingAbsorb(frame)
		local settings = UnitFrames.GetSettings()
		if frame.Absorb and settings.shieldEnabled ~= false and settings.shieldDirection == 'left' then return frame.Absorb end
		if frame.HealAbsorb and settings.healAbsorbEnabled ~= false and settings.healAbsorbDirection == 'left' then return frame.HealAbsorb end
	end

	local function PrepFillTexture(texture, asset, blend, alpha)
		texture:ClearAllPoints()
		texture:SetTexture(asset)
		texture:SetBlendMode(blend)
		texture:SetAlpha(alpha)
	end

	function UnitFrames.StyleDispelFill(kit, style, healthTexture, rightEdge, rightSide, alpha)
		local settings = UnitFrames.GetSettings()
		local blend = settings.dispelBlend and 'ADD' or 'BLEND'
		local half = style == 'top' or style == 'bottom'
		local fill, fade, shade = kit.fill, kit.fade, kit.shade
		PrepFillTexture(fill, half and FADE_TEXTURE or WHITE8X8, blend, alpha)
		PrepFillTexture(fade, FADE_TEXTURE, blend, alpha)
		PrepFillTexture(shade, FADE_TEXTURE, 'BLEND', (half and alpha > 0) and settings.dispelFadeDark / 100 or 0)
		shade:SetVertexColor(0, 0, 0)
		if style == 'top' then
			shade:SetPoint('TOPLEFT', healthTexture, 'LEFT')
			shade:SetPoint('BOTTOMRIGHT', rightEdge, 'BOTTOM' .. rightSide)
			shade:SetTexCoord(0, 1, 1, 0)
		else
			shade:SetPoint('TOPLEFT', healthTexture, 'TOPLEFT')
			shade:SetPoint('BOTTOMRIGHT', rightEdge, rightSide)
			shade:SetTexCoord(0, 1, 0, 1)
		end
		if not half then
			fill:SetTexCoord(0, 1, 0, 1)
			fill:SetPoint('TOPLEFT', healthTexture, 'TOPLEFT')
			fill:SetPoint('BOTTOMRIGHT', rightEdge, 'BOTTOM' .. rightSide)
			fade:SetTexCoord(0, 1, 1, 1)
			fade:SetPoint('TOPLEFT', healthTexture, 'TOPLEFT')
			fade:SetPoint('BOTTOMRIGHT', rightEdge, 'BOTTOM' .. rightSide)
			return
		end
		local middle = settings.dispelFadeMiddle / 100
		local far = math.min(settings.dispelFadeFar / 100, middle)
		if style == 'bottom' then
			fill:SetPoint('TOPLEFT', healthTexture, 'LEFT')
			fill:SetPoint('BOTTOMRIGHT', rightEdge, 'BOTTOM' .. rightSide)
			fill:SetTexCoord(0, 1, 1 - middle, 0)
			fade:SetPoint('TOPLEFT', healthTexture, 'TOPLEFT')
			fade:SetPoint('BOTTOMRIGHT', rightEdge, rightSide)
			fade:SetTexCoord(0, 1, 1 - far, 1 - middle)
		else
			fill:SetPoint('TOPLEFT', healthTexture, 'TOPLEFT')
			fill:SetPoint('BOTTOMRIGHT', rightEdge, rightSide)
			fill:SetTexCoord(0, 1, 0, 1 - middle)
			fade:SetPoint('TOPLEFT', healthTexture, 'LEFT')
			fade:SetPoint('BOTTOMRIGHT', rightEdge, 'BOTTOM' .. rightSide)
			fade:SetTexCoord(0, 1, 1 - middle, 1 - far)
		end
	end

	local function AnchorDispelFill(kit, frame, alpha)
		local healthTexture = frame.Health:GetStatusBarTexture()
		local style = UnitFrames.GetUnitSettings('player').debuffHighlightStyle
		local absorb = OverlappingAbsorb(frame)
		local rightEdge, rightSide = healthTexture, 'RIGHT'
		if absorb then rightEdge, rightSide = absorb:GetStatusBarTexture(), 'LEFT' end
		UnitFrames.StyleDispelFill(kit, style, healthTexture, rightEdge, rightSide, alpha)
	end

	local function AnchorFrameEdges(edges, to)
		local thickness = Pixel.Scale(Pixel.ClampBorder(1))
		edges[1]:ClearAllPoints()
		edges[1]:SetPoint('TOPLEFT', to, 'TOPLEFT')
		edges[1]:SetPoint('BOTTOMRIGHT', to, 'TOPRIGHT', 0, -thickness)
		edges[2]:ClearAllPoints()
		edges[2]:SetPoint('BOTTOMLEFT', to, 'BOTTOMLEFT')
		edges[2]:SetPoint('TOPRIGHT', to, 'BOTTOMRIGHT', 0, thickness)
		edges[3]:ClearAllPoints()
		edges[3]:SetPoint('TOPLEFT', to, 'TOPLEFT', 0, -thickness)
		edges[3]:SetPoint('BOTTOMRIGHT', to, 'BOTTOMLEFT', thickness, thickness)
		edges[4]:ClearAllPoints()
		edges[4]:SetPoint('TOPRIGHT', to, 'TOPRIGHT', 0, -thickness)
		edges[4]:SetPoint('BOTTOMLEFT', to, 'BOTTOMRIGHT', -thickness, thickness)
	end

	local function PaintDispelVisual(frame, kit, typeName, forceOn)
		local wantFill = forceOn or UnitFrames.GetUnitSettings('player').debuffHighlightBar
		AnchorDispelFill(kit, frame, wantFill and UnitFrames.GetSettings().dispelOpacity / 100 or 0)
		local red, green, blue = UnitFrames.DispelTypeColor(typeName)
		kit.fill:SetVertexColor(red, green, blue)
		kit.fade:SetVertexColor(red, green, blue)
	end

	local function StyleFrameKit(frame, kit)
		PaintDispelVisual(frame, kit, kit.typeName, false)
	end

	local function RestyleFrameKits(frame)
		local kits = frameKits[frame]
		if not kits then return end
		if BUI.Tools.ShouldAurasBeSecret() then
			framePending[frame] = true
			return
		end
		framePending[frame] = nil
		for kitIndex = 1, #kits do StyleFrameKit(frame, kits[kitIndex]) end
	end

	local function DrainFrameRestyle()
		for frame in pairs(framePending) do
			framePending[frame] = nil
			RestyleFrameKits(frame)
		end
	end

	local function FrameInitializer(frame, typeName, priority)
		return function(button)
			local kit = {
				typeName = typeName,
				fill = button:CreateTexture(nil, 'ARTWORK', nil, priority),
				fade = button:CreateTexture(nil, 'ARTWORK', nil, priority),
				shade = button:CreateTexture(nil, 'ARTWORK', nil, priority),
			}
			local kits = frameKits[frame]
			if not kits then kits = {}; frameKits[frame] = kits end
			kits[#kits + 1] = kit
			StyleFrameKit(frame, kit)
			if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
			if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
		end
	end

	local function EnsureFrameGroups(container, frame)
		if not container.AddAuraGroup then return end
		local unitSettings = UnitFrames.GetUnitSettings('player')
		local byMe = unitSettings.debuffHighlightClassFilter ~= false
		local covered = byMe and GetSelfCleanseTypes() or nil
		local groups = container._fgGroups
		for typeIndex = 1, #HL_TYPES do
			local typeName = HL_TYPES[typeIndex]
			local wantByme = byMe and not (covered and covered[typeName])
			local plainKey, bymeKey = typeName, typeName .. '#byme'
			local activeKey = wantByme and bymeKey or plainKey
			local function SyncVariant(variantKey)
				local info = groups[variantKey]
				local wantActive = variantKey == activeKey
				if info then
					if info.active ~= wantActive then
						info.active = wantActive
						if container.SetAuraGroupMaxFrameCount then
							container:SetAuraGroupMaxFrameCount(info.key, wantActive and 1 or 0)
						end
					end
				elseif wantActive then
					container._fgSeq = (container._fgSeq or 0) + 1
					local key = 'fg' .. container._fgSeq
					local filter = variantKey == bymeKey and 'HARMFUL|RAID_PLAYER_DISPELLABLE' or 'HARMFUL'
					container:AddAuraGroup(key, filter, {
						maxFrameCount = 1,
						initializeFrame = FrameInitializer(frame, typeName, #HL_TYPES - typeIndex + 1),
						candidateFilters = { includeDispelTypes = { [typeName] = true } },
					})
					groups[variantKey] = { key = key, active = true }
				end
			end
			SyncVariant(plainKey)
			SyncVariant(bymeKey)
		end
	end

	local function ConfigureFrameColors(frame, wanted)
		local container = frame._dispelFrameHL
		if not wanted then
			if container then
				container:Hide()
				Engine.BindUnit(container, nil)
				wipe(container._highlightInputs)
			end
			return
		end
		if not container then
			container = Engine.NewContainer(frame.Health, true, 3)
			container:SetPoint('TOPLEFT', frame, 'TOPLEFT')
			container._fgGroups = {}
			container._highlightInputs = {}
			frame._dispelFrameHL = container
		end
		if HighlightInputsChanged(container._highlightInputs) then
			EnsureFrameGroups(container, frame)
			RestyleFrameKits(frame)
		end
		container:Show()
		Engine.BindUnit(container, frame.unit or 'player')
	end

	local previewPin, previewKit, previewIconHost
	local previewIcons = {}

	local function PreviewTypeIndex()
		for typeIndex = 1, #HL_TYPES do
			if HL_TYPES[typeIndex] == previewPin then return typeIndex end
		end
		return 1
	end

	local function EnsurePreviewKit()
		local frame = UnitFrames.player
		if not frame or not frame.Health then return nil end
		if previewKit and previewKit.frame == frame then return previewKit end
		local host = CreateFrame('Frame', nil, frame.Health)
		host:SetFrameLevel(frame.Health:GetFrameLevel() + 4)
		host:EnableMouse(false)
		host:Hide()
		local kit = { frame = frame, host = host }
		kit.fill = host:CreateTexture(nil, 'ARTWORK', nil, 6)
		kit.fade = host:CreateTexture(nil, 'ARTWORK', nil, 6)
		kit.shade = host:CreateTexture(nil, 'ARTWORK', nil, 6)
		previewKit = kit
		return kit
	end

	local function EnsurePreviewIcons()
		if previewIconHost then return previewIconHost end
		local host = TypeRowHost()
		previewIconHost = CreateFrame('Frame', nil, host)
		previewIconHost:SetAllPoints(host)
		previewIconHost:EnableMouse(false)
		previewIconHost:Hide()
		for typeIndex = 1, #HL_TYPES do
			local texture = previewIconHost:CreateTexture(nil, 'OVERLAY', nil, 7)
			texture:SetAtlas(DISPEL_BADGE_ATLAS[HL_TYPES[typeIndex]])
			previewIcons[typeIndex] = texture
		end
		return previewIconHost
	end

	local function HidePreview()
		if previewKit then previewKit.host:Hide() end
		if previewIconHost then previewIconHost:Hide() end
	end

	function UnitFrames.RefreshDispelPreview()
		if not previewPin then HidePreview() return end
		local recolor = UnitFrames.GetSettings().dispelRecolor
		local active = PreviewTypeIndex()

		local kit = EnsurePreviewKit()
		if kit then
			PaintDispelVisual(kit.frame, kit, HL_TYPES[active], true)
			kit.host:Show()
		end

		local host = EnsurePreviewIcons()
		local size = TypeRowIconSize()
		local typeCount = #HL_TYPES
		local left = -((typeCount * size + (typeCount - 1) * TYPE_ICON_GAP) / 2) + size / 2
		for typeIndex = 1, typeCount do
			local texture = previewIcons[typeIndex]
			texture:SetSize(Pixel.Scale(size), Pixel.Scale(size))
			texture:ClearAllPoints()
			texture:SetPoint('CENTER', host, 'CENTER', Pixel.Scale(left + (typeIndex - 1) * (size + TYPE_ICON_GAP)), 0)
			if recolor then
				texture:SetDesaturated(true)
				texture:SetVertexColor(UnitFrames.DispelTypeColor(HL_TYPES[typeIndex]))
			else
				texture:SetDesaturated(false)
				texture:SetVertexColor(1, 1, 1)
			end
			texture:SetAlpha(typeIndex == active and 1 or 0.35)
		end
		host:Show()
	end

	function UnitFrames.PinDispelPreview(typeName)
		previewPin = typeName
		UnitFrames.RefreshDispelPreview()
	end

	function UnitFrames.UnpinDispelPreview()
		previewPin = nil
		HidePreview()
	end

	local DISPEL_PREVIEW_SECONDS = 1.5
	local previewTicker, previewCycle = nil, 0

	local StepDispelPreview = BUI.Profiler.Wrap('UnitFrames dispel preview', function()
		previewCycle = previewCycle % #HL_TYPES + 1
		UnitFrames.PinDispelPreview(HL_TYPES[previewCycle])
	end)

	function UnitFrames.StopDispelPreview()
		if previewTicker then previewTicker:Cancel() end
		previewTicker = nil
		UnitFrames.UnpinDispelPreview()
	end

	function UnitFrames.StartDispelPreview()
		UnitFrames.StopDispelPreview()
		previewCycle = 0
		StepDispelPreview()
		previewTicker = C_Timer.NewTicker(DISPEL_PREVIEW_SECONDS, StepDispelPreview)
	end

	function UnitFrames.IsDispelPreviewing() return previewTicker ~= nil end

	local CALLOUT_ICON, CALLOUT_FONT, CALLOUT_PAD = 46, 24, 6

	local calloutHost
	local calloutCells = {}
	local measureFontString

	local function CalloutHost()
		if calloutHost then return calloutHost end
		calloutHost = CreateFrame('Frame', nil, UIParent)
		calloutHost:SetSize(Pixel.Scale(1), Pixel.Scale(1))
		calloutHost:SetPoint('CENTER', UIParent, 'CENTER', 0, Pixel.Scale(130))
		calloutHost:SetFrameStrata('HIGH')
		calloutHost:EnableMouse(false)
		return calloutHost
	end

	local function MeasureWord(word)
		if not measureFontString then
			measureFontString = CalloutHost():CreateFontString(nil, 'OVERLAY')
			measureFontString:Hide()
		end
		Pixel.ApplyFont(measureFontString, CALLOUT_FONT, BUI.GetGlobalFont(), 'OUTLINE')
		measureFontString:SetText(word)
		return measureFontString:GetStringWidth() or 0
	end

	local calloutCellWidth = CALLOUT_ICON

	local function BuildCalloutList()
		local list = BuildCleanseCallouts()
		local widest = CALLOUT_ICON
		for _, callout in ipairs(list) do
			local wordWidth = MeasureWord(callout.word)
			if wordWidth > widest then widest = wordWidth end
		end
		calloutCellWidth = widest + CALLOUT_PAD
		return list
	end

	local CALLOUT_EDGE_MAP = {
		[1] = { 1, 1, 1, 1 },
		[2] = { 1, 2, 1, 2 },
		[3] = { 1, 2, 3, 3 },
		[4] = { 1, 2, 3, 4 },
	}

	local function PaintCalloutRing(part)
		if not part.edges then return end
		local map = part.types and CALLOUT_EDGE_MAP[#part.types]
		for edgeIndex = 1, 4 do
			if map then
				local red, green, blue = UnitFrames.DispelTypeColor(part.types[map[edgeIndex]])
				part.edges[edgeIndex]:SetColorTexture(red, green, blue, 1)
				part.edges[edgeIndex]:SetAlpha(1)
			else
				part.edges[edgeIndex]:SetAlpha(0)
			end
		end
	end

	local calloutContainer

	local function ApplyCellReadiness(cell)
		local ready = IsCleanseReady(cell.part.spellID)
		local mark = ready ~= false and 1 or 0
		if cell.lastPick == mark then return end
		cell.lastPick = mark
		if calloutContainer and calloutContainer.SetAuraGroupMaxFrameCount then
			calloutContainer:SetAuraGroupMaxFrameCount(cell.part.groupKey, mark)
		end
	end

	local calloutPaletteStamp, calloutRepaintPending

	local function RepaintCalloutRings()
		if BUI.Tools.ShouldAurasBeSecret() then
			calloutRepaintPending = true
			return
		end
		calloutRepaintPending = false
		for _, cell in ipairs(calloutCells) do
			PaintCalloutRing(cell.part)
		end
	end

	local function DrainCalloutRepaint()
		if calloutRepaintPending then RepaintCalloutRings() end
	end

	local function ApplyCalloutReadiness()
		if not InCombatLockdown() then
			local stamp = Engine.DispelPaletteStamp()
			if stamp ~= calloutPaletteStamp then
				calloutPaletteStamp = stamp
				RepaintCalloutRings()
			end
		end
		for _, cell in ipairs(calloutCells) do
			ApplyCellReadiness(cell)
		end
	end

	local function CalloutPartInitializer(part)
		return function(button)
			button:SetSize(Pixel.Scale(calloutCellWidth), Pixel.Scale(CALLOUT_ICON + 2))
			local outline = button:CreateTexture(nil, 'ARTWORK')
			outline:SetColorTexture(0, 0, 0, 1)
			outline:SetSize(Pixel.Scale(CALLOUT_ICON + 2), Pixel.Scale(CALLOUT_ICON + 2))
			outline:SetPoint('CENTER', button, 'CENTER', 0, 0)
			local edges = {}
			for edgeIndex = 1, 4 do edges[edgeIndex] = button:CreateTexture(nil, 'ARTWORK', nil, 1) end
			AnchorFrameEdges(edges, outline)
			local icon = button:CreateTexture(nil, 'OVERLAY', nil, 1)
			icon:SetTexture(C_Spell.GetSpellTexture(part.spellID))
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			icon:SetSize(Pixel.Scale(CALLOUT_ICON), Pixel.Scale(CALLOUT_ICON))
			icon:SetPoint('CENTER', outline, 'CENTER', 0, 0)
			local name = button:CreateFontString(nil, 'OVERLAY')
			Pixel.ApplyFont(name, CALLOUT_FONT, BUI.GetGlobalFont(), 'OUTLINE')
			name:SetText(part.word)
			name:SetPoint('TOP', outline, 'BOTTOM', 0, Pixel.Scale(-4))
			part.edges = edges
			PaintCalloutRing(part)
			if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
			if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
		end
	end

	local QueueCalloutReadiness = BUI.Dispatcher.NewDelayed(ApplyCalloutReadiness, 0.25, 'Callout readiness')

	local calloutEventsOn
	local function StartCalloutEvents()
		if calloutEventsOn then return end
		calloutEventsOn = true
		BUI.Events:Register('SPELL_UPDATE_COOLDOWN', 'UF.DispelCallout.CD', QueueCalloutReadiness)
	end

	local function StopCalloutEvents()
		if not calloutEventsOn then return end
		calloutEventsOn = false
		BUI.Events:Unregister('SPELL_UPDATE_COOLDOWN', 'UF.DispelCallout.CD')
	end

	local function BuildCallouts()
		local callouts = BuildCalloutList()
		if #callouts == 0 then return end
		local host = CalloutHost()
		local cellHeight = CALLOUT_ICON + 2
		calloutContainer = Engine.NewContainer(host, true, 1)
		calloutContainer:SetPoint('CENTER', host, 'CENTER')
		Engine.ApplyFlowLayout(calloutContainer, {
			growX = 'RIGHT', growY = 'DOWN',
			gap = CALLOUT_PAD, size = calloutCellWidth, perRow = #callouts,
		})
		if not calloutContainer.AddAuraGroup then return end
		for calloutIndex = 1, #callouts do
			local callout = callouts[calloutIndex]
			local types = {}
			for _, dispelType in ipairs(callout.types) do types[dispelType] = true end
			local part = {
				word = callout.word, spellID = callout.spellID, types = callout.types,
				groupKey = 'co' .. calloutIndex,
			}
			calloutContainer:AddAuraGroup(part.groupKey, 'HARMFUL', {
				maxFrameCount = 1,
				initializeFrame = CalloutPartInitializer(part),
				candidateFilters = { includeDispelTypes = types },
				layout = {
					elementWidth = calloutCellWidth, elementHeight = cellHeight,
					elementSpacing = CALLOUT_PAD, lineSpacing = CALLOUT_PAD,
					layoutIndex = calloutIndex,
				},
			})
			calloutCells[#calloutCells + 1] = { part = part }
		end
	end

	local calloutTalentSignature

	local function ResetCallouts()
		if calloutContainer then
			Engine.BindUnit(calloutContainer, nil)
			if calloutContainer.SetAuraGroupMaxFrameCount then
				for _, cell in ipairs(calloutCells) do
					calloutContainer:SetAuraGroupMaxFrameCount(cell.part.groupKey, 0)
				end
			end
			calloutContainer:Hide()
			calloutContainer = nil
		end
		wipe(calloutCells)
		StopCalloutEvents()
	end

	local function ConfigureCallouts(wanted)
		local _, signature = GetSelfCleanseTypes()
		if calloutTalentSignature and signature ~= calloutTalentSignature then ResetCallouts() end
		calloutTalentSignature = signature

		if not wanted then
			StopCalloutEvents()
			if calloutContainer then
				calloutContainer:Hide()
				Engine.BindUnit(calloutContainer, nil)
			end
			return
		end
		if #calloutCells == 0 then
			if BUI.Tools.ShouldAurasBeSecret() or BUI.Tools.AuraQueriesBlocked() then return end
			BuildCallouts()
			if #calloutCells == 0 then return end
			ApplyCalloutReadiness()
		end
		StartCalloutEvents()
		if calloutContainer then
			calloutContainer:Show()
			Engine.BindUnit(calloutContainer, 'player')
		end
	end

	if UnitFrames.DispelViaEngine then
		BUI.Events:Register('PLAYER_REGEN_ENABLED', 'UF.DispelRow.Restyle', function() BUI.Events:AfterCombatSettled(DrainTypeRowRestyle, 'UF.DispelRow.Restyle') end)
		BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.DispelRow.Restyle', DrainTypeRowRestyle)
		BUI.Events:Register('PLAYER_REGEN_ENABLED', 'UF.DispelFrame.Restyle', function() BUI.Events:AfterCombatSettled(DrainFrameRestyle, 'UF.DispelFrame.Restyle') end)
		BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.DispelFrame.Restyle', DrainFrameRestyle)
		BUI.Events:Register('PLAYER_REGEN_ENABLED', 'UF.DispelCallout.Repaint', function() BUI.Events:AfterCombatSettled(DrainCalloutRepaint, 'UF.DispelCallout.Repaint') end)
		BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.DispelCallout.Repaint', DrainCalloutRepaint)
	end

	function UnitFrames.UpdateDebuffHighlight(frame)
		if not frame then return end
		local unitSettings = UnitFrames.GetUnitSettings('player')

		if UnitFrames.DispelViaEngine then
			local badgeWanted = unitSettings.debuffHighlightBadge ~= false
			local frameColorsWanted = unitSettings.debuffHighlightBar and true or false
			if badgeWanted or frameColorsWanted then GatherHighlightInputs(unitSettings) end
			ConfigureTypeRow(badgeWanted)
			ConfigureCallouts(unitSettings.debuffHighlightTypeText and true or false)
			ConfigureFrameColors(frame, frameColorsWanted)
			return
		end

		RefreshFeignSalveSet(frame.unit or 'player')
		if feignSignature ~= frame._feignSig then
			frame._feignSig = feignSignature
			if frame.Debuffs and frame.Debuffs.ForceUpdate then frame.Debuffs:ForceUpdate() end
		end
	end

	function UnitFrames.FollowDebuffHighlightUnit(frame)
		local container = frame._dispelFrameHL
		if container and container._buiUnit and container._buiUnit ~= frame.unit then
			Engine.BindUnit(container, frame.unit)
		end
	end

	local function ScanPlayer()
		UnitFrames.UpdateDebuffHighlight(UnitFrames.player)
	end

	BUI.Tools.OnAuraQueriesUnblocked(ScanPlayer, 'Unit frame debuff highlight')
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.DebuffHighlight.Scan', ScanPlayer)

	if UnitFrames.DispelViaEngine then
		BUI.Events:OnTalentBurst('UF.DebuffHighlight', ScanPlayer)
	else
		local flushFrame = CreateFrame('Frame')
		flushFrame:Hide()
		flushFrame:SetScript('OnUpdate', BUI.Profiler.Wrap('UnitFrames.Core debuff highlight', function(self)
			self:Hide()
			ScanPlayer()
		end))
		BUI.Events:RegisterUnit('UNIT_AURA', 'player', 'UF.DebuffHighlight', function(_, _, updateInfo)
			if updateInfo then
				local full = updateInfo.isFullUpdate
				local added = updateInfo.addedAuras
				local removed = updateInfo.removedAuraInstanceIDs
				if not (issecretvalue(full) or issecretvalue(added) or issecretvalue(removed))
					and not full and not added and not removed then
					return
				end
			end
			flushFrame:Show()
		end)
	end
end

do
	local pendingCombatEdge
	local DispatchCombatBorders = BUI.Dispatcher.New(function()
		local inCombat = pendingCombatEdge == 'PLAYER_REGEN_DISABLED'
		pendingCombatEdge = nil
		for _, unitType in ipairs(OPACITY_UNITS) do
			local unitFrame = UnitFrames[unitType]
			if unitFrame then UnitFrames.UpdateCombatBorder(unitFrame, unitType, inCombat) end
		end
		if not inCombat then UnitFrames.RefreshAnchoredFrames() end
	end, 'UF.CombatBorder')

	local function OnCombatBorderEvent(event)
		if event == 'UNIT_THREAT_SITUATION_UPDATE' then
			if not InCombatLockdown() then return end
			local playerFrame = UnitFrames.player
			if playerFrame then
				UnitFrames.UpdateCombatBorder(playerFrame, 'player', true)
			end
			return
		end
		pendingCombatEdge = event
		DispatchCombatBorders()
	end
	BUI.Events:Register('PLAYER_REGEN_ENABLED', 'UF.CombatBorder', OnCombatBorderEvent)
	BUI.Events:Register('PLAYER_REGEN_DISABLED', 'UF.CombatBorder', OnCombatBorderEvent)
	BUI.Events:RegisterUnit('UNIT_THREAT_SITUATION_UPDATE', 'player', 'UF.CombatBorder', OnCombatBorderEvent)
end

BUI.Visibility.Register("UnitFrames", function(instant)
	UnitFrames.UpdateOpacity(instant)
end, true)

