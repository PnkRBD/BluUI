local BUI = BluUI
local SetScript = BUI.Prof.Scripts('Pages.CDAnnouncer')

local BUILib = BluUI.BUILibClient
local Controls, Layout, Widget, Modals, Toast = BUILib.Controls, BUILib.Layout, BUILib.Widget, BUILib.Modals, BUILib.Toast
local PageKit = BUILib.PageKit
local Reconciler = BUILib.R
local Pixel = BUI.Pixel
local Animation = BUI.Animation
local TimeFormat = BUI.TimeFormat
local MISSING_ICON = 134400

local CONTENT_W = Layout.PAGE_CONTENT_W
local HEADER_H  = 44
local STAGE_H   = 132
local CHIP_H    = 26
local ROW_GAP   = 8
local SEG_CD, SEG_LOW = 0.55, 0.20
local LOOP_SECONDS = 7
local FADE_DURATION = 0.15

local LOW_DEF   = { r = 1,   g = 0.2,  b = 0.2,  a = 1 }

local CDAnnouncer = BUI.CDAnnouncer

local function GetCfg() return BUI.GetDB().cdAnnouncer end
local function Refresh() CDAnnouncer.Refresh() end

local function BarOpts()
    return {
        style    = 'bar',
        position = 'bottom',
        parent   = BUI.PageEngine.window.frame,
    }
end

local fonts
local editor
local RenderList

local TRow, TCat, TInfo

local function LookupRow(entry)
    if entry.kind == 'item' then
        local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(entry.spellID)
        return icon or MISSING_ICON, name or ('Item ' .. tostring(entry.spellID))
    end
    local icon, name = BUI.Lookup.GetSpellInfo(entry.spellID)
    return icon or MISSING_ICON, name or ('Spell ' .. tostring(entry.spellID))
end

local function MaxChargesOf(entry)
    if entry.kind == 'item' then return nil end
    local info = C_Spell.GetSpellCharges(entry.spellID)
    local maxC = info and BUI.Tools.SafeNum(info.maxCharges)
    return (maxC and maxC > 1) and maxC or nil
end

local function SubtitleFor(entry)
    local kind = entry.kind == 'item' and 'Item' or 'Spell'
    local hasDur = entry.duration and entry.duration > 0
    local maxC = MaxChargesOf(entry)
    local dur
    if maxC then
        dur = hasDur
            and string.format('%d charges, %gs recharge', maxC, entry.duration)
            or string.format('%d charges', maxC)
    else
        dur = hasDur and string.format('%gs cooldown', entry.duration) or 'no cooldown duration'
    end
    return string.format('%s %d  -  %s', kind, entry.spellID, dur)
end

