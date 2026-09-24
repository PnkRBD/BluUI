local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals = BUILib.Controls, BUILib.Layout, BUILib.Modals
local PageKit = BUILib.PageKit

local Tabs = { 'General', 'Party', 'Raid', 'Party Auras', 'Raid Auras', 'Filters' }

local function GroupFrames() return BUI.GroupFrames end
local function Config() return BUI.GetDB().groupFrames end

local ANCHOR_ITEMS = BUI.C.ANCHOR_POINT_OPTIONS

local OUTLINE_ITEMS = {
	{ value = '',             text = 'None'          },
	{ value = 'OUTLINE',      text = 'Outline'       },
	{ value = 'THICKOUTLINE', text = 'Thick Outline' },
	{ value = 'MONOCHROME',   text = 'Monochrome'    },
}

local HP_FORMAT_ITEMS = {
	{ value = '[blu:hppct]',           text = 'Percent (60%)'           },
	{ value = '[blu:hp]',              text = 'Current (45k)'           },
	{ value = '[blu:hp]/[blu:hpmax]',  text = 'Current / Max (45k/75k)' },
	{ value = '[blu:hpmissing]',       text = 'Missing (30k)'           },
	{ value = '[blu:absorb]',          text = 'Absorb Shield (30k)'     },
	{ value = '[blu:hp] [blu:absorb]', text = 'Health + Absorb'         },
}

local PWR_FORMAT_ITEMS = {
	{ value = '[blu:pwr]',              text = 'Current (45k)'           },
	{ value = '[blu:pwrpct]',           text = 'Percent (60%)'           },
	{ value = '[blu:pwr]/[blu:pwrmax]', text = 'Current / Max (45k/75k)' },
}

local GROW_ITEMS = {
	{ value = 'RIGHT', text = 'Right' },
	{ value = 'LEFT',  text = 'Left'  },
	{ value = 'UP',    text = 'Up'    },
	{ value = 'DOWN',  text = 'Down'  },
}

local SORT_METHOD_ITEMS = BUI.AuraEngine.SortMethodItems()

local ABSORB_TEXTURE_ITEMS = {
	{ value = 'Solid',   text = 'Solid' },
	{ value = 'Stripes', text = 'Diagonal Stripes' },
}

local ABSORB_DIRECTION_ITEMS = {
	{ value = 'right', text = 'Fill Empty Area' },
	{ value = 'left',  text = 'Reverse Into Health' },
	{ value = 'edge',  text = 'From Bar Edge' },
}

local DISPEL_COLOR_ITEMS = {
	{ value = 'off',    text = 'Off' },
	{ value = 'border', text = 'Color Border' },
	{ value = 'bar',    text = 'Tint Health Bar' },
}

local DISPEL_SOURCE_ITEMS = {
	{ value = 'mine', text = 'Dispellable By Me' },
	{ value = 'all',  text = 'All Magic/Curse/Disease/Poison' },
}

local CLICK_MODE_ITEMS = {
	{ value = 'down', text = 'On Key Down' },
	{ value = 'up',   text = 'On Key Up' },
	{ value = 'both', text = 'Both' },
}

local SORT_BY_ITEMS = {
	{ value = 'GROUP',        text = 'Party Slot (1-4)' },
	{ value = 'ASSIGNEDROLE', text = 'Role' },
	{ value = 'CLASS',        text = 'Class' },
}

local ROLE_ORDER_ITEMS = {
	{ value = 'TANK,HEALER,DAMAGER', text = 'Tank > Healer > DPS' },
	{ value = 'HEALER,TANK,DAMAGER', text = 'Healer > Tank > DPS' },
	{ value = 'TANK,DAMAGER,HEALER', text = 'Tank > DPS > Healer' },
	{ value = 'HEALER,DAMAGER,TANK', text = 'Healer > DPS > Tank' },
	{ value = 'DAMAGER,TANK,HEALER', text = 'DPS > Tank > Healer' },
	{ value = 'DAMAGER,HEALER,TANK', text = 'DPS > Healer > Tank' },
}

local CLASS_ORDER_ITEMS = {
	{ value = 'DEATHKNIGHT,DEMONHUNTER,DRUID,EVOKER,HUNTER,MAGE,MONK,PALADIN,PRIEST,ROGUE,SHAMAN,WARLOCK,WARRIOR',
	  text  = 'Alphabetical' },
	{ value = 'DEATHKNIGHT,PALADIN,WARRIOR,HUNTER,SHAMAN,EVOKER,DEMONHUNTER,DRUID,MONK,ROGUE,MAGE,PRIEST,WARLOCK',
	  text  = 'Armor: Plate > Mail > Leather > Cloth' },
	{ value = 'MAGE,PRIEST,WARLOCK,DEMONHUNTER,DRUID,MONK,ROGUE,HUNTER,SHAMAN,EVOKER,DEATHKNIGHT,PALADIN,WARRIOR',
	  text  = 'Armor: Cloth > Leather > Mail > Plate' },
}

local ROLE_ICON_ITEMS = {
	{ value = 'all',        text = 'Everyone' },
	{ value = 'tank',       text = 'Tanks Only' },
	{ value = 'healer',     text = 'Healers Only' },
	{ value = 'tankhealer', text = 'Tanks + Healers' },
}

local RAID_LAYOUT_ITEMS = {
	{ value = 'GROUPS', text = 'By Raid Group' },
	{ value = 'ROLE',   text = 'One List: By Role' },
	{ value = 'CLASS',  text = 'One List: By Class' },
	{ value = 'NAME',   text = 'One List: By Name' },
}

