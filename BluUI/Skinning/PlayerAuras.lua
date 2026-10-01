local _, BUI = ...

local ipairs = ipairs
local wipe = wipe
local Hook = BUI.Profiler.Hooker('Skin.PlayerAuras')
local min = math.min
local IsSecret = _G.issecretvalue or function() return false end

local Skin = BUI.Skinning
local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Controls = BUILib.Controls
local PageKit = BUILib.PageKit
local Pixel = BUI.Pixel

local SKIN_ID = 'playerauras'
local SETTINGS_KEY = 'playerAuraSettings'
local BUTTON_ART_KEYS = { 'Border', 'TempEnchantBorder', 'DebuffBorder' }
local MIN_ICON_SIZE = 4
local BORDER_SIZE = 1
local AURA_FRAME_NAMES = { 'BuffFrame', 'DebuffFrame' }

local OUTLINE_ITEMS = {
	{ value = '',             text = 'None'          },
	{ value = 'OUTLINE',      text = 'Outline'       },
	{ value = 'THICKOUTLINE', text = 'Thick Outline' },
	{ value = 'MONOCHROME',   text = 'Monochrome'    },
}

local installed = false
local skinnedButtons = {}
local collapseButton

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local function Settings()
	return BUI.GetDB().skinning[SETTINGS_KEY]
end

local context = Skin.NewContext(Enabled)
local FadeRegions, FadeKeys = context.FadeRegions, context.FadeKeys

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function ResolveFont(name)
	if name == BUI.C.GLOBAL_OPTION then return BUI.GetGlobalFont() end
	return LibStub('LibSharedMedia-3.0'):Fetch('font', name) or BUI.GetGlobalFont()
end

local function ForEachAuraFrame(action)
	for _, name in ipairs(AURA_FRAME_NAMES) do
		local frame = _G[name]
		if frame and frame.AuraContainer then action(frame) end
	end
end

local function ContainerScale(container)
	local scale = container and container.iconScale
	if not scale or scale <= 0 then return 1 end
	return scale
end

local function ButtonScale(button)
	return ContainerScale(button:GetParent())
end

local function AnchorText(fontString, icon, anchor, offsetX, offsetY, scale)
	if not fontString or not icon then return end
	local textX, textY = Pixel.Scale(offsetX) / scale, Pixel.Scale(offsetY) / scale
	fontString:ClearAllPoints()
	fontString:SetPoint(anchor, icon, anchor, textX, textY)
	fontString._buiAnchor, fontString._buiAnchorX, fontString._buiAnchorY = anchor, textX, textY
end

local function TextAnchoredAt(fontString, anchor, offsetX, offsetY, scale)
	return fontString._buiAnchor == anchor
		and fontString._buiAnchorX == Pixel.Scale(offsetX) / scale
		and fontString._buiAnchorY == Pixel.Scale(offsetY) / scale
end

local function StyleText(fontString, icon, size, anchor, offsetX, offsetY, settings, scale)
	if not fontString then return end
	Pixel.ApplyFont(fontString, size / scale, ResolveFont(settings.font), settings.outline)
	AnchorText(fontString, icon, anchor, offsetX, offsetY, scale)
end

local function EdgeColorFor(button)
	local border = button.Border or button.DebuffBorder
	if border and border:IsShown() then return border:GetVertexColor() end
	if button.TempEnchantBorder and button.TempEnchantBorder:IsShown() then
		return button.TempEnchantBorder:GetVertexColor()
	end
end

local function RefreshButton(button)
	if not button._buiAura then return end
	Skin.SetIconEdgeColor(button.Icon, EdgeColorFor(button))
end

local function BorderInset(button, scale)
	local base = button._buiAuraIconWidth
	if not base or IsSecret(base) then return 0 end
	return min(BORDER_SIZE / scale, (base - MIN_ICON_SIZE) / 2)
end

local function InsetIcon(button, inset)
	local icon = button.Icon
	local base = button._buiAuraIconWidth
	if not icon or not base or IsSecret(base) or IsSecret(button._buiAuraIconHeight) then return end
	if button._buiIconInset ~= inset then
		icon:SetSize(base - inset * 2, button._buiAuraIconHeight - inset * 2)
		button._buiIconInset = inset
	end
	local point = icon:GetPoint(1)
	if point ~= nil and not IsSecret(point) then
		button._buiIconPoint = point
	else
		point = button._buiIconPoint
	end
	if not point then return end

	icon:ClearAllPoints()
	if point == 'BOTTOM' then
		icon:SetPoint(point, button, point, 0, inset)
	elseif point == 'LEFT' then
		icon:SetPoint(point, button, point, inset, 0)
	elseif point == 'RIGHT' then
		icon:SetPoint(point, button, point, -inset, 0)
	else
		icon:SetPoint(point, button, point, 0, -inset)
	end
