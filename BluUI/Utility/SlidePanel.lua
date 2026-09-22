local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Util.SlidePanel')

BUI.SlidePanel = {}

local SLIDE_DURATION = 0.22

local panels = {}

local function Anchor()
    return BUI.Skinning.GetCharacterFrame() or CharacterFrame
end

function BUI.SlidePanel.New(options)
    local slidePanel = { open = false }
    panels[#panels + 1] = slidePanel

    local hiddenX = options.hiddenX

    local function Width()
        if type(options.width) == 'function' then return options.width() end
        return options.width
    end

    local function SetOffset(offsetX)
        local panel = options.panel()
        if not panel then return end
        local anchor = Anchor()
        if not anchor then return end
        panel:ClearAllPoints()
        panel:SetPoint('TOPLEFT', anchor, 'TOPRIGHT', offsetX, 0)
        panel:SetSize(Width(), anchor:GetHeight())
    end
    slidePanel.SetOffset = SetOffset

    local function SlideTo(targetX, onDone)
        local panel = options.panel()
        if not panel then return end
        local _, _, _, startX = panel:GetPoint(1)
        startX = startX or hiddenX
        local elapsed = 0
        SetScript(panel, 'OnUpdate', function(self, deltaTime)
            elapsed = elapsed + deltaTime
            local progress = math.min(1, elapsed / SLIDE_DURATION)
            local eased = 1 - (1 - progress) * (1 - progress) * (1 - progress)
            SetOffset(startX + (targetX - startX) * eased)
            if progress >= 1 then
                SetScript(self, 'OnUpdate', nil)
                if onDone then onDone() end
            end
        end)
    end

    function slidePanel.Open()
        if slidePanel.open then return end
        if not BUI.Skinning.IsSkinEnabled(options.skin) then return end
        for panelIndex = 1, #panels do
            local other = panels[panelIndex]
            if other ~= slidePanel and other.open then other.Close() end
        end
        if not options.panel() then options.build() end
        local panel = options.panel()
        if not panel then return end
        panel.isBluUIWindow = true
        SetOffset(hiddenX)
        panel:Show()
        if options.onOpen then options.onOpen() end
        slidePanel.open = true
        SlideTo(2)
    end

    function slidePanel.Close(immediate)
        if options.onClose then options.onClose() end
        local panel = options.panel()
        if not panel or not panel:IsShown() then
            slidePanel.open = false
            return
        end
        if immediate then
            SetScript(panel, 'OnUpdate', nil)
            panel:Hide()
            slidePanel.open = false
            return
        end
        slidePanel.open = false
        SlideTo(hiddenX, function() panel:Hide() end)
    end

    function slidePanel.Toggle()
        if slidePanel.open then slidePanel.Close() else slidePanel.Open() end
    end

    function slidePanel.IsOpen()
        return slidePanel.open
    end

    return slidePanel
end
