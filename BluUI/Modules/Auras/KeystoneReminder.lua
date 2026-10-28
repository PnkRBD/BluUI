local _, BUI = ...
local Pixel = BUI.Pixel

local BUILib = BluUI.BUILibClient
local Widget = BUILib.Widget
local Controls = BUILib.Controls
local FONT = BUILib.Font

local KeystoneReminder = {}
BUI.Auras.KeystoneReminder = KeystoneReminder

local FRAME_NAME = 'BUI_KeystoneReminder'
local EVENT_KEY = 'KeystoneReminder'
local COOLDOWN_KEY = 'KeystoneReminder.Cooldown'
local CARD_KEY = 'KeystoneReminder.Card'
local PORTAL_KEY = 'KeystoneReminder.Portal.'
local WIDTH, HEIGHT = 260, 62
local PAD = 10
local PORTAL_SIZE = 42
local ROW_HEIGHT = 32
local ROW_PORTAL = 26
local ROWS_TOP = 8
local ROW_HOVER_INSET = 4
local ROW_HOVER_TRIM = 1
local ROW_HOVER_RADIUS = 6
local ROW_HOVER_ALPHA = 0.08
local ROW_STATUS_SIZE = 10
local ROW_READY_TEXT = 'Ready'
local ROW_COOLDOWN_TEXT = 'On cooldown'
local ROW_UNLEARNED_TEXT = 'Not learned'
local TEST_PARTY = {
    { name = 'Brickwall', class = 'WARRIOR', role = 'TANK', level = 15 },
    { name = 'Lightmender', class = 'PRIEST', role = 'HEALER', level = 14 },
    { name = 'Pyrobelle', class = 'MAGE', role = 'DAMAGER', level = 12 },
    { name = 'Shadowfang', class = 'ROGUE', role = 'DAMAGER' },
}
local LEVEL_SIZE = 13
local ROW_LEVEL_SIZE = 11
local PREVIEW_LEVEL = 12
local FULL_PARTY = 5
local PREVIEW_SIZE = 3
local PREVIEW_CLASSES = { 'WARRIOR', 'PRIEST', 'MAGE' }
local LEAVE_SETTLE = 1
local KEYS_SETTLE = 3
local KEYS_RETRIES = 3
local FILLING_TEXT = 'MYTHIC+  ·  FILLING %d/%d'
local FULL_TEXT = 'MYTHIC+  ·  GROUP FULL'
local COMPLETE_TEXT = 'MYTHIC+  ·  KEY COMPLETE'
local NO_KEY_NAME = 'No key yet'
local NO_KEY_TEXT = 'No key'
local PARTY_ACTIVITY = 'party'
local TEXT_GAP = 10
local ROW_GAP = 8
local CLOSE_SIZE = 14
local CARD_RADIUS = 8
local SOLID = { 1, 1, 1, 1 }
local EMPTY = {}
local ROLE_MARKUP = '|A:%s:12:12|a '
local ROLE_ATLAS = {
    TANK    = 'UI-LFG-RoleIcon-Tank-Micro-Raid',
    HEALER  = 'UI-LFG-RoleIcon-Healer-Micro-Raid',
    DAMAGER = 'UI-LFG-RoleIcon-DPS-Micro-Raid',
}
local ROLE_NAMES = { TANK = 'Tank', HEALER = 'Healer', DAMAGER = 'DPS' }
local KEYSTONE_ICON = 'Interface\\Icons\\INV_Relics_Hourglass'
local READY_TEXT = 'Click to teleport'
local COOLDOWN_TEXT = 'Teleport on cooldown'
local UNLEARNED_TEXT = 'Teleport not learned'
local PartyKeys = BUI.PartyKeys

local card, current, group, dismissed, keyDone
local ShowParty

local function GetDB() return BUI.GetDB().keystoneReminder end

local function Apply()
    BUI.Anchor.ApplyPosition(card, GetDB())
end

local function PlayerRole()
    local role = UnitGroupRolesAssigned('player')
    if role == 'NONE' then
        local spec = C_SpecializationInfo.GetSpecialization()
        role = spec and GetSpecializationRole(spec)
    end
    return role
end

local FindDungeon = BUI.Tools.ChallengeMapForActivity

local function MapInfo(mapID)
    if not mapID then return nil end
    local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
    return name, texture
end

