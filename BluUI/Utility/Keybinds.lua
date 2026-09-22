local _, BUI = ...

local Keybinds = {}
BUI.Keybinds = Keybinds

local MODIFIER_LABELS = {
    SHIFT = "S",
    CTRL  = "C",
    ALT   = "A",
    STRG  = "C",
}

local KEY_LABELS = {
    MOUSEWHEELUP   = "WU",
    MOUSEWHEELDOWN = "WD",
    NUMPADPLUS     = "N+",
    NUMPADMINUS    = "N-",
    NUMPADDIVIDE   = "N/",
    NUMPADMULTIPLY = "N*",
    NUMPADDECIMAL  = "N.",
    NUMPADENTER    = "NE",
    PAGEUP         = "PU",
    PAGEDOWN      = "PD",
    INSERT         = "Ins",
    DELETE         = "Del",
    SPACE          = "Spc",
    SPACEBAR       = "Spc",
    ESCAPE         = "Esc",
    BACKSPACE      = "BkSp",
    CAPSLOCK       = "Caps",
    HOME           = "Hm",
    END            = "End",
}

local PREFIX_LABELS = {
    MOUSEBUTTON = "M",
    BUTTON      = "M",
    NUMPAD      = "N",
}

function Keybinds.Format(key)
    if not key or key == "" then return nil end
    key = key:upper()
    local result = ""
    local position = 1
    while true do
        local separator = key:find("-", position, true)
        if not separator then break end
        local modifierLabel = MODIFIER_LABELS[key:sub(position, separator - 1)]
        if not modifierLabel then break end
        result = result .. modifierLabel
        position = separator + 1
    end
    local base = key:sub(position)
    local label = KEY_LABELS[base]
    if not label then
        local prefix, number = base:match("^(%a+)(%d+)$")
        if prefix and PREFIX_LABELS[prefix] then
            label = PREFIX_LABELS[prefix] .. number
        else
            label = base
        end
    end
    return result .. label
end
