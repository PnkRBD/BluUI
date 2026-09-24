local _, BUI = ...

local Skin = BUI.Skinning

local SKIN_ID = 'chatpanels'
local ADDONS = { 'Blizzard_Channels' }
local FRAMES = { 'ChatConfigFrame', 'ChannelFrame', 'CreateChannelPopup' }
local MAX_DEPTH = 7
local FONT_DEPTH = 7
local ART_KEYS = { 'Border', 'BorderFrame', 'Background', 'BackgroundTile', 'BG', 'Bg', 'NineSlice', 'Inset', 'InsetFrame', 'PortraitContainer', 'TitleBg', 'TitleContainer', 'TopTileStreaks', 'ArtFrame', 'Overlay', 'Header' }
local BACKDROP_KEYS = { 'Center', 'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge', 'TopLeftCorner', 'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner', 'NineSlice', 'Bg', 'BG', 'Background', 'Border', 'Inset', 'InsetFrame' }
local CLOSE_KEYS = { 'CloseButton', 'ClosePanelButton', 'CloseDialogButton', 'closeButton' }
local BUTTON_KEYS = { 'OkayButton', 'OkButton', 'OKButton', 'CancelButton', 'DefaultButton', 'DefaultsButton', 'RedockButton', 'NewButton', 'SettingsButton', 'ResetButton', 'SaveButton', 'DeleteButton' }
local SCROLL_LIST_KEYS = { 'ChannelList', 'ChannelRoster' }
local CONFIG_PANELS = { 'ChatConfigCategoryFrame', 'ChatConfigBackgroundFrame', 'ChatConfigCombatSettingsFilters' }
local PANEL_INSET = Skin.TIP_TAB_INSET
local FOOTER_GAP = 4
local TAB_ROW_OFFSET = 2
local CATEGORY_BUTTON_COUNT = 7
local CATEGORY_BUTTON_HEIGHT = 20
local NAV_TEXT_INSET = 6
local CHECK_SIZE = 16
local SWATCH_INSET = 2
local WHITE = [[Interface\Buttons\WHITE8X8]]

local testShown = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Close, Dropdown = context.Shell, context.Button, context.Close, context.Dropdown
local EditBox, CheckBox, ScrollBar, Tab = context.EditBox, context.CheckBox, context.ScrollBar, context.Tab
local Face, Title = context.Face, context.Title

local function FrameName(frame)
	return (frame.GetName and frame:GetName()) or ''
end

local function IsType(object, kind)
	local ok, result = pcall(object.IsObjectType, object, kind)
	return ok and result == true
end

local function NamedFontString(name)
	local object = _G[name]
	if type(object) == 'table' and IsType(object, 'FontString') then return object end
end

local function ForEachNumbered(prefix, callback)
	local index = 1
	local frame = _G[prefix .. index]
	while frame do
		callback(frame)
		index = index + 1
		frame = _G[prefix .. index]
	end
end

local function HasBackdrop(frame)
	return frame.NineSlice ~= nil or frame.Bg ~= nil or frame.BG ~= nil
		or frame.Background ~= nil or frame.backdropInfo ~= nil
end

local function IsNineSlice(frame)
	return frame.backdropInfo == nil and (frame.Center ~= nil or frame.TopEdge ~= nil)
end

local function IsCloseButton(button)
	return FrameName(button):find('CloseButton$') ~= nil
end

local function IsTabButton(button)
	if FrameName(button):find('Tab%d*$') then return true end
	return button:GetParent() == ChatConfigFrame.ChatTabManager
end

local function IsPanelButton(button)
	if button.Left ~= nil and button.Right ~= nil then return true end
	if not button.GetText then return false end
	local text = button:GetText()
	return text ~= nil and text ~= '' and button.GetNormalTexture ~= nil and button:GetNormalTexture() ~= nil
end

local function IsNavButton(button)
	return button.Highlight ~= nil and button.NormalText ~= nil
end

local function IsSwatch(button)
	return button.SwatchBg ~= nil or FrameName(button):find('ColorSwatch$') ~= nil
end

local function IsLegacyDropdown(frame)
	return frame.Left ~= nil and frame.Middle ~= nil and frame.Right ~= nil and frame.Button ~= nil
end

local function IsCheckRow(frame)
	return frame.BlankText ~= nil and frame.CheckButton ~= nil
