local _, BUI = ...

local _G = _G
local ipairs, wipe = ipairs, wipe
local sort = table.sort

local function C_Timer_After(delay, callback) BUI.Prof.After('CDM.Layout', delay, callback) end

local CDM = BUI.CDM
local Pixel = BUI.Pixel
local FrameData = CDM.FrameData
local GetFrameData = CDM.GetFrameData
local PackInto = CDM.PackInto

local iconBuffer = {}
local layoutBuffer = {}
local viewerChildBuf = {}
local poolActiveBuf = {}

local iconCache = {}
local iconCacheValid = {}

function CDM.SortByLayoutIndex(left, right)
    local leftIndex = left.layoutIndex or left:GetID() or 0
    local rightIndex = right.layoutIndex or right:GetID() or 0
    if leftIndex ~= rightIndex then return leftIndex < rightIndex end
    local leftData = FrameData[left]
    local rightData = FrameData[right]
    return (leftData and leftData.trackSeq or 0) < (rightData and rightData.trackSeq or 0)
end

local orderLookup = {}

local function SortByUserOrder(left, right)
    local idA = CDM.GetSortKey(left)
    local idB = CDM.GetSortKey(right)
    local posA = idA and orderLookup[idA] or 99999
    local posB = idB and orderLookup[idB] or 99999
    if posA ~= posB then return posA < posB end
    return CDM.SortByLayoutIndex(left, right)
end

