local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Layout, Modals, Widget = BUILib.Controls, BUILib.Layout, BUILib.Modals, BUILib.Widget

local PAGE_WIDTH = 960
local RAIL_GROUPS = {
	{ title = 'Game', items = {
		{ id = 'combat', label = 'Combat', icon = 'power' },
		{ id = 'interface', label = 'Interface', icon = 'eye' },
		{ id = 'automation', label = 'Automation', icon = 'reload' },
		{ id = 'mythicplus', label = 'Mythic+', icon = 'clock' },
	} },
	{ title = 'System', items = {
		{ id = 'graphics', label = 'Graphics', icon = 'checker' },
		{ id = 'danger', label = 'Danger zone', icon = 'skull' },
	} },
}
local TAB_IDS = { 'combat', 'interface', 'automation', 'graphics', 'danger', 'mythicplus' }
local TAB_INDEX = {}
for index, id in ipairs(TAB_IDS) do TAB_INDEX[id] = index end
local SLIDER_WIDTH = 220
local BUTTON_ROOM = 130
local STATUS_ROOM = 120
local BUTTON_GAP = 10
local GATE_WIDTH = 420
local GATE_BLEED = 8
local DIALOG_WIDTH, DIALOG_HEIGHT = 660, 720
local DIALOG_PAD = 24
local LIST_TOP = 76
local LIST_BOTTOM = 66
local SCROLL_ROOM = 28
local ROW_ROOM = 220
local READOUT_GAP = 16
local ARROW_SIZE = 10
local ARROW_GAP = 8
local DANGER_CARD = 160
local DANGER_EDGE_ALPHA = 0.5
local DANGER_VALUE_Y = 44
local DANGER_VALUE_SIZE = 30
local DANGER_NOTE_Y = 84
local DANGER_BUTTON_Y = 16
local DANGER_HEAD_GAP = 16
local ACCOUNT_MACRO_SLOTS = 120
local CHARACTER_MACRO_SLOTS = 18

local BOARDS = {
	combat = { title = 'Combat', description = 'The numbers that float up over your target, casting feel, the keystone slot and how early the next spell queues.', headers = { 'Target Combat Text', 'Casting' } },
	logging = { title = 'Combat logging', description = 'Start a combat log on its own in the content you pick, with a small indicator while it runs.', headers = { 'Combat Logging' } },
	interface = { title = 'Interface', description = 'Blizzard frames and messages you would rather not see, and a faster item delete.', headers = { 'Interface' } },
	automation = { title = 'Automation', description = 'Loot, sell, repair, quest and accept invites without the clicks. Hold shift at a vendor or quest giver to skip it once.', headers = { 'Looting', 'Merchant', 'Questing', 'Auction House', 'Social' } },
}

local FPS_CVARS = {
	vsync = '0', LowLatencyMode = '3', MSAAQuality = '0',
	ffxAntiAliasingMode = '0', alphaTestMSAA = '1', cameraFov = '90',
	graphicsQuality = '9', graphicsShadowQuality = '0',
	graphicsLiquidDetail = '1', graphicsParticleDensity = '5',
	graphicsSSAO = '0', graphicsDepthEffects = '0',
	graphicsComputeEffects = '0', graphicsOutlineMode = '1',
	OutlineEngineMode = '1', graphicsTextureResolution = '2',
	graphicsSpellDensity = '0', spellClutter = '1',
	spellVisualDensityFilterSetting = '1',
	graphicsProjectedTextures = '1', projectedTextures = '1',
	graphicsViewDistance = '3', graphicsEnvironmentDetail = '0',
	graphicsGroundClutter = '0',
	gxTripleBuffer = '0', textureFilteringMode = '5',
	graphicsRayTracedShadows = '0', rtShadowQuality = '0',
	ResampleQuality = '4', ffxSuperResolution = '1',
	VRSMode = '0', physicsLevel = '0',
	maxFPS = '144', maxFPSBk = '60',
	targetFPS = '61', useTargetFPS = '0',
	ResampleSharpness = '0.2',
	Brightness = '50', Gamma = '1',
	particulatesEnabled = '0', clusteredShading = '0',
	volumeFogLevel = '0', reflectionMode = '0', ffxGlow = '0',
	farclip = '5000', horizonStart = '1000', horizonClip = '5000',
	lodObjectCullSize = '35', lodObjectFadeScale = '50',
	lodObjectMinSize = '0', doodadLodScale = '50',
	entityLodDist = '7', terrainLodDist = '350', TerrainLodDiv = '512',
	waterDetail = '1', rippleDetail = '0', weatherDensity = '3',
	entityShadowFadeScale = '15', groundEffectDist = '40',
	ResampleAlwaysSharpen = '1',
	cameraDistanceMaxZoomFactor = '2.6',
	CameraReduceUnexpectedMovement = '1',
}

