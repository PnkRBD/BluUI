local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('ExperienceBar')
local hooksecurefunc = BUI.Prof.MakeHooker('ExperienceBar')

local floor, format, max, min = math.floor, string.format, math.max, math.min
local GetTime = GetTime

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local RegisterAccentElement = BUILib.Colors.RegisterAccentElement
local Layout = BUILib.Layout
local Controls = BUILib.Controls

local Pixel = BUI.Pixel
local Skin = BUI.Skinning
local Dragging = BUI.Dragging
local BLANK = BUI.C.FALLBACK_TEXTURE

local STAT_KEYS = { 'timeLevel', 'timeSession', 'levelingIn', 'completed' }

local barFrame, xpBar, restedBar, reputationBar, xpText, reputationText
local reputationEdgeTexture
local statLabels = {}
local hoverTicker
local isActive = false

local sessionOnlineTime = 0
local sessionLoginTime = 0
local sessionXPGained = 0
local lastKnownXP = 0
local lastKnownMax = 0
local levelPlayedSeconds = 0
local levelPlayedBaseTime = 0
local levelPlayedReceived = false
local suppressNextPlayed = false

if ChatFrame_DisplayTimePlayed then
	local origDisplayTimePlayed = ChatFrame_DisplayTimePlayed
	ChatFrame_DisplayTimePlayed = function(...)
		if suppressNextPlayed then
			suppressNextPlayed = false
			return
		end
		return origDisplayTimePlayed(...)
	end
end

local function IsAtMaxLevel()
	local level = UnitLevel('player')
	if IsLevelAtEffectiveMaxLevel then return IsLevelAtEffectiveMaxLevel(level) end
	if GetMaxLevelForPlayerExpansion then return level >= GetMaxLevelForPlayerExpansion() end
	return level >= (MAX_PLAYER_LEVEL or 80)
end

local function GetSessionTime()
	if sessionLoginTime == 0 then return 0 end
	return sessionOnlineTime + (time() - sessionLoginTime)
end

local function GetConfig()
	return BUI.GetDB().skinning.experiencebarSettings
end

local function GetFont()
	return BUI.GetGlobalFont() or BUI.C.FONT_PATH
end

local function IsVertical(position)
	return position == 'LEFT' or position == 'RIGHT'
end

local function ApplyBarPosition()
	if not barFrame then return end
	local config = GetConfig()
	local position = config.position or 'BOTTOM'

	barFrame:ClearAllPoints()
	local barWidth = config.barWidth or 400
	local fullWidth = config.fullWidth ~= false

	if position == 'BOTTOM' then
		if fullWidth then
			barFrame:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT')
			barFrame:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT')
		else
			barFrame:SetWidth(barWidth)
			barFrame:SetPoint('BOTTOM', UIParent, 'BOTTOM')
		end
	elseif position == 'TOP' then
		if fullWidth then
			barFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT')
			barFrame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT')
		else
			barFrame:SetWidth(barWidth)
			barFrame:SetPoint('TOP', UIParent, 'TOP')
		end
	elseif position == 'LEFT' then
		barFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT')
		barFrame:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT')
	elseif position == 'RIGHT' then
		barFrame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT')
		barFrame:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT')
	elseif position == 'FREE' then
		barFrame:SetWidth(barWidth)
		barFrame:SetPoint('CENTER', UIParent, 'CENTER', config.posX or 0, config.posY or -250)
	end

	if barFrame.dragReady then
		Dragging.SetLocked(barFrame, position ~= 'FREE' or config.locked ~= false)
	end
end

local function SaveSession()
	local db = BUI.db
	if not db then return end
	if not db.char then db.char = {} end
	db.char.xpSessionOnline = GetSessionTime()
	db.char.xpSessionGained = sessionXPGained
end

