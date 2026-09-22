local _, BUI = ...

local pairs, ipairs, wipe = pairs, ipairs, wipe
local type, select, tonumber = type, select, tonumber

local C_Item = C_Item
local C_Spell = C_Spell
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitAffectingCombat = UnitAffectingCombat

local Pixel = BUI.Pixel
BUI.CDM = {}
local CDM = BUI.CDM
local FrameData = setmetatable({}, { __mode = "k" })

CDM.FrameData = FrameData

local function GetFrameData(frame)
    local data = FrameData[frame]
    if not data then
        data = {}
        FrameData[frame] = data
    end
    return data
end
CDM.GetFrameData = GetFrameData

function CDM._OnBuffIconShow()
    CDM.MarkBuffCenterDirty()
end
function CDM._OnBuffIconHide()
    CDM.MarkBuffCenterDirty()
end

CDM.VIEWERS = {
    essential = "EssentialCooldownViewer",
    utility = "UtilityCooldownViewer",
    buffs = "BuffIconCooldownViewer",
}

CDM.SYNCED_SETTINGS = {
    iconWidth = true, iconHeight = true, spacing = true, zoom = true,
    rowGrowth = true, vertical = true, borderSize = true, borderColor = true,
    textSize = true, textPosition = true, textOffsetX = true, textOffsetY = true, textColor = true,
    cooldownTextSize = true, cooldownTextPosition = true,
    cooldownTextOffsetX = true, cooldownTextOffsetY = true, cooldownTextColor = true,
    showCooldownDecimals = true, cooldownDecimalThreshold = true,
    cooldownWarnSeconds = true, cooldownWarnColor = true,
    centerHorizontally = true, iconsPerRow = true,
    row2Count = true, row3Count = true,
    showFlash = true, showEdge = true,
    reverseSwipe = true, swipeColor = true, keepAspectRatio = true,
}

CDM.PreviewIcons = { 136048, 135994, 136018, 135936, 136085, 136074, 135932 }

CDM.STRIP_ELEMENTS = {
    "Border", "Shadow", "IconBorder", "NormalTexture", "Flash", "Backdrop",
    "background", "Background", "HighlightTexture", "highlight", "Highlight",
    "active", "Active", "ActiveOverlay", "Shine", "shine", "Bling", "bling",
}
CDM.STRIP_ELEMENTS_COUNT = #CDM.STRIP_ELEMENTS

CDM.HIDE_ELEMENTS = {
    "Border", "IconBorder", "NormalTexture", "Flash", "CheckedTexture",
    "SlotBackground", "SlotArt", "SlotFrame",
}
CDM.HIDE_ELEMENTS_COUNT = #CDM.HIDE_ELEMENTS

CDM.SHOW_ELEMENTS = {
    "Border", "IconBorder", "NormalTexture", "Flash", "Glow", "CheckedTexture",
}
CDM.SHOW_ELEMENTS_COUNT = #CDM.SHOW_ELEMENTS

CDM.VIEWER_KEYS = { "essential", "utility", "buffs" }
CDM.VIEWER_KEYS_COUNT = 3

CDM.VIEWER_NAMES = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }

CDM.state = {
    initialized = false,
    initComplete = false,
    skinVersion = 1,
}

CDM.controls = {}

function CDM.PackInto(buf, ...)
    local count = select('#', ...)
    for i = 1, count do buf[i] = select(i, ...) end
    for i = count + 1, #buf do buf[i] = nil end
    return buf, count
end

local TrackedIcons = { essential = {}, utility = {}, buffs = {} }
local TrackedCounts = { essential = 0, utility = 0, buffs = 0 }

local trackSeqCounter = 0

function CDM.TrackIcon(key, icon)
    local frameData = GetFrameData(icon)
    if frameData.tracked == key then return end
    if frameData.tracked then CDM.UntrackIcon(frameData.tracked, icon) end

    if not frameData.trackSeq then
        trackSeqCounter = trackSeqCounter + 1
        frameData.trackSeq = trackSeqCounter
    end

    local list = TrackedIcons[key]
    local count = TrackedCounts[key] + 1
    list[count] = icon
    frameData.trackIndex = count
    frameData.tracked = key
    TrackedCounts[key] = count
    CDM._iconChurn[key] = (CDM._iconChurn[key] or 0) + 1
    CDM.InvalidateIconCache(key)
    CDM.NotifyTrackedIconsChanged(key)
