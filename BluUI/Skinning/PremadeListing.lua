local _, BUI = ...

local Premade = BUI.Premade
local BUILib = BluUI.BUILibClient
local FONT = BUILib.Font
local Skin = BUI.Skinning
local Painter = BUI.Painter
local Pixel = BUI.Pixel
local PALETTE = Skin.PALETTE

local context, Settings = Premade.context, Premade.Settings
local Text, Rule, Panel, Strip, Comp = Premade.Text, Premade.Rule, Premade.Panel, Premade.Strip, Premade.Comp
local BUTTON_H, FRAME, STRIP, SIDE = Premade.BUTTON_H, Premade.FRAME, Premade.STRIP, Premade.SIDE
local BAR, ROW, POP, ALPHA = Premade.BAR, Premade.ROW, Premade.POP, Premade.ALPHA
local ROLES, ROLE_ATLAS, ROLE_NAMES = Premade.ROLES, Premade.ROLE_ATLAS, Premade.ROLE_NAMES
local SLOT_ROLES, SLOT_RANK = Premade.SLOT_ROLES, Premade.SLOT_RANK
local FALLBACK_ICON = Premade.FALLBACK_ICON

local OWNER = 'Skinning.PremadeListing'
local FORM = {
	pad = 12, header = 18, section = 16, titleH = 28, descriptionH = 84, descriptionLines = 4, previewH = 44,
	previewIcon = 32, nameY = 7, subY = -8, inset = 10, listW = 120, backW = 80, moreW = 300, moreRows = 12,
	moreGap = 8, scrollTrack = 20, tileMax = 16, badgeSize = 11,
}
local APPS = {
	cardH = 62, art = 40, artInset = 11, textX = 61, textRight = 200, titleY = 15, commentY = -15,
	memberH = 26, pad = 4, roleIcon = 16, roleGap = 2, specX = 64, specIcon = 18, nameX = 88, nameW = 170,
	ilvlW = 36, ratingW = 40, bestW = 32, columnGap = 8, inviteW = 64, declineW = 64, actionGap = 4,
	actionsW = 146, clearSize = 10, headerH = 16, headerGap = 2, sortW = 130, autoW = 110, browseW = 110, editW = 70,
}
local EMPTY = {}
local MORE_TILE = { label = '', texture = FALLBACK_ICON }
local STYLES = {}
for value, item in ipairs(Premade.PLAYSTYLES) do STYLES[value] = { value = value, label = item.label } end
local ROLE_ITEMS = {}
for index, role in ipairs(ROLES) do ROLE_ITEMS[index] = { key = role, label = ROLE_NAMES[role] } end
local ROLE_FIELD = { TANK = 'tank', HEALER = 'healer', DAMAGER = 'damage' }
local LUST_ITEMS = { { key = 'any', label = Premade.ANY }, { key = 'lust', label = 'Brings lust' } }
local LUST = {}
for _, classFile in ipairs(Comp.lust) do LUST[classFile] = true end
local AUTO_ITEM = { label = 'Auto accept' }
local APP_SORTS = {
	{ label = 'Rating', sort = 'rating' },
	{ label = 'Item level', sort = 'ilvl' },
	{ label = 'Newest', sort = 'newest' },
}
local APP_EVENTS = {
	'LFG_LIST_APPLICANT_LIST_UPDATED', 'LFG_LIST_APPLICANT_UPDATED', 'LFG_LIST_ACTIVE_ENTRY_UPDATE',
	'GROUP_ROSTER_UPDATE', 'PARTY_LEADER_CHANGED', 'PLAYER_ROLES_ASSIGNED',
}
local APP_STATUS = {
	invited = 'Invited', inviteaccepted = 'Joined', invitedeclined = 'Declined invite', declined = 'Declined',
	declined_full = 'Declined', declined_delisted = 'Declined', cancelled = 'Cancelled', failed = 'Cancelled',
	timedout = 'Expired',
}
local APP_DONE = {
	inviteaccepted = true, invitedeclined = true, declined = true, declined_full = true, declined_delisted = true,
	cancelled = true, failed = true, timedout = true,
}
local STATUS_RANK = { applied = 1, invited = 2 }

local REGIONS = Premade.REGIONS

local finder, listing, applicants
local form = { choices = {}, more = {}, activities = {} }
local appFilter = {}
local shown, cards, artCache, tagParts, skipped, applicantRealms = {}, {}, {}, {}, {}, {}
local groupRoles = { TANK = {}, HEALER = {}, DAMAGER = {} }
local appSort = 'rating'
local Listing, Applicants = {}, {}

local function Plain(value)
	if issecretvalue and issecretvalue(value) then return nil end
	return value
end

local function Colored(role, text)
	return '|cff' .. BUI.Hex(Painter.Color(role)) .. text .. '|r'
end

local function Locked()
	return C_ChatInfo.InChatMessagingLockdown() == true
end

local function IsLeader()
	return not IsInGroup(LE_PARTY_CATEGORY_HOME) or UnitIsGroupLeader('player', LE_PARTY_CATEGORY_HOME)
end

local function Empowered()
	return IsLeader() or UnitIsGroupAssistant('player', LE_PARTY_CATEGORY_HOME)
end

local function Creation()
	return LFGListFrame.EntryCreation
end

local function ActivityName(info)
	local short = info.shortName
	return short and short ~= '' and short or info.fullName
end

local function ActivityArt(activityID)
	if not activityID then return FALLBACK_ICON end
	if not artCache[activityID] then
		local info = C_LFGList.GetActivityInfoTable(activityID)
		artCache[activityID] = info and select(2, Premade.DungeonArt(info)) or FALLBACK_ICON
	end
	return artCache[activityID]
end

local function SortChoices(left, right)
	if left.order ~= right.order then return left.order < right.order end
	return left.label < right.label
end

local function MoveHeader(label, parent, y)
	label:ClearAllPoints()
	label:SetPoint('LEFT', parent, 'TOPLEFT', Pixel.Scale(SIDE.pad), Pixel.Scale(-(y + POP.headerMid)))
end

local function ResetAppFilter()
	appFilter.TANK, appFilter.HEALER, appFilter.DAMAGER = true, true, true
	appFilter.comp, appFilter.lust, appFilter.rating, appFilter.ilvl = 'any', false, 0, 0
end
ResetAppFilter()

local function OpenPage(page)
	Strip.ShowSearch(false)
	page:Show()
	Pixel.SetScale(finder, Settings().scale)
	Strip.Hold()
end

local function ClosePage(page, now)
	BUI.Events:UnregisterAll(OWNER)
	if not page or not page:IsShown() then return end
	Premade.HidePanel()
	page:Hide()
	Strip.Release(now)
end

local function ShowBlizzardPanel(button)
	skipped[button.kind] = true
	ClosePage(button.kind == 'listing' and listing or applicants, true)
end

