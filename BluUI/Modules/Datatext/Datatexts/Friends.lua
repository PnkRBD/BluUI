local _, BUI = ...

local Datatext = BUI.Datatext

local friendsOnline, bnetOnline = 0, 0

local function Read()
    local friends = C_FriendList.GetNumOnlineFriends()
    local _, bnet = BNGetNumFriends()
    if friends ~= friendsOnline or bnet ~= bnetOnline then
        friendsOnline, bnetOnline = friends, bnet
        return true
    end
end

Datatext.Register('friends', {
    name = 'Friends', show = 'showFriends', label = 'Friends:',
    events = { 'FRIENDLIST_UPDATE', 'BN_FRIEND_INFO_CHANGED', 'BN_FRIEND_ACCOUNT_ONLINE', 'BN_FRIEND_ACCOUNT_OFFLINE',
        'BN_CONNECTED', 'BN_DISCONNECTED', 'GROUP_ROSTER_UPDATE', 'PLAYER_ENTERING_WORLD' },
    OnActivate = Read,
    OnEvent = function()
        if Read() then Datatext.Refresh() end
        Datatext.RefreshOpenSocialPanel()
    end,
    build = function(config, valueHex, self)
        return Datatext.Label(config, self) .. Datatext.Colored(friendsOnline + bnetOnline, valueHex)
    end,
    OnClick = function(_, button)
        if button ~= 'LeftButton' then return end
        ToggleFriendsFrame()
        return true
    end,
    OnEnter = function(hit)
        Datatext.OpenSocialHover(hit, 'friends')
    end,
    options = function()
        return {
            {
                label = 'Show BattleTag',
                get = function() return BUI.GetDB().socialShowBattleTag ~= false end,
                set = function(value) BUI.GetDB().socialShowBattleTag = value end,
            },
        }
    end,
    sample = function(config, label, colorize) return label .. colorize('8') end,
})
