local api = require("api")
local RoleHelper = require("power_ranger_on/role_helper")

local TargetReader = {}

function TargetReader.GetDistance(safeCall, token)
    local d = tonumber(safeCall(function() return api.Unit:UnitDistance(token) end))
    if not d then return nil end
    return math.floor(d + 0.5)
end

function TargetReader.GetInfoById(safeCall, targetId)
    if not targetId then return nil end
    return safeCall(function() return api.Unit:GetUnitInfoById(targetId) end)
end

function TargetReader.IsCharacter(info, gearscore)
    if not info then return (tonumber(gearscore) or 0) > 0 end
    if info.type == "character" or info.type == "player" then return true end
    if info.type ~= nil and info.type ~= "" then return false end
    return (tonumber(gearscore) or 0) > 0
end

function TargetReader.IsPlayer(info)
    return info and (info.type == "character" or info.type == "player") or false
end

function TargetReader.OwnershipField(textField, info, keys)
    local value = textField(info, keys)
    if not value then return nil end
    local upper = string.upper(tostring(value))
    if upper == "NO FAMILY" or upper == "UNKNOWN" or upper == "NONE" or upper == "NIL" then return nil end
    return value
end

function TargetReader.HasOwnershipFields(textField, info)
    return TargetReader.OwnershipField(textField, info, {"expeditionName", "expedition", "guildName", "guild"})
        or TargetReader.OwnershipField(textField, info, {"family_name", "familyName", "family"})
        or TargetReader.OwnershipField(textField, info, {"owner_name", "ownerName", "owner", "portal_owner", "portalOwner"})
end

function TargetReader.IsOwnership(textField, info)
    if not info or TargetReader.IsPlayer(info) then return false end
    local typeText = string.lower(tostring(info.type or info.unitType or info.unit_type or info.category or info.kind or info.objectType or info.object_type or ""))
    local nameText = string.lower(tostring(info.name or info.unitName or info.unit_name or info.landType or info.house_category or ""))
    local hasInfo = TargetReader.HasOwnershipFields(textField, info)
    if hasInfo and (info.is_portal or info.isPortal) then return true end
    if hasInfo and typeText ~= "npc" and typeText ~= "monster" then return true end
    if typeText:find("monster", 1, true) or typeText:find("npc", 1, true) or typeText:find("character", 1, true) then
        return false
    end
    if typeText == "" then return hasInfo ~= nil end
    if typeText:find("house", 1, true) or typeText:find("housing", 1, true) or typeText:find("building", 1, true)
        or typeText:find("land", 1, true) or typeText:find("property", 1, true)
        or typeText:find("vehicle", 1, true) or typeText:find("ship", 1, true) or typeText:find("boat", 1, true)
        or typeText:find("mount", 1, true) or typeText:find("slave", 1, true) or typeText:find("doodad", 1, true)
        or typeText:find("farm", 1, true) or typeText:find("plant", 1, true) or typeText:find("tree", 1, true)
        or nameText:find("farmhouse", 1, true) or nameText:find("scarecrow", 1, true) or nameText:find("tree", 1, true)
        or nameText:find("farm", 1, true) or nameText:find("land", 1, true) or nameText:find("property", 1, true) then
        return hasInfo ~= nil
    end
    return hasInfo ~= nil
end

function TargetReader.GetClassName(safeCall, targetInfo)
    local className = RoleHelper.getClassName(targetInfo and targetInfo.class)
    if className then return className end
    local apiName = safeCall(function() return api.Ability:GetUnitClassName("target") end)
    if type(apiName) == "string" and apiName ~= "" and apiName ~= "0" then return apiName end
    return nil
end

function TargetReader.GetTokenName(safeCall, token)
    local name = safeCall(function() return api.Unit:UnitName(token) end)
    if type(name) == "string" and name ~= "" and name ~= "0" then return name end
    return nil
end

function TargetReader.GetTokenFaction(safeCall, token)
    local faction = safeCall(function() return api.Unit:GetFactionName(token) end)
    if type(faction) == "string" and faction ~= "" and faction ~= "0" then return faction end
    return nil
end