end

local function IsSwatchRow(frame)
	return FrameName(frame):find('Swatch%d+$') ~= nil
end

local function SkinScrollHost(frame)
	if frame.ScrollBar and not frame.ScrollBar._buiDeepSkip then
		frame.ScrollBar._buiDeepSkip = true
		ScrollBar(frame.ScrollBar)
	end
	local name = FrameName(frame)
	local named = name ~= '' and _G[name .. 'ScrollBar']
	if named and not named._buiDeepSkip then
		named._buiDeepSkip = true
		ScrollBar(named)
	end
end

local function CheckLabel(check)
	if check.Text then return check.Text end
	local name = FrameName(check)
	if name ~= '' then return NamedFontString(name .. 'Text') end
end

local function Check(check)
	local width = check:GetWidth()
	CheckBox(check, width > CHECK_SIZE and math.floor((width - CHECK_SIZE) / 2) or 0)
	local label = CheckLabel(check)
	if not label then return end
	Face(label)
	local point, relativeTo, relativePoint, offsetX = label:GetPoint(1)
	if point == 'LEFT' and relativeTo == check and relativePoint == 'RIGHT' then
		label:SetPoint('LEFT', check, 'RIGHT', offsetX, 0)
	end
end

local function SwatchEnter(swatch)
	Skin.TipShellEdges(swatch, true)
end

local function SwatchLeave(swatch)
	Skin.TipShellEdges(swatch, false)
end

local function Swatch(swatch)
	if not swatch then return end
	Shell(swatch)
	Fade(swatch.SwatchBg or _G[FrameName(swatch) .. 'SwatchBg'])
	Fade(swatch.InnerBorder)
	if swatch._buiSwatch then return end
	swatch._buiSwatch = true
	local fill = swatch.Color
	if not fill then
		fill = swatch:GetNormalTexture()
		fill:SetTexture(WHITE)
	end
	fill:ClearAllPoints()
	fill:SetPoint('TOPLEFT', swatch, 'TOPLEFT', SWATCH_INSET, -SWATCH_INSET)
	fill:SetPoint('BOTTOMRIGHT', swatch, 'BOTTOMRIGHT', -SWATCH_INSET, SWATCH_INSET)
	swatch:HookScript('OnEnter', SwatchEnter)
	swatch:HookScript('OnLeave', SwatchLeave)
end

local function CheckRow(row)
	Fade(row.NineSlice)
	Check(row.CheckButton)
	Face(row.BlankText)
	Swatch(row.ColorSwatch)
	Close(row.CloseChannel)
end

local function SwatchRow(row)
	Fade(row.NineSlice)
	local name = FrameName(row)
	Face(NamedFontString(name .. 'Text'))
	Swatch(_G[name .. 'ColorSwatch'])
end

local function CheckEntry(entry)
	if IsCheckRow(entry) then
		CheckRow(entry)
		return
	end
	Check(entry)
	ForEachNumbered(FrameName(entry) .. '_', Check)
end

local function NavButton(button)
	Skin.TipButtonFonts(button)
	Skin.RowHighlight(button)
	button.Highlight:SetVertexColor(1, 1, 1, 1)
	if button._buiNav then return end
	button._buiNav = true
	button.NormalText:ClearAllPoints()
	button.NormalText:SetPoint('LEFT', button, 'LEFT', NAV_TEXT_INSET, 0)
end

local function BoxHeaders(frame)
	local name = FrameName(frame)
	if name == '' then return end
	Title(NamedFontString(name .. 'Title'))
	local colorHeader = NamedFontString(name .. 'ColorHeader')
	if colorHeader then Skin.TipFont(colorHeader, 'label') end
end

local DeepSkin

local function SkinButton(button, depth, flat)
	if IsCloseButton(button) then
		Close(button)
	elseif IsTabButton(button) then
		Tab(button)
	elseif IsSwatch(button) then
		Swatch(button)
	elseif IsNavButton(button) then
		NavButton(button)
	elseif IsPanelButton(button) then
		Button(button)
	else
		DeepSkin(button, depth - 1, flat)
	end
end

