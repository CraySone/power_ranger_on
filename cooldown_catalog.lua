local Catalog = {}

local function copyList(list)
    local out = {}
    if type(list) == "table" then
        for i, value in ipairs(list) do out[i] = value end
    end
    return out
end

local function copyRow(row)
    local out = {}
    for key, value in pairs(row or {}) do
        if type(value) == "table" then
            out[key] = copyList(value)
        else
            out[key] = value
        end
    end
    return out
end

local function gliderDevice(key, name, itemTypes, patterns, abilities, icon)
    return {
        key = key,
        name = name,
        kind = "glider",
        itemTypes = itemTypes,
        namePatterns = patterns,
        icon = icon,
        abilities = abilities or {}
    }
end

local function mountDevice(key, name, abilities, icon)
    return {
        key = key,
        name = name,
        kind = "mount",
        icon = icon,
        abilities = abilities or {}
    }
end

local function ability(key, row)
    row = copyRow(row)
    row.recipeAbilityKey = key
    return row
end

Catalog.DEVICES = {
    gliderDevice("sloth_glider", "Sloth Glider", {30621}, {
        "sloth",
        "glider companion: sloth",
        "sloth glider companion",
        "enhanced sloth glider companion"
    }, {
        ability("star_roll", {
            unit = "self",
            name = "Sloth Glider",
            source = "Sloth",
            buffName = "Star Divine Protection",
            buffNames = {"Star Divine Protection", "Star's Divine Protection", "Starfall"},
            cooldown = 10,
            cooldownStartsOnActive = true,
            cooldownOnlyOnActive = true,
            triggerMinTimeLeftMs = 5300,
            fixedCooldown = true
        })
    }),
    gliderDevice("crystal_wings", "Crystal Wings", nil, {"crystal wings"}, {
        ability("crystal_star", {
            unit = "self",
            name = "Crystal Wings",
            source = "Crystal Wings",
            buffName = "Star Divine Protection",
            buffNames = {"Star Divine Protection", "Star's Divine Protection", "Starfall", "Charging"},
            cooldown = 60,
            cooldownStartsOnActive = true,
            cooldownOnlyOnActive = true,
            triggerMinTimeLeftMs = 5300,
            fixedCooldown = true
        })
    }),
    gliderDevice("cumulus_magithopter", "Cumulus Magithopter", nil, {
        "cumulus magicopter",
        "cumulus magithopter",
        "magicopter",
        "magithopter"
    }, {
        ability("magicopter_star", {
            unit = "self",
            name = "Magicopter",
            source = "Cumulus Magithopter",
            buffName = "Star Divine Protection",
            buffNames = {"Star Divine Protection", "Star's Divine Protection", "Starfall"},
            cooldown = 45,
            cooldownStartsOnActive = true,
            cooldownOnlyOnActive = true,
            triggerMinTimeLeftMs = 5300,
            fixedCooldown = true,
            icon = "Game\\ui\\icon\\icon_item_4138.dds"
        })
    }, "Game\\ui\\icon\\icon_item_4138.dds"),
    gliderDevice("ezi_glider", "Ezi Glider", {18174}, {"ezi", "ezi's glider"}, {
        ability("invincible_flight", {
            unit = "self",
            id = 3636,
            name = "Ezi Glider",
            source = "Ezi",
            buffName = "Invincible Flight",
            buffNames = {"Invincible Flight", "Invincibility Flight"},
            cooldown = 60,
            cooldownStartsOnActive = true,
            fixedCooldown = true,
            itemType = 18174
        })
    }),
    gliderDevice("flamefeather_glider", "Flamefeather Glider", {
        8001101, 8001102, 8001103, 8001104,
        8001105, 8001106, 8001107, 8001108
    }, {
        "flamefeather",
        "flamefeather glider",
        "enhanced flamefeather glider",
        "glider companion: flamefeather",
        "flamefeather glider companion",
        "enhanced flamefeather glider companion"
    }, {
        ability("invincible_flight", {
            unit = "self",
            id = 3636,
            name = "Flamefeather",
            source = "Flamefeather Glider",
            buffName = "Invincible Flight",
            buffNames = {"Invincible Flight", "Invincibility Flight"},
            cooldown = 60,
            cooldownStartsOnActive = true,
            triggerMinTimeLeftMs = 500,
            fixedCooldown = true,
            itemType = 8001101
        })
    }),
    gliderDevice("snowflake_wings", "Snowflake Wings", nil, {"snowflake wings", "snowflake"}, {
        ability("snowflake_flight", {
            unit = "self",
            id = 30570,
            name = "Snowflake",
            source = "Snowflake Wings",
            buffName = "Snowflake Flight",
            buffNames = {"Snowflake Flight"},
            cooldown = 60,
            cooldownStartsOnActive = true,
            fixedCooldown = true,
            icon = "Game\\ui\\icon\\icon_skill_glider_snowflake02.dds"
        })
    }, "Game\\ui\\icon\\icon_skill_glider_snowflake02.dds"),
    gliderDevice("frozen_glider", "Frozen Glider", nil, {"frozen glider", "frozen"}, {
        ability("frozen_glider", {
            unit = "self",
            id = 30300,
            name = "Frozen Glider",
            source = "Frozen Glider",
            buffName = "Frozen",
            buffNames = {"Frozen"},
            cooldown = 60,
            cooldownStartsOnActive = true,
            fixedCooldown = true
        })
    }),
    mountDevice("general_mount", "General Mount", {
        ability("dash", {
            unit = "self",
            id = 3523,
            name = "Dash",
            source = "Ser Meatball",
            cooldown = 30,
            preferMountIcon = true
        })
    }),
    mountDevice("rajani", "Rajani", {
        ability("rajani_dash", {
            unit = "self",
            id = 8000211,
            name = "Dash",
            source = "Mount",
            cooldown = 30,
            preferMountIcon = true,
            icon = "Game\\ui\\icon\\icon_skill_wild03.dds"
        }),
        ability("rajani_sprint", {
            unit = "self",
            id = 8000208,
            name = "Sprint",
            source = "Rajani",
            cooldown = 30,
            cooldownStartsOnActive = true,
            fixedCooldown = true,
            preferMountIcon = true
        })
    }),
    mountDevice("kirin", "Kirin", {
        ability("kirin_speed", {
            unit = "self",
            id = 21817,
            name = "Kirin Speed",
            source = "Kirin",
            cooldown = 35,
            cooldownStartsOnActive = true,
            fixedCooldown = true,
            preferMountIcon = true,
            icon = "Game\\ui\\icon\\icon_skill_karon01.dds"
        })
    }, "Game\\ui\\icon\\icon_skill_karon01.dds"),
    mountDevice("cloud_mount", "Cloud Mount", {
        ability("cloud", {
            unit = "self",
            id = 8000565,
            name = "Cloud",
            source = "Cloud Mount",
            cooldown = 60,
            cooldownStartsOnActive = true,
            fixedCooldown = true,
            preferMountIcon = true,
            itemType = 43813
        })
    }),
    mountDevice("nuis_veil_mount", "Nui's Veil Mount", {
        ability("nuis_veil", {
            unit = "playerpet",
            name = "Nui's Veil",
            source = "Mount",
            buffName = "Nui's Veil",
            buffNames = {"Nui's Veil"},
            cooldown = 30,
            cooldownAura = true,
            fixedCooldown = true,
            preferMountIcon = true,
            icon = "Game\\ui\\icon\\icon_skill_tare01.dds"
        })
    }),
    mountDevice("golem", "Golem", {
        ability("golem_invinc", {
            unit = "self",
            id = 15068,
            name = "Golem Invinc",
            source = "Golem",
            cooldown = 33,
            cooldownStartsOnActive = true,
            fixedCooldown = true
        })
    })
}

