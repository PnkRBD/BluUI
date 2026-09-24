local _, BUI = ...

local UnitFrames = BUI.UnitFrames
local Pixel = BUI.Pixel

local ceil, floor, max, min, random = math.ceil, math.floor, math.max, math.min, math.random
local ipairs, pairs, tostring, unpack, wipe = ipairs, pairs, tostring, unpack, wipe

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local RegisterUnitWatch = RegisterUnitWatch
local UIParent = UIParent
local UnregisterUnitWatch = UnregisterUnitWatch

local GetAccent = BUI.BUILibClient.Colors.GetAccent

local STACK_POSITIONS = {
	TOPLEFT     = { 'TOPLEFT', 1, -1 },
	TOP         = { 'TOP', 0, -1 },
	TOPRIGHT    = { 'TOPRIGHT', -1, -1 },
	LEFT        = { 'LEFT', 1, 0 },
	CENTER      = { 'CENTER', 0, 0 },
	RIGHT       = { 'RIGHT', -1, 0 },
	BOTTOMLEFT  = { 'BOTTOMLEFT', 1, 1 },
	BOTTOM      = { 'BOTTOM', 0, 1 },
	BOTTOMRIGHT = { 'BOTTOMRIGHT', -1, 1 },
}

local active = {}
local hintLabels = {}
local auraCache = {}
local savedWatch = {}
local positionCallbacks = {}
local animEntries = {}
local testFrames = {}

local animFrame
local testActive = false

UnitFrames._previewFrames = {}
UnitFrames._previewButtons = {}

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
local DEBUFF_TYPES = {'Magic', 'Curse', 'Poison', 'Disease', nil, nil}
local CAST_ICONS = {136243, 136235, 136168, 136175}
local TAG_FIELDS = {'Name', 'HealthText', 'PowerText', 'LevelText'}

