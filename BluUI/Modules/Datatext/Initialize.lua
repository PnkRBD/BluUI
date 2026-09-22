local _, BUI = ...

local Datatext = BUI.Datatext

function Datatext.Initialize()
    Datatext.MigrateBars()
    Datatext._initialized = true
    local registryList = Datatext.registryList
    for listIndex = 1, #registryList do
        local entry = registryList[listIndex]
        if entry.OnInit then entry.OnInit() end
    end
    Datatext.Apply()
end

BUI.Events:OnLogin('Datatext', Datatext.Initialize)

BUI.Events:Register('PLAYER_REGEN_DISABLED', 'Datatext.CombatHovers', function()
    if BUI.GetDB().datatextHideHoversInCombat == false then return end
    Datatext.HideAllHovers()
end)
