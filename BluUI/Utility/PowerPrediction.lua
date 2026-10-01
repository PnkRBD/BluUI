local _, BUI = ...

local PowerPrediction = {}
BUI.PowerPrediction = PowerPrediction

local instances = {}
local instanceForBar = {}
local listenersStarted = false

local CAST_EVENTS = {
    'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_SUCCEEDED',
    'UNIT_SPELLCAST_INTERRUPTED', 'UNIT_SPELLCAST_CHANNEL_START', 'UNIT_SPELLCAST_CHANNEL_STOP',
    'UNIT_SPELLCAST_DELAYED', 'UNIT_SPELLCAST_CHANNEL_UPDATE',
}

local function ApplyAnchors(instance)
    local predict = instance.bar
    local parent  = instance.parent
    predict:ClearAllPoints()
    predict:SetPoint('TOP',    parent, 'TOP',    0, 0)
    predict:SetPoint('BOTTOM', parent, 'BOTTOM', 0, 0)
    local parentTexture = parent:GetStatusBarTexture()
    instance.anchorTexture = parentTexture
    if parentTexture then
        predict:SetPoint('RIGHT', parentTexture, 'RIGHT')
    else
        predict:SetPoint('RIGHT', parent, 'RIGHT')
    end
    local width = parent:GetWidth()
    predict:SetWidth(width > 0 and width or 200)

    if not instance._textureSet then
        local texturePath = instance.optsTexture
        if not texturePath and parentTexture and parentTexture.GetTexture then texturePath = parentTexture:GetTexture() end
        if texturePath then
            predict:SetStatusBarTexture(texturePath)
            local predictTexture = predict:GetStatusBarTexture()
            if predictTexture then predictTexture:SetTexCoord(0.01, 0.99, 0.01, 0.99) end
            instance._textureSet = true
        end
    end
end

local function UpdateInstance(instance)
    local enabled = not instance.enabled or instance.enabled()
    if not enabled then instance.bar:Hide(); return end

    if instance.anchorTexture ~= instance.parent:GetStatusBarTexture() then ApplyAnchors(instance) end

    local _, _, _, _, _, _, _, _, spellID = UnitCastingInfo('player')
    if not spellID then
        local channelName
        channelName, _, _, _, _, _, _, spellID = UnitChannelInfo('player')
    end
    if not spellID then instance.bar:Hide(); return end

    local costs = C_Spell.GetSpellPowerCost(spellID)
    if type(costs) ~= 'table' or #costs == 0 then instance.bar:Hide(); return end

    local powerType = instance.powerType
    if type(powerType) == 'function' then powerType = powerType() end
    if powerType == nil then powerType = UnitPowerType('player') end

    local checkRequiredAura = #costs > 1
    for _, costInfo in ipairs(costs) do
        if (not checkRequiredAura) or costInfo.hasRequiredAura then
            if costInfo.type == powerType and costInfo.cost and costInfo.cost > 0 then
                local maxPower = UnitPowerMax('player', powerType)
                if maxPower and maxPower > 0 then
                    instance.bar:SetMinMaxValues(0, maxPower)
                    instance.bar:SetValue(costInfo.cost)
                    instance.bar:Show()
                    return
                end
            end
        end
    end
    instance.bar:Hide()
end

local function UpdateAll()
    for _, instance in ipairs(instances) do
        if instance.active then UpdateInstance(instance) end
    end
end

local function SyncListeners()
    local wanted = false
    for _, instance in ipairs(instances) do
        if instance.active then
            wanted = true
            break
        end
    end
    if wanted == listenersStarted then return end
    listenersStarted = wanted
    if not wanted then
        BUI.Events:UnregisterAll('PowerPredict')
        return
    end
    for _, event in ipairs(CAST_EVENTS) do
        BUI.Events:RegisterUnit(event, 'player', 'PowerPredict', UpdateAll)
    end
end

function PowerPrediction.SetActive(predict, active)
    local instance = instanceForBar[predict]
    active = active and true or false
    if instance.active == active then return end
    instance.active = active
    if not active then predict:Hide() end
    SyncListeners()
end

function PowerPrediction.Attach(parentBar, options)
    options = options or {}

    local predict = CreateFrame('StatusBar', nil, parentBar)
    predict:SetReverseFill(true)
    predict:SetFrameLevel(parentBar:GetFrameLevel() + 1)
    local color = options.color or { 1, 1, 1, 0.35 }
    predict:SetStatusBarColor(color[1], color[2], color[3], color[4] or 0.35)
    predict:Hide()

    local instance = {
        bar         = predict,
        parent      = parentBar,
        optsTexture = options.texture,
        enabled     = options.enabled,
        powerType   = options.powerType,
        active      = options.active ~= false,
    }
    instances[#instances + 1] = instance
    instanceForBar[predict] = instance
    SyncListeners()

    ApplyAnchors(instance)

    parentBar:HookScript('OnSizeChanged', BUI.Profiler.Wrap('Utility.PowerPrediction bar resized', function() ApplyAnchors(instance) end))

    return predict
end
