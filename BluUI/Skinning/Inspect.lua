local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Inspect')

local hooksecurefunc = BUI.Prof.MakeHooker('inspect')
local ipairs = ipairs
local floor = math.floor
local max = math.max

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local IsSecretValue = BUI.Tools.IsSecretValue

local SKIN_ID = 'inspect'
local BOTTOM_TAB_COUNT = 3
local PVP_TALENT_SLOT_COUNT = 3
local MAIN_ART = { 'Bg', 'TopTileStreaks', 'Inset' }
local SLOT_NAMES = {
	'Head', 'Neck', 'Shoulder', 'Back', 'Chest', 'Shirt', 'Tabard', 'Wrist',
	'Hands', 'Waist', 'Legs', 'Feet', 'Finger0', 'Finger1', 'Trinket0', 'Trinket1',
	'MainHand', 'SecondaryHand',
}
local SLOT_CONTENT_KEYS = { 'icon', 'IconOverlay', 'IconOverlay2', 'searchOverlay' }
local PVP_STAT_KEYS = { 'RatedBG', 'Arena2v2', 'Arena3v3', 'RatedSoloShuffle', 'RatedBGBlitz' }
local PVP_STAT_LABEL_KEYS = { 'RatingLabel', 'RecordLabel' }
local PVP_STAT_VALUE_KEYS = { 'Rating', 'Record' }
local GUILD_TEXT_KEYS = { 'guildRealmName', 'guildLevel', 'guildNumMembers' }
local GUILD_POINTS_ART = { 'LeftCap', 'RightCap' }
local ILVL_SIZE = 11
local TRACK_SIZE = 10
local ILVL_ALPHA = 0.9
local TRACK_ALPHA = 0.6
local LABEL_GAP_X = 5
local LABEL_LINE_Y = 13
local GEM_SIZE = 14
local GEM_PAD = 1
local GEM_INSET = 2
local GEM_MAX = 4
local GEM_RARE_QUALITY = 3
local GEM_BORDER_RARE = { 1, 0.82, 0 }
local GEM_BORDER_COMMON = { 0.75, 0.75, 0.75 }
local QUESTION_MARK_ICON = 134400
local TRACK_COLORS = {
	explorer   = { 0.62, 0.62, 0.62 },
	adventurer = { 1, 1, 1 },
	veteran    = { 0.12, 1, 0 },
	champion   = { 0, 0.44, 0.87 },
	hero       = { 0.64, 0.21, 0.93 },
	myth       = { 1, 0.5, 0 },
}
local EMPTY_SOCKET_ATLAS = {
	EMPTY_SOCKET_META       = 'socket-meta',
	EMPTY_SOCKET_RED        = 'socket-red',
	EMPTY_SOCKET_YELLOW     = 'socket-yellow',
	EMPTY_SOCKET_BLUE       = 'socket-blue',
	EMPTY_SOCKET_PRISMATIC  = 'socket-prismatic',
	EMPTY_SOCKET_TINKER     = 'socket-tinker',
	EMPTY_SOCKET_PRIMORDIAL = 'socket-primordial',
	EMPTY_SOCKET_DOMINATION = 'socket-domination',
	EMPTY_SOCKET_CYPHER     = 'socket-cypher',
	EMPTY_SOCKET_HYDRAULIC  = 'socket-hydraulic',
	EMPTY_SOCKET_COGWHEEL   = 'socket-cogwheel',
}
local TOTAL_LEVEL_SIZE = 24
local TOTAL_LEVEL_COLOR = { 1, 0.82, 0, 1 }
local TOTAL_LEVEL_BOX = { -8, -20, -110, -67 }
local TOTAL_LEVEL_FALLBACK = { -30, -10 }
local ENCHANT_SIZE = 9
local ENCHANT_NAME_W = 100
local ENCHANT_HOVER_H = 14
local ENCHANT_TINT = 0.5
local ENCHANT_ALPHA = 0.95
local MISSING_COLOR = { 0.898, 0.286, 0.286, 1 }
local MAX_LEVEL_FALLBACK = 90
local OVERLAY_LEVEL_BUMP = 20
local ENCHANT_LINE_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent or 15
local SLOT_INFO = {
	Head = { col = 'left', enchant = true },
	Neck = { col = 'left' },
	Shoulder = { col = 'left', enchant = true },
	Back = { col = 'left' },
	Chest = { col = 'left', enchant = true },
	Shirt = { col = 'left', cosmetic = true },
	Tabard = { col = 'left', cosmetic = true },
	Wrist = { col = 'left' },
	Hands = { col = 'right' },
	Waist = { col = 'right' },
	Legs = { col = 'right', enchant = true },
	Feet = { col = 'right', enchant = true },
	Finger0 = { col = 'right', enchant = true },
	Finger1 = { col = 'right', enchant = true },
	Trinket0 = { col = 'right' },
	Trinket1 = { col = 'right' },
	MainHand = { col = 'mainhand', enchant = true },
	SecondaryHand = { col = 'offhand', enchant = 'weapon' },
}

