local _, BUI = ...
local SetScript = BUI.Prof.Scripts('CDM.Glow')

local hooksecurefunc = BUI.Prof.MakeHooker('glow')
local CDM = BUI.CDM
local Pixel = BUI.Pixel

local ipairs, pairs = ipairs, pairs
local CreateFrame = CreateFrame
local UIParent = UIParent

local FrameData = CDM.FrameData
local GetFrameData = CDM.GetFrameData
local GLOW_LAYER = 15
CDM.GLOW_LAYER = GLOW_LAYER
local GLOW_KEY = 'BUI_CDMProc'

local SAA_CHILDREN = { 'ProcLoopFlipbook', 'ProcStartFlipbook' }
local SAA_CHILDREN_COUNT = #SAA_CHILDREN

CDM.GLOW_TYPES = {
	{ id = 'pixel',    name = 'Pixel'    },
	{ id = 'autocast', name = 'Autocast' },
	{ id = 'button',   name = 'Button'   },
	{ id = 'proc',     name = 'Proc'     },
}

local TypeLookup = {}
for _, entry in ipairs(CDM.GLOW_TYPES) do
	TypeLookup[entry.id] = entry
end

local function ReadGlowDB()
	return BUI.GetDB().cdm.glow
end

function CDM.MigrateGlowType()
	local db = BUI.GetDB()

	local function walk(node)
		if type(node) ~= 'table' then return end
		for key, value in pairs(node) do
			if key == 'glow' and type(value) == 'table' then
				if type(value.type) == 'string' and not TypeLookup[value.type] then
					value.type = 'pixel'
				end
				if type(value.style) == 'string' and not TypeLookup[value.style] then
					value.style = 'pixel'
				end
			elseif type(value) == 'table' then
				walk(value)
			end
		end
	end
	walk(db.cdm)
end

function CDM.HideBlizzardGlow(icon)
	if not ReadGlowDB().enabled then return end

	local spellAlert = icon.SpellActivationAlert
	if spellAlert then
		spellAlert:Hide()
		for childIndex = 1, SAA_CHILDREN_COUNT do
			local child = spellAlert[SAA_CHILDREN[childIndex]]
			if child then child:Hide() end
		end
	end

	if icon.overlay then icon.overlay:Hide() end
	if icon.Overlay then icon.Overlay:Hide() end
	if icon.Glow    then icon.Glow:Hide()    end
end

function CDM.ShowBlizzardGlow(icon)
	local spellAlert = icon.SpellActivationAlert
	if spellAlert then
		spellAlert:Show()
		spellAlert:SetAlpha(1)
		for childIndex = 1, SAA_CHILDREN_COUNT do
			local child = spellAlert[SAA_CHILDREN[childIndex]]
			if child then child:Show() end
		end
	end

	if icon.overlay then icon.overlay:Show(); icon.overlay:SetAlpha(1) end
	if icon.Overlay then icon.Overlay:Show(); icon.Overlay:SetAlpha(1) end
	if icon.Glow    then icon.Glow:Show()    end
end

local GlowManager = BUI.GlowManager

local function PixelLength(icon, lineCount)
	local frameData = FrameData[icon]
	local settings = frameData and frameData.viewerKey and BUI.GetDB().cdm[frameData.viewerKey]
	if not settings then return nil end
	return GlowManager.PixelLength(settings._pxW or Pixel.Scale(settings.iconWidth), settings._pxH or Pixel.Scale(settings.iconHeight), lineCount)
end

local function DispatchStart(icon, config)
	local glowType = config.type
	local length = glowType == 'pixel' and PixelLength(icon, config.lines) or nil
	GlowManager.Start(icon, glowType, config.color, config.speed, config.lines, config.thickness, GLOW_KEY, GLOW_LAYER, length)
end

local function DispatchStop(icon, glowType)
	GlowManager.Stop(icon, glowType, GLOW_KEY)
end

local function ColorsMatch(colorA, colorB)
	if colorA == colorB then return true end
	if not colorA or not colorB then return false end
	return colorA[1] == colorB[1] and colorA[2] == colorB[2] and colorA[3] == colorB[3] and (colorA[4] or 1) == (colorB[4] or 1)
end

local mergedGlowConfig = {}

