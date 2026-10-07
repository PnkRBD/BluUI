local _, BUI = ...

local UnitFrames = BUI.UnitFrames
local Pixel = BUI.Pixel
local Engine = BUI.AuraEngine

local ceil, floor, max, min, random = math.ceil, math.floor, math.max, math.min, math.random
local ipairs, pairs, tostring, unpack = ipairs, pairs, tostring, unpack

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local RegisterUnitWatch = RegisterUnitWatch
local UnregisterUnitWatch = UnregisterUnitWatch

local GetAccent = BUI.BUILibClient.Colors.GetAccent

local active = {}
local auraCache = {}
local savedWatch = {}
local sampleCasts = {}
local testFrames = {}
local stageFrames = {}
local listener
local spotlight
local animFrame
local testActive = false

local ALL_UNITS = {'player', 'target', 'targettarget', 'focus', 'pet', 'boss'}
local CLASS_TOKENS = {'WARRIOR', 'PRIEST', 'MAGE', 'ROGUE', 'SHAMAN', 'DRUID', 'PALADIN', 'HUNTER', 'WARLOCK', 'DEATHKNIGHT'}
local NAMES = {'Arthas', 'Jaina', 'Thrall', 'Sylvanas', 'Illidan', 'Tyrande', 'Gul\'dan', 'Anduin', 'Valeera', 'Bolvar'}
local ICONS = {
	'Interface\\Icons\\spell_shadow_ritualofsacrifice',
	'Interface\\Icons\\spell_holy_holybolt',
	'Interface\\Icons\\spell_nature_rejuvenation',
	'Interface\\Icons\\spell_fire_flamebolt',
	'Interface\\Icons\\spell_frost_frostbolt02',
	'Interface\\Icons\\spell_nature_lightningshield',
}
local DEBUFF_TYPES = {'Magic', 'Curse', 'Poison', 'Disease'}
local CAST_ICONS = {136243, 136235, 136168, 136175}
local TAG_FIELDS = {'Name', 'HealthText', 'PowerText', 'LevelText', 'StatusText'}
local LIVE_ELEMENTS = {'Health', 'Power', 'AbsorbBars'}
local RAID_MARKER_COORDS = {
	{0, 0.25, 0, 0.25}, {0.25, 0.5, 0, 0.25}, {0.5, 0.75, 0, 0.25}, {0.75, 1, 0, 0.25},
	{0, 0.25, 0.25, 0.5}, {0.25, 0.5, 0.25, 0.5}, {0.5, 0.75, 0.25, 0.5}, {0.75, 1, 0.25, 0.5},
}
local STAGE_DOT_TILE = 16
local SAMPLE_HEALTH, SAMPLE_POWER = 75, 60
local SAMPLE_ABSORB, SAMPLE_HEAL_ABSORB = 15, 10
local CAST_SPEED = 25

