local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Datatext.Panel')

local Datatext = BUI.Datatext
local Pixel = BUI.Pixel

local hoverPanels = {}

local function FadeOut(panel)
    if not panel:IsShown() or panel._fadingOut then return end
    panel._fadingOut = true
    panel.introFade:Stop()
    panel.outroFade:Stop()
    panel.outroFade:Play()
end

local function ForceHide(panel)
    if not panel:IsShown() then return end
    panel._fadingOut = false
    panel.outroFade:Stop()
    panel.introFade:Stop()
    panel:SetAlpha(1)
    panel:Hide()
end

local function Reveal(panel)
    panel._outTime = 0
    panel._fadingOut = false
    panel.outroFade:Stop()
    panel:SetAlpha(1)
    panel:Show()
    panel.introFade:Stop()
    panel.introFade:Play()
end

local function OnUpdate(self, elapsed)
    self._accumulated = (self._accumulated or 0) + elapsed
    if self._accumulated < 0.1 then return end
    local accumulated = self._accumulated
    self._accumulated = 0
    local menu = _G.BUI_MinimapMenu
    if menu and menu:IsShown() then
        ForceHide(self)
        return
    end
    if self:IsMouseOver() or (self.anchor and self.anchor:IsMouseOver()) then
        self._outTime = 0
        if self._fadingOut then
            self._fadingOut = false
            self.outroFade:Stop()
            self:SetAlpha(1)
        end
    elseif not self._fadingOut then
        self._outTime = (self._outTime or 0) + accumulated
        if self._outTime > 0.5 then FadeOut(self) end
    end
end

function Datatext.CreateHoverPanel(name, width)
    local panel = CreateFrame('Frame', name, UIParent, 'BackdropTemplate')
    panel.isBluUIWindow = true
    panel:SetWidth(Pixel.Scale(width))
    panel:SetFrameStrata('DIALOG')
    panel:SetFrameLevel(200)
    panel:SetClampedToScreen(true)
    Pixel.SetTemplate(panel, unpack(BUI.C.PANEL_BACKDROP))
    panel:EnableMouse(true)
    panel:Hide()

    panel.title = panel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panel.title, 12, Datatext.PanelFont())
    panel.title:SetPoint('TOPLEFT', Pixel.Scale(10), Pixel.Scale(-8))

    panel.introFade = panel:CreateAnimationGroup()
    local fade = panel.introFade:CreateAnimation('Alpha')
    fade:SetFromAlpha(0); fade:SetToAlpha(1); fade:SetDuration(0.12); fade:SetSmoothing('OUT')
    SetScript(panel.introFade, 'OnFinished', function() panel:SetAlpha(1) end)

    panel.outroFade = panel:CreateAnimationGroup()
    local outro = panel.outroFade:CreateAnimation('Alpha')
    outro:SetFromAlpha(1); outro:SetToAlpha(0); outro:SetDuration(0.22); outro:SetSmoothing('IN')
    SetScript(panel.outroFade, 'OnFinished', function() panel._fadingOut = false; panel:Hide() end)

    panel.Reveal, panel.FadeOut, panel.ForceHide = Reveal, FadeOut, ForceHide
    SetScript(panel, 'OnUpdate', OnUpdate)

    hoverPanels[#hoverPanels + 1] = panel
    return panel
end

function Datatext.PlacePanelAtCursor(panel)
    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    local offset = Pixel.Scale(14)
    panel:ClearAllPoints()
    if cursorY - panel:GetHeight() < 40 then
        panel:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', cursorX + offset, cursorY + offset)
    else
        panel:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', cursorX + offset, cursorY - offset)
    end
end

function Datatext.HideAllHovers()
    for panelIndex = 1, #hoverPanels do ForceHide(hoverPanels[panelIndex]) end
    local owner = GameTooltip:GetOwner()
    if owner and owner.isDatatextHit then GameTooltip:Hide() end
end
