local _, BUI = ...

local tonumber, type = tonumber, type
local C_Item = C_Item
local C_SpellBook = C_SpellBook
local IsEquippedItem = IsEquippedItem
local GetInventoryItemTexture = GetInventoryItemTexture
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

BUI.IconEngine = {}
local IconEngine = BUI.IconEngine

local isDead = false

local function RefreshDeadState()
	isDead = UnitIsDeadOrGhost('player')
end

BUI.Events:Register('PLAYER_DEAD',          'IconEngineDead', RefreshDeadState)
BUI.Events:Register('PLAYER_ALIVE',         'IconEngineDead', RefreshDeadState)
BUI.Events:Register('PLAYER_UNGHOST',       'IconEngineDead', RefreshDeadState)
BUI.Events:Register('PLAYER_ENTERING_WORLD','IconEngineDead', RefreshDeadState)

local function SetColor(texture, red, green, blue, alpha)
	if isDead then
		texture:SetVertexColor(0.4, 0.4, 0.4, alpha or 1)
	else
		texture:SetVertexColor(red, green, blue, alpha)
	end
end
IconEngine.SetColor = SetColor

local function ScheduleExpiry(cooldown, remaining, callback)
	if cooldown._expiryTimer then cooldown._expiryTimer:Cancel() end
	cooldown._expiryTimer = C_Timer.NewTimer(remaining + 0.1, function()
		cooldown._expiryTimer = nil
		callback()
	end)
end

local bagItemForSpellFn = nil
local bagAggregateCountFn = nil

function IconEngine.SetBagResolver(itemForSpellFn, aggregateCountFn)
	bagItemForSpellFn = itemForSpellFn
	bagAggregateCountFn = aggregateCountFn
end

function IconEngine.GetConsumableCount(itemID)
	if bagAggregateCountFn then return bagAggregateCountFn(itemID) end
	return C_Item.GetItemCount(itemID, true, true, true), itemID, nil
end

local TRINKET_SLOT_INV = { [1] = 13, [2] = 14 }

function IconEngine.GetTrinketSlotNumber(value)
	if type(value) ~= "string" then return nil end
	return tonumber(value:match("^trinket:(%d)$"))
end

function IconEngine.ResolveTrinketSlot(slot)
	local inventorySlot = TRINKET_SLOT_INV[slot]
	if not inventorySlot then return nil end
	return GetInventoryItemID("player", inventorySlot)
end

local onUseTrinketFallback = {}

local function OnUseTrinketStore()
	local globalDB = BUI.db and BUI.db.global
	if not globalDB then return onUseTrinketFallback end
	globalDB.onUseTrinketCache = globalDB.onUseTrinketCache or {}
	return globalDB.onUseTrinketCache
end

function IconEngine.TrinketSlotHasItem(slot)
	local inventorySlot = TRINKET_SLOT_INV[slot]
	if not inventorySlot then return false end
	return GetInventoryItemTexture("player", inventorySlot) ~= nil
end

function IconEngine.IsOnUseTrinketSlot(slot)
	local itemID = IconEngine.ResolveTrinketSlot(slot)
	if not itemID then return false, not IconEngine.TrinketSlotHasItem(slot) end
	local store = OnUseTrinketStore()
	if C_Item.IsItemDataCachedByID(itemID) then
		local _, spellID = C_Item.GetItemSpell(itemID)
		store[itemID] = spellID ~= nil
		return spellID ~= nil, true
	end
	return store[itemID] == true, false
end

local racialSlotResolver = nil
function IconEngine.SetRacialSlotResolver(resolver) racialSlotResolver = resolver end

function IconEngine.GetRacialSlotNumber(value)
	if type(value) ~= "string" then return nil end
	return tonumber(value:match("^racial:(%d)$"))
end

function IconEngine.ResolveRacialSlot(slot)
	if not racialSlotResolver then return nil end
	return racialSlotResolver(slot)
end

function IconEngine.ExtractSpellItemID(value)
	if type(value) == "string" then
		local slot = IconEngine.GetTrinketSlotNumber(value)
		if slot then
			return IconEngine.ResolveTrinketSlot(slot), true
		end
		slot = IconEngine.GetRacialSlotNumber(value)
		if slot then
			return IconEngine.ResolveRacialSlot(slot), false
		end
		if value:match("^item:") then
			return tonumber(value:match("^item:(%d+)")), true
		end
		if value:match("^spell:") then
			return tonumber(value:match("^spell:(%d+)")), false, true
		end
	end
	return tonumber(value), false
end

local function IsKnownSpell(spellID)
	if not spellID then return false end
	if C_SpellBook.IsSpellKnown(spellID) then return true end
	if C_SpellBook.IsSpellKnownOrInSpellBook(spellID) then return true end
	if C_SpellBook.HasPetSpells() and C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Pet) then
		return true
	end
	return false