local function Pick(list, index) return list[((index - 1) % #list) + 1] end

local function ClassColor(index)
	local classColor = RAID_CLASS_COLORS[Pick(CLASS_TOKENS, index)]
	return classColor.r, classColor.g, classColor.b
end

local function SampleClassColor(frame, unitType, classIndex)
	if unitType == 'player' or frame._stage then return BUI.Tools.GetUnitClassColor('player') end
	return ClassColor(classIndex)
end

local function GetFrame(unitType, index)
	if unitType == 'boss' then return UnitFrames['boss' .. (index or 1)] end
	return UnitFrames[unitType]
end

local function WatchKey(unitType, index)
	return unitType == 'boss' and ('boss' .. index) or unitType
end

local function Notify()
	if listener then listener() end
end

local function Freeze(frame)
	frame._isPreview = true
	frame.unit = nil
	for _, key in ipairs(TAG_FIELDS) do frame:Untag(frame[key]) end
	local healthShown, powerShown = frame.Health:IsShown(), frame.Power:IsShown()
	for _, element in ipairs(LIVE_ELEMENTS) do frame:PauseElement(element) end
	frame.Health:SetShown(healthShown)
	frame.Power:SetShown(powerShown)
end

local function Thaw(frame)
	frame._isPreview = nil
	frame._previewIndex = nil
	frame._previewSample = nil
	frame.unit = frame.__unit
	for _, element in ipairs(LIVE_ELEMENTS) do frame:ResumeElement(element) end
	UnitFrames.TagFontStrings(frame)
	if frame.unit then frame:UpdateAllElements('PreviewEnd') end
end

local function HealthAlpha(settings)
	return settings.transparentHealth and settings.healthBarAlpha or 1
end

local function Format(unitSettings, settings, key)
	local format = unitSettings[key]
	if format and format ~= '' then return format end
	return settings[key]
end

local function SetTagText(frame, key, unitSettings, settings, formatKey, healthPercent, powerPercent)
	local fontString = frame[key]
	if not fontString:IsShown() then return end
	fontString:SetText(UnitFrames.ParsePreviewTags(Format(unitSettings, settings, formatKey), healthPercent, powerPercent))
end

local function SetFakeCustomTags(frame, healthPercent, powerPercent)
	UnitFrames.ApplyCustomTags(frame)
	local tags = frame._customTags
	for tagIndex, entry in ipairs(UnitFrames.GetUnitSettings(frame._unitType).customTags) do
		local fontString = tags[tagIndex]
		if fontString then
			frame:Untag(fontString)
			if fontString:IsShown() and entry.tag and entry.tag ~= '' and entry.enabled ~= false then
				fontString:SetText(UnitFrames.ParsePreviewTags(entry.tag, healthPercent, powerPercent))
			end
		end
	end
end

local function SampleNameColor(frame, unitType, unitSettings, classIndex)
	if unitSettings.classColorName then
		if unitType == 'boss' then
			local hostile = unitSettings.hostileNameColor
			return hostile[1], hostile[2], hostile[3]
		elseif unitType ~= 'pet' then
			return SampleClassColor(frame, unitType, classIndex)
		end
	end
	local color = UnitFrames.GetSettings().nameColor
	return color[1], color[2], color[3]
end

local function SetFakeData(frame, unitType, index, sample, absorbs)
	frame._previewIndex = index
	frame._previewSample = sample
	absorbs = absorbs or spotlight
	local healthPercent = sample and sample.hp or (unitType == 'boss' and (95 - index * 8) or SAMPLE_HEALTH)
	local powerPercent = sample and sample.pp or (unitType == 'boss' and (100 - index * 7) or SAMPLE_POWER)
	local classIndex = sample and sample.classIndex or index
	local settings = UnitFrames.GetSettings()
	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	local colorUnit = unitType == 'pet' and 'pet' or 'player'

	frame.Health:SetMinMaxValues(0, 100)
	frame.Health:SetValue(healthPercent)
	local red, green, blue
	if settings.classColorHealth and unitType ~= 'pet' then
		red, green, blue = SampleClassColor(frame, unitType, classIndex)
	else
		red, green, blue = UnitFrames.GetHealthColor(colorUnit, settings)
	end
	frame.Health:SetStatusBarColor(red, green, blue, HealthAlpha(settings))

	if frame.Power:IsShown() then
		frame.Power:SetMinMaxValues(0, 100)
		frame.Power:SetValue(powerPercent)
		if settings.useClassColorPowerBar and unitType ~= 'pet' then
			red, green, blue = SampleClassColor(frame, unitType, classIndex)
		else
			red, green, blue = UnitFrames.GetPowerColor(colorUnit, settings, unitSettings)
		end
		frame.Power:SetStatusBarColor(red, green, blue)
	end

	if sample and sample.name then
		frame.Name:SetText(sample.name)
	elseif (unitType == 'player' or unitType == 'pet') and unitSettings.customName and unitSettings.customName ~= '' then
		frame.Name:SetText(unitSettings.customName)
	else
		frame.Name:SetText(UnitFrames.ParsePreviewTags(Format(unitSettings, settings, 'nameFormat'), healthPercent, powerPercent))
	end
	frame.Name:SetTextColor(SampleNameColor(frame, unitType, unitSettings, classIndex))

	SetTagText(frame, 'HealthText', unitSettings, settings, 'healthFormat', healthPercent, powerPercent)
	SetTagText(frame, 'PowerText', unitSettings, settings, 'powerFormat', healthPercent, powerPercent)
	SetTagText(frame, 'LevelText', unitSettings, settings, 'levelFormat', healthPercent, powerPercent)
	SetFakeCustomTags(frame, healthPercent, powerPercent)

	UnitFrames.FitAbsorbBars(frame)
	frame.Absorb:SetMinMaxValues(0, 100)
	frame.Absorb:SetValue(absorbs == 'healAbsorb' and 0 or SAMPLE_ABSORB)
	frame.HealAbsorb:SetMinMaxValues(0, 100)
	frame.HealAbsorb:SetValue((absorbs == 'healAbsorb' or absorbs == 'both') and SAMPLE_HEAL_ABSORB or 0)
end

function UnitFrames.SetPreviewSpotlight(kind)
	spotlight = kind
end

function UnitFrames.GetPreviewSpotlight()
	return spotlight
end

local function MakeIcon(parent)
	local icon = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	Pixel.ApplyBorder(icon, 1, 0, 0, 0, 1)
	local inset = Pixel.PixelSize(1)
	icon.Icon = icon:CreateTexture(nil, 'ARTWORK')
	icon.Icon:SetPoint('TOPLEFT', inset, -inset)
	icon.Icon:SetPoint('BOTTOMRIGHT', -inset, inset)
	icon.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local overlay = CreateFrame('Frame', nil, icon)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(icon:GetFrameLevel() + 20)
	icon.stacks = overlay:CreateFontString(nil, 'OVERLAY')
	icon.cd = overlay:CreateFontString(nil, 'OVERLAY')
	icon.cd:SetPoint('CENTER')
	return icon
end

local function StyleIconText(icon, style)
	Pixel.ApplyFont(icon.stacks, style.stackSize, style.font)
	Pixel.ApplyFont(icon.cd, style.cdSize, style.font)
	local stackAnchor = Engine.StackAnchors[style.stackPos]
	icon.stacks:ClearAllPoints()
	icon.stacks:SetPoint(stackAnchor[1], icon, stackAnchor[1], stackAnchor[2], stackAnchor[3])
	icon.stacks:SetShown(style.showStack)
	icon.cd:SetShown(style.showCd)
end

local function BuildIcons(list, holder, count, size, setup)
	for iconIndex = 1, max(#list, count) do
		local icon = list[iconIndex]
		if iconIndex > count then
			icon:Hide()
		else
			if not icon then
				icon = MakeIcon(holder)
				list[iconIndex] = icon
			end
			icon:SnapSize(size)
			setup(icon, iconIndex)
			icon:Show()
		end
	end
end

local function LayoutGrid(holder, icons, count, style, parent)
	if count == 0 then holder:Hide() return end
	local size, gap, perRow = style.size, style.gap, style.perRow
	local from = Engine.GrowthToAnchor(style.growX, style.growY)
	local verticalPoint = style.growY == 'UP' and 'BOTTOM' or 'TOP'
	local horizontalPoint = style.growX == 'RIGHT' and 'LEFT' or 'RIGHT'
	holder:ClearAllPoints()
	holder:SetPoint(from, parent, style.anchorTo, Pixel.Scale(style.offsetX), Pixel.Scale(style.offsetY))
	local rows = ceil(count / perRow)
	holder:SnapSize(perRow * size + (perRow - 1) * gap, rows * size + (rows - 1) * gap)
	holder:Show()
	for iconIndex = 1, count do
		local icon = icons[iconIndex]
		local column, row = (iconIndex - 1) % perRow, floor((iconIndex - 1) / perRow)
		icon:ClearAllPoints()
		if column > 0 then
			icon:SetPoint(horizontalPoint, icons[iconIndex - 1], horizontalPoint == 'LEFT' and 'RIGHT' or 'LEFT', style.growX == 'RIGHT' and gap or -gap, 0)
		elseif row > 0 then
			icon:SetPoint(verticalPoint, icons[(row - 1) * perRow + 1], verticalPoint == 'BOTTOM' and 'TOP' or 'BOTTOM', 0, style.growY == 'UP' and gap or -gap)
		else
			icon:SetPoint(from, holder, from)
		end
	end
end

local function HideAuraElements(frame)
	if frame.Debuffs then frame.Debuffs:Hide() end
	if frame.Buffs then frame.Buffs:Hide() end
	if frame.DebuffContainer then frame.DebuffContainer:Hide() end
	if frame.BuffContainer then frame.BuffContainer:Hide() end
end

local function HideStageAuras(frame)
	HideAuraElements(frame)
	local cached = auraCache[frame]
	if cached then
		cached.debuffHolder:Hide()
		cached.buffHolder:Hide()
	end
end

local function ShowFakeAuras(frame, unitType)
	if not UnitFrames.GetUnitConfig(unitType).hasAuras then return end
	HideAuraElements(frame)

	local cached = auraCache[frame]
	if not cached then
		cached = { debuffs = {}, buffs = {}, debuffHolder = CreateFrame('Frame', nil, frame), buffHolder = CreateFrame('Frame', nil, frame) }
		cached.debuffHolder:SetFrameLevel(frame:GetFrameLevel() + 15)
		cached.buffHolder:SetFrameLevel(frame:GetFrameLevel() + 15)
		auraCache[frame] = cached
	end

	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	local debuffStyle = UnitFrames.ResolveAuraStyle(unitSettings, true)
	local buffStyle = UnitFrames.ResolveAuraStyle(unitSettings, false)
	local follower, leader = UnitFrames.ResolveAuraFlow(unitSettings, debuffStyle, buffStyle)
	local debuffCount = debuffStyle.shown and debuffStyle.max or 0
	local buffCount = buffStyle.shown and buffStyle.max or 0

	BuildIcons(cached.debuffs, cached.debuffHolder, debuffCount, debuffStyle.size, function(icon, iconIndex)
		icon.Icon:SetTexture(Pick(ICONS, iconIndex))
		local debuffType = debuffStyle.showDispelType and DEBUFF_TYPES[iconIndex]
		if debuffType then
			local red, green, blue = UnitFrames.DispelTypeColor(debuffType)
			Pixel.SetBorderColor(icon, red, green, blue, 1)
		else
			Pixel.SetBorderColor(icon, unpack(debuffStyle.baseColor))
		end
		StyleIconText(icon, debuffStyle)
		icon.stacks:SetText(iconIndex > 2 and tostring(iconIndex) or '')
		icon.cd:SetText(tostring(10 + iconIndex))
	end)

	BuildIcons(cached.buffs, cached.buffHolder, buffCount, buffStyle.size, function(icon, iconIndex)
		icon.Icon:SetTexture(Pick(ICONS, iconIndex + 2))
		Pixel.SetBorderColor(icon, unpack(buffStyle.baseColor))
		StyleIconText(icon, buffStyle)
		icon.stacks:SetText('')
		icon.cd:SetText(tostring(30 + iconIndex * 5))
	end)

	if not follower then
		LayoutGrid(cached.debuffHolder, cached.debuffs, debuffCount, debuffStyle, frame)
		LayoutGrid(cached.buffHolder, cached.buffs, buffCount, buffStyle, frame)
		return
	end
	local leaderIsDebuff = leader == debuffStyle
	local leaderIcons, leaderCount, leaderHolder = cached.buffs, buffCount, cached.buffHolder
	local followerIcons, followerCount, followerHolder = cached.debuffs, debuffCount, cached.debuffHolder
	if leaderIsDebuff then
		leaderIcons, leaderCount, leaderHolder = cached.debuffs, debuffCount, cached.debuffHolder
		followerIcons, followerCount, followerHolder = cached.buffs, buffCount, cached.buffHolder
	end
	local flow = cached.flow or {}
	cached.flow = flow
	wipe(flow)
	for iconIndex = 1, leaderCount do flow[iconIndex] = leaderIcons[iconIndex] end
	for iconIndex = 1, followerCount do flow[leaderCount + iconIndex] = followerIcons[iconIndex] end
	LayoutGrid(leaderHolder, flow, leaderCount + followerCount, leader, frame)
	followerHolder:ClearAllPoints()
	followerHolder:SetAllPoints(leaderHolder)
	followerHolder:Show()
end

local function RestoreContainer(container)
	if not container then return end
	container:Show()
	if container.UpdateAllAuras then container:UpdateAllAuras() end
end

local function HideFakeAuras(frame)
	local cached = auraCache[frame]
	if cached then
		cached.debuffHolder:Hide()
		cached.buffHolder:Hide()
	end
	if frame.Debuffs then frame.Debuffs:Show() end
	if frame.Buffs then frame.Buffs:Show() end
	RestoreContainer(frame.DebuffContainer)
	RestoreContainer(frame.BuffContainer)
end

local function PaintSampleCast(frame)
	local sample = sampleCasts[frame]
	if not sample then return false end
	local castbar = frame.Castbar
	local showIcon = BUI.CastBar.GetSettings(sample.barType).showIcon
	castbar.holdTime = 1e9
	castbar:SetMinMaxValues(0, 100)
	castbar:SetValue(sample.value)
	castbar.Text:SetText(Pick(NAMES, sample.index) .. '\'s Wrath')
	castbar.Text:Show()
	castbar.Time:SetFormattedText('%.1f', sample.value / CAST_SPEED)
	castbar.Time:Show()
	castbar.Icon:SetTexture(Pick(CAST_ICONS, sample.index))
	castbar.Icon:SetShown(showIcon)
	castbar._iconFrame:SetShown(showIcon)
	castbar:Show()
	castbar._container:Show()
	return true
end

UnitFrames.PaintSampleCast = PaintSampleCast

local function ShowSampleCast(frame, barType, index)
	if not frame.Castbar or not BUI.CastBar.GetSettings(barType).enabled then return end
	sampleCasts[frame] = { barType = barType, index = index, value = 30 + index * 12 }
	PaintSampleCast(frame)
end

local function HideSampleCast(frame)
	if not sampleCasts[frame] then return end
	sampleCasts[frame] = nil
	frame.Castbar.holdTime = 0
	BUI.CastBar.HideQuietly(frame.Castbar)
end

local function ShowUnit(frame, unitType, index, sample)
	local key = WatchKey(unitType, index)
	if key ~= 'player' then
		UnregisterUnitWatch(frame)
		savedWatch[key] = true
	end
	Freeze(frame)
	UnitFrames.ApplySettings(frame, unitType, index)
	SetFakeData(frame, unitType, index or 1, sample)
	ShowFakeAuras(frame, unitType)
	frame:Show()
	Pixel.SetBorderColor(frame, GetAccent())
end

local function HideUnit(frame, unitType, index)
	HideSampleCast(frame)
	HideFakeAuras(frame)
	Thaw(frame)
	local key = WatchKey(unitType, index)
	if savedWatch[key] then
		RegisterUnitWatch(frame)
		savedWatch[key] = nil
	end
end

local function ReleaseTestFrame(key)
	local entry = testFrames[key]
	if not entry then return end
	testFrames[key] = nil
	entry.frame.RaidTargetIndicator:Hide()
end

local function ReleaseTestEntries(unitType)
	if unitType == 'boss' then
		for bossIndex = 1, 5 do ReleaseTestFrame('boss' .. bossIndex) end
	else
		ReleaseTestFrame(unitType)
	end
end

local function SavePosition(unitType, x, y)
	local position = UnitFrames.GetUnitSettings(unitType).position
	position.x, position.y = BUI.Round(x), BUI.Round(y)
	return position
end

local function LockPreview(unitType)
	UnitFrames.HidePreview(unitType)
	BUI.Print(unitType:sub(1, 1):upper() .. unitType:sub(2) .. ' preview hidden.')
end

local function SetupDrag(frame, unitType)
	BUI.Dragging.MakeDraggable(frame, {
		snapCenter = true,
		showHint = true,
		skipClickThrough = true,
		isLocked = function() return BUI.ResolveAnchorFrame(UnitFrames.GetUnitSettings(unitType).anchorFrame) ~= nil end,
		onDragging = function(x, y)
			SavePosition(unitType, x, y)
			if unitType == 'boss' then
				for bossIndex = 2, 5 do
					local bossFrame = UnitFrames['boss' .. bossIndex]
					if bossFrame then UnitFrames.ApplyPosition(bossFrame, 'boss', bossIndex) end
				end
			end
		end,
		onPositionChanged = function(x, y)
			local position = SavePosition(unitType, x, y)
			position.point, position.relPoint = 'CENTER', 'CENTER'
			UnitFrames:Refresh()
			UnitFrames.UpdatePreviews()
			Notify()
		end,
		onRightClick = function() LockPreview(unitType) end,
	})
end

function UnitFrames.StageFrame(unitType, index, parent, options)
	local key = WatchKey(unitType, index)
	local frame = stageFrames[key]
	if not frame then
		if InCombatLockdown() then return nil end
		BUI.oUF:SetActiveStyle('BluUIStage')
		frame = BUI.oUF:Spawn(index and (unitType .. index) or unitType, 'BUI_Stage_' .. key)
		BUI.oUF:SetActiveStyle('BluUI')
		UnregisterUnitWatch(frame)
		frame:EnableMouse(false)
		stageFrames[key] = frame
	end
	frame:SetParent(parent)
	frame:SetFrameStrata(parent:GetFrameStrata())
	frame:SetFrameLevel(parent:GetFrameLevel() + 2)
	Freeze(frame)
	UnitFrames.ApplySettings(frame, unitType, index)
	SetFakeData(frame, unitType, index or 1, nil, options and options.absorbs)
	if options and options.bare then HideStageAuras(frame) else ShowFakeAuras(frame, unitType) end
	frame:Show()
	return frame
end

local staged = setmetatable({}, { __mode = 'k' })
local stagePlates = setmetatable({}, { __mode = 'k' })

function UnitFrames.ClearStage(stage)
	for _, frame in ipairs(staged[stage] or {}) do
		frame:Hide()
		local plate = stagePlates[stage][frame]
		plate:Hide()
		plate.dots:Hide()
	end
	staged[stage] = {}
end

function UnitFrames.StageInto(stage, kit, unitType, index, maxWidth, maxHeight, options)
	local frame = UnitFrames.StageFrame(unitType, index, stage, options)
	if not frame then return nil end
	local scale = min(1, maxWidth / frame:GetWidth(), maxHeight / frame:GetHeight())
	frame:SetScale(scale)
	local width, height = frame:GetWidth() * scale, frame:GetHeight() * scale
	local plates = stagePlates[stage] or {}
	stagePlates[stage] = plates
	local plate = plates[frame]
	if not plate then
		plate = kit.Fill(stage, 'control', 'BACKGROUND')
		plate:SetPoint('TOPLEFT', frame, 'TOPLEFT')
		plate:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT')
		plate.dots = kit.DotGrid(stage, width, height, 'muted')
		plate.dots:SetAllPoints(plate)
		plates[frame] = plate
	end
	plate.dots:SetTexCoord(0, width / STAGE_DOT_TILE, 0, height / STAGE_DOT_TILE)
	plate:Show()
	plate.dots:Show()
	local list = staged[stage] or {}
	staged[stage] = list
	list[#list + 1] = frame
	return frame, width, height
end

function UnitFrames.PlaceStaged(frame, stage, x, y)
	local scale = frame:GetScale()
	frame:ClearAllPoints()
	frame:SetPoint('CENTER', stage, 'CENTER', x / scale, y / scale)
end

function UnitFrames.StagePair(stage, kit, maxWidth, maxHeight, gap, options)
	local player, playerWidth = UnitFrames.StageInto(stage, kit, 'player', nil, maxWidth, maxHeight, options)
	local target, targetWidth = UnitFrames.StageInto(stage, kit, 'target', nil, maxWidth, maxHeight, options)
	if not player or not target then return nil end
	local playerX, targetX = -(playerWidth / 2 + gap), targetWidth / 2 + gap
	UnitFrames.PlaceStaged(player, stage, playerX, 0)
	UnitFrames.PlaceStaged(target, stage, targetX, 0)
	return playerX, targetX
end

function UnitFrames.SetPreviewListener(callback)
	listener = callback
end

function UnitFrames.ShowPreview(unitType)
	if InCombatLockdown() then BUI.Print('Cannot preview during combat.') return end
	if active[unitType] then return end
	local anchor = GetFrame(unitType)
	if not anchor then return end
	active[unitType] = 'preview'
	if unitType == 'boss' then
		for bossIndex = 1, 5 do
			local bossFrame = GetFrame('boss', bossIndex)
			if bossFrame then
				ShowUnit(bossFrame, 'boss', bossIndex)
				ShowSampleCast(bossFrame, 'boss', bossIndex)
			end
		end
	else
		ShowUnit(anchor, unitType)
	end
	SetupDrag(anchor, unitType)
	Notify()
	BUI.Print(unitType .. ' preview shown, right-click hides it.')
end

function UnitFrames.HidePreview(unitType)
	if not active[unitType] then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(function() UnitFrames.HidePreview(unitType) end, 'UF.Preview.Hide.' .. unitType)
		return
	end
	active[unitType] = nil
	ReleaseTestEntries(unitType)
	BUI.Dragging.Release(GetFrame(unitType))
	if unitType == 'boss' then
		for bossIndex = 1, 5 do
			local bossFrame = GetFrame('boss', bossIndex)
			if bossFrame then HideUnit(bossFrame, 'boss', bossIndex) end
		end
	else
		HideUnit(GetFrame(unitType), unitType)
	end
	UnitFrames:Refresh()
	Notify()
end

function UnitFrames.TogglePreview(unitType)
	if active[unitType] then UnitFrames.HidePreview(unitType) else UnitFrames.ShowPreview(unitType) end
end

function UnitFrames.IsPreviewShown(unitType)
	return active[unitType] == 'preview'
end

function UnitFrames.UpdatePreviews()
	for unitType in pairs(active) do
		local count = unitType == 'boss' and 5 or 1
		for frameIndex = 1, count do
			local bossIndex = unitType == 'boss' and frameIndex or nil
			local frame = GetFrame(unitType, bossIndex)
			if frame then
				SetFakeData(frame, unitType, frame._previewIndex, frame._previewSample)
				ShowFakeAuras(frame, unitType)
				Pixel.SetBorderColor(frame, GetAccent())
				PaintSampleCast(frame)
			end
		end
	end
end

function UnitFrames.LockAllPreviews()
	for unitType, kind in pairs(active) do
		if kind == 'preview' then UnitFrames.HidePreview(unitType) end
	end
end

local function Animate(_, elapsed)
	local settings = UnitFrames.GetSettings()
	for _, entry in pairs(testFrames) do
		local frame, sample = entry.frame, entry.sample
		local unitSettings = UnitFrames.GetUnitSettings(entry.unitType)
		entry.healthTimer = entry.healthTimer + elapsed
		if entry.healthTimer > entry.healthWait then
			entry.healthTimer = 0
			entry.healthWait = 0.4 + random() * 0.8
			sample.hp = floor(max(15, min(95, sample.hp + (random() < 0.7 and -(5 + random() * 15) or (3 + random() * 7)))))
			frame.Health:SetValue(sample.hp)
			SetTagText(frame, 'HealthText', unitSettings, settings, 'healthFormat', sample.hp, sample.pp)
		end
		entry.powerTimer = entry.powerTimer + elapsed
		if entry.powerTimer > entry.powerWait then
			entry.powerTimer = 0
			entry.powerWait = 0.3 + random() * 0.5
			sample.pp = floor(max(5, min(95, sample.pp + (random() < 0.5 and -(10 + random() * 20) or (5 + random() * 15)))))
			if frame.Power:IsShown() then frame.Power:SetValue(sample.pp) end
			SetTagText(frame, 'PowerText', unitSettings, settings, 'powerFormat', sample.hp, sample.pp)
		end
		local cast = sampleCasts[frame]
		if cast then
			cast.value = (cast.value + elapsed * CAST_SPEED) % 100
			frame.Castbar:SetValue(cast.value)
			frame.Castbar.Time:SetFormattedText('%.1f', cast.value / CAST_SPEED)
		end
	end
end

local function ShowAll()
	if InCombatLockdown() then BUI.Print('Cannot show test mode during combat.') return end
	if testActive then return end
	testActive = true
	local index = 0
	for _, unitType in ipairs(ALL_UNITS) do
		if not active[unitType] and UnitFrames.GetUnitSettings(unitType).enabled ~= false then
			local count = unitType == 'boss' and 5 or 1
			for frameIndex = 1, count do
				local bossIndex = unitType == 'boss' and frameIndex or nil
				local frame = GetFrame(unitType, bossIndex)
				if frame then
					index = index + 1
					active[unitType] = 'test'
					local sample = { hp = max(15, 95 - index * 8), pp = max(5, 100 - index * 7), name = Pick(NAMES, index), classIndex = index }
					ShowUnit(frame, unitType, bossIndex, sample)
					if index <= 8 then
						frame.RaidTargetIndicator:SetTexture(BUI.C.RAID_ICON_TEXTURE)
						frame.RaidTargetIndicator:SetTexCoord(unpack(RAID_MARKER_COORDS[index]))
						frame.RaidTargetIndicator:Show()
					end
					ShowSampleCast(frame, unitType, index)
					testFrames[WatchKey(unitType, bossIndex)] = {
						frame = frame, unitType = unitType, index = bossIndex, sample = sample,
						healthTimer = 0, healthWait = 0.5, powerTimer = 0, powerWait = 0.6,
					}
				end
			end
		end
	end
	if not animFrame then
		animFrame = CreateFrame('Frame')
		animFrame:SetScript('OnUpdate', BUI.Profiler.Wrap('UnitFrames.Preview test animation', Animate))
	end
	animFrame:Show()
	BUI.Print('Test mode |cff00ff00enabled|r. Type |cff' .. BUI.C.COLOR_PINK .. '/buitest|r to disable.')
end

local function HideAll()
	if not testActive then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(HideAll, 'UF.Preview.HideAll')
		return
	end
	testActive = false
	animFrame:Hide()
	for key, entry in pairs(testFrames) do
		active[entry.unitType] = nil
		HideUnit(entry.frame, entry.unitType, entry.index)
		ReleaseTestFrame(key)
	end
	UnitFrames:Refresh()
	BUI.Print('Test mode |cffff6600disabled|r.')
end

UnitFrames.TestMode = {
	Toggle = function() if testActive then HideAll() else ShowAll() end end,
	IsActive = function() return testActive end,
}
