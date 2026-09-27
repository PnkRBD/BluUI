local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Widget = BUILib.Widget
local Theme = BUILib.Theme

local BAR_HEIGHT = Layout.TITLE_BAR_HEIGHT
local FOOTER_HEIGHT = Layout.FOOTER_HEIGHT
local PAGE_WIDTH = 1040
local LINK_SIZE = 13
local LINK_GAP = 36
local INSET = 16
local FOOTER_GAP = 8
local INDICATOR_SIZE = 8
local BAR_ROLES = { bar = true, barText = true, barIcon = true }

function Layout.FlatButton(window, parent, spec)
	local kit = Layout.TableKit(window)
	local button = CreateFrame('Button', nil, parent)
	window:Fill(button, 'secondary'):SetAllPoints()
	kit.Hover(button)
	local textX = 14
	local dot
	if spec.indicator or spec.roundedIndicator then
		dot = kit.Fill(button, 'faint', 'OVERLAY')
		dot:SetSize(INDICATOR_SIZE, INDICATOR_SIZE)
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

	local BaseChromeColor = window.ChromeColor
	function window:ChromeColor(role, mode)
		if BAR_ROLES[role] and not self:Override(role, mode) then return Theme.palettes[mode][role] end
		return BaseChromeColor(self, role, mode)
	end

	local bar = Layout.TitleBar(window, config).frame

	local links = CreateFrame('Frame', nil, bar)
	links:SetPoint('TOP')
	links:SetPoint('BOTTOM')
	links:SetWidth(1)

	local footerConfig = config.footerButtons or {}
	local footerHeight = #footerConfig > 0 and FOOTER_HEIGHT or 0

	local sidebar
	if sidebarWidth then
		sidebar = CreateFrame('Frame', nil, frame)
		sidebar:SetPoint('TOPLEFT', 1, -(BAR_HEIGHT + 1))
		sidebar:SetPoint('BOTTOMLEFT', 1, 1)
		sidebar:SetWidth(sidebarWidth)
		window:Fill(sidebar, 'sidebar'):SetAllPoints()
		local edge = window:Fill(sidebar, 'sidebarEdge', 'ARTWORK')
		edge:SetPoint('TOPRIGHT', 0, -INSET)
		edge:SetPoint('BOTTOMRIGHT', 0, footerHeight + INSET)
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
		local buttons, navHeight = Layout.SidebarRail(self, sidebar, sidebarWidth, navConfig)
		self:SetMinimum('nav', 0, navHeight + BAR_HEIGHT + FOOTER_HEIGHT)
		return buttons
	end

	if footerHeight > 0 then
		local footer = CreateFrame('Frame', nil, frame)
		footer:SetPoint('BOTTOMLEFT', (sidebarWidth or 0) + 1, 1)
		footer:SetPoint('BOTTOMRIGHT', -1, 1)
		footer:SetHeight(FOOTER_HEIGHT)
		local footerRule = window:Fill(footer, 'rule', 'ARTWORK')
		footerRule:SetPoint('TOPLEFT', INSET, 0)
		footerRule:SetPoint('TOPRIGHT', -INSET, 0)
		footerRule:SetHeight(1)
		if config.version then window:Text(footer, 'v' .. config.version, 12, 'faint'):SetPoint('LEFT', INSET, 0) end
		window.footerButtons = {}
		local anchor
		for index = #footerConfig, 1, -1 do
			local spec = footerConfig[index]
			local button = Layout.FlatButton(window, footer, spec)
			if anchor then
				button:SetPoint('RIGHT', anchor, 'LEFT', -FOOTER_GAP, 0)
			else
				button:SetPoint('RIGHT', -INSET, 0)
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

	Layout.ReservePage(window, pageWidth, sidebarWidth or 0, footerHeight)
	function window:SetContentMinSize(width, height)
		self:SetMinimum('content', width + 2 + (sidebarWidth or 0), height + BAR_HEIGHT + footerHeight + 2)
	end

	window:ApplyTheme(config.theme)
	return window
end
