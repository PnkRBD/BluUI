local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE

local floor, max, min = math.floor, math.max, math.min
local pi = math.pi
local select, unpack, tostring = select, unpack, tostring

local ThumbFactories = {}

ThumbFactories.rect = function(track, accentRed, accentGreen, accentBlue)
	local thumbWidget = Widget.New(track, "Frame", nil, {size = {12, 18}})
	local thumb = thumbWidget.frame
	thumb:SetBackdropColor(accentRed, accentGreen, accentBlue, 1)
	thumb:SetBackdropBorderColor(accentRed * 0.7, accentGreen * 0.7, accentBlue * 0.7, 1)
	return thumb, function(red, green, blue)
		thumb:SetBackdropColor(red, green, blue, 1)
		thumb:SetBackdropBorderColor(red * 0.7, green * 0.7, blue * 0.7, 1)
	end
end

ThumbFactories.diamond = function(track, accentRed, accentGreen, accentBlue)
	local thumb = CreateFrame("Frame", nil, track)
	thumb:SetSize(16, 16)
	local fill = thumb:CreateTexture(nil, "OVERLAY")
	fill:SetTexture(Widget.WHITE)
	fill:SetSize(11, 11)
	fill:SetPoint("CENTER")
	fill:SetRotation(pi / 4)
	fill:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
	return thumb, function(red, green, blue)
		fill:SetVertexColor(red, green, blue, 1)
	end
end

ThumbFactories.notch = function(track, accentRed, accentGreen, accentBlue)
	local thumb = CreateFrame("Frame", nil, track)
	thumb:SetSize(14, 22)
	local body = thumb:CreateTexture(nil, "OVERLAY")
	body:SetTexture(Widget.WHITE)
	body:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
	body:SetPoint("TOPLEFT")
	body:SetPoint("TOPRIGHT")
	body:SetHeight(15)
	local tip = thumb:CreateTexture(nil, "OVERLAY")
	tip:SetTexture(Widget.WHITE)
	tip:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
	tip:SetSize(14, 7)
	tip:SetPoint("TOP", body, "BOTTOM", 0, 0)
	if tip.SetVertexOffset then
		tip:SetVertexOffset(2, 7, 0)
		tip:SetVertexOffset(4, -7, 0)
	end
	return thumb, function(red, green, blue)
		body:SetVertexColor(red, green, blue, 1)
		tip:SetVertexColor(red, green, blue, 1)
	end
end

ThumbFactories.ellipse = function(track, accentRed, accentGreen, accentBlue)
	local thumb = CreateFrame("Frame", nil, track)
	thumb:SetSize(20, 16)
	local fill = thumb:CreateTexture(nil, "OVERLAY")
	fill:SetTexture(BUILib.GetLibMedia('ellipse'))
	fill:SetAllPoints()
	fill:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
	return thumb, function(red, green, blue)
		fill:SetVertexColor(red, green, blue, 1)
	end
end

ThumbFactories.circle = function(track, accentRed, accentGreen, accentBlue)
	local thumb = CreateFrame("Frame", nil, track)
	thumb:SetSize(14, 14)
	local fill = thumb:CreateTexture(nil, "OVERLAY")
	fill:SetTexture(BUILib.GetLibMedia('smoothdisc'))
	fill:SetAllPoints()
	fill:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
	return thumb, function(red, green, blue)
		fill:SetVertexColor(red, green, blue, 1)
	end
end

