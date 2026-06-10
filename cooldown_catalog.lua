local Catalog = {}

-- Trimmed catalog: only the Star Divine Protection gliders ship as defaults.
-- Their trigger recipe (cooldownOnlyOnActive + triggerMinTimeLeftMs) cannot be
-- recreated through the detected-skills panel, so they stay built in. Everything
-- else (other gliders, mounts) is user-added via the detected panel, which captures
-- the exact buff id, item type, and icon of the user's own device tier at add time --
-- the hardcoded per-tier ids this catalog used to carry were the source of the
-- wrong-grouping/wrong-icon/wrong-cooldown reports. A one-time migration in
-- target_overlay (removedDefaultsTrimVersion) drops the old merged default rows
-- from existing users' settings.

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
    }, "Game\\ui\\icon\\icon_item_4138.dds")
}

Catalog.EXTRA_ROWS = {}

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
