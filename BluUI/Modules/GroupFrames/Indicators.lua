local _, BUI = ...

local GroupFrames    = BUI.GroupFrames
local Util  = GroupFrames.Util
local Pixel = BUI.Pixel

local CreateFrame            = CreateFrame
local UnitIsUnit             = UnitIsUnit
local UnitInParty            = UnitInParty
local UnitIsGroupLeader      = UnitIsGroupLeader
local UnitIsGroupAssistant   = UnitIsGroupAssistant

local ROLE_ATLAS = {
	TANK    = "UI-LFG-RoleIcon-Tank-Micro-Raid",
	HEALER  = "UI-LFG-RoleIcon-Healer-Micro-Raid",
	DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-Raid",
}

local READY_ATLAS = {
	ready    = "UI-LFG-ReadyMark-Raid",
	notready = "UI-LFG-DeclineMark-Raid",
	waiting  = "UI-LFG-PendingMark-Raid",
}

local function MakeIndicator(frame, config, elementName)
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetFrameLevel(frame:GetFrameLevel() + GroupFrames.Layers.indicators)
	holder:SetSize(Pixel.Scale(config.size), Pixel.Scale(config.size))
	holder:SetPoint(config.anchor, frame, config.anchor, Pixel.Scale(config.offsetX), Pixel.Scale(config.offsetY))

	local texture = holder:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints()
	texture:SetShown(config.enabled)
	texture._elementName = elementName
	return texture
end

local TRANSIENT_ELEMENTS = { ReadyCheckIndicator = true }

local function ApplyIndicator(texture, config)
	if not texture then return end
	local holder = texture:GetParent()
	local frame  = holder:GetParent()
	holder:SetSize(Pixel.Scale(config.size), Pixel.Scale(config.size))
	holder:ClearAllPoints()
	holder:SetPoint(config.anchor, frame, config.anchor, Pixel.Scale(config.offsetX), Pixel.Scale(config.offsetY))

	if texture._previewOn then return end

	local name = texture._elementName
	if config.enabled then
		if name and not frame:IsElementEnabled(name) then
			frame:EnableElement(name)
		end
		if texture.ForceUpdate and not TRANSIENT_ELEMENTS[name] and frame.unit and UnitExists(frame.unit) then texture:ForceUpdate() end
	else
		if name and frame:IsElementEnabled(name) then
			frame:DisableElement(name)
		end
		texture:Hide()
		texture:SetTexture(nil)
		texture:SetAtlas(nil)
	end
end

local ROLE_ICON_ROLES = {
	tank       = { TANK = true },
	healer     = { HEALER = true },
	tankhealer = { TANK = true, HEALER = true },
}

local function RoleOverride(self)
	local element = self.GroupRoleIndicator
	if element._previewOn then return end
	local role  = Util.FrameRole(self)
	local atlas = role and ROLE_ATLAS[role]
	local allowedRoles  = ROLE_ICON_ROLES[GroupFrames.SettingsForFrame(self).roleIconFilter or "all"]
	if atlas and (not allowedRoles or allowedRoles[role]) then
		element:SetAtlas(atlas); element:Show()
	else
		element:Hide()
	end
end

local function LeaderOverride(self)
	local element = self.LeaderIndicator
	if element._previewOn then return end
	if self._preview then
		local decoy = self._previewDecoy
		if decoy and decoy.leader then
			element:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon", element.useAtlasSize)
			element:Show()
		else
			element:Hide()
		end
		return
	end
	if self.unit and UnitInParty(self.unit) and UnitIsGroupLeader(self.unit) then
		element:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon", element.useAtlasSize)
		element:Show()
	else
		element:Hide()
	end
end

local function AssistantOverride(self)
	local element = self.AssistantIndicator
	if element._previewOn then return end
	if self._preview then element:Hide(); return end
	if self.unit and UnitInParty(self.unit) and UnitIsGroupAssistant(self.unit) and not UnitIsGroupLeader(self.unit) then
		element:SetAtlas("UI-HUD-UnitFrame-Party-PortraitOn-Icon-Assist", element.useAtlasSize)
		element:Show()
	else
		element:Hide()
	end
end

