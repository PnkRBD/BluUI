local _, BUI = ...
local HookScript = select(2, BUI.Prof.Scripts('CooldownManager'))

local Skin = BUI.Skinning
local hooker = BUI.Prof.MakeHooker('skin')

local SKIN_ID = 'cooldownmanager'
local ADDON = 'Blizzard_CooldownViewer'
local MAIN_ART = { 'Bg', 'Background', 'TopTileStreaks', 'Inset', 'Border', 'TitleBg', 'BottomInset', 'ScrollInset' }
local TAB_KEYS = { 'SpellsTab', 'AurasTab', 'ItemsTab', 'BarsTab', 'UtilityTab' }
local TAB_SYSTEM_KEYS = { 'TabSystem', 'CategoryTabSystem' }
local SELECTED_KEYS = { 'SelectedTexture', 'Selected', 'ActiveTexture' }
local ICON_KEYS = { 'Icon', 'icon', 'IconTexture' }
local ICON_ART = { 'IconBorder', 'Border', 'Backdrop', 'Background' }
local HEADER_KEYS = { 'Header', 'HeaderButton', 'CategoryHeader', 'TitleBar' }
local CATEGORY_ART = { 'Background', 'Bg', 'Border', 'NineSlice' }
local TAB_MAX_WIDTH = 56
local ITEM_DEPTH = 3
local FONT_DEPTH = 3

local chrome = {}
local sideTabs = {}
local scrollBox
local testShown = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, Dropdown, EditBox, ScrollBar = context.Shell, context.Button, context.Close, context.Dropdown, context.EditBox, context.ScrollBar
local Title = context.Title
local CropIcon = Skin.CropIcon

local function FirstKey(frame, keys)
	for index = 1, #keys do
		local child = frame[keys[index]]
		if child then return child end
	end
	return nil
end

local function IsKeyed(frame, child, keys)
	for index = 1, #keys do
		if frame[keys[index]] == child then return true end
	end
	return false
end

local function HasText(button)
	if not button.GetText then return false end
	local text = button:GetText()
	return text ~= nil and text ~= ''
end

local function SkinIconButton(button)
	if button._buiCdmIcon then return end
	local icon = FirstKey(button, ICON_KEYS)
	if not icon or not icon.SetTexCoord then return end
	button._buiCdmIcon = true
	icon.__buiSkin = true
	CropIcon(icon)
	Skin.TipIconFrame(button, icon)
	for index = 1, #ICON_ART do
		local art = button[ICON_ART[index]]
		if art and art ~= icon and art.SetAlpha then Fade(art) end
	end
end

local function SweepItems(frame, depth)
	if depth <= 0 or not frame.GetChildren then return end
	for _, child in ipairs({ frame:GetChildren() }) do
		if not child:IsForbidden() then
			if child:IsObjectType('Button') and FirstKey(child, ICON_KEYS) then
				SkinIconButton(child)
			else
				SweepItems(child, depth - 1)
			end
		end
	end
end

local function SkinCategory(element)
	if not Enabled() or not element or element:IsForbidden() then return end
	if not element._buiCdmCategory then
		element._buiCdmCategory = true
		FadeKeys(element, CATEGORY_ART)
		local header = FirstKey(element, HEADER_KEYS)
		if header then
			FadeRegions(header)
			Shell(header)
		end
	end
	SweepItems(element, ITEM_DEPTH)
	Skin.TipFaceTree(element, 2)
end

local function StyleSideTab(tab)
	local width, height = tab:GetWidth(), tab:GetHeight()
	Skin.SideTab(context, tab, {
		iconKeys = ICON_KEYS,
		width = width > 0 and width or nil,
		height = height > 0 and height or nil,
	})
	sideTabs[tab] = true
end

local function RefreshTabSystem(tabSystem)
	if not Enabled() then return end
	local tabs = tabSystem.tabs
	if not tabs then return end
	for index = 1, #tabs do
		local tab = tabs[index]
		if sideTabs[tab] then Skin.SetSideTabSelected(tab, tab.isSelected == true) end
	end
end

local function SkinTabSystem(tabSystem)
	local tabs = tabSystem.tabs
	if not tabs then return end
	for index = 1, #tabs do
		local tab = tabs[index]
		if tab and FirstKey(tab, ICON_KEYS) then StyleSideTab(tab) end
	end
	if not tabSystem._buiCdmTabs then
		tabSystem._buiCdmTabs = true
		hooker(tabSystem, 'SetTab', RefreshTabSystem)
	end
	RefreshTabSystem(tabSystem)
end

