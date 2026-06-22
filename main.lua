local api = require("api")
local TargetOverlay = require("power_ranger_on/target_overlay")
local HotSwap = require("power_ranger_on/hot_swap")
local michaelClientLib = require("power_ranger_on/michael_client")

local power_ranger_on = {
    name = "Power Ranger ON",
    author = "CraySone",
    desc = "PvP self tracking and gear tools",
    version = "1.5.5"
}

local active = false
local updateFrame = nil
local lastUpdateErrorLog = 0

local function OnUpdate(dt)
    if not active then return end
    TargetOverlay.update(dt)
    HotSwap.update(dt)
end

local function OnWidgetUpdate(self, dt)
    local ok, err = pcall(OnUpdate, dt or 0)
    if not ok then
        local now = api.Time:GetUiMsec()
        if now - lastUpdateErrorLog > 5000 then
            lastUpdateErrorLog = now
            api.Log:Error("[Power Ranger ON] update failed: " .. tostring(err))
        end
    end
end

local function StartUpdateDriver()
    if updateFrame then return end
    -- Post-2026-06-18 API behavior can throttle api.On("UPDATE") to about 1fps
    -- while a target is held. A shown 1x1 widget keeps UI-driven updates full-speed.
    updateFrame = api.Interface:CreateEmptyWindow("powerRangerOnUpdate")
    updateFrame:SetExtent(1, 1)
    updateFrame:AddAnchor("TOPLEFT", "UIParent", "TOPLEFT", 0, 0)
    updateFrame:Show(true)
    updateFrame:SetHandler("OnUpdate", OnWidgetUpdate)
end

local function StopUpdateDriver()
    if not updateFrame then return end
    updateFrame:SetHandler("OnUpdate", function() return end)
    updateFrame:Show(false)
    updateFrame = nil
end

local function Load()
    if active then return end
    active = true
    TargetOverlay.init()
    local activeSettings = TargetOverlay.getActiveSettings()
    if activeSettings then
        HotSwap.init(activeSettings, TargetOverlay.saveActiveSettings, TargetOverlay.getSettingsRoot, TargetOverlay.getActiveProfileKey)
    end
    pcall(function()
        michaelClientLib:initializeMichaelClient()
        local configMenu = ADDON:GetContent(UIC.SYSTEM_CONFIG_FRAME)
        if configMenu and configMenu.michaelClient and configMenu.michaelClient.AddAddon then
            configMenu.michaelClient:AddAddon("Power Ranger ON", function()
                TargetOverlay.openSettings()
            end)
        end
    end)
    StartUpdateDriver()
end

local function Unload()
    active = false
    StopUpdateDriver()
    pcall(function() michaelClientLib.OnUnload() end)
    HotSwap.cleanup()
    TargetOverlay.cleanup()
end

power_ranger_on.OnLoad = Load
power_ranger_on.OnUnload = Unload
power_ranger_on.OnSettingToggle = TargetOverlay.openSettings

return power_ranger_on