end

function CDM.UntrackIcon(key, icon)
    local frameData = FrameData[icon]
    if not frameData or frameData.tracked ~= key then return end

    local list = TrackedIcons[key]
    local count = TrackedCounts[key]
    local idx = frameData.trackIndex

    if idx and idx <= count then
        local last = list[count]
        if last and last ~= icon then
            list[idx] = last
            GetFrameData(last).trackIndex = idx
        end
        list[count] = nil
        TrackedCounts[key] = count - 1
    end

    frameData.trackIndex = nil
    frameData.tracked = nil
    CDM._iconChurn[key] = (CDM._iconChurn[key] or 0) + 1
    CDM.InvalidateIconCache(key)
    CDM.NotifyTrackedIconsChanged(key)
end

CDM._iconChurn = {}

function CDM.GetIconChurn(key)
    return CDM._iconChurn[key] or 0
end

local trackedChangedListeners = {}

function CDM.OnTrackedIconsChanged(callback)
    trackedChangedListeners[#trackedChangedListeners + 1] = callback
end

function CDM.NotifyTrackedIconsChanged(key)
    for i = 1, #trackedChangedListeners do
        trackedChangedListeners[i](key)
    end
end

function CDM.GetTrackedIcons(key)
    return TrackedIcons[key], TrackedCounts[key]
end

function CDM.IsViewerEnabled(key)
    local db = BUI.GetDB()
    local settings = db.cdm[key]
    return settings and settings.enabled
end

function CDM.ForAllIcons(callback)
    for i = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[i]
        if CDM.IsViewerEnabled(key) then
            local list = TrackedIcons[key]
            local count = TrackedCounts[key]
            for j = 1, count do
                callback(list[j], key)
            end
        end
    end
end

function CDM.IconMatchesSpell(icon, spellID)
    local cooldownInfo = icon.cooldownInfo
    if not cooldownInfo then return false end
    if cooldownInfo.overrideSpellID == spellID then return true end
    if cooldownInfo.spellID == spellID then return true end
    local linked = cooldownInfo.linkedSpellIDs
    if linked then
        for j = 1, #linked do
            if linked[j] == spellID then return true end
        end
    end
    return false
end

function CDM.FindIconForSpell(spellID, skipBuffs)
    for i = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[i]
        if not (skipBuffs and key == 'buffs') and CDM.IsViewerEnabled(key) then
            local list, count = CDM.GetTrackedIcons(key)
            for j = 1, count do
                if CDM.IconMatchesSpell(list[j], spellID) then
                    return list[j]
                end
            end
        end
    end
    return nil
end

local ViewerNameToKey = {}
for key, viewerName in pairs(CDM.VIEWERS) do ViewerNameToKey[viewerName] = key end
CDM.ViewerNameToKey = ViewerNameToKey

function CDM.GetSettings(key)
    return BUI.GetDB().cdm[key]
end

function CDM.GetViewerKey(viewer)
    local frameData = FrameData[viewer]
    if frameData and frameData.viewerKey then return frameData.viewerKey end
    local name = viewer:GetName()
    local key = ViewerNameToKey[name]
    if key then
        frameData = GetFrameData(viewer)
        frameData.viewerKey = key
    end
    return key
end

function CDM.IsCooldownIcon(frame)
    return frame.Icon and frame.Cooldown
end

local function ReadCooldownSpellID(cooldownInfo)
    local sid = cooldownInfo.spellID
    if issecretvalue(sid) then sid = nil end
    if sid then return sid end
    local overrideSpellID = cooldownInfo.overrideSpellID
    if issecretvalue(overrideSpellID) then overrideSpellID = nil end
    return overrideSpellID
end

function CDM.GetStableSpellID(icon)
    local frameData = FrameData[icon]
    if frameData then
        if frameData.storedValue then return frameData.storedValue end
        if frameData.customSpellID then return frameData.customSpellID end
    end
    local cooldownInfo = icon.cooldownInfo
    if not cooldownInfo then return nil end
    return ReadCooldownSpellID(cooldownInfo)
end

function CDM.GetSortKey(icon)
    local frameData = FrameData[icon]
    if frameData then
        if frameData.customIcon and frameData.customKey then return frameData.customKey end
        if frameData.storedValue then return frameData.storedValue end
        if frameData.customSpellID then return frameData.customSpellID end
    end
    local cooldownInfo = icon.cooldownInfo
    if not cooldownInfo then return nil end
    return ReadCooldownSpellID(cooldownInfo)
end

local RACIAL_SPELL_IDS = {
    [59752] = true,
    [20594] = true,
    [58984] = true,
    [20589] = true,
    [28880] = true,
    [59542] = true,
    [59543] = true,
    [59544] = true,
    [59545] = true,
    [59547] = true,
    [59548] = true,
    [121093] = true,
    [68992] = true,
    [87840] = true,
    [107079] = true,
    [260364] = true,
    [256948] = true,
    [255647] = true,
    [265221] = true,
    [287712] = true,
    [291944] = true,
    [312924] = true,
    [20572] = true,
    [33697] = true,
    [33702] = true,
    [7744] = true,
    [20577] = true,
    [20549] = true,
    [26297] = true,
    [28730] = true, [25046] = true, [50613] = true, [69179] = true,
    [80483] = true, [129597] = true, [155145] = true, [202719] = true,
    [232633] = true,
    [69070] = true,
    [69041] = true,
    [255654] = true,
    [274738] = true,
    [280870] = true,
    [292380] = true,
    [312411] = true,
    [369536] = true,
    [368970] = true,
    [357214] = true,
    [358267] = true,
    [436344] = true,
    [1237885] = true,
    [1238686] = true,
}

function CDM.IsRacialSpell(spellID) return RACIAL_SPELL_IDS[spellID] == true end

function CDM.GetKnownRacialSpellIDs(out)
    out = out or {}
    wipe(out)
    for id in pairs(RACIAL_SPELL_IDS) do
        if C_SpellBook.IsSpellKnown(id) then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

local _racialScratch = {}
function CDM.ResolveRacialSlot(slot)
    slot = slot or 1
    CDM.GetKnownRacialSpellIDs(_racialScratch)
    return _racialScratch[slot]
end

BUI.IconEngine._isRacialSpell = CDM.IsRacialSpell
BUI.IconEngine.SetRacialSlotResolver(CDM.ResolveRacialSlot)

function CDM.GetUnavailableTag(storedValue, isItemID)
    if CDM.Custom.IsTrackedEntryUsable(storedValue, true) then
        return nil
    end

    if type(storedValue) == "string" then
        local rSlot = storedValue:match("^racial:(%d)$")
        if rSlot then
            local resolved = CDM.ResolveRacialSlot(tonumber(rSlot))
            if resolved then return nil end
            return "No Racial"
        end
    end

    if isItemID then
        if type(storedValue) == "string" then
            local slot = storedValue:match("^trinket:(%d)$")
            if slot then
                local resolved = GetInventoryItemID("player", slot == "1" and 13 or 14)
                if resolved then return nil end
                return "Empty Slot"
            end
        end
        local id
        if type(storedValue) == "string" and storedValue:match("^item:") then
            id = tonumber(storedValue:match("^item:(%d+)"))
        else
            id = tonumber(storedValue)
        end
        if id then
            local _, _, _, equipLoc = C_Item.GetItemInfoInstant(id)
            if equipLoc == "INVTYPE_TRINKET" then
                return "Not Equipped"
            end
        end
        return "Not In Bags"
    end

    local id = tonumber(storedValue)
    if not id then return "Unknown" end

    local name = C_Spell.GetSpellName(id)
    if not name then return "Unknown Spell" end

    if C_SpellBook.IsSpellKnown(id) then
        return nil
    end

    if RACIAL_SPELL_IDS[id] then
        return "Other Race"
    end

    if CDM.IsClassSpell(id) then
        return "Other Spec"
    end

    return "Unavailable"
end


function CDM.GetCountFont(icon)
    local frameData = FrameData[icon]
    if frameData then
        if frameData.countFont then return frameData.countFont end
        if frameData.countFontNil then return nil end
    end

    local result = nil
    if icon.ChargeCount and icon.ChargeCount.Current then
        result = icon.ChargeCount.Current
    end
    if not result and icon.Applications and icon.Applications.Applications then
        result = icon.Applications.Applications
    end
    if not result then
        result = icon.Count or icon.count
    end

    frameData = GetFrameData(icon)
    if result then frameData.countFont = result else frameData.countFontNil = true end
    return result
end

function CDM.RegisterControl(viewerKey, settingKey, control, controlType)
    CDM.controls[viewerKey .. "_" .. settingKey] = { control = control, type = controlType or "slider" }
end

function CDM.ClearControls() wipe(CDM.controls) end

local function UpdateSyncedControl(viewerKey, settingKey, value, includeColorZoom)
    local entry = CDM.controls[viewerKey .. "_" .. settingKey]
    if not entry or not entry.control then return end
    local control, controlType = entry.control, entry.type
    if includeColorZoom and controlType == "zoom" then
        if control.SetValue then control:SetValue(value * 100) end
    elseif controlType == "slider" or controlType == "toggle" or controlType == "dropdown" then
        if control.SetValue then control:SetValue(value) end
    elseif includeColorZoom and controlType == "colorswatch" then
        if control.SetColor and type(value) == "table" then
            control:SetColor(value[1], value[2], value[3], value[4])
        end
    end
end

function CDM.SyncSetting(settingKey, value)
    local db = BUI.GetDB()
    if not db.cdm.syncViewers then return false end
    if not CDM.SYNCED_SETTINGS[settingKey] then return false end

    local essential, utility = db.cdm.essential, db.cdm.utility
    if essential then essential[settingKey] = value end
    if utility then utility[settingKey] = value end

    UpdateSyncedControl("essential", settingKey, value, true)
    UpdateSyncedControl("utility", settingKey, value, true)

    if settingKey == "centerHorizontally" then
        local essX = CDM.controls["essential_X"]
        local utilX = CDM.controls["utility_X"]
        local essSlider = essX and essX.control
        local utilSlider = utilX and utilX.control
        if value then
            if essential then essential.positionX = 0 end
            if utility then utility.positionX = 0 end
            if essSlider and essSlider.SetValue then essSlider:SetValue(0) end
            if utilSlider and utilSlider.SetValue then utilSlider:SetValue(0) end
        end
        if essSlider and essSlider.SetLocked then essSlider:SetLocked(value) end
        if utilSlider and utilSlider.SetLocked then utilSlider:SetLocked(value) end
    end

    if CDM.SIZE_SETTINGS[settingKey] then
        CDM.RefreshSizeSettings()
    else
        CDM.RefreshSkinSettings()
    end
    return true
end

function CDM.SyncSettingLayout(settingKey, value)
    local db = BUI.GetDB()
    if not db.cdm.syncViewers then return false end
    if not CDM.SYNCED_SETTINGS[settingKey] then return false end

    local essential, utility = db.cdm.essential, db.cdm.utility
    if essential then essential[settingKey] = value end
    if utility then utility[settingKey] = value end

    UpdateSyncedControl("essential", settingKey, value, false)
    UpdateSyncedControl("utility", settingKey, value, false)
    CDM.RefreshLayoutOnly()
    return true
end

function CDM.InvalidateSkinCache()
    CDM.state.skinVersion = CDM.state.skinVersion + 1
    for _, frameData in pairs(FrameData) do
        frameData.countFont = nil
        frameData.countFontNil = nil
    end
end

function CDM.UpdatePixelValues(key)
    local settings = CDM.GetSettings(key)
    if not settings then return end
    settings._pxW = Pixel.Scale(settings.iconWidth)    settings._pxH = Pixel.Scale(settings.iconHeight)    settings._pxGap = Pixel.Scale(settings.spacing)
end

function CDM.UpdateAllPixelValues()
    for i = 1, CDM.VIEWER_KEYS_COUNT do
        CDM.UpdatePixelValues(CDM.VIEWER_KEYS[i])
    end
end

local min = math.min

function CDM.NextRowSize(rowIndex, remaining, perRow, row2Count, row3Count)
    if rowIndex == 1 then
        return min(perRow, remaining)
    end

    if row2Count == nil and row3Count == nil then
        return remaining
    end

    local cap = perRow
    if rowIndex == 2 and row2Count and row2Count > 0 then
        cap = row2Count
    elseif rowIndex == 3 and row3Count and row3Count > 0 then
        cap = row3Count
    end
    if cap <= 0 then cap = remaining end
    return min(cap, remaining)
end

function CDM.RowMetrics(count, perRow, row2Count, row3Count)
    local numRows, maxCols = 0, 0
    local remaining = count
    while remaining > 0 do
        numRows = numRows + 1
        local rowSize = CDM.NextRowSize(numRows, remaining, perRow, row2Count, row3Count)
        if rowSize <= 0 then break end
        if rowSize > maxCols then maxCols = rowSize end
        remaining = remaining - rowSize
    end
    return numRows, maxCols
end

function CDM.NotifyUnitFrames()
    BUI.UnitFrames.RefreshAnchoredFrames()
end

local tostring = tostring
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local C_CooldownViewer = C_CooldownViewer

local cachedBuildKey
local function GetBuildKey()
    if cachedBuildKey then return cachedBuildKey end
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec) or 0
    cachedBuildKey = tostring(specID)
    return cachedBuildKey