local function InitSession()
	if sessionLoginTime > 0 then return end
	sessionLoginTime = time()
	local db = BUI.db
	if db and db.char and db.char.xpSessionOnline then
		sessionOnlineTime = db.char.xpSessionOnline
		sessionXPGained = db.char.xpSessionGained or 0
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
	if config.useAccentColor then return BUI.GetAccentColor() end
	return config.xpColor[1], config.xpColor[2], config.xpColor[3]
end

local function HasReputation()
	local data = C_Reputation.GetWatchedFactionData()
	return data and data.name and true or false
end

local function HideHoverStats()
	for _, label in pairs(statLabels) do label:Hide() end
end

local function UpdateHoverStats()
	if not statLabels.timeLevel then return end
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
	if not isActive then return end
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

local function GetReputationProgress(data)
	local factionID = data.factionID

	if factionID and C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) then
		local majorData = C_MajorFactions.GetMajorFactionData(factionID)
		if majorData then
			local threshold = majorData.renownLevelThreshold or 0
			local earned = majorData.renownReputationEarned or 0
			local level = majorData.renownLevel or 0
			local label = format('%s  Renown %d', data.name, level)
			if threshold <= 0 then
				if C_Reputation.IsFactionParagon(factionID) then
					local paragonValue, paragonThreshold, _, hasReward = C_Reputation.GetFactionParagonInfo(factionID)
					if paragonValue and paragonThreshold and paragonThreshold > 0 then
						local currentValue = paragonValue % paragonThreshold
						local suffix = hasReward and ' |cff00ff00Reward!|r' or ''
						return 0, paragonThreshold, currentValue, format('%s  Paragon%s', data.name, suffix), 0.0, 0.75, 0.44
					end
				end
				return 0, 1, 1, label .. '  (Max)', 0.0, 0.68, 0.94
			end
			return 0, threshold, earned, label, 0.0, 0.68, 0.94
		end
	end

	if factionID and C_Reputation.IsFactionParagon(factionID) then
		local paragonValue, paragonThreshold, _, hasReward = C_Reputation.GetFactionParagonInfo(factionID)
		if paragonValue and paragonThreshold and paragonThreshold > 0 then
			local currentValue = paragonValue % paragonThreshold
			local suffix = hasReward and ' |cff00ff00Reward!|r' or ''
			return 0, paragonThreshold, currentValue, format('%s  Paragon%s', data.name, suffix), 0.0, 0.75, 0.44
		end
	end

	if factionID then
		local friendData = C_GossipInfo.GetFriendshipReputation(factionID)
		if friendData and friendData.friendshipFactionID and friendData.friendshipFactionID > 0 then
			local friendMin = friendData.reactionThreshold or 0
			local friendMax = friendData.nextThreshold or 0
			if friendMax > 0 then
				return friendMin, friendMax, friendData.reputation or 0
			end
			return 0, 1, 1, data.name .. '  (Max)'
		end
	end

	return data.currentReactionThreshold or 0, data.nextReactionThreshold or 0, data.currentStanding or 0
end

local function UpdateReputation()
	if not isActive then
		reputationBar:Hide()
		reputationText:SetText('')
		return
	end

	local data = C_Reputation.GetWatchedFactionData()
	if not data or not data.name then
		reputationBar:Hide()
		reputationText:SetText('')
		return
	end

	local barMin, barMax, barCurrent, label, reputationRed, reputationGreen, reputationBlue = GetReputationProgress(data)
	local rangeMax = max(1, barMax - barMin)
	local rangeCurrent = max(0, min(barCurrent - barMin, rangeMax))

	reputationBar:Show()
	reputationBar:SetMinMaxValues(0, rangeMax)
	reputationBar:SetValue(rangeCurrent)

	if reputationRed then
		reputationBar:SetStatusBarColor(reputationRed, reputationGreen, reputationBlue)
	else
		local colors = FACTION_BAR_COLORS[data.reaction or 0]
		if colors then
			reputationBar:SetStatusBarColor(colors.r, colors.g, colors.b)
		else
			reputationBar:SetStatusBarColor(0.6, 0.6, 0.6)
		end
	end

	reputationText:SetFormattedText('%s  %s / %s  (%d%%)',
		label or data.name, ShortNumber(rangeCurrent), ShortNumber(rangeMax), floor(rangeCurrent / rangeMax * 100))
