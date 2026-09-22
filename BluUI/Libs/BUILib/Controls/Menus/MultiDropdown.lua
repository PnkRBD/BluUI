local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local DEFAULT_FONT_SIZE = BUILib.FONT_SIZE
local CONTROL_HEIGHT = BUILib.CONTROL_HEIGHT
local LIB_ROW_HEIGHT = BUILib.ROW_HEIGHT
local LABEL_OFFSET = BUILib.LABEL_OFFSET
local ROW_HEIGHT = 22
local ICON_ROW_HEIGHT = 22
local ICON_SIZE = 12
local unpack = unpack

function Controls.MultiDropdown(parent, label, items, selected, callback, tooltip, width, maxVisible, options)
	width = width or 180; maxVisible = maxVisible or 10
	items = items or {}; selected = selected or {}
	local actions = (options and options.actions) or {}
	local state = {selected = selected, items = items, width = width}
	local buttonHeight = label and CONTROL_HEIGHT or LIB_ROW_HEIGHT
	local containerHeight = label and (CONTROL_HEIGHT + LABEL_OFFSET) or buttonHeight
	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	container:SetSize(width, containerHeight)

	if label then
		container.label = Controls.Text(container, label, DEFAULT_FONT_SIZE, Theme.text.primary)
		container.label:SetPoint("TOPLEFT")
	end

	local buttonWidget = Widget.New(container, "Button", nil, {raw = true, size = {width, buttonHeight}})
	local button = buttonWidget.frame; button:SetPoint("BOTTOMLEFT")
	local SetButtonHighlighted = Widget.RoundedInput(button)
	local buttonText = button:CreateFontString(nil, "OVERLAY")
	buttonText:SetFont(BUILib.Font, 12, "")
	buttonText:SetPoint("LEFT", 10, 0); buttonText:SetPoint("RIGHT", -25, 0)
	buttonText:SetJustifyH("LEFT"); buttonText:SetTextColor(unpack(Theme.text.primary))
	local expandIcon = button:CreateTexture(nil, "OVERLAY")
	expandIcon:SetTexture(BUILib.GetLibMedia("dropdown"))
	expandIcon:SetSize(11, 11); expandIcon:SetPoint("RIGHT", -10, 0)
	expandIcon:SetVertexColor(unpack(Theme.text.secondary))

	local function SetExpandOpen(isOpen) expandIcon:SetTexCoord(0, 1, isOpen and 1 or 0, isOpen and 0 or 1) end
	SetExpandOpen(false)

	local function CollapseExpandIcon() SetExpandOpen(false) end
	local menu, scrollFrame, scrollChild, scrollLogic, PositionMenu = Widget.DropdownMenuScaffold(parentFrame, button, width, ROW_HEIGHT * 2, CollapseExpandIcon)

	local function CountSelected()
		local validKeys = {}
		for _, item in ipairs(state.items) do
			local itemValue = type(item) == "table" and item.value or item
			validKeys[itemValue] = true
		end
		local selectedCount = 0
		for key in pairs(state.selected) do
			if validKeys[key] then selectedCount = selectedCount + 1 end
		end
		return selectedCount
	end

	local function UpdateButtonDisplay()
		local count = CountSelected()
		local total = #state.items
		if count == 0 then
			buttonText:SetText("None selected")
		elseif count == total then
			buttonText:SetText("All selected")
		else
			buttonText:SetText(count .. " of " .. total .. " selected")
		end
	end

	local rowPool = {}

	local function GetRow(index)
		if rowPool[index] then rowPool[index]:Show(); return rowPool[index] end
		local row = CreateFrame("Button", nil, scrollChild); row:SetHeight(ROW_HEIGHT)

		row.box = CreateFrame("Frame", nil, row, "BackdropTemplate")
		row.box:SetSize(14, 14)
		row.box:SetBackdrop(Widget.BACKDROP)
		row.box:SetBackdropColor(unpack(Theme.bg.input))
		row.box:SetBackdropBorderColor(unpack(Theme.border.input))
		row.box:SetPoint("LEFT", 6, 0)

		row.check = row.box:CreateTexture(nil, "OVERLAY")
		row.check:SetTexture(BUILib.GetLibMedia("check"))
		row.check:SetSize(9, 9)
		row.check:SetPoint("CENTER")

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(ICON_SIZE, ICON_SIZE)
		row.icon:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.icon:Hide()

		row.text = row:CreateFontString(nil, "OVERLAY")
		row.text:SetFont(BUILib.Font, 11, "")
		row.text:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
		row.text:SetPoint("RIGHT", -6, 0)
		row.text:SetJustifyH("LEFT")

		row.hl = Widget.Create(row, 0, 0, 0, 0); row.hl:SetAllPoints(); row.hl:SetDrawLayer("BACKGROUND")
		row:SetScript("OnEnter", function(rowButton)
			Widget.SetColor(rowButton.hl, Theme.GetAccent()); rowButton.hl:SetAlpha(0.15)
			rowButton.box:SetBackdropBorderColor(Theme.GetAccent())
		end)
		row:SetScript("OnLeave", function(rowButton)
			rowButton.hl:SetAlpha(0)
			rowButton.box:SetBackdropBorderColor(unpack(Theme.border.input))
		end)

		rowPool[index] = row; return row
	end

	local function UpdateRowVisual(row, checked)
		local accentRed, accentGreen, accentBlue = Theme.GetAccent()
		if checked then
			row.check:Show()
			Widget.SetColor(row.check, accentRed, accentGreen, accentBlue, 1)
			row.text:SetTextColor(unpack(Theme.text.primary))
			row.icon:SetDesaturated(false)
			row.icon:SetVertexColor(1, 1, 1)
		else
			row.check:Hide()
			row.text:SetTextColor(unpack(Theme.text.secondary))
			row.icon:SetDesaturated(true)
			row.icon:SetVertexColor(0.62, 0.62, 0.66)
		end
	end

	local function ApplyRowIcon(row, icon)
		row.text:ClearAllPoints()
		row.text:SetPoint("RIGHT", -6, 0)
		row.text:SetJustifyH("LEFT")
		if icon then
			row.icon:SetTexture(icon)
			row.icon:Show()
			row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
		else
			row.icon:Hide()
			row.text:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
		end
	end

	local actionPool = {}
	local divider
	local BuildMenu

	local function GetActionRow(index)
		if actionPool[index] then actionPool[index]:Show(); return actionPool[index] end
		local row = CreateFrame("Button", nil, scrollChild); row:SetHeight(ROW_HEIGHT)
		row.text = row:CreateFontString(nil, "OVERLAY")
		row.text:SetFont(BUILib.Font, 11, "")
		row.text:SetPoint("LEFT",  6, 0)
		row.text:SetPoint("RIGHT", -6, 0)
		row.text:SetJustifyH("LEFT")
		row.hl = Widget.Create(row, 0, 0, 0, 0); row.hl:SetAllPoints(); row.hl:SetDrawLayer("BACKGROUND")
		row:SetScript("OnEnter", function(rowButton)
			Widget.SetColor(rowButton.hl, Theme.GetAccent()); rowButton.hl:SetAlpha(0.15)
			local accentRed, accentGreen, accentBlue = Theme.GetAccent(); rowButton.text:SetTextColor(accentRed, accentGreen, accentBlue, 1)
		end)
		row:SetScript("OnLeave", function(rowButton)
			rowButton.hl:SetAlpha(0)
			rowButton.text:SetTextColor(unpack(Theme.text.primary))
		end)
		actionPool[index] = row; return row
	end

	local function SetSelected(selectionMap)
		state.selected = selectionMap or {}
		UpdateButtonDisplay()
		BuildMenu()
		if callback then callback(state.selected) end
	end

	function BuildMenu()
		for _, row in ipairs(rowPool) do row:Hide() end
		for _, row in ipairs(actionPool) do row:Hide() end
		if divider then divider:Hide() end
		local offsetY = 0; local menuWidth = button:GetWidth()
		menu:SetWidth(menuWidth); scrollChild:SetWidth(menuWidth - Widget.PANEL_INSET * 2)

		for actionIndex, action in ipairs(actions) do
			local row = GetActionRow(actionIndex)
			row:SetPoint("TOPLEFT", 0, -offsetY); row:SetPoint("TOPRIGHT", 0, -offsetY)
			row.text:SetText(action.text or "")
			row.text:SetTextColor(unpack(Theme.text.primary))
			row:SetScript("OnClick", function()
				if action.onClick then action.onClick(state.items, SetSelected) end
			end)
			offsetY = offsetY + ROW_HEIGHT
		end
		if #actions > 0 then
			divider = divider or scrollChild:CreateTexture(nil, "OVERLAY")
			divider:SetTexture(Widget.WHITE)
			divider:SetVertexColor(unpack(Theme.border.input))
			divider:ClearAllPoints()
			divider:SetPoint("TOPLEFT",  4, -offsetY - 2)
			divider:SetPoint("TOPRIGHT", -4, -offsetY - 2)
			divider:SetHeight(1)
			divider:Show()
			offsetY = offsetY + 5
		end

		local iconMode = false
		for _, item in ipairs(state.items) do
			if type(item) == "table" and item.icon then iconMode = true; break end
		end
		local rowHeight = iconMode and ICON_ROW_HEIGHT or ROW_HEIGHT

		for itemIndex, item in ipairs(state.items) do
			local itemValue, displayText, itemIcon
			if type(item) == "table" then
				itemValue = item.value or item[1]; displayText = item.text or item.label or item[2]; itemIcon = item.icon
			else itemValue, displayText = item, item end
			local row = GetRow(itemIndex)
			row:SetHeight(rowHeight)
			row:SetPoint("TOPLEFT", 0, -offsetY); row:SetPoint("TOPRIGHT", 0, -offsetY)
			ApplyRowIcon(row, itemIcon)
			row.text:SetText(displayText)
			row.val = itemValue
			UpdateRowVisual(row, state.selected[itemValue])
			row:SetScript("OnClick", function()
				state.selected[itemValue] = not state.selected[itemValue] or nil
				UpdateRowVisual(row, state.selected[itemValue])
				UpdateButtonDisplay()
				if callback then callback(state.selected) end
			end)
			offsetY = offsetY + rowHeight
		end
		scrollChild:SetHeight(offsetY)
		local visibleItems = math.min(#state.items, math.max(1, maxVisible - #actions))
		local dividerHeight = (#actions > 0) and 5 or 0
		menu:SetHeight(visibleItems * rowHeight + #actions * ROW_HEIGHT + Widget.PANEL_INSET * 2 + dividerHeight)
		menu._targetH = menu:GetHeight()
		scrollFrame:SetVerticalScroll(0); BUILib.Defer(scrollLogic.UpdateThumb)
	end

	button:SetScript("OnClick", function()
		if menu:IsShown() then Widget.HideMenuAnimated(menu); SetExpandOpen(false)
		else BuildMenu(); PositionMenu(); Widget.ShowMenuAnimated(menu); SetExpandOpen(true) end
	end)
	button:SetScript("OnEnter", function() SetButtonHighlighted(true); expandIcon:SetVertexColor(1, 1, 1) end)
	button:SetScript("OnLeave", function() SetButtonHighlighted(false); expandIcon:SetVertexColor(unpack(Theme.text.secondary)) end)
	if tooltip then Widget.Tooltip(button, tooltip) end
	UpdateButtonDisplay()

	function container:GetValue() return state.selected end
	function container:SetValue(selectionMap) state.selected = selectionMap; UpdateButtonDisplay() end
	function container:CloseMenu()
		if menu:IsShown() then Widget.HideMenuAnimated(menu); SetExpandOpen(false) end
	end
	function container:SetItems(newItems, newSelected)
		state.items = newItems
		if newSelected then state.selected = newSelected end
		UpdateButtonDisplay()
		if menu:IsShown() then BuildMenu() end
	end
	local nativeSetWidth = container.SetWidth
	function container:SetWidth(newWidth)
		state.width = newWidth; nativeSetWidth(container, newWidth)
		button:SetWidth(newWidth); menu:SetWidth(newWidth); scrollChild:SetWidth(newWidth - Widget.PANEL_INSET * 2)
	end
	return Widget.Wrap(container)
end
