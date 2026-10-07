local _, BUI = ...

local Datatext = BUI.Datatext
local Pixel = BUI.Pixel
local BUILib = LibStub('BUILib')
local Controls = BUILib.Controls
local Widget = BUILib.Widget

local CURRENT_SPEC_ICON = 132222
local PANEL_WIDTH = 230
local PANEL_PAD = 10
local MAX_SPECS = 4
local ICON_TOP = 30
local ICON_SIZE = 30
local ICON_GAP = 6
local INACTIVE_ALPHA = 0.5
local ROW_TOP = 70
local ROW_HEIGHT = 22
local ROW_GAP = 2
local ROW_INSET = 4
local ROW_RADIUS = 6
local CHEVRON_SIZE = 9
local CHEVRON_ROTATION = math.pi / 2
local NOTE_HEIGHT = 16
local BOTTOM_PAD = 10
local MENU_WIDTH = 220
local FLYOUT_GAP = 6
local STARTER_BUILD = 'Starter Build'
local DEFAULT_LOADOUT = 'Default Loadout'
local SOLID, CLEAR = { 1, 1, 1, 1 }, { 0, 0, 0, 0 }

local lootSpecName, currentSpecName = '', ''
local specPanel
local pendingSpecID, pendingConfigID, pendingUnflag

local function CurrentSpecInfo()
    local specIndex = GetSpecialization()
    if not specIndex then return nil, 'None' end
    local specID, name = GetSpecializationInfo(specIndex)
    return specID, name or '?'
end

local function Read()
    local _, current = CurrentSpecInfo()
    local loot
    local lootSpecID = GetLootSpecialization()
    if lootSpecID == 0 then
        loot = current
    else
        local _, name = GetSpecializationInfoByID(lootSpecID)
        loot = name or '?'
    end
    if loot ~= lootSpecName or current ~= currentSpecName then
        lootSpecName, currentSpecName = loot, current
        return true
    end
end

local function ActiveText(text, isActive)
    if not isActive then return text end
    local red, green, blue = BUILib.Theme.GetAccent()
    return '|cff' .. BUI.Hex(red, green, blue) .. text .. '|r'
end

local function ShowError(message)
    if message and message ~= '' then UIErrorsFrame:AddExternalErrorMessage(message) end
end

local function MenuOptions(anchor)
    local screenScale = UIParent:GetEffectiveScale() / anchor:GetEffectiveScale()
    local openLeft = anchor:GetRight() + FLYOUT_GAP + MENU_WIDTH > UIParent:GetRight() * screenScale
    local _, centerY = anchor:GetCenter()
    local vertical = centerY < UIParent:GetTop() * screenScale / 2 and 'BOTTOM' or 'TOP'
    return {
        anchor = anchor, width = MENU_WIDTH, offsetY = 0,
        point = vertical .. (openLeft and 'RIGHT' or 'LEFT'),
        relPt = vertical .. (openLeft and 'LEFT' or 'RIGHT'),
        offsetX = openLeft and -FLYOUT_GAP or FLYOUT_GAP,
    }
end

local function OpenLootSpecMenu(anchor)
    if InCombatLockdown() then return end
    local lootSpecID = GetLootSpecialization()
    local _, currentName = CurrentSpecInfo()
    local items = {
        { title = 'Loot Specialization' },
        {
            text = ActiveText('Current Specialization (' .. currentName .. ')', lootSpecID == 0),
            icon = CURRENT_SPEC_ICON,
            callback = function() SetLootSpecialization(0) end,
        },
        { separator = true },
    }
    for specIndex = 1, GetNumSpecializations() do
        local specID, name, _, icon = GetSpecializationInfo(specIndex)
        if specID then
            items[#items + 1] = {
                text = ActiveText(name, lootSpecID == specID),
                icon = icon,
                callback = function() SetLootSpecialization(specID) end,
            }
        end
    end
    Controls.ContextMenu(items, MenuOptions(anchor))
end

