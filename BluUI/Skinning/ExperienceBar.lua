local _, BUI = ...

local floor, format, max, min = math.floor, string.format, math.max, math.min
local GetTime = GetTime

local Pixel = BUI.Pixel
local Skin = BUI.Skinning
local Dragging = BUI.Dragging
local BLANK = BUI.C.FALLBACK_TEXTURE

local STAT_KEYS = { 'timeLevel', 'timeSession', 'levelingIn', 'completed' }
local XP_EVENTS = { 'PLAYER_XP_UPDATE', 'PLAYER_LEVEL_UP', 'UPDATE_EXHAUSTION', 'UPDATE_FACTION', 'PLAYER_ENTERING_WORLD', 'TIME_PLAYED_MSG' }
local BLIZZARD_CONTAINERS = { MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }
local RENOWN_COLOR = { 0, 0.68, 0.94 }
local PARAGON_COLOR = { 0, 0.75, 0.44 }

local context = Skin.Define('experiencebar', {
	name = 'Experience Bar',
	description = 'Replaces the Blizzard status tracking bars with a minimal dark bar. Supports edge anchoring and free drag positioning.',
	icon = 'Interface\\Icons\\Achievement_Level_80',
})
local Hook, Enabled = context.Hook, context.Enabled

local barFrame, xpBar, restedBar, reputationBar, xpText, reputationText
local reputationEdgeTexture, reputationBackground
local statLabels = {}
local hoverTicker

local sessionOnlineTime = 0
local sessionLoginTime = 0
local sessionXPGained = 0
local lastKnownXP = 0
local lastKnownMax = 0
local levelPlayedSeconds = 0
local levelPlayedBaseTime = 0
local levelPlayedReceived = false
local suppressNextPlayed = false

local DisplayTimePlayed = ChatFrameUtil.DisplayTimePlayed
function ChatFrameUtil.DisplayTimePlayed(...)
	if suppressNextPlayed then
		suppressNextPlayed = false
		return
	end
	return DisplayTimePlayed(...)
end

local function IsAtMaxLevel()
	return GameRulesUtil.IsPlayerAtEffectiveMaxLevel()
end

local function GetSessionTime()
	if sessionLoginTime == 0 then return 0 end
	return sessionOnlineTime + (time() - sessionLoginTime)
end

local function GetConfig()
	return BUI.GetDB().skinning.experiencebarSettings
end

local function Placing()
	local config = GetConfig()
	return config.position == 'FREE' and not config.locked
end

local function IsVertical(position)
	return position == 'LEFT' or position == 'RIGHT'
end

local function ApplyBarPosition()
	local config = GetConfig()
	local position = config.position

	barFrame:ClearAllPoints()

	if position == 'BOTTOM' then
		if config.fullWidth then
			barFrame:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT')
			barFrame:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT')
		else
			barFrame:SetWidth(config.barWidth)
			BUI.Anchor.PlaceOnPixels(barFrame, 'BOTTOM', UIParent, 'BOTTOM', 0, 0)
		end
	elseif position == 'TOP' then
		if config.fullWidth then
			barFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT')
			barFrame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT')
		else
			barFrame:SetWidth(config.barWidth)
			BUI.Anchor.PlaceOnPixels(barFrame, 'TOP', UIParent, 'TOP', 0, 0)
		end
	elseif position == 'LEFT' then
		barFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT')
		barFrame:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT')
	elseif position == 'RIGHT' then
		barFrame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT')
		barFrame:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT')
	elseif position == 'FREE' then
		barFrame:SetWidth(config.barWidth)
		BUI.Anchor.PlaceOnPixels(barFrame, 'CENTER', UIParent, 'CENTER', config.posX, config.posY)
	end

	Dragging.SetLocked(barFrame, position ~= 'FREE' or config.locked)
end

local function SaveSession()
	local char = BUI.db.char
	char.xpSessionOnline = GetSessionTime()
	char.xpSessionGained = sessionXPGained
end

