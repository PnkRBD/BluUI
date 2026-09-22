local _, BUI = ...

local Skin = BUI.Skinning
local hooksecurefunc = BUI.Prof.MakeHooker('alertframes')
local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Layout = BUILib.Layout

local SKIN_ID = 'alerts'
local TITLE_KEYS = { 'Label', 'Title', 'Unlocked', 'TopText' }
local BODY_KEYS = { 'ItemName', 'Name', 'Amount', 'BonusText', 'RewardText', 'SubTitle', 'Text' }
local ANCHOR_DEFAULT_Y = 180

local installed = false
local skinnedAlerts = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local FadeRegions, Shell, Body, Title = context.FadeRegions, context.Shell, context.Body, context.Title
local CropIcon = Skin.CropIcon

local function FontString(frame, key)
	local region = frame[key]
	if region and region.GetStringWidth then return region end
	return nil
end

local function AlertIcon(frame)
	local icon = frame.Icon
	if icon and icon.SetTexCoord then return icon end
	if icon and icon.texture and icon.texture.SetTexCoord then return icon.texture end
	local lootItem = frame.lootItem
	if lootItem and lootItem.Icon and lootItem.Icon.SetTexCoord then return lootItem.Icon end
	return nil
end

local function SkinAlert(frame)
	if not frame or frame._buiAlert or frame:IsForbidden() then return end
	frame._buiAlert = true
	skinnedAlerts[#skinnedAlerts + 1] = frame

	local icon = AlertIcon(frame)
	if icon then icon.__buiSkin = true end
	FadeRegions(frame)
	Shell(frame)
	if icon then
		CropIcon(icon)
		Skin.TipIconFrame(frame, icon)
	end
	for index = 1, #TITLE_KEYS do Title(FontString(frame, TITLE_KEYS[index])) end
	for index = 1, #BODY_KEYS do Body(FontString(frame, BODY_KEYS[index])) end
end

local function SweepAlerts()
	if not Enabled() then return end
	local alertFrame = _G.AlertFrame
	local subSystems = alertFrame and alertFrame.alertFrameSubSystems
	if not subSystems then return end
	for index = 1, #subSystems do
		local pool = subSystems[index].alertFramePool
		if pool and pool.EnumerateActive then
			for frame in pool:EnumerateActive() do SkinAlert(frame) end
		end
	end
end

local function Install()
	if installed or not Enabled() then return end
	local alertFrame = _G.AlertFrame
	if not alertFrame or not alertFrame.UpdateAnchors then return end
	installed = true
	hooksecurefunc(alertFrame, 'UpdateAnchors', SweepAlerts)
	SweepAlerts()
end

Skin.ToastAnchors.Register({
	key = 'alerts',
	label = 'ALERT FRAMES',
	defaultY = ANCHOR_DEFAULT_Y,
	point = 'BOTTOM',
	sample = 'toast',
	sampleRelativePoint = 'TOP',
	config = function()
		local db = BUI.GetDB()
		return db and db.alerts
	end,
	frame = function() return _G.AlertFrame end,
	apply = function(frame, anchor)
		frame:ClearAllPoints()
		frame:SetAllPoints(anchor)
	end,
	hooks = function(reapply)
		local alertFrame = _G.AlertFrame
		if alertFrame and alertFrame.UpdateAnchors then hooksecurefunc(alertFrame, 'UpdateAnchors', reapply) end
	end,
})

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		for index = 1, #skinnedAlerts do skinnedAlerts[index]._buiAlert = nil end
		Install()
		SweepAlerts()
	else
		context.Restore()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Alert Toasts',
	description = 'The pop-ups that slide up mid-screen when you win loot, gain money or earn an achievement: dark shell, framed icon, house font, none of the gold filigree.',
	icon = 'Interface/Icons/INV_Misc_Bag_10',
	unlock = {
		tooltip = 'Unlock position. Drag the toast window, then click again to lock.',
		get = function() return Skin.ToastAnchors.IsUnlocked('alerts') end,
		set = function(value) Skin.ToastAnchors.SetUnlocked('alerts', value) end,
	},
})

BUI.Events:Once('PLAYER_LOGIN', 'Skin.AlertFrames', Install)