end

local function UpdateAll()
	UpdateXP()
	UpdateReputation()
end

local function LayoutStatLabels()
	if not statLabels.timeLevel then return end
	local config = GetConfig()
	local position = config.position or 'BOTTOM'
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
	if not barFrame then return end
	local config = GetConfig()
	local barHeight = config.barHeight
	local position = config.position or 'BOTTOM'
	local vertical = IsVertical(position)
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

		if totalWidth == 0 then
			barFrame:Hide()
		else
			barFrame:SetWidth(totalWidth + scaledEdge * 2)
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

		if totalHeight == 0 then
			barFrame:Hide()
		else
			barFrame:SetHeight(totalHeight + scaledEdge * 2)
			barFrame:Show()
		end
	end

	LayoutStatLabels()
end

local function ApplySettings()
	if not barFrame or not isActive then return end
	local config = GetConfig()
	local red, green, blue = GetXPColor()
	xpBar:SetStatusBarColor(red, green, blue, 0.85)

	local restedColor = config.restedColor
	restedBar:SetStatusBarColor(restedColor[1], restedColor[2], restedColor[3], 0.5)

	local font = GetFont()
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

local BLIZZ_BAR_FRAMES = { 'StatusTrackingBarManager', 'MainStatusTrackingBarContainer', 'SecondaryStatusTrackingBarContainer' }

local function SuppressBlizzard()
	for _, name in ipairs(BLIZZ_BAR_FRAMES) do
		local frame = _G[name]
		if frame then
			Skin.SuppressBlizzardFrame(frame)
			if not frame._buiReassertHooked then
				frame._buiReassertHooked = true
				HookScript(frame, 'OnShow', function(self) if isActive then Skin.SuppressBlizzardFrame(self) end end)
				hooksecurefunc(frame, 'SetAlpha', function(self, alpha)
					if isActive and alpha ~= 0 and not self._buiReasserting then
						self._buiReasserting = true
						self:SetAlpha(0)
						self._buiReasserting = nil
					end
				end)
			end
		end
	end
end

local function RestoreBlizzard()
	local manager = StatusTrackingBarManager
	if manager then
		Skin.RestoreBlizzardFrame(manager)
		if manager.UpdateBarsShown then manager:UpdateBarsShown() end
	end
	for _, name in ipairs({ 'MainStatusTrackingBarContainer', 'SecondaryStatusTrackingBarContainer' }) do
		local frame = _G[name]
		if frame then
			Skin.RestoreBlizzardFrame(frame)
			if frame.ApplySystemAnchor then frame:ApplySystemAnchor() end
		end
	end
	if manager and manager.ApplySystemAnchor then manager:ApplySystemAnchor() end