local function InitSession()
	if sessionLoginTime > 0 then return end
	sessionLoginTime = time()
	local char = BUI.db.char
	if char.xpSessionOnline then
		sessionOnlineTime = char.xpSessionOnline
		sessionXPGained = char.xpSessionGained
	end
	lastKnownXP = UnitXP('player')
	lastKnownMax = UnitXPMax('player')
	SaveSession()
	suppressNextPlayed = true
	RequestTimePlayed()
end

local function ShortNumber(number)
	if number >= 1e6 then return format('%.2fM', number / 1e6) end
	if number >= 1e4 then return format('%.1fK', number / 1e3) end
	return format('%d', number)
end

local function FormatTime(seconds)
	if seconds < 60 then return format('%ds', seconds) end
	local minutes = floor(seconds / 60)
	if minutes < 60 then return format('%dm', minutes) end
	local hours = floor(minutes / 60)
	minutes = minutes - hours * 60
	if minutes > 0 then return format('%dh %dm', hours, minutes) end
	return format('%dh', hours)
end

local function GetXPColor()
	local config = GetConfig()
	return config.xpColor[1], config.xpColor[2], config.xpColor[3]
end

local function HasReputation()
	return C_Reputation.GetWatchedFactionData() ~= nil
end

local function HideHoverStats()
	for _, label in pairs(statLabels) do label:Hide() end
end

local function UpdateHoverStats()
	if IsAtMaxLevel() then
		HideHoverStats()
		return
	end

	local currentXP = UnitXP('player')
	local xpMax = max(1, UnitXPMax('player'))

	if levelPlayedReceived then
		statLabels.timeLevel:SetFormattedText('Time this level: %s', FormatTime(levelPlayedSeconds + GetTime() - levelPlayedBaseTime))
	else
		statLabels.timeLevel:SetText('Time this level: ...')
	end
	statLabels.timeLevel:Show()

	local sessionTime = GetSessionTime()
	statLabels.timeSession:SetFormattedText('Time this session: %s', FormatTime(sessionTime))
	statLabels.timeSession:Show()

	local xpPerHour = (sessionTime > 120 and sessionXPGained > 0) and (sessionXPGained / sessionTime * 3600) or 0
	local remaining = xpMax - currentXP
	if xpPerHour > 0 and remaining > 0 then
		statLabels.levelingIn:SetFormattedText('Leveling in: %s (%s remaining | %s XP/Hour)',
			FormatTime(remaining / xpPerHour * 3600), ShortNumber(remaining), ShortNumber(xpPerHour))
	else
		statLabels.levelingIn:SetText('Leveling in: --')
	end
	statLabels.levelingIn:Show()

	local percent = floor(currentXP / xpMax * 100)
	local rested = GetXPExhaustion() or 0
	local restedPercent = floor(rested / xpMax * 100)
	if restedPercent > 0 then
		statLabels.completed:SetFormattedText('Completed: |cff00ff80%d%%|r - Rested: |cff4488ff%d%%|r', percent, restedPercent)
	else
		statLabels.completed:SetFormattedText('Completed: |cff00ff80%d%%|r - Rested: 0%%', percent)
	end
	statLabels.completed:Show()
end

local function UpdateXP()
	local config = GetConfig()
	if IsAtMaxLevel() then
		xpBar:Hide()
		restedBar:Hide()
		xpText:SetText('')
		return
	end

	local currentXP = UnitXP('player')
	local xpMax = max(1, UnitXPMax('player'))

	xpBar:Show()
	xpBar:SetMinMaxValues(0, xpMax)
	xpBar:SetValue(currentXP)

	local rested = GetXPExhaustion() or 0
	if rested > 0 and config.showRestedXP then
		restedBar:Show()
		restedBar:SetMinMaxValues(0, xpMax)
		restedBar:SetValue(min(currentXP + rested, xpMax))
	else
		restedBar:Hide()
	end

	local percent = floor(currentXP / xpMax * 100)
	local restedString = ''
	if rested > 0 and config.showRestedXP then
		restedString = format(' (|cff4488ff%.1f%% rested|r)', floor(rested / xpMax * 1000 + 0.5) / 10)
	end
	xpText:SetFormattedText('Lv %d   %s / %s (%s)   %d%%%s',
		UnitLevel('player'), ShortNumber(currentXP), ShortNumber(xpMax),
		ShortNumber(xpMax - currentXP), percent, restedString)
