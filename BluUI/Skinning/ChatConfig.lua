local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('ChatConfig')

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

local skinned = {}
local testShown = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys, FadeArt = context.Fade, context.FadeRegions, context.FadeKeys, context.FadeArt
local Shell, Button, Close, Dropdown = context.Shell, context.Button, context.Close, context.Dropdown
local EditBox, CheckBox, ScrollBar, Tab = context.EditBox, context.CheckBox, context.ScrollBar, context.Tab

local function FrameName(frame)
	return (frame.GetName and frame:GetName()) or ''
end

local function IsType(frame, kind)
	local ok, result = pcall(frame.IsObjectType, frame, kind)
	return ok and result == true
end

local function HasBackdrop(frame)
	return frame.NineSlice ~= nil or frame.Bg ~= nil or frame.BG ~= nil
		or frame.Background ~= nil or frame.backdropInfo ~= nil
end

local function IsNineSlice(frame)
	return frame.Center ~= nil or frame.TopEdge ~= nil
end

local function IsCloseButton(button)
	return FrameName(button):find('CloseButton$') ~= nil
end

local function IsTabButton(button)
	if FrameName(button):find('Tab%d*$') then return true end
	local parent = button:GetParent()
	local manager = _G.ChatConfigFrame and _G.ChatConfigFrame.ChatTabManager
	return manager ~= nil and parent == manager
end

local function IsPanelButton(button)
	if button.Left ~= nil and button.Right ~= nil then return true end
	if not button.GetText then return false end
	local text = button:GetText()
	return text ~= nil and text ~= '' and button.GetNormalTexture ~= nil and button:GetNormalTexture() ~= nil
end

local function IsLegacyDropdown(frame)
	return frame.Left ~= nil and frame.Middle ~= nil and frame.Right ~= nil and frame.Button ~= nil
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

local DeepSkin

local function SkinChild(child, depth)
	if child._buiDeepSkip or child:IsForbidden() then return end
	if IsType(child, 'CheckButton') then
		CheckBox(child)
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
		DeepSkin(child, depth - 1)
		return
	end
	if IsType(child, 'Button') then
		if IsCloseButton(child) then
			Close(child)
		elseif IsTabButton(child) then
			Tab(child)
		elseif IsPanelButton(child) then
			Button(child)
		else
			DeepSkin(child, depth - 1)
		end
		return
	end
	if IsNineSlice(child) then
		FadeRegions(child)
		return
	end
	if HasBackdrop(child) then
		FadeKeys(child, BACKDROP_KEYS)
		Shell(child)
	end
	SkinScrollHost(child)
	DeepSkin(child, depth - 1)
end

DeepSkin = function(frame, depth)
	if depth <= 0 or not frame or not frame.GetChildren then return end
	for _, child in ipairs({ frame:GetChildren() }) do
		SkinChild(child, depth)
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

local function SkinWindow(frame)
	if not frame or frame._buiChatSkin or frame:IsForbidden() or not Enabled() then return end
	frame._buiChatSkin = true
	skinned[#skinned + 1] = frame

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
	DeepSkin(frame, MAX_DEPTH)
	Skin.HideHelpButtons(frame)
	Skin.TipFaceTree(frame, FONT_DEPTH)
end

local function SweepAll()
	if not Enabled() then return end
	for index = 1, #FRAMES do
		local frame = _G[FRAMES[index]]
		if frame then
			SkinWindow(frame)
			if not frame._buiChatShowHook then
				frame._buiChatShowHook = true
				HookScript(frame, 'OnShow', function(shown) SkinWindow(shown) end)
			end
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
	for index = 1, #skinned do skinned[index]._buiChatSkin = nil end
	wipe(skinned)
	BUI.Print('Chat Settings skin disabled. /reload for a full visual reset.')
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

BUI.Events:Register('ADDON_LOADED', 'Skin.ChatConfig', SweepAll)
BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Skin.ChatConfig', SweepAll)
BUI.Events:Once('PLAYER_LOGIN', 'Skin.ChatConfig', SweepAll)
