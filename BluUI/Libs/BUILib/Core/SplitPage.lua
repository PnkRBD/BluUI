local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Layout = BUILib.Layout
local Theme = BUILib.Theme
local Widget = BUILib.Widget

local SIDE_WIDTH = 400
local COLUMN_GAP = 16
local BLOCK_GAP = 12
local HEAD_HEIGHT = 44
local HEAD_GAP = 20
local ICON_SIZE = 18
local BADGE_SIZE = 44
local BADGE_FILL_ALPHA = 0.16
local BADGE_EDGE_ALPHA = 0.45
local TITLE_X = 58
local ENABLE_GAP = 12
local SEARCH_GAP = 20
local CARD_RADIUS = 8
local INSET_RADIUS = 6
local CARD_PAD = 16
local SELECT_HEIGHT = 34
local SELECT_PAD = 12
local SELECT_ICON = 14
local SELECT_GAP = 12
local SELECT_DIVIDER_INSET = 8
local SELECT_CHEVRON = 9
local SELECT_CHEVRON_GAP = 8
local SELECT_MENU_WIDTH = 220
local QUARTER_TURN = math.pi / 2
local LIVE_DOT = 7
local LIVE_Y = 22
local LIVE_GAP = 10
local STAGE_TOP = 42
local STAGE_INSET = 12
local STAGE_CAPTION = 12
local CAPTION_GAP = 10
local BAR_HEIGHT = 40
local BAR_PAD = 12
local BAR_BOTTOM = 12
local BAR_LEVEL = 30
local THUMB_WIDTH = 32
local THUMB_HEIGHT = 22
local THUMB_GAP = 6
local THUMB_FRAME = 1
local THUMB_IDLE_ALPHA = 0.6
local DOT_TILE = 16
local PREVIEW_MIN = 360
local SCROLL_INSET = 8
local FILL_MARGIN = 16
local LINK_HEIGHT = 20
local WHITE = { 1, 1, 1, 1 }

local Stack = {}

