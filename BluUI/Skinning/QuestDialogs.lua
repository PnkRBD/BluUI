local _, BUI = ...

local ipairs, pairs = ipairs, pairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Theme = BUILib.Theme

local SKIN_ID = 'questdialogs'
local MAIN_ART = { 'Bg', 'TopTileStreaks', 'Inset' }
local QUEST_TITLE_SCALE = 1.25
local SECTION_TITLE_SCALE = 1.1
local ROW_HOVER_ALPHA = 0.12
local ITEM_HIGHLIGHT_ALPHA = 0.18
local ITEM_HIGHLIGHT_OFFSET_X, ITEM_HIGHLIGHT_OFFSET_Y = 8, -7
local ITEM_BUTTON_WIDTH, ITEM_BUTTON_HEIGHT = 147, 41
local PROGRESS_ITEM_COUNT = 6
local BODY_TEXT = { 0.87, 0.87, 0.9, 1 }
local SHORT_MONEY_TEXT = { 0.9, 0.35, 0.35, 1 }
local HTML_ELEMENTS = { P = 12, H1 = 16, H2 = 14, H3 = 13 }
local MONEY_BUTTON_KEYS = { 'GoldButton', 'SilverButton', 'CopperButton' }
local QUEST_PANEL_NAMES = { 'QuestFrameGreetingPanel', 'QuestFrameDetailPanel', 'QuestFrameProgressPanel', 'QuestFrameRewardPanel' }
local QUEST_SCROLL_NAMES = { 'QuestGreetingScrollFrame', 'QuestDetailScrollFrame', 'QuestProgressScrollFrame', 'QuestRewardScrollFrame' }
local QUEST_BUTTON_NAMES = {
	'QuestFrameAcceptButton', 'QuestFrameDeclineButton', 'QuestFrameCompleteButton',
	'QuestFrameGoodbyeButton', 'QuestFrameCompleteQuestButton', 'QuestFrameGreetingGoodbyeButton',
}
local PANEL_TEXT_STYLES = {
	GreetingText = { 'body', 1 },
	QuestProgressText = { 'body', 1 },
	CurrentQuestsText = { 'title', SECTION_TITLE_SCALE },
	AvailableQuestsText = { 'title', SECTION_TITLE_SCALE },
	QuestProgressRequiredItemsText = { 'title', SECTION_TITLE_SCALE },
	QuestProgressTitleText = { 'title', QUEST_TITLE_SCALE },
}
local INFO_HEADER_NAMES = { 'QuestInfoDescriptionHeader', 'QuestInfoObjectivesHeader' }
local INFO_BODY_NAMES = {
	'QuestInfoQuestType', 'QuestInfoObjectivesText', 'QuestInfoRewardText', 'QuestInfoGroupSize',
	'QuestInfoDescriptionText', 'QuestInfoTimerText', 'QuestInfoSpellObjectiveLearnLabel',
}
local REWARD_TEXT_KEYS = { 'ItemChooseText', 'ItemReceiveText', 'PlayerTitleText', 'QuestSessionBonusReward' }
local REWARD_ITEM_KEYS = { 'HonorFrame', 'WarModeBonusFrame', 'ArtifactXPFrame', 'SkillPointFrame' }
local TITLE_FRAME_ART = { 'FrameLeft', 'FrameCenter', 'FrameRight' }
local FRIENDSHIP_ART = { 'BarBorder', 'BarRingBackground', 'BarCircle', 'Notch1', 'Notch2', 'Notch3', 'Notch4' }
local MODEL_SCENE_ART = { 'ModelBackground', 'ModelNameDivider', 'ModelNameBackground', 'ShadowOverlay', 'Border', 'TopBarBg' }
local GOSSIP_MEASURE_KEYS = { 'greetingTextFrame', 'titleOptionButton', 'availableQuestButton', 'activeQuestButton' }

local installed = false
local questSkinned = false
local gossipSkinned = false
local itemTextSkinned = false
local questPanelTexts = {}
local questInfoParents = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close = context.Shell, context.Button, context.Close
local ScrollBar, Face, Body, Title = context.ScrollBar, context.Face, context.Body, context.Title
local FlatTexture, AccentTexture, RowHighlight, CropIcon = Skin.FlatTexture, Skin.AccentTexture, Skin.RowHighlight, Skin.CropIcon

