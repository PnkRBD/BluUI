local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('ActionBars.ExtraBar')
local hooksecurefunc = BUI.Prof.MakeHooker('ActionBars.ExtraBar')

local ActionBars = BUI.ActionBars
local Pixel = BUI.Pixel

local EVENT_KEY = 'ActionBars.ExtraBar'
local EMPTY_SIZE = 52
local RELEASE_OFFSET_Y = 150

local extraBar
local QueueRetake, QueueMeasure

local function Container()
	return _G.ExtraAbilityContainer
end

local function ArtTextures()
	local textures = {}
	local extraButton = _G.ExtraActionButton1
	if extraButton and extraButton.style then textures[#textures + 1] = extraButton.style end
	local zone = _G.ZoneAbilityFrame
	if zone and zone.Style then textures[#textures + 1] = zone.Style end
	return textures
end

local function ZoneButtons()
	local zone = _G.ZoneAbilityFrame
	local holder = zone and zone.SpellButtonContainer
	if not holder then return {} end
	return { holder:GetChildren() }
end

local function Buttons()
	local buttons = ZoneButtons()
	if _G.ExtraActionButton1 then buttons[#buttons + 1] = _G.ExtraActionButton1 end
	return buttons
end

local function StyleButton(button, showArt)
	local icon = button.icon or button.Icon
	if icon and not button._buiExtraCropped then
		button._buiExtraCropped = true
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	local settings = ActionBars.GetSettings()
	local borderColor = settings.borderColor
	if showArt then
		Pixel.HideBorder(button)
	else
		Pixel.ApplyBorder(button, settings.borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
		Pixel.ShowBorder(button)
	end
end

local function ApplyArt(self)
	local showArt = self:Settings().blizzardArt == true
	for _, texture in ipairs(ArtTextures()) do texture:SetAlpha(showArt and 1 or 0) end
	for _, button in ipairs(Buttons()) do StyleButton(button, showArt) end
end

local function RefreshArt()
	if extraBar:Active() then ApplyArt(extraBar) end
end

local function Measure(self)
	if not self.bar or not self:Owned() or not self:Enabled() then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(QueueMeasure, EVENT_KEY .. '.Measure')
		return
	end
	local container = Container()
	local width, height = EMPTY_SIZE, EMPTY_SIZE
	if container:IsShown() then
		local containerWidth, containerHeight = container:GetSize()
		width = math.max(EMPTY_SIZE, containerWidth)
		height = math.max(EMPTY_SIZE, containerHeight)
	end
	self:Apply(function() self.bar.header:SetSize(width, height) end)
end

local function LeaveFrameManager(self)
	local header = self.bar.header
	local centerX, centerY = header:GetCenter()
	local parentX, parentY = UIParent:GetCenter()
	if not centerX or not parentX then return end
	local ratio = header:GetEffectiveScale() / UIParent:GetEffectiveScale()
	BUI.LeaveFrameManager(Container(), 'CENTER', 'CENTER', centerX * ratio - parentX, centerY * ratio - parentY)
end

local function Retake(self)
	if not self.bar or not self:Enabled() then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(QueueRetake, EVENT_KEY .. '.Retake')
		return
	end
	local container = Container()
	local header = self.bar.header
	local barSettings = self:Settings()
	self:Apply(function()
		container:SetParent(header)
		container:ClearAllPoints()
		container:SetPoint('CENTER', header, 'CENTER', 0, 0)
		header:SetScale(barSettings.scale / 100)
		header:Show()
	end)
	ActionBars.PositionBar(self.bar)
	self:SyncHover()
	ActionBars.HookFadeFrames(self.bar, Buttons())
	ApplyArt(self)
	LeaveFrameManager(self)
	QueueMeasure()
end

local function Release(self)
	local container = Container()
	self:Apply(function()
		container:SetParent(UIParent)
		container:ClearAllPoints()
		container:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, RELEASE_OFFSET_Y)
	end)
	for _, texture in ipairs(ArtTextures()) do texture:SetAlpha(1) end
end

local function OnBlizzardAnchor()
	if extraBar:Active() then QueueRetake() end
end

local function OnBlizzardLayout()
	if extraBar:Active() then QueueMeasure() end
end

local function OnFrameAdded()
	RefreshArt()
	OnBlizzardLayout()
end

local function InstallHooks()
	local container = Container()
	container:SetScript('OnShow', nil)
	hooksecurefunc(container, 'ApplySystemAnchor', OnBlizzardAnchor)
	hooksecurefunc(container, 'Layout', OnBlizzardLayout)
	hooksecurefunc(container, 'AddFrame', OnFrameAdded)
	hooksecurefunc(container, 'RemoveFrame', OnBlizzardLayout)
	HookScript(container, 'OnHide', OnBlizzardLayout)
	BUI.Events:Register('UPDATE_EXTRA_ACTIONBAR', EVENT_KEY .. '.Art', RefreshArt)
	BUI.Events:Register('ZONE_CHANGED_NEW_AREA', EVENT_KEY .. '.Art', RefreshArt)
end

extraBar = ActionBars.NewBlizzardBar({
	key = 'extra',
	headerName = 'BUI_ExtraBar',
	frame = Container,
	retake = Retake,
	release = Release,
	installHooks = InstallHooks,
})
QueueRetake = BUI.Dispatcher.New(function() Retake(extraBar) end, EVENT_KEY .. '.Retake')
QueueMeasure = BUI.Dispatcher.New(function() Measure(extraBar) end, EVENT_KEY .. '.Measure')

function ActionBars.RefreshExtraBar()
	if not Container() then return end
	if InCombatLockdown() then
		ActionBars.RunSecure('ExtraBar.Refresh', ActionBars.RefreshExtraBar)
		return
	end
	extraBar:Refresh()
	if extraBar.bar and extraBar:Enabled() then
		ActionBars.ApplyBarMouse(extraBar.bar, Buttons())
	end
end