end

function IconEngine.ClassifyAsSpellOrItem(id, isItemByPrefix, itemForSpellFn, isExplicitSpell)
	if isExplicitSpell then return "spell", nil end
	if isItemByPrefix then
		if not id then return "trinket", nil end
		local _, _, _, equipLoc = C_Item.GetItemInfoInstant(id)
		if equipLoc == "INVTYPE_TRINKET" then return "trinket", id end
		return "consumable", id
	end

	if IsKnownSpell(id) then
		return "spell", nil
	end

	if IconEngine._isRacialSpell and IconEngine._isRacialSpell(id) then
		return "spell", nil
	end

	local resolverFn = itemForSpellFn or bagItemForSpellFn
	if resolverFn then
		local _, foundItemID = resolverFn(id)
		if foundItemID then
			local _, _, _, equipLoc = C_Item.GetItemInfoInstant(foundItemID)
			if equipLoc == "INVTYPE_TRINKET" then return "trinket", foundItemID end
			return "consumable", foundItemID
		end
	end

	local _, _, _, equipLoc, _, itemClass = C_Item.GetItemInfoInstant(id)
	if itemClass then
		if equipLoc == "INVTYPE_TRINKET" then return "trinket", id end
		if itemClass == Enum.ItemClass.Consumable then return "consumable", id end
		local count = C_Item.GetItemCount(id, true)
		if count and count > 0 then return "consumable", id end
	end

	return "spell", nil
end

local HIDE_WHEN_EMPTY = {
	[5512]   = true,
	[224464] = true,
}

function IconEngine.IsEquippedOrKnownOrInBags(iconType, id, itemID)
	if iconType == "trinket" then
		return IsEquippedItem(itemID or id)
	end
	if iconType == "spell" then
		return C_SpellBook.IsSpellKnown(id)
	end
	if iconType == "consumable" then
		local checkID = itemID or id
		if IsEquippedItem(checkID) then return true end
		if C_Item.GetItemCount(checkID, true, true, true) > 0 then return true end
		if HIDE_WHEN_EMPTY[checkID] then return false end
		return true
	end
	return true
end

function IconEngine.IsTrackedEntryUsable(storedValue, itemForSpellFn)
	local spellID, isItemByPrefix, isExplicitSpell = IconEngine.ExtractSpellItemID(storedValue)
	if not spellID then return false end
	local iconType, itemID = IconEngine.ClassifyAsSpellOrItem(spellID, isItemByPrefix, itemForSpellFn, isExplicitSpell)
	return IconEngine.IsEquippedOrKnownOrInBags(iconType, spellID, itemID)
end

local knownItemDurations = {}
local ITEM_CD_THRESHOLD = 1.5

local itemSpellIDs = {}
local function GetItemSpellID(itemID)
	local cached = itemSpellIDs[itemID]
	if cached ~= nil then return cached or nil end
	local _, spellID = C_Item.GetItemSpell(itemID)
	itemSpellIDs[itemID] = spellID or false
	return spellID
end

local KNOWN_ITEM_DURATIONS = {
	[5512]   = 60,
	[224464] = 60,
}
for itemID, duration in pairs(KNOWN_ITEM_DURATIONS) do knownItemDurations[itemID] = duration end