local function PaintPortalEdge(portal, hovered)
    portal:SetBackdropBorderColor(BUI.ThemeColor(hovered and 'accent' or 'edge'))
end

local function BuildPortal(parent, size, id, host)
    local portal
    if host then
        portal = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
    else
        portal = CreateFrame('Button', nil, parent, 'SecureActionButtonTemplate, BackdropTemplate')
    end
    local button = host or portal
    portal:SetSize(Pixel.Scale(size), Pixel.Scale(size))
    Pixel.SetTemplate(portal, 0, 0, 0, 1, 0, 0, 0, 1, 1)
    button:RegisterForClicks('LeftButtonUp')
    button:SetAttribute('type', 'spell')
    button:SetAttribute('useOnKeyDown', false)
    button._keepMouseForTooltip = true
    portal.button = button
    portal._combatKey = PORTAL_KEY .. id
    local inset = Pixel.PixelSize(1)
    portal.icon = portal:CreateTexture(nil, 'ARTWORK')
    portal.icon:SetPoint('TOPLEFT', inset, -inset)
    portal.icon:SetPoint('BOTTOMRIGHT', -inset, inset)
    portal.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    portal.cooldown = CreateFrame('Cooldown', nil, portal, 'CooldownFrameTemplate')
    portal.cooldown:SetAllPoints(portal.icon)
    portal.cooldown:SetDrawEdge(false)
    portal.cooldown:SetHideCountdownNumbers(false)
    local countdown = portal.cooldown:GetCountdownFontString()
    Pixel.ApplyFont(countdown, LEVEL_SIZE, FONT, 'OUTLINE')
    countdown:ClearAllPoints()
    countdown:SetPoint('TOP', 0, Pixel.Scale(-3))
    local overlay = CreateFrame('Frame', nil, portal)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(portal.cooldown:GetFrameLevel() + 1)
    portal.level = overlay:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(portal.level, LEVEL_SIZE, FONT, 'OUTLINE')
    portal.level:SetPoint('BOTTOMRIGHT', Pixel.Scale(-2), Pixel.Scale(2))
    button:SetScript('OnEnter', function()
        PaintPortalEdge(portal, true)
        if button.hover then button.hover:Show() end
        if not portal._spellID then return end
        GameTooltip:SetOwner(portal, 'ANCHOR_TOP')
        GameTooltip:SetSpellByID(portal._spellID)
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function()
        PaintPortalEdge(portal, false)
        if button.hover then button.hover:Hide() end
        GameTooltip:Hide()
    end)
    return portal
end

local function CardText(parent, size)
    local text = parent:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(text, size, FONT, '')
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    return text
end

local function Dismiss()
    dismissed = current and current.activity
    KeystoneReminder.SetLocked(true)
end

local function Build()
    if card then return end
    card = CreateFrame('Frame', FRAME_NAME, UIParent)
    card:SetSize(Pixel.Scale(WIDTH), Pixel.Scale(HEIGHT))
    card:SetFrameStrata('HIGH')
    card.fill, card.edge = Widget.DrawCardShape(card, CARD_RADIUS, SOLID, SOLID, 'BACKGROUND', 0, 0)
    card:Hide()

    card.portal = BuildPortal(card, PORTAL_SIZE, 'main')
    card.portal:SetPoint('TOPLEFT', Pixel.Scale(PAD), -Pixel.Scale(PAD))
    card.rows = {}

    local close = Controls.Icon(card, { preset = 'close', size = CLOSE_SIZE, onClick = Dismiss })
    close:SetPoint('TOPRIGHT', Pixel.Scale(-8), Pixel.Scale(-8))
    Widget.Unwrap(close)._keepMouseForTooltip = true

    local textLeft = Pixel.Scale(TEXT_GAP)
    local textRight = Pixel.Scale(-(PAD + CLOSE_SIZE + 6))

    card.kicker = CardText(card, 10)
    card.kicker:SetPoint('TOPLEFT', card.portal, 'TOPRIGHT', textLeft, 0)
    card.kicker:SetPoint('RIGHT', textRight, 0)

    card.name = CardText(card, 14)
    card.name:SetPoint('LEFT', card.portal, 'RIGHT', textLeft, Pixel.Scale(1))
    card.name:SetPoint('RIGHT', textRight, 0)

    card.meta = CardText(card, 11)
    card.meta:SetPoint('BOTTOMLEFT', card.portal, 'BOTTOMRIGHT', textLeft, 0)
    card.meta:SetPoint('RIGHT', Pixel.Scale(-PAD), 0)

    card.divider = card:CreateTexture(nil, 'ARTWORK')
    card.divider:SetPoint('TOPLEFT', Pixel.Scale(PAD), -Pixel.Scale(HEIGHT))
    card.divider:SetPoint('TOPRIGHT', -Pixel.Scale(PAD), -Pixel.Scale(HEIGHT))
    card.divider:SetHeight(Pixel.PixelSize(1))
    card.divider:SetColorTexture(1, 1, 1, 1)
    card.divider:Hide()

    card:EnableMouse(true)
    BUI.Dragging.MakeDraggable(card, {
        skipClickThrough = true,
        onRightClick = Dismiss,
        onPositionChanged = function() BUI.Anchor.SaveDrop(card, GetDB()) end,
    })