local function ListSubtitle(entry)
    local subtitle = SubtitleFor(entry)
    if entry.aliases and #entry.aliases > 0 then
        subtitle = subtitle .. string.format('  (+%d trigger IDs)', #entry.aliases)
    end
    return subtitle
end

local function FormatAliases(list)
    if not list or #list == 0 then return '' end
    return table.concat(list, ', ')
end

local function ParseAliases(text, selfID)
    if not text or text == '' then return nil end
    local list = {}
    for part in text:gmatch('([^,%s]+)') do
        local numberValue = tonumber(part)
        if numberValue and numberValue ~= selfID then list[#list + 1] = numberValue end
    end
    return #list > 0 and list or nil
end

local function TimelineModel(editorEntry)
    local dur  = (editorEntry.duration and editorEntry.duration > 0) and editorEntry.duration or 30
    local lowT = math.min(editorEntry.lowThreshold or 5, dur)
    local tail = (editorEntry.readyMode == 'persist') and 2 or math.max(0.5, editorEntry.glowDuration or 1)
    return dur, lowT, tail
end

local function PosToState(editorEntry, p)
    local dur, lowT, tail = TimelineModel(editorEntry)
    if p < SEG_CD then
        return 'cd', lowT + (dur - lowT) * (1 - p / SEG_CD)
    elseif p < SEG_CD + SEG_LOW then
        return 'low', lowT * (1 - (p - SEG_CD) / SEG_LOW)
    end
    return 'ready', tail * ((p - SEG_CD - SEG_LOW) / (1 - SEG_CD - SEG_LOW))
end

local function PhaseForPos(p)
    if p < SEG_CD then return 'cooldown' end
    if p < SEG_CD + SEG_LOW then return 'low' end
    return 'ready'
end

local function PhaseEnabled(editorEntry, phase)
    if phase == 'cooldown' then return editorEntry.cdPhase ~= false end
    if phase == 'low' then return editorEntry.lowPhase ~= false end
    return editorEntry.readyPhase ~= false
end

local function NextEnabledPos(editorEntry, p)
    if not PhaseEnabled(editorEntry, 'cooldown') and not PhaseEnabled(editorEntry, 'low') and not PhaseEnabled(editorEntry, 'ready') then
        return p
    end
    for _ = 1, 3 do
        local phase = PhaseForPos(p)
        if PhaseEnabled(editorEntry, phase) then return p end
        if phase == 'cooldown' then p = SEG_CD
        elseif phase == 'low' then p = SEG_CD + SEG_LOW
        else p = 0 end
    end
    return p
end

local function EntryFont(editorEntry)
    if editorEntry.font and editorEntry.font ~= BUI.C.GLOBAL_OPTION then
        return BUI.GetModuleFont({ font = editorEntry.font })
    end
    return BUI.GetModuleFont(GetCfg())
end

local function LayoutStage(editorEntry, showIcon, showText)
    local row, icon, text = editor.stageRow, editor.stageIcon, editor.stageText
    icon:SetShown(showIcon)
    editor.stageIconBorder:SetShown(showIcon)
    text:SetShown(showText)

    local isz = Pixel.Scale(editorEntry.iconSize or 22)
    icon:SetSize(isz, isz)
    local textWidth = showText and (text:GetStringWidth() or 0) or 0
    local textHeight = showText and (text:GetStringHeight() or 0) or 0
    icon:ClearAllPoints()
    text:ClearAllPoints()

    local anchor = editorEntry.textAnchor or 'right'
    local w, h
    if not showIcon then
        text:SetPoint('CENTER', row, 'CENTER', 0, 0)
        w, h = math.max(textWidth, 10), math.max(textHeight, 10)
    elseif anchor == 'top' then
        icon:SetPoint('BOTTOM', row, 'BOTTOM', 0, 0)
        text:SetPoint('BOTTOM', icon, 'TOP', 0, Pixel.Scale(4))
        w = math.max(textWidth, isz)
        h = isz + (showText and (textHeight + Pixel.Scale(4)) or 0)
    elseif anchor == 'bottom' then
        icon:SetPoint('TOP', row, 'TOP', 0, 0)
        text:SetPoint('TOP', icon, 'BOTTOM', 0, Pixel.Scale(-4))
        w = math.max(textWidth, isz)
        h = isz + (showText and (textHeight + Pixel.Scale(4)) or 0)
    else
        icon:SetPoint('LEFT', row, 'LEFT', 0, 0)
        text:SetPoint('LEFT', icon, 'RIGHT', Pixel.Scale(6), 0)
        w = isz + (showText and (Pixel.Scale(6) + textWidth) or 0)
        h = math.max(isz, textHeight)
    end
    row:SetSize(math.max(w, 10), math.max(h, 10))
end

local function RenderStage()
    local editorEntry = editor.entry
    if not editorEntry then return end
    local phase, value = PosToState(editorEntry, editor.playPos)
    local isCD = phase ~= 'ready'
    local row, text = editor.stageRow, editor.stageText

    local phaseOn, offHint
    if phase == 'cd' then
        phaseOn = editorEntry.cdPhase ~= false
        offHint = 'Cooldown phase is disabled - nothing is shown until the final seconds.'
    elseif phase == 'low' then
        phaseOn = editorEntry.lowPhase ~= false or editorEntry.cdPhase ~= false
        offHint = 'Cooldown and Final Seconds are disabled - nothing is shown while on cooldown.'
    else
        phaseOn = editorEntry.readyPhase ~= false
        offHint = 'Ready phase is disabled - nothing is shown when it comes off cooldown.'
    end
    if not phaseOn then
        row:Hide()
        editor.stageHint:SetText(offHint)
        editor.stageHint:Show()
        editor.lastStagePhase = phase
        return
    end
    editor.stageHint:Hide()
    row:Show()

    local _, name = LookupRow(editorEntry)
    local str, color
    local showIcon, showText
    if isCD then
        local fmt = (editorEntry.cdDisplayFormat or '[spell] [time]')
            :gsub('%[spell%]', name):gsub('%[name%]', name)
        str = fmt:gsub('%[time%]', TimeFormat.Format(value, 10))
        local lowOn = phase == 'low' and editorEntry.lowPhase ~= false
        color = lowOn and (editorEntry.lowColor or LOW_DEF) or (editorEntry.color or GetCfg().cdColor)
        showIcon = editorEntry.showIcon ~= false
        showText = editorEntry.showText ~= false
    else
        str = (editorEntry.readyDisplayFormat or '[spell] Ready')
            :gsub('%[spell%]', name):gsub('%[name%]', name)
        color = editorEntry.readyColor or GetCfg().readyColor
        showIcon = editorEntry.showIconReady ~= false
        showText = editorEntry.showTextReady ~= false
        if editorEntry.readyMode ~= 'persist' then
            local scope = editorEntry.flashScope or 'both'
            if scope == 'icon' then showText = false
            elseif scope == 'text' then showIcon = false end
        end
    end

    Pixel.ApplyFont(text, editorEntry.fontSize or 16, EntryFont(editorEntry), BUI.GetFontOutline())
    text:SetText(str)
    text:SetTextColor(color.r, color.g, color.b, color.a or 1)

    local icon, iconTex = editor.stageIcon, LookupRow(editorEntry)
    if icon._tex ~= iconTex then
        icon._tex = iconTex
        icon:SetTexture(iconTex)
    end

    local iconTime = editor.stageIconTime
    if isCD and editorEntry.timeInIcon and showIcon then
        local isz = editorEntry.iconSize or 22
        local tsz = editorEntry.iconTimeSize or math.max(8, math.floor(isz * 0.45))
        Pixel.ApplyFont(iconTime, tsz, EntryFont(editorEntry), BUI.GetFontOutline())
        local anchor = editorEntry.iconTimeAnchor or 'CENTER'
        local ox, oy = editorEntry.iconTimeX or 0, editorEntry.iconTimeY or 0
        if iconTime._anchor ~= anchor or iconTime._x ~= ox or iconTime._y ~= oy then
            iconTime._anchor, iconTime._x, iconTime._y = anchor, ox, oy
            iconTime:ClearAllPoints()
            iconTime:SetPoint(anchor, editor.stageIcon, anchor, ox, oy)
        end
        iconTime:SetText(TimeFormat.Format(value, 10))
        iconTime:SetTextColor(color.r, color.g, color.b, color.a or 1)
        iconTime:Show()
    else
        iconTime:Hide()
    end

    LayoutStage(editorEntry, showIcon, showText)

    local wantTextPulse = phase == 'low' and editorEntry.flashLow and editorEntry.lowPhase ~= false
    if wantTextPulse and not editor.stagePulse:IsPlaying() then
        editor.stagePulse:Play()
    elseif not wantTextPulse and editor.stagePulse:IsPlaying() then
        editor.stagePulse:Stop()
        text:SetAlpha(1)
    end

    local wantRowPulse = phase == 'ready' and editorEntry.readyMode ~= 'persist'
    if wantRowPulse and not editor.stageRowPulse:IsPlaying() then
        editor.stageRowPulse:Play()
    elseif not wantRowPulse and editor.stageRowPulse:IsPlaying() then
        editor.stageRowPulse:Stop()
    end

    if phase == 'ready' and editor.lastStagePhase ~= 'ready' and editorEntry.readyMode == 'persist' then
        editor.stageFlash:Stop()
        editor.stageFlash:Play()
    end
    editor.lastStagePhase = phase

    row:SetAlpha(1)
end

local function RefreshChips()
    local editorEntry = editor.entry
    if not editorEntry then return end
    local dur, lowT = TimelineModel(editorEntry)
    local chips = editor.chips
    chips.cooldown.label:SetText(string.format('COOLDOWN  %gs', dur))
    chips.low.label:SetText(string.format('FINAL  %gs', lowT))
    chips.ready.label:SetText(editorEntry.readyMode == 'persist' and 'READY  (stays)' or 'READY')

    local colors = {
        cooldown = editorEntry.color or GetCfg().cdColor,
        low      = editorEntry.lowColor or LOW_DEF,
        ready    = editorEntry.readyColor or GetCfg().readyColor,
    }
    local enabled = {
        cooldown = editorEntry.cdPhase ~= false,
        low      = editorEntry.lowPhase ~= false,
        ready    = editorEntry.readyPhase ~= false,
    }
    local current = PhaseForPos(editor.playPos)
    editor.lastChipPhase = current
    for key, chip in pairs(chips) do
        local color = colors[key]
        local sel = current == key
        local on = enabled[key]
        local fillA = on and (sel and 0.45 or 0.15) or 0.05
        Widget.SetRectColor(chip.rect, color.r, color.g, color.b, fillA)
        chip.label:SetTextColor(1, 1, 1, on and (sel and 1 or 0.7) or 0.35)
    end
end

local function UpdateHeader()
    local editorEntry = editor.entry
    if not editorEntry then return end
    local icon, name = LookupRow(editorEntry)
    editor.headerIcon:SetTexture(icon)
    editor.headerTitle:SetText(name)
    editor.headerSub:SetText(SubtitleFor(editorEntry))
    editor.enableToggle:SetValue(editorEntry.enabled ~= false)
end

local Touch

local function PhaseToggled(phase, enabled)
    if enabled then
        if phase == 'cooldown' then editor.playPos = 0
        elseif phase == 'low' then editor.playPos = SEG_CD
        else editor.playPos = SEG_CD + SEG_LOW end
    elseif editor.entry then
        editor.playPos = NextEnabledPos(editor.entry, editor.playPos)
    end
    Touch()
end

Touch = function()
    UpdateHeader()
    RefreshChips()
    RenderStage()
end

local function SetPlaying(playing)
    editor.playing = playing
    editor.playBtn:SetText(playing and 'Pause' or 'Play')
end

local function DriveOnScreen()
    local editorEntry = editor.entry
    if not editorEntry or not editor.spellID then return end
    local phase, value = PosToState(editorEntry, editor.playPos)
    CDAnnouncer.DriveLivePreview(editor.spellID, phase, value)
end

local function EditorDriver(self, dt)
    local editorEntry = editor.entry
    if not editorEntry then return end
    if editor.playing then
        editor.playPos = NextEnabledPos(editorEntry, (editor.playPos + dt / LOOP_SECONDS) % 1)
        if PhaseForPos(editor.playPos) ~= editor.lastChipPhase then
            RefreshChips()
        end
        RenderStage()
    end
    DriveOnScreen()
end

local CHIP_STARTS = { cooldown = 0, low = SEG_CD, ready = SEG_CD + SEG_LOW }

local function JumpToPhase(key)
    editor.playPos = CHIP_STARTS[key]
    RefreshChips()
    RenderStage()
end

local function MakeChip(parent, key)
    local chip = CreateFrame('Button', nil, parent)
    chip:SetHeight(Pixel.Scale(CHIP_H))
    chip.rect = Widget.DrawRoundedRect(chip, 4, { 1, 1, 1, 0.1 }, 'BACKGROUND', 0, 0)
    chip.label = chip:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(chip.label, 10, BUILib.Font, 'OUTLINE')
    chip.label:SetPoint('CENTER')
    SetScript(chip, 'OnClick', function() JumpToPhase(key) end)
    return chip
end

local function SpeakSample(editorEntry, spellID, phrase, withTime)
    if not BUI.TTS.IsAvailable() then return end
    local info = (editorEntry.kind == 'item')
        and { name = (C_Item.GetItemInfo(spellID) or 'Item') }
        or C_Spell.GetSpellInfo(spellID)
    local name = (info and info.name) or 'Spell'
    phrase = phrase:gsub('%[spell%]', name):gsub('%[name%]', name)
    if withTime then
        phrase = phrase:gsub('%[time%]', tostring(math.max(1, math.floor(editorEntry.lowThreshold or 5))))
    end
    BUI.TTS.Speak(phrase)
end

local function EditorSpec()
    local editorEntry, spellID = editor.entry, editor.spellID
    local rebuildKey = editor.rebuildKey
    local sounds = BUI.BuildSoundDropdownItems()
    local specs = {}

    local function Cat(key, text, first)
        specs[#specs + 1] = { type = TCat, key = key, props = { gap = 6, topMargin = first and 0 or 20,
            make = function(p) return Controls.CategoryLabel(p, text, CONTENT_W) end } }
    end
    local function Row(key, buildCfg, sync)
        specs[#specs + 1] = { type = TRow, key = key, props = { gap = ROW_GAP, rebuildKey = rebuildKey,
            make = function(p)
                local cfg = buildCfg()
                cfg.width = CONTENT_W
                return Controls.SettingRow(p, cfg)
            end,
            update = sync } }
    end

    Cat('cat.cd', 'Cooldown Phase', true)

    Row('cd.main', function() return {
        title = 'Countdown While on Cooldown',
        description = 'Announce the remaining time until this cooldown is back up',
        checked = editorEntry.cdPhase ~= false,
        callback = function(v) editorEntry.cdPhase = v; PhaseToggled('cooldown', v) end,
        accessoryWidth = 60,
        accessories = function(row)
            local cog = PageKit.SettingsIcon(row, {
                title = 'COOLDOWN', tooltip = 'Countdown text & elements',
                onChange = Touch,
                options = {
                    { kind = 'textbox', label = 'Display Text',
                      get = function() return editorEntry.cdDisplayFormat or '[spell] [time]' end,
                      set = function(v) editorEntry.cdDisplayFormat = v end },
                    { label = 'Show Text',
                      get = function() return editorEntry.showText ~= false end,
                      set = function(v) editorEntry.showText = v end },
                    { label = 'Show Spell Icon',
                      get = function() return editorEntry.showIcon ~= false end,
                      set = function(v) editorEntry.showIcon = v end },
                },
            })
            local color = editorEntry.color or GetCfg().cdColor
            local colorSwatch = Controls.ColorSwatch(row, { r = color.r, g = color.g, b = color.b, a = color.a or 1,
                callback = function(r, g, b, alphaAnimation) editorEntry.color = { r = r, g = g, b = b, a = alphaAnimation }; Touch() end,
                tooltip = 'Countdown color' })
            return { cog, colorSwatch }
        end,
    } end, function(row) row:SetValue(editorEntry.cdPhase ~= false) end)

    local maxC = MaxChargesOf(editorEntry)
    Row('cd.duration', function() return {
        title = maxC and 'Recharge Time' or 'Cooldown Duration',
        description = maxC
            and string.format('%d charges - seconds each charge takes to recharge', maxC)
            or 'Seconds this cooldown takes; Auto reads it from the tooltip',
        plain = true,
        accessoryWidth = 145,
        accessories = function(row)
            local box
            box = Controls.TextBox(row, nil, tostring(editorEntry.duration or ''), function(v)
                local numberValue = tonumber(v)
                if numberValue and numberValue > 0 then editorEntry.duration = numberValue; Touch() end
            end, nil, 70)
            local autoBtn = Controls.Button(row, 'Auto', 52, function()
                local seconds = CDAnnouncer.ResolveCooldownSeconds(spellID, editorEntry.kind)
                if seconds then
                    editorEntry.duration = seconds
                    box:SetValue(tostring(seconds))
                    Touch()
                end
            end)
            return { autoBtn, box }
        end,
    } end)

    Row('cd.iconTime', function() return {
        title = 'Countdown Inside Icon',
        description = 'Overlay the remaining seconds on the spell icon itself',
        checked = editorEntry.timeInIcon and true or false,
        callback = function(v) editorEntry.timeInIcon = v; Touch() end,
        accessoryWidth = 60,
        accessories = function(row)
            local mover = PageKit.OffsetMover(row, {
                title = 'COUNTDOWN OFFSET', tooltip = 'Nudge the in-icon countdown',
                min = -30, max = 30,
                getX = function() return editorEntry.iconTimeX or 0 end,
                setX = function(v) editorEntry.iconTimeX = v; Touch() end,
                getY = function() return editorEntry.iconTimeY or 0 end,
                setY = function(v) editorEntry.iconTimeY = v; Touch() end,
            })
            local cog = PageKit.SettingsIcon(row, {
                title = 'IN-ICON COUNTDOWN', tooltip = 'Size & placement',
                onChange = Touch,
                options = {
                    { kind = 'slider', label = 'Text Size', min = 6, max = 40,
                      get = function() return editorEntry.iconTimeSize or math.max(8, math.floor((editorEntry.iconSize or 22) * 0.45)) end,
                      set = function(v) editorEntry.iconTimeSize = v end },
                    { kind = 'dropdown', label = 'Placement', items = BUI.C.ANCHOR_POINT_OPTIONS_SHORT,
                      get = function() return editorEntry.iconTimeAnchor or 'CENTER' end,
                      set = function(v) editorEntry.iconTimeAnchor = v end },
                },
            })
            return { mover, cog }
        end,
    } end, function(row) row:SetValue(editorEntry.timeInIcon and true or false) end)

    if editorEntry.kind ~= 'item' then
        Row('cd.aliases', function() return {
            title = 'Extra Trigger IDs',
            description = 'Other spell IDs that also start this cooldown (comma separated)',
            plain = true,
            accessoryWidth = 210,
            accessories = function(row)
                return { Controls.TextBox(row, nil, FormatAliases(editorEntry.aliases), function(v)
                    editorEntry.aliases = ParseAliases(v, spellID)
                end, nil, 200) }
            end,
        } end)
    end

    Cat('cat.low', 'Final Seconds')

    Row('low.main', function() return {
        title = 'Final Seconds Alert',
        description = 'Recolor and flash the countdown when it is almost ready',
        checked = editorEntry.lowPhase ~= false,
        callback = function(v) editorEntry.lowPhase = v; PhaseToggled('low', v) end,
        accessoryWidth = 60,
        accessories = function(row)
            local cog = PageKit.SettingsIcon(row, {
                title = 'FINAL SECONDS', tooltip = 'Threshold, flash & sound',
                onChange = Touch,
                options = {
                    { kind = 'slider', label = 'Starts At (sec)', min = 1, max = 30,
                      get = function() return editorEntry.lowThreshold or 5 end,
                      set = function(v) editorEntry.lowThreshold = v end },
                    { label = 'Flash Text',
                      get = function() return editorEntry.flashLow and true or false end,
                      set = function(v) editorEntry.flashLow = v end },
                    { kind = 'dropdown', label = 'Sound', items = sounds,
                      get = function() return editorEntry.soundLow or 'None' end,
                      set = function(v)
                          editorEntry.soundLow = (v ~= 'None') and v or nil
                          BUI.PlaySoundByName(v)
                      end },
                },
            })
            local color = editorEntry.lowColor or LOW_DEF
            local colorSwatch = Controls.ColorSwatch(row, { r = color.r, g = color.g, b = color.b, a = color.a or 1,
                callback = function(r, g, b, alphaAnimation) editorEntry.lowColor = { r = r, g = g, b = b, a = alphaAnimation }; Touch() end,
                tooltip = 'Final seconds color' })
            return { cog, colorSwatch }
        end,
    } end, function(row) row:SetValue(editorEntry.lowPhase ~= false) end)

    Row('low.tts', function() return {
        title = 'Speak Countdown',
        description = 'Read the final seconds aloud with text-to-speech',
        checked = editorEntry.countdownLow and true or false,
        callback = function(v) editorEntry.countdownLow = v end,
        accessoryWidth = 215,
        accessories = function(row)
            local box = Controls.TextBox(row, nil, editorEntry.countdownText or '[spell] in [time]', function(v)
                editorEntry.countdownText = v
            end, nil, 150)
            local test = Controls.Button(row, 'Test', 48, function()
                SpeakSample(editorEntry, spellID, editorEntry.countdownText or '[spell] in [time]', true)
            end)
            return { test, box }
        end,
    } end, function(row) row:SetValue(editorEntry.countdownLow and true or false) end)

    Cat('cat.ready', 'Ready')

    Row('ready.main', function() return {
        title = 'Ready Alert',
        description = 'Announce the moment this cooldown is available again',
        checked = editorEntry.readyPhase ~= false,
        callback = function(v) editorEntry.readyPhase = v; PhaseToggled('ready', v) end,
        accessoryWidth = 195,
        accessories = function(row)
            local modeDD = Controls.Dropdown(row, nil, {
                { value = 'flash',   text = 'Flash & Hide' },
                { value = 'persist', text = 'Stay Shown' },
            }, editorEntry.readyMode or 'flash', function(v) editorEntry.readyMode = v; Touch() end, nil, 130)
            local cog = PageKit.SettingsIcon(row, {
                title = 'READY', tooltip = 'Text, flash & sound',
                onChange = Touch,
                options = {
                    { kind = 'textbox', label = 'Display Text',
                      get = function() return editorEntry.readyDisplayFormat or '[spell] Ready' end,
                      set = function(v) editorEntry.readyDisplayFormat = v end },
                    { kind = 'dropdown', label = 'Flash Scope', items = {
                        { value = 'both', text = 'Icon + Text' },
                        { value = 'icon', text = 'Icon Only' },
                        { value = 'text', text = 'Text Only' },
                      },
                      get = function() return editorEntry.flashScope or 'both' end,
                      set = function(v) editorEntry.flashScope = v end },
                    { kind = 'slider', label = 'Flash Duration', min = 0.25, max = 5, step = 0.25,
                      get = function() return editorEntry.glowDuration or 1 end,
                      set = function(v) editorEntry.glowDuration = v end },
                    { kind = 'dropdown', label = 'Sound', items = sounds,
                      get = function() return editorEntry.soundReady or 'None' end,
                      set = function(v)
                          editorEntry.soundReady = (v ~= 'None') and v or nil
                          BUI.PlaySoundByName(v)
                      end },
                },
            })
            local color = editorEntry.readyColor or GetCfg().readyColor
            local colorSwatch = Controls.ColorSwatch(row, { r = color.r, g = color.g, b = color.b, a = color.a or 1,
                callback = function(r, g, b, alphaAnimation) editorEntry.readyColor = { r = r, g = g, b = b, a = alphaAnimation }; Touch() end,
                tooltip = 'Ready color' })
            return { modeDD, cog, colorSwatch }
        end,
    } end, function(row) row:SetValue(editorEntry.readyPhase ~= false) end)

    Row('ready.tts', function() return {
        title = 'Speak on Ready',
        description = 'Say a phrase with text-to-speech when it comes off cooldown',
        checked = editorEntry.tts and true or false,
        callback = function(v) editorEntry.tts = v end,
        accessoryWidth = 215,
        accessories = function(row)
            local box = Controls.TextBox(row, nil, editorEntry.ttsText or '[spell] ready', function(v)
                editorEntry.ttsText = v
            end, nil, 150)
            local test = Controls.Button(row, 'Test', 48, function()
                SpeakSample(editorEntry, spellID, editorEntry.ttsText or '[spell] ready', false)
            end)
            return { test, box }
        end,
    } end, function(row) row:SetValue(editorEntry.tts and true or false) end)

    Cat('cat.style', 'Style & Position')

    Row('style.text', function() return {
        title = 'Text & Icon Style',
        description = 'Font, sizes and where the text sits relative to the icon',
        plain = true,
        accessoryWidth = 195,
        accessories = function(row)
            local cog = PageKit.SettingsIcon(row, {
                title = 'STYLE', tooltip = 'Sizes & layout',
                onChange = Touch,
                options = {
                    { kind = 'slider', label = 'Font Size', min = 8, max = 48,
                      get = function() return editorEntry.fontSize or 16 end,
                      set = function(v) editorEntry.fontSize = v end },
                    { kind = 'slider', label = 'Icon Size', min = 12, max = 64,
                      get = function() return editorEntry.iconSize or 22 end,
                      set = function(v) editorEntry.iconSize = v end },
                    { kind = 'dropdown', label = 'Text Position', items = {
                        { value = 'right',  text = 'Right of Icon' },
                        { value = 'top',    text = 'Above Icon' },
                        { value = 'bottom', text = 'Below Icon' },
                      },
                      get = function() return editorEntry.textAnchor or 'right' end,
                      set = function(v) editorEntry.textAnchor = v end },
                },
            })
            local fdd = Controls.Dropdown(row, nil, fonts, editorEntry.font or BUI.C.GLOBAL_OPTION, function(v)
                editorEntry.font = v; Touch()
            end, nil, 150)
            return { cog, fdd }
        end,
    } end)

    Row('style.pos', function() return {
        title = 'Custom Position',
        description = 'Place this announcement somewhere other than the shared anchor',
        checked = editorEntry.useCustomPos and true or false,
        callback = function(v) editorEntry.useCustomPos = v; Touch() end,
        accessoryWidth = 30,
        accessories = function(row)
            return { PageKit.PositionIcon(row, {
                title = 'CUSTOM POSITION', tooltip = 'Anchor & offsets',
                options = {
                    { kind = 'dropdown', label = 'Anchor Point', items = BUI.C.ANCHOR_POINT_OPTIONS,
                      get = function() return editorEntry.posAnchor or 'CENTER' end,
                      set = function(v) editorEntry.posAnchor = v end },
                    { kind = 'slider', label = 'X Offset', min = -1500, max = 1500,
                      get = function() return editorEntry.posX or 0 end,
                      set = function(v) editorEntry.posX = v end },
                    { kind = 'slider', label = 'Y Offset', min = -1000, max = 1000,
                      get = function() return editorEntry.posY or 0 end,
                      set = function(v) editorEntry.posY = v end },
                },
            }) }
        end,
    } end, function(row) row:SetValue(editorEntry.useCustomPos and true or false) end)

    return specs
