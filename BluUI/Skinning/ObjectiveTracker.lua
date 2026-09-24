local _, BUI = ...

local pairs = pairs
local ipairs = ipairs
local select = select
local hooksecurefunc = hooksecurefunc

local BUILib = BluUI.BUILibClient or LibStub('BUILib')
local Theme = BUILib.Theme
local Skin3 = BUILib.Skin
local Controls = BUILib.Controls
local PageKit = BUILib.PageKit
local LibWidget = BUILib.Widget
local FONT = BUILib.Font or STANDARD_TEXT_FONT
local Skin = BUI.Skinning
local Pixel = BUI.Pixel
local sharedMedia = LibStub and LibStub('LibSharedMedia-3.0', true)
local LibEMO = LibStub and LibStub('LibEditModeOverride-1.0', true)

local LIBRARY_FONT_OPTION    = 'LIBRARY'
local DEFAULT_FONT_SIZE      = 11
local DEFAULT_CARD_OPACITY   = 98
local ROLE_SIZE_DELTA        = { line = 0, title = 1, header = 2, timer = 8 }
local POSITION_KEY           = 'objectivetracker'
local TRACKER_STASH_SCALE    = 0.01
local DEFAULT_TRACKER_COLORS = {
	title     = { 1, 0.82, 0.25 },
	hover     = { 1, 1, 1 },
	objective = { 0.85, 0.85, 0.9 },
	completed = { 0.45, 0.85, 0.45 },
	ready     = { 0.35, 1, 0.45 },
	timeLeft  = { 1, 0.45, 0.45 },
	dim       = { 0.45, 0.45, 0.5 },
}
local TIP_TEXT_MAX_LENGTH    = 46
local CARD_TEXTURE_TINT      = { 0.18, 0.19, 0.21 }
local READY_COUNT_HEX        = 'ffd140'
local PEEK_MAX_ROWS          = 12
local GLIDE_SECONDS          = 0.12
local FLASH_SECONDS          = 0.7

local GLYPH_SIZE        = 10
local BAR_LABEL_SIZE    = 11
local HEADER_TEXT_INSET = 11
local HEADER_ROW_HEIGHT = 22
local HEADER_ROW_TOP_PAD = 4
local MINIMIZE_SIZE     = 15
local BAR_ICON_SIZE     = 20
local CARD_PAD_LEFT     = 22
local CARD_PAD_RIGHT    = 10
local CARD_PAD_Y        = 6

local LAYOUT_HEIGHT     = 2600
local DEFAULT_MAX_HEIGHT = 700
local DEFAULT_TRACKER_WIDTH = 280
local SCROLL_STEP       = 44
local POI_BUTTON_SCALE  = 0.8
local POI_ANCHOR_OFFSET_X = -10
local POI_CLIP_PAD      = 16
local RIGHT_CLIP_PAD    = 34
local FLAT_TEXTURE      = 'Interface\\Buttons\\WHITE8X8'

local TRACKER_NAMES = {
	'ScenarioObjectiveTracker',
	'UIWidgetObjectiveTracker',
	'CampaignQuestObjectiveTracker',
	'QuestObjectiveTracker',
	'AdventureObjectiveTracker',
	'AchievementObjectiveTracker',
	'MonthlyActivitiesObjectiveTracker',
	'ProfessionsRecipeTracker',
	'BonusObjectiveTracker',
	'WorldQuestObjectiveTracker',
	'InitiativeTasksObjectiveTracker',
}

local addedElements = {}
local restoreHeaders = {}
local skinnedBars = {}
local hiddenTextures = {}
local restoreFonts = {}
local hiddenPoiButtons = {}
local trackerCard
local headerRow
local headerChevron
local headerCounts
local headerFilter
local scrollHolder
local scrollChild
local hostedContainer
local scrollOffset = 0
local scrollTarget = 0
local scrollTrack, scrollThumb
local queueScrollRefresh
local reasserting = false
local watchedQuestCache = {}
local readyQuestIDs = {}
local previousReadyByQuest = {}
local watchedCount = 0
local readyCount = 0
local questItemButton
local pendingMenuQuestID
local wrapAdjustedText = { titles = {}, objectives = {} }
local questClassificationLabels
local Scenario = {}
local QuestFilter = {}

local function IsEnabled()
	return Skin.IsSkinEnabled('objectivetracker')
end

local function GetSettings()
	local skinningDB = BUI.GetDB().skinning
	if not skinningDB.objectivetrackerSettings then skinningDB.objectivetrackerSettings = {} end
	return skinningDB.objectivetrackerSettings
end

local function GetSkinFont()
	local fontName = GetSettings().font
	if fontName == BUI.C.GLOBAL_OPTION then
		return BUI.GetGlobalFont() or FONT
	end
	if fontName and fontName ~= LIBRARY_FONT_OPTION and sharedMedia then
		local fetched = sharedMedia:Fetch('font', fontName, true)
		if fetched then return fetched end
	end
	return FONT
end

local function GetSkinFontFlags()
	return GetSettings().fontOutline and 'OUTLINE' or ''
end

local function GetRoleSize(role)
	return (GetSettings().fontSize or DEFAULT_FONT_SIZE) + (ROLE_SIZE_DELTA[role] or 0)
end

local function ApplySkinFont(fontString, role)
	if not fontString then return end
	local entry = restoreFonts[fontString]
	if entry then
		entry.role = role
	else
		local font, oldSize, flags = fontString:GetFont()
		restoreFonts[fontString] = { font = font, size = oldSize, flags = flags, role = role }
	end
	Pixel.ApplyFont(fontString, GetRoleSize(role), GetSkinFont(), GetSkinFontFlags())
end

local linkedPanels = {}

local FLAT_TEXTURE_OPTION = 'FLAT'

local function ApplyPanelStyle(panel)
	local settings = GetSettings()
	local opacity = (settings.cardOpacity or DEFAULT_CARD_OPACITY) / 100
	local borderColor = settings.cardBorderColor or Theme.border.light
	local borderAlpha = settings.cardBorder == false and 0 or (borderColor[4] or 1)
	local textureName = settings.cardTexture or FLAT_TEXTURE_OPTION
	local texturePath
	if textureName ~= FLAT_TEXTURE_OPTION and sharedMedia then
		texturePath = sharedMedia:Fetch('statusbar', textureName, true)
	end
	local overlay = panel.__buiCardTexture
	if texturePath then
		if not overlay then
			overlay = panel:CreateTexture(nil, 'BACKGROUND', nil, 1)
			local inset = Pixel.PixelSize(1)
			overlay:SetPoint('TOPLEFT', panel, 'TOPLEFT', inset, -inset)
			overlay:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -inset, inset)
			panel.__buiCardTexture = overlay
		end
		overlay:SetTexture(texturePath)
		local textureTint = settings.cardTextureColor or CARD_TEXTURE_TINT
		overlay:SetVertexColor(textureTint[1], textureTint[2], textureTint[3], opacity)
		overlay:Show()
		panel:SetBackdropColor(Theme.bg.dark[1], Theme.bg.dark[2], Theme.bg.dark[3], 0)
	else
		if overlay then overlay:Hide() end
		panel:SetBackdropColor(Theme.bg.dark[1], Theme.bg.dark[2], Theme.bg.dark[3], opacity)
	end
	panel:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
end

local function ApplyCardStyle()
	if trackerCard then ApplyPanelStyle(trackerCard) end
	for panel in pairs(linkedPanels) do ApplyPanelStyle(panel) end
end

Skin.trackerRules = {}

function Skin.TrackerSeparatorColor()
	local color = GetSettings().separatorColor or Theme.border.light
	return color[1], color[2], color[3], color[4] or 1
end

local normalizedTrackerColors = {}

local function NormalizeTrackerColor(color)
	if type(color) ~= 'table' then return nil end
	if type(color[1]) == 'number' and type(color[2]) == 'number' and type(color[3]) == 'number' then return color end
	if type(color.r) == 'number' and type(color.g) == 'number' and type(color.b) == 'number' then return { color.r, color.g, color.b } end
	return nil
end

function Skin.ClearTrackerColorCache()
	wipe(normalizedTrackerColors)
end

function Skin.TrackerColor(key)
	local cached = normalizedTrackerColors[key]
	if cached then return cached end
	local colors = GetSettings().colors
	local color = NormalizeTrackerColor(colors and colors[key]) or DEFAULT_TRACKER_COLORS[key] or DEFAULT_TRACKER_COLORS.objective
	if type(color[1]) ~= 'number' then color = DEFAULT_TRACKER_COLORS[key] or DEFAULT_TRACKER_COLORS.objective end
	color = { color[1], color[2], color[3] }
	normalizedTrackerColors[key] = color
	return color
end

function Skin.TrackerColorRGB(key)
	local color = Skin.TrackerColor(key)
	return color[1], color[2], color[3], 1
end

function Skin.ApplyTrackerSeparators()
	local red, green, blue, alpha = Skin.TrackerSeparatorColor()
	for rule in pairs(Skin.trackerRules) do
		rule:SetColorTexture(red, green, blue, alpha)
	end
end

function Skin.RegisterTrackerPanel(frame)
	linkedPanels[frame] = true
	ApplyCardStyle()
end

function Skin.GetTrackerPanelOutsets()
	return Pixel.PixelSize(CARD_PAD_LEFT), Pixel.PixelSize(CARD_PAD_RIGHT), Pixel.PixelSize(CARD_PAD_Y)
end

function Skin.TrackerModulesOrdered()
	for _, trackerName in ipairs(TRACKER_NAMES) do
		local module = _G[trackerName]
		if module and module.uiOrder == nil then return false end
	end
	return true
end

local function RefreshTrackerLayout()
	if not hostedContainer then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(RefreshTrackerLayout, 'Skinning.TrackerRefresh')
		return
	end
	if not Skin.TrackerModulesOrdered() then return end
	hostedContainer:UpdateHeight()
	hostedContainer:Update()
end

local function GetMaxTrackerHeight()
	return GetSettings().maxHeight or DEFAULT_MAX_HEIGHT
end

local function GetTrackerWidth()
	return GetSettings().trackerWidth or DEFAULT_TRACKER_WIDTH
end

local function IsFiniteNumber(value)
	if type(value) ~= 'number' then return false end
	if issecretvalue and issecretvalue(value) then return false end
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function IsEditModeActive()
	return _G.EditModeManagerFrame and _G.EditModeManagerFrame.IsEditModeActive and _G.EditModeManagerFrame:IsEditModeActive() or false
end

local function GetFallbackTrackerAnchor()
	local right = scrollHolder and scrollHolder:GetRight()
	local top = scrollHolder and scrollHolder:GetTop()
	if IsFiniteNumber(right) and IsFiniteNumber(top) then
		return right + Pixel.Scale(RIGHT_CLIP_PAD), top
	end
	return UIParent:GetWidth() - 90, UIParent:GetHeight() - 260
end

local function HasUsableRect(frame)
	local left, bottom, width, height = frame:GetRect()
	return IsFiniteNumber(left) and IsFiniteNumber(bottom) and IsFiniteNumber(width) and IsFiniteNumber(height)
end

