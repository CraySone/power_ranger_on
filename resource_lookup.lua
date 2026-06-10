local api = require("api")
local OverlayUtils = require("power_ranger_on/overlay_utils")
local CooldownRecipes = require("power_ranger_on/cooldown_recipes")

local ResourceLookup = {}

local buffIconCache = {}
local buffTooltipCache = {}
local skillIconCache = {}
local iconOverrides = {
    [8000798] = "game/ui/icon/icon_skill_seahorse02.dds"
}

-- Cache keys MUST go through formatBuffId, never tostring: this client's tostring is
-- %.6g, so all 7-digit ids print the same string. With tostring keys, sibling buffs
-- (Raijin run 8000208 / dash 8000211) shared ONE cache slot -- whichever resolved
-- first served its tooltip/name/icon for BOTH ids. Same for 7-digit item types
-- (all Flamefeather tiers 8001101..8001108 collided onto one icon slot).
function ResourceLookup.BuffTooltipById(id, optionalBuffHelper)
    if id == nil then return nil end
    local key = OverlayUtils.formatBuffId(id)
    if buffTooltipCache[key] ~= nil then return buffTooltipCache[key] or nil end
    local tooltip = OverlayUtils.safeCall(function() return api.Ability:GetBuffTooltip(tonumber(id), 0) end)
    if not tooltip then
        tooltip = OverlayUtils.safeCall(function() return api.Ability:GetBuffTooltip(tonumber(id), 1) end)
    end
    if not tooltip then
        tooltip = OverlayUtils.safeCall(function() return api.Ability.GetBuffTooltip(tonumber(id)) end)
    end
    if not tooltip and optionalBuffHelper and optionalBuffHelper.GetBuffName then
        local name = OverlayUtils.safeCall(function() return optionalBuffHelper.GetBuffName(OverlayUtils.formatBuffId(id)) end)
        if name then tooltip = { name = name } end
    end
    OverlayUtils.cachePut(buffTooltipCache, key, tooltip or false)
    return tooltip
end

function ResourceLookup.BuffIconById(id, optionalBuffHelper)
    local key = OverlayUtils.formatBuffId(id)
    if buffIconCache[key] ~= nil then return buffIconCache[key] end
    local tooltip = ResourceLookup.BuffTooltipById(id, optionalBuffHelper)
    local path = OverlayUtils.iconPath(tooltip)
    if not path and optionalBuffHelper and optionalBuffHelper.GetBuffIcon then
        path = OverlayUtils.safeCall(function() return optionalBuffHelper.GetBuffIcon(OverlayUtils.formatBuffId(id)) end)
    end
    OverlayUtils.cachePut(buffIconCache, key, path or false)
    return path
end

function ResourceLookup.ItemIconByType(itemType)
    local key = "item:" .. OverlayUtils.formatBuffId(itemType)
    if buffIconCache[key] ~= nil then return buffIconCache[key] or nil end
    local info = OverlayUtils.safeCall(function() return api.Item:GetItemInfoByType(tonumber(itemType)) end)
    local path = OverlayUtils.iconPath(info)
    OverlayUtils.cachePut(buffIconCache, key, path or false)
    return path
end

function ResourceLookup.CooldownAbilityIcon(row)
    if not row then return nil end
    local iconType = string.lower(tostring(row.icon_type or row.iconType or ""))
    local iconId = row.icon_id or row.iconId
    if iconId then
        local icon = ResourceLookup.IconPathByType(iconType, iconId)
        if icon then return icon end
    end
    local skillId = row.skillId or row.skill_id or row.id
    if skillId then
        local icon = ResourceLookup.SkillIconById(skillId) or ResourceLookup.BuffIconById(skillId)
        if icon then return icon end
    end
    if type(row.buffIds) == "table" and row.buffIds[1] then
        local icon = ResourceLookup.BuffIconById(row.buffIds[1])
        if icon then return icon end
    end
    if row.icon and row.icon ~= row.recipeDeviceIcon then return row.icon end
    return nil
end

function ResourceLookup.CooldownDeviceIcon(row)
    if not row then return nil end
    if row.recipeDeviceIconLocked and row.recipeDeviceIcon then return row.recipeDeviceIcon end
    if row.recipeDeviceItemType then
        local icon = ResourceLookup.ItemIconByType(row.recipeDeviceItemType)
        if icon then return icon end
    end
    if row.recipeDeviceIcon then return row.recipeDeviceIcon end
    if row.deviceIcon then return row.deviceIcon end
    local itemType = CooldownRecipes.FirstItemType(row)
    if itemType then
        local icon = ResourceLookup.ItemIconByType(itemType)
        if icon then return icon end
    end
    if row.icon and row.icon == row.recipeDeviceIcon then return row.icon end
    return nil
end

function ResourceLookup.CooldownRowIcon(row)
    return ResourceLookup.CooldownAbilityIcon(row) or ResourceLookup.CooldownDeviceIcon(row)
end

function ResourceLookup.IconPathByType(iconType, iconId)
    iconId = tonumber(iconId)
    if not iconId or iconId <= 0 then return nil end
    local override = iconOverrides[iconId]
    if override then return override end
    iconType = string.lower(tostring(iconType or "buff"))
    if iconType == "item" then return ResourceLookup.ItemIconByType(iconId) end
    if iconType == "skill" then return ResourceLookup.SkillIconById(iconId) end
    return ResourceLookup.BuffIconById(iconId) or ResourceLookup.SkillIconById(iconId) or ResourceLookup.ItemIconByType(iconId)
end

function ResourceLookup.BuffCooldownById(id, optionalBuffHelper)
    if not id then return 30 end
    if optionalBuffHelper and optionalBuffHelper.GetBuffCooldown then
        local cooldown = OverlayUtils.safeCall(function() return optionalBuffHelper.GetBuffCooldown(OverlayUtils.formatBuffId(id)) end)
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
        return OverlayUtils.safeCall(function() return optionalBuffHelper.GetBuffName(OverlayUtils.formatBuffId(id)) end)
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
    local key = OverlayUtils.formatBuffId(id)
    if skillIconCache[key] ~= nil then return skillIconCache[key] end
    local override = iconOverrides[tonumber(id)]
    if override then
        OverlayUtils.cachePut(skillIconCache, key, override)
        return override
    end
    local tooltip = OverlayUtils.safeCall(function() return api.Ability:GetBuffTooltip(tonumber(id), 0) end)
    local path = OverlayUtils.iconPath(tooltip)
    if not path then
        tooltip = OverlayUtils.safeCall(function() return api.Skill:GetSkillTooltip(tonumber(id)) end)
        path = OverlayUtils.iconPath(tooltip)
    end
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
