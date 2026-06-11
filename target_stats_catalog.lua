-- Catalog of every trackable target stat, taken from the character_card probe of
-- api.Unit:UnitInfo(unit) / GetUnitInfoById(uid). Each entry maps a profile/settings
-- key to its raw UnitInfo field(s), display label, category and suffix.
--
-- "legacy" entries are the original eight intel stats (pdef..critRate); their values
-- keep flowing through TargetReader.ExtraStats with its robust multi-key fallbacks,
-- so this catalog only describes them for the picker window and never reads them.
-- All other entries are read here, directly from the raw UnitInfo tables.

local TargetStatsCatalog = {}

TargetStatsCatalog.CATEGORIES = {
    { key = "core", label = "Core" },
    { key = "info", label = "Info" },
    { key = "attributes", label = "Attr" },
    { key = "defense", label = "Def" },
    { key = "melee", label = "Melee" },
    { key = "ranged", label = "Range" },
    { key = "magic", label = "Magic" },
    { key = "healing", label = "Heal" },
    { key = "offense", label = "Off" },
    { key = "mobility", label = "Move" },
    { key = "pve", label = "PvE" },
    { key = "misc", label = "Misc" }
}

TargetStatsCatalog.STATS = {
    -- Core: the original intel stats, rendered by the existing ExtraStats pipeline.
    { key = "pdef", label = "PDef", category = "core", legacy = true },
    { key = "mdef", label = "MDef", category = "core", legacy = true },
    { key = "block", label = "Block", category = "core", legacy = true },
    { key = "parry", label = "Parry", category = "core", legacy = true },
    { key = "evasion", label = "Evasion", category = "core", legacy = true },
    { key = "toughness", label = "Toughness", category = "core", legacy = true },
    { key = "resilience", label = "Resilience", category = "core", legacy = true },
    { key = "critRate", label = "Crit Rate", category = "core", legacy = true },

    -- Unit info fields (GetUnitInfoById): text values render as "Kind: npc".
    { key = "level", label = "Level", category = "info", fields = {"level"} },
    { key = "heirLevel", label = "Ancestral Level", category = "info", fields = {"heirLevel", "heir_level"} },
    { key = "hp", label = "Current Health", category = "info", fields = {"hp", "health", "current_health"} },
    { key = "kind", label = "Kind", category = "info", text = true, fields = {"kind"} },
    { key = "type", label = "Type", category = "info", text = true, fields = {"type", "unitType", "unit_type"} },
    { key = "faction", label = "Faction", category = "info", text = true, fields = {"faction", "factionName", "faction_name"} },
    { key = "grade", label = "Grade", category = "info", text = true, fields = {"grade"} },

    { key = "str", label = "Strength", category = "attributes", fields = {"str"} },
    { key = "dex", label = "Agility", category = "attributes", fields = {"dex"} },
    { key = "sta", label = "Stamina", category = "attributes", fields = {"sta"} },
    { key = "int", label = "Intelligence", category = "attributes", fields = {"int"} },
    { key = "spi", label = "Spirit", category = "attributes", fields = {"spi"} },

    { key = "max_health", label = "Max Health", category = "defense", fields = {"max_health", "max_hp", "maxHealth"} },
    { key = "incoming_melee_damage_mul", label = "Melee Dmg Reduction", category = "defense", suffix = "%", fields = {"incoming_melee_damage_mul"} },
    { key = "incoming_ranged_damage_mul", label = "Ranged Dmg Reduction", category = "defense", suffix = "%", fields = {"incoming_ranged_damage_mul"} },
    { key = "incoming_spell_damage_mul", label = "Magic Dmg Reduction", category = "defense", suffix = "%", fields = {"incoming_spell_damage_mul"} },
    { key = "incoming_melee_damage_val", label = "Fixed Melee Reduction", category = "defense", fields = {"incoming_melee_damage_val"} },
    { key = "incoming_ranged_damage_val", label = "Fixed Ranged Reduction", category = "defense", fields = {"incoming_ranged_damage_val"} },
    { key = "incoming_spell_damage_val", label = "Fixed Magic Reduction", category = "defense", fields = {"incoming_spell_damage_val"} },
    { key = "incoming_siege_damage_mul", label = "Siege Dmg Reduction", category = "defense", suffix = "%", fields = {"incoming_siege_damage_mul"} },
    { key = "incoming_siege_damage_val", label = "Fixed Siege Reduction", category = "defense", fields = {"incoming_siege_damage_val"} },
    { key = "magic_effect_resist_percentage", label = "Magic Effect Resist", category = "defense", suffix = "%", fields = {"magic_effect_resist_percentage"} },

    { key = "melee_dps", label = "Melee Attack", category = "melee", fields = {"melee_dps"} },
    { key = "melee_min_dps", label = "Min Melee Attack", category = "melee", fields = {"melee_min_dps"} },
    { key = "melee_max_dps", label = "Max Melee Attack", category = "melee", fields = {"melee_max_dps"} },
    { key = "melee_success_rate", label = "Melee Accuracy", category = "melee", suffix = "%", fields = {"melee_success_rate"} },
    { key = "melee_critical_rate", label = "Melee Crit Rate", category = "melee", suffix = "%", fields = {"melee_critical_rate"} },
    { key = "melee_critical_bonus", label = "Melee Crit Dmg", category = "melee", suffix = "%", fields = {"melee_critical_bonus"} },
    { key = "melee_damage_mul", label = "Melee Skill Dmg", category = "melee", suffix = "%", fields = {"melee_damage_mul"} },
    { key = "mainhand_melee_speed", label = "MH Attack Speed", category = "melee", fields = {"mainhand_melee_speed"} },
    { key = "offhand_melee_speed", label = "OH Attack Speed", category = "melee", fields = {"offhand_melee_speed"} },
    { key = "backattack_melee_damage_mul", label = "Backstab Melee", category = "melee", suffix = "%", fields = {"backattack_melee_damage_mul"} },

    { key = "ranged_dps", label = "Ranged Attack", category = "ranged", fields = {"ranged_dps"} },
    { key = "ranged_min_dps", label = "Min Ranged Attack", category = "ranged", fields = {"ranged_min_dps"} },
    { key = "ranged_max_dps", label = "Max Ranged Attack", category = "ranged", fields = {"ranged_max_dps"} },
    { key = "ranged_success_rate", label = "Ranged Accuracy", category = "ranged", suffix = "%", fields = {"ranged_success_rate"} },
    { key = "ranged_critical_rate", label = "Ranged Crit Rate", category = "ranged", suffix = "%", fields = {"ranged_critical_rate"} },
    { key = "ranged_critical_bonus", label = "Ranged Crit Dmg", category = "ranged", suffix = "%", fields = {"ranged_critical_bonus"} },
    { key = "ranged_damage_mul", label = "Ranged Skill Dmg", category = "ranged", suffix = "%", fields = {"ranged_damage_mul"} },
    { key = "ranged_speed", label = "Ranged Attack Speed", category = "ranged", fields = {"ranged_speed"} },
    { key = "backattack_ranged_damage_mul", label = "Backstab Ranged", category = "ranged", suffix = "%", fields = {"backattack_ranged_damage_mul"} },

    { key = "spell_dps", label = "Magic Attack", category = "magic", fields = {"spell_dps"} },
    { key = "spell_success_rate", label = "Magic Accuracy", category = "magic", suffix = "%", fields = {"spell_success_rate"} },
    { key = "spell_critical_rate", label = "Magic Crit Rate", category = "magic", suffix = "%", fields = {"spell_critical_rate"} },
    { key = "spell_critical_bonus", label = "Magic Crit Dmg", category = "magic", suffix = "%", fields = {"spell_critical_bonus"} },
    { key = "spell_damage_mul", label = "Magic Skill Dmg", category = "magic", suffix = "%", fields = {"spell_damage_mul"} },
    { key = "backattack_spell_damage_mul", label = "Backstab Magic", category = "magic", suffix = "%", fields = {"backattack_spell_damage_mul"} },

    { key = "heal_dps", label = "Healing Power", category = "healing", fields = {"heal_dps"} },
    { key = "heal_critical_rate", label = "Crit Heal Rate", category = "healing", suffix = "%", fields = {"heal_critical_rate"} },
    { key = "heal_critical_bonus", label = "Crit Heal Bonus", category = "healing", suffix = "%", fields = {"heal_critical_bonus"} },
    { key = "heal_mul", label = "Healing", category = "healing", suffix = "%", fields = {"heal_mul"} },
    { key = "incoming_heal_mul", label = "Received Healing", category = "healing", suffix = "%", fields = {"incoming_heal_mul"} },

    { key = "ignore_armor", label = "Def Penetration", category = "offense", fields = {"ignore_armor"} },
    { key = "magic_penetration", label = "Magic Def Pen", category = "offense", fields = {"magic_penetration"} },
    { key = "ignore_shield_bonus", label = "Shield Def Pen", category = "offense", fields = {"ignore_shield_bonus"} },
    { key = "ignore_shield_bonus_mul", label = "Shield Def Pen %", category = "offense", suffix = "%", fields = {"ignore_shield_bonus_mul"} },
    { key = "ignore_shield_chance", label = "Shield Pen Rate", category = "offense", suffix = "%", fields = {"ignore_shield_chance"} },
    { key = "bulls_eye", label = "Focus", category = "offense", fields = {"bulls_eye"} },
    { key = "attack_anim_speed", label = "Attack Speed", category = "offense", fields = {"attack_anim_speed"} },
    { key = "attack_anim_speed_mul", label = "Attack Speed %", category = "offense", suffix = "%", fields = {"attack_anim_speed_mul", "global_cooldown_mul"} },
    { key = "casting_time", label = "Cast Time", category = "offense", fields = {"casting_time"} },
    { key = "casting_time_mul", label = "Cast Time %", category = "offense", suffix = "%", fields = {"casting_time_mul"} },

    { key = "move_speed", label = "Move Speed", category = "mobility", fields = {"move_speed"} },
    { key = "health_regen", label = "Health Regen", category = "mobility", fields = {"health_regen"} },
    { key = "persistent_health_regen", label = "Cont. Health Regen", category = "mobility", fields = {"persistent_health_regen"} },
    { key = "mana_regen", label = "Mana Regen", category = "mobility", fields = {"mana_regen"} },
    { key = "persistent_mana_regen", label = "Cont. Mana Regen", category = "mobility", fields = {"persistent_mana_regen"} },

    { key = "incoming_damage_mul_anti_npc", label = "PvE Dmg Reduction", category = "pve", suffix = "%", fields = {"incoming_damage_mul_anti_npc"} },
    { key = "incoming_melee_damage_add_anti_npc", label = "PvE Melee Reduction", category = "pve", suffix = "%", fields = {"incoming_melee_damage_add_anti_npc"} },
    { key = "incoming_ranged_damage_add_anti_npc", label = "PvE Ranged Reduction", category = "pve", suffix = "%", fields = {"incoming_ranged_damage_add_anti_npc"} },
    { key = "incoming_spell_damage_add_anti_npc", label = "PvE Magic Reduction", category = "pve", suffix = "%", fields = {"incoming_spell_damage_add_anti_npc"} },
    { key = "melee_damage_mul_anti_npc", label = "PvE Melee Skill Dmg", category = "pve", suffix = "%", fields = {"melee_damage_mul_anti_npc"} },
    { key = "ranged_damage_mul_anti_npc", label = "PvE Ranged Skill Dmg", category = "pve", suffix = "%", fields = {"ranged_damage_mul_anti_npc"} },
    { key = "spell_damage_mul_anti_npc", label = "PvE Magic Skill Dmg", category = "pve", suffix = "%", fields = {"spell_damage_mul_anti_npc"} },

    { key = "detect_stealth_range_mul", label = "Stealth Detection", category = "misc", suffix = "%", fields = {"detect_stealth_range_mul"} },
    { key = "exp_mul", label = "Experience Gain", category = "misc", suffix = "%", fields = {"exp_mul"} },
    { key = "drop_rate_mul", label = "Loot Drop Rate", category = "misc", suffix = "%", fields = {"drop_rate_mul"} },
    { key = "loot_gold_mul", label = "Gold Drop Rate", category = "misc", suffix = "%", fields = {"loot_gold_mul"} }
}

