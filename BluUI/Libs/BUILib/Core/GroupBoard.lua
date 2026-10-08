local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Layout = BUILib.Layout
local Modals = BUILib.Modals

local TINTS = {
	{ 0.35, 0.6, 1 },
	{ 0.4, 0.9, 0.5 },
	{ 1, 0.65, 0.25 },
	{ 0.8, 0.45, 1 },
	{ 1, 0.4, 0.5 },
	{ 0.3, 0.85, 0.85 },
	{ 0.95, 0.85, 0.3 },
}

local function Tint(index)
	local tint = TINTS[(index - 1) % #TINTS + 1]
	return { tint[1], tint[2], tint[3] }
end

local function Members(group, items)
	local members = {}
	for _, id in ipairs(group.members) do members[#members + 1] = items[id] end
	return members
end

local function MemberText(group, items, noun)
	local count = #Members(group, items)
	if count == 0 then return 'Empty' end
	return count == 1 and ('1 ' .. noun[1]) or (count .. ' ' .. noun[2])
end

local function GroupSwitch(group, items)
	return {
		get = function()
			local members = Members(group, items)
			for _, item in ipairs(members) do
				if not item.switch.get() then return false end
			end
			return #members > 0
		end,
		set = function(value)
			for _, item in ipairs(Members(group, items)) do
				if item.switch.get() ~= value then
					item.switch.set(value)
					item.after()
				end
			end
		end,
	}
end

local function GroupCount(layout)
	local count = 0
	for _, node in ipairs(layout.nodes) do
		if type(node) == 'table' then count = count + 1 end
	end
	return count
end

local function Arrange(layout, items, order)
	local entries, placed = {}, {}
	local function Place(id, group)
		if not items[id] or placed[id] then return end
		placed[id] = true
		entries[#entries + 1] = { item = items[id], group = group }
	end
	for _, node in ipairs(layout.nodes) do
		if type(node) == 'table' then
			entries[#entries + 1] = { header = node }
			for _, id in ipairs(node.members) do Place(id, node) end
		else
			Place(node)
		end
	end
	for _, item in ipairs(order) do Place(item.id) end
	return entries
end

local function Save(layout, board, nodeOf)
	local nodes = {}
	for _, frame in ipairs(board:DragRows()) do
		local node = nodeOf[frame]
		if frame.dragGroup then
			local members = nodeOf[frame.dragGroup].members
			members[#members + 1] = node
		else
			if type(node) == 'table' then node.members = {} end
			nodes[#nodes + 1] = node
		end
	end
	layout.nodes = nodes
end

local function Ungroup(layout, group)
	local nodes = {}
	for _, node in ipairs(layout.nodes) do
		if node == group then
			for _, id in ipairs(group.members) do nodes[#nodes + 1] = id end
		else
			nodes[#nodes + 1] = node
		end
	end
	layout.nodes = nodes
end

local function RowTools(item)
	local tools = {}
	for index, tool in ipairs(item.tools) do tools[index] = tool end
	tools[#tools + 1] = item.switch
	return tools
end

local function DeleteMessage(group, count, noun)
	if count == 1 then
		return ('Delete "%s"? Its %s stays where it is, just out of the group.'):format(group.name, noun[1])
	end
	return ('Delete "%s"? Its %d %s stay where they are, just out of the group.'):format(group.name, count, noun[2])
end

Layout.TableKitExtensions[#Layout.TableKitExtensions + 1] = function(kit, window)
	local function Repaint() window:Repaint() end

	function kit.GroupBoard(parent, width, spec)
		local layout, noun = spec.layout, spec.noun
		local items = {}
		for _, item in ipairs(spec.items) do items[item.id] = item end
		local nodeOf, headers = {}, {}
		local board

		local function Delete(group)
			Ungroup(layout, group)
			spec.rebuild()
		end

		local function ConfirmDelete(group)
			local count = #Members(group, items)
			if count == 0 then
				Delete(group)
				return
			end
			Modals.Confirm({
				parent = window.frame,
				title = 'Delete ' .. group.name,
				message = DeleteMessage(group, count, noun),
				confirmText = 'Delete', cancelText = 'Cancel',
				onConfirm = function() Delete(group) end,
			})
		end

		local function Header(group, index)
			group.tint = group.tint or Tint(index)
			local row, title, count = board:AddDragHeader(group.name, MemberText(group, items, noun), {
				{ kind = 'swatch', label = 'Color', tooltip = 'Group color', slot = 'settings', get = function() return unpack(group.tint) end, set = function(red, green, blue) group.tint = { red, green, blue } end },
				{ icon = 'text', tooltip = 'Rename', title = 'Group', slot = 'position', options = {
					{ label = 'Name', kind = 'input', placeholder = 'Group name', get = function() return group.name end, set = function(text)
						if text ~= '' then group.name = text end
					end },
				} },
				{ icon = 'erase', size = Layout.ERASE_SIZE, tooltip = 'Delete the group', hover = 'danger', slot = 'toggle', onClick = function() ConfirmDelete(group) end },
				GroupSwitch(group, items),
			}, Repaint, function() return group.collapsed == true end, function()
				group.collapsed = not group.collapsed or nil
				spec.resize()
			end, function() return unpack(group.tint) end)
			kit.Bind(title, function() title:SetText(group.name) end)
			kit.Bind(count, function() count:SetText(MemberText(group, items, noun)) end)
			return row
		end

		local function NewGroup()
			Save(layout, board, nodeOf)
			local count = GroupCount(layout)
			table.insert(layout.nodes, 1, { name = 'Group ' .. (count + 1), members = {}, tint = Tint(count + 1) })
			spec.rebuild()
		end

		board = kit.Board(parent, width, {
			stacked = true,
			title = spec.title,
			description = spec.description,
			buttons = { { text = 'New group', onClick = NewGroup } },
		})
		board:DragList(spec.resize, function()
			Save(layout, board, nodeOf)
			spec.resize()
			Repaint()
		end)
		local groupIndex = 0
		for _, entry in ipairs(Arrange(layout, items, spec.items)) do
			if entry.header then
				groupIndex = groupIndex + 1
				local header = Header(entry.header, groupIndex)
				headers[entry.header] = header
				nodeOf[header] = entry.header
			else
				local item = entry.item
				nodeOf[board:AddDragTools(item.name, item.sub, item.icon, RowTools(item), item.after, headers[entry.group])] = item.id
			end
		end
		return board
	end
end
