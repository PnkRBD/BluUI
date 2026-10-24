local _, BUI = ...

local CustomBars = {}
BUI.CustomBars = CustomBars

local Pixel = BUI.Pixel
local IconEngine = BUI.IconEngine
local AggregateCountPrio = BUI.CDM.Custom.AggregateCountPrio

local TRINKET_SLOTS = { 13, 14 }
local CORNER_OFFSETS = {
    TOPLEFT = { 2, -2 }, TOP = { 0, -2 }, TOPRIGHT = { -2, -2 },
    LEFT = { 2, 0 }, CENTER = { 0, 0 }, RIGHT = { -2, 0 },
    BOTTOMLEFT = { 2, 2 }, BOTTOM = { 0, 2 }, BOTTOMRIGHT = { -2, 2 },
}

local bars = {}
local eventsRegistered = false
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
    return BUI.GetDB().customBars
end

local function GetBar(index)
    return GetSettings()[index]
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

local UNCOPIED_KEYS = { name = true, posX = true, posY = true, customSpells = true }

local function CopyBar(destination, source, spells)
    if source then
        for key, value in pairs(source) do
            if not UNCOPIED_KEYS[key] then
                if type(value) == "table" then
                    local copy = {}
                    for tableKey, tableValue in pairs(value) do copy[tableKey] = tableValue end
                    destination[key] = copy
                else
                    destination[key] = value
                end
            end
        end
    end
    wipe(destination.customSpells)
    for spellIndex, spell in ipairs(spells) do destination.customSpells[spellIndex] = spell end
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
            CopyBar(settings[newIndex], sourceBar, list)
        end
    end
    CustomBars.RefreshAllBars()
end

function CustomBars.DuplicateBar(index)
    local source = GetBar(index)
    local newIndex = CustomBars.AddBar(source.name .. " copy")
    CopyBar(GetBar(newIndex), source, source.customSpells)
    CustomBars.RefreshBar(newIndex)
    return newIndex
end

local function LockBar(index)
    local settings = GetBar(index)
    if not settings or settings.locked then return end
    settings.locked = true
    BUI.NotifyModuleChange('customBars')
    CustomBars.RefreshBar(index)
end

local function IsDragBlocked(index)
    return GetBar(index).locked or bars[index].frame._isAnchored
end

local function CreateIcon(parent, barIndex, iconIndex)
    local icon = CreateFrame("Frame", "BUI_TrackBar" .. barIndex .. "Icon" .. iconIndex, parent)
    icon:SnapSize(40)
    icon:EnableMouse(true)
    icon:RegisterForDrag("LeftButton")

    icon:SetScript("OnDragStart", BUI.Profiler.Script('CDM.CustomBars icon OnDragStart', function()
        if IsDragBlocked(barIndex) then return end
        parent.dragActive = true
        parent:StartMoving()
    end))
    icon:SetScript("OnDragStop", BUI.Profiler.Script('CDM.CustomBars icon OnDragStop', function()
        parent:StopMovingOrSizing()
        parent.dragActive = false
        local settings = GetBar(barIndex)
        if settings and not parent._isAnchored then
            settings.posX, settings.posY = BUI.Dragging.GetCenterOffset(parent)
        end
    end))
    icon:SetScript("OnMouseUp", BUI.Profiler.Script('CDM.CustomBars icon OnMouseUp', function(_, button)
        if button == "RightButton" and not parent.dragActive then
            LockBar(barIndex)
        end
    end))

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

    icon:SetScript("OnEnter", BUI.Profiler.Script('CDM.CustomBars icon OnEnter', function()
        if not GetBar(barIndex).showTooltips then return end
        if not icon.itemID then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        if icon.iconType == "spell" then
            GameTooltip:SetSpellByID(icon.itemID)
        else
            GameTooltip:SetItemByID(icon.itemID)
        end
        GameTooltip:Show()
    end))
    icon:SetScript("OnLeave", BUI.Profiler.Script('CDM.CustomBars icon OnLeave', function() GameTooltip:Hide() end))
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
    local stackOffset = CORNER_OFFSETS[stackPosition]
    icon.stack:ClearAllPoints()
    icon.stack:SetPoint(stackPosition, icon, stackPosition,
        Pixel.Scale(settings.stackTextOffsetX + stackOffset[1]),
        Pixel.Scale(settings.stackTextOffsetY + stackOffset[2]))
    Pixel.ApplyFont(icon.stack, settings.stackTextSize, BUI.GetTrackingFont())

    local cooldownPosition = settings.cooldownTextPosition
    local cooldownOffset = CORNER_OFFSETS[cooldownPosition]
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
        entry.iconType = nil; entry.hasCharges = nil; entry.prio = nil
    end
    return entry
