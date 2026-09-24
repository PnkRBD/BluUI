local _, BUI = ...

local _G = _G
local wipe, type = wipe, type
local tonumber = tonumber
local math_ceil = math.ceil

local CreateFrame = CreateFrame
local GetBindingKey = GetBindingKey
local GetActionBarPage = GetActionBarPage
local HasAction = HasAction
local GetActionInfo = GetActionInfo
local GetMacroBody = GetMacroBody
local GetMacroInfo = GetMacroInfo
local GetMacroSpell = GetMacroSpell
local GetMacroItem = GetMacroItem
local GetMacroIndexByName = GetMacroIndexByName
local GetActionText = GetActionText
local GetItemSpell = GetItemSpell
local C_Spell = C_Spell
local C_ActionBar = C_ActionBar

local Tools = BUI.Tools
local Pixel = BUI.Pixel

local CDM = BUI.CDM
local FrameData = CDM.FrameData

local SLOTS_PER_PAGE = 12

local STABLE_MAIN_PAGES = { 1, 7, 8, 9, 10, 11 }

local BAR_COMMANDS = {
    [3]  = "MULTIACTIONBAR3BUTTON",
    [4]  = "MULTIACTIONBAR4BUTTON",
    [5]  = "MULTIACTIONBAR2BUTTON",
    [6]  = "MULTIACTIONBAR1BUTTON",
    [13] = "MULTIACTIONBAR5BUTTON",
    [14] = "MULTIACTIONBAR6BUTTON",
    [15] = "MULTIACTIONBAR7BUTTON",
    [16] = "MULTIACTIONBAR8BUTTON",
}

local mainBarSlots

local function CurrentOverridePage()
    if HasOverrideActionBar() then
        return GetOverrideBarIndex()
    end
    if HasVehicleActionBar() then
        return GetVehicleBarIndex()
    end
    if HasTempShapeshiftActionBar() then
        return GetTempShapeshiftBarIndex()
    end
    return nil
end

local function MapWholePage(target, page)
    local base = (page - 1) * SLOTS_PER_PAGE
    for index = 1, SLOTS_PER_PAGE do
        target[base + index] = index
    end
end

local function MainBarFollowsForms()
    local settings = BUI.ActionBars.GetBarSettings(1)
    if not settings or not settings.enabled then return true end
    return settings.pagingEnabled == true
end

local function BuildMainBarSlots()
    local target = {}
    if MainBarFollowsForms() then
        for index = 1, #STABLE_MAIN_PAGES do
            MapWholePage(target, STABLE_MAIN_PAGES[index])
        end
        local livePage = CurrentOverridePage()
        if not livePage then
            local page = GetActionBarPage()
            if type(page) == "number" and page > 1 then livePage = page end
        end
        if livePage then MapWholePage(target, livePage) end
    else
        MapWholePage(target, 1)
    end
    return target
end

local function MainBarIndexForSlot(slot)
    if not mainBarSlots then
        mainBarSlots = BuildMainBarSlots()
    end
    return mainBarSlots[slot]
end

local function BindingForSlot(slot)
    if not slot or slot < 1 then return nil end

    local mainIndex = MainBarIndexForSlot(slot)
    if mainIndex then
        return "ACTIONBUTTON" .. mainIndex
    end

    local command = BAR_COMMANDS[math_ceil(slot / SLOTS_PER_PAGE)]
    if not command then return nil end
    return command .. (((slot - 1) % SLOTS_PER_PAGE) + 1)
end

local function KeybindForSlot(slot)
    local command = BindingForSlot(slot)
    if not command then return nil, nil end
    local key = GetBindingKey(command)
    if key and key ~= "" then return BUI.Keybinds.Format(key), key end
    return nil, nil
end

local function ShortestFromSlots(slots)
    local bestFormatted, bestRaw, bestLength
    for slotIndex = 1, #slots do
        local formatted, raw = KeybindForSlot(slots[slotIndex])
        if formatted then
            local length = #formatted
            if not bestFormatted or length < bestLength then
                bestFormatted, bestRaw, bestLength = formatted, raw, length
            end
        end
    end
    return bestFormatted, bestRaw
end

local function SpellName(spellID)
    if not spellID or spellID == 0 then return nil end
    local name = C_Spell.GetSpellName(spellID)
    if name and name ~= "" then return name end
    return nil
end

