local _, BUI = ...

local ActionBars = BUI.ActionBars
local LibActionButton = LibStub('LibActionButton-1.0-BluUI')
local LibCustomGlow = LibStub('LibCustomGlow-1.0')

local GLOW_KEY = '_BUIProc'
local GLOW_LAYER = 12
local EVENT_KEY = 'ActionBars.ProcGlow'

local glowOptions = { key = GLOW_KEY, frameLevel = GLOW_LAYER, startAnim = true, duration = 1 }
local glowOwner = {}
local IsSpellOverlayed = C_SpellActivationOverlay.IsSpellOverlayed
local Plain = ActionBars.Plain

local function GlowEnabled()
	return BUI.IsModuleEnabled('actionBars') and ActionBars.GetSettings().procGlow
end

local function GlowColor()
	return ActionBars.GetSettings().procGlowColor
end

local function TintTexture(texture, color)
	if not texture then return end
	texture:SetDesaturated(true)
	texture:SetVertexColor(color[1], color[2], color[3], 1)
end

local function TintGlow(button)
	local frame = button['_ProcGlow' .. GLOW_KEY]
	if not frame then return end
	local color = GlowColor()
	TintTexture(frame.ProcStart, color)
	TintTexture(frame.ProcLoop, color)
end

local function SpeedMultiplier(speed)
	local multiplier = speed / 100
	if multiplier < 0.01 then multiplier = 0.01 end
	return multiplier
end

local function PixelLength(button, lineCount)
	local width, height = button:GetSize()
	if not width or not height or width < 1 or height < 1 then return nil end
	return math.min(math.floor((width + height) * (2 / lineCount - 0.1)), math.min(width, height))
end

local function StartProc(button, settings)
	glowOptions.duration = 1 / SpeedMultiplier(settings.procGlowSpeed)
	LibCustomGlow.ProcGlow_Start(button, glowOptions)
	TintGlow(button)
end

local function StartPixel(button, settings)
	local lineCount = settings.procGlowLines
	LibCustomGlow.PixelGlow_Start(button, settings.procGlowColor, lineCount, SpeedMultiplier(settings.procGlowSpeed) * 0.25,
		PixelLength(button, lineCount), settings.procGlowThickness, 0, 0, false, GLOW_KEY, button:GetFrameLevel() + GLOW_LAYER)
end

local function StartAutoCast(button, settings)
	LibCustomGlow.AutoCastGlow_Start(button, settings.procGlowColor, math.max(1, math.floor(settings.procGlowLines / 2)),
		SpeedMultiplier(settings.procGlowSpeed) * 0.125, 1, 0, 0, GLOW_KEY, button:GetFrameLevel() + GLOW_LAYER)
end

local function StartButton(button, settings)
	local speed = settings.procGlowSpeed
	local frequency = speed ~= 100 and SpeedMultiplier(speed) or nil
	LibCustomGlow.ButtonGlow_Start(button, settings.procGlowColor, frequency, button:GetFrameLevel() + GLOW_LAYER)
end

local StartByStyle = {
	proc     = StartProc,
	pixel    = StartPixel,
	autocast = StartAutoCast,
	button   = StartButton,
}

local StopByStyle = {
	proc     = function(button) LibCustomGlow.ProcGlow_Stop(button, GLOW_KEY) end,
	pixel    = function(button) LibCustomGlow.PixelGlow_Stop(button, GLOW_KEY) end,
	autocast = function(button) LibCustomGlow.AutoCastGlow_Stop(button, GLOW_KEY) end,
	button   = function(button) LibCustomGlow.ButtonGlow_Stop(button) end,
}

local function ShowGlow(button)
	if button._buiProcGlow then return end
	local settings = ActionBars.GetSettings()
	local style = StartByStyle[settings.procGlowStyle] and settings.procGlowStyle or 'proc'
	button._buiProcGlow = style
	StartByStyle[style](button, settings)
	local libraryOverlay = button.__LBGoverlay
	if libraryOverlay then libraryOverlay:Hide() end
end

local function HideGlow(button)
	local style = button._buiProcGlow
	if not style then return end
	button._buiProcGlow = nil
	StopByStyle[style](button)
end

local function SpellOverlayed(spellID)
	spellID = Plain(spellID)
	if not spellID then return false end
	return Plain(IsSpellOverlayed(spellID)) == true
end

local function ButtonOverlayed(button)
	if SpellOverlayed(button:GetSpellId()) then return true end
	if button._state_type ~= 'action' or not button._state_action then return false end
	local actionType, actionID = GetActionInfo(button._state_action)
	if actionType ~= 'flyout' or not actionID then return false end
	local _, _, slotCount = GetFlyoutInfo(actionID)
	for slotIndex = 1, (slotCount or 0) do
		local flyoutSpellID = GetFlyoutSlotInfo(actionID, slotIndex)
		if SpellOverlayed(flyoutSpellID) then return true end
	end
	return false
end

function ActionBars.SyncProcGlow(button)
	if not GlowEnabled() then
		HideGlow(button)
		return
	end
	if ButtonOverlayed(button) then ShowGlow(button) else HideGlow(button) end
end

local function SyncAllProcGlow()
	ActionBars.ForEachButton(ActionBars.SyncProcGlow)
end

function ActionBars.RefreshProcGlow()
	ActionBars.ForEachButton(HideGlow)
	SyncAllProcGlow()
end

local QueueSync = BUI.Dispatcher.New(SyncAllProcGlow, EVENT_KEY)

BUI.Events:Register('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', EVENT_KEY .. '.Show', QueueSync)
BUI.Events:Register('SPELL_ACTIVATION_OVERLAY_GLOW_HIDE', EVENT_KEY .. '.Hide', QueueSync)

LibActionButton.RegisterCallback(glowOwner, 'OnButtonUpdate', function(_, button)
	if not button._buiBar then return end
	ActionBars.SyncProcGlow(button)
end)
