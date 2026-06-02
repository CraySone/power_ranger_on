local api = require("api")
local RoleHelper = require("power_ranger_on/role_helper")
local BuffDetector = require("power_ranger_on/buff_detector")
local OverlayUtils = require("power_ranger_on/overlay_utils")
local Compat = require("power_ranger_on/compat")
local NuziCooldownImport = require("power_ranger_on/nuzi_cooldown_import")

local TargetOverlay = {}
TargetOverlay.cooldawnBuffList = OverlayUtils.safeCall(function() return require("CooldawnBuffTracker/buff_helper") end)
TargetOverlay.simpleStatsGrid = {
    pdef = 0,
    mdef = 0,
    resilience = 0,
    toughness = 0,
    block = 1,
    parry = 1,
    evasion = 1
}
TargetOverlay.compactStatsOrder = {
    pdef = 1,
    mdef = 2,
    resilience = 3,
    toughness = 4,
    block = 1,
    parry = 2,
    evasion = 3
}

local ADDON_ID = "power_ranger_on"
local TARGET_UPDATE_MS = 100
local SELF_UPDATE_MS = 50
local PROBE_LOG_INTERVAL_MS = 250

local COLORS = {
    gold = {1, 0.84, 0, 1},
    white = {1, 1, 1, 1},
    muted = {0.64, 0.66, 0.70, 1},
    blue = {0.45, 0.72, 1, 1},
    green = {0.38, 0.95, 0.44, 1},
    dark = {0.06, 0.06, 0.068, 0.96},
    panel = {0.045, 0.045, 0.052, 0.84},
    button = {0.14, 0.14, 0.16, 0.95},
    active = {0.12, 0.28, 0.15, 0.95}
}

local defaults = {
    showModelOverlay = true,
    showArmorIcon = true,
    showWeaponIcon = true,
    showRoleIcon = true,
    showModelGearscore = true,
    showModelClass = true,
    showModelRange = true,
    showModelDefense = true,
    compactModelOverlay = true,
    nuziUiCompatMode = "auto",
    compactModelLeftOffset = 45,
    overlayTextShadow = true,
    uiScaleLevel = 0,
    targetWindowScaleLevel = 0,
    selfScaleLevel = 0,
    showTargetWindow = true,
    compactTargetWindow = true,
    testTargetWindow = false,
    importNuziCooldowns = true,
    simpleSpacingVersion = 6,
    simpleColumnGap = 0,
    simpleLineGap = 0,
    showInfoRange = true,
    showInfoClass = true,
    showInfoGearscore = true,
    showInfoGuild = true,
    showInfoFamily = true,
    showOwnershipLabels = true,
    showInfoDefense = true,
    showInfoPdef = true,
    showInfoMdef = true,
    showInfoBlock = true,
    showInfoParry = true,
    showInfoEvasion = true,
    showInfoToughness = false,
    showInfoResilience = false,
    showSelfPanel = true,
    showSelfCooldowns = true,
    showSelfEquipment = true,
    cooldownSettingsPage = 1,
    skillProbeLogging = false,
    detectedSkillsX = 760,
    detectedSkillsY = 260,
    ownershipWindowX = 860,
    ownershipWindowY = 280,
    ownershipScaleLevel = 0,
    targetInfoColors = {
        range = {1, 0.84, 0, 1},
        class = {0.82, 0.90, 1, 1},
        gearscore = {0.38, 0.95, 0.44, 1},
        guild = {0.62, 0.82, 1, 1},
        family = {1, 0.78, 0.52, 1},
        pdef = {1, 1, 1, 1},
        mdef = {0.72, 0.86, 1, 1},
        block = {0.78, 0.92, 1, 1},
        parry = {1, 0.92, 0.62, 1},
        evasion = {0.70, 1, 0.70, 1},
        toughness = {1, 0.72, 0.72, 1},
        resilience = {0.90, 0.72, 1, 1}
    },
    targetWindowX = 860,
    targetWindowY = 330,
    selfX = 860,
    selfY = 470,
    settingsX = 650,
    settingsY = 210,
    trackedBuffs = {
        { unit = "player", id = 131, name = "Invinc", source = "Player", cooldown = 120, fixedCooldown = true },
        { unit = "self", name = "Sloth Glider", source = "Sloth", buffName = "Star Divine Protection", buffNames = {"Star Divine Protection", "Star's Divine Protection", "Starfall"}, gliderPattern = {"sloth"}, cooldown = 10, cooldownStartsOnActive = true, cooldownOnlyOnActive = true, triggerMinTimeLeftMs = 5300, fixedCooldown = true },
        { unit = "self", name = "Crystal Wings", source = "Crystal Wings", buffName = "Star Divine Protection", buffNames = {"Star Divine Protection", "Star's Divine Protection", "Starfall", "Charging"}, gliderPattern = {"crystal wings"}, cooldown = 60, cooldownStartsOnActive = true, cooldownOnlyOnActive = true, triggerMinTimeLeftMs = 5300, fixedCooldown = true },
        { unit = "self", name = "Magicopter", source = "Cumulus Magithopter", buffName = "Star Divine Protection", buffNames = {"Star Divine Protection", "Star's Divine Protection", "Starfall"}, gliderPattern = {"cumulus magicopter", "cumulus magithopter", "magicopter", "magithopter"}, cooldown = 45, cooldownStartsOnActive = true, cooldownOnlyOnActive = true, triggerMinTimeLeftMs = 5300, fixedCooldown = true, icon = "Game\\ui\\icon\\icon_item_4138.dds" },
        { unit = "self", id = 3636, name = "Ezi Glider", source = "Ezi", buffName = "Invincible Flight", buffNames = {"Invincible Flight", "Invincibility Flight"}, gliderPattern = {"ezi", "ezi's glider"}, cooldown = 60, cooldownStartsOnActive = true, fixedCooldown = true, itemType = 18174 },
        { unit = "self", id = 3636, name = "Flamefeather", source = "Flamefeather Glider", buffName = "Invincible Flight", buffNames = {"Invincible Flight", "Invincibility Flight"}, gliderPattern = {"flamefeather glider", "enhanced flamefeather glider", "flamefeather"}, cooldown = 60, cooldownStartsOnActive = true, triggerMinTimeLeftMs = 500, fixedCooldown = true, itemType = 8001101, category = "glider" },
        { unit = "self", id = 30570, name = "Snowflake", source = "Snowflake Wings", buffName = "Snowflake Flight", buffNames = {"Snowflake Flight"}, gliderPattern = {"snowflake wings", "snowflake"}, cooldown = 60, cooldownStartsOnActive = true, fixedCooldown = true, icon = "Game\\ui\\icon\\icon_skill_glider_snowflake02.dds" },
        { unit = "self", id = 3523, name = "Dash", source = "Ser Meatball", cooldown = 30, preferMountIcon = true },
        { unit = "self", id = 8000211, name = "Dash", source = "Mount", cooldown = 30, preferMountIcon = true, icon = "Game\\ui\\icon\\icon_skill_wild03.dds" },
        { unit = "self", id = 21817, name = "Kirin Speed", source = "Kirin", cooldown = 35, cooldownStartsOnActive = true, fixedCooldown = true, preferMountIcon = true, icon = "Game\\ui\\icon\\icon_skill_karon01.dds" },
        { unit = "playerpet", name = "Nui's Veil", source = "Mount", buffName = "Nui's Veil", buffNames = {"Nui's Veil"}, cooldown = 30, cooldownAura = true, fixedCooldown = true, preferMountIcon = true, icon = "Game\\ui\\icon\\icon_skill_tare01.dds" },
        { unit = "self", id = 15068, name = "Golem Invinc", source = "Golem", cooldown = 33, cooldownStartsOnActive = true, fixedCooldown = true },
    },
    trackedSkills = {},
    detectedSkills = {}
}

local DEPRECATED_TRACKED_BUFFS = {
    ["playerpet:545"] = true,
    ["self:8000566"] = true,
    ["self:22290"] = true,
    ["self:30779"] = true,
    ["self:30780"] = true,
    ["self:20121"] = true,
    ["self:name:nui's veil:nui's veil"] = true,
    ["self:name:star divine protection:flamefeather"] = true
}

local DEPRECATED_TRACKED_SKILL_PATTERNS = {
    flight = true,
    ["invincible flight"] = true
}

local function trackedBuffSettingKey(row)
    if row and row.importKey then return tostring(row.importKey) end
    local unit = tostring(row and row.unit or "player")
    if row and row.id then
        if row.gliderPattern or row.category == "glider" then
            return unit .. ":" .. tostring(row.id) .. ":glider:" .. string.lower(tostring(row.name or row.source or ""))
        end
        return unit .. ":" .. tostring(row.id)
    end
    if row and row.buffName then
        return unit .. ":name:" .. string.lower(tostring(row.buffName)) .. ":" .. string.lower(tostring(row.name or ""))
    end
    return unit .. ":name:" .. string.lower(tostring(row and row.name or ""))
end

local CONFIG = {
    roleIconSize = 20,
    buffIconSize = 25,
    fontSize = 12,
    healthbarOffset = -15,
    compactHealthbarOffset = -25,
    armorBuffOffset = 45,
    weaponBuffOffset = -45,
    compactModelLeftOffset = 45,
    gearscoreOffset = 5,
    classOffset = 2,
    roleIconSpacing = -2,
    defenseOffset = 2,
    rangeOffset = -18,
    maxScreenDistance = 120,
    gsColorMin = 3000,
    gsColorMax = 9000
}

local SELF_PANEL = {
    maxRowIcons = 10,
    iconSize = 28,
    iconStep = 32,
    left = 8,
    headerHeight = 20,
    gliderY = 24,
    mountY = 64,
    equipY = 106,
    minWidth = 140,
    height = 146
}

local BUFF_CATEGORIES = {
    armor = {713, 714, 16551, 715, 716, 16552, 717, 740, 16553},
    weapon = {16557, 8227, 16558, 4899, 8226, 16559}
}
local SELF_BUFF_UNITS = {"player", "playerpet", "playerpet1", "playerpet2", "slave"}

local COLOR_CHOICES = {
    {1, 1, 1, 1},
    {1, 0.84, 0, 1},
    {0.62, 0.82, 1, 1},
    {0.38, 0.95, 0.44, 1},
    {1, 0.72, 0.72, 1},
    {0.90, 0.72, 1, 1}
}

local TARGET_INFO_FIELDS = {
    { key = "guild", setting = "showInfoGuild", label = "Guild" },
    { key = "family", setting = "showInfoFamily", label = "Family" },
    { key = "class", setting = "showInfoClass", label = "Class" },
    { key = "gearscore", setting = "showInfoGearscore", label = "Gearscore" },
    { key = "range", setting = "showInfoRange", label = "Range" },
    { key = "pdef", setting = "showInfoPdef", label = "PDef" },
    { key = "mdef", setting = "showInfoMdef", label = "MDef" },
    { key = "block", setting = "showInfoBlock", label = "Block" },
    { key = "parry", setting = "showInfoParry", label = "Parry" },
    { key = "evasion", setting = "showInfoEvasion", label = "Evasion" },
    { key = "toughness", setting = "showInfoToughness", label = "Tough" },
    { key = "resilience", setting = "showInfoResilience", label = "Resil" }
}

local settings = nil
local mainCanvas = nil
local armorBuffIcon = nil
local weaponBuffIcon = nil
local targetRoleIcon = nil
local targetGearscoreLabel = nil
local targetClassLabel = nil
local targetPdefTitleLabel = nil
local targetPdefValueLabel = nil
local targetMdefTitleLabel = nil
local targetMdefValueLabel = nil
local targetRangeCanvas = nil
local targetRangeLabel = nil
local targetInfoWnd = nil
local ownershipWnd = nil
local selfWnd = nil
local settingsWnd = nil
local detectedSkillsWnd = nil
local eventWnd = nil
local curTargetIcon = nil
local lastScreenPosition = ""
local previousTargetId = nil
local modelDataTargetId = nil
local targetTokenMisses = 0
local targetInfoMisses = 0
local screenPositionMisses = 0
local updateElapsed = TARGET_UPDATE_MS
local selfUpdateElapsed = SELF_UPDATE_MS
local compatState = Compat.Resolve(defaults)
local compatRefreshElapsed = 1000
local nuziCooldownRows = NuziCooldownImport.EmptyRows()
local buffState = {}
local triggerState = {}
local buffIconCache = {}
local buffTooltipCache = {}
local skillIconCache = {}
local skillCooldowns = {}
local playerName = nil
local skillProbe = { entries = {}, maxEntries = 240 }
local skillProbeDirty = false
local lastSkillProbeSave = 0
local probeLogElapsed = 0
local lastSelfEquipmentUpdate = 0
local unpackArgs = unpack or (table and table.unpack)
local recordSkillProbe
local recordDetectedSkill
local serialValue
local refreshSettingsButtons
local refreshDetectedSkillRows

local function updateCompatState(force)
    compatRefreshElapsed = force and 1000 or compatRefreshElapsed
    if force or compatRefreshElapsed >= 1000 then
        compatRefreshElapsed = 0
        compatState = Compat.Resolve(settings)
    end
    return compatState
end

local function refreshNuziCooldownRows(force)
    if not Compat.ShouldShowOptions(compatState) then
        local changed = #(nuziCooldownRows.buffs or {}) > 0 or #(nuziCooldownRows.skills or {}) > 0
        if changed then
            nuziCooldownRows = NuziCooldownImport.EmptyRows()
            NuziCooldownImport.Reset()
            if TargetOverlay.refreshEventSubscriptions then
                TargetOverlay.refreshEventSubscriptions()
            end
        end
        return changed
    end

    local rows, changed = NuziCooldownImport.Refresh(settings, force, nuziCooldownRows)
    nuziCooldownRows = rows
    if changed and TargetOverlay.refreshEventSubscriptions then
        TargetOverlay.refreshEventSubscriptions()
    end
    return changed
end

local function allTrackedBuffRows()
    local rows = {}
    for _, row in ipairs(settings and settings.trackedBuffs or {}) do
        table.insert(rows, row)
    end
    for _, row in ipairs(nuziCooldownRows.buffs or {}) do
        table.insert(rows, row)
    end
    return rows
end

local function allTrackedSkillRows()
    local rows = {}
    for _, row in ipairs(settings and settings.trackedSkills or {}) do
        table.insert(rows, row)
    end
    for _, row in ipairs(nuziCooldownRows.skills or {}) do
        table.insert(rows, row)
    end
    return rows
end

local function copyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                local out = {}
                if #v > 0 then
                    for i, row in ipairs(v) do
                        out[i] = {}
                        for rk, rv in pairs(row) do out[i][rk] = rv end
                    end
                else
                    for rk, rv in pairs(v) do
                        if type(rv) == "table" then
                            out[rk] = {}
                            for nk, nv in pairs(rv) do out[rk][nk] = nv end
                        else
                            out[rk] = rv
                        end
                    end
                end
                dst[k] = out
            else
                dst[k] = v
            end
        end
    end
end

local function addMissingTrackedBuffDefaults()
    settings.trackedBuffs = settings.trackedBuffs or {}
    local function copyRow(row)
        local copy = {}
        for k, v in pairs(row or {}) do copy[k] = v end
        return copy
    end
    local function mergedRow(defaultRow, existing)
        local copy = copyRow(defaultRow or existing)
        if defaultRow and existing then
            if existing.cooldown ~= nil and not defaultRow.fixedCooldown then copy.cooldown = existing.cooldown end
            if existing.enabled ~= nil then copy.enabled = existing.enabled end
            if existing.source ~= nil then copy.source = existing.source end
            if existing.icon ~= nil and copy.icon == nil then copy.icon = existing.icon end
            if defaultRow.icon ~= nil then copy.icon = defaultRow.icon end
            if existing.mount ~= nil and copy.source == nil then copy.source = existing.mount end
            copy.unit = defaultRow.unit
            copy.id = defaultRow.id
            copy.buffName = defaultRow.buffName
            copy.buffNames = defaultRow.buffNames
            copy.gliderPattern = defaultRow.gliderPattern
            copy.itemType = defaultRow.itemType
            copy.category = defaultRow.category
            copy.fixedCooldown = defaultRow.fixedCooldown
            copy.cooldownStartsOnActive = defaultRow.cooldownStartsOnActive
            copy.cooldownOnlyOnActive = defaultRow.cooldownOnlyOnActive
            copy.triggerMinTimeLeftMs = defaultRow.triggerMinTimeLeftMs
            if defaultRow.name == "Sloth Glider" then
                copy.source = defaultRow.source
                if existing.icon == "Game\\ui\\icon\\icon_item_1648.dds" then copy.icon = nil end
            end
        end
        return copy
    end
    local defaultsByKey = {}
    for _, row in ipairs(defaults.trackedBuffs or {}) do
        defaultsByKey[trackedBuffSettingKey(row)] = row
    end
    local ordered = {}
    local usedKeys = {}
    for _, existing in ipairs(settings.trackedBuffs) do
        local recoverableStarRecipe = existing.buffName == "Star Divine Protection"
            and not existing.gliderPattern
            and existing.name
            and existing.name ~= existing.buffName
        if recoverableStarRecipe then
            existing.category = "glider"
            existing.recipeType = "glider"
            existing.gliderPattern = {string.lower(tostring(existing.name))}
            existing.cooldownOnlyOnActive = true
            existing.triggerMinTimeLeftMs = 5300
        end
        local key = trackedBuffSettingKey(existing)
        local staleGenericStar = existing.buffName == "Star Divine Protection" and not existing.gliderPattern and not recoverableStarRecipe
        if not usedKeys[key] and not DEPRECATED_TRACKED_BUFFS[key] and not staleGenericStar then
            local defaultRow = defaultsByKey[key]
            if defaultRow or existing.id or existing.buffName then
                if not defaultRow and existing.gliderPattern and not existing.fixedCooldown and existing.recipeType ~= "glider" and existing.category ~= "glider" then
                    existing.gliderPattern = nil
                    existing.category = nil
                end
                if not defaultRow and existing.cooldownStartsOnActive == nil then
                    existing.cooldownStartsOnActive = true
                end
                if not defaultRow then
                    existing.cooldown = TargetOverlay.detectedCooldown(existing.name or existing.buffName, existing.id, existing.cooldown)
                    existing.category = existing.category or TargetOverlay.detectedCooldownCategory(existing.name or existing.buffName, existing.source, existing.unit)
                end
                if existing.cooldownStartsOnActive == nil then
                    existing.cooldownStartsOnActive = true
                end
                table.insert(ordered, mergedRow(defaultRow, existing))
                usedKeys[key] = true
            end
        end
    end
    for _, row in ipairs(defaults.trackedBuffs or {}) do
        local key = trackedBuffSettingKey(row)
        if not usedKeys[key] then
            table.insert(ordered, copyRow(row))
            usedKeys[key] = true
        end
    end
    for _, row in ipairs(ordered) do
        if row.cooldownStartsOnActive == nil then row.cooldownStartsOnActive = true end
    end
    settings.trackedBuffs = ordered
end

local function trackedCooldownIsHardcoded(skillName, skillId)
    local id = tonumber(skillId)
    local lowerName = string.lower(tostring(skillName or ""))
    local rows = (settings and settings.trackedBuffs) or defaults.trackedBuffs or {}
    for _, row in ipairs(rows) do
        local rowId = tonumber(row.id)
        if id and rowId and id == rowId then return true end
        if lowerName ~= "" then
            if row.buffName and lowerName == string.lower(tostring(row.buffName)) then return true end
            for _, name in ipairs(row.buffNames or {}) do
                if lowerName == string.lower(tostring(name or "")) then return true end
            end
            local rowName = string.lower(tostring(row.name or ""))
            if rowName ~= "" and rowName ~= "dash" and (lowerName == rowName or lowerName:find(rowName, 1, true) or rowName:find(lowerName, 1, true)) then
                return true
            end
            for _, pattern in ipairs(row.gliderPattern or {}) do
                local gliderName = string.lower(tostring(pattern or ""))
                if gliderName ~= "" and (lowerName == gliderName or lowerName:find(gliderName, 1, true) or gliderName:find(lowerName, 1, true)) then
                    return true
                end
            end
        end
    end
    return false
end

local function cleanDeprecatedTrackedSkills()
    settings.trackedSkills = settings.trackedSkills or {}
    local cleaned = {}
    for _, row in ipairs(settings.trackedSkills) do
        local name = string.lower(tostring(row.name or row.pattern or ""))
        local id = tostring(row.id or row.skillId or "")
        local staleFlight = name:find("flight", 1, true) and not row.icon and id == ""
        local deprecated = DEPRECATED_TRACKED_SKILL_PATTERNS[name] or staleFlight or id == "3636" or id == "8000566" or trackedCooldownIsHardcoded(row.name or row.pattern, row.id or row.skillId)
        if not deprecated then table.insert(cleaned, row) end
    end
    settings.trackedSkills = cleaned
end

local function cleanHardcodedDetectedSkills()
    settings.detectedSkills = settings.detectedSkills or {}
    local cleaned = {}
    for _, row in ipairs(settings.detectedSkills) do
        if not trackedCooldownIsHardcoded(row.name or row.pattern, row.id) then
            table.insert(cleaned, row)
        end
    end
    settings.detectedSkills = cleaned
end

local function loadSettings()
    settings = api.GetSettings(ADDON_ID) or {}
    local simpleSpacingVersion = tonumber(settings.simpleSpacingVersion) or 1
    local hadSimpleSpacing = settings.simpleColumnGap ~= nil or settings.simpleLineGap ~= nil
    copyDefaults(settings, defaults)
    if simpleSpacingVersion < 2 and hadSimpleSpacing then
        settings.simpleColumnGap = (tonumber(settings.simpleColumnGap) or 0) + 8
        settings.simpleLineGap = (tonumber(settings.simpleLineGap) or 0) + 4
    end
    if simpleSpacingVersion < 3 and hadSimpleSpacing then
        settings.simpleColumnGap = (tonumber(settings.simpleColumnGap) or 0) + 10
    end
    if simpleSpacingVersion < 4 and hadSimpleSpacing then
        settings.simpleColumnGap = (tonumber(settings.simpleColumnGap) or 0) + 10
    end
    if simpleSpacingVersion < 5 and hadSimpleSpacing then
        settings.simpleColumnGap = (tonumber(settings.simpleColumnGap) or 0) + 10
    end
    if simpleSpacingVersion < 6 and hadSimpleSpacing then
        settings.simpleColumnGap = (tonumber(settings.simpleColumnGap) or 0) + 5
    end
    settings.simpleSpacingVersion = 6
    if settings.compactTargetWindow and settings.testTargetWindow then
        settings.compactTargetWindow = false
    end
    settings.compactModelLeftOffset = math.max(20, math.min(140, tonumber(settings.compactModelLeftOffset) or CONFIG.compactModelLeftOffset))
    settings.overlayShadowSize = nil
    settings.simpleColumnGap = math.max(0, math.min(73, tonumber(settings.simpleColumnGap) or 0))
    settings.simpleLineGap = math.max(0, math.min(23, tonumber(settings.simpleLineGap) or 0))
    if settings.showInfoDefense == false then
        if settings.showInfoPdef == nil then settings.showInfoPdef = false end
        if settings.showInfoMdef == nil then settings.showInfoMdef = false end
    end
    settings.targetInfoColors = settings.targetInfoColors or {}
    for key, color in pairs(defaults.targetInfoColors or {}) do
        if type(settings.targetInfoColors[key]) ~= "table" then
            settings.targetInfoColors[key] = {color[1], color[2], color[3], color[4]}
        end
    end
    if not settings.trackedBuffs then settings.trackedBuffs = defaults.trackedBuffs end
    addMissingTrackedBuffDefaults()
    if not settings.trackedSkills then settings.trackedSkills = {} end
    cleanDeprecatedTrackedSkills()
    for _, row in ipairs(settings.trackedSkills or {}) do
        row.category = row.category or TargetOverlay.detectedCooldownCategory(row.name or row.pattern, row.source, row.unit)
    end
    settings.detectedSkills = {}
    settings.skillProbeLogging = false
    updateCompatState(true)
    refreshNuziCooldownRows(true)
end

local function saveSettings()
    pcall(function() api.SaveSettings() end)
end

local function setTextColor(widget, color)
    if widget and widget.style and widget.style.SetColor then
        widget.style:SetColor(color[1], color[2], color[3], color[4])
    end
end

local function settingColor(key)
    local color = settings and settings.targetInfoColors and settings.targetInfoColors[key]
    return type(color) == "table" and color or COLORS.white
end