end

local function StyleButton(button)
	local settings = Settings()
	local scale = ButtonScale(button)
	local inset = BorderInset(button, scale)
	InsetIcon(button, inset)
	Skin.SetIconEdgeThickness(button.Icon, inset)
	StyleText(button.Duration, button.Icon, settings.timerSize, settings.timerAnchor, settings.timerOffsetX, settings.timerOffsetY, settings, scale)
	StyleText(button.Count, button.Icon, settings.stackSize, settings.stackAnchor, settings.stackOffsetX, settings.stackOffsetY, settings, scale)
	RefreshButton(button)
end

local function RepairLayout(container, auras, skipDisabled)
	local settings = Settings()
	local scale = ContainerScale(container)
	for _, button in ipairs(auras) do
		if button._buiAura and (not skipDisabled or button.hasValidInfo or button.isExample) then
			InsetIcon(button, BorderInset(button, scale))
			AnchorText(button.Duration, button.Icon, settings.timerAnchor, settings.timerOffsetX, settings.timerOffsetY, scale)
			if not TextAnchoredAt(button.Count, settings.stackAnchor, settings.stackOffsetX, settings.stackOffsetY, scale) then
				AnchorText(button.Count, button.Icon, settings.stackAnchor, settings.stackOffsetX, settings.stackOffsetY, scale)
			end
		end
	end
end