end

CDM.GetBuildKey = GetBuildKey

function CDM.InvalidateBuildKey()
    cachedBuildKey = nil
end

local VIEWER_CATEGORY
local blizzardCDMSpellCache = {}
local classSpellCache = {}

local function GetStorage()
    local globalDB = BUI.db and BUI.db.global
    if not globalDB then return nil end
    globalDB.cdmSpecCache = globalDB.cdmSpecCache or {}
    return globalDB.cdmSpecCache
end

local function GetSpecBucket(buildKey, create)
    local store = GetStorage()
    if not store then return nil end
    local bucket = store[buildKey]
    if not bucket and create then
        bucket = { class = nil, viewers = {} }
        store[buildKey] = bucket
    end
    return bucket
end

local function BuildBlizzardCDMSpellCache(viewerKey)
    local buildKey = GetBuildKey()
    local memoSpec = blizzardCDMSpellCache[buildKey]
    if memoSpec and memoSpec[viewerKey] then return memoSpec[viewerKey] end

    local stored = GetSpecBucket(buildKey, false)
    if stored and stored.viewers and stored.viewers[viewerKey] then
        memoSpec = memoSpec or {}
        memoSpec[viewerKey] = stored.viewers[viewerKey]
        blizzardCDMSpellCache[buildKey] = memoSpec
        return memoSpec[viewerKey]
    end

    if not VIEWER_CATEGORY then
        local cats = Enum.CooldownViewerCategory
        VIEWER_CATEGORY = {
            essential = cats.Essential,
            utility   = cats.Utility,
            buffs     = cats.TrackedBuff,
        }
    end
    local cat = VIEWER_CATEGORY[viewerKey]
    if not cat then return nil end

    local cache = {}
    local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
    if ids then
        local GetInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo
        for j = 1, #ids do
            local info = GetInfo(ids[j])
            if info and info.spellID then cache[info.spellID] = true end
        end
    end

    memoSpec = memoSpec or {}
    memoSpec[viewerKey] = cache
    blizzardCDMSpellCache[buildKey] = memoSpec

    local bucket = GetSpecBucket(buildKey, true)
    if bucket then bucket.viewers[viewerKey] = cache end
    return cache
