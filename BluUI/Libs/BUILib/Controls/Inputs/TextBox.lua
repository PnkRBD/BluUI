local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE
local ROW_HEIGHT = BUILib.ROW_HEIGHT
local LABEL_OFFSET = BUILib.LABEL_OFFSET
local math_floor = math.floor
local unpack = unpack

function Controls.TextBox(parent, label, initial, callback, tooltip, width, labelPosition)
	width = width or 280; labelPosition = labelPosition or "top"
	local containerHeight, boxWidth, boxHeight
	boxHeight = ROW_HEIGHT
	if label then
		if labelPosition == "top" then containerHeight = ROW_HEIGHT + LABEL_OFFSET; boxWidth = width
		else containerHeight = ROW_HEIGHT; boxWidth = math_floor(width * 0.6 / 2) * 2 end
	else containerHeight = ROW_HEIGHT; boxWidth = width end
	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	container:SetSize(width, containerHeight)
	local boxWidget = Widget.New(container, "EditBox", nil, {raw = true, size = {boxWidth, boxHeight}})
	local box = boxWidget.frame
	box:EnableMouse(true)
	local SetBoxHighlighted = Widget.RoundedInput(box)
	box:SetAutoFocus(false); box:SetFont(BUILib.Font, 12, "")
	box:SetTextColor(unpack(Theme.text.primary)); box:SetTextInsets(10, 10, 0, 0)
	box:SetText(initial or "")
	if label then
		container.label = Controls.Text(container, label, FONT_SIZE, Theme.text.label)
		if labelPosition == "top" then
			container.label:SetPoint("TOPLEFT")
			box:SetPoint("BOTTOMLEFT"); box:SetPoint("BOTTOMRIGHT")
		elseif labelPosition == "left" then
			container.label:SetPoint("LEFT"); box:SetPoint("LEFT", container.label, "RIGHT", 8, 0)
		else box:SetPoint("LEFT"); container.label:SetPoint("LEFT", box, "RIGHT", 8, 0) end
	else box:SetPoint("LEFT"); box:SetPoint("RIGHT") end
	box:SetScript("OnEnter", function() SetBoxHighlighted(true) end)
	box:SetScript("OnLeave", function() if not box:HasFocus() then SetBoxHighlighted(false) end end)
	box:SetScript("OnEditFocusGained", function() SetBoxHighlighted(true) end)
	box:SetScript("OnEditFocusLost", function() SetBoxHighlighted(false) end)
	box:SetScript("OnEnterPressed", function(editBox) editBox:ClearFocus(); if callback then callback(editBox:GetText()) end end)
	box:SetScript("OnEscapePressed", function(editBox) editBox:ClearFocus() end)
	if tooltip then Widget.Tooltip(box, tooltip) end
	function container:GetValue() return box:GetText() end
	function container:SetValue(value) box:SetText(value or "") end
	container.editbox = box
	return Widget.Wrap(container)
end
