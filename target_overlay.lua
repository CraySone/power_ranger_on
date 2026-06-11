local api = require("api")
local RoleHelper = require("power_ranger_on/role_helper")
local BuffDetector = require("power_ranger_on/buff_detector")
local OverlayUtils = require("power_ranger_on/overlay_utils")
local Compat = require("power_ranger_on/compat")
local NuziCooldownImport = require("power_ranger_on/nuzi_cooldown_import")
local CooldownRecipes = require("power_ranger_on/cooldown_recipes")
local CooldownLearning = require("power_ranger_on/cooldown_learning")
local HotSwap = require("power_ranger_on/hot_swap")
local ClassIntelProfiles = require("power_ranger_on/class_intel_profiles")
local SkillProbe = require("power_ranger_on/skill_probe")
local SettingsSanitizer = require("power_ranger_on/settings_sanitizer")
local SettingsProfile = require("power_ranger_on/settings_profile")
local SettingsStore = require("power_ranger_on/settings_store")

local TargetOverlay = {}
TargetOverlay.uiHelpers = require("power_ranger_on/ui_helpers")
TargetOverlay.targetUi = require("power_ranger_on/target_ui")
TargetOverlay.targetReader = require("power_ranger_on/target_reader")
TargetOverlay.detectedSkills = require("power_ranger_on/detected_skills")
TargetOverlay.selfCooldowns = require("power_ranger_on/self_cooldowns")
TargetOverlay.buffRuntime = require("power_ranger_on/buff_runtime")
TargetOverlay.equipmentReader = require("power_ranger_on/equipment_reader")
TargetOverlay.iconWidgets = require("power_ranger_on/icon_widgets")
TargetOverlay.resourceLookup = require("power_ranger_on/resource_lookup")
TargetOverlay.windowHelpers = require("power_ranger_on/window_helpers")
TargetOverlay.travelSpeed = require("power_ranger_on/travel_speed")
TargetOverlay.ownersMark = require("power_ranger_on/owners_mark")
TargetOverlay.weaponProc = require("power_ranger_on/weapon_proc")
TargetOverlay.statsCatalog = require("power_ranger_on/target_stats_catalog")
TargetOverlay.optionalBuffHelper = OverlayUtils.safeCall(function() return require("CooldawnBuffTracker/buff_helper") end)
TargetOverlay.simpleStatsGrid = {
    pdef = 0,
    mdef = 0,
    resilience = 0,
    toughness = 0,
    block = 1,
    parry = 1,
    evasion = 1,
    critRate = 1
}
TargetOverlay.compactStatsOrder = {
    pdef = 1,
    mdef = 2,
    resilience = 3,
    toughness = 4,
    block = 1,
    parry = 2,
    evasion = 3,
    critRate = 4
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
    modelRangeOffsetX = 0,
    modelRangeOffsetY = 0,
    overlayTextShadow = true,
    overlayTextStyle = "shadow",
    uiScaleLevel = 0,
    modelRangeScaleLevel = 0,
    targetWindowScaleLevel = 0,
    selfScaleLevel = 0,
    selfOpacityLevel = 8,
    speedMeterOpacityLevel = 8,
    guildFamilyLabelScaleLevel = 0,
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
    showGuildFamilyLabel = false,
    showSpeedMeter = false,
    showOwnOwnersMark = false,
    showTargetOwnersMark = true,
    warnMissingOwnersMark = true,
    weaponProcEnabled = false,
    weaponProcReadyPopup = true,
    weaponProcDamageChat = true,
    weaponProcX = 500,
    weaponProcY = 230,
    debugLogging = false,
    showInfoDefense = true,
    showInfoPdef = true,
    showInfoMdef = true,
    showInfoBlock = true,
    showInfoParry = true,
    showInfoEvasion = true,
    showInfoToughness = false,
    showInfoResilience = false,
    showInfoCritRate = false,
    classIntelEditProfile = "general",
    classIntelProfiles = require("power_ranger_on/class_intel_profiles").DefaultProfiles(),
    showSelfPanel = true,
    showSelfCooldowns = true,
    showSelfEquipment = true,
    showSelfBorder = true,
    selfMinimized = false,
    cooldownSettingsPage = 1,
    skillProbeLogging = false,
    detectedSkillsX = 760,
    detectedSkillsY = 260,
    ownershipWindowX = 860,
    ownershipWindowY = 280,
    ownershipScaleLevel = 0,
    speedMeterX = 300,
    speedMeterY = 180,
    ownersMarkX = 500,
    ownersMarkY = 180,
    targetInfoColors = {
        range = {1, 0.84, 0, 1},
        class = {0.82, 0.90, 1, 1},
        gearscore = {0.38, 0.95, 0.44, 1},
        modelRange = {1, 0.84, 0, 1},
        modelClass = {0.82, 0.90, 1, 1},
        modelGearscore = {1, 1, 1, 1},
        guild = {0.62, 0.82, 1, 1},
        family = {1, 0.78, 0.52, 1},
        guildFamilyGuild = {1, 1, 1, 1},
        guildFamilyFamily = {0.76, 0.82, 0.95, 1},
        pdef = {1, 1, 1, 1},
        mdef = {0.72, 0.86, 1, 1},
        block = {0.78, 0.92, 1, 1},
        parry = {1, 0.92, 0.62, 1},
        evasion = {0.70, 1, 0.70, 1},
        toughness = {1, 0.72, 0.72, 1},
        resilience = {0.90, 0.72, 1, 1},
        critRate = {1, 0.72, 0.52, 1}
    },
    targetWindowX = 860,
    targetWindowY = 330,
    selfX = 860,
    selfY = 470,
    cooldownSkillsX = 720,
    cooldownSkillsY = 270,
    settingsX = 650,
    settingsY = 210,
    trackedBuffs = require("power_ranger_on/cooldown_catalog").BuildTrackedBuffRows(),
    trackedSkills = {},
    detectedSkills = {},
    learnedCooldownDevices = {}
}

local DEPRECATED_TRACKED_BUFFS = {
    ["playerpet:545"] = true,
    ["self:8000566"] = true,
    ["self:22290"] = true,
    ["self:30779"] = true,
    ["self:30780"] = true,
    ["self:20121"] = true,
    ["self:8000208"] = true,
    ["self:name:nui's veil:nui's veil"] = true,
    ["self:name:star divine protection:flamefeather"] = true,
    ["self:name:star divine protection:sloth glider"] = true,
    ["self:name:star divine protection:crystal wings"] = true,
    ["self:3636:glider:ezi glider"] = true,
    ["self:3636:glider:flamefeather"] = true,
    ["self:8000290:glider:flamefeather_glider"] = true,
    ["self:8000286:glider:phoenix"] = true
}

local DEPRECATED_TRACKED_SKILL_PATTERNS = {
    flight = true,
    ["invincible flight"] = true
}

function TargetOverlay.isDeprecatedTrackedBuffRow(row)
    if not row then return false end
    local deviceName = string.lower(tostring(row.recipeDeviceName or row.mountName or row.source or ""))
    local source = string.lower(tostring(row.source or row.recipeDeviceName or row.name or row.buffName or ""))
    local buffName = string.lower(tostring(row.buffName or ""))
    if row.recipeDeviceKey == "phoenix_glider" then return true end
    if row.recipeDeviceKey == "general_mount" then return true end
    if row.recipeDeviceKey == "nuis_veil_mount" then return true end
    if row.recipeDeviceKey == "cloud_glider" then return true end
    if row.recipeDeviceKey == "cloud_mount" then return true end
    if row.recipeDeviceKey == "frozen_glider" then return true end
    if (row.recipeDeviceKey == "crystal_wings" or deviceName:find("crystal wings", 1, true) or source:find("crystal wings", 1, true))
        and buffName:find("star", 1, true) then return true end
    if (row.recipeDeviceKey == "flamefeather_glider" or deviceName:find("flamefeather", 1, true) or source:find("flamefeather", 1, true)) then
        local id = tonumber(row.id or row.buff_id)
        if id == 8000290 then return true end
        if buffName:find("flamefeather", 1, true) and not buffName:find("invincible", 1, true) then return true end
    end
    if row.recipeAbilityKey == "rajani_sprint" then return true end
    if row.recipeAbilityKey == "meatball_bite" or row.recipeAbilityKey == "rajani_bite" or row.recipeAbilityKey == "kirin_bite" then return true end
    if (row.recipeDeviceKey == "ser_meatball" or deviceName:find("ser meatball", 1, true) or source:find("ser meatball", 1, true))
        and string.lower(tostring(row.name or row.buffName or "")):find("bite", 1, true) then return true end
    if (row.recipeDeviceKey == "rajani" or row.recipeDeviceKey == "kirin" or deviceName:find("raijin", 1, true)
        or deviceName:find("rajani", 1, true) or deviceName:find("kirin", 1, true))
        and string.lower(tostring(row.name or row.buffName or "")):find("bite", 1, true) then return true end
    if not row.recipeDeviceKey and tonumber(row.id or row.buff_id) == 3523 and string.lower(tostring(row.source or "")):find("ser meatball", 1, true) then return true end
    if row.recipeDeviceKey == "custom_mount_mount/pet" or deviceName == "mount/pet" or deviceName == "mount" then return true end
    if row.recipeDeviceKey ~= "sloth_glider" and deviceName:find("sloth", 1, true) and (tonumber(row.id or row.buff_id) == 8000138 or string.lower(tostring(row.buffName or "")):find("star", 1, true)) then return true end
    return source:find("phoenix", 1, true) ~= nil and tonumber(row.id or row.buff_id) == 8000286
end

local function trackedBuffSettingKey(row)
    if row and row.importKey then return tostring(row.importKey) end
    local unit = tostring(row and row.unit or "player")
    local devicePart = ""
    if row and (row.recipeDeviceKind == "mount" or row.category == "mount" or row.mountNames or row.mountName or row.mount_name) then
        devicePart = ":mount:" .. string.lower(tostring(row.recipeDeviceKey or row.recipeDeviceName or row.source or row.mountName or row.mount_name or ""))
    elseif row and (row.gliderPattern or row.category == "glider" or row.recipeDeviceKind == "glider") then
        devicePart = ":glider:" .. string.lower(tostring(row.recipeDeviceKey or row.recipeDeviceName or row.name or row.source or ""))
    end
    if row and row.id then
        -- formatBuffId, not tostring: this client's tostring is %.6g and collapses
        -- distinct 7-digit ids onto one key (see SkillProbe.detectedSkillKey).
        return unit .. ":" .. OverlayUtils.formatBuffId(row.id) .. devicePart
    end
    if row and row.buffName then
        return unit .. ":name:" .. string.lower(tostring(row.buffName)) .. ":" .. string.lower(tostring(row.name or "")) .. devicePart
    end
    return unit .. ":name:" .. string.lower(tostring(row and row.name or "")) .. devicePart
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
    {0.90, 0.72, 1, 1},
    {0.89, 0, 0.55, 1}
}

local TARGET_INFO_FIELDS = {
    { key = "guild", setting = "showInfoGuild", label = "Guild" },
    { key = "family", setting = "showInfoFamily", label = "Family" },
    { key = "class", setting = "showInfoClass", label = "Class" },
    { key = "gearscore", setting = "showInfoGearscore", label = "Gearscore" },
    { key = "range", setting = "showInfoRange", label = "Range" }
}

local settings = nil
local settingsRoot = nil
local settingsProfileKey = nil
local settingsProfileState = nil
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
local guildFamilyWnd = nil
local stumpyDockHooksRegistered = false
local stumpyStatsDockVisible = false
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
local stumpySenseLayout = { enabled = false }
local buffState = {}
local triggerState = {}
local skillCooldowns = {}
local playerName = nil
local skillProbe = { entries = {}, maxEntries = 240 }
local skillProbeDirty = false
local lastSkillProbeSave = 0
local probeLogElapsed = 0
local detectManaState = { init = false, mountKey = nil, mountMana = 0, playerMana = 0, mountSpent = 0, playerSpent = 0 }
local lastSelfEquipmentUpdate = 0
local recordSkillProbe
local recordDetectedSkill
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

local function onStumpySenseLayout(opts)
    if type(opts) ~= "table" then
        stumpySenseLayout.enabled = false
        stumpySenseLayout.anchor = nil
        return
    end
    stumpySenseLayout.enabled = opts.enabled == true
    stumpySenseLayout.width = tonumber(opts.width)
    stumpySenseLayout.height = tonumber(opts.height)
    stumpySenseLayout.anchor = opts.anchor
    stumpySenseLayout.anchorX = tonumber(opts.anchorX)
    stumpySenseLayout.anchorY = tonumber(opts.anchorY)
    if targetInfoWnd then
        targetInfoWnd._lastWidth = nil
        targetInfoWnd._lastHeight = nil
    end
end

local function registerStumpyDockMember()
    if not targetInfoWnd then return end
    StumpyDock = StumpyDock or { members = {} }
    StumpyDock.members = StumpyDock.members or {}
    StumpyDock.members["power_ranger_stats"] = {
        id = "power_ranger_stats",
        window = targetInfoWnd,
        visible = function()
            local ok, visible = pcall(function() return targetInfoWnd and targetInfoWnd:IsVisible() end)
            return ok and visible == true
        end
    }
    pcall(function() api:Emit("STUMPY_DOCK_REGISTER", "power_ranger_stats") end)
end

function TargetOverlay.clearStumpyStatsBox()
    if StumpyDock and StumpyDock.boxes then
        local hadBox = StumpyDock.boxes["power_ranger_stats"] ~= nil
        StumpyDock.boxes["power_ranger_stats"] = nil
        if hadBox then
            pcall(function() api:Emit("STUMPY_DOCK_REGISTER", "power_ranger_stats") end)
        end
    end
end

function TargetOverlay.publishStumpyStatsBox(width, height)
    if not stumpySenseLayout or stumpySenseLayout.enabled ~= true then return end
    local anchorX = tonumber(stumpySenseLayout.anchorX)
    local anchorY = tonumber(stumpySenseLayout.anchorY)
    local w = tonumber(width) or tonumber(stumpySenseLayout.width)
    local h = tonumber(height) or tonumber(stumpySenseLayout.height)
    if not anchorX or not anchorY or not w or not h then return end
    StumpyDock = StumpyDock or { members = {} }
    StumpyDock.boxes = StumpyDock.boxes or {}
    local nextBox = {
        x = math.floor(anchorX - w - 8 + 0.5),
        y = math.floor(anchorY + 0.5),
        w = math.floor(w + 0.5),
        h = math.floor(h + 0.5)
    }
    local prev = StumpyDock.boxes["power_ranger_stats"]
    local changed = not prev or prev.x ~= nextBox.x or prev.y ~= nextBox.y or prev.w ~= nextBox.w or prev.h ~= nextBox.h
    StumpyDock.boxes["power_ranger_stats"] = nextBox
    return changed
end

local function unregisterStumpyDockMember()
    if StumpyDock and StumpyDock.members then
        StumpyDock.members["power_ranger_stats"] = nil
    end
    TargetOverlay.clearStumpyStatsBox()
    stumpyStatsDockVisible = false
end

local function notifyStumpyStatsVisible()
    if stumpyStatsDockVisible == true then return end
    stumpyStatsDockVisible = true
    registerStumpyDockMember()
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

local function copySerializable(value, seen)
    local kind = type(value)
    if kind ~= "table" then
        if kind == "string" or kind == "number" or kind == "boolean" then return value end
        return nil
    end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local out = {}
    for key, child in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            local copied = copySerializable(child, seen)
            if copied ~= nil then out[key] = copied end
        end
    end
    seen[value] = nil
    return out
end

local function copyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = copySerializable(v)
        end
    end
end

