local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Widget = BUILib.Widget

BUI.SkinningPage = {}

local ICON_SIZE = 22
local ICON_ROOM = 24
local DROPDOWN_WIDTH = 170
local BUTTON_ROOM = 150
local RELOAD_SKINS = { chat = true, objectivetracker = true }
local POSITION_MODES = {
	{ value = 'remember', text = 'Remember' },
	{ value = 'session', text = 'Keep until reload' },
	{ value = 'reset', text = 'Reset when closed' },
}

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function SettingsPopover(info)
	local options = {}
	local settings = type(info.settings) == 'function' and info.settings() or info.settings
	for index, option in ipairs(settings) do
		if option.onClick then
			local click = option.onClick
			option = setmetatable({ onClick = function()
				click()
				Repaint()
			end }, { __index = option })
		end
		options[index] = option
	end
	return { title = info.name, options = options }
end

local function CellIcon(ui, cell, glyph, tip, onClick, active)
	local window = Window()
	local button = CreateFrame('Button', nil, cell)
	button:SetSize(ICON_SIZE, ICON_SIZE)
	local icon = ui.Glyph(button, glyph, 13, 'muted')
	icon:SetPoint('CENTER')
	local function Paint() window:Paint(icon, active and active() and 'accent' or 'muted') end
	window:Bind(button, Paint)
	button:SetScript('OnEnter', function(self)
		window:Paint(icon, 'text')
		Widget.ShowTip(self, tip)
	end)
	button:SetScript('OnLeave', function()
		Paint()
		Widget.HideTip()
	end)
	button:SetScript('OnClick', function()
		onClick()
		Paint()
	end)
	return button
end

local function FramesBoard(ui, parent, width)
	local MoveFrames = BUI.MoveFrames
	local board = ui.Board(parent, width, { title = 'Blizzard frames', description = 'Click and hold on a Blizzard window to drag it, and choose what happens to it once you let go.' })
	if MoveFrames.blockedBy then
		board:AddRow('Handled by ' .. MoveFrames.blockedBy, MoveFrames.blockedBy .. ' is loaded, so BluUI leaves frame moving to it')
		return board
	end
	local config = MoveFrames.GetConfig()
	board:AddSwitch('Movable frames', function() return config.enabled end, function(enabled) MoveFrames.SetEnabled(enabled) end, 'Drag Blizzard windows by clicking and holding on them.')
	local mode = board:AddRow('After a move', 'What happens to a window once you let go, toasts and popups always keep their spot', DROPDOWN_WIDTH)
	local dropdown = ui.Dropdown(mode, DROPDOWN_WIDTH, function()
		local items = {}
		for _, entry in ipairs(POSITION_MODES) do
			items[#items + 1] = { text = entry.text, checked = config.positionMode == entry.value, callback = function()
				config.positionMode = entry.value
				Window():Repaint()
			end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(mode, function()
		for _, entry in ipairs(POSITION_MODES) do
			if entry.value == config.positionMode then dropdown.label:SetText(entry.text) end
		end
	end)
	local saved = board:AddRow('Saved positions', 'Put every window back where Blizzard puts it', BUTTON_ROOM)
	ui.Button(saved, 'Reset positions', 'control', function()
		MoveFrames.ResetPositions()
		BUI.Print('Blizzard frame positions reset.')
	end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
	return board
end

local function ConfirmReload(info)
	BUILib.Modals.Confirm({
		parent = Window().frame,
		title = 'Reload recommended',
		message = info.name .. ' skin is now off, but some of its hooks only release on an interface reload.\n\nReload now for a 100% default ' .. info.name .. '?',
		confirmText = 'Reload now', cancelText = 'Later',
		onConfirm = ReloadUI,
	})
end
BUI.SkinningPage.ConfirmReload = ConfirmReload

local function AllSkins(order, enabled)
	for _, id in ipairs(order) do
		if (BUI.Skinning.IsSkinEnabled(id) and true or false) ~= enabled then return false end
	end
	return true
end

local function SkinsBoard(ui, parent, width)
	local Skin = BUI.Skinning
	local registry, order = Skin.GetSkinRegistry()
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Skins',
		description = 'Hover a name for what it covers. Skins added in an update start off and are marked new.',
		buttons = {
			{ text = 'All off', icon = 'check', active = function() return AllSkins(order, false) end, onClick = function()
				Skin.SetAllSkinsEnabled(false)
				Window():Repaint()
			end },
			{ text = 'All on', icon = 'check', active = function() return AllSkins(order, true) end, onClick = function()
				Skin.SetAllSkinsEnabled(true)
				Window():Repaint()
			end },
		},
	})
	for _, id in ipairs(order) do
		local info = registry[id]
		local tag
		local icons = (info.unlock and 1 or 0) + ((info.page or info.settings) and 1 or 0)
		local _, cell = board:AddSwitch(info.name, function() return Skin.IsSkinEnabled(id) end, function(enabled)
			Skin.SetSkinEnabled(id, enabled)
			Window():Repaint()
			if tag then tag:Hide() end
			if not enabled and RELOAD_SKINS[id] then ConfirmReload(info) end
		end, info.description, icons * ICON_ROOM)
		local mark = Skin.IsSkinNew(id) and 'NEW' or info.newLook and 'NEW LOOK'
		if mark then
			local text = ui.Text(cell, mark, 9, mark == 'NEW' and 'accent' or 'positive')
			text:SetPoint('LEFT', cell.label, 'LEFT', math.ceil(cell.label:GetStringWidth()) + 6, 0)
			if mark == 'NEW' then tag = text end
		end
		local anchor
		if info.page then
			anchor = CellIcon(ui, cell, 'cog', 'Settings', function() BUI.PageEngine.NavigateToID(info.page) end)
		elseif info.settings then
			anchor = CellIcon(ui, cell, 'cog', 'Settings', function() ui.Popover(anchor, SettingsPopover(info), Repaint) end)
		end
		if anchor then anchor:SetPoint('RIGHT', -4, 0) end
		if info.unlock then
			local eye = CellIcon(ui, cell, 'eye', info.unlock.tooltip or 'Unlock position', function() info.unlock.set(not info.unlock.get()) end, info.unlock.get)
			if anchor then eye:SetPoint('RIGHT', anchor, 'LEFT', 0, 0) else eye:SetPoint('RIGHT', -4, 0) end
		end
	end

	local windowFrame = Window().frame
	if not windowFrame._buiSkinUnlockHooked then
		windowFrame._buiSkinUnlockHooked = true
		windowFrame:HookScript('OnHide', function()
			for _, info in pairs(registry) do
				if info.unlock and info.unlock.get() then info.unlock.set(false) end
			end
			Window():Repaint()
		end)
	end
	return board
end

function BUI.SkinningPage.Sections(ui, _, parent, width)
	return { FramesBoard(ui, parent, width), SkinsBoard(ui, parent, width) }
end
