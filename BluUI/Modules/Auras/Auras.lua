local _, BUI = ...

local Pixel = BUI.Pixel

BUI.Auras = {}
local Auras = BUI.Auras

local PetClasses = { HUNTER = true, WARLOCK = true, DEATHKNIGHT = true }

local NoPetSpecs = { [254] = true, [250] = true, [251] = true }

local _, playerClass = BUI.Tools.SafeUnitClass("player")
local cachedIsPetSpec

local function InvalidatePetSpec() cachedIsPetSpec = nil end

local function HasPetSpec()
    if cachedIsPetSpec ~= nil then return cachedIsPetSpec end
    if not playerClass or not PetClasses[playerClass] then
        cachedIsPetSpec = false
        return false
    end
    local specID = PlayerUtil.GetCurrentSpecID()
    cachedIsPetSpec = not (specID and NoPetSpecs[specID])
    return cachedIsPetSpec
end

local GRIMOIRE_OF_SACRIFICE_BUFF = 196099
local PLAY_DEAD_BUFF             = 209997

local function GrimoireOfSacrificeTalented()
    if playerClass ~= "WARLOCK" then return false end
    if BUI.Tools.ShouldAurasBeSecret() then return false end
    return C_UnitAuras.GetPlayerAuraBySpellID(GRIMOIRE_OF_SACRIFICE_BUFF) ~= nil
end

local playDeadSlot = nil
local petWasDead = false

local function CachePlayDeadSlot()
    if playerClass ~= "HUNTER" then return end
    if InCombatLockdown() then return end
    playDeadSlot = nil
    if not UnitExists("pet") then return end
    for slotIndex = 1, NUM_PET_ACTION_SLOTS do
        local _, _, _, _, _, _, _, spellID = GetPetActionInfo(slotIndex)
        if spellID == PLAY_DEAD_BUFF then
            playDeadSlot = slotIndex
            return
        end
    end
end

local function HasPlayDead()
    if playerClass ~= "HUNTER" or not playDeadSlot then return false end
    if not UnitExists("pet") then return false end
    local _, _, _, _, isActive = GetPetActionInfo(playDeadSlot)
    return isActive == true
end

local function GetDB() return BUI.GetDB().auras end

local function MakeWarningFrame(name, frameLevel)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SnapSize(350, 50)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(frameLevel)
    frame:Hide()

    frame.text = frame:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(frame.text, 28)
    frame.text:SetPoint("CENTER")

    return frame
end

local function StyleWarningFrame(frame)
    if not frame then return end
    local db = GetDB()
    BUI.Anchor.ApplyPosition(frame, db)
    Pixel.ApplyFont(frame.text, db.fontSize, BUI.GetModuleFont(db))
    local warningColor = db.warningColor
    frame.text:SetTextColor(warningColor.r, warningColor.g, warningColor.b, warningColor.a)
    frame:SnapSize(
        frame.text:GetStringWidth() + 40,
        frame.text:GetStringHeight() + 20
    )
end

local warningFrame
local previewing = false
local activeWarning
local hideHealthWarning
local CheckPet

local ATTACK_GRACE = 0.5
local petNoTargetSince = nil
local attackRecheckPending = false

local ScheduleCheck = BUI.Dispatcher.New(function()
    CheckPet()
end, 'Auras.PetCheck')

local function BuildPetWarning()
    if warningFrame then return end

    warningFrame = MakeWarningFrame("BUI_PetWarning", 100)

    BUI.Dragging.MakeAnchoredAlert(warningFrame, {
        settings = GetDB,
        isLocked = function() return GetDB().locked end,
        onRightClick = function() Auras.SetLocked(true) end,
    })
end

local function HidePetWarning()
    activeWarning = nil
    if warningFrame then warningFrame:Hide() end
end

local lastStyledFor = nil
local function Warn(message)
    if activeWarning == message and warningFrame and warningFrame:IsShown() then return end
    hideHealthWarning()
    BuildPetWarning()
    activeWarning = message
    warningFrame.text:SetText(message)
    if lastStyledFor ~= message then
        StyleWarningFrame(warningFrame)
        lastStyledFor = message
    end
    warningFrame:Show()
end

local healthFrame

local function BuildHealthWarning()
    if healthFrame then return end
    healthFrame = MakeWarningFrame(nil, 99)
    healthFrame.text:SetText("***HEAL PET***")
end