local FPS_CVAR_GROUPS = {
	{ label = 'Shadows', cvars = { 'graphicsShadowQuality', 'graphicsRayTracedShadows', 'rtShadowQuality', 'entityShadowFadeScale' } },
	{ label = 'Anti-aliasing', cvars = { 'MSAAQuality', 'ffxAntiAliasingMode', 'alphaTestMSAA' } },
	{ label = 'View distance', cvars = { 'graphicsViewDistance', 'farclip', 'horizonStart', 'horizonClip' } },
	{ label = 'Ground clutter', cvars = { 'graphicsGroundClutter', 'graphicsEnvironmentDetail', 'doodadLodScale', 'groundEffectDist' } },
	{ label = 'Particles and spell density', cvars = { 'graphicsParticleDensity', 'graphicsSpellDensity', 'spellClutter', 'spellVisualDensityFilterSetting', 'particulatesEnabled' } },
	{ label = 'Lighting and reflections', cvars = { 'graphicsSSAO', 'graphicsDepthEffects', 'graphicsComputeEffects', 'volumeFogLevel', 'reflectionMode', 'ffxGlow', 'clusteredShading' } },
	{ label = 'Water and weather', cvars = { 'graphicsLiquidDetail', 'waterDetail', 'rippleDetail', 'weatherDensity' } },
	{ label = 'Textures', cvars = { 'graphicsTextureResolution', 'textureFilteringMode' } },
	{ label = 'Frame rate cap', cvars = { 'maxFPS', 'maxFPSBk', 'targetFPS', 'useTargetFPS' } },
	{ label = 'Camera', cvars = { 'cameraFov', 'cameraDistanceMaxZoomFactor', 'CameraReduceUnexpectedMovement' } },
}

local GATE_TEXT = 'These tools permanently delete loadouts, macros or quests, or put every BluUI setting back to default. There is no undo.\n\nBy clicking below, I solemnly swear not to cry in Discord when my stuff disappears because I clearly cannot read.'

local function Window()
	return BUI.PageEngine.window
end

local function PrintTalents(message)
	print('|cff' .. BUI.C.COLOR_BRAND .. 'BUI/Talents:|r ' .. message)
end

local function Confirm(title, message, confirmText, onConfirm)
	Modals.Confirm({ parent = Window().frame, title = title, message = message, confirmText = confirmText, cancelText = 'Cancel', onConfirm = onConfirm })
end

local function SectionNamed(header)
	for _, section in ipairs(BUI.Settings.checkboxSections) do
		if section.header == header then return section end
	end
end

local function Read(item)
	if item.fct then return BUI.Settings.GetFCTBool(item.cvar) end
	if item.cvarInit then return C_CVar.GetCVarBool(item.cvarInit) end
	local value = BUI.GetDB()[item.db][item.key]
	if value == nil and item.cvar then return C_CVar.GetCVarBool(item.cvar) end
	return value
end

local function Write(item, checked)
	if item.fct then
		BUI.Settings.SetFCT(item.cvar, checked and 1 or 0)
		return
	end
	BUI.GetDB()[item.db][item.key] = checked
	if item.toggle then
		BUI.Settings[item.toggle](BUI.Settings, checked)
	elseif item.fn then
		BUI.Settings[item.fn](BUI.Settings, checked)
	elseif item.cvar then
		C_CVar.SetCVar(item.cvar, checked and '1' or '0')
	end
end

local function ReadNumber(item)
	if item.fct then return tonumber(BUI.Settings.GetFCT(item.cvar)) end
	return BUI.GetDB()[item.db][item.key] or tonumber(C_CVar.GetCVar(item.cvarInit))
end

local function WriteNumber(item, value)
	if item.fct then
		BUI.Settings.SetFCT(item.cvar, value)
		return
	end
	BUI.GetDB()[item.db][item.key] = value
	BUI.Settings[item.fn](BUI.Settings, value)
end

local function Slider(ui, row, min, max, step, get, set)
	ui.Slider(row, SLIDER_WIDTH, { min = min, max = max, step = step, get = get, set = set }):SetPoint('RIGHT', -ui.ROW_INSET, 0)