end

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
	BUI.Tools.SetColorTex(background, 0.05, 0.05, 0.05, 0.9)
	barFrame.FrameBG = background

	Pixel.ApplyBorder(barFrame, 1, 0, 0, 0, 1)

	restedBar = CreateFrame('StatusBar', nil, barFrame)
	restedBar:SetStatusBarTexture(BLANK)
	restedBar:SetFrameLevel(barFrame:GetFrameLevel() + 1)
	restedBar:Hide()

	xpBar = CreateFrame('StatusBar', nil, barFrame)
	xpBar:SetStatusBarTexture(BLANK)
	xpBar:SetFrameLevel(barFrame:GetFrameLevel() + 2)

	RegisterAccentElement(xpBar, function(_, red, green, blue)
		if GetConfig().useAccentColor then xpBar:SetStatusBarColor(red, green, blue, 0.85) end
	end)

	reputationBar = CreateFrame('StatusBar', nil, barFrame)
	reputationBar:SetStatusBarTexture(BLANK)
	reputationBar:SetStatusBarColor(0.6, 0.6, 0.6)
	reputationBar:SetFrameLevel(barFrame:GetFrameLevel() + 2)
	reputationBar:Hide()

	local reputationBackground = reputationBar:CreateTexture(nil, 'BACKGROUND')
	reputationBackground:SetAllPoints()
	reputationBackground:SetColorTexture(0.05, 0.05, 0.05, 0.9)

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

	local font = GetFont()
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
	SetScript(hoverTicker, 'OnUpdate', function(_, elapsed)
		tickElapsed = tickElapsed + elapsed
		if tickElapsed < 0.5 then return end
		tickElapsed = 0
		UpdateHoverStats()
	end)

	barFrame:EnableMouse(true)
	SetScript(barFrame, 'OnEnter', function(self)
		local config = GetConfig()
		local hover = config.hoverHeight
		local position = config.position or 'BOTTOM'
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
					self:SetPoint('CENTER', UIParent, 'CENTER', config.posX or 0, (config.posY or -250) - delta)
				end
			end
		end

		UpdateHoverStats()
		hoverTicker:Show()
	end)

	SetScript(barFrame, 'OnLeave', function()
		xpText:Hide()
		reputationText:Hide()
		HideHoverStats()
		hoverTicker:Hide()
		LayoutBars()
		ApplyBarPosition()
	end)

	Dragging.MakeDraggable(barFrame, {
		isLocked = function()
			local config = GetConfig()
			return config.position ~= 'FREE' or config.locked ~= false
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
				Dragging.SetLocked(barFrame, true)
			else
				ToggleCharacter('ReputationFrame')
			end
		end,
		showHint = true,
		showUnlockedBg = true,
		hintText = 'Drag to Reposition | Right-Click to Lock',
		hintAnchor = 'TOP',
		skipClickThrough = true,
	})
	barFrame.dragReady = true

	local function OnXPBarEvent(event, totalPlayedTime, levelPlayedTime)
		if not isActive then return end
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
			LayoutBars()
			ApplyBarPosition()
		elseif event == 'TIME_PLAYED_MSG' and levelPlayedTime then
			levelPlayedSeconds = levelPlayedTime
			levelPlayedBaseTime = GetTime()
			levelPlayedReceived = true
		end
		UpdateAll()
	end
	for _, event in ipairs({
		'PLAYER_XP_UPDATE', 'PLAYER_LEVEL_UP', 'UPDATE_EXHAUSTION',
		'UPDATE_FACTION', 'PLAYER_ENTERING_WORLD', 'TIME_PLAYED_MSG',
	}) do
		BUI.Events:Register(event, 'Skinning.XPBar', OnXPBarEvent)
	end

	barFrame:Hide()
end

local function Enable()
	local wasActive = isActive
	isActive = true
	CreateBars()
	SuppressBlizzard()
	if not wasActive then InitSession() end
	ApplySettings()
end

local function Disable()
	if not isActive then return end
	isActive = false
	if barFrame then barFrame:Hide() end
	if hoverTicker then hoverTicker:Hide() end
	HideHoverStats()
	RestoreBlizzard()
end

BUI.Events:OnLogin('Skinning.XPBar.Init', function()
	if Skin.IsSkinEnabled('experiencebar') then Enable() end
end)

Skin.OnToggle('experiencebar', function(enabled)
	if enabled then Enable() else Disable() end
end)

local POSITION_OPTIONS = {
	{ value = 'BOTTOM', text = 'Bottom Edge' },
	{ value = 'TOP',    text = 'Top Edge' },
	{ value = 'LEFT',   text = 'Left Edge' },
	{ value = 'RIGHT',  text = 'Right Edge' },
	{ value = 'FREE',   text = 'Free Position' },
}

