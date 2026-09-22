local _, BUI = ...
local SetScript, HookScript = BUI.Prof.Scripts('Settings.Settings')
local AceHook = LibStub('AceHook-3.0')

local Pixel = BUI.Pixel
local BUILib = BluUI.BUILibClient
local Controls = BUILib.Controls
local Widget = BUILib.Widget
BUI.Settings = {}
local Settings = BUI.Settings
local ActiveToggles = {}

local LastLoot = 0

local function EventToggle(key, events, handler, cleanup)
    local eventList = type(events) == "string" and { events } or events
    local toggleKey = 'Settings.' .. key
    return function(_, enabled)
        if enabled then
            if ActiveToggles[key] then return end
            ActiveToggles[key] = true
            for _, eventName in ipairs(eventList) do
                BUI.Events:Register(eventName, toggleKey, handler)
            end
        else
            if ActiveToggles[key] then
                BUI.Events:UnregisterAll(toggleKey)
                ActiveToggles[key] = nil
            end
            if cleanup then cleanup() end
        end
    end
end

local function HideFrameToggle(key, getFrame)
    return function(_, enabled)
        local frame = getFrame()
        if not frame then return end
        if enabled then
            frame:Hide()
            if not AceHook.IsHooked(BUI, frame, "OnShow") then
                AceHook.HookScript(BUI, frame, "OnShow", BUI.Prof.Wrap('Settings#OnShow', function(self) self:Hide() end))
            end
        else
            if AceHook.IsHooked(BUI, frame, "OnShow") then AceHook.Unhook(BUI, frame, "OnShow") end
        end
    end
end

local function CVarToggle(cvar)
    return function(_, enabled)
        if (not InCombatLockdown()) then
            C_CVar.SetCVar(cvar, enabled and "1" or "0")
        end
    end
end

Settings.ToggleFasterLooting = EventToggle("loot", {"LOOT_READY", "LOOT_BIND_CONFIRM"}, function(event, ...)
    if event == "LOOT_BIND_CONFIRM" then
        ConfirmLootSlot(...)
        StaticPopup_Hide("LOOT_BIND")
        return
    end
    local now = GetTime()
    if (now - LastLoot >= 0.3 and GetNumLootItems() > 0) then
        LastLoot = now
        for lootSlotIndex = GetNumLootItems(), 1, -1 do
            LootSlot(lootSlotIndex)
        end
    end
end, function()
    LastLoot = 0
end)

local function StripRealm(name)
	return name and (strsplit('-', name, 2))
end

local function IsBNetFriend(name, guid)
	local numFriends = BNGetNumFriends()
	for friendIndex = 1, numFriends do
		local numAccounts = C_BattleNet.GetFriendNumGameAccounts(friendIndex)
		for accountIndex = 1, numAccounts do
			local info = C_BattleNet.GetFriendGameAccountInfo(friendIndex, accountIndex)
			if info and info.clientProgram == 'WoW' then
				if guid and info.playerGuid and info.playerGuid == guid then return true end
				if info.characterName == name then return true end
			end
		end
	end
	return false
end

local function IsGuildMember(name, guid)
	if not IsInGuild() then return false end
	local count = GetNumGuildMembers()
	for memberIndex = 1, count do
		local memberName, _, _, _, _, _, _, _, online, _, _, _, _, _, _, _, memberGUID = GetGuildRosterInfo(memberIndex)
		if online and memberName then
			if guid and memberGUID and memberGUID == guid then return true end
			if StripRealm(memberName) == name then return true end
		end
	end
	return false
end

local function IsInLFGQueue()
	for _, category in ipairs({ LE_LFG_CATEGORY_LFD, LE_LFG_CATEGORY_LFR, LE_LFG_CATEGORY_RF,
	                        LE_LFG_CATEGORY_SCENARIO, LE_LFG_CATEGORY_FLEXRAID }) do
		if GetLFGMode(category) then return true end
	end
	return false
end

function Settings.IsFriendly(fullName, guid)
	if not fullName then return false end
	local name = StripRealm(fullName)
	if not name or name == '' then return false end
	C_FriendList.ShowFriends()
	if IsBNetFriend(name, guid) then return true end
	local db = BUI.GetDB()
	if db.social.includeGuild and IsGuildMember(name, guid) then return true end
	return false
end