local function SkinChild(child, depth, flat)
	if child._buiDeepSkip or child:IsForbidden() then return end
	if IsType(child, 'CheckButton') then
		Check(child)
		DeepSkin(child, depth - 1, flat)
		return
	end
	if IsType(child, 'EditBox') then
		EditBox(child)
		return
	end
	if IsType(child, 'Slider') or IsType(child, 'StatusBar') then return end
	if IsType(child, 'DropdownButton') or IsLegacyDropdown(child) then
		Dropdown(child)
		return
	end
	if IsType(child, 'ScrollFrame') then
		SkinScrollHost(child)
		DeepSkin(child, depth - 1, flat)
		return
	end
	if IsType(child, 'Button') then
		SkinButton(child, depth, flat)
		return
	end
	if IsNineSlice(child) then
		FadeRegions(child)
		return
	end
	if IsCheckRow(child) then
		CheckRow(child)
		return
	end
	if IsSwatchRow(child) then
		SwatchRow(child)
		return
	end
	if HasBackdrop(child) then
		FadeKeys(child, BACKDROP_KEYS)
		if not flat then Shell(child) end
	end
	BoxHeaders(child)
	SkinScrollHost(child)
	DeepSkin(child, depth - 1, flat)
end

DeepSkin = function(frame, depth, flat)
	if depth <= 0 then return end
	for _, child in ipairs({ frame:GetChildren() }) do
		SkinChild(child, depth, flat)
	end
end

local function SkinRow(row)
	if not Enabled() or row._buiRow then return end
	row._buiRow = true
	Skin.TipFaceTree(row, 2)
end

local function SkinChannelLists(frame)
	for index = 1, #SCROLL_LIST_KEYS do
		local list = frame[SCROLL_LIST_KEYS[index]]
		if list then
			ScrollBar(list.ScrollBar)
			if list.ScrollBar then list.ScrollBar._buiDeepSkip = true end
			Skin.SweepScrollBox(list.ScrollBox, SkinRow)
		end
	end
end

local function StyleTab(tab, selected)
	Tab(tab)
	Skin.TipTabSelected(tab, selected)
	tab:SetAlpha(1)
	local text = tab:GetFontString()
	text:SetVertexColor(1, 1, 1, 1)
	text:SetTextColor(tab:GetNormalFontObject():GetTextColor())
end

local function RefreshWindowTabs(manager)
	if not Enabled() then return end
	for tab in manager.tabPool:EnumerateActive() do
		StyleTab(tab, tab:GetID() == CURRENT_CHAT_FRAME_ID)
	end
end

local function RefreshCombatTabs()
	if not Enabled() then return end
	for index, info in ipairs(COMBAT_CONFIG_TABS) do
		StyleTab(_G[CHAT_CONFIG_COMBAT_TAB_NAME .. index], _G[info.frame]:IsShown())
	end
end

local function FilterRow(button)
	if Enabled() then NavButton(button) end
end

local function WindowTitle(frame)
	if frame.Header then Title(frame.Header.Text) end
	if frame.TitleContainer then Title(frame.TitleContainer.TitleText) end
end

local function AlignEdges(frame)
	local category, background = ChatConfigCategoryFrame, ChatConfigBackgroundFrame
	frame.DefaultButton:ClearAllPoints()
	frame.DefaultButton:SetPoint('TOPLEFT', category, 'BOTTOMLEFT', PANEL_INSET, -FOOTER_GAP)
	frame.DefaultButton:SetPoint('TOPRIGHT', category, 'BOTTOMRIGHT', -PANEL_INSET, -FOOTER_GAP)
	frame.RedockButton:ClearAllPoints()
	frame.RedockButton:SetPoint('TOPLEFT', background, 'BOTTOMLEFT', PANEL_INSET, -FOOTER_GAP)
	ChatConfigFrameOkayButton:ClearAllPoints()
	ChatConfigFrameOkayButton:SetPoint('TOPRIGHT', background, 'BOTTOMRIGHT', -PANEL_INSET, -FOOTER_GAP)
	local firstCombatTab = _G[CHAT_CONFIG_COMBAT_TAB_NAME .. 1]
	firstCombatTab:ClearAllPoints()
	firstCombatTab:SetPoint('BOTTOMLEFT', background, 'TOPLEFT', 0, -TAB_ROW_OFFSET)
end

