local _, BUI = ...

local CreateFrame = CreateFrame
local UIParent = UIParent

local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local CDM = BUI.CDM
local Pixel = BUI.Pixel
local BLANK = BUI.C.FALLBACK_TEXTURE

function CDM.SetupBlizzardOverlay()
    if not CooldownViewerSettings then return end

    local overlay = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetBackdrop({
        bgFile = BLANK,
        edgeFile = BLANK,
        edgeSize = 1,
    })
    overlay:SetBackdropColor(0.05, 0.0, 0.1, 0.92)
    overlay:SetBackdropBorderColor(0.43, 0, 0.99, 0.8)
    overlay:EnableMouse(true)
    overlay:Hide()

    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", overlay, "CENTER", 0, Pixel.Scale(10))
    text:SetText("|cff" .. BUI.C.COLOR_BRAND .. "BluUI|r is controlling icon order.")
    text:SetTextColor(1, 1, 1)
    text:SetShadowOffset(0, 0)

    local subtext = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtext:SetPoint("TOP", text, "BOTTOM", 0, Pixel.Scale(-6))
    subtext:SetText("Disable in |cff" .. BUI.C.COLOR_BRAND .. "/bluui|r > CDM > Blizzard Panel Overlay.")
    subtext:SetTextColor(0.7, 0.7, 0.7)
    subtext:SetShadowOffset(0, 0)

    local dismissButton = CreateFrame("Button", nil, overlay)
    dismissButton:SetSize(Pixel.Scale(80), Pixel.Scale(22))
    dismissButton:SetPoint("TOP", subtext, "BOTTOM", 0, Pixel.Scale(-10))
    Pixel.SetTemplate(dismissButton, 0.12, 0.0, 0.18, 0.95, 0.43, 0, 0.99, 0.8, 1)

    local buttonText = dismissButton:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(buttonText, 12, STANDARD_TEXT_FONT, "OUTLINE")
    buttonText:SetPoint("CENTER")
    buttonText:SetText("Dismiss")
    buttonText:SetTextColor(1, 1, 1)

    dismissButton:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.0, 0.3, 1) end)
    dismissButton:SetScript("OnLeave", function(self) self:SetBackdropColor(0.12, 0.0, 0.18, 0.95) end)
    local dismissed = false
    dismissButton:SetScript("OnClick", function()
        dismissed = true
        overlay:Hide()
    end)

    local onSpellsTab = true
    local PollTick

    local overlayChildBuf = {}
    local function HookTabs()
        local children, childCount = CDM.PackInto(overlayChildBuf, CooldownViewerSettings:GetChildren())
        local hookedAny = false
        for childIndex = 1, childCount do
            local child = children[childIndex]
            if child.GetText then
                local tabText = child:GetText()
                if tabText then
                    if tabText:find("Spell") or tabText:find("Cooldown") then
                        child:HookScript("OnClick", function()
                            onSpellsTab = true
                            if PollTick then PollTick() end
                        end)
                        hookedAny = true
                    elseif tabText:find("Aura") or tabText:find("Buff") then
                        child:HookScript("OnClick", function()
                            onSpellsTab = false
                            if PollTick then PollTick() end
                        end)
                        hookedAny = true
                    end
                end
            end
        end
        return hookedAny
    end

    local function CheckTabState()
        local spellsTab = CooldownViewerSettings.SpellsTab
        if spellsTab and spellsTab.SelectedTexture and spellsTab.SelectedTexture.IsShown then
            return spellsTab.SelectedTexture:IsShown()
        end
        local aurasTab = CooldownViewerSettings.AurasTab
        if aurasTab and aurasTab.SelectedTexture and aurasTab.SelectedTexture.IsShown then
            return not aurasTab.SelectedTexture:IsShown()
        end
        return onSpellsTab
    end

    local tabsHooked = false
    local pollTicker  = nil
    local cachedDB    = nil
    local anchored    = false

    PollTick = function()
        if not tabsHooked then
            tabsHooked = HookTabs()
        end
        if tabsHooked and pollTicker then
            pollTicker:Cancel()
            pollTicker = nil
        end

        local db = cachedDB
        if not db then
            overlay:Hide()
            return
        end
        if not db.cdm.showBlizzardOverlay or dismissed then
            overlay:Hide()
            return
        end

        local essentialSettings = db.cdm.essential
        local utilitySettings = db.cdm.utility
        local cdmEnabled = (essentialSettings and essentialSettings.enabled) or (utilitySettings and utilitySettings.enabled)
        local shouldShow = cdmEnabled and CheckTabState()

        overlay:SetShown(shouldShow)
        if shouldShow and not anchored then
            overlay:ClearAllPoints()
            overlay:SetAllPoints(CooldownViewerSettings)
            anchored = true
        end
    end

    CooldownViewerSettings:HookScript("OnShow", function()
        cachedDB = BUI.GetDB()
        PollTick()
        if not pollTicker and not tabsHooked then
            pollTicker = C_Timer.NewTicker(1.0, PollTick)
        end
    end)
    CooldownViewerSettings:HookScript("OnHide", function()
        overlay:Hide()
        dismissed = false
        cachedDB = nil
        anchored = false
        if pollTicker then
            pollTicker:Cancel()
            pollTicker = nil
        end
    end)

    if CooldownViewerSettings:IsShown() then
        cachedDB = BUI.GetDB()
        PollTick()
        if not pollTicker and not tabsHooked then
            pollTicker = C_Timer.NewTicker(1.0, PollTick)
        end
    end
end
