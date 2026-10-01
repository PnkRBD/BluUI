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

local PANEL_ANCHORS = {
	LEFT   = { 'RIGHT',  'LEFT',   -2, 0 },
	RIGHT  = { 'LEFT',   'RIGHT',   2, 0 },
	TOP    = { 'BOTTOM', 'TOP',     0, 2 },
	BOTTOM = { 'TOP',    'BOTTOM',  0, -2 },
}

local bar, bgFrame, tab
local shown = {}
local active = false
local hovering = false
local hideTimer
local hasSessionError = false

local function Config()
	return BUI.GetDB().interface
end

function Drawer.TabLayout(tabSide, x, y, measure)
	local width, height = measure(TAB_W), measure(TAB_H)
	if tabSide == 'TOP' or tabSide == 'BOTTOM' then width, height = height, width end
	local anchor = TAB_ANCHORS[tabSide]
	local inset = measure(TAB_INSET)
	return width, height, anchor.point, anchor.dirX * inset + measure(x), anchor.dirY * inset + measure(y)
end

local function LayoutTab()
	local config = Config()
	local width, height, point, x, y = Drawer.TabLayout(config.drawerSide, config.drawerX, config.drawerY, Pixel.Scale)
	tab:SetSize(width, height)
	tab:ClearAllPoints()
	tab:SetPoint('CENTER', WoWMinimap, point, x, y)
end

local function TabColor()
	if hasSessionError then
		return hovering and TAB_COLOR_ERROR_HOVER or TAB_COLOR_ERROR
	end
	return hovering and TAB_COLOR_HOVER or TAB_COLOR_NORMAL
end

local function PaintTab()
	local color = TabColor()
	Pixel.SetBackgroundColor(tab, color[1], color[2], color[3], color[4])
end

local function OnErrorCaught()
	hasSessionError = true
	PaintTab()
end

local function CancelHide()
	if not hideTimer then return end
	hideTimer:Cancel()
	hideTimer = nil
end

local function HideDrawer()
	hideTimer = nil
	bar:Hide()
	bgFrame:Hide()
	hovering = false
	PaintTab()
	for index = 1, #shown do shown[index]:Hide() end
end

local function ScheduleHide()
	if not active then return end
	CancelHide()
	hideTimer = BUI.Profiler.NewTimer('Minimap.Drawer hide drawer', HIDE_DELAY, HideDrawer)
end

local function AnchorToTab(target)
	local anchor = PANEL_ANCHORS[Config().drawerSide]
	target:ClearAllPoints()
	target:SetPoint(anchor[1], tab, anchor[2], Pixel.Scale(anchor[3]), Pixel.Scale(anchor[4]))
end

local function StyleButton(button)
	local original = button._buiOriginalFuncs
	local iconSize = Pixel.Scale(ICON_SIZE)
	original.SetParent(button, bar)
	original.SetScale(button, 1)
	original.SetSize(button, Pixel.Scale(BUTTON_SIZE), Pixel.Scale(BUTTON_SIZE))
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
	border:Show()
	if not button._buiDrawerHooked then
		button._buiDrawerHooked = true
		button:HookScript('OnEnter', CancelHide)
		button:HookScript('OnLeave', ScheduleHide)
	end
end

local function ShowDrawer()
	CancelHide()
	if not active then return end
	local count = #shown
	if count == 0 then
		HideDrawer()
		return
	end

	local cols = math.min(count, MAX_COLS)
	local rows = math.ceil(count / MAX_COLS)
	local buttonSize = Pixel.Scale(BUTTON_SIZE)
	local step = buttonSize + Pixel.Scale(BUTTON_PAD)
	local margin = Pixel.Scale(MARGIN)
	local width = margin * 2 + cols * step - Pixel.Scale(BUTTON_PAD)
	local height = margin * 2 + rows * step - Pixel.Scale(BUTTON_PAD)

	bar:SetSize(width, height)
	bgFrame:SetSize(width, height)
	AnchorToTab(bar)
	AnchorToTab(bgFrame)

	for index = 1, count do
		local button = shown[index]
		local col = (index - 1) % MAX_COLS
		local row = math.floor((index - 1) / MAX_COLS)
		StyleButton(button)
		button._buiOriginalFuncs.ClearAllPoints(button)
		button._buiOriginalFuncs.SetPoint(button, 'TOPLEFT', bar, 'TOPLEFT', margin + col * step, -(margin + row * step))
		button:SetFrameStrata('MEDIUM')
		button:SetFrameLevel(120)
		button:SetAlpha(1)
		button:Show()
	end

	bgFrame:Show()
	bar:Show()
	hovering = true
	PaintTab()
end

local function Create()
	if bar then return end

	bgFrame = CreateFrame('Frame', 'BUI_AddonDrawerBg', UIParent, 'BackdropTemplate')
	bgFrame:SetFrameStrata('MEDIUM')
	bgFrame:SetFrameLevel(100)
	bgFrame:EnableMouse(true)
	bgFrame:Hide()

	bar = CreateFrame('Frame', 'BUI_AddonDrawerBar', UIParent)
	bar:SetFrameStrata('MEDIUM')
	bar:SetFrameLevel(110)
	bar:EnableMouse(true)
	bar:Hide()

	tab = CreateFrame('Button', 'BUI_AddonDrawerTab', UIParent, 'BackdropTemplate')
	tab:SetFrameStrata('MEDIUM')
	tab:SetFrameLevel(111)

	tab:SetScript('OnEnter', ShowDrawer)
	tab:SetScript('OnLeave', ScheduleHide)
	bar:SetScript('OnEnter', CancelHide)
	bar:SetScript('OnLeave', ScheduleHide)
	bgFrame:SetScript('OnEnter', CancelHide)
	bgFrame:SetScript('OnLeave', ScheduleHide)

	if _G.BugGrabber then
		local dataObject = LibStub('LibDataBroker-1.1'):GetDataObjectByName('BugSack')
		hasSessionError = dataObject and (tonumber(dataObject.text) or 0) > 0 or false
		EventRegistry:RegisterCallback('BugGrabber.BugGrabbed', BUI.Profiler.Wrap('Minimap.Drawer error caught', OnErrorCaught), Drawer)
	end
end

function Drawer.Show()
	active = true
	Create()
	Pixel.SetTemplate(bgFrame, 0.06, 0.06, 0.06, 0.95, 0.12, 0.12, 0.12, 1)
	Pixel.SetTemplate(tab, 0, 0, 0, 0, 0.1, 0.1, 0.1, 1)
	LayoutTab()
	if bar:IsShown() then HideDrawer() else PaintTab() end
	tab:Show()
end

function Drawer.Hide()
	active = false
	CancelHide()
	HideDrawer()
	tab:Hide()
end

function Drawer.Layout(list)
	shown = list
	if bar:IsShown() then ShowDrawer() end
end

BUI.AddonButtons.Register('DRAWER', Drawer)
