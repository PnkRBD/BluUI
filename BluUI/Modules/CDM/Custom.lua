local _, BUI = ...
local SetScript = BUI.Prof.Scripts('CDM.Custom')

local _G = _G
local wipe = wipe
local type, ipairs, pairs, tonumber = type, ipairs, pairs, tonumber
local next = next

local CreateFrame = CreateFrame
local C_Spell = C_Spell
local C_Container = C_Container
local C_Item = C_Item
local GetItemSpell = GetItemSpell
local IsPlayerSpell = IsPlayerSpell
local IsSpellKnown = IsSpellKnown
local IsEquippedItem = IsEquippedItem

local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT

local function C_Timer_After(delay, callback) BUI.Prof.After('CDM.Custom', delay, callback) end
local C_ClassTalents = C_ClassTalents

local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local CDM = BUI.CDM
local Pixel = BUI.Pixel
local Tools = BUI.Tools
local GlowManager = BUI.GlowManager
local SetColor = BUI.IconEngine.SetColor

local function SafeGetPlayerAura(spellID)
	if not spellID then return nil, false end
	if Tools.ShouldAurasBeSecret() then return nil, true end
	return GetPlayerAuraBySpellID(spellID), false
end

local FrameData = CDM.FrameData
local GetFrameData = CDM.GetFrameData

local GetStableSpellTexture = Tools.GetStableSpellTexture

local manualStartByStored = {}

local warningFrame, warningText
local warningTemplate, warningExpiry, warningSpellName, warningThreshold
local warningShowDecimals, warningLastBucket

local function UpdateWarningText()
	if not warningFrame or not warningFrame:IsShown() then return end
	if not warningExpiry then return end
	local remaining = warningExpiry - GetTime()
	if remaining <= 0 then
		warningFrame:Hide()
		warningExpiry = nil
		warningLastBucket = nil
		return
	end
	local threshold = warningShowDecimals and (warningThreshold or 5) or 0
	local bucket = BUI.TimeFormat.Bucket(remaining, threshold)
	if bucket == warningLastBucket then return end
	warningLastBucket = bucket
	local display = warningTemplate or "BUFF EXPIRING!"
	display = display:gsub("%[time%]", BUI.TimeFormat.Format(remaining, threshold))
	if warningSpellName then
		display = display:gsub("%[name%]", warningSpellName)
	end
	warningText:SetText(display)
end

local warningLastSound

local function ShowBuffWarning(text, color, remaining, spellName, font, _, decimalThreshold)
	if not warningFrame then
		warningFrame = CreateFrame("Frame", nil, UIParent)
		warningFrame:SetSize(Pixel.Scale(500), Pixel.Scale(50))
		warningFrame:SetPoint("CENTER", UIParent, "CENTER", 0, Pixel.Scale(200))
		warningFrame:SetFrameStrata("HIGH")
		warningFrame:SetFrameLevel(99)
		warningText = warningFrame:CreateFontString(nil, "OVERLAY")
		Pixel.ApplyFont(warningText, 28)
		warningText:SetPoint("CENTER")
		SetScript(warningFrame, "OnUpdate", BUI.Prof.Wrap("cdm#BuffWarningText", UpdateWarningText))
	end
	warningTemplate = text or "BUFF EXPIRING!"
	if spellName ~= warningSpellName then warningExpiry = nil end
	warningSpellName = spellName
	warningLastBucket = nil

	if not warningExpiry and remaining then
		warningExpiry = GetTime() + remaining
	end
	if decimalThreshold then warningThreshold = decimalThreshold end
	warningShowDecimals = BUI.GetDB().cdm.buffs.showCooldownDecimals
	if font then
		Pixel.ApplyFont(warningText, 28, font)
	else
		Pixel.ApplyFont(warningText, 28)
	end
	if color then
		warningText:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	else
		warningText:SetTextColor(1, 0.2, 0.2, 1)
	end
	UpdateWarningText()
	warningFrame:Show()
end

local function HideBuffWarning()
	if warningFrame then warningFrame:Hide() end
	warningTemplate = nil
	warningExpiry = nil
	warningSpellName = nil
	warningLastSound = nil
	warningThreshold = nil
	warningShowDecimals = nil
	warningLastBucket = nil
end


local function DeferredGlowActivate(icon, frameData)
    local glowConfig = frameData._deferredGlowCfg
    if not glowConfig then return end
    CDM.StartProcGlow(icon, glowConfig)
    local warning = glowConfig.warning
    if warning then
        if warning.sound and warning.sound ~= 0 then
            warningLastSound = warning.sound
            PlaySound(warning.sound, 'Master')
        end
        if warning.enabled then
            local threshold = glowConfig.threshold or 5
            local spellName = C_Spell.GetSpellName(frameData._deferredGlowSpellID) or tostring(frameData._deferredGlowSpellID)
            ShowBuffWarning(warning.text or "BUFF EXPIRING!", warning.color, threshold, spellName, warning.font, nil, threshold)
        end
    end
    frameData._deferredGlowCfg = nil
    frameData._deferredGlowSpellID = nil
end

local icons = {
    essential = {},
    utility = {},
    buffs = {},
}
local iconCounts = {
    essential = 0,
    utility = 0,
    buffs = 0,
}

local function CopyColor(source)
    if not source then return { 0, 0, 0, 1 } end
    return { source[1] or 0, source[2] or 0, source[3] or 0, source[4] or 1 }
end

local pool = {}
local poolCount = 0

local spellMap = {}
local itemMap = {}

local trinketSlotIcons = {}
local dispatchFrame = nil
local cooldownPending = false
local auraPending = false
local usablePending = false

local buffSpellToIcons = {}
local buffInstanceToIcon = {}
local needsFullBuffScan = false
local changedBuffSpellIDs = {}
local changedBuffInstanceIDs = {}

local function WatchSpell(spellID, icon)
    local set = spellMap[spellID]
    if not set then set = {}; spellMap[spellID] = set end
    set[icon] = true
end

local function WatchItem(itemID, icon)
    local set = itemMap[itemID]
    if not set then set = {}; itemMap[itemID] = set end
    set[icon] = true
end

local function UnwatchIcon(icon)
    local frameData = FrameData[icon]
    if not frameData then return end
    trinketSlotIcons[icon] = nil
    local id = frameData.customSpellID
    if not id then return end
    local set = spellMap[id]
    if set then
        set[icon] = nil
        if not next(set) then spellMap[id] = nil end
    end
    if frameData.itemID then
        set = itemMap[frameData.itemID]
        if set then
            set[icon] = nil
            if not next(set) then itemMap[frameData.itemID] = nil end
        end
    end
    set = buffSpellToIcons[id]
    if set then
        set[icon] = nil
        if not next(set) then buffSpellToIcons[id] = nil end
    end
    if frameData.trackedBuff and frameData.trackedBuff ~= id then
        set = buffSpellToIcons[frameData.trackedBuff]
        if set then
            set[icon] = nil
            if not next(set) then buffSpellToIcons[frameData.trackedBuff] = nil end
        end
    end
    if frameData._auraSpellID and frameData._auraSpellID ~= id then
        set = buffSpellToIcons[frameData._auraSpellID]
        if set then
            set[icon] = nil
            if not next(set) then buffSpellToIcons[frameData._auraSpellID] = nil end
        end
    end
    if frameData._auraInstanceID then
        buffInstanceToIcon[frameData._auraInstanceID] = nil
    end
end

local function AcquireIcon(parent, borderSize, borderColor, zoom)
    if poolCount > 0 then
        local icon = pool[poolCount]
        pool[poolCount] = nil
        poolCount = poolCount - 1
        icon:SetParent(parent)
        icon:Update(borderSize, borderColor, zoom)
        return icon
    end
    return nil
end

local function ResetManualBuffOverlay(icon, frameData)
    if not frameData then return end
    if frameData._manualGlowTimer then
        frameData._manualGlowTimer:Cancel()
        frameData._manualGlowTimer = nil
    end
    frameData._manualGlowActive = nil
    local cooldown = icon and icon.Cooldown
    if cooldown then SetScript(cooldown, "OnCooldownDone", CDM.OnCooldownWidgetDone) end
end

