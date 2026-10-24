local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Controls = BUILib.Controls
local Theme = BUILib.Theme
local Widget = BUILib.Widget
local fontSize = BUILib.FONT_SIZE
local CHECKER_SIZE = 7
local CHECKER_LIGHT = 0.62
local CHECKER_DARK = 0.3

function Controls.ColorSwatch(parent, options)
    local red, green, blue, alpha = options.r or 1, options.g or 1, options.b or 1, options.a or 1
    local width = options.width or 120
    local label = options.label
    local hasOpacity = options.hasOpacity ~= false

    local state = { r = red, g = green, b = blue, a = alpha }
    local original = {}
    local host = Widget.Unwrap(parent)
    local container = label and CreateFrame("Frame", nil, host) or nil
    if container then container:SetSize(width, 18) end

    local buttonHost = container or { frame = host }
    local buttonWidget = Widget.New(buttonHost, "Button", nil, {
        bg = { 0, 0, 0, 1 }, border = Theme.border.hover, size = { 18, 18 },
    })
    local button = buttonWidget.frame
    if hasOpacity then
        for index = 1, 4 do
            local square = button:CreateTexture(nil, "ARTWORK")
            local shade = (index == 1 or index == 4) and CHECKER_LIGHT or CHECKER_DARK
            square:SetColorTexture(shade, shade, shade, 1)
            square:SetSize(CHECKER_SIZE, CHECKER_SIZE)
            square:SetPoint("TOPLEFT", (index == 2 or index == 4) and (2 + CHECKER_SIZE) or 2, index >= 3 and -(2 + CHECKER_SIZE) or -2)
        end
    end
    local fill = buttonWidget:CreateFill("OVERLAY", red, green, blue, alpha)
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)

    if container then
        button:SetPoint("LEFT")
        container.label = Controls.Text(container, label, fontSize, Theme.text.primary)
        container.label:SetPoint("LEFT", button, "RIGHT", 8, 0)
    else
        container = button
    end

    button:SetScript("OnClick", function()
        original.r, original.g, original.b, original.a = state.r, state.g, state.b, state.a
        Controls.OpenColorPicker({
            r = state.r, g = state.g, b = state.b, a = state.a,
            hasOpacity = hasOpacity,
            anchorTo = button,
            callback = function(newRed, newGreen, newBlue, newAlpha, cancelled, phase)
                if cancelled then
                    state.r, state.g, state.b, state.a = original.r, original.g, original.b, original.a
                else
                    state.r, state.g, state.b, state.a = newRed, newGreen, newBlue, newAlpha
                end
                Widget.SetColor(fill, state.r, state.g, state.b, state.a)
                if options.callback then options.callback(state.r, state.g, state.b, state.a, cancelled, phase) end
            end,
        })
    end)

    if options.tooltip then Widget.Tooltip(button, options.tooltip) end

    function container:SetColor(newRed, newGreen, newBlue, newAlpha)
        state.r, state.g, state.b, state.a = newRed or 1, newGreen or 1, newBlue or 1, newAlpha or 1
        Widget.SetColor(fill, state.r, state.g, state.b, state.a)
    end
    function container:SetEnabled(enabled)
        if enabled then
            button:Enable(); button:SetAlpha(1)
            if container.label then container.label:SetTextColor(unpack(Theme.text.primary)) end
        else
            button:Disable(); button:SetAlpha(0.5)
            if container.label then container.label:SetTextColor(unpack(Theme.text.disabled)) end
        end
    end
    container.swatch = button
    return Widget.Wrap(container)
end
