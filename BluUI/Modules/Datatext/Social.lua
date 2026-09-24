local _, BUI = ...

local Datatext = BUI.Datatext
local Pixel = BUI.Pixel
local BUILib = LibStub('BUILib')
local Controls = BUILib.Controls
local LibMedia = BUILib.GetLibMedia

local socialPanel, socialRows = nil, {}
local keystoneData = {}
local keystoneRegistered = false
local function GetSortState()
    local profile = BUI.GetDB()
    local sortState = profile.datatextSortState
    if not sortState then
        sortState = {}
        profile.datatextSortState = sortState
    end
    return sortState
end
local guildFactionMap = {}
local guildFactionTime = 0

local SOCIAL_ROW_HEIGHT = 20
local SOCIAL_MAX_ROWS = 10

local SOCIAL_CHILD_GUTTER  = 12
local SOCIAL_CLIP_INSET    = 8
local SOCIAL_PANEL_INSET   = 12
local SOCIAL_MAX_CONTENT   = 520

local NAME_COLUMN = 2
local GUILD_COLS  = { { columnLeft = 4, columnWidth = 16 }, { columnLeft = 22, columnWidth = 96 }, { columnLeft = 122, columnWidth = 24, numeric = true }, { columnLeft = 150, columnWidth = 110 } }
local FRIEND_COLS = { { columnLeft = 4, columnWidth = 16 }, { columnLeft = 22, columnWidth = 96 }, { columnLeft = 122, columnWidth = 24, numeric = true }, { columnLeft = 150, columnWidth = 110 }, { columnLeft = 264, columnWidth = 60 } }
local GUILD_HEADERS  = { '', 'Name', 'Lvl', 'Zone' }
local FRIEND_HEADERS = { '', 'Name', 'Lvl', 'Zone', 'Game' }

local FRIEND_TAG_COLS = { { columnLeft = 4, columnWidth = 16 }, { columnLeft = 22, columnWidth = 96 }, { columnLeft = 122, columnWidth = 24, numeric = true }, { columnLeft = 150, columnWidth = 110 }, { columnLeft = 264, columnWidth = 96 }, { columnLeft = 364, columnWidth = 60 } }
local FRIEND_TAG_HEADERS = { '', 'Name', 'Lvl', 'Zone', 'BattleTag', 'Game' }
local BATTLETAG_COLOR = { 0.55, 0.55, 0.6 }
local FAVORITE_COLOR = { 1, 0.82, 0 }
local FRIEND_TAG_MIN_WIDTH = 96
local FRIEND_TAG_MAX_WIDTH = 200
local TOOLTIP_SEPARATOR = '  |cff5a5a62|||r  '

local GUILD_EXTRA_X = 264
local GUILD_RANK_WIDTH  = 74
local GUILD_SCORE_WIDTH = 46

local function GuildTooltipShows()
    local profile = BUI.GetDB()
    return profile.guildTooltipScore ~= false, profile.guildTooltipRanks == true
end

local function ShowBattleTag()
    return BUI.GetDB().socialShowBattleTag ~= false
end

local function FriendColumns()
    if ShowBattleTag() then return FRIEND_TAG_COLS, FRIEND_TAG_HEADERS end
    return FRIEND_COLS, FRIEND_HEADERS
end

local function PanelFont() return BUI.GetGlobalFont() end

local function FitColumn(panel, specs, labels, columnIndex, minWidth, maxWidth)
    local measureText = panel.measureString or panel:CreateFontString(nil, 'OVERLAY')
    panel.measureString = measureText
    Pixel.ApplyFont(measureText, 11, PanelFont())

    local widest = 0
    measureText:SetText(labels[columnIndex] or '')
    widest = measureText:GetStringWidth()
    for _, entry in ipairs(panel.data) do
        local cell = entry.cols[columnIndex]
        if cell and cell.text and cell.text ~= '' then
            measureText:SetText(cell.text)
            local cellWidth = measureText:GetStringWidth()
            if cellWidth > widest then widest = cellWidth end
        end
    end

    local fitted = math.ceil(widest) + 8
    if fitted < minWidth then fitted = minWidth end
    if fitted > maxWidth then fitted = maxWidth end
    if fitted == specs[columnIndex].columnWidth then return specs end

    local shift = fitted - specs[columnIndex].columnWidth
    local resized = {}
    for index = 1, #specs do
        local spec = specs[index]
        resized[index] = { columnLeft = spec.columnLeft, columnWidth = spec.columnWidth, numeric = spec.numeric }
        if index == columnIndex then resized[index].columnWidth = fitted
        elseif index > columnIndex then resized[index].columnLeft = spec.columnLeft + shift end
    end
    return resized
end

local function FriendCells(factionCell, nameCell, levelCell, zoneCell, tagCell, gameCell)
    if ShowBattleTag() then
        return { factionCell, nameCell, levelCell, zoneCell, tagCell, gameCell }
    end
    return { factionCell, nameCell, levelCell, zoneCell, gameCell }
end

