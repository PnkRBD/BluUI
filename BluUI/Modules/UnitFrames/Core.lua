local _, BUI = ...

local Pixel = BUI.Pixel
local Motion = BUI.BUILibClient.Motion

local CreateFrame = CreateFrame

local UIParent = UIParent
local UnitClass = UnitClass
local UnitIsPlayer = UnitIsPlayer
local UnitPowerType = UnitPowerType
local UnitReaction = UnitReaction

local SetColorTex = BUI.Tools.SetColorTex
local UnitFrames = {}
BUI.UnitFrames = UnitFrames

local UNIT_CONFIG = {
	player = { showPower = true, showPowerDefault = true, hasCombatBorder = true, hasAuras = true },
	target = { showPower = true, showPowerDefault = true, hasAuras = true },
	targettarget = { showPower = false, showPowerDefault = false, hasAuras = true },
	focus = { showPower = true, showPowerDefault = true, hasAuras = true },
	pet = { showPower = true, showPowerDefault = false },
	boss = { showPower = true, showPowerDefault = false, hasAuras = true },
}

local unitConfigCache = {}
function UnitFrames.GetUnitConfig(unit)
	local key = unitConfigCache[unit]
	if not key then
		key = unit:gsub('%d+$', '')
		unitConfigCache[unit] = key
	end
	return UNIT_CONFIG[key]
end

local WHITE_TEX = [[Interface\Buttons\WHITE8x8]]
local STRIPES_TEXTURE = BUI.C.MEDIA_PATH .. 'stripes.tga'

function UnitFrames.ApplyAbsorbVisual(bar, textureKey, color, alpha)
	if bar.Excess then UnitFrames.ApplyAbsorbVisual(bar.Excess, textureKey, color, alpha) end
	bar:SetStatusBarTexture(WHITE_TEX)
	bar:SetStatusBarColor(color[1], color[2], color[3], alpha or color[4])
	local base = bar:GetStatusBarTexture()
	base:SetBlendMode('BLEND')

	if textureKey == 'Solid' then
		if bar._absOverlay then bar._absOverlay:Hide() end
		return
	end

	local overlay = bar._absOverlay
	if not overlay then overlay = bar:CreateTexture(nil, 'OVERLAY'); bar._absOverlay = overlay end
	overlay:SetTexture(STRIPES_TEXTURE, 'REPEAT', 'REPEAT')
	overlay:SetHorizTile(true); overlay:SetVertTile(true)
	overlay:SetBlendMode('BLEND')
	overlay:SetVertexColor(1, 1, 1)
	overlay:SetAlpha(1)
	overlay:ClearAllPoints()
	overlay:SetAllPoints(base)
	overlay:Show()
end

local FILLS = {
	RIGHT = { orientation = 'HORIZONTAL', reverse = false, start = 'LEFT',   lead = 'RIGHT' },
	LEFT  = { orientation = 'HORIZONTAL', reverse = true,  start = 'RIGHT',  lead = 'LEFT' },
	UP    = { orientation = 'VERTICAL',   reverse = false, start = 'BOTTOM', lead = 'TOP' },
	DOWN  = { orientation = 'VERTICAL',   reverse = true,  start = 'TOP',    lead = 'BOTTOM' },
}
local SIDE_CORNERS = {
	LEFT   = { 'TOPLEFT', 'BOTTOMLEFT' },
	RIGHT  = { 'TOPRIGHT', 'BOTTOMRIGHT' },
	TOP    = { 'TOPLEFT', 'TOPRIGHT' },
	BOTTOM = { 'BOTTOMLEFT', 'BOTTOMRIGHT' },
}

function UnitFrames.FillDirection(key)
	return FILLS[key] or FILLS.RIGHT
end

local function AttachSide(region, side, target, targetSide)
	local from, to = SIDE_CORNERS[side], SIDE_CORNERS[targetSide]
	region:SetPoint(from[1], target, to[1])
	region:SetPoint(from[2], target, to[2])
end
UnitFrames.AttachSide = AttachSide

