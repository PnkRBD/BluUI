local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls = BUILib.Controls
local PageKit = BUILib.PageKit

local POSITION_RANGE_X = 1500
local POSITION_RANGE_Y = 1000
local ANCHOR_RANGE = 200

local function AlertMover(parent, db, apply, options)
	options = options or {}
	local fieldMap = options.fields or {}
	local function FieldKey(standardKey) return fieldMap[standardKey] or standardKey end
	local function Get(standardKey) return db[FieldKey(standardKey)] end
	local function Set(standardKey, value) db[FieldKey(standardKey)] = value end

	local rangeX = (options.xyRange and options.xyRange.x) or 1500
	local rangeY = (options.xyRange and options.xyRange.y) or 1000
	local anchorRange = options.anchorRange or 200
	local dropdowns = options.dropdowns or {}
	local rowCount = 6 + (options.noCenter and 0 or 1) + (options.unlock and 1 or 0) + (options.matchWidth and 1 or 0) + (options.matchHeight and 1 or 0) + #dropdowns

	return Controls.Icon(parent, {
		texture = BUILib.GetLibMedia('mover'), tooltip = 'Position & anchor',
		onClick = function(button)
			local frameItems = { { value = '', text = 'None (screen position)' } }
			local list = options.frames or (options.selfTag and BUI.AnchorFramesExcept(options.selfTag)) or BUI.C.ANCHOR_FRAMES
			for index = 1, #list do
				frameItems[#frameItems + 1] = { value = list[index].tag, text = list[index].desc }
			end
			Controls.Popover({
				anchor = button, width = 280, title = 'POSITION', height = rowCount * 40 - 2,
				build = function(panel)
					local y = 18
					local Widget = BUILib.Widget
					local centerCheckbox, unlockCheckbox
					local xSlider = Controls.CompactSlider(panel, nil, -rangeX, rangeX, Get('posX') or 0, function(value) Set('posX', value); apply() end, 1, 150)
					PageKit.PopRow(panel, y, 'X Position', xSlider); y = y + 40
					local ySlider = Controls.CompactSlider(panel, nil, -rangeY, rangeY, Get('posY') or 0, function(value) Set('posY', value); apply() end, 1, 150)
					PageKit.PopRow(panel, y, 'Y Position', ySlider); y = y + 40
					local function SyncAnchorLock()
						local anchored = (Get('anchorFrame') or '') ~= ''
						if anchored then
							xSlider:SetLockedText('ANCHORED')
							ySlider:SetLockedText('ANCHORED')
						end
						xSlider:SetLocked(anchored)
						ySlider:SetLocked(anchored)
						if centerCheckbox then Widget.Unwrap(centerCheckbox):SetEnabled(not anchored) end
					end
					if not options.noCenter then
						centerCheckbox = Controls.StampCheckbox(panel, nil, Get('centerHorizontally'), function(value)
							Set('centerHorizontally', value)
							if value then Set('posX', 0); xSlider:SetValue(0) end
							apply()
						end, nil, true, nil, 'mini')
						PageKit.PopRow(panel, y, 'Center Horizontally', centerCheckbox); y = y + 40
					end
					for _, dropdown in ipairs(dropdowns) do
						PageKit.PopRow(panel, y, dropdown.label, Controls.Dropdown(panel, nil, dropdown.items, Get(dropdown.key) or dropdown.default, function(value)
							Set(dropdown.key, value)
							apply()
						end, nil, 150)); y = y + 40
					end
					if options.unlock then
						unlockCheckbox = Controls.StampCheckbox(panel, nil, options.unlock.get(), function(value)
							options.unlock.set(value)
						end, nil, true, nil, 'mini')
						PageKit.PopRow(panel, y, 'Unlock (drag to move)', unlockCheckbox); y = y + 40
					end
					if options.matchWidth then
						PageKit.PopRow(panel, y, 'Match Anchor Width', Controls.StampCheckbox(panel, nil, options.matchWidth.get(), function(value)
							options.matchWidth.set(value)
						end, nil, true, nil, 'mini')); y = y + 40
					end
					if options.matchHeight then
						PageKit.PopRow(panel, y, 'Match Anchor Height', Controls.StampCheckbox(panel, nil, options.matchHeight.get(), function(value)
							options.matchHeight.set(value)
						end, nil, true, nil, 'mini')); y = y + 40
					end
					PageKit.PopRow(panel, y, 'Anchor Frame', Controls.Dropdown(panel, nil, frameItems, Get('anchorFrame') or '', function(value)
						Set('anchorFrame', value); apply()
						SyncAnchorLock()
					end, nil, 150)); y = y + 40
					SyncAnchorLock()
					PageKit.PopRow(panel, y, 'Anchor Point', Controls.Dropdown(panel, nil, BUI.C.ANCHOR_PLACEMENT_OPTIONS, Get('anchorPoint') or 'BOTTOM', function(value)
						Set('anchorPoint', value); apply()
					end, nil, 150)); y = y + 40
					PageKit.PopRow(panel, y, 'Anchor X', Controls.CompactSlider(panel, nil, -anchorRange, anchorRange, Get('anchorOffsetX') or 0, function(value) Set('anchorOffsetX', value); apply() end, 1, 150)); y = y + 40
					PageKit.PopRow(panel, y, 'Anchor Y', Controls.CompactSlider(panel, nil, -anchorRange, anchorRange, Get('anchorOffsetY') or 0, function(value) Set('anchorOffsetY', value); apply() end, 1, 150))
				end,
			})
		end,
	})
end

BUI.AlertMover = AlertMover

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
	for _, frame in ipairs(options.selfTag and BUI.AnchorFramesExcept(options.selfTag) or BUI.C.ANCHOR_FRAMES) do
		frames[#frames + 1] = { value = frame.tag, text = frame.desc }
	end
	local rows = {
		Option('Horizontal', 'posX', { min = -POSITION_RANGE_X, max = POSITION_RANGE_X, step = 1 }),
		Option('Vertical', 'posY', { min = -POSITION_RANGE_Y, max = POSITION_RANGE_Y, step = 1 }),
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
	return { icon = 'mover', tooltip = 'Position and anchor', title = 'Position', options = rows }
end

BUI.PositionTool = PositionTool
