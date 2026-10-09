local _, BUI = ...

local Skin = BUI.Skinning
local IsSecretValue = BUI.Tools.IsSecretValue

local Readout = {}
Skin.Readout = Readout

local GEM_MAX = 4
local GEM_RARE_QUALITY = 3
local GEM_BORDER_RARE = { 1, 0.82, 0 }
local GEM_BORDER_COMMON = { 0.75, 0.75, 0.75 }
local EMPTY_SOCKET_ALPHA = 0.6
local EMPTY_SOCKET_PATH = 'Interface\\ItemSocketingFrame\\UI-EmptySocket-'
local QUESTION_MARK_ICON = 134400
local MAX_LEVEL_FALLBACK = 90
local ENCHANT_TINT = 0.5
local ENCHANT_ALPHA = 0.95
local ENCHANT_LINE_TYPE = Enum.TooltipDataLineType.ItemEnchantmentPermanent
local ATLAS_MARKUP = '|A:[^|]+|a'

Readout.MISSING_COLOR = { 0.898, 0.286, 0.286, 1 }
Readout.TRACK_COLORS = {
	explorer   = { 0.62, 0.62, 0.62 },
	adventurer = { 1, 1, 1 },
	veteran    = { 0.12, 1, 0 },
	champion   = { 0, 0.44, 0.87 },
	hero       = { 0.64, 0.21, 0.93 },
	myth       = { 1, 0.5, 0 },
}
local TRACK_COLORS = Readout.TRACK_COLORS

local SOCKET_TYPES = {
	EMPTY_SOCKET_META       = 'Meta',
	EMPTY_SOCKET_RED        = 'Red',
	EMPTY_SOCKET_YELLOW     = 'Yellow',
	EMPTY_SOCKET_BLUE       = 'Blue',
	EMPTY_SOCKET_PRISMATIC  = 'Prismatic',
	EMPTY_SOCKET_TINKER     = 'Tinker',
	EMPTY_SOCKET_PRIMORDIAL = 'Primordial',
	EMPTY_SOCKET_DOMINATION = 'Domination',
	EMPTY_SOCKET_CYPHER     = 'Cypher',
	EMPTY_SOCKET_HYDRAULIC  = 'Hydraulic',
	EMPTY_SOCKET_COGWHEEL   = 'Cogwheel',
}

local function EscapePattern(text)
	return (text:gsub('([%(%)%.%[%]%^%$%*%+%-%?%%])', '%%%1'))
end

local function PatternFromFormat(format)
	local head, tail = format:match('^(.-)%%s(.*)$')
	if not head then return nil end
	return '^' .. EscapePattern(head) .. '(.+)' .. EscapePattern(tail) .. '$'
end

local ENCHANT_PATTERN = PatternFromFormat(ENCHANTED_TOOLTIP_LINE)
local UPGRADE_PATTERN = '^' .. EscapePattern(ITEM_UPGRADE_TOOLTIP_FORMAT):gsub('%%%%s', '(.-)'):gsub('%%%%d', '(%%d+)') .. '$'

local function StripColors(text)
	if not text then return '' end
	text = text:gsub('|cn.-:(.-)|r', '%1')
	text = text:gsub('|c%x%x%x%x%x%x%x%x', '')
	text = text:gsub('|r', '')
	text = text:gsub('^%s*[%+&]%s*', '')
	return text
end

local function Lines(unit, slotID, link)
	local data = unit and C_TooltipInfo.GetInventoryItem(unit, slotID) or C_TooltipInfo.GetHyperlink(link)
	return data and data.lines
end

local function ParseUpgradeLine(raw)
	local track, current, maximum = raw:match(UPGRADE_PATTERN)
	if track then return track, current, maximum end
	track, current, maximum = raw:match('(%a+)%s+(%d+)%s*/%s*(%d+)%s*$')
	if track and TRACK_COLORS[track:lower()] then return track, current, maximum end
end

local NO_TRACK = {}
local trackCache, enchantCache = {}, {}

local function ScanTrack(lines)
	for _, line in ipairs(lines) do
		local track, current, maximum = ParseUpgradeLine(StripColors(line.leftText))
		if track then
			return { track .. ' ' .. current .. '/' .. maximum, TRACK_COLORS[track:lower():match('^(%a+)')] }
		end
	end
	return NO_TRACK
end

local function ScanEnchant(lines)
	for _, line in ipairs(lines) do
		local raw = StripColors(line.leftText)
		local matched = ENCHANT_PATTERN and raw:match(ENCHANT_PATTERN)
		if not matched and line.type == ENCHANT_LINE_TYPE then matched = raw end
		if matched and matched ~= '' then return (matched:gsub('^Enchanted:%s*', '')) end
	end
end

function Readout.Read(unit, slotID, link, wantEnchant)
	local track = trackCache[link]
	local enchantID = wantEnchant and tonumber(link:match('item:%d+:(%d+)'))
	if enchantID == 0 then enchantID = nil end
	local enchant = enchantID and enchantCache[enchantID]
	if not track or (enchantID and not enchant) then
		local lines = Lines(unit, slotID, link)
		if lines then
			if not track then
				track = ScanTrack(lines)
				trackCache[link] = track
			end
			if enchantID and not enchant then
				enchant = ScanEnchant(lines)
				enchantCache[enchantID] = enchant
			end
		end
	end
	local trackText, trackColor
	if track and track ~= NO_TRACK then trackText, trackColor = track[1], track[2] end
	return trackText, trackColor, enchant or ''