function IconEngine.ApplyItemVisual(texture, cooldown, cooldownStart, cooldownDuration, count, itemID, onExpireCallback)
	if count == 0 then
		if cooldown and cooldown._lastItemState ~= "empty" then
			cooldown._lastItemState = "empty"
			cooldown:Clear()
		end
		if cooldown and cooldown._itemFP then cooldown._itemFP.count = 0 end
		texture:SetDesaturation(1)
		SetColor(texture, 0.3, 0.3, 1)
		return
	end

	local enable = 1
	if itemID then
		cooldownStart, cooldownDuration, enable = C_Container.GetItemCooldown(itemID)
	end

	cooldownStart = cooldownStart or 0
	cooldownDuration = cooldownDuration or 0
	enable = enable or 1

	if cooldown then
		local fingerprint = cooldown._itemFP
		if fingerprint and fingerprint.start == cooldownStart and fingerprint.duration == cooldownDuration and fingerprint.enable == enable and fingerprint.count == count then
			local desaturation = 0
			if enable == 0 then
				desaturation = (itemID and knownItemDurations[itemID]) and 1 or 0
			elseif cooldownStart > 0 and (cooldownDuration > ITEM_CD_THRESHOLD or (itemID and knownItemDurations[itemID])) then
				desaturation = 1
			end
			texture:SetDesaturation(desaturation)
			return
		end
		if not fingerprint then fingerprint = {}; cooldown._itemFP = fingerprint end
		fingerprint.start, fingerprint.duration, fingerprint.enable, fingerprint.count = cooldownStart, cooldownDuration, enable, count
	end

	if enable == 0 and itemID and knownItemDurations[itemID] then
		if cooldown and cooldown._lastItemState ~= "locked" then
			cooldown._lastItemState = "locked"
			cooldown._lastItemStart = nil
			cooldown:Clear()
		end
		texture:SetDesaturation(1)
		SetColor(texture, 1, 1, 1)
		return
	elseif enable == 0 then
		local itemSpellID = itemID and GetItemSpellID(itemID)
		local gcdDuration = itemSpellID and C_Spell.GetSpellCooldownDuration(itemSpellID) or nil
		if cooldown then
			if gcdDuration then
				cooldown._lastItemState = "gcd"
				cooldown._lastItemStart = nil
				cooldown:SetCooldownFromDurationObject(gcdDuration)
			elseif cooldown._lastItemState ~= "ready" then
				cooldown._lastItemState = "ready"
				cooldown._lastItemStart = nil
				cooldown:Clear()
			end
		end
		texture:SetDesaturation(0)
		SetColor(texture, 1, 1, 1)
		return
	end

	local hasStart = type(cooldownStart) == "number" and cooldownStart > 0
	local hasDuration = type(cooldownDuration) == "number"

	local duration = (hasDuration and cooldownDuration) or 0
	if itemID and duration > ITEM_CD_THRESHOLD then
		knownItemDurations[itemID] = duration
	elseif itemID and hasStart and knownItemDurations[itemID] then
		duration = knownItemDurations[itemID]
	end

	local onCooldown = hasStart and duration > ITEM_CD_THRESHOLD

	if onCooldown then
		if cooldown then
			if cooldown._lastItemStart ~= cooldownStart then
				cooldown._lastItemStart = cooldownStart
				cooldown._lastItemState = "cd"
				if not cooldown._itemDurObj then
					cooldown._itemDurObj = C_DurationUtil.CreateDuration()
				end
				cooldown._itemDurObj:SetTimeFromStart(cooldownStart, duration)
				cooldown:SetCooldownFromDurationObject(cooldown._itemDurObj)
			end
			texture:SetDesaturation(cooldown._itemDurObj:EvaluateRemainingDuration(BUI.Tools.OnCooldownCurve, 0))
		end
		SetColor(texture, 1, 1, 1)

		if onExpireCallback then
			local remaining = (cooldownStart + duration) - GetTime()
			if remaining > 0 then ScheduleExpiry(cooldown, remaining, onExpireCallback) end
		end
	else
		if cooldown and cooldown._lastItemState ~= "ready" then
			cooldown._lastItemState = "ready"
			cooldown._lastItemStart = nil
			cooldown:Clear()
		end
		texture:SetDesaturation(0)
		SetColor(texture, 1, 1, 1)
	end
end

local TRINKET_COOLDOWN_MIN = 1.6

function IconEngine.ApplyTrinketVisual(texture, cooldown, itemID, itemSpellID, onExpireCallback, countText)
	if countText then countText:Hide() end

	local cooldownStart, cooldownDuration = C_Container.GetItemCooldown(itemID)
	cooldownStart = tonumber(cooldownStart) or 0
	cooldownDuration = tonumber(cooldownDuration) or 0

	local idle = cooldownStart == 0 and not cooldown._trinketLastStart
	if idle and cooldown._trinketWasIdle then
		texture:SetDesaturation(0)
		return
	end
	cooldown._trinketWasIdle = idle

	local hasRealCooldown = cooldownStart > 0 and cooldownDuration >= TRINKET_COOLDOWN_MIN

	if not cooldown._trinketDurObj then
		cooldown._trinketDurObj = C_DurationUtil.CreateDuration()
	end

	if hasRealCooldown then
		if cooldownStart ~= cooldown._trinketLastStart then
			cooldown._trinketLastStart = cooldownStart
			cooldown._trinketDurObj:SetTimeFromStart(cooldownStart, cooldownDuration)
			cooldown:SetCooldownFromDurationObject(cooldown._trinketDurObj)

			if onExpireCallback then
				local remaining = (cooldownStart + cooldownDuration) - GetTime()
				if remaining > 0 then ScheduleExpiry(cooldown, remaining, onExpireCallback) end
			end
		end
		texture:SetDesaturation(cooldown._trinketDurObj:EvaluateRemainingDuration(BUI.Tools.OnCooldownCurve, 0))
	else

		local spellDuration = itemSpellID and C_Spell.GetSpellCooldownDuration(itemSpellID) or nil
		if spellDuration then
			cooldown:SetCooldownFromDurationObject(spellDuration)
		end
		texture:SetDesaturation(0)
		if cooldown._trinketLastStart then
			cooldown._trinketLastStart = nil
			if not spellDuration then cooldown:Clear() end
		end
	end

	if cooldown._trinketLastStart then
		local ready = BUI.Tools.SafeNum(IconEngine.ReadyAlpha(cooldown._trinketDurObj))
		if ready and ready > 0.5 then
			cooldown._trinketLastStart = nil
			cooldown:Clear()
			texture:SetDesaturation(0)
		end
	end

	SetColor(texture, 1, 1, 1)
