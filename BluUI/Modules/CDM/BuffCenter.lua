local _, BUI = ...

local _G = _G
local sort = table.sort
local wipe = wipe

local CDM = BUI.CDM
local Pixel = BUI.Pixel
local FrameData = CDM.FrameData

local active = false
local visible = {}
local orderLookup = {}
local cachedOpacity = 100
local lastSnap = {}
local lastSnapCount = 0
local lastWidth, lastHeight, lastSpacing, lastVertical
local lastAnchorWidth, lastAnchorHeight, lastAlpha, lastGrowUp
local forceLayout = false
local snapLayout = {}
local snapOrder = {}
local snapCustomOrder = false
local snapKeyed = false

local prefilteredIcons
local prefilteredCount = 0

local function SortByLayout(iconA, iconB)
	return (iconA.layoutIndex or 0) < (iconB.layoutIndex or 0)
end

local function OrderPosition(icon)
	return orderLookup[CDM.GetSortKey(icon) or 0] or 999999
end

local function SortByCustomOrder(iconA, iconB)
	local posA = OrderPosition(iconA)
	local posB = OrderPosition(iconB)
	if posA ~= posB then return posA < posB end
	return (iconA.layoutIndex or 0) < (iconB.layoutIndex or 0)
end

local function SnapshotUnchanged(count, anchor, skinVersion, customOrder)
	if customOrder ~= snapCustomOrder then return false end
	for iconIndex = 1, count do
		local icon = visible[iconIndex]
		if snapLayout[icon] ~= (icon.layoutIndex or 0) then return false end
		if customOrder and snapOrder[icon] ~= OrderPosition(icon) then return false end
		local frameData = FrameData[icon]
		if not frameData or frameData.parked or frameData.anchor ~= anchor or frameData.skinVer ~= skinVersion then return false end
	end
	return true
end

local function RecordSnapshotKeys(count, customOrder)
	wipe(snapLayout)
	wipe(snapOrder)
	for iconIndex = 1, count do
		local icon = visible[iconIndex]
		snapLayout[icon] = icon.layoutIndex or 0
		if customOrder then snapOrder[icon] = OrderPosition(icon) end
	end
	snapCustomOrder = customOrder
	snapKeyed = true
end

local function IsCenterable(icon)
	if not icon:IsShown() then return false end
	local frameData = FrameData[icon]
	return not frameData or not (frameData.hidden or frameData.anchor == UIParent)
end

local function CollectVisible(viewer)
	local count = 0

	for icon in viewer.itemFramePool:EnumerateActive() do
		if IsCenterable(icon) then
			count = count + 1
			visible[count] = icon
		end
	end

	local customList, customCount = CDM.Custom.GetIcons("buffs")
	if customList then
		for customIndex = 1, customCount do
			local icon = customList[customIndex]
			if IsCenterable(icon) then
				count = count + 1
				visible[count] = icon
			end
		end
	end
	for staleIndex = count + 1, #visible do visible[staleIndex] = nil end
	return count
end

local function PlaceIconCentered(icon, anchor, x, y, alpha)
	local frameData = FrameData[icon]
	local left = Pixel.Snap(anchor._layoutW / 2 + x - frameData.sizeW / 2)
	local top = -Pixel.Snap(anchor._layoutH / 2 - y - frameData.sizeH / 2)
	frameData.locking = true
	frameData.anchor = anchor
	local wasParked = frameData.parked
	if wasParked or frameData.posCornerX ~= left or frameData.posCornerY ~= top then
		frameData.selfPoint = 'TOPLEFT'
		frameData.relPoint = 'TOPLEFT'
		frameData.posCornerX = left
		frameData.posCornerY = top
		icon:ClearAllPoints()
		icon:SetPoint('TOPLEFT', anchor, 'TOPLEFT', left, top)
	end
	frameData.parked = nil
	icon:SetAlpha(alpha)
	frameData.locking = false
	if wasParked then CDM.ResumeProcGlow(icon, frameData) end
end

local function PlaceRow(list, iconCount, anchor, vertical, growUp, stepX, stepY, alpha)
	if not vertical then
		local startX = Pixel.Snap(-((iconCount - 1) * stepX) / 2)
		for slotIndex = 1, iconCount do
			PlaceIconCentered(list[slotIndex], anchor, startX + (slotIndex - 1) * stepX, 0, alpha)
		end
	else
		local signedStepY = growUp and stepY or -stepY
		for slotIndex = 1, iconCount do
			PlaceIconCentered(list[slotIndex], anchor, 0, (slotIndex - 1) * signedStepY, alpha)
		end
	end
end

local function StopBuffCentering()
	active = false
end

