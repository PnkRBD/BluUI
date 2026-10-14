local _, BUI = ...

local Wrap = BUI.Profiler.Wrap

local ipairs, pairs = ipairs, pairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local SELECTED = Skin.SELECTED_COLOR

local QUEST_TITLE_SCALE = 1.25
local SECTION_TITLE_SCALE = 1.1
local PANEL = { INSET = 6, TOP = -65, BOTTOM = 28, BAR_INSET = 4, BAR_LEVEL = 10, ROW_PAD = 10, ICON_X = 3 }
local GOSSIP = { CARD_INSET = { top = -5, bottom = -5 }, PAD = 8, SPACING = 12, DIVIDER = 1, BAR_SPACE = 20 }
local GREETING = { PAD = 8, TEXT_GAP = 4, BREAK_X = 22 }
GREETING.CARD_INSET = { left = GREETING.PAD, right = GREETING.PAD }
local ITEM_HIGHLIGHT_ALPHA = 0.12
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
local ADVENTURE_ART = { 'Background', 'Rewards' }
local ADVENTURE_BODY_KEYS = { 'DescriptionText', 'ObjectivesText' }

local questPanelTexts = {}
local questInfoParents = {}
local breakLine

local context = Skin.Define('questdialogs', {
	name = 'Quest Dialogs',
	description = 'NPC quest offers, turn-ins, gossip menus, readable books and the quest offers on the Prey scouting map: dark shells, library style text and buttons, and framed reward icons. Only visible while talking to an NPC or reading an object, so there is no preview.',
	icon = 'Interface/QuestFrame/UI-QuestLog-BookIcon',
	newLook = true,
})
local Enabled = context.Enabled
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, Card = context.Shell, context.Button, context.Close, context.Card
local ScrollBar, Face, Body, Title = context.ScrollBar, context.Face, context.Body, context.Title
local SelectedTexture, CropIcon = Skin.SelectedTexture, Skin.CropIcon

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

local function WideScroll(frame, scroll, scrollBar)
	scroll:ClearAllPoints()
	scroll:SetPoint('TOPLEFT', frame, 'TOPLEFT', PANEL.INSET, PANEL.TOP)
	scroll:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -PANEL.INSET, PANEL.BOTTOM)
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint('TOPRIGHT', scroll, 'TOPRIGHT', -PANEL.BAR_INSET, -PANEL.BAR_INSET)
	scrollBar:SetPoint('BOTTOMRIGHT', scroll, 'BOTTOMRIGHT', -PANEL.BAR_INSET, PANEL.BAR_INSET)
	scrollBar:SetFrameLevel(scroll:GetFrameLevel() + PANEL.BAR_LEVEL)
	scrollBar:SetHideIfUnscrollable(true)
	Fade(scrollBar.Back)
	Fade(scrollBar.Forward)
end

local function SkinFriendshipBar(bar)
	if not bar then return end
	FadeKeys(bar, FRIENDSHIP_ART)
	FadeTexturesExcept(bar, bar.icon, bar.Bar)
	bar:SetStatusBarTexture(BUI.GetGlobalTexture())
	Shell(bar)
end

local function SkinListRow(button, inset)
	local fontString = button:GetFontString()
	if not fontString then return end
	fontString:SetFixedColor(true)
	Body(fontString)
	Fade(button:GetHighlightTexture())
	Card(button, inset)
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
	Skin.TipCount(button.Count)
end

local function RefreshQualityEdge(button)
	Skin.SetIconEdgeQuality(button.Icon, button.IconBorder)
end

local function OnItemButtonQuality(button)
	if button and button._buiRewardIcon then RefreshQualityEdge(button) end
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
	SelectedTexture(fill, ITEM_HIGHLIGHT_ALPHA)
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
	if questInfoParents[parentFrame] then RefreshQuestInfo() end
end

local function OnQuestInfoRewards()
	if QuestInfoOnQuestFrame() then SweepRewards() end
end

local function StylePanelText(fontString)
	local style = questPanelTexts[fontString]
	if style then Skin.TipFont(fontString, style[1], style[2]) end
end

local function GreetingRowWidth()
	return _G.QuestFrame:GetWidth() - 2 * PANEL.INSET
end

local function LayoutGreetingRow(button, width)
	SkinListRow(button, GREETING.CARD_INSET)
	button:SetWidth(width)
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint('LEFT', GREETING.PAD + PANEL.ICON_X, 0)
	local text = button:GetFontString()
	text:ClearAllPoints()
	text:SetPoint('LEFT', button.Icon, 'RIGHT', GREETING.TEXT_GAP, 0)
	text:SetPoint('RIGHT', -GREETING.PAD - PANEL.ICON_X, 0)
	button:SetHeight(math.max(button:GetTextHeight() + 2, button.Icon:GetHeight()) + PANEL.ROW_PAD)
