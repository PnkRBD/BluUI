local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Widget = BUILib.Widget
local Theme = BUILib.Theme
local ROW_HEIGHT = BUILib.ROW_HEIGHT

function Controls.GhostButton(parent, text, width, callback, tooltip)
	width = width or 100
	local self = Widget.New(parent, "Button", nil, { raw = true, size = {width, ROW_HEIGHT} })
	local ghostBorder = Widget.DrawOutline(self.frame, Widget.INPUT_RADIUS, Theme.border.light)
	self.frame._noGridStretch = true
	if tooltip then self:SetTooltip(tooltip) end
	local frame = self.frame
	local label = self:CreateText({text = text or "", color = Theme.text.secondary})
	label:SetPoint("CENTER")
	local textWidth = label:GetStringWidth() + 24
	if textWidth > width then frame:SetWidth(textWidth) end
	frame:HookScript("OnEnter", function(button)
		local red, green, blue = Theme.GetAccent()
		Widget.SetShapeColor(ghostBorder, red, green, blue, 1)
		label:SetTextColor(red, green, blue, 1)
	end)
	frame:HookScript("OnLeave", function(button)
		Widget.SetShapeColor(ghostBorder, unpack(Theme.border.light))
		label:SetTextColor(unpack(Theme.text.secondary))
	end)
	frame:SetScript("OnMouseDown", function(button) if button:IsEnabled() then label:SetPoint("CENTER", 1, -1) end end)
	frame:SetScript("OnMouseUp", function() label:SetPoint("CENTER", 0, 0) end)
	if callback then frame:SetScript("OnClick", function() callback() end) end
	function frame:SetText(newText)
		label:SetText(newText)
		local newWidth = label:GetStringWidth() + 24
		if newWidth > frame:GetWidth() then frame:SetWidth(newWidth) end
	end
	function frame:GetText() return label:GetText() end
	function frame:SetCallback(newCallback) frame:SetScript("OnClick", function() if newCallback then newCallback() end end) end
	function frame:SetEnabled(enabled)
		if enabled then
			frame:Enable()
			label:SetTextColor(unpack(Theme.text.secondary))
			Widget.SetShapeColor(ghostBorder, unpack(Theme.border.light))
		else
			frame:Disable()
			label:SetTextColor(unpack(Theme.text.disabled))
			Widget.SetShapeColor(ghostBorder, unpack(Theme.border.dark))
		end
	end
	frame.text = label
	return self
end
