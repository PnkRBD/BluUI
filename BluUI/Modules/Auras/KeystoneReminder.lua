local _, BUI = ...
local Pixel = BUI.Pixel

local BUILib = BluUI.BUILibClient
local Widget = BUILib.Widget
local Controls = BUILib.Controls
local Colors = BUILib.Colors
local FONT = BUILib.Font

local KeystoneReminder = {}
BUI.Auras.KeystoneReminder = KeystoneReminder

local FRAME_NAME = 'BUI_KeystoneReminder'
local EVENT_KEY = 'KeystoneReminder'
local ROSTER_KEY = 'KeystoneReminder.Roster'
local CARD_KEY = 'KeystoneReminder.Card'
local WIDTH, HEIGHT = 250, 64
local PAD = 8
local SLOT_SIZE = 30
local ROLE_SIZE = 14
local ROLE_TEXTURE = 'Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES'
local ROLE_COORDS = {
    TANK    = { 0, 19 / 64, 22 / 64, 41 / 64 },
    HEALER  = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
local ROLE_NAMES = { TANK = 'Tank', HEALER = 'Healer', DAMAGER = 'DPS' }
local KEYSTONE_ICON = 'Interface\\Icons\\INV_Relics_Hourglass'

local card, current, lockListener

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

local function MakeSlot(parent)
    local slot = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
    slot:SetSize(Pixel.Scale(SLOT_SIZE), Pixel.Scale(SLOT_SIZE))
    Pixel.SetTemplate(slot, 0, 0, 0, 1, 0.15, 0.15, 0.15, 1, 1)
    return slot
end

local function FillSlot(slot)
    local inset = Pixel.PixelSize(1)
    local icon = slot:CreateTexture(nil, 'ARTWORK')
    icon:SetPoint('TOPLEFT', inset, -inset)
    icon:SetPoint('BOTTOMRIGHT', -inset, inset)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return icon
end

local function BuildPortal(parent)
    local portal = CreateFrame('Button', nil, parent, 'SecureActionButtonTemplate, BackdropTemplate')
    portal:SetSize(Pixel.Scale(SLOT_SIZE), Pixel.Scale(SLOT_SIZE))
    portal:SetPoint('BOTTOMRIGHT', Pixel.Scale(-PAD), Pixel.Scale(PAD))
    Pixel.SetTemplate(portal, 0, 0, 0, 1, 0.15, 0.15, 0.15, 1, 1)
    portal:RegisterForClicks('LeftButtonUp')
    portal:SetAttribute('type', 'spell')
    portal:SetAttribute('useOnKeyDown', false)
    portal._keepMouseForTooltip = true
    portal.icon = FillSlot(portal)
    portal:SetScript('OnEnter', BUI.Profiler.Script('Auras.KeystoneReminder portal OnEnter', function(self)
        self:SetBackdropBorderColor(Colors.GetAccent())
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:SetSpellByID(self._spellID)
        GameTooltip:Show()
    end))
    portal:SetScript('OnLeave', BUI.Profiler.Script('Auras.KeystoneReminder portal OnLeave', function(self)
        self:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
        GameTooltip:Hide()
    end))
    return portal
end

local function Build()
    if card then return end
    card = CreateFrame('Frame', FRAME_NAME, UIParent, 'BackdropTemplate')
    card:SetSize(Pixel.Scale(WIDTH), Pixel.Scale(HEIGHT))
    card:SetFrameStrata('HIGH')
    BUI.Skinning.ApplyBackdrop(card, Colors.bg.dark, Colors.border.light)
    card:Hide()

    card.title = card:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(card.title, 11, FONT, '')
    card.title:SetPoint('TOPLEFT', Pixel.Scale(PAD), Pixel.Scale(-6))
    card.title:SetTextColor(Colors.GetAccent())
    card.title:SetText('Mythic+ group joined')

    local close = Controls.Icon(card, { preset = 'close', size = 16, onClick = function() KeystoneReminder.Hide() end })
    close:SetPoint('TOPRIGHT', Pixel.Scale(-4), Pixel.Scale(-4))
    Widget.Unwrap(close)._keepMouseForTooltip = true

    local slot = MakeSlot(card)
    slot:SetPoint('BOTTOMLEFT', Pixel.Scale(PAD), Pixel.Scale(PAD))
    card.icon = FillSlot(slot)

    card.portal = BuildPortal(card)

    card.name = card:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(card.name, 12, FONT, '')
    card.name:SetPoint('TOPLEFT', slot, 'TOPRIGHT', Pixel.Scale(8), Pixel.Scale(-1))
    card.name:SetPoint('RIGHT', card.portal, 'LEFT', Pixel.Scale(-8), 0)
    card.name:SetJustifyH('LEFT')
    card.name:SetWordWrap(false)

    card.roleIcon = card:CreateTexture(nil, 'ARTWORK')
    card.roleIcon:SetSize(Pixel.Scale(ROLE_SIZE), Pixel.Scale(ROLE_SIZE))
    card.roleIcon:SetPoint('BOTTOMLEFT', slot, 'BOTTOMRIGHT', Pixel.Scale(8), Pixel.Scale(1))
    card.roleIcon:SetTexture(ROLE_TEXTURE)

    card.role = card:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(card.role, 11, FONT, '')
    card.role:SetPoint('LEFT', card.roleIcon, 'RIGHT', Pixel.Scale(4), 0)
    card.role:SetTextColor(0.7, 0.7, 0.7, 1)

    BUI.Dragging.MakeAnchoredAlert(card, {
        settings = GetDB,
        isLocked = function() return GetDB().locked end,
        onRightClick = function() KeystoneReminder.SetLocked(true) end,
    })
    Apply()
end

local function SetPortal(spellID)
    local portal = card.portal
    portal._spellID = spellID
    local known = spellID and C_SpellBook.IsSpellInSpellBook(spellID)
    if spellID then
        portal.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
        portal.icon:SetDesaturated(not known)
    end
    BUI.Events:AfterCombat(function()
        portal:SetAttribute('spell', known and spellID or nil)
        portal:SetShown(spellID ~= nil)
    end, 'KeystoneReminder.Portal')
end

local function PaintRole()
    local role = PlayerRole()
    local coords = ROLE_COORDS[role]
    card.roleIcon:SetShown(coords ~= nil)
    if coords then card.roleIcon:SetTexCoord(unpack(coords)) end
    card.role:SetText(ROLE_NAMES[role] or '')
end

local function SyncCard()
    card:SetShown(current ~= nil)
end

local function Paint(info)
    card.name:SetText(info.dungeon or info.activity)
    card.icon:SetTexture(info.texture or KEYSTONE_ICON)
    PaintRole()
    SetPortal(info.spellID)
end

function KeystoneReminder.Show(info)
    Build()
    current = info
    Paint(info)
    BUI.Events:AfterCombat(SyncCard, CARD_KEY)
    BUI.Events:Register('GROUP_ROSTER_UPDATE', ROSTER_KEY, PaintRole)
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
    BUI.Dragging.SetLocked(card, locked)
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
    BUI.Dragging.SetLocked(card, db.locked)
end

BUI.Events:OnLogin('KeystoneReminder', function()
    if GetDB().enabled then KeystoneReminder.Enable() end
end, 'auras')
