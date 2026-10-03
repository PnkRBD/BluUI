local _, BUI = ...

local Hook = BUI.Profiler.Hooker('Minimap.Minimap')
local Wrap = BUI.Profiler.Wrap

local Minimap = {}
BUI.Minimap = Minimap

local Pixel = BUI.Pixel
local Events = BUI.Events
local WoWMinimap = _G.Minimap
local SQUARE_MASK = BUI.C.FALLBACK_TEXTURE
local DEFAULT_GOLD = { 1, 0.82, 0 }

local zoneColors = {
	sanctuary = { 0.41, 0.80, 0.94 },
	friendly  = { 0.10, 1.00, 0.10 },
	hostile   = { 1.00, 0.10, 0.10 },
	contested = { 1.00, 0.70, 0.00 },
}

local difficultyPrefix = {
	[1] = 'N', [2] = 'H', [3] = 'N', [4] = 'N',
	[5] = 'H', [6] = 'H', [7] = 'LFR', [8] = 'M+',
	[9] = 'N', [14] = 'N', [15] = 'H', [16] = 'M',
	[17] = 'LFR', [23] = 'M', [24] = 'TW', [33] = 'TW',
	[151] = 'TW', [152] = 'N', [205] = 'N', [208] = 'D',
}

local prefixColors = {
	N      = { 0.12, 1.00, 0.00 },
	H      = { 0.78, 0.13, 1.00 },
	LFR    = { 0.12, 1.00, 0.00 },
	M      = { 1.00, 0.50, 0.00 },
	['M+'] = { 1.00, 0.50, 0.00 },
	TW     = { 0.00, 0.80, 0.80 },
}

local zoneEvents = { 'ZONE_CHANGED', 'ZONE_CHANGED_INDOORS', 'ZONE_CHANGED_NEW_AREA' }
local difficultyEvents = {
	'PLAYER_ENTERING_WORLD', 'UPDATE_INSTANCE_INFO',
	'PLAYER_DIFFICULTY_CHANGED', 'INSTANCE_GROUP_SIZE_CHANGED',
	'CHALLENGE_MODE_START', 'CHALLENGE_MODE_COMPLETED',
}

local defaultIconScale = { queue = 0.8, difficulty = 0.9, mail = 0.8, crafting = 0.8, missions = 0.8 }
local FOLIO_BASE = 32
local PREVIEW_DIFFICULTY = 'M+10'

local hiddenParent = CreateFrame('Frame')
hiddenParent:Hide()
local indicatorHolder = CreateFrame('Frame', nil, WoWMinimap, 'ResizeLayoutFrame')
indicatorHolder:SetPoint('CENTER')
indicatorHolder:SetSize(1, 1)

local backdropFrame, clockFrame, zoneFrame, difficultyFrame, unlockOverlay
local clockTicker, alignmentTimer
local clockUse24h, clockUseServerTime = false, false
local lockReleaseCallback, indicatorMovedCallback
local ghosts, previewing = {}, {}

local function GetConfig()
	return BUI.GetDB().interface
end

local function GetTextFont(key)
	return BUI.GetFontByName(GetConfig()[key])
end

local function IsEnabled()
	return GetConfig().minimapEnabled ~= false
end

local function RegisterEvents(key, events, handler)
	for eventIndex = 1, #events do
		Events:Register(events[eventIndex], key, handler)
	end
end

local function PositionText(frame, fontString, squareCorner, squareX, squareY, offsetX, offsetY)
	frame:ClearAllPoints()
	fontString:ClearAllPoints()
	local side = squareCorner:find('LEFT') and 'LEFT' or 'RIGHT'
	frame:SetPoint(squareCorner, WoWMinimap, squareCorner, Pixel.Scale(squareX + offsetX), Pixel.Scale(squareY + offsetY))
	fontString:SetPoint(side)
	fontString:SetJustifyH(side)
end

local function Park(element, keepParent)
	if not element then return end
	element:Hide()
	element:SetAlpha(0)
	if not keepParent then element:SetParent(hiddenParent) end
end

local function SuppressBlizzardChrome()
	local cluster = _G.MinimapCluster
	Park(_G.MinimapBackdrop)
	Park(_G.MinimapZoneText)
	Park(_G.GameTimeFrame)
	Park(_G.TimeManagerClockButton)
	Park(_G.AddonCompartmentFrame)
	Park(cluster.BorderTop)
	Park(cluster.ZoneTextButton)
	Park(cluster.Tracking)
	Park(WoWMinimap.ZoomHitArea)
	cluster:EnableMouse(false)

	for _, zoom in ipairs({ WoWMinimap.ZoomIn, WoWMinimap.ZoomOut }) do
		Park(zoom, true)
		zoom:EnableMouse(false)
	end

	cluster.IndicatorFrame.MailFrame:SetParent(indicatorHolder)
	cluster.IndicatorFrame.CraftingOrderFrame:SetParent(indicatorHolder)

	local keep = { [WoWMinimap] = true, [cluster.InstanceDifficulty] = true, [_G.ExpansionLandingPageMinimapButton] = true }
	for _, parent in ipairs({ cluster, cluster.MinimapContainer }) do
		for _, child in pairs({ parent:GetChildren() }) do
			if not keep[child] then Park(child, true) end
		end
	end
end

local function CreateBackdrop()
	if backdropFrame then return end

	backdropFrame = CreateFrame('Frame', 'BUI_MinimapBackdrop', UIParent)
	backdropFrame:SetFrameStrata('BACKGROUND')
	backdropFrame:SetFrameLevel(0)

	local texture = backdropFrame:CreateTexture(nil, 'BACKGROUND')
	texture:SetAllPoints()
	BUI.Tools.SetColorTex(texture, 0, 0, 0, 1)
end

