local BUI = BluUI
local SetScript, HookScript = BUI.Prof.Scripts('Pages.ActionBars')

local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals = BUILib.Controls, BUILib.Layout, BUILib.Modals
local PageKit = BUILib.PageKit
local Widget = BUILib.Widget
local Theme = BUILib.Theme
local Pixel = BUI.Pixel

local LIST_WIDTH = 180
local CONTENT_WIDTH = Layout.PAGE_CONTENT_W
local DETAIL_WIDTH = CONTENT_WIDTH - LIST_WIDTH - 60
local PREVIEW_HEIGHT = 112
local PREVIEW_PAD = 14
local PREVIEW_MIN_FONT = 6
local PREVIEW_TICK = 0.5
local MOCK_FILL = { 0.16, 0.17, 0.2, 1 }
local MOCK_PLAIN_FILL = { 0.11, 0.115, 0.13, 1 }
local MICRO_WIDTH, MICRO_HEIGHT, MICRO_COUNT, MICRO_OVERLAP = 32, 40, 13, -5
local BAG_SIZE, BAG_COUNT, BAG_GAP = 30, 6, 4
local BAG_BUTTON_NAMES = {
	'MainMenuBarBackpackButton', 'CharacterBag0Slot', 'CharacterBag1Slot', 'CharacterBag2Slot', 'CharacterBag3Slot', 'CharacterReagentBag0Slot',
}
local STANCE_PREVIEW_FALLBACK = 3
local EMPTY_BUTTON_DEFAULT = BUI.Defaults.profile.actionBars.emptyButtonColor
local STRATA_ITEMS = BUI.C.STRATA_OPTIONS

local ANCHOR_ITEMS = {
	{ value = 'TOPLEFT', text = 'Top Left' },
	{ value = 'TOP', text = 'Top' },
	{ value = 'TOPRIGHT', text = 'Top Right' },
	{ value = 'LEFT', text = 'Left' },
	{ value = 'CENTER', text = 'Center' },
	{ value = 'RIGHT', text = 'Right' },
	{ value = 'BOTTOMLEFT', text = 'Bottom Left' },
	{ value = 'BOTTOM', text = 'Bottom' },
	{ value = 'BOTTOMRIGHT', text = 'Bottom Right' },
}

local GROWTH_ITEMS = {
	{ value = 'TOPLEFT', text = 'Top Left' },
	{ value = 'TOPRIGHT', text = 'Top Right' },
	{ value = 'BOTTOMLEFT', text = 'Bottom Left' },
	{ value = 'BOTTOMRIGHT', text = 'Bottom Right' },
}

local PICKUP_ITEMS = {
	{ value = 'SHIFT', text = 'Shift' },
	{ value = 'CTRL', text = 'Ctrl' },
	{ value = 'ALT', text = 'Alt' },
	{ value = 'NONE', text = 'Never' },
}

local MODIFIER_PAGE_ITEMS = {
	{ value = 0, text = 'Off' },
	{ value = 2, text = 'Page 2' },
	{ value = 3, text = 'Page 3 (Bar 4 slots)' },
	{ value = 4, text = 'Page 4 (Bar 5 slots)' },
	{ value = 5, text = 'Page 5 (Bar 3 slots)' },
	{ value = 6, text = 'Page 6 (Bar 2 slots)' },
}

local MODIFIERS = {
	{ key = 'ctrl', label = 'Ctrl Page' },
	{ key = 'alt', label = 'Alt Page' },
	{ key = 'shift', label = 'Shift Page' },
}

local TEXT_KINDS = {
	{ key = 'hotkey', title = 'Hotkey Text', desc = 'Keybind label on each button.', sizeMax = 20 },
	{ key = 'count', title = 'Count Text', desc = 'Stack and charge counts.', sizeMax = 20 },
	{ key = 'macro', title = 'Macro Text', desc = 'Macro and spell names along the bottom edge.', sizeMax = 16 },
}

local ACTION_BAR_ROWS = { hotkeys = true, macroText = true, cooldownText = true, hideEmpty = true, clickThrough = true }
local CLICK_THROUGH_ROW = { clickThrough = true }

