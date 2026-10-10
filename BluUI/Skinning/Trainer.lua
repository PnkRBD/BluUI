local _, BUI = ...

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local FONT = BUILib.Font or STANDARD_TEXT_FONT
local Skin = BUI.Skinning
local Painter = BUI.Painter
local Pixel = BUI.Pixel
local After = BUI.Profiler.After

local FRAME_WIDTH = 480
local FRAME_HEIGHT = 560
local ROW_HEIGHT = 40
local ROW_PAD = 4
local ICON_SIZE = 32
local SCROLL_PAD = 8
local BUY_DELAY = 0.3
local TRAIN_ALL_W, BUTTON_H = 90, 26
local DIMMED_ALPHA = 0.45
local PANEL_SLOT_X = 16
local PANEL_SLOT_Y = -116

local FILTER_ALL         = 1
local FILTER_AVAILABLE   = 2
local FILTER_UNAVAILABLE = 3
local FILTER_KNOWN       = 4
local FILTER_CATEGORY = { [FILTER_AVAILABLE] = 'available', [FILTER_UNAVAILABLE] = 'unavailable', [FILTER_KNOWN] = 'used' }
local CATEGORY_LABELS = { unavailable = 'Unavailable', used = 'Already Known' }
local VALID_CATEGORIES = { available = true, unavailable = true, used = true }
local LIVE_EVENTS = { 'PLAYER_MONEY', 'TRAINER_UPDATE', 'TRAINER_SERVICE_INFO_NAME_UPDATE', 'TRAINER_DESCRIPTION_UPDATE' }

local context = Skin.Define('trainer', {
	name = 'Trainer',
	description = 'Replaces the class trainer window with a searchable card list and a Train All button.',
	icon = 'Interface\\Icons\\INV_Misc_Book_11',
	newLook = true,
})

local activeFilter = FILTER_AVAILABLE
local searchText = ''
local trainerFrame
local services = {}
local rows = {}
local RefreshContent

local function ScanServices()
	wipe(services)
	for serviceIndex = 1, GetNumTrainerServices() do
		local name, category, icon = GetTrainerServiceInfo(serviceIndex)
		if name then
			services[#services + 1] = {
				index = serviceIndex, name = name, icon = icon,
				category = VALID_CATEGORIES[category] and category or 'unavailable',
				cost = GetTrainerServiceCost(serviceIndex) or 0,
			}
		end
	end
end

local function ShowEveryService()
	SetTrainerServiceTypeFilter('available', true)
	SetTrainerServiceTypeFilter('unavailable', true)
	SetTrainerServiceTypeFilter('used', true)
end

local function PassesFilter(service)
	local category = FILTER_CATEGORY[activeFilter]
	if category and service.category ~= category then return false end
	return searchText == '' or service.name:lower():find(searchText, 1, true) ~= nil
end

local function CreateRow(parent)
	local row = Skin.CreateListRow(parent, ROW_HEIGHT, ICON_SIZE)
	Pixel.ApplyFont(row.priceText, 11, FONT, '')
	Painter.Text(row.nameText, 'skinText')

	row.statusText = row:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(row.statusText, 9, FONT, '')
	row.statusText:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(-8))
	Painter.Text(row.statusText, 'skinLabel')

	row.trainBtn = Skin.SmallButton(row, 50, ROW_HEIGHT - 6, 'Train')
	row.trainBtn:SetPoint('RIGHT', Pixel.Scale(-4), 0)
	row.trainBtn:SetFrameLevel(row:GetFrameLevel() + 5)
	row.trainBtn:SetScript('OnClick', BUI.Profiler.Script('Skin.Trainer trainBtn OnClick', function(self)
		BuyTrainerService(self:GetParent().serviceIndex)
		After('Skin.Trainer list refresh', 0.1, RefreshContent)
	end))

	row:HookScript('OnEnter', BUI.Profiler.Wrap('Skin.Trainer row OnEnter', function(self)
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		GameTooltip:SetTrainerService(self.serviceIndex)
		GameTooltip:Show()
	end))
	return row
end

