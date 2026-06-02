local api = require("api")

local Compat = {}

local MODE_AUTO = "auto"
local MODE_ON = "on"
local MODE_OFF = "off"
local NUZI_SETTINGS_PATHS = {
    "nuzi-ui/.data/settings.txt",
    "nuzi-ui/settings.txt"
}
local LEGACY_SETTINGS_PATHS = {
    "polar-ui/settings.txt",
    "polar-ui/.data/settings.txt"
}

local function normalizeMode(value)
    value = string.lower(tostring(value or ""))
    if value == MODE_ON or value == "enabled" or value == "force" then
        return MODE_ON
    end
    if value == MODE_OFF or value == "disabled" or value == "none" then
        return MODE_OFF
    end
    return MODE_AUTO
end

local function hasAnyKey(value)
    if type(value) ~= "table" then return false end
    for _ in pairs(value) do
        return true
    end
    return false
end

local function readAddonSettings(addonId)
    if type(api.GetSettings) ~= "function" then return nil end
    local value = api.GetSettings(addonId)
    if type(value) == "table" then
        return value
    end
    return nil
end

local function readSettingsFile(path)
    if type(api.File) ~= "table" or type(api.File.Read) ~= "function" then return nil end
    local ok, value = pcall(function() return api.File:Read(path) end)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

local function looksLikeNuziUiSettings(value)
    if type(value) ~= "table" or not hasAnyKey(value) then return false end
    if value.enabled == false then return false end
    if value.enabled == true then return true end
    return type(value.cooldown_tracker) == "table"
        or type(value.mount_glider) == "table"
        or type(value.nameplates) == "table"
        or type(value.style) == "table"
        or type(value.settings_button) == "table"
        or type(value.cast_bar) == "table"
        or type(value.crowd_control) == "table"
        or type(value.quest_watch) == "table"
end

local function detectSettingsFile(paths, label)
    for _, path in ipairs(paths or {}) do
        local value = readSettingsFile(path)
        if type(value) == "table" and hasAnyKey(value) then
            if value.enabled == false then
                return false, label .. " disabled"
            end
            if looksLikeNuziUiSettings(value) then
                return true, label .. " settings file detected"
            end
        end
    end
    return nil, ""
end

local function detectNuziUi()
    local detected, reason = detectSettingsFile(NUZI_SETTINGS_PATHS, "nuzi-ui")
    if detected ~= nil then
        return detected, reason
    end
    detected, reason = detectSettingsFile(LEGACY_SETTINGS_PATHS, "polar-ui")
    if detected ~= nil then
        return detected, reason
    end
    if looksLikeNuziUiSettings(readAddonSettings("nuzi-ui")) then
        return true, "nuzi-ui settings detected"
    end
    if looksLikeNuziUiSettings(readAddonSettings("polar-ui")) then
        return true, "polar-ui settings detected"
    end
    return false, "no nuzi-ui settings detected"
end

function Compat.Resolve(settings)
    local mode = normalizeMode(type(settings) == "table" and settings.nuziUiCompatMode or nil)
    local detected, detectedReason = detectNuziUi()
    local active = false
    local reason = detectedReason

    if mode == MODE_OFF then
        reason = detected and "compat off" or detectedReason
    elseif mode == MODE_ON and detected then
        active = true
        reason = "forced on"
    elseif mode == MODE_AUTO and detected then
        active = true
        reason = detectedReason
    end

    return {
        mode = mode,
        active = active,
        detected = detected,
        reason = reason,
        hideTargetText = active,
        hideTargetInfoWindow = active,
        hideSelfPanel = active
    }
end

function Compat.NextMode(mode)
    mode = normalizeMode(mode)
    if mode == MODE_AUTO then return MODE_ON end
    if mode == MODE_ON then return MODE_OFF end
    return MODE_AUTO
end

function Compat.ModeLabel(state)
    local mode = normalizeMode(type(state) == "table" and state.mode or state)
    if mode == MODE_ON then return "Compat On" end
    if mode == MODE_OFF then return "Compat Off" end
    return "Compat Auto"
end

function Compat.ShouldShowOptions(state)
    return type(state) == "table" and state.detected == true
end

function Compat.ShouldHideTargetInfoWindow(state, ownershipOnly)
    return type(state) == "table" and state.hideTargetInfoWindow == true and ownershipOnly ~= true
end

function Compat.ShouldHideTargetText(state)
    return type(state) == "table" and state.hideTargetText == true
end

function Compat.ShouldHideSelfPanel(state)
    return type(state) == "table" and state.hideSelfPanel == true
end

return Compat
