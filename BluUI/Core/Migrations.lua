local _, BUI = ...

local MigratedMediaNames = {
	['AUI Gradient']       = 'BUI Gradient',
	['Azor Wailing Arrow'] = 'None',
}

local function FixLegacyValue(value)
	local mapped = MigratedMediaNames[value]
	if mapped then return mapped end
	value = value:gsub('^Interface\\AddOns\\AzortharionUI\\Media\\Fonts\\', 'Interface\\AddOns\\BluUI\\Media\\Fonts\\')
	if value:sub(1, 4) == 'AUI_' then
		value = 'BUI_' .. value:sub(5)
	end
	return value
end

local function FixLegacyValues(targetTable, depth)
	if type(targetTable) ~= 'table' or depth > 20 then return end
	for key, value in pairs(targetTable) do
		if type(value) == 'string' then
			local fixed = FixLegacyValue(value)
			if fixed ~= value then targetTable[key] = fixed end
		elseif type(value) == 'table' then
			FixLegacyValues(value, depth + 1)
		end
	end
end

function BUI.FixLegacyValues(targetTable)
	FixLegacyValues(targetTable, 1)
end

local PROFILE_MIGRATION_VERSION = 5

function BUI.MigrateProfile(profile)
	if not profile then return end
	local general = profile.general
	if general and (general._buiMigrationVersion or 0) >= PROFILE_MIGRATION_VERSION then return end

	FixLegacyValues(profile, 1)

	if profile.unitFrames and not (profile.general and profile.general._absorbColorBluFramesMigrated_v3) then
		profile.general = profile.general or {}
		profile.general._absorbColorBluFramesMigrated_v3 = true
		profile.unitFrames.shieldColor           = { 1, 1, 1, 0.6 }
		profile.unitFrames.shieldDirection       = 'right'
		profile.unitFrames.shieldOverlay         = 'Stripes'
		profile.unitFrames.healAbsorbColor       = { 0.9, 0.1, 0.1, 0.6 }
		profile.unitFrames.healAbsorbDirection   = 'left'
		profile.unitFrames.healAbsorbOverlay     = 'Stripes'
		profile.unitFrames.shieldShowTexture     = nil
		profile.unitFrames.healAbsorbShowTexture = nil
	end

	if profile.unitFrames and not (profile.general and profile.general._absorbColorGreenFix_v4) then
		profile.general = profile.general or {}
		profile.general._absorbColorGreenFix_v4 = true
		profile.unitFrames.shieldColor = { 0, 1, 0.239, 0.5 }
	end

	if not (profile.general and profile.general._fontShadowMigrated) then
		profile.general = profile.general or {}
		profile.general._fontShadowMigrated = true
		profile.general.fontShadowEnabled = nil
		profile.general.fontShadowX       = nil
		profile.general.fontShadowY       = nil
		profile.general.fontShadowAlpha   = nil
	end

	if profile.unitFrames and not (profile.general and profile.general._dispelHighlightBluForced) then
		profile.general = profile.general or {}
		profile.general._dispelHighlightBluForced = true
		local deadKeys = { 'debuffHighlight', 'debuffHighlightAlert', 'debuffHighlightTint', 'debuffHighlightTintAlpha', 'debuffHighlightStripes', 'debuffHighlightStripeTexture', 'debuffHighlightStripeBlend', 'debuffHighlightStripeAlpha' }
		for _, unitKey in ipairs({ 'player', 'target', 'targettarget', 'focus', 'focustarget', 'pet', 'boss', 'arena', 'party' }) do
			local unitTable = profile.unitFrames[unitKey]
			if type(unitTable) == 'table' then
				unitTable.debuffHighlightBorder = true
				unitTable.debuffHighlightBar = false
				unitTable.debuffHighlightBadge = true
				unitTable.debuffHighlightClassFilter = true
				for _, deadKey in ipairs(deadKeys) do unitTable[deadKey] = nil end
			end
		end
	end

	if profile.unitFrames then
		local unitFrames = profile.unitFrames
		local mode = unitFrames.cdmSyncMode or (unitFrames.alignWithCDM and 'full') or 'off'
		if mode == 'full' or mode == 'positionOnly' then
			local shouldMatchHeight = mode == 'full'

			local UNIT_OF = { BUI_PlayerFrame = 'player', BUI_TargetFrame = 'target', BUI_FocusFrame = 'focus',
			                  BUI_PetFrame = 'pet', BUI_TargetTargetFrame = 'targettarget', BUI_FocusTargetFrame = 'focustarget' }
			local SELF_NAME = { player = 'BUI_PlayerFrame', target = 'BUI_TargetFrame', pet = 'BUI_PetFrame' }
			local function savedReaches(fromName, targetName)
				local name, depth = fromName, 0
				while name and depth < 16 do
					if name == targetName then return true end
					local unit = UNIT_OF[name]
					if not unit then return false end
					name = unitFrames[unit] and unitFrames[unit].anchorFrame
					depth = depth + 1
				end
				return false
			end
			local function migrate(unit, anchorFrame, point, matchWidth, matchHeight)
				unitFrames[unit] = unitFrames[unit] or {}
				if unitFrames[unit].anchorFrame and unitFrames[unit].anchorFrame ~= '' then return end
				if SELF_NAME[unit] and savedReaches(anchorFrame, SELF_NAME[unit]) then return end
				unitFrames[unit].anchorFrame = anchorFrame
				unitFrames[unit].anchorPoint = point
				unitFrames[unit].anchorOffsetX, unitFrames[unit].anchorOffsetY = 0, 0
				unitFrames[unit].matchAnchorWidth, unitFrames[unit].matchAnchorHeight = matchWidth, matchHeight
			end
			migrate('player', 'BUI_EssentialCooldownViewer', 'LEFT', false, shouldMatchHeight)
			migrate('target', 'BUI_EssentialCooldownViewer', 'RIGHT', false, shouldMatchHeight)
			if not unitFrames.excludePetFromSync then
				migrate('pet', 'BUI_PlayerFrame', 'LEFT', false, false)
			end
		end
		unitFrames.cdmSyncMode = nil
		unitFrames.cdmSyncSpacing = nil
		unitFrames.alignWithCDM = nil
		unitFrames.syncPositions = nil
		unitFrames._cdmPosCache = nil
		if profile.general then profile.general._cdmSyncToAnchorMigrated = nil end
	end

	if profile.unitFrames and not (profile.general and profile.general._syncPlayerTargetOptIn) then
		profile.general = profile.general or {}
		profile.general._syncPlayerTargetOptIn = true
		if profile.unitFrames.syncPlayerTarget then
			profile.unitFrames.syncPlayerTarget = false
		end
	end

	if profile.unitFrames and not (profile.general and profile.general._ufMatchWidthReset) then
		profile.general = profile.general or {}
		profile.general._ufMatchWidthReset = true
		for _, unit in ipairs({ 'player', 'target', 'targettarget', 'focus', 'focustarget', 'pet', 'boss', 'arena', 'party' }) do
			local unitTable = profile.unitFrames[unit]
			if type(unitTable) == 'table' and unitTable.matchAnchorWidth then unitTable.matchAnchorWidth = false end
		end
	end

	if not (profile.general and profile.general._cursorMasterUnified) then
		profile.general = profile.general or {}
		profile.general._cursorMasterUnified = true
		if profile.cursor and profile.cursor.enabled == false then
			profile.modules = profile.modules or {}
			profile.modules.cursor = false
		end
	end

	if not (profile.general and profile.general._skinMasterRetired) then
		profile.general = profile.general or {}
		profile.general._skinMasterRetired = true
		local masterOn = profile.interface and profile.interface.skinBlizzardFrames == true
		local hasSkinningTable = type(profile.skinning) == 'table' and next(profile.skinning) ~= nil
		if not masterOn and not hasSkinningTable and BUI.Skinning and BUI.Skinning.GetSkinRegistry then
			profile.skinning = profile.skinning or {}
			local _, order = BUI.Skinning.GetSkinRegistry()
			for _, id in ipairs(order) do
				profile.skinning[id] = false
			end
		end
	end

	if not (profile.general and profile.general._powerBarAnyAnchorMigrated) then
		profile.general = profile.general or {}
		profile.general._powerBarAnyAnchorMigrated = true
		local POWER_TAGS = { BUI_PowerBar = true, BUI_SecondaryPower = true }
		local function migrateAnchors(targetTable, depth)
			if type(targetTable) ~= 'table' or depth > 12 then return end
			for key, value in pairs(targetTable) do
				if (key == 'anchorFrame' or key == 'textAnchorFrame') and POWER_TAGS[value] then
					targetTable[key] = 'BUI_PowerBarAny'
				elseif type(value) == 'table' then
					migrateAnchors(value, depth + 1)
				end
			end
		end
		for key, value in pairs(profile) do
			if key ~= 'powerBar' and key ~= 'secondaryPower' and type(value) == 'table' then
				migrateAnchors(value, 1)
			end
		end
	end

	local interface = profile.interface
	if interface then
		if type(interface.minimapIconPos) == 'table' then
			local scales = type(interface.minimapIconScale) == 'table' and interface.minimapIconScale or {}
			local defaultScales = { queue = 0.8, difficulty = 0.9, mail = 0.8, crafting = 0.8, missions = 0.8 }
			for _, shapePositions in pairs(interface.minimapIconPos) do
				if type(shapePositions) == 'table' then
					for key, iconPosition in pairs(shapePositions) do
						if type(iconPosition) == 'table' and iconPosition.v == 2 then
							local scale = tonumber(scales[key]) or defaultScales[key] or 0.8
							if scale > 0 and type(iconPosition[2]) == 'number' and type(iconPosition[3]) == 'number' then
								iconPosition[2] = iconPosition[2] / scale
								iconPosition[3] = iconPosition[3] / scale
							end
							iconPosition.v = nil
						end
					end
				end
			end
		end
		interface.minimapDockOrder = nil
		interface.minimapIconFree = nil
		interface.minimapShape = nil
		if type(interface.minimapIconPos) == 'table' then
			interface.minimapIconPos.circle = nil
		end
	end

	if not (profile.general and profile.general._rangeTagSeeded) then
		profile.general = profile.general or {}
		profile.general._rangeTagSeeded = true
		profile.unitFrames = profile.unitFrames or {}
		local targetSettings = profile.unitFrames.target
		if type(targetSettings) ~= 'table' then targetSettings = {}; profile.unitFrames.target = targetSettings end
		targetSettings.customTags = targetSettings.customTags or {}
		local exists = false
		for _, entry in ipairs(targetSettings.customTags) do
			if type(entry) == 'table' and type(entry.tag) == 'string' and entry.tag:find('[range]', 1, true) then
				exists = true
				break
			end
		end
		if not exists then
			targetSettings.customTags[#targetSettings.customTags + 1] = {
				name = 'Range', tag = '[range]', enabled = true,
				point = 'TOPRIGHT', x = 0, y = 16, fontSize = 12,
				color = { 1, 1, 1, 1 }, drawLayer = 'OVERLAY', drawSubLevel = 0,
			}
		end
	end

	if not (profile.general and profile.general._dispelColorsShared) then
		profile.general = profile.general or {}
		profile.general._dispelColorsShared = true
		local legacyKeys = {
			dispelColorMagic   = 'dispel_magic',
			dispelColorCurse   = 'dispel_curse',
			dispelColorDisease = 'dispel_disease',
			dispelColorPoison  = 'dispel_poison',
			dispelColorBleed   = 'dispel_bleed',
		}
		local unitFrames = profile.unitFrames
		if type(unitFrames) == 'table' then
			profile.colors = profile.colors or {}
			for legacyKey, sharedKey in pairs(legacyKeys) do
				local legacyColor = unitFrames[legacyKey]
				if type(legacyColor) == 'table' and not profile.colors[sharedKey] then
					profile.colors[sharedKey] = {
						r = legacyColor[1], g = legacyColor[2], b = legacyColor[3], a = legacyColor[4] or 1,
					}
				end
				unitFrames[legacyKey] = nil
			end
		end
	end

	if not (profile.general and profile.general._smoothBarsShared) then
		profile.general = profile.general or {}
		profile.general._smoothBarsShared = true
		local unitFrames, groupFrames = profile.unitFrames, profile.groupFrames
		if (type(unitFrames) == 'table' and unitFrames.smoothBars == false)
			or (type(groupFrames) == 'table' and groupFrames.smoothBars == false) then
			profile.general.smoothBars = false
		end
		if type(unitFrames) == 'table' then unitFrames.smoothBars = nil end
		if type(groupFrames) == 'table' then groupFrames.smoothBars = nil end
	end

	profile.killCommandSend = nil

	profile.general = profile.general or {}
	if not profile.general._actionBarFadePerBarMigrated then
		profile.general._actionBarFadePerBarMigrated = true
		local actionBars = profile.actionBars
		if actionBars and (actionBars.fadeAnimated ~= nil or actionBars.fadeDuration ~= nil) then
			local function MigrateBar(barSettings)
				if type(barSettings) ~= 'table' then return end
				if actionBars.fadeAnimated ~= nil and barSettings.fadeAnimated == nil then barSettings.fadeAnimated = actionBars.fadeAnimated end
				if actionBars.fadeDuration ~= nil and barSettings.fadeDuration == nil then barSettings.fadeDuration = actionBars.fadeDuration end
			end
			if type(actionBars.bars) == 'table' then
				for _, barSettings in pairs(actionBars.bars) do MigrateBar(barSettings) end
			end
			for _, settingsKey in ipairs({ 'petBar', 'stanceBar', 'vehicleBar', 'microBar', 'bagBar', 'extraBar' }) do
				MigrateBar(actionBars[settingsKey])
			end
			actionBars.fadeAnimated = nil
			actionBars.fadeDuration = nil
		end
	end

	if not profile.general._ldbDatatextsRemoved then
		profile.general._ldbDatatextsRemoved = true
		local function StripLDB(config)
			if type(config) ~= 'table' then return end
			for key in pairs(config) do
				if type(key) == 'string' and key:sub(1, 7) == 'showLDB' then config[key] = nil end
			end
			if type(config.order) == 'table' then
				local kept = {}
				for orderIndex = 1, #config.order do
					local id = config.order[orderIndex]
					if not (type(id) == 'string' and id:sub(1, 4) == 'ldb:') then kept[#kept + 1] = id end
				end
				config.order = kept
			end
		end
		if type(profile.datatextBars) == 'table' then
			for _, barConfig in pairs(profile.datatextBars) do StripLDB(barConfig) end
		end
		StripLDB(profile.datatextMinimap)
	end

	profile.general._buiMigrationVersion = PROFILE_MIGRATION_VERSION
end

function BUI.RunMigrations()
	if not BUI.db.global._layoutCenteredMigrated then
		BUI.db.global._layoutCenteredMigrated = true
		BUI.db.global.layoutStyle = 'centered'
	end

	for _, profile in pairs(BUI.db.profiles) do
		BUI.MigrateProfile(profile)
	end
end
