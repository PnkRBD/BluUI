local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local Layout = BUILib.Layout

local CORNER_RADIUS = 6

local SHEET = {
	marginWidth = 136,
	rowInset = 14,
	rightPad = 16,
	rowMin = 30,
	topPad = 6,
	bottomPad = 6,
	marginFill = { 1, 1, 1, 0.025 },
	hairline = { 1, 1, 1, 0.06 },
}
BUILib.SHEET = SHEET

local function Fill(parent, color, layer, sublevel)
	local texture = parent:CreateTexture(nil, layer or 'BORDER', nil, sublevel or 0)
	texture:SetTexture(Widget.WHITE)
	texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	return texture
end

local function TitleCase(title)
	if title == title:upper() then return title:sub(1, 1) .. title:sub(2):lower() end
	return title
end

local function AdaptRow(child, width)
	if child.__sheetAdapted then return end
	child.__sheetAdapted = true
	local label = child.label
	if type(label) ~= 'table' or not label.GetStringWidth then return end
	local part = child.toggle or child.swatch
	if not part then
		for _, sub in ipairs({ child:GetChildren() }) do
			if sub:GetObjectType() == 'Button' then part = sub break end
		end
		if part then child:SetHeight(part:GetHeight() or child:GetHeight()) end
	end
	if not part then return end
	child:SetWidth(width)
	part:ClearAllPoints()
	part:SetPoint('RIGHT', child, 'RIGHT', 0, 0)
	label:ClearAllPoints()
	label:SetPoint('LEFT', child, 'LEFT', 0, 0)
end

