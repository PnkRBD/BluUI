local _, BUI = ...
local PoolGet, PoolHideFrom = BUI.Tools.PoolGet, BUI.Tools.PoolHideFrom
local Pixel   = BUI.Pixel
local Painter = BUI.Painter
local Skin    = BUI.Skinning

local BUILib   = BluUI.BUILibClient
local Colors   = BUILib.Colors
local FONT     = BUILib.Font

local PANEL_W       = 360
local ROW_H         = 26
local ROW_GAP       = 4
local ICON_SIZE     = 20
local HEADER_H      = 22
local WALLET_H      = 28
local FALLBACK_ICON = 134400
local WEEKLY_COLOR  = '44bbff'
local ACCOUNT_COLOR = 'ffd200'

local TRANSFER_FAILURE_TEXT = {
    [Enum.AccountCurrencyTransferResult.MaxQuantity]              = CURRENCY_TRANSFER_DISABLED_MAX_QUANTITY,
    [Enum.AccountCurrencyTransferResult.NoValidSourceCharacter]   = CURRENCY_TRANSFER_DISABLED_NO_VALID_SOURCES,
    [Enum.AccountCurrencyTransferResult.CannotUseCurrency]        = CURRENCY_TRANSFER_DISABLED_UNMET_REQUIREMENTS,
    [Enum.AccountCurrencyTransferResult.TransactionInProgress]    = CURRENCY_TRANSFER_IN_PROGRESS,
    [Enum.AccountCurrencyTransferResult.CurrencyTransferDisabled] = ERR_CURRENCY_TRANSFER_DISABLED,
}

local context = Skin.Define('currencyManager', {
    name = 'Currency Manager',
    description = 'Currency list beside the Character frame.',
    icon = 'Interface\\Icons\\INV_Misc_Coin_01',
    newLook = true,
})

BUI.CurrencyManager = {}

local panel, slide
local rowPool, headerPool = {}, {}
local searchText = ''
local hideUnused = false
local RefreshContent

local function EnsureTokenUI()
    if not TokenFrame then C_AddOns.LoadAddOn('Blizzard_TokenUI') end
    return TokenFrame ~= nil
end

local function InsertChatLink(link)
    if not link or ChatEdit_InsertLink(link) then return end
    local editBox = ChatEdit_ChooseBoxForSend()
    ChatEdit_ActivateChat(editBox)
    editBox:Insert(link)
end

local function SetTracked(listIndex, tracked)
    if not EnsureTokenUI() then return end
    if TokenFrame:SetTokenWatched(listIndex, tracked) then RefreshContent() end
end

local transferMenuHooked = false

local function PositionTransferMenu()
    local anchor = panel:IsShown() and panel or Skin.GetCharacterFrame() or CharacterFrame
    CurrencyTransferMenu:ClearAllPoints()
    CurrencyTransferMenu:SetPoint('TOPLEFT', anchor, 'TOPRIGHT', 5, 0)
    CurrencyTransferMenu:SetFrameStrata('FULLSCREEN_DIALOG')
end

local function OpenWarbandTransfer(currencyID, isRetry)
    if InCombatLockdown() or not EnsureTokenUI() then return end
    if not C_CurrencyInfo.IsAccountCharacterCurrencyDataReady() then
        C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()
        if not isRetry then
            BUI.Profiler.After('CurrencyManager.CurrencyManager transfer retry', 0.5, function() OpenWarbandTransfer(currencyID, true) end)
        end
        return
    end
    local canTransfer, failureReason = C_CurrencyInfo.CanTransferCurrency(currencyID)
    if not canTransfer then
        UIErrorsFrame:AddMessage(TRANSFER_FAILURE_TEXT[failureReason] or CURRENCY_TRANSFER_DISABLED_NO_VALID_SOURCES, 1, 0.3, 0.3, 1)
        return
    end
    if not transferMenuHooked then
        transferMenuHooked = true
        CurrencyTransferMenu:HookScript('OnShow', BUI.Profiler.Wrap('CurrencyManager.CurrencyManager transfer menu shown', PositionTransferMenu))
    end
    CurrencyTransferMenu:TriggerEvent(CurrencyTransferMenuMixin.Event.CurrencyTransferRequested, currencyID)
    BUI.Profiler.After('CurrencyManager.CurrencyManager transfer menu position', 0, PositionTransferMenu)
