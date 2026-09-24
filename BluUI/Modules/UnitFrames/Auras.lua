local _, BUI = ...

local UnitFrames = BUI.UnitFrames
local Pixel = BUI.Pixel
local AuraRules = BUI.AuraRules
local AuraBlacklist = BUI.AuraBlacklist
local Engine = BUI.AuraEngine

local ceil = math.ceil
local select = select
local pairs, ipairs = pairs, ipairs

local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local UnitExists = UnitExists

local DEBUFF_BASE_COLOR = { 0.8, 0, 0, 1 }
local BUFF_BASE_COLOR = { 0, 0, 0, 1 }

local ENGINE_OK = Engine.Available

local auraBorderCurve, auraBorderCurveStamp
local function GetAuraBorderCurve()
	if auraBorderCurve and auraBorderCurveStamp == Engine.DispelPaletteStamp() then return auraBorderCurve end
	auraBorderCurve, auraBorderCurveStamp = Engine.BuildDispelCurve(CreateColor(0.8, 0, 0, 1))
	return auraBorderCurve
end

local filterCache
local debuffWhitelistActive, buffWhitelistActive = false, false

local function GetFilters()
	if not filterCache then
		local db = BUI.GetDB()
		filterCache = db and db.auraFilters or {}
		debuffWhitelistActive = (filterCache.debuffWhitelist and next(filterCache.debuffWhitelist)) ~= nil
		buffWhitelistActive   = (filterCache.buffWhitelist   and next(filterCache.buffWhitelist))   ~= nil
	end
	return filterCache
end

function UnitFrames.InvalidateFilterCache()
	filterCache = nil
end

local DEBUFF_FILTERS = {
	all            = 'HARMFUL|INCLUDE_NAME_PLATE_ONLY',
	mine           = 'HARMFUL|PLAYER',
	dispellable    = 'HARMFUL|RAID_PLAYER_DISPELLABLE',
	allDispellable = 'HARMFUL',
	blizzardRaid   = 'HARMFUL|RAID',
}

local BUFF_FILTERS = {
	mine    = 'HELPFUL|PLAYER|RAID_IN_COMBAT',
	mineAll = 'HELPFUL|PLAYER',
	raid    = 'HELPFUL|RAID',
	all     = 'HELPFUL',
}

local SHOWMODE_TO_RULES = {
	debuff = {
		all            = { 'allHarmful' },
		mine           = { 'mineHarmful' },
		dispellable    = { 'dispellable' },
		allDispellable = { 'anyDispellable' },
		blizzardRaid   = { 'allHarmful' },
	},
	buff = {
		all     = { 'allHelpful' },
		mine    = { 'mineHelpful' },
		mineAll = { 'mineHelpful' },
		raid    = { 'raidRelevant' },
	},
}

local function UnitRules(unitSettings, isDebuff)
	local key = isDebuff and 'debuffRules' or 'buffRules'
	local rules = unitSettings[key]
	if type(rules) == 'table' then return rules end
	local map = isDebuff and SHOWMODE_TO_RULES.debuff or SHOWMODE_TO_RULES.buff
	local mode = isDebuff and (unitSettings.debuffShowMode or 'all') or (unitSettings.buffShowMode or 'all')
	local from = map[mode] or { isDebuff and 'allHarmful' or 'allHelpful' }
	rules = {}
	for ruleIndex = 1, #from do rules[ruleIndex] = from[ruleIndex] end
	unitSettings[key] = rules
	return rules
end
UnitFrames.GetAuraRules = UnitRules

local function MigrateDebuffSettings(settings, unitType)
	if unitType == 'player' and not settings.playerBuffRulesNarrowed then
		settings.playerBuffRulesNarrowed = true
		local buffRules = settings.buffRules
		if type(buffRules) == 'table' and #buffRules == 1 and buffRules[1] == 'mineHelpful' then
			buffRules[1] = 'mineRaidCombat'
		end
	end

	if not settings.debuffShowMode then
		local mode = settings.debuffFilter
		if mode then
			settings.debuffOnlyMine = (mode == 'mine' or mode == 'myimportant')
			settings.debuffImportant = (mode == 'important' or mode == 'myimportant')
			settings.debuffFilter = nil
		end
		if settings.onlyPlayerDebuffs then
			settings.debuffOnlyMine = true
			settings.onlyPlayerDebuffs = nil
		end

		if settings.debuffOnlyMine then
			settings.debuffShowMode = 'mine'
		elseif settings.onlyDispellableDebuffs then
			settings.debuffShowMode = 'dispellable'
		else
			settings.debuffShowMode = 'all'
		end
		settings.debuffImportant = nil
		settings.debuffOnlyMine  = nil
		settings.onlyDispellableDebuffs = nil
	end

	if not settings.buffShowMode then
		if settings.onlyPlayerBuffs then
			settings.buffShowMode = settings.buffImportant and 'mine' or 'mineAll'
		elseif settings.buffImportant then
			settings.buffShowMode = 'raid'
		else
			settings.buffShowMode = 'all'
		end
		settings.onlyPlayerBuffs = nil
		settings.buffImportant   = nil
	end