local function cycleSettingColor(key)
    settings.targetInfoColors = settings.targetInfoColors or {}
    local cur = settings.targetInfoColors[key]
    local nextIndex = 1
    for i, color in ipairs(COLOR_CHOICES) do
        if OverlayUtils.sameColor(cur, color) then
            nextIndex = (i % #COLOR_CHOICES) + 1
            break
        end
    end
    local picked = COLOR_CHOICES[nextIndex]
    settings.targetInfoColors[key] = {picked[1], picked[2], picked[3], picked[4]}
    saveSettings()
end

local function addBg(parent, r, g, b, a)
    local bg = parent:CreateColorDrawable(r, g, b, a, "background")
    bg:AddAnchor("TOPLEFT", parent, 0, 0)
    bg:AddAnchor("BOTTOMRIGHT", parent, 0, 0)
    bg:Show(true)
    return bg
end

local function label(parent, id, text, x, y, w, h, size, color, align)
    local l = api.Interface:CreateWidget("label", id, parent)
    l:SetExtent(w, h)
    l:AddAnchor("TOPLEFT", parent, x, y)
    l.style:SetFontSize(size or 12)
    l.style:SetAlign(align or ALIGN.LEFT)
    if l.style.SetShadow then l.style:SetShadow(false) end
    if l.style.SetOutline then l.style:SetOutline(false) end
    setTextColor(l, color or COLORS.white)
    l:SetText(text or "")
    l:Show(true)
    return l
end

local function flatButton(parent, id, text, x, y, w, h, tone, onClick)
    local btn = api.Interface:CreateWidget("button", id, parent)
    btn:SetExtent(w, h)
    btn:AddAnchor("TOPLEFT", parent, x, y)
    btn:SetText("")
    local border = btn:CreateColorDrawable(0, 0, 0, 0.92, "background")
    border:AddAnchor("TOPLEFT", btn, 0, 0)
    border:AddAnchor("BOTTOMRIGHT", btn, 0, 0)
    border:Show(true)
    local fill = btn:CreateColorDrawable((tone or COLORS.button)[1], (tone or COLORS.button)[2], (tone or COLORS.button)[3], (tone or COLORS.button)[4], "background")
    fill:AddAnchor("TOPLEFT", btn, 1, 1)
    fill:AddAnchor("BOTTOMRIGHT", btn, -1, -1)
    fill:Show(true)
    local txt = label(btn, id .. "_txt", text, 1, 2, w - 2, h - 4, 11, COLORS.white, ALIGN.CENTER)
    txt:Clickable(false)
    btn._fill = fill
    btn._text = txt
    function btn:SetCleanText(value) self._text:SetText(value or "") end
    function btn:SetTone(color) self._fill:SetColor(color[1], color[2], color[3], color[4]) end
    if onClick then btn:SetHandler("OnClick", onClick) end
    btn:Show(true)
    return btn
end

local function cooldownEdit(parent, id, x, y, w, h)
    local edit = W_CTRL and W_CTRL.CreateEdit and W_CTRL.CreateEdit(id, parent) or parent:CreateChildWidget("edit", id, 0, true)
    local border = parent:CreateColorDrawable(0, 0, 0, 0.95, "background")
    border:SetExtent(w + 2, h + 2)
    border:AddAnchor("TOPLEFT", parent, x - 1, y - 1)
    border:Show(true)
    edit:SetExtent(w, h)
    edit:AddAnchor("TOPLEFT", parent, x, y)
    local plate = edit:CreateColorDrawable(0.10, 0.10, 0.11, 0.96, "background")
    plate:AddAnchor("TOPLEFT", edit, 0, 0)
    plate:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
    plate:Show(true)
    if edit.SetMaxTextLength then edit:SetMaxTextLength(4) end
    if edit.style then
        edit.style:SetColor(1, 1, 1, 1)
        edit.style:SetAlign(ALIGN.CENTER)
        edit.style:SetFontSize(10)
    end
    edit:SetHandler("OnTextChanged", function(self)
        if self._settingText then return end
        local value = tonumber(self:GetText())
        if not value then return end
        value = math.max(0, math.min(999, math.floor(value + 0.5)))
        local list = self.entryKind == "skill" and settings.trackedSkills or settings.trackedBuffs
        local row = list and list[self.entryIndex]
        if not row then return end
        row.cooldown = value
        row.cooldownSeconds = nil
        if self.entryKind == "buff" then row.cooldownStartsOnActive = true end
        saveSettings()
    end)
    if edit.Raise then edit:Raise() end
    edit:Show(true)
    return edit
end

local function panel(parent, id, x, y, w, h)
    local p = parent:CreateChildWidget("emptywidget", id, 0, true)
    p:SetExtent(w, h)
    p:AddAnchor("TOPLEFT", parent, x, y)
    addBg(p, COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], COLORS.panel[4])
    p:Show(true)
    return p
end

local function sectionPanel(parent, id, x, y, w, h, titleText)
    local p = panel(parent, id, x, y, w, h)
    local header = p:CreateColorDrawable(0.09, 0.09, 0.11, 0.95, "background")
    header:SetExtent(w, 24)
    header:AddAnchor("TOPLEFT", p, 0, 0)
    header:Show(true)
    local accent = p:CreateColorDrawable(1, 0.84, 0, 0.85, "background")
    accent:SetExtent(4, 24)
    accent:AddAnchor("TOPLEFT", p, 0, 0)
    accent:Show(true)
    label(p, id .. "_title", titleText or "", 14, 4, w - 28, 16, 12, COLORS.gold, ALIGN.LEFT)
    return p
end

local function colorCube(parent, id, x, y, key)
    local btn = api.Interface:CreateWidget("button", id, parent)
    btn:SetExtent(20, 20)
    btn:AddAnchor("TOPLEFT", parent, x, y)
    btn:SetText("")
    local border = btn:CreateColorDrawable(0, 0, 0, 0.96, "background")
    border:AddAnchor("TOPLEFT", btn, 0, 0)
    border:AddAnchor("BOTTOMRIGHT", btn, 0, 0)
    border:Show(true)
    local fill = btn:CreateColorDrawable(1, 1, 1, 1, "background")
    fill:AddAnchor("TOPLEFT", btn, 3, 3)
    fill:AddAnchor("BOTTOMRIGHT", btn, -3, -3)
    fill:Show(true)
    btn._fill = fill
    btn._colorKey = key
    btn:SetHandler("OnClick", function()
        cycleSettingColor(key)
        refreshSettingsButtons()
    end)
    btn:Show(true)
    return btn
end

local function setToggleButton(btn, enabled, text)
    if not btn then return end
    btn:SetCleanText(text .. (enabled and " ON" or " OFF"))
    btn:SetTone(enabled and COLORS.active or COLORS.button)
end

local function uiScaleFactor(key)
    return 1 + ((tonumber(settings and settings[key or "uiScaleLevel"]) or 0) * 0.1)
end

local function trackedBuffKey(row)
    return trackedBuffSettingKey(row)
end

local function trackedBuffTriggerKey(row)
    if row and row.importKey then return "trigger:" .. tostring(row.importKey) end
    local unit = tostring(row and row.unit or "player")
    local gliderPart = ""
    if row and (row.gliderPattern or row.category == "glider") then
        gliderPart = ":glider:" .. string.lower(tostring(row.name or row.source or ""))
    end
    if row and row.buffNames and row.buffNames[1] then
        return unit .. ":trigger:" .. string.lower(tostring(row.buffNames[1])) .. gliderPart
    end
    if row and row.buffName then return unit .. ":trigger:" .. string.lower(tostring(row.buffName)) .. gliderPart end
    if row and row.id then return unit .. ":trigger:" .. tostring(row.id) .. gliderPart end
    return trackedBuffKey(row)
end

function TargetOverlay.clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if maxValue < minValue then return minValue end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function TargetOverlay.safeWindowPosition(x, y, width, height)
    local screenWidth = tonumber(api.Interface:GetScreenWidth()) or 1920
    local screenHeight = tonumber(api.Interface:GetScreenHeight()) or 1080
    if screenWidth <= 0 then screenWidth = 1920 end
    if screenHeight <= 0 then screenHeight = 1080 end
    local pad = 12
    local maxX = screenWidth - (tonumber(width) or 1) - pad
    local maxY = screenHeight - (tonumber(height) or 1) - pad
    return TargetOverlay.clamp(x, pad, maxX), TargetOverlay.clamp(y, pad, maxY)
end

function TargetOverlay.windowPosition(window)
    if not window then return nil, nil end
    if window.GetEffectiveOffset then
        local x, y = window:GetEffectiveOffset()
        if tonumber(x) and tonumber(y) then return x, y end
    end
    if window.GetOffset then
        local x, y = window:GetOffset()
        if tonumber(x) and tonumber(y) then return x, y end
    end
    return nil, nil
end

function TargetOverlay.saveWindowPosition(window, keyX, keyY)
    local x, y = TargetOverlay.windowPosition(window)
    if not tonumber(x) or not tonumber(y) then return end
    settings[keyX] = math.floor(tonumber(x) + 0.5)
    settings[keyY] = math.floor(tonumber(y) + 0.5)
    saveSettings()
end

local function applyDrag(window, handle, keyX, keyY, allowPlainDrag)
    local function startDrag()
        if not allowPlainDrag and not (api.Input and api.Input:IsShiftKeyDown()) then return end
        if window.StartMoving then window:StartMoving() end
        if api.Cursor and api.Cursor.ClearCursor then api.Cursor:ClearCursor() end
    end
    local function stopDrag()
        if window.StopMovingOrSizing then window:StopMovingOrSizing() end
        if api.Cursor and api.Cursor.ClearCursor then api.Cursor:ClearCursor() end
        TargetOverlay.saveWindowPosition(window, keyX, keyY)
    end
    if window.EnableDrag then window:EnableDrag(true) end
    if window.RegisterForDrag then window:RegisterForDrag("LeftButton") end
    if window.SetHandler then
        window:SetHandler("OnDragStart", startDrag)
        window:SetHandler("OnDragStop", stopDrag)
        window:SetHandler("OnDragEnd", stopDrag)
    end
    if handle then
        if handle.EnableDrag then handle:EnableDrag(true) end
        if handle.RegisterForDrag then handle:RegisterForDrag("LeftButton") end
        if handle.SetHandler then
            handle:SetHandler("OnDragStart", startDrag)
            handle:SetHandler("OnDragStop", stopDrag)
            handle:SetHandler("OnDragEnd", stopDrag)
        end
    end
end

local function applyHandleDrag(window, handle, keyX, keyY)
    local function startDrag()
        if not (api.Input and api.Input:IsShiftKeyDown()) then return end
        if window.StartMoving then window:StartMoving() end
        if api.Cursor and api.Cursor.ClearCursor then api.Cursor:ClearCursor() end
    end
    local function stopDrag()
        if window.StopMovingOrSizing then window:StopMovingOrSizing() end
        if api.Cursor and api.Cursor.ClearCursor then api.Cursor:ClearCursor() end
        TargetOverlay.saveWindowPosition(window, keyX, keyY)
    end
    if handle then
        if handle.Clickable then handle:Clickable(true) end
        if handle.EnableDrag then handle:EnableDrag(true) end
        if handle.RegisterForDrag then handle:RegisterForDrag("LeftButton") end
        if handle.SetHandler then
            handle:SetHandler("OnDragStart", startDrag)
            handle:SetHandler("OnDragStop", stopDrag)
            handle:SetHandler("OnDragEnd", stopDrag)
        end
    end
end

function TargetOverlay.getDistance(token)
    local d = tonumber(OverlayUtils.safeCall(function() return api.Unit:UnitDistance(token) end))
    if not d then return nil end
    return math.floor(d + 0.5)
end

function TargetOverlay.getGearscoreColor(gearscore)
    local gs = tonumber(gearscore) or 0
    if gs < CONFIG.gsColorMin then return 0, 1, 0 end
    if gs >= CONFIG.gsColorMax then return 1, 0, 0 end
    local factor = (gs - CONFIG.gsColorMin) / (CONFIG.gsColorMax - CONFIG.gsColorMin)
    return factor, 1 - factor, 0
end

function TargetOverlay.isBuffInCategory(buffId, category)
    for _, id in ipairs(category) do
        if buffId == id then return true end
    end
    return false
end

function TargetOverlay.findBuffByCategory(trackedBuffs, category)
    for _, buff in ipairs(trackedBuffs) do
        if TargetOverlay.isBuffInCategory(buff.buff_id, category) then return buff end
    end
    return nil
end

function TargetOverlay.getTargetInfoById(targetId)
    if not targetId then return nil end
    local info = OverlayUtils.safeCall(function() return api.Unit:GetUnitInfoById(targetId) end)
    if info then return info end
    local textId = tostring(targetId)
    if string.find(textId, "^0x") then
        info = OverlayUtils.safeCall(function() return api.Unit:GetUnitInfoById(string.sub(textId, 3)) end)
        if info then return info end
    end
    if type(targetId) == "number" then
        info = OverlayUtils.safeCall(function() return api.Unit:GetUnitInfoById(string.format("%x", targetId)) end)
        if info then return info end
    end
    local numericId = tonumber(targetId)
    if numericId and numericId ~= targetId then
        return OverlayUtils.safeCall(function() return api.Unit:GetUnitInfoById(numericId) end)
    end
    return nil
end

function TargetOverlay.isCharacterTarget(info, gearscore)
    if not info then return false end
    if info.type == "character" or info.type == "player" then return true end
    if info.type ~= nil and info.type ~= "" then return false end
    return tonumber(gearscore) ~= nil
end

function TargetOverlay.isPlayerTarget(info)
    return info and (info.type == "character" or info.type == "player") or false
end

function TargetOverlay.ownershipField(info, keys)
    local value = OverlayUtils.textField(info, keys)
    if not value then return nil end
    local upper = string.upper(tostring(value))
    if upper == "NO FAMILY" or upper == "UNKNOWN" or upper == "NONE" or upper == "NIL" then return nil end
    return value
end

function TargetOverlay.hasOwnershipFields(info)
    return TargetOverlay.ownershipField(info, {"expeditionName", "expedition", "guildName", "guild"})
        or TargetOverlay.ownershipField(info, {"family_name", "familyName", "family"})
        or TargetOverlay.ownershipField(info, {"owner_name", "ownerName", "owner", "portal_owner", "portalOwner"})
end

function TargetOverlay.isOwnershipTarget(info)
    if not info or TargetOverlay.isPlayerTarget(info) then return false end
    local typeText = string.lower(tostring(info.type or info.unitType or info.unit_type or info.category or info.kind or info.objectType or info.object_type or ""))
    local nameText = string.lower(tostring(info.name or info.unitName or info.unit_name or info.landType or info.house_category or ""))
    local hasInfo = TargetOverlay.hasOwnershipFields(info)
    if hasInfo and (info.is_portal or info.isPortal) then return true end
    if hasInfo and typeText ~= "npc" and typeText ~= "monster" then return true end
    if typeText:find("monster", 1, true) or typeText:find("npc", 1, true) or typeText:find("character", 1, true) then
        return false
    end
    if typeText == "" then return hasInfo ~= nil end
    if typeText:find("house", 1, true) or typeText:find("housing", 1, true) or typeText:find("building", 1, true)
        or typeText:find("land", 1, true) or typeText:find("property", 1, true)
        or typeText:find("vehicle", 1, true) or typeText:find("ship", 1, true) or typeText:find("boat", 1, true)
        or typeText:find("mount", 1, true) or typeText:find("slave", 1, true) or typeText:find("doodad", 1, true)
        or typeText:find("farm", 1, true) or typeText:find("plant", 1, true) or typeText:find("tree", 1, true)
        or nameText:find("farmhouse", 1, true) or nameText:find("scarecrow", 1, true) or nameText:find("tree", 1, true)
        or nameText:find("farm", 1, true) or nameText:find("land", 1, true) or nameText:find("property", 1, true) then
        return hasInfo ~= nil
    end
    return hasInfo ~= nil
end

function TargetOverlay.getClassName(targetInfo)
    local className = RoleHelper.getClassName(targetInfo and targetInfo.class)
    if className then return className end
    local apiName = OverlayUtils.safeCall(function() return api.Ability:GetUnitClassName("target") end)
    if type(apiName) == "string" and apiName ~= "" and apiName ~= "0" then return apiName end
    return nil
end

function TargetOverlay.getDefense(info)
    local pdef = OverlayUtils.numField(info, {"armor", "physical_defense", "physicalDefense", "pdef"})
    local mdef = OverlayUtils.numField(info, {"magic_resist", "magicResist", "magic_defense", "magicDefense", "mdef"})
    local pdefPct = OverlayUtils.numField(info, {"armor_percentage", "armorPercent", "physical_defense_percentage", "physicalDefensePercent", "pdefPercent"})
    local mdefPct = OverlayUtils.numField(info, {"magic_resist_percentage", "magicResistPercent", "magic_defense_percentage", "magicDefensePercent", "mdefPercent"})
    return pdef, mdef, pdefPct, mdefPct
end

function TargetOverlay.fillDefense(basePdef, baseMdef, basePdefPct, baseMdefPct, info)
    local pdef, mdef, pdefPct, mdefPct = TargetOverlay.getDefense(info)
    return basePdef or pdef, baseMdef or mdef, basePdefPct or pdefPct, baseMdefPct or mdefPct
end

function TargetOverlay.targetExtraStats(tokenInfo, targetInfo, modifierInfo)
    local infos = {tokenInfo or {}, targetInfo or {}, modifierInfo or {}}
    return {
        block = OverlayUtils.chanceText(OverlayUtils.firstNumAllowZero(infos, {"block_rate", "blockRate", "block_chance", "blockChance", "shield_block_rate", "shieldBlockRate", "shield_defense_rate", "shieldDefenseRate", "shield_defense", "shieldDefense", "block"}) or OverlayUtils.firstPatternNum(infos, {"block", "shield_defense", "shielddefense"})),
        parry = OverlayUtils.chanceText(OverlayUtils.firstNumAllowZero(infos, {"parry_rate", "parryRate", "parry_chance", "parryChance", "weapon_parry", "weaponParry", "parry", "melee_parry_rate", "meleeParryRate"}) or OverlayUtils.firstPatternNum(infos, {"parry"})),
        evasion = OverlayUtils.chanceText(OverlayUtils.firstNumAllowZero(infos, {"evasion", "evasion_rate", "evasionRate", "evade_rate", "evadeRate", "dodge", "dodge_rate", "dodgeRate"}) or OverlayUtils.firstPatternNum(infos, {"evasion", "evade", "dodge"})),
        toughness = OverlayUtils.valueText(OverlayUtils.firstNumAllowZero(infos, {"toughness", "toughness_value", "toughnessValue", "battle_resist", "battleResist", "critical_resistance", "criticalResistance", "critical_resilience", "criticalResilience", "received_critical_damage_reduce", "receivedCriticalDamageReduce", "critical_damage_resistance", "criticalDamageResistance"}) or OverlayUtils.firstPatternNum(infos, {"tough", "battle_resist", "battleresist", "critical_resist", "criticalresist", "critical_resilience", "criticalresilience"})),
        resilience = OverlayUtils.valueText(OverlayUtils.firstNumAllowZero(infos, {"resilience", "resilience_value", "resilienceValue", "flexibility", "pvp_resilience", "pvpResilience", "battle_resilience", "battleResilience", "pvp_damage_resistance", "pvpDamageResistance", "pvp_damage_reduce", "pvpDamageReduce"}) or OverlayUtils.firstPatternNum(infos, {"resil", "flexibility", "pvp"}))
    }
end

function TargetOverlay.equippedSnapshot(slot)
    if not slot then return nil end
    local info = OverlayUtils.safeCall(function() return api.Equipment:GetEquippedItemTooltipInfo(slot) end)
    local textInfo = OverlayUtils.safeCall(function() return api.Equipment:GetEquippedItemTooltipText("player", slot) end)
    return {
        name = OverlayUtils.itemName(info) or OverlayUtils.itemName(textInfo),
        icon = OverlayUtils.iconPath(info) or OverlayUtils.iconPath(textInfo)
    }
end

function TargetOverlay.gliderEquipSlot()
    if not EQUIP_SLOT then return nil end
    if EQUIP_SLOT.GLIDER then return EQUIP_SLOT.GLIDER end
    if EQUIP_SLOT.BACKPACK then return EQUIP_SLOT.BACKPACK end
    if EQUIP_SLOT.MUSICAL then return tonumber(EQUIP_SLOT.MUSICAL) and (EQUIP_SLOT.MUSICAL + 1) or nil end
    return nil
end

function TargetOverlay.equippedGliderSnapshot()
    return TargetOverlay.equippedSnapshot(TargetOverlay.gliderEquipSlot()) or {}
end

local MOUNT_SYMBOLS = {
    ["abysswraith kirin"] = "Game\\ui\\icon\\icon_skill_karon01.dds",
    ["stormwraith kirin"] = "Game\\ui\\icon\\icon_skill_karon01.dds"
}

function TargetOverlay.mountedPetSnapshot()
    local info = OverlayUtils.safeCall(function() return api.Unit:UnitInfo("playerpet") end) or {}
    local name = OverlayUtils.textField(info, {"mate_npc_name", "mateNpcName", "name", "unitName", "unit_name"})
    local key = string.lower(tostring(name or ""))
    return {
        name = name,
        icon = OverlayUtils.iconPath(info) or MOUNT_SYMBOLS[key]
    }
end

function TargetOverlay.trackedGliderMatches(row, glider)
    local patterns = row and row.gliderPattern
    if not patterns then return true end
    local name = string.lower(tostring(glider and glider.name or ""))
    if name == "" then return false end
    local normalizedName = string.gsub(name, "^enhanced%s+", "")
    if type(patterns) ~= "table" then patterns = {patterns} end
    for _, pattern in ipairs(patterns) do
        local wanted = string.lower(tostring(pattern or ""))
        local normalizedWanted = string.gsub(wanted, "^enhanced%s+", "")
        if wanted ~= "" and (name:find(wanted, 1, true) or normalizedName:find(normalizedWanted, 1, true)) then
            return true
        end
    end
    return false
end

function TargetOverlay.buffId(buff)
    if type(buff) ~= "table" then return nil end
    return tonumber(buff.buff_id or buff.buffId or buff.buff_id_string or buff.buffType or buff.buff_type)
end

function TargetOverlay.buffName(buff)
    if type(buff) ~= "table" then return nil end
    return OverlayUtils.textField(buff, {"name", "buff_name", "tooltip", "description"})
end

function TargetOverlay.isStarTriggerCooldown(row)
    if not row or not (row.gliderPattern or row.category == "glider") then return false end
    local text = string.lower(tostring(row.buffName or row.name or ""))
    if text:find("star", 1, true) then return true end
    for _, name in ipairs(row.buffNames or {}) do
        text = string.lower(tostring(name or ""))
        if text:find("star", 1, true) then return true end
    end
    return false
end

function TargetOverlay.buffTooltipById(id)
    if id == nil then return nil end
    local key = tostring(id or "")
    if buffTooltipCache[key] ~= nil then return buffTooltipCache[key] or nil end
    local tooltip = OverlayUtils.safeCall(function() return api.Ability:GetBuffTooltip(tonumber(id), 1) end)
    if not tooltip then
        tooltip = OverlayUtils.safeCall(function() return api.Ability.GetBuffTooltip(tonumber(id)) end)
    end
    if not tooltip and TargetOverlay.cooldawnBuffList and TargetOverlay.cooldawnBuffList.GetBuffName then
        local name = OverlayUtils.safeCall(function() return TargetOverlay.cooldawnBuffList.GetBuffName(tostring(id)) end)
        if name then tooltip = { name = name } end
    end
    OverlayUtils.cachePut(buffTooltipCache, key, tooltip or false)
    return tooltip
end

function TargetOverlay.buffIconById(id)
    local key = tostring(id or "")
    if buffIconCache[key] ~= nil then return buffIconCache[key] end
    local tooltip = TargetOverlay.buffTooltipById(id)
    local path = OverlayUtils.iconPath(tooltip)
    if not path and TargetOverlay.cooldawnBuffList and TargetOverlay.cooldawnBuffList.GetBuffIcon then
        path = OverlayUtils.safeCall(function() return TargetOverlay.cooldawnBuffList.GetBuffIcon(tostring(id)) end)
    end
    OverlayUtils.cachePut(buffIconCache, key, path or false)
    return path
end

function TargetOverlay.itemIconByType(itemType)
    local key = "item:" .. tostring(itemType or "")
    if buffIconCache[key] ~= nil then return buffIconCache[key] or nil end
    local info = OverlayUtils.safeCall(function() return api.Item:GetItemInfoByType(tonumber(itemType)) end)
    local path = OverlayUtils.iconPath(info)
    OverlayUtils.cachePut(buffIconCache, key, path or false)
    return path
end

function TargetOverlay.cooldownRowIcon(row)
    if not row then return nil end
    if row.itemType then
        local icon = TargetOverlay.itemIconByType(row.itemType)
        if icon then return icon end
    end
    return row.icon
end

function TargetOverlay.buffCooldownById(id)
    if not id then return 30 end
    if TargetOverlay.cooldawnBuffList and TargetOverlay.cooldawnBuffList.GetBuffCooldown then
        local cooldown = OverlayUtils.safeCall(function() return TargetOverlay.cooldawnBuffList.GetBuffCooldown(tostring(id)) end)
        cooldown = tonumber(cooldown)
        if cooldown and cooldown > 0 then return cooldown end
    end
    return 30
end

function TargetOverlay.buffNameById(id)
    local tooltip = TargetOverlay.buffTooltipById(id)
    local name = OverlayUtils.textField(tooltip, {"name", "title", "buff_name"})
    if name then return name end
    if TargetOverlay.cooldawnBuffList and TargetOverlay.cooldawnBuffList.GetBuffName then
        return OverlayUtils.safeCall(function() return TargetOverlay.cooldawnBuffList.GetBuffName(tostring(id)) end)
    end
    return nil
end

function TargetOverlay.detectedCooldown(name, id, fallback)
    local lowerName = string.lower(tostring(name or ""))
    if lowerName:find("invisible predator", 1, true)
        or lowerName:find("insibile predator", 1, true)
        or (lowerName:find("predator", 1, true) and lowerName:find("invis", 1, true)) then
        return 60
    end
    local cooldown = tonumber(fallback)
    if cooldown and cooldown > 0 then return cooldown end
    return TargetOverlay.buffCooldownById(id) or 30
