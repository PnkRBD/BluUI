local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE
local ROW_HEIGHT = BUILib.ROW_HEIGHT
local LABEL_OFFSET = BUILib.LABEL_OFFSET
local unpack = unpack

local function SafeSetPropagateKeyboardInput(frame, value)
	if InCombatLockdown() then
		local eventFrame = CreateFrame("Frame")
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		eventFrame:SetScript("OnEvent", function(self)
			self:UnregisterAllEvents()
			if frame and frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(value) end
			self:SetScript("OnEvent", nil)
		end)
	else frame:SetPropagateKeyboardInput(value) end
end

function Controls.Keybind(parent, label, key, callback, width)
	width = width or 280
	local state = {key = key or "NONE", listening = false}
	local containerHeight = label and (ROW_HEIGHT + LABEL_OFFSET) or ROW_HEIGHT
	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	container:SetSize(width, containerHeight)
	if label then Controls.Text(container, label, FONT_SIZE, Theme.text.primary):SetPoint("TOPLEFT") end
	local rowWidget = Widget.New(container, "Frame", nil, {bg = Theme.bg.input, border = Theme.border.input, size = {width, ROW_HEIGHT}})
	local row = rowWidget.frame; row:SetPoint("BOTTOMLEFT"); row:SetPoint("BOTTOMRIGHT")
	local buttonHeight = ROW_HEIGHT - 6
	local buttonWidth = math.floor(width * 0.3)
	local clearSize = buttonHeight - 4
	local editButton = Controls.Button(row, "Edit Keybind", buttonWidth)
	editButton:SetSize(buttonWidth, buttonHeight); editButton:SetPoint("RIGHT", -3, 0)
	local clearButton = Controls.Icon(row, { preset = "clear", size = clearSize })
	clearButton:SetPoint("RIGHT", editButton.frame or editButton, "LEFT", -4, 0)
	local keyText = row:CreateFontString(nil, "OVERLAY")
	keyText:SetFont(BUILib.Font, 12, ""); keyText:SetPoint("LEFT", 10, 0)
	keyText:SetPoint("RIGHT", clearButton.frame or clearButton, "LEFT", -6, 0)
	keyText:SetJustifyH("LEFT")
	keyText:SetTextColor(unpack(Theme.text.primary))
	local listener = CreateFrame("Frame", nil, UIParent)
	listener:EnableKeyboard(true); listener:Hide()
	listener:SetScript("OnShow", function(listenerFrame) SafeSetPropagateKeyboardInput(listenerFrame, true) end)
	local function UpdateDisplay()
		if state.listening then
			keyText:SetText("Press a key..."); keyText:SetTextColor(1, 1, 1, 1)
			row:SetBackdropBorderColor(0.9, 0.2, 0.2, 1)
			editButton:SetText("Cancel"); clearButton:Hide()
		else
			keyText:SetText(state.key == "NONE" and "Not bound" or state.key)
			keyText:SetTextColor(unpack(Theme.text.primary))
			row:SetBackdropBorderColor(unpack(Theme.border.input))
			editButton:SetText("Edit Keybind"); clearButton:SetShown(state.key ~= "NONE")
		end
	end
	clearButton:SetScript("OnClick", function()
		state.key = "NONE"; UpdateDisplay()
		if callback then callback(state.key) end
	end)
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(hoveredRow) if not state.listening then hoveredRow:SetBackdropBorderColor(Theme.GetAccent()) end end)
	row:SetScript("OnLeave", function(hoveredRow) if not state.listening then hoveredRow:SetBackdropBorderColor(unpack(Theme.border.input)) end end)
	listener:SetScript("OnKeyDown", function(self, keyPressed)
		if not state.listening then return end
		if keyPressed == "LSHIFT" or keyPressed == "RSHIFT" or keyPressed == "LCTRL" or keyPressed == "RCTRL" or keyPressed == "LALT" or keyPressed == "RALT" then return end
		SafeSetPropagateKeyboardInput(self, false)
		if keyPressed ~= "ESCAPE" then
			local modifierPrefix = ""
			if IsShiftKeyDown() then modifierPrefix = modifierPrefix .. "SHIFT-" end
			if IsControlKeyDown() then modifierPrefix = modifierPrefix .. "CTRL-" end
			if IsAltKeyDown() then modifierPrefix = modifierPrefix .. "ALT-" end
			state.key = modifierPrefix .. keyPressed
			if callback then callback(state.key) end
		end
		state.listening = false; self:Hide(); UpdateDisplay()
	end)
	editButton:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		if state.listening then state.listening = false; listener:Hide()
		else state.listening = true; listener:Show() end
		UpdateDisplay()
	end)
	UpdateDisplay()
	function container:GetValue() return state.key end
	function container:SetValue(value) state.key = value or "NONE"; UpdateDisplay() end
	function container:Clear() state.key = "NONE"; UpdateDisplay(); if callback then callback(state.key) end end
	return Widget.Wrap(container)
end
