local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Minimap.Minimap')

local hooksecurefunc = BUI.Prof.MakeHooker('minimap')
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

local defaultIconScale = { queue = 0.8, difficulty = 0.9, mail = 0.8, crafting = 0.8 }

local hiddenParent = CreateFrame('Frame')
hiddenParent:Hide()
local indicatorHolder = CreateFrame('Frame', nil, WoWMinimap, 'ResizeLayoutFrame')
indicatorHolder:SetPoint('CENTER')
indicatorHolder:SetSize(1, 1)

local backdropFrame, clockFrame, zoneFrame, difficultyFrame, unlockOverlay
local clockTicker, alignmentTimer
local clockUse24h, clockUseServerTime = false, false
local lockReleaseCallback

local function GetConfig()
	return BUI.GetDB().interface
end

local fontProbe = {}
local function GetTextFont(key)
	fontProbe.font = GetConfig()[key]
	return BUI.GetModuleFont(fontProbe)
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
	offsetX, offsetY = offsetX or 0, offsetY or 0
	frame:ClearAllPoints()
	fontString:ClearAllPoints()
	local side = squareCorner:find('LEFT') and 'LEFT' or 'RIGHT'
	frame:SetPoint(squareCorner, WoWMinimap, squareCorner, Pixel.Scale(squareX + offsetX), Pixel.Scale(squareY + offsetY))
	fontString:SetPoint(side)
	fontString:SetJustifyH(side)
end

local function Park(element, options)
	if not element then return end
	element:Hide()
	element:SetAlpha(0)
	if options and options.disableMouse and element.EnableMouse then element:EnableMouse(false) end
	if options and options.reparent ~= false then element:SetParent(hiddenParent) end
end

local function SuppressBlizzardChrome()
	local reparentHidden = { reparent = true }
	Park(_G.MinimapBorder,                       reparentHidden)
	Park(_G.MinimapBorderTop,                    reparentHidden)
	Park(_G.MinimapBackdrop,                     reparentHidden)
	Park(_G.MinimapZoneText,                     reparentHidden)
	Park(_G.MinimapZoneTextButton,               reparentHidden)
	Park(_G.GameTimeFrame,                       reparentHidden)
	Park(_G.TimeManagerClockButton,              reparentHidden)
	Park(_G.MiniMapTracking,                     reparentHidden)
	Park(_G.MiniMapTrackingButton,               reparentHidden)
	Park(_G.AddonCompartmentFrame,               reparentHidden)

	local cluster = _G.MinimapCluster
	if cluster then
		Park(cluster.BorderTop,        reparentHidden)
		Park(cluster.BorderBottom,     reparentHidden)
		Park(cluster.BorderLeft,       reparentHidden)
		Park(cluster.BorderRight,      reparentHidden)
		Park(cluster.ZoneTextButton,   reparentHidden)
		Park(cluster.Tracking,         reparentHidden)
		cluster:EnableMouse(false)
	end

	local zoomOpts = { disableMouse = true, reparent = false }
	Park(_G.MinimapZoomIn,         zoomOpts)
	Park(_G.MinimapZoomOut,        zoomOpts)
	Park(WoWMinimap.ZoomIn,        zoomOpts)
	Park(WoWMinimap.ZoomOut,       zoomOpts)
	Park(WoWMinimap.ZoomHitArea,   reparentHidden)

	if cluster then
		local indicatorFrame = cluster.IndicatorFrame
		if indicatorFrame then
			if indicatorFrame.MailFrame then indicatorFrame.MailFrame:SetParent(indicatorHolder) end
			if indicatorFrame.CraftingOrderFrame then indicatorFrame.CraftingOrderFrame:SetParent(indicatorHolder) end
		end
		local difficulty = cluster.InstanceDifficulty
		local landing = _G.ExpansionLandingPageMinimapButton
		local function suppressChildren(parent)
			if not parent then return end
			for _, child in pairs({ parent:GetChildren() }) do
				if child ~= WoWMinimap and child ~= difficulty and child ~= landing then
					Park(child, { reparent = false })
				end
			end
		end
		suppressChildren(cluster)
		suppressChildren(cluster.MinimapContainer)
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
	backdropFrame.tex = texture

	local mask = backdropFrame:CreateMaskTexture()
	mask:SetAllPoints(texture)
	mask:SetTexture(SQUARE_MASK)
	texture:AddMaskTexture(mask)
	backdropFrame.mask = mask
