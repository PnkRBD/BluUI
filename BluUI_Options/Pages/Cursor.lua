local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Layout, Theme = BUILib.Controls, BUILib.Layout, BUILib.Theme
local MouseCursor = BUI.MouseCursor
local Pixel = BUI.Pixel
local RING_TEXTURE = BUI.C.CURSOR_RING_TEXTURE

local PAGE_WIDTH = 960
local PREVIEW_HEIGHT = 180
local STAGE_INSET = 12
local NAME_WIDTH = 220
local SLIDER_WIDTH = 220
local SWATCH_SIZE = 28
local MODE_COLUMN = 300
local MODE_WIDTH = 150
local OFFSET_COLUMN = 470
local OFFSET_WIDTH = 220
local LAYER_COLUMN = 710
local LAYER_WIDTH = 220
local LOOP_DURATION = 1.6
local LOOP_GAP = 0.3
local CLICK_SWIPE_DURATION = 1.0
local IDLE_CLICK_ALPHA = 0.35

local RINGS = {
	{ key = 'main', name = 'Main ring', sub = 'The base ring that follows the cursor' },
	{ key = 'inner', name = 'Inner ring', sub = 'Stacked inside the main ring' },
	{ key = 'outer', name = 'Outer ring', sub = 'Stacked outside the main ring' },
}

local MODES = {
	{ value = 'off', text = 'Off' },
	{ value = 'static', text = 'Static ring' },
	{ value = 'click', text = 'Click ring' },
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

local function RefreshPreview()
	if preview then preview:UpdateRing() end
end

local function Apply()
	MouseCursor.Apply()
	RefreshPreview()
end

local function ModeOf(slot)
	if not slot.enabled or slot.kind == 'none' then return 'off' end
	return slot.kind
end

local function ModeName(value)
	for _, mode in ipairs(MODES) do
		if mode.value == value then return mode.text end
	end
end

local function SetMode(slot, value)
	if value == 'off' then
		slot.enabled = false
	else
		slot.enabled = true
		slot.kind = value
	end
	Apply()
	Window():Repaint()
end

local function PickColor(slot, anchor)
	local red, green, blue, alpha = slot.colorR, slot.colorG, slot.colorB, slot.alpha
	Controls.OpenColorPicker({
		r = red, g = green, b = blue, a = alpha, hasOpacity = true, anchorTo = anchor,
		callback = function(newRed, newGreen, newBlue, newAlpha, cancelled)
			if cancelled then
				slot.colorR, slot.colorG, slot.colorB, slot.alpha = red, green, blue, alpha
			else
				slot.colorR, slot.colorG, slot.colorB, slot.alpha = newRed, newGreen, newBlue, newAlpha
			end
			Apply()
			Window():Repaint()
		end,
	})
end

local function BuildPreview(band)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetPoint('TOPLEFT', STAGE_INSET, -STAGE_INSET)
	stage:SetPoint('BOTTOMRIGHT', -STAGE_INSET, STAGE_INSET)
	stage:SetClipsChildren(true)

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
		widgets[ring.key] = { layer = layer, texture = texture, cooldown = cooldown, kind = 'off', nextLoop = 0 }
	end

	local dotLayer = CreateFrame('Frame', nil, holder)
	dotLayer:SetSize(1, 1)
	dotLayer:SetPoint('CENTER')
	dotLayer:SetFrameLevel(holderLevel + 20)
	local dot = dotLayer:CreateTexture(nil, 'OVERLAY')
	dot:SetTexture(BUILib.Widget.WHITE)
	dot:SetSize(Pixel.Scale(3), Pixel.Scale(3))
	dot:SetPoint('CENTER')
	local accentRed, accentGreen, accentBlue = Theme.GetAccent()
	dot:SetVertexColor(accentRed, accentGreen, accentBlue, 0.9)
	Theme.RegisterAccentElement(dot, function(element, red, green, blue) element:SetVertexColor(red, green, blue, 0.9) end)

	function band:UpdateRing()
		local config = Config()
		for _, ring in ipairs(RINGS) do
			local slot = config.slots[ring.key]
			local widget = widgets[ring.key]
			local mode = ModeOf(slot)
			widget.kind = mode
			widget.texture:Hide()
			widget.cooldown:Hide()
			if mode ~= 'off' then
				widget.nextLoop = 0
				widget.layer:SetFrameLevel(holderLevel + slot.zOrder)
				local diameter = Pixel.Scale(math.max(4, config.size + slot.offset))
				widget.texture:SetSize(diameter, diameter)
				widget.cooldown:SetSize(diameter, diameter)
				widget.cooldown:SetSwipeColor(slot.colorR, slot.colorG, slot.colorB, slot.alpha)
				if mode == 'static' then
					widget.texture:SetVertexColor(slot.colorR, slot.colorG, slot.colorB, slot.alpha)
					widget.texture:Show()
				elseif mode == 'click' then
					widget.texture:SetVertexColor(slot.colorR, slot.colorG, slot.colorB, slot.alpha * IDLE_CLICK_ALPHA)
					widget.texture:Show()
				else
					widget.cooldown:Show()
				end
			end
		end
	end

	local demoX, demoY, wasDown
	band:SetScript('OnUpdate', function(self, elapsed)
		local stageLeft, stageBottom = stage:GetLeft(), stage:GetBottom()
		local stageWidth, stageHeight = stage:GetWidth(), stage:GetHeight()
		if not stageLeft or stageWidth <= 0 then return end
		local targetX, targetY = stageWidth / 2, stageHeight / 2
		local over = self:IsMouseOver()
		if over then
			local scale = stage:GetEffectiveScale()
			local cursorX, cursorY = GetCursorPosition()
			cursorX, cursorY = cursorX / scale - stageLeft, cursorY / scale - stageBottom
			targetX = math.min(math.max(cursorX, 0), stageWidth)
			targetY = math.min(math.max(cursorY, 0), stageHeight)
		end
		local smoothing = 1 - math.exp(-14 * elapsed)
		demoX = demoX and (demoX + (targetX - demoX) * smoothing) or targetX
		demoY = demoY and (demoY + (targetY - demoY) * smoothing) or targetY
		holder:ClearAllPoints()
		holder:SetPoint('CENTER', stage, 'BOTTOMLEFT', demoX, demoY)

		local now = GetTime()
		local down = over and IsMouseButtonDown('LeftButton')
		for _, ring in ipairs(RINGS) do
			local widget = widgets[ring.key]
			if widget.kind == 'gcd' or widget.kind == 'cast' then
				if down and not wasDown and widget.kind == 'gcd' then
					widget.cooldown:SetCooldown(now, CLICK_SWIPE_DURATION)
					widget.nextLoop = now + CLICK_SWIPE_DURATION + LOOP_GAP
				elseif now >= widget.nextLoop then
					widget.cooldown:SetCooldown(now, LOOP_DURATION)
					widget.nextLoop = now + LOOP_DURATION + LOOP_GAP
				end
			elseif widget.kind == 'click' and down ~= wasDown then
				local slot = Config().slots[ring.key]
				widget.texture:SetVertexColor(slot.colorR, slot.colorG, slot.colorB, down and slot.alpha or slot.alpha * IDLE_CLICK_ALPHA)
			end
		end
		wasDown = down
	end)
	band:HookScript('OnShow', function(self) self:UpdateRing() end)
	band:UpdateRing()
	return band
end

local function CursorBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Cursor',
		description = 'Rings and cast feedback that follow the mouse. Everything here applies to the live cursor as you change it, and the preview above follows your mouse while you hover it.',
	})
	board:AddSwitch('Only in combat', function() return Config().combatOnly == true end, function(value)
		Config().combatOnly = value
		MouseCursor.Refresh()
		RefreshPreview()
	end)
	board:AddSwitch('Hide over BluUI windows', function() return Config().hideOverMenus == true end, function(value)
		Config().hideOverMenus = value
		Apply()
	end)
	ui.Slider(board:AddRow('Ring size', 'Diameter before each ring adds its own offset', SLIDER_WIDTH), SLIDER_WIDTH, {
		min = 8, max = 160, step = 1,
		get = function() return Config().size end,
		set = function(value)
			Config().size = value
			Apply()
		end,
	}):SetPoint('RIGHT', -ui.ROW_INSET, 0)
	return board