local function ApplyThresholdAlpha(frame, unit, threshold)
    local color = UnitHealthPercent(unit, false, BUI.Tools.ThresholdAlphaCurve(threshold))
    frame:SetAlpha(color and select(4, color:GetRGBA()) or 0)
end

local function UpdateHealthAlpha()
    ApplyThresholdAlpha(healthFrame, "pet", GetDB().petHealthWarning.threshold)
    healthFrame:Show()
end

hideHealthWarning = function()
    if healthFrame then healthFrame:Hide() end
end

CheckPet = function()
    if previewing then return end
    hideHealthWarning()

    local db = GetDB()
    if not db.petWarningsEnabled or not HasPetSpec() then
        HidePetWarning()
        return
    end

    if UnitIsDead("player") or UnitIsGhost("player") or IsMounted() or UnitInVehicle("player") then
        HidePetWarning()
        return
    end

    local petExists = UnitExists("pet")
    local petDead   = petExists and UnitIsDead("pet")

    if playerClass == "HUNTER" then
        if petExists then petWasDead = petDead and true or false end
        petDead = petDead or (not petExists and petWasDead)
    end

    if GrimoireOfSacrificeTalented() then
        if db.grimoireSacrificeWarning.enabled
           and petExists and not petDead then
            Warn("***SACRIFICE PET***")
        else
            HidePetWarning()
        end
        return
    end

    if HasPlayDead() then
        if db.playDeadWarning.enabled then
            Warn("***PLAYING DEAD***")
        else
            HidePetWarning()
        end
        return
    end

    if db.petDeadWarning.enabled and (not petExists or petDead) then
        Warn(petDead and (playerClass == "HUNTER" and "***REVIVE PET***" or "***DEAD PET***") or "***SUMMON PET***")
        return
    end

    if db.petHealthWarning.enabled and petExists and not petDead then
        if not healthFrame then
            BuildHealthWarning()
            StyleWarningFrame(healthFrame)
        end
        UpdateHealthAlpha()
    end

    if db.petAttackWarning.enabled
        and InCombatLockdown()
        and petExists and not petDead then
        if UnitExists("pettarget") then
            petNoTargetSince = nil
        else
            local now = GetTime()
            petNoTargetSince = petNoTargetSince or now
            local elapsed = now - petNoTargetSince
            if elapsed >= ATTACK_GRACE then
                Warn("***PET NOT ATTACKING***")
                return
            elseif not attackRecheckPending then
                attackRecheckPending = true
                C_Timer.After(ATTACK_GRACE - elapsed + 0.05, function()
                    attackRecheckPending = false
                    ScheduleCheck()
                end)
            end
        end
    else
        petNoTargetSince = nil
    end

    HidePetWarning()
end

local function OnSpecChanged()
    InvalidatePetSpec()
    CheckPet()
end

local eventsWired = false

local function WireEvents()
    if eventsWired then return end
    if not HasPetSpec() then return end
    eventsWired = true

    BUI.Events:RegisterUnit("UNIT_AURA",   "player", "Auras", ScheduleCheck)
    BUI.Events:RegisterUnit("UNIT_AURA",   "pet",    "Auras", ScheduleCheck)
    BUI.Events:RegisterUnit("UNIT_FLAGS",  "pet",    "Auras", ScheduleCheck)
    BUI.Events:RegisterUnit("UNIT_HEALTH", "pet",    "Auras", ScheduleCheck)
    BUI.Events:RegisterUnit("UNIT_TARGET", "pet",    "Auras", ScheduleCheck)
    BUI.Events:RegisterUnit("UNIT_PET",    "player", "Auras", ScheduleCheck)
    BUI.Events:RegisterUnit("UNIT_ENTERED_VEHICLE", "player", "Auras", ScheduleCheck)
    BUI.Events:RegisterUnit("UNIT_EXITED_VEHICLE",  "player", "Auras", ScheduleCheck)

    BUI.Events:Register("PLAYER_REGEN_DISABLED",         "Auras", ScheduleCheck)
    BUI.Events:Register("PLAYER_REGEN_ENABLED",          "Auras", function() CachePlayDeadSlot(); ScheduleCheck() end)
    BUI.Events:Register("PLAYER_ENTERING_WORLD",         "Auras", function() CachePlayDeadSlot(); ScheduleCheck() end)
    BUI.Events:Register("PLAYER_ALIVE",                  "Auras", ScheduleCheck)
    BUI.Events:Register("PLAYER_DEAD",                   "Auras", ScheduleCheck)
    BUI.Events:RegisterUnit("UNIT_PET",                  "player", "Auras.PlayDeadCache", function() CachePlayDeadSlot(); ScheduleCheck() end)
    BUI.Events:Register("PET_BAR_UPDATE",                "Auras", function() CachePlayDeadSlot(); ScheduleCheck() end)
    BUI.Events:Register("PLAYER_MOUNT_DISPLAY_CHANGED",  "Auras", ScheduleCheck)
    BUI.Events:Register("PLAYER_SPECIALIZATION_CHANGED", "Auras", OnSpecChanged)
    BUI.Events:Register("PLAYER_TALENT_UPDATE",          "Auras", OnSpecChanged)

    CachePlayDeadSlot()