end

local function BuildRow(index)
    local row = CreateFrame('Button', nil, card, 'SecureActionButtonTemplate')
    row:SetSize(Pixel.Scale(WIDTH - PAD * 2), Pixel.Scale(ROW_HEIGHT))
    row:SetPoint('TOPLEFT', card, 'TOPLEFT', Pixel.Scale(PAD), -Pixel.Scale(HEIGHT + ROWS_TOP + (index - 1) * ROW_HEIGHT))

    local hover, hoverEdge = Widget.DrawCardShape(row, ROW_HOVER_RADIUS, SOLID, SOLID, 'BACKGROUND', 0, 0)
    hoverEdge:Hide()
    hover:ClearAllPoints()
    hover:SetPoint('TOPLEFT', -Pixel.Scale(ROW_HOVER_INSET), -Pixel.Scale(ROW_HOVER_TRIM))
    hover:SetPoint('BOTTOMRIGHT', Pixel.Scale(ROW_HOVER_INSET), Pixel.Scale(ROW_HOVER_TRIM))
    hover:Hide()
    row.hover = hover


    row.portal = BuildPortal(row, ROW_PORTAL, index, row)
    row.portal:SetPoint('LEFT')
    Pixel.ApplyFont(row.portal.level, ROW_LEVEL_SIZE, FONT, 'OUTLINE')

    row.status = CardText(row, ROW_STATUS_SIZE)
    row.status:SetJustifyH('RIGHT')
    row.status:SetPoint('RIGHT', -Pixel.Scale(2), 0)

    local textLeft = Pixel.Scale(ROW_GAP)
    local textRight = -Pixel.Scale(ROW_GAP)
    row.name = CardText(row, 11)
    row.name:SetPoint('TOPLEFT', row.portal, 'TOPRIGHT', textLeft, 0)
    row.name:SetPoint('RIGHT', row.status, 'LEFT', textRight, 0)

    row.key = CardText(row, 10)
    row.key:SetPoint('BOTTOMLEFT', row.portal, 'BOTTOMRIGHT', textLeft, 0)
    row.key:SetPoint('RIGHT', row.status, 'LEFT', textRight, 0)
    return row
end

local function PaintCard()
    card.fill:SetVertexColor(BUI.ThemeColor('page'))
    card.edge:SetVertexColor(BUI.ThemeColor('edge'))
    card.name:SetTextColor(BUI.ThemeColor('text'))
    card.meta:SetTextColor(BUI.ThemeColor('muted'))
    card.divider:SetVertexColor(BUI.ThemeColor('edge'))
    PaintPortalEdge(card.portal, card.portal:IsMouseOver())
end

local function PaintCooldown(portal)
    local info = portal._known and C_Spell.GetSpellCooldown(portal._spellID)
    if not info then return false end
    local cooling = info.isActive and not info.isOnGCD
    if cooling == portal._cooling then return false end
    portal._cooling = cooling
    if cooling then
        portal.cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(portal._spellID))
    else
        portal.cooldown:Clear()
    end
    return true
end

