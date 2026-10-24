local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local PANEL_INSET = 8
local SELECT_BUTTON_ROOM = 14
local CONCESSION_INSET = 2
local DIVIDER_INSET = 40
local TITLE_SCALE = 1.3
local ROW_NAME_SCALE = 1.5
local HEADER_ART_ALPHA = 0.45
local DIM_ALPHA = 0.55
local SLOT_EDGE_PIXELS = 3
local TYPE_FRAME_KEYS = { 'RaidFrame', 'MythicFrame', 'PVPFrame', 'WorldFrame' }

local context = Skin.Define('greatvault', {
	name = 'Great Vault',
	description = 'The Great Vault window: dark shell, faded gold chrome, library style row titles and progress text, framed reward icons. Reward slots keep their own art.',
	icon = 'Interface/Icons/INV_Box_01',
})
local Hook = context.Hook
local Fade, FadeRegions, Keep, Line = context.Fade, context.FadeRegions, context.Keep, context.Line
local Shell, Button, Close, Body, Face = context.Shell, context.Button, context.Close, context.Body, context.Face
local FlatTexture = Skin.FlatTexture

local function ReplaceDivider(texture)
	Fade(texture)
	if texture._buiDividerLine then return end
	texture._buiDividerLine = Line(texture:GetParent(), texture, false, DIVIDER_INSET, DIVIDER_INSET, 'BORDER')
end

local function DimFrame(holder, inset)
	if holder._buiDim then return end
	holder._buiDim = true
	for _, region in ipairs({ holder:GetRegions() }) do
		if region:IsObjectType('Texture') then
			region:ClearAllPoints()
			region:SetPoint('TOPLEFT', holder, 'TOPLEFT', inset, -inset)
			region:SetPoint('BOTTOMRIGHT', holder, 'BOTTOMRIGHT', -inset, inset)
			FlatTexture(region, 0, 0, 0, DIM_ALPHA)
		end
	end
end

local function QualityEdges(holder, icon, hyperlink)
	Skin.SquareIcon(holder, icon)
	Skin.SetIconEdgeItemQuality(icon, hyperlink)
end

local function StyleItemFrame(itemFrame)
	if not itemFrame._buiItem then
		itemFrame._buiItem = true
		Keep(itemFrame.Icon)
		Keep(itemFrame.IconOverlay)
	end
	FadeRegions(itemFrame)
	local hyperlink = itemFrame.displayedItemDBID and C_WeeklyRewards.GetItemHyperlink(itemFrame.displayedItemDBID)
	QualityEdges(itemFrame, itemFrame.Icon, hyperlink)
	Face(itemFrame.Name)
end

local function BlackEdges(activity)
	if activity._buiEdges then return end
	local edges = {}
	local thickness = BUI.Pixel.PixelSizeFor(activity, SLOT_EDGE_PIXELS)
	for edgeIndex = 1, 4 do
		local edge = context.Own(activity:CreateTexture(nil, 'OVERLAY', nil, 7))
		FlatTexture(edge, 0, 0, 0, 1)
		edges[edgeIndex] = edge
	end
	edges[1]:SetPoint('TOPLEFT')
	edges[1]:SetPoint('BOTTOMRIGHT', activity, 'TOPRIGHT', 0, -thickness)
	edges[2]:SetPoint('BOTTOMLEFT')
	edges[2]:SetPoint('TOPRIGHT', activity, 'BOTTOMRIGHT', 0, thickness)
	edges[3]:SetPoint('TOPLEFT', 0, -thickness)
	edges[3]:SetPoint('BOTTOMRIGHT', activity, 'BOTTOMLEFT', thickness, thickness)
	edges[4]:SetPoint('TOPRIGHT', 0, -thickness)
	edges[4]:SetPoint('BOTTOMLEFT', activity, 'BOTTOMRIGHT', -thickness, thickness)
	activity._buiEdges = edges
end

local function SkinActivity(activity)
	local active = activity.unlocked or activity.hasRewards
	Skin.TipFont(activity.Threshold, active and 'body' or 'label')
	Skin.TipFont(activity.Progress, active and 'body' or 'label')
	BlackEdges(activity)
	if not activity._buiActivity then
		activity._buiActivity = true
		Hook(activity.ItemFrame, 'SetDisplayedItem', StyleItemFrame)
	end
	StyleItemFrame(activity.ItemFrame)
