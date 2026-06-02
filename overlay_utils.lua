local OverlayUtils = {}

function OverlayUtils.safeCall(fn)
    local ok, a, b, c = pcall(fn)
    if ok then return a, b, c end
    return nil
end

function OverlayUtils.sameColor(a, b)
    return type(a) == "table" and type(b) == "table"
        and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

function OverlayUtils.textField(info, keys)
    for _, key in ipairs(keys) do
        local value = info and info[key]
        if value ~= nil and type(value) ~= "table" and type(value) ~= "function" and tostring(value) ~= "" and tostring(value) ~= "0" then
            return tostring(value)
        end
    end
    return nil
end

function OverlayUtils.numField(info, keys)
    for _, key in ipairs(keys) do
        local value = info and info[key]
        if type(value) == "number" then return value end
        if type(value) == "string" then
            local numeric = tonumber(value)
            if numeric ~= nil then return numeric end
        end
    end
    return nil
end

function OverlayUtils.firstNum(infos, keys)
    for _, info in ipairs(infos or {}) do
        local value = OverlayUtils.numField(info, keys)
        if value and value ~= 0 then return value end
    end
    return nil
end

function OverlayUtils.firstNumAllowZero(infos, keys)
    for _, info in ipairs(infos or {}) do
        local value = OverlayUtils.numField(info, keys)
        if value ~= nil then return value end
    end
    return nil
end

function OverlayUtils.patternNum(value, patterns, depth)
    if type(value) ~= "table" or (depth or 0) > 2 then return nil end
    for k, v in pairs(value) do
        local key = string.lower(tostring(k or ""))
        if type(v) == "number" or (type(v) == "string" and tonumber(v)) then
            for _, pattern in ipairs(patterns or {}) do
                if key:find(pattern, 1, true) then return tonumber(v) end
            end
        elseif type(v) == "table" then
            local found = OverlayUtils.patternNum(v, patterns, (depth or 0) + 1)
            if found then return found end
        end
    end
    return nil
end

function OverlayUtils.firstPatternNum(infos, patterns)
    for _, info in ipairs(infos or {}) do
        local value = OverlayUtils.patternNum(info, patterns, 0)
        if value and value ~= 0 then return value end
    end
    return nil
end

function OverlayUtils.defenseText(raw, pct)
    if raw and tonumber(raw) and tonumber(raw) > 0 then return tostring(math.floor(raw)) end
    if pct and tonumber(pct) and tonumber(pct) > 0 then
        local value = tonumber(pct)
        if value <= 1 then value = value * 100 end
        return tostring(math.floor(value + 0.5)) .. "%"
    end
    return "-"
end

function OverlayUtils.chanceText(value)
    if not value then return nil end
    value = tonumber(value)
    if not value then return nil end
    if value <= 1 then value = value * 100 end
    return tostring(math.floor(value + 0.5)) .. "%"
end

function OverlayUtils.valueText(value)
    if not value then return nil end
    value = tonumber(value)
    if not value then return nil end
    return tostring(math.floor(value + 0.5))
end

function OverlayUtils.iconPath(info)
    if type(info) ~= "table" then return nil end
    return OverlayUtils.textField(info, {
        "path", "icon", "iconPath", "icon_path", "iconTexture", "icon_texture",
        "texture", "image", "dds", "itemIcon", "item_icon"
    })
end

function OverlayUtils.itemName(info)
    if type(info) ~= "table" then return nil end
    return OverlayUtils.textField(info, {"name", "item_name", "itemName", "grade_name", "item_name_with_grade"})
end

function OverlayUtils.formatBuffId(id)
    local numeric = tonumber(id)
    if numeric then return string.format("%.0f", numeric) end
    return tostring(id or "")
end

function OverlayUtils.cooldownTimerText(value)
    local numeric = tonumber(value)
    if numeric then return tostring(math.max(0, math.ceil(numeric))) end
    if value ~= nil and tostring(value) ~= "" then return tostring(value) end
    return nil
end

function OverlayUtils.shortText(value, maxLen)
    value = tostring(value or "")
    if #value <= maxLen then return value end
    return value:sub(1, maxLen - 1) .. "."
end

function OverlayUtils.buffRemainText(ms)
    local value = tonumber(ms)
    if not value or value <= 0 then return nil end
    if value > 60000 then return tostring(math.ceil(value / 60000)) .. "m" end
    return tostring(math.ceil(value / 1000)) .. "s"
end

function OverlayUtils.cachePut(cache, key, value, maxEntries)
    local count = 0
    for _ in pairs(cache) do
        count = count + 1
        if count >= (maxEntries or 256) then
            for oldKey in pairs(cache) do cache[oldKey] = nil end
            break
        end
    end
    cache[key] = value
    return value
end

return OverlayUtils