function Stack:Add(item)
	self.items[#self.items + 1] = item
	return item
end

local function Matches(item, query)
	return item.search ~= nil and item.search:find(query, 1, true) ~= nil
end

function Stack:Filter(query, forced)
	local any = false
	for _, item in ipairs(self.items) do
		local shown = forced or query == '' or Matches(item, query)
		if item.Filter then shown = item:Filter(query, shown) or shown end
		item.filtered = not shown
		any = any or shown
	end
	return any
end

function Stack:Measure(width)
	local inner = width - self.left - self.right
	local y, placed = self.top, false
	for _, item in ipairs(self.items) do
		item:SetShown(not item.filtered)
		if not item.filtered then
			if placed then y = y + self.gap end
			local height = item.Measure and item:Measure(inner) or item:GetHeight()
			item:ClearAllPoints()
			item:SetPoint('TOPLEFT', self.left, -y)
			item:SetSize(inner, height)
			y = y + height
			placed = true
		end
	end
	return y + self.bottom
end

local function AccentTint(alpha)
	return function(region)
		local red, green, blue = Theme.GetAccent()
		region:SetVertexColor(red, green, blue, alpha)
	end
end

Layout.TableKitExtensions[#Layout.TableKitExtensions + 1] = function(kit, window)
	function kit.Stack(frame, left, top, right, bottom, gap)
		Mixin(frame, Stack)
		frame.items = {}
		frame.left, frame.top, frame.right, frame.bottom, frame.gap = left, top, right, bottom, gap
		return frame
	end

	function kit.Select(parent, spec)
		local button = CreateFrame('Button', nil, parent)
		button:SetHeight(SELECT_HEIGHT)
		local edge = Widget.DrawOutline(button, INSET_RADIUS, WHITE, 'BACKGROUND', 1)
		window:Paint(edge, 'cardEdge')
		kit.Glyph(button, spec.icon, SELECT_ICON, 'text'):SetPoint('LEFT', SELECT_PAD, 0)
		local x = SELECT_PAD + SELECT_ICON + SELECT_GAP
		local label = kit.Text(button, spec.label, 12, 'text')
		label:SetPoint('LEFT', x, 0)
		local divider = kit.Fill(button, 'cardEdge', 'ARTWORK')
		divider:SetSize(1, SELECT_HEIGHT - SELECT_DIVIDER_INSET * 2)
		divider:SetPoint('LEFT', label, 'RIGHT', SELECT_GAP, 0)
		local value = kit.Text(button, '', 12, 'text')
		value:SetPoint('LEFT', divider, 'RIGHT', SELECT_GAP, 0)
		local chevron = kit.Glyph(button, 'dropdown', SELECT_CHEVRON, 'muted')
		if spec.stretch then
			chevron:SetPoint('RIGHT', -SELECT_PAD, 0)
		else
			chevron:SetPoint('LEFT', value, 'RIGHT', SELECT_CHEVRON_GAP, 0)
		end
		window:Bind(button, function()
			value:SetText(spec.value())
			if spec.stretch then return end
			button:SetWidth(math.ceil(x + label:GetStringWidth() + SELECT_GAP * 2 + 1 + value:GetStringWidth() + SELECT_CHEVRON_GAP + SELECT_CHEVRON + SELECT_PAD))
		end)
		button:SetScript('OnEnter', function()
			window:Paint(edge, 'faint')
			window:Paint(chevron, 'text')
		end)
		button:SetScript('OnLeave', function()
			window:Paint(edge, 'cardEdge')
			window:Paint(chevron, 'muted')
		end)
		button:SetScript('OnClick', function(self)
			chevron:SetRotation(QUARTER_TURN * 2)
			Controls.ContextMenu(spec.items(), {
				anchor = self, width = math.max(self:GetWidth(), SELECT_MENU_WIDTH), offsetY = -4, window = window,
				onClose = function() chevron:SetRotation(0) end,
			})
		end)
		return button
	end
end

local function Header(kit, window, head, spec, onSearch)
	local badge = CreateFrame('Frame', nil, head)
	badge:SetSize(BADGE_SIZE, BADGE_SIZE)
	badge:SetPoint('TOPLEFT')
	local badgeFill, badgeEdge = Widget.DrawCardShape(badge, CARD_RADIUS, WHITE, WHITE, 'ARTWORK', 0, 0)
	window:Paint(badgeFill, AccentTint(BADGE_FILL_ALPHA))
	window:Paint(badgeEdge, AccentTint(BADGE_EDGE_ALPHA))
	kit.Glyph(badge, spec.icon, ICON_SIZE, 'text', 'OVERLAY'):SetPoint('CENTER')
	local title = kit.Text(head, spec.title, 22, 'text')
	title:SetPoint('TOPLEFT', TITLE_X, -1)
	if spec.subtitle then kit.Text(head, spec.subtitle, 12, 'muted'):SetPoint('TOPLEFT', title, 'BOTTOMLEFT') end
	local search = kit.Search(head, spec.placeholder, onSearch)
	search:SetPoint('TOPRIGHT', 0, -(BADGE_SIZE - search:GetHeight()) / 2)
	if not spec.enable then return end
	local switch = kit.Switch(head, spec.enable.get, function(value)
		spec.enable.set(value)
		window:Repaint()
	end)
	switch:SetPoint('RIGHT', search, 'LEFT', -SEARCH_GAP, 0)
	kit.Text(head, 'Enabled', 13, 'text'):SetPoint('RIGHT', switch, 'LEFT', -ENABLE_GAP, 0)
end

local function Cover(texture, aspect, width, height)
	if width <= 0 or height <= 0 then return end
	local view = width / height
	if view < aspect then
		local inset = (1 - view / aspect) / 2
		texture:SetTexCoord(inset, 1 - inset, 0, 1)
	else
		local inset = (1 - aspect / view) / 2
		texture:SetTexCoord(0, 1, inset, 1 - inset)
	end
end

local function Backdrop(window, parent, background, layer)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetAllPoints()
	if background.texture then
		texture:SetTexture(background.texture)
	elseif background.color then
		texture:SetColorTexture(unpack(background.color))
	else
		texture:SetTexture(BUILib.GetLibMedia('dotgrid'), 'REPEAT', 'REPEAT')
		window:Paint(texture, 'dots')
	end
	return texture
end

local function Fit(texture, background, width, height)
	if background.texture then
		Cover(texture, background.aspect, width, height)
	elseif not background.color then
		texture:SetTexCoord(0, width / DOT_TILE, 0, height / DOT_TILE)
	end
end

local function PreviewCard(kit, window, parent, x, width, spec)
	local card = CreateFrame('Frame', nil, parent)
	card:SetPoint('TOPLEFT', x, 0)
	card:SetWidth(width)
	local fill, edge = Widget.DrawCardShape(card, CARD_RADIUS, WHITE, WHITE, 'BACKGROUND', 0, 0)
	window:Paint(fill, 'card')
	window:Paint(edge, 'cardEdge')
	local dot = kit.Disc(card, LIVE_DOT, 'positive')
	dot:SetPoint('CENTER', card, 'TOPLEFT', CARD_PAD + LIVE_DOT / 2, -LIVE_Y)
	kit.Text(card, spec.title:upper(), 10, 'muted'):SetPoint('LEFT', dot, 'RIGHT', LIVE_GAP, 0)

	local stage = CreateFrame('Frame', nil, card)
	stage:SetPoint('TOPLEFT', STAGE_INSET, -STAGE_TOP)
	stage:SetPoint('BOTTOMRIGHT', -STAGE_INSET, STAGE_INSET)
	stage:SetClipsChildren(true)
	local backgrounds = spec.backgrounds or { {} }
	local layers = {}
	for index, background in ipairs(backgrounds) do layers[index] = Backdrop(window, stage, background, 'BACKGROUND') end
	local selected = 1
	local function ShowBackground(index)
		selected = index
		for layerIndex, layer in ipairs(layers) do layer:SetShown(layerIndex == index) end
	end
	ShowBackground(1)
	stage:SetScript('OnSizeChanged', function(_, stageWidth, stageHeight)
		for index, layer in ipairs(layers) do Fit(layer, backgrounds[index], stageWidth, stageHeight) end
	end)

	local bar
	if #backgrounds > 1 then
		bar = CreateFrame('Frame', nil, stage)
		bar:SetFrameLevel(stage:GetFrameLevel() + BAR_LEVEL)
		bar:SetHeight(BAR_HEIGHT)
		bar:SetPoint('BOTTOM', 0, BAR_BOTTOM)
		local barFill, barEdge = Widget.DrawCardShape(bar, CARD_RADIUS, WHITE, WHITE, 'BACKGROUND', 0, 0)
		window:Paint(barFill, 'card')
		window:Paint(barEdge, 'cardEdge')
		local label = kit.Text(bar, 'Background', 12, 'muted')
		label:SetPoint('LEFT', BAR_PAD, 0)
		local thumbs = {}
		local function PaintThumbs()
			for index, thumb in ipairs(thumbs) do
				local active = index == selected
				thumb.frame:SetShown(active)
				thumb:SetAlpha((active or thumb:IsMouseOver()) and 1 or THUMB_IDLE_ALPHA)
			end
		end
		for index, background in ipairs(backgrounds) do
			local thumb = CreateFrame('Button', nil, bar)
			thumb:SetSize(THUMB_WIDTH, THUMB_HEIGHT)
			thumb:SetPoint('LEFT', label, 'RIGHT', BAR_PAD + (index - 1) * (THUMB_WIDTH + THUMB_GAP), 0)
			thumb.frame = kit.Fill(thumb, 'accent', 'BACKGROUND', 0)
			thumb.frame:SetPoint('TOPLEFT', -THUMB_FRAME, THUMB_FRAME)
			thumb.frame:SetPoint('BOTTOMRIGHT', THUMB_FRAME, -THUMB_FRAME)
			kit.Fill(thumb, 'card', 'BACKGROUND', 1):SetAllPoints()
			Fit(Backdrop(window, thumb, background, 'ARTWORK'), background, THUMB_WIDTH, THUMB_HEIGHT)
			thumb:SetScript('OnClick', function()
				ShowBackground(index)
				PaintThumbs()
			end)
			thumb:SetScript('OnEnter', function(self)
				PaintThumbs()
				if background.label then Widget.ShowTip(self, background.label) end
			end)
			thumb:SetScript('OnLeave', function()
				PaintThumbs()
				Widget.HideTip()
			end)
			thumbs[index] = thumb
		end
		window:Bind(bar, function()
			bar:SetWidth(math.ceil(BAR_PAD * 3 + label:GetStringWidth() + #thumbs * THUMB_WIDTH + (#thumbs - 1) * THUMB_GAP))
			PaintThumbs()
		end)
	end

	if spec.caption then
		local caption = kit.Text(stage, spec.caption, 12, 'text')
		caption:SetShadowColor(0, 0, 0, 0.9)
		caption:SetShadowOffset(1, -1)
		if bar then caption:SetPoint('BOTTOM', bar, 'TOP', 0, CAPTION_GAP) else caption:SetPoint('BOTTOM', 0, STAGE_CAPTION) end
	end

	if spec.action then
		local button = CreateFrame('Button', nil, card)
		button:SetHeight(LINK_HEIGHT)
		button:SetPoint('RIGHT', card, 'TOPRIGHT', -CARD_PAD, -LIVE_Y)
		local label = kit.Text(button, spec.action.text, 11, 'muted')
		label:SetPoint('RIGHT')
		window:Bind(button, function() button:SetWidth(math.ceil(label:GetStringWidth())) end)
		button:SetScript('OnEnter', function() window:Paint(label, 'text') end)
		button:SetScript('OnLeave', function() window:Paint(label, 'muted') end)
		button:SetScript('OnClick', spec.action.onClick)
	end

	spec.build(stage, kit)
	return card
end

function Layout.SplitPage(tab, shell, spec)
	local window = shell.window
	local kit = Layout.TableKit(window)
	local width = tab.width
	local mainWidth = width - SIDE_WIDTH - COLUMN_GAP
	local block = CreateFrame('Frame', nil, tab.child)
	block:SetWidth(width)

	local main = kit.Stack(CreateFrame('Frame', nil, block), 0, 0, 0, 0, BLOCK_GAP)
	for _, item in ipairs(spec.build(kit, main, mainWidth)) do main:Add(item) end
	local preview = PreviewCard(kit, window, block, mainWidth + COLUMN_GAP, SIDE_WIDTH, spec.preview)
	if spec.disabled then Layout.DisableWhen(window, spec.disabled, block, { block }):SetAllPoints() end

	local query = ''
	local head = CreateFrame('Frame', nil, tab.pinned)
	head:SetPoint('TOPLEFT')
	head:SetSize(width, HEAD_HEIGHT)
	Header(kit, window, head, spec, function(text)
		if text == query then return end
		query = text
		main:Filter(query)
		kit.Relayout()
	end)
	tab:SetPinnedHeight(HEAD_HEIGHT + HEAD_GAP)
	local Align = Layout.AlignPinned(tab, head, block)

	local function LastShown(stack)
		for index = #stack.items, 1, -1 do
			local item = stack.items[index]
			if not item.filtered then return item end
		end
	end

	local function Resize()
		local height = main:Measure(mainWidth)
		local viewport = tab.frame:GetHeight() - HEAD_HEIGHT - HEAD_GAP - SCROLL_INSET - FILL_MARGIN
		local columns = math.max(height, PREVIEW_MIN, viewport)
		local last = LastShown(main)
		if last and columns > height then last:SetHeight(last:GetHeight() + columns - height) end
		main:ClearAllPoints()
		main:SetPoint('TOPLEFT')
		main:SetSize(mainWidth, columns)
		preview:SetHeight(columns)
		block:SetHeight(columns)
		block.layoutHeight = columns
		BUILib.Defer(function()
			Align()
			tab:Refresh()
		end)
	end
	kit.Relayout = Resize
	tab.frame:HookScript('OnSizeChanged', Resize)
	tab.frame:HookScript('OnShow', Resize)

	Resize()
	Layout.Add(tab, block, -Layout.DEFAULT_PADDING)
	Align()
	tab:Refresh()
end