local function NewPage()
	local page = CreateFrame('Frame', nil, finder)
	page:SetAllPoints()
	page:Hide()
	finder.pages[#finder.pages + 1] = page
	page.side = CreateFrame('Frame', nil, page)
	page.side:SetPoint('BOTTOMLEFT')
	page.side:SetWidth(Pixel.Scale(FRAME.sideW))
	page.main = CreateFrame('Frame', nil, page)
	page.main:SetPoint('BOTTOMRIGHT')
	page.divider = Rule(page)
	page.divider:SetHeight(Pixel.PixelSize(1))
	local sideRule = Rule(page)
	sideRule:SetWidth(Pixel.PixelSize(1))
	sideRule:SetPoint('TOPLEFT', page.side, 'TOPRIGHT')
	sideRule:SetPoint('BOTTOMLEFT', page.side, 'BOTTOMRIGHT', 0, Pixel.Scale(1))
	page.header = Panel.Header(page, '', FRAME.edge, STRIP.top)
	local blizzard = Skin.SmallButton(page.side, FRAME.sideW - SIDE.pad * 2, SIDE.serversH, 'Blizzard group finder')
	blizzard:SetPoint('BOTTOMLEFT', Pixel.Scale(SIDE.pad), Pixel.Scale(SIDE.pad))
	blizzard:SetScript('OnClick', ShowBlizzardPanel)
	page.blizzard = blizzard
	return page
end

local function PlaceBody(page, top)
	page.divider:SetPoint('TOPLEFT', Pixel.Scale(1), Pixel.Scale(-(top - 1)))
	page.divider:SetPoint('TOPRIGHT', Pixel.Scale(-1), Pixel.Scale(-(top - 1)))
	page.side:SetPoint('TOPLEFT', 0, Pixel.Scale(-top))
	page.main:SetPoint('TOPLEFT', Pixel.Scale(FRAME.sideW), Pixel.Scale(-top))
end

local QueuePaint = BUI.Dispatcher.New(function() Listing.Paint() end)
local QueueApplicants = BUI.Dispatcher.New(function() Applicants.Refresh() end)

local function OwnedKey()
	local activityID, groupID, level = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel()
	if not activityID then activityID, groupID, level = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel(true) end
	return activityID, groupID, level
end

local function Difficulty(info)
	if info.isMythicPlusActivity then return 'mplus' end
	if info.isMythicActivity then return 'mythic' end
	if info.isHeroicActivity then return 'heroic' end
	if info.isNormalActivity then return 'normal' end
end

local function SelectedKey()
	if form.groupID and form.groupID ~= 0 then return 'g' .. form.groupID end
	return form.activityID and ('a' .. form.activityID)
end

function Listing.Collect(list, seen, filters)
	local category = form.category
	for _, groupID in ipairs(C_LFGList.GetAvailableActivityGroups(category, filters)) do
		local key = 'g' .. groupID
		if not seen[key] then
			seen[key] = true
			local name, order = C_LFGList.GetActivityGroupInfo(groupID)
			local first = C_LFGList.GetAvailableActivities(category, groupID, filters)[1]
			list[#list + 1] = { key = key, groupID = groupID, label = name or '', order = order or 0, art = first }
		end
	end
	for _, activityID in ipairs(C_LFGList.GetAvailableActivities(category, 0, filters)) do
		local key = 'a' .. activityID
		local info = not seen[key] and C_LFGList.GetActivityInfoTable(activityID)
		if info then
			seen[key] = true
			list[#list + 1] = { key = key, activityID = activityID, label = ActivityName(info), order = info.orderIndex or 0, art = activityID }
		end
	end
end

function Listing.BuildChoices(category)
	wipe(form.choices)
	wipe(form.more)
	if not category or category.autoChooseActivity then return end
	local primary, rest, seen = {}, {}, {}
	local flag = form.category == Premade.DUNGEON_CATEGORY and Enum.LFGListFilter.CurrentSeason or Enum.LFGListFilter.Recommended
	Listing.Collect(primary, seen, bit.bor(form.filters, flag))
	Listing.Collect(rest, seen, form.filters)
	if #primary == 0 then primary, rest = rest, primary end
	table.sort(primary, SortChoices)
	table.sort(rest, SortChoices)
	local room = (#rest > 0 or #primary > FORM.tileMax) and FORM.tileMax - 1 or FORM.tileMax
	for index, choice in ipairs(primary) do
		local list = index <= room and form.choices or form.more
		list[#list + 1] = choice
	end
	for _, choice in ipairs(rest) do form.more[#form.more + 1] = choice end
end

function Listing.GroupActivities()
	wipe(form.activities)
	local groupID = form.groupID
	if not groupID or groupID == 0 then return end
	for _, activityID in ipairs(C_LFGList.GetAvailableActivities(form.category, groupID, form.filters)) do
		local info = C_LFGList.GetActivityInfoTable(activityID)
		if info then
			form.activities[#form.activities + 1] = { activityID = activityID, label = ActivityName(info), order = info.orderIndex or 0 }
		end
	end
	table.sort(form.activities, SortChoices)
end

function Listing.PickActivity(groupID)
	local keyActivity, keyGroup = OwnedKey()
	if keyGroup == groupID then return keyActivity end
	local current = form.activityID and C_LFGList.GetActivityInfoTable(form.activityID)
	local wanted = current and Difficulty(current)
	local activities = C_LFGList.GetAvailableActivities(form.category, groupID, form.filters)
	for _, activityID in ipairs(activities) do
		local info = wanted and C_LFGList.GetActivityInfoTable(activityID)
		if info and Difficulty(info) == wanted then return activityID end
	end
	return activities[1]
end

function Listing.SetPrebuiltTitle()
	local info = form.activityID and C_LFGList.GetActivityInfoTable(form.activityID)
	if not info then return end
	if info.isMythicPlusActivity or IsActivityLockedForCustomText(form.category, form.activityID) then
		C_LFGList.SetEntryTitle(form.activityID, form.groupID or 0, nil, form.playstyle)
	end
end

function Listing.Select(activityID)
	local info = activityID and C_LFGList.GetActivityInfoTable(activityID)
	if not info then return end
	form.activityID, form.groupID = activityID, info.groupFinderActivityGroupID
	Listing.SetPrebuiltTitle()
	Listing.Layout()
end

function Listing.Choose(choice)
	if form.editMode or not choice then return end
	Listing.Select(choice.groupID and Listing.PickActivity(choice.groupID) or choice.activityID)
end

function Listing.MoreChoice()
	local key = SelectedKey()
	for _, choice in ipairs(form.more) do
		if choice.key == key then return choice end
	end
end

function Listing.TileOn(tile)
	if tile.kind then return Listing.MoreChoice() ~= nil end
	return tile.choice.key == SelectedKey()
end

function Listing.ChooseTile(tile)
	if tile.kind then
		if not form.editMode then Panel.OpenPanel(tile) end
		return
	end
	Listing.Choose(tile.choice)
end

function Listing.PaintMoreTile(tile)
	local choice = Listing.MoreChoice()
	local label = choice and choice.label or ('+%d more'):format(#form.more)
	tile.icon:SetTexture(choice and ActivityArt(choice.art) or FALLBACK_ICON)
	tile.text:SetText(label)
	tile.label = label
end

function Listing.LayoutTiles()
	local width = (FRAME.width - FRAME.edge * 2 - STRIP.tileGap * (STRIP.perRow - 1)) / STRIP.perRow
	local count = #form.choices + (#form.more > 0 and 1 or 0)
	local _, keyGroup, keyLevel = OwnedKey()
	local y = STRIP.top + STRIP.header
	for index = 1, count do
		local choice = form.choices[index]
		local tile = listing.tiles[index]
		if not tile then
			tile = Strip.Tile(listing, MORE_TILE, width, Listing.TileOn, Listing.ChooseTile)
			tile.badge = tile:CreateFontString(nil, 'OVERLAY')
			Pixel.ApplyFont(tile.badge, FORM.badgeSize, FONT, 'OUTLINE')
			tile.badge:SetPoint('BOTTOMRIGHT', tile.icon, 'BOTTOMRIGHT', Pixel.Scale(1), 0)
			Painter.Text(tile.badge, 'skinTitle')
			listing.tiles[index] = tile
		end
		tile.choice, tile.kind = choice, not choice and 'more' or nil
		if choice then
			tile.icon:SetTexture(ActivityArt(choice.art))
			tile.text:SetText(choice.label)
			tile.label = choice.label
		end
		local isKey = choice and choice.groupID ~= nil and choice.groupID == keyGroup
		tile.badge:SetText(isKey and ('+%d'):format(keyLevel) or '')
		local column, line = (index - 1) % STRIP.perRow, math.floor((index - 1) / STRIP.perRow)
		tile:ClearAllPoints()
		tile:SetPoint('TOPLEFT', Pixel.Scale(FRAME.edge + column * (width + STRIP.tileGap)), Pixel.Scale(-(y + line * (STRIP.tileH + STRIP.tileGap))))
		tile:Show()
	end
	for index = count + 1, #listing.tiles do listing.tiles[index]:Hide() end
	local lines = math.ceil(count / STRIP.perRow)
	if lines > 0 then y = y + lines * STRIP.tileH + (lines - 1) * STRIP.tileGap end
	PlaceBody(listing, y + STRIP.divider + 1)
end

function Listing.MoreMatches(choice, query)
	return not query or query == '' or choice.label:lower():find(query, 1, true) ~= nil
end

function Listing.PickMore(check)
	Premade.HidePanel()
	Listing.Choose(check.choice)
end

function Listing.RefreshMore(pop)
	local key, count = SelectedKey(), 0
	for _, choice in ipairs(form.more) do
		if Listing.MoreMatches(choice, pop.query) then
			count = count + 1
			local check = pop.rows[count]
			if not check then
				check = Panel.CheckRow(pop.list, pop.rowW, Listing.PickMore, FALLBACK_ICON)
				pop.rows[count] = check
			end
			check.choice = choice
			check.icon:SetTexture(ActivityArt(choice.art))
			check.text:SetText(choice.label)
			check:SetPoint('TOPLEFT', 0, -Pixel.Scale((count - 1) * POP.checkRow))
			Panel.SetChecked(check, choice.key == key)
			check:Show()
		end
	end
	for index = count + 1, #pop.rows do pop.rows[index]:Hide() end
	pop.list:SetHeight(math.max(1, Pixel.Scale(count * POP.checkRow)))
	pop.emptyText:SetShown(count == 0)
end

function Listing.BuildMore()
	local inner = FORM.moreW - POP.pad * 2
	local pop = Panel.Popover('more', FORM.moreW, 'TOPRIGHT', 'BOTTOMRIGHT', 0, -POP.gap)
	pop.search = Skin.CreateSearchBox(pop, inner, function(text)
		pop.query = text
		Listing.RefreshMore(pop)
	end)
	pop.search:SetPoint('TOPLEFT', Pixel.Scale(POP.pad), Pixel.Scale(-POP.pad))
	local top = POP.pad + BUTTON_H + FORM.moreGap
	local area = CreateFrame('Frame', nil, pop)
	area:SetPoint('TOPLEFT', Pixel.Scale(POP.pad), Pixel.Scale(-top))
	area:SetSize(Pixel.Scale(inner), Pixel.Scale(FORM.moreRows * POP.checkRow))
	pop.scroll, pop.list = Skin.CreateScrollArea(area, POP.checkRow, 0)
	pop.emptyText = Skin.CreateEmptyText(pop, area)
	pop.emptyText:SetText('Nothing matches.')
	pop.rows, pop.rowW = {}, inner - FORM.scrollTrack
	pop:SetHeight(Pixel.Scale(top + FORM.moreRows * POP.checkRow + POP.pad))
	pop.Refresh = Listing.RefreshMore
end

function Listing.ActivityOn(button)
	return button.item.activityID == form.activityID
end

function Listing.ToggleActivity(button)
	if form.editMode then return end
	Listing.Select(button.item.activityID)
end

function Listing.StyleOn(button)
	return button.item.value == form.playstyle
end

function Listing.SetStyle(value)
	local previous = form.playstyle
	form.playstyle = value
	if form.activityID and C_LFGList.DoesEntryTitleMatchPrebuiltTitle(form.activityID, form.groupID or 0, Enum.LFGEntryPlaystyle.None, previous) then
		Listing.SetPrebuiltTitle()
	end
end

function Listing.ToggleStyle(button)
	Listing.SetStyle(button.item.value)
	Listing.Paint()
end

function Listing.ToggleLocked(button)
	local activityID = button.item.activityID
	return form.editMode and activityID ~= nil and activityID ~= form.activityID
end

function Listing.Ilvl()
	return form.ilvl
end

function Listing.SetIlvl(value)
	form.ilvl = value
	QueuePaint()
end

function Listing.Rating()
	return form.rating
end

function Listing.SetRating(value)
	form.rating = value
	QueuePaint()
end

function Listing.Section(header, pool, items, perRow, height, y, isOn, onClick)
	local side = listing.side
	header:SetShown(#items > 0)
	if #items == 0 then
		Strip.PlaceToggles(side, pool, items, perRow, height, y, isOn, onClick)
		return y
	end
	MoveHeader(header, side, y)
	return Strip.PlaceToggles(side, pool, items, perRow, height, y + SIDE.header, isOn, onClick) + SIDE.section
end

function Listing.NumberRow(header, box, y)
	local side = listing.side
	MoveHeader(header, side, y + BUTTON_H / 2 - POP.headerMid)
	box:ClearAllPoints()
	box:SetPoint('TOPRIGHT', side, 'TOPLEFT', Pixel.Scale(FRAME.sideW - SIDE.pad), Pixel.Scale(-y))
	return y + BUTTON_H + SIDE.section
end

function Listing.LayoutSide()
	local activity = form.activityID and C_LFGList.GetActivityInfoTable(form.activityID)
	local activities = #form.activities > 1 and form.activities or EMPTY
	local y = Listing.Section(listing.activityHeader, listing.activityToggles, activities, 2, SIDE.toggleH, SIDE.pad, Listing.ActivityOn, Listing.ToggleActivity)
	y = Listing.Section(listing.styleHeader, listing.styleToggles, STYLES, 2, SIDE.playstyleH, y, Listing.StyleOn, Listing.ToggleStyle)
	y = Listing.NumberRow(listing.ilvlHeader, listing.ilvlBox, y)
	local rated = activity ~= nil and (activity.isMythicPlusActivity or activity.isRatedPvpActivity)
	listing.ratingHeader:SetShown(rated)
	listing.ratingBox:SetShown(rated)
	if rated then Listing.NumberRow(listing.ratingHeader, listing.ratingBox, y) end
end

function Listing.Layout()
	Listing.GroupActivities()
	Listing.LayoutSide()
	Listing.Paint()
end

function Listing.MirrorField(slot)
	local box = slot.box
	local text = box:GetText()
	local focused = box:HasFocus()
	slot.text:SetText(text)
	slot.hint:SetShown(Plain(text) == '' and not focused)
	slot:SetAlpha(box:IsEnabled() and 1 or ALPHA.dimmed)
	if slot.caret then Strip.PlaceCaret(slot.caret, box, focused) end
	local edge = PALETTE.edge
	if focused then
		edge = Skin.SELECTED_COLOR
	elseif slot:IsMouseOver() then
		edge = Skin.HoverColor()
	end
	Pixel.SetBorderColor(slot, edge[1], edge[2], edge[3], edge[4])
end

function Listing.FocusField(slot)
	if slot.box:IsEnabled() then slot.box:SetFocus() end
end

function Listing.FieldEnter(slot)
	if slot.box:IsEnabled() then
		Pixel.SetBorderColor(slot, unpack(Skin.HoverColor()))
		return
	end
	local reason = GetLFGLockedTooltip(form.activityID)
	if reason == '' then return end
	GameTooltip:SetOwner(slot, 'ANCHOR_TOP')
	GameTooltip:SetText(reason, 1, 1, 1, 1, true)
	GameTooltip:Show()
end

function Listing.FieldLeave(slot)
	Listing.MirrorField(slot)
	GameTooltip:Hide()
end

function Listing.Field(parent, height, hint, multiline)
	local slot = CreateFrame('Button', nil, parent, 'BackdropTemplate')
	slot:SetHeight(Pixel.Scale(height))
	Skin.PaintBackdrop(slot, PALETTE.card)
	slot.text = Text(slot, 12, 'skinTitle')
	slot.hint = Text(slot, 11, 'skinLabel')
	slot.hint:SetText(hint)
	local inset = Pixel.Scale(FORM.inset)
	for _, label in ipairs({ slot.text, slot.hint }) do
		if multiline then
			label:SetPoint('TOPLEFT', inset, -inset)
			label:SetPoint('TOPRIGHT', -inset, -inset)
			label:SetJustifyV('TOP')
		else
			label:SetPoint('LEFT', inset, 0)
			label:SetPoint('RIGHT', -inset, 0)
		end
	end
	if multiline then
		slot.text:SetWordWrap(true)
		slot.text:SetMaxLines(FORM.descriptionLines)
	else
		slot.caret = Strip.Caret(slot, slot.text, 12)
	end
	slot:SetScript('OnClick', Listing.FocusField)
	slot:SetScript('OnEnter', Listing.FieldEnter)
	slot:SetScript('OnLeave', Listing.FieldLeave)
	return slot
end

function Listing.Preview(parent)
	local card = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	card:SetHeight(Pixel.Scale(FORM.previewH))
	Skin.PaintBackdrop(card, PALETTE.card)
	card.icon = card:CreateTexture(nil, 'ARTWORK')
	card.icon:SetSize(Pixel.Scale(FORM.previewIcon), Pixel.Scale(FORM.previewIcon))
	card.icon:SetPoint('LEFT', Pixel.Scale(ROW.inset), 0)
	Skin.SquareIcon(card, card.icon, 1)
	card.title = Text(card, 12, 'skinText')
	card.title:SetPoint('LEFT', card.icon, 'RIGHT', Pixel.Scale(ROW.columnGap), Pixel.Scale(FORM.nameY))
	card.title:SetPoint('RIGHT', Pixel.Scale(-ROW.inset), Pixel.Scale(FORM.nameY))
	card.sub = Text(card, 10, 'skinLabel')
	card.sub:SetPoint('LEFT', card.icon, 'RIGHT', Pixel.Scale(ROW.columnGap), Pixel.Scale(FORM.subY))
	card.sub:SetPoint('RIGHT', Pixel.Scale(-ROW.inset), Pixel.Scale(FORM.subY))
	return card
end

function Listing.Summary(activity)
	wipe(tagParts)
	tagParts[1] = activity and activity.fullName or ''
	local style = STYLES[form.playstyle]
	if style then tagParts[#tagParts + 1] = style.label end
	if form.ilvl > 0 then tagParts[#tagParts + 1] = ('%d+ ilvl'):format(form.ilvl) end
	if activity and form.rating > 0 then
		if activity.isMythicPlusActivity then tagParts[#tagParts + 1] = ('%d+ score'):format(form.rating) end
		if activity.isRatedPvpActivity then tagParts[#tagParts + 1] = ('%d+ rating'):format(form.rating) end
	end
	if form.private then tagParts[#tagParts + 1] = 'Private' end
	return table.concat(tagParts, '  ·  ')
end

function Listing.PaintPreview(activity)
	local preview = listing.preview
	local title = Creation().Name:GetText()
	preview.icon:SetTexture(ActivityArt(form.activityID))
	preview.title:SetText(Plain(title) == '' and 'Your group title' or title)
	preview.sub:SetText(Listing.Summary(activity))
end

function Listing.NameEmpty()
	local text = Plain(Creation().Name:GetText())
	return text ~= nil and text:match('^%s*(.-)%s*$') == ''
end

function Listing.Problem(activity)
	if not activity then return 'Pick what the group is for.' end
	local maxPlayers = activity.maxNumPlayers or 0
	if maxPlayers > 0 and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) >= maxPlayers then return LFG_LIST_TOO_MANY_FOR_ACTIVITY:format(maxPlayers) end
	if form.playstyle == 0 then return GROUP_FINDER_PLAYSTYLE_REQUIRED end
	if activity.isMythicPlusActivity and not C_LFGList.IsPlayerAuthenticatedForLFG(activity.categoryID) and not C_LFGList.GetKeystoneForActivity(form.activityID) then
		return LFG_AUTHENTICATOR_BUTTON_MYTHIC_PLUS_TOOLTIP
	end
	if Listing.NameEmpty() then return LFG_LIST_MUST_HAVE_NAME end
	local itemLevel, _, pvpItemLevel = GetAverageItemLevel()
	if activity.isPvpActivity and form.ilvl > pvpItemLevel then return LFG_LIST_PVP_ILVL_ABOVE_YOURS end
	if not activity.isPvpActivity and form.ilvl > itemLevel then return LFG_LIST_ILVL_ABOVE_YOURS end
	if form.rating > 0 then
		if activity.isMythicPlusActivity and not C_LFGList.ValidateRequiredDungeonScore(form.rating) then return LFG_LIST_DUNGEON_SCORE_ABOVE_YOURS end
		if activity.isRatedPvpActivity and not C_LFGList.ValidateRequiredPvpRatingForActivity(form.activityID, form.rating) then return LFG_LIST_PVP_RATING_ABOVE_YOURS end
	end
	return LFGListUtil_GetActiveQueueMessage(false)
end

function Listing.KeyText()
	local mapID = form.category == Premade.DUNGEON_CATEGORY and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	if not mapID then return '' end
	return ('Your keystone  +%d %s'):format(C_MythicPlus.GetOwnedKeystoneLevel() or 0, C_ChallengeMode.GetMapUIInfo(mapID) or '')
end

function Listing.Paint()
	if not listing or not listing:IsShown() then return end
	local activity = form.activityID and C_LFGList.GetActivityInfoTable(form.activityID)
	for _, tile in ipairs(listing.tiles) do
		if tile:IsShown() then
			if tile.kind then Listing.PaintMoreTile(tile) end
			Strip.PaintTile(tile)
		end
	end
	for _, pool in ipairs(listing.pools) do
		for _, button in ipairs(pool) do
			if button:IsShown() then
				Panel.PaintToggle(button)
				button:SetAlpha(Listing.ToggleLocked(button) and ALPHA.dimmed or 1)
			end
		end
	end
	Panel.PaintNumber(listing.ilvlBox)
	Panel.PaintNumber(listing.ratingBox)
	Listing.MirrorField(listing.titleSlot)
	Listing.MirrorField(listing.descriptionSlot)
	Listing.PaintPreview(activity)
	local button = listing.listButton
	button.blocker = Listing.Problem(activity)
	button:SetAlpha((button.blocker or form.working) and ALPHA.dimmed or 1)
	button.label:SetText(form.working and 'Listing...' or form.editMode and 'Save changes' or 'List group')
	listing.keyText:SetText(Listing.KeyText())
end

function Listing.Submit(button)
	if form.working then return end
	if button.blocker then
		UIErrorsFrame:AddExternalErrorMessage(button.blocker)
		return
	end
	local activity = C_LFGList.GetActivityInfoTable(form.activityID)
	local category = C_LFGList.GetLfgCategoryInfo(form.category)
	local crossFaction = category.allowCrossFaction and activity.allowCrossFaction and not form.sameFaction or false
	local data = {
		activityIDs = { form.activityID },
		isAutoAccept = false,
		isCrossFactionListing = crossFaction,
		isPrivateGroup = form.private,
		playstyle = Enum.LFGEntryPlaystyle.None,
		generalPlaystyle = form.playstyle,
		requiredDungeonScore = activity.isMythicPlusActivity and form.rating or 0,
		requiredItemLevel = form.ilvl,
		requiredPvpRating = activity.isRatedPvpActivity and form.rating or 0,
	}
	local entry = form.editMode and C_LFGList.GetActiveEntryInfo()
	if entry then
		data.isAutoAccept, data.questID = entry.autoAccept, entry.questID
		if entry.isCrossFactionListing == crossFaction then
			C_LFGList.UpdateListing(data)
		else
			C_LFGList.RemoveListing()
			C_LFGList.CreateListing(data)
		end
		LFGListFrame_SetActivePanel(LFGListFrame, LFGListFrame.ApplicationViewer)
		return
	end
	if C_LFGList.CreateListing(data) then
		form.working = true
		ResetAppFilter()
		Creation().Name:ClearFocus()
		Creation().Description.EditBox:ClearFocus()
		Listing.Paint()
	end
end

function Listing.Back()
	Creation().CancelButton:Click()
end

function Listing.BuildMain(main)
	local y = FORM.pad
	Panel.Header(main, 'Title', FRAME.edge, y)
	listing.titleSlot = Listing.Field(main, FORM.titleH, LFG_LIST_ENTER_NAME, false)
	listing.titleSlot:SetPoint('TOPLEFT', Pixel.Scale(FRAME.edge), Pixel.Scale(-(y + FORM.header)))
	listing.titleSlot:SetPoint('RIGHT', Pixel.Scale(-FRAME.edge), 0)
	y = y + FORM.header + FORM.titleH + FORM.section
	Panel.Header(main, DESCRIPTION, FRAME.edge, y)
	listing.descriptionSlot = Listing.Field(main, FORM.descriptionH, DESCRIPTION_OF_YOUR_GROUP, true)
	listing.descriptionSlot:SetPoint('TOPLEFT', Pixel.Scale(FRAME.edge), Pixel.Scale(-(y + FORM.header)))
	listing.descriptionSlot:SetPoint('RIGHT', Pixel.Scale(-FRAME.edge), 0)
	y = y + FORM.header + FORM.descriptionH + FORM.section
	Panel.Header(main, 'Preview', FRAME.edge, y)
	listing.preview = Listing.Preview(main)
	listing.preview:SetPoint('TOPLEFT', Pixel.Scale(FRAME.edge), Pixel.Scale(-(y + FORM.header)))
	listing.preview:SetPoint('RIGHT', Pixel.Scale(-FRAME.edge), 0)

	local list = Skin.SmallButton(main, FORM.listW, BUTTON_H, '')
	list:SetPoint('BOTTOMRIGHT', Pixel.Scale(-FRAME.edge), Pixel.Scale(FRAME.footerY))
	list:SetScript('OnClick', Listing.Submit)
	list:HookScript('OnEnter', Premade.BlockerTip)
	list:HookScript('OnLeave', GameTooltip_Hide)
	listing.listButton = list
	local back = Skin.SmallButton(main, FORM.backW, BUTTON_H, 'Back')
	back:SetPoint('RIGHT', list, 'LEFT', Pixel.Scale(-BAR.gap), 0)
	back:SetScript('OnClick', Listing.Back)
	listing.keyText = Text(main, 11, 'skinLabel')
	listing.keyText:SetPoint('LEFT', main, 'BOTTOMLEFT', Pixel.Scale(FRAME.edge), Pixel.Scale(FRAME.footerY + BUTTON_H / 2))
end

function Listing.Build()
	if listing then return end
	listing = NewPage()
	listing.blizzard.kind = 'listing'
	listing.tiles, listing.activityToggles, listing.styleToggles = {}, {}, {}
	listing.pools = { listing.activityToggles, listing.styleToggles }
	local side = listing.side
	listing.activityHeader = Panel.Header(side, LFG_LIST_DIFFICULTY, SIDE.pad, 0)
	listing.styleHeader = Panel.Header(side, GROUP_FINDER_FILTER_PLAYSTYLE, SIDE.pad, 0)
	listing.ilvlHeader = Panel.Header(side, 'Min item level', SIDE.pad, 0)
	listing.ilvlBox = Panel.NumberBox(side, SIDE.ratingW, Listing.Ilvl, Listing.SetIlvl)
	listing.ratingHeader = Panel.Header(side, 'Min rating', SIDE.pad, 0)
	listing.ratingBox = Panel.NumberBox(side, SIDE.ratingW, Listing.Rating, Listing.SetRating)
	Listing.BuildMain(listing.main)
	listing.titleSlot.box, listing.descriptionSlot.box = Creation().Name, Creation().Description.EditBox
	Listing.BuildMore()
end

function Listing.Load()
	local creation = Creation()
	form.category = creation.selectedCategory
	form.filters = bit.bor(creation.baseFilters or 0, creation.selectedFilters or 0)
	form.editMode = LFGListEntryCreation_IsEditMode(creation) == true
	form.activityID, form.groupID = creation.selectedActivity, creation.selectedGroup
	form.playstyle = creation.generalPlaystyle or 0
	local itemLevel = creation.PvpItemLevel:IsShown() and creation.PvpItemLevel or creation.ItemLevel
	form.ilvl = tonumber(itemLevel.EditBox:GetText()) or 0
	form.rating = tonumber(creation.MythicPlusRating.EditBox:GetText()) or tonumber(creation.PVPRating.EditBox:GetText()) or 0
	form.private = form.editMode and creation.PrivateGroup.CheckButton:GetChecked() == true
	form.sameFaction = form.editMode and creation.CrossFactionGroup.CheckButton:GetChecked() == true
	form.working = false
	if form.playstyle == 0 then Listing.SetStyle(Enum.LFGEntryGeneralPlaystyle.FunSerious) end
	local category = C_LFGList.GetLfgCategoryInfo(form.category)
	local title = form.editMode and 'Edit your listing' or 'Start a group'
	listing.header:SetText((title .. '  ·  ' .. (category and category.name or '')):upper())
	finder.countText:SetText('')
	Listing.BuildChoices(category)
	Listing.LayoutTiles()
	Listing.Layout()
end

function Listing.OnEvent(event)
	if event == 'LFG_LIST_ENTRY_CREATION_FAILED' then form.working = false end
	QueuePaint()
end

function Listing.Shown()
	if skipped.listing then return end
	finder = Premade.Frame()
	Listing.Build()
	OpenPage(listing)
	Listing.Load()
	BUI.Events:Register('LFG_LIST_ENTRY_CREATION_FAILED', OWNER, Listing.OnEvent)
	BUI.Events:Register('GROUP_ROSTER_UPDATE', OWNER, Listing.OnEvent)
end

function Listing.Hidden()
	skipped.listing = nil
	ClosePage(listing)
end

function Applicants.RoleOn(button)
	return appFilter[button.item.key]
end

function Applicants.ToggleRole(button)
	local key = button.item.key
	local on = (appFilter.TANK and 1 or 0) + (appFilter.HEALER and 1 or 0) + (appFilter.DAMAGER and 1 or 0)
	if appFilter[key] and on == 1 then return end
	appFilter[key] = not appFilter[key]
	Applicants.Refresh()
end

function Applicants.CompOn(button)
	return appFilter.comp == button.item.key
end

function Applicants.ToggleComp(button)
	appFilter.comp = button.item.key
	Applicants.Refresh()
end

function Applicants.LustOn(button)
	return appFilter.lust == (button.item.key == 'lust')
end

function Applicants.ToggleLust(button)
	appFilter.lust = button.item.key == 'lust'
	Applicants.Refresh()
end

function Applicants.MinRating()
	return appFilter.rating
end

function Applicants.SetMinRating(value)
	appFilter.rating = value
	QueueApplicants()
end

function Applicants.MinIlvl()
	return appFilter.ilvl
end

function Applicants.SetMinIlvl(value)
	appFilter.ilvl = value
	QueueApplicants()
end

function Applicants.ResetFilters()
	ResetAppFilter()
	Applicants.Refresh()
end

function Applicants.AutoOn()
	local entry = C_LFGList.GetActiveEntryInfo()
	return entry ~= nil and entry.autoAccept == true
end

function Applicants.ToggleAuto()
	if IsLeader() then LFGListUtil_SetAutoAccept(not Applicants.AutoOn()) end
end

function Applicants.OnSort(item)
	appSort = item.sort
	Applicants.Refresh()
end

function Applicants.RefreshList()
	C_LFGList.RefreshApplicants()
end

function Applicants.Browse()
	LFGListFrame.ApplicationViewer.BrowseGroupsButton:Click()
end

function Applicants.Edit(button)
	if not button.blocker then LFGListFrame.ApplicationViewer.EditButton:Click() end
end

function Applicants.Delist()
	LFGListFrame.ApplicationViewer.RemoveEntryButton:Click()
end

function Applicants.ReadMember(applicantID, index, activityID, activity)
	local name, class, _, _, itemLevel, _, tank, healer, damage, role, relationship, score, pvpItemLevel, _, _, specID, isLeaver = C_LFGList.GetApplicantMemberInfo(applicantID, index)
	local member = {
		index = index, name = name, class = class, tank = tank, healer = healer, damage = damage, role = role,
		relationship = relationship, leaver = isLeaver, specID = Plain(specID), rating = 0, best = 0, timed = false,
		itemLevel = Plain(activity.isPvpActivity and pvpItemLevel or itemLevel) or 0,
	}
	local plain = Plain(name)
	member.realm = plain and (plain:match('%-(.+)$') or GetNormalizedRealmName())
	if member.realm then
		applicantRealms[member.realm] = (applicantRealms[member.realm] or 0) + 1
		member.region = REGIONS.split and (REGIONS.byRealm[(member.realm:lower():gsub('[%s%p]', ''))] or 'us') or nil
	end
	if activity.isRatedPvpActivity then
		local pvp = C_LFGList.GetApplicantPvpRatingInfoForListing(applicantID, index, activityID)
		member.rating = pvp and Plain(pvp.rating) or 0
		return member
	end
	member.rating = Plain(score) or 0
	if activity.isMythicPlusActivity then
		local best = C_LFGList.GetApplicantDungeonScoreForListing(applicantID, index, activityID)
		if best then member.best, member.timed = Plain(best.bestRunLevel) or 0, best.finishedSuccess == true end
	end
	return member
end

function Applicants.Keep(app)
	if app.status == 'invited' or app.status == 'inviteaccepted' then return true end
	local realms = Premade.Realms()
	local role, lust = false, false
	for _, member in ipairs(app.members) do
		if member.realm and realms.hidden[member.realm] then return false end
		if member.region and realms.hiddenRegions[member.region] then return false end
		if appFilter.rating > 0 and member.rating < appFilter.rating then return false end
		if appFilter.ilvl > 0 and member.itemLevel < appFilter.ilvl then return false end
		local damage = appFilter.comp ~= 'any' and member.role == 'DAMAGER' and member.specID and Comp.damage[member.specID]
		if damage and damage ~= appFilter.comp then return false end
		role = role or (member.tank and appFilter.TANK) or (member.healer and appFilter.HEALER) or (member.damage and appFilter.DAMAGER) or false
		lust = lust or LUST[member.class] == true
	end
	return role and (lust or not appFilter.lust)
end

function Applicants.Sort(left, right)
	local leftRank, rightRank = STATUS_RANK[left.status] or 3, STATUS_RANK[right.status] or 3
	if leftRank ~= rightRank then return leftRank < rightRank end
	if appSort ~= 'newest' then
		local key = appSort == 'ilvl' and 'itemLevel' or 'rating'
		local leftValue, rightValue = left.members[1][key], right.members[1][key]
		if leftValue ~= rightValue then return leftValue > rightValue end
	end
	return (left.info.displayOrderID or left.id) > (right.info.displayOrderID or right.id)
end

function Applicants.Collect(activityID, activity)
	wipe(shown)
	wipe(applicantRealms)
	local total, hidden = 0, 0
	for _, applicantID in ipairs(C_LFGList.GetApplicants()) do
		local info = C_LFGList.GetApplicantInfo(applicantID)
		if info then
			total = total + 1
			local app = { id = applicantID, info = info, status = info.applicationStatus, members = {} }
			for index = 1, info.numMembers do app.members[index] = Applicants.ReadMember(applicantID, index, activityID, activity) end
			if Applicants.Keep(app) then
				shown[#shown + 1] = app
			else
				hidden = hidden + 1
			end
		end
	end
	table.sort(shown, Applicants.Sort)
	return total, hidden
end

function Applicants.MemberEnter(line)
	Pixel.SetBorderColor(line:GetParent(), unpack(Skin.HoverColor()))
	LFGListApplicantMember_OnEnter(line)
	local realm = line.realm
	if not realm or not GameTooltip:IsOwned(line) then return end
	local labelR, labelG, labelB = Painter.Color('skinLabel')
	local valueR, valueG, valueB = Painter.Color('skinTitle')
	if Premade.Realms().flagged[realm] then valueR, valueG, valueB = BUI.ThemeColor('danger') end
	GameTooltip:AddLine(' ')
	GameTooltip:AddDoubleLine('Server', realm, labelR, labelG, labelB, valueR, valueG, valueB)
	GameTooltip:AddLine('Right-click to hide or flag this server', labelR, labelG, labelB)
	GameTooltip:Show()
end

function Applicants.MemberLeave(line)
	Pixel.SetBorderColor(line:GetParent(), unpack(PALETTE.edge))
	GameTooltip:Hide()
end

function Applicants.MemberMenu(line)
	local applicantID = line:GetParent().applicantID
	local name = Plain((C_LFGList.GetApplicantMemberInfo(applicantID, line.memberIdx)))
	if not name then return end
	local realm = name:match('%-(.+)$') or GetNormalizedRealmName()
	local realms = Premade.Realms()
	Skin.ContextMenu({
		{ title = Ambiguate(name, 'short') },
		{ text = WHISPER, callback = function() ChatFrameUtil.SendTell(name) end },
		{ text = 'Ignore and decline', callback = function()
			C_FriendList.AddIgnore(name)
			C_LFGList.DeclineApplicant(applicantID)
		end },
		{ title = realm },
		{ text = 'Hide applicants from this server', checked = realms.hidden[realm] == true, callback = function() Premade.ToggleHidden(realm) end },
		{ text = 'Flag this server', checked = realms.flagged[realm] == true, callback = function() Premade.ToggleFlagged(realm) end },
	}, { atCursor = true, width = Premade.MENU_W })
end

function Applicants.SwitchRole(button)
	local line = button:GetParent()
	C_LFGList.SetApplicantMemberRole(line:GetParent().applicantID, line.memberIdx, button.role)
end

function Applicants.RoleEnter(button)
	GameTooltip:SetOwner(button, 'ANCHOR_TOP')
	GameTooltip:SetText(button:IsEnabled() and ('Switch to ' .. ROLE_NAMES[button.role]) or ROLE_NAMES[button.role])
	GameTooltip:Show()
end

function Applicants.Line(card, index)
	local line = CreateFrame('Button', nil, card)
	line:SetHeight(Pixel.Scale(APPS.memberH))
	line:SetPoint('TOPLEFT', 0, -Pixel.Scale(APPS.pad + (index - 1) * APPS.memberH))
	line:SetPoint('RIGHT', Pixel.Scale(-APPS.actionsW), 0)
	line.memberIdx = index
	line.roles = {}
	for slot = 1, #ROLES do
		local button = CreateFrame('Button', nil, line)
		button:SetSize(Pixel.Scale(APPS.roleIcon), Pixel.Scale(APPS.roleIcon))
		button:SetPoint('LEFT', Pixel.Scale(ROW.inset + (slot - 1) * (APPS.roleIcon + APPS.roleGap)), 0)
		button:SetMotionScriptsWhileDisabled(true)
		button.icon = button:CreateTexture(nil, 'ARTWORK')
		button.icon:SetAllPoints()
		button:SetScript('OnClick', Applicants.SwitchRole)
		button:SetScript('OnEnter', Applicants.RoleEnter)
		button:SetScript('OnLeave', GameTooltip_Hide)
		line.roles[slot] = button
	end
	line.spec = line:CreateTexture(nil, 'ARTWORK')
	line.spec:SetSize(Pixel.Scale(APPS.specIcon), Pixel.Scale(APPS.specIcon))
	line.spec:SetPoint('LEFT', Pixel.Scale(APPS.specX), 0)
	Skin.SquareIcon(line, line.spec, 1)
	line.name = Text(line, 12, 'skinText')
	line.name:SetPoint('LEFT', Pixel.Scale(APPS.nameX), 0)
	line.name:SetWidth(Pixel.Scale(APPS.nameW))
	line.best = Text(line, 11, 'skinText', 'RIGHT')
	line.best:SetPoint('RIGHT')
	line.best:SetWidth(Pixel.Scale(APPS.bestW))
	line.rating = Text(line, 12, 'skinTitle', 'RIGHT')
	line.rating:SetPoint('RIGHT', line.best, 'LEFT', Pixel.Scale(-APPS.columnGap), 0)
	line.rating:SetWidth(Pixel.Scale(APPS.ratingW))
	line.ilvl = Text(line, 11, 'skinText', 'RIGHT')
	line.ilvl:SetPoint('RIGHT', line.rating, 'LEFT', Pixel.Scale(-APPS.columnGap), 0)
	line.ilvl:SetWidth(Pixel.Scale(APPS.ilvlW))
	line.tags = Text(line, 10, 'skinLabel')
	line.tags:SetPoint('LEFT', line.name, 'RIGHT', Pixel.Scale(APPS.columnGap), 0)
	line.tags:SetPoint('RIGHT', line.ilvl, 'LEFT', Pixel.Scale(-APPS.columnGap), 0)
	line:RegisterForClicks('RightButtonUp')
	line:SetScript('OnClick', Applicants.MemberMenu)
	line:SetScript('OnEnter', Applicants.MemberEnter)
	line:SetScript('OnLeave', Applicants.MemberLeave)
	return line
end

function Applicants.FillRoles(line, member, status)
	local slot = 0
	for _, role in ipairs(ROLES) do
		if member[ROLE_FIELD[role]] then
			slot = slot + 1
			local button = line.roles[slot]
			local assigned = member.role == role
			button.role = role
			button.icon:SetAtlas(ROLE_ATLAS[role])
			button.icon:SetAlpha(assigned and 1 or ALPHA.emptyRole)
			button:SetEnabled(not assigned and status == 'applied')
			button:Show()
		end
	end
	for index = slot + 1, #line.roles do line.roles[index]:Hide() end
end

function Applicants.NameText(member)
	local name = Plain(member.name)
	if not name then return member.name or '' end
	local color = member.class and RAID_CLASS_COLORS[member.class]
	local text = Ambiguate(name, 'short')
	if color then text = color:WrapTextInColorCode(text) end
	if not member.realm or not Settings().showServer then return text end
	local flagged = Premade.Realms().flagged[member.realm]
	return text .. '  ' .. Colored(flagged and 'danger' or 'skinLabel', member.realm)
end

function Applicants.FillLine(line, member, status, activity)
	Applicants.FillRoles(line, member, status)
	local specName, icon
	if member.specID then
		local _, name, _, specIcon = GetSpecializationInfoByID(member.specID)
		specName, icon = name, specIcon
	end
	line.spec:SetTexture(icon or FALLBACK_ICON)
	line.realm = member.realm
	line.name:SetText(Applicants.NameText(member))
	wipe(tagParts)
	if specName then tagParts[1] = specName end
	local damage = member.role == 'DAMAGER' and member.specID and Comp.damage[member.specID]
	if damage then tagParts[#tagParts + 1] = Comp.labels[damage] end
	if LUST[member.class] then tagParts[#tagParts + 1] = Colored('positive', 'Lust') end
	if member.relationship then tagParts[#tagParts + 1] = member.relationship == 'guild' and 'Guild' or 'Friend' end
	if member.leaver then tagParts[#tagParts + 1] = Colored('danger', 'Leaver') end
	line.tags:SetText(table.concat(tagParts, '  ·  '))
	line.ilvl:SetText(member.itemLevel > 0 and math.floor(member.itemLevel) or '')
	if member.rating > 0 and activity.isMythicPlusActivity then
		line.rating:SetText(C_ChallengeMode.GetDungeonScoreRarityColor(member.rating):WrapTextInColorCode(member.rating))
	else
		line.rating:SetText(member.rating > 0 and activity.isRatedPvpActivity and member.rating or '')
	end
	if member.best > 0 then
		line.best:SetText(('+%d'):format(member.best))
		Painter.Text(line.best, member.timed and 'skinText' or 'skinLabel')
	else
		line.best:SetText('')
	end
end

function Applicants.Invite(button)
	if button.blocker then return end
	local card = button:GetParent()
	local members = math.max(1, GetNumGroupMembers(LE_PARTY_CATEGORY_HOME))
	if not IsInRaid(LE_PARTY_CATEGORY_HOME) and members + card.numMembers + C_LFGList.GetNumInvitedApplicantMembers() > MAX_PARTY_MEMBERS + 1 then
		StaticPopup_Show('LFG_LIST_INVITING_CONVERT_TO_RAID', nil, nil, card.applicantID)
	else
		C_LFGList.InviteApplicant(card.applicantID)
	end
end

function Applicants.Decline(button)
	C_LFGList.DeclineApplicant(button:GetParent().applicantID)
end

function Applicants.Clear(button)
	C_LFGList.RemoveApplicant(button.card.applicantID)
end

function Applicants.ClearEnter(button)
	button.glyph:SetVertexColor(unpack(Skin.HoverColor()))
end

function Applicants.ClearLeave(button)
	Painter.Tint(button.glyph, 'skinLabel')
end

function Applicants.Card(parent)
	local card = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	Skin.PaintBackdrop(card, PALETTE.card)
	card.lines = {}
	card.decline = Skin.SmallButton(card, APPS.declineW, BUTTON_H, DECLINE)
	card.decline:SetPoint('RIGHT', Pixel.Scale(-ROW.inset), 0)
	card.decline:SetScript('OnClick', Applicants.Decline)
	card.invite = Skin.SmallButton(card, APPS.inviteW, BUTTON_H, INVITE)
	card.invite:SetPoint('RIGHT', card.decline, 'LEFT', Pixel.Scale(-APPS.actionGap), 0)
	card.invite:SetScript('OnClick', Applicants.Invite)
	card.invite:HookScript('OnEnter', Premade.BlockerTip)
	card.invite:HookScript('OnLeave', GameTooltip_Hide)
	card.status = Text(card, 11, 'skinTitle', 'RIGHT')
	card.status:SetPoint('RIGHT', Pixel.Scale(-ROW.inset * 2), 0)
	card.cover = Strip.Cover(card)
	card.clear = CreateFrame('Button', nil, card.cover)
	card.clear:SetSize(Pixel.Scale(APPS.clearSize), Pixel.Scale(APPS.clearSize))
	card.clear:SetPoint('RIGHT', Pixel.Scale(-ROW.inset * 2), 0)
	card.clear.card = card
	card.clear.glyph = card.clear:CreateTexture(nil, 'ARTWORK')
	card.clear.glyph:SetAllPoints()
	BUILib.Widget.SetGlyph(card.clear.glyph, BUILib.GetLibMedia('x'))
	Painter.Tint(card.clear.glyph, 'skinLabel')
	card.clear:SetScript('OnClick', Applicants.Clear)
	card.clear:SetScript('OnEnter', Applicants.ClearEnter)
	card.clear:SetScript('OnLeave', Applicants.ClearLeave)
	return card
end

function Applicants.StatusText(status, pending)
	if pending == 'invited' then return 'Inviting...' end
	if pending then return 'Updating...' end
	return APP_STATUS[status] or ''
end

function Applicants.FillCard(card, app, activity, empowered, free, room)
	local info, status = app.info, app.status
	card.applicantID, card.numMembers = app.id, info.numMembers
	for index = 1, info.numMembers do
		local line = card.lines[index] or Applicants.Line(card, index)
		card.lines[index] = line
		Applicants.FillLine(line, app.members[index], status, activity)
		line:Show()
	end
	for index = info.numMembers + 1, #card.lines do card.lines[index]:Hide() end
	local pending = info.pendingApplicationStatus
	local done = APP_DONE[status] == true and not pending
	local open = empowered and status == 'applied' and not pending
	card.invite:SetShown(open)
	card.decline:SetShown(open)
	local blocker
	if info.numMembers > room then
		blocker = LFG_LIST_GROUP_TOO_FULL
	elseif info.numMembers > free then
		blocker = LFG_LIST_INVITED_APP_FILLS_GROUP
	end
	card.invite.blocker = blocker
	card.invite:SetAlpha(blocker and ALPHA.dimmed or 1)
	card.status:SetText(not open and not done and Applicants.StatusText(status, pending) or '')
	Painter.Text(card.status, status == 'invited' and 'positive' or 'skinTitle')
	card.cover:SetShown(done)
	card.cover.label:SetText(done and APP_STATUS[status]:upper() or '')
	card.clear:SetShown(done and empowered)
	for _, line in ipairs(card.lines) do line:SetAlpha(done and ALPHA.dimmed or 1) end
end

function Applicants.Populate(activity, empowered)
	local maxPlayers = activity.maxNumPlayers or 0
	local allowed = maxPlayers > 0 and maxPlayers or MAX_RAID_MEMBERS
	local room = allowed - math.max(1, GetNumGroupMembers(LE_PARTY_CATEGORY_HOME))
	local free = room - C_LFGList.GetNumInvitedApplicantMembers()
	local y = 0
	for index, app in ipairs(shown) do
		local card = cards[index]
		if not card then
			card = Applicants.Card(applicants.child)
			cards[index] = card
		end
		local height = app.info.numMembers * APPS.memberH + APPS.pad * 2
		card:SetHeight(Pixel.Scale(height))
		card:ClearAllPoints()
		card:SetPoint('TOPLEFT', 0, -Pixel.Scale(y))
		card:SetPoint('RIGHT')
		Applicants.FillCard(card, app, activity, empowered, free, room)
		card:Show()
		y = y + height + ROW.pad
	end
	for index = #shown + 1, #cards do cards[index]:Hide() end
	applicants.child:SetHeight(math.max(1, Pixel.Scale(y)))
end

function Applicants.PaintGroup(card, activity)
	for _, list in pairs(groupRoles) do wipe(list) end
	local raid = IsInRaid(LE_PARTY_CATEGORY_HOME)
	local count = raid and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) or GetNumSubgroupMembers(LE_PARTY_CATEGORY_HOME) + 1
	for index = 1, count do
		local unit = raid and ('raid' .. index) or (index == 1 and 'player' or ('party' .. (index - 1)))
		local role = UnitGroupRolesAssigned(unit)
		if role == 'NONE' and UnitIsUnit(unit, 'player') then
			local spec = C_SpecializationInfo.GetSpecialization()
			role = spec and GetSpecializationRole(spec) or role
		end
		local _, classFile = UnitClass(unit)
		local list = groupRoles[role] or groupRoles.DAMAGER
		list[#list + 1] = classFile
	end
	local maxPlayers = activity.maxNumPlayers or 0
	local small = not raid and maxPlayers > 0 and maxPlayers <= #SLOT_ROLES
	for index, slot in ipairs(card.slots) do
		slot:SetShown(small)
		if small then Premade.PaintSlot(slot, groupRoles[SLOT_ROLES[index]][SLOT_RANK[index]]) end
	end
	card.roleText:SetShown(not small)
	card.roleText:SetText(('%d tanks  ·  %d healers  ·  %d damage'):format(#groupRoles.TANK, #groupRoles.HEALER, #groupRoles.DAMAGER))
end

function Applicants.PaintCard(entry, activity)
	local card = applicants.card
	card.icon:SetTexture(ActivityArt(entry.activityIDs[1]))
	card.title:SetText(entry.censored and Premade.CENSORED_TITLE or entry.name)
	wipe(tagParts)
	tagParts[1] = activity.fullName
	local style = STYLES[entry.generalPlaystyle]
	if style then tagParts[#tagParts + 1] = style.label end
	if entry.requiredItemLevel > 0 then tagParts[#tagParts + 1] = ('%d+ ilvl'):format(entry.requiredItemLevel) end
	if (entry.requiredDungeonScore or 0) > 0 then tagParts[#tagParts + 1] = ('%d+ score'):format(entry.requiredDungeonScore) end
	if (entry.requiredPvpRating or 0) > 0 then tagParts[#tagParts + 1] = ('%d+ rating'):format(entry.requiredPvpRating) end
	if entry.privateGroup then tagParts[#tagParts + 1] = 'Private' end
	if entry.autoAccept then tagParts[#tagParts + 1] = 'Auto accept' end
	card.sub:SetText(table.concat(tagParts, '  ·  '))
	card.comment:SetText(not entry.censored and entry.comment or '')
	Applicants.PaintGroup(card, activity)
end

function Applicants.Message(total, empowered)
	if Locked() then return 'Applicants show again once the encounter ends.' end
	if not empowered then return 'Only the leader or an assistant can see applicants.' end
	if total == 0 then return 'No applicants yet.' end
	if #shown == 0 then return 'No applicants match your filters.' end
end

function Applicants.Refresh()
	if not applicants or not applicants:IsShown() then return end
	local entry = C_LFGList.GetActiveEntryInfo()
	local activityID = entry and entry.activityIDs[1]
	local activity = activityID and C_LFGList.GetActivityInfoTable(activityID)
	if not activity then return end
	local category = C_LFGList.GetLfgCategoryInfo(activity.categoryID)
	applicants.header:SetText(('Your listing  ·  ' .. (category and category.name or '')):upper())
	Applicants.PaintCard(entry, activity)
	local side = applicants.side
	for _, button in ipairs(side.toggles) do Panel.PaintToggle(button) end
	Panel.PaintNumber(side.ratingBox)
	Panel.PaintNumber(side.ilvlBox)
	side.servers.value:SetText(Premade.ServersSummary())
	local leader, empowered = IsLeader(), Empowered()
	applicants.auto:SetShown(C_LFGList.CanActiveEntryUseAutoAccept() and empowered)
	applicants.auto:SetAlpha(leader and 1 or ALPHA.dimmed)
	Panel.PaintToggle(applicants.auto)
	for _, button in ipairs(applicants.leaderButtons) do button:SetShown(leader) end
	applicants.edit.blocker = IsRestrictedAccount() and ERR_RESTRICTED_ACCOUNT_LFG_LIST_TRIAL or nil
	applicants.edit:SetAlpha(applicants.edit.blocker and ALPHA.dimmed or 1)
	applicants.ratingHeader:SetShown(activity.isMythicPlusActivity or activity.isRatedPvpActivity)
	applicants.bestHeader:SetShown(activity.isMythicPlusActivity)
	local total, hidden = 0, 0
	if empowered and not Locked() then
		total, hidden = Applicants.Collect(activityID, activity)
	else
		wipe(shown)
		wipe(applicantRealms)
	end
	Applicants.Populate(activity, empowered)
	local message = Applicants.Message(total, empowered)
	applicants.emptyText:SetText(message or '')
	applicants.emptyText:SetShown(message ~= nil)
	local count = #shown == 1 and '1 applicant' or (#shown .. ' applicants')
	applicants.countText:SetText(hidden > 0 and ('%s  ·  %d hidden by filters'):format(count, hidden) or count)
	finder.countText:SetText(count)
	local pop = applicants.serversPop
	if pop and pop:IsShown() then pop:Refresh() end
end

function Applicants.BuildCard(page)
	local card = CreateFrame('Frame', nil, page, 'BackdropTemplate')
	local y = STRIP.top + STRIP.header
	card:SetPoint('TOPLEFT', Pixel.Scale(FRAME.edge), Pixel.Scale(-y))
	card:SetPoint('TOPRIGHT', Pixel.Scale(-FRAME.edge), Pixel.Scale(-y))
	card:SetHeight(Pixel.Scale(APPS.cardH))
	Skin.PaintBackdrop(card, PALETTE.card)
	card.icon = card:CreateTexture(nil, 'ARTWORK')
	card.icon:SetSize(Pixel.Scale(APPS.art), Pixel.Scale(APPS.art))
	card.icon:SetPoint('LEFT', Pixel.Scale(APPS.artInset), 0)
	Skin.SquareIcon(card, card.icon, 1)
	card.title = Text(card, 13, 'skinTitle')
	card.title:SetPoint('LEFT', Pixel.Scale(APPS.textX), Pixel.Scale(APPS.titleY))
	card.title:SetPoint('RIGHT', Pixel.Scale(-APPS.textRight), Pixel.Scale(APPS.titleY))
	card.sub = Text(card, 10, 'skinLabel')
	card.sub:SetPoint('LEFT', Pixel.Scale(APPS.textX), 0)
	card.sub:SetPoint('RIGHT', Pixel.Scale(-APPS.textRight), 0)
	card.comment = Text(card, 10, 'skinText')
	card.comment:SetPoint('LEFT', Pixel.Scale(APPS.textX), Pixel.Scale(APPS.commentY))
	card.comment:SetPoint('RIGHT', Pixel.Scale(-APPS.textRight), Pixel.Scale(APPS.commentY))
	card.slots = {}
	for index, role in ipairs(SLOT_ROLES) do
		local slot = Premade.CreateSlot(card, role)
		slot:SetPoint('RIGHT', Pixel.Scale(-(APPS.artInset + (#SLOT_ROLES - index) * (ROW.slot + ROW.slotGap))), 0)
		card.slots[index] = slot
	end
	card.roleText = Text(card, 11, 'skinText', 'RIGHT')
	card.roleText:SetPoint('RIGHT', Pixel.Scale(-APPS.artInset), 0)
	page.card = card
	return y + APPS.cardH
end

function Applicants.BuildSide(side)
	side.toggles = {}
	local y = SIDE.pad
	Panel.Header(side, ROLE, SIDE.pad, y)
	local reset = Panel.LinkButton(side, RESET, Applicants.ResetFilters)
	reset:SetPoint('RIGHT', side, 'TOPRIGHT', Pixel.Scale(-SIDE.pad), Pixel.Scale(-(y + POP.headerMid)))
	y = Strip.ToggleGrid(side, ROLE_ITEMS, #ROLE_ITEMS, SIDE.toggleH, y + SIDE.header, Applicants.RoleOn, Applicants.ToggleRole) + SIDE.section
	Panel.Header(side, 'Comp', SIDE.pad, y)
	y = Strip.ToggleGrid(side, Comp.choices, #Comp.choices, SIDE.toggleH, y + SIDE.header, Applicants.CompOn, Applicants.ToggleComp) + SIDE.section
	Panel.Header(side, 'Lust', SIDE.pad, y)
	y = Strip.ToggleGrid(side, LUST_ITEMS, #LUST_ITEMS, SIDE.toggleH, y + SIDE.header, Applicants.LustOn, Applicants.ToggleLust) + SIDE.section
	Panel.Header(side, 'Min rating', SIDE.pad, y + BUTTON_H / 2 - POP.headerMid)
	side.ratingBox = Panel.NumberBox(side, SIDE.ratingW, Applicants.MinRating, Applicants.SetMinRating)
	side.ratingBox:SetPoint('TOPRIGHT', side, 'TOPLEFT', Pixel.Scale(FRAME.sideW - SIDE.pad), Pixel.Scale(-y))
	y = y + BUTTON_H + SIDE.section
	Panel.Header(side, 'Min item level', SIDE.pad, y + BUTTON_H / 2 - POP.headerMid)
	side.ilvlBox = Panel.NumberBox(side, SIDE.ratingW, Applicants.MinIlvl, Applicants.SetMinIlvl)
	side.ilvlBox:SetPoint('TOPRIGHT', side, 'TOPLEFT', Pixel.Scale(FRAME.sideW - SIDE.pad), Pixel.Scale(-y))
	y = y + BUTTON_H + SIDE.section
	if REGIONS.split then
		Panel.Header(side, 'Region', SIDE.pad, y)
		Strip.ToggleGrid(side, REGIONS, 2, SIDE.toggleH, y + SIDE.header, Panel.RegionOn, Panel.ToggleRegion)
	end
	side.servers = Strip.ServersButton(side, 'applicantServers')
	side.servers:SetPoint('BOTTOMLEFT', applicants.blizzard, 'TOPLEFT', 0, Pixel.Scale(SIDE.toggleGap))
end

function Applicants.BuildServers(kind)
	applicants.serversPop = Panel.BuildServers(kind)
	return applicants.serversPop
end

Panel.SERVER_LISTS.applicantServers = {
	counts = applicantRealms, noun = 'applicant', absent = 'Not applying', empty = 'No applicants yet.',
	header = 'Servers applying',
}
Panel.BUILDERS.applicantServers = Applicants.BuildServers
Panel.onRealmsChanged = QueueApplicants

function Applicants.ColumnLabel(header, text, point, offset)
	local label = Text(header, 10, 'skinLabel', point)
	label:SetPoint(point, Pixel.Scale(offset), 0)
	label:SetText(text:upper())
	return label
end

function Applicants.BuildColumns(scroll)
	local header = CreateFrame('Frame', nil, scroll:GetParent())
	header:SetPoint('BOTTOMLEFT', scroll, 'TOPLEFT', 0, Pixel.Scale(APPS.headerGap))
	header:SetPoint('BOTTOMRIGHT', scroll, 'TOPRIGHT', 0, Pixel.Scale(APPS.headerGap))
	header:SetHeight(Pixel.Scale(APPS.headerH - APPS.headerGap))
	Applicants.ColumnLabel(header, NAME, 'LEFT', APPS.nameX)
	applicants.bestHeader = Applicants.ColumnLabel(header, 'Best', 'RIGHT', -APPS.actionsW)
	applicants.ratingHeader = Applicants.ColumnLabel(header, 'Rating', 'RIGHT', -(APPS.actionsW + APPS.bestW + APPS.columnGap))
	Applicants.ColumnLabel(header, 'Item level', 'RIGHT', -(APPS.actionsW + APPS.bestW + APPS.ratingW + APPS.columnGap * 2))
end

function Applicants.FooterButton(main, width, label, onClick, anchor)
	local button = Skin.SmallButton(main, width, BUTTON_H, label)
	if anchor then
		button:SetPoint('RIGHT', anchor, 'LEFT', Pixel.Scale(-BAR.gap), 0)
	else
		button:SetPoint('BOTTOMRIGHT', Pixel.Scale(-FRAME.edge), Pixel.Scale(FRAME.footerY))
	end
	button:SetScript('OnClick', onClick)
	return button
end

function Applicants.BuildMain(main)
	local refresh = Strip.GlyphButton(main, 'reload', 'Refresh applicants', Applicants.RefreshList)
	refresh:SetPoint('TOPLEFT', Pixel.Scale(FRAME.edge), Pixel.Scale(-FRAME.toolbarY))
	local sort = Skin.CreateDropdown(main, APP_SORTS, Applicants.OnSort, APPS.sortW)
	sort:SetPoint('LEFT', refresh, 'RIGHT', Pixel.Scale(BAR.gap), 0)
	applicants.auto = Panel.Toggle(main, APPS.autoW, BUTTON_H, AUTO_ITEM, nil, Applicants.AutoOn, Applicants.ToggleAuto)
	applicants.auto:SetPoint('TOPRIGHT', Pixel.Scale(-FRAME.edge), Pixel.Scale(-FRAME.toolbarY))

	local area = CreateFrame('Frame', nil, main)
	area:SetPoint('TOPLEFT', Pixel.Scale(FRAME.edge - FRAME.scrollPad), Pixel.Scale(-(FRAME.listTop + APPS.headerH)))
	area:SetPoint('BOTTOMRIGHT', Pixel.Scale(FRAME.scrollPad - FRAME.edge), Pixel.Scale(FRAME.listBottom))
	applicants.scroll, applicants.child = Skin.CreateScrollArea(area, APPS.memberH, FRAME.scrollPad)
	applicants.emptyText = Skin.CreateEmptyText(main, area)
	Applicants.BuildColumns(applicants.scroll)

	applicants.countText = Text(main, 11, 'skinLabel')
	applicants.countText:SetPoint('LEFT', main, 'BOTTOMLEFT', Pixel.Scale(FRAME.edge), Pixel.Scale(FRAME.footerY + BUTTON_H / 2))
	local browse = Applicants.FooterButton(main, APPS.browseW, 'Browse groups', Applicants.Browse)
	applicants.edit = Applicants.FooterButton(main, APPS.editW, 'Edit', Applicants.Edit, browse)
	applicants.edit:HookScript('OnEnter', Premade.BlockerTip)
	applicants.edit:HookScript('OnLeave', GameTooltip_Hide)
	local delist = Applicants.FooterButton(main, APPS.editW, 'Delist', Applicants.Delist, applicants.edit)
	applicants.leaderButtons = { browse, applicants.edit, delist }
end

function Applicants.Build()
	if applicants then return end
	applicants = NewPage()
	applicants.blizzard.kind = 'applicants'
	PlaceBody(applicants, Applicants.BuildCard(applicants) + STRIP.divider + 1)
	Applicants.BuildSide(applicants.side)
	Applicants.BuildMain(applicants.main)
end

function Applicants.Shown()
	if skipped.applicants then return end
	finder = Premade.Frame()
	Applicants.Build()
	OpenPage(applicants)
	for _, event in ipairs(APP_EVENTS) do BUI.Events:Register(event, OWNER, QueueApplicants) end
	Applicants.Refresh()
end

function Applicants.Hidden()
	skipped.applicants = nil
	ClosePage(applicants)
end

context.Window('LFGListFrame', {
	install = function(frame)
		local creation, viewer = frame.EntryCreation, frame.ApplicationViewer
		creation:HookScript('OnShow', context.Guard(Listing.Shown))
		creation:HookScript('OnHide', context.Guard(Listing.Hidden))
		viewer:HookScript('OnShow', context.Guard(Applicants.Shown))
		viewer:HookScript('OnHide', context.Guard(Applicants.Hidden))
		for _, box in ipairs({ creation.Name, creation.Description.EditBox }) do
			box:HookScript('OnTextChanged', QueuePaint)
			box:HookScript('OnEditFocusGained', QueuePaint)
			box:HookScript('OnEditFocusLost', QueuePaint)
			box:HookScript('OnCursorChanged', QueuePaint)
		end
	end,
})

context.OnDisable(function()
	wipe(skipped)
	ClosePage(listing, true)
	ClosePage(applicants, true)
end)
