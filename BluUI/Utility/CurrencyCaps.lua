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
