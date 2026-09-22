local BUILib = LibStub('BUILib')
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Controls = BUILib.Controls
local Widget = BUILib.Widget

local TOP_PAD = 16
local CHIP_PITCH = Widget.NAV_CHIP_HEIGHT + 8
local HEADER_HEIGHT = Widget.NAV_HEADER_HEIGHT
local GROUP_GAP = 8
local CHILD_INDENT = 16
local CHILD_FONT_SIZE = 11
local PARENT_FONT_SIZE = 12
local CHEVRON_SIZE = 10
local CHEVRON_X = -12
local DIVIDER_COLOR = { 0.10, 0.10, 0.12, 1 }
local DETAIL_PADDING = 15
local unpack = unpack

function Layout.SidebarPage(parent, config)
	config = config or {}
	local groups       = config.groups or {}
	local listWidth    = config.listWidth or 180
	local contentWidth = config.contentWidth or 620
	local onSelect     = config.onSelect
	local onLayout     = config.onLayout

	local sidebarPage    = {}
	local selectedItemID = nil
	local headerFrames   = {}
	local chipFrames     = {}
	local expandedItems  = {}
	local detailTab      = nil

	local listFrame = CreateFrame('Frame', nil, parent)
	listFrame:SetWidth(listWidth)
	listFrame:SetPoint('TOPLEFT', 0, 0)
	listFrame:SetPoint('BOTTOMLEFT', 0, 0)
	local divider = listFrame:CreateTexture(nil, 'OVERLAY')
	divider:SetTexture(Widget.WHITE)
	divider:SetVertexColor(unpack(DIVIDER_COLOR))
	divider:SetWidth(1)
	divider:SetPoint('TOPRIGHT')
	divider:SetPoint('BOTTOMRIGHT')

	local detailFrame = CreateFrame('Frame', nil, parent)
	detailFrame:SetPoint('TOPLEFT', listWidth + 1, 0)
	detailFrame:SetPoint('BOTTOMRIGHT', 0, 0)

	local scrollWidget = Controls.ScrollFrame(detailFrame, nil, nil, 100)
	local scrollContainer = scrollWidget.frame or scrollWidget
	scrollContainer:SetAllPoints()
	local scrollChild = scrollContainer.child

	local scrollFrame = scrollContainer.scrollFrame or scrollContainer
	scrollFrame:HookScript('OnSizeChanged', function(self)
		local width = self:GetWidth()
		if width and width > 50 then scrollChild:SetWidth(width) end
	end)

	local contentWrapper = CreateFrame('Frame', nil, scrollChild)
	contentWrapper:SetWidth(contentWidth)
	contentWrapper:SetHeight(100)
	contentWrapper:SetPoint('TOP', scrollChild, 'TOP', -4, 0)

	local topAnchor = CreateFrame('Frame', nil, contentWrapper)
	topAnchor:SetPoint('TOPLEFT'); topAnchor:SetPoint('TOPRIGHT'); topAnchor:SetHeight(1)

	local function UpdateContentPosition()
		if not scrollChild or not contentWrapper then return end
		local childWidth = scrollChild:GetWidth() or 0
		if childWidth < 50 then return end
		local effectiveWidth = math.min(contentWidth, childWidth - DETAIL_PADDING * 2)
		contentWrapper:SetWidth(effectiveWidth)
	end

	scrollChild:SetScript('OnSizeChanged', UpdateContentPosition)
	BUILib.Defer(function()
		local width = scrollFrame:GetWidth()
		if width and width > 50 then scrollChild:SetWidth(width) end
		UpdateContentPosition()
	end)

	local function ResetDetail()
		local children = { contentWrapper:GetChildren() }
		for _, child in ipairs(children) do
			if child ~= topAnchor then child:Hide() end
		end

		local regions = { contentWrapper:GetRegions() }
		for _, region in ipairs(regions) do
			region:Hide()
		end

		UpdateContentPosition()

		detailTab = Layout.ApplyContentMixin({
			child      = contentWrapper,
			frame      = scrollContainer,
			scrollChild = scrollChild,
			scroll     = scrollContainer,
			width      = contentWidth,
		})
		detailTab.lastControl = topAnchor
	end

	local function FinalizeDetail()
		if not contentWrapper then return end
		local height = math.max(Layout.MeasureLowestExtent(contentWrapper) + 20, 100)
		contentWrapper:SetHeight(height)
		scrollChild:SetHeight(height)
		scrollContainer:UpdateScroll()
	end

	local function GetOrCreateHeader(index)
		if headerFrames[index] then return headerFrames[index] end
		local header = Widget.NavHeader(listFrame, '', 0)
		headerFrames[index] = header
		return header
	end

	local function GetOrCreateChip(index)
		if chipFrames[index] then return chipFrames[index] end
		local chip = Widget.NavChip(listFrame, '', nil)
		local chevron = chip:CreateTexture(nil, 'ARTWORK')
		chevron:SetTexture(BUILib.GetLibMedia('dropdown'))
		chevron:SetSize(CHEVRON_SIZE, CHEVRON_SIZE)
		chevron:SetPoint('RIGHT', CHEVRON_X, 0)
		chevron:SetVertexColor(0.74, 0.74, 0.78, 1)
		chevron:Hide()
		chip.chevron = chevron
		chip:HookScript('OnEnter', function(self)
			if self.comingSoon then Widget.ShowTip(self, 'Coming Soon', { anchor = 'RIGHT' }) end
		end)
		chip:HookScript('OnLeave', function(self)
			if self.comingSoon then Widget.HideTip() end
		end)
		chipFrames[index] = chip
		return chip
	end

	local function ContainsSelected(item)
		if not item.children then return false end
		for _, child in ipairs(item.children) do
			if child.id == selectedItemID then return true end
		end
		return false
	end

	local function RebuildSidebar()
		for _, header in ipairs(headerFrames) do header:Hide() end
		for _, chip in ipairs(chipFrames) do chip:Hide() end

		local yOffset = TOP_PAD
		local headerIndex, chipIndex = 0, 0
		local anySelected = false

		local function RenderItem(item, depth)
			chipIndex = chipIndex + 1
			local chip = GetOrCreateChip(chipIndex)
			local isChild = depth > 0
			chip:ClearAllPoints()
			chip:SetPoint('TOPLEFT', Widget.NAV_CHIP_X, -yOffset)
			chip:SetLabel(item.label)
			chip:SetIndent(isChild and CHILD_INDENT * depth or 0)
			chip.text:SetFont(BUILib.Font, isChild and CHILD_FONT_SIZE or PARENT_FONT_SIZE, '')

			local holdsSelected = ContainsSelected(item)
			local isOpen = item.children ~= nil and (expandedItems[item] or holdsSelected) and true or false
			local isSelected = item.id ~= nil and item.id == selectedItemID
			chip.chevron:SetShown(item.children ~= nil)
			chip.chevron:SetRotation(isOpen and 0 or math.pi / 2)

			Widget.NavChipEnable(chip, function()
				if item.children then
					if item.id and not isSelected then
						expandedItems[item] = true
						sidebarPage:Select(item.id)
					else
						expandedItems[item] = not expandedItems[item]
						RebuildSidebar()
					end
				elseif item.id then
					sidebarPage:Select(item.id)
				end
			end)
			chip.comingSoon = item.comingSoon and true or nil
			if item.comingSoon then Widget.NavChipMute(chip) end
			chip:SetSelected(isSelected)
			if isSelected then anySelected = true end
			chip:Show()
			yOffset = yOffset + CHIP_PITCH

			if isOpen then
				for _, child in ipairs(item.children) do
					RenderItem(child, depth + 1)
				end
			end
		end

		for groupIndex, group in ipairs(groups) do
			if groupIndex > 1 then yOffset = yOffset + GROUP_GAP end
			headerIndex = headerIndex + 1
			local header = GetOrCreateHeader(headerIndex)
			header:ClearAllPoints()
			header:SetPoint('TOPLEFT', 24, -yOffset)
			header:SetText(string.upper(group.header or ''))
			header:Show()
			yOffset = yOffset + HEADER_HEIGHT

			for _, item in ipairs(group.items) do
				RenderItem(item, 0)
			end
		end

		if not anySelected then Widget.NavResetPill(listFrame) end
		sidebarPage.listHeight = yOffset
		if onLayout then onLayout(yOffset) end
	end

	function sidebarPage:Select(itemID)
		if itemID == selectedItemID and detailTab then return end
		selectedItemID = itemID
		RebuildSidebar()
		ResetDetail()
		if onSelect then onSelect(itemID, detailTab) end
		FinalizeDetail()
	end

	function sidebarPage:GetSelected()
		return selectedItemID
	end

	function sidebarPage:GetDetailContent()
		return contentWrapper
	end

	function sidebarPage:GetDetailScroll()
		return scrollContainer
	end

	for _, group in ipairs(groups) do
		for _, item in ipairs(group.items or {}) do
			if item.expanded then expandedItems[item] = true end
		end
	end

	local defaultID = config.default
	if not defaultID then
		for _, group in ipairs(groups) do
			if group.items and group.items[1] then defaultID = group.items[1].id; break end
		end
	end

	RebuildSidebar()
	if defaultID then sidebarPage:Select(defaultID) end

	sidebarPage.listContainer = listFrame
	sidebarPage.detailContainer = detailFrame
	sidebarPage.frame = parent

	return sidebarPage
end
