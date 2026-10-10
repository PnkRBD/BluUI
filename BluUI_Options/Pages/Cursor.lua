local BUI = BluUI
local BUILib = BUI.BUILibClient
local Layout, Modals = BUILib.Layout, BUILib.Modals
local MouseCursor = BUI.MouseCursor
local RING_TEXTURE = BUI.C.CURSOR_RING_TEXTURE

local PAGE_WIDTH = 960
local MENU_WIDTH = 170
local SLIDER_WIDTH = 240
local POINTER_SIZE = 18
local POINTER_TIP_X, POINTER_TIP_Y = 5, 2
local GCD_DURATION = 1.2
local CAST_DURATION = 1.8

local RINGS = {
	{ key = 'main', name = 'Main ring', about = 'Your primary cursor outline' },
	{ key = 'inner', name = 'Inner ring', about = 'Sits inside the main ring' },
	{ key = 'outer', name = 'Outer ring', about = 'Sits outside the main ring' },
}

local function Scene(label, name)
	return { label = label, texture = BUI.C.MEDIA_PATH .. 'cursor_preview_' .. name .. '.tga', aspect = 1 }
end

local BACKGROUNDS = {
	{ label = 'Dark' },
	Scene('Jungle ruins', 'jungle'),
	Scene('Molten', 'molten'),
	Scene('Fel', 'fel'),
	Scene('Silvermoon', 'silvermoon'),
	Scene('Garden', 'garden'),
	Scene('Void', 'void'),
}

local BEHAVIORS = {
	{ value = 'static', text = 'Always visible' },
	{ value = 'click', text = 'On click' },
	{ value = 'gcd', text = 'GCD swipe' },
	{ value = 'cast', text = 'Cast progress' },
}

local preview

local function Window()
	return BUI.PageEngine.window
end

local function Config()
	return BUI.GetDB().cursor
end

local function Restyle()
	MouseCursor.Restyle()
	preview:UpdateRing()
end

local function Changed()
	MouseCursor.Apply()
	preview:UpdateRing()
	Window():Repaint()
end

local function Reset()
	Modals.Confirm({
		title = 'Reset cursor',
		message = 'Put every cursor setting back to its default?',
		confirmText = 'Reset', cancelText = 'Cancel',
		onConfirm = function()
			local config = Config()
			wipe(config)
			for key, value in pairs(CopyTable(BUI.Defaults.profile.cursor)) do config[key] = value end
			MouseCursor.Refresh()
			Changed()
		end,
	})
end

local function BuildPreview(stage, kit)
	local holder = CreateFrame('Frame', nil, stage)
	holder:SetSize(1, 1)
	holder:SetPoint('CENTER')
	local holderLevel = holder:GetFrameLevel()

	local widgets = {}
	for _, ring in ipairs(RINGS) do
		local layer = CreateFrame('Frame', nil, holder)
		layer:SetSize(1, 1)
		layer:SetPoint('CENTER')
		local texture = layer:CreateTexture(nil, 'OVERLAY')
		texture:SetTexture(RING_TEXTURE)
		texture:SetPoint('CENTER')
		texture:Hide()
		local cooldown = CreateFrame('Cooldown', nil, layer)
		cooldown:SetPoint('CENTER')
		cooldown:SetSwipeTexture(RING_TEXTURE)
		cooldown:SetReverse(true)
		cooldown:SetDrawSwipe(true)
		cooldown:SetDrawEdge(false)
		cooldown:SetDrawBling(false)
		cooldown:SetHideCountdownNumbers(true)
		cooldown:Hide()
		widgets[ring.key] = { layer = layer, texture = texture, cooldown = cooldown, kind = 'off' }
	end

	local pointerLayer = CreateFrame('Frame', nil, holder)
	pointerLayer:SetSize(1, 1)
	pointerLayer:SetPoint('CENTER')
	pointerLayer:SetFrameLevel(holderLevel + 20)
	local pointer = kit.Glyph(pointerLayer, 'cursor', POINTER_SIZE, 'text', 'OVERLAY')
	pointer:SetPoint('TOPLEFT', pointerLayer, 'CENTER', -POINTER_TIP_X, POINTER_TIP_Y)

	local view = {}
	local held = false
	local lastX, lastY

	function view:UpdateRing()
		local config = Config()
		for _, ring in ipairs(RINGS) do
			local slot = config.slots[ring.key]
			local widget = widgets[ring.key]
			widget.kind = slot.enabled and slot.kind or 'off'
			widget.texture:Hide()
			widget.cooldown:Hide()
			if widget.kind ~= 'off' then
				widget.layer:SetFrameLevel(holderLevel + slot.zOrder)
				local diameter = MouseCursor.SlotDiameter(slot)
				widget.texture:SetSize(diameter, diameter)
				widget.texture:SetVertexColor(slot.colorR, slot.colorG, slot.colorB, slot.alpha)
				widget.cooldown:SetSize(diameter, diameter)
				widget.cooldown:SetSwipeColor(slot.colorR, slot.colorG, slot.colorB, slot.alpha)
				widget.texture:SetShown(widget.kind == 'static' or (widget.kind == 'click' and held))
			end
		end
	end

	local function Press(down)
		held = down
		local now = GetTime()
		for _, ring in ipairs(RINGS) do
			local widget = widgets[ring.key]
			if widget.kind == 'click' then
				widget.texture:SetShown(down)
			elseif down and (widget.kind == 'gcd' or widget.kind == 'cast') then
				widget.cooldown:Show()
				widget.cooldown:SetCooldown(now, widget.kind == 'gcd' and GCD_DURATION or CAST_DURATION)
			end
		end
	end

	local function Follow(self)
		local cursorX, cursorY = GetCursorPosition()
		if cursorX == lastX and cursorY == lastY then return end
		lastX, lastY = cursorX, cursorY
		local scale = self:GetEffectiveScale()
		holder:SetPoint('CENTER', self, 'BOTTOMLEFT', cursorX / scale - self:GetLeft(), cursorY / scale - self:GetBottom())
	end

	local function Rest(self)
		self:SetScript('OnUpdate', nil)
		lastX, lastY = nil, nil
		if held then Press(false) end
		holder:SetPoint('CENTER', self, 'CENTER')
		pointer:Show()
	end

	stage:EnableMouse(true)
	stage:SetScript('OnEnter', function(self)
		pointer:Hide()
		self:SetScript('OnUpdate', Follow)
	end)
	stage:SetScript('OnLeave', Rest)
	stage:SetScript('OnMouseDown', function(_, button) if button == 'LeftButton' then Press(true) end end)
	stage:SetScript('OnMouseUp', function(_, button) if button == 'LeftButton' then Press(false) end end)
	stage:HookScript('OnShow', function() view:UpdateRing() end)
	stage:HookScript('OnHide', Rest)
	view:UpdateRing()
	return view
