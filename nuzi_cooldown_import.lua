local api = require("api")
local OverlayUtils = require("power_ranger_on/overlay_utils")

local Import = {}

local NUZI_DEVICE_FILE = "nuzi-ui/.data/mount_glider_devices.txt"
local REFRESH_MS = 5000
local MOUNT_MANA_MATCH_TOLERANCE = 10
local MOUNT_MANA_UNITS = {"playerpet1", "playerpet", "slave", "playerpet2"}

local refreshElapsed = REFRESH_MS
local mountManaState = { initialized = false, unitId = nil, mana = 0 }

local function trimText(value)
    local text = tostring(value or "")
    return string.match(text, "^%s*(.-)%s*$") or text
end

local function normalizeText(value)
    local text = string.lower(trimText(value))
    return string.gsub(text, "%s+", " ")
end

local function appendNumericIds(out, value)
    if type(value) == "table" then
        for _, item in ipairs(value) do
            appendNumericIds(out, item)
        end
        return
    end
    local id = tonumber(value)
    if id and id > 0 then
        table.insert(out, math.floor(id + 0.5))
    end
end

local function firstNumericId(value)
    local ids = {}
    appendNumericIds(ids, value)
    return ids[1]
end

local function cooldownSecondsFromMs(value)
    local ms = tonumber(value)
    if not ms or ms <= 0 then return nil end
    return math.max(1, math.floor((ms / 1000) + 0.5))
end

local function deviceGroup(device)
    return tostring(device and device.kind or "") == "Mount" and "mount" or "glider"
end

local function deviceName(device, group)
    local fallback = group == "mount" and "Nuzi Mount" or "Nuzi Glider"
    local name = trimText(device and device.name or fallback)
    return name ~= "" and name or fallback
end

local function importKey(group, device, ability, suffix)
    return table.concat({
        "nuzi",
        tostring(group or ""),
        tostring(device and (device.key or device.name) or ""),
        tostring(ability and (ability.key or ability.label or ability.spell_id or ability.trigger_spell_id or ability.mount_mana_spent) or ""),
        tostring(suffix or "")
    }, ":")
end

