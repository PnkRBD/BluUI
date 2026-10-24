local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local BN_TOAST_TYPE_NEW_INVITE = 5
local TEXT_KEYS = { 'TopLine', 'MiddleLine', 'BottomLine', 'DoubleLine', 'Text' }

local previewing = false

local function IsPreviewing()
	return previewing and _G.BNToastFrame:IsShown()
end

local function StartPreview()
	if InCombatLockdown() then return end
	local toast = _G.BNToastFrame
	previewing = true
	toast:AddToast(BN_TOAST_TYPE_NEW_INVITE)
	C_Timer.After(0.05, function()
		if previewing and toast:IsShown() then AlertFrame_PauseOutAnimation(toast) end
	end)
end

local function StopPreview()
	previewing = false
	local toast = _G.BNToastFrame
	if toast:IsShown() then AlertFrame_PlayOutAnimation(toast, 0) end
end

local context = Skin.Define('bnetToast', {
	name = 'Battle.net Toasts',
	description = 'The small pop-up when a Battle.net friend comes online, goes offline, broadcasts or sends an invite: dark shell, framed portrait, library font, flat close button.',
	icon = 'Interface/FriendsFrame/Battlenet-Battleneticon',
	unlock = {
		tooltip = 'Show a test toast held on screen so you can drag it where you want. Click again to dismiss it.',
		get = IsPreviewing,
		set = function(value)
			if value then StartPreview() else StopPreview() end
		end,
	},
})
local Fade, FadeRegions, Shell, Close, Body = context.Fade, context.FadeRegions, context.Shell, context.Close, context.Body

local function SkinToast(frame)
	if frame.backdropInfo then
		frame._buiBackdrop = frame.backdropInfo
		frame:SetBackdrop(nil)
	end
	Fade(_G[frame:GetName() .. 'GlowFrame'])
	Shell(frame)
	Close(frame.CloseButton)
	for _, key in ipairs(TEXT_KEYS) do Body(frame[key]) end
	local icon = frame.IconTexture
	if icon then
		if icon._buiIconFrame then
			Skin.SetIconEdgeThickness(icon, 1)
		else
			Skin.TipIconFrame(frame, icon)
		end
	end
	local tooltip = frame.TooltipFrame
	if tooltip then
		FadeRegions(tooltip)
		Fade(tooltip.NineSlice)
		Shell(tooltip)
		Body(tooltip.Text)
	end
end

context.Window('BNToastFrame', { skin = SkinToast })

context.OnDisable(function()
	local frame = _G.BNToastFrame
	if frame._buiBackdrop then
		frame:SetBackdrop(frame._buiBackdrop)
		frame._buiBackdrop = nil
	end
	Skin.SetIconEdgeThickness(frame.IconTexture, 0)
end)
