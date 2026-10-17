local _, BUI = ...

local Datatext = BUI.Datatext
local DIM, RESET = Datatext.DIM, Datatext.RESET

local BAR_ICON = '|T%s:12:12:0:0:64:64:5:59:5:59|t '
local TIP_ICON = '|T%s:14:14:0:0:64:64:5:59:5:59|t  %s'

local tracked, trackedCount = {}, 0
local parts = {}
local signature = ''

local function Read()
    local index = 1
    while true do
        local info = C_CurrencyInfo.GetBackpackCurrencyInfo(index)
        if not info then break end
        local currency = tracked[index]
        if not currency then
            currency = {}
            tracked[index] = currency
        end
        currency.name, currency.quantity, currency.icon, currency.id = info.name, info.quantity, info.iconFileID, info.currencyTypesID
        parts[index] = info.currencyTypesID .. '=' .. info.quantity
        index = index + 1
    end
    trackedCount = index - 1
    for partIndex = #parts, index, -1 do parts[partIndex] = nil end
    local newSignature = table.concat(parts, ';')
    if newSignature ~= signature then
        signature = newSignature
        return true
    end
end

local DispatchRead = BUI.Dispatcher.New(function()
    if Read() then Datatext.Refresh('currency') end
end, 'Datatext.Currency')

Datatext.Register('currency', {
    name = 'Currencies', show = 'showCurrency', label = 'Cur:',
    events = { 'CURRENCY_DISPLAY_UPDATE', 'PLAYER_ENTERING_WORLD' },
    OnActivate = Read,
    OnEvent = DispatchRead,
    build = function(config, valueHex, self)
        local label = Datatext.Label(config, self)
        if trackedCount == 0 then return label .. DIM .. 'None' .. RESET end
        local text = label
        for trackedIndex = 1, trackedCount do
            local currency = tracked[trackedIndex]
            if trackedIndex > 1 then text = text .. ' ' end
            text = text .. string.format(BAR_ICON, currency.icon) .. Datatext.Colored(BreakUpLargeNumbers(currency.quantity), valueHex)
        end
        return text
    end,
    OnClick = function(_, button)
        if button ~= 'LeftButton' or InCombatLockdown() then return end
        Datatext.OpenCurrencyUI()
        return true
    end,
    OnEnter = function(hit)
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine('Tracked Currencies', 1, 1, 1)
        if trackedCount == 0 then
            tooltip:AddLine('Right-click a currency in the Currencies panel and pick Track on Backpack', 0.5, 0.5, 0.5)
        end
        for trackedIndex = 1, trackedCount do
            local currency = tracked[trackedIndex]
            local right = BreakUpLargeNumbers(currency.quantity)
            local cap = BUI.Currency.Cap(currency.id)
            if cap > 0 then
                right = right .. ' / ' .. BreakUpLargeNumbers(cap)
            end
            tooltip:AddDoubleLine(string.format(TIP_ICON, currency.icon, currency.name), right, 0.85, 0.85, 0.88, 1, 1, 1)
        end
        tooltip:AddLine(' ')
        tooltip:AddLine('Left-Click  |cffffffffCurrencies|r', 1, 0.82, 0)
        tooltip:Show()
    end,
    sample = function(config, label, colorize) return label .. string.format(BAR_ICON, 134400) .. colorize('1,250') end,
})
