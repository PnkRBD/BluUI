local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget

local ShowMenu = Widget.ShowMenuAnimated
local HideMenu = Widget.HideMenuAnimated
local WHITE    = "Interface\\Buttons\\WHITE8x8"
local PADDING      = 12
local TITLE_HEIGHT  = 22

local activePopover

local function ClosePopover()
	if activePopover and activePopover:IsShown() then HideMenu(activePopover) end
	activePopover = nil
end

local function BuildShadow(frame)
	for layerIndex, alpha in ipairs({ 0.10, 0.06 }) do
		local shadowTexture = frame:CreateTexture(nil, "BACKGROUND", nil, -8 + layerIndex)
		shadowTexture:SetTexture(WHITE); shadowTexture:SetVertexColor(0, 0, 0, alpha)
		local inset = 3 - layerIndex
		shadowTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", -inset, inset)
		shadowTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", inset, -inset)
	end
end

function Controls.Popover(options)
	options = options or {}
	local anchor = options.anchor and Widget.Unwrap(options.anchor) or nil

	if activePopover and activePopover:IsShown() and activePopover._anchor == anchor then
		ClosePopover()
		return nil
	end
	ClosePopover()

	local width      = options.width or 240
	local hasTitle   = options.title and options.title ~= ""
	local contentTop = PADDING + (hasTitle and TITLE_HEIGHT or 0)
	local height     = options.height or 120
	local totalHeight     = contentTop + height + PADDING

	local frameWidget = Widget.New({ frame = UIParent }, "Frame", nil, {
		bg = Theme.bg.dark, border = Theme.border.light, size = { width, totalHeight },
	})
	local frame = frameWidget.frame
	frame:SetFrameStrata(BUILib.GetPopupStrata())
	frame:SetFrameLevel(BUILib.GetPopupLevel() + 50)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()

	BuildShadow(frame)

	if hasTitle then
		local title = frame:CreateFontString(nil, "OVERLAY")
		title:SetFont(BUILib.Font, 12, "")
		title:SetPoint("TOPLEFT", PADDING, -PADDING)
		title:SetText(options.title)
		title:SetTextColor(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3], 1)
	end

	local panel = CreateFrame("Frame", nil, frame)
	panel:SetPoint("TOPLEFT", PADDING, -contentTop)
	panel:SetPoint("TOPRIGHT", -PADDING, -contentTop)
	panel:SetHeight(height)
	panel.width = width - PADDING * 2
	if options.build then options.build(panel) end

	frame:ClearAllPoints()
	if anchor then
		frame:SetPoint(options.point or "TOPRIGHT", anchor, options.relPt or "BOTTOMRIGHT",
			options.offsetX or 0, options.offsetY or -4)
	else
		frame:SetPoint("CENTER")
	end

	local checkFrame = CreateFrame("Frame")
	local armed = not (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
	checkFrame:SetScript("OnUpdate", function(self)
		if not frame:IsShown() then self:SetScript("OnUpdate", nil); return end
		local isMouseDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
		if not armed then
			if not isMouseDown then armed = true end
			return
		end
		if isMouseDown and not frame:IsMouseOver() and not (anchor and anchor:IsMouseOver()) and (BUILib._popupCount or 0) == 0 then
			self:SetScript("OnUpdate", nil)
			ClosePopover()
		end
	end)

	frame._anchor = anchor
	frame:SetScript("OnShow", function(self) self:Raise() end)
	frame:SetScript("OnHide", function(self)
		checkFrame:SetScript("OnUpdate", nil)
		if activePopover == self then activePopover = nil end
		if options.onClose then options.onClose() end
	end)

	activePopover = frame
	ShowMenu(frame)
	return panel
end

function Controls.ClosePopover() ClosePopover() end