end

local function ParagonProgress(factionID, name)
	if not C_Reputation.IsFactionParagon(factionID) then return end
	local paragonValue, paragonThreshold, _, hasReward = C_Reputation.GetFactionParagonInfo(factionID)
	if paragonThreshold <= 0 then return end
	local suffix = hasReward and ' |cff00ff00Reward!|r' or ''
	return 0, paragonThreshold, paragonValue % paragonThreshold, format('%s  Paragon%s', name, suffix), PARAGON_COLOR[1], PARAGON_COLOR[2], PARAGON_COLOR[3]
end

local function GetReputationProgress(data)
	local factionID, name = data.factionID, data.name

	if C_Reputation.IsMajorFaction(factionID) then
		local majorData = C_MajorFactions.GetMajorFactionData(factionID)
		if majorData then
			local threshold = majorData.renownLevelThreshold
			local label = format('%s  Renown %d', name, majorData.renownLevel)
			if threshold > 0 then
				return 0, threshold, majorData.renownReputationEarned, label, RENOWN_COLOR[1], RENOWN_COLOR[2], RENOWN_COLOR[3]
			end
			local barMin, barMax, barCurrent, paragonLabel, red, green, blue = ParagonProgress(factionID, name)
			if barMax then return barMin, barMax, barCurrent, paragonLabel, red, green, blue end
			return 0, 1, 1, label .. '  (Max)', RENOWN_COLOR[1], RENOWN_COLOR[2], RENOWN_COLOR[3]
		end
	end

	local barMin, barMax, barCurrent, label, red, green, blue = ParagonProgress(factionID, name)
	if barMax then return barMin, barMax, barCurrent, label, red, green, blue end

	local friendData = C_GossipInfo.GetFriendshipReputation(factionID)
	if friendData.friendshipFactionID > 0 then
		local friendMax = friendData.nextThreshold or 0
		if friendMax > 0 then
			return friendData.reactionThreshold, friendMax, friendData.standing
		end
		return 0, 1, 1, name .. '  (Max)'
	end

	return data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
end

local function UpdateReputation()
	local data = C_Reputation.GetWatchedFactionData()
	if not data then
		reputationBar:Hide()
		reputationText:SetText('')
		return
	end

	local barMin, barMax, barCurrent, label, red, green, blue = GetReputationProgress(data)
	local rangeMax = max(1, barMax - barMin)
	local rangeCurrent = max(0, min(barCurrent - barMin, rangeMax))

	reputationBar:Show()
	reputationBar:SetMinMaxValues(0, rangeMax)
	reputationBar:SetValue(rangeCurrent)

	if not red then
		local colors = FACTION_BAR_COLORS[data.reaction]
		red, green, blue = colors.r, colors.g, colors.b
	end
	reputationBar:SetStatusBarColor(red, green, blue)

	reputationText:SetFormattedText('%s  %s / %s  (%d%%)',
		label or data.name, ShortNumber(rangeCurrent), ShortNumber(rangeMax), floor(rangeCurrent / rangeMax * 100))
end

local function UpdateAll()
	UpdateXP()
	UpdateReputation()
end

