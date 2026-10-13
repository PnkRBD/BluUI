local _, BUI = ...

local Hook = BUI.Profiler.Hooker('Skin.Menus')

local next = next
local pairs = pairs
local ipairs = ipairs
local wipe = wipe

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin3 = BUILib.Skin
local Skin = BUI.Skinning

local ARROW_TEXTURE = 130940
local WHITE_TEXTURE = 'Interface\\Buttons\\WHITE8X8'
local CHECK_TEXTURE = BUILib.GetLibMedia('check')
local ROUND_TEXTURE = BUILib.GetLibMedia('circle_mask')
local MARK = { box = 14, tick = 12, dot = 6, textGap = 7 }
local MENU_FILL = {}
local LOADOUT_MENU_TAG = 'MENU_CLASS_TALENT_PROFILE'
local BLIZZARD_CHECK = 'UI%-CheckBox%-Check'

local function MenuFill()
	local panel = Skin.PALETTE.panel
	MENU_FILL[1], MENU_FILL[2], MENU_FILL[3], MENU_FILL[4] = panel[1], panel[2], panel[3], 1
	return MENU_FILL
end

local function OnePixel(region)
	return PixelUtil.GetNearestPixelSize(1, region:GetEffectiveScale(), 1)
end

local function Tint(texture, file, color, size)
	texture:SetTexture(file, nil, nil, 'TRILINEAR')
	texture:SetVertexColor(color[1], color[2], color[3], 1)
	if size then texture:SetSize(size, size) end
end

local function PaintSelection(frame, round)
	local box = frame.leftTexture1
	if not (box and Skin.IsSkinEnabled('menus')) then return end
	local shape = round and ROUND_TEXTURE or WHITE_TEXTURE
	Tint(box, shape, Skin.PALETTE.edge, MARK.box)
	box:SetDrawLayer('ARTWORK', 0)
	box:ClearAllPoints()
	box:SetPoint('LEFT')
	local fill = frame:AttachTexture()
	Tint(fill, shape, MenuFill())
	fill:SetDrawLayer('ARTWORK', 1)
	local pixel = OnePixel(box)
	fill:SetPoint('TOPLEFT', box, 'TOPLEFT', pixel, -pixel)
	fill:SetPoint('BOTTOMRIGHT', box, 'BOTTOMRIGHT', -pixel, pixel)
	frame.fontString:SetPoint('LEFT', box, 'RIGHT', MARK.textGap, 0)
	local mark = frame.leftTexture2
	if not mark then return end
	Tint(mark, round and ROUND_TEXTURE or CHECK_TEXTURE, Skin.SELECTED_COLOR, round and MARK.dot or MARK.tick)
	mark:SetDrawLayer('ARTWORK', 2)
	mark:ClearAllPoints()
	mark:SetPoint('CENTER', box, 'CENTER')
end

local function OnCheckbox(_, frame)
	PaintSelection(frame, false)
end

local function OnRadio(_, frame)
	PaintSelection(frame, true)
end

local function RestoreRadio(button)
	if not Skin.IsSkinEnabled('menus') then return end
	local box, fontString = button.leftTexture1, button.fontString
	box:Show()
	if button.leftTexture2 then button.leftTexture2:Show() end
	fontString:SetPoint('LEFT', box, 'RIGHT', MARK.textGap, 0)
	fontString:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGBA())
	for _, region in ipairs({ button:GetRegions() }) do
		if region ~= fontString and region:IsObjectType('FontString') and (region:GetText() or ''):find(BLIZZARD_CHECK) then region:Hide() end
	end
end

local function OnLoadoutMenu(_, rootDescription)
	for _, description in rootDescription:EnumerateElementDescriptions() do
		if description:IsRadio() then description:AddInitializer(RestoreRadio) end
	end
end

local function OnDivider(frame)
	if not Skin.IsSkinEnabled('menus') then return end
	local divider = frame:GetRegions()
	if not divider then return end
	divider:SetAlpha(0)
	local edge = Skin.PALETTE.edge
	local line = frame:AttachTexture()
	line:SetColorTexture(edge[1], edge[2], edge[3], 1)
	line:SetPoint('LEFT', divider, 'LEFT')
	line:SetPoint('RIGHT', divider, 'RIGHT')
	line:SetHeight(OnePixel(line))
end

local menuBackdrops = setmetatable({}, { __mode = 'k' })
local pendingMenus = setmetatable({}, { __mode = 'k' })
local flushScheduled = false

local function ApplySkin(frame)
	if not frame or frame:IsForbidden() then return end
	if not Skin.IsSkinEnabled('menus') then return end
	Skin3.StripTextures(frame)
	frame._buiBackdrop = frame._buiBackdrop or menuBackdrops[frame]
	local backdrop = Skin3.ChildBackdrop(frame, { inside = true })
	menuBackdrops[frame] = backdrop
	local fill, edge = MenuFill(), Skin.PALETTE.edge
	local width, height = backdrop:GetSize()
	if issecretvalue(width) or issecretvalue(height) then
		backdrop:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
		backdrop:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
	else
		Skin.ApplyBackdrop(backdrop, fill, edge)
	end
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
	BUI.Profiler.After('Skin.Menus pending flush', 0, FlushPending)
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

local watchedDescriptions = setmetatable({}, { __mode = 'k' })

local function OnMenuOpen(manager, _, menuDescription)
	local menu = manager.GetOpenMenu and manager:GetOpenMenu()
	if menu then SkinFrame(menu) end
	if menuDescription and menuDescription.AddMenuAcquiredCallback and not watchedDescriptions[menuDescription] then
		watchedDescriptions[menuDescription] = true
		menuDescription:AddMenuAcquiredCallback(SkinFrame)
	end
end

local function Install()
	if not _G.Menu or not _G.Menu.GetManager then return end
	local manager = _G.Menu.GetManager()
	if not manager then return end
	Hook(manager, 'OpenMenu', OnMenuOpen)
	Hook(manager, 'OpenContextMenu', OnMenuOpen)
	_G.Menu.ModifyMenu(LOADOUT_MENU_TAG, OnLoadoutMenu)
	local variants = _G.MenuVariants
	if variants then
		Hook(variants, 'CreateCheckbox', OnCheckbox)
		Hook(variants, 'CreateRadio', OnRadio)
		Hook(variants, 'CreateDivider', OnDivider)
	end
	if _G.CompositorMixin and _G.CompositorMixin.AttachTexture then
		Hook(_G.CompositorMixin, 'AttachTexture', SkinAttachments)
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
