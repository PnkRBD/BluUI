local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Util.ImportChooser')
local BUILib = BluUI.BUILibClient
local Pixel = BUI.Pixel
local Controls = BUILib.Controls
local Layout = BUILib.Layout
local Modals = BUILib.Modals
local Widget = BUILib.Widget
local Theme
local pairs, type, ipairs = pairs, type, ipairs

local GROUPS = {
	{ header = 'Core', sections = {
		{ key = 'general',     name = 'Theme & Fonts' },
		{ key = 'modules',     name = 'Module Toggles' },
		{ key = 'interface',   name = 'Interface & Minimap' },
		{ key = 'skinning',    name = 'Skinning' },
		{ key = 'colors',      name = 'Colors' },
	}},
	{ header = 'Frames', sections = {
		{ key = 'unitFrames',  name = 'Unit Frames' },
		{ key = 'castBars',    name = 'Cast Bars' },
		{ key = 'actionBars',  name = 'Action Bars' },
	}},
	{ header = 'Cooldowns & Power', sections = {
		{ key = 'cdm',             name = 'Cooldown Manager' },
		{ key = 'powerBar',        name = 'Primary Power' },
		{ key = 'secondaryPower',  name = 'Secondary Power' },
	}},
	{ header = 'Auras & Tracking', sections = {
		{ key = 'customBars',      name = 'Custom Bars' },
		{ key = 'auras',           name = 'Warning Auras' },
		{ key = 'auraFilters',     name = 'Aura Filters' },
		{ key = 'cdAnnouncer',     name = 'CD Announcer' },
		{ key = 'bloodlust',       name = 'Bloodlust Tracker' },
		{ key = 'gatewayAlert',    name = 'Gateway Alert' },
	}},
	{ header = 'HUD', sections = {
		{ key = 'datatext',     name = 'Datatext (Legacy)' },
		{ key = 'datatextBars', name = 'Datatext Bars' },
		{ key = 'cursor',       name = 'Cursor' },
		{ key = 'crosshair',    name = 'Crosshair' },
	}},
	{ header = 'Automation & Social', sections = {
		{ key = 'social',        name = 'Social' },
		{ key = 'automation',    name = 'Automation' },
		{ key = 'combatLogging', name = 'Combat Logging' },
	}},
	{ header = 'Combat', sections = {
		{ key = 'combatMessage',  name = 'Combat Message' },
		{ key = 'combatTimer',    name = 'Combat Timer' },
	}},
	{ header = 'Buff Tracking', sections = {
		{ key = 'hunterTip',                  name = 'Hunter Tip' },
		{ key = 'hunterPreciseShots',         name = 'Hunter Precise Shots' },
		{ key = 'hunterLockAndLoad',          name = 'Hunter Lock and Load' },
		{ key = 'hunterBulletstorm',          name = 'Hunter Bulletstorm' },
		{ key = 'hunterKillCommand',          name = 'Hunter Kill Command' },
		{ key = 'hunterCobraFang',            name = 'Hunter Cobra Fang' },
		{ key = 'hunterRaptorSwipe',          name = 'Hunter Raptor Swipe' },
		{ key = 'hunterRaptorPrompt',         name = 'Hunter Raptor Prompt' },
		{ key = 'packLeader',                 name = 'Pack Leader' },
		{ key = 'smartMisdirect',             name = 'Smart Misdirection' },
		{ key = 'misdirectAlert',             name = 'Misdirect Alert' },
		{ key = 'petAlert',                   name = 'Pet Alert' },
		{ key = 'killCommandOverlay',         name = 'Pack Leader Overlay on KC' },
		{ key = 'monkVivaciousVivification',  name = 'Monk Vivacious Vivification' },
	}},
	{ header = 'Layout', sections = {
		{ key = 'framePositions',  name = 'Frame Positions' },
		{ key = 'uiScale',        name = 'UI Scale' },
	}},
}

