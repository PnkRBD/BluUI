local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

local function OptionRowHeight(option)
	return (option.kind == 'dropdown' or option.kind == 'slider' or option.kind == 'textbox') and 34 or 30
end

local COLUMN_GAP = 24

local function SplitOptionColumns(options, columnCount)
	local groups, total = {}, 0
	for _, option in ipairs(options) do
		local group = groups[#groups]
		if not group or not option.indent or option.indent == 0 then
			group = { height = 0 }
			groups[#groups + 1] = group
		end
		local rowHeight = OptionRowHeight(option)
		group[#group + 1] = option
		group.height = group.height + rowHeight
		total = total + rowHeight
	end
	local target = total / columnCount
	local columns = { { height = 0 } }
	for _, group in ipairs(groups) do
		local column = columns[#columns]
		if #columns < columnCount and column.height > 0 and column.height + group.height / 2 > target then
			column = { height = 0 }
			columns[#columns + 1] = column
		end
		for _, option in ipairs(group) do column[#column + 1] = option end
		column.height = column.height + group.height
	end
	local tallest = 0
	for _, column in ipairs(columns) do tallest = math.max(tallest, column.height) end
	return columns, tallest
end

local function BuildOptionRow(panel, config, option, columnX, columnWidth, yOffset)
	local rowHeight = OptionRowHeight(option)
	local fontString = panel:CreateFontString(nil, "OVERLAY")
	fontString:SetFont(BUILib.Font, 11, "")
	fontString:SetPoint("TOPLEFT", columnX + (option.indent or 0) * 14, -(yOffset + math.floor(rowHeight / 2 - 5)))
	if (option.indent or 0) > 0 then
		fontString:SetTextColor(unpack(Theme.text.secondary))
	else
		fontString:SetTextColor(0.85, 0.85, 0.88, 1)
	end
	fontString:SetText(option.label)
	local function changed(value)
		option.set(value)
		if config.onChange then config.onChange() end
	end
	local control
	if option.kind == 'slider' then
		control = Controls.CompactSlider(panel, nil, option.min, option.max, option.get(), changed, option.step or 1, option.controlWidth or 130)
		if option.locked then
			control:SetLockedText(option.lockedText or 'LOCKED')
			control:SetLocked(true)
		end
	elseif option.kind == 'dropdown' then
		control = Controls.Dropdown(panel, nil, option.items, option.get(), changed, nil, option.controlWidth or 110)
	elseif option.kind == 'textbox' then
		control = Controls.TextBox(panel, nil, option.get(), changed, nil, option.controlWidth or 130)
	else
		control = Controls.StampCheckbox(panel, nil, option.get(), changed, nil, true, nil, "mini")
	end
	local controlFrame = Widget.Unwrap(control)
	controlFrame:ClearAllPoints()
	local controlHeight = controlFrame:GetHeight() or 20
	controlFrame:SetPoint("TOPRIGHT", panel, "TOPLEFT", columnX + columnWidth, -(yOffset + math.max(2, math.floor((rowHeight - controlHeight) / 2))))
	if option.kind == 'dropdown' and control.SetWidth then control:SetWidth(option.controlWidth or 110) end
	return rowHeight
end

local function BuildOptionsPopover(anchorButton, config)
	local columnCount = config.columns or 1
	local columns, tallest = SplitOptionColumns(config.options or {}, columnCount)
	Controls.Popover({
		anchor = anchorButton, width = (config.width or 240) * #columns, title = config.title,
		height = tallest,
		build = function(panel)
			local columnWidth = (panel.width - COLUMN_GAP * (#columns - 1)) / #columns
			for columnIndex, column in ipairs(columns) do
				local columnX = (columnIndex - 1) * (columnWidth + COLUMN_GAP)
				if columnIndex > 1 then
					local divider = panel:CreateTexture(nil, "ARTWORK")
					divider:SetColorTexture(unpack(Theme.border.light))
					divider:SetPoint("TOP", panel, "TOPLEFT", columnX - COLUMN_GAP / 2, 0)
					divider:SetHeight(tallest)
					PixelUtil.SetWidth(divider, 1, 1)
				end
				local yOffset = 0
				for _, option in ipairs(column) do
					yOffset = yOffset + BuildOptionRow(panel, config, option, columnX, columnWidth, yOffset)
				end
			end
		end,
	})
end

local DEFAULT_IDLE_COLOR = {0.7, 0.7, 0.72, 1}

local PRESETS = {
	close = { icon = "x", size = 24, iconScale = 0.62, idleColor = Theme.text.muted, hoverColor = {1, 0.4, 0.4} },
	clear = { icon = "x", size = 18, iconScale = 0.8, idleColor = Theme.text.muted, hoverColor = {1, 1, 1} },
}

function Controls.Icon(parent, config)
	config = config or {}
	local preset = config.preset and PRESETS[config.preset]
	if preset then
		local merged = {}
		for key, value in pairs(preset) do merged[key] = value end
		for key, value in pairs(config) do merged[key] = value end
		config = merged
	end

	local size = config.size or 18
	local iconScale = config.iconScale or 1
	local idleColor = config.idleColor or DEFAULT_IDLE_COLOR
	local hoverColor = config.hoverColor
	local button = CreateFrame("Button", nil, Widget.Unwrap(parent))
	button:SetSize(size, size)
	button:RegisterForClicks("AnyUp")

	local icon = button:CreateTexture(nil, "ARTWORK")
	local inset = math.floor(size * (1 - iconScale) / 2 + 0.5)
	icon:SetPoint("TOPLEFT", inset, -inset)
	icon:SetPoint("BOTTOMRIGHT", -inset, inset)
	if config.atlas then
		icon:SetAtlas(config.atlas)
	else
		icon:SetTexture(config.texture or BUILib.GetLibMedia(config.icon or "cog"))
	end

	local function ApplyIdleColor()
		icon:SetVertexColor(idleColor[1], idleColor[2], idleColor[3], idleColor[4] or 1)
	end
	local function ApplyHoverColor()
		if hoverColor then
			icon:SetVertexColor(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4] or 1)
		else
			local accentRed, accentGreen, accentBlue = Theme.GetAccent()
			icon:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
		end
	end
	ApplyIdleColor()

	button:SetScript("OnEnter", function(self)
		ApplyHoverColor()
		if config.tooltip and Widget.ShowTip then Widget.ShowTip(self, config.tooltip) end
	end)
	button:SetScript("OnLeave", function()
		ApplyIdleColor()
		if config.tooltip and Widget.HideTip then Widget.HideTip() end
	end)

	local onClick = config.onClick
	if config.options then
		onClick = function(clickedButton) BuildOptionsPopover(clickedButton, config) end
	end
	if onClick then button:SetScript("OnClick", function() onClick(button) end) end

	if config.fadeHost then Widget.HoverFade(button, config.fadeHost) end

	button.icon = icon
	function button:SetCallback(callback) button:SetScript("OnClick", function() if callback then callback(button) end end) end
	function button:SetIcon(nameOrPath)
		if type(nameOrPath) == "string" and nameOrPath:find("\\") then
			icon:SetTexture(nameOrPath)
		else
			icon:SetTexture(BUILib.GetLibMedia(nameOrPath or "cog"))
		end
	end
	function button:SetIdleColor(red, green, blue, alpha)
		idleColor = {red, green, blue, alpha or 1}
		if not button:IsMouseOver() then ApplyIdleColor() end
	end
	return Widget.Wrap(button)
end
