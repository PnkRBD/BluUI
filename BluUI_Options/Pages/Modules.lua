local BUI = BluUI
local BUILib = BUI.BUILibClient
local Modals, Toast = BUILib.Modals, BUILib.Toast

local STATUS_COLUMN = 344
local NAME_WIDTH = 260
local DROPDOWN_WIDTH = 112
local AVATAR_SIZE = 28

local MODULES = {
	{ key = 'actionBars', name = 'Action Bars', sub = 'Skinned bars with keybinds and cooldown text', icon = 'order' },
	{ key = 'unitFrames', name = 'Unit Frames', sub = 'Player, target, focus, pet and boss frames', icon = 'modules5' },
	{ key = 'groupFrames', name = 'Group Frames', sub = 'Party and raid frames', icon = 'copy' },
	{ key = 'cdm', name = 'Cooldown Manager', sub = 'Layouts and icons for the cooldown manager', icon = 'reload' },
	{ key = 'castBars', name = 'Cast Bars', sub = 'Player, target, focus and boss cast bars', icon = 'play' },
	{ key = 'power', name = 'Power Bars', sub = 'Primary and secondary power bars', icon = 'power' },
	{ key = 'minimap', name = 'Minimap', sub = 'The square minimap and its buttons', icon = 'disc' },
	{ key = 'auras', name = 'Auras', sub = 'Low health, marks, crosshair and gateway alerts', icon = 'glow' },
	{ key = 'buffTracking', name = 'Buff Tracking', sub = 'Trackers for buffs you want to keep up', icon = 'pill' },
	{ key = 'datatext', name = 'Datatext', sub = 'Datatext bars and the minimap stats', icon = 'text' },
	{ key = 'customBars', name = 'Custom Bars', sub = 'Your own bars for spells and items', icon = 'capsule' },
	{ key = 'cursor', name = 'Cursor', sub = 'Cursor ring and trail', icon = 'mover' },
	{ key = 'markers', name = 'Markers', sub = 'Raid and world markers', icon = 'markers' },
	{ key = 'streamerTools', name = 'Streamer Tools', sub = 'Overlays for streaming, like the GCD history', icon = 'eye' },
	{ key = 'gemCounter', name = 'Gem Manager', sub = 'Keeps count of your gems', icon = 'check' },
}

local booted = CopyTable(BUI.GetDB().modules)
local pending = {}

local function Window()
	return BUI.PageEngine.window
end

local function Modules()
	return BUI.GetDB().modules
end

local function ToastOptions()
	return { style = 'bar', position = 'bottom', parent = Window().frame }
end

local function Set(entry, enabled)
	if Modules()[entry.key] == enabled then return false end
	local applied = BUI.SetModuleEnabled(entry.key, enabled)
	local waits = not applied and enabled ~= booted[entry.key]
	pending[entry.key] = waits or nil
	return waits
end

local function Apply(entries, enabled)
	local needsReload = false
	for _, entry in ipairs(entries) do
		if Set(entry, enabled) then needsReload = true end
	end
	Window():Repaint()
	if needsReload then Toast.Warning('Reload needed', 'Some modules only change after a /reload', ToastOptions()) end
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
			pending[key] = enabled ~= booted[key] or nil
			Window():Repaint()
		end,
		onCancel = revert,
	})
end

local function AllModules(enabled)
	for _, entry in ipairs(MODULES) do
		if (Modules()[entry.key] and true or false) ~= enabled then return false end
	end
	return true
end

local function StatusText(entry)
	local text = Modules()[entry.key] and 'On' or 'Off'
	if pending[entry.key] then return text .. ' after reload' end
	return text
end

local function Sections(ui, _, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Modules',
		description = 'Turn parts of BluUI on or off. Some only change after a /reload.',
		columns = { { 'Module', ui.AVATAR_X }, { 'Status', STATUS_COLUMN } },
		buttons = {
			{ text = 'All off', icon = 'check', active = function() return AllModules(false) end, onClick = function() Apply(MODULES, false) end },
			{ text = 'All on', icon = 'check', active = function() return AllModules(true) end, onClick = function() Apply(MODULES, true) end },
		},
	})
	for _, entry in ipairs(MODULES) do
		local row = section:AddRow(entry.name .. ' ' .. entry.sub)
		ui.IconAvatar(row, AVATAR_SIZE, entry.icon):SetPoint('LEFT', ui.AVATAR_X, 0)
		ui.RowTitle(row, entry.name, entry.sub, ui.NAME_X, NAME_WIDTH)
		local status = ui.Cell(row, '', STATUS_COLUMN)
		local dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
			local on = Modules()[entry.key]
			return {
				{ text = 'On', checked = on, callback = function() Apply({ entry }, true) end },
				{ text = 'Off', checked = not on, callback = function() Apply({ entry }, false) end },
			}
		end)
		dropdown:SetPoint('RIGHT', -ui.ROW_INSET, 0)
		ui.Bind(row, function()
			status:SetText(StatusText(entry))
			dropdown.label:SetText(Modules()[entry.key] and 'On' or 'Off')
		end)
	end
	return { section }
end

BUI.ModulesPage = { Sections = Sections, ConfirmReload = ConfirmReload }
