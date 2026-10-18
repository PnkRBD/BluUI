local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout = BUILib.Layout

local PAGE_WIDTH = 960
local MENU_WIDTH = 150
local TEXT_OFFSET_RANGE = 60

local STYLES = {
	{ value = 'cross', text = 'Cross' },
	{ value = 'dot', text = 'Dot' },
}

local LOW_HP_FIELDS = {
	posX = 'lowHpPosX', posY = 'lowHpPosY',
	anchorFrame = 'lowHpAnchorFrame', anchorPoint = 'lowHpAnchorPoint',
	anchorOffsetX = 'lowHpAnchorOffsetX', anchorOffsetY = 'lowHpAnchorOffsetY',
	centerHorizontally = 'lowHpCenterHorizontally',
}

local fonts, sounds
local specList

local Kit = BUI.OptionsKit
local Window, Repaint, Option, Toggle, Color, TableColor = Kit.Window, Kit.Repaint, Kit.Option, Kit.Toggle, Kit.Color, Kit.TableColor

local function Font(db, key)
	return { entries = fonts, width = MENU_WIDTH, get = function() return db[key] end, set = function(value) db[key] = value end }
end

local function TextTool(options)
	return { icon = 'text', tooltip = 'Text', title = 'Text', slot = 'text', options = options }
end

local function PageCog(label, id)
	return { icon = 'cog', tooltip = 'Open the ' .. label .. ' page', slot = 'settings', onClick = function() BUI.PageEngine.NavigateToID(id) end }
end

local function Pin(db, options)
	local tool = BUI.PositionTool(db, options)
	tool.slot = 'position'
	return tool
end

local function Eye(tooltip, get, set)
	return { icon = 'eye', tooltip = tooltip, get = get, set = set }
end

local function ArrayColor(db, label, key)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = false,
		get = function()
			local color = db[key]
			return color[1], color[2], color[3], 1
		end,
		set = function(red, green, blue) db[key] = { red, green, blue } end,
	}
end

local function ChannelColor(db, label, alphaKey)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = alphaKey ~= nil,
		get = function() return db.colorR, db.colorG, db.colorB, alphaKey and db[alphaKey] or 1 end,
		set = function(red, green, blue, alpha)
			db.colorR, db.colorG, db.colorB = red, green, blue
			if alphaKey then db[alphaKey] = alpha end
		end,
	}
end

local function CombatTimerRow()
	local db = BUI.GetDB().combatTimer
	local CombatTimer = BUI.CombatTimer
	BUI.OnModuleChange('combatTimer', Repaint)
	return {
		id = 'combatTimer', name = 'Combat Timer', sub = 'How long you have been in combat', after = CombatTimer.ApplySettings,
		switch = { get = function() return db.enabled == true end, set = CombatTimer.Toggle },
		tools = {
			ChannelColor(db, 'Text color'),
			Font(db, 'font'),
			TextTool({ Option(db, 'Font size', 'fontSize', { min = 10, max = 40, step = 1 }) }),
			{ tooltip = 'Readout', title = 'Combat timer', slot = 'settings', options = {
				Option(db, 'Milliseconds', 'showMilliseconds'),
			} },
			Pin(db, { selfTag = 'BUI_CombatTimer' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) CombatTimer.SetLocked(not value) end),
		},
	}
end

