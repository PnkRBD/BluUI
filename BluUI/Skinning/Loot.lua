local _, BUI = ...

local Skin = BUI.Skinning

local ROW_ART_KEYS = { 'NameFrame', 'IconBorder', 'IconOverlay', 'IconOverlay2', 'IconQuestTexture' }
local FONT_DEPTH = 2

local context = Skin.Define('lootwindow', {
	name = 'Loot Window',
	description = 'The loot window you get from a corpse or a chest: dark shell, framed icons, library font.',
	icon = 'Interface/Icons/INV_Misc_Bag_10_Green',
})
local FadeArt, FadeKeys, Keep = context.FadeArt, context.FadeKeys, context.Keep
local Shell, Close, ScrollBar, Title = context.Shell, context.Close, context.ScrollBar, context.Title
local RowHighlight = Skin.RowHighlight

local function SkinItem(item)
	if item._buiLootItem then return end
	item._buiLootItem = true
	local icon = Keep(item.icon)
	FadeArt(item)
	FadeKeys(item, ROW_ART_KEYS)
	Skin.SquareIcon(item, icon)
	RowHighlight(item)
end

local function SkinRow(row)
	local item = row.Item
	if not item or not context.Enabled() then return end
	FadeKeys(row, ROW_ART_KEYS)
	SkinItem(item)
	Skin.TipFaceTree(row, FONT_DEPTH)
end

local function SkinLoot(frame)
	FadeArt(frame)
	Shell(frame)
	Close(frame.ClosePanelButton)
	ScrollBar(frame.ScrollBar)
	Title(frame.TitleContainer.TitleText)
	Skin.SweepScrollBox(frame.ScrollBox, SkinRow)
end

context.Window('LootFrame', { skin = SkinLoot })
