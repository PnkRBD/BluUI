local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE
local TOGGLE_HEIGHT = BUILib.TOGGLE_HEIGHT
local unpack = unpack

local ANIM_DURATION = 0.12
local THUMB_OFF_X, THUMB_ON_X = 2, 20

function Controls.Toggle(parent, label, checked, callback, indentLevel, enabled, tooltip, width, description)
	width = width or 200
	local indentPixels = (indentLevel or 0) * 20
	if enabled == nil then enabled = true end
	local state = {enabled = checked or false, disabled = not enabled}
	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	container:SetSize(width, TOGGLE_HEIGHT)
	local track = CreateFrame("Button", nil, container, "BackdropTemplate")
	track:SetSize(36, TOGGLE_HEIGHT - 4); track:SetPoint("LEFT", indentPixels, 0)
	track:SetBackdrop(Widget.BACKDROP)
	local thumb = track:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(14, 14); thumb:SetTexture(Widget.WHITE)
	local labelFontString = Controls.Text(container, label, FONT_SIZE, Theme.text.primary)
	labelFontString:SetPoint("LEFT", track, "RIGHT", 8, 0)
	local descriptionFontString
	if description then
		descriptionFontString = Controls.Text(container, "(" .. description .. ")", FONT_SIZE, Theme.text.muted)
		descriptionFontString:SetPoint("LEFT", labelFontString, "RIGHT", 5, 0)
	end

	local progress = state.enabled and 1 or 0
	local animationFromProgress, animationToProgress, animationStartTime = progress, progress, 0

	local function Render()
		thumb:ClearAllPoints()
		if state.disabled then
			track:SetBackdropColor(unpack(Theme.control.disabled))
			track:SetBackdropBorderColor(unpack(Theme.border.dark))
			thumb:SetPoint("LEFT", track, "LEFT", state.enabled and THUMB_ON_X or THUMB_OFF_X, 0)
			thumb:SetVertexColor(unpack(Theme.text.disabled))
			labelFontString:SetTextColor(unpack(Theme.text.disabled))
			if descriptionFontString then descriptionFontString:SetTextColor(unpack(Theme.text.disabled)) end
			return
		end

		local red, green, blue = Theme.GetAccent()
		local offBackground, offBorder, offThumb = Theme.control.trackOff, Theme.border.default, Theme.text.muted
		local function Lerp(fromValue, toValue) return fromValue + (toValue - fromValue) * progress end

		track:SetBackdropColor(Lerp(offBackground[1], red * 0.6), Lerp(offBackground[2], green * 0.6), Lerp(offBackground[3], blue * 0.6), 1)
		track:SetBackdropBorderColor(Lerp(offBorder[1], red), Lerp(offBorder[2], green), Lerp(offBorder[3], blue), 1)
		thumb:SetVertexColor(Lerp(offThumb[1], red), Lerp(offThumb[2], green), Lerp(offThumb[3], blue), 1)
		thumb:SetPoint("LEFT", track, "LEFT", THUMB_OFF_X + (THUMB_ON_X - THUMB_OFF_X) * progress, 0)

		labelFontString:SetTextColor(unpack(state.enabled and Theme.text.primary or Theme.text.muted))
		if descriptionFontString then descriptionFontString:SetTextColor(unpack(state.enabled and Theme.text.muted or Theme.text.disabled)) end
	end

	local function StartAnimation()
		animationFromProgress = progress
		animationToProgress = state.enabled and 1 or 0
		animationStartTime = GetTime()
		container:SetScript("OnUpdate", function(self)
			local elapsedFraction = (GetTime() - animationStartTime) / ANIM_DURATION
			if elapsedFraction >= 1 then
				progress = animationToProgress
				self:SetScript("OnUpdate", nil)
			else
				local eased = 1 - (1 - elapsedFraction) * (1 - elapsedFraction)
				progress = animationFromProgress + (animationToProgress - animationFromProgress) * eased
			end
			Render()
		end)
	end

	local function Snap()
		container:SetScript("OnUpdate", nil)
		progress = state.enabled and 1 or 0
		Render()
	end

	track:SetScript("OnClick", function()
		if state.disabled then return end
		state.enabled = not state.enabled
		StartAnimation()
		if callback then callback(state.enabled) end
	end)
	if tooltip then Widget.Tooltip(track, tooltip) end
	Snap()
	Theme.RegisterAccentElement(container, function() Render() end)

	function container:GetValue() return state.enabled end
	function container:SetValue(value) state.enabled = value; Snap() end
	function container:SetEnabled(isEnabled) state.disabled = not isEnabled; Snap() end
	container.toggle = track; container.label = labelFontString; container.description = descriptionFontString
	return Widget.Wrap(container)
end