end

local function UpdateBackdrop()
	if not backdropFrame then return end

	local borderWidth = GetConfig().minimapBorderWidth
	if borderWidth <= 0 then
		backdropFrame:Hide()
		return
	end

	local padding = Pixel.Scale(borderWidth)
	backdropFrame:ClearAllPoints()
	backdropFrame:SetPoint('TOPLEFT',     WoWMinimap, 'TOPLEFT',     -padding,  padding)
	backdropFrame:SetPoint('BOTTOMRIGHT', WoWMinimap, 'BOTTOMRIGHT',  padding, -padding)
	backdropFrame:Show()
end

local function ApplyShape()
	WoWMinimap:SetMaskTexture(SQUARE_MASK)
	if _G.MinimapCompassTexture then _G.MinimapCompassTexture:Hide() end
	WoWMinimap:SetArchBlobRingScalar(0)
	WoWMinimap:SetArchBlobRingAlpha(0)
	WoWMinimap:SetQuestBlobRingScalar(0)
	WoWMinimap:SetQuestBlobRingAlpha(0)

	_G.GetMinimapShape = function() return 'SQUARE' end

	if backdropFrame and backdropFrame.mask then
		backdropFrame.mask:SetTexture(SQUARE_MASK)
	end

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
	clockTicker = BUI.Prof.NewTicker('Minimap.Minimap', 60, BUI.Prof.Wrap('tick#MinimapClock', UpdateClock))
end

local function StartClock()
	StopClock()
	UpdateClock()
	local secondsToNextMinute = 60 - tonumber(date('%S'))
	if secondsToNextMinute <= 0 then secondsToNextMinute = 60 end
	alignmentTimer = BUI.Prof.NewTimer('Minimap.Minimap', secondsToNextMinute, BeginMinuteAlignedTicker)
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
	local name = GetMinimapZoneText()
	if not name then return end
	zoneFrame.text:SetText(name)
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
	difficultyFrame:SetPoint('BOTTOMRIGHT', WoWMinimap, 'BOTTOMRIGHT', Pixel.Scale(-5), Pixel.Scale(5))
	difficultyFrame.text = difficultyFrame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(difficultyFrame.text, 12, BUI.GetGlobalFont())
	difficultyFrame.text:SetPoint('RIGHT')
	difficultyFrame.text:SetJustifyH('RIGHT')
	difficultyFrame:Hide()
end

local function UpdateDifficultyText()
	if not difficultyFrame then return end
	local _, instanceType, difficultyID, _, maxPlayers = GetInstanceInfo()
	if not instanceType or instanceType == 'none' or instanceType == '' then
		difficultyFrame:Hide()
		return
	end
	local prefix = GetDifficultyPrefix(difficultyID)
	if not prefix then
		difficultyFrame:Hide()
		return
	end

	local label
	if difficultyID == 8 then
		local level = C_ChallengeMode.GetActiveKeystoneInfo()
		label = (level and level > 0) and string.format('%s%d', prefix, level) or prefix
	elseif maxPlayers and maxPlayers > 5 then
		label = string.format('%s%d', prefix, maxPlayers)
	else
		label = prefix
	end

	local color = prefixColors[prefix] or DEFAULT_GOLD
	difficultyFrame.text:SetText(label)
	difficultyFrame.text:SetTextColor(color[1], color[2], color[3])
	difficultyFrame:SetWidth(difficultyFrame.text:GetStringWidth() + 4)
	difficultyFrame:Show()
end

local function GetBlizzardDifficultyFrame()
	local cluster = _G.MinimapCluster
	return cluster and cluster.InstanceDifficulty
end

local function GetMailFrame()
	local cluster = _G.MinimapCluster
	return cluster and cluster.IndicatorFrame and cluster.IndicatorFrame.MailFrame
end

