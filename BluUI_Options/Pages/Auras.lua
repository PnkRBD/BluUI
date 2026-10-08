local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout = BUILib.Layout

local PAGE_WIDTH = 960
local MENU_WIDTH = 150
local SPECS_WIDTH = 220

local STYLES = {
	{ value = 'cross', text = 'Cross' },
	{ value = 'dot', text = 'Dot' },
}

local LOW_HP_FIELDS = {
	posX = 'lowHpPosX', posY = 'lowHpPosY',
	anchorFrame = 'lowHpAnchorFrame', anchorPoint = 'lowHpAnchorPoint',
	anchorOffsetX = 'lowHpAnchorOffsetX', anchorOffsetY = 'lowHpAnchorOffsetY',
	centerHorizontally = 'lowHpCenterHorizontally',
}

local fonts, sounds

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local relock = { SetValue = Repaint }

local function Option(db, label, key, extra)
	local option = { label = label, get = function() return db[key] end, set = function(value) db[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Flag(holder, label)
	return { label = label, get = function() return holder.enabled == true end, set = function(value) holder.enabled = value end }
end

local function Font(db, key)
	return { entries = fonts, width = MENU_WIDTH, get = function() return db[key] end, set = function(value) db[key] = value end }
end

local function TextTool(options)
	return { icon = 'text', tooltip = 'Text', title = 'Text', options = options }
end

local function Eye(tooltip, get, set)
	return { icon = 'eye', tooltip = tooltip, get = get, set = set }
end

local function Switch(db, key)
	return { get = function() return db[key] == true end, set = function(value) db[key] = value end }
end

local function TableColor(db, label, key, opacity)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = opacity,
		get = function()
			local color = db[key]
			return color.r, color.g, color.b, opacity and color.a or 1
		end,
		set = function(red, green, blue, alpha)
			db[key] = opacity and { r = red, g = green, b = blue, a = alpha } or { r = red, g = green, b = blue }
		end,
	}
end

local function ArrayColor(db, label, key, opacity)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = opacity,
		get = function()
			local color = db[key]
			return color[1], color[2], color[3], opacity and color[4] or 1
		end,
		set = function(red, green, blue, alpha)
			db[key] = opacity and { red, green, blue, alpha } or { red, green, blue }
		end,
	}
end

local function ChannelColor(db, label, alphaKey)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = alphaKey ~= nil,
		get = function() return db.colorR, db.colorG, db.colorB, alphaKey and db[alphaKey] or 1 end,
		set = function(red, green, blue, alpha)
			db.colorR, db.colorG, db.colorB = red, green, blue
			if alphaKey then db[alphaKey] = alpha end
		end,
	}
end

local function CombatTimerRow()
	local db = BUI.GetDB().combatTimer
	local CombatTimer = BUI.CombatTimer
	CombatTimer._lockToggle = relock
	return {
		id = 'combatTimer', name = 'Combat Timer', sub = 'How long you have been in combat', after = CombatTimer.ApplySettings,
		switch = { get = function() return db.enabled == true end, set = CombatTimer.Toggle },
		tools = {
			ChannelColor(db, 'Text color'),
			Font(db, 'font'),
			TextTool({ Option(db, 'Font size', 'fontSize', { min = 10, max = 40, step = 1 }) }),
			{ tooltip = 'Readout', title = 'Combat timer', options = {
				Option(db, 'Milliseconds', 'showMilliseconds'),
			} },
			BUI.PositionTool(db, { selfTag = 'BUI_CombatTimer' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) CombatTimer.SetLocked(not value) end),
		},
	}
end

