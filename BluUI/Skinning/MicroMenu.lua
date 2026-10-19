local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local PLATE_INSET = { left = 4, right = 4, top = 4, bottom = 3 }
local BUTTON_ART = { 'Background', 'PushedBackground', 'Shadow', 'PushedShadow' }
local LATENCY = { texture = 'Interface/Buttons/WHITE8X8', side = 2, bottom = 2, height = 2 }
local BLIZZARD_LATENCY = { texture = 'Interface/MainMenuBar/UI-MainMenuBar-PerformanceBar', width = 19, height = 39, y = -2 }

local context = Skin.Define('microbuttons', {
	name = 'Micro Menu',
	description = 'The row of game menu buttons: flat tiles with a thin border, lit on hover and while their window is open.',
	icon = 'Interface/Icons/INV_Misc_Gear_01',
})

local function MicroButtons()
	local buttons = {}
	for index, info in ipairs(MicroMenu:GenerateButtonInfos()) do buttons[index] = info.button end
	return buttons
end

local function SyncActive(button)
	Skin.SetActiveEdge(button, button.PushedBackground:IsShown())
end

local function LatencyBar()
	return MainMenuMicroButton and MainMenuMicroButton.MainMenuBarPerformanceBar
end

local function PlaceLatency()
	local bar = LatencyBar()
	if not bar then return end
	local button = MainMenuMicroButton
	local y = PLATE_INSET.bottom + LATENCY.bottom
	bar:SetTexture(LATENCY.texture)
	bar:ClearAllPoints()
	bar:SetPoint('BOTTOMLEFT', button, 'BOTTOMLEFT', PLATE_INSET.left + LATENCY.side, y)
	bar:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -(PLATE_INSET.right + LATENCY.side), y)
	bar:SetHeight(BUI.Pixel.PixelSizeFor(button, LATENCY.height))
end

local function RestoreLatency()
	local bar = LatencyBar()
	if not bar then return end
	bar:SetTexture(BLIZZARD_LATENCY.texture)
	bar:ClearAllPoints()
	bar:SetPoint('BOTTOM', MainMenuMicroButton, 'BOTTOM', 0, BLIZZARD_LATENCY.y)
	bar:SetSize(BLIZZARD_LATENCY.width, BLIZZARD_LATENCY.height)
end

local function SkinMicroMenu()
	for _, button in ipairs(MicroButtons()) do
		context.FadeKeys(button, BUTTON_ART)
		context.Card(button, PLATE_INSET)
		SyncActive(button)
	end
	PlaceLatency()
end

local function InstallMicroMenu()
	for _, button in ipairs(MicroButtons()) do
		context.Hook(button, 'SetPushed', SyncActive)
		context.Hook(button, 'SetNormal', SyncActive)
	end
end

context.Window('MicroMenu', { install = InstallMicroMenu, enable = SkinMicroMenu })
context.OnDisable(RestoreLatency)
