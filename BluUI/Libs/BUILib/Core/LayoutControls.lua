local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Controls = BUILib.Controls
local Widget = BUILib.Widget
local Theme = BUILib.Theme

local PositionInTab = Layout.PositionInTab
local DEFAULT_MARGIN = Layout.DEFAULT_MARGIN
local COMPACT_MARGIN = Layout.COMPACT_MARGIN
local CONTROL_HEIGHT = Layout.CONTROL_HEIGHT

local LABEL_OFFSET = Layout.LABEL_OFFSET
local TOGGLE_HEIGHT = BUILib.TOGGLE_HEIGHT

Layout.HEIGHTS = {
	toggle = TOGGLE_HEIGHT, checkbox = TOGGLE_HEIGHT, slider = 70, sliderInput = 42, compactSlider = 42,
	button = CONTROL_HEIGHT, editbox = CONTROL_HEIGHT,
	editboxWithLabel = CONTROL_HEIGHT + LABEL_OFFSET,
	dropdown = CONTROL_HEIGHT, dropdownWithLabel = CONTROL_HEIGHT + LABEL_OFFSET,
	searchbox = CONTROL_HEIGHT, colorswatch = 26,
	statusindicator = 18, listitem = 60,
}
local HEIGHTS = Layout.HEIGHTS

local SHEET_MARGIN = 6
local SHEET_TOGGLE_W, SHEET_TOGGLE_H = 36, 18

local function IsSheet(tab) return tab.cardStyle == 'datasheet' or BUILib.IsDatasheet() end

local function SheetMargin(tab, def, labelOrDef)
	local explicit = type(labelOrDef) == 'table' and labelOrDef.topMargin ~= nil
	if IsSheet(tab) and not explicit then def.topMargin = SHEET_MARGIN end
	return def
end

function Layout.Toggle(tab, labelOrDef, checked, callback, description, indent)
	local def = Layout.ParseControlParams(labelOrDef, tab, {
		value = checked, callback = callback, desc = description,
		indent = indent or 0, enabled = true, topMargin = COMPACT_MARGIN,
	})
	local toggle, height
	if IsSheet(tab) then
		SheetMargin(tab, def, labelOrDef)
		toggle = Controls.SwitchToggle(tab.child, def.label, def.value, def.callback, def.indent, def.enabled ~= false, def.tooltip, SHEET_TOGGLE_W, SHEET_TOGGLE_H)
		height = SHEET_TOGGLE_H
	else
		toggle = Controls.Toggle(tab.child, def.label, def.value, def.callback, def.indent, def.enabled ~= false, def.tooltip, def.width, def.desc)
		height = HEIGHTS.toggle
	end
	PositionInTab(tab, toggle, height, def.topMargin)
	return toggle
end

function Layout.Dropdown(tab, labelOrDef, items, selected, callback, topMargin)
	local def = Layout.ParseControlParams(labelOrDef, tab, {
		items = items or {}, selected = selected or 1, callback = callback, topMargin = topMargin,
	})
	def.selected = def.value or def.selected
	if topMargin == nil then SheetMargin(tab, def, labelOrDef) end
	local dropdown = Controls.Dropdown(tab.child, def.label, def.items, def.selected, def.callback, def.tooltip, def.width)
	local height = def.label and HEIGHTS.dropdownWithLabel or HEIGHTS.dropdown
	PositionInTab(tab, dropdown, height, def.topMargin)
	return dropdown
end

function Layout.ColorSwatch(tab, labelOrDef, red, green, blue, alpha, callback, topMargin)
	local def = Layout.ParseControlParams(labelOrDef, tab, {
		r = red or 1, g = green or 1, b = blue or 1, a = alpha or 1,
		callback = callback, topMargin = topMargin, width = 150,
	})
	local swatch = Controls.ColorSwatch(tab.child, {
		r = def.r, g = def.g, b = def.b, a = def.a,
		callback = def.callback, label = def.label, tooltip = def.tooltip, width = def.width,
	})
	local height = HEIGHTS.colorswatch
	if IsSheet(tab) then
		if topMargin == nil then SheetMargin(tab, def, labelOrDef) end
		height = 18
	end
	PositionInTab(tab, swatch, height, def.topMargin)
	return swatch
end

function Layout.Text(tab, def)
	def = Layout.ParseControlParams(def, tab, {size = 12, color = Theme.text.primary})
	local text = Controls.Text(tab.child, def.text, def.size, def.color)
	PositionInTab(tab, text, def.size, def.topMargin)
	return text
end