local function CombatMessagesRow()
	local db = BUI.GetDB().combatMessage
	local CombatMessage = BUI.CombatMessage
	CombatMessage._lockToggle = relock
	return {
		id = 'combatMessage', name = 'Combat Messages', sub = 'Text when combat starts and ends', after = CombatMessage.Refresh,
		switch = { get = function() return db.enabled == true end, set = function(value)
			db.enabled = value
			if value then CombatMessage.Enable() else CombatMessage.Disable() end
		end },
		tools = {
			ArrayColor(db, 'Enter combat', 'enterColor', true),
			ArrayColor(db, 'Leave combat', 'leaveColor', true),
			Font(db, 'font'),
			TextTool({ Option(db, 'Font size', 'fontSize', { min = 10, max = 40, step = 1 }) }),
			{ tooltip = 'Timing', title = 'Messages', options = {
				Option(db, 'Fade time', 'fadeTime', { min = 0.2, max = 3, step = 0.1 }),
			} },
			BUI.PositionTool(db, { selfTag = 'BUI_CombatMessage' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) CombatMessage.SetLocked(not value) end),
		},
	}
end

local function SecondaryStatsRow()
	local db = BUI.GetDB().secondaryStats
	local SecondaryStats = BUI.Auras.SecondaryStats
	SecondaryStats.SetLockListener(Repaint)
	return {
		id = 'secondaryStats', name = 'Secondary Stats', sub = 'Your stats on screen', after = SecondaryStats.Refresh,
		switch = Switch(db, 'enabled'),
		tools = {
			{ icon = 'cog', tooltip = 'Open the Secondary Stats page', onClick = function() BUI.PageEngine.NavigateToID('secondaryStats') end },
			BUI.PositionTool(db, { selfTag = 'BUI_SecondaryStats' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) SecondaryStats.SetLocked(not value) end),
		},
	}
end

local function KeystoneReminderRow()
	local db = BUI.GetDB().keystoneReminder
	local KeystoneReminder = BUI.Auras.KeystoneReminder
	KeystoneReminder.SetLockListener(Repaint)
	return {
		id = 'keystoneReminder', name = 'Keystone Reminder', sub = 'Dungeon and teleport when you join a key', after = KeystoneReminder.Refresh,
		switch = { get = function() return db.enabled == true end, set = function(value)
			db.enabled = value
			if value then KeystoneReminder.Enable() else KeystoneReminder.Disable() end
		end },
		tools = {
			BUI.PositionTool(db, { selfTag = 'BUI_KeystoneReminder' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) KeystoneReminder.SetLocked(not value) end),
		},
	}
end

local function PrivateWarningRow()
	local db = BUI.GetDB().privateWarning
	local PrivateWarning = BUI.Auras.PrivateWarning
	PrivateWarning.SetLockListener(Repaint)
	return {
		id = 'privateWarning', name = 'Private raid warning', sub = "Moves Blizzard's private boss warnings", after = PrivateWarning.Refresh,
		switch = Switch(db, 'enabled'),
		tools = {
			BUI.PositionTool(db),
			{ icon = 'resize', tooltip = 'Scale', title = 'Private raid warning', options = { Option(db, 'Scale', 'scale', { min = 50, max = 200, step = 5 }) } },
			Eye('Preview, drag to move', function() return not db.locked end, function(value) PrivateWarning.SetLocked(not value) end),
		},
	}
end

local function LowHpRow()
	local db = BUI.GetDB().auras
	local Auras = BUI.Auras
	Auras._lowHpLockToggle = relock
	return {
		id = 'lowHp', name = 'Low HP Warning', sub = 'Text when your health is low', after = Auras.UpdateLowHp,
		switch = Switch(db, 'lowHpWarning'),
		tools = {
			TableColor(db, 'Text color', 'lowHpColor', true),
			Font(db, 'lowHpFont'),
			TextTool({
				Option(db, 'Warning text', 'lowHpText', { kind = 'input', placeholder = 'Warning text' }),
				Option(db, 'Font size', 'lowHpFontSize', { min = 10, max = 60, step = 1 }),
			}),
			{ tooltip = 'Threshold', title = 'Low HP warning', options = {
				Option(db, 'Threshold %', 'lowHpThreshold', { min = 5, max = 95, step = 5 }),
			} },
			BUI.PositionTool(db, { selfTag = 'BUI_LowHpWarning', fields = LOW_HP_FIELDS }),
			Eye('Preview, drag to move', function() return db.lowHpLocked == false end, function(value)
				db.lowHpLocked = not value
				Auras.UpdateLowHp()
			end),
		},
	}
end

