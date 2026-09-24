local _, BUI = ...

local abs = math.abs
local _G = _G
local pairs = pairs
local wipe = wipe

local InCombatLockdown = InCombatLockdown

local CDM = BUI.CDM
local Pixel = BUI.Pixel
local BLANK = BUI.C.FALLBACK_TEXTURE
local FrameData = CDM.FrameData
local GetFrameData = CDM.GetFrameData

local CDMCooldowns = setmetatable({}, { __mode = "k" })

CDM.CDMCooldowns = CDMCooldowns

local reconcileBuf = {}

local function ReconcileKey(key)
    local db = BUI.GetDB()
    local settings = db.cdm[key]
    if not settings or not settings.enabled then return end
    local viewerName = CDM.VIEWERS[key]
    local viewer = viewerName and _G[viewerName]
    if not viewer or not viewer.itemFramePool or not viewer.itemFramePool.EnumerateActive then return end
    for frame in viewer.itemFramePool:EnumerateActive() do
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

local function OnRefreshLayoutComplete(viewer)
    local key = CDM.GetViewerKey(viewer)
    if not key then return end

    local pool = viewer.itemFramePool
    local activeCount = pool and pool.GetNumActive and pool:GetNumActive() or -1
    if activeCount ~= lastPoolActive[key] then
        lastPoolActive[key] = activeCount
        ReconcileKey(key)
    end

    local churn = CDM.GetIconChurn(key)
    if churn ~= lastChurn[key] or not CDM.HasUserOrder(key) then
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

    hooksecurefunc(icon, "SetPoint", OnIconSetPoint)
    hooksecurefunc(icon, "SetScale", OnIconSetScale)
    hooksecurefunc(icon, "SetAlpha", OnIconSetAlpha)
    hooksecurefunc(icon, "SetSize", OnIconSetSize)
    hooksecurefunc(icon, "SetWidth", OnIconSetSize)
    hooksecurefunc(icon, "SetHeight", OnIconSetSize)
    if icon.SetCooldownID then
        local cooldownID = icon.cooldownID
        if not issecretvalue(cooldownID) then
            frameData.lastCooldownID = cooldownID
        end
        hooksecurefunc(icon, "SetCooldownID", OnIconSetCooldownID)
    end
    if icon.OnActiveStateChanged then
        hooksecurefunc(icon, "OnActiveStateChanged", OnIconActiveStateChanged)
    end
    if key == 'buffs' then
        hooksecurefunc(icon, "Show", CDM._OnBuffIconShow)
        hooksecurefunc(icon, "Hide", CDM._OnBuffIconHide)
        hooksecurefunc(icon, "SetShown", CDM._OnBuffIconShow)
    end
end

local function OnViewerVisibilityChanged(viewer)
    local viewerFrameData = FrameData[viewer]
    local key = viewerFrameData and viewerFrameData.viewerKey
    if key then
        CDM.MarkDirty(key)
    else
        CDM.MarkAllDirty()
    end
end

local function SkinAndPark(frame, key)
    local settings = CDM.GetSettings(key)
    local anchor = CDM.Anchors[key]
    if not settings or not anchor then return end

    CDM.HookIconFrame(frame, key)
    local parkData = GetFrameData(frame)
    parkData.parked = true
    CDM.SkinIcon(frame, settings, key)
    parkData.selfPoint = "TOPLEFT"
    parkData.relPoint = "TOPLEFT"
    parkData.posCornerX = 0
    parkData.posCornerY = 0

    parkData.posX = nil
    parkData.posY = nil
    parkData.locking = true
    frame:SetScale(1)
    frame:SetAlpha(0)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    local width = anchor._cachedScaledW or settings._pxW or Pixel.Scale(settings.iconWidth)
    local height = anchor._cachedScaledH or settings._pxH or Pixel.Scale(settings.iconHeight)
    parkData.sizeW = width
    parkData.sizeH = height
    frame:SetSize(width, height)
    parkData.locking = false
end

local function OnViewerAcquireFrame(viewer, frame)
    local viewerFrameData = FrameData[viewer]
    local key = viewerFrameData and viewerFrameData.viewerKey
    local isValid = key == "buffs" and frame.Icon or CDM.IsCooldownIcon(frame)
    if not isValid then return end

    if key then
        local frameData = FrameData[frame]
        if frameData then
            frameData.countFont = nil
            frameData.countFontNil = nil
        end

        CDM.TrackIcon(key, frame)

        local db = BUI.GetDB()
        local settings = db.cdm[key]
        if settings and settings.enabled then
            SkinAndPark(frame, key)
        end
    end
