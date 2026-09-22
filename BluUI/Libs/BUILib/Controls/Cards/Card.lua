local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local unpack, type = unpack, type

function Controls.Card(parent, icon, title, description, width, height, clickable, callback)
	if type(height) == "boolean" then callback = clickable; clickable = height; height = width end
	width = width or 140; height = height or width
	local cardWidget = Widget.New(parent, clickable and "Button" or "Frame", nil, {bg = Theme.bg.card, border = {0.4, 0.4, 0.4, 1}, size = {width, height}})
	local card = cardWidget.frame; card:SetClipsChildren(true)
	local content = CreateFrame("Frame", nil, card)
	content:SetPoint("LEFT", 8, 0); content:SetPoint("RIGHT", -8, 0)
	local iconSize = width >= 180 and 48 or 32
	content:SetPoint("CENTER", 0, 0)
	local yOffset = 0
	if icon then
		local iconTexture = Widget.Icon(content, icon, iconSize, Widget.ICON_ZOOM, true)
		iconTexture:SetPoint("TOP", 0, -yOffset - 4); card.icon = iconTexture; yOffset = yOffset + iconSize + 16
	end
	local titleFontSize = width >= 180 and 14 or 12
	local titleText = content:CreateFontString(nil, "OVERLAY")
	titleText:SetFont(BUILib.GetFont(), titleFontSize, ""); titleText:SetWidth(width - 20)
	titleText:SetPoint("TOP", 0, -yOffset); titleText:SetText(title or "")
	titleText:SetTextColor(1, 1, 1, 1); titleText:SetJustifyH("CENTER"); titleText:SetWordWrap(true); titleText:SetMaxLines(2)
	card.title = titleText; yOffset = yOffset + titleText:GetStringHeight() + 2
	if description then
		local descFontSize = width >= 180 and 12 or 10
		local descText = content:CreateFontString(nil, "OVERLAY")
		descText:SetFont(BUILib.GetFont(), descFontSize, ""); descText:SetWidth(width - 20)
		descText:SetPoint("TOP", 0, -yOffset); descText:SetText(description)
		descText:SetTextColor(unpack(Theme.text.muted)); descText:SetJustifyH("CENTER"); descText:SetWordWrap(true); descText:SetMaxLines(2)
		card.description = descText
	end
	content:SetHeight(yOffset + 4)
	if clickable then
		card:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(Theme.GetAccent()) end)
		card:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1) end)
		card:SetScript("OnClick", function(self) if callback then callback(self) end end)
	end
	function card:SetIcon(texture) if card.icon then card.icon:SetTexture(texture) end end
	return card
end