local EXTRA_PAGES = {
	{
		key = 'pet', title = 'Pet Bar', desc = "Replaces Blizzard's pet bar. Turning it off needs a reload to bring Blizzard's back.",
		selfTag = 'BUI_PetBar', buttons = true, maxButtons = 10, rows = { hotkeys = true, cooldownText = true, hideEmpty = true, clickThrough = true },
	},
	{
		key = 'stance', title = 'Stance Bar', desc = "Replaces Blizzard's stance and form bar. Turning it off needs a reload to bring Blizzard's back.",
		selfTag = 'BUI_StanceBar', buttons = true, maxButtons = 10, rows = { hotkeys = true, cooldownText = true, clickThrough = true },
	},
	{
		key = 'vehicle', title = 'Vehicle Exit', desc = 'One button to leave a vehicle, land a taxi early, or cancel possession. Only shows when it can act.',
		size = true, rows = CLICK_THROUGH_ROW,
	},
	{
		key = 'micro', title = 'Micro Menu', desc = "Blizzard's micro buttons on a bar you control.",
		micro = true, rows = CLICK_THROUGH_ROW,
	},
	{
		key = 'bags', title = 'Bag Bar', desc = "Blizzard's bag buttons on a bar you control.",
		scaleOnly = true, rows = CLICK_THROUGH_ROW,
	},
	{
		key = 'extra', title = 'Extra Action', desc = "Blizzard's extra action and zone ability buttons on a bar you control.",
		scaleOnly = true, scaleDesc = 'Overall size of the extra action buttons.', rows = { clickThrough = true, blizzardArt = true },
	},
}

local AddRow = PageKit.AddSettingRow
local GLOW_STYLE_ITEMS = {
	{ value = 'proc',     text = 'Proc' },
	{ value = 'pixel',    text = 'Pixel' },
	{ value = 'autocast', text = 'Autocast' },
	{ value = 'button',   text = 'Button' },
}

local function StoreOption(store, apply, kind, label, key, extra)
	local option = {
		kind = kind, label = label,
		get = function() return store[key] end,
		set = function(value) store[key] = value; apply() end,
	}
	for optionKey, value in pairs(extra or {}) do option[optionKey] = value end
	return option
end

local function StoreSwatch(parent, store, apply, key, tooltip, hasOpacity)
	local color = store[key]
	return Controls.ColorSwatch(parent, {
		r = color[1], g = color[2], b = color[3], a = color[4], hasOpacity = hasOpacity ~= false, tooltip = tooltip,
		callback = function(red, green, blue, alpha) store[key] = { red, green, blue, alpha or 1 }; apply() end,
	})
end

local previewEyes = {}

local function PreviewEye(row, key)
	local eye = Controls.IconToggle(row, BUI.ActionBars.BarUnlocked(key), function(value)
		BUI.ActionBars.SetBarUnlocked(key, value)
	end, { texture = BUILib.GetLibMedia('eye'), tooltip = 'Preview and unlock this bar to drag it' })
	previewEyes[key] = eye
	return eye
end

local function SyncPreviewEyes()
	for key, eye in pairs(previewEyes) do
		eye:SetValue(BUI.ActionBars.BarUnlocked(key))
	end
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

local function PreviewItems(key, barSettings)
	local scale = barSettings.scale / 100
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
		local perRow = key == 'micro' and barSettings.buttonsPerRow or count
		if key == 'micro' and barSettings.vertical then perRow = 1 end
		local spacing = key == 'micro' and (MICRO_OVERLAP + barSettings.spacing) or BAG_GAP
		return { items = items, perRow = perRow, spacing = spacing, scale = scale, plain = true }
	end
	local count = key == 'vehicle' and 1 or barSettings.buttonCount
	if key == 'stance' then
		local forms = GetNumShapeshiftForms()
		count = math.min(count, forms > 0 and forms or STANCE_PREVIEW_FALLBACK)
	end
	if live and #live > 0 then count = #live end
	count = math.max(1, count)
	local size = barSettings.buttonSize
	local items = {}
	for index = 1, count do
		items[index] = { real = live and live[index], width = size, height = size }
	end
	return {
		items = items, perRow = barSettings.buttonsPerRow, spacing = barSettings.spacing, scale = scale,
		hotkeys = barSettings.showHotkey, macro = barSettings.showMacroText,
	}
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

local function PlaceText(fontString, mock, settings, prefix, scale, text)
	fontString:ClearAllPoints()
	Pixel.ApplyFont(fontString, math.max(PREVIEW_MIN_FONT, settings[prefix .. 'FontSize'] * scale), BUI.GetAddonFont(), 'OUTLINE')
	local anchor = settings[prefix .. 'Anchor']
	fontString:SetPoint(anchor, mock, anchor, settings[prefix .. 'OffsetX'] * scale, settings[prefix .. 'OffsetY'] * scale)
	local color = settings[prefix .. 'Color']
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

