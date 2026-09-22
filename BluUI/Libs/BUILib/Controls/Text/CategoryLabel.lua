local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

function Controls.CategoryLabel(parent, text, width, description)
	width = width or 200
	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	local label = container:CreateFontString(nil, "OVERLAY")
	label:SetFont(BUILib.Font, 16, ""); label:SetPoint("TOPLEFT"); label:SetText(text or "Category")
	label:SetTextColor(unpack(Theme.text.primary))
	local descriptionText, lineY = nil, -22
	if description then
		descriptionText = container:CreateFontString(nil, "OVERLAY")
		descriptionText:SetFont(BUILib.Font, 12, ""); descriptionText:SetPoint("TOPLEFT", 0, -20); descriptionText:SetPoint("RIGHT")
		descriptionText:SetJustifyH("LEFT"); descriptionText:SetText(description); descriptionText:SetTextColor(unpack(Theme.text.muted)); lineY = -38
	end
	local line = Widget.Create(container, 0.08, 0.08, 0.08, 1)
	line:SetHeight(1); line:SetPoint("TOPLEFT", 0, lineY); line:SetPoint("TOPRIGHT", 0, lineY)
	container:SetSize(width, description and 42 or 28)
	container.label = label; container.line = line; container.desc = descriptionText
	function container:SetText(newText) label:SetText(newText) end
	return Widget.Wrap(container)
end
