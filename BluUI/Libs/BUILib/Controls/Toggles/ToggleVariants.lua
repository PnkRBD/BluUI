local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE
local unpack = unpack

local ANIMATION_DURATION = 0.14

function Widget.ToggleLerp(fromValue, toValue, progress) return fromValue + (toValue - fromValue) * progress end

function Widget.ToggleLabel(container, anchor, label, offset)
	if not label then return nil end
	local labelFontString = Controls.Text(container, label, FONT_SIZE, Theme.text.primary)
	labelFontString:SetPoint("LEFT", anchor, "RIGHT", offset, 0)
	return labelFontString
end

function Widget.AttachToggle(container, state, progressRef, render, snap, clickFrame, callback, tooltip, labelFontString, duration, easeFunction)
	clickFrame:SetScript("OnClick", function()
		if state.disabled then return end
		state.enabled = not state.enabled
		local startProgress = progressRef.progress
		local targetProgress = state.enabled and 1 or 0
		local startTime = GetTime()
		container:SetScript("OnUpdate", function(self)
			local elapsedFraction = (GetTime() - startTime) / duration
			if elapsedFraction >= 1 then
				progressRef.progress = targetProgress
				self:SetScript("OnUpdate", nil)
			else
				progressRef.progress = startProgress + (targetProgress - startProgress) * easeFunction(elapsedFraction)
			end
			render()
		end)
		if callback then callback(state.enabled) end
	end)
	if tooltip then Widget.Tooltip(clickFrame, tooltip) end
	snap()
	Theme.RegisterAccentElement(container, function() render() end)

	function container:GetValue() return state.enabled end
	function container:SetValue(value) state.enabled = value; snap() end
	function container:SetEnabled(isEnabled) state.disabled = not isEnabled; snap() end
	container.toggle = clickFrame
	container.label = labelFontString
end

local Lerp = Widget.ToggleLerp
local function BuildLabel(container, track, label) return Widget.ToggleLabel(container, track, label, 8) end
local function EaseQuad(progress) return 1 - (1 - progress) * (1 - progress) end
local function AttachStandardToggle(container, state, progressRef, render, snap, track, callback, tooltip, labelFontString)
	Widget.AttachToggle(container, state, progressRef, render, snap, track, callback, tooltip, labelFontString, ANIMATION_DURATION, EaseQuad)
end

local function ResolveContainerWidth(width, label, indentPixels, trackWidth)
	return math.max(width or (label and 200 or trackWidth), trackWidth + indentPixels)
end

function Controls.StatusToggle(parent, label, checked, callback, indentLevel, enabled, tooltip)
	return Controls.SwitchToggle(parent, label, checked, callback, indentLevel, enabled, tooltip, 44, 22)
end

local STAMP_PRESETS = {
	small   = { box = 18 },
	midsize = { box = 21 },
	medium  = { box = 24 },
	large   = { box = 26 },
}