end

function CDM.IsBlizzardCDMSpell(spellID, viewerKey)
    local cache = BuildBlizzardCDMSpellCache(viewerKey)
    return cache and cache[spellID] == true or false
end

local function BuildClassSpellCache()
    local buildKey = GetBuildKey()
    if classSpellCache[buildKey] then return classSpellCache[buildKey] end

    local stored = GetSpecBucket(buildKey, false)
    if stored and stored.class then
        classSpellCache[buildKey] = stored.class
        return stored.class
    end

    local cache = {}
    local GetInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo
    local nilStreak = 0
    for cooldownID = 1, 1500 do
        local info = GetInfo(cooldownID)
        if info then
            nilStreak = 0
            cache[info.spellID] = true
            if info.linkedSpellIDs then
                for _, linkedID in ipairs(info.linkedSpellIDs) do
                    cache[linkedID] = true
                end
            end
        else
            nilStreak = nilStreak + 1
            if nilStreak > 200 then break end
        end
    end

    classSpellCache[buildKey] = cache
    local bucket = GetSpecBucket(buildKey, true)
    if bucket then bucket.class = cache end
    return cache
end

function CDM.InvalidateClassSpellCache()
    local buildKey = GetBuildKey()
    classSpellCache[buildKey] = nil
    blizzardCDMSpellCache[buildKey] = nil
    local store = GetStorage()
    if store then store[buildKey] = nil end
