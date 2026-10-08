local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Widget = BUILib.Widget
local Motion = BUILib.Motion
local Ease = Motion.Ease

local PAD = 10
local CELL_INSET = 8
local CELL_HEIGHT = 36
local MIN_CELL = 190
local STACKED_COLUMNS = 2
local SIDE_COLUMNS = 3
local SWITCH_X = 12
local LABEL_X = 62
local LABEL_INSET = 6
local PACK_GAP = 24
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
local DROP_TIME = 0.24
local CHEVRON_SIZE = 10
local GHOST_TINT_ALPHA = 0.3
local GROUP_INDENT = 20
local TINT_ALPHA = 0.07
local COUNT_GAP = 10

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
	cell.room = room or 0
	cell:SetScript('OnClick', function() switch.toggle:Click() end)
	if tip then
		cell:HookScript('OnEnter', function(self) Widget.ShowTip(self, tip) end)
		cell:HookScript('OnLeave', Widget.HideTip)
	end
	self.rows[#self.rows + 1] = { kind = 'cell', frame = cell, search = label:lower() }
	return switch, cell
end

function Board:AddRow(name, sub, room, search)
	local kit = self.kit
	local row = Section.AddRow(self, search or (sub and (name .. ' ' .. sub) or name))
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
	ghost.tint = kit.Fill(ghost, 'positive', 'BACKGROUND', 1)
	ghost.tint:SetAllPoints()
	ghost.tint:SetAlpha(GHOST_TINT_ALPHA)
	ghost.tint:Hide()
	ghost.edge = kit.Fill(ghost, 'accent', 'ARTWORK', 1)
	ghost.edge:SetPoint('TOPLEFT')
	ghost.edge:SetPoint('BOTTOMLEFT')
	ghost.edge:SetWidth(2)
	kit.Glyph(ghost, 'grabber', GRABBER_SIZE, 'text'):SetPoint('LEFT', kit.ROW_INSET, 0)
	ghost.icon = ghost:CreateTexture(nil, 'ARTWORK')
	ghost.icon:SetSize(ICON_SIZE, ICON_SIZE)
	ghost.icon:SetPoint('LEFT', DRAG_TITLE_X, 0)
	ghost.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	ghost.label = kit.Text(ghost, '', 12, 'text')
	ghost.sub = kit.Text(ghost, '', 11, 'muted')
	ghost:Hide()
	drag.ghost = ghost
	return ghost
end

local function DragTextX(icon)
	return icon and (DRAG_TITLE_X + ICON_SIZE + CONTROL_GAP) or DRAG_TITLE_X
end

local function IndentOf(row)
	return row.dragGroup and GROUP_INDENT or 0
end

local function TintRow(row)
	local header = row.dragHeader and row or row.dragGroup
	row.groupTint:SetShown(header ~= nil)
	if not header then return end
	local red, green, blue = header.dragTint()
	row.groupTint:SetVertexColor(red, green, blue, TINT_ALPHA)
	row.groupTint:SetPoint('TOPLEFT', -IndentOf(row), 0)
end

local function Tint(board, row)
	row.groupTint = row:CreateTexture(nil, 'BACKGROUND', nil, 2)
	row.groupTint:SetTexture(Widget.WHITE)
	row.groupTint:SetPoint('BOTTOMRIGHT')
	board.kit.Bind(row.groupTint, function() TintRow(row) end)
end

local function OffsetOf(frame)
	local _, _, _, _, y = frame:GetPoint(1)
	return y
end

local function Press(frame)
	local _, cursorY = GetCursorPosition()
	frame.pressY = cursorY
end

local function PlaceAt(board, frame, y)
	frame:ClearAllPoints()
	frame:SetPoint('TOPLEFT', board.panel, 'TOPLEFT', 0, y)
end

local function SlotOf(row)
	return Motion.Goal(row, 'y') or OffsetOf(row)
end

local function IndexOf(list, item)
	for index, value in ipairs(list) do
		if value == item then return index end
	end
end

local function RowIndex(board, frame)
	for index, row in ipairs(board.rows) do
		if row.frame == frame then return index end
	end
end

local function Shift(list, from, delta, count)
	local block = {}
	for index = 1, count do block[index] = table.remove(list, from) end
	for index = count, 1, -1 do table.insert(list, from + delta, block[index]) end
end
Layout.ShiftBlock = Shift

local function NodeSize(rows, index)
	local head = rows[index]
	if not head.dragHeader then return 1 end
	local count = 1
	while rows[index + count] and rows[index + count].dragGroup == head do count = count + 1 end
	return count
end

local function NodeBefore(rows, index)
	local row = rows[index - 1]
	if not row then return nil end
	return row.dragGroup and IndexOf(rows, row.dragGroup) or index - 1
end

local function ShownHeight(rows, index)
	local height = 0
	for offset = 0, NodeSize(rows, index) - 1 do
		local row = rows[index + offset]
		if row:IsShown() then height = height + row:GetHeight() end
	end
	return height
end

local function DropTone(drag)
	local dragging = drag.dragging
	if not dragging or dragging.dragHeader then return end
	local header = drag.target or dragging.dragGroup
	if header then return function(region) region:SetVertexColor(header.dragTint()) end end
	if drag.origin then return 'danger' end
end

local function PaintGroups(board)
	local drag, window = board.drag, board.window
	for _, row in ipairs(drag.rows) do TintRow(row) end
	local ghost = drag.ghost
	if not ghost then return end
	if drag.dragging then
		local indent = IndentOf(drag.dragging)
		if Motion.Goal(ghost, 'x') ~= indent then
			Motion.To(ghost, 'x', indent, SLIDE_TIME, { easing = Ease.outCubic })
			Motion.To(ghost, 'width', board.panelWidth - indent, SLIDE_TIME, { easing = Ease.outCubic })
		end
	end
	local tone = DropTone(drag)
	ghost.tint:SetShown(tone ~= nil)
	if tone then window:Paint(ghost.tint, tone) end
	window:Paint(ghost.edge, tone or 'accent')
end

local function Reorder(board, from, delta, count)
	local drag = board.drag
	local before = {}
	for _, row in ipairs(drag.rows) do before[row] = OffsetOf(row) end
	Shift(board.rows, RowIndex(board, drag.rows[from]), delta, count)
	Shift(drag.rows, from, delta, count)
	drag.onMove(from, delta, count)
	for _, row in ipairs(drag.rows) do
		local target = OffsetOf(row)
		if before[row] ~= target then Motion.To(row, 'y', target, SLIDE_TIME, { from = before[row], easing = Ease.outCubic }) end
	end
end

local function MoveTo(board, to, group)
	local drag = board.drag
	local dragging = drag.dragging
	local from = IndexOf(drag.rows, dragging)
	if from == to and dragging.dragGroup == group then return end
	dragging.dragGroup = group
	Reorder(board, from, to - from, 1)
	PaintGroups(board)
end

local function PlaceGhost(board)
	local drag = board.drag
	local _, cursorY = GetCursorPosition()
	local ghostY = cursorY / board.frame:GetEffectiveScale() + drag.grabOffset - board.panel:GetTop()
	Motion.To(drag.ghost, 'y', ghostY, 0)
	return ghostY - DRAG_ROW / 2
end

local function TrackDrag(board)
	local drag = board.drag
	local centre = PlaceGhost(board)
	local rows = drag.rows
	local over, first, last
	for index, row in ipairs(rows) do
		if row:IsShown() then
			local top = SlotOf(row)
			if centre <= top and centre >= top - row:GetHeight() then over = row end
			first = first or row
			last = row
		end
	end
	local target
	if over and over.dragHeader then
		target = over
	elseif over then
		MoveTo(board, IndexOf(rows, over), over.dragGroup)
	elseif first and centre > SlotOf(first) then
		MoveTo(board, 1, nil)
	elseif last and centre < SlotOf(last) - last:GetHeight() then
		MoveTo(board, #rows, nil)
	end
	if target ~= drag.target then
		drag.target = target
		PaintGroups(board)
	end
end

local function TrackBlock(board)
	local drag = board.drag
	local centre = PlaceGhost(board)
	local rows = drag.rows
	local from = IndexOf(rows, drag.dragging)
	local count = NodeSize(rows, from)
	local previous = NodeBefore(rows, from)
	local following = rows[from + count] and from + count
	if previous and centre > SlotOf(rows[previous]) - DRAG_ROW then
		Reorder(board, from, previous - from, count)
	elseif following and centre <= SlotOf(drag.dragging) - ShownHeight(rows, following) then
		Reorder(board, from, NodeSize(rows, following), count)
	end
end

local function Mirror(text, source)
	text:SetShown(source ~= nil)
	if not source then return end
	text:SetFont(source:GetFont())
	local point, _, _, x, y = source:GetPoint(1)
	text:ClearAllPoints()
	text:SetPoint(point, x, y)
	text:SetWidth(source:GetWidth())
	text:SetWordWrap(false)
	text:SetText(source:GetText())
end

local function StartDrag(board, frame, track, dimmed, title, subtitle, icon)
	local drag = board.drag
	local ghost = DragGhost(board)
	Motion.Finish(ghost, 'y')
	local indent = IndentOf(frame)
	PlaceAt(board, ghost, OffsetOf(frame))
	Motion.To(ghost, 'x', indent, 0)
	Motion.To(ghost, 'width', board.panelWidth - indent, 0)
	drag.dragging = frame
	drag.origin = not frame.dragHeader and frame.dragGroup or nil
	drag.dimmed = dimmed
	drag.grabOffset = frame:GetTop() - frame.pressY / board.frame:GetEffectiveScale()
	for _, row in ipairs(dimmed) do Motion.To(row, 'alpha', DRAG_ALPHA, 0) end
	ghost.icon:SetShown(icon ~= nil)
	if icon then ghost.icon:SetTexture(icon) end
	Mirror(ghost.label, title)
	Mirror(ghost.sub, subtitle)
	Motion.To(ghost, 'alpha', 1, 0)
	ghost:Show()
	PaintGroups(board)
	track(board)
	frame:SetScript('OnUpdate', function() track(board) end)
end

local function JoinTarget(board, frame)
	local drag = board.drag
	local target = drag.target
	drag.target = nil
	if not target or frame.dragGroup == target then return end
	local rows = drag.rows
	local from = IndexOf(rows, frame)
	local header = IndexOf(rows, target)
	local to = header + NodeSize(rows, header)
	if from < to then to = to - 1 end
	MoveTo(board, to, target)
end

local function Landing(rows, frame)
	for index = IndexOf(rows, frame), 1, -1 do
		if rows[index]:IsShown() then return SlotOf(rows[index]) end
	end
	return SlotOf(frame)
end

local function EndDrag(board, frame)
	local drag = board.drag
	frame:SetScript('OnUpdate', nil)
	JoinTarget(board, frame)
	drag.dragging, drag.origin = nil, nil
	drag.onDrop()
	PaintGroups(board)
	local ghost = drag.ghost
	Motion.To(ghost, 'y', Landing(drag.rows, frame), DROP_TIME, { easing = Ease.outCubic, onComplete = function() ghost:Hide() end })
	Motion.To(ghost, 'alpha', 0, DROP_TIME, { easing = Ease.outCubic })
	for _, row in ipairs(drag.dimmed) do Motion.To(row, 'alpha', 1, DROP_TIME, { easing = Ease.outCubic }) end
end

function Board:DragList(onMove, onDrop)
	self.drag = { rows = {}, onMove = onMove, onDrop = onDrop }
end

function Board:DragRows()
	return self.drag.rows
end

function Board:AddDragRow(label, room, sub, icon, group)
	local kit, drag = self.kit, self.drag
	local row = Section.AddRow(self, sub and (label .. ' ' .. sub) or label)
	row:SetHeight(DRAG_ROW)
	row.dragGroup = group
	drag.rows[#drag.rows + 1] = row
	Tint(self, row)
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
	row:SetScript('OnMouseDown', Press)
	row:SetScript('OnDragStart', function(frame) StartDrag(self, frame, TrackDrag, { frame }, title, subtitle, icon) end)
	row:SetScript('OnDragStop', function(frame) EndDrag(self, frame) end)
	return row, title, subtitle
end

function Board:AddDragTools(label, sub, icon, tools, after, group)
	local kit = self.kit
	local row, title, subtitle = self:AddDragRow(label, 0, sub, icon, group)
	local placer = kit.Tools(row, tools, after)
	local textWidth = self.panelWidth - DragTextX(icon) - kit.ROW_INSET - CONTROL_GAP
	row.tools = {
		widths = placer.widths,
		Place = function(slots)
			local width = textWidth - IndentOf(row) - placer.Place(slots)
			title:SetWidth(width)
			if subtitle then subtitle:SetWidth(width) end
		end,
	}
	row.controls = placer.controls
	return row
end

function Board:AddDragHeader(label, sub, tools, after, folded, onFold, tint)
	local kit, drag = self.kit, self.drag
	local row = Section.AddRow(self, label)
	row:SetHeight(DRAG_ROW)
	row.dragHeader = true
	row.dragFolded = folded
	row.dragTint = tint
	row.dragEntry = self.rows[#self.rows]
	row.dragEntry.kind = 'header'
	drag.rows[#drag.rows + 1] = row
	kit.Fill(row, 'secondary', 'BACKGROUND', 0):SetAllPoints()
	Tint(self, row)
	kit.Hover(row)
	local chevron = kit.Glyph(row, 'dropdown', CHEVRON_SIZE, 'muted')
	chevron:SetPoint('LEFT', kit.ROW_INSET, 0)
	local function Turn() chevron:SetRotation(folded() and math.pi / 2 or 0) end
	Turn()
	local title = kit.Text(row, label, 13, 'text', nil, 'title')
	title:SetPoint('LEFT', DRAG_TITLE_X, 0)
	title:SetWordWrap(false)
	local count = kit.Text(row, sub, 11, 'muted')
	count:SetPoint('LEFT', title, 'RIGHT', COUNT_GAP, 0)
	count:SetWordWrap(false)
	local placer = kit.Tools(row, tools, after)
	row.tools = { widths = placer.widths, Place = placer.Place }
	row.controls = placer.controls
	row:EnableMouse(true)
	row:RegisterForDrag('LeftButton')
	row:SetScript('OnMouseDown', function(frame)
		frame.dragged = false
		Press(frame)
	end)
	row:SetScript('OnMouseUp', function(frame, button)
		if button ~= 'LeftButton' or frame.dragged or not frame:IsMouseOver() then return end
		onFold()
		Turn()
	end)
	row:SetScript('OnDragStart', function(frame)
		frame.dragged = true
		local rows = drag.rows
		local from = IndexOf(rows, frame)
		local block = {}
		for offset = 0, NodeSize(rows, from) - 1 do block[#block + 1] = rows[from + offset] end
		StartDrag(self, frame, TrackBlock, block, title)
	end)
	row:SetScript('OnDragStop', function(frame) EndDrag(self, frame) end)
	return row, title, count
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

local function CellWidth(cell)
	return LABEL_X + math.ceil(cell.label:GetUnboundedStringWidth()) + LABEL_INSET + cell.room
end

local function Packs(board, room)
	local run = 0
	for _, row in ipairs(board.rows) do
		if row.kind == 'cell' then
			run = run + (run > 0 and PACK_GAP or 0) + CellWidth(row.frame)
			if run > room then return false end
		else
			run = 0
		end
	end
	return true
end

function Board:Layout(y, query)
	self:Measure()
	local room = self.panelWidth - CELL_INSET * 2
	local packed = Packs(self, room)
	local widest = MIN_CELL
	for _, row in ipairs(self.rows) do
		if row.kind == 'cell' then widest = math.max(widest, CellWidth(row.frame)) end
	end
	local columns = math.min(self.stacked and STACKED_COLUMNS or SIDE_COLUMNS, math.max(1, math.floor(room / widest)))
	local cellWidth = math.floor(room / columns)
	local shown, caption = 0, nil
	local dragging = self.drag and self.drag.dragging
	for _, row in ipairs(self.rows) do
		local header = row.frame.dragGroup
		if row.kind == 'caption' then
			caption = row
			row.match = false
		elseif row.kind == 'header' then
			row.match = query == '' or row.search:find(query, 1, true) ~= nil
		else
			row.match = query == '' or row.search:find(query, 1, true) ~= nil
			if row.match then
				shown = shown + 1
				if header then header.dragEntry.match = true elseif caption then caption.match = true end
			end
			if header and query == '' and header.dragFolded() and row.frame ~= dragging then row.match = false end
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
	local first, last
	for _, row in ipairs(self.rows) do
		if row.match then
			first = first or row
			last = row
		end
	end
	local top = self.headHeight or (first and first.kind == 'cell' and PAD or 0)
	local height, column, x = top, 0, CELL_INSET
	local function Break()
		if column == 0 then return end
		height = height + CELL_HEIGHT
		column, x = 0, CELL_INSET
	end
	for _, row in ipairs(self.rows) do
		row.frame:SetShown(row.match)
		if row.match then
			row.frame:ClearAllPoints()
			if row.kind == 'cell' then
				local width = packed and CellWidth(row.frame) or cellWidth
				row.frame:SetPoint('TOPLEFT', x, -height)
				row.frame:SetWidth(width)
				column, x = column + 1, x + width + (packed and PACK_GAP or 0)
				if not packed and column == columns then Break() end
			else
				Break()
				local indent = IndentOf(row.frame)
				row.rule:SetShown(height > top)
				row.frame:SetPoint('TOPLEFT', indent, -height)
				row.frame:SetWidth(self.panelWidth - indent)
				height = height + row.frame:GetHeight()
			end
		end
	end
	Break()
	if self.drag then PaintGroups(self) end
	return self:Place(y, height + (last and last.kind == 'cell' and PAD or 0))
end

Layout.TableKitExtensions[#Layout.TableKitExtensions + 1] = function(kit)
	function kit.Board(parent, width, spec)
		local board = setmetatable(kit.Section(parent, width, spec), Board)
		board.kit = kit
		board.stacked = spec.stacked == true
		return board
	end
end

local GRID_HEAD = 32
local GRID_ROW = 34
local GRID_GROUP = 24
local GRID_PAD = 10
local GRID_BOX = 26
local GRID_GAP = 8

local Grid = setmetatable({}, { __index = Section })
Grid.__index = Grid

local function FullRule(grid)
	local rule = grid.rows[#grid.rows].rule
	rule:ClearAllPoints()
	rule:SetPoint('TOPLEFT')
	rule:SetPoint('TOPRIGHT')
end

function Grid:AddGroup(label)
	local row = Section.AddRow(self, '')
	row:SetHeight(GRID_GROUP)
	self.window:Fill(row, 'gridGroup', 'BACKGROUND', 1):SetAllPoints()
	self.kit.Text(row, label:upper(), 10, 'muted', nil, 'title'):SetPoint('LEFT', GRID_PAD, 0)
	FullRule(self)
	return row
end

function Grid:AddTools(name, sub, tools, after)
	local kit = self.kit
	local groups = {}
	for _, tool in ipairs(tools) do
		local slot = Layout.ToolSlot(tool)
		groups[slot] = groups[slot] or {}
		table.insert(groups[slot], tool)
	end
	local cells = {}
	for index, column in ipairs(self.columns) do
		if column.slot == 'name' then
			cells[index] = { text = name, tip = sub }
		elseif column.slot == 'sub' then
			cells[index] = { text = sub or '', role = 'muted', tip = sub }
		else
			local slotTools = groups[column.slot]
			cells[index] = { build = function(row, x, cellWidth)
				if not slotTools then return end
				local controls, total = {}, -GRID_GAP
				for _, tool in ipairs(slotTools) do
					local control = kit.Tool(row, tool, after)
					if Layout.ToolSlot(tool) == 'input' then control:SetWidth(cellWidth) end
					controls[#controls + 1] = control
					total = total + control:GetWidth() + GRID_GAP
				end
				local cursor = x
				if column.align == 'CENTER' then cursor = x + math.floor((cellWidth - total) / 2) elseif column.align == 'RIGHT' then cursor = x + cellWidth - total end
				for _, control in ipairs(controls) do
					control:SetPoint('LEFT', cursor, 0)
					cursor = cursor + control:GetWidth() + GRID_GAP
				end
			end }
		end
	end
	return self:AddLine(cells, name .. ' ' .. (sub or ''))
end

function Grid:AddLine(cells, search)
	local kit, window = self.kit, self.window
	local row = Section.AddRow(self, search)
	row:SetHeight(self.rowHeight)
	for index, cell in ipairs(cells) do
		local column = self.columns[index]
		local inner = column.width - GRID_PAD * 2
		if type(cell) == 'table' and cell.build then
			cell.build(row, column.x + GRID_PAD, inner)
		elseif type(cell) == 'table' and cell.copy then
			local box = CreateFrame('Frame', nil, row)
			box:SetSize(inner, GRID_BOX)
			box:SetPoint('LEFT', column.x + GRID_PAD, 0)
			kit.Box(box, 'textbox', 'inputEdge')
			local edit = CreateFrame('EditBox', nil, box)
			edit:SetPoint('LEFT', GRID_PAD, 0)
			edit:SetPoint('RIGHT', -GRID_PAD, 0)
			edit:SetHeight(GRID_BOX)
			edit:SetAutoFocus(false)
			edit:SetFont(window.font, 12, '')
			window:Paint(edit, 'text')
			window:SetFontRole(edit, 'control')
			edit:SetText(cell.copy)
			edit:SetScript('OnTextChanged', function(self, userInput) if userInput then self:SetText(cell.copy) end end)
			edit:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
			edit:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
			edit:SetScript('OnEditFocusGained', function(self) self:HighlightText() end)
			edit:SetScript('OnEditFocusLost', function(self) self:HighlightText(0, 0) end)
			box:EnableMouse(true)
			box:SetScript('OnMouseDown', function() edit:SetFocus() end)
		else
			local value = type(cell) == 'table' and cell.text or cell
			local label = kit.Text(row, value, 12, type(cell) == 'table' and cell.role or 'text', inner)
			label:SetPoint('LEFT', column.x + GRID_PAD, 0)
			label:SetJustifyH(column.align or 'LEFT')
			label:SetWordWrap(false)
			local hover = CreateFrame('Frame', nil, row)
			hover:SetPoint('TOPLEFT', column.x, 0)
			hover:SetPoint('BOTTOMLEFT', column.x, 0)
			hover:SetWidth(column.width)
			hover:EnableMouse(true)
			local tip = type(cell) == 'table' and cell.tip
			hover:SetScript('OnEnter', function(self)
				local text = tip
				if not text and label:IsTruncated() then text = value end
				if text then Widget.ShowTip(self, text) end
			end)
			hover:SetScript('OnLeave', Widget.HideTip)
		end
	end
	FullRule(self)
	return row
end

Layout.TableKitExtensions[#Layout.TableKitExtensions + 1] = function(kit, window)
	function kit.Grid(parent, width, spec)
		local grid = setmetatable(kit.Section(parent, width, { stacked = true, title = spec.title, description = spec.description }), Grid)
		grid.kit = kit
		grid.headHeight = GRID_HEAD
		grid.rowHeight = spec.rowHeight or GRID_ROW
		local panel = grid.panel
		local head = window:Fill(panel, 'gridHead', 'BACKGROUND', 1)
		head:SetPoint('TOPLEFT')
		head:SetPoint('TOPRIGHT')
		head:SetHeight(GRID_HEAD)
		local underline = window:Fill(panel, 'rule', 'ARTWORK')
		underline:SetPoint('TOPLEFT', 0, -(GRID_HEAD - 1))
		underline:SetPoint('TOPRIGHT', 0, -(GRID_HEAD - 1))
		underline:SetHeight(1)
		grid.columns = {}
		local x = 0
		for index, column in ipairs(spec.columns) do
			local columnWidth = column.width or (width - x)
			local align = column.align or (column.slot == 'swatch' and 'RIGHT' or nil)
			grid.columns[index] = { x = x, width = columnWidth, align = align, slot = column.slot }
			local title = kit.Text(panel, column.title, 12, 'text', columnWidth - GRID_PAD * 2, 'title')
			title:SetPoint('LEFT', panel, 'TOPLEFT', x + GRID_PAD, -GRID_HEAD / 2)
			title:SetJustifyH(align or 'LEFT')
			title:SetWordWrap(false)
			if index > 1 then
				local divider = window:Fill(panel, 'rule', 'ARTWORK')
				divider:SetPoint('TOPLEFT', x, 0)
				divider:SetPoint('BOTTOMLEFT', x, 0)
				divider:SetWidth(1)
			end
			x = x + columnWidth
		end
		return grid
	end
end
