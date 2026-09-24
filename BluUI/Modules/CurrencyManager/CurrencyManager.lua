local _, BUI = ...
local PoolGet, PoolHideFrom = BUI.Tools.PoolGet, BUI.Tools.PoolHideFrom

local Pixel  = BUI.Pixel
local BUILib = BluUI.BUILibClient
local Widget = BUILib.Widget
local Colors = BUILib.Colors
local Controls = BUILib.Controls
local FONT   = BUILib.Font

local PANEL_W       = 360
local PANEL_H       = 460
local ROW_H         = 26
local ICON_SIZE     = 22
local HEADER_H      = 22
local FALLBACK_ICON = 134400

local TRANSFER_FAILURE_TEXT = {
    [Enum.AccountCurrencyTransferResult.MaxQuantity]              = CURRENCY_TRANSFER_DISABLED_MAX_QUANTITY,
    [Enum.AccountCurrencyTransferResult.NoValidSourceCharacter]   = CURRENCY_TRANSFER_DISABLED_NO_VALID_SOURCES,
    [Enum.AccountCurrencyTransferResult.CannotUseCurrency]        = CURRENCY_TRANSFER_DISABLED_UNMET_REQUIREMENTS,
    [Enum.AccountCurrencyTransferResult.TransactionInProgress]    = CURRENCY_TRANSFER_IN_PROGRESS,
    [Enum.AccountCurrencyTransferResult.CurrencyTransferDisabled] = ERR_CURRENCY_TRANSFER_DISABLED,
}

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
    local anchor = (panel and panel:IsShown()) and panel or BUI.Skinning.GetCharacterFrame() or CharacterFrame
    CurrencyTransferMenu:ClearAllPoints()
    CurrencyTransferMenu:SetPoint('TOPLEFT', anchor, 'TOPRIGHT', 5, 0)
    CurrencyTransferMenu:SetFrameStrata('FULLSCREEN_DIALOG')
end

local function OpenWarbandTransfer(currencyID, isRetry)
    if InCombatLockdown() or not EnsureTokenUI() or not CurrencyTransferMenu then return end
    if not C_CurrencyInfo.IsAccountCharacterCurrencyDataReady() then
        C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()
        if not isRetry then
            C_Timer.After(0.5, function() OpenWarbandTransfer(currencyID, true) end)
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
        CurrencyTransferMenu:HookScript('OnShow', PositionTransferMenu)
    end
    CurrencyTransferMenu:TriggerEvent(CurrencyTransferMenuMixin.Event.CurrencyTransferRequested, currencyID)
    C_Timer.After(0, PositionTransferMenu)
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
    Controls.ContextMenu(items, { atCursor = true, width = 240 })
end

local function CreateRow(parent)
    local row = CreateFrame('Button', nil, parent, 'BackdropTemplate')
    row:SetHeight(Pixel.Scale(ROW_H))
    row:SetBackdrop({
        bgFile = 'Interface\\Buttons\\WHITE8x8',
        edgeFile = 'Interface\\Buttons\\WHITE8x8',
        edgeSize = 1,
    })
    row:SetBackdropColor(0.07, 0.07, 0.08, 0.6)
    row:SetBackdropBorderColor(0.13, 0.13, 0.15, 1)
    row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

    local iconBackground = CreateFrame('Frame', nil, row, 'BackdropTemplate')
    iconBackground:SetSize(Pixel.Scale(ICON_SIZE + 2), Pixel.Scale(ICON_SIZE + 2))
    iconBackground:SetPoint('LEFT', Pixel.Scale(4), 0)
    iconBackground:SetBackdrop({
        bgFile = 'Interface\\Buttons\\WHITE8x8',
        edgeFile = 'Interface\\Buttons\\WHITE8x8',
        edgeSize = 1,
    })
    iconBackground:SetBackdropColor(0, 0, 0, 1)
    iconBackground:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)

    local icon = iconBackground:CreateTexture(nil, 'ARTWORK')
    icon:SetSize(Pixel.Scale(ICON_SIZE), Pixel.Scale(ICON_SIZE))
    icon:SetPoint('CENTER')
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local quantityText = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(quantityText, 11, FONT, '')
    quantityText:SetPoint('RIGHT', Pixel.Scale(-6), 0)
    quantityText:SetTextColor(1, 1, 1, 1)
    quantityText:SetJustifyH('RIGHT')
    row.qtyText = quantityText

    local warband = row:CreateTexture(nil, 'OVERLAY')
    warband:SetSize(Pixel.Scale(18), Pixel.Scale(18))
    warband:SetPoint('RIGHT', quantityText, 'LEFT', Pixel.Scale(-8), 0)
    warband:SetAtlas('warbands-transferable-icon')
    row.warbandIcon = warband

    local name = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(name, 11, FONT, '')
    name:SetPoint('LEFT', iconBackground, 'RIGHT', Pixel.Scale(8), 0)
    name:SetPoint('RIGHT', quantityText, 'LEFT', Pixel.Scale(-8), 0)
    name:SetJustifyH('LEFT')
    name:SetWordWrap(false)
    row.nameText = name

    row:SetScript('OnEnter', function(self)
        self:SetBackdropBorderColor(Colors.GetAccent())
        GameTooltip:SetOwner(self, 'ANCHOR_NONE')
        GameTooltip:SetPoint('TOPRIGHT', self, 'TOPLEFT', -6, 0)
        GameTooltip:SetCurrencyToken(self._listIndex)
        GameTooltip:Show()
    end)
    row:SetScript('OnLeave', function(self)
        self:SetBackdropBorderColor(0.13, 0.13, 0.15, 1)
        GameTooltip:Hide()
    end)
    row:SetScript('OnClick', function(self, mouseButton)
        GameTooltip:Hide()
        if mouseButton == 'RightButton' then
            ShowRowMenu(self)
        elseif self._isTransferable then
            OpenWarbandTransfer(self._currencyID)
        end
    end)

    return row