local function SkinConfigWindow(frame)
	for index = 1, #CONFIG_PANELS do
		Shell(_G[CONFIG_PANELS[index]], PANEL_INSET)
	end
	AlignEdges(frame)
	for index = 1, CATEGORY_BUTTON_COUNT do
		_G['ChatConfigCategoryFrameButton' .. index]:SetHeight(CATEGORY_BUTTON_HEIGHT)
	end
	Skin.TipPageButton(ChatConfigMoveFilterUpButton, 'up')
	Skin.TipPageButton(ChatConfigMoveFilterDownButton, 'down')
	Skin.SweepScrollBox(ChatConfigCombatSettingsFilters.ScrollBox, FilterRow)
	RefreshWindowTabs(frame.ChatTabManager)
	RefreshCombatTabs()
end

local function SkinWindow(frame)
	if frame:IsForbidden() or not Enabled() then return end
	local isConfig = frame == ChatConfigFrame
	FadeArt(frame)
	FadeKeys(frame, ART_KEYS)
	Shell(frame)
	for index = 1, #CLOSE_KEYS do
		local button = frame[CLOSE_KEYS[index]]
		if button then
			button._buiDeepSkip = true
			Close(button)
		end
	end
	for index = 1, #BUTTON_KEYS do
		local button = frame[BUTTON_KEYS[index]]
		if button then
			button._buiDeepSkip = true
			Button(button)
		end
	end
	SkinChannelLists(frame)
	Skin.TipFaceTree(frame, FONT_DEPTH)
	DeepSkin(frame, MAX_DEPTH, isConfig)
	Skin.HideHelpButtons(frame)
	WindowTitle(frame)
	if isConfig then SkinConfigWindow(frame) end
end

local function SweepAll()
	if not Enabled() then return end
	for index = 1, #FRAMES do
		local frame = _G[FRAMES[index]]
		if frame then
			if not frame._buiChatShowHook then
				frame._buiChatShowHook = true
				frame:HookScript('OnShow', SkinWindow)
			end
			if frame:IsShown() then SkinWindow(frame) end
		end
	end
end

local function LoadWindows()
	for index = 1, #ADDONS do
		pcall(C_AddOns.LoadAddOn, ADDONS[index])
	end
end

local function Test()
	LoadWindows()
	SweepAll()
	local shown = {}
	for index = 1, #FRAMES do
		local frame = _G[FRAMES[index]]
		if frame and not frame:IsShown() and pcall(frame.Show, frame) then
			testShown[#testShown + 1] = frame
			shown[#shown + 1] = frame
		end
	end
	return unpack(shown)
end

local function StopTest()
	for index = 1, #testShown do
		pcall(testShown[index].Hide, testShown[index])
	end
	wipe(testShown)
end

local function Deactivate()
	context.Restore()
	BUI.Print('Chat Settings skin disabled. /reload for a full visual reset.')
end

local function OnCheckboxesCreated(frame)
	if Enabled() then ForEachNumbered(FrameName(frame) .. 'Checkbox', CheckEntry) end
end

local function OnSwatchesCreated(frame)
	if Enabled() then ForEachNumbered(FrameName(frame) .. 'Swatch', SwatchRow) end
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		SweepAll()
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Chat Settings',
	description = 'The chat settings window from a chat tab, the channels window and the new channel dialog: dark shell, flat panels, house checkboxes, tabs and buttons.',
	icon = 'Interface/Icons/INV_Scroll_03',
	test = Test,
	stopTest = StopTest,
})

hooksecurefunc('ChatConfig_CreateCheckboxes', OnCheckboxesCreated)
hooksecurefunc('ChatConfig_CreateTieredCheckboxes', OnCheckboxesCreated)
hooksecurefunc('ChatConfig_CreateColorSwatches', OnSwatchesCreated)
hooksecurefunc('TextToSpeechFrame_CreateCheckboxes', OnCheckboxesCreated)
hooksecurefunc('ChatConfig_UpdateCombatTabs', RefreshCombatTabs)
hooksecurefunc(ChatConfigFrame.ChatTabManager, 'UpdateSelection', RefreshWindowTabs)
hooksecurefunc(ChatConfigFrame.ChatTabManager, 'UpdateWidth', RefreshWindowTabs)

BUI.Events:Register('ADDON_LOADED', 'Skin.ChatConfig', SweepAll)
BUI.Events:Once('PLAYER_LOGIN', 'Skin.ChatConfig', SweepAll)