local function LayoutStatLabels()
	local position = GetConfig().position
	local vertical = IsVertical(position)
	local pad = 6

	for _, label in pairs(statLabels) do label:ClearAllPoints() end

	if vertical then
		for _, label in pairs(statLabels) do label:SetJustifyH('LEFT') end

		local xDir = (position == 'LEFT') and 1 or -1
		local anchor = (position == 'LEFT') and 'TOPLEFT' or 'TOPRIGHT'
		local barAnchor = (position == 'LEFT') and 'TOPRIGHT' or 'TOPLEFT'
		statLabels.timeLevel  :SetPoint(anchor, barFrame, barAnchor, Pixel.Scale(xDir * pad), Pixel.Scale(-pad))
		statLabels.timeSession:SetPoint('TOPLEFT', statLabels.timeLevel,   'BOTTOMLEFT', 0, Pixel.Scale(-4))
		statLabels.levelingIn :SetPoint('TOPLEFT', statLabels.timeSession, 'BOTTOMLEFT', 0, Pixel.Scale(-4))
		statLabels.completed  :SetPoint('TOPLEFT', statLabels.levelingIn,  'BOTTOMLEFT', 0, Pixel.Scale(-4))
	else
		statLabels.timeLevel  :SetJustifyH('LEFT')
		statLabels.timeSession:SetJustifyH('RIGHT')
		statLabels.levelingIn :SetJustifyH('LEFT')
		statLabels.completed  :SetJustifyH('RIGHT')

		if position == 'BOTTOM' then
			statLabels.timeLevel  :SetPoint('BOTTOMLEFT',  barFrame, 'TOPLEFT',  Pixel.Scale(8), Pixel.Scale(pad))
			statLabels.timeSession:SetPoint('BOTTOMRIGHT', barFrame, 'TOPRIGHT', Pixel.Scale(-8), Pixel.Scale(pad))
			statLabels.levelingIn :SetPoint('BOTTOMLEFT',  statLabels.timeLevel,   'TOPLEFT',  0, Pixel.Scale(4))
			statLabels.completed  :SetPoint('BOTTOMRIGHT', statLabels.timeSession, 'TOPRIGHT', 0, Pixel.Scale(4))
		elseif position == 'TOP' then
			statLabels.timeLevel  :SetPoint('TOPLEFT',  barFrame, 'BOTTOMLEFT',  Pixel.Scale(8), Pixel.Scale(-pad))
			statLabels.timeSession:SetPoint('TOPRIGHT', barFrame, 'BOTTOMRIGHT', Pixel.Scale(-8), Pixel.Scale(-pad))
			statLabels.levelingIn :SetPoint('TOPLEFT',  statLabels.timeLevel,   'BOTTOMLEFT',  0, Pixel.Scale(-4))
			statLabels.completed  :SetPoint('TOPRIGHT', statLabels.timeSession, 'BOTTOMRIGHT', 0, Pixel.Scale(-4))
		else
			statLabels.timeLevel  :SetPoint('BOTTOMLEFT',  barFrame, 'TOPLEFT',     Pixel.Scale(8), Pixel.Scale(pad))
			statLabels.timeSession:SetPoint('BOTTOMRIGHT', barFrame, 'TOPRIGHT',    Pixel.Scale(-8), Pixel.Scale(pad))
			statLabels.levelingIn :SetPoint('TOPLEFT',     barFrame, 'BOTTOMLEFT',  Pixel.Scale(8), Pixel.Scale(-pad))
			statLabels.completed  :SetPoint('TOPRIGHT',    barFrame, 'BOTTOMRIGHT', Pixel.Scale(-8), Pixel.Scale(-pad))
		end
	end
end