local statsByCategory = nil

function TargetStatsCatalog.ByCategory(categoryKey)
    if not statsByCategory then
        statsByCategory = {}
        for _, stat in ipairs(TargetStatsCatalog.STATS) do
            statsByCategory[stat.category] = statsByCategory[stat.category] or {}
            table.insert(statsByCategory[stat.category], stat)
        end
    end
    return statsByCategory[categoryKey] or {}
end

local legacyKeys = nil

local function isLegacyKey(key)
    if not legacyKeys then
        legacyKeys = {}
        for _, stat in ipairs(TargetStatsCatalog.STATS) do
            if stat.legacy then legacyKeys[stat.key] = true end
        end
    end
    return legacyKeys[key] == true
end

-- True when any profile enables a non-legacy catalog stat; gates the extra
-- UnitInfo reads on the 100ms target update path.
function TargetStatsCatalog.AnyEnabled(settings)
    local profiles = settings and settings.classIntelProfiles
    if type(profiles) ~= "table" then return false end
    for _, profile in pairs(profiles) do
        if type(profile) == "table" then
            for key, enabled in pairs(profile) do
                if enabled == true and not isLegacyKey(key) then return true end
            end
        end
    end
    return false
end

local function formatNumber(value)
    if value % 1 == 0 then return string.format("%.0f", value) end
    return string.format("%.1f", value)
end

-- Formatted value text for one stat, or nil when no info table carries it.
function TargetStatsCatalog.Value(utils, infos, stat)
    if stat.legacy or not stat.fields then return nil end
    if stat.text then
        for _, info in ipairs(infos) do
            local value = utils.textField(info, stat.fields)
            if value then return value end
        end
        return nil
    end
    local value = utils.firstNumAllowZero(infos, stat.fields)
    if value == nil then return nil end
    return formatNumber(value) .. (stat.suffix or "")
end

return TargetStatsCatalog
