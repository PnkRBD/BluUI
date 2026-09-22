local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Controls = BUILib.Controls
local Widget = BUILib.Widget


local cachedTheme
local function theme() if not cachedTheme then cachedTheme = BUILib.Theme end return cachedTheme end

local WINDOW = {
	TOPBAR_H           = 52,
	RAIL_W             = 200,
	NAV_BUTTON_HEIGHT  = 32,
	FOOTER_PADDING     = 12,
	FOOTER_RESERVED    = 56,
	RESIZE_HANDLE_SIZE = 14,

	TITLE_BAR_HEIGHT   = 52,
	TITLE_ICON_SIZE    = 32,
	TITLE_ICON_MARGIN  = 16,
	SIDEBAR_TOP        = 53,
	SIDEBAR_BOTTOM     = 1,
	CONTENT_BOTTOM     = 1,
	NAV_BUTTON_MARGIN  = 8,
}

local function ResolveAccent()
	return theme().GetAccent()
end

local function FindPageIndex(pageOrder, pageID)
	for index, orderedID in ipairs(pageOrder) do
		if orderedID == pageID then return index end
	end
end

local function BuildChipRail(window, navConfig)
	local rail = window.sidebar
	local sections = navConfig.sections or {}
	local pages = navConfig.pages or {}
	local pageOrder = navConfig.pageOrder or {}
	local showPage = navConfig.showPage

	local registered = {}
	local buttons = {}

	local y = -22
	for _, section in ipairs(sections) do
		local headerText = Widget.NavHeader(rail, Widget.StripColorCodes(section.header), y)
		window:TrackNavFrame(headerText)
		y = y - 18

		for _, pageID in ipairs(section.ids) do
			local pageConfig = pages[pageID]
			if pageConfig then
				local pageIndex = FindPageIndex(pageOrder, pageID)
				if pageIndex then
					local label = Widget.StripColorCodes(pageConfig.buttonText or pageConfig.title or pageID)
					local button = Widget.NavChip(rail, label, function() if showPage then showPage(pageIndex) end end)
					if pageConfig.disabled then Widget.NavChipDisable(button) end
					button:SetPoint('TOPLEFT', Widget.NAV_CHIP_X, y)
					button.pageIndex = pageIndex
					buttons[pageIndex] = button
					window:TrackNavFrame(button)
					registered[pageID] = true
					y = y - WINDOW.NAV_BUTTON_HEIGHT - 6
				end
			end
		end
		y = y - 8
	end

	for index, pageID in ipairs(pageOrder) do
		if not registered[pageID] and pages[pageID] and not pages[pageID].hidden then
			local label = Widget.StripColorCodes(pages[pageID].buttonText or pages[pageID].title or pageID)
			local button = Widget.NavChip(rail, label, function() if showPage then showPage(index) end end)
			if pages[pageID].disabled then Widget.NavChipDisable(button) end
			button:SetPoint('TOPLEFT', Widget.NAV_CHIP_X, y)
			button.pageIndex = index
			buttons[index] = button
			window:TrackNavFrame(button)
			y = y - WINDOW.NAV_BUTTON_HEIGHT - 6
		end
	end

	return buttons, math.abs(y) + 16
end