local function SetPortal(portal, spellID, texture)
    local known = spellID ~= nil and C_SpellBook.IsSpellInSpellBook(spellID)
    portal._spellID, portal._known, portal._cooling = spellID, known, false
    portal.cooldown:Clear()
    portal.icon:SetTexture(spellID and C_Spell.GetSpellTexture(spellID) or texture or KEYSTONE_ICON)
    portal.icon:SetDesaturated(spellID ~= nil and not known)
    PaintPortalEdge(portal, portal:IsMouseOver())
    PaintCooldown(portal)
    BUI.Events:AfterCombat(function()
        portal.button:SetAttribute('spell', known and spellID or nil)
    end, portal._combatKey)
end

local function PortalStatus()
    local portal = card.portal
    if not portal._spellID then return nil end
    if not portal._known then return UNLEARNED_TEXT end
    return portal._cooling and COOLDOWN_TEXT or READY_TEXT
end

local function RowStatus(portal)
    if not portal._spellID then return '' end
    if not portal._known then return ROW_UNLEARNED_TEXT end
    return portal._cooling and ROW_COOLDOWN_TEXT or ROW_READY_TEXT
end

local function RoleMarkup(role)
    local atlas = ROLE_ATLAS[role]
    return atlas and ROLE_MARKUP:format(atlas) or ''
end

local function PaintMeta()
    local playerRole = PlayerRole()
    local role = ROLE_NAMES[playerRole] and (RoleMarkup(playerRole) .. ROLE_NAMES[playerRole])
    local status = PortalStatus()
    if role and status then
        card.meta:SetText(role .. '  ·  ' .. status)
    else
        card.meta:SetText(role or status or '')
    end
end

local function PaintLevel()
    local level = current.level or (current.mapID and PartyKeys.LevelFor(current.mapID))
    card.portal.level:SetText(level and ('+' .. level) or '')
end

local function UnitKey(unit)
    local key = PartyKeys.ForUnit(unit)
    local level = key and key.level or 0
    if level > 0 then return key.mapID, level end
end

local function PartyEntries(skipUnit)
    local entries = {}
    for _, unit in ipairs(PartyKeys.UNITS) do
        if unit ~= skipUnit and UnitExists(unit) then
            local mapID, level = UnitKey(unit)
            local classFile = select(2, UnitClass(unit))
            entries[#entries + 1] = {
                name = UnitName(unit),
                class = not issecretvalue(classFile) and classFile or nil,
                role = UnitGroupRolesAssigned(unit),
                level = level,
                mapID = mapID,
            }
        end
    end
    return entries
end

local function GroupKey()
    local bestMap, bestLevel, bestUnit
    for _, unit in ipairs(PartyKeys.UNITS) do
        if UnitExists(unit) then
            local mapID, level = UnitKey(unit)
            if level then
                if UnitIsGroupLeader(unit) then return mapID, level, unit end
                if not bestLevel or level > bestLevel then bestMap, bestLevel, bestUnit = mapID, level, unit end
            end
        end
    end
    local ownMap, ownLevel = UnitKey('player')
    if ownMap then return ownMap, ownLevel, 'player' end
    return bestMap, bestLevel, bestUnit
end

local function HeaderStale()
    if current.activity ~= PARTY_ACTIVITY then return false end
    local mapID, level, unit = GroupKey()
    return mapID ~= current.mapID or level ~= current.level or unit ~= current.keyUnit
end

local function PaintRow(row, entry)
    local dungeon, texture = MapInfo(entry.mapID)
    local color = entry.class and RAID_CLASS_COLORS[entry.class]
    local name = entry.name or ''
    if issecretvalue(name) then
        row.name:SetText(name)
    else
        row.name:SetText(RoleMarkup(entry.role) .. name)
    end
    if color then
        row.name:SetTextColor(color.r, color.g, color.b)
    else
        row.name:SetTextColor(BUI.ThemeColor('text'))
    end
    row.key:SetText(dungeon or NO_KEY_TEXT)
    row.key:SetTextColor(BUI.ThemeColor('muted'))
    local red, green, blue = BUI.ThemeColor('text')
    row.hover:SetVertexColor(red, green, blue, ROW_HOVER_ALPHA)
    SetPortal(row.portal, dungeon and BUI.PortalManager.TeleportSpell(dungeon), texture)
    row.portal.level:SetText(entry.level and ('+' .. entry.level) or '')
    row.status:SetText(RowStatus(row.portal))
    row.status:SetTextColor(BUI.ThemeColor('muted'))
    row:Show()
end

