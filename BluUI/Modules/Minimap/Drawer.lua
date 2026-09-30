local _, BUI = ...

local Drawer = {}
BUI.Drawer = Drawer

local Pixel = BUI.Pixel
local WoWMinimap = _G.Minimap

local BUTTON_SIZE = 26
local BUTTON_PAD = 6
local MARGIN = 10
local MAX_COLS = 5
local TAB_W = 10
local TAB_H = 44
local TAB_INSET = 3
local HIDE_DELAY = 0.3
local ICON_SIZE = 22
local ICON_CROP = 0.08
local ICON_BORDER_BOX = 24
local BORDER_TEXTURE_FILEID = 136430
local BACKGROUND_TEXTURE_FILEID = 136467

local TAB_COLOR_NORMAL      = { 0.85,  0.85, 0.85, 1 }
local TAB_COLOR_HOVER       = { 1,     1,    1,    1 }
local TAB_COLOR_ERROR       = { 0.937, 0.267, 0.267, 1 }
local TAB_COLOR_ERROR_HOVER = { 1,     0.4,  0.4,  1 }

local TAB_ANCHORS = {
	LEFT   = { point = 'LEFT',   dirX = 1,  dirY = 0 },
	RIGHT  = { point = 'RIGHT',  dirX = -1, dirY = 0 },
	TOP    = { point = 'TOP',    dirX = 0,  dirY = -1 },
	BOTTOM = { point = 'BOTTOM', dirX = 0,  dirY = 1 },
}

local bar, bgFrame, tab
local buttons = {}
local captured = {}
local hovering = false
local hideTimer
local side = 'LEFT'
local offsetX, offsetY = 0, 0
local enabled = false
local hasSessionError = false
local claims = {}
local captureListeners = {}
local captureWanted = false

local noop = function() end

local ignoreNames = {
	GameTimeFrame                    = true,
	MinimapBackdrop                  = true,
	MiniMapWorldMapButton            = true,
	MinimapZoomIn                    = true,
	MinimapZoomOut                   = true,
	MiniMapTracking                  = true,
	MiniMapMailFrame                 = true,
	MiniMapBattlefieldFrame          = true,
	MinimapZoneTextButton            = true,
	TimeManagerClockButton           = true,
	QueueStatusButton                = true,
	GarrisonLandingPageMinimapButton = true,
	ExpansionLandingPageMinimapButton = true,
	AddonCompartmentFrame            = true,
}

local ignorePatterns = {
	'^GatherMatePin%d+$',
	'^HandyNotes.*Pin$',
}

local function ShouldIgnore(frame)
	local name = frame:GetName()
	if not name then return false end
	if ignoreNames[name] then return true end
	for patternIndex = 1, #ignorePatterns do
		if name:match(ignorePatterns[patternIndex]) then return true end
	end
	return false
end

local function ClassifyTexture(region)
	local path = region:GetTexture()
	if path == BORDER_TEXTURE_FILEID
		or (type(path) == 'string' and path:lower():find('minimap%-trackingborder')) then
		return 'border'
	end
	if path == BACKGROUND_TEXTURE_FILEID
		or (type(path) == 'string' and path:lower():find('ui%-minimap%-background')) then
		return 'background'
	end
	return 'content'
end

local function IsVertical()
	return side == 'TOP' or side == 'BOTTOM'
end

function Drawer.TabLayout(tabSide, x, y, measure)
	local width, height = measure(TAB_W), measure(TAB_H)
	if tabSide == 'TOP' or tabSide == 'BOTTOM' then width, height = height, width end
	local anchor = TAB_ANCHORS[tabSide]
	local inset = measure(TAB_INSET)
	return width, height, anchor.point, anchor.dirX * inset + measure(x), anchor.dirY * inset + measure(y)
end

local function LayoutTab()
	if not tab then return end
	local width, height, point, x, y = Drawer.TabLayout(side, offsetX, offsetY, Pixel.Scale)
	tab:SetSize(width, height)
	tab:ClearAllPoints()
	tab:SetPoint('CENTER', WoWMinimap, point, x, y)
end

