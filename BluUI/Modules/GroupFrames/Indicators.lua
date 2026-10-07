local _, BUI = ...

local Wrap = BUI.Profiler.Wrap

local GroupFrames    = BUI.GroupFrames
local Util  = GroupFrames.Util
local Pixel = BUI.Pixel
local SafeBool = BUI.Tools.SafeBool

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

local PIXEL_FILTER  = "NEAREST"
local TRIMMED_ATLAS = ROLE_ATLAS.HEALER:lower()
local TRIM_COLUMN   = 1
local TRIM_ROW      = 5

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
	Pixel.KeepSnap(texture)
	texture:SetAllPoints()
	texture:SetShown(config.enabled)
	texture._elementName = elementName
	return texture
end

local function Cuts(texels, skip, length)
	local cut = Pixel.Scale(length * skip / (texels - 1))
	return { { 0, cut, 0, skip }, { cut, length, skip + 1, texels } }
end

local function FitTrimmed(texture, info)
	local holder = texture:GetParent()
	local size = holder:GetWidth()
	local piece = 0
	for _, row in ipairs(Cuts(info.height, TRIM_ROW, size)) do
		for _, column in ipairs(Cuts(info.width, TRIM_COLUMN, size)) do
			local slice = piece == 0 and texture or texture._slices[piece]
			if slice ~= texture then slice:SetAtlas(texture._atlas, nil, PIXEL_FILTER) end
			slice:SetTexCoord(column[3] / info.width, column[4] / info.width, row[3] / info.height, row[4] / info.height)
			slice:ClearAllPoints()
			slice:SetPoint("TOPLEFT", holder, "TOPLEFT", column[1], -row[1])
			slice:SetPoint("BOTTOMRIGHT", holder, "TOPLEFT", column[2], -row[2])
			piece = piece + 1
		end
	end
end

local function FitAtlas(texture)
	local atlas = texture._atlas
	local slices = texture._slices
	local trimmed = slices ~= nil and atlas ~= nil and atlas:lower() == TRIMMED_ATLAS
	texture:ClearAllPoints()
	if trimmed then
		FitTrimmed(texture, C_Texture.GetAtlasInfo(atlas))
	else
		texture:SetTexCoord(0, 1, 0, 1)
		texture:SetAllPoints()
	end
	if slices then
		for _, slice in ipairs(slices) do slice:SetShown(trimmed and texture:IsShown()) end
	end
end

local function HideIcon(texture)
	texture:Hide()
	if texture._slices then
		for _, slice in ipairs(texture._slices) do slice:Hide() end
	end
end

local TRANSIENT_ELEMENTS = { ReadyCheckIndicator = true }

local function ApplyIndicator(texture, config)
	if not texture then return end
	local holder = texture:GetParent()
	local frame  = holder:GetParent()
	holder:SetSize(Pixel.Scale(config.size), Pixel.Scale(config.size))
	holder:ClearAllPoints()
	holder:SetPoint(config.anchor, frame, config.anchor, Pixel.Scale(config.offsetX), Pixel.Scale(config.offsetY))
	if texture._slices then FitAtlas(texture) end

	if texture._previewOn then return end

	local name = texture._elementName
	if config.enabled then
		if name and not frame:IsElementEnabled(name) then
			frame:EnableElement(name, frame:GetAttribute("oUF-guessUnit"))
		end
		if texture.ForceUpdate and not TRANSIENT_ELEMENTS[name] and frame.unit and UnitExists(frame.unit) then texture:ForceUpdate() end
	else
		if name and frame:IsElementEnabled(name) then
			frame:DisableElement(name)
		end
		HideIcon(texture)
		texture:SetTexture(nil)
		texture:SetAtlas(nil)
		texture._atlas = nil
	end
end

local ROLE_ICON_ROLES = {
	tank       = { TANK = true },
	healer     = { HEALER = true },
	tankhealer = { TANK = true, HEALER = true },
}

local LEADER_ATLAS    = "UI-HUD-UnitFrame-Player-Group-LeaderIcon"
local ASSISTANT_TEXTURE = "Interface\\GroupFrame\\UI-Group-AssistantIcon"

local function ShowAtlas(element, atlas, useAtlasSize)
	if element:IsShown() and element._atlas == atlas then return end
	element:SetAtlas(atlas, useAtlasSize, PIXEL_FILTER)
	element._atlas = atlas
	element:Show()
	FitAtlas(element)
end

local function RoleOverride(self)
	local element = self.GroupRoleIndicator
	if element._previewOn or not self:IsElementEnabled("GroupRoleIndicator") then return end
	local role  = Util.FrameRole(self)
	local atlas = role and ROLE_ATLAS[role]
	local allowedRoles  = ROLE_ICON_ROLES[GroupFrames.SettingsForFrame(self).roleIconFilter or "all"]
	if atlas and (not allowedRoles or allowedRoles[role]) then
		ShowAtlas(element, atlas)
	else
		HideIcon(element)
	end
end

local function LeaderOverride(self)
	local element = self.LeaderIndicator
	if element._previewOn then return end
	if self._preview then
		local decoy = self._previewDecoy
		if decoy and decoy.leader then
			ShowAtlas(element, LEADER_ATLAS, element.useAtlasSize)
		else
			element:Hide()
		end
		return
	end
	if self.unit and UnitInParty(self.unit) and SafeBool(UnitIsGroupLeader(self.unit)) then
		ShowAtlas(element, LEADER_ATLAS, element.useAtlasSize)
	else
		element:Hide()
	end
