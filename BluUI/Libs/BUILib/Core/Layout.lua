local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Widget = BUILib.Widget
local Theme

local function GetTheme() if not Theme then Theme = BUILib.Theme end return Theme end

local deferredCallbacks = {}
local deferredQueued = {}
local deferFrame = CreateFrame("Frame", "BUILib_DeferFrame")
function BUILib.Defer(callback)
	if not callback or deferredQueued[callback] then return end
	deferredQueued[callback] = true
	deferredCallbacks[#deferredCallbacks + 1] = callback
	deferFrame:Show()
end
deferFrame:SetScript("OnUpdate", function(self)
	local callbacks = deferredCallbacks
	deferredCallbacks = {}
	self:Hide()
	for callbackIndex = 1, #callbacks do deferredQueued[callbacks[callbackIndex]] = nil end
	for callbackIndex = 1, #callbacks do callbacks[callbackIndex]() end
end)
deferFrame:Hide()

Layout.DEFAULT_WIDTH = 876
Layout.PAGE_CONTENT_W = 804
Layout.PAGE_PREVIEW_H = 180
Layout.DEFAULT_PADDING = 20
Layout.DEFAULT_GAP = 10
Layout.DEFAULT_MARGIN = 14
Layout.CONTROL_HEIGHT = BUILib.CONTROL_HEIGHT
Layout.ROW_HEIGHT = BUILib.ROW_HEIGHT
Layout.BUTTON_ROW_HEIGHT = BUILib.BUTTON_ROW_HEIGHT
Layout.LABEL_OFFSET = BUILib.LABEL_OFFSET
Layout.COMPACT_MARGIN = 10
Layout.PANEL_HPAD = 14
Layout.PANEL_VPAD = 0
Layout.PANEL_BPAD = 10
Layout.GRID_TOP_MARGIN = 0

local PAGE_INDENT_OFFSET = 15
local SCROLL_LEFT_PAD = 4

local allPages = setmetatable({}, {__mode = "v"})

local function GetCurrentStyle()
	return "centered"
end

local function RefreshAllPages()
	for _, page in ipairs(allPages) do
		if page and page.tabContents then
			for _, tab in pairs(page.tabContents) do
				if tab.UpdatePosition then tab:UpdatePosition() end
			end
		end
	end
end

function Layout.SetStyle(style)
	if style == "offset" or style == "centered" then
		BUILib.GetActiveClient().layoutStyle = style
		RefreshAllPages()
	end
end

local function GetPageIndent(containerWidth, contentWidth)
	if GetCurrentStyle() == "centered" and containerWidth and contentWidth then
		return math.max(0, math.floor((containerWidth - contentWidth) / 2) - SCROLL_LEFT_PAD)
	end
	return PAGE_INDENT_OFFSET
end

local ContentMixin = {}

function ContentMixin:AddY(amount)
	self.y = math.floor(self.y - amount)
	return self.y
end

function ContentMixin:GetY() return self.y end

function ContentMixin:SetLast(control, margin)
	self.lastControl = Widget.Unwrap(control)
	self.lastMargin = margin or 0
end

function ContentMixin:GetAnchor(topMargin)
	topMargin = topMargin or Layout.DEFAULT_MARGIN
	if self.lastControl then
		return self.lastControl, math.floor(-(topMargin + self.lastMargin))
	end

	return nil, -(self.topPadding or Layout.DEFAULT_PADDING)
end

function ContentMixin:GetContentHeight()
	return self:_MeasureContentHeight()
end

function Layout.MeasureLowestExtent(childFrame, skipFrame, requirePositiveHeight)
	local childTop = childFrame:GetTop()
	if not childTop then return 0 end
	local lowest = 0
	local childCount = childFrame:GetNumChildren()
	for index = 1, childCount do
		local child = select(index, childFrame:GetChildren())
		if child and child ~= skipFrame and child:IsShown()
			and (not requirePositiveHeight or child:GetHeight() > 0) then
			local childBottom = child:GetBottom()
			if childBottom then
				local extent = childTop - childBottom
				if extent > lowest then lowest = extent end
			end
		end
	end
	return lowest
end

function ContentMixin:_MeasureContentHeight()
	local lowest = Layout.MeasureLowestExtent(self.child, nil, true)
	if lowest > 0 then return lowest end
	return math.abs(self.y)
end

local SCROLL_BOTTOM_PAD = 20

function ContentMixin:Refresh()
	if self._isRefreshing then return end
	self._isRefreshing = true
	local containerHeight = Widget.SafeGetHeight(self.frame) - (self._pinnedHeight or 0)
	if containerHeight < 50 then self._isRefreshing = false return end

	local rawHeight = self:_MeasureContentHeight()
	local contentHeight = math.max(rawHeight + SCROLL_BOTTOM_PAD, 100)
	self.child:SetHeight(contentHeight)

	local visibleHeight = containerHeight - 8
	local needsScroll = rawHeight > visibleHeight

	self.scroll._refreshLock = true
	self.scroll:SetChildHeight(needsScroll and contentHeight or visibleHeight)

	if self.scroll.scrollbar then self.scroll.scrollbar:SetShown(needsScroll) end
	if self.scroll.thumb then self.scroll.thumb:SetShown(needsScroll) end
	if self.scroll.scrollFrame then
		self.scroll.scrollFrame:SetPoint("BOTTOMRIGHT", needsScroll and -14 or -4, 4)
		local currentScroll = self.scroll.scrollFrame:GetVerticalScroll() or 0
		local maxScroll = math.max(contentHeight - visibleHeight, 0)
		if not needsScroll then
			self.scroll.scrollFrame:SetVerticalScroll(0)
		elseif currentScroll > maxScroll then
			self.scroll.scrollFrame:SetVerticalScroll(maxScroll)
		end
	end
	self._isRefreshing = false

	BUILib.Defer(function() self.scroll._refreshLock = nil end)
end

function ContentMixin:Clear()
	for _, child in pairs({ self.child:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
	self.y = -Layout.DEFAULT_PADDING
	self.lastControl = nil
	self.lastMargin = 0
	if self.scroll and self.scroll.scrollFrame then
		self.scroll.scrollFrame:SetVerticalScroll(0)
	end
end

function Layout.ApplyContentMixin(obj)
	for key, value in pairs(ContentMixin) do
		if not obj[key] then obj[key] = value end
	end
	obj.y = obj.y or -Layout.DEFAULT_PADDING
	obj.lastControl = nil
	obj.lastMargin = 0
	obj._isRefreshing = false
	return obj
end

function Layout.ParseControlParams(labelOrDef, tab, defaults)
	local def = type(labelOrDef) == "table" and labelOrDef or {label = labelOrDef}
	def.width = def.width or tab.width
	def.topMargin = def.topMargin or Layout.DEFAULT_MARGIN
	for key, value in pairs(defaults or {}) do
		if def[key] == nil then def[key] = value end
	end
	return def
end

function Layout.PositionInTab(tab, control, height, topMargin)
	topMargin = topMargin or Layout.DEFAULT_MARGIN
	local anchorTo, yOffset = tab:GetAnchor(topMargin)
	if anchorTo then
		control:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOffset)
	else
		control:SetPoint("TOPLEFT", Layout.DEFAULT_PADDING, yOffset - topMargin)
	end
	tab:SetLast(control, 0)
	tab:AddY(topMargin + height)
end

function Layout.Page(parent, tabs, width)
	width = width or BUILib.GetActiveClient().defaultWidth or Layout.DEFAULT_WIDTH
	local Controls = BUILib.Controls
	local page = {width = width, tabs = tabs or {}, tabContents = {}, currentTab = 0}

	local tabBar
	if tabs and #tabs > 0 then
		tabBar = Controls.TabLineBar(parent, tabs, 1, nil, width)
		tabBar:SetPoint("TOPLEFT", SCROLL_LEFT_PAD + PAGE_INDENT_OFFSET, -10)
		page.tabBar = tabBar
	end

	local function CreateTabContent(index)
		local container = CreateFrame("Frame", nil, parent)

		local tabBarOffset = 0
		if tabBar then
			local barFrame = tabBar.frame or tabBar
			tabBarOffset = -(10 + (barFrame:GetHeight() or 32) + 6)
		end
		container:SetPoint("TOPLEFT", 0, tabBarOffset)
		container:SetPoint("BOTTOMRIGHT", 0, 14)
		container:Hide()

		local scrollContainer = Controls.ScrollFrame(container, nil, nil, 100)

		local pinned = CreateFrame("Frame", nil, container)
		pinned:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
		pinned:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
		pinned:SetHeight(1)
		pinned:Hide()

		local pinnedHeight = 0
		local function AnchorScroll()
			scrollContainer:ClearAllPoints()
			scrollContainer:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -pinnedHeight)
			scrollContainer:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
		end
		AnchorScroll()

		local contentWrapper = CreateFrame("Frame", nil, scrollContainer.child)
		contentWrapper:SetWidth(width)
		contentWrapper:SetHeight(100)
		contentWrapper:SetPoint("TOPLEFT", scrollContainer.child, "TOPLEFT", 0, 0)

		local content

		local function UpdateWrapperPosition()
			local containerWidth = container:GetWidth() or 0
			local containerHeight = container:GetHeight() or 0
			if containerWidth < 50 or containerHeight < 50 then return end
			scrollContainer.child:SetWidth(math.max(containerWidth - 24, width))
			local indent = GetPageIndent(containerWidth, width)
			contentWrapper:ClearAllPoints()
			contentWrapper:SetPoint("TOPLEFT", scrollContainer.child, "TOPLEFT", indent - Layout.DEFAULT_PADDING, 0)
			if tabBar then
				tabBar:ClearAllPoints()
				tabBar:SetPoint("TOPLEFT", SCROLL_LEFT_PAD + indent, -10)
			end
		end

		local sizeChangeTimer = nil
		local function DeferredSizeRefresh()
			sizeChangeTimer = nil
			if page.currentTab == index and content and content.Refresh and not content._isRefreshing then
				content:Refresh()
			end
		end
		container:SetScript("OnSizeChanged", function()
			if page.currentTab ~= index then return end
			UpdateWrapperPosition()
			if content and content._isRefreshing then return end
			if BUILib._isResizing then return end
			if sizeChangeTimer then return end
			sizeChangeTimer = true
			BUILib.Defer(DeferredSizeRefresh)
		end)
		container:SetScript("OnShow", function()

			if page.currentTab ~= index then
				container:Hide()
				return
			end
			UpdateWrapperPosition()
			if content and content.Refresh then
				BUILib.Defer(function()
					if page.currentTab == index then content:Refresh() end
				end)
			end
		end)
		UpdateWrapperPosition()

		content = Layout.ApplyContentMixin({
			frame = container,
			scroll = scrollContainer,
			scrollChild = scrollContainer.child,
			child = contentWrapper,
			pinned = pinned,
			width = width,
			UpdatePosition = UpdateWrapperPosition,
		})

		function content:SetPinnedHeight(height)
			pinnedHeight = height or 0
			self._pinnedHeight = pinnedHeight
			pinned:SetShown(pinnedHeight > 0)
			pinned:SetHeight(pinnedHeight > 0 and pinnedHeight or 1)
			AnchorScroll()
		end

		page.tabContents[index] = content
		return content
	end

	function page:ShowTab(index)
		if self.currentTab == index then return end
		self.currentTab = index
		for tabIndex, tabContent in pairs(self.tabContents) do
			tabContent.frame:SetShown(tabIndex == index)
		end
	end

	if tabs then
		for tabIndex = 1, #tabs do CreateTabContent(tabIndex) end
		page.tabBar:SetCallback(function(tabIndex) page:ShowTab(tabIndex) end)
		page:ShowTab(1)
	else
		CreateTabContent(1)
		page:ShowTab(1)
	end

	function page:GetTab(index) return self.tabContents[index or self.currentTab] end
	function page:SetTab(index)
		if self.tabBar then self.tabBar:SetSelected(index) end
		self:ShowTab(index)
	end
	function page:Refresh()
		for _, tab in pairs(self.tabContents) do
			if tab.Refresh then tab:Refresh() end
		end
	end
	function page:AutoRefresh()
		BUILib.Defer(function() self:Refresh() end)
	end

	allPages[#allPages + 1] = page
	return page
end

function Layout.Section(tab, title, description)
	local Controls = BUILib.Controls
	local sectionFrame = CreateFrame("Frame", nil, tab.child)
	sectionFrame:SetWidth(tab.contentWidth or tab.width)
	local header = Controls.CategoryLabel(sectionFrame, title, tab.contentWidth or tab.width, description)
	header:SetPoint("TOPLEFT", 0, 0)
	local sectionHeight = description and 42 or 28
	sectionFrame:SetHeight(sectionHeight)
	local topMargin = tab.lastControl and 24 or 0
	local anchorTo, yOffset = tab:GetAnchor(topMargin)
	if anchorTo then
		sectionFrame:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOffset)
	else
		sectionFrame:SetPoint("TOPLEFT", Layout.DEFAULT_PADDING, yOffset)
	end
	tab:SetLast(sectionFrame, 6)
	tab:AddY(topMargin + sectionHeight + 6)
	return {tab = tab, controls = {}, header = header}
end

function Layout.Refresh(tab)
	if tab and tab.Refresh then return tab:Refresh()
	elseif tab and tab.scroll and tab.scroll.RefreshContentHeight then return tab.scroll:RefreshContentHeight() end
	return false
end

function Layout.Add(tab, control, topMargin, description)
	if not topMargin then topMargin = control.layoutHeight and 12 or 8 end
	if not control.layoutHeight then control:SetWidth(tab.width) end
	if tab.scroll and control.SetOnHeightChanged then
		control:SetOnHeightChanged(function()
			BUILib.Defer(function() if tab.Refresh then tab:Refresh() end end)
		end)
	end
	local anchorTo, yOffset = tab:GetAnchor(topMargin)
	if anchorTo then
		control:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOffset)
	else
		control:SetPoint("TOPLEFT", Layout.DEFAULT_PADDING, yOffset - topMargin)
	end
	local height = math.floor((control.layoutHeight or control:GetHeight() or 28) + 0.5)
	if description then
		local descriptionText = BUILib.Controls.Text(tab.child, description, 11, GetTheme().text.muted)
		descriptionText:SetPoint("TOPLEFT", Widget.Unwrap(control), "BOTTOMLEFT", 0, -4)
		height = height + 18
	end
	tab:SetLast(control, 0)
	tab:AddY(topMargin + height)
	return control
