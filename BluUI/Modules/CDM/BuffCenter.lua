local _, BUI = ...

local _G = _G
local sort = table.sort
local wipe = wipe
local CreateFrame = CreateFrame

local CDM = BUI.CDM
local Pixel = BUI.Pixel
local FrameData = CDM.FrameData

local active = false
local visible = {}
local orderLookup = {}
local cachedOpacity = 100
local pendingFrame = nil
local lastSnap = {}
local lastSnapCount = 0
local lastWidth, lastHeight, lastSpacing, lastVertical
local lastAnchorWidth, lastAnchorHeight, lastAlpha, lastGrowUp
local forceLayout = false

local prefilteredIcons
local prefilteredCount = 0

local function SortByLayout(iconA, iconB)
	return (iconA.layoutIndex or 0) < (iconB.layoutIndex or 0)
end

local function SortByCustomOrder(iconA, iconB)
	local idA = CDM.GetSortKey(iconA) or 0
	local idB = CDM.GetSortKey(iconB) or 0
	local posA = orderLookup[idA] or 999999
	local posB = orderLookup[idB] or 999999
	if posA ~= posB then return posA < posB end
	return (iconA.layoutIndex or 0) < (iconB.layoutIndex or 0)
end

local function CollectVisible(viewer)
	local count = 0

	local pool = viewer.itemFramePool
	if pool and pool.EnumerateActive then
		for icon in pool:EnumerateActive() do
			if icon:IsShown() then
				local frameData = FrameData[icon]
				if not frameData or not frameData.hidden then
					count = count + 1
					visible[count] = icon
				end
			end
		end
	end

	local customList, customCount = CDM.Custom.GetIcons("buffs")
	if customList then
		for customIndex = 1, customCount do
			local icon = customList[customIndex]
			if icon and icon:IsShown() then
				local frameData = FrameData[icon]
				if not frameData or not frameData.hidden then
					count = count + 1
					visible[count] = icon
				end
			end
		end
	end
	for staleIndex = count + 1, #visible do visible[staleIndex] = nil end
	return count
end

local function PlaceIconCentered(icon, anchor, x, y, alpha)
	if not icon then return end
	local frameData = FrameData[icon]
	if not frameData then return end
	local anchorWidth = anchor._layoutW or anchor:GetWidth() or 0
	local anchorHeight = anchor._layoutH or anchor:GetHeight() or 0
	local width = frameData.sizeW or anchor._cachedScaledW or 0
	local height = frameData.sizeH or anchor._cachedScaledH or 0
	local left = Pixel.Snap(anchorWidth / 2 + x - width / 2)
	local top = -Pixel.Snap(anchorHeight / 2 - y - height / 2)
	frameData.locking = true
	frameData.anchor = anchor
	if frameData.parked or frameData.posCornerX ~= left or frameData.posCornerY ~= top then
		frameData.selfPoint = 'TOPLEFT'
		frameData.relPoint = 'TOPLEFT'
		frameData.posCornerX = left
		frameData.posCornerY = top
		frameData.posX = nil
		frameData.posY = nil
		icon:ClearAllPoints()
		icon:SetPoint('TOPLEFT', anchor, 'TOPLEFT', left, top)
	end
	frameData.parked = nil
	icon:SetAlpha(alpha)
	frameData.locking = false
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

local function CenterNow()
	if not active then return end

	local viewerName = CDM.VIEWERS.buffs
	local viewer = viewerName and _G[viewerName]
	if not viewer then return end

	local settings = BUI.GetDB().cdm.buffs
	if not settings or not settings.enabled then
		CDM.StopBuffCentering()
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
	local scaledWidth = settings._pxW or Pixel.Scale(settings.iconWidth)
	local scaledHeight = settings._pxH or Pixel.Scale(settings.iconHeight)
	local vertical = settings.vertical and true or false
	anchor._cachedScaledW = scaledWidth
	anchor._cachedScaledH = scaledHeight
	local anchorWidth, anchorHeight = anchor._layoutW, anchor._layoutH
	local alpha = (cachedOpacity / 100) * (anchor._iconAlpha or 1)
	local growUp = settings.rowGrowth == "Up"
	local skinVersion = CDM.state.skinVersion

	if not usedPrefiltered then
		local savedOrder = CDM.GetIconOrder(settings)
		if savedOrder and #savedOrder > 0 then
			wipe(orderLookup)
			for orderIndex, id in ipairs(savedOrder) do orderLookup[id] = orderIndex end
			sort(visible, SortByCustomOrder)
			wipe(orderLookup)
		else
			sort(visible, SortByLayout)
		end
	end

	if not forceLayout and visibleCount == lastSnapCount
		and scaledWidth == lastWidth and scaledHeight == lastHeight and spacing == lastSpacing and vertical == lastVertical
		and anchorWidth == lastAnchorWidth and anchorHeight == lastAnchorHeight and alpha == lastAlpha and growUp == lastGrowUp then
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
		local frameData = FrameData[icon]
		if not frameData then
			CDM.HookIconFrame(icon, "buffs")
			frameData = FrameData[icon]
		end
		if frameData and frameData.anchor ~= UIParent then
			local scale = icon:GetScale()
			if scale and (scale > 1.01 or scale < 0.99) then
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
	end

	local stepX = Pixel.Snap(scaledWidth + spacing)
	local stepY = Pixel.Snap(scaledHeight + spacing)
	PlaceRow(visible, visibleCount, anchor, vertical, growUp, stepX, stepY, alpha)

	for iconIndex = 1, visibleCount do lastSnap[iconIndex] = visible[iconIndex] end
	for staleIndex = visibleCount + 1, #lastSnap do lastSnap[staleIndex] = nil end
	lastSnapCount = visibleCount
	lastWidth = scaledWidth
	lastHeight = scaledHeight
	lastSpacing = spacing
	lastVertical = vertical
	lastAnchorWidth = anchorWidth
	lastAnchorHeight = anchorHeight
	lastAlpha = alpha
	lastGrowUp = growUp
end

local function ScheduleCenter()
	if not active then return end
	if not pendingFrame then
		pendingFrame = CreateFrame("Frame", "BUI_CDMBuffCenterFlush")
		pendingFrame:SetScript("OnUpdate", function(self)
			self:Hide()
			CenterNow()
		end)
	end
	pendingFrame:Show()
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
	local opacity = CDM.GetContextualOpacity("buffs")
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

function CDM.StopBuffCentering()
	active = false
	if pendingFrame then pendingFrame:Hide() end
end