local function GetCraftingOrderFrame()
	local cluster = _G.MinimapCluster
	return cluster and cluster.IndicatorFrame and cluster.IndicatorFrame.CraftingOrderFrame
end

function Minimap.ToggleTextDifficulty(enabled)
	if not IsEnabled() then
		if difficultyFrame then difficultyFrame:Hide() end
		return
	end
	if not enabled and not difficultyFrame then return end
	if not difficultyFrame then CreateDifficultyText() end
	difficultyFrame:SetShown(enabled)

	local blizzard = GetBlizzardDifficultyFrame()
	if blizzard then
		if enabled then
			blizzard:SetAlpha(0)
			blizzard:Hide()
		elseif not GetConfig().minimapHideDifficulty then
			blizzard:SetAlpha(1)
			blizzard:Show()
		end
	end

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
	if type(point) ~= 'string' or type(x) ~= 'number' or type(y) ~= 'number' then return end
	local interfaceDB = GetConfig()
	interfaceDB.minimapIconPos.square = interfaceDB.minimapIconPos.square or {}
	interfaceDB.minimapIconPos.square[key] = { point, x, y }
end

local function GetIconScale(key)
	local scales = GetConfig().minimapIconScale
	if scales and scales[key] then return scales[key] end
	return defaultIconScale[key] or 0.8
end

local function SaveIconScale(key, scale)
	local interfaceDB = GetConfig()
	interfaceDB.minimapIconScale = interfaceDB.minimapIconScale or {}
	interfaceDB.minimapIconScale[key] = scale
end

local function GetDock()
	return GetConfig().minimapIconDock
end

local function GetDockSize()
	return GetConfig().minimapIconSize
end

local function SizeQueueEye(frame, target)
	local eye = frame.Eye
	if not eye then return end
	local frameWidth = frame:GetWidth()
	local eyeWidth = eye:GetWidth()
	if eyeWidth > frameWidth then frameWidth = eyeWidth end
	if frameWidth <= 1 then return end
	eye:SetScale(target / (frameWidth * frame:GetScale()))
end

local function MakeDraggable(frame, key)
	if not frame or frame._buiDragKey then return end
	frame._buiDragKey = key
	frame:SetMovable(true)
	frame:RegisterForDrag('LeftButton')

	HookScript(frame, 'OnDragStart', function(self)
		if not IsControlKeyDown() then return end
		self:StartMoving()
		self._buiDragging = true
	end)

	HookScript(frame, 'OnDragStop', function(self)
		if not self._buiDragging then return end
		self:StopMovingOrSizing()
		self._buiDragging = false

		local frameCenterX, frameCenterY = self:GetCenter()
		local minimapCenterX, minimapCenterY = WoWMinimap:GetCenter()
		if not frameCenterX or not minimapCenterX then return end

		local relativeScale = self:GetEffectiveScale() / WoWMinimap:GetEffectiveScale()
		local relativeX = (frameCenterX * relativeScale) - minimapCenterX
		local relativeY = (frameCenterY * relativeScale) - minimapCenterY
		local halfWidth, halfHeight = WoWMinimap:GetWidth() / 2, WoWMinimap:GetHeight() / 2
		if relativeX < -halfWidth then relativeX = -halfWidth elseif relativeX > halfWidth then relativeX = halfWidth end
		if relativeY < -halfHeight then relativeY = -halfHeight elseif relativeY > halfHeight then relativeY = halfHeight end
		local offsetX, offsetY = relativeX / relativeScale, relativeY / relativeScale

		SaveIndicatorPosition(self._buiDragKey, 'CENTER', offsetX, offsetY)
		self:ClearAllPoints()
		self:SetPoint('CENTER', WoWMinimap, 'CENTER', offsetX, offsetY)
	end)
end

local function WantedIndicatorParent(frame)
	if frame == GetMailFrame() or frame == GetCraftingOrderFrame() then return indicatorHolder end
	return WoWMinimap
end