local backdropAnnounced

local function UpdateBackdrop()
	if not backdropFrame then return end

	local borderWidth = GetConfig().minimapBorderWidth
	if borderWidth <= 0 then
		backdropFrame:Hide()
	else
		local padding = Pixel.Scale(borderWidth)
		backdropFrame:ClearAllPoints()
		backdropFrame:SetPoint('TOPLEFT',     WoWMinimap, 'TOPLEFT',     -padding,  padding)
		backdropFrame:SetPoint('BOTTOMRIGHT', WoWMinimap, 'BOTTOMRIGHT',  padding, -padding)
		backdropFrame:Show()
	end

	local shown = backdropFrame:IsShown()
	if shown ~= backdropAnnounced then
		backdropAnnounced = shown
		BUI.Datatext.AnchorMinimapBar()
	end
end

local function ApplyShape()
	WoWMinimap:SetMaskTexture(SQUARE_MASK)
	_G.MinimapCompassTexture:Hide()
	WoWMinimap:SetArchBlobRingScalar(0)
	WoWMinimap:SetArchBlobRingAlpha(0)
	WoWMinimap:SetQuestBlobRingScalar(0)
	WoWMinimap:SetQuestBlobRingAlpha(0)

	_G.GetMinimapShape = function() return 'SQUARE' end

	local hybrid = _G.HybridMinimap
	if hybrid and hybrid.MapCanvas and hybrid.CircleMask then
		hybrid.MapCanvas:SetUseMaskTexture(false)
		hybrid.CircleMask:SetTexture(SQUARE_MASK)
		hybrid.MapCanvas:SetUseMaskTexture(true)
	end

	local LDBIcon = LibStub('LibDBIcon-1.0')
	for _, name in ipairs(LDBIcon:GetButtonList()) do LDBIcon:Refresh(name) end
end

local function ReparentMinimap()
	WoWMinimap:SetFrameStrata('LOW')
	WoWMinimap:SetFrameLevel(2)
	WoWMinimap:SetFixedFrameStrata(true)
	WoWMinimap:SetFixedFrameLevel(true)
	WoWMinimap:SetParent(UIParent)
end

local function FormatTime(hour, minute)
	if clockUse24h then
		return string.format('%02d:%02d', hour, minute)
	end
	local suffix = hour >= 12 and 'pm' or 'am'
	hour = hour % 12
	if hour == 0 then hour = 12 end
	return string.format('%d:%02d%s', hour, minute, suffix)
end

local function UpdateClock()
	if not clockFrame or not clockFrame:IsShown() then return end
	local hour, minute
	if clockUseServerTime then
		hour, minute = GetGameTime()
	else
		hour, minute = tonumber(date('%H')), tonumber(date('%M'))
	end
	local text = FormatTime(hour, minute)
	clockFrame.text:SetText((text:gsub('%d', '8')))
	clockFrame:SetWidth(clockFrame.text:GetStringWidth() + 4)
	clockFrame.text:SetText(text)
end

local ClockTick = Wrap('Minimap.Minimap clock tick', UpdateClock)

local function StopClock()
	if clockTicker then
		clockTicker:Cancel()
		clockTicker = nil
	end
	if alignmentTimer then
		alignmentTimer:Cancel()
		alignmentTimer = nil
	end
end

local function BeginMinuteAlignedTicker()
	alignmentTimer = nil
	if not clockFrame or not clockFrame:IsShown() then return end
	UpdateClock()
	clockTicker = C_Timer.NewTicker(60, ClockTick)
end

local function StartClock()
	StopClock()
	UpdateClock()
	local secondsToNextMinute = 60 - tonumber(date('%S'))
	if secondsToNextMinute <= 0 then secondsToNextMinute = 60 end
	alignmentTimer = BUI.Profiler.NewTimer('Minimap.Minimap clock align', secondsToNextMinute, BeginMinuteAlignedTicker)
end

local function CreateClock()
	if clockFrame then return end
	clockFrame = CreateFrame('Frame', 'BUI_MinimapClock', WoWMinimap)
	clockFrame:SetSize(Pixel.Scale(60), Pixel.Scale(16))
	clockFrame:SetFrameLevel(WoWMinimap:GetFrameLevel() + 10)
	clockFrame.text = clockFrame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(clockFrame.text, 12, GetTextFont('minimapClockFont'))
	clockFrame:Hide()
end

function Minimap.RefreshClock()
	if not clockFrame or not clockFrame:IsShown() then return end
	local config = GetConfig()
	Pixel.ApplyFont(clockFrame.text, config.minimapClockSize, GetTextFont('minimapClockFont'))
	local color = config.minimapClockColor
	clockFrame.text:SetTextColor(color.r, color.g, color.b)
	PositionText(clockFrame, clockFrame.text, 'TOPRIGHT', -5, -5, config.minimapClockX, config.minimapClockY)
	clockFrame.text:ClearAllPoints()
	clockFrame.text:SetPoint('LEFT', clockFrame, 'LEFT', Pixel.Scale(2), 0)
	clockFrame.text:SetJustifyH('LEFT')
	UpdateClock()
end

function Minimap.ToggleClock(enabled)
	if not IsEnabled() then
		if clockFrame then clockFrame:Hide() end
		StopClock()
		return
	end
	if not enabled and not clockFrame then return end
	if not clockFrame then CreateClock() end
	clockFrame:SetShown(enabled)
	if enabled then
		Minimap.RefreshClock()
		StartClock()
	else
		StopClock()
	end
end

function Minimap.SetClockFormat(use24h)
	clockUse24h = use24h
	if clockFrame then UpdateClock() end
end

function Minimap.SetClockSource(useServer)
	clockUseServerTime = useServer
	if clockFrame then UpdateClock() end
end