local function MirrorItem(mock, item, spec, settings, scale)
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
	if hasAction or settings.emptyButtonBackground or not real then
		local borderColor = settings.borderColor
		Pixel.ApplyBorder(mock, settings.borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	else
		Pixel.HideBorder(mock)
	end
	if real then
		PlaceText(mock.hotkey, mock, settings, 'hotkey', scale, TextOf(real.HotKey, spec.hotkeys))
		PlaceText(mock.count, mock, settings, 'count', scale, TextOf(real.Count, true))
		PlaceText(mock.macro, mock, settings, 'macro', scale, TextOf(real.Name, spec.macro))
	end
end

local function CreatePreview(tab, key)
	local card = CreateFrame('Frame', nil, tab.child)
	card:SetSize(tab.width, PREVIEW_HEIGHT)
	Widget.RoundedPanel(card, 8, Theme.bg.card, Theme.border.light)
	local stage = CreateFrame('Frame', nil, card)
	stage:SetPoint('CENTER')
	stage:SetSize(1, 1)
	card.stage, card.mocks, card.key, card.elapsed = stage, {}, key, 0
	Layout.Add(tab, card, 8)

	function card:Render()
		local settings = BUI.ActionBars.GetSettings()
		local barSettings = BUI.ActionBars.GetBarSettings(self.key)
		if not barSettings then return end
		local spec = PreviewItems(self.key, barSettings)
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
		self.stage:SetSize(math.max(1, totalWidth * scale), math.max(1, totalHeight * scale))
		local mockIndex, y = 0, 0
		for rowIndex, row in ipairs(rows) do
			local x = 0
			for _, item in ipairs(row.items) do
				mockIndex = mockIndex + 1
				local mock = self.mocks[mockIndex]
				if not mock then
					mock = CreateMock(self.stage)
					self.mocks[mockIndex] = mock
				end
				local offsetY = (row.height - item.height) / 2
				mock:SetSize(item.width * scale, item.height * scale)
				mock:ClearAllPoints()
				mock:SetPoint('TOPLEFT', self.stage, 'TOPLEFT', x * scale, -(y + offsetY) * scale)
				MirrorItem(mock, item, spec, settings, scale)
				mock:Show()
				x = x + item.width + spec.spacing
			end
			y = y + row.height + (rowIndex < #rows and spec.spacing or 0)
		end
		for index = mockIndex + 1, #self.mocks do
			self.mocks[index]:Hide()
		end
	end

	SetScript(card, 'OnUpdate', function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if self.elapsed < PREVIEW_TICK then return end
		self.elapsed = 0
		self:Render()
	end)

	card:Render()
	return card
end

local function BuildGeneral(tab, settings, Apply)
	local function Option(kind, label, key, extra) return StoreOption(settings, Apply, kind, label, key, extra) end
	local function Toggle(key)
		return {
			checked = settings[key],
			callback = function(value) settings[key] = value; Apply() end,
		}
	end
	local function Row(config, toggle)
		if toggle then config.checked, config.callback = toggle.checked, toggle.callback end
		return AddRow(tab, config)
	end
	local function PositionIcon(row, title, prefix)
		return PageKit.PositionIcon(row, { title = title, tooltip = 'Anchor & offset', options = {
			Option('dropdown', 'Anchor', prefix .. 'Anchor', { items = ANCHOR_ITEMS }),
			Option('slider', 'Offset X', prefix .. 'OffsetX', { min = -30, max = 30 }),
			Option('slider', 'Offset Y', prefix .. 'OffsetY', { min = -30, max = 30 }),
		} })
	end

	Layout.Section(tab, 'Button Text')
	for _, textKind in ipairs(TEXT_KINDS) do
		Row({
			title = textKind.title, description = textKind.desc, plain = true, accessoryWidth = 92,
			accessories = function(row)
				local position = PositionIcon(row, textKind.title:upper() .. ' POSITION', textKind.key)
				local cog = PageKit.SettingsIcon(row, { title = textKind.title:upper(), tooltip = 'Size', options = {
					Option('slider', 'Size', textKind.key .. 'FontSize', { min = 6, max = textKind.sizeMax }),
				} })
				return { position, cog, StoreSwatch(row, settings, Apply, textKind.key .. 'Color', textKind.title .. ' color') }
			end,
		})
	end
	Row({
		title = 'Cooldown Text', description = 'Countdown numbers on a button on cooldown. Each bar turns them on or off and sets their size. The cog adds decimals and recolors the last few seconds.', plain = true, accessoryWidth = 96,
		accessories = function(row)
			local cog = PageKit.SettingsIcon(row, { title = 'COOLDOWN TEXT', tooltip = 'Decimals and the final-seconds color', options = {
				Option(nil, 'Show Decimals', 'showCooldownDecimals'),
				Option('slider', 'Decimal Threshold', 'cooldownDecimalThreshold', { min = 1, max = 30 }),
				Option('slider', 'Warning Seconds', 'cooldownThreshold', { min = 0, max = 10 }),
				Option('swatch', 'Warning Color', 'cooldownThresholdColor'),
			} })
			return { PositionIcon(row, 'COOLDOWN TEXT POSITION', 'cooldown'), cog, StoreSwatch(row, settings, Apply, 'cooldownColor', 'Countdown color') }
		end,
	})
	Row({
		title = 'Item Rank', description = 'Crafting quality badge on potions, flasks and other ranked items.', accessoryWidth = 64,
		accessories = function(row)
			local position = PositionIcon(row, 'ITEM RANK POSITION', 'itemRank')
			local cog = PageKit.SettingsIcon(row, { title = 'ITEM RANK', tooltip = 'Badge size', options = {
				Option('slider', 'Size', 'itemRankSize', { min = 8, max = 48 }),
			} })
			return { position, cog }
		end,
	}, Toggle('showItemRank'))

	Layout.Section(tab, 'Appearance')
	Row({
		title = 'Border', description = 'Pixel outline around every button.', plain = true, accessoryWidth = 60,
		accessories = function(row)
			local cog = PageKit.SettingsIcon(row, { title = 'BORDER', tooltip = 'Border thickness', options = {
				Option('slider', 'Border Size', 'borderSize', { min = 1, max = 4 }),
			} })
			return { cog, StoreSwatch(row, settings, Apply, 'borderColor', 'Border color') }
		end,
	})
	Row({
		title = 'Pet Active Border', description = 'Outline on pet abilities that are autocasting or set as the active mode. Follows the accent until you pick a color.', plain = true, accessoryWidth = 64,
		accessories = function(row)
			local red, green, blue = Theme.GetAccent()
			local chosen = settings.petActiveColor
			if chosen then red, green, blue = chosen[1], chosen[2], chosen[3] end
			local swatch = Controls.ColorSwatch(row, {
				r = red, g = green, b = blue, a = 1, hasOpacity = false, tooltip = 'Active pet ability border color',
				callback = function(newRed, newGreen, newBlue) settings.petActiveColor = { newRed, newGreen, newBlue, 1 }; Apply() end,
			})
			local reset = Controls.Icon(row, {
				texture = BUILib.GetLibMedia('reset'), tooltip = 'Follow the accent color',
				onClick = function()
					settings.petActiveColor = false
					local accentRed, accentGreen, accentBlue = Theme.GetAccent()
					Widget.Unwrap(swatch):SetColor(accentRed, accentGreen, accentBlue, 1)
					Apply()
				end,
			})
			return { reset, swatch }
		end,
	})
	Row({
		title = 'Cooldown Swipe', description = 'Color and opacity of the dark sweep that drains while a cooldown runs.', plain = true, accessoryWidth = 36,
		accessories = function(row) return { StoreSwatch(row, settings, Apply, 'swipeColor', 'Swipe color & opacity') } end,
	})
	Row({
		title = 'Empty Buttons', description = 'Background color and opacity behind slots with nothing in them.', accessoryWidth = 64,
		accessories = function(row)
			local swatch = StoreSwatch(row, settings, Apply, 'emptyButtonColor', 'Background color & opacity')
			local reset = Controls.Icon(row, {
				texture = BUILib.GetLibMedia('reset'), tooltip = 'Reset to default',
				onClick = function()
					settings.emptyButtonColor = { EMPTY_BUTTON_DEFAULT[1], EMPTY_BUTTON_DEFAULT[2], EMPTY_BUTTON_DEFAULT[3], EMPTY_BUTTON_DEFAULT[4] }
					Widget.Unwrap(swatch):SetColor(EMPTY_BUTTON_DEFAULT[1], EMPTY_BUTTON_DEFAULT[2], EMPTY_BUTTON_DEFAULT[3], EMPTY_BUTTON_DEFAULT[4])
					Apply()
				end,
			})
			return { reset, swatch }
		end,
	}, Toggle('emptyButtonBackground'))
	Row({
		title = 'Key Presses', description = 'Flash a button while its keybind is held.', accessoryWidth = 64,
		accessories = function(row)
			local cog = PageKit.SettingsIcon(row, { title = 'KEY PRESSES', tooltip = 'Flash strength', options = {
				Option('slider', 'Flash Opacity %', 'pressOpacity', { min = 5, max = 100 }),
			} })
			return { cog, StoreSwatch(row, settings, Apply, 'pressColor', 'Flash color', false) }
		end,
	}, Toggle('showKeyPresses'))

	Layout.Section(tab, 'Effects')
	Row({
		title = 'Proc Glow', description = 'Glow when a spell procs. Pick the style, then shape and tint it.', accessoryWidth = 220,
		accessories = function(row)
			local styleDropdown = Controls.Dropdown(row, nil, GLOW_STYLE_ITEMS, settings.procGlowStyle, function(value)
				settings.procGlowStyle = value; Apply()
			end, nil, 120)
			local cog = PageKit.SettingsIcon(row, { title = 'GLOW SHAPE', tooltip = 'Speed, lines & thickness', options = {
				Option('slider', 'Speed %', 'procGlowSpeed', { min = 25, max = 400, step = 25 }),
				Option('slider', 'Lines (Pixel)', 'procGlowLines', { min = 4, max = 16 }),
				Option('slider', 'Thickness (Pixel)', 'procGlowThickness', { min = 1, max = 5 }),
			} })
			return { styleDropdown, cog, StoreSwatch(row, settings, Apply, 'procGlowColor', 'Glow tint', false) }
		end,
	}, Toggle('procGlow'))
	Row({ title = 'Cast Animation', description = "Blizzard's fill sweep and burst while a spell casts or channels." }, Toggle('castAnimation'))
	Row({ title = 'Assisted Combat', description = "Blizzard's rotation helper markers on the buttons." }, Toggle('showAssistedCombat'))

	Layout.Section(tab, 'Blizzard')
	Row({
		title = 'Hide Micro Menu', description = "Remove Blizzard's micro buttons entirely instead of carrying them on the Micro Menu bar.",
		checked = settings.microBar.hidden,
		callback = function(value) settings.microBar.hidden = value; Apply() end,
	})
	Row({
		title = 'Hide Bag Bar', description = "Remove Blizzard's bag buttons entirely instead of carrying them on the Bag Bar.",
		checked = settings.bagBar.hidden,
		callback = function(value) settings.bagBar.hidden = value; Apply() end,
	})

	Layout.Section(tab, 'Keybinds')
	Row({
		title = 'Keybind Mode', description = 'Hover any button and press a key or mouse button to bind it. Escape clears the hovered button. Also /bui keybind.',
		plain = true, accessoryWidth = 76,
		accessories = function(row)
			return { Controls.Button(row, 'Start', 70, function() BUI.ActionBars.ToggleKeybindMode() end) }
		end,
	})

	Layout.Section(tab, 'Locking & Moving')
	Row({
		title = 'Lock Buttons', description = 'Spells only leave a button while the pick-up key is held.', accessoryWidth = 36,
		accessories = function(row)
			return { PageKit.SettingsIcon(row, { title = 'LOCK BUTTONS', tooltip = 'Pick-up key', options = {
				{ kind = 'dropdown', label = 'Pick-up Key', items = PICKUP_ITEMS,
				  get = function() return settings.pickupKey end,
				  set = function(value) settings.pickupKey = value; Apply() end },
			} }) }
		end,
	}, Toggle('lockButtons'))
	return Row({
		title = 'Unlock Bars', description = 'Drag handles on every bar. Bars snap to each other and to the screen edges; hold Shift to drag freely.',
		checked = BUI.ActionBars.MoversUnlocked(),
		callback = function(value) BUI.ActionBars.SetMoversUnlocked(value) end,
		accessoryWidth = 36,
		accessories = function(row)
			return { PageKit.SettingsIcon(row, { title = 'MOVING BARS', tooltip = 'Snapping', options = {
				{ label = 'Snap While Dragging', get = function() return settings.snapBars end, set = function(value) settings.snapBars = value end },
				{ kind = 'slider', label = 'Snap Gap (px)', min = 0, max = 12, get = function() return settings.snapGap end, set = function(value) settings.snapGap = value end },
			} }) }
		end,
	})
end

local function BarPageKit(tab, key, title, barSettings, Apply)
	local kit = { rows = {} }

	function kit.Option(kind, label, optionKey, extra)
		return StoreOption(barSettings, Apply, kind, label, optionKey, extra)
	end

	function kit.Row(config)
		local row = AddRow(tab, config)
		kit.rows[#kit.rows + 1] = row
		return row
	end

	function kit.ToggleRow(rowTitle, description, settingKey)
		return kit.Row({
			title = rowTitle, description = description,
			checked = barSettings[settingKey],
			callback = function(value) barSettings[settingKey] = value; Apply() end,
		})
	end

	function kit.SyncDim()
		for _, row in ipairs(kit.rows) do Widget.Unwrap(row):SetRowEnabled(barSettings.enabled) end
	end

	function kit.EnabledRow(description)
		AddRow(tab, {
			title = 'Enabled', description = description,
			checked = barSettings.enabled,
			callback = function(value)
				barSettings.enabled = value
				Apply()
				kit.SyncDim()
			end,
		})
	end

	function kit.PositionRow(selfTag, includeFill)
		kit.Row({
			title = 'Position', plain = true, accessoryWidth = 92,
			description = 'Screen position or anchor frame. The eye previews and unlocks just this bar; the cog holds centering' .. (includeFill and ', fill direction' or '') .. ' and strata.',
			accessories = function(row)
				local options = {
					{ label = 'Center Horizontally',
					  get = function() return barSettings.centerHorizontally end,
					  set = function(value)
						  barSettings.centerHorizontally = value
						  if value then barSettings.posX = 0 end
						  Apply()
					  end },
				}
				if includeFill then options[#options + 1] = kit.Option('dropdown', 'Fill From', 'growth', { items = GROWTH_ITEMS }) end
				options[#options + 1] = kit.Option('dropdown', 'Strata', 'frameStrata', { items = STRATA_ITEMS })
				return {
					PreviewEye(row, key),
					PageKit.SettingsIcon(row, { title = 'POSITION OPTIONS', tooltip = 'Centering, fill direction & strata', options = options }),
					BUI.AlertMover(row, barSettings, Apply, { selfTag = selfTag, noCenter = true }),
				}
			end,
		})
	end

	function kit.ButtonsRow(maxButtons)
		kit.Row({
			title = 'Buttons', description = 'The cog sets how many buttons and how many per row; the size glyph sets how big. Height 0 keeps buttons square.', plain = true, accessoryWidth = 64,
			accessories = function(row)
				local cog = PageKit.SettingsIcon(row, { title = title:upper() .. ' BUTTONS', tooltip = 'Count & rows', options = {
					kit.Option('slider', 'Buttons', 'buttonCount', { min = 1, max = maxButtons }),
					kit.Option('slider', 'Per Row', 'buttonsPerRow', { min = 1, max = maxButtons }),
				} })
				local size = PageKit.SizeIcon(row, { title = title:upper() .. ' SIZE', tooltip = 'Size, spacing & scale', options = {
					kit.Option('slider', 'Button Size', 'buttonSize', { min = 20, max = 64 }),
					kit.Option('slider', 'Height', 'buttonHeight', { min = 0, max = 64 }),
					kit.Option('slider', 'Spacing', 'spacing', { min = 0, max = 16 }),
					kit.Option('slider', 'Scale %', 'scale', { min = 50, max = 200 }),
				} })
				return { cog, size }
			end,
		})
	end

	function kit.FadeRow()
		kit.Row({
			title = 'Mouseover Fade', description = 'Fade the bar out until the cursor is over it. The cog sets opacity and whether the fade is animated or instant.', accessoryWidth = 36,
			checked = barSettings.fadeEnabled,
			callback = function(value) barSettings.fadeEnabled = value; Apply() end,
			accessories = function(row)
				return { PageKit.SettingsIcon(row, { title = 'FADING', tooltip = 'Opacity, animation and fade time', options = {
					kit.Option('slider', 'Bar Opacity %', 'alpha', { min = 10, max = 100 }),
					kit.Option('slider', 'Faded Opacity %', 'fadeAlpha', { min = 0, max = 100 }),
					{ label = 'Animated', get = function() return barSettings.fadeAnimated end, set = function(value) barSettings.fadeAnimated = value; Apply() end },
					kit.Option('slider', 'Fade Time (s)', 'fadeDuration', { min = 0.05, max = 1, step = 0.05 }),
				} }) }
			end,
		})
	end

	function kit.ButtonRows(rows)
		if not rows then return end
		Layout.Section(tab, 'Buttons')
		if rows.hotkeys then kit.ToggleRow('Hotkeys', 'Keybind labels on this bar.', 'showHotkey') end
		if rows.macroText then kit.ToggleRow('Macro Text', 'Macro and spell names on this bar.', 'showMacroText') end
		if rows.cooldownText then
			kit.Row({
				title = 'Cooldown Text', description = 'Countdown numbers on this bar and their text size.',
				checked = barSettings.showCooldownText,
				callback = function(value) barSettings.showCooldownText = value; Apply() end,
				accessoryWidth = 170,
				accessories = function(row)
					return { Controls.CompactSlider(row, nil, 8, 24, barSettings.cooldownFontSize, function(value)
						barSettings.cooldownFontSize = value
						Apply()
					end, 1, 150) }
				end,
			})
		end
		if rows.hideEmpty then kit.ToggleRow('Hide Empty Buttons', 'Collapse slots with nothing in them.', 'hideEmptyButtons') end
		if rows.clickThrough then kit.ToggleRow('Click Through', 'The mouse passes through this bar. Keybinds still work; clicks and tooltips do not.', 'clickThrough') end
		if rows.blizzardArt then kit.ToggleRow('Blizzard Art', "Keep Blizzard's decorative frame around the buttons.", 'blizzardArt') end
	end

	return kit
end

local function BuildActionBar(tab, barIndex, barSettings, Apply)
	local kit = BarPageKit(tab, barIndex, 'Bar ' .. barIndex, barSettings, Apply)
	local preview = CreatePreview(tab, barIndex)

	Layout.Section(tab, 'Bar ' .. barIndex)
	kit.EnabledRow("Show this bar. Its keybinds follow the matching Blizzard bar, which is hidden while this is on (reload to bring Blizzard's back).")

	Layout.Section(tab, 'Layout')
	kit.PositionRow('BUI_ActionBar' .. barIndex, true)
	kit.ButtonsRow(12)
	kit.FadeRow()

	do
		Layout.Section(tab, 'Paging')
		kit.Row({
			title = 'Page Switching', description = barIndex == 1 and 'Vehicles, stances, possession and the page arrows swap what this bar shows.' or 'Stances, possession and the modifier pages swap what this bar shows.',
			checked = barSettings.pagingEnabled,
			callback = function(value) barSettings.pagingEnabled = value; Apply() end,
			accessoryWidth = 36,
			accessories = function(row)
				local options = {}
				for _, modifier in ipairs(MODIFIERS) do
					options[#options + 1] = {
						kind = 'dropdown', label = modifier.label, items = MODIFIER_PAGE_ITEMS,
						get = function() return barSettings.modifierPages[modifier.key] end,
						set = function(value)
							barSettings.modifierPages[modifier.key] = value
							Apply()
						end,
					}
				end
				return { PageKit.SettingsIcon(row, { title = 'MODIFIER PAGES', tooltip = 'Pages shown while a modifier is held', options = options }) }
			end,
		})
	end

	kit.ButtonRows(ACTION_BAR_ROWS)
	kit.SyncDim()
	return preview
end

local function BuildExtraBar(tab, page, barSettings, Apply)
	local kit = BarPageKit(tab, page.key, page.title, barSettings, Apply)
	local preview = CreatePreview(tab, page.key)

	Layout.Section(tab, page.title)
	kit.EnabledRow(page.desc)

	Layout.Section(tab, 'Layout')
	kit.PositionRow(page.selfTag, page.buttons)
	if page.buttons then
		kit.ButtonsRow(page.maxButtons)
	elseif page.size then
		kit.Row({
			title = 'Size', description = 'Button size and overall scale.', plain = true, accessoryWidth = 36,
			accessories = function(row)
				return { PageKit.SizeIcon(row, { title = page.title:upper(), tooltip = 'Size & scale', options = {
					kit.Option('slider', 'Button Size', 'buttonSize', { min = 24, max = 80 }),
					kit.Option('slider', 'Scale %', 'scale', { min = 50, max = 200 }),
				} }) }
			end,
		})
	elseif page.micro then
		kit.Row({
			title = 'Arrangement', description = 'Buttons per row, spacing, scale, or a vertical stack.', plain = true, accessoryWidth = 36,
			accessories = function(row)
				return { PageKit.SizeIcon(row, { title = 'MICRO MENU', tooltip = 'Rows, spacing & scale', options = {
					kit.Option('slider', 'Per Row', 'buttonsPerRow', { min = 1, max = MICRO_COUNT }),
					kit.Option('slider', 'Spacing', 'spacing', { min = 0, max = 12 }),
					kit.Option('slider', 'Scale %', 'scale', { min = 50, max = 200 }),
					{ label = 'Vertical', get = function() return barSettings.vertical end, set = function(value) barSettings.vertical = value; Apply() end },
				} }) }
			end,
		})
	elseif page.scaleOnly then
		kit.Row({
			title = 'Scale', description = page.scaleDesc or 'Overall size of the bag buttons.', plain = true, accessoryWidth = 36,
			accessories = function(row)
				return { PageKit.SizeIcon(row, { title = page.title:upper(), tooltip = 'Scale', options = {
					kit.Option('slider', 'Scale %', 'scale', { min = 50, max = 200 }),
				} }) }
			end,
		})
	end
	kit.FadeRow()

	kit.ButtonRows(page.rows)
	kit.SyncDim()
	return preview
end

BUI.PageEngine.RegisterPage('actionbars', {
	title = 'Action Bars',
	buttonText = 'Action Bars',
	OnBuild = function(pageFrame)
		local db = BUI.GetDB()

		if not BUI.IsModuleEnabled('actionBars') then
			local page = Layout.Page(pageFrame, nil)
			local tab = page:GetTab(1)
			Layout.Section(tab, 'Action Bars', 'Module disabled. Enable it below, then reload.')
			local enableButton = Controls.Button(tab.child, 'Enable Action Bars & Reload', 220, function()
				BUI.SetModuleEnabled('actionBars', true)
				ReloadUI()
			end)
			Layout.Add(tab, enableButton, 12)
			page:AutoRefresh()
			return
		end

		local settings = db.actionBars
		local currentPreview
		local function Apply()
			BUI.ActionBars.Refresh()
			if currentPreview then currentPreview:Render() end
		end

		local titleBar
		local titleHeight
		titleHeight, titleBar = PageKit.PageTitle(pageFrame, 'Action Bars', CONTENT_WIDTH, {
			desc = "BluUI's own action bars, replacing Blizzard's. General settings and each bar have their own page.",
			anchor = {
				value = BUI.ActionBars.MoversUnlocked(),
				tooltip = 'Unlock every bar to drag it; right-click a bar to lock again',
				onToggle = function(unlocked) BUI.ActionBars.SetMoversUnlocked(unlocked) end,
			},
			enable = { value = true, tooltip = 'Disable the action bars module', onToggle = function(enabled)
				if enabled then return end
				Modals.Confirm({
					parent = BUI.PageEngine.window.frame,
					title = 'Disable Action Bars',
					message = 'This change requires a UI reload to take effect.',
					confirmText = 'Reload Now', cancelText = 'Cancel',
					onConfirm = function() BUI.SetModuleEnabled('actionBars', false); ReloadUI() end,
					onCancel = function() titleBar.enableToggle:SetValue(true) end,
				})
			end },
		})

		local host = CreateFrame('Frame', nil, pageFrame)
		host:SetPoint('TOP', pageFrame, 'TOP', 0, -(PageKit.PAD + titleHeight))
		host:SetPoint('BOTTOM', pageFrame, 'BOTTOM', 0, 0)
		host:SetWidth(CONTENT_WIDTH)

		local barItems = {}
		for barIndex = 1, BUI.ActionBars.BAR_COUNT do
			barItems[barIndex] = { id = 'bar' .. barIndex, label = 'Bar ' .. barIndex }
		end
		local extraItems = {}
		local extraByKey = {}
		for _, page in ipairs(EXTRA_PAGES) do
			extraItems[#extraItems + 1] = { id = page.key, label = page.title }
			extraByKey[page.key] = page
		end

		local pages = {}
		local unlockRow
		local sidebar
		sidebar = Layout.SidebarPage(host, {
			listWidth = LIST_WIDTH,
			contentWidth = DETAIL_WIDTH,
			default = 'general',
			groups = {
				{ header = 'Settings', items = { { id = 'general', label = 'General' } } },
				{ header = 'Bars', items = barItems },
				{ header = 'Other Bars', items = extraItems },
			},
			onSelect = function(id, detailTab)
				for _, entry in pairs(pages) do entry.wrapper:Hide() end
				local entry = pages[id]
				if not entry then
					local wrapper = CreateFrame('Frame', nil, detailTab.child)
					wrapper:SetPoint('TOPLEFT')
					wrapper:SetWidth(detailTab.width)
					local topAnchor = CreateFrame('Frame', nil, wrapper)
					topAnchor:SetPoint('TOPLEFT')
					topAnchor:SetPoint('TOPRIGHT')
					topAnchor:SetHeight(1)
					local tab = Layout.ApplyContentMixin({
						child = wrapper, frame = detailTab.frame, scroll = detailTab.scroll, scrollChild = detailTab.scrollChild, width = detailTab.width,
					})
					tab.lastControl = topAnchor
					local preview
					if id == 'general' then
						unlockRow = BuildGeneral(tab, settings, Apply)
					elseif extraByKey[id] then
						local page = extraByKey[id]
						preview = BuildExtraBar(tab, page, BUI.ActionBars.GetBarSettings(page.key), Apply)
					else
						local barIndex = tonumber(id:match('%d+'))
						preview = BuildActionBar(tab, barIndex, settings.bars[barIndex], Apply)
					end
					local height = Layout.MeasureLowestExtent(wrapper)
					if height == 0 then height = math.abs(tab.y) end
					wrapper:SetHeight(height + 8)
					entry = { wrapper = wrapper, tab = tab, preview = preview }
					pages[id] = entry
				end
				currentPreview = entry.preview
				if currentPreview then currentPreview:Render() end
				entry.wrapper:Show()
			end,
		})

		pageFrame._selectModule = function(key)
			sidebar:Select((key or ''):match('^[^.]+') or 'general')
		end

		local function SyncUnlockControls()
			local unlocked = BUI.ActionBars.MoversUnlocked()
			if unlockRow then Widget.Unwrap(unlockRow):SetValue(unlocked) end
			titleBar.anchorToggle:SetValue(unlocked)
		end
		BUI.ActionBars.OnMoversChanged('ActionBarsPage', function(kind)
			if kind == 'unlocked' then SyncUnlockControls() end
			if kind == 'unlocked' or kind == 'barUnlocked' then SyncPreviewEyes() end
		end)
		HookScript(pageFrame, 'OnShow', function()
			SyncUnlockControls()
			SyncPreviewEyes()
			if currentPreview then currentPreview:Render() end
		end)
	end,
})