local function ActiveLoadoutName(specID)
    if C_ClassTalents.GetStarterBuildActive() then return STARTER_BUILD end
    local configID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    local info = configID and C_Traits.GetConfigInfo(configID)
    return info and info.name or DEFAULT_LOADOUT
end

local function ClearPendingLoadout()
    pendingSpecID, pendingConfigID, pendingUnflag = nil, nil, nil
end

local function FinishLoadout(specID, configID, unflagStarter)
    C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, configID)
    if unflagStarter then C_ClassTalents.SetStarterBuildActive(false) end
end

local function LoadLoadout(specID, configID)
    local unflagStarter = C_ClassTalents.GetStarterBuildActive()
    local result, changeError = C_ClassTalents.LoadConfig(configID, true)
    if result == Enum.LoadConfigResult.Error then
        ShowError(changeError)
    elseif result == Enum.LoadConfigResult.NoChangesNecessary then
        FinishLoadout(specID, configID, unflagStarter)
    else
        pendingSpecID, pendingConfigID, pendingUnflag = specID, configID, unflagStarter
    end
end

local function OnConfigCommitted()
    if not pendingConfigID then return end
    FinishLoadout(pendingSpecID, pendingConfigID, pendingUnflag)
    ClearPendingLoadout()
end

local function OpenLoadoutMenu(anchor)
    if InCombatLockdown() then return end
    local specID = CurrentSpecInfo()
    if not specID then return end
    local starterActive = C_ClassTalents.GetStarterBuildActive()
    local selectedID = not starterActive and C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    local items = { { title = 'Loadouts' } }
    if C_ClassTalents.GetHasStarterBuild() then
        items[#items + 1] = {
            text = STARTER_BUILD,
            checked = starterActive,
            callback = function()
                if not C_ClassTalents.GetStarterBuildActive() then C_ClassTalents.SetStarterBuildActive(true) end
            end,
        }
    end
    for _, configID in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID)) do
        local info = C_Traits.GetConfigInfo(configID)
        if info then
            items[#items + 1] = {
                text = info.name,
                checked = configID == selectedID,
                callback = function() LoadLoadout(specID, configID) end,
            }
        end
    end
    if #items == 1 then items[2] = { text = 'No saved loadouts', disabled = true } end
    Controls.ContextMenu(items, MenuOptions(anchor))
end

local function ActivateSpec(specIndex)
    if specIndex == GetSpecialization() then return end
    if InCombatLockdown() then
        ShowError(ERR_NOT_IN_COMBAT)
        return
    end
    local canUse, failureReason = C_SpecializationInfo.CanPlayerUseTalentSpecUI()
    if not canUse then
        ShowError(failureReason)
        return
    end
    C_SpecializationInfo.SetSpecialization(specIndex)
end

local function SpecButtonEnter(button)
    button:SetAlpha(1)
    GameTooltip:SetOwner(button, 'ANCHOR_TOP')
    GameTooltip:SetText(button.specName, 1, 1, 1)
    if button.active then
        GameTooltip:AddLine('Active specialization', 0.7, 0.7, 0.7)
    else
        GameTooltip:AddLine('Click to switch', 1, 0.82, 0)
    end
    GameTooltip:Show()
end

local function SpecButtonLeave(button)
    button:SetAlpha(button.active and 1 or INACTIVE_ALPHA)
    GameTooltip:Hide()
end

local function SpecButtonClick(button)
    ActivateSpec(button.specIndex)
end