local function CombatResRow()
	local db = BUI.GetDB().combatRes
	local CombatRes = BUI.CombatRes
	BUI.OnModuleChange('combatRes', Repaint)
	return {
		id = 'combatRes', name = 'Combat Rez', sub = 'Charges and recharge time in raids and keys', after = CombatRes.ApplySettings,
		switch = { get = function() return db.enabled == true end, set = CombatRes.Toggle },
		tools = {
			TableColor(db, 'Text color', 'textColor'),
			TableColor(db, 'No charges color', 'emptyColor'),
			Font(db, 'font'),
			TextTool({
				Option(db, 'Show timer', 'showTimer'),
				Option(db, 'Timer size', 'timerSize', { min = 8, max = 40, step = 1 }),
				Option(db, 'Timer position', 'timerPosition', { entries = BUI.C.TEXT_PLACEMENT_OPTIONS, width = MENU_WIDTH }),
				Option(db, 'Timer horizontal', 'timerOffsetX', { min = -TEXT_OFFSET_RANGE, max = TEXT_OFFSET_RANGE, step = 1 }),
				Option(db, 'Timer vertical', 'timerOffsetY', { min = -TEXT_OFFSET_RANGE, max = TEXT_OFFSET_RANGE, step = 1 }),
				Option(db, 'Show charges', 'showCharges', { separator = true }),
				Option(db, 'Charges size', 'chargesSize', { min = 8, max = 40, step = 1 }),
				Option(db, 'Charges position', 'chargesPosition', { entries = BUI.C.TEXT_PLACEMENT_OPTIONS, width = MENU_WIDTH }),
				Option(db, 'Charges horizontal', 'chargesOffsetX', { min = -TEXT_OFFSET_RANGE, max = TEXT_OFFSET_RANGE, step = 1 }),
				Option(db, 'Charges vertical', 'chargesOffsetY', { min = -TEXT_OFFSET_RANGE, max = TEXT_OFFSET_RANGE, step = 1 }),
			}),
			{ tooltip = 'Icon', title = 'Icon', slot = 'settings', options = {
				Option(db, 'Show icon', 'showIcon'),
				TableColor(db, 'Border color', 'borderColor'),
				Option(db, 'Icon size', 'size', { min = 24, max = 96, step = 1 }),
				Option(db, 'Recharge swipe', 'showSwipe'),
				Option(db, 'Glow when a charge returns', 'glowOnCharge'),
			} },
			Pin(db, { selfTag = 'BUI_CombatRes' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) CombatRes.SetLocked(not value) end),
		},
	}
end

local function CombatMessagesRow()
	local db = BUI.GetDB().combatMessage
	local CombatMessage = BUI.CombatMessage
	BUI.OnModuleChange('combatMessage', Repaint)
	return {
		id = 'combatMessage', name = 'Combat Messages', sub = 'Text when combat starts and ends', after = CombatMessage.Refresh,
		switch = { get = function() return db.enabled == true end, set = function(value)
			db.enabled = value
			if value then CombatMessage.Enable() else CombatMessage.Disable() end
		end },
		tools = {
			Color(db, 'Enter combat', 'enterColor'),
			Color(db, 'Leave combat', 'leaveColor'),
			Font(db, 'font'),
			TextTool({ Option(db, 'Font size', 'fontSize', { min = 10, max = 40, step = 1 }) }),
			{ tooltip = 'Timing', title = 'Messages', slot = 'settings', options = {
				Option(db, 'Fade time', 'fadeTime', { min = 0.2, max = 3, step = 0.1 }),
			} },
			Pin(db, { selfTag = 'BUI_CombatMessage' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) CombatMessage.SetLocked(not value) end),
		},
	}
end

local function SecondaryStatsRow()
	local db = BUI.GetDB().secondaryStats
	local SecondaryStats = BUI.Auras.SecondaryStats
	BUI.OnModuleChange('secondaryStats', Repaint)
	return {
		id = 'secondaryStats', name = 'Secondary Stats', sub = 'Your stats on screen', after = SecondaryStats.Refresh,
		switch = Toggle(db, nil, 'enabled'),
		tools = {
			PageCog('Secondary Stats', 'secondaryStats'),
			Pin(db, { selfTag = 'BUI_SecondaryStats' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) SecondaryStats.SetLocked(not value) end),
		},
	}
end

local function KeystoneReminderRow()
	local db = BUI.GetDB().keystoneReminder
	local KeystoneReminder = BUI.Auras.KeystoneReminder
	BUI.OnModuleChange('keystoneReminder', Repaint)
	return {
		id = 'keystoneReminder', name = 'Keystone Reminder', sub = 'Dungeon and teleport when a key group forms', after = KeystoneReminder.Refresh,
		switch = { get = function() return db.enabled == true end, set = function(value)
			db.enabled = value
			if value then KeystoneReminder.Enable() else KeystoneReminder.Disable() end
		end },
		tools = {
			Pin(db, { selfTag = 'BUI_KeystoneReminder' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) KeystoneReminder.SetLocked(not value) end),
		},
	}
