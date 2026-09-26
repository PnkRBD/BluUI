local _, BUI = ...

local CustomBars = {}
BUI.CustomBars = CustomBars

local Pixel = BUI.Pixel
local IconEngine = BUI.IconEngine

local TRINKET_SLOTS = { 13, 14 }
local CORNER_OFFSETS = {
    TOPLEFT = { 2, -2 }, TOP = { 0, -2 }, TOPRIGHT = { -2, -2 },
    LEFT = { 2, 0 }, CENTER = { 0, 0 }, RIGHT = { -2, 0 },
    BOTTOMLEFT = { 2, 2 }, BOTTOM = { 0, 2 }, BOTTOMRIGHT = { -2, 2 },
}
local VALID_STRATA = {
    BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true,
    DIALOG = true, FULLSCREEN_DIALOG = true, TOOLTIP = true,
}

local bars = {}
local positionCallbacks = {}
local lockSyncs = {}
local eventsRegistered = false
local styleVersion = 0
local playerKey

local function GetPlayerKey()
    if not playerKey then
        playerKey = UnitName("player") .. " - " .. GetRealmName()
    end
    return playerKey
end

local function GetAllSpellStores()
    local global = BUI.db.global
    global.charCustomBarsSpells = global.charCustomBarsSpells or {}
    return global.charCustomBarsSpells
end

local function CurrentProfileName()
    return BUI.GetAceDB():GetCurrentProfile()
end

local function ProfileBucket(store, profileName)
    local bucket = store[profileName]
    if not bucket then
        bucket = {}
        store[profileName] = bucket
        for storeKey, list in pairs(store) do
            if type(storeKey) == "number" then
                bucket[storeKey] = list
                store[storeKey] = nil
            end
        end
    end
    return bucket
end

local function GetSpellStore()
    local stores = GetAllSpellStores()
    local key = GetPlayerKey()
    stores[key] = stores[key] or {}
    return ProfileBucket(stores[key], CurrentProfileName())
end

local function ProfileNameFor(characterKey)
    local savedVariables = BUI.db.sv
    return savedVariables.profileKeys and savedVariables.profileKeys[characterKey]
end

local function LoadBarsFor(characterKey)
    local savedVariables = BUI.db.sv
    local profileName = ProfileNameFor(characterKey)
    if not (profileName and savedVariables.profiles and savedVariables.profiles[profileName]) then return nil end
    return savedVariables.profiles[profileName].customBars
end

local function LoadSpellsFor(characterKey)
    local store = GetAllSpellStores()[characterKey]
    if not store then return nil end
    local profileName = ProfileNameFor(characterKey)
    local source = profileName and store[profileName] or store
    local spells = {}
    for barIndex, list in pairs(source) do
        if type(barIndex) == "number" and type(list) == "table" and #list > 0 then
            spells[barIndex] = list
        end
    end
    return next(spells) and spells or nil
end

local function GetSettings()
    local db = BUI.GetDB()
    for _, bar in ipairs(db.customBars) do
        bar.customSpells = bar.customSpells or {}
    end
    return db.customBars
end

local function GetBar(index)
    return GetSettings()[index]
end

function CustomBars.RegisterPositionCallback(index, callback)
    positionCallbacks[index] = callback
end

function CustomBars.UnregisterPositionCallback(index)
    positionCallbacks[index] = nil
end

function CustomBars.RegisterLockSync(index, callback)
    lockSyncs[index] = callback
end

function CustomBars.UnregisterLockSync(index)
    lockSyncs[index] = nil
end

