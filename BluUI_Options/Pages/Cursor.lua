local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Layout = BUILib.Controls, BUILib.Layout
local MouseCursor = BUI.MouseCursor

local PAGE_WIDTH = 960
local NAME_WIDTH = 220
local SLIDER_WIDTH = 220
local SWATCH_SIZE = 28
local MODE_COLUMN = 300
local MODE_WIDTH = 150
local OFFSET_COLUMN = 470
local OFFSET_WIDTH = 220
local LAYER_COLUMN = 710
local LAYER_WIDTH = 220

local RINGS = {
	{ key = 'main', name = 'Main ring', sub = 'The base ring that follows the cursor' },
	{ key = 'inner', name = 'Inner ring', sub = 'Stacked inside the main ring' },
	{ key = 'outer', name = 'Outer ring', sub = 'Stacked outside the main ring' },
}

local MODES = {
	{ value = 'off', text = 'Off' },
	{ value = 'static', text = 'Static ring' },
	{ value = 'click', text = 'Click ring' },
	{ value = 'gcd', text = 'GCD swipe' },
	{ value = 'cast', text = 'Cast progress' },
}

local function Window()
	return BUI.PageEngine.window
end

local function Config()
	return BUI.GetDB().cursor
end

local function Apply()
	MouseCursor.Apply()
end

local function ModeOf(slot)
	if not slot.enabled or slot.kind == 'none' then return 'off' end
	return slot.kind
end

local function ModeName(value)
	for _, mode in ipairs(MODES) do
		if mode.value == value then return mode.text end
	end
end

local function SetMode(slot, value)
	if value == 'off' then
		slot.enabled = false
	else
		slot.enabled = true
		slot.kind = value
	end
	Apply()
	Window():Repaint()
end

local function PickColor(slot, anchor)
	local red, green, blue, alpha = slot.colorR, slot.colorG, slot.colorB, slot.alpha
	Controls.OpenColorPicker({
		r = red, g = green, b = blue, a = alpha, hasOpacity = true, anchorTo = anchor,
		callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
			if cancelled then
				slot.colorR, slot.colorG, slot.colorB, slot.alpha = red, green, blue, alpha
			else
				slot.colorR, slot.colorG, slot.colorB, slot.alpha = newRed, newGreen, newBlue, newAlpha
			end
			Apply()
			Window():Repaint()
		end,
	})
end

local function CursorBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Cursor',
		description = 'Rings and cast feedback that follow the mouse. Everything here applies to the live cursor as you change it.',
	})
	board:AddSwitch('Cursor rings', function() return BUI.IsModuleEnabled('cursor') end, function(value)
		BUI.SetModuleEnabled('cursor', value)
	end, 'The whole module')
	board:AddSwitch('Only in combat', function() return Config().combatOnly == true end, function(value)
		Config().combatOnly = value
		MouseCursor.Refresh()
	end)
	board:AddSwitch('Hide over BluUI windows', function() return Config().hideOverMenus == true end, function(value)
		Config().hideOverMenus = value
		Apply()
	end)
	ui.Slider(board:AddRow('Ring size', 'Diameter before each ring adds its own offset', SLIDER_WIDTH), SLIDER_WIDTH, {
		min = 8, max = 160, step = 1,
		get = function() return Config().size end,
		set = function(value)
			Config().size = value
			Apply()
		end,
	}):SetPoint('RIGHT', -ui.ROW_INSET, 0)
	return board
end

local function RingsSection(ui, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Rings',
		description = 'Three rings share the cursor. Each one picks what it shows, how far it sits from the ring size, and which draws on top.',
		columns = { { 'Ring', ui.AVATAR_X }, { 'Shows', MODE_COLUMN }, { 'Size offset', OFFSET_COLUMN }, { 'Layer', LAYER_COLUMN } },
	})
	for _, ring in ipairs(RINGS) do
		local slot = Config().slots[ring.key]
		local row = section:AddRow(ring.name .. ' ' .. ring.sub)
		local swatch = ui.Swatch(row, SWATCH_SIZE, function(self) PickColor(slot, self) end)
		swatch:SetPoint('LEFT', ui.AVATAR_X, 0)
		ui.RowTitle(row, ring.name, ring.sub, ui.NAME_X, NAME_WIDTH)
		local dropdown = ui.Dropdown(row, MODE_WIDTH, function()
			local current = ModeOf(slot)
			local items = {}
			for _, mode in ipairs(MODES) do
				items[#items + 1] = { text = mode.text, checked = mode.value == current, callback = function() SetMode(slot, mode.value) end }
			end
			return items
		end)
		dropdown:SetPoint('LEFT', MODE_COLUMN, 0)
		ui.Slider(row, OFFSET_WIDTH, {
			min = -40, max = 80, step = 1,
			get = function() return slot.offset end,
			set = function(value)
				slot.offset = value
				Apply()
			end,
		}):SetPoint('LEFT', OFFSET_COLUMN, 0)
		ui.Slider(row, LAYER_WIDTH, {
			min = 1, max = 10, step = 1,
			get = function() return slot.zOrder end,
			set = function(value)
				slot.zOrder = value
				Apply()
			end,
		}):SetPoint('LEFT', LAYER_COLUMN, 0)
		ui.Bind(row, function()
			swatch.fill:SetVertexColor(slot.colorR, slot.colorG, slot.colorB, slot.alpha)
			dropdown.label:SetText(ModeName(ModeOf(slot)))
		end)
	end
	return section
end

local function Sections(ui, _, parent, width)
	return { CursorBoard(ui, parent, width), RingsSection(ui, parent, width) }
end

BUI.PageEngine.RegisterPage('cursor', {
	title = 'Cursor',
	buttonText = 'Cursor',
	icon = 'cursor',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'cursor',
			title = 'Cursor',
			placeholder = 'Search cursor settings...',
			tabs = { { label = 'Cursor', build = Sections } },
		})
		page:AutoRefresh()
	end,
})
