local BUI = BluUI
local BUILib = BUI.BUILibClient
local Modals, Toast = BUILib.Modals, BUILib.Toast

local SECTIONS = {
	{ caption = 'Frames and bars', modules = {
		{ key = 'actionBars', name = 'Action Bars', sub = 'Skinned bars with keybinds and cooldown text' },
		{ key = 'unitFrames', name = 'Unit Frames', sub = 'Player, target, focus, pet and boss frames' },
		{ key = 'groupFrames', name = 'Group Frames', sub = 'Party and raid frames' },
		{ key = 'castBars', name = 'Cast Bars', sub = 'Player, target, focus and boss cast bars' },
		{ key = 'power', name = 'Power Bars', sub = 'Primary and secondary power bars' },
	} },
	{ caption = 'Cooldowns and auras', modules = {
		{ key = 'cdm', name = 'Cooldown Manager', sub = 'Cooldown viewers and custom bars' },
		{ key = 'auras', name = 'Auras', sub = 'Low health, marks, crosshair and gateway alerts' },
		{ key = 'buffTracking', name = 'Buff Tracking', sub = 'Trackers for buffs you want to keep up' },
		{ key = 'buffFrames', name = 'Buffs & Debuffs', sub = 'Your own buff and debuff icons' },
	} },
	{ caption = 'Interface', modules = {
		{ key = 'minimap', name = 'Minimap', sub = 'The square minimap and its buttons' },
		{ key = 'datatext', name = 'Datatext', sub = 'Datatext bars and the minimap stats' },
		{ key = 'cursor', name = 'Cursor', sub = 'Cursor ring and trail' },
		{ key = 'markers', name = 'Markers', sub = 'Raid and world markers' },
		{ key = 'streamerTools', name = 'Streamer Tools', sub = 'Overlays for streaming, like the GCD history' },
	} },
}
local MODULES = {}
for _, section in ipairs(SECTIONS) do
	for _, entry in ipairs(section.modules) do MODULES[#MODULES + 1] = entry end
end

local Window = BUI.OptionsKit.Window

local function ToastOptions()
	return { style = 'bar', parent = Window().frame }
end

local function Pending(key)
	if BUI.ModuleControls[key] then return false end
	return BUI.IsModuleEnabled(key) ~= (BUI.BootedModules()[key] ~= false)
end

local function Set(entry, enabled)
	if BUI.IsModuleEnabled(entry.key) == enabled then return false end
	BUI.SetModuleEnabled(entry.key, enabled)
	return Pending(entry.key)
end

local function Apply(entries, enabled)
	local needsReload = false
	for _, entry in ipairs(entries) do
		if Set(entry, enabled) then needsReload = true end
	end
	if needsReload then Toast.Warning('Reload needed', 'Some modules only change after a /reload', ToastOptions()) end
end

local function ApplyAll(enabled)
	Apply(MODULES, enabled)
	Window():Repaint()
end

local function ConfirmReload(key, enabled, revert)
	Modals.Confirm({
		parent = Window().frame,
		title = 'Reload required',
		message = enabled and 'Turning this module on needs a UI reload.' or 'Turning this module off needs a UI reload to put everything back.',
		confirmText = 'Reload now', cancelText = 'Cancel', laterText = 'Later',
		onConfirm = function()
			BUI.SetModuleEnabled(key, enabled)
			ReloadUI()
		end,
		onLater = function()
			BUI.SetModuleEnabled(key, enabled)
			Window():Repaint()
		end,
		onCancel = revert,
	})
end

local function AllModules(enabled)
	for _, entry in ipairs(MODULES) do
		if BUI.IsModuleEnabled(entry.key) ~= enabled then return false end
	end
	return true
end

local function Sections(ui, _, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Modules',
		description = 'Turn parts of BluUI on or off. Some only change after a /reload.',
		buttons = {
			{ text = 'All off', icon = 'check', active = function() return AllModules(false) end, onClick = function() ApplyAll(false) end },
			{ text = 'All on', icon = 'check', active = function() return AllModules(true) end, onClick = function() ApplyAll(true) end },
		},
	})
	for _, section in ipairs(SECTIONS) do
		board:AddCaption(section.caption)
		for _, entry in ipairs(section.modules) do
			local _, cell = board:AddSwitch(entry.name, function() return BUI.IsModuleEnabled(entry.key) end, function(enabled) Apply({ entry }, enabled) end, entry.sub)
			ui.Bind(cell, function() cell.label:SetText(Pending(entry.key) and (entry.name .. ', after reload') or entry.name) end)
		end
	end
	return { board }
end

BUI.ModulesPage = { Sections = Sections, ConfirmReload = ConfirmReload }
