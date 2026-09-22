local _, BUI = ...

local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'bnetToast'
local BLIZZARD_ADDON = 'Blizzard_BNet'
local BN_TOAST_TYPE_NEW_INVITE = 5
local TOAST_NAMES = { 'BNToastFrame', 'TimeAlertFrame' }
local TEXT_KEYS = { 'TopLine', 'MiddleLine', 'BottomLine', 'DoubleLine', 'Text' }

local installed = false
local skinnedToasts = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, Shell, Close, Body = context.Fade, context.FadeRegions, context.Shell, context.Close, context.Body

local function SkinToast(frame)
	if not frame or frame._buiToast then return end
	frame._buiToast = true
	skinnedToasts[#skinnedToasts + 1] = frame
	if frame.SetBackdrop then frame:SetBackdrop(nil) end
	local name = frame:GetName()
	Fade(frame.GlowFrame or (name and _G[name .. 'GlowFrame']))
	Shell(frame)
	Close(frame.CloseButton)
	for _, key in ipairs(TEXT_KEYS) do Body(frame[key]) end
	if frame.IconTexture then Skin.TipIconFrame(frame, frame.IconTexture) end
	local tooltip = frame.TooltipFrame
	if tooltip then
		FadeRegions(tooltip)
		Fade(tooltip.NineSlice)
		Shell(tooltip)
		Body(tooltip.Text)
	end
end

local function Apply()
	if not Enabled() then return end
	for _, name in ipairs(TOAST_NAMES) do SkinToast(_G[name]) end
end

local function Install()
	if installed or not Enabled() then return end
	if not _G.BNToastFrame then return end
	installed = true
	Apply()
end

local function TryInstall(_, addonName)
	if addonName and addonName ~= BLIZZARD_ADDON then return end
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.BNToast') end
end

local function Deactivate()
	context.Restore()
	for _, frame in ipairs(skinnedToasts) do
		if frame.ApplyBackdrop and frame.backdropInfo then frame:ApplyBackdrop() end
		if frame.IconTexture then Skin.SetIconEdgeThickness(frame.IconTexture, 0) end
		frame._buiToast = nil
	end
	wipe(skinnedToasts)
	BUI.Print('Battle.net toast skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.BNToast', TryInstall)
		else
			Apply()
		end
	else
		Deactivate()
	end
end)

local previewing = false

local function IsPreviewing()
	local toast = _G.BNToastFrame
	return previewing and toast ~= nil and toast:IsShown()
end

local function StartPreview()
	local toast = _G.BNToastFrame
	if not toast or not toast.AddToast or InCombatLockdown() then return end
	previewing = true
	toast:AddToast(BN_TOAST_TYPE_NEW_INVITE)
	BUI.Prof.After('BNToast', 0.05, function()
		if previewing and toast:IsShown() and _G.AlertFrame_PauseOutAnimation then _G.AlertFrame_PauseOutAnimation(toast) end
	end)
end

local function StopPreview()
	previewing = false
	local toast = _G.BNToastFrame
	if toast and toast:IsShown() and _G.AlertFrame_PlayOutAnimation then _G.AlertFrame_PlayOutAnimation(toast, 0) end
end

Skin.RegisterSkin(SKIN_ID, {
	name = 'Battle.net Toasts',
	description = 'The small pop-up when a Battle.net friend comes online, goes offline, broadcasts or sends an invite: dark shell, framed portrait, house font, flat close button.',
	icon = 'Interface/FriendsFrame/Battlenet-Battleneticon',
	unlock = {
		tooltip = 'Show a test toast held on screen so you can drag it where you want. Click again to dismiss it.',
		get = IsPreviewing,
		set = function(value)
			if value then StartPreview() else StopPreview() end
		end,
	},
})
