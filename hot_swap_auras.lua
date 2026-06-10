-- Hot Swap aura matching + auto-trigger predicates.
-- Pure helpers split out of hot_swap.lua: they operate on passed args + api + consts
-- and never touch Hot Swap settings or mutable module state, so they live cleanly here.

local api = require("api")

local HotSwapAuras = {}

local function safeCall(fn)
    local ok, a, b, c = pcall(fn)
    if ok then return a, b, c end
    return nil
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(value)
    return string.lower(trim(value))
end

local AUTO_SWIMMING_HINTS = {
    "rough sea winds"
}

local function customAuraKey(row)
    if type(row) ~= "table" then return nil end
    -- %.0f, not tostring: this client's tostring is %.6g and collapses 7-digit ids.
    if tonumber(row.id) then return "id:" .. string.format("%.0f", tonumber(row.id)) end
    local name = lower(row.name or row.pattern or row.buffName)
    if name == "" then return nil end
    return "name:" .. name
end

local function formatId(value)
    local numeric = tonumber(value)
    if numeric then return string.format("%.0f", numeric) end
    return tostring(value or "")
end

local function auraMatchFromRow(row)
    if type(row) ~= "table" then return nil end
    -- formatId for the id fallbacks: %.6g tostring would store "8.00021e+006" as the
    -- match query, which can never match a real aura name or id string.
    local name = trim(row.name or row.pattern or row.buffName or formatId(row.id))
    local id = tonumber(row.id)
    if name == "" and not id then return nil end
    return {
        id = id,
        name = name,
        query = trim(row.pattern or row.buffName or row.name or formatId(row.id)),
        source = row.source or "Detected"
    }
end

local function auraMatchKey(match)
    if type(match) ~= "table" then return nil end
    if tonumber(match.id) then return "id:" .. string.format("%.0f", tonumber(match.id)) end
    local name = lower(match.query or match.name)
    if name == "" then return nil end
    return "name:" .. name
end

local function normalizeCustomAura(entry)
    if type(entry) ~= "table" then return false end
    local changed = false
    if type(entry.matches) ~= "table" then
        entry.matches = {}
        local match = auraMatchFromRow(entry)
        if match then entry.matches[1] = match end
        changed = true
    end
    if not entry.key then
        local first = entry.matches and entry.matches[1]
        entry.key = auraMatchKey(first) or customAuraKey(entry)
        changed = true
    end
    return changed
end

local function customAuraHasMatch(entry, key)
    if type(entry) ~= "table" or not key then return false end
    if entry.key == key then return true end
    for _, match in ipairs(entry.matches or {}) do
        if auraMatchKey(match) == key then return true end
    end
    return false
end

local function auraId(aura)
    if type(aura) ~= "table" then return nil end
    return tonumber(aura.buff_id or aura.buffId or aura.id or aura.spellId or aura.spell_id)
end

local function auraName(aura)
    if type(aura) ~= "table" then return "" end
    for _, key in ipairs({"name", "buff_name", "buffName", "skill_name", "skillName", "title"}) do
        local value = trim(aura[key])
        if value ~= "" then return lower(value) end
    end
    local id = auraId(aura)
    if id and api.Ability and api.Ability.GetBuffTooltip then
        local tip = safeCall(function() return api.Ability:GetBuffTooltip(id, 1) end)
        if type(tip) == "table" then
            for _, key in ipairs({"name", "buffName", "buff_name", "title", "skillName", "skill_name"}) do
                local value = trim(tip[key])
                if value ~= "" then return lower(value) end
            end
        elseif type(tip) == "string" then
            return lower(tip)
        end
    end
    return ""
end

local function readPlayerAuras()
    local buffs, debuffs = {}, {}
    if not api.Unit then return buffs, debuffs end
    if api.Unit.UnitBuffCount and api.Unit.UnitBuff then
        local count = tonumber(safeCall(function() return api.Unit:UnitBuffCount("player") end)) or 0
        for i = 1, count do
            local aura = safeCall(function() return api.Unit:UnitBuff("player", i) end)
            if type(aura) == "table" then buffs[#buffs + 1] = aura end
        end
    end
    if api.Unit.UnitDeBuffCount and api.Unit.UnitDeBuff then
        local count = tonumber(safeCall(function() return api.Unit:UnitDeBuffCount("player") end)) or 0
        for i = 1, count do
            local aura = safeCall(function() return api.Unit:UnitDeBuff("player", i) end)
            if type(aura) == "table" then debuffs[#debuffs + 1] = aura end
        end
    end
    return buffs, debuffs
end

local function auraMatches(aura, query, wantedId)
    local id = auraId(aura)
    if wantedId and id and tonumber(wantedId) == id then return true end
    local text = lower(query)
    if text == "" then return false end
    local queryId = tonumber(text)
    if queryId and id and queryId == id then return true end
    local name = auraName(aura)
    return name ~= "" and name:find(text, 1, true) ~= nil
end

local function anyAuraMatches(buffs, debuffs, query, wantedId)
    for _, aura in ipairs(buffs or {}) do
        if auraMatches(aura, query, wantedId) then return true end
    end
    for _, aura in ipairs(debuffs or {}) do
        if auraMatches(aura, query, wantedId) then return true end
    end
    return false
end

local function customAuraMatches(entry, buffs, debuffs)
    if type(entry) ~= "table" then return false end
    normalizeCustomAura(entry)
    for _, match in ipairs(entry.matches or {}) do
        if anyAuraMatches(buffs, debuffs, match.query or match.name, match.id) then return true end
    end
    return anyAuraMatches(buffs, debuffs, entry.query or entry.name, entry.id)
end

local function swimmingActive(buffs, debuffs)
    return anyAuraMatches(buffs, debuffs, AUTO_SWIMMING_HINTS[1] or "rough sea winds")
end

local function sleepActive(buffs, debuffs)
    return anyAuraMatches(buffs, debuffs, "counting sheep", 4895)
        or anyAuraMatches(buffs, debuffs, "counting sheep", 7280)
        or anyAuraMatches(buffs, debuffs, "bat nap")
end

local function wakeupActive(buffs, debuffs)
    return anyAuraMatches(buffs, debuffs, "good day to work", 5207)
end

HotSwapAuras.customAuraKey = customAuraKey
HotSwapAuras.auraMatchFromRow = auraMatchFromRow
HotSwapAuras.auraMatchKey = auraMatchKey
HotSwapAuras.normalizeCustomAura = normalizeCustomAura
HotSwapAuras.customAuraHasMatch = customAuraHasMatch
HotSwapAuras.customAuraMatches = customAuraMatches
HotSwapAuras.auraId = auraId
HotSwapAuras.auraName = auraName
HotSwapAuras.readPlayerAuras = readPlayerAuras
HotSwapAuras.auraMatches = auraMatches
HotSwapAuras.anyAuraMatches = anyAuraMatches
HotSwapAuras.swimmingActive = swimmingActive
HotSwapAuras.sleepActive = sleepActive
HotSwapAuras.wakeupActive = wakeupActive

return HotSwapAuras