local function LayoutBars()
	local config = GetConfig()
	local barHeight = config.barHeight
	local vertical = IsVertical(config.position)
	local atMax = IsAtMaxLevel()
	local hasReputation = HasReputation()
	local scaledEdge = Pixel.PixelSize(1)

	xpBar:ClearAllPoints()
	restedBar:ClearAllPoints()
	reputationBar:ClearAllPoints()

	local orientation = vertical and 'VERTICAL' or 'HORIZONTAL'
	xpBar:SetOrientation(orientation)
	restedBar:SetOrientation(orientation)
	reputationBar:SetOrientation(orientation)

	local showDivider = hasReputation and not atMax

	if vertical then
		local totalWidth = 0

		if not atMax then
			xpBar:SetPoint('TOPLEFT', barFrame, 'TOPLEFT', scaledEdge, -scaledEdge)
			xpBar:SetPoint('BOTTOMLEFT', barFrame, 'BOTTOMLEFT', scaledEdge, scaledEdge)
			xpBar:SetWidth(barHeight)
			restedBar:SetPoint('TOPLEFT', xpBar)
			restedBar:SetPoint('BOTTOMLEFT', xpBar)
			restedBar:SetWidth(barHeight)
			totalWidth = barHeight
		end

		if hasReputation then
			if atMax then
				reputationBar:SetPoint('TOPLEFT', barFrame, 'TOPLEFT', scaledEdge, -scaledEdge)
				reputationBar:SetPoint('BOTTOMLEFT', barFrame, 'BOTTOMLEFT', scaledEdge, scaledEdge)
			else
				reputationBar:SetPoint('TOPLEFT', xpBar, 'TOPRIGHT', scaledEdge, 0)
				reputationBar:SetPoint('BOTTOMLEFT', xpBar, 'BOTTOMRIGHT', scaledEdge, 0)
			end
			reputationBar:SetWidth(barHeight)
			totalWidth = totalWidth + barHeight + (atMax and 0 or scaledEdge)
		end

		if showDivider then
			reputationEdgeTexture:ClearAllPoints()
			reputationEdgeTexture:SetPoint('TOPLEFT', reputationBar, 'TOPLEFT')
			reputationEdgeTexture:SetPoint('BOTTOMLEFT', reputationBar, 'BOTTOMLEFT')
			reputationEdgeTexture:SetWidth(scaledEdge)
			reputationEdgeTexture:SetHeight(0)
			reputationEdgeTexture:Show()
		else
			reputationEdgeTexture:Hide()
		end

		if totalWidth == 0 and not Placing() then
			barFrame:Hide()
		else
			barFrame:SetWidth(max(totalWidth, barHeight) + scaledEdge * 2)
			barFrame:Show()
		end
	else
		local totalHeight = 0

		if not atMax then
			xpBar:SetPoint('TOPLEFT', barFrame, 'TOPLEFT', scaledEdge, -scaledEdge)
			xpBar:SetPoint('TOPRIGHT', barFrame, 'TOPRIGHT', -scaledEdge, -scaledEdge)
			xpBar:SetHeight(barHeight)
			restedBar:SetPoint('TOPLEFT', xpBar)
			restedBar:SetPoint('TOPRIGHT', xpBar)
			restedBar:SetHeight(barHeight)
			totalHeight = barHeight
		end

		if hasReputation then
			if atMax then
				reputationBar:SetPoint('TOPLEFT', barFrame, 'TOPLEFT', scaledEdge, -scaledEdge)
				reputationBar:SetPoint('TOPRIGHT', barFrame, 'TOPRIGHT', -scaledEdge, -scaledEdge)
			else
				reputationBar:SetPoint('TOPLEFT', xpBar, 'BOTTOMLEFT', 0, -scaledEdge)
				reputationBar:SetPoint('TOPRIGHT', xpBar, 'BOTTOMRIGHT', 0, -scaledEdge)
			end
			reputationBar:SetHeight(barHeight)
			totalHeight = totalHeight + barHeight + (atMax and 0 or scaledEdge)
		end

		if showDivider then
			reputationEdgeTexture:ClearAllPoints()
			reputationEdgeTexture:SetPoint('TOPLEFT', reputationBar, 'TOPLEFT')
			reputationEdgeTexture:SetPoint('TOPRIGHT', reputationBar, 'TOPRIGHT')
			reputationEdgeTexture:SetHeight(scaledEdge)
			reputationEdgeTexture:SetWidth(0)
			reputationEdgeTexture:Show()
		else
			reputationEdgeTexture:Hide()
		end

		if totalHeight == 0 and not Placing() then
			barFrame:Hide()
		else
			barFrame:SetHeight(max(totalHeight, barHeight) + scaledEdge * 2)
			barFrame:Show()
		end
	end

	LayoutStatLabels()
end

