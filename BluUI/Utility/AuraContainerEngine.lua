local _, BUI = ...

local Pixel = BUI.Pixel
local AR    = BUI.AuraRules

local pairs, ipairs = pairs, ipairs
local select = select
local tsort, tconcat = table.sort, table.concat
local floor = math.floor

local CreateFrame      = CreateFrame
local UnitGUID         = UnitGUID
local GetTime          = GetTime
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown   = IsShiftKeyDown
local IsSecret         = issecretvalue
local CanAccess        = canaccessvalue

local WHITE8X8 = [[Interface\Buttons\WHITE8X8]]

local Engine = {}
BUI.AuraEngine = Engine

Engine.Available = type(AuraContainerSortMethod) == 'table' and C_Secrets ~= nil

local DISPEL_TOKENS = { 'Magic', 'Curse', 'Disease', 'Poison', 'Bleed' }
local DISPEL_COLOR_KEY = {
	Magic   = 'dispel_magic',
	Curse   = 'dispel_curse',
	Disease = 'dispel_disease',
	Poison  = 'dispel_poison',
	Bleed   = 'dispel_bleed',
}
local DISPEL_FALLBACK = {
	Magic   = { 0.20, 0.60, 1.00 },
	Curse   = { 0.60, 0.00, 1.00 },
	Disease = { 0.60, 0.40, 0.00 },
	Poison  = { 0.00, 0.60, 0.00 },
	Bleed   = { 1.00, 0.20, 0.20 },
}

function Engine.DispelColorRGB(token)
	local fallback = DISPEL_FALLBACK[token]
	if not fallback then return 1, 1, 1 end
	local db = BUI.GetDB()
	local color = db and db.colors and db.colors[DISPEL_COLOR_KEY[token]]
	if not color then return fallback[1], fallback[2], fallback[3] end
	return color.r or fallback[1], color.g or fallback[2], color.b or fallback[3]
end

function Engine.DispelColorKey(token)
	return DISPEL_COLOR_KEY[token]
end

function Engine.DispelColor(token)
	local red, green, blue = Engine.DispelColorRGB(token)
	return CreateColor(red, green, blue, 1)
end

function Engine.BuildDispelCurve(zeroColor)
	local curve = C_CurveUtil.CreateColorCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	curve:AddPoint(0,  zeroColor)
	curve:AddPoint(1,  Engine.DispelColor('Magic'))
	curve:AddPoint(2,  Engine.DispelColor('Curse'))
	curve:AddPoint(3,  Engine.DispelColor('Disease'))
	curve:AddPoint(4,  Engine.DispelColor('Poison'))
	curve:AddPoint(9,  Engine.DispelColor('Bleed'))
	curve:AddPoint(11, Engine.DispelColor('Bleed'))
	return curve, Engine.DispelPaletteStamp()
end

function Engine.DispelPaletteStamp()
	local parts = {}
	for tokenIndex = 1, #DISPEL_TOKENS do
		local red, green, blue = Engine.DispelColorRGB(DISPEL_TOKENS[tokenIndex])
		parts[tokenIndex] = floor(red * 255) .. ':' .. floor(green * 255) .. ':' .. floor(blue * 255)
	end
	return tconcat(parts, '|')
end

Engine.StackAnchors = {
	TOPLEFT      = { 'TOPLEFT', 1, -1 },
	TOP          = { 'TOP', 0, -1 },
	TOPRIGHT     = { 'TOPRIGHT', -1, -1 },
	LEFT         = { 'LEFT', 1, 0 },
	CENTER       = { 'CENTER', 0, 0 },
	RIGHT        = { 'RIGHT', -1, 0 },
	BOTTOMLEFT   = { 'BOTTOMLEFT', 1, 1 },
	BOTTOM       = { 'BOTTOM', 0, 1 },
	BOTTOMRIGHT  = { 'BOTTOMRIGHT', -1, 1 },
}

