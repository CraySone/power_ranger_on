-- Skill/event probe text + serialization + stateless detection helpers.
-- Detector module split out of target_overlay.lua. Stateless helpers only; the
-- stateful probe runtime (snapshots, record/detect, event handlers) still lives in
-- target_overlay until it can be moved via ctx-injection against a running client.

local OverlayUtils = require("power_ranger_on/overlay_utils")
local unpackArgs = unpack or (table and table.unpack)

local SkillProbe = {}

-- Shallow, log-safe serialization: keep scalars, drop functions and nested tables.
function SkillProbe.serialValue(value)
    local valueType = type(value)
    if valueType == "number" or valueType == "string" or valueType == "boolean" then return value end
    if valueType ~= "table" then return tostring(value) end
    local out = {}
    for k, v in pairs(value) do
        if type(v) ~= "function" and type(v) ~= "table" then out[tostring(k)] = v end
    end
    return out
end

local PROBE_KEYWORDS = {
    "dash", "glider", "flight", "invincible", "invincibility",
    "invisible", "invisibility", "stealth", "stealthed", "camouflage",
    "protection", "amarendra", "meatball", "mount", "debuff", "buff",
    "charging", "charge", "veil", "kirin", "speed", "immunity", "immune", "wings"
}

SkillProbe.DETECTED_SKILL_KEYWORDS = {
    "dash", "glider", "flight", "invincible", "invincibility",
    "invisible", "invisibility", "stealth", "stealthed", "camouflage",
    "protection", "amarendra", "meatball", "mount", "golem",
    "charging", "charge", "veil", "kirin", "speed", "immunity", "immune", "wings"
}

local function appendProbeText(parts, value, depth)
    if value == nil or depth > 2 then return end
    local valueType = type(value)
    if valueType == "string" or valueType == "number" or valueType == "boolean" then
        table.insert(parts, tostring(value))
    elseif valueType == "table" then
        for k, v in pairs(value) do
            appendProbeText(parts, k, depth + 1)
            appendProbeText(parts, v, depth + 1)
        end
    end
end

function SkillProbe.probeText(result, args, source, target, combatEvent)
    local parts = { tostring(combatEvent or ""), tostring(source or ""), tostring(target or "") }
    appendProbeText(parts, result, 0)
    appendProbeText(parts, args, 0)
    return string.lower(table.concat(parts, " "))
end

function SkillProbe.hasProbeKeyword(text)
    for _, keyword in ipairs(PROBE_KEYWORDS) do
        if text:find(keyword, 1, true) then return true end
    end
    return false
end

-- Pure detection predicates (no module state / settings coupling).
function SkillProbe.auraLooksLikeCooldownSkill(aura)
    if type(aura) ~= "table" then return false end
    local name = string.lower(tostring(aura.name or ""))
    local desc = string.lower(tostring(aura.description or ""))
    local haystack = name .. " " .. desc
    local directNameHit = false
    for _, keyword in ipairs(SkillProbe.DETECTED_SKILL_KEYWORDS) do
        if haystack:find(keyword, 1, true) then directNameHit = true break end
    end
    if not directNameHit then return false end
    if name:find("equip ", 1, true) or name:find("leather set", 1, true) or name:find("armor", 1, true) then return false end
    if name:find("eanna", 1, true) or name:find("blessing", 1, true) then return false end
    local timeLeft = tonumber(aura.timeLeft)
    if timeLeft and timeLeft > 0 and timeLeft <= 600000 then return true end
    return haystack:find("cooldown", 1, true) or haystack:find("cannot be used", 1, true)
end

function SkillProbe.detectedSkillKey(skillName, skillId)
    local id = tonumber(skillId)
    if id then return "id:" .. tostring(id) end
    local name = string.lower(tostring(skillName or ""))
    if name == "" then return nil end
    return "name:" .. name
end

function SkillProbe.detectFallbackSkillName(flatText)
    for _, keyword in ipairs(SkillProbe.DETECTED_SKILL_KEYWORDS) do
        if flatText and flatText:find(keyword, 1, true) then
            if keyword == "invincible" or keyword == "invincibility" then return "Invincibility" end
            return keyword:sub(1, 1):upper() .. keyword:sub(2)
        end
    end
    return nil
end

function SkillProbe.parsedCombatMessage(combatEvent, args)
    if not ParseCombatMessage or not unpackArgs then return nil end
    return OverlayUtils.safeCall(function() return ParseCombatMessage(combatEvent, unpackArgs(args)) end)
end

function SkillProbe.extractSkillFields(result, args)
    local name = OverlayUtils.textField(result, {"spellName", "skillName", "abilityName", "name"})
    local id = tonumber(result and (result.spellId or result.abilityId or result.skillId or result.id))
    if name or id then return name, id end
    for _, value in ipairs(args or {}) do
        if type(value) == "table" then
            name = name or OverlayUtils.textField(value, {"spellName", "skillName", "abilityName", "name"})
            id = id or tonumber(value.spellId or value.abilityId or value.skillId or value.id)
        elseif type(value) == "string" and not name and #value > 1 then
            name = value
        elseif type(value) == "number" and not id then
            id = value
        end
    end
    return name, id
end

return SkillProbe
