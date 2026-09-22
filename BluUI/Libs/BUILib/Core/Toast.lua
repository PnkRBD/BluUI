local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end
local Toast = BUILib.Toast
local Widget = BUILib.Widget

local CreateFrame, GetTime, UIParent = CreateFrame, GetTime, UIParent

local DEFAULT_DURATION = 5
local FADE_IN          = 0.2
local FADE_OUT         = 0.3
local SLIDE_IN         = 0.3
local SLIDE_OUT        = 0.22
local STACK_GAP        = 8
local EDGE_OFFSET      = 16
local TOAST_WIDTH      = 320
local BAR_HEIGHT       = 48
local PADDING_X, PADDING_Y     = 14, 10

local VARIANTS = {
    success = { 0.30, 0.85, 0.45 },
    error   = { 0.95, 0.30, 0.30 },
    warning = { 0.95, 0.65, 0.20 },
    info    = { 0.30, 0.65, 0.95 },
}

local POSITIONS = {
    ["bottom-right"] = { vpart = "BOTTOM", hpart = "RIGHT", x = -EDGE_OFFSET, y =  EDGE_OFFSET, grow =  1 },
    ["bottom"]       = { vpart = "BOTTOM", hpart = "",      x = 0,            y =  EDGE_OFFSET, grow =  1 },
    ["top-right"]    = { vpart = "TOP",    hpart = "RIGHT", x = -EDGE_OFFSET, y = -EDGE_OFFSET, grow = -1 },
}
local DEFAULT_CARD_POSITION = "bottom-right"

local defaultParent = nil
function Toast.SetParent(parent) defaultParent = parent end

local function EaseOutQuad(progress) return progress * (2 - progress) end
local function Lerp(from, to, ratio) return from + (to - from) * ratio end

local cardStacks = {}
for key in pairs(POSITIONS) do cardStacks[key] = {} end
local barSlots = {}

local function ReanchorCards(positionKey)
    local position  = POSITIONS[positionKey]
    local list = cardStacks[positionKey]
    local anchor = position.vpart .. position.hpart
    for index, token in ipairs(list) do
        local frame = token._frame
        frame:ClearAllPoints()
        if index == 1 then
            frame:SetPoint(anchor, token._parent, anchor, position.x, position.y)
        elseif position.grow > 0 then
            frame:SetPoint("BOTTOM" .. position.hpart, list[index - 1]._frame, "TOP" .. position.hpart, 0, STACK_GAP)
        else
            frame:SetPoint("TOP" .. position.hpart, list[index - 1]._frame, "BOTTOM" .. position.hpart, 0, -STACK_GAP)
        end
    end
end

local function SetBarOffset(token, yOffset)
    token._curOffset = yOffset
    local frame, clip = token._frame, token._clip
    frame:ClearAllPoints()
    if token._edge == "bottom" then
        frame:SetPoint("BOTTOMLEFT",  clip, "BOTTOMLEFT",  0, yOffset)
        frame:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, yOffset)
    else
        frame:SetPoint("TOPLEFT",  clip, "TOPLEFT",  0, yOffset)
        frame:SetPoint("TOPRIGHT", clip, "TOPRIGHT", 0, yOffset)
    end
end

local function Destroy(token)
    if token._destroyed then return end
    token._destroyed = true
    local frame = token._frame
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
    frame:SetParent(nil)

    if token._kind == "bar" then
        if barSlots[token._edge] == token then barSlots[token._edge] = nil end
        if token._clip then
            token._clip:Hide()
            token._clip:SetParent(nil)
        end
    else
        local list = cardStacks[token._posKey]
        for index, stacked in ipairs(list) do
            if stacked == token then table.remove(list, index); break end
        end
        ReanchorCards(token._posKey)
    end
end

local function RunAnim(token, duration, onStep, onDone)
    local startTime = GetTime()
    token._frame:SetScript("OnUpdate", function(self)
        local progress = (GetTime() - startTime) / duration
        if progress >= 1 then
            onStep(token, 1)
            self:SetScript("OnUpdate", nil)
            if onDone then onDone(token) end
        else
            onStep(token, EaseOutQuad(progress))
        end
    end)