local function UpdateZoneText()
	if not zoneFrame or not zoneFrame:IsShown() then return end
	zoneFrame.text:SetText(GetMinimapZoneText())
	local config = GetConfig()
	if config.minimapZoneColorCustom then
		local customColor = config.minimapZoneColor
		zoneFrame.text:SetTextColor(customColor.r, customColor.g, customColor.b)
	else
		local color = zoneColors[C_PvP.GetZonePVPInfo()] or DEFAULT_GOLD
		zoneFrame.text:SetTextColor(color[1], color[2], color[3])
	end
	zoneFrame:SetWidth(zoneFrame.text:GetStringWidth() + 4)
end

local function CreateZoneText()
	if zoneFrame then return end
	zoneFrame = CreateFrame('Frame', 'BUI_MinimapZone', WoWMinimap)
	zoneFrame:SetSize(Pixel.Scale(100), Pixel.Scale(16))
	zoneFrame:SetFrameLevel(WoWMinimap:GetFrameLevel() + 10)
	zoneFrame.text = zoneFrame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(zoneFrame.text, 11, GetTextFont('minimapZoneFont'))
	zoneFrame.text:SetJustifyH('CENTER')
	zoneFrame:Hide()
end

function Minimap.RefreshZoneText()
	if not zoneFrame or not zoneFrame:IsShown() then return end
	local config = GetConfig()
	Pixel.ApplyFont(zoneFrame.text, config.minimapZoneSize, GetTextFont('minimapZoneFont'))
	PositionText(zoneFrame, zoneFrame.text, 'TOPLEFT', 5, -5, config.minimapZoneX, config.minimapZoneY)
	UpdateZoneText()
end

function Minimap.ToggleZoneText(enabled)
	if not IsEnabled() then
		if zoneFrame then zoneFrame:Hide() end
		return
	end
	if not enabled and not zoneFrame then return end
	if not zoneFrame then CreateZoneText() end
	zoneFrame:SetShown(enabled)
	if enabled then
		Minimap.RefreshZoneText()
		RegisterEvents('MinimapZone', zoneEvents, UpdateZoneText)
	else
		Events:UnregisterAll('MinimapZone')
	end
end

local function GetDifficultyPrefix(difficultyID)
	if not difficultyID or difficultyID == 0 then return nil end
	local prefix = difficultyPrefix[difficultyID]
	if prefix then return prefix end
	local _, _, isHeroic, isChallengeMode = GetDifficultyInfo(difficultyID)
	if isChallengeMode then return 'M+' end
	if isHeroic then return 'H' end
	return 'N'
end

local function CreateDifficultyText()
	if difficultyFrame then return end
	difficultyFrame = CreateFrame('Frame', 'BUI_MinimapDifficulty', WoWMinimap)
	difficultyFrame:SetSize(Pixel.Scale(60), Pixel.Scale(16))
	difficultyFrame:SetFrameLevel(WoWMinimap:GetFrameLevel() + 10)
	difficultyFrame.text = difficultyFrame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(difficultyFrame.text, 12, BUI.GetGlobalFont())
	difficultyFrame:Hide()
end

local function LettersActive()
	local config = GetConfig()
	return config.minimapTextDifficulty and not config.minimapHideDifficulty
end

local function DifficultyLabel()
	local _, instanceType, difficultyID, _, maxPlayers = GetInstanceInfo()
	if not instanceType or instanceType == 'none' or instanceType == '' then return nil end
	local prefix = GetDifficultyPrefix(difficultyID)
	if not prefix then return nil end
	if difficultyID == 8 then
		local level = C_ChallengeMode.GetActiveKeystoneInfo()
		return (level and level > 0) and string.format('%s%d', prefix, level) or prefix, prefix
	end
	if maxPlayers and maxPlayers > 5 then return string.format('%s%d', prefix, maxPlayers), prefix end
	return prefix, prefix
end

local function UpdateDifficultyText()
	if not difficultyFrame then return end
	local label, prefix = DifficultyLabel()
	if previewing.difficulty then label, prefix = PREVIEW_DIFFICULTY, 'M+' end
	if not label then
		difficultyFrame:Hide()
		return
	end

	local color = prefixColors[prefix] or DEFAULT_GOLD
	difficultyFrame.text:SetText(label)
	difficultyFrame.text:SetTextColor(color[1], color[2], color[3])
	difficultyFrame:SetWidth(difficultyFrame.text:GetStringWidth() + 4)
	difficultyFrame:Show()
end

local function GetBlizzardDifficultyFrame()
	return _G.MinimapCluster.InstanceDifficulty
end

local function GetMailFrame()
	return _G.MinimapCluster.IndicatorFrame.MailFrame
end

local function GetCraftingOrderFrame()
	return _G.MinimapCluster.IndicatorFrame.CraftingOrderFrame
end

function Minimap.ToggleTextDifficulty(enabled)
	if not IsEnabled() then
		if difficultyFrame then difficultyFrame:Hide() end
		return
	end
	if not enabled and not difficultyFrame then return end
	if not difficultyFrame then CreateDifficultyText() end
	difficultyFrame:SetShown(enabled)

	if enabled then
		RegisterEvents('MinimapDiff', difficultyEvents, UpdateDifficultyText)
		UpdateDifficultyText()
	else
		Events:UnregisterAll('MinimapDiff')
	end
end

local function GetIndicatorPosition(key)
	local positions = GetConfig().minimapIconPos
	local shapePositions = positions.square
	local position = shapePositions and shapePositions[key]
	if not position then return nil end
	if type(position) ~= 'table' or type(position[1]) ~= 'string' or type(position[2]) ~= 'number' or type(position[3]) ~= 'number' then
		shapePositions[key] = nil
		return nil
	end
	return position
end

