local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout, Modals = BUILib.Layout, BUILib.Modals
local AuraLists = BUI.AuraLists

local PAGE_WIDTH = 960
local MENU_WIDTH = 150
local WIDE_MENU = 200
local TEXT_RANGE = 100
local ICON_RANGE = 80
local AURA_RANGE = 200
local POSITION_RANGE = 2000
local PARTY_FIELDS = { posX = 'x', posY = 'y' }

local OUTLINES = {
	{ value = '', text = 'None' },
	{ value = 'OUTLINE', text = 'Outline' },
	{ value = 'THICKOUTLINE', text = 'Thick outline' },
	{ value = 'MONOCHROME', text = 'Monochrome' },
}
local HP_FORMATS = {
	{ value = '[blu:hppct]', text = 'Percent, 60%' },
	{ value = '[blu:hp]', text = 'Current, 45k' },
	{ value = '[blu:hp]/[blu:hpmax]', text = 'Current and max, 45k/75k' },
	{ value = '[blu:hpmissing]', text = 'Missing, 30k' },
	{ value = '[blu:absorb]', text = 'Absorb shield, 30k' },
	{ value = '[blu:hp] [blu:absorb]', text = 'Health and absorb' },
}
local POWER_FORMATS = {
	{ value = '[blu:pwr]', text = 'Current, 45k' },
	{ value = '[blu:pwrpct]', text = 'Percent, 60%' },
	{ value = '[blu:pwr]/[blu:pwrmax]', text = 'Current and max, 45k/75k' },
}
local GROWTHS = {
	{ value = 'RIGHT', text = 'Right' },
	{ value = 'LEFT', text = 'Left' },
	{ value = 'UP', text = 'Up' },
	{ value = 'DOWN', text = 'Down' },
}
local ABSORB_TEXTURES = {
	{ value = 'Solid', text = 'Solid' },
	{ value = 'Stripes', text = 'Diagonal stripes' },
}
local ABSORB_DIRECTIONS = {
	{ value = 'right', text = 'Fill the empty area' },
	{ value = 'left', text = 'Reverse into health' },
	{ value = 'edge', text = 'From the bar edge' },
}
local DISPEL_MODES = {
	{ value = 'off', text = 'Off' },
	{ value = 'border', text = 'Color the border' },
	{ value = 'bar', text = 'Tint the health bar' },
}
local DISPEL_SOURCES = {
	{ value = 'mine', text = 'Dispellable by me' },
	{ value = 'all', text = 'All magic, curse, disease and poison' },
}
local CLICK_MODES = {
	{ value = 'down', text = 'On key down' },
	{ value = 'up', text = 'On key up' },
	{ value = 'both', text = 'Both' },
}
local SORT_BYS = {
	{ value = 'GROUP', text = 'Party slot' },
	{ value = 'ASSIGNEDROLE', text = 'Role' },
	{ value = 'CLASS', text = 'Class' },
}
local ROLE_ORDERS = {
	{ value = 'TANK,HEALER,DAMAGER', text = 'Tank, healer, damage' },
	{ value = 'HEALER,TANK,DAMAGER', text = 'Healer, tank, damage' },
	{ value = 'TANK,DAMAGER,HEALER', text = 'Tank, damage, healer' },
	{ value = 'HEALER,DAMAGER,TANK', text = 'Healer, damage, tank' },
	{ value = 'DAMAGER,TANK,HEALER', text = 'Damage, tank, healer' },
	{ value = 'DAMAGER,HEALER,TANK', text = 'Damage, healer, tank' },
}
local CLASS_ORDERS = {
	{ value = 'DEATHKNIGHT,DEMONHUNTER,DRUID,EVOKER,HUNTER,MAGE,MONK,PALADIN,PRIEST,ROGUE,SHAMAN,WARLOCK,WARRIOR', text = 'Alphabetical' },
	{ value = 'DEATHKNIGHT,PALADIN,WARRIOR,HUNTER,SHAMAN,EVOKER,DEMONHUNTER,DRUID,MONK,ROGUE,MAGE,PRIEST,WARLOCK', text = 'Plate, mail, leather, cloth' },
	{ value = 'MAGE,PRIEST,WARLOCK,DEMONHUNTER,DRUID,MONK,ROGUE,HUNTER,SHAMAN,EVOKER,DEATHKNIGHT,PALADIN,WARRIOR', text = 'Cloth, leather, mail, plate' },
}
local ROLE_ICONS = {
	{ value = 'all', text = 'Everyone' },
	{ value = 'tank', text = 'Tanks only' },
	{ value = 'healer', text = 'Healers only' },
	{ value = 'tankhealer', text = 'Tanks and healers' },
}
local RAID_LAYOUTS = {
	{ value = 'GROUPS', text = 'By raid group' },
	{ value = 'ROLE', text = 'One list by role' },
	{ value = 'CLASS', text = 'One list by class' },
	{ value = 'NAME', text = 'One list by name' },
}
local RAID_GROUPS = { { value = 'off', text = 'Hidden in a raid' } }
for group = 1, 8 do RAID_GROUPS[#RAID_GROUPS + 1] = { value = tostring(group), text = 'Shown as raid group ' .. group } end
local INDICATORS = {
	{ key = 'roleIcon', kind = 'role', label = 'Role icon' },
	{ key = 'leaderIcon', kind = 'leader', label = 'Leader and assist' },
	{ key = 'raidTargetIcon', kind = 'raidTarget', label = 'Raid marker' },
	{ key = 'resurrectIcon', kind = 'resurrect', label = 'Resurrect' },
	{ key = 'readyCheckIcon', kind = 'readyCheck', label = 'Ready check' },
	{ key = 'combatIcon', kind = 'combat', label = 'Combat' },
}
local STATUSES = { 'DND', 'AFK', 'Offline', 'Ghost', 'Dead' }
local DISPEL_TYPES = { 'Bleed', 'Poison', 'Disease', 'Curse', 'Magic' }
local CONTAINERS = {
	{ key = 'buffs', title = 'Buffs', description = 'Helpful auras on each member' },
	{ key = 'debuffs', title = 'Debuffs', description = 'Harmful auras on each member' },
	{ key = 'bigDef', title = 'Defensives', description = 'Major defensive cooldowns' },
	{ key = 'crowdControl', title = 'Crowd control', description = 'Stuns, fears and other loss of control' },
}
local POLARITY = { buffs = 'HELPFUL', bigDef = 'HELPFUL', debuffs = 'HARMFUL', crowdControl = 'HARMFUL' }
local SECTION_OF = { party = 'party', partyAuras = 'party', raid = 'raid', raidAuras = 'raid' }
local TAB_IDS = { 'general', 'party', 'raid', 'partyAuras', 'raidAuras', 'filters' }
local TAB_INDEX = {}
for index, id in ipairs(TAB_IDS) do TAB_INDEX[id] = index end

local selected = 'general'
local fonts, textures

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function GroupFrames()
	return BUI.GroupFrames
end

local function Config()
	return BUI.GetDB().groupFrames
end

local function RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function Option(db, label, key, extra)
	local option = { label = label, get = function() return db[key] end, set = function(value) db[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Toggle(db, label, key)
	return { label = label, get = function() return db[key] == true end, set = function(value) db[key] = value end }
end

local function OnUnlessOff(db, label, key)
	return { label = label, get = function() return db[key] ~= false end, set = function(value) db[key] = value end }
end

local function Color(db, label, key)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = true,
		get = function()
			local color = db[key]
			return color[1], color[2], color[3], color[4] or 1
		end,
		set = function(red, green, blue, alpha) db[key] = { red, green, blue, alpha } end,
	}
end

local function Menu(db, key, entries, width)
	return { entries = entries, width = width or MENU_WIDTH, get = function() return db[key] end, set = function(value) db[key] = value end }
end

local function Eye(tooltip, get, set)
	return { icon = 'eye', tooltip = tooltip, get = get, set = function(value)
		set(value)
		Repaint()
	end }
end

local function TextOptions(text, extra)
	local options = {
		Option(text, 'Size', 'size', { min = 6, max = 28, step = 1 }),
		Option(text, 'Outline', 'outline', { entries = OUTLINES }),
		Option(text, 'Anchor', 'anchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
		Option(text, 'Horizontal', 'offsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		Option(text, 'Vertical', 'offsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
	}
	for _, option in ipairs(extra or {}) do options[#options + 1] = option end
	return { icon = 'text', tooltip = 'Size and placement', title = 'Text', options = options }
end

local function Placement(settings)
	local byPoints = {}
	for _, item in ipairs(BUI.C.TEXT_PLACEMENT_OPTIONS) do
		local point, relativePoint = BUI.Tools.ResolvePlacement(item.value)
		byPoints[point .. ':' .. relativePoint] = item.value
	end
	return { label = 'Anchor', entries = BUI.C.TEXT_PLACEMENT_OPTIONS, get = function() return byPoints[settings.anchorPoint .. ':' .. settings.relativePoint] end, set = function(value)
		settings.anchorPoint, settings.relativePoint = BUI.Tools.ResolvePlacement(value)
	end }
end

local function FramesBoard(ui, parent, width, key)
	local section = Config()[key]
	local isParty = key == 'party'
	local function Refresh() GroupFrames().Refresh(key) end
	local Colors = GroupFrames().RefreshColors
	local board = ui.Board(parent, width, {
		stacked = true,
		title = isParty and 'Party frames' or 'Raid frames',
		description = isParty and 'Compact party frames with auras, dispels and indicators. The eye forces the frames to show so you can place them.'
			or 'Group based raid frames for 10 to 40 players. The eye forces the frames to show so you can place them.',
	})
	local position
	if isParty then
		position = BUI.PositionTool(section, { selfTag = 'BUI_GroupParty', fields = PARTY_FIELDS, noCenter = true, matchWidth = true, rangeX = POSITION_RANGE, rangeY = POSITION_RANGE })
	else
		position = { icon = 'mover', tooltip = 'Position', title = 'Position', options = {
			Option(section, 'Horizontal', 'x', { min = -POSITION_RANGE, max = POSITION_RANGE, step = 1 }),
			Option(section, 'Vertical', 'y', { min = -POSITION_RANGE, max = POSITION_RANGE, step = 1 }),
		} }
	end
	board:AddTools(isParty and 'Party frames' or 'Raid frames', 'On or off, preview and position', {
		position,
		Eye('Force the frames to show', function()
			if isParty then return GroupFrames().IsPartyPreviewShown() end
			return GroupFrames().IsRaidPreviewShown()
		end, function()
			if isParty then GroupFrames().TogglePartyPreview() else GroupFrames().ToggleRaidPreview() end
		end),
		Toggle(section, nil, 'enabled'),
	}, Refresh)
	if isParty then
		board:AddTools('Sorting', 'How party members are ordered', {
			Menu(section, 'sortBy', SORT_BYS),
			{ tooltip = 'Role and class order', title = 'Sorting', options = {
				Option(section, 'Role order', 'roleOrder', { entries = ROLE_ORDERS }),
				Option(section, 'Class order', 'classOrder', { entries = CLASS_ORDERS }),
			} },
		}, Refresh)
		board:AddTools('Visibility', 'When the party frames show', {
			Menu(section, 'raidGroup', RAID_GROUPS, WIDE_MENU),
			{ tooltip = 'Yourself and solo play', title = 'Visibility', options = {
				Toggle(section, 'Show yourself in the party', 'showPlayer'),
				Toggle(section, 'Show while solo', 'showSolo'),
			} },
		}, Refresh)
	else
		board:AddTools('Role icons', 'Who gets a tank, healer or damage icon', { Menu(section, 'roleIconFilter', ROLE_ICONS) }, Refresh)
		board:AddSwitch('Fit groups to the instance', function() return section.clampGroups ~= false end, function(value)
			section.clampGroups = value
			Refresh()
		end, 'Skip groups past the instance size cap')
		board:AddTools('Sorting', 'A grouped grid, or one list sorted across the raid', {
			{ entries = RAID_LAYOUTS, width = WIDE_MENU, get = function() return section.raidWideSorting and section.wideSortBy or 'GROUPS' end, set = function(value)
				if value == 'GROUPS' then
					section.raidWideSorting = false
				else
					section.raidWideSorting = true
					section.wideSortBy = value
				end
			end },
			{ tooltip = 'Order and column size', title = 'Sorting', options = {
				Option(section, 'Role order', 'roleOrder', { entries = ROLE_ORDERS }),
				Option(section, 'Class order', 'classOrder', { entries = CLASS_ORDERS }),
				Option(section, 'Units per column', 'wideUnitsPerColumn', { min = 5, max = 40, step = 5 }),
			} },
		}, Refresh)
		local large = section.large
		board:AddTools('Large raid layout', 'Different sizing once the raid grows', {
			{ tooltip = 'Threshold and sizing', title = 'Large raid', options = {
				Option(large, 'Switch at raid size', 'threshold', { min = 11, max = 40, step = 1 }),
				Option(large, 'Width', 'width', { min = 40, max = 300, step = 1 }),
				Option(large, 'Height', 'height', { min = 14, max = 80, step = 1 }),
				Option(large, 'Power height', 'powerHeight', { min = 0, max = 16, step = 1 }),
				Option(large, 'Frame spacing', 'spacing', { min = 0, max = 40, step = 1 }),
				Option(large, 'Group spacing', 'groupSpacing', { min = 0, max = 40, step = 1 }),
				Option(large, 'Groups per row', 'groupsPerRow', { min = 1, max = 8, step = 1 }),
			} },
			Toggle(large, nil, 'enabled'),
		}, Refresh)
	end
	local sizing = {
		Option(section, 'Width', 'width', { min = 50, max = 300, step = 1 }),
		Option(section, 'Height', 'height', { min = 18, max = 80, step = 1 }),
		Option(section, 'Frame spacing', 'spacing', { min = 0, max = 40, step = 1 }),
		Toggle(section, 'Power bars', 'showPower'),
		Option(section, 'Power height', 'powerHeight', { min = 0, max = 16, step = 1 }),
		Toggle(section, 'Mana on healers only', 'healerOnlyPower'),
	}
	if not isParty then
		sizing[#sizing + 1] = Option(section, 'Group spacing', 'groupSpacing', { min = 0, max = 40, step = 1 })
		sizing[#sizing + 1] = Option(section, 'Groups per row', 'groupsPerRow', { min = 1, max = 8, step = 1 })
	end
	sizing[#sizing + 1] = Toggle(section, 'Vertical layout', 'vertical')
	if not isParty then sizing[#sizing + 1] = Toggle(section, 'Grow upward', 'growUp') end
	board:AddTools('Frames', 'Texture, size, spacing and power bars', {
		Menu(section, 'statusbarTexture', textures, WIDE_MENU),
		{ tooltip = 'Size, spacing and power bars', title = 'Frames', options = sizing },
	}, Refresh)

	local look = ui.Board(parent, width, {
		stacked = true,
		title = 'Appearance',
		description = 'Colors, absorbs and the borders that mark your target and mouseover.',
	})
	look:AddTools('Health and colors', 'Bar, border and background colors', {
		Color(section, 'Health', 'healthColor'),
		Color(section, 'Border', 'borderColor'),
		Color(section, 'Background', 'bgColor'),
		Color(section, 'Dead background', 'deadBackgroundColor'),
		{ tooltip = 'Class colors and opacity', title = 'Health and colors', options = {
			Toggle(section, 'Class color the health', 'useClassColor'),
			Toggle(section, 'Class color the names', 'classColorNames'),
			Toggle(section, 'Class color the background', 'classColorBackground'),
			Toggle(section, 'Transparent health', 'transparentHealth'),
			Toggle(section, 'Color the background when dead', 'deadBackground'),
			Option(section, 'Health fill opacity %', 'healthOpacity', { min = 0, max = 100, step = 1 }),
		} },
	}, Colors)
	for _, absorb in ipairs({ { key = 'absorb', title = 'Damage absorb', description = 'Shield bar layered on the health bar' }, { key = 'healAbsorb', title = 'Heal absorb', description = 'Incoming heal absorbs shown against health' } }) do
		local settings = section[absorb.key]
		look:AddTools(absorb.title, absorb.description, {
			Color(settings, 'Bar color', 'color'),
			{ tooltip = 'Texture and direction', title = absorb.title, options = {
				Option(settings, 'Texture', 'texture', { entries = ABSORB_TEXTURES }),
				Option(settings, 'Direction', 'direction', { entries = ABSORB_DIRECTIONS }),
			} },
			Toggle(settings, nil, 'enabled'),
		}, Colors)
	end
	for _, border in ipairs({ { key = 'targetBorder', title = 'Target border', description = 'Outline on your current target' }, { key = 'mouseoverBorder', title = 'Mouseover border', description = 'Outline on the hovered frame' } }) do
		local settings = section[border.key]
		look:AddTools(border.title, border.description, {
			Color(settings, 'Border color', 'color'),
			{ tooltip = 'Thickness', title = border.title, options = { Option(settings, 'Thickness', 'thickness', { min = 1, max = 6, step = 1 }) } },
			Toggle(settings, nil, 'enabled'),
		}, Colors)
	end

	local text = ui.Board(parent, width, {
		stacked = true,
		title = 'Text',
		description = 'Names, values and status labels on the frames.',
	})
	text:AddTools('Font', 'Shared by all text on the frames', { Menu(section, 'font', fonts, WIDE_MENU) }, Refresh)
	text:AddTools('Name', nil, {
		Color(section.name, 'Name color', 'color'),
		TextOptions(section.name, { Option(section, 'Max letters, 0 for all', 'nameMaxLength', { min = 0, max = 20, step = 1 }) }),
		Toggle(section, nil, 'showName'),
	}, Refresh)
	text:AddTools('Health text', nil, {
		Color(section.hpText, 'Text color', 'color'),
		Color(section, 'Absorb color', 'absorbColor'),
		Menu(section.hpText, 'format', HP_FORMATS, WIDE_MENU),
		TextOptions(section.hpText, { Toggle(section.hpText, 'Class color', 'classColor') }),
		Toggle(section, nil, 'showHpText'),
	}, function()
		Refresh()
		Colors()
	end)
	text:AddTools('Power text', nil, {
		Color(section.pwrText, 'Text color', 'color'),
		Menu(section.pwrText, 'format', POWER_FORMATS, WIDE_MENU),
		TextOptions(section.pwrText, { Toggle(section.pwrText, 'Class color', 'classColor') }),
		Toggle(section, nil, 'showPwrText'),
	}, function()
		Refresh()
		Colors()
	end)
	local statusTools = {}
	for _, status in ipairs(STATUSES) do statusTools[#statusTools + 1] = Color(section.statusText.colors, status, status) end
	statusTools[#statusTools + 1] = TextOptions(section.statusText)
	statusTools[#statusTools + 1] = Toggle(section, nil, 'showStatusText')
	text:AddTools('Status text', 'Dead, ghost, offline, AFK and DND labels', statusTools, Refresh)
	if isParty then
		local keystone = TextOptions(section.keystone)
		table.remove(keystone.options, 2)
		text:AddTools('Mythic+ key', 'Party keystones, hidden once a run starts', {
			Color(section.keystone, 'Key color', 'color'),
			keystone,
			Toggle(section, nil, 'showKeystone'),
		}, Refresh)
	end

	local indicators = ui.Board(parent, width, {
		stacked = true,
		title = 'Indicators',
		description = 'Icons layered on each frame. The eye previews one on the frames.',
	})
	for _, indicator in ipairs(INDICATORS) do
		local settings = section[indicator.key]
		indicators:AddTools(indicator.label, nil, {
			Menu(settings, 'anchor', BUI.C.ANCHOR_POINT_OPTIONS),
			{ tooltip = 'Size and offset', title = indicator.label, options = {
				Option(settings, 'Size', 'size', { min = 6, max = 48, step = 1 }),
				Option(settings, 'Horizontal', 'offsetX', { min = -ICON_RANGE, max = ICON_RANGE, step = 1 }),
				Option(settings, 'Vertical', 'offsetY', { min = -ICON_RANGE, max = ICON_RANGE, step = 1 }),
			} },
			Eye('Preview it on the frames', function() return GroupFrames().IsIndicatorPreviewing(indicator.kind) end, function(value) GroupFrames().PreviewIndicator(indicator.kind, value) end),
			Toggle(settings, nil, 'enabled'),
		}, Refresh)
	end

	local tooltips = ui.Board(parent, width, {
		stacked = true,
		title = 'Tooltips',
		description = 'What hovering shows.',
	})
	tooltips:AddSwitch('Unit tooltips', function() return section.showUnitTooltips == true end, function(value)
		section.showUnitTooltips = value
		Refresh()
	end, 'Tooltip when hovering a frame')
	tooltips:AddSwitch('Aura tooltips', function() return section.showAuraTooltips == true end, function(value)
		section.showAuraTooltips = value
		Refresh()
	end, 'Tooltips on buff and debuff icons')
	return { board, look, text, indicators, tooltips }
end

local function AurasBoards(ui, parent, width, key)
	local section = Config()[key]
	local function Refresh() GroupFrames().Refresh(key) end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = key == 'party' and 'Party auras' or 'Raid auras',
		description = 'Buffs, debuffs, defensives, crowd control and private auras on each member. The eye shows sample icons on the frames.',
	})
	for _, container in ipairs(CONTAINERS) do
		local settings = section[container.key]
		board:AddTools(container.title, container.description, {
			AuraLists.Rules({
				getRules = function() return GroupFrames().ContainerRules(settings, container.key) end,
				polarity = POLARITY[container.key],
				onChanged = Refresh,
			}),
			{ tooltip = 'Layout and sizing', title = container.title, options = {
				Option(settings, 'Max per rule', 'max', { min = 1, max = 20, step = 1 }),
				Option(settings, 'Per row', 'perRow', { min = 1, max = 20, step = 1 }),
				Option(settings, 'Icon size', 'size', { min = 10, max = 48, step = 1 }),
				Option(settings, 'Icon spacing', 'spacing', { min = 0, max = 10, step = 1 }),
				Option(settings, 'Row spacing', 'rowSpacing', { min = 0, max = 10, step = 1 }),
				Option(settings, 'Stack text size', 'stackSize', { min = 6, max = 24, step = 1 }),
				{ label = 'Sort by', entries = BUI.AuraEngine.SortMethodItems(), get = function() return settings.sortMethod or 'default' end, set = function(value) settings.sortMethod = value end },
				Option(settings, 'Grow', 'growDirection', { entries = GROWTHS }),
				Placement(settings),
				Option(settings, 'Horizontal', 'offsetX', { min = -AURA_RANGE, max = AURA_RANGE, step = 1 }),
				Option(settings, 'Vertical', 'offsetY', { min = -AURA_RANGE, max = AURA_RANGE, step = 1 }),
			} },
			Eye('Show sample icons on the frames', function() return GroupFrames().IsAuraPreviewing(key, container.key) end, function(value) GroupFrames().PreviewAuraKind(key, container.key, value) end),
			Toggle(settings, nil, 'enabled'),
		}, Refresh)
	end
	local private = section.privateAuras
	board:AddTools('Private auras', 'Boss mechanics only you are allowed to see', {
		{ tooltip = 'Count, size and placement', title = 'Private auras', options = {
			Option(private, 'Count', 'num', { min = 1, max = 4, step = 1 }),
			Option(private, 'Icon size', 'size', { min = 12, max = 48, step = 1 }),
			Toggle(private, 'Timer', 'showTimer'),
			Option(private, 'Grow', 'growDirection', { entries = GROWTHS }),
			Placement(private),
			Option(private, 'Horizontal', 'offsetX', { min = -AURA_RANGE, max = AURA_RANGE, step = 1 }),
			Option(private, 'Vertical', 'offsetY', { min = -AURA_RANGE, max = AURA_RANGE, step = 1 }),
		} },
		Eye('Show sample icons where private auras appear', function() return GroupFrames().IsAuraPreviewing(key, 'privateAuras') end, function(value) GroupFrames().PreviewAuraKind(key, 'privateAuras', value) end),
		Toggle(private, nil, 'enabled'),
	}, Refresh)

	local dispels = ui.Board(parent, width, {
		stacked = true,
		title = 'Dispels',
		description = 'Color the frame while a member has a dispellable debuff.',
	})
	local border, badge = section.dispelBorder, section.dispelBadge
	local function Badges() GroupFrames().RestyleAllDispelBadges() end
	dispels:AddTools('Dispel highlight', 'How the frame reacts', {
		{ entries = DISPEL_MODES, width = MENU_WIDTH, get = function()
			if border.tintBar then return 'bar' end
			return border.enabled and 'border' or 'off'
		end, set = function(value)
			border.enabled = value == 'border'
			border.tintBar = value == 'bar'
		end },
		{ tooltip = 'Trigger and badge icon', title = 'Dispel highlight', options = {
			Option(border, 'Trigger', 'source', { entries = DISPEL_SOURCES }),
			Toggle(border, 'Dispel icon', 'showBadge'),
			Option(badge, 'Icon size', 'size', { min = 10, max = 48, step = 1 }),
			Option(badge, 'Icon anchor', 'anchor', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(badge, 'Icon horizontal', 'offsetX', { min = -AURA_RANGE, max = AURA_RANGE, step = 1 }),
			Option(badge, 'Icon vertical', 'offsetY', { min = -AURA_RANGE, max = AURA_RANGE, step = 1 }),
		} },
		Eye('Cycle the dispel colors on the party frames', GroupFrames().IsDispelPreviewActive, function(value)
			if value then GroupFrames().StartDispelPartyPreview() else GroupFrames().StopDispelPreview() end
		end),
	}, function()
		Badges()
		Refresh()
	end)
	local store = BUI.Colors.GetStore()
	local swatches = {
		{ icon = 'reset', tooltip = 'Back to the default colors', onClick = function()
			BUI.Colors.ResetGroup('Dispel Types')
			BUI.ApplyColors()
			Badges()
			Refresh()
			Repaint()
		end },
	}
	for _, typeName in ipairs(DISPEL_TYPES) do
		local stored = store[BUI.AuraEngine.DispelColorKey(typeName)]
		swatches[#swatches + 1] = {
			kind = 'swatch', tooltip = typeName, opacity = true,
			get = function() return stored.r, stored.g, stored.b, stored.a end,
			set = function(red, green, blue, alpha) stored.r, stored.g, stored.b, stored.a = red, green, blue, alpha end,
		}
	end
	dispels:AddTools('Dispel type colors', 'Shared with the unit frames and the color editor', swatches, function()
		Badges()
		Refresh()
	end)
	return { board, dispels }
end

local function GeneralBoards(ui, parent, width)
	local config = Config()
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Group frames',
		description = 'Party and raid frames rebuilt, replacing the Blizzard group frames.',
	})
	if C_AddOns.IsAddOnLoaded('BluFrames') then
		board:AddRow('Standalone Blu Frames detected', 'Your settings were imported, but the module stays idle while the standalone addon runs. Remove it, then reload')
	end
	board:AddSwitch('Hide the Blizzard frames', function() return config.hideBlizzardFrames ~= false end, function(value)
		config.hideBlizzardFrames = value
		if value then
			if GroupFrames().IsActive() then
				GroupFrames().HideBlizzardParty()
				GroupFrames().HideBlizzardRaid()
				GroupFrames().HideBlizzardRaidManager()
			end
			return
		end
		Modals.Confirm({
			parent = Window().frame,
			title = 'Bring the Blizzard frames back',
			message = 'The Blizzard party and raid frames only come back after a reload. Reload now?',
			confirmText = 'Reload', cancelText = 'Later',
			onConfirm = ReloadUI,
		})
	end, 'Replace the default party and raid frames')
	board:AddTools('Click casting', 'When clicks on frames register', { Menu(config, 'clickMode', CLICK_MODES) }, GroupFrames().RefreshClickMode)
	local range = config.range
	board:AddTools('Fade out of range', 'Dim members you cannot reach', {
		{ tooltip = 'Opacity and offline fading', title = 'Range fading', options = {
			Toggle(range, 'Fade offline members', 'fadeOffline'),
			Option(range, 'In range opacity', 'insideAlpha', { min = 0.1, max = 1, step = 0.05 }),
			Option(range, 'Out of range opacity', 'outsideAlpha', { min = 0.1, max = 1, step = 0.05 }),
		} },
		Toggle(range, nil, 'enabled'),
	}, GroupFrames().RefreshRange)
	return { board }
end

local function FiltersBoards(ui, parent, width, page)
	local shared = ui.Board(parent, width, {
		stacked = true,
		title = 'Blacklists',
		description = 'Auras that never show on the frames.',
	})
	AuraLists.ShareCell(shared, 'Share blacklists with the unit frames')
	return {
		shared,
		AuraLists.Blacklist(ui, parent, width, page, { scope = 'group', polarity = 'HARMFUL', title = 'Debuff blacklist', description = 'Debuffs that never show on the frames.' }),
		AuraLists.Blacklist(ui, parent, width, page, { scope = 'group', polarity = 'HELPFUL', title = 'Buff blacklist', description = 'Buffs that never show on the frames.' }),
	}
end

local function Panes(ui, _, parent, width, item, page)
	if item.id == 'general' then return GeneralBoards(ui, parent, width) end
	if item.id == 'filters' then return FiltersBoards(ui, parent, width, page) end
	if item.id == 'partyAuras' or item.id == 'raidAuras' then return AurasBoards(ui, parent, width, SECTION_OF[item.id]) end
	return FramesBoard(ui, parent, width, item.id)
end

local RAIL_GROUPS = {
	{ title = 'Settings', items = {
		{ id = 'general', label = 'General', icon = 'cog' },
		{ id = 'filters', label = 'Filters', icon = 'x' },
	} },
	{ title = 'Party', items = {
		{ id = 'party', label = 'Frames' },
		{ id = 'partyAuras', label = 'Auras' },
	} },
	{ title = 'Raid', items = {
		{ id = 'raid', label = 'Frames' },
		{ id = 'raidAuras', label = 'Auras' },
	} },
}

BUI.PageEngine.RegisterPage('groupframes', {
	title = 'Group Frames',
	buttonText = 'Group Frames',
	icon = 'modules5',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		textures = BUI.BuildTextureDropdownItems(BUI.C.GLOBAL_OPTION)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local tab = page:GetTab(1)
		local enabled = BUI.IsModuleEnabled('groupFrames')
		local rail
		rail = Layout.RailPage(tab, { window = Window() }, {
			icon = 'modules5',
			title = 'Group Frames',
			placeholder = 'Search group frame settings...',
			tools = {
				{ icon = 'enable', tooltip = 'Turn the group frames on or off', get = function() return enabled and Config().enabled == true end, set = function(value)
					if not enabled then return Repaint() end
					Config().enabled = value
					GroupFrames().SetEnabledLive(value)
					if value then return end
					Modals.Confirm({
						parent = Window().frame,
						title = 'Group frames off',
						message = 'The frames are hidden now, but the Blizzard party and raid frames only come back after a reload. Reload now?',
						confirmText = 'Reload', cancelText = 'Later',
						onConfirm = ReloadUI,
					})
				end },
			},
			rail = { groups = enabled and RAIL_GROUPS or { { title = 'Settings', items = { { id = 'off', label = 'Module off' } } } }, selected = enabled and selected or 'off' },
			build = function(ui, shell, parent, width, item, handle)
				if item.id == 'off' then
					return { ui.Board(parent, width, { stacked = true, title = 'Group frames are off', description = 'Turn the module on under Settings, Modules, then reload to use party and raid frames.' }) }
				end
				return Panes(ui, shell, parent, width, item, handle)
			end,
		})
		if not enabled then
			page:AutoRefresh()
			return
		end
		local Select = rail.Select
		function rail:Select(id)
			selected = id
			Select(self, id)
			Repaint()
		end
		pageFrame._page = { tabContents = { tab, tab, tab, tab, tab, tab }, currentTab = TAB_INDEX[selected], SetTab = function(_, index) rail:Select(TAB_IDS[index] or 'general') end }
		page:AutoRefresh()
	end,
	OnHide = function()
		BUI.GroupFrames.CloseAllPreviews()
	end,
})