local function normalizeRemovedCooldownDefaults()
    local source = settings and settings.removedCooldownDefaults
    local out = {}
    local seen = {}
    local function addRemovedKey(value)
        value = tostring(value or "")
        if value ~= "" and not seen[value] then
            out[#out + 1] = value
            seen[value] = true
        end
    end
    if type(source) == "table" then
        for _, value in ipairs(source) do
            addRemovedKey(value)
        end
        for key, value in pairs(source) do
            if type(key) == "string" and value == true then
                addRemovedKey(key)
            elseif type(value) == "string" then
                addRemovedKey(value)
            end
        end
    end
    settings.removedCooldownDefaults = out
    return out, seen
end

local function cooldownDefaultRemoved(key)
    if not key or key == "" then return false end
    local _, seen = normalizeRemovedCooldownDefaults()
    return seen[tostring(key)] == true
end

local function markCooldownDefaultRemoved(row)
    local key = trackedBuffSettingKey(row)
    if not key or key == "" then return end
    local out, seen = normalizeRemovedCooldownDefaults()
    if not seen[key] then
        out[#out + 1] = key
        seen[key] = true
    end
end

local function addMissingTrackedBuffDefaults()
    settings.trackedBuffs = settings.trackedBuffs or {}
    normalizeRemovedCooldownDefaults()
    local migrateHardcodedGliders = (tonumber(settings.hardcodedGliderDefaultsVersion) or 0) < 1
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
            if existing.customName ~= nil then copy.customName = existing.customName end
            if existing.icon ~= nil
                and copy.icon == nil
                and defaultRow.recipeDeviceKind == nil
                and not tostring(existing.icon):find("icon_skill_", 1, true) then
                copy.icon = existing.icon
            end
            if defaultRow.icon ~= nil then copy.icon = defaultRow.icon end
            if existing.mount ~= nil and copy.source == nil then copy.source = existing.mount end
            copy.unit = defaultRow.unit
            copy.id = defaultRow.id
            copy.buffName = defaultRow.buffName
            copy.buffNames = defaultRow.buffNames
            copy.buffIds = defaultRow.buffIds
            copy.genericBuffIds = defaultRow.genericBuffIds
            copy.generic_buff_ids = defaultRow.generic_buff_ids
            copy.icon_type = defaultRow.icon_type
            copy.icon_id = defaultRow.icon_id
            copy.iconType = defaultRow.iconType
            copy.iconId = defaultRow.iconId
            copy.gliderPattern = defaultRow.gliderPattern
            copy.itemType = defaultRow.itemType
            copy.itemTypes = defaultRow.itemTypes
            copy.mountName = defaultRow.mountName
            copy.mountNames = defaultRow.mountNames
            copy.requiredBuffId = defaultRow.requiredBuffId
            copy.requiredBuffIds = defaultRow.requiredBuffIds
            copy.requiredBuffName = defaultRow.requiredBuffName
            copy.requiredBuffNames = defaultRow.requiredBuffNames
            copy.mountManaSpent = defaultRow.mountManaSpent
            copy.petManaSpent = defaultRow.petManaSpent
            copy.playerManaSpent = defaultRow.playerManaSpent
            copy.category = defaultRow.category
            copy.recipeDeviceKey = defaultRow.recipeDeviceKey
            copy.recipeDeviceName = defaultRow.recipeDeviceName
            copy.recipeDeviceKind = defaultRow.recipeDeviceKind
            copy.recipeDeviceItemType = defaultRow.recipeDeviceItemType or existing.recipeDeviceItemType
            copy.recipeDeviceIconLocked = defaultRow.recipeDeviceIconLocked == true
            copy.recipeDeviceIcon = defaultRow.recipeDeviceIcon
            if copy.recipeDeviceIcon == nil and copy.recipeDeviceItemType == nil then
                copy.recipeDeviceIcon = existing.recipeDeviceIcon
            end
            copy.recipeAbilityKey = defaultRow.recipeAbilityKey
            copy.recipeAbilityLabel = defaultRow.recipeAbilityLabel
            copy.fixedCooldown = defaultRow.fixedCooldown
            copy.cooldownStartsOnActive = defaultRow.cooldownStartsOnActive
            copy.cooldownOnlyOnActive = defaultRow.cooldownOnlyOnActive
            copy.triggerMinTimeLeftMs = defaultRow.triggerMinTimeLeftMs
            if existing.dynamicDisplay ~= nil then
                copy.dynamicDisplay = existing.dynamicDisplay == true
            else
                copy.dynamicDisplay = defaultRow.dynamicDisplay == true
            end
            if defaultRow.name == "Sloth Glider" then
                copy.source = defaultRow.source
                if existing.icon == "Game\\ui\\icon\\icon_item_1648.dds" then copy.icon = nil end
            end
            if migrateHardcodedGliders and (defaultRow.name == "Sloth Glider" or defaultRow.name == "Flamefeather") then
                copy.enabled = true
            end
        end
        return copy
    end
    local function normalizeKnownMountDeviceIcon(row, key, name, itemType, patterns)
        if not row then return end
        local text = string.lower(tostring(row.recipeDeviceKey or "") .. " "
            .. tostring(row.recipeDeviceName or "") .. " "
            .. tostring(row.source or "") .. " "
            .. tostring(row.mountName or "") .. " "
            .. tostring(row.name or ""))
        for _, mountName in ipairs(row.mountNames or {}) do
            text = text .. " " .. string.lower(tostring(mountName or ""))
        end
        local matched = text:find(string.lower(tostring(key or "")), 1, true) ~= nil
        for _, pattern in ipairs(patterns or {}) do
            if text:find(string.lower(tostring(pattern or "")), 1, true) then
                matched = true
                break
            end
        end
        if matched then
            row.category = "mount"
            row.recipeDeviceKey = key
            row.recipeDeviceName = name
            row.recipeDeviceKind = "mount"
            row.itemType = row.itemType or itemType
            row.recipeDeviceItemType = itemType
            row.recipeDeviceIcon = nil
            row.recipeDeviceIconLocked = false
        end
    end
    local function normalizeKnownGliderDeviceIcon(row, key, name, itemTypes, displayItemType, patterns)
        if not row then return end
        local text = string.lower(tostring(row.recipeDeviceKey or "") .. " "
            .. tostring(row.recipeDeviceName or "") .. " "
            .. tostring(row.source or "") .. " "
            .. tostring(row.name or "") .. " "
            .. tostring(row.buffName or ""))
        for _, pattern in ipairs(row.gliderPattern or {}) do
            text = text .. " " .. string.lower(tostring(pattern or ""))
        end
        local matched = text:find(string.lower(tostring(key or "")), 1, true) ~= nil
        for _, pattern in ipairs(patterns or {}) do
            if text:find(string.lower(tostring(pattern or "")), 1, true) then
                matched = true
                break
            end
        end
        if matched then
            row.category = "glider"
            row.recipeDeviceKey = key
            row.recipeDeviceName = name
            row.recipeDeviceKind = "glider"
            row.gliderPattern = patterns
            row.itemTypes = itemTypes
            row.itemType = row.itemType or (itemTypes and itemTypes[1])
            row.recipeDeviceItemType = displayItemType or row.itemType
            row.recipeDeviceIcon = nil
            row.recipeDeviceIconLocked = false
        end
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
        local userManaged = existing.userManaged == true
        local staleGenericStar = existing.buffName == "Star Divine Protection" and not existing.gliderPattern and not recoverableStarRecipe
        -- Rows the user explicitly created/edited are never auto-dropped by the
        -- deprecation heuristics; those only police the built-in default rows. This is
        -- what was silently deleting user-added glider/mount cooldowns on relog.
        -- catalogOrphan: a merged copy of a catalog default that no longer exists (the
        -- catalog was trimmed to the Star Divine Protection gliders). recipeAbilityKey is
        -- only ever set by the catalog, so user-added rows are never affected.
        local catalogOrphan = not userManaged and existing.recipeAbilityKey ~= nil and defaultsByKey[key] == nil
        local autoDropped = not userManaged and (catalogOrphan or DEPRECATED_TRACKED_BUFFS[key] or staleGenericStar or TargetOverlay.isDeprecatedTrackedBuffRow(existing))
        if not usedKeys[key] and not autoDropped then
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
                -- Keep user-managed rows verbatim; the merge only rebuilds built-in
                -- default rows from the catalog (which is why their non-preserved fields
                -- used to revert every load).
                table.insert(ordered, mergedRow(userManaged and nil or defaultRow, existing))
                usedKeys[key] = true
            end
        end
    end
    for _, row in ipairs(defaults.trackedBuffs or {}) do
        local key = trackedBuffSettingKey(row)
        if not usedKeys[key] and not cooldownDefaultRemoved(key) then
            table.insert(ordered, copyRow(row))
            usedKeys[key] = true
        end
    end
    for _, row in ipairs(ordered) do
        if row.cooldownStartsOnActive == nil then row.cooldownStartsOnActive = true end
        normalizeKnownMountDeviceIcon(row, "ser_meatball", "Ser Meatball", 9000375, {"meatball"})
        normalizeKnownMountDeviceIcon(row, "bouncy_cow", "Bouncy Cow", 53939, {"bouncy cow", "asianbunnyx"})
        normalizeKnownMountDeviceIcon(row, "golem", "Golem", 37136, {"golem", "andelph", "patrol mech"})
        normalizeKnownGliderDeviceIcon(row, "stormduster_1000", "Stormduster 1000", {
            42736,
            8001544,
            8001545,
            8001546,
            8001547,
            8001548,
            8001549,
            8001550
        }, 8001544, {"stormduster", "stormduster 1000", "storm duster", "enhanced stormduster 1000"})
    end
    settings.trackedBuffs = ordered
    if migrateHardcodedGliders then settings.hardcodedGliderDefaultsVersion = 1 end
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
        -- formatBuffId, not tostring: with %.6g tostring the "8000566" comparison below
        -- could never match (it rendered as "8.00057e+006").
        local id = OverlayUtils.formatBuffId(row.id or row.skillId or "")
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

-- Compact one-line trace emitted before/instead of each global settings write, so
-- save-timing and data-shape regressions are visible in the client log. Saves are
-- user-triggered (infrequent), so this is not a per-frame cost.
function TargetOverlay.logSettingsSave(reason)
    if not (settings and settings.debugLogging == true) then return end
    if not (api.Log and api.Log.Info) then return end
    local hs = type(settings) == "table" and settings.hotSwap
    local gearSets = type(hs) == "table" and hs.gear_sets
    local gearCount = type(gearSets) == "table" and #gearSets or -1
    local buffCount = type(settings) == "table" and type(settings.trackedBuffs) == "table" and #settings.trackedBuffs or -1
    local hasProfiles = type(settingsRoot) == "table" and type(settingsRoot.characterProfiles) == "table"
    local key = (type(settingsRoot) == "table" and settingsRoot.activeProfileKey) or "?"
    pcall(function()
        api.Log:Info("[PowerRangerON] settings " .. tostring(reason)
            .. " profile=" .. tostring(key)
            .. " hotSwap.gear_sets=" .. tostring(gearCount)
            .. " trackedBuffs=" .. tostring(buffCount)
            .. " characterProfiles=" .. tostring(hasProfiles))
    end)
end

local function loadSettings()
    -- Source of truth is our private file (immune to the shared-file reset and to the
    -- serializer's id rounding); falls back to the shared branch on first run.
    settingsRoot = SettingsStore.Load(ADDON_ID)
    settings, settingsProfileKey, playerName, settingsRoot, settingsProfileState = SettingsProfile.Resolve(api, settingsRoot)
    SettingsStore.SetRoot(settingsRoot)
    if settingsProfileState and settingsProfileState.error and api.Log and api.Log.Err then
        pcall(function()
            api.Log:Err("[PowerRangerON] Settings profile migration stopped: "
                .. tostring(settingsProfileState.error)
                .. ". Existing settings remain active and were not overwritten.")
        end)
    end
    if settingsProfileKey == "__pending__" or settingsProfileKey == "__migration_failed__" then
        settings = copySerializable(settings) or {}
    end
    local simpleSpacingVersion = tonumber(settings.simpleSpacingVersion) or 1
    local hadSimpleSpacing = settings.simpleColumnGap ~= nil or settings.simpleLineGap ~= nil
    copyDefaults(settings, defaults)
    ClassIntelProfiles.Ensure(settings)
    CooldownLearning.Ensure(settings)
    if (tonumber(settings.removedCooldownDefaultsVersion) or 0) < 2 then
        settings.removedCooldownDefaults = {}
        settings.removedCooldownDefaultsVersion = 2
    end
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
    if settings.overlayTextStyle ~= "outline" then settings.overlayTextStyle = "shadow" end
    settings.overlayTextShadow = settings.overlayTextStyle == "shadow"
    settings.compactModelLeftOffset = math.max(20, math.min(140, tonumber(settings.compactModelLeftOffset) or CONFIG.compactModelLeftOffset))
    settings.modelRangeOffsetX = math.max(-120, math.min(120, tonumber(settings.modelRangeOffsetX) or 0))
    settings.modelRangeOffsetY = math.max(-120, math.min(120, tonumber(settings.modelRangeOffsetY) or 0))
    settings.modelRangeScaleLevel = math.max(0, math.min(10, tonumber(settings.modelRangeScaleLevel) or 0))
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
    SettingsSanitizer.Clean(settingsRoot or settings)
    -- Do NOT api.SaveSettings() here. SaveAddonSettings() serializes EVERY addon's
    -- live settings and rewrites the whole shared addon_settings file. Doing that
    -- during the load window persisted other addons' transient/default state (the
    -- "all addons reset + re-enabled on reload" bug). Migrations applied above stay
    -- in memory and persist on the next genuine user-triggered save.
    TargetOverlay.logSettingsSave("loaded (no write)")
end

local function saveSettings(reason)
    -- Guard: never write when our own settings table is missing/uninitialised --
    -- that would push a default-shaped power_ranger_on branch into the shared file.
    if type(settings) ~= "table" then
        TargetOverlay.logSettingsSave("SKIPPED (settings not ready)")
        return
    end
    if settingsProfileKey == "__pending__" or settingsProfileKey == "__migration_failed__" then
        TargetOverlay.logSettingsSave("SKIPPED (profile unresolved)")
        return
    end
    if type(settingsRoot) == "table"
        and type(settingsRoot.characterProfiles) == "table"
        and settingsProfileKey
        and settingsProfileKey ~= "__account__" then
        settingsRoot.characterProfiles[settingsProfileKey] = settings
    end
    TargetOverlay.logSettingsSave(reason or "saving (user change)")
    -- Persist to our private file (+ backup). Store.Save sanitizes and id-encodes for us;
    -- we no longer write the shared addon_settings, so we can neither corrupt nor reset
    -- other addons, and we recover our own data even if the shared file is wiped.
    SettingsStore.Save()
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

function TargetOverlay.useOutlineText()
    return settings and settings.overlayTextStyle == "outline"
end

function TargetOverlay.applyReadableTextStyle(widget, enabled)
    if not widget or not widget.style then return end
    enabled = enabled ~= false
    if widget.style.SetShadow then widget.style:SetShadow(enabled and not TargetOverlay.useOutlineText()) end
    if widget.style.SetOutline then widget.style:SetOutline(enabled and TargetOverlay.useOutlineText()) end
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

TargetOverlay.uiContext = TargetOverlay.targetUi.Context(COLORS, function(key)
    cycleSettingColor(key)
    refreshSettingsButtons()
end)

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

local function uiScaleFactor(key)
    return 1 + ((tonumber(settings and settings[key or "uiScaleLevel"]) or 0) * 0.1)
end

local function guildFamilyScaleFactor()
    return uiScaleFactor("guildFamilyLabelScaleLevel") * 0.75
end

local function normalizeStumpyPriorityName(name)
    local text = string.lower(tostring(name or ""))
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function isStumpyPriorityTargetName(name)
    local key = normalizeStumpyPriorityName(name)
    if key == "" or key == "nil" then return false end
    local stumpySettings = OverlayUtils.safeCall(function() return api.GetSettings("Stumpy_Sense") end)
    if type(stumpySettings) ~= "table" or type(stumpySettings.priorityNames) ~= "table" then return false end
    for _, value in ipairs(stumpySettings.priorityNames) do
        if normalizeStumpyPriorityName(value) == key then return true end
    end
    return false
end

local function stumpyTargetName(info)
    local name = TargetOverlay.ownershipField(info, {"name", "targetName", "unitName", "characterName"})
    if name then return name end
    return OverlayUtils.safeCall(function() return api.Unit:UnitName("target") end)
end

local function trackedBuffKey(row)
    if row and row.sharedCooldownKey then return "shared:" .. tostring(row.sharedCooldownKey) end
    return trackedBuffSettingKey(row)
end

local function trackedBuffTriggerKey(row)
    if row and row.importKey then return "trigger:" .. tostring(row.importKey) end
    local unit = tostring(row and row.unit or "player")
    local devicePart = ""
    if row and (row.gliderPattern or row.category == "glider") then
        devicePart = ":glider:" .. string.lower(tostring(row.recipeDeviceKey or row.recipeDeviceName or row.name or row.source or ""))
    elseif row and (row.recipeDeviceKind == "mount" or row.category == "mount" or row.mountNames or row.mountName or row.mount_name) then
        devicePart = ":mount:" .. string.lower(tostring(row.recipeDeviceKey or row.recipeDeviceName or row.source or row.mountName or row.mount_name or ""))
    end
    if row and row.buffNames and row.buffNames[1] then
        return unit .. ":trigger:" .. string.lower(tostring(row.buffNames[1])) .. devicePart
    end
    if row and row.buffName then return unit .. ":trigger:" .. string.lower(tostring(row.buffName)) .. devicePart end
    if row and row.id then return unit .. ":trigger:" .. OverlayUtils.formatBuffId(row.id) .. devicePart end
    return trackedBuffKey(row)
end

function TargetOverlay.clamp(value, minValue, maxValue)
    return TargetOverlay.windowHelpers.Clamp(value, minValue, maxValue)
end

function TargetOverlay.safeWindowPosition(x, y, width, height)
    return TargetOverlay.windowHelpers.SafePosition(x, y, width, height)
end

function TargetOverlay.windowPosition(window)
    return TargetOverlay.windowHelpers.Position(window)
end

function TargetOverlay.saveWindowPosition(window, keyX, keyY)
    TargetOverlay.windowHelpers.SavePosition(window, settings, keyX, keyY, saveSettings)
end

local function applyDrag(window, handle, keyX, keyY, allowPlainDrag)
    TargetOverlay.windowHelpers.ApplyDrag(window, handle, settings, keyX, keyY, saveSettings, allowPlainDrag)
end

local function applyHandleDrag(window, handle, keyX, keyY)
    TargetOverlay.windowHelpers.ApplyHandleDrag(window, handle, settings, keyX, keyY, saveSettings)
end

function TargetOverlay.getDistance(token)
    return TargetOverlay.targetReader.GetDistance(OverlayUtils.safeCall, token)
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
    return TargetOverlay.targetReader.GetInfoById(OverlayUtils.safeCall, targetId)
end

function TargetOverlay.isCharacterTarget(info, gearscore)
    return TargetOverlay.targetReader.IsCharacter(info, gearscore)
end

function TargetOverlay.isPlayerTarget(info)
    return TargetOverlay.targetReader.IsPlayer(info)
end

function TargetOverlay.ownershipField(info, keys)
    return TargetOverlay.targetReader.OwnershipField(OverlayUtils.textField, info, keys)
end

function TargetOverlay.hasOwnershipFields(info)
    return TargetOverlay.targetReader.HasOwnershipFields(OverlayUtils.textField, info)
end

function TargetOverlay.isOwnershipTarget(info)
    return TargetOverlay.targetReader.IsOwnership(OverlayUtils.textField, info)
end

function TargetOverlay.getClassName(targetInfo)
    return TargetOverlay.targetReader.GetClassName(OverlayUtils.safeCall, targetInfo)
end

function TargetOverlay.getDefense(info)
    return TargetOverlay.targetReader.GetDefense(OverlayUtils.numField, info)
end

function TargetOverlay.fillDefense(basePdef, baseMdef, basePdefPct, baseMdefPct, info)
    return TargetOverlay.targetReader.FillDefense(OverlayUtils.numField, basePdef, baseMdef, basePdefPct, baseMdefPct, info)
end

function TargetOverlay.targetExtraStats(tokenInfo, targetInfo, modifierInfo)
    return TargetOverlay.targetReader.ExtraStats(OverlayUtils, tokenInfo, targetInfo, modifierInfo)
end

function TargetOverlay.equippedSnapshot(slot)
    return TargetOverlay.equipmentReader.Snapshot(slot)
end

function TargetOverlay.gliderEquipSlot()
    return TargetOverlay.equipmentReader.GliderSlot()
end

function TargetOverlay.equippedGliderSnapshot()
    return TargetOverlay.equipmentReader.GliderSnapshot()
end

function TargetOverlay.mountedPetSnapshot()
    return TargetOverlay.equipmentReader.MountedPetSnapshot()
end

function TargetOverlay.trackedGliderMatches(row, glider)
    return TargetOverlay.equipmentReader.DeviceMatches(row, glider)
end

function TargetOverlay.trackedMountMatches(row, mount)
    if not row then return false end
    if not mount or tostring(mount.name or "") == "" then return false end
    local mountName = string.lower(tostring(mount.name or ""))
    local names = row.mountNames or row.mount_names or row.mountName or row.mount_name
    if type(names) ~= "table" then names = {names} end
    if #names == 0 then return row.category == "mount" or row.recipeDeviceKind == "mount" or row.preferMountIcon == true end
    for _, name in ipairs(names) do
        local wanted = string.lower(tostring(name or ""))
        if wanted ~= "" and (mountName:find(wanted, 1, true) or wanted:find(mountName, 1, true)) then return true end
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
    return TargetOverlay.resourceLookup.BuffTooltipById(id, TargetOverlay.optionalBuffHelper)
end

function TargetOverlay.buffIconById(id)
    return TargetOverlay.resourceLookup.BuffIconById(id, TargetOverlay.optionalBuffHelper)
end

function TargetOverlay.itemIconByType(itemType)
    return TargetOverlay.resourceLookup.ItemIconByType(itemType)
end

function TargetOverlay.cooldownRowIcon(row)
    return TargetOverlay.resourceLookup.CooldownRowIcon(row)
end

function TargetOverlay.cooldownDeviceIcon(row)
    return TargetOverlay.resourceLookup.CooldownDeviceIcon(row)
end

function TargetOverlay.buffCooldownById(id)
    return TargetOverlay.resourceLookup.BuffCooldownById(id, TargetOverlay.optionalBuffHelper)
end

function TargetOverlay.buffNameById(id)
    return TargetOverlay.resourceLookup.BuffNameById(id, TargetOverlay.optionalBuffHelper)
end

function TargetOverlay.detectedCooldown(name, id, fallback)
    return TargetOverlay.resourceLookup.DetectedCooldown(name, id, fallback, TargetOverlay.optionalBuffHelper)
end

function TargetOverlay.skillIconById(id)
    return TargetOverlay.resourceLookup.SkillIconById(id)
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

function TargetOverlay.getActiveSettings()
    return settings
end

function TargetOverlay.saveActiveSettings(reason)
    saveSettings(reason or "saving (module change)")
end

function TargetOverlay.getActiveProfileKey()
    return settingsProfileKey
end

function TargetOverlay.getSettingsRoot()
    return settingsRoot
end

local function createIcon(parent, id, x, y, size)
    return TargetOverlay.iconWidgets.Create(parent, id, x, y, size, addBg)
end

local function setIcon(icon, path)
    TargetOverlay.iconWidgets.Set(icon, path)
end

local function setCachedIcon(icon, path)
    TargetOverlay.iconWidgets.SetCached(icon, path)
end

local function setEquipIcon(icon, path)
    TargetOverlay.iconWidgets.SetEquip(icon, path)
end

local function setCooldownIcon(icon, path, state, seconds)
    TargetOverlay.iconWidgets.SetCooldown(icon, path, state, seconds)
end

local function setCooldownSkillIcon(icon, path, state, seconds)
    TargetOverlay.iconWidgets.SetCooldownSkill(icon, path, state, seconds)
end

local function clearCooldownIcon(icon)
    TargetOverlay.iconWidgets.ClearCooldown(icon)
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

function TargetOverlay.fitTextToWidth(widget, text, maxWidth, minChars)
    text = tostring(text or "")
    if text == "" or not widget or not widget.style or not widget.style.GetTextWidth then return text end
    maxWidth = tonumber(maxWidth) or 0
    minChars = tonumber(minChars) or 4
    if widget.style:GetTextWidth(text) <= maxWidth then return text end
    local limit = #text
    while limit > minChars do
        limit = limit - 1
        local fitted = OverlayUtils.shortText(text, limit)
        if widget.style:GetTextWidth(fitted) <= maxWidth then return fitted end
    end
    return OverlayUtils.shortText(text, minChars)
end

function TargetOverlay.compactSummaryText(parts, guildLimit, familyLimit)
    local out = {}
    for _, part in ipairs(parts or {}) do
        local text = part.text or ""
        if part.key == "guild" and guildLimit then
            text = OverlayUtils.shortText(text, guildLimit)
        elseif (part.key == "family" or part.key == "owner" or part.key == "destination") and familyLimit then
            text = OverlayUtils.shortText(text, familyLimit)
        end
        if text ~= "" then table.insert(out, text) end
    end
    return table.concat(out, " | ")
end

function TargetOverlay.fitCompactSummaryParts(widget, parts, maxWidth)
    local fullText = TargetOverlay.compactSummaryText(parts)
    if not parts or #parts == 0 then return "" end
    if widget and widget.style and widget.style.GetTextWidth and widget.style:GetTextWidth(fullText) <= maxWidth then
        return fullText
    end
    local hasFamily = false
    for _, part in ipairs(parts) do
        if part.key == "family" or part.key == "owner" or part.key == "destination" then
            hasFamily = true
            break
        end
    end
    if not hasFamily then return TargetOverlay.fitTextToWidth(widget, fullText, maxWidth, 6) end
    for familyLimit = 12, 4, -1 do
        local text = TargetOverlay.compactSummaryText(parts, nil, familyLimit)
        if widget.style:GetTextWidth(text) <= maxWidth then return text end
    end
    for guildLimit = 32, 8, -1 do
        local text = TargetOverlay.compactSummaryText(parts, guildLimit, 4)
        if widget.style:GetTextWidth(text) <= maxWidth then return text end
    end
    return TargetOverlay.fitTextToWidth(widget, TargetOverlay.compactSummaryText(parts, 8, 4), maxWidth, 6)
end

local function classProfileStatVisible(targetInfo, className, statKey)
    local profileValue = ClassIntelProfiles.ShouldShow(settings, targetInfo, className, statKey)
    return profileValue == true
end

local function buildInfoRows(targetInfo, className, gearscore, pdef, mdef, pdefPct, mdefPct, extraStats, ownershipOnly, forceExpanded)
    local identity = {}
    local defense = {}
    local compactSummary = {}
    local simpleMeta = {}
    local simpleGuild = nil
    local compact = (settings.compactTargetWindow or settings.testTargetWindow) and forceExpanded ~= true
    local function addRow(list, key, text, forceCol)
        if text and text ~= "" then
            table.insert(list, { key = key, text = text, color = settingColor(key), forceCol = forceCol })
        end
    end
    local function addSummary(text, key)
        if text and text ~= "" then
            if settings.testTargetWindow then
                table.insert(simpleMeta, text)
            else
                table.insert(compactSummary, { text = text, key = key })
            end
        end
    end
    if compact and not settings.testTargetWindow and settings.showInfoRange then
        local range = TargetOverlay.getDistance("target")
        if range then addSummary(tostring(range) .. "m", "range") end
    end
    if compact and settings.showInfoGearscore and gearscore then addSummary(tostring(gearscore), "gearscore") end
    if compact and settings.showInfoClass and className then addSummary(OverlayUtils.shortText(className, 16), "class") end
    if ownershipOnly and (targetInfo.is_portal or targetInfo.isPortal) then
        local portalOwner = TargetOverlay.ownershipField(targetInfo, {"portal_owner", "portalOwner", "owner_name", "ownerName", "owner"})
        local destination = TargetOverlay.ownershipField(targetInfo, {"name", "targetName", "destination"})
        if portalOwner then
            if settings.testTargetWindow then simpleGuild = OverlayUtils.shortText(portalOwner, 34)
            elseif compact then addSummary(portalOwner, "guild")
            else addRow(identity, "guild", "Owner: " .. OverlayUtils.shortText(portalOwner, 21)) end
        end
        if destination then
            if compact then addSummary(destination, "destination")
            else addRow(identity, "family", "Portal: " .. OverlayUtils.shortText(destination, 20)) end
        end
    elseif settings.showInfoGuild or ownershipOnly then
        local guild = TargetOverlay.ownershipField(targetInfo, {"expeditionName", "expedition", "guildName", "guild"})
        if guild then
            if settings.testTargetWindow then simpleGuild = OverlayUtils.shortText(guild, 34)
            elseif compact then addSummary(guild, "guild")
            else addRow(identity, "guild", "Guild: " .. OverlayUtils.shortText(guild, 21)) end
        end
    end
    if settings.showInfoFamily or ownershipOnly then
        local family = TargetOverlay.ownershipField(targetInfo, {"family_name", "familyName", "family"})
        local owner = ownershipOnly and TargetOverlay.ownershipField(targetInfo, {"owner_name", "ownerName", "owner"}) or nil
        if family then
            if compact then
                addSummary(family, "family")
            else addRow(identity, "family", "Family: " .. OverlayUtils.shortText(family, 20)) end
        end
        if owner and owner ~= family then
            if compact then
                addSummary(owner, "owner")
            else addRow(identity, "family", "Owner: " .. OverlayUtils.shortText(owner, 20)) end
        end
    end
    if ownershipOnly then
        local rows = {}
        if not compact and #identity > 0 then
            table.insert(rows, { header = true, text = "Ownership" })
            for _, row in ipairs(identity) do table.insert(rows, row) end
        end
        return rows, TargetOverlay.compactSummaryText(compactSummary), simpleGuild or "", table.concat(simpleMeta, "  |  "), compactSummary
    end
    if not compact and settings.showInfoClass and className then addRow(identity, "class", "Class: " .. OverlayUtils.shortText(className, 22)) end
    if not compact and settings.showInfoGearscore and gearscore then addRow(identity, "gearscore", "GS: " .. tostring(gearscore)) end
    local rangeHeader = ""
    if not compact and settings.showInfoRange then
        local range = TargetOverlay.getDistance("target")
        if range then rangeHeader = "  |  " .. tostring(range) .. "m" end
    end
    if classProfileStatVisible(targetInfo, className, "pdef") then addRow(defense, "pdef", "PDef: " .. OverlayUtils.defenseText(pdef, pdefPct)) end
    if classProfileStatVisible(targetInfo, className, "mdef") then addRow(defense, "mdef", "MDef: " .. OverlayUtils.defenseText(mdef, mdefPct)) end
    extraStats = extraStats or {}
    if classProfileStatVisible(targetInfo, className, "block") then addRow(defense, "block", extraStats.block and ("Block: " .. extraStats.block) or nil) end
    if classProfileStatVisible(targetInfo, className, "parry") then addRow(defense, "parry", extraStats.parry and ("Parry: " .. extraStats.parry) or nil) end
    if classProfileStatVisible(targetInfo, className, "evasion") then addRow(defense, "evasion", extraStats.evasion and ("Evasion: " .. extraStats.evasion) or nil) end
    if classProfileStatVisible(targetInfo, className, "toughness") then addRow(defense, "toughness", extraStats.toughness and ("Tough: " .. extraStats.toughness) or nil) end
    if classProfileStatVisible(targetInfo, className, "resilience") then
        addRow(defense, "resilience", extraStats.resilience and ("Resil: " .. extraStats.resilience) or nil)
    end
    if classProfileStatVisible(targetInfo, className, "critRate") then addRow(defense, "critRate", extraStats.critRate and ("Crit: " .. extraStats.critRate) or nil) end
    -- Catalog stats (target_stats_catalog): profile-selected raw UnitInfo stats.
    -- Expanded mode lists them under their own "Stats" header; compact/simple
    -- mode merges them into the stats grid, balanced across both grid rows.
    local catalogStats = {}
    if extraStats.catalogInfos then
        for _, stat in ipairs(TargetOverlay.statsCatalog.STATS) do
            if not stat.legacy and classProfileStatVisible(targetInfo, className, stat.key) then
                local text = TargetOverlay.statsCatalog.Value(OverlayUtils, extraStats.catalogInfos, stat)
                if text then addRow(catalogStats, stat.key, stat.label .. ": " .. text) end
            end
        end
    end
    if compact then
        for _, row in ipairs(catalogStats) do
            row.catalog = true
            table.insert(defense, row)
        end
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
                if gridRow == nil and row.catalog then gridRow = -1 end
                if gridRow ~= nil then
                    if row.key == "critRate" or gridRow == -1 then
                        local topCount = #(simpleRows[0] or {})
                        local bottomCount = #(simpleRows[1] or {})
                        gridRow = topCount <= bottomCount and 0 or 1
                    end
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
                if gridRow == nil and row.catalog then gridRow = -1 end
                if gridRow ~= nil then
                    if row.key == "critRate" or gridRow == -1 then
                        local topCount = #(compactRows[0] or {})
                        local bottomCount = #(compactRows[1] or {})
                        gridRow = topCount <= bottomCount and 0 or 1
                    end
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
    -- Expanded mode only: in compact/simple the catalog rows were already merged
    -- into the defense grid above, so appending here would duplicate them.
    if not compact and #catalogStats > 0 then
        table.insert(rows, { header = true, text = "Stats" })
        for _, row in ipairs(catalogStats) do table.insert(rows, row) end
    end
    return rows, TargetOverlay.compactSummaryText(compactSummary), simpleGuild or "", table.concat(simpleMeta, "  |  "), compactSummary
end

local function createTargetInfoWindow()
    targetInfoWnd = require("power_ranger_on/target_windows").CreateTargetInfo({
        colors = COLORS,
        settings = settings,
        addBg = TargetOverlay.uiContext.addBg,
        label = TargetOverlay.uiContext.label,
        safePosition = TargetOverlay.safeWindowPosition,
        applyHandleDrag = applyHandleDrag
    })
end

local function createOwnershipWindow()
    ownershipWnd = require("power_ranger_on/target_windows").CreateOwnership({
        colors = COLORS,
        settings = settings,
        label = TargetOverlay.uiContext.label,
        safePosition = TargetOverlay.safeWindowPosition,
        applyReadableTextStyle = TargetOverlay.applyReadableTextStyle,
        applyHandleDrag = applyHandleDrag
    })
end

local function createGuildFamilyWindow()
    guildFamilyWnd = require("power_ranger_on/target_windows").CreateGuildFamily({
        colors = COLORS,
        settings = settings,
        label = TargetOverlay.uiContext.label,
        safePosition = TargetOverlay.safeWindowPosition,
        applyReadableTextStyle = TargetOverlay.applyReadableTextStyle,
        applyHandleDrag = applyHandleDrag
    })
end

local function hideOwnershipWindow()
    if ownershipWnd then ownershipWnd:Show(false) end
end

local function hideGuildFamilyWindow()
    if guildFamilyWnd then guildFamilyWnd:Show(false) end
end

function TargetOverlay.applyTextShadow()
    local modelLabels = {
        targetPdefTitleLabel, targetPdefValueLabel, targetMdefTitleLabel, targetMdefValueLabel,
        targetGearscoreLabel, targetClassLabel, targetRangeLabel
    }
    for _, widget in ipairs(modelLabels) do
        TargetOverlay.applyReadableTextStyle(widget, true)
    end
    if ownershipWnd then
        TargetOverlay.applyReadableTextStyle(ownershipWnd.title, true)
        TargetOverlay.applyReadableTextStyle(ownershipWnd.meta, true)
        TargetOverlay.applyReadableTextStyle(ownershipWnd.markTime, true)
    end
    if guildFamilyWnd then
        TargetOverlay.applyReadableTextStyle(guildFamilyWnd.guild, true)
        TargetOverlay.applyReadableTextStyle(guildFamilyWnd.family, true)
    end
    if targetInfoWnd then
        local simpleEnabled = settings.testTargetWindow == true
        TargetOverlay.applyReadableTextStyle(targetInfoWnd.title, simpleEnabled)
        TargetOverlay.applyReadableTextStyle(targetInfoWnd.simpleMeta, simpleEnabled)
        for i = 1, 30 do
            TargetOverlay.applyReadableTextStyle(targetInfoWnd.rows[i], simpleEnabled)
            TargetOverlay.applyReadableTextStyle(targetInfoWnd.simpleValues[i], simpleEnabled)
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
    TargetOverlay.clearStumpyStatsBox()
    local titleDisplay = OverlayUtils.shortText(titleText, 34)
    local metaDisplay = table.concat(meta, "  |  ")
    local scale = uiScaleFactor("ownershipScaleLevel")
    local targetMark = TargetOverlay.ownersMark.GetTargetMark()
    local markWidth = targetMark and math.floor((30 * scale) + 0.5) or 0
    local pad = math.floor((4 * scale) + 0.5)
    local titleHeight = math.floor((20 * scale) + 0.5)
    local metaHeight = math.floor((16 * scale) + 0.5)
    ownershipWnd.title.style:SetFontSize(math.floor((15 * scale) + 0.5))
    ownershipWnd.meta.style:SetFontSize(math.floor((11 * scale) + 0.5))
    ownershipWnd.title:SetText(titleDisplay)
    ownershipWnd.meta:SetText(metaDisplay)
    ownershipWnd.meta:Show(#meta > 0)
    ownershipWnd.markIcon:Show(targetMark ~= nil)
    ownershipWnd.markTime:Show(targetMark ~= nil)
    if targetMark then
        ownershipWnd.markIcon:SetExtent(math.floor((24 * scale) + 0.5), math.floor((24 * scale) + 0.5))
        if targetMark.path and ownershipWnd.markIcon._lastPath ~= targetMark.path then
            F_SLOT.SetIconBackGround(ownershipWnd.markIcon, targetMark.path)
            ownershipWnd.markIcon._lastPath = targetMark.path
        end
        ownershipWnd.markTime.style:SetFontSize(math.floor((10 * scale) + 0.5))
        ownershipWnd.markTime:SetText(string.format("%.0fs", math.max(0, (tonumber(targetMark.timeLeft) or 0) - 750) / 1000))
    end
    setTextColor(ownershipWnd.title, guild and settingColor("guild") or settingColor("family"))
    setTextColor(ownershipWnd.meta, COLORS.white)
    local titleWidth = ownershipWnd.title.style:GetTextWidth(titleDisplay)
    local metaWidth = #meta > 0 and ownershipWnd.meta.style:GetTextWidth(metaDisplay) or 0
    local wantedWidth = math.max(math.floor((120 * scale) + 0.5), math.min(math.floor((490 * scale) + 0.5), math.ceil(math.max(titleWidth, metaWidth) + (12 * scale) + markWidth)))
    local wantedHeight = #meta > 0 and math.floor((42 * scale) + 0.5) or math.floor((24 * scale) + 0.5)
    local hasMark = targetMark ~= nil
    if ownershipWnd._lastWidth ~= wantedWidth
        or ownershipWnd._lastHeight ~= wantedHeight
        or ownershipWnd._lastHasMark ~= hasMark then
        ownershipWnd:SetExtent(wantedWidth, wantedHeight)
        ownershipWnd.title:RemoveAllAnchors()
        if targetMark then
            ownershipWnd.markIcon:RemoveAllAnchors()
            ownershipWnd.markIcon:AddAnchor("TOPLEFT", ownershipWnd, pad, 0)
            ownershipWnd.markTime:RemoveAllAnchors()
            ownershipWnd.markTime:AddAnchor("TOP", ownershipWnd.markIcon, "BOTTOM", 0, -2)
        end
        ownershipWnd.title:AddAnchor("TOPLEFT", ownershipWnd, pad + markWidth, 0)
        ownershipWnd.title:SetExtent(wantedWidth - (pad * 2) - markWidth, titleHeight)
        ownershipWnd.meta:RemoveAllAnchors()
        ownershipWnd.meta:AddAnchor("TOPLEFT", ownershipWnd, pad + markWidth, titleHeight)
        ownershipWnd.meta:SetExtent(wantedWidth - (pad * 2) - markWidth, metaHeight)
        ownershipWnd.dragHandle:SetExtent(wantedWidth, wantedHeight)
        ownershipWnd._lastWidth = wantedWidth
        ownershipWnd._lastHeight = wantedHeight
        ownershipWnd._lastHasMark = hasMark
    end
    ownershipWnd:Show(true)
end

local function refreshGuildFamilyWindow(info)
    if not guildFamilyWnd or not info then return end
    if settings.showGuildFamilyLabel ~= true then
        hideGuildFamilyWindow()
        return
    end
    local guild = TargetOverlay.ownershipField(info, {"expeditionName", "expedition", "guildName", "guild"})
    local family = TargetOverlay.ownershipField(info, {"family_name", "familyName", "family"})
    if not guild and not family then
        hideGuildFamilyWindow()
        return
    end
    local scale = guildFamilyScaleFactor()
    local wantedWidth = math.floor((360 * scale) + 0.5)
    local pad = math.floor((10 * scale) + 0.5)
    local textWidth = math.max(80, wantedWidth - (pad * 2))
    local guildText = tostring(guild or "")
    local familyText = tostring(family or "")
    local guildHeight = math.floor((28 * scale) + 0.5)
    local familyHeight = math.floor((16 * scale) + 0.5)
    local gap = math.floor((2 * scale) + 0.5)
    guildFamilyWnd.guild.style:SetFontSize(math.floor((22 * scale) + 0.5))
    guildFamilyWnd.family.style:SetFontSize(math.floor((12 * scale) + 0.5))
    guildText = TargetOverlay.fitTextToWidth(guildFamilyWnd.guild, guildText, textWidth, 8)
    familyText = TargetOverlay.fitTextToWidth(guildFamilyWnd.family, familyText, textWidth, 6)
    guildFamilyWnd.guild:SetText(guildText)
    guildFamilyWnd.family:SetText(familyText)
    guildFamilyWnd.guild:Show(guildText ~= "")
    guildFamilyWnd.family:Show(familyText ~= "")
    setTextColor(guildFamilyWnd.guild, settingColor("guildFamilyGuild"))
    setTextColor(guildFamilyWnd.family, settingColor("guildFamilyFamily"))
    local wantedHeight = guildHeight + gap + familyHeight
    if guildFamilyWnd._lastWidth ~= wantedWidth or guildFamilyWnd._lastHeight ~= wantedHeight then
        guildFamilyWnd:SetExtent(wantedWidth, wantedHeight)
        guildFamilyWnd.guild:RemoveAllAnchors()
        guildFamilyWnd.guild:AddAnchor("TOP", guildFamilyWnd, "TOP", 0, 0)
        guildFamilyWnd.guild:SetExtent(textWidth, guildHeight)
        guildFamilyWnd.family:RemoveAllAnchors()
        guildFamilyWnd.family:AddAnchor("TOP", guildFamilyWnd, "TOP", 0, guildHeight + gap)
        guildFamilyWnd.family:SetExtent(textWidth, familyHeight)
        guildFamilyWnd.dragHandle:SetExtent(wantedWidth, wantedHeight)
        guildFamilyWnd._lastWidth = wantedWidth
        guildFamilyWnd._lastHeight = wantedHeight
    end
    guildFamilyWnd:Show(true)
end

local function applyStumpySenseAnchor(width)
    if not targetInfoWnd or not stumpySenseLayout or stumpySenseLayout.enabled ~= true then
        return
    end
    if stumpySenseLayout.anchor then
        local ok = pcall(function()
            targetInfoWnd:RemoveAllAnchors()
            targetInfoWnd:AddAnchor("TOPRIGHT", stumpySenseLayout.anchor, "TOPLEFT", -8, 0)
        end)
        if ok then return end
    end
    local anchorX = tonumber(stumpySenseLayout.anchorX)
    local anchorY = tonumber(stumpySenseLayout.anchorY)
    local w = tonumber(width) or tonumber(stumpySenseLayout.width) or 290
    if anchorX and anchorY then
        pcall(function()
            targetInfoWnd:RemoveAllAnchors()
            targetInfoWnd:AddAnchor("TOPLEFT", "UIParent", math.floor(anchorX - w - 8 + 0.5), math.floor(anchorY + 0.5))
        end)
    end
end

local function renderStumpyStatsWindow(rows, compactSummary, scale, targetInfo, className, gearscore)
    local width = math.max(140, math.floor((tonumber(stumpySenseLayout.width) or 176) + 0.5))
    local height = math.max(120, math.floor((tonumber(stumpySenseLayout.height) or 286) + 0.5))
    local headerHeight = 28
    local side = 9
    local gap = 8
    local rowHeight = 17
    local colWidth = math.floor((width - (side * 2) - gap) / 2)
    local labelWidth = math.min(68, math.max(46, math.floor(colWidth * 0.48)))
    local valueWidth = math.max(18, colWidth - labelWidth)
    local guild = TargetOverlay.ownershipField(targetInfo, {"expeditionName", "expedition", "guildName", "guild"})
    local family = TargetOverlay.ownershipField(targetInfo, {"family_name", "familyName", "family"})
    local targetName = stumpyTargetName(targetInfo)
    local priority = isStumpyPriorityTargetName(targetName)
    local titleText = (priority and "\226\152\133 " or "") .. tostring(targetName or guild or "Power Ranger ON")
    local metaParts = {}
    if className and className ~= "" then table.insert(metaParts, tostring(className)) end
    if gearscore then table.insert(metaParts, "GS " .. tostring(gearscore)) end
    local range = TargetOverlay.getDistance("target")
    if range then table.insert(metaParts, tostring(range) .. "m") end
    if #metaParts == 0 and compactSummary and compactSummary ~= "" then table.insert(metaParts, compactSummary) end
    titleText = TargetOverlay.fitTextToWidth(targetInfoWnd.title, titleText, width - (side * 2), 8)
    local metaText = TargetOverlay.fitTextToWidth(targetInfoWnd.simpleMeta, table.concat(metaParts, "  |  "), width - (side * 2), 8)

    if targetInfoWnd._lastHeight ~= height or targetInfoWnd._lastWidth ~= width then
        targetInfoWnd:SetExtent(width, height)
        targetInfoWnd._lastHeight = height
        targetInfoWnd._lastWidth = width
    end
    targetInfoWnd.bg:Show(true)
    targetInfoWnd.header:Show(true)
    pcall(function() targetInfoWnd.bg:SetColor(0, 0, 0, 0.34) end)
    pcall(function() targetInfoWnd.header:SetColor(0.12, 0.135, 0.155, 0.58) end)
    targetInfoWnd.header:SetExtent(width, headerHeight)
    targetInfoWnd.dragHandle:SetExtent(width, headerHeight)

    targetInfoWnd.title:RemoveAllAnchors()
    targetInfoWnd.title:AddAnchor("TOPLEFT", targetInfoWnd, side, 3)
    targetInfoWnd.title:SetExtent(width - (side * 2), 15)
    targetInfoWnd.title.style:SetFontSize(math.floor((14 * scale) + 0.5))
    targetInfoWnd.title:SetText(titleText)
    setTextColor(targetInfoWnd.title, COLORS.gold)
    TargetOverlay.applyReadableTextStyle(targetInfoWnd.title, true)

    targetInfoWnd.simpleMeta:RemoveAllAnchors()
    targetInfoWnd.simpleMeta:AddAnchor("TOPLEFT", targetInfoWnd, side, 17)
    targetInfoWnd.simpleMeta:SetExtent(width - (side * 2), 12)
    targetInfoWnd.simpleMeta.style:SetFontSize(math.floor((10 * scale) + 0.5))
    targetInfoWnd.simpleMeta:SetText(metaText)
    setTextColor(targetInfoWnd.simpleMeta, COLORS.white)
    TargetOverlay.applyReadableTextStyle(targetInfoWnd.simpleMeta, true)
    targetInfoWnd.simpleMeta:Show(metaText ~= "")

    local widgetIndex = 1
    local y = headerHeight + 7
    local col = 0
    for _, row in ipairs(rows or {}) do
        if widgetIndex > 30 or y + rowHeight > height - 3 then break end
        local widget = targetInfoWnd.rows[widgetIndex]
        local valueWidget = targetInfoWnd.simpleValues[widgetIndex]
        widget.style:SetFontSize(math.floor((11 * scale) + 0.5))
        valueWidget.style:SetFontSize(math.floor((11 * scale) + 0.5))
        TargetOverlay.applyReadableTextStyle(widget, true)
        TargetOverlay.applyReadableTextStyle(valueWidget, true)
        widget:RemoveAllAnchors()
        valueWidget:RemoveAllAnchors()
        if row.header then
            if col ~= 0 then
                y = y + rowHeight
                col = 0
            end
            widget:SetExtent(width - (side * 2), 14)
            widget:AddAnchor("TOPLEFT", targetInfoWnd, side, y)
            setInfoCell(widget, tostring(row.text or ""):upper(), COLORS.gold)
            setInfoCell(valueWidget, nil)
            widgetIndex = widgetIndex + 1
            y = y + 15
        elseif row.key == "guild" or row.key == "family" then
            if col ~= 0 then
                y = y + rowHeight
                col = 0
            end
            widget:SetExtent(width - (side * 2), rowHeight)
            widget:AddAnchor("TOPLEFT", targetInfoWnd, side, y)
            setInfoCell(widget, tostring(row.text or ""), row.color or COLORS.white)
            setInfoCell(valueWidget, nil)
            widgetIndex = widgetIndex + 1
            y = y + rowHeight
        else
            local text = tostring(row.text or "")
            local labelText, valueText = text:match("^(.-):%s*(.*)$")
            local x = side + (col * (colWidth + gap))
            widget:SetExtent(labelText and labelWidth or colWidth, rowHeight)
            widget:AddAnchor("TOPLEFT", targetInfoWnd, x, y)
            if labelText then
                if labelText == "Evasion" then labelText = "Evas" end
                setInfoCell(widget, labelText .. ":", COLORS.white)
                valueWidget:SetExtent(valueWidth, rowHeight)
                valueWidget:AddAnchor("TOPLEFT", targetInfoWnd, x + labelWidth, y)
                setInfoCell(valueWidget, valueText, row.color or COLORS.white)
            else
                setInfoCell(widget, text, row.color or COLORS.white)
                setInfoCell(valueWidget, nil)
            end
            widgetIndex = widgetIndex + 1
            if col == 1 then
                y = y + rowHeight
                col = 0
            else
                col = 1
            end
        end
    end
    for i = widgetIndex, 30 do
        setInfoCell(targetInfoWnd.rows[i], nil)
        setInfoCell(targetInfoWnd.simpleValues[i], nil)
    end
    applyStumpySenseAnchor(width)
    local stumpyBoxChanged = TargetOverlay.publishStumpyStatsBox(width, height)
    targetInfoWnd:Show(true)
    notifyStumpyStatsVisible()
    if stumpyBoxChanged then
        pcall(function() api:Emit("STUMPY_DOCK_REGISTER", "power_ranger_stats") end)
    end
end

local function refreshTargetInfoWindow(targetInfo, className, gearscore, pdef, mdef, pdefPct, mdefPct, extraStats, ownershipOnly)
    if not targetInfoWnd then return end
    if ((not settings.showTargetWindow or Compat.ShouldHideTargetInfoWindow(compatState, ownershipOnly)) and not ownershipOnly) or not targetInfo then
        targetInfoWnd:Show(false)
        stumpyStatsDockVisible = false
        TargetOverlay.clearStumpyStatsBox()
        return
    end
    local stumpyMode = stumpySenseLayout and stumpySenseLayout.enabled == true
    local rows, compactSummary, simpleGuild, simpleMeta, compactParts = buildInfoRows(targetInfo, className, gearscore, pdef, mdef, pdefPct, mdefPct, extraStats, ownershipOnly, stumpyMode)
    local compact = settings.compactTargetWindow or settings.testTargetWindow
    local testLayout = settings.testTargetWindow == true
    local summaryVisible = testLayout and (simpleGuild ~= "" or simpleMeta ~= "") or compactSummary ~= ""
    if #rows == 0 and (not compact or not summaryVisible) then
        targetInfoWnd:Show(false)
        stumpyStatsDockVisible = false
        TargetOverlay.clearStumpyStatsBox()
        return
    end
    local scale = uiScaleFactor("targetWindowScaleLevel")
    if stumpyMode then
        renderStumpyStatsWindow(rows, compactSummary, scale, targetInfo, className, gearscore)
        return
    end
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
    pcall(function() targetInfoWnd.bg:SetColor(0, 0, 0, 0.62) end)
    pcall(function() targetInfoWnd.header:SetColor(0.06, 0.075, 0.095, 0.76) end)
    setTextColor(targetInfoWnd.title, testLayout and COLORS.white or COLORS.gold)
    TargetOverlay.applyReadableTextStyle(targetInfoWnd.title, testLayout)
    TargetOverlay.applyReadableTextStyle(targetInfoWnd.simpleMeta, testLayout)
    local headerHeight = math.floor(((compact and 18 or 22) * scale) + 0.5)
    local sideMargin = math.floor(((testLayout and 4 or compact and 6 or 12) * scale) + 0.5)
    -- Snug grid: every column sizes to its own content, so the column gap is a
    -- true pixel gap now. (The old layout used wide uniform 108px cells with a
    -- -43px default offset to fake density, which fell apart once long catalog
    -- stat labels inflated every cell.)
    local simpleColumnGap = math.max(0, math.min(73, tonumber(settings.simpleColumnGap) or 0))
    local simpleLineGap = math.max(0, math.min(23, tonumber(settings.simpleLineGap) or 0)) - 4
    local colGap = math.floor(((testLayout and (4 + simpleColumnGap) or compact and 5 or 12) * scale) + 0.5)
    local titleMargin = math.floor(((testLayout and 4 or compact and 6 or 8) * scale) + 0.5)
    local outlinePad = testLayout and math.floor((4 * scale) + 0.5) or 0
    local minCellWidth = math.floor(((testLayout and 44 or 40) * scale) + 0.5) + outlinePad
    local wantedWidth = math.floor((430 * scale) + 0.5)
    for i = 1, 30 do
        targetInfoWnd.rows[i].style:SetFontSize(math.floor((12 * scale) + 0.5))
        targetInfoWnd.simpleValues[i].style:SetFontSize(math.floor((12 * scale) + 0.5))
        TargetOverlay.applyReadableTextStyle(targetInfoWnd.rows[i], testLayout)
        TargetOverlay.applyReadableTextStyle(targetInfoWnd.simpleValues[i], testLayout)
        setInfoCell(targetInfoWnd.simpleValues[i], nil)
    end
    -- Measure each grid column's own widest cell and lay columns out snugly.
    local gridCols = 0
    local gridColWidths = {}
    local gridColOffsets = {}
    local maxColWidth = minCellWidth
    if compact then
        for _, row in ipairs(rows) do
            if row.compactGridCol ~= nil then
                gridCols = math.max(gridCols, row.compactGridCol + 1)
                local w = math.ceil(targetInfoWnd.rows[1].style:GetTextWidth(row.text or "")) + outlinePad
                if w > (gridColWidths[row.compactGridCol] or 0) then gridColWidths[row.compactGridCol] = w end
            end
        end
        local acc = sideMargin
        for c = 0, gridCols - 1 do
            local w = math.max(gridColWidths[c] or 0, minCellWidth)
            gridColWidths[c] = w
            gridColOffsets[c] = acc
            acc = acc + w + colGap
            if w > maxColWidth then maxColWidth = w end
        end
        local statsWidth = gridCols > 0 and (acc - colGap + sideMargin) or math.floor((150 * scale) + 0.5)
        if testLayout then
            local summaryWidth = targetInfoWnd.title.style:GetTextWidth(simpleGuild)
            summaryWidth = math.max(summaryWidth, targetInfoWnd.simpleMeta.style:GetTextWidth(simpleMeta))
            wantedWidth = math.ceil(math.max(summaryWidth + (titleMargin * 2) + outlinePad, statsWidth))
        else
            wantedWidth = math.ceil(statsWidth)
        end
    end
    local cellWidth = compact and maxColWidth or math.floor((198 * scale) + 0.5)
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
    if compact then
        local titleWidth = wantedWidth - (titleMargin * 2)
        if testLayout then
            targetInfoWnd.title:SetText(TargetOverlay.fitTextToWidth(targetInfoWnd.title, simpleGuild, titleWidth, 8))
            targetInfoWnd.simpleMeta:SetText(TargetOverlay.fitTextToWidth(targetInfoWnd.simpleMeta, simpleMeta, titleWidth, 8))
        else
            targetInfoWnd.title:SetText(TargetOverlay.fitCompactSummaryParts(targetInfoWnd.title, compactParts, titleWidth))
        end
    end
    local widgetIndex = 1
    local y = math.floor(((testLayout and 36 or compact and 20 or 29) * scale) + 0.5)
    local col = 0
    for _, row in ipairs(rows) do
        if widgetIndex > 30 then break end
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
                local colX = gridColOffsets[row.compactGridCol] or (sideMargin + (row.compactGridCol * colStep))
                local colW = gridColWidths[row.compactGridCol] or cellWidth
                widget:RemoveAllAnchors()
                widget:SetExtent(colW, math.floor(((testLayout and 15 or 13) * scale) + 0.5))
                widget:AddAnchor("TOPLEFT", targetInfoWnd, colX, y + (row.compactGridRow * rowStep))
                if testLayout then
                    local labelText, valueText = tostring(row.text or ""):match("^(.-):%s*(.*)$")
                    if labelText == "Evasion" then labelText = "Evas" end
                    -- Value hugs its own label instead of a shared global column.
                    local valueOffset = colW
                    if labelText then
                        valueOffset = math.ceil(targetInfoWnd.rows[1].style:GetTextWidth(labelText .. ":")) + math.floor((2 * scale) + 0.5)
                    end
                    valueWidget:RemoveAllAnchors()
                    valueWidget:SetExtent(math.max(0, colW - valueOffset), math.floor((15 * scale) + 0.5))
                    valueWidget:AddAnchor("TOPLEFT", targetInfoWnd, colX + valueOffset, y + (row.compactGridRow * rowStep))
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
    for i = widgetIndex, 30 do
        setInfoCell(targetInfoWnd.rows[i], nil)
    end
    targetInfoWnd:Show(true)
end

local function updateTrackedBuffs()
    TargetOverlay.buffRuntime.Update({
        settings = settings,
        selfBuffUnits = SELF_BUFF_UNITS,
        nuziBuffRows = nuziCooldownRows.buffs,
        buffState = buffState,
        triggerState = triggerState,
        allTrackedBuffRows = allTrackedBuffRows,
        trackedBuffKey = trackedBuffKey,
        trackedBuffTriggerKey = trackedBuffTriggerKey,
        buffId = TargetOverlay.buffId,
        buffName = TargetOverlay.buffName,
        buffTooltipById = TargetOverlay.buffTooltipById,
        buffIconById = TargetOverlay.buffIconById,
        cooldownRowIcon = TargetOverlay.cooldownRowIcon,
        cooldownDeviceIcon = TargetOverlay.cooldownDeviceIcon,
        trackedGliderMatches = TargetOverlay.trackedGliderMatches,
        equippedGliderSnapshot = TargetOverlay.equippedGliderSnapshot,
        mountedPetSnapshot = TargetOverlay.mountedPetSnapshot,
        isStarTriggerCooldown = TargetOverlay.isStarTriggerCooldown,
        serialValue = SkillProbe.serialValue,
        recordSkillProbe = recordSkillProbe,
        saveSettings = saveSettings
    })
end

local function trackedSkillCooldownKey(row, skillName, skillId)
    -- formatBuffId: numeric ids must not go through this client's %.6g tostring.
    return OverlayUtils.formatBuffId(row and (row.importKey or row.id or row.skillId or row.pattern or row.name) or skillName or skillId or "")
end

local function createSelfWindow()
    selfWnd = require("power_ranger_on/target_windows").CreateSelf({
        colors = COLORS,
        settings = settings,
        selfPanel = SELF_PANEL,
        addBg = TargetOverlay.uiContext.addBg,
        label = TargetOverlay.uiContext.label,
        flatButton = TargetOverlay.uiContext.flatButton,
        createIcon = createIcon,
        safePosition = TargetOverlay.safeWindowPosition,
        applyHandleDrag = applyHandleDrag,
        toggleSelfMinimized = function()
            settings.selfMinimized = not settings.selfMinimized
            if selfWnd then
                selfWnd._lastWidth = nil
                selfWnd._lastHeight = nil
                selfWnd._equipY = nil
            end
            saveSettings("saving (SelfCD minimize)")
        end
    })
end

local function updateSelfPanel()
    TargetOverlay.selfCooldowns.Update({
        selfWnd = selfWnd,
        settings = settings,
        panel = SELF_PANEL,
        colors = COLORS,
        scale = function() return uiScaleFactor("selfScaleLevel") end,
        shouldHideSelfPanel = function() return Compat.ShouldHideSelfPanel(compatState) end,
        createIcon = createIcon,
        label = TargetOverlay.uiContext.label,
        setCooldownSkillIcon = setCooldownSkillIcon,
        clearCooldownIcon = clearCooldownIcon,
        setEquipIcon = setEquipIcon,
        shortText = OverlayUtils.shortText,
        buffRemainText = OverlayUtils.buffRemainText,
        allTrackedBuffRows = allTrackedBuffRows,
        allTrackedSkillRows = allTrackedSkillRows,
        trackedBuffKey = trackedBuffKey,
        trackedSkillCooldownKey = trackedSkillCooldownKey,
        buffState = buffState,
        skillCooldowns = skillCooldowns,
        isStarTriggerCooldown = TargetOverlay.isStarTriggerCooldown,
        cooldownRowIcon = TargetOverlay.cooldownRowIcon,
        cooldownDeviceIcon = TargetOverlay.cooldownDeviceIcon,
        trackedGliderMatches = TargetOverlay.trackedGliderMatches,
        trackedMountMatches = TargetOverlay.trackedMountMatches,
        buffIconById = TargetOverlay.buffIconById,
        skillIconById = TargetOverlay.skillIconById,
        equippedSnapshot = TargetOverlay.equippedSnapshot,
        equippedGliderSnapshot = TargetOverlay.equippedGliderSnapshot,
        mountedPetSnapshot = TargetOverlay.mountedPetSnapshot,
        gliderSlot = TargetOverlay.gliderEquipSlot,
        mainhandSlot = function() return EQUIP_SLOT and EQUIP_SLOT.MAINHAND end,
        offhandSlot = function() return EQUIP_SLOT and EQUIP_SLOT.OFFHAND end,
        lastEquipmentUpdate = function() return lastSelfEquipmentUpdate end,
        setLastEquipmentUpdate = function(value) lastSelfEquipmentUpdate = value end
    })
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

local function detectedMountMana()
    for _, unit in ipairs({"playerpet1", "playerpet", "slave", "playerpet2"}) do
        local mana = tonumber(OverlayUtils.safeCall(function() return api.Unit:UnitMana(unit) end)) or 0
        if mana > 0 then
            local info = OverlayUtils.safeCall(function() return api.Unit:UnitInfo(unit) end) or {}
            local name = OverlayUtils.textField(info, {"mate_npc_name", "mateNpcName", "name", "unitName", "unit_name"}) or unit
            return unit .. ":" .. tostring(name or ""), mana
        end
    end
    return nil, 0
end

local function detectedManaDelta()
    local mountKey, mountMana = detectedMountMana()
    local playerMana = tonumber(OverlayUtils.safeCall(function() return api.Unit:UnitMana("player") end)) or 0
    if not detectManaState.init or tostring(mountKey or "") ~= tostring(detectManaState.mountKey or "") then
        detectManaState.init = true
        detectManaState.mountKey = mountKey
        detectManaState.mountMana = mountMana
        detectManaState.playerMana = playerMana
        detectManaState.mountSpent = 0
        detectManaState.playerSpent = 0
    else
        detectManaState.mountSpent = math.max(0, (tonumber(detectManaState.mountMana) or 0) - mountMana)
        detectManaState.playerSpent = math.max(0, (tonumber(detectManaState.playerMana) or 0) - playerMana)
        detectManaState.mountMana = mountMana
        detectManaState.playerMana = playerMana
    end
    return {
        mountKey = mountKey,
        mountSpent = detectManaState.mountSpent,
        playerSpent = detectManaState.playerSpent
    }
end

local function probeSnapshot(eventName)
    local mana = detectedManaDelta()
    return {
        event = eventName,
        mana = mana,
        playerAuras = auraSnapshot("player", 64),
        playerPetAuras = auraSnapshot("playerpet", 64),
        targetAuras = auraSnapshot("target", 32),
        equipment = {
            mainhand = SkillProbe.serialValue(TargetOverlay.equippedSnapshot(EQUIP_SLOT and EQUIP_SLOT.MAINHAND) or {}),
            offhand = SkillProbe.serialValue(TargetOverlay.equippedSnapshot(EQUIP_SLOT and EQUIP_SLOT.OFFHAND) or {}),
            back = SkillProbe.serialValue(TargetOverlay.equippedSnapshot(EQUIP_SLOT and EQUIP_SLOT.BACK) or {}),
            glider = SkillProbe.serialValue(TargetOverlay.equippedSnapshot(TargetOverlay.gliderEquipSlot()) or {})
        }
    }
end

function TargetOverlay.auraLooksLikeUsefulCandidate(aura, source)
    if SkillProbe.auraLooksLikeCooldownSkill(aura) then return true end
    local timeLeft = tonumber(aura and aura.timeLeft)
    if not timeLeft or timeLeft <= 0 or timeLeft > 180000 then return false end
    if source == "Mount/Pet" then return true end
    return aura and aura.icon ~= nil
end

local function detectFromAuraList(list, source, unit, mana)
    for _, aura in ipairs(list or {}) do
        if TargetOverlay.auraLooksLikeUsefulCandidate(aura, source) and recordDetectedSkill then
            recordDetectedSkill(aura.name, aura.id, source, tostring(aura.name or "") .. " " .. tostring(aura.description or ""), {
                kind = "buff",
                unit = unit,
                icon = aura.icon,
                cooldown = aura.cooldown,
                auraKind = aura.kind,
                timeLeft = aura.timeLeft,
                description = aura.description,
                manaSpent = mana and mana.mountSpent or nil,
                playerManaSpent = mana and mana.playerSpent or nil
            })
        end
    end
end

local function detectFromProbeSnapshot(snapshot)
    if settings.skillProbeLogging ~= true or type(snapshot) ~= "table" then return end
    detectFromAuraList(snapshot.playerAuras, "Player", "player", snapshot.mana)
    detectFromAuraList(snapshot.playerPetAuras, "Mount/Pet", "playerpet", snapshot.mana)
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

local function trackedSkillIndex(skillName, skillId)
    local key = SkillProbe.detectedSkillKey(skillName, skillId)
    if not key then return nil end
    for i, row in ipairs(settings.trackedSkills or {}) do
        if SkillProbe.detectedSkillKey(row.name or row.pattern, row.id or row.skillId) == key then return i end
    end
    return nil
end

local function lowerPattern(value)
    value = string.lower(tostring(value or ""))
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

function TargetOverlay.isGenericMountName(value)
    local name = lowerPattern(value)
    return name == "" or name == "mount" or name == "mount/pet" or name == "pet" or name == "playerpet" or name == "unknown" or name == "detected"
end

function TargetOverlay.firstRealMountName(...)
    local values = {...}
    for _, value in ipairs(values) do
        if not TargetOverlay.isGenericMountName(value) then return tostring(value) end
    end
    return nil
end

function TargetOverlay.canonicalGliderDevice(name)
    local text = lowerPattern(name)
    if text:find("sloth", 1, true) then
        return {
            key = "sloth_glider",
            name = "Sloth Glider",
            patterns = {"sloth", "glider companion: sloth", "sloth glider companion", "enhanced sloth glider companion"},
            itemTypes = {30621},
            displayItemType = 8000412
        }
    end
    if text:find("crystal wings", 1, true) then
        return {
            key = "crystal_wings",
            name = "Crystal Wings",
            patterns = {"crystal wings"},
            itemTypes = nil,
            displayItemType = 44649
        }
    end
    if text:find("flamefeather", 1, true) then
        return {
            key = "flamefeather_glider",
            name = "Flamefeather Glider",
            patterns = {
                "flamefeather",
                "flamefeather glider",
                "enhanced flamefeather glider",
                "glider companion: flamefeather",
                "flamefeather glider companion",
                "enhanced flamefeather glider companion"
            },
            itemTypes = nil,
            displayItemType = 8001102
        }
    end
    if text:find("snowflake", 1, true) then
        return {
            key = "snowflake_wings",
            name = "Snowflake Wings",
            patterns = {"snowflake wings", "snowflake"},
            itemTypes = nil
        }
    end
    if text:find("ezi", 1, true) then
        return {
            key = "ezi_glider",
            name = "Ezi Glider",
            patterns = {
                "ezi",
                "ezi's glider",
                "ezi glider",
                "glider companion: ezi",
                "ezi glider companion",
                "enhanced ezi glider",
                "enhanced ezi glider companion"
            },
            itemTypes = {18174, 8000399},
            displayItemType = 8000399
        }
    end
    if text:find("cumulus", 1, true) or text:find("magicopter", 1, true) or text:find("magithopter", 1, true) then
        return {
            key = "cumulus_magithopter",
            name = "Cumulus Magithopter",
            patterns = {"cumulus magicopter", "cumulus magithopter", "magicopter", "magithopter"},
            itemTypes = nil
        }
    end
    if text:find("stormduster", 1, true) or text:find("storm duster", 1, true) then
        return {
            key = "stormduster_1000",
            name = "Stormduster 1000",
            patterns = {
                "stormduster",
                "stormduster 1000",
                "storm duster",
                "enhanced stormduster 1000"
            },
            itemTypes = {
                42736,
                8001544,
                8001545,
                8001546,
                8001547,
                8001548,
                8001549,
                8001550
            },
            displayItemType = 8001544
        }
    end
    local learned = CooldownLearning.Find(settings, "glider", name)
    if learned then return learned end
    return nil
end

function TargetOverlay.canonicalMountDevice(name)
    local text = lowerPattern(name)
    if text:find("meatball", 1, true) then
        return {
            key = "ser_meatball",
            name = "Ser Meatball",
            names = {"Ser Meatball", "Ser Meatball (Vanity)", "Gallant Ser Meatball"},
            itemType = 9000375,
            displayItemType = 9000375
        }
    end
    if text:find("kirin", 1, true) then
        return {
            key = "kirin",
            name = "Kirin",
            names = {"Kirin", "Hellwraith Kirin"},
            itemType = 9001789
        }
    end
    if text:find("rajin", 1, true) or text:find("raijin", 1, true) or text:find("rajani", 1, true) then
        return {
            key = "rajani",
            name = "Raijin",
            names = {"Rajani", "Raijin"},
            itemType = 8000618
        }
    end
    if text:find("stormrose", 1, true) then
        return {
            key = "stormrose",
            name = "Stormrose",
            names = {"Stormrose"},
            itemType = 8001042,
            displayItemType = 8001042
        }
    end
    if text:find("golem", 1, true) or text:find("andelph", 1, true) or text:find("patrol mech", 1, true) then
        return {
            key = "golem",
            name = "Golem",
            names = {"Golem", "Andelph Patrol Mech", "Andelph Mech", "Patrol Mech"},
            itemType = 37136,
            displayItemType = 37136
        }
    end
    if text:find("bouncy cow", 1, true) or text:find("asianbunnyx", 1, true) then
        return {
            key = "bouncy_cow",
            name = "Bouncy Cow",
            names = {"Bouncy Cow", "Asianbunnyx"},
            itemType = 53939,
            displayItemType = 53939,
            icon = "Game\\ui\\icon\\icon_skill_snowman03.dds"
        }
    end
    local learned = CooldownLearning.Find(settings, "mount", name)
    if learned then return learned end
    return nil
end

function TargetOverlay.learnCooldownDevice(recipe)
    return CooldownLearning.Learn(settings, recipe)
end

function TargetOverlay.detectedRecipeRow(row, mode)
    if not row then return nil end
    mode = mode or "aura"
    local recipe = {
        enabled = true,
        userManaged = true,
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
        -- With a concrete buff id, never fall back to name matching: mounts like Raijin
        -- give several DIFFERENT buffs the same display name ("4-Leg Lope" is both the
        -- run buff 8000208 and the dash 8000211), so a name fallback cross-activates
        -- the tracker from the sibling buff. The name stays for display only.
        if tonumber(row.id) then recipe.matchByIdOnly = true end
    end
    if mode == "glider" then
        local glider = TargetOverlay.equippedGliderSnapshot()
        local gliderName = glider.name or row.gliderName or row.source or "Glider"
        local canonical = TargetOverlay.canonicalGliderDevice(gliderName)
        recipe.name = canonical and canonical.name or gliderName
        recipe.source = canonical and canonical.name or gliderName
        recipe.itemType = glider.itemType or row.gliderItemType or (canonical and canonical.itemTypes and canonical.itemTypes[1])
        recipe.itemTypes = canonical and canonical.itemTypes or (recipe.itemType and {recipe.itemType} or nil)
        recipe.recipeDeviceItemType = canonical and canonical.displayItemType or recipe.itemType
        recipe.category = "glider"
        recipe.gliderPattern = canonical and canonical.patterns or {lowerPattern(gliderName)}
        recipe.recipeDeviceName = canonical and canonical.name or gliderName
        recipe.recipeDeviceKey = canonical and canonical.key or ("custom_glider_" .. lowerPattern(gliderName))
        recipe.recipeDeviceKind = "glider"
        recipe.recipeDeviceIcon = row.gliderIcon or (canonical and canonical.icon)
        if not canonical then
            recipe.recipeDeviceIcon = recipe.recipeDeviceIcon or glider.icon
        end
        if TargetOverlay.isStarTriggerCooldown(recipe) then
            recipe.cooldownOnlyOnActive = true
            recipe.triggerMinTimeLeftMs = 5300
        end
    elseif mode == "mount" then
        local mount = TargetOverlay.mountedPetSnapshot()
        local mountName = TargetOverlay.firstRealMountName(mount.name, row.mountName, row.source)
        if not mountName then
            if api.Log and api.Log.Info then api.Log:Info("[Power Ranger ON] Mount name unavailable. Summon/target the mount until its real name is exposed, then add again.") end
            return nil
        end
        local canonical = TargetOverlay.canonicalMountDevice(mountName)
        recipe.name = row.name or (canonical and canonical.name) or mountName
        recipe.source = canonical and canonical.name or mountName
        recipe.category = "mount"
        recipe.preferMountIcon = true
        recipe.mountName = canonical and canonical.name or mountName
        recipe.mountNames = canonical and canonical.names or {mountName}
        recipe.recipeDeviceName = canonical and canonical.name or mountName
        recipe.recipeDeviceKey = canonical and canonical.key or ("custom_mount_" .. lowerPattern(mountName))
        recipe.recipeDeviceKind = "mount"
        recipe.itemType = canonical and canonical.itemType or mount.itemType or row.mountItemType or recipe.itemType
        recipe.recipeDeviceItemType = canonical and (canonical.displayItemType or canonical.itemType) or mount.itemType or row.mountItemType or recipe.itemType
        recipe.recipeDeviceIcon = row.mountIcon or (canonical and canonical.icon)
        if not canonical then
            recipe.recipeDeviceIcon = recipe.recipeDeviceIcon or mount.icon
        end
        recipe.dynamicDisplay = false
        if tonumber(row.manaSpent) and tonumber(row.manaSpent) > 0 then
            recipe.petManaSpent = math.floor(tonumber(row.manaSpent) + 0.5)
        end
        if tonumber(row.playerManaSpent) and tonumber(row.playerManaSpent) > 0 then
            recipe.playerManaSpent = math.floor(tonumber(row.playerManaSpent) + 0.5)
        end
        if tonumber(recipe.id) then
            -- The row has a real aura id: that is the precise trigger (matchByIdOnly is
            -- already set above), exactly like the old catalog defaults tracked mount
            -- buffs. Discard incidentally captured mana deltas -- detected rows often
            -- pick up a stray pet-mana spend from an unrelated action in the same probe
            -- tick, and keeping it would (a) false-start the cooldown from the mana
            -- branch while the buff is down and (b, historical bug) it used to REPLACE
            -- the id entirely, producing an untrackable mana-only recipe.
            recipe.petManaSpent = nil
            recipe.playerManaSpent = nil
        elseif recipe.petManaSpent or recipe.playerManaSpent then
            -- No id at all: a genuine no-buff mount skill (old kirin/meatball style);
            -- the mana spend is the only use-edge. Clear name matchers so the recipe
            -- cannot cross-activate from a same-named aura.
            recipe.buffName = nil
            recipe.buffNames = nil
        end
    end
    return recipe
end

function TargetOverlay.detectedBuffTrackedIndex(row, mode)
    local probe = TargetOverlay.detectedRecipeRow(row, mode or "aura")
    if not probe then return nil end
    local key = trackedBuffSettingKey(probe)
    local probeDevice = lowerPattern(probe.recipeDeviceKey or probe.recipeDeviceName or probe.source or "")
    local probeTriggerId = tonumber(probe.id or probe.buff_id)
    local probeTriggerName = lowerPattern((probe.buffNames and probe.buffNames[1]) or probe.buffName or probe.name or "")
    for i, tracked in ipairs(settings.trackedBuffs or {}) do
        if trackedBuffSettingKey(tracked) == key then return i end
        local trackedDevice = lowerPattern(tracked.recipeDeviceKey or tracked.recipeDeviceName or tracked.source or "")
        local trackedTriggerId = tonumber(tracked.id or tracked.buff_id)
        local trackedTriggerName = lowerPattern((tracked.buffNames and tracked.buffNames[1]) or tracked.buffName or tracked.name or "")
        if probeDevice ~= "" and trackedDevice == probeDevice then
            if probeTriggerId and trackedTriggerId then
                -- Both sides have concrete ids: equal means same ability, different
                -- means DIFFERENT ability even when the display name is identical
                -- (Raijin run 8000208 vs dash 8000211 are both "4-Leg Lope"). Never
                -- fall through to the name comparison in that case, or tracking one
                -- lights up / untracks the other.
                if probeTriggerId == trackedTriggerId then return i end
            elseif probeTriggerName ~= "" and trackedTriggerName ~= "" and probeTriggerName == trackedTriggerName then
                return i
            end
        end
    end
    return nil
end

local function inferSkillSource(skillName, sourceName, flatText)
    local lower = string.lower(tostring(flatText or "") .. " " .. tostring(skillName or "") .. " " .. tostring(sourceName or ""))
    if lower:find("meatball", 1, true) then return "Ser Meatball" end
    if lower:find("kirin", 1, true) then return "Kirin" end
    if lower:find("nui's veil", 1, true) or lower:find("nuis veil", 1, true) then return "Stormrose" end
    if lower:find("golem", 1, true) or lower:find("andelph", 1, true) or lower:find("patrol mech", 1, true) then return "Golem" end
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
        or lower:find("kirin", 1, true) or lower:find("golem", 1, true)
        or lower:find("andelph", 1, true) or lower:find("patrol mech", 1, true) or lower:find("nui", 1, true) then
        return "mount"
    end
    return nil
end

function recordDetectedSkill(skillName, skillId, sourceName, flatText, extra)
    if settings.skillProbeLogging ~= true then return end
    extra = extra or {}
    local glider = TargetOverlay.equippedGliderSnapshot()
    if glider and glider.name then
        extra.gliderName = extra.gliderName or glider.name
        extra.gliderIcon = extra.gliderIcon or glider.icon
        extra.gliderItemType = extra.gliderItemType or glider.itemType
    end
    local mount = TargetOverlay.mountedPetSnapshot()
    if mount and mount.name and not TargetOverlay.isGenericMountName(mount.name) then
        extra.mountName = extra.mountName or mount.name
        extra.mountIcon = extra.mountIcon or mount.icon
        extra.mountItemType = extra.mountItemType or mount.itemType
        extra.mountUnitId = extra.mountUnitId or mount.id
    end
    local name = skillName or SkillProbe.detectFallbackSkillName(flatText) or TargetOverlay.buffNameById(skillId)
    local key = SkillProbe.detectedSkillKey(name, skillId)
    if not key then return end
    settings.detectedSkills = settings.detectedSkills or {}
    local detectedCategory = TargetOverlay.detectedCooldownCategory(name, sourceName, extra.unit, flatText)
    local lowerDetectedName = string.lower(tostring(name or ""))
    local deviceCandidate = detectedCategory == "glider"
        or detectedCategory == "mount"
        or extra.gliderName ~= nil
        or extra.mountName ~= nil
    local recipeCandidate = deviceCandidate or (extra.kind == "buff" and lowerDetectedName:find("star", 1, true) ~= nil)
    if trackedCooldownIsHardcoded(name, skillId) and not recipeCandidate then
        for i = #settings.detectedSkills, 1, -1 do
            if settings.detectedSkills[i].key == key then table.remove(settings.detectedSkills, i) end
        end
        if detectedSkillsWnd and refreshDetectedSkillRows then refreshDetectedSkillRows() end
        if HotSwap and HotSwap.RefreshSettings then HotSwap.RefreshSettings() end
        return
    end
    local found = nil
    for _, row in ipairs(settings.detectedSkills) do
        if row.key == key then found = row break end
    end
    if not found then
        found = { key = key, firstSeen = api.Time:GetUiMsec(), seen = 0, cooldown = TargetOverlay.detectedCooldown(name, skillId, extra.cooldown) }
        table.insert(settings.detectedSkills, 1, found)
        while #settings.detectedSkills > 24 do table.remove(settings.detectedSkills) end
    end
    found.kind = extra.kind or found.kind or "skill"
    found.name = name
    found.id = tonumber(skillId) or found.id
    found.pattern = string.lower(tostring(name or ""))
    found.unit = extra.unit or found.unit
    found.auraKind = extra.auraKind or found.auraKind
    found.timeLeft = extra.timeLeft or found.timeLeft
    found.description = extra.description or found.description
    if tonumber(extra.manaSpent) and tonumber(extra.manaSpent) > 0 then
        found.manaSpent = math.floor(tonumber(extra.manaSpent) + 0.5)
    end
    if tonumber(extra.playerManaSpent) and tonumber(extra.playerManaSpent) > 0 then
        found.playerManaSpent = math.floor(tonumber(extra.playerManaSpent) + 0.5)
    end
    found.category = detectedCategory or found.category
    found.cooldown = TargetOverlay.detectedCooldown(name, skillId, extra.cooldown or found.cooldown)
    found.source = inferSkillSource(name, sourceName, flatText)
    found.icon = extra.icon or found.icon or (found.kind == "buff" and TargetOverlay.buffIconById(found.id) or TargetOverlay.skillIconById(found.id))
    if extra.gliderName then
        found.gliderName = extra.gliderName
        found.gliderIcon = extra.gliderIcon or found.gliderIcon
        found.gliderItemType = extra.gliderItemType or found.gliderItemType
    end
    if extra.mountName then
        found.mountName = extra.mountName
        found.mountIcon = extra.mountIcon or found.mountIcon
        found.mountItemType = extra.mountItemType or found.mountItemType
        found.mountUnitId = extra.mountUnitId or found.mountUnitId
    end
    found.seen = (tonumber(found.seen) or 0) + 1
    found.lastSeen = api.Time:GetUiMsec()
    if detectedSkillsWnd and refreshDetectedSkillRows then refreshDetectedSkillRows() end
    if HotSwap and HotSwap.RefreshSettings then HotSwap.RefreshSettings() end
end

local function startSkillCooldown(row, skillName, skillId)
    local cooldown = tonumber(row.cooldown or row.cooldownSeconds)
    if not cooldown or cooldown <= 0 then return end
    local key = trackedSkillCooldownKey(row, skillName, skillId)
    skillCooldowns[key] = {
        name = row.name or skillName or tostring(skillId),
        id = skillId or row.id or row.skillId,
        icon = TargetOverlay.skillIconById(skillId or row.id or row.skillId) or TargetOverlay.cooldownRowIcon(row),
        readyAt = api.Time:GetUiMsec() + (cooldown * 1000)
    }
end

local function onCombatMessage(targetUnitId, combatEvent, source, target, ...)
    local args = {...}
    TargetOverlay.weaponProc.OnCombatMessage(source, target, args)
    local logging = settings.skillProbeLogging == true
    if not logging and not TargetOverlay.hasEnabledTrackedSkills() then return end
    local result = SkillProbe.parsedCombatMessage(combatEvent, args)
    local skillName, skillId = SkillProbe.extractSkillFields(result, args)
    local row = findTrackedSkill(skillName, skillId)
    if row then startSkillCooldown(row, skillName, skillId) end
    if not logging then return end
    if not playerName then playerName = TargetOverlay.getPlayerName() end
    local sourceName = tostring(source or "")
    local targetName = tostring(target or "")
    local flat = SkillProbe.probeText(result, args, sourceName, targetName, combatEvent)
    local keywordHit = SkillProbe.hasProbeKeyword(flat)
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
            parsed = SkillProbe.serialValue(result),
            args = SkillProbe.serialValue(args)
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
    local skillName, skillId = SkillProbe.extractSkillFields(nil, args)
    local row = findTrackedSkill(skillName, skillId)
    if row then startSkillCooldown(row, skillName, skillId) end
    if not logging then return end
    local flat = SkillProbe.probeText(nil, args, "", "", event)
    local keywordHit = SkillProbe.hasProbeKeyword(flat)
    if skillName or skillId or keywordHit then
        local entry = {
            event = tostring(event or ""),
            skillName = skillName,
            skillId = skillId,
            keywordHit = keywordHit,
            args = SkillProbe.serialValue(args)
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
    local shouldListen = settings and (settings.skillProbeLogging == true
        or TargetOverlay.hasEnabledTrackedSkills()
        or (settings.weaponProcEnabled == true and settings.weaponProcDamageChat == true)) or false
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
    eventWnd = require("power_ranger_on/event_window").Create(onCombatMessage, onSkillEvent)
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

local function cooldownEntryIsGlider(entry)
    local row = entry and entry.row
    return row and (row.gliderPattern ~= nil or row.category == "glider" or row.recipeDeviceKind == "glider")
end

local function cooldownDeviceKey(entry)
    local row = entry and entry.row
    if not row then return "" end
    local kind = cooldownEntryIsGlider(entry) and "glider" or "mount"
    if kind == "mount" and TargetOverlay.canonicalMountDevice then
        local canonical = TargetOverlay.canonicalMountDevice(row.recipeDeviceName or row.mountName or row.mount_name or row.source or row.mount or row.name or "")
        if canonical then return kind .. ":" .. lowerPattern(canonical.key) end
    end
    local name = row.recipeDeviceKey or row.recipeDeviceName or row.mountName or row.mount_name or row.source or row.mount or row.name or row.buffName or row.pattern or tostring(row.id or row.skillId or "")
    return kind .. ":" .. lowerPattern(name)
end

local function cooldownDeviceTitle(entry)
    local row = entry and entry.row
    if not row then return "" end
    if TargetOverlay.canonicalMountDevice then
        local canonical = TargetOverlay.canonicalMountDevice(row.recipeDeviceName or row.mountName or row.mount_name or row.source or row.mount or row.name or "")
        if canonical then return canonical.name end
    end
    return row.recipeDeviceName or row.mountName or row.mount_name or row.source or row.mount or row.name or row.buffName or row.pattern or tostring(row.id or row.skillId or "")
end

local function cooldownDeviceEntries(group)
    local byKey = {}
    local out = {}
    for _, entry in ipairs(cooldownSettingEntries(group)) do
        local key = cooldownDeviceKey(entry)
        if key ~= "" then
            local device = byKey[key]
            if not device then
                device = {
                    key = key,
                    group = group,
                    title = cooldownDeviceTitle(entry),
                    first = entry,
                    refs = {},
                    anyEnabled = false
                }
                byKey[key] = device
                out[#out + 1] = device
            end
            device.refs[#device.refs + 1] = entry
            if entry.row and entry.row.enabled ~= false then device.anyEnabled = true end
        end
    end
    return out
end

local function cooldownSettingIcon(entry)
    local ref = entry and (entry.first or entry)
    local row = ref and ref.row
    if not row then return nil end
    if entry and entry.first then
        local deviceIcon = TargetOverlay.cooldownDeviceIcon(row)
        if deviceIcon then return deviceIcon end
        for _, ref in ipairs(entry.refs or {}) do
            local refIcon = ref and ref.row and TargetOverlay.cooldownDeviceIcon(ref.row)
            if refIcon then return refIcon end
        end
        if row.recipeDeviceKind == "mount" or row.category == "mount" then
            local mount = TargetOverlay.mountedPetSnapshot()
            if TargetOverlay.trackedMountMatches(row, mount) and mount and mount.icon then
                return mount.icon
            end
            return nil
        end
        if row.gliderPattern or row.category == "glider" or row.recipeDeviceKind == "glider" then
            local glider = TargetOverlay.equippedGliderSnapshot()
            if TargetOverlay.trackedGliderMatches(row, glider) and glider and glider.icon then return glider.icon end
        end
        return nil
    end
    if ref.kind == "skill" then return TargetOverlay.skillIconById(row.id or row.skillId) or TargetOverlay.cooldownRowIcon(row) end
    return TargetOverlay.cooldownRowIcon(row) or TargetOverlay.buffIconById(row.id)
end

local function cooldownSettingName(entry)
    local row = entry and entry.row
    if not row then return "" end
    return row.customName or row.name or row.buffName or row.pattern or tostring(row.id or row.skillId or "")
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
    local entries = cooldownDeviceEntries(group)
    local pageSize = #rows
    local total = #entries
    local pages = math.max(1, math.ceil(total / math.max(1, pageSize)))
    local pageKey = cooldownSettingPageKey(group)
    settings[pageKey] = math.max(1, math.min(tonumber(settings[pageKey]) or 1, pages))
    local startIndex = ((settings[pageKey] - 1) * pageSize) + 1
    for i, ui in ipairs(rows) do
        local entry = entries[startIndex + i - 1]
        if entry and entry.first and entry.first.row then
            local enabled = entry.anyEnabled == true
            ui.deviceKey = entry.key
            ui.deviceTitle = entry.title
            ui.abilityRefs = entry.refs
            ui.entryGroup = group
            ui.entryFilteredIndex = startIndex + i - 1
            setEquipIcon(ui.icon, cooldownSettingIcon(entry))
            ui.name:SetText(OverlayUtils.shortText(entry.title, 18))
            ui.source:SetText(tostring(#entry.refs) .. " skills")
            if ui.info then
                ui.info.deviceKey = entry.key
                ui.info.deviceTitle = entry.title
                ui.info.entryGroup = group
            end
            if ui.skills then
                ui.skills.deviceKey = entry.key
                ui.skills.deviceTitle = entry.title
                ui.skills.entryGroup = group
            end
            TargetOverlay.uiContext.setToggleButton(ui.button, enabled, "Show")
            if ui.del then
                local removable = false
                for _, ref in ipairs(entry.refs or {}) do
                    if ref.kind == "skill" or (ref.kind == "buff" and not isDefaultTrackedBuff(ref.row)) then
                        removable = true
                        break
                    end
                end
                ui.del:SetTone(removable and COLORS.danger or {0.08, 0.08, 0.09, 0.95})
            end
            if ui.up then
                local prevEntry = entries[(startIndex + i - 1) - 1]
                ui.up.deviceKey = entry.key
                ui.up.entryGroup = group
                ui.up:SetCleanText("^")
                ui.up:SetTone(prevEntry and COLORS.button or {0.08, 0.08, 0.09, 0.95})
            end
            if ui.down then
                local nextEntry = entries[(startIndex + i - 1) + 1]
                ui.down.deviceKey = entry.key
                ui.down.entryGroup = group
                ui.down:SetCleanText("v")
                ui.down:SetTone(nextEntry and COLORS.button or {0.08, 0.08, 0.09, 0.95})
            end
            ui.root:Show(true)
        else
            ui.deviceKey = nil
            ui.deviceTitle = nil
            ui.abilityRefs = nil
            ui.entryGroup = nil
            ui.entryFilteredIndex = nil
            if ui.info then ui.info.deviceKey = nil end
            if ui.skills then ui.skills.deviceKey = nil end
            if ui.del then ui.del:SetTone({0.08, 0.08, 0.09, 0.95}) end
            if ui.up then
                ui.up.deviceKey = nil
                ui.up.entryGroup = nil
            end
            if ui.down then
                ui.down.deviceKey = nil
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
    if group == "glider" and settingsWnd.cooldownGliderShowAllBtn then
        local allOn = total > 0
        for _, device in ipairs(entries) do
            if not device.anyEnabled then
                allOn = false
                break
            end
        end
        TargetOverlay.uiContext.setToggleButton(settingsWnd.cooldownGliderShowAllBtn, allOn, "Show All")
    end
    if group == "other" and settingsWnd.cooldownOtherShowAllBtn then
        local allOn = total > 0
        for _, device in ipairs(entries) do
            if not device.anyEnabled then
                allOn = false
                break
            end
        end
        TargetOverlay.uiContext.setToggleButton(settingsWnd.cooldownOtherShowAllBtn, allOn, "Show All")
    end
end

local function refreshCooldownSettingRows()
    refreshCooldownSettingGroup("glider", "Gliders")
    refreshCooldownSettingGroup("other", "Mounts/skills")
end

local function toggleCooldownSetting(rowIndex, group)
    local rows = cooldownSettingRowSet(group)
    local ui = rows and rows[rowIndex]
    if not ui or not ui.abilityRefs then return end
    local nextEnabled = true
    for _, ref in ipairs(ui.abilityRefs) do
        if ref.row and ref.row.enabled ~= false then
            nextEnabled = false
            break
        end
    end
    for _, ref in ipairs(ui.abilityRefs) do
        if ref.row then
            ref.row.enabled = nextEnabled
            if nextEnabled then ref.row.dynamicDisplay = false end
            if not nextEnabled then
                if ref.kind == "skill" then
                    clearSkillCooldownForRow(ref.row)
                else
                    buffState[trackedBuffKey(ref.row)] = nil
                end
            end
        end
    end
    TargetOverlay.refreshEventSubscriptions()
    saveSettings()
    refreshSettingsButtons()
end

local function removeCooldownSetting(rowIndex, group)
    local rows = cooldownSettingRowSet(group)
    local ui = rows and rows[rowIndex]
    if not ui then return end
    if ui.abilityRefs then
        local removed = false
        for i = #ui.abilityRefs, 1, -1 do
            local ref = ui.abilityRefs[i]
            if ref.kind == "skill" and settings.trackedSkills and settings.trackedSkills[ref.index] then
                clearSkillCooldownForRow(ref.row)
                table.remove(settings.trackedSkills, ref.index)
                removed = true
            elseif ref.kind == "buff" and settings.trackedBuffs and settings.trackedBuffs[ref.index] and not isDefaultTrackedBuff(ref.row) then
                buffState[trackedBuffKey(ref.row)] = nil
                table.remove(settings.trackedBuffs, ref.index)
                removed = true
            end
        end
        if removed then
            TargetOverlay.refreshEventSubscriptions()
            saveSettings()
            refreshSettingsButtons()
        end
        return
    end
    if not ui.entryKind or not ui.entryIndex then return end
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
    if not ui or not ui.deviceKey then return end
    local entries = cooldownDeviceEntries(group)
    local currentFiltered = tonumber(ui.entryFilteredIndex) or 0
    local targetEntry = entries[currentFiltered + delta]
    if not targetEntry or not targetEntry.key then return end
    local function moveInList(list)
        if not list then return end
        local moving, rest = {}, {}
        for i, row in ipairs(list) do
            local entry = {kind = list == settings.trackedSkills and "skill" or "buff", index = i, row = row}
            if cooldownDeviceKey(entry) == ui.deviceKey then
                moving[#moving + 1] = row
            else
                rest[#rest + 1] = row
            end
        end
        if #moving == 0 then return end
        local rebuilt = {}
        local inserted = false
        for i, row in ipairs(rest) do
            local entry = {kind = list == settings.trackedSkills and "skill" or "buff", index = i, row = row}
            local key = cooldownDeviceKey(entry)
            if not inserted and delta < 0 and key == targetEntry.key then
                for _, movingRow in ipairs(moving) do rebuilt[#rebuilt + 1] = movingRow end
                inserted = true
            end
            rebuilt[#rebuilt + 1] = row
            if not inserted and delta > 0 and key == targetEntry.key then
                for _, movingRow in ipairs(moving) do rebuilt[#rebuilt + 1] = movingRow end
                inserted = true
            end
        end
        if not inserted then
            for _, movingRow in ipairs(moving) do rebuilt[#rebuilt + 1] = movingRow end
        end
        for i = 1, #rebuilt do list[i] = rebuilt[i] end
        for i = #rebuilt + 1, #list do list[i] = nil end
    end
    moveInList(settings.trackedBuffs)
    moveInList(settings.trackedSkills)
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

-- Resolve a clicked visual row slot to the row's CURRENT index in
-- settings.detectedSkills. While probe logging runs, new detections prepend to the
-- list, so the visual index can go stale between render and click -- clicking "Dash"
-- would act on the neighbouring row (e.g. Four-Legged Lope). Resolving through the
-- key stamped at render time targets the row the user actually saw. Returns nil if
-- that row no longer exists (then the click is a no-op instead of hitting a neighbour).
function TargetOverlay.detectedIndexFromVisual(index)
    local ui = detectedSkillsWnd and detectedSkillsWnd.rows and detectedSkillsWnd.rows[index]
    local key = ui and ui.detectedKey
    if not key then return index end
    for i, row in ipairs((settings and settings.detectedSkills) or {}) do
        if row.key == key then return i end
    end
    return nil
end

local function showDetectedDetails(index)
    index = TargetOverlay.detectedIndexFromVisual(index)
    if not index then return end
    TargetOverlay.detectedSkills.ShowDetails({
        window = detectedSkillsWnd,
        settings = settings,
        refreshRows = refreshDetectedSkillRows
    }, index)
end

local function toggleDetectedSkillTracking(index, mode)
    index = TargetOverlay.detectedIndexFromVisual(index)
    if not index then return end
    TargetOverlay.detectedSkills.ToggleTracking({
        settings = settings,
        buffState = buffState,
        trackedBuffKey = trackedBuffKey,
        detectedBuffTrackedIndex = TargetOverlay.detectedBuffTrackedIndex,
        trackedBuffIsDefault = isDefaultTrackedBuff,
        trackedCooldownIsHardcoded = trackedCooldownIsHardcoded,
        detectedRecipeRow = TargetOverlay.detectedRecipeRow,
        learnCooldownDevice = TargetOverlay.learnCooldownDevice,
        canonicalMountDevice = TargetOverlay.canonicalMountDevice,
        canonicalGliderDevice = TargetOverlay.canonicalGliderDevice,
        trackedSkillIndex = trackedSkillIndex,
        clearSkillCooldownForRow = clearSkillCooldownForRow,
        refreshEventSubscriptions = TargetOverlay.refreshEventSubscriptions,
        saveSettings = saveSettings,
        refreshRows = refreshDetectedSkillRows,
        refreshSettingsButtons = refreshSettingsButtons
    }, index, mode)
end

function refreshDetectedSkillRows()
    TargetOverlay.detectedSkills.RefreshRows({
        window = detectedSkillsWnd,
        settings = settings,
        setToggleButton = TargetOverlay.uiContext.setToggleButton,
        detectedBuffTrackedIndex = TargetOverlay.detectedBuffTrackedIndex,
        trackedSkillIndex = trackedSkillIndex,
        setEquipIcon = setEquipIcon,
        buffIconById = TargetOverlay.buffIconById,
        skillIconById = TargetOverlay.skillIconById
    })
end

local function createDetectedSkillsWindow()
    if detectedSkillsWnd then return end
    detectedSkillsWnd = require("power_ranger_on/detected_skills_ui").Create({
        colors = COLORS,
        settings = settings,
        label = TargetOverlay.uiContext.label,
        flatButton = TargetOverlay.uiContext.flatButton,
        panel = TargetOverlay.uiContext.panel,
        createIcon = createIcon,
        applyDrag = applyDrag,
        safePosition = TargetOverlay.safeWindowPosition,
        showDetails = showDetectedDetails,
        toggleTracking = toggleDetectedSkillTracking,
        clearDetected = function()
            settings.detectedSkills = {}
            saveSettings("saving (detected skills cleared)")
            if refreshDetectedSkillRows then refreshDetectedSkillRows() end
        end
    })
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
    TargetOverlay.uiContext.setToggleButton(settingsWnd.compatModeBtn, compat.active, Compat.ModeLabel(compat))
    settingsWnd.compatModeBtn:Show(showNuziOptions)
    TargetOverlay.uiContext.setToggleButton(settingsWnd.modelBtn, settings.showModelOverlay, "Overhead")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.armorBtn, settings.showArmorIcon, "Armor")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.weaponBtn, settings.showWeaponIcon, "Weapon")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.roleBtn, settings.showRoleIcon, "Role")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.modelGsBtn, settings.showModelGearscore, "Gear")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.modelClassBtn, settings.showModelClass, "Class")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.modelRangeBtn, settings.showModelRange, "Range")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.modelDefBtn, settings.showModelDefense, "Defense")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.modelCompactBtn, settings.compactModelOverlay, "Compact")
    if settingsWnd.shadowBtn then
        settingsWnd.shadowBtn:SetCleanText(settings.overlayTextStyle == "outline" and "Text Border" or "Text Shadow")
        settingsWnd.shadowBtn:SetTone(COLORS.active)
    end
    TargetOverlay.uiContext.setToggleButton(settingsWnd.targetWindowBtn, settings.showTargetWindow, "Stats window")
    if settingsWnd.weaponProcBtn then
        TargetOverlay.uiContext.setToggleButton(settingsWnd.weaponProcBtn, settings.weaponProcEnabled == true, "Weapon proc")
        TargetOverlay.uiContext.setToggleButton(settingsWnd.weaponProcPopupBtn, settings.weaponProcReadyPopup ~= false, "Ready popup")
        TargetOverlay.uiContext.setToggleButton(settingsWnd.weaponProcChatBtn, settings.weaponProcDamageChat ~= false, "Hit dmg chat")
    end
    require("power_ranger_on/stats_picker_window").Refresh()
    TargetOverlay.uiContext.setToggleButton(settingsWnd.compactWindowBtn, settings.compactTargetWindow, "Compact")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.testWindowBtn, settings.testTargetWindow, "Compact/Simple")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.ownershipBtn, settings.showOwnershipLabels ~= false, "Ownership")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.guildFamilyLabelBtn, settings.showGuildFamilyLabel == true, "Guild/Fam")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.speedMeterBtn, settings.showSpeedMeter == true, "Speed meter")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.ownOwnersMarkBtn, settings.showOwnOwnersMark == true, "Personal")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.targetOwnersMarkBtn, settings.showTargetOwnersMark ~= false, "Target mark")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.warnOwnersMarkBtn, settings.warnMissingOwnersMark ~= false, "Missing warning")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.selfBtn, settings.showSelfPanel, "Self win")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.selfCdBtn, settings.showSelfCooldowns, "Cooldowns")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.selfEquipmentBtn, settings.showSelfEquipment ~= false, "Equipment")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.selfBorderBtn, settings.showSelfBorder ~= false, "Border")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.nuziImportBtn, settings.importNuziCooldowns ~= false, "Nuzi CDs")
    settingsWnd.nuziImportBtn:Show(showNuziOptions)
    TargetOverlay.uiContext.setToggleButton(settingsWnd.probeLogBtn, settings.skillProbeLogging, "Log")
    local hotSwap = require("power_ranger_on/hot_swap")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.hotSwapEnabledBtn, hotSwap.IsEnabled(), "HotSwap")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.hotSwapFloatBtn, hotSwap.IsFloatShown(), "Float")
    TargetOverlay.uiContext.setToggleButton(settingsWnd.debugLogBtn, settings.debugLogging == true, "Debug")
    if settingsWnd.scaleValue then
        settingsWnd.scaleValue:SetText(tostring(settings.uiScaleLevel or 0))
    end
    if settingsWnd.modelRangeScaleValue then
        settingsWnd.modelRangeScaleValue:SetText(tostring(settings.modelRangeScaleLevel or 0))
    end
    if settingsWnd.modelRangeXValue then
        settingsWnd.modelRangeXValue:SetText(tostring(settings.modelRangeOffsetX or 0))
    end
    if settingsWnd.modelRangeYValue then
        settingsWnd.modelRangeYValue:SetText(tostring(settings.modelRangeOffsetY or 0))
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
    if settingsWnd.selfOpacityValue then
        local opacity = math.max(0, math.min(10, tonumber(settings.selfOpacityLevel) or 8))
        settingsWnd.selfOpacityValue:SetText(string.format("%.2f", opacity / 10))
        if settingsWnd.selfOpacityFill then
            if opacity > 0 then
                settingsWnd.selfOpacityFill:SetExtent(math.max(1, math.floor((opacity / 10) * 310)), 14)
                settingsWnd.selfOpacityFill:Show(true)
            else
                settingsWnd.selfOpacityFill:Show(false)
            end
        end
    end
    if settingsWnd.speedOpacityValue then
        local opacity = math.max(0, math.min(10, tonumber(settings.speedMeterOpacityLevel) or 8))
        settingsWnd.speedOpacityValue:SetText(string.format("%.2f", opacity / 10))
        if settingsWnd.speedOpacityFill then
            if opacity > 0 then
                settingsWnd.speedOpacityFill:SetExtent(math.max(1, math.floor((opacity / 10) * 148)), 14)
                settingsWnd.speedOpacityFill:Show(true)
            else
                settingsWnd.speedOpacityFill:Show(false)
            end
        end
    end
    if settingsWnd.ownershipScaleValue then
        settingsWnd.ownershipScaleValue:SetText(tostring(settings.ownershipScaleLevel or 0))
    end
    if settingsWnd.guildFamilyScaleValue then
        settingsWnd.guildFamilyScaleValue:SetText(tostring(settings.guildFamilyLabelScaleLevel or 0))
    end
    refreshCooldownSettingRows()
    if settingsWnd.fieldButtons then
        for _, field in ipairs(TARGET_INFO_FIELDS) do
            local btn = settingsWnd.fieldButtons[field.key]
            if btn then TargetOverlay.uiContext.setToggleButton(btn, settings[field.setting] ~= false, field.label) end
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

