local _, BUI = ...
local SetScript = BUI.Prof.Scripts('ActionBars.PetBar')

local ActionBars = BUI.ActionBars
local Plain = ActionBars.Plain

local BUTTON_COUNT = ActionBars.PET_BUTTON_COUNT
local COMMAND = 'BONUSACTIONBUTTON'
local VISIBILITY = '[petbattle] hide; [novehicleui,pet,nooverridebar,nopossessbar] show; hide'
local EVENT_KEY = 'ActionBars.PetBar'
local UPDATE_EVENTS = {
	'PET_UI_UPDATE', 'PET_BAR_UPDATE', 'PLAYER_CONTROL_GAINED', 'PLAYER_CONTROL_LOST', 'PLAYER_ENTERING_WORLD',
	'PLAYER_FARSIGHT_FOCUS_CHANGED', 'SPELLS_CHANGED',
}
local UNUSABLE_TINT = 0.4
local BUILib = BUI.BUILibClient
local Pixel = BUI.Pixel

local bar
local QueueUpdate

local function OnEnter(button)
	if not button._hasAction then return end
	GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
	GameTooltip:SetPetAction(button:GetID())
	GameTooltip:Show()
end

local function OnDragStart(button)
	if InCombatLockdown() then return end
	if ActionBars.GetSettings().lockButtons and not IsModifiedClick('PICKUPACTION') then return end
	PickupPetAction(button:GetID())
	QueueUpdate()
end

local function OnReceiveDrag(button)
	if InCombatLockdown() then return end
	PickupPetAction(button:GetID())
	QueueUpdate()
end

local function CreateHeader()
	return ActionBars.RegisterBar({
		key = 'pet',
		kind = 'pet',
		label = ActionBars.BarLabel('pet'),
		command = COMMAND,
		clickButton = 'LeftButton',
		header = ActionBars.CreateHeader('BUI_PetBar', true),
		buttons = {},
		visibility = VISIBILITY,
	})
end

local function CreateButton(index)
	local button = CreateFrame('CheckButton', 'BUI_PetBarButton' .. index, bar.header, 'PetActionButtonTemplate')
	button:SetID(index)
	ActionBars.PrepareTemplateButton(button, 'pet', COMMAND .. index)
	button:RegisterForDrag('LeftButton')
	SetScript(button, 'OnEnter', OnEnter)
	SetScript(button, 'OnLeave', GameTooltip_Hide)
	SetScript(button, 'OnDragStart', OnDragStart)
	SetScript(button, 'OnReceiveDrag', OnReceiveDrag)
	ActionBars.SkinButton(button)
	ActionBars.ApplyHotkeyText(button)
	return button
end

local function UpdateButton(button, index, hasActionBar)
	local name, texture, isToken, isActive, _, autoCastEnabled, spellID = GetPetActionInfo(index)
	local hasAction = texture ~= nil
	button._hasAction = hasAction
	button._spellID = Plain(spellID)
	if hasAction then
		if Plain(isToken) then texture = _G[texture] end
		button.icon:SetTexture(texture)
		button.icon:Show()
	else
		button.icon:Hide()
	end
	local active = Plain(isActive) == true
	button:SetChecked(false)
	local autoCastOn = hasAction and Plain(autoCastEnabled) == true
	local dimmed
	if hasActionBar == false and hasAction and Plain(name) ~= 'PET_ACTION_FOLLOW' then
		dimmed = true
		active = false
		autoCastOn = false
	else
		dimmed = Plain(GetPetActionSlotUsable(index)) == false
	end
	local tint = dimmed and UNUSABLE_TINT or 1
	button.icon:SetDesaturated(dimmed)
	button.icon:SetVertexColor(tint, tint, tint)
	CooldownFrame_Set(button.cooldown, GetPetActionCooldown(index))
	ActionBars.SyncButtonBorder(button)
	local settings = ActionBars.GetSettings()
	if hasAction and (autoCastOn or active) then
		local chosen = settings.petActiveColor
		local red, green, blue = BUILib.Theme.GetAccent()
		if chosen then red, green, blue = chosen[1], chosen[2], chosen[3] end
		Pixel.SetBorderColor(button, red, green, blue, 1)
	elseif hasAction then
		local color = settings.borderColor
		Pixel.SetBorderColor(button, color[1], color[2], color[3], color[4])
	end
	ActionBars.SyncEmptyButtonAlpha(button)
end

local function UpdateAll()
	if not bar then return end
	local hasActionBar = Plain(PetHasActionBar())
	for index, button in ipairs(bar.buttons) do
		UpdateButton(button, index, hasActionBar)
	end
end

QueueUpdate = BUI.Dispatcher.New(UpdateAll, EVENT_KEY)

local function UpdateCooldowns()
	if not bar then return end
	for index, button in ipairs(bar.buttons) do
		CooldownFrame_Set(button.cooldown, GetPetActionCooldown(index))
	end
end

local function RegisterEvents()
	for _, event in ipairs(UPDATE_EVENTS) do
		BUI.Events:Register(event, EVENT_KEY, QueueUpdate)
	end
	BUI.Events:RegisterUnit('UNIT_PET', 'player', EVENT_KEY, QueueUpdate)
	BUI.Events:RegisterUnit('UNIT_FLAGS', 'pet', EVENT_KEY, QueueUpdate)
	BUI.Events:Register('PET_BAR_UPDATE_COOLDOWN', EVENT_KEY .. '.Cooldown', UpdateCooldowns)
end

function ActionBars.RefreshPetBar()
	local barSettings = ActionBars.GetBarSettings('pet')
	if not barSettings then return end
	if not barSettings.enabled then
		if bar then ActionBars.SetBarActive(bar, false) end
		return
	end
	if not bar then bar = CreateHeader() end
	if #bar.buttons == 0 then
		for index = 1, BUTTON_COUNT do
			bar.buttons[index] = CreateButton(index)
		end
		RegisterEvents()
	end
	local clicks = GetCVarBool('ActionButtonUseKeyDown') and 'AnyDown' or 'AnyUp'
	for _, button in ipairs(bar.buttons) do
		button:RegisterForClicks(clicks)
		button.config.showGrid = not barSettings.hideEmptyButtons
		ActionBars.SkinButton(button)
		button.HotKey:SetShown(barSettings.showHotkey)
		button._formattedHotkey = nil
		ActionBars.ApplyHotkeyText(button)
	end
	ActionBars.LayoutBar(bar)
	ActionBars.PositionBar(bar)
	ActionBars.ApplyBarMouse(bar)
	ActionBars.SetBarActive(bar, true)
	ActionBars.HideBlizzardPetBar()
	UpdateAll()
end
