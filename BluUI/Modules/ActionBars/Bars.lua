local _, BUI = ...

local ActionBars = BUI.ActionBars
local Pixel = BUI.Pixel
local LibActionButton = LibStub('LibActionButton-1.0-BluUI')

local MAIN_BAR_VISIBILITY = '[petbattle] hide; show'
local SIDE_BAR_VISIBILITY = '[petbattle][vehicleui][overridebar] hide; show'

local function CreateBar(barIndex)
	return ActionBars.RegisterBar({
		key = barIndex,
		kind = 'action',
		label = ActionBars.BarLabel(barIndex),
		command = ActionBars.COMMAND_FOR_BAR[barIndex],
		clickButton = 'Keybind',
		header = ActionBars.CreateHeader('BUI_ActionBar' .. barIndex, true),
		buttons = {},
		visibility = barIndex == 1 and MAIN_BAR_VISIBILITY or SIDE_BAR_VISIBILITY,
	})
end

local function CreateButtons(bar)
	local page = ActionBars.PAGE_FOR_BAR[bar.key]
	for buttonIndex = 1, ActionBars.BUTTONS_PER_PAGE do
		local buttonName = 'BUI_ActionBar' .. bar.key .. 'Button' .. buttonIndex
		local button = LibActionButton:CreateButton(buttonIndex, buttonName, bar.header, ActionBars.BuildButtonConfig(bar.key, buttonIndex))
		button:SetState(0, 'action', (page - 1) * ActionBars.BUTTONS_PER_PAGE + buttonIndex)
		ActionBars.SetPagingStates(button, buttonIndex)
		button._buiBar = bar.key
		ActionBars.ApplyButtonLock(button)
		ActionBars.SkinButton(button)
		ActionBars.ApplyHotkeyText(button)
		bar.buttons[buttonIndex] = button
	end
end

local function GridSize(buttonCount, perRow, buttonSize, buttonHeight, spacing)
	local columns = math.max(1, math.min(perRow, buttonCount))
	local rows = math.max(1, math.ceil(buttonCount / perRow))
	return columns * buttonSize + (columns - 1) * spacing, rows * buttonHeight + (rows - 1) * spacing
end

function ActionBars.LayoutBar(bar, buttonCountOverride)
	local barSettings = ActionBars.GetBarSettings(bar.key)
	local buttonSize = Pixel.Scale(barSettings.buttonSize)
	local buttonHeight = barSettings.buttonHeight > 0 and Pixel.Scale(barSettings.buttonHeight) or buttonSize
	local spacing = Pixel.Scale(barSettings.spacing)
	local fromRight = barSettings.growth:find('RIGHT', 1, true) ~= nil
	local fromBottom = barSettings.growth:find('BOTTOM', 1, true) ~= nil
	local point = (fromBottom and 'BOTTOM' or 'TOP') .. (fromRight and 'RIGHT' or 'LEFT')
	local available = #bar.buttons
	local configuredCount = math.max(1, math.min(barSettings.buttonCount, available))
	local buttonCount = math.max(0, math.min(buttonCountOverride or configuredCount, available))
	local perRow = math.max(1, math.min(barSettings.buttonsPerRow, configuredCount))

	for buttonIndex = 1, available do
		local button = bar.buttons[buttonIndex]
		if buttonIndex > buttonCount then
			button:Hide()
		else
			local rowIndex = math.floor((buttonIndex - 1) / perRow)
			local columnIndex = (buttonIndex - 1) % perRow
			button:SetSize(buttonSize, buttonHeight)
			button:ClearAllPoints()
			button:SetPoint(point, bar.header, point,
				(fromRight and -1 or 1) * columnIndex * (buttonSize + spacing),
				(fromBottom and 1 or -1) * rowIndex * (buttonHeight + spacing))
			ActionBars.ApplyIconCrop(button)
			button:Show()
		end
	end

	bar.empty = buttonCount == 0
	bar.header:SetSize(GridSize(bar.empty and configuredCount or buttonCount, perRow, buttonSize, buttonHeight, spacing))
	bar.header:SetScale(barSettings.scale / 100)
end

function ActionBars.PositionBar(bar)
	local barSettings = ActionBars.GetBarSettings(bar.key)
	bar.header:SetFrameStrata(barSettings.frameStrata)
	BUI.Anchor.ApplyPosition(bar.header, barSettings)
end

function ActionBars.SetBarActive(bar, active)
	if active then
		if bar.visibility and not bar.forcedShown then
			RegisterStateDriver(bar.header, 'visibility', bar.visibility)
		else
			bar.header:Show()
		end
	else
		UnregisterStateDriver(bar.header, 'visibility')
		bar.header:Hide()
	end
end

function ActionBars.ForceBarShown(bar)
	if bar.visibility then UnregisterStateDriver(bar.header, 'visibility') end
	bar.header:Show()
end

function ActionBars.BuildBar(barIndex)
	local bar = ActionBars.bars[barIndex] or CreateBar(barIndex)
	if #bar.buttons == 0 then
		CreateButtons(bar)
	end
	ActionBars.LayoutBar(bar)
	ActionBars.PositionBar(bar)
	return bar
end

function ActionBars.RefreshAllBars()
	ActionBars.ApplyPickupKey()
	for barIndex = 1, ActionBars.BAR_COUNT do
		local barSettings = ActionBars.GetBarSettings(barIndex)
		local bar = ActionBars.bars[barIndex]
		if barSettings and barSettings.enabled then
			if bar then
				ActionBars.ApplyButtonConfig(bar)
				ActionBars.LayoutBar(bar)
				ActionBars.PositionBar(bar)
			else
				bar = ActionBars.BuildBar(barIndex)
			end
			ActionBars.ApplyBarMouse(bar)
			ActionBars.SetBarActive(bar, true)
		elseif bar then
			ActionBars.SetBarActive(bar, false)
		end
	end
	ActionBars.RefreshFlyoutButtons()
	BUI.Anchor.OnAnchorSizeChanged()
end