end

function TargetOverlay.skillIconById(id)
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

function TargetOverlay.getPlayerName()
    local info = OverlayUtils.safeCall(function() return api.Unit:UnitInfo("player") end)
    local name = OverlayUtils.textField(info, {"name", "unitName", "unit_name"})
    if name then return name end
    name = OverlayUtils.safeCall(function() return api.Unit:UnitName("player") end)
    if name and tostring(name) ~= "" then return tostring(name) end
    local id = OverlayUtils.safeCall(function() return api.Unit:GetUnitId("player") end)
    name = id and OverlayUtils.safeCall(function() return api.Unit:GetUnitNameById(id) end)
    return name and tostring(name) or nil
end

local function decorateCooldownIcon(icon, parent, id, size)
    if not icon then return end
    local overlay = icon:CreateColorDrawable(0, 0, 0, 0.62, "overlay")
    overlay:AddAnchor("TOPLEFT", icon, 0, 0)
    overlay:AddAnchor("BOTTOMRIGHT", icon, 0, 0)
    overlay:Show(false)
    icon.cooldownOverlay = overlay

    local timer = parent:CreateChildWidget("label", id .. "_timer", 0, true)
    timer:SetExtent(size, size)
    timer:AddAnchor("CENTER", icon, 0, 0)
    timer.style:SetFontSize(10)
    timer.style:SetAlign(ALIGN.CENTER)
    if timer.style.SetShadow then timer.style:SetShadow(false) end
    if timer.style.SetOutline then timer.style:SetOutline(false) end
    timer.style:SetColor(1, 1, 1, 1)
    timer:SetText("")
    timer:Show(false)
    timer:Clickable(false)
    icon.timerLabel = timer
end

local function createIcon(parent, id, x, y, size)
    local icon = nil
    if CreateItemIconButton then
        local ok, created = pcall(function() return CreateItemIconButton(id, parent) end)
        if ok then icon = created end
    end
    if icon then
        icon:SetExtent(size, size)
        icon:AddAnchor("TOPLEFT", parent, x, y)
        if icon.Clickable then icon:Clickable(false) end
        if F_SLOT and F_SLOT.ApplySlotSkin and SLOT_STYLE then
            pcall(function() F_SLOT.ApplySlotSkin(icon, icon.back, SLOT_STYLE.DEFAULT) end)
        end
        icon:Show(false)
        decorateCooldownIcon(icon, parent, id, size)
        return icon
    end

    local holder = parent:CreateChildWidget("emptywidget", id, 0, true)
    holder:SetExtent(size, size)
    holder:AddAnchor("TOPLEFT", parent, x, y)
    addBg(holder, 0, 0, 0, 0.48)
    holder:Show(false)
    decorateCooldownIcon(holder, parent, id, size)
    return holder
end

local function setIcon(icon, path)
    if not icon then return end
    if not path or tostring(path) == "" then
        icon:Show(false)
        return
    end
    local ok = false
    if F_SLOT and F_SLOT.SetIconBackGround then
        ok = pcall(function() F_SLOT.SetIconBackGround(icon, tostring(path)) end)
    end
    if not ok and icon.SetTgaTexture then
        ok = pcall(function() icon:SetTgaTexture(tostring(path)) end)
    end
    icon:Show(ok == true)
end

local function setCachedIcon(icon, path)
    if not icon then return end
    path = path and tostring(path) or nil
    if icon._lastPath == path and icon._lastVisible ~= nil then
        icon:Show(icon._lastVisible)
        return
    end
    icon._lastPath = path
    if path and path ~= "" then
        setIcon(icon, path)
        icon._lastVisible = true
    else
        icon:Show(false)
        icon._lastVisible = false
    end
end

local function setEquipIcon(icon, path)
    if not icon then return end
    path = path and tostring(path) or nil
    if path and path ~= "" then
        setCachedIcon(icon, path)
        return
    end
    if icon._lastPath ~= "__empty" then
        if F_SLOT and F_SLOT.SetIconBackGround then
            pcall(function() F_SLOT.SetIconBackGround(icon, nil) end)
        end
        if F_SLOT and F_SLOT.ApplySlotSkin and SLOT_STYLE and icon.back then
            pcall(function() F_SLOT.ApplySlotSkin(icon, icon.back, SLOT_STYLE.DEFAULT) end)
        end
        icon._lastPath = "__empty"
    end
    icon._lastVisible = true
    icon:Show(true)
end

local function setCooldownIcon(icon, path, state, seconds)
    setCachedIcon(icon, path)
    if not icon then return end
    local active = state == "active" or state == "cooldown"
    if icon.cooldownOverlay then icon.cooldownOverlay:Show(active) end
    if icon.timerLabel then
        if state == "active" then
            icon.timerLabel:SetText(OverlayUtils.cooldownTimerText(seconds) or "ON")
            icon.timerLabel:Show(true)
        elseif state == "cooldown" and seconds then
            icon.timerLabel:SetText(OverlayUtils.cooldownTimerText(seconds) or "")
            icon.timerLabel:Show(true)
        else
            icon.timerLabel:SetText("")
            icon.timerLabel:Show(false)
        end
    end
end

local function setCooldownSkillIcon(icon, path, state, seconds)
    if path then
        setCooldownIcon(icon, path, state, seconds)
        return
    end
    setEquipIcon(icon, nil)
    local active = state == "active" or state == "cooldown"
    if icon.cooldownOverlay then icon.cooldownOverlay:Show(active) end
    if icon.timerLabel then
        if state == "cooldown" and seconds then
            icon.timerLabel:SetText(OverlayUtils.cooldownTimerText(seconds) or "")
            icon.timerLabel:Show(true)
        elseif state == "active" then
            icon.timerLabel:SetText(OverlayUtils.cooldownTimerText(seconds) or "ON")
            icon.timerLabel:Show(true)
        else
            icon.timerLabel:SetText("")
            icon.timerLabel:Show(false)
        end
    end
end

local function setInfoCell(row, value, color)
    if not row then return end
    if value and value ~= "" then
        row:SetText(value)
        setTextColor(row, color or COLORS.white)
        row:Show(true)
    else
        row:SetText("")
        row:Show(false)
    end
end

local function setModelLabel(row, value)
    if not row then return end
    value = tostring(value or "")
    if row._lastText ~= value then
        row:SetText(value)
        row._lastText = value
    end
    if row._visible ~= true then
        row:Show(true)
        row._visible = true
    end
end

local function hideModelLabel(row)
    if not row then return end
    if row._visible ~= false then
        row:Show(false)
        row._visible = false
    end
end

local function hideModelRange()
    if targetRangeCanvas then targetRangeCanvas:Show(false) end
    if targetRangeLabel then
        targetRangeLabel:SetText("")
        targetRangeLabel._lastText = ""
        targetRangeLabel:Show(false)
        targetRangeLabel._visible = false
    end
end

