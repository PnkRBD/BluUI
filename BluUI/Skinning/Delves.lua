local _, BUI = ...

local ipairs = ipairs

local BUILib = BluUI.BUILibClient
local Skin = BUI.Skinning

local CHROME_FRAMES = { 'NineSlice', 'Border' }
local CLOSE_INSET = -4
local FONT_DEPTH = 3
local SHELL_CLEAR = { 0, 0, 0, 0 }
local COVER_PAD = 6
local COVER_SUBLEVEL = -7
local TITLE_SCALE = 1.3
local REWARDS_GLYPH_SIZE = 16
local SLOT_KEYS = { 'CompanionCombatRoleSlot', 'CompanionFlavorSlot', 'CompanionCombatTrinketSlot', 'CompanionUtilityTrinketSlot' }

local context = Skin.Define('delves', {
	name = 'Delves',
	description = 'The delve entrance window where you pick a tier, plus the companion panels: the metal frame stripped off, the delve scene left alone.',
	icon = 'Interface/Icons/INV_Misc_Cave_01',
})
local Hook, Guard, Once = context.Hook, context.Guard, context.Once
local Fade, FadeRegions, Line = context.Fade, context.FadeRegions, context.Line
local Shell, Close, Button, Dropdown, ScrollBar, ToolButton, Paging = context.Shell, context.Close, context.Button, context.Dropdown, context.ScrollBar, context.ToolButton, context.Paging

local function StripDialog(frame)
	for index = 1, #CHROME_FRAMES do FadeRegions(frame[CHROME_FRAMES[index]]) end
	Shell(frame)
	BUILib.Skin.SetShellFill(frame, SHELL_CLEAR)
	local close = frame.CloseButton
	Close(close)
	close:ClearAllPoints()
	close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', CLOSE_INSET, CLOSE_INSET)
	Skin.TipFaceTree(frame, FONT_DEPTH)
end

local function DelveCover(frame)
	local cover = frame._buiDelveCover
	if cover then return cover end
	cover = context.Own(frame:CreateTexture(nil, 'BACKGROUND', nil, COVER_SUBLEVEL))
	BUI.Painter.Fill(cover, 'skinBackground')
	cover:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -1, -1)
	cover:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -1, 1)
	frame._buiDelveCover = cover
	return cover
end

local function FitCover(frame)
	local right, left = frame:GetRight(), frame.DelveRewardsContainerFrame:GetLeft()
	if not right or not left or right <= left then return false end
	DelveCover(frame):SetWidth(right - left + COVER_PAD)
	return true
end

local function InitReward(row)
	Fade(row.NameFrame)
	Fade(row.IconBorder)
	Skin.SquareIcon(row, row.Icon)
	Skin.TipFaceTree(row, 1)
end

local function SkinReward(row)
	Once(row, InitReward)
	Skin.SetIconEdgeQuality(row.Icon, row.IconBorder)
end

local function RewardsGlyphEnter(button)
	button._buiRewardsGlyph:SetVertexColor(unpack(Skin.HoverColor()))
end

local function RewardsGlyphLeave(button)
	BUI.Painter.Tint(button._buiRewardsGlyph, 'skinLabel')
end

local function SkinRewardsButton(button)
	ToolButton(button)
	if button._buiRewardsGlyph then return end
	local glyph = context.Own(button:CreateTexture(nil, 'OVERLAY'))
	BUILib.Widget.SetGlyph(glyph, BUILib.GetLibMedia('dungeon'))
	glyph:SetSize(REWARDS_GLYPH_SIZE, REWARDS_GLYPH_SIZE)
	glyph:SetPoint('CENTER')
	BUI.Painter.Tint(glyph, 'skinLabel')
	button._buiRewardsGlyph = glyph
	button:HookScript('OnEnter', RewardsGlyphEnter)
	button:HookScript('OnLeave', RewardsGlyphLeave)
end

local function SkinPicker(frame)
	StripDialog(frame)
	Skin.TipFont(frame.Title, 'title', TITLE_SCALE)
	Skin.TipFont(frame.ScenarioLabel, 'label')
	Skin.TipFont(frame.DelveModifiersWidgetContainer.ModifiersLabel, 'title')
	Skin.TipFont(frame.ChallengesContainerFrame.Title, 'title')
	Dropdown(frame.Dropdown)
	Button(frame.EnterDelveButton)
	SkinRewardsButton(frame.TieredEntranceViewRewardsButton)
	local rewards = frame.DelveRewardsContainerFrame
	ScrollBar(rewards.ScrollBar)
	Skin.SweepScrollBox(rewards.ScrollBox, Guard(SkinReward))
	if not frame._buiDelvesFit then
		frame._buiDelvesFit = true
		frame:HookScript('OnShow', Guard(FitCover))
	end
	if not FitCover(frame) then C_Timer.After(0, function() FitCover(frame) end) end
end

local function InitOptionRow(row)
	Fade(row.Border)
	Skin.SquareIcon(row, row.Icon)
	Skin.RowHighlight(row)
	Skin.TipFace(row.Name, 'body')
end

local function SkinOptionRow(row)
	Once(row, InitOptionRow)
	local border = row.Border
	local red, green, blue = border:GetVertexColor()
	if border:IsShown() and (red < 1 or green < 1 or blue < 1) then
		Skin.SetIconEdgeColor(row.Icon, red, green, blue)
	else
		Skin.SetIconEdgeColor(row.Icon)
	end
end

local function SkinOptionsList(list)
	FadeRegions(list)
	Shell(list)
	Skin.SweepScrollBox(list.ScrollBox, Guard(SkinOptionRow))
end

local function SkinConfiguration(frame)
	StripDialog(frame)
	local info = frame.CompanionInfoFrame
	Skin.TipFont(info.CompanionName, 'title', TITLE_SCALE)
	local divider = _G.CompanionInfoGLine
	Fade(divider)
	if not frame._buiDelveDivider then frame._buiDelveDivider = Line(info, divider, false, 0, 0, 'ARTWORK') end
	Button(frame.CompanionConfigShowAbilitiesButton)
	local slots = frame.CompanionSlots
	for index = 1, #SLOT_KEYS do SkinOptionsList(slots[SLOT_KEYS[index]].OptionsList) end
end

local function InitAbility(button)
	Skin.SquareIcon(button, button.Icon)
	Skin.TipFace(button.Name, 'body')
	Skin.TipFace(button.UnlockCondition, 'body')
	Skin.TipFace(button.Rank, 'body')
end

local function SweepAbilities(frame)
	for _, button in ipairs(frame.buttons) do Once(button, InitAbility) end
end

local function RefreshAbilityPaging(paging)
	Skin.RefreshPageButtons(paging.PrevPageButton, paging.NextPageButton)
end

local function SkinAbilityList(frame)
	Skin.TipFaceTree(frame, FONT_DEPTH)
	context.Chrome(frame)
	Dropdown(frame.DelvesCompanionRoleDropdown)
	local paging = frame.DelvesCompanionAbilityListPagingControls
	Paging(paging)
	RefreshAbilityPaging(paging)
	SweepAbilities(frame)
end

local function InstallAbilityList(frame)
	Hook(frame, 'Refresh', SweepAbilities)
	Hook(frame.DelvesCompanionAbilityListPagingControls, 'Refresh', RefreshAbilityPaging)
end

context.Window('DelvesDifficultyPickerFrame', { skin = SkinPicker })
context.Window('DelvesCompanionConfigurationFrame', { skin = SkinConfiguration })
context.Window('DelvesCompanionAbilityListFrame', { install = InstallAbilityList, skin = SkinAbilityList })
