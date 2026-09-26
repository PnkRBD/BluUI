local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Widget = {}
BUILib.Widget = Widget

local Theme
local function getTheme() if not Theme then Theme = BUILib.Theme end return Theme end

local WidgetMethods = {}

local BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	edgeSize = 1,
	insets = {left = 1, right = 1, top = 1, bottom = 1},
}
local BACKDROP_BORDERLESS = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	insets = {left = 0, right = 0, top = 0, bottom = 0},
}
local WHITE = "Interface\\Buttons\\WHITE8x8"

Widget.BACKDROP = BACKDROP
Widget.BACKDROP_BORDERLESS = BACKDROP_BORDERLESS
Widget.WHITE = WHITE
Widget.ICON_ZOOM = 0.08

local function widgetIndex(self, key)
	local method = WidgetMethods[key]
	if method ~= nil then return method end
	local frame = rawget(self, "frame")
	if not frame then return nil end
	local value = frame[key]
	if value == nil then return nil end
	if type(value) == "function" then
		local wrapper = function(_, ...) return value(frame, ...) end
		rawset(self, key, wrapper)
		return wrapper
	end
	return value
end

local WidgetMetatable = {__index = widgetIndex}

function Widget.New(parent, frameType, template, config)
	config = config or {}
	local parentFrame = type(parent) == "table" and parent.frame or parent
	local frame = CreateFrame(frameType or "Frame", nil, parentFrame, template or "BackdropTemplate")
	if parentFrame == UIParent then frame.isBluUIWindow = true end
	local self = setmetatable({}, WidgetMetatable)
	self.frame = frame
	self._enabled = true
	frame._w = self
	if not config.raw then
		frame:SetBackdrop(config.borderless and BACKDROP_BORDERLESS or BACKDROP)
		local theme = getTheme()
		local backgroundColor = config.bg or theme.bg.dark
		local border = config.border or theme.border.dark
		frame:SetBackdropColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4] or 1)
		frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
	end
	if config.size then frame:SetSize(config.size[1], config.size[2])
	else
		if config.width then frame:SetWidth(config.width) end
		if config.height then frame:SetHeight(config.height) end
	end
	return self
end

function Widget.EvenSize(size)
	return math.ceil(size / 2) * 2
end

function Widget.StripColorCodes(text)
	if type(text) ~= "string" then return tostring(text or "") end
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function Widget.Wrap(frame)
	local self = setmetatable({}, WidgetMetatable)
	self.frame = frame
	self._enabled = true
	frame._w = self
	return self
end

function Widget.Unwrap(widgetOrFrame) return type(widgetOrFrame) == "table" and widgetOrFrame.frame or widgetOrFrame end

local HOVER_FADE_SPEED = 5

function Widget.HoverFade(frame, host)
	host = Widget.Unwrap(host)
	frame:SetAlpha(0)
	frame._fadeCurrent, frame._fadeTarget = 0, 0
	local function Tick(self, deltaTime)
		local currentAlpha, targetAlpha = self._fadeCurrent, self._fadeTarget
		if currentAlpha < targetAlpha then currentAlpha = math.min(targetAlpha, currentAlpha + HOVER_FADE_SPEED * deltaTime)
		elseif currentAlpha > targetAlpha then currentAlpha = math.max(targetAlpha, currentAlpha - HOVER_FADE_SPEED * deltaTime) end
		self._fadeCurrent = currentAlpha
		self:SetAlpha(currentAlpha)
		if currentAlpha == targetAlpha then self:SetScript("OnUpdate", nil) end
	end
	local function UpdateTarget()
		if frame:IsMouseOver() then frame._fadeTarget = 1.0
		elseif host:IsMouseOver() then frame._fadeTarget = 0.5
		else frame._fadeTarget = 0.0 end
		if frame._fadeCurrent ~= frame._fadeTarget then frame:SetScript("OnUpdate", Tick) end
	end
	host:EnableMouse(true)
	host:HookScript("OnEnter", UpdateTarget)
	host:HookScript("OnLeave", UpdateTarget)
	frame:HookScript("OnEnter", UpdateTarget)
	frame:HookScript("OnLeave", UpdateTarget)
end

