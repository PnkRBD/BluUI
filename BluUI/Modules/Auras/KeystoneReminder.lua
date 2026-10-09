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
local WIDTH, HEIGHT = 260, 62
local PAD = 10
local PORTAL_SIZE = 42
local LEVEL_SIZE = 13
local PREVIEW_LEVEL = 12
local FULL_PARTY = 5
local PREVIEW_SIZE = 3
local LEAVE_SETTLE = 1
local FILLING_TEXT = 'MYTHIC+  ·  FILLING %d/%d'
local FULL_TEXT = 'MYTHIC+  ·  GROUP FULL'
local TEXT_GAP = 10
local CLOSE_SIZE = 14
local CARD_RADIUS = 8
local SOLID = { 1, 1, 1, 1 }
local ROLE_MARKUP = '|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:12:12:0:0:64:64:%d:%d:%d:%d|t '
local ROLE_COORDS = {
    TANK    = { 0, 19, 22, 41 },
    HEALER  = { 20, 39, 1, 20 },
    DAMAGER = { 20, 39, 22, 41 },
}
local ROLE_NAMES = { TANK = 'Tank', HEALER = 'Healer', DAMAGER = 'DPS' }
local KEYSTONE_ICON = 'Interface\\Icons\\INV_Relics_Hourglass'
local READY_TEXT = 'Click to teleport'
local COOLDOWN_TEXT = 'Teleport on cooldown'
local UNLEARNED_TEXT = 'Teleport not learned'
local IsSecret = BUI.Tools.IsSecretValue
local PartyKeys = BUI.PartyKeys

local card, current, group, dismissed, lockListener

local function GetDB() return BUI.GetDB().keystoneReminder end

local function Apply()
    BUI.Anchor.ApplyPosition(card, GetDB())
end

local function PlayerRole()
    local role = UnitGroupRolesAssigned('player')
    if role == 'NONE' then
        local spec = GetSpecialization()
        role = spec and GetSpecializationRole(spec)
    end
    return role
end

local function FindDungeon(activityName)
    for _, mapID in ipairs(C_ChallengeMode.GetMapTable()) do
        local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
        if name and activityName:find(name, 1, true) then return name, texture, mapID end
    end
end

local function PaintPortalEdge(portal, hovered)
    portal:SetBackdropBorderColor(BUI.ThemeColor(hovered and 'accent' or 'edge'))
end

local function BuildPortal(parent)
    local portal = CreateFrame('Button', nil, parent, 'SecureActionButtonTemplate, BackdropTemplate')
    portal:SetSize(Pixel.Scale(PORTAL_SIZE), Pixel.Scale(PORTAL_SIZE))
    portal:SetPoint('LEFT', Pixel.Scale(PAD), 0)
    Pixel.SetTemplate(portal, 0, 0, 0, 1, 0, 0, 0, 1, 1)
    portal:RegisterForClicks('LeftButtonUp')
    portal:SetAttribute('type', 'spell')
    portal:SetAttribute('useOnKeyDown', false)
    portal._keepMouseForTooltip = true
    local inset = Pixel.PixelSize(1)
    portal.icon = portal:CreateTexture(nil, 'ARTWORK')
    portal.icon:SetPoint('TOPLEFT', inset, -inset)
    portal.icon:SetPoint('BOTTOMRIGHT', -inset, inset)
    portal.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    portal.cooldown = CreateFrame('Cooldown', nil, portal, 'CooldownFrameTemplate')
    portal.cooldown:SetAllPoints(portal.icon)
    portal.cooldown:SetDrawEdge(false)
    portal.cooldown:SetHideCountdownNumbers(false)
    local overlay = CreateFrame('Frame', nil, portal)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(portal.cooldown:GetFrameLevel() + 1)
    portal.level = overlay:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(portal.level, LEVEL_SIZE, FONT, 'OUTLINE')
    portal.level:SetPoint('BOTTOMRIGHT', Pixel.Scale(-2), Pixel.Scale(2))
    portal:SetScript('OnEnter', BUI.Profiler.Script('Auras.KeystoneReminder portal OnEnter', function(self)
        PaintPortalEdge(self, true)
        if not self._spellID then return end
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:SetSpellByID(self._spellID)
        GameTooltip:Show()
    end))
    portal:SetScript('OnLeave', BUI.Profiler.Script('Auras.KeystoneReminder portal OnLeave', function(self)
        PaintPortalEdge(self, false)
        GameTooltip:Hide()
    end))
    return portal
