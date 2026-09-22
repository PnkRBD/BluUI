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

function Controls.Frames(parent, label, initial, callback, width, hint, suggestions)
	width = width or 280
	suggestions = suggestions or {}
	local state = {text = initial or "", selectedIndex = 0}
	local syncIcons = function() end
	width = math_floor(width / 2) * 2
	local buttonHeight = label and CONTROL_HEIGHT or ROW_HEIGHT
	local containerHeight = label and (CONTROL_HEIGHT + LABEL_OFFSET) or buttonHeight
	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(width, containerHeight)
	if label then Controls.Text(container, label, FONT_SIZE, Theme.text.primary):SetPoint("TOPLEFT") end

	local buttonWidget = Widget.New(container, "Button", nil, {bg = Theme.bg.input, border = Theme.border.input, size = {width, buttonHeight}})
	local button = buttonWidget.frame; button:SetPoint("BOTTOMLEFT")
	local buttonText = button:CreateFontString(nil, "OVERLAY")
	buttonText:SetFont(BUILib.Font, FONT_SIZE, ""); buttonText:SetJustifyH("LEFT")
	buttonText:SetPoint("LEFT", 10, 0); buttonText:SetPoint("RIGHT", -28, 0)
	buttonText:SetWordWrap(false); buttonText:SetNonSpaceWrap(false)
	buttonText:SetMaxLines(1)
	local chevron = button:CreateFontString(nil, "OVERLAY")
	chevron:SetFont(BUILib.Font, 14, ""); chevron:SetPoint("RIGHT", -10, 0)
	chevron:SetText("+"); chevron:SetTextColor(unpack(Theme.text.secondary))

	local function UpdateButtonText()
		if state.text ~= "" then
			buttonText:SetText(state.text); buttonText:SetTextColor(unpack(Theme.text.secondary))
		else
			buttonText:SetText("None"); buttonText:SetTextColor(unpack(Theme.text.muted))
		end
	end
	UpdateButtonText()

	local panelWidget = Widget.New({frame = UIParent}, "Frame", nil, {bg = Theme.bg.dark, border = Theme.border.light, size = {width, 100}})
	local panel = panelWidget.frame
	panel:SetFrameStrata(BUILib.GetPopupStrata()); panel:SetFrameLevel(BUILib.GetPopupLevel())
	panel:SetClampedToScreen(true); panel:Hide()

	local searchRow = CreateFrame("Frame", nil, panel)
	searchRow:SetHeight(28); searchRow:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
	searchRow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
	local searchIcon = searchRow:CreateTexture(nil, "ARTWORK")
	searchIcon:SetSize(14, 14); searchIcon:SetPoint("LEFT", 8, 0)
	searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon"); searchIcon:SetVertexColor(unpack(Theme.text.muted))
	local searchBox = CreateFrame("EditBox", nil, searchRow)
	searchBox:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0); searchBox:SetPoint("RIGHT", -8, 0)
	searchBox:SetHeight(20); searchBox:SetAutoFocus(false)
	searchBox:SetFont(BUILib.Font, FONT_SIZE, ""); searchBox:SetTextColor(unpack(Theme.text.primary))
	local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY")
	searchPlaceholder:SetFont(BUILib.Font, FONT_SIZE, ""); searchPlaceholder:SetPoint("LEFT")
	searchPlaceholder:SetText(hint or "Search..."); searchPlaceholder:SetTextColor(unpack(Theme.text.muted))

	local divider = panel:CreateTexture(nil, "ARTWORK")
	divider:SetHeight(1); divider:SetPoint("TOPLEFT", searchRow, "BOTTOMLEFT", 0, -1)
	divider:SetPoint("TOPRIGHT", searchRow, "BOTTOMRIGHT", 0, -1)
	divider:SetColorTexture(unpack(Theme.border.input))

	local maxVisible, itemHeight, maxDisplay = 20, 24, 10
	local listTop = 2 + 28 + 2
	local scrollFrame = CreateFrame("ScrollFrame", nil, panel)
	scrollFrame:SetPoint("TOPLEFT", 2, -listTop); scrollFrame:SetPoint("TOPRIGHT", -2, -listTop)
	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetWidth(width - 4); scrollFrame:SetScrollChild(scrollChild)
	local scrollTrack = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	scrollTrack:SetWidth(6); scrollTrack:SetPoint("TOPRIGHT", -2, -listTop); scrollTrack:SetPoint("BOTTOMRIGHT", -2, 2)
	scrollTrack:SetBackdrop({bgFile = Widget.WHITE}); scrollTrack:SetBackdropColor(0.1, 0.1, 0.1, 0.8); scrollTrack:Hide()
	local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
	scrollThumb:SetWidth(6); scrollThumb:SetBackdrop({bgFile = Widget.WHITE})
	scrollThumb:SetBackdropColor(0.4, 0.4, 0.4, 1); scrollThumb:SetPoint("TOP"); scrollThumb:SetHeight(20)
	local framesScrollLogic = Widget.ScrollLogic(scrollFrame, scrollChild, scrollTrack, scrollThumb, {
		step = itemHeight * 2,
		onShow = function(needsScrollbar)
			scrollFrame:SetPoint("TOPRIGHT", needsScrollbar and -10 or -2, -listTop)
		end,
	})
	panel:EnableMouseWheel(true); panel:SetScript("OnMouseWheel", function(_, delta) framesScrollLogic.DoScroll(delta) end)
	local resultItems = {}
	local filteredSuggestions = {}

	local function UpdateHighlight()
		for itemIndex, item in ipairs(resultItems) do
			if item:IsShown() then item.highlight:SetAlpha(state.selectedIndex == itemIndex and 0.3 or 0) end
		end
	end

	local function SelectFrame(frameName)
		state.text = frameName; panel:Hide(); chevron:SetText("+"); UpdateButtonText()
		syncIcons()
		if callback then callback(frameName) end
	end

	for itemIndex = 1, maxVisible do
		local item = CreateFrame("Button", nil, scrollChild)
		item:SetHeight(itemHeight)
		item:SetPoint("TOPLEFT", 0, -((itemIndex - 1) * itemHeight))
		item:SetPoint("TOPRIGHT", 0, -((itemIndex - 1) * itemHeight))
		local highlight = Widget.Create(item, Theme.GetAccent())
		highlight:SetAllPoints(); highlight:SetDrawLayer("BACKGROUND"); highlight:SetAlpha(0)
		item.highlight = highlight
		local itemText = item:CreateFontString(nil, "OVERLAY")
		itemText:SetFont(BUILib.Font, FONT_SIZE, ""); itemText:SetPoint("LEFT", 10, 0)
		itemText:SetWidth(110); itemText:SetJustifyH("LEFT"); itemText:SetWordWrap(false)
		local descriptionText = item:CreateFontString(nil, "OVERLAY")
		descriptionText:SetFont(BUILib.Font, 10, "")
		descriptionText:SetPoint("LEFT", itemText, "RIGHT", 8, 0)
		descriptionText:SetPoint("RIGHT", item, "RIGHT", -10, 0)
		descriptionText:SetTextColor(unpack(Theme.text.muted)); descriptionText:SetJustifyH("RIGHT")
		descriptionText:SetWordWrap(false); item.desc = descriptionText
		itemText:SetTextColor(unpack(Theme.text.primary)); item.text = itemText
		item:SetScript("OnEnter", function() state.selectedIndex = itemIndex; UpdateHighlight() end)
		item:SetScript("OnClick", function(self) if self.value then SelectFrame(self.value) end end)
		item:Hide(); resultItems[itemIndex] = item
	end

	local function FilterAndShow()
		local searchText = searchBox:GetText():lower()
		filteredSuggestions = {}
		for _, suggestion in ipairs(suggestions) do
			local tagName = suggestion.tag or suggestion
			local description = type(suggestion) == "table" and (suggestion.desc or ""):lower() or ""
			if searchText == "" or tagName:lower():find(searchText, 1, true) or description:find(searchText, 1, true) then
				filteredSuggestions[#filteredSuggestions + 1] = suggestion
				if #filteredSuggestions >= maxVisible then break end
			end
		end
		for itemIndex, item in ipairs(resultItems) do
			local suggestion = filteredSuggestions[itemIndex]
			if suggestion then
				if type(suggestion) == "table" then item.text:SetText(suggestion.tag); item.desc:SetText(suggestion.desc or ""); item.value = suggestion.tag
				else item.text:SetText(suggestion); item.desc:SetText(""); item.value = suggestion end
				item:Show()
			else item:Hide() end
		end
		local count = math_min(#filteredSuggestions, maxVisible)
		local displayCount = math_min(count, maxDisplay)
		local viewHeight = displayCount * itemHeight
		scrollChild:SetHeight(count * itemHeight)
		scrollFrame:SetHeight(viewHeight)
		panel:SetHeight(listTop + viewHeight + 2)
		scrollFrame:SetVerticalScroll(0)
		BUILib.Defer(framesScrollLogic.UpdateThumb)
		state.selectedIndex = count > 0 and 1 or 0; UpdateHighlight()
	end

	local function OpenPanel()
		searchBox:SetText(""); searchPlaceholder:Show()
		local panelWidth = math_max(width, 340)
		panel:SetWidth(panelWidth); scrollChild:SetWidth(panelWidth - 4)
		FilterAndShow()
		panel:ClearAllPoints()
		local bottom = button:GetBottom(); local panelHeight = panel:GetHeight() or 100
		if not bottom or bottom < panelHeight + 50 then panel:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 2)
		else panel:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2) end
		panel:Show(); panel:Raise(); chevron:SetText("\226\136\146"); syncIcons()
		searchBox:SetFocus()
	end

	local function ClosePanel()
		panel:Hide(); chevron:SetText("+"); searchBox:ClearFocus(); syncIcons()
	end

	button:SetScript("OnClick", function()
		if panel:IsShown() then ClosePanel() else OpenPanel() end
	end)
	button:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(Theme.GetAccent()) end)
	button:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(Theme.border.input)) end)

	searchBox:SetScript("OnTextChanged", function(_, userInput)
		searchPlaceholder:SetShown(searchBox:GetText() == "")
		if userInput then FilterAndShow() end
	end)
	searchBox:SetScript("OnEnterPressed", function()
		if state.selectedIndex > 0 and filteredSuggestions[state.selectedIndex] then
			local selectedSuggestion = filteredSuggestions[state.selectedIndex]
			SelectFrame(type(selectedSuggestion) == "table" and selectedSuggestion.tag or selectedSuggestion)
		end
	end)
	searchBox:SetScript("OnEscapePressed", function() ClosePanel() end)
	local function ScrollToSelected()
		if state.selectedIndex <= 0 then return end
		local itemTop = (state.selectedIndex - 1) * itemHeight
		local itemBottom = itemTop + itemHeight
		local scroll = scrollFrame:GetVerticalScroll()
		local viewHeight = scrollFrame:GetHeight()
		if itemTop < scroll then scrollFrame:SetVerticalScroll(itemTop)
		elseif itemBottom > scroll + viewHeight then scrollFrame:SetVerticalScroll(itemBottom - viewHeight) end
		framesScrollLogic.UpdateThumb()
	end
	searchBox:SetScript("OnKeyDown", function(_, key)
		if key == "DOWN" then state.selectedIndex = math_min(state.selectedIndex + 1, #filteredSuggestions); UpdateHighlight(); ScrollToSelected()
		elseif key == "UP" then state.selectedIndex = math_max(state.selectedIndex - 1, 1); UpdateHighlight(); ScrollToSelected()
		elseif key == "TAB" and state.selectedIndex > 0 and filteredSuggestions[state.selectedIndex] then
			local selectedSuggestion = filteredSuggestions[state.selectedIndex]
			SelectFrame(type(selectedSuggestion) == "table" and selectedSuggestion.tag or selectedSuggestion)
		end
	end)

	panel:SetScript("OnShow", function(self)
		self.checkFrame = self.checkFrame or CreateFrame("Frame")
		self.checkFrame:SetScript("OnUpdate", function(checkFrame)
			if not (button:IsMouseOver() or panel:IsMouseOver()) then
				if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
					ClosePanel(); checkFrame:SetScript("OnUpdate", nil)
				end
			end
		end)
	end)
	panel:SetScript("OnHide", function(self) if self.checkFrame then self.checkFrame:SetScript("OnUpdate", nil) end end)

	local clearButton = Controls.Icon(button, { preset = "clear", size = 16 })
	clearButton:SetPoint("RIGHT", -4, 0)
	container._clearBtn = clearButton
	clearButton:SetScript("OnClick", function()
		state.text = ""; UpdateButtonText(); ClosePanel()
		if callback then callback("") end
	end)
	syncIcons = function()
		local hasValue = state.text ~= ""
		local isOpen = panel:IsShown()
		clearButton:SetShown(hasValue and not isOpen)
		chevron:SetShown(not hasValue or isOpen)
	end
	syncIcons()

	function container:GetValue() return state.text end
	function container:SetValue(value) state.text = value or ""; UpdateButtonText(); syncIcons() end
	function container:Focus() OpenPanel() end

	local nativeSetWidth = container.SetWidth
	function container:SetWidth(newWidth)
		width = newWidth; nativeSetWidth(container, newWidth); button:SetWidth(newWidth)
	end

	return Widget.Wrap(container)
end