end

local function RenderEditor()
    Reconciler.Reconcile.Children(editor.root, EditorSpec())
    editor.tab:Refresh()
    BUILib.Defer(function() editor.tab:Refresh() end)
end

local function BuildEditor(pageFrame)
    editor = CreateFrame('Frame', nil, pageFrame)
    editor:SetAllPoints(pageFrame)
    editor:SetFrameStrata(pageFrame:GetFrameStrata())
    editor:SetFrameLevel(pageFrame:GetFrameLevel() + 60)
    editor:EnableMouse(true)
    editor:SetAlpha(0)
    editor:Hide()
    editor.playPos = 0
    editor.playing = true

    editor.bg = editor:CreateTexture(nil, 'BACKGROUND')
    editor.bg:SetAllPoints()
    editor.bg:SetColorTexture(0.04, 0.045, 0.052, 1)

    local col = CreateFrame('Frame', nil, editor)
    col:SetWidth(Pixel.Scale(CONTENT_W))
    col:SetPoint('TOP', editor, 'TOP', 0, Pixel.Scale(-16))
    col:SetPoint('BOTTOM', editor, 'BOTTOM', 0, 0)

    local header = CreateFrame('Frame', nil, col)
    header:SetPoint('TOPLEFT', 0, 0)
    header:SetPoint('TOPRIGHT', 0, 0)
    header:SetHeight(Pixel.Scale(HEADER_H))

    local backBtn = Controls.GhostButton(header, '< Back', 80, function() CDAnnouncer.CloseSpellEditor() end)
    Widget.Unwrap(backBtn):SetPoint('LEFT', header, 'LEFT', 0, 0)

    editor.headerIcon = header:CreateTexture(nil, 'ARTWORK')
    editor.headerIcon:SetSize(Pixel.Scale(30), Pixel.Scale(30))
    editor.headerIcon:SetPoint('LEFT', Widget.Unwrap(backBtn), 'RIGHT', Pixel.Scale(14), 0)
    editor.headerIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    editor.headerTitle = header:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(editor.headerTitle, 16, BUILib.Font, '')
    editor.headerTitle:SetPoint('TOPLEFT', editor.headerIcon, 'TOPRIGHT', Pixel.Scale(10), Pixel.Scale(-1))
    editor.headerTitle:SetTextColor(1, 1, 1, 1)

    editor.headerSub = header:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(editor.headerSub, 10, BUILib.Font, '')
    editor.headerSub:SetPoint('TOPLEFT', editor.headerTitle, 'BOTTOMLEFT', 0, Pixel.Scale(-3))
    editor.headerSub:SetTextColor(0.55, 0.58, 0.64, 1)

    local previewBtn = Controls.Icon(header, {
        texture = BUILib.GetLibMedia('eye'),
        size = 20,
        tooltip = 'Preview on screen',
        onClick = function()
            if editor.spellID then CDAnnouncer.PreviewSpell(editor.spellID, 8) end
        end,
    })
    Widget.Unwrap(previewBtn):SetPoint('RIGHT', header, 'RIGHT', 0, 0)

    editor.enableToggle = Controls.IconToggle(header, true, function(v)
        if editor.spellID then CDAnnouncer.SetSpellEnabled(editor.spellID, v) end
    end, {
        texture = BUILib.GetLibMedia('enable'),
        tooltip = 'Enable or disable this spell',
    })
    Widget.Unwrap(editor.enableToggle):SetPoint('RIGHT', Widget.Unwrap(previewBtn), 'LEFT', Pixel.Scale(-14), 0)

    local stage = CreateFrame('Frame', nil, col)
    stage:SetPoint('TOPLEFT', 0, Pixel.Scale(-(HEADER_H + 10)))
    stage:SetPoint('TOPRIGHT', 0, Pixel.Scale(-(HEADER_H + 10)))
    stage:SetHeight(Pixel.Scale(STAGE_H))
    Widget.DrawRoundedRect(stage, 8, { 0.2, 0.22, 0.26, 0.5 }, 'BACKGROUND', 0, 0)
    Widget.DrawRoundedRect(stage, 7, { 0.025, 0.028, 0.034, 1 }, 'BACKGROUND', 1, 1)
    editor.stage = stage

    local liveTag = stage:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(liveTag, 9, BUILib.Font, 'OUTLINE')
    liveTag:SetPoint('TOPLEFT', Pixel.Scale(12), Pixel.Scale(-10))
    liveTag:SetTextColor(1, 1, 1, 0.3)
    liveTag:SetText('LIVE PREVIEW')

    editor.playBtn = Widget.Unwrap(Controls.GhostButton(stage, 'Pause', 64, function()
        SetPlaying(not editor.playing)
    end))
    editor.playBtn:SetPoint('BOTTOMRIGHT', stage, 'BOTTOMRIGHT', Pixel.Scale(-10), Pixel.Scale(10))

    editor.stageRow = CreateFrame('Frame', nil, stage)
    editor.stageRow:SetPoint('CENTER', stage, 'CENTER', 0, 0)
    editor.stageRow:SetSize(10, 10)

    editor.stageIcon = editor.stageRow:CreateTexture(nil, 'ARTWORK')
    editor.stageIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    editor.stageIconBorder = CreateFrame('Frame', nil, editor.stageRow, 'BackdropTemplate')
    editor.stageIconBorder:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
    editor.stageIconBorder:SetBackdropBorderColor(0, 0, 0, 1)
    editor.stageIconBorder:SetPoint('TOPLEFT', editor.stageIcon, 'TOPLEFT', Pixel.Scale(-1), Pixel.Scale(1))
    editor.stageIconBorder:SetPoint('BOTTOMRIGHT', editor.stageIcon, 'BOTTOMRIGHT', Pixel.Scale(1), Pixel.Scale(-1))

    editor.stageText = editor.stageRow:CreateFontString(nil, 'OVERLAY')

    editor.stageIconTime = editor.stageRow:CreateFontString(nil, 'OVERLAY')
    editor.stageIconTime:SetPoint('CENTER', editor.stageIcon, 'CENTER', 0, 0)
    editor.stageIconTime:Hide()

    editor.stageHint = stage:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(editor.stageHint, 11, BUILib.Font, '')
    editor.stageHint:SetPoint('CENTER')
    editor.stageHint:SetTextColor(0.5, 0.52, 0.58, 1)
    editor.stageHint:Hide()

    editor.stagePulse = editor.stageText:CreateAnimationGroup()
    editor.stagePulse:SetLooping('REPEAT')
    local pOut = editor.stagePulse:CreateAnimation('Alpha')
    pOut:SetFromAlpha(1); pOut:SetToAlpha(0.45); pOut:SetDuration(0.35); pOut:SetOrder(1); pOut:SetSmoothing('IN_OUT')
    local pIn = editor.stagePulse:CreateAnimation('Alpha')
    pIn:SetFromAlpha(0.45); pIn:SetToAlpha(1); pIn:SetDuration(0.35); pIn:SetOrder(2); pIn:SetSmoothing('IN_OUT')

    editor.stageFlash = editor.stageRow:CreateAnimationGroup()
    local blinkSteps = { { 1, 0.4, 0.09 }, { 0.4, 1, 0.12 }, { 1, 0.4, 0.09 }, { 0.4, 1, 0.12 } }
    for i, subtitle in ipairs(blinkSteps) do
        local alphaAnimation = editor.stageFlash:CreateAnimation('Alpha')
        alphaAnimation:SetOrder(i); alphaAnimation:SetSmoothing('IN_OUT')
        alphaAnimation:SetFromAlpha(subtitle[1]); alphaAnimation:SetToAlpha(subtitle[2]); alphaAnimation:SetDuration(subtitle[3])
    end

    editor.stageRowPulse = editor.stageRow:CreateAnimationGroup()
    editor.stageRowPulse:SetLooping('REPEAT')
    local rpOut = editor.stageRowPulse:CreateAnimation('Alpha')
    rpOut:SetFromAlpha(1); rpOut:SetToAlpha(0.45); rpOut:SetDuration(0.35); rpOut:SetOrder(1); rpOut:SetSmoothing('IN_OUT')
    local rpIn = editor.stageRowPulse:CreateAnimation('Alpha')
    rpIn:SetFromAlpha(0.45); rpIn:SetToAlpha(1); rpIn:SetDuration(0.35); rpIn:SetOrder(2); rpIn:SetSmoothing('IN_OUT')

    local chipRow = CreateFrame('Frame', nil, col)
    chipRow:SetPoint('TOPLEFT', stage, 'BOTTOMLEFT', 0, Pixel.Scale(-8))
    chipRow:SetPoint('TOPRIGHT', stage, 'BOTTOMRIGHT', 0, Pixel.Scale(-8))
    chipRow:SetHeight(Pixel.Scale(CHIP_H))

    local gap = Pixel.Scale(8)
    local colW = Pixel.Scale(CONTENT_W)
    local chipW = math.floor((colW - 2 * gap) / 3)
    local chips = {}
    chips.cooldown = MakeChip(chipRow, 'cooldown')
    chips.cooldown:SetPoint('TOPLEFT', 0, 0)
    chips.cooldown:SetWidth(chipW)
    chips.low = MakeChip(chipRow, 'low')
    chips.low:SetPoint('TOPLEFT', chipW + gap, 0)
    chips.low:SetWidth(chipW)
    chips.ready = MakeChip(chipRow, 'ready')
    chips.ready:SetPoint('TOPLEFT', 2 * (chipW + gap), 0)
    chips.ready:SetWidth(colW - 2 * (chipW + gap))
    editor.chips = chips

    local host = CreateFrame('Frame', nil, editor)
    host:SetPoint('TOPLEFT', editor, 'TOPLEFT', 0, -Pixel.Scale(16 + HEADER_H + 10 + STAGE_H + 8 + CHIP_H + 2))
    host:SetPoint('BOTTOMRIGHT', editor, 'BOTTOMRIGHT', 0, 0)

    editor.page = Layout.Page(host, nil, CONTENT_W)
    editor.tab = editor.page:GetTab(1)
    editor.tab.topPadding = 0

    editor.root = CreateFrame('Frame', nil, editor.tab.child)
    editor.root:SetPoint('TOPLEFT', editor.tab.child, 'TOPLEFT', Layout.DEFAULT_PADDING, -4)
    editor.root:SetWidth(CONTENT_W)
    editor.root:SetHeight(1)

    SetScript(editor, 'OnUpdate', EditorDriver)
