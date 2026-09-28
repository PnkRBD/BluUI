local BUI = BluUI
local BUILib = BUI.BUILibClient
local Controls, Layout, Modals, Widget = BUILib.Controls, BUILib.Layout, BUILib.Modals, BUILib.Widget

local RAIL_GROUPS = {
	{ title = 'BluUI', items = {
		{ id = 'theme', label = 'Theme', icon = 'theme' },
		{ id = 'modules', label = 'Modules', icon = 'modules5' },
		{ id = 'help', label = 'Help', icon = 'question' },
	} },
	{ title = 'Game', items = {
		{ id = 'appearance', label = 'Appearance', icon = 'glow' },
		{ id = 'settings', label = 'Settings', icon = 'cog' },
		{ id = 'skinning', label = 'Skinning', icon = 'edit' },
		{ id = 'visibility', label = 'Visibility', icon = 'eye' },
	} },
}
local PAGE_WIDTH = 960
local TAB_IDS = { 'appearance', 'settings', 'skinning', 'visibility', 'modules', 'help', 'theme' }
local TAB_INDEX = {}
for index, id in ipairs(TAB_IDS) do TAB_INDEX[id] = index end
local SLIDER_WIDTH = 220
local DROPDOWN_WIDTH = 200
local BUTTON_ROOM = 130
local STATUS_ROOM = 120
local PAIR_ROOM = 360
local BUTTON_GAP = 10
local GATE_WIDTH = 420
local PREVIEW_LINE_HEIGHT = 15
local PREVIEW_HEADER_HEIGHT = 20

local BOARDS = {
	{ title = 'Combat', description = 'The numbers that float up over your target, casting feel, the keystone slot and how early the next spell queues.', headers = { 'Target Combat Text', 'Casting' } },
	{ title = 'Combat logging', description = 'Start a combat log on its own in the content you pick, with a small indicator while it runs.', headers = { 'Combat Logging' } },
	{ title = 'Interface', description = 'Blizzard frames and messages you would rather not see, and a faster item delete.', headers = { 'Interface' } },
	{ title = 'Automation', description = 'Loot, sell, repair, quest and accept invites without the clicks. Hold shift at a vendor or quest giver to skip it once.', headers = { 'Looting', 'Merchant', 'Questing', 'Auction House', 'Social' } },
}

