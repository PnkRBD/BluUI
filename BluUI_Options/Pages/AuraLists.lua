local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Controls, Widget = BUILib.Controls, BUILib.Widget

local INPUT_WIDTH = 260
local ERASE_SIZE = BUILib.Layout.ERASE_SIZE
local RESULTS_WIDTH = 280
local STRIP_ICON = 26
local STRIP_GAP = 4
local STRIP_MAX = 12
local DEFAULT_ICON = 134400
local ENEMIES_ONLY_TIP = 'Blizzard does not let addons hide this debuff on you or your group, so it only hides on enemies.'

local AuraLists = {}
BUI.AuraLists = AuraLists

local function Window()
	return BUI.PageEngine.window
end

local function GroupByName(ids)
	local byName, groups = {}, {}
	for _, spellID in ipairs(ids) do
		local info = C_Spell.GetSpellInfo(spellID)
		local name = info and info.name or ('Spell ' .. spellID)
		local group = byName[name]
		if not group then
			group = { name = name, ids = {}, icon = info and info.iconID or DEFAULT_ICON }
			byName[name] = group
			groups[#groups + 1] = group
		end
		group.ids[#group.ids + 1] = spellID
	end
	table.sort(groups, function(left, right) return left.name < right.name end)
	for _, group in ipairs(groups) do table.sort(group.ids) end
	return groups
end

local function Strip(ui, spells, tooltip, onPick)
	return { build = function(parent)
		local frame = CreateFrame('Frame', nil, parent)
		frame:SetSize(STRIP_MAX * (STRIP_ICON + STRIP_GAP) - STRIP_GAP, STRIP_ICON)
		local buttons = {}
		for index = 1, STRIP_MAX do
			local button = CreateFrame('Button', nil, frame)
			button:SetSize(STRIP_ICON, STRIP_ICON)
			button:SetPoint('LEFT', (index - 1) * (STRIP_ICON + STRIP_GAP), 0)
			local icon = button:CreateTexture(nil, 'ARTWORK')
			icon:SetAllPoints()
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			button.icon = icon
			local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
			highlight:SetAllPoints()
			highlight:SetColorTexture(1, 1, 1, 0.25)
			button:SetScript('OnClick', function(self)
				GameTooltip:Hide()
				onPick(self.spellID)
			end)
			button:SetScript('OnEnter', function(self)
				GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
				GameTooltip:SetSpellByID(self.spellID)
				GameTooltip:AddLine('Spell ' .. self.spellID, 0.5, 0.5, 0.5)
				GameTooltip:AddLine(tooltip, 1, 0.82, 0)
				GameTooltip:Show()
			end)
			button:SetScript('OnLeave', function() GameTooltip:Hide() end)
			button:Hide()
			buttons[index] = button
		end
		local function Fill()
			local ids = spells()
			for index, button in ipairs(buttons) do
				local spellID = ids[index]
				button.spellID = spellID
				if spellID then
					local info = C_Spell.GetSpellInfo(spellID)
					button.icon:SetTexture(info and info.iconID or DEFAULT_ICON)
				end
				button:SetShown(spellID ~= nil)
			end
		end
		frame:SetScript('OnShow', Fill)
		Fill()
		return frame
	end }
end

local function Search(anchor, text, Add)
	local spellID = BUI.ResolveSpellInput(text)
	if spellID then return Add(spellID) end
	local hits = BUI.Lookup.SearchSpells(text)
	if #hits == 1 then return Add(hits[1].id) end
	local menu = {}
	for _, hit in ipairs(hits) do
		menu[#menu + 1] = { text = hit.name, icon = hit.icon, callback = function() Add(hit.id) end }
	end
	if #menu == 0 then menu[1] = { text = 'Nothing found', disabled = true } end
	Controls.ContextMenu(menu, { anchor = anchor, width = RESULTS_WIDTH, window = Window() })
end

local function AddRow(ui, board, Add)
	local row = board:AddRow('Add a spell', 'Name, ID or spell link, then press Enter', INPUT_WIDTH)
	local box
	box = ui.Input(row, INPUT_WIDTH, { placeholder = 'Search...', get = function() return '' end, set = function(text) Search(box, text, Add) end })
	box:SetPoint('RIGHT', -ui.ROW_INSET, 0)
end

local function SpellRow(board, icon, name, sub, tooltip, onRemove)
	return board:AddTools(name, sub, {
		{ slot = 'erase', icon = 'erase', size = ERASE_SIZE, hover = 'danger', tooltip = tooltip, onClick = onRemove },
	}, nil, icon)
end

function AuraLists.Blacklist(ui, parent, width, page, options)
	local AB = BUI.AuraBlacklist
	local scope, polarity = options.scope, options.polarity
	local board = ui.Board(parent, width, {
		stacked = true,
		title = options.title,
		description = options.description,
	})
	local function Changed()
		AB.RefreshConsumers(scope)
		if options.onChange then options.onChange() end
		page:RebuildCurrent()
	end
	local function Add(spellID)
		local set = scope == 'group' and AB.GroupSet(polarity) or AB.UnitSet(polarity)
		if set[spellID] then return end
		AB.UserAdd(scope, polarity, spellID)
		if not AB.HidesOnFriendly(spellID, polarity) then
			BUI.Print((C_Spell.GetSpellName(spellID) or ('Spell ' .. spellID)) .. ': ' .. ENEMIES_ONLY_TIP)
		end
		Changed()
	end
	AddRow(ui, board, Add)
	if AB.RecentEntries(scope, polarity)[1] then
		board:AddTools('Recently seen', 'Click one to blacklist it', { Strip(ui, function() return AB.RecentEntries(scope, polarity) end, 'Click to blacklist', Add) })
	end

	local entries = {}
	for _, group in ipairs(GroupByName(AB.UserEntries(scope, polarity))) do entries[#entries + 1] = group end
	local showsBuiltIns = AB.ShowsBuiltIns(scope, polarity)
	local active, disabled = {}, {}
	if showsBuiltIns then
		for _, entry in ipairs(AB.BuiltInEntries(polarity)) do
			if entry.hidden then active[#active + 1] = entry.id else disabled[#disabled + 1] = entry.id end
		end
		for _, group in ipairs(GroupByName(active)) do
			group.builtin = true
			entries[#entries + 1] = group
		end
		table.sort(entries, function(left, right) return left.name < right.name end)
	end
	for _, group in ipairs(entries) do
		local enemiesOnly = false
		for _, spellID in ipairs(group.ids) do
			if not AB.HidesOnFriendly(spellID, polarity) then enemiesOnly = true end
		end
		local name = #group.ids > 1 and (group.name .. ', ' .. #group.ids .. ' spells') or group.name
		local sub = 'Spell ' .. table.concat(group.ids, ', ')
		if group.builtin then sub = sub .. ', built in' end
		if enemiesOnly then sub = sub .. ', enemies only' end
		local row = SpellRow(board, group.icon, name, sub, group.builtin and 'Turn this built-in off' or 'Remove ' .. group.name, function()
			for _, spellID in ipairs(group.ids) do
				if group.builtin then AB.SetBuiltInHidden(polarity, spellID, false) else AB.UserRemove(scope, polarity, spellID) end
			end
			Changed()
		end)
		if enemiesOnly then
			row:EnableMouse(true)
			row:SetScript('OnEnter', function(self) Widget.ShowTip(self, ENEMIES_ONLY_TIP) end)
			row:SetScript('OnLeave', Widget.HideTip)
		end
	end
	if #entries == 0 then board:AddRow('Nothing blacklisted', 'Every aura shows') end
	if disabled[1] then
		local groups = GroupByName(disabled)
		local ids = {}
		for index, group in ipairs(groups) do ids[index] = group.ids[1] end
		board:AddTools('Built-ins turned off', 'Click one to turn it back on', { Strip(ui, function() return ids end, 'Click to turn it back on', function(spellID)
			for _, group in ipairs(groups) do
				if group.ids[1] == spellID then
					for _, id in ipairs(group.ids) do AB.SetBuiltInHidden(polarity, id, true) end
				end
			end
			Changed()
		end) })
	end
	return board
end

function AuraLists.Pinned(ui, parent, width, page, options)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = options.title,
		description = options.description,
	})
	local list = options.get()
	local function Changed()
		options.onChange()
		page:RebuildCurrent()
	end
	if options.only then
		board:AddSwitch(options.only.label, options.only.get, function(value)
			options.only.set(value)
			options.onChange()
		end, options.only.tip)
	end
	AddRow(ui, board, function(spellID)
		if list[spellID] then return end
		list[spellID] = true
		Changed()
	end)
	local items = BUI.SpellListItems(list)
	for _, item in ipairs(items) do
		SpellRow(board, item.icon or DEFAULT_ICON, item.name, 'Spell ' .. item.id, 'Unpin ' .. item.name, function()
			list[item.id] = nil
			Changed()
		end)
	end
	if #items == 0 then board:AddRow('Nothing pinned', 'Only the rules decide what shows') end
	return board
end

function AuraLists.ShareCell(board, label)
	local AB = BUI.AuraBlacklist
	board:AddSwitch(label, AB.IsShared, function(value)
		AB.SetShared(value)
		AB.RefreshConsumers()
		BUILib.Defer(function() BUI.PageEngine.RebuildAllPages() end)
	end, 'Both frame modules use one combined blacklist')
end

function BUI.AuraRuleEditor(parent, options)
	local AuraRules = BUI.AuraRules
	local kit = BUILib.Layout.TableKit(Window())
	local button
	button = kit.Button(parent, 'Priority rules', 'secondary', function()
		local rules = options.getRules()
		local function Push()
			if options.onChanged then options.onChanged() end
		end
		Controls.Popover({
			anchor = button, width = 320, height = 254, title = 'PRIORITY RULES, TOP WINS',
			build = function(panel)
				local list
				local function Fill()
					list:ClearItems()
					for _, id in ipairs(rules) do
						list:AddItem(AuraRules.Icon(id), AuraRules.Label(id), id, true)
					end
				end
				list = Controls.ItemList(panel, nil, panel.width, 176,
					nil,
					function(row)
						for ruleIndex = 1, #rules do
							if rules[ruleIndex] == row.id then table.remove(rules, ruleIndex); break end
						end
						if #rules == 0 then BUI.Print('No rules left, this container shows nothing.') end
						Push()
					end,
					nil, nil,
					true,
					function(data)
						for ruleIndex = #rules, 1, -1 do rules[ruleIndex] = nil end
						for dataIndex = 1, #data do rules[dataIndex] = data[dataIndex].id end
						Push()
					end,
					true,
					{})
				list:SetPoint('TOPLEFT', 0, -34)
				Fill()
				local addDropdown = Controls.Dropdown(panel, nil, AuraRules.DropdownItems(options.polarity, nil, options.unitFramesOnly), nil, function(value)
					for ruleIndex = 1, #rules do
						if rules[ruleIndex] == value then return end
					end
					rules[#rules + 1] = value
					Fill()
					Push()
				end, 'Add a rule', panel.width)
				local addFrame = Widget.Unwrap(addDropdown)
				addFrame:ClearAllPoints()
				addFrame:SetPoint('TOPLEFT', 0, 0)
			end,
		})
	end)
	local tip = options.tooltip or 'Pick which auras show here, the top rule claims icon slots first'
	button:HookScript('OnEnter', function(self) Widget.ShowTip(self, tip) end)
	button:HookScript('OnLeave', Widget.HideTip)
	return button
end

function AuraLists.Rules(options)
	return { build = function(parent) return Widget.Unwrap(BUI.AuraRuleEditor(parent, options)) end }
end