end

local function FinishClose(frame)
    frame:Hide()
    frame.entry = nil
    frame.spellID = nil
    CDAnnouncer.StopLivePreview()
    RenderList()
    Refresh()
end

function CDAnnouncer.CloseSpellEditor()
    if not editor:IsShown() then return end
    Animation.To(editor, 'alpha', 0, FADE_DURATION, { onComplete = FinishClose })
end

function CDAnnouncer.OpenSpellEditor(spellID)
    spellID = tonumber(spellID)
    if not editor then return end
    local entry = spellID and CDAnnouncer.FindEntry(spellID)
    if not entry then return end
    CDAnnouncer.ApplyEntryDefaults(entry)

    if editor._entryRef ~= entry then
        editor._gen = (editor._gen or 0) + 1
        editor._entryRef = entry
    end
    editor.entry = entry
    editor.spellID = spellID
    editor.rebuildKey = tostring(spellID) .. ':' .. editor._gen
    editor.playPos = 0
    editor.lastStagePhase = nil
    editor.lastChipPhase = nil
    editor.stageIcon._tex = nil
    SetPlaying(true)

    RenderEditor()
    Touch()

    if editor.tab.scroll and editor.tab.scroll.scrollFrame then
        editor.tab.scroll.scrollFrame:SetVerticalScroll(0)
    end
    editor:Show()
    Animation.To(editor, 'alpha', 1, FADE_DURATION)
