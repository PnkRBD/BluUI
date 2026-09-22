local _, BUI = ...

local ActionBars = BUI.ActionBars
local LibActionButton = LibStub('LibActionButton-1.0-BluUI')

local GLOW_KEY = '_BUIProc'
local GLOW_LAYER = 12
local PROC_GLOW_FIELD = '_ProcGlow' .. GLOW_KEY
local EVENT_KEY = 'ActionBars.ProcGlow'

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
	local frame = button[PROC_GLOW_FIELD]
	if not frame then return end
	local color = GlowColor()
	TintTexture(frame.ProcStart, color)
	TintTexture(frame.ProcLoop, color)
end

local GlowManager = BUI.GlowManager

local function ShowGlow(button)
	if button._buiProcGlow then return end
	local settings = ActionBars.GetSettings()
	local style = settings.procGlowStyle
	if not GlowManager.STYLES[style] then style = 'proc' end
	button._buiProcGlow = style
	local lines = settings.procGlowLines
	local length
	if style == 'pixel' then
		local width, height = button:GetSize()
		length = GlowManager.PixelLength(width, height, lines)
	elseif style == 'autocast' then
		lines = math.max(1, math.floor(lines / 2))
	end
	GlowManager.Start(button, style, settings.procGlowColor, settings.procGlowSpeed, lines, settings.procGlowThickness, GLOW_KEY, GLOW_LAYER, length, true)
	if style == 'proc' then TintGlow(button) end
	local libraryOverlay = button.__LBGoverlay
	if libraryOverlay then libraryOverlay:Hide() end
end

local function HideGlow(button)
	local style = button._buiProcGlow
	if not style then return end
	button._buiProcGlow = nil
	GlowManager.Stop(button, style, GLOW_KEY)
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