local function ApplyIndicatorPosition(frame, key, defaultPoint, defaultX, defaultY)
	local saved = GetIndicatorPosition(key)
	local point, x, y = defaultPoint, defaultX, defaultY
	if saved then point, x, y = saved[1], saved[2], saved[3] end
	local parent = WantedIndicatorParent(frame)
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
		Resolve = function() return _G.QueueStatusButton end,
		dockable = true,
		squareDefault = { 'BOTTOMLEFT',   5,   5 },
		raiseFrameLevel = true,
	},
	{
		key = 'difficulty',
		Resolve = GetBlizzardDifficultyFrame,
		squareDefault = { 'BOTTOMRIGHT', -5,   5 },
	},
	{
		key = 'mail',
		Resolve = GetMailFrame,
		dockable = true,
		squareDefault = { 'TOPLEFT',  5, -30 },
	},
	{
		key = 'crafting',
		Resolve = GetCraftingOrderFrame,
		dockable = true,
		squareDefault = { 'TOPLEFT', 28, -30 },
		raiseFrameLevel = true,
	},
	{
		key = 'missions',
		Resolve = function() return _G.ExpansionLandingPageMinimapButton end,
		dockable = true,
		squareDefault = { 'TOPRIGHT', -5, -30 },
		raiseFrameLevel = true,
	},
}

local function FindIndicator(key)
	for indicatorIndex = 1, #indicators do
		if indicators[indicatorIndex].key == key then return indicators[indicatorIndex] end
	end
end

function Minimap.GetIndicatorDefault(key)
	local indicator = FindIndicator(key)
	if not indicator then return 'CENTER', 0, 0 end
	local coords = indicator.squareDefault
	return coords[1], coords[2], coords[3]
end

local function PositionIndicator(indicator)
	local frame = indicator.Resolve()
	if not frame then return end
	local default = indicator.squareDefault
	ApplyIndicatorPosition(frame, indicator.key, default[1], default[2], default[3])
	if frame._buiNativeW then frame:SetSize(frame._buiNativeW, frame._buiNativeH) end
	local iconScale = GetIconScale(indicator.key)
	if frame:GetScale() ~= iconScale then frame:SetScale(iconScale) end
	if indicator.key == 'queue' then SizeQueueEye(frame, GetDockSize() * GetIconScale(indicator.key)) end
	if indicator.raiseFrameLevel then
		frame:SetFrameLevel(WoWMinimap:GetFrameLevel() + 5)
	end
	MakeDraggable(frame, indicator.key)

	if indicator.key == 'difficulty' and difficultyFrame then
		local saved = GetIndicatorPosition('difficulty')
		local point, x, y = default[1], default[2], default[3]
		if saved then point, x, y = saved[1], saved[2], saved[3] end
		local textScale = GetIconScale('difficulty')
		difficultyFrame:ClearAllPoints()
		difficultyFrame:SetPoint(point, WoWMinimap, point, x * textScale, y * textScale)
	end
end

local repositionLock = {}

local function HookSetPoint(frame, key, repositionCallback)
	if not frame then return end
	local function Reassert(self)
		if not repositionLock[key] and IsEnabled() and not self._buiDragging then
			repositionLock[key] = true
			repositionCallback()
			repositionLock[key] = false
		end
	end
	hooksecurefunc(frame, 'SetPoint', Reassert)
	hooksecurefunc(frame, 'SetScale', Reassert)
end

local FOLIO_BASE = 32
local landingTamed = false
local function TameLandingButton()
	local button = _G.ExpansionLandingPageMinimapButton
	if not button or landingTamed then return end
	landingTamed = true

	local clamping = false
	local function Clamp()
		if clamping then return end
		clamping = true
		button:SetSize(FOLIO_BASE, FOLIO_BASE)
		clamping = false
	end
	Clamp()
	hooksecurefunc(button, 'SetSize', Clamp)

	local function Repin()
		if IsEnabled() then Minimap.RepositionIndicators() end
	end
	if button.UpdateIconForGarrison then hooksecurefunc(button, 'UpdateIconForGarrison', Repin) end
	if button.SetLandingPageIconOffset then hooksecurefunc(button, 'SetLandingPageIconOffset', Repin) end
end