local SLOT_HOVER_ALPHA = 0.22
local GUILD_NAME_SCALE = 1.5
local HONOR_LEVEL_SCALE = 1.2

local installed = false
local skinned = false
local slotButtons = {}
local totalLevelText
local overlay

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close = context.Shell, context.Button, context.Close
local Face, Title, Body = context.Face, context.Title, context.Body
local CropIcon, RowHighlight = Skin.CropIcon, Skin.RowHighlight

local function EscapePattern(text)
	return (text:gsub('([%(%)%.%[%]%^%$%*%+%-%?%%])', '%%%1'))
end

local function PatternFromFormat(format)
	if not format then return nil end
	local head, tail = format:match('^(.-)%%s(.*)$')
	if not head then return nil end
	return '^' .. EscapePattern(head) .. '(.+)' .. EscapePattern(tail) .. '$'
end

local ENCHANT_PATTERN = PatternFromFormat(ENCHANTED_TOOLTIP_LINE)

local function StripColors(text)
	if not text then return '' end
	text = text:gsub('|cn.-:(.-)|r', '%1')
	text = text:gsub('|c%x%x%x%x%x%x%x%x', '')
	text = text:gsub('|r', '')
	text = text:gsub('^%s*[%+&]%s*', '')
	return text
end

local enchantCache = {}
local trackCache = {}
local NO_TRACK = {}

local function TooltipLines(unit, slotID, link)
	if not C_TooltipInfo then return nil end
	local data
	if unit and C_TooltipInfo.GetInventoryItem then data = C_TooltipInfo.GetInventoryItem(unit, slotID) end
	if not data and link and C_TooltipInfo.GetHyperlink then data = C_TooltipInfo.GetHyperlink(link) end
	if not data then return nil end
	if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(data) end
	return data.lines
end

local function ReadEnchant(unit, slotID, link)
	local enchantID = tonumber(link:match('item:%d+:(%d+)'))
	if not enchantID or enchantID == 0 then return '' end
	local cached = enchantCache[enchantID]
	if cached then return cached end

	local lines = TooltipLines(unit, slotID, link)
	if not lines then return '' end
	for _, line in ipairs(lines) do
		local raw = StripColors(line.leftText)
		local matched
		if line.type == ENCHANT_LINE_TYPE then
			matched = (ENCHANT_PATTERN and raw:match(ENCHANT_PATTERN)) or raw
		elseif ENCHANT_PATTERN then
			matched = raw:match(ENCHANT_PATTERN)
		end
		if matched and matched ~= '' then
			matched = matched:gsub('^Enchanted:%s*', '')
			matched = matched:gsub('^Enchant%s+[^%-]+%s*%-%s*', '')
			enchantCache[enchantID] = matched
			return matched
		end
	end
	return ''
end