function CDM.StartProcGlow(icon, perIconGlow)
	if not icon.Icon then return end
	if CDM.HighlightsSuppressed() then return end
	local width, height = icon:GetSize()
	if width < 1 or height < 1 then return end

	local frameData = GetFrameData(icon)
	local globalConfig = ReadGlowDB()

	if perIconGlow then
		if not perIconGlow.enabled then return end
	elseif not globalConfig.enabled then
		return
	end

	local spellColor, spellStyle, spellEntry
	if not perIconGlow then
		local perSpell = globalConfig.perSpell
		if perSpell then
			local spellID = CDM.GetStableSpellID(icon)
			spellEntry = spellID and perSpell[spellID] or nil
			if spellEntry then
				spellColor = spellEntry.color
				spellStyle = spellEntry.style
			end
		end
	end

	local tuning = spellEntry or perIconGlow
	local hasTuning = tuning and (tuning.speed or tuning.lines or tuning.thickness) or nil

	local overrideStyle = (perIconGlow and perIconGlow.style) or spellStyle
	local effectiveType = (overrideStyle and TypeLookup[overrideStyle] and overrideStyle)
		or globalConfig.type
	local effectiveColor = (perIconGlow and perIconGlow.color) or spellColor or globalConfig.color

	if frameData.glowActive
		and frameData.glowType == effectiveType
		and ColorsMatch(frameData.glowColor, effectiveColor) then
		return
	end

	if frameData.glowActive then
		DispatchStop(icon, frameData.glowType)
	end

	CDM.HideBlizzardGlow(icon)

	if overrideStyle or spellColor or hasTuning or (perIconGlow and perIconGlow.color) then
		wipe(mergedGlowConfig)
		for key, value in pairs(globalConfig) do mergedGlowConfig[key] = value end
		mergedGlowConfig.perSpell = nil
		if hasTuning then
			if tuning.speed then mergedGlowConfig.speed = tuning.speed end
			if tuning.lines then mergedGlowConfig.lines = tuning.lines end
			if tuning.thickness then mergedGlowConfig.thickness = tuning.thickness end
		end
		if spellColor then mergedGlowConfig.color = spellColor end
		if perIconGlow and perIconGlow.color then mergedGlowConfig.color = perIconGlow.color end
		if overrideStyle and TypeLookup[overrideStyle] then mergedGlowConfig.type = overrideStyle end
		DispatchStart(icon, mergedGlowConfig)
	else
		DispatchStart(icon, globalConfig)
	end

	frameData.glowActive = true
	frameData.glowType   = effectiveType
	frameData.glowColor  = effectiveColor
end

function CDM.StopProcGlow(icon)
	local frameData = FrameData[icon]
	if not frameData or not frameData.glowActive then return end

	DispatchStop(icon, frameData.glowType)

	frameData.glowActive = nil
	frameData.glowType   = nil
	frameData.glowColor  = nil
end

do
	local glowsEnabled = false

	local function ReapplyIcon(icon)
		local frameData = FrameData[icon]
		if not frameData or not frameData.glowActive then return end

		CDM.StopProcGlow(icon)

		if glowsEnabled then
			CDM.HideBlizzardGlow(icon)
			CDM.StartProcGlow(icon)
		else
			CDM.ShowBlizzardGlow(icon)
		end
	end

	function CDM.RefreshActiveGlows()
		glowsEnabled = ReadGlowDB().enabled
		CDM.ForAllIcons(ReapplyIcon)
		CDM.RefreshGlowPreview()
	end
end

local function ResolveViewerIcon(frame)
	if not frame then return nil end
	local host = frame:GetParent()
	local cached = FrameData[frame]
	if cached and cached.cdmGlowResolvedIcon ~= nil and cached.cdmGlowResolvedHost == host then
		return cached.cdmGlowResolvedIcon or nil
	end

	local current = frame
	for _ = 1, 8 do
		local parent = current:GetParent()
		if not parent then break end
		local name = parent:GetName()
		if name then
			local key = CDM.ViewerNameToKey[name]
			if key and CDM.IsViewerEnabled(key) then
				local frameData = GetFrameData(frame)
				frameData.cdmGlowResolvedIcon = current
				frameData.cdmGlowResolvedHost = host
				return current
			end
		end
		current = parent
	end

	local frameData = GetFrameData(frame)
	frameData.cdmGlowResolvedIcon = false
	frameData.cdmGlowResolvedHost = host
	return nil
end