end

local function SameCVarValue(current, target)
	local currentNumber, targetNumber = tonumber(current), tonumber(target)
	if currentNumber and targetNumber then return currentNumber == targetNumber end
	return current == target
end

local function PendingCVars()
	local pending, total, known = {}, 0, 0
	for cvar, value in pairs(FPS_CVARS) do
		local current = C_CVar.GetCVar(cvar)
		if current then
			known = known + 1
			if not SameCVarValue(current, value) then
				pending[cvar] = current
				total = total + 1
			end
		end
	end
	return pending, total, known
end

local function GroupedCVars()
	local remaining = {}
	for cvar in pairs(FPS_CVARS) do remaining[cvar] = true end
	local groups = {}
	for _, group in ipairs(FPS_CVAR_GROUPS) do
		local cvars = {}
		for _, cvar in ipairs(group.cvars) do
			if remaining[cvar] then
				cvars[#cvars + 1] = cvar
				remaining[cvar] = nil
			end
		end
		groups[#groups + 1] = { label = group.label, cvars = cvars }
	end
	local others = {}
	for cvar in pairs(remaining) do others[#others + 1] = cvar end
	table.sort(others)
	groups[#groups + 1] = { label = 'Other', cvars = others }
	return groups
end

local PRESET_GROUPS = GroupedCVars()

local function BackupCVars()
	local globalDB = BUI.db.global
	globalDB.cvarBackup = globalDB.cvarBackup or {}
	for cvar in pairs(FPS_CVARS) do
		local current = C_CVar.GetCVar(cvar)
		if current and not globalDB.cvarBackup[cvar] then globalDB.cvarBackup[cvar] = current end
	end
end

local function SetSelected(selected, Target, report)
	BackupCVars()
	local changed, failed = 0, 0
	for cvar in pairs(selected) do
		local current, target = C_CVar.GetCVar(cvar), Target(cvar)
		if current and target and not SameCVarValue(current, target) then
			if C_CVar.SetCVar(cvar, target) then changed = changed + 1 else failed = failed + 1 end
		end
	end
	local message = report:format(changed)
	if failed > 0 then message = message .. (' %d could not be set.'):format(failed) end
	BUI.Print(message)
	Window():Repaint()
end

local function ApplyPreset(selected)
	SetSelected(selected, function(cvar) return FPS_CVARS[cvar] end, 'Changed %d graphics settings to the preset. Originals backed up.')
end

local function ApplyDefaults(selected)
	SetSelected(selected, C_CVar.GetCVarDefault, 'Put %d graphics settings back to Blizzard defaults. Originals backed up.')
end

local function Selected(picked)
	local chosen = {}
	for cvar, on in pairs(picked) do
		if on then chosen[cvar] = true end
	end
	return chosen
end

local function Readout(kit, row, anchor, current, preset, changed)
	local now = kit.Text(row, current, 12, 'text')
	if not changed then
		now:SetPoint('RIGHT', anchor, 'LEFT', -READOUT_GAP, 0)
		return
	end
	local target = kit.Text(row, preset, 12, 'accent')
	target:SetPoint('RIGHT', anchor, 'LEFT', -READOUT_GAP, 0)
	local arrow = kit.Glyph(row, 'dropdown', ARROW_SIZE, 'faint')
	arrow:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
	arrow:SetPoint('RIGHT', target, 'LEFT', -ARROW_GAP, 0)
	now:SetPoint('RIGHT', arrow, 'LEFT', -ARROW_GAP, 0)
end

local function ShowPresetDialog()
	local window = Window()
	local kit = Layout.TableKit(window)
	local overlay, dialog, Close = Modals.CreateBase(DIALOG_WIDTH, DIALOG_HEIGHT, true, window.frame)
	local title = Modals.CreateTitle(dialog, 'FPS preset')
	local summary = Modals.CreateMessage(dialog, '', 'LEFT', title, -6)
	local listWidth = DIALOG_WIDTH - DIALOG_PAD * 2
	local boardWidth = listWidth - SCROLL_ROOM
	local list = Controls.ScrollFrame(dialog, listWidth, DIALOG_HEIGHT - LIST_TOP - LIST_BOTTOM, 1, boardWidth)
	Widget.Unwrap(list):SetPoint('TOPLEFT', DIALOG_PAD, -LIST_TOP)

	local picked, switches, differs = {}, {}, {}
	local total, differing = 0, 0
	local function RefreshSummary()
		local count = 0
		for _, on in pairs(picked) do
			if on then count = count + 1 end
		end
		summary:SetText(('%d of %d differ from the preset  ·  %d selected'):format(differing, total, count))
	end
	local function Select(Pick)
		for cvar, switch in pairs(switches) do
			picked[cvar] = Pick(cvar)
			switch.Refresh()
		end
		RefreshSummary()
	end

	local board = kit.Board(list.child, boardWidth, {
		stacked = true,
		title = 'Settings in the preset',
		description = "Switch on the ones to change. Apply sets them to the preset value, Blizzard defaults puts them back to the game's own value.",
		buttons = {
			{ text = 'Changed', onClick = function() Select(function(cvar) return differs[cvar] end) end },
			{ text = 'All', onClick = function() Select(function() return true end) end },
			{ text = 'None', onClick = function() Select(function() return false end) end },
		},
	})
	for _, group in ipairs(PRESET_GROUPS) do
		local entries = {}
		for _, cvar in ipairs(group.cvars) do
			local current = C_CVar.GetCVar(cvar)
			if current then entries[#entries + 1] = { cvar = cvar, current = current } end
		end
		if #entries > 0 then board:AddCaption(group.label) end
		for _, entry in ipairs(entries) do
			local cvar, current, preset = entry.cvar, entry.current, FPS_CVARS[cvar]
			local changed = not SameCVarValue(current, preset)
			differs[cvar] = changed
			picked[cvar] = changed
			total = total + 1
			if changed then differing = differing + 1 end
			local default = C_CVar.GetCVarDefault(cvar)
			local sub = default and ('Blizzard default ' .. default) or ''
			if not changed then sub = default and ('At the preset  ·  ' .. sub) or 'At the preset' end
			local row = board:AddRow(cvar, sub, ROW_ROOM)
			local switch = kit.Switch(row, function() return picked[cvar] end, function(value)
				picked[cvar] = value
				RefreshSummary()
			end)
			switch:SetPoint('RIGHT', -kit.ROW_INSET, 0)
			switches[cvar] = switch
			Readout(kit, row, switch, current, preset, changed)
		end
	end
	list:SetChildHeight(board:Layout(0, ''))
	RefreshSummary()

	Modals.LayoutButtons(dialog, {
		{ text = 'Apply', color = Modals.BTN_CONFIRM, onClick = function(close) close(); ApplyPreset(Selected(picked)) end },
		{ text = 'Blizzard defaults', color = Modals.BTN_NEUTRAL, onClick = function(close) close(); ApplyDefaults(Selected(picked)) end },
		{ text = 'Cancel', color = Modals.BTN_CANCEL, onClick = function(close) close() end },
	}, Close)
	overlay:Show()
end

local function RestoreFPS()
	local globalDB = BUI.db.global
	if not globalDB.cvarBackup or not next(globalDB.cvarBackup) then
		BUI.Print('No backup found, apply the FPS preset first.')
		return
	end
	local restored = 0
	for cvar, value in pairs(globalDB.cvarBackup) do
		local current = C_CVar.GetCVar(cvar)
		if current and not SameCVarValue(current, tostring(value)) and C_CVar.SetCVar(cvar, tostring(value)) then restored = restored + 1 end
	end
	globalDB.cvarBackup = nil
	BUI.Print('Restored ' .. restored .. ' settings to their original values.')
	Window():Repaint()
end

local function CreateTestLoadouts()
	if InCombatLockdown() then
		BUI.Print('Cannot create loadouts in combat.')
		return
	end
	if not C_AddOns.IsAddOnLoaded('Blizzard_PlayerSpells') then
		C_AddOns.LoadAddOn('Blizzard_PlayerSpells')
	end
	C_Timer.After(0.2, function()
		local timeStamp = tostring(time())
		local loadoutIndex = 0
		local pending = false
		local createNext

		local watcher = CreateFrame('Frame')
		watcher:RegisterEvent('TRAIT_CONFIG_CREATED')
		watcher:SetScript('OnEvent', function()
			if pending then
				pending = false
				C_Timer.After(0.3, createNext)
			end
		end)

		createNext = function()
			loadoutIndex = loadoutIndex + 1
			if loadoutIndex > 10 then
				watcher:UnregisterAllEvents()
				watcher:SetScript('OnEvent', nil)
				PrintTalents('Create batch done.')
				if PlayerSpellsFrame and PlayerSpellsFrame:IsShown() and not InCombatLockdown() then
					HideUIPanel(PlayerSpellsFrame)
					ShowUIPanel(PlayerSpellsFrame)
				end
				return
			end
			local name = ('test_%s_%d'):format(timeStamp, loadoutIndex)
			local success = C_ClassTalents.RequestNewConfig(name)
			PrintTalents(('RequestNewConfig("%s") -> %s'):format(name, tostring(success)))
			if success then
				pending = true
			else
				C_Timer.After(0.3, createNext)
			end
		end

		createNext()
	end)
end

local function DeleteLoadouts()
	if InCombatLockdown() then
		BUI.Print('Cannot delete loadouts in combat.')
		return
	end
	Confirm('Delete Talent Loadouts', 'Delete every talent loadout for this spec? Other specs must be cleaned from those specs.', 'Delete', function()
		if not C_AddOns.IsAddOnLoaded('Blizzard_PlayerSpells') then
			PrintTalents('Loading Blizzard_PlayerSpells...')
			C_AddOns.LoadAddOn('Blizzard_PlayerSpells')
		end

		C_Timer.After(0.2, function()
			local specID = PlayerUtil.GetCurrentSpecID()
			if not specID then
				PrintTalents('ERROR: no current spec.')
				return
			end

			local activeID = C_ClassTalents.GetActiveConfigID()
			local before = C_ClassTalents.GetConfigIDsBySpecID(specID) or {}
			PrintTalents(('Spec %d, %d loadout(s), active=%s'):format(specID, #before, tostring(activeID)))

			if #before == 0 then
				PrintTalents('No loadouts on current spec.')
				return
			end

			local NameOfConfig = function(configID)
				local info = C_Traits.GetConfigInfo(configID)
				return info and info.name or '?'
			end
			for configIndex, configID in ipairs(before) do
				local tag = (configID == activeID) and ' [ACTIVE]' or ''
				PrintTalents(('  [%d] id=%s name="%s"%s'):format(configIndex, tostring(configID), NameOfConfig(configID), tag))
			end

			local deleteIndex = 1
			local pending = nil
			local deleteNext

			local watcher = CreateFrame('Frame')
			watcher:RegisterEvent('TRAIT_CONFIG_DELETED')

			local function finish()
				watcher:UnregisterAllEvents()
				watcher:SetScript('OnEvent', nil)
				C_Timer.After(0.3, function()
					local after = C_ClassTalents.GetConfigIDsBySpecID(specID) or {}
					local actuallyDeleted = #before - #after
					PrintTalents(('Final: %d of %d deleted, %d remain.'):format(actuallyDeleted, #before, #after))
					for configIndex, configID in ipairs(after) do
						PrintTalents(('  REMAIN [%d] id=%s name="%s"'):format(configIndex, tostring(configID), NameOfConfig(configID)))
					end
					if PlayerSpellsFrame and PlayerSpellsFrame:IsShown() and not InCombatLockdown() then
						HideUIPanel(PlayerSpellsFrame)
						ShowUIPanel(PlayerSpellsFrame)
						PrintTalents('Dropdown refreshed.')
					end
				end)
			end

			deleteNext = function()
				local configID = before[deleteIndex]
				deleteIndex = deleteIndex + 1
				if not configID then
					finish()
					return
				end
				pending = configID
				local success = C_ClassTalents.DeleteConfig(configID)
				PrintTalents(('DeleteConfig(%s "%s") -> %s'):format(tostring(configID), NameOfConfig(configID), tostring(success)))
				if not success then
					pending = nil
					C_Timer.After(0.3, deleteNext)
				end
			end

			watcher:SetScript('OnEvent', function(_, _, configID)
				if configID == pending then
					pending = nil
					C_Timer.After(0.3, deleteNext)
				end
			end)

			deleteNext()
		end)
	end)
end

local function DeleteGeneralMacros()
	Confirm('Delete General Macros', 'This will delete ALL account-wide (General) macros. This cannot be undone.', 'Delete', function()
		local generalMacroCount = GetNumMacros()
		for macroIndex = generalMacroCount, 1, -1 do
			DeleteMacro(macroIndex)
		end
		BUI.Print(('Deleted %d general macro(s).'):format(generalMacroCount))
	end)
end

local function DeleteCharacterMacros()
	Confirm('Delete Character Macros', 'This will delete ALL character-specific macros on this toon. This cannot be undone.', 'Delete', function()
		local _, characterMacroCount = GetNumMacros()
		for macroIndex = ACCOUNT_MACRO_SLOTS + characterMacroCount, ACCOUNT_MACRO_SLOTS + 1, -1 do
			DeleteMacro(macroIndex)
		end
		BUI.Print(('Deleted %d character macro(s).'):format(characterMacroCount))
	end)
end

local function AbandonQuests()
	if InCombatLockdown() then
		BUI.Print('Cannot abandon quests in combat.')
		return
	end
	Confirm('Abandon All Quests', 'This will abandon every quest in your log that can be abandoned. Campaign and account quests will be skipped. This cannot be undone.', 'Abandon', function()
		local queue, seen = {}, {}
		for entryIndex = 1, C_QuestLog.GetNumQuestLogEntries() do
			local info = C_QuestLog.GetInfo(entryIndex)
			local questID = info and not info.isHeader and info.questID
			if questID and not seen[questID] and C_QuestLog.CanAbandonQuest(questID) then
				seen[questID] = true
				queue[#queue + 1] = questID
			end
		end

		if #queue == 0 then
			BUI.Print('Quest log already clear.')
			return
		end

		local confirmed = 0
		local watcher = CreateFrame('Frame')
		watcher:RegisterEvent('QUEST_REMOVED')
		watcher:SetScript('OnEvent', function(_, _, questID)
			if seen[questID] then
				confirmed = confirmed + 1
				seen[questID] = nil
			end
		end)

		local queueIndex = 1
		C_Timer.NewTicker(0.05, function(ticker)
			local questID = queue[queueIndex]
			queueIndex = queueIndex + 1
			if not questID then
				ticker:Cancel()
				C_Timer.After(0.5, function()
					watcher:UnregisterAllEvents()
					watcher:SetScript('OnEvent', nil)
					if confirmed == 0 then
						BUI.Print('Quest log already clear.')
					else
						BUI.Print(('Abandoned %d quest(s).'):format(confirmed))
					end
				end)
				return
			end
			C_QuestLog.SetSelectedQuest(questID)
			C_QuestLog.SetAbandonQuest()
			C_QuestLog.AbandonQuest()
		end)
	end)
end

local function ResetSettings()
	Confirm('Reset All Settings', 'This will reset ALL BluUI settings to their defaults. This cannot be undone.', 'Reset', function()
		BUI.GetAceDB():ResetDB()
		ReloadUI()
	end)
end

local function SettingBoard(ui, parent, width, spec)
	BUI.Settings._pageToggles = BUI.Settings._pageToggles or {}
	local board = ui.Board(parent, width, { title = spec.title, description = spec.description })
	local captions = #spec.headers > 1
	for _, header in ipairs(spec.headers) do
		if captions then board:AddCaption(header) end
		local wide = {}
		for _, item in ipairs(SectionNamed(header).items) do
			if item.type then
				wide[#wide + 1] = item
			else
				local switch = board:AddSwitch(item.label, function() return Read(item) end, function(checked) Write(item, checked) end)
				if item.key then BUI.Settings._pageToggles[item.key] = switch.Refresh end
			end
		end
		for _, item in ipairs(wide) do
			if item.type == 'slider' then
				local row = board:AddRow(item.label, item.sub, SLIDER_WIDTH)
				Slider(ui, row, item.min, item.max, item.step, function() return ReadNumber(item) end, function(value) WriteNumber(item, value) end)
			else
				local row = board:AddRow(item.label, item.sub, BUTTON_ROOM)
				ui.Button(row, item.buttonText, 'control', function() BUI.Settings[item.fn](BUI.Settings) end):SetPoint('RIGHT', -ui.ROW_INSET, 0)
			end
		end
	end
	return board
end

local function GraphicsBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		title = 'Graphics',
		description = 'A performance preset for the graphics CVars. Your current values are backed up the first time it is applied, and Restore puts them back.',
		buttons = {
			{ text = 'Restore', icon = 'reset', onClick = RestoreFPS },
			{ style = 'primary', text = 'Apply preset', onClick = ShowPresetDialog },
		},
	})
	local row = board:AddRow('FPS preset', 'Shadows, distance, particles and more', STATUS_ROOM)
	local status = ui.Text(row, '', 11, 'muted')
	status:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(row, function()
		local _, total, known = PendingCVars()
		status:SetText(total == 0 and 'At the preset' or (total .. ' of ' .. known .. ' differ'))
	end)
	return board
end

local function LoadoutCount()
	local specID = PlayerUtil.GetCurrentSpecID()
	if not specID then return 0 end
	return #(C_ClassTalents.GetConfigIDsBySpecID(specID) or {})
end

local function AbandonableCount()
	local seen, count = {}, 0
	for entryIndex = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(entryIndex)
		local questID = info and not info.isHeader and info.questID
		if questID and not seen[questID] and C_QuestLog.CanAbandonQuest(questID) then
			seen[questID] = true
			count = count + 1
		end
	end
	return count
end

local function Plural(count, singular, plural)
	return count == 1 and singular or plural
end

local DANGER_CARDS = {
	loadouts = {
		title = 'Talent loadouts',
		events = { 'TRAIT_CONFIG_LIST_UPDATED', 'TRAIT_CONFIG_CREATED', 'TRAIT_CONFIG_DELETED', 'ACTIVE_PLAYER_SPECIALIZATION_CHANGED' },
		read = function()
			local count = LoadoutCount()
			return count, Plural(count, 'loadout on this spec', 'loadouts on this spec')
		end,
		buttons = {
			{ text = 'Create 10 test loadouts', style = 'control', onClick = CreateTestLoadouts },
			{ text = 'Delete every loadout', onClick = DeleteLoadouts },
		},
	},
	quests = {
		title = 'Quest log',
		events = { 'QUEST_LOG_UPDATE', 'QUEST_ACCEPTED', 'QUEST_REMOVED' },
		read = function()
			local count = AbandonableCount()
			return count, Plural(count, 'quest can be abandoned', 'quests can be abandoned')
		end,
		buttons = { { text = 'Abandon every quest', onClick = AbandonQuests } },
	},
	characterMacros = {
		title = 'Character macros',
		events = { 'UPDATE_MACROS' },
		read = function()
			local _, count = GetNumMacros()
			return count, 'of ' .. CHARACTER_MACRO_SLOTS .. ' slots on this character'
		end,
		buttons = { { text = 'Delete character macros', onClick = DeleteCharacterMacros } },
	},
	generalMacros = {
		title = 'General macros',
		events = { 'UPDATE_MACROS' },
		read = function()
			local count = GetNumMacros()
			return count, 'of ' .. ACCOUNT_MACRO_SLOTS .. ' account wide slots'
		end,
		buttons = { { text = 'Delete general macros', onClick = DeleteGeneralMacros } },
	},
	reset = {
		title = 'BluUI settings',
		read = function()
			local db = BUI.GetAceDB()
			return db:GetCurrentProfile(), #db:GetProfiles() .. ' profiles saved  ·  every setting back to its default, then a reload'
		end,
		buttons = { { text = 'Reset BluUI', onClick = ResetSettings } },
	},
}

local function DangerCard(ui, cards, parent, x, y, width, spec)
	local card = cards.Card(parent, x, y, width, DANGER_CARD, { edge = 'danger' })
	card.edge:SetAlpha(DANGER_EDGE_ALPHA)
	cards.Title(card, spec.title)
	local value = cards.Readout(card, cards.PAD, DANGER_VALUE_Y, DANGER_VALUE_SIZE, width - cards.PAD * 2)
	local note = cards.Label(card, '', cards.PAD, DANGER_NOTE_Y, 11, 'muted')
	note:SetWidth(width - cards.PAD * 2)
	note:SetWordWrap(false)
	local anchor
	for index = #spec.buttons, 1, -1 do
		local action = spec.buttons[index]
		local button = ui.Button(card, action.text, action.style or 'danger', action.onClick)
		if anchor then
			button:SetPoint('RIGHT', anchor, 'LEFT', -BUTTON_GAP, 0)
		else
			button:SetPoint('BOTTOMRIGHT', -cards.PAD, DANGER_BUTTON_Y)
		end
		anchor = button
	end
	local function Update()
		local text, hint = spec.read()
		value:SetText(text)
		note:SetText(hint)
	end
	if spec.events then cards.Listen(card, spec.events, Update) else Update() end
	return card
end

local function DangerPane(ui, parent, width)
	local cards = Layout.CardKit(Window())
	local host = CreateFrame('Frame', nil, parent)
	host:SetWidth(width)
	local title = ui.Text(host, 'Danger zone', 13, 'text')
	title:SetPoint('TOPLEFT', 0, -2)
	local description = ui.Text(host, 'Tools that delete loadouts, macros or quests, and the reset that puts every BluUI setting back. None of it can be undone.', 12, 'muted', width)
	description:SetWordWrap(true)
	description:SetSpacing(4)
	description:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
	local head = 2 + ui.Height(title) + 8 + ui.Height(description) + DANGER_HEAD_GAP

	local grid = CreateFrame('Frame', nil, host)
	grid:SetPoint('TOPLEFT', 0, -head)
	grid:SetWidth(width)
	local function Card(spec)
		return function(gridParent, x, y, span) return DangerCard(ui, cards, gridParent, x, y, span, spec) end
	end
	local height = cards.Grid(grid, width, {
		{ { span = 'half', build = Card(DANGER_CARDS.loadouts) }, { span = 'half', build = Card(DANGER_CARDS.quests) } },
		{ { span = 'half', build = Card(DANGER_CARDS.characterMacros) }, { span = 'half', build = Card(DANGER_CARDS.generalMacros) } },
		{ { span = 'full', build = Card(DANGER_CARDS.reset) } },
	})
	grid:SetHeight(height)
	host:SetHeight(head + height)

	local gate = CreateFrame('Frame', nil, host)
	gate:SetPoint('TOPLEFT', grid, 'TOPLEFT', -GATE_BLEED, GATE_BLEED)
	gate:SetPoint('BOTTOMRIGHT', grid, 'BOTTOMRIGHT', GATE_BLEED, -GATE_BLEED)
	gate:SetFrameLevel(grid:GetFrameLevel() + 20)
	gate:EnableMouse(true)
	ui.Fill(gate, 'page'):SetAllPoints()
	local warning = ui.Text(gate, GATE_TEXT, 12, 'danger', GATE_WIDTH)
	warning:SetJustifyH('CENTER')
	warning:SetSpacing(3)
	warning:SetPoint('CENTER', 0, 24)
	ui.Button(gate, 'I confirm I will be careful', 'control', function() gate:Hide() end):SetPoint('TOP', warning, 'BOTTOM', 0, -16)
	return host
end

local function CelebrationBoard(ui, parent, width)
	local settings = BUI.GetDB().celebrations
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Celebrations',
		description = 'Confetti across your screen when something goes right.',
		buttons = { { text = 'Try it', icon = 'play', onClick = function() BUI.Celebrations.Test() end } },
	})
	board:AddSwitch('Timed keys', function() return settings.timedKey == true end, function(value) settings.timedKey = value end, 'When you finish a Mythic+ key in time')
	board:AddSwitch('Raid bosses', function() return settings.raidBoss == true end, function(value) settings.raidBoss = value end, 'When your raid kills a boss')
	board:AddSwitch('Dungeon bosses', function() return settings.dungeonBoss == true end, function(value) settings.dungeonBoss = value end, 'When your group kills a dungeon boss, keys included')
	return board
end

local PANES = {
	combat = function(ui, parent, width) return { SettingBoard(ui, parent, width, BOARDS.combat), SettingBoard(ui, parent, width, BOARDS.logging) } end,
	interface = function(ui, parent, width) return { SettingBoard(ui, parent, width, BOARDS.interface) } end,
	automation = function(ui, parent, width) return { SettingBoard(ui, parent, width, BOARDS.automation) } end,
	graphics = function(ui, parent, width) return { GraphicsBoard(ui, parent, width) } end,
	danger = function(ui, parent, width) return { DangerPane(ui, parent, width) } end,
	mythicplus = function(ui, parent, width) return { CelebrationBoard(ui, parent, width) } end,
}

BUI.PageEngine.RegisterPage('qol', {
	title = 'Quality of life',
	buttonText = 'Quality of life',
	icon = 'plus',
	OnBuild = function(pageFrame)
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local adapter = { tabContents = {}, currentTab = 1 }
		for index in ipairs(TAB_IDS) do adapter.tabContents[index] = {} end
		local rail
		rail = Layout.RailPage(page:GetTab(1), { window = Window() }, {
			icon = 'plus',
			title = 'Quality of life',
			placeholder = 'Search quality of life settings...',
			rail = { groups = RAIL_GROUPS },
			build = function(kit, _, parent, width, item) return PANES[item.id](kit, parent, width) end,
		})
		local Select = rail.Select
		function rail:Select(id)
			Select(self, id)
			adapter.currentTab = TAB_INDEX[id]
		end
		function adapter:SetTab(index)
			rail:Select(TAB_IDS[index])
		end
		pageFrame._page = adapter
		page:AutoRefresh()
	end,
})
