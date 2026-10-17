local BUI = BluUI
local BUILib = BluUI.BUILibClient

local MENU_WIDTH = 140
local INPUT_WIDTH = 260
local ICON_SIZE = 24
local NAME_WIDTH = 300
local ERASE_INSET = 18
local ERASE_SIZE = BUILib.Layout.ERASE_SIZE

local GROWTH = {
	{ value = 'LEFT', text = 'Grow left' },
	{ value = 'RIGHT', text = 'Grow right' },
}

local Kit = BUI.OptionsKit
local Window, Repaint, RebuildPage, Option = Kit.Window, Kit.Repaint, Kit.RebuildPage, Kit.Option

local function Config()
	return BUI.GetDB().gcdHistory
end

local function Refresh()
	BUI.GCDHistory.UpdateAppearance()
end

local function HistoryBoard(ui, parent, width)
	local GCDHistory = BUI.GCDHistory
	local db = Config()
	BUI.OnModuleChange('gcdHistory', Repaint)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'GCD History',
		description = 'A rolling strip of the spells you cast, newest first.',
	})
	board:AddTools('Strip', 'Turn it on, or unlock it to drag it around, right-click it to lock it again', {
		{ icon = 'eye', tooltip = 'Unlock to drag the strip', get = function() return not db.locked end, set = function(value) GCDHistory.SetLocked(not value) end },
		{ get = function() return db.enabled == true end, set = function(value)
			db.enabled = value
			GCDHistory.Toggle(value)
		end },
	})
	board:AddTools('Icons', 'Size, count, spacing and border of the strip', {
		Kit.Color(db, nil, 'borderColor', { tooltip = 'Border color' }),
		Option(db, nil, 'growDirection', { entries = GROWTH, width = MENU_WIDTH }),
		{ tooltip = 'Size, count, spacing and border', title = 'Icons', options = {
			Option(db, 'Icon size', 'iconSize', { min = 20, max = 80, step = 1 }),
			Option(db, 'Max icons', 'maxIcons', { min = 1, max = 20, step = 1 }),
			Option(db, 'Spacing', 'spacing', { min = -10, max = 20, step = 1 }),
			Option(db, 'Icon zoom', 'zoom', { min = 0, max = 0.2, step = 0.01 }),
			Option(db, 'Border size', 'borderSize', { min = 0, max = 4, step = 1 }),
		} },
		BUI.PositionTool(db, { noCenter = true }),
	}, Refresh)
	board:AddTools('Active cast', 'Enlarged icon for the spell you are casting or channeling', {
		{ tooltip = 'Scale', title = 'Active cast', options = { Option(db, 'Scale', 'activeCastScale', { min = 1, max = 2, step = 0.1 }) } },
		Option(db, nil, 'showActiveCast'),
	}, Refresh)
	board:AddTools('Auto-expire', 'Fade icons out after they have been on screen for a while', {
		{ tooltip = 'Lifetime', title = 'Auto-expire', options = { Option(db, 'Lifetime in seconds', 'fadeTime', { min = 1, max = 15, step = 0.5 }) } },
		Option(db, nil, 'fadeOldIcons'),
	}, Refresh)
	board:AddSwitch('Hide auto attacks', function() return db.hideAutoAttacks == true end, function(value)
		db.hideAutoAttacks = value
	end, 'Skip melee and ranged auto attacks')
	board:AddSwitch('Debug to chat', function() return GCDHistory.debug == true end, GCDHistory.SetDebug, 'Print every recorded cast to the chat frame')
	return board
end

local function Add(spellID)
	Config().blacklist[spellID] = true
	RebuildPage()
end

local function BlacklistSection(ui, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Blacklist',
		description = 'Spells that never show on the strip. Type a name or paste an ID or link, then press Enter.',
		columns = { { 'Spell', ui.AVATAR_X } },
	})
	local row = section:AddRow('add a spell')
	ui.RowTitle(row, 'Add a spell', 'Name, ID or spell link', ui.AVATAR_X, NAME_WIDTH)
	local box
	box = ui.Input(row, INPUT_WIDTH, { placeholder = 'Search...', get = function() return '' end, set = function(text) BUI.AuraLists.Search(box, text, Add) end })
	box:SetPoint('RIGHT', -ui.ROW_INSET, 0)

	local spells = {}
	for spellID in pairs(Config().blacklist) do
		local icon, name = BUI.Lookup.GetSpellInfo(spellID)
		spells[#spells + 1] = { id = spellID, icon = icon, name = name or ('Spell ' .. spellID) }
	end
	table.sort(spells, function(left, right) return left.name < right.name end)
	for _, spell in ipairs(spells) do
		local spellRow = section:AddRow(spell.name)
		local icon = spellRow:CreateTexture(nil, 'ARTWORK')
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		icon:SetPoint('LEFT', ui.AVATAR_X, 0)
		icon:SetTexture(spell.icon)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ui.RowTitle(spellRow, spell.name, 'Spell ' .. spell.id, ui.NAME_X, NAME_WIDTH)
		ui.IconButton(spellRow, 'erase', 'Remove ' .. spell.name, function()
			Config().blacklist[spell.id] = nil
			RebuildPage()
		end, 'danger', ERASE_SIZE):SetPoint('RIGHT', -ERASE_INSET, 0)
	end
	if #spells == 0 then
		local empty = section:AddRow('nothing blacklisted')
		ui.RowTitle(empty, 'Nothing blacklisted', 'Every cast shows on the strip', ui.AVATAR_X, NAME_WIDTH)
	end
	return section
end

local function Sections(ui, _, parent, width)
	return { HistoryBoard(ui, parent, width), BlacklistSection(ui, parent, width) }
end

BUI.StreamerToolsPage = { GCDHistory = Sections }