end

local function SkinConcession(concession)
	Fade(concession.Background)
	Fade(concession.SelectedTexture)
	DimFrame(concession.UnselectedFrame, CONCESSION_INSET)
	Shell(concession, CONCESSION_INSET)
	local rewards = concession.RewardsFrame
	Skin.TipFont(rewards.Label, 'label')
	Skin.TipFont(rewards.Text, concession.unlocked and 'body' or 'label')
end

local function RefreshActivities(frame)
	for _, activity in ipairs(frame.Activities) do
		if activity.RewardsFrame then
			SkinConcession(activity)
		else
			SkinActivity(activity)
		end
	end
end

local function SkinTypeFrame(typeFrame)
	Fade(typeFrame.Border)
	local background = typeFrame.Background
	Fade(background)
	background:SetAlpha(HEADER_ART_ALPHA)
	Skin.TipFont(typeFrame.Name, 'title', ROW_NAME_SCALE)
end

local function SkinOverlay(overlay)
	if not overlay then return end
	Fade(overlay.Background)
	Fade(overlay.NineSlice)
	Fade(overlay.ModelScene)
	Shell(overlay)
	Skin.TipFont(overlay.Title, 'title', TITLE_SCALE)
	Body(overlay.Text)
end

local function SkinWarning(dialog)
	Fade(dialog.NineSlice)
	Shell(dialog)
	Body(dialog.Description)
end

local function RefreshConfirm(confirm)
	local itemFrame = confirm.ItemFrame
	Fade(itemFrame.NameFrame)
	Fade(itemFrame.IconBorder)
	QualityEdges(itemFrame, itemFrame.Icon, itemFrame.itemHyperlink)
	Face(itemFrame.Name)
	Skin.TipCount(itemFrame.Count)
	local alsoItems = confirm.AlsoItemsFrame
	Body(alsoItems.Text)
	if alsoItems.pool then
		for item in alsoItems.pool:EnumerateActive() do
			Fade(item.IconBorder)
			QualityEdges(item, item.Icon, item.itemHyperlink)
		end
	end
	Skin.TipFaceTree(confirm.CurrencyFrame, 2)
end

local function SkinConfirm(confirm)
	if not confirm then return end
	if not confirm._buiConfirm then
		confirm._buiConfirm = true
		Hook(confirm, 'RefreshRewards', RefreshConfirm)
	end
	RefreshConfirm(confirm)
end

local function SkinMainFrame(frame)
	Fade(frame.Background)
	Fade(frame.BorderShadow)
	ReplaceDivider(frame.Divider1)
	ReplaceDivider(frame.Divider2)
	FadeRegions(frame.BorderContainer)
	Shell(frame, { all = PANEL_INSET, bottom = -SELECT_BUTTON_ROOM })
	local header = frame.HeaderFrame
	Skin.TipFont(header.Text, 'title', TITLE_SCALE)
	Fade(header.HeaderDivider)
	Body(frame.PreviousRewardNotification)
	for _, key in ipairs(TYPE_FRAME_KEYS) do SkinTypeFrame(frame[key]) end
	Skin.TipFont(frame.ConcessionsFrame.HeaderText, 'title')
	Button(frame.SelectRewardButton)
	Close(frame.CloseButton)
	SkinWarning(_G.WeeklyRewardExpirationWarningDialog)
end

local function ShowFrame(frame)
	RefreshActivities(frame)
	SkinOverlay(frame.Overlay)
	SkinConfirm(frame.confirmSelectionFrame)
end

local function OnSetUpActivity(frame, typeFrame)
	SkinTypeFrame(typeFrame)
	RefreshActivities(frame)
end

local function OnOverlay(frame)
	SkinOverlay(frame.Overlay)
end

local function OnSelectReward(frame)
	SkinConfirm(frame.confirmSelectionFrame)
end

local function InstallFrame(frame)
	Hook(frame, 'Refresh', RefreshActivities)
	Hook(frame, 'SetUpActivity', OnSetUpActivity)
	Hook(frame, 'UpdateOverlay', OnOverlay)
	Hook(frame, 'SelectReward', OnSelectReward)
	_G.WeeklyRewardExpirationWarningDialog:HookScript('OnShow', context.Guard(SkinWarning))
end

context.Window('WeeklyRewardsFrame', { install = InstallFrame, skin = SkinMainFrame, show = ShowFrame })
