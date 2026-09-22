local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE
local CONTROL_HEIGHT = BUILib.CONTROL_HEIGHT
local ROW_HEIGHT = BUILib.ROW_HEIGHT
local LABEL_OFFSET = BUILib.LABEL_OFFSET
local math_floor, math_max, math_min = math.floor, math.max, math.min
local type, unpack = type, unpack

function Controls.Tags(parent, label, initial, callback, width, placeholder, suggestions, defaultValue)
	width = width or 280
	placeholder = placeholder or "Type [ to insert tags..."
	suggestions = suggestions or {}
	local state = {text = initial or "", selectedIndex = 0, triggerPos = nil}
	width = math_floor(width / 2) * 2

	local boxHeight = label and CONTROL_HEIGHT or ROW_HEIGHT
	local containerHeight = label and (CONTROL_HEIGHT + LABEL_OFFSET) or boxHeight
	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(width, containerHeight)

	if label then
		local labelText = Controls.Text(container, label, FONT_SIZE, Theme.text.primary)
		labelText:SetPoint("TOPLEFT")
	end

	local rowWidget = Widget.New(container, "Frame", nil, {bg = Theme.bg.input, border = Theme.border.input, size = {width, boxHeight}})
	local row = rowWidget.frame
	row:SetPoint("BOTTOMLEFT"); row:SetPoint("BOTTOMRIGHT")

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(16, 16); icon:SetPoint("LEFT", 10, 0)
	icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon"); icon:SetVertexColor(unpack(Theme.text.muted))

	local clearButton = Controls.Icon(row, { preset = "clear", size = boxHeight - 6 })
	clearButton:SetPoint("RIGHT", -3, 0); clearButton:Hide()

	local editBox = CreateFrame("EditBox", nil, row)
	editBox:SetPoint("LEFT", icon, "RIGHT", 8, 0); editBox:SetPoint("RIGHT", clearButton.frame, "LEFT", -8, 0)
	editBox:SetHeight(20); editBox:SetAutoFocus(false)
	editBox:SetFont(BUILib.Font, FONT_SIZE, ""); editBox:SetTextColor(unpack(Theme.text.primary)); editBox:SetText(state.text)

	local placeholderText = editBox:CreateFontString(nil, "OVERLAY")
	placeholderText:SetFont(BUILib.Font, FONT_SIZE, ""); placeholderText:SetPoint("LEFT")
	placeholderText:SetText(placeholder); placeholderText:SetTextColor(unpack(Theme.text.muted))
	placeholderText:SetShown(state.text == "")

	local dropdownWidth = math.max(width, 340)
	local dropdownWidget = Widget.New(UIParent, "Frame", nil, {bg = Theme.bg.medium, border = Theme.border.default, size = {dropdownWidth, 10}})
	local dropdown = dropdownWidget.frame
	dropdown:SetFrameStrata(BUILib.GetPopupStrata()); dropdown:SetFrameLevel(BUILib.GetPopupLevel())
	dropdown:SetClampedToScreen(true); dropdown:Hide()

	local scrollFrame = CreateFrame("ScrollFrame", nil, dropdown)
	scrollFrame:SetPoint("TOPLEFT", 2, -2); scrollFrame:SetPoint("BOTTOMRIGHT", -2, 2)
	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetWidth(dropdownWidth - 4); scrollFrame:SetScrollChild(scrollChild)

	local scrollTrack = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
	scrollTrack:SetWidth(6); scrollTrack:SetPoint("TOPRIGHT", -2, -2); scrollTrack:SetPoint("BOTTOMRIGHT", -2, 2)
	scrollTrack:SetBackdrop(Widget.BACKDROP_BORDERLESS); scrollTrack:SetBackdropColor(0.1, 0.1, 0.1, 0.8); scrollTrack:Hide()
	local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
	scrollThumb:SetWidth(6); scrollThumb:SetBackdrop(Widget.BACKDROP_BORDERLESS)
	scrollThumb:SetBackdropColor(0.4, 0.4, 0.4, 1); scrollThumb:SetPoint("TOP"); scrollThumb:SetHeight(20)
	local tagsScrollLogic = Widget.ScrollLogic(scrollFrame, scrollChild, scrollTrack, scrollThumb, {
		step = 48,
		onShow = function(needsScrollbar)
			scrollFrame:SetPoint("BOTTOMRIGHT", needsScrollbar and -10 or -2, 2)
		end,
	})
	dropdown:EnableMouseWheel(true)
	dropdown:SetScript("OnMouseWheel", function(_, delta) tagsScrollLogic.DoScroll(delta) end)

	local function PositionDropdown()
		dropdown:ClearAllPoints(); dropdown:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -2)
		local parentStrata = row:GetFrameStrata(); local parentLevel = row:GetFrameLevel()
		dropdown:SetFrameStrata(parentStrata); dropdown:SetFrameLevel(parentLevel + 100)
	end

	local dropdownItems = {}
	local maxVisible = 10
	local maxItems = 50
	local itemHeight = 24
	local InsertTag
	local filteredSuggestions = {}

	local function UpdateDropdownHighlight()
		for itemIndex, item in ipairs(dropdownItems) do
			if item:IsShown() then item.highlight:SetAlpha(state.selectedIndex == itemIndex and 0.3 or 0) end
		end
	end

	for itemIndex = 1, maxItems do
		local item = CreateFrame("Button", nil, scrollChild)
		item:SetSize(dropdownWidth - 4, itemHeight); item:SetPoint("TOPLEFT", 0, -(itemIndex - 1) * itemHeight)
		local highlight = Widget.Create(item, Theme.GetAccent())
		highlight:SetAllPoints(); highlight:SetDrawLayer("BACKGROUND"); highlight:SetAlpha(0)
		item.highlight = highlight
		local tagColumnWidth = math_floor((dropdownWidth - 4) * 0.42)
		local itemText = item:CreateFontString(nil, "OVERLAY")
		itemText:SetFont(BUILib.Font, FONT_SIZE, ""); itemText:SetPoint("LEFT", 10, 0)
		itemText:SetWidth(tagColumnWidth); itemText:SetJustifyH("LEFT"); itemText:SetWordWrap(false)
		itemText:SetTextColor(unpack(Theme.text.primary)); item.text = itemText
		local descText = item:CreateFontString(nil, "OVERLAY")
		descText:SetFont(BUILib.Font, 10, ""); descText:SetPoint("LEFT", 10 + tagColumnWidth + 8, 0)
		descText:SetPoint("RIGHT", -10, 0); descText:SetJustifyH("LEFT"); descText:SetWordWrap(false)
		descText:SetTextColor(unpack(Theme.text.muted)); item.desc = descText
		item:SetScript("OnEnter", function(self) state.selectedIndex = self.index or itemIndex; UpdateDropdownHighlight() end)
		item:SetScript("OnLeave", function() end)
		item:SetScript("OnClick", function(self) if self.value then InsertTag(self.value) end end)
		item:Hide(); dropdownItems[itemIndex] = item
	end

	InsertTag = function(tag)
		local text = state.text
		local cursor = state.cursorPos or #text
		if state.triggerPos then
			local before = text:sub(1, state.triggerPos - 1)
			local after = text:sub(cursor + 1)
			editBox:SetText(before .. tag .. after)
			editBox:SetCursorPosition(state.triggerPos - 1 + #tag)
		else
			local before = text:sub(1, cursor)
			local after = text:sub(cursor + 1)
			editBox:SetText(before .. tag .. after)
			editBox:SetCursorPosition(cursor + #tag)
		end
		state.text = editBox:GetText(); state.cursorPos = editBox:GetCursorPosition()
		state.triggerPos = nil; dropdown:Hide()
		if callback then callback(state.text) end
	end

	local function UpdateDropdown()
		local text = editBox:GetText(); local cursor = editBox:GetCursorPosition()
		state.cursorPos = cursor; filteredSuggestions = {}
		local searchStart, searchText = nil, ""
		for charIndex = cursor, 1, -1 do
			local char = text:sub(charIndex, charIndex)
			if char == "[" then searchStart = charIndex; searchText = text:sub(charIndex + 1, cursor):lower(); break
			elseif char == "]" or char == " " then break end
		end
		if searchStart and #suggestions > 0 then
			state.triggerPos = searchStart
			for _, suggestion in ipairs(suggestions) do
				local tagName = suggestion.tag or suggestion
				if searchText == "" or tagName:lower():find(searchText, 1, true) then
					table.insert(filteredSuggestions, suggestion)
					if #filteredSuggestions >= maxItems then break end
				end
			end
		else state.triggerPos = nil end

		for itemIndex, item in ipairs(dropdownItems) do
			local suggestion = filteredSuggestions[itemIndex]
			if suggestion then
				if type(suggestion) == "table" then
					item.text:SetText(suggestion.tag); item.desc:SetText(suggestion.desc or ""); item.value = suggestion.tag
				else item.text:SetText(suggestion); item.desc:SetText(""); item.value = suggestion end
				item.index = itemIndex; item:Show()
			else item:Hide() end
		end

		if #filteredSuggestions > 0 then
			local visibleCount = math_min(#filteredSuggestions, maxVisible)
			dropdown:SetHeight(visibleCount * itemHeight + 4)
			scrollChild:SetHeight(#filteredSuggestions * itemHeight)
			scrollFrame:SetVerticalScroll(0); PositionDropdown(); dropdown:Show()
			BUILib.Defer(tagsScrollLogic.UpdateThumb)
			state.selectedIndex = 1; UpdateDropdownHighlight()
		else dropdown:Hide(); state.selectedIndex = 0 end
	end

	rowWidget:SetupHoverBorder(editBox, Theme.border.input)
	row:EnableMouse(true)
	row:SetScript("OnMouseDown", function() editBox:SetFocus() end)

	local function UpdateDisplay()
		state.text = editBox:GetText()
		placeholderText:SetShown(state.text == ""); clearButton:SetShown(state.text ~= "")
	end

	clearButton:SetScript("OnClick", function()
		editBox:SetText(""); state.text = ""; UpdateDisplay(); dropdown:Hide()
		if callback then callback("") end
	end)

	editBox:SetScript("OnTextChanged", function(self, userInput)
		UpdateDisplay(); if userInput then UpdateDropdown() end
	end)

	editBox:SetScript("OnEnterPressed", function(self)
		if dropdown:IsShown() and state.selectedIndex > 0 and filteredSuggestions[state.selectedIndex] then
			local suggestion = filteredSuggestions[state.selectedIndex]
			InsertTag(type(suggestion) == "table" and suggestion.tag or suggestion)
		else self:ClearFocus(); dropdown:Hide(); if callback then callback(state.text) end end
	end)
	editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); dropdown:Hide() end)

	editBox:HookScript("OnEditFocusLost", function()
		C_Timer.After(0.15, function() if not editBox:HasFocus() then dropdown:Hide() end end)
	end)

	local function ScrollToSelected()
		if state.selectedIndex <= 0 or #filteredSuggestions <= maxVisible then return end
		local itemTop = (state.selectedIndex - 1) * itemHeight
		local itemBottom = itemTop + itemHeight
		local viewTop = scrollFrame:GetVerticalScroll()
		local viewBottom = viewTop + scrollFrame:GetHeight()
		if itemTop < viewTop then scrollFrame:SetVerticalScroll(itemTop); tagsScrollLogic.UpdateThumb()
		elseif itemBottom > viewBottom then scrollFrame:SetVerticalScroll(itemBottom - scrollFrame:GetHeight()); tagsScrollLogic.UpdateThumb() end
	end

	editBox:SetScript("OnKeyDown", function(self, key)
		if not dropdown:IsShown() then return end
		if key == "DOWN" then state.selectedIndex = math_min(state.selectedIndex + 1, #filteredSuggestions); UpdateDropdownHighlight(); ScrollToSelected()
		elseif key == "UP" then state.selectedIndex = math_max(state.selectedIndex - 1, 1); UpdateDropdownHighlight(); ScrollToSelected()
		elseif key == "TAB" and state.selectedIndex > 0 and filteredSuggestions[state.selectedIndex] then
			local suggestion = filteredSuggestions[state.selectedIndex]
			InsertTag(type(suggestion) == "table" and suggestion.tag or suggestion)
		end
	end)

	editBox:SetScript("OnChar", function(self, char)
		if char == "[" then BUILib.Defer(UpdateDropdown) end
	end)

	UpdateDisplay()

	function container:GetValue() return editBox:GetText() end
	function container:SetValue(newValue) editBox:SetText(newValue or ""); state.text = newValue or ""; UpdateDisplay() end
	function container:Clear() editBox:SetText(""); state.text = ""; UpdateDisplay(); dropdown:Hide(); if callback then callback("") end end
	function container:Focus() editBox:SetFocus() end

	return Widget.Wrap(container)
end