function Controls.Slider(parent, label, minValue, maxValue, value, callback, indentLevel, locked, tooltip, step, width, titleAlign, config)
	config = config or {}
	width = width or 280
	titleAlign = titleAlign or "middle"
	local indentPx = (indentLevel or 0) * 20
	step = step or 1
	value = value or minValue or 0
	minValue = minValue or 0; maxValue = maxValue or 100
	local thumbType = config.thumbType or 'rect'
	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	container:SetSize(width, 70)
	local state = {value = value, locked = locked or false}
	local trackPadding = min(30, max(20, width * 0.1))
	local trackWidget = Widget.New(container, "Frame", nil, {bg = Theme.control.track, border = Theme.border.dark, height = 6})
	local track = trackWidget.frame
	track:SetPoint("TOPLEFT", container, "TOPLEFT", trackPadding + indentPx, -24)
	track:SetPoint("TOPRIGHT", container, "TOPRIGHT", -trackPadding, -24)
	Controls.Text(container, tostring(minValue), 10, Theme.text.muted):SetPoint("RIGHT", track, "LEFT", -4, 0)
	Controls.Text(container, tostring(maxValue), 10, Theme.text.muted):SetPoint("LEFT", track, "RIGHT", 4, 0)
	local labelText = Controls.Text(container, label, FONT_SIZE, Theme.text.primary)
	if titleAlign == "left" then
		labelText:SetPoint("TOPLEFT", container, "TOPLEFT", indentPx, 0); labelText:SetJustifyH("LEFT")
	elseif titleAlign == "right" then
		labelText:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0); labelText:SetJustifyH("RIGHT")
	else labelText:SetPoint("BOTTOM", track, "TOP", 0, 12) end
	local accentRed, accentGreen, accentBlue = Theme.GetAccent()
	local factory = ThumbFactories[thumbType] or ThumbFactories.rect
	local thumb, recolorThumb = factory(track, accentRed, accentGreen, accentBlue)
	local valueBox = CreateFrame("EditBox", nil, container, "BackdropTemplate")
	valueBox:SetSize(46, 22); valueBox:SetPoint("TOP", track, "BOTTOM", 0, -12)
	valueBox:SetAutoFocus(false); valueBox:SetFont(BUILib.Font, 12, "")
	valueBox:SetTextColor(1, 1, 1); valueBox:SetJustifyH("CENTER"); valueBox:SetMaxLetters(10)
	valueBox:SetBackdrop(Widget.BACKDROP)
	valueBox:SetBackdropColor(unpack(Theme.bg.input)); valueBox:SetBackdropBorderColor(unpack(Theme.border.dark))
	valueBox:SetScript("OnEnter", function(editBox)
		if not state.locked then editBox:SetBackdropBorderColor(Theme.GetAccent()) end
	end)
	valueBox:SetScript("OnLeave", function(editBox)
		if not editBox:HasFocus() then editBox:SetBackdropBorderColor(unpack(Theme.border.dark)) end
	end)
	local function MakeStepButton(text, anchor, offset)
		local stepButton = Widget.New(container, "Button", nil, {bg = Theme.button.normal, border = Theme.button.normal, size = {22, 22}})
		stepButton.frame:SetPoint(anchor, valueBox, offset == -1 and "LEFT" or "RIGHT", offset * 4, 0)
		local buttonLabel = stepButton:CreateText({size = 14, text = text, color = Theme.text.secondary})
		buttonLabel:SetPoint("CENTER")
		stepButton.frame:SetScript("OnEnter", function(buttonFrame)
			if not state.locked then buttonFrame:SetBackdropColor(unpack(Theme.button.hover)); buttonLabel:SetTextColor(1, 1, 1) end
		end)
		stepButton.frame:SetScript("OnLeave", function(buttonFrame)
			buttonFrame:SetBackdropColor(unpack(Theme.button.normal)); buttonLabel:SetTextColor(unpack(Theme.text.secondary))
		end)
		return stepButton.frame
	end
	local minusButton = MakeStepButton("\226\136\146", "RIGHT", -1)
	local plusButton = MakeStepButton("+", "LEFT", 1)

	local function EnsureOverlay()
		Widget.AttachLockOverlay(container, {
			nonGridPad = 10,
			frameLevel = max(plusButton:GetFrameLevel(), minusButton:GetFrameLevel(), valueBox:GetFrameLevel()) + 10,
		})
	end
	local function UpdateThumb(newValue)
		newValue = max(minValue, min(maxValue, newValue))
		newValue = floor(newValue / step + 0.5) * step
		newValue = max(minValue, min(maxValue, newValue))
		state.value = newValue
		local range = maxValue - minValue
		local percent = range > 0 and ((newValue - minValue) / range) or 0
		local trackWidth = track:GetWidth()
		local thumbWidth = thumb:GetWidth()
		if not trackWidth or trackWidth <= 0 then trackWidth = 100 end
		if not thumbWidth or thumbWidth <= 0 then thumbWidth = 12 end
		thumb:ClearAllPoints()
		thumb:SetPoint("LEFT", track, "LEFT", percent * max(1, trackWidth - thumbWidth), 0)
		valueBox:SetText(tostring(newValue))
	end
	minusButton:SetScript("OnClick", function()
		if not state.locked then UpdateThumb(state.value - step); if callback then callback(state.value) end end
	end)
	plusButton:SetScript("OnClick", function()
		if not state.locked then UpdateThumb(state.value + step); if callback then callback(state.value) end end
	end)
	track:EnableMouse(true)
	track:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and not state.locked then
			local trackLeft, trackWidth = self:GetLeft(), self:GetWidth()
			if not trackLeft or not trackWidth or trackWidth <= 0 then return end
			local cursorX = select(1, GetCursorPosition()) / track:GetEffectiveScale()
			UpdateThumb(minValue + max(0, min(1, (cursorX - trackLeft) / trackWidth)) * (maxValue - minValue))
			if callback then callback(state.value) end
		end
	end)
	valueBox:SetScript("OnEnterPressed", function(self)
		local enteredNumber = tonumber(self:GetText())
		if enteredNumber then UpdateThumb(enteredNumber); if callback then callback(state.value) end
		else self:SetText(tostring(state.value)) end
		self:ClearFocus()
	end)
	valueBox:SetScript("OnEscapePressed", function(editBox) editBox:ClearFocus() end)
	valueBox:SetScript("OnEditFocusGained", function(editBox) editBox:SetBackdropBorderColor(Theme.GetAccent()) end)
	valueBox:SetScript("OnEditFocusLost", function(editBox) editBox:SetBackdropBorderColor(unpack(Theme.border.dark)) end)
	thumb:EnableMouse(true)
	thumb:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and not state.locked then
			self.dragging = true
			self:SetScript("OnUpdate", function(thumbFrame)
				if thumbFrame.dragging then
					local trackLeft, trackWidth = track:GetLeft(), track:GetWidth()
					if not trackLeft or not trackWidth or trackWidth <= 0 then return end
					local cursorX = select(1, GetCursorPosition()) / track:GetEffectiveScale()
					local newValue = floor((minValue + max(0, min(1, (cursorX - trackLeft) / trackWidth)) * (maxValue - minValue)) / step + 0.5) * step
					if newValue ~= state.value then UpdateThumb(newValue); if callback then callback(state.value) end end
				end
			end)
		end
	end)
	thumb:SetScript("OnMouseUp", function(thumbFrame) thumbFrame.dragging = false; thumbFrame:SetScript("OnUpdate", nil) end)
	if tooltip then Widget.Tooltip(track, tooltip); Widget.Tooltip(thumb, tooltip) end
	BUILib.Defer(function() UpdateThumb(state.value) end)
	if state.locked then EnsureOverlay(); container._lockedOverlay:SetShown(true) end
	local function DeferredThumbUpdate() if container and container.GetValue then UpdateThumb(state.value) end end
	container:SetScript("OnSizeChanged", function(_, newWidth)
		local newPadding = min(30, max(20, newWidth * 0.1))
		track:ClearAllPoints()
		track:SetPoint("TOPLEFT", container, "TOPLEFT", newPadding + indentPx, -24)
		track:SetPoint("TOPRIGHT", container, "TOPRIGHT", -newPadding, -24)
		BUILib.Defer(DeferredThumbUpdate)
	end)
	function container:GetValue() return state.value end
	function container:SetValue(newValue) UpdateThumb(newValue) end
	function container:SetLockedText(text) EnsureOverlay(); container._lockedText:SetText(text or "LOCKED") end
	function container:SetLocked(shouldLock)
		state.locked = shouldLock
		EnsureOverlay()
		container._lockedOverlay:SetShown(shouldLock)
	end
	Theme.RegisterAccentElement(container, function(_, red, green, blue) recolorThumb(red, green, blue) end)
	return Widget.Wrap(container)
end