function TargetReader.GetGearScore(safeCall, token)
    local gearscore = tonumber(safeCall(function() return api.Unit:UnitGearScore(token) end))
    if gearscore and gearscore > 0 then return gearscore end
    return nil
end

function TargetReader.MakeRestrictedCharacterInfo(name, faction)
    return {
        type = "character",
        name = name,
        faction = faction,
        unitFaction = faction,
        apiRestricted = true
    }
end

function TargetReader.GetDefense(numField, info)
    local pdef = numField(info, {"armor", "physical_defense", "physicalDefense", "pdef"})
    local mdef = numField(info, {"magic_resist", "magicResist", "magic_defense", "magicDefense", "mdef"})
    local pdefPct = numField(info, {"armor_percentage", "armorPercent", "physical_defense_percentage", "physicalDefensePercent", "pdefPercent"})
    local mdefPct = numField(info, {"magic_resist_percentage", "magicResistPercent", "magic_defense_percentage", "magicDefensePercent", "mdefPercent"})
    return pdef, mdef, pdefPct, mdefPct
end

function TargetReader.FillDefense(numField, basePdef, baseMdef, basePdefPct, baseMdefPct, info)
    local pdef, mdef, pdefPct, mdefPct = TargetReader.GetDefense(numField, info)
    return basePdef or pdef, baseMdef or mdef, basePdefPct or pdefPct, baseMdefPct or mdefPct
end

function TargetReader.ExtraStats(utils, tokenInfo, targetInfo, modifierInfo)
    local infos = {tokenInfo or {}, targetInfo or {}, modifierInfo or {}}
    return {
        block = utils.chanceText(utils.firstNumAllowZero(infos, {"block_rate", "blockRate", "block_chance", "blockChance", "shield_block_rate", "shieldBlockRate", "shield_defense_rate", "shieldDefenseRate", "shield_defense", "shieldDefense", "block"}) or utils.firstPatternNum(infos, {"block", "shield_defense", "shielddefense"})),
        parry = utils.chanceText(utils.firstNumAllowZero(infos, {"parry_rate", "parryRate", "parry_chance", "parryChance", "weapon_parry", "weaponParry", "parry", "melee_parry_rate", "meleeParryRate"}) or utils.firstPatternNum(infos, {"parry"})),
        evasion = utils.chanceText(utils.firstNumAllowZero(infos, {"evasion", "evasion_rate", "evasionRate", "evade_rate", "evadeRate", "dodge", "dodge_rate", "dodgeRate"}) or utils.firstPatternNum(infos, {"evasion", "evade", "dodge"})),
        toughness = utils.valueText(utils.firstNumAllowZero(infos, {"toughness", "toughness_value", "toughnessValue", "battle_resist", "battleResist", "critical_resistance", "criticalResistance", "critical_resilience", "criticalResilience", "received_critical_damage_reduce", "receivedCriticalDamageReduce", "critical_damage_resistance", "criticalDamageResistance"}) or utils.firstPatternNum(infos, {"tough", "battle_resist", "battleresist", "critical_resist", "criticalresist", "critical_resilience", "criticalresilience"})),
        resilience = utils.valueText(utils.firstNumAllowZero(infos, {"resilience", "resilience_value", "resilienceValue", "flexibility", "pvp_resilience", "pvpResilience", "battle_resilience", "battleResilience", "pvp_damage_resistance", "pvpDamageResistance", "pvp_damage_reduce", "pvpDamageReduce"}) or utils.firstPatternNum(infos, {"resil", "flexibility", "pvp"})),
        critRate = utils.chanceText(utils.firstNumAllowZero(infos, {"critical_rate", "criticalRate", "crit_rate", "critRate", "critical_chance", "criticalChance", "crit_chance", "critChance", "melee_critical_rate", "meleeCriticalRate", "ranged_critical_rate", "rangedCriticalRate", "spell_critical_rate", "spellCriticalRate"}) or utils.firstPatternNum(infos, {"critical_rate", "criticalrate", "crit_rate", "critrate", "critical_chance", "criticalchance", "crit_chance", "critchance"}))
    }
end

return TargetReader