function Engine.GrowthToAnchor(growX, growY)
	local vertical = growY == 'UP' and 'BOTTOM' or 'TOP'
	local horizontal = growX == 'RIGHT' and 'LEFT' or 'RIGHT'
	return vertical .. horizontal
end

function Engine.SortedKeys(map)
	local keys = {}
	for key in pairs(map) do keys[#keys + 1] = key end
	tsort(keys)
	return tconcat(keys, ',')
end

local SORT_CHOICES = {
	{ key = 'default',    enumKey = 'Default',            label = 'Priority Order' },
	{ key = 'expiration', enumKey = 'Expiration',         label = 'Time Remaining' },
	{ key = 'applied',    enumKey = 'AuraInstanceIDOnly', label = 'Order Applied' },
	{ key = 'name',       enumKey = 'Name',               label = 'Spell Name' },
}

function Engine.ResolveSortMethod(key)
	for choiceIndex = 1, #SORT_CHOICES do
		local choice = SORT_CHOICES[choiceIndex]
		if choice.key == key then return AuraContainerSortMethod[choice.enumKey] end
	end
	return AuraContainerSortMethod.Default
end

function Engine.SortMethodItems()
	local items = {}
	for choiceIndex = 1, #SORT_CHOICES do
		local choice = SORT_CHOICES[choiceIndex]
		items[choiceIndex] = { value = choice.key, text = choice.label }
	end
	return items
end

local function ApplyLayout(container, style)
	local FlowDirection = AnchorUtil.FlowDirection
	container:SetFlowLayoutAnchorPoint(Engine.GrowthToAnchor(style.growX, style.growY))
	container:SetFlowLayoutGrowthDirection(
		style.growX == 'RIGHT' and FlowDirection.Right or FlowDirection.Left,
		style.growY == 'UP' and FlowDirection.Up or FlowDirection.Down)
	local padding = Pixel.Scale(style.padding or style.gap)
	container:SetFlowLayoutPadding(padding, padding, padding, padding)
	local lineSize = style.perRow * style.size + (style.perRow - 1) * style.gap + 0.4
	container:SetFlowLayoutMaximumLineSize(Pixel.Scale(lineSize))
end

function Engine.ApplyFlowLayout(container, style)
	ApplyLayout(container, style)
end

local buttonData = setmetatable({}, { __mode = 'k' })
local restyleQueue = {}

local captureButtons = setmetatable({}, { __mode = 'k' })
local armedButton
local disarmPending = false

local function CaptureSpell(container, buttonInfo)
	local unit = container._buiUnit
	if not unit then return end
	if InCombatLockdown() or BUI.Tools.ShouldAurasBeSecret() or BUI.Tools.AuraQueriesBlocked() then return end
	local fileID = buttonInfo.icon and buttonInfo.icon:GetTexture()
	if type(fileID) ~= 'number' then return end
	local harmful = buttonInfo.group.harmful
	local polarity = harmful and 'HARMFUL' or 'HELPFUL'
	local filter = harmful and 'HARMFUL|INCLUDE_NAME_PLATE_ONLY' or 'HELPFUL'
	local auras = C_UnitAuras.GetUnitAuras(unit, filter, 40, 0, 0)
	if not auras then return end
	for auraIndex = 1, #auras do
		local aura = auras[auraIndex]
		local icon, spellID = aura.icon, aura.spellId
		if CanAccess(icon) and icon == fileID and CanAccess(spellID) and type(spellID) == 'number' then
			local scope = container._buiScope or 'unit'
			BUI.AuraBlacklist.UserAdd(scope, polarity, spellID)
			BUI.AuraBlacklist.RefreshConsumers(scope)
			local name = C_Spell.GetSpellName(spellID)
			print(BUI.C.CHAT_PREFIX .. ('Blacklisted %s.'):format(name or ('spell ' .. spellID)))
			return
		end
	end
end

local function OnButtonMouseDown(button, mouseButton)
	if mouseButton ~= 'RightButton' or not IsShiftKeyDown() then return end
	local container = captureButtons[button]
	local buttonInfo = buttonData[button]
	if container and buttonInfo then CaptureSpell(container, buttonInfo) end
end

local function DisarmCapture()
	if not armedButton then return end
	if BUI.Tools.ShouldAurasBeSecret() then
		disarmPending = true
		return
	end
	armedButton:SetMouseClickEnabled(false)
	armedButton = nil
	disarmPending = false
end

local function ArmCapture()
	if InCombatLockdown() or BUI.Tools.ShouldAurasBeSecret() then return end
	local pointed
	for button in pairs(captureButtons) do
		if button:IsVisible() and button:IsMouseOver() then
			pointed = button
			break
		end
	end
	if pointed == armedButton then return end
	DisarmCapture()
	if pointed then
		pointed:SetMouseClickEnabled(true)
		armedButton = pointed
	end
end

local function OnModifierChanged(key, down)
	if key ~= 'LSHIFT' and key ~= 'RSHIFT' then return end
	if down == 1 then ArmCapture() else DisarmCapture() end
end

local function FinishPendingDisarm()
	if disarmPending then DisarmCapture() end
end

local function ApplyCooldownFont(cooldown, size, font, flags)
	for _, child in pairs({ cooldown:GetChildren() }) do
		for regionIndex = 1, select('#', child:GetRegions()) do
			local region = select(regionIndex, child:GetRegions())
			if region and region:IsObjectType('FontString') then
				Pixel.ApplyFont(region, size, font, flags)
			end
		end
	end
	for regionIndex = 1, select('#', cooldown:GetRegions()) do
		local region = select(regionIndex, cooldown:GetRegions())
		if region and region:IsObjectType('FontString') then
			Pixel.ApplyFont(region, size, font, flags)
		end
	end
end

local function RestyleButton(container, button, buttonInfo, style)
	local size = Pixel.Scale(style.size)
	button:SetSize(size, size)

	local edge = Pixel.PixelSize(1)
	buttonInfo.icon:ClearAllPoints()
	buttonInfo.icon:SetPoint('TOPLEFT', edge, -edge)
	buttonInfo.icon:SetPoint('BOTTOMRIGHT', -edge, edge)

	buttonInfo.base:SetVertexColor(unpack(style.baseColor))

	if style.showStack == false then
		buttonInfo.count:Hide()
	else
		Pixel.ApplyFont(buttonInfo.count, style.stackSize, style.font, style.fontFlags)
		local posData = Engine.StackAnchors[style.stackPos] or Engine.StackAnchors.BOTTOMRIGHT
		buttonInfo.count:ClearAllPoints()
		buttonInfo.count:SetPoint(posData[1], button, posData[1], posData[2], posData[3])
		buttonInfo.count:Show()
	end

	buttonInfo.cooldown:SetReverse(style.reverseSwipe and true or false)
	buttonInfo.cooldown:SetHideCountdownNumbers(style.showCd == false)
	if style.showCd ~= false then
		ApplyCooldownFont(buttonInfo.cooldown, style.cdSize, style.font, style.fontFlags)
	end

	if InCombatLockdown() then
		buttonInfo.mousePending = true
		restyleQueue[button] = container
		return
	end
	buttonInfo.mousePending = nil
	button:SetMouseMotionEnabled(style.showTooltips and true or false)
	button:SetPropagateMouseMotion(true)
end

local function Retired(buttonInfo)
	local group = buttonInfo.group
	return group ~= nil and not group.active
end

local function AttemptRestyle(container, button)
	local buttonInfo = buttonData[button]
	if not buttonInfo then return end
	local style = buttonInfo.group.style
	if Retired(buttonInfo) then
		restyleQueue[button] = nil
		return
	end
	if buttonInfo.stamp == container._buiStyleStamp and not buttonInfo.mousePending then return end

	if buttonInfo.created and BUI.Tools.ShouldAurasBeSecret() then
		restyleQueue[button] = container
		return
	end

	RestyleButton(container, button, buttonInfo, style)
	buttonInfo.stamp = container._buiStyleStamp
	restyleQueue[button] = buttonInfo.mousePending and container or nil
end

local recreateQueue = {}
local ConfigureContainer

local function DrainRestyleQueue()
	for container in pairs(recreateQueue) do
		recreateQueue[container] = nil
		local args = container._buiLastConfig
		if args then ConfigureContainer(container, args, true) end
	end
	for button, container in pairs(restyleQueue) do
		AttemptRestyle(container, button)
	end
end

local function MakeInitializer(container, groupInfo)
	return function(button)
		local buttonInfo = { group = groupInfo }
		buttonData[button] = buttonInfo
		container._buiButtons[#container._buiButtons + 1] = button

		local base = button:CreateTexture(nil, 'BACKGROUND', nil, 0)
		base:SetAllPoints()
		base:SetTexture(WHITE8X8)
		buttonInfo.base = base

		local dispel = button:CreateTexture(nil, 'BACKGROUND', nil, 1)
		dispel:SetAllPoints()
		dispel:SetTexture(WHITE8X8)
		dispel:Hide()
		buttonInfo.dispel = dispel

		local icon = button:CreateTexture(nil, 'ARTWORK')
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		local edge = Pixel.PixelSize(1)
		icon:SetPoint('TOPLEFT', edge, -edge)
		icon:SetPoint('BOTTOMRIGHT', -edge, edge)
		buttonInfo.icon = icon

		local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
		cooldown:SetAllPoints()
		cooldown:SetDrawEdge(false)
		cooldown:SetCountdownAbbrevThreshold(20)
		buttonInfo.cooldown = cooldown

		local countHost = CreateFrame('Frame', nil, button)
		countHost:SetAllPoints()
		countHost:SetFrameLevel(cooldown:GetFrameLevel() + 1)
		countHost:EnableMouse(false)
		local count = countHost:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
		buttonInfo.count = count

		container._buiStyleStamp = container._buiStyleStamp or 1
		xpcall(AttemptRestyle, geterrorhandler(), container, button)

		button:SetIcon(icon)
		button:SetDurationCooldown(cooldown)
		button:SetApplicationCount(count, {})

		if groupInfo.style.showDispelType then
			button:AddDispelTypeTexture(dispel, { showWhenHarmful = true, style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset })
		end

		captureButtons[button] = container
		button:HookScript('OnMouseDown', BUI.Profiler.Wrap('AuraContainerEngine button OnMouseDown', OnButtonMouseDown))
		button:SetMouseClickEnabled(false)

		buttonInfo.created = true
	end
end

local scratchWanted = {}

local NAMEPLATE_ONLY_TOKEN = 'INCLUDE_NAME_PLATE_ONLY'

local function HasFilterToken(filter, token)
	return ('|' .. filter .. '|'):find('|' .. token .. '|', 1, true) ~= nil
end

local SET_LAYOUT_STRIDE = 100

local function FilterClaimed(filter, claimedTokens)
	if not claimedTokens then return false end
	for tokenIndex = 1, #claimedTokens do
		if HasFilterToken(filter, claimedTokens[tokenIndex]) then return true end
	end
	return false
end

local function CollectRuleGroups(wanted, container, setIndex, style, rules, baseFilter, candidates, candidateFingerprint, excludeSuffix)
	local harmful = HasFilterToken(baseFilter, 'HARMFUL')
	local slotPrefix = harmful and 'D' or 'B'
	local slotSuffix = (container._buiGeneration or 0) > 0 and ('@' .. container._buiGeneration) or ''
	local layoutBase = (setIndex - 1) * SET_LAYOUT_STRIDE
	local candidateSig = candidateFingerprint or ''
	local position = 0

	local function Want(filter, cand, candSig)
		local layoutIndex = layoutBase + position
		position = position + 1
		wanted[slotPrefix .. layoutIndex .. slotSuffix] = { index = layoutIndex, filter = filter, cand = cand, candSig = candSig, style = style, harmful = harmful }
	end

	local function Suffixed(filter)
		return excludeSuffix and (filter .. '|' .. excludeSuffix) or filter
	end

	local pinIDs = candidates and candidates.pinSpellIDs
	if pinIDs then
		Want(baseFilter, { includeSpellIDs = pinIDs }, 'pin/' .. candidateSig)
		local rest = {}
		for key, value in pairs(candidates) do
			if key ~= 'pinSpellIDs' then rest[key] = value end
		end
		candidates = next(rest) and rest or nil
	end

	if candidates and candidates.includeSpellIDs then
		Want(Suffixed(baseFilter), candidates, 'only/' .. candidateSig)
		return
	end

	local claimedTokens, claimedFlagNames, claimedFlagValues
	local keepNameplateOnly = HasFilterToken(baseFilter, NAMEPLATE_ONLY_TOKEN)
	for ruleIndex = 1, #rules do
		local rule = AR.BY_ID[rules[ruleIndex]]
		if rule and not FilterClaimed(rule.engineFilter or baseFilter, claimedTokens) then
			local flagCascade = ''
			local candidateFilters = candidates
			if rule.engineCandidates or claimedFlagNames then
				candidateFilters = {}
				if candidates then
					for key, value in pairs(candidates) do candidateFilters[key] = value end
				end
				if claimedFlagNames then
					for flagIndex = 1, #claimedFlagNames do
						local flag = claimedFlagNames[flagIndex]
						if rule.engineCandidates == nil or rule.engineCandidates[flag] == nil then
							candidateFilters[flag] = not claimedFlagValues[flag]
							flagCascade = flagCascade .. '~' .. flag
						end
					end
				end
				if rule.engineCandidates then
					for key, value in pairs(rule.engineCandidates) do candidateFilters[key] = value end
				end
			end
			local filter = rule.engineFilter or baseFilter
			if keepNameplateOnly and not HasFilterToken(filter, NAMEPLATE_ONLY_TOKEN) then
				filter = filter .. '|' .. NAMEPLATE_ONLY_TOKEN
			end
			if claimedTokens then
				for tokenIndex = 1, #claimedTokens do
					local token = claimedTokens[tokenIndex]
					if not HasFilterToken(filter, '!' .. token) then filter = filter .. '|!' .. token end
				end
			end
			Want(Suffixed(filter), candidateFilters, rule.id .. flagCascade .. '/' .. candidateSig)
			if rule.engineExcludeToken then
				claimedTokens = claimedTokens or {}
				claimedTokens[#claimedTokens + 1] = rule.engineExcludeToken
			end
			if rule.engineCandidates then
				for flag, value in pairs(rule.engineCandidates) do
					if type(value) == 'boolean' and (claimedFlagValues == nil or claimedFlagValues[flag] == nil) then
						claimedFlagNames = claimedFlagNames or {}
						claimedFlagValues = claimedFlagValues or {}
						claimedFlagNames[#claimedFlagNames + 1] = flag
						claimedFlagValues[flag] = value
					end
				end
			end
		end
	end
end

local function EnsureRuleGroups(container, sets)
	local wanted = scratchWanted
	wipe(wanted)
	for setIndex, args in ipairs(sets) do
		CollectRuleGroups(wanted, container, setIndex, unpack(args, 1, 6))
	end

	for slot, info in pairs(container._buiGroups) do
		if not wanted[slot] and info.active then
			info.active = false
			info.max = 0
			container:SetAuraGroupMaxFrameCount(info.key, 0)
		end
	end

	local sortDirection = AuraContainerSortDirection.Normal

	for slot, spec in pairs(wanted) do
		local style = spec.style
		local max = style.max
		local layout = {
			elementWidth = style.size, elementHeight = style.size,
			elementSpacing = style.gap, lineSpacing = style.rowGap or style.gap,
			layoutIndex = spec.index,
		}
		local info = container._buiGroups[slot]
		if info then
			info.active = true
			info.style = style
			if info.filter ~= spec.filter then
				info.filter = spec.filter
				container:SetAuraGroupFilterString(info.key, spec.filter)
			end
			if info.candSig ~= spec.candSig then
				info.candSig = spec.candSig
				container:SetAuraGroupCandidateFilters(info.key, spec.cand)
			end
			if info.max ~= max then
				info.max = max
				container:SetAuraGroupMaxFrameCount(info.key, max)
			end
			container:SetAuraGroupLayout(info.key, layout)
			container:SetAuraGroupSortMethod(info.key, style.sortMethod, sortDirection)
		else
			container._buiGroupSeq = (container._buiGroupSeq or 0) + 1
			info = {
				key = 'bui' .. container._buiGroupSeq, active = true, max = max, style = style,
				harmful = spec.harmful, filter = spec.filter, candSig = spec.candSig,
			}
			container:AddAuraGroup(info.key, spec.filter, {
				maxFrameCount = max,
				initializeFrame = MakeInitializer(container, info),
				candidateFilters = spec.cand,
				layout = layout,
				sortMethod = style.sortMethod,
				sortDirection = sortDirection,
			})
			container._buiGroups[slot] = info
		end
	end
end

function Engine.NewContainer(parent, isDebuff, levelOffset)
	local container = CreateFrame('AuraContainer', nil, parent, 'CustomAuraContainerTemplate')
	container:SetFrameLevel(parent:GetFrameLevel() + (levelOffset or 10))
	container:SetSize(1, 1)
	container._buiAuraContainer = true
	container._buiIsDebuff = isDebuff
	container._buiGroups = {}
	container._buiButtons = {}
	container._buiStyleStamp = 1
	return container
end

function Engine.NewAuraDriver(parent)
	return { parent = parent, seq = 0 }
end

Engine.NewAuraCooldownDriver = Engine.NewAuraDriver

local function SyncButtonDriver(driver, wanted, spellSet, stamp, width, height, init, style)
	if not wanted then
		if driver.container then
			driver.container:Hide()
			Engine.BindUnit(driver.container, nil)
			driver.bound = false
		end
		return
	end
	driver.init, driver.style = init, style
	if not driver.container or driver.stamp ~= stamp then
		if BUI.Tools.ShouldAurasBeSecret() or BUI.Tools.AuraQueriesBlocked() then
			if driver.container and not driver.bound then
				driver.container:Show()
				Engine.BindUnit(driver.container, 'player')
				driver.bound = true
			end
			return
		end
		if not driver.container then
			driver.container = Engine.NewContainer(driver.parent, false, 2)
			driver.container:SetPoint('CENTER', driver.parent, 'CENTER')
		end
		local container = driver.container
		driver.w, driver.h = width, height
		local layout = { elementWidth = width, elementHeight = height, layoutIndex = 1 }
		local entry
		if driver.spellSet == spellSet then
			entry = driver.entry
		else
			if driver.group then container:SetAuraGroupMaxFrameCount(driver.group, 0) end
			driver.groupsBySet = driver.groupsBySet or {}
			entry = driver.groupsBySet[spellSet]
			if entry then container:SetAuraGroupMaxFrameCount(entry.key, 1) end
		end
		if entry then
			container:SetAuraGroupLayout(entry.key, layout)
			for buttonIndex = 1, #entry.buttons do
				local button = entry.buttons[buttonIndex]
				button:SetSize(width, height)
				init(driver, button)
			end
		else
			driver.seq = driver.seq + 1
			local key = 'acd' .. driver.seq
			local buttons = {}
			entry = { key = key, buttons = buttons }
			container:AddAuraGroup(key, 'HELPFUL', {
				maxFrameCount = 1,
				initializeFrame = function(button)
					buttons[#buttons + 1] = button
					button:SetSize(driver.w, driver.h)
					driver.init(driver, button)
					button:SetMouseClickEnabled(false)
					button:SetMouseMotionEnabled(false)
				end,
				candidateFilters = { includeSpellIDs = spellSet },
				layout = layout,
			})
			driver.groupsBySet = driver.groupsBySet or {}
			driver.groupsBySet[spellSet] = entry
		end
		driver.entry = entry
		driver.group = entry.key
		driver.spellSet = spellSet
		driver.stamp = stamp
		driver.bound = false
		container:UpdateAllAuras()
	end
	if not driver.bound then
		driver.container:Show()
		Engine.BindUnit(driver.container, 'player')
		driver.bound = true
	end
end

local function InitCooldownButton(driver, button)
	local cooldown = button._buiDriverCd
	if not cooldown then
		cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
		cooldown:SetAllPoints(button)
		button._buiDriverCd = cooldown
		if button.SetDurationCooldown then button:SetDurationCooldown(cooldown) end
	end
	driver.style(cooldown, button)
end

local function InitTextButton(driver, button)
	local text = button._buiDriverText
	if not text then
		text = button:CreateFontString(nil, 'OVERLAY')
		text:SetPoint('CENTER', button, 'CENTER', 0, 0)
		button._buiDriverText = text
	end
	driver.style(text, button)
end

local function InitStackButton(driver, button)
	local text = button._buiDriverText
	if text then
		driver.style(text, button)
		return
	end
	text = button:CreateFontString(nil, 'OVERLAY')
	text:SetPoint('CENTER', button, 'CENTER', 0, 0)
	button._buiDriverText = text
	driver.style(text, button)
	if button.SetApplicationCount then button:SetApplicationCount(text, {}) end
end

function Engine.SyncAuraCooldownDriver(driver, wanted, spellSet, stamp, width, height, styleCooldown)
	SyncButtonDriver(driver, wanted, spellSet, stamp, width, height, InitCooldownButton, styleCooldown)
end

function Engine.SyncAuraTextDriver(driver, wanted, spellSet, stamp, width, height, styleText)
	SyncButtonDriver(driver, wanted, spellSet, stamp, width, height, InitTextButton, styleText)
end

function Engine.SyncAuraStackDriver(driver, wanted, spellSet, stamp, width, height, styleText)
	SyncButtonDriver(driver, wanted, spellSet, stamp, width, height, InitStackButton, styleText)
end

local STYLE_SIGNATURE_KEYS = {
	'size', 'gap', 'rowGap', 'perRow', 'max', 'growX', 'growY', 'sortMethod', 'showDispelType', 'showStack',
	'stackSize', 'stackPos', 'showCd', 'cdSize', 'reverseSwipe', 'showTooltips', 'font', 'fontFlags',
}

local signatureParts = {}
local function StyleSignature(style)
	wipe(signatureParts)
	for index = 1, #STYLE_SIGNATURE_KEYS do
		signatureParts[index] = tostring(style[STYLE_SIGNATURE_KEYS[index]])
	end
	local baseColor = style.baseColor
	if baseColor then
		signatureParts[#signatureParts + 1] = ('%.2f,%.2f,%.2f,%.2f'):format(baseColor[1] or 0, baseColor[2] or 0, baseColor[3] or 0, baseColor[4] or 1)
	end
	return table.concat(signatureParts, '|')
end

local function RestyleRestricted()
	return BUI.Tools.ShouldAurasBeSecret() or BUI.Tools.AuraQueriesBlocked()
end

local function HasLiveButtons(container)
	local buttons = container._buiButtons
	for index = 1, #buttons do
		local buttonInfo = buttonData[buttons[index]]
		if buttonInfo and buttonInfo.created and not Retired(buttonInfo) then return true end
	end
	return false
end

local nest = {}
local worldReady = false

local HatchNext
HatchNext = BUI.Dispatcher.New(function()
	local container = table.remove(nest, 1)
	if not container then return end
	EnsureRuleGroups(container, container._buiLastConfig)
	container._buiHatched = true
	if container._buiOnHatch then container._buiOnHatch() end
	if container._buiUnit then container:UpdateAllAuras() end
	if nest[1] then HatchNext() end
end, 'AuraEngine.Hatch')

BUI.Events:Once('PLAYER_ENTERING_WORLD', 'AuraEngine.Hatch', function()
	worldReady = true
	if nest[1] then HatchNext() end
end)

local function SetsSignature(sets)
	local parts = {}
	for index, args in ipairs(sets) do parts[index] = StyleSignature(args[1]) end
	return table.concat(parts, '||')
end

ConfigureContainer = function(container, sets, forced)
	container._buiLastConfig = sets
	local signature = SetsSignature(sets)
	local styleChanged = forced or signature ~= container._buiStyleSig
	container._buiStyleSig = signature
	container._buiStyleStamp = container._buiStyleStamp + 1

	local regenerated = false
	if styleChanged and HasLiveButtons(container) and RestyleRestricted() then
		if InCombatLockdown() then
			recreateQueue[container] = true
		else
			container._buiGeneration = (container._buiGeneration or 0) + 1
			regenerated = true
		end
	end

	ApplyLayout(container, sets[1][1])
	if container._buiHatched or (worldReady and not nest[1]) then
		EnsureRuleGroups(container, sets)
		container._buiHatched = true
	elseif not container._buiNested then
		container._buiNested = true
		nest[#nest + 1] = container
	end
	container._buiGUID = nil
	if regenerated and container._buiUnit then container:UpdateAllAuras() end

	for _, button in ipairs(container._buiButtons) do
		AttemptRestyle(container, button)
	end
end

function Engine.Configure(container, style, rules, baseFilter, candidates, candidateFingerprint, excludeSuffix)
	ConfigureContainer(container, { { style, rules, baseFilter, candidates, candidateFingerprint, excludeSuffix } }, false)
end

function Engine.ConfigureSets(container, sets)
	ConfigureContainer(container, sets, false)
end

function Engine.BindUnit(container, unit)
	if not unit then
		container._buiUnit = nil
		container._buiGUID = nil
		if container._buiEnabled ~= false then
			container._buiEnabled = false
			container:SetEnabled(false)
		end
		return
	end
	local changed = false
	if container._buiEnabled ~= true then
		container._buiEnabled = true
		container:SetEnabled(true)
		changed = true
	end
	if container._buiUnit ~= unit then
		container._buiUnit = unit
		container:SetUnit(unit)
		changed = true
	end
	local guid = UnitGUID(unit)
	if guid ~= nil and IsSecret(guid) then
		if container._buiGUID ~= 'secret' then changed = true end
		container._buiGUID = 'secret'
	else
		if guid ~= container._buiGUID then changed = true end
		container._buiGUID = guid
	end
	if changed then container:UpdateAllAuras() end
end

function Engine.RebindUnit(container, unit)
	unit = unit or container._buiUnit
	if not unit then return end
	local now = GetTime()
	if container._buiRebindTime == now then return end
	container._buiRebindTime = now
	Engine.BindUnit(container, nil)
	Engine.BindUnit(container, unit)
	if container:IsShown() then
		container:Hide()
		container:Show()
	end
end

BUI.Events:Register('PLAYER_REGEN_ENABLED', 'AuraEngine.RestyleDrain', function() BUI.Events:AfterCombatSettled(DrainRestyleQueue, 'AuraEngine.RestyleDrain') end)
BUI.Events:Register('PLAYER_ENTERING_WORLD', 'AuraEngine.RestyleDrain', DrainRestyleQueue)
BUI.Events:Register('MODIFIER_STATE_CHANGED', 'AuraEngine.Capture', OnModifierChanged)
BUI.Events:Register('PLAYER_REGEN_DISABLED', 'AuraEngine.Capture', DisarmCapture)
BUI.Tools.OnAuraQueriesUnblocked(FinishPendingDisarm, 'Aura blacklist capture')
