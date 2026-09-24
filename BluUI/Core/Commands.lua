local _, BUI = ...

local function CenterWindow()
	BUI.PageEngine.Show()
	local frame = BUI.PageEngine.frame
	if not frame then return end
	frame:ClearAllPoints()
	frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	BUI.Print('Window centered.')
end

local function FrameScan()
	local totalCount, visibleCount = 0, 0
	local counts = {}
	local order = {}
	local frame = EnumerateFrames()
	while frame do
		if frame.GetScript then
			local scriptOk, script = pcall(frame.GetScript, frame, 'OnUpdate')
			if scriptOk and script then
				totalCount = totalCount + 1
				local visibleOk, visible = pcall(frame.IsVisible, frame)
				if visibleOk and visible then
					visibleCount = visibleCount + 1
					local name = frame:GetName()
					if not name and frame.GetDebugName then
						local debugOk, debugName = pcall(frame.GetDebugName, frame)
						if debugOk and debugName and debugName ~= '' and not debugName:find('^<unnamed>') then
							name = debugName
						end
					end
					if not name then
						local parent = frame:GetParent()
						local parentName = parent and parent:GetName()
						local depth = 0
						while parent and not parentName and depth < 8 do
							parent = parent:GetParent()
							parentName = parent and parent:GetName()
							depth = depth + 1
						end
						name = '(anonymous) under ' .. (parentName or 'nil parent')
					end
					if counts[name] then
						counts[name] = counts[name] + 1
					else
						counts[name] = 1
						order[#order + 1] = name
					end
				end
			end
		end
		frame = EnumerateFrames(frame)
	end
	table.sort(order)
	BUI.Print(('OnUpdate frames: %d exist, %d VISIBLE and running every frame:'):format(totalCount, visibleCount))
	for orderIndex = 1, #order do
		local name = order[orderIndex]
		local count = counts[name]
		print('  ' .. name .. (count > 1 and ('  x' .. count) or ''))
	end
end

local function ArtOf(region)
	local atlasOk, atlas = pcall(region.GetAtlas, region)
	if atlasOk and atlas then return atlas end
	local fileOk, file = pcall(region.GetTexture, region)
	if fileOk and file then return tostring(file) end
	return 'none'
end

local function DumpMember(lines, key, value)
	if type(value) ~= 'table' or type(value.GetObjectType) ~= 'function' then return end
	local typeOk, objectType = pcall(value.GetObjectType, value)
	if not typeOk or type(objectType) ~= 'string' then return end
	local shownOk, shown = pcall(value.IsShown, value)
	local alphaOk, alpha = pcall(value.GetAlpha, value)
	local detail = ('shown=%s alpha=%s'):format(shownOk and tostring(shown) or '?', alphaOk and tostring(alpha) or '?')
	if objectType == 'Texture' then detail = detail .. ' art=' .. ArtOf(value) end
	lines[#lines + 1] = ('  .%s = %s %s'):format(tostring(key), objectType, detail)
end

local function ResolvePath(path)
	local object
	for part in tostring(path or ''):gmatch('[^%.]+') do
		if object == nil then object = _G[part] else object = object[part] end
		if type(object) ~= 'table' then return nil end
	end
	return object
end

local function DumpFrame(name)
	local frame = ResolvePath(name)
	if type(frame) ~= 'table' or type(frame.GetObjectType) ~= 'function' then
		BUI.Print('Usage: /bui dump <FrameName>')
		return
	end
	BUI.Print(('%s = %s shown=%s'):format(name, frame:GetObjectType(), tostring(frame:IsShown())))
	local lines = {}
	for key, value in pairs(frame) do DumpMember(lines, key, value) end
	table.sort(lines)
	for index = 1, #lines do print(lines[index]) end
	local regionCount = select('#', frame:GetRegions())
	for index = 1, regionCount do
		local region = select(index, frame:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == 'Texture' then
			print(('  region %d: alpha=%s layer=%s art=%s'):format(index, tostring(region:GetAlpha()), tostring(region:GetDrawLayer()), ArtOf(region)))
		end
	end
	for index, child in ipairs({ frame:GetChildren() }) do
		print(('  child %d: %s %s shown=%s alpha=%s'):format(index, tostring(child:GetName()), child:GetObjectType(), tostring(child:IsShown()), tostring(child:GetAlpha())))
	end
end

local function PrintHelp()
	local function line(command, description)
		print('  |cff6D00FD' .. command .. '|r  ' .. description)
	end
	BUI.Print('Commands:')
	line('/bui', 'open/close the settings window')
	line('/bui center', 'recenter the settings window')
	line('/bui ?', 'this help')
	line('/bui install', 'run the setup wizard')
	line('/bui cpu', 'toggle CPU profiling')
	line('/bui cpu reload', 'reload and profile everything BluUI runs during login')
	line('/bui framescan', 'list every visible frame running an OnUpdate script')
	line('/bui keybind', 'toggle action bar keybind mode (hover a button, press a key)')
	line('/bui currency <id>', 'print the cap fields the game reports for a currency (3418 = Nebulous Voidcore)')
	line('/bui dump <frame>', 'print a frame\'s parentKeys, textures and children')
	line('/cdm', "toggle Blizzard's Cooldown Viewer settings")
	line('/cdm cpu', 'toggle CPU profiling for just the cooldown manager, split by viewer (same as /bui cpu cdm)')
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
		if BUI.Installer then BUI.Installer.Open() end
	elseif command == 'framescan' then
		FrameScan()
	elseif command == 'cpu' then
		if rest:lower() == 'reload' then
			BluUI_DB.__profileNextLoad = true
			BUI.Reload()
		elseif rest:lower() == 'login' then
			BluUI_DB.__profileNextLoad = true
			BUI.Print('Profiler armed for the next login. Log out to the character screen and back in.')
		elseif rest:lower() == 'cdm' or BUI.CDM.Profiler.IsRunning() then
			BUI.CDM.Profiler.Toggle()
		elseif BUI.Prof.active then
			BUI.Prof.Stop()
			BUI.Prof.Report(30)
		else
			BUI.Prof.Start()
			BUI.Print('CPU profiler running. Do a pull, then /bui cpu again for the report.')
		end
	elseif command == 'currency' then
		local id = tonumber(rest)
		if id then BUI.Currency.Dump(id) else BUI.Print('Usage: /bui currency <currency id>') end
	elseif command == 'dump' then
		DumpFrame(rest)
	elseif command == 'keybind' or command == 'kb' then
		BUI.ActionBars.ToggleKeybindMode()
	else
		BUI.PageEngine.Toggle()
	end
end

SLASH_BUICDM1 = '/cdm'
SlashCmdList['BUICDM'] = function(message)
	if message:match('^%s*(%S*)'):lower() == 'cpu' then
		BUI.CDM.Profiler.Toggle()
		return
	end
	if not CooldownViewerSettings then
		BUI.Print('CooldownViewerSettings panel not found.')
		return
	end
	BUI.Prof.After('Core.Commands', 0, function()
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
