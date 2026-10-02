local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout, Modals, Theme = BUILib.Layout, BUILib.Modals, BUILib.Theme
local Pixel = BUI.Pixel

local PAGE_WIDTH = 960
local PREVIEW_HEIGHT = 112
local PREVIEW_PAD = 14
local PREVIEW_MIN_FONT = 6
local PREVIEW_TICK = 0.5
local MENU_WIDTH = 150
local TEXT_RANGE = 30
local MOCK_FILL = { 0.16, 0.17, 0.2, 1 }
local MOCK_PLAIN_FILL = { 0.11, 0.115, 0.13, 1 }
local MICRO_WIDTH, MICRO_HEIGHT, MICRO_COUNT, MICRO_OVERLAP = 32, 40, 13, -5
local BAG_SIZE, BAG_COUNT, BAG_GAP = 30, 6, 4
local BAG_BUTTON_NAMES = {
	'MainMenuBarBackpackButton', 'CharacterBag0Slot', 'CharacterBag1Slot', 'CharacterBag2Slot', 'CharacterBag3Slot', 'CharacterReagentBag0Slot',
}
local EMPTY_BUTTON_DEFAULT = BUI.Defaults.profile.actionBars.emptyButtonColor

local ANCHORS = {
	{ value = 'TOPLEFT', text = 'Top left' },
	{ value = 'TOP', text = 'Top' },
	{ value = 'TOPRIGHT', text = 'Top right' },
	{ value = 'LEFT', text = 'Left' },
	{ value = 'CENTER', text = 'Center' },
	{ value = 'RIGHT', text = 'Right' },
	{ value = 'BOTTOMLEFT', text = 'Bottom left' },
	{ value = 'BOTTOM', text = 'Bottom' },
	{ value = 'BOTTOMRIGHT', text = 'Bottom right' },
}
local GROWTHS = {
	{ value = 'TOPLEFT', text = 'Top left' },
	{ value = 'TOPRIGHT', text = 'Top right' },
	{ value = 'BOTTOMLEFT', text = 'Bottom left' },
	{ value = 'BOTTOMRIGHT', text = 'Bottom right' },
}
local PICKUP_KEYS = {
	{ value = 'SHIFT', text = 'Shift' },
	{ value = 'CTRL', text = 'Ctrl' },
	{ value = 'ALT', text = 'Alt' },
	{ value = 'NONE', text = 'Never' },
}
local MODIFIER_PAGES = {
	{ value = 0, text = 'Off' },
	{ value = 2, text = 'Page 2' },
	{ value = 3, text = 'Page 3, bar 4 slots' },
	{ value = 4, text = 'Page 4, bar 5 slots' },
	{ value = 5, text = 'Page 5, bar 3 slots' },
	{ value = 6, text = 'Page 6, bar 2 slots' },
}
local MODIFIERS = {
	{ key = 'ctrl', label = 'Ctrl page' },
	{ key = 'alt', label = 'Alt page' },
	{ key = 'shift', label = 'Shift page' },
}
local GLOW_STYLES = {
	{ value = 'proc', text = 'Proc' },
	{ value = 'pixel', text = 'Pixel' },
	{ value = 'autocast', text = 'Autocast' },
	{ value = 'button', text = 'Button' },
}
local TEXT_KINDS = {
	{ key = 'hotkey', title = 'Hotkey text', description = 'Keybind label on each button', sizeMax = 20 },
	{ key = 'count', title = 'Count text', description = 'Stack and charge counts', sizeMax = 20 },
	{ key = 'macro', title = 'Macro text', description = 'Macro and spell names along the bottom edge', sizeMax = 16 },
}
local ACTION_BAR_ROWS = { hotkeys = true, macroText = true, cooldownText = true, hideEmpty = true, clickThrough = true }
local CLICK_THROUGH_ROW = { clickThrough = true }
local EXTRA_BARS = {
	{ key = 'pet', title = 'Pet bar', description = 'Replaces the Blizzard pet bar. Turning it off needs a reload to bring the Blizzard one back.', selfTag = 'BUI_PetBar', buttons = true, maxButtons = 10, rows = { hotkeys = true, cooldownText = true, hideEmpty = true, clickThrough = true } },
	{ key = 'stance', title = 'Stance bar', description = 'Replaces the Blizzard stance and form bar. Turning it off needs a reload to bring the Blizzard one back.', selfTag = 'BUI_StanceBar', buttons = true, maxButtons = 10, countLabel = 'Max buttons, one per stance', rows = { hotkeys = true, cooldownText = true, clickThrough = true } },
	{ key = 'vehicle', title = 'Vehicle exit', description = 'One button to leave a vehicle, land a taxi early or cancel possession. Only shows when it can act.', size = true, rows = CLICK_THROUGH_ROW },
	{ key = 'micro', title = 'Micro menu', description = 'The Blizzard micro buttons on a bar you control.', micro = true, rows = CLICK_THROUGH_ROW },
	{ key = 'bags', title = 'Bag bar', description = 'The Blizzard bag buttons on a bar you control.', scaleOnly = true, rows = CLICK_THROUGH_ROW },
	{ key = 'extra', title = 'Extra action', description = 'The Blizzard extra action and zone ability buttons on a bar you control. Turning it off needs a reload to bring the Blizzard one back.', scaleOnly = true, rows = { clickThrough = true, blizzardArt = true } },
}
local EXTRA_BY_KEY = {}
for _, extra in ipairs(EXTRA_BARS) do EXTRA_BY_KEY[extra.key] = extra end

