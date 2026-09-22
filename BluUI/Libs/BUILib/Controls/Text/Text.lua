local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Widget = BUILib.Widget
local DEFAULT_FONT_SIZE = BUILib.FONT_SIZE
local unpack = unpack

function Controls.Text(parent, text, size, color)
	local parentFrame = Widget.Unwrap(parent)
	local fontString = parentFrame:CreateFontString(nil, "OVERLAY")
	fontString:SetFont(BUILib.GetFont(), size or DEFAULT_FONT_SIZE, "")
	fontString:SetText(text or ""); fontString:SetTextColor(unpack(color or BUILib.Theme.text.primary))
	return fontString
end
