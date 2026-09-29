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

function Board:AddTools(name, sub, tools, after)
	local kit = self.kit
	local row = Section.AddRow(self, sub and (name .. ' ' .. sub) or name)
	local controls, width = kit.Tools(row, tools, after)
	kit.RowTitle(row, name, sub, kit.ROW_INSET, self.panelWidth - kit.ROW_INSET * 2 - width - CONTROL_GAP)
	row.controls = controls
	return row
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
	local height, column = PAD, 0
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
				row.rule:SetShown(height > PAD)
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