end

local seenScratch = {}
local racialScratch = {}
local placedScratch = {}
local knownScratch = {}
local customScratch = {}
local SLOT_KEYS = {}
for _, slot in ipairs(TRINKET_SLOTS) do SLOT_KEYS[slot] = "auto:slot:" .. slot end
local racialKeys = {}

local function RacialKey(spellID)
    local key = racialKeys[spellID]
    if not key then
        key = "auto:racial:" .. spellID
        racialKeys[spellID] = key
    end
    return key
end

local function AutoToken(stored)
    if type(stored) ~= "string" or stored:sub(1, 5) ~= "auto:" then return end
    local slot = tonumber(stored:match("^auto:slot:(%d+)$"))
    if slot and SLOT_KEYS[slot] then return "slot", slot end
    local racial = tonumber(stored:match("^auto:racial:(%d+)$"))
    if racial then return "racial", racial end
end

function CustomBars.SlotKey(slot)
    return SLOT_KEYS[slot]
end

CustomBars.RacialKey = RacialKey

function CustomBars.ForEachIcon(settings, visit)
    local spells = settings.customSpells
    local placed, known, custom = wipe(placedScratch), wipe(knownScratch), wipe(customScratch)
    for _, stored in ipairs(spells) do
        if AutoToken(stored) then
            placed[stored] = true
        else
            local id, isItem = IconEngine.ExtractSpellItemID(stored)
            if id and not isItem then custom[id] = true end
        end
    end
    if settings.showTrinkets then
        for _, slot in ipairs(TRINKET_SLOTS) do
            if not placed[SLOT_KEYS[slot]] then visit("slot", slot) end
        end
    end
    if settings.showRacials then
        for _, spellID in ipairs(BUI.CDM.GetKnownRacialSpellIDs(racialScratch)) do
            known[spellID] = true
            if not placed[RacialKey(spellID)] and not custom[spellID] then visit("racial", spellID) end
        end
    end
    for _, stored in ipairs(spells) do
        local kind, value = AutoToken(stored)
        if kind == "slot" then
            if settings.showTrinkets then visit("slot", value) end
        elseif kind == "racial" then
            if known[value] and not custom[value] then visit("racial", value) end
        else
            visit("custom", stored)
        end
    end
end

local collectSettings, collectOut, collectCount

local function Collect(entry)
    collectCount = collectCount + 1
    collectOut[collectCount] = entry
    seenScratch[entry.id] = true
end

local function CollectSlot(slot)
    local settings = collectSettings
    local itemID = GetInventoryItemID("player", slot)
    local hideKey = SLOT_KEYS[slot]
    if not itemID or settings.hiddenIcons[hideKey] or settings.trinketBlacklist[itemID] then return end
    if settings.trinketsUsableOnly and IconEngine.GetItemSpellID(itemID) == nil then return end
    local entry = AcquireEntry()
    entry.id = itemID
    entry.icon = GetInventoryItemTexture("player", slot)
    entry.iconType = "trinket"
    Collect(entry)
end

local function CollectRacial(spellID)
    local hideKey = RacialKey(spellID)
    if seenScratch[spellID] or collectSettings.hiddenIcons[hideKey] then return end
    local iconID = C_Spell.GetSpellTexture(spellID)
    if not iconID then return end
    local charges = C_Spell.GetSpellCharges(spellID)
    local entry = AcquireEntry()
    entry.id = spellID
    entry.icon = iconID
    entry.iconType = "spell"
    entry.hasCharges = charges ~= nil and charges.maxCharges > 1
    Collect(entry)
end