local function ReleaseIcon(icon)
    if not icon then return end
    CDM.StopProcGlow(icon)
    UnwatchIcon(icon)
    local frameData = FrameData[icon]
    ResetManualBuffOverlay(icon, frameData)
    icon:Hide()
    icon:ClearAllPoints()
    icon:SetParent(nil)

    if frameData then
        GlowManager.ResetIconState(frameData)

        frameData.skinVer = nil
        frameData.customIcon = nil
        frameData.customSpellID = nil
        frameData.customKey = nil
        frameData.storedValue = nil
        frameData.isItemByPrefix = nil
        frameData.trinketSlot = nil
        frameData.racialSlot = nil
        frameData.iconType = nil
        frameData.itemID = nil
        frameData.trackedBuff = nil
        frameData.tracked = nil
        frameData.trackIndex = nil
        frameData.anchor = nil
        frameData.posX = nil
        frameData.posY = nil
        frameData.sizeW = nil
        frameData.sizeH = nil
        frameData.hidden = nil
        frameData.glowActive = nil
        frameData.glowType = nil
        frameData.lastCDStart = nil
        frameData._cdFingerStart = nil
        frameData._cdFingerDuration = nil
        frameData._trinketDurObj = nil
        frameData._auraExpiry = nil
        frameData._auraDuration = nil
        frameData.lastCount = nil
        frameData.lastBestTier = nil
        frameData._manualBuff = nil
        frameData._manualStart = nil
        frameData._manualExpiry = nil
        frameData._manualGlowCfg = nil
        frameData._manualGlowThresh = nil
        frameData._manualGlowActive = nil
        frameData._auraSpellID = nil
        frameData._origTexture = nil
        frameData.hasCharges = nil
        frameData.countFont = nil
        frameData.countFontNil = nil
    end
    icon.cooldownInfo = nil
    if icon.Icon then
        icon.Icon:SetVertexColor(1, 1, 1)
        icon.Icon:SetDesaturation(0)
    end
    icon.Count = nil
    if icon._chargeText then
        icon._chargeText:SetText("")
        icon._chargeText:Hide()
    end
    poolCount = poolCount + 1
    pool[poolCount] = icon
end

local GetTime = GetTime

local spellToItemID = {}
local spellToItemCount = {}
local cacheValid = false
local bagItemCounts = {}
local bagItemToSpell = {}

local itemFamily = {}
local familyData = {}
local familyKeyMemo = {}
local familyMembersCache = {}
local pendingItems = {}
local itemLoadFrame
local function GetFamilyKey(id)
    local _, _, _, _, _, itemClass, itemSubclass = C_Item.GetItemInfoInstant(id)
    if itemClass == Enum.ItemClass.Consumable
    and (itemSubclass == Enum.ItemConsumableSubclass.Potion
      or itemSubclass == Enum.ItemConsumableSubclass.Flask) then
        local itemName = C_Item.GetItemInfo(id)
        if itemName then
            return itemName:gsub("|[AT][^|]-|[at]", ""):match("^(.-)%s*$") or itemName
        end
        C_Item.RequestLoadItemDataByID(id)
        pendingItems[id] = true
        if not itemLoadFrame then
            itemLoadFrame = true
            BUI.Events:Register('ITEM_DATA_LOAD_RESULT', 'CDM.Custom.ItemLoad', function(event, itemID, success)
                if pendingItems[itemID] then
                    pendingItems[itemID] = nil
                    if success then
                        cacheValid = false
                        CDM.Custom.Refresh()
                        BUI.CustomBars.RefreshAllBars()
                    end
                end
            end)
        end
    end
end

local function RebuildBagCache()
    wipe(spellToItemID)
    wipe(spellToItemCount)
    wipe(bagItemCounts)
    wipe(bagItemToSpell)
    wipe(itemFamily)
    wipe(familyData)
    wipe(familyMembersCache)

    for bagIndex = 0, 4 do
        for slotIndex = 1, C_Container.GetContainerNumSlots(bagIndex) do
            local slot = C_Container.GetContainerItemInfo(bagIndex, slotIndex)
            if slot and slot.itemID then
                local id = slot.itemID
                bagItemCounts[id] = (bagItemCounts[id] or 0) + slot.stackCount

                if not bagItemToSpell[id] then
                    local _, spellID = GetItemSpell(id)
                    if spellID then bagItemToSpell[id] = spellID end
                end

                if not itemFamily[id] then
                    itemFamily[id] = GetFamilyKey(id)
                end
            end
        end
    end

    for id, itemSpellID in pairs(bagItemToSpell) do
        if (bagItemCounts[id] or 0) > 0 then
            spellToItemID[itemSpellID] = id
            spellToItemCount[itemSpellID] = bagItemCounts[id]
        end
    end

    for id, familyKey in pairs(itemFamily) do
        local itemCount = bagItemCounts[id] or 0
        if itemCount > 0 then
            local family = familyData[familyKey]
            if not family then
                family = { sum = 0, icon = id, breakdown = {} }
                familyData[familyKey] = family
            end
            family.sum = family.sum + itemCount
            family.breakdown[id] = itemCount

            local newQuality = BUI.Lookup.CraftedQuality(id)
            local currentQuality = BUI.Lookup.CraftedQuality(family.icon)
            if newQuality > currentQuality or (newQuality == currentQuality and id > family.icon) then
                family.icon = id
            end
        end
    end

    cacheValid = true
end

local function AggregateCount(id)
    if not cacheValid then RebuildBagCache() end
    local familyKey = itemFamily[id]
    if not familyKey then familyKey = GetFamilyKey(id) end
    if familyKey then
        local family = familyData[familyKey]
        if family then return family.sum, family.icon, family.breakdown end
    end
    return C_Item.GetItemCount(id, true, true), id, nil
end

local function ItemQuality(id)
    return (BUI.Lookup.CraftedQuality(id))
end

local function FamilyMembersFor(baseKey)
    local members = familyMembersCache[baseKey]
    if members ~= nil then
        return members or nil
    end
    local root = baseKey
    for key in pairs(familyData) do
        if key ~= root and #key < #root and root:find(key, 1, true) then root = key end
    end
    members = false
    for key, family in pairs(familyData) do
        if key == root or key:find(root, 1, true) then
            if not members then members = {} end
            for memberID, memberCount in pairs(family.breakdown) do
                members[memberID] = memberCount
            end
        end
    end
    familyMembersCache[baseKey] = members
    return members or nil
end

local prioSeen = {}
local function AggregateCountPrio(id, prio)
    local order = prio and prio.order
    if not order or #order == 0 then return AggregateCount(id) end
    if not cacheValid then RebuildBagCache() end
    local off = prio.off
    local shownID, shownCount, total, firstOn = nil, 0, 0, nil
    wipe(prioSeen)
    for versionIndex = 1, #order do
        local memberID = order[versionIndex]
        prioSeen[memberID] = true
        if not (off and off[memberID]) then
            firstOn = firstOn or memberID
            local count = bagItemCounts[memberID] or 0
            total = total + count
            if not shownID and count > 0 then
                shownID = memberID
                shownCount = count
            end
        end
    end

    local baseKey = itemFamily[id] or familyKeyMemo[id]
    if baseKey == nil then
        baseKey = GetFamilyKey(id)
        if baseKey then familyKeyMemo[id] = baseKey end
    end
    local members = baseKey and FamilyMembersFor(baseKey)
    if members then
        for memberID, memberCount in pairs(members) do
            if not prioSeen[memberID] then
                total = total + memberCount
                if not shownID and memberCount > 0 then
                    shownID = memberID
                    shownCount = memberCount
                end
            end
        end
    end

    if prio.combine then shownCount = total end
    return shownCount, shownID or firstOn or id
end

local LINKED_ANCHORS = {
    { 241308, 245897 },
    { 241288, 245902 },
    { 241292, 245910 },
    { 241294, 245904 },
    { 241296, 245900 },
    { 241300, 245916 },
    { 241304, 271883 },
}

