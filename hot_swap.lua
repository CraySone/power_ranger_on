local api = require("api")
local UiHelpers = require("power_ranger_on/ui_helpers")
local HotSwapAuras = require("power_ranger_on/hot_swap_auras")

local HotSwap = {}

local ADDON_ID = "power_ranger_on"
local LEGACY_ADDON_ID = "hot_swap"
local QUEUE_DELAY_MS = 250
local TITLE_RETRY_DELAY_MS = 250
local TITLE_RETRY_COUNT = 3
local AUTO_CHECK_MS = 150
local EQUIP_VERIFY_DELAY_MS = 700
local BAG_SLOT_COUNT = 150

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
local selectedSetIndex = nil
local selectedCustomIndex = nil
local gearViewWnd = nil
local customPage = 1
local detectedPage = 1
local selectedLoadout
local createSettingsWindow

local DEFAULT_CUSTOM_TRIGGERS = {
    swimming = { enabled = true, loadoutName = "" },
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

local function copyTable(value, depth)
    if type(value) ~= "table" then return value end
    if (depth or 0) > 6 then return nil end
    local copy = {}
    for k, v in pairs(value) do
        copy[copyTable(k, (depth or 0) + 1)] = copyTable(v, (depth or 0) + 1)
    end
    return copy
end

local function saveSettings()
    safeCall(function() api.SaveSettings() end)
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

local function refreshActiveLabel()
    if canvas and canvas.activeLabel then
        local name = settings and settings.activeLoadoutName or ""
        name = tostring(name or "")
        if #name > 11 then name = name:sub(1, 10) .. "." end
        canvas.activeLabel:SetText(name ~= "" and ("Active: " .. name) or "Active: -")
        if name ~= "" then
            canvas.activeLabel.style:SetColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], COLORS.green[4])
        else
            canvas.activeLabel.style:SetColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], COLORS.muted[4])
        end
    end
end

