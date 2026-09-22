local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE
local CONTROL_ROW_HEIGHT = BUILib.ROW_HEIGHT
local LABEL_OFFSET = BUILib.LABEL_OFFSET
local ROW_HEIGHT = 22
local ICON_ROW_HEIGHT = 22
local ICON_SIZE = 12
local BUTTON_ICON_INSET = 4
local ICON_TEXT_GAP = 8
local BUTTON_ICON_TEXT_OFFSET = BUTTON_ICON_INSET + ICON_SIZE + ICON_TEXT_GAP
local ROW_ICON_INSET = BUTTON_ICON_INSET - Widget.PANEL_INSET
local ROW_ICON_TEXT_OFFSET = ROW_ICON_INSET + ICON_SIZE + ICON_TEXT_GAP
local CHECK_SIZE = 12
local unpack = unpack

local ShowMenu = Widget.ShowMenuAnimated
local HideMenu = Widget.HideMenuAnimated

local STRATA_ORDER = {BACKGROUND=0,LOW=1,MEDIUM=2,HIGH=3,DIALOG=4,FULLSCREEN_DIALOG=5,TOOLTIP=6}

function Widget.DropdownMenuScaffold(parentFrame, anchorButton, menuWidth, scrollStep, onClose)
	local menuWidget = Widget.New({frame = UIParent}, "Frame", nil, {raw = true, size = {menuWidth, 100}})
	local menu = menuWidget.frame
	Widget.RoundedPanel(menu, Widget.INPUT_RADIUS, nil, Theme.border.light)
	local parentStrata = parentFrame:GetFrameStrata(); local parentLevel = parentFrame:GetFrameLevel()
	local popupStrata = BUILib.GetPopupStrata(); local popupLevel = BUILib.GetPopupLevel()
	local useParent = (STRATA_ORDER[parentStrata] or 0) > (STRATA_ORDER[popupStrata] or 0) or
		((STRATA_ORDER[parentStrata] or 0) == (STRATA_ORDER[popupStrata] or 0) and parentLevel >= popupLevel)
	menu:SetFrameStrata(useParent and parentStrata or popupStrata)
	menu:SetFrameLevel((useParent and parentLevel or popupLevel) + 50)
	menu:SetClampedToScreen(true); menu:Hide()

	local panelInset = Widget.PANEL_INSET
	local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
	scrollFrame:SetPoint("TOPLEFT", panelInset, -panelInset); scrollFrame:SetPoint("BOTTOMRIGHT", -panelInset, panelInset)
	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetWidth(menuWidth - panelInset * 2); scrollFrame:SetScrollChild(scrollChild)
	local scrollTrack = CreateFrame("Frame", nil, menu, "BackdropTemplate")
	scrollTrack:SetWidth(6); scrollTrack:SetPoint("TOPRIGHT", -panelInset, -panelInset); scrollTrack:SetPoint("BOTTOMRIGHT", -panelInset, panelInset)
	scrollTrack:SetBackdrop({bgFile = Widget.WHITE}); scrollTrack:SetBackdropColor(0.1, 0.1, 0.1, 0.8); scrollTrack:Hide()
	local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
	scrollThumb:SetWidth(6); scrollThumb:SetBackdrop({bgFile = Widget.WHITE})
	scrollThumb:SetBackdropColor(0.4, 0.4, 0.4, 1); scrollThumb:SetPoint("TOP"); scrollThumb:SetHeight(20)
	local scrollLogic = Widget.ScrollLogic(scrollFrame, scrollChild, scrollTrack, scrollThumb, {
		step = scrollStep,
		onShow = function(needs)
			scrollFrame:SetPoint("BOTTOMRIGHT", needs and -(panelInset + 8) or -panelInset, panelInset)
		end,
	})
	menu:EnableMouseWheel(true); menu:SetScript("OnMouseWheel", function(_, delta) scrollLogic.DoScroll(delta) end)

	local function PositionMenu()
		menu:ClearAllPoints()
		local bottom = anchorButton:GetBottom(); local menuHeight = menu:GetHeight() or 100
		if not bottom or bottom < menuHeight + 50 then menu:SetPoint("BOTTOMLEFT", anchorButton, "TOPLEFT", 0, 2)
		else menu:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -2) end
	end

	menu:SetScript("OnShow", function(self)
		self:Raise()
		BUILib._popupCount = (BUILib._popupCount or 0) + 1
		self.checkFrame = self.checkFrame or CreateFrame("Frame")
		self.checkFrame:SetScript("OnUpdate", function(updateFrame)
			if not (anchorButton:IsMouseOver() or menu:IsMouseOver()) then
				if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
					HideMenu(menu); onClose(); updateFrame:SetScript("OnUpdate", nil)
				end
			end
		end)
	end)
	menu:SetScript("OnHide", function(self)
		BUILib._popupCount = math.max(0, (BUILib._popupCount or 0) - 1)
		if self.checkFrame then self.checkFrame:SetScript("OnUpdate", nil) end
	end)

	return menu, scrollFrame, scrollChild, scrollLogic, PositionMenu
end

