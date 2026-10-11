local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout

local PAGE_WIDTH = 960
local MODULE_KEY = 'buffFrames'
local WIDE_MENU = 200
local COLUMNS = { { 'Frame', 'name', 130 }, { 'Shows', 'sub' }, { 'Options', 'icon', 140, 'CENTER' }, { '', 'reset', 42, 'CENTER' }, { 'Preview', 'toggle', 60, 'CENTER' }, { 'Enabled', 'switch', 70, 'CENTER' } }

local GROWTH_SIDEWAYS = {
	{ value = 'LEFT', text = 'Left' },
	{ value = 'RIGHT', text = 'Right' },
}
local GROWTH_ROWS = {
	{ value = 'DOWN', text = 'Down' },
	{ value = 'UP', text = 'Up' },
}
local TIMER_PLACES = {
	{ value = 'below', text = 'Below the icon' },
	{ value = 'icon', text = 'On the icon' },
	{ value = 'none', text = 'Hidden' },
}
local OUTLINES = {
	{ value = '', text = 'None' },
	{ value = 'OUTLINE', text = 'Outline' },
	{ value = 'THICKOUTLINE', text = 'Thick outline' },
}

local KINDS = {
	{ key = 'buffs', title = 'Buffs', frameName = 'BUI_BuffFrame', sub = 'Your buffs and weapon enchants', cancel = true },
	{ key = 'debuffs', title = 'Debuffs', frameName = 'BUI_DebuffFrame', sub = 'Edged in their dispel type color' },
}

local function Window()
	return BUI.PageEngine.window
end

local function Config()
	return BUI.GetDB().buffFrames
end

local function Factory()
	return BUI.Defaults.profile.buffFrames
end

local function Apply()
	BUI.BuffFrames.Refresh()
end

local function Option(db, factory, label, key, extra)
	local option = {
		label = label,
		get = function() return db[key] end,
		set = function(value) db[key] = value end,
		default = function() return factory[key] end,
	}
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function SortItems()
	local items = {}
	for _, choice in ipairs(BUI.BuffFrames.SORT_METHODS) do items[#items + 1] = { value = choice.value, text = choice.text } end
	return items
end

local function AddKind(grid, spec)
	local db, factory = Config()[spec.key], Factory()[spec.key]
	local behavior = {
		Option(db, factory, 'Sort by', 'sortMethod', { entries = SortItems(), width = WIDE_MENU }),
		Option(db, factory, 'Reverse the order', 'sortReverse'),
		Option(db, factory, 'Cooldown swipe', 'swipe', { separator = true }),
		Option(db, factory, 'Reverse the swipe', 'swipeReverse'),
		Option(db, factory, 'Bright edge', 'swipeEdge'),
		Option(db, factory, 'Tooltips on mouseover', 'tooltips', { separator = true }),
		Option(db, factory, 'Tooltips in combat', 'tooltipsInCombat'),
	}
	if spec.cancel then behavior[#behavior + 1] = Option(db, factory, 'Right-click a buff to cancel it', 'rightClickCancel', { separator = true }) end
	grid:AddTools(spec.title, spec.sub, {
		BUI.PositionTool(db, { selfTag = spec.frameName }),
		{ icon = 'resize', tooltip = 'Size and grid', title = spec.title, options = {
			Option(db, factory, 'Icon size', 'size', { min = 16, max = 64, step = 1 }),
			Option(db, factory, 'Per row', 'perRow', { min = 1, max = 40, step = 1 }),
			Option(db, factory, 'Rows', 'rows', { min = 1, max = 8, step = 1 }),
			Option(db, factory, 'Spacing', 'spacing', { min = 0, max = 20, step = 1, separator = true }),
			Option(db, factory, 'Row spacing', 'rowSpacing', { min = 0, max = 40, step = 1 }),
			Option(db, factory, 'Grow sideways', 'growX', { entries = GROWTH_SIDEWAYS, separator = true }),
			Option(db, factory, 'Grow rows', 'growY', { entries = GROWTH_ROWS }),
		} },
		{ icon = 'text', tooltip = 'Font, timer and stacks', title = spec.title, options = {
			Option(db, factory, 'Font', 'font', { entries = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), width = WIDE_MENU }),
			Option(db, factory, 'Outline', 'fontOutline', { entries = OUTLINES, width = WIDE_MENU }),
			Option(db, factory, 'Timer', 'timer', { entries = TIMER_PLACES, width = WIDE_MENU, separator = true }),
			Option(db, factory, 'Timer size', 'durationSize', { min = 6, max = 24, step = 1 }),
			Option(db, factory, 'Stack size', 'countSize', { min = 6, max = 24, step = 1 }),
		} },
		{ tooltip = 'Sorting, swipe and tooltips', title = spec.title, options = behavior },
		{ icon = 'eye', tooltip = 'Show the ' .. spec.title:lower() .. ' frame, drag to move', get = function() return db.locked == false end, set = function(value)
			db.locked = not value
			Apply()
		end },
		Option(db, factory, nil, 'enabled'),
	}, Apply)
end

local function Sections(ui, _, parent, width)
	local grid = BUI.ToolGrid(ui, parent, width, 'Frames', 'Your buff and debuff icons. The eye shows a frame so you can drag it.', COLUMNS)
	for _, spec in ipairs(KINDS) do AddKind(grid, spec) end
	return { grid }
end

BUI.PageEngine.RegisterPage('buffs', {
	title = 'Buffs & Debuffs',
	buttonText = 'Buffs & Debuffs',
	icon = 'updown',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'updown',
			title = 'Buffs & Debuffs',
			placeholder = 'Search buff settings...',
			disabled = function() return not BUI.IsModuleEnabled(MODULE_KEY) end,
			tools = {
				{ icon = 'enable', tooltip = 'Turn the buff and debuff frames on or off', get = function() return BUI.IsModuleEnabled(MODULE_KEY) end, set = function(value) BUI.SetModuleEnabled(MODULE_KEY, value) end },
			},
			tabs = { { label = 'Buffs & Debuffs', build = Sections } },
		})
		page:AutoRefresh()
	end,
})