function Layout.InfoBox(tab, textOrDef, infoType, topMargin)
	local def = Layout.ParseControlParams(textOrDef, tab, {
		infoType = infoType or "info", topMargin = topMargin,
	})
	def.text = def.text or (type(textOrDef) ~= "table" and textOrDef) or nil
	local control = Controls.InfoBox(tab.child, def.text, def.infoType, def.width)
	local height = control.layoutHeight or control:GetHeight() or 40
	PositionInTab(tab, control, height, def.topMargin)
	return control
end

function Layout.ItemList(tab, def)
	def = Layout.ParseControlParams(def, tab, {height = 100})
	local config = {
		showCheckbox = def.showCheckbox,
		onCheckboxChange = def.onCheckboxChange,
		onIconClick = def.onIconClick,
		onRowRightClick = def.onRowRightClick,
		noDragPicker = def.noDragPicker,
		onBindRow = def.onBindRow,
	}
	local control = Controls.ItemList(tab.child, def.hint, def.width, def.height, def.onAdd, def.onRemove, def.searchFunc, def.onSearchSelect, def.orderable, def.onReorder, nil, config)
	if def.items then
		for _, item in ipairs(def.items) do
			if type(item) == "string" then control:AddItem(nil, item, nil)
			elseif type(item) == "table" then control:AddItem(item.icon, item.name, item.id, item.removable, item.enabled) end
		end
	end
	local height = 44 + def.height
	PositionInTab(tab, control, height, def.topMargin)
	return control
end

