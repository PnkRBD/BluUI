local _, BUI = ...

local Hook = BUI.Profiler.Hooker('Skin.GroupLoot')

local ipairs = ipairs

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Skin = BUI.Skinning
local Tools = BUI.Tools
local Layout = BUILib.Layout

local SKIN_ID = 'grouploot'
local ANCHOR_KEY = 'lootrolls'
local GROW_DOWN_SETTING = 'grouplootGrowDown'
local ROLL_WIDTH, ROLL_HEIGHT = 300, 48
local ROLL_GAP = 1
local ROLL_STEP = ROLL_HEIGHT + ROLL_GAP
local ROLL_INSET = 8
local CONTENT_LIFT = 2
local ICON_SIZE = 32
local BUTTON_SIZE = 26
local BUTTON_GAP = 4
local TEXT_GAP = 8
local TIMER_HEIGHT = 3
local EXAMPLES = {
	{ name = 'Example Epic Sword', icon = 'Interface/Icons/INV_Sword_04', quality = 4, need = true, timeLeft = 0.8 },
	{ name = 'Example Rare Helm', icon = 'Interface/Icons/INV_Helmet_25', quality = 3, need = true, transmog = true, timeLeft = 0.55 },
	{ name = 'Example Rare Trinket', icon = 'Interface/Icons/INV_Misc_Gem_01', quality = 3, need = false, timeLeft = 0.3 },
}

local installed = false
local skinned = {}
local rollFrames = {}

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

local function RaiseTimer(frame)
	if Enabled() then frame.Timer:SetFrameLevel(frame:GetFrameLevel() + 1) end
end

local function LayoutFrame(frame)
	frame:SetSize(ROLL_WIDTH, ROLL_HEIGHT)
	local iconFrame = frame.IconFrame
	iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
	iconFrame:ClearAllPoints()
	iconFrame:SetPoint('LEFT', frame, 'LEFT', ROLL_INSET, CONTENT_LIFT)
	iconFrame.Icon:SetAllPoints(iconFrame)
	for _, button in ipairs(frame.LootButtons) do button:SetSize(BUTTON_SIZE, BUTTON_SIZE) end
	local pass, greed, need = frame.PassButton, frame.GreedButton, frame.NeedButton
	pass:ClearAllPoints()
	pass:SetPoint('RIGHT', frame, 'RIGHT', -ROLL_INSET, CONTENT_LIFT)
	greed:ClearAllPoints()
	greed:SetPoint('RIGHT', pass, 'LEFT', -BUTTON_GAP, 0)
	need:ClearAllPoints()
	need:SetPoint('RIGHT', greed, 'LEFT', -BUTTON_GAP, 0)
	local name = frame.Name
	name:ClearAllPoints()
	name:SetPoint('LEFT', iconFrame, 'RIGHT', TEXT_GAP, 0)
	name:SetPoint('RIGHT', need, 'LEFT', -TEXT_GAP, 0)
	name:SetWordWrap(false)
	local timer = frame.Timer
	timer:ClearAllPoints()
	timer:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 1, 1)
	timer:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -1, 1)
	timer:SetHeight(TIMER_HEIGHT)
end

local function SkinFrame(frame)
	local iconFrame, timer = frame.IconFrame, frame.Timer
	Fade(frame.Background)
	Fade(frame.Border)
	Fade(iconFrame.Border)
	LayoutFrame(frame)
	context.Shell(frame)
	Skin.TipFace(frame.Name, 'body')
	Skin.CropIcon(iconFrame.Icon)
	Skin.TipIconFrame(iconFrame, iconFrame.Icon)
	timer:SetStatusBarTexture(BUI.GetGlobalTexture())
	Tools.SetColorTex(timer.Background, 0, 0, 0, 0.5)
	frame:HookScript('OnShow', BUI.Profiler.Wrap('Skin.GroupLoot frame OnShow', RaiseTimer))
	RaiseTimer(frame)
end

local function SkinAll()
	if not Enabled() then return end
	local red, green, blue = BUILib.Theme.GetAccent()
	for _, frame in pairs(_G.GroupLootContainer.rollFrames) do
		if rollFrames[frame] then
			if not skinned[frame] then
				skinned[frame] = true
				SkinFrame(frame)
			end
			local color = QualityColor(frame)
			if color then
				Skin.SetIconEdgeColor(frame.IconFrame.Icon, color.r, color.g, color.b)
			else
				Skin.SetIconEdgeColor(frame.IconFrame.Icon, 0, 0, 0)
			end
			frame.Timer:SetStatusBarColor(red, green, blue, 1)
		end
	end