Settings.ToggleAutoRepair = EventToggle('repair', 'MERCHANT_SHOW', function()
	if IsShiftKeyDown() then return end
	if not CanMerchantRepair() then return end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or cost == 0 then return end
	local db = BUI.GetDB()
	local usedGuild = false
	if db.automation.autoRepairGuildFunds and IsInGuild() and CanGuildBankRepair() then
		RepairAllItems(1)
		usedGuild = true
	end
	RepairAllItems()
	if db.automation.autoRepairShowSummary then
		local fundsSuffix = usedGuild and ' (guild)' or ''
		print('|cff6D00FDBluUI:|r Repaired for ' .. GetCoinTextureString(cost) .. fundsSuffix)
	end
end)

do
    local sellActive = false

    local function SellNext()
        if not sellActive or not (MerchantFrame and MerchantFrame:IsShown()) then
            sellActive = false
            return
        end
        for bag = 0, 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
                    C_Container.UseContainerItem(bag, slot)
                    BUI.Prof.After('Settings.Settings', 0.2, SellNext)
                    return
                end
            end
        end
        sellActive = false
    end

    local function StopSelling()
        sellActive = false
        BUI.Events:Unregister("UI_ERROR_MESSAGE", "Settings.junkSell")
    end

    local function OnSellError(_, _, errorMsg)
        if errorMsg == ERR_VENDOR_DOESNT_BUY or errorMsg == ERR_TOO_MUCH_GOLD then
            StopSelling()
        end
    end

    Settings.ToggleSellJunk = EventToggle("junk", { "MERCHANT_SHOW", "MERCHANT_CLOSED" }, function(event)
        if event == "MERCHANT_SHOW" then
            StopSelling()
            sellActive = true
            BUI.Events:Register("UI_ERROR_MESSAGE", "Settings.junkSell", OnSellError)
            BUI.Prof.After('Settings.Settings', 0.3, SellNext)
        elseif event == "MERCHANT_CLOSED" then
            StopSelling()
        end
    end, StopSelling)
end

Settings.ToggleAutoKeystone = EventToggle("keystone", "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN", function()
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if (id and C_Item.IsItemKeystoneByID(id)) then
                C_Container.UseContainerItem(bag, slot)
                return
            end
        end
    end
end)

