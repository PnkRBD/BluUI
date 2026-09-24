local BUI = BluUI

local BUILib = BluUI.BUILibClient
local Layout, Controls = BUILib.Layout, BUILib.Controls
local PageKit = BUILib.PageKit

local BuffTracking = BUI.BuffTracking
local Display = BuffTracking.Display
local KillCommandOverlay = BuffTracking.KillCommandOverlay

local fonts
local registeredCallbackKeys = {}

local function RefreshTracker(settingsKey)
    local tracker = Display.GetTracker(settingsKey)
    if tracker then tracker.Refresh() end
end

local RefreshKillCommandOverlay = KillCommandOverlay.Refresh

local function SpellIcon(spellID)
    return C_Spell.GetSpellTexture(spellID)
end

local AddRow = PageKit.AddSettingRow

local function EyeAccessory(row, settingsKey)
    local function GetSettings() return BUI.GetDB()[settingsKey] end
    local anchorToggle = Controls.IconToggle(row, GetSettings().showAnchor, function(value)
        GetSettings().showAnchor = value
        RefreshTracker(settingsKey)
    end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Unlock (drag to move)' })
    Display.RegisterAnchorCallback(settingsKey, function(state) anchorToggle:SetValue(state) end)
    registeredCallbackKeys[settingsKey] = true
    return anchorToggle
end

local function TrackerRow(tab, settingsKey, frameName, rowDef, accessoryWidth, BuildAccessories)
    local function GetSettings() return BUI.GetDB()[settingsKey] end
    local function Refresh() RefreshTracker(settingsKey) end

    AddRow(tab, {
        title = rowDef.title,
        description = rowDef.description,
        icon = rowDef.icon,
        checked = GetSettings().enabled,
        callback = function(value)
            GetSettings().enabled = value
            Refresh()
        end,
        accessoryWidth = accessoryWidth,
        accessories = function(row)
            local anchorToggle = EyeAccessory(row, settingsKey)
            local mover = BUI.AlertMover(row, GetSettings(), Refresh, { selfTag = frameName, noCenter = rowDef.noCenter })
            return BuildAccessories(row, GetSettings, Refresh, anchorToggle, mover)
        end,
    })
end

local function TextTrackerRow(tab, settingsKey, frameName, rowDef)
    TrackerRow(tab, settingsKey, frameName, rowDef, 270, function(row, GetSettings, Refresh, anchorToggle, mover)
        local options = {
            { kind = 'textbox', label = rowDef.textLabel or 'Custom Text',
              get = function() return GetSettings().customText end,
              set = function(value) GetSettings().customText = value end, apply = Refresh },
        }
        if rowDef.altTextLabel then
            options[#options + 1] = { kind = 'textbox', label = rowDef.altTextLabel,
              get = function() return GetSettings().customTextAlt end,
              set = function(value) GetSettings().customTextAlt = value end, apply = Refresh }
        end
        options[#options + 1] = { kind = 'slider', label = 'Text Size', min = 10, max = 48,
          get = function() return GetSettings().textSize end,
          set = function(value) GetSettings().textSize = value end, apply = Refresh }
        options[#options + 1] = { kind = 'dropdown', label = 'Sound', items = BUI.BuildSoundDropdownItems(),
          get = function() return GetSettings().sound end,
          set = function(value) GetSettings().sound = value; BUI.PlaySoundByName(value) end }
        if rowDef.extraOptions then
            for _, option in ipairs(rowDef.extraOptions(GetSettings, Refresh)) do
                options[#options + 1] = option
            end
        end

        local settingsIcon = PageKit.SettingsIcon(row, {
            title = rowDef.title:upper(), tooltip = 'Text & sound', options = options,
        })
        local fontDropdown = Controls.Dropdown(row, nil, fonts, GetSettings().font, function(value)
            GetSettings().font = value
            Refresh()
        end, nil, 140)
        local textColor = GetSettings().textColor
        local colorSwatch = Controls.ColorSwatch(row, { r = textColor.r, g = textColor.g, b = textColor.b, a = textColor.a,
            tooltip = 'Text Color',
            callback = function(red, green, blue, alpha)
                GetSettings().textColor = { r = red, g = green, b = blue, a = alpha }
                Refresh()
            end })
        return { anchorToggle, mover, settingsIcon, fontDropdown, colorSwatch }
    end)
end

local function StackTrackerRow(tab, settingsKey, frameName, maxStacks, rowDef)
    TrackerRow(tab, settingsKey, frameName, rowDef, 220, function(row, GetSettings, Refresh, anchorToggle, mover)
        local settingsIcon = PageKit.SettingsIcon(row, {
            title = rowDef.title:upper(), tooltip = 'Display, bars & text',
            options = {
                { label = 'Bar Mode',
                  get = function() return GetSettings().displayMode == 'BARS' end,
                  set = function(value) GetSettings().displayMode = value and 'BARS' or 'TEXT' end, apply = Refresh,
                  swatch = function()
                      local color = GetSettings().filledColor
                      return { r = color.r, g = color.g, b = color.b, a = color.a, tooltip = 'Filled Color',
                          callback = function(red, green, blue, alpha) GetSettings().filledColor = { r = red, g = green, b = blue, a = alpha }; Refresh() end }
                  end },
                { label = 'Hide When No Stacks',
                  get = function() return GetSettings().hideWhenEmpty end,
                  set = function(value) GetSettings().hideWhenEmpty = value end, apply = Refresh,
                  swatch = function()
                      local color = GetSettings().emptyColor
                      return { r = color.r, g = color.g, b = color.b, a = color.a, tooltip = 'Empty Color',
                          callback = function(red, green, blue, alpha) GetSettings().emptyColor = { r = red, g = green, b = blue, a = alpha }; Refresh() end }
                  end },
                { label = 'Show Only in Combat',
                  get = function() return GetSettings().showOnlyInCombat end,
                  set = function(value) GetSettings().showOnlyInCombat = value end, apply = Refresh },
                { label = 'Color by Stack Count',
                  get = function() return GetSettings().colorByStacks end,
                  set = function(value) GetSettings().colorByStacks = value end, apply = Refresh },
                { kind = 'slider', label = 'Bar Width', min = 30, max = 200,
                  get = function() return GetSettings().barWidth end,
                  set = function(value) GetSettings().barWidth = value end, apply = Refresh },
                { kind = 'slider', label = 'Bar Height', min = 4, max = 50,
                  get = function() return GetSettings().barHeight end,
                  set = function(value) GetSettings().barHeight = value end, apply = Refresh },
                { kind = 'slider', label = 'Bar Spacing', min = 0, max = 20,
                  get = function() return GetSettings().barSpacing end,
                  set = function(value) GetSettings().barSpacing = value end, apply = Refresh },
                { kind = 'slider', label = 'Border Thickness', min = 0, max = 4,
                  get = function() return GetSettings().borderThickness end,
                  set = function(value) GetSettings().borderThickness = value end, apply = Refresh,
                  swatch = function()
                      local color = GetSettings().borderColor
                      return { r = color.r, g = color.g, b = color.b, a = color.a, tooltip = 'Border Color',
                          callback = function(red, green, blue, alpha) GetSettings().borderColor = { r = red, g = green, b = blue, a = alpha }; Refresh() end }
                  end },
                { kind = 'slider', label = 'Text Size', min = 10, max = 48,
                  get = function() return GetSettings().textSize end,
                  set = function(value) GetSettings().textSize = value end, apply = Refresh },
                { kind = 'dropdown', label = 'Font', items = fonts,
                  get = function() return GetSettings().font end,
                  set = function(value) GetSettings().font = value end, apply = Refresh },
            },
        })

        local accessoryList = { anchorToggle, mover, settingsIcon }
        for stackIndex = maxStacks, 1, -1 do
            local colorKey = 'stack' .. stackIndex .. 'Color'
            local color = GetSettings()[colorKey]
            accessoryList[#accessoryList + 1] = Controls.ColorSwatch(row, { r = color.r, g = color.g, b = color.b, a = color.a,
                tooltip = stackIndex == 1 and '1 Stack' or (stackIndex .. ' Stacks'),
                callback = function(red, green, blue, alpha)
                    GetSettings()[colorKey] = { r = red, g = green, b = blue, a = alpha }
                    Refresh()
                end })
        end
        return accessoryList
    end)
end

local function SmartMisdirectRow(tab)
    local function GetSettings() return BUI.GetDB().smartMisdirect end
    local SmartMisdirect = BuffTracking.SmartMisdirect
    local Refresh = SmartMisdirect.Refresh
    local CreateMacro = SmartMisdirect.CreateMacro
    local tankMethodItems = SmartMisdirect.TANK_METHOD_ITEMS

    AddRow(tab, {
        title = 'Smart Misdirection',
        description = 'Bind it in Key Bindings or macro "/click BUI_SmartMisdirect LeftButton"; it aims at your override, focus, tank or pet. Right click a group member to pin it to them.',
        icon = SpellIcon(34477),
        checked = GetSettings().enabled,
        callback = function(value)
            GetSettings().enabled = value
            Refresh()
        end,
        accessoryWidth = 40,
        accessories = function(row)
            return { PageKit.SettingsIcon(row, { title = 'SMART MISDIRECTION', tooltip = 'Target priority', width = 300, options = {
                { kind = 'textbox', label = 'MD Override Target',
                  get = function() return GetSettings().overrideName end,
                  set = function(value)
                      GetSettings().overrideName = value
                      GetSettings().overrideRealm = ''
                      Refresh()
                  end },
                { kind = 'checkbox', label = 'Use Focus',
                  get = function() return GetSettings().useFocus end,
                  set = function(value) GetSettings().useFocus = value; Refresh() end },
                { kind = 'checkbox', label = 'Prefer Tank',
                  get = function() return GetSettings().preferTank end,
                  set = function(value) GetSettings().preferTank = value; Refresh() end },
                { kind = 'dropdown', label = 'Tank Selection', items = tankMethodItems,
                  get = function() return GetSettings().tankMethod end,
                  set = function(value) GetSettings().tankMethod = value; Refresh() end },
                { kind = 'checkbox', label = 'Fall Back To Pet',
                  get = function() return GetSettings().fallbackPet end,
                  set = function(value) GetSettings().fallbackPet = value; Refresh() end },
                { kind = 'button', label = 'Macro', text = 'Create Macro', set = CreateMacro },
            } }) }
        end,
    })
end

local function PackLeaderRow(tab)
    local rowDef = {
        title = 'Pack Leader',
        description = 'Beast cycle icon with cooldown countdown and next-beast preview',
        icon = SpellIcon(471876),
        noCenter = true,
    }
    TrackerRow(tab, 'packLeader', 'BUI_PackLeader', rowDef, 220, function(row, GetSettings, Refresh, anchorToggle, mover)
        local sizeIcon = PageKit.SizeIcon(row, {
            title = 'PACK LEADER', tooltip = 'Icon sizes & spacing',
            options = {
                { kind = 'slider', label = 'Main Icon Size', min = 16, max = 64,
                  get = function() return GetSettings().iconSize end,
                  set = function(value) GetSettings().iconSize = value end, apply = Refresh },
                { kind = 'slider', label = 'Next Icon Size', min = 8, max = 64,
                  get = function() return GetSettings().nextIconSize end,
                  set = function(value) GetSettings().nextIconSize = value end, apply = Refresh },
                { kind = 'slider', label = 'Spacing', min = 0, max = 16,
                  get = function() return GetSettings().spacing end,
                  set = function(value) GetSettings().spacing = value end, apply = Refresh },
                { kind = 'slider', label = 'Label Size', min = 6, max = 32,
                  get = function() return GetSettings().labelTextSize end,
                  set = function(value) GetSettings().labelTextSize = value end, apply = Refresh },
            },
        })

        local settingsIcon = PageKit.SettingsIcon(row, {
            title = 'PACK LEADER', tooltip = 'Effects & labels',
            options = {
                { label = 'Show Only in Combat',
                  get = function() return GetSettings().showOnlyInCombat end,
                  set = function(value) GetSettings().showOnlyInCombat = value end, apply = Refresh },
                { label = 'Glow When Ready',
                  get = function() return GetSettings().glowOnReady end,
                  set = function(value) GetSettings().glowOnReady = value end, apply = Refresh },
                { label = 'Animate Transitions',
                  get = function() return GetSettings().animateTransitions end,
                  set = function(value) GetSettings().animateTransitions = value end },
                { label = 'Show Countdown Text',
                  get = function() return GetSettings().showCountdownText end,
                  set = function(value) GetSettings().showCountdownText = value end, apply = Refresh },
                { label = "Show 'Next' / 'USE!' Text",
                  get = function() return GetSettings().showNextText end,
                  set = function(value) GetSettings().showNextText = value end, apply = Refresh },
                { label = 'Show Next Icon',
                  get = function() return GetSettings().showNextIcon end,
                  set = function(value) GetSettings().showNextIcon = value end, apply = Refresh },
                { kind = 'slider', label = 'Top Text X', min = -50, max = 50,
                  get = function() return GetSettings().topTextOffsetX end,
                  set = function(value) GetSettings().topTextOffsetX = value end, apply = Refresh },
                { kind = 'slider', label = 'Top Text Y', min = -50, max = 50,
                  get = function() return GetSettings().topTextOffsetY end,
                  set = function(value) GetSettings().topTextOffsetY = value end, apply = Refresh },
                { kind = 'slider', label = 'Bottom Text X', min = -50, max = 50,
                  get = function() return GetSettings().bottomTextOffsetX end,
                  set = function(value) GetSettings().bottomTextOffsetX = value end, apply = Refresh },
                { kind = 'slider', label = 'Bottom Text Y', min = -50, max = 50,
                  get = function() return GetSettings().bottomTextOffsetY end,
                  set = function(value) GetSettings().bottomTextOffsetY = value end, apply = Refresh },
            },
        })

        local function BeastSwatch(beastKey, label)
            local currentColor = GetSettings().beastColors[beastKey]
            return Controls.ColorSwatch(row, { r = currentColor.r, g = currentColor.g, b = currentColor.b, a = 1,
                tooltip = label,
                callback = function(red, green, blue)
                    GetSettings().beastColors[beastKey] = { r = red, g = green, b = blue }
                    Refresh()
                    RefreshKillCommandOverlay()
                end })
        end

        return { anchorToggle, mover, sizeIcon, settingsIcon, BeastSwatch('wyvern', 'Wyvern'), BeastSwatch('bear', 'Bear'), BeastSwatch('boar', 'Boar') }
    end)
end

local function KillCommandOverlayRow(tab)
    local function GetSettings() return BUI.GetDB().killCommandOverlay end
    local Refresh = RefreshKillCommandOverlay

    AddRow(tab, {
        title = 'Pack Leader Overlay on KC',
        description = 'Pack Leader countdown and beast label on the Kill Command icon',
        icon = SpellIcon(34026),
        checked = GetSettings().enabled,
        callback = function(value)
            GetSettings().enabled = value
            Refresh()
        end,
        accessoryWidth = 90,
        accessories = function(row)
            local preview = Controls.IconToggle(row, KillCommandOverlay.IsPreviewing(), function(value)
                if value then KillCommandOverlay.StartPreview() else KillCommandOverlay.StopPreview() end
            end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Preview' })

            local settingsIcon = PageKit.SettingsIcon(row, {
                title = 'PACK LEADER OVERLAY ON KC', tooltip = 'Timer & beast label',
                options = {
                    { label = 'Show Timer',
                      get = function() return GetSettings().showTimer end,
                      set = function(value) GetSettings().showTimer = value end, apply = Refresh,
                      swatch = function()
                          local timerColor = GetSettings().timerColor
                          return { r = timerColor.r, g = timerColor.g, b = timerColor.b, a = 1, tooltip = 'Timer Color',
                              callback = function(red, green, blue) GetSettings().timerColor = { r = red, g = green, b = blue }; Refresh() end }
                      end },
                    { label = 'Show Beast Name',
                      get = function() return GetSettings().showBeastName end,
                      set = function(value) GetSettings().showBeastName = value end, apply = Refresh },
                    { label = 'Show Decimals',
                      get = function() return GetSettings().showDecimals end,
                      set = function(value) GetSettings().showDecimals = value end, apply = Refresh },
                    { kind = 'slider', label = 'Decimal Threshold', min = 1, max = 10,
                      get = function() return GetSettings().decimalThreshold end,
                      set = function(value) GetSettings().decimalThreshold = value end, apply = Refresh },
                    { kind = 'slider', label = 'Timer Size', min = 6, max = 72,
                      get = function() return GetSettings().timerSize end,
                      set = function(value) GetSettings().timerSize = value end, apply = Refresh },
                    { kind = 'dropdown', label = 'Timer Anchor', items = BUI.C.ANCHOR_POINT_OPTIONS,
                      get = function() return GetSettings().timerAnchor end,
                      set = function(value) GetSettings().timerAnchor = value end, apply = Refresh },
                    { kind = 'slider', label = 'Timer X', min = -30, max = 30,
                      get = function() return GetSettings().timerOffsetX end,
                      set = function(value) GetSettings().timerOffsetX = value end, apply = Refresh },
                    { kind = 'slider', label = 'Timer Y', min = -30, max = 30,
                      get = function() return GetSettings().timerOffsetY end,
                      set = function(value) GetSettings().timerOffsetY = value end, apply = Refresh },
                    { kind = 'slider', label = 'Beast Name Size', min = 6, max = 24,
                      get = function() return GetSettings().beastSize end,
                      set = function(value) GetSettings().beastSize = value end, apply = Refresh },
                    { kind = 'dropdown', label = 'Beast Anchor', items = BUI.C.ANCHOR_POINT_OPTIONS,
                      get = function() return GetSettings().beastAnchor end,
                      set = function(value) GetSettings().beastAnchor = value end, apply = Refresh },
                    { kind = 'slider', label = 'Beast X', min = -30, max = 30,
                      get = function() return GetSettings().beastOffsetX end,
                      set = function(value) GetSettings().beastOffsetX = value end, apply = Refresh },
                    { kind = 'slider', label = 'Beast Y', min = -30, max = 30,
                      get = function() return GetSettings().beastOffsetY end,
                      set = function(value) GetSettings().beastOffsetY = value end, apply = Refresh },
                },
            })
            return { preview, settingsIcon }
        end,
    })
end

local function BestialWrathOverlayRow(tab)
    local function GetSettings() return BUI.GetDB().bestialWrathOverlay end
    local Refresh = BuffTracking.BestialWrathOverlay.Refresh

    AddRow(tab, {
        title = 'Bestial Wrath AoE Callout',
        description = 'HOLD BW / SEND BW / THRASH! on the BW icon or on screen (needs Wild Thrash)',
        icon = SpellIcon(19574),
        checked = GetSettings().enabled,
        callback = function(value)
            GetSettings().enabled = value
            Refresh()
        end,
        accessoryWidth = 90,
        accessories = function(row)
            local Overlay = BuffTracking.BestialWrathOverlay
            local preview = Controls.IconToggle(row, Overlay.IsPreviewing(), function(value)
                if value then Overlay.StartPreview() else Overlay.StopPreview() end
            end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Preview' })

            local settingsIcon = PageKit.SettingsIcon(row, {
                title = 'BESTIAL WRATH AOE CALLOUT', tooltip = 'Text & hints', width = 320,
                options = {
                    { kind = 'dropdown', label = 'Display', items = {
                        { value = 'icon',   text = 'On BW Icon' },
                        { value = 'screen', text = 'On Screen' },
                        { value = 'both',   text = 'Both' },
                      },
                      get = function() return GetSettings().displayMode end,
                      set = function(value) GetSettings().displayMode = value end, apply = Refresh },
                    { label = 'Text To Speech',
                      get = function() return GetSettings().tts end,
                      set = function(value) GetSettings().tts = value end, apply = Refresh },
                    { label = 'Speak Hold Cues',
                      get = function() return GetSettings().ttsHold end,
                      set = function(value) GetSettings().ttsHold = value end, apply = Refresh },
                    { label = 'Hold Thrash Hint (BW 10-13s)',
                      get = function() return GetSettings().showHoldThrash end,
                      set = function(value) GetSettings().showHoldThrash = value end, apply = Refresh },
                    { label = 'Unlock Screen Text',
                      get = function() return GetSettings().screenLocked == false end,
                      set = function(value) GetSettings().screenLocked = not value end, apply = Refresh },
                    { label = 'Screen Text In Combat Only',
                      get = function() return GetSettings().screenCombatOnly end,
                      set = function(value) GetSettings().screenCombatOnly = value end, apply = Refresh },
                    { kind = 'slider', label = 'Screen Size', min = 12, max = 64,
                      get = function() return GetSettings().screenTextSize end,
                      set = function(value) GetSettings().screenTextSize = value end, apply = Refresh },
                    { kind = 'slider', label = 'Icon Size', min = 6, max = 32,
                      get = function() return GetSettings().textSize end,
                      set = function(value) GetSettings().textSize = value end, apply = Refresh },
                    { kind = 'dropdown', label = 'Icon Anchor', items = BUI.C.ANCHOR_POINT_OPTIONS,
                      get = function() return GetSettings().textAnchor end,
                      set = function(value) GetSettings().textAnchor = value end, apply = Refresh },
                    { kind = 'slider', label = 'Icon X', min = -30, max = 30,
                      get = function() return GetSettings().textOffsetX end,
                      set = function(value) GetSettings().textOffsetX = value end, apply = Refresh },
                    { kind = 'slider', label = 'Icon Y', min = -30, max = 30,
                      get = function() return GetSettings().textOffsetY end,
                      set = function(value) GetSettings().textOffsetY = value end, apply = Refresh },
                },
            })
            return { preview, settingsIcon }
        end,
    })
end

BUI.PageEngine.RegisterPage("buffTracking", {
    title = "Buff Tracking",
    buttonText = "Buff Tracking",
    OnBuild = function(pageFrame)
        fonts = BUI.BuildFontDropdownItems('GLOBAL')

        local Hunter, Monk = BuffTracking.Hunter, BuffTracking.Monk

        local isSurvival = Hunter.IsSurvivalHunter()
        local isMarksmanship = Hunter.IsMarksmanshipHunter()
        local isBeastMastery = Hunter.IsBeastMastery()
        local isMistweaver = Monk.IsMistweaver()

        local page = Layout.Page(pageFrame, nil)
        pageFrame._page = page
        local tab = page:GetTab(1)

        if isBeastMastery then
            Layout.Section(tab, 'Pack Leader')
            PackLeaderRow(tab)
            KillCommandOverlayRow(tab)

            Layout.Section(tab, 'Procs')
            TextTrackerRow(tab, 'hunterKillCommand', 'BUI_BuffTrackingHunterKC', {
                title = 'Kill Command',
                description = 'Text alert when Kill Command procs',
                icon = SpellIcon(34026),
            })
            TextTrackerRow(tab, 'hunterCobraFang', 'BUI_BuffTrackingHunterCF', {
                title = 'Cobra Fang',
                description = 'Live tier set stack count, spent by Cobra Shot (max 4)',
                icon = SpellIcon(193455),
            })

            Layout.Section(tab, 'AoE Burst')
            BestialWrathOverlayRow(tab)
        elseif isSurvival then
            Layout.Section(tab, 'Procs')
            StackTrackerRow(tab, 'hunterTip', 'BUI_BuffTrackingHunterTip', 3, {
                title = 'Tip of the Spear',
                description = 'Stack bars for Tip of the Spear (max 3)',
                icon = SpellIcon(260286),
            })
            TextTrackerRow(tab, 'hunterRaptorSwipe', 'BUI_BuffTrackingHunterRS', {
                title = 'Raptor Swipe',
                description = 'Text alert while Raptor Swipe is active',
                icon = SpellIcon(1273155),
                textLabel = 'Text (default)',
                altTextLabel = 'Text (no Tip stacks)',
            })
            TextTrackerRow(tab, 'hunterRaptorPrompt', 'BUI_BuffTrackingHunterRaptorPrompt', {
                title = 'Raptor Prompt',
                description = 'Reminder to cast Raptor Strike when nothing else is up',
                icon = SpellIcon(186270),
            })
            Layout.Section(tab, 'Pack Leader')
            PackLeaderRow(tab)
            KillCommandOverlayRow(tab)
        elseif isMarksmanship then
            Layout.Section(tab, 'Procs')
            TextTrackerRow(tab, 'hunterPreciseShots', 'BUI_BuffTrackingHunterPS', {
                title = 'Precise Shots',
                description = 'Text alert while Precise Shots is active',
                icon = SpellIcon(260242),
            })
            TextTrackerRow(tab, 'hunterLockAndLoad', 'BUI_BuffTrackingHunterLnL', {
                title = 'Lock and Load',
                description = 'Text alert when Lock and Load procs',
                icon = SpellIcon(194594),
            })
            TextTrackerRow(tab, 'hunterBulletstorm', 'BUI_BuffTrackingHunterBS', {
                title = 'Bulletstorm',
                description = 'Empowered Aimed Shots remaining after Rapid Fire',
                icon = SpellIcon(389019),
            })
        end

        if isBeastMastery or isSurvival or isMarksmanship then
            Layout.Section(tab, 'Utility')
            SmartMisdirectRow(tab)
            TextTrackerRow(tab, 'misdirectAlert', 'BUI_MisdirectAlert', {
                title = 'Misdirect Alert',
                description = 'On screen text naming your current Misdirection target',
                icon = SpellIcon(34477),
                textLabel = 'Prefix',
                extraOptions = function(GetSettings, Refresh)
                    return {
                        { kind = 'dropdown', label = 'Display', items = {
                            { value = 'flash', text = 'Flash Briefly' },
                            { value = 'stay',  text = 'Stay On Screen' },
                          },
                          get = function() return GetSettings().alertMode end,
                          set = function(value) GetSettings().alertMode = value; Refresh() end },
                        { kind = 'slider', label = 'Flash Seconds', min = 1, max = 10,
                          get = function() return GetSettings().flashSeconds end,
                          set = function(value) GetSettings().flashSeconds = value end, apply = Refresh },
                        { kind = 'checkbox', label = 'Flash On Cast',
                          get = function() return GetSettings().flashOnCast end,
                          set = function(value) GetSettings().flashOnCast = value end },
                        { kind = 'checkbox', label = 'Flash On Target Change',
                          get = function() return GetSettings().flashOnTargetChange end,
                          set = function(value) GetSettings().flashOnTargetChange = value end },
                    }
                end,
            })
        end

        if isMistweaver then
            Layout.Section(tab, 'Mistweaver')
            TextTrackerRow(tab, 'monkVivaciousVivification', 'BUI_MonkVivaciousVivification', {
                title = 'Vivacious Vivification',
                description = 'Reminder when your instant Vivify is ready',
                icon = SpellIcon(392883),
            })
        elseif not (isBeastMastery or isSurvival or isMarksmanship) then
            Layout.Section(tab, 'Buff Tracking')
            AddRow(tab, {
                title = 'Not Available',
                description = 'Buff tracking is only available for Hunter and Mistweaver Monk specs.',
                plain = true,
            })
        end

        page:AutoRefresh()
    end,
    OnHide = function()
        if KillCommandOverlay.IsPreviewing() then KillCommandOverlay.StopPreview() end
        if BuffTracking.BestialWrathOverlay.IsPreviewing() then BuffTracking.BestialWrathOverlay.StopPreview() end
        for key in pairs(registeredCallbackKeys) do Display.UnregisterAnchorCallback(key) end
        wipe(registeredCallbackKeys)
    end,
})

BUI.Events:Register("PLAYER_SPECIALIZATION_CHANGED", "BuffTrackingPage", function(_, unit)
    if unit ~= "player" then return end
    C_Timer.After(0.3, function()
        local pageConfig = BUI.PageEngine.pages.buffTracking
        if pageConfig.frame then pageConfig.stale = true end
        if BUI.PageEngine.GetCurrentPage() == "buffTracking" then
            BUI.PageEngine.RefreshCurrentPage()
        end
    end)
end)
