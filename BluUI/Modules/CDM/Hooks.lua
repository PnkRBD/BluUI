local _, BUI = ...

local Hook = BUI.Profiler.Hooker('CDM.Hooks')

local abs = math.abs
local _G = _G
local wipe = wipe


local CDM = BUI.CDM
local Pixel = BUI.Pixel
local FrameData = CDM.FrameData
local GetFrameData = CDM.GetFrameData

local CDMCooldowns = setmetatable({}, { __mode = "k" })

CDM.CDMCooldowns = CDMCooldowns

local reconcileBuf = {}

local function ReconcileKey(key)
    local db = BUI.GetDB()
    local settings = db.cdm[key]
    if not settings.enabled then return end
    for frame in _G[CDM.VIEWERS[key]].itemFramePool:EnumerateActive() do
        reconcileBuf[frame] = true
    end
    local list, count = CDM.GetTrackedIcons(key)
    for iconIndex = count, 1, -1 do
        local icon = list[iconIndex]
        local frameData = FrameData[icon]
        if not (frameData and frameData.customIcon) and not reconcileBuf[icon] then
            CDM.UntrackIcon(key, icon)
        end
    end
    wipe(reconcileBuf)
end

local lastPoolActive = {}
local lastChurn = {}

local function ActiveIconsMoved(pool)
    local moved = false
    for frame in pool:EnumerateActive() do
        local frameData = GetFrameData(frame)
        local layoutIndex = frame.layoutIndex
        local cooldownID = frame.cooldownID
        local included = (frame:IsShown() or frame.cooldownInfo) and true or false
        if issecretvalue(cooldownID) then
            moved = true
        elseif frameData.seenLayoutIndex ~= layoutIndex or frameData.seenCooldownID ~= cooldownID or frameData.seenIncluded ~= included then
            frameData.seenLayoutIndex = layoutIndex
            frameData.seenCooldownID = cooldownID
            frameData.seenIncluded = included
            moved = true
        end
    end
    return moved
end

local function OnRefreshLayoutComplete(viewer)
    local key = CDM.GetViewerKey(viewer)
    if not key then return end

    local pool = viewer.itemFramePool
    local activeCount = pool:GetNumActive()
    if activeCount ~= lastPoolActive[key] then
        lastPoolActive[key] = activeCount
        ReconcileKey(key)
    end

    local iconsMoved = key ~= 'buffs' and ActiveIconsMoved(pool)
    local churn = CDM.GetIconChurn(key)
    if churn ~= lastChurn[key] or iconsMoved then
        lastChurn[key] = churn
        CDM.MarkDirty(key)
    else
        CDM.MarkLayoutDirty(key)
    end
end

local rawProxy = CreateFrame("Frame")
local RawSetPoint = rawProxy.SetPoint
local RawClearAllPoints = rawProxy.ClearAllPoints
local RawSetScale = rawProxy.SetScale
local RawSetAlpha = rawProxy.SetAlpha
local RawSetSize = rawProxy.SetSize

local function ReapplyIconPoint(self, frameData)
    RawClearAllPoints(self)
    RawSetPoint(self, frameData.selfPoint or "TOPLEFT", frameData.anchor, frameData.relPoint or frameData.selfPoint or "TOPLEFT", frameData.posCornerX or 0, frameData.posCornerY or 0)
end

local function OnIconSetPoint(self)
    local frameData = FrameData[self]
    if not frameData or frameData.locking then return end
    if not frameData.anchor then
        if frameData.viewerKey == 'buffs' then
            CDM.MarkBuffCenterDirty()
        end
        return
    end
    ReapplyIconPoint(self, frameData)
end

local function OnIconSetScale(self, scale)
    local frameData = FrameData[self]
    if not frameData or frameData.locking then return end
    if abs(scale - 1) > 0.01 then
        RawSetScale(self, 1)
    end
end

local function OnIconSetAlpha(self, alpha)
    local frameData = FrameData[self]
    if not frameData or frameData.locking then return end
    if (frameData.parked or frameData.hidden) and alpha > 0 then
        RawSetAlpha(self, 0)
    end
end

