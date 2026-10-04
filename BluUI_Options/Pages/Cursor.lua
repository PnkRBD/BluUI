local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Layout, Modals = BUILib.Controls, BUILib.Layout, BUILib.Modals
local MouseCursor = BUI.MouseCursor
local RING_TEXTURE = BUI.C.CURSOR_RING_TEXTURE

local PAGE_WIDTH = 960
local SLIDER_WIDTH = 200
local DROPDOWN_WIDTH = 200
local TOP_ROW = 50
local TOP_GAP = 20
local TOP_DIVIDER_INSET = 10
local SIZE_LABEL = 100
local COLOR_SIZE = 26
local HEX_WIDTH = 88
local HEX_GAP = 8
local POINTER_SIZE = 18
local POINTER_TIP_X, POINTER_TIP_Y = 5, 2
local GCD_DURATION = 1.2
local CAST_DURATION = 1.8
local DISABLED_ALPHA = 0.3
local TILE_RING = 46
local EDITOR_HEAD = 58
local EDITOR_ICON = 30
local EDITOR_TEXT_X = 14

local RINGS = {
	{ key = 'main', name = 'Main ring', short = 'Main', about = 'Your primary cursor outline' },
	{ key = 'inner', name = 'Inner ring', short = 'Inner', about = 'Sits inside the main ring' },
	{ key = 'outer', name = 'Outer ring', short = 'Outer', about = 'Sits outside the main ring' },
}
local RING_BY_KEY = {}
for _, ring in ipairs(RINGS) do RING_BY_KEY[ring.key] = ring end

local function Scene(label, name)
	return { label = label, texture = BUI.C.MEDIA_PATH .. 'cursor_preview_' .. name .. '.tga', aspect = 1 }
end

local BACKGROUNDS = {
	Scene('Jungle ruins', 'jungle'),
	Scene('Molten', 'molten'),
	Scene('Fel', 'fel'),
	Scene('Silvermoon', 'silvermoon'),
	Scene('Garden', 'garden'),
	Scene('Void', 'void'),
	{ label = 'Dark' },
}

local BEHAVIORS = {
	{ value = 'static', text = 'Always visible' },
	{ value = 'click', text = 'On click' },
	{ value = 'gcd', text = 'GCD swipe' },
	{ value = 'cast', text = 'Cast progress' },
}

local opened = {}
local arts = {}
local selected = 'main'
local preview

local function Window()
	return BUI.PageEngine.window
end

local function Config()
	return BUI.GetDB().cursor
end

local function Slot()
	return Config().slots[selected]
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

local function BehaviorName(kind)
	for _, behavior in ipairs(BEHAVIORS) do
		if behavior.value == kind then return behavior.text end
	end
end

local function ParseHex(text)
	local digits = text:match('^%s*#?(%x%x%x%x%x%x)%s*$')
	if not digits then return end
	return tonumber(digits:sub(1, 2), 16) / 255, tonumber(digits:sub(3, 4), 16) / 255, tonumber(digits:sub(5, 6), 16) / 255
end

local function PickColor(Slot, anchor, sync)
	local slot = Slot()
	local red, green, blue, alpha = slot.colorR, slot.colorG, slot.colorB, slot.alpha
	Controls.OpenColorPicker({
		r = red, g = green, b = blue, a = alpha, hasOpacity = true, anchorTo = anchor,
		callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
			local current = Slot()
			if cancelled then
				current.colorR, current.colorG, current.colorB, current.alpha = red, green, blue, alpha
			else
				current.colorR, current.colorG, current.colorB, current.alpha = newRed, newGreen, newBlue, newAlpha
			end
			Restyle()
			sync()
		end,
	})
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
	local config = Config()
	return {
		{ text = 'Always shown', checked = not config.combatOnly, callback = function() SetCombatOnly(false) end },
		{ text = 'In combat only', checked = config.combatOnly, callback = function() SetCombatOnly(true) end },
		{ separator = true },
		{ text = 'Hide over BluUI windows', checked = config.hideOverMenus, callback = function(item)
			config.hideOverMenus = not config.hideOverMenus
			item.checked = config.hideOverMenus
			Changed()
			return true
		end },
	}
end

local function RingSummary(slot)
	return slot.enabled and BehaviorName(slot.kind) or 'Off'
end

local function TopCard(kit, parent)
	local card = kit.Card(parent)
	local row = CreateFrame('Frame', nil, card)
	row:SetHeight(TOP_ROW)
	row.search = 'cursor size visibility combat hide over bluui windows'
	kit.Text(row, 'Cursor size', 12, 'text'):SetPoint('LEFT')
	local slider = kit.Slider(row, SLIDER_WIDTH, {
		plain = true, min = 8, max = 160, step = 1,
		get = function() return Config().size end,
		set = function(value)
			Config().size = value
			Restyle()
		end,
	})
	slider:SetPoint('LEFT', SIZE_LABEL, 0)
	local divider = kit.Fill(row, 'cardEdge', 'ARTWORK')
	divider:SetSize(1, TOP_ROW - TOP_DIVIDER_INSET * 2)
	local visibility = kit.Select(row, {
		icon = 'eye',
		label = 'Visibility',
		stretch = true,
		value = function() return Config().combatOnly and 'In combat only' or 'Always shown' end,
		items = VisibilityItems,
	})
	visibility:SetPoint('RIGHT')
	function row:Measure(width)
		local half = math.floor(width / 2)
		slider:SetWidth(half - SIZE_LABEL - TOP_GAP)
		divider:SetPoint('LEFT', half, 0)
		visibility:SetPoint('LEFT', half + TOP_GAP, 0)
		return TOP_ROW
	end
	card:Add(row)
	return card
