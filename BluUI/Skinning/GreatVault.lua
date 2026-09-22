local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('GreatVault')

local hooksecurefunc = BUI.Prof.MakeHooker('greatvault')
local ipairs, select = ipairs, select

local Skin = BUI.Skinning

local SKIN_ID = 'greatvault'
local PANEL_INSET = 8
local SELECT_BUTTON_ROOM = 14
local CARD_INSET = 2
local CONCESSION_INSET = 2
local DIVIDER_INSET = 40
local TITLE_SCALE = 1.3
local ROW_NAME_SCALE = 1.5
local HEADER_ART_ALPHA = 0.45
local CHEST_ALPHA = 0.35
local DIM_ALPHA = 0.55
local TYPE_FRAME_KEYS = { 'RaidFrame', 'MythicFrame', 'PVPFrame', 'WorldFrame' }
local ACTIVITY_CHROME = { 'Border', 'ItemGlow', 'UncollectedGlow', 'SelectedTexture' }

local installed = false
local skinned = false
local dividerLines = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, Body, Face = context.Shell, context.Button, context.Close, context.Body, context.Face
local FlatTexture, CropIcon = Skin.FlatTexture, Skin.CropIcon

local function ReplaceDivider(texture)
	if not texture then return end
	Fade(texture)
	local line = texture._buiDividerLine
	if not line then
		line = texture:GetParent():CreateTexture(nil, 'BORDER')
		line.__buiSkin = true
		line:SetHeight(1)
		line:SetPoint('LEFT', texture, 'LEFT', DIVIDER_INSET, 0)
		line:SetPoint('RIGHT', texture, 'RIGHT', -DIVIDER_INSET, 0)
		local edge = Skin.PANEL_EDGE
		FlatTexture(line, edge[1], edge[2], edge[3], edge[4])
		texture._buiDividerLine = line
		dividerLines[#dividerLines + 1] = line
	end
	line:Show()
end

local function DimFrame(holder, inset)
	if not holder or holder._buiDim then return end
	holder._buiDim = true
	for regionIndex = 1, select('#', holder:GetRegions()) do
		local region = select(regionIndex, holder:GetRegions())
		if region:IsObjectType('Texture') then
			region:ClearAllPoints()
			region:SetPoint('TOPLEFT', holder, 'TOPLEFT', inset, -inset)
			region:SetPoint('BOTTOMRIGHT', holder, 'BOTTOMRIGHT', -inset, inset)
			FlatTexture(region, 0, 0, 0, DIM_ALPHA)
		end
	end
end

local function QualityEdges(holder, icon, hyperlink)
	CropIcon(icon)
	Skin.TipIconFrame(holder, icon)
	Skin.SetIconEdgeItemQuality(icon, hyperlink)
end

local function StyleItemFrame(itemFrame)
	if not Enabled() or not itemFrame then return end
	if not itemFrame._buiItem then
		itemFrame._buiItem = true
		if itemFrame.Icon then itemFrame.Icon.__buiSkin = true end
		if itemFrame.IconOverlay then itemFrame.IconOverlay.__buiSkin = true end
	end
	FadeRegions(itemFrame)
	local hyperlink = itemFrame.displayedItemDBID and C_WeeklyRewards.GetItemHyperlink(itemFrame.displayedItemDBID)
	QualityEdges(itemFrame, itemFrame.Icon, hyperlink)
	Face(itemFrame.Name)
end

local function SkinActivity(activity)
	local active = activity.unlocked or activity.hasRewards
	FadeKeys(activity, ACTIVITY_CHROME)
	Fade(activity.SelectionGlow)
	local background = activity.Background
	if background then
		Fade(background)
		background:SetAlpha(active and CHEST_ALPHA or 0)
	end
	DimFrame(activity.UnselectedFrame, CARD_INSET)
	Shell(activity, CARD_INSET)
	Skin.TipFont(activity.Threshold, active and 'body' or 'label')
	Skin.TipFont(activity.Progress, active and 'body' or 'label')
	local itemFrame = activity.ItemFrame
	if itemFrame then
		if not activity._buiActivity then
			activity._buiActivity = true
			hooksecurefunc(itemFrame, 'SetDisplayedItem', StyleItemFrame)
		end
		StyleItemFrame(itemFrame)
	end
end

local function SkinConcession(concession)
	Fade(concession.Background)
	Fade(concession.SelectedTexture)
	DimFrame(concession.UnselectedFrame, CONCESSION_INSET)
	Shell(concession, CONCESSION_INSET)
	local rewards = concession.RewardsFrame
	if not rewards then return end
	Skin.TipFont(rewards.Label, 'label')
	Skin.TipFont(rewards.Text, concession.unlocked and 'body' or 'label')
end

local function RefreshSelection(frame)
	if not Enabled() or not frame.Activities then return end
	for _, activity in ipairs(frame.Activities) do
		local selected = activity.SelectedTexture and activity.SelectedTexture:IsShown()
		Skin.TipShellEdges(activity, selected)
	end
end

local function RefreshActivities(frame)
	if not Enabled() or not frame.Activities then return end
	for _, activity in ipairs(frame.Activities) do
		if activity.RewardsFrame then
			SkinConcession(activity)
		else
			SkinActivity(activity)
		end
	end
	RefreshSelection(frame)
end

local function SkinTypeFrame(typeFrame)
	if not typeFrame then return end
	Fade(typeFrame.Border)
	local background = typeFrame.Background
	if background then
		Fade(background)
		background:SetAlpha(HEADER_ART_ALPHA)
	end
	Skin.TipFont(typeFrame.Name, 'title', ROW_NAME_SCALE)
end

local function SkinOverlay(overlay)
	if not overlay or not Enabled() then return end
	Fade(overlay.Background)
	Fade(overlay.NineSlice)
	Fade(overlay.ModelScene)
	Shell(overlay)
	Skin.TipFont(overlay.Title, 'title', TITLE_SCALE)
	Body(overlay.Text)
end

local function SkinWarning(dialog)
	if not dialog or not Enabled() then return end
	Fade(dialog.NineSlice)
	Shell(dialog)
	Body(dialog.Description)
end

local function RefreshConfirm(confirm)
	if not confirm or not Enabled() then return end
	local itemFrame = confirm.ItemFrame
	if itemFrame then
		Fade(itemFrame.NameFrame)
		Fade(itemFrame.IconBorder)
		QualityEdges(itemFrame, itemFrame.Icon, itemFrame.itemHyperlink)
		Face(itemFrame.Name)
		Face(itemFrame.Count)
	end
	local alsoItems = confirm.AlsoItemsFrame
	if alsoItems then
		Body(alsoItems.Text)
		if alsoItems.pool then
			for item in alsoItems.pool:EnumerateActive() do
				Fade(item.IconBorder)
				QualityEdges(item, item.Icon, item.itemHyperlink)
			end
		end
	end
	Skin.TipFaceTree(confirm.CurrencyFrame, 2)
end

local function SkinConfirm(confirm)
	if not confirm then return end
	if not confirm._buiConfirm then
		confirm._buiConfirm = true
		hooksecurefunc(confirm, 'RefreshRewards', RefreshConfirm)
	end
	RefreshConfirm(confirm)
end

local function SkinMainFrame(frame)
	Fade(frame.Background)
	Fade(frame.BorderShadow)
	Fade(frame.ModelScene)
	ReplaceDivider(frame.Divider1)
	ReplaceDivider(frame.Divider2)
	FadeRegions(frame.BorderContainer)
	Shell(frame, { all = PANEL_INSET, bottom = -SELECT_BUTTON_ROOM })
	local header = frame.HeaderFrame
	if header then
		Skin.TipFont(header.Text, 'title', TITLE_SCALE)
		Fade(header.HeaderDivider)
	end
	Body(frame.PreviousRewardNotification)
	for _, key in ipairs(TYPE_FRAME_KEYS) do SkinTypeFrame(frame[key]) end
	local concessions = frame.ConcessionsFrame
	if concessions then Skin.TipFont(concessions.HeaderText, 'title') end
	Button(frame.SelectRewardButton)
	Close(frame.CloseButton)
	SkinWarning(_G.WeeklyRewardExpirationWarningDialog)
end

local function Apply()
	local frame = _G.WeeklyRewardsFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not skinned then
		skinned = true
		SkinMainFrame(frame)
	end
	RefreshActivities(frame)
	SkinOverlay(frame.Overlay)
	SkinConfirm(frame.confirmSelectionFrame)
end

local function OnRefresh(frame)
	if skinned then RefreshActivities(frame) end
end

local function OnSelection(frame)
	if skinned then RefreshSelection(frame) end
end

local function OnSetUpActivity(frame, typeFrame)
	if not skinned or not Enabled() then return end
	SkinTypeFrame(typeFrame)
	RefreshActivities(frame)
end

local function OnOverlay(frame)
	if skinned then SkinOverlay(frame.Overlay) end
end

local function OnSelectReward(frame)
	if skinned and Enabled() then SkinConfirm(frame.confirmSelectionFrame) end
end

local function Install()
	if installed then return end
	local frame = _G.WeeklyRewardsFrame
	if not frame then return end
	installed = true
	HookScript(frame, 'OnShow', Apply)
	hooksecurefunc(frame, 'Refresh', OnRefresh)
	hooksecurefunc(frame, 'UpdateSelection', OnSelection)
	hooksecurefunc(frame, 'SetUpActivity', OnSetUpActivity)
	hooksecurefunc(frame, 'UpdateOverlay', OnOverlay)
	hooksecurefunc(frame, 'SelectReward', OnSelectReward)
	local warning = _G.WeeklyRewardExpirationWarningDialog
	if warning then HookScript(warning, 'OnShow', SkinWarning) end
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.GreatVault') end
end

local function Deactivate()
	context.Restore()
	for _, line in ipairs(dividerLines) do line:Hide() end
	skinned = false
	BUI.Print('Great Vault skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.GreatVault', TryInstall)
		elseif _G.WeeklyRewardsFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Great Vault',
	description = 'The Great Vault window: dark shell, faded gold chrome, house row titles and progress text, framed reward icons and accent-edged selection.',
	icon = 'Interface/Icons/INV_Box_01',
})
