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

return AppearanceOptions
