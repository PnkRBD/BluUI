local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Util.IconSearch')

local IconSearch = {}
BUI.IconSearch = IconSearch

local find = string.find
local wipe = wipe

local MAX_SPELL_ID = 1200000
local CHUNK_BUDGET_MS = 1

local names, tips, icons = {}, {}, {}
local count = 0
local building, ready = false, false
local scanID = 0
local scanFrame
local seenPairs = {}
local listeners = {}

local function Finish()
    ready = true
    building = false
    seenPairs = nil
    if scanFrame then SetScript(scanFrame, 'OnUpdate', nil) end
    for listenerIndex = 1, #listeners do listeners[listenerIndex]() end
    wipe(listeners)
end

local function ScanChunk()
    local deadline = debugprofilestop() + CHUNK_BUDGET_MS
    while scanID < MAX_SPELL_ID do
        scanID = scanID + 1
        local name = C_Spell.GetSpellName(scanID)
        if name then
            local texture = C_Spell.GetSpellTexture(scanID)
            if texture and texture ~= 0 then
                local textureSet = seenPairs[name]
                if not textureSet then
                    textureSet = {}
                    seenPairs[name] = textureSet
                end
                if not textureSet[texture] then
                    textureSet[texture] = true
                    count = count + 1
                    names[count] = name:lower()
                    tips[count] = name
                    icons[count] = texture
                end
            end
        end
        if scanID % 128 == 0 and debugprofilestop() > deadline then return end
    end
    Finish()
end

function IconSearch.Ready()
    return ready
end

function IconSearch.Progress()
    return scanID / MAX_SPELL_ID
end

function IconSearch.EnsureIndex(onReady)
    if ready then
        if onReady then onReady() end
        return
    end
    if onReady then listeners[#listeners + 1] = onReady end
    if building then return end
    building = true
    scanFrame = scanFrame or CreateFrame('Frame')
    SetScript(scanFrame, 'OnUpdate', ScanChunk)
end

function IconSearch.Search(query, cap)
    if not ready then return nil end
    query = query:lower()
    cap = cap or 24
    local prefix, rest = {}, {}
    local restCap = cap * 4
    for entryIndex = 1, count do
        local matchPosition = find(names[entryIndex], query, 1, true)
        if matchPosition == 1 then
            prefix[#prefix + 1] = entryIndex
            if #prefix >= cap then break end
        elseif matchPosition and #rest < restCap then
            rest[#rest + 1] = entryIndex
        end
    end
    local results, seenIcons = {}, {}
    for _, list in ipairs({ prefix, rest }) do
        for listIndex = 1, #list do
            local entryIndex = list[listIndex]
            if not seenIcons[icons[entryIndex]] then
                seenIcons[icons[entryIndex]] = true
                results[#results + 1] = { icon = icons[entryIndex], name = tips[entryIndex] }
                if #results >= cap then return results end
            end
        end
    end
    return results
end