end

local POSITION_OFFSETS = Engine.StackAnchors

local function GetAuraSetting(settings, isDebuff, debuffKey, buffKey, globalKey, fallback)
	local specificKey = isDebuff and debuffKey or buffKey
	local value = settings[specificKey]
	if value ~= nil then return value end
	if globalKey then
		value = settings[globalKey]
		if value ~= nil then return value end
	end
	return fallback
end

local GrowthToAnchor = Engine.GrowthToAnchor

local function ResolveStyle(settings, isDebuff)
	local style = {}
	if isDebuff then
		style.size   = settings.debuffIconSize or settings.auraIconSize or 24
		style.gap    = settings.debuffSpacing or settings.auraSpacing or 2
		style.perRow = settings.debuffsPerRow or settings.maxDebuffs or 8
		style.max    = settings.maxDebuffs or 16
		style.growX  = settings.debuffGrowthX
		style.growY  = settings.debuffGrowthY
		style.anchorTo = settings.debuffAnchorPoint
		style.offsetX = settings.debuffOffsetX
		style.offsetY = settings.debuffOffsetY
		style.shown  = settings.showDebuffs
		style.baseColor = DEBUFF_BASE_COLOR
		style.showDispelType = settings.showDebuffType ~= false
	else
		style.size   = settings.buffIconSize or settings.auraIconSize or 20
		style.gap    = settings.buffSpacing or settings.auraSpacing or 2
		style.perRow = settings.buffsPerRow or settings.maxBuffs or 8
		style.max    = settings.maxBuffs or 8
		style.growX  = settings.buffGrowthX or 'RIGHT'
		style.growY  = settings.buffGrowthY or 'DOWN'
		style.anchorTo = settings.buffAnchorPoint or 'BOTTOMLEFT'
		style.offsetX = settings.buffOffsetX or 0
		style.offsetY = settings.buffOffsetY or 0
		style.shown  = settings.showBuffs
		style.baseColor = BUFF_BASE_COLOR
		style.showDispelType = false
	end
	style.sortMethod = Engine.ResolveSortMethod(GetAuraSetting(settings, isDebuff, 'debuffSortMethod', 'buffSortMethod', 'auraSortMethod', 'default'))
	style.showStack = GetAuraSetting(settings, isDebuff, 'debuffShowStack', 'buffShowStack', 'auraShowStack', true)
	style.stackSize = GetAuraSetting(settings, isDebuff, 'debuffStackSize', 'buffStackSize', 'auraStackSize', 10)
	style.stackPos  = GetAuraSetting(settings, isDebuff, 'debuffStackPos', 'buffStackPos', nil, 'BOTTOMRIGHT')
	style.showCd    = GetAuraSetting(settings, isDebuff, 'debuffShowCd', 'buffShowCd', 'auraShowCd', true)
	style.cdSize    = GetAuraSetting(settings, isDebuff, 'debuffCdSize', 'buffCdSize', 'auraCdSize', 10)
	style.reverseSwipe = settings.auraReverseSwipe
	style.showTooltips = settings.showTooltips ~= false
	style.font = UnitFrames.GetFont()
	return style
end

local auraFrames = {}