local function OnIconSetSize(self)
    local frameData = FrameData[self]
    if not frameData or frameData.locking then return end
    local wantedWidth, wantedHeight = frameData.sizeW, frameData.sizeH
    if not wantedWidth or not wantedHeight then return end
    local width, height = self:GetSize()
    if issecretvalue(width) or issecretvalue(height) then return end
    if not width or not height or abs(width - wantedWidth) > 0.5 or abs(height - wantedHeight) > 0.5 then
        RawSetSize(self, wantedWidth, wantedHeight)
    end
end

local function OnIconActiveStateChanged(self)
    local frameData = FrameData[self]
    if not frameData or frameData.viewerKey ~= 'buffs' then return end
    CDM.CenterBuffsNow()
end

local function OnIconSetCooldownID(self, cooldownID)
    if issecretvalue(cooldownID) then return end
    local frameData = FrameData[self]
    if not frameData then return end
    if frameData.lastCooldownID == cooldownID then return end
    frameData.lastCooldownID = cooldownID
    local key = frameData.tracked or frameData.viewerKey
    if key then CDM.MarkDirty(key) end
    CDM.PressHighlight.Invalidate()
end

function CDM.HookIconFrame(icon, key)
    local frameData = GetFrameData(icon)
    if frameData.posHooked then return end
    frameData.posHooked = true
    frameData.viewerKey = key
    if key ~= 'buffs' and icon.Cooldown and not frameData.customIcon then
        icon.Cooldown:HookScript('OnCooldownDone', CDM.OnCooldownWidgetDone)
    end

    Hook(icon, "SetPoint", OnIconSetPoint)
    Hook(icon, "SetScale", OnIconSetScale)
    Hook(icon, "SetAlpha", OnIconSetAlpha)
    Hook(icon, "SetSize", OnIconSetSize)
    Hook(icon, "SetWidth", OnIconSetSize)
    Hook(icon, "SetHeight", OnIconSetSize)
    if icon.SetCooldownID then
        local cooldownID = icon.cooldownID
        if not issecretvalue(cooldownID) then
            frameData.lastCooldownID = cooldownID
        end
        Hook(icon, "SetCooldownID", OnIconSetCooldownID)
    end
    if icon.OnActiveStateChanged then
        Hook(icon, "OnActiveStateChanged", OnIconActiveStateChanged)
    end
    if key == 'buffs' then
        Hook(icon, "Show", CDM.MarkBuffCenterDirty)
        Hook(icon, "Hide", CDM.MarkBuffCenterDirty)
        Hook(icon, "SetShown", CDM.MarkBuffCenterDirty)
    end
end

local function OnViewerVisibilityChanged(viewer)
    local viewerFrameData = FrameData[viewer]
    local shown = viewer:IsShown()
    if viewerFrameData.seenShown == shown then return end
    viewerFrameData.seenShown = shown
    CDM.MarkDirty(viewerFrameData.viewerKey)
end

local function SkinAndPark(frame, key)
    local settings = CDM.GetSettings(key)
    local anchor = CDM.Anchors[key]

    CDM.HookIconFrame(frame, key)
    local parkData = GetFrameData(frame)
    if key ~= 'buffs' and parkData.anchor == anchor and not parkData.parked and not parkData.hidden
        and parkData.skinVer == CDM.state.skinVersion then
        ReapplyIconPoint(frame, parkData)
        return
    end
    parkData.parked = true
    CDM.SkinIcon(frame, settings, key)
    parkData.selfPoint = "TOPLEFT"
    parkData.relPoint = "TOPLEFT"
    parkData.posCornerX = 0
    parkData.posCornerY = 0
    parkData.locking = true
    frame:SetScale(1)
    frame:SetAlpha(0)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    local width = anchor._cachedScaledW
    local height = anchor._cachedScaledH
    parkData.sizeW = width
    parkData.sizeH = height
    frame:SetSize(width, height)
    parkData.locking = false
end

local function OnViewerAcquireFrame(viewer, frame)
    local key = FrameData[viewer].viewerKey
    local isValid = key == "buffs" and frame.Icon or CDM.IsCooldownIcon(frame)
    if not isValid then return end

    local frameData = FrameData[frame]
    if frameData then
        frameData.countFont = nil
        frameData.countFontNil = nil
    end

    CDM.TrackIcon(key, frame)

    if BUI.GetDB().cdm[key].enabled then
        SkinAndPark(frame, key)
    end
end

