local BUI = BluUI
local SetScript, HookScript = BUI.Prof.Scripts('Pages.CDM')

local BUILib = BluUI.BUILibClient
local Controls, Layout, Modals = BUILib.Controls, BUILib.Layout, BUILib.Modals

local POS_OPTIONS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local cdmHeaders, cdmGrids = {}, {}

local function RefreshCDMMocks()
    for _, header in pairs(cdmHeaders) do
        if header.Update and header.stage and header.stage:IsVisible() then header.Update() end
    end
end

local function ResolveCDMMedia(kind, key, fallback)
    if key and key ~= '' and key ~= 'GLOBAL' then
        local sharedMedia = LibStub('LibSharedMedia-3.0')
        local path = sharedMedia:Fetch(kind, key, true)
        if path then return path end
    end
    return fallback
end

local CDM_MOCK_KEYS = { 'Q', 'E', 'R', 'F', 'T', 'G', 'Z', 'X', 'C', 'V' }

local function GetViewerSpellList(viewerKey)
    local CDMModule = BUI.CDM
    local list, count = CDMModule.GetTrackedIcons(viewerKey)
    if list and count and count > 0 then
        local results = {}
        for iconIndex = 1, count do
            local icon = list[iconIndex]
            local key = CDMModule.GetSortKey(icon)
            local info = icon.cooldownInfo
            local spellID = info and BUI.Tools.SafeNum(info.overrideSpellID or info.spellID)
            if not spellID and type(key) == 'number' then spellID = key end
            local iconTexture = icon.Icon and icon.Icon.GetTexture and icon.Icon:GetTexture()
            if iconTexture and BUI.Tools.IsSecretValue and BUI.Tools.IsSecretValue(iconTexture) then iconTexture = nil end
            iconTexture = iconTexture or (spellID and C_Spell.GetSpellTexture(spellID))
            if iconTexture then results[#results + 1] = { icon = iconTexture, spellID = spellID, key = key } end
        end
        if #results > 0 then return results end
    end

    local categoryEnum = Enum.CooldownViewerCategory
    local GetCategorySet = C_CooldownViewer.GetCooldownViewerCategorySet
    local GetCooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo
    local category
    if viewerKey == 'essential' then category = categoryEnum.Essential
    elseif viewerKey == 'utility' then category = categoryEnum.Utility
    elseif viewerKey == 'buffs' then category = categoryEnum.TrackedBuff
    elseif viewerKey == 'buffBars' then category = categoryEnum.TrackedBar end
    if not category then return nil end
    local cooldownIDs = GetCategorySet(category)
    if not cooldownIDs then return nil end
    local results = {}
    for idIndex = 1, #cooldownIDs do
        local info = GetCooldownInfo(cooldownIDs[idIndex])
        local spellID = info and (info.overrideSpellID or info.spellID)
        if spellID then
            local spellTexture = C_Spell.GetSpellTexture(spellID)
            if spellTexture then results[#results + 1] = { icon = spellTexture, spellID = spellID } end
        end
    end
    if #results == 0 then return nil end
    return results
end

local function GetLiveViewerIcons(CDMModule, viewerKey, viewerSettings)
    local icons = CDMModule.GetViewerIcons(viewerKey)
    if #icons == 0 then return nil end
    local hiddenSlots = viewerSettings.hiddenSlots
    local hiddenIcons = CDMModule.GetHiddenIcons(viewerSettings)
    local results = {}
    for iconIndex = 1, #icons do
        local icon = icons[iconIndex]
        local isHidden = (hiddenSlots and hiddenSlots[iconIndex]) or CDMModule.IsIconHiddenByUser(viewerKey, hiddenIcons, icon)
        if not isHidden then
            local info = icon.cooldownInfo
            local spellID = info and BUI.Tools.SafeNum(info.overrideSpellID or info.spellID)
            local iconTexture = icon.Icon:GetTexture() or (spellID and C_Spell.GetSpellTexture(spellID))
            local frameData = CDMModule.FrameData[icon]
            results[#results + 1] = {
                tex = iconTexture or 134400,
                key = CDMModule.GetSortKey(icon),
                spellID = spellID,
                itemID = frameData and frameData.itemID,
            }
        end
    end
    if #results == 0 then return nil end
    return results
end

local function CreateViewerMock(stage, withKeybinds)
    local WHITE = 'Interface\\Buttons\\WHITE8x8'
    local holder = CreateFrame('Frame', nil, stage)
    holder:SetPoint('CENTER')
    local cells = {}
    local dragState, ghost

    local function HiddenKeyLabel(key)
        if type(key) == 'number' then
            return C_Spell.GetSpellName(key) or ('Spell ' .. key)
        end
        local keyText = tostring(key)
        local itemKeyID = tonumber(keyText:match('^item:(%d+)$'))
        if itemKeyID then
            return C_Item.GetItemNameByID(itemKeyID) or ('Item ' .. itemKeyID)
        end
        local customID = tonumber(keyText:match('^custom:(%d+)$'))
        if customID then
            if not C_SpellBook.IsSpellKnown(customID) and C_Item.GetItemInfoInstant(customID) then
                return C_Item.GetItemNameByID(customID) or ('Item ' .. customID)
            end
            return C_Spell.GetSpellName(customID) or ('Custom ' .. customID)
        end
        local trinketSlot = keyText:match('^trinket:(%d)$')
        if trinketSlot then return 'Trinket Slot ' .. trinketSlot end
        if keyText:match('^racial:') then return 'Racial' end
        return keyText
    end

    local function CellDisplayName(cell)
        local entry = cell._entry
        if not entry then return '' end
        if entry.itemID then
            local itemName = C_Item.GetItemNameByID(entry.itemID)
            if itemName then return itemName end
        end
        if entry.spellID then
            local spellName = C_Spell.GetSpellName(entry.spellID)
            if spellName then return spellName end
        end
        if entry.key ~= nil then return HiddenKeyLabel(entry.key) end
        return ''
    end

    local function RerenderLive()
        BUI.CDM.RefreshLayoutOnly()
        holder:Render(holder._viewerKey)
    end

    local function ShowUnhideMenu(viewerSettings, hiddenList)
        local menuItems = { { title = true, text = 'Restore' } }
        table.sort(hiddenList, function(keyA, keyB) return HiddenKeyLabel(keyA) < HiddenKeyLabel(keyB) end)
        for _, hiddenKey in ipairs(hiddenList) do
            menuItems[#menuItems + 1] = { text = HiddenKeyLabel(hiddenKey), callback = function()
                BUI.CDM.SetHiddenIcon(viewerSettings, hiddenKey, false)
                RerenderLive()
            end }
        end
        if #hiddenList > 1 then
            menuItems[#menuItems + 1] = { separator = true }
            menuItems[#menuItems + 1] = { text = 'Restore All', callback = function()
                for _, hiddenKey in ipairs(hiddenList) do
                    BUI.CDM.SetHiddenIcon(viewerSettings, hiddenKey, false)
                end
                RerenderLive()
            end }
        end
        Controls.ContextMenu(menuItems, { width = 230 })
    end

    local function ShowCellMenu(cell)
        local entry = cell._entry
        if not (entry and entry.key and holder._vs) then return end
        local viewerSettings = holder._vs
        local name = CellDisplayName(cell)
        local items = { { title = true, text = name ~= '' and name or 'Icon' } }

        local spellID = entry.spellID or (type(entry.key) == 'number' and entry.key or nil)
        if spellID then
            local procConfig = BUI.CDM.GetProcConfig(spellID)
            items[#items + 1] = { text = procConfig and 'Alert Settings... |cffffe066(active)|r' or 'Alert Settings...',
                callback = function() BUI.ShowCDMProcModal(BUI.CDM, spellID, RerenderLive, nil, viewerSettings) end }
        end
        if spellID then
            local iconOverrides = BUI.CDM.GetIconOverrides(viewerSettings)
            items[#items + 1] = {
                text = (iconOverrides and iconOverrides[spellID]) and 'Change Icon... |cffffe066(custom)|r' or 'Change Icon...',
                callback = function() BUI.ShowCDMIconOverrideModal(BUI.CDM, spellID, viewerSettings, RerenderLive) end,
            }
        end

        local potionValue, potionItemID
        do
            local list, count = BUI.CDM.GetTrackedIcons(holder._viewerKey)
            if list and count then
                for iconIndex = 1, count do
                    local frameData = BUI.CDM.FrameData[list[iconIndex]]
                    if frameData and frameData.customIcon and BUI.CDM.GetSortKey(list[iconIndex]) == entry.key then
                        if frameData.iconType == 'consumable'
                            and BUI.CDM.Custom.IsPotionItem(frameData.itemID or frameData.customSpellID) then
                            potionValue = frameData.storedValue
                            potionItemID = frameData.itemID or frameData.customSpellID
                        end
                        break
                    end
                end
            end
        end
        if potionValue then
            local viewerKey = holder._viewerKey
            local currentPriority = BUI.CDM.GetPotionPrioFor(potionValue)
            local label = 'Potion Display...'
            if potionItemID then
                local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(potionItemID)
                if classID == Enum.ItemClass.Consumable and subclassID == Enum.ItemConsumableSubclass.Flask then
                    label = 'Flask Display...'
                end
            end
            items[#items + 1] = {
                text = currentPriority and (label .. ' |cffffe066(custom)|r') or label,
                callback = function()
                    BUI.ShowCDMPotionModal(BUI.CDM, potionItemID, potionValue, viewerSettings, viewerKey, RerenderLive)
                end,
            }
        end
        if holder._viewerKey ~= 'buffs' then
            items[#items + 1] = {
                text = 'Show Only On Cooldown',
                checked = BUI.CDM.IsShowOnlyOnCD(viewerSettings, entry.key) and true or false,
                callback = function()
                    local wasOn = BUI.CDM.IsShowOnlyOnCD(viewerSettings, entry.key)
                    BUI.CDM.SetShowOnlyOnCD(viewerSettings, entry.key, not wasOn)
                    BUI.CDM.UpdateShowOnlyOnCDWatcher()
                    RerenderLive()
                end,
            }
        end
        items[#items + 1] = { text = '|cffff6060Remove from Viewer|r', callback = function()
            BUI.CDM.SetHiddenIcon(viewerSettings, entry.key, true)
            RerenderLive()
            BUILib.Toast.Info('Icon removed', 'Right-click any icon > Restore Icons to bring it back.')
        end }

        items[#items + 1] = { separator = true }

        local hiddenList = {}
        for hiddenKey, isHidden in pairs(BUI.CDM.GetHiddenIcons(viewerSettings)) do
            if isHidden == true then hiddenList[#hiddenList + 1] = hiddenKey end
        end
        if #hiddenList > 0 then
            items[#items + 1] = { text = ('Restore Icons (%d)...'):format(#hiddenList), callback = function()
                ShowUnhideMenu(viewerSettings, hiddenList)
                return true
            end }
        end
        items[#items + 1] = { text = 'Manage Icons...', callback = function()
            local configPage = BUI.PageEngine.pages.cdm
            local pageControl = configPage.frame and configPage.frame._page
            if pageControl and pageControl.SetTab then pageControl:SetTab(7) end
        end }
        Controls.ContextMenu(items, { width = 230 })
    end

    local function EnsureGhost()
        if ghost then return ghost end
        ghost = CreateFrame('Frame', nil, UIParent)
        ghost:SetFrameStrata(BUILib.GetPopupStrata())
        ghost:SetFrameLevel(BUILib.GetPopupLevel() + 20)
        ghost.tex = ghost:CreateTexture(nil, 'OVERLAY')
        ghost.tex:SetAllPoints()
        ghost.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ghost:Hide()
        return ghost
    end

    local function SlotFromCursor()
        local rects = holder._slotRects
        if not rects then return nil end
        local cursorX, cursorY = GetCursorPosition()
        local scale = holder:GetEffectiveScale()
        local localX = cursorX / scale - (holder:GetLeft() or 0)
        local localY = (holder:GetTop() or 0) - cursorY / scale
        for slotIndex = 1, #rects do
            local rect = rects[slotIndex]
            if localX >= rect.x and localX <= rect.x + rect.w and localY >= rect.y and localY <= rect.y + rect.h then return slotIndex end
        end
    end

    local function TargetSlotFor(slotIndex, sourceSlot, hoverSlot)
        if slotIndex == sourceSlot then return hoverSlot end
        if sourceSlot < hoverSlot then
            if slotIndex > sourceSlot and slotIndex <= hoverSlot then return slotIndex - 1 end
        elseif sourceSlot > hoverSlot then
            if slotIndex >= hoverSlot and slotIndex < sourceSlot then return slotIndex + 1 end
        end
        return slotIndex
    end

    local function BeginDrag(draggedCell)
        local entry = draggedCell._entry
        if not (entry and entry.key and holder._vs) or not IsControlKeyDown() then return end
        dragState = { src = draggedCell._slot, cell = draggedCell, hover = draggedCell._slot }
        draggedCell.frame:SetAlpha(0)
        local ghostFrame = EnsureGhost()
        local scale = draggedCell.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        ghostFrame:SetSize(draggedCell.frame:GetWidth() * scale, draggedCell.frame:GetHeight() * scale)
        ghostFrame.tex:SetTexture(entry.tex)
        ghostFrame:Show()
        SetScript(ghostFrame, 'OnUpdate', function(self, elapsed)
            local cursorX, cursorY = GetCursorPosition()
            local uiScale = UIParent:GetEffectiveScale()
            self:ClearAllPoints()
            self:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', cursorX / uiScale, cursorY / uiScale)

            local state = dragState
            local rects = holder._slotRects
            if not state or not rects then return end
            local hoveredSlot = SlotFromCursor()
            if hoveredSlot then state.hover = hoveredSlot end
            local lerpFactor = math.min(1, (elapsed or 0.016) * 14)
            for slotIndex = 1, #rects do
                local cell = cells[slotIndex]
                if cell and cell.frame:IsShown() then
                    local targetRect = rects[TargetSlotFor(slotIndex, state.src, state.hover)]
                    if targetRect then
                        cell._px = cell._px + (targetRect.x - cell._px) * lerpFactor
                        cell._py = cell._py + (targetRect.y - cell._py) * lerpFactor
                        cell.frame:ClearAllPoints()
                        cell.frame:SetPoint('TOPLEFT', holder, 'TOPLEFT', cell._px, -cell._py)
                    end
                end
            end
        end)
    end

    local function EndDrag(draggedCell)
        if ghost then ghost:Hide(); SetScript(ghost, 'OnUpdate', nil) end
        draggedCell.frame:SetAlpha(1)
        local state = dragState
        dragState = nil
        if not state or state.cell ~= draggedCell then return end
        local viewerSettings = holder._vs
        local entries = holder._entries
        if not (viewerSettings and entries) then return end
        local target = state.hover
        if not target or target == state.src or not entries[state.src] or not entries[target] then
            holder:Render(holder._viewerKey)
            return
        end
        local moved = table.remove(entries, state.src)
        table.insert(entries, target, moved)
        local order = {}
        for _, entry in ipairs(entries) do
            if entry.key then order[#order + 1] = entry.key end
        end
        if #order == 0 then holder:Render(holder._viewerKey); return end
        BUI.CDM.SetIconOrder(viewerSettings, order)
        RerenderLive()
        BUILib.Toast.Success('Order saved', 'Icon order updated for this spec.')
    end

    local function Cell(cellIndex)
        if not cells[cellIndex] then
            local cell = {}
            local cellButton = CreateFrame('Button', nil, holder)
            cellButton:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
            cellButton:RegisterForDrag('LeftButton')
            cell.frame = cellButton
            cell.border = cellButton:CreateTexture(nil, 'BACKGROUND')
            cell.border:SetTexture(WHITE)
            cell.border:SetAllPoints(cellButton)
            cell.icon = cellButton:CreateTexture(nil, 'ARTWORK')
            cell.swipe = cellButton:CreateTexture(nil, 'ARTWORK', nil, 1)
            cell.swipe:SetTexture(WHITE)
            cell.cd = cellButton:CreateFontString(nil, 'OVERLAY')
            cell.stack = cellButton:CreateFontString(nil, 'OVERLAY')
            cell.kb = cellButton:CreateFontString(nil, 'OVERLAY')
            SetScript(cellButton, 'OnClick', function() ShowCellMenu(cell) end)
            SetScript(cellButton, 'OnDragStart', function() BeginDrag(cell) end)
            SetScript(cellButton, 'OnDragStop', function() EndDrag(cell) end)
            SetScript(cellButton, 'OnEnter', function(self)
                local entry = cell._entry
                if not (entry and entry.key) then return end
                local name = CellDisplayName(cell)
                BUILib.Widget.ShowTip(self, (name ~= '' and name or 'Icon')
                    .. '|n|cff888888Ctrl+drag to reorder - click for options|r')
            end)
            SetScript(cellButton, 'OnLeave', function() BUILib.Widget.HideTip() end)
            cells[cellIndex] = cell
        end
        return cells[cellIndex]
    end

    function holder:Render(viewerKey)
        local viewerSettings = BUI.GetDB().cdm[viewerKey]
        local CDMModule = BUI.CDM
        if not viewerSettings then self:Hide(); return end
        local iconWidth = viewerSettings.iconWidth or viewerSettings.iconSize or 38
        local iconHeight = viewerSettings.iconHeight or iconWidth
        local spacing = viewerSettings.spacing
        local borderSize = viewerSettings.borderSize
        local borderColor = viewerSettings.borderColor
        local swipeColor = viewerSettings.swipeColor
        local font = BUI.GetGlobalFont()

        local list = GetLiveViewerIcons(CDMModule, viewerKey, viewerSettings)
        if not list then
            local spells = GetViewerSpellList(viewerKey)
            if spells then
                local hiddenIcons = CDMModule.GetHiddenIcons(viewerSettings)
                list = {}
                for spellIndex = 1, #spells do
                    local spellID = spells[spellIndex].spellID
                    local key = spells[spellIndex].key or spellID
                    local isHidden = (key ~= nil and hiddenIcons[key]) or (spellID and hiddenIcons[spellID])
                    if not isHidden then
                        list[#list + 1] = { tex = spells[spellIndex].icon, spellID = spellID, key = key }
                    end
                end
                local order = CDMModule.GetIconOrder(viewerSettings)
                if order and #order > 0 then
                    local rank = {}
                    for orderIndex = 1, #order do rank[order[orderIndex]] = orderIndex end
                    table.sort(list, function(entryA, entryB)
                        local rankA, rankB = rank[entryA.key], rank[entryB.key]
                        if rankA and rankB then return rankA < rankB end
                        if rankA or rankB then return rankA ~= nil end
                        return tostring(entryA.key) < tostring(entryB.key)
                    end)
                end
                if #list == 0 then list = nil end
            end
        end
        if not list then self:Hide(); return end
        local count = math.min(#list, 40)
        self._entries = list
        self._viewerKey = viewerKey
        self._vs = viewerSettings
        local slotRects = {}
        self._slotRects = slotRects

        local perRow = viewerSettings.iconsPerRow > 0 and viewerSettings.iconsPerRow or count
        local numRows, maxCols
        if viewerKey == 'buffs' then
            numRows, maxCols = CDMModule.RowMetrics(count, perRow)
        else
            numRows, maxCols = CDMModule.RowMetrics(count, perRow, viewerSettings.row2Count, viewerSettings.row3Count)
        end
        if numRows < 1 or maxCols < 1 then self:Hide(); return end

        local stepX, stepY = iconWidth + spacing, iconHeight + spacing
        local totalWidth, totalHeight
        if viewerSettings.vertical then
            totalWidth = numRows * iconWidth + (numRows - 1) * spacing
            totalHeight = maxCols * iconHeight + (maxCols - 1) * spacing
        else
            totalWidth = maxCols * iconWidth + (maxCols - 1) * spacing
            totalHeight = numRows * iconHeight + (numRows - 1) * spacing
        end
        self:SetSize(totalWidth, totalHeight)
        self:SetScale(math.min(1, 620 / totalWidth, 150 / totalHeight))

        local growUp = viewerSettings.rowGrowth == 'Up'
        local iconIndex = 0
        local remaining = count
        for row = 1, numRows do
            local rowCount
            if viewerKey == 'buffs' then
                rowCount = CDMModule.NextRowSize(row, remaining, perRow)
            else
                rowCount = CDMModule.NextRowSize(row, remaining, perRow, viewerSettings.row2Count, viewerSettings.row3Count)
            end
            if rowCount <= 0 then break end
            remaining = remaining - rowCount
            local slot = growUp and (numRows - row) or (row - 1)
            for col = 0, rowCount - 1 do
                iconIndex = iconIndex + 1
                local cell = Cell(iconIndex)
                local x, y
                if viewerSettings.vertical then
                    local columnHeight = rowCount * iconHeight + (rowCount - 1) * spacing
                    local within = growUp and (rowCount - 1 - col) or col
                    x = (row - 1) * stepX
                    y = (totalHeight - columnHeight) / 2 + within * stepY
                else
                    local rowWidth = rowCount * iconWidth + (rowCount - 1) * spacing
                    local rowLeft = (totalWidth - rowWidth) / 2
                    if row == numRows and numRows > 1 and viewerSettings.centerLastRow == false then
                        rowLeft = 0
                    end
                    x = rowLeft + col * stepX
                    y = slot * stepY
                end
                local cellButton = cell.frame
                cell._slot = iconIndex
                cell._entry = list[iconIndex]
                cell._px, cell._py = x, y
                slotRects[iconIndex] = { x = x, y = y, w = iconWidth, h = iconHeight }
                cellButton:ClearAllPoints()
                cellButton:SetSize(iconWidth, iconHeight)
                cellButton:SetPoint('TOPLEFT', self, 'TOPLEFT', x, -y)
                cellButton:SetAlpha(1)
                cellButton:Show()
                cell.border:SetVertexColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderSize > 0 and (borderColor[4] or 1) or 0)
                cell.icon:ClearAllPoints()
                cell.icon:SetPoint('TOPLEFT', cellButton, 'TOPLEFT', borderSize, -borderSize)
                cell.icon:SetPoint('BOTTOMRIGHT', cellButton, 'BOTTOMRIGHT', -borderSize, borderSize)
                local entry = list[(iconIndex - 1) % #list + 1]
                cell.icon:SetTexture(entry.tex)
                cell.icon:SetTexCoord(CDMModule.GetAspectTexCoords(viewerSettings.zoom, iconWidth, iconHeight, viewerSettings.keepAspectRatio))
                cell.icon:Show(); cell.border:Show()

                if iconIndex % 3 == 2 then
                    cell.swipe:ClearAllPoints()
                    cell.swipe:SetSize(math.max(1, iconWidth - borderSize * 2), math.max(1, (iconHeight - borderSize * 2) * 0.55))
                    local edge = viewerSettings.reverseSwipe and 'TOP' or 'BOTTOM'
                    cell.swipe:SetPoint(edge, cell.icon, edge, 0, 0)
                    cell.swipe:SetVertexColor(swipeColor[1] or 0, swipeColor[2] or 0, swipeColor[3] or 0, swipeColor[4] or 0.58)
                    cell.swipe:Show()
                    local cooldownTextColor = viewerSettings.cooldownTextColor
                    BUI.Pixel.ApplyFont(cell.cd, viewerSettings.cooldownTextSize, font, 'OUTLINE')
                    cell.cd:SetText(tostring(2 + iconIndex))
                    cell.cd:ClearAllPoints()
                    local cooldownTextPoint = viewerSettings.cooldownTextPosition
                    local previewOffsetY = viewerSettings.cooldownTextOffsetY
                    if cooldownTextPoint == 'CENTER' and viewerSettings.cooldownTextSize > 0 then
                        previewOffsetY = previewOffsetY - BUI.CDM.CooldownTextCenterDrop(viewerSettings.cooldownTextSize)
                    end
                    cell.cd:SetPoint(cooldownTextPoint, cell.icon, cooldownTextPoint, viewerSettings.cooldownTextOffsetX, previewOffsetY)
                    cell.cd:SetTextColor(cooldownTextColor[1] or 1, cooldownTextColor[2] or 1, cooldownTextColor[3] or 1, cooldownTextColor[4] or 1)
                    cell.cd:Show()
                else
                    cell.swipe:Hide(); cell.cd:Hide()
                end

                if iconIndex % 4 == 3 then
                    local stackTextColor = viewerSettings.textColor
                    BUI.Pixel.ApplyFont(cell.stack, viewerSettings.textSize, font, 'OUTLINE')
                    cell.stack:SetText('2')
                    cell.stack:ClearAllPoints()
                    local stackTextPoint = viewerSettings.textPosition
                    cell.stack:SetPoint(stackTextPoint, cell.icon, stackTextPoint, viewerSettings.textOffsetX, viewerSettings.textOffsetY)
                    cell.stack:SetTextColor(stackTextColor[1] or 1, stackTextColor[2] or 1, stackTextColor[3] or 1, stackTextColor[4] or 1)
                    cell.stack:Show()
                else
                    cell.stack:Hide()
                end

                if withKeybinds and viewerSettings.showKeybinds then
                    local keybindColor = viewerSettings.keybindColor
                    BUI.Pixel.ApplyFont(cell.kb, viewerSettings.keybindFontSize, ResolveCDMMedia('font', viewerSettings.keybindFont, font), 'OUTLINE')
                    cell.kb:SetText(CDM_MOCK_KEYS[(iconIndex - 1) % #CDM_MOCK_KEYS + 1])
                    cell.kb:ClearAllPoints()
                    local keybindPoint = viewerSettings.keybindAnchor
                    cell.kb:SetPoint(keybindPoint, cell.icon, keybindPoint, viewerSettings.keybindOffsetX, viewerSettings.keybindOffsetY)
                    cell.kb:SetTextColor(keybindColor[1] or 1, keybindColor[2] or 1, keybindColor[3] or 1, keybindColor[4] or 1)
                    cell.kb:Show()
                else
                    cell.kb:Hide()
                end
            end
        end
        for cellIndex = iconIndex + 1, #cells do
            cells[cellIndex].frame:Hide()
            cells[cellIndex]._entry = nil
        end
        self:Show()
    end

    return holder
end

local CDM_MOCK_BARS = {
    { icon = 'Interface\\Icons\\Spell_Nature_Rejuvenation', name = 'Rejuvenation', dur = '12s', fill = 0.78 },
    { icon = 'Interface\\Icons\\Ability_Warrior_BattleShout', name = 'Battle Shout', dur = '48s', fill = 0.52 },
    { icon = 'Interface\\Icons\\Spell_Holy_PowerWordShield', name = 'Power Word: Shield', dur = '8s', fill = 0.24 },
}

local function CreateBuffBarMock(stage)
    local WHITE = 'Interface\\Buttons\\WHITE8x8'
    local holder = CreateFrame('Frame', nil, stage)
    holder:SetPoint('CENTER')
    local barsPool = {}

    local function Bar(barIndex)
        if not barsPool[barIndex] then
            local bar = {}
            bar.border = holder:CreateTexture(nil, 'BACKGROUND')
            bar.border:SetTexture(WHITE)
            bar.bg = holder:CreateTexture(nil, 'BORDER')
            bar.bg:SetTexture(WHITE)
            bar.fill = holder:CreateTexture(nil, 'ARTWORK')
            bar.iconBorder = holder:CreateTexture(nil, 'BACKGROUND')
            bar.iconBorder:SetTexture(WHITE)
            bar.icon = holder:CreateTexture(nil, 'ARTWORK')
            bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            bar.name = holder:CreateFontString(nil, 'OVERLAY')
            bar.dur = holder:CreateFontString(nil, 'OVERLAY')
            bar.hit = CreateFrame('Button', nil, holder)
            bar.hit:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
            SetScript(bar.hit, 'OnClick', function(self)
                if not self._spellID then return end
                local items = { { title = true, text = self._name or 'Buff Bar' } }
                local procConfig = BUI.CDM.GetProcConfig(self._spellID)
                items[#items + 1] = {
                    text = procConfig and 'Settings... |cffffe066(active)|r' or 'Settings...',
                    callback = function()
                        BUI.ShowCDMProcModal(BUI.CDM, self._spellID, function() holder:Render() end)
                    end,
                }
                items[#items + 1] = { separator = true }
                items[#items + 1] = { text = 'Manage Icons...', callback = function()
                    local configPage = BUI.PageEngine.pages.cdm
                    local pageControl = configPage.frame and configPage.frame._page
                    if pageControl and pageControl.SetTab then pageControl:SetTab(7) end
                end }
                Controls.ContextMenu(items, { width = 230 })
            end)
            SetScript(bar.hit, 'OnEnter', function(self)
                if not self._spellID then return end
                BUILib.Widget.ShowTip(self, (self._name or 'Buff Bar') .. '|n|cff888888Click for options|r')
            end)
            SetScript(bar.hit, 'OnLeave', function() BUILib.Widget.HideTip() end)
            barsPool[barIndex] = bar
        end
        return barsPool[barIndex]
    end

    function holder:Render()
        local config = BUI.GetDB().cdm.buffBars
        if not config then self:Hide(); return end
        local barWidth = config.barWidth
        local barHeight = config.barHeight
        local iconSize = config.iconSize
        local showIcon = config.showIcon ~= false
        local spacing = config.spacing
        local borderSize = config.borderSize
        local borderColor = config.borderColor
        local backgroundColor = config.bgColor
        local fillColor = config.barColor
        if config.useClassColor then
            local _, playerClass = UnitClass('player')
            local classColor = playerClass and RAID_CLASS_COLORS[playerClass]
            if classColor then fillColor = { classColor.r, classColor.g, classColor.b, 1 } end
        end
        local barTexture = ResolveCDMMedia('statusbar', config.texture, BUI.GetGlobalTexture())
        local font = BUI.GetGlobalFont()

        local live = GetViewerSpellList('buffBars')
        if not live or #live == 0 then self:Hide(); return end
        local rowHeight = math.max(barHeight, showIcon and iconSize or 0)
        local totalWidth = barWidth + (showIcon and (iconSize + 2) or 0)
        local barCount = math.min(#live, 3)
        local totalHeight = barCount * rowHeight + (barCount - 1) * spacing
        self:SetSize(totalWidth, totalHeight)
        self:SetScale(math.min(1, 620 / totalWidth, 150 / totalHeight))

        local growDirection = config.growDirection
        for barIndex = 1, barCount do
            local mockBar = CDM_MOCK_BARS[(barIndex - 1) % #CDM_MOCK_BARS + 1]
            local entry = live[barIndex]
            local iconTexture = entry.icon
            local barName = C_Spell.GetSpellName(entry.spellID) or mockBar.name
            local bar = Bar(barIndex)
            local slot = growDirection == 'UP' and (barCount - barIndex + 1) or barIndex
            local y = (slot - 1) * (rowHeight + spacing)
            local x = 0
            if showIcon then
                local iconY = y + (rowHeight - iconSize) / 2
                bar.iconBorder:ClearAllPoints()
                bar.iconBorder:SetSize(iconSize + borderSize * 2, iconSize + borderSize * 2)
                bar.iconBorder:SetPoint('TOPLEFT', self, 'TOPLEFT', -borderSize, -iconY + borderSize)
                bar.iconBorder:SetVertexColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderSize > 0 and (borderColor[4] or 1) or 0)
                bar.icon:ClearAllPoints()
                bar.icon:SetSize(iconSize, iconSize)
                bar.icon:SetPoint('TOPLEFT', self, 'TOPLEFT', 0, -iconY)
                bar.icon:SetTexture(iconTexture)
                bar.icon:Show(); bar.iconBorder:Show()
                x = iconSize + 2
            else
                bar.icon:Hide(); bar.iconBorder:Hide()
            end
            local barY = y + (rowHeight - barHeight) / 2
            bar.border:ClearAllPoints()
            bar.border:SetSize(barWidth + borderSize * 2, barHeight + borderSize * 2)
            bar.border:SetPoint('TOPLEFT', self, 'TOPLEFT', x - borderSize, -barY + borderSize)
            bar.border:SetVertexColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderSize > 0 and (borderColor[4] or 1) or 0)
            bar.bg:ClearAllPoints()
            bar.bg:SetSize(barWidth, barHeight)
            bar.bg:SetPoint('TOPLEFT', self, 'TOPLEFT', x, -barY)
            bar.bg:SetVertexColor(backgroundColor[1] or 0.1, backgroundColor[2] or 0.1, backgroundColor[3] or 0.1, backgroundColor[4] or 0.85)
            bar.fill:SetTexture(barTexture)
            bar.fill:ClearAllPoints()
            bar.fill:SetSize(math.max(1, barWidth * mockBar.fill), barHeight)
            bar.fill:SetPoint('TOPLEFT', self, 'TOPLEFT', x, -barY)
            bar.fill:SetVertexColor(fillColor[1] or 1, fillColor[2] or 0.5, fillColor[3] or 0.25, fillColor[4] or 1)
            bar.bg:Show(); bar.fill:Show(); bar.border:Show()
            if config.showName ~= false then
                BUI.Pixel.ApplyFont(bar.name, config.nameSize, font)
                bar.name:SetText(barName)
                bar.name:ClearAllPoints()
                bar.name:SetPoint('LEFT', bar.bg, 'LEFT', 4, 0)
                bar.name:SetTextColor(1, 1, 1, 1)
                bar.name:Show()
            else
                bar.name:Hide()
            end
            if config.showDuration ~= false then
                BUI.Pixel.ApplyFont(bar.dur, config.durationSize, font)
                bar.dur:SetText(mockBar.dur)
                bar.dur:ClearAllPoints()
                bar.dur:SetPoint('RIGHT', bar.bg, 'RIGHT', -4, 0)
                bar.dur:SetTextColor(1, 1, 1, 1)
                bar.dur:Show()
            else
                bar.dur:Hide()
            end
            bar.hit._spellID = entry.spellID
            bar.hit._name = barName
            bar.hit:ClearAllPoints()
            bar.hit:SetPoint('TOPLEFT', self, 'TOPLEFT', -borderSize, -y)
            bar.hit:SetSize(totalWidth + borderSize * 2, rowHeight)
            bar.hit:Show()
        end
        for barIndex = barCount + 1, #barsPool do
            local bar = barsPool[barIndex]
            bar.border:Hide(); bar.bg:Hide(); bar.fill:Hide()
            bar.iconBorder:Hide(); bar.icon:Hide()
            bar.name:Hide(); bar.dur:Hide()
            bar.hit:Hide()
        end
        self:Show()
    end

    return holder
end

local function InstallCDMHeader(page, tabIndex, config)
    local PageKit = BUILib.PageKit
    local tab = page:GetTab(tabIndex)
    local width = page.width
    local titleHeight, titleBar = PageKit.PageTitle(tab.pinned, config.title, width, {
        desc = config.desc, enable = config.enable, anchor = config.anchor, button = config.button,
    })
    local pinnedHeight = PageKit.PAD + titleHeight
    local header = { titleBar = titleBar }
    if config.preview then
        local band = PageKit.PreviewBand(tab.pinned, width, Layout.PAGE_PREVIEW_H, pinnedHeight)
        local _, stage = PageKit.PreviewStage(band)
        header.band, header.stage = band, stage
        pinnedHeight = pinnedHeight + Layout.PAGE_PREVIEW_H + PageKit.GAP
    end
    tab:SetPinnedHeight(pinnedHeight)
    cdmHeaders[tabIndex] = header
    return header
end

local function HookCDMRefreshers(CDM)
    if CDM._pageMockHooked then return end
    CDM._pageMockHooked = true
    local function Wrap(owner, name)
        local original = owner[name]
        if not original then return end
        owner[name] = function(...)
            local result1, result2, result3 = original(...)
            RefreshCDMMocks()
            return result1, result2, result3
        end
    end
    Wrap(CDM, 'RefreshSizeSettings')
    Wrap(CDM, 'RefreshSkinSettings')
    Wrap(CDM, 'RefreshLayoutOnly')
    Wrap(CDM, 'RefreshBuffBarSkin')
    Wrap(CDM, 'RefreshCooldownStyleFlags')
    Wrap(CDM, 'SyncSetting')
    Wrap(CDM, 'SyncSettingLayout')
    Wrap(CDM.Keybinds, 'StyleViewer')
    Wrap(CDM.Keybinds, 'RefreshViewer')
end

local function BuildViewerSettings(tab, viewerKey, db, CDM)
    local PageKit = BUILib.PageKit
    local viewerSettings = db.cdm[viewerKey]
    local canSync = viewerKey ~= "buffs"

    local function TrySync(key, value)
        if canSync and CDM.SyncSetting(key, value) then return end
        if CDM.SIZE_SETTINGS[key] then
            CDM.RefreshSizeSettings()
        else
            CDM.RefreshSkinSettings()
        end
    end
    local function TrySyncLayout(key, value)
        if canSync and CDM.SyncSettingLayout(key, value) then return end
        CDM.RefreshLayoutOnly()
    end

    local grids = {}
    local grid
    local function Section(title)
        if grid then grid:Flush() end
        Layout.Section(tab, title)
        grid = PageKit.RowGrid(tab)
        grids[#grids + 1] = grid
    end
    local function AddRow(config)
        return grid:Add(config)
    end

    cdmGrids[viewerKey] = {
        SyncDim = function(_, enabled)
            for gridIndex = 1, #grids do grids[gridIndex]:SyncDim(enabled) end
        end,
    }

    local SELF_ANCHOR_NAMES = {
        essential = "BUI_EssentialCooldownViewer",
        utility = "BUI_UtilityCooldownViewer",
        buffs = "BUI_BuffCooldownViewer",
    }
    local selfAnchorName = SELF_ANCHOR_NAMES[viewerKey]
    local anchorFrameList = {}
    for _, entry in ipairs(BUI.C.ANCHOR_FRAMES) do
        if entry.tag ~= selfAnchorName then
            anchorFrameList[#anchorFrameList + 1] = entry
        end
    end

    local posDb = setmetatable({}, {
        __index = function(_, key) return viewerSettings[key] end,
        __newindex = function(_, key, value)
            if key == "centerHorizontally" then
                TrySync("centerHorizontally", value)
                CDM.OnCenterHorizontallyChanged(viewerKey, value)
            else
                viewerSettings[key] = value
            end
        end,
    })
    local function ApplyPos()
        CDM.ApplyPosition(viewerKey); CDM.RefreshLayoutOnly()
    end

    Section('Layout')

    AddRow({
        title = 'Position',
        description = 'Screen position, or anchor to another frame.',
        plain = true,
        accessoryWidth = 36,
        accessories = function(row)
            return { BUI.AlertMover(row, posDb, ApplyPos, {
                fields = { posX = 'positionX', posY = 'positionY' },
                frames = anchorFrameList,
            }) }
        end,
    })

    local rowOptions = {
        { kind = 'dropdown', label = 'Row Growth', items = BUI.C.ROW_GROWTH_OPTIONS,
          get = function() return viewerSettings.rowGrowth end,
          set = function(value) viewerSettings.rowGrowth = value; TrySyncLayout('rowGrowth', value) end },
        { kind = 'slider', label = 'Row 1 Count', min = 0, max = 20,
          get = function() return viewerSettings.iconsPerRow end,
          set = function(value) viewerSettings.iconsPerRow = value; TrySyncLayout('iconsPerRow', value) end },
        { kind = 'slider', label = 'Row 2 Count', min = 0, max = 20,
          get = function() return viewerSettings.row2Count or 0 end,
          set = function(value) viewerSettings.row2Count = value; TrySyncLayout('row2Count', value) end },
    }
    if viewerKey ~= "buffs" then
        rowOptions[#rowOptions + 1] = { kind = 'slider', label = 'Row 3 Count', min = 0, max = 20,
            get = function() return viewerSettings.row3Count or 0 end,
            set = function(value) viewerSettings.row3Count = value; TrySyncLayout('row3Count', value) end }
        rowOptions[#rowOptions + 1] = { label = 'Center Last Row',
            get = function() return viewerSettings.centerLastRow end,
            set = function(value) viewerSettings.centerLastRow = value; CDM.RefreshLayoutOnly() end }
    end
    rowOptions[#rowOptions + 1] = { label = 'Vertical',
        get = function() return viewerSettings.vertical end,
        set = function(value) viewerSettings.vertical = value; TrySyncLayout('vertical', value) end }

    AddRow({
        title = 'Icon Rows',
        description = 'Growth direction and icons per row.',
        plain = true,
        accessoryWidth = 36,
        accessories = function(row)
            return { PageKit.SettingsIcon(row, { title = 'ICON ROWS', tooltip = 'Growth & row counts', options = rowOptions }) }
        end,
    })

    Section('Appearance')

    AddRow({
        title = 'Icon Size',
        description = 'Width, height, spacing and zoom.',
        plain = true,
        accessoryWidth = 36,
        accessories = function(row)
            return { PageKit.SizeIcon(row, { title = 'ICON SIZE', options = {
                { kind = 'slider', label = 'Icon Width', min = 20, max = 100,
                  get = function() return viewerSettings.iconWidth or viewerSettings.iconSize or 38 end,
                  set = function(value) viewerSettings.iconWidth = value; TrySync('iconWidth', value) end },
                { kind = 'slider', label = 'Icon Height', min = 10, max = 100,
                  get = function() return viewerSettings.iconHeight or (viewerSettings.iconWidth or viewerSettings.iconSize or 38) * viewerSettings.aspectRatio end,
                  set = function(value) viewerSettings.iconHeight = value; TrySync('iconHeight', value) end },
                { kind = 'slider', label = 'Spacing', min = -20, max = 20,
                  get = function() return viewerSettings.spacing end,
                  set = function(value) viewerSettings.spacing = value; TrySyncLayout('spacing', value) end },
                { kind = 'slider', label = 'Zoom %', min = 0, max = 20,
                  get = function() return viewerSettings.zoom * 100 end,
                  set = function(value) viewerSettings.zoom = value / 100; TrySync('zoom', viewerSettings.zoom) end },
            } }) }
        end,
    })

    AddRow({
        title = 'Border',
        description = 'Outline around each icon.',
        plain = true,
        accessoryWidth = 64,
        accessories = function(row)
            local cog = PageKit.SettingsIcon(row, { title = 'BORDER', tooltip = 'Border thickness', options = {
                { kind = 'slider', label = 'Border Size', min = 0, max = 5,
                  get = function() return viewerSettings.borderSize end,
                  set = function(value) viewerSettings.borderSize = value; TrySync('borderSize', value) end },
            } })
            local borderColor = viewerSettings.borderColor
            local swatch = Controls.ColorSwatch(row, {
                r = borderColor[1], g = borderColor[2], b = borderColor[3], a = borderColor[4],
                tooltip = 'Border color',
                callback = function(red, green, blue, alpha)
                    viewerSettings.borderColor = { red, green, blue, alpha }; TrySync('borderColor', { red, green, blue, alpha })
                end,
            })
            return { cog, swatch }
        end,
    })

    AddRow({
        title = 'Keep Aspect Ratio',
        description = 'Icon height follows width at its native shape.',
        checked = viewerSettings.keepAspectRatio,
        callback = function(value)
            viewerSettings.keepAspectRatio = value or nil; TrySync('keepAspectRatio', viewerSettings.keepAspectRatio)
        end,
    })

    AddRow({
        title = 'Reverse Swipe',
        description = 'Cooldown sweep fills up instead of emptying.',
        checked = viewerSettings.reverseSwipe,
        callback = function(value) viewerSettings.reverseSwipe = value; TrySync('reverseSwipe', value) end,
        accessoryWidth = 36,
        accessories = function(row)
            local swipeColor = viewerSettings.swipeColor
            return { Controls.ColorSwatch(row, {
                r = swipeColor[1], g = swipeColor[2], b = swipeColor[3], a = swipeColor[4],
                tooltip = 'Swipe color',
                callback = function(red, green, blue, alpha)
                    viewerSettings.swipeColor = { red, green, blue, alpha }; TrySync('swipeColor', { red, green, blue, alpha })
                end,
            }) }
        end,
    })

    Section('Text')

    AddRow({
        title = 'Cooldown Text',
        description = 'Remaining-time countdown on each icon.',
        plain = true,
        accessoryWidth = 64,
        accessories = function(row)
            local cog = PageKit.SettingsIcon(row, { title = 'COOLDOWN TEXT', tooltip = 'Position, size, decimals & warning color', options = {
                { kind = 'dropdown', label = 'Position', items = POS_OPTIONS,
                  get = function() return viewerSettings.cooldownTextPosition end,
                  set = function(value) viewerSettings.cooldownTextPosition = value; TrySync('cooldownTextPosition', value) end },
                { kind = 'slider', label = 'Size', min = 0, max = 30,
                  get = function() return viewerSettings.cooldownTextSize end,
                  set = function(value) viewerSettings.cooldownTextSize = value; TrySync('cooldownTextSize', value) end },
                { kind = 'slider', label = 'Offset X', min = -30, max = 30,
                  get = function() return viewerSettings.cooldownTextOffsetX end,
                  set = function(value) viewerSettings.cooldownTextOffsetX = value; TrySync('cooldownTextOffsetX', value) end },
                { kind = 'slider', label = 'Offset Y', min = -30, max = 30,
                  get = function() return viewerSettings.cooldownTextOffsetY end,
                  set = function(value) viewerSettings.cooldownTextOffsetY = value; TrySync('cooldownTextOffsetY', value) end },
                { label = 'Show Decimals',
                  get = function() return viewerSettings.showCooldownDecimals end,
                  set = function(value) viewerSettings.showCooldownDecimals = value; TrySync('showCooldownDecimals', value) end },
                { kind = 'slider', label = 'Decimal Threshold', min = 1, max = 30,
                  get = function() return viewerSettings.cooldownDecimalThreshold end,
                  set = function(value) viewerSettings.cooldownDecimalThreshold = value; TrySync('cooldownDecimalThreshold', value) end },
                { kind = 'slider', label = 'Warning Seconds', min = 0, max = 10,
                  get = function() return viewerSettings.cooldownWarnSeconds or 0 end,
                  set = function(value) viewerSettings.cooldownWarnSeconds = value; TrySync('cooldownWarnSeconds', value) end },
                { kind = 'swatch', label = 'Warning Color', tooltip = 'Countdown color inside the warning window',
                  get = function() return viewerSettings.cooldownWarnColor end,
                  set = function(value) viewerSettings.cooldownWarnColor = value; TrySync('cooldownWarnColor', value) end },
            } })
            local cooldownColor = viewerSettings.cooldownTextColor
            local swatch = Controls.ColorSwatch(row, {
                r = cooldownColor[1], g = cooldownColor[2], b = cooldownColor[3], a = cooldownColor[4],
                tooltip = 'Cooldown text color',
                callback = function(red, green, blue, alpha)
                    viewerSettings.cooldownTextColor = { red, green, blue, alpha }; TrySync('cooldownTextColor', { red, green, blue, alpha })
                end,
            })
            return { cog, swatch }
        end,
    })

    AddRow({
        title = 'Stack Text',
        description = 'Charge and stack counts on each icon.',
        plain = true,
        accessoryWidth = 64,
        accessories = function(row)
            local cog = PageKit.SettingsIcon(row, { title = 'STACK TEXT', tooltip = 'Position & size', options = {
                { kind = 'dropdown', label = 'Position', items = POS_OPTIONS,
                  get = function() return viewerSettings.textPosition end,
                  set = function(value) viewerSettings.textPosition = value; TrySync('textPosition', value) end },
                { kind = 'slider', label = 'Size', min = 0, max = 30,
                  get = function() return viewerSettings.textSize end,
                  set = function(value) viewerSettings.textSize = value; TrySync('textSize', value) end },
                { kind = 'slider', label = 'Offset X', min = -30, max = 30,
                  get = function() return viewerSettings.textOffsetX end,
                  set = function(value) viewerSettings.textOffsetX = value; TrySync('textOffsetX', value) end },
                { kind = 'slider', label = 'Offset Y', min = -30, max = 30,
                  get = function() return viewerSettings.textOffsetY end,
                  set = function(value) viewerSettings.textOffsetY = value; TrySync('textOffsetY', value) end },
            } })
            local stackColor = viewerSettings.textColor
            local swatch = Controls.ColorSwatch(row, {
                r = stackColor[1], g = stackColor[2], b = stackColor[3], a = stackColor[4],
                tooltip = 'Stack text color',
                callback = function(red, green, blue, alpha)
                    viewerSettings.textColor = { red, green, blue, alpha }; TrySync('textColor', { red, green, blue, alpha })
                end,
            })
            return { cog, swatch }
        end,
    })

    if viewerKey == "essential" or viewerKey == "utility" then
        Section('Keybinds')

        local keybindFonts = BUI.BuildFontDropdownItems("GLOBAL")
        AddRow({
            spanFull = true,
            title = 'Keybind Text',
            description = 'Key labels on each icon, read from your action bars.',
            checked = viewerSettings.showKeybinds,
            callback = function(value)
                viewerSettings.showKeybinds = value; CDM.Keybinds.RefreshViewer(viewerKey)
            end,
            accessoryWidth = 64,
            accessories = function(row)
                local cog = PageKit.SettingsIcon(row, { title = 'KEYBIND TEXT', tooltip = 'Anchor, font & offset', options = {
                    { kind = 'dropdown', label = 'Anchor', items = POS_OPTIONS,
                      get = function() return viewerSettings.keybindAnchor end,
                      set = function(value) viewerSettings.keybindAnchor = value; CDM.Keybinds.StyleViewer(viewerKey) end },
                    { kind = 'dropdown', label = 'Font', items = keybindFonts,
                      get = function() return viewerSettings.keybindFont end,
                      set = function(value) viewerSettings.keybindFont = value; CDM.Keybinds.StyleViewer(viewerKey) end },
                    { kind = 'slider', label = 'Font Size', min = 8, max = 24,
                      get = function() return viewerSettings.keybindFontSize end,
                      set = function(value) viewerSettings.keybindFontSize = value; CDM.Keybinds.StyleViewer(viewerKey) end },
                    { kind = 'slider', label = 'Offset X', min = -20, max = 20,
                      get = function() return viewerSettings.keybindOffsetX end,
                      set = function(value) viewerSettings.keybindOffsetX = value; CDM.Keybinds.StyleViewer(viewerKey) end },
                    { kind = 'slider', label = 'Offset Y', min = -20, max = 20,
                      get = function() return viewerSettings.keybindOffsetY end,
                      set = function(value) viewerSettings.keybindOffsetY = value; CDM.Keybinds.StyleViewer(viewerKey) end },
                } })
                local keybindColor = viewerSettings.keybindColor
                local swatch = Controls.ColorSwatch(row, {
                    r = keybindColor[1], g = keybindColor[2], b = keybindColor[3], a = keybindColor[4],
                    tooltip = 'Keybind text color',
                    callback = function(red, green, blue, alpha)
                        viewerSettings.keybindColor = { red, green, blue, alpha }; CDM.Keybinds.StyleViewer(viewerKey)
                    end,
                })
                return { cog, swatch }
            end,
        })
    end

    grid:Flush()
    cdmGrids[viewerKey]:SyncDim(viewerSettings.enabled)
end

local function BuildGeneralTab(tab, db, CDM)
    local PageKit = BUILib.PageKit

    local grid
    local function Section(title)
        if grid then grid:Flush() end
        Layout.Section(tab, title)
        grid = PageKit.RowGrid(tab)
    end
    local function AddRow(config)
        return grid:Add(config)
    end

    Section('Setup')

    AddRow({
        spanFull = true,
        title = 'Shortcuts',
        description = "Blizzard's Edit Mode, and the full Cooldown Viewer settings panel.",
        plain = true,
        accessoryWidth = 250,
        accessories = function(row)
            local advancedButton = Controls.Button(row, 'Advanced CDM', 120, function()
                if CooldownViewerSettings then CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown()) end
            end)
            local editModeButton = Controls.Button(row, 'Edit Mode', 110, BUI.ToggleEditMode)

            return { advancedButton, editModeButton }
        end,
    })

    local EditModeLock = CDM.EditModeLock
    do
        local GREEN, RED, AMBER = "|cff4CD964", "|cffF24C3D", "|cffF2B800"
        local SystemIndices  = Enum.EditModeCooldownViewerSystemIndices
        local SettingEnum = Enum.EditModeCooldownViewerSetting
        local VIEWER_NAME = {
            [SystemIndices.Essential] = "Essential",
            [SystemIndices.Utility]   = "Utility",
            [SystemIndices.BuffIcon]  = "Buff Icons",
        }
        if SystemIndices.BuffBar then VIEWER_NAME[SystemIndices.BuffBar] = "Buff Bars" end
        local SETTING_NAME = {
            [SettingEnum.VisibleSetting]   = "Always Visible",
            [SettingEnum.ShowTimer]        = "Show Timer",
            [SettingEnum.HideWhenInactive] = "Hide When Inactive",
        }
        local VIEWER_ORDER = { SystemIndices.Essential, SystemIndices.Utility, SystemIndices.BuffIcon, SystemIndices.BuffBar }

        local function EditModeStatus()
            local compliance = EditModeLock.GetCompliance()
            if not compliance.isReady then
                return AMBER .. "Edit Mode not loaded, /reload.|r"
            elseif compliance.isPreset then
                return RED .. "Blizzard preset layout. Make a custom one.|r"
            elseif compliance.isCompliant then
                return GREEN .. "Viewers configured.|r"
            end

            local byViewer = {}
            for _, mismatch in ipairs(compliance.mismatches) do
                local list = byViewer[mismatch.systemIndex]
                if not list then list = {}; byViewer[mismatch.systemIndex] = list end
                list[#list + 1] = SETTING_NAME[mismatch.setting]
            end
            local parts = {}
            for _, systemIndex in ipairs(VIEWER_ORDER) do
                if systemIndex and byViewer[systemIndex] then
                    parts[#parts + 1] = VIEWER_NAME[systemIndex] .. ": " .. table.concat(byViewer[systemIndex], ", ")
                end
            end
            return RED .. "Needs fixing: " .. table.concat(parts, "   ") .. "|r"
        end

        local editModeStatusText
        AddRow({
            spanFull = true,
            title = 'Edit Mode Setup',
            description = "Viewer visibility settings BluUI needs from Blizzard's Edit Mode.",
            plain = true,
            accessoryWidth = 130,
            accessories = function(row)
                return { Controls.Button(row, 'Apply Fix', 110, function()
                    local result = EditModeLock.ApplyRecommendedSettings()
                    if result == 'applied' then
                        BUI.Print('Viewers configured. /reload to apply.')
                    elseif result == 'noop' then
                        BUI.Print('Nothing to change.')
                    elseif result == 'preset' then
                        BUI.Print('Blizzard preset layout. Make a custom one.')
                    elseif result == 'in_combat' then
                        BUI.Print("Can't edit in combat.")
                    elseif result == 'not_ready' then
                        BUI.Print('Edit Mode not loaded, /reload.')
                    else
                        BUI.Print('Could not apply settings.')
                    end
                    CDM._emStatusRefresh()
                end) }
            end,
            extra = function(row)
                local statusText = row:CreateFontString(nil, 'OVERLAY')
                statusText:SetFont(BUILib.Font, 11, '')
                statusText:SetJustifyH('LEFT')
                statusText:SetWordWrap(true)
                statusText:SetSpacing(2)
                statusText:SetWidth(tab.width - 220)
                statusText:SetText(EditModeStatus())
                editModeStatusText = statusText
                return statusText
            end,
        })

        CDM._emStatusRefresh = function()
            editModeStatusText:SetText(EditModeStatus())
        end
    end

    Section('Behavior')

    AddRow({
        title = 'Sync Settings',
        description = 'Essential, Utility, and Buff Icons share one set of appearance settings.',
        checked = db.cdm.syncViewers,
        callback = function(value) db.cdm.syncViewers = value end,
    })

    AddRow({
        title = 'Move Icons Individually',
        description = 'Drag any icon out of its grid to place it freely.',
        checked = db.cdm.allowIndividualMove,
        callback = function(value)
            db.cdm.allowIndividualMove = value
            CDM.Detached.UpdateModifierWatcher()
            CDM.RefreshAll()
        end,
        accessoryWidth = 60,
        accessories = function(row)
            local cog = PageKit.SettingsIcon(row, {
                title = 'DETACHED ICONS', tooltip = 'Resize & snapping',
                options = {
                    { label = 'Resize Detached Icons',
                      get = function() return db.cdm.allowIndividualResize end,
                      set = function(value) db.cdm.allowIndividualResize = value end },
                    { label = 'Disable Snapping',
                      get = function() return db.cdm.disableSnapping end,
                      set = function(value) db.cdm.disableSnapping = value end },
                },
            })
            local reset = Controls.Icon(row, {
                texture = BUILib.GetLibMedia('reset'),
                tooltip = 'Reset all icon positions',
                onClick = function()
                    CDM.Detached.ClearAll('essential'); CDM.Detached.ClearAll('utility')
                    CDM.RefreshAll()
                end,
            })
            return { cog, reset }
        end,
    })

    Section('Display')

    AddRow({
        title = 'Blizzard Panel Overlay',
        description = "BluUI's overlay on Blizzard's Cooldown Viewer settings panel.",
        checked = db.cdm.showBlizzardOverlay,
        callback = function(value) db.cdm.showBlizzardOverlay = value end,
    })

    AddRow({
        title = 'Tooltips',
        description = 'Spell tooltips when hovering tracked icons.',
        checked = db.cdm.showTooltips ~= false,
        callback = function(value) db.cdm.showTooltips = value end,
    })

    AddRow({
        title = 'Buff Duration',
        description = 'Remaining time on tracked buff icons.',
        checked = db.cdm.showBuffDuration ~= false,
        callback = function(showDuration)
            db.cdm.showBuffDuration = showDuration
            CDM.RefreshBuffOverrideCache()
            for cooldown in pairs(CDM.CDMCooldowns) do
                CDM.ForceSpellCooldownIfBuffHidden(cooldown)
                local icon = cooldown:GetParent()
                if icon and icon.Icon then
                    if showDuration then
                        icon.Icon:SetDesaturation(0)
                    else
                        CDM.RefreshIconDesaturation(icon.Icon)
                    end
                end
            end
        end,
    })

    local function SetAllViewers(key, value)
        db.cdm.essential[key] = value; db.cdm.utility[key] = value; db.cdm.buffs[key] = value
        CDM.RefreshCooldownStyleFlags()
    end

    AddRow({
        title = 'Cooldown Flash',
        description = 'Flash animation when a cooldown completes.',
        checked = db.cdm.essential.showFlash,
        callback = function(value) SetAllViewers('showFlash', value) end,
    })

    AddRow({
        title = 'Cooldown Edge',
        description = 'Bright leading edge on the cooldown sweep.',
        checked = db.cdm.essential.showEdge,
        callback = function(value) SetAllViewers('showEdge', value) end,
    })

    AddRow({
        title = 'Font',
        description = 'Timer and stack text across the Cooldown Manager.',
        controlWidth = 160,
        control = function(row)
            return Controls.Dropdown(row, nil, BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION), db.general.cdmFont or BUI.C.GLOBAL_OPTION, function(value)
                db.general.cdmFont = value ~= BUI.C.GLOBAL_OPTION and value or nil; CDM.RefreshSkinSettings()
            end, nil, 150)
        end,
    })

    Section('Glow')

    local glowSettings = db.cdm.glow
    local glowTypeOptions = {}
    for _, glowType in ipairs(CDM.GLOW_TYPES) do glowTypeOptions[#glowTypeOptions + 1] = { value = glowType.id, text = glowType.name } end

    AddRow({
        spanFull = true,
        title = 'Custom Glows',
        description = "BluUI-styled glow for procs and alerts, replacing Blizzard's highlight.",
        checked = glowSettings.enabled,
        callback = function(value)
            glowSettings.enabled = value; CDM.RefreshActiveGlows(); CDM.RefreshSkinSettings()
        end,
        accessoryWidth = 230,
        accessories = function(row)
            local styleDropdown = Controls.Dropdown(row, nil, glowTypeOptions, glowSettings.type, function(value)
                glowSettings.type = value; CDM.RefreshActiveGlows()
            end, nil, 140)
            local cog = PageKit.SettingsIcon(row, {
                title = 'GLOW SHAPE', tooltip = 'Speed, lines & thickness',
                options = {
                    { kind = 'slider', label = 'Speed %', min = 25, max = 400, step = 25,
                      get = function() return glowSettings.speed end,
                      set = function(value) glowSettings.speed = value end,
                      apply = function() CDM.RefreshActiveGlows() end },
                    { kind = 'slider', label = 'Lines (Pixel)', min = 4, max = 16, step = 1,
                      get = function() return glowSettings.lines end,
                      set = function(value) glowSettings.lines = value end,
                      apply = function() CDM.RefreshActiveGlows() end },
                    { kind = 'slider', label = 'Thickness (Pixel)', min = 1, max = 5, step = 1,
                      get = function() return glowSettings.thickness end,
                      set = function(value) glowSettings.thickness = value end,
                      apply = function() CDM.RefreshActiveGlows() end },
                },
            })
            local glowColor = glowSettings.color
            local swatch = Controls.ColorSwatch(row, {
                r = glowColor[1], g = glowColor[2], b = glowColor[3], a = glowColor[4],
                tooltip = 'Glow color',
                callback = function(red, green, blue, alpha)
                    glowSettings.color = { red, green, blue, alpha }; CDM.RefreshActiveGlows(); CDM.RefreshGlowPreview()
                end,
            })
            local previewToggle = Controls.IconToggle(row, CDM.glowPreview and CDM.glowPreview:IsShown() or false, function(value)
                if value then CDM.ShowGlowPreview() else CDM.HideGlowPreview() end
            end, { texture = BUILib.GetLibMedia('eye'), size = 18, tooltip = 'Preview' })
            CDM._previewBtn = previewToggle
            return { styleDropdown, cog, swatch, previewToggle }
        end,
    })

    Section('Highlights')

    local assistSettings = db.cdm.assist
    AddRow({
        title = 'Assisted Highlight',
        description = "Color for Blizzard's Assisted Combat Highlight.",
        plain = true,
        accessoryWidth = 30,
        accessories = function(row)
            local assistColor = assistSettings.color
            return { Controls.ColorSwatch(row, {
                r = assistColor[1], g = assistColor[2], b = assistColor[3], a = assistColor[4],
                tooltip = 'Highlight color',
                callback = function(red, green, blue, alpha)
                    assistSettings.color = { red, green, blue, alpha }; CDM.RefreshAssistHighlight()
                end,
            }) }
        end,
    })

    local pressHighlightSettings = db.cdm.pressHighlight
    AddRow({
        spanFull = true,
        title = 'Keypress Highlight',
        description = 'Flash the icon when its key is pressed.',
        checked = pressHighlightSettings.enabled,
        callback = function(value)
            pressHighlightSettings.enabled = value; CDM.PressHighlight.Refresh()
        end,
        accessoryWidth = 200,
        accessories = function(row)
            local styleDropdown = Controls.Dropdown(row, nil, CDM.PressHighlight.OVERLAY_STYLES, pressHighlightSettings.overlayStyle, function(value)
                pressHighlightSettings.overlayStyle = value; CDM.PressHighlight.Refresh()
            end, nil, 140)
            local cog = PageKit.SettingsIcon(row, {
                title = 'KEYPRESS BORDER', tooltip = 'Border & border color',
                options = {
                    { label = 'Show Border',
                      get = function() return pressHighlightSettings.showBorder end,
                      set = function(value) pressHighlightSettings.showBorder = value end,
                      apply = function() CDM.PressHighlight.Refresh() end,
                      swatch = function()
                          local borderColor = pressHighlightSettings.borderColor
                          return { r = borderColor[1], g = borderColor[2], b = borderColor[3], a = borderColor[4],
                              callback = function(red, green, blue, alpha)
                                  pressHighlightSettings.borderColor = { red, green, blue, alpha }; CDM.PressHighlight.Refresh()
                              end }
                      end },
                },
            })
            local tintColor = pressHighlightSettings.tintColor
            local tintSwatch = Controls.ColorSwatch(row, {
                r = tintColor[1], g = tintColor[2], b = tintColor[3], a = tintColor[4],
                tooltip = 'Tint color',
                callback = function(red, green, blue, alpha)
                    pressHighlightSettings.tintColor = { red, green, blue, alpha }; CDM.PressHighlight.Refresh()
                end,
            })
            return { styleDropdown, cog, tintSwatch }
        end,
    })

    grid:Flush()
end

local function BuildBuffBarsTab(tab, db, CDM)
    local PageKit = BUILib.PageKit
    local config = db.cdm.buffBars
    local function Refresh() CDM.RefreshBuffBarSkin() end
    local function Reposition() CDM.RepositionBuffBarRack(); Refresh() end

    local grids = {}
    local grid
    local function Section(title)
        if grid then grid:Flush() end
        Layout.Section(tab, title)
        grid = PageKit.RowGrid(tab)
        grids[#grids + 1] = grid
    end
    local function AddRow(rowConfig)
        return grid:Add(rowConfig)
    end

    cdmGrids.buffBars = {
        SyncDim = function(_, enabled)
            for gridIndex = 1, #grids do grids[gridIndex]:SyncDim(enabled) end
        end,
    }

    Section('Layout')

    AddRow({
        title = 'Position',
        description = 'Screen position, or anchor to another frame.',
        plain = true,
        accessoryWidth = 36,
        accessories = function(row)
            return { BUI.AlertMover(row, config, Reposition, {
                fields = { posX = 'positionX', posY = 'positionY' },
                anchorRange = 500,
                matchWidth = {
                    get = function() return config.matchAnchorWidth end,
                    set = function(value) config.matchAnchorWidth = value; Refresh() end,
                },
            }) }
        end,
    })

    AddRow({
        title = 'Grow Direction',
        description = 'New bars extend downward or upward.',
        controlWidth = 130,
        control = function(row)
            return Controls.Dropdown(row, nil, {
                { value = 'DOWN', text = 'Down' },
                { value = 'UP',   text = 'Up'   },
            }, config.growDirection, function(value)
                config.growDirection = value; Reposition()
            end, nil, 110)
        end,
    })

    Section('Bars')

    AddRow({
        title = 'Bar Size',
        description = 'Width, height and spacing.',
        plain = true,
        accessoryWidth = 36,
        accessories = function(row)
            return { PageKit.SizeIcon(row, { title = 'BAR SIZE', options = {
                { kind = 'slider', label = 'Bar Width', min = 80, max = 400,
                  get = function() return config.barWidth end,
                  set = function(value) config.barWidth = value; Refresh() end },
                { kind = 'slider', label = 'Bar Height', min = 10, max = 50,
                  get = function() return config.barHeight end,
                  set = function(value) config.barHeight = value; Refresh() end },
                { kind = 'slider', label = 'Spacing', min = 0, max = 30,
                  get = function() return config.spacing end,
                  set = function(value) config.spacing = value; Refresh() end },
            } }) }
        end,
    })

    AddRow({
        title = 'Icon',
        description = 'Buff icon beside each bar.',
        checked = config.showIcon ~= false,
        callback = function(value) config.showIcon = value; Reposition() end,
        accessoryWidth = 36,
        accessories = function(row)
            return { PageKit.SizeIcon(row, { title = 'ICON', options = {
                { kind = 'slider', label = 'Icon Size', min = 12, max = 64,
                  get = function() return config.iconSize end,
                  set = function(value) config.iconSize = value; Refresh() end },
            } }) }
        end,
    })

    AddRow({
        title = 'Class Color Bar',
        description = 'Fill bars with your class color.',
        checked = config.useClassColor,
        callback = function(value) config.useClassColor = value; Refresh() end,
        accessoryWidth = 36,
        accessories = function(row)
            local barColor = config.barColor
            return { Controls.ColorSwatch(row, {
                r = barColor[1], g = barColor[2], b = barColor[3], a = barColor[4],
                tooltip = 'Bar color (when not class-colored)',
                callback = function(red, green, blue, alpha)
                    config.barColor = { red, green, blue, alpha }; Refresh()
                end,
            }) }
        end,
    })

    AddRow({
        title = 'Backdrop',
        description = 'Border and background behind each bar.',
        plain = true,
        accessoryWidth = 64,
        accessories = function(row)
            local cog = PageKit.SettingsIcon(row, { title = 'BACKDROP', tooltip = 'Border size & color', options = {
                { kind = 'slider', label = 'Border Size', min = 0, max = 5,
                  get = function() return config.borderSize end,
                  set = function(value) config.borderSize = value; Refresh() end,
                  swatch = function()
                      local borderColor = config.borderColor
                      return { r = borderColor[1], g = borderColor[2], b = borderColor[3], a = borderColor[4],
                          callback = function(red, green, blue, alpha)
                              config.borderColor = { red, green, blue, alpha }; Refresh()
                          end }
                  end },
            } })
            local backgroundColor = config.bgColor
            local backgroundSwatch = Controls.ColorSwatch(row, {
                r = backgroundColor[1], g = backgroundColor[2], b = backgroundColor[3], a = backgroundColor[4],
                tooltip = 'Background color',
                callback = function(red, green, blue, alpha)
                    config.bgColor = { red, green, blue, alpha }; Refresh()
                end,
            })
            return { cog, backgroundSwatch }
        end,
    })

    Section('Text')

    local function TextRow(title, description, showKey, sizeKey, popoverTitle)
        AddRow({
            title = title,
            description = description,
            checked = config[showKey] ~= false,
            callback = function(value) config[showKey] = value; Refresh() end,
            accessoryWidth = 36,
            accessories = function(row)
                return { PageKit.SettingsIcon(row, { title = popoverTitle, tooltip = 'Text size', options = {
                    { kind = 'slider', label = 'Size', min = 6, max = 24,
                      get = function() return config[sizeKey] or 11 end,
                      set = function(value) config[sizeKey] = value; Refresh() end },
                } }) }
            end,
        })
    end

    TextRow('Name', 'Buff name on each bar.', 'showName', 'nameSize', 'NAME TEXT')
    TextRow('Duration', 'Remaining time on each bar.', 'showDuration', 'durationSize', 'DURATION TEXT')
    TextRow('Stacks', 'Stack count on each bar.', 'showStacks', 'stackSize', 'STACK TEXT')

    grid:Flush()
    cdmGrids.buffBars:SyncDim(config.skinEnabled)
end

local function BuildLayoutsTab(tab, CDM)
    local Profiles = CDM.Profiles

    if not Profiles.IsAvailable() then
        Layout.Section(tab, "Layout Snapshots",
            "Blizzard's Cooldown Manager layout API is not available on this game version.")
        return
    end

    local PageKit = BUILib.PageKit
    local ALL_LAYOUTS = "__all__"
    local selectedSnapshot
    local selectedExport = ALL_LAYOUTS
    local nameBox, snapshotDropdown, exportDropdown, shareBox

    local function SnapshotItems()
        local items = {}
        for _, snapshot in ipairs(Profiles.GetSnapshots()) do
            local text = snapshot.name
            if snapshot.class then text = text .. " |cff9d9d9d(" .. snapshot.class .. ")|r" end
            items[#items + 1] = { value = snapshot.name, text = text }
        end
        table.sort(items, function(itemA, itemB) return itemA.value < itemB.value end)
        return items
    end

    local function ExportItems()
        local items = { { value = ALL_LAYOUTS, text = "Everything (all layouts)" } }
        for _, layout in ipairs(Profiles.GetBlizzardLayouts()) do
            if not layout.isDefault then
                items[#items + 1] = { value = layout.id, text = "Only: " .. layout.name }
            end
        end
        return items
    end

    local function RefreshLists()
        local items = SnapshotItems()
        if not selectedSnapshot or not Profiles.FindSnapshot(selectedSnapshot) then
            selectedSnapshot = items[1] and items[1].value or nil
        end
        snapshotDropdown:SetItems(items)
        snapshotDropdown:SetValue(selectedSnapshot)
        local exportItems = ExportItems()
        local found = false
        for _, item in ipairs(exportItems) do
            if item.value == selectedExport then found = true break end
        end
        if not found then selectedExport = ALL_LAYOUTS end
        exportDropdown:SetItems(exportItems)
        exportDropdown:SetValue(selectedExport)
    end

    local function DoSave(name)
        name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then
            BUI.Print("Enter a name for the snapshot first.")
            return
        end
        local function Commit()
            local ok, result = Profiles.SaveSnapshot(name)
            if ok then
                BUI.Print("Saved snapshot: " .. result)
                selectedSnapshot = result
                nameBox:SetValue("")
                RefreshLists()
            else
                BUI.Print(result or "Could not save snapshot.")
            end
        end
        if Profiles.FindSnapshot(name) then
            Modals.Confirm({
                title = "Overwrite Snapshot",
                message = "'" .. name .. "' already exists. Overwrite it with your current setup?",
                confirmText = "Overwrite", cancelText = "Cancel", onConfirm = Commit,
            })
        else
            Commit()
        end
    end

    local function DoApply()
        if not selectedSnapshot then return end
        local name = selectedSnapshot
        Modals.Confirm({
            title = "Apply Snapshot",
            message = "Replace your current Cooldown Manager layouts with '" .. name .. "'?\n\nA backup snapshot of your current layouts is saved first. A reload is needed afterwards.",
            confirmText = "Apply", cancelText = "Cancel",
            onConfirm = function()
                local backed, backupName = Profiles.AutoBackupSnapshot()
                local ok, err = Profiles.ApplySnapshot(name)
                if ok then
                    if backed then RefreshLists() end
                    Modals.Confirm({
                        title = "Snapshot Applied",
                        message = backed and ("'" .. name .. "' is applied. Your previous layouts were saved as '" .. backupName .. "'.\n\nReload now to finish?") or ("'" .. name .. "' is applied. Reload now to finish?"),
                        confirmText = "Reload Now", cancelText = "Later",
                        onConfirm = function() BUI.Reload() end,
                    })
                else
                    BUI.Print(err or "Could not apply snapshot.")
                end
            end,
        })
    end

    Layout.Section(tab, 'Snapshots')
    local snapshotGrid = PageKit.RowGrid(tab)

    snapshotGrid:Add({
        spanFull = true,
        title = 'New Snapshot',
        description = 'Save your current Cooldown Manager layouts under a name.',
        plain = true,
        accessoryWidth = 320,
        accessories = function(row)
            nameBox = Controls.TextBox(row, nil, "", function(text) DoSave(text) end, nil, 220)
            local saveButton = Controls.GhostButton(row, "Save", 80, function()
                DoSave(nameBox:GetValue())
            end)
            return { saveButton, nameBox }
        end,
    })

    snapshotGrid:Add({
        spanFull = true,
        title = 'Saved Snapshots',
        description = 'Apply a saved snapshot, or delete it.',
        plain = true,
        accessoryWidth = 340,
        accessories = function(row)
            snapshotDropdown = Controls.Dropdown(row, nil, SnapshotItems(), selectedSnapshot, function(value) selectedSnapshot = value end, nil, 220)
            local applyButton = Controls.GhostButton(row, "Apply", 80, DoApply)
            local deleteButton = Controls.Icon(row, {
                texture = BUILib.GetLibMedia('delete'),
                tooltip = "Delete this snapshot",
                onClick = function()
                    if not selectedSnapshot then return end
                    local name = selectedSnapshot
                    Modals.Confirm({
                        title = "Delete Snapshot", message = "Delete '" .. name .. "'?",
                        confirmText = "Delete", cancelText = "Cancel",
                        onConfirm = function()
                            local ok, err = Profiles.DeleteSnapshot(name)
                            if ok then
                                BUI.Print("Deleted snapshot: " .. name)
                                selectedSnapshot = nil
                                RefreshLists()
                            else
                                BUI.Print(err or "Could not delete snapshot.")
                            end
                        end,
                    })
                end,
            })
            local deleteFrame = BUILib.Widget.Unwrap(deleteButton)
            deleteFrame.icon:SetVertexColor(0.55, 0.5, 0.52, 1)
            HookScript(deleteFrame, 'OnEnter', function() deleteFrame.icon:SetVertexColor(1, 0.35, 0.35, 1) end)
            HookScript(deleteFrame, 'OnLeave', function() deleteFrame.icon:SetVertexColor(0.55, 0.5, 0.52, 1) end)
            return { deleteButton, applyButton, snapshotDropdown }
        end,
    })
    snapshotGrid:Flush()

    Layout.Section(tab, 'Share')
    local shareGrid = PageKit.RowGrid(tab)

    shareGrid:Add({
        spanFull = true,
        title = 'Export / Import',
        description = 'Copy your setup as a string to share, or paste one below to import.',
        plain = true,
        accessoryWidth = 220,
        accessories = function(row)
            exportDropdown = Controls.Dropdown(row, nil, ExportItems(), selectedExport, function(value) selectedExport = value end, nil, 200)
            return { exportDropdown }
        end,
    })
    shareGrid:Flush()

    shareBox = Layout.TextArea(tab, nil, 160)
    Layout.ButtonRow(tab, {
        { text = "Export", width = 80, callback = function()
            local exportString, err
            if selectedExport == ALL_LAYOUTS then
                exportString, err = Profiles.ExportCurrent()
            else
                exportString, err = Profiles.ExportLayout(selectedExport)
            end
            if not exportString then
                BUI.Print(err or "Could not export.")
                return
            end
            shareBox.editbox:SetText(exportString)
            shareBox.editbox:SetFocus()
            shareBox.editbox:HighlightText()
        end },
        { text = "Import", width = 80, callback = function()
            local valid, layoutString = Profiles.IsLayoutString(shareBox.editbox:GetText())
            if not valid then
                BUI.Print("Paste a Cooldown Manager layout string first.")
                return
            end
            Modals.Confirm({
                title = "Import Layouts",
                message = "Add the pasted layout(s) next to your current ones, or replace your whole setup with them?\n\nReplacing saves a backup snapshot of your current layouts first.",
                confirmText = "Add to Mine", laterText = "Replace Everything", cancelText = "Cancel",
                onConfirm = function()
                    local ok, result = Profiles.ImportLayoutString(layoutString)
                    if ok then
                        BUI.Print("Added " .. result .. " layout(s) to your Cooldown Manager.")
                        shareBox.editbox:SetText("")
                        RefreshLists()
                        Modals.Confirm({
                            title = "Layouts Added",
                            message = "Layouts imported. Reload so everything picks them up?",
                            confirmText = "Reload Now", cancelText = "Later",
                            onConfirm = function() BUI.Reload() end,
                        })
                    else
                        BUI.Print(result or "Import failed.")
                    end
                end,
                onLater = function()
                    local backed, backupName = Profiles.AutoBackupSnapshot()
                    local ok, err = Profiles.ApplyLayoutData(layoutString)
                    if ok then
                        shareBox.editbox:SetText("")
                        RefreshLists()
                        Modals.Confirm({
                            title = "Setup Replaced",
                            message = backed and ("Done. Your previous layouts were saved as '" .. backupName .. "'.\n\nReload now to finish?") or "Done. Reload now to finish?",
                            confirmText = "Reload Now", cancelText = "Later",
                            onConfirm = function() BUI.Reload() end,
                        })
                    else
                        BUI.Print(err or "Could not apply that string.")
                    end
                end,
            })
        end },
        { text = "Clear", width = 60, callback = function() shareBox.editbox:SetText("") end },
    })

    HookScript(tab.frame, "OnShow", RefreshLists)
    RefreshLists()
end

BUI.PageEngine.RegisterPage("cdm", {
    title = "Cooldown Manager",
    buttonText = "CDM",
    OnBuild = function(pageFrame)
        local db = BUI.GetDB()
        local CDM = BUI.CDM

        if not BUI.IsModuleEnabled('cdm') then
            local page = Layout.Page(pageFrame, nil)
            Layout.Section(page:GetTab(1), "Cooldown Manager",
                "Module disabled. Enable it under Settings > Modules, then reload.")
            page:AutoRefresh()
            return
        end

        CDM.Initialize()

        local page = Layout.Page(pageFrame, { "General", "Essential", "Utility", "Buffs", "Buff Bars", "Layouts", "Icon Management" })
        pageFrame._page = page

        wipe(cdmHeaders)
        wipe(cdmGrids)
        HookCDMRefreshers(CDM)

        local mark = pageFrame:CreateTexture(nil, 'BACKGROUND', nil, 1)
        mark:SetTexture(BUI.Tools.GetLogo())
        mark:SetSize(520, 520)
        mark:SetPoint('CENTER')
        mark:SetVertexColor(1, 1, 1, 0.06)

        InstallCDMHeader(page, 1, {
            title = 'Cooldown Manager',
            desc = "Skin, arrange and extend Blizzard's Cooldown Manager.",
        })
        InstallCDMHeader(page, 6, {
            title = 'Layouts',
            desc = 'Save, restore and share your Cooldown Manager setup.',
        })
        InstallCDMHeader(page, 7, {
            title = 'Icon Management',
            desc = 'Choose which spells appear in each viewer, and where.',
        })

        local VIEWER_HEADERS = {
            { index = 2, key = 'essential', title = 'Essential Viewer', desc = "Blizzard's Essential viewer, reskinned.", keybinds = true },
            { index = 3, key = 'utility',   title = 'Utility Viewer',   desc = 'Utility and defensive cooldowns from the Utility viewer.', keybinds = true },
            { index = 4, key = 'buffs',     title = 'Buff Icons',       desc = 'Tracked buff icons from the Buff viewer.' },
        }
        for _, viewerDef in ipairs(VIEWER_HEADERS) do
            local viewerSettings = db.cdm[viewerDef.key]
            local header
            local headerConfig = {
                title = viewerDef.title, desc = viewerDef.desc, preview = true,
                enable = { value = viewerSettings.enabled, tooltip = 'Enable or disable this viewer skin', onToggle = function(enabled)
                    local gridController = cdmGrids[viewerDef.key]
                    gridController:SyncDim(enabled)
                    Modals.Confirm({
                        parent = BUI.PageEngine.window.frame,
                        title = (enabled and 'Enable ' or 'Disable ') .. viewerDef.title,
                        message = 'This change requires a UI reload to take effect.',
                        confirmText = 'Reload Now', cancelText = 'Cancel',
                        laterText = 'Later',
                        onConfirm = function() viewerSettings.enabled = enabled; BUI.Reload() end,
                        onLater = function() viewerSettings.enabled = enabled end,
                        onCancel = function()
                            header.titleBar.enableToggle:SetValue(not enabled)
                            gridController:SyncDim(not enabled)
                        end,
                    })
                end },
            }
            if viewerDef.key == 'buffs' then
                local function EyeValue()
                    return CDM.state.buffsPreview and CDM.state.buffsPreview:IsShown() or false
                end
                headerConfig.anchor = { value = EyeValue(), tooltip = 'Show a movable preview of the buff icons', onToggle = function()
                    if EyeValue() then
                        CDM.HideBuffsPreview()
                    else
                        CDM.ShowBuffsPreview(viewerSettings)
                    end
                    header.titleBar.anchorToggle:SetValue(EyeValue())
                end }
            end
            header = InstallCDMHeader(page, viewerDef.index, headerConfig)
            if viewerDef.key == 'buffs' then
                CDM.state.buffsPreviewButton = { SetText = function(_, text)
                    header.titleBar.anchorToggle:SetValue(text == 'Hide Preview')
                end }
            end
            local mock = CreateViewerMock(header.stage, viewerDef.keybinds)
            header.Update = function() mock:Render(viewerDef.key) end
            local viewerTab = page:GetTab(viewerDef.index)
            HookScript(viewerTab.frame, 'OnShow', function()
                header.titleBar.enableToggle:SetValue(db.cdm[viewerDef.key].enabled)
                if viewerDef.key == 'buffs' then
                    header.titleBar.anchorToggle:SetValue(CDM.state.buffsPreview and CDM.state.buffsPreview:IsShown() or false)
                end
                header.Update()
            end)
            header.Update()
        end

        do
            local config = db.cdm.buffBars
            local header
            local function BarEye()
                return CDM.IsBuffBarPreviewShown() or false
            end
            header = InstallCDMHeader(page, 5, {
                title = 'Buff Bars',
                desc = "Blizzard's buff bar viewer, reskinned as compact bars.",
                preview = true,
                enable = { value = config.skinEnabled, tooltip = 'Skin the Blizzard buff bars', onToggle = function(enabled)
                    config.skinEnabled = enabled
                    CDM.RefreshBuffBarSkin()
                    cdmGrids.buffBars:SyncDim(enabled)
                end },
                anchor = { value = BarEye(), tooltip = 'Show a preview of the buff bars', onToggle = function()
                    if BarEye() then
                        CDM.HideBuffBarPreview()
                    else
                        CDM.ShowBuffBarPreview()
                    end
                    header.titleBar.anchorToggle:SetValue(BarEye())
                end },
            })
            local mock = CreateBuffBarMock(header.stage)
            header.Update = function() mock:Render() end
            local buffBarsTab = page:GetTab(5)
            HookScript(buffBarsTab.frame, 'OnShow', function()
                header.titleBar.enableToggle:SetValue(db.cdm.buffBars.skinEnabled)
                header.titleBar.anchorToggle:SetValue(BarEye())
                header.Update()
            end)
            header.Update()
        end

        if GetCVar('cooldownViewerEnabled') ~= '1' then
            Modals.Confirm({
                parent = BUI.PageEngine.window.frame,
                title = 'Cooldown Manager Disabled',
                message = 'Blizzard\'s Cooldown Manager is turned off.\n\nBluUI\'s CDM requires it. Enable and reload?',
                confirmText = 'Enable & Reload', cancelText = 'Close',
                laterText = 'Enable Later',
                onConfirm = function() SetCVar('cooldownViewerEnabled', '1'); BUI.Reload() end,
                onLater = function() SetCVar('cooldownViewerEnabled', '1') end,
            })
        end

        BuildGeneralTab(page:GetTab(1), db, CDM)
        BuildViewerSettings(page:GetTab(2), "essential", db, CDM)
        BuildViewerSettings(page:GetTab(3), "utility", db, CDM)
        BuildViewerSettings(page:GetTab(4), "buffs", db, CDM)
        BuildBuffBarsTab(page:GetTab(5), db, CDM)

        BuildLayoutsTab(page:GetTab(6), CDM)
        BUI.BuildCDMIconManagementTab(page:GetTab(7), db)

        page:AutoRefresh()
    end,
    OnHide = function()
        local CDM = BUI.CDM
        if CDM.state.buffsPreview and CDM.state.buffsPreview:IsShown() then
            CDM.HideBuffsPreview()
        end
        if CDM.glowPreview and CDM.glowPreview:IsShown() then
            CDM.HideGlowPreview()
        end
        if CDM.IsBuffBarPreviewShown() then
            CDM.HideBuffBarPreview()
        end
    end,
})

local function RefreshCDMPageIfOpen()
    if BUI.PageEngine.GetCurrentPage() ~= "cdm" then return end
    local CDM = BUI.CDM
    if CDM._emStatusRefresh then CDM._emStatusRefresh() end
    if not CDM._iconListRefreshers then return end
    for _, callback in pairs(CDM._iconListRefreshers) do callback() end
end

BUI.Events:Register("PLAYER_SPECIALIZATION_CHANGED", "CDMPage", function(_, unit)
    if unit ~= "player" then return end
    BUI.Prof.After('Pages.CDM', 0.3, RefreshCDMPageIfOpen)
end)

BUI.Events:Register("TRAIT_CONFIG_UPDATED", "CDMPage", function()
    BUI.Prof.After('Pages.CDM', 0.3, RefreshCDMPageIfOpen)
end)

BUI.Events:Register("COOLDOWN_VIEWER_DATA_LOADED", "CDMPage", function()
    BUI.Prof.After('Pages.CDM', 0.3, RefreshCDMPageIfOpen)
end)

BUI.Events:Register("EDIT_MODE_LAYOUTS_UPDATED", "CDMPage", function()
    RefreshCDMPageIfOpen()
end)
