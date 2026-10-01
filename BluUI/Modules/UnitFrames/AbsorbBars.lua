local _, BUI = ...

local oUF = BUI.oUF
local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction
local CreateUnitHealPredictionCalculator = CreateUnitHealPredictionCalculator

local SHIELD_EVENTS = { 'UNIT_ABSORB_AMOUNT_CHANGED', 'UNIT_HEAL_ABSORB_AMOUNT_CHANGED', 'UNIT_MAXHEALTH' }

local function Fit(bars)
	local width = bars.__owner.Health:GetWidth()
	bars.Damage:SetWidth(width)
	bars.Heal:SetWidth(width)
end

local function Fill(bar, maxHealth, amount)
	bar:SetMinMaxValues(0, maxHealth)
	bar:SetValue(amount)
end

local function Update(self, _, unit)
	if self.__unit ~= unit then return end
	local bars = self.AbsorbBars
	local damage, heal = bars.Damage, bars.Heal
	if not damage:IsShown() and not heal:IsShown() then return end
	local values = bars.values
	UnitGetDetailedHealPrediction(unit, 'player', values)
	local maxHealth = values:GetMaximumHealth()
	if damage:IsShown() then Fill(damage, maxHealth, (values:GetDamageAbsorbs())) end
	if heal:IsShown() then Fill(heal, maxHealth, (values:GetHealAbsorbs())) end
end

local function Refresh(self, event, unit)
	Fit(self.AbsorbBars)
	Update(self, event, unit)
end

local function ForceUpdate(bars)
	Refresh(bars.__owner, 'ForceUpdate', bars.__owner.__unit)
end

local function Enable(self)
	local bars = self.AbsorbBars
	if not bars then return end
	bars.__owner = self
	bars.ForceUpdate = ForceUpdate
	if not bars.values then
		bars.values = CreateUnitHealPredictionCalculator()
		bars.values:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)
		bars.values:SetHealAbsorbClampMode(Enum.UnitHealAbsorbClampMode.MaximumHealth)
		self.Health:HookScript('OnSizeChanged', BUI.Profiler.Wrap('UnitFrames.AbsorbBars fit', function() Fit(bars) end))
	end
	for _, event in ipairs(SHIELD_EVENTS) do self:RegisterEvent(event, Update) end
	return true
end

local function Disable(self)
	if not self.AbsorbBars then return end
	for _, event in ipairs(SHIELD_EVENTS) do self:UnregisterEvent(event, Update) end
end

oUF:AddElement('AbsorbBars', Refresh, Enable, Disable)