end

local function RingArt(kit, ring)
	return function(holder)
		local band = holder:CreateTexture(nil, 'ARTWORK')
		band:SetTexture(RING_TEXTURE)
		band:SetSize(TILE_RING, TILE_RING)
		band:SetPoint('CENTER')
		local function Update()
			local slot = Config().slots[ring.key]
			band:SetVertexColor(slot.colorR, slot.colorG, slot.colorB, slot.enabled and 1 or DISABLED_ALPHA)
		end
		arts[ring.key] = Update
		kit.Bind(holder, Update)
	end
end

local function RingPicker(kit, parent)
	local items = {}
	for _, ring in ipairs(RINGS) do
		items[#items + 1] = { key = ring.key, title = ring.short, sub = function() return RingSummary(Config().slots[ring.key]) end, art = RingArt(kit, ring) }
	end
	return kit.Tiles(parent, {
		items = items,
		search = 'rings main inner outer',
		selected = function() return selected end,
		onSelect = function(key)
			selected = key
			Window():Repaint()
		end,
	})
end

local function ColorField(kit, parent, sync)
	local field = CreateFrame('Frame', nil, parent)
	field:SetSize(COLOR_SIZE + HEX_GAP + HEX_WIDTH, COLOR_SIZE)
	field.swatch = kit.RoundSwatch(field, COLOR_SIZE, function(self) PickColor(Slot, self, sync) end)
	field.swatch:SetPoint('LEFT')
	field.hex = kit.Input(field, HEX_WIDTH, {
		placeholder = '#FFFFFF',
		get = function()
			local slot = Slot()
			return Layout.HexColor(slot.colorR, slot.colorG, slot.colorB)
		end,
		set = function(text)
			local red, green, blue = ParseHex(text)
			if red then
				local slot = Slot()
				slot.colorR, slot.colorG, slot.colorB = red, green, blue
				Restyle()
			end
			sync()
		end,
	})
	field.hex:SetPoint('LEFT', field.swatch, 'RIGHT', HEX_GAP, 0)
	return field
end

local function RingEditor(kit, parent)
	local card = kit.Card(parent)
	local head = CreateFrame('Frame', nil, card)
	head:SetHeight(EDITOR_HEAD)
	head.search = 'ring enable'
	local icon = head:CreateTexture(nil, 'ARTWORK')
	icon:SetTexture(RING_TEXTURE)
	icon:SetSize(EDITOR_ICON, EDITOR_ICON)
	icon:SetPoint('LEFT')
	local title = kit.Text(head, '', 14, 'text')
	title:SetPoint('BOTTOMLEFT', icon, 'RIGHT', EDITOR_TEXT_X, 1)
	local about = kit.Text(head, '', 12, 'muted')
	about:SetPoint('TOPLEFT', icon, 'RIGHT', EDITOR_TEXT_X, -3)
	kit.Switch(head, function() return Slot().enabled end, function(value)
		Slot().enabled = value
		Changed()
	end):SetPoint('RIGHT')
	card:Add(head)
	card:AddRule()

	local behavior = kit.Dropdown(card, DROPDOWN_WIDTH, function()
		local current = Slot().kind
		local items = {}
		for _, entry in ipairs(BEHAVIORS) do
			items[#items + 1] = { text = entry.text, checked = entry.value == current, callback = function()
				Slot().kind = entry.value
				Changed()
			end }
		end
		return items
	end)
	card:AddField('Behavior', behavior, true)

	local color
	local function Sync()
		local slot, ring = Slot(), RING_BY_KEY[selected]
		title:SetText(ring.name)
		about:SetText(ring.about)
		icon:SetVertexColor(slot.colorR, slot.colorG, slot.colorB, slot.enabled and 1 or DISABLED_ALPHA)
		color.swatch.fill:SetVertexColor(slot.colorR, slot.colorG, slot.colorB, slot.alpha)
		color.hex.edit:SetText(Layout.HexColor(slot.colorR, slot.colorG, slot.colorB))
		behavior.label:SetText(BehaviorName(slot.kind))
		arts[selected]()
	end
	color = ColorField(kit, card, Sync)
	card:AddField('Color', color)
	card:AddField('Size offset', kit.Slider(card, SLIDER_WIDTH, {
		plain = true, signed = true, min = -40, max = 80, step = 1,
		get = function() return Slot().offset end,
		set = function(value)
			Slot().offset = value
			Restyle()
		end,
	}), true)
	card:AddRule()
	local fineTune = card:Add(kit.Fold(card, {
		title = 'Fine-tune', icon = 'cog', chevron = 'right',
		open = opened.fineTune,
		onToggle = function(open) opened.fineTune = open end,
	}))
	fineTune.body:AddField('Layer', kit.Slider(fineTune.body, SLIDER_WIDTH, {
		plain = true, min = 1, max = 10, step = 1,
		get = function() return Slot().zOrder end,
		set = function(value)
			Slot().zOrder = value
			Restyle()
		end,
	}), true)

	kit.Bind(card, Sync)
	return card
end

local function Build(kit, parent)
	return { RingPicker(kit, parent), RingEditor(kit, parent) }
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
			enable = { get = function() return BUI.IsModuleEnabled('cursor') end, set = function(value) BUI.SetModuleEnabled('cursor', value) end },
			top = TopCard,
			build = Build,
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