local function CenterNow()
	if not active then return end

	local viewer = _G[CDM.VIEWERS.buffs]
	if not viewer then return end

	local settings = BUI.GetDB().cdm.buffs
	if not settings.enabled then
		StopBuffCentering()
		return
	end

	local anchor = CDM.Anchors.buffs
	if not anchor then return end

	local visibleCount
	local usedPrefiltered = false
	if prefilteredIcons then
		visibleCount = prefilteredCount
		for iconIndex = 1, visibleCount do visible[iconIndex] = prefilteredIcons[iconIndex] end
		for staleIndex = visibleCount + 1, #visible do visible[staleIndex] = nil end
		prefilteredIcons = nil
		prefilteredCount = 0
		usedPrefiltered = true
	else
		visibleCount = CollectVisible(viewer)
	end

	if visibleCount == 0 then
		if lastSnapCount > 0 then
			lastSnapCount = 0
			forceLayout = false
		end
		anchor:Hide()
		return
	end
	anchor:Show()

	local spacing = Pixel.Scale(settings.spacing)
	local scaledWidth = Pixel.Scale(settings.iconWidth)
	local scaledHeight = Pixel.Scale(settings.iconHeight)
	local vertical = settings.vertical
	anchor._cachedScaledW = scaledWidth
	anchor._cachedScaledH = scaledHeight
	local anchorWidth, anchorHeight = anchor._layoutW, anchor._layoutH
	local alpha = cachedOpacity / 100
	local growUp = settings.rowGrowth == "Up"
	local skinVersion = CDM.state.skinVersion

	local inputsSame = not forceLayout and visibleCount == lastSnapCount
		and scaledWidth == lastWidth and scaledHeight == lastHeight and spacing == lastSpacing and vertical == lastVertical
		and anchorWidth == lastAnchorWidth and anchorHeight == lastAnchorHeight and alpha == lastAlpha and growUp == lastGrowUp

	if not usedPrefiltered then
		local savedOrder = CDM.GetIconOrder(settings)
		local customOrder = savedOrder and #savedOrder > 0 or false
		if customOrder then
			wipe(orderLookup)
			for orderIndex, id in ipairs(savedOrder) do orderLookup[id] = orderIndex end
		end
		if inputsSame and snapKeyed and SnapshotUnchanged(visibleCount, anchor, skinVersion, customOrder) then
			wipe(orderLookup)
			return
		end
		sort(visible, customOrder and SortByCustomOrder or SortByLayout)
		RecordSnapshotKeys(visibleCount, customOrder)
		wipe(orderLookup)
	end

	if inputsSame then
		local same = true
		for iconIndex = 1, visibleCount do
			local icon = visible[iconIndex]
			if icon ~= lastSnap[iconIndex] then same = false break end
			local frameData = FrameData[icon]
			if not frameData or frameData.parked or frameData.anchor ~= anchor or frameData.skinVer ~= skinVersion then same = false break end
		end
		if same then return end
	end
	forceLayout = false

	for iconIndex = 1, visibleCount do
		local icon = visible[iconIndex]
		CDM.HookIconFrame(icon, "buffs")
		local frameData = FrameData[icon]
		local scale = icon:GetScale()
		if scale > 1.01 or scale < 0.99 then
			frameData.locking = true
			icon:SetScale(1)
			frameData.locking = false
		end
		if frameData.sizeW ~= scaledWidth or frameData.sizeH ~= scaledHeight then
			frameData.sizeW = scaledWidth
			frameData.sizeH = scaledHeight
			frameData.locking = true
			icon:SetSize(scaledWidth, scaledHeight)
			frameData.locking = false
		end
		if frameData.skinVer ~= skinVersion then
			CDM.SkinIcon(icon, settings, "buffs")
		end
	end

	local stepX = Pixel.Snap(scaledWidth + spacing)
	local stepY = Pixel.Snap(scaledHeight + spacing)
	PlaceRow(visible, visibleCount, anchor, vertical, growUp, stepX, stepY, alpha)

	for iconIndex = 1, visibleCount do lastSnap[iconIndex] = visible[iconIndex] end
	for staleIndex = visibleCount + 1, #lastSnap do lastSnap[staleIndex] = nil end
	lastSnapCount = visibleCount
	if usedPrefiltered then snapKeyed = false end
	lastWidth = scaledWidth
	lastHeight = scaledHeight
	lastSpacing = spacing
	lastVertical = vertical
	lastAnchorWidth = anchorWidth
	lastAnchorHeight = anchorHeight
	lastAlpha = alpha
	lastGrowUp = growUp
end

local FlushCenter = BUI.Dispatcher.New(CenterNow, 'CDM.BuffCenter flush')

local function ScheduleCenter()
	if active then FlushCenter() end
end

function CDM.MarkBuffCenterDirty()
	ScheduleCenter()
end

function CDM.CenterBuffsNow(force)
	if force then
		forceLayout = true
		CenterNow()
		return
	end

	ScheduleCenter()
end

function CDM.RefreshBuffOpacityCache()
	local opacity = CDM.GetContextualOpacity()
	if opacity == cachedOpacity then return end
	cachedOpacity = opacity
	forceLayout = true
	ScheduleCenter()
end

function CDM.CenterBuffList(icons, count)
	prefilteredIcons = icons
	prefilteredCount = count
	active = true
	CenterNow()
end

function CDM.SetupBuffCentering()
	if not BUI.GetDB().cdm.buffs.enabled then return end
	active = true
	forceLayout = true
	CenterNow()
end