function TargetOverlay.cycleOverlayTextStyle()
    settings.overlayTextStyle = settings.overlayTextStyle == "outline" and "shadow" or "outline"
    settings.overlayTextShadow = settings.overlayTextStyle == "shadow"
    if mainCanvas then mainCanvas._layoutTextStyle = nil end
    TargetOverlay.applyTextShadow()
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
    if key == "overlayTextShadow" then
        settings.overlayTextStyle = settings.overlayTextShadow and "shadow" or "outline"
        if mainCanvas then mainCanvas._layoutTextStyle = nil end
        TargetOverlay.applyTextShadow()
    end
    if key == "showOwnershipLabels" and settings.showOwnershipLabels == false then hideOwnershipWindow() end
    if key == "showGuildFamilyLabel" and settings.showGuildFamilyLabel ~= true then hideGuildFamilyWindow() end
    if key == "showSpeedMeter" then TargetOverlay.travelSpeed.Refresh() end
    if key == "showOwnOwnersMark" or key == "showTargetOwnersMark" or key == "warnMissingOwnersMark" then
        TargetOverlay.ownersMark.Refresh()
    end
    if key == "importNuziCooldowns" then
        refreshNuziCooldownRows(true)
        TargetOverlay.refreshEventSubscriptions()
    end
    if key == "weaponProcEnabled" or key == "weaponProcReadyPopup" or key == "weaponProcDamageChat" then
        TargetOverlay.weaponProc.Refresh()
        TargetOverlay.refreshEventSubscriptions()
    end
    saveSettings()
    refreshSettingsButtons()
    if key == "showSelfEquipment" or key == "showSelfCooldowns" or key == "showSelfPanel" or key == "showSelfBorder" then updateSelfPanel() end
