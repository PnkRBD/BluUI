local _, BUI = ...

local Pixel = BUI.Pixel
local WoWMinimap = _G.Minimap

local ButtonBar = {}
BUI.MinimapButtonBar = ButtonBar

local ICON_CROP = 0.08

local ANCHORS = {
	BOTTOM = { START = { 'TOPLEFT', 'BOTTOMLEFT' }, CENTER = { 'TOP', 'BOTTOM' }, END = { 'TOPRIGHT', 'BOTTOMRIGHT' }, horizontal = true,  dirX = 1,  dirY = -1 },
	TOP    = { START = { 'BOTTOMLEFT', 'TOPLEFT' }, CENTER = { 'BOTTOM', 'TOP' }, END = { 'BOTTOMRIGHT', 'TOPRIGHT' }, horizontal = true,  dirX = 1,  dirY = 1  },
	LEFT   = { START = { 'TOPRIGHT', 'TOPLEFT' },   CENTER = { 'RIGHT', 'LEFT' }, END = { 'BOTTOMRIGHT', 'BOTTOMLEFT' }, horizontal = false, dirX = -1, dirY = -1 },
	RIGHT  = { START = { 'TOPLEFT', 'TOPRIGHT' },   CENTER = { 'LEFT', 'RIGHT' }, END = { 'BOTTOMLEFT', 'BOTTOMRIGHT' }, horizontal = false, dirX = 1,  dirY = -1 },
}

local frame
local tiles = {}

local function Config()
	return BUI.GetDB().interface.buttonBar
end

function ButtonBar.Arrange(config, count, measure)
	local anchor = ANCHORS[config.side]
	local size, gap = measure(config.size), measure(config.spacing)
	local perLine = config.perLine > 0 and config.perLine or math.max(1, count)
	local lineCount = math.min(count, perLine)
	local crossCount = math.ceil(count / perLine)
	local lineExtent = math.max(1, lineCount * size + (lineCount - 1) * gap)
	local crossExtent = math.max(1, crossCount * size + (crossCount - 1) * gap)
	local mapGap = measure(config.gap)
	local points = anchor[config.align]
	local layout = {
		size = size,
		width = anchor.horizontal and lineExtent or crossExtent,
		height = anchor.horizontal and crossExtent or lineExtent,
		point = points[1],
		relativePoint = points[2],
		x = measure(config.offsetX) + ((config.side == 'LEFT' and -mapGap) or (config.side == 'RIGHT' and mapGap) or 0),
		y = measure(config.offsetY) + ((config.side == 'TOP' and mapGap) or (config.side == 'BOTTOM' and -mapGap) or 0),
		corner = (anchor.dirY == 1 and 'BOTTOM' or 'TOP') .. (anchor.dirX == -1 and 'RIGHT' or 'LEFT'),
		slots = {},
	}
	local step = size + gap
	for index = 1, count do
		local line, cross = (index - 1) % perLine, math.floor((index - 1) / perLine)
		local x, y = line * step, cross * step
		if not anchor.horizontal then x, y = y, x end
		layout.slots[index] = { x * anchor.dirX, y * anchor.dirY }
	end
	return layout
end

local function Tile(index)
	local tile = tiles[index]
	if not tile then
		tile = frame:CreateTexture(nil, 'BACKGROUND')
		tile:SetTexture('Interface\\Buttons\\WHITE8x8')
		tiles[index] = tile
	end
	return tile
end

local function PlaceButton(button, size, edge, corner, x, y)
	local original = button._buiOriginalFuncs
	original.SetParent(button, frame)
	original.SetScale(button, 1)
	original.SetSize(button, size, size)
	original.ClearAllPoints(button)
	original.SetPoint(button, corner, frame, corner, x, y)
	button:SetFrameStrata('MEDIUM')
	button:SetFrameLevel(frame:GetFrameLevel() + 2)
	button:SetAlpha(1)
	button:Show()

	local icon = button._buiIcon
	if icon then
		icon:ClearAllPoints()
		icon:SetPoint('TOPLEFT', button, 'TOPLEFT', edge, -edge)
		icon:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -edge, edge)
		icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
		icon:Show()
	end
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if highlight then
		highlight:ClearAllPoints()
		highlight:SetPoint('TOPLEFT', button, 'TOPLEFT', edge, -edge)
		highlight:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -edge, edge)
	end
	local border = button._buiBorder
	border:ClearAllPoints()
	border:SetAllPoints(button)
	Pixel.ApplyBorder(border, 1, 0, 0, 0, 1)
	border:Show()
end

function ButtonBar.Show()
	if frame then return end
	frame = CreateFrame('Frame', 'BUI_MinimapButtonBar', UIParent)
	frame:SetFrameStrata('MEDIUM')
	frame:SetFrameLevel(100)
	frame:EnableMouse(false)
end

function ButtonBar.Hide()
	frame:Hide()
end

function ButtonBar.Layout(list)
	local config = Config()
	local count = #list
	local layout = ButtonBar.Arrange(config, count, Pixel.Scale)
	frame:SetSize(layout.width, layout.height)
	frame:ClearAllPoints()
	frame:SetPoint(layout.point, WoWMinimap, layout.relativePoint, layout.x, layout.y)

	local edge = Pixel.PixelSize(1)
	local background = config.background
	for index = 1, count do
		local button = list[index]
		local slot = layout.slots[index]
		PlaceButton(button, layout.size, edge, layout.corner, slot[1], slot[2])
		local tile = Tile(index)
		tile:ClearAllPoints()
		tile:SetPoint('TOPLEFT', button, 'TOPLEFT', edge, -edge)
		tile:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -edge, edge)
		tile:SetVertexColor(background[1], background[2], background[3], background[4])
		tile:Show()
	end
	for index = count + 1, #tiles do tiles[index]:Hide() end
	frame:SetShown(count > 0)
end

BUI.AddonButtons.Register('BAR', ButtonBar)
