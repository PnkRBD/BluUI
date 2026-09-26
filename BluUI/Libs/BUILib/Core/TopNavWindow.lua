local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Widget = BUILib.Widget
local Theme = BUILib.Theme

local EDGE_ACCENT_SCALE = 0.45
local BAR_HEIGHT = 64
local PAGE_WIDTH = 1040
local BRAND_SIZE = 15
local LINK_SIZE = 13
local LINK_GAP = 36
local ACTION_SIZE = 28
local ACTION_ICON_SIZE = 12
local ACTION_GAP = 8
local AVATAR_SIZE = 30
local SIDEBAR_INSET = 16
local SIDEBAR_TOP = 24
local FOOTER_HEIGHT = 56
local FOOTER_GAP = 8
local FOOTER_DOT = 7

local function FooterButton(window, kit, parent, spec)
	local button = CreateFrame('Button', nil, parent)
	window:Fill(button, 'secondary'):SetAllPoints()
	kit.Hover(button)
	local textX = 14
	local dot
	if spec.indicator or spec.roundedIndicator then
		dot = kit.Disc(button, FOOTER_DOT, 'faint')
		dot:SetPoint('LEFT', 12, 0)
		textX = 26
	end
	local label = kit.Text(button, spec.text, 12, 'secondaryText')
	label:SetPoint('LEFT', textX, 0)
	button:SetSize(Widget.EvenSize(textX + label:GetStringWidth() + 14), 30)
	button:SetScript('OnClick', function()
		if spec.callback then spec.callback() end
	end)
	if spec.tooltip then
		button:HookScript('OnEnter', function(self) Widget.ShowTip(self, spec.tooltip) end)
		button:HookScript('OnLeave', Widget.HideTip)
	end
	function button:SetActive(active)
		if dot then window:Paint(dot, active and 'accent' or 'faint') end
		window:Paint(label, active and 'text' or 'secondaryText')
	end
	return button
end