end

local function BuildPanel()
    if panel then return end

    panel = Widget.New(UIParent, 'Frame', nil, {
        bg = Colors.bg.dark,
        border = Colors.border.light,
        size = { PANEL_W, PANEL_H },
    }).frame
    panel:SetFrameStrata('HIGH')
    panel:SetFrameLevel(50)
    panel:SetClampedToScreen(false)
    panel:Hide()

    BUI.Skinning.CreateTitleBar(panel, 'Currency', 36, function() slide.Close(true) end)
    panel.searchBox = BUI.Skinning.CreateSearchBox(panel, PANEL_W - 24, function(text)
        searchText = text
        RefreshContent()
    end)
    panel.searchBox:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-44))

    local moneyHeader = CreateFrame('Frame', nil, panel, 'BackdropTemplate')
    moneyHeader:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-78))
    moneyHeader:SetPoint('TOPRIGHT', Pixel.Scale(-12), Pixel.Scale(-78))
    moneyHeader:SetHeight(Pixel.Scale(28))
    moneyHeader:SetBackdrop({
        bgFile = 'Interface\\Buttons\\WHITE8x8',
        edgeFile = 'Interface\\Buttons\\WHITE8x8',
        edgeSize = 1,
    })
    moneyHeader:SetBackdropColor(0.08, 0.08, 0.1, 0.7)
    moneyHeader:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)

    local walletLabel = moneyHeader:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(walletLabel, 11, FONT, '')
    walletLabel:SetPoint('LEFT', Pixel.Scale(8), 0)
    walletLabel:SetTextColor(0.6, 0.6, 0.6)
    walletLabel:SetText('Wallet')

    local hideButton = CreateFrame('Button', nil, moneyHeader)
    hideButton:SetPoint('LEFT', walletLabel, 'RIGHT', Pixel.Scale(14), 0)
    hideButton:SetSize(Pixel.Scale(90), Pixel.Scale(20))
    local hideText = hideButton:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(hideText, 11, FONT, '')
    hideText:SetPoint('LEFT')
    hideText:SetText('Hide Unused')
    local function PaintHideButton()
        if hideUnused then
            hideText:SetTextColor(Colors.GetAccent())
        else
            hideText:SetTextColor(0.45, 0.45, 0.5, 1)
        end
    end
    PaintHideButton()
    hideButton:SetScript('OnEnter', function() hideText:SetAlpha(0.85) end)
    hideButton:SetScript('OnLeave', function() hideText:SetAlpha(1) end)
    hideButton:SetScript('OnClick', function()
        hideUnused = not hideUnused
        PaintHideButton()
        RefreshContent()
    end)

    local moneyText = moneyHeader:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(moneyText, 12, FONT, '')
    moneyText:SetPoint('RIGHT', Pixel.Scale(-8), 0)
    moneyText:SetJustifyH('RIGHT')
    moneyText:SetTextColor(1, 1, 1, 1)
    panel.moneyText = moneyText

    local scrollArea = CreateFrame('Frame', nil, panel)
    scrollArea:SetPoint('TOPLEFT', Pixel.Scale(8), Pixel.Scale(-114))
    scrollArea:SetPoint('BOTTOMRIGHT', Pixel.Scale(-8), Pixel.Scale(12))
    panel.scroll, panel.child = BUI.Skinning.CreateScrollArea(scrollArea, ROW_H, 4)

    panel.emptyText = panel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panel.emptyText, 11, FONT, '')
    panel.emptyText:SetPoint('CENTER', scrollArea)
    panel.emptyText:SetTextColor(0.4, 0.4, 0.4)
    panel.emptyText:Hide()
end

local function ExpandAllCurrencyHeaders()
    local listIndex = 1
    while listIndex <= C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(listIndex)
        if info and info.isHeader and not info.isHeaderExpanded then
            C_CurrencyInfo.ExpandCurrencyList(listIndex, true)
        end
        listIndex = listIndex + 1
    end
end

local function CreateHeader(parent)
    return BUI.Skinning.CreateListHeader(parent, HEADER_H)
end

