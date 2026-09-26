local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Widget = BUILib.Widget
local Theme = BUILib.Theme
local CONTROL_HEIGHT = BUILib.CONTROL_HEIGHT

local min = math.min
local GetTime = GetTime

function Controls.HoldButton(parent, text, callback, duration, width)
	duration = duration or 1.5
	width = Widget.EvenSize(width or 100)
	local self = Widget.New(parent, "Button", nil, { raw = true, size = {width, CONTROL_HEIGHT} })
	local frame = self.frame
	frame._noGridStretch = true
	Widget.RoundedShape(frame, Widget.INPUT_RADIUS, Theme.button.normal, Theme.border.default, "BACKGROUND", 0, 0)

	local progress = self:CreateFill("ARTWORK")
	progress:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	progress:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
	progress:SetWidth(0)
	local red, green, blue = Theme.GetAccent()
	Widget.SetColor(progress, red, green, blue, 0.3)

	local label = self:CreateText({text = text or "Hold"})
	label:SetPoint("CENTER")
	local textWidth = label:GetStringWidth() + 24
	if textWidth > width then
		width = Widget.EvenSize(textWidth)
		frame:SetWidth(width)
	end

	local holding, startTime = false, 0

	local function stopHolding()
		holding = false
		progress:SetWidth(0)
		frame:SetScript("OnUpdate", nil)
	end

	local function tick()
		if not holding then return end
		local fraction = min(1, (GetTime() - startTime) / duration)
		progress:SetWidth((frame:GetWidth() - 2) * fraction)
		if fraction >= 1 then
			stopHolding()
			if callback then callback() end
		end
	end

	frame:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			holding = true
			startTime = GetTime()
			frame:SetScript("OnUpdate", tick)
		end
	end)
	frame:SetScript("OnMouseUp", stopHolding)

	function frame:SetText(newText)
		label:SetText(newText)
		local newWidth = label:GetStringWidth() + 24
		if newWidth > frame:GetWidth() then frame:SetWidth(Widget.EvenSize(newWidth)) end
	end
	function frame:UpdateAccent(newRed, newGreen, newBlue) Widget.SetColor(progress, newRed, newGreen, newBlue, 0.3) end
	Theme.RegisterAccentElement(frame, function(element, newRed, newGreen, newBlue) element:UpdateAccent(newRed, newGreen, newBlue) end)
	frame.text = label
	frame.progress = progress
	return self
end
