local _, BUI = ...
local HookScript = select(2, BUI.Prof.Scripts('InstanceAbandon'))

local Skin = BUI.Skinning

local SKIN_ID = 'instanceabandon'
local NAME_HINTS = { 'Abandon', 'InstanceLeaver', 'Leaver', 'LeaveInstance', 'InstanceVote' }
local NAME_SKIP = { 'AbandonHouse', 'AbandonQuest', 'StaticPopup' }
local CHROME_KEYS = { 'NineSlice', 'Border', 'Background', 'Bg', 'Backdrop' }
local FONT_DEPTH = 4
local BUTTON_DEPTH = 3

local dialog
local skinnedFrames = {}

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local FadeRegions, FadeKeys = context.FadeRegions, context.FadeKeys
local Shell, Button = context.Shell, context.Button

local function Wanted(name)
	if not name or BUI.Tools.IsSecretValue(name) then return false end
	for index = 1, #NAME_SKIP do
		if name:find(NAME_SKIP[index], 1, true) then return false end
	end
	for index = 1, #NAME_HINTS do
		if name:find(NAME_HINTS[index], 1, true) then return true end
	end
	return false
end

local function Locate()
	if dialog then return dialog end
	local frame = EnumerateFrames()
	local IsSecretValue = BUI.Tools.IsSecretValue
	while frame do
		if not frame:IsForbidden() then
			local shown = frame:IsShown()
			if not IsSecretValue(shown) and shown and Wanted(frame:GetName()) then
				dialog = frame
				return frame
			end
		end
		frame = EnumerateFrames(frame)
	end
	return nil
end

local function SkinButtons(frame, depth)
	if depth <= 0 or not frame.GetChildren then return end
	local children = { frame:GetChildren() }
	for index = 1, #children do
		local child = children[index]
		if child and not child:IsForbidden() then
			if child.IsObjectType and child:IsObjectType('Button') and child.GetText and child:GetText() then
				Button(child)
			end
			SkinButtons(child, depth - 1)
		end
	end
end

local function SkinDialog(frame)
	if not frame or frame._buiAbandon or frame:IsForbidden() then return end
	frame._buiAbandon = true
	skinnedFrames[#skinnedFrames + 1] = frame

	FadeRegions(frame)
	FadeKeys(frame, CHROME_KEYS)
	Shell(frame)
	SkinButtons(frame, BUTTON_DEPTH)
	Skin.TipFaceTree(frame, FONT_DEPTH)
	HookScript(frame, 'OnShow', function(self)
		if not Enabled() then return end
		Skin.TipFaceTree(self, FONT_DEPTH)
	end)
end

local function Apply()
	if not Enabled() then return end
	local frame = Locate()
	if not frame then return end
	SkinDialog(frame)
end

local function ApplySoon()
	Apply()
	if dialog then return end
	BUI.Prof.After('Skin.InstanceAbandon', 0, Apply)
end

Skin.OnToggle(SKIN_ID, function(enabled)
	context.Restore()
	if enabled then
		for index = 1, #skinnedFrames do skinnedFrames[index]._buiAbandon = nil end
		Apply()
	end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Abandon Instance Vote',
	description = 'The group vote prompt for leaving a dungeon or delve, with the metal frame stripped off and the buttons in the dark shell.',
	icon = 'Interface/Icons/INV_Misc_Key_03',
})

BUI.Events:Register('INSTANCE_ABANDON_VOTE_STARTED', 'Skin.InstanceAbandon', ApplySoon)
BUI.Events:Register('INSTANCE_ABANDON_VOTE_UPDATED', 'Skin.InstanceAbandon', ApplySoon)
