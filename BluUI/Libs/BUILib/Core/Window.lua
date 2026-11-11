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
local FOOTER_PADDING = 15
local FOOTER_HEIGHT = 56
local PAGE_MARGIN = 48
local PAGE_MIN_HEIGHT = 240
local FOOTER_GAP = 8
local GRIP_SIZE = 14
local NAV_RAIL_INSET = 12
local PORTRAIT_SIZE = 32
local BRAND_SIZE = 15
local BAR_ICON_GAP = 14
local CARD_HEAD = 50
local CARD_PAD = 14
local BORDER_ACCENT_SCALE = 0.45
local GRIP_ACCENT_SCALE = 0.85
local GRIP_IDLE_ALPHA = 0.55
local BORDER_SIDES = {
	{ 'TOPLEFT', 'TOPRIGHT', 'SetHeight' },
	{ 'BOTTOMLEFT', 'BOTTOMRIGHT', 'SetHeight' },
	{ 'TOPLEFT', 'BOTTOMLEFT', 'SetWidth' },
	{ 'TOPRIGHT', 'BOTTOMRIGHT', 'SetWidth' },
}
local LOOK_ROLES = { page = 'background', bar = 'titleBar', barText = 'text', barIcon = 'icon', sidebar = 'sidebar', sidebarEdge = 'divider' }
local FONT_ROLES = { text = 'title', barText = 'title', barMuted = 'title', muted = 'body', faint = 'hint', controlText = 'control', onAccent = 'control', secondaryText = 'control' }

Layout.TITLE_BAR_HEIGHT = TOPBAR_HEIGHT
Layout.FOOTER_HEIGHT = FOOTER_HEIGHT

function Layout.DefaultColor(role, mode)
	local lookRole = LOOK_ROLES[role]
	return lookRole and Theme.window[mode][lookRole] or Theme.palettes[mode][role]
end

function Layout.ThemeOverride(theme, role, mode)
	local overrides = theme[mode or theme.mode or 'dark']
	return overrides and overrides[role]
end

function Layout.ThemeChromeColor(theme, role, mode)
	if role == 'edge' and theme.edgeAccent ~= false and not Layout.ThemeOverride(theme, 'edge', mode) then
		local red, green, blue = Theme.GetAccent()
		return { red * BORDER_ACCENT_SCALE, green * BORDER_ACCENT_SCALE, blue * BORDER_ACCENT_SCALE, 1 }
	end
end

function Layout.ThemeColor(theme, role, mode)
	if role == 'accent' then return Theme.GetAccent() end
	if role == 'onAccent' then return Theme.ReadableOn(Theme.GetAccent()) end
	mode = mode or theme.mode or 'dark'
	local color = Layout.ThemeChromeColor(theme, role, mode) or Layout.ThemeOverride(theme, role, mode) or Layout.DefaultColor(role, mode)
	return color[1], color[2], color[3], color[4] or 1
end

function Layout.ThemeFontPath(theme, fontRole, resolveFont, fallback)
	local fonts = theme.fonts
	local name = fonts and (fonts[fontRole] or fonts.base)
	return name and resolveFont(name) or fallback
end

function Layout.FrameChrome(frame)
	local edges = {}
	for index, side in ipairs(BORDER_SIDES) do
		local edge = frame:CreateTexture(nil, 'BACKGROUND', nil, 0)
		edge:SetTexture(Widget.WHITE)
		edge:SetPoint(side[1])
		edge:SetPoint(side[2])
		edge[side[3]](edge, 1)
		edges[index] = edge
	end
	local background = frame:CreateTexture(nil, 'BACKGROUND', nil, 1)
	background:SetPoint('TOPLEFT', 1, -1)
	background:SetPoint('BOTTOMRIGHT', -1, 1)
	background:SetTexture(Widget.WHITE)
	return edges, background
end