do
	local questEvents = {
		'GOSSIP_SHOW', 'QUEST_GREETING',
		'QUEST_DETAIL', 'QUEST_ACCEPT_CONFIRM',
		'QUEST_PROGRESS', 'QUEST_COMPLETE',
		'QUEST_AUTOCOMPLETE',
	}

	local function GetDB()
		return BUI.GetDB().automation
	end

	local function WantAccept() return GetDB().autoAcceptQuests end
	local function WantComplete() return GetDB().autoCompleteQuests end

	local function IsQuestLogFull()
		local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
		return numQuests >= C_QuestLog.GetMaxNumQuestsCanAccept()
	end

	local function QuestRequiresGold()
		local gold = GetQuestMoneyToGet()
		return gold and gold > 0
	end

	local function QuestRequiresCurrency()
		for itemIndex = 1, 6 do
			local progressItem = _G['QuestProgressItem' .. itemIndex]
			if progressItem and progressItem:IsShown() and progressItem.type == 'required' then
				if progressItem.objectType == 'currency' then return true end
				if progressItem.objectType == 'item' then
					local _, _, _, _, _, itemID = GetQuestItemInfo('required', itemIndex)
					if itemID then
						local info = C_Item.GetItemInfo(itemID)
						local isCraftingReagent = type(info) == 'table' and info.isCraftingReagent
						if not isCraftingReagent then
							local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_, craftingReagent = C_Item.GetItemInfo(itemID)
							isCraftingReagent = craftingReagent
						end
						if isCraftingReagent then return true end
					end
				end
			end
		end
	end

	local pendingGossipType
	local gossipPending = false
	local completePending = false

	local function DeferredGossip()
		gossipPending = false
		if IsShiftKeyDown() then return end
		if pendingGossipType == 'greeting' then
			if WantComplete() then
				for questIndex = 1, GetNumActiveQuests() do
					local title, isComplete = GetActiveTitle(questIndex)
					if title and isComplete then
						SelectActiveQuest(questIndex)
						return
					end
				end
			end
			if WantAccept() and not IsQuestLogFull() then
				for questIndex = 1, GetNumAvailableQuests() do
					local title = GetAvailableTitle(questIndex)
					if title then
						SelectAvailableQuest(questIndex)
						return
					end
				end
			end
		else
			if WantComplete() then
				local activeQuests = C_GossipInfo.GetActiveQuests()
				for _, info in ipairs(activeQuests) do
					if info.title and info.isComplete and info.questID then
						C_GossipInfo.SelectActiveQuest(info.questID)
						return
					end
				end
			end
			if WantAccept() and not IsQuestLogFull() then
				local availableQuests = C_GossipInfo.GetAvailableQuests()
				for _, info in ipairs(availableQuests) do
					if info.questID then
						C_GossipInfo.SelectAvailableQuest(info.questID)
						return
					end
				end
			end
			if WantAccept() then
				local options = C_GossipInfo.GetOptions()
				for _, option in ipairs(options) do
					if option.gossipOptionID then
						local isQuestFlagged = option.flags and bit.band(option.flags, 1) == 1
						local isDelve = option.name and option.name:find('%(Delve%)') ~= nil
						if isQuestFlagged or isDelve then
							C_GossipInfo.SelectOption(option.gossipOptionID)
							return
						end
					end
				end
			end
		end
	end

	local function DeferredComplete()
		completePending = false
		if IsShiftKeyDown() then return end
		if QuestRequiresGold() then return end
		if QuestRequiresCurrency() then return end
		local choices = GetNumQuestChoices()
		if choices <= 1 then
			GetQuestReward(choices)
		else
			local bestIndex, bestPrice = 1, 0
			for choiceIndex = 1, choices do
				local link = GetQuestItemLink('choice', choiceIndex)
				if link then
					local itemID = tonumber(link:match('item:(%d+)'))
					if itemID then
						local result = C_Item.GetItemInfo(itemID)
						local sellValue = 0
						if type(result) == 'table' then
							sellValue = result.sellPrice or 0
						else
							local _,_,_,_,_,_,_,_,_,_, vendorPrice = C_Item.GetItemInfo(itemID)
							sellValue = vendorPrice or 0
						end
						if sellValue > bestPrice then
							bestPrice = sellValue
							bestIndex = choiceIndex
						end
					end
				end
			end
			GetQuestReward(bestIndex)
		end
	end

	local function OnQuestEvent(event, arg1)
		if IsShiftKeyDown() then return end

		if event == 'GOSSIP_SHOW' or event == 'QUEST_GREETING' then
			pendingGossipType = event == 'QUEST_GREETING' and 'greeting' or 'gossip'
			if not gossipPending then
				gossipPending = true
				BUI.Prof.After('Settings.Settings', 0, DeferredGossip)
			end
		elseif event == 'QUEST_DETAIL' and WantAccept() then
			if not IsQuestLogFull() then AcceptQuest() end
		elseif event == 'QUEST_ACCEPT_CONFIRM' and WantAccept() then
			if not IsQuestLogFull() then
				ConfirmAcceptQuest()
				StaticPopup_Hide('QUEST_ACCEPT')
			end
		elseif event == 'QUEST_PROGRESS' and WantComplete() then
			if IsQuestCompletable() and not QuestRequiresGold() and not QuestRequiresCurrency() then
				CompleteQuest()
			end
		elseif event == 'QUEST_COMPLETE' and WantComplete() then
			if not completePending then
				completePending = true
				BUI.Prof.After('Settings.Settings', 0, DeferredComplete)
			end
		elseif event == 'QUEST_AUTOCOMPLETE' and WantComplete() then
			local index = arg1 and C_QuestLog.GetLogIndexForQuestID(arg1)
			if index then
				local info = C_QuestLog.GetInfo(index)
				if info and info.isAutoComplete then
					C_QuestLog.SetSelectedQuest(arg1)
					ShowQuestComplete(C_QuestLog.GetSelectedQuest())
				end
			end
		end
	end

	local questRegistered = false

	local function UpdateRegistration()
		if WantAccept() or WantComplete() then
			if not questRegistered then
				questRegistered = true
				for _, eventName in ipairs(questEvents) do
					BUI.Events:Register(eventName, 'Settings.Quest', OnQuestEvent)
				end
			end
		else
			if questRegistered then
				BUI.Events:UnregisterAll('Settings.Quest')
				questRegistered = false
			end
		end
	end

	local overlayCheckboxes = {}

	local function CreateOverlayCheckbox(parent, label, dbKey, tooltip)
		local checkbox = Controls.StampCheckbox(parent, label, false, function(checked)
			local db = GetDB()
			db[dbKey] = checked
			UpdateRegistration()
			local pageSync = Settings._pageToggles and Settings._pageToggles[dbKey]
			if pageSync then pageSync(checked) end
		end, nil, true, tooltip)
		local frame = Widget.Unwrap(checkbox)
		frame.dbKey = dbKey
		frame.labelFs = frame.label
		frame.Sync = function(checked) checkbox:SetValue(checked) end
		return frame
	end

	local function SyncOverlay()
		local db = GetDB()
		for _, checkbox in ipairs(overlayCheckboxes) do
			checkbox.Sync(db[checkbox.dbKey] or false)
		end
	end

	local overlayCreated = false
	local overlayHolder
	local function CreateOverlay()
		if overlayCreated then return end
		overlayCreated = true

		local panel = _G.BUI_TrackerPanel
		local anchor = panel or ObjectiveTrackerFrame
		if not anchor then return end

		overlayHolder = CreateFrame('Frame', nil, anchor, 'BackdropTemplate')
		local holder = overlayHolder
		local Theme = BUILib.Theme
		local gap = Pixel.PixelSize(1)
		holder:SetHeight(Pixel.Scale(30))
		if panel then
			holder:SetPoint('BOTTOMLEFT', panel, 'TOPLEFT', 0, gap)
			holder:SetPoint('BOTTOMRIGHT', panel, 'TOPRIGHT', 0, gap)
		else
			local outsetLeft, outsetRight, outsetTop = Pixel.PixelSize(14), Pixel.PixelSize(24), Pixel.PixelSize(6)
			outsetLeft, outsetRight, outsetTop = BUI.Skinning.GetTrackerPanelOutsets()
			holder:SetPoint('BOTTOMLEFT', anchor, 'TOPLEFT', -outsetLeft, outsetTop + gap)
			holder:SetPoint('BOTTOMRIGHT', anchor, 'TOPRIGHT', outsetRight, outsetTop + gap)
		end
		holder:SetBackdrop({
			bgFile = BUI.C.FALLBACK_TEXTURE,
			edgeFile = BUI.C.FALLBACK_TEXTURE,
			edgeSize = 1,
		})
		holder:SetBackdropColor(Theme.bg.dark[1], Theme.bg.dark[2], Theme.bg.dark[3], Theme.bg.dark[4])
		holder:SetBackdropBorderColor(Theme.border.light[1], Theme.border.light[2], Theme.border.light[3], 1)
		BUI.Skinning.RegisterTrackerPanel(holder)
		holder:SetShown(BUI.Skinning.IsSkinEnabled('questoverlay'))

		local items = {
			{ 'Auto-Accept', 'autoAcceptQuests', 'Accept quests and gossip options. Hold shift to skip.' },
			{ 'Auto-Complete', 'autoCompleteQuests', 'Turn in quests, taking the best-value reward.' },
		}

		local previousCheckbox
		for _, item in ipairs(items) do
			local checkbox = CreateOverlayCheckbox(holder, item[1], item[2], item[3])
			if previousCheckbox then
				checkbox:SetPoint('LEFT', previousCheckbox.labelFs, 'RIGHT', Pixel.Scale(14), 0)
			else
				checkbox:SetPoint('LEFT', holder, 'LEFT', Pixel.Scale(8), 0)
			end
			overlayCheckboxes[#overlayCheckboxes + 1] = checkbox
			previousCheckbox = checkbox
		end

		SyncOverlay()
	end

	BUI.Events:Once('PLAYER_ENTERING_WORLD', 'QuestOverlay', function()
		CreateOverlay()
	end)

	local function QuestToggle()
		UpdateRegistration()
		SyncOverlay()
	end
	Settings.ToggleAutoAcceptQuests = QuestToggle
	Settings.ToggleAutoCompleteQuests = QuestToggle

	BUI.Events:OnLogin('QuestOverlaySkin', function()
		local Skin = BUI.Skinning
		Skin.RegisterSkin('questoverlay', {
			name = 'Quest Auto Accept & Complete',
			description = 'Two checkboxes above the objective tracker: accept quests automatically, and turn them in automatically.',
			icon = 'Interface\\Icons\\INV_Misc_Note_01',
		})
		Skin.OnToggle('questoverlay', function(enabled)
			if overlayHolder then overlayHolder:SetShown(enabled) end
		end)
	end)
end

Settings.ToggleAutoAcceptParty = EventToggle('party', 'PARTY_INVITE_REQUEST', function(_, inviter, _, _, _, _, _, guid)
	if IsInLFGQueue() then return end
	if Settings.IsFriendly(inviter, guid) then
		AcceptGroup()
		StaticPopup_Hide('PARTY_INVITE')
		StaticPopup_Hide('PARTY_INVITE_XREALM')
	end
end)

Settings.ToggleAutoConfirmRole = function(_, enabled)
	if enabled then
		if not LFDRoleCheckPopupAcceptButton then return end
		HookScript(LFDRoleCheckPopupAcceptButton, 'OnShow', function(self)
			if not BUI.GetDB().social.autoConfirmRole then return end
			self:Click()
		end)
	end
end

Settings.ToggleEasyItemDestroy = EventToggle("destroy", "DELETE_ITEM_CONFIRM", function()
    if StaticPopup1EditBox and StaticPopup1Button1 then StaticPopup1EditBox:Hide(); StaticPopup1Button1:Enable() end
end)

Settings.ToggleHideTalkingFrame = HideFrameToggle("talkinghead", function()
    return TalkingHeadFrame
end)

Settings.ToggleHideRestedSleep = HideFrameToggle("restedsleep", function()
    return PlayerFrame.PlayerRestIcon or
        (PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual and
            PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PlayerRestIcon)
end)

Settings.ToggleHideZoneText = HideFrameToggle("zonetext", function()
    return ZoneTextFrame
end)

Settings.ToggleHideErrorMessages = function(_, enabled)
    if enabled then UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    else UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE") end
end

Settings.ToggleCastOnKeyDown = CVarToggle("ActionButtonUseKeyDown")

local function CVarExists(cvar) return C_CVar.GetCVar(cvar) ~= nil end
local fctNameCache = {}
function Settings.ResolveFCTCVar(cvar)
    local cached = fctNameCache[cvar]
    if cached then return cached end
    local v2 = cvar .. '_v2'
    cached = CVarExists(v2) and v2 or cvar
    fctNameCache[cvar] = cached
    return cached
end

function Settings.GetFCTBool(cvar) return C_CVar.GetCVarBool(Settings.ResolveFCTCVar(cvar)) end
function Settings.GetFCT(cvar)     return C_CVar.GetCVar(Settings.ResolveFCTCVar(cvar))     end

function Settings.SetFCT(cvar, value)
    C_CVar.SetCVar(Settings.ResolveFCTCVar(cvar), value)
    if C_CVar.GetCVarBool('enableFloatingCombatText') then
        C_CVar.SetCVar('enableFloatingCombatText', 0)
        C_CVar.SetCVar('enableFloatingCombatText', 1)
    end
    if CombatText_UpdateDisplayedMessages then CombatText_UpdateDisplayedMessages() end
end

local function ApplyAHCurrentExpansion(value)
    if AUCTION_HOUSE_DEFAULT_FILTERS and Enum.AuctionHouseFilter then
        AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.CurrentExpansionOnly] = value and true or false
    end
