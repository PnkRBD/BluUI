local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Widget = BUILib.Widget
local Theme = BUILib.Theme
local ROW_HEIGHT = BUILib.ROW_HEIGHT

function Controls.Button(parent, text, width, callback, tooltipOrOptions, accent)
	local options
	if type(tooltipOrOptions) == "table" then
		options = tooltipOrOptions
	else
		options = { tooltip = tooltipOrOptions, accent = accent }
	end
	width = width or 100
	local rounded = options.rounded
	if rounded == nil then rounded = true end
	local radius = options.radius or 6
	local isAccent = options.accent

	local normal = options.normal or Theme.button.normal
	local hover = options.hover or Theme.button.hover
	local borderColor = options.border or Theme.border.default

	local self, button, borderRect, fillRect
	if rounded then
		self = Widget.New(parent, "Button", nil, { raw = true, size = {width, ROW_HEIGHT} })
		button = self.frame
		fillRect, borderRect = Widget.RoundedShape(button, radius, normal, borderColor, "BACKGROUND", 0, 0)
		button:HookScript("OnEnter", function() Widget.SetShapeColor(fillRect, hover[1], hover[2], hover[3], hover[4] or 1) end)
		button:HookScript("OnLeave", function() Widget.SetShapeColor(fillRect, normal[1], normal[2], normal[3], normal[4] or 1) end)
	else
		self = Widget.New(parent, "Button", nil, { bg = normal, border = borderColor, size = {width, ROW_HEIGHT} })
		button = self.frame
		self:SetHover(normal, hover)
	end
	self.frame._noGridStretch = true
	if options.tooltip then self:SetTooltip(options.tooltip) end

	local indicator, flashAnim
	local state = { active = options.active or false, flashing = false }
	local labelOffsetX = 0
	if options.indicator then
		indicator = self:CreateFill("OVERLAY")
		indicator:SetSize(8, 8)
		indicator:SetPoint("LEFT", button, "LEFT", 10, 0)
		labelOffsetX = 6
	end

	local label = self:CreateText({text = text or ""})
	label:SetPoint("CENTER", labelOffsetX, 0)
	if isAccent then
		local red, green, blue = Theme.GetAccent()
		label:SetTextColor(red, green, blue, 1)
	end
	local textWidth = label:GetStringWidth() + 24 + (indicator and 14 or 0)
	button:SetWidth(math.max(width, textWidth))

	local function UpdateIndicator()
		if not indicator then return end
		if state.flashing then
			Widget.SetColor(indicator, 0.9, 0.2, 0.2, 1)
		elseif state.active then
			local red, green, blue = Theme.GetAccent()
			Widget.SetColor(indicator, red, green, blue, 1)
		else
			Widget.SetColor(indicator, unpack(Theme.text.muted))
		end
	end
	if indicator then
		flashAnim = button:CreateAnimationGroup()
		flashAnim:SetLooping("REPEAT")
		local fadeOut = flashAnim:CreateAnimation("Alpha")
		fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0.15); fadeOut:SetDuration(0.8); fadeOut:SetOrder(1)
		fadeOut:SetTarget(indicator)
		local fadeIn = flashAnim:CreateAnimation("Alpha")
		fadeIn:SetFromAlpha(0.15); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.8); fadeIn:SetOrder(2)
		fadeIn:SetTarget(indicator)
		UpdateIndicator()
	end

	button:SetScript("OnMouseDown", function(buttonFrame) if buttonFrame:IsEnabled() then label:SetPoint("CENTER", labelOffsetX + 1, -1) end end)
	button:SetScript("OnMouseUp", function() label:SetPoint("CENTER", labelOffsetX, 0) end)
	if callback then button:SetScript("OnClick", function() callback(state.active) end) end

	function button:SetText(newText)
		label:SetText(newText)
		local newWidth = label:GetStringWidth() + 24 + (indicator and 14 or 0)
		if newWidth > button:GetWidth() then button:SetWidth(newWidth) end
	end
	function button:GetText() return label:GetText() end
	function button:SetCallback(newCallback) button:SetScript("OnClick", function() if newCallback then newCallback(state.active) end end) end
	function button:SetEnabled(enabled)
		if enabled then
			button:Enable()
			if isAccent then local red, green, blue = Theme.GetAccent(); label:SetTextColor(red, green, blue, 1)
			else label:SetTextColor(unpack(Theme.text.primary)) end
			if rounded then Widget.SetShapeColor(fillRect, normal[1], normal[2], normal[3], normal[4] or 1)
			else button:SetBackdropColor(unpack(normal)) end
		else
			button:Disable()
			label:SetTextColor(unpack(Theme.text.disabled))
			local disabledColor = Theme.control.disabled
			if rounded then Widget.SetShapeColor(fillRect, disabledColor[1], disabledColor[2], disabledColor[3], disabledColor[4] or 1)
			else button:SetBackdropColor(unpack(disabledColor)) end
		end
	end
	function button:SetFillColor(red, green, blue, alpha) if fillRect then Widget.SetShapeColor(fillRect, red, green, blue, alpha) end end
	function button:SetBorderColor(red, green, blue, alpha) if borderRect then Widget.SetShapeColor(borderRect, red, green, blue, alpha) end end
	function button:SetActive(isActive)
		state.active = isActive and true or false
		UpdateIndicator()
	end
	function button:GetActive() return state.active end
	function button:SetFlashing(isFlashing)
		state.flashing = isFlashing and true or false
		UpdateIndicator()
		if not flashAnim then return end
		if isFlashing then flashAnim:Play() else flashAnim:Stop(); if indicator then indicator:SetAlpha(1) end end
	end
	function button:UpdateAccent(red, green, blue)
		if isAccent then label:SetTextColor(red, green, blue, 1) end
		UpdateIndicator()
	end
	Theme.RegisterAccentElement(button, function(element, red, green, blue) element:UpdateAccent(red, green, blue) end)
	button.text = label
	button.borderRect = borderRect
	button.fillRect = fillRect
	button.indicator = indicator
	return self
end
