local api = require("api")
local UiHelpers = require("power_ranger_on/ui_helpers")
local HotSwapAuras = require("power_ranger_on/hot_swap_auras")
local SettingsSanitizer = require("power_ranger_on/settings_sanitizer")

local HotSwap = {}

local ADDON_ID = "power_ranger_on"
local LEGACY_ADDON_ID = "hot_swap"
local QUEUE_DELAY_MS = 250
local TITLE_RETRY_DELAY_MS = 250
local TITLE_RETRY_COUNT = 3
local AUTO_CHECK_MS = 150
-- The WakeUp ("Good day to work") rested buff lingers ~30 min, so on beds where the sleep
-- buff briefly drops while you're still lying down it would flip sleep -> wakeup. Only fire
-- WakeUp once the sleep buff has been gone for this long, so flickers / a quick second sleep
-- never steal the swap. ~3s at a 150ms check cadence.
local WAKEUP_GRACE_MS = 3000
local EQUIP_VERIFY_DELAY_MS = 700
local BAG_SLOT_COUNT = 150
local SWIMMING_BLOCKED_ZONE_HINTS = {"growlgate", "freedich"}

local MAIN = {
    width = 160,
    headerH = 24,
    rowH = 24,
    rowStep = 28,
    left = 8,
    pad = 6,
    defaultX = 100,
    defaultY = 100
}

local SETTINGS = {
    width = 620,
    height = 830,
    contentX = 14,
    contentW = 592,
    fieldW = 250,
    actionX = 438,
    actionW = 118,
    defaultX = 500,
    defaultY = 180,
    pageSize = 5,
    customPageSize = 2,
    detectedPageSize = 3
}

local SLOT_DEFS = {
    {key = "head", api_key = "HEAD", label = "Head", slot = 1},
    {key = "chest", api_key = "CHEST", label = "Chest", slot = 3},
    {key = "waist", api_key = "WAIST", label = "Waist", slot = 4},
    {key = "arms", api_key = "ARMS", label = "Wrist", slot = 8},
    {key = "hands", api_key = "HANDS", label = "Hands", slot = 6},
    {key = "back", api_key = "BACK", label = "Cloak", slot = 9},
    {key = "legs", api_key = "LEGS", label = "Pants", slot = 5},
    {key = "feet", api_key = "FEET", label = "Boots", slot = 7},
    {key = "undershirt", api_key = "UNDERPANTS", label = "Under", slot = 15},
    {key = "cosplay", api_key = "COSPLAY", label = "Costume", slot = 0},
    {key = "backpack", api_key = "BACKPACK", label = "Glider", slot = 28},
    {key = "neck", api_key = "NECK", label = "Neck", slot = 2},
    {key = "ear1", api_key = "EAR_1", label = "Ear 1", slot = 10},
    {key = "ear2", api_key = "EAR_2", label = "Ear 2", slot = 11, is_aux = true},
    {key = "finger1", api_key = "FINGER_1", label = "Ring 1", slot = 12},
    {key = "finger2", api_key = "FINGER_2", label = "Ring 2", slot = 13, is_aux = true},
    {key = "mainhand", api_key = "MAINHAND", label = "Main", slot = 16},
    {key = "offhand", api_key = "OFFHAND", label = "Off", slot = 17, is_aux = true},
    {key = "ranged", api_key = "RANGED", label = "Bow", slot = 18},
    {key = "musical", api_key = "MUSICAL", label = "Music", slot = 19}
}

local COLORS = {
    dark = {0.06, 0.06, 0.068, 0.96},
    panel = {0.045, 0.045, 0.052, 0.82},
    header = {0.06, 0.075, 0.095, 0.76},
    settingsHeader = {0.09, 0.09, 0.11, 0.98},
    button = {0.14, 0.14, 0.16, 0.95},
    active = {0.12, 0.28, 0.15, 0.95},
    danger = {0.24, 0.09, 0.09, 0.95},
    blue = {0.10, 0.18, 0.30, 0.95},
    gold = {1, 0.84, 0, 1},
    green = {0.38, 0.95, 0.44, 1},
    white = {1, 1, 1, 1},
    muted = {0.68, 0.70, 0.74, 1}
}

local rootSettings
local settings
local canvas
local settingsWnd
local settingsShown = false
local buttons = {}
local gearQueue = {}
local pendingTitle = nil
local titleDelay = 0
local titleAttempts = 0
local queueDelay = 0
local pendingCheck = nil
local pendingCheckDelay = 0
local autoElapsed = 0
local autoActiveKey = nil
-- Milliseconds since the sleep buff was last seen (starts "long ago" so WakeUp works at login).
local sleepClearMs = WAKEUP_GRACE_MS
local autoZoneMs = 1000
local autoZoneName = ""
local selectedSetIndex = nil
local selectedCustomIndex = nil
local gearViewWnd = nil
local customPage = 1
local detectedPage = 1
local selectedLoadout
local createSettingsWindow
local persistSettings
local accountRootProvider
local profileKeyProvider

local DEFAULT_CUSTOM_TRIGGERS = {
    swimming = { enabled = true, loadoutName = "", blockFreedichGrowlgate = true },
    captain = { enabled = true, loadoutName = "" },
    sleep = { enabled = true, loadoutName = "" },
    wakeup = { enabled = true, loadoutName = "" }
}

local function safeCall(fn)
    local ok, a, b, c = pcall(fn)
    if ok then return a, b, c end
    return nil
end

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function isEmpty(value)
    return value == nil or tostring(value):match("^%s*$") ~= nil
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(value)
    return string.lower(trim(value))
end

local function copyTable(value, seen)
    if type(value) ~= "table" then
        local kind = type(value)
        if kind == "string" or kind == "number" or kind == "boolean" then return value end
        return nil
    end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local copy = {}
    for k, v in pairs(value) do
        if type(k) == "string" or type(k) == "number" then
            local copied = copyTable(v, seen)
            if copied ~= nil then copy[k] = copied end
        end
    end
    seen[value] = nil
    return copy
end

local function hasGearSets(list)
    return type(list) == "table" and #list > 0
end

local function accountRoot()
    if type(accountRootProvider) ~= "function" then return nil end
    local root = safeCall(accountRootProvider)
    if type(root) == "table" then return root end
    return nil
end

local function activeProfileKey()
    if type(profileKeyProvider) ~= "function" then return nil end
    local key = safeCall(profileKeyProvider)
    if type(key) == "string" and key ~= "" and key ~= "__pending__" and key ~= "__migration_failed__" then
        return key
    end
    return nil
end

local function copyHotSwapBackup()
    if type(settings) ~= "table" or not hasGearSets(settings.gear_sets) then return nil end
    return {
        gear_sets = copyTable(settings.gear_sets),
        activeLoadoutName = settings.activeLoadoutName,
        x = settings.x,
        y = settings.y,
        settings_x = settings.settings_x,
        settings_y = settings.settings_y,
        open_direction = settings.open_direction,
        hidden = settings.hidden
    }
end

local function backupHotSwapGearSets()
    if type(rootSettings) ~= "table" or type(settings) ~= "table" then return end
    local backup = copyHotSwapBackup()
    if type(backup) ~= "table" then return end
    rootSettings.hotSwapGearSetsBackup = copyTable(backup)
    local root = accountRoot()
    local key = activeProfileKey()
    if type(root) == "table" and key then
        if type(root.hotSwapBackups) ~= "table" then root.hotSwapBackups = {} end
        root.hotSwapBackups[key] = copyTable(backup)
    end
end

local function restoreHotSwapGearSetsFromBackup()
    if type(rootSettings) ~= "table" or type(settings) ~= "table" then return false end
    if hasGearSets(settings.gear_sets) then return false end
    local backup = rootSettings.hotSwapGearSetsBackup
    if type(backup) ~= "table" or not hasGearSets(backup.gear_sets) then
        local root = accountRoot()
        local key = activeProfileKey()
        local backups = type(root) == "table" and root.hotSwapBackups or nil
        backup = type(backups) == "table" and key and backups[key] or nil
    end
    if type(backup) ~= "table" or not hasGearSets(backup.gear_sets) then return false end
    settings.gear_sets = copyTable(backup.gear_sets) or {}
    settings.activeLoadoutName = settings.activeLoadoutName or backup.activeLoadoutName
    settings.x = settings.x or backup.x
    settings.y = settings.y or backup.y
    settings.settings_x = settings.settings_x or backup.settings_x
    settings.settings_y = settings.settings_y or backup.settings_y
    settings.open_direction = settings.open_direction or backup.open_direction
    if settings.hidden == nil then settings.hidden = backup.hidden end
    return hasGearSets(settings.gear_sets)
end

local function saveSettings()
    backupHotSwapGearSets()
    SettingsSanitizer.Clean(rootSettings)
    if api.Log and api.Log.Info then
        local count = type(settings) == "table" and type(settings.gear_sets) == "table" and #settings.gear_sets or -1
        pcall(function() api.Log:Info("[PowerRangerON] HotSwap save gear_sets=" .. tostring(count)) end)
    end
    if persistSettings then
        persistSettings("saving (HotSwap change)")
    end
end

local function setStatus(text, isError)
    local value = tostring(text or "")
    if settings then settings.status = value end
    local color = isError and {1, 0.42, 0.36, 1} or COLORS.muted
    if settingsWnd and settingsWnd.status then
        settingsWnd.status:SetText(value)
        settingsWnd.status.style:SetColor(color[1], color[2], color[3], color[4])
    end
end

local function chatWarning(text)
    local value = tostring(text or "")
    if value == "" then return end
    if api.Log and api.Log.Warning then
        local ok = pcall(function() api.Log:Warning(value) end)
        if ok then return end
    end
    if api.Log and api.Log.Info then
        safeCall(function() api.Log:Info(value) end)
    end
end