local function WirePlayerReadyCheck(frame, texture)
	local watcher = CreateFrame("Frame", nil, frame)
	local hideTimer
	local function ApplyReadyStatus()
		local status = GetReadyCheckStatus("player")
		if status and READY_ATLAS[status] then
			texture:SetAtlas(READY_ATLAS[status]); texture:Show()
		else
			texture:Hide()
		end
	end
	watcher:SetScript("OnEvent", function(_, event)
		if event == "READY_CHECK_FINISHED" then
			if hideTimer then hideTimer:Cancel() end
			hideTimer = C_Timer.NewTimer(10, function()
				hideTimer = nil
				texture:Hide()
			end)
		else
			if hideTimer then hideTimer:Cancel(); hideTimer = nil end
			ApplyReadyStatus()
		end
	end)
	watcher:RegisterEvent("READY_CHECK")
	watcher:RegisterEvent("READY_CHECK_CONFIRM")
	watcher:RegisterEvent("READY_CHECK_FINISHED")
end

function GroupFrames.BuildIndicators(frame, unit)
	local settings = GroupFrames.SettingsForFrame(frame)
	frame.GroupRoleIndicator  = MakeIndicator(frame, settings.roleIcon,       "GroupRoleIndicator")
	frame.LeaderIndicator     = MakeIndicator(frame, settings.leaderIcon,     "LeaderIndicator")
	frame.AssistantIndicator  = MakeIndicator(frame, settings.leaderIcon,     "AssistantIndicator")
	frame.RaidTargetIndicator = MakeIndicator(frame, settings.raidTargetIcon, "RaidTargetIndicator")
	frame.ResurrectIndicator  = MakeIndicator(frame, settings.resurrectIcon,  "ResurrectIndicator")
	frame.ReadyCheckIndicator = MakeIndicator(frame, settings.readyCheckIcon, "ReadyCheckIndicator")
	frame.CombatIndicator     = MakeIndicator(frame, settings.combatIcon,     "CombatIndicator")

	frame.GroupRoleIndicator.Override = RoleOverride
	frame.LeaderIndicator.Override    = LeaderOverride
	frame.AssistantIndicator.Override = AssistantOverride
	frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() RoleOverride(frame) end, true)
	frame:RegisterEvent("PLAYER_ROLES_ASSIGNED", function() RoleOverride(frame) end, true)

	if unit == "player" then
		WirePlayerReadyCheck(frame, frame.ReadyCheckIndicator)
	end
end

function GroupFrames.ApplyIndicatorsToChild(child, settings)
	ApplyIndicator(child.GroupRoleIndicator,  settings.roleIcon)
	ApplyIndicator(child.LeaderIndicator,     settings.leaderIcon)
	ApplyIndicator(child.AssistantIndicator,  settings.leaderIcon)
	ApplyIndicator(child.RaidTargetIndicator, settings.raidTargetIcon)
	ApplyIndicator(child.ResurrectIndicator,  settings.resurrectIcon)
	ApplyIndicator(child.ReadyCheckIndicator, settings.readyCheckIcon)
	ApplyIndicator(child.CombatIndicator,     settings.combatIcon)
end

local INDICATOR_FIELD = {
	role       = "GroupRoleIndicator",
	leader     = "LeaderIndicator",
	assistant  = "AssistantIndicator",
	raidTarget = "RaidTargetIndicator",
	resurrect  = "ResurrectIndicator",
	readyCheck = "ReadyCheckIndicator",
	combat     = "CombatIndicator",
}

local INDICATOR_PREVIEW = {
	role       = { atlas   = "UI-LFG-RoleIcon-Tank-Micro-Raid" },
	leader     = { atlas   = "UI-HUD-UnitFrame-Player-Group-LeaderIcon" },
	assistant  = { texture = "Interface\\GroupFrame\\UI-Group-AssistantIcon" },
	raidTarget = { raidTarget = 8 },
	resurrect  = { atlas   = "RaidFrame-Icon-Rez" },
	readyCheck = { atlas   = "UI-LFG-ReadyMark-Raid" },
	combat     = { atlas   = "UI-HUD-UnitFrame-Player-CombatIcon" },
}

local previewActive = {}

local function RestoreElementAsset(child, texture)
	local name = texture._elementName
	if name and child:IsElementEnabled(name) then
		child:DisableElement(name)
		child:EnableElement(name)
	end
	if texture.ForceUpdate and child.unit and UnitExists(child.unit) then texture:ForceUpdate() end
