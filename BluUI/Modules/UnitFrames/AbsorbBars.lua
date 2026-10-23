local _, BUI = ...

local oUF = BUI.oUF
local UnitFrames = BUI.UnitFrames
local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction
local CreateUnitHealPredictionCalculator = CreateUnitHealPredictionCalculator

local SHIELD_EVENTS = { 'UNIT_ABSORB_AMOUNT_CHANGED', 'UNIT_HEAL_ABSORB_AMOUNT_CHANGED', 'UNIT_MAXHEALTH' }
local DAMAGE_CLAMP = Enum.UnitDamageAbsorbClampMode

function UnitFrames.SetAbsorbOverflow(frame, shown)
	local bars = frame.AbsorbBars
	bars.Overflow:SetShown(shown)
	bars.damageClamp = shown and DAMAGE_CLAMP.MissingHealthWithoutIncomingHeals or DAMAGE_CLAMP.MaximumHealth
	bars.values:SetDamageAbsorbClampMode(bars.damageClamp)
end

local function Fit(bars)
	local health = bars.__owner.Health
	local excess = bars.Damage.Excess
	if health:GetOrientation() == 'VERTICAL' then
		local height = health:GetHeight()
		bars.Damage:SetHeight(height)
		bars.Heal:SetHeight(height)
		if excess then excess:SetHeight(height) end
		return
	end
	local width = health:GetWidth()
	bars.Damage:SetWidth(width)
	bars.Heal:SetWidth(width)
	if excess then excess:SetWidth(width) end
end

function UnitFrames.FitAbsorbBars(frame)
	Fit(frame.AbsorbBars)
end

local function Fill(bar, maxHealth, amount)
	bar:SetMinMaxValues(0, maxHealth)
	bar:SetValue(amount)
	local excess = bar.Excess
	if excess then
		excess:SetMinMaxValues(0, maxHealth)
		excess:SetValue(amount)
	end
end
UnitFrames.FillAbsorb = Fill

local function Update(self, _, unit)
	if self.__unit ~= unit then return end
	local bars = self.AbsorbBars
	local damage, heal = bars.Damage, bars.Heal
	if not damage:IsShown() and not heal:IsShown() then return end
	local values = bars.values
	UnitGetDetailedHealPrediction(unit, 'player', values)
	local maxHealth = values:GetMaximumHealth()
	if damage:IsShown() then
		local amount, overflow = values:GetDamageAbsorbs()
		Fill(damage, maxHealth, amount)
		if bars.Overflow then bars.Overflow:SetAlphaFromBoolean(overflow, 1, 0) end
	end
	if heal:IsShown() then Fill(heal, maxHealth, (values:GetHealAbsorbs())) end
end

local pending = {}

local FlushPending = BUI.Dispatcher.New(function()
	for frame in pairs(pending) do
		pending[frame] = nil
		Update(frame, nil, frame.__unit)
	end
end, 'UF.AbsorbBars')

local function Queue(self, _, unit)
	if self.__unit ~= unit then return end
	pending[self] = true
	FlushPending()
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
		bars.values:SetDamageAbsorbClampMode(bars.damageClamp or DAMAGE_CLAMP.MaximumHealth)
		bars.values:SetHealAbsorbClampMode(Enum.UnitHealAbsorbClampMode.MaximumHealth)
		self.Health:HookScript('OnSizeChanged', BUI.Profiler.Wrap('UnitFrames.AbsorbBars fit', function() Fit(bars) end))
	end
	for _, event in ipairs(SHIELD_EVENTS) do self:RegisterEvent(event, Queue) end
	return true
end

local function Disable(self)
	if not self.AbsorbBars then return end
	for _, event in ipairs(SHIELD_EVENTS) do self:UnregisterEvent(event, Queue) end
end

oUF:AddElement('AbsorbBars', Refresh, Enable, Disable)