function CDM.HookViewer(viewer, key)
    local viewerFrameData = GetFrameData(viewer)

    if not viewerFrameData.hooked then
        viewerFrameData.hooked = true
        viewerFrameData.viewerKey = key

        Hook(viewer, "Show", OnViewerVisibilityChanged)
        Hook(viewer, "Hide", OnViewerVisibilityChanged)
        Hook(viewer, "SetShown", OnViewerVisibilityChanged)

        local pool = viewer.itemFramePool
        local HookViewer = BUI.Profiler.Hooker("CDM." .. key)
        HookViewer(viewer, "OnAcquireItemFrame", OnViewerAcquireFrame)
        HookViewer(viewer, "RefreshLayout", OnRefreshLayoutComplete)

        local enabled = BUI.GetDB().cdm[key].enabled
        for frame in pool:EnumerateActive() do
            local isValid = key == "buffs" and frame.Icon or CDM.IsCooldownIcon(frame)
            if isValid then
                CDM.TrackIcon(key, frame)
                if enabled then SkinAndPark(frame, key) end
            end
        end
    end

    viewerFrameData.seenShown = viewer:IsShown()
    CDM.MarkDirty(key)
end

function CDM.RestoreViewer(viewer, key)
    local viewerFrameData = FrameData[viewer]

    if not viewerFrameData or not viewerFrameData.hooked then return end

    local list, count = CDM.GetTrackedIcons(key)
    for iconIndex = 1, count do
        local icon = list[iconIndex]
        local frameData = FrameData[icon]
        if frameData then
            frameData.anchor = nil
            frameData.parked = nil
            frameData.locking = true
            icon:SetAlpha(1)
            frameData.locking = false
        end
    end

    CDM.UnskinViewer(key)
end

local barAcquireListeners, barLayoutListeners = {}, {}
local barViewerHooked = false

local function OnBarViewerAcquire(viewer, item)
    for listenerIndex = 1, #barAcquireListeners do barAcquireListeners[listenerIndex](viewer, item) end
end

local function OnBarViewerLayout(viewer)
    for listenerIndex = 1, #barLayoutListeners do barLayoutListeners[listenerIndex](viewer) end
end

function CDM.HookBarViewer(onAcquire, onLayout)
    local viewer = _G.BuffBarCooldownViewer
    if not viewer then return false end
    barAcquireListeners[#barAcquireListeners + 1] = onAcquire
    barLayoutListeners[#barLayoutListeners + 1] = onLayout
    if not barViewerHooked then
        barViewerHooked = true
        local HookBars = BUI.Profiler.Hooker("CDM.bars")
        HookBars(viewer, "OnAcquireItemFrame", OnBarViewerAcquire)
        HookBars(viewer, "RefreshLayout", OnBarViewerLayout)
    end
    return true
end

local function ApplyCooldownStyle(cooldown, cooldownFrameData)
    local parent = cooldown:GetParent()
    local parentFrameData = FrameData[parent]
    local settings = CDM.GetSettings(parentFrameData.viewerKey)

    local scaledEdge = (parentFrameData.skinVer and settings.borderSize > 0)
        and (Pixel.Scale(settings.borderSize) - Pixel.PixelSize(1)) or 0
    if cooldownFrameData.anchoredParent ~= parent or cooldownFrameData.anchoredEdge ~= scaledEdge then
        cooldownFrameData.anchoredParent = parent
        cooldownFrameData.anchoredEdge = scaledEdge
        cooldown:ClearAllPoints()
        if scaledEdge > 0 then
            cooldown:SetPoint("TOPLEFT", parent, "TOPLEFT", scaledEdge, -scaledEdge)
            cooldown:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -scaledEdge, scaledEdge)
        else
            cooldown:SetAllPoints(parent)
        end
    end

    CDM.ApplyCooldownSwipeStyle(cooldown, settings)
    cooldownFrameData.styleVer = CDM.state.skinVersion
end

function CDM.RestyleCooldown(cooldown)
    if issecretvalue(cooldown) then return end
    if not CDMCooldowns[cooldown] then return end

    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup then return end

    if EditModeManagerFrame:IsShown() then return end

    if cooldownFrameData.styleVer ~= CDM.state.skinVersion then
        ApplyCooldownStyle(cooldown, cooldownFrameData)
    end
    cooldown:SetDrawSwipe(true)
end
