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

local MARK_FIELDS = {
	posX = 'markPosX', posY = 'markPosY',
	anchorFrame = 'markAnchorFrame', anchorPoint = 'markAnchorPoint',
	anchorOffsetX = 'markAnchorOffsetX', anchorOffsetY = 'markAnchorOffsetY',
	centerHorizontally = 'markCenterHorizontally',
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

local function ChannelColor(db, label)
	return {
		kind = 'swatch', label = label, tooltip = label,
		get = function() return db.colorR, db.colorG, db.colorB, 1 end,
		set = function(red, green, blue) db.colorR, db.colorG, db.colorB = red, green, blue end,
	}
end

local function CombatTimerRow(board)
	local db = BUI.GetDB().combatTimer
	local CombatTimer = BUI.CombatTimer
	CombatTimer._lockToggle = relock
	board:AddTools('Combat Timer', 'Elapsed time readout while you are in combat', {
		ChannelColor(db, 'Text color'),
		Font(db, 'font'),
		TextTool({ Option(db, 'Font size', 'fontSize', { min = 10, max = 40, step = 1 }) }),
		{ tooltip = 'Readout', title = 'Combat timer', options = {
			Option(db, 'Milliseconds', 'showMilliseconds'),
		} },
		BUI.PositionTool(db, { selfTag = 'BUI_CombatTimer' }),
		Eye('Preview, drag to move', function() return not db.locked end, function(value) CombatTimer.SetLocked(not value) end),
		{ get = function() return db.enabled == true end, set = CombatTimer.Toggle },
	}, CombatTimer.ApplySettings)
end

local function CombatMessagesRow(board)
	local db = BUI.GetDB().combatMessage
	local CombatMessage = BUI.CombatMessage
	CombatMessage._lockToggle = relock
	board:AddTools('Combat Messages', 'On-screen text when combat starts and ends', {
		ArrayColor(db, 'Enter combat', 'enterColor', true),
		ArrayColor(db, 'Leave combat', 'leaveColor', true),
		Font(db, 'font'),
		TextTool({ Option(db, 'Font size', 'fontSize', { min = 10, max = 40, step = 1 }) }),
		{ tooltip = 'Timing', title = 'Messages', options = {
			Option(db, 'Fade time', 'fadeTime', { min = 0.2, max = 3, step = 0.1 }),
		} },
		BUI.PositionTool(db, { selfTag = 'BUI_CombatMessage' }),
		Eye('Preview, drag to move', function() return not db.locked end, function(value) CombatMessage.SetLocked(not value) end),
		{ get = function() return db.enabled == true end, set = function(value)
			db.enabled = value
			if value then CombatMessage.Enable() else CombatMessage.Disable() end
		end },
	}, CombatMessage.Refresh)
end

local function LowHpRow(board)
	local db = BUI.GetDB().auras
	local Auras = BUI.Auras
	Auras._lowHpLockToggle = relock
	board:AddTools('Low HP Warning', 'Warning text when your health drops below the threshold', {
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
		Switch(db, 'lowHpWarning'),
	}, Auras.UpdateLowHp)
end

local function PetWarningsRow(board)
	local db = BUI.GetDB().auras
	local Auras = BUI.Auras
	Auras._lockToggle = relock
	board:AddTools('Pet Warnings', 'Alerts when your pet is dead, missing, idle or low on health', {
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
		Switch(db, 'petWarningsEnabled'),
	}, Auras.Update)
end

local function MarkWarningRow(board)
	local db = BUI.GetDB().auras
	local Auras = BUI.Auras
	Auras._markLockToggle = relock
	board:AddTools("Hunter's Mark Warning", "Callout while your target is missing Hunter's Mark, hunters only", {
		TableColor(db, 'Text color', 'markColor', true),
		Font(db, 'markFont'),
		TextTool({
			Option(db, 'Warning text', 'markText', { kind = 'input', placeholder = 'Warning text' }),
			Option(db, 'Font size', 'markFontSize', { min = 10, max = 48, step = 1 }),
		}),
		{ tooltip = 'Icon and visibility', title = "Hunter's mark", options = {
			{ label = 'Spell icon', get = function() return db.markShowIcon ~= false end, set = function(value) db.markShowIcon = value end },
			{ label = 'Pulse icon', get = function() return db.markPulse ~= false end, set = function(value) db.markPulse = value end },
			Option(db, 'Combat only', 'markCombatOnly'),
			Option(db, 'Group only', 'markGroupOnly'),
			Option(db, 'Hide in town', 'markHideInTown'),
		} },
		BUI.PositionTool(db, { selfTag = 'BUI_MarkWarning', fields = MARK_FIELDS }),
		Eye('Preview, drag to move', function() return db.markLocked == false end, function(value)
			db.markLocked = not value
			Auras.UpdateMark()
		end),
		Switch(db, 'markWarning'),
	}, Auras.UpdateMark)
end

local function GatewayRow(board)
	local db = BUI.GetDB().gatewayAlert
	local Display = BUI.BuffTracking.Display
	local function Apply()
		local tracker = Display.GetTracker('gatewayAlert')
		if tracker then tracker.Refresh() end
	end
	Display.RegisterAnchorCallback('gatewayAlert', Repaint)
	board:AddTools('Gateway Alert', 'Text while a Demonic Gateway is in reach and off cooldown, needs a Gateway Control Shard on an action bar', {
		TableColor(db, 'Text color', 'textColor', true),
		Font(db, 'font'),
		TextTool({
			Option(db, 'Text', 'customText', { kind = 'input', placeholder = 'Alert text' }),
			Option(db, 'Font size', 'textSize', { min = 10, max = 48, step = 1 }),
		}),
		{ tooltip = 'Sound', title = 'Gateway alert', options = {
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
		Switch(db, 'enabled'),
	}, Apply)
end

local function BloodlustRow(board)
	local db = BUI.GetDB().bloodlust
	local Bloodlust = BUI.Bloodlust
	Bloodlust.onPreviewStop = Repaint
	board:AddTools('Bloodlust', 'Tracks Bloodlust, Heroism and similar haste buffs', {
		Font(db, 'font'),
		TextTool({ Option(db, 'Font size', 'fontSize', { min = 8, max = 48, step = 1 }) }),
		{ icon = 'cog', tooltip = 'Open the Bloodlust page', onClick = function() BUI.PageEngine.NavigateToID('bloodlust') end },
		BUI.PositionTool(db),
		Eye('Preview the alerts', Bloodlust.IsPreviewing, function(value)
			if value then Bloodlust.StartPreview() else Bloodlust.StopPreview() end
		end),
		Switch(db, 'enabled'),
	}, Bloodlust.Refresh)
end

local function CDAnnouncerRow(board)
	local db = BUI.GetDB().cdAnnouncer
	local CDAnnouncer = BUI.CDAnnouncer
	CDAnnouncer.RegisterAnchorCallback(Repaint)
	board:AddTools('Cooldown Announcer', 'Countdowns and ready alerts for the cooldowns you pick', {
		{ icon = 'cog', tooltip = 'Open the Cooldown Announcer page', onClick = function() BUI.PageEngine.NavigateToID('cdAnnouncer') end },
		Eye('Unlock the anchor to drag it, right-click it to lock', function() return db.showAnchor == true end, function(value)
			db.showAnchor = value
			CDAnnouncer.Refresh()
		end),
		Switch(db, 'enabled'),
	}, CDAnnouncer.Refresh)
end

local function AlertsBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Alerts',
		description = 'Text callouts for combat, your pet, your health and your target. The eye on a row previews it and lets you drag it, right-click the alert to lock it again.',
	})
	CombatTimerRow(board)
	CombatMessagesRow(board)
	LowHpRow(board)
	PetWarningsRow(board)
	MarkWarningRow(board)
	GatewayRow(board)
	BloodlustRow(board)
	CDAnnouncerRow(board)
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
		ChannelColor(db, 'Crosshair color'),
		{ entries = STYLES, width = MENU_WIDTH, get = function() return db.style end, set = function(value) db.style = value end },
		{ tooltip = 'Appearance and visibility', title = 'Crosshair', options = {
			Option(db, 'Size', 'size', { min = 5, max = 100, step = 1 }),
			Option(db, 'Thickness', 'thickness', { min = 1, max = 10, step = 1 }),
			Option(db, 'Center gap', 'gap', { min = 0, max = 30, step = 1 }),
			{ label = 'Opacity', min = 10, max = 100, step = 5, get = function() return db.alpha * 100 end, set = function(value) db.alpha = value / 100 end },
			Option(db, 'Hide out of combat', 'hideOutOfCombat'),
			Option(db, 'Hide in town', 'hideInTown'),
			Option(db, 'Range indicator, ' .. Crosshair.RangeLabel(), 'rangeIndicator'),
			ArrayColor(db, 'In range color', 'inRangeColor', false),
			ArrayColor(db, 'Out of range color', 'outOfRangeColor', false),
		} },
		{ icon = 'mover', tooltip = 'Screen offset', title = 'Position', options = {
			Option(db, 'Horizontal offset', 'offsetX', { min = -500, max = 500, step = 1 }),
			Option(db, 'Vertical offset', 'offsetY', { min = -500, max = 500, step = 1 }),
		} },
		Eye('Preview', Crosshair.IsPreviewing, Crosshair.SetPreview),
		Switch(db, 'enabled'),
	}, Crosshair.Refresh)
	board:AddTools('Show for specs', 'Specializations the crosshair is shown for', { SpecsTool(ui, db, Crosshair.Refresh) })
	return board
