local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Widget = BUILib.Widget
local Theme = BUILib.Theme

local DEFAULTS = {
	height       = 27,
	iconSize     = 15,
	iconGap      = 7,
	labelOffsetX = 11,
	dotSize      = 5,
	dotInset     = 5,
	fontSize     = 11,
	hoverScale   = 0.24,
}

local FILL_COLOR  = { 0.02, 0.022, 0.026, 1 }
local LABEL_IDLE  = { 0.8, 0.8, 0.84 }
local ICON_IDLE   = { 0.74, 0.74, 0.78 }

local function Option(options, key)
	local value = options[key]
	if value == nil then return DEFAULTS[key] end
	return value
end

-- A square icon+label row: solid fill, accent wash on hover, optional corner dot.
function Controls.ToolButton(parent, options)
	options = options or {}
	local fill = options.fill or FILL_COLOR
	local hoverScale = Option(options, "hoverScale")

	local button = CreateFrame("Button", nil, Widget.Unwrap(parent))
	button:SetHeight(Option(options, "height"))

	local fillTexture = button:CreateTexture(nil, "BACKGROUND")
	fillTexture:SetAllPoints(button)
	fillTexture:SetColorTexture(1, 1, 1, 1)
	fillTexture:SetVertexColor(fill[1], fill[2], fill[3], fill[4] or 1)
	button.fill = fillTexture

	local label = button:CreateFontString(nil, "OVERLAY")
	label:SetFont(options.font or BUILib.Font, Option(options, "fontSize"), "")
	label:SetPoint("CENTER", Option(options, "labelOffsetX"), 0)
	label:SetJustifyH("LEFT")
	label:SetText(options.label or "")
	label:SetTextColor(LABEL_IDLE[1], LABEL_IDLE[2], LABEL_IDLE[3])
	button.label = label

	local iconSize = Option(options, "iconSize")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("RIGHT", label, "LEFT", -Option(options, "iconGap"), 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetVertexColor(ICON_IDLE[1], ICON_IDLE[2], ICON_IDLE[3])
	button.icon = icon

	local dotSize = Option(options, "dotSize")
	local dotInset = Option(options, "dotInset")
	local dot = button:CreateTexture(nil, "OVERLAY")
	dot:SetSize(dotSize, dotSize)
	dot:SetPoint("TOPRIGHT", -dotInset, -dotInset)
	dot:Hide()
	button.dot = dot

	function button:SetIconAtlas(atlas)
		self.icon:SetAtlas(atlas)
		self.icon:SetVertexColor(ICON_IDLE[1], ICON_IDLE[2], ICON_IDLE[3])
	end

	function button:SetIconTexture(texture)
		self.icon:SetTexture(texture)
		self.icon:SetVertexColor(ICON_IDLE[1], ICON_IDLE[2], ICON_IDLE[3])
	end

	if options.atlas then button:SetIconAtlas(options.atlas)
	elseif options.texture then button:SetIconTexture(options.texture) end

	button:SetScript("OnEnter", function(self)
		local red, green, blue = Theme.GetAccent()
		Widget.SetShapeColor(self.fill, red * hoverScale, green * hoverScale, blue * hoverScale, 1)
		self.icon:SetVertexColor(1, 1, 1)
		self.label:SetTextColor(1, 1, 1)
	end)
	button:SetScript("OnLeave", function(self)
		Widget.SetShapeColor(self.fill, fill[1], fill[2], fill[3], fill[4] or 1)
		self.icon:SetVertexColor(ICON_IDLE[1], ICON_IDLE[2], ICON_IDLE[3])
		self.label:SetTextColor(LABEL_IDLE[1], LABEL_IDLE[2], LABEL_IDLE[3])
	end)
	if options.onClick then
		button:SetScript("OnClick", function(self, mouseButton) options.onClick(self, mouseButton) end)
	end

	return button
end