local relayouting = false
local DOCK_ANCHORS = {
	TOPLEFT     = { point = 'TOPLEFT',     x =  6, y = -6, dirX =  1 },
	TOPRIGHT    = { point = 'TOPRIGHT',    x = -6, y = -6, dirX = -1 },
	BOTTOMLEFT  = { point = 'BOTTOMLEFT',  x =  6, y =  6, dirX =  1 },
	BOTTOMRIGHT = { point = 'BOTTOMRIGHT', x = -6, y =  6, dirX = -1 },
}

local function LayoutDocked(anchor)
	local size = GetDockSize()
	local step = size + 4
	local dockedCount = 0
	for _, indicator in ipairs(indicators) do
		local frame = indicator.Resolve()
		if indicator.dockable and frame and frame:IsShown() then
			local parent = WantedIndicatorParent(frame)
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
				local baseWidth = frame._buiNativeW or frame:GetWidth()
				if not baseWidth or baseWidth <= 1 then baseWidth = size end
				local iconFit = size * iconScale / baseWidth
				frame:SetScale(iconFit)
				frame:SetPoint(anchor.point, WoWMinimap, anchor.point, (anchor.x + offset) / iconFit, anchor.y / iconFit)
			end
			if indicator.raiseFrameLevel then frame:SetFrameLevel(WoWMinimap:GetFrameLevel() + 5) end
			dockedCount = dockedCount + 1
		elseif not indicator.dockable and frame then
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
			local frame = indicator.Resolve()
			if frame then
				indicator.hooked = true
				if not frame._buiNativeW then
					frame._buiNativeW, frame._buiNativeH = frame:GetSize()
				end
				HookSetPoint(frame, indicator.key, function()
					if DOCK_ANCHORS[GetDock()] then PositionAllIndicators() else PositionIndicator(indicator) end
				end)
				if indicator.dockable then
					local function RelayoutDock()
						if IsEnabled() and not relayouting and DOCK_ANCHORS[GetDock()] then
							PositionAllIndicators()
						end
					end
					HookScript(frame, 'OnShow', RelayoutDock)
					HookScript(frame, 'OnHide', RelayoutDock)
				end
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
	SetScript(WoWMinimap, 'OnMouseWheel', OnMouseWheel)
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
	WoWMinimap:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', x, y)
	UpdateBackdrop()
end

function Minimap.SetScale(percent)
	GetConfig().minimapScale = percent
	Minimap.ApplyPosition()
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
	if not element or not element.TryPlayMailNotification then return end
	if not element:IsShown() then return end
	element:TryPlayMailNotification()
end

local function SetIndicatorVisible(element, visible)
	if not element then return end
	if visible then
		if element._buiForcedHide then
			element._buiForcedHide = nil
			element:Show()
			ReplayMailNotification(element)
		end
		element:SetAlpha(1)
		if element.EnableMouse then element:EnableMouse(true) end
	else
		element:SetAlpha(0)
		if element.EnableMouse then element:EnableMouse(false) end
		element:Hide()
		element._buiForcedHide = true
	end
end

function Minimap.ApplyVisibility()
	local interfaceDB = GetConfig()
	local blizzard = GetBlizzardDifficultyFrame()
	if blizzard then
		local hidden = interfaceDB.minimapTextDifficulty or interfaceDB.minimapHideDifficulty
		SetIndicatorVisible(blizzard, not hidden)
	end
	SetIndicatorVisible(GetMailFrame(),                       not interfaceDB.minimapHideMail)
	SetIndicatorVisible(GetCraftingOrderFrame(),              not interfaceDB.minimapHideCrafting)
	SetIndicatorVisible(_G.ExpansionLandingPageMinimapButton, not interfaceDB.minimapHideGarrison)
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

	SetScript(unlockOverlay, 'OnDragStart', function(self)
		local interfaceDB = GetConfig()
		startX = interfaceDB.minimapScreenX or -20
		startY = interfaceDB.minimapScreenY or -20
		startCursorX, startCursorY = GetCursorPosition()
		self.dragging = true
	end)

	SetScript(unlockOverlay, 'OnUpdate', function(self)
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
	end)

	SetScript(unlockOverlay, 'OnDragStop', function(self)
		self.dragging = false
		local _, _, _, x, y = WoWMinimap:GetPoint()
		local interfaceDB = GetConfig()
		interfaceDB.minimapScreenX = x
		interfaceDB.minimapScreenY = y
	end)

	SetScript(unlockOverlay, 'OnMouseUp', function(_, button)
		if button == 'RightButton' then
			Minimap.ToggleUnlock(false)
			if lockReleaseCallback then lockReleaseCallback() end
		end
	end)
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