end

local function StartSit(token)
    local sitUntil = GetTime() + token._duration
    token._frame:SetScript("OnUpdate", function(self)
        if GetTime() >= sitUntil then
            self:SetScript("OnUpdate", nil)
            token:Dismiss()
        end
    end)
end

local function Disappear(token)
    if token._leaving or token._destroyed then return end
    token._leaving = true
    local frame = token._frame
    local fromAlpha = frame:GetAlpha()

    if token._kind == "bar" then
        local fromOffset = token._curOffset or 0
        RunAnim(token, SLIDE_OUT, function(animatedToken, progress)
            SetBarOffset(animatedToken, Lerp(fromOffset, animatedToken._hiddenOffset, progress))
            frame:SetAlpha(fromAlpha * (1 - progress))
        end, Destroy)
    else
        RunAnim(token, FADE_OUT, function(_, progress)
            frame:SetAlpha(fromAlpha * (1 - progress))
        end, Destroy)
    end
end

local function Appear(token)
    local frame = token._frame
    if token._kind == "bar" then
        SetBarOffset(token, token._hiddenOffset)
        frame:SetAlpha(0)
        RunAnim(token, SLIDE_IN, function(animatedToken, progress)
            SetBarOffset(animatedToken, Lerp(animatedToken._hiddenOffset, 0, progress))
            frame:SetAlpha(progress)
        end, StartSit)
    else
        frame:SetAlpha(0)
        RunAnim(token, FADE_IN, function(_, progress)
            frame:SetAlpha(progress)
        end, StartSit)
    end
end

local function BuildCardFrame(parent, text, subtext, color, onClick, token)
    local height = subtext and (PADDING_Y * 2 + 14 + 4 + 12) or (PADDING_Y * 2 + 14)

    local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    frame:SetSize(TOAST_WIDTH, height)
    frame:SetFrameStrata(parent:GetFrameStrata())
    frame:SetFrameLevel((parent:GetFrameLevel() or 0) + 100)
    Widget.DrawRoundedRect(frame, 6, { 0.20, 0.22, 0.26, 0.85 }, "BACKGROUND", 0, 0)
    Widget.DrawRoundedRect(frame, 5, { 0.06, 0.07, 0.08, 0.96 }, "BACKGROUND", 1, 1)

    local stripe = frame:CreateTexture(nil, "OVERLAY")
    stripe:SetTexture(Widget.WHITE)
    stripe:SetVertexColor(color[1], color[2], color[3], 1)
    stripe:SetPoint("TOPLEFT",  1, -1)
    stripe:SetPoint("TOPRIGHT", -1, -1)
    stripe:SetHeight(2)

    local titleFontString = frame:CreateFontString(nil, "OVERLAY")
    titleFontString:SetFont(BUILib.Font, 12, "")
    titleFontString:SetPoint("TOPLEFT",  PADDING_X, -PADDING_Y)
    titleFontString:SetPoint("TOPRIGHT", -PADDING_X, -PADDING_Y)
    titleFontString:SetJustifyH("LEFT")
    titleFontString:SetText(text)
    titleFontString:SetTextColor(0.95, 0.95, 0.97, 1)

    if subtext then
        local subFontString = frame:CreateFontString(nil, "OVERLAY")
        subFontString:SetFont(BUILib.Font, 10, "")
        subFontString:SetPoint("TOPLEFT",  titleFontString, "BOTTOMLEFT",  0, -4)
        subFontString:SetPoint("TOPRIGHT", titleFontString, "BOTTOMRIGHT", 0, -4)
        subFontString:SetJustifyH("LEFT")
        subFontString:SetWordWrap(false)
        subFontString:SetText(subtext)
        subFontString:SetTextColor(0.6, 0.6, 0.65, 1)
    end

    frame:SetScript("OnClick", function()
        if onClick then onClick() end
        token:Dismiss()
    end)
    return frame
end