function Layout.TopNavWindow(config)
	local window = Layout.WindowFrame(config)
	local frame = window.frame
	local pageWidth = config.pageWidth or PAGE_WIDTH
	local sidebarWidth = config.sidebarWidth

	function window:ChromeColor(role, theme, mode)
		if role == 'edge' and theme.edgeAccent and not (theme[mode] and theme[mode].edge) then
			local red, green, blue = Theme.GetAccent()
			return { red * EDGE_ACCENT_SCALE, green * EDGE_ACCENT_SCALE, blue * EDGE_ACCENT_SCALE, 1 }
		end
	end

	function window:PaintChrome()
		self:PaintFrame({ self:Color('page') }, { self:Color('edge') })
	end

	local bar = CreateFrame('Frame', nil, frame)
	bar:SetPoint('TOPLEFT', 1, -1)
	bar:SetPoint('TOPRIGHT', -1, -1)
	bar:SetHeight(BAR_HEIGHT)
	window:DragWith(bar)
	window:Fill(bar, 'bar'):SetAllPoints()

	local inner = CreateFrame('Frame', nil, bar)
	inner:SetPoint('TOPLEFT', SIDEBAR_INSET, 0)
	inner:SetPoint('BOTTOMRIGHT', -SIDEBAR_INSET, 0)

	local rule = window:Fill(inner, 'barRule', 'ARTWORK')
	rule:SetPoint('BOTTOMLEFT')
	rule:SetPoint('BOTTOMRIGHT')
	rule:SetHeight(1)

	local avatar = inner:CreateTexture(nil, 'ARTWORK')
	avatar:SetSize(AVATAR_SIZE, AVATAR_SIZE)
	avatar:SetPoint('LEFT')
	if config.icon then
		avatar:SetTexture(config.icon)
	else
		Layout.PlayerPortrait(avatar)
	end
	avatar:SetMask(BUILib.GetLibMedia('circle_mask'))

	local brand = window:Text(inner, Widget.StripColorCodes(config.title or 'BUILib'), BRAND_SIZE, 'barText')
	brand:SetPoint('LEFT', avatar, 'RIGHT', 10, 0)

	local function ActionButton(action)
		local button = CreateFrame('Button', nil, inner)
		button:SetSize(ACTION_SIZE, ACTION_SIZE)
		local disc = button:CreateTexture(nil, 'BACKGROUND')
		disc:SetTexture(BUILib.GetLibMedia('smoothdisc'))
		disc:SetAllPoints()
		window:Paint(disc, 'barButton')
		local icon = button:CreateTexture(nil, 'ARTWORK')
		icon:SetTexture(BUILib.GetLibMedia(action.icon))
		icon:SetSize(ACTION_ICON_SIZE, ACTION_ICON_SIZE)
		icon:SetPoint('CENTER')
		window:Paint(icon, 'barIcon')
		local dynamicTip = type(action.tooltip) == 'function'
		local function ShowTip()
			Widget.ShowTip(button, dynamicTip and action.tooltip() or action.tooltip)
		end
		button:SetScript('OnEnter', function()
			window:Paint(icon, 'barText')
			ShowTip()
		end)
		button:SetScript('OnLeave', function()
			window:Paint(icon, 'barIcon')
			Widget.HideTip()
		end)
		button:SetScript('OnClick', function()
			action.onClick()
			if dynamicTip then ShowTip() end
		end)
		return button
	end

	local actions = {
		{
			icon = 'glow',
			tooltip = function() return window:GetMode() == 'dark' and 'Light mode' or 'Dark mode' end,
			onClick = function() window:SetMode(window:GetMode() == 'dark' and 'light' or 'dark') end,
		},
	}
	for _, action in ipairs(config.actions or {}) do actions[#actions + 1] = action end
	actions[#actions + 1] = { icon = 'x', tooltip = 'Close', onClick = function() frame:Hide() end }

	local anchor
	for index = #actions, 1, -1 do
		local button = ActionButton(actions[index])
		if anchor then
			button:SetPoint('RIGHT', anchor, 'LEFT', -ACTION_GAP, 0)
		else
			button:SetPoint('RIGHT')
		end
		anchor = button
	end

	local links = CreateFrame('Frame', nil, inner)
	links:SetPoint('TOP')
	links:SetPoint('BOTTOM')
	links:SetWidth(1)

	local sidebar
	if sidebarWidth then
		sidebar = CreateFrame('Frame', nil, frame)
		sidebar:SetPoint('TOPLEFT', 1, -(BAR_HEIGHT + 1))
		sidebar:SetPoint('BOTTOMLEFT', 1, 1)
		sidebar:SetWidth(sidebarWidth)
		window:Fill(sidebar, 'sidebar'):SetAllPoints()
		local edge = window:Fill(sidebar, 'sidebarEdge', 'ARTWORK')
		edge:SetPoint('TOPRIGHT')
		edge:SetPoint('BOTTOMRIGHT')
		edge:SetWidth(1)
		window.sidebar = sidebar
	end

	local function BuildLinks(navConfig)
		local buttons, x = {}, 0
		for index, pageID in ipairs(navConfig.pageOrder) do
			local page = navConfig.pages[pageID]
			if not page.hidden then
				local link = CreateFrame('Button', nil, links)
				local label = window:Text(link, Widget.StripColorCodes(page.buttonText or page.title or pageID), LINK_SIZE, 'barMuted')
				label:SetPoint('CENTER')
				link:SetSize(math.ceil(label:GetStringWidth()), BAR_HEIGHT)
				link:SetPoint('LEFT', x, 0)
				x = x + link:GetWidth() + LINK_GAP
				local selected = false
				function link:SetSelected(isSelected)
					selected = isSelected
					window:Paint(label, isSelected and 'barText' or 'barMuted')
				end
				link:SetScript('OnEnter', function() window:Paint(label, 'barText') end)
				link:SetScript('OnLeave', function() window:Paint(label, selected and 'barText' or 'barMuted') end)
				link:SetScript('OnClick', function() navConfig.showPage(index) end)
				window.navFrames[#window.navFrames + 1] = link
				buttons[index] = link
			end
		end
		links:SetWidth(math.max(1, x - LINK_GAP))
		return buttons
	end

	function window:SetNavStyle(_, navConfig)
		self:ReleaseNav()
		if not sidebar then return BuildLinks(navConfig) end
		local rail, buttons = Layout.NavRail(self, sidebar, sidebarWidth - SIDEBAR_INSET * 2, navConfig)
		rail.frame:SetPoint('TOPLEFT', SIDEBAR_INSET, -SIDEBAR_TOP)
		self.navFrames[#self.navFrames + 1] = rail.frame
		self:SetMinimum('nav', 0, rail.height + SIDEBAR_TOP + BAR_HEIGHT + 24)
		return buttons
	end

	local footerConfig = config.footerButtons or {}
	local footerHeight = #footerConfig > 0 and FOOTER_HEIGHT or 0
	if footerHeight > 0 then
		local footer = CreateFrame('Frame', nil, frame)
		footer:SetPoint('BOTTOMLEFT', (sidebarWidth or 0) + 1, 1)
		footer:SetPoint('BOTTOMRIGHT', -1, 1)
		footer:SetHeight(FOOTER_HEIGHT)
		local rule = window:Fill(footer, 'rule', 'ARTWORK')
		rule:SetPoint('TOPLEFT', SIDEBAR_INSET, 0)
		rule:SetPoint('TOPRIGHT', -SIDEBAR_INSET, 0)
		rule:SetHeight(1)
		if config.version then window:Text(footer, 'v' .. config.version, 12, 'faint'):SetPoint('LEFT', SIDEBAR_INSET, 0) end
		local kit = Layout.TableKit(window)
		window.footerButtons = {}
		local anchor
		for index = #footerConfig, 1, -1 do
			local spec = footerConfig[index]
			local button = FooterButton(window, kit, footer, spec)
			if anchor then
				button:SetPoint('RIGHT', anchor, 'LEFT', -FOOTER_GAP, 0)
			else
				button:SetPoint('RIGHT', -SIDEBAR_INSET, 0)
			end
			window.footerButtons[spec.key or spec.text] = button
			anchor = button
		end
		window.footerLeftmost = anchor
	end

	local content = CreateFrame('Frame', nil, frame)
	content:SetPoint('TOPLEFT', (sidebarWidth or 0) + 1, -(BAR_HEIGHT + 1))
	content:SetPoint('BOTTOMRIGHT', -1, footerHeight + 1)
	window.content = content

	window:SetMinimum('page', pageWidth + 48 + (sidebarWidth or 0), BAR_HEIGHT + footerHeight + 240)
	function window:SetContentMinSize(width, height)
		self:SetMinimum('content', width + 2 + (sidebarWidth or 0), height + BAR_HEIGHT + footerHeight + 2)
	end

	window:ApplyTheme(config.theme)
	return window
end
