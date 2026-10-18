local _, BUI = ...

local ipairs = ipairs
local floor = math.floor
local GetTime = GetTime
local C_Timer = C_Timer
local GetBattlefieldPortExpiration = GetBattlefieldPortExpiration

local BUILib = BluUI.BUILibClient
local Skin = BUI.Skinning

local EVENT_KEY = 'Skin.QueuePopups'
local LFG_PROPOSAL_SECONDS = 40
local COUNTDOWN_PADDING_X = 10
local COUNTDOWN_PADDING_Y = 8

local context = Skin.Define('queuepopups', {
	name = 'Queue Popups',
	description = 'Dungeon, raid and PvP ready dialogs, role checks and queue invites, with a countdown until the queue expires.',
	icon = 'Interface/Icons/INV_Misc_PocketWatch_01',
})
local Fade, FadeRegions, FadeArt = context.Fade, context.FadeRegions, context.FadeArt
local Shell, Button, Close, TextBox, Guard = context.Shell, context.Button, context.Close, context.TextBox, context.Guard

local function StopGroup(group)
	if group.ticker then
		group.ticker:Cancel()
		group.ticker = nil
	end
	group.expiry = nil
	for _, text in ipairs(group.texts) do text:SetText('') end
end

local function TickGroup(group)
	if not group.expiry then return end
	local remaining = group.expiry - GetTime()
	if remaining <= 0 then
		StopGroup(group)
		return
	end
	local seconds = floor(remaining + 0.5)
	for _, text in ipairs(group.texts) do BUILib.Skin.SetCountdownText(text, seconds) end
end

local function StartGroup(group, seconds)
	StopGroup(group)
	if not seconds or seconds <= 0 then return end
	group.expiry = GetTime() + seconds
	TickGroup(group)
	group.ticker = C_Timer.NewTicker(1, BUI.Profiler.Timed('Skinning.QueuePopups StartGroup ticker', group.tick))
end

local function NewGroup()
	local group = { texts = {} }
	group.tick = BUI.Profiler.Wrap('Skin.QueuePopups countdown tick', function() TickGroup(group) end)
	return group
end

local lfgGroup, pvpGroup = NewGroup(), NewGroup()

local function AddCountdown(group, frame)
	if frame._buiCountdown then return end
	local text = frame:CreateFontString(nil, 'OVERLAY')
	Skin.TipFont(text, 'body')
	text:SetTextColor(BUILib.Skin.CountdownColor(LFG_PROPOSAL_SECONDS))
	text:SetJustifyH('LEFT')
	text:SetPoint('TOPLEFT', frame, 'TOPLEFT', COUNTDOWN_PADDING_X, -COUNTDOWN_PADDING_Y)
	frame._buiCountdown = text
	group.texts[#group.texts + 1] = text
	if group.expiry then TickGroup(group) end
end

local function OnProposalShow()
	StartGroup(lfgGroup, LFG_PROPOSAL_SECONDS)
end

local function OnProposalEnded()
	StopGroup(lfgGroup)
end

local function OnPvpReadyShow(dialog)
	local index = dialog.activeIndex
	StartGroup(pvpGroup, index and GetBattlefieldPortExpiration(index))
end

local function OnPvpReadyHide()
	StopGroup(pvpGroup)
end

local function SkinPopup(frame, closeButton, buttons, roleButtons)
	FadeArt(frame.Border)
	FadeRegions(frame)
	Shell(frame)
	Close(closeButton)
	if buttons then
		for _, button in ipairs(buttons) do Button(button) end
	end
	if roleButtons then
		for _, roleButton in ipairs(roleButtons) do Skin.TipRoleButton(context, roleButton) end
	end
	Skin.TipFaceTree(frame, 1)
end

local function SkinReadyDialog(dialog, closeButton, group)
	FadeArt(dialog.Border)
	Fade(dialog.bottomArt)
	Shell(dialog)
	Close(closeButton)
	Button(dialog.enterButton)
	Button(dialog.leaveButton)
	Skin.TipFaceTree(dialog, 2)
	AddCountdown(group, dialog)
end

local function SkinInvitePopup(popup)
	SkinPopup(popup, nil, { _G.LFGInvitePopupAcceptButton, _G.LFGInvitePopupDeclineButton }, popup.RoleButtons)
end

local function SkinRoleCheck(popup)
	SkinPopup(popup, nil, { _G.LFDRoleCheckPopupAcceptButton, _G.LFDRoleCheckPopupDeclineButton },
		{ _G.LFDRoleCheckPopupRoleButtonTank, _G.LFDRoleCheckPopupRoleButtonHealer, _G.LFDRoleCheckPopupRoleButtonDPS })
end

local function SkinRolePoll(popup)
	SkinPopup(popup, _G.RolePollPopupCloseButton, { _G.RolePollPopupAcceptButton },
		{ _G.RolePollPopupRoleButtonTank, _G.RolePollPopupRoleButtonHealer, _G.RolePollPopupRoleButtonDPS })
end

local function SkinReadyStatus(status)
	SkinPopup(status, _G.LFGDungeonReadyStatusCloseButton)
	AddCountdown(lfgGroup, status)
end

local function SkinDungeonReady(dialog)
	SkinReadyDialog(dialog, _G.LFGDungeonReadyDialogCloseButton, lfgGroup)
end

local function SkinPvpReady(dialog)
	SkinReadyDialog(dialog, _G.PVPReadyDialogCloseButton, pvpGroup)
end

local function SkinBrawlStatus(status)
	SkinPopup(status, status.CloseButton)
end

local function SkinApplication(dialog)
	SkinPopup(dialog, nil, { dialog.SignUpButton, dialog.CancelButton }, { dialog.TankButton, dialog.HealerButton, dialog.DamagerButton })
	TextBox(dialog.Description)
end

local function SkinListInvite(dialog)
	dialog.RoleIcon.__buiSkin = true
	SkinPopup(dialog, nil, { dialog.AcceptButton, dialog.DeclineButton, dialog.AcknowledgeButton })
end

local function InstallProposal()
	BUI.Events:Register('LFG_PROPOSAL_SHOW', EVENT_KEY, Guard(OnProposalShow))
	BUI.Events:Register('LFG_PROPOSAL_DONE', EVENT_KEY, OnProposalEnded)
	BUI.Events:Register('LFG_PROPOSAL_FAILED', EVENT_KEY, OnProposalEnded)
	BUI.Events:Register('LFG_PROPOSAL_SUCCEEDED', EVENT_KEY, OnProposalEnded)
end

local function InstallPvpReady(dialog)
	dialog:HookScript('OnHide', BUI.Profiler.Wrap('Skin.QueuePopups pvp stop', OnPvpReadyHide))
end

context.Window('LFGInvitePopup', { skin = SkinInvitePopup })
context.Window('LFDRoleCheckPopup', { skin = SkinRoleCheck })
context.Window('RolePollPopup', { skin = SkinRolePoll })
context.Window('LFGDungeonReadyStatus', { skin = SkinReadyStatus })
context.Window('LFGDungeonReadyDialog', { skin = SkinDungeonReady, install = InstallProposal })
context.Window('PVPReadyDialog', { skin = SkinPvpReady, show = OnPvpReadyShow, install = InstallPvpReady })
context.Window('ReadyStatus', { skin = SkinBrawlStatus })
context.Window('LFGListApplicationDialog', { skin = SkinApplication })
context.Window('LFGListInviteDialog', { skin = SkinListInvite })

context.OnDisable(function()
	StopGroup(lfgGroup)
	StopGroup(pvpGroup)
end)