Skin.RegisterSkin('experiencebar', {
	name = 'Experience Bar',
	description = 'Replaces the Blizzard status tracking bars with a minimal dark bar. Supports edge anchoring and free drag positioning.',
	icon = 'Interface\\Icons\\Achievement_Level_80',
	buildSettings = function(content)
		local config = GetConfig()

		local posPanel = Layout.SettingsCard(content, { title = 'Position' })
		Layout.Dropdown(posPanel, nil, POSITION_OPTIONS, config.position or 'BOTTOM', function(value)
			config.position = value
			ApplySettings()
			content.Rebuild()
		end)
		local isHorizontal = not IsVertical(config.position or 'BOTTOM')
		local isFree = config.position == 'FREE'

		if isHorizontal and not isFree then
			Layout.Toggle(posPanel, 'Full Width', config.fullWidth ~= false, function(value)
				config.fullWidth = value; ApplySettings()
			end)
		end
		if isFree then
			Layout.Toggle(posPanel, 'Center Horizontally', config.centerH or false, function(value)
				config.centerH = value
				if value then config.posX = 0 end
				if barFrame then barFrame:RefreshDragState() end
				ApplySettings()
			end)
			Layout.Toggle(posPanel, 'Locked', config.locked ~= false, function(value)
				config.locked = value
				if barFrame then Dragging.SetLocked(barFrame, value) end
			end)
		end
		posPanel:Refresh()

		local sizing = Layout.SettingsCard(content, { title = 'Bar Sizing' })

		local COL_GAP = 8
		local sliderHeight = Layout.HEIGHTS.slider
		local colWidth = floor((sizing.width - COL_GAP) / 2)
		local gridHeight = sliderHeight * 2 + COL_GAP

		local grid = CreateFrame('Frame', nil, sizing.child)
		grid:SetSize(sizing.width, gridHeight)

		local anchorControl, anchorY = sizing:GetAnchor(14)
		if anchorControl then
			grid:SetPoint('TOPLEFT', anchorControl, 'BOTTOMLEFT', 0, anchorY)
		end
		sizing:SetLast(grid, 0)
		sizing:AddY(14 + gridHeight)

		local function MakeSlider(label, minValue, maxValue, currentValue, callback, offsetX, offsetY)
			local slider = Controls.Slider(grid, label, minValue, maxValue, currentValue, callback, 0, nil, nil, 1, colWidth)
			slider:SetPoint('TOPLEFT', grid, 'TOPLEFT', offsetX, offsetY)
			return slider
		end

		MakeSlider('Bar Height',   2,   24,   config.barHeight,         function(value) config.barHeight   = value; ApplySettings() end, 0,                  0)
		MakeSlider('Hover Height', 10,  40,   config.hoverHeight,       function(value) config.hoverHeight = value end,                  colWidth + COL_GAP, 0)
		MakeSlider('Font Size',    6,   18,   config.fontSize,          function(value) config.fontSize    = value; ApplySettings() end, 0,                  -(sliderHeight + COL_GAP))
		MakeSlider('Bar Width',    500, 1500, config.barWidth or 500,   function(value) config.barWidth    = value; ApplySettings() end, colWidth + COL_GAP, -(sliderHeight + COL_GAP))
		sizing:Refresh()

		local colorsPanel = Layout.SettingsCard(content, { title = 'Colors & Display' })
		Layout.Toggle(colorsPanel, 'Use Accent Color for XP Bar', config.useAccentColor, function(value)
			config.useAccentColor = value; ApplySettings()
		end)
		if not config.useAccentColor then
			Layout.ColorSwatch(colorsPanel, 'XP Bar Color', config.xpColor[1], config.xpColor[2], config.xpColor[3], 1, function(red, green, blue)
				config.xpColor = { red, green, blue }; ApplySettings()
			end)
		end
		Layout.Toggle(colorsPanel, 'Show Rested XP', config.showRestedXP, function(value)
			config.showRestedXP = value; ApplySettings()
		end)
		Layout.ColorSwatch(colorsPanel, 'Rested XP Color', config.restedColor[1], config.restedColor[2], config.restedColor[3], 1, function(red, green, blue)
			config.restedColor = { red, green, blue }; ApplySettings()
		end)
		colorsPanel:Refresh()

		content:Refresh()
	end,
})