local function CollectCustom(stored)
    local settings = collectSettings
    local entryID, isItem, isExplicitSpell = IconEngine.ExtractSpellItemID(stored)
    if not entryID or settings.hiddenIcons[entryID] then return end
    local iconType, itemID = IconEngine.ClassifyAsSpellOrItem(entryID, isItem, nil, isExplicitSpell)
    if iconType == "spell" then
        if seenScratch[entryID] then return end
        if BUI.CDM.IsRacialSpell(entryID) and not C_SpellBook.IsSpellKnown(entryID) then return end
        local iconID = C_Spell.GetSpellTexture(entryID)
        if not iconID then return end
        local charges = C_Spell.GetSpellCharges(entryID)
        local entry = AcquireEntry()
        entry.id = entryID
        entry.icon = iconID
        entry.iconType = "spell"
        entry.hasCharges = charges ~= nil and charges.maxCharges > 1
        Collect(entry)
    elseif iconType == "trinket" then
        local checkID = itemID or entryID
        if seenScratch[checkID] then return end
        local entry = AcquireEntry()
        entry.id = checkID
        entry.icon = C_Item.GetItemIconByID(checkID) or 134400
        entry.iconType = "trinket"
        Collect(entry)
    elseif iconType == "consumable" then
        local checkID = itemID or entryID
        if seenScratch[checkID] then return end
        local priority = BUI.CDM.GetPotionPrioFor(stored)
        local bagCount, bestID = AggregateCountPrio(checkID, priority)
        if bagCount <= 0 then
            if settings.hideWhenZero and settings.hideWhenZero[entryID] then return end
            if settings.hideIfNotInBags and not C_Item.IsEquippedItem(checkID) then return end
        end
        local entry = AcquireEntry()
        entry.id = checkID
        entry.icon = C_Item.GetItemIconByID(bestID or checkID) or 134400
        entry.iconType = "consumable"
        entry.cnt = bagCount
        entry.prio = priority
        Collect(entry)
    end
end

local function CollectVisit(kind, value)
    if kind == "slot" then
        CollectSlot(value)
    elseif kind == "racial" then
        CollectRacial(value)
    else
        CollectCustom(value)
    end
end

local function CollectItems(settings, outEntries)
    poolCursor = 0
    wipe(outEntries)
    wipe(seenScratch)
    collectSettings, collectOut, collectCount = settings, outEntries, 0
    CustomBars.ForEachIcon(settings, CollectVisit)
    return collectCount
end

local shownBuffer = {}

function CustomBars.ShownIcons(settings)
    local icons = {}
    for index = 1, CollectItems(settings, shownBuffer) do icons[index] = shownBuffer[index].icon end
    return icons
end

local positionConfig = {}
local function PositionBar(bar, settings)
    local frame = bar.frame

    frame:SetFrameStrata(settings.frameStrata)
    frame:SetFrameLevel(settings.frameLevel)

    local anchorPoint = settings.anchorPoint

    local extraY = 0
    local pixelGap = Pixel.PixelSize(1)
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

    if not settings.locked then
        if anchored then
            frame.dragHint.text:SetText("Anchored | Right-click to Lock")
            frame.dragHint:Show()
            frame:EnableMouse(false)
        else
            frame.dragHint.text:SetText("Drag to Reposition | Right-click to Lock")
        end
        frame.dragHint:SetWidth(Pixel.Scale(frame.dragHint.text:GetStringWidth() + 16))
    end
end

local itemsBuffer = {}
local RefreshCooldowns