function CustomBars.GetOtherCharacters()
    local stores = GetAllSpellStores()
    local myKey = GetPlayerKey()
    local result = {}
    for characterKey in pairs(stores) do
        if characterKey ~= myKey and LoadSpellsFor(characterKey) then
            result[#result + 1] = characterKey
        end
    end
    table.sort(result)
    return result
end

function CustomBars.GetBarInfoForCharacter(characterKey)
    local spells = LoadSpellsFor(characterKey)
    if not spells then return {} end
    local sourceBars = LoadBarsFor(characterKey)
    local result = {}
    for barIndex, list in pairs(spells) do
        if #list > 0 then
            local name = sourceBars and sourceBars[barIndex] and sourceBars[barIndex].name or ("Bar " .. barIndex)
            result[#result + 1] = { index = barIndex, name = name, count = #list }
        end
    end
    table.sort(result, function(leftBar, rightBar) return leftBar.index < rightBar.index end)
    return result
end

function CustomBars.CopyBarsFromCharacter(characterKey, indices)
    local spells = LoadSpellsFor(characterKey)
    if not spells then return end
    local sourceBars = LoadBarsFor(characterKey)

    local allowedIndices
    if indices then
        allowedIndices = {}
        for _, index in ipairs(indices) do allowedIndices[index] = true end
    end

    local settings = GetSettings()

    for sourceIndex, list in pairs(spells) do
        if #list > 0 and (not allowedIndices or allowedIndices[sourceIndex]) then
            local sourceBar = sourceBars and sourceBars[sourceIndex]
            local newIndex = #settings + 1
            CustomBars.AddBar(sourceBar and sourceBar.name or ("Imported Bar " .. sourceIndex))
            local destinationBar = settings[newIndex]
            if sourceBar then
                for key, value in pairs(sourceBar) do
                    if key ~= "name" and key ~= "posX" and key ~= "posY" and key ~= "customSpells" then
                        if type(value) == "table" then
                            local copy = {}
                            for tableKey, tableValue in pairs(value) do copy[tableKey] = tableValue end
                            destinationBar[key] = copy
                        else
                            destinationBar[key] = value
                        end
                    end
                end
            end
            wipe(destinationBar.customSpells)
            for spellIndex, spell in ipairs(list) do destinationBar.customSpells[spellIndex] = spell end
        end
    end
    CustomBars.RefreshAllBars()
end

local function LockBar(index)
    local settings = GetBar(index)
    if not settings or settings.locked then return end
    settings.locked = true
    local sync = lockSyncs[index]
    if sync then sync(false) end
    CustomBars.RefreshBar(index)
end

local function IsDragBlocked(index)
    local settings = GetBar(index)
    if settings and settings.locked then return true end
    local bar = bars[index]
    return bar and bar.frame._isAnchored or false
end

local function InvalidateStyle()
    styleVersion = styleVersion + 1
end

local function CreateIcon(parent, barIndex, iconIndex)
    local icon = CreateFrame("Frame", "BUI_TrackBar" .. barIndex .. "Icon" .. iconIndex, parent)
    icon:SnapSize(40)
    icon:EnableMouse(true)
    icon:RegisterForDrag("LeftButton")

    icon:SetScript("OnDragStart", function()
        if IsDragBlocked(barIndex) then return end
        parent.dragActive = true
        parent:StartMoving()
    end)
    icon:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        parent.dragActive = false
        local settings = GetBar(barIndex)
        if settings and not parent._isAnchored then
            settings.posX, settings.posY = BUI.Dragging.GetCenterOffset(parent)
            local callback = positionCallbacks[barIndex]
            if callback then callback(settings.posX, settings.posY) end
        end
    end)
    icon:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and not parent.dragActive then
            LockBar(barIndex)
        end
    end)

    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints()

    icon.hl = icon:CreateTexture(nil, "ARTWORK", nil, 1)
    icon.hl:SetAllPoints(icon.tex)
    BUI.Tools.SetColorTex(icon.hl, 0, 1, 0, 0.3)
    icon.hl:Hide()

    icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cd:SetAllPoints(icon.tex)
    icon.cd:SetDrawEdge(false)
    icon.cd:SetDrawBling(false)
    icon.cd:SetHideCountdownNumbers(true)
    icon.cd:SetSwipeColor(0, 0, 0, 0.8)

    local overlay = CreateFrame("Frame", nil, icon)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(icon:GetFrameLevel() + 20)
    overlay:EnableMouse(false)
    icon._tooltipOverlay = overlay

    icon:SetScript("OnEnter", function()
        local settings = GetBar(barIndex)
        if not settings or settings.showTooltips == false then return end
        if not icon.itemID or not icon.iconType then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        if icon.iconType == "spell" then
            GameTooltip:SetSpellByID(icon.itemID)
        else
            GameTooltip:SetItemByID(icon.itemID)
        end
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icon.stack = overlay:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(icon.stack, 12, BUI.GetTrackingFont())

    return icon
end

local function FindFontStringRegion(...)
    for regionIndex = 1, select('#', ...) do
        local region = select(regionIndex, ...)
        if region and region:GetObjectType() == "FontString" then return region end
    end
    return nil
end

local function StyleIcon(icon, settings)
    if icon._styleVer == styleVersion then return end
    icon._styleVer = styleVersion

    local size = settings.iconSize
    local zoom = settings.zoom
    local borderSize = settings.borderSize
    icon:SnapSize(size)

    local edge = Pixel.Scale(borderSize)
    icon.tex:ClearAllPoints()
    icon.tex:SetPoint("TOPLEFT", icon, "TOPLEFT", edge, -edge)
    icon.tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -edge, edge)
    icon.tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)

    icon.cd:ClearAllPoints()
    icon.cd:SetAllPoints(icon.tex)
    icon.hl:ClearAllPoints()
    icon.hl:SetAllPoints(icon.tex)

    local stackPosition = settings.stackTextPosition
    local stackOffset = CORNER_OFFSETS[stackPosition] or { 0, 0 }
    icon.stack:ClearAllPoints()
    icon.stack:SetPoint(stackPosition, icon, stackPosition,
        Pixel.Scale(settings.stackTextOffsetX + stackOffset[1]),
        Pixel.Scale(settings.stackTextOffsetY + stackOffset[2]))
    Pixel.ApplyFont(icon.stack, settings.stackTextSize, BUI.GetTrackingFont())

    local cooldownPosition = settings.cooldownTextPosition
    local cooldownOffset = CORNER_OFFSETS[cooldownPosition] or { 0, 0 }
    local cooldownOffsetX = settings.cooldownTextOffsetX + cooldownOffset[1]
    local cooldownOffsetY = settings.cooldownTextOffsetY + cooldownOffset[2]
    local cooldownFontString = FindFontStringRegion(icon.cd:GetRegions())
    if cooldownFontString then
        Pixel.ApplyFont(cooldownFontString, settings.cooldownTextSize, BUI.GetTrackingFont())
        cooldownFontString:ClearAllPoints()
        cooldownFontString:SetPoint(cooldownPosition, icon.cd, cooldownPosition, Pixel.Scale(cooldownOffsetX), Pixel.Scale(cooldownOffsetY))
    end

    local borderColor = settings.borderColor
    Pixel.ApplyBorder(icon, borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    Pixel.ShowBorder(icon)
end

local entryPool = {}
local poolCursor = 0

local function AcquireEntry()
    poolCursor = poolCursor + 1
    local entry = entryPool[poolCursor]
    if not entry then
        entry = {}
        entryPool[poolCursor] = entry
    else
        entry.id = nil; entry.icon = nil; entry.cnt = nil
        entry.slot = nil; entry.iconType = nil; entry.itemID = nil
        entry.hasCharges = nil; entry.hiddenKey = nil; entry.prio = nil
    end
    return entry
end

local function ConsumableCount(itemID, priority)
    return BUI.CDM.Custom.AggregateCountPrio(itemID, priority)
end

local seenScratch = {}
local racialScratch = {}

local function CollectItems(settings, outEntries)
    poolCursor = 0
    wipe(outEntries)
    wipe(seenScratch)
    local count = 0
    local hidden = settings.hiddenIcons
    local seen = seenScratch

    local blacklist = settings.trinketBlacklist
    if settings.showTrinkets then
        local usableOnly = settings.trinketsUsableOnly == true
        for slotIndex = 1, #TRINKET_SLOTS do
            local slot = TRINKET_SLOTS[slotIndex]
            local itemID = GetInventoryItemID("player", slot)
            local hideKey = "auto:slot:" .. slot
            local slotHidden = hidden and hidden[hideKey]
            local itemBlacklisted = blacklist and itemID and blacklist[itemID]

            local passive = usableOnly and itemID and (C_Item.GetItemSpell(itemID) == nil)
            if itemID and not slotHidden and not itemBlacklisted and not passive then
                local entry = AcquireEntry()
                entry.id = itemID
                entry.itemID = itemID
                entry.icon = GetInventoryItemTexture("player", slot)
                entry.slot = slot
                entry.iconType = "trinket"
                entry.hiddenKey = hideKey
                count = count + 1
                outEntries[count] = entry
                seen[itemID] = true
            end
        end
    end

    if settings.showRacials then
        local racials = BUI.CDM.GetKnownRacialSpellIDs(racialScratch)
        for racialIndex = 1, #racials do
            local racialSpellID = racials[racialIndex]
            local hideKey = "auto:racial:" .. racialSpellID
            if not seen[racialSpellID] and not (hidden and hidden[hideKey]) then
                local info = C_Spell.GetSpellInfo(racialSpellID)
                if info then
                    local charges = C_Spell.GetSpellCharges(racialSpellID)
                    local entry = AcquireEntry()
                    entry.id = racialSpellID
                    entry.icon = info.iconID
                    entry.iconType = "spell"
                    entry.hiddenKey = hideKey
                    entry.hasCharges = charges ~= nil and (charges.maxCharges or 0) > 1
                    if entry.hasCharges then
                        entry.cnt = C_Spell.GetSpellDisplayCount(racialSpellID)
                    end
                    count = count + 1
                    outEntries[count] = entry
                    seen[racialSpellID] = true
                end
            end
        end
    end

    local customSpells = settings.customSpells
    if customSpells then
        for _, stored in ipairs(customSpells) do
            local entryID, isItem, isExplicitSpell = IconEngine.ExtractSpellItemID(stored)
            if entryID and not (hidden and hidden[entryID]) then
                local iconType, itemID = IconEngine.ClassifyAsSpellOrItem(entryID, isItem, nil, isExplicitSpell)
                if iconType == "spell" then
                    local info = C_Spell.GetSpellInfo(entryID)
                    local isUnusableRacial = BUI.CDM.IsRacialSpell(entryID)
                        and not C_SpellBook.IsSpellKnown(entryID)
                    if info and not seen[entryID] and not isUnusableRacial then
                        local charges = C_Spell.GetSpellCharges(entryID)
                        local entry = AcquireEntry()
                        entry.id = entryID
                        entry.icon = info.iconID
                        entry.iconType = "spell"
                        entry.hasCharges = charges ~= nil and (charges.maxCharges or 0) > 1
                        if entry.hasCharges then
                            entry.cnt = C_Spell.GetSpellDisplayCount(entryID)
                        end
                        count = count + 1
                        outEntries[count] = entry
                        seen[entryID] = true
                    end
                elseif iconType == "trinket" then
                    local checkID = itemID or entryID
                    if not seen[checkID] then
                        local entry = AcquireEntry()
                        entry.id = checkID
                        entry.itemID = checkID
                        entry.icon = C_Item.GetItemIconByID(checkID) or 134400
                        entry.iconType = "trinket"
                        count = count + 1
                        outEntries[count] = entry
                        seen[checkID] = true
                    end
                elseif iconType == "consumable" then
                    local checkID = itemID or entryID
                    if not seen[checkID] then
                        local priority
                        priority = BUI.CDM.GetPotionPrioFor(stored)
                        local bagCount, bestID = ConsumableCount(checkID, priority)
                        local empty = (bagCount or 0) <= 0
                        local hideAtZero = settings.hideWhenZero and settings.hideWhenZero[entryID] and empty
                        local hideNoBags = settings.hideIfNotInBags and empty and not IsEquippedItem(checkID)
                        if not hideAtZero and not hideNoBags then
                            local entry = AcquireEntry()
                            entry.id = checkID
                            entry.itemID = checkID
                            entry.icon = C_Item.GetItemIconByID(bestID or checkID) or 134400
                            entry.iconType = "consumable"
                            entry.cnt = bagCount or 0
                            entry.prio = priority
                            count = count + 1
                            outEntries[count] = entry
                            seen[checkID] = true
                        end
                    end
                end
            end
        end
    end

    return count
end

local positionConfig = {}
local function PositionBar(bar, settings)
    local frame = bar.frame

    local strata = settings.frameStrata
    if VALID_STRATA[strata] then frame:SetFrameStrata(strata) end
    if type(settings.frameLevel) == "number" then
        frame:SetFrameLevel(math.max(0, math.floor(settings.frameLevel)))
    end

    local anchorPoint = settings.anchorPoint

    local extraY = 0
    local pixelGap = BUI.Pixel.PixelSize(1)
    if anchorPoint == "BOTTOM" or anchorPoint == "BOTTOMLEFT" or anchorPoint == "BOTTOMRIGHT" then
        extraY = -pixelGap
    elseif anchorPoint == "TOP" or anchorPoint == "TOPLEFT" or anchorPoint == "TOPRIGHT" then
        extraY = pixelGap
    end
    positionConfig.anchorFrame = settings.anchorFrame
    positionConfig.anchorPoint = anchorPoint
    positionConfig.anchorOffsetX = settings.anchorOffsetX
    positionConfig.anchorOffsetY = settings.anchorOffsetY + extraY
    positionConfig.posX = settings.posX
    positionConfig.posY = settings.posY
    positionConfig.noGap = true
    BUI.Anchor.ApplyPosition(frame, positionConfig)

    local anchored = frame._isAnchored
    BUI.Dragging.SetLocked(frame, settings.locked)

    if not settings.locked and frame.dragHint then
        if anchored then
            frame.dragHint.text:SetText("Anchored | Right-click to Lock")
            frame.dragHint:Show()
            frame:EnableMouse(false)
        else
            frame.dragHint.text:SetText("Drag to Reposition | Right-click to Lock")
        end
        if not frame._hintSizeTimer then
            frame._hintSizeTimer = true
            C_Timer.After(0, function()
                frame._hintSizeTimer = nil
                if frame.dragHint and frame.dragHint:IsShown() then
                    frame.dragHint:SetWidth(Pixel.Scale(frame.dragHint.text:GetStringWidth() + 16))
                end
            end)
        end
    end
end

local itemsBuffer = {}
local RefreshCooldowns

local function UpdateBar(index)
    local bar = bars[index]
    if not bar then return end
    if bar.frame.dragActive then return end

    local settings = GetBar(index)
    if not settings or not settings.enabled then
        bar.frame:Hide()
        return
    end

    local opacity = BUI.Visibility.GetContextualOpacity("CustomBars") / 100
    opacity = opacity * (settings.barOpacity / 100)
    if opacity <= 0 then
        bar.frame:Hide()
        return
    end

    local count = CollectItems(settings, itemsBuffer)

    for iconIndex = 1, #bar.icons do bar.icons[iconIndex]:Hide() end
    if bar.preview then bar.preview:Hide() end

    local size = settings.iconSize
    local gap = Pixel.Scale(settings.spacing)
    local scaledSize = Pixel.Scale(size)
    local growRight = settings.growDirection == "RIGHT"
    local growDown = settings.growVertical ~= "UP"
    local maxPerRow = settings.maxPerRow > 0 and settings.maxPerRow or 9999
    local cursorAnchored = settings.anchorFrame == "Mouse"

    for iconIndex = 1, count do
        local entry = itemsBuffer[iconIndex]
        local icon = bar.icons[iconIndex] or CreateIcon(bar.frame, index, iconIndex)
        bar.icons[iconIndex] = icon

        if icon.itemID ~= entry.id then
            icon._trinketSpellID = nil
            icon._lastBestTier = nil
        end

        icon.itemID = entry.id
        icon.slot = entry.slot
        icon.iconType = entry.iconType
        icon.hasCharges = entry.hasCharges
        icon.potionPrio = entry.prio
        icon.tex:SetTexture(entry.icon)

        if entry.iconType == "spell" then
            local charges = IconEngine.ApplySpellVisual(icon.tex, icon.cd, entry.id, entry.hasCharges, bar.expiryCb, true)
            if entry.hasCharges and settings.showStackText then
                icon.stack:SetText(charges ~= nil and C_StringUtil.TruncateWhenZero(charges) or "")
                icon.stack:Show()
            elseif settings.showStackText and entry.cnt then
                icon.stack:SetText(entry.cnt)
                icon.stack:Show()
            else
                icon.stack:Hide()
            end
        elseif entry.iconType == "trinket" then
            if icon._trinketSpellID == nil then
                local _, spellID = GetItemSpell(entry.id)
                icon._trinketSpellID = spellID or false
            end
            IconEngine.ApplyTrinketVisual(icon.tex, icon.cd, entry.id, icon._trinketSpellID or nil, bar.expiryCb, icon.stack)
        elseif entry.iconType == "consumable" then
            if settings.showStackText and entry.cnt then
                icon.stack:SetText(entry.cnt)
                icon.stack:Show()
            else
                icon.stack:Hide()
            end
            IconEngine.ApplyItemVisual(icon.tex, icon.cd, nil, nil, entry.cnt or 0, entry.id, bar.expiryCb)
        end
        icon.cd:SetHideCountdownNumbers(not settings.showCooldownText)

        StyleIcon(icon, settings)
        icon:ClearAllPoints()

        local column = (iconIndex - 1) % maxPerRow
        local row = math.floor((iconIndex - 1) / maxPerRow)
        local offsetX = column * (scaledSize + gap)
        local offsetY = row * (scaledSize + gap)

        local horizontalAnchor = growRight and "LEFT" or "RIGHT"
        local verticalAnchor = growDown and "TOP" or "BOTTOM"
        local anchor = verticalAnchor .. horizontalAnchor
        icon:SetPoint(anchor, bar.frame, anchor, growRight and offsetX or -offsetX, growDown and -offsetY or offsetY)
        icon:Show()
        icon:EnableMouse(not cursorAnchored)
        icon:SetHitRectInsets(0, 0, 0, 0)
        icon.hl:SetShown(iconIndex == 1 and not settings.locked)
    end

    if count > 0 then
        local columnCount = math.min(count, maxPerRow)
        local rowCount = math.ceil(count / maxPerRow)
        bar.frame:SetSize(columnCount * scaledSize + (columnCount - 1) * gap, rowCount * scaledSize + (rowCount - 1) * gap)
        bar.frame:SetAlpha(opacity)
        bar.frame:Show()
    elseif not settings.locked then
        if not bar.preview then
            bar.preview = CreateIcon(bar.frame, index, 999)
            bar.preview.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        StyleIcon(bar.preview, settings)
        bar.preview:ClearAllPoints()
        bar.preview:SetPoint("CENTER")
        bar.preview.hl:Show()
        bar.preview:Show()
        bar.preview:EnableMouse(not cursorAnchored)
        bar.preview:SetHitRectInsets(0, 0, 0, 0)
        bar.frame:SnapSize(size)
        bar.frame:SetAlpha(opacity)
        bar.frame:Show()
    else
        bar.frame:Hide()
    end
end

local cooldownFrameCache = {}
local cooldownFrameTime = -1

local function GetFrameCachedSpellCooldown(spellID)
    local now = GetTime()
    if now ~= cooldownFrameTime then
        cooldownFrameTime = now
        wipe(cooldownFrameCache)
    end
    local entry = cooldownFrameCache[spellID]
    if entry == nil then
        entry = C_Spell.GetSpellCooldown(spellID) or false
        cooldownFrameCache[spellID] = entry
    end
    return entry or nil
end

RefreshCooldowns = function(index)
    local bar = bars[index]
    if not (bar and bar.frame:IsShown()) then return end

    local settings = GetBar(index)
    local hideGCD = settings and settings.hideGCD
    local expiryCallback = bar.expiryCb
    for iconIndex = 1, #bar.icons do
        local icon = bar.icons[iconIndex]
        if icon:IsShown() and icon.itemID then
            if icon.iconType == "spell" then
                local charges = IconEngine.ApplySpellVisual(icon.tex, icon.cd, icon.itemID, icon.hasCharges, expiryCallback, true)
                if icon.hasCharges and icon.stack:IsShown() then
                    icon.stack:SetText(charges ~= nil and C_StringUtil.TruncateWhenZero(charges) or "")
                end

                if hideGCD and not icon.hasCharges then
                    local cooldownInfo = GetFrameCachedSpellCooldown(icon.itemID)
                    if cooldownInfo and cooldownInfo.isOnGCD == true then
                        icon.cd:Clear()
                    end
                end
            elseif icon.iconType == "trinket" then
                IconEngine.ApplyTrinketVisual(icon.tex, icon.cd, icon.itemID, icon._trinketSpellID or nil, expiryCallback, icon.stack)
            elseif icon.iconType == "consumable" then
                local count, bestID = ConsumableCount(icon.itemID, icon.potionPrio)
                count = count or 0
                if bestID and bestID ~= icon._lastBestTier then
                    icon._lastBestTier = bestID
                    local textureID = C_Item.GetItemIconByID(bestID)
                    if textureID then icon.tex:SetTexture(textureID) end
                end
                if icon.stack:IsShown() then icon.stack:SetText(count) end
                IconEngine.ApplyItemVisual(icon.tex, icon.cd, nil, nil, count, icon.itemID, expiryCallback)
            end
        end
    end
end

local function CreateBar(index)
    local settings = GetBar(index)
    if not settings then return nil end

    local bar = { icons = {} }
    bar.expiryCb = function() RefreshCooldowns(index) end

    local frame = CreateFrame("Frame", "BUI_TrackingBar" .. index, UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    bar.frame = frame

    BUI.Dragging.MakeDraggable(frame, {
        isLocked = function()
            local settings = GetBar(index)
            return (settings and settings.locked) or frame._isAnchored
        end,
        onPositionChanged = function(x, y)
            local settings = GetBar(index)
            if not settings then return end
            settings.posX, settings.posY = x, y
            local callback = positionCallbacks[index]
            if callback then callback(x, y) end
        end,
        onRightClick = function() LockBar(index) end,
        showHint = true,
    })

    bars[index] = bar
    return bar
end

function CustomBars.RefreshBar(index)
    InvalidateStyle()
    local settings = GetBar(index)
    if not settings then
        local bar = bars[index]
        if bar then bar.frame:Hide() end
        CustomBars.RefreshHotEventRegistration()
        return
    end
    local bar = bars[index] or CreateBar(index)
    PositionBar(bar, settings)
    UpdateBar(index)
    CustomBars.RefreshHotEventRegistration()
end

function CustomBars.RefreshAllBars()
    local settings = GetSettings()
    local maxIndex = #settings
    for index in pairs(bars) do
        if index > maxIndex then maxIndex = index end
    end
    for barIndex = 1, maxIndex do
        CustomBars.RefreshBar(barIndex)
    end
    CustomBars.UpdateOpacity()
    CustomBars.RefreshHotEventRegistration()
end

function CustomBars.UpdateOpacity()
    local settings = GetSettings()
    local globalOpacity = BUI.Visibility.GetContextualOpacity("CustomBars") / 100
    for barIndex = 1, #settings do
        local bar = bars[barIndex]
        if bar then
            local opacity = globalOpacity * (settings[barIndex].barOpacity / 100)
            if opacity <= 0 or not settings[barIndex].enabled then
                bar.frame:Hide()
            else
                bar.frame:SetAlpha(opacity)
                bar.frame:Show()
            end
        end
    end
end

local BAR_DEFAULTS = {
    enabled = true,
    locked = false,
    iconSize = 40,
    spacing = 1,
    zoom = 0.08,
    borderSize = 1,
    borderColor = { 0, 0, 0, 1 },
    growDirection = "RIGHT",
    growVertical = "DOWN",
    maxPerRow = 0,
    showTrinkets = false,
    trinketsUsableOnly = false,
    showRacials = false,
    hideIfNotInBags = false,
    showTooltips = true,
    hiddenIcons = {},
    trinketBlacklist = {},
    showStackText = true,
    showCooldownText = true,
    stackTextPosition = "BOTTOMRIGHT",
    stackTextOffsetX = 0,
    stackTextOffsetY = 0,
    cooldownTextPosition = "CENTER",
    cooldownTextOffsetX = 0,
    cooldownTextOffsetY = 0,
    stackTextSize = 12,
    cooldownTextSize = 14,
    posX = 0,
    posY = 0,
    anchorFrame = "",
    anchorPoint = "BOTTOM",
    anchorOffsetX = 0,
    anchorOffsetY = 0,
    frameStrata = "MEDIUM",
    frameLevel = 5,
    hideGCD = false,
    barOpacity = 100,
}

local function ApplyBarDefaults(bar)
    for key, default in pairs(BAR_DEFAULTS) do
        if bar[key] == nil then
            if type(default) == "table" then
                local copy = {}
                for defaultKey, defaultValue in pairs(default) do copy[defaultKey] = defaultValue end
                bar[key] = copy
            else
                bar[key] = default
            end
        end
    end
end

function CustomBars.AddBar(name)
    local settings = GetSettings()
    local newIndex = #settings + 1
    local bar = { name = name or ("Bar " .. newIndex), customSpells = {} }
    ApplyBarDefaults(bar)
    GetSpellStore()[newIndex] = bar.customSpells
    settings[newIndex] = bar
    CustomBars.RefreshBar(newIndex)
    return newIndex
end

function CustomBars.DeleteBar(index)
    local settings = GetSettings()
    if index < 1 or index > #settings then return false end

    for barIndex = index, #settings do
        local bar = bars[barIndex]
        if bar then
            bar.frame:Hide()
            for iconIndex = 1, #bar.icons do bar.icons[iconIndex]:Hide() end
        end
        bars[barIndex] = nil
    end

    local stores = GetAllSpellStores()
    local profileName = CurrentProfileName()
    local function ShiftDown(lists)
        local maxIndex = #settings
        for storeKey in pairs(lists) do
            if type(storeKey) == "number" and storeKey > maxIndex then maxIndex = storeKey end
        end
        for shiftIndex = index, maxIndex do lists[shiftIndex] = lists[shiftIndex + 1] end
    end
    for _, store in pairs(stores) do
        ShiftDown(store)
        if type(store[profileName]) == "table" then ShiftDown(store[profileName]) end
    end

    table.remove(settings, index)

    CustomBars.RefreshAllBars()
    return true
end

function CustomBars.GetBarCount()
    return #GetSettings()
end


local cooldownDispatchFrame
local function FlushCooldownDispatch(self)
    self:Hide()
    local settings = GetSettings()
    for barIndex = 1, #settings do
        if settings[barIndex].enabled then RefreshCooldowns(barIndex) end
    end
end

local function ScheduleCooldownRefresh()
    if not cooldownDispatchFrame then
        cooldownDispatchFrame = CreateFrame("Frame", "BUI_CustomBarsFlush")
        cooldownDispatchFrame:Hide()
        cooldownDispatchFrame:SetScript("OnUpdate", FlushCooldownDispatch)
    end
    cooldownDispatchFrame:Show()
end

local function OnHotEvent()
    ScheduleCooldownRefresh()
end

local OnEvent = BUI.Dispatcher.NewDelayed(function()
    BUI.CDM.Custom.InvalidateBagCache()
    CustomBars.RefreshAllBars()
end, 0.1)

local hotEventsRegistered = false

local function HasEnabledBar()
    local settings = GetSettings()
    for barIndex = 1, #settings do
        if settings[barIndex].enabled then return true end
    end
    return false
end

function CustomBars.RefreshHotEventRegistration()
    if not eventsRegistered then return end
    local needed = HasEnabledBar()
    if needed and not hotEventsRegistered then
        hotEventsRegistered = true
        BUI.Events:Register("SPELL_UPDATE_COOLDOWN", "CustomBars.Hot",     OnHotEvent)
        BUI.Events:Register("SPELL_UPDATE_CHARGES",  "CustomBars.Charges", OnHotEvent)
        BUI.Events:Register("BAG_UPDATE_COOLDOWN",   "CustomBars.BagCD",   OnHotEvent)
    elseif not needed and hotEventsRegistered then
        hotEventsRegistered = false
        BUI.Events:Unregister("SPELL_UPDATE_COOLDOWN", "CustomBars.Hot")
        BUI.Events:Unregister("SPELL_UPDATE_CHARGES",  "CustomBars.Charges")
        BUI.Events:Unregister("BAG_UPDATE_COOLDOWN",   "CustomBars.BagCD")
    end
end

function CustomBars.Enable()
    if eventsRegistered then
        CustomBars.RefreshAllBars()
        return
    end
    eventsRegistered = true

    BUI.Events:Register("PLAYER_EQUIPMENT_CHANGED", "CustomBars", OnEvent)
    BUI.Events:Register("BAG_UPDATE_DELAYED",       "CustomBars", OnEvent)
    BUI.Events:Register("ITEM_COUNT_CHANGED",       "CustomBars", OnEvent)
    BUI.Events:Register("PLAYER_ENTERING_WORLD",    "CustomBars", OnEvent)
    CustomBars.RefreshHotEventRegistration()

    BUI.Visibility.Register("CustomBars", CustomBars.UpdateOpacity, true)

    Pixel.OnScaleChange("CustomBars", CustomBars.RefreshAllBars)
    BUI.Anchor.RegisterCallback("CustomBars", CustomBars.RefreshAllBars)

    CustomBars.RefreshAllBars()
end

local function RunMigrations(db)
    if db.trackingBars then
        if next(db.trackingBars) and not next(db.customBars) then
            db.customBars = db.trackingBars
        end
        db.trackingBars = nil
    end
    if db.modules and db.modules.tracking ~= nil then
        db.modules.customBars = db.modules.tracking
        db.modules.tracking = nil
    end
    local global = BUI.db.global
    if global.charTrackingSpells then
        if not global.charCustomBarsSpells then
            global.charCustomBarsSpells = global.charTrackingSpells
        end
        global.charTrackingSpells = nil
    end

    if db.tracking then
        local hasReal = db.customBars[1] and db.customBars[1].name
        if not hasReal then
            local tracking = db.tracking
            db.customBars = { [1] = {
                name = "Consumables", enabled = tracking.enabled ~= false,
                locked = tracking.locked, iconSize = tracking.iconSize, spacing = tracking.spacing,
                zoom = tracking.zoom or 0.08, borderSize = tracking.borderSize, borderColor = tracking.borderColor,
                growDirection = tracking.growDirection, growVertical = tracking.growVertical, maxPerRow = tracking.maxPerRow,
                showTrinkets = tracking.showTrinkets, showStackText = tracking.showStackText, showCooldownText = tracking.showCooldownText,
                stackTextPosition = tracking.stackTextPosition, stackTextOffsetX = tracking.stackTextOffsetX, stackTextOffsetY = tracking.stackTextOffsetY,
                cooldownTextPosition = tracking.cooldownTextPosition, cooldownTextOffsetX = tracking.cooldownTextOffsetX, cooldownTextOffsetY = tracking.cooldownTextOffsetY,
                stackTextSize = tracking.stackTextSize, cooldownTextSize = tracking.cooldownTextSize,
                posX = tracking.posX, posY = tracking.posY, anchorFrame = tracking.anchorFrame,
                anchorPoint = tracking.anchorPoint or "BOTTOM", anchorOffsetX = tracking.anchorOffsetX, anchorOffsetY = tracking.anchorOffsetY,
                customSpells = {},
            }}
            if tracking.customItems then
                local destination = db.customBars[1].customSpells
                for _, itemID in ipairs(tracking.customItems) do
                    destination[#destination + 1] = "item:" .. itemID
                end
            end
        end
        db.tracking = nil
    end

    for _, bar in ipairs(db.customBars) do
        if bar.items or bar.spells then
            bar.customSpells = bar.customSpells or {}
            local list, seen = bar.customSpells, {}
            for _, value in ipairs(list) do seen[tostring(value)] = true end
            for _, itemID in ipairs(bar.items or {}) do
                local stored = "item:" .. itemID
                if not seen[stored] then list[#list + 1] = stored; seen[stored] = true end
            end
            for _, spellID in ipairs(bar.spells or {}) do
                if not seen[tostring(spellID)] then list[#list + 1] = spellID; seen[tostring(spellID)] = true end
            end
            bar.items, bar.spells, bar.blacklist = nil, nil, nil
        end
    end

    for _, bar in ipairs(db.customBars) do
        if not bar._trinketMigrated and bar.name and bar.name:lower():find('trinket') and not bar.showTrinkets then
            bar.showTrinkets = true
            if bar.customSpells then
                local kept = {}
                for _, value in ipairs(bar.customSpells) do
                    local itemID = tonumber(tostring(value):match('^item:(%d+)$'))
                    if itemID then
                        local _, _, _, equipSlot = C_Item.GetItemInfoInstant(itemID)
                        if equipSlot ~= 'INVTYPE_TRINKET' then kept[#kept + 1] = value end
                    else
                        kept[#kept + 1] = value
                    end
                end
                bar.customSpells = kept
            end
            bar._trinketMigrated = true
            BUI.Print('Bar "' .. bar.name .. '" now scans trinkets.')
        end
    end
end

local function BindSpellLists(db)
    local store = GetSpellStore()
    for barIndex, bar in ipairs(db.customBars) do
        if store[barIndex] == nil then
            local seed = {}
            if bar.customSpells then
                for spellIndex, spell in ipairs(bar.customSpells) do seed[spellIndex] = spell end
            end
            store[barIndex] = seed
        end
        bar.customSpells = store[barIndex]
    end
end

function CustomBars.AdoptProfileSpells()
    local db = BUI.GetDB()
    local store = GetSpellStore()
    local count = #db.customBars
    for barIndex, bar in ipairs(db.customBars) do
        bar.customSpells = bar.customSpells or {}
        store[barIndex] = bar.customSpells
    end
    for storeKey in pairs(store) do
        if type(storeKey) == "number" and storeKey > count then store[storeKey] = nil end
    end
end

function CustomBars.Initialize()
    local db = BUI.GetDB()
    RunMigrations(db)
    BindSpellLists(db)
    for _, bar in ipairs(db.customBars) do ApplyBarDefaults(bar) end
    CustomBars.Enable()
end

BUI.Events:OnLogin("CustomBars", function() CustomBars.Initialize() end, "customBars")
