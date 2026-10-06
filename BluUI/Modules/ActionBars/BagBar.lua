local _, BUI = ...

local Hook = BUI.Profiler.Hooker('ActionBars.BagBar')

local ActionBars = BUI.ActionBars

local EVENT_KEY = 'ActionBars.BagBar'
local SLOT_NAMES = {
	'MainMenuBarBackpackButton', 'CharacterBag0Slot', 'CharacterBag1Slot', 'CharacterBag2Slot', 'CharacterBag3Slot',
	'CharacterReagentBag0Slot', 'BagBarExpandToggle',
}
local RELEASE_INSET = 4
local BAG_BUTTON_NAMES = {
	'MainMenuBarBackpackButton', 'CharacterBag0Slot', 'CharacterBag1Slot', 'CharacterBag2Slot', 'CharacterBag3Slot',
	'CharacterReagentBag0Slot',
}
local MASKED_REGIONS = { 'icon', 'searchOverlay', 'ItemContextOverlay' }
local COUNT_SIZE = 12
local BACKPACK_ICON = 133633
local EXPAND_CVAR = 'expandBagBar'

local bagBar
local QueueRetake, QueueMeasure
local bagButtonsSkinned = false
local singleApplied = false

local function ApplySingleBag(barSettings)
	local single = barSettings.singleBag == true
	if single then
		C_CVar.SetCVar(EXPAND_CVAR, '0')
	elseif singleApplied then
		C_CVar.SetCVar(EXPAND_CVAR, '1')
	end
	singleApplied = single
	MainMenuBarBagManager:SetExpandBar(not single)
	CharacterReagentBag0Slot:SetShown(not single)
	BagsBar:Layout()
end

local function StyleBagState(button)
	button:GetNormalTexture():SetAlpha(0)
	button:GetPushedTexture():SetAlpha(0)
	local highlight = button:GetHighlightTexture()
	highlight:SetBlendMode('BLEND')
	highlight:SetAlpha(1)
	ActionBars.FlattenStateTexture(highlight, 1, 1, 1, 0.15)
	ActionBars.FlattenStateTexture(button.SlotHighlightTexture, 1, 1, 1, 0.3)
end

local function ShowFreeSlots(button)
	button.Count:SetText(button.freeSlots)
end

local function ShowBackpackIcon(button)
	button.icon:SetTexture(BACKPACK_ICON)
	button.icon:Show()
end

local function CloseToggleGap()
	if BagBarExpandToggle:IsShown() then return end
	local point, relativePoint, offsetX, offsetY = BagsBar:GetBagButtonAnchorPoints()
	for _, button in MainMenuBarBagManager:EnumerateBagButtons() do
		if button:IsShown() and button ~= MainMenuBarBackpackButton then
			button:ClearAllPoints()
			button:SetPoint(point, MainMenuBarBackpackButton, relativePoint, offsetX, offsetY)
			return
		end
	end
end

local function HideExpandToggle()
	if not BagBarExpandToggle:IsShown() then return end
	BagBarExpandToggle:Hide()
	BagsBar:Layout()
end

local function RestoreExpandToggle()
	if BagBarExpandToggle:IsShown() then return end
	BagBarExpandToggle:Show()
	BagsBar:Layout()
end