end

function CDM.IsClassSpell(spellID)
    local cache = BuildClassSpellCache()
    return cache and cache[spellID] == true or false
end

function CDM.GetContextualOpacity()
    return BUI.Visibility.GetContextualOpacity("CDM")
end

local lastAlpha = {}
local lastDead

function CDM.InvalidateOpacityCache()
    wipe(lastAlpha)
end

function CDM.UpdateOpacity(instant)
    CDM.RefreshBuffOpacityCache()

    local dead = UnitIsDeadOrGhost('player')
    if dead ~= lastDead then
        lastDead = dead
        wipe(lastAlpha)
        if dead then CDM.ClearAllHighlights() end
    end

    for i = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[i]
        local opacity = CDM.GetContextualOpacity(key)
        local anchor = CDM.Anchors[key]
        local visAlpha = anchor and anchor._iconAlpha or 1
        local targetAlpha = (opacity / 100) * visAlpha
        if lastAlpha[key] ~= targetAlpha then
            lastAlpha[key] = targetAlpha
            local invisible = targetAlpha < 0.01
            if anchor then
                if invisible then
                    anchor:Hide()
                    anchor._opacityHidden = true
                elseif anchor._opacityHidden then
                    anchor._opacityHidden = nil
                    anchor:Show()
                end
            end
            local list, count = CDM.GetTrackedIcons(key)
            for j = 1, count do
                local frame = list[j]
                local frameData = FrameData[frame]

                if not frameData or (not frameData.hidden and not frameData.parked) then
                    frame:SetAlpha(targetAlpha)
                    if frameData and frameData.customIcon and frame.Icon then
                        if dead then
                            frame.Icon:SetVertexColor(0.4, 0.4, 0.4)
                        else
                            frame.Icon:SetVertexColor(1, 1, 1)
                        end
                    end
                end
            end
        end
    end
