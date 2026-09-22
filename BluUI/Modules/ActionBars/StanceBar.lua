local _, BUI = ...
local SetScript = BUI.Prof.Scripts('ActionBars.StanceBar')

local ActionBars = BUI.ActionBars
local Plain = ActionBars.Plain

local BUTTON_COUNT = ActionBars.STANCE_BUTTON_COUNT
local COMMAND = 'SHAPESHIFTBUTTON'
local VISIBILITY = '[petbattle][vehicleui][overridebar][possessbar] hide; show'
local EVENT_KEY = 'ActionBars.StanceBar'
local VISUAL_EVENTS = { 'UPDATE_SHAPESHIFT_FORM', 'UPDATE_SHAPESHIFT_USABLE', 'PLAYER_ENTERING_WORLD' }
local UNUSABLE_TINT = 0.4

local bar

local function OnEnter(button)
	if not button._hasAction then return end
	GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
	GameTooltip:SetShapeshift(button:GetID())
	GameTooltip:Show()
end

local function CreateHeader()
	return ActionBars.RegisterBar({
		key = 'stance',
		kind = 'stance',
		label = ActionBars.BarLabel('stance'),
		command = COMMAND,
		clickButton = 'LeftButton',
		header = ActionBars.CreateHeader('BUI_StanceBar', true),
		buttons = {},
		visibility = VISIBILITY,
	})
end

local function CreateButton(index)
	local button = CreateFrame('CheckButton', 'BUI_StanceBarButton' .. index, bar.header, 'ActionButtonTemplate, SecureActionButtonTemplate')
	button:SetID(index)
	ActionBars.PrepareTemplateButton(button, 'stance', COMMAND .. index)
	button:SetAttribute('type', 'spell')
	SetScript(button, 'OnEnter', OnEnter)
	SetScript(button, 'OnLeave', GameTooltip_Hide)
	ActionBars.SkinButton(button)
	ActionBars.ApplyHotkeyText(button)
	return button
end

local function UpdateButton(button, index)
	local texture, isActive, isCastable, spellID = GetShapeshiftFormInfo(index)
	button._hasAction = true
	button._spellID = Plain(spellID)
	button.icon:SetTexture(texture)
	button.icon:Show()
	button:SetChecked(Plain(isActive) == true)
	local tint = Plain(isCastable) == false and UNUSABLE_TINT or 1
	button.icon:SetVertexColor(tint, tint, tint)
	CooldownFrame_Set(button.cooldown, GetShapeshiftFormCooldown(index))
	ActionBars.SyncButtonBorder(button)
	ActionBars.SyncEmptyButtonAlpha(button)
end

local function UpdateVisuals()
	if not bar then return end
	local formCount = GetNumShapeshiftForms()
	for index, button in ipairs(bar.buttons) do
		if index <= formCount then UpdateButton(button, index) end
	end
end

local QueueVisuals = BUI.Dispatcher.New(UpdateVisuals, EVENT_KEY)

local function UpdateCooldowns()
	if not bar then return end
	local formCount = GetNumShapeshiftForms()
	for index, button in ipairs(bar.buttons) do
		if index <= formCount then CooldownFrame_Set(button.cooldown, GetShapeshiftFormCooldown(index)) end
	end
end

local function RegisterEvents()
	for _, event in ipairs(VISUAL_EVENTS) do
		BUI.Events:Register(event, EVENT_KEY, QueueVisuals)
	end
	BUI.Events:Register('UPDATE_SHAPESHIFT_COOLDOWN', EVENT_KEY .. '.Cooldown', UpdateCooldowns)
	BUI.Events:Register('UPDATE_SHAPESHIFT_FORMS', EVENT_KEY .. '.Forms', function()
		ActionBars.RunSecure('StanceForms', ActionBars.RefreshStanceBar)
	end)
end

function ActionBars.RefreshStanceBar()
	local barSettings = ActionBars.GetBarSettings('stance')
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
	local formCount = math.min(GetNumShapeshiftForms(), BUTTON_COUNT)
	local clicks = GetCVarBool('ActionButtonUseKeyDown') and 'AnyDown' or 'AnyUp'
	for index, button in ipairs(bar.buttons) do
		button:RegisterForClicks(clicks)
		if index <= formCount then
			local _, _, _, spellID = GetShapeshiftFormInfo(index)
			button:SetAttribute('spell', Plain(spellID))
		else
			button:SetAttribute('spell', nil)
		end
		ActionBars.SkinButton(button)
		button.HotKey:SetShown(barSettings.showHotkey)
		button._formattedHotkey = nil
		ActionBars.ApplyHotkeyText(button)
	end
	ActionBars.LayoutBar(bar, formCount)
	ActionBars.SetBarContentHidden(bar, formCount == 0)
	ActionBars.ApplyBarMouse(bar)
	ActionBars.PositionBar(bar)
	ActionBars.SetBarActive(bar, true)
	ActionBars.HideBlizzardStanceBar()
	UpdateVisuals()
end