end

local listRoot, listTab
local hideUnusableRow

local function NameOf(id)
    local entry = CDAnnouncer.FindEntry(tonumber(id))
    if not entry then return nil end
    return select(2, LookupRow(entry))
end

local function AddSpellFeedback(id, isItem)
    id = tonumber(id)
    if not id then
        Toast.Error('Could not add', 'Not a valid spell or item ID.', BarOpts())
        return
    end
    if CDAnnouncer.FindEntry(id) then
        Toast.Warning('Already tracked', NameOf(id), BarOpts())
        return
    end
    if CDAnnouncer.AddSpell(id, isItem) then
        Toast.Success('Spell added', NameOf(id), BarOpts())
        RenderList()
    else
        Toast.Error('Could not add', 'Not a valid spell or item ID.', BarOpts())
    end
end

local function DuplicateSpellFeedback(sourceID, id, isItem)
    id = tonumber(id)
    if not id then
        Toast.Error('Could not duplicate', 'Not a valid spell or item ID.', BarOpts())
        return
    end
    if CDAnnouncer.FindEntry(id) then
        Toast.Warning('Already tracked', NameOf(id), BarOpts())
        return
    end
    local newID = CDAnnouncer.DuplicateSpell(sourceID, id, isItem)
    if newID then
        Toast.Success('Spell duplicated', NameOf(newID), BarOpts())
        RenderList()
        CDAnnouncer.OpenSpellEditor(newID)
    else
        Toast.Error('Could not duplicate', 'Not a valid spell or item ID.', BarOpts())
    end
