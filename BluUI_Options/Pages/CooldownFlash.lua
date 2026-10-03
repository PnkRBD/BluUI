local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local Controls = BUILib.Controls
local CooldownFlash = BUI.CooldownFlash

local PAGE_WIDTH = 960
local MENU_WIDTH = 150
local INPUT_WIDTH = 220
local RESULTS_WIDTH = 260
local ERASE_INSET = 18
local TOOL_SIZE = 22
local TOOL_GAP = 12
local TOOLS_ROOM = Layout.ERASE_SIZE + TOOL_GAP + TOOL_SIZE + TOOL_GAP

local GLOWS = {
	{ value = 'proc', text = 'Proc glow' },
	{ value = 'pixel', text = 'Pixel glow' },
	{ value = 'none', text = 'No glow' },
}

local sounds

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function Config()
	return BUI.GetDB().cooldownFlash
end

local function RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function Option(db, label, key, extra)
	local option = { label = label, get = function() return db[key] end, set = function(value) db[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function FlashBoard(ui, parent, width)
	local db = Config()
	local board = ui.Board(parent, width, { stacked = true, title = 'Flash', description = 'How the icons look, how long they stay and where they sit.' })
	board:AddTools('Icons', 'Sound, glow, size, timing and position', {
		{ entries = sounds, width = MENU_WIDTH, get = function() return db.sound end, set = function(value)
			db.sound = value
			BUI.PlaySoundByName(value)
		end },
		{ entries = GLOWS, width = MENU_WIDTH, get = function() return db.glow end, set = function(value) db.glow = value end },
		{ tooltip = 'Size and timing', title = 'Icons', options = {
			Option(db, 'Icon size', 'iconSize', { min = 24, max = 96, step = 1 }),
			Option(db, 'Spacing', 'spacing', { min = 0, max = 24, step = 1 }),
			Option(db, 'Stay for seconds', 'holdSeconds', { min = 0.5, max = 10, step = 0.5, separator = true }),
		} },
		BUI.PositionTool(db, { selfTag = 'BUI_CooldownFlash' }),
	}, CooldownFlash.Refresh)
	return board
end

local function SpellsBoard(ui, parent, width, page)
	local entries = {}
	for index, spellID in ipairs(CooldownFlash.GetSpells()) do entries[index] = spellID end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Spells',
		description = ('Saved for %s. They flash in this order, drag a row to reorder it. Type a name, paste an ID or a link, then press Enter.'):format(CooldownFlash.ListLabel()),
	})
	local function Add(spellID)
		if CooldownFlash.AddSpell(spellID) then RebuildPage() end
	end
	local function Search(anchor, text)
		local hits = {}
		for _, hit in ipairs(BUI.Lookup.SearchSpellsAndItems(text)) do
			if not hit.isItem then hits[#hits + 1] = hit end
		end
		if #hits == 1 then return Add(hits[1].id) end
		local menu = {}
		for _, hit in ipairs(hits) do
			menu[#menu + 1] = { text = hit.name, icon = hit.icon, callback = function() Add(hit.id) end }
		end
		if #menu == 0 then menu[1] = { text = 'Nothing found', disabled = true } end
		Controls.ContextMenu(menu, { anchor = anchor, width = RESULTS_WIDTH, window = Window() })
	end
	local addRow = board:AddRow('Add a spell', 'Name, ID or link', INPUT_WIDTH)
	local box
	box = ui.Input(addRow, INPUT_WIDTH, { placeholder = 'Search...', get = function() return '' end, set = function(text) Search(box, text) end })
	box:SetPoint('RIGHT', -ui.ROW_INSET, 0)

	board:DragList(function(index, delta)
		entries[index], entries[index + delta] = entries[index + delta], entries[index]
		page:Resize()
	end, function()
		CooldownFlash.ReorderSpells(entries)
	end)
	for _, spellID in ipairs(entries) do
		local name = C_Spell.GetSpellName(spellID) or ('Spell ' .. spellID)
		local row = board:AddDragRow(name, TOOLS_ROOM, 'Spell ' .. spellID, C_Spell.GetSpellTexture(spellID))
		local x = ERASE_INSET
		local function Put(control, size)
			control:SetPoint('RIGHT', -x, 0)
			x = x + size + TOOL_GAP
		end
		Put(ui.IconButton(row, 'erase', 'Remove ' .. name, function()
			CooldownFlash.RemoveSpell(spellID)
			RebuildPage()
		end, 'danger', Layout.ERASE_SIZE), Layout.ERASE_SIZE)
		Put(ui.IconButton(row, 'eye', 'Flash it now', function() CooldownFlash.FlashNow(spellID) end), TOOL_SIZE)
	end
	if #entries == 0 then board:AddRow('Nothing yet', 'Search above to add a spell') end
	return board
end

local function Sections(ui, _, parent, width, page)
	return { FlashBoard(ui, parent, width), SpellsBoard(ui, parent, width, page) }
end

BUI.PageEngine.RegisterPage('cooldownFlash', {
	title = 'Cooldown Flash',
	buttonText = 'Cooldown Flash',
	hidden = true,
	navParent = 'auras',
	OnBuild = function(pageFrame)
		sounds = BUI.BuildSoundDropdownItems()
		local db = Config()
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'glow',
			title = 'Cooldown Flash',
			placeholder = 'Search cooldown flash...',
			tools = {
				{ text = 'Back to alerts', onClick = function() BUI.PageEngine.NavigateToID('auras') end },
				{ icon = 'enable', hint = false, tooltip = 'Turn cooldown flashes on or off', get = function() return db.enabled == true end, set = function(value)
					db.enabled = value
					CooldownFlash.Refresh()
				end },
				{ icon = 'eye', tooltip = 'Unlock to drag the icons, right-click them to lock', get = function() return db.showAnchor == true end, set = function(value)
					db.showAnchor = value
					CooldownFlash.Refresh()
				end },
			},
			tabs = { { label = 'Cooldown Flash', build = Sections } },
		})
		CooldownFlash.RegisterAnchorCallback(Repaint)
		page:AutoRefresh()
	end,
})
