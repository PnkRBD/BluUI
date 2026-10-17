local _, BUI = ...

local tonumber, type = tonumber, type
local C_Item = C_Item
local C_SpellBook = C_SpellBook
local IsEquippedItem = C_Item.IsEquippedItem
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
		texture:SetVertexColor(0.4, 0.4, 0.4, alpha)
	else
		texture:SetVertexColor(red, green, blue, alpha)
	end
end
IconEngine.SetColor = SetColor

local function ScheduleExpiry(cooldown, remaining, callback)
	BUI.Tools.ReplaceTimer(cooldown, '_expiryTimer', 'Utility.IconEngine cooldown expiry', remaining + 0.1, callback)
end

local function ScheduleSpellExpiry(cooldown, cooldownInfo, callback)
	if not callback or not cooldownInfo then return end
	local cooldownStart = BUI.Tools.SafeNum(cooldownInfo.startTime)
	local cooldownDuration = BUI.Tools.SafeNum(cooldownInfo.duration)
	if cooldownStart and cooldownDuration and cooldownStart > 0 and cooldownDuration > 1.5 then
		local remaining = (cooldownStart + cooldownDuration) - GetTime()
		if remaining > 0 then ScheduleExpiry(cooldown, remaining, callback) end
	end
end

local bagItemForSpellFn

function IconEngine.SetBagResolver(itemForSpellFn)
	bagItemForSpellFn = itemForSpellFn
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

local itemSpellIDs = {}

function IconEngine.GetItemSpellID(itemID)
	local cached = itemSpellIDs[itemID]
	if cached ~= nil then return cached or nil, true end
	local _, spellID = C_Item.GetItemSpell(itemID)
	if spellID then
		itemSpellIDs[itemID] = spellID
		return spellID, true
	end
	if C_Item.IsItemDataCachedByID(itemID) then
		itemSpellIDs[itemID] = false
		return nil, true
	end
	return nil, false
end

local GetItemSpellID = IconEngine.GetItemSpellID

local onUseTrinkets

local function OnUseTrinketStore()
	if onUseTrinkets then return onUseTrinkets end
	local globalDB = BUI.db.global
	onUseTrinkets = globalDB.onUseTrinketCache or {}
	globalDB.onUseTrinketCache = onUseTrinkets
	return onUseTrinkets
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
	local spellID, settled = GetItemSpellID(itemID)
	if not settled then return store[itemID] == true, false end
	local onUse = spellID ~= nil
	if store[itemID] ~= onUse then store[itemID] = onUse end
	return onUse, true
end

local racialSlotResolver
function IconEngine.SetRacialSlotResolver(resolver) racialSlotResolver = resolver end

function IconEngine.GetRacialSlotNumber(value)
	if type(value) ~= "string" then return nil end
	return tonumber(value:match("^racial:(%d)$"))
end

function IconEngine.ResolveRacialSlot(slot)
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

	if IconEngine._isRacialSpell(id) then
		return "spell", nil
	end

	local _, foundItemID = (itemForSpellFn or bagItemForSpellFn)(id)
	if foundItemID then
		local _, _, _, equipLoc = C_Item.GetItemInfoInstant(foundItemID)
		if equipLoc == "INVTYPE_TRINKET" then return "trinket", foundItemID end
		return "consumable", foundItemID
	end

	local _, _, _, equipLoc, _, itemClass = C_Item.GetItemInfoInstant(id)
	if itemClass then
		if equipLoc == "INVTYPE_TRINKET" then return "trinket", id end
		if itemClass == Enum.ItemClass.Consumable then return "consumable", id end
		if C_Item.GetItemCount(id, true) > 0 then return "consumable", id end
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

local knownItemDurations = {
	[5512]   = 60,
	[224464] = 60,
}
local ITEM_CD_THRESHOLD = 1.5

function IconEngine.ItemCooldownKey(itemID)
	local cooldownStart, cooldownDuration, enable = C_Container.GetItemCooldown(itemID)
	if enable == 0 then return nil end
	if cooldownStart > 0 and (cooldownDuration > ITEM_CD_THRESHOLD or knownItemDurations[itemID]) then
		return cooldownStart
	end
	return 0
end

