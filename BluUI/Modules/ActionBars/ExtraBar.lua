local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('ActionBars.ExtraBar')
local hooksecurefunc = BUI.Prof.MakeHooker('ActionBars.ExtraBar')

local ActionBars = BUI.ActionBars
local Pixel = BUI.Pixel

local EVENT_KEY = 'ActionBars.ExtraBar'
local EMPTY_SIZE = 52

local CHILDREN = { 'ExtraActionBarFrame', 'ZoneAbilityFrame' }

local extraBar
local ApplyArt
local QueueMeasure
local Retake

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

local function StyleButton(button, showArt)
	if not button then return end
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

local function RefreshArt()
	if extraBar and extraBar:Active() then ApplyArt(extraBar) end
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

ApplyArt = function(self)
	local showArt = self:Settings().blizzardArt == true
	for _, texture in ipairs(ArtTextures()) do texture:SetAlpha(showArt and 1 or 0) end
	StyleButton(_G.ExtraActionButton1, showArt)
	for _, button in ipairs(ZoneButtons()) do StyleButton(button, showArt) end
end

local function Reclaim(self)
	local header = self.bar.header
	for _, name in ipairs(CHILDREN) do
		local child = _G[name]
		if child and child:GetParent() ~= header then
			if InCombatLockdown() then
				BUI.Events:AfterCombat(function() QueueMeasure() end, EVENT_KEY .. '.Reclaim')
				return false
			end
			self:Apply(function() child:SetParent(header) end)
		end
	end
	return true
end

local function Layout(self)
	local header = self.bar.header
	local width, height, shownCount = 0, 0, 0
	self:Apply(function()
		for _, name in ipairs(CHILDREN) do
			local child = _G[name]
			if child and child:IsShown() then
				local childWidth, childHeight = child:GetSize()
				if childWidth and childHeight and not issecretvalue(childWidth) and not issecretvalue(childHeight) then
					child:ClearAllPoints()
					child:SetPoint('BOTTOM', header, 'BOTTOM', 0, height)
					height = height + childHeight
					if childWidth > width then width = childWidth end
					shownCount = shownCount + 1
				end
			end
		end
		header:SetSize(math.max(EMPTY_SIZE, width), math.max(EMPTY_SIZE, height))
	end)
end

local function Measure(self)
	if not self.bar or not self:Enabled() then return end
	if not self:Owned() then
		if InCombatLockdown() then
			BUI.Events:AfterCombat(function() QueueMeasure() end, EVENT_KEY .. '.Retake')
			return
		end
		Retake(self)
		return
	end
	if not Reclaim(self) then return end
	Layout(self)
	ApplyArt(self)
	ActionBars.PositionBar(self.bar)
end

local function ParkContainerLayout(self)
	local container = Container()
	if not container or self.parked then return end
	self.parked = {
		script = container:GetScript('OnUpdate'),
		onUpdate = container.OnUpdate,
		isLayoutFrame = container.IsLayoutFrame,
	}
	container:SetScript('OnUpdate', nil)
	container.OnUpdate = nil
	container.IsLayoutFrame = nil
end

local function RestoreContainerLayout(self)
	local container = Container()
	local parked = self.parked
	if not container or not parked then return end
	self.parked = nil
	container.OnUpdate = parked.onUpdate
	container.IsLayoutFrame = parked.isLayoutFrame
	container:SetScript('OnUpdate', parked.script)
	if container.MarkDirty then container:MarkDirty() end
end

Retake = function(self)
	if not self.bar or not self:Enabled() then return end
	local header = self.bar.header
	local barSettings = self:Settings()
	ParkContainerLayout(self)
	self:Apply(function()
		for _, name in ipairs(CHILDREN) do
			local child = _G[name]
			if child then
				child:SetParent(header)
				child:SetFrameLevel(header:GetFrameLevel() + 1)
			end
		end
		header:SetScale(barSettings.scale / 100)
		header:Show()
	end)
	ActionBars.PositionBar(self.bar)
	QueueMeasure()
end

local function Release(self)
	local container = Container()
	if not container then return end
	self:Apply(function()
		for _, name in ipairs(CHILDREN) do
			local child = _G[name]
			if child then
				child:SetParent(container)
				child:ClearAllPoints()
			end
		end
	end)
	RestoreContainerLayout(self)
	for _, texture in ipairs(ArtTextures()) do texture:SetAlpha(1) end
end

local function OnBlizzardLayout()
	if extraBar:Active() then QueueMeasure() end
end

local function OnExtraShow()
	RefreshArt()
	OnBlizzardLayout()
end

local function OnChildParent(child, parent)
	if extraBar.applying or not extraBar:Active() then return end
	if parent ~= extraBar.bar.header then OnBlizzardLayout() end
end

local function InstallHooks()
	local container = Container()
	if container and container.AddFrame then hooksecurefunc(container, 'AddFrame', OnBlizzardLayout) end
	for _, name in ipairs(CHILDREN) do
		local child = _G[name]
		if child then
			HookScript(child, 'OnShow', OnBlizzardLayout)
			HookScript(child, 'OnHide', OnBlizzardLayout)
			HookScript(child, 'OnSizeChanged', OnBlizzardLayout)
			hooksecurefunc(child, 'SetParent', OnChildParent)
		end
	end
	if _G.ExtraActionButton1 then HookScript(_G.ExtraActionButton1, 'OnShow', OnExtraShow) end
	BUI.Events:Register('PLAYER_ENTERING_WORLD', EVENT_KEY, OnBlizzardLayout)
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

function extraBar:Owned()
	local header = self.bar and self.bar.header
	local extra = _G.ExtraActionBarFrame
	return header ~= nil and extra ~= nil and extra:GetParent() == header
end

QueueMeasure = BUI.Dispatcher.New(function() Measure(extraBar) end, EVENT_KEY .. '.Measure')

function ActionBars.RefreshExtraBar()
	if not Container() then return end
	extraBar:Refresh()
	if extraBar.bar and extraBar:Enabled() then
		ActionBars.ApplyBarMouse(extraBar.bar, Buttons())
	end
end
