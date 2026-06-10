local Recipes = {}

local ITEM_TYPE_KEYS = {
    "itemType", "item_type", "itemTypeId", "item_type_id",
    "typeId", "type_id", "itemId", "item_id", "id"
}

local function trim(value)
    local text = tostring(value or "")
    return string.match(text, "^%s*(.-)%s*$") or text
end

function Recipes.NormalizeName(value)
    local text = string.lower(trim(value))
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^enhanced%s+", "")
    return text
end

local function addItemType(out, value)
    if type(value) == "table" then
        for _, item in ipairs(value) do
            addItemType(out, item)
        end
        return
    end
    local numeric = tonumber(value)
    if numeric and numeric > 0 then
        out[#out + 1] = math.floor(numeric + 0.5)
    end
end

function Recipes.ItemTypes(row)
    local out = {}
    addItemType(out, row and row.itemType)
    addItemType(out, row and row.itemTypes)
    addItemType(out, row and row.item_ids)
    return out
end

function Recipes.FirstItemType(row)
    local types = Recipes.ItemTypes(row)
    return types[1]
end

function Recipes.Patterns(row)
    local out = {}
    local source = row and (row.gliderPattern or row.namePatterns or row.devicePatterns)
    if type(source) == "table" then
        for _, value in ipairs(source) do
            if trim(value) ~= "" then out[#out + 1] = value end
        end
    elseif source ~= nil and trim(source) ~= "" then
        out[#out + 1] = source
    end
    return out
end

function Recipes.ExtractItemType(...)
    local infos = {...}
    for i = 1, #infos do
        local info = infos[i]
        if type(info) == "table" then
            for _, key in ipairs(ITEM_TYPE_KEYS) do
                local value = tonumber(info[key])
                if value and value > 0 then return math.floor(value + 0.5) end
            end
            local nested = info.item or info.itemInfo or info.tooltipInfo or info.info
            if type(nested) == "table" then
                local value = Recipes.ExtractItemType(nested)
                if value then return value end
            end
        end
    end
    return nil
end

function Recipes.ItemTypeMatches(row, itemType)
    local numeric = tonumber(itemType)
    if not numeric or numeric <= 0 then return false end
    numeric = math.floor(numeric + 0.5)
    for _, wanted in ipairs(Recipes.ItemTypes(row)) do
        if wanted == numeric then return true end
    end
    return false
end

-- Device words too generic to identify a specific glider/mount. A row whose only
-- "signature" is one of these (e.g. a custom row whose name fell back to "Glider")
-- must NOT be allowed to match every equipped device.
local GENERIC_DEVICE_WORDS = {
    ["glider"] = true, ["wings"] = true, ["mount"] = true, ["pet"] = true,
    ["flight"] = true, ["companion"] = true, ["glider companion"] = true,
    ["detected"] = true, ["unknown"] = true, ["mount/pet"] = true
}

local function specificPatterns(row)
    local out = {}
    for _, pattern in ipairs(Recipes.Patterns(row)) do
        local wanted = Recipes.NormalizeName(pattern)
        if wanted ~= "" and not GENERIC_DEVICE_WORDS[wanted] then
            out[#out + 1] = wanted
        end
    end
    return out
end

function Recipes.DeviceMatches(row, device)
    if not row then return nil end
    local itemTypes = Recipes.ItemTypes(row)
    local patterns = specificPatterns(row)
    -- No usable signal (no item types, no specific name patterns): undecidable. Callers
    -- treat nil as "do not match" so an under-specified row never claims an arbitrary
    -- equipped device.
    if #itemTypes == 0 and #patterns == 0 then return nil end

    local deviceType = Recipes.ExtractItemType(device or {})
    if deviceType and Recipes.ItemTypeMatches(row, deviceType) then return true end

    local deviceName = Recipes.NormalizeName(device and device.name or "")
    if deviceName ~= "" then
        for _, wanted in ipairs(patterns) do
            -- Forward containment only: the equipped device's name must contain the row's
            -- signature pattern. The old reverse direction (wanted:find(deviceName)) let a
            -- short equipped-glider name match an unrelated longer tracked pattern, which
            -- grouped Invincible Flight under Sloth and made icons flip with the equip.
            if deviceName:find(wanted, 1, true) then return true end
        end
    end

    return false
end

return Recipes
