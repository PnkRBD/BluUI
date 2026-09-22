local _, BUI = ...
local _, HookScript = BUI.Prof.Scripts('Util.PowerPrediction')

local PowerPrediction = {}
BUI.PowerPrediction = PowerPrediction

local instances = {}
local listenersStarted = false

local function ApplyAnchors(instance)
    local predict = instance.bar
    local parent  = instance.parent
    predict:ClearAllPoints()
    predict:SetPoint('TOP',    parent, 'TOP',    0, 0)
    predict:SetPoint('BOTTOM', parent, 'BOTTOM', 0, 0)
    local parentTexture = parent:GetStatusBarTexture()
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

    ApplyAnchors(instance)

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
    for _, instance in ipairs(instances) do UpdateInstance(instance) end
end

local function StartListeners()
    if listenersStarted then return end
    listenersStarted = true
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_START',         'player', 'PowerPredict', UpdateAll)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_STOP',          'player', 'PowerPredict', UpdateAll)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_FAILED',        'player', 'PowerPredict', UpdateAll)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_SUCCEEDED',     'player', 'PowerPredict', UpdateAll)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_INTERRUPTED',   'player', 'PowerPredict', UpdateAll)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_CHANNEL_START', 'player', 'PowerPredict', UpdateAll)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_CHANNEL_STOP',  'player', 'PowerPredict', UpdateAll)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_DELAYED',       'player', 'PowerPredict', UpdateAll)
    BUI.Events:RegisterUnit('UNIT_SPELLCAST_CHANNEL_UPDATE','player', 'PowerPredict', UpdateAll)
end

function PowerPrediction.Attach(parentBar, options)
    options = options or {}
    StartListeners()

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
    }
    instances[#instances + 1] = instance

    ApplyAnchors(instance)

    HookScript(parentBar, 'OnSizeChanged', function() ApplyAnchors(instance) end)

    return predict
end
