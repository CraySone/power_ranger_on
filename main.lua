local api = require("api")
local TargetOverlay = require("power_ranger_on/target_overlay")
local HotSwap = require("power_ranger_on/hot_swap")
local michaelClientLib = require("power_ranger_on/michael_client")

local power_ranger_on = {
    name = "Power Ranger ON",
    author = "CraySone",
    desc = "PvP Overlay and self tracking",
    version = "1.4.5"
}

local active = false
local updateRegistered = false

local function OnUpdate(dt)
    if not active then return end
    TargetOverlay.update(dt)
    HotSwap.update(dt)
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
    if not updateRegistered then
        api.On("UPDATE", OnUpdate)
        updateRegistered = true
    end
end

local function Unload()
    active = false
    pcall(function() michaelClientLib.OnUnload() end)
    HotSwap.cleanup()
    TargetOverlay.cleanup()
end

power_ranger_on.OnLoad = Load
power_ranger_on.OnUnload = Unload
power_ranger_on.OnSettingToggle = TargetOverlay.openSettings

return power_ranger_on
