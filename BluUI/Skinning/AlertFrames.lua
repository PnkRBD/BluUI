local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local ANCHOR_KEY = 'alerts'
local ANCHOR_DEFAULT_Y = 180
local FACE_DEPTH = 2
local ICON_KEYS = { 'Icon', 'dungeonTexture', 'QuestTexture' }
local PART_KEYS = { 'Icon', 'Shield', 'lootItem' }
local KEEP_KEYS = { 'RollTypeIcon', 'SpecIcon', 'heroicIcon', 'DigsiteTypeTexture', 'EmblemIcon', 'GuildTabardEmblem', 'MissionType', 'Portrait', 'DieIcon', 'Banner', 'Checkmark' }
local EFFECT_KEYS = {
	'Background', 'Background2', 'Background3', 'Ring1', 'Particles1', 'Particles2', 'Particles3', 'Starglow',
	'Sheen', 'BorderGlow', 'BaseQualityBorder', 'UpgradeQualityBorder', 'Glow', 'LightRays', 'LightRays2', 'Sparkles',
}
local FLASH_KEYS = { 'glow', 'shine' }
local CAPTION_KEYS = { 'Label', 'Title', 'Unlocked', 'ToastText', 'completionText', 'HeaderLabel', 'CollectedLabel', 'CompletedLabel' }
local NAME_KEYS = { 'Name', 'Amount', 'instanceName', 'dungeonName', 'QuestName', 'ZoneName', 'DigsiteType', 'Description', 'GuildName', 'DecorName', 'TaskName' }

local context = Skin.Define('alerts', {
	name = 'Alert Toasts',
	description = 'Loot, money, achievement and other reward pop-ups in a dark card with a framed icon.',
	icon = 'Interface/Icons/INV_Misc_Bag_10',
	newLook = true,
	unlock = {
		tooltip = 'Unlock position. Drag the toast window, then click again to lock.',
		get = function() return Skin.ToastAnchors.IsUnlocked(ANCHOR_KEY) end,
		set = function(value) Skin.ToastAnchors.SetUnlocked(ANCHOR_KEY, value) end,
	},
})
local FadeRegions, Shell, Keep = context.FadeRegions, context.Shell, context.Keep
local Title, Body, Face = context.Title, context.Body, context.Face
local CropIcon = Skin.CropIcon

local skinned = {}

local function AlertIcon(frame)
	local loot = frame.lootItem
	if loot then return loot.Icon end
	for _, key in ipairs(ICON_KEYS) do
		local icon = frame[key]
		if icon then
			if icon:IsObjectType('Texture') then return icon end
			return icon.Texture
		end
	end
end

local function StripArt(part)
	for _, key in ipairs(KEEP_KEYS) do Keep(part[key]) end
	FadeRegions(part)
end

local function HideKeys(frame, keys)
	for _, key in ipairs(keys) do
		local region = frame[key]
		if region then region:Hide() end
	end
end

local function ApplyFonts(frame, keys, apply)
	for _, key in ipairs(keys) do apply(frame[key]) end
end

local function SkinAlert(frame)
	local icon = Keep(AlertIcon(frame))
	StripArt(frame)
	for _, key in ipairs(PART_KEYS) do
		local part = frame[key]
		if part then StripArt(part) end
	end
	HideKeys(frame, EFFECT_KEYS)
	Shell(frame)
	Skin.HoverEdge(frame)
	if icon and not icon:GetAtlas() then Skin.SquareIcon(frame, icon) end
	Skin.TipFaceTree(frame, FACE_DEPTH)
	ApplyFonts(frame, CAPTION_KEYS, Title)
	ApplyFonts(frame, NAME_KEYS, Body)
	local loot = frame.lootItem
	if loot then Skin.TipCount(loot.Count) end
end

local function RefreshAlert(frame)
	HideKeys(frame, FLASH_KEYS)
	if frame.tradeSkillID then
		frame.Icon:SetMask('')
		CropIcon(frame.Icon)
	end
	if frame.hyperlink then Skin.SetIconEdgeItemQuality(AlertIcon(frame), frame.hyperlink) end
	local shield = frame.Shield
	if shield then Face(shield.Points) end
end

local function OnAlertAdded(_, frame)
	if frame:IsForbidden() then return end
	if not skinned[frame] then
		skinned[frame] = true
		SkinAlert(frame)
	end
	RefreshAlert(frame)
end

local function SkinActive(container)
	for _, subSystem in ipairs(container.alertFrameSubSystems) do
		local pool = subSystem.alertFramePool
		if pool then
			for frame in pool:EnumerateActive() do OnAlertAdded(container, frame) end
		end
	end
end

local function SkinRewards(frame)
	local rewards = frame.RewardFrames
	if not rewards then return end
	for _, button in ipairs(rewards) do
		if not skinned[button] then
			skinned[button] = true
			local icon = Keep(button.texture)
			icon:RemoveMaskTexture(button.CircleMask)
			FadeRegions(button)
			Skin.SquareIcon(button, icon)
		end
	end
end

context.Window('AlertFrame', {
	install = function(frame)
		context.Hook(frame, 'AddAlertFrame', OnAlertAdded)
		context.Hook('StandardRewardAlertFrame_AdjustRewardAnchors', SkinRewards)
	end,
	enable = SkinActive,
})

context.OnDisable(function() wipe(skinned) end)

Skin.ToastAnchors.Register({
	key = ANCHOR_KEY,
	label = 'ALERT FRAMES',
	defaultY = ANCHOR_DEFAULT_Y,
	point = 'BOTTOM',
	sample = 'toast',
	sampleRelativePoint = 'TOP',
	config = function() return BUI.GetDB().alerts end,
	frame = function() return _G.AlertFrame end,
	apply = function(frame, anchor)
		frame:ClearAllPoints()
		frame:SetAllPoints(anchor)
	end,
	hooks = function(reapply) BUI.Hook('AlertFrames.reapply', _G.AlertFrame, 'UpdateAnchors', reapply) end,
})
