local _, BUI = ...
local SetScript = BUI.Prof.Scripts('ActionBars.Style')

local ActionBars = BUI.ActionBars
local Pixel = BUI.Pixel
local LibActionButton = LibStub('LibActionButton-1.0-BluUI')

local CAST_FRAME_KEYS = { 'SpellCastAnimFrame', 'InterruptDisplay', 'TargetReticleAnimFrame', 'CooldownFlash' }

local function TextBlock(fontPath, size, color, anchor, offsetX, offsetY)
	return {
		font = { font = fontPath, size = size, flags = 'OUTLINE' },
		color = color,
		position = { anchor = anchor, relAnchor = anchor, offsetX = offsetX, offsetY = offsetY },
		justifyH = ActionBars.JustifyForAnchor(anchor),
	}
end

function ActionBars.BuildButtonConfig(barIndex, buttonIndex)
	local settings = ActionBars.GetSettings()
	local barSettings = ActionBars.GetBarSettings(barIndex)
	local fontPath = BUI.GetAddonFont()
	return {
		outOfRangeColoring = 'button',
		tooltip = 'enabled',
		showGrid = not barSettings.hideEmptyButtons,
		keyBoundTarget = ActionBars.COMMAND_FOR_BAR[barIndex] .. buttonIndex,
		actionButtonUI = true,
		assistedHighlight = settings.showAssistedCombat,
		spellCastVFX = settings.castAnimation,
		cooldownCount = barSettings.showCooldownText,
		hideElements = {
			macro = not barSettings.showMacroText,
			hotkey = not barSettings.showHotkey,
			equipped = true,
			border = true,
			borderIfEmpty = true,
		},
		text = {
			hotkey = TextBlock(fontPath, settings.hotkeyFontSize, settings.hotkeyColor, settings.hotkeyAnchor, settings.hotkeyOffsetX, settings.hotkeyOffsetY),
			count = TextBlock(fontPath, settings.countFontSize, settings.countColor, settings.countAnchor, settings.countOffsetX, settings.countOffsetY),
			macro = TextBlock(fontPath, settings.macroFontSize, settings.macroColor, settings.macroAnchor, settings.macroOffsetX, settings.macroOffsetY),
		},
	}
end

local function FlattenStateTexture(texture, red, green, blue, alpha)
	if not texture then return end
	texture:SetAtlas(nil)
	texture:SetTexture(BUI.C.FALLBACK_TEXTURE)
	texture:SetTexCoord(0, 1, 0, 1)
	texture:SetVertexColor(red, green, blue, alpha)
	texture:ClearAllPoints()
	texture:SetAllPoints(texture:GetParent())
end
ActionBars.FlattenStateTexture = FlattenStateTexture

function ActionBars.FitButtonOverlays(button)
	local width = button:GetWidth()
	if width == 0 then return end
	local showAssistedCombat = ActionBars.GetSettings().showAssistedCombat
	local assistScale = width / 45
	local rotationFrame = button.AssistedCombatRotationFrame
	if rotationFrame then
		rotationFrame:SetScale(assistScale)
		rotationFrame:ClearAllPoints()
		rotationFrame:SetPoint('CENTER', button, 'CENTER', 0, 0)
		rotationFrame:SetAlpha(showAssistedCombat and 1 or 0)
	end
	local highlightFrame = button.AssistedCombatHighlightFrame
	if highlightFrame then
		highlightFrame:SetScale(assistScale)
		if not showAssistedCombat then highlightFrame:Hide() end
	end
	if button.SpellActivationAlert then button.SpellActivationAlert:SetScale(assistScale) end
	for _, key in ipairs(CAST_FRAME_KEYS) do
		local castFrame = button[key]
		if castFrame then castFrame:SetScale(assistScale) end
	end
	local highlight = button.HighlightTexture
	if highlight then highlight:ClearAllPoints(); highlight:SetAllPoints(button) end
	local checked = button.CheckedTexture
	if checked then checked:ClearAllPoints(); checked:SetAllPoints(button) end
end

function ActionBars.FitAllButtonOverlays()
	ActionBars.ForEachButton(ActionBars.FitButtonOverlays)
end

local QueueOverlayFit = BUI.Dispatcher.New(ActionBars.FitAllButtonOverlays, 'ActionBars.AssistSync')

EventRegistry:RegisterCallback('AssistedCombatManager.OnSetActionSpell', QueueOverlayFit, ActionBars)
EventRegistry:RegisterCallback('AssistedCombatManager.OnAssistedHighlightSpellChange', QueueOverlayFit, ActionBars)
EventRegistry:RegisterCallback('AssistedCombatManager.OnSetUseAssistedHighlight', QueueOverlayFit, ActionBars)