end

function IconEngine.ReadyAlpha(durationObject)
	if not durationObject or not durationObject.EvaluateRemainingDuration then return 1 end
	return durationObject:EvaluateRemainingDuration(BUI.Tools.IsReadyCurve, 0)
end

function IconEngine.ApplySpellVisual(texture, cooldown, spellID, hasCharges, onExpireCallback, ignoreGCD, usableIn, notEnoughPowerIn, cooldownInfoIn)
	local desaturationCurve = BUI.Tools.OnCooldownCurve
	local isUsable, notEnoughPower
	if usableIn ~= nil then
		isUsable, notEnoughPower = usableIn, notEnoughPowerIn
	else
		isUsable, notEnoughPower = C_Spell.IsSpellUsable(spellID)
	end

	local castable = issecretvalue(isUsable) or isUsable ~= false
	if not castable then
		if texture._lastUsable ~= false then
			texture._lastUsable = false
			texture._lastNotEnoughPower = nil
			SetColor(texture, 0.4, 0.4, 0.4)
			texture:SetDesaturation(1)
		end
		cooldown._spellLastStart = nil
		cooldown:Clear()
		return
	elseif texture._lastUsable == false then
		texture._lastUsable = true
		texture:SetDesaturation(0)
		cooldown._spellLastStart = nil
	end

	if not issecretvalue(notEnoughPower) and notEnoughPower ~= texture._lastNotEnoughPower then
		texture._lastNotEnoughPower = notEnoughPower
		local shade = notEnoughPower and 0.5 or 1
		SetColor(texture, shade, shade, shade)
	end

	local cooldownInfo = cooldownInfoIn
	if cooldownInfo == nil then cooldownInfo = C_Spell.GetSpellCooldown(spellID) end
	local skipGCDDesat = ignoreGCD and cooldownInfo and cooldownInfo.isOnGCD

	if not hasCharges then
		local spellDuration = C_Spell.GetSpellCooldownDuration(spellID)
		if spellDuration then
			cooldown:SetCooldownFromDurationObject(spellDuration)
		else
			cooldown:Clear()
		end

		if skipGCDDesat then
			texture:SetDesaturation(0)
		elseif spellDuration and spellDuration.EvaluateRemainingDuration then
			texture:SetDesaturation(spellDuration:EvaluateRemainingDuration(desaturationCurve, 0) or 0)
		else
			texture:SetDesaturation(0)
		end

		if onExpireCallback and cooldownInfo then
			local cooldownStart = BUI.Tools.SafeNum(cooldownInfo.startTime)
			local cooldownDuration = BUI.Tools.SafeNum(cooldownInfo.duration)
			if cooldownStart and cooldownDuration and cooldownStart > 0 and cooldownDuration > 1.5 then
				local remaining = (cooldownStart + cooldownDuration) - GetTime()
				if remaining > 0 then ScheduleExpiry(cooldown, remaining, onExpireCallback) end
			end
		end

		return
	end

	cooldown._spellLastStart = nil
	local chargeDuration = C_Spell.GetSpellChargeDuration(spellID)
	local spellDuration = C_Spell.GetSpellCooldownDuration(spellID)
	local swipeSource = chargeDuration or spellDuration
	if swipeSource then
		cooldown:SetCooldownFromDurationObject(swipeSource)
	else
		cooldown:Clear()
	end

	local chargeInfo = C_Spell.GetSpellCharges(spellID)
	local safeCharges = BUI.Tools.SafeNum(chargeInfo and chargeInfo.currentCharges)

	if (safeCharges and safeCharges > 0) or skipGCDDesat then
		texture:SetDesaturation(0)
	elseif spellDuration and spellDuration.EvaluateRemainingDuration then
		texture:SetDesaturation(spellDuration:EvaluateRemainingDuration(desaturationCurve, 0) or 0)
	else
		texture:SetDesaturation(0)
	end

	if onExpireCallback and cooldownInfo then
		local cooldownStart = BUI.Tools.SafeNum(cooldownInfo.startTime)
		local cooldownDuration = BUI.Tools.SafeNum(cooldownInfo.duration)
		if cooldownStart and cooldownDuration and cooldownStart > 0 and cooldownDuration > 1.5 then
			local remaining = (cooldownStart + cooldownDuration) - GetTime()
			if remaining > 0 then ScheduleExpiry(cooldown, remaining, onExpireCallback) end
		end
	end

	return safeCharges
end