local function PetWarningsRow()
	local db = BUI.GetDB().auras
	local Auras = BUI.Auras
	Auras._lockToggle = relock
	return {
		id = 'petWarnings', name = 'Pet Warnings', sub = 'Dead, missing, idle or hurt pet', after = Auras.Update,
		switch = Switch(db, 'petWarningsEnabled'),
		tools = {
			TableColor(db, 'Warning color', 'warningColor', true),
			Font(db, 'font'),
			TextTool({ Option(db, 'Font size', 'fontSize', { min = 14, max = 48, step = 1 }) }),
			{ tooltip = 'Warning types', title = 'Pet warnings', options = {
				Flag(db.petAttackWarning, 'Pet not attacking'),
				Flag(db.petDeadWarning, 'Pet dead or missing'),
				Flag(db.grimoireSacrificeWarning, 'Grimoire of Sacrifice'),
				Flag(db.playDeadWarning, 'Playing dead'),
				Flag(db.petHealthWarning, 'Pet low health'),
				{ label = 'Low health %', min = 10, max = 80, step = 5, get = function() return db.petHealthWarning.threshold end, set = function(value) db.petHealthWarning.threshold = value end },
			} },
			BUI.PositionTool(db, { selfTag = 'BUI_PetWarning' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) Auras.SetLocked(not value) end),
		},
	}
end

local function GatewayRow()
	local db = BUI.GetDB().gatewayAlert
	local Display = BUI.BuffTracking.Display
	local function Apply()
		local tracker = Display.GetTracker('gatewayAlert')
		if tracker then tracker.Refresh() end
	end
	Display.RegisterAnchorCallback('gatewayAlert', Repaint)
	return {
		id = 'gatewayAlert', name = 'Gateway Alert', sub = 'Text when a Demonic Gateway is in reach', after = Apply,
		switch = Switch(db, 'enabled'),
		tools = {
			TableColor(db, 'Text color', 'textColor', true),
			Font(db, 'font'),
			TextTool({
				Option(db, 'Text', 'customText', { kind = 'input', placeholder = 'Alert text' }),
				Option(db, 'Font size', 'textSize', { min = 10, max = 48, step = 1 }),
			}),
			{ icon = 'sound', tooltip = 'Sound', title = 'Gateway alert', options = {
				{ label = 'Sound', entries = sounds, get = function() return db.sound end, set = function(value)
					db.sound = value
					BUI.PlaySoundByName(value)
				end },
			} },
			BUI.PositionTool(db, { selfTag = 'BUI_GatewayAlert' }),
			Eye('Unlock, drag to move', function() return db.showAnchor == true end, function(value)
				db.showAnchor = value
				Apply()
			end),
		},
	}
end

local function BloodlustRow()
	local db = BUI.GetDB().bloodlust
	local Bloodlust = BUI.Bloodlust
	Bloodlust.onPreviewStop = Repaint
	return {
		id = 'bloodlust', name = 'Bloodlust', sub = 'Lust timers and alerts', after = Bloodlust.Refresh,
		switch = Switch(db, 'enabled'),
		tools = {
			Font(db, 'font'),
			TextTool({ Option(db, 'Font size', 'fontSize', { min = 8, max = 48, step = 1 }) }),
			{ icon = 'cog', tooltip = 'Open the Bloodlust page', onClick = function() BUI.PageEngine.NavigateToID('bloodlust') end },
			BUI.PositionTool(db),
			Eye('Preview the alerts', Bloodlust.IsPreviewing, function(value)
				if value then Bloodlust.StartPreview() else Bloodlust.StopPreview() end
			end),
		},
	}
end

local function CDAnnouncerRow()
	local db = BUI.GetDB().cdAnnouncer
	local CDAnnouncer = BUI.CDAnnouncer
	CDAnnouncer.RegisterAnchorCallback(Repaint)
	return {
		id = 'cdAnnouncer', name = 'Cooldown Announcer', sub = 'Countdowns for cooldowns you pick', after = CDAnnouncer.Refresh,
		switch = Switch(db, 'enabled'),
		tools = {
			{ icon = 'cog', tooltip = 'Open the Cooldown Announcer page', onClick = function() BUI.PageEngine.NavigateToID('cdAnnouncer') end },
			Eye('Unlock the anchor to drag it, right-click it to lock', function() return db.showAnchor == true end, function(value)
				db.showAnchor = value
				CDAnnouncer.Refresh()
			end),
		},
	}
