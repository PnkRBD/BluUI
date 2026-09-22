local _, BUI = ...

local Datatext = BUI.Datatext
local RESET = Datatext.RESET

local MAX_CHARACTER_ROWS = 15

local money = 0
local lastKnown
local sessionEarned, sessionSpent = 0, 0
local realmName, characterName

local function Store()
    local globalStore = BUI.db and BUI.db.globalStore
    if not globalStore then return end
    globalStore.datatextGold = globalStore.datatextGold or {}
    return globalStore.datatextGold
end

local function RememberCharacter()
    local store = Store()
    if not store or not realmName or not characterName then return end
    store[realmName] = store[realmName] or {}
    local record = store[realmName][characterName] or {}
    record.money = money
    record.class = select(2, UnitClass('player'))
    record.faction = UnitFactionGroup('player')
    record.seen = time()
    store[realmName][characterName] = record
end

local function Read()
    local current = GetMoney()
    if lastKnown then
        local change = current - lastKnown
        if change > 0 then sessionEarned = sessionEarned + change
        elseif change < 0 then sessionSpent = sessionSpent - change end
    end
    lastKnown = current
    if current ~= money then
        money = current
        RememberCharacter()
        return true
    end
end

local function SortByMoney(first, second) return first.money > second.money end

Datatext.Register('gold', {
    name = 'Gold', show = 'showGold', label = 'G:',
    events = { 'PLAYER_MONEY', 'PLAYER_ENTERING_WORLD', 'PLAYER_TRADE_MONEY', 'TRADE_MONEY_CHANGED',
        'SEND_MAIL_MONEY_CHANGED', 'SEND_MAIL_COD_CHANGED' },
    OnInit = function()
        characterName = UnitName('player')
        realmName = GetRealmName()
        lastKnown = nil
        sessionEarned, sessionSpent = 0, 0
        Read()
    end,
    OnActivate = Read,
    OnEvent = function()
        if Read() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        return Datatext.Label(config, self) .. Datatext.Colored(BreakUpLargeNumbers(math.floor(money / 10000)), valueHex)
    end,
    OnClick = function(_, button)
        if button == 'RightButton' then
            if IsControlKeyDown() then
                sessionEarned, sessionSpent = 0, 0
                return true
            end
            return
        end
        if InCombatLockdown() then return true end
        Datatext.OpenCurrencyUI()
        return true
    end,
    OnEnter = function(hit)
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine('Gold', 1, 1, 1)
        tooltip:AddDoubleLine('Current', Datatext.FormatMoney(money), 0.7, 0.7, 0.7, 1, 1, 1)

        tooltip:AddLine(' ')
        tooltip:AddLine('Session', 1, 1, 1)
        tooltip:AddDoubleLine('Earned', Datatext.FormatMoney(sessionEarned), 0.7, 0.7, 0.7, 1, 1, 1)
        tooltip:AddDoubleLine('Spent', Datatext.FormatMoney(sessionSpent), 0.7, 0.7, 0.7, 1, 1, 1)
        local net = sessionEarned - sessionSpent
        if net ~= 0 then
            local gained = net > 0
            tooltip:AddDoubleLine(gained and 'Profit' or 'Deficit', Datatext.FormatMoney(net),
                gained and 0.3 or 1, gained and 1 or 0.3, 0.3, 1, 1, 1)
        end

        local store = Store()
        local realm = store and realmName and store[realmName]
        if realm then
            local rows, total = {}, 0
            for name, record in pairs(realm) do
                if type(record) == 'table' and record.money then
                    rows[#rows + 1] = { name = name, money = record.money, class = record.class }
                    total = total + record.money
                end
            end
            if #rows > 0 then
                table.sort(rows, SortByMoney)
                tooltip:AddLine(' ')
                tooltip:AddLine('Characters on ' .. realmName, 1, 1, 1)
                for rowIndex = 1, math.min(#rows, MAX_CHARACTER_ROWS) do
                    local row = rows[rowIndex]
                    local classColor = row.class and RAID_CLASS_COLORS[row.class]
                    local red, green, blue = 0.8, 0.8, 0.8
                    if classColor then red, green, blue = classColor.r, classColor.g, classColor.b end
                    local nameText = row.name
                    if row.name == characterName then nameText = nameText .. ' |cff8a8a90(you)|r' end
                    tooltip:AddDoubleLine(nameText, Datatext.FormatMoney(row.money, true), red, green, blue, 1, 1, 1)
                end
                if #rows > MAX_CHARACTER_ROWS then
                    tooltip:AddLine('+' .. (#rows - MAX_CHARACTER_ROWS) .. ' more', 0.5, 0.5, 0.5)
                end
                tooltip:AddDoubleLine('Total', Datatext.FormatMoney(total, true), 1, 1, 1, 1, 1, 1)
            end
        end

        tooltip:AddLine(' ')
        tooltip:AddLine('Left-Click  |cffffffffCurrencies|r', 1, 0.82, 0)
        tooltip:AddLine('Ctrl+Right-Click  |cffffffffReset Session|r', 1, 0.82, 0)
        tooltip:Show()
    end,
    sample = function(config, label, colorize) return label .. colorize('12,345') end,
})
