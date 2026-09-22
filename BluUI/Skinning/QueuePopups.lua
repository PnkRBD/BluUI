local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('QueuePopups')

local ipairs, pairs, type = ipairs, pairs, type
local floor = math.floor
local GetTime = GetTime
local C_Timer = C_Timer
local GetBattlefieldPortExpiration = GetBattlefieldPortExpiration

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning

local SKIN_ID = 'queuepopups'
local EVENT_KEY = 'Skin.QueuePopups'
local LFG_PROPOSAL_SECONDS = 40
local COUNTDOWN_PADDING_X = 10
local COUNTDOWN_PADDING_Y = 8

local installed = false
local groups = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeArt = context.Fade, context.FadeRegions, context.FadeArt
local Shell, Button, Close, TextBox = context.Shell, context.Button, context.Close, context.TextBox

local function SkinRoleButton(button)
	Skin.TipRoleButton(context, button)
end

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
	if not Enabled() or type(seconds) ~= 'number' or seconds <= 0 then return end
	group.expiry = GetTime() + seconds
	TickGroup(group)
	group.ticker = BUI.Prof.NewTicker('QueuePopups', 1, group.tick)
end

local function EnsureGroup(name)
	local group = groups[name]
	if group then return group end
	group = { texts = {} }
	group.tick = BUI.Prof.Wrap('tick#QueuePopupCountdown', function() TickGroup(group) end)
	groups[name] = group
	return group
end

