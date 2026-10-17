local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout = BUILib.Layout

local PAGE_WIDTH = 960

local Kit = BUI.OptionsKit
local Window, Option, Toggle = Kit.Window, Kit.Option, Kit.Toggle

local function Config()
	return BUI.GetDB().markers
end

local function Apply()
	BUI.Markers.Refresh()
end

local function Sections(ui, _, parent, width)
	local db = Config()
	local board = BUI.ResetBoard(ui, ui.Board(parent, width, {
		stacked = true,
		title = 'Marker bar',
		description = 'Click a tile to mark your target, Shift-Click to place a world marker.',
	}))
	board:AddTools('Bar', 'Size, display and position', {
		{ icon = 'resize', tooltip = 'Size, applied after combat', title = 'Size', options = {
			Option(db, 'Icon size', 'iconSize', { min = 16, max = 40, step = 1 }),
			Option(db, 'Spacing', 'spacing', { min = 0, max = 12, step = 1 }),
		} },
		{ tooltip = 'Display and fade', title = 'Display', options = {
			Option(db, 'Only in a group', 'onlyInGroup'),
			Option(db, 'Tooltips', 'tooltips'),
			Option(db, 'Fade until moused over', 'fadeEnabled', { separator = true }),
			Option(db, 'Bar opacity', 'alpha', { min = 10, max = 100, step = 1 }),
			Option(db, 'Faded opacity', 'fadeAlpha', { min = 0, max = 100, step = 1 }),
			Option(db, 'Fade time', 'fadeDuration', { min = 0, max = 1, step = 0.05 }),
		} },
		BUI.PositionTool(db, { selfTag = 'BUI_MarkerBar', noCenter = true, matchWidth = true }),
	}, Apply)
	board:AddTools('Utility tiles', 'Clear, ready check and countdown', {
		{ icon = 'clock', tooltip = 'Countdown seconds', title = 'Countdowns', options = {
			Option(db, 'Primary countdown', 'countdownTime', { min = 0, max = 60, step = 1 }),
			Option(db, 'Secondary countdown', 'countdownTime2', { min = 0, max = 60, step = 1 }),
		} },
		Toggle(db, nil, 'showControls'),
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
		pageFrame._page = page
		page:AutoRefresh()
	end,
})