local function LogTrackerEvent(eventText)
	local log = Skin.trackerEventLog
	if not log then
		log = {}
		Skin.trackerEventLog = log
	end
	log[#log + 1] = ('%.2f %s'):format(GetTime(), eventText)
	if #log > 30 then table.remove(log, 1) end
end

local function RepairSelectionRect(mainTracker)
	local selection = mainTracker.Selection
	if not selection or HasUsableRect(selection) then return end
	selection:ClearAllPoints()
	selection:SetPoint('TOPLEFT', mainTracker, 'TOPLEFT', -30, 0)
	selection:SetPoint('BOTTOMRIGHT', mainTracker, 'BOTTOMRIGHT', 0, 0)
end

local function RepairTrackerRect()
	local mainTracker = _G.ObjectiveTrackerFrame
	if not mainTracker then return end
	if mainTracker.isDragging then return end
	if not HasUsableRect(mainTracker) then
		reasserting = true
		local offsetX, offsetY = GetFallbackTrackerAnchor()
		mainTracker:ClearAllPoints()
		mainTracker:SetPoint('TOPRIGHT', UIParent, 'BOTTOMLEFT', offsetX, offsetY)
		if not IsFiniteNumber(mainTracker:GetWidth()) or mainTracker:GetWidth() < 1 then
			mainTracker:SetWidth(GetTrackerWidth())
		end
		if not IsFiniteNumber(mainTracker:GetHeight()) or mainTracker:GetHeight() < 1 then
			local holderHeight = scrollHolder and scrollHolder:GetHeight()
			mainTracker:SetHeight(math.max(200, IsFiniteNumber(holderHeight) and holderHeight or 200))
		end
		reasserting = false
	end
	RepairSelectionRect(mainTracker)
end

local QueueTrackerRectRepair = BUI.Dispatcher.New(RepairTrackerRect, 'Skinning.TrackerRectRepair')

local function ApplyEditModeHeight()
	if not LibEMO or not IsEnabled() then return end
	if GetSettings().scrollEnabled == true then return end
	if InCombatLockdown() then return end
	if IsEditModeActive() then return end
	local trackerFrame = _G.ObjectiveTrackerFrame
	if not trackerFrame or not Enum.EditModeObjectiveTrackerSetting then return end
	if not LibEMO:IsReady() then
		BUI.Events:Once('EDIT_MODE_LAYOUTS_UPDATED', 'Skinning.TrackerEditModeHeight', function()
			ApplyEditModeHeight()
		end)
		return
	end
	local target = math.max(400, math.min(600, GetMaxTrackerHeight()))
	LibEMO:LoadLayouts()
	if not LibEMO:CanEditActiveLayout() then return end
	if not LibEMO:HasEditModeSettings(trackerFrame) then return end
	if LibEMO:GetFrameSetting(trackerFrame, Enum.EditModeObjectiveTrackerSetting.Height) ~= target then
		if BUI.CanWriteEditModeLayout() then
			LibEMO:SetFrameSetting(trackerFrame, Enum.EditModeObjectiveTrackerSetting.Height, target)
			LibEMO:SaveOnly()
		end
	end
	local point, relativePoint, x, y = Skin.SavedPosition(POSITION_KEY)
	if point then BUI.LeaveFrameManager(trackerFrame, point, relativePoint, x, y) end
end

local function GetTrackerContentHeight()
	if not hostedContainer then return 0 end
	local total = 0
	local spacing = hostedContainer.moduleSpacing or 10
	for _, trackerName in ipairs(TRACKER_NAMES) do
		local module = _G[trackerName]
		if module and module.GetContentsHeight and module:GetParent() == hostedContainer then
			local moduleHeight = module:GetContentsHeight()
			if moduleHeight and moduleHeight > 0 then
				if total > 0 then total = total + spacing end
				total = total + moduleHeight
			end
		end
	end
	if total > 0 then
		total = total + (hostedContainer.topModulePadding or 0) + (hostedContainer.bottomModulePadding or 10)
	end
	return total
end

local function AdoptModules()
	if not hostedContainer then return end
	if not IsEnabled() or GetSettings().scrollEnabled ~= true then return end
	if not Skin.TrackerModulesOrdered() then return end
	if IsEditModeActive() then return end
	local manager = _G.ObjectiveTrackerManager
	local mainTracker = _G.ObjectiveTrackerFrame
	if not manager or not manager.moduleToContainerMap or not mainTracker then return end
	for _, trackerName in ipairs(TRACKER_NAMES) do
		local module = _G[trackerName]
		if module then
			local target = QuestFilter.SectionShown(trackerName) and hostedContainer or mainTracker
			if manager.moduleToContainerMap[module] ~= target then
				manager:SetModuleContainer(module, target)
			end
		end
	end
	mainTracker:SetAlpha(0)
	if mainTracker.Header then
		mainTracker.Header:EnableMouse(false)
		if mainTracker.Header.MinimizeButton then mainTracker.Header.MinimizeButton:EnableMouse(false) end
	end
	if not hostedContainer:IsShown() then hostedContainer:Show() end
	RefreshTrackerLayout()
end

local function ReleaseModules()
	local manager = _G.ObjectiveTrackerManager
	local mainTracker = _G.ObjectiveTrackerFrame
	if not hostedContainer or not manager or not manager.moduleToContainerMap or not mainTracker then return end
	for _, trackerName in ipairs(TRACKER_NAMES) do
		local module = _G[trackerName]
		if module and manager.moduleToContainerMap[module] == hostedContainer then
			manager:SetModuleContainer(module, mainTracker)
		end
	end
	mainTracker:SetAlpha(1)
	if mainTracker.Header then
		mainTracker.Header:EnableMouse(true)
		if mainTracker.Header.MinimizeButton then mainTracker.Header.MinimizeButton:EnableMouse(true) end
	end
end

function Skin.TrackerRepairEditModeAnchor()
	if not LibEMO or not IsEnabled() then return end
	if InCombatLockdown() then return end
	if IsEditModeActive() then return end
	local trackerFrame = _G.ObjectiveTrackerFrame
	if not trackerFrame then return end
	local scrollMode = scrollHolder ~= nil and GetSettings().scrollEnabled == true
	if not scrollMode and HasUsableRect(trackerFrame) then return end
	if not BUI.CanWriteEditModeLayout() then return end
	if not LibEMO:IsReady() then
		BUI.Events:Once('EDIT_MODE_LAYOUTS_UPDATED', 'Skinning.TrackerAnchorRepair', Skin.TrackerRepairEditModeAnchor)
		return
	end
	LibEMO:LoadLayouts()
	if not LibEMO:CanEditActiveLayout() then
		LogTrackerEvent('edit mode anchor repair skipped: preset layout')
		return
	end
	if not LibEMO:HasEditModeSettings(trackerFrame) then return end
	local right, top
	if scrollMode then
		right, top = scrollHolder:GetRight(), scrollHolder:GetTop()
	end
	if not IsFiniteNumber(right) or not IsFiniteNumber(top) then
		right, top = trackerFrame:GetRight(), trackerFrame:GetTop()
	end
	if not IsFiniteNumber(right) or not IsFiniteNumber(top) then
		right, top = UIParent:GetWidth() - 90, UIParent:GetHeight() - 260
	end
	LibEMO:ReanchorFrame(trackerFrame, 'TOPRIGHT', UIParent, 'BOTTOMLEFT', right, top)
	LibEMO:SaveOnly()
	RepairTrackerRect()
end

local QueueTrackerAnchorRepair = BUI.Dispatcher.New(function()
	Skin.TrackerRepairEditModeAnchor()
end, 'Skinning.TrackerAnchorRepairQueue')

function Skin.TrackerEditModeHooks()
	if Skin.trackerEditModeHooked then return end
	if not EventRegistry or not EventRegistry.RegisterCallback then return end
	Skin.trackerEditModeHooked = true
	local guardedFrame = _G.ObjectiveTrackerFrame
	if guardedFrame and GetSettings().scrollEnabled == true and not guardedFrame.__buiSafeSelectionSides then
		guardedFrame.__buiSafeSelectionSides = true
		local function GuardMethod(methodName, fallback)
			local blizzardMethod = guardedFrame[methodName]
			if type(blizzardMethod) ~= 'function' then return end
			guardedFrame[methodName] = function(self, ...)
				local ok, first, second, third, fourth = pcall(blizzardMethod, self, ...)
				if ok and first ~= nil then return first, second, third, fourth end
				Skin.trackerGuardTrips = (Skin.trackerGuardTrips or 0) + 1
				Skin.trackerGuardLast = ('%s frameRect=%s frameShown=%s selectionPoints=%s selectionShown=%s movable=%s selected=%s'):format(
					methodName, tostring(HasUsableRect(self)), tostring(self:IsShown()),
					tostring(self.Selection and self.Selection:GetNumPoints() or 'nil'),
					tostring(self.Selection and self.Selection:IsShown() or 'nil'),
					tostring(self:IsMovable()), tostring(self.isSelected))
				return fallback(self)
			end
		end
		local function GetRectOrDraggedRect(self)
			local left, bottom, width, height = self:GetRect()
			if IsFiniteNumber(left) and IsFiniteNumber(bottom) and IsFiniteNumber(width) and IsFiniteNumber(height) then
				return left, bottom, width, height
			end
			if not self.isDragging then return nil end
			width = self:GetWidth()
			height = self:GetHeight()
			if not IsFiniteNumber(width) or width < 1 then width = GetTrackerWidth() end
			if not IsFiniteNumber(height) or height < 1 then height = 400 end
			local effectiveScale = self:GetEffectiveScale()
			if not IsFiniteNumber(effectiveScale) or effectiveScale <= 0 then effectiveScale = 1 end
			local cursorX, cursorY = GetCursorPosition()
			if not IsFiniteNumber(cursorX) or not IsFiniteNumber(cursorY) then return nil end
			return cursorX / effectiveScale - width / 2, cursorY / effectiveScale - height / 2, width, height
		end
		GuardMethod('GetScaledSelectionSides', function(self)
			local left, bottom, width, height = GetRectOrDraggedRect(self)
			if left then
				local scale = self:GetScale()
				return (left - 30) * scale, (left + width) * scale, bottom * scale, (bottom + height) * scale
			end
			return 0, 0, 0, 0
		end)
		GuardMethod('GetScaledSelectionCenter', function(self)
			local left, bottom, width, height = GetRectOrDraggedRect(self)
			if left then
				local scale = self:GetScale()
				return (left + width / 2 - 15) * scale, (bottom + height / 2) * scale
			end
			return 0, 0
		end)
		GuardMethod('GetScaledCenter', function(self)
			local left, bottom, width, height = GetRectOrDraggedRect(self)
			if left then
				local scale = self:GetScale()
				return (left + width / 2) * scale, (bottom + height / 2) * scale
			end
			return 0, 0
		end)
		GuardMethod('GetSelectionOffset', function()
			return 0
		end)
	end
	if guardedFrame and not guardedFrame.__buiStateProbes then
		guardedFrame.__buiStateProbes = true
		guardedFrame:HookScript('OnHide', function(self)
			if IsEditModeActive() then LogTrackerEvent('tracker hidden dragging=' .. tostring(self.isDragging)) end
		end)
		guardedFrame:HookScript('OnShow', function()
			if IsEditModeActive() then LogTrackerEvent('tracker shown') end
		end)
		if guardedFrame.Selection then
			guardedFrame.Selection:HookScript('OnHide', function()
				if IsEditModeActive() then LogTrackerEvent('selection hidden dragging=' .. tostring(guardedFrame.isDragging)) end
			end)
			guardedFrame.Selection:HookScript('OnShow', function()
				if IsEditModeActive() then LogTrackerEvent('selection shown') end
			end)
		end
		hooksecurefunc(guardedFrame, 'SetMovable', function(self, movable)
			if IsEditModeActive() then
				LogTrackerEvent(('setmovable %s dragging=%s'):format(tostring(movable), tostring(self.isDragging)))
			end
		end)
		hooksecurefunc(guardedFrame, 'ClearAllPoints', function(self)
			if self.isDragging then LogTrackerEvent('clearallpoints during drag') end
		end)
		if type(guardedFrame.OnDragStart) == 'function' then
			hooksecurefunc(guardedFrame, 'OnDragStart', function(self)
				LogTrackerEvent(('dragstart selected=%s movable=%s rect=%s selShown=%s selRect=%s'):format(
					tostring(self.isSelected), tostring(self:IsMovable()), tostring(HasUsableRect(self)),
					tostring(self.Selection and self.Selection:IsShown()),
					tostring(self.Selection and HasUsableRect(self.Selection))))
			end)
		end
		if type(guardedFrame.OnDragStop) == 'function' then
			hooksecurefunc(guardedFrame, 'OnDragStop', function(self)
				LogTrackerEvent(('dragstop mousedown=%s selected=%s shown=%s selShown=%s rect=%s'):format(
					tostring(IsMouseButtonDown('LeftButton')), tostring(self.isSelected), tostring(self:IsShown()),
					tostring(self.Selection and self.Selection:IsShown()), tostring(HasUsableRect(self))))
			end)
		end
	end
	if _G.EditModeManagerFrame and _G.EditModeManagerFrame.SetSnapPreviewFrame then
		hooksecurefunc(_G.EditModeManagerFrame, 'SetSnapPreviewFrame', function(_, frame)
			local mainTracker = _G.ObjectiveTrackerFrame
			if not frame or frame ~= mainTracker or not IsEnabled() then return end
			local point, relativeTo, relativePoint, offsetX, offsetY = mainTracker:GetPoint(1)
			Skin.trackerDragState = {
				numPoints = mainTracker:GetNumPoints(),
				point = tostring(point),
				relativeTo = relativeTo and ((relativeTo.GetName and relativeTo:GetName()) or tostring(relativeTo)) or 'nil',
				relativePoint = tostring(relativePoint),
				offsetX = tostring(offsetX),
				offsetY = tostring(offsetY),
				parent = tostring(mainTracker:GetParent() and mainTracker:GetParent():GetName() or mainTracker:GetParent()),
				frameRectOk = HasUsableRect(mainTracker),
				frameShown = mainTracker:IsShown(),
				selectionRectOk = mainTracker.Selection and HasUsableRect(mainTracker.Selection) or false,
				selectionPoints = tostring(mainTracker.Selection and mainTracker.Selection:GetNumPoints() or 'nil'),
				selectionShown = tostring(mainTracker.Selection and mainTracker.Selection:IsShown() or 'nil'),
				width = tostring(mainTracker:GetWidth()),
				height = tostring(mainTracker:GetHeight()),
			}
		end)
	end
	BUI.Events:Register('EDIT_MODE_LAYOUTS_UPDATED', 'Skinning.TrackerRectRepair', function()
		if IsEnabled() and IsEditModeActive() then QueueTrackerRectRepair() end
	end)
	EventRegistry:RegisterCallback('EditMode.Enter', function()
		if not IsEnabled() then return end
		local mainTracker = _G.ObjectiveTrackerFrame
		if not mainTracker then return end
		if scrollHolder and GetSettings().scrollEnabled == true then
			if not mainTracker.__buiNativeWidth then mainTracker.__buiNativeWidth = mainTracker:GetWidth() end
			local overlayTarget = (trackerCard and trackerCard:IsShown() and trackerCard) or scrollHolder
			local overlayRight, overlayTop = overlayTarget:GetRight(), overlayTarget:GetTop()
			local overlayWidth, overlayHeight = overlayTarget:GetWidth(), overlayTarget:GetHeight()
			if IsFiniteNumber(overlayWidth) and overlayWidth > 50 then
				mainTracker:SetWidth(overlayWidth)
			else
				mainTracker:SetWidth(GetTrackerWidth() + Pixel.Scale(POI_CLIP_PAD) + Pixel.Scale(RIGHT_CLIP_PAD))
			end
			if IsFiniteNumber(overlayHeight) and overlayHeight > 50 then
				mainTracker:SetHeight(overlayHeight)
				if mainTracker.__buiNativeEditModeHeight == nil then
					mainTracker.__buiNativeEditModeHeight = mainTracker.editModeHeight or false
				end
				mainTracker.editModeHeight = overlayHeight
			end
			if IsFiniteNumber(overlayRight) and IsFiniteNumber(overlayTop) then
				reasserting = true
				mainTracker:ClearAllPoints()
				mainTracker:SetPoint('TOPRIGHT', UIParent, 'BOTTOMLEFT', overlayRight, overlayTop)
				reasserting = false
			end
			mainTracker:SetAlpha(1)
			if mainTracker.Header then mainTracker.Header:SetAlpha(0) end
			if not mainTracker.isLocked then
				mainTracker.__buiLockedForEditMode = true
				mainTracker.isLocked = true
			end
			if not Skin.printedTrackerMoveHint then
				Skin.printedTrackerMoveHint = true
				BUI.Print('Objective tracker: Edit Mode moving is disabled for the scrolling tracker. Hold Ctrl and drag the tracker header to move it; sizing lives in BluUI settings.')
			end
		end
		RepairTrackerRect()
		QueueTrackerRectRepair()
	end, QuestFilter)
	EventRegistry:RegisterCallback('EditMode.Exit', function()
		if not IsEnabled() then return end
		local mainTracker = _G.ObjectiveTrackerFrame
		if mainTracker and mainTracker.__buiLockedForEditMode then
			mainTracker.__buiLockedForEditMode = nil
			mainTracker.isLocked = nil
		end
		if mainTracker and mainTracker.Header then mainTracker.Header:SetAlpha(1) end
		if mainTracker and mainTracker.__buiNativeEditModeHeight ~= nil then
			mainTracker.editModeHeight = mainTracker.__buiNativeEditModeHeight or nil
			mainTracker.__buiNativeEditModeHeight = nil
		end
		if scrollHolder and mainTracker and mainTracker.__buiNativeWidth then
			mainTracker:SetWidth(mainTracker.__buiNativeWidth)
			mainTracker.__buiNativeWidth = nil
		end
		QueueTrackerAnchorRepair()
		if scrollHolder and IsEnabled() then AdoptModules() end
	end, QuestFilter)
end

local function EnsureHostedContainer()
	if hostedContainer or not scrollChild then return end
	local manager = _G.ObjectiveTrackerManager
	if not manager or not manager.AddContainer then return end
	local staging = CreateFrame('Frame')
	staging:Hide()
	local mixin = _G.ObjectiveTrackerContainerMixin
	local savedOnShow = mixin and mixin.OnShow
	if savedOnShow then mixin.OnShow = function() end end
	local container = CreateFrame('Frame', 'BUI_TrackerContainer', staging, 'ObjectiveTrackerContainerTemplate')
	if savedOnShow then mixin.OnShow = savedOnShow end
	container.modules = {}
	container:SetScript('OnShow', function(self) self:UpdateHeight() end)
	container.editModeHeight = LAYOUT_HEIGHT
	container.IsInDefaultPosition = function() return false end
	container.SetCollapsed = function(self, collapsed)
		self.isCollapsed = collapsed and true or false
		self:Update()
	end
	hostedContainer = container
	manager:AddContainer(container)
	if container.SetDirtyMethod then
		container:SetDirtyMethod(function()
			if Skin.TrackerModulesOrdered() then container:Update(true) end
		end)
	end
	hooksecurefunc(container, 'Update', function()
		if queueScrollRefresh then queueScrollRefresh() end
	end)
	local mainTracker = _G.ObjectiveTrackerFrame
	if mainTracker and mainTracker.AddModule then
		local queueAdopt = BUI.Dispatcher.New(AdoptModules, 'Skinning.TrackerAdopt')
		hooksecurefunc(mainTracker, 'AddModule', queueAdopt)
	end
	container:SetParent(scrollChild)
	container:SetPoint('TOPLEFT', scrollChild, 'TOPLEFT', Pixel.Scale(POI_CLIP_PAD), 0)
	container:SetPoint('TOPRIGHT', scrollChild, 'TOPRIGHT', -Pixel.Scale(RIGHT_CLIP_PAD), 0)
	AdoptModules()
	container:UpdateHeight()
end

local function RefreshScroll()
	if not scrollHolder or not IsEnabled() then return end
	local containerHidden = hostedContainer and not hostedContainer:IsShown()
	local contentHeight = GetTrackerContentHeight()
	if headerRow and (GetSettings().trackerCollapsed == true or containerHidden or contentHeight <= 0) then
		if math.abs((scrollHolder:GetHeight() or 0) - 1) > 0.01 then scrollHolder:SetHeight(1) end
		if math.abs(scrollHolder:GetAlpha() or 0) > 0.01 then scrollHolder:SetAlpha(0) end
		scrollOffset = 0
		scrollTarget = 0
		if math.abs(scrollHolder:GetVerticalScroll() or 0) > 0.01 then scrollHolder:SetVerticalScroll(0) end
		if scrollTrack and scrollTrack:IsShown() then scrollTrack:Hide() end
		if scrollThumb and scrollThumb:IsShown() then scrollThumb:Hide() end
		if trackerCard then
			local keepStrip = GetSettings().trackerCollapsed == true or (QuestFilter.HasActive and QuestFilter.HasActive())
			local wantCard = (keepStrip and scrollHolder:IsShown()) and true or false
			if trackerCard:IsShown() ~= wantCard then trackerCard:SetShown(wantCard) end
		end
		return
	end
	if contentHeight <= 0 then return end
	if math.abs((scrollHolder:GetAlpha() or 0) - 1) > 0.01 then scrollHolder:SetAlpha(1) end
	if trackerCard then
		local wantCard = scrollHolder:IsShown() and true or false
		if trackerCard:IsShown() ~= wantCard then trackerCard:SetShown(wantCard) end
	end
	local windowHeight = math.min(contentHeight, GetMaxTrackerHeight())
	if math.abs((scrollHolder:GetHeight() or 0) - windowHeight) > 0.01 then scrollHolder:SetHeight(windowHeight) end
	local maxOffset = math.max(0, contentHeight - windowHeight)
	if scrollOffset > maxOffset then scrollOffset = maxOffset end
	if scrollTarget > maxOffset then scrollTarget = maxOffset end
	if scrollTarget < 0 then scrollTarget = 0 end
	if math.abs((scrollHolder:GetVerticalScroll() or 0) - scrollOffset) > 0.01 then scrollHolder:SetVerticalScroll(scrollOffset) end

	local overflow = maxOffset > 0
	if scrollTrack then
		if scrollTrack:IsShown() ~= overflow then scrollTrack:SetShown(overflow) end
		if scrollThumb:IsShown() ~= overflow then scrollThumb:SetShown(overflow) end
		if overflow then
			local trackHeight = scrollTrack:GetHeight() or 0
			if trackHeight > 0 then
				local thumbHeight = math.max(Pixel.Scale(20), trackHeight * windowHeight / contentHeight)
				if math.abs((scrollThumb:GetHeight() or 0) - thumbHeight) > 0.01 then scrollThumb:SetHeight(thumbHeight) end
				local travel = math.max(0, trackHeight - thumbHeight)
				scrollThumb:SetPoint('TOP', scrollTrack, 'TOP', 0, -(travel * scrollOffset / maxOffset))
			end
		end
	end
end

local glide = { from = 0, startTime = 0 }

local function GlideStep()
	local progress = math.min(1, (GetTime() - glide.startTime) / GLIDE_SECONDS)
	local remaining = 1 - progress
	scrollOffset = glide.from + (scrollTarget - glide.from) * (1 - remaining * remaining)
	if progress >= 1 then
		scrollOffset = scrollTarget
		glide.frame:Hide()
	end
	RefreshScroll()
end

local function StartScrollGlide()
	glide.from = scrollOffset
	glide.startTime = GetTime()
	if not glide.frame then
		glide.frame = CreateFrame('Frame')
		glide.frame:SetScript('OnUpdate', GlideStep)
	end
	glide.frame:Show()
end

local function OnTrackerWheel(_, delta)
	if not scrollHolder or not IsEnabled() then return end
	if headerRow and GetSettings().trackerCollapsed == true then return end
	local contentHeight = GetTrackerContentHeight()
	local maxOffset = math.max(0, contentHeight - scrollHolder:GetHeight())
	local newTarget = math.max(0, math.min(maxOffset, scrollTarget - delta * Pixel.Scale(SCROLL_STEP)))
	if newTarget == scrollTarget then return end
	scrollTarget = newTarget
	StartScrollGlide()
end

function Skin.ForwardTrackerWheel(frame)
	if not frame or frame:GetScript('OnMouseWheel') == OnTrackerWheel then return end
	frame:EnableMouseWheel(true)
	frame:SetScript('OnMouseWheel', OnTrackerWheel)
end

local function EnsureScrollHolder()
	if GetSettings().scrollEnabled ~= true then return end
	if scrollHolder then
		EnsureHostedContainer()
		return
	end
	local manager = _G.ObjectiveTrackerManager
	if not manager or not manager.AddContainer or not manager.SetModuleContainer then return end
	local trackerFrame = _G.ObjectiveTrackerFrame

	scrollHolder = CreateFrame('ScrollFrame', 'BUI_TrackerScroll', UIParent)
	scrollHolder:SetClipsChildren(true)
	local width = GetTrackerWidth() + Pixel.Scale(POI_CLIP_PAD) + Pixel.Scale(RIGHT_CLIP_PAD)
	scrollHolder:SetSize(width, GetMaxTrackerHeight())
	local right = trackerFrame and trackerFrame:GetRight()
	local top = trackerFrame and trackerFrame:GetTop()
	if IsFiniteNumber(right) and IsFiniteNumber(top) then
		scrollHolder:SetPoint('TOPRIGHT', UIParent, 'BOTTOMLEFT', right + Pixel.Scale(RIGHT_CLIP_PAD), top)
	else
		scrollHolder:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -90, -260)
	end
	scrollHolder:SetMovable(true)
	scrollHolder:SetClampedToScreen(true)
	scrollHolder:EnableMouseWheel(true)
	scrollHolder:SetScript('OnMouseWheel', OnTrackerWheel)

	scrollChild = CreateFrame('Frame', 'BUI_TrackerScrollChild', scrollHolder)
	scrollChild:SetSize(width, LAYOUT_HEIGHT)
	scrollHolder:SetScrollChild(scrollChild)

	queueScrollRefresh = BUI.Dispatcher.New(RefreshScroll, 'Skinning.TrackerScroll')
	EnsureHostedContainer()
