local _, BUI = ...
local SetScript = BUI.Prof.Scripts('Util.Animation')
local Animation = {}
BUI.Animation = Animation
local GetTime = GetTime
local pairs   = pairs

local activeAnimations = setmetatable({}, { __mode = 'k' })
local updateFrame
local animationCount   = 0

local function EaseOutQuad(progress) return progress * (2 - progress) end

local PropertyHandlers = {
	alpha  = { get = function(frame) return frame:GetAlpha()  end, set = function(frame, value) frame:SetAlpha(value)  end },
	scale  = { get = function(frame) return frame:GetScale()  end, set = function(frame, value) frame:SetScale(value)  end },
	width  = { get = function(frame) return frame:GetWidth()  end, set = function(frame, value) frame:SetWidth(value)  end },
	height = { get = function(frame) return frame:GetHeight() end, set = function(frame, value) frame:SetHeight(value) end },
}

local OnUpdate

OnUpdate = function(self)
	local now = GetTime()
	for frame, properties in pairs(activeAnimations) do
		local anyActive = false
		for propertyKey, animation in pairs(properties) do
			if animation._active then
				local progress = (now - animation.startTime) / animation.duration
				if progress >= 1 then
					animation.handler.set(animation.frame, animation.targetValue)
					animation._active = false
					animationCount = animationCount - 1
					if animation.onComplete then animation.onComplete(animation.frame) end

					if animation._active then anyActive = true end
				else
					local value = animation.startValue + (animation.targetValue - animation.startValue) * animation.easing(progress)
					animation.handler.set(animation.frame, value)
					if animation.onUpdate then animation.onUpdate(animation.frame, value, progress) end
					anyActive = true
				end
			end
		end
		if not anyActive then
			activeAnimations[frame] = nil
		end
	end
	if animationCount <= 0 then
		animationCount = 0
		SetScript(self, 'OnUpdate', nil)
	end
end

local function EnsureUpdateFrame()
	if not updateFrame then updateFrame = CreateFrame('Frame') end
	if animationCount > 0 then SetScript(updateFrame, 'OnUpdate', OnUpdate) end
end

function Animation.To(frame, property, targetValue, duration, options)
	if not frame or not property then return end

	local handler = PropertyHandlers[property]
	if not handler then
		if type(property) == 'table' and property.get and property.set then
			handler  = property
			property = property.name or 'custom'
		else
			return
		end
	end

	duration = duration or 0.2

	if duration <= 0 then
		local frameAnimations = activeAnimations[frame]
		if frameAnimations then
			local existing = frameAnimations[property]
			if existing and existing._active then
				existing._active = false
				animationCount = animationCount - 1
			end
		end
		handler.set(frame, targetValue)
		if options and options.onComplete then options.onComplete(frame) end
		return
	end

	local startValue = (options and options.fromValue) or handler.get(frame)
	if BUI.ApproxEqual(startValue, targetValue) then
		if options and options.onComplete then options.onComplete(frame) end
		return
	end

	local frameAnimations = activeAnimations[frame]
	if not frameAnimations then
		frameAnimations = {}
		activeAnimations[frame] = frameAnimations
	end

	local existing = frameAnimations[property]
	if existing then
		local wasActive      = existing._active
		existing._active     = true
		existing.startValue  = startValue
		existing.targetValue = targetValue
		existing.startTime   = GetTime()
		existing.duration    = duration
		existing.easing      = (options and options.easing) or EaseOutQuad
		existing.onComplete  = options and options.onComplete
		existing.onUpdate    = options and options.onUpdate
		if not wasActive then animationCount = animationCount + 1 end
	else
		frameAnimations[property] = {
			_active     = true,
			frame       = frame,
			handler     = handler,
			startValue  = startValue,
			targetValue = targetValue,
			startTime   = GetTime(),
			duration    = duration,
			easing      = (options and options.easing) or EaseOutQuad,
			onComplete  = options and options.onComplete,
			onUpdate    = options and options.onUpdate,
		}
		animationCount = animationCount + 1
	end

	EnsureUpdateFrame()
end

function Animation.RegisterProperty(name, getter, setter)
	PropertyHandlers[name] = { get = getter, set = setter }
end