local function BuildCandidates(isDebuff)
	local filters = GetFilters()
	local candidates, fingerprint

	local blacklist = AuraBlacklist.UnitSet(isDebuff and 'HARMFUL' or 'HELPFUL')
	local whitelist, whitelistActive, whitelistOnly
	if isDebuff then
		whitelist, whitelistActive = filters.debuffWhitelist, debuffWhitelistActive
		whitelistOnly = filters.debuffWhitelistOnly
	else
		whitelist, whitelistActive = filters.buffWhitelist, buffWhitelistActive
		whitelistOnly = filters.buffWhitelistOnly
	end

	if whitelistActive and whitelistOnly then
		candidates = { includeSpellIDs = whitelist }
		fingerprint = 'wl:' .. Engine.SortedKeys(whitelist)
	else
		if whitelistActive then
			candidates = { pinSpellIDs = whitelist }
			fingerprint = 'pin:' .. Engine.SortedKeys(whitelist)
		end
		if blacklist and next(blacklist) then
			candidates = candidates or {}
			candidates.excludeSpellIDs = blacklist
			local blacklistFingerprint = 'bl:' .. Engine.SortedKeys(blacklist)
			fingerprint = fingerprint and (fingerprint .. '+' .. blacklistFingerprint) or blacklistFingerprint
		end
	end

	return candidates, fingerprint or ''
end

local UNIT_CONTAINER_KEYS = { 'DebuffContainer', 'BuffContainer', '_dispelFrameHL' }

local function BindUnit(frame, rebind)
	local unit = frame.unit
	if not unit then return end
	for _, key in ipairs(UNIT_CONTAINER_KEYS) do
		local container = frame[key]
		if container and (container._buiUnit or container:IsShown()) then
			if rebind then
				Engine.RebindUnit(container, unit)
			else
				Engine.BindUnit(container, unit)
			end
		end
	end
end

local EnsureEventlessTicker