local function SaveIndicatorPosition(key, point, x, y)
	local positions = GetConfig().minimapIconPos
	positions.square = positions.square or {}
	positions.square[key] = { point, x, y }
end

local function GetIconScale(key)
	return GetConfig().minimapIconScale[key] or defaultIconScale[key]
end

local function GetDock()
	return GetConfig().minimapIconDock
end

local function GetDockSize()
	return GetConfig().minimapIconSize
end

local function SizeQueueEye(frame, target)
	local eye = frame.Eye
	local frameWidth = frame:GetWidth()
	local eyeWidth = eye:GetWidth()
	if eyeWidth > frameWidth then frameWidth = eyeWidth end
	if frameWidth <= 1 then return end
	eye:SetScale(target / (frameWidth * frame:GetScale()))
end

local function SaveDraggedPosition(frame, key)
	local frameCenterX, frameCenterY = frame:GetCenter()
	local minimapCenterX, minimapCenterY = WoWMinimap:GetCenter()
	if not frameCenterX or not minimapCenterX then return end

	local relativeScale = frame:GetEffectiveScale() / WoWMinimap:GetEffectiveScale()
	local relativeX = (frameCenterX * relativeScale) - minimapCenterX
	local relativeY = (frameCenterY * relativeScale) - minimapCenterY
	local halfWidth, halfHeight = WoWMinimap:GetWidth() / 2, WoWMinimap:GetHeight() / 2
	if relativeX < -halfWidth then relativeX = -halfWidth elseif relativeX > halfWidth then relativeX = halfWidth end
	if relativeY < -halfHeight then relativeY = -halfHeight elseif relativeY > halfHeight then relativeY = halfHeight end
	local offsetX, offsetY = relativeX / relativeScale, relativeY / relativeScale

	SaveIndicatorPosition(key, 'CENTER', offsetX, offsetY)
	if indicatorMovedCallback then indicatorMovedCallback() end
	return offsetX, offsetY
end

local function MakeDraggable(frame, key)
	if frame._buiDragKey then return end
	frame._buiDragKey = key
	frame:SetMovable(true)
	frame:RegisterForDrag('LeftButton')

	frame:HookScript('OnDragStart', BUI.Profiler.Wrap('Minimap.Minimap frame OnDragStart', function(self)
		if not IsControlKeyDown() then return end
		self:StartMoving()
		self._buiDragging = true
	end))

	frame:HookScript('OnDragStop', BUI.Profiler.Wrap('Minimap.Minimap frame OnDragStop', function(self)
		if not self._buiDragging then return end
		self:StopMovingOrSizing()
		self._buiDragging = false
		local offsetX, offsetY = SaveDraggedPosition(self, self._buiDragKey)
		if not offsetX then return end
		self:ClearAllPoints()
		self:SetPoint('CENTER', WoWMinimap, 'CENTER', offsetX, offsetY)
	end))
end

local function ApplyIndicatorPosition(frame, parent, point, x, y)
	if frame:GetParent() == parent and frame:GetNumPoints() == 1 then
		local currentPoint, currentRelative, currentRelativePoint, currentX, currentY = frame:GetPoint(1)
		if currentPoint == point and currentRelative == WoWMinimap and currentRelativePoint == point and currentX == x and currentY == y then
			return
		end
	end
	if frame:GetParent() ~= parent then frame:SetParent(parent) end
	frame:ClearAllPoints()
	frame:SetPoint(point, WoWMinimap, point, x, y)
end

local indicators = {
	{
		key = 'queue',
		hide = 'minimapHideQueue',
		Resolve = function() return _G.QueueStatusButton end,
		dockable = true,
		squareDefault = { 'BOTTOMLEFT',   5,   5 },
		raiseFrameLevel = true,
		atlas = 'groupfinder-eye-single',
		color = { 0.35, 0.72, 1.00 },
	},
	{
		key = 'difficulty',
		hide = 'minimapHideDifficulty',
		Resolve = GetBlizzardDifficultyFrame,
		squareDefault = { 'BOTTOMRIGHT', -5,   5 },
		icon = 'Interface\\Icons\\INV_Misc_Bone_Skull_02',
		color = { 1.00, 0.55, 0.15 },
	},
	{
		key = 'mail',
		hide = 'minimapHideMail',
		Resolve = GetMailFrame,
		dockable = true,
		holder = true,
		squareDefault = { 'TOPLEFT',  5, -30 },
		icon = 'Interface\\Icons\\INV_Letter_15',
		color = { 1.00, 0.88, 0.25 },
	},
	{
		key = 'crafting',
		hide = 'minimapHideCrafting',
		Resolve = GetCraftingOrderFrame,
		dockable = true,
		holder = true,
		squareDefault = { 'TOPLEFT', 28, -30 },
		raiseFrameLevel = true,
		icon = 'Interface\\Icons\\Trade_BlackSmithing',
		color = { 0.45, 0.82, 0.30 },
	},
	{
		key = 'missions',
		hide = 'minimapHideGarrison',
		Resolve = function() return _G.ExpansionLandingPageMinimapButton end,
		dockable = true,
		squareDefault = { 'TOPRIGHT', -5, -30 },
		raiseFrameLevel = true,
		icon = 'Interface\\Icons\\INV_Misc_Book_09',
		color = { 0.65, 0.40, 0.95 },
	},
}

local function IndicatorHidden(indicator)
	local interfaceDB = GetConfig()
	if interfaceDB[indicator.hide] then return true end
	return indicator.key == 'difficulty' and interfaceDB.minimapTextDifficulty
end

local function IndicatorParent(indicator)
	if IndicatorHidden(indicator) then return hiddenParent end
	return indicator.holder and indicatorHolder or WoWMinimap
end

