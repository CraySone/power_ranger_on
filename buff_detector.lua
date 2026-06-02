local api = require("api")

--[[
==========================================================================
                           BUFF DETECTOR MODULE
==========================================================================
Detects specific buffs on targets (armor sets, weapon buffs, armor tier buffs)
==========================================================================
]]

local BuffDetector = {}

-- SINGLE SOURCE OF TRUTH: All tracked buff IDs
local TRACKED_BUFF_IDS = {
    -- Cloth armor sets (incomplete + complete)
    713, 714, 16551,
    -- Leather armor sets (incomplete + complete)
    715, 716, 16552,
    -- Plate armor sets (incomplete + complete)
    717, 740, 16553,
    -- Tier buffs (all grades)
    6418, 6419, 6420, 6421, 6422, 6423, 6424,  -- Cloth (Arcane->Legendary)
    6426, 6427, 6428, 6429, 6430, 6431, 6432,  -- Leather (Arcane->Legendary)
    6434, 6435, 6436, 6437, 6438, 6439, 6440,  -- Plate (Arcane->Legendary)
    -- Weapon buffs
    16557, 8227,  -- Two Hander
    16558, 4899,  -- Dual Wield
    8226, 16559   -- Shield
}

-- Legacy categorized tables (kept for backwards compatibility)
local ARMOR_SET_BUFFS = {
    leather = {715, 716, 16552},
    cloth = {713, 714, 16551},
    plate = {717, 740, 16553}
}

local ARMOR_TIER_BUFFS = {
    arcane_cloth = {6418}, heroic_cloth = {6419}, unique_cloth = {6420},
    celestial_cloth = {6421}, divine_cloth = {6422}, epic_cloth = {6423}, legendary_cloth = {6424},
    arcane_leather = {6426}, heroic_leather = {6427}, unique_leather = {6428},
    celestial_leather = {6429}, divine_leather = {6430}, epic_leather = {6431}, legendary_leather = {6432},
    arcane_plate = {6434}, heroic_plate = {6435}, unique_plate = {6436},
    celestial_plate = {6437}, divine_plate = {6438}, epic_plate = {6439}, legendary_plate = {6440}
}

local WEAPON_BUFFS = {
    two_hander = {16557, 8227},
    dual_wield = {16558, 4899},
    shield = {8226, 16559}
}

-- Helper to check if buff ID exists in a table
local function hasBuffId(buffTable, buffId)
    for _, id in ipairs(buffTable) do
        if id == buffId then
            return true
        end
    end
    return false
end

-- Get all buffs from a unit
local function getUnitBuffs(unit)
    local buffs = {}

    -- Get regular buffs
    local buffCount = api.Unit:UnitBuffCount(unit) or 0
    for i = 1, buffCount do
        local buff = api.Unit:UnitBuff(unit, i)
        if buff then
            table.insert(buffs, buff)
        end
    end

    -- Get debuffs (in case armor buffs show as debuffs)
    local debuffCount = api.Unit:UnitDeBuffCount(unit) or 0
    for i = 1, debuffCount do
        local debuff = api.Unit:UnitDeBuff(unit, i)
        if debuff then
            table.insert(buffs, debuff)
        end
    end

    return buffs
end

-- Detect armor set type on target
function BuffDetector.getArmorSetType(unit)
    local buffs = getUnitBuffs(unit)

    for _, buff in ipairs(buffs) do
        if hasBuffId(ARMOR_SET_BUFFS.leather, buff.buff_id) then
            return "leather"
        elseif hasBuffId(ARMOR_SET_BUFFS.cloth, buff.buff_id) then
            return "cloth"
        elseif hasBuffId(ARMOR_SET_BUFFS.plate, buff.buff_id) then
            return "plate"
        end
    end

    return nil -- No complete set detected
end

-- Detect armor tier buff on target
function BuffDetector.getArmorTierBuff(unit)
    local buffs = getUnitBuffs(unit)

    for _, buff in ipairs(buffs) do
        -- Check each tier
        for tierName, buffIds in pairs(ARMOR_TIER_BUFFS) do
            if hasBuffId(buffIds, buff.buff_id) then
                return tierName -- Returns e.g. "divine_leather"
            end
        end
    end

    return nil
end

-- Detect weapon buff on target
function BuffDetector.getWeaponBuff(unit)
    local buffs = getUnitBuffs(unit)

    for _, buff in ipairs(buffs) do
        if hasBuffId(WEAPON_BUFFS, buff.buff_id) then
            return buff.buff_id
        end
    end

    return nil
end

-- Check if a buff ID is tracked
function BuffDetector.isTrackedBuff(buffId)
    for _, id in ipairs(TRACKED_BUFF_IDS) do
        if buffId == id then
            return true
        end
    end
    return false
end

-- Get ALL tracked buff objects from a unit (for UI display)
function BuffDetector.getTrackedBuffObjects(unit)
    local trackedBuffs = {}

    local buffCount = api.Unit:UnitBuffCount(unit) or 0
    for i = 1, buffCount do
        local buff = api.Unit:UnitBuff(unit, i)
        if buff and BuffDetector.isTrackedBuff(buff.buff_id) then
            table.insert(trackedBuffs, buff)
        end
    end

    return trackedBuffs
end

-- Get tracked buff info (legacy - for backwards compatibility)
function BuffDetector.getTrackedBuffs(unit)
    return {
        armorSet = BuffDetector.getArmorSetType(unit),
        armorTier = BuffDetector.getArmorTierBuff(unit),
        weapon = BuffDetector.getWeaponBuff(unit)
    }
end

-- Helper: Print all buffs on a unit (for discovering buff IDs)
function BuffDetector.debugPrintBuffs(unit)
    local buffs = getUnitBuffs(unit)
    api.Log:Info("=== BUFFS ON " .. unit .. " ===")
    for i, buff in ipairs(buffs) do
        api.Log:Info(string.format("[%d] ID=%s, Name=%s, Stacks=%s",
            i, tostring(buff.buff_id), tostring(buff.name), tostring(buff.stack)))
    end
end

return BuffDetector
