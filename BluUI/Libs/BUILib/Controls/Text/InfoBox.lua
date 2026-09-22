local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Widget = BUILib.Widget

local INFOBOX_TYPES = {
	info    = {{0.30,0.60,1.00}, {0.30,0.60,1.00,0.06}, {0.55,0.75,1.00}},
	warning = {{0.95,0.75,0.20}, {0.95,0.75,0.20,0.06}, {0.95,0.82,0.45}},
	error   = {{0.90,0.25,0.25}, {0.90,0.25,0.25,0.06}, {1.00,0.55,0.55}},
	success = {{0.30,0.85,0.40}, {0.30,0.85,0.40,0.06}, {0.50,0.90,0.55}},
}

function Controls.InfoBox(parent, text, infoType, width)
	infoType = infoType or "info"; width = width or 400
	local colors = INFOBOX_TYPES[infoType] or INFOBOX_TYPES.info
	local accentColor, backgroundColor, textColor = colors[1], colors[2], colors[3]
	local padding = 12
	local box = Widget.New(parent, "Frame", nil, {
		bg = backgroundColor, border = {accentColor[1], accentColor[2], accentColor[3], 0.15}, width = width,
	})
	local boxFrame = box.frame
	local strip = box:CreateFill("ARTWORK", accentColor[1], accentColor[2], accentColor[3], 0.9)
	strip:SetWidth(3); strip:SetPoint("TOPLEFT", boxFrame, "TOPLEFT", 1, -1); strip:SetPoint("BOTTOMLEFT", boxFrame, "BOTTOMLEFT", 1, 1)
	local fontString = boxFrame:CreateFontString(nil, "OVERLAY")
	fontString:SetFont(BUILib.GetFont(), 11, ""); fontString:SetPoint("TOPLEFT", 3 + padding, -padding); fontString:SetWidth(width - 3 - padding * 2)
	fontString:SetText(text or ""); fontString:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
	fontString:SetJustifyH("LEFT"); fontString:SetWordWrap(true); fontString:SetSpacing(2)
	local boxHeight = fontString:GetStringHeight() + padding * 2
	boxFrame:SetHeight(boxHeight); boxFrame.text = fontString; boxFrame.strip = strip; boxFrame.layoutHeight = boxHeight
	function boxFrame:SetText(newText)
		fontString:SetText(newText); local updatedHeight = fontString:GetStringHeight() + padding * 2
		boxFrame:SetHeight(updatedHeight); boxFrame.layoutHeight = updatedHeight
	end
	return box
end