local function Pick(list, index) return list[((index - 1) % #list) + 1] end

local function ClassColor(index)
	local classColor = RAID_CLASS_COLORS[Pick(CLASS_TOKENS, index)]
	return classColor.r, classColor.g, classColor.b
end

local function GetFrame(unitType, index)
	if unitType == 'boss' then return UnitFrames['boss' .. (index or 1)] end
	return UnitFrames[unitType]
end

local function WatchKey(unitType, index)
	return unitType == 'boss' and ('boss' .. index) or unitType
end

local function UntagAll(frame)
	for _, key in ipairs(TAG_FIELDS) do
		if frame[key] then frame:Untag(frame[key]) end
	end
end

local function Freeze(frame)
	if not frame._isPreview then frame._savedUnit = frame.unit end
	frame._isPreview = true
	frame.unit = nil
	UntagAll(frame)
end

local function Thaw(frame)
	frame._isPreview = nil
	frame._previewIndex = nil
	frame.unit = frame._savedUnit
	frame._savedUnit = nil
	UnitFrames.TagFontStrings(frame)
	if frame.unit then frame:UpdateAllElements('PreviewEnd') end
end

local function SetTagText(frame, key, unitSettings, settings, formatKey, healthPercent, powerPercent)
	local fontString = frame[key]
	if not fontString or (key ~= 'Name' and not fontString:IsShown()) then return end
	local format = unitSettings[formatKey] or settings[formatKey]
	fontString:SetText(UnitFrames.ParsePreviewTags(format, healthPercent, powerPercent))
end

local function SetFakeCustomTags(frame, healthPercent, powerPercent)
	UnitFrames.ApplyCustomTags(frame)
	local tags = frame._customTags
	local entries = UnitFrames.GetUnitSettings(frame._unitType).customTags
	for tagIndex, entry in ipairs(entries) do
		local fontString = tags[tagIndex]
		if fontString then
			frame:Untag(fontString)
			if fontString:IsShown() and entry.tag and entry.tag ~= '' and entry.enabled ~= false then
				fontString:SetText(UnitFrames.ParsePreviewTags(entry.tag, healthPercent, powerPercent))
			end
		end
	end
end

local function SetFakeData(frame, unitType, index)
	local healthPercent = max(20, min(95, unitType == 'boss' and (95 - index * 8) or 75))
	local powerPercent = max(10, min(95, unitType == 'boss' and (100 - index * 7) or 60))
	frame._previewIndex = index

	local settings = UnitFrames.GetSettings()
	local settingsUnitType = unitType == 'boss' and 'boss' or unitType
	local unitSettings = UnitFrames.GetUnitSettings(settingsUnitType)

	if frame.Health then
		frame.Health:SetMinMaxValues(0, 100)
		frame.Health:SetValue(healthPercent)
		local healthRed, healthGreen, healthBlue
		if settings.classColorHealth then
			healthRed, healthGreen, healthBlue = ClassColor(index)
		else
			healthRed, healthGreen, healthBlue = UnitFrames.GetHealthColor('player', settings)
		end
		frame.Health:SetStatusBarColor(healthRed, healthGreen, healthBlue)
	end

	if frame.Power and frame.Power:IsShown() then
		frame.Power:SetMinMaxValues(0, 100)
		frame.Power:SetValue(powerPercent)
		frame.Power:SetStatusBarColor(UnitFrames.GetPowerColor('player', settings, unitSettings))
	end

	if frame.Name then
		local name
		if (unitType == 'player' or unitType == 'pet') and unitSettings.customName and unitSettings.customName ~= '' then
			name = unitSettings.customName
		else
			local format = unitSettings.nameFormat or settings.nameFormat
			name = UnitFrames.ParsePreviewTags(format, healthPercent, powerPercent)
		end
		frame.Name:SetText(name)
		local useClassColor = unitSettings.classColorName
		if unitType == 'boss' or unitType == 'pet' then useClassColor = useClassColor ~= false end
		if useClassColor then frame.Name:SetTextColor(ClassColor(index)) else frame.Name:SetTextColor(1, 1, 1) end
	end

	SetTagText(frame, 'HealthText', unitSettings, settings, 'healthFormat', healthPercent, powerPercent)
	SetTagText(frame, 'PowerText', unitSettings, settings, 'powerFormat', healthPercent, powerPercent)
	SetTagText(frame, 'LevelText', unitSettings, settings, 'levelFormat', healthPercent, powerPercent)
	SetFakeCustomTags(frame, healthPercent, powerPercent)

	if frame.Absorb and frame.Health then
		UnitFrames.ApplyAbsorbVisual(frame.Absorb, UnitFrames.BuildAbsorbCfg(settings))
		frame.Absorb:SetReverseFill(true)
		frame.Absorb:ClearAllPoints()
		local healthTexture = frame.Health:GetStatusBarTexture()
		if healthTexture then frame.Absorb:SetAllPoints(healthTexture) end
		frame.Absorb:SetMinMaxValues(0, 100)
		frame.Absorb:SetValue(15)
		frame.Absorb:Show()
	end
end

local function MakeIcon(parent)
	local iconFrame = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	Pixel.ApplyBorder(iconFrame, 1, 0, 0, 0, 1)
	local inset = Pixel.PixelSize(1)
	iconFrame.Icon = iconFrame:CreateTexture(nil, 'ARTWORK')
	iconFrame.Icon:SetPoint('TOPLEFT', inset, -inset)
	iconFrame.Icon:SetPoint('BOTTOMRIGHT', -inset, inset)
	iconFrame.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local overlay = CreateFrame('Frame', nil, iconFrame)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(iconFrame:GetFrameLevel() + 20)
	local font = UnitFrames.GetFont()
	iconFrame.stacks = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(iconFrame.stacks, 10, font)
	iconFrame.stacks:SetPoint('BOTTOMRIGHT', 0, 0)
	iconFrame.cd = overlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(iconFrame.cd, 10, font)
	iconFrame.cd:SetPoint('CENTER', 0, 0)
	return iconFrame
end

local function LayoutGrid(holder, icons, count, size, gap, perRow, growX, growY, anchorPoint, offsetX, offsetY, parent)
	if count == 0 then holder:Hide() return end
	local verticalPoint = growY == 'UP' and 'BOTTOM' or 'TOP'
	local horizontalPoint = growX == 'RIGHT' and 'LEFT' or 'RIGHT'
	local from = verticalPoint .. horizontalPoint
	holder:ClearAllPoints()
	holder:SetPoint(from, parent, anchorPoint, Pixel.Scale(offsetX), Pixel.Scale(offsetY))
	local rows = ceil(count / perRow)
	holder:SnapSize(perRow * size + (perRow - 1) * gap, rows * size + (rows - 1) * gap)
	holder:Show()
	for iconIndex = 1, count do
		icons[iconIndex]:ClearAllPoints()
		local col, row = (iconIndex - 1) % perRow, floor((iconIndex - 1) / perRow)
		if col == 0 then
			if row == 0 then
				icons[iconIndex]:SetPoint(from, holder, from, 0, 0)
			else
				local above = icons[((row - 1) * perRow) + 1]
				icons[iconIndex]:SetPoint(verticalPoint, above, verticalPoint == 'BOTTOM' and 'TOP' or 'BOTTOM', 0, growY == 'UP' and gap or -gap)
			end
		else
			local previousIcon = icons[iconIndex - 1]
			icons[iconIndex]:SetPoint(horizontalPoint, previousIcon, horizontalPoint == 'LEFT' and 'RIGHT' or 'LEFT', growX == 'RIGHT' and gap or -gap, 0)
		end
	end
end

local function BuildIcons(list, holder, count, size, setupCallback)
	for iconIndex = 1, max(6, count) do
		if not list[iconIndex] then list[iconIndex] = MakeIcon(holder) end
		list[iconIndex]:SnapSize(size)
		if iconIndex <= count then setupCallback(list[iconIndex], iconIndex) list[iconIndex]:Show() else list[iconIndex]:Hide() end
	end
end

local function ShowFakeAuras(frame, unitType, index)
	if unitType ~= 'player' and unitType ~= 'target' and unitType ~= 'focus' and unitType ~= 'boss' and unitType ~= 'targettarget' then return end

	local cacheKey = unitType == 'boss' and ('boss' .. (index or 1)) or unitType

	if frame.Debuffs then frame.Debuffs:Hide() end
	if frame.Buffs then frame.Buffs:Hide() end
	if frame.DebuffContainer then frame.DebuffContainer:Hide() end
	if frame.BuffContainer then frame.BuffContainer:Hide() end

	local cached = auraCache[cacheKey]
	if not cached then
		cached = { debuffs = {}, buffs = {}, dH = CreateFrame('Frame', nil, frame), bH = CreateFrame('Frame', nil, frame) }
		cached.dH:SetFrameLevel(frame:GetFrameLevel() + 15)
		cached.bH:SetFrameLevel(frame:GetFrameLevel() + 15)
		auraCache[cacheKey] = cached
	end
	cached.dH:SetParent(frame)
	cached.bH:SetParent(frame)

	local unitSettings = UnitFrames.GetUnitSettings(unitType)
	local font = UnitFrames.GetFont()
	local debuffSize, debuffGap = unitSettings.debuffIconSize or unitSettings.auraIconSize or 22, unitSettings.debuffSpacing or unitSettings.auraSpacing or 2
	local debuffCount = unitSettings.showDebuffs and min(unitSettings.maxDebuffs or 6, 4) or 0
	local buffSize, buffGap = unitSettings.buffIconSize or unitSettings.auraIconSize or 22, unitSettings.buffSpacing or unitSettings.auraSpacing or 2
	local buffCount = unitSettings.showBuffs and min(unitSettings.maxBuffs or 4, 3) or 0

	BuildIcons(cached.debuffs, cached.dH, debuffCount, debuffSize, function(icon, iconIndex)
		icon.Icon:SetTexture(Pick(ICONS, iconIndex))
		local debuffType = DEBUFF_TYPES[iconIndex]
		local debuffRed, debuffGreen, debuffBlue
		if debuffType and unitSettings.showDebuffType ~= false then debuffRed, debuffGreen, debuffBlue = UnitFrames.DispelTypeColor(debuffType) end
		if debuffRed then Pixel.SetBorderColor(icon, debuffRed, debuffGreen, debuffBlue, 1)
		else Pixel.SetBorderColor(icon, 0.8, 0, 0, 1) end
		icon.stacks:SetText(iconIndex > 2 and tostring(iconIndex) or '')
		Pixel.ApplyFont(icon.stacks, unitSettings.debuffStackSize or unitSettings.auraStackSize or 10, font)
		local debuffPosition = STACK_POSITIONS[unitSettings.debuffStackPos or 'BOTTOMRIGHT'] or STACK_POSITIONS.BOTTOMRIGHT
		icon.stacks:ClearAllPoints()
		icon.stacks:SetPoint(debuffPosition[1], icon, debuffPosition[1], debuffPosition[2], debuffPosition[3])
		icon.cd:SetText(tostring(10 + iconIndex))
		Pixel.ApplyFont(icon.cd, unitSettings.debuffCdSize or unitSettings.auraCdSize or 10, font)
	end)

	BuildIcons(cached.buffs, cached.bH, buffCount, buffSize, function(icon, iconIndex)
		icon.Icon:SetTexture(Pick(ICONS, iconIndex + 2))
		Pixel.SetBorderColor(icon, 0, 0, 0, 1)
		icon.stacks:SetText('')
		local buffPosition = STACK_POSITIONS[unitSettings.buffStackPos or 'BOTTOMRIGHT'] or STACK_POSITIONS.BOTTOMRIGHT
		icon.stacks:ClearAllPoints()
		icon.stacks:SetPoint(buffPosition[1], icon, buffPosition[1], buffPosition[2], buffPosition[3])
		icon.cd:SetText(tostring(30 + iconIndex * 5))
		Pixel.ApplyFont(icon.cd, unitSettings.buffCdSize or unitSettings.auraCdSize or 10, font)
	end)

	local debuffGrowthX = unitSettings.debuffGrowthX
	local debuffGrowthY = unitSettings.debuffGrowthY
	local debuffAnchor = unitSettings.debuffAnchorPoint
	LayoutGrid(cached.dH, cached.debuffs, debuffCount, debuffSize, debuffGap, unitSettings.debuffsPerRow or 8,
		debuffGrowthX, debuffGrowthY, debuffAnchor, unitSettings.debuffOffsetX, unitSettings.debuffOffsetY, frame)

	local buffGrowthX = unitSettings.buffGrowthX or 'RIGHT'
	local buffGrowthY = unitSettings.buffGrowthY or 'DOWN'
	local buffAnchor = unitSettings.buffAnchorPoint or 'BOTTOMLEFT'
	LayoutGrid(cached.bH, cached.buffs, buffCount, buffSize, buffGap, unitSettings.buffsPerRow or 8,
		buffGrowthX, buffGrowthY, buffAnchor, unitSettings.buffOffsetX or 0, unitSettings.buffOffsetY or 0, frame)
end

local function HideFakeAuras(frame, unitType, index)
	local cacheKey = unitType == 'boss' and ('boss' .. (index or 1)) or unitType
	local cached = auraCache[cacheKey]
	if cached then cached.dH:Hide() cached.bH:Hide() end
	if frame.Debuffs then frame.Debuffs:Show() end
	if frame.Buffs then frame.Buffs:Show() end
	for _, key in ipairs({ 'DebuffContainer', 'BuffContainer' }) do
		local container = frame[key]
		if container then
			container:Show()
			if container.UpdateAllAuras then container:UpdateAllAuras() end
		end
	end
end

local function ShowHint(frame, unitType)
	if hintLabels[unitType] then hintLabels[unitType]:Show() return end
	local hintLabel = frame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(hintLabel, 11, BUI.GetGlobalFont())
	hintLabel:SetPoint('BOTTOM', frame, 'TOP', 0, Pixel.Scale(5))
	hintLabel:SetText('Drag to Reposition | Right-Click to Lock')
	hintLabel:SetTextColor(1, 1, 1, 1)
	hintLabels[unitType] = hintLabel
end

local function HideHint(unitType) if hintLabels[unitType] then hintLabels[unitType]:Hide() end end

local function SetupDrag(frame, unitType)
	BUI.Dragging.MakeDraggable(frame, {
		snapCenter = true,
		isLocked = function()
			if BUI.ResolveAnchorFrame(UnitFrames.GetUnitSettings(unitType).anchorFrame) then return true end
			return false
		end,
		onDragging = function(x, y)
			x, y = BUI.Round(x), BUI.Round(y)
			local db = BUI.GetDB()
			db.unitFrames[unitType].position.x = x
			db.unitFrames[unitType].position.y = y
			if positionCallbacks[unitType] then positionCallbacks[unitType](x, y) end
			if unitType == 'boss' then
				for bossIndex = 2, 5 do
					local bossFrame = UnitFrames['boss' .. bossIndex]
					if bossFrame then UnitFrames.ApplyPosition(bossFrame, 'boss', bossIndex) end
				end
			end
		end,
		onPositionChanged = function(x, y)
			x, y = BUI.Round(x), BUI.Round(y)
			local db = BUI.GetDB()
			db.unitFrames[unitType].position.x = x
			db.unitFrames[unitType].position.y = y
			db.unitFrames[unitType].position.point = 'CENTER'
			db.unitFrames[unitType].position.relPoint = 'CENTER'
			if positionCallbacks[unitType] then positionCallbacks[unitType](x, y) end
			frame:ClearAllPoints()
			frame:SetPoint('CENTER', UIParent, 'CENTER', x, y)
			UnitFrames.InvalidateSettingsCache()
			UnitFrames:Refresh()
			UnitFrames.UpdatePreviews()
		end,
		onRightClick = function() UnitFrames.LockPreview(unitType) end,
	})
end

local function TeardownDrag(frame)
	if not frame then return end
	frame:SetScript('OnDragStart', nil)
	frame:SetScript('OnDragStop', nil)
	frame:SetScript('OnMouseUp', nil)
	frame:SetScript('OnUpdate', nil)
	frame:SetMovable(false)
	frame.dragActive = nil
	frame.dragLocked = nil
	frame.dragOnPosition = nil
	frame.dragOnDragging = nil
	frame.dragOnRightClick = nil
	frame.RefreshDragState = nil
end

local function ShowUnit(frame, unitType, index)
	local key = WatchKey(unitType, index)
	if key ~= 'player' then
		UnregisterUnitWatch(frame)
		savedWatch[key] = true
	end
	Freeze(frame)
	UnitFrames.ApplySettings(frame, unitType == 'boss' and 'boss' or unitType, index)
	SetFakeData(frame, unitType == 'boss' and 'boss' or unitType, index or 1)
	ShowFakeAuras(frame, unitType, index)
	frame:Show()
	Pixel.SetBorderColor(frame, GetAccent())
end

local function HideUnit(frame, unitType, index)
	if unitType ~= 'boss' then
		TeardownDrag(frame)
	end
	HideFakeAuras(frame, unitType, index)
	Thaw(frame)
	if frame.Absorb then frame.Absorb:Hide() end
	local settings = UnitFrames.GetSettings()
	local borderColor = (unitType == 'pet') and settings.petBorderColor or settings.borderColor
	Pixel.SetBorderColor(frame, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	local key = WatchKey(unitType, index)
	if savedWatch[key] then
		RegisterUnitWatch(frame)
		savedWatch[key] = nil
	end
end

function UnitFrames.RegisterPositionCallback(unitType, callback) positionCallbacks[unitType] = callback end
function UnitFrames.UnregisterPositionCallback(unitType) positionCallbacks[unitType] = nil end

local bossCastbarPreviewActive = false

function UnitFrames.ShowBossCastbarPreview()
	local settings = BUI.CastBar.GetSettings('boss')
	if not settings or not settings.enabled then return end

	for bossIndex = 1, 5 do
		local bossFrame = UnitFrames['boss' .. bossIndex]
		if bossFrame then
			BUI.CastBar.ApplyBossCastbar(bossFrame, bossIndex)
			local castbar = bossFrame.Castbar
			local container = bossFrame._castbarContainer
			if castbar and container then
				castbar:SetMinMaxValues(0, 100)
				castbar:SetValue(30 + bossIndex * 12)
				local barColor = settings.barColor
				if settings.useIndividualColors and settings.bossColors then
					barColor = settings.bossColors[bossIndex] or barColor
				end
				castbar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)
				if castbar.Text then castbar.Text:SetText(Pick(NAMES, bossIndex) .. '\'s Wrath') castbar.Text:Show() end
				if castbar.Time then castbar.Time:SetFormattedText('%.1f', 1.2 + bossIndex * 0.3) castbar.Time:Show() end
				if castbar.Icon then castbar.Icon:SetTexture(CAST_ICONS[((bossIndex - 1) % #CAST_ICONS) + 1]) castbar.Icon:Show() end

				castbar.holdTime = 1e9
				castbar:Show()
				container:Show()
			end
		end
	end
	bossCastbarPreviewActive = true
end

function UnitFrames.HideBossCastbarPreview()
	if not bossCastbarPreviewActive then return end
	bossCastbarPreviewActive = false
	for bossIndex = 1, 5 do
		local bossFrame = UnitFrames['boss' .. bossIndex]
		if bossFrame and bossFrame.Castbar then
			bossFrame.Castbar.holdTime = 0
			bossFrame.Castbar:Hide()
			if bossFrame._castbarContainer then bossFrame._castbarContainer:Hide() end
		end
	end
end

function UnitFrames.ShowPreview(unitType)
	if InCombatLockdown() then print('|cff6D00FDBluUI:|r Cannot preview during combat.') return end
	if active[unitType] then return end
	active[unitType] = true

	if unitType == 'boss' then
		for bossIndex = 1, 5 do
			local bossFrame = GetFrame('boss', bossIndex)
			if bossFrame then ShowUnit(bossFrame, 'boss', bossIndex) end
		end
		local anchor = UnitFrames['boss1']
		if not anchor then active[unitType] = nil return end
		SetupDrag(anchor, 'boss')
		ShowHint(anchor, 'boss')
		UnitFrames._previewFrames['boss'] = anchor
		UnitFrames.ShowBossCastbarPreview()
	else
		local frame = GetFrame(unitType)
		if not frame then active[unitType] = nil return end
		ShowUnit(frame, unitType)
		SetupDrag(frame, unitType)
		ShowHint(frame, unitType)
		UnitFrames._previewFrames[unitType] = frame
	end

	local button = UnitFrames._previewButtons[unitType]
	if button and button.SetText then button:SetText('Hide Preview') end
	print('|cff6D00FDBluUI:|r ' .. unitType .. ' preview shown, right-click hides it.')
end

local pendingHides = {}
local pendingHideAll = false
local regenWatcher

local function QueueAfterCombat(unitType)
	if unitType then pendingHides[unitType] = true else pendingHideAll = true end
	if not regenWatcher then
		regenWatcher = CreateFrame('Frame')
		regenWatcher:SetScript('OnEvent', function(self)
			self:UnregisterAllEvents()
			local doAll = pendingHideAll
			pendingHideAll = false
			if doAll then UnitFrames.HideAll() end
			for unitType in pairs(pendingHides) do
				pendingHides[unitType] = nil
				UnitFrames.HidePreview(unitType)
			end
		end)
	end
	regenWatcher:RegisterEvent('PLAYER_REGEN_ENABLED')
end

local function ReleaseTestFrame(key)
	local frame = testFrames[key]
	animEntries[key] = nil
	testFrames[key] = nil
	if not frame then return end
	frame._testCastActive = nil
	frame._testCastValue = nil
	frame._testCastIcon = nil
	local castbar = frame.Castbar
	if castbar then
		castbar.holdTime = 0
		castbar._suppressAutoPreview = true
		castbar:Hide()
		castbar._suppressAutoPreview = nil
		local container = castbar._container or castbar:GetParent()
		if container and container ~= frame then container:Hide() end
	end
	if frame.RaidTargetIndicator then frame.RaidTargetIndicator:Hide() end
end

local function ReleaseTestEntries(unitType)
	if not testActive then return end
	if unitType == 'boss' then
		for bossIndex = 1, 5 do ReleaseTestFrame('boss' .. bossIndex) end
	else
		ReleaseTestFrame(unitType)
	end
end

function UnitFrames.HidePreview(unitType)
	if not active[unitType] then return end
	if InCombatLockdown() then
		QueueAfterCombat(unitType)
		return
	end
	active[unitType] = nil
	ReleaseTestEntries(unitType)

	if unitType == 'boss' then
		TeardownDrag(UnitFrames['boss1'])
		HideHint('boss')
		UnitFrames.HideBossCastbarPreview()
		for bossIndex = 1, 5 do
			local bossFrame = GetFrame('boss', bossIndex)
			if bossFrame then HideUnit(bossFrame, 'boss', bossIndex) end
		end
	else
		HideHint(unitType)
		local frame = GetFrame(unitType)
		if frame then HideUnit(frame, unitType) end
	end

	UnitFrames._previewFrames[unitType] = nil
	UnitFrames:Refresh()
	local button = UnitFrames._previewButtons[unitType]
	if button and button.SetText then button:SetText('Show Preview') end
end

function UnitFrames.LockPreview(unitType)
	UnitFrames.HidePreview(unitType)
	print('|cff6D00FDBluUI:|r ' .. unitType:sub(1, 1):upper() .. unitType:sub(2) .. ' preview hidden.')
end

function UnitFrames.TogglePreview(unitType)
	if active[unitType] then UnitFrames.HidePreview(unitType) else UnitFrames.ShowPreview(unitType) end
end

function UnitFrames.IsPreviewShown(unitType)
	return active[unitType] == true
end

function UnitFrames.UpdatePreviews()
	for unitType in pairs(active) do
		if unitType == 'boss' then
			for bossIndex = 1, 5 do
				local bossFrame = GetFrame('boss', bossIndex)
				if bossFrame then
					SetFakeData(bossFrame, 'boss', bossIndex)
					ShowFakeAuras(bossFrame, 'boss', bossIndex)
					Pixel.SetBorderColor(bossFrame, GetAccent())
				end
			end
			if bossCastbarPreviewActive then UnitFrames.ShowBossCastbarPreview() end
		else
			local frame = GetFrame(unitType)
			if frame then
				SetFakeData(frame, unitType, frame._previewIndex or 1)
				ShowFakeAuras(frame, unitType, frame._previewIndex)
				Pixel.SetBorderColor(frame, GetAccent())
			end
		end
	end
end

function UnitFrames.LockAllPreviews()
	local list = {}
	for unitType in pairs(active) do list[#list + 1] = unitType end
	for _, unitType in ipairs(list) do UnitFrames.HidePreview(unitType) end
end

function UnitFrames.UpdatePreviewAurasOnly(frame, unitType, index)
	if active[unitType] then ShowFakeAuras(frame, unitType, index) end
end

local RAID_MARKER_COORDS = {
	{0, 0.25, 0, 0.25}, {0.25, 0.5, 0, 0.25}, {0.5, 0.75, 0, 0.25}, {0.75, 1, 0, 0.25},
	{0, 0.25, 0.25, 0.5}, {0.25, 0.5, 0.25, 0.5}, {0.5, 0.75, 0.25, 0.5}, {0.75, 1, 0.25, 0.5},
}
local function TestData(index)
	local healthPercent = 0.95 - (index * 0.08)
	if healthPercent < 0.15 then healthPercent = 0.15 + (index * 0.05) end
	return {
		name = Pick(NAMES, index),
		class = Pick(CLASS_TOKENS, index),
		hp = healthPercent,
		pp = 1 - (index * 0.07),
		marker = index <= 8 and index or nil,
	}
end

local function ApplyTestVisuals(frame, data, showCast)
	if frame.Health then
		frame.Health:SetMinMaxValues(0, 100)
		frame.Health:SetValue(data.hp * 100)
		local classColor = RAID_CLASS_COLORS[data.class]
		if classColor then
			frame.Health:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
		end
	end
	if frame.Power and frame.Power:IsShown() then
		frame.Power:SetMinMaxValues(0, 100)
		frame.Power:SetValue(max(0, data.pp * 100))
	end
	if frame.Name then
		frame.Name:SetText(data.name)
		local classColor = RAID_CLASS_COLORS[data.class]
		if classColor then frame.Name:SetTextColor(classColor.r, classColor.g, classColor.b) end
	end
	if frame.HealthText then frame.HealthText:SetText(floor(data.hp * 100) .. '%') end
	SetFakeCustomTags(frame, floor(data.hp * 100), floor(data.pp * 100))
	if frame.RaidTargetIndicator and data.marker then
		frame.RaidTargetIndicator:SetTexture(BUI.C.RAID_ICON_TEXTURE)
		frame.RaidTargetIndicator:SetTexCoord(unpack(RAID_MARKER_COORDS[data.marker]))
		frame.RaidTargetIndicator:Show()
	elseif frame.RaidTargetIndicator then
		frame.RaidTargetIndicator:Hide()
	end
	if showCast then
		frame._testCastActive = true
		frame._testCastValue = 0
		frame._testCastIcon = CAST_ICONS[((data.marker or 1) % #CAST_ICONS) + 1]
	end
end

local function ShowEmbeddedCastbar(frame)
	if not frame or not frame._testCastActive then return end
	local castbar = frame.Castbar
	if not castbar then return end

	local barType = castbar._barType
	local castbarSettings = barType and BUI.CastBar.GetSettings(barType)
	local showIcon = castbarSettings and castbarSettings.showIcon

	castbar.holdTime = 1e9
	castbar:SetMinMaxValues(0, 100)
	castbar:SetValue(0)
	castbar:Show()
	if castbar.Text then castbar.Text:SetText('Test Cast') castbar.Text:Show() end
	if castbar.Icon then
		castbar.Icon:SetTexture(frame._testCastIcon or 136243)
		castbar.Icon:SetShown(showIcon ~= false)
	end
	if castbar._iconFrame then castbar._iconFrame:SetShown(showIcon ~= false) end
	if castbar.Time then castbar.Time:SetText('0.0') castbar.Time:Show() end
	local container = castbar._container or castbar:GetParent()
	if container and container ~= frame then container:Show() end
end

local function OnAnimUpdate(_, elapsed)
	for _, entry in pairs(animEntries) do
		local frame = entry.frame
		entry.ht = (entry.ht or 0) + elapsed
		if entry.ht > (entry.hn or 0.5) then
			entry.ht = 0
			entry.hn = 0.4 + random() * 0.8
			entry.hp = max(0.15, min(0.95, entry.hp + (random() < 0.7 and -(0.05 + random() * 0.15) or (0.03 + random() * 0.07))))
			if frame.Health then frame.Health:SetValue(entry.hp * 100) end
			if frame.HealthText then frame.HealthText:SetText(floor(entry.hp * 100) .. '%') end
		end
		entry.pt = (entry.pt or 0) + elapsed
		if entry.pt > (entry.pn or 0.6) then
			entry.pt = 0
			entry.pn = 0.3 + random() * 0.5
			entry.pp = max(0.05, min(0.95, entry.pp + (random() < 0.5 and -(0.1 + random() * 0.2) or (0.05 + random() * 0.15))))
			if frame.Power and frame.Power:IsShown() then frame.Power:SetValue(entry.pp * 100) end
		end
		if frame._testCastActive then
			frame._testCastValue = (frame._testCastValue or 0) + elapsed * 25
			if frame._testCastValue > 100 then frame._testCastValue = 0 end
			local castbar = frame.Castbar
			if castbar and castbar:IsShown() then
				castbar:SetValue(frame._testCastValue)
				if castbar.Time then castbar.Time:SetFormattedText('%.1f', frame._testCastValue / 25) end
			end
		end
	end
end

function UnitFrames.ShowAll()
	if InCombatLockdown() then print('|cff6D00FDBluUI:|r Cannot show test mode during combat.') return end
	if testActive then return end
	testActive = true
	wipe(animEntries)
	wipe(testFrames)
	UnitFrames.InvalidateSettingsCache()

	local index = 0
	for _, unitType in ipairs(ALL_UNITS) do
		local unitSettings = UnitFrames.GetUnitSettings(unitType == 'boss' and 'boss' or unitType)
		if not active[unitType] and unitSettings.enabled ~= false then
			if unitType == 'boss' then
				local found = false
				for bossIndex = 1, 5 do
					local bossFrame = GetFrame('boss', bossIndex)
					if bossFrame then
						found = true
						index = index + 1
						local data = TestData(index)
						ShowUnit(bossFrame, 'boss', bossIndex)
						ApplyTestVisuals(bossFrame, data, true)
						ShowEmbeddedCastbar(bossFrame)
						testFrames['boss' .. bossIndex] = bossFrame
						animEntries['boss' .. bossIndex] = { frame = bossFrame, hp = data.hp, pp = data.pp }
					end
				end
				if found then active[unitType] = true end
			else
				local frame = GetFrame(unitType)
				if frame then
					index = index + 1
					local data = TestData(index)
					local showCast = unitType == 'player' or unitType == 'target' or unitType == 'focus'
					if unitType ~= 'player' then UnregisterUnitWatch(frame) savedWatch[unitType] = true end
					Freeze(frame)
					frame:Show()
					ApplyTestVisuals(frame, data, showCast)
					if showCast then ShowEmbeddedCastbar(frame) end
					testFrames[unitType] = frame
					animEntries[unitType] = { frame = frame, hp = data.hp, pp = data.pp }
					active[unitType] = true
				end
			end
		end
	end

	for bossIndex = 1, 5 do
		local bossFrame = UnitFrames['boss' .. bossIndex]
		if bossFrame and bossFrame.Castbar then
			BUI.CastBar.ApplyBossCastbar(bossFrame, bossIndex)
		end
	end

	for _, unitType in ipairs({ 'player', 'target', 'focus' }) do
		local frame = testFrames[unitType]
		if frame and frame.Castbar then
			BUI.CastBar.ApplyCastbar(frame, unitType)
		end
	end

	if not animFrame then animFrame = CreateFrame('Frame') end
	animFrame:SetScript('OnUpdate', OnAnimUpdate)
	print('|cff6D00FDBluUI:|r Test mode |cff00ff00enabled|r. Type |cffFD008B/buitest|r to disable.')
end

function UnitFrames.HideAll()
	if not testActive then return end
	if InCombatLockdown() then
		QueueAfterCombat()
		return
	end
	testActive = false

	if animFrame then animFrame:SetScript('OnUpdate', nil) end
	wipe(animEntries)

	for key, frame in pairs(testFrames) do
		frame._testCastActive = nil
		frame._testCastValue = nil
		frame._testCastIcon = nil
		local castbar = frame.Castbar
		if castbar then
			castbar.holdTime = 0
			castbar._suppressAutoPreview = true
			castbar:Hide()
			castbar._suppressAutoPreview = nil
			local container = castbar._container or castbar:GetParent()
			if container and container ~= frame then container:Hide() end
		end
		if frame.RaidTargetIndicator then frame.RaidTargetIndicator:Hide() end
		HideFakeAuras(frame, key)
		Thaw(frame)
		if savedWatch[key] then
			RegisterUnitWatch(frame)
			savedWatch[key] = nil
		end
	end

	for key in pairs(testFrames) do
		local unitType = key:match('^boss') and 'boss' or key
		active[unitType] = nil
		UnitFrames._previewFrames[unitType] = nil
	end
	wipe(testFrames)
	UnitFrames:Refresh()

	print('|cff6D00FDBluUI:|r Test mode |cffff6600disabled|r.')
end

function UnitFrames.ToggleShowAll()
	if testActive then UnitFrames.HideAll() else UnitFrames.ShowAll() end
end

function UnitFrames.IsShowAllActive()
	return testActive
end

UnitFrames.TestMode = { Toggle = UnitFrames.ToggleShowAll, IsActive = UnitFrames.IsShowAllActive }