function Minimap.ToggleDrawer(enabled)
	local interfaceDB = GetConfig()
	interfaceDB.drawerEnabled = enabled
	if enabled then
		BUI.Drawer.SetOffset(interfaceDB.drawerX, interfaceDB.drawerY)
		BUI.Drawer.SetSide(interfaceDB.drawerSide)
		BUI.Drawer.Enable()
	else
		BUI.Drawer.Disable()
	end
end

function Minimap.SetDrawerSide(side)
	GetConfig().drawerSide = side
	BUI.Drawer.SetSide(side)
end

function Minimap.RefreshButtonBar()
	BUI.MinimapButtonBar.Refresh()
end

function Minimap.RepositionDrawer()
	local interfaceDB = GetConfig()
	BUI.Drawer.SetOffset(interfaceDB.drawerX, interfaceDB.drawerY)
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

	Minimap.ToggleClock(interfaceDB.minimapClock and true or false)
	Minimap.ToggleZoneText(interfaceDB.minimapZone and true or false)

	if interfaceDB.drawerEnabled then
		BUI.Drawer.SetOffset(interfaceDB.drawerX, interfaceDB.drawerY)
		BUI.Drawer.SetSide(interfaceDB.drawerSide)
		BUI.Drawer.Enable()
	else
		BUI.Drawer.Disable()
	end

	BUI.MinimapButtonBar.Refresh()

	Minimap.ToggleTextDifficulty(interfaceDB.minimapTextDifficulty and true or false)

	PositionAllIndicators()
	Minimap.ApplyVisibility()
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
Minimap.GetIndicatorPosition = GetIndicatorPosition
Minimap.SaveIndicatorPosition = SaveIndicatorPosition

function Minimap.SetIconScale(key, scale)
	SaveIconScale(key, scale)
	if IsEnabled() then PositionAllIndicators() end
end

function Minimap.GetDock() return GetDock() end

function Minimap.GetIconSize() return GetDockSize() end

local initialized = false

function Minimap.Initialize()
	if not initialized then
		initialized = true

		local lastWidth, lastHeight = 0, 0
		HookScript(WoWMinimap, 'OnSizeChanged', function(_, width, height)
			if not IsEnabled() then return end
			width, height = math.floor(width + 0.5), math.floor(height + 0.5)
			if width == lastWidth and height == lastHeight then return end
			lastWidth, lastHeight = width, height
			UpdateBackdrop()
		end)

		Events:Register('PLAYER_ENTERING_WORLD', 'MinimapDeferred', function()
			if IsEnabled() then
				PositionAllIndicators()
				UpdateBackdrop()
				Minimap.ApplyVisibility()
			end
		end)

		Events:Register('EDIT_MODE_LAYOUTS_UPDATED', 'MinimapEditMode', function()
			if IsEnabled() then
				PositionAllIndicators()
				Minimap.ApplyVisibility()
			end
		end)

		if EditModeManagerFrame then
			HookScript(EditModeManagerFrame, 'OnHide', function()
				if IsEnabled() then
					PositionAllIndicators()
					Minimap.ApplyVisibility()
				end
			end)
		end

		Events:Register('DISPLAY_SIZE_CHANGED', 'MinimapResolution', function()
			if IsEnabled() then Minimap.ApplyPosition() end
		end)

		local farmHud = _G.FarmHud
		if farmHud then
			HookScript(farmHud, 'OnShow', function()
				if not IsEnabled() then return end
				if backdropFrame then backdropFrame:Hide() end
				WoWMinimap:SetMaskTexture('Textures\\MinimapMask')
			end)
			HookScript(farmHud, 'OnHide', function()
				if not IsEnabled() then return end
				UpdateBackdrop()
				ApplyShape()
			end)
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

Events:OnLogin('Minimap', Minimap.Initialize)
