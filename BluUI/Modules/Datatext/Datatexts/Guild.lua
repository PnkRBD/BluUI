local _, BUI = ...

local Datatext = BUI.Datatext

local guildOnline = 0

local function Read()
    local online = 0
    if IsInGuild() then
        local _, count = GetNumGuildMembers()
        online = count or 0
    end
    if online ~= guildOnline then
        guildOnline = online
        return true
    end
end

Datatext.Register('guild', {
    name = 'Guild', show = 'showGuild', label = 'Guild:',
    events = { 'GUILD_ROSTER_UPDATE', 'PLAYER_GUILD_UPDATE', 'GROUP_ROSTER_UPDATE', 'PLAYER_ENTERING_WORLD' },
    OnInit = function()
        Datatext.RequestKeystones()
    end,
    OnActivate = function()
        Read()
        if IsInGuild() then C_GuildInfo.GuildRoster() end
    end,
    OnEvent = function()
        if Read() then Datatext.Refresh() end
        Datatext.RefreshOpenSocialPanel()
    end,
    build = function(config, valueHex, self)
        return Datatext.Label(config, self) .. Datatext.Colored(guildOnline, valueHex)
    end,
    OnClick = function(_, button)
        if button ~= 'LeftButton' then return end
        local toggle = ToggleGuildFrame or ToggleCommunitiesFrame
        if IsInGuild() and toggle then toggle() end
        return true
    end,
    OnEnter = function(hit)
        if not IsInGuild() then return end
        Datatext.OpenSocialHover(hit, 'guild')
    end,
    options = function()
        return {
            {
                label = 'Tooltip: M+ Score',
                get = function() return BUI.GetDB().guildTooltipScore ~= false end,
                set = function(value) BUI.GetDB().guildTooltipScore = value end,
            },
            {
                label = 'Tooltip: Guild Ranks',
                get = function() return BUI.GetDB().guildTooltipRanks == true end,
                set = function(value) BUI.GetDB().guildTooltipRanks = value end,
            },
        }
    end,
    sample = function(config, label, colorize) return label .. colorize('12') end,
})
