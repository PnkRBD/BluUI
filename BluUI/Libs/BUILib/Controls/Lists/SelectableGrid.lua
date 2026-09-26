local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE
local unpack, type, tostring, ipairs = unpack, type, tostring, ipairs

function Controls.SelectableGrid(parent, config)
	config = config or {}
	local width = config.width or 700
	local columns = config.columns or {}
	local rowHeight = config.rowHeight or 36
	local headerHeight = config.headerHeight or 32
	local selectable = config.selectable ~= false
	local onSelect = config.onSelect
	local onRowClick = config.onRowClick

	local containerWidget = Widget.New(parent, "Frame", nil, {bg = {0.03, 0.035, 0.04, 1}, border = {0.1, 0.1, 0.1, 1}, width = width})
	local container = containerWidget.frame

	local header = CreateFrame("Frame", nil, container)
	header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(headerHeight)

	local headerBg = Widget.Create(header, 0.045, 0.05, 0.055, 1)
	headerBg:SetAllPoints(); headerBg:SetDrawLayer("BACKGROUND")

	local headerBorder = Widget.Create(header, 0.08, 0.08, 0.08, 1)
	headerBorder:SetPoint("BOTTOMLEFT"); headerBorder:SetPoint("BOTTOMRIGHT"); headerBorder:SetHeight(1)

	local selectAllCheck
	local columnCursorX = 8
	if selectable then
		local selectAllBox = CreateFrame("Button", nil, header, "BackdropTemplate")
		selectAllBox:SetSize(16, 16); selectAllBox:SetPoint("LEFT", columnCursorX, 0)
		selectAllBox:SetBackdrop(Widget.BACKDROP)
		selectAllBox:SetBackdropColor(unpack(Theme.bg.input)); selectAllBox:SetBackdropBorderColor(unpack(Theme.border.input))

		selectAllCheck = Widget.Create(selectAllBox)
		selectAllCheck:SetSize(10, 10); selectAllCheck:SetPoint("CENTER")
		selectAllCheck:SetDrawLayer("OVERLAY")
		local red, green, blue = Theme.GetAccent()
		Widget.SetColor(selectAllCheck, red, green, blue, 1)
		selectAllCheck:Hide()

		selectAllBox:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(Theme.border.hover)) end)
		selectAllBox:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(Theme.border.input)) end)
		container._selectAllBox = selectAllBox
		columnCursorX = columnCursorX + 28
	end

	for _, column in ipairs(columns) do
		local columnLabel = header:CreateFontString(nil, "OVERLAY")
		columnLabel:SetFont(BUILib.GetFont(), 10, ""); columnLabel:SetPoint("LEFT", columnCursorX, 0)
		columnLabel:SetWidth(column.width or 100); columnLabel:SetText(column.label or "")
		columnLabel:SetTextColor(unpack(Theme.text.muted)); columnLabel:SetJustifyH(column.align or "LEFT")
		columnCursorX = columnCursorX + (column.width or 100)
	end

	local rows = {}
	local selection = {}

	local rowContainer = CreateFrame("Frame", nil, container)
	rowContainer:SetPoint("TOPLEFT", 1, -(headerHeight + 1))
	rowContainer:SetPoint("TOPRIGHT", -1, -(headerHeight + 1))

	local function UpdateHeight()
		local visibleCount = 0
		for _, row in ipairs(rows) do
			if row:IsShown() then visibleCount = visibleCount + 1 end
		end
		local totalHeight = headerHeight + 2 + visibleCount * rowHeight
		rowContainer:SetHeight(math.max(1, visibleCount * rowHeight))
		container:SetHeight(totalHeight)
		container.layoutHeight = totalHeight
	end

	local function UpdateSelectAll()
		if not selectAllCheck then return end
		if #rows == 0 then selectAllCheck:Hide(); return end
		local allSelected = true
		for rowIndex in ipairs(rows) do
			if not selection[rowIndex] then allSelected = false; break end
		end
		selectAllCheck:SetShown(allSelected)
	end

	local function UpdateRowVisual(row, index)
		local isSelected = selection[index]
		if isSelected then
			local red, green, blue = Theme.GetAccent()
			Widget.SetColor(row._selectBg, red, green, blue, 0.08)
			row._checkTex:Show()
			row._checkBox:SetBackdropBorderColor(red, green, blue, 0.8)
		else
			Widget.SetColor(row._selectBg, 0, 0, 0, 0)
			row._checkTex:Hide()
			row._checkBox:SetBackdropBorderColor(unpack(Theme.border.input))
		end
	end

	local STATUS_COLORS = {
		fulfilled = {0.34, 0.80, 0.44}, confirmed = {0.30, 0.60, 1.0},
		shipped = {0.95, 0.65, 0.15}, partial = {0.95, 0.65, 0.15},
		pending = {0.7, 0.7, 0.7}, cancelled = {0.8, 0.3, 0.3},
		active = {0.34, 0.80, 0.44}, inactive = {0.5, 0.5, 0.5},
		enabled = {0.34, 0.80, 0.44}, disabled = {0.5, 0.5, 0.5},
		error = {0.9, 0.25, 0.25}, warning = {0.95, 0.75, 0.15},
	}

	function container:AddRow(values, rowData)
		local rowIndex = #rows + 1
		local row = CreateFrame("Button", nil, rowContainer)
		row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * rowHeight))
		row:SetPoint("TOPRIGHT", 0, -((rowIndex - 1) * rowHeight)); row:SetHeight(rowHeight)
		row._data = rowData

		local selectBg = Widget.Create(row, 0, 0, 0, 0)
		selectBg:SetAllPoints(); selectBg:SetDrawLayer("BACKGROUND", 0)
		row._selectBg = selectBg

		if rowIndex % 2 == 0 then
			local stripeBg = Widget.Create(row, 0.035, 0.04, 0.045, 0.6)
			stripeBg:SetAllPoints(); stripeBg:SetDrawLayer("BACKGROUND", -1)
		end

		local hoverBg = Widget.Create(row, 0.08, 0.08, 0.1, 0)
		hoverBg:SetAllPoints(); hoverBg:SetDrawLayer("BACKGROUND", 1)
		row._hoverBg = hoverBg

		local cellX = 8
		if selectable then
			local checkBox = CreateFrame("Button", nil, row, "BackdropTemplate")
			checkBox:SetSize(16, 16); checkBox:SetPoint("LEFT", cellX, 0)
			checkBox:SetBackdrop(Widget.BACKDROP)
			checkBox:SetBackdropColor(unpack(Theme.bg.input)); checkBox:SetBackdropBorderColor(unpack(Theme.border.input))

			local checkTexture = Widget.Create(checkBox)
			checkTexture:SetSize(10, 10); checkTexture:SetPoint("CENTER"); checkTexture:SetDrawLayer("OVERLAY")
			local red, green, blue = Theme.GetAccent()
			Widget.SetColor(checkTexture, red, green, blue, 1)
			checkTexture:Hide()

			row._checkBox = checkBox; row._checkTex = checkTexture

			checkBox:SetScript("OnClick", function()
				selection[rowIndex] = not selection[rowIndex]
				UpdateRowVisual(row, rowIndex); UpdateSelectAll()
				if onSelect then onSelect(container:GetSelected()) end
			end)
			cellX = cellX + 28
		else
			local stub = CreateFrame("Frame", nil, row); stub:Hide()
			stub.SetBackdropBorderColor = function() end
			row._checkBox = stub
			row._checkTex = stub:CreateTexture(nil, "OVERLAY"); row._checkTex:Hide()
		end

		row._cells = {}
		for columnIndex, column in ipairs(columns) do
			local columnType = column.type or "text"
			local value = values[columnIndex] or ""
			local columnWidth = column.width or 100

			if columnType == "status" then
				local statusFrame = CreateFrame("Frame", nil, row)
				statusFrame:SetPoint("LEFT", cellX, 0); statusFrame:SetSize(columnWidth, rowHeight)

				local dot = Widget.Create(statusFrame)
				dot:SetSize(7, 7); dot:SetPoint("LEFT")
				local statusText = statusFrame:CreateFontString(nil, "OVERLAY")
				statusText:SetFont(BUILib.GetFont(), 10, ""); statusText:SetPoint("LEFT", dot, "RIGHT", 6, 0)

				if type(value) == "table" then
					statusText:SetText(string.upper(value.text or ""))
					local statusColor = value.color
					if type(statusColor) == "string" then statusColor = STATUS_COLORS[statusColor:lower()] or {0.7, 0.7, 0.7} end
					statusColor = statusColor or {0.7, 0.7, 0.7}
					Widget.SetColor(dot, statusColor[1], statusColor[2], statusColor[3], 1)
					statusText:SetTextColor(statusColor[1], statusColor[2], statusColor[3], 1)
				else
					statusText:SetText(string.upper(tostring(value)))
					Widget.SetColor(dot, 0.7, 0.7, 0.7, 1)
					statusText:SetTextColor(0.7, 0.7, 0.7, 1)
				end
				row._cells[columnIndex] = statusFrame
			elseif columnType == "accent" then
				local cell = row:CreateFontString(nil, "OVERLAY")
				cell:SetFont(BUILib.GetFont(), FONT_SIZE, ""); cell:SetPoint("LEFT", cellX, 0)
				cell:SetWidth(columnWidth); cell:SetText(tostring(value))
				local red, green, blue = Theme.GetAccent()
				cell:SetTextColor(red, green, blue, 1); cell:SetJustifyH(column.align or "LEFT")
				row._cells[columnIndex] = cell
			elseif columnType == "icon" then
				local size = math.min(columnWidth, rowHeight - 8)
				local iconTexture = row:CreateTexture(nil, "ARTWORK")
				iconTexture:SetSize(size, size)
				iconTexture:SetPoint("LEFT", cellX, 0)
				iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				iconTexture:SetTexture((value ~= nil and value ~= "") and value or 134400)
				row._cells[columnIndex] = iconTexture
			else
				local cell = row:CreateFontString(nil, "OVERLAY")
				cell:SetFont(BUILib.GetFont(), FONT_SIZE, ""); cell:SetPoint("LEFT", cellX, 0)
				cell:SetWidth(columnWidth); cell:SetText(tostring(value))
				cell:SetTextColor(unpack(Theme.text.secondary)); cell:SetJustifyH(column.align or "LEFT")
				row._cells[columnIndex] = cell
			end
			cellX = cellX + columnWidth
		end

		local border = Widget.Create(row, 0.06, 0.06, 0.06, 0.5)
		border:SetPoint("BOTTOMLEFT"); border:SetPoint("BOTTOMRIGHT"); border:SetHeight(1)

		row:SetScript("OnEnter", function() Widget.SetColor(hoverBg, 0.08, 0.08, 0.1, 0.4) end)
		row:SetScript("OnLeave", function() Widget.SetColor(hoverBg, 0.08, 0.08, 0.1, 0) end)

		row:SetScript("OnClick", function()
			if onRowClick then onRowClick(rowIndex, rowData)
			elseif selectable then
				selection[rowIndex] = not selection[rowIndex]
				UpdateRowVisual(row, rowIndex); UpdateSelectAll()
				if onSelect then onSelect(container:GetSelected()) end
			end
		end)

		rows[rowIndex] = row; UpdateHeight()
		return row
	end

	if container._selectAllBox then
		container._selectAllBox:SetScript("OnClick", function()
			local allSelected = true
			for rowIndex in ipairs(rows) do if not selection[rowIndex] then allSelected = false; break end end
			for rowIndex, row in ipairs(rows) do
				selection[rowIndex] = not allSelected; UpdateRowVisual(row, rowIndex)
			end
			UpdateSelectAll()
			if onSelect then onSelect(container:GetSelected()) end
		end)
	end

	function container:GetSelected()
		local result = {}
		for rowIndex, row in ipairs(rows) do
			if selection[rowIndex] then result[#result + 1] = {index = rowIndex, data = row._data} end
		end
		return result
	end

	function container:ClearRows()
		for _, row in ipairs(rows) do row:Hide() end
		wipe(rows)
		wipe(selection)
		UpdateHeight(); UpdateSelectAll()
	end

	Theme.RegisterAccentElement(container, function(_, red, green, blue)
		if selectAllCheck then Widget.SetColor(selectAllCheck, red, green, blue, 1) end
		for rowIndex, row in ipairs(rows) do
			if row._checkTex then Widget.SetColor(row._checkTex, red, green, blue, 1) end
			if selection[rowIndex] then UpdateRowVisual(row, rowIndex) end
		end
	end)

	UpdateHeight()
	return container
end