end

local function PrivateWarningRow()
	local db = BUI.GetDB().privateWarning
	local PrivateWarning = BUI.Auras.PrivateWarning
	BUI.OnModuleChange('privateWarning', Repaint)
	return {
		id = 'privateWarning', name = 'Private raid warning', sub = "Moves Blizzard's private boss warnings", after = PrivateWarning.Refresh,
		switch = Toggle(db, nil, 'enabled'),
		tools = {
			TextTool({ Option(db, 'Scale', 'scale', { min = 50, max = 200, step = 5 }) }),
			Pin(db),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) PrivateWarning.SetLocked(not value) end),
		},
	}
end

local function LowHpRow()
	local db = BUI.GetDB().auras
	local Auras = BUI.Auras
	BUI.OnModuleChange('lowHp', Repaint)
	return {
		id = 'lowHp', name = 'Low HP Warning', sub = 'Text when your health is low', after = Auras.UpdateLowHp,
		switch = Toggle(db, nil, 'lowHpWarning'),
		tools = {
			TableColor(db, 'Text color', 'lowHpColor', true),
			Font(db, 'lowHpFont'),
			TextTool({
				Option(db, 'Warning text', 'lowHpText', { kind = 'input', placeholder = 'Warning text' }),
				Option(db, 'Font size', 'lowHpFontSize', { min = 10, max = 60, step = 1 }),
			}),
			{ tooltip = 'Threshold', title = 'Low HP warning', slot = 'settings', options = {
				Option(db, 'Threshold %', 'lowHpThreshold', { min = 5, max = 95, step = 5 }),
			} },
			Pin(db, { selfTag = 'BUI_LowHpWarning', fields = LOW_HP_FIELDS }),
			Eye('Preview, drag to move', function() return db.lowHpLocked == false end, function(value)
				db.lowHpLocked = not value
				Auras.UpdateLowHp()
			end),
		},
	}
end

local function DurabilityWarningRow()
	local db = BUI.GetDB().durabilityWarning
	local DurabilityWarning = BUI.Auras.DurabilityWarning
	BUI.OnModuleChange('durabilityWarning', Repaint)
	return {
		id = 'durabilityWarning', name = 'Durability Warning', sub = 'Text when your gear needs repair', after = DurabilityWarning.Refresh,
		switch = Toggle(db, nil, 'enabled'),
		tools = {
			TableColor(db, 'Text color', 'textColor', true),
			Font(db, 'font'),
			TextTool({
				Option(db, 'Warning text', 'text', { kind = 'input', placeholder = 'Warning text' }),
				Option(db, 'Font size', 'fontSize', { min = 10, max = 60, step = 1 }),
				Option(db, 'Show percent', 'showPercent'),
			}),
			{ tooltip = 'Threshold', title = 'Durability warning', slot = 'settings', options = {
				Option(db, 'Threshold %', 'threshold', { min = 5, max = 95, step = 5 }),
			} },
			Pin(db, { selfTag = 'BUI_DurabilityWarning' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) DurabilityWarning.SetLocked(not value) end),
		},
	}
end

local function PetWarningsRow()
	local db = BUI.GetDB().auras
	local Auras = BUI.Auras
	BUI.OnModuleChange('petWarnings', Repaint)
	return {
		id = 'petWarnings', name = 'Pet Warnings', sub = 'Dead, missing, idle or hurt pet', after = Auras.Update,
		switch = Toggle(db, nil, 'petWarningsEnabled'),
		tools = {
			TableColor(db, 'Warning color', 'warningColor', true),
			Font(db, 'font'),
			TextTool({ Option(db, 'Font size', 'fontSize', { min = 14, max = 48, step = 1 }) }),
			{ tooltip = 'Warning types', title = 'Pet warnings', slot = 'settings', options = {
				Toggle(db.petAttackWarning, 'Pet not attacking', 'enabled'),
				Toggle(db.petDeadWarning, 'Pet dead or missing', 'enabled'),
				Toggle(db.grimoireSacrificeWarning, 'Grimoire of Sacrifice', 'enabled'),
				Toggle(db.playDeadWarning, 'Playing dead', 'enabled'),
				Toggle(db.petHealthWarning, 'Pet low health', 'enabled'),
				{ label = 'Low health %', min = 10, max = 80, step = 5, get = function() return db.petHealthWarning.threshold end, set = function(value) db.petHealthWarning.threshold = value end },
			} },
			Pin(db, { selfTag = 'BUI_PetWarning' }),
			Eye('Preview, drag to move', function() return not db.locked end, function(value) Auras.SetLocked(not value) end),
		},
	}
