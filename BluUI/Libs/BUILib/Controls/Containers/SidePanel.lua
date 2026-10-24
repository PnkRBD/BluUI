local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Widget = BUILib.Widget
local Theme = BUILib.Theme

local DEFAULT_WIDTH = 360
local DEFAULT_INSET = 12

local DEFAULT_TOP_INSET = 60
local DEFAULT_BOTTOM_INSET = 64
local SLIDE_TIME = 0.18

function Controls.SidePanel(parent, options)
	options = options or {}
	local parentFrame = Widget.Unwrap(parent)
	local width = options.width or DEFAULT_WIDTH
	local inset = options.inset or DEFAULT_INSET
	local topInset = options.topInset or DEFAULT_TOP_INSET
	local bottomInset = options.bottomInset or DEFAULT_BOTTOM_INSET

	local panelWidget

	local dimmer = CreateFrame("Frame", nil, parentFrame)
	dimmer:SetAllPoints(parentFrame)
	dimmer:SetFrameStrata(parentFrame:GetFrameStrata())
	dimmer:SetFrameLevel((parentFrame:GetFrameLevel() or 0) + 55)
	dimmer:EnableMouse(true)
	local dimTexture = dimmer:CreateTexture(nil, "BACKGROUND")
	dimTexture:SetAllPoints()
	dimTexture:SetColorTexture(0, 0, 0, 0.55)
	dimmer:SetScript("OnMouseDown", function() if panelWidget then panelWidget:Close() end end)
	dimmer:Hide()

	local host = CreateFrame("Frame", nil, parentFrame)
	host:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -inset, -topInset)
	host:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -inset, bottomInset)
	host:SetWidth(width)
	host:SetFrameStrata(parentFrame:GetFrameStrata())
	host:SetFrameLevel((parentFrame:GetFrameLevel() or 0) + 60)
	if host.SetClipsChildren then host:SetClipsChildren(true) end
	host:Hide()

	local panel = CreateFrame("Frame", nil, host, "BackdropTemplate")
	panel:SetWidth(width)
	panel:SetBackdrop(Widget.BACKDROP)
	panel:SetBackdropColor(Theme.bg.panel[1], Theme.bg.panel[2], Theme.bg.panel[3], Theme.bg.panel[4] or 1)
	panel:SetBackdropBorderColor(Theme.border.default[1], Theme.border.default[2], Theme.border.default[3], 1)
	panel:EnableMouse(true)

	local function place(offsetX)
		panel._x = offsetX
		panel:ClearAllPoints()
		panel:SetPoint("TOPRIGHT", host, "TOPRIGHT", offsetX, 0)
		panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", offsetX, 0)
	end
	place(width)

	local header = CreateFrame("Frame", nil, panel)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(40)

	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")

	header:SetScript("OnDragStart", function(self)
		local window = BUILib.ClientOf(self).popupParent
		if window and window.StartMoving then window:StartMoving() end
	end)
	header:SetScript("OnDragStop", function(self)
		local window = BUILib.ClientOf(self).popupParent
		if window and window.StopMovingOrSizing then window:StopMovingOrSizing() end
	end)
	local headerBackground = header:CreateTexture(nil, "BACKGROUND")
	headerBackground:SetAllPoints()
	headerBackground:SetColorTexture(0, 0, 0, 0.25)

	local accent = header:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("BOTTOMLEFT", 8, 0)
	accent:SetPoint("BOTTOMRIGHT", -8, 0)
	accent:SetHeight(1)
	accent:SetTexture("Interface\\Buttons\\WHITE8x8")
	local accentRed, accentGreen, accentBlue = Theme.GetAccent()
	accent:SetVertexColor(accentRed, accentGreen, accentBlue, 0.6)
	Theme.RegisterAccentElement(accent, function(element, red, green, blue) element:SetVertexColor(red, green, blue, 0.6) end)

	local headerIcon = header:CreateTexture(nil, "ARTWORK")
	headerIcon:SetSize(24, 24)
	headerIcon:SetPoint("LEFT", 10, 0)
	headerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	headerIcon:Hide()

	local title = header:CreateFontString(nil, "OVERLAY")
	title:SetFont(BUILib.Font, 14, "OUTLINE")
	title:SetPoint("LEFT", 12, 0)
	title:SetTextColor(Theme.text.primary[1], Theme.text.primary[2], Theme.text.primary[3], 1)
	title:SetText(options.title or "Panel")

	local subtitle = header:CreateFontString(nil, "OVERLAY")
	subtitle:SetFont(BUILib.Font, 9, "")
	subtitle:SetTextColor(0.6, 0.6, 0.62, 1)
	subtitle:Hide()

	local closeButton = Controls.Icon(header, { preset = "clear", size = 20, idleColor = {0.45, 0.45, 0.48, 0.7},
		onClick = function() if panelWidget then panelWidget:Close() end end })
	closeButton:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -8, 5)

	local content = CreateFrame("Frame", nil, panel)
	content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 7, -4)
	content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 10)

	local from, to, elapsed, hideAtEnd = width, width, 0, false
	local driver = CreateFrame("Frame", nil, host)
	driver:Hide()
	driver:SetScript("OnUpdate", function(self, deltaTime)
		elapsed = elapsed + deltaTime
		local progress = (SLIDE_TIME > 0) and math.min(elapsed / SLIDE_TIME, 1) or 1
		local eased = 1 - (1 - progress) * (1 - progress)
		place(from + (to - from) * eased)
		if progress >= 1 then
			self:Hide()
			if hideAtEnd then
				host:Hide()
				dimmer:Hide()
			end
		end
	end)
	local function slide(target, hideWhenDone)
		from = panel._x or width
		to = target
		elapsed = 0
		hideAtEnd = hideWhenDone
		driver:Show()
	end

	panelWidget = Widget.Wrap(panel)
	panelWidget.content = content
	panelWidget.header = header

	function panelWidget:GetContent() return content end
	function panelWidget:IsOpen() return self._open == true end

	function panelWidget:SetHeader(titleText, subtitleText, iconID)
		title:SetText(titleText or "")
		if iconID then headerIcon:SetTexture(iconID); headerIcon:Show() else headerIcon:Hide() end
		local left = iconID and 42 or 12
		title:ClearAllPoints()
		if subtitleText and subtitleText ~= "" then
			title:SetPoint("TOPLEFT", left, -10)
			subtitle:ClearAllPoints()
			subtitle:SetPoint("TOPLEFT", left, -25)
			subtitle:SetText(subtitleText)
			subtitle:Show()
		else
			title:SetPoint("LEFT", left, 0)
			subtitle:Hide()
		end
	end

	local enableToggle, anchorEye, actionButton, actionIcon, actionIconOptions, actionIconTexture
	function panelWidget:Open()
		if self._open then return end
		self._open = true
		dimmer:Show()
		host:Show()
		slide(0, false)
	end
	function panelWidget:Close()
		if not self._open then return end
		self._open = false
		slide(width, true)
		if options.onClose then options.onClose() end
	end
	function panelWidget:Toggle()
		if self._open then self:Close() else self:Open() end
	end
	function panelWidget:Reset()
		self._open = false
		driver:Hide()
		place(width)
		host:Hide()
		dimmer:Hide()
	end

	return panelWidget
end