end
Settings.ToggleAHCurrentExpansion = function(_, enabled) ApplyAHCurrentExpansion(enabled) end
BUI.Events:Register('ADDON_LOADED', 'Settings.AHFilter', function(_, addon)
    if addon ~= 'Blizzard_AuctionHouseUI' then return end
    ApplyAHCurrentExpansion(BUI.GetDB().automation.ahCurrentExpansionOnly)
end)

function Settings.SetSpellQueueWindow(_, milliseconds)
    milliseconds = tonumber(milliseconds)
    if not milliseconds then return end
    C_CVar.SetCVar("SpellQueueWindow", tostring(math.max(0, math.min(400, milliseconds))))
end

Settings.ToggleFasterMovieSkip = function(_, enabled)
    local function hookSkip(frame, button)
        if not frame or not button then return end
        if enabled then
            if not AceHook.IsHooked(BUI, frame, "OnKeyUp") then
                AceHook.HookScript(BUI, frame, "OnKeyUp", BUI.Prof.Wrap('Settings#OnKeyUp', function(_, key)
                    if key == "ESCAPE" or key == "SPACE" or key == "ENTER" then button:Click() end
                end))
            end
            if not AceHook.IsHooked(BUI, frame, "OnShow") then
                AceHook.HookScript(BUI, frame, "OnShow", BUI.Prof.Wrap('Settings#OnShow', function()
                    BUI.Prof.After('Settings.Settings', 0, function() if frame:IsShown() and button then button:Click() end end)
                end))
            end
        else
            if AceHook.IsHooked(BUI, frame, "OnKeyUp") then AceHook.Unhook(BUI, frame, "OnKeyUp") end
            if AceHook.IsHooked(BUI, frame, "OnShow") then AceHook.Unhook(BUI, frame, "OnShow") end
        end
    end
    hookSkip(CinematicFrame, CinematicFrameCloseDialogConfirmButton)
    hookSkip(MovieFrame, MovieFrame and MovieFrame.CloseDialog and MovieFrame.CloseDialog.ConfirmButton)
