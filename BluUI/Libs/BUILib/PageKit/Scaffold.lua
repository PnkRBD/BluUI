local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Layout = BUILib.Layout
local PageKit = BUILib.PageKit

function PageKit.Scaffold(pageFrame, options)
	local width    = options.width or Layout.PAGE_CONTENT_W
	local totalHeight   = options.totalH
	local previewHeight = options.previewH

	if options.watermark then
		local mark = pageFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
		mark:SetTexture(options.watermark)
		mark:SetSize(520, 520)
		mark:SetPoint("CENTER")
		mark:SetVertexColor(1, 1, 1, 0.06)
	end

	local topY = PageKit.PAD
	local titleBar
	if options.title then
		local titleHeight
		titleHeight, titleBar = PageKit.PageTitle(pageFrame, options.title, width, {
			anchor = options.titleAnchor, enable = options.titleEnable,
			desc = options.titleDesc,
		})
		topY = topY + titleHeight
	end

	local wantBand = options.tabBand or (options.hostTabs ~= nil)
	local pinned, tabBand
	local scrollTop = topY
	if previewHeight then
		pinned = PageKit.PreviewBand(pageFrame, width, previewHeight, topY, wantBand)
		scrollTop = topY + previewHeight + PageKit.GAP
	end
	if wantBand then
		tabBand = PageKit.TabBand(pageFrame, width, scrollTop)
		scrollTop = tabBand.bottom + PageKit.GAP
	end

	if options.hostTabs then
		local hostTabs = options.hostTabs
		local groups = {}
		for _, tabDef in ipairs(hostTabs.defs) do groups[tabDef.key] = {} end
		for _, tabDef in ipairs(hostTabs.defs) do
			local host = CreateFrame("Frame", nil, pageFrame)

			host:SetPoint("TOPLEFT", pageFrame, "TOPLEFT", 0, -(tabBand.bottom + PageKit.GAP))
			host:SetPoint("BOTTOMRIGHT", pageFrame, "BOTTOMRIGHT", 0, 0)
			groups[tabDef.key][1] = host
			local page = Layout.Page(host, nil, width)
			local tab = page:GetTab(1)
			tab.topPadding = 0
			hostTabs.build(tabDef, tab)
			page:AutoRefresh()
		end
		local ApplyTab = PageKit.TabStrip(tabBand, hostTabs.defs, groups, hostTabs.defaultKey or hostTabs.defs[1].key, width, hostTabs.onSelect)
		ApplyTab()
		return nil, pinned, titleBar, tabBand, ApplyTab
	end

	local scrollWidget = Controls.ScrollFrame(pageFrame, nil, nil, totalHeight, width)
	scrollWidget.frame:ClearAllPoints()
	scrollWidget.frame:SetPoint("TOPLEFT",     pageFrame, "TOPLEFT",     0, -scrollTop)
	scrollWidget.frame:SetPoint("BOTTOMRIGHT", pageFrame, "BOTTOMRIGHT", 0, 0)
	local scrollFrame = scrollWidget.frame.scrollFrame
	local scrollChild = scrollWidget.frame.child
	scrollChild:SetHeight(totalHeight)
	scrollFrame:HookScript("OnSizeChanged", function(_, newWidth)
		if newWidth and newWidth > 0 then scrollChild:SetWidth(newWidth) end
	end)

	local root = CreateFrame("Frame", nil, scrollChild)
	root:SetSize(width, totalHeight - PageKit.PAD)
	root:SetPoint("TOP", scrollChild, "TOP", 0, 0)

	return root, pinned, titleBar, tabBand
end
