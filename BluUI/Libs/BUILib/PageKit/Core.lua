local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Widget = BUILib.Widget

BUILib.PageKit = BUILib.PageKit or {}
local PageKit = BUILib.PageKit

PageKit.PAD     = 24
PageKit.GAP     = 12
PageKit.TAB_H   = 88
PageKit.TAB_GAP = 12

local SHEET_ROW_PITCH, SHEET_ROW_TOP = 32, 8

function PageKit.CardHeight(rows)
	if BUILib.IsDatasheet() then return SHEET_ROW_TOP * 2 + rows * SHEET_ROW_PITCH end
	return 40 + rows * 40
end

function PageKit.AddSettingRow(tab, config, gap)
	config.width = tab.width
	local row = BUILib.Controls.SettingRow(tab.child, config)
	BUILib.Layout.Add(tab, row, gap or 8)
	return row
end

function PageKit.Row(parent, yOffset, label, control)
	local row = CreateFrame("Frame", nil, parent)
	local sheet = parent.__datasheet and BUILib.SHEET
	if sheet then
		local rowIndex = math.floor((yOffset - 38) / 40 + 0.5)
		local y = SHEET_ROW_TOP + rowIndex * SHEET_ROW_PITCH
		row:SetPoint("TOPLEFT", sheet.marginWidth + sheet.rowInset, -y)
		row:SetPoint("TOPRIGHT", -sheet.rightPad, -y)
		if rowIndex > 0 then
			local hairline = row:CreateTexture(nil, "BORDER")
			hairline:SetTexture(Widget.WHITE)
			hairline:SetVertexColor(unpack(sheet.hairline))
			hairline:SetHeight(1)
			hairline:SetPoint("TOPLEFT", 0, 3)
			hairline:SetPoint("TOPRIGHT", 0, 3)
		end
		parent.__datasheetFixed = true
		if parent.AddField then parent:AddField() end
	else
		row:SetPoint("TOPLEFT", 14, -yOffset)
		row:SetPoint("TOPRIGHT", -14, -yOffset)
	end
	row:SetHeight(28)
	if label then
		local labelText = row:CreateFontString(nil, "OVERLAY")
		labelText:SetFont(BUILib.Font, sheet and 12 or 11, "")
		labelText:SetPoint("LEFT", 0, 0)
		if sheet then labelText:SetTextColor(1, 1, 1, 1) else labelText:SetTextColor(0.85, 0.85, 0.88, 1) end
		labelText:SetText(label)
	end
	if control then
		local controlFrame = control.frame or control
		controlFrame:ClearAllPoints(); controlFrame:SetParent(row); controlFrame:SetPoint("RIGHT", 0, 0)
	end
	return row
end

function PageKit.AttachLeft(control, target, gap)
	local controlFrame = Widget.Unwrap(control)
	controlFrame:ClearAllPoints()
	controlFrame:SetPoint("RIGHT", Widget.Unwrap(target), "LEFT", -(gap or 8), 0)
	return control
end

function PageKit.HintArrow(target, config)
	config = config or {}
	local size = config.size or 40
	local hint = CreateFrame("Frame", nil, target:GetParent())
	hint:SetSize(size, size)
	hint:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", config.offsetX or 2, config.offsetY or -6)
	local arrowTexture = hint:CreateTexture(nil, "OVERLAY")
	arrowTexture:SetAllPoints()
	arrowTexture:SetTexture(BUILib.GetLibMedia("arrow"))
	arrowTexture:SetVertexColor(1, 1, 1, 0.9)
	hint.arrow = arrowTexture
	if config.label then
		local labelText = hint:CreateFontString(nil, "OVERLAY")
		labelText:SetFont(BUILib.Font, 13, "")
		labelText:SetPoint("RIGHT", hint, "BOTTOMLEFT", -4, 4)
		labelText:SetTextColor(1, 1, 1, 0.9)
		labelText:SetText(config.label)
		hint.label = labelText
	end
	return hint
end

function PageKit.PopRow(panel, yOffset, label, control)
	local labelText = panel:CreateFontString(nil, "OVERLAY")
	labelText:SetFont(BUILib.Font, 11, "")
	labelText:SetPoint("LEFT", panel, "TOPLEFT", 0, -yOffset)
	labelText:SetTextColor(0.85, 0.85, 0.88, 1)
	labelText:SetText(label)
	local controlFrame = Widget.Unwrap(control)
	controlFrame:ClearAllPoints(); controlFrame:SetPoint("RIGHT", panel, "TOPRIGHT", 0, -yOffset)
end

