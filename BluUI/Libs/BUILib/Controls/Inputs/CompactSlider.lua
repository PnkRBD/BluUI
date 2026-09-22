local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE
local math_floor, math_max, math_min = math.floor, math.max, math.min
local select, unpack, tostring = select, unpack, tostring

function Controls.CompactSlider(parent, label, minVal, maxVal, value, callback, step, width, locked, tooltip)
	local hasLabel = label and label ~= ""
	width = width or (hasLabel and 280 or 200); step = step or 1; value = value or minVal or 0
	minVal = minVal or 0; maxVal = maxVal or 100
	local parentFrame = Widget.Unwrap(parent)
	local buttonSize, editBoxWidth, gap = 20, 46, 4
	local rowTop = hasLabel and -18 or 0
	local container = CreateFrame("Frame", nil, parentFrame)
	container:SetSize(width, hasLabel and 38 or 20)
	local state = {value = value, locked = locked or false}

	if hasLabel then
		local labelText = Controls.Text(container, label, FONT_SIZE, Theme.text.primary)
		labelText:SetPoint("TOPLEFT"); labelText:SetJustifyH("LEFT")
	end

	local function MakeButton(text, anchor, offsetX)
		local buttonWidget = Widget.New(container, "Button", nil, {bg = Theme.button.normal, border = Theme.button.normal, size = {buttonSize, buttonSize}})
		buttonWidget.frame:SetPoint(anchor, offsetX, rowTop)
		local buttonText = buttonWidget:CreateText({size = 14, text = text, color = Theme.text.secondary})
		buttonText:SetPoint("CENTER")
		return buttonWidget.frame, buttonText
	end
	local minusButton, minusText = MakeButton("\226\136\146", "TOPLEFT", 0)
	local plusButton, plusText = MakeButton("+", "TOPRIGHT", -(editBoxWidth + gap))

	local trackWidget = Widget.New(container, "Frame", nil, {bg = Theme.control.track, border = Theme.border.dark, height = 4})
	local track = trackWidget.frame
	track:SetPoint("LEFT", minusButton, "RIGHT", gap, 0)
	track:SetPoint("RIGHT", plusButton, "LEFT", -gap, 0)
	track:SetPoint("TOP", 0, rowTop - math_floor((buttonSize - 4) / 2))

	local accentRed, accentGreen, accentBlue = Theme.GetAccent()
	local fill = track:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", 1, -1); fill:SetHeight(2); fill:SetColorTexture(accentRed, accentGreen, accentBlue, 1)

	local thumb = Widget.New(track, "Frame", nil, {size = {10, 14}}).frame
	thumb:SetBackdropColor(accentRed, accentGreen, accentBlue, 1); thumb:SetBackdropBorderColor(accentRed * 0.7, accentGreen * 0.7, accentBlue * 0.7, 1)

	local valueBox = CreateFrame("EditBox", nil, container, "BackdropTemplate")
	valueBox:SetSize(editBoxWidth, buttonSize); valueBox:SetPoint("TOPRIGHT", 0, rowTop)
	valueBox:SetAutoFocus(false); valueBox:SetFont(BUILib.Font, 12, "")
	valueBox:SetTextColor(1, 1, 1); valueBox:SetJustifyH("CENTER"); valueBox:SetMaxLetters(10)
	valueBox:SetBackdrop(Widget.BACKDROP); valueBox:SetBackdropColor(unpack(Theme.bg.input)); valueBox:SetBackdropBorderColor(unpack(Theme.border.dark))

	local function UpdateThumb(newValue)
		newValue = math_floor(math_max(minVal, math_min(maxVal, newValue)) / step + 0.5) * step
		newValue = math_max(minVal, math_min(maxVal, newValue)); state.value = newValue
		local fraction = (maxVal > minVal) and ((newValue - minVal) / (maxVal - minVal)) or 0
		local trackWidth, thumbWidth = track:GetWidth() or 100, thumb:GetWidth() or 12
		local usable = math_max(1, trackWidth - thumbWidth)
		thumb:ClearAllPoints(); thumb:SetPoint("LEFT", track, "LEFT", fraction * usable, 0)
		fill:SetWidth(math_max(1, fraction * usable + thumbWidth * 0.5))
		valueBox:SetText(tostring(newValue))
	end

	local function Step(direction)
		if not state.locked then UpdateThumb(state.value + direction * step); if callback then callback(state.value) end end
	end
	local function TrackClick(self)
		if state.locked then return end
		local left, trackWidth = self:GetLeft(), self:GetWidth()
		if not left or not trackWidth or trackWidth <= 0 then return end
		local cursorX = select(1, GetCursorPosition()) / track:GetEffectiveScale()
		UpdateThumb(minVal + math_max(0, math_min(1, (cursorX - left) / trackWidth)) * (maxVal - minVal))
		if callback then callback(state.value) end
	end
	local function ButtonHover(button, buttonText, isHovering)
		if isHovering and not state.locked then button:SetBackdropColor(unpack(Theme.button.hover)); buttonText:SetTextColor(1, 1, 1)
		else button:SetBackdropColor(unpack(Theme.button.normal)); buttonText:SetTextColor(unpack(Theme.text.secondary)) end
	end

	minusButton:SetScript("OnClick", function() Step(-1) end)
	plusButton:SetScript("OnClick", function() Step(1) end)
	minusButton:SetScript("OnEnter", function(button) ButtonHover(button, minusText, true) end)
	minusButton:SetScript("OnLeave", function(button) ButtonHover(button, minusText, false) end)
	plusButton:SetScript("OnEnter", function(button) ButtonHover(button, plusText, true) end)
	plusButton:SetScript("OnLeave", function(button) ButtonHover(button, plusText, false) end)

	track:EnableMouse(true)
	track:SetScript("OnMouseDown", function(self, mouseButton) if mouseButton == "LeftButton" then TrackClick(self) end end)

	valueBox:SetScript("OnEnter", function(editBox) if not state.locked then editBox:SetBackdropBorderColor(Theme.GetAccent()) end end)
	valueBox:SetScript("OnLeave", function(editBox) if not editBox:HasFocus() then editBox:SetBackdropBorderColor(unpack(Theme.border.dark)) end end)
	valueBox:SetScript("OnEnterPressed", function(editBox)
		local typedNumber = tonumber(editBox:GetText())
		if typedNumber then UpdateThumb(typedNumber); if callback then callback(state.value) end else editBox:SetText(tostring(state.value)) end
		editBox:ClearFocus()
	end)
	valueBox:SetScript("OnEscapePressed", function(editBox) editBox:ClearFocus() end)
	valueBox:SetScript("OnEditFocusGained", function(editBox) editBox:SetBackdropBorderColor(Theme.GetAccent()) end)
	valueBox:SetScript("OnEditFocusLost", function(editBox) editBox:SetBackdropBorderColor(unpack(Theme.border.dark)) end)

	thumb:EnableMouse(true)
	thumb:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton" and not state.locked then
			self.dragging = true
			self:SetScript("OnUpdate", function(draggedThumb)
				if not draggedThumb.dragging then return end
				local left, trackWidth = track:GetLeft(), track:GetWidth()
				if not left or not trackWidth or trackWidth <= 0 then return end
				local cursorX = select(1, GetCursorPosition()) / track:GetEffectiveScale()
				local newValue = math_floor((minVal + math_max(0, math_min(1, (cursorX - left) / trackWidth)) * (maxVal - minVal)) / step + 0.5) * step
				if newValue ~= state.value then UpdateThumb(newValue); if callback then callback(state.value) end end
			end)
		end
	end)
	thumb:SetScript("OnMouseUp", function(draggedThumb) draggedThumb.dragging = false; draggedThumb:SetScript("OnUpdate", nil) end)

	if tooltip then Widget.Tooltip(track, tooltip); Widget.Tooltip(thumb, tooltip) end
	BUILib.Defer(function() UpdateThumb(state.value) end)

	local function EnsureOverlay()
		Widget.AttachLockOverlay(container, {nonGridPad = 4})
	end

	local function DeferredThumbUpdate() if container.GetValue then UpdateThumb(state.value) end end
	container:SetScript("OnSizeChanged", function() BUILib.Defer(DeferredThumbUpdate) end)
	function container:GetValue() return state.value end
	function container:SetValue(newValue) UpdateThumb(newValue) end
	function container:SetLocked(isLocked)
		state.locked = isLocked
		EnsureOverlay()
		container._lockedOverlay:SetShown(isLocked)
	end
	function container:SetLockedText(text)
		EnsureOverlay()
		container._lockedText:SetText(text or "LOCKED")
	end
	if state.locked then container:SetLocked(true) end
	Theme.RegisterAccentElement(container, function(_, red, green, blue)
		thumb:SetBackdropColor(red, green, blue, 1); thumb:SetBackdropBorderColor(red * 0.7, green * 0.7, blue * 0.7, 1)
		fill:SetColorTexture(red, green, blue, 1)
	end)
	return Widget.Wrap(container)
end
