local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Trainer')

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Widget = BUILib.Widget
local Controls = BUILib.Controls
local Colors = BUILib.Colors
local FONT = BUILib.Font or STANDARD_TEXT_FONT
local Skin = BUI.Skinning
local Pixel = BUI.Pixel

local FRAME_WIDTH = 480
local FRAME_HEIGHT = 560
local ROW_HEIGHT = 40
local ROW_PAD = 2
local ICON_SIZE = 32
local SCROLL_PAD = 8
local BUY_DELAY = 0.3

local TRAINER_ADDON = 'Blizzard_TrainerUI'
local PANEL_SLOT_X = 16
local PANEL_SLOT_Y = -116

local FILTER_ALL         = 1
local FILTER_AVAILABLE   = 2
local FILTER_UNAVAILABLE = 3
local FILTER_KNOWN       = 4

local CATEGORY_COLORS = {
	available   = { 1, 0.82, 0, 1 },
	unavailable = { 0.5, 0.5, 0.5, 1 },
	used        = { 0.3, 0.3, 0.3, 1 },
}

local CATEGORY_LABELS = {
	unavailable = 'Unavailable',
	used        = 'Already Known',
}

local VALID_CATEGORIES = { available = true, unavailable = true, used = true }

local activeFilter = FILTER_AVAILABLE
local searchText = ''
local npcName = 'Trainer'
local trainerFrame
local services = {}
local rows = {}
local isOpen = false

local scanTip = CreateFrame('GameTooltip', 'BUITrainerScanTip', nil, 'GameTooltipTemplate')
scanTip:SetOwner(WorldFrame, 'ANCHOR_NONE')

local function ScanRequirements(serviceIndex)
	scanTip:ClearLines()
	scanTip:SetTrainerService(serviceIndex)
	local requirements
	for lineIndex = 2, scanTip:NumLines() do
		local leftText = _G['BUITrainerScanTipTextLeft' .. lineIndex]
		local text = leftText and leftText:GetText()
		if text then
			local isRequires = text:find('^Requires') ~= nil
			if isRequires then
				requirements = text
			else

				local red, green, blue = leftText:GetTextColor()
				if red > 0.9 and green < 0.2 and blue < 0.2 then
					requirements = requirements and (requirements .. ', ' .. text) or text
				end
			end
		end
	end
	return requirements
end

local function ScanServices()
	wipe(services)
	for serviceIndex = 1, GetNumTrainerServices() do
		local name, category = GetTrainerServiceInfo(serviceIndex)
		if name then
			if not VALID_CATEGORIES[category] then category = 'unavailable' end
			services[#services + 1] = {
				index = serviceIndex,
				name = name,
				reqs = ScanRequirements(serviceIndex),
				category = category,
				cost = GetTrainerServiceCost(serviceIndex) or 0,
				icon = GetTrainerServiceIcon(serviceIndex),
			}
		end
	end
end

local function PassesFilter(service)
	if activeFilter == FILTER_AVAILABLE   and service.category ~= 'available'   then return false end
	if activeFilter == FILTER_UNAVAILABLE and service.category ~= 'unavailable' then return false end
	if activeFilter == FILTER_KNOWN       and service.category ~= 'used'        then return false end
	if searchText ~= '' and not service.name:lower():find(searchText, 1, true) then return false end
	return true
end

local RefreshContent

local function CreateRow(parent)
	local row = Skin.CreateListRow(parent, ROW_HEIGHT, ICON_SIZE)

	row.reqText = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row.reqText, 9, FONT, '')
	row.reqText:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(-8))
	row.reqText:SetTextColor(0.5, 0.5, 0.5, 1)

	row.trainBtn = Skin.SmallButton(row, 50, ROW_HEIGHT - 6, 'Train')
	row.trainBtn:SetPoint('RIGHT', Pixel.Scale(-4), 0)
	row.trainBtn:SetFrameLevel(row:GetFrameLevel() + 5)
	SetScript(row.trainBtn, 'OnClick', function(self)
		local index = self:GetParent().serviceIndex
		if index then
			BuyTrainerService(index)
			BUI.Prof.After('Trainer', 0.1, RefreshContent)
		end
	end)

	Pixel.ApplyFont(row.priceText, 11, FONT, '')

	SetScript(row, 'OnEnter', function(self)
		self:SetBackdropBorderColor(Colors.GetAccent())
		if self.serviceIndex then
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetTrainerService(self.serviceIndex)
			GameTooltip:Show()
		end
	end)
	SetScript(row, 'OnLeave', function(self)
		self:SetBackdropBorderColor(unpack(Colors.border.dark))
		GameTooltip:Hide()
	end)

	return row