local function HasBugSackError()
	if hasSessionError then return true end
	local dataObject = LibStub('LibDataBroker-1.1'):GetDataObjectByName('BugSack')
	if dataObject and tonumber(dataObject.text) and tonumber(dataObject.text) > 0 then
		hasSessionError = true
		return true
	end
	return false
end

local function GetTabColor(isHover)
	if hasSessionError then
		return isHover and TAB_COLOR_ERROR_HOVER or TAB_COLOR_ERROR
	end
	return isHover and TAB_COLOR_HOVER or TAB_COLOR_NORMAL
end

local function ApplyTabColor(isHover)
	local color = GetTabColor(isHover)
	Pixel.SetBackgroundColor(tab, color[1], color[2], color[3], color[4])
end

local function OnErrorCaught()
	hasSessionError = true
	if tab and not hovering then
		ApplyTabColor(false)
	end
end

local function CancelHide()
	if not hideTimer then return end
	hideTimer:Cancel()
	hideTimer = nil
end

local function HideDrawer()
	bar:Hide()
	bgFrame:Hide()
	hovering = false
	ApplyTabColor(false)
	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
		if not claims[button] then button:Hide() end
	end
end

local function ScheduleHide()
	CancelHide()
	hideTimer = C_Timer.NewTimer(HIDE_DELAY, HideDrawer)
end

local function AnchorBarToTab(target)
	target:ClearAllPoints()
	local barAnchor, tabAnchor, offset = 'RIGHT', 'LEFT', -2
	if side == 'RIGHT' then
		barAnchor, tabAnchor, offset = 'LEFT', 'RIGHT', 2
	elseif side == 'TOP' then
		barAnchor, tabAnchor, offset = 'BOTTOM', 'TOP', 2
	elseif side == 'BOTTOM' then
		barAnchor, tabAnchor, offset = 'TOP', 'BOTTOM', -2
	end
	if IsVertical() then
		target:SetPoint(barAnchor, tab, tabAnchor, 0, Pixel.Scale(offset))
	else
		target:SetPoint(barAnchor, tab, tabAnchor, Pixel.Scale(offset), 0)
	end
end