local function AddCountdown(name, frame)
	if not frame or frame._buiCountdown then return end
	local group = EnsureGroup(name)
	local text = frame:CreateFontString(nil, 'OVERLAY')
	Skin.TipFont(text, 'body')
	text:SetTextColor(BUILib.Skin.CountdownColor(LFG_PROPOSAL_SECONDS))
	text:SetJustifyH('LEFT')
	text:SetPoint('TOPLEFT', frame, 'TOPLEFT', COUNTDOWN_PADDING_X, -COUNTDOWN_PADDING_Y)
	frame._buiCountdown = text
	group.texts[#group.texts + 1] = text
end

local function OnProposalShow()
	StartGroup(EnsureGroup('lfg'), LFG_PROPOSAL_SECONDS)
end

local function OnProposalEnded()
	local group = groups.lfg
	if group then StopGroup(group) end
end

local function OnPvpReadyShow(dialog)
	local index = dialog.activeIndex
	local seconds = index and GetBattlefieldPortExpiration(index)
	StartGroup(EnsureGroup('pvp'), seconds)
end

local function OnPvpReadyHide()
	local group = groups.pvp
	if group then StopGroup(group) end
end

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function SkinPopup(frame, closeButton, buttons, roleButtons)
	if not frame then return end
	FadeArt(frame.Border)
	FadeRegions(frame)
	Shell(frame)
	Close(closeButton)
	if buttons then
		for _, button in ipairs(buttons) do Button(button) end
	end
	if roleButtons then
		for _, roleButton in ipairs(roleButtons) do SkinRoleButton(roleButton) end
	end
	Skin.TipFaceTree(frame, 1)
end

local function SkinReadyDialog(dialog, closeButton, countdownGroup)
	if not dialog then return end
	FadeArt(dialog.Border)
	Fade(dialog.bottomArt)
	Shell(dialog)
	Close(closeButton)
	Button(dialog.enterButton)
	Button(dialog.leaveButton)
	Skin.TipFaceTree(dialog, 2)
	AddCountdown(countdownGroup, dialog)
end

local function SkinPopups()
	local invitePopup = _G.LFGInvitePopup
	SkinPopup(invitePopup, nil, { _G.LFGInvitePopupAcceptButton, _G.LFGInvitePopupDeclineButton }, invitePopup and invitePopup.RoleButtons)
	SkinPopup(_G.LFDRoleCheckPopup, nil, { _G.LFDRoleCheckPopupAcceptButton, _G.LFDRoleCheckPopupDeclineButton },
		{ _G.LFDRoleCheckPopupRoleButtonTank, _G.LFDRoleCheckPopupRoleButtonHealer, _G.LFDRoleCheckPopupRoleButtonDPS })
	SkinPopup(_G.RolePollPopup, _G.RolePollPopupCloseButton, { _G.RolePollPopupAcceptButton },
		{ _G.RolePollPopupRoleButtonTank, _G.RolePollPopupRoleButtonHealer, _G.RolePollPopupRoleButtonDPS })
	local readyStatus = _G.LFGDungeonReadyStatus
	SkinPopup(readyStatus, _G.LFGDungeonReadyStatusCloseButton)
	AddCountdown('lfg', readyStatus)
	SkinReadyDialog(_G.LFGDungeonReadyDialog, _G.LFGDungeonReadyDialogCloseButton, 'lfg')
	SkinReadyDialog(_G.PVPReadyDialog, _G.PVPReadyDialogCloseButton, 'pvp')
	local brawlStatus = _G.ReadyStatus
	if brawlStatus then SkinPopup(brawlStatus, brawlStatus.CloseButton) end
	local application = _G.LFGListApplicationDialog
	if application then
		SkinPopup(application, nil, { application.SignUpButton, application.CancelButton },
			{ application.TankButton, application.HealerButton, application.DamagerButton })
		TextBox(application.Description)
	end
	local invite = _G.LFGListInviteDialog
	if invite then
		KeepTexture(invite.RoleIcon)
		SkinPopup(invite, nil, { invite.AcceptButton, invite.DeclineButton, invite.AcknowledgeButton })
	end
end


local PREVIEW_SECONDS = 15
local PREVIEW_INSTANCE = 'Preview Dungeon'
local PREVIEW_ROLE = 'DAMAGER'
local PREVIEW_ROLE_COUNTS = { Tank = '1/1', Healer = '1/1', Damager = '3/3' }

local function SetMoverSuspended(frame, isSuspended)
	if frame and BUI.MoveFrames and BUI.MoveFrames.SetSuspended then BUI.MoveFrames.SetSuspended(frame, isSuspended) end
end

local STATUS_LAYOUT_KEYS = { 'LFGDungeonReadyStatusIndividual', 'LFGDungeonReadyStatusRoleless', 'LFGDungeonReadyStatusGrouped' }
local statusLayoutShown = {}

local function RestoreReadyFrames()
	local popup = _G.LFGDungeonReadyPopup
	local dialog, status = _G.LFGDungeonReadyDialog, _G.LFGDungeonReadyStatus
	if not popup then return end
	if dialog then
		dialog:Hide()
		if dialog.instanceInfo then dialog.instanceInfo:EnableMouse(true) end
		dialog:SetParent(popup)
		dialog:ClearAllPoints()
		dialog:SetAllPoints(popup)
		SetMoverSuspended(dialog, false)
	end
	if status then
		status:Hide()
		status:SetParent(popup)
		status:ClearAllPoints()
		status:SetPoint('TOP', popup, 'TOP', 0, 0)
		for _, name in ipairs(STATUS_LAYOUT_KEYS) do
			if _G[name] and statusLayoutShown[name] ~= nil then _G[name]:SetShown(statusLayoutShown[name]) end
		end
		wipe(statusLayoutShown)
		SetMoverSuspended(status, false)
	end
end

local function PreviewReadyDialog(dialog)
	SetMoverSuspended(dialog, true)
	dialog:SetParent(UIParent)
	dialog:ClearAllPoints()
	dialog:SetPoint('CENTER', UIParent, 'CENTER', -170, 100)
	local info = dialog.instanceInfo
	if info then
		info:Show()
		info:EnableMouse(false)
		if info.name then info.name:SetText(PREVIEW_INSTANCE) end
		if info.statusText then info.statusText:SetFormattedText(BOSSES_KILLED or 'Bosses Defeated: %d/%d', 0, 4) end
	end
	if dialog.randomInProgress then dialog.randomInProgress:Hide() end
	local roleIcon = _G.LFGDungeonReadyDialogRoleIconTexture
	if roleIcon and GetIconForRole then
		roleIcon:SetAtlas(GetIconForRole(PREVIEW_ROLE, false), TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
	end
	local roleLabel = _G.LFGDungeonReadyDialogRoleLabel
	if roleLabel then roleLabel:SetText(_G[PREVIEW_ROLE] or 'Damage') end
	dialog:Show()
end

local function PreviewReadyStatus(status)
	SetMoverSuspended(status, true)
	status:SetParent(UIParent)
	status:ClearAllPoints()
	status:SetPoint('CENTER', UIParent, 'CENTER', 170, 100)
	for _, name in ipairs(STATUS_LAYOUT_KEYS) do
		if _G[name] then statusLayoutShown[name] = _G[name]:IsShown() end
	end
	if _G.LFGDungeonReadyStatusIndividual then _G.LFGDungeonReadyStatusIndividual:Hide() end
	if _G.LFGDungeonReadyStatusRoleless then _G.LFGDungeonReadyStatusRoleless:Hide() end
	local grouped = _G.LFGDungeonReadyStatusGrouped
	if grouped then
		grouped:Show()
		for roleKey, countText in pairs(PREVIEW_ROLE_COUNTS) do
			local role = _G['LFGDungeonReadyStatusGrouped' .. roleKey]
			if role then
				if role.count then role.count:SetText(countText) end
				if role.statusIcon then
					role.statusIcon:SetAtlas('UI-LFG-ReadyMark')
					role.statusIcon:Show()
				end
			end
		end
	end
	status:Show()
end

local function PreviewReadyFrames()
	local dialog, status = _G.LFGDungeonReadyDialog, _G.LFGDungeonReadyStatus
	if not dialog or not status then return end
	PreviewReadyDialog(dialog)
	PreviewReadyStatus(status)
	StartGroup(EnsureGroup('lfg'), PREVIEW_SECONDS)
	return dialog, status
end

local function StopPreview()
	OnProposalEnded()
	RestoreReadyFrames()
end

local function Install()
	if installed then return end
	installed = true
	SkinPopups()
	BUI.Events:Register('LFG_PROPOSAL_SHOW', EVENT_KEY, OnProposalShow)
	BUI.Events:Register('LFG_PROPOSAL_DONE', EVENT_KEY, OnProposalEnded)
	BUI.Events:Register('LFG_PROPOSAL_FAILED', EVENT_KEY, OnProposalEnded)
	BUI.Events:Register('LFG_PROPOSAL_SUCCEEDED', EVENT_KEY, OnProposalEnded)
	local pvpReady = _G.PVPReadyDialog
	if pvpReady then
		HookScript(pvpReady, 'OnShow', OnPvpReadyShow)
		HookScript(pvpReady, 'OnHide', OnPvpReadyHide)
	end
end

local function Deactivate()
	for _, group in pairs(groups) do StopGroup(group) end
	context.Restore()
	BUI.Print('Queue Popups skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		SkinPopups()
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Queue Popups',
	description = 'Dungeon, raid and PvP ready dialogs, role checks and queue invites, with a countdown until the queue expires.',
	icon = 'Interface/Icons/INV_Misc_PocketWatch_01',
	test = PreviewReadyFrames,
	stopTest = StopPreview,
})
