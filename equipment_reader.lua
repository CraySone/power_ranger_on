local api = require("api")
local OverlayUtils = require("power_ranger_on/overlay_utils")
local CooldownRecipes = require("power_ranger_on/cooldown_recipes")

local EquipmentReader = {}

local MOUNT_SYMBOLS = {
    ["abysswraith kirin"] = "Game\\ui\\icon\\icon_skill_karon01.dds",
    ["stormwraith kirin"] = "Game\\ui\\icon\\icon_skill_karon01.dds"
}

local MOUNT_UNITS = {"playerpet", "playerpet1", "playerpet2", "slave"}
local bagDeviceCache = { name = nil, time = 0, result = nil }

local function activePetUnit()
    for _, unit in ipairs(MOUNT_UNITS) do
        local uid = OverlayUtils.safeCall(function() return api.Unit:GetUnitId(unit) end)
        if uid and uid ~= 0 then return unit, uid end
    end
    return nil, nil
end

local function normalizedDeviceName(value)
    local text = string.lower(tostring(value or ""))
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("^wrapped%s+", "")
    text = text:gsub("^summon%s+", "")
    text = text:gsub("%s+", " ")
    return text
end

local function deviceNamesMatch(itemName, deviceName)
    itemName = normalizedDeviceName(itemName)
    deviceName = normalizedDeviceName(deviceName)
    if itemName == "" or deviceName == "" then return false end
    return itemName:find(deviceName, 1, true) ~= nil or deviceName:find(itemName, 1, true) ~= nil
end

local function findBagDeviceByName(deviceName)
    if not deviceName or deviceName == "" then return nil end
    local now = OverlayUtils.safeCall(function() return api.Time:GetUiMsec() end) or 0
    local cacheName = normalizedDeviceName(deviceName)
    if bagDeviceCache.name == cacheName and now - (bagDeviceCache.time or 0) < 2000 then
        return bagDeviceCache.result
    end
    bagDeviceCache.name = cacheName
    bagDeviceCache.time = now
    bagDeviceCache.result = nil

    local capacity = OverlayUtils.safeCall(function() return api.Bag:Capacity() end) or 0
    for i = 1, tonumber(capacity) or 0 do
        local item = OverlayUtils.safeCall(function() return api.Bag:GetBagItemInfo(1, i) end)
        local itemName = OverlayUtils.itemName(item)
        if deviceNamesMatch(itemName, deviceName) then
            bagDeviceCache.result = {
                name = itemName,
                icon = OverlayUtils.iconPath(item),
                itemType = CooldownRecipes.ExtractItemType(item)
            }
            return bagDeviceCache.result
        end
    end
    return nil
end

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
    local unit, uid = activePetUnit()
    local info = unit and (OverlayUtils.safeCall(function() return api.Unit:UnitInfo(unit) end) or {}) or {}
    local idInfo = uid and (OverlayUtils.safeCall(function() return api.Unit:GetUnitInfoById(uid) end) or {}) or {}
    local name = OverlayUtils.textField(info, {
        "mate_npc_name", "mateNpcName", "mateName", "mate_name",
        "npc_name", "npcName", "slave_name", "slaveName",
        "name", "unitName", "unit_name", "unitNameText"
    })
    if not name or name == "" then
        name = OverlayUtils.textField(idInfo, {
            "mate_npc_name", "mateNpcName", "mateName", "mate_name",
            "npc_name", "npcName", "slave_name", "slaveName",
            "name", "unitName", "unit_name", "unitNameText"
        })
    end
    if (not name or name == "") and uid then
        name = OverlayUtils.safeCall(function() return api.Unit:GetUnitNameById(uid) end)
    end
    local key = string.lower(tostring(name or ""))
    local icon = OverlayUtils.iconPath(info) or OverlayUtils.iconPath(idInfo) or MOUNT_SYMBOLS[key]
    local itemType = CooldownRecipes.ExtractItemType(info, idInfo)
    if name and (not icon or not itemType) then
        local bagItem = findBagDeviceByName(name)
        if bagItem then
            icon = icon or bagItem.icon
            itemType = itemType or bagItem.itemType
        end
    end
    return {
        name = name,
        unit = unit,
        id = uid,
        icon = icon,
        itemType = itemType
    }
end

function EquipmentReader.DeviceMatches(row, glider)
    local matched = CooldownRecipes.DeviceMatches(row, glider)
    if matched ~= nil then return matched end
    return true
end

return EquipmentReader