end

function Settings:Initialize()
    local db = BUI.GetDB()

    SetCVar("UberTooltips", 1)

    local toggles = {
        { db.automation, "fasterLooting", "ToggleFasterLooting" },
        { db.automation, "autoRepair", "ToggleAutoRepair" },
        { db.automation, "sellJunk", "ToggleSellJunk" },
        { db.automation, "autoKeystone", "ToggleAutoKeystone" },
        { db.automation, "castOnKeyDown", "ToggleCastOnKeyDown" },
        { db.automation, "autoAcceptQuests", "ToggleAutoAcceptQuests" },
        { db.automation, "autoCompleteQuests", "ToggleAutoCompleteQuests" },
        { db.social, "autoAcceptParty", "ToggleAutoAcceptParty" },
        { db.social, "autoConfirmRole", "ToggleAutoConfirmRole" },
        { db.interface, "easyItemDestroy", "ToggleEasyItemDestroy" },
        { db.interface, "hideTalkingFrame", "ToggleHideTalkingFrame" },
        { db.interface, "hideRestedSleep", "ToggleHideRestedSleep" },
        { db.interface, "hideZoneText", "ToggleHideZoneText" },
        { db.interface, "hideErrorMessages", "ToggleHideErrorMessages" },
        { db.interface, "fasterMovieSkip", "ToggleFasterMovieSkip" },
        { db.automation, "ahCurrentExpansionOnly", "ToggleAHCurrentExpansion" },
    }

    for _, toggle in ipairs(toggles) do
        local settingsTable, key, toggleName = toggle[1], toggle[2], toggle[3]
        if settingsTable[key] ~= nil then
            Settings[toggleName](nil, settingsTable[key])
        end
    end

    if db.automation.spellQueueWindow then
        Settings.SetSpellQueueWindow(nil, db.automation.spellQueueWindow)
    end

    for _, section in ipairs(Settings.checkboxSections) do
        for _, item in ipairs(section.items) do
            if item.cvar and not item.toggle and not item.fn and item.type ~= 'slider' then
                local settingsTable = item.db and db[item.db]
                if settingsTable and settingsTable[item.key] ~= nil then
                    C_CVar.SetCVar(item.cvar, settingsTable[item.key] and '1' or '0')
                end
            end
        end
    end