end

local function CooldownFlashRow()
	local db = BUI.GetDB().cooldownFlash
	local CooldownFlash = BUI.CooldownFlash
	CooldownFlash.RegisterAnchorCallback(Repaint)
	return {
		id = 'cooldownFlash', name = 'Cooldown Flash', sub = 'Flashes spells as they come off cooldown', after = CooldownFlash.Refresh,
		switch = Switch(db, 'enabled'),
		tools = {
			{ icon = 'cog', tooltip = 'Open the Cooldown Flash page', onClick = function() BUI.PageEngine.NavigateToID('cooldownFlash') end },
			BUI.PositionTool(db, { selfTag = 'BUI_CooldownFlash' }),
			Eye('Unlock to drag the icons, right-click them to lock', function() return db.showAnchor == true end, function(value)
				db.showAnchor = value
				CooldownFlash.Refresh()
			end),
		},
	}
end

local ROWS = {
	CombatTimerRow, CombatMessagesRow, SecondaryStatsRow, KeystoneReminderRow, PrivateWarningRow,
	LowHpRow, PetWarningsRow, GatewayRow, BloodlustRow, CDAnnouncerRow, CooldownFlashRow,
}

local function Members(group, specs)
	local members = {}
	for _, id in ipairs(group.members) do members[#members + 1] = specs[id] end
	return members
end

local function MemberCount(group, specs)
	local count = #Members(group, specs)
	if count == 0 then return 'Empty' end
	return count == 1 and '1 aura' or (count .. ' auras')
end

local function GroupSwitch(group, specs)
	return {
		get = function()
			local members = Members(group, specs)
			for _, spec in ipairs(members) do
				if not spec.switch.get() then return false end
			end
			return #members > 0
		end,
		set = function(value)
			for _, spec in ipairs(Members(group, specs)) do
				if spec.switch.get() ~= value then
					spec.switch.set(value)
					spec.after()
				end
			end
		end,
	}
end

local function DeleteGroup(layout, group)
	local nodes = {}
	for _, node in ipairs(layout.nodes) do
		if node == group then
			for _, id in ipairs(group.members) do nodes[#nodes + 1] = id end
		else
			nodes[#nodes + 1] = node
		end
	end
	layout.nodes = nodes
	BUI.PageEngine.RefreshCurrentPage()
end

local function GroupCount(layout)
	local count = 0
	for _, node in ipairs(layout.nodes) do
		if type(node) == 'table' then count = count + 1 end
	end
	return count
end

local function Arrange(layout, specs, order)
	local entries, placed = {}, {}
	local function Place(id, group)
		if not specs[id] or placed[id] then return end
		placed[id] = true
		entries[#entries + 1] = { spec = specs[id], group = group }
	end
	for _, node in ipairs(layout.nodes) do
		if type(node) == 'table' then
			entries[#entries + 1] = { header = node }
			for _, id in ipairs(node.members) do Place(id, node) end
		else
			Place(node)
		end
	end
	for _, spec in ipairs(order) do Place(spec.id) end
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

local function GroupHeader(ui, board, layout, group, specs, page)
	local row, title, subtitle = board:AddDragHeader(group.name, MemberCount(group, specs), {
		{ tooltip = 'Rename', title = 'Group', options = {
			{ label = 'Name', kind = 'input', placeholder = 'Group name', get = function() return group.name end, set = function(text)
				if text ~= '' then group.name = text end
			end },
		} },
		{ icon = 'erase', size = Layout.ERASE_SIZE, tooltip = 'Delete the group, its auras stay where it was', hover = 'danger', slot = 'icon', onClick = function() DeleteGroup(layout, group) end },
		GroupSwitch(group, specs),
	}, Repaint, function() return group.collapsed == true end, function()
		group.collapsed = not group.collapsed or nil
		page:Resize()
	end)
	ui.Bind(title, function() title:SetText(group.name) end)
	ui.Bind(subtitle, function() subtitle:SetText(MemberCount(group, specs)) end)
	return row
end

local function GeneralBoard(ui, parent, width, page)
	local layout = BUI.GetDB().auraGroups
	local order, specs = {}, {}
	for index, Row in ipairs(ROWS) do
		local spec = Row()
		spec.tools[#spec.tools + 1] = spec.switch
		order[index] = spec
		specs[spec.id] = spec
	end
	local nodeOf, headers = {}, {}
	local board
	local function NewGroup()
		Save(layout, board, nodeOf)
		table.insert(layout.nodes, 1, { name = 'Group ' .. (GroupCount(layout) + 1), members = {} })
		BUI.PageEngine.RefreshCurrentPage()
	end
	board = ui.Board(parent, width, {
		stacked = true,
		title = 'General',
		description = 'Drag a row to reorder it or drop it on a group. The eye shows an alert so you can move it.',
		buttons = { { text = 'New group', onClick = NewGroup } },
	})
	board:DragList(function() page:Resize() end, function()
		Save(layout, board, nodeOf)
		page:Resize()
		Repaint()
	end)
	for _, entry in ipairs(Arrange(layout, specs, order)) do
		if entry.header then
			local header = GroupHeader(ui, board, layout, entry.header, specs, page)
			headers[entry.header] = header
			nodeOf[header] = entry.header
		else
			local spec = entry.spec
			nodeOf[board:AddDragTools(spec.name, spec.sub, nil, spec.tools, spec.after, headers[entry.group])] = spec.id
		end
	end
	return board
end

local function SpecList()
	local specs = {}
	for classID = 1, GetNumClasses() do
		local className, classFile = GetClassInfo(classID)
		if className then
			local classColor = RAID_CLASS_COLORS[classFile]
			local colorText = classColor and classColor.colorStr or 'ffcccccc'
			for specIndex = 1, GetNumSpecializationsForClassID(classID) do
				local specID, specName = GetSpecializationInfoForClassID(classID, specIndex)
				if specID then
					specs[#specs + 1] = { className = className, id = specID, text = ('|c%s%s|r  |cff888888%s|r'):format(colorText, specName or ('Spec ' .. specIndex), className) }
				end
			end
		end
	end
	table.sort(specs, function(left, right)
		if left.className ~= right.className then return left.className < right.className end
		return left.text < right.text
	end)
	return specs
end

local function SpecsTool(ui, db, apply)
	local specs = SpecList()
	local melee = BUI.Crosshair.MELEE_SPEC_IDS
	local function Selected()
		if db.specs then return db.specs end
		local all = {}
		for _, spec in ipairs(specs) do all[spec.id] = true end
		return all
	end
	local function Choose(filter)
		local map = {}
		for _, spec in ipairs(specs) do
			if filter(spec.id) then map[spec.id] = true end
		end
		db.specs = map
		apply()
		Repaint()
	end
	local function Count()
		local selected, count = Selected(), 0
		for _, spec in ipairs(specs) do
			if selected[spec.id] then count = count + 1 end
		end
		return count
	end
	return {
		kind = 'custom',
		build = function(parent)
			local dropdown = ui.Dropdown(parent, SPECS_WIDTH, function()
				local selected = Selected()
				local items = {
					{ text = 'Select all', callback = function() Choose(function() return true end) end },
					{ text = 'Deselect all', callback = function() Choose(function() return false end) end },
					{ text = 'Melee only', callback = function() Choose(function(id) return melee[id] == true end) end },
					{ separator = true },
				}
				for _, spec in ipairs(specs) do
					local item = { text = spec.text, checked = selected[spec.id] == true }
					item.callback = function()
						local map = CopyTable(Selected())
						map[spec.id] = not map[spec.id] or nil
						item.checked = map[spec.id] == true
						db.specs = map
						apply()
						Repaint()
						return true
					end
					items[#items + 1] = item
				end
				return items
			end)
			ui.Bind(dropdown, function()
				local count = Count()
				dropdown.label:SetText(count == #specs and 'All specs' or count == 0 and 'No specs' or (count .. ' specs'))
			end)
			return dropdown
		end,
	}
end

local function CrosshairBoard(ui, parent, width)
	local db = BUI.GetDB().crosshair
	local Crosshair = BUI.Crosshair
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Crosshair',
		description = 'A reticle at the center of your screen, shown for the specs you pick.',
	})
	board:AddTools('Crosshair', 'Style, size, color and when it hides', {
		ChannelColor(db, 'Crosshair color', 'alpha'),
		{ entries = STYLES, width = MENU_WIDTH, get = function() return db.style end, set = function(value) db.style = value end },
		{ tooltip = 'Appearance and visibility', title = 'Crosshair', options = {
			Option(db, 'Size', 'size', { min = 5, max = 100, step = 1 }),
			Option(db, 'Thickness', 'thickness', { min = 1, max = 10, step = 1 }),
			Option(db, 'Center gap', 'gap', { min = 0, max = 30, step = 1 }),
			Option(db, 'Hide out of combat', 'hideOutOfCombat'),
			Option(db, 'Hide in town', 'hideInTown'),
			Option(db, 'Range indicator, ' .. Crosshair.RangeLabel(), 'rangeIndicator'),
			ArrayColor(db, 'In range color', 'inRangeColor', false),
			ArrayColor(db, 'Out of range color', 'outOfRangeColor', false),
		} },
		{ icon = 'location', tooltip = 'Screen offset', title = 'Position', options = {
			Option(db, 'Horizontal offset', 'offsetX', { min = -500, max = 500, step = 1 }),
			Option(db, 'Vertical offset', 'offsetY', { min = -500, max = 500, step = 1 }),
		} },
		Eye('Preview', Crosshair.IsPreviewing, Crosshair.SetPreview),
		Switch(db, 'enabled'),
	}, Crosshair.Refresh)
	board:AddTools('Show for specs', 'Specializations the crosshair is shown for', { SpecsTool(ui, db, Crosshair.Refresh) })
	return board
end

local function General(ui, _, parent, width, page)
	return { GeneralBoard(ui, parent, width, page), CrosshairBoard(ui, parent, width) }
end

BUI.PageEngine.RegisterPage('auras', {
	title = '|cffFF0000Weaker|r Auras',
	buttonText = '|cffFF0000Weaker|r Auras',
	icon = 'glow',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		sounds = BUI.BuildSoundDropdownItems()
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local enabled = BUI.IsModuleEnabled('auras')
		local handle = Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'glow',
			title = '|cffFF0000Weaker|r Auras',
			placeholder = 'Search auras...',
			disabled = function() return not enabled end,
			tools = {
				{ icon = 'enable', tooltip = 'Turn the auras module on or off, needs a reload', get = function() return BUI.IsModuleEnabled('auras') end, set = function(value)
					BUI.ModulesPage.ConfirmReload('auras', value, Repaint)
				end },
			},
			tabs = {
				{ label = 'General', build = General },
				{ label = 'GCD History', build = BUI.StreamerToolsPage.GCDHistory },
				{ label = 'Class', build = BUI.BuffTrackingPage.Class },
			},
		})
		pageFrame._page = handle
		pageFrame._selectModule = function() handle:SetTab(1) end
		page:AutoRefresh()
	end,
	OnHide = function()
		local settings = BUI.GetDB().auras
		if not settings.locked then BUI.Auras.SetLocked(true) end
		if settings.lowHpLocked == false then
			settings.lowHpLocked = true
			BUI.Auras.UpdateLowHp()
		end
		BUI.Crosshair.SetPreview(false)
		if BUI.Bloodlust.IsPreviewing() then BUI.Bloodlust.StopPreview() end
		if not BUI.GetDB().gcdHistory.locked then BUI.GCDHistory.SetLocked(true) end
		local overlays = BUI.BuffTracking
		if overlays.KillCommandOverlay.IsPreviewing() then overlays.KillCommandOverlay.StopPreview() end
	end,
})
