local BUILib = LibStub("BUILib")
if not BUILib.__loadChildren then return end

local Motion = {}
BUILib.Motion = Motion

local GetTime = GetTime
local SETTLED = 0.0001

local Ease = {
	outQuad = function(progress) return progress * (2 - progress) end,
	outCubic = function(progress) return 1 - (1 - progress) ^ 3 end,
}
Motion.Ease = Ease

local function OffsetX(frame)
	local _, _, _, x = frame:GetPoint(1)
	return x
end

local function OffsetY(frame)
	local _, _, _, _, y = frame:GetPoint(1)
	return y
end

local properties = {
	alpha = { get = function(frame) return frame:GetAlpha() end, set = function(frame, value) frame:SetAlpha(value) end },
	scale = { get = function(frame) return frame:GetScale() end, set = function(frame, value) frame:SetScale(value) end },
	width = { get = function(frame) return frame:GetWidth() end, set = function(frame, value) frame:SetWidth(value) end },
	height = { get = function(frame) return frame:GetHeight() end, set = function(frame, value) frame:SetHeight(value) end },
	x = { get = OffsetX, set = function(frame, value)
		local point, relativeTo, relativePoint, _, y = frame:GetPoint(1)
		frame:SetPoint(point, relativeTo, relativePoint, value, y)
	end },
	y = { get = OffsetY, set = function(frame, value)
		local point, relativeTo, relativePoint, x = frame:GetPoint(1)
		frame:SetPoint(point, relativeTo, relativePoint, x, value)
	end },
}

local tweens, byTarget, snapshot = {}, {}, {}
local driver = CreateFrame('Frame')
driver:Hide()

local function Find(target, property)
	local owned = byTarget[target]
	return owned and owned[property]
end

local function Remove(tween)
	tween.active = false
	local last = tweens[#tweens]
	tweens[tween.index] = last
	last.index = tween.index
	tweens[#tweens] = nil
	local owned = byTarget[tween.target]
	owned[tween.property] = nil
	if not next(owned) then byTarget[tween.target] = nil end
	if #tweens == 0 then driver:Hide() end
end

local function Settle(tween)
	Remove(tween)
	properties[tween.property].set(tween.target, tween.to)
	if tween.onComplete then tween.onComplete(tween.target) end
end

driver:SetScript('OnUpdate', function()
	local now, count = GetTime(), #tweens
	for index = 1, count do snapshot[index] = tweens[index] end
	for index = 1, count do
		local tween = snapshot[index]
		snapshot[index] = nil
		if tween.active then
			local progress = (now - tween.start) / tween.duration
			if progress >= 1 then
				Settle(tween)
			else
				local value = tween.from + (tween.to - tween.from) * tween.easing(progress)
				properties[tween.property].set(tween.target, value)
				if tween.onUpdate then tween.onUpdate(tween.target, value, progress) end
			end
		end
	end
end)

function Motion.RegisterProperty(name, get, set)
	properties[name] = { get = get, set = set }
end

function Motion.To(target, property, value, duration, options)
	local running = Find(target, property)
	if running then Remove(running) end
	local from = options and options.from or properties[property].get(target)
	if duration <= 0 or math.abs(value - from) < SETTLED then
		properties[property].set(target, value)
		if options and options.onComplete then options.onComplete(target) end
		return
	end
	local tween = {
		active = true, target = target, property = property, from = from, to = value,
		start = GetTime(), duration = duration,
		easing = options and options.easing or Ease.outQuad,
		onUpdate = options and options.onUpdate,
		onComplete = options and options.onComplete,
		index = #tweens + 1,
	}
	properties[property].set(target, from)
	tweens[tween.index] = tween
	byTarget[target] = byTarget[target] or {}
	byTarget[target][property] = tween
	driver:Show()
end

function Motion.Finish(target, property)
	local tween = Find(target, property)
	if tween then Settle(tween) end
end

function Motion.Stop(target, property)
	local tween = Find(target, property)
	if tween then Remove(tween) end
end

function Motion.Goal(target, property)
	local tween = Find(target, property)
	return tween and tween.to
end