end

local function RemoveSpellFeedback(id)
    local name = NameOf(id)
    CDAnnouncer.RemoveSpell(id)
    RenderList()
    Toast.Info('Spell removed', name, BarOpts())
end

local function PromptDuplicate(sourceID)
    Modals.Input({
        title = 'Duplicate Spell',
        message = 'Enter a spell or item (ID or link) to track with these settings:',
        confirmText = 'Duplicate',
        parent = BUI.PageEngine.window.frame,
        onConfirm = function(text)
            local id, isItem = BUI.Lookup.ParseSpellOrItemInput(text)
            DuplicateSpellFeedback(sourceID, id, isItem)
        end,
    })
end

local function MoveSpell(id, delta)
    local ids = {}
    for _, editorEntry in ipairs(CDAnnouncer.GetSpells()) do ids[#ids + 1] = editorEntry.spellID end
    local idx
    for i, v in ipairs(ids) do
        if v == id then idx = i break end
    end
    if not idx then return end
    local targetIndex = idx + delta
    if targetIndex < 1 or targetIndex > #ids then return end
    ids[idx], ids[targetIndex] = ids[targetIndex], ids[idx]
    CDAnnouncer.ReorderSpells(ids)
    RenderList()
end

local function ShowSpellContextMenu(rowId)
    if not rowId or not CDAnnouncer.FindEntry(rowId) then return end
    Controls.ContextMenu({
        { text = 'Edit Announcement...',
          callback = function() CDAnnouncer.OpenSpellEditor(rowId) end },
        { text = 'Preview',
          callback = function() CDAnnouncer.PreviewSpell(rowId, 8) end },
        { text = 'Duplicate...',
          callback = function() PromptDuplicate(rowId) end },
        { text = 'Refresh Duration from Tooltip',
          callback = function() CDAnnouncer.RefreshSpellDuration(rowId); RenderList() end },
        { separator = true },
        { text = 'Move Up',
          callback = function() MoveSpell(rowId, -1) end },
        { text = 'Move Down',
          callback = function() MoveSpell(rowId, 1) end },
        { separator = true },
        { text = '|cffff6060Remove|r',
          callback = function() RemoveSpellFeedback(rowId) end },
    }, { width = 230 })
end

local function ListSpec()
    local specs = {}
    local spells = CDAnnouncer.GetSpells()
    if #spells == 0 then
        specs[1] = { type = TInfo, key = 'empty', props = { gap = ROW_GAP,
            make = function(p)
                return Controls.InfoBox(p,
                    'Nothing tracked yet. Drag a spell or item onto the bar above to start announcing its cooldown.',
                    'info', CONTENT_W)
            end } }
        return specs
    end
    for _, entry in ipairs(spells) do
        local icon, name = LookupRow(entry)
        local sub = ListSubtitle(entry)
        local id = entry.spellID
        local editorEntry = entry
        specs[#specs + 1] = { type = TRow, key = 'sp' .. id, props = {
            gap = ROW_GAP,
            rebuildKey = table.concat({ id, entry.kind or 'spell', name, sub }, '|'),
            make = function(p)
                return Controls.SettingRow(p, {
                    width = CONTENT_W,
                    icon = icon,
                    title = name,
                    description = sub,
                    checked = editorEntry.enabled ~= false,
                    callback = function(v) CDAnnouncer.SetSpellEnabled(id, v) end,
                    onRightClick = function() ShowSpellContextMenu(id) end,
                    accessoryWidth = 60,
                    accessories = function(row)
                        local edit = Controls.Icon(row, {
                            texture = BUILib.GetLibMedia('cog'),
                            tooltip = 'Edit announcement',
                            onClick = function() CDAnnouncer.OpenSpellEditor(id) end,
                        })
                        local eye = Controls.Icon(row, {
                            texture = BUILib.GetLibMedia('eye'),
                            tooltip = 'Preview on screen',
                            onClick = function() CDAnnouncer.PreviewSpell(id, 8) end,
                        })
                        return { edit, eye }
                    end,
                })
            end,
            update = function(row) row:SetValue(editorEntry.enabled ~= false) end,
        } }
    end
    return specs