local function BuildBarFrame(parent, text, subtext, color, onClick, token)

    local clip = CreateFrame("Frame", nil, parent)
    clip:SetAllPoints(parent)
    clip:SetFrameStrata(parent:GetFrameStrata())
    clip:SetFrameLevel((parent:GetFrameLevel() or 0) + 100)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    token._clip = clip

    local frame = CreateFrame("Button", nil, clip)
    frame:SetHeight(BAR_HEIGHT)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.06, 0.07, 0.08, 0.98)

    local stripe = frame:CreateTexture(nil, "OVERLAY")
    stripe:SetTexture(Widget.WHITE)
    stripe:SetVertexColor(color[1], color[2], color[3], 1)
    stripe:SetHeight(2)
    if token._edge == "bottom" then
        stripe:SetPoint("TOPLEFT", 0, 0)
        stripe:SetPoint("TOPRIGHT", 0, 0)
    else
        stripe:SetPoint("BOTTOMLEFT", 0, 0)
        stripe:SetPoint("BOTTOMRIGHT", 0, 0)
    end

    local dot = frame:CreateTexture(nil, "OVERLAY")
    dot:SetTexture(Widget.WHITE)
    dot:SetVertexColor(color[1], color[2], color[3], 1)
    dot:SetSize(8, 8)
    dot:SetPoint("LEFT", 20, 0)

    local titleFontString = frame:CreateFontString(nil, "OVERLAY")
    titleFontString:SetFont(BUILib.Font, 13, "")
    titleFontString:SetPoint("LEFT", dot, "RIGHT", 10, 0)
    titleFontString:SetText(text)
    titleFontString:SetTextColor(0.95, 0.95, 0.97, 1)

    if subtext then
        local subFontString = frame:CreateFontString(nil, "OVERLAY")
        subFontString:SetFont(BUILib.Font, 11, "")
        subFontString:SetPoint("LEFT", titleFontString, "RIGHT", 10, 0)
        subFontString:SetText(subtext)
        subFontString:SetTextColor(0.6, 0.6, 0.65, 1)
    end

    frame:SetScript("OnClick", function()
        if onClick then onClick() end
        token:Dismiss()
    end)
    return frame
end

function Toast.Show(options)
    options = options or {}
    local variant  = options.variant or "info"
    local color    = VARIANTS[variant] or VARIANTS.info
    local parent   = options.parent or BUILib.GetActiveClient().popupParent or defaultParent or UIParent
    local duration = options.duration or DEFAULT_DURATION

    local token = { _parent = parent, _duration = duration }
    function token:Dismiss() Disappear(self) end

    if options.style == "bar" then
        local edge = (options.position == "top") and "top" or "bottom"
        token._kind         = "bar"
        token._edge         = edge
        token._hiddenOffset = (edge == "bottom") and -BAR_HEIGHT or BAR_HEIGHT
        if barSlots[edge] then Destroy(barSlots[edge]) end
        barSlots[edge] = token
        token._frame = BuildBarFrame(parent, options.text or "", options.subtext, color, options.onClick, token)
    else
        local positionKey = POSITIONS[options.position] and options.position or DEFAULT_CARD_POSITION
        token._kind   = "card"
        token._posKey = positionKey
        token._frame  = BuildCardFrame(parent, options.text or "", options.subtext, color, options.onClick, token)
        local list = cardStacks[positionKey]
        list[#list + 1] = token
        ReanchorCards(positionKey)
    end

    Appear(token)
    return token
end

local function WithVariant(variant, text, subtext, options)
    local merged = {}
    if options then
        for key, value in pairs(options) do merged[key] = value end
    end
    merged.text, merged.subtext, merged.variant = text, subtext, variant
    return Toast.Show(merged)
end

function Toast.Success(text, subtext, options) return WithVariant("success", text, subtext, options) end
function Toast.Error(text, subtext, options)   return WithVariant("error",   text, subtext, options) end
function Toast.Warning(text, subtext, options) return WithVariant("warning", text, subtext, options) end
function Toast.Info(text, subtext, options)    return WithVariant("info",    text, subtext, options) end

