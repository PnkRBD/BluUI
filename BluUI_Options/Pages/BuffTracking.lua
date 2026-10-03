local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local BuffTracking = BUI.BuffTracking
local Display = BuffTracking.Display

local PAGE_WIDTH = 960
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
local SECONDS_WIDTH = 70
local MIN_SECONDS, MAX_SECONDS = 0.5, 14

local fonts, sounds, current

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

local function Refresher(spec)
	return spec.refresh or function() RefreshTracker(spec.key) end
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

local function Switch(board, db, label, key, Refresh)
	board:AddSwitch(label, function() return db[key] == true end, function(value)
		db[key] = value
		Refresh()
	end)
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
	return { entries = fonts, get = function() return db.font end, set = function(value) db.font = value end }
end

local function Sound(db)
	return { entries = sounds, get = function() return db.sound end, set = function(value)
		db.sound = value
		BUI.PlaySoundByName(value)
	end }
end

local function Seconds(db, key, label)
	return {
		kind = 'input', label = label, width = SECONDS_WIDTH, placeholder = 'Seconds',
		get = function() return ('%g'):format(db[key]) end,
		set = function(text)
			local seconds = tonumber(text)
			if seconds then db[key] = math.min(math.max(seconds, MIN_SECONDS), MAX_SECONDS) end
			Repaint()
		end,
	}
end

local function TextTool(title, options)
	return { icon = 'text', tooltip = 'Text and size', title = title, options = options }
end

local function Timing(options)
	return { tooltip = 'Timing', title = 'Timing', options = options }
end