end

RenderList = function()
    Reconciler.Reconcile.Children(listRoot, ListSpec())
    listTab:Refresh()
    BUILib.Defer(function() listTab:Refresh() end)
end

local GROWTH_ITEMS = {
    { value = 'center', text = 'Grow from middle' },
    { value = 'down',   text = 'Grow downward' },
    { value = 'up',     text = 'Grow upward' },
}

local AddRow = PageKit.AddSettingRow
local function BuildMainTab(tab)
    Layout.Section(tab, 'General')

    AddRow(tab, {
        title = 'Appearance & Position',
        description = 'Font, where the anchor sits, and which way rows stack as cooldowns come and go',
        plain = true,
        accessoryWidth = 340,
        accessories = function(row)
            local mover = PageKit.PositionMover(row, {
                get = function(k) return GetCfg()[k] end,
                set = function(k, v) GetCfg()[k] = v end,
                apply = Refresh,
                tooltip = 'Screen position',
                onBuilt = function(xSl, ySl)
                    CDAnnouncer.RegisterPositionCallback(function(x, y)
                        xSl:SetValue(x)
                        ySl:SetValue(y)
                    end)
                end,
            })
            local fdd = Controls.Dropdown(row, nil, fonts, GetCfg().font, function(v)
                GetCfg().font = v
                Refresh()
            end, nil, 150)
            local gdd = Controls.Dropdown(row, nil, GROWTH_ITEMS, GetCfg().growth or 'center', function(v)
                GetCfg().growth = v
                Refresh()
            end, 'Only rows with something to say are shown, in list order. This sets which way they stack from the anchor.', 130)
            return { mover, fdd, gdd }
        end,
    })

    hideUnusableRow = AddRow(tab, {
        title = 'Hide Unusable Spells',
        description = 'Skip announcements for spells you can\'t currently use',
        checked = GetCfg().hideUnusable,
        callback = function(v) GetCfg().hideUnusable = v; Refresh() end,
    })

    Layout.Section(tab, 'Tracked Cooldowns',
        'Rows announce in this order. Click a row to toggle it, the cog to edit its announcement. Right-click to move or remove it.')

    local input = Controls.ItemInput(tab.child, {
        hint = 'Drag a spell or item here, search, or paste a link/ID...',
        width = tab.width,
        height = 30,
        modalParent = BUI.PageEngine.window.frame,
        searchFunc = BUI.Lookup.SearchSpellsAndItems,
        onAdd = function(text)
            local id, isItem = BUI.Lookup.ParseSpellOrItemInput(text)
            AddSpellFeedback(id, isItem)
        end,
        onSearchSelect = function(item)
            if item and item.id then AddSpellFeedback(item.id, item.isItem) end
        end,
    })
    Layout.Add(tab, input, 10)

    listRoot = CreateFrame('Frame', nil, tab.child)
    listRoot:SetWidth(tab.width)
    listRoot:SetHeight(1)
    Layout.Add(tab, listRoot, 10)
    listTab = tab

    RenderList()