local function UnclaimedButtons()
	local visible = {}
	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
		if not claims[button] then visible[#visible + 1] = button end
	end
	return visible
end

local function ShowDrawer()
	CancelHide()
	if not enabled then return end
	local visible = UnclaimedButtons()
	if #visible == 0 then return end

	local cols = math.min(#visible, MAX_COLS)
	local rows = math.ceil(#visible / MAX_COLS)
	local buttonSize = Pixel.Scale(BUTTON_SIZE)
	local buttonPadding = Pixel.Scale(BUTTON_PAD)
	local margin = Pixel.Scale(MARGIN)
	local barWidth = margin + cols * (buttonSize + buttonPadding) - buttonPadding + margin
	local barHeight = margin + rows * (buttonSize + buttonPadding) - buttonPadding + margin

	bar:SetSize(barWidth, barHeight)
	bgFrame:SetSize(barWidth, barHeight)
	AnchorBarToTab(bar)
	AnchorBarToTab(bgFrame)

	for buttonIndex = 1, #visible do
		local button = visible[buttonIndex]
		local col = (buttonIndex - 1) % MAX_COLS
		local row = math.floor((buttonIndex - 1) / MAX_COLS)
		button._buiOriginalFuncs.ClearAllPoints(button)
		button._buiOriginalFuncs.SetPoint(button, 'TOPLEFT', bar, 'TOPLEFT',
			margin + col * (buttonSize + buttonPadding),
			-(margin + row * (buttonSize + buttonPadding)))
		button:SetFrameStrata('MEDIUM')
		button:SetFrameLevel(120)
		button:Show()
		button:SetAlpha(1)
		button._buiBorder:Show()
	end

	bgFrame:Show()
	bar:Show()
	hovering = true
	ApplyTabColor(true)
end

function Drawer.SetSide(newSide)
	side = newSide
	LayoutTab()
	if bar and bar:IsShown() then HideDrawer() end
end

function Drawer.SetOffset(x, y)
	offsetX, offsetY = x, y
	LayoutTab()
	if bar and bar:IsShown() then HideDrawer() end
end

function Drawer.Create()
	if bar then return end

	bgFrame = CreateFrame('Frame', 'BUI_AddonDrawerBg', UIParent, 'BackdropTemplate')
	bgFrame:SetFrameStrata('MEDIUM')
	bgFrame:SetFrameLevel(100)
	Pixel.SetTemplate(bgFrame, 0.06, 0.06, 0.06, 0.95, 0.12, 0.12, 0.12, 1)
	bgFrame:EnableMouse(true)
	bgFrame:Hide()

	bar = CreateFrame('Frame', 'BUI_AddonDrawerBar', UIParent)
	bar:SetSize(Pixel.Scale(200), Pixel.Scale(34))
	bar:SetFrameStrata('MEDIUM')
	bar:SetFrameLevel(110)
	bar:EnableMouse(true)
	bar:Hide()

	tab = CreateFrame('Button', 'BUI_AddonDrawerTab', UIParent, 'BackdropTemplate')
	tab:SetFrameStrata('MEDIUM')
	tab:SetFrameLevel(111)
	local color = GetTabColor(false)
	Pixel.SetTemplate(tab, color[1], color[2], color[3], color[4], 0.1, 0.1, 0.1, 1)
	LayoutTab()

	tab:SetScript('OnEnter', ShowDrawer)
	tab:SetScript('OnLeave', ScheduleHide)
	bar:SetScript('OnEnter', CancelHide)
	bar:SetScript('OnLeave', ScheduleHide)
	bgFrame:SetScript('OnEnter', CancelHide)
	bgFrame:SetScript('OnLeave', ScheduleHide)

	if _G.BugGrabber then
		HasBugSackError()
		EventRegistry:RegisterCallback('BugGrabber.BugGrabbed', OnErrorCaught, Drawer)
	end

	Pixel.OnScaleChange('Drawer', Drawer.Refresh)
end

local function FindIconTexture(button)
	local icon = button.Icon or button.icon
	if icon and icon.IsObjectType and icon:IsObjectType('Texture') then return icon end

	if button.GetNormalTexture then
		local normal = button:GetNormalTexture()
		if normal and (normal:GetTexture() or normal:GetAtlas()) and ClassifyTexture(normal) == 'content' then
			return normal
		end
	end

	local best, bestArea
	for _, region in pairs({ button:GetRegions() }) do
		if region:IsObjectType('Texture') and ClassifyTexture(region) == 'content' then
			local layer = region:GetDrawLayer()
			if layer == 'BACKGROUND' or layer == 'ARTWORK' then
				local texturePath = region:GetTexture()
				if region:GetDebugName():lower():find('icon', 1, true) or (type(texturePath) == 'string' and texturePath:lower():find('icon', 1, true)) then
					return region
				end
				local width, height = region:GetSize()
				local area = (width or 0) * (height or 0)
				if not bestArea or area > bestArea then best, bestArea = region, area end
			end
		end
	end
	return best
end

local function HasClickHandler(frame)
	if frame:HasScript('OnClick')     and frame:GetScript('OnClick')     then return true end
	if frame:HasScript('OnMouseUp')   and frame:GetScript('OnMouseUp')   then return true end
	if frame:HasScript('OnMouseDown') and frame:GetScript('OnMouseDown') then return true end
	return false
end

local function LooksLikeButton(frame)
	if not frame or frame:IsForbidden() then return false end
	if not frame:IsShown() then return false end
	local width, height = frame:GetSize()
	if width < 16 or height < 16 then return false end
	if width > 60 or height > 60 then return false end
	if math.abs(width - height) > 10 then return false end
	if HasClickHandler(frame) then return true end
	for _, child in pairs({ frame:GetChildren() }) do
		if HasClickHandler(child) then return true end
	end
	return false
end

local function FreezeButton(button)
	if button._buiFrozen then return end
	button._buiFrozen = true
	button._buiOriginalFuncs = {
		SetPoint       = button.SetPoint,
		ClearAllPoints = button.ClearAllPoints,
		SetParent      = button.SetParent,
		SetScale       = button.SetScale,
		SetSize        = button.SetSize,
		SetWidth       = button.SetWidth,
		SetHeight      = button.SetHeight,
	}
	button:SetFixedFrameStrata(false)
	button:SetFixedFrameLevel(false)
	button.SetPoint, button.ClearAllPoints = noop, noop
	button.SetParent, button.SetScale = noop, noop
	button.SetSize, button.SetWidth, button.SetHeight = noop, noop, noop
end

local function UnfreezeButton(button)
	if not button._buiFrozen then return end
	button._buiFrozen = nil
	for name, originalFunc in pairs(button._buiOriginalFuncs) do
		button[name] = originalFunc
	end
	button._buiOriginalFuncs = nil
end

local function StyleDrawerButton(button)
	local buttonSize = Pixel.Scale(BUTTON_SIZE)
	local iconSize = Pixel.Scale(ICON_SIZE)
	button._buiOriginalFuncs.SetParent(button, bar)
	button._buiOriginalFuncs.SetScale(button, 1)
	button._buiOriginalFuncs.SetSize(button, buttonSize, buttonSize)
	local iconTexture = button._buiIcon
	if iconTexture then
		iconTexture:ClearAllPoints()
		iconTexture:SetPoint('CENTER')
		iconTexture:SetSize(iconSize, iconSize)
		iconTexture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
		iconTexture:Show()
	end
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if highlight then
		highlight:ClearAllPoints()
		highlight:SetPoint('CENTER')
		highlight:SetSize(iconSize, iconSize)
	end
	local border = button._buiBorder
	border:ClearAllPoints()
	border:SetPoint('CENTER')
	border:SetSize(Pixel.Scale(ICON_BORDER_BOX), Pixel.Scale(ICON_BORDER_BOX))
	Pixel.ApplyBorder(border, 1, 0, 0, 0, 1)
end

local function CaptureButton(button)
	if captured[button] or ShouldIgnore(button) then return end
	captured[button] = true

	local points = {}
	for pointIndex = 1, button:GetNumPoints() do
		points[pointIndex] = { button:GetPoint(pointIndex) }
	end
	button._buiOriginalState = {
		parent = button:GetParent(),
		points = points,
		strata = button:GetFrameStrata(),
		level  = button:GetFrameLevel(),
		scale  = button:GetScale(),
		alpha  = button:GetAlpha(),
		width  = button:GetWidth(),
		height = button:GetHeight(),
	}

	FreezeButton(button)

	local iconTexture = FindIconTexture(button)
	for _, region in pairs({ button:GetRegions() }) do
		if region:IsObjectType('Texture') and region ~= iconTexture and ClassifyTexture(region) ~= 'content' then
			region:Hide()
		end
	end
	if iconTexture and not button._buiIcon then
		button._buiIcon = iconTexture
		button._buiIconCoord = { iconTexture:GetTexCoord() }
		button._buiIconW, button._buiIconH = iconTexture:GetSize()
		button._buiIconPoints = {}
		for pointIndex = 1, iconTexture:GetNumPoints() do button._buiIconPoints[pointIndex] = { iconTexture:GetPoint(pointIndex) } end
	end
	button._buiBorder = button._buiBorder or CreateFrame('Frame', nil, button, 'BackdropTemplate')
	StyleDrawerButton(button)

	button:Hide()
	buttons[#buttons + 1] = button

	if not button._buiHooked then
		button:HookScript('OnEnter', CancelHide)
		button:HookScript('OnLeave', ScheduleHide)
		button._buiHooked = true
	end
	for _, listener in pairs(captureListeners) do listener(button) end
end

local function ReleaseButton(button)
	if not captured[button] then return end
	captured[button] = nil
	claims[button] = nil

	UnfreezeButton(button)

	local original = button._buiOriginalState
	button:SetParent(original.parent)
	button:ClearAllPoints()
	for _, point in ipairs(original.points) do
		button:SetPoint(unpack(point))
	end
	button:SetFrameStrata(original.strata)
	button:SetFrameLevel(original.level)
	button:SetScale(original.scale)
	button:SetAlpha(original.alpha)
	button:SetSize(original.width, original.height)

	for _, region in pairs({ button:GetRegions() }) do
		if region:IsObjectType('Texture') and not region._buiBarBg then
			region:Show()
		end
	end
	local iconTexture = button._buiIcon
	if iconTexture then
		iconTexture:SetTexCoord(unpack(button._buiIconCoord))
		iconTexture:SetSize(button._buiIconW, button._buiIconH)
		iconTexture:ClearAllPoints()
		for _, point in ipairs(button._buiIconPoints) do iconTexture:SetPoint(unpack(point)) end
		button._buiIcon, button._buiIconCoord, button._buiIconW, button._buiIconH, button._buiIconPoints = nil, nil, nil, nil, nil
	end
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if highlight then
		highlight:ClearAllPoints()
		highlight:SetAllPoints(button)
	end
	button._buiBorder:Hide()
	button:Show()
	button._buiOriginalState = nil

	for buttonIndex = #buttons, 1, -1 do
		if buttons[buttonIndex] == button then
			table.remove(buttons, buttonIndex)
			break
		end
	end
end

local function ReleaseAll()
	for buttonIndex = #buttons, 1, -1 do
		ReleaseButton(buttons[buttonIndex])
	end
	wipe(buttons)
	wipe(captured)
	wipe(claims)
end

local function ScanChildren(parent)
	if not parent then return end
	for _, child in pairs({ parent:GetChildren() }) do
		if not captured[child] and LooksLikeButton(child) then
			CaptureButton(child)
		end
	end
end

local function ScanLibDBIcon()
	local LDBIcon = LibStub('LibDBIcon-1.0')
	for _, name in ipairs(LDBIcon:GetButtonList()) do
		local button = LDBIcon:GetMinimapButton(name)
		if button and not captured[button] then
			CaptureButton(button)
		end
	end
end

local function OnLibDBIconCreated(_, button)
	if not enabled and not captureWanted then return end
	if not captured[button] then CaptureButton(button) end
end

function Drawer.CaptureButtons()
	ReleaseAll()
	ScanLibDBIcon()
	ScanChildren(WoWMinimap)
	ScanChildren(_G.MinimapBackdrop)

	LibStub('LibDBIcon-1.0').RegisterCallback(Drawer, 'LibDBIcon_IconCreated', OnLibDBIconCreated)
end

function Drawer.Enable()
	enabled = true
	Drawer.Create()
	tab:Show()
	Drawer.CaptureButtons()
end

function Drawer.Disable()
	enabled = false
	LibStub('LibDBIcon-1.0').UnregisterCallback(Drawer, 'LibDBIcon_IconCreated')
	if tab     then tab:Hide()     end
	if bar     then bar:Hide()     end
	if bgFrame then bgFrame:Hide() end
	if not captureWanted then ReleaseAll() end
end

function Drawer.Refresh()
	if not enabled or not tab then return end

	Pixel.SetTemplate(bgFrame, 0.06, 0.06, 0.06, 0.95, 0.12, 0.12, 0.12, 1)
	local color = GetTabColor(hovering)
	Pixel.SetTemplate(tab, color[1], color[2], color[3], color[4], 0.1, 0.1, 0.1, 1)
	LayoutTab()

	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
		if not claims[button] then StyleDrawerButton(button) end
	end

	if bar:IsShown() then ShowDrawer() end
end

function Drawer.GetButtons() return buttons end

function Drawer.IsCaptured(button) return captured[button] == true end

function Drawer.Claim(button, owner)
	if not captured[button] then return end
	claims[button] = owner
end

function Drawer.ReturnButton(button)
	if not captured[button] then return end
	claims[button] = nil
	StyleDrawerButton(button)
	if bar and bar:IsShown() then ShowDrawer() else button:Hide() end
end

function Drawer.OnCapture(key, listener)
	captureListeners[key] = listener
end

function Drawer.SetCaptureWanted(wanted)
	wanted = wanted and true or false
	if captureWanted == wanted then return end
	captureWanted = wanted
	if enabled then return end
	if wanted then
		Drawer.Create()
		tab:Hide()
		Drawer.CaptureButtons()
	else
		ReleaseAll()
	end
end