local CHANNELS = {
	{ value = 'Master', text = 'Master' },
	{ value = 'SFX', text = 'Sound Effects' },
	{ value = 'Music', text = 'Music' },
	{ value = 'Ambience', text = 'Ambience' },
	{ value = 'Dialog', text = 'Dialog' },
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

local function Named(entries, value)
	for _, entry in ipairs(entries) do
		if entry.value == value then return entry.text end
	end
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

local function Menu(ui, row, entries, get, set)
	local dropdown = ui.Dropdown(row, DROPDOWN_WIDTH, function()
		local items = {}
		for _, entry in ipairs(entries) do
			items[#items + 1] = { text = entry.text, checked = entry.value == get(), callback = function()
				set(entry.value)
				Window():Repaint()
			end }
		end
		return items
	end)
	dropdown:SetPoint('RIGHT', -ui.ROW_INSET, 0)
	ui.Bind(row, function() dropdown.label:SetText(Named(entries, get())) end)
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

local function PreviewLine(child, offsetY, name, valueText, isHeader)
	local label = child:CreateFontString(nil, 'OVERLAY')
	label:SetFont(Modals.BodyFont(), isHeader and 12 or 11, '')
	label:SetPoint('TOPLEFT', child, 'TOPLEFT', isHeader and 6 or 18, -offsetY)
	label:SetJustifyH('LEFT')
	label:SetText(name)
	if isHeader then label:SetTextColor(0.4, 0.72, 1, 1) else label:SetTextColor(0.78, 0.78, 0.82, 1) end
	if not valueText then return end
	local value = child:CreateFontString(nil, 'OVERLAY')
	value:SetFont(Modals.BodyFont(), 11, '')
	value:SetPoint('TOPRIGHT', child, 'TOPRIGHT', -10, -offsetY)
	value:SetJustifyH('RIGHT')
	value:SetText(valueText)
	value:SetTextColor(1, 1, 1, 1)
end

local function FillPreviewList(list, pending)
	local child = list.child
	local offsetY, remaining = 6, {}
	for cvar in pairs(pending) do remaining[cvar] = true end
	local function AddSection(label, cvars)
		if #cvars == 0 then return end
		PreviewLine(child, offsetY, label, nil, true)
		offsetY = offsetY + PREVIEW_HEADER_HEIGHT
		for _, cvar in ipairs(cvars) do
			PreviewLine(child, offsetY, cvar, ('%s  ->  %s'):format(pending[cvar], FPS_CVARS[cvar]))
			offsetY = offsetY + PREVIEW_LINE_HEIGHT
		end
		offsetY = offsetY + 8
	end
	for _, group in ipairs(FPS_CVAR_GROUPS) do
		local rows = {}
		for _, cvar in ipairs(group.cvars) do
			if pending[cvar] then
				rows[#rows + 1] = cvar
				remaining[cvar] = nil
			end
		end
		AddSection(group.label, rows)
	end
	local others = {}
	for cvar in pairs(remaining) do others[#others + 1] = cvar end
	table.sort(others)
	AddSection('Other', others)
	list:SetChildHeight(offsetY)
end

local function ApplyFPSPreset(pending)
	local globalDB = BUI.db.global
	globalDB.cvarBackup = globalDB.cvarBackup or {}
	local changed, failed = 0, 0
	for cvar, value in pairs(FPS_CVARS) do
		local current = C_CVar.GetCVar(cvar)
		if current and not globalDB.cvarBackup[cvar] then globalDB.cvarBackup[cvar] = current end
		if pending[cvar] then
			if C_CVar.SetCVar(cvar, value) then changed = changed + 1 else failed = failed + 1 end
		end
	end
	local report = ('Changed %d graphics settings. Originals backed up.'):format(changed)
	if failed > 0 then report = report .. (' %d could not be set.'):format(failed) end
	BUI.Print(report)
	Window():Repaint()
end

local function ShowFPSPreview(pending, total, known)
	local overlay, dialog, Close = Modals.CreateBase(540, 500, true, Window().frame)
	local titleText = Modals.CreateTitle(dialog, 'Apply FPS Preset')
	local summary = Modals.CreateMessage(dialog, ('%d of %d settings will change'):format(total, known), 'CENTER', titleText, -16)
	local list = Controls.ScrollFrame(dialog, 480, 300, 100, 452)
	local listFrame = Widget.Unwrap(list)
	listFrame:SetPoint('TOP', summary, 'BOTTOM', 0, -14)
	FillPreviewList(list, pending)
	Modals.CreateMessage(dialog, 'Current values are backed up, and Restore puts them back.', 'CENTER', listFrame, -12)
	Modals.LayoutButtons(dialog, {
		{ text = 'Apply', color = Modals.BTN_CONFIRM, onClick = function(close) close(); ApplyFPSPreset(pending) end },
		{ text = 'Cancel', color = Modals.BTN_CANCEL, onClick = function(close) close() end },
	}, Close)
	overlay:SetScript('OnKeyDown', function(self, key)
		if key == 'ESCAPE' then
			self:SetPropagateKeyboardInput(false)
			Close()
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)
	overlay:Show()
end

local function ApplyFPS()
	local pending, total, known = PendingCVars()
	if total == 0 then
		BUI.Print('Every FPS setting is already at its preset value.')
		return
	end
	ShowFPSPreview(pending, total, known)
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
		for macroIndex = MAX_ACCOUNT_MACROS + characterMacroCount, MAX_ACCOUNT_MACROS + 1, -1 do
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

local function SoundBoard(ui, parent, width)
	local general = BUI.GetDB().general
	local board = ui.Board(parent, width, { title = 'Voice and sound', description = 'The voice BluUI speaks with, how loud it is, and the channel its alert sounds play on.' })
	Menu(ui, board:AddRow('Voice', 'Used for every spoken alert', DROPDOWN_WIDTH), BUI.TTS.BuildVoiceDropdownItems(), function() return general.ttsVoice end, function(voiceID)
		general.ttsVoice = voiceID
		BUI.TTS.Speak('Voice selected', { voiceID = voiceID })
	end)
	Slider(ui, board:AddRow('Volume', 'For spoken alerts', SLIDER_WIDTH), 0, 100, 5, function() return general.ttsVolume end, function(value) general.ttsVolume = value end)
	Menu(ui, board:AddRow('Alert sound channel', 'Where BluUI alert sounds play', DROPDOWN_WIDTH), CHANNELS, function() return general.soundChannel end, function(channel) general.soundChannel = channel end)
	return board
end

local function GraphicsBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		title = 'Graphics',
		description = 'A performance preset for the graphics CVars. Your current values are backed up the first time it is applied, and Restore puts them back.',
		buttons = {
			{ text = 'Restore', icon = 'reset', onClick = RestoreFPS },
			{ style = 'primary', text = 'Apply preset', onClick = ApplyFPS },
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

local function DangerBoard(ui, parent, width)
	local board = ui.Board(parent, width, {
		stacked = true,
		title = 'Danger zone',
		description = 'Tools that delete loadouts, macros or quests, and the reset that puts every BluUI setting back. None of it can be undone.',
	})
	local function Action(name, sub, buttons)
		local row = board:AddRow(name, sub, PAIR_ROOM)
		local anchor
		for index = #buttons, 1, -1 do
			local spec = buttons[index]
			local button = ui.Button(row, spec.text, spec.style or 'danger', spec.onClick)
			if anchor then
				button:SetPoint('RIGHT', anchor, 'LEFT', -BUTTON_GAP, 0)
			else
				button:SetPoint('RIGHT', -ui.ROW_INSET, 0)
			end
			anchor = button
		end
	end
	Action('Talent loadouts', 'This spec only', {
		{ text = 'Create 10 test loadouts', style = 'control', onClick = CreateTestLoadouts },
		{ text = 'Delete every loadout', onClick = DeleteLoadouts },
	})
	Action('Macros', 'Account wide or this character only', {
		{ text = 'Delete character macros', onClick = DeleteCharacterMacros },
		{ text = 'Delete general macros', onClick = DeleteGeneralMacros },
	})
	Action('Quest log', 'Every quest that can be abandoned', { { text = 'Abandon every quest', onClick = AbandonQuests } })
	Action('BluUI settings', 'Every setting back to its default, then a reload', { { text = 'Reset BluUI', onClick = ResetSettings } })

	local gate = CreateFrame('Frame', nil, board.panel)
	gate:SetAllPoints()
	gate:SetFrameLevel(board.panel:GetFrameLevel() + 20)
	gate:EnableMouse(true)
	ui.Fill(gate, 'panel'):SetAllPoints()
	local warning = ui.Text(gate, GATE_TEXT, 12, 'danger', GATE_WIDTH)
	warning:SetJustifyH('CENTER')
	warning:SetSpacing(3)
	warning:SetPoint('CENTER', 0, 24)
	ui.Button(gate, 'I confirm I will be careful', 'control', function() gate:Hide() end):SetPoint('TOP', warning, 'BOTTOM', 0, -16)
	return board
end

local function Sections(ui, parent, width)
	BUI.Settings._pageToggles = BUI.Settings._pageToggles or {}
	local sections = {}
	for _, spec in ipairs(BOARDS) do sections[#sections + 1] = SettingBoard(ui, parent, width, spec) end
	sections[#sections + 1] = SoundBoard(ui, parent, width)
	sections[#sections + 1] = GraphicsBoard(ui, parent, width)
	sections[#sections + 1] = DangerBoard(ui, parent, width)
	return sections
end

BUI.PageEngine.RegisterPage("settings", {
	title = "Settings",
	icon = 'cog',
	OnBuild = function(pageFrame)
		local panes = {
			theme = BUI.ThemePage,
			modules = BUI.ModulesPage,
			help = BUI.HelpPage,
			appearance = BUI.AppearancePage,
			skinning = BUI.SkinningPage,
			visibility = BUI.VisibilityPage,
		}
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local adapter = { tabContents = {}, currentTab = 1 }
		for index in ipairs(TAB_IDS) do adapter.tabContents[index] = {} end
		local rail
		rail = Layout.RailPage(page:GetTab(1), { window = BUI.PageEngine.window }, {
			icon = 'cog',
			title = 'Settings',
			placeholder = 'Search settings...',
			rail = { groups = RAIL_GROUPS },
			build = function(kit, shell, parent, width, item, railPage)
				if item.id == 'settings' then return Sections(kit, parent, width) end
				return panes[item.id].Sections(kit, shell, parent, width, railPage)
			end,
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
