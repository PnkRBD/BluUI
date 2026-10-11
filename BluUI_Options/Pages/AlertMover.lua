local BUI = BluUI

local POSITION_RANGE_X = 1500
local POSITION_RANGE_Y = 1000
local ANCHOR_RANGE = 200

local function PositionTool(db, options)
	options = options or {}
	local fieldMap = options.fields or {}
	local function Field(standardKey)
		local key = fieldMap[standardKey] or standardKey
		return function() return db[key] end, function(value) db[key] = value end
	end
	local function Option(label, standardKey, extra)
		local option = { label = label }
		option.get, option.set = Field(standardKey)
		for name, value in pairs(extra or {}) do option[name] = value end
		return option
	end
	local frames = { { value = '', text = 'None, free on the screen' } }
	for _, frame in ipairs(options.frames or (options.selfTag and BUI.AnchorFramesExcept(options.selfTag)) or BUI.C.ANCHOR_FRAMES) do
		frames[#frames + 1] = { value = frame.tag, text = frame.desc }
	end
	local rangeX, rangeY = options.rangeX or POSITION_RANGE_X, options.rangeY or POSITION_RANGE_Y
	local rows = {
		Option('Horizontal', 'posX', { min = -rangeX, max = rangeX, step = 1 }),
		Option('Vertical', 'posY', { min = -rangeY, max = rangeY, step = 1 }),
	}
	if not options.noCenter then
		local centered = Option('Center horizontally', 'centerHorizontally')
		local setCentered = centered.set
		local _, setX = Field('posX')
		centered.set = function(value)
			setCentered(value)
			if value then setX(0) end
		end
		rows[#rows + 1] = centered
	end
	if not options.noAnchor then
		rows[#rows + 1] = Option('Anchor to', 'anchorFrame', { entries = frames, separator = true })
		rows[#rows + 1] = Option('Anchor side', 'anchorPoint', { entries = BUI.C.ANCHOR_PLACEMENT_OPTIONS })
		rows[#rows + 1] = Option('Anchor offset X', 'anchorOffsetX', { min = -ANCHOR_RANGE, max = ANCHOR_RANGE, step = 1 })
		rows[#rows + 1] = Option('Anchor offset Y', 'anchorOffsetY', { min = -ANCHOR_RANGE, max = ANCHOR_RANGE, step = 1 })
	end
	if options.matchWidth then rows[#rows + 1] = Option('Match anchor width', 'matchAnchorWidth') end
	if options.matchHeight then rows[#rows + 1] = Option('Match anchor height', 'matchAnchorHeight') end
	return { icon = 'location', tooltip = options.noAnchor and 'Position' or 'Position and anchor', title = 'Position', options = rows }
end

BUI.PositionTool = PositionTool

local GRID_ROW_HEIGHT = 40

local function ResetTool(ui, tooltip, isChanged, reset)
	return { slot = 'icon', build = function(parent)
		local button = ui.IconButton(parent, 'redo', tooltip, reset, 'text', 16, 'accent')
		ui.Bind(button, function() button:SetShown(isChanged()) end)
		return button
	end }
end

local function RowReset(ui, tools, after)
	local entries = {}
	for _, tool in ipairs(tools) do
		if tool.slot == 'reset' then return tools end
		for _, option in ipairs(tool.options or { tool }) do
			if option.default then entries[#entries + 1] = option end
		end
	end
	if #entries == 0 then return tools end
	local reset = ResetTool(ui, 'Changed from the factory default, click to restore it', function()
		for _, option in ipairs(entries) do
			local a1, a2, a3, a4 = option.get()
			local d1, d2, d3, d4 = option.default()
			if a1 ~= d1 or a2 ~= d2 or a3 ~= d3 or a4 ~= d4 then return true end
		end
		return false
	end, function()
		for _, option in ipairs(entries) do option.set(option.default()) end
		if after then after() end
		BUI.PageEngine.window:Repaint()
	end)
	reset.slot = 'reset'
	tools[#tools + 1] = reset
	return tools
end

local function ToolGrid(ui, parent, width, title, description, columns)
	local fixed = 0
	for _, column in ipairs(columns) do fixed = fixed + (column[3] or 0) end
	local specs = {}
	for index, column in ipairs(columns) do
		specs[index] = { title = column[1], slot = column[2], width = column[3] or (width - fixed), align = column[4] }
	end
	local grid = ui.Grid(parent, width, { title = title, description = description, rowHeight = GRID_ROW_HEIGHT, columns = specs })
	local AddTools = grid.AddTools
	function grid:AddTools(name, sub, tools, after)
		return AddTools(self, name, sub, RowReset(ui, tools, after), after)
	end
	return grid
end

BUI.ResetTool = ResetTool
BUI.ToolGrid = ToolGrid
