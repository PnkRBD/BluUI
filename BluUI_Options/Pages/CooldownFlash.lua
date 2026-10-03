local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout
local CooldownFlash = BUI.CooldownFlash

local PAGE_WIDTH = 960
local MENU_WIDTH = 150
local INPUT_WIDTH = 220

local GLOWS = {
	{ value = 'both', text = 'Ring and sweep' },
	{ value = 'ring', text = 'Ring' },
	{ value = 'sweep', text = 'Sweep' },
	{ value = 'none', text = 'None' },
}

local fonts, sounds

local function Window()
	return BUI.PageEngine.window
end

local function RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function SpellName(spellID)
	return C_Spell.GetSpellName(spellID) or ('Spell ' .. spellID)
end

local function Option(db, label, key, extra)
	local option = { label = label, get = function() return db[key] end, set = function(value) db[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function SpellTools(entry, name)
	return {
		{ kind = 'swatch', tooltip = 'Sweep and glow color', get = function()
			local color = entry.color
			return color[1], color[2], color[3], 1
		end, set = function(red, green, blue)
			entry.color = { red, green, blue }
		end },
		{ kind = 'swatch', tooltip = 'Text color', opacity = true, get = function()
			local color = entry.textColor
			return color.r, color.g, color.b, color.a
		end, set = function(red, green, blue, alpha)
			entry.textColor = { r = red, g = green, b = blue, a = alpha }
		end },
		{ entries = fonts, width = MENU_WIDTH, get = function() return entry.font end, set = function(value) entry.font = value end },
		{ icon = 'text', tooltip = 'Text', title = name, options = {
			Option(entry, 'Text', 'text', { kind = 'input', placeholder = name }),
			Option(entry, 'Text size', 'textSize', { min = 10, max = 48, step = 1 }),
			Option(entry, 'Show text', 'showText', { separator = true }),
		} },
		{ icon = 'sound', tooltip = 'Sound and speech', title = name, options = {
			{ label = 'Sound', entries = sounds, get = function() return entry.sound end, set = function(value)
				entry.sound = value
				BUI.PlaySoundByName(value)
			end },
			Option(entry, 'Spoken text', 'ttsText', { kind = 'input', placeholder = name, separator = true }),
			Option(entry, 'Say it', 'tts'),
		} },
		{ tooltip = 'Icon size, opacity, glow and timing', title = name, options = {
			Option(entry, 'Size', 'size', { min = 24, max = 96, step = 1 }),
			Option(entry, 'Opacity', 'opacity', { min = 10, max = 100, step = 5 }),
			Option(entry, 'Stay for seconds', 'holdSeconds', { min = 0.5, max = 10, step = 0.5 }),
			Option(entry, 'Glow', 'glow', { entries = GLOWS, separator = true }),
			Option(entry, 'Show icon', 'showIcon'),
		} },
		{ icon = 'eye', slot = 'toggle', tooltip = 'Flash it now', onClick = function() CooldownFlash.FlashNow(entry.id) end },
		{ get = function() return entry.enabled == true end, set = function(value) entry.enabled = value end },
		{ slot = 'erase', icon = 'erase', size = Layout.ERASE_SIZE, hover = 'danger', tooltip = 'Remove ' .. name, onClick = function()
			CooldownFlash.RemoveSpell(entry.id)
			RebuildPage()
		end },
	}
end

local function SpellsBoard(ui, parent, width, page)
	local entries = {}
	for index, entry in ipairs(CooldownFlash.GetSpells()) do entries[index] = entry end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Spells',
		description = ('Saved for %s. Cooldowns flash when they are ready, buffs from the CDM buff viewer flash when they fall off. They flash in this order, drag a row to reorder it.'):format(CooldownFlash.ListLabel()),
	})
	local addRow = board:AddRow('Add a spell or buff', 'Name, ID or link', INPUT_WIDTH)
	BUI.SpellSearch(ui, addRow, INPUT_WIDTH, { spellsOnly = true, onPick = function(hit)
		if CooldownFlash.AddSpell(hit.id) then RebuildPage() end
	end }):SetPoint('RIGHT', -ui.ROW_INSET, 0)

	board:DragList(function(index, delta)
		entries[index], entries[index + delta] = entries[index + delta], entries[index]
		page:Resize()
	end, function()
		CooldownFlash.ReorderSpells(entries)
	end)
	for _, entry in ipairs(entries) do
		local name = SpellName(entry.id)
		board:AddDragTools(name, 'Spell ' .. entry.id, C_Spell.GetSpellTexture(entry.id), SpellTools(entry, name), CooldownFlash.Refresh)
	end
	if #entries == 0 then board:AddRow('Nothing yet', 'Search above to add a spell') end
	return board
end

local function Sections(ui, _, parent, width, page)
	return { SpellsBoard(ui, parent, width, page) }
end

BUI.PageEngine.RegisterPage('cooldownFlash', {
	title = 'Cooldown Flash',
	buttonText = 'Cooldown Flash',
	hidden = true,
	navParent = 'auras',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		sounds = BUI.BuildSoundDropdownItems()
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'glow',
			title = 'Cooldown Flash',
			placeholder = 'Search cooldown flash...',
			back = { label = 'alerts', onClick = function() BUI.PageEngine.NavigateToID('auras') end },
			tabs = { { label = 'Cooldown Flash', build = Sections } },
		})
		page:AutoRefresh()
	end,
})