local linkedPartners
local function BuildLinkedPartners()
    linkedPartners = {}
    for _, group in ipairs(LINKED_ANCHORS) do
        for _, anchor in ipairs(group) do
            local partners = {}
            for _, other in ipairs(group) do
                if other ~= anchor then partners[#partners + 1] = other end
            end
            linkedPartners[anchor] = partners
            linkedPartners[anchor + 1] = partners
        end
    end
end

local function GetPotionVersions(itemID)
    if not cacheValid then RebuildBagCache() end
    if not linkedPartners then BuildLinkedPartners() end
    local versions, seen, keyByID, pending = {}, {}, {}, nil

    local function AddVersion(id, key)
        if seen[id] then return end
        seen[id] = true
        keyByID[id] = key
        versions[#versions + 1] = { id = id, count = bagItemCounts[id] or 0, quality = ItemQuality(id) }
    end

    local baseKey = itemFamily[itemID] or GetFamilyKey(itemID)
    if not baseKey then
        pending = { itemID }
    else
        local root = baseKey
        for key in pairs(familyData) do
            if key ~= root and #key < #root and root:find(key, 1, true) then root = key end
        end
        for key, family in pairs(familyData) do
            if key == root or key:find(root, 1, true) then
                for memberID in pairs(family.breakdown) do
                    AddVersion(memberID, key)
                end
            end
        end
    end
    AddVersion(itemID, baseKey)

    local versionIndex = 1
    while versionIndex <= #versions do
        local partners = linkedPartners[versions[versionIndex].id]
        if partners then
            for _, partner in ipairs(partners) do
                if not seen[partner] then
                    local pkey = GetFamilyKey(partner)
                    if not pkey then
                        pending = pending or {}
                        pending[#pending + 1] = partner
                    else
                        AddVersion(partner, pkey)
                    end
                end
            end
        end
        versionIndex = versionIndex + 1
    end

    local anchorCount = #versions
    for a = 1, anchorCount do
        local anchor = versions[a].id
        local anchorKey = keyByID[anchor]
        if anchorKey then
            for probeID = anchor - 4, anchor + 4 do
                if probeID > 0 and not seen[probeID] then
                    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(probeID)
                    if classID == Enum.ItemClass.Consumable
                    and (subclassID == Enum.ItemConsumableSubclass.Potion or subclassID == Enum.ItemConsumableSubclass.Flask) then
                        local probeKey = GetFamilyKey(probeID)
                        if not probeKey then
                            pending = pending or {}
                            pending[#pending + 1] = probeID
                        elseif probeKey == anchorKey then
                            AddVersion(probeID, probeKey)
                        end
                    end
                end
            end
        end
    end

    local rootKey
    for _, v in ipairs(versions) do
        local key = keyByID[v.id]
        if key and (not rootKey or #key < #rootKey) then rootKey = key end
    end
    for _, v in ipairs(versions) do
        v.variant = keyByID[v.id] ~= rootKey
    end

    table.sort(versions, function(a, b)
        if a.variant ~= b.variant then return b.variant end
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.id < b.id
    end)
    return versions, pending
end

local function InvalidateCache()
    cacheValid = false
end

local spellToItemPersist = {}

local function GetItemForSpell(spellID)
    if not cacheValid then RebuildBagCache() end
    local itemID = spellToItemID[spellID]
    if itemID then
        spellToItemPersist[spellID] = itemID
        return spellToItemCount[spellID], itemID
    end
    itemID = spellToItemPersist[spellID]
    if itemID then return 0, itemID end
    return nil, nil
end

local IconEngine = BUI.IconEngine
local ExtractSpellItemID     = IconEngine.ExtractSpellItemID
local IsEquippedOrKnownOrInBags = IconEngine.IsEquippedOrKnownOrInBags

local function ClassifyAsSpellOrItem(id, isItemByPrefix)
    return IconEngine.ClassifyAsSpellOrItem(id, isItemByPrefix, GetItemForSpell)
end

local function IsTrackedEntryUsable(storedValue)
    return IconEngine.IsTrackedEntryUsable(storedValue, GetItemForSpell)
end

local function CreateChargeText(icon)
    if icon._chargeText then
        icon.Count = icon._chargeText
        return icon._chargeText
    end

    local overlay = CreateFrame("Frame", nil, icon)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(icon:GetFrameLevel() + 20)

    local text = overlay:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(text, 14, STANDARD_TEXT_FONT, "OUTLINE")
    text:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", Pixel.Scale(-2), Pixel.Scale(2))
    text:SetTextColor(1, 1, 1, 1)
    icon._chargeText = text
    icon.Count = text
    return text
end

local function CreateIconFrame(parent, borderSize, borderColor, zoom)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(Pixel.Scale(50), Pixel.Scale(50))
    frame._edgeThickness = borderSize or 1
    frame._baseColor = CopyColor(borderColor)
    frame._zoom = zoom or 0.08

    local texture = frame:CreateTexture(nil, "ARTWORK")
    local scaledEdge = Pixel.Scale(frame._edgeThickness)
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", scaledEdge, -scaledEdge)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -scaledEdge, scaledEdge)
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
    texture:SetTexCoord(frame._zoom, 1 - frame._zoom, frame._zoom, 1 - frame._zoom)
    frame.Icon = texture

    local color = frame._baseColor
    Pixel.ApplyBorder(frame, frame._edgeThickness, color[1], color[2], color[3], color[4])

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")

    local cdEdge = scaledEdge - Pixel.PixelSize(1)
    if cdEdge < 0 then cdEdge = 0 end
    cooldown:SetPoint("TOPLEFT", frame, "TOPLEFT", cdEdge, -cdEdge)
    cooldown:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -cdEdge, cdEdge)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetHideCountdownNumbers(true)
    SetScript(cooldown, "OnCooldownDone", CDM.OnCooldownWidgetDone)
    frame.Cooldown = cooldown

    function frame:Update(newBorderSize, newBorderColor, newZoom)
        if newBorderSize then self._edgeThickness = newBorderSize end
        if newBorderColor then
            local baseColor = self._baseColor
            baseColor[1], baseColor[2], baseColor[3], baseColor[4] = newBorderColor[1] or 0, newBorderColor[2] or 0, newBorderColor[3] or 0, newBorderColor[4] or 1
        end
        if newZoom then self._zoom = newZoom end

        local baseColor = self._baseColor
        Pixel.ApplyBorder(self, self._edgeThickness, baseColor[1], baseColor[2], baseColor[3], baseColor[4])

        local edge = Pixel.Scale(self._edgeThickness)
        self.Icon:ClearAllPoints()
        self.Icon:SetPoint("TOPLEFT", self, "TOPLEFT", edge, -edge)
        self.Icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -edge, edge)
        self.Icon:SetTexCoord(self._zoom, 1 - self._zoom, self._zoom, 1 - self._zoom)
        local cdEdge = edge - Pixel.PixelSize(1)
        if cdEdge < 0 then cdEdge = 0 end
        self.Cooldown:ClearAllPoints()
        self.Cooldown:SetPoint("TOPLEFT", self, "TOPLEFT", cdEdge, -cdEdge)
        self.Cooldown:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -cdEdge, cdEdge)
    end

    local tooltipOverlay = CreateFrame("Frame", nil, frame)
    tooltipOverlay:SetAllPoints()
    tooltipOverlay:SetFrameLevel(frame:GetFrameLevel() + 5)
    tooltipOverlay:EnableMouse(true)
    frame._tooltipOverlay = tooltipOverlay
    SetScript(tooltipOverlay, "OnEnter", function()
        local frameData = FrameData[frame]
        if not frameData or frameData.hidden then return end
        local db = BUI.GetDB()
        if db.cdm.showTooltips == false then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        local spellID = frameData.customSpellID
        if frameData.isItemByPrefix then
            GameTooltip:SetItemByID(spellID)
        elseif frameData.itemID and (frameData.iconType == "consumable" or frameData.iconType == "trinket") then
            GameTooltip:SetItemByID(frameData.itemID)
        else
            GameTooltip:SetSpellByID(spellID)
        end
        GameTooltip:Show()
    end)
    SetScript(tooltipOverlay, "OnLeave", function()
        GameTooltip:Hide()
    end)

    local frameData = GetFrameData(frame)
    frameData.customIcon = true
    return frame
end

local CancelManualBuffGlowTimer
local CleanupManualBuff

local function ManualBuffActivateGlow(icon, frameData, glowConfig, remaining)
    if frameData._manualGlowActive then return end
    frameData._manualGlowActive = true
    CDM.StartProcGlow(icon, glowConfig)
    local warn = glowConfig.warning
    if not warn then return end
    if warn.sound and warn.sound ~= 0 then
        warningLastSound = warn.sound
        PlaySound(warn.sound, 'Master')
    end
    if warn.enabled then
        local spellName = C_Spell.GetSpellName(frameData.customSpellID) or tostring(frameData.customSpellID)
        ShowBuffWarning(warn.text or "BUFF EXPIRING!", warn.color, remaining, spellName, warn.font, nil, glowConfig.threshold or 5)
    end
end

local function ManualBuffDeactivateGlow(icon, frameData)
    if not frameData._manualGlowActive then return end
    frameData._manualGlowActive = false
    CDM.StopProcGlow(icon)
    HideBuffWarning()
end

CancelManualBuffGlowTimer = function(frameData)
    if frameData._manualGlowTimer then
        frameData._manualGlowTimer:Cancel()
        frameData._manualGlowTimer = nil
    end
end

local function ScheduleManualBuffGlow(icon, frameData, glowConfig, expiry)
    CancelManualBuffGlowTimer(frameData)
    if not glowConfig or not glowConfig.enabled then
        ManualBuffDeactivateGlow(icon, frameData)
        return
    end
    local thresh = glowConfig.threshold or 5
    local remaining = expiry - GetTime()
    local timeUntilThreshold = remaining - thresh
    local mode = glowConfig.mode or 'always'

    if mode == 'always' then
        ManualBuffActivateGlow(icon, frameData, glowConfig, remaining)
    elseif mode == 'below' then
        if timeUntilThreshold <= 0 then
            ManualBuffActivateGlow(icon, frameData, glowConfig, remaining)
        else
            ManualBuffDeactivateGlow(icon, frameData)
            frameData._manualGlowTimer = BUI.Prof.NewTimer('CDM.Custom', timeUntilThreshold, function()
                frameData._manualGlowTimer = nil
                ManualBuffActivateGlow(icon, frameData, glowConfig, thresh)
            end)
        end
    elseif mode == 'above' then
        ManualBuffActivateGlow(icon, frameData, glowConfig, remaining)
        if timeUntilThreshold > 0 then
            frameData._manualGlowTimer = BUI.Prof.NewTimer('CDM.Custom', timeUntilThreshold, function()
                frameData._manualGlowTimer = nil
                ManualBuffDeactivateGlow(icon, frameData)
            end)
        end
    end
end

CleanupManualBuff = function(icon, frameData, caller)
    local wasShown = icon:IsShown()
    if frameData.storedValue ~= nil then
        manualStartByStored[frameData.storedValue] = nil
    end
    CancelManualBuffGlowTimer(frameData)
    frameData._manualStart = nil
    frameData._manualExpiry = nil
    frameData._manualGlowCfg = nil
    frameData._manualGlowThresh = nil
    frameData._manualGlowActive = nil
    local cooldown = icon.Cooldown
    if cooldown then
        SetScript(cooldown, "OnCooldownDone", CDM.OnCooldownWidgetDone)
        cooldown:Clear()
    end
    GlowManager.CancelDeferred(frameData)
    CDM.StopProcGlow(icon)
    HideBuffWarning()
    frameData.lastCDStart = 0
    icon:Hide()
    if wasShown and frameData.viewerKey then CDM.MarkDirty(frameData.viewerKey) end
end

local function UpdateIcon(icon)
    local frameData = FrameData[icon]
    if not frameData or not frameData.customSpellID then return end
    local refresh = frameData._refreshClosure
    if not refresh then
        refresh = function() UpdateIcon(icon) end
        frameData._refreshClosure = refresh
    end
    local id = frameData.customSpellID
    local cooldown = icon.Cooldown
    local texture = icon.Icon
    local db = BUI.GetDB()

    if not frameData.iconType then
        local iconType, itemID = ClassifyAsSpellOrItem(id, frameData.isItemByPrefix)
        frameData.iconType = iconType
        frameData.itemID = itemID
    end

    local iconType = frameData.iconType
    local itemID = frameData.itemID

    if frameData.trackedBuff == nil then
        local tracking = CDM.GetBuffTracking(db.cdm[frameData.viewerKey])
        local resolved = tracking[frameData.storedValue] or tracking[id] or false
        frameData.trackedBuff = resolved
        if resolved and (resolved ~= id or frameData.viewerKey ~= "buffs") then
            local set = buffSpellToIcons[resolved]
            if not set then set = {}; buffSpellToIcons[resolved] = set end
            set[icon] = true
        end
    end

    if frameData.trackedBuff and icon._chargeText then
        local aura = GetPlayerAuraBySpellID(frameData.trackedBuff)
        if frameData.viewerKey ~= "buffs" then
            local newInstanceID = aura and Tools.SafeNum(aura.auraInstanceID)
            if newInstanceID ~= frameData._auraInstanceID then
                if frameData._auraInstanceID then
                    buffInstanceToIcon[frameData._auraInstanceID] = nil
                end
                frameData._auraInstanceID = newInstanceID
                if newInstanceID then buffInstanceToIcon[newInstanceID] = icon end
            end
        end
        local text = aura and Tools.CountText(aura.applications)
        if text then
            icon._chargeText:SetText(text)
            icon._chargeText:Show()
        elseif aura then
            local stacks = Tools.SafeNum(aura.applications) or 0
            if stacks > 0 then icon._chargeText:SetText(stacks); icon._chargeText:Show()
            else icon._chargeText:Hide() end
        else
            icon._chargeText:Hide()
        end
    end

    if frameData.viewerKey == "buffs" then
        local config = db.cdm.buffs
        local hiddenIcons = CDM.GetHiddenIcons(config)
        local isHidden
        if frameData.customIcon then
            isHidden = frameData.customKey and hiddenIcons[frameData.customKey]
        else
            isHidden = hiddenIcons[id] or hiddenIcons[frameData.storedValue]
        end
        if isHidden then
            icon:Hide()
            return
        end

        if frameData.customIcon and not frameData.isItemByPrefix then
            local origTex = frameData._origTexture
            if not origTex then
                origTex = CDM.GetIconOverrides(config)[frameData.storedValue]
                    or GetStableSpellTexture(frameData.storedValue)
                frameData._origTexture = origTex
            end
            if origTex and texture:GetTexture() ~= origTex then
                texture:SetTexture(origTex)
            end
        end
        if frameData._manualBuff == nil then
            local manualBuffs = CDM.GetManualBuffs(config)
            frameData._manualBuff = manualBuffs[frameData.storedValue] or manualBuffs[id] or false
        end

        if frameData._manualBuff then
            local manualBuff = frameData._manualBuff
            local duration = manualBuff.duration
            if not duration or duration <= 0 then
                CleanupManualBuff(icon, frameData, "UI/bad-duration")
                return
            end
            local now = GetTime()
            if frameData._manualStart then
                local expiry = frameData._manualStart + duration
                if expiry > now then
                    local wasHidden = not icon:IsShown()
                    icon:Show()
                    if wasHidden then CDM.MarkDirty(frameData.viewerKey) end
                    SetColor(texture, 1, 1, 1)
                    texture:SetDesaturation(0)

                    if frameData._manualStart ~= frameData.lastCDStart then
                        frameData.lastCDStart = frameData._manualStart
                        frameData._manualExpiry = expiry
                        frameData._manualGlowCfg = manualBuff.glow
                        frameData._manualGlowThresh = (manualBuff.glow and manualBuff.glow.threshold) or 5
                        cooldown:SetCooldown(frameData._manualStart, duration)
                        SetScript(cooldown, "OnCooldownDone", function()
                            CleanupManualBuff(icon, frameData, "OnCooldownDone")
                        end)
                        ScheduleManualBuffGlow(icon, frameData, manualBuff.glow, expiry)
                    end
                    return
                end
                CleanupManualBuff(icon, frameData, "UI/expired")
                return
            end

            CleanupManualBuff(icon, frameData, "UI/no-start")
            return
        end

        local aura, auraBlocked

        if frameData.trackedBuff then
            aura, auraBlocked = SafeGetPlayerAura(frameData.trackedBuff)
        end

        if not aura and (frameData.isItemByPrefix or iconType == "consumable" or iconType == "trinket") then
            if frameData._auraSpellID == nil then
                local _, sid = GetItemSpell(itemID or id)
                frameData._auraSpellID = sid or false
                if sid and frameData.viewerKey == "buffs" then
                    local set = buffSpellToIcons[sid]
                    if not set then set = {}; buffSpellToIcons[sid] = set end
                    set[icon] = true
                end
            end
            if frameData._auraSpellID then
                local a, blocked = SafeGetPlayerAura(frameData._auraSpellID)
                aura = a
                auraBlocked = auraBlocked or blocked
            end
        end

        if not aura and not itemID then
            local a, blocked = SafeGetPlayerAura(id)
            aura = a
            auraBlocked = auraBlocked or blocked
            if not aura then
                local overrideID = Tools.GetOverrideSpell(id)
                if overrideID ~= id then
                    a, blocked = SafeGetPlayerAura(overrideID)
                    aura = a
                    auraBlocked = auraBlocked or blocked
                end
            end
        end

        if not aura and auraBlocked then return end

        if aura then
            frameData._cdFingerStart = nil
            frameData._cdFingerDuration = nil
            if not icon:IsShown() then
                icon:Show()
                CDM.MarkDirty(frameData.viewerKey)
                SetColor(texture, 1, 1, 1)
                texture:SetDesaturation(0)
            end
            local newInstanceID = Tools.SafeNum(aura.auraInstanceID)
            if newInstanceID and newInstanceID ~= frameData._auraInstanceID then
                if frameData._auraInstanceID then
                    buffInstanceToIcon[frameData._auraInstanceID] = nil
                end
                frameData._auraInstanceID = newInstanceID
                buffInstanceToIcon[newInstanceID] = icon
            end

            local expiry = Tools.SafeNum(aura.expirationTime)
            local auraDuration = Tools.SafeNum(aura.duration)
            if expiry and auraDuration then
                local auraStart = expiry - auraDuration
                if auraStart ~= frameData._auraExpiry or auraDuration ~= frameData._auraDuration then
                    frameData._auraExpiry = auraStart
                    frameData._auraDuration = auraDuration
                    cooldown:SetCooldown(auraStart, auraDuration)
                end
            elseif frameData._auraExpiry ~= 'secret' then
                frameData._auraExpiry = 'secret'
                frameData._auraDuration = nil
            end
            local manualBuff = frameData._manualBuff
            local glowConfig = manualBuff and manualBuff.glow
            local remaining = expiry and (expiry - GetTime()) or nil
            if glowConfig and glowConfig.enabled and remaining == nil then
                if glowConfig.mode == 'always' then
                    CDM.StartProcGlow(icon, glowConfig)
                else
                    CDM.StopProcGlow(icon)
                    HideBuffWarning()
                end
            elseif glowConfig and glowConfig.enabled then
                local thresh = glowConfig.threshold or 5
                local shouldGlow = glowConfig.mode == 'always'
                    or (glowConfig.mode == 'below' and remaining <= thresh)
                    or (glowConfig.mode == 'above' and remaining >= thresh)

                if shouldGlow then
                    CDM.StartProcGlow(icon, glowConfig)
                    local warn = glowConfig.warning
                    if warn then
                        if warn.sound and warn.sound ~= 0 and warn.sound ~= warningLastSound then
                            warningLastSound = warn.sound
                            PlaySound(warn.sound, 'Master')
                        end
                        if warn.enabled then
                            ShowBuffWarning(warn.text or "BUFF EXPIRING!", warn.color, remaining, C_Spell.GetSpellName(id) or tostring(id), warn.font, nil, glowConfig.threshold or 5)
                        end
                    end
                else
                    CDM.StopProcGlow(icon)
                    HideBuffWarning()
                    if glowConfig.mode == 'below' and remaining > thresh then
                        frameData._deferredGlowCfg = glowConfig
                        frameData._deferredGlowSpellID = id
                        GlowManager.ScheduleDeferred(frameData, remaining - thresh, function()
                            DeferredGlowActivate(icon, frameData)
                        end)
                    end
                end
            end
            if icon._chargeText and not frameData.trackedBuff then
                local text = Tools.GetAuraStacksText('player', aura.auraInstanceID)
                if text then
                    icon._chargeText:SetText(text)
                    icon._chargeText:Show()
                else
                    local stacks = Tools.SafeNum(aura.applications) or 0
                    if stacks > 0 then icon._chargeText:SetText(stacks); icon._chargeText:Show()
                    else icon._chargeText:Hide() end
                end
            end
            return
        end

        frameData._auraExpiry = nil
        frameData._auraDuration = nil
        if frameData._auraInstanceID then
            buffInstanceToIcon[frameData._auraInstanceID] = nil
            frameData._auraInstanceID = nil
        end
        GlowManager.ResetIconState(frameData)
        local wasShown = icon:IsShown()
        CDM.StopProcGlow(icon)
        HideBuffWarning()
        icon:Hide()
        if frameData.lastCDStart ~= 0 then frameData.lastCDStart = 0; cooldown:Clear() end
        if wasShown then CDM.MarkDirty(frameData.viewerKey) end
        return
    end

    if iconType == "trinket" then
        local checkID = itemID or id
        if frameData._auraSpellID == nil then
            local _, sid = GetItemSpell(checkID)
            frameData._auraSpellID = sid or false
        end
        IconEngine.ApplyTrinketVisual(texture, cooldown, checkID, frameData._auraSpellID or nil, refresh, icon._chargeText)
        return
    end

    if iconType == "consumable" then
        local checkID = itemID or id
        local count, bestID = AggregateCountPrio(checkID, frameData.potionPrio)
        if not frameData.trackedBuff and icon._chargeText then
            if count ~= frameData.lastCount then
                frameData.lastCount = count
                icon._chargeText:SetText(count or 0)
            end
            icon._chargeText:Show()
        end
        if bestID and bestID ~= frameData.lastBestTier then
            frameData.lastBestTier = bestID
            local iconTexture = select(10, C_Item.GetItemInfo(bestID))
            if iconTexture then texture:SetTexture(iconTexture) end
        end

        if frameData.viewerKey == "buffs" then
            local auraSpellID = frameData._auraSpellID
            if auraSpellID == nil then
                local _, sid = GetItemSpell(checkID)
                auraSpellID = sid or id or false
                frameData._auraSpellID = auraSpellID
            end
            if auraSpellID then
                local aura, blocked = SafeGetPlayerAura(auraSpellID)
                if not aura and blocked then return end
                local duration = aura and Tools.SafeNum(aura.duration)
                local expirationTime = aura and Tools.SafeNum(aura.expirationTime)
                if aura and not expirationTime then
                    SetColor(texture, 1, 1, 1)
                    texture:SetDesaturation(0)
                    return
                end
                if expirationTime and expirationTime > 0 and (expirationTime - GetTime()) > 0 then
                    SetColor(texture, 1, 1, 1)
                    texture:SetDesaturation(0)
                    local start = expirationTime - duration
                    if start ~= frameData.lastCDStart then
                        frameData.lastCDStart = start
                        cooldown:SetCooldown(start, duration)
                    end
                    return
                end
            end
            texture:SetDesaturation(1)
            SetColor(texture, 0.3, 0.3, 0.3)
            if frameData.lastCDStart ~= 0 then
                frameData.lastCDStart = 0
                cooldown:Clear()
            end
            return
        end

        IconEngine.ApplyItemVisual(texture, cooldown, nil, nil, count or 0, checkID, refresh)
        return
    end

    local cdInfo = C_Spell.GetSpellCooldown(id)
    if frameData.hasCharges == nil then
        frameData.hasCharges = C_Spell.GetSpellCharges(id) ~= nil
    end
    if cdInfo then
        local cdStart = cdInfo.startTime
        local cdDuration = cdInfo.duration
        if cdStart and not issecretvalue(cdStart) and not issecretvalue(cdDuration) then
            local fingerValid = true
            local chargeCount, chargeStart, chargeDuration
            if frameData.hasCharges then
                local chargeInfo = C_Spell.GetSpellCharges(id)
                chargeCount = chargeInfo and Tools.SafeNum(chargeInfo.currentCharges)
                chargeStart = chargeInfo and Tools.SafeNum(chargeInfo.cooldownStartTime)
                chargeDuration = chargeInfo and Tools.SafeNum(chargeInfo.cooldownDuration)
                fingerValid = chargeCount ~= nil and chargeStart ~= nil and chargeDuration ~= nil
            end
            if fingerValid and cdStart == frameData._cdFingerStart and cdDuration == frameData._cdFingerDuration
                and chargeCount == frameData._cdFingerCharges
                and chargeStart == frameData._cdFingerChargeStart
                and chargeDuration == frameData._cdFingerChargeDuration then
                local _, notEnoughPower = C_Spell.IsSpellUsable(id)
                if not issecretvalue(notEnoughPower) and notEnoughPower ~= texture._lastNotEnoughPower then
                    texture._lastNotEnoughPower = notEnoughPower
                    local tint = notEnoughPower and 0.5 or 1
                    SetColor(texture, tint, tint, tint)
                end
                return
            end
            if fingerValid then
                frameData._cdFingerStart = cdStart
                frameData._cdFingerDuration = cdDuration
                frameData._cdFingerCharges = chargeCount
                frameData._cdFingerChargeStart = chargeStart
                frameData._cdFingerChargeDuration = chargeDuration
            else
                frameData._cdFingerStart = nil
                frameData._cdFingerDuration = nil
            end
        else
            frameData._cdFingerStart = nil
            frameData._cdFingerDuration = nil
        end
    end

    local isUsable, notEnoughPower = C_Spell.IsSpellUsable(id)
    if issecretvalue(notEnoughPower) then notEnoughPower = false end
    texture._lastNotEnoughPower = notEnoughPower
    if not issecretvalue(isUsable) then
        frameData._usableKey = (isUsable and 1 or 0) + (notEnoughPower and 2 or 0)
    end
    local tint = notEnoughPower and 0.5 or 1
    SetColor(texture, tint, tint, tint)

    local charges = IconEngine.ApplySpellVisual(texture, cooldown, id, frameData.hasCharges, refresh, nil, isUsable, notEnoughPower, cdInfo)
    if frameData.hasCharges then
        if not frameData.trackedBuff and icon._chargeText then
            icon._chargeText:SetText(charges ~= nil and C_StringUtil.TruncateWhenZero(charges) or "")
            icon._chargeText:Show()
        end
    else
        if not frameData.trackedBuff and icon._chargeText then icon._chargeText:Hide() end
    end
end

local function SetupIcon(icon, storedValue, viewerKey, index)
    local trinketSlot = IconEngine.GetTrinketSlotNumber(storedValue)
    local racialSlot = IconEngine.GetRacialSlotNumber(storedValue)
    local spellID, isItemByPrefix = ExtractSpellItemID(storedValue)

    if trinketSlot then
        trinketSlotIcons[icon] = true
        if spellID and CDM.IsTrinketBlacklisted(BUI.GetDB().cdm[viewerKey], spellID) then
            spellID = nil
        end
        if not spellID then
            UnwatchIcon(icon)
            icon:Hide()
            trinketSlotIcons[icon] = true
            return
        end
    end

    if racialSlot and spellID and CDM.IsRacialBlacklisted(BUI.GetDB().cdm[viewerKey], spellID) then
        spellID = nil
    end
    if racialSlot and not spellID then
        UnwatchIcon(icon)
        icon:Hide()
        return
    end

    if not spellID then return end

    local frameData = GetFrameData(icon)

    local priorManualStart = frameData._manualStart
    UnwatchIcon(icon)
    if trinketSlot then trinketSlotIcons[icon] = true end
    frameData.customIcon = true
    frameData.customSpellID = spellID

    frameData.customKey = (trinketSlot or racialSlot) and storedValue or ('custom:' .. spellID)
    frameData.storedValue = storedValue
    frameData.viewerKey = viewerKey
    frameData.isItemByPrefix = isItemByPrefix
    frameData.trinketSlot = trinketSlot
    frameData.racialSlot = racialSlot
    frameData.iconType = nil
    local config = BUI.GetDB().cdm[viewerKey]
    frameData._activeChoiceID = CDM.GetChoiceNodes(config)[spellID]
    frameData.potionPrio = CDM.GetPotionPrioFor(storedValue)
    frameData.lastBestTier = nil
    frameData.itemID = nil
    frameData.trackedBuff = nil
    frameData.hasCharges = nil
    frameData.lastCDStart = nil
    frameData.lastCount = nil
    frameData._cdFingerStart = nil
    frameData._cdFingerDuration = nil
    frameData._manualBuff = nil

    local preservedStart = manualStartByStored[storedValue] or priorManualStart
    if preservedStart then
        local manualBuffs = CDM.GetManualBuffs(config)
        local entry = manualBuffs[storedValue] or manualBuffs[spellID]
        local duration = entry and entry.duration
        if not (duration and duration > 0 and GetTime() < preservedStart + duration) then
            preservedStart = nil
            manualStartByStored[storedValue] = nil
        end
    end
    frameData._manualStart = preservedStart

    if not preservedStart then
        frameData._manualExpiry = nil
        frameData._manualGlowCfg = nil
        frameData._manualGlowThresh = nil
        frameData._manualGlowActive = nil
        ResetManualBuffOverlay(icon, frameData)
    end
    frameData._auraSpellID = nil
    frameData._origTexture = nil
    icon.layoutIndex = 100000 + (index or 1)

    local overrides = CDM.GetIconOverrides(config)
    local overrideTexture = overrides[storedValue] or overrides[spellID]

    if not overrideTexture and viewerKey == "buffs" and not isItemByPrefix then
        local manualBuffs = CDM.GetManualBuffs(config)
        local isManualBuff = manualBuffs[storedValue] or manualBuffs[spellID]
        if isManualBuff then
            local pinned = GetStableSpellTexture(storedValue)
            if pinned then
                CDM.SetIconOverride(config, storedValue, pinned)
                overrideTexture = pinned
            end
        end
    end

    if not isItemByPrefix and not overrideTexture then
        local spellKnown = IsPlayerSpell(spellID) or IsSpellKnown(spellID)

        if viewerKey ~= "buffs" and not spellKnown and frameData._activeChoiceID then
            local activeID = frameData._activeChoiceID
            if activeID ~= spellID and (IsPlayerSpell(activeID) or IsSpellKnown(activeID)) then
                spellID = activeID
                frameData.customSpellID = spellID
                frameData.customKey = 'custom:' .. spellID
                spellKnown = true
            end
        end
        if not spellKnown and viewerKey ~= "buffs" then
            local itemCount = C_Item.GetItemCount(spellID, true)
            local equipped = IsEquippedItem(spellID)
            if not (itemCount and itemCount > 0) and not equipped then
                icon:Hide()
                return
            end
        end
    end

    local iconTexture
    if overrideTexture then
        iconTexture = overrideTexture
    elseif viewerKey == "buffs" and not isItemByPrefix then
        iconTexture = GetStableSpellTexture(storedValue) or GetStableSpellTexture(spellID)
    elseif isItemByPrefix then
        local _, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(spellID)
        if not itemIcon then
            local _, _, _, _, instantIcon = C_Item.GetItemInfoInstant(spellID)
            itemIcon = instantIcon
            C_Item.RequestLoadItemDataByID(spellID)
        end
        iconTexture = itemIcon or 134400
        frameData.itemID = spellID
    elseif IsPlayerSpell(spellID) or IsSpellKnown(spellID) then
        iconTexture = C_Spell.GetSpellTexture(spellID)
    else
        local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(spellID)
        local itemCount = C_Item.GetItemCount(spellID, true)
        if itemName and (itemCount > 0 or IsEquippedItem(spellID)) then
            iconTexture = itemIcon or 134400
            frameData.itemID = spellID
        else
            iconTexture = C_Spell.GetSpellTexture(spellID)
        end
    end

    icon.Icon:SetTexture(iconTexture or 134400)
    CreateChargeText(icon)

    if viewerKey ~= "buffs" then
        if frameData.itemID then
            WatchItem(frameData.itemID, icon)
        else
            WatchSpell(spellID, icon)
        end
    else

        local set = buffSpellToIcons[spellID]
        if not set then set = {}; buffSpellToIcons[spellID] = set end
        set[icon] = true
    end

    UpdateIcon(icon)

    if viewerKey ~= "buffs" then
        icon:Show()
    end
end

local trinketLoadPending = {}
local trinketSlotRetryPending = {}
local trinketSlotRetryCount = {}
local MAX_TRINKET_SLOT_RETRIES = 6

local function ArmTrinketDataLoad(slot)
    local itemID = IconEngine.ResolveTrinketSlot(slot)
    if not itemID then
        if trinketSlotRetryPending[slot] or not IconEngine.TrinketSlotHasItem(slot) then return end
        local attempts = (trinketSlotRetryCount[slot] or 0) + 1
        if attempts > MAX_TRINKET_SLOT_RETRIES then return end
        trinketSlotRetryCount[slot] = attempts
        trinketSlotRetryPending[slot] = true
        C_Timer_After(0.5, function()
            trinketSlotRetryPending[slot] = nil
            CDM.Custom.Refresh("essential")
        end)
        return
    end
    trinketSlotRetryCount[slot] = nil
    if trinketLoadPending[itemID] then return end
    local ok, item = pcall(Item.CreateFromItemID, Item, itemID)
    if not ok or not item or item:IsItemEmpty() then return end
    trinketLoadPending[itemID] = true
    item:ContinueOnItemLoad(function()
        trinketLoadPending[itemID] = nil
        CDM.Custom.Refresh("essential")
    end)
end

local function RefreshViewer(viewerKey)
    local db = BUI.GetDB()
    local config = db.cdm[viewerKey]
    if not config or not config.enabled then return end

    local spells = CDM.GetCustomSpells(config)
    local viewerName = CDM.VIEWERS[viewerKey]
    local viewer = viewerName and _G[viewerName]
    if not viewer then return end

    local anchor = CDM.Anchors[viewerKey]
    local parentFrame = anchor or viewer

    local viewerIcons = icons[viewerKey]
    local oldCount = iconCounts[viewerKey]

    local opacity = CDM.GetContextualOpacity(viewerKey)
    local visAlpha = anchor and anchor._iconAlpha or 1

    local alwaysShow = CDM.GetAlwaysShow(config)
    local visibleCount = 0

    local function Place(v, versionIndex)
        local numId = tonumber(tostring(v):match('(%d+)'))
        local customKey = numId and ('custom:' .. numId)
        local forceShow = customKey and alwaysShow[customKey]
        if viewerKey == "buffs" or forceShow or IsTrackedEntryUsable(v) then
            visibleCount = visibleCount + 1
            local icon = viewerIcons[visibleCount]
            if not icon then
                icon = AcquireIcon(parentFrame, config.borderSize, config.borderColor, config.zoom) or CreateIconFrame(parentFrame, config.borderSize, config.borderColor, config.zoom)
                viewerIcons[visibleCount] = icon
            end
            icon:SetParent(parentFrame)
            icon:SetFrameStrata(viewer:GetFrameStrata())
            icon:SetFrameLevel(viewer:GetFrameLevel() + 1)
            SetupIcon(icon, v, viewerKey, versionIndex)
            local frameData = FrameData[icon]
            if not frameData or not frameData.tracked then
                CDM.TrackIcon(viewerKey, icon)
            end
            CDM.SkinIcon(icon, config, viewerKey)
            if not frameData then frameData = GetFrameData(icon) end

            if not frameData.anchor then
                frameData.locking = true
                icon:SetAlpha(0)
                frameData.locking = false
            end
        end
    end

    for versionIndex, v in ipairs(spells) do
        local isSlotEntry = type(v) == "string" and
            (v:match("^trinket:%d$") or v:match("^racial:%d$"))
        if not isSlotEntry then
            Place(v, versionIndex)
        end
    end

    if viewerKey == "essential" then
        for slot = 1, 2 do
            local onUse, conclusive = IconEngine.IsOnUseTrinketSlot(slot)
            if onUse then Place('trinket:' .. slot, 90000 + slot) end
            if not conclusive then ArmTrinketDataLoad(slot) end
        end
    end

    if viewerKey == "essential" or viewerKey == "utility" then
        Place('racial:1', 90010)
    end

    for versionIndex = visibleCount + 1, oldCount do
        local icon = viewerIcons[versionIndex]
        if icon then
            CDM.UntrackIcon(viewerKey, icon)
            ReleaseIcon(icon)
            viewerIcons[versionIndex] = nil
        end
    end

    iconCounts[viewerKey] = visibleCount
    if visibleCount > 0 or oldCount > 0 then
        CDM.MarkDirty(viewerKey)
    end
end

local function ForEachIcon(filter, callback)
    for viewerKey, viewerIcons in pairs(icons) do
        local count = iconCounts[viewerKey]
        for versionIndex = 1, count do
            local icon = viewerIcons[versionIndex]
            if icon then
                local frameData = FrameData[icon]
                if not filter or (frameData and filter(frameData)) then
                    callback(icon, frameData)
                end
            end
        end
    end
end

local function UpdateAllCooldowns()
    ForEachIcon(nil, UpdateIcon)
end

local function UpdateIconsByType(targetType)
    ForEachIcon(function(frameData) return frameData.iconType == targetType end, function(icon) UpdateIcon(icon) end)
end

local function UpdateBufViewerIconsFull()
    local buffsIcons = icons.buffs
    local buffsCount = iconCounts.buffs
    for versionIndex = 1, buffsCount do
        local icon = buffsIcons[versionIndex]
        if icon then
            local frameData = FrameData[icon]
            if not frameData or not frameData.hidden then UpdateIcon(icon) end
        end
    end
end

local function UpdateTrackedBuffOtherViewers()
    for viewerKey, viewerIcons in pairs(icons) do
        if viewerKey ~= "buffs" then
            local count = iconCounts[viewerKey]
            for versionIndex = 1, count do
                local icon = viewerIcons[versionIndex]
                if icon then
                    local frameData = FrameData[icon]
                    if frameData and frameData.trackedBuff then UpdateIcon(icon) end
                end
            end
        end
    end
end

local function UpdateTrackedBuffIcons()
    UpdateBufViewerIconsFull()
    UpdateTrackedBuffOtherViewers()
end

local function InvalidateIconTypes()
    ForEachIcon(nil, function(_, frameData)
        if frameData then
            frameData.iconType = nil
            frameData.trackedBuff = nil

            if frameData.isItemByPrefix then frameData._availChecked = nil end
        end
    end)
end

local RebuildManualSpellMap

local function DoRefresh()
    RefreshViewer("essential")
    RefreshViewer("utility")
    RefreshViewer("buffs")
    RebuildManualSpellMap()
end

local function UpdateIconUsable(icon)
    local frameData = FrameData[icon]
    if not frameData or not frameData.customSpellID or frameData.hidden then return end
    if frameData.iconType and frameData.iconType ~= "spell" then return end
    local isUsable, notEnoughPower = C_Spell.IsSpellUsable(frameData.customSpellID)
    if issecretvalue(isUsable) or issecretvalue(notEnoughPower) then return end
    local key = (isUsable and 1 or 0) + (notEnoughPower and 2 or 0)
    if frameData._usableKey == key then return end
    frameData._usableKey = key
    frameData._cdFingerStart = nil
    frameData._cdFingerDuration = nil
    UpdateIcon(icon)
end

local flushSeen = {}

local RunBuffScanFull = BUI.Prof.Wrap("cdm#BuffScan.Full", UpdateTrackedBuffIcons)
local RunBuffScanRelevant = BUI.Prof.Wrap("cdm#BuffScan.Relevant", UpdateTrackedBuffIcons)

local RunWalkIconUpdate = BUI.Prof.Wrap("cdm#Flush.IconUpdate", UpdateIcon)

local function FlushCooldownWalk()
    wipe(flushSeen)
    for spellID, iconSet in pairs(spellMap) do
        for icon in pairs(iconSet) do
            if not flushSeen[icon] then
                flushSeen[icon] = true
                local frameData = FrameData[icon]
                if not frameData or not frameData.hidden then
                    RunWalkIconUpdate(icon)
                end
            end
        end
    end
    for itemID, iconSet in pairs(itemMap) do
        for icon in pairs(iconSet) do
            if not flushSeen[icon] then
                flushSeen[icon] = true
                local frameData = FrameData[icon]
                if not frameData or not frameData.hidden then
                    RunWalkIconUpdate(icon)
                end
            end
        end
    end
end

local function FlushUsableWalk()
    for spellID, iconSet in pairs(spellMap) do
        for icon in pairs(iconSet) do
            UpdateIconUsable(icon)
        end
    end
end

local RunFlushCooldownWalk = BUI.Prof.Wrap("cdm#Flush.Cooldowns", FlushCooldownWalk)
local RunFlushUsableWalk = BUI.Prof.Wrap("cdm#Flush.Usable", FlushUsableWalk)

local function FlushDispatch()
    if cooldownPending then
        cooldownPending = false
        RunFlushCooldownWalk()
        usablePending = false
    end
    if usablePending then
        usablePending = false
        RunFlushUsableWalk()
    end
    if auraPending then
        auraPending = false
        if needsFullBuffScan then
            needsFullBuffScan = false
            wipe(changedBuffSpellIDs)
            wipe(changedBuffInstanceIDs)
            RunBuffScanFull()
        else
            local anyRelevant = false
            for instanceID in pairs(changedBuffInstanceIDs) do
                if buffInstanceToIcon[instanceID] then anyRelevant = true; break end
            end
            if not anyRelevant then
                for spellID in pairs(changedBuffSpellIDs) do
                    if buffSpellToIcons[spellID] then anyRelevant = true; break end
                end
            end
            wipe(changedBuffSpellIDs)
            wipe(changedBuffInstanceIDs)
            if anyRelevant then
                RunBuffScanRelevant()
            end
        end
    end
end

local FLUSH_MIN_INTERVAL = 0.1
local lastFlushTime = 0
local RunFlush = BUI.Prof.Wrap("cdm#CustomFlush", FlushDispatch)

local function QueueDispatch()
    if not dispatchFrame then
        dispatchFrame = CreateFrame("Frame", "BUI_CDMCustomFlush")
        SetScript(dispatchFrame, "OnUpdate", function(self)
            local now = GetTime()
            if now - lastFlushTime < FLUSH_MIN_INTERVAL then return end
            lastFlushTime = now
            self:Hide()
            RunFlush()
        end)
    end
    dispatchFrame:Show()
end

local bagPending = false
local prevSpellToItem = {}

local function SnapshotSpellItemMap()
    wipe(prevSpellToItem)
    for spellID, itemID in pairs(spellToItemID) do
        prevSpellToItem[spellID] = itemID
    end
end

local function SpellItemMapChanged()
    for spellID, itemID in pairs(spellToItemID) do
        if prevSpellToItem[spellID] ~= itemID then
            SnapshotSpellItemMap()
            return true
        end
    end
    for spellID in pairs(prevSpellToItem) do
        if spellToItemID[spellID] == nil then
            SnapshotSpellItemMap()
            return true
        end
    end
    return false
end

local function FlushBagUpdate()
    bagPending = false
    InvalidateCache()
    RebuildBagCache()

    if SpellItemMapChanged() then
        InvalidateIconTypes()
        DoRefresh()
        UpdateAllCooldowns()
        CDM.SetUpdatePending(true)
    else
        UpdateIconsByType("consumable")
    end
end

local manualSpellMap = {}

local function AddToManualSpellMap(spellID, icon)
    if not spellID then return end
    if not manualSpellMap[spellID] then manualSpellMap[spellID] = {} end
    local list = manualSpellMap[spellID]
    for _, existing in ipairs(list) do if existing == icon then return end end
    list[#list + 1] = icon
end

RebuildManualSpellMap = function()
    wipe(manualSpellMap)
    local buffsIcons = icons.buffs
    local buffsCount = iconCounts.buffs
    for versionIndex = 1, buffsCount do
        local icon = buffsIcons[versionIndex]
        if icon then
            local frameData = FrameData[icon]
            if frameData and frameData._manualBuff then
                local rawID = frameData.customSpellID
                AddToManualSpellMap(rawID, icon)

                if frameData.isItemByPrefix or frameData.iconType == "consumable" or frameData.iconType == "trinket" then
                    local _, sid = GetItemSpell(frameData.itemID or rawID)
                    AddToManualSpellMap(sid, icon)
                end
            end
        end
    end
end

local function OnSpellCastSucceeded(spellID)
    if not spellID then return end
    if issecretvalue(spellID) then return end
    local matched = manualSpellMap[spellID]
    if not matched then return end
    local now = GetTime()
    for _, icon in ipairs(matched) do
        local frameData = FrameData[icon]
        if frameData then
            frameData._manualStart = now
            if frameData.storedValue ~= nil then
                manualStartByStored[frameData.storedValue] = now
            end
            UpdateIcon(icon)
        end
    end
end

local hotEventsRegistered = false
local itemEventsRegistered = false

local function RegisterHotEvents()
    if hotEventsRegistered then return end
    hotEventsRegistered = true
    needsFullBuffScan = true
    BUI.Events:Register("SPELL_UPDATE_COOLDOWN", "CDM.Custom.Hot", function()
        if not next(spellMap) and not next(itemMap) then return end
        cooldownPending = true
        QueueDispatch()
    end)
    BUI.Events:Register("SPELL_UPDATE_CHARGES", "CDM.Custom.Charges", function()
        if not next(spellMap) and not next(itemMap) then return end
        cooldownPending = true
        QueueDispatch()
    end)
    BUI.Events:Register("SPELL_UPDATE_USABLE", "CDM.Custom.Usable", function()
        if not next(spellMap) then return end
        usablePending = true
        QueueDispatch()
    end)
    BUI.Events:RegisterUnit("UNIT_AURA", "player", "CDM.Custom.Aura", function(event, unit, updateInfo)
        auraPending = true
        local fullUpdate = true
        if updateInfo then
            local rawFullUpdate = updateInfo.isFullUpdate
            fullUpdate = issecretvalue(rawFullUpdate) and true or rawFullUpdate
        end
        if fullUpdate then
            needsFullBuffScan = true
        elseif not needsFullBuffScan then
            local added   = updateInfo.addedAuras
            local removed = updateInfo.removedAuraInstanceIDs
            local updated = updateInfo.updatedAuraInstanceIDs
            if issecretvalue(added) or issecretvalue(removed) or issecretvalue(updated) then
                needsFullBuffScan = true
            else
                if added then
                    for _, auraData in ipairs(added) do
                        local addedSpellID = auraData.spellId
                        if addedSpellID and not issecretvalue(addedSpellID) then
                            changedBuffSpellIDs[addedSpellID] = true
                        elseif addedSpellID then
                            needsFullBuffScan = true
                        end
                    end
                end
                if removed then
                    for _, rawInstanceID in ipairs(removed) do
                        local removedInstanceID = Tools.SafeNum(rawInstanceID)
                        if removedInstanceID then
                            changedBuffInstanceIDs[removedInstanceID] = true
                        else
                            needsFullBuffScan = true
                        end
                    end
                end
                if updated then
                    for _, rawInstanceID in ipairs(updated) do
                        local updatedInstanceID = Tools.SafeNum(rawInstanceID)
                        if updatedInstanceID then
                            changedBuffInstanceIDs[updatedInstanceID] = true
                        else
                            needsFullBuffScan = true
                        end
                    end
                end
            end
        end
        QueueDispatch()
    end)
    BUI.Events:RegisterUnit("UNIT_SPELLCAST_SUCCEEDED", "player", "CDM.Custom.Cast", function(event, unit, castGUID, spellID)
        OnSpellCastSucceeded(spellID)
    end)
end

local function UnregisterHotEvents()
    if not hotEventsRegistered then return end
    hotEventsRegistered = false
    BUI.Events:Unregister("SPELL_UPDATE_COOLDOWN", "CDM.Custom.Hot")
    BUI.Events:Unregister("SPELL_UPDATE_CHARGES", "CDM.Custom.Charges")
    BUI.Events:Unregister("SPELL_UPDATE_USABLE", "CDM.Custom.Usable")
    BUI.Events:Unregister("UNIT_AURA", "CDM.Custom.Aura")
    BUI.Events:Unregister("UNIT_SPELLCAST_SUCCEEDED", "CDM.Custom.Cast")
end

local function RegisterItemEvents()
    if itemEventsRegistered then return end
    itemEventsRegistered = true
    BUI.Events:Register("BAG_UPDATE_COOLDOWN", "CDM.Custom.BagCD", function()
        cooldownPending = true
        QueueDispatch()
    end)
    BUI.Events:Register("BAG_UPDATE_DELAYED", "CDM.Custom.BagDelayed", function()
        if not bagPending then
            bagPending = true
            C_Timer_After(0.05, FlushBagUpdate)
        end
    end)
end

local function UnregisterItemEvents()
    if not itemEventsRegistered then return end
    itemEventsRegistered = false
    BUI.Events:Unregister("BAG_UPDATE_COOLDOWN", "CDM.Custom.BagCD")
    BUI.Events:Unregister("BAG_UPDATE_DELAYED", "CDM.Custom.BagDelayed")
end

local function UpdateHotEventState()
    if iconCounts.essential > 0 or iconCounts.utility > 0 or iconCounts.buffs > 0 then
        RegisterHotEvents()
    else
        UnregisterHotEvents()
        UnregisterItemEvents()
    end

    if next(itemMap) or next(trinketSlotIcons) then
        RegisterItemEvents()
    else
        UnregisterItemEvents()
    end
end

BUI.Events:Register("PLAYER_ENTERING_WORLD", "CDM.Custom.PEW", function()
    wipe(trinketSlotRetryCount)
    InvalidateCache()
    DoRefresh()
    UpdateHotEventState()
    C_Timer_After(2, function()
        InvalidateCache()
        DoRefresh()
        UpdateHotEventState()
    end)
end)

BUI.Events:Register("PLAYER_EQUIPMENT_CHANGED", "CDM.Custom.Equip", function()
    DoRefresh()
    CDM.UpdateShowOnlyOnCDWatcher()
end)

BUI.Events:Register("TRAIT_CONFIG_UPDATED", "CDM.Custom.Traits", function(event, arg1)
    local activeID = C_ClassTalents.GetActiveConfigID()
    if arg1 and activeID and arg1 ~= activeID then return end
    CDM.InvalidateBuildKey()
    InvalidateCache()
end)

BUI.Events:OnTalentBurst("CDM.Custom", function()
    DoRefresh()
    UpdateHotEventState()
end)

CDM.Custom = {}

function CDM.Custom.IsPotionItem(itemID)
    if not itemID then return false end
    local _, _, _, _, _, itemClass, itemSubclass = C_Item.GetItemInfoInstant(itemID)
    return itemClass == Enum.ItemClass.Consumable
        and (itemSubclass == Enum.ItemConsumableSubclass.Potion
          or itemSubclass == Enum.ItemConsumableSubclass.Flask)
end

CDM.Custom.GetPotionVersions = GetPotionVersions
CDM.Custom.GetCraftedQualityInfo = BUI.Lookup.CraftedQuality
CDM.Custom.AggregateCountPrio = AggregateCountPrio
CDM.Custom.InvalidateBagCache = InvalidateCache

IconEngine.SetBagResolver(GetItemForSpell, AggregateCount)

function CDM.Custom.Refresh(viewerKey)
    if viewerKey then
        RefreshViewer(viewerKey)
        if viewerKey == "buffs" then RebuildManualSpellMap() end
    else
        DoRefresh()
    end
    UpdateHotEventState()
end

function CDM.Custom.IsEquippedOrKnownOrInBagsIcon(icon)
    local frameData = FrameData[icon]
    if not frameData or not frameData.customSpellID then return true end
    if frameData._availChecked then return frameData._availResult end
    frameData._availChecked = true

    if not frameData.iconType then
        local iconType, itemID = ClassifyAsSpellOrItem(frameData.customSpellID, frameData.isItemByPrefix)
        frameData.iconType = iconType
        frameData.itemID = itemID
    end
    if frameData.isItemByPrefix then
        frameData._availResult = IsEquippedOrKnownOrInBags(frameData.iconType, frameData.customSpellID, frameData.itemID, true)
        return frameData._availResult
    end
    if not Tools.IsSpellUsable(frameData.customSpellID) and frameData.iconType ~= "trinket" then
        local activeID = frameData._activeChoiceID
        if activeID and activeID ~= frameData.customSpellID and Tools.IsSpellUsable(activeID) then
            frameData.customSpellID = activeID
            frameData.customKey = 'custom:' .. activeID
            frameData.iconType = nil
            frameData.itemID = nil
        else
            frameData._availResult = false
            return false
        end
    end
    frameData._availResult = IsEquippedOrKnownOrInBags(frameData.iconType, frameData.customSpellID, frameData.itemID, true)
    return frameData._availResult
end

function CDM.Custom.GetIcons(viewerKey)
    return icons[viewerKey], iconCounts[viewerKey]
end

CDM.Custom.IsTrackedEntryUsable = IsTrackedEntryUsable

function CDM.Custom.UpdateIcon(icon)
    UpdateIcon(icon)
end