-- Active-set green highlight. IN-MEMORY ONLY: it never calls saveSettings (that
-- disk write firing during a gear swap is what froze PCs). No "Active:" label either.
local function retoneSetButtons()
    if type(buttons) ~= "table" then return end
    local activeName = settings and settings.activeLoadoutName or nil
    for _, button in ipairs(buttons) do
        if button and button.SetTone then
            local isActive = activeName and activeName ~= "" and button._hsSetName == activeName
            button:SetTone(isActive and COLORS.active or COLORS.button)
        end
    end
end

local function setActiveLoadout(set)
    if not settings or type(set) ~= "table" then return end
    settings.activeLoadoutName = tostring(set.name or "")
    retoneSetButtons()
end

local function shortText(value, maxLen)
    value = tostring(value or "")
    maxLen = tonumber(maxLen) or 24
    if #value <= maxLen then return value end
    return value:sub(1, maxLen - 1) .. "."
end

local function getSlotIndex(def)
    if type(def) ~= "table" then return nil end
    if EQUIP_SLOT and def.api_key and EQUIP_SLOT[def.api_key] then
        return tonumber(EQUIP_SLOT[def.api_key])
    end
    local fallback = tonumber(def.slot)
    if fallback and fallback > 0 then return fallback end
    return nil
end

local function itemIsEmpty(item)
    return type(item) ~= "table" or trim(item.name) == ""
end

local function itemGrade(item)
    return item and (item.itemGrade or item.grade or item.gradeType or item.item_grade)
end

local function itemType(item)
    return item and (item.itemType or item.item_type or item.type or item.typeId)
end

local function itemIcon(item)
    return item and (item.path or item.icon or item.iconPath or item.itemIcon or item.texture)
end

local function itemDescriptor(def, item, source, bagSlot)
    if itemIsEmpty(item) then return nil end
    return {
        slot_key = def and def.key or nil,
        slot_label = def and def.label or nil,
        slot_index = def and getSlotIndex(def) or nil,
        name = trim(item.name),
        grade = itemGrade(item),
        item_type = itemType(item),
        icon = itemIcon(item),
        source = source,
        bag_slot = bagSlot,
        is_aux = def and def.is_aux and true or false
    }
end

local function readEquippedItem(def)
    local slotIndex = getSlotIndex(def)
    if not slotIndex or not api.Equipment then return nil end
    local item = nil
    if api.Equipment.GetEquippedItemTooltipInfo then
        item = safeCall(function() return api.Equipment:GetEquippedItemTooltipInfo(slotIndex) end)
    end
    if itemIsEmpty(item) and api.Equipment.GetEquippedItemTooltipText then
        item = safeCall(function() return api.Equipment:GetEquippedItemTooltipText("player", slotIndex) end)
    end
    return itemDescriptor(def, item, "equipped")
end

local function getBagItem(index)
    if not api.Bag or not api.Bag.GetBagItemInfo then return nil end
    local item = safeCall(function() return api.Bag:GetBagItemInfo(1, index) end)
    if itemIsEmpty(item) then return nil end
    return item
end

