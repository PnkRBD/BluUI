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
	rows[#rows + 1] = Option('Anchor to', 'anchorFrame', { entries = frames })
	rows[#rows + 1] = Option('Anchor side', 'anchorPoint', { entries = BUI.C.ANCHOR_PLACEMENT_OPTIONS })
	rows[#rows + 1] = Option('Anchor offset X', 'anchorOffsetX', { min = -ANCHOR_RANGE, max = ANCHOR_RANGE, step = 1 })
	rows[#rows + 1] = Option('Anchor offset Y', 'anchorOffsetY', { min = -ANCHOR_RANGE, max = ANCHOR_RANGE, step = 1 })
	if options.matchWidth then rows[#rows + 1] = Option('Match anchor width', 'matchAnchorWidth') end
	if options.matchHeight then rows[#rows + 1] = Option('Match anchor height', 'matchAnchorHeight') end
	return { icon = 'mover', tooltip = 'Position and anchor', title = 'Position', options = rows }
end

BUI.PositionTool = PositionTool
