local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout

local RAIL_WIDTH = 210
local RAIL_GAP = 40
local RAIL_STEP = 40
local BLOCK_GAP = 8
local BOTTOM_GAP = 24

function Layout.RailPage(tab, shell, spec)
	local window = shell.window
	local kit = Layout.TableKit(window)
	local railWidth = spec.rail.width or RAIL_WIDTH
	local contentX = railWidth + RAIL_GAP
	local contentWidth = tab.width - contentX
	local query, current = '', nil
	local panes = {}
	local page = {}

	local block = CreateFrame('Frame', nil, tab.child)
	block:SetWidth(tab.width)
	local head, top, Align = Layout.PinnedHead(tab, window, kit, spec, block, function(text)
		query = text
		page:Resize()
	end)
	local contentTop = top + (tab.topPadding or Layout.DEFAULT_PADDING) + BLOCK_GAP

	local railScroll = CreateFrame('ScrollFrame', nil, head)
	railScroll:SetPoint('TOPLEFT', 0, -contentTop)
	railScroll:SetPoint('BOTTOM', tab.frame, 'BOTTOM', 0, 0)
	railScroll:SetWidth(railWidth)
	local railHost = CreateFrame('Frame', nil, railScroll)
	railHost:SetSize(railWidth, 1)
	railScroll:SetScrollChild(railHost)
	local rail = Layout.Rail(window, railHost, railWidth, {
		style = spec.rail.style,
		groups = spec.rail.groups,
		isDone = spec.rail.isDone,
		onSelect = function(item) page:Select(item.id) end,
	})
	rail.frame:SetPoint('TOPLEFT')
	railHost:SetHeight(rail.height)
	railScroll:EnableMouseWheel(true)
	railScroll:SetScript('OnMouseWheel', function(self, delta)
		local range = math.max(0, rail.height - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * RAIL_STEP)))
	end)

	local divider = window:Fill(head, 'rule', 'ARTWORK')
	divider:SetPoint('TOP', head, 'TOP', 0, -contentTop)
	divider:SetPoint('LEFT', head, 'LEFT', railWidth + math.floor(RAIL_GAP / 2), 0)
	divider:SetPoint('BOTTOM', tab.frame, 'BOTTOM', 0, 0)
	divider:SetWidth(1)

	local content = CreateFrame('Frame', nil, block)
	content:SetPoint('TOPLEFT', contentX, 0)
	content:SetSize(contentWidth, 1)

	local function Place()
		local height = 0
		if current then
			for _, section in ipairs(panes[current.id].sections) do
				if section.frame then
					height = section:Layout(height, query)
				else
					section:ClearAllPoints()
					section:SetPoint('TOPLEFT', 0, -height)
					height = height + section:GetHeight()
				end
			end
		end
		content:SetHeight(math.max(1, height))
		return height + BOTTOM_GAP
	end

	function page:RefreshRail()
		rail:Refresh()
	end

	function page:Resize()
		local height = Place()
		block:SetHeight(height)
		block.layoutHeight = height
		BUILib.Defer(function()
			Align()
			tab:Refresh()
		end)
	end

	function page:Select(id)
		local previous = current and panes[current.id]
		if previous then previous.frame:Hide() end
		if not current or current.id ~= id then tab.scroll:ScrollToTop() end
		current = rail.byID[id].item
		rail:Select(id)
		local pane = panes[id]
		if not pane then
			local frame = CreateFrame('Frame', nil, content)
			frame:SetAllPoints()
			pane = { frame = frame }
			panes[id] = pane
			pane.sections = spec.build(kit, shell, frame, contentWidth, current, page)
		end
		pane.frame:Show()
		self:Resize()
	end

	function page:RebuildCurrent()
		if current then self:Rebuild(current.id) end
	end

	function page:Rebuild(id)
		for paneID, pane in pairs(panes) do
			if id == nil or paneID == id then
				pane.frame:Hide()
				pane.frame:SetParent(nil)
				panes[paneID] = nil
			end
		end
		if current and (id == nil or current.id == id) then self:Select(current.id) end
	end

	page:Select(spec.rail.selected or rail.entries[1].item.id)
	Layout.Add(tab, block, BLOCK_GAP)
	Align()
	tab:Refresh()
	return page
end