local function CollectCustomIcons(viewerKey, outIcons)
    local Custom = CDM.Custom
    local customList, customCount = Custom.GetIcons(viewerKey)
    if not customList then return end
    for iconIndex = 1, customCount do
        local icon = customList[iconIndex]
        if icon then
            if icon:IsShown() then
                outIcons[#outIcons + 1] = icon
            elseif viewerKey == "buffs" then
                local frameData = FrameData[icon]

                local spellID = frameData and frameData.customSpellID
                if spellID and not CDM._deferredIconUpdate then
                    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                    if aura then
                        CDM._deferredIconUpdate = true
                        C_Timer_After(0, function()
                            CDM._deferredIconUpdate = nil
                            local list, count = Custom.GetIcons("buffs")
                            if not list then return end
                            for hiddenIndex = 1, count do
                                if list[hiddenIndex] and not list[hiddenIndex]:IsShown() then
                                    Custom.UpdateIcon(list[hiddenIndex])
                                end
                            end
                        end)
                    end
                end
            end
        end
    end
end

local function ApplyUserOrder(viewerKey, icons)
    local config = BUI.GetDB().cdm[viewerKey]
    local savedOrder = CDM.GetIconOrder(config)

    if not savedOrder or #savedOrder == 0 then
        sort(icons, CDM.SortByLayoutIndex)
        return
    end

    wipe(orderLookup)
    for orderIndex, id in ipairs(savedOrder) do
        orderLookup[id] = orderIndex
    end
    sort(icons, SortByUserOrder)
    wipe(orderLookup)
end

function CDM.HasUserOrder(viewerKey)
    local savedOrder = CDM.GetIconOrder(BUI.GetDB().cdm[viewerKey])
    return savedOrder ~= nil and #savedOrder > 0
end

local function BuildViewerIcons(viewerKey)
    wipe(iconBuffer)

    local viewer = _G[CDM.VIEWERS[viewerKey]]
    if not viewer then return iconBuffer end

    CollectCustomIcons(viewerKey, iconBuffer)

    local isBuff = viewerKey == "buffs"

    local poolActive
    if not isBuff and viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
        wipe(poolActiveBuf)
        for frame in viewer.itemFramePool:EnumerateActive() do
            poolActiveBuf[frame] = true
        end
        poolActive = poolActiveBuf
    end
    for _, child in ipairs(PackInto(viewerChildBuf, viewer:GetChildren())) do
        local isCDMIcon = isBuff and child.Icon or CDM.IsCooldownIcon(child)
        local included = child:IsShown() or (poolActive and poolActive[child] and child.cooldownInfo and true)
        if included and isCDMIcon then
            local childFrameData = FrameData[child]
            if not (childFrameData and childFrameData.customIcon) then
                iconBuffer[#iconBuffer + 1] = child
            end
        end
    end

    ApplyUserOrder(viewerKey, iconBuffer)

    return iconBuffer
end

function CDM.GetViewerIcons(viewerKey)
    if iconCacheValid[viewerKey] then return iconCache[viewerKey] end

    local icons = BuildViewerIcons(viewerKey)

    local cached = iconCache[viewerKey]
    if not cached then cached = {}; iconCache[viewerKey] = cached end
    for iconIndex = 1, #icons do cached[iconIndex] = icons[iconIndex] end
    for iconIndex = #icons + 1, #cached do cached[iconIndex] = nil end

    iconCacheValid[viewerKey] = true
    return cached
end

function CDM.InvalidateIconCache(viewerKey)
    if viewerKey then
        iconCacheValid[viewerKey] = nil
    else
        wipe(iconCacheValid)
    end
end

local function PlaceIcon(icon, key, anchor, left, top, settings, opacity)
    CDM.HookIconFrame(icon, key)

    local frameData = GetFrameData(icon)

    if not icon:IsShown() then
        icon:Show()
    end
    local scaledWidth = anchor._cachedScaledW
    local scaledHeight = anchor._cachedScaledH
    local visibilityAlpha = anchor._iconAlpha or 1

    local anchorWidth = anchor._layoutW or scaledWidth
    local anchorHeight = anchor._layoutH or scaledHeight

    if not frameData.parked and frameData.anchor == anchor and frameData.posCornerX == left and frameData.posCornerY == -top
       and frameData.sizeW == scaledWidth and frameData.sizeH == scaledHeight
       and frameData.anchorW == anchorWidth and frameData.anchorH == anchorHeight then
        if frameData.skinVer ~= CDM.state.skinVersion then
            CDM.SkinIcon(icon, settings, key)
        end
        if not frameData.hidden then
            frameData.parked = nil
            frameData.locking = true
            icon:SetAlpha((opacity / 100) * visibilityAlpha)
            frameData.locking = false
        end
        return
    end

    if frameData.skinVer ~= CDM.state.skinVersion then
        CDM.SkinIcon(icon, settings, key)
    end

    frameData.anchor = anchor
    frameData.posX = nil
    frameData.posY = nil
    frameData.sizeW = scaledWidth
    frameData.sizeH = scaledHeight
    frameData.anchorW = anchorWidth
    frameData.anchorH = anchorHeight

    frameData.selfPoint = "TOPLEFT"
    frameData.relPoint = "TOPLEFT"
    frameData.posCornerX = left
    frameData.posCornerY = -top
    frameData.locking = true

    icon:SetScale(1)
    icon:SetSize(scaledWidth, scaledHeight)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, -top)

    frameData.parked = nil
    frameData.hiddenParked = nil
    icon:SetAlpha((opacity / 100) * visibilityAlpha)
    frameData.locking = false
end

local function HideWhenZeroCount(frameData, spellID)
    if frameData and frameData.itemID and frameData.iconType ~= 'trinket' then
        return C_Item.GetItemCount(frameData.itemID) or 0
    end
    if spellID then
        local charges = C_Spell.GetSpellCharges(spellID)
        if charges and (charges.maxCharges or 0) > 0 then
            return charges.currentCharges or 0
        end
    end
    return nil
end

local function IconCornerTop(anchorHeight, scaledHeight, y)
    return Pixel.Snap(anchorHeight / 2 - y - scaledHeight / 2)
end

local function RowLeftCorner(anchorWidth, rowWidth)
    return Pixel.Snap((anchorWidth - rowWidth) / 2)
end

local function PublishEdgeOffsets(anchor, totalHeight, scaledHeight, topY, bottomY)
    local topCorner = IconCornerTop(totalHeight, scaledHeight, topY)
    anchor._topEdgeOffset = topCorner
    anchor._bottomEdgeOffset = totalHeight - IconCornerTop(totalHeight, scaledHeight, bottomY) - scaledHeight
    anchor._topRowCenterOffsetY = Pixel.Snap(totalHeight / 2 - topCorner - scaledHeight / 2)
end

local function ResolveIconIDs(icon, iconFrameData)
    local cooldownInfo = icon.cooldownInfo
    local baseID = cooldownInfo and BUI.Tools.SafeNum(cooldownInfo.spellID)
    local overrideID = cooldownInfo and BUI.Tools.SafeNum(cooldownInfo.overrideSpellID)
    if cooldownInfo then
        local cooldownID = BUI.Tools.SafeNum(cooldownInfo.cooldownID)
        if baseID or overrideID then
            if not iconFrameData then iconFrameData = GetFrameData(icon) end
            iconFrameData.knownBaseID, iconFrameData.knownOverrideID, iconFrameData.knownCooldownID = baseID, overrideID, cooldownID
        elseif iconFrameData and (cooldownID == nil or iconFrameData.knownCooldownID == cooldownID) then
            baseID, overrideID = iconFrameData.knownBaseID, iconFrameData.knownOverrideID
        end
    end
    local storedValue = iconFrameData and BUI.Tools.SafeNum(iconFrameData.storedValue)
    local customID = iconFrameData and iconFrameData.customSpellID
    return iconFrameData, baseID, overrideID, storedValue, customID
end

local function IsHiddenByUser(key, hiddenIcons, iconFrameData, baseID, overrideID, storedValue)
    if iconFrameData and iconFrameData.customIcon then
        local customKey = iconFrameData.customKey
        return customKey ~= nil and CDM.IsIconHiddenEffective(key, hiddenIcons, customKey)
    end
    return (baseID and hiddenIcons[baseID]) or (overrideID and hiddenIcons[overrideID]) or (storedValue and hiddenIcons[storedValue]) or false
end

function CDM.IsIconHiddenByUser(key, hiddenIcons, icon)
    local iconFrameData, baseID, overrideID, storedValue = ResolveIconIDs(icon, FrameData[icon])
    return IsHiddenByUser(key, hiddenIcons, iconFrameData, baseID, overrideID, storedValue) and true or false
end

function CDM.ApplyIconPositions(key)
    local Anchors = CDM.Anchors
    local anchor = Anchors[key]
    if not anchor then return end

    local viewerName = CDM.VIEWERS[key]
    local viewer = viewerName and _G[viewerName]
    if not viewer then return end

    local db = BUI.GetDB()
    local settings = db.cdm[key]
    if not settings or not settings.enabled then return end

    local iconWidth = settings.iconWidth
    local iconHeight = settings.iconHeight
    local spacing = settings.spacing
    local borderSize = settings.borderSize
    anchor._cachedScaledW = settings._pxW or (Pixel.Scale(iconWidth))
    anchor._cachedScaledH = settings._pxH or (Pixel.Scale(iconHeight))
    anchor._cachedScaledSpacing = settings._pxGap or Pixel.Scale(spacing)

    if not viewer:IsShown() then
        anchor:Hide()
        return
    end

    local allIcons = CDM.GetViewerIcons(key)
    if not allIcons then return end

    local opacity = CDM.GetContextualOpacity(key)

    local perRow = settings.iconsPerRow
    local vertical = settings.vertical

    if #allIcons == 0 then
        local expectedCols = perRow > 0 and perRow or 8
        local expectedWidth = expectedCols * anchor._cachedScaledW + (expectedCols - 1) * anchor._cachedScaledSpacing
        local expectedHeight = anchor._cachedScaledH
        if vertical then expectedWidth, expectedHeight = expectedHeight, expectedWidth end
        anchor:SetSize(expectedWidth, expectedHeight)
        anchor._layoutW, anchor._layoutH = expectedWidth, expectedHeight
        CDM.ApplyAnchorPosition(key)
        anchor._row1W = expectedWidth
        anchor._topRowW = expectedWidth
        anchor._bottomRowW = expectedWidth
        anchor._row1CenterOffsetX = 0
        anchor._topRowCenterOffsetX = 0
        anchor._bottomRowCenterOffsetX = 0
        anchor._topRowCenterOffsetY = 0
        anchor._topEdgeOffset, anchor._bottomEdgeOffset = 0, 0
        anchor:Hide()
        return
    end

    wipe(layoutBuffer)
    local hiddenSlots = settings.hiddenSlots
    local hiddenIcons = CDM.GetHiddenIcons(settings)
    local showOnlyOnCD = key ~= 'buffs' and CDM.GetShowOnlyOnCD(settings) or nil
    local hideWhenZero = key ~= 'buffs' and CDM.GetHideWhenZero(settings) or nil
    local Custom = CDM.Custom

    for iconIndex = 1, #allIcons do
        local icon = allIcons[iconIndex]
        local shouldHide = false
        local iconFrameData = FrameData[icon]

        if hiddenSlots and hiddenSlots[iconIndex] then
            shouldHide = true
        end

        if not shouldHide then
            local baseID, overrideID, storedValue, customID
            iconFrameData, baseID, overrideID, storedValue, customID = ResolveIconIDs(icon, iconFrameData)
            if IsHiddenByUser(key, hiddenIcons, iconFrameData, baseID, overrideID, storedValue) then
                shouldHide = true
            end

            if not shouldHide and iconFrameData and iconFrameData.customIcon then
                local viewerConfig = db.cdm[iconFrameData.viewerKey]
                local forceShow = viewerConfig and iconFrameData.customKey and CDM.IsAlwaysShow(viewerConfig, iconFrameData.customKey)
                if not forceShow and iconFrameData.viewerKey ~= "buffs" and not Custom.IsEquippedOrKnownOrInBagsIcon(icon) then
                    shouldHide = true
                end
            end

            if not shouldHide and showOnlyOnCD then
                local cooldownKey
                if iconFrameData and iconFrameData.customIcon then
                    cooldownKey = iconFrameData.customKey
                else
                    cooldownKey = baseID or overrideID or storedValue
                end
                if cooldownKey and showOnlyOnCD[cooldownKey] then
                    local spellID = customID or baseID or overrideID
                    if spellID and not CDM.IsShowOnlyOnCDActive(spellID) then
                        shouldHide = true
                    end
                end
            end

            if hideWhenZero then
                local hideZeroKey
                if iconFrameData and iconFrameData.customIcon then
                    hideZeroKey = iconFrameData.customKey
                else
                    hideZeroKey = baseID or overrideID or storedValue
                end
                if hideZeroKey and hideWhenZero[hideZeroKey] then
                    local countID = customID or baseID or overrideID
                    if HideWhenZeroCount(iconFrameData, countID) == 0 then
                        shouldHide = true
                    end
                end
            end
        end

        if shouldHide then
            if not iconFrameData then iconFrameData = GetFrameData(icon) end
            iconFrameData.hidden = true

            CDM.HookIconFrame(icon, key)
            if not (iconFrameData.hiddenParked
                and iconFrameData.anchor == anchor
                and iconFrameData.hiddenSkinVer == CDM.state.skinVersion) then
                iconFrameData.anchor = anchor
                iconFrameData.posX = nil
                iconFrameData.posY = nil
                iconFrameData.selfPoint = "TOPLEFT"
                iconFrameData.relPoint = "TOPLEFT"
                iconFrameData.posCornerX = 0
                iconFrameData.posCornerY = 0
                iconFrameData.locking = true
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
                iconFrameData.locking = false
                icon:SetAlpha(0)
                icon:EnableMouse(false)
                if icon._tooltipOverlay then icon._tooltipOverlay:EnableMouse(false) end
                iconFrameData.hiddenParked = true
                iconFrameData.hiddenSkinVer = CDM.state.skinVersion
            end
        else
            if iconFrameData then
                iconFrameData.hidden = nil
                iconFrameData.hiddenParked = nil
            end
            icon:EnableMouse(true)
            if icon._tooltipOverlay then icon._tooltipOverlay:EnableMouse(true) end
            layoutBuffer[#layoutBuffer + 1] = icon
        end
    end

    if #layoutBuffer == 0 then
        anchor:Hide()
        return
    end

    local Detached = CDM.Detached
    local gridCount = 0
    for iconIndex = 1, #layoutBuffer do
        local icon = layoutBuffer[iconIndex]
        local spellID = CDM.GetStableSpellID(icon)
        if spellID and CDM.IsIconDetached(settings, spellID) then
            Detached.PlaceIcon(icon, key, iconWidth, iconHeight, settings)
        else
            Detached.HookIcon(icon, key)
            gridCount = gridCount + 1
            layoutBuffer[gridCount] = icon
        end
    end
    for iconIndex = gridCount + 1, #layoutBuffer do
        layoutBuffer[iconIndex] = nil
    end

    local icons = layoutBuffer
    local count = gridCount

    if count == 0 then
        anchor:Hide()
        return
    end

    local growUp = settings.rowGrowth == "Up"
    local scaledWidth = anchor._cachedScaledW
    local scaledHeight = anchor._cachedScaledH
    local scaledSpacing = anchor._cachedScaledSpacing
    local stepX = scaledWidth + scaledSpacing
    local stepY = scaledHeight + scaledSpacing

    if perRow <= 0 then
        local totalWidth, totalHeight
        if vertical then
            totalWidth = scaledWidth
            totalHeight = count * scaledHeight + (count - 1) * scaledSpacing
        else
            totalWidth = count * scaledWidth + (count - 1) * scaledSpacing
            totalHeight = scaledHeight
        end

        anchor:SetSize(totalWidth, totalHeight)
        anchor._layoutW, anchor._layoutH = totalWidth, totalHeight
        anchor._row1W = totalWidth
        anchor._topRowW = totalWidth
        anchor._bottomRowW = totalWidth

        local topCenterY = vertical and (totalHeight / 2 - scaledHeight / 2) or 0
        local startLeft = RowLeftCorner(totalWidth, vertical and scaledWidth or totalWidth)
        local startTop = IconCornerTop(totalHeight, scaledHeight, topCenterY)
        if vertical then
            PublishEdgeOffsets(anchor, totalHeight, scaledHeight, topCenterY, topCenterY - (count - 1) * stepY)
        else
            PublishEdgeOffsets(anchor, totalHeight, scaledHeight, 0, 0)
        end
        if key ~= "buffs" then
            anchor._row1CenterOffsetX = 0
            anchor._topRowCenterOffsetX = 0
            anchor._bottomRowCenterOffsetX = 0
        end

        CDM.ApplyAnchorPosition(key)
        if not anchor._opacityHidden then anchor:Show() end

        if key == "buffs" then
            local visibilityAlpha = anchor._iconAlpha or 1
            local alpha = (opacity / 100) * visibilityAlpha
            for iconIndex = 1, count do
                CDM.HookIconFrame(icons[iconIndex], key)
                local iconFrameData = FrameData[icons[iconIndex]]
                if not iconFrameData then iconFrameData = GetFrameData(icons[iconIndex]) end
                if iconFrameData.skinVer ~= CDM.state.skinVersion then
                    CDM.SkinIcon(icons[iconIndex], settings, key)
                end
                iconFrameData.anchor = anchor
                iconFrameData.sizeW = scaledWidth
                iconFrameData.sizeH = scaledHeight
                iconFrameData.locking = true
                icons[iconIndex]:SetScale(1)
                icons[iconIndex]:SetSize(scaledWidth, scaledHeight)
                iconFrameData.locking = false
                if not iconFrameData.hidden then
                    iconFrameData.locking = true
                    icons[iconIndex]:SetAlpha(alpha)
                    iconFrameData.locking = false
                end
            end
            CDM.CenterBuffList(icons, count)
            return
        end

        for iconIndex = 1, count do
            local left, top
            if vertical then
                left = startLeft
                top = startTop + (iconIndex - 1) * stepY
            else
                left = startLeft + (iconIndex - 1) * stepX
                top = startTop
            end
            PlaceIcon(icons[iconIndex], key, anchor, left, top, settings, opacity)
        end
        return
    end

    local numRows, maxCols
    if key == "buffs" then
        numRows, maxCols = CDM.RowMetrics(count, perRow)
    else
        numRows, maxCols = CDM.RowMetrics(count, perRow, settings.row2Count, settings.row3Count)
    end
    local totalWidth, totalHeight

    if vertical then
        totalWidth = numRows * scaledWidth + (numRows - 1) * scaledSpacing
        totalHeight = maxCols * scaledHeight + (maxCols - 1) * scaledSpacing
    else
        totalWidth = maxCols * scaledWidth + (maxCols - 1) * scaledSpacing
        totalHeight = numRows * scaledHeight + (numRows - 1) * scaledSpacing
    end

    anchor:SetSize(totalWidth, totalHeight)
    anchor._layoutW, anchor._layoutH = totalWidth, totalHeight

    local function RowWidthOf(iconCount)
        return iconCount * scaledWidth + (iconCount > 1 and (iconCount - 1) * scaledSpacing or 0)
    end
    local row1Count = CDM.NextRowSize(1, count, perRow)
    anchor._row1W = RowWidthOf(row1Count)

    local lastRowCount = row1Count
    if numRows > 1 then
        if key == "buffs" then
            lastRowCount = count - row1Count
        else
            local placed = 0
            for rowIndex = 1, numRows - 1 do
                placed = placed + CDM.NextRowSize(rowIndex, count - placed, perRow, settings.row2Count, settings.row3Count)
            end
            lastRowCount = count - placed
        end
    end
    local topRowCount = growUp and lastRowCount or row1Count
    local bottomRowCount = growUp and row1Count or lastRowCount
    anchor._topRowW = vertical and totalWidth or RowWidthOf(topRowCount)
    anchor._bottomRowW = vertical and totalWidth or RowWidthOf(bottomRowCount)

    local yDirection = growUp and 1 or -1

    local topRowY, bottomRowY
    if vertical then
        local colStart = -totalHeight / 2 + scaledHeight / 2
        local colEnd = colStart + (maxCols - 1) * stepY
        if growUp then topRowY, bottomRowY = colEnd, colStart else topRowY, bottomRowY = -colStart, -colEnd end
    elseif growUp then
        topRowY, bottomRowY = (numRows - 1) * stepY, 0
    else
        topRowY, bottomRowY = 0, -(numRows - 1) * stepY
    end
    PublishEdgeOffsets(anchor, totalHeight, scaledHeight, topRowY, bottomRowY)

    if key ~= "buffs" then
        if vertical then
            anchor._row1CenterOffsetX = 0
            anchor._topRowCenterOffsetX = 0
            anchor._bottomRowCenterOffsetX = 0
        else
            local function RowCenterOffset(iconCount, isLastRow)
                local rowWidth = RowWidthOf(iconCount)
                local rowLeft
                if isLastRow and numRows > 1 and settings.centerLastRow == false then
                    rowLeft = 0
                else
                    rowLeft = RowLeftCorner(totalWidth, rowWidth)
                end
                return Pixel.Snap(rowLeft + rowWidth / 2 - totalWidth / 2)
            end
            anchor._row1CenterOffsetX = RowCenterOffset(row1Count, false)
            anchor._topRowCenterOffsetX = RowCenterOffset(topRowCount, growUp)
            anchor._bottomRowCenterOffsetX = RowCenterOffset(bottomRowCount, not growUp)
        end
    end

    CDM.ApplyAnchorPosition(key)
    if not anchor._opacityHidden then anchor:Show() end

    if key == "buffs" then
        for iconListIndex = 1, count do
            CDM.HookIconFrame(icons[iconListIndex], key)
            local iconFrameData = FrameData[icons[iconListIndex]]
            if not iconFrameData then iconFrameData = GetFrameData(icons[iconListIndex]) end
            if iconFrameData.skinVer ~= CDM.state.skinVersion then
                CDM.SkinIcon(icons[iconListIndex], settings, key)
            end
            iconFrameData.anchor = anchor
            iconFrameData.sizeW = scaledWidth
            iconFrameData.sizeH = scaledHeight
            iconFrameData.locking = true
            icons[iconListIndex]:SetScale(1)
            icons[iconListIndex]:SetSize(scaledWidth, scaledHeight)
            iconFrameData.locking = false
        end
        CDM.CenterBuffList(icons, count)
        return
    end

    local iconIndex = 1
    local remaining = count
    for row = 1, numRows do
        local rowCount = CDM.NextRowSize(row, remaining, perRow, settings.row2Count, settings.row3Count)
        remaining = remaining - rowCount

        if vertical then
            local columnWidth = rowCount * scaledHeight + (rowCount - 1) * scaledSpacing
            local vertColStart = -columnWidth / 2 + scaledHeight / 2
            local colLeft = RowLeftCorner(totalWidth, totalWidth) + (row - 1) * stepX
            local colTopBase = IconCornerTop(totalHeight, scaledHeight, vertColStart * yDirection)
            for col = 0, rowCount - 1 do
                if iconIndex > count then break end
                PlaceIcon(icons[iconIndex], key, anchor, colLeft, colTopBase - col * stepY * yDirection, settings, opacity)
                iconIndex = iconIndex + 1
            end
        else
            local rowWidth = rowCount * scaledWidth + (rowCount - 1) * scaledSpacing
            local rowLeft
            if row == numRows and numRows > 1 and settings.centerLastRow == false then
                rowLeft = 0
            else
                rowLeft = RowLeftCorner(totalWidth, rowWidth)
            end
            local rowTop = IconCornerTop(totalHeight, scaledHeight, (row - 1) * stepY * yDirection)
            for col = 0, rowCount - 1 do
                if iconIndex > count then break end
                PlaceIcon(icons[iconIndex], key, anchor, rowLeft + col * stepX, rowTop, settings, opacity)
                iconIndex = iconIndex + 1
            end
        end
    end
end

function CDM.LayoutAllViewers()
    for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
        CDM.ApplyIconPositions(CDM.VIEWER_KEYS[viewerIndex])
    end
end

function CDM.NotifyDependents()
    local Anchors = CDM.Anchors
    local anySize, anyOffset, anyPos = false, false, false

    for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[viewerIndex]
        local anchor = Anchors[key]
        if anchor then
            local newWidth, newHeight = anchor:GetSize()
            if anchor._lastW ~= newWidth or anchor._lastH ~= newHeight or anchor._lastTopRowW ~= anchor._topRowW
                or anchor._lastBottomRowW ~= anchor._bottomRowW then
                anchor._lastW, anchor._lastH = newWidth, newHeight
                anchor._lastTopRowW = anchor._topRowW
                anchor._lastBottomRowW = anchor._bottomRowW
                anySize = true
            end
            if anchor._lastTopOffset ~= anchor._topEdgeOffset or anchor._lastBottomOffset ~= anchor._bottomEdgeOffset then
                anchor._lastTopOffset = anchor._topEdgeOffset
                anchor._lastBottomOffset = anchor._bottomEdgeOffset
                anyOffset = true
            end

            if anchor._lastSnapX ~= anchor._snappedCenterX or anchor._lastSnapY ~= anchor._snappedCenterY then
                anchor._lastSnapX, anchor._lastSnapY = anchor._snappedCenterX, anchor._snappedCenterY
                anyPos = true
            end
        end
    end

    if CDM.state.initComplete and (anySize or anyPos) then
        CDM.NotifyUnitFrames()
    end

    if anySize or anyOffset or anyPos then
        BUI.Anchor.OnAnchorSizeChanged()
    end
end

function CDM.RefreshLayoutOnly()
    CDM.InvalidateIconCache()
    CDM.UpdateAllPixelValues()
    CDM.LayoutAllViewers()
    CDM.NotifyDependents()
    if CDM.state.initComplete then
        CDM.NotifyUnitFrames()
    end
    CDM.RefreshBuffsPreview()
    CDM.SetupBuffCentering()
end
