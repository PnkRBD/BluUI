local _, BUI = ...
local Pixel = BUI.Pixel

local CombatLogging = {}
BUI.CombatLogging = CombatLogging

local MODULE_KEY = 'CombatLogging'
local FRAME_NAME = 'BUI_CombatLogIndicator'

local DIFFICULTY_MYTHIC_KEYSTONE = 8
local DIFFICULTY_MYTHIC_DUNGEON  = 23
local DIFFICULTY_DELVE           = 208

local frame, labelText

local function GetConfig()
	return BUI.GetDB().combatLogging
end

local function DesiredLoggingState()
	local config = GetConfig()
	if not config.enabled then return false end
	local _, instanceType, difficultyID = GetInstanceInfo()
	if instanceType == 'raid' then return config.raids == true end
	if instanceType == 'party' then
		if difficultyID == DIFFICULTY_MYTHIC_KEYSTONE or difficultyID == DIFFICULTY_MYTHIC_DUNGEON then
			return config.mythicPlus == true
		end
		return config.otherDungeons == true
	end
	if instanceType == 'arena' then return config.arenas == true end
	if instanceType == 'pvp' then return config.battlegrounds == true end
	if instanceType == 'scenario' then
		return difficultyID == DIFFICULTY_DELVE and config.delves == true
	end
	return false
end

local function DescribeLocation()
	local name, _, _, difficultyName = GetInstanceInfo()
	if difficultyName ~= '' then
		return name .. ' - ' .. difficultyName
	end
	return name
end

local function Announce(active)
	local config = GetConfig()
	if not config.chatMessage then return end
	if active then
		BUI.Print('Combat logging |cff40ff40ON|r (' .. DescribeLocation() .. ')')
	else
		BUI.Print('Combat logging |cffff4040OFF|r')
	end
end

local function BuildFrame()
	local BUILib = BluUI.BUILibClient

	frame = CreateFrame('Frame', FRAME_NAME, UIParent)
	frame:SetFrameStrata('MEDIUM')
	frame:SetFrameLevel(10)
	frame:SetClampedToScreen(true)
	frame:Hide()

	local dotHolder = CreateFrame('Frame', nil, frame)
	dotHolder:SetSize(Pixel.Scale(12), Pixel.Scale(12))
	dotHolder:SetPoint('LEFT', frame, 'LEFT', 0, 0)

	local dotTexture = dotHolder:CreateTexture(nil, 'ARTWORK')
	dotTexture:SetTexture(BUILib.GetLibMedia('round6'))
	dotTexture:SetVertexColor(1, 0.25, 0.25, 1)
	dotTexture:SetAllPoints(dotHolder)

	local dotBorder = dotHolder:CreateTexture(nil, 'ARTWORK', nil, 1)
	dotBorder:SetTexture(BUILib.GetLibMedia('outline6'))
	dotBorder:SetVertexColor(0, 0, 0, 1)
	dotBorder:SetAllPoints(dotHolder)

	local pulse = dotHolder:CreateAnimationGroup()
	pulse:SetLooping('BOUNCE')
	local fade = pulse:CreateAnimation('Alpha')
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.1)
	fade:SetDuration(0.55)
	pulse:Play()

	labelText = frame:CreateFontString(nil, 'OVERLAY')
	labelText:SetPoint('LEFT', dotHolder, 'RIGHT', Pixel.Scale(5), 0)

	BUI.Dragging.MakeDraggable(frame, {
		showHint = true,
		showUnlockedBg = true,
		isLocked = function() return not GetConfig().showAnchor end,
		onRightClick = function()
			GetConfig().showAnchor = false
			CombatLogging.Refresh()
		end,
		onPositionChanged = function(x, y)
			local config = GetConfig()
			config.posX, config.posY = x, y
		end,
	})
end

local function ApplyStyle()
	Pixel.ApplyFont(labelText, 13, BUI.GetGlobalFont(), BUI.GetFontOutline())
	labelText:SetText('LIVE')
	labelText:SetTextColor(1, 1, 1, 1)
	local width = Pixel.Scale(12) + Pixel.Scale(5) + labelText:GetStringWidth()
	frame:SetSize(width, Pixel.Scale(16))
end

local function ApplyPosition()
	local config = GetConfig()
	frame:ClearAllPoints()
	frame:SetPoint('CENTER', UIParent, 'CENTER', config.posX, config.posY)
end

local function ShouldShowIndicator()
	local config = GetConfig()
	return config.showAnchor or (config.showIndicator and LoggingCombat())
end

local function UpdateIndicator()
	if not ShouldShowIndicator() then
		if frame then frame:Hide() end
		return
	end
	if not frame then
		BuildFrame()
		ApplyStyle()
		ApplyPosition()
	end
	frame:Show()
end

local announcedState

local function EnsureAdvancedLogging()
	if not GetConfig().advancedLogging then return end
	if C_CVar.GetCVarBool('advancedCombatLogging') then return end
	C_CVar.SetCVar('advancedCombatLogging', '1')
end

local function ApplyLoggingState()
	local config = GetConfig()
	if config.enabled then
		local desired = DesiredLoggingState()
		local active = LoggingCombat()
		if desired and not active then
			EnsureAdvancedLogging()
			LoggingCombat(true)
			if announcedState ~= true then
				announcedState = true
				Announce(true)
			end
		elseif not desired and active then
			LoggingCombat(false)
			if announcedState ~= false then
				announcedState = false
				Announce(false)
			end
		else
			if desired then EnsureAdvancedLogging() end
			announcedState = desired
		end
	end
	UpdateIndicator()
end

function CombatLogging.Refresh()
	if frame then
		ApplyStyle()
		ApplyPosition()
		frame:RefreshDragState()
	end
	BUI.Scheduler.SetUpdateEnabled(MODULE_KEY, GetConfig().showIndicator)
	ApplyLoggingState()
end

function CombatLogging.ToggleAnchor()
	local config = GetConfig()
	config.showAnchor = not config.showAnchor
	CombatLogging.Refresh()
end

local queueApply = BUI.Dispatcher.New(ApplyLoggingState)

local function Initialize()
	BUI.Scheduler.RegisterUpdate(MODULE_KEY, UpdateIndicator, 2, GetConfig().showIndicator)
	CombatLogging.Refresh()
end

BUI.Events:OnLogin('CombatLogging', Initialize)
BUI.Events:Register('PLAYER_ENTERING_WORLD',     'CombatLogging', queueApply)
BUI.Events:Register('ZONE_CHANGED_NEW_AREA',     'CombatLogging', queueApply)
BUI.Events:Register('UPDATE_INSTANCE_INFO',      'CombatLogging', queueApply)
BUI.Events:Register('CHALLENGE_MODE_START',      'CombatLogging', queueApply)
BUI.Events:Register('PLAYER_DIFFICULTY_CHANGED', 'CombatLogging', queueApply)
