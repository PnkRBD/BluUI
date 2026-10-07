local _, BUI = ...

local Currency = {}
BUI.Currency = Currency

local CAP_TRACKER = {
	[3418] = 3420,
}

local function ProgressOf(info)
	if not info then return end
	if info.maxQuantity > 0 then
		return info.useTotalEarnedForMaxQty and info.totalEarned or info.quantity, info.maxQuantity, false
	end
	if info.maxWeeklyQuantity > 0 then
		return info.quantityEarnedThisWeek, info.maxWeeklyQuantity, true
	end
end

function Currency.Progress(currencyID, info)
	info = info or (currencyID and C_CurrencyInfo.GetCurrencyInfo(currencyID))
	local earned, cap, weekly = ProgressOf(info)
	if earned then return earned, cap, weekly end
	local trackerID = currencyID and CAP_TRACKER[currencyID]
	if trackerID then return ProgressOf(C_CurrencyInfo.GetCurrencyInfo(trackerID)) end
end

function Currency.Cap(currencyID, info)
	local _, cap = Currency.Progress(currencyID, info)
	return cap or 0
end