end

function TargetOverlay.shiftSelfOpacity(delta)
    local level = (tonumber(settings.selfOpacityLevel) or 8) + (tonumber(delta) or 0)
    if level < 0 then level = 0 end
    if level > 10 then level = 10 end
    settings.selfOpacityLevel = level
    saveSettings()
    refreshSettingsButtons()
    updateSelfPanel()
end

function TargetOverlay.shiftSpeedOpacity(delta)
    local level = (tonumber(settings.speedMeterOpacityLevel) or 8) + (tonumber(delta) or 0)
    if level < 0 then level = 0 end
    if level > 10 then level = 10 end
    settings.speedMeterOpacityLevel = level
    saveSettings()
    refreshSettingsButtons()
    TargetOverlay.travelSpeed.Refresh()
end

function TargetOverlay.setSpeedOpacityFromMouse()
    if not settingsWnd then return end
    local okPos, mx = pcall(function() return api.Input:GetMousePos() end)
    if not okPos or not mx then return end
    local windowX = tonumber(settings.settingsX) or 650
    local currentX = TargetOverlay.windowHelpers.Position(settingsWnd)
    if tonumber(currentX) then windowX = tonumber(currentX) end
    local trackLeft = windowX + 18 + 296
    local frac = (tonumber(mx) - trackLeft) / 150
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    settings.speedMeterOpacityLevel = math.floor((frac * 10) + 0.5)
    saveSettings()
    refreshSettingsButtons()
    TargetOverlay.travelSpeed.Refresh()
