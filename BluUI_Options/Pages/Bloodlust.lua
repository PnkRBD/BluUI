local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local Bloodlust = BUI.Bloodlust

local PAGE_WIDTH = 960
local MENU_WIDTH = 160
local POSITION_RANGE = 1500
local ANCHOR_RANGE = 200

local fonts, sounds

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function Config()
	return BUI.GetDB().bloodlust
end

local function Refresh()
	Bloodlust.Refresh()
end

local function Field(key)
	return function() return Config()[key] end, function(value) Config()[key] = value end
end

local function Option(label, key, extra)
	local option = { label = label }
	option.get, option.set = Field(key)
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Text(label, key)
	return Option(label, key, { kind = 'input', placeholder = 'Nothing' })
end

local function Switch(key)
	local tool = {}
	tool.get, tool.set = Field(key)
	return tool
end

local function Choice(key, entries)
	local tool = { entries = entries, width = MENU_WIDTH }
	tool.get, tool.set = Field(key)
	return tool
end

local function Sound(label, key)
	local tool = Choice(key, sounds)
	tool.label = label
	local set = tool.set
	tool.set = function(value)
		set(value)
		if value ~= 'None' then BUI.PlaySoundByName(value) end
	end
	return tool
end

local function Color(key)
	return {
		kind = 'swatch', opacity = true, tooltip = 'Text color',
		get = function()
			local color = Config()[key]
			return color[1], color[2], color[3], color[4]
		end,
		set = function(red, green, blue, alpha) Config()[key] = { red, green, blue, alpha } end,
	}
end

local function Position()
	local frames = { { value = '', text = 'None, free on the screen' } }
	for _, frame in ipairs(BUI.C.ANCHOR_FRAMES) do
		frames[#frames + 1] = { value = frame.tag, text = frame.desc }
	end
	local centered = Option('Center horizontally', 'centerHorizontally')
	local set = centered.set
	centered.set = function(value)
		set(value)
		if value then Config().posX = 0 end
	end
	return {
		icon = 'mover', tooltip = 'Position and anchor', title = 'Position',
		options = {
			Option('Horizontal', 'posX', { min = -POSITION_RANGE, max = POSITION_RANGE, step = 1 }),
			Option('Vertical', 'posY', { min = -POSITION_RANGE, max = POSITION_RANGE, step = 1 }),
			centered,
			Option('Anchor to', 'anchorFrame', { entries = frames }),
			Option('Anchor side', 'anchorPoint', { entries = BUI.C.ANCHOR_PLACEMENT_OPTIONS }),
			Option('Anchor offset X', 'anchorOffsetX', { min = -ANCHOR_RANGE, max = ANCHOR_RANGE, step = 1 }),
			Option('Anchor offset Y', 'anchorOffsetY', { min = -ANCHOR_RANGE, max = ANCHOR_RANGE, step = 1 }),
		},
	}
end

local function Sections(ui, _, parent, width)
	local display = ui.Board(parent, width, {
		stacked = true,
		title = 'Display',
		description = 'How the text looks and where it sits. Use [spell] for the buff name and [time] for the countdown.',
	})
	display:AddTools('Text', 'Font, size, icon and position', {
		Choice('font', fonts),
		{ tooltip = 'Size and icon', title = 'Text', options = {
			Option('Font size', 'fontSize', { min = 8, max = 48, step = 1 }),
			Option('Show icon', 'showIcon'),
			Option('Icon size', 'iconSize', { min = 12, max = 64, step = 1 }),
		} },
		Position(),
	}, Refresh)

	local alerts = ui.Board(parent, width, {
		stacked = true,
		title = 'Alerts',
		description = 'One-off announcements, each with its own sound.',
	})
	alerts:AddTools('Used', 'When someone pops Bloodlust', {
		Color('usedColor'),
		Sound('Sound', 'soundOnUsed'),
		{ tooltip = 'Text, timing and speech', title = 'Used', options = {
			Text('Text', 'usedFormat'),
			Option('Hold seconds', 'usedHoldDuration', { min = 0.5, max = 10, step = 0.5 }),
			Option('Flash', 'flashOnUsed'),
			Option('Flash seconds', 'flashDuration', { min = 0.2, max = 5, step = 0.1 }),
			Option('Speak', 'ttsOnUsed'),
			Text('Speak text', 'ttsUsedText'),
		} },
	}, Refresh)
	alerts:AddTools('Available', 'When Bloodlust comes off cooldown', {
		Color('readyColor'),
		Sound('Sound', 'soundOnReady'),
		{ tooltip = 'Text, timing and speech', title = 'Available', options = {
			Text('Text', 'readyFormat'),
			Option('Hold seconds', 'readyHoldDuration', { min = 0.5, max = 10, step = 0.5 }),
			Option('Keep on screen', 'showWhenReady'),
			Option('Flash', 'flashOnReady'),
			Option('Flash seconds', 'flashReadyDuration', { min = 0.2, max = 5, step = 0.1 }),
			Option('Speak', 'ttsOnReady'),
			Text('Speak text', 'ttsReadyText'),
		} },
	}, Refresh)

	local countdowns = ui.Board(parent, width, {
		stacked = true,
		title = 'Countdowns',
		description = 'Live timers while the buff runs or recharges.',
	})
	countdowns:AddTools('Active', 'Timer while the buff runs', {
		Color('activeColor'),
		{ tooltip = 'Text', title = 'Active', options = { Text('Text', 'activeFormat') } },
		Switch('showWhenActive'),
	}, Refresh)
	countdowns:AddTools('On cooldown', 'Timer until Bloodlust is ready, with an optional warning before', {
		Color('cdColor'),
		{ tooltip = 'Text and warning', title = 'On cooldown', options = {
			Text('Text', 'cdFormat'),
			Option('Warn seconds before', 'warnBeforeReady', { min = 0, max = 60, step = 1 }),
			Sound('Warn sound', 'soundOnWarn'),
			Option('Speak warning', 'ttsOnWarn'),
			Text('Warning text', 'ttsWarnText'),
		} },
		Switch('showWhenCD'),
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
			tools = {
				{ text = 'Back to alerts', onClick = function() BUI.PageEngine.NavigateToID('auras') end },
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
		Bloodlust.onPreviewStop = Repaint
		page:AutoRefresh()
	end,
	OnHide = function()
		if Bloodlust.IsPreviewing() then Bloodlust.StopPreview() end
	end,
})