local SECTIONS = {}
for _, group in ipairs(GROUPS) do
	for _, section in ipairs(group.sections) do
		SECTIONS[#SECTIONS + 1] = section
	end
end

local function TablesEqual(left, right)
	if type(left) ~= type(right) then return false end
	if type(left) ~= 'table' then return left == right end
	for key, value in pairs(left) do
		if not TablesEqual(value, right[key]) then return false end
	end
	for key in pairs(right) do
		if left[key] == nil then return false end
	end
	return true
end

local function Normalize(data)
	if type(data) ~= 'table' then return data end
	local normalized = {}
	for key, value in pairs(data) do
		if type(key) ~= 'string' or not key:match('^_') then
			normalized[key] = Normalize(value)
		end
	end
	return normalized
end

local function WithDefaults(section, sectionKey)
	local DeepCopy = BUI.Tools.DeepCopy
	local MergeDefaults = BUI.ExportImport.MergeDefaults
	local defaultSection = BUI.Defaults.profile[sectionKey]
	local copy = DeepCopy(section or {})
	if defaultSection then MergeDefaults(copy, defaultSection) end
	return copy
end

local function ChangedKeys(left, right)
	local keys = {}
	left  = left  or {}
	right = right or {}
	for key in pairs(left) do
		if not TablesEqual(left[key], right[key]) then keys[#keys + 1] = tostring(key) end
	end
	for key in pairs(right) do
		if left[key] == nil then keys[#keys + 1] = tostring(key) end
	end
	table.sort(keys)
	return keys
end

local SECTION_COMPANIONS = {
	powerBar = { 'powerBar2', 'powerScope', 'powerVariants' },
	secondaryPower = { 'powerScope', 'powerVariants' },
	datatextBars = { 'datatextBarsInit', 'datatextEnabled', 'datatextMinimap' },
	datatext = { 'datatextEnabled', 'datatextMinimap', 'datatextHideHoversInCombat', 'datatextRosterTooltips' },
	social = { 'socialShowBattleTag', 'socialAdvancedView', 'socialCollapsedSections', 'datatextSortState' },
}

local function ChangedCompanions(currentDB, importData, sectionKey)
	local changed = {}
	local companions = SECTION_COMPANIONS[sectionKey]
	if not companions then return changed end
	for _, key in ipairs(companions) do
		local imported = importData[key]
		if imported ~= nil then
			local current = currentDB[key]
			local left = type(current) == 'table' and Normalize(WithDefaults(current, key)) or current
			local right = type(imported) == 'table' and Normalize(WithDefaults(imported, key)) or imported
			if not TablesEqual(left, right) then changed[#changed + 1] = key end
		end
	end
	return changed
end

local function ComputeDiff(currentDB, importData)
	local result = {}
	local details = {}
	for _, section in ipairs(SECTIONS) do
		local sectionKey = section.key
		local imported = importData[sectionKey]
		local companionChanges = ChangedCompanions(currentDB, importData, sectionKey)
		if imported ~= nil or #companionChanges > 0 then
			local changedList
			if imported ~= nil then
				local normalizedCurrent  = Normalize(WithDefaults(currentDB[sectionKey], sectionKey))
				local normalizedImported = Normalize(WithDefaults(imported, sectionKey))
				if not TablesEqual(normalizedCurrent, normalizedImported) then
					changedList = ChangedKeys(normalizedCurrent, normalizedImported)
				end
			end
			if not changedList and #companionChanges == 0 then
				result[sectionKey] = 'unchanged'
			else
				result[sectionKey] = 'changed'
				changedList = changedList or {}
				for _, key in ipairs(companionChanges) do changedList[#changedList + 1] = key end
				details[sectionKey] = changedList
			end
		end
	end
	return result, details
end

local function ShowChooser(importData, currentDB, onConfirm, onCancel)
	if not Theme then Theme = BUILib.Theme end

	local diff, details = ComputeDiff(currentDB, importData)

	local visibleGroups = {}
	local allCheckboxes = {}
	local hasChanges = false
	for _, group in ipairs(GROUPS) do
		local visibleSections = {}
		for _, section in ipairs(group.sections) do
			if diff[section.key] then
				visibleSections[#visibleSections + 1] = section
				if diff[section.key] ~= 'unchanged' then hasChanges = true end
			end
		end
		if #visibleSections > 0 then
			visibleGroups[#visibleGroups + 1] = { header = group.header, sections = visibleSections }
		end
	end

	if #visibleGroups == 0 then
		local overlay = Modals.Message({
			title = 'Nothing to Import',
			message = 'The import string contains no recognized settings sections.',
			fullscreen = true,
		})
		if overlay then overlay:SetFrameLevel(300) end
		if onCancel then onCancel() end
		return
	end

	if not hasChanges then
		local overlay = Modals.Message({
			title = 'Already Up to Date',
			message = 'Your settings already match the imported profile. Nothing to update.',
			fullscreen = true,
		})
		if overlay then overlay:SetFrameLevel(300) end
		if onCancel then onCancel() end
		return
	end

	local content = Modals.Settings({
		title = 'Update Manager',
		width = 580,
		height = 500,
		fullscreen = true,
		onClose = function() if onCancel then onCancel() end end,
		buttons = {
			{ text = 'Import Selected', color = Modals.BTN_CONFIRM, width = 150,
				onClick = function(close)
					local selected = {}
					for _, checkbox in ipairs(allCheckboxes) do
						if checkbox.widget:GetValue() then
							selected[#selected + 1] = checkbox.key
						end
					end
					close()
					if onConfirm then onConfirm(selected) end
				end,
			},
			{ text = 'Cancel', color = Modals.BTN_NEUTRAL, width = 100,
				onClick = function(close)
					close()
					if onCancel then onCancel() end
				end,
			},
		},
	})

	local accentRed, accentGreen, accentBlue = Theme.GetAccent()
	local contentWidth = content.contentWidth or content.width or 520

	local warnWrap = CreateFrame('Frame', nil, content.child)
	warnWrap:SetWidth(contentWidth)
	local warnText = warnWrap:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(warnText, 10, BUILib.Font, '')
	warnText:SetPoint('TOPLEFT')
	warnText:SetWidth(contentWidth)
	warnText:SetJustifyH('LEFT')
	warnText:SetText('Checked sections overwrite your current settings.')
	warnText:SetTextColor(0.7, 0.7, 0.7, 1)
	warnWrap:SetHeight(warnText:GetStringHeight() + 2)
	Layout.Add(content, warnWrap, 8)

	local selectionRow = CreateFrame('Frame', nil, content.child)
	selectionRow:SetSize(contentWidth, Pixel.Scale(18))
	Layout.Add(content, selectionRow, 4)

	local function MakeLink(text, xOffset, onClick)
		local button = CreateFrame('Button', nil, selectionRow)
		button:SetHeight(Pixel.Scale(18))
		local label = button:CreateFontString(nil, 'OVERLAY')
		Pixel.ApplyFont(label, 11, BUILib.Font, '')
		label:SetText(text)
		label:SetTextColor(accentRed, accentGreen, accentBlue, 1)
		label:SetPoint('LEFT')
		button:SetWidth(label:GetStringWidth() + 4)
		button:SetPoint('LEFT', selectionRow, 'LEFT', xOffset, 0)
		SetScript(button, 'OnEnter', function() label:SetTextColor(1, 1, 1, 1) end)
		SetScript(button, 'OnLeave', function() label:SetTextColor(accentRed, accentGreen, accentBlue, 1) end)
		SetScript(button, 'OnClick', onClick)
		return button
	end

	local selectAll = MakeLink('Select All', 0, function()
		for _, checkbox in ipairs(allCheckboxes) do checkbox.widget:SetValue(true) end
	end)
	MakeLink('Deselect All', selectAll:GetWidth() + 12, function()
		for _, checkbox in ipairs(allCheckboxes) do checkbox.widget:SetValue(false) end
	end)

	for groupIndex, group in ipairs(visibleGroups) do
		local headerFrame = CreateFrame('Frame', nil, content.child)
		headerFrame:SetSize(contentWidth, Pixel.Scale(16))
		local headerText = headerFrame:CreateFontString(nil, 'OVERLAY')
		Pixel.ApplyFont(headerText, 11, BUILib.Font, 'OUTLINE')
		headerText:SetPoint('LEFT', Pixel.Scale(2), 0)
		headerText:SetText(group.header)
		headerText:SetTextColor(accentRed, accentGreen, accentBlue, 0.9)
		local line = headerFrame:CreateTexture(nil, 'ARTWORK')
		line:SetHeight(Pixel.PixelSize(1))
		line:SetPoint('LEFT', headerText, 'RIGHT', Pixel.Scale(8), 0)
		line:SetPoint('RIGHT', headerFrame, 'RIGHT', Pixel.Scale(-2), 0)
		line:SetTexture(Widget.WHITE)
		line:SetVertexColor(accentRed, accentGreen, accentBlue, 0.15)
		Layout.Add(content, headerFrame, groupIndex == 1 and 6 or 14)

		for _, section in ipairs(group.sections) do
			local status = diff[section.key]
			local changed = status ~= 'unchanged'
			local checkbox = Controls.StampCheckbox(content.child, section.name, changed, nil)
			allCheckboxes[#allCheckboxes + 1] = { widget = checkbox, key = section.key }
			Layout.Add(content, checkbox, 5)

			local frame = Widget.Unwrap(checkbox)
			frame:SetWidth(contentWidth)
			if changed then
				local changedKeys = details[section.key]
				local badge = frame:CreateFontString(nil, 'OVERLAY')
				Pixel.ApplyFont(badge, 10, BUILib.Font, 'OUTLINE')
				badge:SetPoint('RIGHT', frame, 'RIGHT', Pixel.Scale(-4), 0)
				local count = changedKeys and #changedKeys or 0
				badge:SetText(count > 0 and (count .. ' changed') or 'UPDATED')
				badge:SetTextColor(1, 0.8, 0.2, 1)

				if changedKeys and #changedKeys > 0 then
					SetScript(frame, 'OnEnter', function(self)
						GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
						GameTooltip:AddLine(section.name .. ' changes', 1, 0.8, 0.2)
						for _, changedKey in ipairs(changedKeys) do
							GameTooltip:AddLine('  ' .. changedKey, 0.8, 0.8, 0.8)
						end
						GameTooltip:Show()
					end)
					SetScript(frame, 'OnLeave', GameTooltip_Hide)
				end
			else
				local badge = frame:CreateFontString(nil, 'OVERLAY')
				Pixel.ApplyFont(badge, 10, BUILib.Font, 'OUTLINE')
				badge:SetPoint('RIGHT', frame, 'RIGHT', Pixel.Scale(-4), 0)
				badge:SetText('No Changes')
				badge:SetTextColor(0.4, 0.4, 0.4, 1)
			end
		end
	end

	content:Refresh()

	local overlay = content.overlay
	overlay:SetFrameLevel(300)
	content.dialog:SetFrameLevel(310)

	return overlay
end

BUI.ImportChooser = {
	ShowChooser = ShowChooser,
}
