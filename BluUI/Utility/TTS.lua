local _, BUI = ...

local TTS = {}
BUI.TTS = TTS

local voiceCache
local resolvedCache = {}

local function Voices()
    if not voiceCache or #voiceCache == 0 then
        voiceCache = C_VoiceChat.GetTtsVoices()
    end
    return voiceCache
end

local function InvalidateVoices()
    voiceCache = nil
    wipe(resolvedCache)
end

BUI.Events:Register('VOICE_CHAT_TTS_VOICES_UPDATE', 'TTS', InvalidateVoices)

function TTS.BuildVoiceDropdownItems()
    local items = { { value = -1, text = 'Default Voice' } }
    for _, voice in ipairs(Voices()) do
        items[#items + 1] = { value = voice.voiceID, text = voice.name }
    end
    return items
end

local function ResolveVoiceID(voiceID)
    local cacheKey = voiceID or -1
    local cached = resolvedCache[cacheKey]
    if cached ~= nil then return cached end

    local voices = Voices()
    local resolved
    if voiceID and voiceID ~= -1 then
        for _, voice in ipairs(voices) do
            if voice.voiceID == voiceID then resolved = voiceID; break end
        end
    end
    if not resolved then
        local standard = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)
        for _, voice in ipairs(voices) do
            if voice.voiceID == standard then resolved = standard; break end
        end
    end
    if not resolved then
        resolved = voices[1].voiceID
    end
    resolvedCache[cacheKey] = resolved
    return resolved
end

local warnedNoVoices = false

function TTS.Speak(text, options)
    if type(text) ~= 'string' or issecretvalue(text) or not text:match('%S') then
        return
    end
    if #Voices() == 0 then
        if not warnedNoVoices then
            warnedNoVoices = true
            BUI.Print('TTS: no system voices available.')
        end
        return
    end
    options = options or {}
    local general = BUI.GetDB().general
    local voiceID = options.voiceID
    if not voiceID or voiceID == -1 then
        voiceID = general.ttsVoice
    end
    voiceID = ResolveVoiceID(voiceID)
    local rate    = options.rate or C_TTSSettings.GetSpeechRate()
    local volume  = options.volume or general.ttsVolume
    local overlap = options.overlap ~= false
    C_VoiceChat.SpeakText(voiceID, text, rate, volume, overlap)
end

function TTS.Stop()
    C_VoiceChat.StopSpeakingText()
end
