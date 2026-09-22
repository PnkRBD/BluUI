local _, BUI = ...

local Datatext = BUI.Datatext
local DIM, RESET = Datatext.DIM, Datatext.RESET

local hasMail = false

local function Read()
    local value = HasNewMail() and true or false
    if value ~= hasMail then
        hasMail = value
        return true
    end
end

Datatext.Register('mail', {
    name = 'Mail', show = 'showMail', label = 'Mail:',
    events = { 'MAIL_INBOX_UPDATE', 'UPDATE_PENDING_MAIL', 'MAIL_CLOSED', 'MAIL_SHOW', 'PLAYER_ENTERING_WORLD' },
    OnActivate = Read,
    OnEvent = function()
        if Read() then Datatext.Refresh() end
    end,
    build = function(config, valueHex, self)
        if hasMail then
            return Datatext.Label(config, self) .. Datatext.Colored('New', valueHex)
        end
        return Datatext.Label(config, self) .. DIM .. 'None' .. RESET
    end,
    OnEnter = function(hit)
        local tooltip = Datatext.Tooltip(hit)
        tooltip:AddLine(hasMail and 'New Mail' or 'No New Mail', 1, 1, 1)
        local senders = { GetLatestThreeSenders() }
        if #senders > 0 then
            tooltip:AddLine(' ')
            tooltip:AddLine('From', 0.7, 0.7, 0.7)
            for senderIndex = 1, #senders do
                tooltip:AddLine(senders[senderIndex], 1, 1, 1)
            end
        end
        tooltip:Show()
    end,
    sample = function(config, label, colorize) return label .. colorize('New') end,
})
