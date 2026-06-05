local SettingsProfile = {}

local META_KEYS = {
    characterProfiles = true,
    activeProfileKey = true,
    activeProfileName = true,
    characterProfilesVersion = true,
    useAccountWideSettings = true
}

local function safeCall(fn)
    local ok, a = pcall(fn)
    if ok then return a end
    return nil
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function copyTable(value, depth, seen)
    local kind = type(value)
    if kind ~= "table" then
        if kind == "string" or kind == "number" or kind == "boolean" then return value end
        return nil
    end
    depth = depth or 0
    if depth > 8 then return nil end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local out = {}
    for k, v in pairs(value) do
        if type(k) == "string" or type(k) == "number" then
            local copied = copyTable(v, depth + 1, seen)
            if copied ~= nil then out[k] = copied end
        end
    end
    seen[value] = nil
    return out
end

local function textField(tbl, keys)
    if type(tbl) ~= "table" then return nil end
    for _, key in ipairs(keys or {}) do
        local value = tbl[key]
        if value ~= nil and trim(value) ~= "" then return trim(value) end
    end
    return nil
end

function SettingsProfile.PlayerName(api)
    local info = safeCall(function() return api.Unit:UnitInfo("player") end)
    local name = textField(info, {"name", "unitName", "unit_name"})
    if name then return name end
    name = safeCall(function() return api.Unit:UnitName("player") end)
    if name and trim(name) ~= "" then return trim(name) end
    local id = safeCall(function() return api.Unit:GetUnitId("player") end)
    name = id and safeCall(function() return api.Unit:GetUnitNameById(id) end)
    if name and trim(name) ~= "" then return trim(name) end
    return nil
end

function SettingsProfile.PlayerKey(api)
    local name = SettingsProfile.PlayerName(api)
    if not name or name == "" then return "__unknown__", nil end
    -- The game settings serializer writes table keys as a bare `key = value` with no
    -- brackets or quotes, so a profile key MUST be a valid Lua identifier. The old
    -- "char:Name" format put a colon in the KEY, which made the entire addon_settings
    -- file fail to deserialize and reset every addon on reload. Coerce to a safe key.
    local safe = tostring(name):gsub("[^%w_]", "_")
    return "char_" .. safe, name
end

local function seedFromAccountRoot(root)
    local profile = {}
    if type(root) ~= "table" then return profile end
    for key, value in pairs(root) do
        if not META_KEYS[key] then
            local copied = copyTable(value)
            if copied ~= nil then profile[key] = copied end
        end
    end
    return profile
end

function SettingsProfile.Resolve(api, root)
    if type(root) ~= "table" then root = {} end
    if root.useAccountWideSettings == true then
        root.activeProfileKey = "__account__"
        root.activeProfileName = "Account-wide"
        return root, "__account__", "Account-wide", root
    end

    if type(root.characterProfiles) ~= "table" then root.characterProfiles = {} end
    local key, name = SettingsProfile.PlayerKey(api)
    local profile = root.characterProfiles[key]
    if type(profile) ~= "table" then
        profile = seedFromAccountRoot(root)
        root.characterProfiles[key] = profile
    end

    profile.profileKey = key
    profile.profileName = name or "Unknown"
    root.activeProfileKey = key
    root.activeProfileName = profile.profileName
    root.characterProfilesVersion = 1
    return profile, key, profile.profileName, root
end

return SettingsProfile
