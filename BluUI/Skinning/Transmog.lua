local _, BUI = ...

local ipairs = ipairs

local Skin = BUI.Skinning

local SKIN_ID = 'transmog'
local SLOT_CONTAINERS = { 'LeftSlots', 'RightSlots', 'BottomSlots' }
local SLOT_ART_KEYS = { 'Border', 'ShowEquippedIcon' }
local TOGGLE_KEYS = { 'HideIgnoredToggle', 'SheatheWeaponToggle', 'PreviewedWeaponToggle' }

local installed = false
local skinned = false

local function Enabled()
	return Skin.IsSkinEnabled(SKIN_ID)
end

local context = Skin.NewContext(Enabled)
local Fade, FadeRegions, FadeKeys = context.Fade, context.FadeRegions, context.FadeKeys
local Shell, Button, Close, ScrollBar = context.Shell, context.Button, context.Close, context.ScrollBar
local CheckBox, Tab, Title, Body = context.CheckBox, context.Tab, context.Title, context.Body

local function KeepTexture(texture)
	if texture then texture.__buiSkin = true end
end

local function SkinSlot(slot)
	if not slot or slot._buiSlot or not slot.Icon then return end
	slot._buiSlot = true

	KeepTexture(slot.Icon)
	KeepTexture(slot.DisabledIcon)
	KeepTexture(slot.HiddenVisualIcon)
	FadeRegions(slot)
	FadeKeys(slot, SLOT_ART_KEYS)

	Skin.CropIcon(slot.Icon)
	Skin.TipIconFrame(slot, slot.Icon, 1)
end

local function SweepSlots(preview)
	if not preview then return end
	for _, key in ipairs(SLOT_CONTAINERS) do
		local container = preview[key]
		if container and container.GetChildren then
			for _, slot in ipairs({ container:GetChildren() }) do SkinSlot(slot) end
		end
	end
end

local function SkinToggles(preview)
	if not preview or not preview.ToggleOptions then return end
	for _, key in ipairs(TOGGLE_KEYS) do
		local toggle = preview.ToggleOptions[key]
		if toggle then
			CheckBox(toggle.Checkbox)
			Body(toggle.Text)
		end
	end
end

local function SkinTabs(collection)
	if not collection or not collection.TabHeaders then return end
	if not collection.TabHeaders.GetChildren then return end
	for _, tab in ipairs({ collection.TabHeaders:GetChildren() }) do Tab(tab) end
end

local function SkinOutfits(outfits)
	if not outfits then return end
	FadeRegions(outfits)
	if outfits.OutfitList then
		FadeRegions(outfits.OutfitList)
		ScrollBar(outfits.OutfitList.ScrollBar)
	end
	Button(outfits.PurchaseOutfitButton)
	Button(outfits.SaveOutfitButton)
	if outfits.MoneyFrame then FadeRegions(outfits.MoneyFrame) end
	if outfits.ShowEquippedGearSpellFrame then FadeRegions(outfits.ShowEquippedGearSpellFrame) end
end

local function Apply()
	local frame = _G.TransmogFrame
	if not frame or frame:IsForbidden() or not Enabled() then return end

	if not skinned then
		skinned = true
		FadeRegions(frame)
		Fade(frame.NineSlice)
		if frame.PortraitContainer then Fade(frame.PortraitContainer.portrait) end
		Shell(frame)
		Skin.HideHelpButtons(frame)
		Close(frame.CloseButton)
		Title(frame.TitleContainer and frame.TitleContainer.TitleText)

		SkinOutfits(frame.OutfitCollection)

		local preview = frame.CharacterPreview
		if preview then
			FadeRegions(preview)
			Fade(preview.Gradients)
			SkinToggles(preview)
			Button(preview.ClearAllPendingButton)
			if preview.SetupSlots then
				hooksecurefunc(preview, 'SetupSlots', function(self) SweepSlots(self) end)
			end
		end

		local collection = frame.WardrobeCollection
		if collection then
			FadeRegions(collection)
			if collection.TabContent then FadeRegions(collection.TabContent) end
		end

		if frame.OutfitPopup then
			FadeRegions(frame.OutfitPopup)
			Shell(frame.OutfitPopup)
			Close(frame.OutfitPopup.CloseButton)
		end
	end

	SkinTabs(frame.WardrobeCollection)
	SweepSlots(frame.CharacterPreview)
end

local function Install()
	if installed then return end
	local frame = _G.TransmogFrame
	if not frame then return end
	installed = true
	frame:HookScript('OnShow', Apply)
	if frame:IsShown() then Apply() end
end

local function TryInstall()
	Install()
	if installed then BUI.Events:Unregister('ADDON_LOADED', 'Skin.Transmog') end
end

local function Deactivate()
	context.Restore()
	skinned = false
	BUI.Print('Transmogrify skin disabled. /reload for a full visual reset.')
end

Skin.OnToggle(SKIN_ID, function(enabled)
	if enabled then
		Install()
		if not installed then
			BUI.Events:Register('ADDON_LOADED', 'Skin.Transmog', TryInstall)
		elseif _G.TransmogFrame and _G.TransmogFrame:IsShown() then
			Apply()
		end
	else
		Deactivate()
	end
end)

BUI.Events:Once('PLAYER_LOGIN', 'Skin.TransmogInstall', function()
	if not Enabled() then return end
	Install()
	if not installed then BUI.Events:Register('ADDON_LOADED', 'Skin.Transmog', TryInstall) end
end)

Skin.RegisterSkin(SKIN_ID, {
	name = 'Transmogrify',
	description = 'The transmogrifier at the vendor: dark shell over the stone window, framed slot icons around the model, house buttons and checkboxes, and the appearance tabs on the house tab strip.',
	icon = 'Interface/Icons/INV_Arcane_Orb',
})
