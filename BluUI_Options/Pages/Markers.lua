local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout

local PAGE_WIDTH = 960
local SLIDER_WIDTH = 220
local DROPDOWN_WIDTH = 220
local FREE = ''

local ANCHORS = { { value = FREE, text = 'None, free on the screen' } }
for _, frame in ipairs(BUI.AnchorFramesExcept('BUI_MarkerBar')) do
	ANCHORS[#ANCHORS + 1] = { value = frame.tag, text = frame.desc }
end

local function Window()
	return BUI.PageEngine.window
end

local function Config()
	return BUI.GetDB().markers
end

local function Apply()
	BUI.Markers.Refresh()
end

local function Anchored()
	return Config().anchorFrame ~= FREE
end

local function Field(key)
	return function() return Config()[key] end, function(value) Config()[key] = value end
end

local function Offset(freeKey, anchoredKey)
	return function()
		return Config()[Anchored() and anchoredKey or freeKey]
	end, function(value)
		Config()[Anchored() and anchoredKey or freeKey] = value
	end
end

local function Named(entries, value)
	for _, entry in ipairs(entries) do
		if entry.value == value then return entry.text end
	end
	return value
end

local function Switch(board, label, get, set, tip)
	board:AddSwitch(label, get, function(value)
		set(value)
		Apply()
	end, tip)
end

local function Slider(ui, row, minimum, maximum, step, get, set)
	ui.Slider(row, SLIDER_WIDTH, { min = minimum, max = maximum, step = step, get = get, set = function(value)
		set(value)
		Apply()
	end }):SetPoint('RIGHT', -ui.ROW_INSET, 0)
end

local function Menu(ui, row, entries, get, set)
	local dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
		local current = get()
		local items = {}
		for _, entry in ipairs(entries) do
			items[#items + 1] = { text = entry.text, checked = entry.value == current, callback = function()
				set(entry.value)
				Apply()
				Window():Repaint()
			end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(row, function() dropdown.label:SetText(Named(entries, get())) end)
end

local function BarBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Marker bar',
		description = 'Raid target and world marker tiles in a row. Click marks your target, Shift-Click places a world marker, Shift-Right-Click clears it.',
	})
	Switch(board, 'Only in a group', function() return Config().onlyInGroup == true end, function(value)
		Config().onlyInGroup = value
	end, 'Hide the bar while not in a party or raid')
	Switch(board, 'Tooltips', function() return Config().tooltips == true end, function(value)
		Config().tooltips = value
	end, 'Explain each tile on mouseover')
	Slider(ui, board:AddRow('Icon size', 'Applied after combat ends', SLIDER_WIDTH), 16, 40, 1, Field('iconSize'))
	Slider(ui, board:AddRow('Spacing', 'Pixels between tiles', SLIDER_WIDTH), 0, 12, 1, Field('spacing'))
	return board
end

local function PositionBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Position',
		description = 'Where the bar sits. Drag it on the screen, or hang it off another BluUI frame and nudge it from there.',
	})
	Switch(board, 'Match anchor width', function() return Config().matchAnchorWidth == true end, function(value)
		Config().matchAnchorWidth = value
	end, 'Spread the tiles to the width of the anchor frame')
	Menu(ui, board:AddRow('Anchor to', 'Free on the screen, or attached to a frame', DROPDOWN_WIDTH), ANCHORS, Field('anchorFrame'))
	Menu(ui, board:AddRow('Anchor side', 'Which side of that frame the bar hangs on', DROPDOWN_WIDTH), BUI.C.ANCHOR_PLACEMENT_OPTIONS, Field('anchorPoint'))
	Slider(ui, board:AddRow('Horizontal offset', 'From the screen centre, or from the anchor frame', SLIDER_WIDTH), -1500, 1500, 1, Offset('posX', 'anchorOffsetX'))
	Slider(ui, board:AddRow('Vertical offset', 'From the screen centre, or from the anchor frame', SLIDER_WIDTH), -1000, 1000, 1, Offset('posY', 'anchorOffsetY'))
	return board
end

local function FadeBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Opacity and fade',
		description = 'How see-through the bar is, and whether it fades away until the mouse is over it.',
	})
	Switch(board, 'Fade until hovered', function() return Config().fadeEnabled == true end, function(value)
		Config().fadeEnabled = value
	end, 'Fade the bar out until the cursor is over it')
	Switch(board, 'Animate the fade', function() return Config().fadeAnimated == true end, function(value)
		Config().fadeAnimated = value
	end, 'Ease between the two opacities instead of snapping')
	Slider(ui, board:AddRow('Bar opacity', 'Percent', SLIDER_WIDTH), 10, 100, 1, Field('alpha'))
	Slider(ui, board:AddRow('Faded opacity', 'Percent while the mouse is away', SLIDER_WIDTH), 0, 100, 1, Field('fadeAlpha'))
	Slider(ui, board:AddRow('Fade time', 'Seconds', SLIDER_WIDTH), 0.05, 1, 0.05, Field('fadeDuration'))
	return board
end

local function UtilityBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Utility tiles',
		description = 'Clear, ready check and countdown beside the markers. Click the countdown for the primary timer, Right-Click for the secondary, Shift-Click cancels it.',
	})
	Switch(board, 'Show utility tiles', function() return Config().showControls ~= false end, function(value)
		Config().showControls = value
	end, 'Clear, ready check and countdown')
	Slider(ui, board:AddRow('Primary countdown', 'Seconds, 0 turns it off', SLIDER_WIDTH), 0, 60, 1, Field('countdownTime'))
	Slider(ui, board:AddRow('Secondary countdown', 'Seconds, 0 turns it off', SLIDER_WIDTH), 0, 60, 1, Field('countdownTime2'))
	return board
end

local function Sections(ui, _, parent, width)
	return { BarBoard(ui, parent, width), PositionBoard(ui, parent, width), FadeBoard(ui, parent, width), UtilityBoard(ui, parent, width) }
end

BUI.PageEngine.RegisterPage('markers', {
	title = 'Markers',
	buttonText = 'Markers',
	icon = 'markers',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'markers',
			title = 'Markers',
			placeholder = 'Search marker settings...',
			toggles = {
				{ icon = 'enable', tooltip = 'Turn the marker bar on or off', get = function() return BUI.IsModuleEnabled('markers') end, set = function(value) BUI.SetModuleEnabled('markers', value) end },
			},
			tabs = { { label = 'Markers', build = Sections } },
		})
		page:AutoRefresh()
	end,
})