local MENU_ANIM_DURATION = 0.12
function Widget.ShowMenuAnimated(menu)
	menu:SetAlpha(0)
	menu:Show()
	local start = GetTime()
	menu:SetScript("OnUpdate", function(self)
		local progress = (GetTime() - start) / MENU_ANIM_DURATION
		if progress >= 1 then
			self:SetAlpha(1)
			self:SetScript("OnUpdate", nil)
		else
			local eased = 1 - (1 - progress) * (1 - progress)
			self:SetAlpha(eased)
		end
	end)
end

function Widget.HideMenuAnimated(menu)
	if not menu:IsShown() then return end
	local startAlpha = menu:GetAlpha()
	local start = GetTime()
	menu:SetScript("OnUpdate", function(self)
		local progress = (GetTime() - start) / MENU_ANIM_DURATION
		if progress >= 1 then
			self:SetScript("OnUpdate", nil); self:Hide()
		else
			local eased = 1 - (1 - progress) * (1 - progress)
			self:SetAlpha(startAlpha * (1 - eased))
		end
	end)
end

function Widget.SafeGetHeight(frame) return frame and frame:GetHeight() or 0 end

local WHITE_TEX = "Interface\\Buttons\\WHITE8x8"
Widget.WHITE = WHITE_TEX

local RING_MIN, RING_MAX = 4, 14

local function PrepShapeTexture(texture)
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(false)
		texture:SetTexelSnappingBias(0)
	end
end

local RING_TEX_SIZE = 48