local function CanHaveEnchant(info, link)
	if info.enchant == 'weapon' then
		if not link then return false end
		local _, _, _, _, _, classID = GetItemInfoInstant(link)
		return classID == Enum.ItemClass.Weapon
	end
	return info.enchant == true
end

local function AtEnchantLevel(unit)
	local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or MAX_LEVEL_FALLBACK
	local level = unit and UnitLevel(unit)
	if not level or IsSecretValue(level) then return false end
	return level >= maxLevel
end

local function SlotSides(info)
	if info.col == 'left' or info.col == 'offhand' then return 'RIGHT', 'LEFT' end
	return 'LEFT', 'RIGHT'
end

local UPGRADE_PATTERN
if ITEM_UPGRADE_TOOLTIP_FORMAT then
	local escaped = EscapePattern(ITEM_UPGRADE_TOOLTIP_FORMAT)
	escaped = escaped:gsub('%%%%s', '(.-)'):gsub('%%%%d', '(%%d+)')
	UPGRADE_PATTERN = '^' .. escaped .. '$'
end

local function ParseUpgradeLine(raw)
	if UPGRADE_PATTERN then
		local track, current, maximum = raw:match(UPGRADE_PATTERN)
		if track then return track, current, maximum end
	end
	local track, current, maximum = raw:match('(%a+)%s+(%d+)%s*/%s*(%d+)%s*$')
	if track and TRACK_COLORS[track:lower()] then return track, current, maximum end
	return nil
end

local function ReadUpgradeTrack(unit, slotID, link)
	local cached = trackCache[link]
	if cached == NO_TRACK then return nil end
	if cached then return cached[1], cached[2] end

	local lines = TooltipLines(unit, slotID, link)
	if not lines then return nil end
	for _, line in ipairs(lines) do
		local raw = StripColors(line.leftText)
		local track, current, maximum = ParseUpgradeLine(raw)
		if track then
			local key = track:lower():match('^(%a+)')
			local text, color = track .. ' ' .. current .. '/' .. maximum, TRACK_COLORS[key]
			trackCache[link] = { text, color }
			return text, color
		end
	end
	trackCache[link] = NO_TRACK
	return nil
end