end

local Resweep = BUI.Dispatcher.New(SkinAll, 'Skin.GroupLoot')

local function SetRollButton(button, enabled)
	if enabled then
		GroupLootFrame_EnableLootButton(button)
	else
		GroupLootFrame_DisableLootButton(button)
	end
end

local function BuildExample(parent, spec)
	local frame = CreateFrame('Frame', nil, parent, 'GroupLootFrameTemplate')
	frame:SetParent(parent)
	EventRegistry:UnregisterFrameEventAndCallback('OPEN_MASTER_LOOT_LIST', frame)
	frame:UnregisterAllEvents()
	for _, script in ipairs({ 'OnShow', 'OnHide', 'OnEvent', 'OnUpdate' }) do frame:SetScript(script, nil) end
	frame.IconFrame:EnableMouse(false)
	for _, button in ipairs(frame.LootButtons) do button:EnableMouse(false) end
	SkinFrame(frame)
	local color = ITEM_QUALITY_COLORS[spec.quality]
	frame.IconFrame.Icon:SetTexture(spec.icon)
	Skin.SetIconEdgeColor(frame.IconFrame.Icon, color.r, color.g, color.b)
	frame.Name:SetText(spec.name)
	frame.Name:SetVertexColor(color.r, color.g, color.b)
	SetRollButton(frame.NeedButton, spec.need)
	frame.TransmogButton:SetShown(spec.transmog == true)
	frame.GreedButton:SetShown(not spec.transmog)
	local red, green, blue = BUILib.Theme.GetAccent()
	frame.Timer:SetStatusBarColor(red, green, blue, 1)
	frame.Timer:SetMinMaxValues(0, 1)
	frame.Timer:SetValue(spec.timeLeft)
	frame:Show()
	return frame
end

local function BuildExampleStack(anchor)
	local holder = CreateFrame('Frame', nil, anchor)
	holder:SetSize(ROLL_WIDTH, #EXAMPLES * ROLL_STEP - ROLL_GAP)
	for index, spec in ipairs(EXAMPLES) do
		local frame = BuildExample(holder, spec)
		frame:ClearAllPoints()
		frame:SetPoint('TOP', holder, 'TOP', 0, -(index - 1) * ROLL_STEP)
	end
	return holder
end

local function StackRolls(container, point)
	local direction = point == 'TOP' and -1 or 1
	local offset = 0
	for index = 1, container.maxIndex do
		local frame = container.rollFrames[index]
		local size = (Enabled() and (not frame or rollFrames[frame])) and ROLL_STEP or container.reservedSize
		if frame then
			frame:ClearAllPoints()
			frame:SetPoint('CENTER', container, point, 0, direction * (offset + size / 2))
		end
		offset = offset + size
	end
end

local function Restack(container)
	if not Enabled() or Skin.ToastAnchors.IsPositioned(ANCHOR_KEY) then return end
	StackRolls(container, 'BOTTOM')
end

local function Install()
	if installed then return end
	installed = true
	local index = 1
	while _G['GroupLootFrame' .. index] do
		rollFrames[_G['GroupLootFrame' .. index]] = true
		index = index + 1
	end
	Hook('GroupLootContainer_Update', Resweep)
	Hook('GroupLootContainer_Update', Restack)
end

local function Deactivate()
	context.Restore()
	wipe(skinned)
	BUI.Print('Loot Rolls skin disabled. /reload for a full visual reset.')
end

local function AnchorHooks(reapply)
	Hook('GroupLootContainer_Update', reapply)
	Hook(AlertFrame, 'UpdateAnchors', reapply)
end

local function GrowPoint()
	return BUI.GetDB().skinning[GROW_DOWN_SETTING] and 'TOP' or 'BOTTOM'
end

local function PlaceRolls(container, anchor)
	local point = GrowPoint()
	container:ClearAllPoints()
	container:SetPoint(point, anchor, point, 0, 0)
	StackRolls(container, point)
end

Skin.ToastAnchors.Register({
	key = ANCHOR_KEY,
	label = 'LOOT ROLLS',
	point = GrowPoint,
	sample = BuildExampleStack,
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
			Skin.ToastAnchors.Refresh(ANCHOR_KEY)
		end)
	end,
	unlock = {
		tooltip = 'Unlock position. Drag the roll popup window, then click again to lock.',
		get = function() return Skin.ToastAnchors.IsUnlocked(ANCHOR_KEY) end,
		set = function(value) Skin.ToastAnchors.SetUnlocked(ANCHOR_KEY, value) end,
	},
})