local function SetColor(fontString, color)
	if fontString then fontString:SetTextColor(color[1], color[2], color[3], color[4]) end
end

local function FadeTexturesExcept(frame, keepFirst, keepSecond)
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region ~= keepFirst and region ~= keepSecond and region:IsObjectType('Texture') and not region:IsObjectType('MaskTexture') then Fade(region) end
	end
end

local function BodyRegions(frame)
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region:IsObjectType('FontString') then Body(region) end
	end
end

local function FaceMoney(frame)
	if not frame then return end
	for _, key in ipairs(MONEY_BUTTON_KEYS) do
		local button = frame[key]
		if button then Face(button.Text) end
	end
end

local function SkinPanelFrame(frame)
	FadeRegions(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
end

local function SkinFriendshipBar(bar)
	if not bar then return end
	FadeKeys(bar, FRIENDSHIP_ART)
	FadeTexturesExcept(bar, bar.icon, bar.Bar)
	bar:SetStatusBarTexture(BUI.GetGlobalTexture())
	Shell(bar)
end

local function SkinListRow(button)
	if not button._buiQuestRow then
		button._buiQuestRow = true
		local highlight = button:GetHighlightTexture()
		if highlight then highlight:SetBlendMode('BLEND') end
		RowHighlight(button, ROW_HOVER_ALPHA)
	end
	local fontString = button:GetFontString()
	if not fontString then return end
	fontString:SetFixedColor(true)
	Body(fontString)
end

local function SkinRewardIcon(button)
	if not button or button._buiRewardIcon then return end
	button._buiRewardIcon = true
	Fade(button.NameFrame)
	Fade(button.IconOverlay)
	Fade(button.IconOverlay2)
	Fade(button.IconBorder)
	CropIcon(button.Icon)
	Skin.TipIconFrame(button, button.Icon)
	Face(button.Name)
	Face(button.Count)
end

local function RefreshQualityEdge(button)
	Skin.SetIconEdgeQuality(button.Icon, button.IconBorder)
end

local function OnItemButtonQuality(button)
	if Enabled() and button and button._buiRewardIcon then RefreshQualityEdge(button) end
end

local function SkinSpellReward(button)
	if not button or button._buiSpellReward then return end
	button._buiSpellReward = true
	FadeTexturesExcept(button, button.Icon)
	CropIcon(button.Icon)
	Skin.TipIconFrame(button, button.Icon)
	Face(button.Name)
end

local function SkinFollowerReward(button)
	if button._buiFollowerReward then return end
	button._buiFollowerReward = true
	Fade(button.BG)
	Face(button.Name)
end

local function SkinReputationReward(button)
	if button._buiReputationReward then return end
	button._buiReputationReward = true
	Fade(button.NameFrame)
	CropIcon(button.Icon)
	Skin.TipIconFrame(button, button.Icon)
	Face(button.Name)
	Face(button.RewardAmount)
end

local function SkinItemHighlight(highlight)
	if not highlight or highlight._buiItemHighlight then return end
	highlight._buiItemHighlight = true
	FadeRegions(highlight)
	local fill = highlight:CreateTexture(nil, 'BACKGROUND')
	fill.__buiSkin = true
	fill:SetPoint('TOPLEFT', highlight, 'TOPLEFT', ITEM_HIGHLIGHT_OFFSET_X, ITEM_HIGHLIGHT_OFFSET_Y)
	fill:SetSize(ITEM_BUTTON_WIDTH, ITEM_BUTTON_HEIGHT)
	AccentTexture(fill, ITEM_HIGHLIGHT_ALPHA)
end

local function SkinRewardsFrame(rewards)
	for _, key in ipairs(REWARD_ITEM_KEYS) do SkinRewardIcon(rewards[key]) end
	local artifact = rewards.ArtifactXPFrame
	if artifact then Fade(artifact.Overlay) end
	local skill = rewards.SkillPointFrame
	if skill then
		Fade(skill.CircleBackground)
		Fade(skill.CircleBackgroundGlow)
		Face(skill.ValueText)
	end
	local titleFrame = rewards.TitleFrame
	if titleFrame then
		FadeKeys(titleFrame, TITLE_FRAME_ART)
		CropIcon(titleFrame.Icon)
		Skin.TipIconFrame(titleFrame, titleFrame.Icon)
		Face(titleFrame.Name)
	end
	if rewards.XPFrame then Face(rewards.XPFrame.ValueText) end
	FaceMoney(rewards.MoneyFrame)
	SkinItemHighlight(rewards.ItemHighlight)
end

local function RecolorObjectives()
	local objectives = _G.QuestInfoObjectivesFrame.Objectives
	local completeSuffix = '(' .. COMPLETE .. ')'
	for _, objective in ipairs(objectives) do
		if objective:IsShown() then
			local text = objective:GetText()
			local finished = text and text:sub(-#completeSuffix) == completeSuffix
			Skin.TipFont(objective, finished and 'label' or 'body')
		end
	end
end

local function RecolorMoneyLabel(fontString, required)
	Body(fontString)
	if required > GetMoney() then SetColor(fontString, SHORT_MONEY_TEXT) end
end

local function SweepRewards()
	local rewards = _G.QuestInfoRewardsFrame
	for _, button in ipairs(rewards.RewardButtons) do
		SkinRewardIcon(button)
		RefreshQualityEdge(button)
	end
	for header in rewards.spellHeaderPool:EnumerateActive() do Body(header) end
	for button in rewards.spellRewardPool:EnumerateActive() do SkinSpellReward(button) end
	for button in rewards.followerRewardPool:EnumerateActive() do SkinFollowerReward(button) end
	for button in rewards.reputationRewardPool:EnumerateActive() do SkinReputationReward(button) end
end

local function RefreshQuestInfo()
	Skin.TipFont(_G.QuestInfoTitleHeader, 'title', QUEST_TITLE_SCALE)
	for _, name in ipairs(INFO_HEADER_NAMES) do Skin.TipFont(_G[name], 'title', SECTION_TITLE_SCALE) end
	for _, name in ipairs(INFO_BODY_NAMES) do Body(_G[name]) end
	local rewards = _G.QuestInfoRewardsFrame
	Skin.TipFont(rewards.Header, 'title', SECTION_TITLE_SCALE)
	for _, key in ipairs(REWARD_TEXT_KEYS) do Body(rewards[key]) end
	Body(rewards.XPFrame.ReceiveText)
	RecolorMoneyLabel(_G.QuestInfoRequiredMoneyText, C_QuestLog.GetRequiredMoney())
	RecolorObjectives()
	SweepRewards()
end
Skin.RefreshQuestInfoText = RefreshQuestInfo

local function QuestInfoOnQuestFrame()
	return questInfoParents[_G.QuestInfoRewardsFrame:GetParent()] == true
end

local function OnQuestInfoDisplay(_, parentFrame)
	if Enabled() and questInfoParents[parentFrame] then RefreshQuestInfo() end
end

local function OnQuestInfoRewards()
	if Enabled() and QuestInfoOnQuestFrame() then SweepRewards() end
end

local function StylePanelText(fontString)
	local style = questPanelTexts[fontString]
	if style then Skin.TipFont(fontString, style[1], style[2]) end
end

local function OnPanelText(fontString)
	if Enabled() then StylePanelText(fontString) end
end

local function RefreshGreeting()
	local panel = _G.QuestFrameGreetingPanel
	for button in panel.titleButtonPool:EnumerateActive() do
		SkinListRow(button)
		button:SetHeight(math.max(button:GetTextHeight() + 2, button.Icon:GetHeight()))
	end
end

local function OnGreetingShown()
	if Enabled() then RefreshGreeting() end
end

local function RefreshProgress()
	RecolorMoneyLabel(_G.QuestProgressRequiredMoneyText, GetQuestMoneyToGet())
	for itemIndex = 1, PROGRESS_ITEM_COUNT do
		local button = _G['QuestProgressItem' .. itemIndex]
		if button then RefreshQualityEdge(button) end
	end
end

local function OnProgressItems()
	if Enabled() then RefreshProgress() end
end

local function SkinGreetingBreak(texture)
	if not texture then return end
	Fade(texture)
	if texture._buiBreakLine then return end
	texture._buiBreakLine = true
	local line = texture:GetParent():CreateTexture(nil, 'ARTWORK')
	line.__buiSkin = true
	line:SetHeight(1)
	line:SetPoint('LEFT', texture, 'LEFT', 0, 0)
	line:SetPoint('RIGHT', texture, 'RIGHT', 0, 0)
	local edge = Skin.PANEL_EDGE
	FlatTexture(line, edge[1], edge[2], edge[3], edge[4])
end

local function SkinModelScene(scene)
	if not scene then return end
	FadeKeys(scene, MODEL_SCENE_ART)
	Shell(scene)
	Title(_G.QuestNPCModelNameText)
	local textFrame = scene.ModelTextFrame
	if textFrame then
		Fade(textFrame.TextBackground)
		Shell(textFrame)
	end
	Body(_G.QuestNPCModelText)
	local scroll = _G.QuestNPCModelTextScrollFrame
	if scroll then ScrollBar(scroll.ScrollBar) end
end

local function SkinQuestFrame(frame)
	SkinPanelFrame(frame)
	Fade(_G.QuestFramePortrait)
	local notice = frame.AccountCompletedNotice
	if notice then Skin.TipFont(notice.Text, 'label') end
	SkinFriendshipBar(frame.FriendshipStatusBar)
	for _, name in ipairs(QUEST_PANEL_NAMES) do FadeRegions(_G[name]) end
	for _, name in ipairs(QUEST_SCROLL_NAMES) do
		local scroll = _G[name]
		FadeRegions(scroll)
		Shell(scroll)
		ScrollBar(scroll.ScrollBar)
	end
	for _, name in ipairs(QUEST_BUTTON_NAMES) do Button(_G[name]) end
	for fontString in pairs(questPanelTexts) do StylePanelText(fontString) end
	SkinGreetingBreak(_G.QuestGreetingFrameHorizontalBreak)
	Skin.TipFont(_G.QuestProgressRequiredMoneyText, 'label')
	FaceMoney(_G.QuestProgressRequiredMoneyFrame)
	for itemIndex = 1, PROGRESS_ITEM_COUNT do SkinRewardIcon(_G['QuestProgressItem' .. itemIndex]) end
	SkinRewardsFrame(_G.QuestInfoRewardsFrame)
	SkinSpellReward(_G.QuestInfoSpellObjectiveFrame)
	FaceMoney(_G.QuestInfoRequiredMoneyDisplay)
	SkinModelScene(_G.QuestModelScene)
end

local function SkinGossipRow(row)
	if row.GreetingText then
		row.GreetingText:SetFixedColor(true)
		Body(row.GreetingText)
	elseif row.GetFontString then
		SkinListRow(row)
	end
end

local function FontGossipMeasures(scrollBox)
	local provider = scrollBox:GetDataProvider()
	if not provider then return end
	for _, elementData in provider:EnumerateEntireRange() do
		for _, key in ipairs(GOSSIP_MEASURE_KEYS) do
			local measure = elementData[key]
			if measure and not measure._buiMeasure then
				measure._buiMeasure = true
				if measure.GreetingText then
					Face(measure.GreetingText)
				elseif measure.GetFontString then
					Face(measure:GetFontString())
				end
			end
		end
	end
end

local function RefreshGossip()
	local scrollBox = _G.GossipFrame.GreetingPanel.ScrollBox
	Skin.ForEachScrollFrame(scrollBox, SkinGossipRow)
	FontGossipMeasures(scrollBox)
end

local function OnGossipUpdated()
	if Enabled() and gossipSkinned then RefreshGossip() end
end

local function SkinGossipFrame(frame)
	SkinPanelFrame(frame)
	SkinFriendshipBar(frame.FriendshipStatusBar)
	local panel = frame.GreetingPanel
	FadeRegions(panel)
	Shell(panel.ScrollBox)
	ScrollBar(panel.ScrollBar)
	Button(panel.GoodbyeButton)
	Skin.SweepScrollBox(panel.ScrollBox, SkinGossipRow)
end

local function StylePageHtml()
	local html = _G.ItemTextPageText
	for element, size in pairs(HTML_ELEMENTS) do
		html:SetFont(element, BUILib.Font, size, '')
		html:SetTextColor(element, BODY_TEXT[1], BODY_TEXT[2], BODY_TEXT[3])
	end
end

local function OnItemTextEvent(_, event)
	if Enabled() and event == 'ITEM_TEXT_BEGIN' then StylePageHtml() end
end

local function SkinPageButton(button, direction)
	if not button then return end
	Skin.TipPageButton(button, direction)
	BodyRegions(button)
end

local function SkinItemTextFrame(frame)
	SkinPanelFrame(frame)
	Body(_G.ItemTextCurrentPage)
	local scroll = _G.ItemTextScrollFrame
	Shell(scroll)
	ScrollBar(scroll.ScrollBar)
	StylePageHtml()
	SkinPageButton(_G.ItemTextPrevPageButton, 'previous')
	SkinPageButton(_G.ItemTextNextPageButton, 'next')
	local bar = _G.ItemTextStatusBar
	if bar then
		FadeRegions(bar)
		bar:SetStatusBarTexture(BUI.GetGlobalTexture())
		local red, green, blue = Theme.GetAccent()
		bar:SetStatusBarColor(red, green, blue, 1)
		Shell(bar)
	end
end

local function ApplyQuest()
	local frame = _G.QuestFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not questSkinned then
		questSkinned = true
		SkinQuestFrame(frame)
	end
	if _G.QuestFrameGreetingPanel:IsShown() then RefreshGreeting() end
	if _G.QuestFrameProgressPanel:IsShown() then RefreshProgress() end
	if QuestInfoOnQuestFrame() then RefreshQuestInfo() end
end

local function ApplyGossip()
	local frame = _G.GossipFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not gossipSkinned then
		gossipSkinned = true
		SkinGossipFrame(frame)
	end
	RefreshGossip()
end

local function ApplyItemText()
	local frame = _G.ItemTextFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not itemTextSkinned then
		itemTextSkinned = true
		SkinItemTextFrame(frame)
	end
	StylePageHtml()
end

local function Apply()
	ApplyQuest()
	ApplyGossip()
	ApplyItemText()
end

local function HookQuest(frame)
	frame:HookScript('OnShow', ApplyQuest)
	hooksecurefunc('QuestInfo_Display', OnQuestInfoDisplay)
	hooksecurefunc('QuestInfo_ShowRewards', OnQuestInfoRewards)
	hooksecurefunc('QuestFrame_SetTextColor', OnPanelText)
	hooksecurefunc('QuestFrame_SetTitleTextColor', OnPanelText)
	hooksecurefunc('QuestFrameGreetingPanel_OnShow', OnGreetingShown)
	hooksecurefunc('QuestFrameProgressItems_Update', OnProgressItems)
	hooksecurefunc('SetItemButtonQuality', OnItemButtonQuality)
end

local function HookGossip(frame)
	frame:HookScript('OnShow', ApplyGossip)
	hooksecurefunc(frame, 'Update', OnGossipUpdated)
end

local function HookItemText(frame)
	frame:HookScript('OnShow', ApplyItemText)
	hooksecurefunc('ItemTextFrame_OnEvent', OnItemTextEvent)
end

local function Install()
	if installed then return end
	local quest, gossip, itemText = _G.QuestFrame, _G.GossipFrame, _G.ItemTextFrame
	if not quest or not gossip or not itemText then return end
	installed = true
	for name, style in pairs(PANEL_TEXT_STYLES) do questPanelTexts[_G[name]] = style end
	questInfoParents[_G.QuestDetailScrollChildFrame] = true
	questInfoParents[_G.QuestRewardScrollChildFrame] = true
	HookQuest(quest)
	HookGossip(gossip)
	HookItemText(itemText)
	if quest:IsShown() then ApplyQuest() end
	if gossip:IsShown() then ApplyGossip() end
	if itemText:IsShown() then ApplyItemText() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.QuestDialogs') end
end

local function Deactivate()
	context.Restore()
	questSkinned = false
	gossipSkinned = false
	itemTextSkinned = false
	BUI.Print('Quest Dialogs skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.QuestDialogs', TryInstall)
		else
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Quest Dialogs',
	description = 'NPC quest offers, turn-ins, gossip menus and readable books: dark shells, house text on the parchment, framed reward icons and house buttons. Only visible while talking to an NPC or reading an object, so there is no preview.',
	icon = 'Interface/QuestFrame/UI-QuestLog-BookIcon',
})