end

local function OnViewerReleaseFrame(viewer, frame)
    local key = CDM.GetViewerKey(viewer)
    if key then
        CDM.UntrackIcon(key, frame)
    end
end

local function OnPoolRelease(pool, frame)
    local poolFrameData = FrameData[pool]
    local viewer = poolFrameData and poolFrameData.viewer
    if viewer then OnViewerReleaseFrame(viewer, frame) end
end

function CDM.HookViewer(viewer, key)
    local viewerFrameData = GetFrameData(viewer)

    if not viewerFrameData.hooked then
        viewerFrameData.hooked = true
        viewerFrameData.viewerKey = key

        hooksecurefunc(viewer, "Show", OnViewerVisibilityChanged)
        hooksecurefunc(viewer, "Hide", OnViewerVisibilityChanged)
        hooksecurefunc(viewer, "SetShown", OnViewerVisibilityChanged)

        if not viewerFrameData.poolHooked and viewer.itemFramePool then
            viewerFrameData.poolHooked = true

            hooksecurefunc(viewer, "OnAcquireItemFrame", OnViewerAcquireFrame)

            if viewer.RefreshLayout then
                hooksecurefunc(viewer, "RefreshLayout", OnRefreshLayoutComplete)
            end

            if viewer.itemFramePool.Release then
                GetFrameData(viewer.itemFramePool).viewer = viewer
                hooksecurefunc(viewer.itemFramePool, "Release", OnPoolRelease)
            end

            if viewer.itemFramePool.EnumerateActive then
                local db = BUI.GetDB()
                local settings = db.cdm[key]
                local enabled = settings and settings.enabled

                for frame in viewer.itemFramePool:EnumerateActive() do
                    local isValid = key == "buffs" and frame.Icon or CDM.IsCooldownIcon(frame)
                    if isValid then
                        CDM.TrackIcon(key, frame)
                        if enabled then SkinAndPark(frame, key) end
                    end
                end
            end
        end
    end

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
            frameData.posX = nil
            frameData.posY = nil
            frameData.parked = nil
            frameData.locking = true
            icon:SetAlpha(1)
            frameData.locking = false
        end
    end

    CDM.UnskinViewer(key)
    BUI.Print('Cooldown viewer restored. /reload to let Blizzard lay it out again.')
end

function CDM.RestyleCooldown(cooldown)
    if issecretvalue(cooldown) then return end
    if not CDMCooldowns[cooldown] then return end

    local cooldownFrameData = FrameData[cooldown]
    if not cooldownFrameData or not cooldownFrameData.cdSetup then return end

    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end

    local parent = cooldown:GetParent()
    local parentFrameData = parent and FrameData[parent]
    local viewerKey = parentFrameData and parentFrameData.viewerKey
    local settings = viewerKey and CDM.GetSettings(viewerKey)

    local scaledEdge = (parentFrameData and parentFrameData.skinVer and settings and settings.borderSize and settings.borderSize > 0)
        and (Pixel.Scale(settings.borderSize) - Pixel.PixelSize(1)) or 0
    if parent and (cooldownFrameData.anchoredParent ~= parent or cooldownFrameData.anchoredEdge ~= scaledEdge) then
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

    local reverse = settings and settings.reverseSwipe or false
    local showEdge = settings and settings.showEdge or false
    local swipeRed, swipeGreen, swipeBlue, swipeAlpha = CDM.ResolveSwipeColor(settings)
    cooldownFrameData.reverseSwipe = reverse
    cooldownFrameData.showEdge = showEdge
    cooldownFrameData.swR, cooldownFrameData.swG, cooldownFrameData.swB, cooldownFrameData.swA = swipeRed, swipeGreen, swipeBlue, swipeAlpha
    cooldown:SetUseCircularEdge(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetSwipeTexture(BLANK)
    cooldown:SetReverse(reverse)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawEdge(showEdge)
    cooldown:SetSwipeColor(swipeRed, swipeGreen, swipeBlue, swipeAlpha)
end