end

local function ShowRowMenu(row)
    local listIndex = row._listIndex
    local items = {
        { title = true, text = row._name },
        {
            text = 'Track on Backpack',
            checked = row._tracked,
            callback = function() SetTracked(listIndex, not row._tracked) end,
        },
        {
            text = 'Mark as Unused',
            checked = row._unused,
            callback = function()
                C_CurrencyInfo.SetCurrencyUnused(listIndex, not row._unused)
                RefreshContent()
            end,
        },
    }
    if row._isTransferable then
        items[#items + 1] = {
            text = 'Warband Transfer',
            callback = function() OpenWarbandTransfer(row._currencyID) end,
        }
    end
    items[#items + 1] = { separator = true }
    items[#items + 1] = {
        text = 'Link in Chat',
        callback = function() InsertChatLink(C_CurrencyInfo.GetCurrencyListLink(listIndex)) end,
    }
    Skin.ContextMenu(items, { atCursor = true, width = 240 })
end

local RowEnter = BUI.Profiler.Script('CurrencyManager.CurrencyManager row OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_NONE')
    GameTooltip:SetPoint('TOPRIGHT', self, 'TOPLEFT', -6, 0)
    GameTooltip:SetCurrencyToken(self._listIndex)
    GameTooltip:Show()
end)

local RowClick = BUI.Profiler.Script('CurrencyManager.CurrencyManager row OnClick', function(self, mouseButton)
    GameTooltip:Hide()
    if mouseButton == 'RightButton' then
        ShowRowMenu(self)
    elseif self._isTransferable then
        OpenWarbandTransfer(self._currencyID)
    end
end)

local function CreateRow(parent)
    local row = CreateFrame('Button', nil, parent)
    row:SetHeight(Pixel.Scale(ROW_H))
    row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    row:SetScript('OnEnter', RowEnter)
    row:SetScript('OnLeave', GameTooltip_Hide)
    row:SetScript('OnClick', RowClick)
    Skin.CardRow(row)

    local icon = row:CreateTexture(nil, 'ARTWORK')
    icon:SetSize(Pixel.Scale(ICON_SIZE), Pixel.Scale(ICON_SIZE))
    icon:SetPoint('LEFT', Pixel.Scale(5), 0)
    Skin.CropIcon(icon)
    Skin.TipIconFrame(row, icon)
    row.icon = icon

    local quantityText = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(quantityText, 11, FONT, '')
    quantityText:SetPoint('RIGHT', Pixel.Scale(-8), 0)
    quantityText:SetJustifyH('RIGHT')
    Painter.Text(quantityText, 'skinText')
    row.qtyText = quantityText

    local warband = row:CreateTexture(nil, 'OVERLAY')
    warband:SetSize(Pixel.Scale(18), Pixel.Scale(18))
    warband:SetPoint('RIGHT', quantityText, 'LEFT', Pixel.Scale(-8), 0)
    warband:SetAtlas('warbands-transferable-icon')
    row.warbandIcon = warband

    local name = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(name, 11, FONT, '')
    name:SetPoint('LEFT', icon, 'RIGHT', Pixel.Scale(8), 0)
    name:SetPoint('RIGHT', warband, 'LEFT', Pixel.Scale(-8), 0)
    name:SetJustifyH('LEFT')
    name:SetWordWrap(false)
    row.nameText = name
    return row
end

local function PaintHideButton(text)
    if hideUnused then
        text:SetTextColor(Colors.GetAccent())
    else
        text:SetTextColor(Painter.Color('skinLabel'))
    end
end