local function buildInfoRows(targetInfo, className, gearscore, pdef, mdef, pdefPct, mdefPct, extraStats, ownershipOnly)
    local identity = {}
    local defense = {}
    local compactSummary = {}
    local simpleMeta = {}
    local simpleGuild = nil
    local compact = settings.compactTargetWindow or settings.testTargetWindow
    local function addRow(list, key, text, forceCol)
        if text and text ~= "" then
            table.insert(list, { key = key, text = text, color = settingColor(key), forceCol = forceCol })
        end
    end
    local function addSummary(text)
        if text and text ~= "" then
            table.insert(settings.testTargetWindow and simpleMeta or compactSummary, text)
        end
    end
    if compact and not settings.testTargetWindow and settings.showInfoRange then
        local range = TargetOverlay.getDistance("target")
        if range then addSummary(tostring(range) .. "m") end
    end
    if compact and settings.showInfoGearscore and gearscore then addSummary(tostring(gearscore)) end
    if compact and settings.showInfoClass and className then addSummary(OverlayUtils.shortText(className, 16)) end
    if ownershipOnly and (targetInfo.is_portal or targetInfo.isPortal) then
        local portalOwner = TargetOverlay.ownershipField(targetInfo, {"portal_owner", "portalOwner", "owner_name", "ownerName", "owner"})
        local destination = TargetOverlay.ownershipField(targetInfo, {"name", "targetName", "destination"})
        if portalOwner then
            if settings.testTargetWindow then simpleGuild = OverlayUtils.shortText(portalOwner, 34)
            elseif compact then addSummary(OverlayUtils.shortText(portalOwner, 14))
            else addRow(identity, "guild", "Owner: " .. OverlayUtils.shortText(portalOwner, 21)) end
        end
        if destination then
            if compact then addSummary(OverlayUtils.shortText(destination, 14))
            else addRow(identity, "family", "Portal: " .. OverlayUtils.shortText(destination, 20)) end
        end
    elseif settings.showInfoGuild or ownershipOnly then
        local guild = TargetOverlay.ownershipField(targetInfo, {"expeditionName", "expedition", "guildName", "guild"})
        if guild then
            if settings.testTargetWindow then simpleGuild = OverlayUtils.shortText(guild, 34)
            elseif compact then addSummary(OverlayUtils.shortText(guild, 14))
            else addRow(identity, "guild", "Guild: " .. OverlayUtils.shortText(guild, 21)) end
        end
    end
    if settings.showInfoFamily or ownershipOnly then
        local family = TargetOverlay.ownershipField(targetInfo, {"family_name", "familyName", "family"})
        local owner = ownershipOnly and TargetOverlay.ownershipField(targetInfo, {"owner_name", "ownerName", "owner"}) or nil
        if family then
            if compact then
                addSummary(OverlayUtils.shortText(family, 14))
            else addRow(identity, "family", "Family: " .. OverlayUtils.shortText(family, 20)) end
        end
        if owner and owner ~= family then
            if compact then
                addSummary(OverlayUtils.shortText(owner, 14))
            else addRow(identity, "family", "Owner: " .. OverlayUtils.shortText(owner, 20)) end
        end
    end
    if ownershipOnly then
        local rows = {}
        if not compact and #identity > 0 then
            table.insert(rows, { header = true, text = "Ownership" })
            for _, row in ipairs(identity) do table.insert(rows, row) end
        end
        return rows, table.concat(compactSummary, "  |  "), simpleGuild or "", table.concat(simpleMeta, "  |  ")
    end
    if not compact and settings.showInfoClass and className then addRow(identity, "class", "Class: " .. OverlayUtils.shortText(className, 22)) end
    if not compact and settings.showInfoGearscore and gearscore then addRow(identity, "gearscore", "GS: " .. tostring(gearscore)) end
    local rangeHeader = ""
    if not compact and settings.showInfoRange then
        local range = TargetOverlay.getDistance("target")
        if range then rangeHeader = "  |  " .. tostring(range) .. "m" end
    end
    if settings.showInfoPdef then addRow(defense, "pdef", "PDef: " .. OverlayUtils.defenseText(pdef, pdefPct)) end
    if settings.showInfoMdef then addRow(defense, "mdef", "MDef: " .. OverlayUtils.defenseText(mdef, mdefPct)) end
    extraStats = extraStats or {}
    if settings.showInfoBlock then addRow(defense, "block", extraStats.block and ("Block: " .. extraStats.block) or nil) end
    if settings.showInfoParry then addRow(defense, "parry", extraStats.parry and ("Parry: " .. extraStats.parry) or nil) end
    if settings.showInfoEvasion then addRow(defense, "evasion", extraStats.evasion and ("Evasion: " .. extraStats.evasion) or nil) end
    if settings.showInfoToughness then addRow(defense, "toughness", extraStats.toughness and ("Tough: " .. extraStats.toughness) or nil) end
    if settings.showInfoResilience then
        addRow(defense, "resilience", extraStats.resilience and ("Resil: " .. extraStats.resilience) or nil)
    end

    local rows = {}
    if not compact and (#identity > 0 or rangeHeader ~= "") then
        table.insert(rows, { header = true, text = "Identity" .. rangeHeader })
        for _, row in ipairs(identity) do table.insert(rows, row) end
    end
    if #defense > 0 then
        if not compact then table.insert(rows, { header = true, text = "Defense" }) end
        if settings.testTargetWindow then
            local simpleRows = {}
            for _, row in ipairs(defense) do
                local gridRow = TargetOverlay.simpleStatsGrid[row.key]
                if gridRow ~= nil then
                    local order = TargetOverlay.compactStatsOrder[row.key] or 99
                    if not simpleRows[gridRow] then simpleRows[gridRow] = {} end
                    table.insert(simpleRows[gridRow], { order = order, row = row })
                end
            end
            for gridRow = 0, 1 do
                table.sort(simpleRows[gridRow] or {}, function(a, b) return a.order < b.order end)
                for col, item in ipairs(simpleRows[gridRow] or {}) do
                    item.row.compactGridRow = gridRow
                    item.row.compactGridCol = col - 1
                    table.insert(rows, item.row)
                end
            end
        elseif compact then
            local compactRows = {}
            for _, row in ipairs(defense) do
                local gridRow = TargetOverlay.simpleStatsGrid[row.key]
                if gridRow ~= nil then
                    local order = TargetOverlay.compactStatsOrder[row.key] or 99
                    if not compactRows[gridRow] then compactRows[gridRow] = {} end
                    table.insert(compactRows[gridRow], { order = order, row = row })
                end
            end
            for gridRow = 0, 1 do
                table.sort(compactRows[gridRow] or {}, function(a, b) return a.order < b.order end)
                for col, item in ipairs(compactRows[gridRow] or {}) do
                    item.row.compactGridRow = gridRow
                    item.row.compactGridCol = col - 1
                    table.insert(rows, item.row)
                end
            end
        else
            for _, row in ipairs(defense) do table.insert(rows, row) end
        end
    end
    return rows, table.concat(compactSummary, "  |  "), simpleGuild or "", table.concat(simpleMeta, "  |  ")
end

local function createTargetInfoWindow()
    targetInfoWnd = api.Interface:CreateEmptyWindow("PowerRangerTargetInfo", "UIParent")
    targetInfoWnd:SetExtent(430, 150)
    local x, y = TargetOverlay.safeWindowPosition(settings.targetWindowX, settings.targetWindowY, 430, 150)
    targetInfoWnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    if targetInfoWnd.Clickable then targetInfoWnd:Clickable(false) end
    targetInfoWnd.bg = addBg(targetInfoWnd, 0, 0, 0, 0.62)
    local header = targetInfoWnd:CreateColorDrawable(0.06, 0.075, 0.095, 0.76, "background")
    header:SetExtent(430, 22)
    header:AddAnchor("TOPLEFT", targetInfoWnd, 0, 0)
    header:Show(true)
    targetInfoWnd.header = header
    local title = label(targetInfoWnd, "power_ranger_target_info_title", "Power Ranger ON", 8, 3, 414, 16, 14, COLORS.gold, ALIGN.LEFT)
    title:Clickable(false)
    targetInfoWnd.title = title
    targetInfoWnd.simpleMeta = label(targetInfoWnd, "power_ranger_target_info_simple_meta", "", 8, 18, 414, 14, 11, COLORS.white, ALIGN.LEFT)
    targetInfoWnd.simpleMeta:Clickable(false)
    targetInfoWnd.simpleMeta:Show(false)
    local dragHandle = targetInfoWnd:CreateChildWidget("emptywidget", "power_ranger_target_info_drag", 0, true)
    dragHandle:SetExtent(430, 22)
    dragHandle:AddAnchor("TOPLEFT", targetInfoWnd, 0, 0)
    dragHandle:Show(true)
    targetInfoWnd.dragHandle = dragHandle
    applyHandleDrag(targetInfoWnd, dragHandle, "targetWindowX", "targetWindowY")
    targetInfoWnd.rows = {}
    targetInfoWnd.simpleValues = {}
    for i = 1, 16 do
        targetInfoWnd.rows[i] = label(targetInfoWnd, "power_ranger_info_row_" .. i, "", 12, 30, 198, 16, 12, COLORS.white, ALIGN.LEFT)
        targetInfoWnd.rows[i]:Clickable(false)
        targetInfoWnd.simpleValues[i] = label(targetInfoWnd, "power_ranger_info_simple_value_" .. i, "", 12, 30, 96, 16, 12, COLORS.white, ALIGN.LEFT)
        targetInfoWnd.simpleValues[i]:Clickable(false)
        targetInfoWnd.simpleValues[i]:Show(false)
    end
    targetInfoWnd:Show(false)
end

local function createOwnershipWindow()
    ownershipWnd = api.Interface:CreateEmptyWindow("PowerRangerOwnershipInfo", "UIParent")
    ownershipWnd:SetExtent(360, 42)
    local x, y = TargetOverlay.safeWindowPosition(settings.ownershipWindowX, settings.ownershipWindowY, 360, 42)
    ownershipWnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    if ownershipWnd.Clickable then ownershipWnd:Clickable(false) end
    ownershipWnd.title = label(ownershipWnd, "power_ranger_ownership_title", "", 4, 0, 352, 20, 15, COLORS.white, ALIGN.LEFT)
    ownershipWnd.title:Clickable(false)
    ownershipWnd.meta = label(ownershipWnd, "power_ranger_ownership_meta", "", 4, 20, 352, 16, 11, COLORS.white, ALIGN.LEFT)
    ownershipWnd.meta:Clickable(false)
    if ownershipWnd.title.style.SetOutline then ownershipWnd.title.style:SetOutline(false) end
    if ownershipWnd.meta.style.SetOutline then ownershipWnd.meta.style:SetOutline(false) end
    if ownershipWnd.title.style.SetShadow then ownershipWnd.title.style:SetShadow(settings.overlayTextShadow ~= false) end
    if ownershipWnd.meta.style.SetShadow then ownershipWnd.meta.style:SetShadow(settings.overlayTextShadow ~= false) end
    local dragHandle = ownershipWnd:CreateChildWidget("emptywidget", "power_ranger_ownership_drag", 0, true)
    dragHandle:SetExtent(360, 42)
    dragHandle:AddAnchor("TOPLEFT", ownershipWnd, 0, 0)
    dragHandle:Show(true)
    ownershipWnd.dragHandle = dragHandle
    applyHandleDrag(ownershipWnd, dragHandle, "ownershipWindowX", "ownershipWindowY")
    ownershipWnd:Show(false)
end

local function hideOwnershipWindow()
    if ownershipWnd then ownershipWnd:Show(false) end
end

function TargetOverlay.applyTextShadow()
    local enabled = settings and settings.overlayTextShadow ~= false or false
    local modelLabels = {
        targetPdefTitleLabel, targetPdefValueLabel, targetMdefTitleLabel, targetMdefValueLabel,
        targetGearscoreLabel, targetClassLabel, targetRangeLabel
    }
    for _, widget in ipairs(modelLabels) do
        if widget and widget.style.SetShadow then widget.style:SetShadow(enabled) end
    end
    if ownershipWnd then
        if ownershipWnd.title.style.SetShadow then ownershipWnd.title.style:SetShadow(enabled) end
        if ownershipWnd.meta.style.SetShadow then ownershipWnd.meta.style:SetShadow(enabled) end
    end
    if targetInfoWnd then
        local simpleShadow = enabled and settings.testTargetWindow == true
        if targetInfoWnd.title.style.SetShadow then targetInfoWnd.title.style:SetShadow(simpleShadow) end
        if targetInfoWnd.simpleMeta.style.SetShadow then targetInfoWnd.simpleMeta.style:SetShadow(simpleShadow) end
        for i = 1, 16 do
            if targetInfoWnd.rows[i].style.SetShadow then targetInfoWnd.rows[i].style:SetShadow(simpleShadow) end
            if targetInfoWnd.simpleValues[i].style.SetShadow then targetInfoWnd.simpleValues[i].style:SetShadow(simpleShadow) end
        end
    end
end

local function refreshOwnershipWindow(info)
    if not ownershipWnd or not info then return end
    if settings.showOwnershipLabels == false then
        hideOwnershipWindow()
        return
    end
    local guild = TargetOverlay.ownershipField(info, {"expeditionName", "expedition", "guildName", "guild"})
    local family = TargetOverlay.ownershipField(info, {"family_name", "familyName", "family"})
    local owner = TargetOverlay.ownershipField(info, {"owner_name", "ownerName", "owner", "portal_owner", "portalOwner"})
    local titleText = guild or family or owner
    local meta = {}
    if guild and titleText ~= guild then table.insert(meta, "Guild: " .. OverlayUtils.shortText(guild, 24)) end
    if family and titleText ~= family then table.insert(meta, "Family: " .. OverlayUtils.shortText(family, 24)) end
    if owner and titleText ~= owner then table.insert(meta, "Owner: " .. OverlayUtils.shortText(owner, 24)) end
    if not titleText then
        hideOwnershipWindow()
        return
    end
    if targetInfoWnd then targetInfoWnd:Show(false) end
    local titleDisplay = OverlayUtils.shortText(titleText, 34)
    local metaDisplay = table.concat(meta, "  |  ")
    local scale = uiScaleFactor("ownershipScaleLevel")
    local pad = math.floor((4 * scale) + 0.5)
    local titleHeight = math.floor((20 * scale) + 0.5)
    local metaHeight = math.floor((16 * scale) + 0.5)
    ownershipWnd.title.style:SetFontSize(math.floor((15 * scale) + 0.5))
    ownershipWnd.meta.style:SetFontSize(math.floor((11 * scale) + 0.5))
    ownershipWnd.title:SetText(titleDisplay)
    ownershipWnd.meta:SetText(metaDisplay)
    ownershipWnd.meta:Show(#meta > 0)
    setTextColor(ownershipWnd.title, guild and settingColor("guild") or settingColor("family"))
    setTextColor(ownershipWnd.meta, COLORS.white)
    local titleWidth = ownershipWnd.title.style:GetTextWidth(titleDisplay)
    local metaWidth = #meta > 0 and ownershipWnd.meta.style:GetTextWidth(metaDisplay) or 0
    local wantedWidth = math.max(math.floor((120 * scale) + 0.5), math.min(math.floor((460 * scale) + 0.5), math.ceil(math.max(titleWidth, metaWidth) + (12 * scale))))
    local wantedHeight = #meta > 0 and math.floor((42 * scale) + 0.5) or math.floor((24 * scale) + 0.5)
    if ownershipWnd._lastWidth ~= wantedWidth or ownershipWnd._lastHeight ~= wantedHeight then
        ownershipWnd:SetExtent(wantedWidth, wantedHeight)
        ownershipWnd.title:RemoveAllAnchors()
        ownershipWnd.title:AddAnchor("TOPLEFT", ownershipWnd, pad, 0)
        ownershipWnd.title:SetExtent(wantedWidth - (pad * 2), titleHeight)
        ownershipWnd.meta:RemoveAllAnchors()
        ownershipWnd.meta:AddAnchor("TOPLEFT", ownershipWnd, pad, titleHeight)
        ownershipWnd.meta:SetExtent(wantedWidth - (pad * 2), metaHeight)
        ownershipWnd.dragHandle:SetExtent(wantedWidth, wantedHeight)
        ownershipWnd._lastWidth = wantedWidth
        ownershipWnd._lastHeight = wantedHeight
    end
    ownershipWnd:Show(true)
end

local function refreshTargetInfoWindow(targetInfo, className, gearscore, pdef, mdef, pdefPct, mdefPct, extraStats, ownershipOnly)
    if not targetInfoWnd then return end
    if ((not settings.showTargetWindow or Compat.ShouldHideTargetInfoWindow(compatState, ownershipOnly)) and not ownershipOnly) or not targetInfo then
        targetInfoWnd:Show(false)
        return
    end
    local rows, compactSummary, simpleGuild, simpleMeta = buildInfoRows(targetInfo, className, gearscore, pdef, mdef, pdefPct, mdefPct, extraStats, ownershipOnly)
    local compact = settings.compactTargetWindow or settings.testTargetWindow
    local testLayout = settings.testTargetWindow == true
    local summaryVisible = testLayout and (simpleGuild ~= "" or simpleMeta ~= "") or compactSummary ~= ""
    if #rows == 0 and (not compact or not summaryVisible) then
        targetInfoWnd:Show(false)
        return
    end
    local scale = uiScaleFactor("targetWindowScaleLevel")
    if testLayout then
        targetInfoWnd.title:SetText(simpleGuild)
        targetInfoWnd.title.style:SetFontSize(math.floor((15 * scale) + 0.5))
        targetInfoWnd.simpleMeta:SetText(simpleMeta)
        targetInfoWnd.simpleMeta.style:SetFontSize(math.floor((11 * scale) + 0.5))
        targetInfoWnd.simpleMeta:Show(simpleMeta ~= "")
    elseif compact then
        targetInfoWnd.title:SetText(compactSummary)
        targetInfoWnd.title.style:SetFontSize(math.floor((11 * scale) + 0.5))
        targetInfoWnd.simpleMeta:Show(false)
    else
        targetInfoWnd.title:SetText("Power Ranger ON")
        targetInfoWnd.title.style:SetFontSize(math.floor((14 * scale) + 0.5))
        targetInfoWnd.simpleMeta:Show(false)
    end
    targetInfoWnd.bg:Show(not testLayout)
    targetInfoWnd.header:Show(not testLayout)
    setTextColor(targetInfoWnd.title, testLayout and COLORS.white or COLORS.gold)
    if targetInfoWnd.title.style.SetOutline then targetInfoWnd.title.style:SetOutline(false) end
    if targetInfoWnd.simpleMeta.style.SetOutline then targetInfoWnd.simpleMeta.style:SetOutline(false) end
    if targetInfoWnd.title.style.SetShadow then targetInfoWnd.title.style:SetShadow(testLayout and settings.overlayTextShadow ~= false) end
    if targetInfoWnd.simpleMeta.style.SetShadow then targetInfoWnd.simpleMeta.style:SetShadow(testLayout and settings.overlayTextShadow ~= false) end
    local headerHeight = math.floor(((compact and 18 or 22) * scale) + 0.5)
    local sideMargin = math.floor(((testLayout and 4 or compact and 6 or 12) * scale) + 0.5)
    local simpleColumnGap = math.max(0, math.min(73, tonumber(settings.simpleColumnGap) or 0)) - 43
    local simpleLineGap = math.max(0, math.min(23, tonumber(settings.simpleLineGap) or 0)) - 4
    local colGap = math.floor(((testLayout and simpleColumnGap or compact and 6 or 12) * scale) + 0.5)
    local titleMargin = math.floor(((testLayout and 4 or compact and 6 or 8) * scale) + 0.5)
    local outlinePad = testLayout and math.floor((4 * scale) + 0.5) or 0
    local minCellWidth = math.floor(((testLayout and 108 or 58) * scale) + 0.5) + outlinePad
    local simpleValueOffset = nil
    local wantedWidth = math.floor((430 * scale) + 0.5)
    for i = 1, 16 do
        targetInfoWnd.rows[i].style:SetFontSize(math.floor((12 * scale) + 0.5))
        targetInfoWnd.simpleValues[i].style:SetFontSize(math.floor((12 * scale) + 0.5))
        if targetInfoWnd.rows[i].style.SetOutline then targetInfoWnd.rows[i].style:SetOutline(false) end
        if targetInfoWnd.simpleValues[i].style.SetOutline then targetInfoWnd.simpleValues[i].style:SetOutline(false) end
        if targetInfoWnd.rows[i].style.SetShadow then targetInfoWnd.rows[i].style:SetShadow(testLayout and settings.overlayTextShadow ~= false) end
        if targetInfoWnd.simpleValues[i].style.SetShadow then targetInfoWnd.simpleValues[i].style:SetShadow(testLayout and settings.overlayTextShadow ~= false) end
        setInfoCell(targetInfoWnd.simpleValues[i], nil)
    end
    simpleValueOffset = math.ceil(targetInfoWnd.rows[1].style:GetTextWidth("Tough:")) + math.floor((2 * scale) + 0.5)
    if compact then
        local summaryWidth = targetInfoWnd.title.style:GetTextWidth(testLayout and simpleGuild or compactSummary)
        if testLayout then summaryWidth = math.max(summaryWidth, targetInfoWnd.simpleMeta.style:GetTextWidth(simpleMeta)) end
        local widestCell = 0
        local gridCols = 0
        for _, row in ipairs(rows) do
            if not row.header and row.text then
                widestCell = math.max(widestCell, targetInfoWnd.rows[1].style:GetTextWidth(row.text))
                if row.compactGridCol ~= nil then
                    gridCols = math.max(gridCols, row.compactGridCol + 1)
                end
            end
        end
        if gridCols > 0 then
            widestCell = math.max(widestCell + outlinePad, minCellWidth)
            wantedWidth = math.ceil(math.max(summaryWidth + (titleMargin * 2) + outlinePad, (widestCell * gridCols) + (colGap * math.max(0, gridCols - 1)) + (sideMargin * 2)))
        else
            wantedWidth = math.ceil(math.max(summaryWidth + (titleMargin * 2) + outlinePad, (widestCell * 2) + (sideMargin * 2) + colGap))
        end
    end
    local cellWidth = compact and math.floor((wantedWidth - (sideMargin * 2) - colGap) / 2) or 198
    if compact then
        local gridCols = 0
        local widestCell = 0
        for _, row in ipairs(rows) do
            if row.compactGridCol ~= nil then
                gridCols = math.max(gridCols, row.compactGridCol + 1)
                widestCell = math.max(widestCell, targetInfoWnd.rows[1].style:GetTextWidth(row.text or "") + outlinePad)
            end
        end
        if gridCols > 0 then
            cellWidth = math.max(minCellWidth, math.ceil(widestCell))
        end
    end
    if not compact then cellWidth = math.floor((cellWidth * scale) + 0.5) end
    local colStep = compact and (cellWidth + colGap) or math.floor((210 * scale) + 0.5)
    local rowStep = math.floor(((testLayout and (15 + simpleLineGap) or compact and 15 or 19) * scale) + 0.5)
    targetInfoWnd.header:SetExtent(wantedWidth, headerHeight)
    targetInfoWnd.dragHandle:SetExtent(wantedWidth, headerHeight)
    targetInfoWnd.title:RemoveAllAnchors()
    targetInfoWnd.title:AddAnchor("TOPLEFT", targetInfoWnd, titleMargin, math.floor(((testLayout and 1 or compact and 2 or 3) * scale) + 0.5))
    targetInfoWnd.title:SetExtent(wantedWidth - (titleMargin * 2), math.floor(((testLayout and 15 or compact and 12 or 16) * scale) + 0.5))
    targetInfoWnd.simpleMeta:RemoveAllAnchors()
    targetInfoWnd.simpleMeta:AddAnchor("TOPLEFT", targetInfoWnd, titleMargin, math.floor((18 * scale) + 0.5))
    targetInfoWnd.simpleMeta:SetExtent(wantedWidth - (titleMargin * 2), math.floor((14 * scale) + 0.5))
    local widgetIndex = 1
    local y = math.floor(((testLayout and 36 or compact and 20 or 29) * scale) + 0.5)
    local col = 0
    for _, row in ipairs(rows) do
        if widgetIndex > 16 then break end
        if row.header then
            if col ~= 0 then
                y = y + rowStep
                col = 0
            end
            local widget = targetInfoWnd.rows[widgetIndex]
            widget:RemoveAllAnchors()
            widget:SetExtent(wantedWidth - (sideMargin * 2), math.floor((16 * scale) + 0.5))
            widget:AddAnchor("TOPLEFT", targetInfoWnd, sideMargin, y)
            setInfoCell(widget, row.text, testLayout and COLORS.white or COLORS.gold)
            widgetIndex = widgetIndex + 1
            y = y + math.floor((18 * scale) + 0.5)
        else
            if compact and row.compactGridRow ~= nil then
                local widget = targetInfoWnd.rows[widgetIndex]
                local valueWidget = targetInfoWnd.simpleValues[widgetIndex]
                widget:RemoveAllAnchors()
                widget:SetExtent(cellWidth, math.floor(((testLayout and 15 or 13) * scale) + 0.5))
                widget:AddAnchor("TOPLEFT", targetInfoWnd, sideMargin + (row.compactGridCol * colStep), y + (row.compactGridRow * rowStep))
                if testLayout then
                    local labelText, valueText = tostring(row.text or ""):match("^(.-):%s*(.*)$")
                    valueWidget:RemoveAllAnchors()
                    valueWidget:SetExtent(math.max(0, cellWidth - simpleValueOffset), math.floor((15 * scale) + 0.5))
                    valueWidget:AddAnchor("TOPLEFT", targetInfoWnd, sideMargin + (row.compactGridCol * colStep) + simpleValueOffset, y + (row.compactGridRow * rowStep))
                    if labelText == "Evasion" then labelText = "Evas" end
                    setInfoCell(widget, labelText and (labelText .. ":") or row.text, COLORS.white)
                    setInfoCell(valueWidget, valueText, COLORS.white)
                else
                    setInfoCell(widget, row.text, row.color)
                end
                widgetIndex = widgetIndex + 1
                col = 0
            else
            if row.forceCol == 0 and col ~= 0 then
                y = y + rowStep
                col = 0
            end
            local widget = targetInfoWnd.rows[widgetIndex]
            widget:RemoveAllAnchors()
            widget:SetExtent(cellWidth, math.floor(((testLayout and 15 or compact and 13 or 16) * scale) + 0.5))
            widget:AddAnchor("TOPLEFT", targetInfoWnd, sideMargin + (col * colStep), y)
            setInfoCell(widget, row.text, testLayout and COLORS.white or row.color)
            widgetIndex = widgetIndex + 1
            if row.forceCol == 0 then
                y = y + rowStep
                col = 0
            elseif col == 1 then
                y = y + rowStep
                col = 0
            else
                col = 1
            end
            end
        end
    end
    if col ~= 0 then y = y + rowStep end
    if compact and #rows > 0 then
        local gridRows = 0
        for _, row in ipairs(rows) do
            if row.compactGridRow ~= nil then gridRows = math.max(gridRows, row.compactGridRow + 1) end
        end
        if gridRows > 0 then y = y + (gridRows * rowStep) end
    end
    local wantedHeight = math.max(math.floor(((compact and 26 or 52) * scale) + 0.5), y + math.floor(((compact and 4 or 8) * scale) + 0.5))
    if targetInfoWnd._lastHeight ~= wantedHeight or targetInfoWnd._lastWidth ~= wantedWidth then
        targetInfoWnd:SetExtent(wantedWidth, wantedHeight)
        targetInfoWnd._lastHeight = wantedHeight
        targetInfoWnd._lastWidth = wantedWidth
    end
    for i = widgetIndex, 16 do
        setInfoCell(targetInfoWnd.rows[i], nil)
    end
    targetInfoWnd:Show(true)
end

local function findBuffInUnit(unit, wantedId)
    local count = OverlayUtils.safeCall(function() return api.Unit:UnitBuffCount(unit) end) or 0
    for i = 1, tonumber(count) or 0 do
        local b = OverlayUtils.safeCall(function() return api.Unit:UnitBuff(unit, i) end)
        if TargetOverlay.buffId(b) == tonumber(wantedId) then return b end
    end
    local debuffCount = OverlayUtils.safeCall(function() return api.Unit:UnitDeBuffCount(unit) end) or 0
    for i = 1, tonumber(debuffCount) or 0 do
        local b = OverlayUtils.safeCall(function() return api.Unit:UnitDeBuff(unit, i) end)
        if TargetOverlay.buffId(b) == tonumber(wantedId) then return b end
    end
    return nil
end

local function auraMatchesName(aura, wantedName)
    local needle = string.lower(tostring(wantedName or ""))
    if needle == "" then return false end
    local id = TargetOverlay.buffId(aura)
    local tooltip = TargetOverlay.buffTooltipById(id)
    local name = string.lower(tostring(TargetOverlay.buffName(aura) or OverlayUtils.textField(tooltip, {"name", "title", "buff_name"}) or ""))
    local desc = string.lower(tostring(OverlayUtils.textField(tooltip, {"description", "desc", "tooltip"}) or ""))
    return name:find(needle, 1, true) ~= nil or desc:find(needle, 1, true) ~= nil
end

local function findBuffByNameInUnit(unit, wantedName)
    local count = OverlayUtils.safeCall(function() return api.Unit:UnitBuffCount(unit) end) or 0
    for i = 1, tonumber(count) or 0 do
        local b = OverlayUtils.safeCall(function() return api.Unit:UnitBuff(unit, i) end)
        if auraMatchesName(b, wantedName) then return b end
    end
    local debuffCount = OverlayUtils.safeCall(function() return api.Unit:UnitDeBuffCount(unit) end) or 0
    for i = 1, tonumber(debuffCount) or 0 do
        local b = OverlayUtils.safeCall(function() return api.Unit:UnitDeBuff(unit, i) end)
        if auraMatchesName(b, wantedName) then return b end
    end
    return nil
end

local function findBuff(unit, wantedId)
    if unit == "self" then
        for _, token in ipairs(SELF_BUFF_UNITS) do
            local buff = findBuffInUnit(token, wantedId)
            if buff then return buff end
        end
        return nil
    end
    return findBuffInUnit(unit or "player", wantedId)
end

local function findBuffByName(unit, wantedName)
    if unit == "self" then
        for _, token in ipairs(SELF_BUFF_UNITS) do
            local buff = findBuffByNameInUnit(token, wantedName)
            if buff then return buff end
        end
        return nil
    end
    return findBuffByNameInUnit(unit or "player", wantedName)
end

local function findTrackedBuff(row)
    if row.buffIds then
        for _, id in ipairs(row.buffIds) do
            local b = findBuff(row.unit or "player", id)
            if b then return b end
        end
    end
    if row.buffNames then
        for _, name in ipairs(row.buffNames) do
            local b = findBuffByName(row.unit or "player", name)
            if b then return b end
        end
        return nil
    end
    if row.buffName then return findBuffByName(row.unit or "player", row.buffName) end
    return findBuff(row.unit or "player", row.id)
end

local function triggerBuffFreshEnough(row, buff)
    local minLeft = tonumber(row and row.triggerMinTimeLeftMs)
    if (not minLeft or minLeft <= 0) and TargetOverlay.isStarTriggerCooldown(row) then
        minLeft = 5300
    end
    if not minLeft or minLeft <= 0 then return true end
    local timeLeft = tonumber(buff and buff.timeLeft)
    return timeLeft and timeLeft > minLeft
end

local function updateTrackedBuffs()
    local t = api.Time:GetUiMsec()
    local glider = TargetOverlay.equippedGliderSnapshot()
    local mount = TargetOverlay.mountedPetSnapshot()
    NuziCooldownImport.UpdateMountManaCooldowns(nuziCooldownRows.buffs, buffState, t, trackedBuffKey, mount and mount.icon)
    local learnedGliderIcon = false
    for _, row in ipairs(allTrackedBuffRows()) do
        local key = trackedBuffKey(row)
        if row.enabled == false then
            buffState[key] = nil
            if triggerState[trackedBuffTriggerKey(row)] and triggerState[trackedBuffTriggerKey(row)].rowKey == key then
                triggerState[trackedBuffTriggerKey(row)] = nil
            end
        elseif row.mountManaSpent then
            buffState[key] = buffState[key] or {}
        else
            local state = buffState[key] or {}
            local gliderMatches = TargetOverlay.trackedGliderMatches(row, glider)
            if row.gliderPattern and gliderMatches and glider.icon and not row.icon then
                row.icon = glider.icon
                learnedGliderIcon = true
            end
            local triggerKey = trackedBuffTriggerKey(row)
            local trigger = triggerState[triggerKey]
            local b = nil
            if row.cooldownStartsOnActive and (row.gliderPattern or row.category == "glider") then
                local visibleBuff = findTrackedBuff(row)
                if not visibleBuff then
                    triggerState[triggerKey] = nil
                    trigger = nil
                elseif not triggerBuffFreshEnough(row, visibleBuff) then
                    b = nil
                elseif trigger and trigger.rowKey then
                    if trigger.rowKey == key then b = visibleBuff end
                elseif gliderMatches then
                    triggerState[triggerKey] = { rowKey = key, startedAt = t }
                    b = visibleBuff
                end
            elseif gliderMatches then
                b = findTrackedBuff(row)
            end
            if b then
                if state.active ~= true then
                    state.activatedAt = t
                    if row.cooldownStartsOnActive then
                        local cooldownMs = (tonumber(row.cooldown) or 0) * 1000
                        state.readyAt = t + cooldownMs
                    end
                    if settings.skillProbeLogging == true and recordSkillProbe then
                        recordSkillProbe({
                            event = "TRACKED_BUFF_ACTIVE",
                            unit = tostring(row.unit or "player"),
                            buffId = tonumber(row.id),
                            buffName = row.buffName,
                            glider = row.gliderPattern and serialValue(glider) or nil,
                            name = row.name or TargetOverlay.buffName(b) or tostring(row.id),
                            aura = serialValue(b)
                        })
                    end
                end
                state.active = true
                state.lastSeen = t
                if row.cooldownStartsOnActive and state.readyAt and t >= state.readyAt then state.readyAt = nil end
                if not row.cooldownStartsOnActive then state.readyAt = nil end
                state.name = row.name or TargetOverlay.buffName(b) or tostring(row.id)
                state.icon = (row.preferMountIcon and mount.icon) or (row.gliderPattern and (TargetOverlay.cooldownRowIcon(row) or glider.icon)) or TargetOverlay.cooldownRowIcon(row) or OverlayUtils.iconPath(b) or TargetOverlay.buffIconById(row.id)
                state.timeLeft = b.timeLeft
            elseif state.active then
                state.active = false
                if not row.cooldownStartsOnActive then
                    local cooldownMs = (tonumber(row.cooldown) or 0) * 1000
                    state.readyAt = (state.activatedAt or t) + cooldownMs
                    if state.readyAt < t then state.readyAt = t end
                end
                state.name = row.name or state.name or tostring(row.id)
                state.icon = row.gliderPattern and (TargetOverlay.cooldownRowIcon(row) or state.icon) or (state.icon or TargetOverlay.buffIconById(row.id) or TargetOverlay.cooldownRowIcon(row))
                state.timeLeft = nil
                if settings.skillProbeLogging == true and recordSkillProbe then
                    recordSkillProbe({
                        event = "TRACKED_BUFF_COOLDOWN",
                        unit = tostring(row.unit or "player"),
                        buffId = tonumber(row.id),
                        buffName = row.buffName,
                        glider = row.gliderPattern and serialValue(glider) or nil,
                        name = state.name,
                        cooldown = tonumber(row.cooldown) or 0,
                        readyIn = state.readyAt and math.ceil((state.readyAt - t) / 1000) or 0
                    })
                end
            elseif state.readyAt and t >= state.readyAt then
                state.readyAt = nil
                state.timeLeft = nil
                state.activatedAt = nil
            else
                state.icon = row.gliderPattern and (TargetOverlay.cooldownRowIcon(row) or state.icon) or (state.icon or TargetOverlay.buffIconById(row.id) or TargetOverlay.cooldownRowIcon(row))
                state.timeLeft = nil
            end
            buffState[key] = state
        end
    end
    if learnedGliderIcon then saveSettings() end
end

local function selfPanelWidth(gliderCount, mountCount, equipmentVisible)
    local count = math.max(equipmentVisible and 3 or 0, tonumber(gliderCount) or 0, tonumber(mountCount) or 0)
    return math.floor((math.max(SELF_PANEL.minWidth, SELF_PANEL.left + (count * SELF_PANEL.iconStep) + 4) * uiScaleFactor("selfScaleLevel")) + 0.5)
end

function TargetOverlay.setSelfEquipmentVisible(visible)
    if not selfWnd or not selfWnd.equipIcons then return end
    for i, icon in ipairs(selfWnd.equipIcons) do
        icon:Show(visible)
        if selfWnd.equipLabels[i] then selfWnd.equipLabels[i]:Show(visible) end
    end
end

local function positionSelfEquipmentRow(y)
    if not selfWnd or not selfWnd.equipIcons then return end
    local scale = uiScaleFactor("selfScaleLevel")
    local xs = { SELF_PANEL.left, SELF_PANEL.left + 42, SELF_PANEL.left + 84 }
    for i, icon in ipairs(selfWnd.equipIcons) do
        local x = math.floor((xs[i] * scale) + 0.5)
        local iconY = math.floor((y * scale) + 0.5)
        icon:SetExtent(math.floor((24 * scale) + 0.5), math.floor((24 * scale) + 0.5))
        icon:RemoveAllAnchors()
        icon:AddAnchor("TOPLEFT", selfWnd, x, iconY)
        if icon.timerLabel then
            icon.timerLabel:SetExtent(math.floor((24 * scale) + 0.5), math.floor((24 * scale) + 0.5))
            icon.timerLabel.style:SetFontSize(math.floor((10 * scale) + 0.5))
        end
        selfWnd.equipLabels[i]:RemoveAllAnchors()
        selfWnd.equipLabels[i]:SetExtent(math.floor((46 * scale) + 0.5), math.floor((10 * scale) + 0.5))
        selfWnd.equipLabels[i].style:SetFontSize(math.floor((7 * scale) + 0.5))
        selfWnd.equipLabels[i]:AddAnchor("TOPLEFT", selfWnd, math.floor(((xs[i] - 10) * scale) + 0.5), math.floor(((y + 24) * scale) + 0.5))
    end
end

local function resizeSelfPanel(gliderCount, mountCount, cooldownsVisible, equipmentVisible)
    if not selfWnd then return end
    local width = selfPanelWidth(gliderCount, mountCount, equipmentVisible)
    local scale = uiScaleFactor("selfScaleLevel")
    local baseHeight = cooldownsVisible and (equipmentVisible and SELF_PANEL.height or 104) or (equipmentVisible and 60 or SELF_PANEL.headerHeight)
    local height = math.floor((baseHeight * scale) + 0.5)
    local equipY = cooldownsVisible and SELF_PANEL.equipY or SELF_PANEL.gliderY
    if equipmentVisible and selfWnd._equipY ~= equipY then
        positionSelfEquipmentRow(equipY)
        selfWnd._equipY = equipY
    end
    TargetOverlay.setSelfEquipmentVisible(equipmentVisible)
    if selfWnd._lastWidth ~= width or selfWnd._lastHeight ~= height then
        selfWnd:SetExtent(width, height)
        if selfWnd.header then selfWnd.header:SetExtent(width, math.floor((SELF_PANEL.headerHeight * scale) + 0.5)) end
        if selfWnd.dragHandle then selfWnd.dragHandle:SetExtent(width, math.floor((SELF_PANEL.headerHeight * scale) + 0.5)) end
        if selfWnd.title then
            selfWnd.title:RemoveAllAnchors()
            selfWnd.title:AddAnchor("TOPLEFT", selfWnd, math.floor((8 * scale) + 0.5), math.floor((3 * scale) + 0.5))
            selfWnd.title:SetExtent(math.floor((110 * scale) + 0.5), math.floor((14 * scale) + 0.5))
            selfWnd.title.style:SetFontSize(math.floor((11 * scale) + 0.5))
        end
        if selfWnd.status then
            if selfWnd.status.RemoveAllAnchors then selfWnd.status:RemoveAllAnchors() end
            selfWnd.status:SetExtent(math.max(math.floor((46 * scale) + 0.5), width - math.floor((116 * scale) + 0.5)), math.floor((14 * scale) + 0.5))
            selfWnd.status.style:SetFontSize(math.floor((10 * scale) + 0.5))
            selfWnd.status:AddAnchor("TOPLEFT", selfWnd, math.floor((112 * scale) + 0.5), math.floor((3 * scale) + 0.5))
        end
        selfWnd._lastWidth = width
        selfWnd._lastHeight = height
    end
end

local function clearSelfCooldownRow(icons, labels)
    for i, icon in ipairs(icons or {}) do
        icon:Show(false)
        if labels and labels[i] then labels[i]:SetText("") end
    end
end

local function ensureSelfCooldownRow(icons, labels, prefix, y, wanted)
    if not selfWnd then return end
    local scale = uiScaleFactor("selfScaleLevel")
    local count = math.max(tonumber(wanted) or 0, #icons)
    for i = #icons + 1, count do
        local x = math.floor(((SELF_PANEL.left + ((i - 1) * SELF_PANEL.iconStep)) * scale) + 0.5)
        icons[i] = createIcon(selfWnd, prefix .. "_icon_" .. i, x, math.floor((y * scale) + 0.5), math.floor((SELF_PANEL.iconSize * scale) + 0.5))
        labels[i] = label(selfWnd, prefix .. "_label_" .. i, "", math.floor(((SELF_PANEL.left + ((i - 1) * SELF_PANEL.iconStep) - 3) * scale) + 0.5), math.floor(((y + 28) * scale) + 0.5), math.floor((34 * scale) + 0.5), math.floor((10 * scale) + 0.5), math.floor((7 * scale) + 0.5), COLORS.white, ALIGN.CENTER)
        labels[i]:Clickable(false)
    end
    for i, icon in ipairs(icons) do
        local x = SELF_PANEL.left + ((i - 1) * SELF_PANEL.iconStep)
        local size = math.floor((SELF_PANEL.iconSize * scale) + 0.5)
        icon:SetExtent(size, size)
        icon:RemoveAllAnchors()
        icon:AddAnchor("TOPLEFT", selfWnd, math.floor((x * scale) + 0.5), math.floor((y * scale) + 0.5))
        if icon.timerLabel then
            icon.timerLabel:SetExtent(size, size)
            icon.timerLabel.style:SetFontSize(math.floor((10 * scale) + 0.5))
        end
        labels[i]:SetExtent(math.floor((34 * scale) + 0.5), math.floor((10 * scale) + 0.5))
        labels[i].style:SetFontSize(math.floor((7 * scale) + 0.5))
        labels[i]:RemoveAllAnchors()
        labels[i]:AddAnchor("TOPLEFT", selfWnd, math.floor(((x - 3) * scale) + 0.5), math.floor(((y + 28) * scale) + 0.5))
    end
end

local function renderSelfCooldownRow(icons, labels, entries)
    local shown = 0
    for i, icon in ipairs(icons or {}) do
        local entry = entries and entries[i]
        if entry then
            setCooldownSkillIcon(icon, entry.icon, entry.state or "ready", entry.remain)
            if labels and labels[i] then labels[i]:SetText(OverlayUtils.shortText(entry.name, 7)) end
            shown = i
        else
            icon:Show(false)
            if labels and labels[i] then labels[i]:SetText("") end
        end
    end
    return shown
end

local function trackedBuffCooldownEntry(row, st, glider, mount)
    local name = row.name or st.name or tostring(row.id)
    local iconState = "ready"
    local remain = nil
    if st.active then
        if (row.cooldownOnlyOnActive or TargetOverlay.isStarTriggerCooldown(row)) and st.readyAt then
            remain = math.max(0, math.ceil((st.readyAt - api.Time:GetUiMsec()) / 1000))
            iconState = "cooldown"
        else
            remain = OverlayUtils.buffRemainText(st.timeLeft)
            iconState = row.cooldownAura and "cooldown" or "active"
        end
    elseif st.readyAt then
        remain = math.max(0, math.ceil((st.readyAt - api.Time:GetUiMsec()) / 1000))
        iconState = "cooldown"
    end
    return {
        name = name,
        icon = (row.preferMountIcon and ((mount and mount.icon) or TargetOverlay.cooldownRowIcon(row) or st.icon)) or (row.gliderPattern and (TargetOverlay.cooldownRowIcon(row) or st.icon or (TargetOverlay.trackedGliderMatches(row, glider) and glider and glider.icon))) or (st.icon or TargetOverlay.cooldownRowIcon(row) or TargetOverlay.buffIconById(row.id)),
        state = iconState,
        remain = remain
    }
end

local function trackedSkillCooldownKey(row, skillName, skillId)
    return tostring(row and (row.importKey or row.id or row.skillId or row.pattern or row.name) or skillName or skillId or "")
end

local function trackedSkillCooldownEntry(row, now)
    local key = trackedSkillCooldownKey(row)
    local cd = key ~= "" and skillCooldowns[key] or nil
    if cd and cd.readyAt and cd.readyAt > now then
        return {
            name = cd.name or row.name or row.id,
            icon = cd.icon or row.icon or TargetOverlay.skillIconById(row.id or row.skillId),
            state = "cooldown",
            remain = math.max(0, math.ceil((cd.readyAt - now) / 1000))
        }
    end
    if cd then skillCooldowns[key] = nil end
    return {
        name = row.name or row.pattern or row.id,
        icon = row.icon or TargetOverlay.skillIconById(row.id or row.skillId),
        state = "ready",
        remain = nil
    }
end

local function createSelfWindow()
    selfWnd = api.Interface:CreateEmptyWindow("PowerRangerSelf", "UIParent")
    selfWnd:SetExtent(SELF_PANEL.minWidth, SELF_PANEL.height)
    local x, y = TargetOverlay.safeWindowPosition(settings.selfX, settings.selfY, SELF_PANEL.minWidth, SELF_PANEL.height)
    selfWnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    if selfWnd.Clickable then selfWnd:Clickable(false) end
    addBg(selfWnd, 0, 0, 0, 0.62)
    selfWnd.header = selfWnd:CreateColorDrawable(0.06, 0.075, 0.095, 0.76, "background")
    selfWnd.header:SetExtent(SELF_PANEL.minWidth, SELF_PANEL.headerHeight)
    selfWnd.header:AddAnchor("TOPLEFT", selfWnd, 0, 0)
    selfWnd.header:Show(true)
    local title = label(selfWnd, "power_ranger_self_title", "Self CDs", 8, 3, 110, 14, 11, COLORS.gold, ALIGN.LEFT)
    title:Clickable(false)
    selfWnd.title = title
    selfWnd.dragHandle = selfWnd:CreateChildWidget("emptywidget", "power_ranger_self_drag", 0, true)
    selfWnd.dragHandle:SetExtent(SELF_PANEL.minWidth, SELF_PANEL.headerHeight)
    selfWnd.dragHandle:AddAnchor("TOPLEFT", selfWnd, 0, 0)
    selfWnd.dragHandle:Show(true)
    applyHandleDrag(selfWnd, selfWnd.dragHandle, "selfX", "selfY")
    selfWnd.status = label(selfWnd, "power_ranger_self_status", "", 112, 3, 48, 14, 10, COLORS.muted, ALIGN.RIGHT)
    selfWnd.status:Clickable(false)
    selfWnd.gliderIcons = {}
    selfWnd.gliderLabels = {}
    selfWnd.mountIcons = {}
    selfWnd.mountLabels = {}
    for i = 1, SELF_PANEL.maxRowIcons do
        local x = SELF_PANEL.left + ((i - 1) * SELF_PANEL.iconStep)
        selfWnd.gliderIcons[i] = createIcon(selfWnd, "power_ranger_self_glider_cd_icon_" .. i, x, SELF_PANEL.gliderY, SELF_PANEL.iconSize)
        selfWnd.gliderLabels[i] = label(selfWnd, "power_ranger_self_glider_cd_label_" .. i, "", x - 3, SELF_PANEL.gliderY + 28, 34, 10, 7, COLORS.white, ALIGN.CENTER)
        selfWnd.mountIcons[i] = createIcon(selfWnd, "power_ranger_self_mount_cd_icon_" .. i, x, SELF_PANEL.mountY, SELF_PANEL.iconSize)
        selfWnd.mountLabels[i] = label(selfWnd, "power_ranger_self_mount_cd_label_" .. i, "", x - 3, SELF_PANEL.mountY + 28, 34, 10, 7, COLORS.white, ALIGN.CENTER)
        selfWnd.gliderLabels[i]:Clickable(false)
        selfWnd.mountLabels[i]:Clickable(false)
    end
    selfWnd.equipIcons = {}
    selfWnd.equipLabels = {}
    selfWnd.equipIcons[1] = createIcon(selfWnd, "power_ranger_self_equip_weapon", SELF_PANEL.left, SELF_PANEL.equipY, 24)
    selfWnd.equipLabels[1] = label(selfWnd, "power_ranger_self_equip_weapon_label", "Weapon", SELF_PANEL.left - 10, SELF_PANEL.equipY + 24, 46, 10, 7, COLORS.muted, ALIGN.CENTER)
    selfWnd.equipIcons[2] = createIcon(selfWnd, "power_ranger_self_equip_offhand", SELF_PANEL.left + 42, SELF_PANEL.equipY, 24)
    selfWnd.equipLabels[2] = label(selfWnd, "power_ranger_self_equip_offhand_label", "Offhand", SELF_PANEL.left + 32, SELF_PANEL.equipY + 24, 46, 10, 7, COLORS.muted, ALIGN.CENTER)
    selfWnd.equipIcons[3] = createIcon(selfWnd, "power_ranger_self_equip_glider", SELF_PANEL.left + 84, SELF_PANEL.equipY, 24)
    selfWnd.equipLabels[3] = label(selfWnd, "power_ranger_self_equip_glider_label", "Glider", SELF_PANEL.left + 74, SELF_PANEL.equipY + 24, 46, 10, 7, COLORS.muted, ALIGN.CENTER)
    selfWnd.equipLabels[1]:Clickable(false)
    selfWnd.equipLabels[2]:Clickable(false)
    selfWnd.equipLabels[3]:Clickable(false)
    selfWnd:Show(false)
end

local function updateSelfEquipmentIcons()
    if not selfWnd or not selfWnd.equipIcons then return end
    if settings.showSelfEquipment == false then
        TargetOverlay.setSelfEquipmentVisible(false)
        return
    end
    TargetOverlay.setSelfEquipmentVisible(true)
    local now = api.Time:GetUiMsec()
    if selfWnd._equipReady and now - lastSelfEquipmentUpdate < 1000 then return end
    lastSelfEquipmentUpdate = now
    selfWnd._equipReady = true
    local weapon = TargetOverlay.equippedSnapshot(EQUIP_SLOT and EQUIP_SLOT.MAINHAND) or {}
    local offhand = TargetOverlay.equippedSnapshot(EQUIP_SLOT and EQUIP_SLOT.OFFHAND) or {}
    local glider = TargetOverlay.equippedSnapshot(TargetOverlay.gliderEquipSlot()) or {}
    setEquipIcon(selfWnd.equipIcons[1], weapon.icon)
    setEquipIcon(selfWnd.equipIcons[2], offhand.icon)
    setEquipIcon(selfWnd.equipIcons[3], glider.icon)
end

local function updateSelfPanel()
    if not selfWnd then return end
    if settings.showSelfPanel == false or Compat.ShouldHideSelfPanel(compatState) then
        selfWnd:Show(false)
        return
    end
    if settings.showSelfCooldowns == false then
        if selfWnd.status then selfWnd.status:SetText("OFF") end
        clearSelfCooldownRow(selfWnd.gliderIcons, selfWnd.gliderLabels)
        clearSelfCooldownRow(selfWnd.mountIcons, selfWnd.mountLabels)
        resizeSelfPanel(0, 0, false, settings.showSelfEquipment ~= false)
        updateSelfEquipmentIcons()
        selfWnd:Show(true)
        return
    end

    local t = api.Time:GetUiMsec()
    if selfWnd.status then selfWnd.status:SetText(settings.skillProbeLogging and "LOG" or "") end
    updateSelfEquipmentIcons()
    local glider = TargetOverlay.equippedGliderSnapshot()
    local mount = TargetOverlay.mountedPetSnapshot()
    local gliderEntries = {}
    local mountEntries = {}
    for _, row in ipairs(allTrackedBuffRows()) do
        if row.enabled ~= false then
            local key = trackedBuffKey(row)
            local st = buffState[key] or {}
            local visibleForGlider = row.gliderPattern or row.category == "glider" or TargetOverlay.trackedGliderMatches(row, glider) or st.active or st.readyAt
            if visibleForGlider then
                local entry = trackedBuffCooldownEntry(row, st, glider, mount)
                if row.gliderPattern or row.category == "glider" then
                    table.insert(gliderEntries, entry)
                else
                    table.insert(mountEntries, entry)
                end
            end
        end
    end

    for _, row in ipairs(allTrackedSkillRows()) do
        if row.enabled ~= false then
            table.insert(mountEntries, trackedSkillCooldownEntry(row, t))
        end
    end
    ensureSelfCooldownRow(selfWnd.gliderIcons, selfWnd.gliderLabels, "power_ranger_self_glider_cd_dynamic", SELF_PANEL.gliderY, #gliderEntries)
    ensureSelfCooldownRow(selfWnd.mountIcons, selfWnd.mountLabels, "power_ranger_self_mount_cd_dynamic", SELF_PANEL.mountY, #mountEntries)
    resizeSelfPanel(#gliderEntries, #mountEntries, true, settings.showSelfEquipment ~= false)
    renderSelfCooldownRow(selfWnd.gliderIcons, selfWnd.gliderLabels, gliderEntries)
    renderSelfCooldownRow(selfWnd.mountIcons, selfWnd.mountLabels, mountEntries)
    selfWnd:Show(true)
end

function serialValue(value)
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

local DETECTED_SKILL_KEYWORDS = {
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

local function probeText(result, args, source, target, combatEvent)
    local parts = { tostring(combatEvent or ""), tostring(source or ""), tostring(target or "") }
    appendProbeText(parts, result, 0)
    appendProbeText(parts, args, 0)
    return string.lower(table.concat(parts, " "))
end

local function hasProbeKeyword(text)
    for _, keyword in ipairs(PROBE_KEYWORDS) do
        if text:find(keyword, 1, true) then return true end
    end
    return false
end

local function auraSnapshot(unit, maxCount)
    local out = {}
    local limit = math.min(tonumber(maxCount) or 32, 80)
    local function addAura(kind, aura)
        local id = TargetOverlay.buffId(aura)
        local tooltip = TargetOverlay.buffTooltipById(id)
        local name = OverlayUtils.textField(tooltip, {"name", "title", "buff_name"}) or TargetOverlay.buffName(aura) or TargetOverlay.buffNameById(id)
        table.insert(out, {
            kind = kind,
            id = id,
            idText = OverlayUtils.formatBuffId(id),
            name = name,
            description = OverlayUtils.textField(tooltip, {"description", "desc", "tooltip"}),
            icon = OverlayUtils.iconPath(aura) or OverlayUtils.iconPath(tooltip) or TargetOverlay.buffIconById(id),
            cooldown = TargetOverlay.buffCooldownById(id),
            stack = type(aura) == "table" and aura.stack or nil,
            timeLeft = type(aura) == "table" and aura.timeLeft or nil
        })
    end
    local buffCount = tonumber(OverlayUtils.safeCall(function() return api.Unit:UnitBuffCount(unit) end)) or 0
    for i = 1, math.min(buffCount, limit) do
        local b = OverlayUtils.safeCall(function() return api.Unit:UnitBuff(unit, i) end)
        if b then addAura("buff", b) end
    end
    local debuffCount = tonumber(OverlayUtils.safeCall(function() return api.Unit:UnitDeBuffCount(unit) end)) or 0
    for i = 1, math.min(debuffCount, limit) do
        local b = OverlayUtils.safeCall(function() return api.Unit:UnitDeBuff(unit, i) end)
        if b then addAura("debuff", b) end
    end
    return out
end

local function probeSnapshot(eventName)
    return {
        event = eventName,
        playerAuras = auraSnapshot("player", 64),
        playerPetAuras = auraSnapshot("playerpet", 64),
        targetAuras = auraSnapshot("target", 32),
        equipment = {
            mainhand = serialValue(TargetOverlay.equippedSnapshot(EQUIP_SLOT and EQUIP_SLOT.MAINHAND) or {}),
            offhand = serialValue(TargetOverlay.equippedSnapshot(EQUIP_SLOT and EQUIP_SLOT.OFFHAND) or {}),
            back = serialValue(TargetOverlay.equippedSnapshot(EQUIP_SLOT and EQUIP_SLOT.BACK) or {}),
            glider = serialValue(TargetOverlay.equippedSnapshot(TargetOverlay.gliderEquipSlot()) or {})
        }
    }
end

local function auraLooksLikeCooldownSkill(aura)
    if type(aura) ~= "table" then return false end
    local name = string.lower(tostring(aura.name or ""))
    local desc = string.lower(tostring(aura.description or ""))
    local haystack = name .. " " .. desc
    local directNameHit = false
    for _, keyword in ipairs(DETECTED_SKILL_KEYWORDS) do
        if haystack:find(keyword, 1, true) then directNameHit = true break end
    end
    if not directNameHit then return false end
    if name:find("equip ", 1, true) or name:find("leather set", 1, true) or name:find("armor", 1, true) then return false end
    if name:find("eanna", 1, true) or name:find("blessing", 1, true) then return false end
    local timeLeft = tonumber(aura.timeLeft)
    if timeLeft and timeLeft > 0 and timeLeft <= 600000 then return true end
    return haystack:find("cooldown", 1, true) or haystack:find("cannot be used", 1, true)
end

function TargetOverlay.auraLooksLikeUsefulCandidate(aura, source)
    if auraLooksLikeCooldownSkill(aura) then return true end
    local timeLeft = tonumber(aura and aura.timeLeft)
    if not timeLeft or timeLeft <= 0 or timeLeft > 180000 then return false end
    if source == "Mount/Pet" then return true end
    return aura and aura.icon ~= nil
end

local function detectFromAuraList(list, source, unit)
    for _, aura in ipairs(list or {}) do
        if TargetOverlay.auraLooksLikeUsefulCandidate(aura, source) and recordDetectedSkill then
            recordDetectedSkill(aura.name, aura.id, source, tostring(aura.name or "") .. " " .. tostring(aura.description or ""), {
                kind = "buff",
                unit = unit,
                icon = aura.icon,
                cooldown = aura.cooldown,
                auraKind = aura.kind,
                timeLeft = aura.timeLeft,
                description = aura.description
            })
        end
    end
end

local function detectFromProbeSnapshot(snapshot)
    if settings.skillProbeLogging ~= true or type(snapshot) ~= "table" then return end
    detectFromAuraList(snapshot.playerAuras, "Player", "player")
    detectFromAuraList(snapshot.playerPetAuras, "Mount/Pet", "playerpet")
end

local function updateProbeLogging(dt)
    if settings.skillProbeLogging ~= true then
        probeLogElapsed = 0
        return
    end
    probeLogElapsed = probeLogElapsed + (dt or 0)
    if probeLogElapsed < PROBE_LOG_INTERVAL_MS then return end
    probeLogElapsed = 0
    local snapshot = probeSnapshot("PROBE_LOG_TICK")
    recordSkillProbe(snapshot)
    detectFromProbeSnapshot(snapshot)
end

local function saveSkillProbe()
    if not skillProbeDirty then return end
    skillProbeDirty = false
    OverlayUtils.safeCall(function() api.File:Write("power_ranger_skill_probe.lua", skillProbe.entries) end)
end

function recordSkillProbe(entry)
    entry.time = api.Time:GetUiMsec()
    table.insert(skillProbe.entries, entry)
    while #skillProbe.entries > skillProbe.maxEntries do table.remove(skillProbe.entries, 1) end
    skillProbeDirty = true
end

local function parsedCombatMessage(combatEvent, args)
    if not ParseCombatMessage or not unpackArgs then return nil end
    return OverlayUtils.safeCall(function() return ParseCombatMessage(combatEvent, unpackArgs(args)) end)
end

local function extractSkillFields(result, args)
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

local function findTrackedSkill(skillName, skillId)
    local lowerName = string.lower(tostring(skillName or ""))
    for _, row in ipairs(allTrackedSkillRows()) do
        if row.enabled ~= false then
            local rowId = tonumber(row.id or row.skillId)
            local pattern = string.lower(tostring(row.pattern or row.name or ""))
            if rowId and skillId and rowId == tonumber(skillId) then return row end
            if pattern ~= "" and lowerName:find(pattern, 1, true) then return row end
        end
    end
    return nil
end

local function detectedSkillKey(skillName, skillId)
    local id = tonumber(skillId)
    if id then return "id:" .. tostring(id) end
    local name = string.lower(tostring(skillName or ""))
    if name == "" then return nil end
    return "name:" .. name
end

local function trackedSkillIndex(skillName, skillId)
    local key = detectedSkillKey(skillName, skillId)
    if not key then return nil end
    for i, row in ipairs(settings.trackedSkills or {}) do
        if detectedSkillKey(row.name or row.pattern, row.id or row.skillId) == key then return i end
    end
    return nil
end

local function lowerPattern(value)
    value = string.lower(tostring(value or ""))
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

function TargetOverlay.detectedRecipeRow(row, mode)
    if not row then return nil end
    mode = mode or "aura"
    local recipe = {
        enabled = true,
        recipeType = mode,
        unit = row.unit or "self",
        id = row.id,
        name = row.name or row.pattern or tostring(row.id),
        source = row.source or "Detected",
        cooldown = TargetOverlay.detectedCooldown(row.name or row.pattern, row.id, row.cooldown),
        icon = row.icon or TargetOverlay.buffIconById(row.id),
        cooldownStartsOnActive = true
    }
    if row.kind == "buff" and (row.name or row.pattern) then
        recipe.buffName = row.name or row.pattern
        recipe.buffNames = {row.name or row.pattern}
    end
    if mode == "glider" then
        local glider = TargetOverlay.equippedGliderSnapshot()
        local gliderName = glider.name or row.gliderName or row.source or "Glider"
        recipe.name = gliderName
        recipe.source = gliderName
        recipe.icon = glider.icon or row.gliderIcon or recipe.icon
        recipe.category = "glider"
        recipe.gliderPattern = {lowerPattern(gliderName)}
        if TargetOverlay.isStarTriggerCooldown(recipe) then
            recipe.cooldownOnlyOnActive = true
            recipe.triggerMinTimeLeftMs = 5300
        end
    elseif mode == "mount" then
        local mount = TargetOverlay.mountedPetSnapshot()
        local mountName = mount.name or row.mountName or row.source or "Mount"
        recipe.name = row.name or mountName
        recipe.source = mountName
        recipe.icon = mount.icon or row.mountIcon or recipe.icon
        recipe.category = "mount"
        recipe.preferMountIcon = true
    end
    return recipe
end

function TargetOverlay.detectedBuffTrackedIndex(row, mode)
    local probe = TargetOverlay.detectedRecipeRow(row, mode or "aura")
    if not probe then return nil end
    local key = trackedBuffSettingKey(probe)
    for i, tracked in ipairs(settings.trackedBuffs or {}) do
        if trackedBuffSettingKey(tracked) == key then return i end
    end
    return nil
end

local function inferSkillSource(skillName, sourceName, flatText)
    local lower = string.lower(tostring(flatText or "") .. " " .. tostring(skillName or "") .. " " .. tostring(sourceName or ""))
    if lower:find("meatball", 1, true) then return "Ser Meatball" end
    if lower:find("kirin", 1, true) then return "Kirin" end
    if lower:find("nui's veil", 1, true) or lower:find("nuis veil", 1, true) then return "Mount" end
    if lower:find("golem", 1, true) then return "Golem" end
    if lower:find("glider", 1, true) or lower:find("flight", 1, true) then return "Glider" end
    if sourceName and sourceName ~= "" and sourceName ~= playerName then return tostring(sourceName) end
    return "Unknown"
end

function TargetOverlay.detectedCooldownCategory(name, sourceName, unit, flatText)
    local lower = string.lower(tostring(name or "") .. " " .. tostring(sourceName or "") .. " " .. tostring(flatText or ""))
    if lower:find("glider", 1, true) or lower:find("flight", 1, true) or lower:find("wings", 1, true) then
        return "glider"
    end
    if unit == "playerpet" or lower:find("mount", 1, true) or lower:find("meatball", 1, true)
        or lower:find("kirin", 1, true) or lower:find("golem", 1, true) or lower:find("nui", 1, true) then
        return "mount"
    end
    return nil
end

local function detectFallbackSkillName(flatText)
    for _, keyword in ipairs(DETECTED_SKILL_KEYWORDS) do
        if flatText and flatText:find(keyword, 1, true) then
            if keyword == "invincible" or keyword == "invincibility" then return "Invincibility" end
            return keyword:sub(1, 1):upper() .. keyword:sub(2)
        end
    end
    return nil
end

function recordDetectedSkill(skillName, skillId, sourceName, flatText, extra)
    if settings.skillProbeLogging ~= true then return end
    local name = skillName or detectFallbackSkillName(flatText) or TargetOverlay.buffNameById(skillId)
    local key = detectedSkillKey(name, skillId)
    if not key then return end
    settings.detectedSkills = settings.detectedSkills or {}
    local detectedCategory = TargetOverlay.detectedCooldownCategory(name, sourceName, extra and extra.unit, flatText)
    local lowerDetectedName = string.lower(tostring(name or ""))
    local recipeCandidate = extra and extra.kind == "buff" and (detectedCategory == "glider" or lowerDetectedName:find("star", 1, true) ~= nil)
    if trackedCooldownIsHardcoded(name, skillId) and not recipeCandidate then
        for i = #settings.detectedSkills, 1, -1 do
            if settings.detectedSkills[i].key == key then table.remove(settings.detectedSkills, i) end
        end
        if detectedSkillsWnd and refreshDetectedSkillRows then refreshDetectedSkillRows() end
        return
    end
    local found = nil
    for _, row in ipairs(settings.detectedSkills) do
        if row.key == key then found = row break end
    end
    if not found then
        found = { key = key, firstSeen = api.Time:GetUiMsec(), seen = 0, cooldown = TargetOverlay.detectedCooldown(name, skillId, extra and extra.cooldown) }
        table.insert(settings.detectedSkills, 1, found)
        while #settings.detectedSkills > 24 do table.remove(settings.detectedSkills) end
    end
    found.kind = extra and extra.kind or found.kind or "skill"
    found.name = name
    found.id = tonumber(skillId) or found.id
    found.pattern = string.lower(tostring(name or ""))
    found.unit = extra and extra.unit or found.unit
    found.auraKind = extra and extra.auraKind or found.auraKind
    found.timeLeft = extra and extra.timeLeft or found.timeLeft
    found.description = extra and extra.description or found.description
    found.category = detectedCategory or found.category
    found.cooldown = TargetOverlay.detectedCooldown(name, skillId, extra and extra.cooldown or found.cooldown)
    found.source = inferSkillSource(name, sourceName, flatText)
    found.icon = (extra and extra.icon) or found.icon or (found.kind == "buff" and TargetOverlay.buffIconById(found.id) or TargetOverlay.skillIconById(found.id))
    local glider = TargetOverlay.equippedGliderSnapshot()
    if glider and glider.name then
        found.gliderName = glider.name
        found.gliderIcon = glider.icon or found.gliderIcon
    end
    local mount = TargetOverlay.mountedPetSnapshot()
    if mount and mount.name then
        found.mountName = mount.name
        found.mountIcon = mount.icon or found.mountIcon
    end
    found.seen = (tonumber(found.seen) or 0) + 1
    found.lastSeen = api.Time:GetUiMsec()
    if detectedSkillsWnd and refreshDetectedSkillRows then refreshDetectedSkillRows() end
end

local function startSkillCooldown(row, skillName, skillId)
    local cooldown = tonumber(row.cooldown or row.cooldownSeconds)
    if not cooldown or cooldown <= 0 then return end
    local key = trackedSkillCooldownKey(row, skillName, skillId)
    skillCooldowns[key] = {
        name = row.name or skillName or tostring(skillId),
        id = skillId or row.id or row.skillId,
        icon = TargetOverlay.cooldownRowIcon(row) or TargetOverlay.skillIconById(skillId or row.id or row.skillId),
        readyAt = api.Time:GetUiMsec() + (cooldown * 1000)
    }
end

local function onCombatMessage(targetUnitId, combatEvent, source, target, ...)
    local logging = settings.skillProbeLogging == true
    if not logging and not TargetOverlay.hasEnabledTrackedSkills() then return end
    local args = {...}
    local result = parsedCombatMessage(combatEvent, args)
    local skillName, skillId = extractSkillFields(result, args)
    local row = findTrackedSkill(skillName, skillId)
    if row then startSkillCooldown(row, skillName, skillId) end
    if not logging then return end
    if not playerName then playerName = TargetOverlay.getPlayerName() end
    local sourceName = tostring(source or "")
    local targetName = tostring(target or "")
    local flat = probeText(result, args, sourceName, targetName, combatEvent)
    local keywordHit = hasProbeKeyword(flat)
    if skillName or skillId or keywordHit then
        local entry = {
            event = "COMBAT_MSG",
            combatEvent = tostring(combatEvent or ""),
            targetUnitId = tostring(targetUnitId or ""),
            source = sourceName,
            target = targetName,
            skillName = skillName,
            skillId = skillId,
            keywordHit = keywordHit,
            parsed = serialValue(result),
            args = serialValue(args)
        }
        if keywordHit then
            entry.playerAuras = auraSnapshot("player", 16)
            entry.playerPetAuras = auraSnapshot("playerpet", 16)
            entry.targetAuras = auraSnapshot("target", 16)
        end
        recordSkillProbe(entry)
        recordDetectedSkill(skillName, skillId, sourceName, flat)
    end
end

local function onSkillEvent(event, ...)
    local logging = settings.skillProbeLogging == true
    if not logging and not TargetOverlay.hasEnabledTrackedSkills() then return end
    local args = {...}
    local skillName, skillId = extractSkillFields(nil, args)
    local row = findTrackedSkill(skillName, skillId)
    if row then startSkillCooldown(row, skillName, skillId) end
    if not logging then return end
    local flat = probeText(nil, args, "", "", event)
    local keywordHit = hasProbeKeyword(flat)
    if skillName or skillId or keywordHit then
        local entry = {
            event = tostring(event or ""),
            skillName = skillName,
            skillId = skillId,
            keywordHit = keywordHit,
            args = serialValue(args)
        }
        if keywordHit then
            entry.playerAuras = auraSnapshot("player", 16)
            entry.playerPetAuras = auraSnapshot("playerpet", 16)
            entry.targetAuras = auraSnapshot("target", 16)
        end
        recordSkillProbe(entry)
        recordDetectedSkill(skillName, skillId, "", flat)
    end
end

function TargetOverlay.hasEnabledTrackedSkills()
    for _, row in ipairs(allTrackedSkillRows()) do
        if row.enabled ~= false then return true end
    end
    return false
end

function TargetOverlay.refreshEventSubscriptions()
    if not eventWnd then return end
    local shouldListen = settings and (settings.skillProbeLogging == true or TargetOverlay.hasEnabledTrackedSkills()) or false
    if eventWnd._powerRangerListening == shouldListen then return end
    if shouldListen then
        pcall(function() eventWnd:RegisterEvent("COMBAT_MSG") end)
        pcall(function() eventWnd:RegisterEvent("SPELLCAST_START") end)
        pcall(function() eventWnd:RegisterEvent("SPELLCAST_SUCCEEDED") end)
        pcall(function() eventWnd:RegisterEvent("SPELLCAST_STOP") end)
    else
        pcall(function() eventWnd:UnregisterEvent("COMBAT_MSG") end)
        pcall(function() eventWnd:UnregisterEvent("SPELLCAST_START") end)
        pcall(function() eventWnd:UnregisterEvent("SPELLCAST_SUCCEEDED") end)
        pcall(function() eventWnd:UnregisterEvent("SPELLCAST_STOP") end)
    end
    eventWnd._powerRangerListening = shouldListen
end

local function createEventWindow()
    eventWnd = api.Interface:CreateEmptyWindow("PowerRangerEvents", "UIParent")
    eventWnd:SetExtent(1, 1)
    eventWnd:AddAnchor("TOPLEFT", "UIParent", 0, 0)
    if eventWnd.Clickable then eventWnd:Clickable(false) end
    eventWnd:SetHandler("OnEvent", function(self, event, ...)
        if event == "COMBAT_MSG" then
            onCombatMessage(...)
        elseif event == "SPELLCAST_START" or event == "SPELLCAST_SUCCEEDED" or event == "SPELLCAST_STOP" then
            onSkillEvent(event, ...)
        end
    end)
    eventWnd:Show(true)
    TargetOverlay.refreshEventSubscriptions()
end

local function dumpSkillProbe()
    local snapshot = probeSnapshot("MANUAL_SKILL_DUMP")
    recordSkillProbe(snapshot)
    detectFromProbeSnapshot(snapshot)
    skillProbeDirty = true
    saveSkillProbe()
    api.Log:Info("[Power Ranger On] wrote power_ranger_skill_probe.lua")
end

local function cooldownSettingEntries(group)
    local out = {}
    for i, row in ipairs(settings.trackedBuffs or {}) do
        local isGlider = row and (row.gliderPattern ~= nil or row.category == "glider")
        if group == nil or (group == "glider" and isGlider) or (group == "other" and not isGlider) then
            table.insert(out, { kind = "buff", index = i, row = row })
        end
    end
    if group == nil or group == "other" or group == "glider" then
        for i, row in ipairs(settings.trackedSkills or {}) do
            local isGlider = row and row.category == "glider"
            if group == nil or (group == "glider" and isGlider) or (group == "other" and not isGlider) then
                table.insert(out, { kind = "skill", index = i, row = row })
            end
        end
    end
    return out
end

local function cooldownSettingIcon(entry)
    local row = entry and entry.row
    if not row then return nil end
    if entry.kind == "skill" then return TargetOverlay.cooldownRowIcon(row) or TargetOverlay.skillIconById(row.id or row.skillId) end
    if row.gliderPattern then
        local glider = TargetOverlay.equippedGliderSnapshot()
        if TargetOverlay.trackedGliderMatches(row, glider) then return TargetOverlay.cooldownRowIcon(row) or glider.icon or TargetOverlay.buffIconById(row.id) end
        return TargetOverlay.cooldownRowIcon(row) or TargetOverlay.buffIconById(row.id)
    end
    return TargetOverlay.cooldownRowIcon(row) or TargetOverlay.buffIconById(row.id)
end

local function cooldownSettingName(entry)
    local row = entry and entry.row
    if not row then return "" end
    return row.name or row.buffName or row.pattern or tostring(row.id or row.skillId or "")
end

local function cooldownSettingSource(entry)
    local row = entry and entry.row
    if not row then return "" end
    if entry.kind == "skill" then return row.source or "Detected" end
    return row.source or row.mount or row.unit or ""
end

local function cooldownSettingCooldown(entry)
    local row = entry and entry.row
    if not row then return "-" end
    return tostring(row.cooldown or row.cooldownSeconds or "-") .. "s"
end

local function clearSkillCooldownForRow(row)
    if not row then return end
    local key = trackedSkillCooldownKey(row)
    if key ~= "" then skillCooldowns[key] = nil end
end

local function isDefaultTrackedBuff(row)
    local key = trackedBuffSettingKey(row)
    for _, defaultRow in ipairs(defaults.trackedBuffs or {}) do
        if trackedBuffSettingKey(defaultRow) == key then return true end
    end
    return false
end

local function cooldownSettingCanRemove(entry)
    if not entry or not entry.row then return false end
    if entry.kind == "skill" then return true end
    return not isDefaultTrackedBuff(entry.row)
end

local function cooldownSettingRowSet(group)
    if not settingsWnd then return nil end
    if group == "glider" then return settingsWnd.cooldownGliderRows end
    if group == "other" then return settingsWnd.cooldownOtherRows end
    return settingsWnd.cooldownSettingRows
end

local function cooldownSettingPageKey(group)
    if group == "glider" then return "cooldownGliderSettingsPage" end
    if group == "other" then return "cooldownOtherSettingsPage" end
    return "cooldownSettingsPage"
end

local function cooldownSettingPageWidgets(group)
    if not settingsWnd then return nil, nil, nil end
    if group == "glider" then
        return settingsWnd.cooldownGliderPageLabel, settingsWnd.cooldownGliderPrevBtn, settingsWnd.cooldownGliderNextBtn
    end
    if group == "other" then
        return settingsWnd.cooldownOtherPageLabel, settingsWnd.cooldownOtherPrevBtn, settingsWnd.cooldownOtherNextBtn
    end
    return settingsWnd.cooldownPageLabel, settingsWnd.cooldownPrevBtn, settingsWnd.cooldownNextBtn
end

local function refreshCooldownSettingGroup(group, title)
    local rows = cooldownSettingRowSet(group)
    if not settingsWnd or not rows then return end
    local entries = cooldownSettingEntries(group)
    local pageSize = #rows
    local total = #entries
    local pages = math.max(1, math.ceil(total / math.max(1, pageSize)))
    local pageKey = cooldownSettingPageKey(group)
    settings[pageKey] = math.max(1, math.min(tonumber(settings[pageKey]) or 1, pages))
    local startIndex = ((settings[pageKey] - 1) * pageSize) + 1
    for i, ui in ipairs(rows) do
        local entry = entries[startIndex + i - 1]
        if entry and entry.row then
            local enabled = entry.row.enabled ~= false
            ui.entryKind = entry.kind
            ui.entryIndex = entry.index
            ui.entryGroup = group
            ui.entryFilteredIndex = startIndex + i - 1
            setEquipIcon(ui.icon, cooldownSettingIcon(entry))
            ui.name:SetText(OverlayUtils.shortText(cooldownSettingName(entry), 18))
            ui.source:SetText(OverlayUtils.shortText(cooldownSettingSource(entry), 18))
            ui.cd.entryKind = entry.kind
            ui.cd.entryIndex = entry.index
            ui.cd._settingText = true
            ui.cd:SetText(tostring(entry.row.cooldown or entry.row.cooldownSeconds or ""))
            ui.cd._settingText = false
            ui.cd:Show(true)
            setToggleButton(ui.button, enabled, "Show")
            if ui.remove then
                ui.remove.entryKind = entry.kind
                ui.remove.entryIndex = entry.index
                ui.remove:SetCleanText("Del")
                ui.remove:SetTone({0.24, 0.09, 0.09, 0.95})
                ui.remove:Show(cooldownSettingCanRemove(entry))
            end
            if ui.up then
                local prevEntry = entries[(startIndex + i - 1) - 1]
                ui.up.entryKind = entry.kind
                ui.up.entryIndex = entry.index
                ui.up.entryGroup = group
                ui.up:SetCleanText("^")
                ui.up:SetTone(prevEntry and prevEntry.kind == entry.kind and COLORS.button or {0.08, 0.08, 0.09, 0.95})
            end
            if ui.down then
                local nextEntry = entries[(startIndex + i - 1) + 1]
                ui.down.entryKind = entry.kind
                ui.down.entryIndex = entry.index
                ui.down.entryGroup = group
                ui.down:SetCleanText("v")
                ui.down:SetTone(nextEntry and nextEntry.kind == entry.kind and COLORS.button or {0.08, 0.08, 0.09, 0.95})
            end
            ui.root:Show(true)
        else
            ui.entryKind = nil
            ui.entryIndex = nil
            ui.entryGroup = nil
            ui.entryFilteredIndex = nil
            if ui.remove then
                ui.remove.entryKind = nil
                ui.remove.entryIndex = nil
                ui.remove.entryGroup = nil
                ui.remove:Show(false)
            end
            if ui.up then
                ui.up.entryKind = nil
                ui.up.entryIndex = nil
                ui.up.entryGroup = nil
            end
            if ui.down then
                ui.down.entryKind = nil
                ui.down.entryIndex = nil
                ui.down.entryGroup = nil
            end
            if ui.cd then
                ui.cd.entryKind = nil
                ui.cd.entryIndex = nil
                ui.cd._settingText = true
                ui.cd:SetText("")
                ui.cd._settingText = false
                ui.cd:Show(false)
            end
            ui.root:Show(false)
        end
    end
    local pageLabel, prevBtn, nextBtn = cooldownSettingPageWidgets(group)
    if pageLabel then
        local fromText = total > 0 and tostring(startIndex) or "0"
        local toText = tostring(math.min(startIndex + pageSize - 1, total))
        pageLabel:SetText(title .. " " .. fromText .. "-" .. toText .. " / " .. tostring(total))
    end
    if prevBtn then
        prevBtn:SetCleanText("<")
        prevBtn:SetTone(settings[pageKey] > 1 and COLORS.button or {0.08, 0.08, 0.09, 0.95})
    end
    if nextBtn then
        nextBtn:SetCleanText(">")
        nextBtn:SetTone(settings[pageKey] < pages and COLORS.button or {0.08, 0.08, 0.09, 0.95})
    end
end

local function refreshCooldownSettingRows()
    refreshCooldownSettingGroup("glider", "Gliders")
    refreshCooldownSettingGroup("other", "Mounts/skills")
end

local function toggleCooldownSetting(rowIndex, group)
    local rows = cooldownSettingRowSet(group)
    local ui = rows and rows[rowIndex]
    if not ui or not ui.entryKind or not ui.entryIndex then return end
    local list = ui.entryKind == "skill" and settings.trackedSkills or settings.trackedBuffs
    local row = list and list[ui.entryIndex]
    if not row then return end
    row.enabled = row.enabled == false
    if row.enabled == false then
        if ui.entryKind == "skill" then
            clearSkillCooldownForRow(row)
        else
            buffState[trackedBuffKey(row)] = nil
        end
    end
    TargetOverlay.refreshEventSubscriptions()
    saveSettings()
    refreshSettingsButtons()
end

local function removeCooldownSetting(rowIndex, group)
    local rows = cooldownSettingRowSet(group)
    local ui = rows and rows[rowIndex]
    if not ui or not ui.entryKind or not ui.entryIndex then return end
    if ui.entryKind == "skill" then
        local row = settings.trackedSkills and settings.trackedSkills[ui.entryIndex]
        clearSkillCooldownForRow(row)
        table.remove(settings.trackedSkills, ui.entryIndex)
    elseif ui.entryKind == "buff" then
        local row = settings.trackedBuffs and settings.trackedBuffs[ui.entryIndex]
        if not row or isDefaultTrackedBuff(row) then return end
        buffState[trackedBuffKey(row)] = nil
        table.remove(settings.trackedBuffs, ui.entryIndex)
    end
    TargetOverlay.refreshEventSubscriptions()
    saveSettings()
    refreshSettingsButtons()
end

local function moveCooldownSetting(rowIndex, delta, group)
    local rows = cooldownSettingRowSet(group)
    local ui = rows and rows[rowIndex]
    if not ui or not ui.entryKind or not ui.entryIndex then return end
    local entries = cooldownSettingEntries(group)
    local currentFiltered = tonumber(ui.entryFilteredIndex) or 0
    local targetEntry = entries[currentFiltered + delta]
    if not targetEntry or targetEntry.kind ~= ui.entryKind then return end
    local list = ui.entryKind == "skill" and settings.trackedSkills or settings.trackedBuffs
    local fromIndex = ui.entryIndex
    local toIndex = targetEntry.index
    if not list or toIndex < 1 or toIndex > #list then return end
    list[fromIndex], list[toIndex] = list[toIndex], list[fromIndex]
    saveSettings()
    refreshSettingsButtons()
end

local function shiftCooldownSettingsPage(delta, group)
    local entries = cooldownSettingEntries(group)
    local rows = cooldownSettingRowSet(group)
    local pageSize = rows and #rows or 3
    local pages = math.max(1, math.ceil(#entries / math.max(1, pageSize)))
    local pageKey = cooldownSettingPageKey(group)
    settings[pageKey] = math.max(1, math.min((tonumber(settings[pageKey]) or 1) + delta, pages))
    saveSettings()
    refreshSettingsButtons()
end

local function detectedDetailText(row)
    if not row then return "Select a detected row to inspect details." end
    local function short(value, maxLen)
        value = tostring(value or "-")
        if #value <= maxLen then return value end
        return value:sub(1, maxLen - 3) .. "..."
    end
    local pieces = {
        "Name: " .. short(row.name or row.pattern, 58),
        "Type: " .. tostring(row.kind or "-"),
        "ID: " .. tostring(row.id or "-"),
        "Seen: " .. tostring(row.seen or 0),
        "Unit: " .. tostring(row.unit or "-"),
        "Aura: " .. tostring(row.auraKind or "-"),
        "Category: " .. tostring(row.category or "-"),
        "Source: " .. short(row.source, 58),
        "Cooldown: " .. tostring(row.cooldown or "-") .. "s",
        "Time left: " .. tostring(row.timeLeft or "-"),
        "Pattern: " .. short(row.pattern, 58)
    }
    if row.gliderName then table.insert(pieces, "Glider: " .. short(row.gliderName, 58)) end
    if row.mountName then table.insert(pieces, "Mount: " .. short(row.mountName, 58)) end
    if row.description and row.description ~= "" then table.insert(pieces, "Desc: " .. short(row.description, 100)) end
    return table.concat(pieces, "\n")
end

local function showDetectedDetails(index)
    if not detectedSkillsWnd then return end
    settings.detectedDetailsIndex = index
    local row = settings.detectedSkills and settings.detectedSkills[index]
    if detectedSkillsWnd.details then
        detectedSkillsWnd.details:SetText(detectedDetailText(row))
    end
    refreshDetectedSkillRows()
end

local function toggleDetectedSkillTracking(index, mode)
    local row = settings.detectedSkills and settings.detectedSkills[index]
    if not row then return end
    if row.kind == "buff" then
        settings.trackedBuffs = settings.trackedBuffs or {}
        mode = mode or "aura"
        local trackedIndex = TargetOverlay.detectedBuffTrackedIndex(row, mode)
        if trackedIndex then
            buffState[trackedBuffKey(settings.trackedBuffs[trackedIndex])] = nil
            table.remove(settings.trackedBuffs, trackedIndex)
        elseif mode == "aura" and trackedCooldownIsHardcoded(row.name or row.pattern, row.id) then
            table.remove(settings.detectedSkills, index)
        else
            local recipe = TargetOverlay.detectedRecipeRow(row, mode)
            if recipe then table.insert(settings.trackedBuffs, recipe) end
        end
        TargetOverlay.refreshEventSubscriptions()
        saveSettings()
        refreshDetectedSkillRows()
        refreshSettingsButtons()
        return
    end
    settings.trackedSkills = settings.trackedSkills or {}
    local trackedIndex = trackedSkillIndex(row.name or row.pattern, row.id)
    if trackedIndex then
        local tracked = settings.trackedSkills[trackedIndex]
        clearSkillCooldownForRow(tracked)
        table.remove(settings.trackedSkills, trackedIndex)
    elseif trackedCooldownIsHardcoded(row.name or row.pattern, row.id) then
        table.remove(settings.detectedSkills, index)
    else
        table.insert(settings.trackedSkills, {
            enabled = true,
            name = row.name or row.pattern or tostring(row.id),
            pattern = row.pattern or string.lower(tostring(row.name or "")),
            id = row.id,
            icon = row.icon,
            source = row.source,
            category = row.category,
            cooldown = tonumber(row.cooldown) or 30
        })
    end
    TargetOverlay.refreshEventSubscriptions()
    saveSettings()
    refreshDetectedSkillRows()
    refreshSettingsButtons()
end

function refreshDetectedSkillRows()
    if not detectedSkillsWnd or not detectedSkillsWnd.rows then return end
    local rows = settings.detectedSkills or {}
    for i, ui in ipairs(detectedSkillsWnd.rows) do
        local row = rows[i]
        if row then
            if row.kind == "buff" then
                setToggleButton(ui.auraButton, TargetOverlay.detectedBuffTrackedIndex(row, "aura") ~= nil, "Aura")
                setToggleButton(ui.gliderButton, TargetOverlay.detectedBuffTrackedIndex(row, "glider") ~= nil, "Glid")
                setToggleButton(ui.mountButton, TargetOverlay.detectedBuffTrackedIndex(row, "mount") ~= nil, "Mount")
                ui.gliderButton:Show(true)
                ui.mountButton:Show(true)
            else
                setToggleButton(ui.auraButton, trackedSkillIndex(row.name or row.pattern, row.id) ~= nil, "Skill")
                ui.gliderButton:Show(false)
                ui.mountButton:Show(false)
            end
            setToggleButton(ui.detailsButton, settings.detectedDetailsIndex == i, "Info")
            setEquipIcon(ui.icon, row.icon or (row.kind == "buff" and TargetOverlay.buffIconById(row.id) or TargetOverlay.skillIconById(row.id)))
            ui.name:SetText(OverlayUtils.shortText(row.name or row.pattern or tostring(row.id or "Unknown"), 22))
            local context = row.source or "Unknown"
            if row.gliderName then
                context = context .. " | G:" .. tostring(row.gliderName)
            elseif row.mountName then
                context = context .. " | M:" .. tostring(row.mountName)
            end
            ui.meta:SetText(OverlayUtils.shortText((row.kind == "buff" and "Aura " or "Skill ") .. (row.id and ("ID " .. tostring(row.id) .. " | ") or "") .. context, 26))
            ui.seen:SetText("x" .. tostring(row.seen or 1))
            ui.root:Show(true)
        else
            ui.root:Show(false)
        end
    end
    if detectedSkillsWnd.details then
        local detailRow = settings.detectedSkills and settings.detectedSkills[settings.detectedDetailsIndex or 0]
        detectedSkillsWnd.details:SetText(detectedDetailText(detailRow))
    end
end

local function createDetectedSkillsWindow()
    if detectedSkillsWnd then return end
    detectedSkillsWnd = api.Interface:CreateEmptyWindow("PowerRangerDetectedSkills", "UIParent")
    detectedSkillsWnd:SetExtent(560, 504)
    local x, y = TargetOverlay.safeWindowPosition(settings.detectedSkillsX, settings.detectedSkillsY, 560, 504)
    detectedSkillsWnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    addBg(detectedSkillsWnd, 0, 0, 0, 0.96)
    local body = detectedSkillsWnd:CreateColorDrawable(COLORS.dark[1], COLORS.dark[2], COLORS.dark[3], COLORS.dark[4], "background")
    body:AddAnchor("TOPLEFT", detectedSkillsWnd, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", detectedSkillsWnd, -1, -1)
    body:Show(true)
    local header = detectedSkillsWnd:CreateColorDrawable(0.09, 0.09, 0.11, 0.98, "background")
    header:SetExtent(558, 30)
    header:AddAnchor("TOPLEFT", detectedSkillsWnd, 1, 1)
    header:Show(true)
    local title = label(detectedSkillsWnd, "power_ranger_detected_title", "Detected Cooldowns", 14, 7, 250, 16, 13, COLORS.gold, ALIGN.LEFT)
    applyDrag(detectedSkillsWnd, title, "detectedSkillsX", "detectedSkillsY")
    flatButton(detectedSkillsWnd, "power_ranger_detected_close", "X", 526, 5, 22, 20, COLORS.button, function() detectedSkillsWnd:Show(false) end)
    label(detectedSkillsWnd, "power_ranger_detected_hint", "Aura = plain buff. Glid = current glider + aura. Mount = pet/mount aura.", 14, 36, 520, 14, 10, COLORS.muted, ALIGN.LEFT)
    detectedSkillsWnd.rows = {}
    for i = 1, 8 do
        local y = 56 + ((i - 1) * 31)
        local root = detectedSkillsWnd:CreateChildWidget("emptywidget", "power_ranger_detected_row_" .. i, 0, true)
        root:SetExtent(532, 28)
        root:AddAnchor("TOPLEFT", detectedSkillsWnd, 14, y)
        local bg = root:CreateColorDrawable(i % 2 == 0 and 0.11 or 0.075, i % 2 == 0 and 0.11 or 0.075, i % 2 == 0 and 0.125 or 0.09, 0.74, "background")
        bg:AddAnchor("TOPLEFT", root, 0, 0)
        bg:AddAnchor("BOTTOMRIGHT", root, 0, 0)
        bg:Show(true)
        local icon = createIcon(root, "power_ranger_detected_icon_" .. i, 4, 2, 24)
        local name = label(root, "power_ranger_detected_name_" .. i, "", 36, 4, 135, 14, 10, COLORS.white, ALIGN.LEFT)
        local meta = label(root, "power_ranger_detected_meta_" .. i, "", 174, 4, 108, 14, 10, COLORS.muted, ALIGN.LEFT)
        local seen = label(root, "power_ranger_detected_seen_" .. i, "", 284, 4, 32, 14, 10, COLORS.muted, ALIGN.LEFT)
        local rowIndex = i
        local infoBtn = flatButton(root, "power_ranger_detected_info_" .. i, "", 318, 3, 46, 22, COLORS.button, function() showDetectedDetails(rowIndex) end)
        local auraBtn = flatButton(root, "power_ranger_detected_aura_" .. i, "", 366, 3, 48, 22, COLORS.active, function() toggleDetectedSkillTracking(rowIndex, "aura") end)
        local gliderBtn = flatButton(root, "power_ranger_detected_glider_" .. i, "", 416, 3, 50, 22, COLORS.active, function() toggleDetectedSkillTracking(rowIndex, "glider") end)
        local mountBtn = flatButton(root, "power_ranger_detected_mount_" .. i, "", 468, 3, 54, 22, COLORS.active, function() toggleDetectedSkillTracking(rowIndex, "mount") end)
        name:Clickable(false)
        meta:Clickable(false)
        seen:Clickable(false)
        detectedSkillsWnd.rows[i] = { root = root, icon = icon, name = name, meta = meta, seen = seen, detailsButton = infoBtn, auraButton = auraBtn, gliderButton = gliderBtn, mountButton = mountBtn }
    end
    local detailsPanel = panel(detectedSkillsWnd, "power_ranger_detected_details_panel", 14, 306, 532, 184)
    detectedSkillsWnd.details = label(detailsPanel, "power_ranger_detected_details", "Select a detected row to inspect details.", 8, 7, 516, 170, 10, COLORS.muted, ALIGN.LEFT)
    detectedSkillsWnd:Show(false)
end

local function openDetectedSkillsWindow()
    createDetectedSkillsWindow()
    refreshDetectedSkillRows()
    detectedSkillsWnd:Show(true)
end

function refreshSettingsButtons()
    if not settingsWnd then return end
    local compat = updateCompatState(true)
    local showNuziOptions = Compat.ShouldShowOptions(compat)
    setToggleButton(settingsWnd.compatModeBtn, compat.active, Compat.ModeLabel(compat))
    settingsWnd.compatModeBtn:Show(showNuziOptions)
    setToggleButton(settingsWnd.modelBtn, settings.showModelOverlay, "Overhead")
    setToggleButton(settingsWnd.armorBtn, settings.showArmorIcon, "Armor")
    setToggleButton(settingsWnd.weaponBtn, settings.showWeaponIcon, "Weapon")
    setToggleButton(settingsWnd.roleBtn, settings.showRoleIcon, "Role")
    setToggleButton(settingsWnd.modelGsBtn, settings.showModelGearscore, "Gear")
    setToggleButton(settingsWnd.modelClassBtn, settings.showModelClass, "Class")
    setToggleButton(settingsWnd.modelRangeBtn, settings.showModelRange, "Range")
    setToggleButton(settingsWnd.modelDefBtn, settings.showModelDefense, "Defense")
    setToggleButton(settingsWnd.modelCompactBtn, settings.compactModelOverlay, "Compact")
    setToggleButton(settingsWnd.shadowBtn, settings.overlayTextShadow, "Shadow")
    setToggleButton(settingsWnd.targetWindowBtn, settings.showTargetWindow, "Intel window")
    setToggleButton(settingsWnd.compactWindowBtn, settings.compactTargetWindow, "Compact")
    setToggleButton(settingsWnd.testWindowBtn, settings.testTargetWindow, "Compact/Simple")
    setToggleButton(settingsWnd.ownershipBtn, settings.showOwnershipLabels ~= false, "Ownership")
    setToggleButton(settingsWnd.selfBtn, settings.showSelfPanel, "Self win")
    setToggleButton(settingsWnd.selfCdBtn, settings.showSelfCooldowns, "Cooldowns")
    setToggleButton(settingsWnd.selfEquipmentBtn, settings.showSelfEquipment ~= false, "Equipment")
    setToggleButton(settingsWnd.nuziImportBtn, settings.importNuziCooldowns ~= false, "Nuzi CDs")
    settingsWnd.nuziImportBtn:Show(showNuziOptions)
    setToggleButton(settingsWnd.probeLogBtn, settings.skillProbeLogging, "Log")
    if settingsWnd.scaleValue then
        settingsWnd.scaleValue:SetText(tostring(settings.uiScaleLevel or 0))
    end
    if settingsWnd.modelLeftValue then
        settingsWnd.modelLeftValue:SetText(tostring(settings.compactModelLeftOffset or CONFIG.compactModelLeftOffset))
    end
    if settingsWnd.intelScaleValue then
        settingsWnd.intelScaleValue:SetText(tostring(settings.targetWindowScaleLevel or 0))
    end
    if settingsWnd.simpleColumnGapValue then
        settingsWnd.simpleColumnGapValue:SetText(tostring(settings.simpleColumnGap or 0))
    end
    if settingsWnd.simpleLineGapValue then
        settingsWnd.simpleLineGapValue:SetText(tostring(settings.simpleLineGap or 0))
    end
    if settingsWnd.selfScaleValue then
        settingsWnd.selfScaleValue:SetText(tostring(settings.selfScaleLevel or 0))
    end
    if settingsWnd.ownershipScaleValue then
        settingsWnd.ownershipScaleValue:SetText(tostring(settings.ownershipScaleLevel or 0))
    end
    refreshCooldownSettingRows()
    if settingsWnd.fieldButtons then
        for _, field in ipairs(TARGET_INFO_FIELDS) do
            local btn = settingsWnd.fieldButtons[field.key]
            if btn then setToggleButton(btn, settings[field.setting] ~= false, field.label) end
        end
    end
    if settingsWnd.colorCubes then
        for key, cube in pairs(settingsWnd.colorCubes) do
            if cube._fill then
                local color = settingColor(key)
                cube._fill:SetColor(color[1], color[2], color[3], color[4])
            end
        end
    end
end

local function cycleCompatMode()
    settings.nuziUiCompatMode = Compat.NextMode(settings.nuziUiCompatMode)
    updateCompatState(true)
    saveSettings()
    refreshSettingsButtons()
end

local function toggleSetting(key)
    settings[key] = not settings[key]
    if settings[key] then
        if key == "compactTargetWindow" then
            settings.testTargetWindow = false
        elseif key == "testTargetWindow" then
            settings.compactTargetWindow = false
        end
    end
    if key == "overlayTextShadow" then TargetOverlay.applyTextShadow() end
    if key == "showOwnershipLabels" and settings.showOwnershipLabels == false then hideOwnershipWindow() end
    if key == "importNuziCooldowns" then
        refreshNuziCooldownRows(true)
        TargetOverlay.refreshEventSubscriptions()
    end
    saveSettings()
    refreshSettingsButtons()
    if key == "showSelfEquipment" or key == "showSelfCooldowns" or key == "showSelfPanel" then updateSelfPanel() end
end

function TargetOverlay.shiftSimpleSpacing(key, delta, minValue, maxValue)
    settings[key] = math.max(minValue, math.min(maxValue, (tonumber(settings[key]) or minValue) + delta))
    if targetInfoWnd then
        targetInfoWnd._lastWidth = nil
        targetInfoWnd._lastHeight = nil
    end
    saveSettings()
    refreshSettingsButtons()
end

function TargetOverlay.shiftCompactModelLeft(delta)
    settings.compactModelLeftOffset = math.max(20, math.min(140, (tonumber(settings.compactModelLeftOffset) or CONFIG.compactModelLeftOffset) + delta))
    if mainCanvas then mainCanvas._layoutScale = nil end
    saveSettings()
    refreshSettingsButtons()
end

local function shiftUiScale(delta, key)
    key = key or "uiScaleLevel"
    local level = math.max(0, math.min(10, (tonumber(settings[key]) or 0) + (tonumber(delta) or 0)))
    settings[key] = level
    if selfWnd then
        selfWnd._lastWidth = nil
        selfWnd._lastHeight = nil
        selfWnd._equipY = nil
    end
    if targetInfoWnd then
        targetInfoWnd._lastWidth = nil
        targetInfoWnd._lastHeight = nil
    end
    if mainCanvas then mainCanvas._layoutScale = nil end
    lastScreenPosition = ""
    if settingsWnd and settingsWnd.scaleValue then
        settingsWnd.scaleValue:SetText(tostring(settings.uiScaleLevel or 0))
    end
    if settingsWnd and settingsWnd.intelScaleValue then
        settingsWnd.intelScaleValue:SetText(tostring(settings.targetWindowScaleLevel or 0))
    end
    if settingsWnd and settingsWnd.selfScaleValue then
        settingsWnd.selfScaleValue:SetText(tostring(settings.selfScaleLevel or 0))
    end
    if settingsWnd and settingsWnd.ownershipScaleValue then
        settingsWnd.ownershipScaleValue:SetText(tostring(settings.ownershipScaleLevel or 0))
    end
    if ownershipWnd then
        ownershipWnd._lastWidth = nil
        ownershipWnd._lastHeight = nil
    end
    if tonumber(delta) and tonumber(delta) ~= 0 then
        saveSettings()
    end
end

local function toggleProbeLogging()
    settings.skillProbeLogging = not settings.skillProbeLogging
    recordSkillProbe({ event = settings.skillProbeLogging and "PROBE_LOG_START" or "PROBE_LOG_STOP" })
    TargetOverlay.refreshEventSubscriptions()
    saveSettings()
    refreshSettingsButtons()
    saveSkillProbe()
    api.Log:Info("[Power Ranger On] skill probe logging " .. (settings.skillProbeLogging and "ON" or "OFF"))
end

local function createSettingsWindow()
    settingsWnd = api.Interface:CreateEmptyWindow("PowerRangerSettings", "UIParent")
    settingsWnd:SetExtent(620, 755)
    local x, y = TargetOverlay.safeWindowPosition(settings.settingsX, settings.settingsY, 620, 755)
    settingsWnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    addBg(settingsWnd, 0, 0, 0, 0.96)
    local body = settingsWnd:CreateColorDrawable(COLORS.dark[1], COLORS.dark[2], COLORS.dark[3], COLORS.dark[4], "background")
    body:AddAnchor("TOPLEFT", settingsWnd, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", settingsWnd, -1, -1)
    body:Show(true)
    local header = settingsWnd:CreateColorDrawable(0.09, 0.09, 0.11, 0.98, "background")
    header:SetExtent(618, 34)
    header:AddAnchor("TOPLEFT", settingsWnd, 1, 1)
    header:Show(true)
    local title = label(settingsWnd, "power_ranger_settings_title", "Power Ranger ON", 16, 8, 320, 18, 14, COLORS.gold, ALIGN.LEFT)
    applyDrag(settingsWnd, title, "settingsX", "settingsY", true)
    settingsWnd.compatModeBtn = flatButton(settingsWnd, "power_ranger_compat_mode", "", 414, 7, 160, 22, COLORS.blue, cycleCompatMode)
    flatButton(settingsWnd, "power_ranger_close", "X", 584, 7, 22, 22, COLORS.button, function() settingsWnd:Show(false) end)

    local p1 = sectionPanel(settingsWnd, "power_ranger_model_panel", 18, 52, 584, 112, "Target Overhead")
    settingsWnd.modelCompactBtn = flatButton(p1, "power_ranger_toggle_model_compact", "", 16, 32, 116, 20, COLORS.active, function() toggleSetting("compactModelOverlay") end)
    label(p1, "power_ranger_scale_label", "Scale", 144, 35, 36, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(p1, "power_ranger_scale_down", "-", 182, 32, 22, 20, COLORS.button, function() shiftUiScale(-1) end)
    settingsWnd.scaleValue = label(p1, "power_ranger_scale_value", "0", 206, 35, 20, 14, 10, COLORS.white, ALIGN.CENTER)
    flatButton(p1, "power_ranger_scale_up", "+", 228, 32, 22, 20, COLORS.button, function() shiftUiScale(1) end)
    label(p1, "power_ranger_model_left_label", "Left", 266, 35, 28, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(p1, "power_ranger_model_left_down", "-", 296, 32, 22, 20, COLORS.button, function() TargetOverlay.shiftCompactModelLeft(-1) end)
    settingsWnd.modelLeftValue = label(p1, "power_ranger_model_left_value", "45", 320, 35, 26, 14, 10, COLORS.white, ALIGN.CENTER)
    flatButton(p1, "power_ranger_model_left_up", "+", 348, 32, 22, 20, COLORS.button, function() TargetOverlay.shiftCompactModelLeft(1) end)
    settingsWnd.shadowBtn = flatButton(p1, "power_ranger_toggle_shadow", "", 388, 32, 154, 20, COLORS.active, function() toggleSetting("overlayTextShadow") end)
    settingsWnd.modelBtn = flatButton(p1, "power_ranger_toggle_model", "", 16, 56, 126, 24, COLORS.active, function() toggleSetting("showModelOverlay") end)
    settingsWnd.armorBtn = flatButton(p1, "power_ranger_toggle_armor", "", 152, 56, 126, 24, COLORS.active, function() toggleSetting("showArmorIcon") end)
    settingsWnd.weaponBtn = flatButton(p1, "power_ranger_toggle_weapon", "", 288, 56, 126, 24, COLORS.active, function() toggleSetting("showWeaponIcon") end)
    settingsWnd.roleBtn = flatButton(p1, "power_ranger_toggle_role", "", 424, 56, 126, 24, COLORS.active, function() toggleSetting("showRoleIcon") end)
    settingsWnd.modelGsBtn = flatButton(p1, "power_ranger_toggle_model_gs", "", 16, 84, 126, 24, COLORS.active, function() toggleSetting("showModelGearscore") end)
    settingsWnd.modelClassBtn = flatButton(p1, "power_ranger_toggle_model_class", "", 152, 84, 126, 24, COLORS.active, function() toggleSetting("showModelClass") end)
    settingsWnd.modelRangeBtn = flatButton(p1, "power_ranger_toggle_model_range", "", 288, 84, 126, 24, COLORS.active, function() toggleSetting("showModelRange") end)
    settingsWnd.modelDefBtn = flatButton(p1, "power_ranger_toggle_model_def", "", 424, 84, 126, 24, COLORS.active, function() toggleSetting("showModelDefense") end)

    local p2 = sectionPanel(settingsWnd, "power_ranger_window_panel", 18, 176, 584, 229, "Intel Window")
    settingsWnd.targetWindowBtn = flatButton(p2, "power_ranger_toggle_window", "", 16, 32, 124, 22, COLORS.active, function() toggleSetting("showTargetWindow") end)
    settingsWnd.compactWindowBtn = flatButton(p2, "power_ranger_toggle_compact_window", "", 148, 32, 96, 22, COLORS.active, function() toggleSetting("compactTargetWindow") end)
    settingsWnd.testWindowBtn = flatButton(p2, "power_ranger_toggle_test_window", "", 252, 32, 142, 22, COLORS.active, function() toggleSetting("testTargetWindow") end)
    label(p2, "power_ranger_intel_scale_label", "Scale", 406, 36, 40, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(p2, "power_ranger_intel_scale_down", "-", 448, 32, 24, 20, COLORS.button, function() shiftUiScale(-1, "targetWindowScaleLevel") end)
    settingsWnd.intelScaleValue = label(p2, "power_ranger_intel_scale_value", "0", 476, 35, 24, 14, 10, COLORS.white, ALIGN.CENTER)
    flatButton(p2, "power_ranger_intel_scale_up", "+", 504, 32, 24, 20, COLORS.button, function() shiftUiScale(1, "targetWindowScaleLevel") end)
    label(p2, "power_ranger_simple_spacing_label", "Simple spacing", 16, 64, 92, 14, 10, COLORS.muted, ALIGN.LEFT)
    label(p2, "power_ranger_simple_columns_label", "Columns", 116, 64, 54, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(p2, "power_ranger_simple_columns_down", "-", 174, 60, 24, 20, COLORS.button, function() TargetOverlay.shiftSimpleSpacing("simpleColumnGap", -1, 0, 73) end)
    settingsWnd.simpleColumnGapValue = label(p2, "power_ranger_simple_columns_value", "0", 202, 63, 24, 14, 10, COLORS.white, ALIGN.CENTER)
    flatButton(p2, "power_ranger_simple_columns_up", "+", 230, 60, 24, 20, COLORS.button, function() TargetOverlay.shiftSimpleSpacing("simpleColumnGap", 1, 0, 73) end)
    label(p2, "power_ranger_simple_lines_label", "Lines", 282, 64, 38, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(p2, "power_ranger_simple_lines_down", "-", 324, 60, 24, 20, COLORS.button, function() TargetOverlay.shiftSimpleSpacing("simpleLineGap", -1, 0, 23) end)
    settingsWnd.simpleLineGapValue = label(p2, "power_ranger_simple_lines_value", "0", 352, 63, 24, 14, 10, COLORS.white, ALIGN.CENTER)
    flatButton(p2, "power_ranger_simple_lines_up", "+", 380, 60, 24, 20, COLORS.button, function() TargetOverlay.shiftSimpleSpacing("simpleLineGap", 1, 0, 23) end)
    label(p2, "power_ranger_ownership_label", "Land / vehicle ownership", 16, 92, 148, 14, 10, COLORS.muted, ALIGN.LEFT)
    settingsWnd.ownershipBtn = flatButton(p2, "power_ranger_toggle_ownership", "", 168, 88, 142, 20, COLORS.active, function() toggleSetting("showOwnershipLabels") end)
    label(p2, "power_ranger_ownership_scale_label", "Scale", 326, 92, 40, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(p2, "power_ranger_ownership_scale_down", "-", 368, 88, 24, 20, COLORS.button, function() shiftUiScale(-1, "ownershipScaleLevel") end)
    settingsWnd.ownershipScaleValue = label(p2, "power_ranger_ownership_scale_value", "0", 396, 91, 24, 14, 10, COLORS.white, ALIGN.CENTER)
    flatButton(p2, "power_ranger_ownership_scale_up", "+", 424, 88, 24, 20, COLORS.button, function() shiftUiScale(1, "ownershipScaleLevel") end)
    settingsWnd.fieldButtons = {}
    settingsWnd.colorCubes = {}
    for i, field in ipairs(TARGET_INFO_FIELDS) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local x = 16 + (col * 138)
        local y = 118 + (row * 27)
        local bg = p2:CreateColorDrawable(row % 2 == 0 and 0.08 or 0.12, row % 2 == 0 and 0.08 or 0.12, row % 2 == 0 and 0.095 or 0.135, 0.72, "background")
        bg:SetExtent(128, 22)
        bg:AddAnchor("TOPLEFT", p2, x - 4, y - 1)
        bg:Show(true)
        settingsWnd.fieldButtons[field.key] = flatButton(p2, "power_ranger_info_field_" .. field.key, "", x, y, 98, 20, COLORS.active, function() toggleSetting(field.setting) end)
        settingsWnd.colorCubes[field.key] = colorCube(p2, "power_ranger_info_color_" .. field.key, x + 106, y, field.key)
    end

    local p4 = sectionPanel(settingsWnd, "power_ranger_self_panel", 18, 417, 584, 318, "Self Cooldowns & Gear")
    label(p4, "power_ranger_self_hint", "Known cooldown auras stay ID-based.", 14, 32, 264, 14, 10, COLORS.muted, ALIGN.LEFT)
    settingsWnd.nuziImportBtn = flatButton(p4, "power_ranger_toggle_nuzi_cd_import", "", 286, 29, 104, 20, COLORS.blue, function() toggleSetting("importNuziCooldowns") end)
    label(p4, "power_ranger_self_scale_label", "Scale", 410, 32, 40, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(p4, "power_ranger_self_scale_down", "-", 452, 29, 24, 20, COLORS.button, function() shiftUiScale(-1, "selfScaleLevel") end)
    settingsWnd.selfScaleValue = label(p4, "power_ranger_self_scale_value", "0", 480, 32, 24, 14, 10, COLORS.white, ALIGN.CENTER)
    flatButton(p4, "power_ranger_self_scale_up", "+", 508, 29, 24, 20, COLORS.button, function() shiftUiScale(1, "selfScaleLevel") end)
    settingsWnd.selfBtn = flatButton(p4, "power_ranger_toggle_self", "", 16, 58, 98, 24, COLORS.active, function() toggleSetting("showSelfPanel") end)
    settingsWnd.selfCdBtn = flatButton(p4, "power_ranger_toggle_self_cd", "", 120, 58, 104, 24, COLORS.active, function() toggleSetting("showSelfCooldowns") end)
    settingsWnd.selfEquipmentBtn = flatButton(p4, "power_ranger_toggle_self_equipment", "", 230, 58, 110, 24, COLORS.active, function() toggleSetting("showSelfEquipment") end)
    settingsWnd.probeLogBtn = flatButton(p4, "power_ranger_probe_log", "", 346, 58, 72, 24, COLORS.blue, toggleProbeLogging)
    flatButton(p4, "power_ranger_detected_open", "Detected", 424, 58, 110, 24, COLORS.blue, openDetectedSkillsWindow)
    label(p4, "power_ranger_cd_glider_title", "Gliders", 16, 90, 64, 14, 11, COLORS.gold, ALIGN.LEFT)
    settingsWnd.cooldownGliderPageLabel = label(p4, "power_ranger_cd_glider_page_label", "", 88, 91, 190, 13, 10, COLORS.muted, ALIGN.LEFT)
    settingsWnd.cooldownGliderPrevBtn = flatButton(p4, "power_ranger_cd_glider_page_prev", "<", 466, 87, 30, 22, COLORS.button, function() shiftCooldownSettingsPage(-1, "glider") end)
    settingsWnd.cooldownGliderNextBtn = flatButton(p4, "power_ranger_cd_glider_page_next", ">", 502, 87, 30, 22, COLORS.button, function() shiftCooldownSettingsPage(1, "glider") end)
    label(p4, "power_ranger_cd_other_title", "Mounts / Skills", 16, 198, 120, 14, 11, COLORS.gold, ALIGN.LEFT)
    settingsWnd.cooldownOtherPageLabel = label(p4, "power_ranger_cd_other_page_label", "", 146, 199, 190, 13, 10, COLORS.muted, ALIGN.LEFT)
    settingsWnd.cooldownOtherPrevBtn = flatButton(p4, "power_ranger_cd_other_page_prev", "<", 466, 195, 30, 22, COLORS.button, function() shiftCooldownSettingsPage(-1, "other") end)
    settingsWnd.cooldownOtherNextBtn = flatButton(p4, "power_ranger_cd_other_page_next", ">", 502, 195, 30, 22, COLORS.button, function() shiftCooldownSettingsPage(1, "other") end)
    settingsWnd.cooldownGliderRows = {}
    settingsWnd.cooldownOtherRows = {}
    local function createCooldownSettingRows(rows, prefix, group, startY)
        for i = 1, 3 do
            local y = startY + ((i - 1) * 28)
            local root = p4:CreateChildWidget("emptywidget", prefix .. "_row_" .. i, 0, true)
            root:SetExtent(552, 26)
            root:AddAnchor("TOPLEFT", p4, 16, y)
            local bg = root:CreateColorDrawable(i % 2 == 0 and 0.11 or 0.075, i % 2 == 0 and 0.11 or 0.075, i % 2 == 0 and 0.125 or 0.09, 0.74, "background")
            bg:AddAnchor("TOPLEFT", root, 0, 0)
            bg:AddAnchor("BOTTOMRIGHT", root, 0, 0)
            bg:Show(true)
            local rowIcon = createIcon(root, prefix .. "_icon_" .. i, 3, 2, 22)
            local nameLabel = label(root, prefix .. "_name_" .. i, "", 32, 6, 136, 14, 10, COLORS.white, ALIGN.LEFT)
            local sourceLabel = label(root, prefix .. "_source_" .. i, "", 172, 6, 122, 14, 10, COLORS.muted, ALIGN.LEFT)
            local cdField = cooldownEdit(root, prefix .. "_cd_" .. i, 302, 3, 40, 20)
            local rowIndex = i
            local upBtn = flatButton(root, prefix .. "_up_" .. i, "^", 350, 2, 28, 22, COLORS.button, function() moveCooldownSetting(rowIndex, -1, group) end)
            local downBtn = flatButton(root, prefix .. "_down_" .. i, "v", 382, 2, 28, 22, COLORS.button, function() moveCooldownSetting(rowIndex, 1, group) end)
            local btn = flatButton(root, prefix .. "_toggle_" .. i, "", 418, 2, 72, 22, COLORS.active, function() toggleCooldownSetting(rowIndex, group) end)
            local removeBtn = flatButton(root, prefix .. "_remove_" .. i, "Del", 498, 2, 42, 22, {0.24, 0.09, 0.09, 0.95}, function() removeCooldownSetting(rowIndex, group) end)
            nameLabel:Clickable(false)
            sourceLabel:Clickable(false)
            removeBtn:Show(false)
            rows[i] = { root = root, icon = rowIcon, name = nameLabel, source = sourceLabel, cd = cdField, up = upBtn, down = downBtn, button = btn, remove = removeBtn }
        end
    end
    createCooldownSettingRows(settingsWnd.cooldownGliderRows, "power_ranger_cd_glider", "glider", 112)
    createCooldownSettingRows(settingsWnd.cooldownOtherRows, "power_ranger_cd_other", "other", 220)

    refreshSettingsButtons()
    settingsWnd:Show(false)
end

function TargetOverlay.openSettings()
    if settingsWnd then
        cleanDeprecatedTrackedSkills()
        saveSettings()
        refreshSettingsButtons()
        settingsWnd:Show(true)
    end
end

function TargetOverlay.init()
    loadSettings()
    playerName = TargetOverlay.getPlayerName()

    mainCanvas = api.Interface:CreateEmptyWindow("TargetOverlayMain")
    mainCanvas:SetExtent(1, 1)
    mainCanvas:Show(true)

    armorBuffIcon = CreateItemIconButton("armorBuffIcon", mainCanvas)
    F_SLOT.ApplySlotSkin(armorBuffIcon, armorBuffIcon.back, SLOT_STYLE.DEFAULT)
    armorBuffIcon:Clickable(false)
    armorBuffIcon:SetExtent(CONFIG.buffIconSize, CONFIG.buffIconSize)
    armorBuffIcon:AddAnchor("LEFT", mainCanvas, "RIGHT", CONFIG.armorBuffOffset, 0)
    armorBuffIcon:Show(false)

    weaponBuffIcon = CreateItemIconButton("weaponBuffIcon", mainCanvas)
    F_SLOT.ApplySlotSkin(weaponBuffIcon, weaponBuffIcon.back, SLOT_STYLE.DEFAULT)
    weaponBuffIcon:Clickable(false)
    weaponBuffIcon:SetExtent(CONFIG.buffIconSize, CONFIG.buffIconSize)
    weaponBuffIcon:AddAnchor("RIGHT", mainCanvas, "LEFT", CONFIG.weaponBuffOffset, 0)
    weaponBuffIcon:Show(false)

    targetPdefTitleLabel = mainCanvas:CreateChildWidget("label", "targetPdefTitle", 0, true)
    targetPdefTitleLabel:SetExtent(54, 13)
    targetPdefTitleLabel.style:SetFontSize(10)
    targetPdefTitleLabel.style:SetShadow(settings.overlayTextShadow ~= false)
    targetPdefTitleLabel.style:SetOutline(false)
    targetPdefTitleLabel.style:SetAlign(ALIGN.CENTER)
    targetPdefTitleLabel.style:SetColor(1, 1, 1, 1)
    targetPdefTitleLabel:AddAnchor("RIGHT", weaponBuffIcon, "LEFT", 0, -5)
    targetPdefTitleLabel:SetText("PDef")
    targetPdefTitleLabel:Show(false)

    targetPdefValueLabel = mainCanvas:CreateChildWidget("label", "targetPdefValue", 0, true)
    targetPdefValueLabel:SetExtent(54, 13)
    targetPdefValueLabel.style:SetFontSize(10)
    targetPdefValueLabel.style:SetShadow(settings.overlayTextShadow ~= false)
    targetPdefValueLabel.style:SetOutline(false)
    targetPdefValueLabel.style:SetAlign(ALIGN.CENTER)
    targetPdefValueLabel.style:SetColor(1, 1, 1, 1)
    targetPdefValueLabel:AddAnchor("TOP", targetPdefTitleLabel, "BOTTOM", 0, -1)
    targetPdefValueLabel:Show(false)

    targetMdefTitleLabel = mainCanvas:CreateChildWidget("label", "targetMdefTitle", 0, true)
    targetMdefTitleLabel:SetExtent(54, 13)
    targetMdefTitleLabel.style:SetFontSize(10)
    targetMdefTitleLabel.style:SetShadow(settings.overlayTextShadow ~= false)
    targetMdefTitleLabel.style:SetOutline(false)
    targetMdefTitleLabel.style:SetAlign(ALIGN.CENTER)
    targetMdefTitleLabel.style:SetColor(1, 1, 1, 1)
    targetMdefTitleLabel:AddAnchor("LEFT", armorBuffIcon, "RIGHT", -3, -5)
    targetMdefTitleLabel:SetText("MDef")
    targetMdefTitleLabel:Show(false)

    targetMdefValueLabel = mainCanvas:CreateChildWidget("label", "targetMdefValue", 0, true)
    targetMdefValueLabel:SetExtent(54, 13)
    targetMdefValueLabel.style:SetFontSize(10)
    targetMdefValueLabel.style:SetShadow(settings.overlayTextShadow ~= false)
    targetMdefValueLabel.style:SetOutline(false)
    targetMdefValueLabel.style:SetAlign(ALIGN.CENTER)
    targetMdefValueLabel.style:SetColor(1, 1, 1, 1)
    targetMdefValueLabel:AddAnchor("TOP", targetMdefTitleLabel, "BOTTOM", 0, -1)
    targetMdefValueLabel:Show(false)

    targetRoleIcon = mainCanvas:CreateImageDrawable("Textures/Defaults/White.dds", "overlay")
    targetRoleIcon:SetExtent(CONFIG.roleIconSize, CONFIG.roleIconSize)
    targetRoleIcon:SetVisible(false)
    targetRoleIcon:SetSRGB(false)

    targetGearscoreLabel = mainCanvas:CreateChildWidget("label", "targetGearscore", 0, true)
    targetGearscoreLabel:SetAutoResize(true)
    targetGearscoreLabel:SetHeight(CONFIG.fontSize + 4)
    targetGearscoreLabel.style:SetFontSize(CONFIG.fontSize)
    targetGearscoreLabel.style:SetShadow(settings.overlayTextShadow ~= false)
    targetGearscoreLabel.style:SetOutline(false)
    targetGearscoreLabel.style:SetAlign(ALIGN.CENTER)
    targetGearscoreLabel:AddAnchor("TOP", mainCanvas, "BOTTOM", 0, CONFIG.gearscoreOffset)
    targetGearscoreLabel:Show(false)

    targetClassLabel = mainCanvas:CreateChildWidget("label", "targetClass", 0, true)
    targetClassLabel:SetExtent(160, 16)
    targetClassLabel.style:SetFontSize(CONFIG.fontSize)
    targetClassLabel.style:SetShadow(settings.overlayTextShadow ~= false)
    targetClassLabel.style:SetOutline(false)
    targetClassLabel.style:SetAlign(ALIGN.CENTER)
    targetClassLabel.style:SetColor(1, 1, 1, 1)
    targetClassLabel:AddAnchor("TOP", targetGearscoreLabel, "BOTTOM", -10, -1)
    targetClassLabel:Show(false)

    targetRangeCanvas = api.Interface:CreateEmptyWindow("PowerRangerModelRange", "UIParent")
    targetRangeCanvas:SetExtent(86, CONFIG.fontSize + 6)
    if targetRangeCanvas.Clickable then targetRangeCanvas:Clickable(false) end
    targetRangeLabel = label(targetRangeCanvas, "targetRange", "", 0, 0, 86, CONFIG.fontSize + 6, CONFIG.fontSize, COLORS.gold, ALIGN.CENTER)
    if targetRangeLabel.style.SetShadow then targetRangeLabel.style:SetShadow(settings.overlayTextShadow ~= false) end
    targetRangeLabel:Show(false)
    targetRangeCanvas:Show(false)

    createTargetInfoWindow()
    createOwnershipWindow()
    createSelfWindow()
    createSettingsWindow()
    createEventWindow()
    shiftUiScale(0)
end

local function updateCanvasPosition()
    local x, y, z = api.Unit:GetUnitScreenPosition("target")
    if not x or not y or not z or z < 0 or z > CONFIG.maxScreenDistance then
        screenPositionMisses = screenPositionMisses + 1
        if screenPositionMisses >= 3 then
            mainCanvas:Show(false)
            lastScreenPosition = ""
            return false
        end
        if modelDataTargetId then mainCanvas:Show(true) end
        return false
    end
    screenPositionMisses = 0
    local px = tonumber(x) or 0
    local py = tonumber(y) or 0
    local pz = math.floor(((tonumber(z) or 0) * 10) + 0.5) / 10
    local scale = uiScaleFactor()
    local anchorOffset = settings.compactModelOverlay and CONFIG.compactHealthbarOffset or CONFIG.healthbarOffset
    if not settings.compactModelOverlay then
        anchorOffset = math.floor((anchorOffset * scale) + 0.5)
    end
    local posString = string.format("%.2f,%.2f,%.1f,%d", px, py, pz, anchorOffset)
    if lastScreenPosition ~= posString then
        mainCanvas:AddAnchor("BOTTOM", "UIParent", "TOPLEFT", px, py + anchorOffset)
        lastScreenPosition = posString
    end
    mainCanvas:Show(true)
    return true
end

local function updateBuffIcon(icon, buff, enabled)
    if not icon then return end
    local path = enabled and buff and buff.path or nil
    if path then
        if icon._lastPath ~= path then
            F_SLOT.SetIconBackGround(icon, path)
            icon._lastPath = path
        end
        if icon._lastVisible ~= true then
            icon:Show(true)
            icon._lastVisible = true
        end
    else
        if icon._lastVisible ~= false then
            icon:Show(false)
            icon._lastVisible = false
        end
        icon._lastPath = nil
    end
end

local function updateRoleIcon(iconPath)
    if not targetRoleIcon then return end
    if not settings.showRoleIcon or not iconPath then
        targetRoleIcon:SetVisible(false)
        curTargetIcon = nil
        return
    end
    if curTargetIcon ~= iconPath then
        curTargetIcon = iconPath
        local visible = targetRoleIcon:SetTgaTexture(iconPath)
        targetRoleIcon:SetVisible(visible)
    end
    targetRoleIcon:RemoveAllAnchors()
    targetRoleIcon:AddAnchor("RIGHT", targetGearscoreLabel, "LEFT", math.floor((CONFIG.roleIconSpacing * uiScaleFactor()) + 0.5), 0)
    targetRoleIcon:SetVisible(true)
end

local function clearModelWidgets()
    updateBuffIcon(armorBuffIcon, nil, false)
    updateBuffIcon(weaponBuffIcon, nil, false)
    hideModelLabel(targetGearscoreLabel)
    hideModelLabel(targetClassLabel)
    hideModelLabel(targetPdefTitleLabel)
    hideModelLabel(targetPdefValueLabel)
    hideModelLabel(targetMdefTitleLabel)
    hideModelLabel(targetMdefValueLabel)
    if targetRoleIcon then targetRoleIcon:SetVisible(false) end
    curTargetIcon = nil
end

local function hideModelOverlay()
    if mainCanvas then mainCanvas:Show(false) end
    clearModelWidgets()
    hideModelRange()
    if targetInfoWnd then targetInfoWnd:Show(false) end
    lastScreenPosition = ""
    modelDataTargetId = nil
    targetInfoMisses = 0
    screenPositionMisses = 0
end

local function applyModelLayout()
    local scale = uiScaleFactor()
    if not mainCanvas or (mainCanvas._compactLayout == settings.compactModelOverlay and mainCanvas._layoutScale == scale) then return end
    mainCanvas._compactLayout = settings.compactModelOverlay
    mainCanvas._layoutScale = scale
    local buffSize = math.floor((CONFIG.buffIconSize * scale) + 0.5)
    armorBuffIcon:SetExtent(buffSize, buffSize)
    weaponBuffIcon:SetExtent(buffSize, buffSize)
    targetRoleIcon:SetExtent(math.floor((CONFIG.roleIconSize * scale) + 0.5), math.floor((CONFIG.roleIconSize * scale) + 0.5))
    targetClassLabel:SetExtent(math.floor((160 * scale) + 0.5), math.floor((16 * scale) + 0.5))
    targetClassLabel.style:SetFontSize(math.floor((CONFIG.fontSize * scale) + 0.5))
    targetPdefTitleLabel:SetExtent(math.floor((54 * scale) + 0.5), math.floor((13 * scale) + 0.5))
    targetPdefValueLabel:SetExtent(math.floor((54 * scale) + 0.5), math.floor((13 * scale) + 0.5))
    targetMdefTitleLabel:SetExtent(math.floor((54 * scale) + 0.5), math.floor((13 * scale) + 0.5))
    targetMdefValueLabel:SetExtent(math.floor((54 * scale) + 0.5), math.floor((13 * scale) + 0.5))
    targetPdefTitleLabel.style:SetFontSize(math.floor((10 * scale) + 0.5))
    targetPdefValueLabel.style:SetFontSize(math.floor((10 * scale) + 0.5))
    targetMdefTitleLabel.style:SetFontSize(math.floor((10 * scale) + 0.5))
    targetMdefValueLabel.style:SetFontSize(math.floor((10 * scale) + 0.5))
    armorBuffIcon:RemoveAllAnchors()
    weaponBuffIcon:RemoveAllAnchors()
    targetGearscoreLabel:RemoveAllAnchors()
    targetClassLabel:RemoveAllAnchors()
    targetPdefTitleLabel:RemoveAllAnchors()
    targetPdefValueLabel:RemoveAllAnchors()
    targetMdefTitleLabel:RemoveAllAnchors()
    targetMdefValueLabel:RemoveAllAnchors()
    if settings.compactModelOverlay then
        local leftOffset = -(tonumber(settings.compactModelLeftOffset) or CONFIG.compactModelLeftOffset)
        local compactIconGap = math.floor((2 * scale) + 0.5)
        armorBuffIcon:AddAnchor("RIGHT", mainCanvas, "LEFT", leftOffset, 0)
        weaponBuffIcon:AddAnchor("RIGHT", armorBuffIcon, "LEFT", -compactIconGap, 0)
        targetGearscoreLabel:SetHeight(math.floor(((CONFIG.fontSize + 7) * scale) + 0.5))
        targetGearscoreLabel.style:SetFontSize(math.floor(((CONFIG.fontSize + 3) * scale) + 0.5))
        targetGearscoreLabel:AddAnchor("BOTTOM", armorBuffIcon, "TOP", 0, math.floor((-4 * scale) + 0.5))
        targetClassLabel:AddAnchor("TOP", armorBuffIcon, "BOTTOM", 0, math.floor((4 * scale) + 0.5))
    else
        armorBuffIcon:AddAnchor("LEFT", mainCanvas, "RIGHT", math.floor((CONFIG.armorBuffOffset * scale) + 0.5), 0)
        weaponBuffIcon:AddAnchor("RIGHT", mainCanvas, "LEFT", math.floor((CONFIG.weaponBuffOffset * scale) + 0.5), 0)
        targetGearscoreLabel:SetHeight(math.floor(((CONFIG.fontSize + 4) * scale) + 0.5))
        targetGearscoreLabel.style:SetFontSize(math.floor((CONFIG.fontSize * scale) + 0.5))
        targetGearscoreLabel:AddAnchor("TOP", mainCanvas, "BOTTOM", 0, math.floor((CONFIG.gearscoreOffset * scale) + 0.5))
        targetClassLabel:AddAnchor("TOP", targetGearscoreLabel, "BOTTOM", math.floor((-10 * scale) + 0.5), math.floor((-1 * scale) + 0.5))
    end
    targetPdefTitleLabel:AddAnchor("RIGHT", weaponBuffIcon, "LEFT", 0, math.floor((-5 * scale) + 0.5))
    targetPdefValueLabel:AddAnchor("TOP", targetPdefTitleLabel, "BOTTOM", 0, math.floor((-1 * scale) + 0.5))
    targetMdefTitleLabel:AddAnchor("LEFT", armorBuffIcon, "RIGHT", math.floor((-3 * scale) + 0.5), math.floor((-5 * scale) + 0.5))
    targetMdefValueLabel:AddAnchor("TOP", targetMdefTitleLabel, "BOTTOM", 0, math.floor((-1 * scale) + 0.5))
end

local function updateFastModelRange()
    if not targetRangeCanvas or not targetRangeLabel then return end
    if settings.showModelOverlay == false or settings.showModelRange == false or Compat.ShouldHideTargetText(compatState) then
        hideModelRange()
        return
    end
    local sX, sY, sZ = api.Unit:GetUnitScreenPosition("target")
    if not sX or not sY or not sZ or sZ < 0 or sZ > CONFIG.maxScreenDistance then
        hideModelRange()
        return
    end
    local dist = tonumber(OverlayUtils.safeCall(function() return api.Unit:UnitDistance("target") end))
    if not dist or dist < 0 then dist = 0 end
    local scale = uiScaleFactor()
    targetRangeCanvas:SetExtent(math.floor((86 * scale) + 0.5), math.floor(((CONFIG.fontSize + 6) * scale) + 0.5))
    targetRangeLabel:SetExtent(math.floor((86 * scale) + 0.5), math.floor(((CONFIG.fontSize + 6) * scale) + 0.5))
    targetRangeLabel.style:SetFontSize(math.floor((CONFIG.fontSize * scale) + 0.5))
    setModelLabel(targetRangeLabel, string.format("%.1fm", dist))
    targetRangeCanvas:AddAnchor("BOTTOM", "UIParent", "TOPLEFT", sX, sY - math.floor((44 * scale) + 0.5))
    targetRangeCanvas:Show(true)
end

function TargetOverlay.update(dt)
    local elapsed = dt or 0
    updateElapsed = updateElapsed + elapsed
    selfUpdateElapsed = selfUpdateElapsed + elapsed
    compatRefreshElapsed = compatRefreshElapsed + elapsed
    NuziCooldownImport.AddElapsed(elapsed)
    updateProbeLogging(elapsed)
    updateCompatState(false)
    refreshNuziCooldownRows(false)
    local now = api.Time:GetUiMsec()
    if skillProbeDirty and now - lastSkillProbeSave >= 2000 then
        lastSkillProbeSave = now
        saveSkillProbe()
    end
    local doSelfUpdate = selfUpdateElapsed >= SELF_UPDATE_MS
    if doSelfUpdate then
        selfUpdateElapsed = 0
        updateTrackedBuffs()
        updateSelfPanel()
    end
    local doSlowUpdate = updateElapsed >= TARGET_UPDATE_MS
    if doSlowUpdate then updateElapsed = 0 end

    local playerId = api.Unit:GetUnitId("player")
    local targetId = api.Unit:GetUnitId("target")
    local directOwnershipInfo = targetId and TargetOverlay.getTargetInfoById(targetId) or nil
    if targetId and playerId ~= targetId and directOwnershipInfo
        and TargetOverlay.hasOwnershipFields(directOwnershipInfo)
        and not TargetOverlay.isPlayerTarget(directOwnershipInfo) then
        targetTokenMisses = 0
        targetInfoMisses = 0
        if targetId ~= previousTargetId then
            previousTargetId = targetId
            updateElapsed = 0
        end
        hideModelOverlay()
        refreshOwnershipWindow(directOwnershipInfo)
        return
    end
    if not targetId or playerId == targetId then
        local tokenInfo = OverlayUtils.safeCall(function() return api.Unit:UnitInfo("target") end)
        if TargetOverlay.isOwnershipTarget(tokenInfo) then
            targetTokenMisses = 0
            targetInfoMisses = 0
            previousTargetId = nil
            hideModelOverlay()
            if doSlowUpdate then
                refreshOwnershipWindow(tokenInfo)
            end
            return
        end
        targetTokenMisses = targetTokenMisses + 1
        if targetTokenMisses >= 3 then
            hideModelOverlay()
            hideOwnershipWindow()
            previousTargetId = nil
        end
        return
    end
    targetTokenMisses = 0
    if targetId ~= previousTargetId then
        hideModelOverlay()
        hideOwnershipWindow()
        previousTargetId = targetId
        doSlowUpdate = true
        updateElapsed = 0
    end
    if settings.showModelOverlay ~= false and modelDataTargetId == targetId then
        updateCanvasPosition()
        updateFastModelRange()
    else
        mainCanvas:Show(false)
        hideModelRange()
    end

    if not doSlowUpdate then return end

    local targetInfo = directOwnershipInfo or TargetOverlay.getTargetInfoById(targetId)
    local tokenInfo = OverlayUtils.safeCall(function() return api.Unit:UnitInfo("target") end)
    local gearscore = OverlayUtils.safeCall(function() return api.Unit:UnitGearScore("target") end)
    gearscore = gearscore or OverlayUtils.numField(tokenInfo, {"gear_score", "gearScore"}) or OverlayUtils.numField(targetInfo, {"gear_score", "gearScore"})
    local isPlayer = TargetOverlay.isPlayerTarget(targetInfo) or TargetOverlay.isPlayerTarget(tokenInfo)
    local ownershipInfo = nil
    if not isPlayer then
        if TargetOverlay.isOwnershipTarget(targetInfo) then
            ownershipInfo = targetInfo
        elseif TargetOverlay.isOwnershipTarget(tokenInfo) then
            ownershipInfo = tokenInfo
        end
    end
    local usableInfo = ownershipInfo or (TargetOverlay.isCharacterTarget(targetInfo, gearscore) and targetInfo or tokenInfo or targetInfo)
    if not usableInfo then
        targetInfoMisses = targetInfoMisses + 1
        if modelDataTargetId ~= targetId and targetInfoMisses >= 3 then
            hideModelOverlay()
        end
        return
    end
    targetInfoMisses = 0

    if ownershipInfo then
        hideModelOverlay()
        refreshOwnershipWindow(ownershipInfo)
        return
    end

    local className = TargetOverlay.getClassName(usableInfo) or "Unknown"
    local pdef, mdef, pdefPct, mdefPct = TargetOverlay.fillDefense(nil, nil, nil, nil, tokenInfo)
    pdef, mdef, pdefPct, mdefPct = TargetOverlay.fillDefense(pdef, mdef, pdefPct, mdefPct, targetInfo or usableInfo)
    local needsExtraStats = settings.showInfoBlock or settings.showInfoParry or settings.showInfoEvasion or settings.showInfoToughness or settings.showInfoResilience
    local modifierInfo = nil
    if needsExtraStats or not pdef or not mdef or not pdefPct or not mdefPct then
        modifierInfo = OverlayUtils.safeCall(function() return api.Unit:UnitModifierInfo("target") end)
        if modifierInfo then
            pdef, mdef, pdefPct, mdefPct = TargetOverlay.fillDefense(pdef, mdef, pdefPct, mdefPct, modifierInfo)
        end
    end
    local extraStats = needsExtraStats and TargetOverlay.targetExtraStats(tokenInfo, targetInfo or usableInfo, modifierInfo) or {}
    if isPlayer then
        refreshTargetInfoWindow(usableInfo, className, gearscore, pdef, mdef, pdefPct, mdefPct, extraStats)
    elseif targetInfoWnd then
        targetInfoWnd:Show(false)
    end

    if not isPlayer then
        hideModelOverlay()
        return
    end

    if settings.showModelOverlay == false then
        mainCanvas:Show(false)
        return
    end
    modelDataTargetId = targetId
    if not updateCanvasPosition() then
        return
    end

    local trackedBuffs = BuffDetector.getTrackedBuffObjects("target")
    local armorBuff = TargetOverlay.findBuffByCategory(trackedBuffs, BUFF_CATEGORIES.armor)
    local weaponBuff = TargetOverlay.findBuffByCategory(trackedBuffs, BUFF_CATEGORIES.weapon)
    local showTargetText = not Compat.ShouldHideTargetText(compatState)
    applyModelLayout()
    updateBuffIcon(armorBuffIcon, armorBuff, settings.showArmorIcon)
    updateBuffIcon(weaponBuffIcon, weaponBuff, settings.showWeaponIcon)

    if showTargetText and settings.showModelGearscore and gearscore then
        setModelLabel(targetGearscoreLabel, tostring(gearscore))
        targetGearscoreLabel.style:SetColor(1, 1, 1, 1)
    else
        hideModelLabel(targetGearscoreLabel)
    end

    if showTargetText and settings.showModelClass then
        setModelLabel(targetClassLabel, className)
    else
        hideModelLabel(targetClassLabel)
    end

    updateFastModelRange()

    if showTargetText and settings.showModelDefense and not settings.compactModelOverlay then
        setModelLabel(targetPdefTitleLabel, "PDef")
        setModelLabel(targetPdefValueLabel, OverlayUtils.defenseText(pdef, pdefPct))
        setModelLabel(targetMdefTitleLabel, "MDef")
        setModelLabel(targetMdefValueLabel, OverlayUtils.defenseText(mdef, mdefPct))
    else
        hideModelLabel(targetPdefTitleLabel)
        hideModelLabel(targetPdefValueLabel)
        hideModelLabel(targetMdefTitleLabel)
        hideModelLabel(targetMdefValueLabel)
    end

    if settings.compactModelOverlay then
        updateRoleIcon(nil)
    else
        local role = RoleHelper.getRoleFromClass(className)
        updateRoleIcon(RoleHelper.getRoleIconPath(role))
    end
end

function TargetOverlay.cleanup()
    if eventWnd then
        pcall(function() eventWnd:UnregisterEvent("COMBAT_MSG") end)
        pcall(function() eventWnd:UnregisterEvent("SPELLCAST_START") end)
        pcall(function() eventWnd:UnregisterEvent("SPELLCAST_SUCCEEDED") end)
        pcall(function() eventWnd:UnregisterEvent("SPELLCAST_STOP") end)
        eventWnd:SetHandler("OnEvent", function() end)
        eventWnd:Show(false)
    end
    saveSkillProbe()
    if settings then
        settings.skillProbeLogging = false
        settings.detectedSkills = {}
        saveSettings()
    end
    if mainCanvas then mainCanvas:Show(false) end
    if targetRangeCanvas then targetRangeCanvas:Show(false) end
    if targetInfoWnd then targetInfoWnd:Show(false) end
    if ownershipWnd then ownershipWnd:Show(false) end
    if selfWnd then selfWnd:Show(false) end
    if settingsWnd then settingsWnd:Show(false) end
    if detectedSkillsWnd then detectedSkillsWnd:Show(false) end
    mainCanvas = nil
    targetInfoWnd = nil
    ownershipWnd = nil
    selfWnd = nil
    settingsWnd = nil
    detectedSkillsWnd = nil
    eventWnd = nil
    armorBuffIcon = nil
    weaponBuffIcon = nil
    targetRoleIcon = nil
    targetGearscoreLabel = nil
    targetClassLabel = nil
    targetPdefTitleLabel = nil
    targetPdefValueLabel = nil
    targetMdefTitleLabel = nil
    targetMdefValueLabel = nil
    targetRangeCanvas = nil
    targetRangeLabel = nil
    curTargetIcon = nil
    lastScreenPosition = ""
    previousTargetId = nil
    modelDataTargetId = nil
    targetTokenMisses = 0
    targetInfoMisses = 0
    screenPositionMisses = 0
    updateElapsed = TARGET_UPDATE_MS
    selfUpdateElapsed = SELF_UPDATE_MS
    nuziCooldownRows = NuziCooldownImport.EmptyRows()
    NuziCooldownImport.Reset()
    buffState = {}
    triggerState = {}
    buffIconCache = {}
    buffTooltipCache = {}
    skillIconCache = {}
    skillCooldowns = {}
    skillProbe = { entries = {}, maxEntries = 240 }
    skillProbeDirty = false
    lastSkillProbeSave = 0
    probeLogElapsed = 0
    lastSelfEquipmentUpdate = 0
    playerName = nil
end

return TargetOverlay
