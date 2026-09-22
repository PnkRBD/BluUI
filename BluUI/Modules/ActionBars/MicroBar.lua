local _, BUI = ...

local ActionBars = BUI.ActionBars
local hooksecurefunc = ActionBars.hooksecurefunc

local BLIZZARD_PADDING = -5
local SIZE_TOLERANCE = 0.5
local EVENT_KEY = 'ActionBars.MicroBar'

local microBar
local QueueRetake
local gridButtons = {}

local function ButtonOverlap()
	return BLIZZARD_PADDING
end

local function WantedLayout(barSettings)
	local stride = math.max(1, math.min(barSettings.buttonsPerRow, MicroMenu.numButtons))
	local padding = ButtonOverlap() + barSettings.spacing
	return not barSettings.vertical, stride, padding
end

local function CompareLayoutIndex(left, right)
	return left.layoutIndex < right.layoutIndex
end

local function CollectGridButtons()
	wipe(gridButtons)
	for _, child in ipairs({ MicroMenu:GetChildren() }) do
		if child.layoutIndex and not child.ignoreInLayout and (child:IsShown() or child.includeAsLayoutChildWhenHidden) then
			gridButtons[#gridButtons + 1] = child
		end
	end
	table.sort(gridButtons, CompareLayoutIndex)
	return gridButtons
end

local function ApplyGrid(horizontal, stride, paddingX, paddingY, goingRight, goingUp)
	local buttons = CollectGridButtons()
	if #buttons == 0 then return 1, 1 end
	local xMultiplier = goingRight and 1 or -1
	local yMultiplier = goingUp and 1 or -1
	local layout
	if horizontal then
		layout = GridLayoutUtil.CreateStandardGridLayout(stride, paddingX, paddingY, xMultiplier, yMultiplier)
	else
		layout = GridLayoutUtil.CreateVerticalGridLayout(stride, paddingX, paddingY, xMultiplier, yMultiplier)
	end
	local anchorPoint
	if goingUp then
		anchorPoint = goingRight and 'BOTTOMLEFT' or 'BOTTOMRIGHT'
	else
		anchorPoint = goingRight and 'TOPLEFT' or 'TOPRIGHT'
	end
	GridLayoutUtil.ApplyGridLayout(buttons, AnchorUtil.CreateAnchor(anchorPoint, MicroMenu, anchorPoint), layout)

	local left, right, top, bottom
	for buttonIndex = 1, #buttons do
		local buttonLeft, buttonBottom, buttonWidth, buttonHeight = buttons[buttonIndex]:GetRect()
		if buttonLeft and buttonBottom then
			local buttonRight, buttonTop = buttonLeft + buttonWidth, buttonBottom + buttonHeight
			left = (left and math.min(left, buttonLeft)) or buttonLeft
			right = (right and math.max(right, buttonRight)) or buttonRight
			top = (top and math.max(top, buttonTop)) or buttonTop
			bottom = (bottom and math.min(bottom, buttonBottom)) or buttonBottom
		end
	end
	if not left then return 1, 1 end
	local width, height = math.max(1, right - left), math.max(1, top - bottom)
	MicroMenu:SetSize(width, height)
	return width, height
end

local function ApplyOwnedGrid(barSettings)
	local horizontal, stride, padding = WantedLayout(barSettings)
	return ApplyGrid(horizontal, stride, padding, padding, true, false)
end

local function MenuSize(width, height)
	local menuScale = MicroMenu:GetScale()
	return math.max(1, width * menuScale), math.max(1, height * menuScale)
end

local function Retake(self)
	if not self.bar or not self:Enabled() then return end
	local header = self.bar.header
	local barSettings = self:Settings()
	self:Apply(function()
		MicroMenu:SetParent(header)
		MicroMenu:ClearAllPoints()
		MicroMenu:SetPoint('TOPLEFT', header, 'TOPLEFT', 0, 0)
		MicroMenu:SetFrameLevel(header:GetFrameLevel() + 1)
		MicroMenu:SetAlpha(1)
		MicroMenu:Show()
		header:SetSize(MenuSize(ApplyOwnedGrid(barSettings)))
		header:SetScale(barSettings.scale / 100)
		header:Show()
	end)
	ActionBars.PositionBar(self.bar)
	self:SyncHover()
end

local function Release()
	MicroMenu:SetParent(MicroMenuContainer)
	ApplyGrid(MicroMenu.isHorizontal, MicroMenu.stride, MicroMenu.childXPadding, MicroMenu.childYPadding,
		MicroMenu.layoutFramesGoingRight, MicroMenu.layoutFramesGoingUp)
end

local function OnBlizzardLayout()
	if not microBar:Active() then return end
	if not microBar:Owned() then
		QueueRetake()
		return
	end
	local header = microBar.bar.header
	local width, height = MenuSize(ApplyOwnedGrid(microBar:Settings()))
	if math.abs(header:GetWidth() - width) > SIZE_TOLERANCE or math.abs(header:GetHeight() - height) > SIZE_TOLERANCE then
		QueueRetake()
	end
end

local function OnBlizzardMove()
	if microBar:Active() then QueueRetake() end
end

local function InstallHooks()
	hooksecurefunc(MicroMenu, 'Layout', OnBlizzardLayout)
	hooksecurefunc(MicroMenu, 'ResetMicroMenuPosition', OnBlizzardMove)
	hooksecurefunc(MicroMenu, 'OverrideMicroMenuPosition', OnBlizzardMove)
	hooksecurefunc(MicroMenu, 'SetNormalScale', OnBlizzardMove)
	hooksecurefunc('MicroMenuBar_ClearFullScreenFrame', OnBlizzardMove)
end

microBar = ActionBars.NewBlizzardBar({
	key = 'micro',
	headerName = 'BUI_MicroMenuBar',
	frame = function() return MicroMenu end,
	retake = Retake,
	release = Release,
	installHooks = InstallHooks,
})
QueueRetake = BUI.Dispatcher.New(function() Retake(microBar) end, EVENT_KEY)

function ActionBars.RefreshMicroBar()
	microBar:Refresh()
end
