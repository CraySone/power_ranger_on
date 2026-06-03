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

function Recipes.DeviceMatches(row, device)
    if not row then return nil end
    local itemTypes = Recipes.ItemTypes(row)
    local patterns = Recipes.Patterns(row)
    if #itemTypes == 0 and #patterns == 0 then return nil end

    local deviceType = Recipes.ExtractItemType(device or {})
    if deviceType and Recipes.ItemTypeMatches(row, deviceType) then return true end

    local deviceName = Recipes.NormalizeName(device and device.name or "")
    if deviceName ~= "" then
        for _, pattern in ipairs(patterns) do
            local wanted = Recipes.NormalizeName(pattern)
            if wanted ~= "" and (deviceName:find(wanted, 1, true) or wanted:find(deviceName, 1, true)) then
                return true
            end
        end
    end

    return false
end

return Recipes
