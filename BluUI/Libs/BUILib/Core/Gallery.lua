local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Widget = BUILib.Widget

local PAD = 24
local GAP = 12
local TILE_WIDTH = 120
local TILE_HEIGHT = 72
local TILE_RADIUS = 6
local LABEL_HEIGHT = 30
local HEADER_GAP = 8
local TILES_GAP = 20
local BUTTON_GAP = 10
local LEFT_GAP = 40

local Gallery = {}
Gallery.__index = Gallery

function Gallery:Refresh()
	for _, tile in ipairs(self.tiles) do
		local picked = tile.spec.selected ~= nil and tile.spec.selected() == true
		self.window:Paint(tile.edge, picked and 'accent' or 'rule')
		self.window:Paint(tile.label, picked and 'text' or 'muted')
		if tile.spec.refresh then tile.spec.refresh(tile.frame, picked) end
	end
end

function Gallery:Layout(y, query)
	local shown = {}
	for _, tile in ipairs(self.tiles) do
		local match = query == '' or tile.search:find(query, 1, true) ~= nil
		tile.frame:SetShown(match)
		if match then shown[#shown + 1] = tile end
	end
	if #shown == 0 and query ~= '' then
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
	local columns = math.max(1, math.floor((self.width + GAP) / (self.tileWidth + GAP)))
	local tileWidth = math.floor((self.width - GAP * (columns - 1)) / columns)
	local top = PAD + headerHeight + TILES_GAP
	for index, tile in ipairs(shown) do
		local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
		tile.frame:ClearAllPoints()
		tile.frame:SetPoint('TOPLEFT', column * (tileWidth + GAP), -(top + row * (self.tileHeight + GAP)))
		tile.frame:SetWidth(tileWidth)
	end
	local rows = math.ceil(#shown / columns)
	local height = top + rows * (self.tileHeight + GAP) - GAP + PAD + 1
	self.frame:ClearAllPoints()
	self.frame:SetPoint('TOPLEFT', 0, -y)
	self.frame:SetHeight(height)
	self.frame:Show()
	return y + height
end

Layout.TableKitExtensions[#Layout.TableKitExtensions + 1] = function(kit, window)
	function kit.Gallery(parent, width, spec)
		local frame = CreateFrame('Frame', nil, parent)
		frame:SetWidth(width)
		local gallery = setmetatable({
			window = window, frame = frame, width = width, tiles = {}, buttons = {},
			tileWidth = spec.tileWidth or TILE_WIDTH, tileHeight = spec.tileHeight or TILE_HEIGHT,
		}, Gallery)

		gallery.title = kit.Text(frame, spec.title, 13, 'text')
		gallery.title:SetPoint('TOPLEFT', 0, -(PAD + 2))
		if spec.description then
			gallery.description = kit.Text(frame, spec.description, 12, 'muted')
			gallery.description:SetWordWrap(true)
			gallery.description:SetSpacing(4)
			gallery.description:SetPoint('TOPLEFT', gallery.title, 'BOTTOMLEFT', 0, -HEADER_GAP)
		end
		for _, buttonSpec in ipairs(spec.buttons or {}) do
			gallery.buttons[#gallery.buttons + 1] = kit.Button(frame, buttonSpec.text, buttonSpec.style, buttonSpec.onClick, buttonSpec.icon)
		end
		for index = #gallery.buttons - 1, 1, -1 do
			gallery.buttons[index]:SetPoint('RIGHT', gallery.buttons[index + 1], 'LEFT', -BUTTON_GAP, 0)
		end

		local contentHeight = gallery.tileHeight - LABEL_HEIGHT
		for _, tileSpec in ipairs(spec.tiles) do
			local tile = CreateFrame('Button', nil, frame)
			tile:SetSize(gallery.tileWidth, gallery.tileHeight)
			for _, piece in ipairs(Widget.DrawRoundedRect(tile, TILE_RADIUS, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)) do window:Paint(piece, 'input') end
			local edge = Widget.DrawOutline(tile, TILE_RADIUS, { 1, 1, 1, 1 }, 'BACKGROUND', 2, 0)
			kit.Hover(tile)
			local content = CreateFrame('Frame', nil, tile)
			content:SetPoint('TOPLEFT', 0, 0)
			content:SetPoint('TOPRIGHT', 0, 0)
			content:SetHeight(contentHeight)
			local label = kit.Text(tile, tileSpec.label, 11, 'muted')
			label:SetPoint('BOTTOMLEFT', 10, tileSpec.sub and 16 or 10)
			label:SetPoint('BOTTOMRIGHT', -10, tileSpec.sub and 16 or 10)
			label:SetWordWrap(false)
			if tileSpec.sub then
				local sub = kit.Text(tile, tileSpec.sub, 9, 'faint')
				sub:SetPoint('BOTTOMLEFT', 10, 5)
				sub:SetPoint('BOTTOMRIGHT', -10, 5)
				sub:SetWordWrap(false)
			end
			if tileSpec.build then tileSpec.build(content, contentHeight, tile) end
			tile:SetScript('OnClick', function(self) tileSpec.onClick(self) end)
			gallery.tiles[#gallery.tiles + 1] = { frame = tile, edge = edge, label = label, spec = tileSpec, search = (tileSpec.search or tileSpec.label):lower() }
		end

		local rule = kit.DottedRule(frame)
		rule:SetPoint('BOTTOMLEFT')
		rule:SetPoint('BOTTOMRIGHT')
		window:Bind(frame, function() gallery:Refresh() end)
		return gallery
	end
end
