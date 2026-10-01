local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Widget = BUILib.Widget

local PAD = 10
local CELL_INSET = 8
local CELL_HEIGHT = 36
local MIN_CELL = 190
local SWITCH_X = 12
local LABEL_X = 62
local LABEL_INSET = 6
local CAPTION_HEIGHT = 28
local CAPTION_Y = 10
local PLAIN_ROW = 44
local CONTROL_GAP = 12
local ICON_SIZE = 24
local DRAG_ROW = 44
local DRAG_TITLE_X = 44
local GRABBER_SIZE = 12
local DRAG_ALPHA = 0.35
local SLIDE_TIME = 0.16

Layout.DRAG_TITLE_X = DRAG_TITLE_X

local Section = Layout.TableSection
local Board = setmetatable({}, { __index = Section })
Board.__index = Board

function Board:AddCaption(text)
	local kit = self.kit
	local caption = Section.AddRow(self, '')
	caption:SetHeight(CAPTION_HEIGHT)
	self.rows[#self.rows].kind = 'caption'
	kit.Text(caption, text:upper(), 9, 'faint'):SetPoint('TOPLEFT', kit.ROW_INSET, -CAPTION_Y)
	return caption
end

function Board:AddSwitch(label, get, set, tip, room)
	local kit = self.kit
	local cell = CreateFrame('Button', nil, self.panel)
	cell:SetHeight(CELL_HEIGHT)
	kit.Hover(cell)
	local switch = kit.Switch(cell, get, set)
	switch:SetPoint('LEFT', SWITCH_X, 0)
	switch.toggle:EnableMouse(false)
	cell.label = kit.Text(cell, label, 12, 'text')
	cell.label:SetPoint('LEFT', LABEL_X, 0)
	cell.label:SetPoint('RIGHT', -(LABEL_INSET + (room or 0)), 0)
	cell.label:SetWordWrap(false)
	cell:SetScript('OnClick', function() switch.toggle:Click() end)
	if tip then
		cell:HookScript('OnEnter', function(self) Widget.ShowTip(self, tip) end)
		cell:HookScript('OnLeave', Widget.HideTip)
	end
	self.rows[#self.rows + 1] = { kind = 'cell', frame = cell, search = label:lower() }
	return switch, cell
end

function Board:AddRow(name, sub, room)
	local kit = self.kit
	local row = Section.AddRow(self, sub and (name .. ' ' .. sub) or name)
	if not sub then row:SetHeight(PLAIN_ROW) end
	kit.RowTitle(row, name, sub, kit.ROW_INSET, room and (self.panelWidth - kit.ROW_INSET * 2 - room - CONTROL_GAP))
	return row
end

function Board:AddTools(name, sub, tools, after, icon)
	local kit = self.kit
	local row = Section.AddRow(self, sub and (name .. ' ' .. sub) or name)
	local x = kit.ROW_INSET
	if icon then
		local texture = row:CreateTexture(nil, 'ARTWORK')
		texture:SetSize(ICON_SIZE, ICON_SIZE)
		texture:SetPoint('LEFT', x, 0)
		if type(icon) == 'function' then
			icon(texture)
		else
			texture:SetTexture(icon)
			texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		row.icon = texture
		x = x + ICON_SIZE + CONTROL_GAP
	end
	local title, subtitle = kit.RowTitle(row, name, sub, x)
	local placer = kit.Tools(row, tools, after)
	local textWidth = self.panelWidth - x - kit.ROW_INSET - CONTROL_GAP
	row.tools = {
		widths = placer.widths,
		Place = function(slots)
			local width = textWidth - placer.Place(slots)
			title:SetWidth(width)
			if subtitle then subtitle:SetWidth(width) end
		end,
	}
	row.controls = placer.controls
	return row
end

local function DragGhost(board)
	local drag = board.drag
	if drag.ghost then return drag.ghost end
	local kit = board.kit
	local ghost = CreateFrame('Frame', nil, board.panel)
	ghost:SetFrameLevel(board.panel:GetFrameLevel() + 10)
	ghost:SetSize(board.panelWidth, DRAG_ROW)
	kit.Fill(ghost, 'control'):SetAllPoints()
	local edge = kit.Fill(ghost, 'accent', 'ARTWORK', 1)
	edge:SetPoint('TOPLEFT')
	edge:SetPoint('BOTTOMLEFT')
	edge:SetWidth(2)
	kit.Glyph(ghost, 'grabber', GRABBER_SIZE, 'text'):SetPoint('LEFT', kit.ROW_INSET, 0)
	ghost.icon = ghost:CreateTexture(nil, 'ARTWORK')
	ghost.icon:SetSize(ICON_SIZE, ICON_SIZE)
	ghost.icon:SetPoint('LEFT', DRAG_TITLE_X, 0)
	ghost.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	ghost.label = kit.Text(ghost, '', 12, 'text')
	ghost:Hide()
	drag.ghost = ghost
	return ghost
end

local function DragTextX(icon)
	return icon and (DRAG_TITLE_X + ICON_SIZE + CONTROL_GAP) or DRAG_TITLE_X
end

local function OffsetOf(frame)
	local _, _, _, _, y = frame:GetPoint(1)
	return y
end

local function PlaceAt(board, frame, y)
	frame:ClearAllPoints()
	frame:SetPoint('TOPLEFT', board.panel, 'TOPLEFT', 0, y)
end

local function FinishSlide(board, frame)
	local slide = board.drag.slides[frame]
	board.drag.slides[frame] = nil
	PlaceAt(board, frame, slide.to)
	if slide.done then slide.done() end
end

local function RunSlides(board, elapsed)
	local slides = board.drag.slides
	for frame, slide in pairs(slides) do
		slide.elapsed = slide.elapsed + elapsed
		if slide.elapsed >= SLIDE_TIME then
			FinishSlide(board, frame)
		else
			local progress = 1 - (1 - slide.elapsed / SLIDE_TIME) ^ 3
			PlaceAt(board, frame, slide.from + (slide.to - slide.from) * progress)
		end
	end
	if not next(slides) then board.drag.animator:SetScript('OnUpdate', nil) end
end

local function Slide(board, frame, from, to, done)
	local drag = board.drag
	drag.slides[frame] = { from = from, to = to, elapsed = 0, done = done }
	PlaceAt(board, frame, from)
	drag.animator:SetScript('OnUpdate', function(_, elapsed) RunSlides(board, elapsed) end)
end

local function SlotOf(board, row)
	local slide = board.drag.slides[row]
	return slide and slide.to or OffsetOf(row)
end

local function TrackDrag(board)
	local drag = board.drag
	local _, cursorY = GetCursorPosition()
	local panelTop = board.panel:GetTop()
	local ghostY = cursorY / board.frame:GetEffectiveScale() + drag.grabOffset - panelTop
	PlaceAt(board, drag.ghost, ghostY)
	local centre = ghostY - DRAG_ROW / 2
	local from, over
	for index, row in ipairs(drag.rows) do
		if row == drag.dragging then from = index end
		local top = SlotOf(board, row)
		if centre <= top and centre >= top - row:GetHeight() then over = index end
	end
	if not over or over == from then return end
	local delta = over > from and 1 or -1
	local before = {}
	for _, row in ipairs(drag.rows) do before[row] = OffsetOf(row) end
	drag.rows[from], drag.rows[from + delta] = drag.rows[from + delta], drag.rows[from]
	board:Move(drag.dragging, delta)
	drag.onMove(from, delta)
	for _, row in ipairs(drag.rows) do
		local target = OffsetOf(row)
		if before[row] ~= target then Slide(board, row, before[row], target) end
	end
end

function Board:DragList(onMove, onDrop)
	local animator = CreateFrame('Frame', nil, self.panel)
	self.drag = { rows = {}, slides = {}, animator = animator, onMove = onMove, onDrop = onDrop }
end

function Board:AddDragRow(label, room, sub, icon)
	local kit, drag = self.kit, self.drag
	local row = Section.AddRow(self, sub and (label .. ' ' .. sub) or label)
	row:SetHeight(DRAG_ROW)
	drag.rows[#drag.rows + 1] = row
	kit.Glyph(row, 'grabber', GRABBER_SIZE, 'faint'):SetPoint('LEFT', kit.ROW_INSET, 0)
	local textX = DragTextX(icon)
	if icon then
		row.icon = row:CreateTexture(nil, 'ARTWORK')
		row.icon:SetSize(ICON_SIZE, ICON_SIZE)
		row.icon:SetPoint('LEFT', DRAG_TITLE_X, 0)
		row.icon:SetTexture(icon)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	local title, subtitle = kit.RowTitle(row, label, sub, textX, self.panelWidth - textX - kit.ROW_INSET - room - CONTROL_GAP)
	row:EnableMouse(true)
	row:RegisterForDrag('LeftButton')
	row:SetScript('OnDragStart', function(frame)
		local ghost = DragGhost(self)
		if drag.slides[ghost] then FinishSlide(self, ghost) end
		local _, cursorY = GetCursorPosition()
		drag.dragging = frame
		drag.grabOffset = frame:GetTop() - cursorY / self.frame:GetEffectiveScale()
		frame:SetAlpha(DRAG_ALPHA)
		ghost.icon:SetShown(icon ~= nil)
		if icon then ghost.icon:SetTexture(icon) end
		ghost.label:ClearAllPoints()
		ghost.label:SetPoint('LEFT', textX, 0)
		ghost.label:SetText(label)
		ghost:Show()
		TrackDrag(self)
		frame:SetScript('OnUpdate', function() TrackDrag(self) end)
	end)
	row:SetScript('OnDragStop', function(frame)
		frame:SetScript('OnUpdate', nil)
		drag.dragging = nil
		local ghost = drag.ghost
		Slide(self, ghost, OffsetOf(ghost), SlotOf(self, frame), function()
			ghost:Hide()
			frame:SetAlpha(1)
		end)
		drag.onDrop()
	end)
	return row, title, subtitle
end

function Board:Move(frame, delta)
	for index, row in ipairs(self.rows) do
		if row.frame == frame then
			local other = self.rows[index + delta]
			if other then self.rows[index], self.rows[index + delta] = other, row end
			return
		end
	end
end

function Board:Layout(y, query)
	self:Measure()
	local columns = math.max(1, math.floor((self.panelWidth - CELL_INSET * 2) / MIN_CELL))
	local cellWidth = math.floor((self.panelWidth - CELL_INSET * 2) / columns)
	local shown, group = 0
	for _, row in ipairs(self.rows) do
		if row.kind == 'caption' then
			group = row
			row.match = false
		else
			row.match = query == '' or row.search:find(query, 1, true) ~= nil
			if row.match then
				shown = shown + 1
				if group then group.match = true end
			end
		end
	end
	if shown == 0 and query ~= '' then
		self.frame:Hide()
		return y
	end
	local slots = {}
	for _, row in ipairs(self.rows) do
		if row.match and row.frame.tools then
			for slot, width in pairs(row.frame.tools.widths) do
				if not slots[slot] or width > slots[slot] then slots[slot] = width end
			end
		end
	end
	for _, row in ipairs(self.rows) do
		if row.match and row.frame.tools then row.frame.tools.Place(slots) end
	end
	local top = self.headHeight or PAD
	local height, column = top, 0
	local function Break()
		if column == 0 then return end
		height = height + CELL_HEIGHT
		column = 0
	end
	for _, row in ipairs(self.rows) do
		row.frame:SetShown(row.match)
		if row.match then
			row.frame:ClearAllPoints()
			if row.kind == 'cell' then
				row.frame:SetPoint('TOPLEFT', CELL_INSET + column * cellWidth, -height)
				row.frame:SetWidth(cellWidth)
				column = column + 1
				if column == columns then Break() end
			else
				Break()
				row.rule:SetShown(height > top)
				row.frame:SetPoint('TOPLEFT', 0, -height)
				height = height + row.frame:GetHeight()
			end
		end
	end
	Break()
	return self:Place(y, height + PAD)
end

Layout.TableKitExtensions[#Layout.TableKitExtensions + 1] = function(kit)
	function kit.Board(parent, width, spec)
		local board = setmetatable(kit.Section(parent, width, spec), Board)
		board.kit = kit
		return board
	end
end