end

local function PopulateRows(parent)
	local offsetY = 0
	local shown = 0
	local money = GetMoney()

	for _, service in ipairs(services) do
		if PassesFilter(service) then
			shown = shown + 1
			local row = rows[shown]
			if not row then
				row = CreateRow(parent)
				rows[shown] = row
			end

			row:SetPoint('TOPLEFT', 0, Pixel.Scale(-offsetY))
			row:SetPoint('RIGHT')
			row.icon:SetTexture(service.icon)
			row.nameText:SetText(service.name)

			local isAvailable = service.category == 'available'
			local canAfford = isAvailable and money >= service.cost
			row.trainBtn:SetShown(isAvailable)
			if isAvailable then
				row.trainBtn:SetAlpha(canAfford and 1 or 0.4)
				row.trainBtn:EnableMouse(canAfford)
			end

			row.priceText:ClearAllPoints()
			if isAvailable then
				row.priceText:SetPoint('RIGHT', row.trainBtn, 'LEFT', Pixel.Scale(-6), 0)
			else
				row.priceText:SetPoint('RIGHT', Pixel.Scale(-8), 0)
			end

			row.nameText:ClearAllPoints()
			row.nameText:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(6))
			row.nameText:SetPoint('RIGHT', row.priceText, 'LEFT', Pixel.Scale(-8), 0)

			if isAvailable and not canAfford then
				row.nameText:SetTextColor(0.8, 0.2, 0.2, 1)
			else
				local color = CATEGORY_COLORS[service.category] or CATEGORY_COLORS.unavailable
				row.nameText:SetTextColor(color[1], color[2], color[3], color[4])
			end

			local subtitle = service.reqs or CATEGORY_LABELS[service.category]
			if subtitle then
				row.reqText:SetText(subtitle)
				row.reqText:Show()
			else
				row.reqText:Hide()
			end

			if service.cost > 0 then
				row.priceText:SetText(GetCoinTextureString(service.cost))
				row.priceText:Show()
			else
				row.priceText:Hide()
			end

			row.serviceIndex = service.index
			row:Show()
			offsetY = offsetY + ROW_HEIGHT + ROW_PAD
		end
	end

	for rowIndex = shown + 1, #rows do rows[rowIndex]:Hide() end
	parent:SetHeight(math.max(1, offsetY))
	return shown
end

local function GetTrainAllInfo()
	local totalCost, count = 0, 0
	for _, service in ipairs(services) do
		if service.category == 'available' then
			totalCost = totalCost + service.cost
			count = count + 1
		end
	end
	return count, totalCost
end