function CDM.SetupGlowHooks()
	if ActionButtonSpellAlertManager then
		local pendingHide = {}
		local hideDrainer = CreateFrame('Frame')
		hideDrainer:Hide()
		SetScript(hideDrainer, 'OnUpdate', function(self)
			self:Hide()
			for icon in pairs(pendingHide) do
				pendingHide[icon] = nil
				CDM.StopProcGlow(icon)
			end
		end)

		if ActionButtonSpellAlertManager.ShowAlert then
			hooksecurefunc(ActionButtonSpellAlertManager, 'ShowAlert', function(_, frame)
				local icon = ResolveViewerIcon(frame)
				if not icon then return end
				if not ReadGlowDB().enabled then return end

				pendingHide[icon] = nil

				local frameData = FrameData[icon]
				if frameData and frameData.glowActive then return end

				CDM.HideBlizzardGlow(icon)
				CDM.StartProcGlow(icon)
			end)
		end

		if ActionButtonSpellAlertManager.HideAlert then
			hooksecurefunc(ActionButtonSpellAlertManager, 'HideAlert', function(_, frame)
				local icon = ResolveViewerIcon(frame)
				if not icon then return end
				local frameData = FrameData[icon]
				if not frameData or not frameData.glowActive then return end
				pendingHide[icon] = true
				hideDrainer:Show()
			end)
		end
	end

	if ActionButton_ShowOverlayGlow then
		hooksecurefunc('ActionButton_ShowOverlayGlow', function(button)
			local icon = ResolveViewerIcon(button)
			if not icon then return end
			if not ReadGlowDB().enabled then return end
			local frameData = FrameData[icon]
			if frameData and frameData.glowActive then return end
			CDM.HideBlizzardGlow(icon)
			CDM.StartProcGlow(icon)
		end)
	end

	if ActionButton_HideOverlayGlow then
		hooksecurefunc('ActionButton_HideOverlayGlow', function(button)
			local icon = ResolveViewerIcon(button)
			if not icon then return end
			CDM.StopProcGlow(icon)
		end)
	end
end

do
	local preview

	local function EnsurePreview()
		if preview then return preview end

		local frame = CreateFrame('Frame', 'BUI_GlowPreview', UIParent)
		frame:SetSize(Pixel.Scale(60), Pixel.Scale(60))
		frame:SetPoint('CENTER', 0, Pixel.Scale(100))
		frame:SetFrameStrata('HIGH')
		frame:SetFrameLevel(100)

		local icon = CreateFrame('Frame', nil, frame)
		icon:SetSize(Pixel.Scale(50), Pixel.Scale(50))
		icon:SetPoint('CENTER')

		local background = icon:CreateTexture(nil, 'BACKGROUND')
		background:SetAllPoints()
		BUI.Tools.SetColorTex(background, 0.1, 0.1, 0.1, 1)

		local texture = icon:CreateTexture(nil, 'ARTWORK')
		texture:SetAllPoints()
		texture:SetTexture('Interface\\Icons\\Spell_Fire_Fireball02')
		texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon.Icon = texture

		Pixel.ApplyBorder(icon, 1, 0, 0, 0, 1)
		Pixel.ShowBorder(icon)

		frame.previewIcon = icon

		BUI.Dragging.MakeDraggable(frame, {
			showHint      = true,
			showUnlockedBg = true,
			hintAnchor    = 'TOP',
			hintText      = 'Drag to Reposition | Right-Click to Lock',
			isLocked      = function() return false end,
			onRightClick  = function()
				CDM.HideGlowPreview()
			end,
			usePointPosition = true,
		})

		preview = frame
		CDM.glowPreview = frame
		return frame
	end

	function CDM.ShowGlowPreview()
		local previewFrame = EnsurePreview()
		previewFrame:Show()
		if previewFrame.dragUnlockBg then previewFrame.dragUnlockBg:Show() end
		if previewFrame.dragHint     then previewFrame.dragHint:Show()     end
		CDM.RefreshGlowPreview()
	end

	function CDM.HideGlowPreview()
		if not preview then return end
		if preview.previewIcon then
			CDM.StopProcGlow(preview.previewIcon)
		end
		preview:Hide()
		if CDM._previewBtn and CDM._previewBtn.SetValue then
			CDM._previewBtn:SetValue(false)
		end
	end

	function CDM.RefreshGlowPreview()
		if not preview or not preview:IsShown() then return end

		local icon = preview.previewIcon
		CDM.StopProcGlow(icon)

		if ReadGlowDB().enabled then
			CDM.StartProcGlow(icon)
		end
	end
end
