local OverlayUtils = require("power_ranger_on/overlay_utils")

local DetectedSkills = {}

local function short(value, maxLen)
    value = tostring(value or "-")
    if #value <= maxLen then return value end
    return value:sub(1, maxLen - 3) .. "..."
end

function DetectedSkills.DetailText(row)
    if not row then return "Select a detected row to inspect details." end
    local pieces = {
        "Name: " .. short(row.name or row.pattern, 58),
        "Type: " .. tostring(row.kind or "-"),
        -- formatBuffId: plain tostring is %.6g in this client and shows the SAME string
        -- for distinct 7-digit ids, which made different buffs look identical.
        "ID: " .. (row.id and OverlayUtils.formatBuffId(row.id) or "-"),
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
    if row.gliderItemType then table.insert(pieces, "Glider item: " .. tostring(row.gliderItemType)) end
    if row.mountName then table.insert(pieces, "Mount: " .. short(row.mountName, 58)) end
    if row.mountUnitId then table.insert(pieces, "Mount unit: " .. tostring(row.mountUnitId)) end
    if row.mountItemType then table.insert(pieces, "Mount item: " .. tostring(row.mountItemType)) end
    if row.description and row.description ~= "" then table.insert(pieces, "Desc: " .. short(row.description, 100)) end
    return table.concat(pieces, "\n")
end

function DetectedSkills.ShowDetails(ctx, index)
    local wnd = ctx.window
    if not wnd then return end
    local settings = ctx.settings
    settings.detectedDetailsIndex = index
    local row = settings.detectedSkills and settings.detectedSkills[index]
    if wnd.details then
        wnd.details:SetText(DetectedSkills.DetailText(row))
    end
    ctx.refreshRows()
end

local function detectionSummary(row)
    if not row then return "" end
    local parts = {}
    if row.id then parts[#parts + 1] = "ID " .. OverlayUtils.formatBuffId(row.id) end
    local auraKind = tostring(row.auraKind or row.kind or "")
    local name = row.name or row.pattern
    if auraKind ~= "" and auraKind ~= "skill" then
        local prettyKind = auraKind:sub(1, 1):upper() .. auraKind:sub(2)
        parts[#parts + 1] = prettyKind .. " " .. tostring(name or "-")
    elseif name then
        parts[#parts + 1] = "Skill " .. tostring(name)
    end
    local mana = tonumber(row.manaSpent or row.petManaSpent or row.mountManaSpent)
    local playerMana = tonumber(row.playerManaSpent)
    if mana and mana > 0 then parts[#parts + 1] = "Pet mana " .. tostring(mana) end
    if playerMana and playerMana > 0 then parts[#parts + 1] = "Mana " .. tostring(playerMana) end
    if not mana and not playerMana then parts[#parts + 1] = "Mana -" end
    return table.concat(parts, " | ")
end

local function hasManaTrigger(row)
    local value = tonumber(row and (row.manaSpent or row.petManaSpent or row.mountManaSpent or row.playerManaSpent))
    return value ~= nil and value > 0
end

local function lowerPattern(value)
    value = string.lower(tostring(value or ""))
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    value = value:gsub("%s+", " ")
    return value
end

local function buildTrackedSkill(ctx, row, mode)
    local tracked = {
        enabled = true,
        name = row.name or row.pattern or tostring(row.id),
        pattern = row.pattern or string.lower(tostring(row.name or "")),
        id = row.id,
        icon = row.icon,
        source = row.source,
        category = row.category,
        cooldown = tonumber(row.cooldown) or 30
    }
    if mode == "mount" then
        local mountName = row.mountName or row.source or "Mount"
        local canonical = ctx.canonicalMountDevice and ctx.canonicalMountDevice(mountName)
        local key = canonical and canonical.key
        local name = canonical and canonical.name
        local names = canonical and canonical.names
        tracked.category = "mount"
        tracked.source = name or mountName
        tracked.recipeDeviceKind = "mount"
        tracked.recipeDeviceName = name or mountName
        tracked.recipeDeviceKey = key or ("custom_mount_" .. lowerPattern(mountName))
        tracked.mountName = name or mountName
        tracked.mountNames = names or {mountName}
        tracked.recipeDeviceItemType = canonical and (canonical.displayItemType or canonical.itemType)
        tracked.recipeDeviceIcon = canonical and canonical.icon
    elseif mode == "glider" then
        local gliderName = row.gliderName or row.source or "Glider"
        local canonical = ctx.canonicalGliderDevice and ctx.canonicalGliderDevice(gliderName)
        tracked.category = "glider"
        tracked.source = canonical and canonical.name or gliderName
        tracked.recipeDeviceKind = "glider"
        tracked.recipeDeviceName = canonical and canonical.name or gliderName
        tracked.recipeDeviceKey = canonical and canonical.key or ("custom_glider_" .. lowerPattern(gliderName))
        tracked.gliderPattern = canonical and canonical.patterns or {lowerPattern(gliderName)}
        tracked.itemTypes = canonical and canonical.itemTypes
        tracked.recipeDeviceItemType = canonical and canonical.displayItemType
        tracked.recipeDeviceIcon = canonical and canonical.icon
    end
    return tracked
end

function DetectedSkills.ToggleTracking(ctx, index, mode)
    local settings = ctx.settings
    local row = settings.detectedSkills and settings.detectedSkills[index]
    if not row then return end
    if row.kind == "buff" or ((mode == "glider" or mode == "mount") and hasManaTrigger(row)) then
        settings.trackedBuffs = settings.trackedBuffs or {}
        mode = mode or "aura"
        local trackedIndex = ctx.detectedBuffTrackedIndex(row, mode)
        if trackedIndex then
            local tracked = settings.trackedBuffs[trackedIndex]
            if ctx.trackedBuffIsDefault and ctx.trackedBuffIsDefault(tracked) then
                if row.icon then
                    tracked.icon = row.icon
                    tracked.icon_type = nil
                    tracked.icon_id = nil
                    tracked.iconType = nil
                    tracked.iconId = nil
                end
                if row.mountItemType and not tracked.recipeDeviceItemType then
                    tracked.recipeDeviceItemType = row.mountItemType
                    tracked.recipeDeviceIcon = nil
                end
                if row.gliderItemType and not tracked.recipeDeviceItemType then
                    tracked.recipeDeviceItemType = row.gliderItemType
                    tracked.recipeDeviceIcon = nil
                end
                if row.mountIcon and not tracked.recipeDeviceItemType then tracked.recipeDeviceIcon = row.mountIcon end
                if row.gliderIcon and not tracked.recipeDeviceItemType then tracked.recipeDeviceIcon = row.gliderIcon end
                table.remove(settings.detectedSkills, index)
            else
                ctx.buffState[ctx.trackedBuffKey(tracked)] = nil
                table.remove(settings.trackedBuffs, trackedIndex)
            end
        elseif mode == "aura" and ctx.trackedCooldownIsHardcoded(row.name or row.pattern, row.id) then
            table.remove(settings.detectedSkills, index)
        else
            local recipe = ctx.detectedRecipeRow(row, mode)
            if recipe then
                table.insert(settings.trackedBuffs, recipe)
                if ctx.learnCooldownDevice then ctx.learnCooldownDevice(recipe) end
            end
        end
        ctx.refreshEventSubscriptions()
        ctx.saveSettings()
        ctx.refreshRows()
        ctx.refreshSettingsButtons()
        return
    end

    settings.trackedSkills = settings.trackedSkills or {}
    local trackedIndex = ctx.trackedSkillIndex(row.name or row.pattern, row.id)
    if trackedIndex then
        local tracked = settings.trackedSkills[trackedIndex]
        ctx.clearSkillCooldownForRow(tracked)
        table.remove(settings.trackedSkills, trackedIndex)
    elseif ctx.trackedCooldownIsHardcoded(row.name or row.pattern, row.id) then
        table.remove(settings.detectedSkills, index)
    else
        table.insert(settings.trackedSkills, buildTrackedSkill(ctx, row, mode))
    end
    ctx.refreshEventSubscriptions()
    ctx.saveSettings()
    ctx.refreshRows()
    ctx.refreshSettingsButtons()
end

function DetectedSkills.RefreshRows(ctx)
    local wnd = ctx.window
    local settings = ctx.settings
    if not wnd or not wnd.rows then return end
    local rows = settings.detectedSkills or {}
    for i, ui in ipairs(wnd.rows) do
        local row = rows[i]
        -- Remember WHICH row this slot is showing. New detections prepend to the list
        -- while logging is active, so by the time the user clicks, the visual index can
        -- point at a neighbour. Click handlers resolve through this key instead.
        ui.detectedKey = row and row.key or nil
        if row then
            if row.kind == "buff" then
                ctx.setToggleButton(ui.auraButton, ctx.detectedBuffTrackedIndex(row, "aura") ~= nil, "Aura")
                ctx.setToggleButton(ui.gliderButton, ctx.detectedBuffTrackedIndex(row, "glider") ~= nil, "Glid")
                ctx.setToggleButton(ui.mountButton, ctx.detectedBuffTrackedIndex(row, "mount") ~= nil, "Mount")
                ui.gliderButton:Show(row.kind == "buff" or row.gliderName or row.category == "glider")
                ui.mountButton:Show(row.kind == "buff" or row.mountName or row.category == "mount")
            elseif row.mountName or row.gliderName or row.category == "mount" or row.category == "glider" then
                local skillTracked = ctx.trackedSkillIndex(row.name or row.pattern, row.id) ~= nil
                ctx.setToggleButton(ui.auraButton, skillTracked, "Skill")
                ctx.setToggleButton(ui.gliderButton, skillTracked and (row.gliderName or row.category == "glider"), "Glid")
                ctx.setToggleButton(ui.mountButton, skillTracked and (row.mountName or row.category == "mount"), "Mount")
                ui.gliderButton:Show(row.gliderName ~= nil or row.category == "glider")
                ui.mountButton:Show(row.mountName ~= nil or row.category == "mount")
            else
                ctx.setToggleButton(ui.auraButton, ctx.trackedSkillIndex(row.name or row.pattern, row.id) ~= nil, "Skill")
                ui.gliderButton:Show(false)
                ui.mountButton:Show(false)
            end
            ctx.setEquipIcon(ui.icon, row.icon or (row.kind == "buff" and ctx.buffIconById(row.id) or ctx.skillIconById(row.id)))
            ui.name:SetText(OverlayUtils.shortText(row.name or row.pattern or tostring(row.id or "Unknown"), 17))
            local context = detectionSummary(row)
            if row.gliderName then
                context = context .. " | G:" .. tostring(row.gliderName)
            elseif row.mountName then
                context = context .. " | M:" .. tostring(row.mountName)
            end
            ui.meta:SetText(OverlayUtils.shortText(context, 48))
            ui.seen:SetText("x" .. tostring(row.seen or 1))
            ui.root:Show(true)
        else
            ui.root:Show(false)
        end
    end
end

return DetectedSkills
