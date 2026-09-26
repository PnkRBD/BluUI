local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local PageKit = BUILib.PageKit

function PageKit.PositionMover(parent, config)
	local function GetValue(key) if config.get then return config.get(key) end return config.db[key] end
	local function SetValue(key, value) if config.set then config.set(key, value) else config.db[key] = value end end
	return Controls.Icon(parent, {
		texture = BUILib.GetLibMedia("mover"), tooltip = config.tooltip or "Position settings",
		onClick = function(button)
			Controls.Popover({
				anchor = button, width = 260, title = "POSITION", height = config.offsets and 198 or 118,
				build = function(panel)
					local anchored = false
					local xSlider = Controls.CompactSlider(panel, nil, -1500, 1500, GetValue("centerHorizontally") and 0 or (GetValue("posX") or 0), function(value)
						SetValue("posX", value); config.apply()
					end, 1, 150)
					PageKit.PopRow(panel, 18, "X Position", xSlider)
					local ySlider = Controls.CompactSlider(panel, nil, -1000, 1000, GetValue("posY") or 0, function(value)
						SetValue("posY", value); config.apply()
					end, 1, 150)
					PageKit.PopRow(panel, 58, "Y Position", ySlider)
					local centerCheckbox
					centerCheckbox = Controls.StampCheckbox(panel, nil, GetValue("centerHorizontally"), function(value)
						SetValue("centerHorizontally", value)
						if value then SetValue("posX", 0); xSlider:SetValue(0) end
						config.apply()
						PageKit.SyncAnchorLocks(xSlider, ySlider, centerCheckbox, anchored, value)
					end, nil, true, nil, "mini")
					PageKit.PopRow(panel, 98, "Center Horizontally", centerCheckbox)
					local offsets = config.offsets
					if offsets then
						local locked = not anchored
						local minOffset, maxOffset = offsets.min or -200, offsets.max or 200
						local offsetXSlider = Controls.CompactSlider(panel, nil, minOffset, maxOffset, offsets.getX() or 0, function(value)
							offsets.setX(value)
						end, 1, 150, locked)
						local offsetYSlider = Controls.CompactSlider(panel, nil, minOffset, maxOffset, offsets.getY() or 0, function(value)
							offsets.setY(value)
						end, 1, 150, locked)
						if locked then
							offsetXSlider:SetLockedText("NO ANCHOR")
							offsetYSlider:SetLockedText("NO ANCHOR")
						end
						PageKit.PopRow(panel, 138, "Anchor X", offsetXSlider)
						PageKit.PopRow(panel, 178, "Anchor Y", offsetYSlider)
					end
					PageKit.SyncAnchorLocks(xSlider, ySlider, centerCheckbox, anchored, GetValue("centerHorizontally"))
					if config.onBuilt then config.onBuilt(xSlider, ySlider) end
				end,
			})
		end,
	})
end

local function SideAnchor(button)
	local centerX = button:GetCenter()
	local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if centerX and (centerX * scale) > GetScreenWidth() / 2 then
		return 'TOPRIGHT', 'TOPLEFT', -8, 4
	end
	return 'TOPLEFT', 'TOPRIGHT', 8, 4
end

local function BuildOptionRows(panel, options, onChange)
	local yOffset = 18
	for _, option in ipairs(options) do
		local function changed(value)
			option.set(value)
			if option.apply then option.apply(value) end
			if onChange then onChange() end
		end
		local control
		if option.kind == 'slider' then
			control = Controls.CompactSlider(panel, nil, option.min, option.max, option.get(), changed, option.step or 1, 150)
		elseif option.kind == 'dropdown' then
			control = Controls.Dropdown(panel, nil, option.items, option.get(), changed, nil, option.controlWidth or 150)
		elseif option.kind == 'textbox' then
			control = Controls.TextBox(panel, nil, option.get(), changed, nil, 150)
		elseif option.kind == 'button' then
			control = Controls.Button(panel, option.text or option.label, option.controlWidth or 150, function()
				option.set()
				if option.apply then option.apply() end
				if onChange then onChange() end
			end)
		elseif option.kind == 'swatch' then
			local color = option.get() or { 1, 1, 1, 1 }
			control = Controls.ColorSwatch(panel, {
				r = color[1], g = color[2], b = color[3], a = color[4] or 1,
				hasOpacity = option.hasOpacity == true, tooltip = option.tooltip,
				callback = function(red, green, blue, alpha) changed({ red, green, blue, alpha }) end,
			})
		else
			control = Controls.StampCheckbox(panel, nil, option.get(), changed, nil, true, nil, "mini")
		end
		PageKit.PopRow(panel, yOffset, option.label, control)
		if option.swatch then
			local swatchOptions = type(option.swatch) == 'function' and option.swatch() or option.swatch
			PageKit.AttachLeft(Controls.ColorSwatch(panel, swatchOptions), control)
		end
		yOffset = yOffset + 40
	end
end

function PageKit.OptionsIcon(parent, config)
	return Controls.Icon(parent, {
		texture = config.texture or BUILib.GetLibMedia(config.icon or 'cog'),
		tooltip = config.tooltip,
		onClick = function(button)
			local point, relativePoint, offsetX, offsetY = SideAnchor(button)
			Controls.Popover({
				anchor = button, point = point, relPt = relativePoint, offsetX = offsetX, offsetY = offsetY,
				width = config.width or 260, title = config.title,
				height = #config.options * 40 - 2,
				build = function(panel) BuildOptionRows(panel, config.options, config.onChange) end,
			})
		end,
	})
end

function PageKit.SettingsIcon(parent, config)
	config.icon = config.icon or 'cog'
	config.tooltip = config.tooltip or 'Settings'
	return PageKit.OptionsIcon(parent, config)
end

function PageKit.PositionIcon(parent, config)
	config.icon = 'mover'
	config.tooltip = config.tooltip or 'Position settings'
	return PageKit.OptionsIcon(parent, config)
end

function PageKit.SizeIcon(parent, config)
	config.icon = 'resize'
	config.tooltip = config.tooltip or 'Size settings'
	return PageKit.OptionsIcon(parent, config)
end

function PageKit.OffsetMover(parent, config)
	local minOffset, maxOffset = config.min or -100, config.max or 100
	local position = config.position
	return Controls.Icon(parent, {
		texture = BUILib.GetLibMedia("mover"), tooltip = config.tooltip or "Text offset from the bar",
		onClick = function(button)
			Controls.Popover({
				anchor = button, width = 260, title = config.title or "TEXT OFFSET", height = position and 118 or 78,
				build = function(panel)
					local yOffset = 18
					if position then
						PageKit.PopRow(panel, yOffset, position.label or "Position", Controls.Dropdown(panel, nil, position.items, position.get(), function(value)
							position.set(value)
						end, nil, position.width or 120))
						yOffset = yOffset + 40
					end
					local xSlider = Controls.CompactSlider(panel, nil, minOffset, maxOffset, config.getX(), function(value)
						config.setX(value)
					end, 1, 150)
					PageKit.PopRow(panel, yOffset, config.labelX or "X Offset", xSlider)
					PageKit.PopRow(panel, yOffset + 40, config.labelY or "Y Offset", Controls.CompactSlider(panel, nil, minOffset, maxOffset, config.getY(), function(value)
						config.setY(value)
					end, 1, 150))
				end,
			})
		end,
	})
end