local function PaintRows()
    local entries = current.party or (BUI.PortalManager.ShowsPartyKeys() and PartyEntries(current.keyUnit)) or EMPTY
    for index, entry in ipairs(entries) do
        local row = card.rows[index]
        if not row then
            row = BuildRow(index)
            card.rows[index] = row
        end
        PaintRow(row, entry)
    end
    for index = #entries + 1, #card.rows do card.rows[index]:Hide() end
    local count = #entries
    card.divider:SetShown(count > 0)
    local extra = count > 0 and (ROWS_TOP + count * ROW_HEIGHT + PAD) or 0
    card:SetSize(Pixel.Scale(WIDTH), Pixel.Scale(HEIGHT + extra))
end

local function OnCooldown()
    if PaintCooldown(card.portal) then PaintMeta() end
    for _, row in ipairs(card.rows) do
        if row:IsShown() and PaintCooldown(row.portal) then row.status:SetText(RowStatus(row.portal)) end
    end
end

local function PaintStatus()
    if keyDone and current.activity == PARTY_ACTIVITY then
        card.kicker:SetText(COMPLETE_TEXT)
        card.kicker:SetTextColor(BUI.ThemeColor('positive'))
        return
    end
    local size = current.size or math.max(1, math.min(GetNumGroupMembers(), FULL_PARTY))
    local full = size >= FULL_PARTY
    card.kicker:SetText(full and FULL_TEXT or FILLING_TEXT:format(size, FULL_PARTY))
    card.kicker:SetTextColor(BUI.ThemeColor(full and 'positive' or 'accent'))
end

local function SyncCard()
    card:SetShown(current ~= nil)
end

local function OnKeys()
    if not current then return end
    if HeaderStale() then
        ShowParty()
        return
    end
    PaintLevel()
    PaintRows()
end

local function WantsKeys()
    return current.activity == PARTY_ACTIVITY or BUI.PortalManager.ShowsPartyKeys() or (not current.level and current.mapID ~= nil)
end

local function Paint(info)
    PaintCard()
    PaintStatus()
    card.name:SetText(info.dungeon or info.activity)
    SetPortal(card.portal, info.spellID, info.texture)
    PaintMeta()
    PaintLevel()
    PaintRows()
end

function KeystoneReminder.Show(info)
    Build()
    current = info
    Paint(info)
    BUI.Events:AfterCombat(SyncCard, CARD_KEY)
    BUI.Events:Register('SPELL_UPDATE_COOLDOWN', COOLDOWN_KEY, OnCooldown)
    if not info.party and WantsKeys() then
        PartyKeys.Listen(EVENT_KEY, OnKeys)
        PartyKeys.Request()
    end
end

function KeystoneReminder.Hide()
    current = nil
    BUI.Events:Unregister('SPELL_UPDATE_COOLDOWN', COOLDOWN_KEY)
    PartyKeys.Listen(EVENT_KEY, nil)
    if card then BUI.Events:AfterCombat(SyncCard, CARD_KEY) end
end

local function PreviewParty()
    local maps = C_ChallengeMode.GetMapTable()
    local party = {}
    for index, classFile in ipairs(PREVIEW_CLASSES) do
        party[index] = {
            name = 'Party member ' .. index,
            class = classFile,
            role = index == 1 and 'TANK' or index == 2 and 'HEALER' or 'DAMAGER',
            level = PREVIEW_LEVEL - index,
            mapID = maps[index + 1],
        }
    end
    return party
end

function KeystoneReminder.ShowPreview()
    local dungeon = BUI.PortalData.seasons[1].dungeons[1].name
    local _, texture, mapID = FindDungeon(dungeon)
    KeystoneReminder.Show({
        dungeon = dungeon,
        texture = texture,
        mapID = mapID,
        level = PREVIEW_LEVEL,
        size = PREVIEW_SIZE,
        spellID = BUI.PortalManager.TeleportSpell(dungeon),
        party = BUI.PortalManager.ShowsPartyKeys() and PreviewParty() or EMPTY,
    })
end

local function MythicPlusActivity(activityID)
    local activity = activityID and C_LFGList.GetActivityInfoTable(activityID)
    if activity and activity.isMythicPlusActivity then return activity end
end

local function ResultActivity(resultID)
    local result = C_LFGList.GetSearchResultInfo(resultID)
    return result and MythicPlusActivity(result.activityIDs[1])
end

