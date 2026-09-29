local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout

local PAGE_WIDTH = 960
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

local function Option(label, key, extra)
	local option = { label = label, get = function() return Config()[key] end, set = function(value) Config()[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Offset(label, freeKey, anchoredKey, range)
	return {
		label = label, min = -range, max = range, step = 1,
		get = function() return Config()[Anchored() and anchoredKey or freeKey] end,
		set = function(value) Config()[Anchored() and anchoredKey or freeKey] = value end,
	}
end

local function Switch(board, label, key, tip)
	board:AddSwitch(label, function() return Config()[key] == true end, function(value)
		Config()[key] = value
		Apply()
	end, tip)
end

local function Sections(ui, _, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Marker bar',
		description = 'Raid target and world marker tiles in a row. Click marks your target, Shift-Click places a world marker, Shift-Right-Click clears it. The countdown tile starts the primary timer on click, the secondary on Right-Click, and Shift-Click cancels it.',
	})
	Switch(board, 'Only in a group', 'onlyInGroup', 'Hide the bar while not in a party or raid')
	Switch(board, 'Tooltips', 'tooltips', 'Explain each tile on mouseover')
	board:AddTools('Position', 'Free on the screen, or hung off another BluUI frame', {
		{ icon = 'mover', tooltip = 'Position and anchor', title = 'Position', options = {
			Option('Anchor to', 'anchorFrame', { entries = ANCHORS }),
			Option('Anchor side', 'anchorPoint', { entries = BUI.C.ANCHOR_PLACEMENT_OPTIONS }),
			Offset('Horizontal offset', 'posX', 'anchorOffsetX', 1500),
			Offset('Vertical offset', 'posY', 'anchorOffsetY', 1000),
			Option('Match anchor width', 'matchAnchorWidth'),
		} },
	}, Apply)
	board:AddTools('Size', 'Icon size and spacing, applied after combat ends', {
		{ tooltip = 'Icon size and spacing', title = 'Size', options = {
			Option('Icon size', 'iconSize', { min = 16, max = 40, step = 1 }),
			Option('Spacing', 'spacing', { min = 0, max = 12, step = 1 }),
		} },
	}, Apply)
	board:AddTools('Mouseover fade', 'Fade the bar out until the cursor is over it', {
		{ tooltip = 'Opacity and fade', title = 'Fade', options = {
			Option('Bar opacity', 'alpha', { min = 10, max = 100, step = 1 }),
			Option('Faded opacity', 'fadeAlpha', { min = 0, max = 100, step = 1 }),
			Option('Fade time', 'fadeDuration', { min = 0.05, max = 1, step = 0.05 }),
			Option('Animate', 'fadeAnimated'),
		} },
		{ get = function() return Config().fadeEnabled == true end, set = function(value) Config().fadeEnabled = value end },
	}, Apply)
	board:AddTools('Utility tiles', 'Clear, ready check and countdown beside the markers', {
		{ tooltip = 'Countdown seconds', title = 'Countdowns', options = {
			Option('Primary countdown', 'countdownTime', { min = 0, max = 60, step = 1 }),
			Option('Secondary countdown', 'countdownTime2', { min = 0, max = 60, step = 1 }),
		} },
		{ get = function() return Config().showControls ~= false end, set = function(value) Config().showControls = value end },
	}, Apply)
	return { board }
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
			tools = {
				{ icon = 'enable', tooltip = 'Turn the marker bar on or off', get = function() return BUI.IsModuleEnabled('markers') end, set = function(value) BUI.SetModuleEnabled('markers', value) end },
			},
			tabs = { { label = 'Markers', build = Sections } },
		})
		page:AutoRefresh()
	end,
})