local function BuildWallet()
    local wallet = CreateFrame('Frame', nil, panel, 'BackdropTemplate')
    wallet:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-78))
    wallet:SetPoint('TOPRIGHT', Pixel.Scale(-12), Pixel.Scale(-78))
    wallet:SetHeight(Pixel.Scale(WALLET_H))
    Painter.Custom(wallet, Skin.PaintCardBackdrop)

    local walletLabel = wallet:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(walletLabel, 11, FONT, '')
    walletLabel:SetPoint('LEFT', Pixel.Scale(8), 0)
    Painter.Text(walletLabel, 'skinLabel')
    walletLabel:SetText('Wallet')

    local hideButton = CreateFrame('Button', nil, wallet)
    hideButton:SetPoint('LEFT', walletLabel, 'RIGHT', Pixel.Scale(14), 0)
    hideButton:SetSize(Pixel.Scale(90), Pixel.Scale(20))
    local hideText = hideButton:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(hideText, 11, FONT, '')
    hideText:SetPoint('LEFT')
    hideText:SetText('Hide Unused')
    Painter.Custom(hideText, PaintHideButton)
    hideButton:SetScript('OnEnter', BUI.Profiler.Script('CurrencyManager.CurrencyManager hideButton OnEnter', function() hideText:SetAlpha(0.85) end))
    hideButton:SetScript('OnLeave', BUI.Profiler.Script('CurrencyManager.CurrencyManager hideButton OnLeave', function() hideText:SetAlpha(1) end))
    hideButton:SetScript('OnClick', BUI.Profiler.Script('CurrencyManager.CurrencyManager hideButton OnClick', function()
        hideUnused = not hideUnused
        PaintHideButton(hideText)
        RefreshContent()
        panel.scroll:SetVerticalScroll(0)
    end))

    local moneyText = wallet:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(moneyText, 12, FONT, '')
    moneyText:SetPoint('RIGHT', Pixel.Scale(-8), 0)
    moneyText:SetJustifyH('RIGHT')
    Painter.Text(moneyText, 'skinText')
    panel.moneyText = moneyText
end

local function BuildPanel()
    if panel then return end
    panel = Skin.CreatePanelWindow('Currency', function() slide.Close(true) end)
    panel.searchBox = Skin.CreateSearchBox(panel, PANEL_W - 24, function(text)
        searchText = text
        RefreshContent()
        panel.scroll:SetVerticalScroll(0)
    end)
    panel.searchBox:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-44))
    BuildWallet()

    local area
    area, panel.scroll, panel.child = Skin.CreateListArea(panel, 114, ROW_H)
    panel.emptyText = Skin.CreateEmptyText(panel, area)
end

local function ExpandAllCurrencyHeaders()
    local listIndex = 1
    while listIndex <= C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(listIndex)
        if info.isHeader and not info.isHeaderExpanded then C_CurrencyInfo.ExpandCurrencyList(listIndex, true) end
        listIndex = listIndex + 1
    end
end

local function CreateHeader(parent)
    return Skin.CreateListHeader(parent, HEADER_H)
end

local function PlaceRow(frame, y)
    frame:ClearAllPoints()
    frame:SetPoint('TOPLEFT', panel.child, 'TOPLEFT', 0, -y)
    frame:SetPoint('TOPRIGHT', panel.child, 'TOPRIGHT', 0, -y)
    frame:Show()
end

local function QuantityLabel(info, dimHex)
    local label = BreakUpLargeNumbers(info.quantity)
    if info.maxQuantity > 0 then
        label = label .. ' |cff' .. dimHex .. '/|r ' .. BreakUpLargeNumbers(info.maxQuantity)
    end
    if info.canEarnPerWeek and info.maxWeeklyQuantity > 0 then
        label = ('%s  |cff%s(%s/%s wk)|r'):format(label, WEEKLY_COLOR,
            BreakUpLargeNumbers(info.quantityEarnedThisWeek), BreakUpLargeNumbers(info.maxWeeklyQuantity))
    end
    return label
end