local function FindIndicator(key)
	for indicatorIndex = 1, #indicators do
		if indicators[indicatorIndex].key == key then return indicators[indicatorIndex] end
	end
end

local function IndicatorPlacement(indicator)
	local saved = GetIndicatorPosition(indicator.key)
	if saved then return saved[1], saved[2], saved[3] end
	local default = indicator.squareDefault
	return default[1], default[2], default[3]
end

function Minimap.ApplyIndicatorArt(texture, key)
	local indicator = FindIndicator(key)
	local atlas = indicator.atlas or key == 'missions' and _G.ExpansionLandingPageMinimapButton:GetNormalTexture():GetAtlas()
	if atlas then
		texture:SetAtlas(atlas)
		texture:SetTexCoord(0, 1, 0, 1)
	else
		texture:SetTexture(indicator.icon)
		texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
end

function Minimap.GetIndicatorColor(key)
	return FindIndicator(key).color
end

local function GhostFootprint(indicator)
	if indicator.key == 'missions' then return FOLIO_BASE, FOLIO_BASE end
	local frame = indicator.Resolve()
	local width, height = frame._buiNativeW, frame._buiNativeH
	if width <= 1 or height <= 1 then
		local size = GetDockSize()
		return size, size
	end
	return width, height
end

local function CopyArt(ghost, source, layer, sublevel)
	local texture = ghost:CreateTexture(nil, layer, nil, sublevel)
	texture:SetAtlas(source:GetAtlas(), true)
	return texture
end

local GHOST_ART = {
	queue = function(ghost)
		ghost.eye = CopyArt(ghost, _G.QueueStatusButton.Eye.texture, 'ARTWORK')
		ghost.eye:SetPoint('CENTER')
	end,
	mail = function(ghost)
		CopyArt(ghost, GetMailFrame().MailIcon, 'ARTWORK'):SetPoint('CENTER')
	end,
	crafting = function(ghost)
		CopyArt(ghost, _G.MiniMapCraftingOrderIcon, 'ARTWORK'):SetPoint('CENTER')
	end,
	difficulty = function(ghost)
		local banner = GetBlizzardDifficultyFrame().Default
		CopyArt(ghost, banner.Background, 'BACKGROUND'):SetPoint('CENTER')
		CopyArt(ghost, banner.Border, 'ARTWORK'):SetPoint('CENTER')
		CopyArt(ghost, banner.MythicTexture, 'ARTWORK', 1):SetPoint('TOP', -0.5, -4)
	end,
	missions = function(ghost)
		CopyArt(ghost, _G.ExpansionLandingPageMinimapButton:GetNormalTexture(), 'ARTWORK'):SetAllPoints()
	end,
}

local function OnGhostDragStop(ghost)
	ghost:StopMovingOrSizing()
	SaveDraggedPosition(ghost, ghost._buiKey)
	Minimap.RepositionIndicators()
end

local function CreateGhost(indicator)
	local ghost = CreateFrame('Frame', nil, WoWMinimap)
	ghost._buiKey = indicator.key
	ghost:SetFrameLevel(WoWMinimap:GetFrameLevel() + 20)
	ghost:SetMovable(true)
	ghost:EnableMouse(true)
	ghost:RegisterForDrag('LeftButton')
	GHOST_ART[indicator.key](ghost)
	ghost:SetScript('OnDragStart', BUI.Profiler.Script('Minimap.Minimap preview OnDragStart', function(self) self:StartMoving() end))
	ghost:SetScript('OnDragStop', BUI.Profiler.Script('Minimap.Minimap preview OnDragStop', OnGhostDragStop))
	ghost:Hide()
	return ghost
end

local function PlaceGhost(indicator, point, x, y)
	local ghost = ghosts[indicator.key]
	if not ghost then return end
	local shown = previewing[indicator.key] and not (indicator.key == 'difficulty' and LettersActive())
	ghost:SetShown(shown == true)
	if not shown then return end
	local width, height = GhostFootprint(indicator)
	ghost:SetScale(GetIconScale(indicator.key))
	ghost:SetSize(width, height)
	ghost:ClearAllPoints()
	ghost:SetPoint(point, WoWMinimap, point, x, y)
	if ghost.eye then
		local eye = indicator.Resolve().Eye
		local size = eye:GetWidth() * eye:GetScale()
		ghost.eye:SetSize(size, size)
	end
end

local function PlaceDifficultyText(frame, point, x, y)
	local align = GetConfig().minimapTextDifficultyAlign
	local iconScale = GetIconScale('difficulty')
	local width, height = frame._buiNativeW * iconScale, frame._buiNativeH * iconScale
	local left = point:find('LEFT') and x or point:find('RIGHT') and (x - width) or (x - width / 2)
	local bottom = point:find('BOTTOM') and y or point:find('TOP') and (y - height) or (y - height / 2)
	local edge = align == 'LEFT' and left or align == 'RIGHT' and (left + width) or (left + width / 2)
	difficultyFrame:ClearAllPoints()
	difficultyFrame:SetPoint(align, WoWMinimap, point, edge, bottom + height / 2)
	difficultyFrame.text:ClearAllPoints()
	difficultyFrame.text:SetPoint(align)
	difficultyFrame.text:SetJustifyH(align)
end

local function PositionIndicator(indicator)
	local frame = indicator.Resolve()
	local point, x, y = IndicatorPlacement(indicator)
	ApplyIndicatorPosition(frame, IndicatorParent(indicator), point, x, y)
	frame:SetSize(frame._buiNativeW, frame._buiNativeH)
	local iconScale = GetIconScale(indicator.key)
	if frame:GetScale() ~= iconScale then frame:SetScale(iconScale) end
	if indicator.key == 'queue' then SizeQueueEye(frame, GetDockSize() * iconScale) end
	if indicator.raiseFrameLevel then
		frame:SetFrameLevel(WoWMinimap:GetFrameLevel() + 5)
	end
	MakeDraggable(frame, indicator.key)
	PlaceGhost(indicator, point, x, y)

	if indicator.key == 'difficulty' and difficultyFrame then
		PlaceDifficultyText(frame, point, x * iconScale, y * iconScale)
	end