local function SkinButton(button)
	if not button or button._buiAura or not button.Icon then return end

	KeepTexture(button.Icon)
	FadeRegions(button)
	FadeKeys(button, BUTTON_ART_KEYS)

	Skin.CropIcon(button.Icon)
	Skin.TipIconFrame(button, button.Icon, BORDER_SIZE)

	button._buiAura = true
	local iconWidth, iconHeight = button.Icon:GetSize()
	if not (IsSecret(iconWidth) or IsSecret(iconHeight)) then
		button._buiAuraIconWidth, button._buiAuraIconHeight = iconWidth, iconHeight
	end
	button._buiAuraTimerFont = button.Duration and button.Duration:GetFontObject()
	button._buiAuraStackFont = button.Count and button.Count:GetFontObject()
	skinnedButtons[#skinnedButtons + 1] = button
	StyleButton(button)
end

local function SweepFrame(frame)
	for _, button in ipairs(frame.auraFrames) do
		if not button.isAuraAnchor then
			SkinButton(button)
			if button:IsShown() then RefreshButton(button) end
		end
	end
end

local function Sweep()
	if not Enabled() then return end
	ForEachAuraFrame(SweepFrame)
end

local DispatchSweep = BUI.Dispatcher.New(Sweep, 'Skin.PlayerAuras')

local function Restyle()
	if not Enabled() then return end
	for _, button in ipairs(skinnedButtons) do StyleButton(button) end
end

local function HookAuraFrame(frame)
	if frame._buiAuraHooked then return end
	frame._buiAuraHooked = true
	Hook(frame.AuraContainer, 'UpdateGridLayout', function(container, auras, doNotAnchorDisabledFrames)
		if not Enabled() then return end
		RepairLayout(container, auras, doNotAnchorDisabledFrames)
	end)
end

local function SkinCollapseButton(button)
	if not button or button._buiAuraCollapse then return end
	FadeRegions(button)
	Skin.TipPageButton(button, 'previous')
	button._buiAuraCollapse = true
	collapseButton = button
end

local function Install()
	if installed then return end
	local buffFrame = _G.BuffFrame
	if not buffFrame then return end
	installed = true

	SkinCollapseButton(buffFrame.CollapseAndExpandButton)
	ForEachAuraFrame(HookAuraFrame)
	BUI.Events:RegisterUnit('UNIT_AURA', 'player', 'Skin.PlayerAuras', DispatchSweep)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Skin.PlayerAuras', DispatchSweep)
	Sweep()
end

local function Deactivate()
	for _, button in ipairs(skinnedButtons) do
		button._buiAura = nil
		button._buiIconInset = nil
		if button.Icon then
			button.Icon:SetTexCoord(0, 1, 0, 1)
			Skin.SetIconEdgeThickness(button.Icon, 0)
			if button._buiAuraIconWidth then
				button.Icon:SetSize(button._buiAuraIconWidth, button._buiAuraIconHeight)
			end
		end
		if button.Duration and button._buiAuraTimerFont then
			button.Duration:SetFontObject(button._buiAuraTimerFont)
		end
		if button.Count and button._buiAuraStackFont then
			button.Count:SetFontObject(button._buiAuraStackFont)
			button.Count:ClearAllPoints()
			button.Count:SetPoint('BOTTOMRIGHT', button.Icon, 'BOTTOMRIGHT', -2, 2)
		end
	end
	wipe(skinnedButtons)
	context.Restore()
	Skin.SetPageButtonSkinned(collapseButton, false)
end

local function TextCardRows(card, title, keys)
	local settings = Settings()
	local cog = PageKit.SettingsIcon(card, {
		title = title, tooltip = 'Size & offsets', options = {
			{ kind = 'slider', label = 'Font Size', min = 6, max = 24,
			  get = function() return settings[keys.size] end,
			  set = function(value) settings[keys.size] = value end, apply = Restyle },
			{ kind = 'slider', label = 'X Offset', min = -30, max = 30,
			  get = function() return settings[keys.offsetX] end,
			  set = function(value) settings[keys.offsetX] = value end, apply = Restyle },
			{ kind = 'slider', label = 'Y Offset', min = -30, max = 30,
			  get = function() return settings[keys.offsetY] end,
			  set = function(value) settings[keys.offsetY] = value end, apply = Restyle },
		},
	})
	PageKit.Row(card, 38, 'Size & Offsets', cog)

	local anchorDropdown = Controls.Dropdown(card, nil, BUI.C.ANCHOR_POINT_OPTIONS, settings[keys.anchor], function(value)
		settings[keys.anchor] = value
		Restyle()
	end, nil, 150)
	PageKit.Row(card, 78, 'Anchor', anchorDropdown)
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		Skin.SetPageButtonSkinned(collapseButton, true)
		Sweep()
		Restyle()
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Player Auras',
	description = 'The buff, debuff and weapon enchant icons beside the minimap: cropped icons in a thin edge that takes the debuff type color, with your own timer and stack text.',
	icon = 'Interface/Icons/Spell_Holy_WordFortitude',
	buildSettings = function(content)
		local settings = Settings()
		local width = content.width
		local gap = PageKit.GAP
		local fontHeight = PageKit.CardHeight(2)
		local textHeight = PageKit.CardHeight(2)

		local root = CreateFrame('Frame', nil, content.child)
		root:SetPoint('TOPLEFT', 0, -8)
		root:SetSize(width, fontHeight + gap + textHeight + gap + textHeight)

		local offsetY = 0
		local function MakeCard(title, height)
			local card = Controls.SettingsCard(root, { title = title, width = width }).frame
			card:SetSize(width, height)
			card:SetPoint('TOPLEFT', 0, -offsetY)
			card:SetFrameLevel((root:GetFrameLevel() or 0) + 5)
			offsetY = offsetY + height + gap
			return card
		end

		local fontCard = MakeCard('FONT', fontHeight)
		local fontDropdown = Controls.Dropdown(fontCard, nil, BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), settings.font, function(value)
			settings.font = value
			Restyle()
		end, nil, 150)
		PageKit.Row(fontCard, 38, 'Font', fontDropdown)
		local outlineDropdown = Controls.Dropdown(fontCard, nil, OUTLINE_ITEMS, settings.outline, function(value)
			settings.outline = value
			Restyle()
		end, nil, 150)
		PageKit.Row(fontCard, 78, 'Outline', outlineDropdown)

		TextCardRows(MakeCard('TIMER TEXT', textHeight), 'TIMER TEXT',
			{ size = 'timerSize', anchor = 'timerAnchor', offsetX = 'timerOffsetX', offsetY = 'timerOffsetY' })
		TextCardRows(MakeCard('STACK TEXT', textHeight), 'STACK TEXT',
			{ size = 'stackSize', anchor = 'stackAnchor', offsetX = 'stackOffsetX', offsetY = 'stackOffsetY' })
	end,
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.PlayerAurasInstall', function()
	if Enabled() then Install() end
end)
