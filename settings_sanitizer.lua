local SettingsSanitizer = {}

local function allowedScalar(value)
    local kind = type(value)
    return kind == "string" or kind == "number" or kind == "boolean"
end

local function allowedKey(key)
    local kind = type(key)
    return kind == "string" or kind == "number"
end

local function sanitizeTable(tbl, depth, seen)
    if type(tbl) ~= "table" then return end
    if depth > 10 then return end
    if seen[tbl] then return end
    seen[tbl] = true
    for key, value in pairs(tbl) do
        if not allowedKey(key) then
            tbl[key] = nil
        elseif type(value) == "table" then
            if depth >= 10 or seen[value] then
                tbl[key] = nil
            else
                sanitizeTable(value, depth + 1, seen)
            end
        elseif value == nil or allowedScalar(value) then
            -- keep serializable values
        else
            tbl[key] = nil
        end
    end
    seen[tbl] = nil
end

function SettingsSanitizer.Clean(root)
    if type(root) ~= "table" then return root end
    sanitizeTable(root, 0, {})
    return root
end

return SettingsSanitizer