end

function CDM.HighlightsSuppressed()
    if UnitIsDeadOrGhost('player') then return true end
    if InCombatLockdown() then return false end
    return (UnitCastingInfo('player') or UnitChannelInfo('player')) ~= nil
end

function CDM.ClearAllHighlights()
    CDM.RefreshAssistHighlight()
    CDM.PressHighlight.ForceClear()
    CDM.ForAllIcons(CDM.StopProcGlow)
end

function CDM.RefreshAll(immediate)
    local db = BUI.GetDB()

    CDM.RefreshBuffOverrideCache()

    for i = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[i]
        if not CDM.Anchors[key] then
            CDM.CreateAnchor(key)
        end

        local name = CDM.VIEWERS[key]
        local viewer = name and _G[name]
        local settings = db.cdm[key]
        local isEnabled = settings and settings.enabled

        if viewer then
            if isEnabled then
                CDM.HookViewer(viewer, key)
                CDM.ApplyAnchorPosition(key)
                CDM.SaveToEditModeLayout(key)
            else
                CDM.RestoreViewer(viewer, key)
            end
        end
    end

    CDM.state.initComplete = true

    CDM.UpdateAllPixelValues()
    CDM.InvalidateSkinCache()
    CDM.InvalidateOpacityCache()
    CDM.UpdateOpacity(true)

    CDM.Custom.Refresh()

    CDM.ApplyAllPositions()

    CDM.InvalidateIconCache()

    if immediate then
        CDM.LayoutAllViewers()
        CDM.NotifyDependents()
        CDM.ClearDirty()
    else
        CDM.MarkAllDirty()
    end

    CDM.RefreshBuffsPreview()
    CDM.SetupBuffCentering()
end

function CDM.RefreshSkinSettings()
    CDM.UpdateAllPixelValues()
    CDM.InvalidateSkinCache()
    CDM.RefreshAll(true)
    BUI.Anchor.OnAnchorSizeChanged()

    CDM.RefreshBuffBarSkin()
end

CDM.SIZE_SETTINGS = { iconWidth = true, iconHeight = true, zoom = true, keepAspectRatio = true }

function CDM.RefreshSizeSettings()
    local db = BUI.GetDB()
    for i = 1, CDM.VIEWER_KEYS_COUNT do
        local key = CDM.VIEWER_KEYS[i]
        local settings = db.cdm[key]
        if settings and settings.enabled then
            local list, count = CDM.GetTrackedIcons(key)
            for j = 1, count do
                local icon = list[j]
                local texture = icon.Icon
                if texture then
                    texture:SetTexCoord(CDM.GetAspectTexCoords(settings.zoom, settings.iconWidth, settings.iconHeight, settings.keepAspectRatio))
                end
                CDM.ApplyFlashGeometry(icon, settings)
            end
        end
    end
    CDM.RefreshLayoutOnly()
end
