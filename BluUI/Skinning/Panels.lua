local _, BUI = ...

local Skin = BUI.Skinning

local ART_KEYS = { 'Border', 'BorderFrame', 'Background', 'BackgroundTile', 'BG', 'Bg', 'NineSlice', 'Inset', 'InsetFrame', 'PortraitContainer', 'TitleBg', 'TitleContainer', 'TopTileStreaks', 'ArtFrame', 'Overlay' }
local CLOSE_KEYS = { 'CloseButton', 'ClosePanelButton', 'CloseDialogButton', 'closeButton' }
local SCROLL_KEYS = { 'ScrollBar', 'scrollBar' }
local BUTTON_KEYS = { 'OkayButton', 'OkButton', 'CancelButton', 'AcceptButton', 'DeclineButton', 'ApplyButton', 'ResetButton', 'DefaultsButton', 'SaveButton', 'DeleteButton', 'PurchaseButton', 'ContinueButton', 'StartButton', 'UnlockButton', 'LeaveButton', 'RequestButton' }
local DROPDOWN_KEYS = { 'Dropdown', 'DropDown', 'FilterDropdown', 'SelectionDropdown', 'CategoryDropdown' }
local FONT_DEPTH = 2
local MODEL_CONTROL_KEYS = { 'zoomInButton', 'zoomOutButton', 'rotateLeftButton', 'rotateRightButton', 'resetButton' }
local MODEL_CONTROL_INSET = 4

local function SkinHousingPreview(frame, context)
	local preview = frame.ModelPreview
	if not preview then return end
	context.FadeRegions(preview)
	local controls = preview.ModelSceneControls
	for index = 1, #MODEL_CONTROL_KEYS do
		local button = controls[MODEL_CONTROL_KEYS[index]]
		context.Fade(button.NormalTexture)
		context.Fade(button.PushedTexture)
		context.Shell(button, MODEL_CONTROL_INSET)
	end
	Skin.TipPageButton(preview.VariantLeftButton, 'previous')
	Skin.TipPageButton(preview.VariantRightButton, 'next')
	Skin.TipFaceTree(preview, FONT_DEPTH)
	context.Title(preview.NameContainer.Name)
end

local WINDOWS = {
	{
		id = 'petstable',
		name = 'Pet Stable',
		description = 'The stable master window where you swap and rename pets.',
		icon = 'Interface/Icons/Ability_Hunter_BeastCall',
		frames = { 'StableFrame', 'PetStableFrame' },
	},
	{
		id = 'playerchoice',
		name = 'Quest Choice',
		description = 'The card popup where a quest or event asks you to pick one option.',
		icon = 'Interface/Icons/INV_Misc_Book_09',
		frames = { 'PlayerChoiceFrame' },
	},
	{
		id = 'tradingpost',
		legacy = 'shop',
		name = 'Trading Post',
		description = 'The monthly trading post window.',
		icon = 'Interface/Icons/INV_Misc_Coin_01',
		frames = { 'PerksProgramFrame' },
	},
	{
		id = 'catalogshop',
		legacy = 'shop',
		name = 'In-Game Shop',
		description = 'The Blizzard shop browser.',
		icon = 'Interface/Icons/INV_Misc_Coin_02',
		frames = { 'CatalogShopFrame' },
	},
	{
		id = 'pvpmatch',
		name = 'PvP Scoreboard',
		description = 'The end-of-match results window and the in-match scoreboard.',
		icon = 'Interface/Icons/Achievement_PVP_A_01',
		frames = { 'PVPMatchResults', 'PVPMatchScoreboard' },
	},
	{
		id = 'renown',
		name = 'Renown',
		description = 'The major faction renown track window.',
		icon = 'Interface/Icons/Achievement_Reputation_01',
		frames = { 'MajorFactionRenownFrame' },
	},
	{
		id = 'landingpage',
		legacy = 'renown',
		name = 'Expansion Summary',
		description = 'The expansion landing page opened from the minimap.',
		icon = 'Interface/Icons/INV_Misc_Map_01',
		frames = { 'ExpansionLandingPage' },
	},
	{
		id = 'keybinds',
		name = 'Key Bindings',
		description = 'The key bindings window from the game menu.',
		icon = 'Interface/Icons/INV_Misc_Key_03',
		frames = { 'KeyBindingFrame' },
	},
	{
		id = 'currencytransfer',
		name = 'Currency Transfer',
		description = 'The Warband currency transfer dialog.',
		icon = 'Interface/Icons/INV_Misc_Coin_02',
		frames = { 'CurrencyTransferMenu' },
		extra = function(frame, context)
			local content = frame.Content
			if not content then return end
			context.FadeArt(content)
			context.Button(content.ConfirmButton)
			context.Button(content.CancelButton)
			if content.SourceSelector then context.Dropdown(content.SourceSelector.Dropdown) end
			if content.AmountSelector then
				context.Button(content.AmountSelector.MaxQuantityButton)
				context.EditBox(content.AmountSelector.InputBox)
			end
		end,
	},
	{
		id = 'housing',
		name = 'Housing',
		description = 'The housing dashboard, house finder, bulletin board, cornerstone and decor preview windows.',
		icon = 'Interface/Icons/INV_Misc_Bell_01',
		frames = { 'HousingDashboardFrame', 'HouseFinderFrame', 'HouseListFrame', 'HousingBulletinBoardFrame', 'HousingInviteResidentFrame', 'HousingCornerstoneFrame', 'HousingCornerstoneHouseInfoFrame', 'HousingCornerstonePurchaseFrame', 'HousingCornerstoneVisitorFrame', 'HousingHouseSettingsFrame', 'HousingModelPreviewFrame' },
		extra = SkinHousingPreview,
	},
	{
		id = 'barbershop',
		legacy = 'miscpanels',
		name = 'Barber Shop',
		description = 'The barber shop appearance window.',
		icon = 'Interface/Icons/INV_Misc_Comb_01',
		frames = { 'BarberShopFrame' },
	},
	{
		id = 'iteminteraction',
		legacy = 'miscpanels',
		name = 'Item Interaction',
		description = 'The drop-an-item-here window used by catalysts, upgrade NPCs and similar.',
		icon = 'Interface/Icons/INV_Misc_Gear_01',
		frames = { 'ItemInteractionFrame' },
	},
	{
		id = 'clock',
		legacy = 'miscpanels',
		name = 'Clock & Stopwatch',
		description = 'The clock window from the minimap and the stopwatch.',
		icon = 'Interface/Icons/INV_Misc_PocketWatch_01',
		frames = { 'TimeManagerFrame', 'StopwatchFrame' },
	},
	{
		id = 'tabard',
		legacy = 'miscpanels',
		name = 'Tabard Designer',
		description = 'The guild tabard design window.',
		icon = 'Interface/Icons/INV_Shirt_GuildTabard_01',
		frames = { 'TabardFrame' },
	},
	{
		id = 'petition',
		legacy = 'miscpanels',
		name = 'Guild Charter',
		description = 'The petition window for signing a guild charter.',
		icon = 'Interface/Icons/INV_Scroll_11',
		frames = { 'PetitionFrame' },
	},
	{
		id = 'help',
		legacy = 'miscpanels',
		name = 'Help & Support',
		description = 'The customer support and help window.',
		icon = 'Interface/Icons/INV_Misc_QuestionMark',
		frames = { 'HelpFrame' },
	},
	{
		id = 'talkinghead',
		legacy = 'miscpanels',
		name = 'Talking Head',
		description = 'The NPC dialogue popup with the animated portrait.',
		icon = 'Interface/Icons/Achievement_Reputation_01',
		frames = { 'TalkingHeadFrame' },
	},
	{
		id = 'guildregistrar',
		legacy = 'miscpanels',
		name = 'Guild Registrar',
		description = 'The window where you buy a guild charter.',
		icon = 'Interface/Icons/INV_Misc_Note_02',
		frames = { 'GuildRegistrarFrame' },
	},
}

