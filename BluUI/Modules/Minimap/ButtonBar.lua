local _, BUI = ...

local Pixel = BUI.Pixel
local Drawer = BUI.Drawer
local WoWMinimap = _G.Minimap

local ButtonBar = {}
BUI.MinimapButtonBar = ButtonBar

local LDB_PREFIX = 'LibDBIcon10_'
local ICON_CROP = 0.08
local UNORDERED_BASE = 100000

local ANCHORS = {
	BOTTOM = { START = { 'TOPLEFT', 'BOTTOMLEFT' }, CENTER = { 'TOP', 'BOTTOM' }, END = { 'TOPRIGHT', 'BOTTOMRIGHT' }, horizontal = true,  dirX = 1,  dirY = -1 },
	TOP    = { START = { 'BOTTOMLEFT', 'TOPLEFT' }, CENTER = { 'BOTTOM', 'TOP' }, END = { 'BOTTOMRIGHT', 'TOPRIGHT' }, horizontal = true,  dirX = 1,  dirY = 1  },
	LEFT   = { START = { 'TOPRIGHT', 'TOPLEFT' },   CENTER = { 'RIGHT', 'LEFT' }, END = { 'BOTTOMRIGHT', 'BOTTOMLEFT' }, horizontal = false, dirX = -1, dirY = -1 },
	RIGHT  = { START = { 'TOPLEFT', 'TOPRIGHT' },   CENTER = { 'LEFT', 'RIGHT' }, END = { 'BOTTOMLEFT', 'BOTTOMRIGHT' }, horizontal = false, dirX = 1,  dirY = -1 },
}

local frame
local placed = {}

local function Config()
	return BUI.GetDB().interface.buttonBar
end

local function ButtonLabel(name)
	return (name:gsub('^' .. LDB_PREFIX, ''))
end

local function Included(config, name)
	return name ~= nil and config.excluded[name] ~= true
end

local function OrderKey(config, name, captureIndex)
	local order = config.order
	for index = 1, #order do
		if order[index] == name then return index end
	end
	return UNORDERED_BASE + captureIndex
end

local function SortedCaptured(config, includeExcluded)
	local list = {}
	local keys = {}
	local captured = Drawer.GetButtons()
	for index = 1, #captured do
		local button = captured[index]
		local name = button:GetName()
		if name and (includeExcluded or Included(config, name)) then
			list[#list + 1] = button
			keys[button] = OrderKey(config, name, index)
		end
	end
	table.sort(list, function(left, right) return keys[left] < keys[right] end)
	return list
end

function ButtonBar.PickerEntries()
	local config = Config()
	local entries = {}
	for _, button in ipairs(SortedCaptured(config, true)) do
		local name = button:GetName()
		local icon = button._buiIcon
		entries[#entries + 1] = {
			id = name,
			label = ButtonLabel(name),
			icon = icon and icon:GetTexture(),
			included = Included(config, name),
		}
	end
	return entries
end

function ButtonBar.SetIncluded(name, included)
	Config().excluded[name] = (not included) and true or nil
	ButtonBar.Refresh()
end

function ButtonBar.SetOrder(names)
	local config = Config()
	wipe(config.order)
	for index = 1, #names do config.order[index] = names[index] end
	ButtonBar.Refresh()
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

local function EnsureFrame()
	if frame then return frame end
	frame = CreateFrame('Frame', 'BUI_MinimapButtonBar', UIParent)
	frame:SetFrameStrata('MEDIUM')
	frame:SetFrameLevel(100)
	frame:EnableMouse(false)
	return frame
end

local function PlaceButton(button, size, edge, corner, x, y, background)
	local original = button._buiOriginalFuncs
	local fill = button._buiBarBg
	if not fill then
		fill = button:CreateTexture(nil, 'BACKGROUND', nil, -8)
		fill:SetTexture('Interface\\Buttons\\WHITE8x8')
		fill._buiBarBg = true
		button._buiBarBg = fill
	end
	fill:ClearAllPoints()
	fill:SetPoint('TOPLEFT', button, 'TOPLEFT', edge, -edge)
	fill:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -edge, edge)
	fill:SetVertexColor(background[1], background[2], background[3], background[4])
	fill:Show()
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

local function ReleasePlaced(keep)
	for button in pairs(placed) do
		if not keep or not keep[button] then
			placed[button] = nil
			if button._buiBarBg then button._buiBarBg:Hide() end
			if Drawer.IsCaptured(button) then Drawer.ReturnButton(button) end
		end
	end
end

local function Layout()
	local config = Config()
	if not config.enabled or not frame then return end
	local list = SortedCaptured(config, false)
	local keep = {}
	for index = 1, #list do keep[list[index]] = true end
	ReleasePlaced(keep)

	local count = #list
	local layout = ButtonBar.Arrange(config, count, Pixel.Scale)
	frame:SetSize(layout.width, layout.height)
	frame:ClearAllPoints()
	frame:SetPoint(layout.point, WoWMinimap, layout.relativePoint, layout.x, layout.y)

	local edge = Pixel.PixelSize(1)
	for index = 1, count do
		local button = list[index]
		local slot = layout.slots[index]
		Drawer.Claim(button, 'bar')
		placed[button] = true
		PlaceButton(button, layout.size, edge, layout.corner, slot[1], slot[2], config.background)
	end
	frame:SetShown(count > 0)
end

local QueueLayout = BUI.Dispatcher.New(Layout, 'Minimap.ButtonBar')

function ButtonBar.Refresh()
	if not Config().enabled then
		ButtonBar.Disable()
		return
	end
	EnsureFrame()
	Drawer.SetCaptureWanted(true)
	Layout()
end

function ButtonBar.Disable()
	ReleasePlaced(nil)
	if frame then frame:Hide() end
	Drawer.SetCaptureWanted(false)
end

function ButtonBar.IsEnabled()
	return Config().enabled == true
end

BUI.Events:OnLogin('Minimap.ButtonBar', function()
	Drawer.OnCapture('bar', function()
		if ButtonBar.IsEnabled() then QueueLayout() end
	end)
	Pixel.OnScaleChange('MinimapButtonBar', function()
		if ButtonBar.IsEnabled() then Layout() end
	end)
end)
