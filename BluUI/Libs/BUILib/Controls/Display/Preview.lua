local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local WidgetLib = BUILib.Widget
local unpack = unpack
local WHITE = "Interface\\Buttons\\WHITE8x8"

local CORNER_RADIUS = 10

function Controls.Preview(parent, title, width, height, bgColor)
	width = width or 300
	height = height or 150

	local parentFrame = type(parent) == "table" and parent.frame or parent

	local shell = CreateFrame("Frame", nil, parentFrame)
	shell:SetSize(width, height)

	WidgetLib.DrawRoundedRect(shell, CORNER_RADIUS,     {0.20, 0.22, 0.26, 0.50}, "BACKGROUND", 0, 0)
	WidgetLib.DrawRoundedRect(shell, CORNER_RADIUS - 1, Theme.bg.card,            "BACKGROUND", 1, 1)

	local titleHeight = 0
	if title then
		titleHeight = 28

		local titleText = shell:CreateFontString(nil, "OVERLAY")
		titleText:SetFont(BUILib.Font, 13, "")
		titleText:SetPoint("TOPLEFT", 14, -8)
		titleText:SetText(title)
		titleText:SetTextColor(0.9, 0.9, 0.9, 1)

		local accentRed, accentGreen, accentBlue = Theme.GetAccent()
		local dot = shell:CreateTexture(nil, "OVERLAY")
		dot:SetSize(4, 4)
		dot:SetPoint("RIGHT", titleText, "LEFT", -6, 0)
		dot:SetTexture("Interface\\COMMON\\WhiteCircle")
		dot:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
		Theme.RegisterAccentElement(dot, function(element, red, green, blue) element:SetVertexColor(red, green, blue, 1) end)

		local divider = shell:CreateTexture(nil, "OVERLAY")
		divider:SetColorTexture(0.08, 0.08, 0.08, 1)
		divider:SetHeight(1)
		divider:SetPoint("TOPLEFT", CORNER_RADIUS, -titleHeight)
		divider:SetPoint("TOPRIGHT", -CORNER_RADIUS, -titleHeight)

		shell.titleText = titleText
	end

	local content = CreateFrame("Frame", nil, shell)
	content:SetPoint("TOPLEFT", 1, -(titleHeight + 1))
	content:SetPoint("BOTTOMRIGHT", -1, 1)
	content:SetClipsChildren(false)
	shell.content = content

	local horizontalLine = content:CreateTexture(nil, "ARTWORK")
	horizontalLine:SetTexture(WHITE); horizontalLine:SetVertexColor(1, 1, 1, 0.03)
	horizontalLine:SetHeight(1); horizontalLine:SetPoint("LEFT"); horizontalLine:SetPoint("RIGHT")

	local verticalLine = content:CreateTexture(nil, "ARTWORK")
	verticalLine:SetTexture(WHITE); verticalLine:SetVertexColor(1, 1, 1, 0.03)
	verticalLine:SetWidth(1); verticalLine:SetPoint("TOP"); verticalLine:SetPoint("BOTTOM")

	function shell:GetContent()
		return content
	end

	function shell:ShowCrosshair(show)
		horizontalLine:SetShown(show)
		verticalLine:SetShown(show)
	end

	shell.layoutHeight = height

	return Widget.Wrap(shell)
end