end

local function AssistantOverride(self)
	local element = self.AssistantIndicator
	if element._previewOn then return end
	if self._preview then element:Hide(); return end
	if self.unit and UnitInParty(self.unit) and SafeBool(UnitIsGroupAssistant(self.unit)) and not SafeBool(UnitIsGroupLeader(self.unit)) then
		element:SetTexture(ASSISTANT_TEXTURE, nil, nil, PIXEL_FILTER)
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
	watcher:SetScript("OnEvent", Wrap("GroupFrames.Indicators ready check", function(_, event)
		if event == "READY_CHECK_FINISHED" then
			if hideTimer then hideTimer:Cancel() end
			hideTimer = BUI.Profiler.NewTimer("GroupFrames.Indicators ready hide", 10, function()
				hideTimer = nil
				texture:Hide()
			end)
		else
			if hideTimer then hideTimer:Cancel(); hideTimer = nil end
			ApplyReadyStatus()
		end
	end))
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
	local slices = {}
	for index = 1, 3 do
		local slice = frame.GroupRoleIndicator:GetParent():CreateTexture(nil, "OVERLAY")
		Pixel.KeepSnap(slice)
		slice:Hide()
		slices[index] = slice
	end
	frame.GroupRoleIndicator._slices  = slices
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
	role       = { atlas   = ROLE_ATLAS.TANK, filter = PIXEL_FILTER },
	leader     = { atlas   = LEADER_ATLAS, filter = PIXEL_FILTER },
	assistant  = { texture = ASSISTANT_TEXTURE, filter = PIXEL_FILTER },
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
		child:EnableElement(name, child:GetAttribute("oUF-guessUnit"))
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
			if previewData.atlas then
				texture:SetAtlas(previewData.atlas, nil, previewData.filter)
				texture._atlas = previewData.atlas
				if texture._slices then FitAtlas(texture) end
			elseif previewData.raidTarget then
				texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
				SetRaidTargetIconTexture(texture, previewData.raidTarget)
			elseif previewData.texture then texture:SetTexture(previewData.texture, nil, nil, previewData.filter)
			end
			texture:Show()
		elseif texture._previewOn then
			texture._previewOn = nil
			HideIcon(texture)
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

local targetedFrames = {}

local function UpdateSelection(frame)
	local selection = frame.Selection
	if not selection then return end
	targetedFrames[frame] = nil
	local unit = frame.unit
	if not unit then selection:Hide(); return end
	local settings = GroupFrames.SettingsForFrame(frame)
	local border
	if UnitIsUnit("target", unit) and settings.targetBorder.enabled then
		border = settings.targetBorder
		targetedFrames[frame] = true
	elseif frame._isMouseover and settings.mouseoverBorder.enabled then
		border = settings.mouseoverBorder
	end
	if not border then
		selection:Hide()
		return
	end
	local color = border.color
	Pixel.SetTemplate(selection, 0, 0, 0, 0, color[1], color[2], color[3], color[4], border.thickness)
	selection:Show()
end

function GroupFrames.BuildSelection(frame, unit)
	local selection = CreateFrame("Frame", nil, frame)
	selection:SetFrameLevel(frame:GetFrameLevel() + GroupFrames.Layers.selection)
	selection:SetPoint("TOPLEFT", 0, 0)
	selection:SetPoint("BOTTOMRIGHT", 0, 0)
	selection:Hide()
	frame.Selection = selection

	frame:HookScript("OnEnter", BUI.Profiler.Wrap('GroupFrames.Indicators frame OnEnter', function(self)
		self._isMouseover = true
		UpdateSelection(self)
	end))
	frame:HookScript("OnLeave", BUI.Profiler.Wrap('GroupFrames.Indicators frame OnLeave', function(self)
		self._isMouseover = false
		UpdateSelection(self)
	end))
end

GroupFrames.RefreshSelection = UpdateSelection

local previouslyTargeted = {}

local function SelectIfTarget(child)
	if child.unit and UnitIsUnit("target", child.unit) then UpdateSelection(child) end
end

local function TargetInGroup()
	return UnitPlayerOrPetInRaid("target") or UnitPlayerOrPetInParty("target") or UnitIsUnit("target", "player")
end

local selectionWatcher
function GroupFrames.HookSelection()
	if selectionWatcher then return end
	selectionWatcher = CreateFrame("Frame")
	selectionWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
	selectionWatcher:SetScript("OnEvent", Wrap("GroupFrames.Indicators target change", function()
		for frame in pairs(targetedFrames) do previouslyTargeted[#previouslyTargeted + 1] = frame end
		for index = #previouslyTargeted, 1, -1 do
			UpdateSelection(previouslyTargeted[index])
			previouslyTargeted[index] = nil
		end
		if TargetInGroup() then GroupFrames.EachChild(SelectIfTarget) end
	end))
end

BUI.oUF:RegisterInitCallback(function(frame)
	if frame.style ~= GroupFrames.STYLE_NAME then return end
	GroupFrames.ApplyIndicatorsToChild(frame, GroupFrames.SettingsForFrame(frame))
end)
