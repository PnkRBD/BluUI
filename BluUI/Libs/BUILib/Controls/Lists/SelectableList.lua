local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE

local PADDING = 16
local INCLUDE_FROM_RIGHT = 110

function Controls.SelectableList(parent, options)
	options = options or {}
	local host = Widget.Unwrap(parent)
	local width = options.width or 600
	local rowHeight = options.rowHeight or 46
	local items = options.items or {}
	local includeFromRight = options.hideStatus and 44 or INCLUDE_FROM_RIGHT

	local accentRed, accentGreen, accentBlue = Theme.GetAccent()

	local panel = CreateFrame("Frame", nil, host)
	panel:SetWidth(width)

	local rows = {}
	local summaryText, Refresh

	local function SelectedKeys()
		local keys = {}
		for _, row in ipairs(rows) do
			if row.enabled and row.checked then keys[#keys + 1] = row.key end
		end
		return keys
	end

	local function SetAll(value)
		for _, row in ipairs(rows) do
			if row.enabled then row:SetChecked(value) end
		end
		Refresh()
	end

	local top = PADDING

	if options.title then
		local title = Controls.Text(panel, options.title, FONT_SIZE + 1, Theme.text.primary)
		title:SetPoint("TOPLEFT", PADDING, -top)
		top = top + 20
	end
	if options.description then
		local descriptionText = Controls.Text(panel, options.description, FONT_SIZE - 1, Theme.text.muted)
		descriptionText:SetPoint("TOPLEFT", PADDING, -top)
		descriptionText:SetWidth(width - PADDING * 2 - 160)
		descriptionText:SetJustifyH("LEFT")
		top = top + 18
	end

	top = top + 10

	local nameColumnLabel = Controls.Text(panel, options.nameLabel or "Name", FONT_SIZE - 2, Theme.text.muted)
	nameColumnLabel:SetPoint("TOPLEFT", PADDING, -top)
	local includeColumnLabel = Controls.Text(panel, options.includeLabel or "Include", FONT_SIZE - 2, Theme.text.muted)
	includeColumnLabel:SetPoint("TOP", panel, "TOPRIGHT", -includeFromRight, -top)
	if not options.hideStatus then
		local statusColumnLabel = Controls.Text(panel, options.statusLabel or "Status", FONT_SIZE - 2, Theme.text.muted)
		statusColumnLabel:SetPoint("TOPRIGHT", -PADDING, -top)
	end

	local deselect = Controls.LinkText(panel, options.deselectAllText or "Deselect All", function() SetAll(false) end)
	local selectAll = Controls.LinkText(panel, options.selectAllText or "Select All", function() SetAll(true) end)
	if options.hideStatus then
		local centerY = -top - nameColumnLabel:GetStringHeight() / 2
		Widget.Unwrap(deselect):SetPoint("RIGHT", panel, "TOPRIGHT", -PADDING, centerY)
		Widget.Unwrap(selectAll):SetPoint("RIGHT", Widget.Unwrap(deselect), "LEFT", -16, 0)
	else
		Widget.Unwrap(deselect):SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING, -PADDING)
		Widget.Unwrap(selectAll):SetPoint("TOPRIGHT", Widget.Unwrap(deselect), "TOPLEFT", -16, 0)
	end

	top = top + 20

	local headerRule = panel:CreateTexture(nil, "ARTWORK")
	headerRule:SetTexture(Widget.WHITE); headerRule:SetVertexColor(1, 1, 1, 0.08); headerRule:SetHeight(1)
	headerRule:SetPoint("TOPLEFT", PADDING, -top)
	headerRule:SetPoint("TOPRIGHT", -PADDING, -top)
	top = top + 6

	for index, item in ipairs(items) do
		local enabled = item.enabled ~= false

		local row = CreateFrame("Button", nil, panel)
		row:SetHeight(rowHeight)
		row:SetPoint("TOPLEFT", PADDING, -top)
		row:SetPoint("TOPRIGHT", -PADDING, -top)

		local highlight = row:CreateTexture(nil, "BACKGROUND")
		highlight:SetAllPoints(); highlight:SetColorTexture(1, 1, 1, 0.03); highlight:Hide()
		row:SetScript("OnEnter", function() highlight:Show() end)
		row:SetScript("OnLeave", function() highlight:Hide() end)

		local title = Controls.Text(row, item.title or item.key, FONT_SIZE, enabled and Theme.text.primary or Theme.text.disabled)
		if item.desc then
			title:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -8)
			local descriptionText = Controls.Text(row, item.desc, FONT_SIZE - 2, enabled and Theme.text.muted or Theme.text.disabled)
			descriptionText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
			descriptionText:SetWidth(width - includeFromRight - PADDING * 2 - 20)
			descriptionText:SetJustifyH("LEFT")
		else
			title:SetPoint("LEFT", row, "LEFT", 4, 0)
		end

		if not options.hideStatus then
			local statusRed, statusGreen, statusBlue
			if item.statusColor then
				statusRed, statusGreen, statusBlue = item.statusColor[1], item.statusColor[2], item.statusColor[3]
			elseif enabled then
				statusRed, statusGreen, statusBlue = accentRed, accentGreen, accentBlue
			else
				statusRed, statusGreen, statusBlue = Theme.text.disabled[1], Theme.text.disabled[2], Theme.text.disabled[3]
			end
			local status = Controls.Text(row, item.status or "", FONT_SIZE - 1, { statusRed, statusGreen, statusBlue, 1 })
			status:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		end

		local checkbox = Controls.StampCheckbox(row, nil, item.checked == true, function(value)
			rows[index].checked = value
			if options.onChange then options.onChange(item.key, value, panel) end
			Refresh()
		end, 0, enabled)
		local checkboxFrame = Widget.Unwrap(checkbox)
		checkboxFrame:ClearAllPoints()
		checkboxFrame:SetPoint("CENTER", row, "RIGHT", -(includeFromRight - PADDING), 0)

		rows[index] = {
			key = item.key,
			enabled = enabled,
			checked = item.checked == true,
			SetChecked = function(self, value)
				self.checked = value
				if checkbox.SetValue then checkbox:SetValue(value) end
			end,
		}

		top = top + rowHeight

		if index < #items then
			local rowRule = panel:CreateTexture(nil, "ARTWORK")
			rowRule:SetTexture(Widget.WHITE); rowRule:SetVertexColor(1, 1, 1, 0.04); rowRule:SetHeight(1)
			rowRule:SetPoint("TOPLEFT", PADDING, -top)
			rowRule:SetPoint("TOPRIGHT", -PADDING, -top)
		end
	end

	if not options.hideSummary or options.actionText then
		top = top + 12

		if not options.hideSummary then
			local footerRule = panel:CreateTexture(nil, "ARTWORK")
			footerRule:SetTexture(Widget.WHITE); footerRule:SetVertexColor(1, 1, 1, 0.06); footerRule:SetHeight(1)
			footerRule:SetPoint("TOPLEFT", PADDING, -top)
			footerRule:SetPoint("TOPRIGHT", -PADDING, -top)
			top = top + 18

			summaryText = Controls.Text(panel, "", FONT_SIZE - 1, Theme.text.secondary)
			summaryText:SetPoint("LEFT", panel, "TOPLEFT", PADDING, -(top + 14))
		end

		if options.actionText then
			local actionButton = Controls.Button(panel, options.actionText, options.actionWidth or 180, function()
				if options.onAction then options.onAction(SelectedKeys(), panel) end
			end, { radius = 6 })
			Widget.Unwrap(actionButton):SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING, -top)
		end
		top = top + 44
	end

	panel:SetHeight(top + PADDING)

	function Refresh()
		if not summaryText then return end
		local selectedCount = #SelectedKeys()
		local total = #rows
		if type(options.summary) == "function" then
			summaryText:SetText(options.summary(selectedCount, total))
		else
			summaryText:SetText((options.summaryFormat or "%d of %d selected"):format(selectedCount, total))
		end
	end
	Refresh()

	function panel:SetItemChecked(key, value)
		for _, row in ipairs(rows) do
			if row.key == key then row:SetChecked(value) end
		end
		Refresh()
	end
	function panel:GetSelected() return SelectedKeys() end

	return Widget.Wrap(panel)
end
