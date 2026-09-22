local _, BUI = ...

local Skin = BUI.Skinning

local SKIN_ID = 'lootwindow'
local ROW_ART_KEYS = { 'NameFrame', 'IconBorder', 'IconOverlay', 'IconOverlay2', 'IconQuestTexture', 'QuestTexture', 'Border' }
local FONT_DEPTH = 2

local skinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeArt, FadeKeys = context.Fade, context.FadeArt, context.FadeKeys
local Shell, Close, ScrollBar, Title = context.Shell, context.Close, context.ScrollBar, context.Title
local CropIcon, RowHighlight = Skin.CropIcon, Skin.RowHighlight

local function IconOf(frame)
	if not frame then return nil end
	local icon = frame.icon or frame.Icon
	if icon and icon.SetTexCoord then return icon end
	return nil
end

local function SkinItem(item)
	if not item or item._buiLootItem then return end
	item._buiLootItem = true
	local icon = IconOf(item)
	if icon then icon.__buiSkin = true end
	FadeArt(item)
	FadeKeys(item, ROW_ART_KEYS)
	if icon then
		CropIcon(icon)
		Skin.TipIconFrame(item, icon)
	end
	if item.GetHighlightTexture then RowHighlight(item) end
end

local function SkinRow(row)
	if not row then return end
	FadeKeys(row, ROW_ART_KEYS)
	SkinItem(row.Item or row)
	if row.GetHighlightTexture then RowHighlight(row) end
	Skin.TipFaceTree(row, FONT_DEPTH)
end

local function Apply()
	local frame = _G.LootFrame
	if not frame or not Enabled() or skinned then return end
	skinned = true
	FadeArt(frame)
	Fade(frame.PortraitContainer)
	Shell(frame)
	Close(frame.CloseButton)
	ScrollBar(frame.ScrollBar)
	local titleContainer = frame.TitleContainer
	Title(titleContainer and titleContainer.TitleText or _G.LootFrameTitleText)
	if frame.ScrollBox then Skin.SweepScrollBox(frame.ScrollBox, SkinRow) end
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Apply()
	else
		context.Restore()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Loot Window',
	description = 'The loot window you get from a corpse or a chest: dark shell, framed icons, house font.',
	icon = 'Interface/Icons/INV_Misc_Bag_10_Green',
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.Loot', Apply)
BUI.Events:Register('LOOT_OPENED', 'Skin.Loot', Apply)