end

local function ApplyTrackerWidth()
	if not scrollHolder then return end
	local width = GetTrackerWidth()
	local holderWidth = width + Pixel.Scale(POI_CLIP_PAD) + Pixel.Scale(RIGHT_CLIP_PAD)
	scrollHolder:SetWidth(holderWidth)
	scrollChild:SetWidth(holderWidth)
	for _, trackerName in ipairs(TRACKER_NAMES) do
		local module = _G[trackerName]
		if module then module:SetWidth(width - Pixel.Scale(8)) end
	end
end

local function GetTrackerSlideOffset()
	local total = 0
	for _, trackerName in ipairs(TRACKER_NAMES) do
		local module = _G[trackerName]
		if module and module.heightModifiers then
			for _, height in pairs(module.heightModifiers) do total = total + height end
		end
	end
	return total
end

local function UpdateCardAnchors()
	if not trackerCard then return end
	local trackerFrame = _G.ObjectiveTrackerFrame
	local padLeft = Pixel.PixelSize(CARD_PAD_LEFT)
	local padRight = Pixel.PixelSize(CARD_PAD_RIGHT)
	local padY = Pixel.PixelSize(CARD_PAD_Y)
	trackerCard:ClearAllPoints()
	if scrollHolder then
		local rowShown = headerRow and headerRow:IsShown()
		local rowHeight = rowShown and (headerRow:GetHeight() + Pixel.Scale(HEADER_ROW_TOP_PAD)) or 0
		local cardGapLeft, cardGapRight = CARD_PAD_LEFT, CARD_PAD_RIGHT
		trackerCard:SetPoint('TOPLEFT', scrollHolder, 'TOPLEFT', Pixel.Scale(POI_CLIP_PAD - cardGapLeft), padY + rowHeight)
		trackerCard:SetPoint('TOPRIGHT', scrollHolder, 'TOPRIGHT', -Pixel.Scale(RIGHT_CLIP_PAD - cardGapRight), padY + rowHeight)
		scrollHolder:SetClampRectInsets(Pixel.Scale(POI_CLIP_PAD - cardGapLeft), -Pixel.Scale(RIGHT_CLIP_PAD - cardGapRight), padY + rowHeight, -padY)
		local containerHidden = hostedContainer and not hostedContainer:IsShown()
		if rowShown and (GetSettings().trackerCollapsed == true or containerHidden) then
			trackerCard:SetPoint('BOTTOM', scrollHolder, 'TOP', 0, 0)
		else
			trackerCard:SetPoint('BOTTOM', scrollHolder, 'BOTTOM', 0, -padY)
		end
		return
	end
	if not trackerFrame then return end
	trackerCard:SetPoint('TOPLEFT', trackerFrame, 'TOPLEFT', -padLeft, padY)
	trackerCard:SetPoint('TOPRIGHT', trackerFrame, 'TOPRIGHT', padRight, padY)
	local collapsed = trackerFrame.IsCollapsed and trackerFrame:IsCollapsed()
	if collapsed and trackerFrame.Header then
		trackerCard:SetPoint('BOTTOM', trackerFrame.Header, 'BOTTOM', 0, -padY)
	elseif trackerFrame.NineSlice then
		trackerCard:SetPoint('BOTTOM', trackerFrame.NineSlice, 'BOTTOM', 0, GetTrackerSlideOffset() - padY)
	else
		trackerCard:SetPoint('BOTTOM', trackerFrame, 'BOTTOM', 0, -padY)
	end
end

local function FollowTrackerSlide()
	if not scrollHolder then UpdateCardAnchors() end
end

local function SyncTrackerCardShown()
	if not trackerCard then return end
	if scrollHolder then
		trackerCard:SetShown(IsEnabled() and scrollHolder:IsShown())
		UpdateCardAnchors()
		RefreshScroll()
		return
	end
	local trackerFrame = _G.ObjectiveTrackerFrame
	local nineSlice = trackerFrame and trackerFrame.NineSlice
	local shown = IsEnabled() and not Skin.trackerStashScale and not Skin.trackerFadedOut
	if nineSlice then
		trackerCard:SetShown(shown and nineSlice:IsShown())
	else
		trackerCard:SetShown(shown)
	end
end

local function EnsureTrackerCard()
	local trackerFrame = _G.ObjectiveTrackerFrame
	local mirrorFrame = hostedContainer or trackerFrame
	if not mirrorFrame then return end
	local nineSlice = mirrorFrame.NineSlice
	if not trackerCard then
		trackerCard = CreateFrame('Frame', 'BUI_TrackerPanel', UIParent, 'BackdropTemplate')
		trackerCard:SetFrameStrata('LOW')
		trackerCard:SetFrameLevel(0)
		Skin3.Backdrop(trackerCard, { bg = Theme.bg.dark, border = Theme.border.light })

		trackerCard:EnableMouse(true)
		trackerCard:EnableMouseWheel(true)
		trackerCard:SetScript('OnMouseWheel', OnTrackerWheel)
		trackerCard:HookScript('OnSizeChanged', Skin.TrackerClamp)

		scrollTrack = CreateFrame('Frame', nil, trackerCard)
		scrollTrack:SetWidth(Pixel.PixelSize(8))
		scrollTrack:SetPoint('TOPRIGHT', trackerCard, 'TOPRIGHT', -Pixel.PixelSize(2), -Pixel.PixelSize(CARD_PAD_Y))
		scrollTrack:SetPoint('BOTTOMRIGHT', trackerCard, 'BOTTOMRIGHT', -Pixel.PixelSize(2), Pixel.PixelSize(CARD_PAD_Y))
		local trackTexture = scrollTrack:CreateTexture(nil, 'ARTWORK')
		trackTexture:SetPoint('TOP')
		trackTexture:SetPoint('BOTTOM')
		trackTexture:SetWidth(Pixel.PixelSize(3))
		trackTexture:SetColorTexture(1, 1, 1, 0.06)
		scrollTrack:Hide()

		scrollThumb = CreateFrame('Frame', nil, scrollTrack)
		scrollThumb:SetWidth(Pixel.PixelSize(8))
		scrollThumb:SetPoint('TOP', scrollTrack, 'TOP', 0, 0)
		scrollThumb:EnableMouse(true)
		local thumbTexture = scrollThumb:CreateTexture(nil, 'ARTWORK', nil, 1)
		thumbTexture:SetPoint('TOP')
		thumbTexture:SetPoint('BOTTOM')
		thumbTexture:SetWidth(Pixel.PixelSize(3))
		thumbTexture:SetColorTexture(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3], 0.8)
		scrollThumb:Hide()

		local dragStartCursorY = 0
		local dragStartOffset = 0
		local function EndThumbDrag()
			scrollThumb:SetScript('OnUpdate', nil)
			thumbTexture:SetColorTexture(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3], 0.8)
		end
		local function ThumbDragUpdate(self)
			if not IsMouseButtonDown('LeftButton') then EndThumbDrag() return end
			if not scrollHolder then return end
			local _, cursorY = GetCursorPosition()
			local deltaPixels = (dragStartCursorY - cursorY) / self:GetEffectiveScale()
			local contentHeight = GetTrackerContentHeight()
			local maxOffset = math.max(0, contentHeight - scrollHolder:GetHeight())
			local travel = math.max(1, (scrollTrack:GetHeight() or 1) - (self:GetHeight() or 1))
			scrollOffset = math.max(0, math.min(maxOffset, dragStartOffset + deltaPixels * maxOffset / travel))
			scrollTarget = scrollOffset
			RefreshScroll()
		end
		scrollThumb:SetScript('OnMouseDown', function()
			local _, cursorY = GetCursorPosition()
			dragStartCursorY = cursorY
			dragStartOffset = scrollOffset
			thumbTexture:SetColorTexture(1, 1, 1, 0.9)
			scrollThumb:SetScript('OnUpdate', ThumbDragUpdate)
		end)
		scrollThumb:SetScript('OnMouseUp', EndThumbDrag)
		if mirrorFrame.SetCollapsed then hooksecurefunc(mirrorFrame, 'SetCollapsed', UpdateCardAnchors) end
		if nineSlice then
			nineSlice:SetAlpha(0)
			hooksecurefunc(nineSlice, 'SetAlpha', function(self, alpha)
				if IsEnabled() and alpha ~= 0 then self:SetAlpha(0) end
			end)
			nineSlice:HookScript('OnShow', SyncTrackerCardShown)
			nineSlice:HookScript('OnHide', SyncTrackerCardShown)
		end
		mirrorFrame:HookScript('OnHide', SyncTrackerCardShown)
		mirrorFrame:HookScript('OnShow', SyncTrackerCardShown)
		for _, trackerName in ipairs(TRACKER_NAMES) do
			local module = _G[trackerName]
			if module then
				hooksecurefunc(module, 'SetHeightModifier', FollowTrackerSlide)
				hooksecurefunc(module, 'ClearHeightModifier', FollowTrackerSlide)
			end
		end
		if mirrorFrame == trackerFrame then
			hooksecurefunc(trackerFrame, 'SetAlpha', function(_, alpha)
				local fadedOut = not issecretvalue(alpha) and alpha == 0 and not Skin.trackerStashScale
				if fadedOut == (Skin.trackerFadedOut or false) then return end
				Skin.trackerFadedOut = fadedOut or nil
				SyncTrackerCardShown()
			end)
		end
	end
	UpdateCardAnchors()
	ApplyCardStyle()
	SyncTrackerCardShown()