end

local function Alerts(ui, _, parent, width)
	return { AlertsBoard(ui, parent, width), CrosshairBoard(ui, parent, width) }
end

BUI.PageEngine.RegisterPage('auras', {
	title = '|cffFF0000Weaker|r Auras',
	buttonText = '|cffFF0000Weaker|r Auras',
	icon = 'glow',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		sounds = BUI.BuildSoundDropdownItems()
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local handle = Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'glow',
			title = '|cffFF0000Weaker|r Auras',
			placeholder = 'Search alerts...',
			tools = {
				{ icon = 'enable', tooltip = 'Turn the auras module on or off, needs a reload', get = function() return BUI.IsModuleEnabled('auras') end, set = function(value)
					BUI.ModulesPage.ConfirmReload('auras', value, Repaint)
				end },
			},
			tabs = {
				{ label = 'Alerts', build = Alerts },
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
		if settings.markLocked == false then
			settings.markLocked = true
			BUI.Auras.UpdateMark()
		end
		BUI.Crosshair.SetPreview(false)
		if BUI.Bloodlust.IsPreviewing() then BUI.Bloodlust.StopPreview() end
		if not BUI.GetDB().gcdHistory.locked then BUI.GCDHistory.SetLocked(true) end
		local overlays = BUI.BuffTracking
		if overlays.KillCommandOverlay.IsPreviewing() then overlays.KillCommandOverlay.StopPreview() end
		if overlays.BestialWrathOverlay.IsPreviewing() then overlays.BestialWrathOverlay.StopPreview() end
	end,
})
