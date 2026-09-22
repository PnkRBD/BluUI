local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local FONT_SIZE = BUILib.FONT_SIZE
local GetTime = GetTime
local unpack = unpack

local STROKE = {0.20, 0.22, 0.26, 0.50}
local FILL = {0.045, 0.050, 0.058, 0.96}
local OFF_TRACK = {0.22, 0.23, 0.26, 1}
local HORIZONTAL_PADDING = 20
local VERTICAL_PADDING = 16
local MIN_HEIGHT = 58
local SHEET_HPAD, SHEET_VPAD, SHEET_MIN_HEIGHT = 14, 9, 40
local SHEET_HAIRLINE = {1, 1, 1, 0.06}
local TRACK_WIDTH, TRACK_HEIGHT = 48, 24
local ANIMATION_DURATION = 0.18
local EASE_OVERSHOOT, EASE_OVERSHOOT_PLUS_ONE = 1.70158, 2.70158

local function EaseOutBack(progress)
	local shifted = progress - 1
	return 1 + EASE_OVERSHOOT_PLUS_ONE * shifted * shifted * shifted + EASE_OVERSHOOT * shifted * shifted
end

function Controls.SettingRow(parent, config)
	local width = config.width or 640
	local sheet = BUILib.IsDatasheet()
	local HORIZONTAL_PADDING = sheet and SHEET_HPAD or HORIZONTAL_PADDING
	local VERTICAL_PADDING = sheet and SHEET_VPAD or VERTICAL_PADDING
	local MIN_HEIGHT = sheet and SHEET_MIN_HEIGHT or MIN_HEIGHT
	local controlZoneWidth = config.plain and 0 or (config.controlWidth or 96)
	local iconPadding = config.icon and ((config.iconSize or 30) + 12) or 0
	local textWidth = width - HORIZONTAL_PADDING * 2 - controlZoneWidth - 16 - (config.accessoryWidth or 0) - iconPadding

	local row = CreateFrame("Button", nil, Widget.Unwrap(parent))
	row:SetWidth(width)
	if config.onRightClick then
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end

	local strokeRect, hairline
	if sheet then
		hairline = row:CreateTexture(nil, "BORDER")
		hairline:SetTexture(Widget.WHITE)
		hairline:SetVertexColor(unpack(SHEET_HAIRLINE))
		hairline:SetHeight(1)
		hairline:SetPoint("BOTTOMLEFT", 0, 0)
		hairline:SetPoint("BOTTOMRIGHT", 0, 0)
	else
		strokeRect = Widget.DrawRoundedRect(row, 6, STROKE, "BACKGROUND", 0, 0)
		Widget.DrawRoundedRect(row, 5, FILL, "BACKGROUND", 1, 1)
	end

	if not config.plain and not sheet then
		local divider = row:CreateTexture(nil, "ARTWORK")
		divider:SetTexture(Widget.WHITE)
		divider:SetVertexColor(1, 1, 1, 0.07)
		divider:SetWidth(1)
		divider:SetPoint("TOPRIGHT", -controlZoneWidth, -12)
		divider:SetPoint("BOTTOMRIGHT", -controlZoneWidth, 12)
	end

	local iconTexture
	if config.icon then
		local iconSize = config.iconSize or 30
		iconTexture = row:CreateTexture(nil, "ARTWORK")
		iconTexture:SetSize(iconSize, iconSize)
		iconTexture:SetPoint("LEFT", HORIZONTAL_PADDING, 0)
		iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		iconTexture:SetTexture(config.icon)
		row.iconTex = iconTexture
	end

	local title = row:CreateFontString(nil, "OVERLAY")
	if sheet then title:SetFont(BUILib.GetFont(), FONT_SIZE + 1, "") else title:SetFont(BUILib.GetFont(), FONT_SIZE + 2, "OUTLINE") end
	title:SetJustifyH("LEFT")
	title:SetWidth(textWidth)
	title:SetText(sheet and (config.title or "") or string.upper(config.title or ""))
	title:SetTextColor(unpack(Theme.text.primary))

	local descriptionText
	if config.description then
		descriptionText = Controls.Text(row, config.description, FONT_SIZE + 1, Theme.text.secondary)
		descriptionText:SetJustifyH("LEFT")
		descriptionText:SetWidth(textWidth)
		descriptionText:SetWordWrap(true)
		descriptionText:SetSpacing(3)
	end

	local extraFrame
	if config.extra then
		extraFrame = Widget.Unwrap(config.extra(row))
	end

	local contentHeight = title:GetStringHeight()
	if descriptionText then contentHeight = contentHeight + 6 + descriptionText:GetStringHeight() end
	if extraFrame then contentHeight = contentHeight + 10 + extraFrame:GetHeight() end

	local height = math.max(MIN_HEIGHT, math.floor(contentHeight + VERTICAL_PADDING * 2 + 0.5))
	if height % 2 == 1 then height = height + 1 end
	local controlZoneCenter = math.floor(controlZoneWidth / 2)
	row:SetHeight(height)
	row.layoutHeight = height

	title:SetPoint("TOPLEFT", HORIZONTAL_PADDING + iconPadding, -math.floor((height - contentHeight) / 2))

	function row:SetRowHeight(newHeight)
		row:SetHeight(newHeight)
		row.layoutHeight = newHeight
		title:SetPoint("TOPLEFT", HORIZONTAL_PADDING + iconPadding, -math.floor((newHeight - contentHeight) / 2))
	end
	if descriptionText then descriptionText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6) end
	if extraFrame then
		extraFrame:ClearAllPoints()
		extraFrame:SetPoint("TOPLEFT", descriptionText or title, "BOTTOMLEFT", 0, -10)
	end

	local state = {on = config.checked and true or false, disabled = false}

	if config.control then
		local customControl = Widget.Unwrap(config.control(row))
		customControl:ClearAllPoints()
		customControl:SetPoint("CENTER", row, "RIGHT", -controlZoneCenter, (math.floor((customControl:GetHeight() or 0) + 0.5) % 2) / 2)
	elseif not config.plain then
		local knobSize = TRACK_HEIGHT - 6
		local travelDistance = TRACK_WIDTH - knobSize - 6
		local progress = state.on and 1 or 0

		local track = CreateFrame("Frame", nil, row)
		track:SetSize(TRACK_WIDTH, TRACK_HEIGHT)
		track:SetPoint("CENTER", row, "RIGHT", -controlZoneCenter, 0)
		local glowTexture = track:CreateTexture(nil, "ARTWORK", nil, -1)
		glowTexture:SetTexture(BUILib.GetLibMedia("pillglow"))
		glowTexture:SetSize(TRACK_WIDTH * 2, TRACK_HEIGHT * 2)
		glowTexture:SetPoint("CENTER")
		glowTexture:SetVertexColor(1, 1, 1, 0)
		local trackTexture = track:CreateTexture(nil, "ARTWORK")
		trackTexture:SetAllPoints()
		trackTexture:SetTexture(BUILib.GetLibMedia("pill"))
		trackTexture:SetVertexColor(unpack(OFF_TRACK))

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

		local function RenderSwitch()
			local clampedProgress = progress
			if clampedProgress < 0 then clampedProgress = 0 elseif clampedProgress > 1 then clampedProgress = 1 end
			local stretch = 4 * clampedProgress * (1 - clampedProgress)
			knob:SetSize(knobSize * (1 + 0.15 * stretch), knobSize * (1 - 0.05 * stretch))
			knob:ClearAllPoints()
			knob:SetPoint("LEFT", track, "LEFT", 3 + travelDistance * progress, 0)
			local red, green, blue = Theme.GetAccent()
			trackTexture:SetVertexColor(
				OFF_TRACK[1] + (red - OFF_TRACK[1]) * clampedProgress,
				OFF_TRACK[2] + (green - OFF_TRACK[2]) * clampedProgress,
				OFF_TRACK[3] + (blue - OFF_TRACK[3]) * clampedProgress, 1)
			glowTexture:SetVertexColor(red, green, blue, 0.20 * clampedProgress)
		end
		RenderSwitch()
		Theme.RegisterAccentElement(track, RenderSwitch)

		local function AnimateTo(targetProgress)
			local startProgress = progress
			local startTime = GetTime()
			track:SetScript("OnUpdate", function(self)
				local elapsedFraction = (GetTime() - startTime) / ANIMATION_DURATION
				if elapsedFraction >= 1 then
					progress = targetProgress
					self:SetScript("OnUpdate", nil)
				else
					progress = startProgress + (targetProgress - startProgress) * EaseOutBack(elapsedFraction)
				end
				RenderSwitch()
			end)
		end

		row:SetScript("OnClick", function(_, button)
			if button == "RightButton" then
				if config.onRightClick then config.onRightClick(row) end
				return
			end
			if state.disabled then return end
			state.on = not state.on
			AnimateTo(state.on and 1 or 0)
			if config.callback then config.callback(state.on) end
		end)

		row:SetScript("OnEnter", function()
			if state.disabled then return end
			local red, green, blue = Theme.GetAccent()
			if strokeRect then Widget.SetRectColor(strokeRect, red, green, blue, 0.40) end
			if hairline then hairline:SetVertexColor(red, green, blue, 0.5) end
		end)
		row:SetScript("OnLeave", function()
			if strokeRect then Widget.SetRectColor(strokeRect, unpack(STROKE)) end
			if hairline then hairline:SetVertexColor(unpack(SHEET_HAIRLINE)) end
		end)

		row._RenderSwitch = RenderSwitch
		row._SetProgress = function(newProgress) progress = newProgress end
	end

	if config.onRightClick and (config.plain or config.control) then
		row:SetScript("OnClick", function(_, button)
			if button == "RightButton" then config.onRightClick(row) end
		end)
	end

	if config.accessories then
		local previousAccessory
		for _, accessory in ipairs(config.accessories(row)) do
			local accessoryFrame = Widget.Unwrap(accessory)
			accessoryFrame:ClearAllPoints()
			if previousAccessory then
				accessoryFrame:SetPoint("RIGHT", previousAccessory, "LEFT", -8, 0)
			else
				accessoryFrame:SetPoint("RIGHT", row, "RIGHT", config.plain and -HORIZONTAL_PADDING or -(controlZoneWidth + 16), 0)
			end
			previousAccessory = accessoryFrame
		end
	end

	if config.tooltip then Widget.Tooltip(row, config.tooltip) end

	function row:GetValue() return state.on end
	function row:SetValue(value)
		state.on = value and true or false
		if self._SetProgress then
			self._SetProgress(state.on and 1 or 0)
			self._RenderSwitch()
		end
	end
	function row:SetRowEnabled(isEnabled)
		state.disabled = not isEnabled
		self:SetAlpha(isEnabled and 1 or 0.45)
		if not isEnabled and not self._blocker then
			local blocker = CreateFrame("Frame", nil, self)
			blocker:SetAllPoints()
			blocker:SetFrameLevel(self:GetFrameLevel() + 60)
			blocker:EnableMouse(true)
			self._blocker = blocker
		end
		if self._blocker then self._blocker:SetShown(not isEnabled) end
	end

	row.title = title
	local wrapped = Widget.Wrap(row)
	wrapped.OnEnable = function(_, isEnabled) row:SetRowEnabled(isEnabled) end
	return wrapped
end
