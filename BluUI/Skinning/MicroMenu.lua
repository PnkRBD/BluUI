local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local PLATE_INSET = { left = 4, right = 4, top = 4, bottom = 3 }
local BUTTON_ART = { 'Background', 'PushedBackground', 'Shadow', 'PushedShadow' }

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

local function SkinMicroMenu()
	for _, button in ipairs(MicroButtons()) do
		context.FadeKeys(button, BUTTON_ART)
		context.Card(button, PLATE_INSET)
		SyncActive(button)
	end
end

local function InstallMicroMenu()
	for _, button in ipairs(MicroButtons()) do
		context.Hook(button, 'SetPushed', SyncActive)
		context.Hook(button, 'SetNormal', SyncActive)
	end
end

context.Window('MicroMenu', { install = InstallMicroMenu, enable = SkinMicroMenu })
