local _, BUI = ...

local ActionBars = BUI.ActionBars
local Pixel = BUI.Pixel
local BUILib = BUI.BUILibClient

local VISIBILITY = '[canexitvehicle][possessbar] show; hide'
local ICON_FRACTION = 0.45
local ICON_COLOR = { 0.92, 0.25, 0.25 }
local BACKGROUND_ALPHA = 0.85
local HIGHLIGHT_ALPHA = 0.15

local bar

local function Always() return true end
local function Nothing() return nil end

local function OnEnter(button)
	GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
	GameTooltip:SetText(LEAVE_VEHICLE)
	GameTooltip:Show()
end

local function OnPostClick()
	if InCombatLockdown() then return end
	if UnitOnTaxi('player') then
		TaxiRequestEarlyLanding()
	elseif not CanExitVehicle() then
		CancelPetPossess()
	end
end

local function CreateBar()
	local header = ActionBars.CreateHeader('BUI_VehicleExitBar', true)
	bar = ActionBars.RegisterBar({
		key = 'vehicle',
		kind = 'vehicle',
		label = ActionBars.BarLabel('vehicle'),
		header = header,
		buttons = {},
		visibility = VISIBILITY,
	})

	local button = CreateFrame('Button', 'BUI_VehicleExitButton', header, 'SecureActionButtonTemplate')
	button:SetAttribute('type', 'macro')
	button:SetAttribute('macrotext', '/leavevehicle')
	button:RegisterForClicks('AnyUp')
	button:SetScript('PostClick', OnPostClick)
	button:SetScript('OnEnter', OnEnter)
	button:SetScript('OnLeave', GameTooltip_Hide)

	local background = button:CreateTexture(nil, 'BACKGROUND')
	background:SetAllPoints()
	background:SetTexture(BUI.C.FALLBACK_TEXTURE)
	background:SetVertexColor(0, 0, 0, BACKGROUND_ALPHA)

	local icon = button:CreateTexture(nil, 'ARTWORK')
	icon:SetTexture(BUILib.GetLibMedia('x'))
	icon:SetVertexColor(ICON_COLOR[1], ICON_COLOR[2], ICON_COLOR[3], 1)
	icon:SetPoint('CENTER')
	button.icon = icon

	local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
	highlight:SetAllPoints()
	highlight:SetTexture(BUI.C.FALLBACK_TEXTURE)
	highlight:SetVertexColor(1, 1, 1, HIGHLIGHT_ALPHA)

	button.HasAction = Always
	button.GetSpellId = Nothing
	button._buiBar = 'vehicle'
	button.config = { showGrid = true }
	bar.buttons[1] = button
	return bar
end

local function SkinExitButton(button)
	local settings = ActionBars.GetSettings()
	local color = settings.borderColor
	Pixel.ApplyBorder(button, settings.borderSize, color[1], color[2], color[3], color[4])
	local size = button:GetWidth() * ICON_FRACTION
	button.icon:SetSize(size, size)
end

function ActionBars.RefreshVehicleBar()
	local barSettings = ActionBars.GetBarSettings('vehicle')
	if not barSettings then return end
	if not barSettings.enabled then
		if bar then ActionBars.SetBarActive(bar, false) end
		return
	end
	if not bar then CreateBar() end
	ActionBars.LayoutBar(bar, 1)
	SkinExitButton(bar.buttons[1])
	ActionBars.ApplyBarMouse(bar)
	ActionBars.PositionBar(bar)
	ActionBars.SetBarActive(bar, true)
	ActionBars.HideBlizzardVehicleButton()
end
