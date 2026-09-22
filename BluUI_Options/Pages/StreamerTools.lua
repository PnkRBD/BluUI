local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls, Layout = BUILib.Controls, BUILib.Layout
local PageKit = BUILib.PageKit

local function GetConfig() return BUI.GetDB().gcdHistory end
local function Refresh() BUI.GCDHistory.UpdateAppearance() end
local function bind(key) return function(value) GetConfig()[key] = value; Refresh() end end

local function BuildGCDHistoryTab(tab)
	local GCDHistory = BUI.GCDHistory
	local config = GetConfig()

	local grids = {}
	local grid
	local function SyncDim(enabled)
		for gridIndex = 1, #grids do grids[gridIndex]:SyncDim(enabled) end
	end

	local _, anchorToggle = Layout.ModuleHeader(tab, {
		icon     = 134376,
		title    = 'GCD History',
		subtitle = 'Rolling strip of the spells you cast, newest first.',
		iconToggles = true,
		enabled  = config.enabled,
		onToggle = function(enabled)
			config.enabled = enabled
			GCDHistory.Toggle(enabled)
			SyncDim(enabled)
		end,
		anchor = {
			value = not config.locked,
			tooltip = 'Preview (drag to move)',
			onToggle = function(previewing) GCDHistory.SetLocked(not previewing) end,
		},
	})
	GCDHistory._lockToggle = anchorToggle

	local function Section(title)
		if grid then grid:Flush() end
		Layout.Section(tab, title)
		grid = PageKit.RowGrid(tab)
		grids[#grids + 1] = grid
	end
	local function AddRow(rowConfig) return grid:Add(rowConfig) end

	Section('Display')

	AddRow({
		spanFull = true,
		title = 'Icons',
		description = 'Size, count, spacing and border of the history strip',
		plain = true,
		accessoryWidth = 200,
		accessories = function(row)
			local mover = BUI.AlertMover(row, config, Refresh, {
				noCenter = true,
				unlock = {
					get = function() return not GetConfig().locked end,
					set = function(unlocked) GCDHistory.SetLocked(not unlocked) end,
				},
			})
			local cog = PageKit.SettingsIcon(row, {
				title = 'ICONS', tooltip = 'Size, count, spacing & border',
				options = {
					{ kind = 'slider', label = 'Icon Size', min = 20, max = 80,
					  get = function() return GetConfig().iconSize end,
					  set = bind('iconSize') },
					{ kind = 'slider', label = 'Max Icons', min = 1, max = 20,
					  get = function() return GetConfig().maxIcons end,
					  set = bind('maxIcons') },
					{ kind = 'slider', label = 'Spacing', min = -10, max = 20,
					  get = function() return GetConfig().spacing end,
					  set = bind('spacing') },
					{ kind = 'slider', label = 'Icon Zoom', min = 0, max = 0.2, step = 0.01,
					  get = function() return GetConfig().zoom end,
					  set = bind('zoom') },
					{ kind = 'slider', label = 'Border Size', min = 0, max = 4,
					  get = function() return GetConfig().borderSize end,
					  set = bind('borderSize') },
				},
			})
			local growDirection = Controls.Dropdown(row, nil, {
				{ value = 'LEFT', text = 'Grow Left' },
				{ value = 'RIGHT', text = 'Grow Right' },
			}, config.growDirection, bind('growDirection'), nil, 110)
			local borderColor = config.borderColor
			local swatch = Controls.ColorSwatch(row, { r = borderColor[1], g = borderColor[2], b = borderColor[3], a = borderColor[4], callback = function(red, green, blue, alpha)
				GetConfig().borderColor = { red, green, blue, alpha }; Refresh()
			end, tooltip = 'Border Color' })
			return { mover, cog, growDirection, swatch }
		end,
	})

	Section('Behavior')

	AddRow({
		title = 'Active Cast',
		description = 'Enlarged icon for the spell you are casting or channeling',
		checked = config.showActiveCast,
		callback = bind('showActiveCast'),
		accessoryWidth = 32,
		accessories = function(row)
			local cog = Controls.Icon(row, {
				title = 'ACTIVE CAST', tooltip = 'Scale',
				options = {
					{ kind = 'slider', label = 'Scale', min = 1, max = 2, step = 0.1,
					  get = function() return GetConfig().activeCastScale end,
					  set = bind('activeCastScale') },
				},
			})
			return { cog }
		end,
	})

	AddRow({
		title = 'Auto-Expire',
		description = 'Fade icons out after they have been on screen for a while',
		checked = config.fadeOldIcons,
		callback = bind('fadeOldIcons'),
		accessoryWidth = 32,
		accessories = function(row)
			local cog = Controls.Icon(row, {
				title = 'AUTO-EXPIRE', tooltip = 'Icon lifetime',
				options = {
					{ kind = 'slider', label = 'Lifetime (sec)', min = 1, max = 15, step = 0.5,
					  get = function() return GetConfig().fadeTime end,
					  set = function(value) GetConfig().fadeTime = value end },
				},
			})
			return { cog }
		end,
	})

	AddRow({
		title = 'Hide Auto Attacks',
		description = 'Skip melee and ranged auto attacks',
		checked = config.hideAutoAttacks,
		callback = function(value) GetConfig().hideAutoAttacks = value end,
	})

	AddRow({
		title = 'Debug to Chat',
		description = 'Print every recorded cast to the chat frame',
		checked = GCDHistory.debug == true,
		callback = function(value) GCDHistory.SetDebug(value) end,
	})

	grid:Flush()

	Section('Blacklist')

	local initialItems = {}
	for spellID in pairs(config.blacklist) do
		local icon, name = BUI.Lookup.GetSpellInfo(spellID)
		initialItems[#initialItems + 1] = { icon = icon or 134400, name = name or ('Spell ' .. spellID), id = spellID }
	end
	local list
	list = Layout.ItemList(tab, {
		hint = 'Search spell name or paste ID...',
		height = 200,
		items = initialItems,
		searchFunc = BUI.Lookup.SearchSpells,
		onAdd = function(text)
			local spellID = BUI.Lookup.ParseSpellInput(text)
			if not spellID then return end
			local blacklist = GetConfig().blacklist
			if blacklist[spellID] then return end
			blacklist[spellID] = true
			local icon, name = BUI.Lookup.GetSpellInfo(spellID)
			list:AddItem(icon or 134400, name or ('Spell ' .. spellID), spellID)
		end,
		onSearchSelect = function(item)
			local blacklist = GetConfig().blacklist
			if blacklist[item.id] then return end
			blacklist[item.id] = true
			list:AddItem(item.icon or 134400, item.name or ('Spell ' .. item.id), item.id)
		end,
		onRemove = function(row)
			GetConfig().blacklist[row.id] = nil
		end,
	})

	SyncDim(config.enabled)
end

BUI.StreamerToolsPage = {
	BuildGCDHistoryTab = BuildGCDHistoryTab,
}
