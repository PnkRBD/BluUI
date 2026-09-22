local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('BuffTracking.PackLeader')

local PackLeader = {}
BUI.BuffTracking.PackLeader = PackLeader

local Pixel = BUI.Pixel

local SETTINGS_KEY   = 'packLeader'
local FRAME_NAME     = 'BUI_PackLeader'
local FALLBACK_ICON  = 134400
local HOWL_COLOR     = { 0.95, 0.78, 0.35 }
local DIM_ALPHA      = 0.35
local GLOW_THICKNESS = 2
local GLOW_TEXTURE   = 'Interface\\Buttons\\WHITE8X8'

local function GetConfig()
    return BUI.GetDB()[SETTINGS_KEY]
end

local function SpellTexture(spellID)
    return C_Spell.GetSpellTexture(spellID) or FALLBACK_ICON
end

function PackLeader.Create()
    local Display = BUI.BuffTracking.Display
    local Hunter  = BUI.BuffTracking.Hunter

    local tracker = { settingsKey = SETTINGS_KEY, frame = nil }

    local root, mainPip, nextPip
    local lastPhase, lastBeastId
    local swipeDriver
    local swipeSize, swipeStamp = 10, ''

    local function StyleSwipe(cooldown)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetSwipeColor(0, 0, 0, 0.6)
        cooldown:SetHideCountdownNumbers(not GetConfig().showCountdownText)
    end

    local function SyncLiveSwipe(config)
        local Engine = BUI.AuraEngine
        if not swipeDriver then swipeDriver = Engine.NewAuraCooldownDriver(mainPip) end
        Engine.SyncAuraCooldownDriver(swipeDriver, config.enabled, Hunter.PackLeaderSpellSet, swipeStamp, swipeSize, swipeSize, StyleSwipe)
    end

    local function CreatePip(parent, size, showCountdown)
        local pip = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
        pip:SetSize(size, size)
        Pixel.ApplyBorder(pip, 1, 0, 0, 0, 1)
        Pixel.ShowBorder(pip)

        pip.bg = pip:CreateTexture(nil, 'BACKGROUND')
        pip.bg:SetAllPoints()
        BUI.Tools.SetColorTex(pip.bg, 0, 0, 0, 1)

        local edge = Pixel.PixelSize(1)
        pip.tex = pip:CreateTexture(nil, 'ARTWORK')
        pip.tex:SetPoint('TOPLEFT',     edge, -edge)
        pip.tex:SetPoint('BOTTOMRIGHT', -edge, edge)
        pip.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        pip.swipe = CreateFrame('Cooldown', nil, pip, 'CooldownFrameTemplate')
        pip.swipe:SetAllPoints(pip)
        pip.swipe:SetDrawEdge(false)
        pip.swipe:SetDrawBling(false)
        pip.swipe:SetSwipeColor(0, 0, 0, 0.6)
        pip.swipe:SetHideCountdownNumbers(not showCountdown)

        return pip
    end

    local function PaintPip(pip, beast, mode)
        pip.tex:SetTexture(SpellTexture(beast.spell))
        pip.tex:SetDesaturated(false)

        local red, green, blue = Hunter.BeastColor(beast.id)
        if mode == 'active' then
            pip.tex:SetAlpha(1)
            Pixel.ApplyBorder(pip, 1, red, green, blue, 1)
        elseif mode == 'preview' then
            pip.tex:SetAlpha(0.85)
            Pixel.ApplyBorder(pip, 1, red * 0.7, green * 0.7, blue * 0.7, 0.85)
        else
            pip.tex:SetAlpha(DIM_ALPHA)
            pip.tex:SetDesaturated(true)
            Pixel.ApplyBorder(pip, 1, 0, 0, 0, 1)
        end
        Pixel.ShowBorder(pip)
    end

    local function PaintHowlPip(pip)
        pip.tex:SetTexture(SpellTexture(Hunter.PackLeaderCountdownSpell))
        pip.tex:SetAlpha(1)
        pip.tex:SetDesaturated(false)
        Pixel.ApplyBorder(pip, 1, HOWL_COLOR[1], HOWL_COLOR[2], HOWL_COLOR[3], 1)
        Pixel.ShowBorder(pip)
    end

    local function EnsureFlash(pip)
        if pip.flash then return end
        pip.flash = pip:CreateTexture(nil, 'OVERLAY', nil, 7)
        pip.flash:SetTexture(GLOW_TEXTURE)
        pip.flash:SetBlendMode('ADD')
        pip.flash:SetAllPoints()
        pip.flash:SetVertexColor(1, 1, 1)
        pip.flash:SetAlpha(0)

        pip.flashAnimation = pip.flash:CreateAnimationGroup()
        local fade = pip.flashAnimation:CreateAnimation('Alpha')
        fade:SetFromAlpha(0.65)
        fade:SetToAlpha(0)
        fade:SetDuration(0.45)
        fade:SetSmoothing('OUT')
        SetScript(pip.flashAnimation, 'OnFinished', function() pip.flash:SetAlpha(0) end)
    end

    local function PlayFlash(pip, red, green, blue)
        if not GetConfig().animateTransitions then return end
        EnsureFlash(pip)
        pip.flash:SetVertexColor(red * 1.3, green * 1.3, blue * 1.3)
        pip.flashAnimation:Stop()
        pip.flash:SetAlpha(0.65)
        pip.flashAnimation:Play()
    end

    local function EnsureGlow(pip)
        if pip.glowHost then return end
        local host = CreateFrame('Frame', nil, pip)
        host:SetAllPoints()
        pip.glowHost = host

        local glowTextures = {}
        for edgeIndex = 1, 4 do
            local glowTexture = host:CreateTexture(nil, 'OVERLAY')
            glowTexture:SetTexture(GLOW_TEXTURE)
            glowTexture:SetBlendMode('ADD')
            glowTextures[edgeIndex] = glowTexture
        end
        pip.glowTextures = glowTextures

        local animationGroup = host:CreateAnimationGroup()
        animationGroup:SetLooping('REPEAT')
        local fadeIn = animationGroup:CreateAnimation('Alpha')
        fadeIn:SetFromAlpha(0.15)
        fadeIn:SetToAlpha(1.0)
        fadeIn:SetDuration(0.4)
        fadeIn:SetSmoothing('IN_OUT')
        local fadeOut = animationGroup:CreateAnimation('Alpha')
        fadeOut:SetFromAlpha(1.0)
        fadeOut:SetToAlpha(0.15)
        fadeOut:SetDuration(0.4)
        fadeOut:SetStartDelay(0.4)
        fadeOut:SetSmoothing('IN_OUT')
        pip.glowAnimation = animationGroup
    end

    local function StartGlow(pip, red, green, blue)
        EnsureGlow(pip)
        local width, height = pip:GetSize()
        local thickness = GLOW_THICKNESS
        local glowTextures = pip.glowTextures

        for edgeIndex = 1, 4 do
            glowTextures[edgeIndex]:SetVertexColor(red, green, blue, 1)
            glowTextures[edgeIndex]:ClearAllPoints()
        end
        glowTextures[1]:SetSize(width, thickness)
        glowTextures[1]:SetPoint('TOPLEFT', pip, 'TOPLEFT', 0, 0)
        glowTextures[2]:SetSize(width, thickness)
        glowTextures[2]:SetPoint('BOTTOMLEFT', pip, 'BOTTOMLEFT', 0, 0)
        glowTextures[3]:SetSize(thickness, height - thickness * 2)
        glowTextures[3]:SetPoint('TOPLEFT', pip, 'TOPLEFT', 0, -thickness)
        glowTextures[4]:SetSize(thickness, height - thickness * 2)
        glowTextures[4]:SetPoint('TOPRIGHT', pip, 'TOPRIGHT', 0, -thickness)
        for edgeIndex = 1, 4 do glowTextures[edgeIndex]:Show() end

        pip.glowHost:Show()
        if not pip.glowAnimation:IsPlaying() then
            pip.glowAnimation:Play()
        end
    end

    local function StopGlow(pip)
        if pip.glowAnimation and pip.glowAnimation:IsPlaying() then pip.glowAnimation:Stop() end
        if pip.glowHost then pip.glowHost:Hide() end
    end

    local function BuildFrame()
        if root then return end
        local config = GetConfig()
        local mainSize, nextSize, spacing = config.iconSize, config.nextIconSize, config.spacing

        root = CreateFrame('Frame', FRAME_NAME, UIParent)
        root:SetFrameStrata('MEDIUM')
        root:SetFrameLevel(10)
        root:SetClampedToScreen(true)
        root:Hide()
        Display.MakeAnchorOverlay(root)
        tracker.frame = root

        mainPip = CreatePip(root, mainSize, config.showCountdownText)
        mainPip:SetPoint('TOPLEFT', root, 'TOPLEFT', 0, 0)

        nextPip = CreatePip(root, nextSize, false)
        nextPip:SetPoint('LEFT', mainPip, 'RIGHT', spacing, 0)

        local font = BUI.GetGlobalFont()
        local labelSize = config.labelTextSize

        mainPip.topText = mainPip:CreateFontString(nil, 'OVERLAY')
        Pixel.ApplyFont(mainPip.topText, labelSize, font, 'OUTLINE')

        mainPip.bottomText = mainPip:CreateFontString(nil, 'OVERLAY')
        Pixel.ApplyFont(mainPip.bottomText, labelSize, font, 'OUTLINE')

        root:SetSize(mainSize + spacing + nextSize, mainSize)
    end

    local function ApplyLayout()
        if not root then return end
        local config = GetConfig()
        local mainSize, nextSize, spacing = config.iconSize, config.nextIconSize, config.spacing
        local edge = Pixel.PixelSize(1)

        mainPip:SetSize(mainSize, mainSize)
        mainPip:ClearAllPoints()
        mainPip:SetPoint('TOPLEFT', root, 'TOPLEFT', 0, 0)
        mainPip.tex:ClearAllPoints()
        mainPip.tex:SetPoint('TOPLEFT',     edge, -edge)
        mainPip.tex:SetPoint('BOTTOMRIGHT', -edge, edge)
        mainPip.swipe:ClearAllPoints()
        mainPip.swipe:SetPoint('TOPLEFT',     edge, -edge)
        mainPip.swipe:SetPoint('BOTTOMRIGHT', -edge, edge)
        mainPip.swipe:SetHideCountdownNumbers(not config.showCountdownText)

        swipeSize = math.max(mainSize - 2 * edge, 10)
        swipeStamp = math.floor(swipeSize + 0.5) .. '|' .. (config.showCountdownText and 1 or 0)

        if config.showNextIcon then
            nextPip:SetSize(nextSize, nextSize)
            nextPip:ClearAllPoints()
            nextPip:SetPoint('LEFT', mainPip, 'RIGHT', spacing, 0)
            nextPip.tex:ClearAllPoints()
            nextPip.tex:SetPoint('TOPLEFT',     edge, -edge)
            nextPip.tex:SetPoint('BOTTOMRIGHT', -edge, edge)
            nextPip:Show()
            root:SetSize(mainSize + spacing + nextSize, mainSize)
        else
            nextPip:Hide()
            root:SetSize(mainSize, mainSize)
        end

        local font = BUI.GetGlobalFont()
        local labelSize = config.labelTextSize
        Pixel.ApplyFont(mainPip.topText, labelSize, font, 'OUTLINE')
        mainPip.topText:ClearAllPoints()
        mainPip.topText:SetPoint('BOTTOM', mainPip, 'TOP', Pixel.Scale(config.topTextOffsetX), Pixel.Scale(config.topTextOffsetY))
        Pixel.ApplyFont(mainPip.bottomText, labelSize, font, 'OUTLINE')
        mainPip.bottomText:ClearAllPoints()
        mainPip.bottomText:SetPoint('TOP', mainPip, 'BOTTOM', Pixel.Scale(config.bottomTextOffsetX), Pixel.Scale(config.bottomTextOffsetY))
    end

    local function Resolve()
        local phase = Hunter.GetPackLeaderPhase()
        local mainBeast
        if phase == 'ready' then
            mainBeast = Hunter.GetPackLeaderReadyBeast()
        else
            mainBeast = Hunter.GetNextBeastData()
        end
        return phase, mainBeast, Hunter.BeastById[Hunter.NextBeastId[mainBeast.id]]
    end

    local function HideAll()
        root:Hide()
        StopGlow(mainPip)
        lastPhase = nil
    end

    local function Render()
        if not root then return end
        local config = GetConfig()
        local forceShow = config.showAnchor

        if not forceShow and (not config.enabled
            or not Hunter.IsPackLeaderActive()
            or (config.showOnlyInCombat and not Display.IsInCombat())) then
            HideAll()
            return
        end

        local phase, mainBeast, nextBeast = Resolve()

        SyncLiveSwipe(config)

        if phase == 'off' and config.showOnlyInCombat and not forceShow then
            HideAll()
            return
        end

        root:Show()

        if phase == 'ticking' then
            PaintHowlPip(mainPip)
            if config.showNextIcon then PaintPip(nextPip, mainBeast, 'preview') end
        elseif phase == 'ready' then
            PaintPip(mainPip, mainBeast, 'active')
            if config.showNextIcon then PaintPip(nextPip, nextBeast, 'preview') end
        else
            PaintPip(mainPip, mainBeast, 'inactive')
            if config.showNextIcon then PaintPip(nextPip, nextBeast, 'preview') end
        end

        local red, green, blue = Hunter.BeastColor(mainBeast.id)
        mainPip.topText:SetText(mainBeast.name)
        mainPip.topText:SetTextColor(red, green, blue, 1)
        mainPip.topText:Show()

        if config.showNextText then
            mainPip.bottomText:SetText(phase == 'ready' and 'USE!' or 'Next')
            mainPip.bottomText:SetTextColor(1, 1, 1, 1)
            mainPip.bottomText:Show()
        else
            mainPip.bottomText:Hide()
        end

        mainPip.swipe:Clear()

        if phase == 'ready' and config.glowOnReady then
            StartGlow(mainPip, red, green, blue)
        else
            StopGlow(mainPip)
        end

        local beastId = mainBeast.id
        if lastPhase ~= phase or (phase ~= 'ticking' and lastBeastId ~= beastId) then
            if phase == 'ready' and lastPhase ~= nil then
                PlayFlash(mainPip, red, green, blue)
            end
            lastPhase, lastBeastId = phase, beastId
        end
    end

    function tracker.Update()
        Hunter.Update()
        if not Hunter.ConsumePackLeaderDirty() then return end
        Render()
    end

    function tracker.ApplyPosition()
        if not root then return end
        BUI.Anchor.ApplyPosition(root, GetConfig())
    end

    local function SavePosition()
        Display.SavePosition(root, GetConfig(), false)
    end

    tracker.isActive = Hunter.IsBeastMasteryOrSurvival

    function tracker.EnableDragging()  Display.EnableDragging(tracker, GetConfig, SavePosition) end
    function tracker.DisableDragging() Display.DisableDragging(tracker) end
    function tracker.MarkDirty()       Render() end

    function tracker.RecheckActive()
        BUI.Scheduler.SetUpdateEnabled(FRAME_NAME, GetConfig().enabled and tracker.isActive())
        Render()
    end

    function tracker.Refresh()
        BuildFrame()
        ApplyLayout()
        tracker.ApplyPosition()
        if GetConfig().showAnchor then
            tracker.EnableDragging()
        else
            tracker.DisableDragging()
        end
        tracker.RecheckActive()
    end

    function tracker.Initialize()
        tracker.Refresh()
        BUI.Scheduler.RegisterUpdate(FRAME_NAME, tracker.Update, 1, GetConfig().enabled and tracker.isActive())
    end

    Display.GetTrackers()[SETTINGS_KEY] = tracker
    return tracker
end
