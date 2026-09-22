local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Util.AuraContainerEngine')

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

local function DefaultSortDirection()
	local enum = AuraContainerSortDirection
	if type(enum) ~= 'table' then return nil end
	if enum.Ascending ~= nil then return enum.Ascending end
	if enum.Descending ~= nil then return enum.Descending end
	for _, value in pairs(enum) do return value end
end

function Engine.ResolveSortMethod(key)
	local enum = AuraContainerSortMethod
	if not enum then return nil end
	for choiceIndex = 1, #SORT_CHOICES do
		local choice = SORT_CHOICES[choiceIndex]
		if choice.key == key then
			local value = enum[choice.enumKey]
			if value ~= nil then return value end
			break
		end
	end
	return enum.Default
end

function Engine.SortMethodItems()
	local enum = AuraContainerSortMethod
	local items = {}
	if enum then
		for choiceIndex = 1, #SORT_CHOICES do
			local choice = SORT_CHOICES[choiceIndex]
			if enum[choice.enumKey] ~= nil then
				items[#items + 1] = { value = choice.key, text = choice.label }
			end
		end
	end
	return items
end

local function CallMethod(object, names, ...)
	for nameIndex = 1, #names do
		local method = object[names[nameIndex]]
		if method then
			method(object, ...)
			return true
		end
	end
	return false
end

local FLOW_ANCHOR    = { 'SetFlowLayoutAnchorPoint',     'SetAuraLayoutAnchorPoint' }
local FLOW_GROWTH    = { 'SetFlowLayoutGrowthDirection', 'SetAuraLayoutGrowthDirection' }
local FLOW_PADDING   = { 'SetFlowLayoutPadding',         'SetAuraLayoutPadding' }
local FLOW_LINE_SIZE = { 'SetFlowLayoutMaximumLineSize', 'SetAuraLayoutMaximumLineSize' }

local function FlowDirections(style)
	local FlowDirection = AnchorUtil and AnchorUtil.FlowDirection
	if not FlowDirection then return nil end
	local horizontal = style.growX == 'RIGHT' and FlowDirection.Right or FlowDirection.Left
	local vertical = style.growY == 'UP' and FlowDirection.Up or FlowDirection.Down
	return horizontal, vertical
end

local function ApplyLayout(container, style)
	local anchor = Engine.GrowthToAnchor(style.growX, style.growY)
	CallMethod(container, FLOW_ANCHOR, anchor)
	local horizontal, vertical = FlowDirections(style)
	if horizontal then CallMethod(container, FLOW_GROWTH, horizontal, vertical) end
	local gap = Pixel.Scale(style.gap)
	CallMethod(container, FLOW_PADDING, gap, gap, gap, gap)
	local lineSize = style.perRow * style.size + (style.perRow - 1) * style.gap + 0.4
	CallMethod(container, FLOW_LINE_SIZE, Pixel.Scale(lineSize))
end

function Engine.ApplyFlowLayout(container, style)
	ApplyLayout(container, style)
end

local buttonData = setmetatable({}, { __mode = 'k' })
local restyleQueue = {}

local captureButtons = setmetatable({}, { __mode = 'k' })
local captureArmed = false

local function CaptureSpell(container, buttonInfo)
	local unit = container._buiUnit
	if not unit then return end
	if InCombatLockdown() or BUI.Tools.ShouldAurasBeSecret() or BUI.Tools.AuraQueriesBlocked() then return end
	local fileID = buttonInfo.icon and buttonInfo.icon:GetTexture()
	if type(fileID) ~= 'number' then return end
	local polarity = container._buiIsDebuff and 'HARMFUL' or 'HELPFUL'
	local filter = container._buiIsDebuff and 'HARMFUL|INCLUDE_NAME_PLATE_ONLY' or 'HELPFUL'
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

local function SetCaptureArmed(armed)
	if armed == captureArmed then return end
	if BUI.Tools.ShouldAurasBeSecret() then return end
	captureArmed = armed
	for button in pairs(captureButtons) do
		if button.SetMouseClickEnabled then
			button:SetMouseClickEnabled(armed)
		end
	end
end

local function OnModifierChanged(key, down)
	if key ~= 'LSHIFT' and key ~= 'RSHIFT' then return end
	SetCaptureArmed(down == 1 and not InCombatLockdown())
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
	if button.SetPropagateMouseMotion then button:SetPropagateMouseMotion(true) end
end

local function Retired(buttonInfo)
	local group = buttonInfo.group
	return group ~= nil and not group.active
end

local function AttemptRestyle(container, button)
	local buttonInfo = buttonData[button]
	local style = container._buiStyle
	if not buttonInfo or not style then return end
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

		if button.SetIcon then button:SetIcon(icon) end
		if button.SetDurationCooldown then button:SetDurationCooldown(cooldown) end
		if button.SetApplicationCount then button:SetApplicationCount(count, {}) end

		if container._buiStyle and container._buiStyle.showDispelType and button.AddDispelTypeTexture then
			local dispelOptions = { showWhenHarmful = true }
			local styleEnum = Enum.CustomAuraButtonDispelTypeTextureStyle
			if styleEnum and styleEnum.PreserveAsset then dispelOptions.style = styleEnum.PreserveAsset end
			button:AddDispelTypeTexture(dispel, dispelOptions)
		end

		local capturable = not container._buiNoCapture
		if capturable then
			captureButtons[button] = container
			HookScript(button, 'OnMouseDown', OnButtonMouseDown)
		end
		if button.SetMouseClickEnabled then
			button:SetMouseClickEnabled(capturable and captureArmed or false)
		end

		buttonInfo.created = true
	end
end

local scratchWanted = {}

local function EnsureRuleGroups(container, style, rules, baseFilter, candidates, candidateFingerprint, excludeSuffix)
	local wanted = scratchWanted
	wipe(wanted)

	local fingerprintTail = candidateFingerprint or ''
	if excludeSuffix then fingerprintTail = fingerprintTail .. '~' .. excludeSuffix end
	if (container._buiGeneration or 0) > 0 then fingerprintTail = fingerprintTail .. '@' .. container._buiGeneration end

	local pinIDs = candidates and candidates.pinSpellIDs
	if pinIDs then
		wanted['pin#' .. fingerprintTail] = { index = 0, filter = baseFilter, cand = { includeSpellIDs = pinIDs }, pinned = true }
		local rest = {}
		for key, value in pairs(candidates) do
			if key ~= 'pinSpellIDs' then rest[key] = value end
		end
		candidates = next(rest) and rest or nil
	end

	if candidates and candidates.includeSpellIDs then
		wanted['wl#' .. fingerprintTail] = { index = 1, filter = baseFilter, cand = candidates }
	else
		local claimedTokens, claimedFlagNames, claimedFlagValues
		for ruleIndex = 1, #rules do
			local rule = AR.BY_ID[rules[ruleIndex]]
			if rule then
				local cascade = ''
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
								cascade = cascade .. '~' .. flag
							end
						end
					end
					if rule.engineCandidates then
						for key, value in pairs(rule.engineCandidates) do candidateFilters[key] = value end
					end
				end
				local filter = rule.engineFilter or baseFilter
				if claimedTokens then
					for tokenIndex = 1, #claimedTokens do
						local token = claimedTokens[tokenIndex]
						if not filter:find(token, 1, true) then
							filter = filter .. '|!' .. token
							cascade = cascade .. '!' .. token
						end
					end
				end
				wanted[rule.id .. cascade .. '#' .. fingerprintTail] = {
					index = ruleIndex,
					filter = filter,
					cand = candidateFilters,
				}
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

	if excludeSuffix then
		for _, spec in pairs(wanted) do
			if not spec.pinned then spec.filter = spec.filter .. '|' .. excludeSuffix end
		end
	end

	for fingerprint, info in pairs(container._buiGroups) do
		if not wanted[fingerprint] and info.active then
			info.active = false
			if container.SetAuraGroupMaxFrameCount then
				container:SetAuraGroupMaxFrameCount(info.key, 0)
			end
		end
	end

	if not container.AddAuraGroup then return end

	local sortMethod = style.sortMethod
	if sortMethod == nil and AuraContainerSortMethod then
		sortMethod = AuraContainerSortMethod.Default
	end
	local sortDirection = DefaultSortDirection()

	for fingerprint, spec in pairs(wanted) do
		local layout = {
			elementWidth = style.size, elementHeight = style.size,
			elementSpacing = style.gap, lineSpacing = style.rowGap or style.gap,
			layoutIndex = spec.index,
		}
		local info = container._buiGroups[fingerprint]
		if info then
			if not info.active then
				info.active = true
				if container.SetAuraGroupMaxFrameCount then
					container:SetAuraGroupMaxFrameCount(info.key, style.max)
				end
			end
			if container.SetAuraGroupLayout then
				container:SetAuraGroupLayout(info.key, layout)
			end
			if sortMethod ~= nil and sortDirection ~= nil and container.SetAuraGroupSortMethod then
				container:SetAuraGroupSortMethod(info.key, sortMethod, sortDirection)
			end
		else
			container._buiGroupSeq = (container._buiGroupSeq or 0) + 1
			local key = 'bui' .. container._buiGroupSeq
			local groupInfo = { key = key, active = true }
			local groupOptions = {
				maxFrameCount = style.max,
				initializeFrame = BUI.Prof.Wrap('aura#initializeFrame', MakeInitializer(container, groupInfo)),
				candidateFilters = spec.cand,
				layout = layout,
			}
			if sortMethod ~= nil then
				groupOptions.sortMethod = sortMethod
			end
			if sortDirection ~= nil then
				groupOptions.sortDirection = sortDirection
			end
			container:AddAuraGroup(key, spec.filter, groupOptions)
			container._buiGroups[fingerprint] = groupInfo
		end
	end
end

function Engine.NewContainer(parent, isDebuff, levelOffset)
	local container = CreateFrame('AuraContainer', nil, parent, 'CustomAuraContainerTemplate')
	container:SetFrameLevel(parent:GetFrameLevel() + (levelOffset or 10))
	container:SetSize(1, 1)
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
	if not Engine.Available then return end
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
			if driver.group and container.SetAuraGroupMaxFrameCount then
				container:SetAuraGroupMaxFrameCount(driver.group, 0)
			end
			driver.groupsBySet = driver.groupsBySet or {}
			entry = driver.groupsBySet[spellSet]
			if entry and container.SetAuraGroupMaxFrameCount then
				container:SetAuraGroupMaxFrameCount(entry.key, 1)
			end
		end
		if entry then
			if container.SetAuraGroupLayout then
				container:SetAuraGroupLayout(entry.key, layout)
			end
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
			if container.AddAuraGroup then
				container:AddAuraGroup(key, 'HELPFUL', {
					maxFrameCount = 1,
					initializeFrame = function(button)
						buttons[#buttons + 1] = button
						button:SetSize(driver.w, driver.h)
						driver.init(driver, button)
						if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
						if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
					end,
					candidateFilters = { includeSpellIDs = spellSet },
					layout = layout,
				})
			end
			driver.groupsBySet = driver.groupsBySet or {}
			driver.groupsBySet[spellSet] = entry
		end
		driver.entry = entry
		driver.group = entry.key
		driver.spellSet = spellSet
		driver.stamp = stamp
		driver.bound = false
		if container.UpdateAllAuras then container:UpdateAllAuras() end
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

ConfigureContainer = function(container, args, forced)
	local style = args[1]
	container._buiLastConfig = args
	local signature = StyleSignature(style)
	local styleChanged = forced or signature ~= container._buiStyleSig
	container._buiStyleSig = signature
	container._buiStyle = style
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

	ApplyLayout(container, style)
	EnsureRuleGroups(container, style, args[2], args[3], args[4], args[5], args[6])
	container._buiGUID = nil
	if regenerated and container._buiUnit and container.UpdateAllAuras then container:UpdateAllAuras() end

	for _, button in ipairs(container._buiButtons) do
		AttemptRestyle(container, button)
	end
end

function Engine.Configure(container, style, rules, baseFilter, candidates, candidateFingerprint, excludeSuffix)
	ConfigureContainer(container, { style, rules, baseFilter, candidates, candidateFingerprint, excludeSuffix }, false)
end

function Engine.BindUnit(container, unit)
	if not unit then
		container._buiUnit = nil
		container._buiGUID = nil
		if container._buiEnabled ~= false and container.SetEnabled then
			container._buiEnabled = false
			container:SetEnabled(false)
		end
		return
	end
	local changed = false
	if container._buiEnabled ~= true and container.SetEnabled then
		container._buiEnabled = true
		container:SetEnabled(true)
		changed = true
	end
	if container._buiUnit ~= unit then
		container._buiUnit = unit
		if container.SetUnit then container:SetUnit(unit) end
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
	if changed and container.UpdateAllAuras then container:UpdateAllAuras() end
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

if Engine.Available then
	BUI.Events:Register('PLAYER_REGEN_ENABLED', 'AuraEngine.RestyleDrain', function() BUI.Events:AfterCombatSettled(DrainRestyleQueue, 'AuraEngine.RestyleDrain') end)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'AuraEngine.RestyleDrain', DrainRestyleQueue)
	BUI.Events:Register('MODIFIER_STATE_CHANGED', 'AuraEngine.Capture', OnModifierChanged)
	BUI.Events:Register('PLAYER_REGEN_DISABLED', 'AuraEngine.Capture', function()
		SetCaptureArmed(false)
	end)
	BUI.Events:Register('PLAYER_REGEN_ENABLED', 'AuraEngine.Capture', function()
		SetCaptureArmed(IsShiftKeyDown())
	end)
end