end

BUI.PageEngine.RegisterPage('cdAnnouncer', {
    title = 'CD Announcer',
    buttonText = 'CD Announcer',
    minContentWidth  = 924,
    minContentHeight = 620,
    OnBuild = function(pageFrame)
        fonts = BUI.BuildFontDropdownItems('GLOBAL')
        TRow  = TRow or Reconciler.Legacy('SettingRow')
        TCat  = TCat or Reconciler.Legacy('CategoryLabel')
        TInfo = TInfo or Reconciler.Legacy('InfoBox')

        local cfg = GetCfg()
        BUI.Tools.AddPageWatermark(pageFrame)

        local titleH, titleBar = PageKit.PageTitle(pageFrame, 'CD Announcer', CONTENT_W, {
            desc = 'On-screen countdowns and ready alerts for the cooldowns you track.',
            enable = {
                value = cfg.enabled,
                onToggle = function(v)
                    GetCfg().enabled = v
                    Refresh()
                end,
            },
            anchor = {
                value = cfg.showAnchor,
                tooltip = 'Show the anchor (drag it to move the announcements)',
                onToggle = function(v)
                    GetCfg().showAnchor = v
                    Refresh()
                end,
            },
        })
        CDAnnouncer.RegisterAnchorCallback(function(state) titleBar.anchorToggle:SetValue(state) end)

        local host = CreateFrame('Frame', nil, pageFrame)
        host:SetPoint('TOPLEFT', pageFrame, 'TOPLEFT', 0, -(PageKit.PAD + titleH))
        host:SetPoint('BOTTOMRIGHT', pageFrame, 'BOTTOMRIGHT', 0, 0)

        local page = Layout.Page(host, nil, CONTENT_W)
        pageFrame._page = page
        local tab = page:GetTab(1)
        tab.topPadding = 0
        BuildMainTab(tab)
        page:AutoRefresh()

        BuildEditor(pageFrame)

        SetScript(pageFrame, 'OnShow', function()
            titleBar.enableToggle:SetValue(GetCfg().enabled)
            titleBar.anchorToggle:SetValue(GetCfg().showAnchor)
            hideUnusableRow:SetValue(GetCfg().hideUnusable)
            RenderList()
        end)
    end,
    OnHide = function()
        editor:Hide()
        editor:SetAlpha(0)
        editor.entry = nil
        editor.spellID = nil
        CDAnnouncer.StopLivePreview()
    end,
})