end

local function SetCombatOnly(value)
	Config().combatOnly = value
	MouseCursor.Refresh()
	Changed()
end

local function VisibilityItems()
	local combatOnly = Config().combatOnly
	return {
		{ text = 'Always shown', checked = not combatOnly, callback = function() SetCombatOnly(false) end },
		{ text = 'In combat only', checked = combatOnly, callback = function() SetCombatOnly(true) end },
	}
end

local function SizeOption(label, store, key, min, max)
	return {
		label = label, min = min, max = max, step = 1,
		get = function() return store()[key] end,
		set = function(value)
			store()[key] = value
			Restyle()
		end,
	}
end

local function RingRow(board, ring)
	local function slot() return Config().slots[ring.key] end
	board:AddTools(ring.name, ring.about, {
		{ entries = BEHAVIORS, width = MENU_WIDTH, get = function() return slot().kind end, set = function(value)
			slot().kind = value
			Changed()
		end },
		{ kind = 'swatch', opacity = true, tooltip = 'Ring colour', get = function()
			local current = slot()
			return current.colorR, current.colorG, current.colorB, current.alpha
		end, set = function(red, green, blue, alpha)
			local current = slot()
			current.colorR, current.colorG, current.colorB, current.alpha = red, green, blue, alpha
			Restyle()
		end },
		{ tooltip = 'Size and layer', title = ring.name, options = {
			SizeOption('Size offset', slot, 'offset', -40, 80),
			SizeOption('Layer', slot, 'zOrder', 1, 10),
		} },
		{ get = function() return slot().enabled == true end, set = function(value)
			slot().enabled = value
			Changed()
		end },
	})
end

local function CursorBoard(kit, parent, width)
	local board = kit.Board(parent, width, {
		stacked = true,
		title = 'Cursor',
		description = 'Rings that follow the mouse. The size sets the main ring; the inner and outer rings sit relative to it.',
	})
	board:AddTools('Cursor size', 'Diameter of the main ring in pixels', {
		{ build = function(parent)
			return kit.Slider(parent, SLIDER_WIDTH, { min = 8, max = 160, step = 1, get = function() return Config().size end, set = function(value)
				Config().size = value
				Restyle()
			end })
		end },
	})
	board:AddTools('Show the rings', 'Always, or only while in combat', {
		{ build = function(parent)
			return kit.Select(parent, {
				icon = 'eye',
				label = 'Visibility',
				value = function() return Config().combatOnly and 'In combat only' or 'Always shown' end,
				items = VisibilityItems,
			})
		end },
	})
	return board
end

local function RingsBoard(kit, parent, width)
	local board = kit.Board(parent, width, {
		stacked = true,
		title = 'Rings',
		description = 'Main, inner and outer. Each ring has its own behavior, colour, size and layer.',
	})
	for _, ring in ipairs(RINGS) do RingRow(board, ring) end
	return board
end

local function BoardItem(kit, parent, width, build)
	local item = CreateFrame('Frame', nil, parent)
	local board = build(kit, item, width)
	local query = ''
	function item:Filter(text)
		query = text
		return board:Layout(0, query) > 0
	end
	function item:Measure()
		return board:Layout(0, query)
	end
	function item:SetLast(last)
		board:SetLast(last)
	end
	return item
end

BUI.PageEngine.RegisterPage('cursor', {
	title = 'Cursor',
	buttonText = 'Cursor',
	icon = 'cursor',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.SplitPage(page:GetTab(1), { window = Window() }, {
			icon = 'cursor',
			title = 'Cursor',
			subtitle = 'Appearance and feedback',
			placeholder = 'Search cursor settings...',
			disabled = function() return not BUI.IsModuleEnabled('cursor') end,
			enable = { get = function() return BUI.IsModuleEnabled('cursor') end, set = function(value) BUI.SetModuleEnabled('cursor', value) end },
			build = function(kit, main, width)
				return { BoardItem(kit, main, width, CursorBoard), BoardItem(kit, main, width, RingsBoard) }
			end,
			preview = {
				title = 'Live preview',
				caption = 'Move and click here to try it',
				action = { text = 'Reset to defaults', onClick = Reset },
				backgrounds = BACKGROUNDS,
				build = function(stage, kit) preview = BuildPreview(stage, kit) end,
			},
		})
		page:AutoRefresh()
	end,
})
