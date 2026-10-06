local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout, Modals = BUILib.Layout, BUILib.Modals
local Pixel = BUI.Pixel
local AuraLists = BUI.AuraLists

local PAGE_WIDTH = 960
local PREVIEW_HEIGHT = 150
local MENU_WIDTH = 150
local WIDE_MENU = 200
local TAG_WIDTH = 300
local TAB_STRIP_GAP = 12
local LINE_WIDTH = 40
local DEFAULT_ROW = 40
local RESET_COLUMN = { '', 'reset', 42, 'CENTER' }
local SETTING_COLUMNS = { { 'Setting', 'name', 130 }, { 'Shows', 'sub' }, { 'Options', 'icon', 70, 'CENTER' }, RESET_COLUMN, { 'Enabled', 'switch', 70, 'CENTER' } }
local BAR_COLUMNS = { { 'Setting', 'name', 130 }, { 'Shows', 'sub' }, { 'Colors', 'swatch', 100 }, { 'Options', 'icon', 60, 'CENTER' }, RESET_COLUMN, { 'Preview', 'toggle', 50, 'CENTER' }, { 'Enabled', 'switch', 70, 'CENTER' } }
local DISPEL_COLUMNS = { { 'Setting', 'name', 130 }, { 'Shows', 'sub' }, { 'Colors', 'swatch', 140 }, { 'Options', 'icon', 60, 'CENTER' }, RESET_COLUMN, { 'Preview', 'toggle', 50, 'CENTER' }, { 'Enabled', 'switch', 70, 'CENTER' } }
local NAME_WIDTH = 200
local TEXT_RANGE = 50
local AURA_RANGE = 500
local BADGE_RANGE_X = 600
local BADGE_RANGE_Y = 400
local ICON_RANGE = 50
local TAG_RANGE = 200
local POSITION_RANGE_X = 4000
local POSITION_RANGE_Y = 3000
local PREVIEW_GAP = 18
local PREVIEW_PAIR_WIDTH = 340
local PREVIEW_WIDTH = 620
local PREVIEW_FRAME_HEIGHT = 80
local PREVIEW_BOSS_HEIGHT = 72

