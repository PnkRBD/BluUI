local _, BUI = ...

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Widget = BUILib.Widget
local Controls = BUILib.Controls
local Colors = BUILib.Colors
local FONT = BUILib.Font or STANDARD_TEXT_FONT
local Skin = BUI.Skinning
local IsSecretValue = BUI.Tools.IsSecretValue
local Pixel = BUI.Pixel

local function HasConflictingCharSheet()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return (loaded and loaded('ChonkyCharacterSheet')) and true or false
end

local FRAME_LEVEL   = 100
local SLOT_SIZE     = 40
local SLOT_GAP      = 6
local LABEL_ZONE_W  = 96
local MODEL_HEIGHT  = 384
local MODEL_WIDTH   = 275
local STATS_W       = 264
local STATS_GAP     = 14
local TOP_Y         = -60
local BOTTOM_PAD    = 12
local HEADER = { BAR_H = 48, TOP_PAD = 12, SUBTITLE_GAP = 4 }

local LEFT_X  = 16
local MODEL_X = LEFT_X + SLOT_SIZE + LABEL_ZONE_W
local RIGHT_X = MODEL_X + MODEL_WIDTH + LABEL_ZONE_W
local STATS_X = RIGHT_X + SLOT_SIZE + STATS_GAP
local FRAME_WIDTH  = STATS_X + STATS_W + LEFT_X
local FRAME_HEIGHT = -(TOP_Y + 6) + MODEL_HEIGHT + 6 + SLOT_SIZE + BOTTOM_PAD + 4

local ILVL_SIZE     = 11
local TRACK_SIZE    = 10
local ENCHANT_SIZE  = 9
local HEADER_SIZE   = 11
local ROW_SIZE      = 11
local BIG_ILVL_SIZE, BIG_ILVL_DROP = 34, 4
local STACK_RIGHT_PAD = 14
local INFO_SIZE     = 11
local TAB_SIZE      = 10
local LIST_SIZE     = 10

local TAB_ROW_HEIGHT = 25
local ROW_HEIGHT     = 16
local RATING_COL_W   = 30
local COLUMN_GAP     = 3
local HEADER_HEIGHT  = 16
local SECTION_GAP    = 8
local HEADER_ROW_GAP = 6
local LIST_ROW_H     = 22
local LIST_ROW_GAP   = 2
local SIDEBAR_INSET  = 8
local SCROLLBAR_W    = 18
local LIST_RIGHT_PAD = 12

local GEM_SIZE  = 14
local GEM_PAD   = 1
local LABEL_GAP_X    = 5
local GEM_INSET, ENCHANT_NAME_W = 2, LABEL_ZONE_W - LABEL_GAP_X - 8
local LABEL_LINE_Y   = 13

local IDLE_BORDER   = { 0.4, 0.4, 0.4 }
local SLOT_BG       = { 0.05, 0.05, 0.06, 1 }
local TOGGLE_BORDER = { 0.2, 0.2, 0.22, 1 }
local ART = {
    BLEED = 0,
    SIDE_SHARE = 19 / 275, TOP_SHARE = 256 / 384, SIDE_COORD = 0.296875,
    OVERLAY_ALPHA = { BLOODELF = 0.8, NIGHTELF = 0.6, SCOURGE = 0.3, TROLL = 0.6, ORC = 0.6, WORGEN = 0.5, GOBLIN = 0.6 },
    OVERLAY_DEFAULT = 0.7,
    MODEL_EDGE = { 1, 1, 1, 0.12 },
}
local SIDEBAR_BG    = { 0, 0, 0, 0 }
local BIG_ILVL_COLOR = { 0.6, 0.2, 1 }
local INFO_COLOR    = { 0.8, 0.8, 0.8 }
local LABEL_COLOR   = { 0.8, 0.8, 0.8 }
local VALUE_COLOR   = { 1, 1, 1 }
local SEPARATOR_COLOR = { 0.54, 0.56, 0.6 }
local MISSING_COLOR = { 0.898, 0.286, 0.286 }
local GEM_BORDER_RARE   = { 1, 0.82, 0 }
local GEM_BORDER_COMMON = { 0.75, 0.75, 0.75 }
local LIST_ROW_BG   = { 1, 1, 1, 0.04 }
local LIST_ROW_HOVER = { 1, 1, 1, 0.1 }
local SEARCH_BG     = { 0, 0, 0, 0.5 }

local SECTION_COLORS = {
    Attributes = { 0.55, 0.85, 0.55 },
    Secondary  = { 0.45, 0.72, 1 },
    Tertiary   = { 1, 0.72, 0.3 },
    Attack     = { 1, 0.45, 0.4 },
    Defense    = { 0.7, 0.55, 1 },
    PvP        = { 0.95, 0.6, 0.8 },
}

local TRACK_COLORS = {
    explorer   = { 0.62, 0.62, 0.62 },
    adventurer = { 1, 1, 1 },
    veteran    = { 0.12, 1, 0 },
    champion   = { 0, 0.44, 0.87 },
    hero       = { 0.64, 0.21, 0.93 },
    myth       = { 1, 0.5, 0 },
}

local SLOTS = {
    { id = 'HeadSlot',          col = 'left',   row = 1, enchant = true },
    { id = 'NeckSlot',          col = 'left',   row = 2 },
    { id = 'ShoulderSlot',      col = 'left',   row = 3, enchant = true },
    { id = 'BackSlot',          col = 'left',   row = 4 },
    { id = 'ChestSlot',         col = 'left',   row = 5, enchant = true },
    { id = 'ShirtSlot',         col = 'left',   row = 6, cosmetic = true },
    { id = 'TabardSlot',        col = 'left',   row = 7, cosmetic = true },
    { id = 'WristSlot',         col = 'left',   row = 8 },
    { id = 'HandsSlot',         col = 'right',  row = 1 },
    { id = 'WaistSlot',         col = 'right',  row = 2 },
    { id = 'LegsSlot',          col = 'right',  row = 3, enchant = true },
    { id = 'FeetSlot',          col = 'right',  row = 4, enchant = true },
    { id = 'Finger0Slot',       col = 'right',  row = 5, enchant = true },
    { id = 'Finger1Slot',       col = 'right',  row = 6, enchant = true },
    { id = 'Trinket0Slot',      col = 'right',  row = 7 },
    { id = 'Trinket1Slot',      col = 'right',  row = 8 },
    { id = 'MainHandSlot',      col = 'bottom', row = 1, enchant = true },
    { id = 'SecondaryHandSlot', col = 'bottom', row = 2, enchant = 'weapon' },
}

local EQUIPMENT_SLOT_NAMES = {
    'Head', 'Neck', 'Shoulder', 'Shirt', 'Chest', 'Waist', 'Legs', 'Feet', 'Wrist', 'Hands',
    'Finger 1', 'Finger 2', 'Trinket 1', 'Trinket 2', 'Back', 'Main Hand', 'Off Hand', 'Ranged', 'Tabard',
}

local EMPTY_SOCKET_ATLAS = {
    EMPTY_SOCKET_META       = 'socket-meta',
    EMPTY_SOCKET_RED        = 'socket-red',
    EMPTY_SOCKET_YELLOW     = 'socket-yellow',
    EMPTY_SOCKET_BLUE       = 'socket-blue',
    EMPTY_SOCKET_PRISMATIC  = 'socket-prismatic',
    EMPTY_SOCKET_TINKER     = 'socket-tinker',
    EMPTY_SOCKET_PRIMORDIAL = 'socket-primordial',
    EMPTY_SOCKET_DOMINATION = 'socket-domination',
    EMPTY_SOCKET_CYPHER     = 'socket-cypher',
    EMPTY_SOCKET_HYDRAULIC  = 'socket-hydraulic',
    EMPTY_SOCKET_COGWHEEL   = 'socket-cogwheel',
}

local MP_COLOR_BRACKETS = {
    { 3850, 'ff8000' }, { 3695, 'f9753f' }, { 3575, 'f16961' }, { 3455, 'e75e7f' }, { 3335, 'db529c' },
    { 3215, 'cc47b9' }, { 3095, 'b83dd6' }, { 2965, '9c3eed' }, { 2845, '715be5' }, { 2725, '2c6dde' },
    { 2565, '3b7fcd' }, { 2445, '5292b9' }, { 2325, '5ca6a4' }, { 2205, '5fba8d' }, { 2085, '5cce75' },
    { 1965, '50e258' }, { 1845, '35f72d' }, { 1725, '3eff26' }, { 1600, '5eff43' }, { 1475, '74ff58' },
    { 1350, '88ff6b' }, { 1225, '98ff7d' }, { 1100, 'a8ff8d' }, { 975, 'b6ff9e' },  { 850, 'c3ffae' },
    { 725, 'cfffbd' },  { 600, 'dbffcd' },  { 475, 'e7ffdd' },  { 350, 'f2ffec' },  { 225, 'fdfffc' },
}

local NO_TITLE = -1
local CONQUEST_CURRENCY, QUESTION_MARK_ICON = 1602, 134400

local frame, model, sidebar, overlay
local slots = {}
local slotLabels = {}
local sections = {}

function Skin.GetCharacterFrame()
    return frame
end

local ENCHANT_LINE_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent or 15

local function EscapePattern(text)
    return (text:gsub('([%(%)%.%[%]%^%$%*%+%-%?%%])', '%%%1'))
end

local function PatternFromFormat(format)
    if not format then return nil end
    local head, tail = format:match('^(.-)%%s(.*)$')
    if not head then return nil end
    return '^' .. EscapePattern(head) .. '(.+)' .. EscapePattern(tail) .. '$'
end

local ENCHANT_PATTERN = PatternFromFormat(ENCHANTED_TOOLTIP_LINE)
local UPGRADE_PATTERN
if ITEM_UPGRADE_TOOLTIP_FORMAT then
    local escaped = EscapePattern(ITEM_UPGRADE_TOOLTIP_FORMAT)
    escaped = escaped:gsub('%%%%s', '(.-)'):gsub('%%%%d', '(%%d+)')
    UPGRADE_PATTERN = '^' .. escaped .. '$'
end

local function TooltipLines(inventorySlot)
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return nil end
    local data = C_TooltipInfo.GetInventoryItem('player', inventorySlot)
    if not data then return nil end
    if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(data) end
    return data.lines
end

local function StripColors(text)
    if not text then return '' end
    text = text:gsub('|cn.-:(.-)|r', '%1')
    text = text:gsub('|c%x%x%x%x%x%x%x%x', '')
    text = text:gsub('|r', '')
    text = text:gsub('^%s*[%+&]%s*', '')
    return text
end

local enchantCache = {}

local function ReadEnchant(inventorySlot, link)
    local enchantID = tonumber(link:match('item:%d+:(%d+)'))
    if not enchantID or enchantID == 0 then return '' end
    local cached = enchantCache[enchantID]
    if cached then return cached end

    local lines = TooltipLines(inventorySlot)
    if not lines then return '' end
    for _, line in ipairs(lines) do
        local raw = StripColors(line.leftText)
        local matched
        if line.type == ENCHANT_LINE_TYPE then
            matched = (ENCHANT_PATTERN and raw:match(ENCHANT_PATTERN)) or raw
        elseif ENCHANT_PATTERN then
            matched = raw:match(ENCHANT_PATTERN)
        end
        if matched and matched ~= '' then
            matched = matched:gsub('^Enchanted:%s*', '')
            matched = matched:gsub('^Enchant%s+[^%-]+%s*%-%s*', '')
            enchantCache[enchantID] = matched
            return matched
        end
    end
    return ''
end

local function ParseUpgradeLine(raw)
    if UPGRADE_PATTERN then
        local track, current, maximum = raw:match(UPGRADE_PATTERN)
        if track then return track, current, maximum end
    end
    local track, current, maximum = raw:match('(%a+)%s+(%d+)%s*/%s*(%d+)%s*$')
    if track and TRACK_COLORS[track:lower()] then return track, current, maximum end
    return nil
end

local function ReadUpgradeTrack(inventorySlot)
    local lines = TooltipLines(inventorySlot)
    if not lines then return nil end
    for _, line in ipairs(lines) do
        local raw = StripColors(line.leftText)
        local track, current, maximum = ParseUpgradeLine(raw)
        if track then
            local key = track:lower():match('^(%a+)')
            return track .. ' ' .. current .. '/' .. maximum, TRACK_COLORS[key]
        end
    end
    return nil
end

local function ReadItemLevel(inventorySlot, link)
    if ItemLocation and C_Item.GetCurrentItemLevel then
        local location = ItemLocation:CreateFromEquipmentSlot(inventorySlot)
        if location and location:IsValid() and C_Item.DoesItemExist(location) then
            local level = C_Item.GetCurrentItemLevel(location)
            if level and level > 0 then return level end
        end
    end
    return C_Item.GetDetailedItemLevelInfo(link) or 0
end

