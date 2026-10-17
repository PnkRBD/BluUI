local _, BUI = ...

local Hook = BUI.Profiler.Hooker('CDM.Overlay')

local CreateFrame = CreateFrame
local UIParent = UIParent

local CDM = BUI.CDM
local Pixel = BUI.Pixel
local Painter = BUI.Painter

function CDM.SetupBlizzardOverlay()
    if not CooldownViewerSettings then return end
    local Skin = BUI.Skinning

    local overlay = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetAllPoints(CooldownViewerSettings)
    Painter.Custom(overlay, Skin.PaintPanelBackdrop)
    overlay:EnableMouse(true)
    overlay:Hide()

    local text = overlay:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(text, 16)
    text:SetPoint("CENTER", overlay, "CENTER", 0, Pixel.Scale(10))
    text:SetText("|cff" .. BUI.C.COLOR_BRAND .. "BluUI|r is controlling icon order.")
    Painter.Text(text, 'skinTitle')

    local subtext = overlay:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(subtext, 12)
    subtext:SetPoint("TOP", text, "BOTTOM", 0, Pixel.Scale(-6))
    subtext:SetText("Disable in |cff" .. BUI.C.COLOR_BRAND .. "/bluui|r > CDM > Blizzard Panel Overlay.")
    Painter.Text(subtext, 'skinLabel')

    local dismissButton = CreateFrame("Button", nil, overlay, "BackdropTemplate")
    dismissButton:SetSize(Pixel.Scale(80), Pixel.Scale(22))
    dismissButton:SetPoint("TOP", subtext, "BOTTOM", 0, Pixel.Scale(-10))
    Painter.Custom(dismissButton, Skin.PaintPanelBackdrop)

    local buttonText = dismissButton:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(buttonText, 12)
    buttonText:SetPoint("CENTER")
    buttonText:SetText("Dismiss")
    Painter.Text(buttonText, 'skinText')

    dismissButton:SetScript("OnEnter", BUI.Profiler.Script('CDM.Overlay dismissButton OnEnter', function(self) self:SetBackdropBorderColor(unpack(Skin.HoverColor())) end))
    dismissButton:SetScript("OnLeave", BUI.Profiler.Script('CDM.Overlay dismissButton OnLeave', Skin.PaintPanelBackdrop))
    local dismissed = false
    dismissButton:SetScript("OnClick", BUI.Profiler.Script('CDM.Overlay dismissButton OnClick', function()
        dismissed = true
        overlay:Hide()
    end))

    local function Refresh()
        local cdm = BUI.GetDB().cdm
        overlay:SetShown(cdm.showBlizzardOverlay and not dismissed
            and (cdm.essential.enabled or cdm.utility.enabled)
            and CooldownViewerSettings:IsShown()
            and CooldownViewerSettings.displayMode == "spells")
    end

    Hook(CooldownViewerSettings, "SetDisplayMode", Refresh)
    CooldownViewerSettings:HookScript("OnShow", BUI.Profiler.Wrap("CDM.Overlay settings show", Refresh))
    CooldownViewerSettings:HookScript("OnHide", BUI.Profiler.Wrap("CDM.Overlay settings hide", function()
        overlay:Hide()
        dismissed = false
    end))

    if CooldownViewerSettings:IsShown() then Refresh() end
end