end

local styleOverrides

local function GetStyleOverrides()
	if styleOverrides then return styleOverrides end
	local palette = _G.OBJECTIVE_TRACKER_COLOR
	if not palette then return nil end
	styleOverrides = {}
	local map = {
		Header             = Skin.TrackerColor('title'),
		HeaderHighlight    = Skin.TrackerColor('hover'),
		Normal             = Skin.TrackerColor('objective'),
		NormalHighlight    = Skin.TrackerColor('hover'),
		Complete           = Skin.TrackerColor('completed'),
		CompleteHighlight  = Skin.TrackerColor('completed'),
		TimeLeft           = Skin.TrackerColor('timeLeft'),
		TimeLeftHighlight  = Skin.TrackerColor('hover'),
	}
	for key, replacement in pairs(map) do
		local style = palette[key]
		if style then styleOverrides[style] = replacement end
	end
	return styleOverrides
end

local function PaintFromStyle(fontString, style)
	local overrides = GetStyleOverrides()
	local replacement = overrides and style and overrides[style]
	if replacement then
		fontString:SetTextColor(replacement[1], replacement[2], replacement[3], 1)
	end
end

local function IsReadyBlock(block)
	local questID = block.poiQuestID
	return questID and readyQuestIDs[questID] == true
end

local function OnSetStringText(block, fontString, _, _, colorStyle, useHighlight)
	if not IsEnabled() or not fontString or GetSettings().customColors == false then return end
	if fontString == block.HeaderText and IsReadyBlock(block) then
		fontString:SetTextColor(Skin.TrackerColorRGB(useHighlight and 'hover' or 'ready'))
		return
	end
	local palette = _G.OBJECTIVE_TRACKER_COLOR
	local effective = colorStyle or (palette and palette.Normal)
	if useHighlight and effective and effective.reverse then effective = effective.reverse end
	PaintFromStyle(fontString, effective)
end

local function OnUpdateHighlight(block)
	if not IsEnabled() or GetSettings().customColors == false then return end
	local headerText = block.HeaderText
	if headerText then
		local key = IsReadyBlock(block) and 'ready' or 'title'
		headerText:SetTextColor(Skin.TrackerColorRGB(block.isHighlighted and 'hover' or key))
	end
	if block.usedLines then
		for _, line in pairs(block.usedLines) do
			if line.Text then PaintFromStyle(line.Text, line.Text.colorStyle) end
		end
	end
end

local function ForEachTrackedBlock(callback)
	for _, trackerName in ipairs(TRACKER_NAMES) do
		local tracker = _G[trackerName]
		if tracker and tracker.usedBlocks then
			for _, blocks in pairs(tracker.usedBlocks) do
				for _, block in pairs(blocks) do callback(block) end
			end
		end
	end
end

local function RepaintSkinColors()
	ForEachTrackedBlock(OnUpdateHighlight)
end

local function RepaintBlizzardColors()
	ForEachTrackedBlock(function(block)
		local headerText = block.HeaderText
		local headerStyle = headerText and headerText.colorStyle
		if headerStyle then headerText:SetTextColor(headerStyle.r, headerStyle.g, headerStyle.b) end
		if block.usedLines then
			for _, line in pairs(block.usedLines) do
				local style = line.Text and line.Text.colorStyle
				if style then line.Text:SetTextColor(style.r, style.g, style.b) end
			end
		end
	end)
end

function Skin.ApplyTrackerColors()
	styleOverrides = nil
	Skin.ClearTrackerColorCache()
	if GetSettings().customColors == false then
		RepaintBlizzardColors()
	else
		RepaintSkinColors()
	end
end

local function EnsureQuestItemButton()
	if questItemButton then return end
	questItemButton = CreateFrame('Button', 'BUI_TrackerQuestItemButton', UIParent, 'SecureActionButtonTemplate')
	questItemButton:SetAttribute('type', 'item')
	questItemButton:RegisterForClicks('AnyDown')
	questItemButton:SetSize(1, 1)
	questItemButton:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', -50, -50)
	questItemButton:SetAlpha(0)
	questItemButton:EnableMouse(false)
end

local function UpdateQuestItemBinding()
	local key = GetSettings().questItemKey
	local wantBinding = IsEnabled() and key and key ~= 'NONE'
	if not questItemButton and not wantBinding then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(UpdateQuestItemBinding, 'Skinning.TrackerItemKey')
		return
	end
	EnsureQuestItemButton()
	ClearOverrideBindings(questItemButton)
	if not wantBinding then return end
	local getSpecialItem = C_QuestLog.GetQuestLogSpecialItemInfo or _G.GetQuestLogSpecialItemInfo
	if not getSpecialItem or not C_QuestLog.GetNumQuestWatches then return end
	local bestLink
	local bestDistance = math.huge
	for watchIndex = 1, C_QuestLog.GetNumQuestWatches() do
		local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(watchIndex)
		local logIndex = questID and C_QuestLog.GetLogIndexForQuestID(questID)
		if logIndex then
			local link = getSpecialItem(logIndex)
			if link then
				local distanceSq = C_QuestLog.GetDistanceSqToQuest and C_QuestLog.GetDistanceSqToQuest(logIndex)
				if type(distanceSq) ~= 'number' then distanceSq = math.huge - 1 end
				if distanceSq < bestDistance then
					bestDistance = distanceSq
					bestLink = link
				end
			end
		end
	end
	if bestLink then
		questItemButton:SetAttribute('item', bestLink)
		SetOverrideBindingClick(questItemButton, true, key, 'BUI_TrackerQuestItemButton')
	end
end

local function AddTomTomWaypointButton(_, rootDescription)
	if not IsEnabled() then return end
	local TomTom = _G.TomTom
	if not TomTom or not TomTom.AddWaypoint then return end
	local questID = pendingMenuQuestID
	if not questID then return end
	rootDescription:CreateButton('TomTom Waypoint', function()
		local mapID, waypointX, waypointY
		if C_QuestLog.GetNextWaypoint then
			mapID, waypointX, waypointY = C_QuestLog.GetNextWaypoint(questID)
		end
		if not mapID then
			local uiMapID = GetQuestUiMapID and GetQuestUiMapID(questID)
			if (not uiMapID or uiMapID == 0) and C_Map and C_Map.GetBestMapForUnit then
				uiMapID = C_Map.GetBestMapForUnit('player')
			end
			if uiMapID and uiMapID ~= 0 then
				if C_QuestLog.GetNextWaypointForMap then
					waypointX, waypointY = C_QuestLog.GetNextWaypointForMap(questID, uiMapID)
					if waypointX then mapID = uiMapID end
				end
				if not mapID and C_QuestLog.GetQuestsOnMap then
					local questsOnMap = C_QuestLog.GetQuestsOnMap(uiMapID)
					if questsOnMap then
						for _, questPOI in ipairs(questsOnMap) do
							if questPOI.questID == questID and questPOI.x and questPOI.y then
								mapID, waypointX, waypointY = uiMapID, questPOI.x, questPOI.y
								break
							end
						end
					end
				end
				if not mapID and C_TaskQuest and C_TaskQuest.GetQuestLocation then
					local taskX, taskY = C_TaskQuest.GetQuestLocation(questID, uiMapID)
					if taskX and taskY then
						mapID, waypointX, waypointY = uiMapID, taskX, taskY
					end
				end
			end
		end
		if not mapID or not waypointX or not waypointY then
			BUI.Print('No map location available for that quest.')
			return
		end
		local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or ('Quest ' .. questID)
		TomTom:AddWaypoint(mapID, waypointX, waypointY, { title = title, persistent = false, minimap = true, world = true })
	end)
end

local menuHookInstalled = false

local function InstallMenuHook()
	if menuHookInstalled then return end
	if not Menu or not Menu.ModifyMenu then return end
	menuHookInstalled = true
	Menu.ModifyMenu('MENU_QUEST_OBJECTIVE_TRACKER', AddTomTomWaypointButton)
end

local function SingleLineTitlesEnabled()
	return GetSettings().singleLineTitles ~= false
end

local function ApplyTitleWrap()
	local titleWrap = not (IsEnabled() and SingleLineTitlesEnabled())
	for fontString in pairs(wrapAdjustedText.titles) do
		fontString.__buiWordWrap = titleWrap
		fontString:SetWordWrap(titleWrap)
	end
	local objectiveWrap = not (IsEnabled() and GetSettings().singleLineObjectives ~= false)
	for fontString in pairs(wrapAdjustedText.objectives) do
		fontString.__buiWordWrap = objectiveWrap
		fontString:SetWordWrap(objectiveWrap)
	end
end

local function TruncateTipText(text)
	if #text > TIP_TEXT_MAX_LENGTH then
		return text:sub(1, TIP_TEXT_MAX_LENGTH) .. '...'
	end
	return text
end

local function GetQuestClassificationLabel(questID)
	if not C_QuestInfoSystem or not C_QuestInfoSystem.GetQuestClassification then return nil end
	local classificationEnum = Enum.QuestClassification
	if not classificationEnum then return nil end
	if not questClassificationLabels then
		local labelByMemberName = {
			Normal = { 'Standard', 'e8e8f0' },
			Questline = { 'Questline', '4fd0c0' },
			Campaign = { 'Campaign', 'ffd140' },
			Calling = { 'Calling', 'ffd140' },
			Important = { 'Important', 'ff6060' },
			Legendary = { 'Legendary', 'ff9b33' },
			Meta = { 'Meta', 'c07fff' },
			Recurring = { 'Recurring', '5fb0ff' },
			WorldQuest = { 'World Quest', '5fb0ff' },
			BonusObjective = { 'Bonus Objective', '5fb0ff' },
			Threat = { 'Threat', 'ff6060' },
		}
		questClassificationLabels = {}
		for memberName, entry in pairs(labelByMemberName) do
			local value = classificationEnum[memberName]
			if value then questClassificationLabels[value] = entry end
		end
	end
	local classification = C_QuestInfoSystem.GetQuestClassification(questID)
	local entry = classification and questClassificationLabels[classification]
	if not entry then return nil end
	return entry[1], entry[2]
end

