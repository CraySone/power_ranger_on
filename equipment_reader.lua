local api = require("api")
local OverlayUtils = require("power_ranger_on/overlay_utils")
local CooldownRecipes = require("power_ranger_on/cooldown_recipes")

local EquipmentReader = {}

local MOUNT_SYMBOLS = {
    ["abysswraith kirin"] = "Game\\ui\\icon\\icon_skill_karon01.dds",
    ["stormwraith kirin"] = "Game\\ui\\icon\\icon_skill_karon01.dds"
}

function EquipmentReader.Snapshot(slot)
    if not slot then return nil end
    local info = OverlayUtils.safeCall(function() return api.Equipment:GetEquippedItemTooltipInfo(slot) end)
    local textInfo = OverlayUtils.safeCall(function() return api.Equipment:GetEquippedItemTooltipText("player", slot) end)
    return {
        name = OverlayUtils.itemName(info) or OverlayUtils.itemName(textInfo),
        icon = OverlayUtils.iconPath(info) or OverlayUtils.iconPath(textInfo),
        itemType = CooldownRecipes.ExtractItemType(info, textInfo)
    }
end

function EquipmentReader.GliderSlot()
    if not EQUIP_SLOT then return nil end
    if EQUIP_SLOT.GLIDER then return EQUIP_SLOT.GLIDER end
    if EQUIP_SLOT.BACKPACK then return EQUIP_SLOT.BACKPACK end
    if EQUIP_SLOT.MUSICAL then return tonumber(EQUIP_SLOT.MUSICAL) and (EQUIP_SLOT.MUSICAL + 1) or nil end
    return nil
end

function EquipmentReader.GliderSnapshot()
    return EquipmentReader.Snapshot(EquipmentReader.GliderSlot()) or {}
end

function EquipmentReader.MountedPetSnapshot()
    local info = OverlayUtils.safeCall(function() return api.Unit:UnitInfo("playerpet") end) or {}
    local name = OverlayUtils.textField(info, {"mate_npc_name", "mateNpcName", "name", "unitName", "unit_name"})
    local key = string.lower(tostring(name or ""))
    return {
        name = name,
        icon = OverlayUtils.iconPath(info) or MOUNT_SYMBOLS[key]
    }
end

function EquipmentReader.DeviceMatches(row, glider)
    local matched = CooldownRecipes.DeviceMatches(row, glider)
    if matched ~= nil then return matched end
    return true
end

return EquipmentReader