local function InDungeon()
    return select(2, IsInInstance()) == 'party'
end

local function Busy()
    local inInstance = IsInInstance()
    return inInstance and not (keyDone and InDungeon())
end

local function KeyAlreadyDone()
    if C_ChallengeMode.GetChallengeCompletionInfo then
        local info = C_ChallengeMode.GetChallengeCompletionInfo()
        return (info and info.mapChallengeModeID or 0) > 0
    end
    if C_ChallengeMode.GetCompletionInfo then
        return (C_ChallengeMode.GetCompletionInfo() or 0) > 0
    end
    return false
end

local function ShowFor(activity)
    local dungeon, texture, mapID = FindDungeon(activity.fullName)
    KeystoneReminder.Show({
        dungeon = dungeon,
        mapID = mapID,
        activity = activity.fullName,
        texture = texture,
        spellID = dungeon and BUI.PortalManager.TeleportSpell(dungeon),
    })
end

ShowParty = function()
    local mapID, level, unit = GroupKey()
    local dungeon, texture = MapInfo(mapID)
    KeystoneReminder.Show({
        dungeon = dungeon or NO_KEY_NAME,
        mapID = mapID,
        level = level,
        keyUnit = unit,
        activity = PARTY_ACTIVITY,
        texture = texture,
        spellID = dungeon and BUI.PortalManager.TeleportSpell(dungeon),
    })
end

local function Repaint()
    if HeaderStale() then
        ShowParty()
        return
    end
    PaintMeta()
    PaintStatus()
    PaintRows()
    if WantsKeys() then PartyKeys.Request() end
end

local function KeyGroup()
    if IsInRaid() then return false end
    if keyDone then return true end
    return IsInGroup() and GroupKey() ~= nil
end

local function WantedActivity()
    if Busy() then return nil end
    if group and group.fullName ~= dismissed then return group.fullName end
    if KeyGroup() and dismissed ~= PARTY_ACTIVITY then return PARTY_ACTIVITY end
end

local function Sync()
    if not GetDB().locked then return end
    if current and current.test then return end
    local wanted = WantedActivity()
    if not wanted then
        if current then KeystoneReminder.Hide() end
    elseif not current or current.activity ~= wanted then
        if wanted == PARTY_ACTIVITY then ShowParty() else ShowFor(group) end
    else
        Repaint()
    end
end

local function Remember(activity)
    if not activity then return end
    group = activity
    Sync()
end

local function Forget()
    group, dismissed = nil, nil
    Sync()
end

local function OnJoined(_, resultID)
    Remember(ResultActivity(resultID))
end

local function OnListing(_, created)
    local entry = C_LFGList.GetActiveEntryInfo()
    if entry then
        if created then dismissed = nil end
        Remember(MythicPlusActivity(entry.activityIDs[1]))
    elseif not IsInGroup() then
        Forget()
    else
        group = nil
        Sync()
    end
end

local function OnRoster()
    if not group and C_LFGList.HasActiveEntryInfo() then
        OnListing()
    else
        Sync()
    end
end

local function OnWorld()
    if InDungeon() then
        keyDone = KeyAlreadyDone()
        Forget()
    else
        Sync()
    end
end

local function OnKeyStart()
    keyDone = false
    Sync()
end

local function SettleKeys(remaining)
    if not current then return end
    if WantsKeys() then PartyKeys.Request() end
    OnKeys()
    if remaining > 0 and current and current.activity == PARTY_ACTIVITY and not current.mapID then
        C_Timer.After(KEYS_SETTLE, function() SettleKeys(remaining - 1) end)
    end
end

local function OnKeyDone()
    keyDone = true
    dismissed = nil
    Sync()
    C_Timer.After(KEYS_SETTLE, function() SettleKeys(KEYS_RETRIES) end)
end

local function Settle()
    if IsInGroup() or C_LFGList.HasActiveEntryInfo() then return end
    Forget()
end

local function OnGroupLeft()
    C_Timer.After(LEAVE_SETTLE, Settle)
end

