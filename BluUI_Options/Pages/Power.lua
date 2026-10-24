local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals, Widget = BUILib.Controls, BUILib.Layout, BUILib.Modals, BUILib.Widget
local Pixel = BUI.Pixel
local SafeNum = BUI.Tools.SafeNum

local PAGE_WIDTH = 960
local PREVIEW_HEIGHT = 120
local MENU_WIDTH = 150
local SOURCE_WIDTH = 200
local ORDER_WIDTH = 250
local COPY_WIDTH = 220
local OFFSET_RANGE = 50
local WHITE = 'Interface\\Buttons\\WHITE8x8'
local EVENT_KEY = 'Pages.PowerPreview'
local LABEL_KEY = 'Pages.PowerSourceLabels'

local PowerType = Enum.PowerType
local POWER_SOURCES = {
	{ value = PowerType.Mana, text = 'Mana' },
	{ value = PowerType.Rage, text = 'Rage' },
	{ value = PowerType.Focus, text = 'Focus' },
	{ value = PowerType.Energy, text = 'Energy' },
	{ value = PowerType.RunicPower, text = 'Runic Power' },
	{ value = PowerType.LunarPower, text = 'Astral Power' },
	{ value = PowerType.Maelstrom, text = 'Maelstrom' },
	{ value = PowerType.Insanity, text = 'Insanity' },
	{ value = PowerType.Fury, text = 'Fury' },
	{ value = PowerType.Pain, text = 'Pain' },
}
local POWER_NAMES = {}
for _, source in ipairs(POWER_SOURCES) do POWER_NAMES[source.value] = source.text end

local DRUID_FORMS = {
	{ label = 'Human form', form = 0 },
	{ label = 'Bear form', form = 5 },
	{ label = 'Cat form', form = 1 },
	{ label = 'Travel form', form = 3 },
	{ label = 'Moonkin form', form = 31 },
}
local DRUID_POWERS = {
	{ value = 'none', text = 'None' },
	{ value = PowerType.Mana, text = 'Mana' },
	{ value = PowerType.Rage, text = 'Rage' },
	{ value = PowerType.Energy, text = 'Energy' },
	{ value = PowerType.LunarPower, text = 'Astral Power' },
}
local DRUID_RESOURCES = {
	{ value = 'none', text = 'None' },
	{ value = 'combo', text = 'Combo Points' },
	{ value = 'casterMana', text = 'Mana' },
}
local SCOPES = {
	{ value = 'profile', text = 'Whole profile' },
	{ value = 'class', text = 'Per class' },
	{ value = 'spec', text = 'Per spec' },
}
local SCOPE_TAGS = { class = 'CLASS', spec = 'SPEC' }
local STACK_ORDERS = {
	{ value = 'primary,secondary,castbar', text = 'Primary, Secondary, Cast bar' },
	{ value = 'primary,castbar,secondary', text = 'Primary, Cast bar, Secondary' },
	{ value = 'secondary,primary,castbar', text = 'Secondary, Primary, Cast bar' },
	{ value = 'secondary,castbar,primary', text = 'Secondary, Cast bar, Primary' },
	{ value = 'castbar,primary,secondary', text = 'Cast bar, Primary, Secondary' },
	{ value = 'castbar,secondary,primary', text = 'Cast bar, Secondary, Primary' },
}
local CASTBAR_MODES = {
	{ value = 'collapse', text = 'Collapse when not casting' },
	{ value = 'hold', text = 'Hold the space when not casting' },
}
local STACK_TAGS = { BUI_Castbar_player = true, BUI_PowerBarAny = true }
local MEMBER_NAMES = { primary = 'Primary power', secondary = 'Secondary power' }
local KINDS = { primary = 'primary', secondary = 'secondary' }
local TAB_IDS = { 'primary', 'secondary', 'stacking' }

local selected = 'scope'
local preview
local editConfig
local copySource
local fonts
local autoLabels = {}

local Kit = BUI.OptionsKit
local Window, Repaint, RebuildPage, RebuildPane = Kit.Window, Kit.Repaint, Kit.RebuildPage, Kit.RebuildPane
local Setting, Option, Toggle, OnUnlessOff, Color = Kit.Setting, Kit.Option, Kit.Toggle, Kit.OnUnlessOff, Kit.Color

local function RefreshPreview()
	if preview then preview:Update() end
end

local function Stacked(key)
	return BUI.Power.Container.HasMember(key)
end

local function EditPreview()
	local Secondary = BUI.Power.Secondary
	local wanted = selected == 'secondary' and editConfig and Secondary.GetActiveConfig() ~= editConfig and not BUI.Power.GetSecondaryDB().locked
	Secondary.SetEditPreview(wanted and editConfig.id or nil)
end

local function RefreshAutoLabels()
	for _, refresh in pairs(autoLabels) do refresh() end
	local frame = BUI.PageEngine.frame
	if frame and frame:IsShown() then Repaint() end
end

BUI.Events:OnTalentBurst(LABEL_KEY, RefreshAutoLabels)
BUI.Events:Register('UPDATE_SHAPESHIFT_FORM', LABEL_KEY, RefreshAutoLabels)

local function ScopeInfo()
	local scope = BUI.Power.GetScope()
	if scope == 'spec' then
		local specIndex = C_SpecializationInfo.GetSpecialization()
		return scope, specIndex and select(2, C_SpecializationInfo.GetSpecializationInfo(specIndex))
	elseif scope == 'class' then
		return scope, (UnitClass('player'))
	end
	return scope
end

local function ScopeStatus()
	local scope, detail = ScopeInfo()
	if scope == 'spec' then return ('These settings apply to %s only, other specs keep their own.'):format(detail or 'this spec') end
	if scope == 'class' then return ('These settings apply to every %s on this profile.'):format(detail or 'character of this class') end
	return 'These settings apply to every character on this profile.'
end

local function Not(value) return not value end

local function Inverse(db, label, key)
	local option = Setting(db, label, key, Not)
	option.set = function(value) db[key] = not value end
	return option
end

local function Channels(db, prefix, label, alpha, fallback)
	local function Read(store)
		local red, green, blue = store[prefix .. 'R'], store[prefix .. 'G'], store[prefix .. 'B']
		if red == nil then red, green, blue = fallback() end
		return red, green, blue, alpha and store[prefix .. 'A'] or 1
	end
	local swatch = {
		kind = 'swatch', label = label, tooltip = label, opacity = alpha,
		get = function() return Read(db) end,
		set = function(red, green, blue, opacity)
			db[prefix .. 'R'], db[prefix .. 'G'], db[prefix .. 'B'] = red, green, blue
			if alpha then db[prefix .. 'A'] = opacity end
		end,
	}
	local factory = BUI.FactoryOf(db)
	if factory then swatch.default = function() return Read(factory) end end
	return swatch
end

local function StoreColor(key, label)
	return {
		kind = 'swatch', label = label, tooltip = label,
		get = function() return BUI.Colors.Get(key) end,
		set = function(red, green, blue)
			local color = BUI.Colors.GetStore()[key]
			color.r, color.g, color.b = red, green, blue
			BUI.ApplyColors()
		end,
		default = function() return BUI.Colors.Default(key) end,
	}
end

local function ResourceColor(db, config, label)
	local key = BUI.Colors.ResourceKey(config)
	if key and BUI.Colors.GetStore()[key] then return StoreColor(key, label) end
	return Channels(db, config.prefix .. 'Color', label)
end

local function FontMenu(key)
	local general = BUI.GetDB().general
	return { entries = fonts, width = MENU_WIDTH, get = function() return general[key] or BUI.C.GLOBAL_OPTION end, set = function(value)
		general[key] = value ~= BUI.C.GLOBAL_OPTION and value or nil
	end, default = function() return BUI.FactoryOf(general)[key] or BUI.C.GLOBAL_OPTION end }