function Controls.StampCheckbox(parent, label, checked, callback, indentLevel, enabled, tooltip, sizeName)
	local preset = STAMP_PRESETS[sizeName] or STAMP_PRESETS.midsize
	local size = preset.box
	local indentPixels = (indentLevel or 0) * 20
	if enabled == nil then enabled = true end
	local state = { enabled = checked or false, disabled = not enabled }

	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	container._noGridStretch = true

	local track = CreateFrame("Button", nil, container)
	if PixelUtil and PixelUtil.SetSize then PixelUtil.SetSize(track, size, size) else track:SetSize(size, size) end
	track:SetPoint("LEFT", indentPixels, 0)

	local TRANSPARENT = { 0, 0, 0, 0 }
	local stroke = Widget.DrawCardShape(track, 5, { 0.38, 0.38, 0.40, 1 }, TRANSPARENT, "BACKGROUND", 0, 0)
	local fill = Widget.DrawCardShape(track, 4, { 0.05, 0.055, 0.06, 1 }, TRANSPARENT, "BACKGROUND", 2, 1)

	local markBase = math.floor(size * 0.72 + 0.5)
	local mark = track:CreateTexture(nil, "ARTWORK")
	mark:SetTexture(BUILib.GetLibMedia("check"))
	mark:SetSize(markBase, markBase)
	mark:SetPoint("CENTER", 0, 0)

	local labelFontString = BuildLabel(container, track, label)
	local labelWidth = labelFontString and (math.ceil(labelFontString:GetStringWidth()) + 8) or 0
	container:SetSize(indentPixels + size + labelWidth, size + 4)

	local progressRef = { progress = state.enabled and 1 or 0 }
	local hover = false

	local function Render()
		local progress = progressRef.progress
		local popAmount = state.enabled and (1 - progress) or 0
		local markSize = markBase * (1 + 0.25 * popAmount)
		mark:SetSize(markSize, markSize)
		if state.disabled then
			Widget.SetShapeColor(stroke, unpack(Theme.border.dark))
			Widget.SetShapeColor(fill, 0.05, 0.05, 0.05, 1)
			mark:SetVertexColor(0.5, 0.5, 0.5, 1)
			mark:SetAlpha(0.5 * progress)
			if labelFontString then labelFontString:SetTextColor(unpack(Theme.text.disabled)) end
			return
		end

		local red, green, blue = Theme.GetAccent()
		local offRim = hover and 0.52 or 0.38
		Widget.SetShapeColor(stroke, Lerp(offRim, red, progress), Lerp(offRim, green, progress), Lerp(offRim, blue, progress), 1)
		Widget.SetShapeColor(fill, Lerp(0.05, red * 0.7, progress), Lerp(0.055, green * 0.7, progress), Lerp(0.06, blue * 0.7, progress), 1)

		mark:SetVertexColor(1, 1, 1, 1)
		mark:SetAlpha(progress)

		if labelFontString then labelFontString:SetTextColor(unpack(state.enabled and Theme.text.primary or Theme.text.muted)) end
	end

	track:SetScript("OnEnter", function() hover = true; Render() end)
	track:SetScript("OnLeave", function() hover = false; Render() end)

	local function Snap()
		container:SetScript("OnUpdate", nil)
		progressRef.progress = state.enabled and 1 or 0
		Render()
	end

	AttachStandardToggle(container, state, progressRef, Render, Snap, track, callback, tooltip, labelFontString)
	return Widget.Wrap(container)
end

function Controls.IconToggle(parent, checked, callback, options)
	options = options or {}
	local size = options.size or 20
	local button = CreateFrame("Button", nil, Widget.Unwrap(parent))
	button:SetSize(size, size)
	button:RegisterForClicks("AnyUp")
	local state = checked and true or false
	local disabled = false

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(options.texture or BUILib.GetLibMedia("mover"))

	local function Render()
		if disabled then
			icon:SetVertexColor(0.3, 0.3, 0.32, 0.45)
		elseif state then
			local red, green, blue = Theme.GetAccent()
			icon:SetVertexColor(red, green, blue, 1)
		else
			icon:SetVertexColor(0.45, 0.45, 0.48, 0.7)
		end
	end

	button:SetScript("OnClick", function()
		if disabled then return end
		state = not state
		Render()
		if callback then callback(state) end
	end)
	button:SetScript("OnEnter", function(self)
		if disabled then
			if options.disabledTooltip and Widget.ShowTip then Widget.ShowTip(self, options.disabledTooltip) end
			return
		end
		if not state then icon:SetVertexColor(0.7, 0.7, 0.72, 1) end
		if options.tooltip and Widget.ShowTip then Widget.ShowTip(self, options.tooltip) end
	end)
	button:SetScript("OnLeave", function()
		Render()
		if (options.tooltip or options.disabledTooltip) and Widget.HideTip then Widget.HideTip() end
	end)
	Theme.RegisterAccentElement(button, function() Render() end)
	Render()

	function button:GetValue() return state end
	function button:SetValue(value) state = value and true or false; Render() end
	function button:SetEnabled(isEnabled) disabled = not isEnabled; Render() end
	function button:IsEnabled() return not disabled end
	return Widget.Wrap(button)
end

local SWITCH_OFF_TRACK = {0.22, 0.23, 0.26, 1}
local SWITCH_DURATION = 0.18
local EASE_OVERSHOOT, EASE_OVERSHOOT_PLUS_ONE = 1.70158, 2.70158
local function EaseOutBack(progress)
	local shifted = progress - 1
	return 1 + EASE_OVERSHOOT_PLUS_ONE * shifted * shifted * shifted + EASE_OVERSHOOT * shifted * shifted