function KeystoneReminder.Enable()
    Build()
    Apply()
    C_MythicPlus.RequestMapInfo()
    BUI.Events:Register('LFG_LIST_JOINED_GROUP', EVENT_KEY, OnJoined)
    BUI.Events:Register('LFG_LIST_ACTIVE_ENTRY_UPDATE', EVENT_KEY, OnListing)
    BUI.Events:Register('GROUP_ROSTER_UPDATE', EVENT_KEY, OnRoster)
    BUI.Events:Register('GROUP_LEFT', EVENT_KEY, OnGroupLeft)
    BUI.Events:Register('PLAYER_ENTERING_WORLD', EVENT_KEY, OnWorld)
    BUI.Events:Register('CHALLENGE_MODE_START', EVENT_KEY, OnKeyStart)
    BUI.Events:Register('CHALLENGE_MODE_COMPLETED', EVENT_KEY, OnKeyDone)
    BUI.Events:Register('BAG_UPDATE_DELAYED', EVENT_KEY, OnKeys)
    if InDungeon() then keyDone = KeyAlreadyDone() end
    OnListing()
    Sync()
end

function KeystoneReminder.Disable()
    BUI.Events:UnregisterAll(EVENT_KEY)
    group, dismissed, keyDone = nil, nil, false
    KeystoneReminder.Hide()
end

function KeystoneReminder.SetLocked(locked)
    local db = GetDB()
    db.locked = locked
    BUI.NotifyModuleChange('keystoneReminder')
    if not db.enabled then return end
    Build()
    Apply()
    if locked then
        KeystoneReminder.Hide()
        Sync()
    else
        KeystoneReminder.ShowPreview()
    end
end

function KeystoneReminder.Refresh()
    local db = GetDB()
    if not db.enabled then
        KeystoneReminder.Disable()
        return
    end
    KeystoneReminder.Enable()
    if not db.locked then KeystoneReminder.ShowPreview() end
end

function KeystoneReminder.ToggleTest()
    if current and current.test then
        KeystoneReminder.Hide()
        Sync()
        BUI.Print('Keystone reminder test hidden.')
        return
    end
    Build()
    Apply()
    local maps = C_ChallengeMode.GetMapTable()
    local party = {}
    for index, member in ipairs(TEST_PARTY) do
        party[index] = {
            name = member.name,
            class = member.class,
            role = member.role,
            level = member.level,
            mapID = member.level and maps[index] or nil,
        }
    end
    local dungeon, texture = MapInfo(maps[#maps])
    KeystoneReminder.Show({
        dungeon = dungeon or NO_KEY_NAME,
        mapID = maps[#maps],
        level = PREVIEW_LEVEL + 3,
        size = FULL_PARTY,
        texture = texture,
        spellID = dungeon and BUI.PortalManager.TeleportSpell(dungeon),
        party = party,
        test = true,
    })
    BUI.Print('Keystone reminder test shown. Run /bui party again to hide it.')
end

function KeystoneReminder.Debug()
    local db = GetDB()
    local entry = C_LFGList.GetActiveEntryInfo()
    local activity = entry and C_LFGList.GetActivityInfoTable(entry.activityIDs[1])
    local mapID, level, unit = GroupKey()
    BUI.Print(('Keystone reminder: enabled %s, locked %s, party keys %s'):format(tostring(db.enabled), tostring(db.locked), tostring(BUI.PortalManager.ShowsPartyKeys())))
    BUI.Print(('Listing: %s (mythic+ %s), remembered %s, dismissed %s'):format(activity and activity.fullName or 'none', tostring(activity and activity.isMythicPlusActivity), group and group.fullName or 'none', tostring(dismissed)))
    BUI.Print(('Group %s, raid %s, instance %s, key done %s, busy %s'):format(tostring(IsInGroup()), tostring(IsInRaid()), tostring((IsInInstance())), tostring(keyDone), tostring(Busy())))
    BUI.Print(('Group key: %s +%s from %s, wanted %s, showing %s'):format(mapID and (MapInfo(mapID) or mapID) or 'none', tostring(level), tostring(unit), tostring(WantedActivity()), tostring(current and current.activity)))
    for _, member in ipairs(PartyKeys.UNITS) do
        if UnitExists(member) then
            local memberMap, memberLevel = UnitKey(member)
            BUI.Print(('  %s: %s +%s'):format(tostring(UnitName(member)), memberMap and (MapInfo(memberMap) or memberMap) or 'no key', tostring(memberLevel)))
        end
    end
end

BUI.Events:OnLogin('KeystoneReminder', function()
    if GetDB().enabled then KeystoneReminder.Enable() end
end, 'auras')