local function TrainAll()
	local queue = {}
	for _, service in ipairs(services) do
		if service.category == 'available' then
			queue[#queue + 1] = service.index
		end
	end
	local queueIndex = 0
	local function BuyNext()
		queueIndex = queueIndex + 1
		if queue[queueIndex] then
			BuyTrainerService(queue[queueIndex])
			BUI.Prof.After('Trainer', BUY_DELAY, BuyNext)
		end
	end
	BuyNext()
end

local function BuildFrame()
	if trainerFrame then return end

	local frame = Widget.New(UIParent, 'Frame', nil, {
		bg = Colors.bg.dark,
		border = Colors.border.default,
		size = { FRAME_WIDTH, FRAME_HEIGHT },
	}).frame
	frame:SetFrameStrata('HIGH')
	frame:Hide()
	trainerFrame = frame

	Skin.MakeDraggable(frame, 'trainer', 'TOPLEFT', Pixel.Scale(PANEL_SLOT_X), Pixel.Scale(PANEL_SLOT_Y), 'ClassTrainerFrame')

	Skin.CreateTitleBar(frame, 'Trainer', 36, CloseTrainer)

	local filterItems = {
		{ label = 'Available',     filter = FILTER_AVAILABLE },
		{ label = 'All',           filter = FILTER_ALL },
		{ label = 'Unavailable',   filter = FILTER_UNAVAILABLE },
		{ label = 'Already Known', filter = FILTER_KNOWN },
	}
	frame.filterDD = Skin.CreateDropdown(frame, filterItems, function(item)
		activeFilter = item.filter
		RefreshContent()
	end, 120)
	frame.filterDD:SetPoint('TOPRIGHT', Pixel.Scale(-12), Pixel.Scale(-40))

	frame.searchBox = Skin.CreateSearchBox(frame, 160, function(text)
		searchText = text
		RefreshContent()
	end)
	frame.searchBox:SetPoint('RIGHT', frame.filterDD, 'LEFT', Pixel.Scale(-8), 0)

	frame.countText = frame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(frame.countText, 10, FONT, '')
	frame.countText:SetPoint('LEFT', Pixel.Scale(14), 0)
	frame.countText:SetPoint('TOP', 0, Pixel.Scale(-44))
	frame.countText:SetTextColor(0.5, 0.5, 0.5, 1)

	local contentArea = CreateFrame('Frame', nil, frame)
	contentArea:SetPoint('TOPLEFT', 0, Pixel.Scale(-68))
	contentArea:SetPoint('BOTTOMRIGHT', 0, Pixel.Scale(56))
	frame.scroll, frame.child = Skin.CreateScrollArea(contentArea, ROW_HEIGHT, SCROLL_PAD)

	frame.moneyText = frame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(frame.moneyText, 11, FONT, '')
	frame.moneyText:SetPoint('BOTTOMLEFT', Pixel.Scale(16), Pixel.Scale(20))
	frame.moneyText:SetTextColor(0.8, 0.8, 0.8, 1)

	frame.trainAllBtn = Controls.Button(frame, 'Train All', 90, TrainAll)
	frame.trainAllBtn:SetPoint('BOTTOMRIGHT', Pixel.Scale(-12), Pixel.Scale(14))
	frame.trainAllBtn:SetFrameLevel(frame:GetFrameLevel() + 10)

	frame.emptyText = contentArea:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(frame.emptyText, 13, FONT, '')
	frame.emptyText:SetPoint('CENTER', 0, Pixel.Scale(20))
	frame.emptyText:SetTextColor(0.45, 0.45, 0.45, 1)
	frame.emptyText:Hide()
end

RefreshContent = function()
	if not trainerFrame or not trainerFrame:IsShown() then return end

	trainerFrame.titleText:SetText(npcName)
	trainerFrame.moneyText:SetText(GetCoinTextureString(GetMoney()))

	ScanServices()
	local shown = PopulateRows(trainerFrame.child)
	trainerFrame.countText:SetText(shown .. '/' .. #services)
	trainerFrame.scroll:SetVerticalScroll(0)

	trainerFrame.emptyText:SetShown(shown == 0)
	if shown == 0 then
		if searchText ~= '' then
			trainerFrame.emptyText:SetText('No matching services.')
		elseif activeFilter == FILTER_AVAILABLE then
			trainerFrame.emptyText:SetText('Nothing available to learn.')
		else
			trainerFrame.emptyText:SetText('No services found.')
		end
	end

	local trainCount, totalCost = GetTrainAllInfo()
	trainerFrame.trainAllBtn:SetShown(trainCount > 0)
	if trainCount > 0 then
		local canAfford = GetMoney() >= totalCost
		trainerFrame.trainAllBtn:SetAlpha(canAfford and 1 or 0.4)
		trainerFrame.trainAllBtn:EnableMouse(canAfford)
	end
end

local blizzHooked = false

local function EnsureBlizzTrainer()
	if not _G.ClassTrainerFrame then C_AddOns.LoadAddOn(TRAINER_ADDON) end
	return _G.ClassTrainerFrame
end

local function WithBlizzTrainer(callback)
	local blizzardFrame = ClassTrainerFrame
	if blizzardFrame then callback(blizzardFrame) end
end

local function HideBlizzardTrainer()
	WithBlizzTrainer(Skin.SuppressBlizzardFrame)
end

local function RestoreBlizzard()
	WithBlizzTrainer(Skin.RestoreBlizzardFrame)
end

local function SuppressBlizzardTrainer()
	if not blizzHooked then
		WithBlizzTrainer(function(blizzardFrame)
			blizzHooked = true
			HookScript(blizzardFrame, 'OnShow', function() if isOpen then HideBlizzardTrainer() end end)
		end)
	end
	HideBlizzardTrainer()
end

local function OpenTrainer()
	npcName = UnitName('npc') or 'Trainer'

	if not Skin.IsSkinEnabled('trainer') then
		isOpen = false
		RestoreBlizzard()
		if trainerFrame then trainerFrame:Hide() end
		return
	end

	EnsureBlizzTrainer()
	BuildFrame()
	isOpen = true
	activeFilter = FILTER_AVAILABLE
	trainerFrame.filterDD.label:SetText('Available')
	searchText = ''
	trainerFrame.searchBox.editBox:SetText('')
	trainerFrame:Show()

	SuppressBlizzardTrainer()
	BUI.Prof.After('Trainer', 0, function()
		if not isOpen then return end
		SuppressBlizzardTrainer()
		RefreshContent()
	end)
end

local function CloseTrainerSkin()
	isOpen = false
	if trainerFrame then trainerFrame:Hide() end
	RestoreBlizzard()
	wipe(services)
	for _, row in ipairs(rows) do row.serviceIndex = nil end
end

local function OnTrainerEvent(event, addonName)
	if event == 'ADDON_LOADED' and addonName == 'Blizzard_TrainerUI' then
		BUI.Events:Unregister('ADDON_LOADED', 'Skinning.Trainer')
		if isOpen then
			SuppressBlizzardTrainer()
			RefreshContent()
		end
	elseif event == 'TRAINER_SHOW' then
		OpenTrainer()
		BUI.Events:Register('PLAYER_MONEY', 'Skinning.Trainer.Live', OnTrainerEvent)
	elseif event == 'TRAINER_CLOSED' then
		BUI.Events:Unregister('PLAYER_MONEY', 'Skinning.Trainer.Live')
		CloseTrainerSkin()
	elseif event == 'TRAINER_UPDATE' then
		if isOpen then
			SuppressBlizzardTrainer()
			RefreshContent()
		end
	elseif event == 'PLAYER_MONEY' then
		if isOpen then RefreshContent() end
	end
end

BUI.Events:Register('TRAINER_SHOW', 'Skinning.Trainer', OnTrainerEvent)
BUI.Events:Register('TRAINER_CLOSED', 'Skinning.Trainer', OnTrainerEvent)
BUI.Events:Register('TRAINER_UPDATE', 'Skinning.Trainer', OnTrainerEvent)
BUI.Events:Register('ADDON_LOADED', 'Skinning.Trainer', OnTrainerEvent)

Skin.OnToggle('trainer', function(enabled)
	if not enabled then
		BUI.Events:Unregister('PLAYER_MONEY', 'Skinning.Trainer.Live')
		Skin.ReleasePanelSlot('ClassTrainerFrame')
		CloseTrainerSkin()
	elseif _G.ClassTrainerFrame and _G.ClassTrainerFrame:IsShown() then
		OnTrainerEvent('TRAINER_SHOW')
	end
end)

Skin.RegisterSkin('trainer', {
	name = 'Trainer',
	description = 'Replaces the class trainer window with a dark, searchable frame and a Train All button.',
	icon = 'Interface\\Icons\\INV_Misc_Book_11',
})
