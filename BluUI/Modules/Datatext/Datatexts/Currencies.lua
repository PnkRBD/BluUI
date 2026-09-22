local _, BUI = ...

local Datatext = BUI.Datatext
local DIM, RESET = Datatext.DIM, Datatext.RESET

local BAR_ICON = '|T%s:12:12:0:0:64:64:5:59:5:59|t '
local TIP_ICON = '|T%s:14:14:0:0:64:64:5:59:5:59|t  %s'

local tracked = {}
local signature = ''

local function Read()
    wipe(tracked)
    local parts = {}
    local index = 1
    while true do
        local info = C_CurrencyInfo.GetBackpackCurrencyInfo(index)
        if not info or not info.name then break end
        tracked[index] = { name = info.name, quantity = info.quantity or 0, icon = info.iconFileID, id = info.currencyTypesID }
        parts[index] = (info.currencyTypesID or 0) .. '=' .. (info.quantity or 0)
        index = index + 1
    end
    local newSignature = table.concat(parts, ';')
    if newSignature ~= signature then
        signature = newSignature
        return true
    end
end

Datatext.Register('currency', {
    name = 'Currencies', show = 'showCurrency', label = 'Cur:',
    events = { 'CURRENCY_DISPLAY_UPDATE', 'PLAYER_ENTERING_WORLD' },
    OnActivate = Read,
    OnEvent = function()
        if Read() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        local label = Datatext.Label(config, self)
        if #tracked == 0 then return label .. DIM .. 'None' .. RESET end
        local text = label
        for trackedIndex = 1, #tracked do
            local currency = tracked[trackedIndex]
            if trackedIndex > 1 then text = text .. ' ' end
            text = text .. string.format(BAR_ICON, currency.icon or 134400) .. Datatext.Colored(BreakUpLargeNumbers(currency.quantity), valueHex)
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
        if #tracked == 0 then
            tooltip:AddLine('Right-click a currency in the Currencies panel and pick Track on Backpack', 0.5, 0.5, 0.5)
        end
        for trackedIndex = 1, #tracked do
            local currency = tracked[trackedIndex]
            local right = BreakUpLargeNumbers(currency.quantity)
            local info = currency.id and C_CurrencyInfo.GetCurrencyInfo(currency.id)
            local cap = BUI.Currency.Cap(currency.id, info)
            if cap > 0 then
                right = right .. ' / ' .. BreakUpLargeNumbers(cap)
            end
            tooltip:AddDoubleLine(string.format(TIP_ICON, currency.icon or 134400, currency.name), right, 0.85, 0.85, 0.88, 1, 1, 1)
        end
        tooltip:AddLine(' ')
        tooltip:AddLine('Left-Click  |cffffffffCurrencies|r', 1, 0.82, 0)
        tooltip:Show()
    end,
    sample = function(config, label, colorize) return label .. string.format(BAR_ICON, 134400) .. colorize('1,250') end,
})
