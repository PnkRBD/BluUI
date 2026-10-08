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
local ROSTER_KEY = 'KeystoneReminder.Roster'
local CARD_KEY = 'KeystoneReminder.Card'
local WIDTH, HEIGHT = 260, 62
local PAD = 10
local PORTAL_SIZE = 42
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
local UNLEARNED_TEXT = 'Teleport not learned'

local card, current, portalStatus, lockListener

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
        if name and activityName:find(name, 1, true) then return name, texture end
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

local function Build()
    if card then return end
    card = CreateFrame('Frame', FRAME_NAME, UIParent)
    card:SetSize(Pixel.Scale(WIDTH), Pixel.Scale(HEIGHT))
    card:SetFrameStrata('HIGH')
    card.fill, card.edge = Widget.DrawCardShape(card, CARD_RADIUS, SOLID, SOLID, 'BACKGROUND', 0, 0)
    card:Hide()

    card.portal = BuildPortal(card)

    local close = Controls.Icon(card, { preset = 'close', size = CLOSE_SIZE, onClick = function() KeystoneReminder.Hide() end })
    close:SetPoint('TOPRIGHT', Pixel.Scale(-8), Pixel.Scale(-8))
    Widget.Unwrap(close)._keepMouseForTooltip = true

    local textLeft = Pixel.Scale(TEXT_GAP)
    local textRight = Pixel.Scale(-(PAD + CLOSE_SIZE + 6))

    card.kicker = CardText(10)
    card.kicker:SetPoint('TOPLEFT', card.portal, 'TOPRIGHT', textLeft, 0)
    card.kicker:SetPoint('RIGHT', textRight, 0)
    card.kicker:SetText('MYTHIC+ GROUP JOINED')

    card.name = CardText(14)
    card.name:SetPoint('LEFT', card.portal, 'RIGHT', textLeft, Pixel.Scale(1))
    card.name:SetPoint('RIGHT', textRight, 0)

    card.meta = CardText(11)
    card.meta:SetPoint('BOTTOMLEFT', card.portal, 'BOTTOMRIGHT', textLeft, 0)
    card.meta:SetPoint('RIGHT', Pixel.Scale(-PAD), 0)

    card:EnableMouse(true)
    BUI.Dragging.MakeDraggable(card, {
        skipClickThrough = true,
        onRightClick = function() KeystoneReminder.SetLocked(true) end,
        onPositionChanged = function() BUI.Anchor.SaveDrop(card, GetDB()) end,
    })
    Apply()
end

local function PaintCard()
    card.fill:SetVertexColor(BUI.ThemeColor('page'))
    card.edge:SetVertexColor(BUI.ThemeColor('edge'))
    card.kicker:SetTextColor(BUI.ThemeColor('accent'))
    card.name:SetTextColor(BUI.ThemeColor('text'))
    card.meta:SetTextColor(BUI.ThemeColor('muted'))
    PaintPortalEdge(card.portal, card.portal:IsMouseOver())
end

local function SetPortal(spellID, texture)
    local portal = card.portal
    portal._spellID = spellID
    local known = spellID ~= nil and C_SpellBook.IsSpellInSpellBook(spellID)
    portal.icon:SetTexture(spellID and C_Spell.GetSpellTexture(spellID) or texture or KEYSTONE_ICON)
    portal.icon:SetDesaturated(spellID ~= nil and not known)
    portalStatus = spellID and (known and READY_TEXT or UNLEARNED_TEXT)
    BUI.Events:AfterCombat(function()
        portal:SetAttribute('spell', known and spellID or nil)
    end, 'KeystoneReminder.Portal')
end

local function PaintMeta()
    local playerRole = PlayerRole()
    local coords = ROLE_COORDS[playerRole]
    local role = coords and (ROLE_MARKUP:format(coords[1], coords[2], coords[3], coords[4]) .. ROLE_NAMES[playerRole])
    if role and portalStatus then
        card.meta:SetText(role .. '  ·  ' .. portalStatus)
    else
        card.meta:SetText(role or portalStatus or '')
    end
end

local function SyncCard()
    card:SetShown(current ~= nil)
end

local function Paint(info)
    PaintCard()
    card.name:SetText(info.dungeon or info.activity)
    SetPortal(info.spellID, info.texture)
    PaintMeta()
end

function KeystoneReminder.Show(info)
    Build()
    current = info
    Paint(info)
    BUI.Events:AfterCombat(SyncCard, CARD_KEY)
    BUI.Events:Register('GROUP_ROSTER_UPDATE', ROSTER_KEY, PaintMeta)
end

function KeystoneReminder.Hide()
    current = nil
    BUI.Events:Unregister('GROUP_ROSTER_UPDATE', ROSTER_KEY)
    if card then BUI.Events:AfterCombat(SyncCard, CARD_KEY) end
end

function KeystoneReminder.ShowPreview()
    local dungeon = BUI.PortalData.seasons[1].dungeons[1].name
    local _, texture = FindDungeon(dungeon)
    KeystoneReminder.Show({ dungeon = dungeon, texture = texture, spellID = BUI.PortalManager.TeleportSpell(dungeon) })
end

local function OnJoined(_, resultID)
    if select(2, IsInInstance()) == 'party' then return end
    local result = C_LFGList.GetSearchResultInfo(resultID)
    if not result then return end
    local activity = C_LFGList.GetActivityInfoTable(result.activityIDs[1])
    if not activity or not activity.isMythicPlusActivity then return end
    local dungeon, texture = FindDungeon(activity.fullName)
    KeystoneReminder.Show({
        dungeon = dungeon,
        activity = activity.fullName,
        texture = texture,
        spellID = dungeon and BUI.PortalManager.TeleportSpell(dungeon),
    })
end

local function OnWorld()
    if current and select(2, IsInInstance()) == 'party' then KeystoneReminder.Hide() end
end

function KeystoneReminder.Enable()
    Build()
    Apply()
    C_MythicPlus.RequestMapInfo()
    BUI.Events:Register('LFG_LIST_JOINED_GROUP', EVENT_KEY, OnJoined)
    BUI.Events:Register('GROUP_LEFT', EVENT_KEY, KeystoneReminder.Hide)
    BUI.Events:Register('PLAYER_ENTERING_WORLD', EVENT_KEY, OnWorld)
end

function KeystoneReminder.Disable()
    BUI.Events:UnregisterAll(EVENT_KEY)
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