local function FillRow(row, service, money)
	row.icon:SetTexture(service.icon)
	row.nameText:SetText(service.name)

	local isAvailable = service.category == 'available'
	local canAfford = isAvailable and money >= service.cost
	row:SetAlpha((isAvailable and canAfford) and 1 or DIMMED_ALPHA)
	row.trainBtn:SetShown(isAvailable)
	row.trainBtn:EnableMouse(canAfford)

	row.priceText:ClearAllPoints()
	if isAvailable then
		row.priceText:SetPoint('RIGHT', row.trainBtn, 'LEFT', Pixel.Scale(-6), 0)
	else
		row.priceText:SetPoint('RIGHT', Pixel.Scale(-8), 0)
	end
	row.priceText:SetShown(service.cost > 0)
	row.priceText:SetText(GetCoinTextureString(service.cost))

	row.nameText:ClearAllPoints()
	row.nameText:SetPoint('LEFT', row.iconBorder, 'RIGHT', Pixel.Scale(8), Pixel.Scale(6))
	row.nameText:SetPoint('RIGHT', row.priceText, 'LEFT', Pixel.Scale(-8), 0)
	row.statusText:SetText(CATEGORY_LABELS[service.category] or '')
	row.serviceIndex = service.index
end

local function PopulateRows(parent)
	local offsetY, shown, money = 0, 0, GetMoney()
	for _, service in ipairs(services) do
		if PassesFilter(service) then
			shown = shown + 1
			local row = rows[shown] or CreateRow(parent)
			rows[shown] = row
			row:ClearAllPoints()
			row:SetPoint('TOPLEFT', 0, Pixel.Scale(-offsetY))
			row:SetPoint('RIGHT')
			FillRow(row, service, money)
			row:Show()
			offsetY = offsetY + ROW_HEIGHT + ROW_PAD
		end
	end
	for rowIndex = shown + 1, #rows do rows[rowIndex]:Hide() end
	parent:SetHeight(math.max(1, offsetY))
	return shown
end