function Widget.DrawRoundedRect(frame, radius, color, drawLayer, subLayer, inset, ringOnly)
	inset = inset or 0
	local ringRadius = math.floor(radius + 0.5)
	if ringRadius < RING_MIN then ringRadius = RING_MIN elseif ringRadius > RING_MAX then ringRadius = RING_MAX end
	local colorRed, colorGreen, colorBlue, colorAlpha = color[1], color[2], color[3], color[4] or 1
	local ringPath = BUILib.GetLibMedia("ring" .. ringRadius)
	local cornerSize = ringRadius + 2
	local textureSize = RING_TEX_SIZE
	local cornerCoordMin, cornerCoordMax = 1 / textureSize, (1 + cornerSize) / textureSize
	local edgeCoordMin, edgeCoordMax = 1 / textureSize, (1 + ringRadius) / textureSize
	local spanMin, spanMax = cornerSize / textureSize, 1 - cornerSize / textureSize
	local textures = {}

	local function piece(texturePath, x1, x2, y1, y2)
		local texture = frame:CreateTexture(nil, drawLayer, nil, subLayer)
		texture:SetTexture(texturePath)
		if x1 then texture:SetTexCoord(x1, x2, y1, y2) end
		texture:SetVertexColor(colorRed, colorGreen, colorBlue, colorAlpha)
		PrepShapeTexture(texture)
		textures[#textures + 1] = texture
		return texture
	end

	local topLeft = piece(ringPath, cornerCoordMin, cornerCoordMax, cornerCoordMin, cornerCoordMax)
	topLeft:SetSize(cornerSize, cornerSize)
	topLeft:SetPoint("TOPLEFT", inset, -inset)

	local topRight = piece(ringPath, 1 - cornerCoordMax, 1 - cornerCoordMin, cornerCoordMin, cornerCoordMax)
	topRight:SetSize(cornerSize, cornerSize)
	topRight:SetPoint("TOPRIGHT", -inset, -inset)

	local bottomLeft = piece(ringPath, cornerCoordMin, cornerCoordMax, 1 - cornerCoordMax, 1 - cornerCoordMin)
	bottomLeft:SetSize(cornerSize, cornerSize)
	bottomLeft:SetPoint("BOTTOMLEFT", inset, inset)

	local bottomRight = piece(ringPath, 1 - cornerCoordMax, 1 - cornerCoordMin, 1 - cornerCoordMax, 1 - cornerCoordMin)
	bottomRight:SetSize(cornerSize, cornerSize)
	bottomRight:SetPoint("BOTTOMRIGHT", -inset, inset)

	local top = piece(ringPath, spanMin, spanMax, edgeCoordMin, edgeCoordMax)
	top:SetHeight(ringRadius)
	top:SetPoint("TOPLEFT", inset + cornerSize, -inset)
	top:SetPoint("TOPRIGHT", -(inset + cornerSize), -inset)

	local bottom = piece(ringPath, spanMin, spanMax, 1 - edgeCoordMax, 1 - edgeCoordMin)
	bottom:SetHeight(ringRadius)
	bottom:SetPoint("BOTTOMLEFT", inset + cornerSize, inset)
	bottom:SetPoint("BOTTOMRIGHT", -(inset + cornerSize), inset)

	local left = piece(ringPath, edgeCoordMin, edgeCoordMax, spanMin, spanMax)
	left:SetWidth(ringRadius)
	left:SetPoint("TOPLEFT", inset, -(inset + cornerSize))
	left:SetPoint("BOTTOMLEFT", inset, inset + cornerSize)

	local right = piece(ringPath, 1 - edgeCoordMax, 1 - edgeCoordMin, spanMin, spanMax)
	right:SetWidth(ringRadius)
	right:SetPoint("TOPRIGHT", -inset, -(inset + cornerSize))
	right:SetPoint("BOTTOMRIGHT", -inset, inset + cornerSize)

	if ringOnly then
		textures.ringOnly = true
		return textures
	end

	local center = piece(WHITE_TEX)
	center:SetPoint("TOPLEFT", inset + ringRadius, -(inset + ringRadius))
	center:SetPoint("BOTTOMRIGHT", -(inset + ringRadius), inset + ringRadius)

	return textures
end

local function ApplySlicedShape(texture, texturePath, radius, color, inset)
	texture:SetTexture(texturePath)
	local margin = radius + 2
	texture:SetTextureSliceMargins(margin, margin, margin, margin)
	if texture.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
		texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
	end
	texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	PrepShapeTexture(texture)
	texture:SetPoint("TOPLEFT", inset, -inset)
	texture:SetPoint("BOTTOMRIGHT", -inset, inset)
end

function Widget.DrawCardShape(frame, radius, fillColor, borderColor, drawLayer, subLayer, inset)
	inset = inset or 0
	subLayer = subLayer or 0
	local shapeRadius = math.floor(radius + 0.5)
	if shapeRadius < RING_MIN then shapeRadius = RING_MIN elseif shapeRadius > RING_MAX then shapeRadius = RING_MAX end

	local fill = frame:CreateTexture(nil, drawLayer, nil, subLayer)

	ApplySlicedShape(fill, BUILib.GetLibMedia("round" .. shapeRadius), shapeRadius, fillColor, inset)
	local border = frame:CreateTexture(nil, drawLayer, nil, subLayer + 1)
	ApplySlicedShape(border, BUILib.GetLibMedia("outline" .. shapeRadius), shapeRadius, borderColor, inset)
	return fill, border
end

function Widget.DrawOutline(frame, radius, color, drawLayer, subLayer, inset)
	drawLayer = drawLayer or "BACKGROUND"
	subLayer = subLayer or 0
	inset = inset or 0
	local shapeRadius = math.floor(radius + 0.5)
	if shapeRadius < RING_MIN then shapeRadius = RING_MIN elseif shapeRadius > RING_MAX then shapeRadius = RING_MAX end

	local outline = frame:CreateTexture(nil, drawLayer, nil, subLayer)

	ApplySlicedShape(outline, BUILib.GetLibMedia("outline" .. shapeRadius), shapeRadius, color, inset)
	return outline
end

function Widget.DrawCapsule(frame, color, drawLayer, subLayer, inset)
	inset = inset or 0
	local capWidth = (frame:GetHeight() - inset * 2) / 2
	local texturePath = BUILib.GetLibMedia("capsule")
	local colorRed, colorGreen, colorBlue, colorAlpha = color[1], color[2], color[3], color[4] or 1

	local left = frame:CreateTexture(nil, drawLayer, nil, subLayer)
	left:SetTexture(texturePath)
	left:SetTexCoord(0, 0.25, 0, 1)
	left:SetPoint("TOPLEFT", inset, -inset)
	left:SetPoint("BOTTOMLEFT", inset, inset)
	left:SetWidth(capWidth)

	local right = frame:CreateTexture(nil, drawLayer, nil, subLayer)
	right:SetTexture(texturePath)
	right:SetTexCoord(0.75, 1, 0, 1)
	right:SetPoint("TOPRIGHT", -inset, -inset)
	right:SetPoint("BOTTOMRIGHT", -inset, inset)
	right:SetWidth(capWidth)

	local center = frame:CreateTexture(nil, drawLayer, nil, subLayer)
	center:SetTexture(texturePath)
	center:SetTexCoord(0.25, 0.75, 0, 1)
	center:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
	center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

	local textures = {left, center, right}
	for _, texture in ipairs(textures) do
		texture:SetVertexColor(colorRed, colorGreen, colorBlue, colorAlpha)
		PrepShapeTexture(texture)
	end
	return textures
end

function Widget.SetRectColor(textures, red, green, blue, alpha)
	alpha = alpha or 1
	for _, texture in ipairs(textures) do
		texture:SetVertexColor(red, green, blue, alpha)
	end
end

Widget.INPUT_RADIUS = 5
Widget.PANEL_RADIUS = 6
Widget.PANEL_INSET = 4

function Widget.SetShapeColor(shape, red, green, blue, alpha)
	if not shape then return end
	if shape.SetVertexColor then
		shape:SetVertexColor(red, green, blue, alpha or 1)
	else
		Widget.SetRectColor(shape, red, green, blue, alpha)
	end
end

function Widget.RoundedShape(frame, radius, fillColor, borderColor, drawLayer, subLayer, inset)
	return Widget.DrawCardShape(frame, radius, fillColor, borderColor, drawLayer or "BACKGROUND", subLayer or 0, inset or 0)
end

function Widget.RoundedPanel(frame, radius, fillColor, borderColor)
	local theme = getTheme()
	radius = radius or Widget.PANEL_RADIUS
	fillColor = fillColor or theme.bg.dark
	borderColor = borderColor or theme.border.light

	local fillShape, borderShape = Widget.RoundedShape(frame, radius, fillColor, borderColor, "BACKGROUND", 0, 0)
	return borderShape, fillShape
end

function Widget.RoundedInput(frame, radius, fillColor, borderColor)
	local theme = getTheme()
	radius = radius or Widget.INPUT_RADIUS
	fillColor = fillColor or theme.bg.input
	borderColor = borderColor or theme.border.input

	local fillShape, borderShape = Widget.RoundedShape(frame, radius, fillColor, borderColor, "BACKGROUND", 0, 0)

	local function SetHighlighted(highlighted)
		if highlighted then
			local red, green, blue = theme.GetAccent()
			Widget.SetShapeColor(borderShape, red, green, blue, 1)
		else
			Widget.SetShapeColor(borderShape, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
		end
	end

	return SetHighlighted, borderShape, fillShape
end

function Widget.SetRectRing(textures, red, green, blue, alpha)
	alpha = alpha or 1
	local lastRingPiece = textures.ringOnly and #textures or #textures - 1
	for textureIndex = 1, lastRingPiece do
		textures[textureIndex]:SetVertexColor(red, green, blue, alpha)
	end
end

function WidgetMethods:SetPoint(point, relativeTo, ...)
	if type(relativeTo) == "table" and relativeTo.frame then relativeTo = relativeTo.frame end
	self.frame:SetPoint(point, relativeTo, ...)
end

function WidgetMethods:SetParent(parent) self.frame:SetParent(type(parent) == "table" and parent.frame or parent) end

function WidgetMethods:SetEnabled(enabled)
	self._enabled = enabled
	if self.OnEnable then self:OnEnable(enabled) end
end
function WidgetMethods:IsEnabled() return self._enabled end

function WidgetMethods:SetTooltip(text, anchor)
	if not text or text == "" then return self end
	local tipAnchor = anchor == "ANCHOR_LEFT" and "LEFT" or anchor == "ANCHOR_BOTTOM" and "BOTTOM" or anchor == "ANCHOR_RIGHT" and "RIGHT" or nil
	local frame = self.frame
	frame:HookScript("OnEnter", function(hoveredFrame) Widget.ShowTip(hoveredFrame, text, {anchor = tipAnchor}) end)
	frame:HookScript("OnLeave", function() Widget.HideTip() end)
	return self
end

function WidgetMethods:SetHover(normalBg, hoverBg)
	self._normalBg = normalBg
	self._hoverBg = hoverBg
	local frame = self.frame
	local watcher
	local function ClearHover()
		if watcher then watcher:SetScript("OnUpdate", nil) end
		frame:SetBackdropColor(unpack(normalBg))
		if self.accentLine then self.accentLine:SetAlpha(0) end
	end
	self.ClearHover = ClearHover
	frame:HookScript("OnEnter", function(hoveredFrame)
		hoveredFrame:SetBackdropColor(unpack(hoverBg))
		if self.accentLine then self.accentLine:SetAlpha(1) end
		watcher = watcher or CreateFrame("Frame", nil, hoveredFrame)
		watcher:SetScript("OnUpdate", function()
			if not frame:IsMouseOver() then ClearHover() end
		end)
	end)
	frame:HookScript("OnLeave", ClearHover)
	frame:HookScript("OnHide", ClearHover)
	return self
end

function WidgetMethods:RegisterAccent(updateFn)
	getTheme().RegisterAccentElement(self.frame, updateFn)
	return self
end

function WidgetMethods:CreateText(config)
	config = config or {}
	local theme = getTheme()
	local fontString = self.frame:CreateFontString(nil, config.layer or "OVERLAY")
	fontString:SetFont(config.font or BUILib.GetFont(), config.size or theme.fontSize, config.outline or "")
	fontString:SetShadowOffset(0, 0)
	fontString:SetTextColor(unpack(config.color or theme.text.primary))
	if config.text then fontString:SetText(config.text) end
	if config.wrap then fontString:SetWordWrap(true) end
	if config.justify then fontString:SetJustifyH(config.justify) end
	return fontString
end

function WidgetMethods:CreateFill(layer, red, green, blue, alpha)
	local texture = self.frame:CreateTexture(nil, layer or "ARTWORK")
	texture:SetTexture(WHITE)
	if red then texture:SetVertexColor(red, green or 0, blue or 0, alpha or 1) end
	return texture
end

function WidgetMethods:SetupHoverBorder(editBox, normalBorder)
	local theme = getTheme()
	normalBorder = normalBorder or theme.border.input
	local frame = self.frame
	local function SetHovered(hovered)
		if hovered then
			local red, green, blue = theme.GetAccent()
			frame:SetBackdropBorderColor(red, green, blue, 1)
		else
			frame:SetBackdropBorderColor(unpack(normalBorder))
		end
	end
	frame:SetScript("OnEnter", function() SetHovered(true) end)
	frame:SetScript("OnLeave", function()
		if editBox and editBox.HasFocus and editBox:HasFocus() then return end
		SetHovered(false)
	end)
	if editBox then
		editBox:SetScript("OnEnter", function() SetHovered(true) end)
		editBox:SetScript("OnLeave", function()
			if not editBox:HasFocus() then SetHovered(false) end
		end)
		editBox:SetScript("OnEditFocusGained", function() SetHovered(true) end)
		editBox:SetScript("OnEditFocusLost", function() SetHovered(false) end)
	end
	return SetHovered
end

function Widget.Icon(parent, texture, size, zoom, bordered)
	size = size or 24
	zoom = zoom or Widget.ICON_ZOOM
	if bordered then
		local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
		container:SetSize(size + 2, size + 2)
		container:SetBackdrop(BACKDROP)
		container:SetBackdropColor(0, 0, 0, 1)
		container:SetBackdropBorderColor(0, 0, 0, 1)
		local icon = container:CreateTexture(nil, "ARTWORK")
		icon:SetSize(size, size)
		icon:SetPoint("CENTER")
		icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
		icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
		container.icon = icon
		function container:SetTexture(texturePath) icon:SetTexture(texturePath) end
		function container:SetVertexColor(red, green, blue, alpha) icon:SetVertexColor(red, green, blue, alpha) end
		function container:SetDesaturated(desaturated) icon:SetDesaturated(desaturated) end
		return container
	else
		local icon = parent:CreateTexture(nil, "ARTWORK")
		icon:SetSize(size, size)
		icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
		icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
		return icon
	end
end

do
	local tip
	local MAX_WIDTH, PADDING_X, PADDING_Y = 260, 10, 8

	local function AcquireTip()
		if tip then return tip end
		tip = CreateFrame("Frame", nil, UIParent)
		tip:SetFrameStrata("TOOLTIP")
		tip:SetClampedToScreen(true)
		tip:SetSize(MAX_WIDTH, 30)

		local background = tip:CreateTexture(nil, "BACKGROUND", nil, -8)
		background:SetAllPoints()
		background:SetColorTexture(unpack(getTheme().bg.dark))

		for _, info in ipairs({
			{"TOPLEFT", "TOPRIGHT", true},
			{"BOTTOMLEFT", "BOTTOMRIGHT", true},
			{"TOPLEFT", "BOTTOMLEFT", false},
			{"TOPRIGHT", "BOTTOMRIGHT", false},
		}) do
			local edge = tip:CreateTexture(nil, "BORDER")
			edge:SetColorTexture(unpack(getTheme().border.light))
			edge:SetPoint(info[1]); edge:SetPoint(info[2])
			if info[3] then edge:SetHeight(1) else edge:SetWidth(1) end
		end

		tip.label = tip:CreateFontString(nil, "OVERLAY")
		tip.label:SetFont(BUILib.Font, 11, "")
		tip.label:SetTextColor(1, 1, 1, 0.9)
		tip.label:SetPoint("TOPLEFT", PADDING_X, -PADDING_Y)
		tip.label:SetPoint("TOPRIGHT", -PADDING_X, -PADDING_Y)
		tip.label:SetWordWrap(true)
		tip.label:SetSpacing(2)

		tip._fadeIn = tip:CreateAnimationGroup()
		local fadeInAnim = tip._fadeIn:CreateAnimation("Alpha")
		fadeInAnim:SetFromAlpha(0); fadeInAnim:SetToAlpha(1); fadeInAnim:SetDuration(0.12); fadeInAnim:SetSmoothing("OUT")
		tip._fadeIn:SetScript("OnFinished", function() tip:SetAlpha(1) end)

		tip._fadeOut = tip:CreateAnimationGroup()
		local fadeOutAnim = tip._fadeOut:CreateAnimation("Alpha")
		fadeOutAnim:SetFromAlpha(1); fadeOutAnim:SetToAlpha(0); fadeOutAnim:SetDuration(0.1); fadeOutAnim:SetSmoothing("IN")
		tip._fadeOut:SetScript("OnFinished", function() tip:SetAlpha(0); tip:Hide() end)
		tip:Hide()
		return tip
	end

	local function PositionTip(tooltip, owner, config)
		tooltip:ClearAllPoints()
		local anchor = config and config.anchor
		if anchor == "RIGHT" then
			tooltip:SetPoint("LEFT", owner, "RIGHT", 6, 0)
		elseif anchor == "LEFT" then
			tooltip:SetPoint("RIGHT", owner, "LEFT", -6, 0)
		elseif anchor == "BOTTOM" then
			tooltip:SetPoint("TOP", owner, "BOTTOM", 0, -6)
		else
			tooltip:SetPoint("BOTTOM", owner, "TOP", 0, 6)
		end
		tooltip:Raise()
		tooltip._fadeIn:Stop(); tooltip._fadeIn:Play()
	end

	local rowPool = {}

	local function ResetRowsMode(tooltip)
		if tooltip.title then
			tooltip.title:Hide()
			tooltip.titleLine:Hide()
		end
		for rowIndex = 1, #rowPool do
			rowPool[rowIndex].left:Hide()
			rowPool[rowIndex].right:Hide()
		end
	end

	function Widget.ShowTip(owner, text, config)
		if not text or text == "" then return end
		local tooltip = AcquireTip()
		tooltip._fadeOut:Stop()
		ResetRowsMode(tooltip)
		tooltip.label:SetText(text)
		if config and config.color then
			tooltip.label:SetTextColor(config.color[1], config.color[2], config.color[3], 0.9)
		else
			tooltip.label:SetTextColor(1, 1, 1, 0.9)
		end

		tooltip:SetAlpha(0); tooltip:Show()
		local naturalWidth = math.min(tooltip.label:GetStringWidth() + PADDING_X * 2, MAX_WIDTH)
		tooltip:SetWidth(naturalWidth)
		tooltip:SetHeight(tooltip.label:GetStringHeight() + PADDING_Y * 2)
		PositionTip(tooltip, owner, config)
	end

	local ROW_HEIGHT, ROW_GAP, COLUMN_GAP, ROWS_MIN_WIDTH, TITLE_BLOCK = 16, 6, 24, 140, 24
	local ROWS_LABEL_COLOR = {0.55, 0.55, 0.6}
	local ROWS_VALUE_COLOR = {0.9, 0.9, 0.92}

	local function AcquireRow(tooltip, rowIndex)
		local row = rowPool[rowIndex]
		if not row then
			row = {}
			row.left = tooltip:CreateFontString(nil, "OVERLAY")
			row.left:SetFont(BUILib.Font, 11, "")
			row.left:SetJustifyH("LEFT")
			row.right = tooltip:CreateFontString(nil, "OVERLAY")
			row.right:SetFont(BUILib.Font, 11, "")
			row.right:SetJustifyH("RIGHT")
			rowPool[rowIndex] = row
		end
		return row
	end

	function Widget.ShowTipRows(owner, title, rows, config)
		local tooltip = AcquireTip()
		tooltip._fadeOut:Stop()
		tooltip.label:SetText("")
		if not tooltip.title then
			tooltip.title = tooltip:CreateFontString(nil, "OVERLAY")
			tooltip.title:SetFont(BUILib.Font, 12, "")
			tooltip.title:SetTextColor(0.95, 0.95, 1)
			tooltip.title:SetPoint("TOPLEFT", PADDING_X, -PADDING_Y)
			tooltip.titleLine = tooltip:CreateTexture(nil, "BORDER")
			tooltip.titleLine:SetColorTexture(1, 1, 1, 0.1)
			tooltip.titleLine:SetHeight(1)
			tooltip.titleLine:SetPoint("TOPLEFT", PADDING_X, -(PADDING_Y + TITLE_BLOCK - 6))
			tooltip.titleLine:SetPoint("TOPRIGHT", -PADDING_X, -(PADDING_Y + TITLE_BLOCK - 6))
		end
		tooltip:SetAlpha(0); tooltip:Show()

		local hasTitle = title ~= nil and title ~= ""
		tooltip.title:SetText(hasTitle and title or "")
		tooltip.title:SetShown(hasTitle)
		tooltip.titleLine:SetShown(hasTitle)

		local contentWidth = hasTitle and tooltip.title:GetStringWidth() or 0
		local y = PADDING_Y + (hasTitle and TITLE_BLOCK or 0)
		local shownCount = 0
		for _, spec in ipairs(rows or {}) do
			if spec.space then
				y = y + ROW_GAP
			else
				shownCount = shownCount + 1
				local row = AcquireRow(tooltip, shownCount)
				row.left:ClearAllPoints()
				row.left:SetPoint("TOPLEFT", PADDING_X, -y)
				row.left:SetText(spec.left or "")
				local leftColor = spec.leftColor or ROWS_LABEL_COLOR
				row.left:SetTextColor(leftColor[1], leftColor[2], leftColor[3])
				row.right:ClearAllPoints()
				row.right:SetPoint("TOPRIGHT", -PADDING_X, -y)
				row.right:SetText(spec.right or "")
				local rightColor = spec.rightColor or ROWS_VALUE_COLOR
				row.right:SetTextColor(rightColor[1], rightColor[2], rightColor[3])
				row.left:Show()
				row.right:Show()
				local rowWidth = row.left:GetStringWidth() + COLUMN_GAP + row.right:GetStringWidth()
				if rowWidth > contentWidth then contentWidth = rowWidth end
				y = y + ROW_HEIGHT
			end
		end
		for rowIndex = shownCount + 1, #rowPool do
			rowPool[rowIndex].left:Hide()
			rowPool[rowIndex].right:Hide()
		end

		tooltip:SetWidth(math.max(ROWS_MIN_WIDTH, math.ceil(contentWidth) + PADDING_X * 2))
		tooltip:SetHeight(y + PADDING_Y)
		PositionTip(tooltip, owner, config)
	end

	function Widget.HideTip()
		local tooltip = AcquireTip()
		if not tooltip:IsShown() then return end
		tooltip._fadeIn:Stop()
		tooltip._fadeOut:Stop()
		tooltip._fadeOut:Play()
	end

	function Widget.Tooltip(frame, text, anchor)
		if not text or text == "" then return end
		local tipConfig = anchor and {anchor = anchor} or nil
		frame:HookScript("OnEnter", function(hoveredFrame) Widget.ShowTip(hoveredFrame, text, tipConfig) end)
		frame:HookScript("OnLeave", function() Widget.HideTip() end)
	end
end

function Widget.Create(parent, red, green, blue, alpha)
	local frame = type(parent) == "table" and parent.frame or parent
	local texture = frame:CreateTexture(nil, "ARTWORK")
	texture:SetTexture(WHITE)
	texture:SetVertexColor(red or 1, green or 1, blue or 1, alpha or 1)
	return texture
end

function Widget.SetColor(texture, red, green, blue, alpha) texture:SetVertexColor(red, green, blue, alpha or 1) end

function Widget.CreateAccent(parent, alpha)
	local red, green, blue = getTheme().GetAccent()
	local texture = Widget.Create(parent, red, green, blue, 1)
	if alpha then texture:SetAlpha(alpha) end
	getTheme().RegisterAccentElement(texture, function(element, newRed, newGreen, newBlue)
		element:SetVertexColor(newRed, newGreen, newBlue, 1)
	end)
	return texture
end

function Widget.ScrollLogic(scrollFrame, child, track, thumb, config)
	config = config or {}
	local step = config.step or 40
	local scrollMax = 0
	local shown = false
	local math_max, math_min, math_floor, math_abs, math_exp = math.max, math.min, math.floor, math.abs, math.exp

	local function UpdateThumb()
		local childHeight = child:GetHeight() or 0
		local viewHeight = scrollFrame:GetHeight() or 0
		local range = math_max(0, childHeight - viewHeight)
		scrollMax = range
		local needsScrollbar = range > 1
		if needsScrollbar ~= shown then
			shown = needsScrollbar
			thumb:SetShown(needsScrollbar)
			track:SetShown(needsScrollbar)
			if not needsScrollbar then scrollFrame:SetVerticalScroll(0) end
			if config.onShow then config.onShow(needsScrollbar) end
		end
		if needsScrollbar then
			local trackHeight = track:GetHeight()
			if trackHeight > 0 then
				local thumbHeight = math_max(20, math_min(trackHeight - 4, trackHeight * (viewHeight / childHeight)))
				thumb:SetHeight(thumbHeight)
				local scroll = math_min(scrollFrame:GetVerticalScroll(), range)
				thumb:ClearAllPoints()
				thumb:SetPoint("TOP", track, "TOP", 0, -(scroll / range) * (trackHeight - thumbHeight))
			end
		end
	end

	local targetScroll = nil
	local animator = CreateFrame("Frame")
	animator:Hide()
	animator:SetScript("OnUpdate", function(self, elapsed)
		if not targetScroll then self:Hide(); return end
		local maxScrollNow = math_max(0, (child:GetHeight() or 0) - (scrollFrame:GetHeight() or 0))
		if targetScroll > maxScrollNow then targetScroll = maxScrollNow end
		if targetScroll < 0 then targetScroll = 0 end
		local currentScroll = scrollFrame:GetVerticalScroll()
		local difference = targetScroll - currentScroll
		if math_abs(difference) < 0.5 then
			scrollFrame:SetVerticalScroll(targetScroll)
			targetScroll = nil
			UpdateThumb()
			self:Hide()
			return
		end
		local factor = 1 - math_exp(-elapsed * 16)
		scrollFrame:SetVerticalScroll(currentScroll + difference * factor)
		UpdateThumb()
	end)

	local function StopAnim() targetScroll = nil; animator:Hide() end

	local function DoScroll(delta)
		scrollMax = math_max(0, (child:GetHeight() or 0) - (scrollFrame:GetHeight() or 0))
		if scrollMax <= 0 then return end
		local base = targetScroll or scrollFrame:GetVerticalScroll()
		targetScroll = math_max(0, math_min(scrollMax, base - delta * step))
		animator:Show()
	end

	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScript("OnMouseWheel", function(_, wheelDelta) DoScroll(wheelDelta) end)

	if config.draggable then
		local dragStart, dragScrollStart
		local function OnDragUpdate()
			if not dragStart or scrollMax <= 0 then return end
			local cursorY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
			local travel = track:GetHeight() - thumb:GetHeight()
			if travel <= 0 then return end
			local delta = (dragStart - cursorY) / travel * scrollMax
			scrollFrame:SetVerticalScroll(math_floor(math_max(0, math_min(scrollMax, dragScrollStart + delta)) + 0.5))
			UpdateThumb()
		end
		thumb:SetScript("OnMouseDown", function(_, mouseButton)
			if mouseButton ~= "LeftButton" then return end
			StopAnim()
			UpdateThumb()
			dragStart = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
			dragScrollStart = scrollFrame:GetVerticalScroll()
			thumb:SetScript("OnUpdate", OnDragUpdate)
		end)
		thumb:SetScript("OnMouseUp", function()
			dragStart = nil
			thumb:SetScript("OnUpdate", nil)
		end)

		track:EnableMouse(true)
		track:SetScript("OnMouseDown", function(self, mouseButton)
			if mouseButton ~= "LeftButton" or scrollMax <= 0 then return end
			StopAnim()
			local cursorY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
			local ratio = (self:GetTop() - cursorY) / self:GetHeight()
			scrollFrame:SetVerticalScroll(math_floor(ratio * scrollMax + 0.5))
			UpdateThumb()
		end)
	end

	return {
		UpdateThumb = UpdateThumb,
		DoScroll = DoScroll,
		Stop = StopAnim,
		GetMax = function() return scrollMax end,
	}
end
