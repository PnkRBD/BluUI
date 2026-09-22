local _, BUI = ...

local Datatext = BUI.Datatext
local Pixel = BUI.Pixel

local PULL_HISTORY_MAX = 10
local COMBAT_END_GRACE = 1.5
local ROW_HEIGHT  = 18
local PANEL_WIDTH = 200

local pullHistory = {}
local combatStart, combatLast = 0, 0
local combatActive = false
local currentEncounter
local combatEndToken = 0
local combatText = '00:00'

local combatPanel

local function FormatSeconds(seconds)
    return string.format('%02d:%02d', seconds / 60, seconds % 60)
end

local function RenderCombatPanel()
    local panel = combatPanel
    if not panel then return end
    local pullCount = #pullHistory
    for pullIndex = 1, PULL_HISTORY_MAX do
        local row = panel.rows[pullIndex]
        local entry = pullHistory[pullIndex]
        if entry then
            row.name:SetText(pullIndex .. '. ' .. entry.name)
            row.time:SetText(FormatSeconds(entry.dur))
            row.name:Show(); row.time:Show()
        else
            row.name:Hide(); row.time:Hide()
        end
    end
    panel.empty:SetShown(pullCount == 0)
    local rowsShown = (pullCount > 0) and pullCount or 1
    panel:SetHeight(Pixel.Scale(34 + rowsShown * ROW_HEIGHT + 6 + 16))
end

local function RefreshCombatPanel()
    if combatPanel and combatPanel:IsShown() then RenderCombatPanel() end
end

local function RecordPull(seconds, name)
    if not seconds or seconds < 1 then return end
    table.insert(pullHistory, 1, { dur = math.floor(seconds + 0.5), name = name or 'Trash' })
    for pullIndex = #pullHistory, PULL_HISTORY_MAX + 1, -1 do pullHistory[pullIndex] = nil end
    RefreshCombatPanel()
end

local function BeginPull()
    combatActive = true
    combatStart = GetTime()
    combatLast = 0
    combatText = '00:00'
    Datatext.Refresh()
end

local function FinalizePull()
    if not combatActive then return end
    combatActive = false
    RecordPull(combatLast, currentEncounter)
    currentEncounter = nil
end

local function OnCombatStart()
    combatEndToken = combatEndToken + 1
    if not combatActive then BeginPull() end
end

local function OnCombatEnd()
    if not combatActive then return end
    combatEndToken = combatEndToken + 1
    local token = combatEndToken
    BUI.Prof.After('Datatext.Datatexts.Combat', COMBAT_END_GRACE, function()
        if combatEndToken == token and not UnitAffectingCombat('player') then
            FinalizePull()
        end
    end)
end

local function BuildCombatPanel()
    if combatPanel then return end
    local panel = Datatext.CreateHoverPanel('BUI_DatatextCombat', PANEL_WIDTH)
    local font = Datatext.PanelFont()
    panel.title:SetText('RECENT PULLS')
    panel.title:SetTextColor(0.55, 0.55, 0.60)

    local TIME_X = PANEL_WIDTH - 52
    panel.rows = {}
    for pullIndex = 1, PULL_HISTORY_MAX do
        local rowTop = Pixel.Scale(-(34 + (pullIndex - 1) * ROW_HEIGHT))
        local name = panel:CreateFontString(nil, 'OVERLAY')
        Pixel.ApplyFont(name, 11, font)
        name:SetPoint('TOPLEFT', Pixel.Scale(12), rowTop)
        name:SetWidth(Pixel.Scale(TIME_X - 18))
        name:SetWordWrap(false)
        name:SetJustifyH('LEFT')
        name:SetTextColor(0.78, 0.78, 0.82)
        local time = panel:CreateFontString(nil, 'OVERLAY')
        Pixel.ApplyFont(time, 11, font)
        time:SetPoint('TOPLEFT', Pixel.Scale(TIME_X), rowTop)
        time:SetJustifyH('LEFT')
        time:SetTextColor(0.9, 0.9, 0.95)
        panel.rows[pullIndex] = { name = name, time = time }
    end

    panel.empty = panel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panel.empty, 11, font)
    panel.empty:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-34))
    panel.empty:SetText('|cff777777No pulls recorded|r')

    panel.hint = panel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panel.hint, 10, font)
    panel.hint:SetPoint('BOTTOMLEFT', Pixel.Scale(10), Pixel.Scale(7))
    panel.hint:SetText('|cffffd200Ctrl+Right-Click|r Clear')

    combatPanel = panel
end

local function OpenCombatHover(anchor)
    BuildCombatPanel()
    local panel = combatPanel
    panel.anchor = anchor
    if panel:IsShown() and not panel._fadingOut then return end
    RenderCombatPanel()
    Datatext.PlacePanelAtCursor(panel)
    panel:Reveal()
end

Datatext.Register('combat', {
    name = 'Combat Time', show = 'showCombat', label = 'Combat:',
    events = { 'ENCOUNTER_START', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED' },
    interval = 1,
    OnInit = function()
        local store = BUI.GetAceDB()
        store.char.pullHistory = store.char.pullHistory or {}
        pullHistory = store.char.pullHistory
        for pullIndex = #pullHistory, PULL_HISTORY_MAX + 1, -1 do pullHistory[pullIndex] = nil end
    end,
    OnActivate = function()
        if UnitAffectingCombat('player') and not combatActive then BeginPull() end
    end,
    OnEvent = function(event, _, encounterName)
        if event == 'ENCOUNTER_START' then
            currentEncounter = encounterName
        elseif event == 'PLAYER_REGEN_DISABLED' then
            OnCombatStart()
        elseif event == 'PLAYER_REGEN_ENABLED' then
            OnCombatEnd()
        end
    end,
    OnUpdate = function()
        if not combatActive then return end
        combatLast = GetTime() - combatStart
        local text = FormatSeconds(combatLast)
        if text ~= combatText then
            combatText = text
            Datatext.Refresh()
        end
    end,
    build = function(config, valueHex, self)
        return Datatext.Label(config, self) .. Datatext.Colored(combatText, valueHex)
    end,
    OnClick = function(_, button)
        if button == 'RightButton' and IsControlKeyDown() then
            wipe(pullHistory)
            RefreshCombatPanel()
            return true
        end
    end,
    OnEnter = function(hit)
        OpenCombatHover(hit)
    end,
    sample = function(config, label, colorize) return label .. colorize('01:23') end,
})