end

local repositionLock = {}

local function HookSetPoint(frame, key, repositionCallback)
	local function Reassert(self)
		if not repositionLock[key] and IsEnabled() and not self._buiDragging then
			repositionLock[key] = true
			repositionCallback()
			repositionLock[key] = false
		end
	end
	Hook(frame, 'SetPoint', Reassert)
	Hook(frame, 'SetScale', Reassert)
end

local landingTamed = false
local function TameLandingButton()
	if landingTamed then return end
	landingTamed = true
	local button = _G.ExpansionLandingPageMinimapButton

	local clamping = false
	local function Clamp()
		if clamping then return end
		clamping = true
		button:SetSize(FOLIO_BASE, FOLIO_BASE)
		clamping = false
	end
	Clamp()
	Hook(button, 'SetSize', Clamp)

	local function Repin()
		Minimap.RepositionIndicators()
	end
	Hook(button, 'UpdateIconForGarrison', Repin)
	Hook(button, 'SetLandingPageIconOffset', Repin)
end

local relayouting = false
local DOCK_ANCHORS = {
	TOPLEFT     = { point = 'TOPLEFT',     x =  6, y = -6, dirX =  1 },
	TOPRIGHT    = { point = 'TOPRIGHT',    x = -6, y = -6, dirX = -1 },
	BOTTOMLEFT  = { point = 'BOTTOMLEFT',  x =  6, y =  6, dirX =  1 },
	BOTTOMRIGHT = { point = 'BOTTOMRIGHT', x = -6, y =  6, dirX = -1 },
}
Minimap.DOCK_ANCHORS = DOCK_ANCHORS

local function LayoutDocked(anchor)
	local size = GetDockSize()
	local step = size + 4
	local dockedCount = 0
	for _, indicator in ipairs(indicators) do
		local frame = indicator.Resolve()
		local hidden = IndicatorHidden(indicator)
		if indicator.dockable and frame:IsShown() and not hidden then
			local parent = IndicatorParent(indicator)
			if frame:GetParent() ~= parent then frame:SetParent(parent) end
			frame:ClearAllPoints()
			local offset = anchor.dirX * dockedCount * step
			if indicator.key == 'missions' then
				local missionScale = size / FOLIO_BASE * GetIconScale(indicator.key)
				frame:SetScale(missionScale)
				frame:SetSize(FOLIO_BASE, FOLIO_BASE)
				frame:SetPoint(anchor.point, WoWMinimap, anchor.point, (anchor.x + offset) / missionScale, anchor.y / missionScale)
			elseif indicator.key == 'queue' then
				local iconScale = GetIconScale(indicator.key)
				frame:SetScale(1)
				frame:SetSize(size * iconScale, size * iconScale)
				frame:SetPoint(anchor.point, WoWMinimap, anchor.point, anchor.x + offset, anchor.y)
				SizeQueueEye(frame, size * iconScale)
			else
				local iconScale = GetIconScale(indicator.key)
				local baseWidth = frame._buiNativeW
				if baseWidth <= 1 then baseWidth = size end
				local iconFit = size * iconScale / baseWidth
				frame:SetScale(iconFit)
				frame:SetPoint(anchor.point, WoWMinimap, anchor.point, (anchor.x + offset) / iconFit, anchor.y / iconFit)
			end
			if indicator.raiseFrameLevel then frame:SetFrameLevel(WoWMinimap:GetFrameLevel() + 5) end
			dockedCount = dockedCount + 1
		elseif hidden or not indicator.dockable then
			PositionIndicator(indicator)
		end
	end
end

local function PositionAllIndicators()
	if not IsEnabled() or relayouting then return end
	relayouting = true

	for indicatorIndex = 1, #indicators do
		local indicator = indicators[indicatorIndex]
		if not indicator.hooked then
			indicator.hooked = true
			local frame = indicator.Resolve()
			frame._buiNativeW, frame._buiNativeH = frame:GetSize()
			HookSetPoint(frame, indicator.key, function()
				if DOCK_ANCHORS[GetDock()] then PositionAllIndicators() else PositionIndicator(indicator) end
			end)
			if indicator.dockable then
				local RelayoutDock = Wrap('Minimap.Minimap relayout dock', function()
					if not relayouting and DOCK_ANCHORS[GetDock()] then PositionAllIndicators() end
				end)
				frame:HookScript('OnShow', RelayoutDock)
				frame:HookScript('OnHide', RelayoutDock)
			end
		end
	end

	local anchor = DOCK_ANCHORS[GetDock()]
	if anchor then
		LayoutDocked(anchor)
	else
		for indicatorIndex = 1, #indicators do
			PositionIndicator(indicators[indicatorIndex])
		end
	end
	TameLandingButton()

	relayouting = false
end

local function OnMouseWheel(_, delta)
	if delta > 0 then
		WoWMinimap.ZoomIn:Click()
	else
		WoWMinimap.ZoomOut:Click()
	end
end

local function EnableScrollZoom()
	WoWMinimap:EnableMouseWheel(true)
	WoWMinimap:SetScript('OnMouseWheel', BUI.Profiler.Script('Minimap.Minimap WoWMinimap OnMouseWheel', OnMouseWheel))
end

local DEFAULT_SCREEN_OFFSET = -20

