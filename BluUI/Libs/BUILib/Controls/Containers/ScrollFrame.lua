local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Layout = BUILib.Layout
local Theme = BUILib.Theme
local Widget = BUILib.Widget

function Controls.ScrollFrame(parent, width, height, childHeight, childWidth)
	local parentFrame = Widget.Unwrap(parent)
	local container = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
	if width and height then container:SetSize(width, height)
	else container:SetAllPoints() end
	container:SetBackdrop({bgFile = Widget.WHITE})
	container:SetBackdropColor(0, 0, 0, 0)

	local scrollFrame = CreateFrame("ScrollFrame", nil, container)
	scrollFrame:SetPoint("TOPLEFT", 4, -4)
	scrollFrame:SetPoint("BOTTOMRIGHT", -4, 4)

	local child = CreateFrame("Frame", nil, scrollFrame)
	child:SetSize(childWidth or (width or 700) - 24, 100)
	scrollFrame:SetScrollChild(child)

	local track = CreateFrame("Frame", nil, container, "BackdropTemplate")
	track:SetPoint("TOPRIGHT", -4, -4)
	track:SetPoint("BOTTOMRIGHT", -4, 4)
	track:SetWidth(8)
	track:SetBackdrop({bgFile = Widget.WHITE})
	track:SetBackdropColor(unpack(Theme.scrollbar.track))
	track:Hide()

	local thumbWidget = Widget.New(container, "Frame", nil, {bg = Theme.scrollbar.thumb, border = Theme.scrollbar.border, size = {6, 40}})
	local thumb = thumbWidget.frame
	thumb:SetPoint("TOP", track, "TOP", 0, 0)
	thumb:SetFrameLevel(track:GetFrameLevel() + 5)
	thumb:EnableMouse(true)
	thumb:SetMovable(true)
	thumb:SetHitRectInsets(-4, -4, 0, 0)
	thumb:Hide()
	thumb:SetScript("OnEnter", function(frame) frame:SetBackdropColor(unpack(Theme.scrollbar.thumbHover)) end)
	thumb:SetScript("OnLeave", function(frame) frame:SetBackdropColor(unpack(Theme.scrollbar.thumb)) end)

	local isUpdating = false
	local scrollLogic = Widget.ScrollLogic(scrollFrame, child, track, thumb, {draggable = true})

	local baseUpdateThumb = scrollLogic.UpdateThumb
	local function UpdateThumb()
		if isUpdating or container._refreshLock then return end
		isUpdating = true
		local currentScroll = scrollFrame:GetVerticalScroll()
		local range = math.max(0, child:GetHeight() - scrollFrame:GetHeight())
		if currentScroll > range then scrollFrame:SetVerticalScroll(range) end
		baseUpdateThumb()
		isUpdating = false
	end

	container._buiScrollContainer = true

	local function FindWheelAncestor()
		local ancestor = container:GetParent()
		while ancestor do
			if ancestor._buiScrollContainer and ancestor:GetScript("OnMouseWheel") then return ancestor end
			ancestor = ancestor:GetParent()
		end
	end

	container:EnableMouseWheel(true)
	container:SetScript("OnMouseWheel", function(_, delta)
		local range = math.max(0, (child:GetHeight() or 0) - (scrollFrame:GetHeight() or 0))
		local currentScroll = scrollFrame:GetVerticalScroll() or 0
		local atEdge = (delta < 0 and currentScroll >= range - 1) or (delta > 0 and currentScroll <= 1)
		if range > 1 and not atEdge then
			scrollLogic.DoScroll(delta)
			return
		end
		local ancestor = FindWheelAncestor()
		if ancestor then ancestor:GetScript("OnMouseWheel")(ancestor, delta) else scrollLogic.DoScroll(delta) end
	end)

	scrollFrame:SetScript("OnScrollRangeChanged", UpdateThumb)
	scrollFrame:SetScript("OnSizeChanged", UpdateThumb)
	child:SetScript("OnSizeChanged", UpdateThumb)
	BUILib.Defer(UpdateThumb)

	container.scrollFrame = scrollFrame
	container.scrollChild = child
	container.child = child
	container.scrollbar = track
	container.thumb = thumb

	function container:SetChildHeight(newHeight) child:SetHeight(newHeight); BUILib.Defer(UpdateThumb) end
	function container:ScrollToTop() scrollLogic.Stop(); scrollFrame:SetVerticalScroll(0); UpdateThumb() end
	function container:ScrollToBottom() scrollLogic.Stop(); scrollFrame:SetVerticalScroll(scrollLogic.GetMax()); UpdateThumb() end
	function container:UpdateScroll() UpdateThumb() end

	function container:RefreshContentHeight()
		local lowestPoint = Layout.MeasureLowestExtent(child)
		if lowestPoint == 0 then
			local childCount = child:GetNumChildren()
			for childIndex = 1, childCount do
				local childFrame = select(childIndex, child:GetChildren())
				if childFrame and childFrame:IsShown() then
					local _, _, _, _, offsetY = childFrame:GetPoint()
					if offsetY then
						local bottomExtent = math.abs(offsetY) + (childFrame:GetHeight() or 0)
						if bottomExtent > lowestPoint then lowestPoint = bottomExtent end
					end
				end
			end
		end
		local viewportHeight = container:GetHeight() or 400
		local needsScroll = lowestPoint + 40 > viewportHeight
		child:SetHeight(needsScroll and (lowestPoint + 40) or viewportHeight)
		BUILib.Defer(UpdateThumb)
		return needsScroll
	end

	return Widget.Wrap(container)
end