end

local function GatewayRow()
	local db = BUI.GetDB().gatewayAlert
	local Display = BUI.BuffTracking.Display
	local function Apply()
		local tracker = Display.GetTracker('gatewayAlert')
		if tracker then tracker.Refresh() end
	end
	BUI.OnModuleChange('gatewayAlert', Repaint)
	return {
		id = 'gatewayAlert', name = 'Gateway Alert', sub = 'Text when a Demonic Gateway is in reach', after = Apply,
		switch = Toggle(db, nil, 'enabled'),
		tools = {
			TableColor(db, 'Text color', 'textColor', true),
			Font(db, 'font'),
			TextTool({
				Option(db, 'Text', 'customText', { kind = 'input', placeholder = 'Alert text' }),
				Option(db, 'Font size', 'textSize', { min = 10, max = 48, step = 1 }),
			}),
			{ icon = 'sound', tooltip = 'Sound', title = 'Gateway alert', slot = 'settings', options = {
				{ label = 'Sound', entries = sounds, get = function() return db.sound end, set = function(value)
					db.sound = value
					BUI.PlaySoundByName(value)
				end },
			} },
			Pin(db, { selfTag = 'BUI_GatewayAlert' }),
			Eye('Unlock, drag to move', function() return db.showAnchor == true end, function(value)
				db.showAnchor = value
				Apply()
			end),
		},
	}
end

local function BloodlustRow()
	local db = BUI.GetDB().bloodlust
	local Bloodlust = BUI.Bloodlust
	BUI.OnModuleChange('bloodlust', Repaint)
	return {
		id = 'bloodlust', name = 'Bloodlust', sub = 'Lust timers and alerts', after = Bloodlust.Refresh,
		switch = Toggle(db, nil, 'enabled'),
		tools = {
			Font(db, 'font'),
			TextTool({ Option(db, 'Font size', 'fontSize', { min = 8, max = 48, step = 1 }) }),
			PageCog('Bloodlust', 'bloodlust'),
			Pin(db),
			Eye('Preview the alerts', Bloodlust.IsPreviewing, function(value)
				if value then Bloodlust.StartPreview() else Bloodlust.StopPreview() end
			end),
		},
	}
end

local function CDAnnouncerRow()
	local db = BUI.GetDB().cdAnnouncer
	local CDAnnouncer = BUI.CDAnnouncer
	BUI.OnModuleChange('cdAnnouncer', Repaint)
	return {
		id = 'cdAnnouncer', name = 'Cooldown Announcer', sub = 'Countdowns for cooldowns you pick', after = CDAnnouncer.Refresh,
		switch = Toggle(db, nil, 'enabled'),
		tools = {
			PageCog('Cooldown Announcer', 'cdAnnouncer'),
			Pin(db, { noAnchor = true }),
			Eye('Unlock the anchor to drag it, right-click it to lock', function() return db.showAnchor == true end, function(value)
				db.showAnchor = value
				CDAnnouncer.Refresh()
			end),
		},
	}
end

local function CooldownFlashRow()
	local db = BUI.GetDB().cooldownFlash
	local CooldownFlash = BUI.CooldownFlash
	BUI.OnModuleChange('cooldownFlash', Repaint)
	return {
		id = 'cooldownFlash', name = 'Cooldown Flash', sub = 'Flashes spells as they come off cooldown', after = CooldownFlash.Refresh,
		switch = Toggle(db, nil, 'enabled'),
		tools = {
			PageCog('Cooldown Flash', 'cooldownFlash'),
			Pin(db, { selfTag = 'BUI_CooldownFlash' }),
			Eye('Unlock to drag the icons, right-click them to lock', function() return db.showAnchor == true end, function(value)
				db.showAnchor = value
				CooldownFlash.Refresh()
			end),
		},
	}