end

function TargetOverlay.toggleCooldownGroup(group)
    local entries = cooldownDeviceEntries(group)
    if #entries == 0 then return end
    local nextEnabled = false
    for _, entry in ipairs(entries) do
        if not entry.anyEnabled then
            nextEnabled = true
            break
        end
    end
    for _, entry in ipairs(entries) do
        for _, ref in ipairs(entry.refs or {}) do
            if ref.row then
                ref.row.enabled = nextEnabled
                if nextEnabled then ref.row.dynamicDisplay = false end
                if not nextEnabled then
                    if ref.kind == "skill" then
                        clearSkillCooldownForRow(ref.row)
                    else
                        buffState[trackedBuffKey(ref.row)] = nil
                    end
                end
            end
        end
    end
    TargetOverlay.refreshEventSubscriptions()
    saveSettings()
    refreshSettingsButtons()
    updateSelfPanel()
end

function TargetOverlay.setSelfOpacityFromMouse()
    if not settingsWnd then return end
    local okPos, mx = pcall(function() return api.Input:GetMousePos() end)
    if not okPos or not mx then return end
    local windowX = tonumber(settings.settingsX) or 650
    local trackLeft = windowX + 18 + 78
    local frac = (tonumber(mx) - trackLeft) / 312
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    settings.selfOpacityLevel = math.floor((frac * 10) + 0.5)
    saveSettings()
    refreshSettingsButtons()
    updateSelfPanel()
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