function Controls.Dropdown(parent, label, items, selected, callback, tooltip, width, maxVisible)
	width = width or 200; maxVisible = maxVisible or 10
	items = items or {}
	if selected == nil and items[1] then
		local first = items[1]
		if type(first) == "table" then selected = first.value or first[1]
		else selected = first end
	end
	local state = {value = selected, items = items, width = width}
	local buttonHeight = CONTROL_ROW_HEIGHT
	local containerHeight = label and (CONTROL_ROW_HEIGHT + LABEL_OFFSET) or buttonHeight
	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	container:SetSize(width, containerHeight)
	local function HasIcons()
		for _, item in ipairs(state.items) do
			if type(item) == "table" and item.icon then return true end
		end
		return false
	end
	local iconMode = HasIcons()
	local rowHeight = iconMode and ICON_ROW_HEIGHT or ROW_HEIGHT
	if label then
		container.label = Controls.Text(container, label, FONT_SIZE, Theme.text.primary)
		container.label:SetPoint("TOPLEFT")
	end
	local buttonWidget = Widget.New(container, "Button", nil, {raw = true, size = {width, buttonHeight}})
	local button = buttonWidget.frame; button:SetPoint("BOTTOMLEFT")
	local SetButtonHighlighted = Widget.RoundedInput(button)
	local buttonIcon = button:CreateTexture(nil, "ARTWORK")
	buttonIcon:SetSize(ICON_SIZE, ICON_SIZE); buttonIcon:SetPoint("LEFT", BUTTON_ICON_INSET, 0); buttonIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92); buttonIcon:SetShown(iconMode)
	local buttonText = button:CreateFontString(nil, "OVERLAY")
	buttonText:SetFont(BUILib.Font, 12, "")
	buttonText:SetPoint("LEFT", iconMode and BUTTON_ICON_TEXT_OFFSET or 10, 0); buttonText:SetPoint("RIGHT", -25, 0)
	buttonText:SetJustifyH("LEFT"); buttonText:SetTextColor(unpack(Theme.text.primary))
	local expandIcon = button:CreateTexture(nil, "OVERLAY")
	expandIcon:SetTexture(BUILib.GetLibMedia("dropdown"))
	expandIcon:SetSize(11, 11); expandIcon:SetPoint("RIGHT", -10, 0)
	expandIcon:SetVertexColor(unpack(Theme.text.secondary))
	local function SetExpandOpen(isOpen) expandIcon:SetTexCoord(0, 1, isOpen and 1 or 0, isOpen and 0 or 1) end
	SetExpandOpen(false)
	local function CollapseExpandIcon() SetExpandOpen(false) end
	local menu, scrollFrame, scrollChild, scrollLogic, PositionMenu = Widget.DropdownMenuScaffold(parentFrame, button, width, rowHeight * 2, CollapseExpandIcon)
	local rowPool = {}
	local function GetDisplay(value)
		for _, item in ipairs(state.items) do
			if type(item) == "table" then
				if item.value == value then return item.text or item.label, item.icon end
				if item[1] == value then return item[2] or item.label, item.icon end
			elseif item == value then return item, nil end
		end
		return value or "", nil
	end
	local function GetFontPath(value)
		for _, item in ipairs(state.items) do
			if type(item) == "table" and (item.value == value or item[1] == value) then return item.fontPath end
		end
	end
	local function UpdateButtonDisplay()
		local text, icon = GetDisplay(state.value)
		buttonText:SetText(text)
		if iconMode and icon then buttonIcon:SetTexture(icon); buttonIcon:Show()
		else buttonIcon:Hide() end
		local fontPath = GetFontPath(state.value)
		buttonText:SetFont(fontPath or BUILib.Font, FONT_SIZE, "")
	end
	local function ClearRowPool()
		for index = #rowPool, 1, -1 do
			local row = rowPool[index]
			row:Hide(); row:SetParent(nil)
			rowPool[index] = nil
		end
	end
	local function GetRow(index)
		if rowPool[index] then rowPool[index]:SetHeight(rowHeight); rowPool[index]:Show(); return rowPool[index] end
		local row = CreateFrame("Button", nil, scrollChild); row:SetHeight(rowHeight)
		if iconMode then
			row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(); row.bg:SetColorTexture(0, 0, 0, 0)
			row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(ICON_SIZE, ICON_SIZE); row.icon:SetPoint("LEFT", ROW_ICON_INSET, 0)
			row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			row.text = row:CreateFontString(nil, "OVERLAY"); row.text:SetFont(BUILib.Font, 11, ""); row.text:SetPoint("LEFT", ROW_ICON_TEXT_OFFSET, 0)
			row.check = row:CreateTexture(nil, "OVERLAY")
			row.check:SetTexture(BUILib.GetLibMedia("check"))
			row.check:SetSize(CHECK_SIZE, CHECK_SIZE); row.check:SetPoint("RIGHT", -10, 0)
			row:SetScript("OnEnter", function(rowButton) rowButton.bg:SetColorTexture(unpack(Theme.bg.hover)) end)
			row:SetScript("OnLeave", function(rowButton)
				if rowButton._selected then
					local red, green, blue = Theme.GetAccent()
					rowButton.bg:SetColorTexture(red, green, blue, 0.15)
				else
					rowButton.bg:SetColorTexture(0, 0, 0, 0)
				end
			end)
		else
			row.text = row:CreateFontString(nil, "OVERLAY"); row.text:SetFont(BUILib.Font, 11, ""); row.text:SetPoint("LEFT", 6, 0)
			row.hl = Widget.Create(row, Theme.GetAccent()); row.hl:SetAllPoints(); row.hl:SetDrawLayer("BACKGROUND"); row.hl:SetAlpha(0.18); row.hl:Hide()
			row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 1)
			row.hover:SetAllPoints(); row.hover:SetColorTexture(unpack(Theme.bg.hover)); row.hover:Hide()
			row:SetScript("OnEnter", function(rowButton) rowButton.hover:Show(); rowButton.text:SetTextColor(1, 1, 1) end)
			row:SetScript("OnLeave", function(rowButton)
				rowButton.hover:Hide()
				if not rowButton._selected then rowButton.text:SetTextColor(unpack(Theme.text.secondary)) end
			end)
		end
		rowPool[index] = row; return row
	end
	local function BuildMenu()
		for _, row in ipairs(rowPool) do row:Hide() end
		local offsetY = 0; local menuWidth = button:GetWidth()
		menu:SetWidth(menuWidth); scrollChild:SetWidth(menuWidth - Widget.PANEL_INSET * 2)
		for itemIndex, item in ipairs(state.items) do
			local value, display, itemIcon
			if type(item) == "table" then
				value = item.value or item[1]; display = item.text or item.label or item[2]; itemIcon = item.icon
			else value, display = item, item end
			local row = GetRow(itemIndex)
			row:SetPoint("TOPLEFT", 0, -offsetY); row:SetPoint("TOPRIGHT", 0, -offsetY)
			row.text:SetText(display)
			if iconMode then
				local isSelected = value == state.value
				row._selected = isSelected
				row.text:SetTextColor(unpack(Theme.text.primary))
				row.icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
				local red, green, blue = Theme.GetAccent()
				row.check:SetVertexColor(red, green, blue, 1)
				row.check:SetShown(isSelected)
				if isSelected then row.bg:SetColorTexture(red, green, blue, 0.15)
				else row.bg:SetColorTexture(0, 0, 0, 0) end
			else
				local isSelected = value == state.value
				row._selected = isSelected
				if type(item) == "table" and item.fontPath then row.text:SetFont(item.fontPath, 11, "")
				else row.text:SetFont(BUILib.Font, 11, "") end
				local red, green, blue = Theme.GetAccent(); Widget.SetColor(row.hl, red, green, blue, 0.18)
				row.hl:SetShown(isSelected)
				row.text:SetTextColor(unpack(isSelected and Theme.text.primary or Theme.text.secondary))
			end
			row:SetScript("OnClick", function()
				state.value = value; UpdateButtonDisplay()
				local left, top = menu:GetLeft(), menu:GetTop()
				if left and top then
					menu:ClearAllPoints()
					menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
				end
				HideMenu(menu); SetExpandOpen(false)
				if callback then callback(value, item) end
			end)
			offsetY = offsetY + rowHeight
		end
		scrollChild:SetHeight(offsetY)
		menu:SetHeight(math.min(#state.items, maxVisible) * rowHeight + Widget.PANEL_INSET * 2)
		menu._targetH = menu:GetHeight()
		scrollFrame:SetVerticalScroll(0); BUILib.Defer(scrollLogic.UpdateThumb)
	end
	button:SetScript("OnClick", function()
		if menu:IsShown() then HideMenu(menu); SetExpandOpen(false)
		else BuildMenu(); PositionMenu(); ShowMenu(menu); SetExpandOpen(true) end
	end)
	button:SetScript("OnEnter", function() SetButtonHighlighted(true); expandIcon:SetVertexColor(1, 1, 1) end)
	button:SetScript("OnLeave", function() SetButtonHighlighted(false); expandIcon:SetVertexColor(unpack(Theme.text.secondary)) end)
	if tooltip then Widget.Tooltip(button, tooltip) end
	UpdateButtonDisplay()
	function container:GetValue() return state.value end
	function container:SetValue(value) state.value = value; UpdateButtonDisplay() end
	function container:SetItems(newItems)
		state.items = newItems; iconMode = HasIcons(); rowHeight = iconMode and ICON_ROW_HEIGHT or ROW_HEIGHT
		ClearRowPool()
		buttonIcon:SetShown(iconMode); buttonText:SetPoint("LEFT", iconMode and BUTTON_ICON_TEXT_OFFSET or 10, 0)
		buttonText:SetTextColor(unpack(Theme.text.primary))
		UpdateButtonDisplay()
	end
	local nativeSetWidth = container.SetWidth
	function container:SetWidth(newWidth)
		state.width = newWidth; nativeSetWidth(container, newWidth)
		button:SetWidth(newWidth); menu:SetWidth(newWidth); scrollChild:SetWidth(newWidth - Widget.PANEL_INSET * 2)
	end
	return Widget.Wrap(container)
end