end

local function Kill()
    previewing = false
    BUI.Events:UnregisterAll("Auras")
    eventsWired = false
    HidePetWarning()
    hideHealthWarning()
end

local function ShowAnchor()
    BuildPetWarning()
    previewing = true
    BUI.Dragging.SetLocked(warningFrame, false)
    Warn("**PET WARNING ANCHOR**")
end

local PreviewMessages = {
    petDeadWarning           = "***SUMMON PET***",
    petHealthWarning         = "***HEAL PET***",
    grimoireSacrificeWarning = "***SACRIFICE PET***",
    petAttackWarning         = "***PET NOT ATTACKING***",
    playDeadWarning          = "***PLAYING DEAD***",
}

function Auras.ShowPreview(show, warnType)
    if not GetDB().petWarningsEnabled then
        HidePetWarning()
        return
    end
    BuildPetWarning()
    previewing = show
    if show then
        Warn(PreviewMessages[warnType] or PreviewMessages.petAttackWarning)
    else
        HidePetWarning()
        CheckPet()
    end
end

function Auras.SetLocked(locked)
    GetDB().locked = locked

    if Auras._lockToggle then
        Auras._lockToggle:SetValue(not locked)
    end

    if not GetDB().petWarningsEnabled then
        HidePetWarning()
        return
    end

    BuildPetWarning()
    BUI.Dragging.SetLocked(warningFrame, locked)

    if locked then
        previewing = false
        HidePetWarning()
    else
        ShowAnchor()
    end
end

function Auras.Update()
    local db = GetDB()
    if not db.petWarningsEnabled then
        Kill()
        return
    end

    WireEvents()

    if not db.locked then
        activeWarning = nil
        lastStyledFor = nil
        ShowAnchor()
        return
    end

    if warningFrame then BUI.Dragging.SetLocked(warningFrame, true) end
    previewing = false
    StyleWarningFrame(warningFrame)
    StyleWarningFrame(healthFrame)
    CheckPet()
end

function Auras.Initialize()
    if GetDB().petWarningsEnabled then
        WireEvents()
        Auras.Update()
    end
    Auras.UpdateLowHp()
    Auras.UpdateMark()
end

local lowHpFrame, lowHpText

local lowHpSettings = BUI.Anchor.PrefixedSettings(GetDB, "lowHp")
local function LowHpSettings() return lowHpSettings end

local function BuildLowHp()
    if lowHpFrame then return end
    lowHpFrame = CreateFrame("Frame", "BUI_LowHpWarning", UIParent)
    lowHpFrame:SnapSize(350, 50)
    lowHpFrame:SetFrameStrata("HIGH")
    lowHpFrame:SetFrameLevel(99)
    lowHpFrame:Hide()
    lowHpText = lowHpFrame:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(lowHpText, 28)
    lowHpText:SetPoint("CENTER")

    BUI.Dragging.MakeAnchoredAlert(lowHpFrame, {
        settings = LowHpSettings,
        isLocked = function() return GetDB().lowHpLocked ~= false end,
        onRightClick = function()
            GetDB().lowHpLocked = true
            BUI.Dragging.SetLocked(lowHpFrame, true)
            if Auras._lowHpLockToggle then Auras._lowHpLockToggle:SetValue(false) end
        end,
    })
end

local function LowHpSuppressed()
    if UnitIsDeadOrGhost("player") then return true end
    if InCombatLockdown() then return false end
    return (UnitCastingInfo("player") or UnitChannelInfo("player")) ~= nil
end