function Minimap.ApplyPosition()
	if not IsEnabled() then return end
	local interfaceDB = GetConfig()
	local scale = interfaceDB.minimapScale / 100
	local x = interfaceDB.minimapScreenX or DEFAULT_SCREEN_OFFSET
	local y = interfaceDB.minimapScreenY or DEFAULT_SCREEN_OFFSET

	Pixel.SetScale(WoWMinimap, scale)
	WoWMinimap:ClearAllPoints()
	BUI.Anchor.PlaceOnPixels(WoWMinimap, 'TOPRIGHT', UIParent, 'TOPRIGHT', x, y)
	UpdateBackdrop()
end

function Minimap.SetScale(percent)
	GetConfig().minimapScale = percent
	Minimap.ApplyPosition()
end

function Minimap.GetSizePixels()
	return BUI.Round(WoWMinimap:GetWidth() / Pixel.PixelSizeFor(WoWMinimap, 1))
end

function Minimap.SetSizePixels(pixels)
	Minimap.SetScale(pixels * Pixel.PixelSizeFor(WoWMinimap:GetParent(), 1) / WoWMinimap:GetWidth() * 100)
end

function Minimap.SetPositionX(x)
	GetConfig().minimapScreenX = x
	Minimap.ApplyPosition()
end

function Minimap.SetPositionY(y)
	GetConfig().minimapScreenY = y
	Minimap.ApplyPosition()
end

function Minimap.GetPosition()
	local interfaceDB = GetConfig()
	return interfaceDB.minimapScreenX or DEFAULT_SCREEN_OFFSET, interfaceDB.minimapScreenY or DEFAULT_SCREEN_OFFSET
end

function Minimap.SetBorderWidth(width)
	GetConfig().minimapBorderWidth = width
	if IsEnabled() then UpdateBackdrop() end
end

Pixel.OnScaleChange('Minimap', function()
	if IsEnabled() then UpdateBackdrop() end
end)

function Minimap.ToggleRotation(enabled)
	C_CVar.SetCVar('rotateMinimap', enabled and '1' or '0')
end

local function ReplayMailNotification(element)
	if element:IsShown() then element:TryPlayMailNotification() end
end

function Minimap.ApplyVisibility()
	local mail = GetMailFrame()
	local mailWasHidden = mail:GetParent() == hiddenParent
	PositionAllIndicators()
	if mailWasHidden and mail:GetParent() ~= hiddenParent then ReplayMailNotification(mail) end
end

function Minimap.IsUnlocked()
	return unlockOverlay and unlockOverlay:IsShown()
end

function Minimap.SetLockReleaseCallback(callback)
	lockReleaseCallback = callback
end

local function CreateUnlockOverlay()
	unlockOverlay = CreateFrame('Frame', 'BUI_MinimapUnlock', WoWMinimap, 'BackdropTemplate')
	unlockOverlay:SetAllPoints()
	unlockOverlay:SetFrameStrata('TOOLTIP')
	unlockOverlay:SetFrameLevel(500)
	Pixel.SetTemplate(unlockOverlay, 0.1, 0.6, 0.1, 0.3, 0.1, 0.8, 0.1, 1)
	unlockOverlay:EnableMouse(true)
	unlockOverlay:RegisterForDrag('LeftButton')

	unlockOverlay.text = unlockOverlay:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(unlockOverlay.text, 11, BUI.GetGlobalFont())
	unlockOverlay.text:SetPoint('CENTER')
	unlockOverlay.text:SetText('Drag to Reposition\nRight-Click to Lock')
	unlockOverlay.text:SetJustifyH('CENTER')

	local startX, startY, startCursorX, startCursorY = 0, 0, 0, 0

	unlockOverlay:SetScript('OnDragStart', BUI.Profiler.Script('Minimap.Minimap unlockOverlay OnDragStart', function(self)
		startX, startY = Minimap.GetPosition()
		startCursorX, startCursorY = GetCursorPosition()
		self.dragging = true
	end))

	unlockOverlay:SetScript('OnUpdate', Wrap('Minimap.Minimap unlock drag', function(self)
		if not self.dragging then return end
		local cursorX, cursorY = GetCursorPosition()
		local uiScale = UIParent:GetEffectiveScale()
		local deltaX = (cursorX - startCursorX) / uiScale
		local deltaY = (cursorY - startCursorY) / uiScale

		local minimapScale = GetConfig().minimapScale / 100
		local minimapSize = WoWMinimap:GetWidth() * minimapScale
		local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()

		local newX = math.min(0, math.max(-(screenWidth - minimapSize - 5), startX + deltaX))
		local newY = math.min(0, math.max(-(screenHeight - minimapSize - 5), startY + deltaY))

		WoWMinimap:ClearAllPoints()
		WoWMinimap:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', newX, newY)
		UpdateBackdrop()
	end))

	unlockOverlay:SetScript('OnDragStop', BUI.Profiler.Script('Minimap.Minimap unlockOverlay OnDragStop', function(self)
		self.dragging = false
		local _, _, _, x, y = WoWMinimap:GetPoint()
		local interfaceDB = GetConfig()
		interfaceDB.minimapScreenX = x
		interfaceDB.minimapScreenY = y
		Minimap.ApplyPosition()
	end))

	unlockOverlay:SetScript('OnMouseUp', BUI.Profiler.Script('Minimap.Minimap unlockOverlay OnMouseUp', function(_, button)
		if button == 'RightButton' then
			Minimap.ToggleUnlock(false)
			if lockReleaseCallback then lockReleaseCallback() end
		end
	end))
end

function Minimap.ToggleUnlock(unlock)
	if unlock then
		if not unlockOverlay then CreateUnlockOverlay() end
		WoWMinimap:SetMovable(true)
		unlockOverlay:Show()
	else
		if unlockOverlay then
			unlockOverlay:Hide()
			unlockOverlay.dragging = false
		end
		WoWMinimap:SetMovable(false)
	end
