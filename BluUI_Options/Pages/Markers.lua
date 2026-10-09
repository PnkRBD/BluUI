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

local function Sections(ui, _, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Marker bar',
		description = 'Click a tile to mark your target, Shift-Click to place a world marker.',
	})
	board:AddTools('Bar', 'Size, display and position', {
		{ icon = 'resize', tooltip = 'Size, applied after combat', title = 'Size', options = {
			Option('Icon size', 'iconSize', { min = 16, max = 40, step = 1 }),
			Option('Spacing', 'spacing', { min = 0, max = 12, step = 1 }),
		} },
		{ tooltip = 'Display and fade', title = 'Display', slot = 'settings', options = {
			Option('Only in a group', 'onlyInGroup'),
			Option('Tooltips', 'tooltips'),
			Option('Fade until moused over', 'fadeEnabled', { separator = true }),
			Option('Bar opacity', 'alpha', { min = 10, max = 100, step = 1 }),
			Option('Faded opacity', 'fadeAlpha', { min = 0, max = 100, step = 1 }),
			Option('Fade time', 'fadeDuration', { min = 0, max = 1, step = 0.05 }),
		} },
		{ icon = 'location', tooltip = 'Position and anchor', title = 'Position', slot = 'position', options = {
			Option('Anchor to', 'anchorFrame', { entries = ANCHORS }),
			Option('Anchor side', 'anchorPoint', { entries = BUI.C.ANCHOR_PLACEMENT_OPTIONS }),
			Offset('Horizontal offset', 'posX', 'anchorOffsetX', 1500),
			Offset('Vertical offset', 'posY', 'anchorOffsetY', 1000),
			Option('Match anchor width', 'matchAnchorWidth'),
		} },
	}, Apply)
	board:AddTools('Utility tiles', 'Clear, ready check and countdown', {
		{ icon = 'clock', tooltip = 'Countdown seconds', title = 'Countdowns', options = {
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
			disabled = function() return not BUI.IsModuleEnabled('markers') end,
			tools = {
				{ icon = 'enable', tooltip = 'Turn the marker bar on or off', get = function() return BUI.IsModuleEnabled('markers') end, set = function(value) BUI.SetModuleEnabled('markers', value) end },
			},
			tabs = { { label = 'Markers', build = Sections } },
		})
		page:AutoRefresh()
	end,
})
