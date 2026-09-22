local _, BUI = ...

local GroupFrames = BUI.GroupFrames
local Util = GroupFrames.Util

local CreateFrame            = CreateFrame
local GetUnitName            = GetUnitName
local GetNormalizedRealmName = GetNormalizedRealmName
local UnitExists             = UnitExists
local C_ChallengeMode        = C_ChallengeMode
local LibStub                = LibStub

local Keystone = {}
GroupFrames.Keystone = Keystone

local keys = {}
local abbreviations = {}
local runActive = false
local libHandle
local refreshQueued = false

local FILLER = { the = true, of = true, ["and"] = true, ["in"] = true, ["a"] = true }

local function Abbreviate(mapID)
	if type(mapID) ~= "number" or mapID <= 0 then return nil end
	local stored = abbreviations[mapID]
	if stored then return stored end
	local name = C_ChallengeMode.GetMapUIInfo(mapID)
	if type(name) ~= "string" or name == "" then return nil end
	local letters = ""
	for word in name:gmatch("[%a']+") do
		if not FILLER[word:lower()] then letters = letters .. word:sub(1, 1):upper() end
	end
	if letters == "" then return nil end
	abbreviations[mapID] = letters
	return letters
end

local function NameKey(name)
	if type(name) ~= "string" or name == "" then return nil end
	if Util.IsSecret(name) then return nil end
	if name:find("-", 1, true) then return name end
	local realm = GetNormalizedRealmName()
	if type(realm) ~= "string" or realm == "" then return name end
	return name .. "-" .. realm
end

local function UnitKey(unit)
	if not unit then return nil end
	local name = GetUnitName(unit, true)
	if Util.IsSecret(name) then return nil end
	return NameKey(name)
end

local function Label(entry)
	if not entry then return nil end
	local level = entry.level
	if type(level) ~= "number" or level <= 0 then return nil end
	local short = Abbreviate(entry.mapID)
	if short then return "+" .. level .. " " .. short end
	return "+" .. level
end

local function ReadRunState()
	if C_ChallengeMode.IsChallengeModeActive() then return true end
	local level = C_ChallengeMode.GetActiveKeystoneInfo()
	return type(level) == "number" and level > 0
end

function Keystone.Update(child)
	local text = child and child.KeystoneText
	if not text then return end
	local settings = GroupFrames.SettingsForFrame(child)
	if not settings.showKeystone or not settings.keystone or runActive then
		text:Hide()
		return
	end
	if child._preview then
		text:SetText("+12 TR")
		text:Show()
		return
	end
	local unit = child.unit
	if not unit or not UnitExists(unit) then
		text:Hide()
		return
	end
	local label = Label(keys[UnitKey(unit)])
	if not label then
		text:Hide()
		return
	end
	text:SetText(label)
	text:Show()
end

local function RefreshAll()
	refreshQueued = false
	GroupFrames.EachPartyChild(Keystone.Update)
end

local function QueueRefresh()
	if refreshQueued then return end
	refreshQueued = true
	BUI.Prof.After("GroupFrames.Keystone", 0, RefreshAll)
end

local function Receive(level, mapID, _, sender)
	local key = NameKey(sender)
	if not key then return end
	local entry = keys[key]
	if not entry then
		entry = {}
		keys[key] = entry
	end
	entry.level, entry.mapID = level, mapID
	QueueRefresh()
end

local function Library()
	if libHandle then return libHandle end
	local lib = LibStub("LibKeystone")
	lib.Register(Keystone, Receive)
	libHandle = lib
	return lib
end

local function RequestKeys()
	Library().Request("PARTY")
end

function GroupFrames.BuildKeystone(frame, unit)
	local settings = GroupFrames.SettingsForFrame(frame)
	local config = settings.keystone
	if not config or not frame.Health then return end

	local holder = CreateFrame("Frame", nil, frame.Health)
	holder:SetAllPoints()
	holder:SetFrameLevel(frame.Health:GetFrameLevel() + 6)

	config.outline = ""
	local text = holder:CreateFontString(nil, "OVERLAY")
	GroupFrames.ApplyTextSettings(text, frame.Health, config, GroupFrames.ResolveFont(settings.font))
	text:Hide()
	frame.KeystoneText = text
end

function GroupFrames.ApplyKeystoneToChild(child, settings)
	local text = child.KeystoneText
	if not text then return end
	local config = settings.keystone
	if not config then
		text:Hide()
		return
	end
	config.outline = ""
	GroupFrames.ApplyTextSettings(text, child.Health, config, GroupFrames.ResolveFont(settings.font))
	local color = config.color
	text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	Keystone.Update(child)
end

local function SetRunState(active)
	if active == runActive then return end
	runActive = active
	QueueRefresh()
end

BUI.Events:Register("CHALLENGE_MODE_START", "GroupFramesKeystone", function() SetRunState(true) end)
BUI.Events:Register("CHALLENGE_MODE_RESET", "GroupFramesKeystone", function() SetRunState(ReadRunState()) end)

BUI.Events:Register("CHALLENGE_MODE_COMPLETED", "GroupFramesKeystone", function()
	SetRunState(false)
	QueueRefresh()
end)

BUI.Events:Register("ZONE_CHANGED_NEW_AREA", "GroupFramesKeystone", function()
	SetRunState(ReadRunState())
end)

BUI.Events:Register("GROUP_ROSTER_UPDATE", "GroupFramesKeystone", function()
	RequestKeys()
	QueueRefresh()
end)

BUI.Events:Register("CHALLENGE_MODE_MAPS_UPDATE", "GroupFramesKeystone", QueueRefresh)

BUI.Events:Register("PLAYER_ENTERING_WORLD", "GroupFramesKeystone", function()
	SetRunState(ReadRunState())
	C_MythicPlus.RequestMapInfo()
	RequestKeys()
	QueueRefresh()
end)
