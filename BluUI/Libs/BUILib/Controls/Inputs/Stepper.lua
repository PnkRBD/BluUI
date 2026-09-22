local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE
local ROW_HEIGHT = BUILib.ROW_HEIGHT
local LABEL_OFFSET = BUILib.LABEL_OFFSET
local math_max, math_min = math.max, math.min
local tostring = tostring

function Controls.Stepper(parent, label, value, minValue, maxValue, step, callback, width, height)
	width = width or 200; height = height or ROW_HEIGHT
	step = step or 1; value = value or minValue or 0
	minValue = minValue or 0; maxValue = maxValue or 100
	local buttonFontSize = height > 28 and 18 or 13
	local valueFontSize = height > 28 and 14 or 12
	local containerHeight = label and (height + LABEL_OFFSET) or height
	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	container:SetSize(width, containerHeight)
	local state = {value = value}
	if label then Controls.Text(container, label, FONT_SIZE, Theme.text.primary):SetPoint("TOPLEFT") end
	local row = Widget.New(container, "Frame", nil, {bg = Theme.bg.input, border = Theme.border.input, size = {width, height}})
	row.frame:SetPoint("BOTTOMLEFT")
	local function MakeButton(text, anchor, offset)
		local button = CreateFrame("Button", nil, row.frame, "BackdropTemplate")
		button:SetSize(height, height - 2); button:SetPoint(anchor, offset, 0)
		button:SetBackdrop({bgFile = Widget.WHITE}); button:SetBackdropColor(unpack(Theme.bg.medium))
		local buttonLabel = button:CreateFontString(nil, "OVERLAY")
		buttonLabel:SetFont(BUILib.Font, buttonFontSize, ""); buttonLabel:SetPoint("CENTER"); buttonLabel:SetText(text); buttonLabel:SetTextColor(unpack(Theme.text.primary))
		return button
	end
	local minusButton = MakeButton("\226\136\146", "LEFT", 1)
	local plusButton = MakeButton("+", "RIGHT", -1)
	local valueBox = CreateFrame("EditBox", nil, row.frame)
	valueBox:SetPoint("LEFT", minusButton, "RIGHT", 2, 0)
	valueBox:SetPoint("RIGHT", plusButton, "LEFT", -2, 0)
	valueBox:SetHeight(height - 2); valueBox:SetFont(BUILib.Font, valueFontSize, "")
	valueBox:SetTextColor(unpack(Theme.text.primary)); valueBox:SetJustifyH("CENTER")
	valueBox:SetAutoFocus(false); valueBox:SetNumeric(true); valueBox:SetMaxLetters(6)
	container.valueBox = valueBox
	local function UpdateDisplay() valueBox:SetText(tostring(state.value)) end
	local function Commit()
		state.value = math_min(maxValue, math_max(minValue, tonumber(valueBox:GetText()) or minValue))
		UpdateDisplay(); if callback then callback(state.value) end
	end
	valueBox:SetScript("OnEnterPressed", function(editBox) editBox:ClearFocus() end)
	valueBox:SetScript("OnEscapePressed", function(editBox) editBox:ClearFocus(); UpdateDisplay() end)
	valueBox:SetScript("OnEditFocusLost", Commit)
	minusButton:SetScript("OnClick", function()
		state.value = math_max(minValue, state.value - step); UpdateDisplay()
		if callback then callback(state.value) end
	end)
	plusButton:SetScript("OnClick", function()
		state.value = math_min(maxValue, state.value + step); UpdateDisplay()
		if callback then callback(state.value) end
	end)
	local function RowEnter() row.frame:SetBackdropBorderColor(Theme.GetAccent()) end
	local function RowLeave() row.frame:SetBackdropBorderColor(unpack(Theme.border.input)) end
	minusButton:SetScript("OnEnter", function(stepButton) stepButton:SetBackdropColor(unpack(Theme.bg.light)); RowEnter() end)
	minusButton:SetScript("OnLeave", function(stepButton) stepButton:SetBackdropColor(unpack(Theme.bg.medium)); RowLeave() end)
	plusButton:SetScript("OnEnter", function(stepButton) stepButton:SetBackdropColor(unpack(Theme.bg.light)); RowEnter() end)
	plusButton:SetScript("OnLeave", function(stepButton) stepButton:SetBackdropColor(unpack(Theme.bg.medium)); RowLeave() end)
	row.frame:EnableMouse(true)
	row.frame:SetScript("OnEnter", RowEnter); row.frame:SetScript("OnLeave", RowLeave)
	UpdateDisplay()
	function container:GetValue() return state.value end
	function container:SetValue(newValue) state.value = newValue; UpdateDisplay() end
	return Widget.Wrap(container)
end