local function BuildDatasheetCard(cardWidget, card, config, width, title)
	card.__datasheet = true
	card.__fieldCount = 0

	local margin = Fill(card, SHEET.marginFill, 'BACKGROUND', -7)
	margin:SetPoint('TOPLEFT', 0, 0)
	margin:SetPoint('BOTTOMLEFT', 0, 0)
	margin:SetWidth(SHEET.marginWidth)
	local divider = Fill(card, Theme.border.default)
	divider:SetWidth(1)
	divider:SetPoint('TOP', card, 'TOPLEFT', SHEET.marginWidth, 0)
	divider:SetPoint('BOTTOM', card, 'BOTTOMLEFT', SHEET.marginWidth, 0)
	local topRule = Fill(card, Theme.border.default)
	topRule:SetHeight(1)
	topRule:SetPoint('TOPLEFT', 0, 0)
	topRule:SetPoint('TOPRIGHT', 0, 0)
	local bottomRule = Fill(card, Theme.border.default)
	bottomRule:SetHeight(1)
	bottomRule:SetPoint('BOTTOMLEFT', 0, 0)
	bottomRule:SetPoint('BOTTOMRIGHT', 0, 0)

	local marginHeight = 16
	if title then
		local titleText = card:CreateFontString(nil, 'OVERLAY')
		titleText:SetFont(BUILib.Font, 12, '')
		titleText:SetShadowOffset(0, 0)
		titleText:SetPoint('TOPLEFT', 16, -10)
		titleText:SetWidth(SHEET.marginWidth - 28)
		titleText:SetJustifyH('LEFT')
		titleText:SetWordWrap(true)
		titleText:SetText(TitleCase(title))
		titleText:SetTextColor(unpack(Theme.text.secondary))
		card.titleFs = titleText

		local count = card:CreateFontString(nil, 'OVERLAY')
		count:SetFont(BUILib.Font, 10, '')
		count:SetShadowOffset(0, 0)
		count:SetPoint('TOPLEFT', titleText, 'BOTTOMLEFT', 0, -4)
		count:SetTextColor(unpack(Theme.text.muted))
		card.countFs = count
		marginHeight = 10 + math.ceil(titleText:GetStringHeight()) + 4 + 12 + 10
	end

	function card:SetFieldCount(fieldCount)
		self.__fieldCount = fieldCount
		if self.countFs then
			self.countFs:SetText(('%d %s'):format(fieldCount, fieldCount == 1 and 'field' or 'fields'))
		end
	end
	function card:AddField() self:SetFieldCount((self.__fieldCount or 0) + 1) end
	card:SetFieldCount(0)

	local bodyLeft = SHEET.marginWidth + SHEET.rowInset
	local innerWidth = width - bodyLeft - SHEET.rightPad
	local body = CreateFrame('Frame', nil, card)
	body:SetPoint('TOPLEFT', bodyLeft, -SHEET.topPad)
	body:SetPoint('TOPRIGHT', -SHEET.rightPad, -SHEET.topPad)
	body:SetHeight(SHEET.rowMin)

	local topAnchor = CreateFrame('Frame', nil, body)
	topAnchor:SetPoint('TOPLEFT'); topAnchor:SetPoint('TOPRIGHT'); topAnchor:SetHeight(1)

	local hairlines = {}
	local function Hairline(index)
		local line = hairlines[index]
		if not line then
			line = Fill(body, SHEET.hairline)
			line:SetHeight(1)
			hairlines[index] = line
		end
		return line
	end

	local content = {
		frame = card, child = body,
		y = 0, width = innerWidth, contentWidth = innerWidth,
		lastControl = topAnchor, lastMargin = 0,
		cardStyle = 'datasheet', _topAnchor = topAnchor, _marginHeight = marginHeight,
		_headerHeight = 0, _vpad = SHEET.topPad, _bpad = SHEET.bottomPad,
	}

	function content:Reflow()
		local bodyTop = body:GetTop()
		local rows = {}
		for _, child in ipairs({ body:GetChildren() }) do
			if child ~= topAnchor and child:IsShown() then
				AdaptRow(child, innerWidth)
				local top, bottom = child:GetTop(), child:GetBottom()
				if bodyTop and top and bottom then
					rows[#rows + 1] = { top = bodyTop - top, bottom = bodyTop - bottom, fields = child.__fieldCount or 1 }
				end
			end
		end
		table.sort(rows, function(first, second) return first.top < second.top end)
		local lowest = 0
		for _, region in ipairs({ body:GetRegions() }) do
			if bodyTop and region:IsShown() and region:GetObjectType() == 'FontString' then
				local bottom = region:GetBottom()
				if bottom and bodyTop - bottom > lowest then lowest = bodyTop - bottom end
			end
		end
		local lineCount = 0
		for index = 1, #rows - 1 do
			local gap = rows[index + 1].top - rows[index].bottom
			if gap >= 0 then
				lineCount = lineCount + 1
				local line = Hairline(lineCount)
				local y = math.floor(rows[index].bottom + gap / 2 + 0.5)
				line:ClearAllPoints()
				line:SetPoint('TOPLEFT', body, 'TOPLEFT', 0, -y)
				line:SetPoint('TOPRIGHT', body, 'TOPRIGHT', 0, -y)
				line:Show()
			end
		end
		for index = lineCount + 1, #hairlines do hairlines[index]:Hide() end
		local fieldCount = 0
		for _, row in ipairs(rows) do fieldCount = fieldCount + row.fields end
		card:SetFieldCount(fieldCount)
		if #rows > 0 and rows[#rows].bottom > lowest then lowest = rows[#rows].bottom end
		if lowest <= 0 then lowest = math.abs(self.y) end
		return math.floor(lowest + 0.5)
	end

	function content:GetContentHeight()
		return self:Reflow()
	end

	function content:Refresh()
		local contentHeight = self:GetContentHeight()
		self.child:SetHeight(math.max(contentHeight, 1))
		local totalHeight = math.max(SHEET.topPad + contentHeight + SHEET.bottomPad, self._marginHeight)
		if config.minHeight and totalHeight < config.minHeight then totalHeight = config.minHeight end
		self.frame:SetHeight(totalHeight)
		self.frame.layoutHeight = totalHeight
	end

	function content:SetBuilder(builder) self._builder = builder end

	function content:Clear()
		for _, child in ipairs({ self.child:GetChildren() }) do
			if child ~= self._topAnchor then
				child:Hide()
				child:SetParent(nil)
			end
		end
		for _, line in ipairs(hairlines) do line:Hide() end
		self.y = 0
		self.lastControl = self._topAnchor
		self.lastMargin = 0
	end

	function content:Rebuild()
		self:Clear()
		if self._builder then self._builder(self) end
		self:Refresh()
	end

	Controls.AttachCardDimming(content, card)
	Layout.ApplyContentMixin(content)
	content.lastControl = topAnchor
	card.content = content
	card:SetHeight(marginHeight)
	card.layoutHeight = marginHeight
	return cardWidget, content
end

local DEFAULT_DIM_OVERLAY = {
	kind = "icon",
	icon = BUILib.GetLibMedia('lock'),
	size = 20,
	color = {0.45, 0.45, 0.45, 0.85},
}

function Controls.AttachCardDimming(content, card)
	function content:SetDimmedOverlay(options)
		self._dimOverlayOpts = options
		if self._dimBlocker then
			self._dimBlocker:Hide()
			self._dimBlocker = nil
		end
	end

	local function BuildDimBlocker(self, cardFrame)
		local options = self._dimOverlayOpts or DEFAULT_DIM_OVERLAY

		local blocker = CreateFrame("Button", nil, cardFrame)
		blocker:SetAllPoints()
		blocker:SetFrameLevel(cardFrame:GetFrameLevel() + 50)
		blocker:EnableMouse(true)
		blocker:EnableMouseWheel(true)
		blocker:SetScript("OnMouseDown", function() end)
		blocker:SetScript("OnMouseWheel", function() end)
		blocker:SetIgnoreParentAlpha(true)
		blocker:SetAlpha(0)
		blocker:Hide()

		if options.kind == "none" then
			return blocker
		end

		local color = options.color or DEFAULT_DIM_OVERLAY.color

		if options.kind == "text" then
			local label = blocker:CreateFontString(nil, "OVERLAY")
			label:SetFont(BUILib.Font, options.fontSize or 18, "OUTLINE")
			label:SetPoint("CENTER")
			label:SetText(options.text or "Locked")
			label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
			blocker.label = label
		else
			local icon = blocker:CreateTexture(nil, "OVERLAY")
			local size = options.size or DEFAULT_DIM_OVERLAY.size
			if options.atlas then
				icon:SetAtlas(options.atlas)
			elseif options.icon then
				icon:SetTexture(options.icon)
			else
				icon:SetAtlas(DEFAULT_DIM_OVERLAY.atlas)
			end
			icon:SetSize(size, size)
			icon:SetPoint("CENTER")
			icon:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
			blocker.icon = icon
		end

		return blocker
	end

	function content:SetDimmed(state)
		if state == self._dimmed then return end
		self._dimmed = state

		local cardFrame = self.frame
		local cardTarget = state and 0.35 or 1
		local cardFrom = cardFrame:GetAlpha() or 1

		if not self._dimBlocker then self._dimBlocker = BuildDimBlocker(self, cardFrame) end

		local blocker = self._dimBlocker
		local labelTarget = state and 1 or 0
		local labelFrom = blocker:GetAlpha() or 0
		blocker:Show()

		local elapsed = 0
		local DURATION = 0.18
		if not self._dimAnimFrame then self._dimAnimFrame = CreateFrame("Frame") end
		self._dimAnimFrame:SetScript("OnUpdate", function(animFrame, deltaTime)
			elapsed = elapsed + deltaTime
			local progress = elapsed / DURATION
			if progress >= 1 then
				cardFrame:SetAlpha(cardTarget)
				blocker:SetAlpha(labelTarget)
				if labelTarget == 0 then blocker:Hide() end
				animFrame:SetScript("OnUpdate", nil)
			else
				local eased = 1 - (1 - progress) * (1 - progress)
				cardFrame:SetAlpha(cardFrom + (cardTarget - cardFrom) * eased)
				blocker:SetAlpha(labelFrom + (labelTarget - labelFrom) * eased)
			end
		end)
	end
end

function Controls.SettingsCard(parent, config)
	config = config or {}
	local width = config.width or 500
	local title = config.title
	local horizontalPad = Layout.PANEL_HPAD
	local verticalPad = Layout.PANEL_VPAD
	local bottomPad = Layout.PANEL_BPAD

	local cardWidget = Widget.New(parent, "Frame", nil, {raw = true, width = width})
	local card = cardWidget.frame

	local style = config.style or BUILib.GetCardStyle()
	if style == 'datasheet' then
		return BuildDatasheetCard(cardWidget, card, config, width, title)
	end

	Widget.DrawCardShape(card, CORNER_RADIUS, Theme.bg.card, {0.20, 0.22, 0.26, 0.50}, "BACKGROUND", 0, 0)

	local headerHeight = 0

	if title then
		headerHeight = 28

		local accentRed, accentGreen, accentBlue = Theme.GetAccent()
		local accent = card:CreateTexture(nil, "OVERLAY")
		accent:SetTexture(Widget.WHITE)
		accent:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
		accent:SetSize(2, 14)
		accent:SetPoint("TOPLEFT", 14, -14)
		Theme.RegisterAccentElement(accent, function(element, red, green, blue) element:SetVertexColor(red, green, blue, 1) end)

		local titleText = card:CreateFontString(nil, "OVERLAY")
		titleText:SetFont(BUILib.Font, 13, "OUTLINE")
		titleText:SetPoint("LEFT", accent, "RIGHT", 8, 0)
		titleText:SetText(string.upper(title))
		titleText:SetTextColor(1, 1, 1, 1)
		card.titleFs = titleText
	end

	local innerWidth = width - (horizontalPad * 2)
	local body = CreateFrame("Frame", nil, card)
	body:SetPoint("TOPLEFT", horizontalPad, -(headerHeight + verticalPad))
	body:SetPoint("TOPRIGHT", -horizontalPad, -(headerHeight + verticalPad))
	body:SetHeight(40)

	local topAnchor = CreateFrame("Frame", nil, body)
	topAnchor:SetPoint("TOPLEFT"); topAnchor:SetPoint("TOPRIGHT"); topAnchor:SetHeight(1)

	local content = {
		frame = card, child = body,
		y = 0, width = innerWidth, contentWidth = innerWidth,
		lastControl = topAnchor, lastMargin = 0,
		_vpad = verticalPad, _bpad = bottomPad, _headerHeight = headerHeight, _topAnchor = topAnchor,
	}

	function content:GetContentHeight()
		local contentHeight = self:_MeasureContentHeight()
		if contentHeight < 20 then contentHeight = math.max(30, math.abs(self.y)) end
		return contentHeight
	end

	function content:Refresh()
		local contentHeight = self:GetContentHeight()
		self.child:SetHeight(contentHeight)
		local totalHeight = self._headerHeight + self._vpad + contentHeight + self._bpad

		local minHeight = config.minHeight
		if config.minRows then
			local rowsHeight = self._headerHeight + self._vpad + config.minRows * 40 + self._bpad
			if not minHeight or rowsHeight > minHeight then minHeight = rowsHeight end
		end
		if minHeight and totalHeight < minHeight then totalHeight = minHeight end
		self.frame:SetHeight(totalHeight)
		self.frame.layoutHeight = totalHeight
	end

	function content:SetBuilder(builder)
		self._builder = builder
	end

	function content:Clear()
		for _, child in ipairs({self.child:GetChildren()}) do
			if child ~= self._topAnchor then
				child:Hide()
				child:SetParent(nil)
			end
		end
		for _, region in ipairs({self.child:GetRegions()}) do
			region:Hide()
		end
		self.y = 0
		self.lastControl = self._topAnchor
		self.lastMargin = 0
	end

	function content:Rebuild()
		self:Clear()
		if self._builder then self._builder(self) end
		self:Refresh()
	end

	Controls.AttachCardDimming(content, card)
	Layout.ApplyContentMixin(content)
	content.lastControl = topAnchor

	card.content = content
	local initialHeight = headerHeight + verticalPad * 2 + 40
	card:SetHeight(initialHeight)
	card.layoutHeight = initialHeight

	return cardWidget, content
end
