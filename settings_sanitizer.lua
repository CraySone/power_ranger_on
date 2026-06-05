local SettingsSanitizer = {}

local function allowedScalar(value)
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return true end
    if kind == "number" then
        -- Reject NaN and +/-Infinity. The game serializer writes numbers with bare
        -- tostring(), so a non-finite value becomes "nan" / "1.#INF" / "-1.#IND" --
        -- none of which are valid Lua. That makes loadstring() fail on read, so the
        -- ENTIRE addon_settings file deserializes to nil and InitAddons resets every
        -- addon to {enabled=true}. Dropping the value lets defaults refill it instead.
        return value == value and value ~= math.huge and value ~= -math.huge
    end
    return false
end

local RESERVED = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,
    ["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["goto"] = true,
    ["if"] = true, ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true,
    ["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true, ["while"] = true
}

local function allowedKey(key)
    local kind = type(key)
    if kind == "number" then return true end
    if kind ~= "string" then return false end
    -- The game serializer emits string keys as bare `key = value`. A key that is not a
    -- plain Lua identifier (e.g. contains ":", "-", a space, or starts with a digit) or
    -- that is a reserved word turns the WHOLE addon_settings file into invalid Lua, so
    -- on the next read every addon resets. Drop such keys; defaults refill them.
    if RESERVED[key] then return false end
    return key:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
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