Catalog.EXTRA_ROWS = {
    {
        unit = "player",
        id = 131,
        name = "Invinc",
        source = "Player",
        cooldown = 120,
        fixedCooldown = true
    }
}

function Catalog.BuildTrackedBuffRows()
    local rows = {}
    for _, row in ipairs(Catalog.EXTRA_ROWS) do
        rows[#rows + 1] = copyRow(row)
    end
    for _, device in ipairs(Catalog.DEVICES) do
        for _, rawAbility in ipairs(device.abilities or {}) do
            local row = copyRow(rawAbility)
            row.recipeDeviceKey = device.key
            row.recipeDeviceName = device.name
            if device.kind == "glider" then
                row.category = row.category or "glider"
                row.gliderPattern = row.gliderPattern or copyList(device.namePatterns)
                row.itemTypes = row.itemTypes or copyList(device.itemTypes)
                if row.itemType == nil and row.itemTypes and row.itemTypes[1] then
                    row.itemType = row.itemTypes[1]
                end
            elseif device.kind == "mount" then
                row.category = row.category or "mount"
                row.preferMountIcon = row.preferMountIcon ~= false
            end
            if row.icon == nil then row.icon = device.icon end
            rows[#rows + 1] = row
        end
    end
    return rows
end

return Catalog