local function StripTemplateArt(button)
	local normal = button.NormalTexture
	if normal then
		normal:SetTexture()
		normal:SetAlpha(0)
	end
	if button.IconMask then button.icon:RemoveMaskTexture(button.IconMask) end
	local slotArt = button.SlotArt
	if slotArt then
		slotArt:SetAlpha(0)
		slotArt:Hide()
	end
	local flash = button.Flash
	if flash then
		FlattenStateTexture(flash, 1, 0.6, 0.2, 0.35)
		flash:Hide()
	end
	if button.Border then button.Border:Hide() end
	if button.LevelLinkLockIcon then button.LevelLinkLockIcon:Hide() end
	local cooldown = button.cooldown
	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(button)
	end
end

local ICON_CROP = 0.08
local reassertingCooldown = false

function ActionBars.ApplyIconCrop(button)
	local width, height = button:GetSize()
	local left, right, top, bottom = ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP
	if width > 0 and height > 0 and math.abs(width - height) > 0.5 then
		local half = 0.5 - ICON_CROP
		if height < width then
			half = half * height / width
			top, bottom = 0.5 - half, 0.5 + half
		else
			half = half * width / height
			left, right = 0.5 - half, 0.5 + half
		end
	end
	button.icon:SetTexCoord(left, right, top, bottom)
end

local function SwipeAllowed(cooldown)
	if cooldown.currentCooldownType ~= nil and cooldown.currentCooldownType == COOLDOWN_TYPE_LOSS_OF_CONTROL then return false end
	local button = cooldown:GetParent()
	local castFrame = button and button.SpellCastAnimFrame
	return not (castFrame and castFrame:IsShown())
end

local function ApplyCooldownStyle(cooldown)
	if reassertingCooldown then return end
	reassertingCooldown = true
	if SwipeAllowed(cooldown) then
		local color = ActionBars.GetSettings().swipeColor
		cooldown:SetSwipeColor(color[1], color[2], color[3], color[4])
	end
	local button = cooldown:GetParent()
	if button then ActionBars.StyleCooldownText(button, cooldown) end
	reassertingCooldown = false
end

local function OnSwipeColorSet(cooldown, red, _, _, alpha)
	if reassertingCooldown or alpha == 0 or (red or 0) > 0 then return end
	ApplyCooldownStyle(cooldown)
end

function ActionBars.StyleCooldown(cooldown)
	if not cooldown._buiStyleHooked then
		cooldown._buiStyleHooked = true
		ActionBars.hooksecurefunc(cooldown, 'SetSwipeColor', OnSwipeColorSet)
		ActionBars.hooksecurefunc(cooldown, 'SetCooldown', ApplyCooldownStyle)
		ActionBars.hooksecurefunc(cooldown, 'SetCooldownFromDurationObject', ApplyCooldownStyle)
	end
	ApplyCooldownStyle(cooldown)
end

function ActionBars.EmptyButtonColor()
	local settings = ActionBars.GetSettings()
	if not settings.emptyButtonBackground then return 0, 0, 0, 0 end
	local color = settings.emptyButtonColor
	return color[1], color[2], color[3], color[4]
end

function ActionBars.SyncEmptyButtonColor(button)
	local fill = button._buiEmptyFill
	if not fill then
		fill = button:CreateTexture(nil, 'BACKGROUND', nil, -1)
		fill:SetAllPoints(button)
		button._buiEmptyFill = fill
	end
	local red, green, blue, alpha = ActionBars.EmptyButtonColor()
	fill:SetColorTexture(red, green, blue, alpha)
	fill:SetShown(not button:HasAction())
	local slotBackground = button.SlotBackground
	if slotBackground then
		slotBackground:SetAlpha(0)
		slotBackground:Hide()
	end
end

local TEMPLATE_SCRIPTS = { 'OnAttributeChanged', 'OnEvent', 'OnUpdate', 'OnMouseDown', 'OnMouseUp', 'OnHide', 'OnShow' }

local function NeutralizeTemplateButton(button)
	button:UnregisterAllEvents()
	for _, script in ipairs(TEMPLATE_SCRIPTS) do
		if button:HasScript(script) then SetScript(button, script, nil) end
	end
	local arrow = button.Arrow
	if arrow then
		arrow:SetAlpha(0)
		arrow:Hide()
	end
	if button.BorderShadow then button.BorderShadow:Hide() end
	if button.AutoCastOverlay then button.AutoCastOverlay:Hide() end
end

local function StoredHasAction(button) return button._hasAction == true end
local function StoredSpellId(button) return button._spellID end