end

function Layout.Row(tab, controls, gap, topMargin)
	gap = gap or Layout.DEFAULT_GAP
	topMargin = topMargin or Layout.DEFAULT_MARGIN
	local rowFrame = CreateFrame("Frame", nil, tab.child)
	rowFrame:SetWidth(tab.width)
	local x, maxHeight = 0, 0
	for _, control in ipairs(controls) do
		control:SetParent(rowFrame)
		control:ClearAllPoints()
		control:SetPoint("TOPLEFT", x, 0)
		x = x + (control:GetWidth() or 100) + gap
		local height = control:GetHeight() or 30
		if height > maxHeight then maxHeight = height end
	end
	maxHeight = math.floor(maxHeight + 0.5)
	rowFrame:SetHeight(maxHeight)
	local anchorTo, yOffset = tab:GetAnchor(topMargin)
	if anchorTo then
		rowFrame:SetPoint("TOPLEFT", Widget.Unwrap(anchorTo), "BOTTOMLEFT", 0, yOffset)
	else
		rowFrame:SetPoint("TOPLEFT", Layout.DEFAULT_PADDING, yOffset - topMargin)
	end
	tab:SetLast(rowFrame, 0)
	tab:AddY(topMargin + maxHeight)
	return controls
end

function Layout.ButtonRow(tab, buttonsOrDef, topMargin)
	local def = type(buttonsOrDef) == "table" and buttonsOrDef.buttons and buttonsOrDef or nil
	local buttons = def and def.buttons or (not def and buttonsOrDef) or nil
	topMargin = def and def.topMargin or topMargin or Layout.DEFAULT_MARGIN
	local gap, rowHeight = 8, Layout.BUTTON_ROW_HEIGHT
	local rowFrame = CreateFrame("Frame", nil, tab.child)
	rowFrame:SetSize(tab.width, rowHeight)
	local created, previousButton = {}, nil
	for buttonIndex = #buttons, 1, -1 do
		local buttonDef = buttons[buttonIndex]
		local button = BUILib.Controls.Button(rowFrame, buttonDef.text or "Button", buttonDef.width or 80)
		button:SetHeight(rowHeight)
		if previousButton then button:SetPoint("RIGHT", previousButton, "LEFT", -gap, 0)
		else button:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0) end
		if buttonDef.callback then button:SetScript("OnClick", buttonDef.callback) end
		previousButton = button
		table.insert(created, 1, button)
	end
	rowFrame.buttons = created
	Layout.PositionInTab(tab, rowFrame, rowHeight, topMargin)
	return rowFrame, created
