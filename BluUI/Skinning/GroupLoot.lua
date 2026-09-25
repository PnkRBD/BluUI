local _, BUI = ...

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Tools = BUI.Tools
local Layout = BUILib.Layout

local SKIN_ID = 'grouploot'
local GROW_DOWN_SETTING = 'grouplootGrowDown'

local installed = false
local skinned = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade = context.Fade

local function QualityColor(frame)
	local _, _, _, quality = GetLootRollItemInfo(frame.rollID)
	if not quality or issecretvalue(quality) or quality < 2 then return nil end
	return ITEM_QUALITY_COLORS[quality]
end

local function SkinFrame(frame)
	local iconFrame, timer = frame.IconFrame, frame.Timer
	Fade(frame.Background)
	Fade(frame.Border)
	Fade(iconFrame.Border)
	context.Shell(frame)
	Skin.TipFace(frame.Name, 'body')
	if not iconFrame._buiIconBorder then
		Skin.CropIcon(iconFrame.Icon)
		local border = iconFrame:CreateTexture(nil, 'BACKGROUND', nil, -1)
		border:SetPoint('TOPLEFT', iconFrame.Icon, 'TOPLEFT', -1, 1)
		border:SetPoint('BOTTOMRIGHT', iconFrame.Icon, 'BOTTOMRIGHT', 1, -1)
		iconFrame._buiIconBorder = border
	end
	timer:SetStatusBarTexture(BUI.GetGlobalTexture())
	Tools.SetColorTex(timer.Background, 0, 0, 0, 0.5)
end

local function SkinAll()
	if not Enabled() then return end
	local red, green, blue = BUILib.Theme.GetAccent()
	for _, frame in pairs(_G.GroupLootContainer.rollFrames) do
		if not skinned[frame] then
			skinned[frame] = true
			SkinFrame(frame)
		end
		local color = QualityColor(frame)
		if color then
			Tools.SetColorTex(frame.IconFrame._buiIconBorder, color.r, color.g, color.b, 1)
		else
			Tools.SetColorTex(frame.IconFrame._buiIconBorder, 0, 0, 0, 1)
		end
		frame.Timer:SetStatusBarColor(red, green, blue, 1)
	end
end

local Resweep = BUI.Dispatcher.New(SkinAll, 'Skin.GroupLoot')

local function Install()
	if installed then return end
	installed = true
	hooksecurefunc('GroupLootContainer_Update', Resweep)
end

local function Deactivate()
	context.Restore()
	wipe(skinned)
	BUI.Print('Loot Rolls skin disabled. /reload for a full visual reset.')
end

local function AnchorHooks(reapply)
	hooksecurefunc('GroupLootContainer_Update', reapply)
	hooksecurefunc(AlertFrame, 'UpdateAnchors', reapply)
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