local function SoundRow(board, db, Refresh, timing)
	local tools = {
		Sound(db),
		{ icon = 'sound', tooltip = 'What to say', title = 'Sound', options = {
			Option(db, 'Spoken text', 'ttsText', { kind = 'input', placeholder = 'Same as the alert text' }),
		} },
	}
	if timing then tools[#tools + 1] = Timing(timing) end
	tools[#tools + 1] = { icon = 'play', tooltip = 'Hear it', onClick = function() Display.Announce(db) end }
	tools[#tools + 1] = Toggle(db, nil, 'tts')
	board:AddTools('Sound', 'Plays when it shows, the switch also says the text', tools, Refresh)
end

local function Eye(db, Refresh, spec)
	Display.RegisterAnchorCallback(spec.key, Repaint)
	return { icon = 'eye', tooltip = 'Unlock to drag it, right-click it to lock', get = function() return db.showAnchor == true end, set = function(value)
		db.showAnchor = value
		Refresh()
	end }
end

local function Preview(module)
	return function()
		return { icon = 'eye', tooltip = 'Preview', get = module.IsPreviewing, set = function(value)
			if value then module.StartPreview() else module.StopPreview() end
			Repaint()
		end }
	end
end

local function Open(spec)
	current = spec
	BUI.PageEngine.pages.classAlert.stale = true
	BUI.PageEngine.NavigateToID('classAlert')
end

local function Alert(board, spec)
	local db = BUI.GetDB()[spec.key]
	local Refresh = Refresher(spec)
	local tools = { { icon = 'cog', tooltip = 'Open the ' .. spec.title .. ' page', onClick = function() Open(spec) end } }
	if spec.eye then tools[#tools + 1] = spec.eye(db, Refresh, spec) end
	tools[#tools + 1] = Toggle(db, nil, 'enabled')
	board:AddTools(spec.title, spec.description, tools, Refresh, SpellIcon(spec.spell))
end

local function TextAlert(board, spec)
	spec.eye = Eye
	spec.build = function(db, Board, Refresh)
		local alert = Board(spec.title, 'What it shows and how it sounds.')
		local text = { Option(db, spec.textLabel or 'Text', 'customText', { kind = 'input', placeholder = 'Text' }) }
		if spec.altTextLabel then text[#text + 1] = Option(db, spec.altTextLabel, 'customTextAlt', { kind = 'input', placeholder = 'Text' }) end
		text[#text + 1] = Option(db, 'Text size', 'textSize', { min = 10, max = 48, step = 1 })
		local tools = { Color(db, 'Text color', 'textColor', true), Font(db), TextTool('Text', text) }
		if spec.textTiming then tools[#tools + 1] = Timing(spec.textTiming(db)) end
		tools[#tools + 1] = BUI.PositionTool(db, { selfTag = spec.frame })
		tools[#tools + 1] = Toggle(db, nil, 'showText')
		alert:AddTools('Text', 'Wording, font, size, color and where it sits', tools, Refresh)
		SoundRow(alert, db, Refresh, spec.soundTiming and spec.soundTiming(db))
		if spec.extra then spec.extra(alert, db, Refresh) end
	end
	Alert(board, spec)
end

local function StackAlert(board, spec)
	spec.eye = Eye
	spec.build = function(db, Board, Refresh)
		local alert = Board(spec.title, 'The stack count as a number or as bars.')
		alert:AddSwitch('Show bars', function() return db.displayMode == 'BARS' end, function(value)
			db.displayMode = value and 'BARS' or 'TEXT'
			Refresh()
		end)
		Switch(alert, db, 'Hide when no stacks', 'hideWhenEmpty', Refresh)
		Switch(alert, db, 'Only in combat', 'showOnlyInCombat', Refresh)
		Switch(alert, db, 'Color by stack count', 'colorByStacks', Refresh)
		local text = {}
		for stack = 1, spec.stacks do
			text[#text + 1] = Color(db, stack == 1 and '1 stack' or stack .. ' stacks', 'stack' .. stack .. 'Color', true)
		end
		text[#text + 1] = Color(db, 'Text color', 'textColor', true)
		text[#text + 1] = Font(db)
		text[#text + 1] = TextTool('Text', { Option(db, 'Text size', 'textSize', { min = 10, max = 48, step = 1 }) })
		text[#text + 1] = BUI.PositionTool(db, { selfTag = spec.frame })
		alert:AddTools('Text', 'A color per stack count, the number itself and where it sits', text, Refresh)
		alert:AddTools('Bars', 'Filled, empty and border colors, and the size of each bar', {
			Color(db, 'Filled color', 'filledColor', true),
			Color(db, 'Empty color', 'emptyColor', true),
			Color(db, 'Border color', 'borderColor', true),
			{ tooltip = 'Size', title = 'Bars', options = {
				Option(db, 'Bar width', 'barWidth', { min = 30, max = 200, step = 1 }),
				Option(db, 'Bar height', 'barHeight', { min = 4, max = 50, step = 1 }),
				Option(db, 'Bar spacing', 'barSpacing', { min = 0, max = 20, step = 1 }),
				Option(db, 'Border thickness', 'borderThickness', { min = 0, max = 4, step = 1 }),
			} },
		}, Refresh)
	end
	Alert(board, spec)
end

local function PackLeader(board)
	local Overlay = BuffTracking.KillCommandOverlay
	Alert(board, {
		key = 'packLeader', title = 'Pack Leader', description = 'Beast cycle icon with the cooldown countdown and the next beast', spell = 471876,
		refresh = function()
			RefreshTracker('packLeader')
			Overlay.Refresh()
		end,
		eye = Eye,
		build = function(db, Board, Refresh)
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
			local cycle = Board('Pack Leader', 'The beast cycle icon, its labels and extras.')
			Switch(cycle, db, 'Countdown text', 'showCountdownText', Refresh)
			Switch(cycle, db, 'Next and USE! text', 'showNextText', Refresh)
			Switch(cycle, db, 'Show the next icon', 'showNextIcon', Refresh)
			Switch(cycle, db, 'Only in combat', 'showOnlyInCombat', Refresh)
			Switch(cycle, db, 'Glow when ready', 'glowOnReady', Refresh)
			Switch(cycle, db, 'Animate transitions', 'animateTransitions', Refresh)
			cycle:AddTools('Beasts', 'A color for each beast', { Beast('wyvern', 'Wyvern'), Beast('bear', 'Bear'), Beast('boar', 'Boar') }, Refresh)
			cycle:AddTools('Labels', 'Size and placement of the countdown and the next beast', {
				TextTool('Labels', {
					Option(db, 'Label size', 'labelTextSize', { min = 6, max = 32, step = 1 }),
					Option(db, 'Top text horizontal', 'topTextOffsetX', { min = -LABEL_RANGE, max = LABEL_RANGE, step = 1, separator = true }),
					Option(db, 'Top text vertical', 'topTextOffsetY', { min = -LABEL_RANGE, max = LABEL_RANGE, step = 1 }),
					Option(db, 'Bottom text horizontal', 'bottomTextOffsetX', { min = -LABEL_RANGE, max = LABEL_RANGE, step = 1, separator = true }),
					Option(db, 'Bottom text vertical', 'bottomTextOffsetY', { min = -LABEL_RANGE, max = LABEL_RANGE, step = 1 }),
				}),
			}, Refresh)
			cycle:AddTools('Icons', 'Size of the current and next icon, the gap between them and where they sit', {
				{ tooltip = 'Sizes', title = 'Icons', options = {
					Option(db, 'Icon size', 'iconSize', { min = 16, max = 64, step = 1 }),
					Option(db, 'Next icon size', 'nextIconSize', { min = 8, max = 64, step = 1 }),
					Option(db, 'Spacing', 'spacing', { min = 0, max = 16, step = 1 }),
				} },
				BUI.PositionTool(db, { selfTag = 'BUI_PackLeader', noCenter = true }),
			}, Refresh)
		end,
	})
	Alert(board, {
		key = 'killCommandOverlay', title = 'Kill Command overlay', description = 'Pack Leader countdown and beast name on the Kill Command icon', spell = 34026,
		refresh = Overlay.Refresh, eye = Preview(Overlay),
		build = function(db, Board, Refresh)
			local overlay = Board('Kill Command overlay', 'The countdown and beast name drawn on the icon.')
			Switch(overlay, db, 'Timer', 'showTimer', Refresh)
			Switch(overlay, db, 'Beast name', 'showBeastName', Refresh)
			Switch(overlay, db, 'Decimals', 'showDecimals', Refresh)
			overlay:AddTools('Timer', 'Color, size and where it sits on the icon', {
				Color(db, 'Timer color', 'timerColor', false),
				TextTool('Timer', {
					Option(db, 'Timer size', 'timerSize', { min = 6, max = 72, step = 1 }),
					Option(db, 'Timer anchor', 'timerAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
					Option(db, 'Timer horizontal', 'timerOffsetX', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
					Option(db, 'Timer vertical', 'timerOffsetY', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
					Option(db, 'Decimals under seconds', 'decimalThreshold', { min = 1, max = 10, step = 1, separator = true }),
				}),
			}, Refresh)
			overlay:AddTools('Beast name', 'Size and where it sits on the icon', {
				TextTool('Beast name', {
					Option(db, 'Beast name size', 'beastSize', { min = 6, max = 24, step = 1 }),
					Option(db, 'Beast name anchor', 'beastAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
					Option(db, 'Beast name horizontal', 'beastOffsetX', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
					Option(db, 'Beast name vertical', 'beastOffsetY', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
				}),
			}, Refresh)
		end,
	})
end

local function BestialWrath(board)
	local Overlay = BuffTracking.BestialWrathOverlay
	Alert(board, {
		key = 'bestialWrathOverlay', title = 'Bestial Wrath callout', description = 'HOLD BW, SEND BW and THRASH! on the icon or on screen, needs Wild Thrash', spell = 19574,
		refresh = Overlay.Refresh, eye = Preview(Overlay),
		build = function(db, Board, Refresh)
			local callout = Board('Bestial Wrath callout', 'HOLD BW, SEND BW and THRASH! on the icon or on screen.')
			Switch(callout, db, 'Speak the callouts', 'tts', Refresh)
			Switch(callout, db, 'Speak the hold cues', 'ttsHold', Refresh)
			Switch(callout, db, 'Hold Thrash hint, 8 to 13 seconds before Bestial Wrath', 'showHoldThrash', Refresh)
			Switch(callout, db, 'Screen text only in combat', 'screenCombatOnly', Refresh)
			callout:AddSwitch('Unlock the screen text to drag it', function() return db.screenLocked == false end, function(value)
				db.screenLocked = not value
				Refresh()
			end)
			callout:AddTools('Text', 'Where it shows, how big it is and where the screen text sits', {
				Option(db, 'Show', 'displayMode', { entries = DISPLAYS }),
				TextTool('Text', {
					Option(db, 'Size on the icon', 'textSize', { min = 6, max = 32, step = 1 }),
					Option(db, 'Anchor on the icon', 'textAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
					Option(db, 'Horizontal on the icon', 'textOffsetX', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
					Option(db, 'Vertical on the icon', 'textOffsetY', { min = -OVERLAY_RANGE, max = OVERLAY_RANGE, step = 1 }),
					Option(db, 'Size on screen', 'screenTextSize', { min = 12, max = 64, step = 1, separator = true }),
				}),
				BUI.PositionTool(db, { noCenter = true }),
			}, Refresh)
		end,
	})
end

local function SmartMisdirect(board)
	local SmartMisdirect = BuffTracking.SmartMisdirect
	Alert(board, {
		key = 'smartMisdirect', title = 'Smart Misdirection', description = 'One button that aims at your override, focus, tank or pet. Bind it in Key Bindings or macro /click BUI_SmartMisdirect LeftButton. Right-click a group member to pin them.', spell = 34477,
		refresh = SmartMisdirect.Refresh,
		build = function(db, Board, Refresh)
			local picks = Board('Who it picks', 'Your override, focus, tank or pet.', { { text = 'Create macro', onClick = SmartMisdirect.CreateMacro } })
			Switch(picks, db, 'Use your focus', 'useFocus', Refresh)
			Switch(picks, db, 'Prefer the tank', 'preferTank', Refresh)
			Switch(picks, db, 'Fall back to your pet', 'fallbackPet', Refresh)
			picks:AddTools('Override and tank', 'A player to always pick, and how the tank is found', {
				{ tooltip = 'Override and tank', title = 'Who it picks', options = {
					{ label = 'Override target', kind = 'input', placeholder = 'Name', get = function() return db.overrideName end, set = function(text)
						db.overrideName = text
						db.overrideRealm = ''
					end },
					Option(db, 'Which tank', 'tankMethod', { entries = SmartMisdirect.TANK_METHOD_ITEMS }),
				} },
			}, Refresh)
		end,
	})
end

local function Sections(ui, _, parent, width)
	fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
	sounds = BUI.BuildSoundDropdownItems()
	local Hunter, Monk, Druid, Mage = BuffTracking.Hunter, BuffTracking.Monk, BuffTracking.Druid, BuffTracking.Mage
	local boards = {}
	local function Board(title, description)
		local board = ui.Board(parent, width, { stacked = true, title = title, description = description })
		if #boards == 0 and not BUI.IsModuleEnabled('buffTracking') then
			board:AddSwitch('Buff tracking module', function() return BUI.IsModuleEnabled('buffTracking') end, function(value)
				BUI.ModulesPage.ConfirmReload('buffTracking', value, Repaint)
			end, 'Turning it on or off needs a reload')
		end
		boards[#boards + 1] = board
		return board
	end
	if Hunter.IsBeastMastery() then
		PackLeader(Board('Pack Leader', 'Beast cycle helpers for Pack Leader.'))
		local procs = Board('Procs', 'Text callouts for procs and stacks. The eye on a row lets you drag it, right-click the text to lock it again.')
		TextAlert(procs, { key = 'hunterKillCommand', frame = 'BUI_BuffTrackingHunterKC', title = 'Kill Command', description = 'Text alert when Kill Command procs', spell = 34026 })
		TextAlert(procs, { key = 'hunterCobraFang', frame = 'BUI_BuffTrackingHunterCF', title = 'Cobra Fang', description = 'Live tier set stack count, spent by Cobra Shot, up to 4', spell = 193455 })
		BestialWrath(Board('AoE burst', 'Bestial Wrath callouts for Wild Thrash.'))
	elseif Hunter.IsSurvivalHunter() then
		local procs = Board('Procs', 'Stacks and text callouts. The eye on a row lets you drag it, right-click the text to lock it again.')
		StackAlert(procs, { key = 'hunterTip', frame = 'BUI_BuffTrackingHunterTip', stacks = 3, title = 'Tip of the Spear', description = 'Stacks as bars or a number, up to 3', spell = 260286 })
		TextAlert(procs, { key = 'hunterRaptorSwipe', frame = 'BUI_BuffTrackingHunterRS', title = 'Raptor Swipe', description = 'Text alert while Raptor Swipe is active', spell = 1273155, textLabel = 'Text', altTextLabel = 'Text without Tip stacks' })
		TextAlert(procs, { key = 'hunterRaptorPrompt', frame = 'BUI_BuffTrackingHunterRaptorPrompt', title = 'Raptor Prompt', description = 'Reminder to cast Raptor Strike when nothing else is up', spell = 186270 })
		PackLeader(Board('Pack Leader', 'Beast cycle helpers for Pack Leader.'))
	elseif Hunter.IsMarksmanshipHunter() then
		local procs = Board('Procs', 'Text callouts for procs. The eye on a row lets you drag it, right-click the text to lock it again.')
		TextAlert(procs, { key = 'hunterPreciseShots', frame = 'BUI_BuffTrackingHunterPS', title = 'Precise Shots', description = 'Text alert while Precise Shots is active', spell = 260242 })
		TextAlert(procs, { key = 'hunterLockAndLoad', frame = 'BUI_BuffTrackingHunterLnL', title = 'Lock and Load', description = 'Text alert when Lock and Load procs', spell = 194594 })
		TextAlert(procs, { key = 'hunterBulletstorm', frame = 'BUI_BuffTrackingHunterBS', title = 'Bulletstorm', description = 'Empowered Aimed Shots left after Rapid Fire', spell = 389019 })
	end
	if Hunter.IsBeastMasteryOrSurvival() or Hunter.IsMarksmanshipHunter() then
		local utility = Board('Utility', 'Misdirection helpers.')
		SmartMisdirect(utility)
		TextAlert(utility, {
			key = 'misdirectAlert', frame = 'BUI_MisdirectAlert', title = 'Misdirect alert', description = 'On-screen text naming your current Misdirection target', spell = 34477, textLabel = 'Prefix',
			extra = function(alert, db, Refresh)
				alert:AddTools('When it shows', 'Flash it briefly or keep it up', {
					Option(db, 'Show', 'alertMode', { entries = ALERT_MODES }),
					{ tooltip = 'Flashing', title = 'When it shows', options = {
						Option(db, 'Flash for seconds', 'flashSeconds', { min = 1, max = 10, step = 1 }),
						Toggle(db, 'Flash on cast', 'flashOnCast'),
						Toggle(db, 'Flash on target change', 'flashOnTargetChange'),
					} },
				}, Refresh)
			end,
		})
	end
	if Monk.IsMistweaver() then
		TextAlert(Board('Mistweaver', 'Reminders for Mistweaver procs.'), { key = 'monkVivaciousVivification', frame = 'BUI_MonkVivaciousVivification', title = 'Vivacious Vivification', description = 'Reminder when your instant Vivify is ready', spell = 392883 })
	elseif Druid.IsRestoration() then
		local restoration = Board('Restoration', 'Reminders for Restoration upkeep and procs.')
		TextAlert(restoration, {
			key = 'druidLifebloom', frame = 'BUI_DruidLifebloom', title = 'Lifebloom refresh', description = 'REFRESH when your Lifebloom on anyone in the group is about to fall off', spell = 33763,
			textTiming = function(db) return { Seconds(db, 'refreshSeconds', 'Show at seconds left') } end,
			soundTiming = function(db) return { Seconds(db, 'soundSeconds', 'Play at seconds left') } end,
		})
		TextAlert(restoration, { key = 'druidClearcasting', frame = 'BUI_DruidClearcasting', title = 'Clearcasting', description = 'Text alert while Clearcasting makes your next Regrowth free', spell = 16870 })
	elseif Druid.IsFeral() then
		TextAlert(Board('Feral', 'Reminders for Feral procs.'), { key = 'druidClearcasting', frame = 'BUI_DruidClearcasting', title = 'Clearcasting', description = 'Text alert while Clearcasting makes your next Shred, Thrash or Swipe free', spell = 135700 })
	elseif Mage.IsArcane() then
		TextAlert(Board('Arcane', 'Stack callouts for Arcane. The eye on a row lets you drag it, right-click the text to lock it again.'), {
			key = 'mageArcaneSalvo', frame = 'BUI_MageArcaneSalvo', title = 'Arcane Salvo', description = 'Live stack count, built by Arcane Missiles and spent by Arcane Barrage', spell = 1242974, textLabel = 'Label',
		})
	end
	if #boards == 0 then
		Board('Class', 'Trackers for the buffs and procs of your spec.'):AddRow('Nothing for this spec yet', 'Hunters, Mistweaver Monks, Feral and Restoration Druids and Arcane Mages have class trackers')
	end
	return boards
end

local function Detail(ui, _, parent, width)
	local db = BUI.GetDB()[current.key]
	local boards = {}
	local function Board(title, description, buttons)
		boards[#boards + 1] = ui.Board(parent, width, { stacked = true, title = title, description = description, buttons = buttons })
		return boards[#boards]
	end
	current.build(db, Board, Refresher(current))
	return boards
end

BUI.BuffTrackingPage = { Class = Sections }

BUI.PageEngine.RegisterPage('classAlert', {
	title = 'Class alert',
	buttonText = 'Class alert',
	hidden = true,
	navParent = 'auras',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		sounds = BUI.BuildSoundDropdownItems()
		local db = BUI.GetDB()[current.key]
		local Refresh = Refresher(current)
		local tools = {
			{ text = 'Back to alerts', onClick = function() BUI.PageEngine.NavigateToID('auras') end },
			{ icon = 'enable', tooltip = 'Turn it on or off', get = function() return db.enabled == true end, set = function(value)
				db.enabled = value
				Refresh()
			end },
		}
		if current.eye then tools[#tools + 1] = current.eye(db, Refresh, current) end
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'glow',
			title = current.title,
			placeholder = 'Search ' .. current.title .. '...',
			tools = tools,
			tabs = { { label = current.title, build = Detail } },
		})
		page:AutoRefresh()
	end,
})

BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'BuffTrackingPage', function(_, unit)
	if unit ~= 'player' then return end
	C_Timer.After(0.3, function()
		local pageConfig = BUI.PageEngine.pages.auras
		if pageConfig.frame then pageConfig.stale = true end
		if BUI.PageEngine.GetCurrentPage() == 'auras' then BUI.PageEngine.RefreshCurrentPage() end
	end)
end)