RefreshContent = function()
    if not panel or not panel:IsShown() then return end

    panel.moneyText:SetText(GetCoinTextureString(GetMoney()))

    ExpandAllCurrencyHeaders()
    local headerIndex, rowIndex, y = 0, 0, 0
    local activeHeader, headerPlaced

    for listIndex = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(listIndex)
        if info and info.isHeader then
            if activeHeader and not headerPlaced then activeHeader:Hide() end
            headerIndex = headerIndex + 1
            activeHeader = PoolGet(headerPool, headerIndex, CreateHeader, panel.child)
            activeHeader.text:SetText(info.name)
            headerPlaced = false
        elseif info then
            local matches = searchText == '' or info.name:lower():find(searchText, 1, true)
            if hideUnused and (info.isTypeUnused or info.quantity == 0) then matches = false end
            if matches then
                if activeHeader and not headerPlaced then
                    activeHeader:ClearAllPoints()
                    activeHeader:SetPoint('TOPLEFT', 0, Pixel.Scale(-y))
                    activeHeader:SetPoint('RIGHT', panel.child, 'RIGHT', Pixel.Scale(-2), 0)
                    activeHeader:Show()
                    headerPlaced = true
                    y = y + HEADER_H + 2
                end
                rowIndex = rowIndex + 1
                local row = PoolGet(rowPool, rowIndex, CreateRow, panel.child)
                row:ClearAllPoints()
                row:SetPoint('TOPLEFT', 0, Pixel.Scale(-y))
                row:SetPoint('RIGHT', panel.child, 'RIGHT', Pixel.Scale(-2), 0)

                row.icon:SetTexture(info.iconFileID or FALLBACK_ICON)

                local displayName = info.name
                if info.isAccountWide then
                    displayName = displayName .. '  |cff666666[|r|cffffd200A|r|cff666666]|r'
                end
                row.nameText:SetText(displayName)
                local color = ITEM_QUALITY_COLORS[info.quality] or ITEM_QUALITY_COLORS[1]
                row.nameText:SetTextColor(color.r, color.g, color.b)
                row.nameText:SetAlpha(info.isTypeUnused and 0.5 or 1)

                if info.isAccountTransferable then
                    row.warbandIcon:SetAlpha((info.transferPercentage or 100) < 100 and 0.55 or 1)
                    row.warbandIcon:Show()
                else
                    row.warbandIcon:Hide()
                end

                local quantityLabel = BreakUpLargeNumbers(info.quantity)
                if info.maxQuantity > 0 then
                    quantityLabel = quantityLabel .. ' |cff666666/|r ' .. BreakUpLargeNumbers(info.maxQuantity)
                end
                if info.canEarnPerWeek and info.maxWeeklyQuantity > 0 then
                    quantityLabel = quantityLabel .. '  |cff44bbff('
                        .. BreakUpLargeNumbers(info.quantityEarnedThisWeek)
                        .. '/' .. BreakUpLargeNumbers(info.maxWeeklyQuantity) .. ' wk)|r'
                end
                row.qtyText:SetText(quantityLabel)

                row._listIndex = listIndex
                row._currencyID = info.currencyID
                row._name = info.name
                row._isTransferable = info.isAccountTransferable
                row._tracked = info.isShowInBackpack
                row._unused = info.isTypeUnused
                row:Show()
                y = y + ROW_H + 2
            end
        end
    end
    if activeHeader and not headerPlaced then activeHeader:Hide() end

    PoolHideFrom(headerPool, headerIndex + 1)
    PoolHideFrom(rowPool, rowIndex + 1)
    panel.child:SetHeight(Pixel.Scale(math.max(1, y)))
    panel.scroll:SetVerticalScroll(0)

    panel.emptyText:SetShown(rowIndex == 0)
    panel.emptyText:SetText(searchText ~= '' and 'No matching currencies.' or 'No currencies.')
end

local ThrottledRefresh = BUI.Dispatcher.NewDelayed(function() RefreshContent() end, 0.3)

slide = BUI.SlidePanel.New({
    skin = 'currencyManager',
    width = PANEL_W,
    hiddenX = -PANEL_W,
    panel = function() return panel end,
    build = BuildPanel,
    onOpen = function()
        C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()
        RefreshContent()
    end,
})

function BUI.CurrencyManager.Toggle()
    slide.Toggle()
end

function BUI.CurrencyManager.IsOpen()
    return slide.IsOpen()
end

local function OnCurrencyEvent()
    if slide.IsOpen() then ThrottledRefresh() end
end

BUI.Events:OnLogin('CurrencyManager', function()
    CharacterFrame:HookScript('OnHide', function() slide.Close(true) end)

    BUI.Events:Register('CURRENCY_DISPLAY_UPDATE', 'CurrencyManager', OnCurrencyEvent)
    BUI.Events:Register('PLAYER_MONEY',            'CurrencyManager', OnCurrencyEvent)

    BUI.Skinning.OnToggle('currencyManager', function(enabled)
        if not enabled then slide.Close(true) end
    end)
    BUI.Skinning.RegisterSkin('currencyManager', {
        name = 'Currency Manager',
        description = 'Currency list beside the Character frame.',
        icon = 'Interface\\Icons\\INV_Misc_Coin_01',
    })
end)