local RAID_GROUP_ITEMS = (function()
	local items = { { value = 'off', text = 'Hidden In Raid' } }
	for groupIndex = 1, 8 do items[#items + 1] = { value = tostring(groupIndex), text = 'Show As Raid Group ' .. groupIndex } end
	return items
end)()

local function Dropdown(parent, items, get, set, width)
	return Controls.Dropdown(parent, nil, items, get(), set, nil, width or 180)
end

local function Swatch(parent, getTable, key, onChange, tooltip)
	local color = getTable()[key] or { 1, 1, 1, 1 }
	return Controls.ColorSwatch(parent, { r = color[1], g = color[2], b = color[3], a = color[4] or 1, tooltip = tooltip,
		callback = function(red, green, blue, alpha)
			getTable()[key] = { red, green, blue, alpha }
			if onChange then onChange() else GroupFrames().RefreshColors() end
		end })
end

local function OptionSlider(label, min, max, get, set, step)
	return { kind = 'slider', label = label, min = min, max = max, step = step or 1, get = get, set = set }
end

local function OptionCheckbox(label, get, set)
	return { label = label, get = get, set = set }
end

local function OptionDropdown(label, items, get, set, controlWidth)
	return { kind = 'dropdown', label = label, items = items, get = get, set = set, controlWidth = controlWidth }
end

local function AddRow(tab, rows, config)
	config.width = tab.width
	local row = Controls.SettingRow(tab.child, config)
	Layout.Add(tab, row, 8)
	rows[#rows + 1] = row
	return row
end

local function Cog(parent, title, tooltip, options, width)
	return PageKit.SettingsIcon(parent, { title = title, tooltip = tooltip, options = options, width = width })
end

local function PreviewEye(parent, value, toggle, tooltip)
	return Controls.IconToggle(parent, value, toggle, {
		texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = tooltip,
	})
end

local function SectionEnv(sectionKey)
	local function Section() return Config()[sectionKey] end
	local function Refresh() GroupFrames().Refresh(sectionKey) end
	local function SubGetter(key) return function() return Section()[key] end end
	return Section, Refresh, SubGetter
end

local function DimensionsRow(tab, rows, sectionKey, isRaid)
	local Section, Refresh = SectionEnv(sectionKey)
	local options = {
		OptionSlider('Width', 50, 300, function() return Section().width end, function(value) Section().width = value; Refresh() end),
		OptionSlider('Height', 18, 80, function() return Section().height end, function(value) Section().height = value; Refresh() end),
		OptionSlider('Frame Spacing', 0, 40, function() return Section().spacing end, function(value) Section().spacing = value; Refresh() end),
		OptionCheckbox('Show Power Bars', function() return Section().showPower end, function(value) Section().showPower = value; Refresh() end),
		OptionSlider('Power Height', 0, 16, function() return Section().powerHeight end, function(value) Section().powerHeight = value; Refresh() end),
		OptionCheckbox('Mana On Healers Only', function() return Section().healerOnlyPower end, function(value) Section().healerOnlyPower = value; Refresh() end),
	}
	if isRaid then
		options[#options + 1] = OptionSlider('Group Spacing', 0, 40, function() return Section().groupSpacing end, function(value) Section().groupSpacing = value; Refresh() end)
		options[#options + 1] = OptionSlider('Groups Per Row', 1, 8, function() return Section().groupsPerRow end, function(value) Section().groupsPerRow = value; Refresh() end)
	end
	options[#options + 1] = OptionCheckbox('Vertical Layout', function() return Section().vertical end, function(value) Section().vertical = value; Refresh() end)
	if isRaid then
		options[#options + 1] = OptionCheckbox('Grow Upward', function() return Section().growUp end, function(value) Section().growUp = value; Refresh() end)
	end
	AddRow(tab, rows, {
		title = 'Dimensions',
		description = 'Frame size, spacing and power bars',
		controlWidth = 212,
		control = function(row)
			return Dropdown(row, BUI.BuildTextureDropdownItems(BUI.C.GLOBAL_OPTION), function() return Section().statusbarTexture end, function(value) Section().statusbarTexture = value; Refresh() end, 180)
		end,
		accessoryWidth = 40,
		accessories = function(row)
			return { Cog(row, 'DIMENSIONS', 'Size, spacing & power bars', options) }
		end,
	})
end

local function PositionRow(tab, rows, sectionKey)
	local Section, Refresh = SectionEnv(sectionKey)
	local isParty = sectionKey == 'party'
	AddRow(tab, rows, {
		title = 'Position',
		description = isParty and 'Screen position and frame anchoring' or 'Screen position of the raid block',
		plain = true,
		accessoryWidth = 40,
		accessories = function(row)
			if isParty then
				return { BUI.AlertMover(row, Section(), Refresh, {
					selfTag = 'BUI_GroupParty',
					fields = { posX = 'x', posY = 'y' },
					noCenter = true,
					xyRange = { x = 2000, y = 2000 },
					matchWidth = {
						get = function() return Section().matchAnchorWidth end,
						set = function(value) Section().matchAnchorWidth = value; Refresh() end,
					},
				}) }
			end
			return { PageKit.PositionIcon(row, {
				title = 'POSITION', tooltip = 'Screen position', options = {
					OptionSlider('X Position', -2000, 2000, function() return Section().x end, function(value) Section().x = value; Refresh() end),
					OptionSlider('Y Position', -2000, 2000, function() return Section().y end, function(value) Section().y = value; Refresh() end),
				},
			}) }
		end,
	})
end

local function AppearanceRows(tab, rows, sectionKey)
	local Section, Refresh = SectionEnv(sectionKey)
	local RefreshColors = function() GroupFrames().RefreshColors() end

	AddRow(tab, rows, {
		title = 'Health & Colors',
		description = 'Bar, border and background colors',
		plain = true,
		accessoryWidth = 150,
		accessories = function(row)
			local settingsCog = Cog(row, 'HEALTH & COLORS', 'Class colors & opacity', {
				OptionCheckbox('Class Color Health', function() return Section().useClassColor end, function(value) Section().useClassColor = value; RefreshColors() end),
				OptionCheckbox('Class Color Names', function() return Section().classColorNames end, function(value) Section().classColorNames = value; RefreshColors() end),
				OptionCheckbox('Class Color Background', function() return Section().classColorBackground end, function(value) Section().classColorBackground = value; RefreshColors() end),
				OptionCheckbox('Transparent Health', function() return Section().transparentHealth end, function(value) Section().transparentHealth = value; RefreshColors() end),
				OptionCheckbox('Color Background When Dead', function() return Section().deadBackground end, function(value) Section().deadBackground = value; RefreshColors() end),
				OptionSlider('Health Fill Opacity %', 0, 100, function() return Section().healthOpacity end, function(value) Section().healthOpacity = value; RefreshColors() end),
			})
			local backgroundSwatch = Swatch(row, Section, 'bgColor', nil, 'Background Color')
			local deadSwatch = Swatch(row, Section, 'deadBackgroundColor', nil, 'Dead Background Color')
			local border = Swatch(row, Section, 'borderColor', nil, 'Border Color')
			local health = Swatch(row, Section, 'healthColor', nil, 'Health Color')
			return { settingsCog, backgroundSwatch, deadSwatch, border, health }
		end,
	})

	local function AbsorbRow(key, label, description)
		local function AbsorbSettings() return Section()[key] end
		AddRow(tab, rows, {
			title = label,
			description = description,
			checked = AbsorbSettings().enabled,
			callback = function(value) AbsorbSettings().enabled = value; RefreshColors() end,
			accessoryWidth = 60,
			accessories = function(row)
				local settingsCog = Cog(row, label:upper(), 'Texture & fill direction', {
					OptionDropdown('Texture', ABSORB_TEXTURE_ITEMS, function() return AbsorbSettings().texture end, function(value) AbsorbSettings().texture = value; RefreshColors() end),
					OptionDropdown('Direction', ABSORB_DIRECTION_ITEMS, function() return AbsorbSettings().direction end, function(value) AbsorbSettings().direction = value; RefreshColors() end),
				})
				return { settingsCog, Swatch(row, AbsorbSettings, 'color', nil, 'Bar Color') }
			end,
		})
	end
	AbsorbRow('absorb', 'Damage Absorb', 'Shield bar layered on the health bar')
	AbsorbRow('healAbsorb', 'Heal Absorb', 'Incoming heal absorbs shown against health')

	local function BorderRow(key, label, description)
		local function BorderSettings() return Section()[key] end
		AddRow(tab, rows, {
			title = label,
			description = description,
			checked = BorderSettings().enabled,
			callback = function(value) BorderSettings().enabled = value; RefreshColors() end,
			accessoryWidth = 60,
			accessories = function(row)
				local settingsCog = Cog(row, label:upper(), 'Border thickness', {
					OptionSlider('Thickness', 1, 6, function() return BorderSettings().thickness end, function(value) BorderSettings().thickness = value; RefreshColors() end),
				})
				return { settingsCog, Swatch(row, BorderSettings, 'color', nil, 'Border Color') }
			end,
		})
	end
	BorderRow('targetBorder', 'Target Border', 'Outline on your current target')
	BorderRow('mouseoverBorder', 'Mouseover Border', 'Outline on the hovered frame')
end

local function TextOptions(TextSettings, Refresh)
	return {
		OptionSlider('Size', 6, 28, function() return TextSettings().size end, function(value) TextSettings().size = value; Refresh() end),
		OptionDropdown('Outline', OUTLINE_ITEMS, function() return TextSettings().outline end, function(value) TextSettings().outline = value; Refresh() end),
		OptionDropdown('Anchor', ANCHOR_ITEMS, function() return TextSettings().anchor end, function(value) TextSettings().anchor = value; Refresh() end),
		OptionSlider('X Offset', -100, 100, function() return TextSettings().offsetX end, function(value) TextSettings().offsetX = value; Refresh() end),
		OptionSlider('Y Offset', -100, 100, function() return TextSettings().offsetY end, function(value) TextSettings().offsetY = value; Refresh() end),
	}
end

local function TextRows(tab, rows, sectionKey)
	local Section, Refresh = SectionEnv(sectionKey)

	AddRow(tab, rows, {
		title = 'Font',
		description = 'Shared by all text on the frames',
		controlWidth = 232,
		control = function(row)
			return Dropdown(row, BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), function() return Section().font end, function(value) Section().font = value; Refresh() end, 200)
		end,
	})

	AddRow(tab, rows, {
		title = 'Name',
		checked = Section().showName,
		callback = function(value) Section().showName = value; Refresh() end,
		accessoryWidth = 60,
		accessories = function(row)
			local function TextSettings() return Section().name end
			local optionList = TextOptions(TextSettings, Refresh)
			optionList[#optionList + 1] = OptionSlider('Max Letters', 0, 20, function() return Section().nameMaxLength end, function(value) Section().nameMaxLength = value; Refresh() end)
			return { Cog(row, 'NAME', 'Size, placement & length', optionList),
				Swatch(row, TextSettings, 'color', nil, 'Name Color') }
		end,
	})

	AddRow(tab, rows, {
		title = 'Health Text',
		checked = Section().showHpText,
		callback = function(value) Section().showHpText = value; Refresh() end,
		accessoryWidth = 250,
		accessories = function(row)
			local function TextSettings() return Section().hpText end
			local optionList = TextOptions(TextSettings, Refresh)
			optionList[#optionList + 1] = OptionCheckbox('Use Class Color', function() return TextSettings().classColor end, function(value) TextSettings().classColor = value; GroupFrames().RefreshColors() end)
			local settingsCog = Cog(row, 'HEALTH TEXT', 'Size & placement', optionList)
			local formatDropdown = Dropdown(row, HP_FORMAT_ITEMS, function() return TextSettings().format end, function(value) TextSettings().format = value; Refresh() end, 170)
			return { settingsCog, formatDropdown, Swatch(row, TextSettings, 'color', nil, 'Text Color'), Swatch(row, Section, 'absorbColor', nil, 'Absorb Color') }
		end,
	})

	AddRow(tab, rows, {
		title = 'Power Text',
		checked = Section().showPwrText,
		callback = function(value) Section().showPwrText = value; Refresh() end,
		accessoryWidth = 230,
		accessories = function(row)
			local function TextSettings() return Section().pwrText end
			local optionList = TextOptions(TextSettings, Refresh)
			optionList[#optionList + 1] = OptionCheckbox('Use Class Color', function() return TextSettings().classColor end, function(value) TextSettings().classColor = value; GroupFrames().RefreshColors() end)
			local settingsCog = Cog(row, 'POWER TEXT', 'Size & placement', optionList)
			local formatDropdown = Dropdown(row, PWR_FORMAT_ITEMS, function() return TextSettings().format end, function(value) TextSettings().format = value; Refresh() end, 170)
			return { settingsCog, formatDropdown, Swatch(row, TextSettings, 'color', nil, 'Text Color') }
		end,
	})

	AddRow(tab, rows, {
		title = 'Status Text',
		description = 'Dead, ghost, offline, AFK and DND labels',
		checked = Section().showStatusText,
		callback = function(value) Section().showStatusText = value; Refresh() end,
		accessoryWidth = 160,
		accessories = function(row)
			local function TextSettings() return Section().statusText end
			local function StatusColors() return Section().statusText.colors end
			local accessoryList = { Cog(row, 'STATUS TEXT', 'Size & placement', TextOptions(TextSettings, Refresh)) }
			for _, status in ipairs({ 'DND', 'AFK', 'Offline', 'Ghost', 'Dead' }) do
				accessoryList[#accessoryList + 1] = Swatch(row, StatusColors, status, function() Refresh() end, status .. ' Color')
			end
			return accessoryList
		end,
	})

	if sectionKey ~= 'party' then return end

	AddRow(tab, rows, {
		title = 'Mythic+ Key',
		description = 'Party keystones, hidden once a run starts',
		checked = Section().showKeystone,
		callback = function(value) Section().showKeystone = value; Refresh() end,
		accessoryWidth = 60,
		accessories = function(row)
			local function TextSettings() return Section().keystone end
			local optionList = TextOptions(TextSettings, Refresh)
			for index = #optionList, 1, -1 do
				if optionList[index].label == 'Outline' then table.remove(optionList, index) end
			end
			return { Cog(row, 'MYTHIC+ KEY', 'Size & placement', optionList),
				Swatch(row, TextSettings, 'color', function() Refresh() end, 'Key Color') }
		end,
	})
end

local INDICATORS = {
	{ key = 'roleIcon',       kind = 'role',       label = 'Role Icon' },
	{ key = 'leaderIcon',     kind = 'leader',     label = 'Leader / Assist' },
	{ key = 'raidTargetIcon', kind = 'raidTarget', label = 'Raid Marker' },
	{ key = 'resurrectIcon',  kind = 'resurrect',  label = 'Resurrect' },
	{ key = 'readyCheckIcon', kind = 'readyCheck', label = 'Ready Check' },
	{ key = 'combatIcon',     kind = 'combat',     label = 'Combat' },
}

local function IndicatorRows(tab, rows, sectionKey)
	local Section, Refresh = SectionEnv(sectionKey)
	for _, definition in ipairs(INDICATORS) do
		local function Indicator() return Section()[definition.key] end
		AddRow(tab, rows, {
			title = definition.label,
			checked = Indicator().enabled,
			callback = function(value) Indicator().enabled = value; Refresh() end,
			accessoryWidth = 190,
			accessories = function(row)
				local anchorDropdown = Dropdown(row, ANCHOR_ITEMS, function() return Indicator().anchor end, function(value) Indicator().anchor = value; Refresh() end, 130)
				local settingsCog = Cog(row, definition.label:upper(), 'Size & offsets', {
					OptionSlider('Size', 6, 48, function() return Indicator().size end, function(value) Indicator().size = value; Refresh() end),
					OptionSlider('X Offset', -80, 80, function() return Indicator().offsetX end, function(value) Indicator().offsetX = value; Refresh() end),
					OptionSlider('Y Offset', -80, 80, function() return Indicator().offsetY end, function(value) Indicator().offsetY = value; Refresh() end),
				})
				local previewEye = PreviewEye(row, GroupFrames().IsIndicatorPreviewing(definition.kind), function(value)
					GroupFrames().PreviewIndicator(definition.kind, value)
				end, 'Preview this indicator on the frames')
				return { previewEye, settingsCog, anchorDropdown }
			end,
		})
	end
end

local function TooltipRows(tab, rows, sectionKey)
	local Section, Refresh = SectionEnv(sectionKey)
	AddRow(tab, rows, {
		title = 'Unit Tooltips',
		description = 'Tooltip when hovering a frame',
		checked = Section().showUnitTooltips,
		callback = function(value) Section().showUnitTooltips = value; Refresh() end,
	})
	AddRow(tab, rows, {
		title = 'Aura Tooltips',
		description = 'Tooltips on buff and debuff icons',
		checked = Section().showAuraTooltips,
		callback = function(value) Section().showAuraTooltips = value; Refresh() end,
	})
end

function BUI.AuraRuleEditor(parent, options)
	local AuraRules = BUI.AuraRules
	local button
	button = Controls.Button(parent, 'Priority Rules', 130, function()
		local rules = options.getRules()
		local function Push()
			if options.onChanged then options.onChanged() end
		end
		Controls.Popover({
			anchor = button, width = 320, height = 254, title = 'PRIORITY RULES, TOP WINS',
			build = function(panel)
				local list
				local function Fill()
					list:ClearItems()
					for _, id in ipairs(rules) do
						list:AddItem(AuraRules.Icon(id), AuraRules.Label(id), id, true)
					end
				end
				list = Controls.ItemList(panel, nil, panel.width, 176,
					nil,
					function(row)
						for ruleIndex = 1, #rules do
							if rules[ruleIndex] == row.id then table.remove(rules, ruleIndex); break end
						end
						if #rules == 0 then
							BUI.Print('No rules left, container shows nothing.')
						end
						Push()
					end,
					nil, nil,
					true,
					function(data)
						for ruleIndex = #rules, 1, -1 do rules[ruleIndex] = nil end
						for dataIndex = 1, #data do rules[dataIndex] = data[dataIndex].id end
						Push()
					end,
					true,
					{})
				list:SetPoint('TOPLEFT', 0, -34)
				Fill()

				local addDropdown = Controls.Dropdown(panel, nil, AuraRules.DropdownItems(options.polarity, nil, options.unitFramesOnly), nil, function(value)
					for ruleIndex = 1, #rules do
						if rules[ruleIndex] == value then return end
					end
					rules[#rules + 1] = value
					Fill()
					Push()
				end, 'Add a rule', panel.width)
				local addFrame = BUILib.Widget.Unwrap(addDropdown)
				addFrame:ClearAllPoints()
				addFrame:SetPoint('TOPLEFT', 0, 0)
			end,
		})
	end, options.tooltip or 'Pick which auras show here. The top rule claims icon slots first.')
	return button
end

local KIND_POLARITY = { buffs = 'HELPFUL', bigDef = 'HELPFUL', debuffs = 'HARMFUL', crowdControl = 'HARMFUL' }

local function RuleEditor(parent, sectionKey, kind, getConfig)
	return BUI.AuraRuleEditor(parent, {
		getRules  = function() return GroupFrames().ContainerRules(getConfig(), kind) end,
		polarity  = KIND_POLARITY[kind],
		onChanged = function() GroupFrames().Refresh(sectionKey) end,
	})
end

local function AuraContainerRow(tab, rows, sectionKey, configKey, title, description)
	local Section, Refresh = SectionEnv(sectionKey)
	local function AuraSettings() return Section()[configKey] end
	AddRow(tab, rows, {
		title = title,
		description = description,
		checked = AuraSettings().enabled,
		callback = function(value) AuraSettings().enabled = value; Refresh() end,
		accessoryWidth = 200,
		accessories = function(row)
			local previewEye = PreviewEye(row, GroupFrames().IsAuraPreviewing(sectionKey, configKey), function(value)
				GroupFrames().PreviewAuraKind(sectionKey, configKey, value)
			end, 'Show sample icons on the frames')
			local settingsCog = Cog(row, title:upper(), 'Layout & sizing', {
				OptionSlider('Max Per Rule', 1, 20, function() return AuraSettings().max end, function(value) AuraSettings().max = value; Refresh() end),
				OptionSlider('Per Row', 1, 20, function() return AuraSettings().perRow end, function(value) AuraSettings().perRow = value; Refresh() end),
				OptionSlider('Icon Size', 10, 48, function() return AuraSettings().size end, function(value) AuraSettings().size = value; Refresh() end),
				OptionSlider('Icon Spacing', 0, 10, function() return AuraSettings().spacing end, function(value) AuraSettings().spacing = value; Refresh() end),
				OptionSlider('Row Spacing', 0, 10, function() return AuraSettings().rowSpacing end, function(value) AuraSettings().rowSpacing = value; Refresh() end),
				OptionSlider('Stack Text Size', 6, 24, function() return AuraSettings().stackSize end, function(value) AuraSettings().stackSize = value; Refresh() end),
				OptionDropdown('Sort By', SORT_METHOD_ITEMS, function() return AuraSettings().sortMethod or 'default' end, function(value) AuraSettings().sortMethod = value; Refresh() end),
				OptionDropdown('Grow Direction', GROW_ITEMS, function() return AuraSettings().growDirection end, function(value) AuraSettings().growDirection = value; Refresh() end),
				OptionDropdown('Anchor', ANCHOR_ITEMS, function() return AuraSettings().anchorPoint end, function(value) AuraSettings().anchorPoint = value; AuraSettings().relativePoint = value; Refresh() end),
				OptionSlider('X Offset', -200, 200, function() return AuraSettings().offsetX end, function(value) AuraSettings().offsetX = value; Refresh() end),
				OptionSlider('Y Offset', -200, 200, function() return AuraSettings().offsetY end, function(value) AuraSettings().offsetY = value; Refresh() end),
			})
			return { previewEye, settingsCog, RuleEditor(row, sectionKey, configKey, AuraSettings) }
		end,
	})
end

local function DispelRow(tab, rows, sectionKey)
	local Section, Refresh = SectionEnv(sectionKey)
	local function DispelBorder() return Section().dispelBorder end
	local function DispelBadge() return Section().dispelBadge end
	local Badges = function() GroupFrames().RestyleAllDispelBadges() end
	local function colorMode()
		if DispelBorder().tintBar then return 'bar' end
		if DispelBorder().enabled then return 'border' end
		return 'off'
	end
	AddRow(tab, rows, {
		title = 'Dispel Highlight',
		description = 'Colors the frame while a member has a dispellable debuff',
		controlWidth = 192,
		control = function(row)
			return Dropdown(row, DISPEL_COLOR_ITEMS, colorMode, function(value)
				DispelBorder().enabled = (value == 'border')
				DispelBorder().tintBar = (value == 'bar')
				Refresh()
			end, 160)
		end,
		accessoryWidth = 60,
		accessories = function(row)
			local settingsCog = Cog(row, 'DISPEL HIGHLIGHT', 'Trigger & badge icon', {
				OptionDropdown('Trigger', DISPEL_SOURCE_ITEMS, function() return DispelBorder().source end, function(value) DispelBorder().source = value; Refresh() end, 190),
				OptionCheckbox('Dispel Icon', function() return DispelBorder().showBadge end, function(value) DispelBorder().showBadge = value; Badges(); Refresh() end),
				OptionSlider('Icon Size', 10, 48, function() return DispelBadge().size end, function(value) DispelBadge().size = value; Badges() end),
				OptionDropdown('Icon Anchor', ANCHOR_ITEMS, function() return DispelBadge().anchor end, function(value) DispelBadge().anchor = value; Badges() end),
				OptionSlider('Icon X Offset', -200, 200, function() return DispelBadge().offsetX end, function(value) DispelBadge().offsetX = value; Badges() end),
				OptionSlider('Icon Y Offset', -200, 200, function() return DispelBadge().offsetY end, function(value) DispelBadge().offsetY = value; Badges() end),
			}, 300)
			local previewEye = PreviewEye(row, GroupFrames().IsDispelPreviewActive(), function()
				if GroupFrames().IsDispelPreviewActive() then GroupFrames().StopDispelPreview() else GroupFrames().StartDispelPartyPreview() end
			end, 'Cycle dispel colors on the party frames')
			return { previewEye, settingsCog }
		end,
	})
	AddRow(tab, rows, {
		title = 'Dispel Type Colors',
		description = 'Shared with the unit frames and the color editor.',
		plain = true,
		accessoryWidth = 180,
		accessories = function(row)
			local colorStore = BUI.Colors.GetStore()
			local swatches = {}
			local out = { Controls.Icon(row, {
				texture = BUILib.GetLibMedia('reset'), tooltip = 'Reset to default',
				onClick = function()
					BUI.Colors.ResetGroup('Dispel Types')
					for storeKey, swatch in pairs(swatches) do
						local stored = colorStore[storeKey]
						swatch:SetColor(stored.r, stored.g, stored.b, stored.a)
					end
					BUI.ApplyColors()
				end,
			}) }
			for _, typeName in ipairs({ 'Bleed', 'Poison', 'Disease', 'Curse', 'Magic' }) do
				local storeKey = BUI.AuraEngine.DispelColorKey(typeName)
				local stored = colorStore[storeKey]
				if stored then
					local swatch = Controls.ColorSwatch(row, {
						r = stored.r, g = stored.g, b = stored.b, a = stored.a or 1,
						tooltip = typeName,
						callback = function(red, green, blue, alpha)
							stored.r, stored.g, stored.b, stored.a = red, green, blue, alpha
							Badges()
							Refresh()
						end,
					})
					swatches[storeKey] = swatch
					out[#out + 1] = swatch
				end
			end
			return out
		end,
	})
end

local function PrivateAurasRow(tab, rows, sectionKey)
	local Section, Refresh = SectionEnv(sectionKey)
	local function AuraSettings() return Section().privateAuras end
	AddRow(tab, rows, {
		title = 'Private Auras',
		description = 'Boss mechanics only you are allowed to see',
		checked = AuraSettings().enabled,
		callback = function(value) AuraSettings().enabled = value; Refresh() end,
		accessoryWidth = 70,
		accessories = function(row)
			local previewEye = PreviewEye(row, GroupFrames().IsAuraPreviewing(sectionKey, 'privateAuras'), function(value)
				GroupFrames().PreviewAuraKind(sectionKey, 'privateAuras', value)
			end, 'Show sample icons where private auras appear')
			return { previewEye, Cog(row, 'PRIVATE AURAS', 'Count, size & placement', {
				OptionSlider('Count', 1, 4, function() return AuraSettings().num end, function(value) AuraSettings().num = value; Refresh() end),
				OptionSlider('Icon Size', 12, 48, function() return AuraSettings().size end, function(value) AuraSettings().size = value; Refresh() end),
				OptionCheckbox('Show Timer', function() return AuraSettings().showTimer end, function(value) AuraSettings().showTimer = value; Refresh() end),
				OptionDropdown('Grow Direction', GROW_ITEMS, function() return AuraSettings().growDirection end, function(value) AuraSettings().growDirection = value; Refresh() end),
				OptionDropdown('Anchor', ANCHOR_ITEMS, function() return AuraSettings().anchorPoint end, function(value) AuraSettings().anchorPoint = value; AuraSettings().relativePoint = value; Refresh() end),
				OptionSlider('X Offset', -200, 200, function() return AuraSettings().offsetX end, function(value) AuraSettings().offsetX = value; Refresh() end),
				OptionSlider('Y Offset', -200, 200, function() return AuraSettings().offsetY end, function(value) AuraSettings().offsetY = value; Refresh() end),
			}) }
		end,
	})
end

local function SectionHeader(tab, sectionKey, title, subtitle, rowsRef)
	local Section, Refresh = SectionEnv(sectionKey)
	local isParty = sectionKey == 'party'
	Layout.ModuleHeader(tab, {
		icon     = isParty and 'Interface\\Icons\\Achievement_pvp_a_05' or 'Interface\\Icons\\Achievement_pvp_a_16',
		title    = title,
		subtitle = subtitle,
		iconToggles = true,
		enabled  = Section().enabled,
		onToggle = function(value)
			Section().enabled = value; Refresh()
			for rowIndex = 1, #rowsRef do rowsRef[rowIndex]:SetRowEnabled(value) end
		end,
		action = {
			icon    = 'eye',
			tooltip = 'Toggle preview (forces the real frames to show)',
			value   = isParty and GroupFrames().IsPartyPreviewShown() or GroupFrames().IsRaidPreviewShown(),
			onClick = function()
				if isParty then GroupFrames().TogglePartyPreview() else GroupFrames().ToggleRaidPreview() end
			end,
		},
	})
end

local function BuildPartyTab(tab)
	local Section, Refresh = SectionEnv('party')
	local rows = {}
	SectionHeader(tab, 'party', 'Party Frames', 'Compact party frames with auras, dispels and indicators.', rows)

	Layout.Section(tab, 'Layout')
	AddRow(tab, rows, {
		title = 'Sorting',
		description = 'How party members are ordered',
		controlWidth = 192,
		control = function(row)
			return Dropdown(row, SORT_BY_ITEMS, function() return Section().sortBy end, function(value) Section().sortBy = value; Refresh() end, 160)
		end,
		accessoryWidth = 40,
		accessories = function(row)
			return { Cog(row, 'SORTING', 'Role & class order', {
				OptionDropdown('Role Order', ROLE_ORDER_ITEMS, function() return Section().roleOrder end, function(value) Section().roleOrder = value; Refresh() end, 170),
				OptionDropdown('Class Order', CLASS_ORDER_ITEMS, function() return Section().classOrder end, function(value) Section().classOrder = value; Refresh() end, 170),
			}, 320) }
		end,
	})
	AddRow(tab, rows, {
		title = 'Visibility',
		description = 'When the party frames are shown',
		controlWidth = 232,
		control = function(row)
			return Dropdown(row, RAID_GROUP_ITEMS, function() return Section().raidGroup end, function(value) Section().raidGroup = value; Refresh() end, 200)
		end,
		accessoryWidth = 40,
		accessories = function(row)
			return { Cog(row, 'VISIBILITY', 'Self & solo', {
				OptionCheckbox('Show Self In Party', function() return Section().showPlayer end, function(value) Section().showPlayer = value; Refresh() end),
				OptionCheckbox('Show When Solo', function() return Section().showSolo end, function(value) Section().showSolo = value; Refresh() end),
			}) }
		end,
	})
	DimensionsRow(tab, rows, 'party', false)
	PositionRow(tab, rows, 'party')

	Layout.Section(tab, 'Appearance')
	AppearanceRows(tab, rows, 'party')

	Layout.Section(tab, 'Text')
	TextRows(tab, rows, 'party')

	Layout.Section(tab, 'Indicators')
	IndicatorRows(tab, rows, 'party')

	Layout.Section(tab, 'Tooltips')
	TooltipRows(tab, rows, 'party')

	for rowIndex = 1, #rows do rows[rowIndex]:SetRowEnabled(Section().enabled) end
end

local function BuildRaidTab(tab)
	local Section, Refresh = SectionEnv('raid')
	local rows = {}
	SectionHeader(tab, 'raid', 'Raid Frames', 'Group-based raid frames for 10 to 40 players.', rows)

	Layout.Section(tab, 'Layout')
	AddRow(tab, rows, {
		title = 'Role Icons',
		description = 'Who gets a tank, healer or DPS icon',
		controlWidth = 202,
		control = function(row)
			return Dropdown(row, ROLE_ICON_ITEMS, function() return Section().roleIconFilter end, function(value) Section().roleIconFilter = value; Refresh() end, 170)
		end,
	})
	AddRow(tab, rows, {
		title = 'Fit Groups To Instance',
		description = 'Skip groups past the instance size cap',
		checked = Section().clampGroups ~= false,
		callback = function(value) Section().clampGroups = value; Refresh() end,
	})
	AddRow(tab, rows, {
		title = 'Sorting',
		description = 'Grouped grid, or one list sorted across the raid',
		controlWidth = 202,
		control = function(row)
			return Dropdown(row, RAID_LAYOUT_ITEMS, function()
				return Section().raidWideSorting and Section().wideSortBy or 'GROUPS'
			end, function(value)
				if value == 'GROUPS' then
					Section().raidWideSorting = false
				else
					Section().raidWideSorting = true
					Section().wideSortBy = value
				end
				Refresh()
			end, 170)
		end,
		accessoryWidth = 40,
		accessories = function(row)
			return { Cog(row, 'SORTING', 'Order & column size', {
				OptionDropdown('Role Order', ROLE_ORDER_ITEMS, function() return Section().roleOrder end, function(value) Section().roleOrder = value; Refresh() end, 170),
				OptionDropdown('Class Order', CLASS_ORDER_ITEMS, function() return Section().classOrder end, function(value) Section().classOrder = value; Refresh() end, 170),
				OptionSlider('Units Per Column', 5, 40, function() return Section().wideUnitsPerColumn end, function(value) Section().wideUnitsPerColumn = value; Refresh() end, 5),
			}, 320) }
		end,
	})
	AddRow(tab, rows, {
		title = 'Large Raid Layout',
		description = 'Different sizing once the raid grows',
		checked = Section().large.enabled,
		callback = function(value) Section().large.enabled = value; Refresh() end,
		accessoryWidth = 40,
		accessories = function(row)
			local function LargeRaid() return Section().large end
			return { Cog(row, 'LARGE RAID', 'Threshold & sizing', {
				OptionSlider('Switch At Raid Size', 11, 40, function() return LargeRaid().threshold end, function(value) LargeRaid().threshold = value; Refresh() end),
				OptionSlider('Width', 40, 300, function() return LargeRaid().width end, function(value) LargeRaid().width = value; Refresh() end),
				OptionSlider('Height', 14, 80, function() return LargeRaid().height end, function(value) LargeRaid().height = value; Refresh() end),
				OptionSlider('Power Height', 0, 16, function() return LargeRaid().powerHeight end, function(value) LargeRaid().powerHeight = value; Refresh() end),
				OptionSlider('Frame Spacing', 0, 40, function() return LargeRaid().spacing end, function(value) LargeRaid().spacing = value; Refresh() end),
				OptionSlider('Group Spacing', 0, 40, function() return LargeRaid().groupSpacing end, function(value) LargeRaid().groupSpacing = value; Refresh() end),
				OptionSlider('Groups Per Row', 1, 8, function() return LargeRaid().groupsPerRow end, function(value) LargeRaid().groupsPerRow = value; Refresh() end),
			}) }
		end,
	})
	DimensionsRow(tab, rows, 'raid', true)
	PositionRow(tab, rows, 'raid')

	Layout.Section(tab, 'Appearance')
	AppearanceRows(tab, rows, 'raid')

	Layout.Section(tab, 'Text')
	TextRows(tab, rows, 'raid')

	Layout.Section(tab, 'Indicators')
	IndicatorRows(tab, rows, 'raid')

	Layout.Section(tab, 'Tooltips')
	TooltipRows(tab, rows, 'raid')

	for rowIndex = 1, #rows do rows[rowIndex]:SetRowEnabled(Section().enabled) end
end

local function BuildAuraTab(tab, sectionKey)
	local title = sectionKey == 'party' and 'Party Auras' or 'Raid Auras'
	Layout.Section(tab, title, 'Buffs, debuffs, defensives, crowd control, dispels and private auras.')
	local rows = {}
	AuraContainerRow(tab, rows, sectionKey, 'buffs',        'Buffs',         'Helpful auras on each member')
	AuraContainerRow(tab, rows, sectionKey, 'debuffs',      'Debuffs',       'Harmful auras on each member')
	AuraContainerRow(tab, rows, sectionKey, 'bigDef',       'Defensives',    'Major defensive cooldowns')
	AuraContainerRow(tab, rows, sectionKey, 'crowdControl', 'Crowd Control', 'Stuns, fears and other loss of control')
	DispelRow(tab, rows, sectionKey)
	PrivateAurasRow(tab, rows, sectionKey)
end

local function BuildGeneralTab(tab)
	local config = Config()
	local rows = {}

	Layout.ModuleHeader(tab, {
		icon     = BUI.C.ICON_PATH,
		title    = 'Group Frames',
		subtitle = 'Party and raid frames, rebuilt. Replaces the Blizzard group frames.',
		iconToggles = true,
		enabled  = config.enabled,
		onToggle = function(value)
			Config().enabled = value
			GroupFrames().SetEnabledLive(value)
			for rowIndex = 1, #rows do rows[rowIndex]:SetRowEnabled(value) end
			if not value then
				Modals.Confirm({
					parent = BUI.PageEngine.window.frame,
					title = 'Disable Group Frames',
					message = 'Frames are hidden now, but the Blizzard party/raid frames only come back after a UI reload.\n\nReload now?',
					confirmText = 'Reload', cancelText = 'Later',
					onConfirm = function() BUI.Reload() end,
				})
			end
		end,
	})

	if C_AddOns.IsAddOnLoaded('BluFrames') then
		Layout.Section(tab, 'Standalone Blu Frames detected',
			'Your settings were imported, but the module stays idle while the standalone addon is running. Remove or disable the BluFrames addon, then /reload.')
	end

	Layout.Section(tab, 'Behavior')
	AddRow(tab, rows, {
		title = 'Hide Blizzard Frames',
		description = 'Replaces the default party and raid frames',
		checked = config.hideBlizzardFrames ~= false,
		callback = function(value)
			Config().hideBlizzardFrames = value
			if value then
				if GroupFrames().IsActive() then
					GroupFrames().HideBlizzardParty(); GroupFrames().HideBlizzardRaid(); GroupFrames().HideBlizzardRaidManager()
				end
			else
				Modals.Confirm({
					parent = BUI.PageEngine.window.frame,
					title = 'Restore Blizzard Frames',
					message = 'Blizzard party/raid frames only come back after a UI reload.\n\nReload now?',
					confirmText = 'Reload', cancelText = 'Later',
					onConfirm = function() BUI.Reload() end,
				})
			end
		end,
	})
	AddRow(tab, rows, {
		title = 'Click Casting',
		description = 'When clicks on frames register',
		controlWidth = 182,
		control = function(row)
			return Dropdown(row, CLICK_MODE_ITEMS, function() return Config().clickMode end, function(value) Config().clickMode = value; GroupFrames().RefreshClickMode() end, 150)
		end,
	})

	Layout.Section(tab, 'Range Fading')
	local function RangeSettings() return Config().range end
	local RefreshRange = function() GroupFrames().RefreshRange() end
	AddRow(tab, rows, {
		title = 'Fade Out Of Range',
		description = 'Dims members you cannot reach',
		checked = RangeSettings().enabled,
		callback = function(value) RangeSettings().enabled = value; RefreshRange() end,
		accessoryWidth = 40,
		accessories = function(row)
			return { Cog(row, 'RANGE FADING', 'Alphas & offline fading', {
				OptionCheckbox('Fade Offline', function() return RangeSettings().fadeOffline end, function(value) RangeSettings().fadeOffline = value; RefreshRange() end),
				OptionSlider('In-Range Alpha', 0.1, 1.0, function() return RangeSettings().insideAlpha end, function(value) RangeSettings().insideAlpha = value; RefreshRange() end, 0.05),
				OptionSlider('Out-Of-Range Alpha', 0.1, 1.0, function() return RangeSettings().outsideAlpha end, function(value) RangeSettings().outsideAlpha = value; RefreshRange() end, 0.05),
			}) }
		end,
	})

	for rowIndex = 1, #rows do rows[rowIndex]:SetRowEnabled(config.enabled) end
end

local function ShareBlacklistToggle(tab, label)
	local AuraBlacklist = BUI.AuraBlacklist
	local toggleControl = Controls.Toggle(tab.child, label, AuraBlacklist.IsShared(), function(value)
		AuraBlacklist.SetShared(value)
		AuraBlacklist.RefreshConsumers()
		C_Timer.After(0, function() BUI.PageEngine.RebuildAllPages() end)
	end, 0, true, nil, tab.width, 'Both frame modules use one combined blacklist.')
	Layout.PositionInTab(tab, toggleControl, 40)
end
BUI.ShareBlacklistToggle = ShareBlacklistToggle

local function BuildFiltersTab(tab)
	ShareBlacklistToggle(tab, 'Share Blacklists With Unit Frames')

	BUI.BlacklistSection(tab, {
		scope = 'group', polarity = 'HARMFUL',
		title = 'Debuff Blacklist',
		desc  = 'Debuffs that never show on the frames.',
		onError = function(message) GroupFrames().Print(message) end,
	})
	BUI.BlacklistSection(tab, {
		scope = 'group', polarity = 'HELPFUL',
		title = 'Buff Blacklist',
		desc  = 'Buffs that never show on the frames.',
		onError = function(message) GroupFrames().Print(message) end,
	})
end

BUI.PageEngine.RegisterPage('groupframes', {
	title = 'Group Frames',
	buttonText = 'Group Frames',
	OnBuild = function(pageFrame)
		if not BUI.IsModuleEnabled('groupFrames') then
			local page = Layout.Page(pageFrame, nil)
			Layout.Section(page:GetTab(1), 'Group Frames',
				'This module is turned off in Settings > Modules. Enable it there and /reload to use party and raid frames.')
			page:AutoRefresh()
			return
		end

		local page = Layout.Page(pageFrame, Tabs)
		pageFrame._page = page

		local builders = {
			BuildGeneralTab,
			BuildPartyTab,
			BuildRaidTab,
			function(tab) BuildAuraTab(tab, 'party') end,
			function(tab) BuildAuraTab(tab, 'raid') end,
			BuildFiltersTab,
		}
		for tabIndex, build in ipairs(builders) do
			build(page:GetTab(tabIndex))
		end

		page:AutoRefresh()
	end,
	OnHide = function()
		BUI.GroupFrames.CloseAllPreviews()
	end,
})