end

function Layout.TextArea(tab, labelOrDef, height, topMargin)
	local theme = GetTheme()
	local def = type(labelOrDef) == "table" and labelOrDef or nil
	height = def and def.height or height or 80
	topMargin = def and def.topMargin or topMargin or Layout.DEFAULT_MARGIN
	local width = def and def.width or tab.width or 500
	local container = CreateFrame("Frame", nil, tab.child, "BackdropTemplate")
	container:SetSize(width, height)
	container:SetBackdrop(Widget.BACKDROP)
	if def and def.transparent then
		container:SetBackdropColor(0, 0, 0, 0)
		container:SetBackdropBorderColor(0, 0, 0, 0)
	else
		container:SetBackdropColor(unpack(theme.bg.input))
		container:SetBackdropBorderColor(unpack(theme.border.input))
	end
	local scroll = CreateFrame("ScrollFrame", nil, container)
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -20, 8)
	local editbox = CreateFrame("EditBox", nil, scroll)
	editbox:SetWidth(width - 30)
	editbox:SetHeight(1)
	editbox:SetFont(BUILib.Font, 11, "")
	editbox:SetAutoFocus(false)
	editbox:SetMultiLine(true)
	editbox:SetMaxLetters(0)
	editbox:EnableMouse(true)
	editbox:SetTextColor(unpack(theme.text.primary))
	scroll:SetScrollChild(editbox)
	local scrollbar = CreateFrame("Slider", nil, container, "BackdropTemplate")
	scrollbar:SetPoint("TOPRIGHT", -4, -4)
	scrollbar:SetPoint("BOTTOMRIGHT", -4, 4)
	scrollbar:SetWidth(6)
	scrollbar:SetOrientation("VERTICAL")
	scrollbar:SetMinMaxValues(0, 1)
	scrollbar:SetValue(0)
	scrollbar:SetBackdrop(Widget.BACKDROP)
	scrollbar:SetBackdropColor(unpack(theme.scrollbar.track))
	scrollbar:SetBackdropBorderColor(0, 0, 0, 0)
	scrollbar:SetHitRectInsets(-4, -4, 0, 0)
	local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture(Widget.WHITE)
	thumb:SetVertexColor(unpack(theme.scrollbar.thumb))
	thumb:SetSize(6, 30)
	scrollbar:SetThumbTexture(thumb)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local currentScroll = self:GetVerticalScroll()
		local maxScroll = self:GetVerticalScrollRange()
		self:SetVerticalScroll(math.max(0, math.min(maxScroll, currentScroll - delta * 20)))
	end)
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function() editbox:SetFocus() end)

	local measureFontString = scroll:CreateFontString(nil, "ARTWORK")
	measureFontString:SetFont(BUILib.Font, 11, "")
	measureFontString:SetWidth(width - 30)
	measureFontString:SetWordWrap(true)
	measureFontString:SetNonSpaceWrap(true)
	measureFontString:Hide()

	local function SyncLayout()
		local scrollHeight = scroll:GetHeight() or 0
		if scrollHeight < 10 then return end
		measureFontString:SetText(editbox:GetText() or "")
		local textHeight = measureFontString:GetStringHeight() or 0
		local editHeight = math.max(scrollHeight, textHeight + 4)
		editbox:SetHeight(editHeight)
		local maxScroll = math.max(0, editHeight - scrollHeight)
		scrollbar:SetShown(maxScroll > 0)
		if maxScroll > 0 then scrollbar:SetMinMaxValues(0, maxScroll) end
	end

	scroll:SetScript("OnVerticalScroll", function(_, offset)
		scrollbar:SetValue(offset)
	end)
	scroll:HookScript("OnSizeChanged", SyncLayout)
	editbox:HookScript("OnTextChanged", SyncLayout)
	editbox:HookScript("OnTextSet", SyncLayout)

	scrollbar:SetScript("OnValueChanged", function(_, value) scroll:SetVerticalScroll(value) end)
	editbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	editbox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scrollbar:Hide()
	container.editbox = editbox
	container.scroll = scroll
	Layout.PositionInTab(tab, container, height, topMargin)
	return container
end