end

function Controls.SwitchToggle(parent, label, checked, callback, indentLevel, enabled, tooltip, width, height)
	local indentPixels = (indentLevel or 0) * 20
	if enabled == nil then enabled = true end
	local state = {enabled = checked or false, disabled = not enabled}

	local trackWidth = width or 48
	local trackHeight = height or 24
	local knobSize = trackHeight - 6
	local travelDistance = trackWidth - knobSize - 6

	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	container._noGridStretch = true
	container:SetSize(ResolveContainerWidth(nil, label, indentPixels, trackWidth), trackHeight)

	local track = CreateFrame("Button", nil, container)
	track:SetSize(trackWidth, trackHeight)
	track:SetPoint("LEFT", indentPixels, 0)

	local glowTexture = track:CreateTexture(nil, "ARTWORK", nil, -1)
	glowTexture:SetTexture(BUILib.GetLibMedia("pillglow"))
	glowTexture:SetSize(trackWidth * 2, trackHeight * 2)
	glowTexture:SetPoint("CENTER")
	glowTexture:SetVertexColor(1, 1, 1, 0)
	local trackTexture = track:CreateTexture(nil, "ARTWORK")
	trackTexture:SetAllPoints()
	trackTexture:SetTexture(BUILib.GetLibMedia("pill"))
	trackTexture:SetVertexColor(unpack(SWITCH_OFF_TRACK))

	local knob = CreateFrame("Frame", nil, track)
	knob:SetSize(knobSize, knobSize)
	knob:SetFrameLevel(track:GetFrameLevel() + 2)
	local shadowTexture = knob:CreateTexture(nil, "ARTWORK", nil, 1)
	shadowTexture:SetTexture(BUILib.GetLibMedia("knobshadow"))
	shadowTexture:SetSize(knobSize + 8, knobSize + 8)
	shadowTexture:SetPoint("CENTER", 0, -1)
	shadowTexture:SetVertexColor(0, 0, 0, 0.45)
	local knobTexture = knob:CreateTexture(nil, "ARTWORK", nil, 2)
	knobTexture:SetTexture(BUILib.GetLibMedia("knob"))
	knobTexture:SetAllPoints()
	for _, switchTexture in ipairs({trackTexture, shadowTexture, knobTexture}) do
		if switchTexture.SetSnapToPixelGrid then
			switchTexture:SetSnapToPixelGrid(false)
			switchTexture:SetTexelSnappingBias(0)
		end
	end

	local labelFontString = Widget.ToggleLabel(container, track, label, 8)

	local progressRef = { progress = state.enabled and 1 or 0 }

	local function Render()
		local clampedProgress = progressRef.progress
		if clampedProgress < 0 then clampedProgress = 0 elseif clampedProgress > 1 then clampedProgress = 1 end
		local stretch = 4 * clampedProgress * (1 - clampedProgress)
		knob:SetSize(knobSize * (1 + 0.15 * stretch), knobSize * (1 - 0.05 * stretch))
		knob:ClearAllPoints()
		knob:SetPoint("LEFT", track, "LEFT", 3 + travelDistance * progressRef.progress, 0)
		local red, green, blue = Theme.GetAccent()
		trackTexture:SetVertexColor(
			Lerp(SWITCH_OFF_TRACK[1], red, clampedProgress),
			Lerp(SWITCH_OFF_TRACK[2], green, clampedProgress),
			Lerp(SWITCH_OFF_TRACK[3], blue, clampedProgress), 1)
		glowTexture:SetVertexColor(red, green, blue, 0.20 * clampedProgress)
		container:SetAlpha(state.disabled and 0.45 or 1)
		if labelFontString then labelFontString:SetTextColor(unpack(state.disabled and Theme.text.disabled or Theme.text.primary)) end
	end

	local function Snap()
		container:SetScript("OnUpdate", nil)
		progressRef.progress = state.enabled and 1 or 0
		Render()
	end

	Widget.AttachToggle(container, state, progressRef, Render, Snap, track, callback, tooltip, labelFontString, SWITCH_DURATION, EaseOutBack)
	return Widget.Wrap(container)
end
