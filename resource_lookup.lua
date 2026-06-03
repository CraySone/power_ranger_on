local api = require("api")
local OverlayUtils = require("power_ranger_on/overlay_utils")
local CooldownRecipes = require("power_ranger_on/cooldown_recipes")

local ResourceLookup = {}

local buffIconCache = {}
local buffTooltipCache = {}
local skillIconCache = {}

function ResourceLookup.BuffTooltipById(id, optionalBuffHelper)
    if id == nil then return nil end
    local key = tostring(id or "")
    if buffTooltipCache[key] ~= nil then return buffTooltipCache[key] or nil end
    local tooltip = OverlayUtils.safeCall(function() return api.Ability:GetBuffTooltip(tonumber(id), 1) end)
    if not tooltip then
        tooltip = OverlayUtils.safeCall(function() return api.Ability.GetBuffTooltip(tonumber(id)) end)
    end
    if not tooltip and optionalBuffHelper and optionalBuffHelper.GetBuffName then
        local name = OverlayUtils.safeCall(function() return optionalBuffHelper.GetBuffName(tostring(id)) end)
        if name then tooltip = { name = name } end
    end
    OverlayUtils.cachePut(buffTooltipCache, key, tooltip or false)
    return tooltip
end

function ResourceLookup.BuffIconById(id, optionalBuffHelper)
    local key = tostring(id or "")
    if buffIconCache[key] ~= nil then return buffIconCache[key] end
    local tooltip = ResourceLookup.BuffTooltipById(id, optionalBuffHelper)
    local path = OverlayUtils.iconPath(tooltip)
    if not path and optionalBuffHelper and optionalBuffHelper.GetBuffIcon then
        path = OverlayUtils.safeCall(function() return optionalBuffHelper.GetBuffIcon(tostring(id)) end)
    end
    OverlayUtils.cachePut(buffIconCache, key, path or false)
    return path
end

function ResourceLookup.ItemIconByType(itemType)
    local key = "item:" .. tostring(itemType or "")
    if buffIconCache[key] ~= nil then return buffIconCache[key] or nil end
    local info = OverlayUtils.safeCall(function() return api.Item:GetItemInfoByType(tonumber(itemType)) end)
    local path = OverlayUtils.iconPath(info)
    OverlayUtils.cachePut(buffIconCache, key, path or false)
    return path
end

function ResourceLookup.CooldownRowIcon(row)
    if not row then return nil end
    local itemType = CooldownRecipes.FirstItemType(row)
    if itemType then
        local icon = ResourceLookup.ItemIconByType(itemType)
        if icon then return icon end
    end
    return row.icon
end

function ResourceLookup.BuffCooldownById(id, optionalBuffHelper)
    if not id then return 30 end
    if optionalBuffHelper and optionalBuffHelper.GetBuffCooldown then
        local cooldown = OverlayUtils.safeCall(function() return optionalBuffHelper.GetBuffCooldown(tostring(id)) end)
        cooldown = tonumber(cooldown)
        if cooldown and cooldown > 0 then return cooldown end
    end
    return 30
end

function ResourceLookup.BuffNameById(id, optionalBuffHelper)
    local tooltip = ResourceLookup.BuffTooltipById(id, optionalBuffHelper)
    local name = OverlayUtils.textField(tooltip, {"name", "title", "buff_name"})
    if name then return name end
    if optionalBuffHelper and optionalBuffHelper.GetBuffName then
        return OverlayUtils.safeCall(function() return optionalBuffHelper.GetBuffName(tostring(id)) end)
    end
    return nil
end

function ResourceLookup.DetectedCooldown(name, id, fallback, optionalBuffHelper)
    local lowerName = string.lower(tostring(name or ""))
    if lowerName:find("invisible predator", 1, true)
        or lowerName:find("insibile predator", 1, true)
        or (lowerName:find("predator", 1, true) and lowerName:find("invis", 1, true)) then
        return 60
    end
    local cooldown = tonumber(fallback)
    if cooldown and cooldown > 0 then return cooldown end
    return ResourceLookup.BuffCooldownById(id, optionalBuffHelper) or 30
end

function ResourceLookup.SkillIconById(id)
    if id == nil then return nil end
    local key = tostring(id or "")
    if skillIconCache[key] ~= nil then return skillIconCache[key] end
    local tooltip = OverlayUtils.safeCall(function() return api.Skill:GetSkillTooltip(tonumber(id)) end)
    local path = OverlayUtils.iconPath(tooltip)
    if not path then
        tooltip = OverlayUtils.safeCall(function() return api.Ability:GetBuffTooltip(tonumber(id), 1) end)
        path = OverlayUtils.iconPath(tooltip)
    end
    OverlayUtils.cachePut(skillIconCache, key, path or false)
    return path
end

function ResourceLookup.Clear()
    buffIconCache = {}
    buffTooltipCache = {}
    skillIconCache = {}
end

return ResourceLookup