local function itemsMatch(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    local nameA = lower(a.name)
    local nameB = lower(b.name)
    if nameA == "" or nameB == "" or nameA ~= nameB then return false end
    local gradeA = a.grade or a.itemGrade
    local gradeB = b.grade or b.itemGrade
    if gradeA ~= nil and gradeB ~= nil then return tostring(gradeA) == tostring(gradeB) end
    return true
end

local function findItemInBag(saved, usedSlots)
    for bagSlot = 1, BAG_SLOT_COUNT do
        if not usedSlots[bagSlot] then
            local item = getBagItem(bagSlot)
            if item and itemsMatch(saved, itemDescriptor({is_aux = saved.is_aux}, item, "bag", bagSlot)) then
                return bagSlot
            end
        end
    end
    return nil
end

local function loadoutSlots(loadout)
    if type(loadout) ~= "table" then return {} end
    if type(loadout.slots) ~= "table" then loadout.slots = {} end
    return loadout.slots
end

local function hasSlotLoadout(loadout)
    if type(loadout) == "table" and loadout.legacyPartialSlots == true then return false end
    if type(loadout) ~= "table" or type(loadout.slots) ~= "table" then return false end
    for _, value in pairs(loadout.slots) do
        if type(value) == "table" then return true end
    end
    return false
end

local LEGACY_SLOT_ORDER = {1, 3, 4, 8, 6, 9, 5, 7, 15, 2, 10, 11, 12, 13, 16, 17, 18, 19, 28}
local LEGACY_CONVERT_VERSION = 2

local function slotDefByKey(key)
    key = tostring(key or "")
    if key == "" then return nil end
    for _, def in ipairs(SLOT_DEFS) do
        if def.key == key then return def end
    end
    return nil
end

local function slotDefByIndex(slotIndex)
    slotIndex = tonumber(slotIndex)
    if not slotIndex then return nil end
    for _, def in ipairs(SLOT_DEFS) do
        if tonumber(def.slot) == slotIndex or tonumber(getSlotIndex(def)) == slotIndex then return def end
    end
    return nil
end

local function legacySlotHint(item)
    local name = lower(item and item.name)
    if name == "" then return nil end
    if name:find("glider", 1, true)
        or name:find("wings", 1, true)
        or name:find("magithopter", 1, true)
        or name:find("sloth", 1, true)
        or name:find("snowflake", 1, true)
        or name:find("flamefeather", 1, true)
        or name:find("crystal", 1, true)
        or name:find("ezi", 1, true) then
        return slotDefByKey("backpack")
    end
    if name:find("costume", 1, true)
        or name:find("cosplay", 1, true)
        or name:find("uniform", 1, true)
        or name:find("outfit", 1, true)
        or name:find("garb", 1, true)
        or name:find("raiment", 1, true) then
        return slotDefByKey("cosplay")
    end
    if name:find("lute", 1, true)
        or name:find("flute", 1, true)
        or name:find("drum", 1, true)
        or name:find("horn", 1, true)
        or name:find("instrument", 1, true) then
        return slotDefByKey("musical")
    end
    return nil
end

local function convertLegacyLoadout(loadout)
    if type(loadout) ~= "table" or type(loadout.gear) ~= "table" then return false end
    local shouldRepair = loadout.legacyConverted == true and loadout.legacyConvertVersion ~= LEGACY_CONVERT_VERSION
    if loadout.legacyPartialSlots == true and not shouldRepair then return false end
    if hasSlotLoadout(loadout) and not shouldRepair then return false end
    local fullLegacyOrder = #loadout.gear >= #LEGACY_SLOT_ORDER
    loadout.slots = {}
    local slots = loadout.slots
    local converted = 0
    for index, item in ipairs(loadout.gear) do
        if type(item) == "table" and not itemIsEmpty(item) then
            local def = slotDefByKey(item.slot_key)
            if not def then def = legacySlotHint(item) end
            if not def and fullLegacyOrder then def = slotDefByIndex(item.slot_index or LEGACY_SLOT_ORDER[index]) end
            if def then
                local saved = copyTable(item) or {}
                saved.slot_key = def.key
                saved.slot_label = def.label
                saved.slot_index = getSlotIndex(def) or def.slot
                saved.grade = saved.grade or saved.itemGrade
                saved.is_aux = saved.is_aux or saved.alternative or def.is_aux or false
                slots[def.key] = saved
                converted = converted + 1
            end
        end
    end
    if converted > 0 then
        loadout.legacyConverted = true
        loadout.legacyConvertVersion = LEGACY_CONVERT_VERSION
        loadout.legacyPartialSlots = not fullLegacyOrder
        return true
    end
    return false
end

local function convertLegacyLoadouts(loadouts)
    local changed = false
    for _, loadout in ipairs(loadouts or {}) do
        if convertLegacyLoadout(loadout) then changed = true end
    end
    return changed
end

local function gearSetByName(name)
    name = tostring(name or "")
    for _, set in ipairs(settings and settings.gear_sets or {}) do
        if tostring(set.name or "") == name then return set end
    end
    return nil
end

local customAuraKey = HotSwapAuras.customAuraKey
local auraMatchFromRow = HotSwapAuras.auraMatchFromRow
local auraMatchKey = HotSwapAuras.auraMatchKey
local normalizeCustomAura = HotSwapAuras.normalizeCustomAura
local customAuraHasMatch = HotSwapAuras.customAuraHasMatch
local customAuraMatches = HotSwapAuras.customAuraMatches

local function ensureAutoSettings()
    if not settings then return end
    if type(settings.autoTriggers) ~= "table" then settings.autoTriggers = {} end
    if type(settings.autoTriggers.swimming) ~= "table" then
        settings.autoTriggers.swimming = copyTable(DEFAULT_CUSTOM_TRIGGERS.swimming)
    end
    if settings.autoTriggers.swimming.blockFreedichGrowlgate == nil then
        settings.autoTriggers.swimming.blockFreedichGrowlgate = true
    end
    if type(settings.autoTriggers.captain) ~= "table" then
        settings.autoTriggers.captain = copyTable(DEFAULT_CUSTOM_TRIGGERS.captain)
    end
    if type(settings.autoTriggers.sleep) ~= "table" then
        settings.autoTriggers.sleep = copyTable(DEFAULT_CUSTOM_TRIGGERS.sleep)
    end
    if type(settings.autoTriggers.wakeup) ~= "table" then
        settings.autoTriggers.wakeup = copyTable(DEFAULT_CUSTOM_TRIGGERS.wakeup)
    end
    if type(settings.customAuras) ~= "table" then settings.customAuras = {} end
    for _, entry in ipairs(settings.customAuras) do
        normalizeCustomAura(entry)
    end
end

local readPlayerAuras = HotSwapAuras.readPlayerAuras
local anyAuraMatches = HotSwapAuras.anyAuraMatches
local swimmingActive = HotSwapAuras.swimmingActive
local sleepActive = HotSwapAuras.sleepActive
local wakeupActive = HotSwapAuras.wakeupActive

local function refreshCurrentZoneName()
    autoZoneMs = (tonumber(autoZoneMs) or 0) + AUTO_CHECK_MS
    if autoZoneMs < 1000 and trim(autoZoneName) ~= "" then
        return autoZoneName
    end
    autoZoneMs = 0
    local zoneName = ""
    if api.Unit and api.Unit.GetCurrentZoneGroup and api.Zone and api.Zone.GetZoneStateInfoByZoneId then
        local currentZoneGroup = safeCall(function()
            return api.Unit:GetCurrentZoneGroup()
        end)
        local candidates = {}
        if type(currentZoneGroup) == "number" then
            candidates[#candidates + 1] = currentZoneGroup
        elseif type(currentZoneGroup) == "table" then
            for _, value in ipairs(currentZoneGroup) do
                local zoneId = tonumber(value)
                if zoneId and zoneId > 0 then
                    candidates[#candidates + 1] = zoneId
                end
            end
        end
        for _, zoneId in ipairs(candidates) do
            local zoneInfo = safeCall(function()
                return api.Zone:GetZoneStateInfoByZoneId(zoneId)
            end)
            if type(zoneInfo) == "table" and trim(zoneInfo.zoneName) ~= "" then
                zoneName = trim(zoneInfo.zoneName)
                if zoneInfo.isCurrentZone == true then
                    break
                end
            end
        end
    end
    autoZoneName = zoneName
    return zoneName
end

local function isSwimmingZoneBlocked()
    local trigger = settings and settings.autoTriggers and settings.autoTriggers.swimming
    if type(trigger) == "table" and trigger.blockFreedichGrowlgate == false then
        return false
    end
    local zoneName = lower(refreshCurrentZoneName())
    if zoneName == "" then return false end
    for _, blocked in ipairs(SWIMMING_BLOCKED_ZONE_HINTS) do
        if zoneName:find(blocked, 1, true) then
            return true
        end
    end
    return false
end

local function isPlayerInCombat()
    if not api.Unit or not api.Unit.UnitCombatState then return false end
    local state = safeCall(function() return api.Unit:UnitCombatState("player") end)
    if state == true then return true end
    if type(state) == "number" then return state ~= 0 end
    if type(state) == "string" then
        local value = lower(state)
        return value ~= "" and value ~= "0" and value ~= "false"
    end
    return false
end

local function screenSize()
    local w = tonumber(safeCall(function() return api.Interface:GetScreenWidth() end)) or 1920
    local h = tonumber(safeCall(function() return api.Interface:GetScreenHeight() end)) or 1080
    if w <= 0 then w = 1920 end
    if h <= 0 then h = 1080 end
    return w, h
end

local function safePosition(x, y, w, h)
    local screenW, screenH = screenSize()
    local maxX = math.max(MAIN.pad, screenW - w - MAIN.pad)
    local maxY = math.max(MAIN.pad, screenH - h - MAIN.pad)
    return clamp(x, MAIN.pad, maxX), clamp(y, MAIN.pad, maxY)
end

local function safeHeaderPosition(x, y, width, height, opensUp, hidden)
    local screenW, screenH = screenSize()
    local headerOffset = opensUp and not hidden and (height - MAIN.headerH) or 0
    local maxX = math.max(MAIN.pad, screenW - width - MAIN.pad)
    local minY = MAIN.pad + headerOffset
    local maxY = math.max(minY, screenH - MAIN.headerH - MAIN.pad)
    return clamp(x, MAIN.pad, maxX), clamp(y, minY, maxY)
end

local function windowPosition(window)
    if window and window.GetEffectiveOffset then
        local x, y = window:GetEffectiveOffset()
        if tonumber(x) and tonumber(y) then return x, y end
    end
    if window and window.GetOffset then
        local x, y = window:GetOffset()
        if tonumber(x) and tonumber(y) then return x, y end
    end
    return nil, nil
end

local function label(parent, id, text, x, y, w, h, size, color, align)
    return UiHelpers.ChildLabel(parent, id, text, x, y, w, h, size, color, align)
end

local function flatButton(parent, id, text, x, y, w, h, tone, onClick, align)
    return UiHelpers.ChildFlatButton(parent, id, text, x, y, w, h, tone, onClick, COLORS, align)
end

local function panel(parent, id, x, y, w, h, title)
    local box = parent:CreateChildWidget("emptywidget", id, 0, true)
    box:SetExtent(w, h)
    box:AddAnchor("TOPLEFT", parent, x, y)
    local border = box:CreateColorDrawable(0, 0, 0, 0.92, "background")
    border:AddAnchor("TOPLEFT", box, 0, 0)
    border:AddAnchor("BOTTOMRIGHT", box, 0, 0)
    border:Show(true)
    local bg = box:CreateColorDrawable(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], COLORS.panel[4], "background")
    bg:AddAnchor("TOPLEFT", box, 1, 1)
    bg:AddAnchor("BOTTOMRIGHT", box, -1, -1)
    bg:Show(true)
    local header = box:CreateColorDrawable(COLORS.settingsHeader[1], COLORS.settingsHeader[2], COLORS.settingsHeader[3], 0.95, "background")
    header:SetExtent(w - 2, 26)
    header:AddAnchor("TOPLEFT", box, 1, 1)
    header:Show(true)
    local accent = box:CreateColorDrawable(1, 0.84, 0, 0.85, "background")
    accent:SetExtent(4, 26)
    accent:AddAnchor("TOPLEFT", box, 1, 1)
    accent:Show(true)
    label(box, id .. "_title", title, 14, 6, w - 20, 15, 11, COLORS.gold, ALIGN.LEFT):Clickable(false)
    return box
end

local function darkEdit(parent, id, guide, x, y, w, h)
    local edit = W_CTRL.CreateEdit(id, parent)
    edit:SetExtent(w, h)
    edit:AddAnchor("TOPLEFT", parent, x, y)
    edit:SetMaxTextLength(64)
    edit:CreateGuideText(guide)
    local border = edit:CreateColorDrawable(0, 0, 0, 0.95, "background")
    border:AddAnchor("TOPLEFT", edit, -1, -1)
    border:AddAnchor("BOTTOMRIGHT", edit, 1, 1)
    border:Show(true)
    local fill = edit:CreateColorDrawable(0.10, 0.10, 0.11, 0.96, "background")
    fill:AddAnchor("TOPLEFT", edit, 0, 0)
    fill:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
    fill:Show(true)
    if edit.style then
        edit.style:SetColor(1, 1, 1, 1)
        edit.style:SetFontSize(11)
    end
    edit:Show(true)
    return edit
end

local function ensureSettings(source)
    if type(source) == "table" then
        rootSettings = source
    elseif type(rootSettings) ~= "table" then
        return nil
    end
    if type(rootSettings.hotSwap) ~= "table" then rootSettings.hotSwap = {} end
    settings = rootSettings.hotSwap
    if type(settings.gear_sets) ~= "table" then settings.gear_sets = {} end
    ensureAutoSettings()
    if settings.enabled == nil then settings.enabled = true end
    if settings.floatShown == nil then settings.floatShown = true end
    if settings.open_direction ~= "up" then settings.open_direction = "down" end
    if settings.hidden == nil then settings.hidden = false end
    restoreHotSwapGearSetsFromBackup()
    if settings.migratedFromStandalone ~= true then
        local legacySource = safeCall(function() return api.GetSettings(LEGACY_ADDON_ID) end)
        local legacy = copyTable(legacySource)
        SettingsSanitizer.Clean(legacy)
        if type(legacy) == "table" and hasGearSets(legacy.gear_sets) and not hasGearSets(settings.gear_sets) then
            settings.gear_sets = copyTable(legacy.gear_sets) or {}
            settings.x = legacy.x
            settings.y = legacy.y
            settings.hidden = legacy.hidden
            settings.open_direction = legacy.open_direction == "up" and "up" or "down"
            settings.settings_x = legacy.settings_x
            settings.settings_y = legacy.settings_y
        end
        if hasGearSets(settings.gear_sets) then
            settings.migratedFromStandalone = true
        end
    end
    convertLegacyLoadouts(settings.gear_sets)
    return settings
end

local function saveMainPosition()
    local x, y = windowPosition(canvas)
    if not tonumber(x) or not tonumber(y) then return end
    local headerOffset = canvas and canvas.headerOffset or 0
    settings.x = math.floor(tonumber(x) + 0.5)
    settings.y = math.floor(tonumber(y) + headerOffset + 0.5)
    saveSettings()
end

local function saveSettingsPosition()
    local x, y = windowPosition(settingsWnd)
    if not tonumber(x) or not tonumber(y) then return end
    settings.settings_x = math.floor(tonumber(x) + 0.5)
    settings.settings_y = math.floor(tonumber(y) + 0.5)
    saveSettings()
end

local function panelHeight(rowCount)
    return MAIN.headerH + 8 + (math.max(0, rowCount) * MAIN.rowStep)
end

local function refreshMain()
    HotSwap.destroyMain()
    HotSwap.createMain()
end

local function switchTitle(titleId)
    if titleId == nil or api.Player == nil or api.Player.ChangeAppellation == nil then return end
    safeCall(function() api.Player:ChangeAppellation(math.floor(tonumber(titleId))) end)
end

local function verifyLoadout(set)
    if not hasSlotLoadout(set) then return end
    local missing = {}
    local slots = loadoutSlots(set)
    for _, def in ipairs(SLOT_DEFS) do
        local saved = slots[def.key]
        if type(saved) == "table" and not itemIsEmpty(saved) then
            local equipped = readEquippedItem(def)
            if not itemsMatch(saved, equipped) then
                missing[#missing + 1] = def.label
            end
        end
    end
    if #missing > 0 then
        local text = "Missing/unequipped: " .. table.concat(missing, ", ")
        setStatus(text, true)
        chatWarning("[Power Ranger HotSwap] " .. tostring(set.name or "gear set") .. " missing: " .. table.concat(missing, ", "))
    else
        setStatus("Equipped " .. tostring(set.name or "gear set") .. ".", false)
        setActiveLoadout(set)
    end
end

local function queueSet(set, reason)
    if type(set) ~= "table" then return end
    if settings and settings.enabled == false then
        setStatus("Hot Swap is OFF.", true)
        return
    end
    -- Mark active immediately on press so the green shows right away and survives createMain's
    -- mid-swap rebuild (rebuilt buttons read settings.activeLoadoutName). verifyLoadout re-confirms
    -- it on success. setActiveLoadout is in-memory only (no disk write), so this is cheap.
    setActiveLoadout(set)
    gearQueue = {}
    pendingTitle = set.title_id
    titleDelay = 0
    titleAttempts = 0
    queueDelay = QUEUE_DELAY_MS
    pendingCheck = nil
    pendingCheckDelay = 0
    local usedSlots = {}
    local missing = {}
    if hasSlotLoadout(set) then
        local slots = loadoutSlots(set)
        for _, def in ipairs(SLOT_DEFS) do
            local needed = slots[def.key]
            if type(needed) == "table" and not itemIsEmpty(needed) then
                local equipped = readEquippedItem(def)
                if not itemsMatch(needed, equipped) then
                    local bagSlot = findItemInBag(needed, usedSlots)
                    if bagSlot then
                        gearQueue[#gearQueue + 1] = {
                            pos = bagSlot,
                            alternative = needed.is_aux or def.is_aux or false,
                            slot = def.label,
                            name = needed.name
                        }
                        usedSlots[bagSlot] = true
                    else
                        missing[#missing + 1] = def.label
                    end
                end
            end
        end
        pendingCheck = { loadout = set, missing = missing }
        pendingCheckDelay = #gearQueue > 0 and 0 or EQUIP_VERIFY_DELAY_MS
        if #missing > 0 then
            setStatus("Queued " .. tostring(set.name or "set") .. "; missing: " .. table.concat(missing, ", "), true)
            chatWarning("[Power Ranger HotSwap] " .. tostring(set.name or "set") .. " missing: " .. table.concat(missing, ", "))
        elseif reason and reason ~= "" then
            setStatus("Queued " .. tostring(set.name or "set") .. " from " .. tostring(reason) .. ".", false)
        else
            setStatus("Queued " .. tostring(set.name or "set") .. ".", false)
        end
        return
    end
    for _, needed in ipairs(set.gear or {}) do
        for bagSlot = 1, BAG_SLOT_COUNT do
            if not usedSlots[bagSlot] then
                local item = getBagItem(bagSlot)
                if item and itemsMatch(needed, itemDescriptor({}, item, "bag", bagSlot)) then
                    gearQueue[#gearQueue + 1] = { pos = bagSlot, alternative = needed.alternative or false }
                    usedSlots[bagSlot] = true
                    break
                end
            end
        end
    end
    setStatus("Queued legacy set " .. tostring(set.name or "set") .. ".", false)
    setActiveLoadout(set)
end

local function createSetButton(set, index, rowStartY)
    local id = "power_ranger_hot_swap_set_" .. tostring(index)
    -- Re-apply the active green on rebuild (createMain rebuilds on every swap/refresh).
    local isActive = settings and set.name and set.name ~= "" and settings.activeLoadoutName == set.name
    local button = flatButton(canvas, id, set.name, MAIN.left, rowStartY + ((index - 1) * MAIN.rowStep),
        MAIN.width - (MAIN.left * 2), MAIN.rowH, isActive and COLORS.active or COLORS.button, function()
            for _, other in ipairs(buttons) do
                other:SetTone(other == button and COLORS.active or COLORS.button)
            end
            queueSet(set)
        end)
    button._hsSetName = set.name
    buttons[#buttons + 1] = button
    button:Show(settings.hidden ~= true)
end

function HotSwap.createMain()
    if not settings and not ensureSettings() then return end
    buttons = {}
    gearQueue = {}
    pendingTitle = nil
    titleDelay = 0
    titleAttempts = 0
    queueDelay = 0
    if settings.floatShown == false then return end

    -- Only sets with Show ON occupy a row on the floating window; hidden sets stay
    -- available in settings and for auto-triggers.
    local gearSets = {}
    for _, set in ipairs(settings.gear_sets or {}) do
        if set.showOnFloat ~= false then gearSets[#gearSets + 1] = set end
    end
    local height = settings.hidden and MAIN.headerH or panelHeight(#gearSets)
    local opensUp = settings.open_direction == "up"
    local headerX, headerY = safeHeaderPosition(settings.x, settings.y, MAIN.width, height, opensUp, settings.hidden)
    local headerOffset = opensUp and not settings.hidden and (height - MAIN.headerH) or 0
    local canvasX = headerX
    local canvasY = headerY - headerOffset
    local headerWidgetY = opensUp and not settings.hidden and (height - MAIN.headerH) or 0
    local rowStartY = opensUp and 5 or MAIN.headerH + 5

    canvas = api.Interface:CreateEmptyWindow("powerRangerHotSwapWindow", "UIParent")
    canvas.headerOffset = headerOffset
    canvas:SetExtent(MAIN.width, height)
    canvas:AddAnchor("TOPLEFT", "UIParent", canvasX, canvasY)

    local body = canvas:CreateColorDrawable(0.03, 0.04, 0.055, 0.52, "background")
    body:AddAnchor("TOPLEFT", canvas, 0, 0)
    body:AddAnchor("BOTTOMRIGHT", canvas, 0, 0)
    body:Show(true)
    local header = canvas:CreateColorDrawable(COLORS.header[1], COLORS.header[2], COLORS.header[3], COLORS.header[4], "background")
    header:SetExtent(MAIN.width, MAIN.headerH)
    header:AddAnchor("TOPLEFT", canvas, 0, headerWidgetY)
    header:Show(true)
    label(canvas, "power_ranger_hot_swap_title", "Hot Swap", 8, headerWidgetY + 4, 54, 15, 11, COLORS.gold, ALIGN.LEFT):Clickable(false)

    canvas:SetHandler("OnDragStart", function()
        if api.Input:IsShiftKeyDown() then
            canvas:StartMoving()
            api.Cursor:ClearCursor()
            api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
        end
    end)
    local function onDragStop()
        canvas:StopMovingOrSizing()
        api.Cursor:ClearCursor()
        saveMainPosition()
    end
    canvas:SetHandler("OnDragStop", onDragStop)
    canvas:SetHandler("OnDragEnd", onDragStop)
    canvas:EnableDrag(true)
    if canvas.RegisterForDrag then canvas:RegisterForDrag("LeftButton") end

    local collapse = flatButton(canvas, "power_ranger_hot_swap_collapse", settings.hidden and "+" or "-",
        MAIN.width - 25, headerWidgetY + 3, 20, 18, COLORS.button, function()
            settings.hidden = not settings.hidden
            saveSettings()
            refreshMain()
        end, ALIGN.CENTER)
    collapse.cleanLabel.style:SetAlign(ALIGN.CENTER)

    for index, set in ipairs(gearSets) do
        createSetButton(set, index, rowStartY)
    end
    canvas:Show(true)
end

function HotSwap.destroyMain()
    buttons = {}
    gearQueue = {}
    pendingTitle = nil
    titleDelay = 0
    titleAttempts = 0
    queueDelay = 0
    if canvas then
        api.Interface:Free(canvas)
        canvas = nil
    end
end

local function activeAutoLoadout()
    ensureAutoSettings()
    local buffs, debuffs = readPlayerAuras()
    -- Track how long the sleep buff has been gone. While it's active (or only just gone), the
    -- WakeUp trigger below is held off so a flickering sleep buff / a quick second sleep can't
    -- flip us to the wakeup set mid-bed. This is called once per AUTO_CHECK_MS tick.
    local sleepNow = sleepActive(buffs, debuffs)
    if sleepNow then
        sleepClearMs = 0
    elseif sleepClearMs < WAKEUP_GRACE_MS then
        sleepClearMs = sleepClearMs + AUTO_CHECK_MS
    end
    if settings.autoTriggers.swimming.enabled ~= false and not isSwimmingZoneBlocked() and swimmingActive(buffs, debuffs) then
        local set = gearSetByName(settings.autoTriggers.swimming.loadoutName)
        if set then return "swimming:" .. tostring(set.name), set, "Swimming" end
    end
    if settings.autoTriggers.captain.enabled ~= false and anyAuraMatches(buffs, debuffs, "captain") then
        local set = gearSetByName(settings.autoTriggers.captain.loadoutName)
        if set then return "captain:" .. tostring(set.name), set, "Captain" end
    end
    if settings.autoTriggers.sleep.enabled ~= false and sleepNow then
        local set = gearSetByName(settings.autoTriggers.sleep.loadoutName)
        if set then return "sleep:" .. tostring(set.name), set, "Deep Sleep" end
    end
    for _, entry in ipairs(settings.customAuras or {}) do
        if entry.enabled ~= false and customAuraMatches(entry, buffs, debuffs) then
            local set = gearSetByName(entry.loadoutName)
            if set then return "custom:" .. tostring(entry.key or entry.name), set, entry.name or "Custom" end
        end
    end
    -- WakeUp is the lowest-priority trigger (checked last, after sleep and custom auras) and
    -- only fires once the sleep buff has been gone for the full grace window, so sleep always
    -- wins and you can sleep twice in a row without it bouncing to the wakeup set.
    if settings.autoTriggers.wakeup.enabled ~= false and sleepClearMs >= WAKEUP_GRACE_MS
        and wakeupActive(buffs, debuffs) then
        local set = gearSetByName(settings.autoTriggers.wakeup.loadoutName)
        if set then return "wakeup:" .. tostring(set.name), set, "WakeUp" end
    end
    return nil, nil, nil
end

local function rebuildSettingsWindow()
    if not settingsWnd then return end
    local wasShown = settingsShown
    api.Interface:Free(settingsWnd)
    settingsWnd = nil
    createSettingsWindow()
    settingsShown = wasShown
    settingsWnd:Show(settingsShown)
    if settingsWnd.hotSwapUi and settingsWnd.hotSwapUi.refreshAll then
        settingsWnd.hotSwapUi.refreshAll()
    end
end

local function processAutoTriggers(dt)
    autoElapsed = autoElapsed + (tonumber(dt) or 0)
    if autoElapsed < AUTO_CHECK_MS then return end
    autoElapsed = 0
    if #gearQueue > 0 or pendingCheck then return end
    local key, set, labelText = activeAutoLoadout()
    if not key or not set then
        autoActiveKey = nil
        return
    end
    if autoActiveKey == key then return end
    if isPlayerInCombat() then
        setStatus("Auto trigger waiting for combat: " .. tostring(labelText) .. ".", true)
        return
    end
    autoActiveKey = key
    queueSet(set, labelText)
end

function HotSwap.CustomAuraTracked(row)
    if not settings and not ensureSettings() then return false end
    ensureAutoSettings()
    local key = auraMatchKey(auraMatchFromRow(row)) or customAuraKey(row)
    if not key then return false end
    for _, entry in ipairs(settings.customAuras or {}) do
        if customAuraHasMatch(entry, key) then return true end
    end
    return false
end

function HotSwap.ToggleCustomAura(row)
    if not settings and not ensureSettings() then return false end
    ensureAutoSettings()
    local match = auraMatchFromRow(row)
    local key = auraMatchKey(match) or customAuraKey(row)
    if not key then return false end
    if not match then return false end
    local selectedEntry = selectedCustomIndex and settings.customAuras[selectedCustomIndex] or nil
    if selectedEntry then
        if customAuraHasMatch(selectedEntry, key) then
            setStatus("Trigger already has " .. tostring(match and match.name or row.name or row.id) .. ".", false)
            rebuildSettingsWindow()
            return true
        end
        normalizeCustomAura(selectedEntry)
        selectedEntry.matches[#selectedEntry.matches + 1] = match
        saveSettings()
        setStatus("Bound " .. tostring(match.name or match.id) .. " to " .. tostring(selectedEntry.name or "trigger") .. ".", false)
        rebuildSettingsWindow()
        return true
    end
    for i, entry in ipairs(settings.customAuras or {}) do
        if customAuraHasMatch(entry, key) then
            setStatus("Custom trigger already added: " .. tostring(entry.name or entry.query or row.name or row.id) .. ".", false)
            rebuildSettingsWindow()
            return true
        end
    end
    local currentSet = selectedLoadout()
    settings.customAuras[#settings.customAuras + 1] = {
        key = key,
        enabled = true,
        id = match.id,
        name = match.name,
        query = match.query,
        source = row.source or "Detected",
        matches = {match},
        loadoutName = currentSet and currentSet.name or ""
    }
    saveSettings()
    setStatus("Added custom trigger " .. tostring(row.name or row.id) .. ".", false)
    rebuildSettingsWindow()
    return true
end

local function saveCurrentSet(nameInput, updateDropdown)
    local selectedName = nameInput:GetText()
    if isEmpty(selectedName) then return end
    local items = {}
    local slots = {}
    local gearPieces = {1, 3, 4, 8, 6, 9, 5, 7, 15, 2, 10, 11, 12, 13, 16, 17, 18, 19, 28}
    for _, slot in ipairs(gearPieces) do
        local item = safeCall(function() return api.Equipment:GetEquippedItemTooltipInfo(slot) end)
        if item then
            local entry = {name = item.name, grade = item.itemGrade}
            if slot == 13 or slot == 11 or slot == 17 then entry.alternative = true end
            items[#items + 1] = entry
        end
    end
    for _, def in ipairs(SLOT_DEFS) do
        local item = readEquippedItem(def)
        if item then slots[def.key] = item end
    end
    local loadout = {name = selectedName, gear = items, slots = slots}
    local appellation = safeCall(function() return api.Player:GetShowingAppellation() end)
    local titleId = appellation and appellation[1]
    if titleId then loadout.title_id = string.format("%d", math.floor(titleId)) end
    local replaced = false
    for index, existing in ipairs(settings.gear_sets) do
        if existing.name == selectedName then
            settings.gear_sets[index] = loadout
            replaced = true
            break
        end
    end
    if not replaced then settings.gear_sets[#settings.gear_sets + 1] = loadout end
    saveSettings()
    refreshMain()
    updateDropdown()
    setStatus("Saved " .. selectedName .. ".", false)
    nameInput:SetText("")
    nameInput:CreateGuideText("Enter set name")
end

local function updateSetFromEquipped(set)
    if type(set) ~= "table" then return 0 end
    local slots = loadoutSlots(set)
    local legacy = {}
    local count = 0
    for _, def in ipairs(SLOT_DEFS) do
        local item = readEquippedItem(def)
        if item then
            slots[def.key] = item
            legacy[#legacy + 1] = {
                name = item.name,
                grade = item.grade,
                alternative = item.is_aux or false
            }
            count = count + 1
        end
    end
    set.gear = legacy
    local appellation = safeCall(function() return api.Player:GetShowingAppellation() end)
    local titleId = appellation and appellation[1]
    if titleId then set.title_id = string.format("%d", math.floor(titleId)) end
    return count
end

function selectedLoadout()
    if selectedSetIndex and settings.gear_sets and settings.gear_sets[selectedSetIndex] then
        return settings.gear_sets[selectedSetIndex]
    end
    return nil
end

local function closeGearView()
    if gearViewWnd then
        api.Interface:Free(gearViewWnd)
        gearViewWnd = nil
    end
end

local function openGearView(set)
    if type(set) ~= "table" then return end
    closeGearView()
    convertLegacyLoadout(set)
    gearViewWnd = api.Interface:CreateEmptyWindow("powerRangerHotSwapGearViewWindow", "UIParent")
    gearViewWnd:SetExtent(520, 590)
    local x, y = safePosition((settings.settings_x or SETTINGS.defaultX) + 24, (settings.settings_y or SETTINGS.defaultY) + 28, 520, 590)
    gearViewWnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    local outer = gearViewWnd:CreateColorDrawable(0, 0, 0, 0.96, "background")
    outer:AddAnchor("TOPLEFT", gearViewWnd, 0, 0)
    outer:AddAnchor("BOTTOMRIGHT", gearViewWnd, 0, 0)
    outer:Show(true)
    local body = gearViewWnd:CreateColorDrawable(COLORS.dark[1], COLORS.dark[2], COLORS.dark[3], COLORS.dark[4], "background")
    body:AddAnchor("TOPLEFT", gearViewWnd, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", gearViewWnd, -1, -1)
    body:Show(true)
    local header = gearViewWnd:CreateColorDrawable(COLORS.settingsHeader[1], COLORS.settingsHeader[2], COLORS.settingsHeader[3], COLORS.settingsHeader[4], "background")
    header:SetExtent(518, 34)
    header:AddAnchor("TOPLEFT", gearViewWnd, 1, 1)
    header:Show(true)
    label(gearViewWnd, "power_ranger_hs_view_title", "Gear Set: " .. shortText(set.name or "-", 36), 16, 8, 400, 18, 13, COLORS.gold, ALIGN.LEFT)
    flatButton(gearViewWnd, "power_ranger_hs_view_close", "X", 484, 7, 22, 22, COLORS.button, closeGearView, ALIGN.CENTER)
    label(gearViewWnd, "power_ranger_hs_view_slot_head", "Slot", 18, 44, 96, 14, 10, COLORS.gold, ALIGN.LEFT)
    label(gearViewWnd, "power_ranger_hs_view_item_head", "Gearpiece", 126, 44, 360, 14, 10, COLORS.gold, ALIGN.LEFT)
    local slots = loadoutSlots(set)
    for i, def in ipairs(SLOT_DEFS) do
        local row = gearViewWnd:CreateChildWidget("emptywidget", "power_ranger_hs_view_row_" .. i, 0, true)
        row:SetExtent(484, 22)
        row:AddAnchor("TOPLEFT", gearViewWnd, 18, 62 + ((i - 1) * 24))
        local bg = row:CreateColorDrawable(i % 2 == 0 and 0.12 or 0.08, i % 2 == 0 and 0.12 or 0.08, i % 2 == 0 and 0.135 or 0.095, 0.72, "background")
        bg:AddAnchor("TOPLEFT", row, 0, 0)
        bg:AddAnchor("BOTTOMRIGHT", row, 0, 0)
        bg:Show(true)
        local saved = slots[def.key]
        label(row, "power_ranger_hs_view_slot_" .. i, def.label, 8, 4, 92, 14, 10, COLORS.muted, ALIGN.LEFT)
        label(row, "power_ranger_hs_view_item_" .. i, saved and shortText(saved.name, 58) or "-", 116, 4, 360, 14, 10, COLORS.white, ALIGN.LEFT)
    end
    gearViewWnd:Show(true)
end

local function addSettingsControls()
    ensureAutoSettings()
    local ui = { setRows = {}, customRows = {}, detectedRows = {}, setPage = 1 }
    settingsWnd.hotSwapUi = ui
    local savePanel = panel(settingsWnd, "power_ranger_hot_swap_save_panel", SETTINGS.contentX, 48, SETTINGS.contentW, 84, "Save Current Equipment")
    label(savePanel, "power_ranger_hot_swap_save_hint", "Saves current equipped slots and shown title.", 16, 36, 280, 14, 10, COLORS.muted, ALIGN.LEFT)
    ui.nameInput = darkEdit(savePanel, "power_ranger_hot_swap_name_input", "Enter set name", 16, 54, SETTINGS.fieldW, 24)

    ui.managePanel = panel(settingsWnd, "power_ranger_hot_swap_manage_panel", SETTINGS.contentX, 140, SETTINGS.contentW, 224, "Saved Gear Sets")
    ui.autoPanel = panel(settingsWnd, "power_ranger_hot_swap_auto_panel", SETTINGS.contentX, 372, SETTINGS.contentW, 184, "Auto Triggers")
    ui.detectedPanel = panel(settingsWnd, "power_ranger_hot_swap_detected_panel", SETTINGS.contentX, 564, SETTINGS.contentW, 188, "Detected Buff Triggers")
    ui.status = label(settingsWnd, "power_ranger_hot_swap_status", settings.status or "", 18, 792, 584, 18, 10, COLORS.muted, ALIGN.LEFT)
    settingsWnd.status = ui.status

    local function setPageCount()
        return math.max(1, math.ceil(#settings.gear_sets / SETTINGS.pageSize))
    end
    local function describeSet(set)
        local parts = {}
        for _, def in ipairs(SLOT_DEFS) do
            local saved = loadoutSlots(set)[def.key]
            if saved then parts[#parts + 1] = def.label .. "=" .. shortText(saved.name, 18) end
        end
        if #parts > 0 then return table.concat(parts, " | ") end
        for _, item in ipairs(set.gear or {}) do
            if item and item.name then parts[#parts + 1] = shortText(item.name, 18) end
        end
        return #parts > 0 and ("Legacy: " .. table.concat(parts, " | ")) or "No gear data saved."
    end
    local function detectedBuffRows()
        local rows = {}
        for _, row in ipairs(rootSettings.detectedSkills or {}) do
            if row and row.kind == "buff" then rows[#rows + 1] = row end
        end
        return rows
    end
    local function refreshCustom()
        local pages = math.max(1, math.ceil(#settings.customAuras / SETTINGS.customPageSize))
        customPage = math.max(1, math.min(customPage, pages))
        ui.customPage:SetText(string.format("%d / %d", customPage, pages))
        local first = ((customPage - 1) * SETTINGS.customPageSize) + 1
        for i, row in ipairs(ui.customRows) do
            local entry = settings.customAuras[first + i - 1]
            row.index = first + i - 1
            if entry then
                row.name:SetText(shortText((entry.name or entry.query or "Custom") .. " (" .. tostring(#(entry.matches or {})) .. ")", 18))
                row.gear:SetText(shortText(entry.loadoutName or "-", 14))
                if row.bind then row.bind:SetTone(row.index == selectedCustomIndex and COLORS.active or COLORS.button) end
                row.root:Show(true)
            else
                row.root:Show(false)
            end
        end
    end
    local function refreshDetected()
        local rows = detectedBuffRows()
        local pages = math.max(1, math.ceil(#rows / SETTINGS.detectedPageSize))
        detectedPage = math.max(1, math.min(detectedPage, pages))
        ui.detectedPage:SetText(string.format("%d / %d", detectedPage, pages))
        local first = ((detectedPage - 1) * SETTINGS.detectedPageSize) + 1
        for i, rowUi in ipairs(ui.detectedRows) do
            local row = rows[first + i - 1]
            rowUi.row = row
            if row then
                rowUi.name:SetText(shortText(row.name or row.pattern or tostring(row.id or "Buff"), 28))
                rowUi.meta:SetText(row.id and ("ID " .. string.format("%.0f", tonumber(row.id) or 0)) or "buff")
                rowUi.add:SetTone(HotSwap.CustomAuraTracked(row) and COLORS.active or COLORS.blue)
                rowUi.add:SetCleanText(HotSwap.CustomAuraTracked(row) and "Added" or (selectedCustomIndex and "Bind" or "Add"))
                rowUi.root:Show(true)
            else
                rowUi.root:Show(false)
            end
        end
    end
    local triggerDropdownKey = nil
    local triggerDropdownPage = 1
    local triggerDropdownCustomIndex = nil
    local refreshTriggerDropdown
    local function dropdownTrigger()
        if triggerDropdownKey == "custom" then
            return settings.customAuras and settings.customAuras[triggerDropdownCustomIndex] or nil
        end
        return settings.autoTriggers and settings.autoTriggers[triggerDropdownKey] or nil
    end
    local function triggerLabel(key)
        if key == "custom" then
            local entry = settings.customAuras and settings.customAuras[triggerDropdownCustomIndex] or nil
            return shortText(entry and (entry.name or entry.query) or "Custom", 18)
        end
        if key == "swimming" then return "Swimming" end
        if key == "captain" then return "Captain" end
        if key == "sleep" then return "Sleep" end
        if key == "wakeup" then return "WakeUp" end
        return tostring(key or "Trigger")
    end
    local function refreshAll()
        if selectedSetIndex and not settings.gear_sets[selectedSetIndex] then selectedSetIndex = nil end
        if selectedCustomIndex and not settings.customAuras[selectedCustomIndex] then selectedCustomIndex = nil end
        if not selectedSetIndex and settings.gear_sets[1] then selectedSetIndex = 1 end
        local pages = setPageCount()
        ui.setPage = math.max(1, math.min(ui.setPage, pages))
        ui.setPageLabel:SetText(string.format("%d / %d", ui.setPage, pages))
        local first = ((ui.setPage - 1) * SETTINGS.pageSize) + 1
        for i, row in ipairs(ui.setRows) do
            local index = first + i - 1
            local set = settings.gear_sets[index]
            row.index = index
            if set then
                row.name:SetText(shortText(set.name, 28))
                row.select:SetTone(index == selectedSetIndex and COLORS.active or COLORS.button)
                if row.show then
                    local shown = set.showOnFloat ~= false
                    row.show:SetCleanText(shown and "Show ON" or "Show OFF")
                    row.show:SetTone(shown and COLORS.active or COLORS.button)
                end
                row.root:Show(true)
            else
                row.root:Show(false)
            end
        end
        ui.selectedLabel:SetText("Selected: " .. shortText(selectedLoadout() and selectedLoadout().name or "-", 40))
        local function triggerText(trigger)
            if not trigger or trigger.enabled == false then return "-" end
            local name = trigger.loadoutName or "-"
            if name == "" then name = "-" end
            return shortText(name, 20)
        end
        if ui.swimSelect then ui.swimSelect:SetCleanText(triggerText(settings.autoTriggers.swimming)) end
        if ui.swimBlockBtn then
            local blocked = settings.autoTriggers.swimming.blockFreedichGrowlgate ~= false
            ui.swimBlockBtn:SetCleanText(blocked and "FD/GG Block" or "FD/GG Allow")
            ui.swimBlockBtn:SetTone(blocked and COLORS.active or COLORS.button)
        end
        if ui.captainSelect then ui.captainSelect:SetCleanText(triggerText(settings.autoTriggers.captain)) end
        if ui.sleepSelect then ui.sleepSelect:SetCleanText(triggerText(settings.autoTriggers.sleep)) end
        if ui.wakeupSelect then ui.wakeupSelect:SetCleanText(triggerText(settings.autoTriggers.wakeup)) end
        if ui.triggerDropdown and ui.triggerDropdown.IsVisible and ui.triggerDropdown:IsVisible() and refreshTriggerDropdown then refreshTriggerDropdown() end
        refreshCustom()
        refreshDetected()
    end

    refreshTriggerDropdown = function()
        if not ui.triggerDropdown or not triggerDropdownKey then return end
        local pageSize = 3
        local pages = math.max(1, math.ceil(#settings.gear_sets / pageSize))
        triggerDropdownPage = math.max(1, math.min(triggerDropdownPage, pages))
        ui.triggerDropdownTitle:SetText(triggerLabel(triggerDropdownKey))
        ui.triggerDropdownPage:SetText(string.format("%d / %d", triggerDropdownPage, pages))
        local first = ((triggerDropdownPage - 1) * pageSize) + 1
        local trigger = dropdownTrigger()
        local current = trigger and trigger.loadoutName or ""
        for i, row in ipairs(ui.triggerDropdownRows or {}) do
            local set = settings.gear_sets[first + i - 1]
            row.index = first + i - 1
            if set then
                row.button:SetCleanText(shortText(set.name or "Set", 22))
                row.button:SetTone(current == set.name and COLORS.active or COLORS.button)
                row.button:Show(true)
            else
                row.button:Show(false)
            end
        end
    end
    local function closeTriggerDropdown()
        triggerDropdownKey = nil
        triggerDropdownCustomIndex = nil
        if ui.triggerDropdown then ui.triggerDropdown:Show(false) end
    end
    local function assignTriggerGearset(key, set)
        local trigger = dropdownTrigger()
        if not trigger or not set then return end
        local labelText = triggerLabel(key)
        trigger.loadoutName = tostring(set.name or "")
        trigger.enabled = trigger.loadoutName ~= ""
        saveSettings()
        closeTriggerDropdown()
        refreshAll()
        setStatus("Assigned " .. labelText .. " to " .. tostring(set.name or "gear set") .. ".", false)
    end
    local function clearTriggerGearset(key)
        local trigger = dropdownTrigger()
        if not trigger then return end
        local labelText = triggerLabel(key)
        trigger.loadoutName = ""
        trigger.enabled = false
        saveSettings()
        closeTriggerDropdown()
        refreshAll()
        setStatus("Cleared " .. labelText .. " trigger.", false)
    end
    local function openTriggerDropdown(key, x, y, customIndex)
        triggerDropdownKey = key
        triggerDropdownCustomIndex = customIndex
        triggerDropdownPage = 1
        if ui.triggerDropdown then
            ui.triggerDropdown:RemoveAllAnchors()
            ui.triggerDropdown:AddAnchor("TOPLEFT", ui.autoPanel, x, y)
            ui.triggerDropdown:Show(true)
            if ui.triggerDropdown.Raise then ui.triggerDropdown:Raise() end
        end
        refreshTriggerDropdown()
    end

    flatButton(savePanel, "power_ranger_hot_swap_save_button", "Save", SETTINGS.actionX, 54, SETTINGS.actionW, 24, COLORS.active, function()
        saveCurrentSet(ui.nameInput, refreshAll)
    end, ALIGN.CENTER)
    ui.selectedLabel = label(ui.managePanel, "power_ranger_hs_selected", "Selected: -", 16, 34, 340, 14, 10, COLORS.muted, ALIGN.LEFT)
    for i = 1, SETTINGS.pageSize do
        local root = ui.managePanel:CreateChildWidget("emptywidget", "power_ranger_hs_set_row_" .. i, 0, true)
        root:SetExtent(556, 24)
        root:AddAnchor("TOPLEFT", ui.managePanel, 16, 58 + ((i - 1) * 25))
        local bg = root:CreateColorDrawable(i % 2 == 0 and 0.12 or 0.08, i % 2 == 0 and 0.12 or 0.08, i % 2 == 0 and 0.135 or 0.095, 0.72, "background")
        bg:AddAnchor("TOPLEFT", root, 0, 0)
        bg:AddAnchor("BOTTOMRIGHT", root, 0, 0)
        bg:Show(true)
        local row = { root = root }
        row.name = label(root, "power_ranger_hs_set_name_" .. i, "", 8, 5, 224, 14, 10, COLORS.white, ALIGN.LEFT)
        row.select = flatButton(root, "power_ranger_hs_set_select_" .. i, "Edit", 240, 2, 58, 20, COLORS.button, function()
            selectedSetIndex = ui.setRows[i].index
            refreshAll()
        end, ALIGN.CENTER)
        row.view = flatButton(root, "power_ranger_hs_set_view_" .. i, "View", 306, 2, 46, 20, COLORS.button, function()
            local set = settings.gear_sets[ui.setRows[i].index]
            if set then
                openGearView(set)
            end
        end, ALIGN.CENTER)
        row.update = flatButton(root, "power_ranger_hs_set_update_" .. i, "Upd", 360, 2, 42, 20, COLORS.active, function()
            local set = settings.gear_sets[ui.setRows[i].index]
            if set then
                local count = updateSetFromEquipped(set)
                saveSettings()
                refreshMain()
                refreshAll()
                setStatus("Updated " .. tostring(set.name or "set") .. " from " .. tostring(count) .. " equipped slots.", false)
            end
        end, ALIGN.CENTER)
        row.delete = flatButton(root, "power_ranger_hs_set_delete_" .. i, "Del", 410, 2, 42, 20, COLORS.danger, function()
            if settings.gear_sets[ui.setRows[i].index] then
                table.remove(settings.gear_sets, ui.setRows[i].index)
                selectedSetIndex = nil
                saveSettings()
                refreshMain()
                refreshAll()
            end
        end, ALIGN.CENTER)
        row.show = flatButton(root, "power_ranger_hs_set_show_" .. i, "Show ON", 458, 2, 90, 20, COLORS.active, function()
            local set = settings.gear_sets[ui.setRows[i].index]
            if set then
                set.showOnFloat = set.showOnFloat == false
                saveSettings()
                refreshMain()
                refreshAll()
            end
        end, ALIGN.CENTER)
        ui.setRows[i] = row
    end
    flatButton(ui.managePanel, "power_ranger_hs_set_prev", "<", 16, 194, 34, 22, COLORS.button, function() ui.setPage = math.max(1, ui.setPage - 1) refreshAll() end, ALIGN.CENTER)
    ui.setPageLabel = label(ui.managePanel, "power_ranger_hs_set_page", "1 / 1", 58, 198, 66, 14, 10, COLORS.muted, ALIGN.CENTER)
    flatButton(ui.managePanel, "power_ranger_hs_set_next", ">", 132, 194, 34, 22, COLORS.button, function() ui.setPage = ui.setPage + 1 refreshAll() end, ALIGN.CENTER)
    local function directionText() return settings.open_direction == "up" and "Open Up" or "Open Down" end
    ui.direction = flatButton(ui.managePanel, "power_ranger_hot_swap_direction_button", directionText(), SETTINGS.actionX, 32, SETTINGS.actionW, 22, COLORS.button, function()
        settings.open_direction = settings.open_direction == "up" and "down" or "up"
        saveSettings()
        refreshMain()
        ui.direction:SetCleanText(directionText())
    end, ALIGN.CENTER)

    label(ui.autoPanel, "power_ranger_hs_auto_hint", "Pick a gear set per trigger. Auto swaps wait for combat.", 16, 34, 390, 14, 10, COLORS.muted, ALIGN.LEFT)
    label(ui.autoPanel, "power_ranger_hs_auto_swim_label", "Swim", 16, 58, 50, 14, 10, COLORS.muted, ALIGN.LEFT)
    ui.swimSelect = flatButton(ui.autoPanel, "power_ranger_hs_auto_swim_select", "-", 76, 54, 142, 20, COLORS.button, function()
        openTriggerDropdown("swimming", 76, 76)
    end, ALIGN.CENTER)
    ui.swimBlockBtn = flatButton(ui.autoPanel, "power_ranger_hs_auto_swim_block", "", 414, 54, 106, 20, COLORS.active, function()
        settings.autoTriggers.swimming.blockFreedichGrowlgate = settings.autoTriggers.swimming.blockFreedichGrowlgate == false
        saveSettings()
        refreshAll()
    end, ALIGN.CENTER)
    label(ui.autoPanel, "power_ranger_hs_auto_captain_label", "Captain", 236, 58, 62, 14, 10, COLORS.muted, ALIGN.LEFT)
    ui.captainSelect = flatButton(ui.autoPanel, "power_ranger_hs_auto_captain_select", "-", 302, 54, 100, 20, COLORS.button, function()
        openTriggerDropdown("captain", 302, 76)
    end, ALIGN.CENTER)
    label(ui.autoPanel, "power_ranger_hs_auto_sleep_label", "Sleep", 16, 82, 50, 14, 10, COLORS.muted, ALIGN.LEFT)
    ui.sleepSelect = flatButton(ui.autoPanel, "power_ranger_hs_auto_sleep_select", "-", 76, 78, 142, 20, COLORS.button, function()
        openTriggerDropdown("sleep", 76, 76)
    end, ALIGN.CENTER)
    label(ui.autoPanel, "power_ranger_hs_auto_wakeup_label", "WakeUp", 236, 82, 62, 14, 10, COLORS.muted, ALIGN.LEFT)
    ui.wakeupSelect = flatButton(ui.autoPanel, "power_ranger_hs_auto_wakeup_select", "-", 302, 78, 100, 20, COLORS.button, function()
        openTriggerDropdown("wakeup", 302, 76)
    end, ALIGN.CENTER)
    ui.triggerDropdown = ui.autoPanel:CreateChildWidget("emptywidget", "power_ranger_hs_trigger_dropdown", 0, true)
    ui.triggerDropdown:SetExtent(212, 108)
    local dropdownBg = ui.triggerDropdown:CreateColorDrawable(0.035, 0.035, 0.042, 0.98, "background")
    dropdownBg:AddAnchor("TOPLEFT", ui.triggerDropdown, 0, 0)
    dropdownBg:AddAnchor("BOTTOMRIGHT", ui.triggerDropdown, 0, 0)
    dropdownBg:Show(true)
    ui.triggerDropdownTitle = label(ui.triggerDropdown, "power_ranger_hs_trigger_dropdown_title", "", 8, 6, 112, 14, 10, COLORS.gold, ALIGN.LEFT)
    ui.triggerDropdownRows = {}
    for i = 1, 3 do
        local row = {}
        row.button = flatButton(ui.triggerDropdown, "power_ranger_hs_trigger_dropdown_row_" .. i, "", 8, 22 + ((i - 1) * 21), 196, 19, COLORS.button, function()
            local set = settings.gear_sets[ui.triggerDropdownRows[i].index]
            if triggerDropdownKey and set then assignTriggerGearset(triggerDropdownKey, set) end
        end, ALIGN.CENTER)
        ui.triggerDropdownRows[i] = row
    end
    flatButton(ui.triggerDropdown, "power_ranger_hs_trigger_dropdown_clear", "Clear", 8, 90, 52, 18, COLORS.danger, function()
        if triggerDropdownKey then clearTriggerGearset(triggerDropdownKey) end
    end, ALIGN.CENTER)
    flatButton(ui.triggerDropdown, "power_ranger_hs_trigger_dropdown_prev", "<", 118, 90, 24, 18, COLORS.button, function()
        triggerDropdownPage = math.max(1, triggerDropdownPage - 1)
        refreshTriggerDropdown()
    end, ALIGN.CENTER)
    ui.triggerDropdownPage = label(ui.triggerDropdown, "power_ranger_hs_trigger_dropdown_page", "1 / 1", 144, 93, 42, 12, 9, COLORS.muted, ALIGN.CENTER)
    flatButton(ui.triggerDropdown, "power_ranger_hs_trigger_dropdown_next", ">", 188, 90, 24, 18, COLORS.button, function()
        triggerDropdownPage = triggerDropdownPage + 1
        refreshTriggerDropdown()
    end, ALIGN.CENTER)
    ui.triggerDropdown:Show(false)
    label(ui.autoPanel, "power_ranger_hs_custom_title", "Custom Triggers", 16, 110, 120, 14, 10, COLORS.gold, ALIGN.LEFT)
    for i = 1, SETTINGS.customPageSize do
        local root = ui.autoPanel:CreateChildWidget("emptywidget", "power_ranger_hs_custom_row_" .. i, 0, true)
        root:SetExtent(556, 20)
        root:AddAnchor("TOPLEFT", ui.autoPanel, 16, 132 + ((i - 1) * 21))
        local row = { root = root }
        row.name = label(root, "power_ranger_hs_custom_name_" .. i, "", 0, 3, 154, 12, 9, COLORS.white, ALIGN.LEFT)
        row.gear = label(root, "power_ranger_hs_custom_gear_" .. i, "", 162, 3, 112, 12, 9, COLORS.muted, ALIGN.LEFT)
        flatButton(root, "power_ranger_hs_custom_set_" .. i, "Gear", 282, 0, 48, 18, COLORS.blue, function()
            local index = ui.customRows[i].index
            local entry = settings.customAuras[index]
            if not entry then return end
            openTriggerDropdown("custom", 282, 76, index)
        end, ALIGN.CENTER)
        row.bind = flatButton(root, "power_ranger_hs_custom_bind_" .. i, "Bind", 338, 0, 48, 18, COLORS.button, function()
            local entry = settings.customAuras[ui.customRows[i].index]
            if not entry then return end
            selectedCustomIndex = ui.customRows[i].index
            setStatus("Selected trigger for binding: " .. tostring(entry.name or entry.query or "Custom") .. ".", false)
            refreshAll()
        end, ALIGN.CENTER)
        flatButton(root, "power_ranger_hs_custom_del_" .. i, "Del", 394, 0, 42, 18, COLORS.danger, function()
            local index = ui.customRows[i].index
            if settings.customAuras[index] then
                table.remove(settings.customAuras, index)
                selectedCustomIndex = nil
                saveSettings()
                refreshAll()
            end
        end, ALIGN.CENTER)
        ui.customRows[i] = row
    end
    flatButton(ui.autoPanel, "power_ranger_hs_custom_prev", "<", 482, 108, 24, 18, COLORS.button, function() customPage = math.max(1, customPage - 1) refreshAll() end, ALIGN.CENTER)
    ui.customPage = label(ui.autoPanel, "power_ranger_hs_custom_page", "1 / 1", 508, 112, 42, 12, 9, COLORS.muted, ALIGN.CENTER)
    flatButton(ui.autoPanel, "power_ranger_hs_custom_next", ">", 548, 108, 24, 18, COLORS.button, function() customPage = customPage + 1 refreshAll() end, ALIGN.CENTER)

    label(ui.detectedPanel, "power_ranger_hs_detected_hint", "Uses the same detected buff log. Add a buff here, then assign a gear set above.", 16, 34, 450, 14, 10, COLORS.muted, ALIGN.LEFT)
    for i = 1, SETTINGS.detectedPageSize do
        local root = ui.detectedPanel:CreateChildWidget("emptywidget", "power_ranger_hs_detected_row_" .. i, 0, true)
        root:SetExtent(556, 28)
        root:AddAnchor("TOPLEFT", ui.detectedPanel, 16, 58 + ((i - 1) * 31))
        local bg = root:CreateColorDrawable(i % 2 == 0 and 0.12 or 0.08, i % 2 == 0 and 0.12 or 0.08, i % 2 == 0 and 0.135 or 0.095, 0.72, "background")
        bg:AddAnchor("TOPLEFT", root, 0, 0)
        bg:AddAnchor("BOTTOMRIGHT", root, 0, 0)
        bg:Show(true)
        local row = { root = root }
        row.name = label(root, "power_ranger_hs_detected_name_" .. i, "", 8, 6, 220, 14, 10, COLORS.white, ALIGN.LEFT)
        row.meta = label(root, "power_ranger_hs_detected_meta_" .. i, "", 236, 6, 84, 14, 10, COLORS.muted, ALIGN.LEFT)
        row.add = flatButton(root, "power_ranger_hs_detected_add_" .. i, "Add", 328, 3, 54, 22, COLORS.blue, function()
            local detected = ui.detectedRows[i].row
            if detected then HotSwap.ToggleCustomAura(detected) end
        end, ALIGN.CENTER)
        ui.detectedRows[i] = row
    end
    flatButton(ui.detectedPanel, "power_ranger_hs_detected_prev", "<", 16, 158, 34, 22, COLORS.button, function() detectedPage = math.max(1, detectedPage - 1) refreshAll() end, ALIGN.CENTER)
    ui.detectedPage = label(ui.detectedPanel, "power_ranger_hs_detected_page", "1 / 1", 58, 162, 66, 14, 10, COLORS.muted, ALIGN.CENTER)
    flatButton(ui.detectedPanel, "power_ranger_hs_detected_next", ">", 132, 158, 34, 22, COLORS.button, function() detectedPage = detectedPage + 1 refreshAll() end, ALIGN.CENTER)
    ui.refreshAll = refreshAll
    refreshAll()
end

function createSettingsWindow()
    if settingsWnd then return end
    settingsWnd = api.Interface:CreateEmptyWindow("powerRangerHotSwapSettingsWindow", "UIParent")
    settingsWnd:SetExtent(SETTINGS.width, SETTINGS.height)
    local x, y = safePosition(settings.settings_x or SETTINGS.defaultX, settings.settings_y or SETTINGS.defaultY, SETTINGS.width, SETTINGS.height)
    settingsWnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    local outer = settingsWnd:CreateColorDrawable(0, 0, 0, 0.96, "background")
    outer:AddAnchor("TOPLEFT", settingsWnd, 0, 0)
    outer:AddAnchor("BOTTOMRIGHT", settingsWnd, 0, 0)
    outer:Show(true)
    local body = settingsWnd:CreateColorDrawable(COLORS.dark[1], COLORS.dark[2], COLORS.dark[3], COLORS.dark[4], "background")
    body:AddAnchor("TOPLEFT", settingsWnd, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", settingsWnd, -1, -1)
    body:Show(true)
    local header = settingsWnd:CreateColorDrawable(COLORS.settingsHeader[1], COLORS.settingsHeader[2], COLORS.settingsHeader[3], COLORS.settingsHeader[4], "background")
    header:SetExtent(SETTINGS.width - 2, 34)
    header:AddAnchor("TOPLEFT", settingsWnd, 1, 1)
    header:Show(true)
    label(settingsWnd, "power_ranger_hot_swap_settings_title", "Power Ranger Hot Swap", 16, 8, 320, 18, 14, COLORS.gold, ALIGN.LEFT)
    flatButton(settingsWnd, "power_ranger_hot_swap_settings_close", "X", SETTINGS.width - 36, 7, 22, 22, COLORS.button, function()
        settingsShown = false
        settingsWnd:Show(false)
    end, ALIGN.CENTER)

    settingsWnd:SetHandler("OnDragStart", function()
        settingsWnd:StartMoving()
        api.Cursor:ClearCursor()
        api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
    end)
    local function onDragStop()
        settingsWnd:StopMovingOrSizing()
        api.Cursor:ClearCursor()
        saveSettingsPosition()
    end
    settingsWnd:SetHandler("OnDragStop", onDragStop)
    settingsWnd:SetHandler("OnDragEnd", onDragStop)
    settingsWnd:EnableDrag(true)
    if settingsWnd.RegisterForDrag then settingsWnd:RegisterForDrag("LeftButton") end
    addSettingsControls()
    settingsWnd:Show(settingsShown)
    if settingsWnd.hotSwapUi and settingsWnd.hotSwapUi.refreshAll then
        settingsWnd.hotSwapUi.refreshAll()
    end
end

function HotSwap.toggleSettings()
    if not settings and not ensureSettings() then return end
    createSettingsWindow()
    settingsShown = not settingsShown
    settingsWnd:Show(settingsShown)
    if settingsShown and settingsWnd.hotSwapUi and settingsWnd.hotSwapUi.refreshAll then
        settingsWnd.hotSwapUi.refreshAll()
    end
end

function HotSwap.RefreshSettings()
    if not settingsWnd or not settingsWnd.hotSwapUi or not settingsWnd.hotSwapUi.refreshAll then return end
    settingsWnd.hotSwapUi.refreshAll()
end

function HotSwap.IsEnabled()
    if not settings and not ensureSettings() then return false end
    return settings.enabled ~= false
end

function HotSwap.IsFloatShown()
    if not settings and not ensureSettings() then return false end
    return settings.floatShown ~= false
end

function HotSwap.SetEnabled(value)
    if not settings and not ensureSettings() then return end
    settings.enabled = value ~= false
    if settings.enabled == false then
        settings.floatShown = false
        gearQueue = {}
        pendingTitle = nil
        pendingCheck = nil
        autoActiveKey = nil
    end
    saveSettings()
    refreshMain()
    HotSwap.RefreshSettings()
end

function HotSwap.SetFloatShown(value)
    if not settings and not ensureSettings() then return end
    settings.floatShown = value ~= false
    saveSettings()
    refreshMain()
    HotSwap.RefreshSettings()
end

function HotSwap.update(dt)
    if not settings then return end
    if settings.enabled == false then return end
    processAutoTriggers(dt)
    if #gearQueue > 0 then
        for _, button in ipairs(buttons) do button:Enable(false) end
        queueDelay = queueDelay + (tonumber(dt) or 0)
        if queueDelay >= QUEUE_DELAY_MS then
            queueDelay = 0
            local item = table.remove(gearQueue, 1)
            if item and api.Bag and api.Bag.EquipBagItem then
                safeCall(function() api.Bag:EquipBagItem(item.pos, item.alternative or false) end)
            end
            if #gearQueue == 0 then
                for _, button in ipairs(buttons) do button:Enable(true) end
                pendingCheckDelay = 0
            end
        end
    elseif pendingTitle ~= nil then
        titleDelay = titleDelay + (tonumber(dt) or 0)
        if titleDelay >= TITLE_RETRY_DELAY_MS then
            switchTitle(pendingTitle)
            titleAttempts = titleAttempts + 1
            titleDelay = 0
            if titleAttempts >= TITLE_RETRY_COUNT then
                pendingTitle = nil
                titleAttempts = 0
            end
        end
    elseif pendingCheck ~= nil then
        pendingCheckDelay = pendingCheckDelay + (tonumber(dt) or 0)
        if pendingCheckDelay >= EQUIP_VERIFY_DELAY_MS then
            local check = pendingCheck
            pendingCheck = nil
            pendingCheckDelay = 0
            verifyLoadout(check.loadout)
        end
    end
end

function HotSwap.init(sourceSettings, saveCallback, rootProvider, profileKeyProviderArg)
    persistSettings = saveCallback
    accountRootProvider = rootProvider
    profileKeyProvider = profileKeyProviderArg
    if not ensureSettings(sourceSettings) then return end
    HotSwap.createMain()
end

function HotSwap.cleanup()
    HotSwap.destroyMain()
    if settingsWnd then
        api.Interface:Free(settingsWnd)
        settingsWnd = nil
    end
    closeGearView()
    settingsShown = false
    pendingCheck = nil
    pendingCheckDelay = 0
    autoElapsed = 0
    autoActiveKey = nil
    persistSettings = nil
    accountRootProvider = nil
    profileKeyProvider = nil
end

return HotSwap
