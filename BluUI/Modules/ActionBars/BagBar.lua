local _, BUI = ...

local ActionBars = BUI.ActionBars

local EVENT_KEY = 'ActionBars.BagBar'
local SLOT_NAMES = {
	'MainMenuBarBackpackButton', 'CharacterBag0Slot', 'CharacterBag1Slot', 'CharacterBag2Slot', 'CharacterBag3Slot',
	'CharacterReagentBag0Slot', 'BagBarExpandToggle',
}
local RELEASE_INSET = 4

local bagBar
local QueueRetake, QueueMeasure

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

local function InstallHooks()
	hooksecurefunc(BagsBar, 'ApplySystemAnchor', OnBlizzardAnchor)
	hooksecurefunc(BagsBar, 'Layout', OnBlizzardLayout)
	hooksecurefunc(BagsBar, 'UpdateSystemSettingSize', OnBlizzardLayout)
	for _, name in ipairs(SLOT_NAMES) do
		local slot = _G[name]
		slot:HookScript('OnShow', OnBlizzardLayout)
		slot:HookScript('OnHide', OnBlizzardLayout)
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
