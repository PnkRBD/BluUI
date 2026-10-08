local _, BUI = ...

local PartyKeys = {}
BUI.PartyKeys = PartyKeys

local GetUnitName            = GetUnitName
local GetNormalizedRealmName = GetNormalizedRealmName
local UnitExists             = UnitExists
local issecretvalue          = issecretvalue

local PARTY_UNITS = { 'player', 'party1', 'party2', 'party3', 'party4' }

local keys = {}
local listeners = {}
local library

local function NameKey(name)
	if type(name) ~= 'string' or issecretvalue(name) or name == '' then return nil end
	if name:find('-', 1, true) then return name end
	local realm = GetNormalizedRealmName()
	if type(realm) ~= 'string' or realm == '' then return name end
	return name .. '-' .. realm
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
	for _, listener in pairs(listeners) do listener() end
end

function PartyKeys.Request()
	if not library then
		library = LibStub('LibKeystone')
		library.Register(PartyKeys, Receive)
	end
	library.Request('PARTY')
end

function PartyKeys.Listen(name, callback)
	listeners[name] = callback
end

function PartyKeys.ForUnit(unit)
	local key = NameKey(GetUnitName(unit, true))
	return key and keys[key]
end

function PartyKeys.LevelFor(mapID)
	for _, unit in ipairs(PARTY_UNITS) do
		local entry = UnitExists(unit) and PartyKeys.ForUnit(unit)
		if entry and entry.mapID == mapID and entry.level > 0 then return entry.level end
	end
end