function Layout.Window(config)
	local windowConfig = config or {}
	local accentRed, accentGreen, accentBlue = ResolveAccent()

	local windowWidth       = windowConfig.width or 1100
	local windowHeight      = windowConfig.height or 720
	local title         = windowConfig.title or 'BUILib'
	local version       = windowConfig.version or '1.0'
	local sidebarWidth  = windowConfig.sidebarWidth or WINDOW.RAIL_W
	local footerConfig     = windowConfig.footerButtons or {}
	local onClose       = windowConfig.onClose
	local onSettings    = windowConfig.onSettings
	local onHelp        = windowConfig.onHelp

	local window = {}

	local frame = CreateFrame('Frame', nil, UIParent)
	frame.isBluUIWindow = true
	frame:SetSize(windowWidth, windowHeight)
	frame:SetPoint('CENTER')
	frame:SetFrameStrata(windowConfig.strata or 'HIGH')
	if windowConfig.frameLevel then frame:SetFrameLevel(windowConfig.frameLevel) end
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:EnableMouse(true)
	if windowConfig.clampedToScreen ~= false then frame:SetClampedToScreen(true) end
	window.frame = frame

	local floorMinWidth = windowConfig.minWidth or 1130
	local floorMinHeight = windowConfig.minHeight or 720
	local maxWidth = windowConfig.maxWidth or 1700
	local maxHeight = windowConfig.maxHeight or 1100

	local function ApplyBounds()
		local chromeWidth = (window._sidebarWidth or 0) + 2
		local chromeHeight = WINDOW.TOPBAR_H + WINDOW.FOOTER_RESERVED + 2
		local minWidth = math.max(floorMinWidth, (window._contentMinW or 0) + chromeWidth, (window._footerMinW or 0) + chromeWidth)
		local minHeight = math.max(floorMinHeight, (window._contentMinH or 0) + chromeHeight, (window._navMinH or 0) + WINDOW.TOPBAR_H + WINDOW.FOOTER_RESERVED)
		frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
		local currentWidth, currentHeight = frame:GetSize()
		if currentWidth and currentWidth > 0 and currentWidth < minWidth then frame:SetWidth(minWidth) end
		if currentHeight and currentHeight > 0 and currentHeight < minHeight then frame:SetHeight(minHeight) end
	end

	window._contentMinW = 0
	window._contentMinH = 0
	window._navMinH     = 0
	window._footerMinW  = 0
	window._ApplyBounds = ApplyBounds

	function window:SetContentMinSize(width, height)
		self._contentMinW = width or 0
		self._contentMinH = height or 0
		ApplyBounds()
	end
	function window:SetNavMinHeight(height)
		self._navMinH = height or 0
		ApplyBounds()
	end

	if windowConfig.escapable then

		local client = BUILib.GetActiveClient()
		local globalName = windowConfig.globalName or ('BUILibWindow_' .. ((client and client.name) or 'Default'))
		_G[globalName] = frame
		tinsert(UISpecialFrames, globalName)
	end

	frame.__bui3client = BUILib.GetActiveClient()
	BUILib.SetPopupParent(frame)

	local borderTexture = frame:CreateTexture(nil, 'BACKGROUND', nil, 0)
	borderTexture:SetAllPoints()
	borderTexture:SetTexture(Widget.WHITE)
	borderTexture:SetVertexColor(accentRed * 0.45, accentGreen * 0.45, accentBlue * 0.45, 1)
	theme().RegisterAccentElement(borderTexture, function(element, red, green, blue) element:SetVertexColor(red * 0.45, green * 0.45, blue * 0.45, 1) end)

	local backgroundTexture = frame:CreateTexture(nil, 'BACKGROUND', nil, 1)
	backgroundTexture:SetPoint('TOPLEFT', 1, -1)
	backgroundTexture:SetPoint('BOTTOMRIGHT', -1, 1)
	backgroundTexture:SetTexture(Widget.WHITE)
	backgroundTexture:SetVertexColor(0.04, 0.045, 0.05, 0.98)

	local topbar = CreateFrame('Frame', nil, frame)
	topbar:SetPoint('TOPLEFT', 1, -1)
	topbar:SetPoint('TOPRIGHT', -1, -1)
	topbar:SetHeight(WINDOW.TOPBAR_H)
	topbar:EnableMouse(true)
	topbar:RegisterForDrag('LeftButton')
	topbar:SetScript('OnDragStart', function() frame:StartMoving() end)
	topbar:SetScript('OnDragStop', function() frame:StopMovingOrSizing() end)
	window.titleBar = topbar

	local maskPath = BUILib.GetLibMedia('circle_mask')
	local PORTRAIT_SIZE = 32
	local portrait = topbar:CreateTexture(nil, 'ARTWORK', nil, 2)
	portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait:SetPoint('LEFT', topbar, 'LEFT', 16, 0)
	if windowConfig.icon then
		portrait:SetTexture(windowConfig.icon)
	else
		SetPortraitTexture(portrait, 'player')
	end
	portrait:SetMask(maskPath)
	window.icon = portrait

	local brand = topbar:CreateFontString(nil, 'OVERLAY')
	brand:SetFont(BUILib.Font, 15, 'OUTLINE')
	brand:SetPoint('LEFT', portrait, 'RIGHT', 12, 0)
	brand:SetText(Widget.StripColorCodes(title))
	brand:SetTextColor(1, 1, 1, 1)
	window.title = brand

	if windowConfig.titleSuffix then
		local suffix = topbar:CreateFontString(nil, 'OVERLAY')
		suffix:SetFont(BUILib.Font, 11, '')
		suffix:SetPoint('LEFT', brand, 'RIGHT', 8, 0)
		suffix:SetText(windowConfig.titleSuffix)
		suffix:SetTextColor(accentRed, accentGreen, accentBlue, 1)
		theme().RegisterAccentElement(suffix, function(element, red, green, blue) element:SetTextColor(red, green, blue, 1) end)
		window.titleSuffix = suffix
	end

	local closeButton = Controls.Icon(topbar, {
		size = 14, texture = BUILib.GetLibMedia('x'), tooltip = 'Close',
		onClick = function()
			if onClose then onClose() end
			frame:Hide()
		end,
	})
	closeButton:SetPoint('RIGHT', -16, 0)
	window.closeButton = closeButton

	local lastFrame = Widget.Unwrap(closeButton)
	if onHelp then
		local helpButton = Controls.Icon(topbar, {
			size = 16, texture = BUILib.GetLibMedia('report2'), tooltip = 'Report', onClick = onHelp,
		})
		helpButton:SetPoint('RIGHT', lastFrame, 'LEFT', -12, 0)
		window.helpButton = helpButton
		lastFrame = Widget.Unwrap(helpButton)
	end
	if onSettings then
		local settingsCogButton = Controls.Icon(topbar, {
			size = 14, texture = BUILib.GetLibMedia('cog'), tooltip = 'Settings', onClick = onSettings,
		})
		settingsCogButton:SetPoint('RIGHT', lastFrame, 'LEFT', -12, 0)
		window.settingsButton = settingsCogButton
	end

	window._sidebarWidth = sidebarWidth

	local rail = CreateFrame('Frame', nil, frame)
	rail:SetPoint('TOPLEFT', 1, -WINDOW.TOPBAR_H - 1)
	rail:SetPoint('BOTTOMLEFT', 1, 1)
	rail:SetWidth(sidebarWidth)
	local railLine = rail:CreateTexture(nil, 'OVERLAY')
	railLine:SetTexture(Widget.WHITE); railLine:SetVertexColor(0.10, 0.10, 0.12, 1); railLine:SetWidth(1)
	railLine:SetPoint('TOPRIGHT'); railLine:SetPoint('BOTTOMRIGHT', 0, 50)
	window.sidebar = rail

	local content = CreateFrame('Frame', nil, frame)
	content:SetPoint('TOPLEFT', rail, 'TOPRIGHT', 0, 0)
	content:SetPoint('BOTTOMRIGHT', -1, WINDOW.FOOTER_PADDING + BUILib.ROW_HEIGHT + 2)
	window.content = content

	if windowConfig.watermark then
		local watermark = content:CreateTexture(nil, 'BACKGROUND', nil, 1)
		watermark:SetTexture(windowConfig.watermark)
		watermark:SetSize(480, 480)
		watermark:SetPoint('CENTER')
		watermark:SetVertexColor(1, 1, 1, 0.08)
		window.watermark = watermark
	end

	if windowConfig.searchBox then
		local searchConfig = windowConfig.searchBox
		local searchBox = Controls.SearchBox(topbar, searchConfig.placeholder or 'Search...', searchConfig.onSearch, searchConfig.width or 360)
		searchBox:ClearAllPoints()
		searchBox:SetPoint('LEFT', topbar, 'LEFT', sidebarWidth + 16, 0)
		if not searchConfig.width then
			searchBox:SetPoint('RIGHT', closeButton, 'LEFT', -16, 0)
		end
		if searchConfig.onSubmit and searchBox.frame and searchBox.frame.editbox then
			searchBox.frame.editbox:SetScript('OnEnterPressed', function(self)
				if searchConfig.onSubmit(self:GetText()) then
					self:SetText('')
					self:ClearFocus()
				end
			end)
		end

		local function ForwardDragStart() frame:StartMoving() end
		local function ForwardDragStop() frame:StopMovingOrSizing() end
		local container = searchBox.frame
		container:RegisterForDrag('LeftButton')
		container:HookScript('OnDragStart', ForwardDragStart)
		container:HookScript('OnDragStop', ForwardDragStop)
		if container.editbox then
			container.editbox:RegisterForDrag('LeftButton')
			container.editbox:HookScript('OnDragStart', ForwardDragStart)
			container.editbox:HookScript('OnDragStop', ForwardDragStop)
		end

		window.searchBox = searchBox
	end

	window.footerButtons = {}
	local lastButton = nil
	local footerWidthSum = 0
	local footerCount = #footerConfig
	for footerIndex = footerCount, 1, -1 do
		local buttonConfig = footerConfig[footerIndex]
		local button
		local buttonWidth = buttonConfig.width or 110
		button = Controls.Button(frame, buttonConfig.text, buttonWidth, buttonConfig.callback, { rounded = not buttonConfig.indicator, radius = 6, tooltip = buttonConfig.tooltip, indicator = buttonConfig.indicator or buttonConfig.roundedIndicator, active = buttonConfig.active })
		if lastButton then
			button:SetPoint('RIGHT', lastButton, 'LEFT', -8, 0)
		else
			button:SetPoint('BOTTOMRIGHT', -16, WINDOW.FOOTER_PADDING)
		end
		window.footerButtons[buttonConfig.key or buttonConfig.text] = button
		lastButton = button
		footerWidthSum = footerWidthSum + buttonWidth
	end
	window.footerLeftmost = lastButton
	window._footerMinW = footerWidthSum + math.max(0, footerCount - 1) * 8 + 32
	ApplyBounds()

	local versionLabel = rail:CreateFontString(nil, 'OVERLAY')
	versionLabel:SetFont(BUILib.Font, 12, '')
	versionLabel:SetPoint('BOTTOMLEFT', 18, 14)
	versionLabel:SetText('v' .. version)
	versionLabel:SetTextColor(0.55, 0.55, 0.6, 1)
	window.versionText = versionLabel
	window.versionLabel = versionLabel

	local resize = CreateFrame('Button', nil, frame)
	resize:SetSize(WINDOW.RESIZE_HANDLE_SIZE, WINDOW.RESIZE_HANDLE_SIZE)
	resize:SetPoint('BOTTOMRIGHT', -3, 3)
	resize:SetFrameLevel(frame:GetFrameLevel() + 10)
	local grip = resize:CreateTexture(nil, 'OVERLAY')
	grip:SetTexture(BUILib.GetLibMedia('grabber'))
	grip:SetAllPoints()
	grip:SetVertexColor(accentRed * 0.85, accentGreen * 0.85, accentBlue * 0.85, 0.55)
	theme().RegisterAccentElement(grip, function(element, red, green, blue) element:SetVertexColor(red * 0.85, green * 0.85, blue * 0.85, 0.55) end)
	resize:SetScript('OnMouseDown', function() frame:StartSizing('BOTTOMRIGHT') end)
	resize:SetScript('OnMouseUp', function() frame:StopMovingOrSizing() end)
	resize:SetScript('OnEnter', function(self)
		local red, green, blue = theme().GetAccent()
		for _, region in ipairs({ self:GetRegions() }) do region:SetVertexColor(red, green, blue, 1) end
	end)
	resize:SetScript('OnLeave', function(self)
		local red, green, blue = theme().GetAccent()
		for _, region in ipairs({ self:GetRegions() }) do region:SetVertexColor(red * 0.85, green * 0.85, blue * 0.85, 0.55) end
	end)
	window.resizeHandle = resize

	function window:Show() frame:Show() end
	function window:Hide() frame:Hide() end
	function window:Toggle()
		if frame:IsShown() then frame:Hide() else frame:Show() end
	end

	window._navFrames = {}
	function window:TrackNavFrame(trackedFrame)
		self._navFrames[#self._navFrames + 1] = trackedFrame
		return trackedFrame
	end
	function window:CleanupNavFrames()
		for _, navFrame in ipairs(self._navFrames) do
			navFrame:Hide()
			navFrame:SetParent(nil)
		end
		wipe(self._navFrames)
		Widget.NavResetPill(self.sidebar)
	end

	function window:SetNavStyle(_styleName, navConfig)
		self:CleanupNavFrames()
		local buttons, navHeight = BuildChipRail(self, navConfig or {})
		self:SetNavMinHeight(navHeight or 0)
		return buttons
	end

	window.navButtons = {}
	window.pages = {}
	function window:AddPage(name, createFunc)
		local button = Widget.NavChip(rail, name, function() self:ShowPage(name) end)
		local buttonCount = #self.navButtons
		button:SetPoint('TOPLEFT', Widget.NAV_CHIP_X, -22 - (buttonCount * (WINDOW.NAV_BUTTON_HEIGHT + 6)))
		table.insert(self.navButtons, { name = name, button = button })

		local container = CreateFrame('Frame', nil, content)
		container:SetAllPoints()
		container:Hide()
		local page = createFunc(container)
		page.container = container
		self.pages[name] = page
		if buttonCount == 0 then self:ShowPage(name) end
		return page
	end
	function window:ShowPage(name)
		for _, nav in ipairs(self.navButtons) do
			nav.button:SetSelected(nav.name == name)
		end
		for pageName, page in pairs(self.pages) do
			page.container:SetShown(pageName == name)
		end
		self.currentPage = name
	end

	return window
end