end

function Minimap.SetAddonButtons(mode)
	GetConfig().addonButtons = mode
	if IsEnabled() then BUI.AddonButtons.SetMode(mode) end
end

function Minimap.Enable()
	local interfaceDB = GetConfig()
	interfaceDB.minimapEnabled = true

	ReparentMinimap()
	SuppressBlizzardChrome()
	CreateBackdrop()
	ApplyShape()
	EnableScrollZoom()

	BUI.MinimapMenu.Setup()

	Minimap.ApplyPosition()
	Minimap.ToggleRotation(interfaceDB.rotateMinimap)
	Minimap.SetClockFormat(interfaceDB.minimapClock24h)
	Minimap.SetClockSource(interfaceDB.minimapClockServer)

	Minimap.ToggleClock(interfaceDB.minimapClock)
	Minimap.ToggleZoneText(interfaceDB.minimapZone)
	BUI.AddonButtons.SetMode(interfaceDB.addonButtons)
	Minimap.ToggleTextDifficulty(LettersActive())

	PositionAllIndicators()
	ReplayMailNotification(GetMailFrame())
end

function Minimap.ApplySettings()
	local config = GetConfig()
	if clockFrame      then Pixel.ApplyFont(clockFrame.text,      config.minimapClockSize, GetTextFont('minimapClockFont')) end
	if zoneFrame       then Pixel.ApplyFont(zoneFrame.text,       config.minimapZoneSize,  GetTextFont('minimapZoneFont')) end
	if difficultyFrame then Pixel.ApplyFont(difficultyFrame.text, 12, BUI.GetGlobalFont()) end
end

Minimap.RepositionIndicators = PositionAllIndicators
Minimap.GetIconScale = GetIconScale

function Minimap.SetIconScale(key, scale)
	local point, x, y = IndicatorPlacement(FindIndicator(key))
	local ratio = GetIconScale(key) / scale
	SaveIndicatorPosition(key, point, x * ratio, y * ratio)
	GetConfig().minimapIconScale[key] = scale
	if IsEnabled() then PositionAllIndicators() end
end

function Minimap.GetIndicatorOffset(key)
	local point, x, y = IndicatorPlacement(FindIndicator(key))
	local iconScale = GetIconScale(key)
	return point, x * iconScale, y * iconScale
end

function Minimap.SetIndicatorOffset(key, point, x, y)
	local iconScale = GetIconScale(key)
	SaveIndicatorPosition(key, point, x / iconScale, y / iconScale)
	if IsEnabled() then PositionAllIndicators() end
end

function Minimap.PreviewIndicator(key, enabled)
	previewing[key] = enabled or nil
	if enabled and not ghosts[key] then ghosts[key] = CreateGhost(FindIndicator(key)) end
	if not enabled and ghosts[key] then ghosts[key]:Hide() end
	if key == 'difficulty' and LettersActive() then UpdateDifficultyText() end
	if IsEnabled() then PositionAllIndicators() end
end

function Minimap.IsIndicatorPreviewing(key)
	return previewing[key] == true
end

function Minimap.ClearIndicatorPreviews()
	for key in pairs(previewing) do Minimap.PreviewIndicator(key, false) end
end

function Minimap.SetIndicatorMovedCallback(callback)
	indicatorMovedCallback = callback
end

Minimap.GetDock = GetDock

Minimap.GetIconSize = GetDockSize

local initialized = false

function Minimap.Initialize()
	if not initialized then
		initialized = true

		local lastWidth, lastHeight = 0, 0
		WoWMinimap:HookScript('OnSizeChanged', Wrap('Minimap.Minimap size changed', function(_, width, height)
			if not IsEnabled() then return end
			width, height = math.floor(width + 0.5), math.floor(height + 0.5)
			if width == lastWidth and height == lastHeight then return end
			lastWidth, lastHeight = width, height
			UpdateBackdrop()
		end))

		Events:Register('PLAYER_ENTERING_WORLD', 'MinimapDeferred', function()
			if IsEnabled() then
				PositionAllIndicators()
				UpdateBackdrop()
			end
		end)

		Events:Register('EDIT_MODE_LAYOUTS_UPDATED', 'MinimapEditMode', function()
			if IsEnabled() then
				PositionAllIndicators()
			end
		end)

		EditModeManagerFrame:HookScript('OnHide', Wrap('Minimap.Minimap edit mode closed', function()
			if IsEnabled() then
				PositionAllIndicators()
			end
		end))

		Events:Register('DISPLAY_SIZE_CHANGED', 'MinimapResolution', function()
			if IsEnabled() then Minimap.ApplyPosition() end
		end)

		local farmHud = _G.FarmHud
		if farmHud then
			farmHud:HookScript('OnShow', Wrap('Minimap.Minimap farm hud shown', function()
				if not IsEnabled() then return end
				if backdropFrame then backdropFrame:Hide() end
				WoWMinimap:SetMaskTexture('Textures\\MinimapMask')
			end))
			farmHud:HookScript('OnHide', Wrap('Minimap.Minimap farm hud hidden', function()
				if not IsEnabled() then return end
				UpdateBackdrop()
				ApplyShape()
			end))
		end

		if _G.HybridMinimap then
			if IsEnabled() then ApplyShape() end
		else
			Events:Register('ADDON_LOADED', 'MinimapHybrid', function(_, addon)
				if addon ~= 'Blizzard_HybridMinimap' then return end
				if IsEnabled() then ApplyShape() end
				Events:Unregister('ADDON_LOADED', 'MinimapHybrid')
			end)
		end
	end

	if GetConfig().minimapEnabled == false then return end
	Minimap.Enable()
end

Events:OnLogin('Minimap', Minimap.Initialize, 'minimap')