end

local function CardText(size)
    local text = card:CreateFontString(nil, 'OVERLAY')
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

    card.portal = BuildPortal(card)

    local close = Controls.Icon(card, { preset = 'close', size = CLOSE_SIZE, onClick = Dismiss })
    close:SetPoint('TOPRIGHT', Pixel.Scale(-8), Pixel.Scale(-8))
    Widget.Unwrap(close)._keepMouseForTooltip = true

    local textLeft = Pixel.Scale(TEXT_GAP)
    local textRight = Pixel.Scale(-(PAD + CLOSE_SIZE + 6))

    card.kicker = CardText(10)
    card.kicker:SetPoint('TOPLEFT', card.portal, 'TOPRIGHT', textLeft, 0)
    card.kicker:SetPoint('RIGHT', textRight, 0)

    card.name = CardText(14)
    card.name:SetPoint('LEFT', card.portal, 'RIGHT', textLeft, Pixel.Scale(1))
    card.name:SetPoint('RIGHT', textRight, 0)

    card.meta = CardText(11)
    card.meta:SetPoint('BOTTOMLEFT', card.portal, 'BOTTOMRIGHT', textLeft, 0)
    card.meta:SetPoint('RIGHT', Pixel.Scale(-PAD), 0)

    card:EnableMouse(true)
    BUI.Dragging.MakeDraggable(card, {
        skipClickThrough = true,
        onRightClick = Dismiss,
        onPositionChanged = function() BUI.Anchor.SaveDrop(card, GetDB()) end,
    })
    Apply()
end

local function PaintCard()
    card.fill:SetVertexColor(BUI.ThemeColor('page'))
    card.edge:SetVertexColor(BUI.ThemeColor('edge'))
    card.name:SetTextColor(BUI.ThemeColor('text'))
    card.meta:SetTextColor(BUI.ThemeColor('muted'))
    PaintPortalEdge(card.portal, card.portal:IsMouseOver())
end

local function PaintCooldown()
    local portal = card.portal
    local info = portal._known and C_Spell.GetSpellCooldown(portal._spellID)
    if not info or IsSecret(info.isActive) or IsSecret(info.isOnGCD) then return end
    portal._cooling = info.isActive and not info.isOnGCD
    if portal._cooling then
        portal.cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(portal._spellID))
    else
        portal.cooldown:Clear()
    end
end

local function SetPortal(spellID, texture)
    local portal = card.portal
    local known = spellID ~= nil and C_SpellBook.IsSpellInSpellBook(spellID)
    portal._spellID, portal._known, portal._cooling = spellID, known, false
    portal.cooldown:Clear()
    portal.icon:SetTexture(spellID and C_Spell.GetSpellTexture(spellID) or texture or KEYSTONE_ICON)
    portal.icon:SetDesaturated(spellID ~= nil and not known)
    PaintCooldown()
    BUI.Events:AfterCombat(function()
        portal:SetAttribute('spell', known and spellID or nil)
    end, 'KeystoneReminder.Portal')
end

local function PortalStatus()
    local portal = card.portal
    if not portal._spellID then return nil end
    if not portal._known then return UNLEARNED_TEXT end
    return portal._cooling and COOLDOWN_TEXT or READY_TEXT
end

