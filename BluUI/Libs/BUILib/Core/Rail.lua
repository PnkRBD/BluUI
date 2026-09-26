local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Widget = BUILib.Widget

local GROUP_GAP = 22
local CAPTION_HEIGHT = 24
local ITEM_HEIGHT = 36
local ITEM_GAP = 2
local ITEM_INSET = 14
local ICON_SIZE = 13
local LABEL_X = 38
local COUNT_WIDTH = 56
local ACCENT_BAR = 2
local STEP_HEIGHT = 50
local STEP_DISC = 24
local STEP_LABEL_X = 42

local Rail = {}
Rail.__index = Rail

local function ListButton(window, kit, parent, item, width)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(width, ITEM_HEIGHT)
	local fill = window:Fill(button, 'panel')
	fill:SetAllPoints()
	local bar = window:Fill(button, 'accent', 'BACKGROUND', 2)
	bar:SetPoint('TOPLEFT')
	bar:SetPoint('BOTTOMLEFT')
	bar:SetWidth(ACCENT_BAR)
	kit.Hover(button)

	local textX = ITEM_INSET
	if item.icon then
		button.icon = kit.Glyph(button, item.icon, ICON_SIZE, 'muted')
		button.icon:SetPoint('LEFT', ITEM_INSET, 0)
		textX = LABEL_X
	end
	button.label = kit.Text(button, item.label, 12, 'muted')
	button.label:SetPoint('LEFT', textX, 0)
	button.label:SetWidth(width - textX - (item.count and COUNT_WIDTH or ITEM_INSET))
	button.label:SetWordWrap(false)
	button.count = kit.Text(button, '', 11, 'faint')
	button.count:SetPoint('RIGHT', -ITEM_INSET, 0)
	if item.disabled then button:EnableMouse(false) end

	function button:SetState(selected, count)
		fill:SetShown(selected)
		bar:SetShown(selected)
		local role = selected and 'text' or (item.disabled and 'faint' or 'muted')
		window:Paint(self.label, role)
		if self.icon then window:Paint(self.icon, role) end
		self.count:SetText(count and tostring(count) or '')
	end
	return button
end

local function StepButton(window, kit, parent, item, index, width)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(width, STEP_HEIGHT)
	kit.Hover(button)
	button.disc = kit.Disc(button, STEP_DISC, 'secondary', 'ARTWORK', 1)
	button.disc:SetPoint('LEFT', ITEM_INSET, 0)
	button.number = kit.Text(button, tostring(index), 11, 'secondaryText')
	button.number:SetPoint('CENTER', button.disc)
	button.check = kit.Glyph(button, 'check', 11, 'onAccent', 'OVERLAY')
	button.check:SetPoint('CENTER', button.disc)
	button.label = kit.Text(button, item.label, 12, 'muted')
	button.label:SetPoint('TOPLEFT', STEP_LABEL_X, -(item.sub and 9 or 18))
	if item.sub then
		button.sub = kit.Text(button, item.sub, 11, 'faint')
		button.sub:SetPoint('TOPLEFT', STEP_LABEL_X, -26)
	end

	function button:SetState(state)
		window:Paint(self.disc, state == 'todo' and 'secondary' or 'accent')
		window:Paint(self.number, state == 'current' and 'onAccent' or 'secondaryText')
		self.number:SetShown(state ~= 'done')
		self.check:SetShown(state == 'done')
		window:Paint(self.label, state == 'current' and 'text' or (state == 'done' and 'muted' or 'faint'))
	end
	return button
end

function Rail:Click(item)
	if self.steps and not (self.spec.isDone(item) or item == self.current) then return end
	self.spec.onSelect(item)
end

function Rail:Select(id)
	local entry = self.byID[id]
	self.current = entry and entry.item
	self:Refresh()
end