local function ApplySettings()
	if not Enabled() then return end
	local config = GetConfig()
	local red, green, blue = GetXPColor()
	xpBar:SetStatusBarColor(red, green, blue, 0.85)

	local restedColor = config.restedColor
	restedBar:SetStatusBarColor(restedColor[1], restedColor[2], restedColor[3], 0.5)

	local backgroundAlpha = config.bgOpacity / 100
	BUI.Tools.SetColorTex(barFrame.FrameBG, 0.05, 0.05, 0.05, backgroundAlpha)
	reputationBackground:SetColorTexture(0.05, 0.05, 0.05, backgroundAlpha)

	local font = BUI.GetGlobalFont()
	Pixel.ApplyFont(xpText, config.fontSize, font, 'OUTLINE')
	Pixel.ApplyFont(reputationText, config.fontSize, font, 'OUTLINE')

	local statSize = max(config.fontSize, 10)
	for _, label in pairs(statLabels) do
		Pixel.ApplyFont(label, statSize, font, 'OUTLINE')
	end

	ApplyBarPosition()
	LayoutBars()
	UpdateAll()
end

local function HoldAlpha(frame, alpha)
	if alpha == 0 or frame._buiReasserting then return end
	frame._buiReasserting = true
	frame:SetAlpha(0)
	frame._buiReasserting = nil
end

local function InstallBar(frame)
	Hook(frame, 'SetAlpha', HoldAlpha)
end

local function RestoreBlizzard()
	Skin.RestoreBlizzardFrame(StatusTrackingBarManager)
	StatusTrackingBarManager:UpdateBarsShown()
	for _, frame in ipairs(BLIZZARD_CONTAINERS) do
		Skin.RestoreBlizzardFrame(frame)
		frame:ApplySystemAnchor()
	end
end

local RefreshFaction = BUI.Dispatcher.New(function()
	if not Enabled() then return end
	LayoutBars()
	ApplyBarPosition()
	UpdateAll()
end, 'Skin.ExperienceBar.Faction')