local function addAbilityRow(rows, device, ability, group)
    if type(ability) ~= "table" then return end
    local cooldown = cooldownSecondsFromMs(ability.duration_ms)
    if not cooldown then return end
    local label = trimText(ability.label or ability.name or ability.key)
    if label == "" then return end

    local source = deviceName(device, group)
    local row = {
        enabled = true,
        nuziImported = true,
        recipeType = "nuzi",
        unit = "self",
        name = label,
        source = source,
        category = group,
        cooldown = cooldown,
        cooldownStartsOnActive = true,
        cooldownOnlyOnActive = true,
        icon = trimText(ability.icon_path or device and device.icon_path or "")
    }
    if row.icon == "" then row.icon = nil end
    if group == "glider" then
        row.gliderPattern = {normalizeText(source)}
    elseif group == "mount" then
        row.preferMountIcon = true
    end

    local ids = {}
    if ability.device_trigger == true then
        appendNumericIds(ids, ability.trigger_spell_id or ability.trigger_buff_id)
        if #ids == 0 then
            row.buffName = source
            row.buffNames = {source}
        end
    else
        appendNumericIds(ids, ability.buff_ids or ability.buff_id)
        if #ids == 0 and tostring(ability.icon_type or "") == "buff" then
            appendNumericIds(ids, ability.spell_id or ability.icon_id)
        end
    end

    if #ids > 0 then
        row.id = ids[1]
        row.buffIds = ids
        row.importKey = importKey(group, device, ability, "buff:" .. tostring(ids[1]))
        table.insert(rows.buffs, row)
        return
    end

    if row.buffName or (type(row.buffNames) == "table" and #row.buffNames > 0) then
        row.importKey = importKey(group, device, ability, "name:" .. normalizeText(row.buffName or source))
        table.insert(rows.buffs, row)
        return
    end

    local manaSpent = tonumber(ability.mount_mana_spent)
    if group == "mount" and manaSpent and manaSpent > 0 then
        row.mountManaSpent = math.floor(manaSpent + 0.5)
        row.importKey = importKey(group, device, ability, "mana:" .. tostring(row.mountManaSpent))
        table.insert(rows.buffs, row)
        return
    end

    local skillId = firstNumericId(ability.skill_ids or ability.skill_id or ability.spell_id)
    if skillId then
        row.id = skillId
        row.pattern = normalizeText(label)
        -- %.0f, not tostring: this client's tostring is %.6g and collapses 7-digit ids.
        row.importKey = importKey(group, device, ability, "skill:" .. string.format("%.0f", skillId))
        table.insert(rows.skills, row)
    end
end

local function addDeviceRows(rows, device, fallbackGroup)
    if type(device) ~= "table" then return end
    local group = fallbackGroup or deviceGroup(device)
    for _, ability in ipairs(device.abilities or {}) do
        addAbilityRow(rows, device, ability, group)
    end
end

local function rowsSignature(rows)
    local parts = {}
    for _, group in ipairs({"buffs", "skills"}) do
        for _, row in ipairs(rows[group] or {}) do
            table.insert(parts, tostring(row.importKey or row.name or ""))
        end
    end
    return table.concat(parts, "|")
end

local function findMountMana()
    for _, unit in ipairs(MOUNT_MANA_UNITS) do
        local unitId = OverlayUtils.safeCall(function() return api.Unit:GetUnitId(unit) end)
        if unitId ~= nil and tostring(unitId) ~= "" and tostring(unitId) ~= "0" then
            local mana = tonumber(OverlayUtils.safeCall(function() return api.Unit:UnitMana(unit) end)) or 0
            return tostring(unitId), mana
        end
    end
    return nil, 0
end

local function updateMountManaSpend()
    local unitId, mana = findMountMana()
    if not mountManaState.initialized then
        mountManaState.initialized = true
        mountManaState.unitId = unitId
        mountManaState.mana = mana
        return nil
    end
    local spent = nil
    if unitId and unitId == mountManaState.unitId then
        local previous = tonumber(mountManaState.mana) or 0
        local current = tonumber(mana) or 0
        if previous > current then
            spent = previous - current
        end
    end
    mountManaState.unitId = unitId
    mountManaState.mana = mana
    return spent
end

function Import.EmptyRows()
    return { buffs = {}, skills = {} }
end

function Import.AddElapsed(dt)
    refreshElapsed = refreshElapsed + (tonumber(dt) or 0)
end

function Import.Refresh(settings, force, currentRows)
    if force then refreshElapsed = REFRESH_MS end
    if not force and refreshElapsed < REFRESH_MS then
        return currentRows or Import.EmptyRows(), false
    end
    refreshElapsed = 0
    local oldSignature = rowsSignature(currentRows or Import.EmptyRows())
    local rows = Import.EmptyRows()

    if type(settings) == "table" and settings.importNuziCooldowns ~= false then
        local data = OverlayUtils.safeCall(function() return api.File:Read(NUZI_DEVICE_FILE) end)
        if type(data) == "table" then
            for _, device in ipairs(data.learned_mounts or {}) do
                addDeviceRows(rows, device, "mount")
            end
            for _, device in ipairs(data.learned_gliders or {}) do
                addDeviceRows(rows, device, "glider")
            end
        end
    end

    return rows, oldSignature ~= rowsSignature(rows)
end

function Import.UpdateMountManaCooldowns(rows, stateByKey, now, keyFn, mountIcon)
    local hasManaRows = false
    for _, row in ipairs(rows or {}) do
        if row.mountManaSpent then
            hasManaRows = true
            break
        end
    end
    if not hasManaRows then return end

    local spent = updateMountManaSpend()
    for _, row in ipairs(rows or {}) do
        if row.mountManaSpent then
            local key = keyFn(row)
            local state = stateByKey[key] or {}
            local wanted = tonumber(row.mountManaSpent)
            if wanted and spent and math.abs(spent - wanted) <= MOUNT_MANA_MATCH_TOLERANCE then
                state.active = false
                state.activatedAt = now
                state.readyAt = now + ((tonumber(row.cooldown) or 0) * 1000)
                state.name = row.name or tostring(row.mountManaSpent)
                state.icon = row.icon or mountIcon
                state.timeLeft = nil
            elseif state.readyAt and now >= state.readyAt then
                state.readyAt = nil
                state.activatedAt = nil
                state.timeLeft = nil
            end
            stateByKey[key] = state
        end
    end
end

function Import.Reset()
    refreshElapsed = REFRESH_MS
    mountManaState = { initialized = false, unitId = nil, mana = 0 }
end

return Import