end

function GroupFrames.PreviewIndicator(kind, enabled)
	previewActive[kind] = enabled or nil
	local field = INDICATOR_FIELD[kind]
	local previewData  = INDICATOR_PREVIEW[kind]
	if not field or not previewData then return end

	GroupFrames.EachChild(function(child)
		local texture = child[field]
		if enabled then
			texture._previewOn = true
			if previewData.atlas then texture:SetAtlas(previewData.atlas)
			elseif previewData.raidTarget then
				texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
				SetRaidTargetIconTexture(texture, previewData.raidTarget)
			elseif previewData.texture then texture:SetTexture(previewData.texture)
			end
			texture:Show()
		elseif texture._previewOn then
			texture._previewOn = nil
			texture:Hide()
			RestoreElementAsset(child, texture)
		end
	end)
end

function GroupFrames.IsIndicatorPreviewing(kind) return previewActive[kind] == true end

function GroupFrames.ClearIndicatorPreviews()
	local kinds = {}
	for kind in pairs(previewActive) do kinds[#kinds + 1] = kind end
	for _, kind in ipairs(kinds) do GroupFrames.PreviewIndicator(kind, false) end
end

function GroupFrames.ReapplyIndicatorPreviews()
	for kind in pairs(previewActive) do GroupFrames.PreviewIndicator(kind, true) end
end

local function UpdateSelection(frame)
	local selection = frame.Selection
	if not selection then return end
	local unit = frame.unit
	if not unit then selection:Hide(); return end
	local settings = GroupFrames.SettingsForFrame(frame)
	local isTarget    = UnitIsUnit("target", unit) and settings.targetBorder.enabled
	local isMouseover = frame._isMouseover and settings.mouseoverBorder.enabled

	if isTarget then
		local color = settings.targetBorder.color
		Pixel.SetBorderColor(selection, color[1], color[2], color[3], color[4])
		selection:Show()
	elseif isMouseover then
		local color = settings.mouseoverBorder.color
		Pixel.SetBorderColor(selection, color[1], color[2], color[3], color[4])
		selection:Show()
	else
		selection:Hide()
	end
end

function GroupFrames.BuildSelection(frame, unit)
	local settings = GroupFrames.SettingsForFrame(frame)
	local thickness = math.max(settings.targetBorder.thickness, settings.mouseoverBorder.thickness)
	local selection = CreateFrame("Frame", nil, frame)
	selection:SetFrameLevel(frame:GetFrameLevel() + GroupFrames.Layers.selection)
	selection:SetPoint("TOPLEFT", 0, 0)
	selection:SetPoint("BOTTOMRIGHT", 0, 0)
	Pixel.SetTemplate(selection, 0, 0, 0, 0, 1, 1, 0, 1, thickness)
	selection:Hide()
	frame.Selection = selection

	frame:HookScript("OnEnter", function(self)
		self._isMouseover = true
		UpdateSelection(self)
	end)
	frame:HookScript("OnLeave", function(self)
		self._isMouseover = false
		UpdateSelection(self)
	end)
end

function GroupFrames.ApplySelectionToChild(child, settings)
	if not child.Selection then return end
	local thickness = math.max(settings.targetBorder.thickness, settings.mouseoverBorder.thickness)
	child.Selection:ClearAllPoints()
	child.Selection:SetPoint("TOPLEFT", 0, 0)
	child.Selection:SetPoint("BOTTOMRIGHT", 0, 0)
	Pixel.SetTemplate(child.Selection, 0, 0, 0, 0, 1, 1, 0, 1, thickness)
	UpdateSelection(child)
end

local selectionWatcher
function GroupFrames.HookSelection()
	if selectionWatcher then return end
	selectionWatcher = CreateFrame("Frame")
	selectionWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
	selectionWatcher:SetScript("OnEvent", function()
		GroupFrames.EachChild(UpdateSelection)
	end)
end

BUI.oUF:RegisterInitCallback(function(frame)
	if frame.style ~= GroupFrames.STYLE_NAME then return end
	GroupFrames.ApplyIndicatorsToChild(frame, GroupFrames.SettingsForFrame(frame))
end)