local function CreateBars()
	if barFrame then return end
	local config = GetConfig()

	barFrame = CreateFrame('Frame', 'BUI_ExperienceBar', UIParent)
	local edge = Pixel.PixelSize(1)
	barFrame:SetHeight(config.barHeight + edge * 2)
	barFrame:SetFrameStrata('MEDIUM')
	barFrame:SetFrameLevel(5)

	local background = barFrame:CreateTexture(nil, 'BACKGROUND')
	background:SetPoint('TOPLEFT', edge, -edge)
	background:SetPoint('BOTTOMRIGHT', -edge, edge)
	BUI.Tools.SetColorTex(background, 0.05, 0.05, 0.05, config.bgOpacity / 100)
	barFrame.FrameBG = background

	Pixel.ApplyBorder(barFrame, 1, 0, 0, 0, 1)

	restedBar = CreateFrame('StatusBar', nil, barFrame)
	restedBar:SetStatusBarTexture(BLANK)
	restedBar:SetFrameLevel(barFrame:GetFrameLevel() + 1)
	restedBar:Hide()

	xpBar = CreateFrame('StatusBar', nil, barFrame)
	xpBar:SetStatusBarTexture(BLANK)
	xpBar:SetFrameLevel(barFrame:GetFrameLevel() + 2)

	reputationBar = CreateFrame('StatusBar', nil, barFrame)
	reputationBar:SetStatusBarTexture(BLANK)
	reputationBar:SetStatusBarColor(0.6, 0.6, 0.6)
	reputationBar:SetFrameLevel(barFrame:GetFrameLevel() + 2)
	reputationBar:Hide()

	reputationBackground = reputationBar:CreateTexture(nil, 'BACKGROUND')
	reputationBackground:SetAllPoints()
	reputationBackground:SetColorTexture(0.05, 0.05, 0.05, config.bgOpacity / 100)

	reputationEdgeTexture = reputationBar:CreateTexture(nil, 'OVERLAY')
	reputationEdgeTexture:SetHeight(Pixel.PixelSize(1))
	reputationEdgeTexture:SetPoint('TOPLEFT')
	reputationEdgeTexture:SetPoint('TOPRIGHT')
	reputationEdgeTexture:SetColorTexture(0, 0, 0, 1)

	xpText = xpBar:CreateFontString(nil, 'OVERLAY')
	xpText:SetPoint('CENTER')
	xpText:SetTextColor(1, 1, 1, 1)
	xpText:Hide()

	reputationText = reputationBar:CreateFontString(nil, 'OVERLAY')
	reputationText:SetPoint('CENTER')
	reputationText:SetTextColor(1, 1, 1, 1)
	reputationText:Hide()

	local font = BUI.GetGlobalFont()
	local statSize = max(config.fontSize, 10)
	for _, key in ipairs(STAT_KEYS) do
		local label = barFrame:CreateFontString(nil, 'OVERLAY')
		Pixel.ApplyFont(label, statSize, font, 'OUTLINE')
		label:SetTextColor(1, 1, 1, 0.9)
		statLabels[key] = label
	end
	HideHoverStats()

	hoverTicker = CreateFrame('Frame')
	hoverTicker:Hide()
	local tickElapsed = 0
	hoverTicker:SetScript('OnUpdate', BUI.Profiler.Wrap('Skin.ExperienceBar hover stats', function(_, elapsed)
		tickElapsed = tickElapsed + elapsed
		if tickElapsed < 0.5 then return end
		tickElapsed = 0
		UpdateHoverStats()
	end))

	barFrame:EnableMouse(true)
	barFrame:SetScript('OnEnter', BUI.Profiler.Script('Skin.ExperienceBar barFrame OnEnter', function(self)
		local config = GetConfig()
		local hover = config.hoverHeight
		local position = config.position
		local vertical = IsVertical(position)
		local scaledEdge = Pixel.PixelSize(1)

		if vertical then
			xpBar:SetWidth(hover)
			restedBar:SetWidth(hover)
			reputationBar:SetWidth(hover)

			local total = 0
			if xpBar:IsShown() then total = total + hover end
			if reputationBar:IsShown() then total = total + hover + (xpBar:IsShown() and scaledEdge or 0) end
			if total > 0 then self:SetWidth(total + scaledEdge * 2) end
		else
			local oldHeight = self:GetHeight()
			xpBar:SetHeight(hover)
			restedBar:SetHeight(hover)
			reputationBar:SetHeight(hover)
			xpText:Show()
			reputationText:Show()

			local total = 0
			if xpBar:IsShown() then total = total + hover end
			if reputationBar:IsShown() then total = total + hover + (xpBar:IsShown() and scaledEdge or 0) end
			if total > 0 then
				self:SetHeight(total + scaledEdge * 2)

				if position == 'FREE' then
					local delta = (total + scaledEdge * 2 - oldHeight) / 2
					self:ClearAllPoints()
					BUI.Anchor.PlaceOnPixels(self, 'CENTER', UIParent, 'CENTER', config.posX, config.posY - delta)
				end
			end
		end

		UpdateHoverStats()
		hoverTicker:Show()
	end))

	barFrame:SetScript('OnLeave', BUI.Profiler.Script('Skin.ExperienceBar barFrame OnLeave', function()
		xpText:Hide()
		reputationText:Hide()
		HideHoverStats()
		hoverTicker:Hide()
		LayoutBars()
		ApplyBarPosition()
	end))

	Dragging.MakeDraggable(barFrame, {
		isLocked = function()
			local config = GetConfig()
			return config.position ~= 'FREE' or config.locked
		end,
		onPositionChanged = function(x, y)
			local config = GetConfig()
			if not config.centerH then config.posX = x end
			config.posY = y
		end,
		lockHorizontal = function() return GetConfig().centerH end,
		getLockedX = function() return 0 end,
		onRightClick = function()
			local config = GetConfig()
			if config.position == 'FREE' and not config.locked then
				config.locked = true
				ApplySettings()
			elseif CharacterFrame:IsShown() then
				ToggleCharacter('ReputationFrame', true)
			end
		end,
		showHint = true,
		showUnlockedBg = true,
		hintText = 'Drag to Reposition | Right-Click to Lock',
		hintAnchor = 'TOP',
		skipClickThrough = true,
	})
	BUI.SecureRelay.Attach(barFrame, {
		button = 'RightButton',
		forward = 'OnMouseUp',
		action = function()
			local config = GetConfig()
			if config.position == 'FREE' and not config.locked then return nil end
			return 'click', CharacterMicroButton
		end,
	})

	local function OnXPBarEvent(event, _, levelPlayedTime)
		if not Enabled() then return end
		if event == 'PLAYER_ENTERING_WORLD' then
			InitSession()
			LayoutBars()
		elseif event == 'PLAYER_XP_UPDATE' then
			local xp = UnitXP('player')
			local difference = xp - lastKnownXP
			if difference < 0 then difference = lastKnownMax - lastKnownXP + xp end
			if difference > 0 then
				sessionXPGained = sessionXPGained + difference
				SaveSession()
			end
			lastKnownXP = xp
			lastKnownMax = UnitXPMax('player')
		elseif event == 'PLAYER_LEVEL_UP' then
			levelPlayedSeconds = 0
			levelPlayedBaseTime = GetTime()
			levelPlayedReceived = true
			lastKnownMax = UnitXPMax('player')
		elseif event == 'UPDATE_FACTION' then
			RefreshFaction()
			return
		elseif event == 'TIME_PLAYED_MSG' then
			levelPlayedSeconds = levelPlayedTime
			levelPlayedBaseTime = GetTime()
			levelPlayedReceived = true
		end
		UpdateAll()
	end
	for _, event in ipairs(XP_EVENTS) do
		BUI.Events:Register(event, 'Skinning.XPBar', OnXPBarEvent)
	end

	barFrame:Hide()
