local _, BUI = ...

local ipairs = ipairs

local BUILib = BluUI.BUILibClient
local Skin = BUI.Skinning

local FONT_DEPTH = 3
local SECTION_KEYS = { 'shownSection', 'hiddenSection' }
local GEAR_GLYPH_SIZE = 14

local context = Skin.Define('cooldownmanager', {
	name = 'Cooldown Manager',
	description = 'The Cooldown Manager settings window: the metal frame stripped off, dark category headers, framed icons, and the search box, settings cog, layout dropdown, buttons and side tabs in the library style.',
	icon = 'Interface/Icons/INV_Misc_PocketWatch_01',
})
local Hook = context.Hook
local FadeRegions, Keep = context.FadeRegions, context.Keep
local Shell, Button, Dropdown, EditBox, ScrollBar = context.Shell, context.Button, context.Dropdown, context.EditBox, context.ScrollBar
local Once, CheckedSideTab = context.Once, context.CheckedSideTab

local function SkinItem(item)
	Skin.SquareIcon(item, item.Icon)
end

local function SkinHeader(header)
	FadeRegions(header)
	Shell(header)
	Skin.TipFace(header.Name, 'body')
end

local function SkinCategory(category)
	Once(category.Header, SkinHeader)
	for item in category.itemPool:EnumerateActive() do Once(item, SkinItem) end
end

local function SweepCategories(frame)
	for category in frame.categoryPool:EnumerateActive() do SkinCategory(category) end
end

local function SweepSections(filter)
	for _, key in ipairs(SECTION_KEYS) do SkinCategory(filter[key]) end
end

local function GearEnter(dropdown)
	dropdown._buiGear:SetVertexColor(unpack(Skin.HoverColor()))
end

local function GearLeave(dropdown)
	BUI.Painter.Tint(dropdown._buiGear, 'skinLabel')
end

local function SkinGear(dropdown)
	FadeRegions(dropdown)
	if dropdown._buiGear then return end
	local glyph = context.Own(dropdown:CreateTexture(nil, 'ARTWORK'))
	BUILib.Widget.SetGlyph(glyph, BUILib.GetLibMedia('cog'))
	glyph:SetSize(GEAR_GLYPH_SIZE, GEAR_GLYPH_SIZE)
	glyph:SetPoint('CENTER')
	BUI.Painter.Tint(glyph, 'skinLabel')
	dropdown._buiGear = glyph
	dropdown:HookScript('OnEnter', BUI.Profiler.Wrap('Skin.CooldownManager gear OnEnter', GearEnter))
	dropdown:HookScript('OnLeave', BUI.Profiler.Wrap('Skin.CooldownManager gear OnLeave', GearLeave))
end

local function SkinSideTabs(frame)
	for _, tab in ipairs(frame.TabButtons) do
		Keep(tab.NewOptionsFrame)
		CheckedSideTab(tab, { width = tab:GetWidth(), height = tab:GetHeight() })
	end
end

local function RefreshSideTabs(frame)
	for _, tab in ipairs(frame.TabButtons) do Skin.SetSideTabSelected(tab, frame.displayMode == tab.displayMode) end
end

local function SkinSettings(frame)
	Skin.TipFaceTree(frame, FONT_DEPTH)
	context.Chrome(frame)
	EditBox(frame.SearchBox)
	SkinGear(frame.SettingsDropdown)
	Dropdown(frame.LayoutDropdown)
	Button(frame.UndoButton)
	ScrollBar(frame.CooldownScroll.ScrollBar)
	ScrollBar(frame.GroupBuffFilter.Scroll.ScrollBar)
	SkinSideTabs(frame)
end

local function RefreshSettings(frame)
	SweepCategories(frame)
	SweepSections(frame.GroupBuffFilter)
	RefreshSideTabs(frame)
end

local function InstallSettings(frame)
	Hook(frame, 'RefreshLayout', SweepCategories)
	Hook(frame, 'RefreshVisibleCategories', SweepCategories)
	Hook(frame.GroupBuffFilter, 'Refresh', SweepSections)
end

context.Window('CooldownViewerSettings', { install = InstallSettings, skin = SkinSettings, show = RefreshSettings })