local function CreateSpecButton(panel, specIndex)
    local button = CreateFrame('Button', nil, panel)
    button:SetSize(Pixel.Scale(ICON_SIZE), Pixel.Scale(ICON_SIZE))
    button:SetPoint('TOPLEFT', Pixel.Scale(PANEL_PAD + (specIndex - 1) * (ICON_SIZE + ICON_GAP)), Pixel.Scale(-ICON_TOP))
    Pixel.ApplyBorder(button, 1)
    local edge = Pixel.GetBorderSize(button)
    button.icon = button:CreateTexture(nil, 'ARTWORK')
    button.icon:SetPoint('TOPLEFT', edge, -edge)
    button.icon:SetPoint('BOTTOMRIGHT', -edge, edge)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.specIndex = specIndex
    button:SetScript('OnEnter', BUI.Profiler.Script('Datatext.LootSpec spec OnEnter', SpecButtonEnter))
    button:SetScript('OnLeave', BUI.Profiler.Script('Datatext.LootSpec spec OnLeave', SpecButtonLeave))
    button:SetScript('OnClick', BUI.Profiler.Script('Datatext.LootSpec spec OnClick', SpecButtonClick))
    return button
end

local function RowEnter(row)
    row.hover:SetVertexColor(BUI.ThemeColor('input'))
    row.hover:Show()
end

local function RowLeave(row)
    row.hover:Hide()
end

local function RowClick(row)
    row.open(row)
end

local function CreateRow(panel, rowIndex, label, open)
    local font = Datatext.PanelFont()
    local top = Pixel.Scale(-(ROW_TOP + (rowIndex - 1) * (ROW_HEIGHT + ROW_GAP)))
    local row = CreateFrame('Button', nil, panel)
    row:SetHeight(Pixel.Scale(ROW_HEIGHT))
    row:SetPoint('TOPLEFT', Pixel.Scale(PANEL_PAD - ROW_INSET), top)
    row:SetPoint('TOPRIGHT', -Pixel.Scale(PANEL_PAD - ROW_INSET), top)
    row.hover = Widget.DrawCardShape(row, ROW_RADIUS, SOLID, CLEAR, 'BACKGROUND', 0, 0)
    row.hover:Hide()
    row.label = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(row.label, 11, font)
    row.label:SetPoint('LEFT', Pixel.Scale(ROW_INSET), 0)
    row.label:SetText(label)
    row.chevron = row:CreateTexture(nil, 'OVERLAY')
    row.chevron:SetTexture(BUILib.GetLibMedia('dropdown'))
    row.chevron:SetSize(Pixel.Scale(CHEVRON_SIZE), Pixel.Scale(CHEVRON_SIZE))
    row.chevron:SetRotation(CHEVRON_ROTATION)
    row.chevron:SetPoint('RIGHT', -Pixel.Scale(ROW_INSET), 0)
    row.value = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(row.value, 11, font)
    row.value:SetJustifyH('RIGHT')
    row.value:SetWordWrap(false)
    row.value:SetPoint('LEFT', row.label, 'RIGHT', Pixel.Scale(8), 0)
    row.value:SetPoint('RIGHT', row.chevron, 'LEFT', -Pixel.Scale(6), 0)
    row.open = open
    row:SetScript('OnEnter', BUI.Profiler.Script('Datatext.LootSpec row OnEnter', RowEnter))
    row:SetScript('OnLeave', BUI.Profiler.Script('Datatext.LootSpec row OnLeave', RowLeave))
    row:SetScript('OnClick', BUI.Profiler.Script('Datatext.LootSpec row OnClick', RowClick))
    return row
end