local function OnQuestBlockHeaderEnter(_, block, questID, isInGroup)
	if not IsEnabled() or GetSettings().questTooltip == false then return end
	if isInGroup or not block or not questID then return end
	local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
	if not title then return end

	local rows = {}
	local logIndex = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
	local info = logIndex and C_QuestLog.GetInfo and C_QuestLog.GetInfo(logIndex)
	local metaParts = {}
	if info and info.level then
		metaParts[#metaParts + 1] = '|cffe8e8f0' .. info.level .. '|r'
	end
	local typeLabel, typeHex = GetQuestClassificationLabel(questID)
	if typeLabel then
		metaParts[#metaParts + 1] = '|cff' .. typeHex .. typeLabel .. '|r'
	end
	if info and Enum.QuestFrequency then
		if info.frequency == Enum.QuestFrequency.Daily then
			metaParts[#metaParts + 1] = '|cff5fb0ffDaily|r'
		elseif info.frequency == Enum.QuestFrequency.Weekly then
			metaParts[#metaParts + 1] = '|cff5fb0ffWeekly|r'
		end
	end
	if info and info.suggestedGroup and info.suggestedGroup > 0 then
		metaParts[#metaParts + 1] = ('Group %d'):format(info.suggestedGroup)
	end
	local uiMapID = GetQuestUiMapID and GetQuestUiMapID(questID)
	if uiMapID and uiMapID ~= 0 and C_Map and C_Map.GetMapInfo then
		local mapInfo = C_Map.GetMapInfo(uiMapID)
		if mapInfo and mapInfo.name then
			metaParts[#metaParts + 1] = '|cff7fb0ff' .. mapInfo.name .. '|r'
		end
	end
	if #metaParts > 0 then
		rows[#rows + 1] = {
			left = table.concat(metaParts, ' \194\183 '),
			right = tostring(questID),
			rightColor = Skin.TrackerColor('dim'),
		}
		rows[#rows + 1] = { space = true }
	end

	local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
	if objectives then
		for _, objective in ipairs(objectives) do
			if objective.text and objective.text ~= '' then
				local objectiveText = TruncateTipText(objective.text)
				if not objective.finished then
					objectiveText = objectiveText:gsub('^(%d+/%d+)', '|cff' .. READY_COUNT_HEX .. '%1|r')
				end
				rows[#rows + 1] = {
					left = objectiveText,
					leftColor = Skin.TrackerColor(objective.finished and 'completed' or 'objective'),
				}
			end
		end
	end
	if readyQuestIDs[questID] then
		rows[#rows + 1] = { left = '|A:UI-QuestIcon-TurnIn-Normal:14:14|a Ready to turn in', leftColor = Skin.TrackerColor('ready') }
	end
	if #rows == 0 then return end

	local blockCenterX = block.GetCenter and block:GetCenter()
	local anchorSide = (blockCenterX and blockCenterX < UIParent:GetWidth() / 2) and 'RIGHT' or 'LEFT'
	LibWidget.ShowTipRows(block, title, rows, { anchor = anchorSide })
end

local function HideQuestTip()
	LibWidget.HideTip()
end

local questTipHookInstalled = false

local function InstallQuestTipHook()
	if questTipHookInstalled then return end
	if not EventRegistry or not EventRegistry.RegisterCallback then return end
	questTipHookInstalled = true
	EventRegistry:RegisterCallback('OnQuestBlockHeader.OnEnter', OnQuestBlockHeaderEnter, wrapAdjustedText)
end

QuestFilter.sections = {
	{ module = 'ProfessionsRecipeTracker', label = 'Professions' },
	{ module = 'AchievementObjectiveTracker', label = 'Achievements' },
	{ module = 'WorldQuestObjectiveTracker', label = 'World Quests' },
	{ module = 'BonusObjectiveTracker', label = 'Bonus Objectives' },
	{ module = 'MonthlyActivitiesObjectiveTracker', label = "Traveler's Log" },
	{ module = 'InitiativeTasksObjectiveTracker', label = 'Endeavors' },
	{ module = 'AdventureObjectiveTracker', label = 'Adventures' },
}

function QuestFilter.HasActive()
	local settings = GetSettings()
	if settings.trackerTrackSpec and settings.trackerTrackSpec ~= 'all' then return true end
	local sectionFilters = settings.scrollEnabled == true and settings.trackerSectionFilters
	if sectionFilters then
		for _, section in ipairs(QuestFilter.sections) do
			if sectionFilters[section.module] == false then return true end
		end
	end
	return false
end

function QuestFilter.SectionShown(moduleName)
	if not IsEnabled() then return true end
	local sectionFilters = GetSettings().trackerSectionFilters
	return not (sectionFilters and sectionFilters[moduleName] == false)
end

function QuestFilter.Refresh()
	QuestFilter.UpdateTint()
	if scrollHolder then AdoptModules() end
end

function QuestFilter.Trackable(info)
	return not info.isHeader and not info.isTask and (not info.isBounty or C_QuestLog.IsComplete(info.questID))
end

function QuestFilter.Retrack(spec)
	if not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then return end
	GetSettings().trackerTrackSpec = spec
	QuestFilter.UpdateTint()
	local numEntries = C_QuestLog.GetNumQuestLogEntries()
	local maxWatches = Constants and Constants.QuestWatchConsts and Constants.QuestWatchConsts.MAX_QUEST_WATCHES or 25
	local superTracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID() or 0
	if not IsShiftKeyDown() then
		for entryIndex = 1, numEntries do
			local info = C_QuestLog.GetInfo(entryIndex)
			if info and QuestFilter.Trackable(info) then
				C_QuestLog.RemoveQuestWatch(info.questID)
			end
		end
	end
	local zoneName = GetRealZoneText() or ''
	local inZoneHeader = false
	for entryIndex = 1, numEntries do
		local info = C_QuestLog.GetInfo(entryIndex)
		if info and not info.isHidden then
			if info.isHeader then
				inZoneHeader = info.title == zoneName
			elseif QuestFilter.Trackable(info) then
				local wanted
				if spec == 'all' then
					wanted = true
				elseif spec == 'zone' then
					wanted = info.isOnMap or inZoneHeader
				elseif spec == 'campaign' then
					wanted = (info.campaignID or 0) ~= 0
				elseif spec == 'daily' then
					wanted = info.frequency and Enum.QuestFrequency and info.frequency >= Enum.QuestFrequency.Daily
				elseif spec == 'ready' then
					wanted = C_QuestLog.IsComplete(info.questID)
				end
				if wanted then
					if C_QuestLog.GetNumQuestWatches() >= maxWatches then break end
					C_QuestLog.AddQuestWatch(info.questID)
				end
			end
		end
	end
	C_QuestLog.SortQuestWatches()
	if superTracked > 0 and C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(superTracked) then
		C_SuperTrack.SetSuperTrackedQuestID(superTracked)
	end
	RefreshTrackerLayout()
end

function QuestFilter.Install()
	if QuestFilter.migrated then return end
	QuestFilter.migrated = true
	local settings = GetSettings()
	settings.trackerTypeFilters = nil
	settings.trackerReadyOnly = nil
	if not settings.trackerFilterRebuilt then
		settings.trackerFilterRebuilt = true
		settings.trackerSectionFilters = nil
	end
	local sectionFilters = settings.trackerSectionFilters
	if sectionFilters then
		sectionFilters.CampaignQuestObjectiveTracker = nil
		sectionFilters.QuestObjectiveTracker = nil
	end
end

function QuestFilter.UpdateTint()
	if not headerFilter then return end
	if QuestFilter.HasActive() then
		local accentRed, accentGreen, accentBlue = Theme.GetAccent()
		headerFilter.glyph:SetVertexColor(accentRed, accentGreen, accentBlue, 1)
	else
		headerFilter.glyph:SetVertexColor(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3], 1)
	end
end

function QuestFilter.ShowMenu()
	local settings = GetSettings()
	if not settings.trackerSectionFilters then settings.trackerSectionFilters = {} end
	local sectionFilters = settings.trackerSectionFilters
	local items = {}
	items[#items + 1] = { title = 'TRACK' }
	for _, preset in ipairs({
		{ spec = 'zone', label = 'Zone' },
		{ spec = 'campaign', label = 'Campaign' },
		{ spec = 'daily', label = 'Daily & Weekly' },
		{ spec = 'ready', label = 'Completed' },
		{ spec = 'all', label = 'All Quests' },
	}) do
		local spec = preset.spec
		items[#items + 1] = {
			text = preset.label,
			checked = settings.trackerTrackSpec == spec,
			callback = function(item)
				QuestFilter.Retrack(spec)
				item.checked = true
				QuestFilter.ShowMenu()
				return true
			end,
		}
	end
	if settings.scrollEnabled == true then
		items[#items + 1] = { separator = true }
		items[#items + 1] = { title = 'SECTIONS' }
		for _, section in ipairs(QuestFilter.sections) do
			local module = _G[section.module]
			local blockCount = 0
			if module and module.usedBlocks then
				for _, blocks in pairs(module.usedBlocks) do
					for _ in pairs(blocks) do blockCount = blockCount + 1 end
				end
			end
			items[#items + 1] = {
				text = section.label,
				sub = tostring(blockCount),
				checked = sectionFilters[section.module] ~= false,
				callback = function(item)
					local nowShown = sectionFilters[section.module] == false
					if nowShown then
						sectionFilters[section.module] = nil
					else
						sectionFilters[section.module] = false
					end
					item.checked = nowShown
					QuestFilter.Refresh()
					return true
				end,
			}
		end
	end
	Controls.ContextMenu(items, { width = 180, anchor = headerFilter, point = 'TOPRIGHT', relPt = 'BOTTOMRIGHT', offsetY = -4 })
end

local function UpdateHeaderCounts()
	if not headerCounts then return end
	if watchedCount == 0 then
		headerCounts:SetText('')
		return
	end
	local text = watchedCount .. ' tracked'
	if readyCount > 0 then
		text = ('%s |cff%s\194\183 %d ready|r'):format(text, READY_COUNT_HEX, readyCount)
	end
	headerCounts:SetText(text)
end

local function RefreshQuestCache()
	if not IsEnabled() then return end
	if not C_QuestLog.GetNumQuestWatches or not C_QuestLog.GetQuestIDForQuestWatchIndex then return end
	local newReadyByQuest = {}
	local chime = false
	local readyChanged = false
	watchedQuestCache = {}
	readyQuestIDs = {}
	watchedCount = 0
	readyCount = 0
	for watchIndex = 1, C_QuestLog.GetNumQuestWatches() do
		local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(watchIndex)
		if questID then
			watchedCount = watchedCount + 1
			local ready = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) or false
			if ready then
				readyCount = readyCount + 1
				readyQuestIDs[questID] = true
				if previousReadyByQuest[questID] == false then chime = true end
			end
			if previousReadyByQuest[questID] ~= ready then readyChanged = true end
			newReadyByQuest[questID] = ready
			watchedQuestCache[#watchedQuestCache + 1] = { questID = questID, ready = ready }
		end
	end
	previousReadyByQuest = newReadyByQuest
	UpdateHeaderCounts()
	if readyChanged then RepaintSkinColors() end
	UpdateQuestItemBinding()
	if chime then BUI.PlaySoundByName(GetSettings().completionSound) end
end

local queueQuestCacheRefresh = BUI.Dispatcher.NewDelayed(RefreshQuestCache, 0.3)

local function ScrollBlockIntoView(block)
	if not scrollHolder or not scrollHolder:IsShown() then return end
	if GetSettings().trackerCollapsed == true then return end
	local holderTop, holderBottom = scrollHolder:GetTop(), scrollHolder:GetBottom()
	local blockTop, blockBottom = block:GetTop(), block:GetBottom()
	if not holderTop or not holderBottom or not blockTop or not blockBottom then return end
	local pad = Pixel.Scale(12)
	if blockTop > holderTop then
		scrollTarget = math.max(0, scrollOffset - (blockTop - holderTop) - pad)
		StartScrollGlide()
	elseif blockBottom < holderBottom then
		scrollTarget = scrollOffset + (holderBottom - blockBottom) + pad
		StartScrollGlide()
	end
end

local flashQuestID

local function GetFlashColor()
	local accentRed, accentGreen, accentBlue = Theme.GetAccent()
	return (accentRed + 1) / 2, (accentGreen + 1) / 2, (accentBlue + 1) / 2
end

local function FlashProgressBlock()
	local questID = flashQuestID
	flashQuestID = nil
	if not questID or not IsEnabled() then return end
	local targetBlock
	ForEachTrackedBlock(function(block)
		if block.poiQuestID == questID then targetBlock = block end
	end)
	if not targetBlock then return end
	ScrollBlockIntoView(targetBlock)
	if not targetBlock.usedLines then return end
	local flashRed, flashGreen, flashBlue = GetFlashColor()
	for _, line in pairs(targetBlock.usedLines) do
		if line.Text then line.Text:SetTextColor(flashRed, flashGreen, flashBlue, 1) end
	end
	C_Timer.After(FLASH_SECONDS, function()
		if IsEnabled() then OnUpdateHighlight(targetBlock) end
	end)
end

local queueProgressFlash = BUI.Dispatcher.NewDelayed(FlashProgressBlock, 0.15)

local function OnQuestProgress(_, questID)
	if not IsEnabled() or not questID then return end
	flashQuestID = questID
	queueProgressFlash()
end

local dashFontStrings = {}

local function DashesVisible()
	return not IsEnabled() or GetSettings().showDashes == true
end

local function ApplyDashAlpha()
	local visible = DashesVisible()
	for dash in pairs(dashFontStrings) do
		dash:SetAlpha(visible and 1 or 0)
	end
end

local function SetPoiButtonVisible(button, visible)
	button:SetAlpha(visible and 1 or 0)
	if button.EnableMouse then button:EnableMouse(visible) end
end

local function ApplyPoiVisibility()
	local visible = not IsEnabled() or GetSettings().showQuestIcons == true
	for button in pairs(hiddenPoiButtons) do
		SetPoiButtonVisible(button, visible)
	end
end

local function HasSavedTrackerPosition()
	local positions = BUI.GetDB().framePositions
	return positions and positions[POSITION_KEY] ~= nil
end

local function ApplyTrackerPosition()
	if not IsEnabled() or reasserting then return end
	if scrollHolder then
		Skin.RestorePosition(scrollHolder, POSITION_KEY)
		return
	end
	local point, relativePoint, x, y = Skin.SavedPosition(POSITION_KEY)
	if not point then return end
	local trackerFrame = _G.ObjectiveTrackerFrame
	trackerFrame:ClearAllPointsBase()
	trackerFrame:SetPointBase(point, UIParent, relativePoint, x, y)
	if point:sub(1, 3) == 'TOP' or not Skin.SaveTopPosition(trackerFrame, POSITION_KEY) then return end
	ApplyTrackerPosition()
end

function Skin.StashTracker(stashed)
	local trackerFrame = _G.ObjectiveTrackerFrame
	if stashed == (Skin.trackerStashScale ~= nil) then return end
	if stashed then
		Skin.trackerStashScale = trackerFrame:GetScale()
		trackerFrame:SetScaleBase(TRACKER_STASH_SCALE)
		trackerFrame:SetAlpha(0)
	else
		trackerFrame:SetScaleBase(Skin.trackerStashScale)
		trackerFrame:SetAlpha(1)
		Skin.trackerStashScale = nil
	end
	SyncTrackerCardShown()
	Skin.TrackerClamp()
end

function Skin.TrackerClamp()
	if scrollHolder or not trackerCard or not IsEnabled() or Skin.trackerStashScale then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(Skin.TrackerClamp, 'Skinning.TrackerClamp')
		return
	end
	local trackerFrame = _G.ObjectiveTrackerFrame
	local left, right, top, bottom = trackerCard:GetLeft(), trackerCard:GetRight(), trackerCard:GetTop(), trackerCard:GetBottom()
	local frameLeft, frameRight, frameTop, frameBottom = trackerFrame:GetLeft(), trackerFrame:GetRight(), trackerFrame:GetTop(), trackerFrame:GetBottom()
	if not IsFiniteNumber(left) or not IsFiniteNumber(bottom) or not IsFiniteNumber(frameLeft) or not IsFiniteNumber(frameBottom) then return end
	for panel in pairs(linkedPanels) do
		local panelTop, panelBottom = panel:GetTop(), panel:GetBottom()
		if panel:IsShown() and IsFiniteNumber(panelTop) and IsFiniteNumber(panelBottom) then
			top = math.max(top, panelTop)
			bottom = math.min(bottom, panelBottom)
		end
	end
	local ratio = trackerCard:GetEffectiveScale() / trackerFrame:GetEffectiveScale()
	local insetLeft, insetRight = left * ratio - frameLeft, right * ratio - frameRight
	local insetTop, insetBottom = top * ratio - frameTop, bottom * ratio - frameBottom
	local applied = trackerCard._buiClamp
	if applied and applied[1] == insetLeft and applied[2] == insetRight and applied[3] == insetTop and applied[4] == insetBottom then return end
	trackerCard._buiClamp = { insetLeft, insetRight, insetTop, insetBottom }
	trackerFrame:SetClampRectInsets(insetLeft, insetRight, insetTop, insetBottom)
	ApplyTrackerPosition()
end

local moveDriver

local function StopMoverDrag()
	if moveDriver then moveDriver:SetScript('OnUpdate', nil) end
	if scrollHolder and scrollHolder._buiDragging then
		scrollHolder._buiDragging = false
		Skin.SavePosition(scrollHolder, POSITION_KEY)
	end
end

local function StartMoverDrag()
	if not scrollHolder or not IsEnabled() or not IsControlKeyDown() then return end
	local left, top = scrollHolder:GetLeft(), scrollHolder:GetTop()
	if not IsFiniteNumber(left) or not IsFiniteNumber(top) then return end
	local scale = scrollHolder:GetEffectiveScale()
	if not scale or scale <= 0 then scale = 1 end
	local startX, startY = GetCursorPosition()
	scrollHolder._buiDragging = true
	if not moveDriver then moveDriver = CreateFrame('Frame') end
	moveDriver:SetScript('OnUpdate', function()
		if not IsMouseButtonDown('LeftButton') then
			StopMoverDrag()
			return
		end
		local cursorX, cursorY = GetCursorPosition()
		scrollHolder:ClearAllPoints()
		scrollHolder:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left + (cursorX - startX) / scale, top + (cursorY - startY) / scale)
	end)
end

local function OnMoverDragStart()
	if scrollHolder then
		StartMoverDrag()
		return
	end
	local mover = _G.ObjectiveTrackerFrame
	if not mover or not IsEnabled() or not IsControlKeyDown() then return end
	Skin.TrackerClamp()
	mover:SetMovable(true)
	mover._buiDragging = true
	mover:StartMoving()
	mover:SetUserPlaced(false)
end

local function OnMoverDragStop()
	if scrollHolder then
		StopMoverDrag()
		return
	end
	local mover = _G.ObjectiveTrackerFrame
	if not mover or not mover._buiDragging then return end
	mover:StopMovingOrSizing()
	mover._buiDragging = false
	if not Skin.SaveTopPosition(mover, POSITION_KEY) then return end
	ApplyTrackerPosition()
	BUI.LeaveFrameManager(mover, Skin.SavedPosition(POSITION_KEY))
end

local function MakeHeaderDragHandle(header)
	if header.__buiDragHandle then return end
	header.__buiDragHandle = true
	header:EnableMouse(true)
	Skin.ForwardTrackerWheel(header)
	header:RegisterForDrag('LeftButton')
	header:HookScript('OnDragStart', OnMoverDragStart)
	header:HookScript('OnDragStop', OnMoverDragStop)
end

local function WireCardDragHandles()
	if not trackerCard or trackerCard.__buiDragWired then return end
	trackerCard.__buiDragWired = true
	trackerCard:RegisterForDrag('LeftButton')
	trackerCard:SetScript('OnDragStart', OnMoverDragStart)
	trackerCard:SetScript('OnDragStop', OnMoverDragStop)
end

local appliedTrackerCollapse

local function ApplyTrackerCollapse()
	if not scrollHolder or not headerRow then return end
	local collapsed = GetSettings().trackerCollapsed == true
	if headerChevron then headerChevron:SetRotation(collapsed and 0 or math.pi) end
	local wasCollapsed = appliedTrackerCollapse
	if collapsed == wasCollapsed then return end
	appliedTrackerCollapse = collapsed
	if not collapsed then scrollHolder:SetAlpha(1) end
	UpdateCardAnchors()
	RefreshScroll()
	if wasCollapsed == true and not collapsed then RefreshTrackerLayout() end
end

function Skin.TrackerHeaderControls(parent, anchor)
	local filterButton = CreateFrame('Button', nil, parent)
	filterButton:SetSize(Pixel.PixelSize(MINIMIZE_SIZE), Pixel.PixelSize(MINIMIZE_SIZE))
	filterButton:SetPoint('RIGHT', anchor, 'LEFT', -Pixel.Scale(4), 0)
	local filterGlyph = filterButton:CreateTexture(nil, 'OVERLAY')
	filterGlyph:SetTexture(BUILib.GetLibMedia('eye'))
	filterGlyph:SetPoint('CENTER', 0, 0)
	filterGlyph:SetSize(Pixel.Scale(GLYPH_SIZE + 2), Pixel.Scale(GLYPH_SIZE + 2))
	headerFilter = filterButton
	headerFilter.glyph = filterGlyph
	filterButton:SetScript('OnEnter', function()
		filterGlyph:SetVertexColor(1, 1, 1, 1)
	end)
	filterButton:SetScript('OnLeave', function()
		QuestFilter.UpdateTint()
	end)
	filterButton:SetScript('OnClick', QuestFilter.ShowMenu)
	QuestFilter.UpdateTint()

	headerCounts = parent:CreateFontString(nil, 'ARTWORK')
	ApplySkinFont(headerCounts, 'line')
	headerCounts:SetPoint('RIGHT', filterButton, 'LEFT', -Pixel.Scale(8), 0)
	headerCounts:SetJustifyH('RIGHT')
	headerCounts:SetTextColor(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3], 1)
	UpdateHeaderCounts()
end

function Skin.TrackerDecorateHeader(trackerFrame)
	local header = trackerFrame.Header
	if not header.__buiDecorated then
		header.__buiDecorated = true
		Skin.TrackerHeaderControls(header, header.MinimizeButton)
		hooksecurefunc(trackerFrame, 'Init', Skin.TrackerDecorateHeader)
	end
	local enabled = IsEnabled()
	header.Text:SetText(enabled and 'OBJECTIVES' or trackerFrame.headerText)
	headerFilter:SetShown(enabled)
	headerCounts:SetShown(enabled)
end

local function ApplyHeaderRowVisibility()
	local show = GetSettings().showHeaderRow ~= false
	if not scrollHolder then
		local trackerFrame = _G.ObjectiveTrackerFrame
		local header = trackerFrame and trackerFrame.Header
		if header then
			header:SetShown(not IsEnabled() or show)
			Skin.TrackerDecorateHeader(trackerFrame)
		end
	end
	if not headerRow then return end
	local visible = IsEnabled() and show
	headerRow:SetShown(visible)
	if not visible and GetSettings().trackerCollapsed == true then
		GetSettings().trackerCollapsed = false
		ApplyTrackerCollapse()
	else
		UpdateCardAnchors()
		RefreshScroll()
	end
	if scrollTrack then
		local topInset = visible and (headerRow:GetHeight() + Pixel.Scale(HEADER_ROW_TOP_PAD)) or 0
		scrollTrack:SetPoint('TOPRIGHT', trackerCard, 'TOPRIGHT', -Pixel.PixelSize(2), -(Pixel.PixelSize(CARD_PAD_Y) + topInset))
	end
end

local function EnsureHeaderRow()
	if headerRow or not trackerCard or not scrollHolder then return end
	headerRow = CreateFrame('Button', nil, trackerCard)
	headerRow:SetPoint('TOPLEFT', trackerCard, 'TOPLEFT', 0, -Pixel.Scale(HEADER_ROW_TOP_PAD))
	headerRow:SetPoint('TOPRIGHT', trackerCard, 'TOPRIGHT', 0, -Pixel.Scale(HEADER_ROW_TOP_PAD))
	headerRow:SetHeight(Pixel.Scale(HEADER_ROW_HEIGHT))
	headerRow:SetFrameLevel(trackerCard:GetFrameLevel() + 2)

	local rule = headerRow:CreateTexture(nil, 'ARTWORK')
	rule:SetPoint('BOTTOMLEFT', headerRow, 'BOTTOMLEFT', 0, 0)
	rule:SetPoint('BOTTOMRIGHT', headerRow, 'BOTTOMRIGHT', 0, 0)
	rule:SetHeight(Pixel.PixelSize(1))
	Skin.trackerRules[rule] = true
	rule:SetColorTexture(Skin.TrackerSeparatorColor())

	local label = headerRow:CreateFontString(nil, 'ARTWORK')
	ApplySkinFont(label, 'header')
	label:SetPoint('LEFT', headerRow, 'LEFT', Pixel.Scale(HEADER_TEXT_INSET), 0)
	label:SetText('OBJECTIVES')
	label:SetTextColor(Theme.text.label[1], Theme.text.label[2], Theme.text.label[3], 1)

	local toggle = CreateFrame('Button', nil, headerRow)
	toggle:SetSize(Pixel.PixelSize(MINIMIZE_SIZE), Pixel.PixelSize(MINIMIZE_SIZE))
	toggle:SetPoint('RIGHT', headerRow, 'RIGHT', -Pixel.Scale(8), 0)
	headerChevron = toggle:CreateTexture(nil, 'OVERLAY')
	headerChevron:SetTexture(BUILib.GetLibMedia('dropdown'))
	headerChevron:SetPoint('CENTER', 0, 0)
	headerChevron:SetSize(Pixel.Scale(GLYPH_SIZE), Pixel.Scale(GLYPH_SIZE))
	headerChevron:SetVertexColor(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3], 1)
	toggle:SetScript('OnEnter', function()
		headerChevron:SetVertexColor(1, 1, 1, 1)
	end)
	toggle:SetScript('OnLeave', function()
		headerChevron:SetVertexColor(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3], 1)
	end)
	toggle:SetScript('OnClick', function()
		local settings = GetSettings()
		settings.trackerCollapsed = not (settings.trackerCollapsed == true)
		ApplyTrackerCollapse()
	end)

	Skin.TrackerHeaderControls(headerRow, toggle)

	headerRow:SetScript('OnEnter', function(self)
		if GetSettings().trackerCollapsed ~= true then return end
		if #watchedQuestCache == 0 then return end
		local rows = {}
		for questIndex, entry in ipairs(watchedQuestCache) do
			if questIndex > PEEK_MAX_ROWS then
				rows[#rows + 1] = { left = ('+%d more'):format(#watchedQuestCache - PEEK_MAX_ROWS) }
				break
			end
			local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(entry.questID)
			local done, total = 0, 0
			local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(entry.questID)
			if objectives then
				for _, objective in ipairs(objectives) do
					total = total + 1
					if objective.finished then done = done + 1 end
				end
			end
			rows[#rows + 1] = {
				left = title or ('Quest ' .. entry.questID),
				leftColor = Skin.TrackerColor(entry.ready and 'ready' or 'title'),
				right = entry.ready and 'Ready' or (total > 0 and (done .. '/' .. total) or ''),
				rightColor = entry.ready and Skin.TrackerColor('ready') or nil,
			}
		end
		LibWidget.ShowTipRows(self, 'Objectives', rows)
	end)
	headerRow:SetScript('OnLeave', function()
		LibWidget.HideTip()
	end)

	headerRow:RegisterForDrag('LeftButton')
	headerRow:SetScript('OnDragStart', OnMoverDragStart)
	headerRow:SetScript('OnDragStop', OnMoverDragStop)

	if scrollTrack then
		scrollTrack:SetPoint('TOPRIGHT', trackerCard, 'TOPRIGHT', -Pixel.PixelSize(2), -(Pixel.PixelSize(CARD_PAD_Y) + headerRow:GetHeight() + Pixel.Scale(HEADER_ROW_TOP_PAD)))
	end
end

local trackerMoveInstalled = false

local function InstallTrackerMove()
	if trackerMoveInstalled then return end
	local trackerFrame = _G.ObjectiveTrackerFrame
	if not trackerFrame then return end
	trackerMoveInstalled = true
	hooksecurefunc(trackerFrame, 'SetPoint', function(self, pointArg, relativeArg)
		if self.isDragging then
			local relativeName = relativeArg
			if type(relativeArg) == 'table' then
				relativeName = (relativeArg.GetName and relativeArg:GetName()) or 'unnamed frame'
			end
			LogTrackerEvent(('setpoint during drag %s %s'):format(tostring(pointArg), tostring(relativeName)))
		end
		if reasserting or self._buiDragging then return end
		local editModeActive = IsEditModeActive()
		if scrollHolder then
			if editModeActive then
				local positions = BUI.GetDB().framePositions
				if positions then positions[POSITION_KEY] = nil end
			elseif HasSavedTrackerPosition() then
				return
			end
			local right, top = self:GetRight(), self:GetTop()
			if not IsFiniteNumber(right) or not IsFiniteNumber(top) then return end
			scrollHolder:ClearAllPoints()
			scrollHolder:SetPoint('TOPRIGHT', UIParent, 'BOTTOMLEFT', right + Pixel.Scale(RIGHT_CLIP_PAD), top)
			return
		end
		if editModeActive then
			local positions = BUI.GetDB().framePositions
			if positions then positions[POSITION_KEY] = nil end
			return
		end
		ApplyTrackerPosition()
	end)
	hooksecurefunc(trackerFrame, 'UpdateClampOffsets', Skin.TrackerClamp)
	ApplyTrackerPosition()
end

local function ApplyTextSettings()
	local font = GetSkinFont()
	local flags = GetSkinFontFlags()
	for fontString, entry in pairs(restoreFonts) do
		Pixel.ApplyFont(fontString, GetRoleSize(entry.role), font, flags)
	end
	ApplyCardStyle()
	if IsEnabled() then RefreshTrackerLayout() end
end

local function Track(element)
	if element then addedElements[#addedElements + 1] = element end
	return element
end

local function SetCollapsedGlyph(header, collapsed)
	local button = header and header.MinimizeButton
	local chevron = button and button.__buiChevron
	if chevron then chevron:SetRotation(collapsed and 0 or math.pi) end
end

local function ReassertHidden(texture)
	if texture.__buiReasserting then return end
	if texture.__buiHidden and IsEnabled() then
		texture.__buiReasserting = true
		texture:SetTexture(nil)
		texture:SetAlpha(0)
		texture.__buiReasserting = nil
	end
end

local function HideBlizzardTexture(texture)
	if not texture or texture.__buiHidden then return end
	texture.__buiHidden = true
	texture.__buiOldAlpha = texture:GetAlpha()
	texture.__buiOldAtlas = texture.GetAtlas and texture:GetAtlas() or nil
	if not texture.__buiOldAtlas then texture.__buiOldTexture = texture:GetTexture() end
	hiddenTextures[#hiddenTextures + 1] = texture

	texture:SetTexture(nil)
	texture:SetAlpha(0)
	hooksecurefunc(texture, 'SetAtlas', ReassertHidden)
	hooksecurefunc(texture, 'SetTexture', ReassertHidden)
	hooksecurefunc(texture, 'SetShown', ReassertHidden)
	hooksecurefunc(texture, 'Show', ReassertHidden)
	hooksecurefunc(texture, 'SetAlpha', ReassertHidden)
end

local function HideFrameTextures(frame)
	if not frame or not frame.GetRegions then return end
	for regionIndex = 1, select('#', frame:GetRegions()) do
		local region = select(regionIndex, frame:GetRegions())
		if region and region.IsObjectType and region:IsObjectType('Texture') then
			HideBlizzardTexture(region)
		end
	end
end

local function ClearButtonTextures(button, getters)
	for _, getter in ipairs(getters) do
		HideBlizzardTexture(button[getter] and button[getter](button))
	end
end

local function SkinMinimizeButton(header)
	local button = header.MinimizeButton
	if not button or button.__buiSkinned then return end
	button.__buiSkinned = true

	ClearButtonTextures(button, { 'GetNormalTexture', 'GetPushedTexture', 'GetDisabledTexture', 'GetHighlightTexture' })
	HideFrameTextures(button)
	button:SetSize(Pixel.PixelSize(MINIMIZE_SIZE), Pixel.PixelSize(MINIMIZE_SIZE))

	local chevron = Track(button:CreateTexture(nil, 'OVERLAY'))
	chevron:SetTexture(BUILib.GetLibMedia('dropdown'))
	chevron:SetPoint('CENTER', 0, 0)
	chevron:SetSize(Pixel.Scale(GLYPH_SIZE), Pixel.Scale(GLYPH_SIZE))
	button.__buiChevron = chevron

	local function PaintGlyph(red, green, blue)
		chevron:SetVertexColor(red, green, blue, 1)
	end
	PaintGlyph(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3])

	button:HookScript('OnEnter', function()
		if IsEnabled() then PaintGlyph(1, 1, 1) end
	end)
	button:HookScript('OnLeave', function()
		PaintGlyph(Theme.text.muted[1], Theme.text.muted[2], Theme.text.muted[3])
	end)

	SetCollapsedGlyph(header, header.isCollapsed)
	if header.SetCollapsed then hooksecurefunc(header, 'SetCollapsed', SetCollapsedGlyph) end
end

local function SkinHeader(header)
	if not header or header.__buiSkinned then return end
	header.__buiSkinned = true

	local entry = {}
	restoreHeaders[header] = entry

	HideFrameTextures(header)
	HideBlizzardTexture(header.Background)

	local headerTextInset = -Pixel.Scale(HEADER_TEXT_INSET)

	local rule = Track(header:CreateTexture(nil, 'ARTWORK'))
	rule:SetPoint('BOTTOMLEFT', header, 'BOTTOMLEFT', headerTextInset, 0)
	rule:SetPoint('BOTTOMRIGHT', header, 'BOTTOMRIGHT', 0, 0)
	rule:SetHeight(Pixel.PixelSize(1))
	Skin.trackerRules[rule] = true
	rule:SetColorTexture(Skin.TrackerSeparatorColor())

	local text = header.Text
	if text then
		entry.red, entry.green, entry.blue, entry.alpha = text:GetTextColor()

		ApplySkinFont(text, 'header')
		text:ClearAllPoints()
		text:SetPoint('LEFT', header, 'LEFT', headerTextInset, 0)
		text:SetTextColor(Theme.text.label[1], Theme.text.label[2], Theme.text.label[3], 1)
	end

	MakeHeaderDragHandle(header)
	SkinMinimizeButton(header)
end

local function CropIcon(icon)
	if icon.GetAtlas and icon:GetAtlas() then return end
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function SkinBar(bar)
	if not bar or bar.__buiSkinned then return end
	bar.__buiSkinned = true

	Skin3.StripTextures(bar)
	bar:SetStatusBarTexture(FLAT_TEXTURE)
	bar:SetStatusBarColor(Theme.GetAccent())
	Theme.RegisterAccentElement(bar, function(element, red, green, blue)
		element:SetStatusBarColor(red, green, blue, 1)
	end)
	local backdrop = Skin3.ChildBackdrop(bar, { bg = Theme.bg.dark, border = Theme.border.default })
	skinnedBars[bar] = backdrop
	bar:HookScript('OnShow', function(self)
		backdrop:SetShown(IsEnabled() and self:IsShown())
	end)
	backdrop:SetShown(IsEnabled() and bar:IsShown())

	local label = bar.Label
	if label then
		Pixel.ApplyFont(label, BAR_LABEL_SIZE, FONT, 'OUTLINE')
		label:ClearAllPoints()
		label:SetPoint('CENTER', bar, 'CENTER', 0, 0)
	end

	local icon = bar.Icon
	if icon then
		if icon.SetMask then icon:SetMask('') end
		CropIcon(icon)
		icon:SetSize(Pixel.Scale(BAR_ICON_SIZE), Pixel.Scale(BAR_ICON_SIZE))
		icon:ClearAllPoints()
		icon:SetPoint('LEFT', bar, 'RIGHT', Pixel.Scale(6), 0)
	end
end

local function SkinStageBlock()
	local scenarioTracker = _G.ScenarioObjectiveTracker
	local stageBlock = scenarioTracker and scenarioTracker.StageBlock
	if not stageBlock or stageBlock.__buiSkinned then return end
	stageBlock.__buiSkinned = true

	HideBlizzardTexture(stageBlock.NormalBG)
	HideBlizzardTexture(stageBlock.ThemeOverlay)
	HideBlizzardTexture(stageBlock.FinalBG)
	HideBlizzardTexture(stageBlock.GlowTexture)

	skinnedBars[stageBlock] = Skin3.ChildBackdrop(stageBlock, { bg = Theme.bg.light, border = Theme.border.light })
	stageBlock:HookScript('OnShow', Scenario.SyncStageBackdrop)
	hooksecurefunc(stageBlock, 'UpdateWidgetRegistration', Scenario.SyncStageBackdrop)
	Scenario.SyncStageBackdrop(stageBlock)

	ApplySkinFont(stageBlock.Stage, 'header')
	ApplySkinFont(stageBlock.Name, 'title')
	ApplySkinFont(stageBlock.CompleteLabel, 'header')
	if stageBlock.Stage then
		stageBlock.Stage:SetTextColor(Skin.TrackerColorRGB('title'))
	end
	if stageBlock.Name then
		stageBlock.Name:SetTextColor(Skin.TrackerColorRGB('title'))
	end
end

local function SkinItemButton(button)
	if not button or button.__buiSkinned then return end
	button.__buiSkinned = true

	ClearButtonTextures(button, { 'GetNormalTexture', 'GetPushedTexture' })

	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if highlight then
		highlight:SetAtlas(nil)
		highlight:SetColorTexture(1, 1, 1, 0.22)
	end

	local icon = button.icon or button.Icon or button.IconTexture
	if icon then
		CropIcon(icon)
		icon:ClearAllPoints()
		icon:SetAllPoints(button)
	end

	Pixel.ApplyBorder(button, 1, Theme.border.light[1], Theme.border.light[2], Theme.border.light[3], 1)

	local glow = button.Glow
	if glow then
		local outset = Pixel.PixelSize(2)
		glow:SetAtlas(nil)
		glow:SetColorTexture(Theme.GetAccent())
		glow:ClearAllPoints()
		glow:SetPoint('TOPLEFT', button, 'TOPLEFT', -outset, outset)
		glow:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', outset, -outset)
		Theme.RegisterAccentElement(glow, function(element, red, green, blue)
			element:SetColorTexture(red, green, blue, 1)
		end)
	end

	local count = button.Count or button.count
	if count then Pixel.ApplyFont(count, BAR_LABEL_SIZE, FONT, 'OUTLINE') end
end

local function ApplyCheckTexture(check)
	if check.__buiApplyingCheck then return end
	check.__buiApplyingCheck = true
	check:SetTexture(BUILib.GetLibMedia('check'))
	check:SetVertexColor(Theme.GetAccent())
	check.__buiApplyingCheck = nil
end

local function SkinCheck(check)
	if not check or check.__buiSkinned then return end
	check.__buiSkinned = true
	ApplyCheckTexture(check)
	hooksecurefunc(check, 'SetAtlas', ApplyCheckTexture)
	hooksecurefunc(check, 'SetTexture', ApplyCheckTexture)
	Theme.RegisterAccentElement(check, function(element, red, green, blue)
		element:SetVertexColor(red, green, blue, 1)
	end)
end

local function SkinLine(line)
	SkinCheck(line.Check)
	ApplySkinFont(line.Text, 'line')
	local lineText = line.Text
	if lineText then
		wrapAdjustedText.objectives[lineText] = true
		local wantWrap = GetSettings().singleLineObjectives == false
		if lineText.__buiWordWrap ~= wantWrap then
			lineText.__buiWordWrap = wantWrap
			lineText:SetWordWrap(wantWrap)
		end
	end
	local dash = line.Dash
	if dash and not dashFontStrings[dash] then
		dashFontStrings[dash] = true
		dash:SetAlpha(DashesVisible() and 1 or 0)
	end
end

local function OnAddBlock(_, block)
	if not IsEnabled() or not block then return end
	SkinItemButton(block.ItemButton or block.itemButton)
	if block.addedRegions and not InCombatLockdown() then
		local raisedLevel = (block.GetFrameLevel and block:GetFrameLevel() or 0) + 5
		for region in pairs(block.addedRegions) do
			if region.SetFrameLevel and region:GetFrameLevel() ~= raisedLevel then region:SetFrameLevel(raisedLevel) end
		end
	end
	HideBlizzardTexture(block.HeaderGlow)
	ApplySkinFont(block.HeaderText, 'title')
	local blockHeaderText = block.HeaderText
	if blockHeaderText then
		wrapAdjustedText.titles[blockHeaderText] = true
		local wantWrap = not SingleLineTitlesEnabled()
		if blockHeaderText.__buiWordWrap ~= wantWrap then
			blockHeaderText.__buiWordWrap = wantWrap
			blockHeaderText:SetWordWrap(wantWrap)
		end
	end
	local currentLine = block.currentLine
	if currentLine then SkinLine(currentLine) end
	if block.usedLines then
		for _, line in pairs(block.usedLines) do
			SkinLine(line)
		end
	end
	local poiButton = block.poiButton
	if poiButton and not hiddenPoiButtons[poiButton] then
		hiddenPoiButtons[poiButton] = true
		poiButton:SetScale(POI_BUTTON_SCALE)
		SetPoiButtonVisible(poiButton, GetSettings().showQuestIcons == true)
	end
	if not block.__buiPoiAnchorHook and block.AddPOIButton then
		block.__buiPoiAnchorHook = true
		hooksecurefunc(block, 'AddPOIButton', function(self)
			if not IsEnabled() then return end
			local button = self.poiButton
			if button and self.HeaderText then
				button:ClearAllPoints()
				button:SetPoint('RIGHT', self.HeaderText, 'LEFT', POI_ANCHOR_OFFSET_X, 0)
			end
		end)
	end
	if not block.__buiMenuHook then
		block.__buiMenuHook = true
		block:HookScript('OnMouseDown', function(self)
			pendingMenuQuestID = self.poiQuestID or self.id
		end)
	end
	if not block.__buiColorHook then
		block.__buiColorHook = true
		if block.SetStringText then hooksecurefunc(block, 'SetStringText', OnSetStringText) end
		if block.UpdateHighlight then hooksecurefunc(block, 'UpdateHighlight', OnUpdateHighlight) end
	end
	Skin.ForwardTrackerWheel(block)
	OnUpdateHighlight(block)
end

local function OnGetProgressBar(tracker, key)
	if not IsEnabled() then return end
	local progressBar = tracker.usedProgressBars and tracker.usedProgressBars[key]
	if progressBar then SkinBar(progressBar.Bar) end
end

local function OnGetTimerBar(tracker, key)
	if not IsEnabled() then return end
	local timerBar = tracker.usedTimerBars and tracker.usedTimerBars[key]
	if timerBar then SkinBar(timerBar.Bar) end
end

local hookedTrackers = {}

local challengeModeHidden = false

local function IsChallengeModeRunning()
	if not C_ChallengeMode then return false end
	if C_ChallengeMode.IsChallengeModeActive then return C_ChallengeMode.IsChallengeModeActive() end
	if C_ChallengeMode.GetActiveChallengeMapID then return C_ChallengeMode.GetActiveChallengeMapID() ~= nil end
	return false
end

local function ApplyChallengeModeVisibility()
	local shouldHide = IsEnabled() and (IsChallengeModeRunning() or GetSettings().trackerHidden == true) or false
	if shouldHide == (challengeModeHidden or false) then return end
	if InCombatLockdown() then
		BUI.Events:AfterCombat(ApplyChallengeModeVisibility, 'Skinning.TrackerChallengeMode')
		return
	end
	challengeModeHidden = shouldHide
	if scrollHolder then
		scrollHolder:SetShown(not shouldHide)
		return
	end
	Skin.StashTracker(shouldHide)
end

Scenario.headers = {}
Scenario.headerMixins = { 'UIWidgetTemplateScenarioHeaderDelvesMixin', 'UIWidgetTemplateScenarioHeaderTimerMixin', 'UIWidgetTemplateScenarioHeaderCurrenciesAndBackgroundMixin' }
Scenario.headerOverhangKeys = { 'SpellContainer', 'CurrencyContainer', 'RewardFrame' }
Scenario.headerBackdropInset = 1
Scenario.headerBackdropPad = 4

Scenario.FitHeaderBackdrop = function(widget, backdrop)
	local bottom = widget:GetBottom()
	if not bottom then return false end
	local keys, lowest = Scenario.headerOverhangKeys, bottom
	for keyIndex = 1, #keys do
		local child = widget[keys[keyIndex]]
		if child and child:IsShown() then
			local childBottom = child:GetBottom()
			if childBottom and childBottom < lowest then lowest = childBottom end
		end
	end
	local inset = Scenario.headerBackdropInset
	local drop = bottom - lowest
	if drop > 0 then drop = drop + Scenario.headerBackdropPad end
	if backdrop._buiHeaderDrop == drop then return true end
	backdrop._buiHeaderDrop = drop
	backdrop:ClearAllPoints()
	backdrop:SetPoint('TOPLEFT', widget, 'TOPLEFT', inset, -inset)
	backdrop:SetPoint('BOTTOMRIGHT', widget, 'BOTTOMRIGHT', -inset, inset - drop)
	return true
end

Scenario.ApplyHeader = function(widget)
	Scenario.headers[widget] = true
	local enabled = IsEnabled()
	local alpha = enabled and 0 or 1
	widget.Frame:SetAlpha(alpha)
	widget.ThemeOverlay:SetAlpha(alpha)
	widget.DecorationBottomLeft:SetAlpha(alpha)
	local backdrop = skinnedBars[widget]
	if enabled then
		if not backdrop then
			backdrop = Skin3.ChildBackdrop(widget, { bg = Theme.bg.light, border = Theme.border.light })
			skinnedBars[widget] = backdrop
		end
		if not Scenario.FitHeaderBackdrop(widget, backdrop) then
			C_Timer.After(0, function() Scenario.FitHeaderBackdrop(widget, backdrop) end)
		end
		ApplySkinFont(widget.HeaderText, 'title')
		widget.HeaderText:SetTextColor(Skin.TrackerColorRGB('title'))
		local timerBar = widget.TimerBar
		if timerBar then
			SkinBar(timerBar)
			timerBar:SetStatusBarTexture(FLAT_TEXTURE)
			timerBar:SetStatusBarColor(Theme.GetAccent())
			ApplySkinFont(widget.Timer.Text, 'timer')
		end
	end
	if backdrop then backdrop:SetShown(enabled and widget:IsShown()) end
end

Scenario.TrackHeader = function(widget)
	if Scenario.headers[widget] or not widget.Frame or not widget.HeaderText then return end
	hooksecurefunc(widget, 'Setup', Scenario.ApplyHeader)
	Scenario.ApplyHeader(widget)
end

Scenario.ScanHeaders = function()
	local scenarioTracker = _G.ScenarioObjectiveTracker
	local container = scenarioTracker and scenarioTracker.StageBlock and scenarioTracker.StageBlock.WidgetContainer
	local frames = container and container.widgetFrames
	if type(frames) ~= 'table' then return end
	for _, widget in pairs(frames) do Scenario.TrackHeader(widget) end
end

Scenario.InstallHeaderHooks = function()
	if Scenario.headerHooked then return end
	Scenario.headerHooked = true
	for _, mixinName in ipairs(Scenario.headerMixins) do
		local mixin = _G[mixinName]
		if mixin then hooksecurefunc(mixin, 'Setup', Scenario.ApplyHeader) end
	end
end

Scenario.SyncStageBackdrop = function(stageBlock)
	local backdrop = skinnedBars[stageBlock]
	if backdrop then backdrop:SetShown(IsEnabled() and stageBlock:IsShown() and not stageBlock.widgetSetID) end
end

function Scenario.Install()
	Scenario.ScanHeaders()
	Scenario.InstallHeaderHooks()
end

function Scenario.Remove()
	for widget in pairs(Scenario.headers) do Scenario.ApplyHeader(widget) end
end

local function Install()
	if not IsEnabled() then return end
	Scenario.Install()
	InstallMenuHook()
	InstallQuestTipHook()
	Skin.TrackerEditModeHooks()
	QuestFilter.Install()

	local trackerFrame = _G.ObjectiveTrackerFrame
	if trackerFrame then
		if trackerFrame.Header then SkinHeader(trackerFrame.Header) end
		if trackerFrame.NineSlice then HideFrameTextures(trackerFrame.NineSlice) end
		EnsureScrollHolder()
		ApplyTrackerWidth()
		InstallTrackerMove()
		Skin.TrackerRepairEditModeAnchor()
	end

	for _, trackerName in ipairs(TRACKER_NAMES) do
		local tracker = _G[trackerName]
		if tracker then
			if tracker.Header then SkinHeader(tracker.Header) end
			if not hookedTrackers[tracker] then
				hookedTrackers[tracker] = true
				if tracker.AddBlock then hooksecurefunc(tracker, 'AddBlock', OnAddBlock) end
				if tracker.GetProgressBar then hooksecurefunc(tracker, 'GetProgressBar', OnGetProgressBar) end
				if tracker.GetTimerBar then hooksecurefunc(tracker, 'GetTimerBar', OnGetTimerBar) end
				if tracker.OnBlockHeaderLeave then hooksecurefunc(tracker, 'OnBlockHeaderLeave', HideQuestTip) end
			end
		end
	end

	SkinStageBlock()
	EnsureTrackerCard()
	WireCardDragHandles()
	EnsureHeaderRow()
	ApplyTrackerCollapse()
	ApplyHeaderRowVisibility()
	ApplyEditModeHeight()

	BUI.Events:Register('CHALLENGE_MODE_START', 'Skinning.TrackerChallengeMode', ApplyChallengeModeVisibility)
	BUI.Events:Register('CHALLENGE_MODE_COMPLETED', 'Skinning.TrackerChallengeMode', ApplyChallengeModeVisibility)
	BUI.Events:Register('CHALLENGE_MODE_RESET', 'Skinning.TrackerChallengeMode', ApplyChallengeModeVisibility)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Skinning.TrackerChallengeMode', ApplyChallengeModeVisibility)
	ApplyChallengeModeVisibility()

	BUI.Events:Register('QUEST_LOG_UPDATE', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('QUEST_WATCH_LIST_CHANGED', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('QUEST_ACCEPTED', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('QUEST_REMOVED', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('QUEST_TURNED_IN', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('PLAYER_ENTERING_WORLD', 'Skinning.TrackerQuestCache', queueQuestCacheRefresh)
	BUI.Events:Register('QUEST_WATCH_UPDATE', 'Skinning.TrackerProgress', OnQuestProgress)
	BUI.Events:Register('ZONE_CHANGED_NEW_AREA', 'Skinning.TrackerItemKey', UpdateQuestItemBinding)
	queueQuestCacheRefresh()
end

BUI.Events:OnLogin('Skinning.ObjectiveTracker', Install)

Skin.OnToggle('objectivetracker', function(enabled)
	Skin.ClearTrackerColorCache()
	if enabled then
		Install()
		for _, element in ipairs(addedElements) do element:Show() end
		for bar, backdrop in pairs(skinnedBars) do backdrop:SetShown(bar:IsShown()) end
		Scenario.SyncStageBackdrop(_G.ScenarioObjectiveTracker.StageBlock)
		for button in pairs(hiddenPoiButtons) do button:SetScale(POI_BUTTON_SCALE) end
		ApplyPoiVisibility()
		ApplyDashAlpha()
		ApplyTitleWrap()
		Skin.ApplyTrackerSeparators()
		ApplyTrackerPosition()
		ApplyTextSettings()
		Skin.ApplyTrackerColors()
		queueQuestCacheRefresh()
		UpdateQuestItemBinding()
		if scrollHolder then
			scrollHolder:SetShown(not challengeModeHidden)
			AdoptModules()
		end
		RefreshScroll()
		for _, texture in ipairs(hiddenTextures) do ReassertHidden(texture) end
		return
	end

	for _, element in ipairs(addedElements) do element:Hide() end
	for _, backdrop in pairs(skinnedBars) do backdrop:Hide() end
	if trackerCard then trackerCard:Hide() end
	if scrollHolder then
		scrollOffset = 0
		scrollHolder:SetVerticalScroll(0)
		ReleaseModules()
		scrollHolder:Hide()
		for _, trackerName in ipairs(TRACKER_NAMES) do
			local module = _G[trackerName]
			if module then module:SetWidth(260) end
		end
	end
	for button in pairs(hiddenPoiButtons) do
		button:SetScale(1)
		button:ClearAllPoints()
	end
	ApplyTitleWrap()
	ApplyHeaderRowVisibility()
	HideQuestTip()
	Scenario.Remove()
	if trackerCard then trackerCard._buiClamp = nil end
	_G.ObjectiveTrackerFrame:UpdateClampOffsets()
	UpdateQuestItemBinding()
	ApplyPoiVisibility()
	ApplyDashAlpha()
	ApplyChallengeModeVisibility()
	RepaintBlizzardColors()
	for _, texture in ipairs(hiddenTextures) do
		if texture.__buiOldAtlas then
			texture:SetAtlas(texture.__buiOldAtlas)
		elseif texture.__buiOldTexture then
			texture:SetTexture(texture.__buiOldTexture)
		end
		texture:SetAlpha(texture.__buiOldAlpha or 1)
	end
	for fontString, entry in pairs(restoreFonts) do
		if entry.font then fontString:SetFont(entry.font, entry.size, entry.flags) end
	end
	for header, entry in pairs(restoreHeaders) do
		local text = header.Text
		if text and entry.red then
			text:SetTextColor(entry.red, entry.green, entry.blue, entry.alpha)
		end
	end
end)

Skin.RegisterSkin('objectivetracker', {
	name = 'Objective Tracker',
	description = 'Tooltip-style dark cards behind each tracker section, clean library fonts on quest text, accent-marked headers, flat progress bars, and square quest item icons. An OBJECTIVES title row carries quest counts and filters, and optional scrolling mode caps the height with a scroll bar. Hides itself during Mythic+ runs. Hold Ctrl and drag any section header to move the tracker.',
	icon = 'Interface\\Icons\\INV_Misc_Book_07',
	settingsWidth = 430,
	settingsHeight = 1200,
	buildSettings = function(content)
		local settings = GetSettings()
		local pageKit = PageKit
		local GAP = pageKit.GAP
		local width = content.width

		local textHeight = pageKit.CardHeight(3)
		local colorsHeight = pageKit.CardHeight(7)
		local panelHeight = pageKit.CardHeight(11)
		local positionHeight = pageKit.CardHeight(1)

		local root = CreateFrame('Frame', nil, content.child)
		root:SetPoint('TOPLEFT', 0, -8)
		root:SetSize(width, textHeight + GAP + colorsHeight + GAP + panelHeight + GAP + positionHeight)

		local function MakeCard(title, y, height)
			local cardWidget = Controls.SettingsCard(root, { title = title, width = width })
			local card = cardWidget.frame
			card:SetSize(width, height)
			card:SetPoint('TOPLEFT', 0, -y)
			card:SetFrameLevel((root:GetFrameLevel() or 0) + 5)
			return card
		end

		local textCard = MakeCard('TEXT', 0, textHeight)
		local colorsCard = MakeCard('COLORS', textHeight + GAP, colorsHeight)
		local panelCard = MakeCard('PANEL', textHeight + GAP + colorsHeight + GAP, panelHeight)
		local positionCard = MakeCard('POSITION', textHeight + GAP + colorsHeight + GAP + panelHeight + GAP, positionHeight)

		local fontCog = pageKit.SettingsIcon(textCard, {
			title = 'TEXT', tooltip = 'Size & outline', options = {
				{ kind = 'slider', label = 'Font Size', min = 8, max = 16,
				  get = function() return settings.fontSize or DEFAULT_FONT_SIZE end,
				  set = function(value) settings.fontSize = value end, apply = ApplyTextSettings },
				{ label = 'Outlined Text',
				  get = function() return settings.fontOutline == true end,
				  set = function(value) settings.fontOutline = value end, apply = ApplyTextSettings },
			},
		})
		local fontItems = BUI.BuildFontDropdownItems(BUI.C.GLOBAL_OPTION)
		table.insert(fontItems, 1, { value = LIBRARY_FONT_OPTION, text = 'Tooltip Font' })
		local fontDropdown = Controls.Dropdown(textCard, nil, fontItems, settings.font or LIBRARY_FONT_OPTION, function(value)
			settings.font = value
			ApplyTextSettings()
		end, nil, 150)
		pageKit.Row(textCard, 38, 'Font', fontCog)
		pageKit.AttachLeft(fontDropdown, fontCog)

		local singleLineToggle = Controls.SwitchToggle(textCard, nil, settings.singleLineTitles ~= false, function(value)
			settings.singleLineTitles = value
			ApplyTitleWrap()
			RefreshTrackerLayout()
		end)
		pageKit.Row(textCard, 78, 'Single-line Titles', singleLineToggle)

		local singleLineObjectivesToggle = Controls.SwitchToggle(textCard, nil, settings.singleLineObjectives ~= false, function(value)
			settings.singleLineObjectives = value
			ApplyTitleWrap()
			RefreshTrackerLayout()
		end)
		pageKit.Row(textCard, 118, 'Single-line Objectives', singleLineObjectivesToggle)

		local customColorsToggle = Controls.SwitchToggle(colorsCard, nil, settings.customColors ~= false, function(value)
			settings.customColors = value
			Skin.ApplyTrackerColors()
		end)
		pageKit.Row(colorsCard, 38, 'Custom Colors', customColorsToggle)

		local function ColorRow(y, label, key)
			local color = Skin.TrackerColor(key)
			local swatch = Controls.ColorSwatch(colorsCard, { r = color[1], g = color[2], b = color[3], a = 1, hasOpacity = false, callback = function(red, green, blue)
				settings.colors = settings.colors or {}
				settings.colors[key] = { red, green, blue }
				Skin.ApplyTrackerColors()
			end })
			pageKit.Row(colorsCard, y, label, swatch)
		end
		ColorRow(78, 'Quest Title', 'title')
		ColorRow(118, 'Title Hover', 'hover')
		ColorRow(158, 'Objective', 'objective')
		ColorRow(198, 'Completed Objective', 'completed')
		ColorRow(238, 'Ready to Turn In', 'ready')
		ColorRow(278, 'Time Left', 'timeLeft')

		local backgroundCog = pageKit.SettingsIcon(panelCard, {
			title = 'PANEL', tooltip = 'Background & sizing', options = {
				{ kind = 'slider', label = 'Opacity', min = 0, max = 100,
				  get = function() return settings.cardOpacity or DEFAULT_CARD_OPACITY end,
				  set = function(value) settings.cardOpacity = value end, apply = ApplyCardStyle },
				{ label = 'Border',
				  get = function() return settings.cardBorder ~= false end,
				  set = function(value) settings.cardBorder = value end, apply = ApplyCardStyle,
				  swatch = function()
					  local borderColor = settings.cardBorderColor or Theme.border.light
					  return { r = borderColor[1], g = borderColor[2], b = borderColor[3], a = borderColor[4] or 1,
						  callback = function(red, green, blue, alpha)
							  settings.cardBorderColor = { red, green, blue, alpha }
							  ApplyCardStyle()
						  end }
				  end },
				{ kind = 'slider', label = 'Max Height', min = 400, max = 1000,
				  get = function() return settings.maxHeight or DEFAULT_MAX_HEIGHT end,
				  set = function(value) settings.maxHeight = value end,
				  apply = function() RefreshScroll() ApplyEditModeHeight() end },
				{ kind = 'slider', label = 'Width', min = 260, max = 400,
				  get = function() return settings.trackerWidth or DEFAULT_TRACKER_WIDTH end,
				  set = function(value) settings.trackerWidth = value end,
				  apply = function() ApplyTrackerWidth() RefreshScroll() RefreshTrackerLayout() end },
			},
		})
		pageKit.Row(panelCard, 38, 'Background', backgroundCog)

		local textureItems = BUI.BuildTextureDropdownItems()
		table.insert(textureItems, 1, { value = FLAT_TEXTURE_OPTION, text = 'Flat' })
		local textureDropdown = Controls.Dropdown(panelCard, nil, textureItems, settings.cardTexture or FLAT_TEXTURE_OPTION, function(value)
			settings.cardTexture = value
			ApplyCardStyle()
		end, nil, 150)
		pageKit.Row(panelCard, 78, 'Texture', textureDropdown)
		local textureTint = settings.cardTextureColor or CARD_TEXTURE_TINT
		local textureSwatch = Controls.ColorSwatch(panelCard, { r = textureTint[1], g = textureTint[2], b = textureTint[3], a = 1, hasOpacity = false, callback = function(red, green, blue)
			settings.cardTextureColor = { red, green, blue }
			ApplyCardStyle()
		end })
		pageKit.AttachLeft(textureSwatch, textureDropdown)

		local separatorRed, separatorGreen, separatorBlue, separatorAlpha = Skin.TrackerSeparatorColor()
		local separatorSwatch = Controls.ColorSwatch(panelCard, { r = separatorRed, g = separatorGreen, b = separatorBlue, a = separatorAlpha, callback = function(red, green, blue, alpha)
			settings.separatorColor = { red, green, blue, alpha }
			Skin.ApplyTrackerSeparators()
		end })
		pageKit.Row(panelCard, 358, 'Separator Color', separatorSwatch)

		local hideTrackerToggle = Controls.SwitchToggle(panelCard, nil, settings.trackerHidden == true, function(value)
			settings.trackerHidden = value
			ApplyChallengeModeVisibility()
		end)
		pageKit.Row(panelCard, 398, 'Hide Tracker Completely', hideTrackerToggle)

		local scrollToggle = Controls.SwitchToggle(panelCard, nil, settings.scrollEnabled == true, function(value)
			settings.scrollEnabled = value
			BUI.Modals.Confirm({
				title = 'Reload Required',
				message = value
					and "Scrolling moves Blizzard's tracker sections into a BluUI panel. Blizzard's widget code then runs as addon code, so tooltips that show progress widgets can throw errors.\n\nReload now to apply?"
					or "Reload now to put the tracker back in Blizzard's own frame?",
				confirmText = 'Reload Now', cancelText = 'Later',
				onConfirm = BUI.Reload,
			})
		end)
		pageKit.Row(panelCard, 438, 'Scrolling', scrollToggle)

		local questIconsToggle = Controls.SwitchToggle(panelCard, nil, settings.showQuestIcons == true, function(value)
			settings.showQuestIcons = value
			ApplyPoiVisibility()
		end)
		pageKit.Row(panelCard, 118, 'Quest Type Icons', questIconsToggle)

		local dashesToggle = Controls.SwitchToggle(panelCard, nil, settings.showDashes == true, function(value)
			settings.showDashes = value
			ApplyDashAlpha()
		end)
		pageKit.Row(panelCard, 158, 'Objective Dashes', dashesToggle)

		local chimeDropdown = Controls.Dropdown(panelCard, nil, BUI.BuildSoundDropdownItems(), settings.completionSound or 'None', function(value)
			settings.completionSound = value
			BUI.PlaySoundByName(value)
		end, nil, 150)
		pageKit.Row(panelCard, 198, 'Completion Sound', chimeDropdown)

		local itemKeybind = Controls.Keybind(panelCard, nil, settings.questItemKey or 'NONE', function(value)
			settings.questItemKey = value
			UpdateQuestItemBinding()
		end, 190)
		pageKit.Row(panelCard, 238, 'Quest Item Key', itemKeybind)

		local tooltipToggle = Controls.SwitchToggle(panelCard, nil, settings.questTooltip ~= false, function(value)
			settings.questTooltip = value
		end)
		pageKit.Row(panelCard, 278, 'Quest Tooltip', tooltipToggle)

		local headerRowToggle = Controls.SwitchToggle(panelCard, nil, settings.showHeaderRow ~= false, function(value)
			settings.showHeaderRow = value
			if value == false then
				settings.trackerSectionFilters = nil
				settings.trackerTrackSpec = nil
				QuestFilter.Refresh()
			end
			ApplyHeaderRowVisibility()
		end)
		pageKit.Row(panelCard, 318, 'Objectives Header', headerRowToggle)

		local resetButton = Controls.Button(positionCard, 'Reset', 84, function()
			local positions = BUI.GetDB().framePositions
			if positions then positions[POSITION_KEY] = nil end
			print('|cff6D00FDBluUI:|r Tracker position cleared. Reload the UI to restore the Blizzard anchor.')
		end)
		pageKit.Row(positionCard, 38, 'Reset Position', resetButton)

		content:Refresh()
	end,
})
