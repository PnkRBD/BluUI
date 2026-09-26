local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Controls = BUILib.Controls
local Widget = BUILib.Widget
local Theme = BUILib.Theme

local TOPBAR_HEIGHT = 52
local RAIL_WIDTH = 200
local NAV_TOP = 22
local NAV_PITCH = 38
local NAV_SECTION_GAP = 8
local FOOTER_PADDING = 12
local FOOTER_RESERVED = 56
local FOOTER_GAP = 8
local GRIP_SIZE = 14
local NAV_RAIL_INSET = 12
local PORTRAIT_SIZE = 32
local BORDER_ACCENT_SCALE = 0.45
local GRIP_ACCENT_SCALE = 0.85
local GRIP_IDLE_ALPHA = 0.55
local BORDER_SIDES = {
	{ 'TOPLEFT', 'TOPRIGHT', 'SetHeight' },
	{ 'BOTTOMLEFT', 'BOTTOMRIGHT', 'SetHeight' },
	{ 'TOPLEFT', 'BOTTOMLEFT', 'SetWidth' },
	{ 'TOPRIGHT', 'BOTTOMRIGHT', 'SetWidth' },
}

local function Paint(texture, color)
	texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

local function TrackNavFrame(window, navFrame)
	window.navFrames[#window.navFrames + 1] = navFrame
	return navFrame
end

local function ClearNav(window)
	window:ReleaseNav()
	Widget.NavResetPill(window.sidebar)
end

local function BuildChipRail(window, navConfig)
	local rail = window.sidebar
	local pages = navConfig.pages
	local pageOrder = navConfig.pageOrder
	local showPage = navConfig.showPage
	local indexOf, placed, buttons = {}, {}, {}
	local y = -NAV_TOP

	for index, pageID in ipairs(pageOrder) do indexOf[pageID] = index end

	local function PlaceChip(pageID, pageIndex)
		local pageConfig = pages[pageID]
		local label = Widget.StripColorCodes(pageConfig.buttonText or pageConfig.title or pageID)
		local chip = TrackNavFrame(window, Widget.NavChip(rail, label, function() showPage(pageIndex) end))
		if pageConfig.disabled then Widget.NavChipDisable(chip) end
		chip:SetPoint('TOPLEFT', Widget.NAV_CHIP_X, y)
		chip.pageIndex = pageIndex
		buttons[pageIndex] = chip
		placed[pageID] = true
		y = y - NAV_PITCH
	end

	for _, section in ipairs(navConfig.sections or {}) do
		TrackNavFrame(window, Widget.NavHeader(rail, Widget.StripColorCodes(section.header), y))
		y = y - Widget.NAV_HEADER_HEIGHT
		for _, pageID in ipairs(section.ids) do
			if pages[pageID] and indexOf[pageID] then PlaceChip(pageID, indexOf[pageID]) end
		end
		y = y - NAV_SECTION_GAP
	end

	for index, pageID in ipairs(pageOrder) do
		if not placed[pageID] and not pages[pageID].hidden then PlaceChip(pageID, index) end
	end

	return buttons, 16 - y
end

function Layout.PlayerPortrait(texture)
	local function Refresh() SetPortraitTexture(texture, 'player') end
	local owner = texture:GetParent()
	local watcher = CreateFrame('Frame', nil, owner)
	watcher:RegisterUnitEvent('UNIT_PORTRAIT_UPDATE', 'player')
	watcher:RegisterEvent('PORTRAITS_UPDATED')
	watcher:SetScript('OnEvent', Refresh)
	owner:HookScript('OnShow', Refresh)
	Refresh()
end

function Layout.WindowFrame(config)
	local window = { navFrames = {} }

	local frame = CreateFrame('Frame', nil, UIParent)
	frame.isBluUIWindow = true
	frame:SetSize(config.width or 1100, config.height or 720)
	frame:SetPoint('CENTER')
	frame:SetFrameStrata(config.strata or 'HIGH')
	if config.frameLevel then frame:SetFrameLevel(config.frameLevel) end
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(config.clampedToScreen ~= false)
	window.frame = frame

	local floorWidth = config.minWidth or 1130
	local floorHeight = config.minHeight or 720
	local maxWidth = config.maxWidth or 1700
	local maxHeight = config.maxHeight or 1100
	local minimums = {}

	local function ApplyBounds()
		local minWidth, minHeight = floorWidth, floorHeight
		for _, size in pairs(minimums) do
			minWidth = math.max(minWidth, size[1])
			minHeight = math.max(minHeight, size[2])
		end
		frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
		local width, height = frame:GetSize()
		if width < minWidth then frame:SetWidth(minWidth) end
		if height < minHeight then frame:SetHeight(minHeight) end
	end
	ApplyBounds()

	function window:SetMinimum(key, width, height)
		minimums[key] = { width, height }
		ApplyBounds()
	end

	if config.escapable then
		local globalName = config.globalName or ('BUILibWindow_' .. BUILib.GetActiveClient().name)
		_G[globalName] = frame
		if not tContains(UISpecialFrames, globalName) then tinsert(UISpecialFrames, globalName) end
	end

	frame.__bui3client = BUILib.GetActiveClient()
	BUILib.SetPopupParent(frame)

	local borderEdges = {}
	for index, side in ipairs(BORDER_SIDES) do
		local edge = frame:CreateTexture(nil, 'BACKGROUND', nil, 0)
		edge:SetTexture(Widget.WHITE)
		edge:SetPoint(side[1])
		edge:SetPoint(side[2])
		edge[side[3]](edge, 1)
		borderEdges[index] = edge
	end

	local backgroundTexture = frame:CreateTexture(nil, 'BACKGROUND', nil, 1)
	backgroundTexture:SetPoint('TOPLEFT', 1, -1)
	backgroundTexture:SetPoint('BOTTOMRIGHT', -1, 1)
	backgroundTexture:SetTexture(Widget.WHITE)

	local function StartMoving() frame:StartMoving() end
	local function StopMoving()
		frame:StopMovingOrSizing()
		if config.onGeometryChanged then config.onGeometryChanged(window) end
	end

	function window:DragWith(region)
		region:EnableMouse(true)
		region:RegisterForDrag('LeftButton')
		region:HookScript('OnDragStart', StartMoving)
		region:HookScript('OnDragStop', StopMoving)
	end

	local resize = CreateFrame('Button', nil, frame)
	resize:SetSize(GRIP_SIZE, GRIP_SIZE)
	resize:SetPoint('BOTTOMRIGHT', -3, 3)
	resize:SetFrameLevel(frame:GetFrameLevel() + 10)
	local grip = resize:CreateTexture(nil, 'OVERLAY')
	grip:SetTexture(BUILib.GetLibMedia('grabber'))
	grip:SetAllPoints()
	local function PaintGrip(red, green, blue)
		if resize:IsMouseOver() then
			grip:SetVertexColor(red, green, blue, 1)
		else
			grip:SetVertexColor(red * GRIP_ACCENT_SCALE, green * GRIP_ACCENT_SCALE, blue * GRIP_ACCENT_SCALE, GRIP_IDLE_ALPHA)
		end
	end
	local function RepaintGrip() PaintGrip(Theme.GetAccent()) end
	Theme.RegisterAccentElement(grip, function(_, red, green, blue) PaintGrip(red, green, blue) end)
	resize:SetScript('OnMouseDown', function() frame:StartSizing('BOTTOMRIGHT') end)
	resize:SetScript('OnMouseUp', StopMoving)
	resize:SetScript('OnEnter', RepaintGrip)
	resize:SetScript('OnLeave', RepaintGrip)
	RepaintGrip()

	local customBorder
	local function PaintBorder(red, green, blue)
		if customBorder then
			Widget.SetRectColor(borderEdges, customBorder[1], customBorder[2], customBorder[3], customBorder[4])
		else
			Widget.SetRectColor(borderEdges, red * BORDER_ACCENT_SCALE, green * BORDER_ACCENT_SCALE, blue * BORDER_ACCENT_SCALE, 1)
		end
	end

	function window:PaintFrame(background, border)
		customBorder = border
		Paint(backgroundTexture, background)
		PaintBorder(Theme.GetAccent())
	end

	function window:GetBorderColor()
		return borderEdges[1]:GetVertexColor()
	end

	local roles = setmetatable({}, { __mode = 'k' })
	local theme = {}
	window.font = config.font or BUILib.Font

	function window:GetMode()
		return theme.mode or 'dark'
	end

	function window:Color(role, mode)
		if role == 'accent' then return Theme.GetAccent() end
		if role == 'onAccent' then return Theme.ReadableOn(Theme.GetAccent()) end
		mode = mode or self:GetMode()
		local overrides = theme[mode]
		local color = self.ChromeColor and self:ChromeColor(role, theme, mode) or overrides and overrides[role] or Theme.palettes[mode][role]
		return color[1], color[2], color[3], color[4] or 1
	end

	local function Apply(region, role)
		if type(role) == 'function' then
			role(region)
		elseif region.SetTextColor then
			region:SetTextColor(window:Color(role))
		else
			region:SetVertexColor(window:Color(role))
		end
	end

	function window:Paint(region, role)
		roles[region] = role
		Apply(region, role)
		return region
	end

	function window:Bind(region, update)
		return self:Paint(region, update)
	end

	function window:Fill(parent, role, layer, subLayer)
		local texture = parent:CreateTexture(nil, layer or 'BACKGROUND', nil, subLayer or 0)
		texture:SetTexture(Widget.WHITE)
		return self:Paint(texture, role)
	end

	function window:Text(parent, text, size, role)
		local label = parent:CreateFontString(nil, 'OVERLAY')
		label:SetFont(self.font, size, '')
		label:SetText(text)
		return self:Paint(label, role)
	end

	local function Attached(region)
		local parent = region:GetParent()
		while parent and parent ~= frame do parent = parent:GetParent() end
		return parent == frame
	end

	function window:Repaint()
		for region, role in pairs(roles) do
			if Attached(region) then Apply(region, role) else roles[region] = nil end
		end
		self:PaintChrome(theme)
	end
	Theme.RegisterAccentElement(frame, function() window:Repaint() end)

	function window:ApplyTheme(newTheme)
		theme = newTheme or {}
		self:Repaint()
	end

	function window:SetMode(mode)
		theme.mode = mode
		self:Repaint()
	end

	function window:ReleaseNav()
		for _, navFrame in ipairs(self.navFrames) do
			navFrame:Hide()
			navFrame:SetParent(nil)
		end
		wipe(self.navFrames)
	end

	function window:Show()
		frame:Show()
		frame:Raise()
	end
	function window:Hide() frame:Hide() end

	return window
end

function Layout.Window(config)
	local sidebarWidth = config.sidebarWidth or RAIL_WIDTH
	local chromeWidth, chromeHeight = sidebarWidth + 2, TOPBAR_HEIGHT + FOOTER_RESERVED + 2
	local footerConfig = config.footerButtons or {}
	local window = Layout.WindowFrame(config)
	local frame = window.frame

	function window:SetContentMinSize(width, height)
		self:SetMinimum('content', width + chromeWidth, height + chromeHeight)
	end

	local topbar = CreateFrame('Frame', nil, frame)
	topbar:SetPoint('TOPLEFT', 1, -1)
	topbar:SetPoint('TOPRIGHT', -1, -1)
	topbar:SetHeight(TOPBAR_HEIGHT)
	window:DragWith(topbar)

	local titleBarTexture = topbar:CreateTexture(nil, 'BACKGROUND')
	titleBarTexture:SetAllPoints()
	titleBarTexture:SetTexture(Widget.WHITE)

	local portrait = topbar:CreateTexture(nil, 'ARTWORK', nil, 2)
	portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait:SetPoint('LEFT', 16, 0)
	if config.icon then
		portrait:SetTexture(config.icon)
	else
		Layout.PlayerPortrait(portrait)
	end
	portrait:SetMask(BUILib.GetLibMedia('circle_mask'))

	local brand = topbar:CreateFontString(nil, 'OVERLAY')
	brand:SetFont(BUILib.Font, 15, 'OUTLINE')
	brand:SetText(Widget.StripColorCodes(config.title or 'BUILib'))

	if not config.titleSuffix then
		brand:SetPoint('LEFT', portrait, 'RIGHT', 12, 0)
	else
		brand:SetPoint('BOTTOMLEFT', portrait, 'RIGHT', 12, -3)
		local suffix = topbar:CreateFontString(nil, 'OVERLAY')
		suffix:SetFont(BUILib.Font, 11, '')
		suffix:SetPoint('TOPLEFT', brand, 'BOTTOMLEFT', 0, 3)
		suffix:SetText(config.titleSuffix)
		suffix:SetTextColor(Theme.GetAccent())
		Theme.RegisterAccentElement(suffix, function(element, red, green, blue) element:SetTextColor(red, green, blue, 1) end)
	end

	local closeButton = Controls.Icon(topbar, {
		size = 14, texture = BUILib.GetLibMedia('x'), tooltip = 'Close',
		onClick = function() frame:Hide() end,
	})
	closeButton:SetPoint('RIGHT', -16, 0)

	local rail = CreateFrame('Frame', nil, frame)
	rail:SetPoint('TOPLEFT', 1, -TOPBAR_HEIGHT - 1)
	rail:SetPoint('BOTTOMLEFT', 1, 1)
	rail:SetWidth(sidebarWidth)
	window.sidebar = rail

	local sidebarTexture = rail:CreateTexture(nil, 'BACKGROUND')
	sidebarTexture:SetAllPoints()
	sidebarTexture:SetTexture(Widget.WHITE)

	local divider = rail:CreateTexture(nil, 'OVERLAY')
	divider:SetTexture(Widget.WHITE)
	divider:SetWidth(1)
	divider:SetPoint('TOPRIGHT')
	divider:SetPoint('BOTTOMRIGHT', 0, 50)

	local content = CreateFrame('Frame', nil, frame)
	content:SetPoint('TOPLEFT', rail, 'TOPRIGHT', 0, 0)
	content:SetPoint('BOTTOMRIGHT', -1, FOOTER_PADDING + BUILib.ROW_HEIGHT + 2)
	window.content = content

	if config.searchBox then
		local searchConfig = config.searchBox
		local searchBox = Controls.SearchBox(topbar, searchConfig.placeholder or 'Search...', searchConfig.onSearch, searchConfig.width or 360)
		searchBox:ClearAllPoints()
		searchBox:SetPoint('LEFT', topbar, 'LEFT', sidebarWidth + 16, 0)
		if not searchConfig.width then
			searchBox:SetPoint('RIGHT', closeButton, 'LEFT', -16, 0)
		end
		local container = searchBox.frame
		if searchConfig.onSubmit then
			container.editbox:SetScript('OnEnterPressed', function(self)
				if searchConfig.onSubmit(self:GetText()) then
					self:SetText('')
					self:ClearFocus()
				end
			end)
		end
		window:DragWith(container)
		window:DragWith(container.editbox)
		window.searchBox = searchBox
	end

	window.footerButtons = {}
	local lastButton
	local footerWidth = 0
	for footerIndex = #footerConfig, 1, -1 do
		local buttonConfig = footerConfig[footerIndex]
		local button = Controls.Button(frame, buttonConfig.text, buttonConfig.width or 110, buttonConfig.callback, {
			rounded = not buttonConfig.indicator, radius = 6, tooltip = buttonConfig.tooltip,
			indicator = buttonConfig.indicator or buttonConfig.roundedIndicator, active = buttonConfig.active,
		})
		if lastButton then
			button:SetPoint('RIGHT', lastButton, 'LEFT', -FOOTER_GAP, 0)
		else
			button:SetPoint('BOTTOMRIGHT', -16, FOOTER_PADDING)
		end
		window.footerButtons[buttonConfig.key or buttonConfig.text] = button
		lastButton = button
		footerWidth = footerWidth + Widget.Unwrap(button):GetWidth()
	end
	window.footerLeftmost = lastButton
	window:SetMinimum('footer', footerWidth + math.max(0, #footerConfig - 1) * FOOTER_GAP + 32 + chromeWidth, 0)

	local versionLabel = rail:CreateFontString(nil, 'OVERLAY')
	versionLabel:SetFont(BUILib.Font, 12, '')
	versionLabel:SetPoint('BOTTOMLEFT', 18, 14)
	versionLabel:SetText('v' .. (config.version or '1.0'))

	local function Override(theme, mode, role)
		local overrides = theme[mode]
		return overrides and overrides[role]
	end

	function window:ChromeColor(role, theme, mode)
		if role == 'page' then return Override(theme, mode, 'page') or Theme.window[mode].background end
		if role == 'edge' and not Override(theme, mode, 'edge') then
			local red, green, blue = Theme.GetAccent()
			return { red * BORDER_ACCENT_SCALE, green * BORDER_ACCENT_SCALE, blue * BORDER_ACCENT_SCALE, 1 }
		end
	end

	function window:PaintChrome(theme)
		local mode = self:GetMode()
		local look = Theme.window[mode]
		self:PaintFrame({ self:Color('page') }, Override(theme, mode, 'edge'))
		Paint(titleBarTexture, Override(theme, mode, 'bar') or look.titleBar)
		Paint(sidebarTexture, Override(theme, mode, 'sidebar') or look.sidebar)
		Paint(divider, Override(theme, mode, 'sidebarEdge') or look.divider)
		brand:SetFont(BUILib.Font, 15, look.outline and 'OUTLINE' or '')
		brand:SetTextColor(unpack(look.text))
		versionLabel:SetTextColor(unpack(look.faint))
		closeButton:SetIdleColor(unpack(look.icon))
		Widget.NavSetColors(rail, look.nav)
	end

	function window:SetNavStyle(_, navConfig)
		ClearNav(self)
		local buttons, navHeight
		if config.navStyle == 'rail' then
			local navRail
			navRail, buttons = Layout.NavRail(self, rail, sidebarWidth - NAV_RAIL_INSET * 2, navConfig)
			navRail.frame:SetPoint('TOPLEFT', NAV_RAIL_INSET, -NAV_TOP)
			TrackNavFrame(self, navRail.frame)
			navHeight = navRail.height + NAV_TOP
		else
			buttons, navHeight = BuildChipRail(self, navConfig)
		end
		self:SetMinimum('nav', 0, navHeight + TOPBAR_HEIGHT + FOOTER_RESERVED)
		return buttons
	end

	window:ApplyTheme(config.theme)
	return window
end