function TargetOverlay.shiftModelRangeOffset(axis, delta)
    local key = axis == "y" and "modelRangeOffsetY" or "modelRangeOffsetX"
    settings[key] = math.max(-120, math.min(120, (tonumber(settings[key]) or 0) + delta))
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
    if settingsWnd and settingsWnd.modelRangeScaleValue then
        settingsWnd.modelRangeScaleValue:SetText(tostring(settings.modelRangeScaleLevel or 0))
    end
    if settingsWnd and settingsWnd.modelRangeXValue then
        settingsWnd.modelRangeXValue:SetText(tostring(settings.modelRangeOffsetX or 0))
    end
    if settingsWnd and settingsWnd.modelRangeYValue then
        settingsWnd.modelRangeYValue:SetText(tostring(settings.modelRangeOffsetY or 0))
    end
    if settingsWnd and settingsWnd.intelScaleValue then
        settingsWnd.intelScaleValue:SetText(tostring(settings.targetWindowScaleLevel or 0))
    end
    if settingsWnd and settingsWnd.selfScaleValue then
        settingsWnd.selfScaleValue:SetText(tostring(settings.selfScaleLevel or 0))
    end
    if settingsWnd and settingsWnd.selfOpacityValue then
        local opacity = math.max(0, math.min(10, tonumber(settings.selfOpacityLevel) or 8))
        settingsWnd.selfOpacityValue:SetText(string.format("%.2f", opacity / 10))
    end
    if settingsWnd and settingsWnd.ownershipScaleValue then
        settingsWnd.ownershipScaleValue:SetText(tostring(settings.ownershipScaleLevel or 0))
    end
    if settingsWnd and settingsWnd.guildFamilyScaleValue then
        settingsWnd.guildFamilyScaleValue:SetText(tostring(settings.guildFamilyLabelScaleLevel or 0))
    end
    if ownershipWnd then
        ownershipWnd._lastWidth = nil
        ownershipWnd._lastHeight = nil
    end
    if guildFamilyWnd then
        guildFamilyWnd._lastWidth = nil
        guildFamilyWnd._lastHeight = nil
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
    local settingsUi = require("power_ranger_on/settings_ui")
    local settingsSections = require("power_ranger_on/settings_sections")
    settingsWnd = settingsUi.CreateShell({
        id = "PowerRangerSettings",
        title = "Power Ranger ON",
        width = 620,
        height = 1060,
        x = settings.settingsX,
        y = settings.settingsY,
        xKey = "settingsX",
        yKey = "settingsY",
        colors = COLORS,
        safePosition = TargetOverlay.safeWindowPosition,
        applyDrag = applyDrag,
        compatButtonId = "power_ranger_compat_mode",
        onCompat = cycleCompatMode,
        closeButtonId = "power_ranger_close",
        onClose = function() settingsWnd:Show(false) end
    })

    settingsSections.BuildTargetOverhead(settingsWnd, {
        colors = COLORS,
        sectionPanel = TargetOverlay.uiContext.sectionPanel,
        label = TargetOverlay.uiContext.label,
        flatButton = TargetOverlay.uiContext.flatButton,
        colorCube = TargetOverlay.uiContext.colorCube,
        toggleSetting = toggleSetting,
        shiftUiScale = shiftUiScale,
        shiftCompactModelLeft = TargetOverlay.shiftCompactModelLeft,
        shiftModelRangeOffset = TargetOverlay.shiftModelRangeOffset,
        cycleOverlayTextStyle = TargetOverlay.cycleOverlayTextStyle
    })

    settingsSections.BuildIntelWindow(settingsWnd, {
        colors = COLORS,
        sectionPanel = TargetOverlay.uiContext.sectionPanel,
        label = TargetOverlay.uiContext.label,
        flatButton = TargetOverlay.uiContext.flatButton,
        colorCube = TargetOverlay.uiContext.colorCube,
        toggleSetting = toggleSetting,
        shiftUiScale = shiftUiScale,
        shiftGuildFamilyScale = shiftUiScale,
        shiftSimpleSpacing = TargetOverlay.shiftSimpleSpacing,
        fields = TARGET_INFO_FIELDS,
        openStatsPicker = function() TargetOverlay.openStatsPickerWindow() end
    })

    settingsSections.BuildSelfCooldowns(settingsWnd, {
        colors = COLORS,
        sectionPanel = TargetOverlay.uiContext.sectionPanel,
        label = TargetOverlay.uiContext.label,
        flatButton = TargetOverlay.uiContext.flatButton,
        createIcon = createIcon,
        cooldownEdit = cooldownEdit,
        toggleSetting = toggleSetting,
        shiftUiScale = shiftUiScale,
        shiftSelfOpacity = function(delta) TargetOverlay.shiftSelfOpacity(delta) end,
        setSelfOpacityFromMouse = function() TargetOverlay.setSelfOpacityFromMouse() end,
        toggleProbeLogging = toggleProbeLogging,
        openDetectedSkillsWindow = openDetectedSkillsWindow,
        openCooldownSkillsWindow = function(rowIndex, group, mode) TargetOverlay.openCooldownSkillsWindow(rowIndex, group, mode) end,
        openCooldownManagerWindow = function(group) TargetOverlay.openCooldownManagerWindow(group) end,
        shiftCooldownSettingsPage = shiftCooldownSettingsPage,
        moveCooldownSetting = moveCooldownSetting,
        toggleCooldownSetting = toggleCooldownSetting,
        toggleCooldownGroup = function(group) TargetOverlay.toggleCooldownGroup(group) end,
        removeCooldownSetting = removeCooldownSetting
    })
    settingsSections.BuildHotSwapLauncher(settingsWnd, {
        colors = COLORS,
        sectionPanel = TargetOverlay.uiContext.sectionPanel,
        label = TargetOverlay.uiContext.label,
        flatButton = TargetOverlay.uiContext.flatButton,
        toggleSetting = toggleSetting,
        refreshSettingsButtons = refreshSettingsButtons
    }, 878)
    settingsSections.BuildTravelTools(settingsWnd, {
        colors = COLORS,
        sectionPanel = TargetOverlay.uiContext.sectionPanel,
        label = TargetOverlay.uiContext.label,
        flatButton = TargetOverlay.uiContext.flatButton,
        toggleSetting = toggleSetting,
        shiftUiScale = shiftUiScale,
        shiftSpeedOpacity = TargetOverlay.shiftSpeedOpacity,
        setSpeedOpacityFromMouse = TargetOverlay.setSpeedOpacityFromMouse
    }, 732)
    settingsSections.BuildWeaponProc(settingsWnd, {
        colors = COLORS,
        sectionPanel = TargetOverlay.uiContext.sectionPanel,
        label = TargetOverlay.uiContext.label,
        flatButton = TargetOverlay.uiContext.flatButton,
        toggleSetting = toggleSetting
    }, 968)

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

