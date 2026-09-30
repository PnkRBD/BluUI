local BUI = BluUI
local BUILib = BluUI.BUILibClient
local Layout, Modals = BUILib.Layout, BUILib.Modals
local Pixel = BUI.Pixel
local AuraLists = BUI.AuraLists

local PAGE_WIDTH = 960
local PREVIEW_HEIGHT = 150
local MENU_WIDTH = 150
local TAG_WIDTH = 300
local COPY_WIDTH = 170
local NAME_WIDTH = 200
local TEXT_RANGE = 50
local AURA_RANGE = 500
local BADGE_RANGE_X = 600
local BADGE_RANGE_Y = 400
local ICON_RANGE = 50
local TAG_RANGE = 200
local POSITION_RANGE_X = 4000
local POSITION_RANGE_Y = 3000
local MOCK_GAP = 18
local MOCK_PAIR_WIDTH = 340
local MOCK_WIDTH = 620
local MOCK_BOSS_HEIGHT = 72
local WHITE = 'Interface\\Buttons\\WHITE8x8'
local RAID_ICON = 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_8'

local UNITS = {
	{ key = 'player', label = 'Player', title = 'Player frame', description = 'Position, texts, indicators and auras for your own frame.' },
	{ key = 'target', label = 'Target', title = 'Target frame', description = 'Layout and auras for your current target.' },
	{ key = 'targettarget', label = 'Target of target', title = 'Target of target', description = 'Compact frame showing what your target is targeting.' },
	{ key = 'focus', label = 'Focus', title = 'Focus frame', description = 'Layout and auras for your focus.' },
	{ key = 'pet', label = 'Pet', title = 'Pet frame', description = 'Layout and colors for your pet.' },
	{ key = 'boss', label = 'Boss', title = 'Boss frames', description = 'Up to five stacked frames for boss encounters.' },
}
local UNIT_BY_KEY = {}
for _, unit in ipairs(UNITS) do UNIT_BY_KEY[unit.key] = unit end
local AURA_UNITS = { player = true, target = true, focus = true, targettarget = true, boss = true }
local ANCHORABLE = { player = true, target = true, focus = true, pet = true, targettarget = true }
local TAB_IDS = { 'appearance', 'tags', 'tags', 'player', 'target', 'targettarget', 'focus', 'pet', 'boss', 'filters' }
local TAB_INDEX = { appearance = 1, tags = 2, player = 4, target = 5, targettarget = 6, focus = 7, pet = 8, boss = 9, filters = 10 }
local TAG_UNITS = {
	{ value = 'player', text = 'Player' },
	{ value = 'target', text = 'Target' },
	{ value = 'targettarget', text = 'Target of target' },
	{ value = 'focus', text = 'Focus' },
	{ value = 'pet', text = 'Pet' },
	{ value = 'boss', text = 'Boss' },
}
local LAYERS = {
	{ value = 'BACKGROUND', text = 'Background' },
	{ value = 'BORDER', text = 'Border' },
	{ value = 'ARTWORK', text = 'Artwork' },
	{ value = 'OVERLAY', text = 'Overlay' },
	{ value = 'HIGHLIGHT', text = 'Highlight' },
}
local ABSORB_TEXTURES = {
	{ value = 'Solid', text = 'Solid' },
	{ value = 'Stripes', text = 'Diagonal stripes' },
}
local ABSORB_DIRECTIONS = {
	{ value = 'right', text = 'Fill the empty area' },
	{ value = 'left', text = 'Reverse into health' },
	{ value = 'edge', text = 'From the bar edge' },
}
local DISPEL_MODES = {
	{ value = 'off', text = 'Off' },
	{ value = 'border', text = 'Frame border' },
	{ value = 'bar', text = 'Health bar' },
}
local DISPEL_SOURCES = {
	{ value = 'mine', text = 'Dispellable by me' },
	{ value = 'all', text = 'All dispel types' },
}
local DISPEL_TYPES = { 'Bleed', 'Poison', 'Disease', 'Curse', 'Magic' }
local GROWTHS_X = { { value = 'LEFT', text = 'Left' }, { value = 'RIGHT', text = 'Right' } }
local GROWTHS_Y = { { value = 'UP', text = 'Up' }, { value = 'DOWN', text = 'Down' } }
local STACKINGS = { { value = 'DOWN', text = 'Down, boss one on top' }, { value = 'UP', text = 'Up, boss one at the bottom' } }
local STACK_POINTS = {}
for _, point in ipairs({ 'TOPLEFT', 'TOP', 'TOPRIGHT', 'LEFT', 'CENTER', 'RIGHT', 'BOTTOMLEFT', 'BOTTOM', 'BOTTOMRIGHT' }) do
	STACK_POINTS[#STACK_POINTS + 1] = { value = point, text = point:sub(1, 1) .. point:sub(2):lower():gsub('left', ' left'):gsub('right', ' right') }
end
local TAGS = {
	{ group = 'Names', tag = '[name]', description = 'Full name', example = 'Bluetempest' },
	{ group = 'Names', tag = '[name:short]', description = 'Ten letters', example = 'Bluetempes' },
	{ group = 'Names', tag = '[name:short5]', description = 'Five letters', example = 'Bluet' },
	{ group = 'Names', tag = '[name:target>]', description = 'Name then target', example = 'Blue.. > Ragn..' },
	{ group = 'Names', tag = '[name5:target5>]', description = 'Both cut to five letters', example = 'Bluet > Ragni' },
	{ group = 'Names', tag = '[name8:target>]', description = 'Eight letters then the full target', example = 'Bluetemp > Ragnaros' },
	{ group = 'Health', tag = '[hp]', description = 'Health', example = '75000' },
	{ group = 'Health', tag = '[hp:short]', description = 'Abbreviated', example = '75K' },
	{ group = 'Health', tag = '[maxhp]', description = 'Maximum', example = '100000' },
	{ group = 'Health', tag = '[maxhp:short]', description = 'Maximum abbreviated', example = '100K' },
	{ group = 'Health', tag = '[perhp]', description = 'Percent', example = '75' },
	{ group = 'Power', tag = '[pp]', description = 'Power', example = '9000' },
	{ group = 'Power', tag = '[pp:short]', description = 'Abbreviated', example = '9K' },
	{ group = 'Power', tag = '[maxpp]', description = 'Maximum', example = '10000' },
	{ group = 'Power', tag = '[maxpp:short]', description = 'Maximum abbreviated', example = '10K' },
	{ group = 'Power', tag = '[perpp]', description = 'Percent', example = '60' },
	{ group = 'Power', tag = '[powertype]', description = 'Type', example = 'Mana' },
	{ group = 'Mana', tag = '[mana]', description = 'Mana', example = '8000' },
	{ group = 'Mana', tag = '[mana:short]', description = 'Abbreviated', example = '8K' },
	{ group = 'Mana', tag = '[maxmana]', description = 'Maximum', example = '10000' },
	{ group = 'Mana', tag = '[permana]', description = 'Percent', example = '80' },
	{ group = 'Player', tag = '[class]', description = 'Class in capitals', example = 'HUNTER' },
	{ group = 'Player', tag = '[classname]', description = 'Class name', example = 'Hunter' },
	{ group = 'Player', tag = '[race]', description = 'Race', example = 'Night Elf' },
	{ group = 'Player', tag = '[level]', description = 'Level', example = '80' },
	{ group = 'Player', tag = '[spec]', description = 'Specialization', example = 'Marksmanship' },
	{ group = 'Player', tag = '[itemlevel]', description = 'Item level', example = '639' },
	{ group = 'Player', tag = '[title]', description = 'Title', example = 'the Exalted' },
	{ group = 'Player', tag = '[role]', description = 'Role icon', example = 'icon' },
	{ group = 'Player', tag = '[role:text]', description = 'Role text', example = 'DPS' },
	{ group = 'Creature', tag = '[creature]', description = 'Pet family or creature type', example = 'Cat' },
	{ group = 'Creature', tag = '[creaturefamily]', description = 'Pet family', example = 'Cat' },
	{ group = 'Creature', tag = '[creaturetype]', description = 'Creature type', example = 'Beast' },
	{ group = 'Creature', tag = '[classification]', description = 'Classification', example = 'Boss' },
	{ group = 'Creature', tag = '[difficulty]', description = 'Instance difficulty', example = 'Mythic' },
	{ group = 'Status', tag = '[status]', description = 'Dead, ghost or offline', example = 'Dead' },
	{ group = 'Status', tag = '[dead]', description = 'Dead', example = 'Dead' },
	{ group = 'Status', tag = '[offline]', description = 'Disconnected', example = 'Offline' },
	{ group = 'Status', tag = '[afk]', description = 'Away', example = 'AFK' },
	{ group = 'Status', tag = '[combat]', description = 'In combat', example = '!' },
	{ group = 'Status', tag = '[resting]', description = 'Resting', example = 'zzz' },
	{ group = 'Live', tag = '[combattime]', description = 'Combat timer', example = '01:23' },
	{ group = 'Live', tag = '[threat]', description = 'Threat on the target', example = '42%' },
	{ group = 'Live', tag = '[range]', description = 'Distance to the unit', example = '25-30' },
	{ group = 'Other', tag = '[server]', description = 'Realm', example = 'Kazzak' },
	{ group = 'Other', tag = '[absorbs]', description = 'Absorb shield', example = '5K' },
	{ group = 'Other', tag = '[hpabsorb]', description = 'Health plus absorb', example = '492000' },
	{ group = 'Other', tag = '[hpabsorb:short]', description = 'Health plus absorb abbreviated', example = '492K' },
	{ group = 'Other', tag = '[target]', description = 'Target name', example = 'Ragnaros' },
	{ group = 'Other', tag = '[group]', description = 'Raid group', example = '3' },
}
local TAG_GROUPS = { 'Names', 'Health', 'Power', 'Mana', 'Player', 'Creature', 'Status', 'Live', 'Other' }
local MOCK_DEBUFF_ICONS = {
	'Interface\\Icons\\Spell_Shadow_ShadowWordPain', 'Interface\\Icons\\Spell_Fire_Immolation', 'Interface\\Icons\\Ability_Rogue_Rupture',
	'Interface\\Icons\\Spell_Shadow_CurseOfSargeras', 'Interface\\Icons\\Spell_Frost_FrostNova', 'Interface\\Icons\\Ability_Warrior_Sunder',
	'Interface\\Icons\\Spell_Shadow_AbominationExplosion', 'Interface\\Icons\\Spell_Nature_CorrosiveBreath',
}
local MOCK_BUFF_ICONS = {
	'Interface\\Icons\\Spell_Nature_Rejuvenation', 'Interface\\Icons\\Spell_Holy_PowerWordShield', 'Interface\\Icons\\Spell_Holy_Renew',
	'Interface\\Icons\\Ability_Warrior_BattleShout', 'Interface\\Icons\\Spell_Nature_LightningShield', 'Interface\\Icons\\Spell_Holy_DevotionAura',
	'Interface\\Icons\\Spell_Nature_ProtectionformNature', 'Interface\\Icons\\INV_Potion_167',
}
local MOCK_DISPEL_COLORS = { { 0.2, 0.6, 1.0 }, { 0.6, 0.0, 1.0 }, { 0.0, 0.6, 0.0 }, { 0.8, 0.0, 0.0 } }
local DEFAULT_TAGS = { name = '[name]', health = '[hp:short] • [perhp]%', power = '[perpp]%' }

local selected = 'appearance'
local tagUnit = 'player'
local preview
local fonts, textures

local function Window()
	return BUI.PageEngine.window
end

local function Repaint()
	Window():Repaint()
end

local function Settings()
	return BUI.GetDB().unitFrames
end

local function UnitFrames()
	return BUI.UnitFrames
end

local function RefreshPreview()
	if preview then preview:Update() end
end

local function RebuildPage()
	BUILib.Defer(function() BUI.PageEngine.RefreshCurrentPage() end)
end

local function RebuildPane(page)
	BUILib.Defer(function() page:RebuildCurrent() end)
end

local function ResolveShow(specific, fallback, defaultOn)
	if specific ~= nil then return specific == true end
	if defaultOn == false then return fallback == true end
	return fallback ~= false
end

local function Media(kind, key, fallback)
	if key and key ~= '' and key ~= BUI.C.GLOBAL_OPTION then
		local path = LibStub('LibSharedMedia-3.0'):Fetch(kind, key, true)
		if path then return path end
	end
	return fallback
end

local function Option(db, label, key, extra)
	local option = { label = label, get = function() return db[key] end, set = function(value) db[key] = value end }
	for name, value in pairs(extra or {}) do option[name] = value end
	return option
end

local function Toggle(db, label, key)
	return { label = label, get = function() return db[key] == true end, set = function(value) db[key] = value end }
end

local function OnUnlessOff(db, label, key)
	return { label = label, get = function() return db[key] ~= false end, set = function(value) db[key] = value end }
end

local function Color(db, label, key)
	return {
		kind = 'swatch', label = label, tooltip = label, opacity = true,
		get = function()
			local color = db[key]
			return color[1], color[2], color[3], color[4] or 1
		end,
		set = function(red, green, blue, alpha) db[key] = { red, green, blue, alpha } end,
	}
end

local function Menu(db, key, entries, width)
	return { entries = entries, width = width or MENU_WIDTH, get = function() return db[key] end, set = function(value) db[key] = value end }
end

local function TagInput(db, key, placeholder)
	return { kind = 'input', width = TAG_WIDTH, placeholder = placeholder, get = function() return db[key] or '' end, set = function(text) db[key] = text ~= '' and text or nil end }
end

local function Eye(tooltip, get, set)
	return { icon = 'eye', tooltip = tooltip, get = get, set = function(value)
		set(value)
		Repaint()
	end }
end

local function PreviewEye(unitKey)
	return Eye('Show a movable preview of this frame in the world', function() return UnitFrames().IsPreviewShown(unitKey) end, function() UnitFrames().TogglePreview(unitKey) end)
end

local function MirrorKeys(source, destination)
	local blocked = { enabled = true, width = true, height = true, position = true, spacing = true, growthDirection = true, anchorFrame = true, anchorPoint = true, anchorOffsetX = true, anchorOffsetY = true, matchAnchorWidth = true, matchAnchorHeight = true, customName = true }
	for key in pairs(source) do
		if not blocked[key] and not (type(key) == 'string' and key:sub(1, 1) == '_') then destination[key] = BUI.Tools.DeepCopy(source[key]) end
	end
end

local function IsDriven(unitKey)
	local stash = Settings()._syncStash
	return stash ~= nil and stash[unitKey] ~= nil
end

local function SetDriven(unitKey, driven)
	local settings = Settings()
	if driven and not IsDriven(unitKey) then
		settings._syncStash = settings._syncStash or {}
		local snapshot = {}
		MirrorKeys(settings[unitKey], snapshot)
		settings._syncStash[unitKey] = snapshot
		MirrorKeys(settings.player, settings[unitKey])
	elseif not driven and IsDriven(unitKey) then
		MirrorKeys(settings._syncStash[unitKey], settings[unitKey])
		settings._syncStash[unitKey] = nil
	end
end

local function ApplySync()
	local settings = Settings()
	local on = settings.syncPlayerTarget == true
	SetDriven('target', on)
	SetDriven('pet', on and not settings.excludePetFromSync)
end

local function PropagatePlayer()
	local settings = Settings()
	if IsDriven('target') then MirrorKeys(settings.player, settings.target) end
	if IsDriven('pet') then MirrorKeys(settings.player, settings.pet) end
end

local function RefreshFrames()
	PropagatePlayer()
	local module = UnitFrames()
	module.InvalidateSettingsCache()
	module:Refresh()
	module.UpdatePreviews()
	RefreshPreview()
end

local function RefreshAuras()
	PropagatePlayer()
	local module = UnitFrames()
	module.InvalidateSettingsCache()
	for _, unitKey in ipairs({ 'player', 'target', 'focus' }) do
		if module[unitKey] then module.RefreshAuraLayout(module[unitKey], unitKey) end
	end
	for index = 1, 5 do
		local boss = module['boss' .. index]
		if boss then module.RefreshAuraLayout(boss, 'boss') end
	end
	local previews = module._previewFrames
	if previews then
		for _, unitKey in ipairs({ 'player', 'target', 'focus', 'targettarget', 'pet' }) do
			local frame = previews[unitKey]
			if frame and frame:IsShown() then module.UpdatePreviewAurasOnly(frame, unitKey) end
		end
		if previews.boss then
			for index = 1, 5 do
				local boss = module['boss' .. index]
				if boss and boss:IsShown() then module.UpdatePreviewAurasOnly(boss, 'boss', index) end
			end
		end
	end
	RefreshPreview()
end

local function RefreshFilters()
	local module = UnitFrames()
	module.InvalidateFilterCache()
	if module.targettarget then module.RefreshAuraLayout(module.targettarget, 'targettarget') end
	if module.pet then module.RefreshAuraLayout(module.pet, 'pet') end
	RefreshAuras()
end

local function MockPointX(point, width)
	if point:find('LEFT') then return 0 end
	if point:find('RIGHT') then return width end
	return width / 2
end

local function MockPointY(point, height)
	if point:find('TOP') then return 0 end
	if point:find('BOTTOM') then return height end
	return height / 2
end

local function CreateMock(stage)
	local mock = CreateFrame('Frame', nil, stage)
	mock:SetPoint('CENTER')
	local border = mock:CreateTexture(nil, 'BACKGROUND', nil, 0)
	border:SetTexture(WHITE)
	border:SetAllPoints()
	local background = mock:CreateTexture(nil, 'BACKGROUND', nil, 1)
	background:SetTexture(WHITE)
	background:SetPoint('TOPLEFT', 1, -1)
	background:SetPoint('BOTTOMRIGHT', -1, 1)
	local health = mock:CreateTexture(nil, 'ARTWORK', nil, 0)
	local healthZone = CreateFrame('Frame', nil, mock)
	local absorb = mock:CreateTexture(nil, 'ARTWORK', nil, 1)
	absorb:SetTexture(WHITE)
	local powerBackground = mock:CreateTexture(nil, 'ARTWORK', nil, 0)
	powerBackground:SetTexture(WHITE)
	local power = mock:CreateTexture(nil, 'ARTWORK', nil, 1)
	local nameText = mock:CreateFontString(nil, 'OVERLAY')
	local healthText = mock:CreateFontString(nil, 'OVERLAY')
	local powerText = mock:CreateFontString(nil, 'OVERLAY')
	local raidIcon = mock:CreateTexture(nil, 'OVERLAY')
	raidIcon:SetTexture(RAID_ICON)
	local customTexts, auraIcons = {}, {}

	local function AuraIcon(index)
		if not auraIcons[index] then
			local icon = {}
			icon.border = mock:CreateTexture(nil, 'OVERLAY', nil, 1)
			icon.border:SetTexture(WHITE)
			icon.texture = mock:CreateTexture(nil, 'OVERLAY', nil, 2)
			icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			auraIcons[index] = icon
		end
		return auraIcons[index]
	end

	function mock:SetOffset(x, y)
		local scale = self:GetScale()
		self:ClearAllPoints()
		self:SetPoint('CENTER', stage, 'CENTER', x / scale, y / scale)
	end

	function mock:Render(unitKey, maxWidth, maxHeight)
		local settings = Settings()
		local unitSettings = settings[unitKey]
		local isPet = unitKey == 'pet'
		local width, height = unitSettings.width, unitSettings.height
		local Parse = UnitFrames().ParsePreviewTags
		local texture = Media('statusbar', settings.texture, BUI.GetGlobalTexture())
		local font = Media('font', settings.font, BUI.GetGlobalFont())

		local showDebuffs = unitSettings.showDebuffs == true
		local showBuffs = unitSettings.showBuffs == true
		local auraPadding = 0
		if showDebuffs then
			local count = math.min(unitSettings.maxDebuffs, 16)
			local perRow = math.max(1, math.min(unitSettings.debuffsPerRow or unitSettings.maxDebuffs, count))
			local rows = math.ceil(count / perRow)
			local size = unitSettings.debuffIconSize or unitSettings.auraIconSize
			local gap = unitSettings.debuffSpacing or unitSettings.auraSpacing
			auraPadding = math.max(auraPadding, rows * size + (rows - 1) * gap + 8)
		end
		if showBuffs then
			local count = math.min(unitSettings.maxBuffs, 16)
			local perRow = math.max(1, math.min(unitSettings.buffsPerRow or unitSettings.maxBuffs, count))
			local rows = math.ceil(count / perRow)
			local size = unitSettings.buffIconSize or unitSettings.auraIconSize
			local gap = unitSettings.buffSpacing or unitSettings.auraSpacing
			auraPadding = math.max(auraPadding, rows * size + (rows - 1) * gap + 8)
		end
		local scale = math.min(1, maxWidth / width, maxHeight / (height + auraPadding * 2))
		self:SetScale(scale)
		self:SetSize(width, height)

		local borderColor = isPet and settings.petBorderColor or settings.borderColor
		border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
		local backgroundColor = isPet and settings.petBgColor or settings.bgColor
		background:SetVertexColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])

		local powerHeight = unitSettings.showPower and math.min(unitSettings.powerHeight, height - 6) or 0
		local innerWidth = width - 2
		local innerHeight = height - 2 - powerHeight - (powerHeight > 0 and 1 or 0)
		local _, class = UnitClass('player')
		local classColor = class and RAID_CLASS_COLORS[class]
		local healthRed, healthGreen, healthBlue = 0.2, 0.8, 0.2
		if settings.classColorHealth and classColor then
			healthRed, healthGreen, healthBlue = classColor.r, classColor.g, classColor.b
		else
			local color = isPet and settings.petHealthColor or settings.healthColor
			healthRed, healthGreen, healthBlue = color[1], color[2], color[3]
		end
		health:SetTexture(texture)
		health:ClearAllPoints()
		health:SetPoint('TOPLEFT', 1, -1)
		health:SetSize(innerWidth * 0.72, innerHeight)
		health:SetVertexColor(healthRed, healthGreen, healthBlue, settings.transparentHealth and settings.healthBarAlpha or 1)
		healthZone:ClearAllPoints()
		healthZone:SetPoint('TOPLEFT', 1, -1)
		healthZone:SetSize(innerWidth, innerHeight)

		if settings.shieldEnabled ~= false then
			local shield = settings.shieldColor
			absorb:ClearAllPoints()
			absorb:SetPoint('TOPLEFT', health, 'TOPRIGHT', 0, 0)
			absorb:SetSize(innerWidth * 0.1, innerHeight)
			absorb:SetVertexColor(shield[1], shield[2], shield[3], shield[4])
			absorb:Show()
		else
			absorb:Hide()
		end

		if powerHeight > 0 then
			local powerRed, powerGreen, powerBlue
			if isPet then
				local color = settings.petPowerColor
				powerRed, powerGreen, powerBlue = color[1], color[2], color[3]
			elseif settings.classColorPower then
				powerRed, powerGreen, powerBlue = 0.25, 0.5, 1
			elseif settings.useClassColorPowerBar and classColor then
				powerRed, powerGreen, powerBlue = classColor.r, classColor.g, classColor.b
			else
				local color = settings.powerColor
				powerRed, powerGreen, powerBlue = color[1], color[2], color[3]
			end
			local powerBackgroundColor = isPet and settings.petPowerBgColor or settings.powerBgColor or backgroundColor
			powerBackground:ClearAllPoints()
			powerBackground:SetPoint('BOTTOMLEFT', 1, 1)
			powerBackground:SetPoint('BOTTOMRIGHT', -1, 1)
			powerBackground:SetHeight(powerHeight)
			powerBackground:SetVertexColor(powerBackgroundColor[1], powerBackgroundColor[2], powerBackgroundColor[3], powerBackgroundColor[4])
			power:SetTexture(texture)
			power:ClearAllPoints()
			power:SetPoint('BOTTOMLEFT', 1, 1)
			power:SetSize(innerWidth * 0.6, powerHeight)
			power:SetVertexColor(powerRed, powerGreen, powerBlue, 1)
			powerBackground:Show()
			power:Show()
		else
			powerBackground:Hide()
			power:Hide()
		end

		local function PlaceText(fontString, show, format, fallback, size, position, offsetX, offsetY, region, color)
			if not show then return fontString:Hide() end
			Pixel.ApplyFont(fontString, size, font)
			local text = format and format ~= '' and format or fallback
			fontString:SetText(Parse and Parse(text) or text)
			fontString:ClearAllPoints()
			local insetX = position:find('LEFT') and 4 or position:find('RIGHT') and -4 or 0
			local insetY = position:find('TOP') and -1 or position:find('BOTTOM') and 1 or 0
			fontString:SetPoint(position, region, position, insetX + offsetX, insetY + offsetY)
			fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
			fontString:Show()
		end

		local nameColor
		if unitSettings.classColorName and classColor then
			nameColor = { classColor.r, classColor.g, classColor.b, 1 }
		elseif unitKey == 'target' or unitKey == 'boss' then
			nameColor = unitSettings.hostileNameColor
		else
			nameColor = unitSettings.friendlyNameColor
		end
		PlaceText(nameText, ResolveShow(unitSettings.showName, settings.showName), unitSettings.nameFormat, settings.nameFormat, unitSettings.nameTextSize, unitSettings.namePosition, unitSettings.nameOffsetX, unitSettings.nameOffsetY, healthZone, nameColor)
		PlaceText(healthText, ResolveShow(unitSettings.showHealthText, settings.showHealthText), unitSettings.healthFormat, settings.healthFormat, unitSettings.healthTextSize, unitSettings.healthPosition, unitSettings.healthOffsetX, unitSettings.healthOffsetY, healthZone, { 1, 1, 1, 1 })
		PlaceText(powerText, powerHeight > 0 and ResolveShow(unitSettings.showPowerText, settings.showPowerText, false), unitSettings.powerFormat, settings.powerFormat, unitSettings.powerTextSize, unitSettings.powerPosition, unitSettings.powerOffsetX, unitSettings.powerOffsetY, powerBackground, { 1, 1, 1, 1 })

		local tagIndex = 0
		for _, entry in ipairs(unitSettings.customTags) do
			if entry.tag and entry.tag ~= '' and entry.enabled ~= false then
				tagIndex = tagIndex + 1
				local fontString = customTexts[tagIndex]
				if not fontString then
					fontString = mock:CreateFontString(nil, 'OVERLAY')
					customTexts[tagIndex] = fontString
				end
				Pixel.ApplyFont(fontString, entry.fontSize or 12, Media('font', entry.font, font))
				fontString:SetDrawLayer(entry.drawLayer or 'OVERLAY', entry.drawSubLevel or 0)
				fontString:ClearAllPoints()
				local point = entry.point or 'CENTER'
				fontString:SetPoint(point, self, point, entry.x or 0, entry.y or 0)
				local color = entry.color
				if color then fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1) else fontString:SetTextColor(1, 1, 1, 1) end
				fontString:SetText(Parse and Parse(entry.tag) or entry.tag)
				fontString:Show()
			end
		end
		for index = tagIndex + 1, #customTexts do customTexts[index]:Hide() end

		local used = 0
		local function AuraGrid(icons, count, perRow, size, gap, growX, growY, framePoint, offsetX, offsetY, typed)
			count = math.min(count, 16)
			perRow = math.max(1, math.min(perRow, count))
			local rows = math.ceil(count / perRow)
			local gridWidth = perRow * size + (perRow - 1) * gap
			local gridHeight = rows * size + (rows - 1) * gap
			local selfPoint = (growY == 'UP' and 'BOTTOM' or 'TOP') .. (growX == 'RIGHT' and 'LEFT' or 'RIGHT')
			local anchorX = MockPointX(framePoint, width) + offsetX
			local anchorY = MockPointY(framePoint, height) - offsetY
			local gridLeft = anchorX - MockPointX(selfPoint, gridWidth)
			local gridTop = anchorY - MockPointY(selfPoint, gridHeight)
			for auraIndex = 1, count do
				used = used + 1
				local icon = AuraIcon(used)
				local row = math.floor((auraIndex - 1) / perRow)
				local column = (auraIndex - 1) % perRow
				local x = growX == 'LEFT' and (gridWidth - size - column * (size + gap)) or (column * (size + gap))
				local y = growY == 'UP' and (gridHeight - size - row * (size + gap)) or (row * (size + gap))
				icon.border:SetSize(size + 2, size + 2)
				icon.border:ClearAllPoints()
				icon.border:SetPoint('TOPLEFT', self, 'TOPLEFT', gridLeft + x - 1, -(gridTop + y - 1))
				if typed then
					local dispelColor = MOCK_DISPEL_COLORS[(auraIndex - 1) % #MOCK_DISPEL_COLORS + 1]
					icon.border:SetVertexColor(dispelColor[1], dispelColor[2], dispelColor[3], 1)
				elseif icons == MOCK_DEBUFF_ICONS then
					icon.border:SetVertexColor(0.8, 0, 0, 1)
				else
					icon.border:SetVertexColor(0, 0, 0, 1)
				end
				icon.texture:SetTexture(icons[(auraIndex - 1) % #icons + 1])
				icon.texture:SetSize(size, size)
				icon.texture:ClearAllPoints()
				icon.texture:SetPoint('CENTER', icon.border, 'CENTER', 0, 0)
				icon.border:Show()
				icon.texture:Show()
			end
		end
		if showDebuffs then
			AuraGrid(MOCK_DEBUFF_ICONS, unitSettings.maxDebuffs, unitSettings.debuffsPerRow or unitSettings.maxDebuffs, unitSettings.debuffIconSize or unitSettings.auraIconSize, unitSettings.debuffSpacing or unitSettings.auraSpacing, unitSettings.debuffGrowthX, unitSettings.debuffGrowthY, unitSettings.debuffAnchorPoint, unitSettings.debuffOffsetX, unitSettings.debuffOffsetY, unitSettings.showDebuffType ~= false)
		end
		if showBuffs then
			AuraGrid(MOCK_BUFF_ICONS, unitSettings.maxBuffs, unitSettings.buffsPerRow or unitSettings.maxBuffs, unitSettings.buffIconSize or unitSettings.auraIconSize, unitSettings.buffSpacing or unitSettings.auraSpacing, unitSettings.buffGrowthX or 'RIGHT', unitSettings.buffGrowthY or 'DOWN', unitSettings.buffAnchorPoint or 'BOTTOMLEFT', unitSettings.buffOffsetX or 0, unitSettings.buffOffsetY or -4, false)
		end
		for index = used + 1, #auraIcons do
			auraIcons[index].border:Hide()
			auraIcons[index].texture:Hide()
		end

		if settings.raidIconMode ~= 'off' and not unitSettings.hideRaidIcon then
			raidIcon:SetSize(settings.raidIconSize, settings.raidIconSize)
			raidIcon:ClearAllPoints()
			raidIcon:SetPoint('CENTER', self, settings.raidIconPosition, settings.raidIconOffsetX, settings.raidIconOffsetY)
			raidIcon:Show()
		else
			raidIcon:Hide()
		end
		self:Show()
		return width * scale, height * scale
	end
	return mock
end

local function BuildPreview(band, kit)
	local stage = CreateFrame('Frame', nil, band)
	stage:SetAllPoints()
	stage:SetClipsChildren(true)
	local mocks = { CreateMock(stage), CreateMock(stage) }
	local captions = { kit.Text(stage, 'PLAYER', 9, 'faint'), kit.Text(stage, 'TARGET', 9, 'faint') }
	local captionY = -(PREVIEW_HEIGHT / 2) + 16
	function band:Update()
		for _, mock in ipairs(mocks) do mock:Hide() end
		for _, caption in ipairs(captions) do caption:Hide() end
		if selected == 'appearance' or selected == 'filters' then
			local playerWidth = mocks[1]:Render('player', MOCK_PAIR_WIDTH, PREVIEW_HEIGHT - 22)
			local targetWidth = mocks[2]:Render('target', MOCK_PAIR_WIDTH, PREVIEW_HEIGHT - 22)
			local playerX, targetX = -(playerWidth / 2 + MOCK_GAP), targetWidth / 2 + MOCK_GAP
			mocks[1]:SetOffset(playerX, 0)
			mocks[2]:SetOffset(targetX, 0)
			for index, x in ipairs({ playerX, targetX }) do
				captions[index]:ClearAllPoints()
				captions[index]:SetPoint('CENTER', stage, 'CENTER', x, captionY)
				captions[index]:Show()
			end
			return
		end
		local unitKey = selected == 'tags' and tagUnit or selected
		if unitKey == 'boss' then
			local _, mockHeight = mocks[1]:Render('boss', MOCK_WIDTH, MOCK_BOSS_HEIGHT)
			mocks[2]:Render('boss', MOCK_WIDTH, MOCK_BOSS_HEIGHT)
			local boss = Settings().boss
			local offset = (mockHeight + boss.spacing * mocks[1]:GetScale()) / 2
			local top = boss.growthDirection == 'DOWN' and offset or -offset
			mocks[1]:SetOffset(0, top)
			mocks[2]:SetOffset(0, -top)
			return
		end
		mocks[1]:Render(unitKey, MOCK_WIDTH, PREVIEW_HEIGHT)
		mocks[1]:SetOffset(0, 0)
	end
	band:HookScript('OnShow', function(self) self:Update() end)
	return band
end

local function AppearanceBoards(ui, parent, width)
	local settings = Settings()
	local module = UnitFrames()
	local general = ui.Board(parent, width, {
		stacked = true,
		title = 'Frames',
		description = 'Texture, font and behavior shared by every unit frame.',
	})
	general:AddTools('Look', 'Bar texture and font for names, health and power', {
		Menu(settings, 'texture', textures, MENU_WIDTH),
		Menu(settings, 'font', fonts, MENU_WIDTH),
	}, RefreshFrames)
	general:AddSwitch('Tooltips', function() return settings.showTooltips ~= false end, function(value) settings.showTooltips = value end, 'Unit tooltip on mouseover')
	general:AddSwitch('Click to target', function() return settings.clickToTarget ~= false end, function(value)
		settings.clickToTarget = value
		module.ApplyClickToTarget()
	end, 'Clicking a frame targets its unit')
	general:AddSwitch('Decimal abbreviations', function() return BUI.GetDB().general.showDecimalAbbreviations == true end, function(value)
		BUI.GetDB().general.showDecimalAbbreviations = value
		module.RefreshAbbreviationSetting()
		module.InvalidateTagCache()
		RefreshFrames()
	end, 'Abbreviate numbers with one decimal, 7.5K')
	general:AddSwitch('Sync target and pet to the player', function() return settings.syncPlayerTarget == true end, function(value)
		settings.syncPlayerTarget = value
		ApplySync()
		RefreshFrames()
		RebuildPage()
	end, 'Target and pet copy the player frame look')
	general:AddSwitch('Keep the pet independent', function() return settings.excludePetFromSync == true end, function(value)
		settings.excludePetFromSync = value
		ApplySync()
		RefreshFrames()
		RebuildPage()
	end, 'Leave the pet frame out of the sync')

	local health = ui.Board(parent, width, {
		stacked = true,
		title = 'Health and power',
		description = 'Bar colors and absorbs. The eye shows a movable preview of the player frame.',
	})
	health:AddTools('Health bar', 'Health, background and border colors', {
		Color(settings, 'Health', 'healthColor'),
		Color(settings, 'Background', 'bgColor'),
		Color(settings, 'Border', 'borderColor'),
	}, RefreshFrames)
	health:AddSwitch('Class color health', function() return settings.classColorHealth == true end, function(value)
		settings.classColorHealth = value
		RefreshFrames()
	end, 'Fill health bars with the class color')
	health:AddTools('Transparent health', 'See through health fill', {
		{ tooltip = 'Fill opacity', title = 'Transparent health', options = {
			{ label = 'Fill opacity %', min = 0, max = 100, step = 5, get = function() return math.floor(settings.healthBarAlpha * 100) end, set = function(value) settings.healthBarAlpha = value / 100 end },
		} },
		Toggle(settings, nil, 'transparentHealth'),
	}, RefreshFrames)
	health:AddTools('Damage absorb', 'Absorb shield overlay on the health bar', {
		Color(settings, 'Fill color', 'shieldColor'),
		{ tooltip = 'Texture and direction', title = 'Damage absorb', options = {
			Option(settings, 'Texture', 'shieldOverlay', { entries = ABSORB_TEXTURES }),
			Option(settings, 'Direction', 'shieldDirection', { entries = ABSORB_DIRECTIONS }),
		} },
		PreviewEye('player'),
		OnUnlessOff(settings, nil, 'shieldEnabled'),
	}, RefreshFrames)
	health:AddTools('Heal absorb', 'Heal absorb overlay on the health bar', {
		Color(settings, 'Fill color', 'healAbsorbColor'),
		{ tooltip = 'Texture and direction', title = 'Heal absorb', options = {
			Option(settings, 'Texture', 'healAbsorbOverlay', { entries = ABSORB_TEXTURES }),
			Option(settings, 'Direction', 'healAbsorbDirection', { entries = ABSORB_DIRECTIONS }),
		} },
		PreviewEye('player'),
		OnUnlessOff(settings, nil, 'healAbsorbEnabled'),
	}, RefreshFrames)
	health:AddTools('Power bar', 'Power fill and background colors', {
		Color(settings, 'Power', 'powerColor'),
		Color(settings, 'Background', 'powerBgColor'),
	}, RefreshFrames)
	health:AddSwitch('Color by resource type', function() return settings.classColorPower == true end, function(value)
		settings.classColorPower = value
		RefreshFrames()
	end, 'Mana blue, energy yellow and so on')
	health:AddSwitch('Color by class or reaction', function() return settings.useClassColorPowerBar == true end, function(value)
		settings.useClassColorPowerBar = value
		RefreshFrames()
	end, 'The power bar takes the class color')

	local player = settings.player
	local function RefreshDispel()
		RefreshFrames()
		module.RefreshDispelPreview()
	end
	local dispel = ui.Board(parent, width, {
		stacked = true,
		title = 'Dispels',
		description = 'Color your own frame when a dispellable debuff lands.',
	})
	dispel:AddTools('Dispel highlight', 'How the player frame reacts', {
		{ entries = DISPEL_MODES, width = MENU_WIDTH, get = function()
			if player.debuffHighlightBorder then return 'border' end
			if player.debuffHighlightBar then return 'bar' end
			return 'off'
		end, set = function(value)
			player.debuffHighlightBorder = value == 'border'
			player.debuffHighlightBar = value == 'bar'
		end },
		{ tooltip = 'Source and strength', title = 'Dispel highlight', options = {
			{ label = 'Show', entries = DISPEL_SOURCES, get = function() return player.debuffHighlightClassFilter ~= false and 'mine' or 'all' end, set = function(value) player.debuffHighlightClassFilter = value == 'mine' end },
			Option(settings, 'Bar tint opacity %', 'dispelOpacity', { min = 0, max = 100, step = 5 }),
		} },
	}, RefreshDispel)
	dispel:AddTools('Type icons', 'A row of debuff type icons above your character', {
		{ tooltip = 'Size and position', title = 'Type icons', options = {
			Option(player, 'Size', 'debuffHighlightBadgeSize', { min = 10, max = 48, step = 1 }),
			Option(player, 'Horizontal', 'debuffHighlightBadgeOffsetX', { min = -BADGE_RANGE_X, max = BADGE_RANGE_X, step = 1 }),
			Option(player, 'Vertical', 'debuffHighlightBadgeOffsetY', { min = -BADGE_RANGE_Y, max = BADGE_RANGE_Y, step = 1 }),
		} },
		OnUnlessOff(player, nil, 'debuffHighlightBadge'),
	}, RefreshDispel)
	dispel:AddSwitch('Cleanse callouts', function() return player.debuffHighlightTypeText == true end, function(value)
		player.debuffHighlightTypeText = value
		RefreshDispel()
	end, 'FD, TURT and SF prompts when you can clear it yourself')
	dispel:AddSwitch('Recolor type icons', function() return settings.dispelRecolor == true end, function(value)
		settings.dispelRecolor = value
		RefreshDispel()
	end, 'Tint the Blizzard debuff icons to match your colors')
	dispel:AddSwitch('Blend multiple types', function() return settings.dispelBlend == true end, function(value)
		settings.dispelBlend = value
		RefreshDispel()
	end, 'With two debuffs up, mix both colors instead of showing the higher priority one')
	local store = BUI.Colors.GetStore()
	local swatches = {
		{ icon = 'reset', tooltip = 'Back to the default colors', onClick = function()
			BUI.Colors.ResetGroup('Dispel Types')
			BUI.ApplyColors()
			RefreshDispel()
			Repaint()
		end },
	}
	for _, typeName in ipairs(DISPEL_TYPES) do
		local stored = store[BUI.AuraEngine.DispelColorKey(typeName)]
		swatches[#swatches + 1] = {
			kind = 'swatch', tooltip = typeName, opacity = true,
			get = function() return stored.r, stored.g, stored.b, stored.a end,
			set = function(red, green, blue, alpha) stored.r, stored.g, stored.b, stored.a = red, green, blue, alpha end,
		}
	end
	dispel:AddTools('Type colors', 'Shared with the party and raid frames', swatches, RefreshDispel)

	local tags = ui.Board(parent, width, {
		stacked = true,
		title = 'Default tags',
		description = 'Text formats every frame falls back on. A frame can override each one on its own pane.',
	})
	tags:AddTools('Name tag', nil, { TagInput(settings, 'nameFormat', DEFAULT_TAGS.name) }, RefreshFrames)
	tags:AddTools('Health tag', nil, { TagInput(settings, 'healthFormat', DEFAULT_TAGS.health) }, RefreshFrames)
	tags:AddTools('Power tag', nil, { TagInput(settings, 'powerFormat', DEFAULT_TAGS.power) }, RefreshFrames)
	tags:AddTools('Reset tags', 'Restore the default name, health and power tags', {
		{ text = 'Reset', onClick = function()
			settings.nameFormat, settings.healthFormat, settings.powerFormat = DEFAULT_TAGS.name, DEFAULT_TAGS.health, DEFAULT_TAGS.power
			RefreshFrames()
			Repaint()
		end },
	})

	local indicators = ui.Board(parent, width, {
		stacked = true,
		title = 'Indicators',
		description = 'Icons layered on every frame.',
	})
	indicators:AddTools('Raid icon', 'Raid target marker on each frame', {
		{ tooltip = 'Position and size', title = 'Raid icon', options = {
			Option(settings, 'Position', 'raidIconPosition', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(settings, 'Size', 'raidIconSize', { min = 8, max = 50, step = 1 }),
			Option(settings, 'Horizontal', 'raidIconOffsetX', { min = -ICON_RANGE, max = ICON_RANGE, step = 1 }),
			Option(settings, 'Vertical', 'raidIconOffsetY', { min = -ICON_RANGE, max = ICON_RANGE, step = 1 }),
		} },
		{ get = function() return settings.raidIconMode ~= 'off' end, set = function(value) settings.raidIconMode = value and 'icon' or 'off' end },
	}, RefreshFrames)
	indicators:AddTools('Leader icon', 'Leader and assist crown on the frames', {
		{ tooltip = 'Position and size', title = 'Leader icon', options = {
			Option(settings, 'Position', 'leaderIconPosition', { entries = BUI.C.ANCHOR_POINT_OPTIONS }),
			Option(settings, 'Size', 'leaderIconSize', { min = 8, max = 32, step = 1 }),
			Option(settings, 'Horizontal', 'leaderIconOffsetX', { min = -ICON_RANGE, max = ICON_RANGE, step = 1 }),
			Option(settings, 'Vertical', 'leaderIconOffsetY', { min = -ICON_RANGE, max = ICON_RANGE, step = 1 }),
		} },
		OnUnlessOff(settings, nil, 'leaderIconEnabled'),
	}, RefreshFrames)
	return { general, health, dispel, tags, indicators }
end

local function TagsBoards(ui, parent, width, page)
	local settings = Settings()
	local unitSettings = settings[tagUnit]
	local custom = ui.Board(parent, width, {
		stacked = true,
		title = 'Custom tags',
		description = 'Extra text elements driven by tags, attached to one frame. The preview above shows them in place.',
		buttons = {
			{ text = 'New tag', icon = 'plus', onClick = function()
				unitSettings.customTags[#unitSettings.customTags + 1] = { name = 'Tag ' .. (#unitSettings.customTags + 1), tag = '[name]', point = 'CENTER', x = 0, y = 0, fontSize = 12, color = { 1, 1, 1, 1 }, enabled = true, drawLayer = 'OVERLAY', drawSubLevel = 0 }
				RefreshFrames()
				page:RebuildCurrent()
			end },
		},
	})
	custom:AddTools('Frame', 'Which frame these tags belong to', {
		{ entries = TAG_UNITS, width = MENU_WIDTH, get = function() return tagUnit end, set = function(value)
			tagUnit = value
			RefreshPreview()
			RebuildPane(page)
		end },
	})
	for index, entry in ipairs(unitSettings.customTags) do
		custom:AddTools(entry.name or ('Tag ' .. index), entry.tag or '', {
			Color(entry, 'Text color', 'color'),
			{ icon = 'text', tooltip = 'Name, tag, font and layer', title = entry.name or ('Tag ' .. index), options = {
				{ label = 'Name', kind = 'input', placeholder = 'Name', get = function() return entry.name or '' end, set = function(text)
					entry.name = text ~= '' and text or nil
					page:RebuildCurrent()
				end },
				{ label = 'Tag', kind = 'input', placeholder = '[name]', get = function() return entry.tag or '' end, set = function(text)
					entry.tag = text
					page:RebuildCurrent()
				end },
				{ label = 'Font', entries = fonts, get = function() return entry.font or BUI.C.GLOBAL_OPTION end, set = function(value) entry.font = value ~= BUI.C.GLOBAL_OPTION and value or nil end },
				Option(entry, 'Size', 'fontSize', { min = 6, max = 48, step = 1 }),
				Option(entry, 'Layer', 'drawLayer', { entries = LAYERS }),
				Option(entry, 'Sublevel', 'drawSubLevel', { min = -7, max = 7, step = 1 }),
			} },
			{ icon = 'mover', tooltip = 'Anchor and offset', title = entry.name or ('Tag ' .. index), options = {
				Option(entry, 'Anchor', 'point', { entries = BUI.C.ANCHOR_POINT_OPTIONS_SHORT }),
				Option(entry, 'Horizontal', 'x', { min = -TAG_RANGE, max = TAG_RANGE, step = 1 }),
				Option(entry, 'Vertical', 'y', { min = -TAG_RANGE, max = TAG_RANGE, step = 1 }),
			} },
			OnUnlessOff(entry, nil, 'enabled'),
			{ slot = 'erase', icon = 'erase', size = Layout.ERASE_SIZE, hover = 'danger', tooltip = 'Remove this tag', onClick = function()
				table.remove(unitSettings.customTags, index)
				RefreshFrames()
				page:RebuildCurrent()
			end },
		}, RefreshFrames)
	end
	if #unitSettings.customTags == 0 then custom:AddRow('No custom tags yet', 'Use New tag to add one to this frame') end

	local reference = ui.Board(parent, width, {
		stacked = true,
		title = 'Tag reference',
		description = 'Every text tag with a sample. Click a box and press Ctrl+C to copy it.',
	})
	for _, group in ipairs(TAG_GROUPS) do
		reference:AddCaption(group)
		for _, tag in ipairs(TAGS) do
			if tag.group == group then
				reference:AddTools(tag.description, tag.example, {
					{ kind = 'input', width = COPY_WIDTH, placeholder = tag.tag, get = function() return tag.tag end, set = function() end },
				})
			end
		end
	end
	return { custom, reference }
end

local function FiltersBoards(ui, parent, width, page)
	local filters = BUI.GetDB().auraFilters
	local shared = ui.Board(parent, width, {
		stacked = true,
		title = 'Filters',
		description = 'Pinned auras always show, blacklisted auras never do.',
	})
	AuraLists.ShareCell(shared, 'Share blacklists with the group frames')
	return {
		shared,
		AuraLists.Pinned(ui, parent, width, page, {
			title = 'Pinned buffs', description = 'Always shown on every unit frame, on top of whatever the buff rules match.',
			get = function() return filters.buffWhitelist end, onChange = RefreshFilters,
			only = { label = 'Only show pinned buffs', get = function() return filters.buffWhitelistOnly == true end, set = function(value) filters.buffWhitelistOnly = value end, tip = 'Ignore the buff rules entirely' },
		}),
		AuraLists.Blacklist(ui, parent, width, page, { scope = 'unit', polarity = 'HELPFUL', title = 'Buff blacklist', description = 'Buffs that never show on the unit frames.', onChange = RefreshFilters }),
		AuraLists.Pinned(ui, parent, width, page, {
			title = 'Pinned debuffs', description = 'Always shown on every unit frame, on top of whatever the debuff rules match.',
			get = function() return filters.debuffWhitelist end, onChange = RefreshFilters,
			only = { label = 'Only show pinned debuffs', get = function() return filters.debuffWhitelistOnly == true end, set = function(value) filters.debuffWhitelistOnly = value end, tip = 'Ignore the debuff rules entirely' },
		}),
		AuraLists.Blacklist(ui, parent, width, page, { scope = 'unit', polarity = 'HARMFUL', title = 'Debuff blacklist', description = 'Debuffs that never show on the unit frames.', onChange = RefreshFilters }),
	}
end

local function PositionTool(unitKey, unitSettings)
	if not ANCHORABLE[unitKey] then
		return { icon = 'mover', tooltip = 'Position', title = 'Position', options = {
			{ label = 'Horizontal', min = -POSITION_RANGE_X, max = POSITION_RANGE_X, step = 1, get = function() return unitSettings.position.x end, set = function(value)
				unitSettings.position.x, unitSettings.position.point, unitSettings.position.relPoint = value, 'CENTER', 'CENTER'
			end },
			{ label = 'Vertical', min = -POSITION_RANGE_Y, max = POSITION_RANGE_Y, step = 1, get = function() return unitSettings.position.y end, set = function(value)
				unitSettings.position.y, unitSettings.position.point, unitSettings.position.relPoint = value, 'CENTER', 'CENTER'
			end },
		} }
	end
	local module = UnitFrames()
	local selfFrame = module[unitKey]
	local frames
	if unitKey == 'targettarget' then
		frames = { { tag = 'BUI_TargetFrame', desc = 'Target frame' }, { tag = 'BUI_PlayerFrame', desc = 'Player frame' }, { tag = 'BUI_FocusFrame', desc = 'Focus frame' } }
	else
		frames = BUI.AnchorFramesExcept('BUI_' .. unitKey:sub(1, 1):upper() .. unitKey:sub(2) .. 'Frame')
	end
	if selfFrame then
		local pruned = {}
		for _, frame in ipairs(frames) do
			if not BUI.Anchor.WouldCycle(selfFrame, BUI.ResolveAnchorFrame(frame.tag)) then pruned[#pruned + 1] = frame end
		end
		frames = pruned
	end
	local defaultOffsetX = unitKey == 'targettarget' and 5 or 0
	local proxy = setmetatable({}, {
		__index = function(_, key)
			if key == 'posX' then return unitSettings.position.x end
			if key == 'posY' then return unitSettings.position.y end
			if key == 'anchorOffsetX' then return unitSettings.anchorOffsetX or defaultOffsetX end
			return unitSettings[key]
		end,
		__newindex = function(_, key, value)
			if key == 'posX' then
				unitSettings.position.x, unitSettings.position.point, unitSettings.position.relPoint = value, 'CENTER', 'CENTER'
			elseif key == 'posY' then
				unitSettings.position.y, unitSettings.position.point, unitSettings.position.relPoint = value, 'CENTER', 'CENTER'
			elseif key == 'anchorFrame' then
				if value ~= '' and selfFrame and BUI.Anchor.WouldCycle(selfFrame, BUI.ResolveAnchorFrame(value)) then
					BUI.Print('That frame already anchors to the ' .. unitKey .. ' frame, it would loop.')
					return
				end
				unitSettings.anchorFrame = value
			else
				unitSettings[key] = value
			end
		end,
	})
	return BUI.PositionTool(proxy, { frames = frames, noCenter = true, matchWidth = true, matchHeight = true, rangeX = POSITION_RANGE_X, rangeY = POSITION_RANGE_Y })
end

local function AuraRow(board, unitKey, unitSettings, isDebuff)
	local prefix = isDebuff and 'debuff' or 'buff'
	local title = isDebuff and 'Debuffs' or 'Buffs'
	local function Key(name) return prefix .. name end
	local layout = {
		{ label = 'Anchor point', entries = BUI.C.ANCHOR_POINT_OPTIONS, get = function() return unitSettings[Key('AnchorPoint')] or (isDebuff and 'TOPLEFT' or 'BOTTOMLEFT') end, set = function(value)
			unitSettings[Key('AnchorPoint')] = value
			if value:find('RIGHT') then unitSettings[Key('GrowthX')] = 'LEFT' elseif value:find('LEFT') then unitSettings[Key('GrowthX')] = 'RIGHT' end
			if value:find('TOP') then unitSettings[Key('GrowthY')] = 'UP' elseif value:find('BOTTOM') then unitSettings[Key('GrowthY')] = 'DOWN' end
		end },
		{ label = 'Grow', entries = GROWTHS_X, get = function() return unitSettings[Key('GrowthX')] or 'RIGHT' end, set = function(value) unitSettings[Key('GrowthX')] = value end },
		{ label = 'Rows grow', entries = GROWTHS_Y, get = function() return unitSettings[Key('GrowthY')] or 'DOWN' end, set = function(value) unitSettings[Key('GrowthY')] = value end },
		{ label = 'Horizontal', min = -AURA_RANGE, max = AURA_RANGE, step = 1, get = function() return unitSettings[Key('OffsetX')] or 0 end, set = function(value) unitSettings[Key('OffsetX')] = value end },
		{ label = 'Vertical', min = -AURA_RANGE, max = AURA_RANGE, step = 1, get = function() return unitSettings[Key('OffsetY')] or (isDebuff and 4 or -4) end, set = function(value) unitSettings[Key('OffsetY')] = value end },
	}
	local sizing = {
		{ label = 'Icon size', min = 12, max = 80, step = 1, get = function() return unitSettings[Key('IconSize')] or unitSettings.auraIconSize end, set = function(value) unitSettings[Key('IconSize')] = value end },
		{ label = 'Spacing', min = 0, max = 10, step = 1, get = function() return unitSettings[Key('Spacing')] or unitSettings.auraSpacing end, set = function(value) unitSettings[Key('Spacing')] = value end },
		Option(unitSettings, 'Max icons', isDebuff and 'maxDebuffs' or 'maxBuffs', { min = 1, max = isDebuff and 16 or 32, step = 1 }),
		{ label = 'Per row', min = 1, max = 16, step = 1, get = function() return unitSettings[isDebuff and 'debuffsPerRow' or 'buffsPerRow'] or 8 end, set = function(value) unitSettings[isDebuff and 'debuffsPerRow' or 'buffsPerRow'] = value end },
	}
	local text = {}
	if isDebuff then
		text[#text + 1] = Toggle(unitSettings, 'Reverse swipe', 'auraReverseSwipe')
		text[#text + 1] = OnUnlessOff(unitSettings, 'Color by type', 'showDebuffType')
	end
	text[#text + 1] = { label = 'Sort by', entries = BUI.AuraEngine.SortMethodItems(), get = function() return unitSettings[Key('SortMethod')] or 'default' end, set = function(value) unitSettings[Key('SortMethod')] = value end }
	text[#text + 1] = { label = 'Stack count', get = function() return ResolveShow(unitSettings[Key('ShowStack')], unitSettings.auraShowStack) end, set = function(value) unitSettings[Key('ShowStack')] = value end }
	text[#text + 1] = { label = 'Stack size', min = 6, max = 32, step = 1, get = function() return unitSettings[Key('StackSize')] or unitSettings.auraStackSize end, set = function(value) unitSettings[Key('StackSize')] = value end }
	text[#text + 1] = { label = 'Stack position', entries = STACK_POINTS, get = function() return unitSettings[Key('StackPos')] or 'BOTTOMRIGHT' end, set = function(value) unitSettings[Key('StackPos')] = value end }
	text[#text + 1] = { label = 'Cooldown text', get = function() return ResolveShow(unitSettings[Key('ShowCd')], unitSettings.auraShowCd) end, set = function(value) unitSettings[Key('ShowCd')] = value end }
	text[#text + 1] = { label = 'Cooldown size', min = 6, max = 32, step = 1, get = function() return unitSettings[Key('CdSize')] or unitSettings.auraCdSize end, set = function(value) unitSettings[Key('CdSize')] = value end }
	board:AddTools(title, (isDebuff and 'Debuff' or 'Buff') .. ' icons attached to the frame', {
		AuraLists.Rules({
			getRules = function() return UnitFrames().GetAuraRules(unitSettings, isDebuff) end,
			polarity = isDebuff and 'HARMFUL' or 'HELPFUL', unitFramesOnly = true,
			onChanged = RefreshFrames,
		}),
		{ icon = 'mover', tooltip = 'Anchor, growth and offset', title = title, options = layout },
		{ icon = 'resize', tooltip = 'Size, spacing and count', title = title, options = sizing },
		{ icon = 'text', tooltip = 'Stacks, cooldown text and sorting', title = title, options = text },
		Toggle(unitSettings, nil, isDebuff and 'showDebuffs' or 'showBuffs'),
	}, RefreshFrames)
end

local function BossBoards(ui, parent, width)
	local settings = Settings()
	local boss = settings.boss
	local stacking = ui.Board(parent, width, {
		stacked = true,
		title = 'Stacking',
		description = 'How the five boss frames stack.',
	})
	stacking:AddTools('Stacking', 'Direction and spacing', {
		Menu(boss, 'growthDirection', STACKINGS, 220),
		{ tooltip = 'Spacing between frames', title = 'Stacking', options = { Option(boss, 'Spacing', 'spacing', { min = 0, max = 100, step = 1 }) } },
	}, RefreshFrames)
	local boards = { stacking }
	local CastBar = BUI.CastBar
	local castbar = CastBar.GetSettings('boss')
	if castbar then
		local function Refresh()
			RefreshFrames()
			if UnitFrames().IsPreviewShown('boss') then UnitFrames().ShowBossCastbarPreview() end
		end
		local board = ui.Board(parent, width, {
			stacked = true,
			title = 'Cast bar',
			description = 'The cast bar on each boss frame.',
		})
		board:AddTools('Cast bar', 'Texture, size and layer', {
			Menu(castbar, 'texture', textures, MENU_WIDTH),
			{ tooltip = 'Size and layer', title = 'Cast bar', options = {
				Option(castbar, 'Height', 'height', { min = 4, max = 50, step = 1 }),
				Option(castbar, 'Border size', 'borderSize', { min = 0, max = 5, step = 1 }),
				Option(castbar, 'Layer', 'frameStrata', { entries = BUI.C.STRATA_OPTIONS }),
			} },
			Toggle(castbar, nil, 'enabled'),
		}, Refresh)
		board:AddSwitch('Spell icon', function() return castbar.showIcon == true end, function(value)
			castbar.showIcon = value
			Refresh()
		end, 'The spell icon beside the bar')
		board:AddTools('Text', 'Timer, spell name and size', {
			{ icon = 'text', tooltip = 'What the bar shows', title = 'Text', options = {
				Toggle(castbar, 'Show timer', 'showTimer'),
				OnUnlessOff(castbar, 'Show total time', 'showTotalTime'),
				OnUnlessOff(castbar, 'Countdown', 'countdown'),
				Toggle(castbar, 'Show spell name', 'showSpellName'),
				{ label = 'Name length, 0 for no limit', min = 0, max = 30, step = 1, get = function() return castbar.spellNameMaxLength or 0 end, set = function(value) castbar.spellNameMaxLength = value > 0 and value or nil end },
				Option(castbar, 'Text size', 'textSize', { min = 8, max = 24, step = 1 }),
			} },
		}, Refresh)
		board:AddTools('Colors', 'Bar and border', {
			Color(castbar, 'Bar color', 'barColor'),
			Color(castbar, 'Border color', 'borderColor'),
		}, Refresh)
		local perBoss = {}
		for index = 1, 5 do
			local color = castbar.bossColors[index]
			if not color then
				color = { 0.8, 0.2, 0.2, 1 }
				castbar.bossColors[index] = color
			end
			if color[4] == nil then color[4] = 1 end
			perBoss[#perBoss + 1] = Color(castbar.bossColors, 'Boss ' .. index, index)
		end
		perBoss[#perBoss + 1] = Toggle(castbar, nil, 'useIndividualColors')
		board:AddTools('Per boss colors', 'A distinct bar color for each boss', perBoss, Refresh)
		if castbar.interruptColor then
			board:AddTools('Cast colors', 'Bar color by interrupt state', {
				Color(castbar, 'Interrupt soon', 'interruptWindowColor'),
				Color(castbar, 'Can interrupt', 'interruptReadyColor'),
				Color(castbar, 'Interrupt on cooldown', 'interruptOnCDColor'),
				Color(castbar, 'Not interruptible', 'interruptColor'),
				{ icon = 'eye', tooltip = 'Preview the ready line and the voice lines', get = function() return CastBar.IsPreviewingInterrupt('boss') end, set = function(value)
					if value then CastBar.PreviewInterrupt('boss') else CastBar.StopInterruptPreview('boss') end
					Repaint()
				end },
			}, Refresh)
			board:AddTools('Ready line', 'Line marking when your kick is back up', {
				Color(castbar, 'Line color', 'interruptTickColor'),
				{ tooltip = 'Line width and window', title = 'Ready line', options = {
					Option(castbar, 'Line width', 'interruptTickWidth', { min = 1, max = 6, step = 1 }),
					OnUnlessOff(castbar, 'Show interrupt window', 'interruptWindow'),
				} },
				OnUnlessOff(castbar, nil, 'interruptTick'),
			}, Refresh)
		end
		boards[#boards + 1] = board
	end
	return boards
end

local function UnitBoards(ui, parent, width, unit)
	local settings = Settings()
	local unitKey = unit.key
	local unitSettings = settings[unitKey]
	local description = unit.description
	if IsDriven(unitKey) then description = description .. ' This frame copies the player frame, turn off the sync on Appearance to edit it on its own.' end
	local board = ui.Board(parent, width, {
		stacked = true,
		title = unit.title,
		description = description,
	})
	board:AddTools('Frame', 'Position, size, preview and on or off', {
		PositionTool(unitKey, unitSettings),
		{ icon = 'resize', tooltip = 'Width and height', title = unit.title, options = {
			Option(unitSettings, 'Width', 'width', { min = 50, max = 1500, step = 1 }),
			Option(unitSettings, 'Height', 'height', { min = 1, max = 500, step = 1 }),
		} },
		PreviewEye(unitKey),
		OnUnlessOff(unitSettings, nil, 'enabled'),
	}, RefreshFrames)
	board:AddSwitch('Hide the raid icon', function() return unitSettings.hideRaidIcon == true end, function(value)
		unitSettings.hideRaidIcon = value
		RefreshFrames()
	end, 'No raid marker on this frame')
	board:AddSwitch('Hide the level', function() return unitSettings.hideLevel == true end, function(value)
		unitSettings.hideLevel = value
		RefreshFrames()
	end, 'No level text on this frame')
	if unitKey == 'player' then
		board:AddTools('Power prediction', 'Preview the power cost of your cast', {
			Color(unitSettings, 'Prediction color', 'powerPredictionColor'),
			Toggle(unitSettings, nil, 'powerPrediction'),
		}, RefreshFrames)
		board:AddTools('Combat border', 'Recolor the border while in combat', {
			Color(unitSettings, 'Combat border color', 'combatBorderColor'),
			Toggle(unitSettings, nil, 'combatBorder'),
		}, RefreshFrames)
		board:AddTools('Aggro border', 'Recolor the border when you have aggro', {
			Color(unitSettings, 'Aggro border color', 'aggroBorderColor'),
			Toggle(unitSettings, nil, 'aggroBorder'),
		}, RefreshFrames)
	end
	if unitKey == 'pet' then
		board:AddTools('Pet colors', 'Health, power, backgrounds and border', {
			Color(settings, 'Health', 'petHealthColor'),
			Color(settings, 'Health background', 'petBgColor'),
			Color(settings, 'Power', 'petPowerColor'),
			Color(settings, 'Power background', 'petPowerBgColor'),
			Color(settings, 'Border', 'petBorderColor'),
		}, RefreshFrames)
	end

	local text = ui.Board(parent, width, {
		stacked = true,
		title = 'Text',
		description = 'Name, health and power texts. Tags left empty fall back to the defaults on Appearance.',
	})
	text:AddTools('Name', 'Unit name on the health bar', {
		Color(unitSettings, 'Friendly', 'friendlyNameColor'),
		Color(unitSettings, 'Neutral', 'neutralNameColor'),
		Color(unitSettings, 'Hostile', 'hostileNameColor'),
		{ icon = 'text', tooltip = 'Color, position and size', title = 'Name', options = {
			Toggle(unitSettings, 'Class or reaction color', 'classColorName'),
			Option(unitSettings, 'Position', 'namePosition', { entries = BUI.C.TEXT_PLACEMENT_OPTIONS }),
			Option(unitSettings, 'Text size', 'nameTextSize', { min = 8, max = 20, step = 1 }),
			Option(unitSettings, 'Horizontal', 'nameOffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			Option(unitSettings, 'Vertical', 'nameOffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		} },
		{ get = function() return ResolveShow(unitSettings.showName, settings.showName) end, set = function(value) unitSettings.showName = value end },
	}, RefreshFrames)
	text:AddTools('Name tag', 'Tag override for this frame', { TagInput(unitSettings, 'nameFormat', DEFAULT_TAGS.name) }, RefreshFrames)
	if unitKey == 'player' or unitKey == 'pet' then
		text:AddTools('Custom name', 'Shown instead of the real name', {
			{ kind = 'input', width = NAME_WIDTH, placeholder = 'Real name', get = function() return unitSettings.customName or '' end, set = function(value) unitSettings.customName = value end },
		}, RefreshFrames)
	end
	text:AddTools('Health text', 'Health value on the bar', {
		{ icon = 'text', tooltip = 'Position and size', title = 'Health text', options = {
			Option(unitSettings, 'Position', 'healthPosition', { entries = BUI.C.TEXT_PLACEMENT_OPTIONS }),
			Option(unitSettings, 'Text size', 'healthTextSize', { min = 8, max = 20, step = 1 }),
			Option(unitSettings, 'Horizontal', 'healthOffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			Option(unitSettings, 'Vertical', 'healthOffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		} },
		{ get = function() return ResolveShow(unitSettings.showHealthText, settings.showHealthText) end, set = function(value) unitSettings.showHealthText = value end },
	}, RefreshFrames)
	text:AddTools('Health tag', 'Tag override for this frame', { TagInput(unitSettings, 'healthFormat', DEFAULT_TAGS.health) }, RefreshFrames)
	text:AddTools('Power bar', 'Resource bar under the health bar', {
		{ icon = 'resize', tooltip = 'Height', title = 'Power bar', options = { Option(unitSettings, 'Bar height', 'powerHeight', { min = 1, max = 20, step = 1 }) } },
		Toggle(unitSettings, nil, 'showPower'),
	}, RefreshFrames)
	text:AddTools('Power text', 'Resource value on the power bar', {
		{ icon = 'text', tooltip = 'Position and size', title = 'Power text', options = {
			Option(unitSettings, 'Position', 'powerPosition', { entries = BUI.C.TEXT_PLACEMENT_OPTIONS }),
			Option(unitSettings, 'Text size', 'powerTextSize', { min = 8, max = 20, step = 1 }),
			Option(unitSettings, 'Horizontal', 'powerOffsetX', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
			Option(unitSettings, 'Vertical', 'powerOffsetY', { min = -TEXT_RANGE, max = TEXT_RANGE, step = 1 }),
		} },
		{ get = function() return ResolveShow(unitSettings.showPowerText, settings.showPowerText, false) end, set = function(value) unitSettings.showPowerText = value end },
	}, RefreshFrames)
	text:AddTools('Power tag', 'Tag override for this frame', { TagInput(unitSettings, 'powerFormat', DEFAULT_TAGS.power) }, RefreshFrames)

	local boards = { board, text }
	if AURA_UNITS[unitKey] then
		local auras = ui.Board(parent, width, {
			stacked = true,
			title = 'Auras',
			description = 'Debuff and buff icons attached to the frame. Priority rules decide which auras claim the slots.',
		})
		AuraRow(auras, unitKey, unitSettings, true)
		AuraRow(auras, unitKey, unitSettings, false)
		boards[#boards + 1] = auras
	end
	if unitKey == 'boss' then
		for _, extra in ipairs(BossBoards(ui, parent, width)) do boards[#boards + 1] = extra end
	end
	return boards
end

local function Panes(ui, _, parent, width, item, page)
	if item.id == 'appearance' then return AppearanceBoards(ui, parent, width) end
	if item.id == 'tags' then return TagsBoards(ui, parent, width, page) end
	if item.id == 'filters' then return FiltersBoards(ui, parent, width, page) end
	return UnitBoards(ui, parent, width, UNIT_BY_KEY[item.id])
end

local function RailGroups()
	local frames = {}
	for _, unit in ipairs(UNITS) do frames[#frames + 1] = { id = unit.key, label = unit.label } end
	return {
		{ title = 'Settings', items = {
			{ id = 'appearance', label = 'Appearance', icon = 'cog' },
			{ id = 'tags', label = 'Tags', icon = 'text' },
			{ id = 'filters', label = 'Filters', icon = 'x' },
		} },
		{ title = 'Frames', items = frames },
	}
end

BUI.PageEngine.RegisterPage('unitframes', {
	title = 'Unit Frames',
	buttonText = 'Unit Frames',
	icon = 'profile',
	OnBuild = function(pageFrame)
		fonts = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		textures = BUI.BuildTextureDropdownItems(BUI.C.GLOBAL_OPTION)
		local settings = Settings()
		local module = UnitFrames()
		local page = Layout.Page(pageFrame, nil, PAGE_WIDTH)
		local tab = page:GetTab(1)
		local rail
		rail = Layout.RailPage(tab, { window = Window() }, {
			icon = 'profile',
			title = 'Unit Frames',
			placeholder = 'Search unit frame settings...',
			tools = {
				{ text = 'Test mode', onClick = function()
					module.TestMode.Toggle()
					if module.TestMode.IsActive() then
						Modals.Message({ parent = Window().frame, title = 'Test mode', message = 'Every frame is shown with sample data. Type /buitest to close it.', buttonText = 'Got it' })
					end
				end },
				{ icon = 'enable', tooltip = 'Turn the unit frames on or off, needs a reload', get = function() return settings.enabled == true end, set = function(value)
					settings.enabled = value
					Modals.Confirm({
						parent = Window().frame,
						title = value and 'Unit frames on' or 'Unit frames off',
						message = 'This needs a reload of the interface. Reload now?',
						confirmText = 'Reload', cancelText = 'Later',
						onConfirm = ReloadUI,
					})
				end },
			},
			preview = { height = PREVIEW_HEIGHT, build = function(band, kit) preview = BuildPreview(band, kit) end },
			rail = { groups = RailGroups(), selected = selected },
			build = Panes,
		})
		local Select = rail.Select
		function rail:Select(id)
			selected = id
			Select(self, id)
			Repaint()
			RefreshPreview()
		end
		local tabs = {}
		for index = 1, #TAB_IDS do tabs[index] = tab end
		pageFrame._page = { tabContents = tabs, currentTab = TAB_INDEX[selected], SetTab = function(_, index) rail:Select(TAB_IDS[index] or 'appearance') end }
		for _, unit in ipairs(UNITS) do
			module._previewButtons[unit.key] = { SetText = Repaint }
			module.RegisterPositionCallback(unit.key, RefreshPreview)
		end
		RefreshPreview()
		page:AutoRefresh()
	end,
	OnHide = function()
		BUI.UnitFrames.LockAllPreviews()
		BUI.CastBar.StopInterruptPreview('boss')
		BUI.UnitFrames.UnpinDispelPreview()
	end,
})