local function UpdateBar(index)
    local bar = bars[index]
    if not bar then return end
    if bar.frame.dragActive then return end

    local settings = GetBar(index)
    if not settings.enabled then
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

        icon.itemID = entry.id
        icon.iconType = entry.iconType
        icon.hasCharges = entry.hasCharges
        icon.count = entry.cnt
        icon.prio = entry.prio
        icon.tex:SetTexture(entry.icon)

        if entry.iconType == "spell" then
            local cooldownInfo = C_Spell.GetSpellCooldown(entry.id)
            IconEngine.SpellCooldownChanged(icon, entry.id, entry.hasCharges, cooldownInfo)
            local charges = IconEngine.ApplySpellVisual(icon.tex, icon.cd, entry.id, entry.hasCharges, bar.expiryCb, true, settings.hideGCD, nil, nil, cooldownInfo)
            if entry.hasCharges and settings.showStackText then
                icon.stack:SetText(charges ~= nil and C_StringUtil.TruncateWhenZero(charges) or "")
                icon.stack:Show()
            else
                icon.stack:Hide()
            end
        elseif entry.iconType == "trinket" then
            IconEngine.ApplyTrinketVisual(icon.tex, icon.cd, entry.id, IconEngine.GetItemSpellID(entry.id), bar.expiryCb, icon.stack)
        elseif entry.iconType == "consumable" then
            if settings.showStackText then
                icon.stack:SetText(entry.cnt)
                icon.stack:Show()
            else
                icon.stack:Hide()
            end
            IconEngine.ApplyItemVisual(icon.tex, icon.cd, entry.cnt, entry.id, bar.expiryCb)
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
    bar.count = count

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

local function RefreshSpellIcon(icon, expiryCallback, hideGCD)
    local spellID = icon.itemID
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    local isUsable, notEnoughPower = C_Spell.IsSpellUsable(spellID)
    local cooldownChanged = IconEngine.SpellCooldownChanged(icon, spellID, icon.hasCharges, cooldownInfo)
    if not (cooldownChanged or IconEngine.SpellUsableChanged(icon.tex, isUsable, notEnoughPower)) then return end
    local charges = IconEngine.ApplySpellVisual(icon.tex, icon.cd, spellID, icon.hasCharges, expiryCallback, true, hideGCD, isUsable, notEnoughPower, cooldownInfo)
    if icon.hasCharges and icon.stack:IsShown() then
        icon.stack:SetText(charges ~= nil and C_StringUtil.TruncateWhenZero(charges) or "")
    end
end

local function RefreshItemCount(icon)
    local count = AggregateCountPrio(icon.itemID, icon.prio)
    if count == icon.count then return false end
    icon.count = count
    if icon.stack:IsShown() then icon.stack:SetText(count) end
    return true
end

RefreshCooldowns = function(index, spells, items, counts)
    local bar = bars[index]
    if not (bar and bar.frame:IsShown()) then return end

    local hideGCD = GetBar(index).hideGCD
    local expiryCallback = bar.expiryCb
    local icons = bar.icons
    for iconIndex = 1, bar.count do
        local icon = icons[iconIndex]
        local iconType = icon.iconType
        if iconType == "spell" then
            if spells then RefreshSpellIcon(icon, expiryCallback, hideGCD) end
        elseif iconType == "trinket" then
            IconEngine.ApplyTrinketVisual(icon.tex, icon.cd, icon.itemID, IconEngine.GetItemSpellID(icon.itemID), expiryCallback, icon.stack)
        else
            local countChanged = counts and RefreshItemCount(icon)
            if items or countChanged then
                IconEngine.ApplyItemVisual(icon.tex, icon.cd, icon.count, icon.itemID, expiryCallback)
            end
        end
    end
end

local function CreateBar(index)
    local settings = GetBar(index)
    if not settings then return nil end

    local bar = { icons = {}, count = 0 }
    bar.expiryCb = function() RefreshCooldowns(index, true, true) end

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
        end,
        onRightClick = function() LockBar(index) end,
        showHint = true,
    })

    bars[index] = bar
    return bar
end

function CustomBars.RefreshBar(index)
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
end

local function RepositionAnchoredBars()
    local settings = GetSettings()
    for index, bar in pairs(bars) do
        local barSettings = settings[index]
        if barSettings and barSettings.anchorFrame ~= "" then PositionBar(bar, barSettings) end
    end
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


local spellCooldownsPending, itemCooldownsPending, itemCountsPending = false, false, false

local function FlushCooldownDispatch()
    local spells, items, counts = spellCooldownsPending, itemCooldownsPending, itemCountsPending
    spellCooldownsPending, itemCooldownsPending, itemCountsPending = false, false, false
    local settings = GetSettings()
    for barIndex = 1, #settings do
        if settings[barIndex].enabled then RefreshCooldowns(barIndex, spells, items, counts) end
    end
end

