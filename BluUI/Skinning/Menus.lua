local _, BUI = ...

local next = next
local pairs = pairs
local wipe = wipe

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local theme = BUILib.Theme
local Skin3 = BUILib.Skin
local Skin = BUI.Skinning

local ARROW_TEXTURE = 130940
local MENU_BG = { 0.06, 0.06, 0.06, 0.95 }
local SEPARATOR_COLOR = theme.border.default

local function SkinRow(button)
	if button and button.divider then
		button.divider:SetColorTexture(SEPARATOR_COLOR[1], SEPARATOR_COLOR[2], SEPARATOR_COLOR[3], SEPARATOR_COLOR[4] or 1)
		button.divider:SetHeight(1)
	end
end

local function SkinTree(frame, depth)
	if depth > 8 or not frame.GetChildren then return end
	local children = { frame:GetChildren() }
	for childIndex = 1, #children do
		SkinRow(children[childIndex])
		SkinTree(children[childIndex], depth + 1)
	end
end

local menuBackdrops = setmetatable({}, { __mode = 'k' })
local pendingMenus = setmetatable({}, { __mode = 'k' })
local flushScheduled = false

local function ApplySkin(frame)
	if not frame or frame:IsForbidden() then return end
	if not Skin.IsSkinEnabled('menus') then return end
	Skin3.StripTextures(frame)
	menuBackdrops[frame] = Skin3.ChildBackdrop(frame, { bg = MENU_BG, border = theme.border.light })
	SkinTree(frame, 0)
end

local function FlushPending()
	flushScheduled = false
	for frame in pairs(pendingMenus) do
		pendingMenus[frame] = nil
		ApplySkin(frame)
	end
end

local function SkinFrame(frame)
	if not frame or frame:IsForbidden() then return end
	if not Skin.IsSkinEnabled('menus') then return end
	ApplySkin(frame)
	pendingMenus[frame] = true
	if flushScheduled then return end
	flushScheduled = true
	C_Timer.After(0, FlushPending)
end

local function SkinAttachments(compositor)
	if not Skin.IsSkinEnabled('menus') then return end
	local attachments = compositor.attachments
	if not attachments then return end
	for _, widget in next, attachments do
		if widget.IsObjectType and widget:IsObjectType('Texture') and widget:GetTexture() == ARROW_TEXTURE then
			widget:SetVertexColor(1, 1, 1)
		end
	end
end

local function OnMenuOpen(manager, _, menuDescription)
	local menu = manager.GetOpenMenu and manager:GetOpenMenu()
	if menu then SkinFrame(menu) end
	if menuDescription and menuDescription.AddMenuAcquiredCallback then
		menuDescription:AddMenuAcquiredCallback(SkinFrame)
	end
end

local function Install()
	if not _G.Menu or not _G.Menu.GetManager then return end
	local manager = _G.Menu.GetManager()
	if not manager then return end
	hooksecurefunc(manager, 'OpenMenu', OnMenuOpen)
	hooksecurefunc(manager, 'OpenContextMenu', OnMenuOpen)
	if _G.CompositorMixin and _G.CompositorMixin.AttachTexture then
		hooksecurefunc(_G.CompositorMixin, 'AttachTexture', SkinAttachments)
	end
end

BUI.Events:OnLogin('Skinning.Menus', Install)

Skin.OnToggle('menus', function(enabled)
	if enabled then return end
	for frame, backdrop in pairs(menuBackdrops) do
		backdrop:Hide()
		menuBackdrops[frame] = nil
	end
	wipe(pendingMenus)
end)

Skin.RegisterSkin('menus', {
	name = 'Context Menus',
	description = 'Dark theme for right-click and dropdown menus.',
	icon = 'Interface\\Icons\\INV_Misc_Note_01',
})
