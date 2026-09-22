local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local unpack = unpack

local ROW_HEIGHT = 26
local TRACK_HEIGHT = 4
local TRACK_GAP = 12
local KNOB_SIZE = 14
local VALUE_WIDTH = 64
local FILL_COLOR = {0.92, 0.92, 0.94, 1}

function Controls.RowSlider(parent, minValue, maxValue, value, callback, config)
	config = config or {}
	minValue = minValue or 0
	maxValue = maxValue or 100
	local step = config.step or 1
	local width = config.width or 280
	local valueWidth = config.valueWidth or VALUE_WIDTH
	local FormatValue = config.format or tostring
	local knobColor = config.knobColor or FILL_COLOR
	local fillColor = config.fillColor or FILL_COLOR
	local showValue = config.showValue ~= false

	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame)
	container:SetSize(width, ROW_HEIGHT)
	container._noGridStretch = true

	local valueBox, SetBoxHighlighted
	if showValue then
		valueBox = CreateFrame("EditBox", nil, container)
		valueBox:SetSize(valueWidth, ROW_HEIGHT)
		valueBox:SetPoint("RIGHT")
		valueBox:EnableMouse(true)
		valueBox:SetAutoFocus(false)
		valueBox:SetFont(BUILib.Font, 12, "")
		valueBox:SetTextColor(unpack(Theme.text.primary))
		valueBox:SetJustifyH("CENTER")
		valueBox:SetMaxLetters(12)
		valueBox:SetTextInsets(4, 4, 0, 0)
		SetBoxHighlighted = Widget.RoundedInput(valueBox)
	end

	local track = CreateFrame("Frame", nil, container)
	track:SetHeight(TRACK_HEIGHT)
	track:SetPoint("LEFT", container, "LEFT", 0, 0)
	if valueBox then
		track:SetPoint("RIGHT", valueBox, "LEFT", -TRACK_GAP, 0)
	else
		track:SetPoint("RIGHT", container, "RIGHT", 0, 0)
	end
	track:EnableMouse(true)
	track:SetHitRectInsets(-8, -8, -11, -11)

	local groove = Widget.Create(track, unpack(Theme.control.track))
	groove:SetAllPoints()

	local progress = track:CreateTexture(nil, "ARTWORK")
	progress:SetTexture(Widget.WHITE)
	progress:SetVertexColor(unpack(fillColor))
	progress:SetPoint("TOPLEFT")
	progress:SetPoint("BOTTOMLEFT")

	local knob = track:CreateTexture(nil, "OVERLAY")
	knob:SetTexture(BUILib.GetLibMedia("smoothdisc"))
	knob:SetSize(config.knobSize or KNOB_SIZE, config.knobSize or KNOB_SIZE)
	knob:SetVertexColor(unpack(knobColor))

	local state = {value = value or minValue, locked = config.locked or false}

	local function Render()
		local range = maxValue - minValue
		local percent = range > 0 and (state.value - minValue) / range or 0
		local trackWidth = track:GetWidth()
		if not trackWidth or trackWidth <= 0 then
			trackWidth = width - (valueBox and (valueWidth + TRACK_GAP) or 0)
		end
		progress:SetWidth(math.max(1, percent * trackWidth))
		knob:ClearAllPoints()
		knob:SetPoint("CENTER", track, "LEFT", percent * trackWidth, 0)
		if valueBox and not valueBox:HasFocus() then valueBox:SetText(FormatValue(state.value)) end
	end

	local function SetValue(newValue, silent)
		newValue = math.floor(newValue / step + 0.5) * step
		state.value = math.max(minValue, math.min(maxValue, newValue))
		Render()
		if not silent and callback then callback(state.value) end
	end

	local function ValueFromCursor()
		if state.locked then return end
		local trackLeft, trackWidth = track:GetLeft(), track:GetWidth()
		if not trackLeft or not trackWidth or trackWidth <= 0 then return end
		local cursorX = GetCursorPosition() / UIParent:GetEffectiveScale()
		SetValue(minValue + math.max(0, math.min(1, (cursorX - trackLeft) / trackWidth)) * (maxValue - minValue))
	end

	local function ParseValue(text)
		local numeric = tonumber(text)
		if numeric then return numeric end
		local minutes, seconds = text:match("^%s*(%d+):(%d+)%s*$")
		if minutes then return tonumber(minutes) * 60 + tonumber(seconds) end
		return tonumber(text:match("(-?%d+%.?%d*)") or "")
	end

	local function ApplyLocked()
		if not valueBox then return end
		valueBox:EnableMouse(not state.locked)
		valueBox:EnableKeyboard(not state.locked)
		if state.locked and valueBox:HasFocus() then valueBox:ClearFocus() end
		valueBox:SetTextColor(unpack(state.locked and Theme.text.disabled or Theme.text.primary))
	end

	if valueBox then
		valueBox:SetScript("OnEnterPressed", function(self)
			local parsed = ParseValue(self:GetText() or "")
			self:ClearFocus()
			if parsed then SetValue(parsed) else Render() end
		end)
		valueBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); Render() end)
		valueBox:SetScript("OnEditFocusGained", function(self) SetBoxHighlighted(true); self:HighlightText() end)
		valueBox:SetScript("OnEditFocusLost", function(self)
			self:HighlightText(0, 0)
			SetBoxHighlighted(false)
			Render()
		end)
		valueBox:SetScript("OnEnter", function() SetBoxHighlighted(true) end)
		valueBox:SetScript("OnLeave", function(self) if not self:HasFocus() then SetBoxHighlighted(false) end end)
		ApplyLocked()
	end

	local function OnDragUpdate() ValueFromCursor() end
	local function StopDragging(self) self:SetScript("OnUpdate", nil) end

	track:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" or state.locked then return end
		self:SetScript("OnUpdate", OnDragUpdate)
		ValueFromCursor()
	end)
	track:SetScript("OnMouseUp", StopDragging)
	track:SetScript("OnHide", StopDragging)

	if config.tooltip then Widget.Tooltip(track, config.tooltip) end

	Render()
	BUILib.Defer(Render)

	function container:GetValue() return state.value end
	function container:SetValue(newValue) SetValue(newValue, true) end
	function container:SetLocked(locked) state.locked = locked and true or false; ApplyLocked() end
	container.track = track
	container.valueBox = valueBox

	return Widget.Wrap(container)
end
