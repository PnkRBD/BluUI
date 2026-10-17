local BUI = BluUI

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
local TEXT_OFFSET = { min = -40, max = 40, step = 1 }
local TIMER_PLACES = {
	{ value = 'below', text = 'Text' },
	{ value = 'icon', text = 'Cooldown numbers' },
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

local fonts

local Option = BUI.OptionsKit.Option

local function Config()
	return BUI.GetDB().buffFrames
end

local function Apply()
	BUI.BuffFrames.Refresh()
end

local function AddKind(grid, spec)
	local db = Config()[spec.key]
	local behavior = {
		Option(db, 'Sort by', 'sortMethod', { entries = BUI.BuffFrames.SORT_METHODS, width = WIDE_MENU }),
		Option(db, 'Reverse the order', 'sortReverse'),
		Option(db, 'Cooldown swipe', 'swipe', { separator = true }),
		Option(db, 'Reverse the swipe', 'swipeReverse'),
		Option(db, 'Bright edge', 'swipeEdge'),
		Option(db, 'Tooltips on mouseover', 'tooltips', { separator = true }),
		Option(db, 'Tooltips in combat', 'tooltipsInCombat'),
	}
	if spec.cancel then behavior[#behavior + 1] = Option(db, 'Right-click a buff to cancel it', 'rightClickCancel', { separator = true }) end
	grid:AddTools(spec.title, spec.sub, {
		BUI.PositionTool(db, { selfTag = spec.frameName }),
		{ icon = 'resize', tooltip = 'Size and grid', title = spec.title, options = {
			Option(db, 'Icon size', 'size', { min = 16, max = 64, step = 1 }),
			Option(db, 'Per row', 'perRow', { min = 1, max = 40, step = 1 }),
			Option(db, 'Rows', 'rows', { min = 1, max = 8, step = 1 }),
			Option(db, 'Spacing', 'spacing', { min = 0, max = 20, step = 1, separator = true }),
			Option(db, 'Row spacing', 'rowSpacing', { min = 0, max = 40, step = 1 }),
			Option(db, 'Grow sideways', 'growX', { entries = GROWTH_SIDEWAYS, separator = true }),
			Option(db, 'Grow rows', 'growY', { entries = GROWTH_ROWS }),
		} },
		{ icon = 'text', tooltip = 'Font, timer and stacks', title = spec.title, options = {
			Option(db, 'Font', 'font', { entries = fonts, width = WIDE_MENU }),
			Option(db, 'Outline', 'fontOutline', { entries = OUTLINES, width = WIDE_MENU }),
			Option(db, 'Timer', 'timer', { entries = TIMER_PLACES, width = WIDE_MENU, separator = true }),
			Option(db, 'Timer size', 'durationSize', { min = 6, max = 24, step = 1 }),
			Option(db, 'Compact timer, 11s', 'compactTimer'),
			Option(db, 'Decimals', 'showCooldownDecimals'),
			Option(db, 'Decimals under seconds', 'cooldownDecimalThreshold', { min = 1, max = 30, step = 1 }),
			Option(db, 'Timer anchor', 'durationAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS, width = WIDE_MENU }),
			Option(db, 'Timer X offset', 'durationOffsetX', TEXT_OFFSET),
			Option(db, 'Timer Y offset', 'durationOffsetY', TEXT_OFFSET),
			Option(db, 'Stack size', 'countSize', { min = 6, max = 24, step = 1, separator = true }),
			Option(db, 'Stack anchor', 'countAnchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS, width = WIDE_MENU }),
			Option(db, 'Stack X offset', 'countOffsetX', TEXT_OFFSET),
			Option(db, 'Stack Y offset', 'countOffsetY', TEXT_OFFSET),
		} },
		{ tooltip = 'Sorting, swipe and tooltips', title = spec.title, options = behavior },
		{ icon = 'eye', tooltip = 'Show the ' .. spec.title:lower() .. ' frame, drag to move', get = function() return db.locked == false end, set = function(value)
			db.locked = not value
			Apply()
		end },
		Option(db, nil, 'enabled'),
	}, Apply)
end

local function Sections(ui, _, parent, width)
	fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
	local grid = BUI.ToolGrid(ui, parent, width, 'Frames', 'Your buff and debuff icons. The eye shows a frame so you can drag it.', COLUMNS)
	for _, spec in ipairs(KINDS) do AddKind(grid, spec) end
	return { grid }
end

local function BlacklistSections(ui, _, parent, width, page)
	local AuraLists = BUI.AuraLists
	local settings = BUI.GetDB().buffFrames
	local function PinsChanged() BUI.BuffFrames.Refresh() end
	local function OnlySwitch(list, label, tip)
		return { label = label, tip = tip, get = function() return settings.pinnedOnly[list] == true end, set = function(value) settings.pinnedOnly[list] = value end }
	end
	return {
		AuraLists.Pinned(ui, parent, width, page, {
			polarity = 'HELPFUL', title = 'Pinned buffs', description = 'Shown first on the buff frame.',
			get = function() return settings.pinned.buff end, onChange = PinsChanged,
			only = OnlySwitch('buff', 'Only show pinned buffs', 'The buff frame shows nothing but your pinned buffs'),
		}),
		AuraLists.Pinned(ui, parent, width, page, {
			polarity = 'HARMFUL', title = 'Pinned debuffs', description = 'Shown first on the debuff frame. Blizzard only lets addons pick out a few debuffs on you, like Sated.', onYou = true,
			get = function() return settings.pinned.debuff end, onChange = PinsChanged,
			only = OnlySwitch('debuff', 'Only show pinned debuffs', 'The debuff frame shows nothing but your pinned debuffs, like Sated'),
		}),
		AuraLists.Blacklist(ui, parent, width, page, { scope = 'frames', polarity = 'HELPFUL', title = 'Buff blacklist', description = 'Buffs that never show on the buff frame.' }),
		AuraLists.Blacklist(ui, parent, width, page, { scope = 'frames', polarity = 'HARMFUL', title = 'Debuff blacklist', description ='Debuffs that never show on the debuff frame. Blizzard only lets addons hide a few on you, like Sated.' }),
	}
end

local ITEMS = {
	{ id = 'buffFrames', label = 'Frames', icon = 'updown' },
	{ id = 'buffBlacklist', label = 'Filters', icon = 'x' },
}
local OWNED = {}
for _, item in ipairs(ITEMS) do OWNED[item.id] = true end

local function IsOn()
	return BUI.IsModuleEnabled(MODULE_KEY)
end

BUI.BuffFramesPage = {
	group = { title = 'Buffs and debuffs', items = ITEMS },
	Owns = function(id) return OWNED[id] == true end,
	IsOn = IsOn,
	EnableTool = function(repaint)
		return { icon = 'enable', label = 'Buffs and debuffs', tooltip = 'Turn the buff and debuff frames on or off', get = IsOn, set = function(value)
			BUI.SetModuleEnabled(MODULE_KEY, value)
			repaint()
		end }
	end,
	Build = function(ui, shell, parent, width, item, page)
		if item.id == 'buffBlacklist' then return BlacklistSections(ui, shell, parent, width, page) end
		return Sections(ui, shell, parent, width)
	end,
}
