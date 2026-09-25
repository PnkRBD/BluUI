local _, BUI = ...

local select, type = select, type

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Tools = BUI.Tools
local Layout = BUILib.Layout

local SKIN_ID = 'grouploot'
local GROW_DOWN_SETTING = 'grouplootGrowDown'
local FRAME_COUNT = 4
local ART_KEYS = { 'Border', 'BorderFrame', 'Background', 'Bg', 'Decoration', 'Corner', 'SlotTexture', 'NameFrame', 'Backdrop' }
local ICON_ART_KEYS = { 'IconBorder', 'Border', 'IconQuestTexture' }

local installed = false
local fadedArt = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local function FadeTextures(frame, keep)
	if not frame or not frame.GetRegions then return end
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region and region ~= keep and region.IsObjectType and region:IsObjectType('Texture') and not region.__buiSkin then
			fadedArt[region] = true
			region:SetAlpha(0)
		end
	end
end

local function FadeKeys(frame, keys)
	for keyIndex = 1, #keys do
		local child = frame[keys[keyIndex]]
		if child and child.IsObjectType then
			if child:IsObjectType('Texture') then
				fadedArt[child] = true
				child:SetAlpha(0)
			else
				FadeTextures(child)
			end
		end
	end
end

local function QualityColor(frame)
	local rollID = frame.rollID
	if type(rollID) ~= 'number' or not GetLootRollItemInfo then return nil end
	local _, _, _, quality = GetLootRollItemInfo(rollID)
	if type(quality) ~= 'number' or issecretvalue(quality) or quality < 2 then return nil end
	return ITEM_QUALITY_COLORS[quality]
end

local function SkinIcon(frame, color)
	local host = frame.IconFrame or frame.Item
	if not host then return end
	local icon = host.Icon or host.icon
	if not icon then return end
	if not host._buiIconSkinned then
		host._buiIconSkinned = true
		FadeKeys(host, ICON_ART_KEYS)
		local normal = host.GetNormalTexture and host:GetNormalTexture()
		if normal then normal:SetAlpha(0) end
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local border = host:CreateTexture(nil, 'BACKGROUND', nil, -1)
		border.__buiSkin = true
		border:SetPoint('TOPLEFT', icon, 'TOPLEFT', -1, 1)
		border:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', 1, -1)
		host._buiIconBorder = border
	end
	if color then
		Tools.SetColorTex(host._buiIconBorder, color.r, color.g, color.b, 1)
	else
		Tools.SetColorTex(host._buiIconBorder, 0, 0, 0, 1)
	end
end

local function SkinTimer(frame)
	local bar = frame.Timer
	if not bar or not bar.SetStatusBarTexture then return end
	if not bar._buiSkinned then
		bar._buiSkinned = true
		FadeTextures(bar, bar:GetStatusBarTexture())
		bar:SetStatusBarTexture(BUI.GetGlobalTexture())
		local background = bar:CreateTexture(nil, 'BACKGROUND')
		background.__buiSkin = true
		background:SetAllPoints(bar)
		Tools.SetColorTex(background, 0, 0, 0, 0.5)
	end
	local red, green, blue = BUILib.Theme.GetAccent()
	bar:SetStatusBarColor(red, green, blue, 1)
end

local function SkinRollFrame(frame)
	if not frame or frame:IsForbidden() or not Enabled() then return end
	if not frame._buiGroupLoot then
		frame._buiGroupLoot = true
		FadeTextures(frame)
		FadeKeys(frame, ART_KEYS)
		if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
	end
	Skin.TipShell(frame)
	Skin.TipFace(frame.Name, 'body')
	SkinIcon(frame, QualityColor(frame))
	SkinTimer(frame)
end

local function SkinAll()
	for frameIndex = 1, FRAME_COUNT do
		SkinRollFrame(_G['GroupLootFrame' .. frameIndex])
	end
	local container = _G.GroupLootContainer
	if container and type(container.rollFrames) == 'table' then
		for _, frame in pairs(container.rollFrames) do SkinRollFrame(frame) end
	end
end

local Resweep = BUI.Dispatcher.New(SkinAll, 'Skin.GroupLoot')

local function Install()
	if installed then return end
	installed = true
	if _G.GroupLootContainer_AddFrame then hooksecurefunc('GroupLootContainer_AddFrame', Resweep) end
	if _G.GroupLootContainer_Update then hooksecurefunc('GroupLootContainer_Update', Resweep) end
	local container = _G.GroupLootContainer
	if container then container:HookScript('OnShow', Resweep) end
	BUI.Events:Register('START_LOOT_ROLL', 'Skin.GroupLoot', Resweep)
	Resweep()
end

local function Deactivate()
	for region in pairs(fadedArt) do region:SetAlpha(1) end
	for frameIndex = 1, FRAME_COUNT do
		local frame = _G['GroupLootFrame' .. frameIndex]
		if frame and frame._buiGroupLoot then
			if frame.NineSlice then frame.NineSlice:SetAlpha(1) end
			Skin.HideTipShell(frame)
		end
	end
	BUI.Print('Loot Rolls skin disabled. /reload for a full visual reset.')
end

local function AnchorHooks(reapply)
	if _G.UIParent_ManageFramePositions then hooksecurefunc('UIParent_ManageFramePositions', reapply) end
	if _G.GroupLootContainer_Update then hooksecurefunc('GroupLootContainer_Update', reapply) end
	local alertFrame = _G.AlertFrame
	if alertFrame and alertFrame.UpdateAnchors then hooksecurefunc(alertFrame, 'UpdateAnchors', reapply) end
end

local function GrowPoint()
	return BUI.GetDB().skinning[GROW_DOWN_SETTING] and 'TOP' or 'BOTTOM'
end

local function PlaceRolls(container, anchor)
	local point = GrowPoint()
	local step = point == 'TOP' and -container.reservedSize or container.reservedSize
	container:ClearAllPoints()
	container:SetPoint(point, anchor, point, 0, 0)
	for index = 1, container.maxIndex do
		local frame = container.rollFrames[index]
		if frame then
			frame:ClearAllPoints()
			frame:SetPoint('CENTER', container, point, 0, step * (index - 0.5))
		end
	end
end

Skin.ToastAnchors.Register({
	key = 'lootrolls',
	label = 'LOOT ROLLS',
	point = GrowPoint,
	sample = 'roll',
	followFrame = true,
	defaultY = 260,
	frame = function() return _G.GroupLootContainer end,
	apply = PlaceRolls,
	hooks = AnchorHooks,
})

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		Resweep()
	else
		Deactivate()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Loot Rolls',
	description = 'Need, greed and pass roll popups drawn like the BluUI tooltip, with a quality border on the item.',
	icon = 'Interface/Buttons/UI-GroupLoot-Dice-Up',
	buildSettings = function(content)
		local skinDB = BUI.GetDB().skinning
		local panel = Layout.SettingsCard(content, { title = 'Layout' })
		Layout.Toggle(panel, {
			label = 'Grow downwards',
			tooltip = 'Stack new rolls below the first one. Takes effect once the roll window has been moved with the unlock eye.',
		}, skinDB[GROW_DOWN_SETTING], function(value)
			skinDB[GROW_DOWN_SETTING] = value
			Skin.ToastAnchors.Refresh('lootrolls')
		end)
	end,
	unlock = {
		tooltip = 'Unlock position. Drag the roll popup window, then click again to lock.',
		get = function() return Skin.ToastAnchors.IsUnlocked('lootrolls') end,
		set = function(value) Skin.ToastAnchors.SetUnlocked('lootrolls', value) end,
	},
})
