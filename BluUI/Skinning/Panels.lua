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
local SLIDER_TEXT_KEYS = { 'LeftText', 'RightText', 'TopText', 'MinText', 'MaxText' }

local function SkinStepper(button, direction, context)
	if not button then return end
	Skin.TipStepper(button, direction)
	context.FadeRegions(button)
end

local function SkinCustomizeRow(row, context)
	if row._buiCustomizeRow then return end
	row._buiCustomizeRow = true
	context.Face(row.Label)
	if row.Dropdown then
		local details = row.Dropdown.SelectionDetails
		Skin.TipDropdown(row.Dropdown, nil, true)
		Skin.TipFont(details.SelectionName, 'body')
		Skin.TipFont(details.SelectionNumber, 'body')
		context.Fade(details.SelectionNumberBG)
		SkinStepper(row.DecrementButton, 'previous', context)
		SkinStepper(row.IncrementButton, 'next', context)
	elseif row.Slider then
		Skin.TipSliderTrack(row.Slider)
		SkinStepper(row.Back, 'previous', context)
		SkinStepper(row.Forward, 'next', context)
		for index = 1, #SLIDER_TEXT_KEYS do context.Face(row[SLIDER_TEXT_KEYS[index]]) end
	elseif row.Button then
		Skin.TipCheckBox(row.Button)
	end
end

local function SkinCustomizeOptions(customize, context)
	for _, row in ipairs({ customize.Options:GetChildren() }) do SkinCustomizeRow(row, context) end
end

local function SkinBarberShop(_, context)
	local customize = CharCustomizeFrame
	if not customize or customize._buiCustomizeHooked then return end
	customize._buiCustomizeHooked = true
	context.Hook(customize, 'UpdateOptionButtons', function() SkinCustomizeOptions(customize, context) end)
	SkinCustomizeOptions(customize, context)
end

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

local TABARD_ROWS = 5
local TABARD_BOXES = { 'TabardFrameCostFrame', 'TabardFrameMoneyInset' }

local function SkinTabard(_, context)
	for index = 1, TABARD_ROWS do
		local name = 'TabardFrameCustomization' .. index
		local row = _G[name]
		context.FadeRegions(row)
		context.Card(row)
		Skin.TipFont(_G[name .. 'Text'], 'body')
		Skin.TipPageButton(_G[name .. 'LeftButton'], 'previous')
		Skin.TipPageButton(_G[name .. 'RightButton'], 'next')
	end
	context.FadeRegions(_G.TabardFrameCustomizationFrame)
	for _, boxName in ipairs(TABARD_BOXES) do
		local box = _G[boxName]
		context.FadeArt(box)
		context.Shell(box)
	end
	context.FadeRegions(_G.TabardFrameMoneyBg)
	context.Button(_G.TabardFrameAcceptButton)
	context.Button(_G.TabardFrameCancelButton)
	Skin.TipPageButton(_G.TabardCharacterModelRotateLeftButton, 'previous')
	Skin.TipPageButton(_G.TabardCharacterModelRotateRightButton, 'next')
	context.Title(_G.TabardFrameNameText)
	context.Body(_G.TabardFrameGreetingText)
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
		fullscreen = true,
		extra = SkinBarberShop,
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
		description = 'The guild tabard design window: card rows with page arrows for each part of the design.',
		icon = 'Interface/Icons/INV_Shirt_GuildTabard_01',
		frames = { 'TabardFrame' },
		newLook = true,
		extra = SkinTabard,
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

local function SkinWindow(entry, frame, context)
	if not entry.fullscreen then
		context.FadeKeys(frame, ART_KEYS)
		Skin.TipFaceTree(frame, FONT_DEPTH)
		context.Chrome(frame)
	end
	for index = 1, #CLOSE_KEYS do context.Close(frame[CLOSE_KEYS[index]]) end
	for index = 1, #SCROLL_KEYS do context.ScrollBar(frame[SCROLL_KEYS[index]]) end
	for index = 1, #BUTTON_KEYS do context.Button(frame[BUTTON_KEYS[index]]) end
	for index = 1, #DROPDOWN_KEYS do context.Dropdown(frame[DROPDOWN_KEYS[index]]) end
	if entry.extra then entry.extra(frame, context) end
	Skin.HideHelpButtons(frame)
end

for _, entry in ipairs(WINDOWS) do
	local context = Skin.Define(entry.id, {
		name = entry.name,
		description = entry.description,
		icon = entry.icon,
		legacy = entry.legacy,
		newLook = entry.newLook,
	})
	local function SkinFrame(frame) SkinWindow(entry, frame, context) end
	for _, frameName in ipairs(entry.frames) do context.Window(frameName, { skin = SkinFrame }) end
end
