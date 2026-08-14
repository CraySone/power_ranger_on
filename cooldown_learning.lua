local Learning = {}

local function normalize(value)
    local text = string.lower(tostring(value or ""))
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("^enhanced%s+", "")
    text = text:gsub("^wrapped%s+", "")
    text = text:gsub("^summon%s+", "")
    text = text:gsub("%s+", " ")
    return text
end

local function copyList(list)
    local out = {}
    if type(list) == "table" then
        for i, value in ipairs(list) do out[i] = value end
    end
    return out
end

local function addUnique(list, value)
    value = tostring(value or "")
    if value == "" then return end
    for _, existing in ipairs(list) do
        if normalize(existing) == normalize(value) then return end
    end
    list[#list + 1] = value
end

local function addItemType(list, value)
    local numeric = tonumber(value)
    if not numeric or numeric <= 0 then return end
    numeric = math.floor(numeric + 0.5)
    for _, existing in ipairs(list) do
        if tonumber(existing) == numeric then return end
    end
    list[#list + 1] = numeric
end

local function deviceKey(kind, name)
    local key = normalize(name):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if key == "" then key = "device" end
    local prefix = normalize(kind):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if prefix == "" then prefix = "device" end
    return prefix .. "_" .. key
end

-- Bump when a bug could have written bad aliases/item types into the learned store. The
-- store is DERIVED data -- it is rebuilt as devices are added -- and every already-tracked
-- row carries its own baked fields, so clearing it repairs the corruption without touching
-- anything the user configured. v2: drops devices polluted by the reverse-containment match
-- and by the live-glider re-stamp in recordDetectedSkill.
local STORE_VERSION = 2

local function ensureStore(settings)
    if type(settings.learnedCooldownDevices) ~= "table" then settings.learnedCooldownDevices = {} end
    if tonumber(settings.learnedCooldownDevicesVersion) ~= STORE_VERSION then
        settings.learnedCooldownDevices = {}
        settings.learnedCooldownDevicesVersion = STORE_VERSION
        return settings.learnedCooldownDevices
    end
    local migrated = {}
    for key, device in pairs(settings.learnedCooldownDevices) do
        if type(device) == "table" then
            local safeKey = deviceKey(device.kind or "device", device.name or key)
            if key ~= safeKey then
                local existing = settings.learnedCooldownDevices[safeKey] or migrated[safeKey]
                if type(existing) ~= "table" then
                    device.key = safeKey
                    migrated[safeKey] = device
                end
                settings.learnedCooldownDevices[key] = nil
            elseif device.key ~= safeKey then
                device.key = safeKey
            end
        elseif type(key) ~= "string" or key:match("^[A-Za-z_][A-Za-z0-9_]*$") == nil then
            settings.learnedCooldownDevices[key] = nil
        end
    end
    for key, device in pairs(migrated) do
        settings.learnedCooldownDevices[key] = device
    end
    return settings.learnedCooldownDevices
end

-- Device words too generic to identify a specific glider/mount, mirroring the list in
-- CooldownRecipes. A stored alias that is only one of these must never resolve a lookup.
local GENERIC_DEVICE_WORDS = {
    ["glider"] = true, ["wings"] = true, ["mount"] = true, ["pet"] = true,
    ["flight"] = true, ["companion"] = true, ["glider companion"] = true,
    ["detected"] = true, ["unknown"] = true, ["mount/pet"] = true, ["device"] = true
}

local function matchLearned(device, name)
    local wanted = normalize(name)
    if wanted == "" or type(device) ~= "table" then return false end
    if normalize(device.name) == wanted then return true end
    for _, alias in ipairs(device.patterns or {}) do
        local pattern = normalize(alias)
        -- Forward containment ONLY, the same rule CooldownRecipes.DeviceMatches already
        -- adopted: the looked-up name must contain the stored alias. The old reverse
        -- direction (pattern:find(wanted)) meant any glider whose name was a SUBSTRING of
        -- a stored alias resolved to this device and inherited its icon/displayItemType --
        -- e.g. a glider called "Flight Glider" matching a stored
        -- "glider companion: flamefeather". That is why only some gliders broke: the
        -- hardcoded ones never reach this store, and of the rest only the ones whose names
        -- happened to substring-collide with an already-learned alias.
        if pattern ~= "" and not GENERIC_DEVICE_WORDS[pattern] and wanted:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

function Learning.Ensure(settings)
    ensureStore(settings)
end

function Learning.Learn(settings, recipe)
    if type(settings) ~= "table" or type(recipe) ~= "table" then return false end
    local kind = recipe.recipeDeviceKind or recipe.category
    if kind ~= "glider" and kind ~= "mount" then return false end
    local name = recipe.recipeDeviceName or recipe.mountName or recipe.source or recipe.name
    if normalize(name) == "" then return false end

    local store = ensureStore(settings)
    local key = deviceKey(kind, recipe.recipeDeviceName or recipe.mountName or recipe.source or recipe.name)
    local device = store[key]
    local changed = false
    if type(device) ~= "table" then
        device = { key = key, kind = kind, name = tostring(name), patterns = {}, itemTypes = {} }
        store[key] = device
        changed = true
    end

    if device.name ~= tostring(name) and normalize(device.name) == "" then
        device.name = tostring(name)
        changed = true
    end
    if device.kind ~= kind then
        device.kind = kind
        changed = true
    end

    local beforePatterns = #(device.patterns or {})
    device.patterns = device.patterns or {}
    addUnique(device.patterns, name)
    addUnique(device.patterns, recipe.recipeDeviceName)
    addUnique(device.patterns, recipe.mountName)
    for _, pattern in ipairs(recipe.gliderPattern or {}) do addUnique(device.patterns, pattern) end
    if #device.patterns ~= beforePatterns then changed = true end

    local beforeTypes = #(device.itemTypes or {})
    device.itemTypes = device.itemTypes or {}
    addItemType(device.itemTypes, recipe.recipeDeviceItemType)
    addItemType(device.itemTypes, recipe.itemType)
    for _, itemType in ipairs(recipe.itemTypes or {}) do addItemType(device.itemTypes, itemType) end
    if #device.itemTypes ~= beforeTypes then changed = true end

    if recipe.recipeDeviceIcon and device.icon ~= recipe.recipeDeviceIcon then
        device.icon = recipe.recipeDeviceIcon
        changed = true
    end
    if recipe.recipeDeviceItemType and device.displayItemType ~= recipe.recipeDeviceItemType then
        device.displayItemType = recipe.recipeDeviceItemType
        changed = true
    elseif not device.displayItemType and device.itemTypes and device.itemTypes[1] then
        device.displayItemType = device.itemTypes[1]
        changed = true
    end

    return changed
end

function Learning.Find(settings, kind, name)
    local store = type(settings) == "table" and settings.learnedCooldownDevices
    if type(store) ~= "table" then return nil end
    for _, device in pairs(store) do
        if type(device) == "table" and device.kind == kind and matchLearned(device, name) then
            return {
                key = device.key,
                name = device.name,
                patterns = copyList(device.patterns),
                names = copyList(device.patterns),
                itemTypes = copyList(device.itemTypes),
                itemType = device.itemTypes and device.itemTypes[1],
                displayItemType = device.displayItemType or (device.itemTypes and device.itemTypes[1]),
                icon = device.icon
            }
        end
    end
    return nil
end

return Learning