local function EngineCreateAuraElements(frame, unitType)
	frame.DebuffContainer = Engine.NewContainer(frame, true)
	frame.BuffContainer = Engine.NewContainer(frame, false)
	frame.DebuffContainer._buiScope = 'unit'
	frame.BuffContainer._buiScope = 'unit'
	auraFrames[#auraFrames + 1] = { frame = frame, unitType = unitType }
	if unitType == 'targettarget' then
		frame:HookScript('OnShow', function(shownFrame)
			BindUnit(shownFrame, true)
			EnsureEventlessTicker()
		end)
	end
end

local function ApplyContainer(frame, container, style, rules)
	local anchor = GrowthToAnchor(style.growX, style.growY)
	container:ClearAllPoints()
	container:SetPoint(anchor, frame, style.anchorTo, Pixel.Scale(style.offsetX), Pixel.Scale(style.offsetY))
	container:SetShown(style.shown)

	local isDebuff = container._buiIsDebuff
	local baseFilter = isDebuff and DEBUFF_FILTERS.all or BUFF_FILTERS.all
	local candidates, candidatesFingerprint = BuildCandidates(isDebuff)
	Engine.Configure(container, style, rules, baseFilter, candidates, candidatesFingerprint)
end

local function EngineApplyAuraPositions(frame, unitType)
	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	MigrateDebuffSettings(unitSettings, unitType)

	if frame.DebuffContainer then
		local style = ResolveStyle(unitSettings, true)
		ApplyContainer(frame, frame.DebuffContainer, style, UnitRules(unitSettings, true))
	end

	if frame.BuffContainer then
		local style = ResolveStyle(unitSettings, false)
		ApplyContainer(frame, frame.BuffContainer, style, UnitRules(unitSettings, false))
	end

	BindUnit(frame)
end

local function EngineRefreshAuraLayout(frame, unitType)
	if not frame then return end
	EngineApplyAuraPositions(frame, unitType)
end

local function PokeFrames(matchTypes, rebind)
	for _, entry in ipairs(auraFrames) do
		if matchTypes[entry.unitType] and entry.frame.unit and UnitExists(entry.frame.unit) then
			BindUnit(entry.frame, rebind)
		end
	end
end

local eventlessTicker
function EnsureEventlessTicker()
	if eventlessTicker then return end
	local hasTargetOfTarget = false
	for _, entry in ipairs(auraFrames) do
		if entry.unitType == 'targettarget' then hasTargetOfTarget = true; break end
	end
	if not hasTargetOfTarget then return end
	eventlessTicker = C_Timer.NewTicker(0.5, function()
		local active = false
		for _, entry in ipairs(auraFrames) do
			if entry.unitType == 'targettarget' and entry.frame:IsVisible() then
				active = true
				BindUnit(entry.frame)
			end
		end
		if not active and eventlessTicker then
			eventlessTicker:Cancel()
			eventlessTicker = nil
		end
	end)
end

if ENGINE_OK then
	BUI.Events:Register('PLAYER_TARGET_CHANGED', 'UFAuras.Target', function()
		PokeFrames({ target = true, targettarget = true }, true)
		EnsureEventlessTicker()
	end)
	BUI.Events:Register('PLAYER_FOCUS_CHANGED', 'UFAuras.Focus', function()
		PokeFrames({ focus = true }, true)
	end)
	BUI.Events:RegisterUnit('UNIT_TARGET', 'target', 'UFAuras.TargetOfTarget', function()
		PokeFrames({ targettarget = true }, true)
	end)
	BUI.Events:Register('INSTANCE_ENCOUNTER_ENGAGE_UNIT', 'UFAuras.Boss', function()
		PokeFrames({ boss = true }, true)
	end)
	BUI.Events:RegisterUnit('UNIT_PET', 'player', 'UFAuras.Pet', function()
		PokeFrames({ pet = true }, true)
	end)
end

local FEIGN_DEATH_ICON = 132293

local function LegacyPreUpdate(element, unit)
	if element._bluRules then
		AuraRules.BuildSets(unit, element._bluRules, element._bluSets)
	end
end

local function FilterAura(element, unit, data)
	local isHarmful = data.isHarmfulAura
	local settings = element._buiSettings
	if not settings then return data.isPlayerAura or not element.onlyShowPlayer end

	local spellID = data.spellId
	if spellID and not BUI.Tools.IsSecretValue(spellID) then
		if not BUI.Tools.IsSecretValue(isHarmful) then
			AuraBlacklist.RecordAura(spellID, isHarmful and 'HARMFUL' or 'HELPFUL')
		end
		local filters = GetFilters()
		local whitelist, whitelistActive, whitelistOnly
		if isHarmful then
			whitelist, whitelistActive = filters.debuffWhitelist, debuffWhitelistActive
			whitelistOnly = filters.debuffWhitelistOnly
		else
			whitelist, whitelistActive = filters.buffWhitelist, buffWhitelistActive
			whitelistOnly = filters.buffWhitelistOnly
		end

		if whitelistActive and whitelistOnly then return whitelist[spellID] == true end
		if whitelistActive and whitelist[spellID] then
			data._bluPri = 0
			return true
		end
		if AuraBlacklist.IsUnitBlacklisted(spellID, isHarmful) then return false end
	end

	local rules = element._bluRules
	if rules then
		local priority = AuraRules.Evaluate(rules, data, element._bluSets)
		data._bluPri = priority
		return priority ~= nil
	end

	if not isHarmful and element.onlyShowPlayer and not data.isPlayerAura then return false end
	return true
end

local function StyleButton(element, button)
	local edge = Pixel.PixelSize(1)
	local isDebuff = element._buiIsDebuff
	local settings = element._buiSettings

	Pixel.ApplyBorder(button, 1, 0, 0, 0, 1)

	if button.Icon then
		button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		button.Icon:ClearAllPoints()
		button.Icon:SetPoint('TOPLEFT', edge, -edge)
		button.Icon:SetPoint('BOTTOMRIGHT', -edge, edge)
	end

	if button.Cooldown then
		button.Cooldown:ClearAllPoints()
		button.Cooldown:SetAllPoints(button)
		button.Cooldown:SetDrawEdge(false)
		button.Cooldown:SetHideCountdownNumbers(false)
		button.Cooldown:SetCountdownAbbrevThreshold(20)
		button.Cooldown:SetReverse(settings and settings.auraReverseSwipe or false)
	end

	if not button._buiMouseStripped then
		button._buiMouseStripped = true
		for _, child in pairs({ button:GetChildren() }) do
			child:EnableMouse(false)
			for _, grandchild in pairs({ child:GetChildren() }) do
				grandchild:EnableMouse(false)
			end
		end
	end

	if button.Overlay then
		button.Overlay:Hide()
		button.Overlay:SetAlpha(0)
	end

	if not settings then return end

	local font = UnitFrames.GetFont()

	if button.Count then
		local showStack = GetAuraSetting(settings, isDebuff, 'debuffShowStack', 'buffShowStack', 'auraShowStack', true)
		if showStack == false then
			button.Count:Hide()
		else
			local stackSize = GetAuraSetting(settings, isDebuff, 'debuffStackSize', 'buffStackSize', 'auraStackSize', 10)
			Pixel.ApplyFont(button.Count, stackSize, font)

			local positionKey = GetAuraSetting(settings, isDebuff, 'debuffStackPos', 'buffStackPos', nil, 'BOTTOMRIGHT')
			local positionData = POSITION_OFFSETS[positionKey] or POSITION_OFFSETS.BOTTOMRIGHT
			button.Count:ClearAllPoints()
			button.Count:SetPoint(positionData[1], button, positionData[1], positionData[2], positionData[3])
			button.Count:Show()
		end
	end

	if button.Cooldown then
		local showCd = GetAuraSetting(settings, isDebuff, 'debuffShowCd', 'buffShowCd', 'auraShowCd', true)
		button.Cooldown:SetHideCountdownNumbers(showCd == false)
		if showCd ~= false then
			local cdSize = GetAuraSetting(settings, isDebuff, 'debuffCdSize', 'buffCdSize', 'auraCdSize', 10)

			for _, child in pairs({ button.Cooldown:GetChildren() }) do
				for regionIndex = 1, select('#', child:GetRegions()) do
					local region = select(regionIndex, child:GetRegions())
					if region and region:IsObjectType('FontString') then
						Pixel.ApplyFont(region, cdSize, font)
					end
				end
			end
			for regionIndex = 1, select('#', button.Cooldown:GetRegions()) do
				local region = select(regionIndex, button.Cooldown:GetRegions())
				if region and region:IsObjectType('FontString') then
					Pixel.ApplyFont(region, cdSize, font)
				end
			end
		end
	end
end

local function PostCreateButton(element, button)
	StyleButton(element, button)
end

local function ApplyAuraCooldown(element, button, unit, data)
	if not button.Cooldown then return end
	local eventless = element.__owner and element.__owner.__eventless
	if eventless and button._buiCdInstance == data.auraInstanceID then return end
	button._buiCdInstance = data.auraInstanceID

	local duration = BUI.Tools.CallAuraDuration(unit, data.auraInstanceID)
	if duration then
		button.Cooldown:SetCooldownFromDurationObject(duration)
		button.Cooldown:Show()
	else
		button.Cooldown:Hide()
	end
end

local function DebuffPostUpdateButton(element, button, unit, data)
	button:SetMouseMotionEnabled(UnitFrames.GetSettings().showTooltips ~= false)
	if not data then return end
	ApplyAuraCooldown(element, button, unit, data)
	if element.buiDebuffType then
		local color = C_UnitAuras.GetAuraDispelTypeColor(unit, data.auraInstanceID, GetAuraBorderCurve())
		if color then
			Pixel.SetBorderColor(button, color:GetRGBA())
		else
			Pixel.SetBorderColor(button, 0.8, 0, 0, 1)
		end
	else
		Pixel.SetBorderColor(button, 0.8, 0, 0, 1)
	end

	if button.Icon then
		local feign = unit == 'player' and BUI._feignSalveAuras[data.auraInstanceID]
		button.Icon:SetTexture(feign and FEIGN_DEATH_ICON or data.icon)
	end

	if button.Overlay then button.Overlay:Hide() end
end

local function BuffPostUpdateButton(element, button, unit, data)
	button:SetMouseMotionEnabled(UnitFrames.GetSettings().showTooltips ~= false)
	Pixel.SetBorderColor(button, 0, 0, 0, 1)
	if button.Overlay then button.Overlay:Hide() end
	if data then ApplyAuraCooldown(element, button, unit, data) end
end

local function LegacyCreateAuraElements(frame, unitType)
	local unitSettings = UnitFrames.GetUnitSettings(unitType)

	local debuffs = CreateFrame('Frame', nil, frame)
	debuffs:SetFrameLevel(frame:GetFrameLevel() + 10)
	debuffs.PostCreateButton = PostCreateButton
	debuffs.PostUpdateButton = DebuffPostUpdateButton
	debuffs.FilterAura = FilterAura
	debuffs.disableCooldown = true
	debuffs.buiDebuffType = unitSettings.showDebuffType ~= false
	debuffs._buiIsDebuff = true
	debuffs.disableMouse = true
	frame.Debuffs = debuffs

	local buffs = CreateFrame('Frame', nil, frame)
	buffs:SetFrameLevel(frame:GetFrameLevel() + 10)
	buffs.PostCreateButton = PostCreateButton
	buffs.PostUpdateButton = BuffPostUpdateButton
	buffs.FilterAura = FilterAura
	buffs.disableCooldown = true
	buffs._buiIsDebuff = false
	buffs.disableMouse = true
	frame.Buffs = buffs
end

local function LegacyApplyAuraPositions(frame, unitType)
	local unitSettings = UnitFrames.GetUnitSettings(unitType)

	MigrateDebuffSettings(unitSettings, unitType)

	if frame.Debuffs then
		local style = ResolveStyle(unitSettings, true)
		local anchor = GrowthToAnchor(style.growX, style.growY)

		frame.Debuffs.size = style.size
		frame.Debuffs.spacing = style.gap
		frame.Debuffs.num = style.max
		frame.Debuffs.maxCols = style.perRow
		frame.Debuffs.growthX = style.growX
		frame.Debuffs.growthY = style.growY
		frame.Debuffs.initialAnchor = anchor
		frame.Debuffs.onlyShowPlayer = false
		frame.Debuffs.filter = DEBUFF_FILTERS.all
		frame.Debuffs._bluRules = UnitRules(unitSettings, true)
		frame.Debuffs._bluSets = frame.Debuffs._bluSets or {}
		frame.Debuffs.PreUpdate = LegacyPreUpdate
		frame.Debuffs.SortAuras = AuraRules.Compare
		frame.Debuffs.buiDebuffType = unitSettings.showDebuffType ~= false
		frame.Debuffs._buiSettings = unitSettings
		frame.Debuffs._buiIsDebuff = true

		local rows = ceil(style.max / style.perRow)
		frame.Debuffs:ClearAllPoints()
		frame.Debuffs:SetPoint(anchor, frame, style.anchorTo, Pixel.Scale(style.offsetX), Pixel.Scale(style.offsetY))
		frame.Debuffs:SetSize(style.perRow * style.size + (style.perRow - 1) * style.gap, rows * style.size + (rows - 1) * style.gap)
		frame.Debuffs:SetShown(style.shown)

		for buttonIndex = 1, frame.Debuffs.createdButtons or 0 do
			local button = frame.Debuffs[buttonIndex]
			if button then StyleButton(frame.Debuffs, button) end
		end
	end

	if frame.Buffs then
		local style = ResolveStyle(unitSettings, false)
		local anchor = GrowthToAnchor(style.growX, style.growY)

		frame.Buffs.size = style.size
		frame.Buffs.spacing = style.gap
		frame.Buffs.num = style.max
		frame.Buffs.maxCols = style.perRow
		frame.Buffs.growthX = style.growX
		frame.Buffs.growthY = style.growY
		frame.Buffs.initialAnchor = anchor
		frame.Buffs.onlyShowPlayer = false
		frame.Buffs.filter = BUFF_FILTERS.all
		frame.Buffs._bluRules = UnitRules(unitSettings, false)
		frame.Buffs._bluSets = frame.Buffs._bluSets or {}
		frame.Buffs.PreUpdate = LegacyPreUpdate
		frame.Buffs.SortAuras = AuraRules.Compare
		frame.Buffs._buiSettings = unitSettings
		frame.Buffs._buiIsDebuff = false

		local rows = ceil(style.max / style.perRow)
		frame.Buffs:ClearAllPoints()
		frame.Buffs:SetPoint(anchor, frame, style.anchorTo, Pixel.Scale(style.offsetX), Pixel.Scale(style.offsetY))
		frame.Buffs:SetSize(style.perRow * style.size + (style.perRow - 1) * style.gap, rows * style.size + (rows - 1) * style.gap)
		frame.Buffs:SetShown(style.shown)

		for buttonIndex = 1, frame.Buffs.createdButtons or 0 do
			local button = frame.Buffs[buttonIndex]
			if button then StyleButton(frame.Buffs, button) end
		end
	end
end

local function LegacyRefreshAuraLayout(frame, unitType)
	if not frame then return end
	LegacyApplyAuraPositions(frame, unitType)
	if not frame.unit or not UnitExists(frame.unit) then return end
	if frame.Debuffs then frame.Debuffs.needFullUpdate = true end
	if frame.Buffs then frame.Buffs.needFullUpdate = true end
	if frame.Debuffs and frame.Debuffs.ForceUpdate then frame.Debuffs:ForceUpdate() end
	if frame.Buffs and frame.Buffs.ForceUpdate then frame.Buffs:ForceUpdate() end
end

if ENGINE_OK then
	UnitFrames.CreateAuraElements = EngineCreateAuraElements
	UnitFrames.ApplyAuraPositions = EngineApplyAuraPositions
	UnitFrames.RefreshAuraLayout = EngineRefreshAuraLayout
else
	UnitFrames.CreateAuraElements = LegacyCreateAuraElements
	UnitFrames.ApplyAuraPositions = LegacyApplyAuraPositions
	UnitFrames.RefreshAuraLayout = LegacyRefreshAuraLayout
end