local function MirrorTab(tab, selected)
	Skin.SetSideTabSelected(tab, selected:IsShown())
end

local function SkinTab(tab)
	local selected = FirstKey(tab, SELECTED_KEYS)
	if not selected or not selected.IsShown or not FirstKey(tab, ICON_KEYS) then return end
	StyleSideTab(tab)
	MirrorTab(tab, selected)
	if tab._buiCdmMirror then return end
	tab._buiCdmMirror = true
	local function Mirror() MirrorTab(tab, selected) end
	hooker(selected, 'Show', Mirror)
	hooker(selected, 'Hide', Mirror)
	hooker(selected, 'SetShown', Mirror)
end

local function Classify(frame, child)
	if child.ForEachFrame then return 'scrollbox' end
	if child.HasScrollableExtent or child.SetScrollPercentage then return 'scrollbar' end
	if child:IsObjectType('EditBox') then return 'editbox' end
	if not child:IsObjectType('Button') then return nil end
	if IsKeyed(frame, child, TAB_KEYS) or FirstKey(child, SELECTED_KEYS) then return 'tab' end
	if child.SetupMenu then return 'dropdown' end
	if HasText(child) then return 'button' end
	if FirstKey(child, ICON_KEYS) and (child:GetWidth() or 0) <= TAB_MAX_WIDTH then return 'tab' end
	return nil
end

local function SkinScrollBox(child)
	scrollBox = child
	Skin.SweepScrollBox(child, SkinCategory)
	Skin.ForEachScrollFrame(child, SkinCategory)
end

local HANDLERS = {
	scrollbox = SkinScrollBox,
	scrollbar = ScrollBar,
	editbox = EditBox,
	dropdown = Dropdown,
	button = Button,
	tab = SkinTab,
}

local function SkinChrome(frame)
	local tabSystem = FirstKey(frame, TAB_SYSTEM_KEYS)
	if tabSystem and tabSystem.tabs and tabSystem.SetTab then
		SkinTabSystem(tabSystem)
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		if child ~= tabSystem and not child:IsForbidden() and not child._buiCdmChrome then
			local kind = Classify(frame, child)
			if kind then
				child._buiCdmChrome = true
				chrome[#chrome + 1] = child
				HANDLERS[kind](child)
			end
		end
	end
	Skin.TipFaceTree(frame, FONT_DEPTH)
end

local function SkinMainFrame(frame)
	Fade(frame.NineSlice)
	FadeKeys(frame, MAIN_ART)
	FadeRegions(frame)
	if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
	Shell(frame)
	Title(frame.TitleContainer and frame.TitleContainer.TitleText)
	Close(frame.CloseButton)
	SkinChrome(frame)
end

local function OnShow(frame)
	if not Enabled() then return end
	SkinChrome(frame)
end

local function Apply()
	if not Enabled() then return end
	local frame = _G.CooldownViewerSettings
	if not frame or frame:IsForbidden() then return end
	if frame._buiCdmSkin then
		SkinChrome(frame)
		return
	end
	frame._buiCdmSkin = true
	SkinMainFrame(frame)
	if not frame._buiCdmHooked then
		frame._buiCdmHooked = true
		HookScript(frame, 'OnShow', OnShow)
	end
end

local function Deactivate()
	context.Restore()
	for tab in pairs(sideTabs) do Skin.ResetSideTab(tab) end
	for index = 1, #chrome do chrome[index]._buiCdmChrome = nil end
	wipe(chrome)
	Skin.ForEachScrollFrame(scrollBox, function(element) element._buiCdmCategory = nil end)
	local frame = _G.CooldownViewerSettings
	if frame then frame._buiCdmSkin = nil end
	BUI.Print('Cooldown Manager skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Apply()
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Cooldown Manager',
	description = 'The Cooldown Manager settings window: the metal frame stripped off, dark category headers, framed icons, and the search box, layout dropdown, buttons and side tabs in the house style.',
	icon = 'Interface/Icons/INV_Misc_PocketWatch_01',
	test = function()
		pcall(C_AddOns.LoadAddOn, ADDON)
		Apply()
		local frame = _G.CooldownViewerSettings
		if not frame then return end
		if not frame:IsShown() and pcall(frame.Show, frame) then testShown = true end
		return frame
	end,
	stopTest = function()
		if not testShown then return end
		testShown = false
		local frame = _G.CooldownViewerSettings
		if frame then pcall(frame.Hide, frame) end
	end,
})

BUI.Events:Register('ADDON_LOADED', 'Skin.CooldownManager', Apply)
BUI.Events:Once('PLAYER_LOGIN', 'Skin.CooldownManager', Apply)
