local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Util.Pixel')
local hooksecurefunc = BUI.Prof.MakeHooker('pixel')
local Count = BUI.Prof.Count
local Pixel = {}
BUI.Pixel = Pixel

local floor, max, huge = math.floor, math.max, math.huge
local type, getmetatable, rawget = type, getmetatable, rawget
local FALLBACK_TEXTURE = BUI.C.FALLBACK_TEXTURE
local VIRTUAL_HEIGHT = 768
local _, screenPixels = GetPhysicalScreenSize()
if not screenPixels or screenPixels <= 0 then screenPixels = VIRTUAL_HEIGHT end
local perfectScale = VIRTUAL_HEIGHT / screenPixels
local gridUnit = 1
local listeners = {}

local function Recompute()
    local _, pixels = GetPhysicalScreenSize()
    if not pixels or pixels <= 0 then return false end
    local newPerfect = VIRTUAL_HEIGHT / pixels

    local active = BUI.AppliedUIScale()

    local newGrid = newPerfect / active
    if pixels == screenPixels and newGrid == gridUnit then return false end

    screenPixels = pixels
    perfectScale = newPerfect
    gridUnit = newGrid
    return true
end

local function Broadcast()
    for _, callback in pairs(listeners) do
        callback()
    end
end

function Pixel.OnScaleChange(id, callback)
    listeners[id] = callback
end

local function pixelsFor(value)
    return value / gridUnit
end

local function unitsFor(pixels)
    return pixels * gridUnit
end

local function wholePixels(count)
    return floor(count)
end

local function gridSnap(value)
    if value == 0 then return 0 end
    local unit = gridUnit
    if unit ~= unit or unit == huge or unit == -huge or unit <= 0 then
        return BUI.Round(value)
    end
    if unit == 1 then return value end
    local step = unit > 1 and unit or -unit
    return value - value % (value < 0 and step or -step)
end

Pixel.Scale = gridSnap
Pixel.Snap = gridSnap

function Pixel.ScaleEven(value)
    if value == 0 then return 0 end
    return unitsFor(wholePixels(pixelsFor(value) / 2) * 2)
end

function Pixel.ClampBorder(thickness)
    return max(1, wholePixels(thickness))
end

function Pixel.PixelSize(pixels)
    return unitsFor(Pixel.ClampBorder(pixels))
end

local function KillSnap(object)
    if type(object) ~= "table" or rawget(object, "_noSnap") then return end
    if object.IsForbidden and object:IsForbidden() then return end

    local target = object.SetSnapToPixelGrid and object or (object.GetStatusBarTexture and object:GetStatusBarTexture())
    if type(target) ~= "table" or not target.SetSnapToPixelGrid or rawget(target, "_noSnap") then return end

    target:SetSnapToPixelGrid(false)
    target:SetTexelSnappingBias(0)
    target._noSnap = true
end

local function RearmSnap(object, enabled)
    if not enabled then return end
    if type(object) ~= "table" or not rawget(object, "_noSnap") then return end
    if object.IsForbidden and object:IsForbidden() then return end
    object._noSnap = nil
end

local SNAP_HOOKS = {
    SetAtlas = KillSnap,
    SetColorTexture = KillSnap,
    SetSnapToPixelGrid = RearmSnap,
    SetStatusBarTexture = KillSnap,
    SetTexture = KillSnap,
}

local function HookSnapMethods(widget)
    local prototype = widget and getmetatable(widget)
    prototype = prototype and prototype.__index
    if type(prototype) ~= "table" or rawget(prototype, "_snapHooked") then return end
    prototype._snapHooked = true

    for method, handler in pairs(SNAP_HOOKS) do
        if prototype[method] then
            local key = "pixel#" .. method
            _G.hooksecurefunc(prototype, method, function(object, ...)
                Count(key)
                handler(object, ...)
            end)
        end
    end
end

local function GiveBackdrop(frame)
    if frame.SetBackdrop then return end
    for key, value in pairs(BackdropTemplateMixin) do
        if type(value) == "function" then
            frame[key] = value
        end
    end
    if frame.OnBackdropSizeChanged then
        HookScript(frame, "OnSizeChanged", frame.OnBackdropSizeChanged)
    end
end

local borderBackdrops = {}
local templateBackdrops = {}

local function GetBorderBackdrop(edge)
    local backdrop = borderBackdrops[edge]
    if not backdrop then
        backdrop = { edgeFile = FALLBACK_TEXTURE, edgeSize = edge }
        borderBackdrops[edge] = backdrop
    end
    return backdrop
end

local function GetTemplateBackdrop(edge)
    local backdrop = templateBackdrops[edge]
    if not backdrop then
        backdrop = { bgFile = FALLBACK_TEXTURE, edgeFile = FALLBACK_TEXTURE, edgeSize = edge }
        templateBackdrops[edge] = backdrop
    end
    return backdrop
end

function Pixel.SetTemplate(frame, backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha, borderRed, borderGreen, borderBlue, borderAlpha, borderSize, noScale)
    backgroundRed = backgroundRed or 0.1
    backgroundGreen = backgroundGreen or 0.1
    backgroundBlue = backgroundBlue or 0.1
    backgroundAlpha = backgroundAlpha or 0.8
    borderRed = borderRed or 0
    borderGreen = borderGreen or 0
    borderBlue = borderBlue or 0
    borderAlpha = borderAlpha or 1
    borderSize = borderSize or 1

    local edge = borderSize
    if not noScale then edge = Pixel.PixelSize(borderSize) end

    GiveBackdrop(frame)

    if frame._bdEdge ~= edge or not frame.backdropInfo then
        frame._bdEdge = edge
        frame:SetBackdrop(GetTemplateBackdrop(edge))
    end

    frame:SetBackdropColor(backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha)
    frame:SetBackdropBorderColor(borderRed, borderGreen, borderBlue, borderAlpha)