local function FillRow(row, info, listIndex, dimHex)
    row.icon:SetTexture(info.iconFileID or FALLBACK_ICON)
    local name = info.name
    if info.isAccountWide then name = ('%s  |cff%s[|r|cff%sA|r|cff%s]|r'):format(name, dimHex, ACCOUNT_COLOR, dimHex) end
    row.nameText:SetText(name)
    local color = ITEM_QUALITY_COLORS[info.quality] or ITEM_QUALITY_COLORS[1]
    row.nameText:SetTextColor(color.r, color.g, color.b)
    row.nameText:SetAlpha(info.isTypeUnused and 0.5 or 1)
    row.warbandIcon:SetShown(info.isAccountTransferable)
    row.warbandIcon:SetAlpha((info.transferPercentage or 100) < 100 and 0.55 or 1)
    row.qtyText:SetText(QuantityLabel(info, dimHex))

    row._listIndex = listIndex
    row._currencyID = info.currencyID
    row._name = info.name
    row._isTransferable = info.isAccountTransferable
    row._tracked = info.isShowInBackpack
    row._unused = info.isTypeUnused
end

RefreshContent = function()
    if not panel or not panel:IsShown() then return end
    panel.moneyText:SetText(GetCoinTextureString(GetMoney()))

    local dimHex = BUI.Hex(Painter.Color('skinLabel'))
    local headerIndex, rowIndex, y = 0, 0, 0
    local pendingHeader
    for listIndex = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(listIndex)
        if info.isHeader then
            pendingHeader = info.name
        elseif (searchText == '' or info.name:lower():find(searchText, 1, true))
            and not (hideUnused and (info.isTypeUnused or info.quantity == 0)) then
            if pendingHeader then
                headerIndex = headerIndex + 1
                local header = PoolGet(headerPool, headerIndex, CreateHeader, panel.child)
                header.text:SetText(pendingHeader)
                PlaceRow(header, y)
                y = y + HEADER_H + ROW_GAP
                pendingHeader = nil
            end
            rowIndex = rowIndex + 1
            local row = PoolGet(rowPool, rowIndex, CreateRow, panel.child)
            FillRow(row, info, listIndex, dimHex)
            PlaceRow(row, y)
            y = y + ROW_H + ROW_GAP
        end
    end

    PoolHideFrom(headerPool, headerIndex + 1)
    PoolHideFrom(rowPool, rowIndex + 1)
    panel.child:SetHeight(math.max(1, y))
    panel.emptyText:SetShown(rowIndex == 0)
    panel.emptyText:SetText(searchText ~= '' and 'No matching currencies.' or 'No currencies.')
end

local ThrottledRefresh = BUI.Dispatcher.NewDelayed(function() RefreshContent() end, 0.3, 'Currency refresh')

local function OnCurrencyEvent()
    ThrottledRefresh()
end

local EVENTS = { 'CURRENCY_DISPLAY_UPDATE', 'PLAYER_MONEY' }

slide = BUI.SlidePanel.New({
    skin = 'currencyManager',
    width = PANEL_W,
    hiddenX = -PANEL_W,
    panel = function() return panel end,
    build = BuildPanel,
    onOpen = function()
        for _, event in ipairs(EVENTS) do BUI.Events:Register(event, 'CurrencyManager', OnCurrencyEvent) end
        C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()
        ExpandAllCurrencyHeaders()
        RefreshContent()
        panel.scroll:SetVerticalScroll(0)
    end,
    onClose = function()
        for _, event in ipairs(EVENTS) do BUI.Events:Unregister(event, 'CurrencyManager') end
    end,
})

function BUI.CurrencyManager.Toggle()
    slide.Toggle()
end

function BUI.CurrencyManager.IsOpen()
    return slide.IsOpen()
end

CharacterFrame:HookScript('OnHide', BUI.Profiler.Wrap('CurrencyManager.CurrencyManager character hide', function() slide.Close(true) end))
context.OnDisable(function() slide.Close(true) end)