end

local function RefreshGreeting()
	local width = GreetingRowWidth()
	for button in _G.QuestFrameGreetingPanel.titleButtonPool:EnumerateActive() do LayoutGreetingRow(button, width) end
	breakLine:SetShown(_G.QuestGreetingFrameHorizontalBreak:IsShown())
end

local function RefreshProgress()
	RecolorMoneyLabel(_G.QuestProgressRequiredMoneyText, GetQuestMoneyToGet())
	for itemIndex = 1, PROGRESS_ITEM_COUNT do
		local button = _G['QuestProgressItem' .. itemIndex]
		if button then RefreshQualityEdge(button) end
	end
end

local function BuildBreakLine()
	local texture = _G.QuestGreetingFrameHorizontalBreak
	breakLine = context.Own(texture:GetParent():CreateTexture(nil, 'ARTWORK'))
	BUI.Painter.Fill(breakLine, 'skinBorder')
	local startInset = GREETING.PAD - GREETING.BREAK_X
	local endInset = GREETING.BREAK_X + texture:GetWidth() - GreetingRowWidth() + GREETING.PAD
	BUILib.Skin.PixelLine(breakLine, texture, false, startInset, endInset)
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
	context.Chrome(frame)
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
		WideScroll(frame, scroll, scroll.ScrollBar)
	end
	for _, name in ipairs(QUEST_BUTTON_NAMES) do Button(_G[name]) end
	for fontString in pairs(questPanelTexts) do StylePanelText(fontString) end
	Fade(_G.QuestGreetingFrameHorizontalBreak)
	Skin.TipFont(_G.QuestProgressRequiredMoneyText, 'label')
	FaceMoney(_G.QuestProgressRequiredMoneyFrame)
	for itemIndex = 1, PROGRESS_ITEM_COUNT do SkinRewardIcon(_G['QuestProgressItem' .. itemIndex]) end
	SkinRewardsFrame(_G.QuestInfoRewardsFrame)
	SkinSpellReward(_G.QuestInfoSpellObjectiveFrame)
	FaceMoney(_G.QuestInfoRequiredMoneyDisplay)
	SkinModelScene(_G.QuestModelScene)
end

local function SkinAdventureReward(reward)
	Fade(reward.ItemNameBG)
	Fade(reward.Overlay)
	CropIcon(reward.Icon)
	Skin.TipIconFrame(reward, reward.Icon)
	Face(reward.Name)
	Skin.TipCount(reward.Count)
end

local function RefreshAdventureRewards(dialog)
	for reward in dialog.rewardPool:EnumerateActive() do SkinAdventureReward(reward) end
end

local function SkinAdventureDialog(dialog)
	FadeKeys(dialog, ADVENTURE_ART)
	Shell(dialog)
	Close(dialog.CloseButton)
	Button(dialog.AcceptButton)
	Button(dialog.DeclineButton)
	ScrollBar(dialog.Details.ScrollBar)
	local child = dialog.Details.Child
	Skin.TipFont(child.TitleHeader, 'title', QUEST_TITLE_SCALE)
	Skin.TipFont(child.ObjectivesHeader, 'title', SECTION_TITLE_SCALE)
	for _, key in ipairs(ADVENTURE_BODY_KEYS) do Body(child[key]) end
	Skin.TipFont(dialog.RewardsHeader, 'title', SECTION_TITLE_SCALE)
	SkinModelScene(_G.QuestModelScene)
end

local function SkinGossipRow(row)
	if row.GreetingText then
		row.GreetingText:SetFixedColor(true)
		Body(row.GreetingText)
		row.GreetingText:ClearAllPoints()
		row.GreetingText:SetPoint('TOPLEFT', PANEL.ICON_X, 0)
	elseif row.GetFontString then
		SkinListRow(row, GOSSIP.CARD_INSET)
		row.Icon:ClearAllPoints()
		row.Icon:SetPoint('LEFT', row, 'LEFT', PANEL.ICON_X, 0)
	end
end

local function FontGossipMeasures(scrollBox)
	local provider = scrollBox:GetDataProvider()
	if not provider then return end
	local restyled = false
	for _, elementData in provider:EnumerateEntireRange() do
		for _, key in ipairs(GOSSIP_MEASURE_KEYS) do
			local measure = elementData[key]
			if measure and not measure._buiMeasure then
				measure._buiMeasure = true
				restyled = true
				if measure.GreetingText then
					Face(measure.GreetingText)
				elseif measure.GetFontString then
					Face(measure:GetFontString())
				end
			end
		end
	end
	if restyled then scrollBox:Rebuild(ScrollBoxConstants.RetainScrollPosition) end
end