end

function Pixel.ApplyBorder(frame, thickness, red, green, blue, alpha)
    thickness = thickness or 1
    red = red or 0
    green = green or 0
    blue = blue or 0
    alpha = alpha or 1

    local edge = Pixel.PixelSize(thickness)

    GiveBackdrop(frame)

    if frame._bdEdge ~= edge or not frame.backdropInfo then
        frame._bdEdge = edge
        frame:SetBackdrop(GetBorderBackdrop(edge))
    end

    frame:SetBackdropBorderColor(red, green, blue, alpha)

    frame._edgeRGBA = frame._edgeRGBA or {}
    frame._edgeRGBA[1], frame._edgeRGBA[2], frame._edgeRGBA[3], frame._edgeRGBA[4] = red, green, blue, alpha
end

function Pixel.GetBorderSize(frame)
    return frame._bdEdge or Pixel.PixelSize(1)
end

function Pixel.SetBorderColor(frame, red, green, blue, alpha)
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(red, green, blue, alpha)
        if frame._edgeRGBA then
            frame._edgeRGBA[1], frame._edgeRGBA[2], frame._edgeRGBA[3], frame._edgeRGBA[4] = red, green, blue, alpha
        end
    end
end

function Pixel.HideBorder(frame)
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

function Pixel.ShowBorder(frame, red, green, blue, alpha)
    if not frame.SetBackdropBorderColor then return end

    if not red and frame._edgeRGBA then
        local color = frame._edgeRGBA
        red, green, blue, alpha = color[1], color[2], color[3], color[4]
    end

    frame:SetBackdropBorderColor(red or 0, green or 0, blue or 0, alpha or 1)
end

function Pixel.SetBackgroundColor(frame, red, green, blue, alpha)
    if frame.SetBackdropColor then
        frame:SetBackdropColor(red, green, blue, alpha)
    end
end

local fontRegistry = setmetatable({}, { __mode = 'k' })

function Pixel.ApplyFont(fontString, size, fontPath, flags)
    if not fontString then return end
    if type(size) ~= "number" or size <= 0 then return end

    local font = fontPath or BUI.GetGlobalFont()
    local outline = flags or BUI.GetFontOutline()
    local entry = fontRegistry[fontString]
    if entry then
        entry[1], entry[2], entry[3] = font, size, outline
    else
        fontRegistry[fontString] = { font, size, outline }
    end
    local applied = BUI.ApplySlug(outline)

    if not fontString:SetFont(font, size, applied) then
        fontString:SetFont(BUI.C.BLIZZARD_FONT, size, applied)
    end

    fontString:SetShadowColor(0, 0, 0, 0)
    fontString:SetShadowOffset(0, 0)
end

local function GrantSnapMixins(widget)
    local prototype = getmetatable(widget).__index
    if rawget(prototype, "SnapSize") then return end
    prototype.SnapSize = function(self, width, height)
        self:SetSize(gridSnap(width), gridSnap(height or width))
    end
    prototype.SnapPoint = function(self, point, arg2, arg3, arg4, arg5, ...)
        if not arg2 then arg2 = self:GetParent() end
        if type(arg2) == "number" then arg2 = gridSnap(arg2) end
        if type(arg3) == "number" then arg3 = gridSnap(arg3) end
        if type(arg4) == "number" then arg4 = gridSnap(arg4) end
        if type(arg5) == "number" then arg5 = gridSnap(arg5) end
        self:SetPoint(point, arg2, arg3, arg4, arg5, ...)
    end
end

local probeFrame = CreateFrame("Frame")
GrantSnapMixins(probeFrame)
GrantSnapMixins(CreateFrame("Button"))
GrantSnapMixins(CreateFrame("StatusBar"))
GrantSnapMixins(probeFrame:CreateTexture())
GrantSnapMixins(probeFrame:CreateMaskTexture())
GrantSnapMixins(probeFrame:CreateFontString())

HookSnapMethods(probeFrame)
HookSnapMethods(probeFrame:CreateTexture())
HookSnapMethods(probeFrame:CreateMaskTexture())
HookSnapMethods(probeFrame:CreateLine())
HookSnapMethods(CreateFrame("StatusBar"))

function BUI.RefreshAllFonts()
    for fontString, fontData in pairs(fontRegistry) do
        fontString:SetFont(fontData[1], fontData[2], BUI.ApplySlug(fontData[3]))
    end
end

local function OnScaleChanged()
    if Recompute() then
        Broadcast()
    end
end

local function OnGXRestarted()
    OnScaleChanged()
    BUI.Prof.After('Util.Pixel', 0, OnScaleChanged)
end

BUI.Events:Register('UI_SCALE_CHANGED', 'Pixel', OnScaleChanged)
BUI.Events:Register('DISPLAY_SIZE_CHANGED', 'Pixel', OnScaleChanged)
BUI.Events:Register('GX_RESTARTED', 'Pixel', OnGXRestarted)
hooksecurefunc(UIParent, "SetScale", OnScaleChanged)

Recompute()