end

function Readout.CanHaveEnchant(info, link)
	if info.enchant == 'weapon' then
		local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
		return classID == Enum.ItemClass.Weapon
	end
	return info.enchant == true
end

function Readout.AtEnchantLevel(unit)
	local level = UnitLevel(unit)
	if not level or IsSecretValue(level) then return false end
	return level >= (GetMaxLevelForPlayerExpansion() or MAX_LEVEL_FALLBACK)
end

function Readout.PaintEnchant(label, hover, enchant, red, green, blue)
	local icons = ''
	for atlas in enchant:gmatch(ATLAS_MARKUP) do icons = icons .. atlas end
	local name = enchant:gsub(ATLAS_MARKUP, ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('^Enchant%s+[^%-]+%-%s*', '')
	label:SetText(icons ~= '' and (icons .. ' ' .. name) or name)
	label:SetTextColor(red + (1 - red) * ENCHANT_TINT, green + (1 - green) * ENCHANT_TINT, blue + (1 - blue) * ENCHANT_TINT, ENCHANT_ALPHA)
	hover.tooltip = name
end

function Readout.PaintMissingEnchant(label, hover)
	local color = Readout.MISSING_COLOR
	label:SetText('No Enchant')
	label:SetTextColor(color[1], color[2], color[3], color[4])
	hover.tooltip = 'Enchant missing'
end

local socketIcons, socketLinks = {}, {}

local function ReadSockets(link)
	wipe(socketIcons)
	wipe(socketLinks)
	if not link then return 0 end
	local filled = 0
	for gemIndex = 1, GEM_MAX do
		local _, gemLink = C_Item.GetItemGem(link, gemIndex)
		if gemLink then
			filled = filled + 1
			socketIcons[filled] = C_Item.GetItemIconByID(gemLink) or QUESTION_MARK_ICON
			socketLinks[filled] = gemLink
		end
	end
	local stats = C_Item.GetItemStats(link)
	if not stats then return filled end
	local total, socketType = 0, nil
	for key, count in pairs(stats) do
		local name = SOCKET_TYPES[key]
		if name and count > 0 then
			total = total + count
			socketType = socketType or name
		end
	end
	for index = filled + 1, math.max(filled, total) do
		socketIcons[index] = EMPTY_SOCKET_PATH .. socketType
		socketLinks[index] = false
	end
	return math.max(filled, total)
end

local function GemTooltip(self)
	if not self.link then return end
	GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	GameTooltip:SetHyperlink(self.link)
	GameTooltip:Show()
end

local function HideTooltip() GameTooltip:Hide() end

local function NewGem(metrics)
	local gem = CreateFrame('Frame', nil, metrics.parent, 'BackdropTemplate')
	gem:SetSize(metrics.size, metrics.size)
	gem:SetFrameLevel(metrics.parent:GetFrameLevel() + 1)
	BUI.Pixel.SetTemplate(gem, 0, 0, 0, 1)
	gem.icon = gem:CreateTexture(nil, 'ARTWORK')
	gem.icon:SetPoint('TOPLEFT', 1, -1)
	gem.icon:SetPoint('BOTTOMRIGHT', -1, 1)
	gem:EnableMouse(true)
	gem:SetScript('OnEnter', BUI.Profiler.Script('Skin.Readout gem OnEnter', GemTooltip))
	gem:SetScript('OnLeave', BUI.Profiler.Script('Skin.Readout gem OnLeave', HideTooltip))
	return gem
end

function Readout.RefreshGems(labels, link, metrics)
	local count = ReadSockets(link)
	local gems = labels.gems
	for index = 1, math.max(count, #gems) do
		local gem = gems[index]
		if index > count then
			gem:Hide()
		else
			if not gem then
				gem = NewGem(metrics)
				gems[index] = gem
			end
			local gemLink = socketLinks[index] or nil
			gem.link = gemLink
			gem.icon:SetTexture(socketIcons[index])
			if gemLink then
				gem.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				local border = (C_Item.GetItemQualityByID(gemLink) or 2) >= GEM_RARE_QUALITY and GEM_BORDER_RARE or GEM_BORDER_COMMON
				gem:SetBackdropBorderColor(border[1], border[2], border[3], 1)
			else
				gem.icon:SetTexCoord(0, 1, 0, 1)
				gem:SetBackdropBorderColor(GEM_BORDER_COMMON[1], GEM_BORDER_COMMON[2], GEM_BORDER_COMMON[3], EMPTY_SOCKET_ALPHA)
			end
			gem:ClearAllPoints()
			gem:SetPoint('BOTTOMRIGHT', labels.button, 'BOTTOMRIGHT', -metrics.inset, metrics.inset + (index - 1) * (metrics.size + metrics.pad))
			gem:Show()
		end
	end
end
