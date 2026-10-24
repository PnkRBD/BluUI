local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Widget = BUILib.Widget

local PAD = 24
local GAP = 16
local MIN_CARD = 280
local CARD_HEIGHT = 128
local CARD_RADIUS = 8
local CARD_PAD = 16
local TITLE_Y = 16
local SUB_Y = 40
local NOTE_Y = 58
local FOOTER_Y = 16
local STATUS_LIFT = 7
local MENU_SIZE = 22
local MENU_INSET = 10
local BLANK_GLYPH = 18
local BLANK_LIFT = 18
local HEADER_GAP = 8
local CARDS_GAP = 20
local BUTTON_GAP = 10
local LEFT_GAP = 40

local Deck = {}
Deck.__index = Deck

function Deck:Refresh()
	for _, card in ipairs(self.cards) do
		self.window:Paint(card.edge, card.spec.active and 'accent' or 'cardEdge')
	end
end

function Deck:Layout(y, query)
	local shown = {}
	for _, card in ipairs(self.cards) do
		local match = query == '' or card.search:find(query, 1, true) ~= nil
		card.frame:SetShown(match)
		if match then shown[#shown + 1] = card.frame end
	end
	if self.blank then
		self.blank:SetShown(query == '')
		if query == '' then shown[#shown + 1] = self.blank end
	end
	if #shown == 0 then
		self.frame:Hide()
		return y
	end
	local buttonsWidth = 0
	for _, button in ipairs(self.buttons) do buttonsWidth = buttonsWidth + button:GetWidth() + BUTTON_GAP end
	local headerHeight = 2 + math.ceil(self.title:GetStringHeight())
	if self.description then
		self.description:SetWidth(self.width - buttonsWidth - LEFT_GAP)
		headerHeight = headerHeight + HEADER_GAP + math.ceil(self.description:GetStringHeight())
	end
	local rightmost = self.buttons[#self.buttons]
	if rightmost then
		rightmost:ClearAllPoints()
		rightmost:SetPoint('BOTTOMRIGHT', self.frame, 'TOPRIGHT', 0, -(PAD + headerHeight))
	end
	local columns = math.max(1, math.floor((self.width + GAP) / (MIN_CARD + GAP)))
	local cardWidth = math.floor((self.width - GAP * (columns - 1)) / columns)
	local top = PAD + headerHeight + CARDS_GAP
	for index, frame in ipairs(shown) do
		local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
		frame:ClearAllPoints()
		frame:SetPoint('TOPLEFT', column * (cardWidth + GAP), -(top + row * (CARD_HEIGHT + GAP)))
		frame:SetWidth(cardWidth)
	end
	local rows = math.ceil(#shown / columns)
	local height = top + rows * (CARD_HEIGHT + GAP) - GAP + PAD + 1
	self.frame:ClearAllPoints()
	self.frame:SetPoint('TOPLEFT', 0, -y)
	self.frame:SetHeight(height)
	self.frame:Show()
	return y + height
end

local function Card(kit, window, parent, spec)
	local frame = CreateFrame('Frame', nil, parent)
	frame:SetSize(MIN_CARD, CARD_HEIGHT)
	local fill, edge = Widget.DrawCardShape(frame, CARD_RADIUS, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
	window:Paint(fill, 'card')

	local title = kit.Text(frame, spec.name, 14, 'text')
	title:SetPoint('TOPLEFT', CARD_PAD, -TITLE_Y)
	title:SetPoint('RIGHT', -(CARD_PAD + MENU_SIZE + 8), 0)
	title:SetWordWrap(false)

	local sub = kit.Text(frame, spec.sub, 11, 'muted')
	sub:SetPoint('TOPLEFT', CARD_PAD, -SUB_Y)
	sub:SetPoint('RIGHT', -CARD_PAD, 0)
	sub:SetWordWrap(false)

	if spec.note then
		local note = kit.Text(frame, spec.note, 11, 'faint')
		note:SetPoint('TOPLEFT', CARD_PAD, -NOTE_Y)
		note:SetPoint('RIGHT', -CARD_PAD, 0)
		note:SetWordWrap(false)
	end

	if spec.active then
		kit.Status(frame, spec.activeText):SetPoint('BOTTOMLEFT', CARD_PAD, FOOTER_Y + STATUS_LIFT)
	elseif spec.onUse then
		kit.Button(frame, spec.useText, 'control', spec.onUse):SetPoint('BOTTOMLEFT', CARD_PAD, FOOTER_Y)
	end

	if spec.onMenu then
		local menu
		menu = kit.IconButton(frame, 'more', spec.menuTip, function() spec.onMenu(menu) end)
		menu:SetPoint('TOPRIGHT', -MENU_INSET, -MENU_INSET)
	end
	return frame, edge
end

local function Blank(kit, window, parent, spec)
	local frame = CreateFrame('Button', nil, parent)
	frame:SetSize(MIN_CARD, CARD_HEIGHT)
	window:Paint(Widget.DrawOutline(frame, CARD_RADIUS, { 1, 1, 1, 1 }, 'BACKGROUND', 1, 0), 'cardEdge')
	kit.Hover(frame)
	local glyph = kit.Glyph(frame, 'plus', BLANK_GLYPH, 'muted')
	glyph:SetPoint('CENTER', 0, BLANK_LIFT)
	local label = kit.Text(frame, spec.label, 12, 'text')
	label:SetPoint('TOP', glyph, 'BOTTOM', 0, -10)
	if spec.sub then
		kit.Text(frame, spec.sub, 11, 'faint'):SetPoint('TOP', label, 'BOTTOM', 0, -6)
	end
	frame:SetScript('OnClick', function(self) spec.onClick(self) end)
	return frame
end

Layout.TableKitExtensions[#Layout.TableKitExtensions + 1] = function(kit, window)
	function kit.Deck(parent, width, spec)
		local frame = CreateFrame('Frame', nil, parent)
		frame:SetWidth(width)
		local deck = setmetatable({ window = window, frame = frame, width = width, cards = {}, buttons = {} }, Deck)

		deck.title = kit.Text(frame, spec.title, 13, 'text')
		deck.title:SetPoint('TOPLEFT', 0, -(PAD + 2))
		if spec.description then
			deck.description = kit.Text(frame, spec.description, 12, 'muted')
			deck.description:SetWordWrap(true)
			deck.description:SetSpacing(4)
			deck.description:SetPoint('TOPLEFT', deck.title, 'BOTTOMLEFT', 0, -HEADER_GAP)
		end
		for _, buttonSpec in ipairs(spec.buttons or {}) do
			deck.buttons[#deck.buttons + 1] = kit.Button(frame, buttonSpec.text, buttonSpec.style, buttonSpec.onClick, buttonSpec.icon)
		end
		for index = #deck.buttons - 1, 1, -1 do
			deck.buttons[index]:SetPoint('RIGHT', deck.buttons[index + 1], 'LEFT', -BUTTON_GAP, 0)
		end

		for _, cardSpec in ipairs(spec.cards) do
			local card, edge = Card(kit, window, frame, cardSpec)
			deck.cards[#deck.cards + 1] = { frame = card, edge = edge, spec = cardSpec, search = (cardSpec.search or cardSpec.name):lower() }
		end
		if spec.blank then deck.blank = Blank(kit, window, frame, spec.blank) end

		local rule = kit.DottedRule(frame)
		rule:SetPoint('BOTTOMLEFT')
		rule:SetPoint('BOTTOMRIGHT')
		window:Bind(frame, function() deck:Refresh() end)
		return deck
	end
end