local UNITS = {
	{ key = 'player', label = 'Player', title = 'Player frame', description = 'Position, texts, indicators and auras for your own frame.' },
	{ key = 'target', label = 'Target', title = 'Target frame', description = 'Layout and auras for your current target.' },
	{ key = 'targettarget', label = 'Target of target', title = 'Target of target', description = 'Compact frame showing what your target is targeting.' },
	{ key = 'focus', label = 'Focus', title = 'Focus frame', description = 'Layout and auras for your focus.' },
	{ key = 'pet', label = 'Pet', title = 'Pet frame', description = 'Layout and colors for your pet.' },
	{ key = 'boss', label = 'Boss', title = 'Boss frames', description = 'Up to five stacked frames for boss encounters.' },
}
local UNIT_BY_KEY = {}
for _, unit in ipairs(UNITS) do UNIT_BY_KEY[unit.key] = unit end
local ANCHORABLE = { player = true, target = true, focus = true, pet = true, targettarget = true }
local TAB_IDS = { 'appearance', 'tags', 'player', 'target', 'targettarget', 'focus', 'pet', 'boss', 'filters', 'general', 'party', 'raid', 'partyAuras', 'raidAuras', 'groupFilters' }
local GROUP_TABS = { general = true, party = true, raid = true, partyAuras = true, raidAuras = true, groupFilters = true }
local TAB_INDEX = { appearance = 1, tags = 2, player = 3, target = 4, targettarget = 5, focus = 6, pet = 7, boss = 8, filters = 9, general = 10, party = 11, raid = 12, partyAuras = 13, raidAuras = 14, groupFilters = 15 }
local GROUP_PANE = {}
local TAG_UNITS = {
	{ value = 'player', text = 'Player' },
	{ value = 'target', text = 'Target' },
	{ value = 'targettarget', text = 'Target of target' },
	{ value = 'focus', text = 'Focus' },
	{ value = 'pet', text = 'Pet' },
	{ value = 'boss', text = 'Boss' },
}
local LAYERS = {
	{ value = 'BACKGROUND', text = 'Background' },
	{ value = 'BORDER', text = 'Border' },
	{ value = 'ARTWORK', text = 'Artwork' },
	{ value = 'OVERLAY', text = 'Overlay' },
	{ value = 'HIGHLIGHT', text = 'Highlight' },
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
local DISPEL_STYLES = {
	{ value = 'bar', text = 'Tint the whole bar' },
	{ value = 'top', text = 'Fade from the top' },
	{ value = 'bottom', text = 'Fade from the bottom' },
}
local DISPEL_SOURCES = {
	{ value = 'mine', text = 'Dispellable by me' },
	{ value = 'all', text = 'All dispel types' },
}
local DISPEL_TYPES = { 'Bleed', 'Poison', 'Disease', 'Curse', 'Magic' }
local GROWTHS_X = { { value = 'LEFT', text = 'Left' }, { value = 'RIGHT', text = 'Right' } }
local GROWTHS_Y = { { value = 'UP', text = 'Up' }, { value = 'DOWN', text = 'Down' } }
local STACKINGS = { { value = 'DOWN', text = 'Down, boss one on top' }, { value = 'UP', text = 'Up, boss one at the bottom' } }
local STACK_POINTS = {}
for _, point in ipairs({ 'TOPLEFT', 'TOP', 'TOPRIGHT', 'LEFT', 'CENTER', 'RIGHT', 'BOTTOMLEFT', 'BOTTOM', 'BOTTOMRIGHT' }) do
	STACK_POINTS[#STACK_POINTS + 1] = { value = point, text = point:sub(1, 1) .. point:sub(2):lower():gsub('left', ' left'):gsub('right', ' right') }
end
local TAGS = {
	{ group = 'Names', tag = '[name]', description = 'Full name', example = 'Bluetempest' },
	{ group = 'Names', tag = '[name:short]', description = 'Ten letters', example = 'Bluetempes' },
	{ group = 'Names', tag = '[name:short5]', description = 'Five letters', example = 'Bluet' },
	{ group = 'Names', tag = '[name:target>]', description = 'Name then target', example = 'Blue.. > Ragn..' },
	{ group = 'Names', tag = '[name5:target5>]', description = 'Both cut to five letters', example = 'Bluet > Ragni' },
	{ group = 'Names', tag = '[name8:target>]', description = 'Eight letters then the full target', example = 'Bluetemp > Ragnaros' },
	{ group = 'Health', tag = '[hp]', description = 'Health', example = '75000' },
	{ group = 'Health', tag = '[hp:short]', description = 'Abbreviated', example = '75K' },
	{ group = 'Health', tag = '[maxhp]', description = 'Maximum', example = '100000' },
	{ group = 'Health', tag = '[maxhp:short]', description = 'Maximum abbreviated', example = '100K' },
	{ group = 'Health', tag = '[perhp]', description = 'Percent', example = '75' },
	{ group = 'Power', tag = '[pp]', description = 'Power', example = '9000' },
	{ group = 'Power', tag = '[pp:short]', description = 'Abbreviated', example = '9K' },
	{ group = 'Power', tag = '[maxpp]', description = 'Maximum', example = '10000' },
	{ group = 'Power', tag = '[maxpp:short]', description = 'Maximum abbreviated', example = '10K' },
	{ group = 'Power', tag = '[perpp]', description = 'Percent', example = '60' },
	{ group = 'Power', tag = '[powertype]', description = 'Type', example = 'Mana' },
	{ group = 'Mana', tag = '[mana]', description = 'Mana', example = '8000' },
	{ group = 'Mana', tag = '[mana:short]', description = 'Abbreviated', example = '8K' },
	{ group = 'Mana', tag = '[maxmana]', description = 'Maximum', example = '10000' },
	{ group = 'Mana', tag = '[permana]', description = 'Percent', example = '80' },
	{ group = 'Player', tag = '[class]', description = 'Class in capitals', example = 'HUNTER' },
	{ group = 'Player', tag = '[classname]', description = 'Class name', example = 'Hunter' },
	{ group = 'Player', tag = '[race]', description = 'Race', example = 'Night Elf' },
	{ group = 'Player', tag = '[level]', description = 'Level', example = '80' },
	{ group = 'Player', tag = '[spec]', description = 'Specialization', example = 'Marksmanship' },
	{ group = 'Player', tag = '[itemlevel]', description = 'Item level', example = '639' },
	{ group = 'Player', tag = '[title]', description = 'Title', example = 'the Exalted' },
	{ group = 'Player', tag = '[role]', description = 'Role icon', example = 'icon' },
	{ group = 'Player', tag = '[role:text]', description = 'Role text', example = 'DPS' },
	{ group = 'Creature', tag = '[creature]', description = 'Pet family or creature type', example = 'Cat' },
	{ group = 'Creature', tag = '[creaturefamily]', description = 'Pet family', example = 'Cat' },
	{ group = 'Creature', tag = '[creaturetype]', description = 'Creature type', example = 'Beast' },
	{ group = 'Creature', tag = '[classification]', description = 'Classification', example = 'Boss' },
	{ group = 'Creature', tag = '[difficulty]', description = 'Instance difficulty', example = 'Mythic' },
	{ group = 'Status', tag = '[status]', description = 'Dead, ghost or offline', example = 'Dead' },
	{ group = 'Status', tag = '[dead]', description = 'Dead', example = 'Dead' },
	{ group = 'Status', tag = '[offline]', description = 'Disconnected', example = 'Offline' },
	{ group = 'Status', tag = '[afk]', description = 'Away', example = 'AFK' },
	{ group = 'Status', tag = '[combat]', description = 'In combat', example = '!' },
	{ group = 'Status', tag = '[resting]', description = 'Resting', example = 'zzz' },
	{ group = 'Live', tag = '[combattime]', description = 'Combat timer', example = '01:23' },
	{ group = 'Live', tag = '[threat]', description = 'Threat on the target', example = '42%' },
	{ group = 'Live', tag = '[range]', description = 'Distance to the unit', example = '25-30' },
	{ group = 'Other', tag = '[server]', description = 'Realm', example = 'Kazzak' },
	{ group = 'Other', tag = '[absorbs]', description = 'Absorb shield', example = '5K' },
	{ group = 'Other', tag = '[hpabsorb]', description = 'Health plus absorb', example = '492000' },
	{ group = 'Other', tag = '[hpabsorb:short]', description = 'Health plus absorb abbreviated', example = '492K' },
	{ group = 'Other', tag = '[target]', description = 'Target name', example = 'Ragnaros' },
	{ group = 'Other', tag = '[group]', description = 'Raid group', example = '3' },
}
local TAG_GROUPS = { 'Names', 'Health', 'Power', 'Mana', 'Player', 'Creature', 'Status', 'Live', 'Other' }
local DEFAULT_TAGS = { name = '[name]', health = '[hp:short] • [perhp]%', power = '[perpp]%', status = '[status]' }

local selected = 'appearance'
local tagUnit = 'player'
local tagsTab = 1
local preview
local fonts, textures

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function Settings()
	return BUI.GetDB().unitFrames
end

local function UnitFrames()
	return BUI.UnitFrames
end

local function RefreshPreview()
	if preview then preview:Update() end
end

local function RebuildPane(page)
	BUILib.Defer(function() page:RebuildCurrent() end)
end

local function ResolveShow(specific, fallback, defaultOn)
	if specific ~= nil then return specific == true end
	if defaultOn == false then return fallback == true end
	return fallback ~= false
end

local factoryOf = setmetatable({}, { __mode = 'k' })
local NO_FACTORY = {}

local function MapFactory(live, factory)
	factoryOf[live] = factory
	for key, value in pairs(factory) do
		local child = live[key]
		if type(value) == 'table' and type(child) == 'table' and not factoryOf[child] then MapFactory(child, value) end
	end
end

local function FactoryFor(db)
	if factoryOf[db] == nil then
		MapFactory(BUI.GetDB(), BUI.ExportImport.FactoryProfile())
		if factoryOf[db] == nil then factoryOf[db] = false end
	end
	return factoryOf[db] or NO_FACTORY
end

local READERS = {
	on = function(value) return value == true end,
	off = function(value) return value ~= false end,
}

local function Setting(db, label, key, shape, extra)
	local read = READERS[shape]
	local option = { label = label }
	option.get = function()
		if read then return read(db[key]) end
		return db[key]
	end
	option.set = function(value)
		db[key] = value
		if option.onChange then option.onChange() end
	end
	option.default = function()
		if read then return read(FactoryFor(db)[key]) end
		return FactoryFor(db)[key]
	end
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Option(db, label, key, extra)
	return Setting(db, label, key, nil, extra)
end

local function Inherit(unitSettings, label, key, extra)
	local option = { label = label, get = function()
		local value = unitSettings[key]
		if value == nil then value = Settings()[key] end
		return value
	end, set = function(value) unitSettings[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Toggle(db, label, key, extra)
	return Setting(db, label, key, 'on', extra)
end

local function OnUnlessOff(db, label, key, extra)
	return Setting(db, label, key, 'off', extra)
end

local function Color(db, label, key)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = true,
		get = function()
			local color = db[key]
			return color[1], color[2], color[3], color[4] or 1
		end,
		set = function(red, green, blue, alpha) db[key] = { red, green, blue, alpha } end,
		default = function()
			local color = FactoryFor(db)[key]
			if color then return color[1], color[2], color[3], color[4] or 1 end
		end,
	}
end

local function StoreColor(key, tooltip)
	local stored = BUI.Colors.GetStore()[key]
	return {
		kind = 'swatch', tooltip = tooltip, opacity = true,
		get = function() return stored.r, stored.g, stored.b, stored.a end,
		set = function(red, green, blue, alpha) stored.r, stored.g, stored.b, stored.a = red, green, blue, alpha end,
		default = function()
			for _, group in ipairs(BUI.Colors.GROUPS) do
				for _, entry in ipairs(group.colors) do
					if entry.key == key then return entry.def[1], entry.def[2], entry.def[3], entry.def[4] or 1 end
				end
			end
		end,
	}
end

local function Menu(db, key, entries, width)
	return { entries = entries, width = width or MENU_WIDTH, get = function() return db[key] end, set = function(value) db[key] = value end, default = function() return FactoryFor(db)[key] end }
end

local function TagInput(db, key, placeholder, width)
	return { kind = 'input', width = width or TAG_WIDTH, placeholder = placeholder, get = function() return db[key] or '' end, set = function(text) db[key] = text ~= '' and text or nil end }
end

local function Eye(tooltip, get, set)
	return { icon = 'eye', tooltip = tooltip, get = get, set = function(value)
		set(value)
		Repaint()
	end }
end

local function PreviewEye(unitKey, spotlight)
	local function Lit()
		local module = UnitFrames()
		return module.IsPreviewShown(unitKey) and (spotlight == nil or module.GetPreviewSpotlight() == spotlight)
	end
	return Eye('Show a movable preview of this frame in the world', Lit, function(value)
		local module = UnitFrames()
		if value then
			module.SetPreviewSpotlight(spotlight)
			if module.IsPreviewShown(unitKey) then module.UpdatePreviews() else module.ShowPreview(unitKey) end
		else
			module.SetPreviewSpotlight(nil)
			module.HidePreview(unitKey)
		end
		RefreshPreview()
	end)
end

local function MirrorKeys(source, destination)
	local blocked = { enabled = true, width = true, height = true, position = true, spacing = true, growthDirection = true, anchorFrame = true, anchorPoint = true, anchorOffsetX = true, anchorOffsetY = true, matchAnchorWidth = true, matchAnchorHeight = true, customName = true }
	for key in pairs(source) do
		if not blocked[key] and not (type(key) == 'string' and key:sub(1, 1) == '_') then destination[key] = BUI.Tools.DeepCopy(source[key]) end
	end
end

local function IsDriven(unitKey)
	local stash = Settings()._syncStash
	return stash ~= nil and stash[unitKey] ~= nil
end

local function SetDriven(unitKey, driven)
	local settings = Settings()
	if driven and not IsDriven(unitKey) then
		settings._syncStash = settings._syncStash or {}
		local snapshot = {}
		MirrorKeys(settings[unitKey], snapshot)
		settings._syncStash[unitKey] = snapshot
		MirrorKeys(settings.player, settings[unitKey])
	elseif not driven and IsDriven(unitKey) then
		MirrorKeys(settings._syncStash[unitKey], settings[unitKey])
		settings._syncStash[unitKey] = nil
	end
end

local function ApplySync()
	local settings = Settings()
	local on = settings.syncPlayerTarget == true
	SetDriven('target', on)
	SetDriven('pet', on and not settings.excludePetFromSync)
end

local function PropagatePlayer()
	local settings = Settings()
	if IsDriven('target') then MirrorKeys(settings.player, settings.target) end
	if IsDriven('pet') then MirrorKeys(settings.player, settings.pet) end
end

local RefreshFrames = BUI.Dispatcher.NewDelayed(function()
	PropagatePlayer()
	local module = UnitFrames()
	module.InvalidateSettingsCache()
	module:Refresh()
	module.UpdatePreviews()
	RefreshPreview()
end, 0.1, 'Unit frames refresh')

local function RefreshAuras()
	PropagatePlayer()
	local module = UnitFrames()
	module.InvalidateSettingsCache()
	for _, unit in ipairs(UNITS) do
		if module.GetUnitConfig(unit.key).hasAuras then
			if unit.key == 'boss' then
				for index = 1, 5 do
					local boss = module['boss' .. index]
					if boss then module.RefreshAuraLayout(boss, 'boss') end
				end
			elseif module[unit.key] then
				module.RefreshAuraLayout(module[unit.key], unit.key)
			end
		end
	end
	module.UpdatePreviews()
	RefreshPreview()
end

local function RefreshFilters()
	UnitFrames().InvalidateFilterCache()
	RefreshAuras()
end

local function BuildPreview(band, kit)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetAllPoints()
	stage:SetClipsChildren(true)
	local captions = { kit.Text(stage, 'PLAYER', 9, 'faint'), kit.Text(stage, 'TARGET', 9, 'faint') }
	local notice = kit.Text(stage, 'Preview after combat', 12, 'muted')
	notice:SetPoint('CENTER')
	notice:Hide()
	local groupNote = kit.Text(stage, 'Party and raid frames preview in the world, use the eye on their rows', 12, 'muted')
	groupNote:SetPoint('CENTER')
	groupNote:Hide()
	local captionY = -(PREVIEW_HEIGHT / 2) + 16
	function band:Update()
		local module = UnitFrames()
		local combat = InCombatLockdown()
		notice:SetShown(combat)
		groupNote:SetShown(not combat and GROUP_TABS[selected] == true)
		if combat then return end
		module.ClearStage(stage)
		for _, caption in ipairs(captions) do caption:Hide() end
		if GROUP_TABS[selected] then return end
		if selected == 'appearance' or selected == 'filters' then
			local playerX, targetX = module.StagePair(stage, kit, PREVIEW_PAIR_WIDTH, PREVIEW_FRAME_HEIGHT, PREVIEW_GAP)
			if not playerX then return end
			for index, x in ipairs({ playerX, targetX }) do
				captions[index]:ClearAllPoints()
				captions[index]:SetPoint('CENTER', stage, 'CENTER', x, captionY)
				captions[index]:Show()
			end
			return
		end
		local unitKey = selected == 'tags' and tagUnit or selected
		if unitKey == 'boss' then
			local first, _, firstHeight = module.StageInto(stage, kit, 'boss', 1, PREVIEW_WIDTH, PREVIEW_BOSS_HEIGHT)
			local second = module.StageInto(stage, kit, 'boss', 2, PREVIEW_WIDTH, PREVIEW_BOSS_HEIGHT)
			if not first or not second then return end
			local boss = Settings().boss
			local offset = (firstHeight + boss.spacing * first:GetScale()) / 2
			local top = boss.growthDirection == 'DOWN' and offset or -offset
			module.PlaceStaged(first, stage, 0, top)
			module.PlaceStaged(second, stage, 0, -top)
			return
		end
		local frame = module.StageInto(stage, kit, unitKey, nil, PREVIEW_WIDTH, PREVIEW_FRAME_HEIGHT)
		if frame then module.PlaceStaged(frame, stage, 0, 0) end
	end
	band:HookScript('OnShow', function(self) self:Update() end)
	return band
end

local OVERRIDE_SUFFIXES = { 'Position', 'TextSize', 'OffsetX', 'OffsetY' }

local function HasOverrides(unitSettings, prefix)
	local settings = Settings()
	for _, suffix in ipairs(OVERRIDE_SUFFIXES) do
		local value = unitSettings[prefix .. suffix]
		if value ~= nil and value ~= settings[prefix .. suffix] then return true end
	end
	return false
end

local function ClearOverrides(unitSettings, prefix)
	for _, suffix in ipairs(OVERRIDE_SUFFIXES) do unitSettings[prefix .. suffix] = nil end
	RefreshFrames()
	Repaint()
end

local function DefaultFormat(key, fallback)
	local value = Settings()[key]
	if value ~= nil and value ~= '' then return value end
	return fallback
end

local function ResetTool(ui, tooltip, isChanged, reset)
	return { slot = 'icon', build = function(parent)
		local button = ui.IconButton(parent, 'redo', tooltip, reset, 'text', 16, 'accent')
		ui.Bind(button, function() button:SetShown(isChanged()) end)
		return button
	end }
end

local function RowReset(ui, tools, after)
	local entries = {}
	for _, tool in ipairs(tools) do
		if tool.slot == 'reset' then return tools end
		for _, option in ipairs(tool.options or { tool }) do
			if option.default then entries[#entries + 1] = option end
		end
	end
	if #entries == 0 then return tools end
	local reset = ResetTool(ui, 'Changed from the factory default, click to restore it', function()
		for _, option in ipairs(entries) do
			local a1, a2, a3, a4 = option.get()
			local d1, d2, d3, d4 = option.default()
			if a1 ~= d1 or a2 ~= d2 or a3 ~= d3 or a4 ~= d4 then return true end
		end
		return false
	end, function()
		for _, option in ipairs(entries) do option.set(option.default()) end
		if after then after() end
		Repaint()
	end)
	reset.slot = 'reset'
	tools[#tools + 1] = reset
	return tools
end

local function DropUnitPanes(page)
	for _, unit in ipairs(UNITS) do page:Rebuild(unit.key) end
end

local function ToolGrid(ui, parent, width, title, description, columns)
	local fixed = 0
	for _, column in ipairs(columns) do fixed = fixed + (column[3] or 0) end
	local specs = {}
	for index, column in ipairs(columns) do
		specs[index] = { title = column[1], slot = column[2], width = column[3] or (width - fixed), align = column[4] }
	end
	local grid = ui.Grid(parent, width, { title = title, description = description, rowHeight = DEFAULT_ROW, columns = specs })
	local AddTools = grid.AddTools
	function grid:AddTools(name, sub, tools, after)
		return AddTools(self, name, sub, RowReset(ui, tools, after), after)
	end
	return grid
end

local function AppearanceBoards(ui, parent, width, page)
	local settings = Settings()
	local module = UnitFrames()
	local function SyncChanged()
		ApplySync()
		RefreshFrames()
		RefreshPreview()
		page:Rebuild('target')
		page:Rebuild('pet')
	end
	local health = ToolGrid(ui, parent, width, 'Frames', 'Texture, font, behavior, bar colors and absorbs. The eye shows a movable preview of the player frame.', BAR_COLUMNS)
	health:AddTools('Look and behavior', 'Texture, font, tooltips, targeting and sync', {
		{ icon = 'text', tooltip = 'Texture and font', title = 'Look', options = {
			Option(settings, 'Bar texture', 'texture', { entries = textures, width = WIDE_MENU }),
			Option(settings, 'Font', 'font', { entries = fonts, width = WIDE_MENU }),
		} },
		{ tooltip = 'Behavior options', title = 'Behavior', options = {
			OnUnlessOff(settings, 'Unit tooltip on mouseover', 'showTooltips'),
			OnUnlessOff(settings, 'Clicking a frame targets its unit', 'clickToTarget', { onChange = function() module.ApplyClickToTarget() end }),
			Toggle(BUI.GetDB().general, 'Abbreviate numbers with one decimal, 7.5K', 'showDecimalAbbreviations', { onChange = function()
				module.RefreshAbbreviationSetting()
				module.InvalidateTagCache()
			end }),
			Toggle(settings, 'Target and pet copy the player frame look', 'syncPlayerTarget', { separator = true }),
			Toggle(settings, 'Keep the pet independent', 'excludePetFromSync'),
		} },
	}, SyncChanged)
	health:AddTools('Health bar', 'Health, background and border colors', {
		Color(settings, 'Health', 'healthColor'),
		Color(settings, 'Background', 'bgColor'),
		Color(settings, 'Border', 'borderColor'),
		{ tooltip = 'Health bar options', title = 'Health bar', options = {
			Toggle(settings, 'Fill with the class color', 'classColorHealth'),
		} },
	}, RefreshFrames)
	health:AddTools('Transparent health', 'See through health fill', {
		{ tooltip = 'Fill opacity', title = 'Transparent health', options = {
			{ label = 'Fill opacity %', min = 0, max = 100, step = 5, get = function() return math.floor(settings.healthBarAlpha * 100) end, set = function(value) settings.healthBarAlpha = value / 100 end, default = function() return math.floor(FactoryFor(settings).healthBarAlpha * 100) end },
		} },
		Toggle(settings, nil, 'transparentHealth'),
	}, RefreshFrames)
	health:AddTools('Damage absorb', 'Absorb shield overlay on the health bar', {
		Color(settings, 'Fill color', 'shieldColor'),
		{ tooltip = 'Texture and direction', title = 'Damage absorb', options = {
			Option(settings, 'Texture', 'shieldOverlay', { entries = ABSORB_TEXTURES }),
			Option(settings, 'Direction', 'shieldDirection', { entries = ABSORB_DIRECTIONS }),
		} },
		PreviewEye('player', 'absorb'),
		OnUnlessOff(settings, nil, 'shieldEnabled'),
	}, RefreshFrames)
	health:AddTools('Heal absorb', 'Heal absorb overlay on the health bar', {
		Color(settings, 'Fill color', 'healAbsorbColor'),
		{ tooltip = 'Texture and direction', title = 'Heal absorb', options = {
			Option(settings, 'Texture', 'healAbsorbOverlay', { entries = ABSORB_TEXTURES }),
			Option(settings, 'Direction', 'healAbsorbDirection', { entries = ABSORB_DIRECTIONS }),
		} },
		PreviewEye('player', 'healAbsorb'),
		OnUnlessOff(settings, nil, 'healAbsorbEnabled'),
	}, RefreshFrames)
	health:AddTools('Power bar', 'Power fill and background colors', {
		Color(settings, 'Power', 'powerColor'),
		Color(settings, 'Background', 'powerBgColor'),
		{ tooltip = 'Power bar options', title = 'Power bar', options = {
			Toggle(settings, 'Color by resource type, mana blue, energy yellow', 'classColorPower'),
			Toggle(settings, 'Color by class or reaction', 'useClassColorPowerBar'),
		} },
	}, RefreshFrames)

	local player = settings.player
	local function RefreshDispel()
		RefreshFrames()
		module.RefreshDispelPreview()
		BUI.GroupFrames.Refresh('party')
		BUI.GroupFrames.Refresh('raid')
	end
	local function DispelPreviewEye()
		return Eye('Cycle the dispel colors on your frame', module.IsDispelPreviewing, function(value)
			if value then module.StartDispelPreview() else module.StopDispelPreview() end
		end)
	end
	local dispel = ToolGrid(ui, parent, width, 'Dispels', 'Color your own frame when a dispellable debuff lands.', DISPEL_COLUMNS)
	dispel:AddTools('Dispel highlight', 'Frame reaction to a dispellable debuff', {
		{ tooltip = 'Style, source and strength', title = 'Dispel highlight', options = {
			Option(player, 'Style', 'debuffHighlightStyle', { entries = DISPEL_STYLES }),
			{ label = 'Show', entries = DISPEL_SOURCES, get = function() return player.debuffHighlightClassFilter ~= false and 'mine' or 'all' end, set = function(value) player.debuffHighlightClassFilter = value == 'mine' end, default = function() return FactoryFor(player).debuffHighlightClassFilter ~= false and 'mine' or 'all' end },
			Option(settings, 'Bar tint opacity %', 'dispelOpacity', { min = 0, max = 100, step = 5 }),
			Option(settings, 'Fade: colour at the middle %', 'dispelFadeMiddle', { min = 0, max = 100, step = 5, separator = true }),
			Option(settings, 'Fade: colour at the far edge %', 'dispelFadeFar', { min = 0, max = 100, step = 5 }),
			Option(settings, 'Fade: darkness at the far edge %', 'dispelFadeDark', { min = 0, max = 100, step = 5 }),
			Toggle(settings, 'Blend multiple types instead of showing the top one', 'dispelBlend', { separator = true }),
		} },
		DispelPreviewEye(),
		Toggle(player, nil, 'debuffHighlightBar'),
	}, RefreshDispel)
	local typeIcons = {}
	for _, typeName in ipairs(DISPEL_TYPES) do
		typeIcons[#typeIcons + 1] = StoreColor(BUI.AuraEngine.DispelColorKey(typeName), typeName .. ', shared with the party and raid frames')
	end
	typeIcons[#typeIcons + 1] = { tooltip = 'Size, position and prompts', title = 'Type icons', options = {
		Option(player, 'Size', 'debuffHighlightBadgeSize', { min = 10, max = 48, step = 1 }),
		Option(player, 'Horizontal', 'debuffHighlightBadgeOffsetX', { min = -BADGE_RANGE_X, max = BADGE_RANGE_X, step = 1 }),
		Option(player, 'Vertical', 'debuffHighlightBadgeOffsetY', { min = -BADGE_RANGE_Y, max = BADGE_RANGE_Y, step = 1 }),
		Toggle(player, 'Cleanse callouts, FD, TURT and SF prompts', 'debuffHighlightTypeText', { separator = true }),
		Toggle(settings, 'Recolor the Blizzard debuff icons to match', 'dispelRecolor'),
	} }
	typeIcons[#typeIcons + 1] = DispelPreviewEye()
	typeIcons[#typeIcons + 1] = OnUnlessOff(player, nil, 'debuffHighlightBadge')
	dispel:AddTools('Type icons', 'Debuff type icons above the frame, one color each', typeIcons, RefreshDispel)

	local indicators = ToolGrid(ui, parent, width, 'Indicators', 'Icons layered on every frame.', SETTING_COLUMNS)
	indicators:AddTools('Raid icon', 'Raid target marker on each frame', {
		{ tooltip = 'Position and size', title = 'Raid icon', options = {
			Option(settings, 'Position', 'raidIconPosition', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(settings, 'Size', 'raidIconSize', { min = 8, max = 50, step = 1 }),
			Option(settings, 'Horizontal', 'raidIconOffsetX', { min = -ICON_RANGE, max = ICON_RANGE, step = 1 }),
			Option(settings, 'Vertical', 'raidIconOffsetY', { min = -ICON_RANGE, max = ICON_RANGE, step = 1 }),
		} },
		{ get = function() return settings.raidIconMode ~= 'off' end, set = function(value) settings.raidIconMode = value and 'icon' or 'off' end, default = function() return FactoryFor(settings).raidIconMode ~= 'off' end },
	}, RefreshFrames)
	indicators:AddTools('Leader icon', 'Leader and assist crown on the frames', {
		{ tooltip = 'Position and size', title = 'Leader icon', options = {
			Option(settings, 'Position', 'leaderIconPosition', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(settings, 'Size', 'leaderIconSize', { min = 8, max = 32, step = 1 }),
			Option(settings, 'Horizontal', 'leaderIconOffsetX', { min = -ICON_RANGE, max = ICON_RANGE, step = 1 }),
			Option(settings, 'Vertical', 'leaderIconOffsetY', { min = -ICON_RANGE, max = ICON_RANGE, step = 1 }),
		} },
		OnUnlessOff(settings, nil, 'leaderIconEnabled'),
	}, RefreshFrames)
	return { health, dispel, indicators }
end

local function CustomTagsBoard(ui, parent, width, page)
	local settings = Settings()
	local unitSettings = settings[tagUnit]
	local custom = ui.Board(parent, width, {
		stacked = true,
		title = 'Custom tags',
		description = 'Extra text elements driven by tags, attached to one frame. The preview above shows them in place.',
	})
	custom:AddTools('Frame', 'Which frame these tags belong to', {
		loose = true,
		{ text = 'New tag', icon = 'plus', onClick = function()
			unitSettings.customTags[#unitSettings.customTags + 1] = { name = 'Tag ' .. (#unitSettings.customTags + 1), tag = '[name]', point = 'CENTER', x = 0, y = 0, fontSize = 12, color = { 1, 1, 1, 1 }, enabled = true, drawLayer = 'OVERLAY', drawSubLevel = 0 }
			RefreshFrames()
			page:RebuildCurrent()
		end },
		{ entries = TAG_UNITS, width = MENU_WIDTH, get = function() return tagUnit end, set = function(value)
			tagUnit = value
			RefreshPreview()
			RebuildPane(page)
		end },
	})
	for index, entry in ipairs(unitSettings.customTags) do
		custom:AddTools(entry.name or ('Tag ' .. index), entry.tag or '', {
			Color(entry, 'Text color', 'color'),
			{ icon = 'text', tooltip = 'Name, tag, font and layer', title = entry.name or ('Tag ' .. index), options = {
				{ label = 'Name', kind = 'input', placeholder = 'Name', get = function() return entry.name or '' end, set = function(text)
					entry.name = text ~= '' and text or nil
					page:RebuildCurrent()
				end },
				{ label = 'Tag', kind = 'input', placeholder = '[name]', get = function() return entry.tag or '' end, set = function(text)
					entry.tag = text
					page:RebuildCurrent()
				end },
				{ label = 'Font', entries = fonts, get = function() return entry.font or BUI.C.GLOBAL_OPTION end, set = function(value) entry.font = value ~= BUI.C.GLOBAL_OPTION and value or nil end },
				Option(entry, 'Size', 'fontSize', { min = 6, max = 48, step = 1 }),
				Option(entry, 'Layer', 'drawLayer', { entries = LAYERS }),
				Option(entry, 'Sublevel', 'drawSubLevel', { min = -7, max = 7, step = 1 }),
			} },
			{ icon = 'location', tooltip = 'Anchor and offset', title = entry.name or ('Tag ' .. index), options = {
				Option(entry, 'Anchor', 'point', { entries = BUI.C.ANCHOR_POINT_OPTIONS_SHORT }),
				Option(entry, 'Horizontal', 'x', { min = -TAG_RANGE, max = TAG_RANGE, step = 1 }),
				Option(entry, 'Vertical', 'y', { min = -TAG_RANGE, max = TAG_RANGE, step = 1 }),
			} },
			OnUnlessOff(entry, nil, 'enabled'),
			{ slot = 'erase', icon = 'erase', size = Layout.ERASE_SIZE, hover = 'danger', tooltip = 'Remove this tag', onClick = function()
				Modals.Confirm({
					parent = Window().frame,
					title = 'Remove ' .. (entry.name or ('Tag ' .. index)),
					message = 'Remove this tag from the frame? There is no undo.',
					confirmText = 'Remove', cancelText = 'Cancel',
					onConfirm = function()
						table.remove(unitSettings.customTags, index)
						RefreshFrames()
						page:RebuildCurrent()
					end,
				})
			end },
		}, RefreshFrames)
	end
	if #unitSettings.customTags == 0 then custom:AddRow('No custom tags yet', 'Use New tag to add one to this frame') end
	return custom
end

local DEFAULT_COLOR_KEY = { name = 'nameColor', health = 'healthTextColor', power = 'powerTextColor' }
local DEFAULT_TAG_COLUMNS = { { 'Tag', 'name', 80 }, { 'Shows', 'sub', 140 }, { 'Color', 'swatch', 136 }, { 'Format', 'input', 200 }, { 'Placement', 'icon', 80, 'CENTER' }, { '', 'reset', nil, 'CENTER' } }

local function Factory()
	return FactoryFor(Settings())
end

local function SameColor(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function DefaultRowChanged(settings, prefix)
	local factory = Factory()
	for _, suffix in ipairs(OVERRIDE_SUFFIXES) do
		if settings[prefix .. suffix] ~= factory[prefix .. suffix] then return true end
	end
	local format = settings[prefix .. 'Format']
	if format and format ~= '' and format ~= factory[prefix .. 'Format'] then return true end
	local colorKey = DEFAULT_COLOR_KEY[prefix]
	if colorKey then return not SameColor(settings[colorKey], factory[colorKey]) end
	for status, color in pairs(factory.statusColors) do
		if not SameColor(settings.statusColors[status], color) then return true end
	end
	return false
end

local function ResetDefaultRow(settings, prefix)
	local factory = Factory()
	for _, suffix in ipairs(OVERRIDE_SUFFIXES) do settings[prefix .. suffix] = factory[prefix .. suffix] end
	settings[prefix .. 'Format'] = factory[prefix .. 'Format']
	local colorKey = DEFAULT_COLOR_KEY[prefix]
	if colorKey then
		settings[colorKey] = CopyTable(factory[colorKey])
	else
		for status, color in pairs(factory.statusColors) do settings.statusColors[status] = CopyTable(color) end
	end
end

local function ReferenceBoard(ui, parent, width)
	local nameWidth, sampleWidth = math.floor(width * 0.36), math.floor(width * 0.30)
	local reference = ui.Grid(parent, width, {
		title = 'Tag reference',
		description = 'Every text tag with a sample. Search by name or tag, then click a tag and press Ctrl+C to copy it.',
		columns = {
			{ title = '#', width = LINE_WIDTH, align = 'RIGHT' },
			{ title = 'Name', width = nameWidth },
			{ title = 'Sample', width = sampleWidth },
			{ title = 'Tag' },
		},
	})
	local line = 0
	for _, group in ipairs(TAG_GROUPS) do
		reference:AddGroup(group)
		for _, tag in ipairs(TAGS) do
			if tag.group == group then
				line = line + 1
				reference:AddLine({ { text = tostring(line), role = 'faint' }, tag.description, { text = tag.example, role = 'muted' }, { copy = tag.tag } }, tag.description .. ' ' .. tag.example .. ' ' .. tag.tag)
			end
		end
	end
	return reference
end

local function DefaultTagsBoard(ui, parent, width, page)
	local settings = Settings()
	local grid = ToolGrid(ui, parent, width, 'Default tags', 'Format, color, size and position every frame falls back on. Type in a format box to change it. A frame overrides only what it changes on its own pane.', DEFAULT_TAG_COLUMNS)
	local function Changed()
		RefreshFrames()
		DropUnitPanes(page)
		Repaint()
	end
	local function RefreshStatus()
		Changed()
		BUI.UnitFrames.RefreshLifeVisuals()
		BUI.GroupFrames.RefreshAll()
	end
	local statusSwatches = {}
	for _, statusName in ipairs({ 'Dead', 'Ghost', 'Offline', 'AFK', 'DND' }) do
		statusSwatches[#statusSwatches + 1] = {
			kind = 'swatch', tooltip = statusName, opacity = true,
			get = function()
				local color = settings.statusColors[statusName]
				return color[1], color[2], color[3], color[4] or 1
			end,
			set = function(red, green, blue, alpha) settings.statusColors[statusName] = { red, green, blue, alpha } end,
		}
	end
	local function Row(label, shows, swatches, prefix, placeholder, sizeMax, after)
		local tools = {}
		for _, swatch in ipairs(swatches) do tools[#tools + 1] = swatch end
		local input = TagInput(settings, prefix .. 'Format', placeholder)
		input.square = true
		tools[#tools + 1] = input
		tools[#tools + 1] = { icon = 'text', tooltip = 'Text size', title = label, options = {
			Option(settings, 'Text size', prefix .. 'TextSize', { min = 8, max = sizeMax, step = 1 }),
		} }
		tools[#tools + 1] = { icon = 'location', tooltip = 'Position and offset', title = label, options = {
			Option(settings, 'Position', prefix .. 'Position', { entries = BUI.C.TEXT_PLACEMENT_OPTIONS }),
			Option(settings, 'Horizontal', prefix .. 'OffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			Option(settings, 'Vertical', prefix .. 'OffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		} }
		local reset = ResetTool(ui, 'Changed from the factory default, click to restore it', function() return DefaultRowChanged(settings, prefix) end, function()
			ResetDefaultRow(settings, prefix)
			after()
		end)
		reset.slot = 'reset'
		tools[#tools + 1] = reset
		grid:AddTools(label, shows, tools, after)
	end
	Row('Name', 'Unit name on the health bar', { Color(settings, 'Text color', 'nameColor') }, 'name', DEFAULT_TAGS.name, 20, Changed)
	Row('Health', 'Health value on the bar', { Color(settings, 'Text color', 'healthTextColor') }, 'health', DEFAULT_TAGS.health, 20, Changed)
	Row('Power', 'Resource value on the power bar', { Color(settings, 'Text color', 'powerTextColor') }, 'power', DEFAULT_TAGS.power, 20, Changed)
	Row('Status', 'Dead, Ghost, Offline, AFK and DND', statusSwatches, 'status', DEFAULT_TAGS.status, 24, RefreshStatus)
	return grid
end

local function TagsBoards(ui, parent, width, page)
	local strip = CreateFrame('Frame', nil, parent)
	strip:SetWidth(width)
	local top, select = ui.Tabs(strip, 0, { 'Reference sheet', 'Default tags', 'Custom tags' }, function(index)
		if index == tagsTab then return end
		tagsTab = index
		page:RebuildCurrent()
	end)
	strip:SetHeight(top + TAB_STRIP_GAP)
	select(tagsTab)
	if tagsTab == 1 then return { strip, ReferenceBoard(ui, parent, width) } end
	if tagsTab == 2 then return { strip, DefaultTagsBoard(ui, parent, width, page) } end
	return { strip, CustomTagsBoard(ui, parent, width, page) }
end

local function FiltersBoards(ui, parent, width, page)
	local filters = BUI.GetDB().auraFilters
	local shared = ui.Board(parent, width, {
		stacked = true,
		title = 'Filters',
		description = 'Pinned auras always show, blacklisted auras never do.',
	})
	AuraLists.ShareCell(shared, 'Share blacklists with the group frames')
	return {
		shared,
		AuraLists.Pinned(ui, parent, width, page, {
			title = 'Pinned buffs', description = 'Always shown on every unit frame, on top of whatever the buff rules match.',
			get = function() return filters.buffWhitelist end, onChange = RefreshFilters,
			only = { label = 'Only show pinned buffs', get = function() return filters.buffWhitelistOnly == true end, set = function(value) filters.buffWhitelistOnly = value end, tip = 'Ignore the buff rules entirely' },
		}),
		AuraLists.Blacklist(ui, parent, width, page, { scope = 'unit', polarity = 'HELPFUL', title = 'Buff blacklist', description = 'Buffs that never show on the unit frames.', onChange = RefreshFilters }),
		AuraLists.Pinned(ui, parent, width, page, {
			title = 'Pinned debuffs', description = 'Always shown on every unit frame, on top of whatever the debuff rules match.',
			get = function() return filters.debuffWhitelist end, onChange = RefreshFilters,
			only = { label = 'Only show pinned debuffs', get = function() return filters.debuffWhitelistOnly == true end, set = function(value) filters.debuffWhitelistOnly = value end, tip = 'Ignore the debuff rules entirely' },
		}),
		AuraLists.Blacklist(ui, parent, width, page, { scope = 'unit', polarity = 'HARMFUL', title = 'Debuff blacklist', description = 'Debuffs that never show on the unit frames.', onChange = RefreshFilters }),
	}
end

local function PositionTool(unitKey, unitSettings)
	if not ANCHORABLE[unitKey] then
		return { icon = 'location', tooltip = 'Position', title = 'Position', options = {
			{ label = 'Horizontal', min = -POSITION_RANGE_X, max = POSITION_RANGE_X, step = 1, get = function() return unitSettings.position.x end, set = function(value)
				unitSettings.position.x, unitSettings.position.point, unitSettings.position.relPoint = value, 'CENTER', 'CENTER'
			end },
			{ label = 'Vertical', min = -POSITION_RANGE_Y, max = POSITION_RANGE_Y, step = 1, get = function() return unitSettings.position.y end, set = function(value)
				unitSettings.position.y, unitSettings.position.point, unitSettings.position.relPoint = value, 'CENTER', 'CENTER'
			end },
		} }
	end
	local module = UnitFrames()
	local selfFrame = module[unitKey]
	local frames
	if unitKey == 'targettarget' then
		frames = { { tag = 'BUI_TargetFrame', desc = 'Target frame' }, { tag = 'BUI_PlayerFrame', desc = 'Player frame' }, { tag = 'BUI_FocusFrame', desc = 'Focus frame' } }
	else
		frames = BUI.AnchorFramesExcept('BUI_' .. unitKey:sub(1, 1):upper() .. unitKey:sub(2) .. 'Frame')
	end
	if selfFrame then
		local pruned = {}
		for _, frame in ipairs(frames) do
			if not BUI.Anchor.WouldCycle(selfFrame, BUI.ResolveAnchorFrame(frame.tag)) then pruned[#pruned + 1] = frame end
		end
		frames = pruned
	end
	local defaultOffsetX = unitKey == 'targettarget' and 5 or 0
	local proxy = setmetatable({}, {
		__index = function(_, key)
			if key == 'posX' then return unitSettings.position.x end
			if key == 'posY' then return unitSettings.position.y end
			if key == 'anchorOffsetX' then return unitSettings.anchorOffsetX or defaultOffsetX end
			return unitSettings[key]
		end,
		__newindex = function(_, key, value)
			if key == 'posX' then
				unitSettings.position.x, unitSettings.position.point, unitSettings.position.relPoint = value, 'CENTER', 'CENTER'
			elseif key == 'posY' then
				unitSettings.position.y, unitSettings.position.point, unitSettings.position.relPoint = value, 'CENTER', 'CENTER'
			elseif key == 'anchorFrame' then
				if value ~= '' and selfFrame and BUI.Anchor.WouldCycle(selfFrame, BUI.ResolveAnchorFrame(value)) then
					BUI.Print('That frame already anchors to the ' .. unitKey .. ' frame, it would loop.')
					return
				end
				unitSettings.anchorFrame = value
			else
				unitSettings[key] = value
			end
		end,
	})
	return BUI.PositionTool(proxy, { frames = frames, noCenter = true, matchWidth = true, matchHeight = true, rangeX = POSITION_RANGE_X, rangeY = POSITION_RANGE_Y })
end

local function AuraRow(board, unitKey, unitSettings, isDebuff)
	local prefix = isDebuff and 'debuff' or 'buff'
	local title = isDebuff and 'Debuffs' or 'Buffs'
	local function Key(name) return prefix .. name end
	local layout = {
		{ label = 'Anchor point', entries = BUI.C.ANCHOR_POINT_OPTIONS, get = function() return unitSettings[Key('AnchorPoint')] or (isDebuff and 'TOPLEFT' or 'BOTTOMLEFT') end, set = function(value)
			unitSettings[Key('AnchorPoint')] = value
			if value:find('RIGHT') then unitSettings[Key('GrowthX')] = 'LEFT' elseif value:find('LEFT') then unitSettings[Key('GrowthX')] = 'RIGHT' end
			if value:find('TOP') then unitSettings[Key('GrowthY')] = 'UP' elseif value:find('BOTTOM') then unitSettings[Key('GrowthY')] = 'DOWN' end
		end },
		{ label = 'Grow', entries = GROWTHS_X, get = function() return unitSettings[Key('GrowthX')] or 'RIGHT' end, set = function(value) unitSettings[Key('GrowthX')] = value end },
		{ label = 'Rows grow', entries = GROWTHS_Y, get = function() return unitSettings[Key('GrowthY')] or 'DOWN' end, set = function(value) unitSettings[Key('GrowthY')] = value end },
		{ label = 'Horizontal', min = -AURA_RANGE, max = AURA_RANGE, step = 1, get = function() return unitSettings[Key('OffsetX')] or 0 end, set = function(value) unitSettings[Key('OffsetX')] = value end },
		{ label = 'Vertical', min = -AURA_RANGE, max = AURA_RANGE, step = 1, get = function() return unitSettings[Key('OffsetY')] or (isDebuff and 4 or -4) end, set = function(value) unitSettings[Key('OffsetY')] = value end },
	}
	local sizing = {
		{ label = 'Icon size', min = 12, max = 80, step = 1, get = function() return unitSettings[Key('IconSize')] or unitSettings.auraIconSize end, set = function(value) unitSettings[Key('IconSize')] = value end },
		{ label = 'Spacing', min = 0, max = 10, step = 1, get = function() return unitSettings[Key('Spacing')] or unitSettings.auraSpacing end, set = function(value) unitSettings[Key('Spacing')] = value end },
		Option(unitSettings, 'Max icons', isDebuff and 'maxDebuffs' or 'maxBuffs', { min = 1, max = isDebuff and 16 or 32, step = 1 }),
		{ label = 'Per row', min = 1, max = 16, step = 1, get = function() return unitSettings[isDebuff and 'debuffsPerRow' or 'buffsPerRow'] or 8 end, set = function(value) unitSettings[isDebuff and 'debuffsPerRow' or 'buffsPerRow'] = value end },
	}
	local text = {}
	if isDebuff then
		text[#text + 1] = Toggle(unitSettings, 'Reverse swipe', 'auraReverseSwipe')
		text[#text + 1] = OnUnlessOff(unitSettings, 'Color by type', 'showDebuffType')
	end
	text[#text + 1] = { label = 'Sort by', entries = BUI.AuraEngine.SortMethodItems(), get = function() return unitSettings[Key('SortMethod')] or 'default' end, set = function(value) unitSettings[Key('SortMethod')] = value end }
	text[#text + 1] = { label = 'Stack count', get = function() return ResolveShow(unitSettings[Key('ShowStack')], unitSettings.auraShowStack) end, set = function(value) unitSettings[Key('ShowStack')] = value end }
	text[#text + 1] = { label = 'Stack size', min = 6, max = 32, step = 1, get = function() return unitSettings[Key('StackSize')] or unitSettings.auraStackSize end, set = function(value) unitSettings[Key('StackSize')] = value end }
	text[#text + 1] = { label = 'Stack position', entries = STACK_POINTS, get = function() return unitSettings[Key('StackPos')] or 'BOTTOMRIGHT' end, set = function(value) unitSettings[Key('StackPos')] = value end }
	text[#text + 1] = { label = 'Cooldown text', get = function() return ResolveShow(unitSettings[Key('ShowCd')], unitSettings.auraShowCd) end, set = function(value) unitSettings[Key('ShowCd')] = value end }
	text[#text + 1] = { label = 'Cooldown size', min = 6, max = 32, step = 1, get = function() return unitSettings[Key('CdSize')] or unitSettings.auraCdSize end, set = function(value) unitSettings[Key('CdSize')] = value end }
	board:AddTools(title, (isDebuff and 'Debuff' or 'Buff') .. ' icons attached to the frame', {
		AuraLists.Rules({
			getRules = function() return UnitFrames().GetAuraRules(unitSettings, isDebuff) end,
			polarity = isDebuff and 'HARMFUL' or 'HELPFUL', unitFramesOnly = true,
			onChanged = RefreshFrames,
		}),
		{ icon = 'location', tooltip = 'Anchor, growth and offset', title = title, options = layout },
		{ icon = 'resize', tooltip = 'Size, spacing and count', title = title, options = sizing },
		{ icon = 'text', tooltip = 'Stacks, cooldown text and sorting', title = title, options = text },
		Toggle(unitSettings, nil, isDebuff and 'showDebuffs' or 'showBuffs'),
	}, RefreshFrames)
end

local function BossBoards(ui, parent, width)
	local settings = Settings()
	local boss = settings.boss
	local stacking = ui.Board(parent, width, {
		stacked = true,
		title = 'Stacking',
		description = 'How the five boss frames stack.',
	})
	stacking:AddTools('Stacking', 'Direction and spacing', {
		Menu(boss, 'growthDirection', STACKINGS, 220),
		{ tooltip = 'Spacing between frames', title = 'Stacking', options = { Option(boss, 'Spacing', 'spacing', { min = 0, max = 100, step = 1 }) } },
	}, RefreshFrames)
	local boards = { stacking }
	local CastBar = BUI.CastBar
	local castbar = CastBar.GetSettings('boss')
	if castbar then
		local Refresh = RefreshFrames
		local board = ui.Board(parent, width, {
			stacked = true,
			title = 'Cast bar',
			description = 'The cast bar on each boss frame.',
		})
		board:AddTools('Cast bar', 'Texture, size and layer', {
			Menu(castbar, 'texture', textures, MENU_WIDTH),
			{ tooltip = 'Size and layer', title = 'Cast bar', options = {
				Option(castbar, 'Height', 'height', { min = 4, max = 50, step = 1 }),
				Option(castbar, 'Border size', 'borderSize', { min = 0, max = 5, step = 1 }),
				Option(castbar, 'Layer', 'frameStrata', { entries = BUI.C.STRATA_OPTIONS }),
			} },
			Toggle(castbar, nil, 'enabled'),
		}, Refresh)
		board:AddSwitch('Spell icon', function() return castbar.showIcon == true end, function(value)
			castbar.showIcon = value
			Refresh()
		end, 'The spell icon beside the bar')
		board:AddTools('Text', 'Timer, spell name and size', {
			{ icon = 'text', tooltip = 'What the bar shows', title = 'Text', options = {
				Toggle(castbar, 'Show timer', 'showTimer'),
				OnUnlessOff(castbar, 'Show total time', 'showTotalTime'),
				OnUnlessOff(castbar, 'Countdown', 'countdown'),
				Toggle(castbar, 'Show spell name', 'showSpellName'),
				{ label = 'Name length, 0 for no limit', min = 0, max = 30, step = 1, get = function() return castbar.spellNameMaxLength or 0 end, set = function(value) castbar.spellNameMaxLength = value > 0 and value or nil end },
				Option(castbar, 'Text size', 'textSize', { min = 8, max = 24, step = 1 }),
			} },
		}, Refresh)
		board:AddTools('Colors', 'Bar and border', {
			Color(castbar, 'Bar color', 'barColor'),
			Color(castbar, 'Border color', 'borderColor'),
		}, Refresh)
		local perBoss = {}
		for index = 1, 5 do
			local color = castbar.bossColors[index]
			if not color then
				color = { 0.8, 0.2, 0.2, 1 }
				castbar.bossColors[index] = color
			end
			if color[4] == nil then color[4] = 1 end
			perBoss[#perBoss + 1] = Color(castbar.bossColors, 'Boss ' .. index, index)
		end
		perBoss[#perBoss + 1] = Toggle(castbar, nil, 'useIndividualColors')
		board:AddTools('Per boss colors', 'A distinct bar color for each boss', perBoss, Refresh)
		if castbar.interruptColor then
			board:AddTools('Cast colors', 'Bar color by interrupt state', {
				Color(castbar, 'Interrupt soon', 'interruptWindowColor'),
				Color(castbar, 'Can interrupt', 'interruptReadyColor'),
				Color(castbar, 'Interrupt on cooldown', 'interruptOnCDColor'),
				Color(castbar, 'Not interruptible', 'interruptColor'),
				{ icon = 'eye', tooltip = 'Preview the ready line and the voice lines', get = function() return CastBar.IsPreviewingInterrupt('boss') end, set = function(value)
					if value then CastBar.PreviewInterrupt('boss') else CastBar.StopInterruptPreview('boss') end
					Repaint()
				end },
			}, Refresh)
			board:AddTools('Ready line', 'Line marking when your kick is back up', {
				Color(castbar, 'Line color', 'interruptTickColor'),
				{ tooltip = 'Line width and window', title = 'Ready line', options = {
					Option(castbar, 'Line width', 'interruptTickWidth', { min = 1, max = 6, step = 1 }),
					OnUnlessOff(castbar, 'Show interrupt window', 'interruptWindow'),
				} },
				OnUnlessOff(castbar, nil, 'interruptTick'),
			}, Refresh)
		end
		boards[#boards + 1] = board
	end
	return boards
end

local function UnitBoards(ui, parent, width, unit)
	local settings = Settings()
	local unitKey = unit.key
	local unitSettings = settings[unitKey]
	local description = unit.description
	if IsDriven(unitKey) then description = description .. ' This frame copies the player frame, turn off the sync on Appearance to edit it on its own.' end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = unit.title,
		description = description,
	})
	board:AddTools('Frame', 'Position, size, preview and on or off', {
		PositionTool(unitKey, unitSettings),
		{ icon = 'resize', tooltip = 'Width and height', title = unit.title, options = {
			Option(unitSettings, 'Width', 'width', { min = 50, max = 1500, step = 1 }),
			Option(unitSettings, 'Height', 'height', { min = 1, max = 500, step = 1 }),
		} },
		PreviewEye(unitKey),
		OnUnlessOff(unitSettings, nil, 'enabled'),
	}, RefreshFrames)
	board:AddSwitch('Hide the raid icon', function() return unitSettings.hideRaidIcon == true end, function(value)
		unitSettings.hideRaidIcon = value
		RefreshFrames()
	end, 'No raid marker on this frame')
	board:AddSwitch('Hide the level', function() return unitSettings.hideLevel == true end, function(value)
		unitSettings.hideLevel = value
		RefreshFrames()
	end, 'No level text on this frame')
	if unitKey == 'player' then
		board:AddTools('Power prediction', 'Preview the power cost of your cast', {
			Color(unitSettings, 'Prediction color', 'powerPredictionColor'),
			Toggle(unitSettings, nil, 'powerPrediction'),
		}, RefreshFrames)
		board:AddTools('Combat border', 'Recolor the border while in combat', {
			Color(unitSettings, 'Combat border color', 'combatBorderColor'),
			Toggle(unitSettings, nil, 'combatBorder'),
		}, RefreshFrames)
		board:AddTools('Aggro border', 'Recolor the border when you have aggro', {
			Color(unitSettings, 'Aggro border color', 'aggroBorderColor'),
			Toggle(unitSettings, nil, 'aggroBorder'),
		}, RefreshFrames)
	end
	if unitKey == 'pet' then
		board:AddTools('Pet colors', 'Health, power, backgrounds and border', {
			Color(settings, 'Health', 'petHealthColor'),
			Color(settings, 'Health background', 'petBgColor'),
			Color(settings, 'Power', 'petPowerColor'),
			Color(settings, 'Power background', 'petPowerBgColor'),
			Color(settings, 'Border', 'petBorderColor'),
		}, RefreshFrames)
	end

	local text = ui.Board(parent, width, {
		stacked = true,
		title = 'Text',
		description = 'Name, health, status and power texts. Anything left alone follows the Default tags on the Tags pane.',
	})
	text:AddTools('Name', 'Unit name on the health bar', {
		Color(unitSettings, 'Friendly', 'friendlyNameColor'),
		Color(unitSettings, 'Neutral', 'neutralNameColor'),
		Color(unitSettings, 'Hostile', 'hostileNameColor'),
		ResetTool(ui, 'This frame overrides the default size or position, click to follow the defaults again', function() return HasOverrides(unitSettings, 'name') end, function() ClearOverrides(unitSettings, 'name') end),
		{ icon = 'text', tooltip = 'Color, position and size', title = 'Name', options = {
			Toggle(unitSettings, 'Class or reaction color', 'classColorName'),
			Inherit(unitSettings, 'Position', 'namePosition', { entries = BUI.C.TEXT_PLACEMENT_OPTIONS }),
			Inherit(unitSettings, 'Text size', 'nameTextSize', { min = 8, max = 20, step = 1 }),
			Inherit(unitSettings, 'Horizontal', 'nameOffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			Inherit(unitSettings, 'Vertical', 'nameOffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		} },
		{ get = function() return ResolveShow(unitSettings.showName, settings.showName) end, set = function(value) unitSettings.showName = value end },
	}, RefreshFrames)
	text:AddTools('Name tag', 'Tag override for this frame', { TagInput(unitSettings, 'nameFormat', DefaultFormat('nameFormat', DEFAULT_TAGS.name)) }, RefreshFrames)
	if unitKey == 'player' or unitKey == 'pet' then
		text:AddTools('Custom name', 'Shown instead of the real name', {
			{ kind = 'input', width = NAME_WIDTH, placeholder = 'Real name', get = function() return unitSettings.customName or '' end, set = function(value) unitSettings.customName = value end },
		}, RefreshFrames)
	end
	text:AddTools('Health text', 'Health value on the bar', {
		ResetTool(ui, 'This frame overrides the default size or position, click to follow the defaults again', function() return HasOverrides(unitSettings, 'health') end, function() ClearOverrides(unitSettings, 'health') end),
		{ icon = 'text', tooltip = 'Position and size', title = 'Health text', options = {
			Inherit(unitSettings, 'Position', 'healthPosition', { entries = BUI.C.TEXT_PLACEMENT_OPTIONS }),
			Inherit(unitSettings, 'Text size', 'healthTextSize', { min = 8, max = 20, step = 1 }),
			Inherit(unitSettings, 'Horizontal', 'healthOffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			Inherit(unitSettings, 'Vertical', 'healthOffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		} },
		{ get = function() return ResolveShow(unitSettings.showHealthText, settings.showHealthText) end, set = function(value) unitSettings.showHealthText = value end },
	}, RefreshFrames)
	text:AddTools('Status text', 'Dead, Ghost or Offline over the bar', {
		ResetTool(ui, 'This frame overrides the default size or position, click to follow the defaults again', function() return HasOverrides(unitSettings, 'status') end, function() ClearOverrides(unitSettings, 'status') end),
		{ icon = 'text', tooltip = 'Position and size', title = 'Status text', options = {
			Inherit(unitSettings, 'Position', 'statusPosition', { entries = BUI.C.TEXT_PLACEMENT_OPTIONS }),
			Inherit(unitSettings, 'Text size', 'statusTextSize', { min = 8, max = 24, step = 1 }),
			Inherit(unitSettings, 'Horizontal', 'statusOffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			Inherit(unitSettings, 'Vertical', 'statusOffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		} },
		{ get = function() return unitSettings.showStatusText ~= false end, set = function(value) unitSettings.showStatusText = value end },
	}, RefreshFrames)
	text:AddTools('Status tag', 'Tag override for this frame', { TagInput(unitSettings, 'statusFormat', DefaultFormat('statusFormat', DEFAULT_TAGS.status)) }, RefreshFrames)
	text:AddTools('Health tag', 'Tag override for this frame', { TagInput(unitSettings, 'healthFormat', DefaultFormat('healthFormat', DEFAULT_TAGS.health)) }, RefreshFrames)
	text:AddTools('Power bar', 'Resource bar under the health bar', {
		{ icon = 'resize', tooltip = 'Height', title = 'Power bar', options = { Option(unitSettings, 'Bar height', 'powerHeight', { min = 1, max = 20, step = 1 }) } },
		Toggle(unitSettings, nil, 'showPower'),
	}, RefreshFrames)
	text:AddTools('Power text', 'Resource value on the power bar', {
		ResetTool(ui, 'This frame overrides the default size or position, click to follow the defaults again', function() return HasOverrides(unitSettings, 'power') end, function() ClearOverrides(unitSettings, 'power') end),
		{ icon = 'text', tooltip = 'Position and size', title = 'Power text', options = {
			Inherit(unitSettings, 'Position', 'powerPosition', { entries = BUI.C.TEXT_PLACEMENT_OPTIONS }),
			Inherit(unitSettings, 'Text size', 'powerTextSize', { min = 8, max = 20, step = 1 }),
			Inherit(unitSettings, 'Horizontal', 'powerOffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			Inherit(unitSettings, 'Vertical', 'powerOffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		} },
		{ get = function() return ResolveShow(unitSettings.showPowerText, settings.showPowerText, false) end, set = function(value) unitSettings.showPowerText = value end },
	}, RefreshFrames)
	text:AddTools('Power tag', 'Tag override for this frame', { TagInput(unitSettings, 'powerFormat', DefaultFormat('powerFormat', DEFAULT_TAGS.power)) }, RefreshFrames)

	local boards = { board, text }
	if UnitFrames().GetUnitConfig(unitKey).hasAuras then
		local auras = ui.Board(parent, width, {
			stacked = true,
			title = 'Auras',
			description = 'Debuff and buff icons attached to the frame. Priority rules decide which auras claim the slots.',
		})
		AuraRow(auras, unitKey, unitSettings, true)
		AuraRow(auras, unitKey, unitSettings, false)
		boards[#boards + 1] = auras
	end
	if unitKey == 'boss' then
		for _, extra in ipairs(BossBoards(ui, parent, width)) do boards[#boards + 1] = extra end
	end
	return boards
end

local function Panes(ui, shell, parent, width, item, page)
	if GROUP_PANE[item.id] then return BUI.GroupFramesPage.Build(ui, shell, parent, width, item, page) end
	if item.id == 'appearance' then return AppearanceBoards(ui, parent, width, page) end
	if item.id == 'tags' then return TagsBoards(ui, parent, width, page) end
	if item.id == 'filters' then return FiltersBoards(ui, parent, width, page) end
	return UnitBoards(ui, parent, width, UNIT_BY_KEY[item.id])
end

local function RailGroups()
	local frames = {}
	for _, unit in ipairs(UNITS) do frames[#frames + 1] = { id = unit.key, label = unit.label } end
	return {
		{ title = 'Settings', items = {
			{ id = 'appearance', label = 'Appearance', icon = 'cog' },
			{ id = 'tags', label = 'Tags', icon = 'text' },
			{ id = 'filters', label = 'Filters', icon = 'x' },
		} },
		{ title = 'Units', items = frames },
		{ title = 'Groups', items = BUI.GroupFramesPage.items },
	}
end

BUI.PageEngine.RegisterPage('unitframes', {
	title = 'Unit Frames',
	buttonText = 'Unit Frames',
	icon = 'profile',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		textures = BUI.BuildTextureDropdownItems(BUI.C.GLOBAL_OPTION)
		BUI.GroupFramesPage.Init()
		for _, item in ipairs(BUI.GroupFramesPage.items) do GROUP_PANE[item.id] = true end
		local settings = Settings()
		local module = UnitFrames()
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local tab = page:GetTab(1)
		local enabled = settings.enabled == true
		local rail
		rail = Layout.RailPage(tab, { window = Window() }, {
			icon = 'profile',
			title = 'Unit Frames',
			placeholder = 'Search frame settings...',
			disabled = function(item) return not enabled or (GROUP_PANE[item.id] and not BUI.GroupFramesPage.IsOn()) end,
			tools = {
				{ text = 'Test mode', onClick = function()
					module.TestMode.Toggle()
					if module.TestMode.IsActive() then
						Modals.Message({ parent = Window().frame, title = 'Test mode', message = 'Every frame is shown with sample data. Type /buitest to close it.', buttonText = 'Got it' })
					end
				end },
				{ icon = 'enable', label = 'Unit frames', tooltip = 'Turn the unit frames on or off, needs a reload', get = function() return settings.enabled == true end, set = function(value)
					settings.enabled = value
					Modals.Confirm({
						parent = Window().frame,
						title = value and 'Unit frames on' or 'Unit frames off',
						message = 'This needs a reload of the interface. Reload now?',
						confirmText = 'Reload', cancelText = 'Later',
						onConfirm = ReloadUI,
					})
				end },
				BUI.GroupFramesPage.EnableTool(),
			},
			preview = { height = PREVIEW_HEIGHT, build = function(band, kit) preview = BuildPreview(band, kit) end },
			rail = { groups = RailGroups(), selected = selected },
			build = Panes,
		})
		local Select = rail.Select
		function rail:Select(id)
			selected = id
			Select(self, id)
			Repaint()
			RefreshPreview()
		end
		local tabs = {}
		for index = 1, #TAB_IDS do tabs[index] = tab end
		pageFrame._page = { tabContents = tabs, currentTab = TAB_INDEX[selected], SetTab = function(_, index) rail:Select(TAB_IDS[index] or 'appearance') end }
		module.SetPreviewListener(Repaint)
		RefreshPreview()
		page:AutoRefresh()
	end,
	OnHide = function()
		BUI.UnitFrames.LockAllPreviews()
		BUI.GroupFrames.CloseAllPreviews()
		BUI.CastBar.StopInterruptPreview('boss')
		BUI.UnitFrames.StopDispelPreview()
	end,
})
