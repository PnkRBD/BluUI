local _, BUI = ...

local ipairs = ipairs
local floor = math.floor

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Readout = Skin.Readout
local IsSecretValue = BUI.Tools.IsSecretValue

local BOTTOM_TAB_COUNT = 3
local PVP_TALENT_SLOT_COUNT = 3
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
local READOUT_SIZE = 24
local READOUT_INSET_X = 8
local READOUT_TOP = -20
local READOUT_REACH_X = 110
local READOUT_BOTTOM = -67
local TOTAL_LEVEL_COLOR = { 1, 0.82, 0, 1 }
local SCALE_SETTING = 'inspectScale'
local ENCHANT_SIZE = 9
local ENCHANT_NAME_W = 100
local ENCHANT_HOVER_H = 14
local OVERLAY_LEVEL_BUMP = 20
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

local skinned = false
local slotButtons = {}
local totalLevelText, ratingText
local overlay

local context = Skin.Define('inspect', {
	name = 'Inspect',
	description = 'The inspect window: dark shell, house tabs, framed equipment slots with quality edges and item levels, their M+ rating, flat PvP ratings and guild panel. Preview needs an inspectable target.',
	icon = 'Interface/Icons/INV_Misc_Spyglass_03',
})
local Enabled = context.Enabled
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button = context.Shell, context.Button
local Face, Title, Body = context.Face, context.Title, context.Body
local CropIcon, RowHighlight = Skin.CropIcon, Skin.RowHighlight

local function SlotSides(info)
	if info.col == 'left' or info.col == 'offhand' then return 'RIGHT', 'LEFT' end
	return 'LEFT', 'RIGHT'
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

local function CreateReadout(side)
	local text = overlay:CreateFontString(nil, 'OVERLAY', nil, 7)
	text:SetFont(BUILib.Font, READOUT_SIZE, 'OUTLINE')
	text:SetShadowColor(0, 0, 0, 0)
	text:SetJustifyH(side)
	text:SetJustifyV('MIDDLE')
	local anchor, corner = _G.InspectPaperDollItemsFrame, 'TOP' .. side
	local sign = side == 'RIGHT' and -1 or 1
	text:SetPoint(corner, anchor, corner, sign * READOUT_INSET_X, READOUT_TOP)
	text:SetPoint(side == 'RIGHT' and 'BOTTOMLEFT' or 'BOTTOMRIGHT', anchor, corner, sign * READOUT_REACH_X, READOUT_BOTTOM)
	return text
end

local function UpdateTotalLevel()
	if not totalLevelText then return end
	local unit = _G.InspectFrame.unit
	local level = unit and C_PaperDollInfo.GetInspectItemLevel(unit)
	if level and not IsSecretValue(level) and level > 0 then
		totalLevelText:SetText(floor(level + 0.5))
	else
		totalLevelText:SetText('')
	end
end

local function UpdateRating()
	if not ratingText then return end
	local unit = _G.InspectFrame.unit
	local summary = unit and C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
	local score = summary and summary.currentSeasonScore
	if score and not IsSecretValue(score) and score > 0 then
		ratingText:SetText(floor(score))
		ratingText:SetTextColor(C_ChallengeMode.GetDungeonScoreRarityColor(score):GetRGB())
	else
		ratingText:SetText('')
	end
end

local function ApplyScale()
	_G.InspectFrame:SetScale(BUI.GetDB().skinning[SCALE_SETTING] / 100)
end

local function ColorSlotEdges(button)
	local unit = _G.InspectFrame.unit
	if button.hasItem and unit then
		Skin.SetIconEdgeColor(button.icon, Skin.QualityColor(GetInventoryItemID(unit, button:GetID())))
	else
		Skin.SetIconEdgeColor(button.icon)
	end
end

local gemMetrics = { size = GEM_SIZE, pad = GEM_PAD, inset = GEM_INSET }


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
	labels.hover:SetScript('OnEnter', BUI.Profiler.Script('Skin.Inspect hover OnEnter', EnchantTooltip))
	labels.hover:SetScript('OnLeave', BUI.Profiler.Script('Skin.Inspect hover OnLeave', function() GameTooltip:Hide() end))
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
		Readout.RefreshGems(labels, nil, gemMetrics)
		return
	end

	local canEnchant = Readout.CanHaveEnchant(info, link)
	local trackText, trackColor, enchant = Readout.Read(unit, slotID, link, canEnchant)
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

	if enchant ~= '' then
		Readout.PaintEnchant(labels.enchant, labels.hover, enchant, red, green, blue)
		labels.hover.unit, labels.hover.slot = unit, slotID
		labels.hover:Show()
	elseif canEnchant and Readout.AtEnchantLevel(unit) then
		Readout.PaintMissingEnchant(labels.enchant, labels.hover)
		labels.hover.unit, labels.hover.slot = nil, nil
		labels.hover:Show()
	else
		labels.enchant:SetText('')
		labels.hover:Hide()
	end

	Readout.RefreshGems(labels, link, gemMetrics)
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
	Skin.TipCount(button.Count)
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
	gemMetrics.parent = overlay
	if not totalLevelText then
		totalLevelText = CreateReadout('RIGHT')
		totalLevelText:SetTextColor(TOTAL_LEVEL_COLOR[1], TOTAL_LEVEL_COLOR[2], TOTAL_LEVEL_COLOR[3], TOTAL_LEVEL_COLOR[4])
		ratingText = CreateReadout('LEFT')
	end
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
	context.Chrome(frame)
	Shell(frame.Inset)
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
	if totalLevelText then
		totalLevelText:SetShown(shown)
		ratingText:SetShown(shown)
	end
end

local function SkinFrame(frame)
	skinned = true
	SkinMainFrame(frame)
	SkinPaperDoll(_G.InspectPaperDollFrame)
	SkinPvp(_G.InspectPVPFrame)
	SkinGuild(_G.InspectGuildFrame)
end

local function RefreshReadouts()
	for _, button in ipairs(slotButtons) do RefreshSlot(button) end
	UpdateTotalLevel()
	UpdateRating()
end

local function RefreshFrame(frame)
	ShowSlotLabels(true)
	RefreshReadouts()
	ApplyScale()
	Skin.RefreshTabStrip(frame)
end

local function InstallFrame()
	context.Hook('InspectPaperDollItemSlotButton_Update', RefreshSlot)
	BUI.Events:Register('INSPECT_READY', 'Skin.InspectLevels', function()
		if not Enabled() or not skinned then return end
		RefreshReadouts()
		Skin.RefreshTabStrip(_G.InspectFrame)
	end)
end

context.Window('InspectFrame', { skin = SkinFrame, show = RefreshFrame, install = InstallFrame, enable = ApplyScale })

context.OnDisable(function()
	skinned = false
	ShowSlotLabels(false)
	if _G.InspectFrame then _G.InspectFrame:SetScale(1) end
end)

context.info.settings = {
	{
		label = 'Scale %', min = 80, max = 150, step = 5,
		get = function() return BUI.GetDB().skinning[SCALE_SETTING] end,
		set = function(value)
			BUI.GetDB().skinning[SCALE_SETTING] = value
			if _G.InspectFrame then ApplyScale() end
		end,
	},
}