function Rail:Refresh()
	for _, entry in ipairs(self.entries) do
		local item = entry.item
		if self.steps then
			entry.button:SetState(item == self.current and 'current' or (self.spec.isDone(item) and 'done' or 'todo'))
		else
			local count = item.count
			if type(count) == 'function' then count = count() end
			entry.button:SetState(item == self.current, count)
		end
	end
	if self.steps and self.current then self.progress:SetPoint('BOTTOM', self.byID[self.current.id].button.disc, 'CENTER') end
end

function Layout.Rail(window, parent, width, spec)
	local kit = Layout.TableKit(window)
	local frame = CreateFrame('Frame', nil, parent)
	frame:SetWidth(width)
	local rail = setmetatable({ window = window, frame = frame, spec = spec, entries = {}, byID = {}, steps = spec.style == 'steps' }, Rail)

	if rail.steps then
		rail.line = window:Fill(frame, 'rule', 'ARTWORK', 0)
		rail.line:SetWidth(1)
		rail.progress = window:Fill(frame, 'accent', 'ARTWORK', 1)
		rail.progress:SetWidth(1)
	end

	local y = 0
	for _, group in ipairs(spec.groups) do
		if group.title then
			kit.Text(frame, group.title:upper(), 9, 'faint'):SetPoint('TOPLEFT', ITEM_INSET, -(y + 4))
			y = y + CAPTION_HEIGHT
		end
		for _, item in ipairs(group.items) do
			local index = #rail.entries + 1
			local button = rail.steps and StepButton(window, kit, frame, item, index, width) or ListButton(window, kit, frame, item, width)
			button:SetPoint('TOPLEFT', 0, -y)
			button:SetScript('OnClick', function() rail:Click(item) end)
			local entry = { item = item, button = button }
			rail.entries[index] = entry
			rail.byID[item.id] = entry
			y = y + button:GetHeight() + ITEM_GAP
		end
		y = y - ITEM_GAP + GROUP_GAP
	end
	rail.height = math.max(1, y - GROUP_GAP)
	frame:SetHeight(rail.height)

	if rail.steps and rail.entries[1] then
		rail.line:SetPoint('TOP', rail.entries[1].button.disc, 'CENTER')
		rail.line:SetPoint('BOTTOM', rail.entries[#rail.entries].button.disc, 'CENTER')
		rail.progress:SetPoint('TOP', rail.entries[1].button.disc, 'CENTER')
	end
	rail:Refresh()
	return rail
end

local function NavGroups(navConfig)
	local groups, placed, indexOf = {}, {}, {}
	for index, pageID in ipairs(navConfig.pageOrder) do indexOf[pageID] = index end
	local function Item(pageID)
		local page = navConfig.pages[pageID]
		placed[pageID] = true
		return { id = pageID, index = indexOf[pageID], label = Widget.StripColorCodes(page.buttonText or page.title or pageID), icon = page.icon, count = page.count, disabled = page.disabled }
	end
	for _, section in ipairs(navConfig.sections or {}) do
		local items = {}
		for _, pageID in ipairs(section.ids) do
			if navConfig.pages[pageID] and indexOf[pageID] then items[#items + 1] = Item(pageID) end
		end
		groups[#groups + 1] = { title = Widget.StripColorCodes(section.header), items = items }
	end
	local rest = {}
	for _, pageID in ipairs(navConfig.pageOrder) do
		if not placed[pageID] and not navConfig.pages[pageID].hidden then rest[#rest + 1] = Item(pageID) end
	end
	if #rest > 0 then groups[#groups + 1] = { items = rest } end
	return groups
end

function Layout.NavRail(window, parent, width, navConfig)
	local rail = Layout.Rail(window, parent, width, { groups = NavGroups(navConfig), onSelect = function(item) navConfig.showPage(item.index) end })
	local buttons = {}
	for _, entry in ipairs(rail.entries) do
		local item = entry.item
		function entry.button:SetSelected(isSelected)
			if isSelected then rail:Select(item.id) end
		end
		buttons[item.index] = entry.button
	end
	return rail, buttons
end
