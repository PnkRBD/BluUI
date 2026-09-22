local BUI = BluUI
local SetScript = BUI.Prof.Scripts('Pages.CustomBars')

local wipe = wipe
local Pixel = BUI.Pixel
local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals, Widget = BUILib.Controls, BUILib.Layout, BUILib.Modals, BUILib.Widget
local PageKit = BUILib.PageKit
local TRINKET_SLOTS = { 13, 14 }
local AUTO_PREFIX = 'auto:'
local IconEngine = BUI.IconEngine
local DEFAULT_ICON = 134400
local PRIORITY_TINT = { 1, 0.82, 0, 1 }
local IDLE_TINT = { 0.6, 0.6, 0.6, 1 }

local function IsFlaskItem(itemID)
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return classID == Enum.ItemClass.Consumable and subclassID == Enum.ItemConsumableSubclass.Flask
end

local function PotionDisplayLabel(itemID, storedValue)
    local label = IsFlaskItem(itemID) and 'Flask Display' or 'Potion Display'
    if BUI.CDM.GetPotionPrioFor(storedValue) then return label .. ' |cffffe066(custom)|r', true end
    return label, false
end

local function IsPotionRow(rowId)
    local itemID = type(rowId) == 'string' and tonumber(rowId:match('^item:(%d+)'))
    if not itemID then return nil end
    return BUI.CDM.Custom.IsPotionItem(itemID) and itemID or nil
end

local STRATA_OPTIONS = BUI.C.STRATA_OPTIONS
local GROW_OPTIONS = { { value = 'LEFT', text = 'Left' }, { value = 'RIGHT', text = 'Right' } }
local ROW_OPTIONS  = { { value = 'DOWN', text = 'Down' }, { value = 'UP', text = 'Up' } }

local selectedIndex = 1

local function GetBar(index)
    return BUI.GetDB().customBars[index]
end

local function Current()
    return GetBar(selectedIndex)
end

local function RefreshCurrent()
    BUI.CustomBars.RefreshBar(selectedIndex)
end

