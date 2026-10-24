local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local ROW_HEIGHT = BUILib.ROW_HEIGHT
local unpack = unpack

function Controls.SearchBox(parent, placeholder, callback, width)
	width = width or 250
	local self = Widget.New(parent, "Frame", nil, {bg = Theme.bg.input, border = Theme.border.input, size = {width, ROW_HEIGHT}})
	local container = self.frame
	local function SetHovered(hovered)
		if hovered then container:SetBackdropBorderColor(Theme.GetAccent())
		else container:SetBackdropBorderColor(unpack(Theme.border.input)) end
	end
	container:SetScript("OnEnter", function() SetHovered(true) end)
	container:SetScript("OnLeave", function() SetHovered(false) end)
	local icon = container:CreateTexture(nil, "ARTWORK")
	icon:SetSize(16, 16); icon:SetPoint("LEFT", 10, 0)
	icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon"); icon:SetVertexColor(unpack(Theme.text.muted))
	local clearButton = Controls.Icon(container, { preset = "clear", size = 20 })
	clearButton:SetPoint("RIGHT", -6, 0)
	clearButton:HookScript("OnEnter", function() SetHovered(true) end)
	clearButton:HookScript("OnLeave", function() SetHovered(false) end)
	clearButton:Hide()
	local editBox = CreateFrame("EditBox", nil, container)
	editBox:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	editBox:SetPoint("RIGHT", clearButton.frame, "LEFT", -6, 0)
	editBox:SetHeight(20); editBox:SetAutoFocus(false)
	editBox:EnableMouse(true)
	editBox:SetFont(BUILib.Font, 12, ""); editBox:SetTextColor(unpack(Theme.text.primary))
	editBox:SetScript("OnEnter", function() SetHovered(true) end)
	editBox:SetScript("OnLeave", function() if not editBox:HasFocus() then SetHovered(false) end end)
	editBox:SetScript("OnEditFocusGained", function() SetHovered(true) end)
	editBox:SetScript("OnEditFocusLost", function() SetHovered(false) end)
	local placeholderText = editBox:CreateFontString(nil, "OVERLAY")
	placeholderText:SetFont(BUILib.Font, 12, ""); placeholderText:SetPoint("LEFT")
	placeholderText:SetText(placeholder or "Search..."); placeholderText:SetTextColor(unpack(Theme.text.muted))
	clearButton:SetScript("OnClick", function()
		editBox:SetText(""); editBox:ClearFocus(); placeholderText:Show(); clearButton:Hide()
		if callback then callback("") end
	end)
	editBox:SetScript("OnTextChanged", function(searchBox)
		local searchText = searchBox:GetText()
		placeholderText:SetShown(searchText == ""); clearButton:SetShown(searchText ~= "")
		if callback then callback(searchText) end
	end)
	editBox:SetScript("OnEscapePressed", function(searchBox) searchBox:ClearFocus() end)
	function container:GetValue() return editBox:GetText() end
	function container:SetValue(value)
		editBox:SetText(value or ""); placeholderText:SetShown(value == "" or value == nil)
		clearButton:SetShown(value and value ~= "")
	end
	container.editbox = editBox; container.clearButton = clearButton
	return self
end
