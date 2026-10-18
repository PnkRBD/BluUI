local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local Bloodlust = BUI.Bloodlust

local PAGE_WIDTH = 960
local MENU_WIDTH = 160

local fonts, sounds

local Kit = BUI.OptionsKit
local Window, Repaint, Option = Kit.Window, Kit.Repaint, Kit.Option

local function Config()
	return BUI.GetDB().bloodlust
end

local function Refresh()
	Bloodlust.Refresh()
end

local function Text(db, label, key)
	return Option(db, label, key, { kind = 'input', placeholder = 'Nothing' })
end

local function Sound(db, label, key)
	local tool = Kit.Menu(db, key, sounds, MENU_WIDTH)
	tool.label = label
	local set = tool.set
	tool.set = function(value)
		set(value)
		if value ~= 'None' then BUI.PlaySoundByName(value) end
	end
	return tool
end

local function Color(db, key)
	return Kit.Color(db, nil, key, { tooltip = 'Text color' })
end

local function Sections(ui, _, parent, width)
	local db = Config()
	local display = BUI.ResetBoard(ui, ui.Board(parent, width, {
		stacked = true,
		title = 'Display',
		description = 'Text or one icon, and where it sits. Use [spell] for the buff name and [time] for the countdown.',
	}))
	display:AddTools('Look', 'Text or icon, font, size and position', {
		Kit.Menu(db, 'style', BUI.C.TEXT_OR_ICON_OPTIONS, MENU_WIDTH),
		Kit.Menu(db, 'font', fonts, MENU_WIDTH),
		{ icon = 'text', tooltip = 'Size', title = 'Text', options = {
			Option(db, 'Font size', 'fontSize', { min = 8, max = 48, step = 1 }),
		} },
		{ tooltip = 'Icon', title = 'Icon', options = {
			Option(db, 'Icon beside text', 'showIcon'),
			Option(db, 'Size beside text', 'iconSize', { min = 12, max = 64, step = 1 }),
			Option(db, 'Icon look size', 'tileSize', { min = 24, max = 96, step = 1, separator = true }),
		} },
		BUI.PositionTool(db),
	}, Refresh)

	local alerts = BUI.ResetBoard(ui, ui.Board(parent, width, {
		stacked = true,
		title = 'Alerts',
		description = 'One-off announcements, each with its own sound.',
	}))
	alerts:AddTools('Used', 'When someone pops Bloodlust', {
		Color(db, 'usedColor'),
		Sound(db, 'Sound', 'soundOnUsed'),
		{ icon = 'text', tooltip = 'Message text', title = 'Used', options = { Text(db, 'Text', 'usedFormat') } },
		{ tooltip = 'Timing and speech', title = 'Used', options = {
			Option(db, 'Hold seconds', 'usedHoldDuration', { min = 0.5, max = 10, step = 0.5 }),
			Option(db, 'Flash', 'flashOnUsed'),
			Option(db, 'Flash seconds', 'flashDuration', { min = 0.2, max = 5, step = 0.1 }),
			Option(db, 'Speak', 'ttsOnUsed'),
			Text(db, 'Speak text', 'ttsUsedText'),
		} },
	}, Refresh)
	alerts:AddTools('Available', 'When Bloodlust comes off cooldown', {
		Color(db, 'readyColor'),
		Sound(db, 'Sound', 'soundOnReady'),
		{ icon = 'text', tooltip = 'Message text', title = 'Available', options = { Text(db, 'Text', 'readyFormat') } },
		{ tooltip = 'Timing and speech', title = 'Available', options = {
			Option(db, 'Hold seconds', 'readyHoldDuration', { min = 0.5, max = 10, step = 0.5 }),
			Option(db, 'Keep on screen', 'showWhenReady'),
			Option(db, 'Hide in town', 'readyHideInTown'),
			Option(db, 'Dungeons only', 'readyDungeonOnly'),
			Option(db, 'Flash', 'flashOnReady'),
			Option(db, 'Flash seconds', 'flashReadyDuration', { min = 0.2, max = 5, step = 0.1 }),
			Option(db, 'Speak', 'ttsOnReady'),
			Text(db, 'Speak text', 'ttsReadyText'),
		} },
	}, Refresh)

	local countdowns = BUI.ResetBoard(ui, ui.Board(parent, width, {
		stacked = true,
		title = 'Countdowns',
		description = 'Live timers while the buff runs or recharges.',
	}))
	countdowns:AddTools('Active', 'Timer while the buff runs', {
		Color(db, 'activeColor'),
		{ icon = 'text', tooltip = 'Timer text', title = 'Active', options = { Text(db, 'Text', 'activeFormat') } },
		Option(db, nil, 'showWhenActive'),
	}, Refresh)
	countdowns:AddTools('On cooldown', 'Timer until Bloodlust is ready, with an optional warning before', {
		Color(db, 'cdColor'),
		{ icon = 'text', tooltip = 'Timer text', title = 'On cooldown', options = { Text(db, 'Text', 'cdFormat') } },
		{ tooltip = 'Where it shows and the warning', title = 'On cooldown', options = {
			Option(db, 'Hide in town', 'cdHideInTown'),
			Option(db, 'Dungeons only', 'cdDungeonOnly'),
			Option(db, 'Warn seconds before', 'warnBeforeReady', { min = 0, max = 60, step = 1 }),
			Sound(db, 'Warn sound', 'soundOnWarn'),
			Option(db, 'Speak warning', 'ttsOnWarn'),
			Text(db, 'Warning text', 'ttsWarnText'),
		} },
		Option(db, nil, 'showWhenCD'),
	}, Refresh)
	return { display, alerts, countdowns }
end

BUI.PageEngine.RegisterPage('bloodlust', {
	title = 'Bloodlust',
	buttonText = 'Bloodlust',
	hidden = true,
	navParent = 'auras',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		sounds = BUI.BuildSoundDropdownItems()
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'glow',
			title = 'Bloodlust',
			placeholder = 'Search Bloodlust settings...',
			disabled = function() return Config().enabled ~= true end,
			back = { label = 'Weaker Auras', onClick = function() BUI.PageEngine.NavigateToID('auras') end },
			tools = {
				{ icon = 'enable', tooltip = 'Turn Bloodlust tracking on or off', get = function() return Config().enabled == true end, set = function(value)
					Config().enabled = value
					Refresh()
				end },
				{ icon = 'eye', tooltip = 'Preview the alerts', get = Bloodlust.IsPreviewing, set = function(value)
					if value then Bloodlust.StartPreview() else Bloodlust.StopPreview() end
				end },
			},
			tabs = { { label = 'Bloodlust', build = Sections } },
		})
		BUI.OnModuleChange('bloodlust', Repaint)
		pageFrame._page = page
		page:AutoRefresh()
	end,
	OnHide = function()
		if Bloodlust.IsPreviewing() then Bloodlust.StopPreview() end
	end,
})
