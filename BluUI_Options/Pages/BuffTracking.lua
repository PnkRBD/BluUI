local BUI = BluUI
local BuffTracking = BUI.BuffTracking
local Display = BuffTracking.Display

local MENU_WIDTH = 150
local LABEL_RANGE = 50
local OVERLAY_RANGE = 30

local DISPLAYS = {
	{ value = 'icon', text = 'On the icon' },
	{ value = 'screen', text = 'On screen' },
	{ value = 'both', text = 'Both' },
}
local ALERT_MODES = {
	{ value = 'flash', text = 'Flash briefly' },
	{ value = 'stay', text = 'Stay on screen' },
}

local fonts, sounds

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function RefreshTracker(key)
	local tracker = Display.GetTracker(key)
	if tracker then tracker.Refresh() end
end

local function SpellIcon(spellID)
	return C_Spell.GetSpellTexture(spellID)
end

local function Option(db, label, key, extra)
	local option = { label = label, get = function() return db[key] end, set = function(value) db[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Toggle(db, label, key)
	return { label = label, get = function() return db[key] == true end, set = function(value) db[key] = value end }
end

local function Color(db, label, key, opacity)
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

local function Font(db)
	return { entries = fonts, width = MENU_WIDTH, get = function() return db.font end, set = function(value) db.font = value end }
end

local function Sound(db)
	return { entries = sounds, width = MENU_WIDTH, get = function() return db.sound end, set = function(value)
		db.sound = value
		BUI.PlaySoundByName(value)
	end }
end

local function Eye(db, Refresh)
	return { icon = 'eye', tooltip = 'Unlock to drag it, right-click it to lock', get = function() return db.showAnchor == true end, set = function(value)
		db.showAnchor = value
		Refresh()
	end }
end

local function Preview(module)
	return { icon = 'eye', tooltip = 'Preview', get = module.IsPreviewing, set = function(value)
		if value then module.StartPreview() else module.StopPreview() end
		Repaint()
	end }
end

local function TextRow(board, key, frameName, def)
	local db = BUI.GetDB()[key]
	local function Refresh() RefreshTracker(key) end
	Display.RegisterAnchorCallback(key, Repaint)
	local text = { Option(db, def.textLabel or 'Text', 'customText', { kind = 'input', placeholder = 'Text' }) }
	if def.altTextLabel then text[#text + 1] = Option(db, def.altTextLabel, 'customTextAlt', { kind = 'input', placeholder = 'Text' }) end
	text[#text + 1] = Option(db, 'Text size', 'textSize', { min = 10, max = 48, step = 1 })
	local tools = {
		Color(db, 'Text color', 'textColor', true),
		Font(db),
		{ icon = 'text', tooltip = 'Text and size', title = def.title, options = text },
	}
	if not def.noSound then tools[#tools + 1] = Sound(db) end
	if def.options then tools[#tools + 1] = { tooltip = def.tooltip, title = def.title, options = def.options(db) } end
	tools[#tools + 1] = BUI.PositionTool(db, { selfTag = frameName })
	tools[#tools + 1] = Eye(db, Refresh)
	tools[#tools + 1] = Toggle(db, nil, 'enabled')
	board:AddTools(def.title, def.description, tools, Refresh, SpellIcon(def.spell))
end

local function StackRows(board, key, frameName, maxStacks, def)
	local db = BUI.GetDB()[key]
	local function Refresh() RefreshTracker(key) end
	Display.RegisterAnchorCallback(key, Repaint)
	local tools = {}
	for stack = 1, maxStacks do
		tools[#tools + 1] = Color(db, stack == 1 and '1 stack' or stack .. ' stacks', 'stack' .. stack .. 'Color', true)
	end
	tools[#tools + 1] = Color(db, 'Text color', 'textColor', true)
	tools[#tools + 1] = Font(db)
	tools[#tools + 1] = { icon = 'text', tooltip = 'Text size', title = def.title, options = { Option(db, 'Text size', 'textSize', { min = 10, max = 48, step = 1 }) } }
	tools[#tools + 1] = BUI.PositionTool(db, { selfTag = frameName })
	tools[#tools + 1] = Eye(db, Refresh)
	tools[#tools + 1] = Toggle(db, nil, 'enabled')
	board:AddTools(def.title, def.description, tools, Refresh, SpellIcon(def.spell))
	board:AddTools('Stack bars', 'Bars instead of a number, with their size, colors and when they show', {
		Color(db, 'Filled color', 'filledColor', true),
		Color(db, 'Empty color', 'emptyColor', true),
		Color(db, 'Border color', 'borderColor', true),
		{ tooltip = 'Size and visibility', title = 'Stack bars', options = {
			Option(db, 'Bar width', 'barWidth', { min = 30, max = 200, step = 1 }),
			Option(db, 'Bar height', 'barHeight', { min = 4, max = 50, step = 1 }),
			Option(db, 'Bar spacing', 'barSpacing', { min = 0, max = 20, step = 1 }),
			Option(db, 'Border thickness', 'borderThickness', { min = 0, max = 4, step = 1 }),
			Toggle(db, 'Hide when no stacks', 'hideWhenEmpty'),
			Toggle(db, 'Only in combat', 'showOnlyInCombat'),
			Toggle(db, 'Color by stack count', 'colorByStacks'),
		} },
		{ get = function() return db.displayMode == 'BARS' end, set = function(value) db.displayMode = value and 'BARS' or 'TEXT' end },
	}, Refresh)
end

local function PackLeaderRows(board)
	local db = BUI.GetDB().packLeader
	local Overlay = BuffTracking.KillCommandOverlay
	local function Refresh()
		RefreshTracker('packLeader')
		Overlay.Refresh()
	end
	Display.RegisterAnchorCallback('packLeader', Repaint)
	local function Beast(key, label)
		return {
			kind = 'swatch', label = label, tooltip = label,
			get = function()
				local color = db.beastColors[key]
				return color.r, color.g, color.b, 1
			end,
			set = function(red, green, blue) db.beastColors[key] = { r = red, g = green, b = blue } end,
		}
	end
	board:AddTools('Pack Leader', 'Beast cycle icon with the cooldown countdown and the next beast', {
		Beast('wyvern', 'Wyvern'),
		Beast('bear', 'Bear'),
		Beast('boar', 'Boar'),
		{ icon = 'text', tooltip = 'Labels', title = 'Pack Leader', options = {
			Option(db, 'Label size', 'labelTextSize', { min = 6, max = 32, step = 1 }),
			Toggle(db, 'Countdown text', 'showCountdownText'),
			Toggle(db, 'Next and USE! text', 'showNextText'),
			Option(db, 'Top text horizontal', 'topTextOffsetX', { min = -LABEL_RANGE, max = LABEL_RANGE, step = 1 }),
			Option(db, 'Top text vertical', 'topTextOffsetY', { min = -LABEL_RANGE, max = LABEL_RANGE, step = 1 }),
			Option(db, 'Bottom text horizontal', 'bottomTextOffsetX', { min = -LABEL_RANGE, max = LABEL_RANGE, step = 1 }),
			Option(db, 'Bottom text vertical', 'bottomTextOffsetY', { min = -LABEL_RANGE, max = LABEL_RANGE, step = 1 }),
		} },
		{ tooltip = 'Icons and effects', title = 'Pack Leader', options = {
			Option(db, 'Icon size', 'iconSize', { min = 16, max = 64, step = 1 }),
			Option(db, 'Next icon size', 'nextIconSize', { min = 8, max = 64, step = 1 }),
			Option(db, 'Spacing', 'spacing', { min = 0, max = 16, step = 1 }),
			Toggle(db, 'Show the next icon', 'showNextIcon'),
			Toggle(db, 'Only in combat', 'showOnlyInCombat'),
			Toggle(db, 'Glow when ready', 'glowOnReady'),
			Toggle(db, 'Animate transitions', 'animateTransitions'),
		} },
		BUI.PositionTool(db, { selfTag = 'BUI_PackLeader', noCenter = true }),
		Eye(db, Refresh),
		Toggle(db, nil, 'enabled'),
	}, Refresh, SpellIcon(471876))
	local overlay = BUI.GetDB().killCommandOverlay
	board:AddTools('Kill Command overlay', 'Pack Leader countdown and beast name on the Kill Command icon', {
		Color(overlay, 'Timer color', 'timerColor', false),
		{ icon = 'text', tooltip = 'Timer and beast name text', title = 'Kill Command overlay', options = {
			Option(overlay, 'Timer size', 'timerSize', { min = 6, max = 72, step = 1 }),
			Option(overlay, 'Timer anchor', 'timerAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(overlay, 'Timer horizontal', 'timerOffsetX', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
			Option(overlay, 'Timer vertical', 'timerOffsetY', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
			Option(overlay, 'Beast name size', 'beastSize', { min = 6, max = 24, step = 1 }),
			Option(overlay, 'Beast name anchor', 'beastAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(overlay, 'Beast name horizontal', 'beastOffsetX', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
			Option(overlay, 'Beast name vertical', 'beastOffsetY', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
		} },
		{ tooltip = 'What it shows', title = 'Kill Command overlay', options = {
			Toggle(overlay, 'Timer', 'showTimer'),
			Toggle(overlay, 'Beast name', 'showBeastName'),
			Toggle(overlay, 'Decimals', 'showDecimals'),
			Option(overlay, 'Decimals under seconds', 'decimalThreshold', { min = 1, max = 10, step = 1 }),
		} },
		Preview(Overlay),
		Toggle(overlay, nil, 'enabled'),
	}, Overlay.Refresh, SpellIcon(34026))
end

local function BestialWrathRow(board)
	local db = BUI.GetDB().bestialWrathOverlay
	local Overlay = BuffTracking.BestialWrathOverlay
	board:AddTools('Bestial Wrath callout', 'HOLD BW, SEND BW and THRASH! on the icon or on screen, needs Wild Thrash', {
		{ entries = DISPLAYS, width = MENU_WIDTH, get = function() return db.displayMode end, set = function(value) db.displayMode = value end },
		{ icon = 'text', tooltip = 'Text sizes and placement', title = 'Bestial Wrath callout', options = {
			Option(db, 'Size on the icon', 'textSize', { min = 6, max = 32, step = 1 }),
			Option(db, 'Anchor on the icon', 'textAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(db, 'Horizontal on the icon', 'textOffsetX', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
			Option(db, 'Vertical on the icon', 'textOffsetY', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
			Option(db, 'Size on screen', 'screenTextSize', { min = 12, max = 64, step = 1 }),
		} },
		{ tooltip = 'Speech, hints and the screen text', title = 'Bestial Wrath callout', options = {
			Toggle(db, 'Speak the callouts', 'tts'),
			Toggle(db, 'Speak the hold cues', 'ttsHold'),
			Toggle(db, 'Hold Thrash hint, 10 to 13 seconds in', 'showHoldThrash'),
			Toggle(db, 'Screen text only in combat', 'screenCombatOnly'),
			{ label = 'Unlock the screen text to drag it', get = function() return db.screenLocked == false end, set = function(value) db.screenLocked = not value end },
		} },
		BUI.PositionTool(db, { noCenter = true }),
		Preview(Overlay),
		Toggle(db, nil, 'enabled'),
	}, Overlay.Refresh, SpellIcon(19574))
end

local function SmartMisdirectRow(board)
	local db = BUI.GetDB().smartMisdirect
	local SmartMisdirect = BuffTracking.SmartMisdirect
	board:AddTools('Smart Misdirection', 'One button that aims at your override, focus, tank or pet. Bind it in Key Bindings or macro /click BUI_SmartMisdirect LeftButton. Right-click a group member to pin them.', {
		{ tooltip = 'Who it picks', title = 'Smart Misdirection', options = {
			{ label = 'Override target', kind = 'input', placeholder = 'Name', get = function() return db.overrideName end, set = function(text)
				db.overrideName = text
				db.overrideRealm = ''
			end },
			Toggle(db, 'Use your focus', 'useFocus'),
			Toggle(db, 'Prefer the tank', 'preferTank'),
			Option(db, 'Which tank', 'tankMethod', { entries = SmartMisdirect.TANK_METHOD_ITEMS }),
			Toggle(db, 'Fall back to your pet', 'fallbackPet'),
		} },
		{ text = 'Create macro', onClick = SmartMisdirect.CreateMacro },
		Toggle(db, nil, 'enabled'),
	}, SmartMisdirect.Refresh, SpellIcon(34477))
end

local function Sections(ui, _, parent, width)
	fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
	sounds = BUI.BuildSoundDropdownItems()
	local Hunter, Monk, Druid = BuffTracking.Hunter, BuffTracking.Monk, BuffTracking.Druid
	local boards = {}
	local function Board(title, description)
		local board = ui.Board(parent, width, { stacked = true, title = title, description = description })
		if #boards == 0 then
			board:AddSwitch('Buff tracking module', function() return BUI.IsModuleEnabled('buffTracking') end, function(value)
				BUI.ModulesPage.ConfirmReload('buffTracking', value, Repaint)
			end, 'Turning it on or off needs a reload')
		end
		boards[#boards + 1] = board
		return board
	end
	if Hunter.IsBeastMastery() then
		PackLeaderRows(Board('Pack Leader', 'Beast cycle helpers for Pack Leader.'))
		local procs = Board('Procs', 'Text callouts for procs and stacks. The eye on a row lets you drag it, right-click the text to lock it again.')
		TextRow(procs, 'hunterKillCommand', 'BUI_BuffTrackingHunterKC', { title = 'Kill Command', description = 'Text alert when Kill Command procs', spell = 34026 })
		TextRow(procs, 'hunterCobraFang', 'BUI_BuffTrackingHunterCF', { title = 'Cobra Fang', description = 'Live tier set stack count, spent by Cobra Shot, up to 4', spell = 193455 })
		BestialWrathRow(Board('AoE burst', 'Bestial Wrath callouts for Wild Thrash.'))
	elseif Hunter.IsSurvivalHunter() then
		local procs = Board('Procs', 'Stacks and text callouts. The eye on a row lets you drag it, right-click the text to lock it again.')
		StackRows(procs, 'hunterTip', 'BUI_BuffTrackingHunterTip', 3, { title = 'Tip of the Spear', description = 'Stacks as bars or a number, up to 3', spell = 260286 })
		TextRow(procs, 'hunterRaptorSwipe', 'BUI_BuffTrackingHunterRS', { title = 'Raptor Swipe', description = 'Text alert while Raptor Swipe is active', spell = 1273155, textLabel = 'Text', altTextLabel = 'Text without Tip stacks' })
		TextRow(procs, 'hunterRaptorPrompt', 'BUI_BuffTrackingHunterRaptorPrompt', { title = 'Raptor Prompt', description = 'Reminder to cast Raptor Strike when nothing else is up', spell = 186270 })
		PackLeaderRows(Board('Pack Leader', 'Beast cycle helpers for Pack Leader.'))
	elseif Hunter.IsMarksmanshipHunter() then
		local procs = Board('Procs', 'Text callouts for procs. The eye on a row lets you drag it, right-click the text to lock it again.')
		TextRow(procs, 'hunterPreciseShots', 'BUI_BuffTrackingHunterPS', { title = 'Precise Shots', description = 'Text alert while Precise Shots is active', spell = 260242 })
		TextRow(procs, 'hunterLockAndLoad', 'BUI_BuffTrackingHunterLnL', { title = 'Lock and Load', description = 'Text alert when Lock and Load procs', spell = 194594 })
		TextRow(procs, 'hunterBulletstorm', 'BUI_BuffTrackingHunterBS', { title = 'Bulletstorm', description = 'Empowered Aimed Shots left after Rapid Fire', spell = 389019 })
	end
	if Hunter.IsBeastMasteryOrSurvival() or Hunter.IsMarksmanshipHunter() then
		local utility = Board('Utility', 'Misdirection helpers.')
		SmartMisdirectRow(utility)
		TextRow(utility, 'misdirectAlert', 'BUI_MisdirectAlert', {
			title = 'Misdirect alert', description = 'On-screen text naming your current Misdirection target', spell = 34477, textLabel = 'Prefix', tooltip = 'When it shows',
			options = function(db)
				return {
					Option(db, 'Show', 'alertMode', { entries = ALERT_MODES }),
					Option(db, 'Flash for seconds', 'flashSeconds', { min = 1, max = 10, step = 1 }),
					Toggle(db, 'Flash on cast', 'flashOnCast'),
					Toggle(db, 'Flash on target change', 'flashOnTargetChange'),
				}
			end,
		})
	end
	if Monk.IsMistweaver() then
		TextRow(Board('Mistweaver', 'Reminders for Mistweaver procs.'), 'monkVivaciousVivification', 'BUI_MonkVivaciousVivification', { title = 'Vivacious Vivification', description = 'Reminder when your instant Vivify is ready', spell = 392883 })
	elseif Druid.IsRestoration() then
		TextRow(Board('Restoration', 'Reminders for Restoration upkeep.'), 'druidLifebloom', 'BUI_DruidLifebloom', {
			title = 'Lifebloom refresh', description = 'REFRESH when your Lifebloom on anyone in the group is about to fall off', spell = 33763, noSound = true, tooltip = 'Timing',
			options = function(db) return { Option(db, 'Refresh at seconds left', 'refreshSeconds', { min = 1, max = 8, step = 0.5 }) } end,
		})
	end
	if #boards == 0 then
		Board('Class', 'Trackers for the buffs and procs of your spec.'):AddRow('Nothing for this spec yet', 'Hunters, Mistweaver Monks and Restoration Druids have class trackers')
	end
	return boards
end

BUI.BuffTrackingPage = { Class = Sections }

BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'BuffTrackingPage', function(_, unit)
	if unit ~= 'player' then return end
	C_Timer.After(0.3, function()
		local pageConfig = BUI.PageEngine.pages.auras
		if pageConfig.frame then pageConfig.stale = true end
		if BUI.PageEngine.GetCurrentPage() == 'auras' then BUI.PageEngine.RefreshCurrentPage() end
	end)
end)