local function SkinWindow(entry, frame)
	if not frame or frame._buiPanelSkin or frame:IsForbidden() then return end
	frame._buiPanelSkin = true
	entry.skinned[#entry.skinned + 1] = frame

	local context = entry.context
	context.FadeArt(frame)
	context.FadeKeys(frame, ART_KEYS)
	context.Shell(frame)
	for index = 1, #CLOSE_KEYS do context.Close(frame[CLOSE_KEYS[index]]) end
	for index = 1, #SCROLL_KEYS do context.ScrollBar(frame[SCROLL_KEYS[index]]) end
	for index = 1, #BUTTON_KEYS do context.Button(frame[BUTTON_KEYS[index]]) end
	for index = 1, #DROPDOWN_KEYS do context.Dropdown(frame[DROPDOWN_KEYS[index]]) end
	if entry.extra then entry.extra(frame, context) end
	Skin.HideHelpButtons(frame)
	Skin.TipFaceTree(frame, FONT_DEPTH)
end

local function TrySkin(entry)
	if not entry.enabled() then return end
	for index = 1, #entry.frames do
		SkinWindow(entry, _G[entry.frames[index]])
	end
end

local function SweepAll()
	for index = 1, #WINDOWS do TrySkin(WINDOWS[index]) end
end

for index = 1, #WINDOWS do
	local entry = WINDOWS[index]
	entry.skinned = {}
	entry.enabled = function() return Skin.IsSkinEnabled(entry.id) end
	entry.context = Skin.NewContext(entry.enabled)
	Skin.OnToggle(entry.id, function(enabled)
		if enabled then
			for frameIndex = 1, #entry.skinned do entry.skinned[frameIndex]._buiPanelSkin = nil end
			TrySkin(entry)
		else
			entry.context.Restore()
		end
	end)
	Skin.RegisterSkin(entry.id, {
		name = entry.name,
		description = entry.description,
		icon = entry.icon,
		legacy = entry.legacy,
	})
end

BUI.Events:Register('ADDON_LOADED', 'Skin.Panels', SweepAll)
BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Skin.Panels', SweepAll)
BUI.Events:Once('PLAYER_LOGIN', 'Skin.Panels', SweepAll)