local function SkinBagButton(button, settings)
	for _, key in ipairs(MASKED_REGIONS) do
		local region = button[key]
		if region then region:RemoveMaskTexture(button.CircleMask) end
	end
	button.icon:ClearAllPoints()
	button.icon:SetAllPoints()
	ActionBars.ApplyIconCrop(button)
	StyleBagState(button)
	Hook(button, 'UpdateTextures', StyleBagState)
	local borderColor = settings.borderColor
	BUI.Pixel.ApplyBorder(button, settings.borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	BUI.Pixel.ApplyFont(button.Count, COUNT_SIZE, BUI.GetGlobalFont(), 'OUTLINE')
end

local function SkinBagButtons()
	if bagButtonsSkinned then return end
	bagButtonsSkinned = true
	local settings = ActionBars.GetSettings()
	for _, name in ipairs(BAG_BUTTON_NAMES) do SkinBagButton(_G[name], settings) end
	local backpack = MainMenuBarBackpackButton
	backpack.Count:ClearAllPoints()
	backpack.Count:SetPoint('BOTTOM', backpack, 'BOTTOM', 0, 2)
	Hook(backpack, 'UpdateFreeSlots', ShowFreeSlots)
	Hook(backpack, 'SetItemButtonTexture', ShowBackpackIcon)
	ShowBackpackIcon(backpack)
	ShowFreeSlots(backpack)
end

local function VisibleBounds()
	local left, right, top, bottom
	for _, child in ipairs({ BagsBar:GetChildren() }) do
		if child:IsShown() then
			local childLeft, childRight, childTop, childBottom = child:GetLeft(), child:GetRight(), child:GetTop(), child:GetBottom()
			if childLeft and childRight and childTop and childBottom then
				left = left and math.min(left, childLeft) or childLeft
				right = right and math.max(right, childRight) or childRight
				top = top and math.max(top, childTop) or childTop
				bottom = bottom and math.min(bottom, childBottom) or childBottom
			end
		end
	end
	return left, right, top, bottom
end

local function Measure(self)
	if not self:Owned() or not self:Enabled() then return end
	local left, right, top, bottom = VisibleBounds()
	local barLeft, barTop = BagsBar:GetLeft(), BagsBar:GetTop()
	if not left or not barLeft then return end
	local header = self.bar.header
	self:Apply(function()
		BagsBar:ClearAllPoints()
		BagsBar:SetPoint('TOPLEFT', header, 'TOPLEFT', barLeft - left, barTop - top)
		local scale = BagsBar:GetScale()
		header:SetSize(math.max(1, (right - left) * scale), math.max(1, (top - bottom) * scale))
	end)
	ActionBars.PositionBar(self.bar)
end

local function Retake(self)
	if not self.bar or not self:Enabled() then return end
	local header = self.bar.header
	local barSettings = self:Settings()
	self:Apply(function()
		SkinBagButtons()
		ApplySingleBag(barSettings)
		HideExpandToggle()
		BagsBar:SetParent(header)
		BagsBar:ClearAllPoints()
		BagsBar:SetPoint('TOPLEFT', header, 'TOPLEFT', 0, 0)
		BagsBar:SetFrameLevel(header:GetFrameLevel() + 1)
		BagsBar:SetAlpha(1)
		BagsBar:Show()
		local scale = BagsBar:GetScale()
		header:SetSize(math.max(1, BagsBar:GetWidth() * scale), math.max(1, BagsBar:GetHeight() * scale))
		BUI.Pixel.SetScale(header, barSettings.scale / 100)
		header:Show()
	end)
	ActionBars.PositionBar(self.bar)
	self:SyncHover()
	QueueMeasure()
end

local function Release()
	if singleApplied then
		singleApplied = false
		C_CVar.SetCVar(EXPAND_CVAR, '1')
		MainMenuBarBagManager:SetExpandBar(true)
		CharacterReagentBag0Slot:Show()
	end
	RestoreExpandToggle()
	BagsBar:SetParent(UIParent)
	BagsBar:ClearAllPoints()
	BagsBar:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', -RELEASE_INSET, RELEASE_INSET)
end

local function OnBlizzardAnchor()
	if bagBar:Active() then QueueRetake() end
end

local function OnBlizzardLayout()
	if bagBar:Active() then QueueMeasure() end
end

local function AfterBlizzardLayout()
	CloseToggleGap()
	OnBlizzardLayout()
end

local function InstallHooks()
	Hook(BagsBar, 'ApplySystemAnchor', OnBlizzardAnchor)
	Hook(BagsBar, 'Layout', AfterBlizzardLayout)
	Hook(BagsBar, 'UpdateSystemSettingSize', OnBlizzardLayout)
	local onSlotLayout = BUI.Profiler.Wrap('ActionBars.BagBar slot layout', OnBlizzardLayout)
	for _, name in ipairs(SLOT_NAMES) do
		local slot = _G[name]
		slot:HookScript('OnShow', onSlotLayout)
		slot:HookScript('OnHide', onSlotLayout)
	end
end

bagBar = ActionBars.NewBlizzardBar({
	key = 'bags',
	headerName = 'BUI_BagBar',
	frame = function() return BagsBar end,
	retake = Retake,
	release = Release,
	installHooks = InstallHooks,
})
QueueRetake = BUI.Dispatcher.New(function() Retake(bagBar) end, EVENT_KEY .. '.Retake')
QueueMeasure = BUI.Dispatcher.New(function() Measure(bagBar) end, EVENT_KEY .. '.Measure')

function ActionBars.RefreshBagBar()
	bagBar:Refresh()
end