end

local function RingsSection(ui, parent, width)
	local section = ui.Section(parent, width, {
		stacked = true,
		title = 'Rings',
		description = 'Three rings share the cursor. Each one picks what it shows, how far it sits from the ring size, and which draws on top.',
		columns = { { 'Ring', ui.AVATAR_X }, { 'Shows', MODE_COLUMN }, { 'Size offset', OFFSET_COLUMN }, { 'Layer', LAYER_COLUMN } },
	})
	for _, ring in ipairs(RINGS) do
		local slot = Config().slots[ring.key]
		local row = section:AddRow(ring.name .. ' ' .. ring.sub)
		local swatch = ui.Swatch(row, SWATCH_SIZE, function(self) PickColor(slot, self) end)
		swatch:SetPoint('LEFT', ui.AVATAR_X, 0)
		ui.RowTitle(row, ring.name, ring.sub, ui.NAME_X, NAME_WIDTH)
		local dropdown = ui.Dropdown(row, MODE_WIDTH, function()
			local current = ModeOf(slot)
			local items = {}
			for _, mode in ipairs(MODES) do
				items[#items + 1] = { text = mode.text, checked = mode.value == current, callback = function() SetMode(slot, mode.value) end }
			end
			return items
		end)
		dropdown:SetPoint('LEFT', MODE_COLUMN, 0)
		ui.Slider(row, OFFSET_WIDTH, {
			min = -40, max = 80, step = 1,
			get = function() return slot.offset end,
			set = function(value)
				slot.offset = value
				Apply()
			end,
		}):SetPoint('LEFT', OFFSET_COLUMN, 0)
		ui.Slider(row, LAYER_WIDTH, {
			min = 1, max = 10, step = 1,
			get = function() return slot.zOrder end,
			set = function(value)
				slot.zOrder = value
				Apply()
			end,
		}):SetPoint('LEFT', LAYER_COLUMN, 0)
		ui.Bind(row, function()
			swatch.fill:SetVertexColor(slot.colorR, slot.colorG, slot.colorB, slot.alpha)
			dropdown.label:SetText(ModeName(ModeOf(slot)))
		end)
	end
	return section
end

local function Sections(ui, _, parent, width)
	return { CursorBoard(ui, parent, width), RingsSection(ui, parent, width) }
end

BUI.PageEngine.RegisterPage('cursor', {
	title = 'Cursor',
	buttonText = 'Cursor',
	icon = 'cursor',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'cursor',
			title = 'Cursor',
			placeholder = 'Search cursor settings...',
			toggles = {
				{ icon = 'enable', tooltip = 'Turn the cursor module on or off', get = function() return BUI.IsModuleEnabled('cursor') end, set = function(value) BUI.SetModuleEnabled('cursor', value) end },
			},
			preview = { height = PREVIEW_HEIGHT, build = function(band) preview = BuildPreview(band) end },
			tabs = { { label = 'Cursor', build = Sections } },
		})
		page:AutoRefresh()
	end,
})