local function SpellIDFromName(name)
    if not name or name == "" then return nil end
    local numericID = tonumber(name)
    if numericID then
        if C_Spell.DoesSpellExist(numericID) then return numericID end
        return nil
    end
    local id = C_Spell.GetSpellIDForSpellIdentifier(name)
    if id and id ~= 0 then return id end
    return nil
end

local function SpellVariants(spellID)
    local secondVariant, thirdVariant
    local base = C_Spell.GetBaseSpell(spellID)
    if base and base ~= 0 and base ~= spellID then
        secondVariant = base
    end
    local override = Tools.GetOverrideSpell(spellID)
    if override ~= spellID then
        if secondVariant then thirdVariant = override else secondVariant = override end
    end
    return spellID, secondVariant, thirdVariant
end

local function ParseMacroBody(body)
    if not body or body == "" then return nil end
    local results

    for line in body:gmatch("[^\r\n]+") do
        local command, args = line:match("^/(%S+)%s+(.+)$")
        if command and args then
            command = command:lower()
            if command == "cast" or command == "use" or command == "castsequence" then
                if command == "castsequence" then
                    args = args:gsub("^reset=%S+%s*", "")
                end
                for segment in args:gmatch("([^;]+)") do
                    local token = segment:gsub("%[.-%]%s*", ""):gsub("!+", ""):match("^%s*(.-)%s*$")
                    if token and token ~= "" then
                        for part in token:gmatch("([^,]+)") do
                            local spell = part:match("^%s*(.-)%s*$")
                            if spell and spell ~= "" then
                                results = results or {}
                                results[#results + 1] = spell
                            end
                        end
                    end
                end
                break
            end
        end
    end
    return results
end

local function GetMacroBodySafe(macroIndex)
    if not macroIndex or macroIndex == 0 then return nil end
    local body = GetMacroBody(macroIndex)
    if body and body ~= "" then return body end
    local _, _, infoBody = GetMacroInfo(macroIndex)
    if infoBody and infoBody ~= "" then return infoBody end
    return nil
end

local function ResolveMacroIndex(slot, actionID)
    local macroName = GetActionText(slot)
    if macroName and macroName ~= "" then
        local index = GetMacroIndexByName(macroName)
        if index and index > 0 then return index end
    end
    if type(actionID) == "number" and actionID > 0 then
        if GetMacroInfo(actionID) then return actionID end
    end
    return nil
end

local formattedCache = {}
local rawCache = {}
local cacheSize = 0
local MAX_CACHE_SIZE = 2048
local macroByName
local itemSlotMap
local macroMapBuilt = false
local itemMapBuilt = false
local generation = 0
local appliedGeneration = -1

local function InvalidateAll()
    wipe(formattedCache)
    wipe(rawCache)
    cacheSize = 0
    macroByName = nil
    macroMapBuilt = false
    itemSlotMap = nil
    itemMapBuilt = false
    mainBarSlots = nil
    generation = generation + 1
end

local function InvalidateBindings()
    wipe(formattedCache)
    wipe(rawCache)
    cacheSize = 0
    macroByName = nil
    macroMapBuilt = false
    generation = generation + 1
end

local function CacheOne(id, formatted, raw)
    if not id or formattedCache[id] then return end
    if cacheSize >= MAX_CACHE_SIZE then
        wipe(formattedCache)
        wipe(rawCache)
        cacheSize = 0
    end
    formattedCache[id] = formatted
    rawCache[id] = raw
    cacheSize = cacheSize + 1
end

local function CacheForVariants(id1, id2, id3, formatted, raw)
    CacheOne(id1, formatted, raw)
    CacheOne(id2, formatted, raw)
    CacheOne(id3, formatted, raw)
end

local function IndexMacroSpell(spellID, formatted, raw)
    local variant1, variant2, variant3 = SpellVariants(spellID)
    CacheForVariants(variant1, variant2, variant3, formatted, raw)
    local name = SpellName(spellID)
    if name then
        local lower = name:lower()
        if not macroByName[lower] then
            macroByName[lower] = { formatted, raw }
        end
    end
end

local function IndexMacroSlot(slot, actionID, formatted, raw)
    local macroIndex = ResolveMacroIndex(slot, actionID)
    if not macroIndex then return end

    local result = GetMacroSpell(macroIndex)
    if result then
        local spellID = type(result) == "number" and result or SpellIDFromName(result)
        if spellID then IndexMacroSpell(spellID, formatted, raw) end
    end

    local _, _, macroItemID = GetMacroItem(macroIndex)
    if macroItemID and formattedCache[macroItemID] == nil then
        formattedCache[macroItemID] = formatted
        rawCache[macroItemID] = raw
    end

    local body = GetMacroBodySafe(macroIndex)
    local names = ParseMacroBody(body)
    if names then
        for nameIndex = 1, #names do
            local spellText = names[nameIndex]
            local lower = spellText:lower()
            if not macroByName[lower] then
                macroByName[lower] = { formatted, raw }
            end
            local spellID = SpellIDFromName(spellText)
            if spellID and formattedCache[spellID] == nil then
                IndexMacroSpell(spellID, formatted, raw)
            end
        end
    end
end

local function BuildFallbackMaps()
    local needItems = not itemMapBuilt
    local needMacros = not macroMapBuilt
    if not needItems and not needMacros then return end
    if needItems then itemSlotMap = {}; itemMapBuilt = true end
    if needMacros then macroByName = {}; macroMapBuilt = true end

    for slot = 1, 192 do
        if HasAction(slot) then
            local actionType, actionID = GetActionInfo(slot)

            if actionType == "item" and actionID then
                if needItems then
                    local list = itemSlotMap[actionID]
                    if not list then
                        list = {}
                        itemSlotMap[actionID] = list
                    end
                    list[#list + 1] = slot
                end

            elseif actionType == "macro" and actionID then
                if needMacros then
                    local formatted, raw = KeybindForSlot(slot)
                    if formatted then
                        IndexMacroSlot(slot, actionID, formatted, raw)
                    end
                end
            end
        end
    end
end

local function LookupSpell(spellID)
    if not spellID or spellID == 0 then return nil, nil end

    local cached = formattedCache[spellID]
    if cached ~= nil then
        return cached or nil, rawCache[spellID] or nil
    end

    local variant1, variant2, variant3 = SpellVariants(spellID)
    local variants = { variant1, variant2, variant3 }

    for _, variantID in ipairs(variants) do
        local slots = C_ActionBar.FindSpellActionButtons(variantID)
        if slots and #slots > 0 then
            local formatted, raw = ShortestFromSlots(slots)
            if formatted then
                CacheForVariants(variant1, variant2, variant3, formatted, raw)
                return formatted, raw
            end
        end
    end

    BuildFallbackMaps()

    cached = formattedCache[spellID]
    if cached ~= nil then
        return cached or nil, rawCache[spellID] or nil
    end

    for _, variantID in ipairs(variants) do
        local name = SpellName(variantID)
        if name then
            local entry = macroByName[name:lower()]
            if entry then
                CacheForVariants(variant1, variant2, variant3, entry[1], entry[2])
                return entry[1], entry[2]
            end
        end
    end

    formattedCache[spellID] = false
    rawCache[spellID] = false
    return nil, nil
end

local function LookupItem(itemID)
    if not itemID or itemID == 0 then return nil, nil end

    local cached = formattedCache[itemID]
    if cached ~= nil then
        return cached or nil, rawCache[itemID] or nil
    end

    local _, itemSpellID = GetItemSpell(itemID)
    if itemSpellID then
        local formatted, raw = LookupSpell(itemSpellID)
        if formatted then
            formattedCache[itemID] = formatted
            rawCache[itemID] = raw
            return formatted, raw
        end
    end

    BuildFallbackMaps()

    cached = formattedCache[itemID]
    if cached ~= nil then
        return cached or nil, rawCache[itemID] or nil
    end

    local slots = itemSlotMap[itemID]
    if slots then
        local formatted, raw = ShortestFromSlots(slots)
        if formatted then
            formattedCache[itemID] = formatted
            rawCache[itemID] = raw
            return formatted, raw
        end
    end

    formattedCache[itemID] = false
    rawCache[itemID] = false
    return nil, nil
end

local function ResolveIconIDs(icon)
    if not icon then return nil, nil, nil, nil end
    local frameData = FrameData[icon]
    local itemID = frameData and frameData.isItemByPrefix and (frameData.itemID or frameData.customSpellID) or nil
    local customID = frameData and frameData.customSpellID or nil
    local cooldownInfo = icon.cooldownInfo
    local overrideID = cooldownInfo and BUI.Tools.SafeNum(cooldownInfo.overrideSpellID) or nil
    local spellID = cooldownInfo and BUI.Tools.SafeNum(cooldownInfo.spellID) or nil

    if not spellID and not overrideID and frameData and frameData.storedValue and not itemID then
        spellID = BUI.Tools.SafeNum(frameData.storedValue)
    end
    return itemID, customID, overrideID, spellID
end

local function LookupForIcon(icon)
    local itemID, customID, overrideID, spellID = ResolveIconIDs(icon)
    if itemID then return LookupItem(itemID) end
    if customID then return LookupSpell(customID) end
    if overrideID then
        local formatted, raw = LookupSpell(overrideID)
        if formatted then return formatted, raw end
    end
    if spellID then return LookupSpell(spellID) end
    return nil, nil
end

local function FindKeybindForIcon(icon)
    local formatted = LookupForIcon(icon)
    return formatted
end

local function GetKeybindFont(config)
    local fontName = config and config.keybindFont
    if not fontName or fontName == "GLOBAL" then
        return BUI.GetGlobalFont()
    end
    local path = LibStub("LibSharedMedia-3.0"):Fetch("font", fontName)
    if path then return path end
    return BUI.GetGlobalFont()
end

local function ApplyShadow(fontString)
    fontString:SetShadowOffset(0, 0)
end

local function GetOrCreateKeybindText(icon, config, db)
    local frameData = CDM.GetFrameData(icon)
    if frameData.keybindText then return frameData.keybindText end

    if not frameData.textOverlay then
        local overlay = CreateFrame("Frame", nil, icon)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(icon:GetFrameLevel() + 20)
        frameData.textOverlay = overlay
    end

    local fontString = frameData.textOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    fontString:SetDrawLayer("OVERLAY", 7)
    frameData.keybindText = fontString

    local color = config.keybindColor
    fontString:SetTextColor(color[1], color[2], color[3], color[4])
    Pixel.ApplyFont(fontString, config.keybindFontSize, GetKeybindFont(config), BUI.GetFontOutline())
    fontString:SetPoint(config.keybindAnchor, icon, config.keybindAnchor, Pixel.Scale(config.keybindOffsetX or -2), Pixel.Scale(config.keybindOffsetY or -2))
    ApplyShadow(fontString)

    return fontString
end

local function ApplyViewer(viewerKey)
    local config = CDM.GetSettings(viewerKey)
    local db = BUI.GetDB()
    local list, count = CDM.GetTrackedIcons(viewerKey)

    for iconIndex = 1, count do
        local icon = list[iconIndex]
        local frameData = CDM.GetFrameData(icon)

        if not config or not config.showKeybinds then
            if frameData.keybindText then frameData.keybindText:Hide() end
            frameData.keybind = nil
        else
            local keybind = FindKeybindForIcon(icon)
            frameData.keybind = keybind

            if keybind then
                local fontString = GetOrCreateKeybindText(icon, config, db)
                fontString:SetText(keybind)
                fontString:Show()
            elseif frameData.keybindText then
                frameData.keybindText:Hide()
            end
        end
    end
end

local function ApplyAllViewers()
    for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
        ApplyViewer(CDM.VIEWER_KEYS[viewerIndex])
    end
end

local Keybinds = {}
CDM.Keybinds = Keybinds
Keybinds.BindingForSlot = BindingForSlot

local active = false
local dirty = false
local needsRetry = false
local pendingFull = false
local pendingBindings = false

local function AnyViewerShowsKeybinds()
    for viewerIndex = 1, CDM.VIEWER_KEYS_COUNT do
        local config = CDM.GetSettings(CDM.VIEWER_KEYS[viewerIndex])
        if config and config.showKeybinds then return true end
    end
    return false
end

local function PressHighlightEnabled()
    return BUI.GetDB().cdm.pressHighlight.enabled or false
end

local function AnyConsumerActive()
    return AnyViewerShowsKeybinds() or PressHighlightEnabled()
end

local function DoRefresh(full, bindingsStale)
    if full then
        InvalidateAll()
    elseif bindingsStale then
        InvalidateBindings()
    end
    if AnyViewerShowsKeybinds() then
        ApplyAllViewers()
    end
    appliedGeneration = generation
end

function Keybinds.GetRawBindingForIcon(icon)
    local _, raw = LookupForIcon(icon)
    return raw
end

function Keybinds.GetGeneration()
    return generation
end

function Keybinds.Apply()
    if not active then return end
    if generation == appliedGeneration then return end
    appliedGeneration = generation
    if AnyViewerShowsKeybinds() then
        ApplyAllViewers()
    end
end

function Keybinds.Refresh()
    DoRefresh(true)
end

function Keybinds.RefreshViewer(viewerKey)
    ApplyViewer(viewerKey)
    Keybinds.UpdateConsumerState()
end

function Keybinds.StyleViewer(viewerKey)
    local config = CDM.GetSettings(viewerKey)
    if not config then return end

    local db = BUI.GetDB()
    local list, count = CDM.GetTrackedIcons(viewerKey)

    for iconIndex = 1, count do
        local icon = list[iconIndex]
        local frameData = FrameData[icon]
        local fontString = frameData and frameData.keybindText
        if fontString then
            fontString:ClearAllPoints()
            fontString:SetPoint(config.keybindAnchor, icon, config.keybindAnchor, Pixel.Scale(config.keybindOffsetX or -2), Pixel.Scale(config.keybindOffsetY or -2))
            local color = config.keybindColor
            fontString:SetTextColor(color[1], color[2], color[3], color[4])
            Pixel.ApplyFont(fontString, config.keybindFontSize, GetKeybindFont(config), BUI.GetFontOutline())
            ApplyShadow(fontString)
        end
    end
end

local eventFrame = CreateFrame("Frame", "BUI_CDMKeybindFlush")
eventFrame:Hide()

eventFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    dirty = false
    local full = pendingFull
    local bindingsStale = pendingBindings
    pendingFull = false
    pendingBindings = false
    DoRefresh(full, bindingsStale)

    if needsRetry then
        needsRetry = false

        C_Timer.After(0.1, function()
            DoRefresh(true)
        end)
    end
end)

function Keybinds.ScheduleRebuild()
    if not active then return end
    if dirty then return end
    dirty = true
    eventFrame:Show()
end

local hooksInstalled = false

local function EnsureHooks()
    if hooksInstalled then return end
    local hookedViewer = false
    for key, viewerName in pairs(CDM.VIEWERS) do
        local viewer = key ~= 'buffs' and _G[viewerName]
        if viewer and viewer.RefreshLayout then
            hooksecurefunc(viewer, "RefreshLayout", Keybinds.ScheduleRebuild)
            hookedViewer = true
        end
    end

    if not hookedViewer then return end
    hooksecurefunc(CDM, "NotifyDependents", Keybinds.Apply)
    hooksInstalled = true
end

local RETRY_EVENTS = {
    UPDATE_OVERRIDE_ACTIONBAR = true,
    UPDATE_VEHICLE_ACTIONBAR  = true,
}

local seenBonusPages = {}

local function BonusPageIsNew()
    if not C_ActionBar.HasBonusActionBar() then return false end
    local page = C_ActionBar.GetBonusBarIndex()
    if type(page) ~= "number" or seenBonusPages[page] then return false end
    seenBonusPages[page] = true
    return true
end

local function OnMappingEvent(event)
    if event == "UPDATE_BINDINGS" then
        pendingBindings = true
    elseif event == "UPDATE_BONUS_ACTIONBAR" then
        if not BonusPageIsNew() then return end
        pendingFull = true
    else
        pendingFull = true
    end
    if RETRY_EVENTS[event] then
        needsRetry = true
    end
    Keybinds.ScheduleRebuild()
end

local MAPPING_EVENTS = {
    "ACTIONBAR_SLOT_CHANGED",
    "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR",
    "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_BINDINGS",
    "EDIT_MODE_LAYOUTS_UPDATED",
}

local eventsRegistered = false

local function RegisterMappingEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    for eventIndex = 1, #MAPPING_EVENTS do
        BUI.Events:Register(MAPPING_EVENTS[eventIndex], "CDM.Keybinds." .. MAPPING_EVENTS[eventIndex], OnMappingEvent)
    end
end

local function UnregisterMappingEvents()
    if not eventsRegistered then return end
    eventsRegistered = false
    for eventIndex = 1, #MAPPING_EVENTS do
        BUI.Events:Unregister(MAPPING_EVENTS[eventIndex], "CDM.Keybinds." .. MAPPING_EVENTS[eventIndex])
    end
end

function Keybinds.UpdateConsumerState()
    local nowActive = AnyConsumerActive()
    if nowActive == active then return end
    active = nowActive
    if active then
        EnsureHooks()
        RegisterMappingEvents()
        pendingFull = true
        Keybinds.ScheduleRebuild()
    else
        UnregisterMappingEvents()
    end
end

BUI.Events:Register("PLAYER_ENTERING_WORLD", "CDM.Keybinds.EnterWorld", function()
    EnsureHooks()
    Keybinds.UpdateConsumerState()
    if active then
        pendingFull = true
        needsRetry = true
        Keybinds.ScheduleRebuild()
    end
end)
