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

local function gliderDevice(key, name, itemTypes, patterns, abilities, icon, fallbackItemType, displayItemType)
    local normalizedItemTypes = copyList(itemTypes)
    if fallbackItemType then
        local found = false
        for _, itemType in ipairs(normalizedItemTypes) do
            if tonumber(itemType) == tonumber(fallbackItemType) then found = true end
        end
        if not found then normalizedItemTypes[#normalizedItemTypes + 1] = fallbackItemType end
    end
    return {
        key = key,
        name = name,
        kind = "glider",
        itemTypes = normalizedItemTypes,
        namePatterns = patterns,
        icon = icon,
        iconItemType = displayItemType or fallbackItemType,
        abilities = abilities or {}
    }
end

local function mountDevice(key, name, abilities, icon, itemType, displayItemType)
    return {
        key = key,
        name = name,
        kind = "mount",
        icon = icon,
        itemType = itemType,
        iconItemType = displayItemType or itemType,
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
            id = 8000138,
            buffIds = {8000138},
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
    }, nil, nil, 8000412),
    gliderDevice("crystal_wings", "Crystal Wings", nil, {"crystal wings"}, {
        ability("crystal_star", {
            unit = "self",
            id = 26927,
            buffIds = {26927},
            name = "Crystal Wings",
            source = "Crystal Wings",
            buffName = "Charging",
            buffNames = {"Charging"},
            cooldown = 60,
            cooldownStartsOnActive = true,
            icon_type = "buff",
            icon_id = 26927
        })
    }, nil, nil, 44649),
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
    gliderDevice("ezi_glider", "Ezi Glider", {18174}, {
        "ezi",
        "ezi's glider",
        "ezi glider",
        "glider companion: ezi",
        "ezi glider companion",
        "enhanced ezi glider",
        "enhanced ezi glider companion"
    }, {
        ability("invincible_flight", {
            unit = "self",
            id = 3636,
            buffIds = {3636},
            name = "Ezi Glider",
            source = "Ezi",
            buffName = "Invincible Flight",
            buffNames = {"Invincible Flight", "Invincibility Flight"},
            cooldown = 60,
            cooldownStartsOnActive = true,
            triggerMinTimeLeftMs = 500,
            fixedCooldown = true,
            matchByIdOnly = true,
            icon_type = "buff",
            icon_id = 3636,
            itemType = 18174
        })
    }, nil, 8000399, 8000399),
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
            id = 8000286,
            buffIds = {8000286},
            name = "Flamefeather",
            source = "Flamefeather Glider",
            buffName = "Invincible Flight",
            buffNames = {"Invincible Flight", "Invincibility Flight"},
            cooldown = 60,
            cooldownStartsOnActive = true,
            triggerMinTimeLeftMs = 500,
            fixedCooldown = true,
            matchByIdOnly = true,
            icon_type = "item",
            icon_id = 8001102,
            itemType = 8001101
        })
    }, nil, nil, 8001102),
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
    gliderDevice("red_dragon_glider", "Red Dragon Glider", {8000322}, {
        "red dragon",
        "red dragon glider",
        "rd glider"
    }, {
        ability("red_dragon_flight", {
            unit = "self",
            id = 3637,
            buffIds = {3637},
            name = "Red Dragon",
            source = "Red Dragon Glider",
            cooldown = 60,
            cooldownStartsOnActive = true,
            fixedCooldown = true,
            icon_type = "item",
            icon_id = 8000322
        })
    }, nil, 8000322),
    mountDevice("ser_meatball", "Ser Meatball", {
        ability("dash", {
            unit = "self",
            id = 3523,
            name = "Dash",
            source = "Ser Meatball",
            cooldown = 30,
            preferMountIcon = true,
            mountNames = {"Ser Meatball", "Ser Meatball (Vanity)", "Gallant Ser Meatball"},
            mountDeathDuration = 300,
            icon_type = "buff",
            icon_id = 3523
        })
    }, nil, 9000375),
    mountDevice("rajani", "Raijin", {
        ability("rajani_dash", {
            unit = "self",
            id = 8000211,
            name = "Dash",
            source = "Raijin",
            cooldown = 60,
            preferMountIcon = true,
            mountNames = {"Rajani", "Raijin"},
            icon = "Game\\ui\\icon\\icon_skill_wild03.dds",
            mountDeathDuration = 300
        }),
        ability("rajani_stealth", {
            unit = "self",
            id = 17165,
            name = "Stealth",
            source = "Raijin",
            cooldown = 60,
            preferMountIcon = true,
            mountNames = {"Rajani", "Raijin"},
            icon_type = "skill",
            icon_id = 17165
        })
    }, nil, 8000618),
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
            mountNames = {"Kirin", "Hellwraith Kirin"},
            icon = "Game\\ui\\icon\\icon_skill_karon01.dds"
        }),
        ability("kirin_dash", {
            unit = "self",
            id = 21733,
            name = "Dash",
            source = "Kirin",
            cooldown = 30,
            preferMountIcon = true,
            mountNames = {"Kirin", "Hellwraith Kirin"},
            icon_type = "skill",
            icon_id = 21733
        }),
        ability("kirin_dash_mana", {
            unit = "self",
            name = "Dash",
            source = "Kirin",
            cooldown = 30,
            preferMountIcon = true,
            petManaSpent = 210,
            mountNames = {"Kirin", "Hellwraith Kirin"},
            icon_type = "skill",
            icon_id = 21733
        }),
        ability("kirin_eyes", {
            unit = "self",
            id = 21734,
            name = "Eyes",
            source = "Kirin",
            cooldown = 60,
            preferMountIcon = true,
            mountNames = {"Kirin", "Hellwraith Kirin"},
            icon_type = "skill",
            icon_id = 21734
        })
    }, nil, 9001789),
    mountDevice("stormrose", "Stormrose", {
        ability("nuis_veil", {
            unit = "playerpet",
            name = "Nui's Veil",
            source = "Stormrose",
            buffName = "Nui's Veil",
            buffNames = {"Nui's Veil"},
            cooldown = 30,
            cooldownAura = true,
            fixedCooldown = true,
            preferMountIcon = true,
            mountNames = {"Stormrose"},
            icon = "Game\\ui\\icon\\icon_skill_tare01.dds"
        })
    }, nil, 8001042),
    mountDevice("golem", "Golem", {
        ability("golem_invinc", {
            unit = "self",
            id = 15068,
            name = "Golem Invinc",
            source = "Golem",
            cooldown = 33,
            cooldownStartsOnActive = true,
            fixedCooldown = true,
            mountNames = {"Golem", "Andelph Patrol Mech", "Andelph Mech", "Patrol Mech"},
            icon_type = "buff",
            icon_id = 15068
        })
    }, nil, 37136),
    mountDevice("siegeram_taurus", "Siegeram Taurus", {
        ability("taurus_shield", {
            unit = "self",
            id = 8000338,
            buffIds = {8000338},
            name = "Taurus Shield",
            source = "Siegeram Taurus",
            cooldown = 60,
            preferMountIcon = true,
            mountNames = {"Siegeram Taurus"},
            mountDeathDuration = 300,
            icon_type = "item",
            icon_id = 8001246
        }),
        ability("taurus_kinetic", {
            unit = "self",
            id = 8000345,
            buffIds = {8000345},
            name = "Kinetic Shield",
            source = "Siegeram Taurus",
            cooldown = 60,
            preferMountIcon = true,
            mountNames = {"Siegeram Taurus"},
            icon_type = "skill",
            icon_id = 8000346
        }),
        ability("taurus_dash", {
            unit = "self",
            id = 8000340,
            buffIds = {8000340},
            name = "Dash",
            source = "Siegeram Taurus",
            cooldown = 0,
            preferMountIcon = true,
            mountNames = {"Siegeram Taurus"},
            icon_type = "skill",
            icon_id = 8000340
        }),
        ability("taurus_lunge", {
            unit = "playerpet",
            name = "Rocket Lunge",
            source = "Siegeram Taurus",
            cooldown = 18,
            preferMountIcon = true,
            petManaSpent = 210,
            mountNames = {"Siegeram Taurus"},
            icon_type = "skill",
            icon_id = 613
        })
    }, nil, 8001246),
    mountDevice("blacktail_leomorph", "Gallant Blacktail Leomorph", {
        ability("leomorph_main", {
            unit = "self",
            id = 16793,
            buffIds = {16793},
            name = "Leomorph",
            source = "Gallant Blacktail Leomorph",
            cooldown = 30,
            preferMountIcon = true,
            mountNames = {"Gallant Blacktail Leomorph"},
            mountDeathDuration = 300,
            icon_type = "item",
            icon_id = 39706
        }),
        ability("leomorph_dropback", {
            unit = "playerpet",
            name = "Dropback",
            source = "Gallant Blacktail Leomorph",
            cooldown = 20,
            preferMountIcon = true,
            petManaSpent = 113,
            mountNames = {"Gallant Blacktail Leomorph"},
            icon_type = "skill",
            icon_id = 2727
        }),
        ability("leomorph_stealth", {
            unit = "self",
            id = 16794,
            buffIds = {16794},
            name = "Stealth",
            source = "Gallant Blacktail Leomorph",
            cooldown = 90,
            preferMountIcon = true,
            mountNames = {"Gallant Blacktail Leomorph"},
            icon_type = "skill",
            icon_id = 16794
        })
    }, nil, 39706),
    mountDevice("bouncy_cow", "Bouncy Cow", {
        ability("bouncy_cow", {
            unit = "self",
            id = 32392,
            buffIds = {32392, 32393, 32394},
            name = "Bouncy Cow",
            source = "Bouncy Cow",
            cooldown = 60,
            preferMountIcon = true,
            mountNames = {"Bouncy Cow", "Asianbunnyx"},
            icon = "Game\\ui\\icon\\icon_skill_snowman03.dds"
        })
    }, nil, 53939),
    mountDevice("violet_elk", "Gallant Violet Elk", {
        ability("elk_mana", {
            unit = "playerpet",
            name = "Elk",
            source = "Gallant Violet Elk",
            cooldown = 15,
            preferMountIcon = true,
            petManaSpent = 284,
            mountNames = {"Gallant Violet Elk"},
            icon_type = "item",
            icon_id = 39712
        })
    }, nil, 39712),
    mountDevice("aquestria", "Aquestria", {
        ability("aquestria_main", {
            unit = "self",
            id = 8000316,
            buffIds = {8000316},
            name = "Aquestria",
            source = "Aquestria",
            cooldown = 25,
            preferMountIcon = true,
            mountNames = {"Aquestria"},
            icon_type = "item",
            icon_id = 8001231
        }),
        ability("aquestria_dive", {
            unit = "playerpet",
            name = "Dive",
            source = "Aquestria",
            cooldown = 30,
            preferMountIcon = true,
            petManaSpent = 466,
            mountNames = {"Aquestria"},
            icon_type = "skill",
            icon_id = 8000798
        })
    }, nil, 8001231)
}