local function AvailableServices()
	local queue, totalCost = {}, 0
	for _, service in ipairs(services) do
		if service.category == 'available' then
			queue[#queue + 1] = service.index
			totalCost = totalCost + service.cost
		end
	end
	return queue, totalCost
end

local function TrainAll()
	local queue = AvailableServices()
	local queueIndex = 0
	local function BuyNext()
		queueIndex = queueIndex + 1
		if not queue[queueIndex] then return end
		BuyTrainerService(queue[queueIndex])
		After('Skin.Trainer train all', BUY_DELAY, BuyNext)
	end
	BuyNext()
end

local function BuildFrame()
	if trainerFrame then return end
	local frame = Skin.CreatePanelWindow('Trainer', CloseTrainer)
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetFrameStrata('HIGH')
	trainerFrame = frame
	Skin.MakeDraggable(frame, 'trainer', 'TOPLEFT', Pixel.Scale(PANEL_SLOT_X), Pixel.Scale(PANEL_SLOT_Y), 'ClassTrainerFrame')

	frame.filterDD = Skin.CreateDropdown(frame, {
		{ label = 'Available',     filter = FILTER_AVAILABLE },
		{ label = 'All',           filter = FILTER_ALL },
		{ label = 'Unavailable',   filter = FILTER_UNAVAILABLE },
		{ label = 'Already Known', filter = FILTER_KNOWN },
	}, function(item)
		activeFilter = item.filter
		RefreshContent()
		frame.scroll:SetVerticalScroll(0)
	end, 120)
	frame.filterDD:SetPoint('TOPRIGHT', Pixel.Scale(-12), Pixel.Scale(-40))

	frame.searchBox = Skin.CreateSearchBox(frame, 160, function(text)
		searchText = text
		RefreshContent()
		frame.scroll:SetVerticalScroll(0)
	end)
	frame.searchBox:SetPoint('RIGHT', frame.filterDD, 'LEFT', Pixel.Scale(-8), 0)

	frame.countText = frame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(frame.countText, 10, FONT, '')
	frame.countText:SetPoint('TOPLEFT', Pixel.Scale(14), Pixel.Scale(-48))
	Painter.Text(frame.countText, 'skinLabel')

	local contentArea = CreateFrame('Frame', nil, frame)
	contentArea:SetPoint('TOPLEFT', 0, Pixel.Scale(-68))
	contentArea:SetPoint('BOTTOMRIGHT', 0, Pixel.Scale(56))
	frame.scroll, frame.child = Skin.CreateScrollArea(contentArea, ROW_HEIGHT, SCROLL_PAD)
	frame.emptyText = Skin.CreateEmptyText(frame, contentArea)

	frame.moneyText = frame:CreateFontString(nil, 'OVERLAY')
	Pixel.ApplyFont(frame.moneyText, 11, FONT, '')
	frame.moneyText:SetPoint('BOTTOMLEFT', Pixel.Scale(16), Pixel.Scale(20))
	Painter.Text(frame.moneyText, 'skinText')

	frame.trainAllBtn = Skin.SmallButton(frame, TRAIN_ALL_W, BUTTON_H, 'Train All')
	frame.trainAllBtn:SetScript('OnClick', BUI.Profiler.Script('Skin.Trainer trainAll OnClick', TrainAll))
	frame.trainAllBtn:SetPoint('BOTTOMRIGHT', Pixel.Scale(-12), Pixel.Scale(14))
	frame.trainAllBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
end

local function EmptyMessage()
	if searchText ~= '' then return 'No matching services.' end
	if activeFilter == FILTER_AVAILABLE then return 'Nothing available to learn.' end
	return 'No services found.'
end

RefreshContent = function()
	if not trainerFrame or not trainerFrame:IsShown() then return end
	trainerFrame.titleText:SetText(UnitName('npc') or 'Trainer')
	trainerFrame.moneyText:SetText(GetCoinTextureString(GetMoney()))

	ScanServices()
	local shown = PopulateRows(trainerFrame.child)
	local count = shown .. '/' .. #services
	if IsTradeskillTrainer() then
		local rank, maxRank = GetTrainerTradeskillRankValues()
		if maxRank > 0 then count = count .. '  ·  ' .. TRAINER_REQ_SKILL_RANK:format(rank, maxRank) end
	end
	trainerFrame.countText:SetText(count)
	trainerFrame.emptyText:SetShown(shown == 0)
	trainerFrame.emptyText:SetText(EmptyMessage())

	local queue, totalCost = AvailableServices()
	local canAfford = GetMoney() >= totalCost
	trainerFrame.trainAllBtn:SetShown(#queue > 0)
	trainerFrame.trainAllBtn:SetAlpha(canAfford and 1 or DIMMED_ALPHA)
	trainerFrame.trainAllBtn:EnableMouse(canAfford)
end

local function OnLiveEvent()
	if trainerFrame and trainerFrame:IsShown() then
		Skin.SuppressBlizzardFrame(ClassTrainerFrame)
		RefreshContent()
	end
end

local function OpenTrainer(blizzard)
	BuildFrame()
	ShowEveryService()
	activeFilter = FILTER_AVAILABLE
	trainerFrame.filterDD.label:SetText('Available')
	searchText = ''
	trainerFrame.searchBox.editBox:SetText('')
	trainerFrame.searchBox.hint:Show()
	trainerFrame:Show()
	Skin.SuppressBlizzardFrame(blizzard)
	for _, event in ipairs(LIVE_EVENTS) do BUI.Events:Register(event, 'Skinning.Trainer', OnLiveEvent) end
	After('Skin.Trainer first refresh', 0, function()
		RefreshContent()
		trainerFrame.scroll:SetVerticalScroll(0)
	end)
end

local function CloseTrainerSkin()
	for _, event in ipairs(LIVE_EVENTS) do BUI.Events:Unregister(event, 'Skinning.Trainer') end
	if trainerFrame then trainerFrame:Hide() end
	SetTrainerServiceTypeFilter('used', false)
	Skin.RestoreBlizzardFrame(ClassTrainerFrame)
	wipe(services)
end

context.Window('ClassTrainerFrame', {
	show = OpenTrainer,
	install = function(blizzard)
		blizzard:HookScript('OnHide', BUI.Profiler.Wrap('Skin.Trainer blizzard hide', context.Guard(CloseTrainerSkin)))
	end,
})

context.OnDisable(function()
	Skin.ReleasePanelSlot('ClassTrainerFrame')
	if trainerFrame and trainerFrame:IsShown() then CloseTrainerSkin() end
end)
