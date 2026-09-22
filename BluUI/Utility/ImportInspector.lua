local _, BUI = ...

local ImportInspector = {}
BUI.ImportInspector = ImportInspector

local sort, concat, format = table.sort, table.concat, string.format
local floor = math.floor

local function FormatValue(value)
    local kind = type(value)
    if kind == "string" then return '"' .. value .. '"' end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then
        if value == floor(value) then return tostring(floor(value)) end
        return format("%.4g", value)
    end
    return tostring(value)
end

local function KeyOrder(keyA, keyB)
    local typeA, typeB = type(keyA), type(keyB)
    if typeA ~= typeB then return typeA == "number" end
    return keyA < keyB
end

local function Flatten(value, path, lines)
    if type(value) ~= "table" then
        lines[#lines + 1] = path .. " = " .. FormatValue(value)
        return
    end

    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    if #keys == 0 then
        lines[#lines + 1] = path .. " = {}"
        return
    end

    sort(keys, KeyOrder)
    for _, key in ipairs(keys) do
        local childPath
        if type(key) == "number" then
            childPath = path .. "[" .. key .. "]"
        elseif path == "" then
            childPath = key
        else
            childPath = path .. "." .. key
        end
        Flatten(value[key], childPath, lines)
    end
end

function ImportInspector.Inspect(importString)
    if not importString or importString:match("^%s*$") then
        return nil, "Paste an export string first."
    end

    local data, errorMessage = BUI.ExportImport.DecodeImportString(importString)
    if not data then
        return nil, errorMessage or "Could not decode string."
    end

    local sections = {}
    for key in pairs(data) do
        if type(key) == "string" and not key:match("^_") then
            sections[#sections + 1] = key
        end
    end
    sort(sections)

    local lines = {}
    for _, section in ipairs(sections) do
        Flatten(data[section], section, lines)
    end
    sort(lines)

    local result = BUI.ExportImport.ClassifyData(data)
    local unknown, deprecated = result.unknown, result.deprecated

    local output = {
        "Profile: " .. tostring(data._profileName or "?") .. "    Version: " .. tostring(data._version or "?"),
        format("Settings: %d    Unknown to this version: %d    Deprecated: %d", #lines, #unknown, #deprecated),
        "",
    }

    if #unknown > 0 then
        output[#output + 1] = "|cffffaa00Unrecognised keys:|r"
        for unknownIndex = 1, #unknown do output[#output + 1] = "  |cffffaa00-|r " .. unknown[unknownIndex] end
        output[#output + 1] = ""
    else
        output[#output + 1] = "|cff00cc66All keys recognised.|r"
        output[#output + 1] = ""
    end

    if #deprecated > 0 then
        output[#output + 1] = "|cffff4444Deprecated:|r " .. #deprecated
        for deprecatedIndex = 1, #deprecated do output[#output + 1] = "  |cffff4444-|r " .. deprecated[deprecatedIndex] end
        output[#output + 1] = ""
    end

    output[#output + 1] = "|cff888888All settings:|r"
    if #lines == 0 then
        output[#output + 1] = "(all defaults)"
    else
        for lineIndex = 1, #lines do output[#output + 1] = lines[lineIndex] end
    end

    return concat(output, "\n"), nil
end