function UnitFrames.AnchorAbsorb(absorb, health, healthTexture, direction, fillSpec)
	fillSpec = fillSpec or FILLS.RIGHT
	absorb:ClearAllPoints()
	absorb:SetOrientation(fillSpec.orientation)
	if direction == 'left' then
		absorb:SetReverseFill(not fillSpec.reverse)
		AttachSide(absorb, fillSpec.lead, healthTexture, fillSpec.lead)
	elseif direction == 'edge' then
		absorb:SetReverseFill(not fillSpec.reverse)
		AttachSide(absorb, fillSpec.lead, health, fillSpec.lead)
	else
		absorb:SetReverseFill(fillSpec.reverse)
		AttachSide(absorb, fillSpec.start, healthTexture, fillSpec.lead)
	end
	local excess = absorb.Excess
	if not excess then return end
	local clip = excess:GetParent()
	clip:SetShown(direction == 'left')
	if direction ~= 'left' then return end
	clip:ClearAllPoints()
	AttachSide(clip, fillSpec.start, healthTexture, fillSpec.lead)
	AttachSide(clip, fillSpec.lead, health, fillSpec.lead)
	excess:ClearAllPoints()
	excess:SetOrientation(fillSpec.orientation)
	excess:SetReverseFill(fillSpec.reverse)
	AttachSide(excess, fillSpec.start, health, fillSpec.start)
end

function UnitFrames.AddAbsorbExcess(absorb)
	local clip = CreateFrame('Frame', nil, absorb)
	clip:SetClipsChildren(true)
	absorb.Excess = CreateFrame('StatusBar', nil, clip)
end

local settingsCache
local unitCache = {}
local cachedFont, cachedTexture

function UnitFrames.InvalidateSettingsCache()
	settingsCache = nil
	wipe(unitCache)
	cachedFont = nil
	cachedTexture = nil
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
	local cached = unitCache[unitType]
	if cached then return cached end
	cached = UnitFrames.GetSettings()[unitType]
	unitCache[unitType] = cached
	return cached
end

function UnitFrames.ApplyClickToTarget()
	local oUF = BUI.oUF
	local enabled = UnitFrames.GetSettings().clickToTarget ~= false
	BUI.Events:AfterCombat(function()
		for _, frame in ipairs(oUF.objects) do
			if frame.style == 'BluUI' then frame:SetAttribute('*type1', enabled and 'target' or nil) end
		end
	end, 'UF.ClickToTarget')
end

function UnitFrames.GetTexture()
	if not cachedTexture then
		local settings = UnitFrames.GetSettings()
		cachedTexture = BUI.Tools.ResolveBarTexture(settings.texture)
	end
	return cachedTexture
end

function UnitFrames.GetFont()
	if not cachedFont then cachedFont = BUI.GetFontByName(UnitFrames.GetSettings().font) end
	return cachedFont
end

function UnitFrames.GetBarSmoothing()
	return BUI.GetDB().general.smoothBars and Enum.StatusBarInterpolation.ExponentialEaseOut or Enum.StatusBarInterpolation.Immediate
end

local function ReactionColor(unitSettings, reaction)
	local color = unitSettings[reaction >= 5 and 'friendlyNameColor' or reaction >= 4 and 'neutralNameColor' or 'hostileNameColor']
	return color[1], color[2], color[3]
end

function UnitFrames.GetHealthColor(unit, settings)
	local isPet = unit == 'pet'
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
	return healthColor[1], healthColor[2], healthColor[3], healthColor[4]
end

function UnitFrames.GetPowerColor(unit, settings, unitSettings)
	local isPet = unit == 'pet'
	if settings.useClassColorPowerBar and not isPet then
		if UnitIsPlayer(unit) then
			local red, green, blue = BUI.Tools.GetUnitClassColor(unit)
			if red then return red, green, blue, 1 end
		else
			local reaction = UnitReaction(unit, 'player')
			if reaction then
				local red, green, blue = ReactionColor(unitSettings, reaction)
				return red, green, blue, 1
			end
		end
	end
	if settings.classColorPower and not isPet then
		local powerType, powerToken = UnitPowerType(unit)
		local powerTypeColor = PowerBarColor[powerToken or powerType]
		if powerTypeColor then return powerTypeColor.r, powerTypeColor.g, powerTypeColor.b, 1 end
	end
	local powerColor = isPet and settings.petPowerColor or settings.powerColor
	return powerColor[1], powerColor[2], powerColor[3], powerColor[4]