local function SocialColumns(kind)
    local specs  = (kind == 'guild') and GUILD_COLS or FRIEND_COLS
    local labels = (kind == 'guild') and GUILD_HEADERS or FRIEND_HEADERS
    if kind ~= 'guild' then return FriendColumns() end
    local wantScore, wantRank = GuildTooltipShows()
    if not wantScore and not wantRank then return specs, labels end
    local extendedSpecs, extendedLabels = {}, {}
    for columnIndex = 1, #specs do extendedSpecs[columnIndex], extendedLabels[columnIndex] = specs[columnIndex], labels[columnIndex] end
    local columnLeft = GUILD_EXTRA_X
    if wantRank then
        extendedSpecs[#extendedSpecs + 1] = { columnLeft = columnLeft, columnWidth = GUILD_RANK_WIDTH }
        extendedLabels[#extendedLabels + 1] = 'Rank'
        columnLeft = columnLeft + GUILD_RANK_WIDTH + 4
    end
    if wantScore then
        extendedSpecs[#extendedSpecs + 1] = { columnLeft = columnLeft, columnWidth = GUILD_SCORE_WIDTH, numeric = true }
        extendedLabels[#extendedLabels + 1] = 'M+'
    end
    return extendedSpecs, extendedLabels
end

local function SocialWidths(specs)
    local contentRight = 0
    for columnIndex = 1, #specs do
        local spec = specs[columnIndex]
        if spec then
            local right = spec.columnLeft + spec.columnWidth
            if right > contentRight then contentRight = right end
        end
    end
    local childWidth     = contentRight + SOCIAL_CHILD_GUTTER
    local containerWidth = childWidth + SOCIAL_CLIP_INSET
    local panelWidth     = containerWidth + SOCIAL_PANEL_INSET
    return panelWidth, containerWidth, childWidth
end

local FACTION_LETTER = {
    Horde    = { 'H', 0.90, 0.30, 0.30 },
    Alliance = { 'A', 0.36, 0.58, 0.92 },
}

local function FactionLabel(factionGroup)
    if factionGroup == 'Horde' then return '|cffe35a5a' .. FACTION_HORDE .. '|r'
    elseif factionGroup == 'Alliance' then return '|cff5a8fe6' .. FACTION_ALLIANCE .. '|r' end
end

local STATUS_TAG = {
    AFK = '|cffff9900AFK|r',
    DND = '|cffff3333DND|r',
}

local function FactionCell(factionGroup)
    local letterInfo = FACTION_LETTER[factionGroup or '']
    if letterInfo then return { text = letterInfo[1], color = { letterInfo[2], letterInfo[3], letterInfo[4] } } end
    return { text = '' }
end

local function ZoneText(zone, status)
    local tag = status and STATUS_TAG[status]
    zone = zone or ''
    if not tag then return zone end
    if zone ~= '' then return tag .. '  ' .. zone end
    return tag
end

local function BestKeyText(level, dungeon)
    if not level or level <= 0 then return nil end
    local name = dungeon and (dungeon.shortNameLocale or dungeon.shortName or dungeon.name)
    if type(name) == 'string' and name ~= '' then return '+' .. level .. ' ' .. name end
    return '+' .. level
end

local function RIOLookup(name, realm)
    local raiderIO = _G.RaiderIO
    if not raiderIO or not raiderIO.GetProfile or not name or name == '' then return end
    if not realm or realm == '' then
        local baseName, realmName = name:match('^(.-)%-(.+)$')
        if baseName then name, realm = baseName, realmName else realm = GetRealmName() end
    end
    local profile = raiderIO.GetProfile(name, realm)
    if type(profile) ~= 'table' then return end
    local keystoneProfile = profile.mythicKeystoneProfile
    if not keystoneProfile or not keystoneProfile.currentScore then return end
    local score = math.floor(keystoneProfile.currentScore + 0.5)
    local color
    if raiderIO.GetScoreColor then
        local scoreRed, scoreGreen, scoreBlue = raiderIO.GetScoreColor(score)
        if scoreRed then color = { scoreRed, scoreGreen, scoreBlue } end
    end
    return score, color, BestKeyText(keystoneProfile.maxDungeonLevel, keystoneProfile.maxDungeon)
end

local function ScoreColor(score)
    local raiderIO = _G.RaiderIO
    if score and raiderIO and raiderIO.GetScoreColor then
        local red, green, blue = raiderIO.GetScoreColor(score)
        if red then return { red, green, blue } end
    end
    return { 0.62, 0.51, 0.93 }
end

local function KeyText(level, mapID)
    if not level or level <= 0 then return nil end
    local name = mapID and mapID > 0 and C_ChallengeMode.GetMapUIInfo(mapID)
    if type(name) == 'string' and name ~= '' then return '+' .. level .. ' ' .. name end
    return '+' .. level
end

local function GuildScore(name)
    local keystone = keystoneData[name]
    if keystone and keystone.score and keystone.score > 0 then
        local best = (keystone.level and keystone.level > 0) and KeyText(keystone.level, keystone.mapID) or nil
        return keystone.score, ScoreColor(keystone.score), best
    end
    return RIOLookup(name)
end

local CLIENT_NAMES = {
    WoW = 'WoW', WoWC = 'WoW Classic', App = 'App', BSAp = 'Mobile',
    D3 = 'Diablo III', OSI = 'Diablo IV', WTCG = 'Hearthstone',
    Pro = 'Overwatch', S1 = 'StarCraft', S2 = 'StarCraft II',
    Hero = 'Heroes', DST2 = 'Destiny 2', GRY = 'Warcraft III',
}
local function ClientName(code)
    if not code or code == '' then return 'App' end
    return CLIENT_NAMES[code] or code
end

local CLASS_TOKEN = {}
do
    local function AddClassNames(nameTable) if nameTable then for token, name in pairs(nameTable) do CLASS_TOKEN[name] = token end end end
    AddClassNames(LOCALIZED_CLASS_NAMES_MALE)
    AddClassNames(LOCALIZED_CLASS_NAMES_FEMALE)
end
local function ClassColor(className)
    local token = className and CLASS_TOKEN[className]
    local classColor = token and RAID_CLASS_COLORS[token]
    if classColor then return { classColor.r, classColor.g, classColor.b } end
end

local function WhisperMember(member)
    if member.isBNet and member.bnetName then
        ChatFrameUtil.SendBNetTell(member.bnetName)
    elseif member.name then
        ChatFrameUtil.SendTell(member.name)
    end
end

local function InviteMember(member)
    if member.name then
        C_PartyInfo.InviteUnit(member.name)
    elseif member.isBNet and member.gameAccountID then
        BNInviteFriend(member.gameAccountID)
    end
end

local function WhoMember(member)
    local name = member.name
    if not name then return end
    name = name:match('(.-)%-') or name
    C_FriendList.SendWho('n-"' .. name .. '"')
end

local function RefreshGuildFactions()
    wipe(guildFactionMap)
    local clubId = C_Club.GetGuildClubId()
    if not clubId then return end
    local ids = C_Club.GetClubMembers(clubId)
    if not ids or BUI.Tools.IsSecretValue(ids) then return end
    for _, memberID in ipairs(ids) do
        local memberInfo = C_Club.GetMemberInfo(clubId, memberID)
        local guid = memberInfo and memberInfo.guid
        if guid and not BUI.Tools.IsSecretValue(guid) then
            local factionValue = memberInfo.faction
            if BUI.Tools.IsSecretValue(factionValue) then factionValue = nil end
            local factionGroup = (factionValue == 1 and 'Alliance') or (factionValue == 0 and 'Horde') or nil
            if not factionGroup and memberInfo.race then
                local factionInfo = C_CreatureInfo.GetFactionInfo(memberInfo.race)
                factionGroup = factionInfo and factionInfo.groupTag or nil
            end
            guildFactionMap[guid] = factionGroup
        end
    end
end

local groupFactions = {}

local function SnapshotGroup()
    wipe(groupFactions)
    if not (IsInGroup() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then return end
    local prefix, count = 'party', 4
    if IsInRaid() then prefix, count = 'raid', 40 end
    for unitIndex = 1, count do
        local unit = prefix .. unitIndex
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid and not BUI.Tools.IsSecretValue(guid) then
                local factionGroup = UnitFactionGroup(unit)
                if factionGroup and not BUI.Tools.IsSecretValue(factionGroup) then groupFactions[guid] = factionGroup end
            end
        end
    end
end

local function GatherGuild()
    local list = {}
    if not IsInGuild() then return list end
    local playerFaction = UnitFactionGroup('player')
    local now = GetTime()
    if now - guildFactionTime > 10 then RefreshGuildFactions(); guildFactionTime = now end
    SnapshotGroup()
    local playerGUID = UnitGUID('player')
    local wantScore, wantRank = GuildTooltipShows()
    for memberIndex = 1, GetNumGuildMembers() do
        local name, rankName, rankIndex, level, _, zone, _, _, online, status, classFile, _, _, _, _, _, guid = GetGuildRosterInfo(memberIndex)
        if online and name then
            local shortName = name:match('(.-)%-') or name
            local classColor = classFile and RAID_CLASS_COLORS[classFile]
            local faction = groupFactions[guid] or guildFactionMap[guid] or (guid == playerGUID and playerFaction) or nil
            local statusText = ((status == 1 or status == '<AFK>') and 'AFK')
                or ((status == 2 or status == '<DND>') and 'DND') or nil
            local score, scoreColor, best = GuildScore(name)
            local columns = {
                FactionCell(faction),
                { text = shortName, color = classColor and { classColor.r, classColor.g, classColor.b } },
                { text = level and tostring(level) or '' },
                { text = ZoneText(zone, statusText), color = { 0.45, 0.82, 0.45 } },
            }
            if wantRank then
                columns[#columns + 1] = { text = rankName or '', sortValue = rankIndex }
            end
            if wantScore then
                columns[#columns + 1] = { text = score and tostring(score) or '', color = scoreColor }
            end
            list[#list + 1] = {
                member = { name = name, classFile = classFile, faction = faction, status = statusText,
                    rioScore = score, rioScoreColor = scoreColor, rioBest = best },
                sortName = shortName,
                cols = columns,
            }
        end
    end
    return list
end

local function GatherFriends()
    local list = {}
    local playerFaction = UnitFactionGroup('player')
    for friendIndex = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(friendIndex)
        if info and info.connected then
            local statusText = (info.afk and 'AFK') or (info.dnd and 'DND') or nil
            local shownName = info.name or '?'
            list[#list + 1] = {
                member = {
                    name = info.name,
                    classFile = info.className and CLASS_TOKEN[info.className],
                    faction = playerFaction,
                    status = statusText,
                },
                sortName = shownName,
                cols = FriendCells(
                    FactionCell(playerFaction),
                    { text = shownName, color = ClassColor(info.className) or { 0.51, 0.77, 1 } },
                    { text = (info.level and info.level > 0) and tostring(info.level) or '' },
                    { text = ZoneText(info.area, statusText), color = { 0.45, 0.82, 0.45 } },
                    { text = '' },
                    { text = 'WoW', color = { 0.0, 0.69, 0.94 } }
                ),
            }
        end
    end
    for battleNetIndex = 1, BNGetNumFriends() do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(battleNetIndex)
        local gameAccount = accountInfo and accountInfo.gameAccountInfo
        if gameAccount and gameAccount.isOnline then
            local bnetName = accountInfo.accountName or '?'
            local battleTagText = accountInfo.battleTag or bnetName
            if gameAccount.clientProgram == 'WoW' and gameAccount.characterName and gameAccount.characterName ~= '' then
                local statusText = (gameAccount.isGameAFK and 'AFK') or (gameAccount.isGameBusy and 'DND') or nil
                local faction = (gameAccount.factionName == FACTION_HORDE and 'Horde') or (gameAccount.factionName == FACTION_ALLIANCE and 'Alliance') or nil
                local nameText = gameAccount.characterName
                list[#list + 1] = {
                    member = {
                        name = gameAccount.characterName, isBNet = true, bnetName = bnetName, battleTag = battleTagText, gameAccountID = gameAccount.gameAccountID,
                        classFile = gameAccount.className and CLASS_TOKEN[gameAccount.className],
                        faction = faction,
                        status = statusText,
                        favorite = accountInfo.isFavorite or nil,
                    },
                    sortName = gameAccount.characterName,
                    cols = FriendCells(
                        FactionCell(faction),
                        { text = nameText, color = ClassColor(gameAccount.className) or { 0.51, 0.77, 1 } },
                        { text = gameAccount.characterLevel and tostring(gameAccount.characterLevel) or '' },
                        { text = ZoneText(gameAccount.areaName, statusText), color = { 0.45, 0.82, 0.45 } },
                        { text = battleTagText, color = accountInfo.isFavorite and FAVORITE_COLOR or BATTLETAG_COLOR },
                        { text = 'WoW', color = { 0.0, 0.69, 0.94 } }
                    ),
                }
            else
                local statusText = (accountInfo.isAFK and 'AFK') or (accountInfo.isDND and 'DND') or nil
                local identityColor = accountInfo.isFavorite and FAVORITE_COLOR or { 0.51, 0.77, 1 }
                list[#list + 1] = {
                    member = { isBNet = true, bnetName = bnetName, battleTag = battleTagText, gameAccountID = gameAccount.gameAccountID, status = statusText, favorite = accountInfo.isFavorite or nil },
                    sortName = ShowBattleTag() and battleTagText or bnetName,
                    sortBlank = ShowBattleTag() or nil,
                    cols = FriendCells(
                        { text = '' },
                        { text = ShowBattleTag() and '' or bnetName, color = identityColor },
                        { text = '' },
                        { text = ZoneText(gameAccount.richPresence, statusText), color = { 0.6, 0.6, 0.62 } },
                        { text = battleTagText, color = identityColor },
                        { text = ClientName(gameAccount.clientProgram), color = { 0.0, 0.69, 0.94 } }
                    ),
                }
            end
        end
    end
    return list
end

local function SetRowColumns(row, specs, values)
    for columnIndex = 1, 7 do
        local fontString = row.cols[columnIndex]
        local spec, value = specs[columnIndex], values[columnIndex]
        if spec and value then
            fontString:ClearAllPoints()
            fontString:SetPoint('LEFT', row, 'LEFT', Pixel.Scale(spec.columnLeft), 0)
            fontString:SetWidth(Pixel.Scale(spec.columnWidth))
            fontString:SetText(value.text or '')
            local cellColor = value.color
            if cellColor then fontString:SetTextColor(cellColor[1], cellColor[2], cellColor[3]) else fontString:SetTextColor(0.85, 0.85, 0.88) end
            fontString:Show()
        else
            fontString:Hide()
        end
    end
end

local RenderSocial

local function SetRowSectionHeader(row, entry)
    for columnIndex = 1, 7 do row.cols[columnIndex]:Hide() end
    row.sectionLabel:SetText(entry.label .. '  |cff8a8a90(' .. entry.count .. ')|r')
    local isCollapsed = BUI.GetDB().socialCollapsedSections[entry.header] == true
    row.sectionState:SetText(isCollapsed and 'OFF' or 'ON')
    if isCollapsed then row.sectionState:SetTextColor(0.5, 0.5, 0.55) else row.sectionState:SetTextColor(1, 0.82, 0) end
    row.headerBg:Show()
    row.sectionLabel:Show()
    row.sectionState:Show()
end

local function ClearRowSectionHeader(row)
    row.headerBg:Hide()
    row.sectionLabel:Hide()
    row.sectionState:Hide()
end

local function GetSocialRow(rowIndex)
    local row = socialRows[rowIndex]
    if not row then
        row = CreateFrame('Button', nil, socialPanel.listChild)
        row:SetSize(Pixel.Scale(SOCIAL_MAX_CONTENT), Pixel.Scale(SOCIAL_ROW_HEIGHT))
        row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

        row.highlight = row:CreateTexture(nil, 'BACKGROUND')
        row.highlight:SetAllPoints()
        BUI.Tools.SetColorTex(row.highlight, 1, 1, 1, 0.08)
        row.highlight:Hide()

        row.headerBg = row:CreateTexture(nil, 'BACKGROUND', nil, -1)
        row.headerBg:SetAllPoints()
        BUI.Tools.SetColorTex(row.headerBg, 1, 1, 1, 0.05)
        row.headerBg:Hide()

        row.sectionLabel = row:CreateFontString(nil, 'OVERLAY')
        Pixel.ApplyFont(row.sectionLabel, 11, PanelFont())
        row.sectionLabel:SetPoint('LEFT', row, 'LEFT', Pixel.Scale(4), 0)
        row.sectionLabel:SetTextColor(0.95, 0.95, 1)
        row.sectionLabel:Hide()

        row.sectionState = row:CreateFontString(nil, 'OVERLAY')
        Pixel.ApplyFont(row.sectionState, 10, PanelFont())
        row.sectionState:SetPoint('RIGHT', row, 'RIGHT', -Pixel.Scale(6), 0)
        row.sectionState:Hide()

        row.cols = {}
        for columnIndex = 1, 7 do
            local fontString = row:CreateFontString(nil, 'OVERLAY')
            Pixel.ApplyFont(fontString, 11, PanelFont())
            fontString:SetJustifyH('LEFT')
            fontString:SetWordWrap(false)
            row.cols[columnIndex] = fontString
        end

        row:SetScript('OnEnter', function(self)
            self.highlight:Show()
            local member = self.member
            if not member then return end
            if BUI.GetDB().datatextRosterTooltips == false then return end
            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
            GameTooltip:ClearLines()
            local classColor = member.classFile and RAID_CLASS_COLORS[member.classFile]
            local titleText = member.name or ''
            if titleText ~= '' and classColor then
                titleText = '|c' .. (classColor.colorStr or 'ffffffff') .. titleText .. '|r'
            end
            local tagText = member.isBNet and (member.battleTag or member.bnetName) or nil
            if tagText then
                tagText = (member.favorite and '|cffffd200' or '|cff82c5ff') .. tagText .. '|r'
                titleText = (titleText ~= '') and (titleText .. TOOLTIP_SEPARATOR .. tagText) or tagText
            end
            if titleText == '' then titleText = '?' end
            GameTooltip:AddLine(titleText, 1, 1, 1)
            local faction = member.faction and FactionLabel(member.faction)
            if faction or member.status then
                local line = faction or ''
                if member.status then
                    line = (line ~= '' and (line .. '  ') or '') .. '|cffffd200' .. member.status .. '|r'
                end
                GameTooltip:AddLine(line)
            end
            if member.rioScore then
                local scoreColor = member.rioScoreColor or { 1, 1, 1 }
                GameTooltip:AddDoubleLine('M+ Score', tostring(member.rioScore), 0.7, 0.7, 0.7, scoreColor[1], scoreColor[2], scoreColor[3])
                if member.rioBest then
                    GameTooltip:AddDoubleLine('Key', member.rioBest, 0.7, 0.7, 0.7, 1, 1, 1)
                end
            end
            GameTooltip:AddLine('Left-Click  |cffffffffWhisper|r', 1, 0.82, 0)
            if member.name then GameTooltip:AddLine('Shift-Click  |cffffffffWho|r', 1, 0.82, 0) end
            if member.name or (member.isBNet and member.gameAccountID) then
                GameTooltip:AddLine('Right-Click  |cffffffffInvite|r', 1, 0.82, 0)
            end
            GameTooltip:Show()
        end)
        row:SetScript('OnLeave', function(self) self.highlight:Hide(); GameTooltip:Hide() end)
        row:SetScript('OnClick', function(self, mouseButton)
            if self.headerKey then
                local collapsedSections = BUI.GetDB().socialCollapsedSections
                collapsedSections[self.headerKey] = not collapsedSections[self.headerKey] or nil
                RenderSocial()
                socialPanel.scroll:UpdateScroll()
                return
            end
            if not self.member then return end
            if mouseButton == 'RightButton' then InviteMember(self.member)
            elseif IsShiftKeyDown() then WhoMember(self.member)
            else WhisperMember(self.member) end
        end)

        socialRows[rowIndex] = row
    end
    return row
end

local function SortableCellText(text)
    local plain = tostring(text):gsub('|A.-|a', ''):gsub('|T.-|t', '')
    return (plain:gsub('^%s+', ''):gsub('%s+$', ''):lower())
end

RenderSocial = function()
    local panel = socialPanel
    local specs = panel.specs
    panel.title:SetText((panel.kind == 'guild' and 'GUILD' or 'FRIENDS') .. '  |cff8a8a90(' .. #panel.data .. ')|r')
    local data = {}
    for entryIndex = 1, #panel.data do data[entryIndex] = panel.data[entryIndex] end

    if panel.sortCol and specs[panel.sortCol] then
        local sortColumn, direction = panel.sortCol, panel.sortDir
        local allNumeric = sortColumn ~= NAME_COLUMN
        if allNumeric then
            for _, entry in ipairs(data) do
                local cellText = entry.cols[sortColumn] and entry.cols[sortColumn].text
                if cellText and cellText ~= '' and tonumber(cellText) == nil then allNumeric = false; break end
            end
        end
        table.sort(data, function(firstEntry, secondEntry)
            local firstCell = firstEntry.cols[sortColumn]
            local secondCell = secondEntry.cols[sortColumn]
            local firstOrder = firstCell and firstCell.sortValue
            local secondOrder = secondCell and secondCell.sortValue
            if firstOrder and secondOrder then
                if firstOrder == secondOrder then return false end
                if direction == 1 then return firstOrder < secondOrder end
                return firstOrder > secondOrder
            end
            local firstText = (firstCell and firstCell.text) or ''
            local secondText = (secondCell and secondCell.text) or ''
            if sortColumn == NAME_COLUMN then
                local firstBlank = firstEntry.sortBlank and 1 or 0
                local secondBlank = secondEntry.sortBlank and 1 or 0
                if firstBlank ~= secondBlank then return firstBlank < secondBlank end
                firstText = firstEntry.sortName or firstText
                secondText = secondEntry.sortName or secondText
            end
            local firstValue, secondValue
            if allNumeric then
                firstValue, secondValue = tonumber(firstText) or 0, tonumber(secondText) or 0
            else
                firstValue, secondValue = SortableCellText(firstText), SortableCellText(secondText)
            end
            if firstValue == secondValue then return false end
            if direction == 1 then return firstValue < secondValue end
            return firstValue > secondValue
        end)
    end

    for columnIndex = 1, 7 do
        local headerButton = panel.header[columnIndex]
        if headerButton:IsShown() then
            if panel.sortCol == columnIndex then
                headerButton.arrow:Show()
                headerButton.arrow:SetRotation(0)
                headerButton.arrow:SetTexCoord(0, 1, (panel.sortDir == 1) and 0 or 1, (panel.sortDir == 1) and 1 or 0)
            else
                headerButton.arrow:Hide()
            end
        end
    end

    for rowIndex = 1, #socialRows do socialRows[rowIndex]:Hide() end

    local display = data
    local advancedView = panel.kind ~= 'guild' and BUI.GetDB().socialAdvancedView == true
    if advancedView then
        local collapsedSections = BUI.GetDB().socialCollapsedSections
        local favoriteEntries, friendEntries = {}, {}
        for _, entry in ipairs(data) do
            if entry.member.favorite then favoriteEntries[#favoriteEntries + 1] = entry
            else friendEntries[#friendEntries + 1] = entry end
        end
        display = { { header = 'favorites', label = 'FAVORITES', count = #favoriteEntries } }
        if not collapsedSections.favorites then
            for _, entry in ipairs(favoriteEntries) do display[#display + 1] = entry end
        end
        display[#display + 1] = { header = 'friends', label = 'FRIENDS', count = #friendEntries }
        if not collapsedSections.friends then
            for _, entry in ipairs(friendEntries) do display[#display + 1] = entry end
        end
    end

    if #display == 0 then
        local row = GetSocialRow(1)
        row:ClearAllPoints()
        row:SetWidth(Pixel.Scale(panel.contentW or SOCIAL_MAX_CONTENT))
        row:SetPoint('TOPLEFT', panel.listChild, 'TOPLEFT', 0, 0)
        row.member = nil
        row.headerKey = nil
        ClearRowSectionHeader(row)
        SetRowColumns(row, specs, { [2] = { text = panel.kind == 'guild' and 'No one online' or 'No friends online', color = { 0.5, 0.5, 0.5 } } })
        row:Show()
    else
        for rowIndex, entry in ipairs(display) do
            local row = GetSocialRow(rowIndex)
            row:ClearAllPoints()
            row:SetWidth(Pixel.Scale(panel.contentW or SOCIAL_MAX_CONTENT))
            row:SetPoint('TOPLEFT', panel.listChild, 'TOPLEFT', 0, -Pixel.Scale((rowIndex - 1) * SOCIAL_ROW_HEIGHT))
            if entry.header then
                row.member = nil
                row.headerKey = entry.header
                SetRowSectionHeader(row, entry)
            else
                row.member = entry.member
                row.headerKey = nil
                ClearRowSectionHeader(row)
                SetRowColumns(row, specs, entry.cols)
            end
            row:Show()
        end
    end

    local count   = #display
    local maxRows = advancedView and (SOCIAL_MAX_ROWS + 2) or SOCIAL_MAX_ROWS
    local visible = math.max(1, math.min(count, maxRows))
    panel.scroll:SetChildHeight(Pixel.Scale(math.max(count, 1) * SOCIAL_ROW_HEIGHT))
    panel.scroll:SetHeight(Pixel.Scale(visible * SOCIAL_ROW_HEIGHT + 8))
    panel:SetHeight(Pixel.Scale(44 + visible * SOCIAL_ROW_HEIGHT + 8 + 22))
end

local DispatchGuildRefresh = BUI.Dispatcher.NewDelayed(function()
    if not (socialPanel and socialPanel:IsShown() and socialPanel.kind == 'guild') then return end
    socialPanel.data = GatherGuild()
    RenderSocial()
    for rowIndex = 1, #socialRows do
        local row = socialRows[rowIndex]
        if row:IsShown() and row.member and row:IsMouseOver() then
            local onEnter = row:GetScript('OnEnter')
            if onEnter then onEnter(row) end
            break
        end
    end
end, 0.4)

local function RefreshGuildSoon()
    if not (socialPanel and socialPanel:IsShown() and socialPanel.kind == 'guild') then return end
    DispatchGuildRefresh()
end

local DispatchSocialRefresh = BUI.Dispatcher.NewDelayed(function()
    if not (socialPanel and socialPanel:IsShown()) then return end
    socialPanel.data = (socialPanel.kind == 'guild') and GatherGuild() or GatherFriends()
    RenderSocial()
end, 0.4)

local function RefreshOpenSocialPanel()
    if not (socialPanel and socialPanel:IsShown()) then return end
    DispatchSocialRefresh()
end

local function SetupKeystone()
    if keystoneRegistered then return true end
    local keystoneLib = LibStub('LibKeystone')
    keystoneRegistered = true
    Datatext._LKS = keystoneLib
    keystoneLib.Register(Datatext, function(level, mapID, rating, sender)
        local entry = keystoneData[sender]
        if not entry then entry = {}; keystoneData[sender] = entry end
        entry.level, entry.mapID, entry.score = level, mapID, rating
        RefreshGuildSoon()
    end)
    return true
end

local function RequestKeystones()
    if SetupKeystone() then
        Datatext._LKS.Request('GUILD')
        if IsInGroup() then Datatext._LKS.Request('PARTY') end
    end
end

local function BuildSocialPanel()
    if socialPanel then return end
    local initialPanelWidth, initialContainerWidth, initialChildWidth = SocialWidths(GUILD_COLS)
    local panel = Datatext.CreateHoverPanel('BUI_DatatextSocial', initialPanelWidth)

    panel.advancedToggle = CreateFrame('Button', nil, panel)
    panel.advancedToggle:SetFrameLevel(panel:GetFrameLevel() + 10)
    panel.advancedToggle:SetHeight(Pixel.Scale(14))
    panel.advancedToggle:SetPoint('TOPRIGHT', Pixel.Scale(-10), Pixel.Scale(-7))
    local advancedBox = CreateFrame('Frame', nil, panel.advancedToggle, 'BackdropTemplate')
    advancedBox:SetSize(Pixel.Scale(12), Pixel.Scale(12))
    advancedBox:SetPoint('RIGHT')
    Pixel.SetTemplate(advancedBox, 0.08, 0.08, 0.1, 1, 0.4, 0.4, 0.45, 1)
    panel.advancedCheck = advancedBox:CreateTexture(nil, 'OVERLAY')
    panel.advancedCheck:SetSize(Pixel.Scale(10), Pixel.Scale(10))
    panel.advancedCheck:SetPoint('CENTER')
    panel.advancedCheck:SetTexture(BUI.C.MEDIA_PATH .. 'checkmark.tga')
    panel.advancedCheck:SetVertexColor(1, 0.82, 0)
    panel.advancedCheck:Hide()
    local advancedLabel = panel.advancedToggle:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(advancedLabel, 10, PanelFont())
    advancedLabel:SetTextColor(0.55, 0.55, 0.60)
    advancedLabel:SetText('Advanced')
    advancedLabel:SetPoint('RIGHT', advancedBox, 'LEFT', -Pixel.Scale(5), 0)
    panel.advancedToggle:SetWidth(Pixel.Scale(19) + advancedLabel:GetStringWidth())
    panel.advancedToggle:SetScript('OnEnter', function() advancedLabel:SetTextColor(0.95, 0.95, 1) end)
    panel.advancedToggle:SetScript('OnLeave', function() advancedLabel:SetTextColor(0.55, 0.55, 0.60) end)
    panel.advancedToggle:SetScript('OnClick', function()
        local profile = BUI.GetDB()
        profile.socialAdvancedView = not profile.socialAdvancedView
        panel.advancedCheck:SetShown(profile.socialAdvancedView == true)
        RenderSocial()
        panel.scroll:UpdateScroll()
    end)

    local scroll = Controls.ScrollFrame(panel, Pixel.Scale(initialContainerWidth), Pixel.Scale(SOCIAL_MAX_ROWS * SOCIAL_ROW_HEIGHT + 4), nil, Pixel.Scale(initialChildWidth))
    local scrollWidget = scroll.frame or scroll
    scrollWidget:ClearAllPoints()
    scrollWidget:SetPoint('TOPLEFT', Pixel.Scale(8), Pixel.Scale(-44))
    panel.scroll = scrollWidget
    panel.listChild = scrollWidget.child
    panel.scrollFrame = scrollWidget.scrollFrame

    panel.header = {}
    for columnIndex = 1, 7 do
        local headerButton = CreateFrame('Button', nil, panel)
        headerButton:SetHeight(Pixel.Scale(14))
        headerButton:SetFrameLevel(panel:GetFrameLevel() + 10)
        headerButton:RegisterForClicks('LeftButtonUp')
        headerButton.col = columnIndex
        headerButton.label = headerButton:CreateFontString(nil, 'OVERLAY')
        Pixel.ApplyFont(headerButton.label, 10, PanelFont())
        headerButton.label:SetTextColor(0.55, 0.55, 0.60)
        headerButton.label:SetJustifyH('LEFT')
        headerButton.label:SetPoint('LEFT')
        headerButton.arrow = headerButton:CreateTexture(nil, 'OVERLAY')
        headerButton.arrow:SetTexture(LibMedia('sorttri'))
        headerButton.arrow:SetVertexColor(0.85, 0.85, 0.9)
        headerButton.arrow:SetSize(Pixel.Scale(8), Pixel.Scale(8))
        headerButton.arrow:SetPoint('LEFT', headerButton.label, 'RIGHT', Pixel.Scale(1), 0)
        headerButton.arrow:Hide()
        headerButton:SetScript('OnEnter', function(self) self.label:SetTextColor(0.95, 0.95, 1) end)
        headerButton:SetScript('OnLeave', function(self) self.label:SetTextColor(0.55, 0.55, 0.60) end)
        headerButton:SetScript('OnClick', function(self)
            local openPanel = socialPanel
            if not openPanel.data then return end
            if openPanel.sortCol == self.col then
                openPanel.sortDir = -openPanel.sortDir
            else
                openPanel.sortCol, openPanel.sortDir = self.col, 1
            end
            GetSortState()[openPanel.kind] = { col = openPanel.sortCol, dir = openPanel.sortDir }
            RenderSocial()
            openPanel.scroll:ScrollToTop()
        end)
        panel.header[columnIndex] = headerButton
    end
    panel.headerLine = panel:CreateTexture(nil, 'ARTWORK')
    BUI.Tools.SetColorTex(panel.headerLine, 1, 1, 1, 0.12)
    panel.headerLine:SetHeight(1)
    panel.headerLine:SetPoint('BOTTOMLEFT',  scrollWidget.scrollFrame, 'TOPLEFT',  0, Pixel.Scale(2))
    panel.headerLine:SetPoint('BOTTOMRIGHT', scrollWidget.scrollFrame, 'TOPRIGHT', 0, Pixel.Scale(2))

    panel.key = panel:CreateFontString(nil, 'OVERLAY')
    Pixel.ApplyFont(panel.key, 10, PanelFont())
    panel.key:SetPoint('BOTTOMLEFT', Pixel.Scale(10), Pixel.Scale(7))
    panel.key:SetText('|cffffd200Left-Click|r Whisper   |cffffd200Shift-Click|r Who   |cffffd200Right-Click|r Invite')

    local pressedOutside = false
    local function OnGlobalMouse(event)
        if event == 'GLOBAL_MOUSE_DOWN' then
            pressedOutside = not panel:IsMouseOver()
        elseif event == 'GLOBAL_MOUSE_UP' and pressedOutside and not panel:IsMouseOver() then
            panel:FadeOut()
        end
    end
    panel:SetScript('OnShow', function()
        pressedOutside = false
        BUI.Events:Register('GLOBAL_MOUSE_DOWN', 'Datatext.Social', OnGlobalMouse)
        BUI.Events:Register('GLOBAL_MOUSE_UP',   'Datatext.Social', OnGlobalMouse)
    end)
    panel:SetScript('OnHide', function() BUI.Events:UnregisterAll('Datatext.Social') end)

    socialPanel = panel
end

local function OpenSocialPanel(anchor, kind)
    local panel = socialPanel
    panel.kind = kind
    panel.anchor = anchor:GetParent() or anchor
    if kind == 'guild' then RequestKeystones() end

    panel.data  = (kind == 'guild') and GatherGuild() or GatherFriends()
    local specs, labels = SocialColumns(kind)
    if kind ~= 'guild' and ShowBattleTag() then
        specs = FitColumn(panel, specs, labels, 5, FRIEND_TAG_MIN_WIDTH, FRIEND_TAG_MAX_WIDTH)
    end
    panel.specs = specs
    local savedSort = GetSortState()[kind]
    if savedSort then
        panel.sortCol, panel.sortDir = savedSort.col, savedSort.dir
    else
        panel.sortCol, panel.sortDir = nil, 1
    end
    panel.advancedToggle:SetShown(kind ~= 'guild')
    panel.advancedCheck:SetShown(BUI.GetDB().socialAdvancedView == true)

    local measureText = panel.measureString or panel:CreateFontString(nil, 'OVERLAY')
    panel.measureString = measureText
    Pixel.ApplyFont(measureText, 11, PanelFont())
    local contentRight = 0
    for columnIndex = 1, #panel.specs do
        local columnX = panel.specs[columnIndex].columnLeft
        measureText:SetText(labels[columnIndex] or '')
        if columnX + measureText:GetStringWidth() > contentRight then contentRight = columnX + measureText:GetStringWidth() end
        for _, entry in ipairs(panel.data) do
            local cell = entry.cols[columnIndex]
            if cell and cell.text and cell.text ~= '' then
                measureText:SetText(cell.text)
                if columnX + measureText:GetStringWidth() > contentRight then contentRight = columnX + measureText:GetStringWidth() end
            end
        end
    end
    if panel.key:GetStringWidth() > contentRight then contentRight = panel.key:GetStringWidth() end
    local lastSpec = panel.specs[#panel.specs]
    if contentRight > lastSpec.columnLeft + lastSpec.columnWidth then contentRight = lastSpec.columnLeft + lastSpec.columnWidth end

    local gutter         = (#panel.data > SOCIAL_MAX_ROWS) and SOCIAL_CHILD_GUTTER or 4
    local childWidth     = contentRight + gutter
    local containerWidth = childWidth + SOCIAL_CLIP_INSET
    local panelWidth     = containerWidth + SOCIAL_PANEL_INSET
    panel.contentW = childWidth
    panel:SetWidth(Pixel.Scale(panelWidth))
    panel.scroll:SetWidth(Pixel.Scale(containerWidth))
    panel.listChild:SetWidth(Pixel.Scale(childWidth))
    for rowIndex = 1, #socialRows do socialRows[rowIndex]:SetWidth(Pixel.Scale(childWidth)) end
    panel.scroll:UpdateScroll()

    for columnIndex = 1, 7 do
        local headerButton = panel.header[columnIndex]
        local spec = panel.specs[columnIndex]
        if spec and labels[columnIndex] then
            headerButton:ClearAllPoints()
            headerButton:SetPoint('BOTTOMLEFT', panel.scrollFrame, 'TOPLEFT', Pixel.Scale(spec.columnLeft), Pixel.Scale(4))
            headerButton:SetWidth(Pixel.Scale(spec.columnWidth))
            headerButton.label:SetText(labels[columnIndex])
            headerButton:Show()
        else
            headerButton:Hide()
        end
    end

    RenderSocial()
    panel.scroll:ScrollToTop()

    local anchorFrame = panel.anchor
    local offsetX = 0
    local anchorLeft = anchorFrame:GetLeft()
    if anchorLeft then
        local panelRightPixels = anchorLeft * anchorFrame:GetEffectiveScale() + panel:GetWidth() * panel:GetEffectiveScale()
        local overflowPixels = panelRightPixels - (UIParent:GetRight() * UIParent:GetEffectiveScale() - 24)
        if overflowPixels > 0 then offsetX = -(overflowPixels / panel:GetEffectiveScale()) end
    end
    panel:ClearAllPoints()
    local anchorBottomPixels = anchorFrame:GetBottom() and anchorFrame:GetBottom() * anchorFrame:GetEffectiveScale()
    if anchorBottomPixels and (anchorBottomPixels - panel:GetHeight() * panel:GetEffectiveScale()) < 40 then
        panel:SetPoint('BOTTOMLEFT', anchorFrame, 'TOPLEFT', offsetX, Pixel.Scale(7))
    else
        panel:SetPoint('TOPLEFT', anchorFrame, 'BOTTOMLEFT', offsetX, Pixel.Scale(-7))
    end

    panel:Reveal()
end

function Datatext.OpenSocialHover(anchor, kind)
    BuildSocialPanel()
    local panel = socialPanel
    if panel:IsShown() and not panel._fadingOut and panel.kind == kind then
        panel.anchor = anchor:GetParent() or anchor
        return
    end
    OpenSocialPanel(anchor, kind)
end

function Datatext.HideSocial()
    if socialPanel then socialPanel:ForceHide() end
end

Datatext.RefreshOpenSocialPanel = RefreshOpenSocialPanel
Datatext.RequestKeystones = RequestKeystones