local function UpdateLowHpAlpha()
    local db = GetDB()
    if db.lowHpLocked == false then
        lowHpFrame:SetAlpha(1)
        return
    end
    if LowHpSuppressed() then
        lowHpFrame:SetAlpha(0)
        return
    end
    ApplyThresholdAlpha(lowHpFrame, "player", db.lowHpThreshold)
end

local UpdateLowHpAlphaDispatch = BUI.Dispatcher.New(UpdateLowHpAlpha, "Auras.LowHpAlpha")
local lowHpEventsRegistered = false

local function HideLowHp()
    if lowHpEventsRegistered then
        BUI.Events:UnregisterAll("LowHpWarning")
        lowHpEventsRegistered = false
    end
    if lowHpFrame then
        lowHpFrame:Hide()
    end
end

function Auras.UpdateLowHp()
    local db = GetDB()
    if not db.lowHpWarning then
        HideLowHp()
        return
    end

    BuildLowHp()
    lowHpText:SetText(db.lowHpText)
    Pixel.ApplyFont(lowHpText, db.lowHpFontSize, BUI.GetModuleFont({ font = db.lowHpFont }))
    local color = db.lowHpColor
    lowHpText:SetTextColor(color.r, color.g, color.b, color.a)

    BUI.Anchor.ApplyPosition(lowHpFrame, lowHpSettings)
    lowHpFrame:SnapSize(
        lowHpText:GetStringWidth() + 40,
        lowHpText:GetStringHeight() + 20
    )
    BUI.Dragging.SetLocked(lowHpFrame, db.lowHpLocked ~= false)
    if not lowHpEventsRegistered then
        lowHpEventsRegistered = true
        BUI.Events:RegisterUnit("UNIT_HEALTH",                  "player", "LowHpWarning", UpdateLowHpAlphaDispatch)
        BUI.Events:RegisterUnit("UNIT_SPELLCAST_START",         "player", "LowHpWarning", UpdateLowHpAlpha)
        BUI.Events:RegisterUnit("UNIT_SPELLCAST_STOP",          "player", "LowHpWarning", UpdateLowHpAlpha)
        BUI.Events:RegisterUnit("UNIT_SPELLCAST_CHANNEL_START", "player", "LowHpWarning", UpdateLowHpAlpha)
        BUI.Events:RegisterUnit("UNIT_SPELLCAST_CHANNEL_STOP",  "player", "LowHpWarning", UpdateLowHpAlpha)
        BUI.Events:Register("PLAYER_REGEN_DISABLED", "LowHpWarning", UpdateLowHpAlpha)
        BUI.Events:Register("PLAYER_REGEN_ENABLED",  "LowHpWarning", UpdateLowHpAlpha)
        BUI.Events:Register("PLAYER_ALIVE",          "LowHpWarning", UpdateLowHpAlpha)
        BUI.Events:Register("PLAYER_UNGHOST",        "LowHpWarning", UpdateLowHpAlpha)
    end

    lowHpFrame:Show()
    UpdateLowHpAlpha()
end

local HUNTERS_MARK_SPELL = 257284
local MARK_WINDOW_WIDTH = 420
local MARK_WINDOW_HEIGHT = 60
local MARK_SLIDE_GAP = 2
local MARK_EMPTY_WIDTH = 1
local MARK_SLIDE_WIDTH = 10000

local markFrame, markClip, markContainer, markPanel
local markText, markIcon, markPulse
local markRuntimeOn = false
local markEventsRegistered = false

local function MarkConditionsMet()
    local db = GetDB()
    if UnitIsDeadOrGhost("player") then return false end
    if db.markCombatOnly and not InCombatLockdown() then return false end
    if db.markGroupOnly and not IsInGroup() then return false end
    if db.markHideInTown and IsResting() and not IsInInstance() then return false end
    return true
end

local function MarkTargetNeedsCallout()
    return MarkConditionsMet()
        and UnitExists("target")
        and UnitCanAttack("player", "target")
        and not UnitIsDeadOrGhost("target")
end

local markRuntimeWanted = false
local ApplyMarkRuntime

ApplyMarkRuntime = function()
    if not markContainer or markRuntimeOn == markRuntimeWanted then return end
    if InCombatLockdown() then
        BUI.Events:AfterCombat(ApplyMarkRuntime, "Auras.MarkRuntime")
        return
    end
    markRuntimeOn = markRuntimeWanted
    local Engine = BUI.AuraEngine
    if markRuntimeOn then
        markContainer:Show()
        Engine.BindUnit(markContainer, "target")
    else
        Engine.BindUnit(markContainer, nil)
        markContainer:Hide()
    end
