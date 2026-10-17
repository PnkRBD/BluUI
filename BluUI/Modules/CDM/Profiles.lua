local _, BUI = ...

local CDM = BUI.CDM
local Profiles = {}
CDM.Profiles = Profiles

local function Store()
    local globalDB = BUI.db.global
    globalDB.cdmLayouts = globalDB.cdmLayouts or {}
    globalDB.cdmLayouts.snapshots = globalDB.cdmLayouts.snapshots or {}
    return globalDB.cdmLayouts
end

local function GetLayoutManager()
    return CooldownViewerSettings:GetLayoutManager()
end

function Profiles.GetBlizzardLayouts()
    local layouts = {}
    for layoutID, layout in GetLayoutManager():EnumerateLayouts() do
        layouts[#layouts + 1] = { id = layoutID, name = CooldownManagerLayout_GetName(layout), isDefault = CooldownManagerLayout_IsDefaultLayout(layout) }
    end
    table.sort(layouts, function(left, right) return left.id < right.id end)
    return layouts
end

function Profiles.GetSnapshots()
    return Store().snapshots
end

function Profiles.FindSnapshot(name)
    local snapshots = Profiles.GetSnapshots()
    for snapshotIndex = 1, #snapshots do
        if snapshots[snapshotIndex].name == name then return snapshotIndex, snapshots[snapshotIndex] end
    end
end

function Profiles.SaveSnapshot(name)
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false, "Enter a name for the snapshot first."
    elseif #name > 40 then return false, "Snapshot name is too long (max 40)." end
    local data = C_CooldownViewer.GetLayoutData()
    if data == "" then return false, "No layout data to save. Set up the Cooldown Manager first." end
    local store = Store()
    local _, snapshot = Profiles.FindSnapshot(name)
    if not snapshot then
        snapshot = { name = name, created = time() }
        store.snapshots[#store.snapshots + 1] = snapshot
    end
    local className, classFile = UnitClass("player")
    snapshot.data = data
    snapshot.class = className
    snapshot.classFile = classFile
    snapshot.character = UnitName("player")
    snapshot.modified = time()
    return true, name
end

function Profiles.AutoBackupSnapshot()
    local data = C_CooldownViewer.GetLayoutData()
    if data == "" then return false end
    for _, snapshot in ipairs(Profiles.GetSnapshots()) do
        if snapshot.data == data then return false end
    end
    local base = "Backup " .. date("%Y-%m-%d %H:%M")
    local name, suffix = base, 2
    while Profiles.FindSnapshot(name) do
        name = base .. " (" .. suffix .. ")"
        suffix = suffix + 1
    end
    return Profiles.SaveSnapshot(name)
end

function Profiles.ExportCurrent()
    local data = C_CooldownViewer.GetLayoutData()
    if data == "" then return nil, "No layout data to export." end
    return data
end

function Profiles.ApplyLayoutData(data)
    if InCombatLockdown() then return false, "Cannot change Cooldown Manager layouts during combat." end
    local previous = C_CooldownViewer.GetLayoutData()
    local ok = xpcall(C_CooldownViewer.SetLayoutData, geterrorhandler(), data)
    if not ok then
        if previous ~= "" then xpcall(C_CooldownViewer.SetLayoutData, geterrorhandler(), previous) end
        return false, "Blizzard rejected that layout data."
    end
    return true
end

function Profiles.ApplySnapshot(name)
    local _, snapshot = Profiles.FindSnapshot(name)
    if not snapshot or not snapshot.data or snapshot.data == "" then return false, "Snapshot '" .. tostring(name) .. "' has no data." end
    return Profiles.ApplyLayoutData(snapshot.data)
end

function Profiles.DeleteSnapshot(name)
    local index = Profiles.FindSnapshot(name)
    if not index then return false, "Snapshot not found." end
    table.remove(Profiles.GetSnapshots(), index)
    return true
end

function Profiles.ExportLayout(layoutID)
    local serializer = GetLayoutManager():GetSerializer()
    local dataOk, data = xpcall(serializer.SerializeLayouts, geterrorhandler(), serializer, layoutID)
    if not dataOk or not data or data == "" then return nil, "Could not serialize that layout." end
    return data
end

function Profiles.IsLayoutString(layoutString)
    layoutString = layoutString:gsub("^%s+", ""):gsub("%s+$", "")
    return layoutString:match("^%d+|") ~= nil, layoutString
end

function Profiles.ImportLayoutString(layoutString)
    local valid
    valid, layoutString = Profiles.IsLayoutString(layoutString)
    if not valid then return false, "That is not a Cooldown Manager layout string." end
    if InCombatLockdown() then return false, "Cannot import layouts during combat." end
    local manager = GetLayoutManager()
    local ok, newLayoutIDs = xpcall(manager.CreateLayoutsFromSerializedData, geterrorhandler(), manager, layoutString)
    if not ok then return false, "Import failed. The string may be damaged or from a newer game version." end
    local added = newLayoutIDs and #newLayoutIDs or 0
    if added == 0 then return false, "No layouts were added. All layout slots may be in use (max 5)." end
    manager:SaveLayouts()
    return true, added
end