end

local function SpecList()
	if specList then return specList end
	specList = {}
	for classID = 1, GetNumClasses() do
		local className, classFile = GetClassInfo(classID)
		local colorText = RAID_CLASS_COLORS[classFile].colorStr
		for specIndex = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
			local specID, specName = GetSpecializationInfoForClassID(classID, specIndex)
			specList[#specList + 1] = { className = className, id = specID, text = ('|c%s%s|r  |cff888888%s|r'):format(colorText, specName, className) }
		end
	end
	table.sort(specList, function(left, right)
		if left.className ~= right.className then return left.className < right.className end
		return left.text < right.text
	end)
	return specList
end

local function SpecsTool(ui, db, apply)
	local specs = SpecList()
	local melee = BUI.Crosshair.MELEE_SPEC_IDS
	local function Selected()
		if db.specs then return db.specs end
		local all = {}
		for _, spec in ipairs(specs) do all[spec.id] = true end
		return all
	end
	local function Choose(filter)
		local map = {}
		for _, spec in ipairs(specs) do
			if filter(spec.id) then map[spec.id] = true end
		end
		db.specs = map
		apply()
		Repaint()
	end
	local function Count()
		local selected, count = Selected(), 0
		for _, spec in ipairs(specs) do
			if selected[spec.id] then count = count + 1 end
		end
		return count
	end
	return {
		kind = 'custom',
		build = function(parent)
			local dropdown = ui.Dropdown(parent, MENU_WIDTH, function()
				local selected = Selected()
				local items = {
					{ text = 'Select all', callback = function() Choose(function() return true end) end },
					{ text = 'Deselect all', callback = function() Choose(function() return false end) end },
					{ text = 'Melee only', callback = function() Choose(function(id) return melee[id] == true end) end },
					{ separator = true },
				}
				for _, spec in ipairs(specs) do
					local item = { text = spec.text, checked = selected[spec.id] == true }
					item.callback = function()
						local map = CopyTable(Selected())
						map[spec.id] = not map[spec.id] or nil
						item.checked = map[spec.id] == true
						db.specs = map
						apply()
						Repaint()
						return true
					end
					items[#items + 1] = item
				end
				return items
			end)
			ui.Bind(dropdown, function()
				local count = Count()
				dropdown.label:SetText(count == #specs and 'All specs' or count == 0 and 'No specs' or (count .. ' specs'))
			end)
			return dropdown
		end,
	}
end

local function CrosshairRow(ui)
	local db = BUI.GetDB().crosshair
	local Crosshair = BUI.Crosshair
	return {
		id = 'crosshair', name = 'Crosshair', sub = 'A reticle at the center of your screen', after = Crosshair.Refresh,
		switch = Toggle(db, nil, 'enabled'),
		tools = {
			ChannelColor(db, 'Crosshair color', 'alpha'),
			{ entries = STYLES, width = MENU_WIDTH, get = function() return db.style end, set = function(value) db.style = value end },
			SpecsTool(ui, db, Crosshair.Refresh),
			{ tooltip = 'Appearance and visibility', title = 'Crosshair', slot = 'settings', options = {
				Option(db, 'Size', 'size', { min = 5, max = 100, step = 1 }),
				Option(db, 'Thickness', 'thickness', { min = 1, max = 10, step = 1 }),
				Option(db, 'Center gap', 'gap', { min = 0, max = 30, step = 1 }),
				Option(db, 'Hide out of combat', 'hideOutOfCombat'),
				Option(db, 'Hide in town', 'hideInTown'),
				Option(db, 'Range indicator, ' .. Crosshair.RangeLabel(), 'rangeIndicator'),
				ArrayColor(db, 'In range color', 'inRangeColor'),
				ArrayColor(db, 'Out of range color', 'outOfRangeColor'),
			} },
			{ icon = 'location', tooltip = 'Screen offset', title = 'Position', slot = 'position', options = {
				Option(db, 'Horizontal offset', 'offsetX', { min = -500, max = 500, step = 1 }),
				Option(db, 'Vertical offset', 'offsetY', { min = -500, max = 500, step = 1 }),
			} },
			Eye('Preview', Crosshair.IsPreviewing, Crosshair.SetPreview),
		},
	}
end

local ROWS = {
	CombatTimerRow, CombatResRow, CombatMessagesRow, SecondaryStatsRow, KeystoneReminderRow, PrivateWarningRow,
	LowHpRow, DurabilityWarningRow, PetWarningsRow, GatewayRow, BloodlustRow, CDAnnouncerRow, CooldownFlashRow, CrosshairRow,
}

local function GeneralBoard(ui, parent, width, page)
	local items = {}
	for index, Row in ipairs(ROWS) do items[index] = Row(ui) end
	return ui.GroupBoard(parent, width, {
		title = 'General',
		description = 'Drag a row to reorder it or drop it on a group. The eye shows an alert so you can move it.',
		layout = BUI.GetDB().auraGroups,
		items = items,
		noun = { 'aura', 'auras' },
		resize = function() page:Resize() end,
		rebuild = BUI.PageEngine.RefreshCurrentPage,
	})
end

local function General(ui, _, parent, width, page)
	return { GeneralBoard(ui, parent, width, page) }
end

BUI.PageEngine.RegisterPage('auras', {
	title = '|cffFF0000Weaker|r Auras',
	buttonText = '|cffFF0000Weaker|r Auras',
	icon = 'glow',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		sounds = BUI.BuildSoundDropdownItems()
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local enabled = BUI.IsModuleEnabled('auras')
		local handle = Layout.TablePage(page:GetTab(1), { window = Window() }, {
			icon = 'glow',
			title = '|cffFF0000Weaker|r Auras',
			placeholder = 'Search auras...',
			disabled = function() return not enabled end,
			tools = {
				{ icon = 'enable', tooltip = 'Turn the auras module on or off, needs a reload', get = function() return BUI.IsModuleEnabled('auras') end, set = function(value)
					BUI.ModulesPage.ConfirmReload('auras', value, Repaint)
				end },
			},
			tabs = {
				{ label = 'General', build = General },
				{ label = 'GCD History', build = BUI.StreamerToolsPage.GCDHistory },
				{ label = 'Class', build = BUI.BuffTrackingPage.Class },
			},
		})
		pageFrame._page = handle
		page:AutoRefresh()
	end,
	OnHide = function()
		local settings = BUI.GetDB().auras
		if not settings.locked then BUI.Auras.SetLocked(true) end
		if settings.lowHpLocked == false then
			settings.lowHpLocked = true
			BUI.Auras.UpdateLowHp()
		end
		BUI.Crosshair.SetPreview(false)
		if BUI.Bloodlust.IsPreviewing() then BUI.Bloodlust.StopPreview() end
		if not BUI.GetDB().gcdHistory.locked then BUI.GCDHistory.SetLocked(true) end
		local db = BUI.GetDB()
		if not db.combatTimer.locked then BUI.CombatTimer.SetLocked(true) end
		if not db.combatRes.locked then BUI.CombatRes.SetLocked(true) end
		if not db.combatMessage.locked then BUI.CombatMessage.SetLocked(true) end
		if not db.secondaryStats.locked then BUI.Auras.SecondaryStats.SetLocked(true) end
		if not db.keystoneReminder.locked then BUI.Auras.KeystoneReminder.SetLocked(true) end
		if not db.privateWarning.locked then BUI.Auras.PrivateWarning.SetLocked(true) end
		if not db.durabilityWarning.locked then BUI.Auras.DurabilityWarning.SetLocked(true) end
		if not settings.markLocked then
			settings.markLocked = true
			BUI.Auras.UpdateMark()
		end
		local overlays = BUI.BuffTracking
		if overlays.KillCommandOverlay.IsPreviewing() then overlays.KillCommandOverlay.StopPreview() end
	end,
})