function TargetOverlay.removeCooldownSkillEntry(kind, index)
    if kind == "skill" then
        local row = settings.trackedSkills and settings.trackedSkills[index]
        if not row then return end
        clearSkillCooldownForRow(row)
        table.remove(settings.trackedSkills, index)
    else
        local row = settings.trackedBuffs and settings.trackedBuffs[index]
        if not row then return end
        if isDefaultTrackedBuff(row) then
            markCooldownDefaultRemoved(row)
        end
        buffState[trackedBuffKey(row)] = nil
        table.remove(settings.trackedBuffs, index)
    end
    TargetOverlay.refreshEventSubscriptions()
    saveSettings()
    refreshSettingsButtons()
    updateSelfPanel()
end

function TargetOverlay.openCooldownSkillsWindow(rowIndex, group, mode)
    local deviceKey = nil
    local deviceTitle = nil
    if rowIndex and group then
        local rows = cooldownSettingRowSet(group)
        local ui = rows and rows[rowIndex]
        deviceKey = ui and ui.deviceKey or nil
        deviceTitle = ui and ui.deviceTitle or nil
    end
    require("power_ranger_on/cooldown_skills_window").Open({
        colors = COLORS,
        settings = settings,
        deviceKey = deviceKey,
        deviceTitle = deviceTitle,
        mode = mode,
        deviceKeyForEntry = cooldownDeviceKey,
        safePosition = TargetOverlay.safeWindowPosition,
        applyDrag = applyDrag,
        createIcon = createIcon,
        cooldownEdit = cooldownEdit,
        setEquipIcon = setEquipIcon,
        cooldownRowIcon = TargetOverlay.cooldownRowIcon,
        skillIconById = TargetOverlay.skillIconById,
        buffIconById = TargetOverlay.buffIconById,
        removeSkill = TargetOverlay.removeCooldownSkillEntry,
        save = saveSettings,
        refresh = function()
            refreshSettingsButtons()
            updateSelfPanel()
        end
    })
