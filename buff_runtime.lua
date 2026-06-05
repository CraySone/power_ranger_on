local api = require("api")
local OverlayUtils = require("power_ranger_on/overlay_utils")
local NuziCooldownImport = require("power_ranger_on/nuzi_cooldown_import")

local BuffRuntime = {}

local manaState = {
    initialized = false,
    mountKey = nil,
    mountMana = 0,
    playerMana = 0,
    mountSpent = 0,
    playerSpent = 0
}

local MANA_MOUNT_UNITS = {"playerpet1", "playerpet", "slave", "playerpet2"}
local MANA_TOLERANCE = 10

local function normalizeName(value)
    local text = string.lower(tostring(value or ""))
    text = string.gsub(text, "^%s+", ""):gsub("%s+$", "")
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^enhanced%s+", "")
    return text
end

local function numericList(...)
    local out = {}
    local values = {...}
    for _, value in pairs(values) do
        if type(value) == "table" then
            for _, item in ipairs(value) do
                local n = tonumber(item)
                if n and n > 0 then out[#out + 1] = math.floor(n + 0.5) end
            end
        else
            local n = tonumber(value)
            if n and n > 0 then out[#out + 1] = math.floor(n + 0.5) end
        end
    end
    return out
end

local function stringList(...)
    local out = {}
    local values = {...}
    for _, value in pairs(values) do
        if type(value) == "table" then
            for _, item in ipairs(value) do
                local text = tostring(item or "")
                if text ~= "" then out[#out + 1] = text end
            end
        else
            local text = tostring(value or "")
            if text ~= "" then out[#out + 1] = text end
        end
    end
    return out
end

local function auraId(ctx, aura)
    return ctx.buffId(aura)
end

local function auraName(ctx, aura)
    local id = auraId(ctx, aura)
    local tooltip = ctx.buffTooltipById(id)
    return ctx.buffName(aura) or OverlayUtils.textField(tooltip, {"name", "title", "buff_name"})
end

local function buildAuraScan(ctx)
    local scan = { byUnit = {}, byId = {}, all = {} }
    local units = {}
    local seen = {}
    local function addUnit(unit)
        unit = tostring(unit or "")
        if unit ~= "" and not seen[unit] then
            seen[unit] = true
            units[#units + 1] = unit
        end
    end
    addUnit("player")
    addUnit("playerpet")
    addUnit("playerpet1")
    addUnit("playerpet2")
    addUnit("slave")
    for _, unit in ipairs(ctx.selfBuffUnits or {}) do addUnit(unit) end
    for _, unit in ipairs(units) do
        local list = {}
        scan.byUnit[unit] = list
        local function addAura(kind, aura)
            if not aura then return end
            local id = auraId(ctx, aura)
            local entry = { aura = aura, unit = unit, kind = kind, id = id, name = auraName(ctx, aura) }
            list[#list + 1] = entry
            scan.all[#scan.all + 1] = entry
            if id then scan.byId[id] = entry end
        end
        local count = OverlayUtils.safeCall(function() return api.Unit:UnitBuffCount(unit) end) or 0
        for i = 1, tonumber(count) or 0 do
            addAura("buff", OverlayUtils.safeCall(function() return api.Unit:UnitBuff(unit, i) end))
        end
        local debuffCount = OverlayUtils.safeCall(function() return api.Unit:UnitDeBuffCount(unit) end) or 0
        for i = 1, tonumber(debuffCount) or 0 do
            addAura("debuff", OverlayUtils.safeCall(function() return api.Unit:UnitDeBuff(unit, i) end))
        end
    end
    return scan
end

local function rowIsGlider(row)
    return row and (row.gliderPattern or row.category == "glider" or row.recipeDeviceKind == "glider")
end

local function rowIsMount(row)
    return row and (row.category == "mount" or row.recipeDeviceKind == "mount" or row.preferMountIcon == true or row.mountNames ~= nil)
end

local function scanUnitsForRow(ctx, row)
    local unit = tostring(row and row.unit or "player")
    if unit == "self" or rowIsMount(row) then return ctx.selfBuffUnits or {"player"} end
    return {unit}
end

local function entryMatchesName(entry, wantedName)
    local needle = normalizeName(wantedName)
    if needle == "" then return false end
    local name = normalizeName(entry and entry.name)
    return name ~= "" and (name:find(needle, 1, true) ~= nil or needle:find(name, 1, true) ~= nil)
end

local function findScanId(ctx, scan, row, wantedId)
    wantedId = tonumber(wantedId)
    if not wantedId then return nil end
    for _, unit in ipairs(scanUnitsForRow(ctx, row)) do
        for _, entry in ipairs(scan.byUnit[unit] or {}) do
            if tonumber(entry.id) == wantedId then return entry.aura end
        end
    end
    return nil
end

local function findScanName(ctx, scan, row, wantedName)
    for _, unit in ipairs(scanUnitsForRow(ctx, row)) do
        for _, entry in ipairs(scan.byUnit[unit] or {}) do
            if entryMatchesName(entry, wantedName) then return entry.aura end
        end
    end
    return nil
end

local function numberInList(value, list)
    value = tonumber(value)
    if not value or type(list) ~= "table" then return false end
    for _, item in ipairs(list) do
        if tonumber(item) == value then return true end
    end
    return false
end

local function entryMatchesAnyName(entry, names)
    for _, name in ipairs(names or {}) do
        if entryMatchesName(entry, name) then return true end
    end
    return false
end

local function findScanIdGuarded(ctx, scan, row, wantedId)
    wantedId = tonumber(wantedId)
    if not wantedId then return nil end
    local genericIds = numericList(row and row.genericBuffIds, row and row.generic_buff_ids)
    local names = stringList(row and row.buffNames, row and row.buffName)
    local needsNameMatch = numberInList(wantedId, genericIds) and #names > 0
    for _, unit in ipairs(scanUnitsForRow(ctx, row)) do
        for _, entry in ipairs(scan.byUnit[unit] or {}) do
            if tonumber(entry.id) == wantedId and (not needsNameMatch or entryMatchesAnyName(entry, names)) then
                return entry.aura
            end
        end
    end
    return nil
end

local function hasRequiredAura(ctx, scan, row)
    local ids = numericList(row and row.requiredBuffId, row and row.req_buff, row and row.requiredBuffIds)
    for _, id in ipairs(ids) do
        if findScanId(ctx, scan, row, id) then return true end
    end
    local names = stringList(row and row.requiredBuffName, row and row.requiredBuffNames)
    for _, name in ipairs(names) do
        if findScanName(ctx, scan, row, name) then return true end
    end
    return #ids == 0 and #names == 0
end

local function mountNameMatches(row, mount)
    local gates = stringList(row and row.mountNames, row and row.mountName, row and row.mount_name)
    if #gates == 0 then return true end
    local current = normalizeName(mount and mount.name)
    if current == "" then return false end
    for _, gateValue in ipairs(gates) do
        local gate = normalizeName(gateValue)
        if gate ~= "" and (current:find(gate, 1, true) ~= nil or gate:find(current, 1, true) ~= nil) then
            return true
        end
    end
    return false
end

local function currentMountMana()
    for _, unit in ipairs(MANA_MOUNT_UNITS) do
        local mana = tonumber(OverlayUtils.safeCall(function() return api.Unit:UnitMana(unit) end)) or 0
        if mana > 0 then
            local info = OverlayUtils.safeCall(function() return api.Unit:UnitInfo(unit) end) or {}
            local name = OverlayUtils.textField(info, {"mate_npc_name", "mateNpcName", "name", "unitName", "unit_name"}) or unit
            return unit .. ":" .. tostring(name or ""), mana
        end
    end
    return nil, 0
end

local function updateManaState()
    local mountKey, mountMana = currentMountMana()
    local playerMana = tonumber(OverlayUtils.safeCall(function() return api.Unit:UnitMana("player") end)) or 0
    manaState.mountSpent = 0
    manaState.playerSpent = 0
    if not manaState.initialized or tostring(mountKey or "") ~= tostring(manaState.mountKey or "") then
        manaState.initialized = true
        manaState.mountKey = mountKey
        manaState.mountMana = mountMana
        manaState.playerMana = playerMana
        return
    end
    manaState.mountSpent = math.max(0, (tonumber(manaState.mountMana) or 0) - mountMana)
    manaState.playerSpent = math.max(0, (tonumber(manaState.playerMana) or 0) - playerMana)
    manaState.mountMana = mountMana
    manaState.playerMana = playerMana
end

local function spentMatches(spent, wanted)
    wanted = tonumber(wanted)
    if not wanted or wanted <= 0 then return false end
    spent = tonumber(spent) or 0
    return spent >= math.max(1, wanted - MANA_TOLERANCE) and spent <= wanted + MANA_TOLERANCE
end

local function mountDeathSeconds(row)
    return tonumber(row and (row.mountDeathCooldown or row.mountDeathDuration or row.mount_death_duration)) or 0
end

local function currentMountHealth()
    for _, unit in ipairs(MANA_MOUNT_UNITS) do
        local hp = tonumber(OverlayUtils.safeCall(function() return api.Unit:UnitHealth(unit) end))
        if hp ~= nil then return hp end
    end
    return nil
end

local function findBuffInUnit(ctx, unit, wantedId)
    local count = OverlayUtils.safeCall(function() return api.Unit:UnitBuffCount(unit) end) or 0
    for i = 1, tonumber(count) or 0 do
        local buff = OverlayUtils.safeCall(function() return api.Unit:UnitBuff(unit, i) end)
        if ctx.buffId(buff) == tonumber(wantedId) then return buff end
    end
    local debuffCount = OverlayUtils.safeCall(function() return api.Unit:UnitDeBuffCount(unit) end) or 0
    for i = 1, tonumber(debuffCount) or 0 do
        local buff = OverlayUtils.safeCall(function() return api.Unit:UnitDeBuff(unit, i) end)
        if ctx.buffId(buff) == tonumber(wantedId) then return buff end
    end
    return nil
end

local function auraMatchesName(ctx, aura, wantedName)
    local needle = string.lower(tostring(wantedName or ""))
    if needle == "" then return false end
    local id = ctx.buffId(aura)
    local tooltip = ctx.buffTooltipById(id)
    local name = string.lower(tostring(ctx.buffName(aura) or OverlayUtils.textField(tooltip, {"name", "title", "buff_name"}) or ""))
    local desc = string.lower(tostring(OverlayUtils.textField(tooltip, {"description", "desc", "tooltip"}) or ""))
    return name:find(needle, 1, true) ~= nil or desc:find(needle, 1, true) ~= nil
end

local function findBuffByNameInUnit(ctx, unit, wantedName)
    local count = OverlayUtils.safeCall(function() return api.Unit:UnitBuffCount(unit) end) or 0
    for i = 1, tonumber(count) or 0 do
        local buff = OverlayUtils.safeCall(function() return api.Unit:UnitBuff(unit, i) end)
        if auraMatchesName(ctx, buff, wantedName) then return buff end
    end
    local debuffCount = OverlayUtils.safeCall(function() return api.Unit:UnitDeBuffCount(unit) end) or 0
    for i = 1, tonumber(debuffCount) or 0 do
        local buff = OverlayUtils.safeCall(function() return api.Unit:UnitDeBuff(unit, i) end)
        if auraMatchesName(ctx, buff, wantedName) then return buff end
    end
    return nil
end

local function findBuff(ctx, unit, wantedId)
    if unit == "self" then
        for _, token in ipairs(ctx.selfBuffUnits or {}) do
            local buff = findBuffInUnit(ctx, token, wantedId)
            if buff then return buff end
        end
        return nil
    end
    return findBuffInUnit(ctx, unit or "player", wantedId)
end

local function findBuffByName(ctx, unit, wantedName)
    if unit == "self" then
        for _, token in ipairs(ctx.selfBuffUnits or {}) do
            local buff = findBuffByNameInUnit(ctx, token, wantedName)
            if buff then return buff end
        end
        return nil
    end
    return findBuffByNameInUnit(ctx, unit or "player", wantedName)
end

local function findTrackedBuff(ctx, row)
    if ctx.auraScan then
        local ids = numericList(row and row.buffIds, row and row.buff_ids, row and row.id, row and row.buff_id)
        for _, id in ipairs(ids) do
            local buff = findScanIdGuarded(ctx, ctx.auraScan, row, id)
            if buff then return buff end
        end
        if row and row.matchByIdOnly then return nil end
        local names = stringList(row and row.buffNames, row and row.buffName)
        for _, name in ipairs(names) do
            local buff = findScanName(ctx, ctx.auraScan, row, name)
            if buff then return buff end
        end
        return nil
    end
    if row.buffIds then
        for _, id in ipairs(row.buffIds) do
            local buff = findBuff(ctx, row.unit or "player", id)
            if buff then return buff end
        end
    end
    if row and row.matchByIdOnly then return nil end
    if row.buffNames then
        for _, name in ipairs(row.buffNames) do
            local buff = findBuffByName(ctx, row.unit or "player", name)
            if buff then return buff end
        end
        return nil
    end
    if row.buffName then return findBuffByName(ctx, row.unit or "player", row.buffName) end
    return findBuff(ctx, row.unit or "player", row.id)
end

local function triggerBuffFreshEnough(ctx, row, buff)
    local minLeft = tonumber(row and row.triggerMinTimeLeftMs)
    if (not minLeft or minLeft <= 0) and ctx.isStarTriggerCooldown(row) then
        minLeft = 5300
    end
    if not minLeft or minLeft <= 0 then return true end
    local timeLeft = tonumber(buff and buff.timeLeft)
    return timeLeft and timeLeft > minLeft
end

local function triggerByMana(row)
    if spentMatches(manaState.mountSpent, row and (row.mountManaSpent or row.petManaSpent or row.mana_trigger)) then return true end
    if spentMatches(manaState.playerSpent, row and (row.playerManaSpent or row.player_mana)) then return true end
    return false
end

local function startManualCooldown(ctx, row, state, now, mount, glider)
    local cooldownMs = (tonumber(row.cooldown) or 0) * 1000
    if cooldownMs <= 0 then return state end
    state.active = false
    state.activatedAt = now
    state.readyAt = now + cooldownMs
    state.name = row.name or row.buffName or tostring(row.id or "")
    state.icon = ctx.cooldownRowIcon(row) or ctx.buffIconById(row.id) or (row.gliderPattern and glider and glider.icon)
    state.timeLeft = nil
    return state
end

local function setActiveFromBuff(ctx, row, state, now, buff, mount, glider)
    if state.active ~= true then
        state.activatedAt = now
        if row.cooldownStartsOnActive then
            local cooldownMs = (tonumber(row.cooldown) or 0) * 1000
            state.readyAt = now + cooldownMs
        end
    end
    state.active = true
    state.lastSeen = now
    if row.cooldownStartsOnActive and state.readyAt and now >= state.readyAt then state.readyAt = nil end
    if not row.cooldownStartsOnActive then state.readyAt = nil end
    state.name = row.name or ctx.buffName(buff) or tostring(row.id)
    state.icon = ctx.cooldownRowIcon(row) or OverlayUtils.iconPath(buff) or ctx.buffIconById(row.id) or (row.gliderPattern and glider and glider.icon)
    state.timeLeft = buff.timeLeft
    return state
end

function BuffRuntime.Update(ctx)
    local now = api.Time:GetUiMsec()
    local glider = ctx.equippedGliderSnapshot()
    local mount = ctx.mountedPetSnapshot()
    ctx.auraScan = buildAuraScan(ctx)
    updateManaState()
    NuziCooldownImport.UpdateMountManaCooldowns(ctx.nuziBuffRows, ctx.buffState, now, ctx.trackedBuffKey, mount and mount.icon)
    for _, row in ipairs(ctx.allTrackedBuffRows()) do
        local key = ctx.trackedBuffKey(row)
        if row.enabled == false then
            ctx.buffState[key] = nil
            local triggerKey = ctx.trackedBuffTriggerKey(row)
            if ctx.triggerState[triggerKey] and ctx.triggerState[triggerKey].rowKey == key then
                ctx.triggerState[triggerKey] = nil
            end
        else
            local state = ctx.buffState[key] or {}
            local mountMatches = mountNameMatches(row, mount)
            local mountHp = currentMountHealth()
            if mountHp and mountHp > 0 then state._deathTriggered = nil end

            local gliderMatches = ctx.trackedGliderMatches(row, glider)

            local triggerKey = ctx.trackedBuffTriggerKey(row)
            local trigger = ctx.triggerState[triggerKey]
            local buff = nil

            if rowIsGlider(row) then
                if row.cooldownStartsOnActive and hasRequiredAura(ctx, ctx.auraScan, row) then
                    local visibleBuff = findTrackedBuff(ctx, row)
                    if not visibleBuff then
                        ctx.triggerState[triggerKey] = nil
                        trigger = nil
                    elseif not triggerBuffFreshEnough(ctx, row, visibleBuff) then
                        buff = nil
                    elseif trigger and trigger.rowKey then
                        if trigger.rowKey == key then buff = visibleBuff end
                    elseif gliderMatches then
                        ctx.triggerState[triggerKey] = { rowKey = key, startedAt = now }
                        buff = visibleBuff
                    end
                elseif gliderMatches and hasRequiredAura(ctx, ctx.auraScan, row) then
                    buff = findTrackedBuff(ctx, row)
                end
            elseif rowIsMount(row) then
                if mountMatches then
                    buff = findTrackedBuff(ctx, row)
                end
            else
                buff = findTrackedBuff(ctx, row)
            end

            if buff and triggerBuffFreshEnough(ctx, row, buff) then
                local wasActive = state.active == true
                state = setActiveFromBuff(ctx, row, state, now, buff, mount, glider)
                if not wasActive and ctx.settings.skillProbeLogging == true and ctx.recordSkillProbe then
                    ctx.recordSkillProbe({
                        event = "TRACKED_BUFF_ACTIVE",
                        unit = tostring(row.unit or "player"),
                        buffId = tonumber(row.id),
                        buffName = row.buffName,
                        glider = row.gliderPattern and ctx.serialValue(glider) or nil,
                        name = row.name or ctx.buffName(buff) or tostring(row.id),
                        aura = ctx.serialValue(buff)
                    })
                end
            elseif mountDeathSeconds(row) > 0 and mountMatches and mountHp == 0 then
                if not state._deathTriggered then
                    local originalCooldown = row.cooldown
                    row.cooldown = mountDeathSeconds(row)
                    state = startManualCooldown(ctx, row, state, now, mount, glider)
                    row.cooldown = originalCooldown
                    state._deathTriggered = true
                end
            elseif row.mountManaSpent or row.petManaSpent or row.mana_trigger or row.playerManaSpent or row.player_mana then
                if mountMatches and hasRequiredAura(ctx, ctx.auraScan, row) and triggerByMana(row) then
                    state = startManualCooldown(ctx, row, state, now, mount, glider)
                elseif state.active then
                    state.active = false
                    state.timeLeft = nil
                elseif state.readyAt and now >= state.readyAt then
                    state.readyAt = nil
                    state.activatedAt = nil
                end
            elseif state.active then
                state.active = false
                if not row.cooldownStartsOnActive then
                    local cooldownMs = (tonumber(row.cooldown) or 0) * 1000
                    state.readyAt = (state.activatedAt or now) + cooldownMs
                    if state.readyAt < now then state.readyAt = now end
                end
                state.name = row.name or state.name or tostring(row.id)
                state.icon = row.gliderPattern and (ctx.cooldownRowIcon(row) or state.icon) or (state.icon or ctx.buffIconById(row.id) or ctx.cooldownRowIcon(row))
                state.timeLeft = nil
                if ctx.settings.skillProbeLogging == true and ctx.recordSkillProbe then
                    ctx.recordSkillProbe({
                        event = "TRACKED_BUFF_COOLDOWN",
                        unit = tostring(row.unit or "player"),
                        buffId = tonumber(row.id),
                        buffName = row.buffName,
                        glider = row.gliderPattern and ctx.serialValue(glider) or nil,
                        name = state.name,
                        cooldown = tonumber(row.cooldown) or 0,
                        readyIn = state.readyAt and math.ceil((state.readyAt - now) / 1000) or 0
                    })
                end
            elseif state.readyAt and now >= state.readyAt then
                state.readyAt = nil
                state.timeLeft = nil
                state.activatedAt = nil
            else
                state.icon = row.gliderPattern and (ctx.cooldownRowIcon(row) or state.icon) or (state.icon or ctx.buffIconById(row.id) or ctx.cooldownRowIcon(row))
                state.timeLeft = nil
            end
            ctx.buffState[key] = state
        end
    end
end

return BuffRuntime