local selected = 'general'
local preview

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function Settings()
	return BUI.ActionBars.GetSettings()
end

local function RefreshPreview()
	if preview then preview:Update() end
end

local function Apply()
	BUI.ActionBars.Refresh()
	RefreshPreview()
end

local function SelectedKey()
	if selected == 'general' then return nil end
	local index = selected:match('^bar(%d+)$')
	return index and tonumber(index) or selected
end

local function Option(db, label, key, extra)
	local option = { label = label, get = function() return db[key] end, set = function(value) db[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Toggle(db, label, key)
	return { label = label, get = function() return db[key] == true end, set = function(value) db[key] = value end }
end

local function Color(db, label, key, opacity)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = opacity ~= false,
		get = function()
			local color = db[key]
			return color[1], color[2], color[3], color[4]
		end,
		set = function(red, green, blue, alpha) db[key] = { red, green, blue, alpha or 1 } end,
	}
end

local function TextPlacement(db, title, prefix)
	return { icon = 'location', tooltip = 'Anchor and offset', title = title, options = {
		Option(db, 'Anchor', prefix .. 'Anchor', { entries = ANCHORS }),
		Option(db, 'Horizontal', prefix .. 'OffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		Option(db, 'Vertical', prefix .. 'OffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
	} }
end

local function GeneralBoards(ui, parent, width)
	local db = Settings()
	local ActionBars = BUI.ActionBars
	local text = ui.Board(parent, width, {
		stacked = true,
		title = 'Button text',
		description = 'The labels drawn on every button.',
	})
	for _, kind in ipairs(TEXT_KINDS) do
		text:AddTools(kind.title, kind.description, {
			Color(db, kind.title .. ' color', kind.key .. 'Color'),
			{ icon = 'text', tooltip = 'Size', title = kind.title, options = { Option(db, 'Size', kind.key .. 'FontSize', { min = 6, max = kind.sizeMax, step = 1 }) } },
			TextPlacement(db, kind.title, kind.key),
		}, Apply)
	end
	text:AddTools('Cooldown text', 'Countdown on a button on cooldown, each bar turns it on and sets its size', {
		Color(db, 'Countdown color', 'cooldownColor'),
		{ tooltip = 'Decimals and the final seconds', title = 'Cooldown text', options = {
			Toggle(db, 'Decimals', 'showCooldownDecimals'),
			Option(db, 'Decimals under seconds', 'cooldownDecimalThreshold', { min = 1, max = 30, step = 1 }),
			Option(db, 'Warning under seconds', 'cooldownThreshold', { min = 0, max = 10, step = 1 }),
			Color(db, 'Warning color', 'cooldownThresholdColor'),
		} },
		TextPlacement(db, 'Cooldown text', 'cooldown'),
	}, Apply)
	text:AddTools('Item rank', 'Crafting quality badge on potions, flasks and other ranked items', {
		{ tooltip = 'Size', title = 'Item rank', options = { Option(db, 'Size', 'itemRankSize', { min = 8, max = 48, step = 1 }) } },
		TextPlacement(db, 'Item rank', 'itemRank'),
		Toggle(db, nil, 'showItemRank'),
	}, Apply)

	local look = ui.Board(parent, width, {
		stacked = true,
		title = 'Buttons',
		description = 'Borders, backgrounds and effects shared by every bar.',
	})
	look:AddTools('Border', 'Pixel outline around every button', {
		Color(db, 'Border color', 'borderColor'),
		{ tooltip = 'Thickness', title = 'Border', options = { Option(db, 'Thickness', 'borderSize', { min = 1, max = 4, step = 1 }) } },
	}, Apply)
	look:AddTools('Active pet ability', 'Outline on pet abilities that are autocasting or set as the active mode, follows the accent until you pick a color', {
		{ kind = 'swatch', tooltip = 'Active pet ability color',
			get = function()
				local chosen = db.petActiveColor
				if chosen then return chosen[1], chosen[2], chosen[3], 1 end
				local red, green, blue = Theme.GetAccent()
				return red, green, blue, 1
			end,
			set = function(red, green, blue) db.petActiveColor = { red, green, blue, 1 } end },
		{ icon = 'reset', tooltip = 'Follow the accent color again', onClick = function()
			db.petActiveColor = false
			Apply()
			Repaint()
		end },
	}, Apply)
	look:AddTools('Cooldown swipe', 'The dark sweep that drains while a cooldown runs', {
		Color(db, 'Swipe color', 'swipeColor'),
	}, Apply)
	look:AddTools('Empty buttons', 'Background behind slots with nothing in them', {
		Color(db, 'Background color', 'emptyButtonColor'),
		{ icon = 'reset', tooltip = 'Back to the default color', onClick = function()
			db.emptyButtonColor = { EMPTY_BUTTON_DEFAULT[1], EMPTY_BUTTON_DEFAULT[2], EMPTY_BUTTON_DEFAULT[3], EMPTY_BUTTON_DEFAULT[4] }
			Apply()
			Repaint()
		end },
		Toggle(db, nil, 'emptyButtonBackground'),
	}, Apply)
	look:AddTools('Key presses', 'Flash a button while its keybind is held', {
		Color(db, 'Flash color', 'pressColor', false),
		{ tooltip = 'Strength', title = 'Key presses', options = { Option(db, 'Flash opacity %', 'pressOpacity', { min = 5, max = 100, step = 1 }) } },
		Toggle(db, nil, 'showKeyPresses'),
	}, Apply)
	look:AddTools('Proc glow', 'Glow when a spell procs', {
		Color(db, 'Glow tint', 'procGlowColor', false),
		{ entries = GLOW_STYLES, width = MENU_WIDTH, get = function() return db.procGlowStyle end, set = function(value) db.procGlowStyle = value end },
		{ tooltip = 'Speed, lines and thickness', title = 'Proc glow', options = {
			Option(db, 'Speed %', 'procGlowSpeed', { min = 25, max = 400, step = 25 }),
			Option(db, 'Lines, pixel style', 'procGlowLines', { min = 4, max = 16, step = 1 }),
			Option(db, 'Thickness, pixel style', 'procGlowThickness', { min = 1, max = 5, step = 1 }),
		} },
		Toggle(db, nil, 'procGlow'),
	}, Apply)
	look:AddSwitch('Cast animation', function() return db.castAnimation == true end, function(value)
		db.castAnimation = value
		Apply()
	end, 'The Blizzard fill sweep and burst while a spell casts or channels')
	look:AddSwitch('Assisted combat', function() return db.showAssistedCombat == true end, function(value)
		db.showAssistedCombat = value
		Apply()
	end, 'The Blizzard rotation helper markers on the buttons')
	look:AddSwitch('Hide the micro menu', function() return db.microBar.hidden == true end, function(value)
		db.microBar.hidden = value
		Apply()
	end, 'Remove the Blizzard micro buttons entirely instead of carrying them on the Micro menu bar')
	look:AddSwitch('Hide the bag bar', function() return db.bagBar.hidden == true end, function(value)
		db.bagBar.hidden = value
		Apply()
	end, 'Remove the Blizzard bag buttons entirely instead of carrying them on the Bag bar')

	local control = ui.Board(parent, width, {
		stacked = true,
		title = 'Keybinds and moving',
		description = 'Binding keys, locking spells in place and dragging bars around.',
	})
	control:AddTools('Keybind mode', 'Hover any button and press a key or mouse button to bind it, Escape clears it. Also /bui keybind', {
		{ text = 'Start', onClick = ActionBars.ToggleKeybindMode },
	})
	control:AddTools('Lock buttons', 'Spells only leave a button while the pick-up key is held', {
		{ tooltip = 'Pick-up key', title = 'Lock buttons', options = { Option(db, 'Pick-up key', 'pickupKey', { entries = PICKUP_KEYS }) } },
		Toggle(db, nil, 'lockButtons'),
	}, Apply)
	control:AddTools('Unlock bars', 'Drag handles on every bar. Bars snap to each other and the screen edges, hold Shift to drag freely', {
		{ tooltip = 'Snapping', title = 'Moving bars', options = {
			Toggle(db, 'Snap while dragging', 'snapBars'),
			Option(db, 'Snap gap in pixels', 'snapGap', { min = 0, max = 12, step = 1 }),
		} },
		{ get = ActionBars.MoversUnlocked, set = ActionBars.SetMoversUnlocked },
	})
	return { text, look, control }
end

local function BarRows(ui, board, key, title, db, spec)
	local ActionBars = BUI.ActionBars
	local position = BUI.PositionTool(db, { selfTag = spec.selfTag })
	local layering = { Option(db, 'Layer', 'frameStrata', { entries = BUI.C.STRATA_OPTIONS }) }
	if spec.fill then table.insert(layering, 1, Option(db, 'Fill from', 'growth', { entries = GROWTHS })) end
	board:AddTools(title, spec.description, {
		position,
		{ tooltip = spec.fill and 'Fill direction and layer' or 'Layer', title = title, options = layering },
		{ icon = 'eye', tooltip = 'Preview and unlock just this bar to drag it', get = function() return ActionBars.BarUnlocked(key) end, set = function(value)
			ActionBars.SetBarUnlocked(key, value)
			Repaint()
		end },
		Toggle(db, nil, 'enabled'),
	}, Apply)
	if spec.buttons then
		board:AddTools('Buttons', 'How many, how big and how they are spaced, height 0 keeps buttons square', {
			{ tooltip = 'Count and rows', title = title, options = {
				Option(db, spec.countLabel or 'Buttons', 'buttonCount', { min = 1, max = spec.maxButtons, step = 1 }),
				Option(db, 'Per row', 'buttonsPerRow', { min = 1, max = spec.maxButtons, step = 1 }),
			} },
			{ icon = 'resize', tooltip = 'Size, spacing and scale', title = title, options = {
				Option(db, 'Button size', 'buttonSize', { min = 20, max = 64, step = 1 }),
				Option(db, 'Height', 'buttonHeight', { min = 0, max = 64, step = 1 }),
				Option(db, 'Spacing', 'spacing', { min = 0, max = 16, step = 1 }),
				Option(db, 'Scale %', 'scale', { min = 50, max = 200, step = 1 }),
			} },
		}, Apply)
	elseif spec.size then
		board:AddTools('Size', 'Button size and overall scale', {
			{ icon = 'resize', tooltip = 'Size and scale', title = title, options = {
				Option(db, 'Button size', 'buttonSize', { min = 24, max = 80, step = 1 }),
				Option(db, 'Scale %', 'scale', { min = 50, max = 200, step = 1 }),
			} },
		}, Apply)
	elseif spec.micro then
		board:AddTools('Arrangement', 'Buttons per row, spacing and scale, or a vertical stack', {
			{ icon = 'resize', tooltip = 'Rows, spacing and scale', title = title, options = {
				Option(db, 'Per row', 'buttonsPerRow', { min = 1, max = MICRO_COUNT, step = 1 }),
				Option(db, 'Spacing', 'spacing', { min = 0, max = 12, step = 1 }),
				Option(db, 'Scale %', 'scale', { min = 50, max = 200, step = 1 }),
				Toggle(db, 'Vertical', 'vertical'),
			} },
		}, Apply)
	elseif spec.scaleOnly then
		board:AddTools('Scale', 'Overall size of the buttons', {
			{ icon = 'resize', tooltip = 'Scale', title = title, options = { Option(db, 'Scale %', 'scale', { min = 50, max = 200, step = 1 }) } },
		}, Apply)
	end
	board:AddTools('Mouseover fade', 'Fade the bar out until the cursor is over it', {
		{ tooltip = 'Opacity and timing', title = 'Mouseover fade', options = {
			Option(db, 'Bar opacity %', 'alpha', { min = 10, max = 100, step = 1 }),
			Option(db, 'Faded opacity %', 'fadeAlpha', { min = 0, max = 100, step = 1 }),
			Toggle(db, 'Animated', 'fadeAnimated'),
			Option(db, 'Fade time in seconds', 'fadeDuration', { min = 0.05, max = 1, step = 0.05 }),
		} },
		Toggle(db, nil, 'fadeEnabled'),
	}, Apply)
	if spec.paging then
		local pages = {}
		for _, modifier in ipairs(MODIFIERS) do
			pages[#pages + 1] = Option(db.modifierPages, modifier.label, modifier.key, { entries = MODIFIER_PAGES })
		end
		board:AddTools('Page switching', spec.paging, {
			{ tooltip = 'Pages shown while a modifier is held', title = 'Modifier pages', options = pages },
			Toggle(db, nil, 'pagingEnabled'),
		}, Apply)
	end
end

local function ButtonsBoard(ui, parent, width, db, rows)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Buttons',
		description = 'What the buttons on this bar show.',
	})
	local function Cell(label, key, tip)
		board:AddSwitch(label, function() return db[key] == true end, function(value)
			db[key] = value
			Apply()
		end, tip)
	end
	if rows.hotkeys then Cell('Hotkeys', 'showHotkey', 'Keybind labels on this bar') end
	if rows.macroText then Cell('Macro text', 'showMacroText', 'Macro and spell names on this bar') end
	if rows.hideEmpty then Cell('Hide empty buttons', 'hideEmptyButtons', 'Collapse slots with nothing in them') end
	if rows.clickThrough then Cell('Click through', 'clickThrough', 'The mouse passes through this bar, keybinds still work, clicks and tooltips do not') end
	if rows.blizzardArt then Cell('Blizzard art', 'blizzardArt', 'Keep the Blizzard decorative frame around the buttons') end
	if rows.cooldownText then
		board:AddTools('Cooldown text', 'Countdown numbers on this bar', {
			{ icon = 'text', tooltip = 'Size', title = 'Cooldown text', options = { Option(db, 'Text size', 'cooldownFontSize', { min = 8, max = 24, step = 1 }) } },
			Toggle(db, nil, 'showCooldownText'),
		}, Apply)
	end
	return board
end

local function ActionBarBoards(ui, parent, width, index)
	local db = Settings().bars[index]
	local title = 'Bar ' .. index
	local board = ui.Board(parent, width, {
		stacked = true,
		title = title,
		description = 'Its keybinds follow the matching Blizzard bar, which is hidden while this is on. Turning it off needs a reload to bring the Blizzard one back.',
	})
	BarRows(ui, board, index, title, db, {
		selfTag = 'BUI_ActionBar' .. index,
		fill = true,
		buttons = true,
		maxButtons = 12,
		description = 'On or off, position, fill direction and layer',
		paging = index == 1 and 'Vehicles, stances, possession and the page arrows swap what this bar shows' or 'Stances, possession and the modifier pages swap what this bar shows',
	})
	return { board, ButtonsBoard(ui, parent, width, db, ACTION_BAR_ROWS) }
end

local function ExtraBoards(ui, parent, width, extra)
	local db = BUI.ActionBars.GetBarSettings(extra.key)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = extra.title,
		description = extra.description,
	})
	BarRows(ui, board, extra.key, extra.title, db, {
		selfTag = extra.selfTag,
		fill = extra.buttons,
		buttons = extra.buttons,
		maxButtons = extra.maxButtons,
		countLabel = extra.countLabel,
		size = extra.size,
		micro = extra.micro,
		scaleOnly = extra.scaleOnly,
		description = extra.buttons and 'On or off, position, fill direction and layer' or 'On or off, position and layer',
	})
	return { board, ButtonsBoard(ui, parent, width, db, extra.rows) }
