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
	return { _G.ExtraActionButton1.style, _G.ZoneAbilityFrame.Style }
end

local function ZoneButtons()
	return { _G.ZoneAbilityFrame.SpellButtonContainer:GetChildren() }
end

local function Buttons()
	local buttons = ZoneButtons()
	buttons[#buttons + 1] = _G.ExtraActionButton1
	return buttons
end

local function StyleText(fontString, button, size, color, anchor, offsetX, offsetY)
	Pixel.ApplyFont(fontString, size, BUI.GetAddonFont(), 'OUTLINE')
	fontString:SetTextColor(color[1], color[2], color[3], color[4])
	fontString:SetSize(0, 0)
	fontString:ClearAllPoints()
	fontString:SetPoint(anchor, button, anchor, offsetX, offsetY)
	fontString:SetJustifyH(ActionBars.JustifyForAnchor(anchor))
end

local function StyleCount(button)
	local settings = ActionBars.GetSettings()
	StyleText(button.Count, button, settings.countFontSize, settings.countColor, settings.countAnchor, settings.countOffsetX, settings.countOffsetY)
end

local function StyleHotkey(button)
	local settings = ActionBars.GetSettings()
	local hotkey = button.HotKey
	StyleText(hotkey, button, settings.hotkeyFontSize, settings.hotkeyColor, settings.hotkeyAnchor, settings.hotkeyOffsetX, settings.hotkeyOffsetY)
	local text = BUI.Keybinds.Format(GetBindingKey(button.commandName)) or ''
	hotkey:SetText(text)
	hotkey:SetShown(text ~= '' and extraBar:Settings().showHotkey)
end

local function ShowBorder(button, showArt)
	if showArt then Pixel.HideBorder(button) else Pixel.ShowBorder(button) end
end

local function StyleExtraButton(button, showArt)
	button._buiBar = 'extra'
	ActionBars.SkinButtonArt(button)
	for _, region in ipairs({ button.lossOfControlCooldown, button.chargeCooldown, button.QuickKeybindHighlightTexture }) do
		region:ClearAllPoints()
		region:SetAllPoints(button)
	end
	StyleCount(button)
	StyleHotkey(button)
	ShowBorder(button, showArt)
end

local function StyleZoneButton(button, showArt)
	button._buiBar = 'extra'
	button._buiExtraStyled = true
	button.NormalTexture:SetAlpha(0)
	ActionBars.FlattenStateTexture(button:GetHighlightTexture(), 1, 1, 1, 0.15)
	button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	for _, cooldown in ipairs({ button.Cooldown, button.ChargeCooldown }) do
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(button)
	end
	ActionBars.StyleCooldown(button.Cooldown)
	StyleCount(button)
	local settings = ActionBars.GetSettings()
	local borderColor = settings.borderColor
	Pixel.ApplyBorder(button, settings.borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	ShowBorder(button, showArt)
end

local function ApplyArt(self)
	local showArt = self:Settings().blizzardArt == true
	for _, texture in ipairs(ArtTextures()) do texture:SetAlpha(showArt and 1 or 0) end
	StyleExtraButton(_G.ExtraActionButton1, showArt)
	for _, button in ipairs(ZoneButtons()) do StyleZoneButton(button, showArt) end
end

local function RefreshArt()
	if extraBar:Active() then ApplyArt(extraBar) end
end

local function OnHotkeysUpdated(button)
	if extraBar:Active() then StyleHotkey(button) end
end

local function OnZoneAbilitiesUpdated()
	if not extraBar:Active() then return end
	local showArt = extraBar:Settings().blizzardArt == true
	for button in _G.ZoneAbilityFrame.SpellButtonContainer:EnumerateActive() do
		if not button._buiExtraStyled then
			StyleZoneButton(button, showArt)
			ActionBars.HookFadeFrames(extraBar.bar, { button })
		end
	end
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
		Pixel.SetScale(header, barSettings.scale / 100)
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
	hooksecurefunc(_G.ExtraActionButton1, 'UpdateHotkeys', OnHotkeysUpdated)
	hooksecurefunc(_G.ZoneAbilityFrame, 'UpdateDisplayedZoneAbilities', OnZoneAbilitiesUpdated)
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