function ActionBars.PrepareTemplateButton(button, barKey, command)
	NeutralizeTemplateButton(button)
	button.HasAction = StoredHasAction
	button.GetSpellId = StoredSpellId
	button._buiBar = barKey
	button.config = { showGrid = true, keyBoundTarget = command }
end

function ActionBars.SkinButtonArt(button)
	local settings = ActionBars.GetSettings()
	local borderColor = settings.borderColor
	StripTemplateArt(button)
	ActionBars.ApplyIconCrop(button)
	if button.cooldown then ActionBars.StyleCooldown(button.cooldown) end
	FlattenStateTexture(button.HighlightTexture, 1, 1, 1, 0.15)
	local pressColor = settings.pressColor
	local pressAlpha = settings.showKeyPresses and settings.pressOpacity / 100 or 0
	FlattenStateTexture(button.PushedTexture, pressColor[1], pressColor[2], pressColor[3], pressAlpha)
	FlattenStateTexture(button.CheckedTexture, 1, 1, 1, 0.3)
	FlattenStateTexture(button.SpellHighlightTexture, 1, 0.85, 0.3, 0.35)
	FlattenStateTexture(button.NewActionTexture, 1, 1, 1, 0.2)
	if button.FlyoutBorderShadow then button.FlyoutBorderShadow:SetAlpha(0) end
	Pixel.ApplyBorder(button, settings.borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
end

function ActionBars.SkinButton(button)
	ActionBars.SkinButtonArt(button)
	ActionBars.SyncEmptyButtonColor(button)
	button._buiBorderState = nil
	ActionBars.SyncButtonBorder(button)
	ActionBars.FitButtonOverlays(button)
end

function ActionBars.SyncButtonBorder(button)
	local settings = ActionBars.GetSettings()
	local state = (button:HasAction() or settings.emptyButtonBackground) and 'shown' or 'hidden'
	if button._buiBorderState == state then return end
	button._buiBorderState = state
	if state == 'hidden' then
		Pixel.HideBorder(button)
		return
	end
	local color = settings.borderColor
	Pixel.SetBorderColor(button, color[1], color[2], color[3], color[4])
end

function ActionBars.SyncEmptyButtonAlpha(button)
	local hasAction = button:HasAction()
	ActionBars.SyncEmptyButtonColor(button)
	if button.config.showGrid or hasAction or GetCursorInfo() then
		button:SetAlpha(1)
	else
		button:SetAlpha(0)
	end
end

function ActionBars.SyncAllEmptyButtonAlpha()
	ActionBars.ForEachButton(ActionBars.SyncEmptyButtonAlpha)
end

local QueueEmptyButtonSync = BUI.Dispatcher.New(ActionBars.SyncAllEmptyButtonAlpha, 'ActionBars.GridSync')

local function ResyncAllButtons()
	if InCombatLockdown() then
		BUI.Events:AfterCombat(ResyncAllButtons, 'ActionBars.Resync')
		return
	end
	ActionBars.ForEachButton(function(button)
		if button.UpdateAction then button:UpdateAction(true) end
	end)
end
local QueueResync = BUI.Dispatcher.New(ResyncAllButtons, 'ActionBars.Resync')
for _, event in ipairs({ 'ENCOUNTER_END', 'PLAYER_ALIVE', 'PLAYER_UNGHOST' }) do
	BUI.Events:Register(event, 'ActionBars.Resync', QueueResync)
end

BUI.Events:Register('ACTIONBAR_SHOWGRID', 'ActionBars.GridSync', QueueEmptyButtonSync)
BUI.Events:Register('ACTIONBAR_HIDEGRID', 'ActionBars.GridSync', QueueEmptyButtonSync)

function ActionBars.ApplyHotkeyText(button)
	local hotkey = button.HotKey
	local command = button.config and button.config.keyBoundTarget
	if not hotkey or not command then return end
	local text = BUI.Keybinds.Format(GetBindingKey(command)) or ''
	if button._formattedHotkey == text then return end
	button._formattedHotkey = text
	hotkey:SetText(text)
end

function ActionBars.RefreshAllHotkeyText()
	ActionBars.ForEachButton(ActionBars.ApplyHotkeyText)
end

local QueueHotkeyText = BUI.Dispatcher.New(ActionBars.RefreshAllHotkeyText, 'ActionBars.HotkeyText')

BUI.Events:Register('UPDATE_BINDINGS', 'ActionBars.HotkeyText', QueueHotkeyText)

LibActionButton.RegisterCallback(ActionBars, 'OnButtonUpdate', function(_, button)
	if button._formattedHotkey == nil then return end
	local hotkey = button.HotKey
	if hotkey and hotkey:GetText() ~= button._formattedHotkey then
		hotkey:SetText(button._formattedHotkey)
	end
	ActionBars.SyncButtonBorder(button)
	ActionBars.FitButtonOverlays(button)
	ActionBars.SyncEmptyButtonAlpha(button)
	ActionBars.SyncItemRank(button)
end)

local clickThroughSuspended = false

function ActionBars.ApplyBarMouse(bar, frames)
	local clicks = not bar.contentHidden and (clickThroughSuspended or not ActionBars.GetBarSettings(bar.key).clickThrough)
	local motion = not bar.contentHidden
	local state = (clicks and 'c' or '-') .. (motion and 'm' or '-')
	if bar.mouseState == state then return end
	if InCombatLockdown() then
		ActionBars.RunSecure('Mouse.' .. tostring(bar.key), function() ActionBars.ApplyBarMouse(bar, frames) end)
		return
	end
	bar.mouseState = state
	bar.mouseEnabled = clicks
	for _, frame in ipairs(frames or bar.buttons) do
		frame:SetMouseClickEnabled(clicks)
		frame:SetMouseMotionEnabled(motion)
	end
end

function ActionBars.SetClickThroughSuspended(suspended)
	clickThroughSuspended = suspended
	for _, bar in pairs(ActionBars.bars) do
		if bar.kind ~= 'blizzard' then ActionBars.ApplyBarMouse(bar) end
	end
end

function ActionBars.ApplyButtonLock(button)
	if InCombatLockdown() then return end
	button:SetAttribute('buttonlock', ActionBars.GetSettings().lockButtons or nil)
end

function ActionBars.ApplyPickupKey()
	local key = ActionBars.GetSettings().pickupKey
	if GetModifiedClick('PICKUPACTION') ~= key then
		SetModifiedClick('PICKUPACTION', key)
	end
end

function ActionBars.BuildFlyoutConfig()
	local config = ActionBars.BuildButtonConfig(1, 1)
	config.keyBoundTarget = nil
	config.hideElements.hotkey = true
	config.hideElements.macro = true
	return config
end

function ActionBars.SkinFlyoutButton(button)
	button._buiBar = 'flyout'
	button:UpdateConfig(ActionBars.BuildFlyoutConfig())
	ActionBars.SkinButton(button)
	button._formattedHotkey = ''
	ActionBars.SyncEmptyButtonAlpha(button)
end

function ActionBars.RefreshFlyoutButtons()
	for _, button in ipairs(LibActionButton.FlyoutButtons) do
		ActionBars.SkinFlyoutButton(button)
	end
end

LibActionButton.RegisterCallback(ActionBars, 'OnFlyoutButtonCreated', function(_, button)
	if BUI.IsModuleEnabled('actionBars') then ActionBars.SkinFlyoutButton(button) end
end)

function ActionBars.ApplyButtonConfig(bar)
	for buttonIndex, button in ipairs(bar.buttons) do
		button:UpdateConfig(ActionBars.BuildButtonConfig(bar.key, buttonIndex))
		ActionBars.ApplyButtonLock(button)
		ActionBars.SkinButton(button)
		button._formattedHotkey = nil
		ActionBars.ApplyHotkeyText(button)
		ActionBars.SyncEmptyButtonAlpha(button)
	end
end

do
	local function WrapLibraryFrame()
		local frame = LibActionButton.eventFrame
		if not frame or frame._buiProfWrapped then return end
		local onEvent = frame:GetScript('OnEvent')
		local onUpdate = frame:GetScript('OnUpdate')
		if not onEvent then return end
		frame._buiProfWrapped = true
		BUI.Prof.SetScript('LAB', frame, 'OnEvent', onEvent)
		if onUpdate then frame:SetScript('OnUpdate', BUI.Prof.WrapScript('tick#LAB.Update', onUpdate)) end
		local pass = LibActionButton.cooldownPassFrame
		if pass and not pass._buiProfWrapped then
			pass._buiProfWrapped = true
			local passUpdate = pass:GetScript('OnUpdate')
			if passUpdate then pass:SetScript('OnUpdate', BUI.Prof.WrapScript('tick#LAB.CooldownPass', passUpdate)) end
		end
	end
	local function WrapButton(button)
		if button._buiProfWrapped then return end
		local onEvent = button:GetScript('OnEvent')
		if not onEvent then return end
		button._buiProfWrapped = true
		BUI.Prof.SetScript('LAB.Button', button, 'OnEvent', onEvent)
	end
	for button in pairs(LibActionButton.buttonRegistry) do WrapButton(button) end
	WrapLibraryFrame()
	local profOwner = {}
	LibActionButton.RegisterCallback(profOwner, 'OnButtonCreated', function(_, button)
		WrapButton(button)
		WrapLibraryFrame()
	end)
end
