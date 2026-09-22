local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE

function Controls.LinkText(parent, text, callback)
	local parentFrame = Widget.Unwrap(parent)
	local button = CreateFrame("Button", nil, parentFrame); button:SetHeight(18)
	local fontString = button:CreateFontString(nil, "OVERLAY")
	fontString:SetFont(BUILib.GetFont(), FONT_SIZE, ""); fontString:SetPoint("LEFT"); fontString:SetText(text or "Link")
	local red, green, blue = Theme.GetAccent()
	fontString:SetTextColor(red, green, blue, 1)
	button:SetWidth(fontString:GetStringWidth() + 4)
	button:SetScript("OnEnter", function() fontString:SetTextColor(1, 1, 1, 1) end)
	button:SetScript("OnLeave", function() fontString:SetTextColor(red, green, blue, 1) end)
	button:SetScript("OnClick", function() if callback then callback() end end)
	button.text = fontString
	return Widget.Wrap(button)
end
