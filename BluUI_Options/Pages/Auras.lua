local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Controls, Layout = BUILib.Controls, BUILib.Layout
local PageKit = BUILib.PageKit

local fonts
local lowHpEye
local crosshairEye
local markWarningEye
local bloodlustEye

local function ClearPreviewToggle(toggle)
	if toggle then toggle:SetValue(false) end
end

local function AlertMover(parent, db, apply, options)
	options = options or {}
	local fieldMap = options.fields or {}
	local function FieldKey(standardKey) return fieldMap[standardKey] or standardKey end
	local function Get(standardKey) return db[FieldKey(standardKey)] end
	local function Set(standardKey, value) db[FieldKey(standardKey)] = value end

	local rangeX = (options.xyRange and options.xyRange.x) or 1500
	local rangeY = (options.xyRange and options.xyRange.y) or 1000
	local anchorRange = options.anchorRange or 200
	local dropdowns = options.dropdowns or {}
	local rowCount = 6 + (options.noCenter and 0 or 1) + (options.unlock and 1 or 0) + (options.matchWidth and 1 or 0) + (options.matchHeight and 1 or 0) + #dropdowns

	return Controls.Icon(parent, {
		texture = BUILib.GetLibMedia('mover'), tooltip = 'Position & anchor',
		onClick = function(button)
			local frameItems = { { value = '', text = 'None (screen position)' } }
			local list = options.frames or (options.selfTag and BUI.AnchorFramesExcept(options.selfTag)) or BUI.C.ANCHOR_FRAMES
			for index = 1, #list do
				frameItems[#frameItems + 1] = { value = list[index].tag, text = list[index].desc }
			end
			Controls.Popover({
				anchor = button, width = 280, title = 'POSITION', height = rowCount * 40 - 2,
				build = function(panel)
					local y = 18
					local Widget = BUILib.Widget
					local centerCheckbox, unlockCheckbox
					local xSlider = Controls.CompactSlider(panel, nil, -rangeX, rangeX, Get('posX') or 0, function(value) Set('posX', value); apply() end, 1, 150)
					PageKit.PopRow(panel, y, 'X Position', xSlider); y = y + 40
					local ySlider = Controls.CompactSlider(panel, nil, -rangeY, rangeY, Get('posY') or 0, function(value) Set('posY', value); apply() end, 1, 150)
					PageKit.PopRow(panel, y, 'Y Position', ySlider); y = y + 40
					local function SyncAnchorLock()
						local anchored = (Get('anchorFrame') or '') ~= ''
						if anchored then
							xSlider:SetLockedText('ANCHORED')
							ySlider:SetLockedText('ANCHORED')
						end
						xSlider:SetLocked(anchored)
						ySlider:SetLocked(anchored)
						if centerCheckbox then Widget.Unwrap(centerCheckbox):SetEnabled(not anchored) end
						if unlockCheckbox then Widget.Unwrap(unlockCheckbox):SetEnabled(not anchored) end
					end
					if not options.noCenter then
						centerCheckbox = Controls.StampCheckbox(panel, nil, Get('centerHorizontally'), function(value)
							Set('centerHorizontally', value)
							if value then Set('posX', 0); xSlider:SetValue(0) end
							apply()
						end)
						PageKit.PopRow(panel, y, 'Center Horizontally', centerCheckbox); y = y + 40
					end
					for _, dropdown in ipairs(dropdowns) do
						PageKit.PopRow(panel, y, dropdown.label, Controls.Dropdown(panel, nil, dropdown.items, Get(dropdown.key) or dropdown.default, function(value)
							Set(dropdown.key, value)
							apply()
						end, nil, 150)); y = y + 40
					end
					if options.unlock then
						unlockCheckbox = Controls.StampCheckbox(panel, nil, options.unlock.get(), function(value)
							options.unlock.set(value)
						end)
						PageKit.PopRow(panel, y, 'Unlock (drag to move)', unlockCheckbox); y = y + 40
					end
					if options.matchWidth then
						PageKit.PopRow(panel, y, 'Match Anchor Width', Controls.StampCheckbox(panel, nil, options.matchWidth.get(), function(value)
							options.matchWidth.set(value)
						end)); y = y + 40
					end
					if options.matchHeight then
						PageKit.PopRow(panel, y, 'Match Anchor Height', Controls.StampCheckbox(panel, nil, options.matchHeight.get(), function(value)
							options.matchHeight.set(value)
						end)); y = y + 40
					end
					PageKit.PopRow(panel, y, 'Anchor Frame', Controls.Dropdown(panel, nil, frameItems, Get('anchorFrame') or '', function(value)
						Set('anchorFrame', value); apply()
						SyncAnchorLock()
					end, nil, 150)); y = y + 40
					SyncAnchorLock()
					PageKit.PopRow(panel, y, 'Anchor Point', Controls.Dropdown(panel, nil, BUI.C.ANCHOR_PLACEMENT_OPTIONS, Get('anchorPoint') or 'BOTTOM', function(value)
						Set('anchorPoint', value); apply()
					end, nil, 150)); y = y + 40
					PageKit.PopRow(panel, y, 'Anchor X', Controls.CompactSlider(panel, nil, -anchorRange, anchorRange, Get('anchorOffsetX') or 0, function(value) Set('anchorOffsetX', value); apply() end, 1, 150)); y = y + 40
					PageKit.PopRow(panel, y, 'Anchor Y', Controls.CompactSlider(panel, nil, -anchorRange, anchorRange, Get('anchorOffsetY') or 0, function(value) Set('anchorOffsetY', value); apply() end, 1, 150))
				end,
			})
		end,
	})
end

BUI.AlertMover = AlertMover

local AddRow = PageKit.AddSettingRow
local function BuildAlertsTab(tab)
	Layout.Section(tab, 'Alerts')

	do
		local db = BUI.GetDB().combatTimer
		local CombatTimer = BUI.CombatTimer
		local function Apply() CombatTimer.ApplySettings() end

		AddRow(tab, {
			title = 'Combat Timer',
			description = 'Elapsed time readout while you are in combat',
			checked = db.enabled,
			callback = function(enabled)
				CombatTimer.Toggle(enabled)
			end,
			accessoryWidth = 270,
			accessories = function(row)
				local eye = Controls.IconToggle(row, not db.locked, function(previewing)
					CombatTimer.SetLocked(not previewing)
				end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Preview (drag to move)' })
				CombatTimer._lockToggle = eye
				local mover = AlertMover(row, db, Apply, {
					selfTag = 'BUI_CombatTimer',
					unlock = {
						get = function() return not db.locked end,
						set = function(unlocked) CombatTimer.SetLocked(not unlocked) end,
					},
				})
				local settingsIcon = PageKit.SettingsIcon(row, {
					title = 'COMBAT TIMER', tooltip = 'Text size', options = {
						{ kind = 'slider', label = 'Font Size', min = 10, max = 40,
						  get = function() return db.fontSize end,
						  set = function(value) db.fontSize = value end, apply = Apply },
						{ label = 'Milliseconds',
						  get = function() return db.showMilliseconds == true end,
						  set = function(value) db.showMilliseconds = value end, apply = Apply },
					},
				})
				local fontDropdown = Controls.Dropdown(row, nil, fonts, db.font, function(value) db.font = value; Apply() end, nil, 140)
				local swatch = Controls.ColorSwatch(row, { r = db.colorR, g = db.colorG, b = db.colorB, a = 1, callback = function(red, green, blue)
					db.colorR, db.colorG, db.colorB = red, green, blue; Apply()
				end, tooltip = 'Text Color' })
				return { eye, mover, settingsIcon, fontDropdown, swatch }
			end,
		})
	end

	do
		local db = BUI.GetDB().combatMessage
		local CombatMessage = BUI.CombatMessage
		local function Apply() CombatMessage.Refresh() end

		AddRow(tab, {
			title = 'Combat Messages',
			description = 'On-screen text when combat starts and ends',
			checked = db.enabled,
			callback = function(enabled)
				db.enabled = enabled
				if enabled then CombatMessage.Enable() else CombatMessage.Disable() end
			end,
			accessoryWidth = 300,
			accessories = function(row)
				local eye = Controls.IconToggle(row, not db.locked, function(previewing)
					CombatMessage.SetLocked(not previewing)
				end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Preview (drag to move)' })
				CombatMessage._lockToggle = eye
				local mover = AlertMover(row, db, Apply, {
					selfTag = 'BUI_CombatMessage',
					unlock = {
						get = function() return not db.locked end,
						set = function(unlocked) CombatMessage.SetLocked(not unlocked) end,
					},
				})
				local settingsIcon = PageKit.SettingsIcon(row, {
					title = 'MESSAGES', tooltip = 'Text size & timing', options = {
						{ kind = 'slider', label = 'Font Size', min = 10, max = 40,
						  get = function() return db.fontSize end,
						  set = function(value) db.fontSize = value end, apply = Apply },
						{ kind = 'slider', label = 'Fade Time', min = 0.2, max = 3, step = 0.1,
						  get = function() return db.fadeTime end,
						  set = function(value) db.fadeTime = value end },
					},
				})
				local fontDropdown = Controls.Dropdown(row, nil, fonts, db.font, function(value) db.font = value; Apply() end, nil, 140)
				local enterColor, leaveColor = db.enterColor, db.leaveColor
				local leaveSwatch = Controls.ColorSwatch(row, { r = leaveColor[1], g = leaveColor[2], b = leaveColor[3], a = leaveColor[4], callback = function(red, green, blue, alpha)
					db.leaveColor = { red, green, blue, alpha }; Apply()
				end, tooltip = 'Leave Combat' })
				local enterSwatch = Controls.ColorSwatch(row, { r = enterColor[1], g = enterColor[2], b = enterColor[3], a = enterColor[4], callback = function(red, green, blue, alpha)
					db.enterColor = { red, green, blue, alpha }; Apply()
				end, tooltip = 'Enter Combat' })
				return { eye, mover, settingsIcon, fontDropdown, leaveSwatch, enterSwatch }
			end,
		})
	end

	do
		local db = BUI.GetDB().auras
		local function Apply() BUI.Auras.UpdateLowHp() end

		AddRow(tab, {
			title = 'Low HP Warning',
			description = 'Warning text when your health drops below the threshold',
			checked = db.lowHpWarning == true,
			callback = function(enabled) db.lowHpWarning = enabled; Apply() end,
			accessoryWidth = 270,
			accessories = function(row)
				local eye = Controls.IconToggle(row, db.lowHpLocked == false, function(previewing)
					db.lowHpLocked = not previewing; Apply()
				end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Preview (drag to move)' })
				lowHpEye = eye
				BUI.Auras._lowHpLockToggle = eye
				local mover = AlertMover(row, db, Apply, {
					selfTag = 'BUI_LowHpWarning',
					fields = {
						posX               = 'lowHpPosX',          posY          = 'lowHpPosY',
						anchorFrame        = 'lowHpAnchorFrame',   anchorPoint   = 'lowHpAnchorPoint',
						anchorOffsetX      = 'lowHpAnchorOffsetX', anchorOffsetY = 'lowHpAnchorOffsetY',
						centerHorizontally = 'lowHpCenterHorizontally',
					},
					unlock = {
						get = function() return not db.lowHpLocked end,
						set = function(unlocked) db.lowHpLocked = not unlocked; Apply() end,
					},
				})
				local settingsIcon = PageKit.SettingsIcon(row, {
					title = 'LOW HP WARNING', tooltip = 'Warning text, size & threshold', options = {
						{ kind = 'textbox', label = 'Warning Text',
						  get = function() return db.lowHpText end,
						  set = function(value) db.lowHpText = value end, apply = Apply },
						{ kind = 'slider', label = 'Font Size', min = 10, max = 60,
						  get = function() return db.lowHpFontSize end,
						  set = function(value) db.lowHpFontSize = value end, apply = Apply },
						{ kind = 'slider', label = 'Threshold %', min = 5, max = 95, step = 5,
						  get = function() return db.lowHpThreshold end,
						  set = function(value) db.lowHpThreshold = value end, apply = Apply },
					},
				})
				local fontDropdown = Controls.Dropdown(row, nil, fonts, db.lowHpFont, function(value) db.lowHpFont = value; Apply() end, nil, 140)
				local lowHpColor = db.lowHpColor
				local swatch = Controls.ColorSwatch(row, { r = lowHpColor.r, g = lowHpColor.g, b = lowHpColor.b, a = lowHpColor.a, callback = function(red, green, blue, alpha)
					db.lowHpColor = { r = red, g = green, b = blue, a = alpha }; Apply()
				end, tooltip = 'Text Color' })
				return { eye, mover, settingsIcon, fontDropdown, swatch }
			end,
		})
	end

	do
		local db = BUI.GetDB().auras
		local Auras = BUI.Auras
		local function Apply() Auras.Update() end

		AddRow(tab, {
			title = 'Pet Warnings',
			description = 'Alerts when your pet is dead, missing, idle or low on health',
			checked = db.petWarningsEnabled,
			callback = function(enabled) db.petWarningsEnabled = enabled; Apply() end,
			accessoryWidth = 270,
			accessories = function(row)
				local eye = Controls.IconToggle(row, not db.locked, function(previewing)
					Auras.SetLocked(not previewing)
				end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Preview (drag to move)' })
				Auras._lockToggle = eye
				local mover = AlertMover(row, db, Apply, {
					selfTag = 'BUI_PetWarning',
					unlock = {
						get = function() return not db.locked end,
						set = function(unlocked) Auras.SetLocked(not unlocked) end,
					},
				})
				local settingsIcon = Controls.Icon(row, {
					title = 'PET WARNINGS', tooltip = 'Warning types & text size',
					onChange = Apply,
					options = {
						{ kind = 'slider', label = 'Font Size', min = 14, max = 48,
						  get = function() return db.fontSize end,
						  set = function(value) db.fontSize = value end },
						{ label = 'Pet Not Attacking',
						  get = function() return db.petAttackWarning.enabled end,
						  set = function(value) db.petAttackWarning.enabled = value end },
						{ label = 'Pet Dead / Missing',
						  get = function() return db.petDeadWarning.enabled end,
						  set = function(value) db.petDeadWarning.enabled = value end },
						{ label = 'Grimoire of Sacrifice',
						  get = function() return db.grimoireSacrificeWarning.enabled end,
						  set = function(value) db.grimoireSacrificeWarning.enabled = value end },
						{ label = 'Playing Dead',
						  get = function() return db.playDeadWarning.enabled end,
						  set = function(value) db.playDeadWarning.enabled = value end },
						{ label = 'Pet Low Health',
						  get = function() return db.petHealthWarning.enabled end,
						  set = function(value) db.petHealthWarning.enabled = value end },
						{ kind = 'slider', label = 'Low Health %', min = 10, max = 80, step = 5, indent = 1,
						  get = function() return db.petHealthWarning.threshold end,
						  set = function(value) db.petHealthWarning.threshold = value end },
					},
				})
				local fontDropdown = Controls.Dropdown(row, nil, fonts, db.font, function(value) db.font = value; Apply() end, nil, 140)
				local warningColor = db.warningColor
				local swatch = Controls.ColorSwatch(row, { r = warningColor.r, g = warningColor.g, b = warningColor.b, a = warningColor.a, callback = function(red, green, blue, alpha)
					db.warningColor = { r = red, g = green, b = blue, a = alpha }; Apply()
				end, tooltip = 'Warning Color' })
				return { eye, mover, settingsIcon, fontDropdown, swatch }
			end,
		})
	end

	local db = BUI.GetDB().auras
	local function Apply() BUI.Auras.UpdateMark() end

	AddRow(tab, {
		title = "Hunter's Mark Warning",
		description = "Callout while your target is missing Hunter's Mark (hunters only)",
		checked = db.markWarning == true,
		callback = function(enabled) db.markWarning = enabled; Apply() end,
		accessoryWidth = 270,
		accessories = function(row)
			local eye = Controls.IconToggle(row, db.markLocked == false, function(previewing)
				db.markLocked = not previewing; Apply()
			end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Preview (drag to move)' })
			markWarningEye = eye
			BUI.Auras._markLockToggle = eye
			local mover = AlertMover(row, db, Apply, {
				selfTag = 'BUI_MarkWarning',
				fields = {
					posX               = 'markPosX',          posY          = 'markPosY',
					anchorFrame        = 'markAnchorFrame',   anchorPoint   = 'markAnchorPoint',
					anchorOffsetX      = 'markAnchorOffsetX', anchorOffsetY = 'markAnchorOffsetY',
					centerHorizontally = 'markCenterHorizontally',
				},
				unlock = {
					get = function() return db.markLocked == false end,
					set = function(unlocked) db.markLocked = not unlocked; Apply() end,
				},
			})
			local settingsIcon = PageKit.SettingsIcon(row, {
				title = "HUNTER'S MARK", tooltip = 'Warning text, style & visibility', options = {
					{ kind = 'textbox', label = 'Warning Text',
					  get = function() return db.markText end,
					  set = function(value) db.markText = value end, apply = Apply },
					{ kind = 'slider', label = 'Font Size', min = 10, max = 48,
					  get = function() return db.markFontSize end,
					  set = function(value) db.markFontSize = value end, apply = Apply },
					{ label = 'Spell Icon',
					  get = function() return db.markShowIcon ~= false end,
					  set = function(value) db.markShowIcon = value end, apply = Apply },
					{ label = 'Pulse Icon',
					  get = function() return db.markPulse ~= false end,
					  set = function(value) db.markPulse = value end, apply = Apply },
					{ label = 'Combat Only',
					  get = function() return db.markCombatOnly == true end,
					  set = function(value) db.markCombatOnly = value end, apply = Apply },
					{ label = 'Group Only',
					  get = function() return db.markGroupOnly == true end,
					  set = function(value) db.markGroupOnly = value end, apply = Apply },
					{ label = 'Hide In Town',
					  get = function() return db.markHideInTown == true end,
					  set = function(value) db.markHideInTown = value end, apply = Apply },
				},
			})
			local fontDropdown = Controls.Dropdown(row, nil, fonts, db.markFont, function(value) db.markFont = value; Apply() end, nil, 140)
			local markColor = db.markColor
			local swatch = Controls.ColorSwatch(row, { r = markColor.r, g = markColor.g, b = markColor.b, a = markColor.a, callback = function(red, green, blue, alpha)
				db.markColor = { r = red, g = green, b = blue, a = alpha }; Apply()
			end, tooltip = 'Text Color' })
			return { eye, mover, settingsIcon, fontDropdown, swatch }
		end,
	})

	do
		local db = BUI.GetDB().gatewayAlert
		local function Tracker() return BUI.BuffTracking.Display.GetTracker('gatewayAlert') end
		local function Apply() local tracker = Tracker(); if tracker then tracker.Refresh() end end

		AddRow(tab, {
			title = 'Gateway Alert',
			description = 'Text while a Demonic Gateway is in reach and off cooldown; needs a Gateway Control Shard on an action bar',
			checked = db.enabled,
			callback = function(enabled) db.enabled = enabled; Apply() end,
			accessoryWidth = 270,
			accessories = function(row)
				local eye = Controls.IconToggle(row, db.showAnchor, function(unlocked)
					db.showAnchor = unlocked; Apply()
				end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Unlock (drag to move)' })
				BUI.BuffTracking.Display.RegisterAnchorCallback('gatewayAlert', function(state) eye:SetValue(state) end)
				local mover = AlertMover(row, db, Apply, { selfTag = 'BUI_GatewayAlert' })
				local settingsIcon = PageKit.SettingsIcon(row, {
					title = 'GATEWAY ALERT', tooltip = 'Text & sound', options = {
						{ kind = 'textbox', label = 'Text',
						  get = function() return db.customText end,
						  set = function(value) db.customText = value end, apply = Apply },
						{ kind = 'slider', label = 'Font Size', min = 10, max = 48,
						  get = function() return db.textSize end,
						  set = function(value) db.textSize = value end, apply = Apply },
						{ kind = 'dropdown', label = 'Sound', items = BUI.BuildSoundDropdownItems(),
						  get = function() return db.sound end,
						  set = function(value) db.sound = value; BUI.PlaySoundByName(value) end },
					},
				})
				local fontDropdown = Controls.Dropdown(row, nil, fonts, db.font, function(value) db.font = value; Apply() end, nil, 140)
				local textColor = db.textColor
				local swatch = Controls.ColorSwatch(row, { r = textColor.r, g = textColor.g, b = textColor.b, a = textColor.a, callback = function(red, green, blue, alpha)
					db.textColor = { r = red, g = green, b = blue, a = alpha }; Apply()
				end, tooltip = 'Text Color' })
				return { eye, mover, settingsIcon, fontDropdown, swatch }
			end,
		})
	end

	do
		local db = BUI.GetDB().bloodlust
		local Bloodlust = BUI.Bloodlust
		local function Apply() Bloodlust.Refresh() end

		AddRow(tab, {
			title = 'Bloodlust',
			description = 'Tracks Bloodlust, Heroism and similar haste buffs',
			checked = db.enabled,
			callback = function(enabled) db.enabled = enabled; Apply() end,
			accessoryWidth = 300,
			accessories = function(row)
				local eye = Controls.IconToggle(row, Bloodlust.IsPreviewing(), function(previewing)
					if previewing then Bloodlust.StartPreview() else Bloodlust.StopPreview() end
				end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Preview' })
				bloodlustEye = eye
				local mover = AlertMover(row, db, Apply)
				local configure = Controls.GhostButton(row, 'Configure', 100, function() BUI.PageEngine.NavigateToID('bloodlust') end, 'Open the Bloodlust page')
				local fontDropdown = Controls.Dropdown(row, nil, fonts, db.font, function(value) db.font = value; Apply() end, nil, 140)
				return { eye, mover, configure, fontDropdown }
			end,
		})
	end

	do
		local db = BUI.GetDB().crosshair
		local Crosshair = BUI.Crosshair
		local function Apply() Crosshair.Refresh() end

		Layout.Section(tab, 'Crosshair')

		AddRow(tab, {
			title = 'Crosshair',
			description = 'Customizable reticle at the center of your screen',
			checked = db.enabled,
			callback = function(enabled) db.enabled = enabled; Apply() end,
			accessoryWidth = 270,
			accessories = function(row)
				local eye = Controls.IconToggle(row, Crosshair.IsPreviewing(), function(previewing)
					Crosshair.SetPreview(previewing)
				end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Preview' })
				crosshairEye = eye
				local mover = PageKit.PositionIcon(row, {
					title = 'POSITION', tooltip = 'Screen offset', options = {
						{ kind = 'slider', label = 'X Offset', min = -500, max = 500,
						  get = function() return db.offsetX end,
						  set = function(value) db.offsetX = value end, apply = Apply },
						{ kind = 'slider', label = 'Y Offset', min = -500, max = 500,
						  get = function() return db.offsetY end,
						  set = function(value) db.offsetY = value end, apply = Apply },
					},
				})
				local settingsIcon = PageKit.SettingsIcon(row, {
					title = 'CROSSHAIR', tooltip = 'Appearance & visibility', options = {
						{ kind = 'slider', label = 'Size', min = 5, max = 100,
						  get = function() return db.size end,
						  set = function(value) db.size = value end, apply = Apply },
						{ kind = 'slider', label = 'Thickness', min = 1, max = 10,
						  get = function() return db.thickness end,
						  set = function(value) db.thickness = value end, apply = Apply },
						{ kind = 'slider', label = 'Center Gap', min = 0, max = 30,
						  get = function() return db.gap end,
						  set = function(value) db.gap = value end, apply = Apply },
						{ kind = 'slider', label = 'Opacity', min = 10, max = 100, step = 5,
						  get = function() return db.alpha * 100 end,
						  set = function(value) db.alpha = value / 100 end, apply = Apply },
						{ label = 'Hide Out of Combat',
						  get = function() return db.hideOutOfCombat end,
						  set = function(value) db.hideOutOfCombat = value end, apply = Apply },
						{ label = 'Hide in Town',
						  get = function() return db.hideInTown end,
						  set = function(value) db.hideInTown = value end, apply = Apply },
						{ label = 'Range Indicator · ' .. Crosshair.RangeLabel(),
						  get = function() return db.rangeIndicator end,
						  set = function(value) db.rangeIndicator = value end, apply = Apply },
						{ kind = 'swatch', label = 'In Range Color', tooltip = 'In range',
						  get = function() return db.inRangeColor end,
						  set = function(color) db.inRangeColor = { color[1], color[2], color[3] } end, apply = Apply },
						{ kind = 'swatch', label = 'Out of Range Color', tooltip = 'Out of range',
						  get = function() return db.outOfRangeColor end,
						  set = function(color) db.outOfRangeColor = { color[1], color[2], color[3] } end, apply = Apply },
					},
				})
				local styleDropdown = Controls.Dropdown(row, nil, {
					{ value = 'cross', text = 'Cross (+)' }, { value = 'dot', text = 'Dot' },
				}, db.style, function(value) db.style = value; Apply() end, nil, 140)
				local swatch = Controls.ColorSwatch(row, { r = db.colorR, g = db.colorG, b = db.colorB, a = 1, callback = function(red, green, blue)
					db.colorR, db.colorG, db.colorB = red, green, blue; Apply()
				end, tooltip = 'Crosshair Color' })
				return { eye, mover, settingsIcon, styleDropdown, swatch }
			end,
		})

		local MELEE_SPEC_IDS = Crosshair.MELEE_SPEC_IDS

		local specItems = {}
		local classRows = {}
		for classID = 1, GetNumClasses() do
			local className, classFile = GetClassInfo(classID)
			if className then
				local classColor = RAID_CLASS_COLORS[classFile]
				local colorStr = classColor and classColor.colorStr or 'ffcccccc'
				for specIndex = 1, GetNumSpecializationsForClassID(classID) do
					local specID, specName = GetSpecializationInfoForClassID(classID, specIndex)
					if specID then
						classRows[#classRows + 1] = {
							className = className,
							value = specID,
							text = ('|c%s%s|r  |cff888888%s|r'):format(colorStr, specName or ('Spec ' .. specIndex), className),
						}
					end
				end
			end
		end
		table.sort(classRows, function(leftRow, rightRow)
			if leftRow.className ~= rightRow.className then return leftRow.className < rightRow.className end
			return leftRow.text < rightRow.text
		end)
		for _, row in ipairs(classRows) do
			specItems[#specItems + 1] = { value = row.value, text = row.text }
		end
		local specsSelected = {}
		if db.specs then
			for specID, selected in pairs(db.specs) do specsSelected[specID] = selected end
		else
			for _, item in ipairs(specItems) do specsSelected[item.value] = true end
		end
		local function BuildAllMap(items)
			local map = {}
			for _, item in ipairs(items) do
				local specID = (type(item) == 'table') and (item.value or item[1]) or item
				map[specID] = true
			end
			return map
		end
		local function BuildMeleeMap(items)
			local map = {}
			for _, item in ipairs(items) do
				local specID = (type(item) == 'table') and (item.value or item[1]) or item
				if MELEE_SPEC_IDS[specID] then map[specID] = true end
			end
			return map
		end

		local specsActions = {
			{ text = 'Select all',   onClick = function(items, set) set(BuildAllMap(items))   end },
			{ text = 'Deselect all', onClick = function(_, set)     set({})                   end },
			{ text = 'Melee only',   onClick = function(items, set) set(BuildMeleeMap(items)) end },
		}

		AddRow(tab, {
			title = 'Show for Specs',
			description = 'Specializations the crosshair is shown for',
			controlWidth = 272,
			control = function(row)
				return Controls.MultiDropdown(row, nil, specItems, specsSelected, function(map)
					db.specs = map
					Apply()
				end, nil, 240, 16, { actions = specsActions })
			end,
		})

	end
end

BUI.PageEngine.RegisterPage('auras', {
	title = '|cffFF0000Weaker|r Auras',
	buttonText = '|cffFF0000Weaker|r Auras',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems('GLOBAL')
		BUI.Tools.AddPageWatermark(pageFrame)

		local page = Layout.Page(pageFrame, { 'Alerts', 'GCD History' })
		pageFrame._page = page
		BuildAlertsTab(page:GetTab(1))
		BUI.StreamerToolsPage.BuildGCDHistoryTab(page:GetTab(2))
		page:AutoRefresh()

		local MODULE_TABS = { gcdHistory = 2 }
		pageFrame._selectModule = function(moduleId)
			if moduleId == 'bloodlust' then BUI.PageEngine.NavigateToID('bloodlust'); return end
			page:SetTab(MODULE_TABS[moduleId] or 1)
		end
	end,
	OnHide = function()
		local settings = BUI.GetDB().auras
		if settings.locked then BUI.Auras.ShowPreview(false) end
		settings.lowHpLocked = true
		BUI.Auras.UpdateLowHp()
		ClearPreviewToggle(lowHpEye)
		if settings.markLocked == false then
			settings.markLocked = true
			BUI.Auras.UpdateMark()
		end
		ClearPreviewToggle(markWarningEye)
		BUI.Crosshair.SetPreview(false)
		ClearPreviewToggle(crosshairEye)
		if BUI.Bloodlust.IsPreviewing() then
			BUI.Bloodlust.StopPreview()
		end
		ClearPreviewToggle(bloodlustEye)
		if not BUI.GetDB().gcdHistory.locked then
			BUI.GCDHistory.SetLocked(true)
		end
	end,
})