local function ReadSockets(link)
    local entries, gemLinks = {}, {}
    if not link or not C_Item.GetItemGem or not C_Item.GetItemStats then return entries, gemLinks end

    for gemIndex = 1, 4 do
        local _, gemLink = C_Item.GetItemGem(link, gemIndex)
        if gemLink then
            gemLinks[#gemLinks + 1] = gemLink
            local icon = C_Item.GetItemIconByID(gemLink) or (GetItemInfoInstant and select(5, GetItemInfoInstant(gemLink)))
            entries[#entries + 1] = { icon = icon or QUESTION_MARK_ICON }
        end
    end

    local stats = C_Item.GetItemStats(link)
    if stats then
        local total, firstAtlas = 0, nil
        for key, count in pairs(stats) do
            local atlas = EMPTY_SOCKET_ATLAS[key]
            if atlas and count and count > 0 then
                total = total + count
                firstAtlas = firstAtlas or atlas
            end
        end
        for _ = 1, math.max(0, total - #gemLinks) do
            entries[#entries + 1] = { atlas = firstAtlas }
        end
    end
    return entries, gemLinks
end

local function QualityColor(link)
    local quality = link and C_Item.GetItemQualityByID(link)
    if quality and quality > 1 then
        local red, green, blue = C_Item.GetItemQualityColor(quality)
        return { red, green, blue }
    end
    return nil
end

local function AtEnchantLevel()
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 90
    local level = UnitLevel('player')
    if not level or IsSecretValue(level) then return false end
    return level >= maxLevel
end

local function CanHaveEnchant(info, link)
    if info.enchant == 'weapon' then
        if not link then return false end
        local _, _, _, _, _, classID = GetItemInfoInstant(link)
        return classID == Enum.ItemClass.Weapon
    end
    return info.enchant == true
end

local function SlotAnchor(info)
    if info.col == 'left' then
        return LEFT_X, TOP_Y - (info.row - 1) * (SLOT_SIZE + SLOT_GAP)
    elseif info.col == 'right' then
        return RIGHT_X, TOP_Y - (info.row - 1) * (SLOT_SIZE + SLOT_GAP)
    end
    local centerX = MODEL_X + MODEL_WIDTH / 2
    local x = centerX - SLOT_SIZE - SLOT_GAP / 2 + (info.row - 1) * (SLOT_SIZE + SLOT_GAP)
    return x, TOP_Y - MODEL_HEIGHT
end

local function SlotSides(info)
    if info.col == 'left' or (info.col == 'bottom' and info.row == 2) then
        return 'RIGHT', 'LEFT'
    end
    return 'LEFT', 'RIGHT'
end

local function PopupSide(info)
    if info.col == 'left' then return 'LEFT', 'RIGHT' end
    if info.col == 'right' then return 'RIGHT', 'LEFT' end
    return SlotSides(info)
end

local CONTEXT_DIM_ALPHA = 0.75

local function HideTexture(texture)
    if not texture or texture._buiHidden then return end
    texture._buiHidden = true
    texture:SetTexture('')
    texture:SetVertexColor(1, 1, 1, 0)
    texture:SetAlpha(0)
    texture:Hide()
    texture.Show = texture.Hide
    texture.SetShown = function(self, shown) if not shown then self:Hide() end end
    texture.SetAtlas = function(self) self:Hide() end
    texture.SetTexture = function(self) self:Hide() end
    texture.SetAlpha = function() end
end

local function HideBlizzardDecorations(button)
    local name = button:GetName()
    local icon = button.icon or (name and _G[name .. 'IconTexture'])
    local contextOverlay = button.ItemContextOverlay
    if contextOverlay and not contextOverlay._buiContext then
        contextOverlay._buiContext = true
        contextOverlay:ClearAllPoints()
        contextOverlay:SetPoint('TOPLEFT', 1, -1)
        contextOverlay:SetPoint('BOTTOMRIGHT', -1, 1)
        contextOverlay:SetColorTexture(0, 0, 0, CONTEXT_DIM_ALPHA)
    end
    for regionIndex = 1, button:GetNumRegions() do
        local region = select(regionIndex, button:GetRegions())
        if region and region ~= icon and region ~= contextOverlay and not region._buiOurs and region:GetObjectType() == 'Texture' then
            HideTexture(region)
        end
    end
    for _, child in ipairs({ button:GetChildren() }) do
        if child ~= button.Cooldown then
            child:Hide()
            child.Show = child.Hide
        end
    end
    if button.NineSlice then
        button.NineSlice:Hide()
        button.NineSlice.Show = button.NineSlice.Hide
    end
end

local function ApplyQualityBorder(button, link)
    local color = QualityColor(link)
    button._buiQualityColor = color
    if color then
        button:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    else
        button:SetBackdropBorderColor(IDLE_BORDER[1], IDLE_BORDER[2], IDLE_BORDER[3], 1)
    end
end

local function StyleSlotButton(button)
    if button._buiStyled then return end
    button._buiStyled = true

    button.backgroundTextureName = nil
    if not button.SetBackdrop then Mixin(button, BackdropTemplateMixin) end

    local existing = {}
    for regionIndex = 1, button:GetNumRegions() do existing[select(regionIndex, button:GetRegions())] = true end

    button:SetBackdrop({
        bgFile   = 'Interface\\Buttons\\WHITE8x8',
        edgeFile = 'Interface\\Buttons\\WHITE8x8',
        edgeSize = 1,
    })
    button:SetBackdropColor(SLOT_BG[1], SLOT_BG[2], SLOT_BG[3], 1)
    button:SetBackdropBorderColor(IDLE_BORDER[1], IDLE_BORDER[2], IDLE_BORDER[3], 1)

    for regionIndex = 1, button:GetNumRegions() do
        local region = select(regionIndex, button:GetRegions())
        if region and not existing[region] then region._buiOurs = true end
    end

    HideBlizzardDecorations(button)

    local name = button:GetName()
    local icon = button.icon or (name and _G[name .. 'IconTexture'])
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint('TOPLEFT', 1, -1)
        icon:SetPoint('BOTTOMRIGHT', -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    button:HookScript('OnEnter', function(self)
        self:SetBackdropBorderColor(Colors.GetAccent())
    end)
    button:HookScript('OnLeave', function(self)
        local color = self._buiQualityColor
        if color then
            self:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        else
            self:SetBackdropBorderColor(IDLE_BORDER[1], IDLE_BORDER[2], IDLE_BORDER[3], 1)
        end
    end)
end

local function CreateGemFrame(button)
    local gem = CreateFrame('Frame', nil, overlay, 'BackdropTemplate')
    gem:SetSize(Pixel.Scale(GEM_SIZE), Pixel.Scale(GEM_SIZE))
    gem:SetFrameLevel(button:GetFrameLevel() + 6)
    gem:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8x8', edgeFile = 'Interface\\Buttons\\WHITE8x8', edgeSize = 1 })
    gem:SetBackdropColor(0, 0, 0, 1)
    gem.icon = gem:CreateTexture(nil, 'ARTWORK')
    gem.icon:SetPoint('TOPLEFT', 1, -1)
    gem.icon:SetPoint('BOTTOMRIGHT', -1, 1)
    gem:EnableMouse(true)
    gem:SetScript('OnEnter', function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    gem:SetScript('OnLeave', function() GameTooltip:Hide() end)
    gem:Hide()
    return gem
end

local BAG = { ARROW_SIZE = GEM_SIZE, COLS = 5, CELL = 40, GAP = 4, PAD = 8, POPUP_TOP = 24, POPUP_MAX = 15, POPUP_LINGER = 0.35 }
BAG.POPUP_W = BAG.PAD * 2 + BAG.COLS * BAG.CELL + (BAG.COLS - 1) * BAG.GAP
function BAG.Colors()
    local skinning = BUI.GetDB().skinning
    local arrow = skinning.characterFrameArrow
    if not arrow then
        local red, green, blue = Colors.GetAccent()
        arrow = { red, green, blue, 1 }
    end
    return arrow,
        skinning.characterFrameArrowEmpty or { 0.45, 0.45, 0.48, 1 },
        skinning.characterFrameArrowPlate or { 1, 1, 1, 0.85 }
end

local EQUIP_LOC_SLOTS = {
    INVTYPE_HEAD = { 'HeadSlot' },           INVTYPE_NECK = { 'NeckSlot' },
    INVTYPE_SHOULDER = { 'ShoulderSlot' },   INVTYPE_CLOAK = { 'BackSlot' },
    INVTYPE_CHEST = { 'ChestSlot' },         INVTYPE_ROBE = { 'ChestSlot' },
    INVTYPE_BODY = { 'ShirtSlot' },          INVTYPE_TABARD = { 'TabardSlot' },
    INVTYPE_WRIST = { 'WristSlot' },         INVTYPE_HAND = { 'HandsSlot' },
    INVTYPE_WAIST = { 'WaistSlot' },         INVTYPE_LEGS = { 'LegsSlot' },
    INVTYPE_FEET = { 'FeetSlot' },
    INVTYPE_FINGER = { 'Finger0Slot', 'Finger1Slot' },
    INVTYPE_TRINKET = { 'Trinket0Slot', 'Trinket1Slot' },
    INVTYPE_WEAPON = { 'MainHandSlot', 'SecondaryHandSlot' },
    INVTYPE_2HWEAPON = { 'MainHandSlot' },   INVTYPE_WEAPONMAINHAND = { 'MainHandSlot' },
    INVTYPE_WEAPONOFFHAND = { 'SecondaryHandSlot' }, INVTYPE_HOLDABLE = { 'SecondaryHandSlot' },
    INVTYPE_SHIELD = { 'SecondaryHandSlot' },
    INVTYPE_RANGED = { 'MainHandSlot' },     INVTYPE_RANGEDRIGHT = { 'MainHandSlot' },
}

local bagItemsBySlot = {}
local bagPopup

local function ScanBagsManually()
    if not C_Container then return end
    for bag = BACKPACK_CONTAINER or 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and info.hyperlink
            if link and info.itemID then
                local _, _, _, equipLoc, icon = GetItemInfoInstant(info.itemID)
                local targets = EQUIP_LOC_SLOTS[equipLoc]
                if targets then
                    local level = 0
                    local location = ItemLocation and ItemLocation:CreateFromBagAndSlot(bag, slot)
                    if location and location:IsValid() and C_Item.DoesItemExist(location) then
                        level = C_Item.GetCurrentItemLevel(location) or 0
                    end
                    local entry = {
                        bag = bag, slot = slot, link = link, level = level,
                        icon = info.iconFileID or icon, quality = info.quality or 1,
                        name = link:match('%[(.-)%]') or '?',
                    }
                    for _, slotName in ipairs(targets) do
                        bagItemsBySlot[slotName] = bagItemsBySlot[slotName] or {}
                        table.insert(bagItemsBySlot[slotName], entry)
                    end
                end
            end
        end
    end
    for _, list in pairs(bagItemsBySlot) do
        table.sort(list, function(left, right)
            if left.level ~= right.level then return left.level > right.level end
            return left.name < right.name
        end)
    end
end

local flyoutScratch = {}

local function ScanBags()
    wipe(bagItemsBySlot)
    if not (GetInventoryItemsForSlot and EquipmentManager_UnpackLocation) then
        ScanBagsManually()
        return
    end
    for _, labels in pairs(slotLabels) do
        local slotName = labels.info.id
        local slotID = GetInventorySlotInfo(slotName)
        wipe(flyoutScratch)
        GetInventoryItemsForSlot(slotID, flyoutScratch)
        local list = {}
        for location, itemID in pairs(flyoutScratch) do
            local _, _, inBags, inVoid, slot, bag = EquipmentManager_UnpackLocation(location)
            local link = inBags and not inVoid and bag and slot and C_Container.GetContainerItemLink(bag, slot)
            if link then
                local level = 0
                local itemLocation = ItemLocation and ItemLocation:CreateFromBagAndSlot(bag, slot)
                if itemLocation and itemLocation:IsValid() and C_Item.DoesItemExist(itemLocation) then
                    level = C_Item.GetCurrentItemLevel(itemLocation) or 0
                end
                list[#list + 1] = {
                    location = location, slotID = slotID, bag = bag, slot = slot, link = link, level = level,
                    icon = select(5, GetItemInfoInstant(itemID)), quality = C_Item.GetItemQualityByID(link) or 1,
                    name = link:match('%[(.-)%]') or '?',
                }
            end
        end
        table.sort(list, function(left, right)
            if left.level ~= right.level then return left.level > right.level end
            return left.name < right.name
        end)
        bagItemsBySlot[slotName] = list
    end
end

local function EquipBagItem(entry, slotName)
    if InCombatLockdown() then
        BUI.Print('Gear cannot change during combat.')
        return
    end
    if entry.location and EquipmentManager_EquipItemByLocation then
        EquipmentManager_EquipItemByLocation(entry.location, entry.slotID or GetInventorySlotInfo(slotName))
    else
        ClearCursor()
        C_Container.PickupContainerItem(entry.bag, entry.slot)
        EquipCursorItem(GetInventorySlotInfo(slotName))
        ClearCursor()
    end
    if bagPopup then bagPopup:Hide() end
end

local function EnsureBagPopup()
    if bagPopup then return bagPopup end
    bagPopup = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
    bagPopup:SetFrameStrata('DIALOG')
    bagPopup:SetClampedToScreen(true)
    bagPopup:EnableMouse(true)
    bagPopup:SetWidth(Pixel.Scale(BAG.POPUP_W))
    bagPopup:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8x8', edgeFile = 'Interface\\Buttons\\WHITE8x8', edgeSize = 1 })
    bagPopup:SetBackdropColor(0.04, 0.04, 0.05, 0.98)
    bagPopup:SetBackdropBorderColor(TOGGLE_BORDER[1], TOGGLE_BORDER[2], TOGGLE_BORDER[3], 1)
    bagPopup.title = bagPopup:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(bagPopup.title, LIST_SIZE, FONT, '')
    bagPopup.title:SetPoint('TOPLEFT', Pixel.Scale(8), Pixel.Scale(-6))
    bagPopup.title:SetTextColor(LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3], 1)
    bagPopup.rows = {}
    bagPopup:SetScript('OnUpdate', function(self, elapsed)
        if self:IsMouseOver() or (self.owner and self.owner:IsMouseOver()) then
            self.away = 0
            return
        end
        self.away = (self.away or 0) + elapsed
        if self.away > BAG.POPUP_LINGER then self:Hide() end
    end)
    bagPopup:Hide()
    return bagPopup
end

local function BagPopupCell(index)
    local cell = bagPopup.rows[index]
    if cell then return cell end
    cell = CreateFrame('Button', nil, bagPopup, 'BackdropTemplate')
    cell:SetSize(Pixel.Scale(BAG.CELL), Pixel.Scale(BAG.CELL))
    local column = (index - 1) % BAG.COLS
    local rowIndex = math.floor((index - 1) / BAG.COLS)
    cell:SetPoint('TOPLEFT', bagPopup, 'TOPLEFT',
        Pixel.Scale(BAG.PAD + column * (BAG.CELL + BAG.GAP)),
        -Pixel.Scale(BAG.POPUP_TOP + rowIndex * (BAG.CELL + BAG.GAP)))
    Skin.ApplyBackdrop(cell, SLOT_BG, TOGGLE_BORDER)
    cell.icon = cell:CreateTexture(nil, 'ARTWORK')
    cell.icon:SetPoint('TOPLEFT', 1, -1)
    cell.icon:SetPoint('BOTTOMRIGHT', -1, 1)
    cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell.hover = cell:CreateTexture(nil, 'OVERLAY')
    cell.hover:SetAllPoints()
    cell.hover:SetColorTexture(1, 1, 1, 0.15)
    cell.hover:Hide()
    cell.level = cell:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(cell.level, LIST_SIZE, FONT, 'OUTLINE')
    cell.level:SetPoint('BOTTOMRIGHT', Pixel.Scale(-3), Pixel.Scale(2))
    cell.level:SetTextColor(1, 1, 1, 1)
    cell:SetScript('OnEnter', function(self)
        self.hover:Show()
        if not self.entry then return end
        GameTooltip:SetOwner(self, self.tipAnchor or 'ANCHOR_RIGHT')
        GameTooltip:SetHyperlink(self.entry.link)
        GameTooltip:Show()
    end)
    cell:SetScript('OnLeave', function(self) self.hover:Hide(); GameTooltip:Hide() end)
    cell:SetScript('OnClick', function(self) EquipBagItem(self.entry, self.slotName) end)
    bagPopup.rows[index] = cell
    return cell
end

local function ShowBagPopup(labels)
    local list = bagItemsBySlot[labels.info.id]
    if not list or #list == 0 then return end
    local popup = EnsureBagPopup()
    popup.owner = labels.bagArrow
    popup.title:SetText(#list > 0 and ('In bags (%d)'):format(#list) or 'Nothing in bags for this slot')
    local side, opposite = PopupSide(labels.info)
    local popupPixels = popup:GetWidth() * popup:GetEffectiveScale() + Pixel.Scale(4) * popup:GetEffectiveScale()
    local buttonScale = labels.button:GetEffectiveScale()
    local screenPixels = UIParent:GetWidth() * UIParent:GetEffectiveScale()
    if side == 'LEFT' and labels.button:GetLeft() and labels.button:GetLeft() * buttonScale < popupPixels then
        side, opposite = 'RIGHT', 'LEFT'
    elseif side == 'RIGHT' and labels.button:GetRight() and screenPixels - labels.button:GetRight() * buttonScale < popupPixels then
        side, opposite = 'LEFT', 'RIGHT'
    end
    local tipAnchor = side == 'RIGHT' and 'ANCHOR_RIGHT' or 'ANCHOR_LEFT'
    local count = math.min(#list, BAG.POPUP_MAX)
    for index = 1, count do
        local entry, cell = list[index], BagPopupCell(index)
        cell.entry, cell.slotName, cell.tipAnchor = entry, labels.info.id, tipAnchor
        cell.icon:SetTexture(entry.icon)
        local red, green, blue = C_Item.GetItemQualityColor(entry.quality or 1)
        cell:SetBackdropBorderColor(red, green, blue, 1)
        cell.level:SetText(entry.level > 0 and tostring(entry.level) or '')
        cell:Show()
    end
    for index = count + 1, #popup.rows do popup.rows[index]:Hide() end
    local rowCount = math.ceil(count / BAG.COLS)
    local gridHeight = rowCount > 0 and (rowCount * BAG.CELL + (rowCount - 1) * BAG.GAP + BAG.PAD) or BAG.PAD
    popup:SetHeight(Pixel.Scale(BAG.POPUP_TOP + gridHeight))
    local sign = side == 'RIGHT' and 1 or -1
    popup:ClearAllPoints()
    popup:SetPoint('TOP' .. opposite, labels.button, 'TOP' .. side, Pixel.Scale(4 * sign), 0)
    popup.away = 0
    popup:Show()
end

local function ToggleBagPopup(labels)
    if bagPopup and bagPopup:IsShown() and bagPopup.owner == labels.bagArrow then
        bagPopup:Hide()
        return
    end
    ShowBagPopup(labels)
end

local function RefreshBagAlternatives()
    ScanBags()
    local arrowColor, emptyColor, plateColor = BAG.Colors()
    for _, labels in pairs(slotLabels) do
        local list = bagItemsBySlot[labels.info.id]
        local count = list and #list or 0
        labels.bagArrow.count = count
        labels.bagArrow:Show()
        local color = count > 0 and arrowColor or emptyColor
        labels.bagArrow.arrow:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        labels.bagArrow.plate:SetColorTexture(plateColor[1], plateColor[2], plateColor[3], plateColor[4] or 1)
    end
    if bagPopup and bagPopup:IsShown() then bagPopup:Hide() end
end

function Skin.SyncSlotGemDim(labels)
    local contextOverlay = labels.button.ItemContextOverlay
    local alpha = (contextOverlay and contextOverlay:IsShown()) and 0.25 or 1
    for _, gem in ipairs(labels.gems) do gem:SetAlpha(alpha) end
end

local function BuildSlotLabels(button, info)
    local labels = { info = info, button = button, gems = {} }
    local outer, inner = SlotSides(info)
    local sign = outer == 'RIGHT' and 1 or -1

    local gapX = Pixel.Scale(LABEL_GAP_X * sign)
    local lineY = Pixel.Scale(LABEL_LINE_Y)

    labels.ilvl = overlay:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(labels.ilvl, ILVL_SIZE, FONT, '')
    labels.ilvl:SetJustifyH(inner)
    labels.ilvl:SetPoint(inner, button, outer, gapX, lineY)

    labels.track = overlay:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(labels.track, TRACK_SIZE, FONT, '')
    labels.track:SetJustifyH(inner)
    labels.track:SetPoint(inner, button, outer, gapX, 0)

    labels.enchant = overlay:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(labels.enchant, ENCHANT_SIZE, FONT, '')
    labels.enchant:SetJustifyH(inner)
    labels.enchant:SetWordWrap(false)
    labels.enchant:SetWidth(Pixel.Scale(ENCHANT_NAME_W))
    labels.enchant:SetPoint(inner, button, outer, gapX, -lineY)

    labels.enchantHover = CreateFrame('Frame', nil, overlay)
    labels.enchantHover:SetSize(Pixel.Scale(ENCHANT_NAME_W), Pixel.Scale(14))
    labels.enchantHover:SetPoint(inner, button, outer, gapX, -lineY)
    labels.enchantHover:EnableMouse(true)
    labels.enchantHover:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        if self.slot and GetInventoryItemLink('player', self.slot) then
            GameTooltip:SetInventoryItem('player', self.slot)
        elseif self.tooltip and self.tooltip ~= '' then
            GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
        else
            GameTooltip:Hide()
            return
        end
        GameTooltip:Show()
    end)
    labels.enchantHover:SetScript('OnLeave', function() GameTooltip:Hide() end)
    labels.enchantHover:Hide()

    labels.bagArrow = CreateFrame('Button', nil, overlay)
    labels.bagArrow:SetSize(Pixel.Scale(BAG.ARROW_SIZE), Pixel.Scale(BAG.ARROW_SIZE))
    local popupSide = PopupSide(info)
    local popupSign = popupSide == 'RIGHT' and 1 or -1
    labels.bagArrow:SetPoint('TOP' .. popupSide, button, 'TOP' .. popupSide, -popupSign * Pixel.Scale(GEM_INSET), -Pixel.Scale(GEM_INSET))
    labels.bagArrow:SetFrameLevel(button:GetFrameLevel() + 6)
    local arrowBg = labels.bagArrow:CreateTexture(nil, 'BACKGROUND')
    arrowBg:SetAllPoints()
    arrowBg:SetColorTexture(1, 1, 1, 0.85)
    local arrow = labels.bagArrow:CreateTexture(nil, 'OVERLAY')
    arrow:SetPoint('TOPLEFT', 1, -1)
    arrow:SetPoint('BOTTOMRIGHT', -1, 1)
    arrow:SetTexture(BUILib.GetLibMedia('dropdown'))
    arrow:SetRotation(popupSign * math.pi / 2)
    local accentRed, accentGreen, accentBlue = Colors.GetAccent()
    arrow:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
    labels.bagArrow.arrow = arrow
    labels.bagArrow.plate = arrowBg
    labels.bagArrow:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, popupSide == 'RIGHT' and 'ANCHOR_RIGHT' or 'ANCHOR_LEFT')
        GameTooltip:SetText((self.count or 0) > 0 and string.format('%d in bags for this slot', self.count) or 'Nothing in bags for this slot', 1, 1, 1)
        if (self.count or 0) > 0 then GameTooltip:AddLine('Click to pick one to equip.', 0.7, 0.7, 0.7) end
        GameTooltip:Show()
    end)
    labels.bagArrow:SetScript('OnLeave', function() GameTooltip:Hide() end)
    labels.bagArrow:SetScript('OnClick', function() ToggleBagPopup(labels) end)
    labels.bagArrow:Hide()

    local contextOverlay = button.ItemContextOverlay
    if contextOverlay then
        local function Sync() Skin.SyncSlotGemDim(labels) end
        hooksecurefunc(contextOverlay, 'Show', Sync)
        hooksecurefunc(contextOverlay, 'Hide', Sync)
        hooksecurefunc(contextOverlay, 'SetShown', Sync)
    end

    return labels
end

local function RefreshGems(labels, link)
    local entries, gemLinks = ReadSockets(link)
    for index = 1, math.max(#entries, #labels.gems) do
        local entry = entries[index]
        local gem = labels.gems[index]
        if entry and not gem then
            gem = CreateGemFrame(labels.button)
            labels.gems[index] = gem
            Skin.SyncSlotGemDim(labels)
        end
        if gem then
            if entry then
                if gem.icon.SetAtlas then gem.icon:SetAtlas(nil) end
                gem.icon:SetTexture(nil)
                if entry.atlas then
                    gem.icon:SetAtlas(entry.atlas)
                    gem.link = nil
                    gem:SetBackdropBorderColor(GEM_BORDER_COMMON[1], GEM_BORDER_COMMON[2], GEM_BORDER_COMMON[3], 0.6)
                else
                    gem.icon:SetTexture(entry.icon)
                    gem.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    gem.link = gemLinks[index]
                    local quality = gem.link and C_Item.GetItemQualityByID(gem.link) or 2
                    local border = quality >= 3 and GEM_BORDER_RARE or GEM_BORDER_COMMON
                    gem:SetBackdropBorderColor(border[1], border[2], border[3], 1)
                end
                gem:ClearAllPoints()
                gem:SetPoint('BOTTOMRIGHT', labels.button, 'BOTTOMRIGHT',
                    -Pixel.Scale(GEM_INSET), Pixel.Scale(GEM_INSET + (index - 1) * (GEM_SIZE + GEM_PAD)))
                gem:Show()
            else
                gem:Hide()
            end
        end
    end
end

local function RefreshSlot(labels)
    local info, button = labels.info, labels.button
    local inventorySlot = GetInventorySlotInfo(info.id)
    local link = GetInventoryItemLink('player', inventorySlot)
    ApplyQualityBorder(button, link)

    if not link or info.cosmetic then
        labels.ilvl:SetText('')
        labels.track:SetText('')
        labels.enchant:SetText('')
        labels.enchantHover:Hide()
        RefreshGems(labels, info.cosmetic and nil or link)
        return
    end

    local trackText, trackColor = ReadUpgradeTrack(inventorySlot)
    local color = trackColor or QualityColor(link) or { 1, 1, 1 }

    local level = ReadItemLevel(inventorySlot, link)
    labels.ilvl:SetText(level > 0 and tostring(level) or '')
    labels.ilvl:SetTextColor(color[1], color[2], color[3], 0.9)

    labels.track:SetText(trackText or '')
    labels.track:SetTextColor(color[1], color[2], color[3], 0.6)

    local canEnchant = CanHaveEnchant(info, link)
    local enchant = canEnchant and ReadEnchant(inventorySlot, link) or ''
    local hasEnchant = enchant ~= ''
    local missing = canEnchant and not hasEnchant and AtEnchantLevel()

    if missing then
        labels.enchant:SetText('No Enchant')
        labels.enchant:SetTextColor(MISSING_COLOR[1], MISSING_COLOR[2], MISSING_COLOR[3], 1)

        labels.enchantHover.tooltip = 'Enchant missing'
        labels.enchantHover.slot = nil
        labels.enchantHover:Show()
    elseif hasEnchant then
        local icons = {}
        for atlas in enchant:gmatch('|A:[^|]+|a') do icons[#icons + 1] = atlas end
        local name = enchant:gsub('|A:[^|]+|a', ''):gsub('^%s+', ''):gsub('%s+$', '')
        name = name:gsub('^.-%s*%-%s*', '')
        labels.enchant:SetText(table.concat(icons, '') .. (#icons > 0 and ' ' or '') .. name)
        labels.enchant:SetTextColor(
            color[1] + (1 - color[1]) * 0.5,
            color[2] + (1 - color[2]) * 0.5,
            color[3] + (1 - color[3]) * 0.5, 0.95)
        labels.enchantHover.tooltip = name
        labels.enchantHover.slot = inventorySlot
        labels.enchantHover:Show()
    else
        labels.enchant:SetText('')
        labels.enchantHover:Hide()
    end

    RefreshGems(labels, link)
end

local function PlaceSlotButtons()
    for _, info in ipairs(SLOTS) do
        local button = _G['Character' .. info.id]
        if button then
            button:SetParent(frame)
            button:ClearAllPoints()
            button:SetSize(SLOT_SIZE, SLOT_SIZE)
            local x, y = SlotAnchor(info)
            button:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, y)
            button:SetFrameStrata(frame:GetFrameStrata())
            button:SetFrameLevel(frame:GetFrameLevel() + 3)
            button:SetAlpha(1)
            button:EnableMouse(true)
            button:Show()
            StyleSlotButton(button)
            slots[info.id] = button
            if not slotLabels[info.id] then slotLabels[info.id] = BuildSlotLabels(button, info) end
        end
    end

    C_Timer.After(0, function()
        for _, info in ipairs(SLOTS) do
            local button = _G['Character' .. info.id]
            if button and button._buiStyled then HideBlizzardDecorations(button) end
        end
    end)
end

local function FormatBigNumber(number)
    if number == nil then return '0' end
    if IsSecretValue(number) then return string.format('%s', AbbreviateNumbers(number)) end
    return BreakUpLargeNumbers and BreakUpLargeNumbers(number) or tostring(number)
end

local STAT_UNAVAILABLE = 'n/a'

local function SecretText(format, value)
    return { format = format, value = value }
end

local function FormatPct(value)
    if value == nil then return '0.00%' end
    if IsSecretValue(value) then return SecretText('%.2f%%', value) end
    return string.format('%.2f%%', value)
end

local function FormatRating(value)
    if value == nil then return '0' end
    if IsSecretValue(value) then return SecretText('%.0f', value) end
    return tostring(math.floor(value + 0.5))
end

local function FormatDecimal(value)
    if value == nil then return '0.00' end
    if IsSecretValue(value) then return SecretText('%.2f', value) end
    return string.format('%.2f', value)
end

local function SetStatText(fontString, text)
    if type(text) ~= 'table' then
        fontString:SetText(text or '')
        return
    end
    if not pcall(fontString.SetFormattedText, fontString, text.format, text.value) then
        fontString:SetText(STAT_UNAVAILABLE)
    end
end

local function MPScoreHex(score)
    for _, bracket in ipairs(MP_COLOR_BRACKETS) do
        if score >= bracket[1] then return bracket[2] end
    end
    return 'ffffff'
end

local function DurabilityPercent()
    local lowest = 100
    for slotIndex = 1, 18 do
        local current, maximum = GetInventoryItemDurability(slotIndex)
        if current and maximum and maximum > 0 then
            local percent = current / maximum * 100
            if percent < lowest then lowest = percent end
        end
    end
    return math.floor(lowest)
end

local function DurabilityColor(percent)
    if percent > 50 then return (100 - percent) / 50, 1, 0 end
    return 1, percent / 50, 0
end

local PRIMARY_NAMES = { [1] = 'Strength', [2] = 'Agility', [3] = 'Stamina', [4] = 'Intellect' }

local function PrimaryStatIndex()
    local specIndex = GetSpecialization()
    if specIndex then
        local _, _, _, _, _, primary = GetSpecializationInfo(specIndex)
        if primary then return primary end
    end
    return 4
end

local function IsBrewmaster()
    local specIndex = GetSpecialization()
    return specIndex ~= nil and (GetSpecializationInfo(specIndex)) == 268
end

local function PctStat(name, percentFn, ratingID, tooltip, title)
    if type(tooltip) == 'string' then
        local template = tooltip
        tooltip = function()
            local value = percentFn()
            if type(value) ~= 'number' or IsSecretValue(value) then return nil end
            return template:format(value)
        end
    end
    return {
        name = name,
        value = function() return FormatRating(GetCombatRating(ratingID)) end,
        percent = function() return FormatPct(percentFn()) end,
        detail = function()
            local rating = GetCombatRating(ratingID)
            if rating == nil or IsSecretValue(rating) then return nil end
            return FormatRating(rating) .. ' rating'
        end,
        tooltip = tooltip,
        title = title,
        ratingID = ratingID,
    }
end

local function ArmorReduction()
    local armor = select(3, UnitArmor('player'))
    if type(armor) ~= 'number' or IsSecretValue(armor) then return nil end
    local Effectiveness = C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectiveness
    if not Effectiveness then return nil end
    local reduction = Effectiveness(armor, UnitLevel('player'))
    if type(reduction) ~= 'number' or IsSecretValue(reduction) then return nil end
    return FormatPct(reduction * 100) .. ' physical damage reduced'
end

local STAT_SECTIONS = {
    {
        title = 'Attributes',
        stats = function()
            local primary = PrimaryStatIndex()
            local rows = {
                { name = PRIMARY_NAMES[primary] or 'Primary', primary = true, value = function() return FormatBigNumber((select(2, UnitStat('player', primary)))) end },
                { name = 'Stamina', value = function() return FormatBigNumber((select(2, UnitStat('player', 3)))) end },
                { name = 'Health',  value = function() return FormatBigNumber(UnitHealthMax('player')) end },
            }
            local mana = UnitPowerMax('player', Enum.PowerType.Mana) or 0
            if not IsSecretValue(mana) and mana > 0 then
                rows[#rows + 1] = { name = 'Mana', value = function() return FormatBigNumber(UnitPowerMax('player', Enum.PowerType.Mana)) end }
            end
            return rows
        end,
    },
    {
        title = 'Secondary',
        stats = function()
            return {
                PctStat('Critical Strike', function() return GetCritChance() end, CR_CRIT_MELEE,
                    'Your attacks and spells have a %.2f%% chance to critically strike, dealing double damage or healing.'),
                PctStat('Haste',           function() return GetHaste() end, CR_HASTE_MELEE,
                    'Your attacks and casts are %.2f%% faster, and resources that scale with haste generate that much quicker.'),
                PctStat('Mastery', function() return GetMasteryEffect() end, CR_MASTERY,
                    function()
                        local specIndex = GetSpecialization()
                        local masterySpell = specIndex and GetSpecializationMasterySpells(specIndex)
                        local description = masterySpell and C_Spell.GetSpellDescription(masterySpell)
                        if description and description ~= '' then return description end
                        return nil
                    end,
                    function()
                        local specIndex = GetSpecialization()
                        local masterySpell = specIndex and GetSpecializationMasterySpells(specIndex)
                        return masterySpell and C_Spell.GetSpellName(masterySpell) or nil
                    end),
                PctStat('Versatility',     function() return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) end, CR_VERSATILITY_DAMAGE_DONE,
                    function()
                        local done = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
                        if type(done) ~= 'number' or IsSecretValue(done) then return nil end
                        local taken = CR_VERSATILITY_DAMAGE_TAKEN and GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_TAKEN)
                        if type(taken) ~= 'number' or IsSecretValue(taken) then
                            return ('Increases your damage and healing done by %.2f%%.'):format(done)
                        end
                        return ('Increases your damage and healing done by %.2f%%, and reduces damage you take by %.2f%%.'):format(done, taken)
                    end),
            }
        end,
    },
    {
        title = 'Tertiary',
        stats = function()
            return {
                PctStat('Leech',     function() return GetLifesteal() end, CR_LIFESTEAL,
                    'Heals you for %.2f%% of the damage and healing you deal.'),
                PctStat('Avoidance', function() return GetAvoidance() end, CR_AVOIDANCE,
                    'Reduces the damage you take from area effects by %.2f%%.'),
                PctStat('Speed',     function() return GetSpeed() end, CR_SPEED,
                    'Increases your movement speed by %.2f%% above base run speed.'),
            }
        end,
    },
    {
        title = 'Attack',
        stats = function()
            local rows = {}
            if PrimaryStatIndex() == 4 then
                rows[#rows + 1] = { name = 'Spell Power', value = function() return FormatBigNumber(GetSpellBonusDamage(7)) end }
            else
                rows[#rows + 1] = { name = 'Attack Power', value = function()
                    local base, positive, negative = UnitAttackPower('player')
                    if IsSecretValue(base) or IsSecretValue(positive) or IsSecretValue(negative) then return FormatBigNumber(base) end
                    return FormatBigNumber((base or 0) + (positive or 0) + (negative or 0))
                end }
            end
            rows[#rows + 1] = { name = 'Attack Speed', value = function() return FormatDecimal((UnitAttackSpeed('player'))) end }
            return rows
        end,
    },
    {
        title = 'Defense',
        stats = function()
            local rows = {
                { name = 'Armor', value = function() return FormatBigNumber((select(3, UnitArmor('player')))) end, detail = ArmorReduction },
                { name = 'Dodge', value = function() return FormatPct(GetDodgeChance()) end },
                { name = 'Parry', value = function() return FormatPct(GetParryChance()) end },
                { name = 'Block', value = function() return FormatPct(GetBlockChance()) end },
            }
            if IsBrewmaster() then
                rows[#rows + 1] = { name = 'Stagger', value = function() return FormatPct(C_PaperDollInfo.GetStaggerPercentage('player')) end }
            end
            return rows
        end,
    },
    {
        title = 'PvP',
        stats = function()
            return {
                { name = 'Honor Level', value = function() return tostring(UnitHonorLevel and UnitHonorLevel('player') or 0) end },
                { name = 'Honor', value = function()
                    local current = UnitHonor and UnitHonor('player') or 0
                    local maximum = UnitHonorMax and UnitHonorMax('player') or 0
                    return FormatBigNumber(current) .. '/' .. FormatBigNumber(maximum)
                end },
                { name = 'Conquest', value = function()
                    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(CONQUEST_CURRENCY)
                    return FormatBigNumber(info and info.quantity or 0)
                end },
            }
        end,
    },
}

local function CreateStatRow(parent)
    local row = CreateFrame('Frame', nil, parent)
    row:SetHeight(Pixel.Scale(ROW_HEIGHT))
    row:EnableMouse(true)

    row.label = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(row.label, ROW_SIZE, FONT, '')
    row.label:SetPoint('LEFT', 0, 0)
    row.label:SetTextColor(LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3], 1)

    row.value = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(row.value, ROW_SIZE, FONT, '')
    row.value:SetPoint('RIGHT', 0, 0)
    row.value:SetJustifyH('RIGHT')
    row.value:SetTextColor(VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3], 1)

    row.separator = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(row.separator, ROW_SIZE, FONT, '')
    row.separator:SetPoint('RIGHT', row, 'RIGHT', -Pixel.Scale(RATING_COL_W), 0)
    row.separator:SetText('|')
    row.separator:SetTextColor(SEPARATOR_COLOR[1], SEPARATOR_COLOR[2], SEPARATOR_COLOR[3], 1)
    row.separator:Hide()

    row.percent = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(row.percent, ROW_SIZE, FONT, '')
    row.percent:SetPoint('RIGHT', row.separator, 'LEFT', -Pixel.Scale(COLUMN_GAP), 0)
    row.percent:SetJustifyH('RIGHT')
    row.percent:SetTextColor(VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3], 1)

    local DETAIL_STEP = 100

    local function BuildTooltip(self)
        if not self.stat then return end
        local detail = self.stat.detail and self.stat.detail()
        local blurb = self.stat.tooltip
        if type(blurb) == 'function' then blurb = blurb() end
        local dr = self.stat.ratingID and BUI.TrueStats and BUI.TrueStats.Get and BUI.TrueStats.Get(self.stat.ratingID)
        if not detail and not blurb and not dr then return end
        local heading = self.stat.title
        if type(heading) == 'function' then heading = heading() end
        local color = self.sectionColor or VALUE_COLOR
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
        GameTooltip:SetText(heading or self.stat.name, color[1], color[2], color[3])
        if detail then GameTooltip:AddLine(detail, color[1], color[2], color[3]) end
        if blurb then
            local highlighted = blurb:gsub('(%d+%.?%d*%%)', '|cff' .. BUI.Hex(color[1], color[2], color[3]) .. '%1|r')
            GameTooltip:AddLine(highlighted, 0.8, 0.8, 0.8, true)
        end
        if dr then
            local red, green, blue = BUI.TrueStats.PenaltyColor(dr.penalty)
            GameTooltip:AddLine(' ')
            GameTooltip:AddDoubleLine('Effective rating', FormatRating(dr.effective), 0.8, 0.8, 0.8, red, green, blue)
            GameTooltip:AddDoubleLine('Lost to diminishing returns',
                FormatRating(dr.wasted) .. '  ' .. math.floor(dr.penalty * 100 + 0.5) .. '%', 0.8, 0.8, 0.8, red, green, blue)
            if dr.toNext > 0 and dr.nextPenalty < 1 then
                local nextRed, nextGreen, nextBlue = BUI.TrueStats.PenaltyColor(dr.nextPenalty)
                GameTooltip:AddDoubleLine('Until ' .. math.floor(dr.nextPenalty * 100 + 0.5) .. '% penalty',
                    FormatRating(dr.toNext), 0.8, 0.8, 0.8, nextRed, nextGreen, nextBlue)
            end
            if self.detailed then
                GameTooltip:AddLine(' ')
                local step = BUI.TrueStats.GainFrom(self.stat.ratingID, DETAIL_STEP)
                if step then
                    GameTooltip:AddDoubleLine('+' .. DETAIL_STEP .. ' rating gives', FormatPct(step), 0.6, 0.6, 0.6, red, green, blue)
                end
                local toWhole = BUI.TrueStats.CostOfNext(self.stat.ratingID, 1)
                if toWhole and toWhole > 0 then
                    GameTooltip:AddDoubleLine('Next +1% costs', FormatRating(toWhole) .. ' rating', 0.6, 0.6, 0.6, 0.9, 0.9, 0.95)
                end
                if BUI.TrueStats.IsDamageRating(self.stat.ratingID) then
                    local costs = BUI.TrueStats.DamageCosts()
                    if costs then
                        GameTooltip:AddDoubleLine('Rating per +1%', costs, 0.6, 0.6, 0.6, 0.9, 0.9, 0.95)
                    end
                elseif self.stat.ratingID == CR_MASTERY then
                    GameTooltip:AddLine('Mastery damage per point is spec specific, so it will not line up with the others.', 0.55, 0.55, 0.6, true)
                end
            else
                GameTooltip:AddLine('Hold Ctrl for details', 0.45, 0.45, 0.5)
            end
        end
        GameTooltip:Show()
    end

    local WatchModifier = function(self)
        local held = IsControlKeyDown() and true or false
        if held ~= self.detailed then
            self.detailed = held
            BuildTooltip(self)
        end
    end

    row:SetScript('OnEnter', function(self)
        self.detailed = IsControlKeyDown() and true or false
        BuildTooltip(self)
        if self.stat and self.stat.ratingID then self:SetScript('OnUpdate', WatchModifier) end
    end)

    row:SetScript('OnLeave', function(self)
        self:SetScript('OnUpdate', nil)
        GameTooltip:Hide()
    end)
    return row
end

local function CreateSectionHeader(parent, title, color)
    local header = CreateFrame('Button', nil, parent)
    header:SetHeight(Pixel.Scale(HEADER_HEIGHT))
    header:RegisterForClicks('LeftButtonUp')

    local text = header:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(text, HEADER_SIZE, FONT, '')
    text:SetPoint('CENTER')
    text:SetTextColor(color[1], color[2], color[3], 1)
    text:SetText(title)

    local leftBar = header:CreateTexture(nil, 'ARTWORK')
    leftBar:SetHeight(Pixel.PixelSize(1))
    leftBar:SetPoint('LEFT', header, 'LEFT', 0, 0)
    leftBar:SetPoint('RIGHT', text, 'LEFT', Pixel.Scale(-6), 0)
    leftBar:SetColorTexture(color[1], color[2], color[3], 0.8)

    local rightBar = header:CreateTexture(nil, 'ARTWORK')
    rightBar:SetHeight(Pixel.PixelSize(1))
    rightBar:SetPoint('LEFT', text, 'RIGHT', Pixel.Scale(6), 0)
    rightBar:SetPoint('RIGHT', header, 'RIGHT', 0, 0)
    rightBar:SetColorTexture(color[1], color[2], color[3], 0.8)

    header.text = text
    return header
end

local LayoutSections

local function BuildSection(parent, definition)
    local section = {
        definition = definition,
        container = CreateFrame('Frame', nil, parent),
        rows = {},
        collapsed = false,
    }
    section.header = CreateSectionHeader(section.container, definition.title, SECTION_COLORS[definition.title])
    section.header:SetPoint('TOPLEFT')
    section.header:SetPoint('TOPRIGHT')
    section.header:SetScript('OnClick', function()
        section.collapsed = not section.collapsed
        LayoutSections()
    end)
    return section
end

local function FillSection(section)
    local stats = section.definition.stats()
    for index, stat in ipairs(stats) do
        local row = section.rows[index]
        if not row then
            row = CreateStatRow(section.container)
            section.rows[index] = row
        end
        row.stat = stat
        row.label:SetText(stat.name)
        local color = SECTION_COLORS[section.definition.title] or VALUE_COLOR
        row.sectionColor = color
        row.value:SetTextColor(color[1], color[2], color[3], 1)
        row.percent:SetTextColor(color[1], color[2], color[3], 1)
    end
    for index = #stats + 1, #section.rows do section.rows[index]:Hide() end
    section.rowCount = #stats
end

LayoutSections = function()
    if not sidebar then return end
    local scrollChild = sidebar.statsScroll.child
    local offsetY = 0
    for _, section in ipairs(sections) do
        local height = HEADER_HEIGHT
        if not section.collapsed then
            local rowY = -(HEADER_HEIGHT + HEADER_ROW_GAP)
            for index = 1, section.rowCount or 0 do
                local row = section.rows[index]
                row:ClearAllPoints()
                row:SetPoint('TOPLEFT', section.container, 'TOPLEFT', 0, Pixel.Scale(rowY))
                row:SetPoint('TOPRIGHT', section.container, 'TOPRIGHT', 0, Pixel.Scale(rowY))
                row:Show()
                rowY = rowY - ROW_HEIGHT
            end
            height = HEADER_HEIGHT + HEADER_ROW_GAP + (section.rowCount or 0) * ROW_HEIGHT
        else
            for index = 1, section.rowCount or 0 do section.rows[index]:Hide() end
        end
        section.container:ClearAllPoints()
        section.container:SetPoint('TOPLEFT', scrollChild, 'TOPLEFT', 0, Pixel.Scale(offsetY))
        section.container:SetPoint('TOPRIGHT', scrollChild, 'TOPRIGHT', 0, Pixel.Scale(offsetY))
        section.container:SetHeight(Pixel.Scale(height))
        section.header.text:SetAlpha(section.collapsed and 0.6 or 1)
        offsetY = offsetY - height - SECTION_GAP
    end
    sidebar.statsScroll:SetChildHeight(Pixel.Scale(-offsetY + 4))
    sidebar.statsScroll:UpdateScroll()
end

local function CreateListRow(parent, width)
    local row = CreateFrame('Button', nil, parent)
    row:SetSize(Pixel.Scale(width), Pixel.Scale(LIST_ROW_H))
    row.bg = row:CreateTexture(nil, 'BACKGROUND')
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(LIST_ROW_BG[1], LIST_ROW_BG[2], LIST_ROW_BG[3], LIST_ROW_BG[4])
    row.hover = row:CreateTexture(nil, 'ARTWORK')
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(LIST_ROW_HOVER[1], LIST_ROW_HOVER[2], LIST_ROW_HOVER[3], LIST_ROW_HOVER[4])
    row.hover:Hide()
    row.text = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(row.text, LIST_SIZE, FONT, '')
    row.text:SetPoint('LEFT', Pixel.Scale(8), 0)
    row.text:SetPoint('RIGHT', Pixel.Scale(-8), 0)
    row.text:SetJustifyH('LEFT')
    row.text:SetWordWrap(false)
    row.text:SetTextColor(1, 1, 1, 1)
    row:SetScript('OnEnter', function(self) self.hover:Show() end)
    row:SetScript('OnLeave', function(self) self.hover:Hide() end)
    return row
end

local function SetRowSelected(row, selected)
    if selected then
        local red, green, blue = Colors.GetAccent()
        row.bg:SetColorTexture(red, green, blue, 0.5)
    else
        row.bg:SetColorTexture(LIST_ROW_BG[1], LIST_ROW_BG[2], LIST_ROW_BG[3], LIST_ROW_BG[4])
    end
end

local function CreateScrollList(parent, topOffset, rowWidth)
    local area = CreateFrame('Frame', nil, parent)
    area:SetPoint('TOPLEFT', parent, 'TOPLEFT', Pixel.Scale(SIDEBAR_INSET), Pixel.Scale(-topOffset))
    area:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', Pixel.Scale(-SIDEBAR_INSET), Pixel.Scale(SIDEBAR_INSET))
    local scroll = Widget.Unwrap(Controls.ScrollFrame(area, nil, nil, 100, Pixel.Scale(rowWidth)))
    return area, scroll
end

local function CreateTab(parent, label, onClick)
    local tab = CreateFrame('Button', nil, parent)
    tab:SetHeight(Pixel.Scale(TAB_ROW_HEIGHT))
    tab.text = tab:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(tab.text, TAB_SIZE, FONT, '')
    tab.text:SetPoint('CENTER')
    tab.text:SetText(label)
    tab.underline = tab:CreateTexture(nil, 'OVERLAY')
    tab.underline:SetHeight(Pixel.PixelSize(1))
    tab.underline:SetPoint('BOTTOMLEFT', Pixel.Scale(6), 0)
    tab.underline:SetPoint('BOTTOMRIGHT', Pixel.Scale(-6), 0)
    tab.underline:Hide()
    tab:SetScript('OnEnter', function(self) if not self.active then self.text:SetTextColor(1, 1, 1, 1) end end)
    tab:SetScript('OnLeave', function(self) if not self.active then self.text:SetTextColor(1, 1, 1, 0.6) end end)
    tab:SetScript('OnClick', onClick)
    return tab
end

local function PaintTabs()
    for _, tab in ipairs(sidebar.tabs) do
        if tab.active then
            local red, green, blue = Colors.GetAccent()
            tab.text:SetTextColor(red, green, blue, 1)
            tab.underline:SetColorTexture(red, green, blue, 1)
            tab.underline:Show()
        else
            tab.text:SetTextColor(1, 1, 1, 0.6)
            tab.underline:Hide()
        end
    end
end

local RefreshTitles, RefreshSets

local function ShowPane(key)
    for paneKey, pane in pairs(sidebar.panes) do pane:SetShown(paneKey == key) end
    for _, tab in ipairs(sidebar.tabs) do tab.active = tab.key == key end
    PaintTabs()
    if key == 'titles' then RefreshTitles() elseif key == 'sets' then RefreshSets() end
end


local function TitleSortKey(name)
    return (name or ''):gsub('%%s', ' '):gsub('^%s+', ''):gsub('%s+$', ''):lower()
end

local function BuildTitlesPane(parent)
    local pane = CreateFrame('Frame', nil, parent)
    pane:SetAllPoints()
    pane:Hide()

    local search = CreateFrame('EditBox', nil, pane)
    search:SetPoint('TOPLEFT', pane, 'TOPLEFT', Pixel.Scale(SIDEBAR_INSET), Pixel.Scale(-(TAB_ROW_HEIGHT + 8)))
    search:SetPoint('TOPRIGHT', pane, 'TOPRIGHT', Pixel.Scale(-SIDEBAR_INSET), Pixel.Scale(-(TAB_ROW_HEIGHT + 8)))
    search:SetHeight(Pixel.Scale(22))
    search:SetAutoFocus(false)
    search:SetMaxLetters(24)
    Pixel.ApplyFont(search, LIST_SIZE, FONT, '')
    search:SetTextInsets(Pixel.Scale(6), Pixel.Scale(6), 0, 0)
    search:SetTextColor(1, 1, 1, 1)
    local searchBg = search:CreateTexture(nil, 'BACKGROUND')
    searchBg:SetAllPoints()
    searchBg:SetColorTexture(SEARCH_BG[1], SEARCH_BG[2], SEARCH_BG[3], SEARCH_BG[4])
    local hint = search:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(hint, LIST_SIZE, FONT, '')
    hint:SetPoint('LEFT', Pixel.Scale(6), 0)
    hint:SetText('Search titles')
    hint:SetTextColor(0.6, 0.6, 0.6, 0.7)
    search:SetScript('OnEscapePressed', function(self) self:SetText(''); self:ClearFocus() end)
    search:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
    search:SetScript('OnTextChanged', function(self)
        hint:SetShown(self:GetText() == '')
        RefreshTitles()
    end)
    pane.search = search

    local rowWidth = STATS_W - SIDEBAR_INSET * 2 - SCROLLBAR_W - LIST_RIGHT_PAD
    pane.area, pane.scroll = CreateScrollList(pane, TAB_ROW_HEIGHT + 8 + 22 + 6, rowWidth)
    pane.rowWidth = rowWidth
    pane.rows = {}
    pane.entries = {}
    return pane
end

RefreshTitles = function()
    local pane = sidebar and sidebar.panes.titles
    if not pane or not pane:IsShown() then return end

    local entries = pane.entries
    wipe(entries)
    entries[#entries + 1] = { index = NO_TITLE, name = 'No Title' }
    for titleIndex = 1, GetNumTitles() do
        if IsTitleKnown(titleIndex) then
            local name = GetTitleName(titleIndex)
            if name then entries[#entries + 1] = { index = titleIndex, name = name } end
        end
    end
    table.sort(entries, function(left, right)
        if left.index == NO_TITLE then return true end
        if right.index == NO_TITLE then return false end
        return TitleSortKey(left.name) < TitleSortKey(right.name)
    end)

    local filter = pane.search:GetText():lower()
    local current = GetCurrentTitle()
    if not current or current == 0 then current = NO_TITLE end

    local visible = 0
    for _, entry in ipairs(entries) do
        local shown = filter == '' or TitleSortKey(entry.name):find(filter, 1, true) ~= nil
        if shown then
            visible = visible + 1
            local row = pane.rows[visible]
            if not row then
                row = CreateListRow(pane.scroll.child, pane.rowWidth)
                row:SetScript('OnClick', function(self)
                    SetCurrentTitle(self.titleIndex)
                    for _, other in ipairs(pane.rows) do SetRowSelected(other, other.titleIndex == self.titleIndex) end
                end)
                pane.rows[visible] = row
            end
            row.titleIndex = entry.index
            row.text:SetText((entry.name:gsub('%%s', ''):gsub('^%s+', ''):gsub('%s+$', '')))
            SetRowSelected(row, entry.index == current)
            row:ClearAllPoints()
            row:SetPoint('TOPLEFT', pane.scroll.child, 'TOPLEFT', 0, -Pixel.Scale((visible - 1) * (LIST_ROW_H + LIST_ROW_GAP)))
            row:Show()
        end
    end
    for index = visible + 1, #pane.rows do pane.rows[index]:Hide() end
    pane.scroll:SetChildHeight(Pixel.Scale(math.max(1, visible * (LIST_ROW_H + LIST_ROW_GAP))))
    pane.scroll:UpdateScroll()
end


local selectedSetID

local function MissingSetItems(setID)
    local items = C_EquipmentSet.GetItemIDs(setID)
    local missing = {}
    if not items then return missing end
    for slot, itemID in pairs(items) do
        if itemID and itemID > 0 and GetInventoryItemID('player', slot) ~= itemID then
            local count = C_Item.GetItemCount(itemID, true, true) or 0
            if count == 0 then
                local name = C_Item.GetItemInfo(itemID) or ('item ' .. itemID)
                missing[#missing + 1] = (EQUIPMENT_SLOT_NAMES[slot] or 'Slot') .. ': ' .. name
            end
        end
    end
    return missing
end

local function InCombatNotice()
    if not InCombatLockdown() then return false end
    BUI.Print('Equipment sets cannot change during combat.')
    return true
end

StaticPopupDialogs['BUI_NEW_EQUIPMENT_SET'] = {
    text = 'Name for the new equipment set:',
    button1 = 'Create', button2 = 'Cancel',
    hasEditBox = true, editBoxWidth = 200,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    OnAccept = function(dialog)
        local editBox = dialog.EditBox or dialog.editBox
        local name = editBox and editBox:GetText() or ''
        name = name:gsub('^%s+', ''):gsub('%s+$', '')
        if name == '' or InCombatLockdown() then return end
        C_EquipmentSet.CreateEquipmentSet(name, QUESTION_MARK_ICON)
    end,
    EditBoxOnEnterPressed = function(editBox)
        local dialog = editBox:GetParent()
        StaticPopupDialogs['BUI_NEW_EQUIPMENT_SET'].OnAccept(dialog)
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
}

StaticPopupDialogs['BUI_RENAME_EQUIPMENT_SET'] = {
    text = 'Rename %s to:',
    button1 = 'Rename', button2 = 'Cancel',
    hasEditBox = true, editBoxWidth = 200,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    OnAccept = function(dialog)
        local editBox = dialog.EditBox or dialog.editBox
        local name = editBox and editBox:GetText() or ''
        name = name:gsub('^%s+', ''):gsub('%s+$', '')
        if name == '' or InCombatLockdown() then return end
        C_EquipmentSet.ModifyEquipmentSet(dialog.data, name)
    end,
    EditBoxOnEnterPressed = function(editBox)
        local dialog = editBox:GetParent()
        StaticPopupDialogs['BUI_RENAME_EQUIPMENT_SET'].OnAccept(dialog)
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
}

StaticPopupDialogs['BUI_DELETE_EQUIPMENT_SET'] = {
    text = 'Delete the equipment set %s?',
    button1 = 'Delete', button2 = 'Cancel',
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    OnAccept = function(dialog)
        if InCombatLockdown() then return end
        C_EquipmentSet.DeleteEquipmentSet(dialog.data)
    end,
}

local function EquipSet(setID)
    if not setID or InCombatNotice() then return end
    if EquipmentManager_EquipSet then EquipmentManager_EquipSet(setID) else C_EquipmentSet.UseEquipmentSet(setID) end
end

local iconPopupContext = Skin.NewContext(function() return Skin.IsSkinEnabled('characterFrame') end)

local function EditSetIcon(setID, setName)
    if InCombatNotice() then return end
    local popup = GearManagerPopupFrame
    popup:Hide()
    popup:SetParent(UIParent)
    popup:SetFrameStrata('DIALOG')
    popup:EnableMouse(true)
    popup:ClearAllPoints()
    popup:SetPoint('TOPLEFT', frame, 'TOPRIGHT', Pixel.Scale(4), 0)
    Skin.TipIconPopup(iconPopupContext, popup)
    popup.mode = IconSelectorPopupFrameModes.Edit
    popup.setID = setID
    popup.origName = setName
    popup:Show()
end

local function ShowSetMenu(row)
    local setID, setName = row.setID, row.setName
    local assigned = C_EquipmentSet.GetEquipmentSetAssignedSpec and C_EquipmentSet.GetEquipmentSetAssignedSpec(setID)
    local items = {
        { title = true, text = setName },
        { text = 'Equip', callback = function() EquipSet(setID) end },
        { separator = true },
        { title = true, text = 'Assign to spec' },
    }
    for specIndex = 1, GetNumSpecializations() do
        local _, specName = GetSpecializationInfo(specIndex)
        items[#items + 1] = {
            text = specName or ('Spec ' .. specIndex),
            checked = assigned == specIndex,
            callback = function()
                if InCombatNotice() then return end
                C_EquipmentSet.AssignSpecToEquipmentSet(setID, specIndex)
                RefreshSets()
            end,
        }
    end
    items[#items + 1] = {
        text = 'No spec',
        checked = not assigned,
        callback = function()
            if InCombatNotice() then return end
            C_EquipmentSet.UnassignEquipmentSetSpec(setID)
            RefreshSets()
        end,
    }
    items[#items + 1] = { separator = true }
    items[#items + 1] = {
        text = 'Rename',
        callback = function()
            if InCombatNotice() then return end
            local dialog = StaticPopup_Show('BUI_RENAME_EQUIPMENT_SET', setName)
            if dialog then dialog.data = setID end
        end,
    }
    items[#items + 1] = {
        text = 'Change Icon',
        callback = function() EditSetIcon(setID, setName) end,
    }
    items[#items + 1] = {
        text = 'Delete',
        callback = function()
            if InCombatNotice() then return end
            local dialog = StaticPopup_Show('BUI_DELETE_EQUIPMENT_SET', setName)
            if dialog then dialog.data = setID end
        end,
    }
    Controls.ContextMenu(items, { atCursor = true, width = 200 })
end


local SET = {
    ROW_H = 36, ROW_GAP = 3, ROW_ICON = 28,
    GRID_COLS = 9, GRID_ICON = 24, GRID_GAP = 3, GRID_PAD = 4, BLOCK_GAP = 8,
    GRID_ORDER = { 1, 2, 3, 15, 5, 4, 19, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 },
    CELL_BORDER = { 0.16, 0.16, 0.18, 1 },
    TICK_COLOR = { 0.5, 0.88, 0.5 },
}
function SET.CreateCell(parent)
    local cell = CreateFrame('Button', nil, parent, 'BackdropTemplate')
    cell:SetSize(Pixel.Scale(SET.GRID_ICON), Pixel.Scale(SET.GRID_ICON))
    Skin.ApplyBackdrop(cell, SLOT_BG, SET.CELL_BORDER)
    cell.icon = cell:CreateTexture(nil, 'ARTWORK')
    cell.icon:SetPoint('TOPLEFT', 1, -1)
    cell.icon:SetPoint('BOTTOMRIGHT', -1, 1)
    cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell:SetScript('OnEnter', function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
        GameTooltip:SetItemByID(self.itemID)
        if self.missing then GameTooltip:AddLine('Not in your bags', 1, 0.4, 0.4) end
        GameTooltip:Show()
    end)
    cell:SetScript('OnLeave', function() GameTooltip:Hide() end)
    return cell
end

function SET.CreateRow(pane)
    local row = CreateListRow(pane.scroll.child, pane.rowWidth)
    row:SetHeight(Pixel.Scale(SET.ROW_H))

    row.iconFrame = CreateFrame('Frame', nil, row, 'BackdropTemplate')
    row.iconFrame:SetSize(Pixel.Scale(SET.ROW_ICON), Pixel.Scale(SET.ROW_ICON))
    row.iconFrame:SetPoint('LEFT', Pixel.Scale(4), 0)
    Skin.ApplyBackdrop(row.iconFrame, SLOT_BG, SET.CELL_BORDER)
    row.icon = row.iconFrame:CreateTexture(nil, 'ARTWORK')
    row.icon:SetPoint('TOPLEFT', 1, -1)
    row.icon:SetPoint('BOTTOMRIGHT', -1, 1)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.marker = row:CreateTexture(nil, 'ARTWORK')
    row.marker:SetSize(Pixel.Scale(14), Pixel.Scale(14))
    row.marker:SetPoint('RIGHT', Pixel.Scale(-8), 0)
    row.marker:SetTexture(BUILib.GetLibMedia('check'))
    row.marker:SetVertexColor(SET.TICK_COLOR[1], SET.TICK_COLOR[2], SET.TICK_COLOR[3], 1)

    row.text:ClearAllPoints()
    row.text:SetPoint('TOPLEFT', row.iconFrame, 'TOPRIGHT', Pixel.Scale(8), Pixel.Scale(-1))
    row.text:SetPoint('RIGHT', row.marker, 'LEFT', Pixel.Scale(-6), 0)
    Pixel.ApplyFont(row.text, LIST_SIZE + 1, FONT, 'OUTLINE')

    row.status = row:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(row.status, LIST_SIZE - 1, FONT, '')
    row.status:SetPoint('TOPLEFT', row.text, 'BOTTOMLEFT', 0, Pixel.Scale(-1))
    row.status:SetPoint('RIGHT', row.marker, 'LEFT', Pixel.Scale(-6), 0)
    row.status:SetJustifyH('LEFT')
    row.status:SetWordWrap(false)

    row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    row:SetScript('OnClick', function(self, mouseButton)
        selectedSetID = self.setID
        RefreshSets()
        if mouseButton == 'RightButton' then ShowSetMenu(self) end
    end)
    row:SetScript('OnDoubleClick', function(self) EquipSet(self.setID) end)
    row:SetScript('OnEnter', function(self)
        self.hover:Show()
        local missing = MissingSetItems(self.setID)
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
        GameTooltip:SetText(self.setName, 1, 1, 1)
        if #missing == 0 then
            GameTooltip:AddLine('All items available', 0.5, 0.9, 0.5)
        else
            GameTooltip:AddLine('Missing:', 1, 0.4, 0.4)
            for _, line in ipairs(missing) do GameTooltip:AddLine(line, 0.8, 0.8, 0.8) end
        end
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine('Double-click to equip, right-click for spec binding.', 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    row:SetScript('OnLeave', function(self) self.hover:Hide(); GameTooltip:Hide() end)
    return row
end

local function BuildSetsPane(parent)
    local pane = CreateFrame('Frame', nil, parent)
    pane:SetAllPoints()
    pane:Hide()

    local innerWidth = STATS_W - SIDEBAR_INSET * 2
    local buttonWidth = math.floor((innerWidth - SET.BLOCK_GAP * 2) / 3)
    local top = TAB_ROW_HEIGHT + 8

    pane.equipButton = Controls.Button(pane, 'Equip', buttonWidth, function() EquipSet(selectedSetID) end, { radius = 6, tooltip = 'Equip the selected set' })
    pane.equipButton:SetPoint('BOTTOMLEFT', pane, 'BOTTOMLEFT', Pixel.Scale(SIDEBAR_INSET), Pixel.Scale(SIDEBAR_INSET))
    pane.saveButton = Controls.Button(pane, 'Save', buttonWidth, function()
        if not selectedSetID or InCombatNotice() then return end
        C_EquipmentSet.SaveEquipmentSet(selectedSetID)
        BUI.Print('Equipment set updated with your current gear.')
        RefreshSets()
    end, { radius = 6, tooltip = 'Overwrite the selected set with what you are wearing' })
    pane.saveButton:SetPoint('BOTTOM', pane, 'BOTTOM', 0, Pixel.Scale(SIDEBAR_INSET))
    pane.newButton = Controls.Button(pane, 'New', buttonWidth, function()
        if InCombatNotice() then return end
        StaticPopup_Show('BUI_NEW_EQUIPMENT_SET')
    end, { radius = 6, tooltip = 'Save what you are wearing as a new set' })
    pane.newButton:SetPoint('BOTTOMRIGHT', pane, 'BOTTOMRIGHT', Pixel.Scale(-SIDEBAR_INSET), Pixel.Scale(SIDEBAR_INSET))

    local gridRows = math.ceil(#SET.GRID_ORDER / SET.GRID_COLS)
    local gridHeight = gridRows * SET.GRID_ICON + (gridRows - 1) * SET.GRID_GAP + SET.GRID_PAD * 2
    local gridWidth = SET.GRID_COLS * SET.GRID_ICON + (SET.GRID_COLS - 1) * SET.GRID_GAP
    pane.grid = CreateFrame('Frame', nil, pane)
    pane.grid:SetHeight(Pixel.Scale(gridHeight))
    pane.grid:SetPoint('BOTTOMLEFT', Widget.Unwrap(pane.equipButton), 'TOPLEFT', 0, Pixel.Scale(SET.BLOCK_GAP))
    pane.grid:SetPoint('BOTTOMRIGHT', Widget.Unwrap(pane.newButton), 'TOPRIGHT', 0, Pixel.Scale(SET.BLOCK_GAP))
    Widget.RoundedPanel(pane.grid, 6, LIST_ROW_BG, SET.CELL_BORDER)
    pane.cells = {}
    local startX = math.floor((innerWidth - gridWidth) / 2)
    for index in ipairs(SET.GRID_ORDER) do
        local column = (index - 1) % SET.GRID_COLS
        local rowIndex = math.floor((index - 1) / SET.GRID_COLS)
        local cell = SET.CreateCell(pane.grid)
        cell:SetPoint('TOPLEFT', pane.grid, 'TOPLEFT',
            Pixel.Scale(startX + column * (SET.GRID_ICON + SET.GRID_GAP)),
            Pixel.Scale(-(SET.GRID_PAD + rowIndex * (SET.GRID_ICON + SET.GRID_GAP))))
        pane.cells[index] = cell
    end

    local rowWidth = STATS_W - SIDEBAR_INSET * 2 - SCROLLBAR_W - LIST_RIGHT_PAD
    pane.area, pane.scroll = CreateScrollList(pane, top, rowWidth)
    pane.area:SetPoint('BOTTOMRIGHT', pane.grid, 'TOPRIGHT', 0, Pixel.Scale(SET.BLOCK_GAP))
    pane.rowWidth = rowWidth
    pane.rows = {}
    pane.empty = pane:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(pane.empty, LIST_SIZE, FONT, '')
    pane.empty:SetPoint('TOP', pane.area, 'TOP', 0, Pixel.Scale(-12))
    pane.empty:SetTextColor(0.6, 0.6, 0.6, 1)
    pane.empty:SetText('No equipment sets yet.')
    pane.empty:Hide()
    return pane
end

function SET.RefreshGrid(pane)
    local items = selectedSetID and C_EquipmentSet.GetItemIDs(selectedSetID)
    pane.grid:SetShown(items ~= nil)
    for index, slot in ipairs(SET.GRID_ORDER) do
        local cell = pane.cells[index]
        local itemID = items and items[slot]
        if itemID and itemID > 0 then
            cell.itemID = itemID
            cell.icon:SetTexture(C_Item.GetItemIconByID(itemID) or QUESTION_MARK_ICON)
            local equipped = GetInventoryItemID('player', slot) == itemID
            local inBags = equipped or (C_Item.GetItemCount(itemID, true, true) or 0) > 0
            cell.missing = not inBags
            cell.icon:SetDesaturated(not inBags)
            cell.icon:SetAlpha(inBags and 1 or 0.55)
            if not inBags then
                cell:SetBackdropBorderColor(MISSING_COLOR[1], MISSING_COLOR[2], MISSING_COLOR[3], 1)
            else
                cell:SetBackdropBorderColor(SET.CELL_BORDER[1], SET.CELL_BORDER[2], SET.CELL_BORDER[3], 1)
            end
            cell:Show()
        else
            cell.itemID = nil
            cell.missing = nil
            cell.icon:SetTexture(nil)
            cell:SetBackdropBorderColor(SET.CELL_BORDER[1], SET.CELL_BORDER[2], SET.CELL_BORDER[3], 1)
            cell:SetShown(items ~= nil)
        end
    end
end

RefreshSets = function()
    local pane = sidebar and sidebar.panes.sets
    if not pane or not pane:IsShown() then return end

    local setIDs = C_EquipmentSet.GetEquipmentSetIDs() or {}
    local count = 0
    local anyEquipped, selectedStillExists
    for _, setID in ipairs(setIDs) do
        local name, iconFileID, _, isEquipped, numItems, numEquipped, _, numLost = C_EquipmentSet.GetEquipmentSetInfo(setID)
        if name and name ~= '' then
            count = count + 1
            if isEquipped then anyEquipped = setID end
            if setID == selectedSetID then selectedStillExists = true end
            local row = pane.rows[count] or SET.CreateRow(pane)
            pane.rows[count] = row
            row.setID, row.setName = setID, name
            row.text:SetText(name)
            row.icon:SetTexture(iconFileID or QUESTION_MARK_ICON)
            local assignedSpec = C_EquipmentSet.GetEquipmentSetAssignedSpec(setID)
            local specName = assignedSpec and select(2, GetSpecializationInfo(assignedSpec))
            local total, worn, lost = numItems or 0, numEquipped or 0, numLost or 0
            local status
            row.marker:SetShown(isEquipped)
            if isEquipped then
                status = '|cff80e080Equipped|r'
            elseif lost > 0 then
                status = ('|cff%02x%02x%02x%d missing|r'):format(MISSING_COLOR[1] * 255, MISSING_COLOR[2] * 255, MISSING_COLOR[3] * 255, lost)
            else
                status = ('%d/%d'):format(worn, total)
            end
            if specName then status = status .. '  |cff555555||  ' .. specName end
            row.status:SetText(status)
            row.status:SetTextColor(0.6, 0.6, 0.62, 1)
            row:ClearAllPoints()
            row:SetPoint('TOPLEFT', pane.scroll.child, 'TOPLEFT', 0, -Pixel.Scale((count - 1) * (SET.ROW_H + SET.ROW_GAP)))
            row:Show()
        end
    end
    if not selectedStillExists then selectedSetID = anyEquipped end
    for index = 1, count do SetRowSelected(pane.rows[index], pane.rows[index].setID == selectedSetID) end
    for index = count + 1, #pane.rows do pane.rows[index]:Hide() end
    pane.empty:SetShown(count == 0)
    pane.scroll:SetChildHeight(Pixel.Scale(math.max(1, count * (SET.ROW_H + SET.ROW_GAP))))
    pane.scroll:UpdateScroll()
    SET.RefreshGrid(pane)
end


local LootSpec = {
    CURRENT_ICON = 132222,
    SHORT = {
        [250] = 'Blood', [251] = 'Frost', [252] = 'Unholy',
        [577] = 'Havoc', [581] = 'Veng', [1480] = 'Devour',
        [102] = 'Boomy', [103] = 'Feral', [104] = 'Guard', [105] = 'Resto',
        [1467] = 'Dev', [1468] = 'Pres', [1473] = 'Aug',
        [253] = 'BM', [254] = 'Marks', [255] = 'Surv',
        [62] = 'Arcane', [63] = 'Fire', [64] = 'Frost',
        [268] = 'Brew', [270] = 'MW', [269] = 'WW',
        [65] = 'Holy', [66] = 'Prot', [70] = 'Ret',
        [256] = 'Disc', [257] = 'Holy', [258] = 'Shadow',
        [259] = 'Sin', [260] = 'Outlaw', [261] = 'Sub',
        [262] = 'Ele', [263] = 'Enh', [264] = 'Resto',
        [265] = 'Aff', [266] = 'Demo', [267] = 'Destro',
        [71] = 'Arms', [72] = 'Fury', [73] = 'Prot',
    },
}

function LootSpec.Name()
    local lootSpecID = GetLootSpecialization()
    if lootSpecID and lootSpecID ~= 0 then
        local _, name = GetSpecializationInfoByID(lootSpecID)
        return LootSpec.SHORT[lootSpecID] or name or '?', false
    end
    local specIndex = GetSpecialization()
    local specID, name
    if specIndex then specID, name = GetSpecializationInfo(specIndex) end
    return LootSpec.SHORT[specID] or name or 'None', true
end

function LootSpec.OpenMenu(anchor)
    if InCombatLockdown() then return end
    local lootSpecID = GetLootSpecialization()
    local currentName = LootSpec.Name()
    local accentHex = BUI.Hex(Colors.GetAccent())
    local function Active(text, isActive)
        if not isActive then return text end
        return '|cff' .. accentHex .. text .. '|r'
    end
    local items = {
        { title = 'Loot Specialization' },
        {
            text = Active('Current Specialization (' .. currentName .. ')', lootSpecID == 0),
            icon = LootSpec.CURRENT_ICON,
            callback = function() SetLootSpecialization(0) end,
        },
        { separator = true },
    }
    for specIndex = 1, GetNumSpecializations() do
        local specID, name, _, icon = GetSpecializationInfo(specIndex)
        if specID then
            items[#items + 1] = {
                text = Active(name, lootSpecID == specID),
                icon = icon,
                callback = function() SetLootSpecialization(specID) end,
            }
        end
    end
    Controls.ContextMenu(items, { anchor = anchor, point = 'TOPRIGHT', relPt = 'BOTTOMRIGHT', offsetY = -4, width = 230 })
end

local function BuildStatsPane(parent)
    local pane = CreateFrame('Frame', nil, parent)
    pane:SetAllPoints()

    local stackHeight = INFO_SIZE * 4 + 6
    pane.ilvl = pane:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(pane.ilvl, BIG_ILVL_SIZE, FONT, '')
    pane.ilvl:SetJustifyH('LEFT')
    pane.ilvl:SetPoint('LEFT', pane, 'TOPLEFT', Pixel.Scale(SIDEBAR_INSET), Pixel.Scale(-(TAB_ROW_HEIGHT + 8) - stackHeight / 2 - BIG_ILVL_DROP))
    pane.ilvl:SetTextColor(BIG_ILVL_COLOR[1], BIG_ILVL_COLOR[2], BIG_ILVL_COLOR[3], 1)

    pane.ilvlInfo = { equipped = 0, total = 0, pvp = 0 }
    local ilvlHit = CreateFrame('Button', nil, pane)
    ilvlHit:SetPoint('TOPLEFT', pane.ilvl, 'TOPLEFT', 0, 0)
    ilvlHit:SetPoint('BOTTOMRIGHT', pane.ilvl, 'BOTTOMRIGHT', 0, 0)
    ilvlHit:SetScript('OnEnter', function(self)
        local info = pane.ilvlInfo
        local rows = {
            { left = 'Equipped', right = ('%.2f'):format(info.equipped), rightColor = { 1, 1, 1 } },
            { left = 'Average (bags included)', right = ('%.2f'):format(info.total), rightColor = BIG_ILVL_COLOR },
        }
        if info.pvp > 0 then rows[#rows + 1] = { left = 'PvP', right = ('%.2f'):format(info.pvp), rightColor = { 0, 0.8, 0.4 } } end
        Widget.ShowTipRows(self, 'Item Level', rows, { anchor = 'BOTTOM' })
    end)
    ilvlHit:SetScript('OnLeave', function() Widget.HideTip() end)
    pane.ilvlHit = ilvlHit

    pane.score = pane:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(pane.score, INFO_SIZE, FONT, '')
    pane.score:SetJustifyH('RIGHT')
    pane.score:SetPoint('TOPRIGHT', pane, 'TOPRIGHT', Pixel.Scale(-(SIDEBAR_INSET + STACK_RIGHT_PAD)), Pixel.Scale(-(TAB_ROW_HEIGHT + 8)))
    pane.score:SetTextColor(INFO_COLOR[1], INFO_COLOR[2], INFO_COLOR[3], 1)

    pane.pvpIlvl = pane:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(pane.pvpIlvl, INFO_SIZE, FONT, '')
    pane.pvpIlvl:SetJustifyH('RIGHT')
    pane.pvpIlvl:SetPoint('TOPRIGHT', pane.score, 'BOTTOMRIGHT', 0, Pixel.Scale(-2))
    pane.pvpIlvl:SetTextColor(INFO_COLOR[1], INFO_COLOR[2], INFO_COLOR[3], 1)

    pane.durability = pane:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(pane.durability, INFO_SIZE, FONT, '')
    pane.durability:SetJustifyH('RIGHT')
    pane.durability:SetPoint('TOPRIGHT', pane.pvpIlvl, 'BOTTOMRIGHT', 0, Pixel.Scale(-2))
    pane.durability:SetTextColor(INFO_COLOR[1], INFO_COLOR[2], INFO_COLOR[3], 1)

    local lootSpec = CreateFrame('Button', nil, pane)
    lootSpec:SetHeight(Pixel.Scale(INFO_SIZE + 2))
    lootSpec:SetWidth(Pixel.Scale(80))
    lootSpec:SetPoint('TOPRIGHT', pane.durability, 'BOTTOMRIGHT', 0, Pixel.Scale(-2))
    lootSpec.text = lootSpec:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(lootSpec.text, INFO_SIZE, FONT, '')
    lootSpec.text:SetJustifyH('RIGHT')
    lootSpec.text:SetPoint('TOPRIGHT')
    lootSpec.text:SetTextColor(INFO_COLOR[1], INFO_COLOR[2], INFO_COLOR[3], 1)
    lootSpec:SetScript('OnClick', function(self) LootSpec.OpenMenu(self) end)
    lootSpec:SetScript('OnEnter', function(self)
        self.text:SetTextColor(1, 1, 1, 1)
        Widget.ShowTip(self, 'Click to change your loot specialization', { anchor = 'LEFT' })
    end)
    lootSpec:SetScript('OnLeave', function(self)
        self.text:SetTextColor(INFO_COLOR[1], INFO_COLOR[2], INFO_COLOR[3], 1)
        Widget.HideTip()
    end)
    pane.lootSpec = lootSpec

    local headerHeight = TAB_ROW_HEIGHT + 8 + math.max(BIG_ILVL_SIZE, stackHeight) + 12
    local rowWidth = STATS_W - SIDEBAR_INSET * 2 - SCROLLBAR_W - LIST_RIGHT_PAD
    pane.area, pane.scroll = CreateScrollList(pane, headerHeight, rowWidth)
    sidebar.statsScroll = pane.scroll

    for _, definition in ipairs(STAT_SECTIONS) do
        sections[#sections + 1] = BuildSection(pane.scroll.child, definition)
    end
    return pane
end

local function BuildSidebar(parent)
    sidebar = CreateFrame('Frame', nil, parent)
    sidebar:SetPoint('TOPLEFT', parent, 'TOPLEFT', STATS_X, TOP_Y + 6)
    sidebar:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', STATS_X, SLOT_SIZE + BOTTOM_PAD + 10)
    sidebar:SetWidth(STATS_W)

    local background = sidebar:CreateTexture(nil, 'BACKGROUND')
    background:SetAllPoints()
    background:SetColorTexture(SIDEBAR_BG[1], SIDEBAR_BG[2], SIDEBAR_BG[3], SIDEBAR_BG[4])
    sidebar.panelBorder, sidebar.panelFill = Widget.RoundedPanel(sidebar, 8, { 0, 0, 0, 0 }, { 1, 1, 1, 0.08 })

    sidebar.tabs = {}
    sidebar.panes = {}
    local tabWidth = STATS_W / 3
    local definitions = { { key = 'stats', label = 'Character' }, { key = 'titles', label = 'Titles' }, { key = 'sets', label = 'Sets' } }
    for index, definition in ipairs(definitions) do
        local tab = CreateTab(sidebar, definition.label, function() ShowPane(definition.key) end)
        tab.key = definition.key
        tab:SetWidth(Pixel.Scale(tabWidth))
        tab:SetPoint('TOPLEFT', sidebar, 'TOPLEFT', Pixel.Scale((index - 1) * tabWidth), 0)
        sidebar.tabs[index] = tab
    end

    sidebar.panes.stats = BuildStatsPane(sidebar)
    sidebar.panes.titles = BuildTitlesPane(sidebar)
    sidebar.panes.sets = BuildSetsPane(sidebar)
    ShowPane('stats')
    return sidebar
end

local function RefreshHeader()
    local pane = sidebar and sidebar.panes.stats
    if not pane then return end

    local total, equipped, pvp = GetAverageItemLevel()
    if IsSecretValue(equipped) or IsSecretValue(total) then
        pane.ilvl:SetText('')
        pane.ilvlHit:EnableMouse(false)
    else
        pane.ilvl:SetFormattedText('%.2f', equipped or 0)
        pane.ilvlInfo.equipped = equipped or 0
        pane.ilvlInfo.total = total or 0
        pane.ilvlInfo.pvp = (pvp and not IsSecretValue(pvp)) and pvp or 0
        pane.ilvlHit:EnableMouse(true)
    end
    if pvp and not IsSecretValue(pvp) and pvp > 0 then
        pane.pvpIlvl:SetFormattedText('PvP iLvl: |cff00cc66%d|r', math.floor(pvp))
    else
        pane.pvpIlvl:SetText('')
    end

    local score = C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore and C_ChallengeMode.GetOverallDungeonScore() or 0
    if score and not IsSecretValue(score) and score > 0 then
        score = math.floor(score)
        pane.score:SetText('M+ Score: |cff' .. MPScoreHex(score) .. score .. '|r')
    else
        pane.score:SetText('')
    end

    local percent = DurabilityPercent()
    local red, green, blue = DurabilityColor(percent)
    pane.durability:SetFormattedText('Durability: |cff%02x%02x%02x%d%%|r', red * 255, green * 255, blue * 255, percent)

    local lootName = LootSpec.Name()
    local accentRed, accentGreen, accentBlue = Colors.GetAccent()
    pane.lootSpec.text:SetFormattedText('Loot Spec: |cff%s%s|r', BUI.Hex(accentRed, accentGreen, accentBlue), lootName)
    pane.lootSpec:SetWidth(pane.lootSpec.text:GetStringWidth() + Pixel.Scale(2))
end

local function RefreshStats()
    if not sidebar then return end
    for _, section in ipairs(sections) do
        FillSection(section)
        for index = 1, section.rowCount do
            local row = section.rows[index]
            SetStatText(row.value, row.stat.value())
            local hasPercent = row.stat.percent ~= nil
            SetStatText(row.percent, hasPercent and row.stat.percent() or '')
            row.separator:SetShown(hasPercent)
        end
    end
    LayoutSections()
end

local function MakeToggleButton(parent, options)
    local button = CreateFrame('Button', nil, parent, 'BackdropTemplate')
    button:SetSize(Pixel.Scale(28), Pixel.Scale(28))
    button:SetFrameLevel(parent:GetFrameLevel() + 5)
    button:SetBackdrop({
        bgFile   = 'Interface\\Buttons\\WHITE8x8',
        edgeFile = 'Interface\\Buttons\\WHITE8x8',
        edgeSize = 1,
    })
    button:SetBackdropColor(SLOT_BG[1], SLOT_BG[2], SLOT_BG[3], 1)
    button:SetBackdropBorderColor(unpack(TOGGLE_BORDER))

    local inset = options.inset or 2
    local texture = button:CreateTexture(nil, 'ARTWORK')
    texture:SetPoint('TOPLEFT', inset, -inset)
    texture:SetPoint('BOTTOMRIGHT', -inset, inset)
    if options.atlas then
        texture:SetAtlas(options.atlas)
    elseif options.icon then
        texture:SetTexture(options.icon)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    button:SetScript('OnEnter', function(self)
        self:SetBackdropBorderColor(Colors.GetAccent())
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:SetText(options.title, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function(self)
        self:SetBackdropBorderColor(unpack(TOGGLE_BORDER))
        GameTooltip:Hide()
    end)
    button:SetScript('OnClick', options.onClick)
    return button
end

local function RaceBackgroundPath()
    local _, fileName = UnitRace('player')
    if DressUpTexturePath then return DressUpTexturePath(fileName), fileName end
    return 'Interface/DressUpFrame/DressUpBackground-' .. (fileName or 'Orc'), fileName
end

local function BuildModelBackground(parent)
    local art = CreateFrame('Frame', nil, parent)
    local artWidth = MODEL_WIDTH + ART.BLEED * 2
    art:SetPoint('TOPLEFT', parent, 'TOPLEFT', MODEL_X - ART.BLEED, TOP_Y + 6)
    art:SetSize(artWidth, MODEL_HEIGHT)

    local mainWidth, sideWidth = artWidth * (1 - ART.SIDE_SHARE), artWidth * ART.SIDE_SHARE
    local topHeight, bottomHeight = MODEL_HEIGHT * ART.TOP_SHARE, MODEL_HEIGHT * (1 - ART.TOP_SHARE)
    local function Piece(width, height, narrow)
        local texture = art:CreateTexture(nil, 'BACKGROUND')
        texture:SetSize(width, height)
        if narrow then texture:SetTexCoord(0, ART.SIDE_COORD, 0, 1) end
        return texture
    end
    art.pieces = { Piece(mainWidth, topHeight), Piece(sideWidth, topHeight, true), Piece(mainWidth, bottomHeight), Piece(sideWidth, bottomHeight, true) }
    art.pieces[1]:SetPoint('TOPLEFT', art, 'TOPLEFT', 0, 0)
    art.pieces[2]:SetPoint('TOPLEFT', art.pieces[1], 'TOPRIGHT', 0, 0)
    art.pieces[3]:SetPoint('TOPLEFT', art.pieces[1], 'BOTTOMLEFT', 0, 0)
    art.pieces[4]:SetPoint('TOPLEFT', art.pieces[1], 'BOTTOMRIGHT', 0, 0)

    art.overlay = art:CreateTexture(nil, 'BORDER')
    art.overlay:SetAllPoints()
    art.overlay:SetColorTexture(0, 0, 0, 1)

    local edges = {}
    for edgeIndex = 1, 4 do
        edges[edgeIndex] = art:CreateTexture(nil, 'OVERLAY')
        edges[edgeIndex]:SetColorTexture(ART.MODEL_EDGE[1], ART.MODEL_EDGE[2], ART.MODEL_EDGE[3], ART.MODEL_EDGE[4])
    end
    edges[1]:SetPoint('TOPLEFT'); edges[1]:SetPoint('TOPRIGHT'); edges[1]:SetHeight(1)
    edges[2]:SetPoint('BOTTOMLEFT'); edges[2]:SetPoint('BOTTOMRIGHT'); edges[2]:SetHeight(1)
    edges[3]:SetPoint('TOPLEFT'); edges[3]:SetPoint('BOTTOMLEFT'); edges[3]:SetWidth(1)
    edges[4]:SetPoint('TOPRIGHT'); edges[4]:SetPoint('BOTTOMRIGHT'); edges[4]:SetWidth(1)

    local path, fileName = RaceBackgroundPath()
    for index = 1, 4 do art.pieces[index]:SetTexture(path .. index) end
    art.overlay:SetAlpha(ART.OVERLAY_ALPHA[strupper(fileName or '')] or ART.OVERLAY_DEFAULT)
    return art
end

local function BuildModel(parent)
    local art = BuildModelBackground(parent)

    local playerModel = CreateFrame('PlayerModel', nil, parent)
    playerModel:SetFrameLevel(art:GetFrameLevel() + 1)
    playerModel:SetSize(MODEL_WIDTH, MODEL_HEIGHT)
    playerModel:SetPoint('TOPLEFT', parent, 'TOPLEFT', MODEL_X, TOP_Y + 6)
    playerModel:SetUnit('player')
    playerModel:SetPortraitZoom(0)
    playerModel:SetCamDistanceScale(1.0)
    playerModel:SetPosition(0, 0, 0)
    playerModel:SetRotation(0)
    playerModel:EnableMouse(true)
    playerModel:EnableMouseWheel(true)
    playerModel.facing = 0
    playerModel.scale = 1.0

    playerModel:SetScript('OnMouseDown', function(self, button)
        if button == 'LeftButton' then
            self.dragStartX = GetCursorPosition()
            self.dragStartFacing = self.facing
        elseif button == 'RightButton' then
            self.facing = 0
            self.scale = 1.0
            self:SetFacing(0)
            self:SetCamDistanceScale(1.0)
            self:SetPosition(0, 0, 0)
        end
    end)
    playerModel:SetScript('OnMouseUp', function(self) self.dragStartX = nil end)
    playerModel:SetScript('OnHide', function(self) self.dragStartX = nil end)
    playerModel:SetScript('OnUpdate', function(self)
        if not self.dragStartX then return end
        local cursorX = GetCursorPosition()
        self.facing = (self.dragStartFacing or 0) + (cursorX - self.dragStartX) / 60
        self:SetFacing(self.facing)
    end)
    playerModel:SetScript('OnMouseWheel', function(self, delta)
        local newScale = self.scale + (delta > 0 and -0.1 or 0.1)
        if newScale < 0.4 then newScale = 0.4 elseif newScale > 2.0 then newScale = 2.0 end
        self.scale = newScale
        self:SetCamDistanceScale(newScale)
    end)
    return playerModel
end

local function RefreshModel()
    if not model or not frame or not frame:IsShown() then return end
    model:SetUnit('player')
    model:SetPortraitZoom(0)
    model:SetPosition(0, 0, 0)
    model:SetFacing(model.facing or 0)
    model:SetCamDistanceScale(model.scale or 1)
end

local Placement = { dragged = false }

function Placement.Mode()
    return Skin.PositionMode()
end

function Placement.Home()
    if frame then Skin.HomePosition(frame, 'characterFrame', nil, nil, nil, CharacterFrame) end
end

function Placement.OnDragStart()
    Placement.dragged = true
end

function Placement.OnDragStop()
    if Placement.Mode() == 'remember' then Skin.SavePosition(frame, 'characterFrame') end
end

function Placement.OnShow()
    if frame and CharacterFrame then Skin.ReservePanelSlot(CharacterFrame, frame:GetWidth(), frame:GetHeight()) end
    if Placement.Mode() ~= 'session' or not Placement.dragged then Placement.Home() end
end

function Placement.OnHide()
    if Placement.Mode() == 'reset' then
        Placement.Home()
        Placement.dragged = false
    end
end

local function PaintAmbience(parent)
    parent.tint = parent:CreateTexture(nil, 'BACKGROUND', nil, 1)
    parent.tint:SetPoint('TOPLEFT', Pixel.Scale(1), Pixel.Scale(-1))
    parent.tint:SetPoint('BOTTOMRIGHT', Pixel.Scale(-1), Pixel.Scale(1))
    parent.tint:SetTexture(Widget.WHITE)
    parent.tint:Hide()
    parent.panels = {}
    local function Column(left, width)
        local panel = CreateFrame('Frame', nil, parent)
        panel:SetPoint('TOPLEFT', parent, 'TOPLEFT', left, TOP_Y + 6)
        panel:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', left, SLOT_SIZE + BOTTOM_PAD + 10)
        panel:SetWidth(width)
        panel:SetFrameLevel(parent:GetFrameLevel())
        Widget.RoundedPanel(panel, 8, { 0, 0, 0, 0 }, { 1, 1, 1, 0.08 })
        parent.panels[#parent.panels + 1] = panel
    end
    Column(LEFT_X - 6, SLOT_SIZE + LABEL_ZONE_W)
    Column(RIGHT_X - LABEL_ZONE_W + 6, SLOT_SIZE + LABEL_ZONE_W)
end

local function ApplyBackground()
    if not frame or not frame.tint then return end
    local skinning = BUI.GetDB().skinning
    local tint = skinning.characterFrameTint
    if skinning.characterFrameTintEnabled and tint then
        frame.tint:SetVertexColor(tint[1] or 0.5, tint[2] or 0.5, tint[3] or 0.6, tint[4] or 0.15)
        frame.tint:Show()
    else
        frame.tint:Hide()
    end
    local showPanels = skinning.characterFramePanels == true
    for _, panel in ipairs(frame.panels or {}) do panel:SetShown(showPanels) end
    if sidebar and sidebar.panelFill then
        sidebar.panelFill:SetShown(showPanels)
        sidebar.panelBorder:SetShown(showPanels)
    end
end

local function BuildFrame()
    if frame then return true end
    if not CharacterFrame or not _G.CharacterHeadSlot then return false end

    frame = Widget.New(UIParent, 'Frame', nil, {
        bg = Colors.bg.dark,
        border = Colors.border.light,
        size = { FRAME_WIDTH, FRAME_HEIGHT },
    }).frame
    frame:SetPoint('CENTER')
    frame:SetFrameStrata('HIGH')
    frame:SetFrameLevel(FRAME_LEVEL)
    frame:Hide()

    local dragger = CreateFrame('Frame', nil, frame)
    dragger:Hide()
    local function BeginSheetDrag()
        if bagPopup then bagPopup:Hide() end
        Placement.OnDragStart()
        local scale = UIParent:GetEffectiveScale()
        local left, top = frame:GetLeft(), frame:GetTop()
        if not left or not top then return end
        local cursorX, cursorY = GetCursorPosition()
        local grabX, grabY = cursorX / scale - left, cursorY / scale - top
        dragger:SetScript('OnUpdate', function()
            local x, y = GetCursorPosition()
            local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
            local width, height = frame:GetWidth(), frame:GetHeight()
            local newLeft = math.min(math.max(x / scale - grabX, 0), screenWidth - width)
            local newTop = math.min(math.max(y / scale - grabY, height), screenHeight)
            frame:ClearAllPoints()
            frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', newLeft, newTop)
        end)
        dragger:Show()
    end
    local function EndSheetDrag()
        dragger:SetScript('OnUpdate', nil)
        dragger:Hide()
        Placement.OnDragStop()
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', BeginSheetDrag)
    frame:SetScript('OnDragStop', EndSheetDrag)
    frame:HookScript('OnHide', function() if dragger:IsShown() then EndSheetDrag() end end)
    PaintAmbience(frame)
    ApplyBackground()
    Placement.Home()

    local titleBar = Skin.CreateTitleBar(frame, UnitName('player'), HEADER.BAR_H, function()
        if CharacterFrame and CharacterFrame:IsShown() then
            HideUIPanel(CharacterFrame)
        end
    end)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag('LeftButton')
    titleBar:SetScript('OnDragStart', BeginSheetDrag)
    titleBar:SetScript('OnDragStop', EndSheetDrag)

    frame.titleText:ClearAllPoints()
    frame.titleText:SetPoint('TOPLEFT', titleBar, 'TOPLEFT', Pixel.Scale(14), Pixel.Scale(-HEADER.TOP_PAD))
    frame.subText = frame:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(frame.subText, 11, FONT, '')
    frame.subText:SetPoint('TOPLEFT', frame.titleText, 'BOTTOMLEFT', 0, Pixel.Scale(-HEADER.SUBTITLE_GAP))
    frame.subText:SetTextColor(0.55, 0.55, 0.55, 1)

    model = BuildModel(frame)

    overlay = CreateFrame('Frame', nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 8)

    BuildSidebar(frame)

    local gemButton = MakeToggleButton(frame, {
        icon    = 'Interface/Icons/INV_Misc_Gem_01',
        title   = 'Gem Manager',
        onClick = function() BUI.GemCounter.Toggle() end,
    })
    gemButton:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', Pixel.Scale(-10), Pixel.Scale(10))

    local portalButton = MakeToggleButton(frame, {
        icon    = 'Interface\\Icons\\Spell_Arcane_PortalDalaran',
        title   = 'Portals',
        onClick = function() BUI.PortalManager.Toggle() end,
    })
    portalButton:SetPoint('RIGHT', gemButton, 'LEFT', Pixel.Scale(-6), 0)

    local currencyButton = MakeToggleButton(frame, {
        icon    = 'Interface\\Icons\\INV_Misc_Coin_01',
        title   = 'Currency',
        onClick = function() BUI.CurrencyManager.Toggle() end,
    })
    currencyButton:SetPoint('RIGHT', portalButton, 'LEFT', Pixel.Scale(-6), 0)

    local reputationButton = MakeToggleButton(frame, {
        icon    = 'Interface\\Icons\\Achievement_Reputation_01',
        title   = 'Reputation',
        onClick = function() BUI.ReputationManager.Toggle() end,
    })
    reputationButton:SetPoint('RIGHT', currencyButton, 'LEFT', Pixel.Scale(-6), 0)

    PlaceSlotButtons()
    return true
end

local function UpdateSubtitle()
    if not frame or not frame.subText then return end
    frame.titleText:SetText(UnitPVPName('player') or UnitName('player'))
    local level = UnitLevel('player')
    local _, classFile = UnitClass('player')
    local className = classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] or classFile
    local specName
    local specIndex = GetSpecialization()
    if specIndex then
        local _, name = GetSpecializationInfo(specIndex)
        specName = name
    end
    local parts = {}
    if level and not IsSecretValue(level) then parts[#parts + 1] = 'Level ' .. level end
    if specName then parts[#parts + 1] = specName end
    if className then parts[#parts + 1] = className end
    frame.subText:SetText(table.concat(parts, '  '))
end

local function RefreshSlots()
    for _, info in ipairs(SLOTS) do
        local labels = slotLabels[info.id]
        if labels then RefreshSlot(labels) end
    end
end

local function RefreshAll()
    if not frame then return end
    RefreshSlots()
    RefreshBagAlternatives()
    RefreshHeader()
    RefreshStats()
    RefreshTitles()
    RefreshSets()
end

local function ShowSkin()
    if HasConflictingCharSheet() then return end
    if not BuildFrame() then return end
    UpdateSubtitle()
    Placement.OnShow()
    frame:Show()
    if model then model.facing, model.scale = 0, 1.0 end
    RefreshModel()
    RefreshAll()
end

local function HideSkin()
    if frame then frame:Hide() end
    Placement.OnHide()
    if bagPopup then bagPopup:Hide() end
end

local function IsOpen()
    return frame ~= nil and frame:IsShown()
end

local function ApplySkin()
    if not Skin.IsSkinEnabled('characterFrame') or HasConflictingCharSheet() then return end
    if InCombatLockdown() and not frame then
        BUI.Print('Character sheet opens after combat.')
        return
    end
    Skin.SuppressBlizzardFrame(CharacterFrame)
    if CharacterModelScene then
        CharacterModelScene:SetAlpha(0)
        CharacterModelScene:EnableMouse(false)
        local controlFrame = CharacterModelScene.ControlFrame
        if controlFrame then
            controlFrame:Hide()
            controlFrame:SetAlpha(0)
            controlFrame:EnableMouse(false)
            controlFrame.Show = controlFrame.Hide
            for _, child in ipairs({ controlFrame:GetChildren() }) do
                child:Hide()
                child:SetAlpha(0)
                child.Show = child.Hide
            end
        end
    end
    C_Timer.After(0, function()
        if CharacterFrame and CharacterFrame:IsShown() then ShowSkin() end
    end)
end

local function ApplyAfterCombat()
    if CharacterFrame and CharacterFrame:IsShown() and not IsOpen() then ApplySkin() end
end

BUI.Events:Register('PLAYER_LOGIN', 'Skinning.CharacterFrame', function()
    if not CharacterFrame or HasConflictingCharSheet() then return end
    CharacterFrame:HookScript('OnShow', ApplySkin)
    CharacterFrame:HookScript('OnHide', function()
        HideSkin()
        if Skin.IsSkinEnabled('characterFrame') then
            Skin.RestoreBlizzardFrame(CharacterFrame)
        end
    end)
end)

local pendingRefresh = {}

local function QueueRefresh(key, callback)
    if pendingRefresh[key] then return end
    pendingRefresh[key] = true
    C_Timer.After(0, function()
        pendingRefresh[key] = nil
        if IsOpen() then callback() end
    end)
end

local function RefreshEquipment() RefreshSlots(); RefreshHeader(); RefreshSets(); RefreshBagAlternatives(); RefreshModel() end
local function OnEquipmentChanged() QueueRefresh('equipment', RefreshEquipment) end
local function OnStatsChanged() QueueRefresh('stats', RefreshStats) end
local function OnTitlesChanged() QueueRefresh('titles', function() RefreshTitles(); UpdateSubtitle() end) end
local function OnHeaderChanged() QueueRefresh('header', RefreshHeader) end

BUI.Events:Register('PLAYER_EQUIPMENT_CHANGED',     'Skinning.CharacterFrame', OnEquipmentChanged)
BUI.Events:Register('PLAYER_AVG_ITEM_LEVEL_UPDATE', 'Skinning.CharacterFrame', OnEquipmentChanged)
BUI.Events:Register('SOCKET_INFO_UPDATE',           'Skinning.CharacterFrame', OnEquipmentChanged)
BUI.Events:Register('GET_ITEM_INFO_RECEIVED',       'Skinning.CharacterFrame', OnEquipmentChanged)
BUI.Events:Register('EQUIPMENT_SETS_CHANGED',       'Skinning.CharacterFrame', function() QueueRefresh('sets', RefreshSets) end)
BUI.Events:Register('EQUIPMENT_SWAP_FINISHED',      'Skinning.CharacterFrame', OnEquipmentChanged)
BUI.Events:Register('KNOWN_TITLES_UPDATE',          'Skinning.CharacterFrame', OnTitlesChanged)
BUI.Events:Register('UPDATE_INVENTORY_DURABILITY',  'Skinning.CharacterFrame', OnHeaderChanged)
BUI.Events:Register('CHALLENGE_MODE_COMPLETED',     'Skinning.CharacterFrame', OnHeaderChanged)
BUI.Events:Register('PLAYER_LOOT_SPEC_UPDATED', 'Skinning.CharacterFrame', OnHeaderChanged)
BUI.Events:Register('COMBAT_RATING_UPDATE',         'Skinning.CharacterFrame', OnStatsChanged)
BUI.Events:Register('PLAYER_REGEN_ENABLED',         'Skinning.CharacterFrame', function() ApplyAfterCombat(); OnStatsChanged() end)
BUI.Events:Register('PLAYER_SPECIALIZATION_CHANGED', 'Skinning.CharacterFrame', function()
    if IsOpen() then UpdateSubtitle(); RefreshStats(); RefreshHeader() end
end)
BUI.Events:RegisterUnit('UNIT_INVENTORY_CHANGED', 'player', 'Skinning.CharacterFrame', OnEquipmentChanged)
BUI.Events:RegisterUnit('UNIT_STATS', 'player', 'Skinning.CharacterFrame', OnStatsChanged)
BUI.Events:RegisterUnit('UNIT_NAME_UPDATE', 'player', 'Skinning.CharacterFrame', function() if IsOpen() then UpdateSubtitle() end end)
BUI.Events:RegisterUnit('UNIT_MODEL_CHANGED', 'player', 'Skinning.CharacterFrame', function() QueueRefresh('model', RefreshModel) end)
BUI.Events:Register('TRANSMOGRIFY_SUCCESS', 'Skinning.CharacterFrame', function() QueueRefresh('model', RefreshModel) end)
BUI.Events:Register('BAG_UPDATE_DELAYED', 'Skinning.CharacterFrame', function() QueueRefresh('bags', RefreshBagAlternatives) end)

Skin.OnToggle('characterFrame', function(enabled)
    if not enabled then
        HideSkin()
        if CharacterFrame then
            Skin.RestoreBlizzardFrame(CharacterFrame)
            Skin.ReleasePanelSlot(CharacterFrame)
        end
        BUI.Print('Character sheet skin disabled. /reload for a full visual reset.')
    elseif CharacterFrame and CharacterFrame:IsShown() then
        ApplySkin()
    end
end)

Skin.RegisterSkin('characterFrame', {
    name = 'Character Frame',
    description = 'Replaces the default character paperdoll with a dark sheet: item level, upgrade track, enchant and gem readouts beside each slot, and a sidebar with stats, titles and equipment sets.',
    icon = 'Interface\\Icons\\INV_Chest_Plate03',
    buildSettings = function(content)
        local Layout = BUILib.Layout
        local skinning = BUI.GetDB().skinning

        local background = Layout.SettingsCard(content, { title = 'Background' })
        Layout.Toggle(background, 'Outline the slot columns and sidebar', skinning.characterFramePanels == true, function(value)
            skinning.characterFramePanels = value
            ApplyBackground()
        end)
        local tint = skinning.characterFrameTint or { 0.45, 0.45, 0.6, 0.15 }
        Layout.Toggle(background, 'Tint the sheet', skinning.characterFrameTintEnabled == true, function(value)
            skinning.characterFrameTintEnabled = value
            skinning.characterFrameTint = skinning.characterFrameTint or tint
            ApplyBackground()
        end)
        Layout.ColorSwatch(background, 'Tint colour and strength', tint[1], tint[2], tint[3], tint[4], function(red, green, blue, alpha)
            skinning.characterFrameTint = { red, green, blue, alpha }
            ApplyBackground()
        end)

        background:Refresh()

        local arrows = Layout.SettingsCard(content, { title = 'Bag arrows' })
        local arrowColor, emptyColor, plateColor = BAG.Colors()
        local swatches = {}
        local function Swatch(label, color, key)
            swatches[key] = Layout.ColorSwatch(arrows, label, color[1], color[2], color[3], color[4] or 1, function(red, green, blue, alpha)
                skinning[key] = { red, green, blue, alpha }
                RefreshBagAlternatives()
            end)
        end
        Swatch('Arrow (something in bags)', arrowColor, 'characterFrameArrow')
        Swatch('Arrow (nothing in bags)', emptyColor, 'characterFrameArrowEmpty')
        Swatch('Plate behind the arrow', plateColor, 'characterFrameArrowPlate')
        Layout.ButtonRow(arrows, { buttons = { { text = 'Reset arrow colours', width = 150, callback = function()
            skinning.characterFrameArrow, skinning.characterFrameArrowEmpty, skinning.characterFrameArrowPlate = nil, nil, nil
            local arrow, empty, plate = BAG.Colors()
            swatches.characterFrameArrow:SetColor(arrow[1], arrow[2], arrow[3], arrow[4])
            swatches.characterFrameArrowEmpty:SetColor(empty[1], empty[2], empty[3], empty[4])
            swatches.characterFrameArrowPlate:SetColor(plate[1], plate[2], plate[3], plate[4])
            RefreshBagAlternatives()
        end } } })
        arrows:Refresh()
    end,
})