local function IsAutoId(rowId)
    return type(rowId) == 'string' and rowId:sub(1, #AUTO_PREFIX) == AUTO_PREFIX
end

local function ExtractNumeric(rowId)
    if type(rowId) == 'number' then return rowId end
    local text = tostring(rowId)
    return tonumber(text) or tonumber(text:match('%d+'))
end

local function ResolveIcon(stored)
    local id, isItem = IconEngine.ExtractSpellItemID(stored)
    if not id then return nil, nil end
    local texture
    if isItem then
        texture = BUI.Lookup.GetItemInfo(id)
    else
        texture = BUI.Lookup.GetSpellInfo(id)
    end
    return texture or DEFAULT_ICON, id
end

local function VisibleIcons(bar)
    local list = {}
    if not bar then return list end
    local hidden = bar.hiddenIcons
    for _, stored in ipairs(bar.customSpells) do
        local texture, id = ResolveIcon(stored)
        if texture and not (id and hidden[id]) then
            list[#list + 1] = texture
        end
    end
    if bar.showTrinkets then
        for slotIndex = 1, #TRINKET_SLOTS do
            local trinketTexture = GetInventoryItemTexture('player', TRINKET_SLOTS[slotIndex])
            if trinketTexture then list[#list + 1] = trinketTexture end
        end
    end
    return list
end

local function ShowImportDialog(CustomBars, onImported)
    local characters = CustomBars.GetOtherCharacters()
    if #characters == 0 then
        Modals.Message({ title = "Import Bars", message = "No other characters have tracking bar data to import." })
        return
    end
    local overlay, dialog, Close = Modals.CreateBase(480, 300, true)
    Modals.CreateTitle(dialog, "Import Bars")

    local selectedCharacter = characters[1]
    local selectedBars = {}

    local barMultiDropdown
    local function RebuildBarMultiDropdown()
        local barInfo = CustomBars.GetBarInfoForCharacter(selectedCharacter)
        local barItems = {}
        selectedBars = {}
        for _, info in ipairs(barInfo) do
            barItems[#barItems + 1] = { value = info.index, text = info.name .. "  (" .. info.count .. ")" }
            selectedBars[info.index] = true
        end
        if barMultiDropdown then barMultiDropdown:SetItems(barItems, selectedBars) end
        return barItems
    end

    local characterItems = {}
    for _, characterKey in ipairs(characters) do
        characterItems[#characterItems + 1] = { value = characterKey, text = characterKey }
    end

    local characterLabel = dialog:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(characterLabel, BUILib.FONT_SIZE, BUILib.Font, "")
    characterLabel:SetTextColor(0.7, 0.7, 0.7)
    characterLabel:SetText("Character")
    characterLabel:SetPoint("CENTER", dialog, "CENTER", 0, Pixel.Scale(55))

    local characterDropdown = Controls.Dropdown(dialog, nil, characterItems, selectedCharacter, function(value)
        selectedCharacter = value
        RebuildBarMultiDropdown()
    end, nil, 340)
    local characterDropdownFrame = characterDropdown.frame
    characterDropdownFrame:SetPoint("TOP", characterLabel, "BOTTOM", 0, Pixel.Scale(-4))

    local barLabel = dialog:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(barLabel, BUILib.FONT_SIZE, BUILib.Font, "")
    barLabel:SetTextColor(0.7, 0.7, 0.7)
    barLabel:SetText("Bars to Import")
    barLabel:SetPoint("TOP", characterDropdownFrame, "BOTTOM", 0, Pixel.Scale(-14))

    barMultiDropdown = Controls.MultiDropdown(dialog, nil, RebuildBarMultiDropdown(), selectedBars, function(map)
        selectedBars = map
    end, nil, 340)
    local barMultiDropdownFrame = barMultiDropdown.frame
    barMultiDropdownFrame:SetPoint("TOP", barLabel, "BOTTOM", 0, Pixel.Scale(-4))

    Modals.LayoutButtons(dialog, {
        { text = "Import", color = Modals.BTN_CONFIRM, width = 100,
          onClick = function(close)
              close()
              local indices = {}
              for index, isSelected in pairs(selectedBars) do
                  if isSelected then indices[#indices + 1] = index end
              end
              if #indices > 0 then
                  CustomBars.CopyBarsFromCharacter(selectedCharacter, indices)
                  if onImported then onImported() end
              end
          end },
        { text = "Cancel", color = Modals.BTN_CANCEL, width = 100 },
    }, Close)

    overlay:Show()
end

local function BuildEmptyState(pageFrame, CustomBars, rebuildPage)
    local page = Layout.Page(pageFrame, nil)
    local tab = page:GetTab(1)
    local Theme = BUILib.Theme

    local hero = CreateFrame("Frame", nil, tab.child)
    hero:SetWidth(tab.width or 600)
    hero:SetHeight(Pixel.Scale(140))

    local title = hero:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(title, 18, BUILib.Font, "OUTLINE")
    title:SetPoint("TOP", hero, "TOP", 0, Pixel.Scale(-8))
    title:SetText("No custom bars yet")
    title:SetTextColor(unpack(Theme.text.primary))

    local desc = hero:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(desc, 12, BUILib.Font, "")
    desc:SetWidth(Pixel.Scale(440))
    desc:SetJustifyH("CENTER")
    desc:SetPoint("TOP", title, "BOTTOM", 0, Pixel.Scale(-10))
    desc:SetText("Custom bars track the cooldowns, trinkets, potions and buffs you care about. Build one from scratch, or import a setup from another character.")
    desc:SetTextColor(unpack(Theme.text.muted))

    local newButton = Controls.Button(hero, "Create First Bar", 150, function()
        CustomBars.AddBar(); selectedIndex = 1; rebuildPage()
    end, nil, true)
    local importButton = Controls.Button(hero, "Import", 110, function()
        ShowImportDialog(CustomBars, rebuildPage)
    end)
    local newButtonFrame, importButtonFrame = Widget.Unwrap(newButton), Widget.Unwrap(importButton)
    local gap = 12
    local newWidth, importWidth = newButtonFrame:GetWidth() or 150, importButtonFrame:GetWidth() or 110
    local totalWidth = newWidth + gap + importWidth
    newButtonFrame:ClearAllPoints(); newButtonFrame:SetPoint("TOP", desc, "BOTTOM", (newWidth - totalWidth) / 2, Pixel.Scale(-24))
    importButtonFrame:ClearAllPoints(); importButtonFrame:SetPoint("LEFT", newButtonFrame, "RIGHT", gap, 0)

    Layout.PositionInTab(tab, hero, 140, 90)
    page:AutoRefresh()
end

local function BuildPreview(parent, width)
    local card, stage = PageKit.PreviewStage(parent, { inset = 14 })
    stage._pool = {}

    local empty = stage:CreateFontString(nil, "OVERLAY")
    Pixel.ApplyFont(empty, 13, BUILib.Font, "")
    empty:SetPoint("CENTER")
    empty:SetTextColor(0.5, 0.5, 0.54, 1)
    empty:SetText("No icons on this bar yet")
    empty:Hide()

    function card:Rebuild()
        local bar = Current()
        for _, iconFrame in ipairs(stage._pool) do iconFrame:Hide() end

        local list = VisibleIcons(bar)
        local iconCount = #list
        if iconCount == 0 then empty:Show() return end
        empty:Hide()

        local gap = bar.spacing
        local stageWidth = width - 28
        local size = bar.iconSize
        local totalWidth = iconCount * size + (iconCount - 1) * gap
        if totalWidth > stageWidth then
            size = math.floor((stageWidth - (iconCount - 1) * gap) / iconCount)
            totalWidth = iconCount * size + (iconCount - 1) * gap
        end
        local startX = -totalWidth / 2 + size / 2
        local growLeft = bar.growDirection == 'LEFT'
        local zoom = bar.zoom
        local borderColor = bar.borderColor

        for iconIndex = 1, iconCount do
            local iconFrame = stage._pool[iconIndex]
            if not iconFrame then
                iconFrame = CreateFrame('Frame', nil, stage)
                local texture = iconFrame:CreateTexture(nil, 'ARTWORK')
                texture:SetPoint('TOPLEFT', 1, -1)
                texture:SetPoint('BOTTOMRIGHT', -1, 1)
                iconFrame._tex = texture
                stage._pool[iconIndex] = iconFrame
            end
            iconFrame:SetSize(size, size)
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint('CENTER', stage, 'CENTER', startX + (iconIndex - 1) * (size + gap), 0)
            iconFrame._tex:SetTexture(list[growLeft and (iconCount - iconIndex + 1) or iconIndex])
            iconFrame._tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
            Pixel.ApplyBorder(iconFrame, bar.borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
            iconFrame:Show()
        end
    end

    return card
end

local function BuildBarDropdownItems()
    local items = {}
    for barIndex, bar in ipairs(BUI.GetDB().customBars) do
        items[#items + 1] = { value = barIndex, text = bar.name or ('Bar ' .. barIndex) }
    end
    return items
end

local function BuildSelector(parent, width, y, callbacks)
    local CustomBars = BUI.CustomBars

    local row = CreateFrame('Frame', nil, parent)
    row:SetSize(width, 44)
    row:SetPoint('TOP', parent, 'TOP', 0, -y)

    local divider = row:CreateTexture(nil, 'OVERLAY')
    divider:SetColorTexture(1, 1, 1, 0.1)
    divider:SetHeight(1)
    divider:SetPoint('BOTTOMLEFT')
    divider:SetPoint('BOTTOMRIGHT')

    local label = row:CreateFontString(nil, 'OVERLAY')
    label:SetFont(BUILib.Font, 12, '')
    label:SetTextColor(0.7, 0.7, 0.74, 1)
    label:SetText('Editing Bar')
    label:SetPoint('LEFT', row, 'LEFT', 2, 0)

    local barDropdown = Controls.Dropdown(row, nil, BuildBarDropdownItems(), selectedIndex, function(value)
        CustomBars.UnregisterPositionCallback(selectedIndex)
        CustomBars.UnregisterLockSync(selectedIndex)
        selectedIndex = value
        callbacks.onPick()
    end, nil, 220)
    local dropdownFrame = Widget.Unwrap(barDropdown)
    dropdownFrame:ClearAllPoints()
    dropdownFrame:SetPoint('LEFT', label, 'RIGHT', 10, 0)

    local function Rename()
        local bar = GetBar(selectedIndex)
        Modals.Input({
            title = 'Rename Bar', message = 'Enter a new name for this bar.',
            defaultText = bar and bar.name or '', confirmText = 'Rename',
            onConfirm = function(text)
                local currentBar = GetBar(selectedIndex)
                if not currentBar or not text or text == '' then return end
                currentBar.name = text
                callbacks.rebuildPage()
            end,
        })
    end

    local function Duplicate()
        local sourceBar = GetBar(selectedIndex); if not sourceBar then return end
        CustomBars.UnregisterPositionCallback(selectedIndex)
        CustomBars.UnregisterLockSync(selectedIndex)
        local newIndex = CustomBars.AddBar(sourceBar.name .. ' Copy')
        local destinationBar = GetBar(newIndex)
        if destinationBar then
            for key, value in pairs(sourceBar) do
                if key ~= 'name' and key ~= 'posX' and key ~= 'posY' and key ~= 'customSpells' then
                    if type(value) == 'table' then
                        destinationBar[key] = {}
                        for tableKey, tableValue in pairs(value) do destinationBar[key][tableKey] = tableValue end
                    else
                        destinationBar[key] = value
                    end
                end
            end
            if sourceBar.customSpells then
                destinationBar.customSpells = destinationBar.customSpells
                wipe(destinationBar.customSpells)
                for spellIndex, spell in ipairs(sourceBar.customSpells) do destinationBar.customSpells[spellIndex] = spell end
            end
            CustomBars.RefreshBar(newIndex)
        end
        selectedIndex = newIndex
        callbacks.rebuildPage()
    end

    local function Delete()
        local currentBar = GetBar(selectedIndex)
        Modals.Confirm({
            title = 'Delete Bar',
            message = 'Delete "' .. (currentBar and currentBar.name or 'this bar') .. '"?',
            confirmText = 'Delete', cancelText = 'Cancel',
            onConfirm = function()
                local index = selectedIndex
                CustomBars.UnregisterPositionCallback(index)
                CustomBars.UnregisterLockSync(index)
                CustomBars.DeleteBar(index)
                selectedIndex = math.max(1, index - 1)
                callbacks.rebuildPage()
            end,
        })
    end

    local function DeleteAll()
        Modals.Confirm({
            title = 'Delete All Bars',
            message = 'Delete all ' .. CustomBars.GetBarCount() .. ' tracking bars?',
            confirmText = 'Delete All', cancelText = 'Cancel',
            onConfirm = function()
                for barIndex = CustomBars.GetBarCount(), 1, -1 do
                    CustomBars.UnregisterPositionCallback(barIndex)
                    CustomBars.UnregisterLockSync(barIndex)
                    CustomBars.DeleteBar(barIndex)
                end
                selectedIndex = 1
                callbacks.rebuildPage()
            end,
        })
    end

    local moreButton = Controls.Button(row, 'More', 70, function()
        Controls.ContextMenu({
            { text = GetBar(selectedIndex) and GetBar(selectedIndex).name or ('Bar ' .. selectedIndex), title = true },
            { text = 'Rename',    callback = Rename },
            { text = 'Duplicate', callback = Duplicate },
            { separator = true },
            { text = 'Import from Character...', callback = function()
                ShowImportDialog(CustomBars, function() callbacks.rebuildPage() end)
            end },
            { separator = true },
            { text = '|cffff6060Delete Bar|r',      callback = Delete },
            { text = '|cffff6060Delete All Bars|r', callback = DeleteAll },
        }, { width = 200 })
    end)
    local newButton = Controls.Button(row, 'New', 70, function()
        CustomBars.UnregisterPositionCallback(selectedIndex)
        CustomBars.UnregisterLockSync(selectedIndex)
        selectedIndex = CustomBars.AddBar()
        callbacks.rebuildPage()
    end)
    local moreButtonFrame = Widget.Unwrap(moreButton)
    moreButtonFrame:ClearAllPoints(); moreButtonFrame:SetPoint('RIGHT', row, 'RIGHT', 0, 0)
    local newButtonFrame = Widget.Unwrap(newButton)
    newButtonFrame:ClearAllPoints(); newButtonFrame:SetPoint('RIGHT', moreButtonFrame, 'LEFT', -8, 0)
end

local function BuildItemsCard(grid, onItemsChanged)
    local card = grid:AddCard({ title = 'Tracked Spells & Items', spanFull = true })
    local list

    local function BuildEntries()
        local entries = {}
        local settings = Current()
        if not settings then return entries end
        local hidden = settings.hiddenIcons
        local seenIDs = {}

        local function FormatName(displayName, hideKey, autoAdded)
            local name = displayName or '?'
            if autoAdded then name = name .. '  |cff44bbff[Auto Added]|r' end
            if hideKey and hidden[hideKey] then name = name .. '  |cffff4444[Hidden]|r' end
            return name
        end

        if settings.customSpells then
            for _, storedValue in ipairs(settings.customSpells) do
                local id, isItem = IconEngine.ExtractSpellItemID(storedValue)
                if id then
                    seenIDs[id] = true
                    local iconTexture, displayName
                    if isItem then
                        iconTexture, displayName = BUI.Lookup.GetItemInfo(id)
                        displayName = displayName or ('Item ' .. id)
                    else
                        iconTexture, displayName = BUI.Lookup.GetSpellInfo(id)
                        displayName = displayName or ('Spell ' .. id)
                    end
                    entries[#entries + 1] = {
                        icon = iconTexture or DEFAULT_ICON,
                        name = FormatName(displayName, id, false),
                        id = storedValue,
                    }
                end
            end
        end

        local blacklist = settings.trinketBlacklist
        if settings.showTrinkets then
            for slotIndex = 1, #TRINKET_SLOTS do
                local slot = TRINKET_SLOTS[slotIndex]
                local itemID = GetInventoryItemID('player', slot)
                local icon = (itemID and GetInventoryItemTexture('player', slot)) or DEFAULT_ICON
                local rowId = AUTO_PREFIX .. 'slot:' .. slot
                local name = FormatName('Trinket ' .. slotIndex, rowId, true)
                if itemID and blacklist[itemID] then
                    name = name .. '  |cffff8844[Blacklisted]|r'
                end
                entries[#entries + 1] = { icon = icon, name = name, id = rowId }
            end
        end

        if settings.showRacials then
            for _, id in ipairs(BUI.CDM.GetKnownRacialSpellIDs()) do
                if not seenIDs[id] then
                    local iconTexture, displayName = BUI.Lookup.GetSpellInfo(id)
                    local rowId = AUTO_PREFIX .. 'racial:' .. id
                    entries[#entries + 1] = {
                        icon = iconTexture or DEFAULT_ICON,
                        name = FormatName(displayName or ('Spell ' .. id), rowId, true),
                        id = rowId,
                    }
                end
            end
        end

        return entries
    end

    local function ResolveTrinketItemID(rowId)
        if type(rowId) ~= 'string' then return nil end
        local slot = tonumber(rowId:match('^auto:slot:(%d+)$'))
        if not slot then return nil end
        return GetInventoryItemID('player', slot)
    end

    local function RefreshList()
        list:ClearItems()
        for _, entry in ipairs(BuildEntries()) do
            list:AddItem(entry.icon, entry.name, entry.id)
        end
        onItemsChanged()
    end

    local function AddStored(storedValue)
        local settings = Current()
        if not settings then return end
        for _, existing in ipairs(settings.customSpells) do
            if tostring(existing) == tostring(storedValue) then return end
        end
        settings.customSpells[#settings.customSpells + 1] = storedValue
        RefreshCurrent()
        RefreshList()
    end

    list = Layout.ItemList(card, {
        hint = "Drag spell/item here, search, or paste link/ID...",
        height = 300,
        items = BuildEntries(),
        orderable = true,
        onReorder = function(newData)
            local settings = Current()
            if not settings then return end
            local spells = settings.customSpells
            wipe(spells)
            for _, entry in ipairs(newData) do
                if not IsAutoId(entry.id) then
                    spells[#spells + 1] = entry.id
                end
            end
            RefreshCurrent()
            onItemsChanged()
        end,
        searchFunc = BUI.Lookup.SearchSpellsAndItems,
        onAdd = function(text)
            local id, isItem = BUI.Lookup.ParseSpellOrItemInput(text)
            if not id then return end
            AddStored(isItem and ("item:" .. id) or ("spell:" .. id))
        end,
        onSearchSelect = function(item)
            AddStored(item.isItem and ("item:" .. item.id) or ("spell:" .. item.id))
        end,
        onRemove = function(row)
            if not row.id then return end
            if IsAutoId(row.id) then RefreshList(); return end
            local settings = Current()
            if not settings then return end
            for index, stored in ipairs(settings.customSpells) do
                if tostring(stored) == tostring(row.id) then table.remove(settings.customSpells, index); break end
            end
            RefreshCurrent()
            onItemsChanged()
        end,
        onRowRightClick = function(rowId, row)
            if not rowId then return end
            local settings = Current()
            if not settings then return end

            local isAuto = IsAutoId(rowId)
            local hideKey = isAuto and rowId or ExtractNumeric(rowId)
            local isHidden = hideKey and settings.hiddenIcons[hideKey] or false

            local items = {}
            local title = row and row.data and row.data.name
            if title and title ~= '' then
                items[#items + 1] = { text = title, title = true }
            end

            items[#items + 1] = {
                text = isHidden and 'Show on Bar' or 'Hide from Bar',
                callback = function()
                    local currentBar = Current()
                    if not currentBar or not hideKey then return end
                    currentBar.hiddenIcons[hideKey] = (not currentBar.hiddenIcons[hideKey]) and true or nil
                    RefreshCurrent()
                    RefreshList()
                end,
            }

            local parsedItemID = type(rowId) == 'string' and tonumber(rowId:match('^item:(%d+)'))
            if parsedItemID then
                local _, _, _, equipLoc, _, itemClass = C_Item.GetItemInfoInstant(parsedItemID)
                if itemClass ~= nil and equipLoc ~= 'INVTYPE_TRINKET' then
                    items[#items + 1] = {
                        text = 'Hide at 0',
                        checked = (settings.hideWhenZero and hideKey and settings.hideWhenZero[hideKey]) and true or false,
                        callback = function()
                            local currentBar = Current()
                            if not currentBar or not hideKey then return end
                            currentBar.hideWhenZero = currentBar.hideWhenZero or {}
                            currentBar.hideWhenZero[hideKey] = (not currentBar.hideWhenZero[hideKey]) and true or nil
                            RefreshCurrent()
                            RefreshList()
                        end,
                    }
                end

                if IsPotionRow(rowId) then
                    items[#items + 1] = {
                        text = PotionDisplayLabel(parsedItemID, rowId) .. '...',
                        callback = function()
                            local currentBar = Current()
                            if not currentBar then return end
                            BUI.ShowCDMPotionModal(BUI.CDM, parsedItemID, rowId, currentBar, nil, function()
                                RefreshCurrent()
                                RefreshList()
                            end)
                        end,
                    }
                end
            end

            local trinketItemID = isAuto and ResolveTrinketItemID(rowId) or nil
            if trinketItemID then
                local blacklist = settings.trinketBlacklist
                local isBlacklisted = blacklist[trinketItemID]
                items[#items + 1] = {
                    text = isBlacklisted and 'Unblacklist Equipped Trinket' or 'Blacklist Equipped Trinket',
                    callback = function()
                        local currentBar = Current()
                        if not currentBar then return end
                        currentBar.trinketBlacklist[trinketItemID] = (not currentBar.trinketBlacklist[trinketItemID]) and true or nil
                        RefreshCurrent()
                        RefreshList()
                    end,
                }
            end

            if not isAuto then
                items[#items + 1] = { separator = true }
                items[#items + 1] = {
                    text = '|cffff6060Remove|r',
                    callback = function()
                        local currentBar = Current()
                        if not currentBar then return end
                        for spellIndex, stored in ipairs(currentBar.customSpells) do
                            if tostring(stored) == tostring(rowId) then
                                table.remove(currentBar.customSpells, spellIndex)
                                break
                            end
                        end
                        RefreshCurrent()
                        RefreshList()
                    end,
                }
            end

            Controls.ContextMenu(items, { width = 220 })
        end,
        onBindRow = function(frame, entry)
            local settings = Current()
            local isAuto = IsAutoId(entry.id)
            local hideKey = isAuto and entry.id or ExtractNumeric(entry.id)
            local isHidden = settings and hideKey and settings.hiddenIcons[hideKey] or false

            if not frame._hideBtn then
                local hideButton = CreateFrame('Button', nil, frame)
                hideButton:SetSize(Pixel.Scale(22), Pixel.Scale(22))
                hideButton:SetPoint('RIGHT', frame.id, 'LEFT', Pixel.Scale(-6), 0)
                hideButton:SetFrameLevel(frame:GetFrameLevel() + 5)
                local hideTexture = hideButton:CreateTexture(nil, 'OVERLAY')
                hideTexture:SetAllPoints()
                hideTexture:SetAtlas('talents-heroclass-ring-minimize-hide')
                hideButton._tex = hideTexture
                SetScript(hideButton, 'OnEnter', function(self)
                    hideTexture:SetVertexColor(1, 1, 1, 1)
                    Widget.ShowTip(self, self._tip or 'Hide from bar')
                end)
                SetScript(hideButton, 'OnLeave', function(self)
                    if self._hiddenState then
                        hideTexture:SetVertexColor(1, 0.3, 0.3, 1)
                    else
                        hideTexture:SetVertexColor(0.6, 0.6, 0.6, 1)
                    end
                    Widget.HideTip()
                end)
                frame._hideBtn = hideButton
            end

            frame._hideBtn._hiddenState = isHidden
            if isHidden then
                frame._hideBtn._tex:SetVertexColor(1, 0.3, 0.3, 1)
                frame._hideBtn._tip = 'Show on bar'
            else
                frame._hideBtn._tex:SetVertexColor(0.6, 0.6, 0.6, 1)
                frame._hideBtn._tip = 'Hide from bar'
            end
            SetScript(frame._hideBtn, 'OnClick', function()
                local currentBar = Current()
                if not currentBar or not hideKey then return end
                currentBar.hiddenIcons[hideKey] = (not currentBar.hiddenIcons[hideKey]) and true or nil
                RefreshCurrent()
                RefreshList()
            end)
            frame._hideBtn:Show()

            local potionItemID = not isAuto and IsPotionRow(entry.id) or nil
            if potionItemID then
                if not frame._potionBtn then
                    local potionButton = CreateFrame('Button', nil, frame)
                    potionButton:SetSize(Pixel.Scale(22), Pixel.Scale(22))
                    potionButton:SetPoint('RIGHT', frame._hideBtn, 'LEFT', Pixel.Scale(-4), 0)
                    potionButton:SetFrameLevel(frame:GetFrameLevel() + 5)
                    local potionTexture = potionButton:CreateTexture(nil, 'OVERLAY')
                    potionTexture:SetPoint('TOPLEFT', Pixel.Scale(3), -Pixel.Scale(3))
                    potionTexture:SetPoint('BOTTOMRIGHT', -Pixel.Scale(3), Pixel.Scale(3))
                    potionTexture:SetTexture(BUILib.GetLibMedia('order'))
                    potionButton._tex = potionTexture
                    SetScript(potionButton, 'OnEnter', function(self)
                        potionTexture:SetVertexColor(1, 1, 1, 1)
                        Widget.ShowTip(self, self._tip)
                    end)
                    SetScript(potionButton, 'OnLeave', function(self)
                        potionTexture:SetVertexColor(unpack(self._tint))
                        Widget.HideTip()
                    end)
                    frame._potionBtn = potionButton
                end
                local storedValue = entry.id
                local label, hasPriority = PotionDisplayLabel(potionItemID, storedValue)
                frame._potionBtn._tip = label
                frame._potionBtn._tint = hasPriority and PRIORITY_TINT or IDLE_TINT
                frame._potionBtn._tex:SetVertexColor(unpack(frame._potionBtn._tint))
                SetScript(frame._potionBtn, 'OnClick', function()
                    local currentBar = Current()
                    if not currentBar then return end
                    BUI.ShowCDMPotionModal(BUI.CDM, potionItemID, storedValue, currentBar, nil, function()
                        RefreshCurrent()
                        RefreshList()
                    end)
                end)
                frame._potionBtn:Show()
            elseif frame._potionBtn then
                frame._potionBtn:Hide()
            end

            if frame.xBtn then
                if isAuto then frame.xBtn:Hide() else frame.xBtn:Show() end
            end
        end,
    })
    card:Refresh()

    return RefreshList
end

BUI.PageEngine.RegisterPage("customBars", {
    title = "Custom Bars",
    buttonText = "Custom Bars",
    OnBuild = function(pageFrame)
        local CustomBars = BUI.CustomBars

        local function rebuildPage() BUI.PageEngine.RefreshCurrentPage() end

        if CustomBars.GetBarCount() == 0 then
            BuildEmptyState(pageFrame, CustomBars, rebuildPage)
            return
        end

        if selectedIndex > CustomBars.GetBarCount() then selectedIndex = CustomBars.GetBarCount() end

        local width = Layout.PAGE_CONTENT_W
        local PREVIEW_HEIGHT = Layout.PAGE_PREVIEW_H

        local grid, preview
        local trinketToggle, racialToggle, hideIfEmptyToggle, tooltipToggle, hideGCDToggle, strataDropdown
        local iconSizeSlider, spacingSlider, growDropdown, borderSwatch
        local anchorFrameControl, anchorPointDropdown, posXSlider, posYSlider
        local fontDropdown, showStackToggle, cooldownSizeSlider
        local refreshList

        local mark = pageFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
        mark:SetTexture(BUI.Tools.GetLogo())
        mark:SetSize(520, 520)
        mark:SetPoint("CENTER")
        mark:SetVertexColor(1, 1, 1, 0.06)

        local function RebuildPreview() preview:Rebuild() end
        local function SyncDim() grid:SyncDim(Current() and Current().enabled or false) end

        local titleHeight, titleBar = PageKit.PageTitle(pageFrame, 'Custom Bars', width, {
            desc = 'Track the cooldowns, trinkets, potions and buffs you care about.',
            enable = { value = Current() and Current().enabled or false, onToggle = function(enabled)
                local currentBar = Current(); if not currentBar then return end
                currentBar.enabled = enabled; RefreshCurrent(); SyncDim()
            end },
            anchor = { value = (Current() and not Current().locked) or false, onToggle = function(unlocked)
                local currentBar = Current(); if not currentBar then return end
                currentBar.locked = not unlocked; RefreshCurrent()
            end },
        })
        local topY = PageKit.PAD + titleHeight

        local pinned = PageKit.PreviewBand(pageFrame, width, PREVIEW_HEIGHT, topY, true)
        local selectorTop = topY + PREVIEW_HEIGHT + PageKit.GAP
        local SELECTOR_HEIGHT = 44
        local contentTop = selectorTop + SELECTOR_HEIGHT + PageKit.GAP

        local host = CreateFrame("Frame", nil, pageFrame)
        host:SetPoint("TOPLEFT", pageFrame, "TOPLEFT", 0, -contentTop)
        host:SetPoint("BOTTOMRIGHT", pageFrame, "BOTTOMRIGHT", 0, 0)
        local page = Layout.Page(host, nil, width)
        local tab = page:GetTab(1)
        tab.topPadding = 0

        local function SyncTitle()
            local currentBar = Current()
            if not currentBar then return end
            titleBar.enableToggle:SetValue(currentBar.enabled)
            titleBar.anchorToggle:SetValue(not currentBar.locked)
        end

        local function UpdatePositionLock(anchored)
            posXSlider:SetLocked(anchored); posXSlider:SetLockedText(anchored and "ANCHORED" or nil)
            posYSlider:SetLocked(anchored); posYSlider:SetLockedText(anchored and "ANCHORED" or nil)
        end

        local function RegisterSync()
            CustomBars.RegisterPositionCallback(selectedIndex, function(x, y)
                posXSlider:SetValue(x)
                posYSlider:SetValue(y)
            end)
            CustomBars.RegisterLockSync(selectedIndex, function(unlocked)
                titleBar.anchorToggle:SetValue(unlocked)
            end)
        end

        local function RebindAll()
            local currentBar = Current()
            if not currentBar then return end
            trinketToggle:SetValue(currentBar.showTrinkets)
            racialToggle:SetValue(currentBar.showRacials)
            hideIfEmptyToggle:SetValue(currentBar.hideIfNotInBags)
            tooltipToggle:SetValue(currentBar.showTooltips ~= false)
            hideGCDToggle:SetValue(currentBar.hideGCD or false)
            strataDropdown:SetValue(currentBar.frameStrata or 'MEDIUM')
            iconSizeSlider:SetValue(currentBar.iconSize)
            spacingSlider:SetValue(currentBar.spacing)
            growDropdown:SetValue(currentBar.growDirection)
            local borderColor = currentBar.borderColor
            borderSwatch:SetColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            anchorFrameControl:SetValue(currentBar.anchorFrame)
            anchorPointDropdown:SetValue(currentBar.anchorPoint)
            posXSlider:SetValue(currentBar.posX)
            posYSlider:SetValue(currentBar.posY)
            UpdatePositionLock(currentBar.anchorFrame and currentBar.anchorFrame ~= "")
            fontDropdown:SetValue(BUI.GetDB().general.trackingFont or BUI.C.GLOBAL_OPTION)
            showStackToggle:SetValue(currentBar.showStackText ~= false)
            cooldownSizeSlider:SetValue(currentBar.cooldownTextSize)
            refreshList()
            SyncDim()
        end

        preview = BuildPreview(pinned, width)

        BuildSelector(pageFrame, width, selectorTop, {
            rebuildPage = rebuildPage,
            onPick = function()
                RebindAll()
                RebuildPreview()
                SyncTitle()
                RegisterSync()
            end,
        })

        grid = PageKit.CardGrid(tab, { columns = 2 })

        local generalCard = grid:AddCard({ title = 'General' })
        local generalChild = generalCard.child
        trinketToggle = Controls.StampCheckbox(generalChild, nil, false, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.showTrinkets = value; RefreshCurrent(); RebuildPreview()
            refreshList()
        end)
        local trinketCog = Controls.Icon(generalChild, {
            title = 'TRINKETS', tooltip = 'Trinket options',
            options = {
                { label = 'Usable Trinkets Only',
                  get = function() return Current() and Current().trinketsUsableOnly == true end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.trinketsUsableOnly = value; RefreshCurrent(); refreshList() end },
            },
        })
        racialToggle = Controls.StampCheckbox(generalChild, nil, false, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.showRacials = value; RefreshCurrent(); RebuildPreview()
            refreshList()
        end)
        hideIfEmptyToggle = Controls.StampCheckbox(generalChild, nil, false, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.hideIfNotInBags = value; RefreshCurrent()
        end)
        tooltipToggle = Controls.StampCheckbox(generalChild, nil, true, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.showTooltips = value; RefreshCurrent()
        end)
        hideGCDToggle = Controls.StampCheckbox(generalChild, nil, false, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.hideGCD = value; RefreshCurrent()
        end)
        strataDropdown = Controls.Dropdown(generalChild, nil, STRATA_OPTIONS, 'MEDIUM', function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.frameStrata = value; RefreshCurrent()
        end, nil, 130)
        local strataCog = Controls.Icon(generalChild, {
            title = 'FRAME', tooltip = 'Frame level',
            options = {
                { kind = 'slider', label = 'Frame Level', min = 0, max = 100, step = 1,
                  get = function() return Current() and Current().frameLevel or 5 end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.frameLevel = value; RefreshCurrent() end },
            },
        })
        PageKit.Grid(generalCard, {
            { label = 'Show Trinkets',      controls = { trinketToggle, trinketCog } },
            { label = 'Show Racials',       controls = { racialToggle } },
            { label = 'Hide If Not In Bags', controls = { hideIfEmptyToggle } },
            { label = 'Show Tooltips',      controls = { tooltipToggle } },
            { label = 'Hide GCD',           controls = { hideGCDToggle } },
            { label = 'Frame Strata',       controls = { strataDropdown, strataCog } },
        })

        local layoutCard = grid:AddCard({ title = 'Layout', minHeight = generalCard.frame.layoutHeight })
        local layoutChild = layoutCard.child
        iconSizeSlider = Controls.CompactSlider(layoutChild, nil, 20, 80, 40, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.iconSize = value; RefreshCurrent(); RebuildPreview()
        end, 1)
        local iconCog = Controls.Icon(layoutChild, {
            title = 'ICONS', tooltip = 'Zoom',
            options = {
                { kind = 'slider', label = 'Zoom %', min = 0, max = 20, step = 1,
                  get = function() return (Current() and (Current().zoom or 0.08) or 0.08) * 100 end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.zoom = value / 100; RefreshCurrent(); RebuildPreview() end },
            },
        })
        spacingSlider = Controls.CompactSlider(layoutChild, nil, -20, 20, 1, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.spacing = value; RefreshCurrent(); RebuildPreview()
        end, 1)
        growDropdown = Controls.Dropdown(layoutChild, nil, GROW_OPTIONS, nil, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.growDirection = value; RefreshCurrent(); RebuildPreview()
        end, nil, 120)
        local growCog = Controls.Icon(layoutChild, {
            title = 'GROWTH', tooltip = 'Row growth & wrapping',
            options = {
                { kind = 'dropdown', label = 'Row Growth', items = ROW_OPTIONS, controlWidth = 120,
                  get = function() return Current() and Current().growVertical or 'DOWN' end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.growVertical = value; RefreshCurrent() end },
                { kind = 'slider', label = 'Max Per Row', min = 0, max = 20, step = 1,
                  get = function() return Current() and Current().maxPerRow or 0 end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.maxPerRow = value; RefreshCurrent() end },
            },
        })
        local initBorder = { 0, 0, 0, 1 }
        borderSwatch = Controls.ColorSwatch(layoutChild, { r = initBorder[1], g = initBorder[2], b = initBorder[3], a = initBorder[4], callback = function(red, green, blue, alpha)
            local currentBar = Current(); if not currentBar then return end
            currentBar.borderColor = { red, green, blue, alpha }; RefreshCurrent(); RebuildPreview()
        end, tooltip = 'Border Color' })
        local borderCog = Controls.Icon(layoutChild, {
            title = 'BORDER', tooltip = 'Border size',
            options = {
                { kind = 'slider', label = 'Border Size', min = 0, max = 5, step = 1,
                  get = function() return Current() and Current().borderSize or 1 end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.borderSize = value; RefreshCurrent(); RebuildPreview() end },
            },
        })
        PageKit.Grid(layoutCard, {
            { label = 'Icon Size',      controls = { iconSizeSlider, iconCog }, fillFirst = true },
            { label = 'Spacing',        controls = { spacingSlider } },
            { label = 'Grow Direction', controls = { growDropdown, growCog } },
            { label = 'Border Color',   controls = { borderSwatch, borderCog } },
        })

        local placementCard = grid:AddCard({ title = 'Placement', spanFull = true })
        local placementChild = placementCard.child
        anchorFrameControl = Controls.Frames(placementChild, nil, "", function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.anchorFrame = value; RefreshCurrent()
            UpdatePositionLock(value and value ~= "")
        end, 200, "Search available frames", BUI.C.ANCHOR_FRAMES_WITH_MOUSE)
        anchorPointDropdown = Controls.Dropdown(placementChild, nil, BUI.C.ANCHOR_PLACEMENT_OPTIONS, nil, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.anchorPoint = value; RefreshCurrent()
        end, nil, 120)
        local anchorOffsetMover = PageKit.OffsetMover(placementChild, {
            title = 'ANCHOR OFFSET', tooltip = 'Anchor offsets',
            labelX = 'Anchor X', labelY = 'Anchor Y', min = -200, max = 200,
            getX = function() return Current() and Current().anchorOffsetX or 0 end,
            setX = function(value) local currentBar = Current(); if not currentBar then return end currentBar.anchorOffsetX = value; RefreshCurrent() end,
            getY = function() return Current() and Current().anchorOffsetY or 0 end,
            setY = function(value) local currentBar = Current(); if not currentBar then return end currentBar.anchorOffsetY = value; RefreshCurrent() end,
        })
        posXSlider = Controls.CompactSlider(placementChild, nil, -1500, 1500, 0, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.posX = value; RefreshCurrent()
        end, 1)
        posYSlider = Controls.CompactSlider(placementChild, nil, -1000, 1000, 0, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.posY = value; RefreshCurrent()
        end, 1)
        PageKit.Grid(placementCard, {
            { label = 'Anchor Frame', controls = { anchorFrameControl } },
            { label = 'Anchor Point', controls = { anchorPointDropdown, anchorOffsetMover } },
            { label = 'X Position',   controls = { posXSlider } },
            { label = 'Y Position',   controls = { posYSlider } },
        }, 2)

        local textCard = grid:AddCard({ title = 'Text', spanFull = true })
        local textChild = textCard.child
        fontDropdown = Controls.Dropdown(textChild, nil, BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), BUI.C.GLOBAL_OPTION, function(value)
            BUI.GetDB().general.trackingFont = value ~= BUI.C.GLOBAL_OPTION and value or nil
            CustomBars.RefreshAllBars()
        end, nil, 160)
        showStackToggle = Controls.StatusToggle(textChild, nil, true, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.showStackText = value; RefreshCurrent()
        end)
        local POINT_OPTIONS = BUI.C.ANCHOR_POINT_OPTIONS
        local stackCog = Controls.Icon(textChild, {
            title = 'STACK TEXT', tooltip = 'Stack text size, position & offset', width = 280,
            options = {
                { kind = 'slider', label = 'Size', min = 8, max = 20, step = 1,
                  get = function() return Current() and Current().stackTextSize or 12 end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.stackTextSize = value; RefreshCurrent() end },
                { kind = 'dropdown', label = 'Position', items = POINT_OPTIONS, controlWidth = 120,
                  get = function() return Current() and Current().stackTextPosition end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.stackTextPosition = value; RefreshCurrent() end },
                { kind = 'slider', label = 'X Offset', min = -20, max = 20, step = 1,
                  get = function() return Current() and Current().stackTextOffsetX or 0 end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.stackTextOffsetX = value; RefreshCurrent() end },
                { kind = 'slider', label = 'Y Offset', min = -20, max = 20, step = 1,
                  get = function() return Current() and Current().stackTextOffsetY or 0 end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.stackTextOffsetY = value; RefreshCurrent() end },
            },
        })
        cooldownSizeSlider = Controls.CompactSlider(textChild, nil, 8, 24, 14, function(value)
            local currentBar = Current(); if not currentBar then return end
            currentBar.cooldownTextSize = value; RefreshCurrent()
        end, 1)
        local cooldownCog = Controls.Icon(textChild, {
            title = 'COOLDOWN TEXT', tooltip = 'Cooldown text position & offset', width = 280,
            options = {
                { kind = 'dropdown', label = 'Position', items = POINT_OPTIONS, controlWidth = 120,
                  get = function() return Current() and Current().cooldownTextPosition end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.cooldownTextPosition = value; RefreshCurrent() end },
                { kind = 'slider', label = 'X Offset', min = -20, max = 20, step = 1,
                  get = function() return Current() and Current().cooldownTextOffsetX or 0 end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.cooldownTextOffsetX = value; RefreshCurrent() end },
                { kind = 'slider', label = 'Y Offset', min = -20, max = 20, step = 1,
                  get = function() return Current() and Current().cooldownTextOffsetY or 0 end,
                  set = function(value) local currentBar = Current(); if not currentBar then return end currentBar.cooldownTextOffsetY = value; RefreshCurrent() end },
            },
        })
        PageKit.Grid(textCard, {
            { label = 'Font',          controls = { fontDropdown } },
            { label = 'Show Stacks',   controls = { showStackToggle, stackCog } },
            { label = 'Cooldown Size', controls = { cooldownSizeSlider, cooldownCog } },
        }, 2)

        refreshList = BuildItemsCard(grid, RebuildPreview)

        RebindAll()
        RebuildPreview()
        SyncTitle()
        RegisterSync()
        page:AutoRefresh()

        SetScript(pageFrame, 'OnShow', function()
            RebindAll()
            RebuildPreview()
            SyncTitle()
            RegisterSync()
        end)
    end,
    OnHide = function()
        BUI.CustomBars.UnregisterPositionCallback(selectedIndex)
        BUI.CustomBars.UnregisterLockSync(selectedIndex)
    end,
})