end

local function SetMarkRuntime(enabled)
    markRuntimeWanted = enabled
    ApplyMarkRuntime()
end

local function RefreshMarkShown()
    if not markPanel then return end
    if GetDB().markLocked == false then
        markPanel:Show()
        return
    end
    markPanel:SetShown(MarkTargetNeedsCallout())
end

local function RefreshMarkTarget()
    if markRuntimeOn then
        markContainer:UpdateAllAuras()
    end
    RefreshMarkShown()
end

local RefreshMarkShownDispatch = BUI.Dispatcher.New(RefreshMarkShown, "Auras.MarkCheck")

local function HideMarkButton(button)
    button:SetAlpha(0)
    button:EnableMouse(false)
end

local markSettings = BUI.Anchor.PrefixedSettings(GetDB, "mark")
local function MarkSettings() return markSettings end

local function AnchorMarkPanel(locked)
    markPanel:ClearAllPoints()
    if locked then
        markPanel:SetPoint("TOPLEFT", markContainer, "TOPLEFT", MARK_SLIDE_GAP + MARK_EMPTY_WIDTH, 0)
    else
        markPanel:SetPoint("TOPLEFT", markClip, "TOPLEFT", 0, 0)
    end
end

local function BuildMarkWarning()
    if markFrame then return end
    local Engine = BUI.AuraEngine
    if not Engine.Available then return end

    local frame = CreateFrame("Frame", "BUI_MarkWarning", UIParent)
    frame:SetSize(MARK_WINDOW_WIDTH, MARK_WINDOW_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(98)
    frame:Hide()

    local clip = CreateFrame("Frame", nil, frame)
    clip:SetAllPoints(frame)
    clip:SetClipsChildren(true)
    clip:EnableMouse(false)
    clip._buiSkipMouseWalk = true

    local container = Engine.NewContainer(clip, true, 1)
    container:ClearAllPoints()
    container:SetPoint("TOPRIGHT", clip, "TOPLEFT", -MARK_SLIDE_GAP, 0)
    if container.SetFlowLayoutAnchorPoint then container:SetFlowLayoutAnchorPoint("TOPLEFT") end
    container:EnableMouse(false)
    if container.SetUnit then container:SetUnit("target") end
    if container.AddAuraGroup then
        container:AddAuraGroup("markMissing", "HARMFUL", {
            maxFrameCount = 1,
            candidateFilters = { includeSpellIDs = { [HUNTERS_MARK_SPELL] = true } },
            layout = { elementWidth = MARK_SLIDE_WIDTH, elementHeight = MARK_WINDOW_HEIGHT },
            initializeFrame = HideMarkButton,
        })
    end
    Engine.BindUnit(container, nil)
    container:Hide()

    local panel = CreateFrame("Frame", nil, clip, "DisableUntrustedLayoutScriptsTemplate")
    panel:SetSize(MARK_WINDOW_WIDTH, MARK_WINDOW_HEIGHT)
    panel:SetFrameLevel(clip:GetFrameLevel() + 5)
    panel:EnableMouse(false)
    panel:SetPoint("TOPLEFT", container, "TOPLEFT", MARK_SLIDE_GAP + MARK_EMPTY_WIDTH, 0)

    local text = panel:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(text, 24)
    text:SetJustifyH("CENTER")

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(C_Spell.GetSpellTexture(HUNTERS_MARK_SPELL))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local pulse = icon:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local pulseAlpha = pulse:CreateAnimation("Alpha")
    pulseAlpha:SetFromAlpha(1)
    pulseAlpha:SetToAlpha(0.4)
    pulseAlpha:SetDuration(0.5)

    markFrame = frame
    markClip = clip
    markContainer = container
    markPanel = panel
    markText = text
    markIcon = icon
    markPulse = pulse

    BUI.Dragging.MakeAnchoredAlert(markFrame, {
        settings = MarkSettings,
        isLocked = function() return GetDB().markLocked ~= false end,
        onRightClick = function()
            GetDB().markLocked = true
            BUI.Dragging.SetLocked(markFrame, true)
            if Auras._markLockToggle then Auras._markLockToggle:SetValue(false) end
            Auras.UpdateMark()
        end,
    })
end

local function StyleMarkWarning()
    if not markFrame or not markText then return end
    local db = GetDB()
    local fontSize = db.markFontSize
    markText:SetText(db.markText)
    Pixel.ApplyFont(markText, fontSize, BUI.GetModuleFont({ font = db.markFont }))
    local color = db.markColor
    markText:SetTextColor(color.r, color.g, color.b, color.a)

    local iconSize = fontSize + 6
    local showIcon = db.markShowIcon ~= false
    markIcon:SetSize(iconSize, iconSize)
    markIcon:SetShown(showIcon)

    markText:ClearAllPoints()
    markIcon:ClearAllPoints()
    if showIcon then
        markText:SetPoint("CENTER", markPanel, "CENTER", math.floor(iconSize / 2) + 3, 0)
        markIcon:SetPoint("RIGHT", markText, "LEFT", -6, 0)
    else
        markText:SetPoint("CENTER", markPanel, "CENTER", 0, 0)
    end

    BUI.Anchor.ApplyPosition(markFrame, markSettings)

    if db.markPulse ~= false and showIcon then markPulse:Play() else markPulse:Stop() end
end

local function WireMarkEvents()
    if markEventsRegistered then return end
    markEventsRegistered = true
    BUI.Events:Register("PLAYER_TARGET_CHANGED", "MarkWarning", RefreshMarkTarget)
    BUI.Events:Register("PLAYER_ENTERING_WORLD", "MarkWarning", RefreshMarkTarget)
    BUI.Events:RegisterUnit("UNIT_FACTION", "target", "MarkWarning", RefreshMarkShownDispatch)
    BUI.Events:RegisterUnit("UNIT_TARGETABLE_CHANGED", "target", "MarkWarning", RefreshMarkShownDispatch)
    BUI.Events:RegisterUnit("UNIT_HEALTH", "target", "MarkWarning", RefreshMarkShownDispatch)
    BUI.Events:Register("PLAYER_REGEN_DISABLED", "MarkWarning", RefreshMarkShownDispatch)
    BUI.Events:Register("PLAYER_REGEN_ENABLED", "MarkWarning", RefreshMarkShownDispatch)
    BUI.Events:Register("PLAYER_UPDATE_RESTING", "MarkWarning", RefreshMarkShownDispatch)
    BUI.Events:Register("ZONE_CHANGED_NEW_AREA", "MarkWarning", RefreshMarkShownDispatch)
    BUI.Events:Register("GROUP_ROSTER_UPDATE", "MarkWarning", RefreshMarkShownDispatch)
    BUI.Events:Register("PLAYER_DEAD", "MarkWarning", RefreshMarkShownDispatch)
    BUI.Events:Register("PLAYER_ALIVE", "MarkWarning", RefreshMarkShownDispatch)
    BUI.Events:Register("PLAYER_UNGHOST", "MarkWarning", RefreshMarkShownDispatch)
end

local function UnwireMarkEvents()
    if not markEventsRegistered then return end
    markEventsRegistered = false
    BUI.Events:UnregisterAll("MarkWarning")
end

function Auras.UpdateMark()
    local db = GetDB()
    local wanted = db.markWarning == true and playerClass == "HUNTER"
    if not wanted then
        UnwireMarkEvents()
        SetMarkRuntime(false)
        if markFrame then
            markFrame:Hide()
            markPulse:Stop()
        end
        return
    end
    if not markFrame then
        if InCombatLockdown() then
            BUI.Events:AfterCombat(Auras.UpdateMark, "Auras.MarkBuild")
            return
        end
        BuildMarkWarning()
        if not markFrame then return end
    end
    local locked = db.markLocked ~= false
    StyleMarkWarning()
    AnchorMarkPanel(locked)
    BUI.Dragging.SetLocked(markFrame, locked)
    WireMarkEvents()
    markFrame:Show()
    SetMarkRuntime(locked)
    RefreshMarkShown()
end

BUI.Events:OnLogin("Auras", Auras.Initialize, "auras")

BUI.Anchor.Follow("Auras.Pet", function() return GetDB().petWarningsEnabled and warningFrame end, GetDB)
BUI.Anchor.Follow("Auras.PetHealth", function() return GetDB().petWarningsEnabled and healthFrame end, GetDB)
BUI.Anchor.Follow("Auras.LowHp", function() return GetDB().lowHpWarning and lowHpFrame end, LowHpSettings)
BUI.Anchor.Follow("Auras.Mark", function() return GetDB().markWarning and markFrame end, MarkSettings)
