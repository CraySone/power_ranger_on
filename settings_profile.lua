local SettingsProfile = {}

local META_KEYS = {
    characterProfiles = true,
    activeProfileKey = true,
    activeProfileName = true,
    characterProfilesVersion = true,
    useAccountWideSettings = true,
    legacySettingsBackup = true,
    recoveryProfiles = true,
    hotSwapGearSetsBackup = true,
    hotSwapBackups = true
}

local PROFILE_VERSION = 2

local function safeCall(fn)
    local ok, a = pcall(fn)
    if ok then return a end
    return nil
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function copyTable(value, seen)
    local kind = type(value)
    if kind ~= "table" then
        if kind == "string" or kind == "number" or kind == "boolean" then return value end
        return nil
    end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local out = {}
    for k, v in pairs(value) do
        if type(k) == "string" or type(k) == "number" then
            local copied = copyTable(v, seen)
            if copied ~= nil then out[k] = copied end
        end
    end
    seen[value] = nil
    return out
end

local function tablesEqual(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do
        if not tablesEqual(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
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

local function tableCount(tbl)
    local count = 0
    if type(tbl) == "table" then
        for _ in pairs(tbl) do count = count + 1 end
    end
    return count
end

local function hasLegacyPayload(root)
    if type(root) ~= "table" then return false end
    for key, value in pairs(root) do
        if not META_KEYS[key] and key ~= "enabled" then
            if type(value) == "table" and tableCount(value) > 0 then return true end
            if type(value) ~= "table" and value ~= nil then return true end
        end
    end
    return false
end

local function hotSwapGearSetCount(root)
    if type(root) ~= "table" then return 0 end
    local hotSwap = root.hotSwap
    local gearSets = type(hotSwap) == "table" and hotSwap.gear_sets or nil
    if type(gearSets) ~= "table" then return 0 end
    return #gearSets
end

local function legacyScore(root)
    if not hasLegacyPayload(root) then return 0 end
    return (hotSwapGearSetCount(root) * 1000) + tableCount(root)
end

local function legacySource(root)
    if type(root) ~= "table" then return {} end
    local flat = seedFromAccountRoot(root)
    local backup = type(root.legacySettingsBackup) == "table" and root.legacySettingsBackup or nil
    if legacyScore(flat) > legacyScore(backup) then
        return flat
    end
    if backup and hasLegacyPayload(backup) then
        return backup
    end
    return flat
end

local function verifiedCopy(source)
    local copied = copyTable(source)
    if type(copied) ~= "table" or not tablesEqual(source, copied) then return nil end
    return copied
end

local function mergeLegacyIntoProfile(profile, legacy)
    if type(profile) ~= "table" or type(legacy) ~= "table" then return false end
    local changed = false
    for key, value in pairs(legacy) do
        if not META_KEYS[key] then
            local copied = copyTable(value)
            if copied ~= nil then
                profile[key] = copied
                changed = true
            end
        end
    end
    return changed
end

function SettingsProfile.Resolve(api, root)
    if type(root) ~= "table" then root = {} end
    if root.useAccountWideSettings == true then
        root.activeProfileKey = "__account__"
        root.activeProfileName = "Account-wide"
        return root, "__account__", "Account-wide", root
    end

    local key, name = SettingsProfile.PlayerKey(api)
    if key == "__unknown__" then
        return root, "__pending__", "Pending character", root, {
            pending = true,
            migrated = false,
            verified = false
        }
    end

    local hadProfiles = type(root.characterProfiles) == "table"
    local version = tonumber(root.characterProfilesVersion) or 0
    local source = legacySource(root)
    if legacyScore(source) > legacyScore(root.legacySettingsBackup) then
        local backup = verifiedCopy(source)
        if backup == nil then
            return root, "__migration_failed__", name or "Unknown", root, {
                pending = false,
                migrated = false,
                verified = false,
                error = "legacy backup verification failed"
            }
        end
        root.legacySettingsBackup = backup
    end
    if not hadProfiles then
        root.characterProfiles = {}
    end

    local profile = root.characterProfiles[key]
    local existingProfile = type(profile) == "table"
    if type(profile) ~= "table" then
        profile = verifiedCopy(source)
        if profile == nil then
            return root, "__migration_failed__", name or "Unknown", root, {
                pending = false,
                migrated = false,
                verified = false,
                error = "profile copy verification failed"
            }
        end
        root.characterProfiles[key] = profile
    elseif version < PROFILE_VERSION and type(root.legacySettingsBackup) == "table" then
        if type(root.recoveryProfiles) ~= "table" then root.recoveryProfiles = {} end
        if type(root.recoveryProfiles[key]) ~= "table" then
            root.recoveryProfiles[key] = verifiedCopy(profile) or {}
        end
        mergeLegacyIntoProfile(profile, source)
    end

    profile.profileKey = key
    profile.profileName = name or "Unknown"
    root.activeProfileKey = key
    root.activeProfileName = profile.profileName
    root.characterProfilesVersion = PROFILE_VERSION
    return profile, key, profile.profileName, root, {
        pending = false,
        migrated = not hadProfiles or not existingProfile or version < PROFILE_VERSION,
        verified = true
    }
end

return SettingsProfile