Catalog.EXTRA_ROWS = {
    {
        unit = "player",
        id = 131,
        name = "Invinc",
        source = "Player",
        cooldown = 120,
        fixedCooldown = true,
        category = "player",
        recipeDeviceKey = "player_immunity",
        recipeDeviceName = "Player",
        recipeDeviceKind = "player",
        recipeAbilityKey = "invinc",
        recipeAbilityLabel = "Invinc"
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
            row.recipeDeviceKind = device.kind
            row.recipeAbilityLabel = row.recipeAbilityLabel or row.label or row.name
            row.recipeDeviceItemType = row.recipeDeviceItemType or device.iconItemType
            row.recipeDeviceIconLocked = row.recipeDeviceIconLocked or device.icon ~= nil
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
                row.dynamicDisplay = row.dynamicDisplay == true
                row.itemType = row.itemType or device.itemType
            end
            row.recipeDeviceIcon = row.recipeDeviceIcon or device.icon
            if row.icon_type == nil and row.iconType == nil
                and row.id
                and (row.mountManaSpent or row.petManaSpent or row.mana_trigger or row.playerManaSpent or row.player_mana) then
                row.icon_type = "skill"
                row.icon_id = row.id
            end
            if row.id and not row.buffIds then row.buffIds = {row.id} end
            rows[#rows + 1] = row
        end
    end
    return rows
end

return Catalog