local function RefreshGossip()
	local scrollBox = _G.GossipFrame.GreetingPanel.ScrollBox
	Skin.ForEachScrollFrame(scrollBox, SkinGossipRow)
	FontGossipMeasures(scrollBox)
end

local function OnGossipUpdated(frame)
	if frame:IsShown() then RefreshGossip() end
end

local function PadGossipList(scrollBox, scrollBar)
	local right = scrollBar:IsShown() and GOSSIP.BAR_SPACE or GOSSIP.PAD
	scrollBox:GetView():SetPadding(GOSSIP.PAD, GOSSIP.PAD, GOSSIP.PAD, right, GOSSIP.SPACING)
end

local function ShapeGossipList(scrollBox, scrollBar)
	local view = scrollBox:GetView()
	local measure = view:GetElementExtentCalculator()
	view:SetElementExtentCalculator(function(dataIndex, elementData)
		if Enabled() and elementData.buttonType == GOSSIP_BUTTON_TYPE_DIVIDER then return GOSSIP.DIVIDER end
		return measure(dataIndex, elementData)
	end)
	PadGossipList(scrollBox, scrollBar)
	local function Repad()
		PadGossipList(scrollBox, scrollBar)
		scrollBox:FullUpdate()
	end
	scrollBar:HookScript('OnShow', Wrap('Skin.QuestDialogs gossip bar shown', Repad))
	scrollBar:HookScript('OnHide', Wrap('Skin.QuestDialogs gossip bar hidden', Repad))
	if view:GetDataProvider() then scrollBox:Rebuild(ScrollBoxConstants.RetainScrollPosition) end
end

local function SkinGossipFrame(frame)
	context.Chrome(frame)
	SkinFriendshipBar(frame.FriendshipStatusBar)
	local panel = frame.GreetingPanel
	FadeRegions(panel)
	Shell(panel.ScrollBox)
	ScrollBar(panel.ScrollBar)
	WideScroll(frame, panel.ScrollBox, panel.ScrollBar)
	Button(panel.GoodbyeButton)
	ShapeGossipList(panel.ScrollBox, panel.ScrollBar)
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
	if event == 'ITEM_TEXT_BEGIN' then StylePageHtml() end
end

local function SkinPageButton(button, direction)
	if not button then return end
	Skin.TipPageButton(button, direction)
	BodyRegions(button)
end

local function SkinItemTextFrame(frame)
	context.Chrome(frame)
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
		bar:SetStatusBarColor(SELECTED[1], SELECTED[2], SELECTED[3], 1)
		Shell(bar)
	end
end

local function OnAdventureRewards(dialog)
	if dialog:IsShown() then RefreshAdventureRewards(dialog) end
end

local function InstallQuest()
	for name, style in pairs(PANEL_TEXT_STYLES) do questPanelTexts[_G[name]] = style end
	questInfoParents[_G.QuestDetailScrollChildFrame] = true
	questInfoParents[_G.QuestRewardScrollChildFrame] = true
	BuildBreakLine()
	_G.QuestFrameGreetingPanel:HookScript('OnShow', Wrap('Skin.QuestDialogs greeting shown', context.Guard(RefreshGreeting)))
	context.Hook('QuestInfo_Display', OnQuestInfoDisplay)
	context.Hook('QuestInfo_ShowRewards', OnQuestInfoRewards)
	context.Hook('QuestFrame_SetTextColor', StylePanelText)
	context.Hook('QuestFrame_SetTitleTextColor', StylePanelText)
	context.Hook('QuestFrameProgressItems_Update', RefreshProgress)
	context.Hook('SetItemButtonQuality', OnItemButtonQuality)
end

local function ShowQuest()
	if _G.QuestFrameGreetingPanel:IsShown() then RefreshGreeting() end
	if _G.QuestFrameProgressPanel:IsShown() then RefreshProgress() end
	if QuestInfoOnQuestFrame() then RefreshQuestInfo() end
end

local function InstallGossip(frame)
	context.Hook(frame, 'Update', OnGossipUpdated)
end

local function InstallItemText(frame)
	frame:HookScript('OnEvent', Wrap('Skin.QuestDialogs text event', context.Guard(OnItemTextEvent)))
end

local function InstallAdventure(dialog)
	context.Hook(dialog, 'RefreshRewards', OnAdventureRewards)
end

context.Window('QuestFrame', { install = InstallQuest, skin = SkinQuestFrame, show = ShowQuest })
context.Window('GossipFrame', { install = InstallGossip, skin = SkinGossipFrame, show = RefreshGossip })
context.Window('ItemTextFrame', { install = InstallItemText, skin = SkinItemTextFrame, show = StylePageHtml })
context.Window('AdventureMapQuestChoiceDialog', { install = InstallAdventure, skin = SkinAdventureDialog, show = RefreshAdventureRewards })
