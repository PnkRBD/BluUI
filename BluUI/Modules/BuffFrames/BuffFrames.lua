local _, BUI = ...

local Pixel = BUI.Pixel
local Events = BUI.Events

local BuffFrames = {}
BUI.BuffFrames = BuffFrames

local ICON_CROP = 0.08
local BORDER_COLOR = { 0, 0, 0, 1 }
local GROUP_KEY = 'all'
local HIDDEN_ROLESET = 'alwaysBlocked'
local BLIZZARD_ROLESET = 'buffs'
local BLIZZARD_FRAMES = { 'BuffFrame', 'DebuffFrame' }
local CANCEL_BUTTON = 'RightButtonUp'
local TIMER_BAND = 1.5
local TEXT_BOX_SPAN = 2

local function TimerRule(unitSeconds, format)
	local Rounding = Enum.NumericRuleFormatRounding
	if unitSeconds == 1 then return { threshold = 0, step = 1, rounding = Rounding.Down, format = format } end
	return {
		threshold = 1 + TIMER_BAND * unitSeconds,
		format = format,
		components = { { div = unitSeconds, step = 1, rounding = Rounding.Up } },
	}
end

local function TimerFormatter(compact, decimals)
	local gap = compact and '' or ' '
	local breakpoints = {}
	if decimals > 0 then
		breakpoints[1] = { threshold = 0, step = 0.1, rounding = Enum.NumericRuleFormatRounding.Down, format = '%.1f' .. gap .. 's' }
	end
	local seconds = TimerRule(1, '%d' .. gap .. 's')
	seconds.threshold = decimals
	breakpoints[#breakpoints + 1] = seconds
	breakpoints[#breakpoints + 1] = TimerRule(SECONDS_PER_MIN, '%d' .. gap .. 'm')
	breakpoints[#breakpoints + 1] = TimerRule(SECONDS_PER_HOUR, '%d' .. gap .. 'h')
	breakpoints[#breakpoints + 1] = TimerRule(SECONDS_PER_DAY, '%d' .. gap .. 'd')
	local formatter = C_StringUtil.CreateNumericRuleFormatter()
	formatter:SetBreakpoints(breakpoints)
	return formatter
end

local timerOptions = {}

local function TimerOptions(compact, decimals)
	if decimals == 0 and not compact then return nil end
	local key = (compact and 'c' or 'n') .. decimals
	local options = timerOptions[key]
	if not options then
		options = { textFormatter = TimerFormatter(compact, decimals) }
		timerOptions[key] = options
	end
	return options
end

local SORT_METHODS = {
	{ value = 'time',     text = 'Time remaining', enumKey = 'ExpirationOnly' },
	{ value = 'priority', text = 'Priority order', enumKey = 'Default' },
	{ value = 'name',     text = 'Spell name',     enumKey = 'NameOnly' },
	{ value = 'applied',  text = 'Order applied',  enumKey = 'AuraInstanceIDOnly' },
}
BuffFrames.SORT_METHODS = SORT_METHODS

local KINDS = {
	buffs   = { frameName = 'BUI_BuffFrame',   filter = 'HELPFUL', cancel = true, enchants = true, hint = 'Buffs | Drag to Reposition | Right-Click to Lock' },
	debuffs = { frameName = 'BUI_DebuffFrame', filter = 'HARMFUL', dispel = true, hint = 'Debuffs | Drag to Reposition | Right-Click to Lock' },
}
local KIND_ORDER = { 'buffs', 'debuffs' }

local headers = {}
local built = false
local restylePending = false

local function Settings()
	return BUI.GetDB().buffFrames
end

local function Enabled()
	return BUI.IsModuleEnabled('buffFrames')
end

local function Restricted()
	return BUI.Tools.ShouldAurasBeSecret() or BUI.Tools.AuraQueriesBlocked()
end

local function ResolveFont(config)
	local name = config.font
	if name == BUI.C.GLOBAL_OPTION then return BUI.GetGlobalFont() end
	return LibStub('LibSharedMedia-3.0'):Fetch('font', name, true) or BUI.GetGlobalFont()
end

local function SortMethod(config)
	for _, choice in ipairs(SORT_METHODS) do
		if choice.value == config.sortMethod then return AuraContainerSortMethod[choice.enumKey] end
	end
	return AuraContainerSortMethod.Default
end

local function SortDirection(config)
	return config.sortReverse and AuraContainerSortDirection.Reverse or AuraContainerSortDirection.Normal
end

local function GrowthPoint(config)
	return (config.growY == 'UP' and 'BOTTOM' or 'TOP') .. (config.growX == 'RIGHT' and 'LEFT' or 'RIGHT')
end

local function GridWidth(config)
	return config.perRow * config.size + (config.perRow - 1) * config.spacing
end

local function GridHeight(config)
	return config.rows * config.size + (config.rows - 1) * config.rowSpacing
end

local function ElementLayout(config)
	return {
		elementWidth = Pixel.Scale(config.size),
		elementHeight = Pixel.Scale(config.size),
		elementSpacing = Pixel.Scale(config.spacing),
		lineSpacing = Pixel.Scale(config.rowSpacing),
	}
end

local function EnchantLayout(config)
	local layout = ElementLayout(config)
	local Placement = CustomAuraContainerItemEnchantmentPlacement
	layout.placement = config.sortReverse and Placement.AfterAuraGroups or Placement.BeforeAuraGroups
	return layout
end

local function EvenPixels(frame, units)
	local pixel = Pixel.PixelSizeFor(frame, 1)
	return math.ceil(units / pixel / 2) * 2 * pixel
end

local function TextJustify(anchor)
	local horizontal = anchor:find('LEFT') and 'LEFT' or anchor:find('RIGHT') and 'RIGHT' or 'CENTER'
	local vertical = anchor:find('TOP') and 'TOP' or anchor:find('BOTTOM') and 'BOTTOM' or 'MIDDLE'
	return horizontal, vertical
end

local function PlaceText(fontString, button, anchor, offsetX, offsetY, iconSize, fontSize)
	local horizontal, vertical = TextJustify(anchor)
	fontString:SetWordWrap(false)
	fontString:SetJustifyH(horizontal)
	fontString:SetJustifyV(vertical)
	fontString:SetSize(EvenPixels(button, iconSize * TEXT_BOX_SPAN), EvenPixels(button, fontSize * TEXT_BOX_SPAN))
	fontString:ClearAllPoints()
	fontString:SetPoint(anchor, button, anchor, Pixel.ScaleFor(button, offsetX), Pixel.ScaleFor(button, offsetY))
end

local function StyleButton(header, button)
	local config = Settings()[header.key]
	local parts = header.parts[button]
	local size = Pixel.Scale(config.size)
	local font, outline = ResolveFont(config), config.fontOutline
	button:SetSize(size, size)

	local timer = config.timer
	local decimals = config.showCooldownDecimals and config.cooldownDecimalThreshold or 0
	Pixel.ApplyFont(parts.duration, config.durationSize, font, outline)
	PlaceText(parts.duration, button, config.durationAnchor, config.durationOffsetX, config.durationOffsetY, size, config.durationSize)
	button:SetDurationText(parts.duration, TimerOptions(config.compactTimer, decimals))
	parts.duration:SetShown(timer == 'below')
	Pixel.ApplyFont(parts.count, config.countSize, font, outline)
	PlaceText(parts.count, button, config.countAnchor, config.countOffsetX, config.countOffsetY, size, config.countSize)

	local cooldown = parts.cooldown
	cooldown:SetDrawSwipe(config.swipe ~= false)
	cooldown:SetReverse(config.swipeReverse ~= false)
	cooldown:SetDrawEdge(config.swipeEdge)
	cooldown:SetHideCountdownNumbers(timer ~= 'icon')
	cooldown:SetCountdownMillisecondsThreshold(decimals)
	Pixel.ApplyFont(cooldown:GetCountdownFontString(), config.durationSize, font, outline)
	button:SetCancelAuraButtons((header.kind.cancel and config.rightClickCancel ~= false) and CANCEL_BUTTON or nil)
	button:SetHideTooltipInCombat(config.tooltipsInCombat == false)
	button:SetMouseMotionEnabled(config.tooltips ~= false)
	if parts.dispel then parts.dispelStamp = BUI.AuraEngine.SyncDispelBorder(button, parts.dispel, parts.dispelStamp, true) end
end

local function BuildButton(header, button)
	local base = button:CreateTexture(nil, 'BACKGROUND', nil, 0)
	base:SetAllPoints()
	base:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])

	local dispel
	if header.kind.dispel then
		dispel = button:CreateTexture(nil, 'BACKGROUND', nil, 1)
		dispel:SetAllPoints()
		dispel:SetColorTexture(1, 1, 1, 1)
	end

	local edge = Pixel.PixelSize(1)
	local icon = button:CreateTexture(nil, 'ARTWORK')
	icon:SetPoint('TOPLEFT', edge, -edge)
	icon:SetPoint('BOTTOMRIGHT', -edge, edge)
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

	local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
	cooldown:SetPoint('TOPLEFT', edge, -edge)
	cooldown:SetPoint('BOTTOMRIGHT', -edge, edge)

	local textHost = CreateFrame('Frame', nil, button)
	textHost:SetAllPoints()
	textHost:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	textHost:EnableMouse(false)

	header.parts[button] = {
		cooldown = cooldown,
		count = textHost:CreateFontString(nil, 'OVERLAY'),
		duration = textHost:CreateFontString(nil, 'OVERLAY'),
		dispel = dispel,
	}
	header.buttons[#header.buttons + 1] = button
	StyleButton(header, button)

	local parts = header.parts[button]
	button:SetIcon(icon)
	button:SetDurationCooldown(cooldown)
	button:SetApplicationCount(parts.count, {})
end

local function RestyleButtons()
	if Restricted() then
		restylePending = true
		return
	end
	restylePending = false
	for _, header in pairs(headers) do
		for _, button in ipairs(header.buttons) do StyleButton(header, button) end
	end
end

local function ApplyLayout(header)
	local config = Settings()[header.key]
	local container, holder = header.container, header.holder
	local point = GrowthPoint(config)
	local FlowDirection = AnchorUtil.FlowDirection

	container:SetFlowLayoutAnchorPoint(point)
	container:SetFlowLayoutGrowthDirection(
		config.growX == 'RIGHT' and FlowDirection.Right or FlowDirection.Left,
		config.growY == 'UP' and FlowDirection.Up or FlowDirection.Down)
	container:SetFlowLayoutMaximumLineSize(Pixel.Scale(GridWidth(config)) + 0.4)
	container:SetAuraGroupLayout(GROUP_KEY, ElementLayout(config))
	container:SetAuraGroupMaxFrameCount(GROUP_KEY, config.perRow * config.rows)
	container:SetAuraGroupSortMethod(GROUP_KEY, SortMethod(config), SortDirection(config))
	container:SetAuraGroupCandidateFilters(GROUP_KEY, { excludeSpellIDs = BUI.AuraBlacklist.FrameSet(header.kind.filter) })
	if header.kind.enchants then
		container:SetItemEnchantmentLayout(EnchantLayout(config))
		container:SetItemEnchantmentSortMethod(AuraContainerItemEnchantmentSortMethod.Duration, SortDirection(config))
	end

	holder:SetSize(Pixel.Scale(GridWidth(config)), Pixel.Scale(GridHeight(config)))
	BUI.Anchor.ApplyPosition(holder, config)
	container:ClearAllPoints()
	container:SetPoint(point, holder, point)
end

local function IsLocked(key)
	return Settings()[key].locked ~= false
end

local function ApplyLock(header)
	header.holder:EnableMouse(not IsLocked(header.key))
	header.holder:RefreshDragState()
end

local function BuildHeader(key)
	local kind = KINDS[key]
	local config = Settings()[key]
	local holder = CreateFrame('Frame', kind.frameName, UIParent)
	holder:SetFrameStrata('HIGH')
	holder:SetClampedToScreen(true)

	local container = CreateFrame('AuraContainer', nil, UIParent, 'CustomAuraContainerTemplate')
	container:SetFrameStrata('MEDIUM')
	container:SetSize(1, 1)
	container._buiSkipMouseWalk = true

	local header = { key = key, kind = kind, holder = holder, container = container, parts = {}, buttons = {} }
	headers[key] = header

	local function Initialize(button)
		xpcall(BuildButton, geterrorhandler(), header, button)
	end
	container:AddAuraGroup(GROUP_KEY, kind.filter, {
		maxFrameCount = config.perRow * config.rows,
		initializeFrame = Initialize,
		sortMethod = SortMethod(config),
		sortDirection = SortDirection(config),
		layout = ElementLayout(config),
	})
	if kind.enchants then
		container:AddItemEnchantment(AuraContainerItemEnchantmentSlot.MainHand, { initializeFrame = Initialize, hidePermanent = true })
		container:AddItemEnchantment(AuraContainerItemEnchantmentSlot.OffHand, { initializeFrame = Initialize, hidePermanent = true })
	end

	BUI.Dragging.MakeDraggable(holder, {
		skipClickThrough = true,
		showHint = true,
		showUnlockedBg = true,
		hintText = kind.hint,
		isLocked = function() return IsLocked(key) end,
		onRightClick = function()
			Settings()[key].locked = true
			BuffFrames.Refresh()
		end,
		onPositionChanged = function() BUI.Anchor.SaveDrop(holder, Settings()[key]) end,
	})

	ApplyLayout(header)
	container:SetUnit('player')
	container:SetEnabled(true)
end

local function SetBlizzardHidden(hidden)
	for _, name in ipairs(BLIZZARD_FRAMES) do
		local frame = _G[name]
		if frame then frame:SetRolesets(hidden and HIDDEN_ROLESET or BLIZZARD_ROLESET) end
	end
end

function BuffFrames.Refresh()
	if not built then return end
	local enabled = Enabled()
	SetBlizzardHidden(enabled)
	for _, key in ipairs(KIND_ORDER) do
		local header = headers[key]
		local shown = enabled and Settings()[key].enabled ~= false
		header.container:SetEnabled(shown)
		header.container:SetShown(shown)
		header.holder:SetShown(shown)
		if shown then
			ApplyLayout(header)
			ApplyLock(header)
		end
	end
	RestyleButtons()
end

local function Build()
	if built or not Enabled() then return end
	built = true
	for _, key in ipairs(KIND_ORDER) do BuildHeader(key) end
	BuffFrames.Refresh()
	BUI.Anchor.RegisterCallback('BuffFrames', function()
		if not built or InCombatLockdown() then return end
		for _, header in pairs(headers) do
			if header.holder:IsShown() then BUI.Anchor.ApplyPosition(header.holder, Settings()[header.key]) end
		end
	end)
	BUI.Tools.OnAuraQueriesUnblocked(function()
		if restylePending then RestyleButtons() end
	end, 'Buff frames restyle')
end

Events:Once('PLAYER_ENTERING_WORLD', 'BuffFrames', Build)

BUI.RegisterModuleControl('buffFrames', function(enabled)
	if enabled and not built then
		Build()
	else
		BuffFrames.Refresh()
	end
end)