local function TrackNavFrame(window, navFrame)
	window.navFrames[#window.navFrames + 1] = navFrame
	return navFrame
end

local function ClearNav(window)
	window:ReleaseNav()
	Widget.NavResetPill(window.sidebar)
end

local function NavGroups(navConfig)
	local groups, placed, indexOf = {}, {}, {}
	for index, pageID in ipairs(navConfig.pageOrder) do indexOf[pageID] = index end
	local function Item(pageID)
		local page = navConfig.pages[pageID]
		placed[pageID] = true
		return { id = pageID, index = indexOf[pageID], label = Widget.StripColorCodes(page.buttonText or page.title or pageID), icon = page.icon, count = page.count, disabled = page.disabled }
	end
	for _, section in ipairs(navConfig.sections or {}) do
		local items = {}
		for _, pageID in ipairs(section.ids) do
			local page = navConfig.pages[pageID]
			if page and indexOf[pageID] and not page.hidden then items[#items + 1] = Item(pageID) end
		end
		if #items > 0 then groups[#groups + 1] = { title = Widget.StripColorCodes(section.header), items = items } end
	end
	local rest = {}
	for _, pageID in ipairs(navConfig.pageOrder) do
		if not placed[pageID] and not navConfig.pages[pageID].hidden then rest[#rest + 1] = Item(pageID) end
	end
	if #rest > 0 then groups[#groups + 1] = { items = rest } end
	return groups
end

local function BuildChipRail(window, navConfig)
	local rail = window.sidebar
	local buttons = {}
	local y = -NAV_TOP
	for groupIndex, group in ipairs(NavGroups(navConfig)) do
		if groupIndex > 1 then y = y - NAV_SECTION_GAP end
		if group.title then
			TrackNavFrame(window, Widget.NavHeader(rail, group.title, y))
			y = y - Widget.NAV_HEADER_HEIGHT
		end
		for _, item in ipairs(group.items) do
			local chip = TrackNavFrame(window, Widget.NavChip(rail, item.label, function() navConfig.showPage(item.index) end))
			if item.disabled then Widget.NavChipDisable(chip) end
			chip:SetPoint('TOPLEFT', Widget.NAV_CHIP_X, y)
			buttons[item.index] = chip
			y = y - NAV_PITCH
		end
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

local function BarIcon(window, parent, glyph, tooltip, onClick)
	local icon = Controls.Icon(parent, { size = 14, texture = BUILib.GetLibMedia(glyph), tooltip = tooltip, onClick = onClick })
	window:Bind(Widget.Unwrap(icon), function() icon:SetIdleColor(window:Color('barIcon')) end)
	return icon
end

function Layout.WindowFrame(config)
	local window = { navFrames = {} }

	local frame = CreateFrame('Frame', nil, UIParent)
	frame:SetSize(config.width or 1100, config.height or 720)
	frame:SetPoint('CENTER')
	frame:SetFrameStrata(config.strata or 'HIGH')
	if config.frameLevel then frame:SetFrameLevel(config.frameLevel) end
	frame:SetMovable(true)
	frame:SetResizable(config.resizable ~= false)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(config.clampedToScreen ~= false)
	window.frame = frame
	frame.window = window

	local floorWidth = config.minWidth or 1130
	local floorHeight = config.minHeight or 0
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

	local borderEdges, backgroundTexture = Layout.FrameChrome(frame)

	local dragDriver = CreateFrame('Frame', nil, frame)
	local dragCursorX, dragCursorY, dragLeft, dragTop
	local function FollowCursor()
		local cursorX, cursorY = GetCursorPosition()
		local scale = frame:GetEffectiveScale()
		local pixel = PixelUtil.GetPixelToUIUnitFactor() / scale
		local left = dragLeft + (cursorX - dragCursorX) / scale
		local top = dragTop + (cursorY - dragCursorY) / scale
		frame:ClearAllPoints()
		frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', Widget.SnapX(left, pixel), Widget.SnapY(top, pixel))
	end
	local function StartMoving()
		dragLeft, dragTop = frame:GetLeft(), frame:GetTop()
		if not dragLeft or not dragTop then return end
		dragCursorX, dragCursorY = GetCursorPosition()
		dragDriver:SetScript('OnUpdate', FollowCursor)
	end
	local function StopMoving()
		dragDriver:SetScript('OnUpdate', nil)
		frame:StopMovingOrSizing()
		local pixel = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
		frame:SetSize(Widget.SnapX(frame:GetWidth(), pixel), Widget.SnapX(frame:GetHeight(), pixel))
		Widget.PinToPixels(frame)
		if config.onGeometryChanged then config.onGeometryChanged(window) end
	end

	function window:DragWith(region)
		region:EnableMouse(true)
		region:RegisterForDrag('LeftButton')
		region:HookScript('OnDragStart', StartMoving)
		region:HookScript('OnDragStop', StopMoving)
	end

	if config.resizable ~= false then
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
	end

	function window:PaintFrame(background, border)
		backgroundTexture:SetVertexColor(background[1], background[2], background[3], background[4])
		Widget.SetRectColor(borderEdges, border[1], border[2], border[3], border[4])
	end

	function window:GetBorderColor()
		return borderEdges[1]:GetVertexColor()
	end

	local roles = setmetatable({}, { __mode = 'k' })
	local fonts = setmetatable({}, { __mode = 'k' })
	local theme = {}
	window.font = config.font or BUILib.Font

	function window:GetMode()
		return theme.mode or 'dark'
	end

	function window:Separators()
		return theme.separators or 'dotted'
	end

	function window:Override(role, mode)
		return Layout.ThemeOverride(theme, role, mode or self:GetMode())
	end

	function window:FontPath(fontRole)
		return Layout.ThemeFontPath(theme, fontRole, config.resolveFont, self.font)
	end

	function window:ChromeColor(role, mode)
		return Layout.ThemeChromeColor(theme, role, mode or self:GetMode())
	end

	function window:Color(role, mode)
		if role == 'accent' then return Theme.GetAccent() end
		if role == 'onAccent' then return Theme.ReadableOn(Theme.GetAccent()) end
		mode = mode or self:GetMode()
		local color = self:ChromeColor(role, mode) or self:Override(role, mode) or Layout.DefaultColor(role, mode)
		return color[1], color[2], color[3], color[4] or 1
	end

	function window:PaintChrome()
		self:PaintFrame({ self:Color('page') }, { self:Color('edge') })
	end

	local function Apply(region, role)
		if type(role) == 'function' then
			role(region)
		elseif region.SetTextColor then
			region:SetTextColor(window:Color(role))
			local fontRole = fonts[region]
			if fontRole then
				local path, size, flags = region:GetFont()
				local wanted = window:FontPath(fontRole)
				if path ~= wanted then region:SetFont(wanted, size, flags) end
			end
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

	function window:SetFontRole(region, fontRole)
		fonts[region] = fontRole
		local _, size, flags = region:GetFont()
		region:SetFont(self:FontPath(fontRole), size, flags)
		return region
	end

	function window:Text(parent, text, size, role, fontRole)
		local label = parent:CreateFontString(nil, 'OVERLAY')
		label:SetFont(self.font, size, '')
		label:SetText(text)
		fonts[label] = fontRole or FONT_ROLES[role]
		return self:Paint(label, role)
	end

	local function Attached(region)
		local parent = region:GetParent()
		while parent and parent ~= frame do parent = parent._paintOwner or parent:GetParent() end
		return parent == frame
	end

	function window:Repaint()
		for region, role in pairs(roles) do
			if Attached(region) then Apply(region, role) else roles[region] = nil end
		end
		self:PaintChrome()
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

function Layout.TitleBar(window, config)
	local bar = CreateFrame('Frame', nil, window.frame)
	bar:SetPoint('TOPLEFT', 1, -1)
	bar:SetPoint('TOPRIGHT', -1, -1)
	bar:SetHeight(TOPBAR_HEIGHT)
	window:DragWith(bar)
	window:Fill(bar, 'bar'):SetAllPoints()

	if config.brand ~= false then
		local portrait = bar:CreateTexture(nil, 'ARTWORK', nil, 2)
		portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
		portrait:SetPoint('LEFT', 16, 0)
		if config.icon then
			portrait:SetTexture(config.icon)
		else
			Layout.PlayerPortrait(portrait)
		end
		portrait:SetMask(BUILib.GetLibMedia('circle_mask'))

		local brand = window:Text(bar, Widget.StripColorCodes(config.title or 'BUILib'), BRAND_SIZE, 'barText')
		brand:SetPoint('LEFT', portrait, 'RIGHT', 12, 0)
	end

	local close = BarIcon(window, bar, 'x', 'Close', function() window.frame:Hide() end)
	close:SetPoint('RIGHT', -16, 0)

	if config.card then
		BarIcon(window, bar, 'minus', 'Minimize', function() window:Minimize() end):SetPoint('RIGHT', Widget.Unwrap(close), 'LEFT', -BAR_ICON_GAP, 0)
		Layout.MinimizedCard(window, config, Widget.Unwrap(close))
	end

	return { frame = bar, close = close }
end

local function Chip(window, kit, parent, icon, label, on)
	local chip = CreateFrame('Button', nil, parent)
	chip:SetHeight(28)
	local fill = window:Fill(chip, 'secondary')
	fill:SetAllPoints()
	kit.Hover(chip)
	local glyph = kit.Glyph(chip, icon, 13, 'muted')
	glyph:SetPoint('LEFT', 8, 0)
	local text = label and kit.Text(chip, label, 12, 'muted', nil, 'title')
	if text then text:SetPoint('LEFT', glyph, 'RIGHT', 8, 0) end
	chip:SetWidth(29 + (text and 8 + math.ceil(text:GetStringWidth()) or 0))
	function chip:SetOn(value)
		fill:SetShown(value)
		window:Paint(glyph, value and 'accent' or 'muted')
		if text then window:Paint(text, value and 'text' or 'muted') end
	end
	chip:SetOn(on)
	return chip
end

function Layout.MinimizedCard(window, config, windowClose)
	local frame, spec, kit = window.frame, config.card, Layout.TableKit(window)
	local minimized, closedCallbacks, chips = false, {}, {}
	local cog, Refresh

	local card = CreateFrame('Button', nil, UIParent)
	card:SetFrameStrata(frame:GetFrameStrata())
	card:SetFrameLevel(frame:GetFrameLevel())
	card:SetMovable(true)
	card:SetClampedToScreen(true)
	card:RegisterForDrag('LeftButton')
	card:SetScript('OnDragStart', card.StartMoving)
	card:SetScript('OnDragStop', card.StopMovingOrSizing)
	card:SetScript('OnClick', spec.onRestore)
	card:Hide()
	card._paintOwner = frame
	local edges, background = Layout.FrameChrome(card)
	for _, edge in ipairs(edges) do window:Paint(edge, 'edge') end
	window:Paint(background, 'page')
	local rule = window:Fill(card, 'rule', 'ARTWORK')
	rule:SetPoint('TOPLEFT', 1, -CARD_HEAD - 1)
	rule:SetPoint('BOTTOMRIGHT', card, 'TOPRIGHT', -1, -CARD_HEAD - 2)

	local logo = card:CreateTexture(nil, 'ARTWORK')
	logo:SetSize(28, 28)
	logo:SetPoint('LEFT', card, 'TOPLEFT', CARD_PAD + 1, -CARD_HEAD / 2 - 1)
	logo:SetTexture(config.icon)
	logo:SetMask(BUILib.GetLibMedia('circle_mask'))
	local heading = window:Text(card, '', 15, 'barText')
	heading:SetPoint('BOTTOMLEFT', logo, 'RIGHT', 12, 1)
	local subheading = window:Text(card, '', 11, 'muted')
	subheading:SetPoint('TOPLEFT', heading, 'BOTTOMLEFT', 0, -2)

	local function Closed()
		for _, callback in ipairs(closedCallbacks) do callback() end
	end
	local close = BarIcon(window, card, 'x', 'Close', function()
		minimized = false
		card:Hide()
		Closed()
	end)
	close:SetPoint('RIGHT', card, 'TOPRIGHT', -CARD_PAD - 1, -CARD_HEAD / 2 - 1)
	local expand = BarIcon(window, card, 'resize', 'Expand', spec.onRestore)
	expand:SetPoint('RIGHT', Widget.Unwrap(close), 'LEFT', -BAR_ICON_GAP, 0)
	local divider = window:Fill(card, 'rule', 'ARTWORK')
	divider:SetSize(1, 24)
	divider:SetPoint('RIGHT', Widget.Unwrap(expand), 'LEFT', -12, 0)

	local function Rebuild()
		local right, top = card:GetRight(), card:GetTop()
		Refresh()
		card:ClearAllPoints()
		card:SetPoint('TOPRIGHT', UIParent, 'BOTTOMLEFT', right, top)
	end
	cog = kit.IconButton(card, 'cog', 'Choose shortcuts', function()
		local items = spec.items()
		local rows = math.ceil(#items / 2)
		Controls.Popover({
			anchor = cog, width = 300, height = rows * 30 - 2, title = 'Shortcuts',
			bg = { window:Color('page') }, border = { window:Color('edge') },
			build = function(panel)
				local width = (panel.width - 2) / 2
				for index, item in ipairs(items) do
					local chip = Chip(window, kit, panel, item.icon, item.label, item.get())
					chip:SetWidth(width)
					chip:SetPoint('TOPLEFT', math.floor((index - 1) / rows) * (width + 2), -((index - 1) % rows) * 30)
					chip:SetScript('OnClick', function()
						item.set(not item.get())
						chip:SetOn(item.get())
						Rebuild()
					end)
				end
			end,
		})
	end)
	cog:SetPoint('RIGHT', divider, 'LEFT', -8, 0)

	function Refresh()
		heading:SetText(spec.heading())
		subheading:SetText(spec.subheading())
		for _, chip in ipairs(chips) do
			chip:Hide()
			chip:SetParent(nil)
		end
		wipe(chips)
		local x = 9
		for _, item in ipairs(spec.items()) do
			if item.current or item.get() then
				local chip = Chip(window, kit, card, item.icon, item.current and item.label, item.current)
				chip:SetPoint('TOPLEFT', x, -CARD_HEAD - 6)
				chip:SetScript('OnClick', item.open)
				if item.current then
					local bar = window:Fill(chip, 'accent', 'ARTWORK')
					bar:SetPoint('BOTTOMLEFT')
					bar:SetPoint('TOPRIGHT', chip, 'BOTTOMRIGHT', 0, 2)
				else
					chip:HookScript('OnEnter', function(self) Widget.ShowTip(self, item.label) end)
					chip:HookScript('OnLeave', Widget.HideTip)
				end
				chips[#chips + 1] = chip
				x = x + chip:GetWidth() + 2
			end
		end
		local text = math.max(heading:GetStringWidth(), subheading:GetStringWidth())
		card:SetSize(Widget.EvenSize(math.max(x + 7, text + cog:GetWidth() + 117 + CARD_PAD * 2)), CARD_HEAD + 41)
	end

	frame:HookScript('OnShow', function()
		minimized = false
		card:Hide()
	end)
	frame:HookScript('OnHide', function()
		if not minimized then Closed() end
	end)

	function window:OnClosed(callback)
		closedCallbacks[#closedCallbacks + 1] = callback
	end

	function window:Minimize()
		local x, y = windowClose:GetCenter()
		minimized = true
		frame:Hide()
		card:SetScale(frame:GetScale())
		Refresh()
		card:ClearAllPoints()
		card:SetPoint('TOPRIGHT', UIParent, 'BOTTOMLEFT', x + 8 + CARD_PAD, y + CARD_HEAD / 2 + 1)
		card:Show()
	end
end

function Layout.ReservePage(window, pageWidth, sidebarWidth, footerHeight)
	window:SetMinimum('page', pageWidth + PAGE_MARGIN + sidebarWidth, TOPBAR_HEIGHT + footerHeight + PAGE_MIN_HEIGHT)
end

function Layout.SidebarRail(window, sidebar, sidebarWidth, navConfig)
	local rail = Layout.Rail(window, sidebar, sidebarWidth - NAV_RAIL_INSET * 2, {
		groups = NavGroups(navConfig),
		onSelect = function(item) navConfig.showPage(item.index) end,
	})
	rail.frame:SetPoint('TOPLEFT', NAV_RAIL_INSET, -NAV_TOP)
	TrackNavFrame(window, rail.frame)
	local buttons = {}
	for _, entry in ipairs(rail.entries) do
		function entry.button:SetSelected(isSelected)
			if isSelected then rail:Select(entry.item.id) end
		end
		buttons[entry.item.index] = entry.button
	end
	return buttons, rail.height + NAV_TOP
end

function Layout.Window(config)
	local sidebarWidth = config.sidebarWidth or RAIL_WIDTH
	local chromeWidth, chromeHeight = sidebarWidth + 2, TOPBAR_HEIGHT + FOOTER_HEIGHT + 2
	local footerConfig = config.footerButtons or {}
	local window = Layout.WindowFrame(config)
	local frame = window.frame

	function window:SetContentMinSize(width, height)
		self:SetMinimum('content', width + chromeWidth, height + chromeHeight)
	end
	if config.pageWidth then Layout.ReservePage(window, config.pageWidth, sidebarWidth, FOOTER_HEIGHT) end

	local titleBar = Layout.TitleBar(window, config)
	local topbar = titleBar.frame

	local rail = CreateFrame('Frame', nil, frame)
	rail:SetPoint('TOPLEFT', 1, -TOPBAR_HEIGHT - 1)
	rail:SetPoint('BOTTOMLEFT', 1, 1)
	rail:SetWidth(sidebarWidth)
	window.sidebar = rail
	window:Fill(rail, 'sidebar'):SetAllPoints()

	local divider = window:Fill(rail, 'sidebarEdge', 'OVERLAY')
	divider:SetWidth(1)
	divider:SetPoint('TOPRIGHT')
	divider:SetPoint('BOTTOMRIGHT', 0, 50)

	local content = CreateFrame('Frame', nil, frame)
	content:SetPoint('TOPLEFT', rail, 'TOPRIGHT', 0, 0)
	content:SetPoint('BOTTOMRIGHT', -1, FOOTER_HEIGHT + 1)
	window.content = content

	if config.searchBox then
		local searchConfig = config.searchBox
		local searchBox = Controls.SearchBox(topbar, searchConfig.placeholder or 'Search...', searchConfig.onSearch, searchConfig.width or 360)
		searchBox:ClearAllPoints()
		searchBox:SetPoint('LEFT', topbar, 'LEFT', sidebarWidth + 16, 0)
		if not searchConfig.width then
			searchBox:SetPoint('RIGHT', titleBar.close, 'LEFT', -16, 0)
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

	local PaintFrameChrome = window.PaintChrome
	function window:PaintChrome()
		PaintFrameChrome(self)
		local look = Theme.window[self:GetMode()]
		versionLabel:SetTextColor(unpack(look.faint))
		Widget.NavSetColors(rail, look.nav)
	end

	function window:SetNavStyle(_, navConfig)
		ClearNav(self)
		local buttons, navHeight
		if config.navStyle == 'rail' then
			buttons, navHeight = Layout.SidebarRail(self, rail, sidebarWidth, navConfig)
		else
			buttons, navHeight = BuildChipRail(self, navConfig)
		end
		self:SetMinimum('nav', 0, navHeight + TOPBAR_HEIGHT + FOOTER_HEIGHT)
		return buttons
	end

	window:ApplyTheme(config.theme)
	return window
end
