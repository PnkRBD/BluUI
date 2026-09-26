local _, BUI = ...

local function CenterWindow()
	BUI.PageEngine.Show()
	local frame = BUI.PageEngine.frame
	if not frame then return end
	frame:ClearAllPoints()
	frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	BUI.Print('Window centered.')
end

local function PrintHelp()
	local function line(command, description)
		print('  |cff' .. BUI.C.COLOR_BRAND .. command .. '|r  ' .. description)
	end
	BUI.Print('Commands:')
	line('/bui', 'open/close the settings window')
	line('/bui center', 'recenter the settings window')
	line('/bui ?', 'this help')
	line('/bui install', 'run the setup wizard')
	line('/bui keybind', 'toggle action bar keybind mode (hover a button, press a key)')
	line('/bui currency <id>', 'print the cap fields the game reports for a currency (3418 = Nebulous Voidcore)')
	line('/cdm', "toggle Blizzard's Cooldown Viewer settings")
	line('/rl', 'reload the UI')
	line('/edit', "open Blizzard's Edit Mode")
	line('/buitest', 'toggle unit frame test mode')
end

SLASH_BUI1 = '/bui'
SLASH_BUI2 = '/blu'
SLASH_BUI3 = '/bluui'
SlashCmdList['BUI'] = function(message)
	local command, rest = message:match('^%s*(%S*)%s*(.-)%s*$')
	command = command:lower()

	if command == '?' or command == 'help' then
		PrintHelp()
	elseif command == 'center' then
		CenterWindow()
	elseif command == 'install' then
		BUI.Installer.Open()
	elseif command == 'currency' then
		local id = tonumber(rest)
		if id then BUI.Currency.Dump(id) else BUI.Print('Usage: /bui currency <currency id>') end
	elseif command == 'keybind' or command == 'kb' then
		BUI.ActionBars.ToggleKeybindMode()
	else
		BUI.PageEngine.Toggle()
	end
end

SLASH_BUICDM1 = '/cdm'
SlashCmdList['BUICDM'] = function()
	if not CooldownViewerSettings then
		BUI.Print('CooldownViewerSettings panel not found.')
		return
	end
	C_Timer.After(0, function()
		CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown())
	end)
end

SLASH_BUIRL1 = '/rl'
SlashCmdList['BUIRL'] = ReloadUI

function BUI.ToggleEditMode()
	local manager = EditModeManagerFrame
	if not manager then return end
	if InCombatLockdown() then
		BUI.Print('Edit Mode opens when combat ends.')
		BUI.Events:AfterCombat(BUI.ToggleEditMode, 'Core.ToggleEditMode')
		return
	end
	if manager:IsShown() then
		HideUIPanel(manager)
	else
		ShowUIPanel(manager)
	end
end

SLASH_BUIEDIT1 = '/edit'
SlashCmdList['BUIEDIT'] = BUI.ToggleEditMode

SLASH_BUITEST1 = '/buitest'
SlashCmdList['BUITEST'] = function()
	BUI.UnitFrames.TestMode.Toggle()
end