function PageKit.RowGrid(tab, gridOptions)
	gridOptions = gridOptions or {}
	local sheet = BUILib.IsDatasheet()
	local gap = gridOptions.gap or (sheet and 0 or 12)
	local columnGap = sheet and 24 or gap
	local width = tab.width or 640
	local colWidth = math.floor((width - columnGap) / 2)

	local container = CreateFrame("Frame", nil, tab.child)
	container:SetWidth(width)
	container:SetHeight(1)
	container.layoutHeight = 1
	BUILib.Layout.Add(tab, container, 8)

	local yOffset = 0
	local lastHeight = 1
	local pending

	local function Sync()
		local totalHeight = math.max(yOffset - gap, 1)
		container:SetHeight(totalHeight)
		container.layoutHeight = totalHeight
		tab:AddY(totalHeight - lastHeight)
		lastHeight = totalHeight
	end

	local function Build(config, rowWidth, xOffset)
		config.width = rowWidth
		local row = BUILib.Controls.SettingRow(container, config)
		local rowFrame = row.frame or row
		rowFrame:ClearAllPoints()
		rowFrame:SetPoint("TOPLEFT", container, "TOPLEFT", xOffset, -yOffset)
		return row, (rowFrame.layoutHeight or rowFrame:GetHeight() or 58), rowFrame
	end

	local function Equalize(firstFrame, secondFrame, rowHeight)
		firstFrame:SetRowHeight(rowHeight)
		secondFrame:SetRowHeight(rowHeight)
	end

	local grid = {}

	function grid:Flush()
		if not pending then return end
		local config = pending
		pending = nil
		local row, rowHeight = Build(config, width, 0)
		yOffset = yOffset + rowHeight + gap
		Sync()
		return row
	end

	function grid:Add(config)
		local isFullSpan = config.spanFull
		config.spanFull = nil
		if isFullSpan then
			self:Flush()
			local row, rowHeight = Build(config, width, 0)
			yOffset = yOffset + rowHeight + gap
			Sync()
			return row
		end
		if not pending then
			pending = config
			return nil
		end
		local firstConfig = pending
		pending = nil
		local _, firstHeight, firstFrame = Build(firstConfig, colWidth, 0)
		local row, secondHeight, secondFrame = Build(config, colWidth, colWidth + columnGap)
		local rowHeight = math.max(firstHeight, secondHeight)
		Equalize(firstFrame, secondFrame, rowHeight)
		yOffset = yOffset + rowHeight + gap
		Sync()
		return row
	end

	function grid:SyncDim(enabled)
		local dim = not enabled
		container:SetAlpha(dim and 0.35 or 1)
		if not container._blocker then
			local blocker = CreateFrame("Frame", nil, container)
			blocker:SetAllPoints()
			blocker:SetFrameLevel(container:GetFrameLevel() + 60)
			blocker:EnableMouse(true)
			blocker:Hide()
			container._blocker = blocker
		end
		container._blocker:SetShown(dim and true or false)
	end

	return grid
end

function PageKit.CheckGrid(tab, gridOptions)
	gridOptions = gridOptions or {}
	local columnCount = gridOptions.columns or 3
	local gap = gridOptions.gap or 10
	local rowHeight = gridOptions.rowHeight or 28
	local width = tab.width or 640
	local colWidth = math.floor((width - gap * (columnCount - 1)) / columnCount)

	local container = CreateFrame("Frame", nil, tab.child)
	container:SetWidth(width)
	container:SetHeight(1)
	container.layoutHeight = 1
	BUILib.Layout.Add(tab, container, 8)

	local cellCount = 0
	local lastHeight = 1

	local function Sync()
		local lineCount = math.ceil(cellCount / columnCount)
		local totalHeight = math.max(lineCount * rowHeight, 1)
		container:SetHeight(totalHeight)
		container.layoutHeight = totalHeight
		tab:AddY(totalHeight - lastHeight)
		lastHeight = totalHeight
	end

	local grid = {}

	function grid:Add(label, checked, callback, tooltip)
		local column = cellCount % columnCount
		local line = math.floor(cellCount / columnCount)
		cellCount = cellCount + 1
		local cell = BUILib.Controls.StampCheckbox(container, label, checked, callback, nil, true, tooltip, "small")
		local cellFrame = cell.frame or cell
		cellFrame:ClearAllPoints()
		cellFrame:SetPoint("TOPLEFT", container, "TOPLEFT", column * (colWidth + gap), -(line * rowHeight) - math.floor((rowHeight - (cellFrame:GetHeight() or 18)) / 2))
		Sync()
		return cell
	end

	return grid
end