end

local function MicroButtons()
	local list = {}
	if not MicroMenu then return list end
	for _, child in ipairs({ MicroMenu:GetChildren() }) do
		if child.layoutIndex and child:IsShown() then list[#list + 1] = child end
	end
	table.sort(list, function(left, right) return left.layoutIndex < right.layoutIndex end)
	return list
end

local function BagButtons()
	local list = {}
	for _, name in ipairs(BAG_BUTTON_NAMES) do
		local button = _G[name]
		if button and button:IsShown() then list[#list + 1] = button end
	end
	return list
end

local function LiveButtons(key)
	if key == 'micro' then return MicroButtons() end
	if key == 'bags' then return BagButtons() end
	local bar = BUI.ActionBars.bars[key]
	if not bar then return nil end
	local list = {}
	for _, button in ipairs(bar.buttons) do
		if button:IsShown() then list[#list + 1] = button end
	end
	return list
end

local function PreviewItems(key, db)
	local scale = db.scale / 100
	local live = LiveButtons(key)
	if key == 'micro' or key == 'bags' then
		local items = {}
		local fallbackWidth = key == 'micro' and MICRO_WIDTH or BAG_SIZE
		local fallbackHeight = key == 'micro' and MICRO_HEIGHT or BAG_SIZE
		local fallbackCount = key == 'micro' and MICRO_COUNT or BAG_COUNT
		local count = live and #live > 0 and #live or fallbackCount
		for index = 1, count do
			local real = live and live[index]
			local width, height = fallbackWidth, fallbackHeight
			if real then width, height = real:GetSize() end
			items[index] = { real = real, width = width or fallbackWidth, height = height or fallbackHeight }
		end
		local perRow = key == 'micro' and db.buttonsPerRow or count
		if key == 'micro' and db.vertical then perRow = 1 end
		local spacing = key == 'micro' and (MICRO_OVERLAP + db.spacing) or BAG_GAP
		return { items = items, perRow = perRow, spacing = spacing, scale = scale, plain = true }
	end
	local count = key == 'vehicle' and 1 or db.buttonCount
	if key == 'stance' then
		local forms = GetNumShapeshiftForms()
		if forms > 0 then count = math.min(count, forms) end
	end
	if live and #live > 0 then count = #live end
	count = math.max(1, count)
	local items = {}
	for index = 1, count do
		items[index] = { real = live and live[index], width = db.buttonSize, height = db.buttonSize }
	end
	return { items = items, perRow = db.buttonsPerRow, spacing = db.spacing, scale = scale, hotkeys = db.showHotkey, macro = db.showMacroText }
end

local function CreateMock(stage)
	local mock = CreateFrame('Frame', nil, stage)
	local fill = mock:CreateTexture(nil, 'BACKGROUND')
	fill:SetAllPoints()
	fill:SetTexture(BUI.C.FALLBACK_TEXTURE)
	local icon = mock:CreateTexture(nil, 'ARTWORK')
	icon:SetAllPoints()
	local font = BUI.GetAddonFont()
	local hotkey = mock:CreateFontString(nil, 'OVERLAY')
	local count = mock:CreateFontString(nil, 'OVERLAY')
	local macro = mock:CreateFontString(nil, 'OVERLAY')
	for _, fontString in ipairs({ hotkey, count, macro }) do
		Pixel.ApplyFont(fontString, PREVIEW_MIN_FONT, font, 'OUTLINE')
	end
	mock.fill, mock.icon, mock.hotkey, mock.count, mock.macro = fill, icon, hotkey, count, macro
	return mock
end

local function PlaceText(fontString, mock, db, prefix, scale, text)
	fontString:ClearAllPoints()
	Pixel.ApplyFont(fontString, math.max(PREVIEW_MIN_FONT, db[prefix .. 'FontSize'] * scale), BUI.GetAddonFont(), 'OUTLINE')
	local anchor = db[prefix .. 'Anchor']
	fontString:SetPoint(anchor, mock, anchor, db[prefix .. 'OffsetX'] * scale, db[prefix .. 'OffsetY'] * scale)
	local color = db[prefix .. 'Color']
	fontString:SetTextColor(color[1], color[2], color[3], color[4])
	fontString:SetText(text)
end

local function TextOf(fontString, show)
	if not show or not fontString then return '' end
	return fontString:GetText() or ''
end

local function MirrorArt(mock, real)
	local portrait = real and real.Portrait
	if portrait and portrait:IsShown() then
		SetPortraitTexture(mock.icon, 'player')
		mock.icon:SetTexCoord(portrait:GetTexCoord())
		mock.icon:SetVertexColor(portrait:GetVertexColor())
		mock.icon:Show()
		return true
	end
	local texture = real and real.icon
	if real and not texture and real.GetNormalTexture then
		texture = real:GetNormalTexture()
		if real.IsEnabled and not real:IsEnabled() and real.GetDisabledTexture and real:GetDisabledTexture() then
			texture = real:GetDisabledTexture()
		end
	end
	if not texture then return false end
	local atlas = texture.GetAtlas and texture:GetAtlas()
	if atlas then
		mock.icon:SetAtlas(atlas)
	else
		mock.icon:SetTexture(texture:GetTexture())
	end
	mock.icon:SetTexCoord(texture:GetTexCoord())
	mock.icon:SetVertexColor(texture:GetVertexColor())
	mock.icon:Show()
	return true
end

local function MirrorItem(mock, item, spec, db, scale)
	local real = item.real
	mock.hotkey:SetText('')
	mock.count:SetText('')
	mock.macro:SetText('')
	if spec.plain then
		Pixel.HideBorder(mock)
		if MirrorArt(mock, real) then
			mock.fill:Hide()
		else
			mock.icon:Hide()
			mock.fill:Show()
			mock.fill:SetVertexColor(unpack(MOCK_PLAIN_FILL))
			local border = Theme.border.light
			Pixel.ApplyBorder(mock, 1, border[1], border[2], border[3], border[4])
		end
		return
	end
	local hasAction = real ~= nil and real:HasAction()
	mock.fill:Show()
	if hasAction and MirrorArt(mock, real) then
		mock.fill:SetVertexColor(unpack(MOCK_FILL))
	else
		mock.icon:Hide()
		if real then
			mock.fill:SetVertexColor(BUI.ActionBars.EmptyButtonColor())
		else
			mock.fill:SetVertexColor(unpack(MOCK_FILL))
		end
	end
	if hasAction or db.emptyButtonBackground or not real then
		local borderColor = db.borderColor
		Pixel.ApplyBorder(mock, db.borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	else
		Pixel.HideBorder(mock)
	end
	if real then
		PlaceText(mock.hotkey, mock, db, 'hotkey', scale, TextOf(real.HotKey, spec.hotkeys))
		PlaceText(mock.count, mock, db, 'count', scale, TextOf(real.Count, true))
		PlaceText(mock.macro, mock, db, 'macro', scale, TextOf(real.Name, spec.macro))
	end
end

local function BuildPreview(band, kit)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetPoint('CENTER')
	stage:SetSize(1, 1)
	local mocks = {}
	local note = kit.Text(band, 'Pick a bar from the rail to see it here', 12, 'muted')
	note:SetPoint('CENTER')
	local elapsed = 0

	function band:Update()
		local key = SelectedKey()
		local db = key and BUI.ActionBars.GetBarSettings(key)
		note:SetShown(not db)
		stage:SetShown(db ~= nil)
		if not db then return end
		local settings = Settings()
		local spec = PreviewItems(key, db)
		local items = spec.items
		local perRow = math.max(1, math.min(spec.perRow or #items, #items))
		local rows = {}
		for index, item in ipairs(items) do
			local rowIndex = math.floor((index - 1) / perRow) + 1
			local row = rows[rowIndex]
			if not row then
				row = { width = 0, height = 0, items = {} }
				rows[rowIndex] = row
			end
			row.items[#row.items + 1] = item
			row.width = row.width + item.width + (#row.items > 1 and spec.spacing or 0)
			row.height = math.max(row.height, item.height)
		end
		local totalWidth, totalHeight = 0, 0
		for rowIndex, row in ipairs(rows) do
			totalWidth = math.max(totalWidth, row.width)
			totalHeight = totalHeight + row.height + (rowIndex > 1 and spec.spacing or 0)
		end
		local available = self:GetWidth() - PREVIEW_PAD * 2
		local fit = math.min(1, available / (totalWidth * spec.scale), (PREVIEW_HEIGHT - PREVIEW_PAD * 2) / (totalHeight * spec.scale))
		local scale = spec.scale * fit
		stage:SetSize(math.max(1, totalWidth * scale), math.max(1, totalHeight * scale))
		local mockIndex, y = 0, 0
		for rowIndex, row in ipairs(rows) do
			local x = 0
			for _, item in ipairs(row.items) do
				mockIndex = mockIndex + 1
				local mock = mocks[mockIndex]
				if not mock then
					mock = CreateMock(stage)
					mocks[mockIndex] = mock
				end
				local offsetY = (row.height - item.height) / 2
				mock:SetSize(item.width * scale, item.height * scale)
				mock:ClearAllPoints()
				mock:SetPoint('TOPLEFT', stage, 'TOPLEFT', x * scale, -(y + offsetY) * scale)
				MirrorItem(mock, item, spec, settings, scale)
				mock:Show()
				x = x + item.width + spec.spacing
			end
			y = y + row.height + (rowIndex < #rows and spec.spacing or 0)
		end
		for index = mockIndex + 1, #mocks do mocks[index]:Hide() end
	end
	band:SetScript('OnUpdate', function(self, delta)
		elapsed = elapsed + delta
		if elapsed < PREVIEW_TICK then return end
		elapsed = 0
		self:Update()
	end)
	band:HookScript('OnShow', function(self) self:Update() end)
	return band
end

local function Panes(ui, _, parent, width, item)
	if item.id == 'general' then return GeneralBoards(ui, parent, width) end
	local extra = EXTRA_BY_KEY[item.id]
	if extra then return ExtraBoards(ui, parent, width, extra) end
	return ActionBarBoards(ui, parent, width, tonumber(item.id:match('%d+')))
end

local function RailGroups()
	local bars = {}
	for index = 1, BUI.ActionBars.BAR_COUNT do
		bars[index] = { id = 'bar' .. index, label = 'Bar ' .. index }
	end
	local extras = {}
	for _, extra in ipairs(EXTRA_BARS) do extras[#extras + 1] = { id = extra.key, label = extra.title } end
	return {
		{ title = 'Settings', items = { { id = 'general', label = 'General', icon = 'cog' } } },
		{ title = 'Bars', items = bars },
		{ title = 'Other bars', items = extras },
	}
end

local function ConfirmModule(value)
	Modals.Confirm({
		parent = Window().frame,
		title = value and 'Turn on action bars' or 'Turn off action bars',
		message = 'This needs a reload of the interface. Reload now?',
		confirmText = 'Reload', cancelText = 'Cancel',
		onConfirm = function()
			BUI.SetModuleEnabled('actionBars', value)
			ReloadUI()
		end,
		onCancel = Repaint,
	})
end

BUI.PageEngine.RegisterPage('actionbars', {
	title = 'Action Bars',
	buttonText = 'Action Bars',
	icon = 'dashboard',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local tab = page:GetTab(1)
		local enabled = BUI.IsModuleEnabled('actionBars')
		local rail
		rail = Layout.RailPage(tab, { window = Window() }, {
			icon = 'dashboard',
			title = 'Action Bars',
			placeholder = 'Search action bar settings...',
			tools = {
				{ icon = 'enable', tooltip = 'Turn the action bars module on or off, needs a reload', get = function() return BUI.IsModuleEnabled('actionBars') end, set = ConfirmModule },
				{ icon = 'eye', tooltip = 'Unlock every bar to drag it, right-click a bar to lock again', get = function() return enabled and BUI.ActionBars.MoversUnlocked() end, set = function(value)
					if enabled then BUI.ActionBars.SetMoversUnlocked(value) end
					Repaint()
				end },
			},
			preview = enabled and { height = PREVIEW_HEIGHT, build = function(band, kit) preview = BuildPreview(band, kit) end } or nil,
			rail = { groups = enabled and RailGroups() or { { title = 'Settings', items = { { id = 'off', label = 'Module off' } } } }, selected = enabled and selected or 'off' },
			build = function(ui, shell, parent, width, item)
				if item.id == 'off' then
					local board = ui.Board(parent, width, { stacked = true, title = 'Action bars are off', description = 'Turn the module on with the cube in the header. It needs a reload.' })
					return { board }
				end
				return Panes(ui, shell, parent, width, item)
			end,
		})
		if not enabled then
			page:AutoRefresh()
			return
		end
		local Select = rail.Select
		function rail:Select(id)
			selected = id
			Select(self, id)
			Repaint()
			RefreshPreview()
		end
		pageFrame._selectModule = function(key) rail:Select(key) end
		BUI.ActionBars.OnMoversChanged('ActionBarsPage', Repaint)
		RefreshPreview()
		page:AutoRefresh()
	end,
})
