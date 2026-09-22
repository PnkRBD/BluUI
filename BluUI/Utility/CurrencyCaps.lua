local _, BUI = ...

local Currency = {}
BUI.Currency = Currency

local CAP_TRACKER = {
	[3418] = 3420,
}

local function FirstCap(info)
	if not info then return 0 end
	if (info.maxQuantity or 0) > 0 then return info.maxQuantity end
	if (info.maxWeeklyQuantity or 0) > 0 then return info.maxWeeklyQuantity end
	return 0
end

function Currency.Cap(currencyID, info)
	info = info or (currencyID and C_CurrencyInfo.GetCurrencyInfo(currencyID))
	local cap = FirstCap(info)
	if cap > 0 then return cap end
	local trackerID = currencyID and CAP_TRACKER[currencyID]
	if trackerID then
		cap = FirstCap(C_CurrencyInfo.GetCurrencyInfo(trackerID))
	end
	return cap
end

function Currency.TrackerFor(currencyID)
	return CAP_TRACKER[currencyID]
end

function Currency.Dump(currencyID)
	local function Describe(id)
		local info = C_CurrencyInfo.GetCurrencyInfo(id)
		if not info then
			BUI.Print(('Currency %d: no data'):format(id))
			return
		end
		BUI.Print(('%s (%d): quantity %s, maxQuantity %s, totalEarned %s, useTotalEarnedForMaxQty %s, canEarnPerWeek %s, maxWeeklyQuantity %s, quantityEarnedThisWeek %s'):format(
			info.name or '?', id,
			tostring(info.quantity), tostring(info.maxQuantity), tostring(info.totalEarned),
			tostring(info.useTotalEarnedForMaxQty), tostring(info.canEarnPerWeek),
			tostring(info.maxWeeklyQuantity), tostring(info.quantityEarnedThisWeek)))
	end
	Describe(currencyID)
	local trackerID = CAP_TRACKER[currencyID]
	if trackerID then Describe(trackerID) end
	BUI.Print(('Cap the dashboard would show: %d'):format(Currency.Cap(currencyID)))
end
