local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local SecondaryStats = BUI.Auras.SecondaryStats

local PAGE_WIDTH = 960
local MENU_WIDTH = 150

local STATS = {
	primary = { name = 'Primary stat', sub = 'Strength, Agility or Intellect, whichever your spec uses' },
	stamina = { name = 'Stamina', sub = 'Your total stamina' },
	crit = { name = 'Critical Strike', sub = 'Crit rating and chance' },
	haste = { name = 'Haste', sub = 'Haste rating and percent' },
	mastery = { name = 'Mastery', sub = 'Mastery rating and percent' },
	vers = { name = 'Versatility', sub = 'Versatility rating and damage bonus' },
	leech = { name = 'Leech', sub = 'Leech rating and percent' },
	avoidance = { name = 'Avoidance', sub = 'Avoidance rating and percent' },
	speed = { name = 'Speed', sub = 'Speed rating and percent' },
}

local ALIGNMENTS = {
	{ value = 'LEFT', text = 'Left' },
	{ value = 'CENTER', text = 'Center' },
	{ value = 'RIGHT', text = 'Right' },
}

local DISPLAYS = {
	{ value = 'both', text = 'Rating and percent' },
	{ value = 'percent', text = 'Percent' },
	{ value = 'rating', text = 'Rating' },
}

local fonts

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function Config()
	return BUI.GetDB().secondaryStats
end

local function Refresh()
	SecondaryStats.Refresh()
end

local function Option(label, key, extra)
	local option = { label = label, get = function() return Config()[key] end, set = function(value) Config()[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function StatColor(stat, label)
	return {
		kind = 'swatch', label = label, tooltip = label .. ' color',
		get = function() return stat.color[1], stat.color[2], stat.color[3], 1 end,
		set = function(red, green, blue) stat.color = { red, green, blue } end,
	}
end

local function StatSwitch(stat)
	return { get = function() return stat.shown == true end, set = function(value) stat.shown = value end }
end

local function StatsBoard(ui, parent, width, page)
	local db = Config()
	local order = SecondaryStats.Order()
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Stats',
		description = 'Top to bottom here is top to bottom on screen. Drag a row to reorder it, the swatch sets its color and the switch shows or hides it.',
	})
	board:DragList(function(index, delta, count)
		Layout.ShiftBlock(order, index, delta, count)
		page:Resize()
	end, function()
		db.order = order
		Refresh()
	end)
	for _, id in ipairs(order) do
		local stat, info = db.stats[id], STATS[id]
		board:AddDragTools(info.name, info.sub, nil, { StatColor(stat, info.name), StatSwitch(stat) }, Refresh)
	end
	return board
end

local function TextBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Text',
		description = 'How the readout looks, what each stat shows and where it sits.',
	})
	board:AddTools('Text', 'Font, size, alignment and position', {
		{ entries = fonts, width = MENU_WIDTH, get = function() return Config().font end, set = function(value) Config().font = value end },
		{ icon = 'text', tooltip = 'Text', title = 'Text', options = {
			Option('Font size', 'fontSize', { min = 8, max = 40, step = 1 }),
			Option('Align', 'align', { entries = ALIGNMENTS }),
		} },
		BUI.PositionTool(Config(), { selfTag = 'BUI_SecondaryStats' }),
	}, Refresh)
	board:AddTools('Readout', 'Rating, percent or both for each stat, and when it shows', {
		Option('Show', 'display', { entries = DISPLAYS, width = MENU_WIDTH }),
		{ tooltip = 'When it shows', title = 'Readout', options = {
			Option('Combat only', 'combatOnly'),
		} },
	}, Refresh)
	return board
end

local function Sections(ui, _, parent, width, page)
	fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
	return { StatsBoard(ui, parent, width, page), TextBoard(ui, parent, width) }
end

BUI.PageEngine.RegisterPage('secondaryStats', {
	title = 'Secondary Stats',
	buttonText = 'Secondary Stats',
	hidden = true,
	navParent = 'auras',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'glow',
			title = 'Secondary Stats',
			placeholder = 'Search stats...',
			disabled = function() return Config().enabled ~= true end,
			back = { label = 'Weaker Auras', onClick = function() BUI.PageEngine.NavigateToID('auras') end },
			tools = {
				{ icon = 'enable', tooltip = 'Turn the readout on or off', get = function() return Config().enabled == true end, set = function(value)
					Config().enabled = value
					Refresh()
				end },
				{ icon = 'eye', tooltip = 'Preview, drag to move, right-click it to lock', get = function() return not Config().locked end, set = function(value)
					SecondaryStats.SetLocked(not value)
				end },
			},
			tabs = { { label = 'Secondary Stats', build = Sections } },
		})
		SecondaryStats.SetLockListener(Repaint)
		page:AutoRefresh()
	end,
})