end

function TargetOverlay.openStatsPickerWindow()
    require("power_ranger_on/stats_picker_window").Open({
        colors = COLORS,
        settings = settings,
        label = TargetOverlay.uiContext.label,
        flatButton = TargetOverlay.uiContext.flatButton,
        safePosition = TargetOverlay.safeWindowPosition,
        applyDrag = applyDrag,
        cycleColor = cycleSettingColor,
        settingColor = settingColor,
        save = saveSettings,
        refresh = refreshSettingsButtons
    })
end

function TargetOverlay.openCooldownManagerWindow(group)
    require("power_ranger_on/cooldown_manager_window").Open({
        colors = COLORS,
        owner = settingsWnd,
        settings = settings,
        label = TargetOverlay.uiContext.label,
        flatButton = TargetOverlay.uiContext.flatButton,
        createIcon = createIcon,
        setEquipIcon = setEquipIcon,
        safePosition = TargetOverlay.safeWindowPosition,
        applyDrag = applyDrag,
        openCooldownSkillsWindow = function(rowIndex, entryGroup, mode) TargetOverlay.openCooldownSkillsWindow(rowIndex, entryGroup, mode) end,
        shiftCooldownSettingsPage = shiftCooldownSettingsPage,
        moveCooldownSetting = moveCooldownSetting,
        toggleCooldownSetting = toggleCooldownSetting,
        toggleCooldownGroup = function(entryGroup) TargetOverlay.toggleCooldownGroup(entryGroup) end,
        removeCooldownSetting = removeCooldownSetting,
        refreshSettingsButtons = refreshSettingsButtons
    }, group)
end

function TargetOverlay.init()
    loadSettings()
    playerName = TargetOverlay.getPlayerName()

    local widgets = require("power_ranger_on/target_windows").CreateModelOverlay({
        colors = COLORS,
        config = CONFIG,
        label = TargetOverlay.uiContext.label,
        applyReadableTextStyle = TargetOverlay.applyReadableTextStyle
    })
    mainCanvas = widgets.canvas
    armorBuffIcon = widgets.armorBuffIcon
    weaponBuffIcon = widgets.weaponBuffIcon
    targetPdefTitleLabel = widgets.targetPdefTitleLabel
    targetPdefValueLabel = widgets.targetPdefValueLabel
    targetMdefTitleLabel = widgets.targetMdefTitleLabel
    targetMdefValueLabel = widgets.targetMdefValueLabel
    targetRoleIcon = widgets.targetRoleIcon
    targetGearscoreLabel = widgets.targetGearscoreLabel
    targetClassLabel = widgets.targetClassLabel
    targetRangeCanvas = widgets.targetRangeCanvas
    targetRangeLabel = widgets.targetRangeLabel

    createTargetInfoWindow()
    createOwnershipWindow()
    createGuildFamilyWindow()
    createSelfWindow()
    createSettingsWindow()
    createEventWindow()
    TargetOverlay.travelSpeed.Init(settings, saveSettings, applyHandleDrag)
    TargetOverlay.ownersMark.Init(settings, applyHandleDrag)
    TargetOverlay.weaponProc.Init(settings, applyHandleDrag)
    api.On("POWER_RANGER_SS_MODE", onStumpySenseLayout)
    if not stumpyDockHooksRegistered then
        api.On("STUMPY_DOCK_WHO", registerStumpyDockMember)
        stumpyDockHooksRegistered = true
    end
    registerStumpyDockMember()
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
    TargetOverlay.clearStumpyStatsBox()
    lastScreenPosition = ""
    modelDataTargetId = nil
    targetInfoMisses = 0
    screenPositionMisses = 0
end

local function applyModelLayout()
    local scale = uiScaleFactor()
    local textStyle = settings.overlayTextStyle or "shadow"
    local armorEnabled = settings.showArmorIcon ~= false
    local weaponEnabled = settings.showWeaponIcon ~= false
    if not mainCanvas
        or (mainCanvas._compactLayout == settings.compactModelOverlay
            and mainCanvas._layoutScale == scale
            and mainCanvas._layoutTextStyle == textStyle
            and mainCanvas._layoutArmorEnabled == armorEnabled
            and mainCanvas._layoutWeaponEnabled == weaponEnabled) then return end
    mainCanvas._compactLayout = settings.compactModelOverlay
    mainCanvas._layoutScale = scale
    mainCanvas._layoutTextStyle = textStyle
    mainCanvas._layoutArmorEnabled = armorEnabled
    mainCanvas._layoutWeaponEnabled = weaponEnabled
    local buffSize = math.floor((CONFIG.buffIconSize * scale) + 0.5)
    armorBuffIcon:SetExtent(buffSize, buffSize)
    weaponBuffIcon:SetExtent(buffSize, buffSize)
    targetRoleIcon:SetExtent(math.floor((CONFIG.roleIconSize * scale) + 0.5), math.floor((CONFIG.roleIconSize * scale) + 0.5))
    targetGearscoreLabel:SetExtent(math.floor((90 * scale) + 0.5), math.floor(((CONFIG.fontSize + 7) * scale) + 0.5))
    targetClassLabel:SetExtent(math.floor((180 * scale) + 0.5), math.floor((16 * scale) + 0.5))
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
        local outlineOffset = TargetOverlay.useOutlineText() and math.floor((4 * scale) + 0.5) or 0
        local compactTextRight = leftOffset - outlineOffset
        targetGearscoreLabel.style:SetAlign(ALIGN.RIGHT)
        targetClassLabel.style:SetAlign(ALIGN.RIGHT)
        armorBuffIcon:AddAnchor("RIGHT", mainCanvas, "LEFT", leftOffset, 0)
        if armorEnabled then
            weaponBuffIcon:AddAnchor("RIGHT", armorBuffIcon, "LEFT", -compactIconGap, 0)
        else
            weaponBuffIcon:AddAnchor("RIGHT", mainCanvas, "LEFT", leftOffset, 0)
        end
        targetGearscoreLabel:SetHeight(math.floor(((CONFIG.fontSize + 7) * scale) + 0.5))
        targetGearscoreLabel.style:SetFontSize(math.floor(((CONFIG.fontSize + 3) * scale) + 0.5))
        targetGearscoreLabel:AddAnchor("BOTTOMRIGHT", mainCanvas, "LEFT", compactTextRight, math.floor((-16 * scale) + 0.5))
        targetClassLabel:AddAnchor("TOPRIGHT", mainCanvas, "LEFT", compactTextRight, math.floor((16 * scale) + 0.5))
    else
        targetGearscoreLabel.style:SetAlign(ALIGN.CENTER)
        targetClassLabel.style:SetAlign(ALIGN.CENTER)
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
    local rangeScale = scale * uiScaleFactor("modelRangeScaleLevel")
    targetRangeCanvas:SetExtent(math.floor((86 * rangeScale) + 0.5), math.floor(((CONFIG.fontSize + 6) * rangeScale) + 0.5))
    targetRangeLabel:SetExtent(math.floor((86 * rangeScale) + 0.5), math.floor(((CONFIG.fontSize + 6) * rangeScale) + 0.5))
    targetRangeLabel.style:SetFontSize(math.floor((CONFIG.fontSize * rangeScale) + 0.5))
    setModelLabel(targetRangeLabel, string.format("%.1fm", dist))
    setTextColor(targetRangeLabel, settingColor("modelRange"))
    local offsetX = math.floor(((tonumber(settings.modelRangeOffsetX) or 0) * scale) + 0.5)
    local offsetY = math.floor(((tonumber(settings.modelRangeOffsetY) or 0) * scale) + 0.5)
    targetRangeCanvas:AddAnchor("BOTTOM", "UIParent", "TOPLEFT", sX + offsetX, sY - math.floor((44 * scale) + 0.5) + offsetY)
    targetRangeCanvas:Show(true)
end

function TargetOverlay.update(dt)
    local elapsed = dt or 0
    TargetOverlay.travelSpeed.Update(elapsed)
    TargetOverlay.ownersMark.Update(elapsed)
    TargetOverlay.weaponProc.Update(elapsed)
    updateElapsed = updateElapsed + elapsed
    selfUpdateElapsed = selfUpdateElapsed + elapsed
    TargetOverlay.cooldownRuntimeElapsed = (TargetOverlay.cooldownRuntimeElapsed or SELF_UPDATE_MS) + elapsed
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
    if TargetOverlay.cooldownRuntimeElapsed >= 25 then
        TargetOverlay.cooldownRuntimeElapsed = math.min(TargetOverlay.cooldownRuntimeElapsed - 25, 25)
        updateTrackedBuffs()
    end
    local doSelfUpdate = selfUpdateElapsed >= SELF_UPDATE_MS
    if doSelfUpdate then
        selfUpdateElapsed = math.min(selfUpdateElapsed - SELF_UPDATE_MS, SELF_UPDATE_MS)
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
        hideGuildFamilyWindow()
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
            hideGuildFamilyWindow()
            return
        end
        targetTokenMisses = targetTokenMisses + 1
        if targetTokenMisses >= 3 then
            hideModelOverlay()
            hideOwnershipWindow()
            hideGuildFamilyWindow()
            previousTargetId = nil
        end
        return
    end
    targetTokenMisses = 0
    if targetId ~= previousTargetId then
        hideModelOverlay()
        hideOwnershipWindow()
        hideGuildFamilyWindow()
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
        hideGuildFamilyWindow()
        return
    end

    local className = TargetOverlay.getClassName(usableInfo) or "Unknown"
    local pdef, mdef, pdefPct, mdefPct = TargetOverlay.fillDefense(nil, nil, nil, nil, tokenInfo)
    pdef, mdef, pdefPct, mdefPct = TargetOverlay.fillDefense(pdef, mdef, pdefPct, mdefPct, targetInfo or usableInfo)
    local needsExtraStats = ClassIntelProfiles.NeedsExtraStats(settings)
    local needsCatalogStats = TargetOverlay.statsCatalog.AnyEnabled(settings)
    local modifierInfo = nil
    if needsExtraStats or needsCatalogStats or not pdef or not mdef or not pdefPct or not mdefPct then
        modifierInfo = OverlayUtils.safeCall(function() return api.Unit:UnitModifierInfo("target") end)
        if modifierInfo then
            pdef, mdef, pdefPct, mdefPct = TargetOverlay.fillDefense(pdef, mdef, pdefPct, mdefPct, modifierInfo)
        end
    end
    local extraStats = needsExtraStats and TargetOverlay.targetExtraStats(tokenInfo, targetInfo or usableInfo, modifierInfo) or {}
    if needsCatalogStats then
        extraStats.catalogInfos = { tokenInfo or {}, targetInfo or usableInfo or {}, modifierInfo or {} }
    end
    if isPlayer then
        refreshTargetInfoWindow(usableInfo, className, gearscore, pdef, mdef, pdefPct, mdefPct, extraStats)
        refreshGuildFamilyWindow(usableInfo)
    elseif targetInfoWnd then
        targetInfoWnd:Show(false)
        TargetOverlay.clearStumpyStatsBox()
        hideGuildFamilyWindow()
    end

    if not isPlayer then
        hideModelOverlay()
        hideGuildFamilyWindow()
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
        setTextColor(targetGearscoreLabel, settingColor("modelGearscore"))
    else
        hideModelLabel(targetGearscoreLabel)
    end

    if showTargetText and settings.showModelClass then
        setModelLabel(targetClassLabel, className)
        setTextColor(targetClassLabel, settingColor("modelClass"))
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
    stumpySenseLayout.enabled = false
    if eventWnd then
        pcall(function() eventWnd:UnregisterEvent("COMBAT_MSG") end)
        pcall(function() eventWnd:UnregisterEvent("SPELLCAST_START") end)
        pcall(function() eventWnd:UnregisterEvent("SPELLCAST_SUCCEEDED") end)
        pcall(function() eventWnd:UnregisterEvent("SPELLCAST_STOP") end)
        eventWnd:SetHandler("OnEvent", function() end)
        eventWnd:Show(false)
    end
    saveSkillProbe()
    if mainCanvas then mainCanvas:Show(false) end
    if targetRangeCanvas then targetRangeCanvas:Show(false) end
    if targetInfoWnd then targetInfoWnd:Show(false) end
    if ownershipWnd then ownershipWnd:Show(false) end
    if guildFamilyWnd then guildFamilyWnd:Show(false) end
    TargetOverlay.travelSpeed.Cleanup()
    TargetOverlay.ownersMark.Cleanup()
    TargetOverlay.weaponProc.Cleanup()
    require("power_ranger_on/stats_picker_window").Cleanup()
    unregisterStumpyDockMember()
    if selfWnd then selfWnd:Show(false) end
    if settingsWnd then settingsWnd:Show(false) end
    if detectedSkillsWnd then detectedSkillsWnd:Show(false) end
    pcall(function() require("power_ranger_on/cooldown_manager_window").Cleanup() end)
    mainCanvas = nil
    targetInfoWnd = nil
    ownershipWnd = nil
    guildFamilyWnd = nil
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
    TargetOverlay.cooldownRuntimeElapsed = 25
    nuziCooldownRows = NuziCooldownImport.EmptyRows()
    NuziCooldownImport.Reset()
    buffState = {}
    triggerState = {}
    TargetOverlay.resourceLookup.Clear()
    skillCooldowns = {}
    skillProbe = { entries = {}, maxEntries = 240 }
    skillProbeDirty = false
    lastSkillProbeSave = 0
    probeLogElapsed = 0
    lastSelfEquipmentUpdate = 0
    playerName = nil
end

return TargetOverlay
