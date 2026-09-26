local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout

local RAIL_WIDTH = 210
local RAIL_GAP = 40
local HEADER_GAP = 26
local TOP_GAP = 24
local BOTTOM_GAP = 24

function Layout.RailPage(tab, shell, spec)
	local window = shell.window
	local kit = Layout.TableKit(window)
	local block = CreateFrame('Frame', nil, tab.child)
	block:SetWidth(tab.width)
	local railWidth = spec.rail.width or RAIL_WIDTH
	local contentX = railWidth + RAIL_GAP
	local contentWidth = tab.width - contentX
	local query, current = '', nil
	local panes = {}
	local page = {}

	local y = kit.Header(block, spec.icon, spec.title, spec.placeholder, function(text)
		query = text
		page:Resize()
	end)
	local top = y + HEADER_GAP
	local rule = window:Fill(block, 'rule', 'ARTWORK')
	rule:SetPoint('TOPLEFT', 0, -top)
	rule:SetPoint('TOPRIGHT', 0, -top)
	rule:SetHeight(1)
	top = top + 1 + TOP_GAP

	local rail = Layout.Rail(window, block, railWidth, {
		style = spec.rail.style,
		groups = spec.rail.groups,
		isDone = spec.rail.isDone,
		onSelect = function(item) page:Select(item.id) end,
	})
	rail.frame:SetPoint('TOPLEFT', 0, -top)
	local divider = window:Fill(block, 'rule', 'ARTWORK')
	divider:SetPoint('TOPLEFT', railWidth + math.floor(RAIL_GAP / 2), -top)
	divider:SetWidth(1)
	local content = CreateFrame('Frame', nil, block)
	content:SetPoint('TOPLEFT', contentX, -top)
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
		height = math.max(rail.height, height)
		divider:SetHeight(height)
		return top + height + BOTTOM_GAP
	end

	function page:RefreshRail()
		rail:Refresh()
	end

	function page:Resize()
		local height = Place()
		block:SetHeight(height)
		block.layoutHeight = height
		BUILib.Defer(function() tab:Refresh() end)
	end

	function page:Select(id)
		local previous = current and panes[current.id]
		if previous then previous.frame:Hide() end
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

	page:Select(rail.entries[1].item.id)
	Layout.Add(tab, block, 8)
	return page
end
