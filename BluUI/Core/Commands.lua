local _, BUI = ...

local function CenterWindow()
	BUI.PageEngine.Show()
	local frame = BUI.PageEngine.frame
	if not frame then return end
	frame:ClearAllPoints()
	frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	BUI.Print('Window centered.')
end

local function ShowReport(title, lines, preview)
	for index = 1, preview do print(lines[index]) end
	BUI.BUILibClient.Modals.Copy({
		title = title,
		message = 'The full report is selected. Press Ctrl+C to copy it.',
		text = table.concat(lines, ' || '),
		fullscreen = true,
	})
end

local function ShowProfile()
	ShowReport('Profile report', BUI.Profiler.Report())
end

local function ShowCDMProfile()
	local lines, preview = BUI.CDMProfiler.Report()
	if not lines then
		BUI.Print('No CDM profile yet. /bui cdm to start one.')
		return
	end
	ShowReport('CDM profile', lines, preview)
end

local function CDMCommand(option)
	local CDMProfiler = BUI.CDMProfiler
	if option == 'report' then
		ShowCDMProfile()
	elseif option == 'reset' then
		CDMProfiler.Reset()
		BUI.Print(CDMProfiler.IsRunning() and 'CDM numbers cleared, still profiling.' or 'CDM numbers cleared.')
	elseif CDMProfiler.IsRunning() then
		CDMProfiler.Stop()
		BUI.Print('CDM profiling stopped.')
		ShowCDMProfile()
	elseif CDMProfiler.Start() then
		BUI.Print('CDM profiling started. /bui cdm to stop.')
	end
end

local function ProfileCommand(option)
	local Profiler = BUI.Profiler
	if option == 'login' then
		BUI.db.global.profileNextLogin = true
		ReloadUI()
	elseif option == 'report' then
		ShowProfile()
	elseif option == 'alerts' then
		local global = BUI.db.global
		global.profileAlerts = not global.profileAlerts or nil
		BUI.Print(global.profileAlerts and 'Slow frame alerts on (100ms or more).' or 'Slow frame alerts off.')
	elseif Profiler.active then
		Profiler.Stop()
		BUI.Print('Profiling stopped.')
		ShowProfile()
	else
		Profiler.Start()
		BUI.Print('Profiling started. /bui profile to stop.')
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
	line('/bui profile', 'start or stop timing BluUI, the report opens when you stop')
	line('/bui profile report', 'show the timings so far without stopping')
	line('/bui profile login', 'reload and time everything from login onwards')
	line('/bui profile alerts', 'say in chat whenever BluUI takes 100ms or more in one frame')
	line('/bui cdm', 'start or stop counting what the Cooldown Manager does, the report opens when you stop')
	line('/bui cdm report', 'show the CDM report again, or so far if it is still running')
	line('/bui cdm reset', 'clear the CDM numbers and keep going')
	line('/bui trace', 'reload and record everything BluUI runs in the first 20 seconds, then show it')
	line('/bui trace show', 'show the last launch trace again')
	line('/cdm', "toggle Blizzard's Cooldown Viewer settings")
	line('/rl', 'reload the UI')
	line('/edit', "open Blizzard's Edit Mode")
	line('/buitest', 'toggle unit frame test mode')
end

SLASH_BUI1 = '/bui'
SLASH_BUI2 = '/blu'
SLASH_BUI3 = '/bluui'
SlashCmdList['BUI'] = BUI.Profiler.Wrap('Core.Commands /bui', function(message)
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
	elseif command == 'profile' then
		ProfileCommand(rest:lower())
	elseif command == 'cdm' then
		CDMCommand(rest:lower())
	elseif command == 'trace' then
		if rest:lower() == 'show' then BUI.LaunchTrace.Show() else BUI.LaunchTrace.Start() end
	else
		BUI.PageEngine.Toggle()
	end
end)

SLASH_BUICDM1 = '/cdm'
SlashCmdList['BUICDM'] = function()
	if not CooldownViewerSettings then
		BUI.Print('CooldownViewerSettings panel not found.')
		return
	end
	BUI.Profiler.After('Core.Commands toggle cdm', 0, function()
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