local function ReadSockets(link)
	local entries, gemLinks = {}, {}
	if not link or not C_Item.GetItemGem or not C_Item.GetItemStats then return entries, gemLinks end

	for gemIndex = 1, GEM_MAX do
		local _, gemLink = C_Item.GetItemGem(link, gemIndex)
		if gemLink then
			gemLinks[#gemLinks + 1] = gemLink
			local icon = C_Item.GetItemIconByID(gemLink) or (GetItemInfoInstant and select(5, GetItemInfoInstant(gemLink)))
			entries[#entries + 1] = { icon = icon or QUESTION_MARK_ICON }
		end
	end

	local stats = C_Item.GetItemStats(link)
	if stats then
		local total, firstAtlas = 0, nil
		for key, count in pairs(stats) do
			local atlas = EMPTY_SOCKET_ATLAS[key]
			if atlas and count and count > 0 then
				total = total + count
				firstAtlas = firstAtlas or atlas
			end
		end
		for _ = 1, max(0, total - #gemLinks) do
			entries[#entries + 1] = { atlas = firstAtlas }
		end
	end
	return entries, gemLinks
end

local function IsSlotContent(button, region)
	for _, key in ipairs(SLOT_CONTENT_KEYS) do
		if button[key] == region then return true end
	end
	return region == button:GetHighlightTexture()
end

local function FadeSlotArt(button)
	for regionIndex = 1, select('#', button:GetRegions()) do
		local region = select(regionIndex, button:GetRegions())
		if region:IsObjectType('Texture') and not region.__buiSkin and not IsSlotContent(button, region) then Fade(region) end
	end
end

local function CreateTotalLevelText()
	local text = overlay:CreateFontString(nil, 'OVERLAY', nil, 7)
	text:SetFont(BUILib.Font, TOTAL_LEVEL_SIZE, 'OUTLINE')
	text:SetTextColor(TOTAL_LEVEL_COLOR[1], TOTAL_LEVEL_COLOR[2], TOTAL_LEVEL_COLOR[3], TOTAL_LEVEL_COLOR[4])
	text:SetShadowColor(0, 0, 0, 0)
	text:SetJustifyH('RIGHT')
	text:SetJustifyV('MIDDLE')
	local anchor = _G.InspectPaperDollItemsFrame
	if anchor then
		text:SetPoint('TOPRIGHT', anchor, 'TOPRIGHT', TOTAL_LEVEL_BOX[1], TOTAL_LEVEL_BOX[2])
		text:SetPoint('BOTTOMLEFT', anchor, 'TOPRIGHT', TOTAL_LEVEL_BOX[3], TOTAL_LEVEL_BOX[4])
	else
		text:SetPoint('TOPRIGHT', _G.InspectFrame, 'TOPRIGHT', TOTAL_LEVEL_FALLBACK[1], TOTAL_LEVEL_FALLBACK[2])
	end
	return text
end

local function UpdateTotalLevel()
	if not totalLevelText then return end
	local frame = _G.InspectFrame
	local unit = frame and frame.unit
	local query = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
	local level = unit and query and query(unit)
	if level and not IsSecretValue(level) and level > 0 then
		totalLevelText:SetText(floor(level + 0.5))
	else
		totalLevelText:SetText('')
	end
end

local function ColorSlotEdges(button)
	local unit = _G.InspectFrame.unit
	if button.hasItem and unit then
		Skin.SetIconEdgeColor(button.icon, Skin.QualityColor(GetInventoryItemID(unit, button:GetID())))
	else
		Skin.SetIconEdgeColor(button.icon)
	end
end

local function GemTooltip(self)
	if not self.link then return end
	GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	GameTooltip:SetHyperlink(self.link)
	GameTooltip:Show()
end

local function CreateGemFrame()
	local gem = CreateFrame('Frame', nil, overlay, 'BackdropTemplate')
	gem:SetSize(GEM_SIZE, GEM_SIZE)
	gem:SetFrameLevel(overlay:GetFrameLevel() + 1)
	gem:SetBackdrop({ bgFile = 'Interface/Buttons/WHITE8x8', edgeFile = 'Interface/Buttons/WHITE8x8', edgeSize = 1 })
	gem:SetBackdropColor(0, 0, 0, 1)
	gem.icon = gem:CreateTexture(nil, 'ARTWORK')
	gem.icon:SetPoint('TOPLEFT', 1, -1)
	gem.icon:SetPoint('BOTTOMRIGHT', -1, 1)
	gem:EnableMouse(true)
	SetScript(gem, 'OnEnter', GemTooltip)
	SetScript(gem, 'OnLeave', function() GameTooltip:Hide() end)
	gem:Hide()
	return gem
end

local function RefreshGems(labels, link)
	local entries, gemLinks = ReadSockets(link)
	for index = 1, max(#entries, #labels.gems) do
		local entry = entries[index]
		local gem = labels.gems[index]
		if entry and not gem then
			gem = CreateGemFrame()
			labels.gems[index] = gem
		end
		if gem then
			if entry then
				if gem.icon.SetAtlas then gem.icon:SetAtlas(nil) end
				gem.icon:SetTexture(nil)
				if entry.atlas then
					gem.icon:SetAtlas(entry.atlas)
					gem.link = nil
					gem:SetBackdropBorderColor(GEM_BORDER_COMMON[1], GEM_BORDER_COMMON[2], GEM_BORDER_COMMON[3], 0.6)
				else
					gem.icon:SetTexture(entry.icon)
					gem.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					gem.link = gemLinks[index]
					local quality = gem.link and C_Item.GetItemQualityByID(gem.link) or 2
					local border = quality >= GEM_RARE_QUALITY and GEM_BORDER_RARE or GEM_BORDER_COMMON
					gem:SetBackdropBorderColor(border[1], border[2], border[3], 1)
				end
				gem:ClearAllPoints()
				gem:SetPoint('BOTTOMRIGHT', labels.button, 'BOTTOMRIGHT', -GEM_INSET, GEM_INSET + (index - 1) * (GEM_SIZE + GEM_PAD))
				gem:Show()
			else
				gem:Hide()
			end
		end
	end
end

local function EnchantTooltip(self)
	GameTooltip:SetOwner(self, self.anchor)
	if self.unit and self.slot and GetInventoryItemLink(self.unit, self.slot) then
		GameTooltip:SetInventoryItem(self.unit, self.slot)
	elseif self.tooltip and self.tooltip ~= '' then
		GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
	else
		GameTooltip:Hide()
		return
	end
	GameTooltip:Show()
end

local function CreateSlotLabels(button, info)
	local outer, inner = SlotSides(info)
	local offsetX = LABEL_GAP_X * (outer == 'RIGHT' and 1 or -1)
	local labels = { button = button, gems = {} }

	labels.ilvl = overlay:CreateFontString(nil, 'OVERLAY')
	labels.ilvl:SetFont(BUILib.Font, ILVL_SIZE, '')
	labels.ilvl:SetJustifyH(inner)
	labels.ilvl:SetPoint(inner, button, outer, offsetX, LABEL_LINE_Y)

	labels.track = overlay:CreateFontString(nil, 'OVERLAY')
	labels.track:SetFont(BUILib.Font, TRACK_SIZE, '')
	labels.track:SetJustifyH(inner)
	labels.track:SetPoint(inner, button, outer, offsetX, 0)

	labels.enchant = overlay:CreateFontString(nil, 'OVERLAY')
	labels.enchant:SetFont(BUILib.Font, ENCHANT_SIZE, '')
	labels.enchant:SetJustifyH(inner)
	labels.enchant:SetWordWrap(false)
	labels.enchant:SetWidth(ENCHANT_NAME_W)
	labels.enchant:SetPoint(inner, button, outer, offsetX, -LABEL_LINE_Y)

	labels.hover = CreateFrame('Frame', nil, overlay)
	labels.hover:SetSize(ENCHANT_NAME_W, ENCHANT_HOVER_H)
	labels.hover:SetPoint(inner, button, outer, offsetX, -LABEL_LINE_Y)
	labels.hover:EnableMouse(true)
	labels.hover.anchor = outer == 'RIGHT' and 'ANCHOR_RIGHT' or 'ANCHOR_LEFT'
	SetScript(labels.hover, 'OnEnter', EnchantTooltip)
	SetScript(labels.hover, 'OnLeave', function() GameTooltip:Hide() end)
	labels.hover:Hide()

	return labels
end

local function UpdateSlotLabels(button)
	local labels, info = button._buiLabels, button._buiInfo
	if not labels then return end
	local unit = _G.InspectFrame.unit
	local slotID = button:GetID()
	local link = button.hasItem and unit and GetInventoryItemLink(unit, slotID)

	if not link or info.cosmetic then
		labels.ilvl:SetText('')
		labels.track:SetText('')
		labels.enchant:SetText('')
		labels.hover:Hide()
		RefreshGems(labels, nil)
		return
	end

	local trackText, trackColor = ReadUpgradeTrack(unit, slotID, link)
	local red, green, blue
	if trackColor then
		red, green, blue = trackColor[1], trackColor[2], trackColor[3]
	else
		red, green, blue = Skin.QualityColor(link)
	end

	local level = C_Item.GetDetailedItemLevelInfo(link)
	if level and not IsSecretValue(level) and level > 0 then
		labels.ilvl:SetText(level)
	else
		labels.ilvl:SetText('')
	end
	labels.ilvl:SetTextColor(red, green, blue, ILVL_ALPHA)

	labels.track:SetText(trackText or '')
	labels.track:SetTextColor(red, green, blue, TRACK_ALPHA)

	local canEnchant = CanHaveEnchant(info, link)
	local enchant = canEnchant and ReadEnchant(unit, slotID, link) or ''

	if enchant ~= '' then
		local icons = {}
		for atlas in enchant:gmatch('|A:[^|]+|a') do icons[#icons + 1] = atlas end
		local name = enchant:gsub('|A:[^|]+|a', ''):gsub('^%s+', ''):gsub('%s+$', '')
		name = name:gsub('^.-%s*%-%s*', '')
		labels.enchant:SetText(table.concat(icons, '') .. (#icons > 0 and ' ' or '') .. name)
		labels.enchant:SetTextColor(
			red + (1 - red) * ENCHANT_TINT,
			green + (1 - green) * ENCHANT_TINT,
			blue + (1 - blue) * ENCHANT_TINT, ENCHANT_ALPHA)
		labels.hover.tooltip = name
		labels.hover.unit, labels.hover.slot = unit, slotID
		labels.hover:Show()
	elseif canEnchant and AtEnchantLevel(unit) then
		labels.enchant:SetText('No Enchant')
		labels.enchant:SetTextColor(MISSING_COLOR[1], MISSING_COLOR[2], MISSING_COLOR[3], MISSING_COLOR[4])
		labels.hover.tooltip = 'Enchant missing'
		labels.hover.unit, labels.hover.slot = nil, nil
		labels.hover:Show()
	else
		labels.enchant:SetText('')
		labels.hover:Hide()
	end

	RefreshGems(labels, link)
end

local function RefreshSlot(button)
	if not Enabled() or not button._buiSlot then return end
	if button.IconBorder then button.IconBorder:SetAlpha(0) end
	ColorSlotEdges(button)
	UpdateSlotLabels(button)
end

local function SkinSlot(button, info)
	if not button or button._buiSlot then return end
	button._buiSlot = true
	button._buiInfo = info or {}
	slotButtons[#slotButtons + 1] = button
	FadeSlotArt(button)
	CropIcon(button.icon)
	Skin.TipIconFrame(button, button.icon)
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetBlendMode('BLEND')
		RowHighlight(button, SLOT_HOVER_ALPHA)
	end
	Face(button.Count)
	button._buiLabels = CreateSlotLabels(button, button._buiInfo)
	RefreshSlot(button)
end

local function SkinModel(model)
	if not model then return end
	FadeRegions(model)
	Shell(model)
end

local function SkinPaperDoll(paperDoll)
	if not paperDoll then return end
	overlay = overlay or CreateFrame('Frame', nil, paperDoll)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(paperDoll:GetFrameLevel() + OVERLAY_LEVEL_BUMP)
	if not totalLevelText then totalLevelText = CreateTotalLevelText() end
	Body(_G.InspectLevelText)
	Button(paperDoll.ViewButton)
	SkinModel(_G.InspectModelFrame)
	for _, slotName in ipairs(SLOT_NAMES) do SkinSlot(_G['Inspect' .. slotName .. 'Slot'], SLOT_INFO[slotName]) end
end

local function TalentsTab()
	local items = _G.InspectPaperDollItemsFrame
	local button = items and items.InspectTalents
	if not button then return nil end
	if button:GetParent() ~= _G.InspectFrame then button:SetParent(_G.InspectFrame) end
	if not button.Text then button.Text = button:GetFontString() end
	local reference = _G.InspectFrameTab1
	if reference then
		button:SetHeight(reference:GetHeight())
		button:SetFrameLevel(reference:GetFrameLevel())
	end
	return button
end

local function SkinPvpStat(stat)
	if not stat then return end
	Title(stat.BGType)
	for _, key in ipairs(PVP_STAT_LABEL_KEYS) do Skin.TipFont(stat[key], 'label') end
	for _, key in ipairs(PVP_STAT_VALUE_KEYS) do Body(stat[key]) end
end

local function SkinPvpTalentSlot(slot)
	if not slot or slot._buiPvpSlot then return end
	slot._buiPvpSlot = true
	Fade(slot.Shadow)
	Fade(slot.Border)
	local icon = slot.Texture
	if not icon then return end
	if slot.TextureMask then icon:RemoveMaskTexture(slot.TextureMask) end
	CropIcon(icon)
	Skin.TipIconFrame(slot, icon)
end

local function SkinPvp(pvp)
	if not pvp then return end
	Fade(pvp.BG)
	Body(pvp.HKs)
	Skin.TipFont(pvp.HonorLevel, 'title', HONOR_LEVEL_SCALE)
	for _, key in ipairs(PVP_STAT_KEYS) do SkinPvpStat(pvp[key]) end
	for slotIndex = 1, PVP_TALENT_SLOT_COUNT do SkinPvpTalentSlot(pvp['TalentSlot' .. slotIndex]) end
end

local function SkinGuild(guild)
	if not guild then return end
	Fade(_G.InspectGuildFrameBG)
	Skin.TipFont(guild.guildName, 'title', GUILD_NAME_SCALE)
	for _, key in ipairs(GUILD_TEXT_KEYS) do Body(guild[key]) end
	local points = guild.Points
	if points then
		FadeKeys(points, GUILD_POINTS_ART)
		Face(points.SumText)
	end
end

local function SkinMainFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Shell(frame.Inset)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	local tabs = {}
	for tabIndex = 1, BOTTOM_TAB_COUNT do tabs[tabIndex] = _G['InspectFrameTab' .. tabIndex] end
	local talents = TalentsTab()
	if talents then tabs[#tabs + 1] = talents end
	Skin.RegisterTabStrip(frame, tabs, context)
end

local function ShowSlotLabels(shown)
	for _, button in ipairs(slotButtons) do
		local labels = button._buiLabels
		if labels then
			labels.ilvl:SetShown(shown)
			labels.track:SetShown(shown)
			labels.enchant:SetShown(shown)
			if not shown then
				labels.hover:Hide()
				for _, gem in ipairs(labels.gems) do gem:Hide() end
			end
		end
	end
	if totalLevelText then totalLevelText:SetShown(shown) end
end

local function Apply()
	local frame = _G.InspectFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinMainFrame(frame)
		SkinPaperDoll(_G.InspectPaperDollFrame)
		SkinPvp(_G.InspectPVPFrame)
		SkinGuild(_G.InspectGuildFrame)
	end
	ShowSlotLabels(true)
	for _, button in ipairs(slotButtons) do RefreshSlot(button) end
	UpdateTotalLevel()
	Skin.RefreshTabStrip(frame)
end

local function Install()
	if installed then return end
	local frame = _G.InspectFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	hooksecurefunc('InspectPaperDollItemSlotButton_Update', RefreshSlot)
	BUI.Events:Register('INSPECT_READY', 'Skin.InspectLevels', function()
		if not Enabled() or not skinned then return end
		for _, button in ipairs(slotButtons) do RefreshSlot(button) end
		UpdateTotalLevel()
		Skin.RefreshTabStrip(_G.InspectFrame)
	end)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Inspect') end
end

local function Deactivate()
	context.Restore()
	ShowSlotLabels(false)
	skinned = false
	BUI.Print('Inspect skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.Inspect', TryInstall)
		elseif _G.InspectFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Inspect',
	description = 'The inspect window: dark shell, house tabs, framed equipment slots with quality edges and item levels, flat PvP ratings and guild panel. Preview needs an inspectable target.',
	icon = 'Interface/Icons/INV_Misc_Spyglass_03',
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.InspectInstall', function()
	if not Enabled() then return end
	Install()
	if not installed then BUI.Events:Register('ADDON_LOADED', 'Skin.Inspect', TryInstall) end
end)