end

Settings.checkboxSections = {
    { header = "Looting", items = {
        { db = "automation", key = "fasterLooting", label = "Faster Looting", toggle = "ToggleFasterLooting" },
        { db = "automation", key = "autoLoot", label = "Auto-Loot All", cvar = "autoLootDefault" },
        { db = "automation", key = "sellJunk", label = "Auto-Sell Junk", toggle = "ToggleSellJunk" },
    }},
    { header = "Merchant", items = {
        { db = "automation", key = "autoRepair", label = "Auto-Repair", toggle = "ToggleAutoRepair" },
        { db = "automation", key = "autoRepairGuildFunds", label = "Use Guild Funds" },
        { db = "automation", key = "autoRepairShowSummary", label = "Show Repair Cost" },
    }},
    { header = "Questing", items = {
        { db = "automation", key = "autoAcceptQuests", label = "Auto-Accept & Gossip", toggle = "ToggleAutoAcceptQuests" },
        { db = "automation", key = "autoCompleteQuests", label = "Auto-Complete", toggle = "ToggleAutoCompleteQuests" },
        { db = "interface", key = "fasterMovieSkip", label = "Skip Movies", toggle = "ToggleFasterMovieSkip" },
    }},
    { header = "Combat", items = {
        { db = "automation", key = "castOnKeyDown", label = "Cast on Key Down", fn = "ToggleCastOnKeyDown", cvarInit = "ActionButtonUseKeyDown" },
        { db = "automation", key = "autoKeystone", label = "Auto Keystone", toggle = "ToggleAutoKeystone" },
        { type = "slider", db = "automation", key = "spellQueueWindow",  label = "Spell Queue (ms)",    min = 0, max = 400, fn = "SetSpellQueueWindow", cvarInit = "SpellQueueWindow" },
    }},
    { header = "Combat Logging", items = {
        { db = "combatLogging", key = "enabled",         label = "Auto Combat Log",   fn = "RefreshCombatLogging" },
        { db = "combatLogging", key = "raids",           label = "Raids",             fn = "RefreshCombatLogging" },
        { db = "combatLogging", key = "mythicPlus",      label = "Mythic & Mythic+",  fn = "RefreshCombatLogging" },
        { db = "combatLogging", key = "otherDungeons",   label = "Other Dungeons",    fn = "RefreshCombatLogging" },
        { db = "combatLogging", key = "delves",          label = "Delves",            fn = "RefreshCombatLogging" },
        { db = "combatLogging", key = "arenas",          label = "Arenas",            fn = "RefreshCombatLogging" },
        { db = "combatLogging", key = "battlegrounds",   label = "Battlegrounds",     fn = "RefreshCombatLogging" },
        { db = "combatLogging", key = "advancedLogging", label = "Advanced Logging",  fn = "RefreshCombatLogging" },
        { db = "combatLogging", key = "chatMessage",     label = "Chat Alerts",       fn = "RefreshCombatLogging" },
        { db = "combatLogging", key = "showIndicator",   label = "Logging Indicator", fn = "RefreshCombatLogging" },
        { type = "button", label = "Indicator Position", buttonText = "Unlock / Lock", fn = "MoveCombatLogIndicator", width = 160 },
    }},
    { header = "Target Combat Text", items = {
        { fct = true, cvar = "floatingCombatTextCombatDamage",                label = "Damage Numbers" },
        { fct = true, cvar = "floatingCombatTextCombatHealing",               label = "Healing Numbers" },
        { fct = true, cvar = "floatingCombatTextCombatLogPeriodicSpells",     label = "Periodic Spells" },
        { fct = true, cvar = "floatingCombatTextPetMeleeDamage",              label = "Pet Damage" },
        { fct = true, cvar = "floatingCombatTextCombatHealingAbsorbTarget",   label = "Healing Absorbs" },
        { fct = true, cvar = "floatingCombatTextCombatDamageDirectionalScale", label = "Directional Damage" },
        { fct = true, type = "slider", cvar = "WorldTextScale", label = "World Text Scale", min = 0.5, max = 2.5, step = 0.1 },
    }},
    { header = "Social", items = {
        { db = "social", key = "autoAcceptParty", label = "Auto-Accept Party", toggle = "ToggleAutoAcceptParty" },
        { db = "social", key = "includeGuild", label = "Include Guild" },
        { db = "social", key = "autoConfirmRole", label = "Auto-Confirm Role", toggle = "ToggleAutoConfirmRole" },
    }},
    { header = "Interface", items = {
        { db = "interface", key = "easyItemDestroy", label = "Easy Item Destroy", toggle = "ToggleEasyItemDestroy" },
        { db = "interface", key = "hideTalkingFrame", label = "Hide Talking Head", toggle = "ToggleHideTalkingFrame" },
        { db = "interface", key = "hideRestedSleep", label = "Hide Rested Zzz", toggle = "ToggleHideRestedSleep" },
        { db = "interface", key = "hideZoneText", label = "Hide Zone Text", toggle = "ToggleHideZoneText" },
        { db = "interface", key = "hideErrorMessages", label = "Hide Error Msgs", toggle = "ToggleHideErrorMessages" },
    }},
    { header = "Auction House", items = {
        { db = "automation", key = "ahCurrentExpansionOnly", label = "Current Expansion Only", toggle = "ToggleAHCurrentExpansion" },
    }},
}

function Settings.RefreshCombatLogging()
    BUI.CombatLogging.Refresh()
end

function Settings.MoveCombatLogIndicator()
    BUI.CombatLogging.ToggleAnchor()
end

BUI.Events:OnLogin("Settings", function() Settings:Initialize() end)
