local _, BUI = ...

local function CenterWindow()
	BUI.PageEngine.Show()
	local frame = BUI.PageEngine.frame
	if not frame then return end
	frame:ClearAllPoints()
	frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	BUI.Print('Window centered.')
end

local function ScaleCommand(option)
	if option ~= 'reset' then
		BUI.Print('/bui scale reset puts the interface scale back to pixel perfect.')
		return
	end
	BUI.Scale.Reset()
	local width, height = GetPhysicalScreenSize()
	BUI.Print(('Scale reset to pixel perfect for %d x %d.'):format(width, height))
end

local function PerfCommand(option)
	if option == 'handlers' then
		BUI.Perf.Handlers()
	elseif option == 'reset' then
		BUI.Perf.Reset()
	elseif option == 'now' then
		BUI.Perf.Report()
	else
		BUI.Perf.Toggle()
	end
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
	line('/bui scale reset', 'put the interface scale back to pixel perfect for your screen')
	line('/bui perf', 'start measuring; type it again after the pull for the report')
	line('/bui perf now', 'BluUI frame time since login')
	line('/bui perf handlers', 'heaviest BluUI handlers and hooks (needs scriptProfile 1 and a reload)')
	line('/bui perf reset', 'restart the handler timers')
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
	elseif command == 'keybind' or command == 'kb' then
		BUI.ActionBars.ToggleKeybindMode()
	elseif command == 'scale' then
		ScaleCommand(rest:lower())
	elseif command == 'party' then
		BUI.Auras.KeystoneReminder.ToggleTest()
	elseif command == 'keys' then
		BUI.Auras.KeystoneReminder.Debug()
	elseif command == 'perf' then
		PerfCommand(rest:lower())
	else
		BUI.PageEngine.Toggle()
	end
end

SLASH_BUICDM1 = '/cdm'
SlashCmdList['BUICDM'] = function()
	C_Timer.After(0, function()
		CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown())
	end)
end

SLASH_BUIRL1 = '/rl'
SlashCmdList['BUIRL'] = ReloadUI

function BUI.ToggleEditMode()
	if InCombatLockdown() then
		BUI.Print('Edit Mode opens when combat ends.')
		BUI.Events:AfterCombat(BUI.ToggleEditMode, 'Core.ToggleEditMode')
		return
	end
	EditModeManagerFrame:SetShown(not EditModeManagerFrame:IsShown())
end

SLASH_BUIEDIT1 = '/edit'
SlashCmdList['BUIEDIT'] = BUI.ToggleEditMode

SLASH_BUITEST1 = '/buitest'
SlashCmdList['BUITEST'] = function()
	BUI.UnitFrames.TestMode.Toggle()
end