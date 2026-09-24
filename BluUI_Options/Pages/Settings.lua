local BUI = BluUI
local SetScript, HookScript = BUI.Prof.Scripts('Pages.Settings')

local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals, Widget = BUILib.Controls, BUILib.Layout, BUILib.Modals, BUILib.Widget
local Pixel = BUI.Pixel

function BUI.Settings.OpenDiagnostics()
	BUI.PageEngine.NavigateToID('settings')
	BUI.PageEngine.pages.settings.frame._page:SetTab(6)
	BUI.Settings.RunDiagnosticsReport()
end

BUI.PageEngine.RegisterPage("settings", {
	title = "Settings",
	OnBuild = function(pageFrame)
		local Settings = BUI.Settings
		local db = BUI.GetDB()
		local globalDB = BUI.db.global
		local PageKit = BUILib.PageKit

		local page = Layout.Page(pageFrame, {'Appearance', 'Settings', 'Skinning', 'Visibility', 'Modules', 'Help'})
		pageFrame._page = page

		do
			local tab = page:GetTab(2)
			local grid
			local function Section(title)
				if grid then grid:Flush() end
				Layout.Section(tab, title)
				grid = PageKit.RowGrid(tab)
			end
			local function AddRow(config) return grid:Add(config) end

			BUI.Settings._pageToggles = BUI.Settings._pageToggles or {}
			local SECTION_ORDER = { 'Target Combat Text', 'Combat', 'Combat Logging', 'Interface', 'Looting', 'Merchant', 'Questing', 'Social', 'Auction House' }
			local byHeader = {}
			for _, section in ipairs(BUI.Settings.checkboxSections) do byHeader[section.header] = section end
			local ordered, seen = {}, {}
			for _, header in ipairs(SECTION_ORDER) do
				if byHeader[header] then ordered[#ordered + 1] = byHeader[header]; seen[header] = true end
			end
			for _, section in ipairs(BUI.Settings.checkboxSections) do
				if not seen[section.header] then ordered[#ordered + 1] = section end
			end

			for _, section in ipairs(ordered) do
				if grid then grid:Flush(); grid = nil end
				Layout.Section(tab, section.header)

				local checks, wide = {}, {}
				for _, item in ipairs(section.items) do
					if item.type then wide[#wide + 1] = item else checks[#checks + 1] = item end
				end

				if #checks > 0 then
					local checkGrid = PageKit.CheckGrid(tab)
					for _, item in ipairs(checks) do
						local initialValue
						if item.fct then
							initialValue = BUI.Settings.GetFCTBool(item.cvar) or false
						else
							local dbValue = (item.db and item.key) and db[item.db][item.key]
							if item.cvar then
								if dbValue ~= nil then initialValue = dbValue else initialValue = C_CVar.GetCVarBool(item.cvar) or false end
							elseif item.cvarInit then
								initialValue = C_CVar.GetCVarBool(item.cvarInit) or false
							else
								if dbValue ~= nil then initialValue = dbValue else initialValue = item.default or false end
							end
						end
						local cell = checkGrid:Add(item.label, initialValue, function(checked)
							if item.fct then
								BUI.Settings.SetFCT(item.cvar, checked and 1 or 0)
								return
							end
							if item.db and item.key then db[item.db][item.key] = checked end
							if item.toggle and BUI.Settings[item.toggle] then
								BUI.Settings[item.toggle](BUI.Settings, checked)
							elseif item.fn and BUI.Settings[item.fn] then
								BUI.Settings[item.fn](BUI.Settings, checked)
							elseif item.cvar then
								C_CVar.SetCVar(item.cvar, checked and '1' or '0')
							end
						end)
						if item.key then
							local cellFrame = BUILib.Widget.Unwrap(cell)
							BUI.Settings._pageToggles[item.key] = function(value) cellFrame:SetValue(value) end
						end
					end
				end

				if #wide > 0 then grid = PageKit.RowGrid(tab) end
				for _, item in ipairs(wide) do
					if item.type == 'button' then
						AddRow({
							title = item.label,
							plain = true,
							accessoryWidth = (item.width or 180) + 10,
							accessories = function(row)
								return { Controls.Button(row, item.buttonText or 'Open', item.width or 180, function()
									if item.fn and BUI.Settings[item.fn] then BUI.Settings[item.fn](BUI.Settings) end
								end) }
							end,
						})
					elseif item.type == 'dropdown' then
						AddRow({
							title = item.label,
							controlWidth = (item.width or 140) + 10,
							control = function(row)
								local currentValue
								if item.fct then currentValue = BUI.Settings.GetFCT(item.cvar)
								elseif item.cvar then currentValue = C_CVar.GetCVar(item.cvar) end
								return Controls.Dropdown(row, nil, item.options, currentValue or (item.options[1] and item.options[1].value), function(selectedValue)
									if item.fct then BUI.Settings.SetFCT(item.cvar, selectedValue)
									elseif item.cvar then C_CVar.SetCVar(item.cvar, selectedValue) end
								end, nil, item.width or 140)
							end,
						})
					elseif item.type == 'slider' then
						AddRow({
							title = item.label,
							controlWidth = 160,
							control = function(row)
								local initialValue
								if item.fct then
									initialValue = tonumber(BUI.Settings.GetFCT(item.cvar)) or item.min or 0
								else
									local dbValue = (item.db and item.key) and db[item.db][item.key]
									if item.cvar then
										initialValue = dbValue or tonumber(C_CVar.GetCVar(item.cvar)) or item.min or 0
									elseif item.cvarInit then
										initialValue = dbValue or tonumber(C_CVar.GetCVar(item.cvarInit)) or 0
									else
										initialValue = dbValue or 0
									end
								end
								return Controls.CompactSlider(row, nil, item.min, item.max, initialValue, function(value)
									if item.fct then
										BUI.Settings.SetFCT(item.cvar, value)
									else
										if item.db and item.key then db[item.db][item.key] = value end
										if item.fn and BUI.Settings[item.fn] then BUI.Settings[item.fn](BUI.Settings, value) end
										if item.cvar then SetCVar(item.cvar, value) end
									end
								end, item.step or 1, 150)
							end,
						})
					end
				end
			end

			Section('Voice & Sound')

			local ttsItems = BUI.TTS.BuildVoiceDropdownItems()
			AddRow({
				spanFull = true,
				title = 'Voice',
				description = 'Voice used for BluUI text-to-speech.',
				controlWidth = 250,
				control = function(row)
					return Controls.Dropdown(row, nil, ttsItems, db.general.ttsVoice, function(voiceID)
						db.general.ttsVoice = voiceID
						BUI.TTS.Speak('Voice selected', { voiceID = voiceID })
					end, nil, 240)
				end,
			})

			AddRow({
				title = 'TTS Volume',
				description = 'Volume for BluUI speech alerts.',
				controlWidth = 170,
				control = function(row)
					return Controls.CompactSlider(row, nil, 0, 100, db.general.ttsVolume, function(value)
						db.general.ttsVolume = value
					end, 5, 160)
				end,
			})

			AddRow({
				title = 'Alert Sound Channel',
				description = 'Audio channel BluUI alert sounds play through.',
				controlWidth = 170,
				control = function(row)
					return Controls.Dropdown(row, nil, {
						{ value = 'Master',   text = 'Master' },
						{ value = 'SFX',      text = 'Sound Effects' },
						{ value = 'Music',    text = 'Music' },
						{ value = 'Ambience', text = 'Ambience' },
						{ value = 'Dialog',   text = 'Dialog' },
					}, db.general.soundChannel, function(value)
						db.general.soundChannel = value
					end, nil, 160)
				end,
			})

			Section('Graphical Tweaks')

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

			local PREVIEW_LINE_HEIGHT = 15
			local PREVIEW_HEADER_HEIGHT = 20

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
				globalDB.cvarBackup = globalDB.cvarBackup or {}
				local changed, failed = 0, 0
				for cvar, value in pairs(FPS_CVARS) do
					local current = C_CVar.GetCVar(cvar)
					if current and not globalDB.cvarBackup[cvar] then globalDB.cvarBackup[cvar] = current end
					if pending[cvar] then
						if C_CVar.SetCVar(cvar, value) then changed = changed + 1 else failed = failed + 1 end
					end
				end
				local report = ('|cff6D00FDBluUI:|r Changed %d graphics settings. Originals backed up.'):format(changed)
				if failed > 0 then report = report .. (' %d could not be set.'):format(failed) end
				print(report)
			end

			local function ShowFPSPreview(pending, total, known)
				local overlay, dialog, Close = Modals.CreateBase(540, 500, true, BUI.PageEngine.window.frame)
				local titleText = Modals.CreateTitle(dialog, 'Apply FPS Preset')
				local summary = Modals.CreateMessage(dialog, ('%d of %d settings will change'):format(total, known), 'CENTER', titleText, -16)
				local list = Controls.ScrollFrame(dialog, 480, 300, 100, 452)
				local listFrame = Widget.Unwrap(list)
				listFrame:SetPoint('TOP', summary, 'BOTTOM', 0, -14)
				FillPreviewList(list, pending)
				Modals.CreateMessage(dialog, 'Current values are backed up, and Restore Original puts them back.', 'CENTER', listFrame, -12)
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

			AddRow({
				spanFull = true,
				title = 'FPS Preset',
				description = 'Apply performance-focused graphics CVars, or restore your backed-up originals.',
				plain = true,
				accessoryWidth = 320,
				accessories = function(row)
					local applyButton = Controls.Button(row, 'Apply FPS Settings', 150, function()
						local pending, total, known = PendingCVars()
						if total == 0 then
							print('|cff6D00FDBluUI:|r Every FPS setting is already at its preset value.')
							return
						end
						ShowFPSPreview(pending, total, known)
					end)
					local restoreButton = Controls.Button(row, 'Restore Original', 150, function()
						if not globalDB.cvarBackup or not next(globalDB.cvarBackup) then
							print('|cff6D00FDBluUI:|r No backup found, apply FPS settings first.')
							return
						end
						local restored = 0
						for cvar, value in pairs(globalDB.cvarBackup) do
							local current = C_CVar.GetCVar(cvar)
							if current and not SameCVarValue(current, tostring(value)) and C_CVar.SetCVar(cvar, tostring(value)) then restored = restored + 1 end
						end
						globalDB.cvarBackup = nil
						print('|cff6D00FDBluUI:|r Restored ' .. restored .. ' settings to their original values.')
					end)
					return { restoreButton, applyButton }
				end,
			})

			Section('Danger Zone')

			AddRow({
				spanFull = true,
				title = 'Reset All Settings',
				description = 'Reset every BluUI setting to its default. This cannot be undone.',
				plain = true,
				accessoryWidth = 190,
				accessories = function(row)
					local holdButton = Controls.HoldButton(row, 'Hold to Reset Settings', function()
						Modals.Confirm({
							parent = BUI.PageEngine.window.frame,
							title = 'Reset All Settings',
							message = 'This will reset ALL BluUI settings to their defaults. This cannot be undone.',
							confirmText = 'Reset', cancelText = 'Cancel',
							onConfirm = function() BUI.GetAceDB():ResetDB(); BUI.Reload() end,
						})
					end, 3, 180)
					holdButton.frame:SetHeight(Pixel.Scale(24))
					return { holdButton }
				end,
			})

			Section('Quality of Life')

			local qualityOfLifeFirstRow = AddRow({
				spanFull = true,
				title = 'Talent Loadouts',
				description = 'Create test loadouts, or delete every loadout for your current spec.',
				plain = true,
				accessoryWidth = 418,
				accessories = function(row)
					local createButton = Controls.Button(row, 'Create 10 Test Loadouts', 200, function()
						if InCombatLockdown() then
							print('|cff6D00FDBluUI:|r Cannot create loadouts in combat.')
							return
						end
						if not C_AddOns.IsAddOnLoaded('Blizzard_PlayerSpells') then
							C_AddOns.LoadAddOn('Blizzard_PlayerSpells')
						end
						BUI.Prof.After('Pages.Settings', 0.2, function()
							local Print = function(message) print('|cff6D00FDBUI/Talents:|r '..message) end
							local timeStamp = tostring(time())
							local loadoutIndex = 0
							local pending = false
							local createNext

							local watcher = CreateFrame('Frame')
							watcher:RegisterEvent('TRAIT_CONFIG_CREATED')
							SetScript(watcher, 'OnEvent', function()
								if pending then
									pending = false
									BUI.Prof.After('Pages.Settings', 0.3, createNext)
								end
							end)

							createNext = function()
								loadoutIndex = loadoutIndex + 1
								if loadoutIndex > 10 then
									watcher:UnregisterAllEvents()
									SetScript(watcher, 'OnEvent', nil)
									Print('Create batch done.')
									if PlayerSpellsFrame and PlayerSpellsFrame:IsShown() and not InCombatLockdown() then
										HideUIPanel(PlayerSpellsFrame)
										ShowUIPanel(PlayerSpellsFrame)
									end
									return
								end
								local name = ('test_%s_%d'):format(timeStamp, loadoutIndex)
								local success = C_ClassTalents.RequestNewConfig(name)
								Print(('RequestNewConfig("%s") -> %s'):format(name, tostring(success)))
								if success then
									pending = true
								else
									BUI.Prof.After('Pages.Settings', 0.3, createNext)
								end
							end

							createNext()
						end)
					end)
					local deleteButton = Controls.Button(row, 'Delete Talent Loadouts', 200, function()
						if InCombatLockdown() then
							print('|cff6D00FDBluUI:|r Cannot delete loadouts in combat.')
							return
						end
						Modals.Confirm({
							parent = BUI.PageEngine.window.frame,
							title = 'Delete Talent Loadouts',
							message = 'Delete every talent loadout for this spec? Other specs must be cleaned from those specs.',
							confirmText = 'Delete', cancelText = 'Cancel',
							onConfirm = function()
								local Print = function(message) print('|cff6D00FDBUI/Talents:|r '..message) end

								if not C_AddOns.IsAddOnLoaded('Blizzard_PlayerSpells') then
									Print('Loading Blizzard_PlayerSpells...')
									C_AddOns.LoadAddOn('Blizzard_PlayerSpells')
								end

								BUI.Prof.After('Pages.Settings', 0.2, function()
									local specIndex = GetSpecialization()
									local specID = specIndex and GetSpecializationInfo(specIndex)
									if not specID then
										Print('ERROR: no current spec.')
										return
									end

									local activeID = C_ClassTalents.GetActiveConfigID()
									local before = C_ClassTalents.GetConfigIDsBySpecID(specID) or {}
									Print(('Spec %d, %d loadout(s), active=%s'):format(specID, #before, tostring(activeID)))

									if #before == 0 then
										Print('No loadouts on current spec.')
										return
									end

									local NameOfConfig = function(configID)
										local info = C_Traits.GetConfigInfo(configID)
										return info and info.name or '?'
									end
									for configIndex, configID in ipairs(before) do
										local tag = (configID == activeID) and ' [ACTIVE]' or ''
										Print(('  [%d] id=%s name="%s"%s'):format(configIndex, tostring(configID), NameOfConfig(configID), tag))
									end

									local deleteIndex = 1
									local pending = nil
									local deleteNext

									local watcher = CreateFrame('Frame')
									watcher:RegisterEvent('TRAIT_CONFIG_DELETED')

									local function finish()
										watcher:UnregisterAllEvents()
										SetScript(watcher, 'OnEvent', nil)
										BUI.Prof.After('Pages.Settings', 0.3, function()
											local after = C_ClassTalents.GetConfigIDsBySpecID(specID) or {}
											local actuallyDeleted = #before - #after
											Print(('Final: %d of %d deleted, %d remain.'):format(actuallyDeleted, #before, #after))
											for configIndex, configID in ipairs(after) do
												Print(('  REMAIN [%d] id=%s name="%s"'):format(configIndex, tostring(configID), NameOfConfig(configID)))
											end
											if PlayerSpellsFrame and PlayerSpellsFrame:IsShown() and not InCombatLockdown() then
												HideUIPanel(PlayerSpellsFrame)
												ShowUIPanel(PlayerSpellsFrame)
												Print('Dropdown refreshed.')
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
										Print(('DeleteConfig(%s "%s") -> %s'):format(tostring(configID), NameOfConfig(configID), tostring(success)))
										if not success then
											pending = nil
											BUI.Prof.After('Pages.Settings', 0.3, deleteNext)
										end
									end

									SetScript(watcher, 'OnEvent', function(_, _, configID)
										if configID == pending then
											pending = nil
											BUI.Prof.After('Pages.Settings', 0.3, deleteNext)
										end
									end)

									deleteNext()
								end)
							end,
						})
					end)
					return { deleteButton, createButton }
				end,
			})

			AddRow({
				spanFull = true,
				title = 'Macros',
				description = 'Delete all account-wide or character-specific macros.',
				plain = true,
				accessoryWidth = 418,
				accessories = function(row)
					local generalButton = Controls.Button(row, 'Delete General Macros', 200, function()
						Modals.Confirm({
							parent = BUI.PageEngine.window.frame,
							title = 'Delete General Macros',
							message = 'This will delete ALL account-wide (General) macros. This cannot be undone.',
							confirmText = 'Delete', cancelText = 'Cancel',
							onConfirm = function()
								local generalMacroCount = GetNumMacros()
								for macroIndex = generalMacroCount, 1, -1 do
									DeleteMacro(macroIndex)
								end
								print(('|cff6D00FDBluUI:|r Deleted %d general macro(s).'):format(generalMacroCount))
							end,
						})
					end)
					local characterButton = Controls.Button(row, 'Delete Character Macros', 200, function()
						Modals.Confirm({
							parent = BUI.PageEngine.window.frame,
							title = 'Delete Character Macros',
							message = 'This will delete ALL character-specific macros on this toon. This cannot be undone.',
							confirmText = 'Delete', cancelText = 'Cancel',
							onConfirm = function()
								local _, characterMacroCount = GetNumMacros()
								for macroIndex = MAX_ACCOUNT_MACROS + characterMacroCount, MAX_ACCOUNT_MACROS + 1, -1 do
									DeleteMacro(macroIndex)
								end
								print(('|cff6D00FDBluUI:|r Deleted %d character macro(s).'):format(characterMacroCount))
							end,
						})
					end)
					return { characterButton, generalButton }
				end,
			})

			local qualityOfLifeLastRow = AddRow({
				spanFull = true,
				title = 'Quest Log',
				description = 'Abandon every abandonable quest in your log.',
				plain = true,
				accessoryWidth = 210,
				accessories = function(row)
					return { Controls.Button(row, 'Abandon All Quests', 200, function()
						if InCombatLockdown() then
							print('|cff6D00FDBluUI:|r Cannot abandon quests in combat.')
							return
						end
						Modals.Confirm({
							parent = BUI.PageEngine.window.frame,
							title = 'Abandon All Quests',
							message = 'This will abandon every quest in your log that can be abandoned. Campaign and account quests will be skipped. This cannot be undone.',
							confirmText = 'Abandon', cancelText = 'Cancel',
							onConfirm = function()
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
									print('|cff6D00FDBluUI:|r Quest log already clear.')
									return
								end

								local confirmed = 0
								local watcher = CreateFrame('Frame')
								watcher:RegisterEvent('QUEST_REMOVED')
								SetScript(watcher, 'OnEvent', function(_, _, questID)
									if seen[questID] then
										confirmed = confirmed + 1
										seen[questID] = nil
									end
								end)

								local queueIndex = 1
								BUI.Prof.NewTicker('Pages.Settings', 0.05, function(ticker)
									local questID = queue[queueIndex]
									queueIndex = queueIndex + 1
									if not questID then
										ticker:Cancel()
										BUI.Prof.After('Pages.Settings', 0.5, function()
											watcher:UnregisterAllEvents()
											SetScript(watcher, 'OnEvent', nil)
											if confirmed == 0 then
												print('|cff6D00FDBluUI:|r Quest log already clear.')
											else
												print(('|cff6D00FDBluUI:|r Abandoned %d quest(s).'):format(confirmed))
											end
										end)
										return
									end
									C_QuestLog.SetSelectedQuest(questID)
									C_QuestLog.SetAbandonQuest()
									C_QuestLog.AbandonQuest()
								end)
							end,
						})
					end) }
				end,
			})

			grid:Flush()

			do
				local firstRowFrame = BUILib.Widget.Unwrap(qualityOfLifeFirstRow)
				local lastRowFrame = BUILib.Widget.Unwrap(qualityOfLifeLastRow)
				local overlay = CreateFrame('Frame', nil, tab.child, 'BackdropTemplate')
				overlay:SetPoint('TOPLEFT', firstRowFrame, 'TOPLEFT', 0, 0)
				overlay:SetPoint('BOTTOMRIGHT', lastRowFrame, 'BOTTOMRIGHT', 0, 0)
				overlay:SetFrameStrata(firstRowFrame:GetFrameStrata())
				overlay:SetFrameLevel(lastRowFrame:GetFrameLevel() + 20)
				overlay:EnableMouse(true)
				overlay:SetBackdrop({
					bgFile = 'Interface\\Buttons\\WHITE8X8',
					edgeFile = 'Interface\\Buttons\\WHITE8X8',
					edgeSize = 1,
				})
				overlay:SetBackdropColor(0.08, 0.02, 0.02, 0.97)
				overlay:SetBackdropBorderColor(0.90, 0.25, 0.25, 0.6)

				local warningText = overlay:CreateFontString(nil, 'OVERLAY')
				Pixel.ApplyFont(warningText, 12, BUILib.Font, '')
				warningText:SetPoint('CENTER', 0, Pixel.Scale(24))
				warningText:SetWidth(Pixel.Scale(560))
				warningText:SetJustifyH('CENTER')
				warningText:SetWordWrap(true)
				warningText:SetText('These tools permanently delete loadouts, macros, or quests. There is no undo.\n\nBy clicking below, I solemnly swear not to cry in Discord when my stuff disappears because I clearly cannot read.')
				warningText:SetTextColor(1.00, 0.55, 0.55, 1)

				local confirmButton = Controls.Button(overlay, 'I confirm I will be careful', 240, function()
					overlay:Hide()
				end)
				confirmButton.frame:SetPoint('TOP', warningText, 'BOTTOM', 0, Pixel.Scale(-14))
			end
		end

		if BUI.AppearancePage then BUI.AppearancePage.BuildTab(page:GetTab(1)) end

		if BUI.SkinningPage then BUI.SkinningPage.BuildTab(page:GetTab(3)) end

		if BUI.VisibilityPage then BUI.VisibilityPage.BuildTab(page:GetTab(4)) end

		do
			local tab = page:GetTab(5)
			Layout.Section(tab, 'Modules', 'Turn BluUI modules on or off. Some changes take effect after a /reload.')

			local MODULE_ORDER = {
				{ key = 'actionBars',    label = 'Action Bars' },
				{ key = 'unitFrames',    label = 'Unit Frames' },
				{ key = 'groupFrames',   label = 'Group Frames (Party/Raid)' },
				{ key = 'cdm',           label = 'Cooldown Manager' },
				{ key = 'castBars',      label = 'Cast Bars' },
				{ key = 'power',         label = 'Power Bars' },
				{ key = 'minimap',       label = 'Minimap' },
				{ key = 'auras',         label = 'Auras' },
				{ key = 'buffTracking',  label = 'Buff Tracking' },
				{ key = 'datatext',      label = 'Datatext' },
				{ key = 'customBars',    label = 'Custom Bars' },
				{ key = 'cursor',        label = 'Cursor' },
				{ key = 'markers',       label = 'Markers' },
				{ key = 'streamerTools', label = 'Streamer Tools' },
				{ key = 'gemCounter',    label = 'Gem Manager' },
			}

			local moduleItems = {}
			for _, entry in ipairs(MODULE_ORDER) do
				moduleItems[#moduleItems + 1] = {
					key     = entry.key,
					title   = entry.label,
					checked = db.modules[entry.key],
				}
			end

			local moduleListFrame
			local moduleDirty = false

			local function SyncModules()
				local selected = {}
				for _, key in ipairs(moduleListFrame:GetSelected()) do selected[key] = true end
				local needReload = false
				for _, entry in ipairs(MODULE_ORDER) do
					local key = entry.key
					local newValue = selected[key] == true
					local changed = db.modules[key] ~= newValue
					db.modules[key] = newValue
					if changed and not BUI.ApplyModuleRuntime(key) then
						needReload = true
					end
				end
				return needReload
			end

			local moduleList = Controls.SelectableList(tab.child, {
				width        = tab.width,
				rowHeight    = 34,
				items        = moduleItems,
				nameLabel    = 'Module',
				includeLabel = '',
				hideStatus   = true,
				hideSummary  = true,
				onChange = function()
					local needReload = SyncModules()
					if not needReload or moduleDirty then return end
					moduleDirty = true
					Modals.Confirm({
						parent = BUI.PageEngine.window.frame,
						title = 'Reload Required',
						message = 'Some module changes take effect after a /reload.',
						confirmText = 'Reload Now', cancelText = 'Later',
						onConfirm = function() SyncModules(); BUI.Reload() end,
					})
				end,
			})
			moduleListFrame = BUILib.Widget.Unwrap(moduleList)
			HookScript(moduleListFrame, 'OnHide', SyncModules)

			HookScript(moduleListFrame, 'OnShow', function()
				for _, entry in ipairs(MODULE_ORDER) do
					moduleListFrame:SetItemChecked(entry.key, db.modules[entry.key])
				end
			end)

			Layout.Add(tab, moduleListFrame, 8)
		end

		do
			local tab = page:GetTab(6)
			Layout.Section(tab, 'Diagnostics')
			local grid = PageKit.RowGrid(tab)

			local helpBox

			local function GatherDiagnostics()
				local lines = {}
				local function AddLine(line) lines[#lines + 1] = line end

				AddLine('== BluUI ==')
				AddLine('Version: ' .. BUI.Version)

				local _, class = UnitClass('player')
				local specIndex = GetSpecialization()
				local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or 'none'
				AddLine('')
				AddLine('== Character ==')
				AddLine('Name: ' .. UnitName('player') .. ' - ' .. GetRealmName())
				AddLine('Class: ' .. class)
				AddLine('Spec: ' .. specName)
				AddLine('Level: ' .. UnitLevel('player'))

				local clientVersion, build, _, tocVersion = GetBuildInfo()
				AddLine('')
				AddLine('== Client ==')
				AddLine('Version: ' .. clientVersion .. ' (build ' .. build .. ')')
				AddLine('TOC: ' .. tocVersion)
				AddLine('Locale: ' .. GetLocale())
				local screenWidth, screenHeight = GetPhysicalScreenSize()
				AddLine('Screen: ' .. screenWidth .. 'x' .. screenHeight)
				AddLine('UI Scale: ' .. format('%.4f', UIParent:GetEffectiveScale()))

				AddLine('')
				AddLine('== Settings ==')
				AddLine('Font: ' .. tostring(db.general.font))
				AddLine('Texture: ' .. tostring(db.general.texture))
				AddLine('Class Color Theme: ' .. tostring(db.general.useClassColorTheme))
				local themeColor = db.general.themeColor
				AddLine('Theme Color: ' .. format('%.2f, %.2f, %.2f', themeColor[1], themeColor[2], themeColor[3]))
				AddLine('')
				AddLine('== Modules ==')
				for moduleKey, moduleEnabled in pairs(db.modules) do
					AddLine('  ' .. moduleKey .. ': ' .. tostring(moduleEnabled))
				end

				AddLine('')
				AddLine('== Addons (' .. C_AddOns.GetNumAddOns() .. ') ==')
				for addonIndex = 1, C_AddOns.GetNumAddOns() do
					local addonName = C_AddOns.GetAddOnInfo(addonIndex)
					local loaded = C_AddOns.IsAddOnLoaded(addonIndex)
					if loaded then
						local addonVersion = C_AddOns.GetAddOnMetadata(addonName, 'Version') or ''
						if addonVersion ~= '' then
							AddLine('  ' .. addonName .. ' v' .. addonVersion)
						else
							AddLine('  ' .. addonName)
						end
					end
				end

				return table.concat(lines, '\n')
			end

			local function RunDiagnosticsReport()
				helpBox.editbox:SetText(GatherDiagnostics())
				helpBox.editbox:HighlightText()
				helpBox.editbox:SetFocus()
			end
			Settings.RunDiagnosticsReport = RunDiagnosticsReport

			grid:Add({
				spanFull = true,
				title = 'Diagnostics Report',
				description = 'Character, client, settings and addon info. Copy and paste it with bug reports.',
				plain = true,
				accessoryWidth = 130,
				accessories = function(row)
					return { Controls.Button(row, 'Generate Report', 120, RunDiagnosticsReport) }
				end,
			})
			grid:Flush()

			helpBox = Layout.TextArea(tab, nil, 500)
		end

		page:AutoRefresh()
	end,
})