local function PaintMeta()
    local playerRole = PlayerRole()
    local coords = ROLE_COORDS[playerRole]
    local role = coords and (ROLE_MARKUP:format(coords[1], coords[2], coords[3], coords[4]) .. ROLE_NAMES[playerRole])
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

local function OnCooldown()
    PaintCooldown()
    PaintMeta()
end

local function PaintStatus()
    local size = current.size or math.max(1, math.min(GetNumGroupMembers(), FULL_PARTY))
    local full = size >= FULL_PARTY
    card.kicker:SetText(full and FULL_TEXT or FILLING_TEXT:format(size, FULL_PARTY))
    card.kicker:SetTextColor(BUI.ThemeColor(full and 'positive' or 'accent'))
end

local function SyncCard()
    card:SetShown(current ~= nil)
end

local function Paint(info)
    PaintCard()
    PaintStatus()
    card.name:SetText(info.dungeon or info.activity)
    SetPortal(info.spellID, info.texture)
    PaintMeta()
    PaintLevel()
end

function KeystoneReminder.Show(info)
    Build()
    current = info
    Paint(info)
    BUI.Events:AfterCombat(SyncCard, CARD_KEY)
    BUI.Events:Register('SPELL_UPDATE_COOLDOWN', COOLDOWN_KEY, OnCooldown)
    if not info.level and info.mapID then
        PartyKeys.Listen(EVENT_KEY, PaintLevel)
        PartyKeys.Request()
    end
end

function KeystoneReminder.Hide()
    current = nil
    BUI.Events:Unregister('SPELL_UPDATE_COOLDOWN', COOLDOWN_KEY)
    PartyKeys.Listen(EVENT_KEY, nil)
    if card then BUI.Events:AfterCombat(SyncCard, CARD_KEY) end
end

function KeystoneReminder.ShowPreview()
    local dungeon = BUI.PortalData.seasons[1].dungeons[1].name
    local _, texture, mapID = FindDungeon(dungeon)
    KeystoneReminder.Show({ dungeon = dungeon, texture = texture, mapID = mapID, level = PREVIEW_LEVEL, size = PREVIEW_SIZE, spellID = BUI.PortalManager.TeleportSpell(dungeon) })
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

local function Sync()
    if not GetDB().locked then return end
    if not group or group.fullName == dismissed or InDungeon() then
        if current then KeystoneReminder.Hide() end
    elseif not current or current.activity ~= group.fullName then
        ShowFor(group)
    else
        PaintMeta()
        PaintStatus()
        if not current.level and current.mapID then PartyKeys.Request() end
    end
end

local function Remember(activity)
    if not activity then return end
    group = activity
    Sync()
end

local function OnJoined(_, resultID)
    Remember(ResultActivity(resultID))
end

local function OnListing()
    local entry = C_LFGList.GetActiveEntryInfo()
    Remember(entry and MythicPlusActivity(entry.activityIDs[1]))
end

local function OnRoster()
    if group then
        Sync()
    elseif C_LFGList.HasActiveEntryInfo() then
        OnListing()
    end
end

local function Forget()
    group, dismissed = nil, nil
    Sync()
end

local function OnWorld()
    if InDungeon() then Forget() end
end

local function Settle()
    if IsInGroup() or C_LFGList.HasActiveEntryInfo() then return end
    Forget()
end

local function OnGroupLeft()
    BUI.Profiler.After('Auras.KeystoneReminder group left', LEAVE_SETTLE, Settle)
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
    OnListing()
end

function KeystoneReminder.Disable()
    BUI.Events:UnregisterAll(EVENT_KEY)
    group, dismissed = nil, nil
    KeystoneReminder.Hide()
end

function KeystoneReminder.SetLockListener(callback)
    lockListener = callback
end

function KeystoneReminder.SetLocked(locked)
    local db = GetDB()
    db.locked = locked
    if lockListener then lockListener() end
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
end

BUI.Events:OnLogin('KeystoneReminder', function()
    if GetDB().enabled then KeystoneReminder.Enable() end
end, 'auras')
