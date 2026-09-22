local _, BUI = ...

local CDM = BUI.CDM
local Profiles = {}
CDM.Profiles = Profiles

local function Store()
    local globalDB = BUI.db and BUI.db.global
    if not globalDB then return nil end
    globalDB.cdmLayouts = globalDB.cdmLayouts or {}
    globalDB.cdmLayouts.snapshots = globalDB.cdmLayouts.snapshots or {}
    return globalDB.cdmLayouts
end

function Profiles.IsAvailable()
    return (C_CooldownViewer.GetLayoutData and C_CooldownViewer.SetLayoutData) ~= nil
end

local layoutManager
local function GetLayoutManager()
    if layoutManager then return layoutManager end
    if not CooldownViewerSettings then
        C_AddOns.LoadAddOn("Blizzard_CooldownViewer")
    end
    if CooldownViewerSettings and CooldownViewerSettings.GetLayoutManager then
        layoutManager = CooldownViewerSettings:GetLayoutManager()
    end
    return layoutManager
end
Profiles.GetLayoutManager = GetLayoutManager

function Profiles.GetBlizzardLayouts()
    local manager = GetLayoutManager()
    if not manager then return {} end
    local layouts = {}
    for layoutID, layout in manager:EnumerateLayouts() do
        local entry = { id = layoutID, name = "Layout " .. layoutID, isDefault = false }
        local name = CooldownManagerLayout_GetName(layout)
        if name and name ~= "" then entry.name = name end
        entry.isDefault = CooldownManagerLayout_IsDefaultLayout(layout) or false
        layouts[#layouts + 1] = entry
    end
    table.sort(layouts, function(left, right) return left.id < right.id end)
    return layouts
end

function Profiles.GetSnapshots()
    local store = Store()
    return (store and store.snapshots) or {}
end

function Profiles.FindSnapshot(name)
    local snapshots = Profiles.GetSnapshots()
    for snapshotIndex = 1, #snapshots do
        if snapshots[snapshotIndex].name == name then return snapshotIndex, snapshots[snapshotIndex] end
    end
end

function Profiles.SaveSnapshot(name)
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false, "Enter a name for the snapshot first."
    elseif #name > 40 then return false, "Snapshot name is too long (max 40)." end
    if not Profiles.IsAvailable() then return false, "The Cooldown Manager layout API is not available." end
    local data = C_CooldownViewer.GetLayoutData()
    if not data or data == "" then return false, "No layout data to save. Set up the Cooldown Manager first." end
    local store = Store()
    if not store then return false, "Settings database is not ready yet." end
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
    if not Profiles.IsAvailable() then return false end
    local data = C_CooldownViewer.GetLayoutData()
    if not data or data == "" then return false end
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
    if not Profiles.IsAvailable() then return nil, "The Cooldown Manager layout API is not available." end
    local data = C_CooldownViewer.GetLayoutData()
    if not data or data == "" then return nil, "No layout data to export." end
    return data
end

function Profiles.ApplyLayoutData(data)
    if not data or data == "" then return false, "No layout data." end
    if not Profiles.IsAvailable() then return false, "The Cooldown Manager layout API is not available." end
    if InCombatLockdown() then return false, "Cannot change Cooldown Manager layouts during combat." end
    local previous = C_CooldownViewer.GetLayoutData()
    local ok = xpcall(C_CooldownViewer.SetLayoutData, geterrorhandler(), data)
    if not ok then
        if previous and previous ~= "" then xpcall(C_CooldownViewer.SetLayoutData, geterrorhandler(), previous) end
        return false, "Blizzard rejected that layout data."
    end
    return true
end

function Profiles.ApplySnapshot(name)
    local _, snapshot = Profiles.FindSnapshot(name)
    if not snapshot or not snapshot.data or snapshot.data == "" then return false, "Snapshot '" .. tostring(name) .. "' has no data." end
    if not Profiles.IsAvailable() then return false, "The Cooldown Manager layout API is not available." end
    if InCombatLockdown() then
        BUI.Events:AfterCombat(function()
            local ok, err = Profiles.ApplySnapshot(name)
            if ok then
                BUI.Print("Snapshot '" .. name .. "' applied. Reload (/rl) to finish.")
            elseif err then
                BUI.Print(err)
            end
        end, "CDM.ApplySnapshot")
        return false, "In combat, snapshot will apply after."
    end
    return Profiles.ApplyLayoutData(snapshot.data)
end

function Profiles.DeleteSnapshot(name)
    local index = Profiles.FindSnapshot(name)
    if not index then return false, "Snapshot not found." end
    table.remove(Profiles.GetSnapshots(), index)
    return true
end

function Profiles.ExportLayout(layoutID)
    local manager = GetLayoutManager()
    if not manager then return nil, "The layout serializer is not available." end
    local serializer = manager:GetSerializer()
    if not serializer then return nil, "The layout serializer is not available." end
    local dataOk, data = xpcall(serializer.SerializeLayouts, geterrorhandler(), serializer, layoutID)
    if not dataOk or not data or data == "" then return nil, "Could not serialize that layout." end
    return data
end

function Profiles.IsLayoutString(layoutString)
    layoutString = (layoutString or ""):gsub("^%s+", ""):gsub("%s+$", "")
    return layoutString:match("^%d+|") ~= nil, layoutString
end

function Profiles.ImportLayoutString(layoutString)
    local valid
    valid, layoutString = Profiles.IsLayoutString(layoutString)
    if not valid then return false, "That is not a Cooldown Manager layout string." end
    if InCombatLockdown() then return false, "Cannot import layouts during combat." end
    local manager = GetLayoutManager()
    if not manager then return false, "The layout manager is not available." end
    local before = {}
    for layoutID in manager:EnumerateLayouts() do before[layoutID] = true end
    local ok = xpcall(manager.CreateLayoutsFromSerializedData, geterrorhandler(), manager, layoutString)
    if not ok then return false, "Import failed. The string may be damaged or from a newer game version." end
    local added = 0
    for layoutID in manager:EnumerateLayouts() do
        if not before[layoutID] then added = added + 1 end
    end
    if added == 0 then return false, "No layouts were added. All layout slots may be in use (max 5)." end
    manager:SaveLayouts()
    return true, added
end