end

function UnitFrames.GetNameColor(unit, unitSettings)
	if unitSettings.classColorName and unit ~= 'pet' then
		if UnitIsPlayer(unit) then
			local red, green, blue = BUI.Tools.GetUnitClassColor(unit)
			if red then return red, green, blue end
		end
		local reaction = UnitReaction(unit, 'player')
		if reaction then return ReactionColor(unitSettings, reaction) end
	end
	local color = UnitFrames.GetSettings().nameColor
	return color[1], color[2], color[3]
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
		local castbarExtra = castbarSettings.enabled and (castbarSettings.height + 1) or 0
		local offset = unitSettings.height + castbarExtra + unitSettings.spacing
		if unitSettings.growthDirection == 'UP' then
			y = y + ((index - 1) * offset)
		else
			y = y - ((index - 1) * offset)
		end
	end

	if point == 'CENTER' and relPoint == 'CENTER' then
		BUI.Anchor.SetCentered(frame, Pixel.Scale(x), Pixel.Scale(y))
	else
		frame:ClearAllPoints()
		BUI.Anchor.PlaceOnPixels(frame, point, UIParent, relPoint, Pixel.Scale(x), Pixel.Scale(y))
	end
end

local function SetFrameOpacity(frame, opacity)
	frame._ufOpacity = opacity
	frame:SetAlpha(opacity)
end

Motion.RegisterProperty('ufOpacity',
	function(frame) return frame._ufOpacity or 1 end,
	function(frame, value) SetFrameOpacity(frame, value) end
)

local OPACITY_UNITS = {'player', 'target', 'targettarget', 'focus', 'pet'}

function UnitFrames.UpdateOpacity(instant)
	local opacity = BUI.Visibility.GetContextualOpacity('UnitFrames') / 100
	local duration = instant and 0 or 0.3
	for _, unitType in ipairs(OPACITY_UNITS) do
		local unitFrame = UnitFrames[unitType]
		if unitFrame then Motion.To(unitFrame, 'ufOpacity', opacity, duration) end
	end
	for bossIndex = 1, 5 do
		local unitFrame = UnitFrames['boss' .. bossIndex]
		if unitFrame then Motion.To(unitFrame, 'ufOpacity', opacity, duration) end
	end
end

local AGGRO_THICKNESS, AGGRO_LEVEL = 2, 15

local function UpdateAggroOutline(frame, unitType, unitSettings, inCombat)
	local outline = frame.AggroOutline
	if not unitSettings.aggroBorder then
		if outline then outline:Empty() end
		return
	end
	if not outline then
		outline = BUI.Tools.AggroOutline(frame, AGGRO_LEVEL)
		frame.AggroOutline = outline
	end
	local color = unitSettings.aggroBorderColor
	outline:SetLook(color[1], color[2], color[3], color[4], AGGRO_THICKNESS)
	if inCombat then
		outline:TrackThreat(frame.unit or unitType)
	else
		outline:Empty()
	end
end