function IconEngine.ApplyItemVisual(texture, cooldown, count, itemID, onExpireCallback)
	if count == 0 then
		if cooldown._lastItemState ~= "empty" then
			cooldown._lastItemState = "empty"
			cooldown:Clear()
		end
		if cooldown._itemFP then cooldown._itemFP.count = 0 end
		texture:SetDesaturation(1)
		SetColor(texture, 0.3, 0.3, 1)
		return
	end

	local cooldownStart, cooldownDuration, enable = C_Container.GetItemCooldown(itemID)
	local known = knownItemDurations[itemID]

	local fingerprint = cooldown._itemFP
	if fingerprint and fingerprint.start == cooldownStart and fingerprint.duration == cooldownDuration and fingerprint.enable == enable and fingerprint.count == count then
		local desaturation = 0
		if enable == 0 then
			desaturation = known and 1 or 0
		elseif cooldownStart > 0 and (cooldownDuration > ITEM_CD_THRESHOLD or known) then
			desaturation = 1
		end
		texture:SetDesaturation(desaturation)
		return
	end
	if not fingerprint then fingerprint = {}; cooldown._itemFP = fingerprint end
	fingerprint.start, fingerprint.duration, fingerprint.enable, fingerprint.count = cooldownStart, cooldownDuration, enable, count

	if enable == 0 and known then
		if cooldown._lastItemState ~= "locked" then
			cooldown._lastItemState = "locked"
			cooldown._lastItemStart = nil
			cooldown:Clear()
		end
		texture:SetDesaturation(1)
		SetColor(texture, 1, 1, 1)
		return
	elseif enable == 0 then
		local itemSpellID = GetItemSpellID(itemID)
		local gcdDuration = itemSpellID and C_Spell.GetSpellCooldownDuration(itemSpellID)
		if gcdDuration then
			cooldown._lastItemState = "gcd"
			cooldown._lastItemStart = nil
			cooldown:SetCooldownFromDurationObject(gcdDuration)
		elseif cooldown._lastItemState ~= "ready" then
			cooldown._lastItemState = "ready"
			cooldown._lastItemStart = nil
			cooldown:Clear()
		end
		texture:SetDesaturation(0)
		SetColor(texture, 1, 1, 1)
		return
	end

	local duration = cooldownDuration
	if duration > ITEM_CD_THRESHOLD then
		knownItemDurations[itemID] = duration
	elseif cooldownStart > 0 and known then
		duration = known
	end

	if cooldownStart > 0 and duration > ITEM_CD_THRESHOLD then
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
		SetColor(texture, 1, 1, 1)

		if onExpireCallback then
			local remaining = (cooldownStart + duration) - GetTime()
			if remaining > 0 then ScheduleExpiry(cooldown, remaining, onExpireCallback) end
		end
	else
		if cooldown._lastItemState ~= "ready" then
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

		local spellDuration = itemSpellID and C_Spell.GetSpellCooldownDuration(itemSpellID)
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
		local ready = BUI.Tools.SafeNum(cooldown._trinketDurObj:EvaluateRemainingDuration(BUI.Tools.IsReadyCurve, 0))
		if ready and ready > 0.5 then
			cooldown._trinketLastStart = nil
			cooldown:Clear()
			texture:SetDesaturation(0)
		end
	end

	SetColor(texture, 1, 1, 1)
end

function IconEngine.ApplySpellVisual(texture, cooldown, spellID, hasCharges, onExpireCallback, ignoreGCD, hideGCD, usableIn, notEnoughPowerIn, cooldownInfoIn)
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
		cooldown:Clear()
		return
	elseif texture._lastUsable == false then
		texture._lastUsable = true
		texture:SetDesaturation(0)
	end

	if not issecretvalue(notEnoughPower) and notEnoughPower ~= texture._lastNotEnoughPower then
		texture._lastNotEnoughPower = notEnoughPower
		local shade = notEnoughPower and 0.5 or 1
		SetColor(texture, shade, shade, shade)
	end

	local cooldownInfo = cooldownInfoIn
	if cooldownInfo == nil then cooldownInfo = C_Spell.GetSpellCooldown(spellID) end
	local skipGCDDesat = ignoreGCD and cooldownInfo and cooldownInfo.isOnGCD
	hideGCD = hideGCD == true

	if not hasCharges then
		local spellDuration = C_Spell.GetSpellCooldownDuration(spellID, hideGCD)
		if spellDuration then
			cooldown:SetCooldownFromDurationObject(spellDuration)
		else
			cooldown:Clear()
		end

		if skipGCDDesat then
			texture:SetDesaturation(0)
		elseif spellDuration then
			texture:SetDesaturation(spellDuration:EvaluateRemainingDuration(desaturationCurve, 0))
		else
			texture:SetDesaturation(0)
		end

		ScheduleSpellExpiry(cooldown, cooldownInfo, onExpireCallback)
		return
	end

	local chargeDuration = C_Spell.GetSpellChargeDuration(spellID)
	local spellDuration = C_Spell.GetSpellCooldownDuration(spellID, hideGCD)
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
	elseif spellDuration then
		texture:SetDesaturation(spellDuration:EvaluateRemainingDuration(desaturationCurve, 0))
	else
		texture:SetDesaturation(0)
	end

	ScheduleSpellExpiry(cooldown, cooldownInfo, onExpireCallback)
	return safeCharges
end
