local _, BUI = ...

local function copy(source)
	local result = {}
	for key, value in pairs(source) do result[key] = type(value) == "table" and copy(value) or value end
	return result
end

local function merge(dest, source)
	for key, value in pairs(source) do dest[key] = value end
	return dest
end

local function TextDefaults(size, anchor, offsetX, offsetY, format)
	return {
		format = format, size = size, outline = "OUTLINE",
		anchor = anchor, offsetX = offsetX, offsetY = offsetY,
		color = { 1, 1, 1, 1 },
		classColor = false,
	}
end

local function IconDefaults(size, anchor, offsetX, offsetY, enabled)
	return { enabled = enabled, size = size, anchor = anchor, offsetX = offsetX, offsetY = offsetY }
end

local function AuraContainer(options)
	return {
		enabled       = options.enabled ~= false,
		source        = options.source,
		size          = options.size,
		spacing       = options.spacing or 2,
		rowSpacing    = options.rowSpacing or 2,
		max           = options.max,
		perRow        = options.perRow,
		stackSize     = 10,
		growDirection = options.growDirection,
		anchorPoint   = options.anchorPoint,
		relativePoint = options.relativePoint or options.anchorPoint,
		offsetX       = options.offsetX or 0,
		offsetY       = options.offsetY or 0,
	}
end

local STATUS_COLORS = {
	Offline = { 1, 1, 1, 1 },
	Dead    = { 1, 1, 1, 1 },
	Ghost   = { 1, 1, 1, 1 },
	AFK     = { 1, 1, 1, 1 },
	DND     = { 1, 1, 1, 1 },
}

local function CommonSettings(sizes)
	local statusText = TextDefaults(sizes.statusSize, "CENTER", 0, 0)
	statusText.format = nil
	statusText.colors = copy(STATUS_COLORS)

	return {
		useClassColor        = true,
		classColorNames      = true,
		nameMaxLength        = 0,
		classColorBackground = false,
		healthColor          = { 0.20, 0.70, 0.20, 1 },
		borderColor          = { 0, 0, 0, 1 },
		bgColor              = { 0.08, 0.08, 0.08, 0.85 },
		deadBackground       = true,
		deadBackgroundColor  = { 0.55, 0.08, 0.08, 0.9 },
		healthOpacity        = 35,
		transparentHealth    = false,
		statusbarTexture     = BUI.C.GLOBAL_OPTION,

		absorb = {
			enabled = true, color = { 1, 1, 1, 0.6 },
			texture = "Stripes", direction = "right",
		},
		healAbsorb = {
			enabled = true, color = { 0.9, 0.1, 0.1, 0.6 },
			texture = "Stripes", direction = "left",
		},

		font        = BUI.C.GLOBAL_OPTION,
		absorbColor = { 0.5, 0.5, 1, 1 },

		name       = TextDefaults(sizes.nameSize, sizes.nameAnchor or "LEFT", sizes.nameOX or 4, 0),
		hpText     = TextDefaults(sizes.hpSize,   "RIGHT", -3, 0, "[blu:hppct]"),
		pwrText    = TextDefaults(sizes.pwrSize,  "RIGHT", -3, 0, "[blu:pwr]"),
		statusText = statusText,

		showStatusText   = true,
		showAuraTooltips = sizes.showAuraTooltips or false,
		showUnitTooltips = true,

		targetBorder    = { enabled = true, color = { 1, 1, 0, 1 },   thickness = 2 },
		mouseoverBorder = { enabled = true, color = { 1, 1, 1, 0.7 }, thickness = 2 },

		roleIcon       = IconDefaults(sizes.smallIcon,  "TOP",     0, sizes.iconY, true),
		leaderIcon     = IconDefaults(sizes.smallIcon,  "TOPLEFT", 0, sizes.iconY, true),
		raidTargetIcon = IconDefaults(sizes.markerIcon, "CENTER",  0, 0, true),
		resurrectIcon  = IconDefaults(sizes.rezIcon,    "CENTER",  0, 0, true),
		readyCheckIcon = IconDefaults(sizes.readyIcon,  "CENTER",  0, 0, true),
		combatIcon     = IconDefaults(sizes.combatIcon, "TOP",     0, -2, false),
		dispelBadge    = { size = sizes.badgeSize, anchor = "CENTER", offsetX = 0, offsetY = 0 },

		buffs = AuraContainer({
			enabled = sizes.buffsOn, source = "raid", size = sizes.smallAura,
			spacing = sizes.auraGap, rowSpacing = sizes.auraGap, max = sizes.buffMax, perRow = sizes.buffMax,
			growDirection = "RIGHT", anchorPoint = "BOTTOMLEFT", relativePoint = "TOPLEFT",
			offsetY = 4,
		}),
		debuffs = AuraContainer({
			enabled = sizes.debuffsOn, source = "bossmob", size = sizes.smallAura,
			spacing = sizes.auraGap, rowSpacing = sizes.auraGap, max = sizes.debuffMax, perRow = sizes.debuffMax,
			growDirection = "LEFT", anchorPoint = "BOTTOMRIGHT", relativePoint = "TOPRIGHT",
			offsetY = 4,
		}),
		bigDef = AuraContainer({
			size = sizes.bigDefSize, max = 1, perRow = 1,
			growDirection = "RIGHT", anchorPoint = "LEFT", relativePoint = "RIGHT",
			offsetX = sizes.bigDefOX, offsetY = 0,
		}),
		crowdControl = AuraContainer({
			size = sizes.ccSize, max = sizes.ccMax, perRow = sizes.ccMax,
			growDirection = "RIGHT", anchorPoint = "CENTER", relativePoint = "CENTER",
		}),
		dispelBorder = {
			enabled = true, tintBar = false, source = "mine", showBadge = true,
		},
		privateAuras = {
			enabled = true, size = sizes.paSize, num = 1,
			anchorPoint = "CENTER", relativePoint = "CENTER",
			offsetX = 0, offsetY = 0, spacing = 2,
			growDirection = "RIGHT", showTimer = true,
		},
	}