function Layout.SettingsGrid(tab, def)
	def = Layout.ParseControlParams(def, tab, {
		topMargin = Layout.GRID_TOP_MARGIN, rowHeight = 34, cols = 2,
		gapX = 24, controlGap = 6, separators = false,
	})
	local width = def.width
	local items = def.items or {}
	local columnCount = def.cols
	local font = def.font or BUILib.GetFont()
	local fontSize = def.fontSize or 10

	local columnWidth = math.floor((width - def.gapX * (columnCount - 1)) / columnCount)

	local container = CreateFrame("Frame", nil, tab.child)
	container:SetWidth(width)
	container.__fieldCount = #items

	local currentY = 0

	if def.title then
		local heading = Controls.CategoryLabel(container, string.upper(def.title), width)
		heading:SetPoint("TOPLEFT", 0, 0)
		if def.hideHeadingLine then local headingFrame = Widget.Unwrap(heading); if headingFrame.line then headingFrame.line:Hide() end end
		currentY = heading:GetHeight() or 28
	end

	local effectiveSpan = {}
	local rowItems = {}
	do
		local probeRow, probeColumn = 1, 0
		for itemIndex, item in ipairs(items) do
			local span = item.span and columnCount or 1
			if probeColumn + span > columnCount then
				probeRow = probeRow + 1
				probeColumn = 0
			end
			effectiveSpan[itemIndex] = span
			rowItems[probeRow] = rowItems[probeRow] or {}
			rowItems[probeRow][#rowItems[probeRow] + 1] = itemIndex
			probeColumn = probeColumn + span
			if probeColumn >= columnCount then
				probeRow = probeRow + 1
				probeColumn = 0
			end
		end
		for _, rowItemIndexes in pairs(rowItems) do
			if #rowItemIndexes == 1 and effectiveSpan[rowItemIndexes[1]] < columnCount then
				effectiveSpan[rowItemIndexes[1]] = columnCount
			end
		end
	end

	local widgetRefs = {}
	local column = 0
	local rowY = currentY
	local rowHeight = def.rowHeight
	local rowIndex = 0
	local rowExtents = {}

	for itemIndex, item in ipairs(items) do
		local span = effectiveSpan[itemIndex]

		if column + span > columnCount then
			if column > 0 then currentY = currentY + rowHeight end
			column = 0
			rowHeight = def.rowHeight
			rowIndex = rowIndex + 1

			if def.separators and rowIndex > 0 then
				local separator = container:CreateTexture(nil, "BACKGROUND")
				separator:SetHeight(1)
				separator:SetPoint("TOPLEFT", 0, -currentY)
				separator:SetPoint("TOPRIGHT", 0, -currentY)
				separator:SetColorTexture(0.06, 0.06, 0.06, 1)
				currentY = currentY + 1
			end
		end

		if column == 0 then
			if item.topMargin then currentY = currentY + item.topMargin end
			rowY = currentY
			rowExtents[#rowExtents + 1] = { top = rowY, startCols = {} }
		end

		local extent = rowExtents[#rowExtents]
		extent.startCols[column] = true

		if item.height and item.height > rowHeight then rowHeight = item.height end

		local cellX = column * (columnWidth + def.gapX)
		local cellWidth = span == columnCount and width or columnWidth

		local labelFontString = container:CreateFontString(nil, "OVERLAY")
		labelFontString:SetFont(font, fontSize, "")
		labelFontString:SetTextColor(unpack(Theme.text.primary))
		labelFontString:SetText(item.label or "")
		labelFontString:SetJustifyH("LEFT")
		labelFontString:SetPoint("LEFT", container, "TOPLEFT", cellX, -(rowY + rowHeight * 0.5))

		local controls = item.controls or (item.control and { item.control } or {})
		local labelAllocation = math.floor(cellWidth * 0.35)
		local fillWidth = cellWidth - labelAllocation
		local rightOffsetFromCell = (column + 1 == columnCount) and 0 or (width - (cellX + cellWidth))
		local accumRight = rightOffsetFromCell
		for ci = #controls, 1, -1 do
			local control = Widget.Unwrap(controls[ci])
			control:SetParent(container)
			control:ClearAllPoints()
			local controlWidth = control:GetWidth() or 36
			if #controls == 1 and controlWidth > 50 and controlWidth < cellWidth and not control._noGridStretch then
				controlWidth = fillWidth
				control:SetWidth(controlWidth)
			elseif ci == 1 and item.fillFirst and not control._noGridStretch then

				local availableWidth = fillWidth - (accumRight - rightOffsetFromCell)
				if availableWidth > 50 then controlWidth = availableWidth; control:SetWidth(controlWidth) end
			end
			local controlHeight = control:GetHeight() or 22
			control:SetPoint("TOPRIGHT", container, "TOPRIGHT", -accumRight, -(rowY + math.floor((rowHeight - controlHeight) / 2)))

			control._gridCellOffset = cellWidth - (accumRight - rightOffsetFromCell) - controlWidth
			control._gridRowPad = math.floor((rowHeight - controlHeight) / 2)
			if control._lockedOverlay then
				control._lockedOverlay:ClearAllPoints()
				control._lockedOverlay:SetPoint("TOPLEFT", -(control._gridCellOffset), control._gridRowPad)
				control._lockedOverlay:SetPoint("BOTTOMRIGHT", 4, -(control._gridRowPad))
			end
			accumRight = accumRight + controlWidth + def.controlGap
			widgetRefs[#widgetRefs + 1] = controls[ci]
		end

		column = column + span
		if column >= columnCount then
			currentY = rowY + rowHeight
			extent.bottom = currentY
			column = 0
		end
	end

	if column > 0 then
		currentY = rowY + rowHeight
		rowExtents[#rowExtents].bottom = currentY
	end

	if def.verticalSeparators ~= false and columnCount > 1 then
		local pad = 6
		for columnIndex = 1, columnCount - 1 do
			local firstRow, lastRow
			for _, extent in ipairs(rowExtents) do
				if extent.startCols[columnIndex] then
					firstRow = firstRow or extent
					lastRow = extent
				end
			end
			if firstRow then
				local separatorX = columnIndex * (columnWidth + def.gapX) - math.floor(def.gapX / 2)
				local separator = container:CreateTexture(nil, "BACKGROUND")
				separator:SetWidth(1)
				local topY = firstRow.top + pad
				local bottomY = lastRow.bottom
				if lastRow == rowExtents[#rowExtents] then bottomY = bottomY - pad end
				separator:SetPoint("TOP", container, "TOPLEFT", separatorX, -topY)
				separator:SetPoint("BOTTOM", container, "TOPLEFT", separatorX, -bottomY)
				separator:SetColorTexture(0.15, 0.15, 0.15, 1)
			end
		end
	end

	container:SetHeight(currentY)
	PositionInTab(tab, container, currentY, def.topMargin)
	container.widgets = widgetRefs

	container._gridDef = def
	container._gridParentContent = tab.Refresh and tab or nil

	function container:SetItems(newItems)
		local childCount = self:GetNumChildren()
		for childIndex = 1, childCount do
			local child = select(childIndex, self:GetChildren())
			if child then child:Hide() end
		end
		local regionCount = self:GetNumRegions()
		for regionIndex = 1, regionCount do
			local region = select(regionIndex, self:GetRegions())
			if region then region:Hide() end
		end

		local gridDef = self._gridDef
		local width = gridDef.width
		local columnCount = gridDef.cols
		local font = gridDef.font or BUILib.GetFont()
		local fontSize = gridDef.fontSize or 10
		local columnWidth = math.floor((width - gridDef.gapX * (columnCount - 1)) / columnCount)

		local y = 0
		if gridDef.title then
			local heading = Controls.CategoryLabel(self, string.upper(gridDef.title), width)
			heading:SetPoint("TOPLEFT", 0, 0)
			if gridDef.hideHeadingLine then local headingFrame = Widget.Unwrap(heading); if headingFrame.line then headingFrame.line:Hide() end end
			y = heading:GetHeight() or 28
		end

		local widgetRefs = {}
		local column = 0
		local rowY = y
		local rowHeight = gridDef.rowHeight

		for _, item in ipairs(newItems) do
			local span = item.span and columnCount or 1
			if column + span > columnCount then
				if column > 0 then y = y + rowHeight end
				column = 0; rowHeight = gridDef.rowHeight
			end
			if column == 0 then rowY = y end
			if item.height and item.height > rowHeight then rowHeight = item.height end

			local cellX = column * (columnWidth + gridDef.gapX)
			local cellWidth = span == columnCount and width or columnWidth

			local labelFontString = self:CreateFontString(nil, "OVERLAY")
			labelFontString:SetFont(font, fontSize, "")
			labelFontString:SetTextColor(unpack(Theme.text.primary))
			labelFontString:SetText(item.label or "")
			labelFontString:SetJustifyH("LEFT")
			labelFontString:SetPoint("LEFT", self, "TOPLEFT", cellX, -(rowY + rowHeight * 0.5))

			local controls = item.controls or {}
			local rightX = cellX + cellWidth
			local labelAllocation2 = math.floor(cellWidth * 0.35)
			local fillWidth2 = cellWidth - labelAllocation2
			for ci = #controls, 1, -1 do
				local control = Widget.Unwrap(controls[ci])
				control:SetParent(self)
				control:ClearAllPoints()
				local controlWidth2 = control:GetWidth() or 36
				if #controls == 1 and controlWidth2 > 50 and controlWidth2 < cellWidth then
					controlWidth2 = fillWidth2; control:SetWidth(controlWidth2)
				elseif ci == 1 and item.fillFirst and not control._noGridStretch then

					local availableWidth = fillWidth2 - ((cellX + cellWidth) - rightX)
					if availableWidth > 50 then controlWidth2 = availableWidth; control:SetWidth(controlWidth2) end
				end
				local controlHeight = control:GetHeight() or 22
				rightX = rightX - controlWidth2
				control:SetPoint("TOPLEFT", self, "TOPLEFT", rightX, -(rowY + math.floor((rowHeight - controlHeight) / 2)))
				control:Show()
				rightX = rightX - gridDef.controlGap
				widgetRefs[#widgetRefs + 1] = controls[ci]
			end

			column = column + span
			if column >= columnCount then y = rowY + rowHeight; column = 0 end
		end
		if column > 0 then y = rowY + rowHeight end

		if gridDef.verticalSeparators ~= false and columnCount > 1 then
			local pad = 6
			for columnIndex = 1, columnCount - 1 do
				local separatorX = columnIndex * (columnWidth + gridDef.gapX) - math.floor(gridDef.gapX / 2)
				local separator = self:CreateTexture(nil, "BACKGROUND")
				separator:SetWidth(1)
				separator:SetPoint("TOP", self, "TOPLEFT", separatorX, -(gridDef.title and 28 or 0) - pad)
				separator:SetPoint("BOTTOM", self, "TOPLEFT", separatorX, -(y - pad))
				separator:SetColorTexture(0.15, 0.15, 0.15, 1)
			end
		end

		self:SetHeight(y)
		self.widgets = widgetRefs
		self._gridHeight = y

		local parentContent = self._gridParentContent
		if parentContent and parentContent.y then
			local maxBottom = 0
			local wrapper = self:GetParent()
			if wrapper then
				local wrapperChildCount = wrapper:GetNumChildren()
				for wrapperChildIndex = 1, wrapperChildCount do
					local child = select(wrapperChildIndex, wrapper:GetChildren())
					if child and child:IsShown() and child:GetHeight() > 0 then
						local _, _, _, _, offsetY = child:GetPoint(1)
						local bottom = math.abs(offsetY or 0) + child:GetHeight()
						if bottom > maxBottom then maxBottom = bottom end
					end
				end
			end
			if maxBottom > 0 then parentContent.y = -maxBottom end
			if parentContent.Refresh then parentContent:Refresh() end
		end
	end

	return container
end

function Layout.Preview(tab, def)
	def = Layout.ParseControlParams(def, tab, {height = 150})
	local control = Controls.Preview(tab.child, def.title, def.width, def.height, def.bgColor)
	PositionInTab(tab, control, def.height, def.topMargin)
	return control
end

function Layout.ModuleHeader(tab, opts)
	opts = opts or {}
	local sink = tab._headerSink
	if sink then
		local sinkResult = sink(opts)
		if sinkResult then return sinkResult.enable, sinkResult.anchor, sinkResult.action end
	end

	local headerHeight = sink and 36 or 48
	local header = CreateFrame('Frame', nil, tab.child)
	header:SetWidth(tab.width)
	header:SetHeight(headerHeight)

	if not sink then
		local icon
		if opts.icon then
			icon = header:CreateTexture(nil, 'ARTWORK')
			icon:SetSize(28, 28)
			icon:SetPoint('TOPLEFT', 0, -8)
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			icon:SetTexture(opts.icon)
		end

		local title = header:CreateFontString(nil, 'OVERLAY')
		title:SetFont(BUILib.Font, 15, '')
		if icon then
			title:SetPoint('TOPLEFT', icon, 'TOPRIGHT', 10, 0)
		elseif opts.subtitle then
			title:SetPoint('TOPLEFT', header, 'TOPLEFT', 0, -8)
		else
			title:SetPoint('LEFT', header, 'LEFT', 0, 0)
		end
		title:SetText(opts.title or '')
		title:SetTextColor(unpack(Theme.text.primary))

		if opts.subtitle then
			local subtitleText = header:CreateFontString(nil, 'OVERLAY')
			subtitleText:SetFont(BUILib.Font, 11, '')
			subtitleText:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -3)
			subtitleText:SetText(opts.subtitle)
			subtitleText:SetTextColor(unpack(Theme.text.muted))
		end
	end

	local separator = header:CreateTexture(nil, 'BACKGROUND')
	separator:SetHeight(1)
	separator:SetPoint('BOTTOMLEFT', 0, 0)
	separator:SetPoint('BOTTOMRIGHT', 0, 0)
	separator:SetColorTexture(unpack(Theme.border.default))

	local function AddToggle(labelText, value, onChange, rightOf)
		local toggle = Controls.StatusToggle(header, nil, value, onChange)
		local frame = Widget.Unwrap(toggle)
		frame:SetParent(header)
		frame:ClearAllPoints()
		if rightOf then frame:SetPoint('RIGHT', rightOf, 'LEFT', -18, 0)
		else frame:SetPoint('TOPRIGHT', header, 'TOPRIGHT', 0, -10) end
		local label = header:CreateFontString(nil, 'OVERLAY')
		label:SetFont(BUILib.Font, 11, '')
		label:SetTextColor(unpack(Theme.text.secondary))
		label:SetText(labelText)
		label:SetPoint('RIGHT', frame, 'LEFT', -8, 0)
		return toggle, label
	end

	local enableToggle, enableLabel, anchorToggle, actionButton
	if opts.iconToggles then
		local rightAnchor
		local function PlaceRight(frame)
			frame:SetParent(header)
			frame:ClearAllPoints()
			if rightAnchor then frame:SetPoint('RIGHT', rightAnchor, 'LEFT', -14, 0)
			else frame:SetPoint('TOPRIGHT', header, 'TOPRIGHT', 0, -14) end
			rightAnchor = frame
		end
		if opts.anchor then
			anchorToggle = Controls.IconToggle(header, opts.anchor.value, opts.anchor.onToggle, {
				texture = BUILib.GetLibMedia('eye'),
				tooltip = opts.anchor.tooltip or 'Show or hide the move anchor',
			})
			PlaceRight(Widget.Unwrap(anchorToggle))
		end
		if opts.action and opts.action.icon then
			if opts.action.plain then
				actionButton = Controls.Icon(header, {
					texture = BUILib.GetLibMedia(opts.action.icon), size = 20,
					tooltip = opts.action.tooltip, onClick = opts.action.onClick,
				})
			else
				actionButton = Controls.IconToggle(header, opts.action.value or false, opts.action.onClick, {
					texture = BUILib.GetLibMedia(opts.action.icon), tooltip = opts.action.tooltip,
				})
			end
			PlaceRight(Widget.Unwrap(actionButton))
		end
		enableToggle = Controls.IconToggle(header, opts.enabled, opts.onToggle, {
			texture = BUILib.GetLibMedia('enable'),
			tooltip = 'Enable or disable this module',
		})
		PlaceRight(Widget.Unwrap(enableToggle))
	else
		if opts.anchor then
			local anchorLabel
			anchorToggle, anchorLabel = AddToggle('Show Anchor', opts.anchor.value, opts.anchor.onToggle)
			enableToggle, enableLabel = AddToggle('Enable', opts.enabled, opts.onToggle, anchorLabel)
		else
			enableToggle, enableLabel = AddToggle('Enable', opts.enabled, opts.onToggle)
		end

		if opts.action then
			if opts.action.icon then
				actionButton = Controls.IconToggle(header, opts.action.value or false, opts.action.onClick, {
					texture = BUILib.GetLibMedia(opts.action.icon), tooltip = opts.action.tooltip,
				})
			else
				actionButton = Controls.Button(header, opts.action.text, opts.action.width or 110, opts.action.onClick)
			end
			local actionFrame = Widget.Unwrap(actionButton)
			actionFrame:SetParent(header)
			actionFrame:ClearAllPoints()
			actionFrame:SetPoint('RIGHT', enableLabel, 'LEFT', -16, 0)
		end
	end

	Layout.PositionInTab(tab, header, headerHeight)
	return enableToggle, anchorToggle, actionButton
end

function Layout.SettingsCard(tab, titleOrDef)
	local def
	if type(titleOrDef) == "table" then
		def = Layout.ParseControlParams(titleOrDef, tab, {topMargin = Layout.DEFAULT_MARGIN})
	else
		def = {title = titleOrDef, width = tab.width or 500, topMargin = Layout.DEFAULT_MARGIN}
	end

	local container, content = Controls.SettingsCard(tab.child, def)
	content.width = content.width or (def.width - 28)
	content.contentWidth = content.width

	if content.cardStyle == 'datasheet' and tab.lastControl and tab.lastControl.__datasheet then def.topMargin = -1 end

	local anchorTo, yOffset = tab:GetAnchor(def.topMargin)
	if anchorTo then container:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOffset)
	else container:SetPoint("TOPLEFT", Layout.DEFAULT_PADDING, yOffset - def.topMargin) end

	tab:SetLast(container, 0)
	tab:AddY(def.topMargin + (container.layoutHeight or 60))

	content.container = container
	content.parentTab = tab

	tab.__deferredRefresh = tab.__deferredRefresh or function()
		if tab.Refresh and not tab._isRefreshing then tab:Refresh() end
	end
	local originalRefresh = content.Refresh
	function content:Refresh()
		if originalRefresh then originalRefresh(self) end
		if tab.Refresh and not tab._isRefreshing then BUILib.Defer(tab.__deferredRefresh) end
	end
	content.__deferredSelfRefresh = function() content:Refresh() end
	BUILib.Defer(content.__deferredSelfRefresh)

	return content, container
end

function Layout.SettingsCardGrid(tab, config)
	config = config or {}
	local columns = config.columns or 2
	local gap = config.gap or 12
	local topMargin = config.topMargin or Layout.DEFAULT_MARGIN
	local width = tab.width or 500
	local columnWidth = math.floor((width - gap * (columns - 1)) / columns)

	local container = CreateFrame("Frame", nil, tab.child)
	container:SetWidth(width)
	container:SetHeight(1)

	local columnFrames = {}
	for columnIndex = 1, columns do
		local columnFrame = CreateFrame("Frame", nil, container)
		columnFrame:SetPoint("TOPLEFT", container, "TOPLEFT", (columnIndex - 1) * (columnWidth + gap), 0)
		columnFrame:SetWidth(columnWidth)
		columnFrame:SetHeight(1)
		columnFrames[columnIndex] = columnFrame
	end

	local fullSpanZone = CreateFrame("Frame", nil, container)
	fullSpanZone:SetWidth(width)
	fullSpanZone:SetHeight(1)
	fullSpanZone:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
	fullSpanZone:Hide()

	local anchorTo, yOffset = tab:GetAnchor(topMargin)
	if anchorTo then container:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOffset)

	else container:SetPoint("TOPLEFT", Layout.DEFAULT_PADDING, -topMargin) end

	tab:SetLast(container, 0)
	tab:AddY(topMargin)

	local grid = {
		_tab = tab, _container = container, _columnFrames = columnFrames,
		_columns = columns, _gap = gap, _colWidth = columnWidth, _width = width,
		_cardsByColumn = {}, _fullSpanEntries = {}, _fullSpanZone = fullSpanZone,
		_addCount = 0, _lastHeight = 0,
	}
	for columnIndex = 1, columns do grid._cardsByColumn[columnIndex] = {} end

	function grid:_MaxColHeight()
		local maxHeight = 0
		for columnIndex = 1, self._columns do
			local height = self._columnFrames[columnIndex]:GetHeight() or 0
			if height > maxHeight then maxHeight = height end
		end
		return maxHeight
	end

	function grid:_OtherColsMaxHeight(excludeColumn)
		local maxHeight = 0
		for columnIndex = 1, self._columns do
			if columnIndex ~= excludeColumn then
				local height = self._columnFrames[columnIndex]:GetHeight() or 0
				if height > maxHeight then maxHeight = height end
			end
		end
		return maxHeight
	end

	function grid:_SyncContainer()
		local maxHeight = self:_MaxColHeight()
		local hasSpan = #self._fullSpanEntries > 0
		local spanHeight = hasSpan and (self._fullSpanZone:GetHeight() or 0) or 0
		local total = maxHeight + (hasSpan and (self._gap + spanHeight) or 0)
		if hasSpan then
			self._fullSpanZone:ClearAllPoints()
			self._fullSpanZone:SetPoint("TOPLEFT", self._container, "TOPLEFT", 0, -(maxHeight + self._gap))
			self._fullSpanZone:Show()
		else
			self._fullSpanZone:Hide()
		end
		self._container:SetHeight(math.max(total, 1))
		self._container.layoutHeight = total
		local delta = total - self._lastHeight
		self._lastHeight = total
		if delta ~= 0 then self._tab:AddY(delta) end
		if self._tab.Refresh then BUILib.Defer(function() self._tab:Refresh() end) end
	end

	function grid:_LayoutColumn(column)
		local cards = self._cardsByColumn[column]
		local y = 0
		for _, entry in ipairs(cards) do
			entry.container:ClearAllPoints()
			entry.container:SetPoint("TOPLEFT", self._columnFrames[column], "TOPLEFT", 0, -y)
			y = y + (entry.container.layoutHeight or 60) + self._gap
		end
		if y > 0 then y = y - self._gap end
		self._columnFrames[column]:SetHeight(math.max(y, 1))
		self:_SyncContainer()
	end

	function grid:_LayoutFullSpan()
		local y = 0
		for _, entry in ipairs(self._fullSpanEntries) do
			entry.container:ClearAllPoints()
			entry.container:SetPoint("TOPLEFT", self._fullSpanZone, "TOPLEFT", 0, -y)
			y = y + (entry.container.layoutHeight or 60) + self._gap
		end
		if y > 0 then y = y - self._gap end
		self._fullSpanZone:SetHeight(math.max(y, 1))
		self:_SyncContainer()
	end

	function grid:AddCard(def)
		def = def or {}
		self._addCount = self._addCount + 1
		local targetColumn = def.column or ((self._addCount - 1) % self._columns) + 1

		local shouldSpan = def.spanFull
		if not shouldSpan and not def.column then
			local thisHeight = self._columnFrames[targetColumn]:GetHeight() or 0
			local otherMaxHeight = self:_OtherColsMaxHeight(targetColumn)
			if otherMaxHeight > 0 and thisHeight > otherMaxHeight then shouldSpan = true end
		end

		if shouldSpan then
			def.width = self._width
			local cardContainer, cardContent = Controls.SettingsCard(self._fullSpanZone, def)
			local entry = { container = cardContainer, content = cardContent, fullSpan = true }
			self._fullSpanEntries[#self._fullSpanEntries + 1] = entry
			cardContent.container = cardContainer
			cardContent.parentTab = self._tab

			local gridSelf = self
			local originalRefresh = cardContent.Refresh
			function cardContent:Refresh()
				if originalRefresh then originalRefresh(self) end
				gridSelf:_LayoutFullSpan()
			end

			self:_LayoutFullSpan()
			return cardContent, cardContainer
		end

		def.width = self._colWidth
		local cardContainer, cardContent = Controls.SettingsCard(self._columnFrames[targetColumn], def)

		local entry = { container = cardContainer, content = cardContent }
		self._cardsByColumn[targetColumn][#self._cardsByColumn[targetColumn] + 1] = entry

		cardContent.container = cardContainer
		cardContent.parentTab = self._tab

		local gridSelf = self
		local originalRefresh = cardContent.Refresh
		function cardContent:Refresh()
			if originalRefresh then originalRefresh(self) end
			gridSelf:_LayoutColumn(targetColumn)
		end

		self:_LayoutColumn(targetColumn)
		return cardContent, cardContainer
	end

	return grid
end

local DETAIL_TALL, DETAIL_SHORT = 52, 40

local function GetDetailControlWidth(item)
	local control = item.control and Widget.Unwrap(item.control)
	return control and (control:GetWidth() or 22) or 0
end

local function BuildDetailCell(container, x, cellWidth, top, rowHeight, item, withIcons, width)
	local labelX = x + 6
	if withIcons and item.icon then
		local icon = container:CreateTexture(nil, "ARTWORK")
		icon:SetSize(24, 24); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); icon:SetTexture(item.icon)
		icon:SetPoint("LEFT", container, "TOPLEFT", x + 6, -(top + rowHeight / 2))
		labelX = x + 40
	end
	local cellRight = x + cellWidth
	local titleFontString = container:CreateFontString(nil, "OVERLAY")
	titleFontString:SetFont(BUILib.Font, 13, ""); titleFontString:SetTextColor(unpack(Theme.text.primary)); titleFontString:SetText(item.title or "")
	if item.desc then
		titleFontString:SetPoint("TOPLEFT", labelX, -(top + 9))
		local descriptionText = container:CreateFontString(nil, "OVERLAY")
		descriptionText:SetFont(BUILib.Font, 11, ""); descriptionText:SetTextColor(unpack(Theme.text.muted)); descriptionText:SetText(item.desc)
		descriptionText:SetWidth(math.max(40, cellRight - GetDetailControlWidth(item) - 12 - labelX)); descriptionText:SetJustifyH("LEFT")
		descriptionText:SetPoint("TOPLEFT", labelX, -(top + 27))
	else
		titleFontString:SetPoint("LEFT", container, "TOPLEFT", labelX, -(top + rowHeight / 2))
	end
	if item.control then
		local control = Widget.Unwrap(item.control)
		control:SetParent(container); control:ClearAllPoints()
		control:SetPoint("RIGHT", container, "TOPRIGHT", -(width - cellRight) - 6, -(top + rowHeight / 2))
	end
end

function Layout.DetailSection(tab, def)
	def = def or {}
	local width = tab.width
	local items = def.items or {}
	local withIcons = def.icons
	local columnCount = (def.cols == 2) and 2 or 1
	local columnGap = 24
	local cellWidth = (columnCount == 2) and ((width - columnGap) / 2) or width
	local container = CreateFrame("Frame", nil, tab.child)
	container:SetWidth(width)

	local y = 0
	if def.title then
		local tick = container:CreateTexture(nil, "OVERLAY")
		tick:SetTexture(Widget.WHITE); tick:SetVertexColor(Theme.GetAccent()); tick:SetSize(2, 12)
		tick:SetPoint("TOPLEFT", 2, -4)
		Theme.RegisterAccentElement(tick, function(element, red, green, blue) element:SetVertexColor(red, green, blue, 1) end)
		local heading = container:CreateFontString(nil, "OVERLAY")
		heading:SetFont(BUILib.Font, 12, ""); heading:SetPoint("LEFT", tick, "RIGHT", 8, 0)
		heading:SetText(string.upper(def.title)); heading:SetTextColor(unpack(Theme.text.secondary))
		y = 26
	end

	local rows, currentRow = {}, {}
	for _, item in ipairs(items) do
		local full = (columnCount == 2) and (GetDetailControlWidth(item) > 80) or (columnCount == 1)
		if full then
			if #currentRow > 0 then rows[#rows + 1] = currentRow; currentRow = {} end
			rows[#rows + 1] = { item, full = true }
		else
			currentRow[#currentRow + 1] = item
			if #currentRow == columnCount then rows[#rows + 1] = currentRow; currentRow = {} end
		end
	end
	if #currentRow > 0 then rows[#rows + 1] = currentRow end

	for rowIndex, row in ipairs(rows) do
		local rowHeight = DETAIL_SHORT
		for _, item in ipairs(row) do if item.desc then rowHeight = DETAIL_TALL end end
		if row.full then
			BuildDetailCell(container, 0, width, y, rowHeight, row[1], withIcons, width)
		else
			for cellIndex, item in ipairs(row) do
				BuildDetailCell(container, (cellIndex - 1) * (cellWidth + columnGap), cellWidth, y, rowHeight, item, withIcons, width)
			end
			if columnCount == 2 and #row == 2 then
				local verticalSeparator = container:CreateTexture(nil, "BACKGROUND")
				verticalSeparator:SetWidth(1); verticalSeparator:SetColorTexture(1, 1, 1, 0.05)
				verticalSeparator:SetPoint("TOP", container, "TOPLEFT", cellWidth + columnGap / 2, -(y + 6))
				verticalSeparator:SetPoint("BOTTOM", container, "TOPLEFT", cellWidth + columnGap / 2, -(y + rowHeight - 6))
			end
		end
		y = y + rowHeight
		if rowIndex < #rows then
			local separator = container:CreateTexture(nil, "BACKGROUND")
			separator:SetHeight(1); separator:SetColorTexture(1, 1, 1, 0.05)
			separator:SetPoint("TOPLEFT", 6, -y); separator:SetPoint("TOPRIGHT", -6, -y)
		end
	end

	container:SetHeight(y + 6)
	Layout.PositionInTab(tab, container, y + 6, def.topMargin or 14)
	if tab.Refresh then tab:Refresh() end
	return container
end
