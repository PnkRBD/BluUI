local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Layout = BUILib.Layout
local Widget = BUILib.Widget

local TOOL_GAP = 12
local MENU_WIDTH = 150
local SWATCH_SIZE = 28
local CONTROL_HEIGHT = 30
local POP_WIDTH = 320
local POP_PAD = 16
local POP_ROW = 40
local POP_TITLE = 24
local POP_CONTROL = 170
local POP_RADIUS = 8
local POP_OFFSET = 4
local LABEL_GAP = 16

local active

local function Close()
	if active and active:IsShown() then Widget.HideMenuAnimated(active) end
	active = nil
end

local function Named(entries, value)
	for _, entry in ipairs(entries) do
		if entry.value == value then return entry.text end
	end
	return value
end

local function Kind(tool)
	if tool.kind then return tool.kind end
	if tool.options then return 'options' end
	if tool.text then return 'button' end
	if tool.entries then return 'menu' end
	if tool.min then return 'slider' end
	if tool.onClick then return 'icon' end
	if tool.icon then return 'toggle' end
	return 'switch'
end

local function OverPopup(frame, anchor)
	return frame:IsMouseOver() or anchor:IsMouseOver() or Controls.ContextMenuIsMouseOver() or Controls.ColorPickerIsMouseOver()
end

Layout.TableKitExtensions[#Layout.TableKitExtensions + 1] = function(kit, window)
	local function Changed(tool, after)
		return function(value)
			tool.set(value)
			if after then after() end
		end
	end

	function kit.Menu(parent, width, tool, after)
		local dropdown = kit.Dropdown(parent, width, function()
			local current = tool.get()
			local items = {}
			for _, entry in ipairs(tool.entries) do
				items[#items + 1] = { text = entry.text, checked = entry.value == current, callback = function()
					tool.set(entry.value)
					if after then after() end
					window:Repaint()
				end }
			end
			return items
		end)
		kit.Bind(dropdown, function() dropdown.label:SetText(Named(tool.entries, tool.get())) end)
		return dropdown
	end

	function kit.ColorSwatch(parent, tool, after)
		local swatch = kit.Swatch(parent, SWATCH_SIZE, function(self)
			local red, green, blue, alpha = tool.get()
			Controls.OpenColorPicker({
				r = red, g = green, b = blue, a = alpha, hasOpacity = tool.opacity, anchorTo = self,
				callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
					if cancelled then tool.set(red, green, blue, alpha) else tool.set(newRed, newGreen, newBlue, newAlpha) end
					if after then after() end
					window:Repaint()
				end,
			})
		end)
		if tool.tooltip then
			swatch:SetScript('OnEnter', function(self) Widget.ShowTip(self, tool.tooltip) end)
			swatch:SetScript('OnLeave', Widget.HideTip)
		end
		kit.Bind(swatch, function()
			local red, green, blue, alpha = tool.get()
			swatch.fill:SetVertexColor(red, green, blue, tool.opacity and alpha or 1)
		end)
		return swatch
	end

	local function BuildPopover(anchor, spec, after)
		local frame = CreateFrame('Frame', nil, window.frame)
		frame:SetFrameStrata(BUILib.GetPopupStrata())
		frame:SetFrameLevel(BUILib.GetPopupLevel())
		frame:SetClampedToScreen(true)
		frame:EnableMouse(true)
		frame:SetPoint('TOPRIGHT', anchor, 'BOTTOMRIGHT', 0, -POP_OFFSET)
		frame:Hide()
		local fill, edge = Widget.DrawCardShape(frame, POP_RADIUS, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, 'BACKGROUND', 0, 0)
		window:Paint(fill, 'card')
		window:Paint(edge, 'cardEdge')
		local width = spec.width or POP_WIDTH
		local y = POP_PAD
		if spec.title then
			kit.Text(frame, spec.title:upper(), 9, 'faint'):SetPoint('TOPLEFT', POP_PAD, -y)
			y = y + POP_TITLE
		end
		for _, option in ipairs(spec.options) do
			local row = CreateFrame('Frame', nil, frame)
			row:SetSize(width - POP_PAD * 2, POP_ROW)
			row:SetPoint('TOPLEFT', POP_PAD, -y)
			local control = kit.Tool(row, option, after)
			control:SetPoint('RIGHT')
			local label = kit.Text(row, option.label, 12, 'text')
			label:SetPoint('LEFT')
			label:SetPoint('RIGHT', control, 'LEFT', -LABEL_GAP, 0)
			label:SetJustifyH('LEFT')
			label:SetWordWrap(false)
			y = y + POP_ROW
		end
		frame:SetSize(width, y - (POP_ROW - CONTROL_HEIGHT) / 2 + POP_PAD)
		local watcher = CreateFrame('Frame')
		frame:SetScript('OnShow', function(self)
			local armed = not (IsMouseButtonDown('LeftButton') or IsMouseButtonDown('RightButton'))
			watcher:SetScript('OnUpdate', function()
				local down = IsMouseButtonDown('LeftButton') or IsMouseButtonDown('RightButton')
				if not armed then
					armed = not down
				elseif down and not OverPopup(self, anchor) then
					Close()
				end
			end)
		end)
		frame:SetScript('OnHide', function(self)
			watcher:SetScript('OnUpdate', nil)
			if active == self then active = nil end
		end)
		anchor:HookScript('OnHide', function()
			if active == frame then frame:Hide() end
		end)
		return frame
	end

	function kit.Popover(anchor, spec, after)
		if anchor.popover and anchor.popover:IsShown() then
			Close()
			return
		end
		Close()
		anchor.popover = anchor.popover or BuildPopover(anchor, spec, after)
		active = anchor.popover
		window:Repaint()
		Widget.ShowMenuAnimated(active)
	end

	function kit.Tool(parent, tool, after)
		local kind = Kind(tool)
		if kind == 'options' then
			local button
			button = kit.IconButton(parent, tool.icon or 'cog', tool.tooltip, function() kit.Popover(button, tool, after) end)
			return button
		elseif kind == 'icon' then
			return kit.IconButton(parent, tool.icon, tool.tooltip, tool.onClick, tool.hover)
		elseif kind == 'toggle' then
			return kit.Toggle(parent, tool)
		elseif kind == 'button' then
			return kit.Button(parent, tool.text, tool.style, tool.onClick, tool.icon)
		elseif kind == 'menu' then
			return kit.Menu(parent, tool.width or MENU_WIDTH, tool, after)
		elseif kind == 'swatch' then
			return kit.ColorSwatch(parent, tool, after)
		elseif kind == 'slider' then
			return kit.Slider(parent, tool.width or POP_CONTROL, { min = tool.min, max = tool.max, step = tool.step, get = tool.get, set = Changed(tool, after) })
		elseif kind == 'input' then
			return kit.Input(parent, tool.width or POP_CONTROL, { placeholder = tool.placeholder, get = tool.get, set = Changed(tool, after) })
		end
		return kit.Switch(parent, tool.get, Changed(tool, after))
	end

	function kit.Tools(row, tools, after)
		local controls, anchor, width = {}, nil, 0
		for index = #tools, 1, -1 do
			local control = kit.Tool(row, tools[index], after)
			if anchor then
				control:SetPoint('RIGHT', anchor, 'LEFT', -TOOL_GAP, 0)
				width = width + TOOL_GAP
			else
				control:SetPoint('RIGHT', -kit.ROW_INSET, 0)
			end
			width = width + control:GetWidth()
			anchor = control
			controls[tools[index].key or index] = control
		end
		return controls, width
	end
end
