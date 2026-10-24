local BUI = BluUI

local POSITION_RANGE_X = 1500
local POSITION_RANGE_Y = 1000
local ANCHOR_MENU_WIDTH = 200

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
	local Pixels = BUI.OptionsKit.Pixels
	local getAnchor = Field('anchorFrame')
	local function Anchored()
		local anchor = getAnchor()
		return anchor ~= nil and anchor ~= ''
	end
	local function Free() return not Anchored() end
	local getCentered, getSide, getMode = Field('centerHorizontally'), Field('anchorPoint'), Field('horizontalMode')
	local function SideCentered() return BUI.Anchor.IsCenteredSide(getSide(), getMode()) end
	local function CenterLocked() return Anchored() and not SideCentered() end
	local function OffsetXLocked() return Free() or (not options.noCenter and getCentered() == true and SideCentered()) end
	local frames = { { value = '', text = 'None, free on the screen' } }
	for _, frame in ipairs(options.frames or (options.selfTag and BUI.AnchorFramesExcept(options.selfTag)) or BUI.C.ANCHOR_FRAMES) do
		frames[#frames + 1] = { value = frame.tag, text = frame.desc }
	end
	local rangeX, rangeY = options.rangeX or POSITION_RANGE_X, options.rangeY or POSITION_RANGE_Y
	local rows = {
		Pixels(Option('Horizontal', 'posX', { min = -rangeX, max = rangeX, step = 1, disabled = Anchored })),
		Pixels(Option('Vertical', 'posY', { min = -rangeY, max = rangeY, step = 1, disabled = Anchored })),
	}
	if not options.noCenter then
		local centered = Option('Center horizontally', 'centerHorizontally', { disabled = CenterLocked })
		local setCentered = centered.set
		local _, setX = Field('posX')
		centered.set = function(value)
			setCentered(value)
			if value then setX(0) end
		end
		rows[#rows + 1] = centered
	end
	if not options.noAnchor then
		rows[#rows + 1] = Option('Anchor to', 'anchorFrame', { entries = frames, width = ANCHOR_MENU_WIDTH, separator = true })
		rows[#rows + 1] = Option('Anchor side', 'anchorPoint', { entries = BUI.C.ANCHOR_PLACEMENT_OPTIONS, width = ANCHOR_MENU_WIDTH, disabled = Free })
		rows[#rows + 1] = Pixels(Option('Anchor offset X', 'anchorOffsetX', { min = -rangeX, max = rangeX, step = 1, disabled = OffsetXLocked }))
		rows[#rows + 1] = Pixels(Option('Anchor offset Y', 'anchorOffsetY', { min = -rangeY, max = rangeY, step = 1, disabled = Free }))
	end
	if options.matchWidth then rows[#rows + 1] = Option('Match anchor width', 'matchAnchorWidth', { disabled = Free }) end
	if options.matchHeight then rows[#rows + 1] = Option('Match anchor height', 'matchAnchorHeight', { disabled = Free }) end
	return { icon = 'location', tooltip = options.noAnchor and 'Position' or 'Position and anchor', title = 'Position', options = rows }
end

BUI.PositionTool = PositionTool

local GRID_ROW_HEIGHT = 40
local RESET_SLOT = 'reset'

local factoryOf = setmetatable({}, { __mode = 'k' })

local function SetFactory(live, factory)
	factoryOf[live] = factory
	for key, value in pairs(factory) do
		local child = live[key]
		if type(value) == 'table' and type(child) == 'table' and not factoryOf[child] then SetFactory(child, value) end
	end
end

local function FactoryOf(db)
	if factoryOf[db] == nil then
		SetFactory(BUI.GetDB(), BUI.ExportImport.FactoryProfile())
		if factoryOf[db] == nil then factoryOf[db] = false end
	end
	return factoryOf[db] or nil
end

local function ResetTool(ui, tooltip, isChanged, reset)
	return { slot = 'icon', reset = true, build = function(parent)
		local button = ui.IconButton(parent, 'redo', tooltip, reset, 'text', 16, 'accent')
		ui.Bind(button, function() button:SetShown(isChanged()) end)
		return button
	end }
end

local function RowReset(ui, tools, after, slot)
	local entries = {}
	for _, tool in ipairs(tools) do
		if tool.reset then return tools end
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
	reset.slot = slot
	tools[#tools + 1] = reset
	return tools
end

local function ResetRows(ui, section, slot)
	local AddTools, AddDragTools = section.AddTools, section.AddDragTools
	function section:AddTools(name, sub, tools, after, icon)
		return AddTools(self, name, sub, RowReset(ui, tools, after, slot), after, icon)
	end
	if AddDragTools then
		function section:AddDragTools(label, sub, icon, tools, after, group)
			return AddDragTools(self, label, sub, icon, RowReset(ui, tools, after, slot), after, group)
		end
	end
	return section
end

local function ResetBoard(ui, board)
	return ResetRows(ui, board, RESET_SLOT)
end

local function ToolGrid(ui, parent, width, title, description, columns)
	local fixed = 0
	for _, column in ipairs(columns) do fixed = fixed + (column[3] or 0) end
	local specs = {}
	for index, column in ipairs(columns) do
		specs[index] = { title = column[1], slot = column[2], width = column[3] or (width - fixed), align = column[4] }
	end
	local grid = ui.Grid(parent, width, { title = title, description = description, rowHeight = GRID_ROW_HEIGHT, columns = specs })
	return ResetRows(ui, grid, RESET_SLOT)
end

BUI.FactoryOf = FactoryOf
BUI.SetFactory = SetFactory
BUI.ResetTool = ResetTool
BUI.ResetBoard = ResetBoard
BUI.ToolGrid = ToolGrid