end

local function TextIcon(title, options)
	return { icon = 'text', tooltip = 'Text', title = title, options = options }
end

local function Offsets(db, title, xKey, yKey, extra)
	local options = {
		Kit.Pixels(Option(db, 'Horizontal', xKey, { min = -OFFSET_RANGE, max = OFFSET_RANGE, step = 1 })),
		Kit.Pixels(Option(db, 'Vertical', yKey, { min = -OFFSET_RANGE, max = OFFSET_RANGE, step = 1 })),
	}
	for _, option in ipairs(extra or {}) do options[#options + 1] = option end
	return { icon = 'location', tooltip = 'Text offset', title = title, options = options }
end

local function Layer(db, key)
	return Option(db, 'Layer', key, { entries = BUI.C.STRATA_OPTIONS })
end

local function Eye(db, module, after)
	return { icon = 'eye', tooltip = 'Unlock to drag it, right-click it to lock', get = function() return not db.locked end, set = function(value)
		module.SetLocked(not value)
		if after then after() end
	end }
end

local function SourceEntries(auto, key)
	local entries = { { value = 'auto' } }
	for _, source in ipairs(POWER_SOURCES) do entries[#entries + 1] = { value = source.value, text = source.text } end
	entries[#entries + 1] = { value = 'none', text = 'None, hidden' }
	local function Refresh()
		local label = auto()
		entries[1].text = label and ('Automatic, ' .. label) or 'Automatic'
	end
	Refresh()
	autoLabels[key] = Refresh
	return entries
end

local function Source(db, entries, after)
	local factory = BUI.FactoryOf(db)
	return { entries = entries, width = SOURCE_WIDTH, get = function() return db.source or 'auto' end, set = function(value)
		db.source = value ~= 'auto' and value or nil
		if after then after() end
	end, default = function() return factory.source or 'auto' end }
end

local function Enabled(db, module)
	local switch = Toggle(db, nil, 'enabled')
	switch.set = function(value) module.Toggle(value) end
	return switch
end

local function PositionFor(db, isText, selfTag)
	return BUI.PositionTool(BUI.Anchor.ModePos(db, isText), { selfTag = selfTag, matchWidth = true })
end

local function TickRow(board, db, Apply)
	local editor
	local function Refresh()
		Apply()
		editor.Refresh()
	end
	board:AddTools('Tick marks', 'Click the track to add a marker, drag markers to move them', {
		{ build = function(parent)
			editor = Widget.Unwrap(Controls.TickEditor(parent, {
				get = function() return db.tickMarks end,
				color = function()
					local color = db.tickMarkColor
					return color[1], color[2], color[3], color[4]
				end,
				width = function() return db.tickMarkWidth end,
				onChange = Apply,
			}))
			return editor
		end },
		Color(db, 'Tick color', 'tickMarkColor'),
		{ tooltip = 'Width', title = 'Tick marks', options = { Option(db, 'Tick width', 'tickMarkWidth', { min = 1, max = 4, step = 1 }) } },
		{ icon = 'erase', size = Layout.ERASE_SIZE, tooltip = 'Clear every tick mark', hover = 'danger', onClick = function()
			wipe(db.tickMarks)
			Refresh()
		end },
	}, Refresh)
end

local function LowPowerRow(board, db, Apply)
	board:AddTools('Low power colors', 'Recolor the bar as power runs out', {
		Channels(db, 'medPowerColor', 'Medium'),
		Channels(db, 'lowPowerColor', 'Low'),
		{ tooltip = 'Thresholds', title = 'Low power', options = {
			Option(db, 'Low below %', 'lowPowerThreshold', { min = 5, max = 95, step = 1 }),
			Option(db, 'Medium below %', 'highPowerThreshold', { min = 5, max = 95, step = 1 }),
		} },
		Toggle(db, nil, 'lowPowerEnabled'),
	}, Apply)
end

local function DruidBoard(ui, parent, width, db, Apply, key, choices, auto)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Druid forms',
		description = key == 'formPowerOverrides' and 'Which power the primary bar shows in each form.' or 'Which resource the secondary bar shows in each form.',
	})
	local overrides = db[key]
	for _, form in ipairs(DRUID_FORMS) do
		local entries = { { value = 'auto', text = 'Automatic, ' .. auto(form.form) } }
		for _, choice in ipairs(choices) do entries[#entries + 1] = choice end
		board:AddTools(form.label, nil, {
			{ entries = entries, width = SOURCE_WIDTH, get = function() return overrides[form.form] or 'auto' end, set = function(value)
				overrides[form.form] = value ~= 'auto' and value or nil
			end },
		}, Apply)
	end
	return board
end

local function PrimaryBoards(ui, parent, width, page)
	local Primary = BUI.Power.Primary
	local db = BUI.Power.GetPrimaryDB()
	BUI.SetFactory(db, BUI.ExportImport.FactoryProfile().powerBar)
	local function Apply()
		Primary.Apply()
		RefreshPreview()
	end
	BUI.OnModuleChange('powerBar', Repaint)
	local stacked = Stacked('primary')
	local board = BUI.ResetBoard(ui, ui.Board(parent, width, {
		stacked = true,
		title = 'Primary power',
		description = 'Whatever your spec runs on. The eye lets you drag it, right-click the bar to lock it again.',
	}))
	local tools = {
		Source(db, SourceEntries(function() return POWER_NAMES[BUI.ClassPowers.GetAutoPowerType()] end, 'primary')),
	}
	if not stacked then tools[#tools + 1] = PositionFor(db, not db.barMode, 'BUI_PowerBar') end
	tools[#tools + 1] = Eye(db, Primary)
	tools[#tools + 1] = Enabled(db, Primary)
	board:AddTools('Primary bar', stacked and 'Source and on or off, its position comes from Stacking' or 'Source, position and on or off', tools, Apply)
	board:AddSwitch('Bar instead of a number', function() return db.barMode == true end, function(value)
		db.barMode = value
		Apply()
		RebuildPane(page)
	end, 'Off shows the plain value as text')
	if db.barMode then
		board:AddSwitch('Class color', function() return db.classColorPower == true end, function(value)
			db.classColorPower = value
			Apply()
		end, 'Color the bar by your class instead of the power type')
		local colorKey = BUI.Colors.PowerKey((BUI.ClassPowers.GetPrimaryPowerType()))
		board:AddTools('Bar', 'Colors and size', {
			colorKey and StoreColor(colorKey, 'Bar color') or Channels(db, 'barColor', 'Bar color'),
			Channels(db, 'barBgColor', 'Background', true),
			{ tooltip = 'Size', title = 'Bar', options = {
				Option(db, 'Width', 'barWidth', { min = 50, max = 400, step = 1 }),
				Option(db, 'Height', 'barHeight', { min = 4, max = 40, step = 1 }),
			} },
		}, Apply)
		board:AddTools('Prediction', 'Incoming power while you cast', {
			Channels(db, 'predictionColor', 'Prediction color', true),
			OnUnlessOff(db, nil, 'showPrediction'),
		}, Apply)
		TickRow(board, db, Apply)
		board:AddTools('Bar text', 'The value on the bar', {
			Channels(db, 'barTextColor', 'Text color'),
			FontMenu('powerFont'),
			TextIcon('Bar text', {
				Option(db, 'Text size', 'barTextSize', { min = 8, max = 50, step = 1 }),
				Inverse(db, 'Percent sign', 'hidePercentSign'),
				Layer(db, 'textStrata'),
			}),
			Offsets(db, 'Bar text', 'barTextOffsetX', 'barTextOffsetY', { Toggle(db, 'Above the bar', 'barTextAbove') }),
			Inverse(db, nil, 'barHideText'),
		}, Apply)
	else
		board:AddTools('Text', 'Size, color and font of the number', {
			Channels(db, 'textColor', 'Text color'),
			FontMenu('powerFont'),
			TextIcon('Text', {
				Option(db, 'Text size', 'textSize', { min = 10, max = 50, step = 1 }),
				Inverse(db, 'Percent sign', 'hidePercentSign'),
				Layer(db, 'frameStrata'),
			}),
		}, Apply)
	end
	LowPowerRow(board, db, Apply)
	local boards = { board }
	if BUI.ClassPowers.IsDruid() then
		db.formPowerOverrides = db.formPowerOverrides or {}
		boards[#boards + 1] = DruidBoard(ui, parent, width, db, Apply, 'formPowerOverrides', DRUID_POWERS, function(form)
			return POWER_NAMES[BUI.ClassPowers.GetDruidAutoPowerForForm(form)]
		end)
	end
	return boards
end

local function DruidSecondaryAuto(form)
	if form == 1 then return 'Combo Points' end
	if BUI.ClassPowers.IsBalance() then return 'Mana' end
	return 'None'
end

local function SecondaryBoards(ui, parent, width, page)
	local Secondary = BUI.Power.Secondary
	local db = BUI.Power.GetSecondaryDB()
	BUI.SetFactory(db, BUI.ExportImport.FactoryProfile().secondaryPower)
	local function Apply()
		Secondary.Apply()
		RefreshPreview()
	end
	BUI.OnModuleChange('secondaryPower', Repaint)
	local available = Secondary.GetConfigsForClass()
	local config = Secondary.GetActiveConfig() or available[1]
	editConfig = config
	local stacked = Stacked('secondary')
	local board = BUI.ResetBoard(ui, ui.Board(parent, width, {
		stacked = true,
		title = 'Secondary power',
		description = config and (config.label .. ' and the other class resources. The eye lets you drag it, right-click the bar to lock it again.') or 'Your class has no secondary resource, only a manual source shows here.',
	}))
	local function AutoLabel()
		for _, candidate in ipairs(available) do
			if candidate.check() then return candidate.label end
		end
	end
	local prefix = config and config.prefix
	local isBar = config and config.mode == 'bar'
	local isRunes = config and config.id == 'runes'
	local isStagger = config and config.id == 'stagger'
	local textOnly = false
	if config then
		if isRunes then textOnly = db.runeNumberOnly == true
		elseif isBar then textOnly = not db[prefix .. 'BarMode']
		else textOnly = db[prefix .. 'NumberOnly'] == true end
	end
	local tools = { Source(db, SourceEntries(AutoLabel, 'secondary'), function()
		if db.source == PowerType.Mana then db.overrideShowPercent = true end
		RebuildPane(page)
	end) }
	if config and not stacked then tools[#tools + 1] = PositionFor(db, textOnly, 'BUI_SecondaryPower') end
	tools[#tools + 1] = Eye(db, Secondary, EditPreview)
	tools[#tools + 1] = Enabled(db, Secondary)
	board:AddTools('Secondary bar', stacked and 'Source and on or off, its position comes from Stacking' or 'Source, position and on or off', tools, Apply)
	if not config then return { board } end

	local segmented = isRunes or not isBar
	local modeGet, modeSet
	if isRunes then
		modeGet = function() return not db.runeNumberOnly end
		modeSet = function(value) db.runeNumberOnly = not value end
	elseif isBar then
		modeGet = function() return db[prefix .. 'BarMode'] == true end
		modeSet = function(value) db[prefix .. 'BarMode'] = value end
	else
		modeGet = function() return not db[prefix .. 'NumberOnly'] end
		modeSet = function(value) db[prefix .. 'NumberOnly'] = not value end
	end
	board:AddSwitch(segmented and 'Segments instead of a number' or 'Bar instead of a number', modeGet, function(value)
		modeSet(value)
		Apply()
		RebuildPane(page)
	end, 'Off shows the plain value as text')

	if not textOnly then
		if isRunes then
			board:AddTools('Runes', 'Colors, size and spacing', {
				Channels(db, 'runeColor', 'Ready'),
				Channels(db, 'runeRechargingColor', 'Recharging'),
				Channels(db, 'runeBgColor', 'Background', true),
				{ tooltip = 'Size and spacing', title = 'Runes', options = {
					Option(db, 'Width', 'runeTotalWidth', { min = 100, max = 400, step = 1 }),
					Option(db, 'Height', 'runeHeight', { min = 4, max = 30, step = 1 }),
					Option(db, 'Spacing', 'runeSpacing', { min = 0, max = 20, step = 1 }),
				} },
			}, Apply)
		elseif isStagger then
			board:AddTools('Bar', 'Stagger colors and size', {
				Channels(db, 'staggerLightColor', 'Light, under 30%'),
				Channels(db, 'staggerModerateColor', 'Moderate, 30 to 60%'),
				Channels(db, 'staggerHeavyColor', 'Heavy, 60% and up'),
				Channels(db, 'staggerBgColor', 'Background', true),
				{ tooltip = 'Size', title = 'Bar', options = {
					Option(db, 'Width', 'staggerBarWidth', { min = 50, max = 400, step = 1 }),
					Option(db, 'Height', 'staggerBarHeight', { min = 4, max = 40, step = 1 }),
				} },
			}, Apply)
		elseif isBar then
			board:AddTools('Bar', 'Colors and size', {
				ResourceColor(db, config, 'Bar color'),
				Channels(db, prefix .. 'BgColor', 'Background', true),
				{ tooltip = 'Size', title = 'Bar', options = {
					Option(db, 'Width', prefix .. 'BarWidth', { min = 50, max = 400, step = 1 }),
					Option(db, 'Height', prefix .. 'BarHeight', { min = 4, max = 40, step = 1 }),
				} },
			}, Apply)
			TickRow(board, db, Apply)
		else
			local style = {
				ResourceColor(db, config, 'Active color'),
				Channels(db, prefix .. 'BgColor', 'Background', true),
			}
			if prefix == 'combo' then table.insert(style, 2, Channels(db, 'comboChargedColor', 'Charged')) end
			style[#style + 1] = { tooltip = 'Size and spacing', title = 'Segments', options = {
				Option(db, 'Width', prefix .. 'TotalWidth', { min = 100, max = 400, step = 1 }),
				Option(db, 'Height', prefix .. 'Height', { min = 4, max = 30, step = 1 }),
				Option(db, 'Spacing', prefix .. 'Spacing', { min = 0, max = 20, step = 1 }),
			} }
			board:AddTools('Segments', 'Colors, size and spacing', style, Apply)
		end
	end

	local function ClassColorCell()
		board:AddSwitch('Class color', function() return db.useClassColor ~= false end, function(value)
			db.useClassColor = value
			Apply()
		end, 'Color the number by your class resource')
	end
	if isRunes then
		if textOnly then
			ClassColorCell()
			board:AddTools('Text', 'Size, color and font of the number', {
				Channels(db, 'runeTextColor', 'Text color'),
				FontMenu('secondaryPowerFont'),
				TextIcon('Text', {
					Option(db, 'Text size', 'runeTextSize', { min = 10, max = 50, step = 1 }),
					Toggle(db, 'Show the maximum', 'runeShowMax'),
					Layer(db, 'textStrata'),
				}),
			}, Apply)
		else
			board:AddTools('Rune cooldown', 'Countdown on recharging runes', {
				Channels(db, 'runeCooldownColor', 'Text color'),
				FontMenu('secondaryPowerFont'),
				TextIcon('Rune cooldown', {
					Option(db, 'Text size', 'runeCooldownSize', { min = 6, max = 20, step = 1 }),
					Layer(db, 'textStrata'),
				}),
				Toggle(db, nil, 'showRuneCooldown'),
			}, Apply)
		end
	elseif isStagger then
		if textOnly then
			ClassColorCell()
			board:AddTools('Text', 'Size, color and font', {
				Channels(db, 'staggerTextColor', 'Text color'),
				FontMenu('secondaryPowerFont'),
				TextIcon('Text', {
					OnUnlessOff(db, 'Show the value', 'staggerShowValue'),
					OnUnlessOff(db, 'Show the percent', 'staggerShowPercent'),
					Option(db, 'Text size', 'textSize', { min = 10, max = 50, step = 1 }),
					Layer(db, 'textStrata'),
				}),
			}, Apply)
		else
			board:AddTools('Bar text', 'The stagger value on the bar', {
				Channels(db, 'staggerValueColor', 'Text color'),
				FontMenu('secondaryPowerFont'),
				TextIcon('Bar text', {
					OnUnlessOff(db, 'Show the value', 'staggerShowValue'),
					OnUnlessOff(db, 'Show the percent', 'staggerShowPercent'),
					Option(db, 'Text size', 'staggerValueSize', { min = 8, max = 50, step = 1 }),
					Layer(db, 'textStrata'),
				}),
				Offsets(db, 'Bar text', 'staggerValueOffsetX', 'staggerValueOffsetY'),
				Inverse(db, nil, 'staggerHideBarText'),
			}, Apply)
		end
	elseif isBar then
		if textOnly then
			ClassColorCell()
			board:AddTools('Text', 'Size, color and font of the number', {
				Channels(db, prefix .. 'TextColor', 'Text color', nil, function() return Secondary.GetBarColor(config) end),
				FontMenu('secondaryPowerFont'),
				TextIcon('Text', {
					Toggle(db, 'Show the percent', prefix .. 'ShowPercent'),
					Option(db, 'Text size', 'textSize', { min = 10, max = 50, step = 1 }),
					Layer(db, 'textStrata'),
				}),
			}, Apply)
		else
			board:AddTools('Bar text', 'The value on the bar', {
				Channels(db, prefix .. 'ValueColor', 'Text color'),
				FontMenu('secondaryPowerFont'),
				TextIcon('Bar text', {
					Toggle(db, 'Show the percent', prefix .. 'ShowPercent'),
					Toggle(db, 'Hide the percent sign', prefix .. 'HidePercentSign'),
					Option(db, 'Text size', prefix .. 'ValueSize', { min = 8, max = 50, step = 1 }),
					Layer(db, 'textStrata'),
				}),
				Offsets(db, 'Bar text', prefix .. 'ValueOffsetX', prefix .. 'ValueOffsetY'),
				Inverse(db, nil, prefix .. 'HideBarText'),
			}, Apply)
		end
		LowPowerRow(board, db, Apply)
	else
		if textOnly then
			ClassColorCell()
			board:AddTools('Text', 'Size, color and font of the number', {
				Channels(db, prefix .. 'TextColor', 'Text color', nil, function() return Secondary.GetResourceColor(config) end),
				FontMenu('secondaryPowerFont'),
				TextIcon('Text', {
					Toggle(db, 'Show the maximum', prefix .. 'ShowMax'),
					Option(db, 'Text size', 'textSize', { min = 10, max = 50, step = 1 }),
					Layer(db, 'textStrata'),
				}),
			}, Apply)
		else
			board:AddTools('Count', 'The number on the segments', {
				Channels(db, prefix .. 'ValueColor', 'Text color'),
				FontMenu('secondaryPowerFont'),
				TextIcon('Count', {
					Option(db, 'Text size', prefix .. 'CenterTextSize', { min = 8, max = 50, step = 1 }),
					Layer(db, 'textStrata'),
				}),
				Offsets(db, 'Count', prefix .. 'ValueOffsetX', prefix .. 'ValueOffsetY'),
				Inverse(db, nil, prefix .. 'HideBarText'),
			}, Apply)
		end
	end
	local boards = { board }
	if BUI.ClassPowers.IsDruid() then
		db.formOverrides = db.formOverrides or {}
		boards[#boards + 1] = DruidBoard(ui, parent, width, db, Apply, 'formOverrides', DRUID_RESOURCES, DruidSecondaryAuto)
	end
	return boards
end

local function TextModeMembers(settings, onlyKey)
	local issues = {}
	if settings.attached.primary and (not onlyKey or onlyKey == 'primary') then
		local db = BUI.Power.GetPrimaryDB()
		if db.enabled and db.source ~= 'none' and not db.barMode then issues[#issues + 1] = 'primary' end
	end
	if settings.attached.secondary and (not onlyKey or onlyKey == 'secondary') then
		local db = BUI.Power.GetSecondaryDB()
		local config = BUI.Power.Secondary.GetDisplayConfig()
		if db.enabled and config then
			local textMode
			if config.id == 'runes' then textMode = db.runeNumberOnly
			elseif config.mode == 'bar' then textMode = not db[config.prefix .. 'BarMode']
			else textMode = db[config.prefix .. 'NumberOnly'] end
			if textMode then issues[#issues + 1] = 'secondary' end
		end
	end
	return issues
end

local function SwitchToBars(issues)
	for _, key in ipairs(issues) do
		if key == 'primary' then
			BUI.Power.GetPrimaryDB().barMode = true
		else
			local db = BUI.Power.GetSecondaryDB()
			local config = BUI.Power.Secondary.GetDisplayConfig()
			if config.id == 'runes' then db.runeNumberOnly = false
			elseif config.mode == 'bar' then db[config.prefix .. 'BarMode'] = true
			else db[config.prefix .. 'NumberOnly'] = false end
		end
	end
end

local function ConfirmBars(issues, onConfirm)
	local names = {}
	for index, key in ipairs(issues) do names[index] = MEMBER_NAMES[key] end
	Modals.Confirm({
		parent = Window().frame,
		title = 'Text does not stack',
		message = table.concat(names, ' and ') .. (#names > 1 and ' are' or ' is') .. ' shown as text, which cannot line up in a stack of bars. Switch to bars and continue?',
		confirmText = 'Use bars', cancelText = 'Cancel',
		onConfirm = function()
			SwitchToBars(issues)
			onConfirm()
			RebuildPage()
		end,
		onCancel = Repaint,
	})
end

local function StackingBoard(ui, parent, width)
	local Container = BUI.Power.Container
	local settings = Container.GetDB()
	local shipped = BUI.ExportImport.FactoryProfile().powerBar.stackLab
	BUI.SetFactory(settings, shipped)
	local function Apply()
		if Container.IsEnabled() then Container.ApplyAll() end
		RefreshPreview()
	end
	BUI.OnModuleChange('powerStack', Repaint)
	local board = BUI.ResetBoard(ui, ui.Board(parent, width, {
		stacked = true,
		title = 'Stacking',
		description = 'Stack the power bars and your cast bar into one container that moves as a unit. The eye lets you drag it, right-click it to lock it again.',
	}))
	local frames = {}
	for _, frame in ipairs(BUI.C.ANCHOR_FRAMES) do
		if not STACK_TAGS[frame.tag] then frames[#frames + 1] = frame end
	end
	local enabled = Toggle(settings, nil, 'enabled')
	enabled.set = function(value)
		if value then
			local issues = TextModeMembers(settings)
			if #issues > 0 then return ConfirmBars(issues, function() Container.SetEnabled(true) end) end
		end
		Container.SetEnabled(value)
	end
	board:AddTools('Stack', 'Position, width and gap', {
		BUI.PositionTool(settings, { frames = frames, matchWidth = true }),
		{ tooltip = 'Width and gap', title = 'Stack', options = {
			Option(settings, 'Width', 'width', { min = 60, max = 600, step = 1 }),
			Option(settings, 'Gap', 'gap', { min = -10, max = 40, step = 1 }),
			Toggle(settings, 'Match member widths', 'matchWidth'),
		} },
		Eye(settings, Container),
		enabled,
	}, Apply)
	board:AddTools('Order', 'Top to bottom', {
		{ entries = STACK_ORDERS, width = ORDER_WIDTH, get = function() return table.concat(settings.order, ',') end, set = function(value)
			local order = {}
			for key in value:gmatch('[^,]+') do order[#order + 1] = key end
			settings.order = order
		end, default = function() return table.concat(shipped.order, ',') end },
	}, Apply)
	local function Attach(key, value)
		if value and settings.enabled then
			settings.attached[key] = true
			local issues = TextModeMembers(settings, key)
			if #issues > 0 then
				settings.attached[key] = false
				return ConfirmBars(issues, function() settings.attached[key] = true end)
			end
		end
		settings.attached[key] = value
		Apply()
	end
	board:AddSwitch('Primary power bar', function() return settings.attached.primary == true end, function(value) Attach('primary', value) end, 'Whatever your spec runs on')
	board:AddSwitch('Secondary power bar', function() return settings.attached.secondary == true end, function(value) Attach('secondary', value) end, 'Combo points, holy power, soul shards and the other class resources')
	board:AddTools('Player cast bar', 'Slot your cast bar into the stack', {
		Option(settings, nil, 'castbarMode', { entries = CASTBAR_MODES, width = ORDER_WIDTH }),
		Toggle(settings.attached, nil, 'castbar'),
	}, Apply)
	return board
end

local function ScopeBoard(ui, parent, width)
	local Power = BUI.Power
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Scope',
		description = ScopeStatus(),
	})
	board:AddTools('Save power settings', 'Shared across the whole profile, or a separate setup per spec or class', {
		{ entries = SCOPES, width = MENU_WIDTH, get = Power.GetScope, set = function(value)
			Power.SetScope(value)
			RebuildPage()
		end },
	})
	local sources = Power.ListCopySources()
	if #sources > 0 then
		local found = false
		for _, source in ipairs(sources) do
			if source.value == copySource then found = true end
		end
		if not found then copySource = sources[1].value end
		board:AddTools('Copy power setup', 'Overwrite this setup with the one saved for another spec or class', {
			{ entries = sources, width = COPY_WIDTH, get = function() return copySource end, set = function(value) copySource = value end },
			{ text = 'Copy', onClick = function()
				local sourceText = copySource
				for _, source in ipairs(sources) do
					if source.value == copySource then sourceText = source.text end
				end
				local _, detail = ScopeInfo()
				Modals.Confirm({
					parent = Window().frame,
					title = 'Copy power setup',
					message = ('Overwrite the %s power setup with the one saved for %s?'):format(detail or 'current', sourceText),
					confirmText = 'Copy', cancelText = 'Cancel',
					onConfirm = function()
						if Power.CopyFrom(copySource) then RebuildPage() end
					end,
				})
			end },
		})
	else
		board:AddRow('Copy power setup', 'Nothing to copy from yet, other specs or classes have no saved setup')
	end
	board:AddTools('Power and resource colors', 'Bar colors for every power type and class resource', {
		{ text = 'Open Appearance', onClick = BUI.OpenAppearance },
	})
	return board
end

local function BuildPreview(band, kit)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetAllPoints()
	stage:SetClipsChildren(true)
	local kind = 'general'

	local function PreviewFont()
		return kind == 'primary' and BUI.GetPowerFont() or BUI.GetSecondaryPowerFont()
	end

	local function ResolveSecondaryConfig()
		local Secondary = BUI.Power.Secondary
		local settings = BUI.Power.GetSecondaryDB()
		local config = Secondary.GetActiveConfig()
		local previewID = Secondary.GetEditPreview()
		if previewID and editConfig and editConfig.id == previewID then config = editConfig end
		if settings.source == 'none' then config = nil end
		return config, settings
	end

	local QueueUpdate = BUI.Dispatcher.New(function()
		if band:IsVisible() then band:Update() end
	end)

	band:HookScript('OnShow', function()
		BUI.Events:RegisterUnit('UNIT_POWER_FREQUENT', 'player', EVENT_KEY, QueueUpdate)
		BUI.Events:RegisterUnit('UNIT_POWER_POINT_CHARGE', 'player', EVENT_KEY, QueueUpdate)
		BUI.Events:RegisterUnit('UNIT_MAXPOWER', 'player', EVENT_KEY, QueueUpdate)
		BUI.Events:RegisterUnit('UNIT_DISPLAYPOWER', 'player', EVENT_KEY, QueueUpdate)
		BUI.Events:RegisterUnit('UNIT_AURA', 'player', EVENT_KEY, QueueUpdate)
		BUI.Events:Register('RUNE_POWER_UPDATE', EVENT_KEY, QueueUpdate)
		QueueUpdate()
	end)
	band:HookScript('OnHide', function()
		BUI.Events:UnregisterAll(EVENT_KEY)
	end)

	local bar = CreateFrame('Frame', nil, stage)
	bar:SetPoint('CENTER')
	local barBg = bar:CreateTexture(nil, 'BACKGROUND')
	barBg:SetTexture(WHITE)
	barBg:SetAllPoints()
	local barFill = bar:CreateTexture(nil, 'ARTWORK')
	barFill:SetTexture(WHITE)
	barFill:SetPoint('TOPLEFT')
	barFill:SetPoint('BOTTOMLEFT')
	local barPredict = bar:CreateTexture(nil, 'ARTWORK')
	barPredict:SetTexture(WHITE)
	barPredict:SetPoint('TOPLEFT', barFill, 'TOPRIGHT')
	barPredict:SetPoint('BOTTOMLEFT', barFill, 'BOTTOMRIGHT')
	local barText = bar:CreateFontString(nil, 'OVERLAY')

	local ticks = {}
	local function Tick(index)
		if not ticks[index] then
			ticks[index] = bar:CreateTexture(nil, 'OVERLAY')
			ticks[index]:SetTexture(WHITE)
		end
		return ticks[index]
	end

	local bigText = stage:CreateFontString(nil, 'OVERLAY')
	bigText:SetPoint('CENTER')

	local segmentFills, segmentBackgrounds, segmentBorders = {}, {}, {}
	local function Segment(index)
		if not segmentFills[index] then
			segmentBorders[index] = stage:CreateTexture(nil, 'BACKGROUND')
			segmentBorders[index]:SetTexture(WHITE)
			segmentBackgrounds[index] = stage:CreateTexture(nil, 'BORDER')
			segmentBackgrounds[index]:SetTexture(WHITE)
			segmentFills[index] = stage:CreateTexture(nil, 'ARTWORK')
			segmentFills[index]:SetTexture(WHITE)
		end
		return segmentFills[index], segmentBackgrounds[index], segmentBorders[index]
	end
	local segmentText = stage:CreateFontString(nil, 'OVERLAY')
	local cooldownText = stage:CreateFontString(nil, 'OVERLAY')

	local stackBars = {}
	local function StackBar(index)
		if not stackBars[index] then
			local member = {}
			member.border = stage:CreateTexture(nil, 'BACKGROUND')
			member.border:SetTexture(WHITE)
			member.bg = stage:CreateTexture(nil, 'BORDER')
			member.bg:SetTexture(WHITE)
			member.fill = stage:CreateTexture(nil, 'ARTWORK')
			member.fill:SetTexture(WHITE)
			member.text = stage:CreateFontString(nil, 'OVERLAY')
			stackBars[index] = member
		end
		return stackBars[index]
	end

	local function HideAll()
		bar:Hide()
		bigText:Hide()
		segmentText:Hide()
		cooldownText:Hide()
		for _, texture in ipairs(segmentFills) do texture:Hide() end
		for _, texture in ipairs(segmentBackgrounds) do texture:Hide() end
		for _, texture in ipairs(segmentBorders) do texture:Hide() end
		for _, member in pairs(stackBars) do
			member.border:Hide()
			member.bg:Hide()
			member.fill:Hide()
			member.text:Hide()
		end
	end

	local function ShowBar(options)
		bar:SetSize(options.w, options.h)
		local fillWidth = math.max(0.5, options.w * math.min(1, math.max(0, options.frac)))
		barFill:SetWidth(fillWidth)
		barFill:SetVertexColor(options.r, options.g, options.b, 1)
		local background = options.bg
		barBg:SetVertexColor(background[1], background[2], background[3], background[4])
		if options.predict then
			barPredict:SetWidth(math.max(0.5, math.min(options.w - fillWidth, options.w * 0.15)))
			barPredict:SetVertexColor(options.predict[1], options.predict[2], options.predict[3], options.predict[4])
			barPredict:Show()
		else
			barPredict:Hide()
		end
		local tickColor = options.tickColor
		for index, percent in ipairs(options.ticks) do
			local tick = Tick(index)
			tick:SetSize(options.tickWidth, options.h)
			tick:ClearAllPoints()
			tick:SetPoint('CENTER', bar, 'LEFT', options.w * (percent / 100), 0)
			tick:SetVertexColor(tickColor[1], tickColor[2], tickColor[3], tickColor[4])
			tick:Show()
		end
		for index = #options.ticks + 1, #ticks do ticks[index]:Hide() end
		if options.text then
			Pixel.ApplyFont(barText, options.textSize, PreviewFont())
			barText:SetText(options.text)
			barText:SetTextColor(options.tr, options.tg, options.tb, 1)
			barText:ClearAllPoints()
			if options.textAbove then
				barText:SetPoint('BOTTOM', bar, 'TOP', options.textX, 2 + options.textY)
			else
				barText:SetPoint('CENTER', bar, 'CENTER', options.textX, options.textY)
			end
			barText:Show()
		else
			barText:Hide()
		end
		bar:Show()
	end

	local function ShowText(text, size, red, green, blue)
		Pixel.ApplyFont(bigText, size, PreviewFont())
		bigText:SetText(text)
		bigText:SetTextColor(red, green, blue, 1)
		bigText:Show()
	end

	local function ShowSegments(totalWidth, count, height, spacing, background, FillColor, offsetY)
		offsetY = offsetY or 0
		local db = BUI.Power.GetSecondaryDB()
		local edge = Pixel.ClampBorder(db.borderSize)
		local borderColor = db.borderColor
		local visualGap = spacing == 0 and -edge or spacing
		local segmentWidth = math.max(edge * 2 + 1, (totalWidth - (count - 1) * spacing) / count)
		local innerWidth = math.max(0.5, segmentWidth - edge * 2)
		local innerHeight = math.max(0.5, height - edge * 2)
		local rowWidth = count * segmentWidth + (count - 1) * visualGap
		local x = -rowWidth / 2
		for index = 1, count do
			local fill, backdrop, border = Segment(index)
			border:SetSize(segmentWidth, height)
			border:ClearAllPoints()
			border:SetPoint('LEFT', stage, 'CENTER', x, offsetY)
			border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
			border:Show()
			backdrop:SetSize(innerWidth, innerHeight)
			backdrop:ClearAllPoints()
			backdrop:SetPoint('LEFT', stage, 'CENTER', x + edge, offsetY)
			backdrop:SetVertexColor(background[1], background[2], background[3], background[4])
			backdrop:Show()
			local red, green, blue, alpha, fraction = FillColor(index)
			fill:SetSize(math.max(0.5, innerWidth * math.min(1, fraction or 1)), innerHeight)
			fill:ClearAllPoints()
			fill:SetPoint('LEFT', stage, 'CENTER', x + edge, offsetY)
			fill:SetVertexColor(red, green, blue, alpha or 1)
			fill:Show()
			x = x + segmentWidth + visualGap
		end
		return segmentWidth
	end

	local function FormatBarValue(settings, prefix, value, percent)
		if settings[prefix .. 'ShowPercent'] == true then return percent .. '%' end
		if settings[prefix .. 'ShowValue'] ~= false then return tostring(value) end
		return nil
	end

	local function SecondaryTextColor(settings, config)
		if settings.useClassColor then return BUI.Power.Secondary.GetResourceColor(config) end
		if config.id == 'runes' then return settings.runeTextColorR, settings.runeTextColorG, settings.runeTextColorB end
		if config.id == 'stagger' then return settings.staggerTextColorR, settings.staggerTextColorG, settings.staggerTextColorB end
		local prefix = config.prefix
		local red, green, blue = BUI.Power.Secondary.GetResourceColor(config)
		return settings[prefix .. 'TextColorR'] or red, settings[prefix .. 'TextColorG'] or green, settings[prefix .. 'TextColorB'] or blue
	end

	local function LowPowerTint(settings, percent, red, green, blue)
		if percent < settings.lowPowerThreshold then return settings.lowPowerColorR, settings.lowPowerColorG, settings.lowPowerColorB end
		if percent < settings.highPowerThreshold then return settings.medPowerColorR, settings.medPowerColorG, settings.medPowerColorB end
		return red, green, blue
	end

	local function LiveValue(config)
		if config.check and not config.check() then return nil, nil end
		local value, maxValue
		if config.getValue then
			value, maxValue = config.getValue()
		elseif config.power then
			value, maxValue = UnitPower('player', config.power), UnitPowerMax('player', config.power)
		end
		return SafeNum(value), SafeNum(maxValue)
	end

	local function PrimaryColor(db, powerType)
		if db.classColorPower then
			local classColor = RAID_CLASS_COLORS[select(2, UnitClass('player'))]
			if classColor then return classColor.r, classColor.g, classColor.b end
		end
		local colorKey = BUI.Colors.PowerKey(powerType)
		if colorKey then return BUI.Colors.Get(colorKey) end
		return db.barColorR, db.barColorG, db.barColorB
	end

	local function ShowStacked()
		local containerDb = BUI.Power.Container.GetDB()
		local order = containerDb.order
		local gap = containerDb.gap
		local primaryDb = BUI.Power.GetPrimaryDB()
		local secondaryDb = BUI.Power.GetSecondaryDB()
		local Secondary = BUI.Power.Secondary
		local config = Secondary.GetDisplayConfig()

		local function MemberOn(key)
			if not containerDb.attached[key] then return false end
			if key == 'castbar' then return BUI.CastBar.GetSettings('player').enabled == true end
			if key == 'primary' then
				return primaryDb.enabled and primaryDb.source ~= 'none' and not BUI.ClassPowers.IsPrimaryHiddenForForm()
			end
			return secondaryDb.enabled and Secondary.HasSecondary()
		end

		local members = {}
		for _, key in ipairs(order) do
			if MemberOn(key) then
				if key == 'castbar' then
					local castbar = BUI.CastBar.GetSettings('player')
					members[#members + 1] = { w = castbar.width, h = castbar.height, r = 1, g = 0.72, b = 0.2, frac = 0.55, bg = { 0.12, 0.12, 0.12, 1 }, text = 'Cast' }
				elseif key == 'primary' then
					local powerType, isMana = BUI.ClassPowers.GetPrimaryPowerType()
					if isMana then powerType = PowerType.Mana end
					local red, green, blue = PrimaryColor(primaryDb, powerType)
					local current, maxValue = SafeNum(UnitPower('player', powerType)), SafeNum(UnitPowerMax('player', powerType))
					if not (current and maxValue and maxValue > 0) then current, maxValue = 70, 100 end
					local fraction = current / maxValue
					local percent = math.floor(fraction * 100 + 0.5)
					members[#members + 1] = {
						w = primaryDb.barWidth, h = primaryDb.barHeight, r = red, g = green, b = blue, frac = fraction,
						bg = { primaryDb.barBgColorR, primaryDb.barBgColorG, primaryDb.barBgColorB, 1 },
						text = isMana and (primaryDb.hidePercentSign and tostring(percent) or (percent .. '%')) or tostring(current),
					}
				elseif config then
					local red, green, blue = Secondary.GetBarColor(config)
					local prefix = config.prefix
					local current, maxValue = LiveValue(config)
					if config.mode == 'bar' then
						if not (current and maxValue and maxValue > 0) then current, maxValue = 60, 100 end
						members[#members + 1] = {
							w = secondaryDb[prefix .. 'BarWidth'], h = secondaryDb[prefix .. 'BarHeight'],
							r = red, g = green, b = blue, frac = current / maxValue,
							bg = { secondaryDb[prefix .. 'BgColorR'], secondaryDb[prefix .. 'BgColorG'], secondaryDb[prefix .. 'BgColorB'], 1 },
							text = FormatBarValue(secondaryDb, prefix, current, math.floor((current / maxValue) * 100 + 0.5)) or '',
						}
					else
						if not maxValue or maxValue < 1 then maxValue = config.max end
						current = current or math.ceil(maxValue * 0.6)
						members[#members + 1] = {
							segments = true, n = maxValue, cur = current,
							w = secondaryDb[prefix .. 'TotalWidth'],
							h = secondaryDb[prefix .. 'Height'],
							spacing = secondaryDb[prefix .. 'Spacing'],
							r = red, g = green, b = blue,
							bg = { secondaryDb[prefix .. 'BgColorR'], secondaryDb[prefix .. 'BgColorG'], secondaryDb[prefix .. 'BgColorB'], 1 },
						}
					end
				end
			end
		end

		if #members == 0 then
			ShowText('Nothing attached to the stack', 16, 0.45, 0.45, 0.5)
			return
		end

		if containerDb.matchWidth then
			for _, member in ipairs(members) do member.w = containerDb.width end
		end

		local edge = Pixel.Scale(1)
		local totalHeight = -gap
		for _, member in ipairs(members) do totalHeight = totalHeight + member.h + gap end
		local top = totalHeight / 2
		for index, member in ipairs(members) do
			local y = top - member.h / 2
			if member.segments then
				ShowSegments(member.w, member.n, member.h, member.spacing, member.bg, function(segmentIndex)
					if segmentIndex <= member.cur then return member.r, member.g, member.b end
					return 0, 0, 0, 0
				end, y)
				Pixel.ApplyFont(segmentText, 10, PreviewFont())
				segmentText:SetText(tostring(member.cur))
				segmentText:SetTextColor(1, 1, 1, 1)
				segmentText:ClearAllPoints()
				segmentText:SetPoint('CENTER', stage, 'CENTER', 0, y)
				segmentText:Show()
			else
				local drawn = StackBar(index)
				drawn.border:SetSize(member.w, member.h)
				drawn.border:ClearAllPoints()
				drawn.border:SetPoint('CENTER', stage, 'CENTER', 0, y)
				drawn.border:SetVertexColor(0, 0, 0, 1)
				drawn.border:Show()
				drawn.bg:SetSize(member.w - 2 * edge, member.h - 2 * edge)
				drawn.bg:ClearAllPoints()
				drawn.bg:SetPoint('CENTER', drawn.border, 'CENTER', 0, 0)
				drawn.bg:SetVertexColor(member.bg[1], member.bg[2], member.bg[3], member.bg[4])
				drawn.bg:Show()
				drawn.fill:SetSize(math.max(1, (member.w - 2 * edge) * math.min(1, member.frac)), member.h - 2 * edge)
				drawn.fill:ClearAllPoints()
				drawn.fill:SetPoint('LEFT', drawn.bg, 'LEFT', 0, 0)
				drawn.fill:SetVertexColor(member.r, member.g, member.b, 1)
				drawn.fill:Show()
				Pixel.ApplyFont(drawn.text, 10, PreviewFont())
				drawn.text:SetText(member.text)
				drawn.text:SetTextColor(1, 1, 1, 1)
				drawn.text:ClearAllPoints()
				drawn.text:SetPoint('CENTER', drawn.border, 'CENTER', 0, 0)
				drawn.text:Show()
			end
			top = top - member.h - gap
		end
	end

	local function ShowPrimary()
		local db = BUI.Power.GetPrimaryDB()
		local powerType, isMana = BUI.ClassPowers.GetPrimaryPowerType()
		if isMana then powerType = PowerType.Mana end
		local current, maxValue = SafeNum(UnitPower('player', powerType)), SafeNum(UnitPowerMax('player', powerType))
		if not (current and maxValue and maxValue > 0) then current, maxValue = 70, 100 end
		local fraction = current / maxValue
		local percent = math.floor(fraction * 100 + 0.5)
		local valueText = isMana and (db.hidePercentSign and tostring(percent) or (percent .. '%')) or tostring(current)
		if db.barMode then
			local red, green, blue = PrimaryColor(db, powerType)
			if db.lowPowerEnabled then red, green, blue = LowPowerTint(db, percent, red, green, blue) end
			ShowBar({
				w = db.barWidth, h = db.barHeight, frac = fraction, r = red, g = green, b = blue,
				bg = { db.barBgColorR, db.barBgColorG, db.barBgColorB, db.barBgColorA },
				text = not db.barHideText and valueText or nil, textSize = db.barTextSize,
				tr = db.barTextColorR, tg = db.barTextColorG, tb = db.barTextColorB,
				textX = db.barTextOffsetX, textY = db.barTextOffsetY, textAbove = db.barTextAbove,
				ticks = db.tickMarks, tickColor = db.tickMarkColor, tickWidth = db.tickMarkWidth,
				predict = db.showPrediction ~= false and { db.predictionColorR, db.predictionColorG, db.predictionColorB, db.predictionColorA } or nil,
			})
		else
			local red, green, blue = db.textColorR, db.textColorG, db.textColorB
			if db.lowPowerEnabled then red, green, blue = LowPowerTint(db, percent, red, green, blue) end
			ShowText(valueText, db.textSize, red, green, blue)
		end
	end

	local function ShowSecondary()
		local Secondary = BUI.Power.Secondary
		local config, settings = ResolveSecondaryConfig()
		if not config then
			ShowText('No secondary power', 16, 0.45, 0.45, 0.5)
		elseif config.id == 'runes' then
			local ready, maxRunes = LiveValue(config)
			if settings.runeNumberOnly then
				local red, green, blue = SecondaryTextColor(settings, config)
				ShowText(settings.runeShowMax and (ready .. '/' .. maxRunes) or tostring(ready), settings.runeTextSize, red, green, blue)
			else
				local spacing = settings.runeSpacing
				local segmentWidth = ShowSegments(settings.runeTotalWidth, maxRunes, settings.runeHeight, spacing,
					{ settings.runeBgColorR, settings.runeBgColorG, settings.runeBgColorB, settings.runeBgColorA },
					function(index)
						if index <= ready then return settings.runeColorR, settings.runeColorG, settings.runeColorB end
						return settings.runeRechargingColorR, settings.runeRechargingColorG, settings.runeRechargingColorB, 1, 0.55
					end)
				if settings.showRuneCooldown and ready < maxRunes then
					Pixel.ApplyFont(cooldownText, settings.runeCooldownSize, PreviewFont())
					cooldownText:SetText('3.4')
					cooldownText:SetTextColor(settings.runeCooldownColorR, settings.runeCooldownColorG, settings.runeCooldownColorB, 1)
					cooldownText:ClearAllPoints()
					cooldownText:SetPoint('CENTER', stage, 'CENTER', -settings.runeTotalWidth / 2 + ready * (segmentWidth + spacing) + segmentWidth / 2, 0)
					cooldownText:Show()
				end
			end
		elseif config.id == 'stagger' then
			local percent, value = 25, 188
			if not config.check or config.check() then
				local liveValue, livePercent = config.getValue()
				percent = SafeNum(livePercent) or 25
				value = SafeNum(liveValue) or 188
			end
			local percentText = math.floor(percent + 0.5) .. '%'
			local valueText
			if settings.staggerShowValue ~= false and settings.staggerShowPercent ~= false then
				valueText = value .. ' (' .. percentText .. ')'
			elseif settings.staggerShowPercent ~= false then
				valueText = percentText
			elseif settings.staggerShowValue ~= false then
				valueText = tostring(value)
			end
			if settings.staggerBarMode then
				local red, green, blue = config.getColor()
				ShowBar({
					w = settings.staggerBarWidth, h = settings.staggerBarHeight, frac = percent / 100, r = red, g = green, b = blue,
					bg = { settings.staggerBgColorR, settings.staggerBgColorG, settings.staggerBgColorB, settings.staggerBgColorA },
					text = not settings.staggerHideBarText and valueText or nil, textSize = settings.staggerValueSize,
					tr = settings.staggerValueColorR, tg = settings.staggerValueColorG, tb = settings.staggerValueColorB,
					textX = settings.staggerValueOffsetX, textY = settings.staggerValueOffsetY,
					ticks = settings.tickMarks, tickColor = settings.tickMarkColor, tickWidth = settings.tickMarkWidth,
				})
			else
				local red, green, blue = SecondaryTextColor(settings, config)
				ShowText(valueText or '', settings.textSize, red, green, blue)
			end
		elseif config.mode == 'bar' then
			local prefix = config.prefix
			local value, maxValue = LiveValue(config)
			if not (value and maxValue and maxValue > 0) then value, maxValue = 70, 100 end
			local fraction = value / maxValue
			local percent = math.floor(fraction * 100 + 0.5)
			local valueText = FormatBarValue(settings, prefix, value, percent)
			if settings[prefix .. 'BarMode'] then
				local red, green, blue = Secondary.GetBarColor(config)
				if settings.lowPowerEnabled and config.power then red, green, blue = LowPowerTint(settings, percent, red, green, blue) end
				ShowBar({
					w = settings[prefix .. 'BarWidth'], h = settings[prefix .. 'BarHeight'], frac = fraction, r = red, g = green, b = blue,
					bg = { settings[prefix .. 'BgColorR'], settings[prefix .. 'BgColorG'], settings[prefix .. 'BgColorB'], settings[prefix .. 'BgColorA'] },
					text = not settings[prefix .. 'HideBarText'] and valueText or nil, textSize = settings[prefix .. 'ValueSize'],
					tr = settings[prefix .. 'ValueColorR'], tg = settings[prefix .. 'ValueColorG'], tb = settings[prefix .. 'ValueColorB'],
					textX = settings[prefix .. 'ValueOffsetX'], textY = settings[prefix .. 'ValueOffsetY'],
					ticks = settings.tickMarks, tickColor = settings.tickMarkColor, tickWidth = settings.tickMarkWidth,
				})
			else
				local red, green, blue = SecondaryTextColor(settings, config)
				ShowText(valueText or '', settings.textSize, red, green, blue)
			end
		else
			local prefix = config.prefix
			local value, maxValue = LiveValue(config)
			if not maxValue or maxValue < 1 then maxValue = config.max end
			value = value or math.ceil(maxValue * 0.6)
			if settings[prefix .. 'NumberOnly'] then
				local red, green, blue = SecondaryTextColor(settings, config)
				ShowText(settings[prefix .. 'ShowMax'] and (value .. '/' .. maxValue) or tostring(value), settings.textSize, red, green, blue)
			else
				local charged
				if config.id == 'combo' and (not config.check or config.check()) then
					local points = GetUnitChargedPowerPoints('player')
					if points and #points > 0 then
						charged = {}
						for _, point in ipairs(points) do charged[point] = true end
					end
				end
				local red, green, blue = Secondary.GetBarColor(config)
				ShowSegments(settings[prefix .. 'TotalWidth'], maxValue, settings[prefix .. 'Height'], settings[prefix .. 'Spacing'],
					{ settings[prefix .. 'BgColorR'], settings[prefix .. 'BgColorG'], settings[prefix .. 'BgColorB'], settings[prefix .. 'BgColorA'] },
					function(index)
						if charged and charged[index] and index <= value then
							return settings.comboChargedColorR, settings.comboChargedColorG, settings.comboChargedColorB
						elseif index <= value then
							return red, green, blue
						end
						return 0, 0, 0, 0
					end)
				if not settings[prefix .. 'HideBarText'] then
					Pixel.ApplyFont(segmentText, settings[prefix .. 'CenterTextSize'], PreviewFont())
					segmentText:SetText(value)
					segmentText:SetTextColor(settings[prefix .. 'ValueColorR'], settings[prefix .. 'ValueColorG'], settings[prefix .. 'ValueColorB'], 1)
					segmentText:ClearAllPoints()
					segmentText:SetPoint('CENTER', stage, 'CENTER', settings[prefix .. 'ValueOffsetX'], settings[prefix .. 'ValueOffsetY'])
					segmentText:Show()
				end
			end
		end
	end

	function band:Update()
		kind = KINDS[selected] or 'general'
		HideAll()
		if kind == 'general' then
			if BUI.Power.Container.IsEnabled() then return ShowStacked() end
			return ShowPrimary()
		end
		if kind == 'primary' then return ShowPrimary() end
		ShowSecondary()
	end
	return band
end

local function Panes(ui, _, parent, width, item, page)
	if item.id == 'primary' then return PrimaryBoards(ui, parent, width, page) end
	if item.id == 'secondary' then return SecondaryBoards(ui, parent, width, page) end
	if item.id == 'stacking' then return { StackingBoard(ui, parent, width) } end
	return { ScopeBoard(ui, parent, width) }
end

local RAIL_GROUPS = {
	{ title = 'Settings', items = { { id = 'scope', label = 'Scope', icon = 'profile', count = function() return SCOPE_TAGS[BUI.Power.GetScope()] end } } },
	{ title = 'Bars', items = {
		{ id = 'primary', label = 'Primary', icon = 'power' },
		{ id = 'secondary', label = 'Secondary', icon = 'more' },
	} },
	{ title = 'Layout', items = { { id = 'stacking', label = 'Stacking', icon = 'order' } } },
}

BUI.PageEngine.RegisterPage('power', {
	title = 'Power',
	buttonText = 'Power',
	icon = 'power',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local tab = page:GetTab(1)
		local enabled = BUI.IsModuleEnabled('power')
		local rail
		rail = Layout.RailPage(tab, { window = Window() }, {
			icon = 'power',
			title = 'Power',
			placeholder = 'Search power settings...',
			tabs = TAB_IDS,
			disabled = function() return not enabled end,
			tools = {
				{ icon = 'enable', tooltip = 'Turn the power module on or off, needs a reload', get = function() return BUI.IsModuleEnabled('power') end, set = function(value)
					BUI.ModulesPage.ConfirmReload('power', value, Repaint)
				end },
			},
			preview = { height = PREVIEW_HEIGHT, build = function(band, kit) preview = BuildPreview(band, kit) end },
			rail = { groups = RAIL_GROUPS, selected = selected },
			build = Panes,
		})
		local Select = rail.Select
		function rail:Select(id)
			selected = id
			Select(self, id)
			EditPreview()
			Repaint()
			RefreshPreview()
		end
		pageFrame._page = rail.adapter
		EditPreview()
		RefreshPreview()
		page:AutoRefresh()
	end,
	OnHide = function()
		BUI.Power.Secondary.SetEditPreview(nil)
		local Container = BUI.Power.Container
		if not Container.GetDB().locked then Container.SetLocked(true) end
		if not BUI.Power.GetPrimaryDB().locked then BUI.Power.Primary.SetLocked(true) end
		if not BUI.Power.GetSecondaryDB().locked then BUI.Power.Secondary.SetLocked(true) end
	end,
})