local QueueCooldownFlush = BUI.Dispatcher.New(FlushCooldownDispatch, "CustomBars.Cooldowns")

local function OnSpellCooldownEvent()
    spellCooldownsPending = true
    QueueCooldownFlush()
end

local function OnItemCooldownEvent()
    itemCooldownsPending = true
    QueueCooldownFlush()
end

local function OnChargesEvent()
    spellCooldownsPending = true
    itemCountsPending = true
    QueueCooldownFlush()
end

local function HasEnabledBar()
    local settings = GetSettings()
    for barIndex = 1, #settings do
        if settings[barIndex].enabled then return true end
    end
    return false
end

local OnEvent = BUI.Dispatcher.NewDelayed(function()
    if HasEnabledBar() then BUI.CDM.Custom.InvalidateStaleBagCache() end
    CustomBars.RefreshAllBars()
end, 0.1, 'Custom bars bag refresh')

local function OnEnteringWorld(_, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then OnEvent() end
end

local spellEventsRegistered, itemEventsRegistered, chargeEventsRegistered = false, false, false

local function NeededCooldownEvents()
    local settings = GetSettings()
    local wantSpells, wantItems, wantCounts = false, false, false
    for barIndex = 1, #settings do
        local bar = bars[barIndex]
        if bar and settings[barIndex].enabled then
            local icons = bar.icons
            for iconIndex = 1, bar.count do
                local iconType = icons[iconIndex].iconType
                if iconType ~= "consumable" then wantSpells = true end
                if iconType ~= "spell" then wantItems = true end
                if iconType == "consumable" then wantCounts = true end
            end
        end
    end
    return wantSpells, wantItems, wantCounts
end

function CustomBars.RefreshHotEventRegistration()
    if not eventsRegistered then return end
    local wantSpells, wantItems, wantCounts = NeededCooldownEvents()
    if wantSpells ~= spellEventsRegistered then
        spellEventsRegistered = wantSpells
        if wantSpells then
            BUI.Events:Register("SPELL_UPDATE_COOLDOWN", "CustomBars.Hot", OnSpellCooldownEvent)
        else
            BUI.Events:Unregister("SPELL_UPDATE_COOLDOWN", "CustomBars.Hot")
        end
    end
    local wantCharges = wantSpells or wantCounts
    if wantCharges ~= chargeEventsRegistered then
        chargeEventsRegistered = wantCharges
        if wantCharges then
            BUI.Events:Register("SPELL_UPDATE_CHARGES", "CustomBars.Charges", OnChargesEvent)
        else
            BUI.Events:Unregister("SPELL_UPDATE_CHARGES", "CustomBars.Charges")
        end
    end
    if wantItems ~= itemEventsRegistered then
        itemEventsRegistered = wantItems
        if wantItems then
            BUI.Events:Register("BAG_UPDATE_COOLDOWN", "CustomBars.BagCD", OnItemCooldownEvent)
        else
            BUI.Events:Unregister("BAG_UPDATE_COOLDOWN", "CustomBars.BagCD")
        end
    end
end

function CustomBars.Enable()
    if eventsRegistered then return end
    eventsRegistered = true

    BUI.Events:Register("PLAYER_EQUIPMENT_CHANGED", "CustomBars", OnEvent)
    BUI.Events:Register("BAG_UPDATE_DELAYED",       "CustomBars", OnEvent)
    BUI.Events:Register("ITEM_COUNT_CHANGED",       "CustomBars", OnEvent)
    BUI.Events:Register("PLAYER_ENTERING_WORLD",    "CustomBars", OnEnteringWorld)
    CustomBars.RefreshHotEventRegistration()

    BUI.Visibility.Register("CustomBars", CustomBars.UpdateOpacity, true)

    Pixel.OnScaleChange("CustomBars", CustomBars.RefreshAllBars)
    BUI.Anchor.RegisterCallback("CustomBars", RepositionAnchoredBars)
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
    BindSpellLists(db)
    for _, bar in ipairs(db.customBars) do ApplyBarDefaults(bar) end
    CustomBars.Enable()
end

BUI.Events:OnLogin("CustomBars", function() CustomBars.Initialize() end, "cdm")
