-- Private, crash-resilient settings persistence for Power Ranger ON.
--
-- Why this exists:
--  1. The shared `addon_settings` file is a single point of failure: one bad value from
--     ANY addon makes the whole file unreadable and resets every addon. By owning a
--     private file we stop writing the shared file entirely, so we can never be the
--     cause, and we self-recover (from our private file/backup) even when another addon
--     or a crash mid-write resets the shared file -- we are no longer a victim either.
--  2. The client serializer renders numbers with ~6 significant figures, so any integer
--     >= 100000 (every 7+ digit buff/item id) is ROUNDED on save (8000138 -> 8000140).
--     We encode large integers as "__n__<digits>" strings before writing and decode them
--     after reading so ids survive the round-trip exactly. (Same approach ezcd/nuzi use.)
--
-- The framework still owns the addon's `enabled` flag in the shared file; everything
-- else (profiles, tracked buffs, hot swap, ...) lives in our private file.

local api = require("api")
local SettingsSanitizer = require("power_ranger_on/settings_sanitizer")

local Store = {}

local INT_THRESHOLD = 100000
local INT_PREFIX = "__n__"
local INT_PREFIX_LEN = #INT_PREFIX
-- Primary lives in data/ -- deliberately NOT a dot-folder: addon managers/updaters
-- filter dot-entries when installing (to skip .git etc.), so a ".data" folder never
-- reached manager users, and the game's File:Write does io.open(path, "w") with NO
-- directory creation, so the addon could not create it either. data/ ships with a
-- plain readme.txt so extractors cannot treat it as empty. The legacy .data paths
-- stay readable for git users who already have settings there; the root-level
-- fallbacks cover installs where even data/ is missing.
local SETTINGS_PATH = "power_ranger_on/data/settings.lua"
local BACKUP_PATH = "power_ranger_on/data/settings_backup.lua"
local LEGACY_SETTINGS_PATH = "power_ranger_on/.data/settings.lua"
local LEGACY_BACKUP_PATH = "power_ranger_on/.data/settings_backup.lua"
local FALLBACK_SETTINGS_PATH = "power_ranger_on/settings_data.lua"
local FALLBACK_BACKUP_PATH = "power_ranger_on/settings_data_backup.lua"

local state = { addonId = nil, root = nil }

local function logInfo(message)
    if api.Log and api.Log.Info then
        pcall(function() api.Log:Info("[PowerRangerON] " .. tostring(message)) end)
    end
end

local function logError(message)
    if api.Log and api.Log.Err then
        pcall(function() api.Log:Err("[PowerRangerON] " .. tostring(message)) end)
    else
        logInfo("ERROR: " .. tostring(message))
    end
end

-- Deep copy + encode large integers as strings. Returns a NEW table; the live settings
-- keep their real numbers in memory.
local function encodeInts(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local out = {}
    for k, v in pairs(value) do
        local tv = type(v)
        if tv == "number" and math.floor(v) == v and (v >= INT_THRESHOLD or v <= -INT_THRESHOLD) then
            out[k] = INT_PREFIX .. string.format("%d", v)
        elseif tv == "table" then
            out[k] = encodeInts(v, seen)
        else
            out[k] = v
        end
    end
    seen[value] = nil
    return out
end

-- Decode "__n__<digits>" strings back to numbers, in place.
local function decodeInts(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return value end
    seen[value] = true
    for k, v in pairs(value) do
        if type(v) == "string" and v:sub(1, INT_PREFIX_LEN) == INT_PREFIX then
            value[k] = tonumber(v:sub(INT_PREFIX_LEN + 1)) or v
        elseif type(v) == "table" then
            decodeInts(v, seen)
        end
    end
    seen[value] = nil
    return value
end

local function safeRead(path)
    local ok, data = pcall(function() return api.File:Read(path) end)
    if ok and type(data) == "table" then return data end
    return nil
end

local function safeWrite(path, tbl)
    local ok = pcall(function() api.File:Write(path, tbl) end)
    return ok == true
end

-- A reset/default branch carries nothing but the framework `enabled` flag.
local function looksEmpty(root)
    if type(root) ~= "table" then return true end
    for k in pairs(root) do
        if k ~= "enabled" then return false end
    end
    return true
end

-- Replace globalRoot's contents (except the framework `enabled` flag) with source.
local function overlay(globalRoot, source)
    local enabled = globalRoot.enabled
    for k in pairs(globalRoot) do globalRoot[k] = nil end
    for k, v in pairs(source) do
        if k ~= "enabled" then globalRoot[k] = v end
    end
    if enabled ~= nil then globalRoot.enabled = enabled end
end

-- Load our settings. The private file (then fallback, then backups) is the source of
-- truth for our rich data; on first run (none exist) we migrate the shared branch as-is.
function Store.Load(addonId)
    state.addonId = addonId
    local globalRoot = api.GetSettings(addonId) or {}
    local private = nil
    local source = "shared (first run / migration)"
    for _, candidate in ipairs({
        { path = SETTINGS_PATH, label = "private" },
        { path = LEGACY_SETTINGS_PATH, label = "private (legacy .data)" },
        { path = FALLBACK_SETTINGS_PATH, label = "private (root fallback)" },
        { path = BACKUP_PATH, label = "backup" },
        { path = LEGACY_BACKUP_PATH, label = "backup (legacy .data)" },
        { path = FALLBACK_BACKUP_PATH, label = "backup (root fallback)" }
    }) do
        local data = safeRead(candidate.path)
        if data and not looksEmpty(data) then
            private = data
            source = candidate.label
            break
        end
    end
    if private then
        decodeInts(private)
        overlay(globalRoot, private)
    end
    logInfo("settings loaded from " .. source)
    state.root = globalRoot
    return globalRoot
end

function Store.SetRoot(root)
    if type(root) == "table" then state.root = root end
end

-- Persist to the private file (+ backup mirror). Sanitizes first so a stray bad value
-- can't break our file, then encodes large ids so they survive the serializer.
-- NEVER fails silently: if .data/ is missing we fall back to addon-root files, and if
-- even those fail we fall back to the old shared api.SaveSettings() path (sanitized,
-- so it cannot corrupt the shared file) rather than lose the user's data.
function Store.Save()
    local root = state.root
    if type(root) ~= "table" then return false end
    SettingsSanitizer.Clean(root)
    local encoded = encodeInts(root)
    if safeWrite(SETTINGS_PATH, encoded) then
        safeWrite(BACKUP_PATH, encoded)
        return true
    end
    if safeWrite(LEGACY_SETTINGS_PATH, encoded) then
        safeWrite(LEGACY_BACKUP_PATH, encoded)
        logInfo("settings saved to legacy .data folder (the data folder is missing)")
        return true
    end
    if safeWrite(FALLBACK_SETTINGS_PATH, encoded) then
        safeWrite(FALLBACK_BACKUP_PATH, encoded)
        logInfo("settings saved to root fallback (no data folder present)")
        return true
    end
    logError("private settings save FAILED on all paths; falling back to shared addon_settings")
    local ok = pcall(function() api.SaveSettings() end)
    return ok == true
end

return Store