local function UpdateCombatBorder(frame, unitType, inCombat)
	local settings = UnitFrames.GetSettings()
	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	local borderColor
	if unitSettings.combatBorder and inCombat then
		borderColor = unitSettings.combatBorderColor
	else
		borderColor = (unitType == 'pet') and settings.petBorderColor or settings.borderColor
	end

	Pixel.SetBorderColor(frame, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	SetColorTex(frame.PowerBorder, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	UpdateAggroOutline(frame, unitType, unitSettings, inCombat)
end

local OUTLINE_THICKNESS = 2
local MOUSEOVER_LEVEL, TARGET_LEVEL = 16, 17

local function BossOutline(frame, key, enabled, color, levelOffset)
	local outline = frame[key]
	if not enabled then
		if outline then outline:Hide() end
		return
	end
	if not outline then
		outline = BUI.Tools.OutlineFrame(frame, levelOffset)
		frame[key] = outline
	end
	Pixel.SetTemplate(outline, 0, 0, 0, 0, color[1], color[2], color[3], color[4], OUTLINE_THICKNESS)
	outline:Show()
end

function UnitFrames.UpdateBossTarget(frame)
	local outline = frame.TargetOutline
	if not outline or not outline:IsShown() then return end
	if frame.unit then
		outline:SetAlphaFromBoolean(UnitIsUnit('target', frame.unit), 1, 0)
	else
		outline:SetAlpha(0)
	end
end

function UnitFrames.UpdateBossMouseover(frame)
	local outline = frame.MouseoverOutline
	if outline then outline:SetAlpha(frame._hovered and 1 or 0) end
end

function UnitFrames.ApplyBossOutlines(frame)
	local unitSettings = UnitFrames.GetUnitSettings('boss')
	BossOutline(frame, 'TargetOutline', unitSettings.targetBorder, unitSettings.targetBorderColor, TARGET_LEVEL)
	BossOutline(frame, 'MouseoverOutline', unitSettings.mouseoverBorder, unitSettings.mouseoverBorderColor, MOUSEOVER_LEVEL)
	UnitFrames.UpdateBossTarget(frame)
	UnitFrames.UpdateBossMouseover(frame)
end

BUI.Events:Register('PLAYER_TARGET_CHANGED', 'UF.BossTarget', function()
	for bossIndex = 1, 5 do
		local frame = UnitFrames['boss' .. bossIndex]
		if frame then UnitFrames.UpdateBossTarget(frame) end
	end
end)

do
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

	local HL_TYPES = { 'Magic', 'Curse', 'Disease', 'Poison', 'Bleed' }
	local TYPE_ICON_GAP = 6
	local PLAIN_FILTER, BYME_FILTER = 'HARMFUL', 'HARMFUL|RAID_PLAYER_DISPELLABLE'

	local function SyncDispelTypeGroups(container, groups, addGroup)
		local unitSettings = UnitFrames.GetUnitSettings('player')
		local byMe = unitSettings.debuffHighlightClassFilter ~= false
		local covered = byMe and GetSelfCleanseTypes()
		for typeIndex = 1, #HL_TYPES do
			local typeName = HL_TYPES[typeIndex]
			local plainKey, bymeKey = typeName, typeName .. '#byme'
			local activeKey = (byMe and not (covered and covered[typeName])) and bymeKey or plainKey
			for variant = 1, 2 do
				local variantKey = variant == 1 and plainKey or bymeKey
				local info = groups[variantKey]
				local wantActive = variantKey == activeKey
				if info then
					if info.active ~= wantActive then
						info.active = wantActive
						container:SetAuraGroupMaxFrameCount(info.key, wantActive and 1 or 0)
					end
				elseif wantActive then
					groups[variantKey] = { key = addGroup(typeIndex, typeName, variantKey == bymeKey and BYME_FILTER or PLAIN_FILTER), active = true }
				end
			end
		end
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
			kit.icon:SetVertexColor(Engine.DispelColorRGB(kit.typeName))
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

	local function TypeRowInitializer(typeName)
		return function(button)
			local kit = { typeName = typeName, button = button }
			kit.icon = button:CreateTexture(nil, 'OVERLAY', nil, 7)
			kit.icon:SetAtlas(DISPEL_BADGE_ATLAS[typeName])
			typeRowKits[#typeRowKits + 1] = kit
			StyleTypeRowKit(kit)
			button:SetMouseClickEnabled(false)
			button:SetMouseMotionEnabled(false)
		end
	end

	local function EnsureTypeRowGroups(container)
		SyncDispelTypeGroups(container, container._rowGroups, function(slot, typeName, filter)
			container._rowSeq = (container._rowSeq or 0) + 1
			local key = 'row' .. container._rowSeq
			local size = TypeRowIconSize()
			container:AddAuraGroup(key, filter, {
				maxFrameCount = 1,
				initializeFrame = TypeRowInitializer(typeName),
				candidateFilters = { includeDispelTypes = { [typeName] = true } },
				layout = {
					elementWidth = size, elementHeight = size,
					elementSpacing = TYPE_ICON_GAP, lineSpacing = TYPE_ICON_GAP,
					layoutIndex = slot,
				},
			})
			return key
		end)
	end

	local HIGHLIGHT_SETTING_INPUTS = 10
	local HIGHLIGHT_INPUT_COUNT = HIGHLIGHT_SETTING_INPUTS + #HL_TYPES * 3
	local highlightInputs = {}

	local function GatherHighlightInputs(unitSettings)
		local settings = UnitFrames.GetSettings()
		local classFilter = unitSettings.debuffHighlightClassFilter ~= false
		highlightInputs[1] = classFilter
		highlightInputs[2] = unitSettings.debuffHighlightBadgeSize
		highlightInputs[3] = unitSettings.debuffHighlightBadgeOffsetX
		highlightInputs[4] = unitSettings.debuffHighlightBadgeOffsetY
		highlightInputs[5] = settings.dispelRecolor
		highlightInputs[6] = settings.dispelBlend
		highlightInputs[7] = settings.dispelOpacity
		highlightInputs[8] = unitSettings.debuffHighlightBar
		highlightInputs[9] = unitSettings.debuffHighlightStyle
		highlightInputs[10] = classFilter and select(2, GetSelfCleanseTypes()) or ''
		for typeIndex = 1, #HL_TYPES do
			local slot = HIGHLIGHT_SETTING_INPUTS + (typeIndex - 1) * 3
			highlightInputs[slot + 1], highlightInputs[slot + 2], highlightInputs[slot + 3] = Engine.DispelColorRGB(HL_TYPES[typeIndex])
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
	local FADE_MIDDLE_COORD, FADE_FAR_COORD = 0.75, 1.05
	local frameKits = setmetatable({}, { __mode = 'k' })
	local framePending = {}

	function UnitFrames.OverlappingAbsorb(frame, damageEnabled, damageDirection, healEnabled, healDirection)
		if frame.Absorb and damageEnabled and damageDirection == 'left' then return frame.Absorb end
		if frame.HealAbsorb and healEnabled and healDirection == 'left' then return frame.HealAbsorb end
	end

	local function PrepFillTexture(texture, asset, blend, alpha)
		texture:ClearAllPoints()
		texture:SetTexture(asset, 'CLAMP', 'CLAMP')
		texture:SetBlendMode(blend)
		texture:SetAlpha(alpha)
	end

	function UnitFrames.AnchorDispelFill(kit, frame, style, absorb, alpha, fillSpec)
		fillSpec = fillSpec or FILLS.RIGHT
		local healthTexture = frame.Health:GetStatusBarTexture()
		local endEdge, endSide = healthTexture, fillSpec.lead
		if absorb then endEdge, endSide = absorb:GetStatusBarTexture(), fillSpec.start end
		local blend = UnitFrames.GetSettings().dispelBlend and 'ADD' or 'BLEND'
		local half = style == 'top' or style == 'bottom'
		local fill, fade = kit.fill, kit.fade
		PrepFillTexture(fill, half and FADE_TEXTURE or WHITE8X8, blend, alpha)
		PrepFillTexture(fade, FADE_TEXTURE, blend, alpha)
		local startCorner, leadCorner, endCorner = SIDE_CORNERS[fillSpec.start][1], SIDE_CORNERS[fillSpec.lead][2], SIDE_CORNERS[endSide][2]
		if not half then
			fill:SetTexCoord(0, 1, 0, 1)
			fill:SetPoint(startCorner, healthTexture, startCorner)
			fill:SetPoint(leadCorner, endEdge, endCorner)
			fade:SetTexCoord(0, 1, 1, 1)
			fade:SetPoint(startCorner, healthTexture, startCorner)
			fade:SetPoint(leadCorner, endEdge, endCorner)
			return
		end
		if fillSpec.orientation == 'VERTICAL' then
			fill:SetPoint(startCorner, healthTexture, startCorner)
			fill:SetPoint(leadCorner, endEdge, endCorner)
			if style == 'bottom' then fill:SetTexCoord(0, 1, FADE_FAR_COORD, 0) else fill:SetTexCoord(0, 1, 0, FADE_FAR_COORD) end
			fade:SetPoint('TOPLEFT', healthTexture, 'TOPLEFT')
			fade:SetPoint('BOTTOMRIGHT', healthTexture, 'TOPLEFT')
			return
		end
		local startSide, leadSide = fillSpec.start, fillSpec.lead
		if style == 'bottom' then
			fill:SetPoint('TOP' .. startSide, healthTexture, startSide)
			fill:SetPoint('BOTTOM' .. leadSide, endEdge, 'BOTTOM' .. endSide)
			fill:SetTexCoord(0, 1, FADE_MIDDLE_COORD, 0)
			fade:SetPoint('TOP' .. startSide, healthTexture, 'TOP' .. startSide)
			fade:SetPoint('BOTTOM' .. leadSide, endEdge, endSide)
			fade:SetTexCoord(0, 1, FADE_FAR_COORD, FADE_MIDDLE_COORD)
		else
			fill:SetPoint('TOP' .. startSide, healthTexture, 'TOP' .. startSide)
			fill:SetPoint('BOTTOM' .. leadSide, endEdge, endSide)
			fill:SetTexCoord(0, 1, 0, FADE_MIDDLE_COORD)
			fade:SetPoint('TOP' .. startSide, healthTexture, startSide)
			fade:SetPoint('BOTTOM' .. leadSide, endEdge, 'BOTTOM' .. endSide)
			fade:SetTexCoord(0, 1, FADE_MIDDLE_COORD, FADE_FAR_COORD)
		end
	end

	local function AnchorPlayerFill(kit, frame, alpha)
		local settings = UnitFrames.GetSettings()
		local absorb = UnitFrames.OverlappingAbsorb(frame, settings.shieldEnabled ~= false, settings.shieldDirection, settings.healAbsorbEnabled ~= false, settings.healAbsorbDirection)
		UnitFrames.AnchorDispelFill(kit, frame, UnitFrames.GetUnitSettings('player').debuffHighlightStyle, absorb, alpha)
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
		AnchorPlayerFill(kit, frame, wantFill and UnitFrames.GetSettings().dispelOpacity / 100 or 0)
		local red, green, blue = Engine.DispelColorRGB(typeName)
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

	local function FrameInitializer(frame, typeName, priority)
		return function(button)
			local kit = {
				typeName = typeName,
				fill = button:CreateTexture(nil, 'ARTWORK', nil, priority),
				fade = button:CreateTexture(nil, 'ARTWORK', nil, priority),
			}
			local kits = frameKits[frame]
			if not kits then kits = {}; frameKits[frame] = kits end
			kits[#kits + 1] = kit
			StyleFrameKit(frame, kit)
			button:SetMouseClickEnabled(false)
			button:SetMouseMotionEnabled(false)
		end
	end

	local function EnsureFrameGroups(container, frame)
		SyncDispelTypeGroups(container, container._fgGroups, function(typeIndex, typeName, filter)
			container._fgSeq = (container._fgSeq or 0) + 1
			local key = 'fg' .. container._fgSeq
			container:AddAuraGroup(key, filter, {
				maxFrameCount = 1,
				initializeFrame = FrameInitializer(frame, typeName, #HL_TYPES - typeIndex + 1),
				candidateFilters = { includeDispelTypes = { [typeName] = true } },
			})
			return key
		end)
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
				texture:SetVertexColor(Engine.DispelColorRGB(HL_TYPES[typeIndex]))
			else
				texture:SetDesaturated(false)
				texture:SetVertexColor(1, 1, 1)
			end
			texture:SetAlpha(typeIndex == active and 1 or 0.35)
		end
		host:Show()
	end

	local function PinDispelPreview(typeName)
		previewPin = typeName
		UnitFrames.RefreshDispelPreview()
	end

	local function UnpinDispelPreview()
		previewPin = nil
		HidePreview()
	end

	local DISPEL_PREVIEW_SECONDS = 1.5
	local previewTicker, previewCycle = nil, 0

	local StepDispelPreview = function()
		previewCycle = previewCycle % #HL_TYPES + 1
		PinDispelPreview(HL_TYPES[previewCycle])
	end

	function UnitFrames.StopDispelPreview()
		if previewTicker then previewTicker:Cancel() end
		previewTicker = nil
		UnpinDispelPreview()
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
		return measureFontString:GetStringWidth()
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
				local red, green, blue = Engine.DispelColorRGB(part.types[map[edgeIndex]])
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
		calloutContainer:SetAuraGroupMaxFrameCount(cell.part.groupKey, mark)
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
			button:SetMouseClickEnabled(false)
			button:SetMouseMotionEnabled(false)
		end
	end

	local QueueCalloutReadiness = BUI.Dispatcher.NewDelayed(ApplyCalloutReadiness, 0.25)

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
			for _, cell in ipairs(calloutCells) do
				calloutContainer:SetAuraGroupMaxFrameCount(cell.part.groupKey, 0)
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
		calloutContainer:Show()
		Engine.BindUnit(calloutContainer, 'player')
	end

	local function DrainPendingRestyles()
		if typeRowRestylePending then RestyleTypeRow() end
		for frame in pairs(framePending) do
			framePending[frame] = nil
			RestyleFrameKits(frame)
		end
		if calloutRepaintPending then RepaintCalloutRings() end
	end

	BUI.Events:Register('PLAYER_REGEN_ENABLED', 'UF.Dispel.Restyle', function() BUI.Events:AfterCombatSettled(DrainPendingRestyles, 'UF.Dispel.Restyle') end)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.Dispel.Restyle', DrainPendingRestyles)

	function UnitFrames.UpdateDebuffHighlight(frame)
		if not frame then return end
		local unitSettings = UnitFrames.GetUnitSettings('player')
		local badgeWanted = unitSettings.debuffHighlightBadge ~= false
		local frameColorsWanted = unitSettings.debuffHighlightBar
		if badgeWanted or frameColorsWanted then GatherHighlightInputs(unitSettings) end
		ConfigureTypeRow(badgeWanted)
		ConfigureCallouts(unitSettings.debuffHighlightTypeText)
		ConfigureFrameColors(frame, frameColorsWanted)
	end

	function UnitFrames.FollowDebuffHighlightUnit(frame)
		local container = frame._dispelFrameHL
		if container and container._buiUnit and container._buiUnit ~= frame.unit then
			Engine.BindUnit(container, frame.unit)
		end
	end

	local ScanPlayer = BUI.Dispatcher.New(function()
		UnitFrames.UpdateDebuffHighlight(UnitFrames.player)
	end)

	BUI.Tools.OnAuraQueriesUnblocked(ScanPlayer)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'UF.DebuffHighlight.Scan', ScanPlayer)

	BUI.Events:OnTalentBurst('UF.DebuffHighlight', ScanPlayer)
end

do
	local pendingCombatEdge
	local DispatchCombatBorders = BUI.Dispatcher.New(function()
		local inCombat = pendingCombatEdge == 'PLAYER_REGEN_DISABLED'
		pendingCombatEdge = nil
		for _, unitType in ipairs(OPACITY_UNITS) do
			local unitFrame = UnitFrames[unitType]
			if unitFrame then UpdateCombatBorder(unitFrame, unitType, inCombat) end
		end
		if not inCombat then UnitFrames.RefreshAnchoredFrames() end
	end)

	local function OnCombatBorderEvent(event)
		if event == 'UNIT_THREAT_SITUATION_UPDATE' then
			if not InCombatLockdown() then return end
			local playerFrame = UnitFrames.player
			if playerFrame then UpdateCombatBorder(playerFrame, 'player', true) end
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