local function BuildSpecPanel()
    if specPanel then return end
    local panel = Datatext.CreateHoverPanel('BUI_DatatextLootSpec', PANEL_WIDTH)
    local font = Datatext.PanelFont()
    panel.title:SetText('SPECIALIZATION')

    panel.current = panel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panel.current, 12, font)
    panel.current:SetPoint('TOPRIGHT', -Pixel.Scale(PANEL_PAD), Pixel.Scale(-8))
    panel.current:SetJustifyH('RIGHT')

    panel.specButtons = {}
    for specIndex = 1, MAX_SPECS do panel.specButtons[specIndex] = CreateSpecButton(panel, specIndex) end

    panel.rows = {
        CreateRow(panel, 1, 'Loadout', OpenLoadoutMenu),
        CreateRow(panel, 2, 'Loot', OpenLootSpecMenu),
    }

    panel.note = panel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panel.note, 10, font)
    panel.note:SetPoint('TOPLEFT', Pixel.Scale(PANEL_PAD), Pixel.Scale(-(ROW_TOP + #panel.rows * (ROW_HEIGHT + ROW_GAP) + 2)))
    panel.note:SetText('Loot follows your current specialization')

    function panel:PaintTheme()
        self.current:SetTextColor(BUI.ThemeColor('accent'))
        for _, row in ipairs(self.rows) do
            row.label:SetTextColor(BUI.ThemeColor('muted'))
            row.value:SetTextColor(BUI.ThemeColor('text'))
            row.chevron:SetVertexColor(BUI.ThemeColor('muted'))
        end
        self.note:SetTextColor(BUI.ThemeColor('muted'))
    end

    specPanel = panel
end

local function RenderSpecPanel()
    local panel = specPanel
    local specID, specName = CurrentSpecInfo()
    local activeIndex = GetSpecialization()
    local numSpecs = GetNumSpecializations()
    for specIndex = 1, MAX_SPECS do
        local button = panel.specButtons[specIndex]
        local id, name, _, icon
        if specIndex <= numSpecs then id, name, _, icon = GetSpecializationInfo(specIndex) end
        if id then
            button.specName = name
            button.active = specIndex == activeIndex
            button.icon:SetTexture(icon)
            button:SetAlpha(button.active and 1 or INACTIVE_ALPHA)
            Pixel.SetBorderColor(button, BUI.ThemeColor(button.active and 'accent' or 'edge'))
            button:Show()
        else
            button:Hide()
        end
    end
    panel.current:SetText(specName)
    panel.rows[1].value:SetText(specID and ActiveLoadoutName(specID) or 'None')
    panel.rows[2].value:SetText(lootSpecName)
    local following = GetLootSpecialization() == 0
    panel.note:SetShown(following)
    local height = ROW_TOP + #panel.rows * (ROW_HEIGHT + ROW_GAP) + (following and NOTE_HEIGHT or 0) + BOTTOM_PAD
    panel:SetHeight(Pixel.Scale(height))
end

local function RefreshSpecPanel()
    if specPanel and specPanel:IsShown() then RenderSpecPanel() end
end

local function OpenSpecHover(anchor)
    BuildSpecPanel()
    local panel = specPanel
    panel.anchor = anchor
    if panel:IsShown() and not panel._fadingOut then return end
    RenderSpecPanel()
    Datatext.PlacePanelAtBar(panel, anchor)
    panel:Reveal()
end

Datatext.Register('lootSpec', {
    name = 'Loot Spec', show = 'showLootSpec', label = 'Loot:',
    events = {
        'PLAYER_LOOT_SPEC_UPDATED', 'PLAYER_SPECIALIZATION_CHANGED', 'PLAYER_ENTERING_WORLD',
        'TRAIT_CONFIG_UPDATED', 'TRAIT_CONFIG_LIST_UPDATED', 'CONFIG_COMMIT_FAILED', 'SELECTED_LOADOUT_CHANGED',
    },
    OnActivate = Read,
    OnEvent = function(event, unit)
        if event == 'PLAYER_SPECIALIZATION_CHANGED' and unit and unit ~= 'player' then return end
        if event == 'TRAIT_CONFIG_UPDATED' then
            OnConfigCommitted()
        elseif event == 'CONFIG_COMMIT_FAILED' then
            ClearPendingLoadout()
        end
        if Read() then Datatext.Refresh('lootSpec') end
        RefreshSpecPanel()
    end,
    build = function(config, valueHex, self)
        return Datatext.Label(config, self) .. Datatext.Colored(lootSpecName, valueHex)
    end,
    OnClick = function(_, button)
        return button == 'LeftButton'
    end,
    OnEnter = function(hit)
        OpenSpecHover(hit)
    end,
    sample = function(config, label, colorize) return label .. colorize('Spec') end,
})
