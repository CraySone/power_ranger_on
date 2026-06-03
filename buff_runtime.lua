local api = require("api")
local OverlayUtils = require("power_ranger_on/overlay_utils")
local NuziCooldownImport = require("power_ranger_on/nuzi_cooldown_import")

local BuffRuntime = {}

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
    if row.buffIds then
        for _, id in ipairs(row.buffIds) do
            local buff = findBuff(ctx, row.unit or "player", id)
            if buff then return buff end
        end
    end
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

function BuffRuntime.Update(ctx)
    local now = api.Time:GetUiMsec()
    local glider = ctx.equippedGliderSnapshot()
    local mount = ctx.mountedPetSnapshot()
    NuziCooldownImport.UpdateMountManaCooldowns(ctx.nuziBuffRows, ctx.buffState, now, ctx.trackedBuffKey, mount and mount.icon)
    local learnedGliderIcon = false
    for _, row in ipairs(ctx.allTrackedBuffRows()) do
        local key = ctx.trackedBuffKey(row)
        if row.enabled == false then
            ctx.buffState[key] = nil
            local triggerKey = ctx.trackedBuffTriggerKey(row)
            if ctx.triggerState[triggerKey] and ctx.triggerState[triggerKey].rowKey == key then
                ctx.triggerState[triggerKey] = nil
            end
        elseif row.mountManaSpent then
            ctx.buffState[key] = ctx.buffState[key] or {}
        else
            local state = ctx.buffState[key] or {}
            local gliderMatches = ctx.trackedGliderMatches(row, glider)
            if row.gliderPattern and gliderMatches and glider.icon and not row.icon then
                row.icon = glider.icon
                learnedGliderIcon = true
            end
            local triggerKey = ctx.trackedBuffTriggerKey(row)
            local trigger = ctx.triggerState[triggerKey]
            local buff = nil
            if row.cooldownStartsOnActive and (row.gliderPattern or row.category == "glider") then
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
            elseif gliderMatches then
                buff = findTrackedBuff(ctx, row)
            end

            if buff then
                if state.active ~= true then
                    state.activatedAt = now
                    if row.cooldownStartsOnActive then
                        local cooldownMs = (tonumber(row.cooldown) or 0) * 1000
                        state.readyAt = now + cooldownMs
                    end
                    if ctx.settings.skillProbeLogging == true and ctx.recordSkillProbe then
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
                end
                state.active = true
                state.lastSeen = now
                if row.cooldownStartsOnActive and state.readyAt and now >= state.readyAt then state.readyAt = nil end
                if not row.cooldownStartsOnActive then state.readyAt = nil end
                state.name = row.name or ctx.buffName(buff) or tostring(row.id)
                state.icon = (row.preferMountIcon and mount.icon) or (row.gliderPattern and (ctx.cooldownRowIcon(row) or glider.icon)) or ctx.cooldownRowIcon(row) or OverlayUtils.iconPath(buff) or ctx.buffIconById(row.id)
                state.timeLeft = buff.timeLeft
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
    if learnedGliderIcon and ctx.saveSettings then ctx.saveSettings() end
end

return BuffRuntime