local function setActiveLoadout(set)
    if not settings or type(set) ~= "table" then return end
    settings.activeLoadoutName = tostring(set.name or "")
    saveSettings()
    refreshActiveLabel()
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
    rootSettings = source or safeCall(function() return api.GetSettings(ADDON_ID) end) or {}
    if type(rootSettings.hotSwap) ~= "table" then rootSettings.hotSwap = {} end
    settings = rootSettings.hotSwap
    if type(settings.gear_sets) ~= "table" then settings.gear_sets = {} end
    ensureAutoSettings()
    if settings.enabled == nil then settings.enabled = true end
    if settings.floatShown == nil then settings.floatShown = true end
    if settings.open_direction ~= "up" then settings.open_direction = "down" end
    if settings.hidden == nil then settings.hidden = false end
    local changed = false
    if settings.migratedFromStandalone ~= true then
        local legacy = safeCall(function() return api.GetSettings(LEGACY_ADDON_ID) end)
        if type(legacy) == "table" and type(legacy.gear_sets) == "table" and #settings.gear_sets == 0 then
            settings.gear_sets = copyTable(legacy.gear_sets) or {}
            settings.x = legacy.x
            settings.y = legacy.y
            settings.hidden = legacy.hidden
            settings.open_direction = legacy.open_direction == "up" and "up" or "down"
            settings.settings_x = legacy.settings_x
            settings.settings_y = legacy.settings_y
        end
        settings.migratedFromStandalone = true
        changed = true
    end
    if convertLegacyLoadouts(settings.gear_sets) then changed = true end
    if changed then saveSettings() end
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
    local button = flatButton(canvas, id, set.name, MAIN.left, rowStartY + ((index - 1) * MAIN.rowStep),
        MAIN.width - (MAIN.left * 2), MAIN.rowH, COLORS.button, function()
            for _, other in ipairs(buttons) do
                other:SetTone(other == button and COLORS.active or COLORS.button)
            end
            queueSet(set)
        end)
    buttons[#buttons + 1] = button
    button:Show(settings.hidden ~= true)
end

function HotSwap.createMain()
    if not settings then ensureSettings() end
    buttons = {}
    gearQueue = {}
    pendingTitle = nil
    titleDelay = 0
    titleAttempts = 0
    queueDelay = 0
    if settings.floatShown == false then return end

    local gearSets = settings.gear_sets or {}
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
    canvas.activeLabel = label(canvas, "power_ranger_hot_swap_active", "", 62, headerWidgetY + 5, 70, 14, 9, COLORS.muted, ALIGN.LEFT)
    canvas.activeLabel:Clickable(false)
    refreshActiveLabel()

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
    if settings.autoTriggers.swimming.enabled ~= false and swimmingActive(buffs, debuffs) then
        local set = gearSetByName(settings.autoTriggers.swimming.loadoutName)
        if set then return "swimming:" .. tostring(set.name), set, "Swimming" end
    end
    if settings.autoTriggers.captain.enabled ~= false and anyAuraMatches(buffs, debuffs, "captain") then
        local set = gearSetByName(settings.autoTriggers.captain.loadoutName)
        if set then return "captain:" .. tostring(set.name), set, "Captain" end
    end
    if settings.autoTriggers.sleep.enabled ~= false and sleepActive(buffs, debuffs) then
        local set = gearSetByName(settings.autoTriggers.sleep.loadoutName)
        if set then return "sleep:" .. tostring(set.name), set, "Deep Sleep" end
    end
    if settings.autoTriggers.wakeup.enabled ~= false and wakeupActive(buffs, debuffs) then
        local set = gearSetByName(settings.autoTriggers.wakeup.loadoutName)
        if set then return "wakeup:" .. tostring(set.name), set, "WakeUp" end
    end
    for _, entry in ipairs(settings.customAuras or {}) do
        if entry.enabled ~= false and customAuraMatches(entry, buffs, debuffs) then
            local set = gearSetByName(entry.loadoutName)
            if set then return "custom:" .. tostring(entry.key or entry.name), set, entry.name or "Custom" end
        end
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
    if not settings then ensureSettings() end
    ensureAutoSettings()
    local key = auraMatchKey(auraMatchFromRow(row)) or customAuraKey(row)
    if not key then return false end
    for _, entry in ipairs(settings.customAuras or {}) do
        if customAuraHasMatch(entry, key) then return true end
    end
    return false
end

function HotSwap.ToggleCustomAura(row)
    if not settings then ensureSettings() end
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
                rowUi.meta:SetText(row.id and ("ID " .. tostring(row.id)) or "buff")
                rowUi.add:SetTone(HotSwap.CustomAuraTracked(row) and COLORS.active or COLORS.blue)
                rowUi.add:SetCleanText(HotSwap.CustomAuraTracked(row) and "Added" or (selectedCustomIndex and "Bind" or "Add"))
                rowUi.root:Show(true)
            else
                rowUi.root:Show(false)
            end
        end
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
                row.root:Show(true)
            else
                row.root:Show(false)
            end
        end
        ui.selectedLabel:SetText("Selected: " .. shortText(selectedLoadout() and selectedLoadout().name or "-", 40))
        local function triggerText(trigger)
            local name = trigger and trigger.loadoutName or "-"
            if name == "" then name = "-" end
            if trigger and trigger.enabled == false and name ~= "-" then name = "OFF: " .. name end
            return shortText(name, 18)
        end
        ui.swimValue:SetText(triggerText(settings.autoTriggers.swimming))
        ui.captainValue:SetText(triggerText(settings.autoTriggers.captain))
        ui.sleepValue:SetText(triggerText(settings.autoTriggers.sleep))
        ui.wakeupValue:SetText(triggerText(settings.autoTriggers.wakeup))
        refreshCustom()
        refreshDetected()
    end

    local function assignOrToggleTrigger(key)
        local set = selectedLoadout()
        if not set then setStatus("Select a gear set first.", true) return end
        local trigger = settings.autoTriggers[key]
        if not trigger then return end
        if trigger.loadoutName == set.name and trigger.enabled ~= false then
            trigger.enabled = false
        else
            trigger.loadoutName = set.name
            trigger.enabled = true
        end
        saveSettings()
        refreshAll()
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

    label(ui.autoPanel, "power_ranger_hs_auto_hint", "Assign selected set to triggers. Auto swaps wait for combat.", 16, 34, 360, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(ui.autoPanel, "power_ranger_hs_auto_swim", "Swim", 16, 54, 54, 20, COLORS.active, function()
        assignOrToggleTrigger("swimming")
    end, ALIGN.CENTER)
    ui.swimValue = label(ui.autoPanel, "power_ranger_hs_auto_swim_value", "-", 76, 58, 100, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(ui.autoPanel, "power_ranger_hs_auto_captain", "Captain", 206, 54, 70, 20, COLORS.active, function()
        assignOrToggleTrigger("captain")
    end, ALIGN.CENTER)
    ui.captainValue = label(ui.autoPanel, "power_ranger_hs_auto_captain_value", "-", 284, 58, 120, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(ui.autoPanel, "power_ranger_hs_auto_sleep", "Sleep", 16, 78, 54, 20, COLORS.active, function()
        assignOrToggleTrigger("sleep")
    end, ALIGN.CENTER)
    ui.sleepValue = label(ui.autoPanel, "power_ranger_hs_auto_sleep_value", "-", 76, 82, 100, 14, 10, COLORS.muted, ALIGN.LEFT)
    flatButton(ui.autoPanel, "power_ranger_hs_auto_wakeup", "WakeUp", 206, 78, 70, 20, COLORS.active, function()
        assignOrToggleTrigger("wakeup")
    end, ALIGN.CENTER)
    ui.wakeupValue = label(ui.autoPanel, "power_ranger_hs_auto_wakeup_value", "-", 284, 82, 120, 14, 10, COLORS.muted, ALIGN.LEFT)
    label(ui.autoPanel, "power_ranger_hs_custom_title", "Custom Triggers", 16, 110, 120, 14, 10, COLORS.gold, ALIGN.LEFT)
    for i = 1, SETTINGS.customPageSize do
        local root = ui.autoPanel:CreateChildWidget("emptywidget", "power_ranger_hs_custom_row_" .. i, 0, true)
        root:SetExtent(556, 20)
        root:AddAnchor("TOPLEFT", ui.autoPanel, 16, 132 + ((i - 1) * 21))
        local row = { root = root }
        row.name = label(root, "power_ranger_hs_custom_name_" .. i, "", 0, 3, 154, 12, 9, COLORS.white, ALIGN.LEFT)
        row.gear = label(root, "power_ranger_hs_custom_gear_" .. i, "", 162, 3, 112, 12, 9, COLORS.muted, ALIGN.LEFT)
        flatButton(root, "power_ranger_hs_custom_set_" .. i, "Gear", 282, 0, 48, 18, COLORS.blue, function()
            local set = selectedLoadout()
            local entry = settings.customAuras[ui.customRows[i].index]
            if not set or not entry then setStatus("Select set and custom buff.", true) return end
            entry.loadoutName = set.name
            entry.enabled = true
            saveSettings()
            refreshAll()
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
    if not settings then ensureSettings() end
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
    if not settings then ensureSettings() end
    return settings.enabled ~= false
end

function HotSwap.IsFloatShown()
    if not settings then ensureSettings() end
    return settings.floatShown ~= false
end

function HotSwap.SetEnabled(value)
    if not settings then ensureSettings() end
    settings.enabled = value ~= false
    if settings.enabled == false then
        gearQueue = {}
        pendingTitle = nil
        pendingCheck = nil
        autoActiveKey = nil
    end
    saveSettings()
    HotSwap.RefreshSettings()
end

function HotSwap.SetFloatShown(value)
    if not settings then ensureSettings() end
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

function HotSwap.init(sourceSettings)
    ensureSettings(sourceSettings)
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
end

return HotSwap
