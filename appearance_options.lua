local api = require("api")

local AppearanceOptions = {}

local DEFAULT_OFF_MODEL_COUNT = 2
local DEFAULT_ON_MODEL_COUNT = 3

local function boolValue(on)
    return on and 1 or 0
end

local function importOptionApi()
    pcall(function()
        if ADDON and ADDON.ImportAPI then
            ADDON:ImportAPI(31)
        end
    end)
end

function AppearanceOptions.ApplyDefaultAppearances(enabled)
    local on = enabled == true
    local enabledValue = boolValue(on)
    local modelCount = on and DEFAULT_ON_MODEL_COUNT or DEFAULT_OFF_MODEL_COUNT
    local applied = false

    if api and api.Option then
        local okMode = pcall(function()
            api.Option:SetCustomCloneModeSetting(enabledValue)
        end)
        local okCount = pcall(function()
            api.Option:SetCustomCloneModelCountSetting(modelCount)
        end)
        applied = okMode or okCount or applied
    end

    importOptionApi()

    local fallbackCalls = {
        function() if api and api.Option and api.Option.SetUseCustomCloneModeSetting then api.Option:SetUseCustomCloneModeSetting(enabledValue); return true end end,
        function() if api and api.Option and api.Option.SetDefaultAppearanceSetting then api.Option:SetDefaultAppearanceSetting(enabledValue); return true end end,
        function() if api and api.Option and api.Option.SetDefaultAppearancesSetting then api.Option:SetDefaultAppearancesSetting(enabledValue); return true end end,
        function() if api and api.Option and api.Option.SetDefaultPlayerAppearanceSetting then api.Option:SetDefaultPlayerAppearanceSetting(enabledValue); return true end end,
        function() if api and api.Option and api.Option.SetDefaultPlayerAppearancesSetting then api.Option:SetDefaultPlayerAppearancesSetting(enabledValue); return true end end,
        function() if api and api.Option and api.Option.SetUseDefaultPlayerAppearanceSetting then api.Option:SetUseDefaultPlayerAppearanceSetting(enabledValue); return true end end,
        function() if X2Option and X2Option.SetConsoleVariable then X2Option:SetConsoleVariable("e_custom_max_model", tostring(modelCount)); return true end end,
        function() if X2Option and X2Option.SetItemFloatValue and OIT_E_CUSTOM_CLONE_MODE then X2Option:SetItemFloatValue(OIT_E_CUSTOM_CLONE_MODE, enabledValue); return true end end
    }

    for _, fn in ipairs(fallbackCalls) do
        local ok, called = pcall(fn)
        applied = (ok and called == true) or applied
    end

    return applied
end

-- === ONLY-MY-PORTAL =========================================================================
--
-- "Only use my portal" stops you being pulled through other players' portals. Unlike the
-- appearance options above it has BOTH a getter and a setter in the addon API
-- (ADDONBRAIN api.lua:890), straight through to GetOptionItemValue/SetOptionItemValue with no
-- gate -- so there is no fallback ladder here, and no need to persist our own copy: the
-- client's value IS the state, and reading it means the button cannot drift out of sync with
-- the options window.
--
-- Returns nil when the API is unavailable, which is distinct from 0. The caller shows the
-- button as unavailable rather than as "off".
function AppearanceOptions.GetOnlyMyPortal()
    if not (api and api.Option and api.Option.GetOnlyUseMyPortalSetting) then return nil end
    local ok, value = pcall(function() return api.Option:GetOnlyUseMyPortalSetting() end)
    if not ok then return nil end
    value = tonumber(value)
    if value == nil then return nil end
    return value == 1
end

function AppearanceOptions.SetOnlyMyPortal(enabled)
    if not (api and api.Option and api.Option.SetOnlyUseMyPortalSetting) then return false end
    local ok = pcall(function()
        api.Option:SetOnlyUseMyPortalSetting(enabled and 1 or 0)
    end)
    return ok
end

return AppearanceOptions