end

local KEYSTONE_TEXT = TextDefaults(10, "TOPRIGHT", -3, -1)
KEYSTONE_TEXT.outline = ""

local PARTY = merge(CommonSettings({
	nameSize = 11, hpSize = 11, pwrSize = 9, statusSize = 12,
	smallIcon = 20, markerIcon = 32, rezIcon = 30, readyIcon = 28,
	combatIcon = 18, badgeSize = 28, iconY = 22,
	smallAura = 22, auraGap = 2, buffMax = 6, debuffMax = 8, buffsOn = true, debuffsOn = true,
	bigDefSize = 28, bigDefOX = 4, ccSize = 24, ccMax = 4,
	paSize = 30,
}), {
	enabled     = true,
	width       = 160,
	height      = 36,
	powerHeight = 6,
	showPower   = true,
	spacing     = 6,
	point       = "TOPLEFT",
	relPoint    = "TOPLEFT",
	x           = 30,
	y           = -200,
	vertical    = true,
	raidGroup   = "off",
	showName    = true,
	showHpText  = true,
	showPwrText = false,

	showKeystone = false,
	keystone     = KEYSTONE_TEXT,

	anchorFrame      = "",
	anchorPoint      = "BOTTOM",
	anchorOffsetX    = 0,
	anchorOffsetY    = 0,
	matchAnchorWidth = false,

	showPlayer      = false,
	showSolo        = false,
	healerOnlyPower = true,

	sortBy     = "GROUP",
	roleOrder  = "TANK,HEALER,DAMAGER",
	classOrder = "DEATHKNIGHT,DEMONHUNTER,DRUID,EVOKER,HUNTER,MAGE,MONK,PALADIN,PRIEST,ROGUE,SHAMAN,WARLOCK,WARRIOR",
})

local RAID = merge(CommonSettings({
	nameSize = 10, hpSize = 10, pwrSize = 8, statusSize = 10,
	nameOX = 3,
	smallIcon = 16, markerIcon = 26, rezIcon = 24, readyIcon = 22,
	combatIcon = 16, badgeSize = 22, iconY = 18,
	smallAura = 18, auraGap = 1, buffMax = 4, debuffMax = 6, buffsOn = false, debuffsOn = false,
	bigDefSize = 24, bigDefOX = 2, ccSize = 20, ccMax = 3,
	paSize = 24,
	showAuraTooltips = true,
}), {
	enabled         = true,
	roleIconFilter  = "all",
	clampGroups     = true,
	raidWideSorting = false,
	wideSortBy      = "ROLE",
	wideUnitsPerColumn = 5,
	roleOrder  = "TANK,HEALER,DAMAGER",
	classOrder = "DEATHKNIGHT,DEMONHUNTER,DRUID,EVOKER,HUNTER,MAGE,MONK,PALADIN,PRIEST,ROGUE,SHAMAN,WARLOCK,WARRIOR",
	large = {
		enabled = false, threshold = 21,
		width = 64, height = 30, powerHeight = 3,
		spacing = 2, groupSpacing = 6, groupsPerRow = 4,
	},
	width           = 80,
	height          = 36,
	powerHeight     = 4,
	showPower       = true,
	spacing         = 2,
	groupSpacing    = 8,
	groupsPerRow    = 4,
	vertical        = true,
	growUp          = false,
	point           = "TOPLEFT",
	relPoint        = "TOPLEFT",
	x               = 30,
	y               = -400,
	showName        = true,
	showHpText      = false,
	showPwrText     = false,
	healerOnlyPower = true,
})

BUI.Defaults.profile.groupFrames = {
	enabled            = true,
	clickMode          = "down",
	hideBlizzardFrames = true,

	blacklistOverrides = { debuff = {}, buff = {} },

	range = {
		enabled      = true,
		fadeOffline  = true,
		insideAlpha  = 1.0,
		outsideAlpha = 0.45,
	},
	party = PARTY,
	raid  = RAID,
}

BUI.Defaults.profile.modules.groupFrames = true