end

local function Enable()
	CreateBars()
	InitSession()
	ApplySettings()
end

context.Window('StatusTrackingBarManager', { install = InstallBar, enable = Enable, show = Skin.SuppressBlizzardFrame })
context.Window('MainStatusTrackingBarContainer', { install = InstallBar, show = Skin.SuppressBlizzardFrame })
context.Window('SecondaryStatusTrackingBarContainer', { install = InstallBar, show = Skin.SuppressBlizzardFrame })

context.OnDisable(function()
	if not barFrame then return end
	barFrame:Hide()
	hoverTicker:Hide()
	HideHoverStats()
	RestoreBlizzard()
end)

local POSITION_OPTIONS = {
	{ value = 'BOTTOM', text = 'Bottom Edge' },
	{ value = 'TOP',    text = 'Top Edge' },
	{ value = 'LEFT',   text = 'Left Edge' },
	{ value = 'RIGHT',  text = 'Right Edge' },
	{ value = 'FREE',   text = 'Free Position' },
}

local function Setting(label, key, apply, extra)
	local option = extra or {}
	option.label = label
	option.get = function() return GetConfig()[key] end
	option.set = function(value)
		GetConfig()[key] = value
		if apply then apply(value) end
	end
	return option
end

local function ColorSetting(label, key)
	return {
		kind = 'swatch', label = label,
		get = function()
			local color = GetConfig()[key]
			return color[1], color[2], color[3], 1
		end,
		set = function(red, green, blue)
			GetConfig()[key] = { red, green, blue }
			ApplySettings()
		end,
	}
end

local function CenterHorizontally(value)
	if value then GetConfig().posX = 0 end
	if barFrame then barFrame:RefreshDragState() end
	ApplySettings()
end

context.info.settings = {
	Setting('Position', 'position', ApplySettings, { entries = POSITION_OPTIONS }),
	Setting('Full width on the top or bottom edge', 'fullWidth', ApplySettings),
	Setting('Center horizontally when free', 'centerH', CenterHorizontally),
	Setting('Locked when free', 'locked', ApplySettings),
	Setting('Bar height', 'barHeight', ApplySettings, { separator = true, min = 2, max = 24, step = 1 }),
	Setting('Hover height', 'hoverHeight', nil, { min = 10, max = 40, step = 1 }),
	Setting('Font size', 'fontSize', ApplySettings, { min = 6, max = 18, step = 1 }),
	Setting('Bar width', 'barWidth', ApplySettings, { min = 500, max = 1500, step = 1 }),
	ColorSetting('XP bar color', 'xpColor'),
	Setting('Show rested XP', 'showRestedXP', ApplySettings),
	ColorSetting('Rested XP color', 'restedColor'),
	Setting('Background opacity', 'bgOpacity', ApplySettings, { min = 0, max = 100, step = 1 }),
}
