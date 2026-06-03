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
    if row.gliderItemType then table.insert(pieces, "Glider item: " .. tostring(row.gliderItemType)) end
    if row.mountName then table.insert(pieces, "Mount: " .. short(row.mountName, 58)) end
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

function DetectedSkills.ToggleTracking(ctx, index, mode)
    local settings = ctx.settings
    local row = settings.detectedSkills and settings.detectedSkills[index]
    if not row then return end
    if row.kind == "buff" then
        settings.trackedBuffs = settings.trackedBuffs or {}
        mode = mode or "aura"
        local trackedIndex = ctx.detectedBuffTrackedIndex(row, mode)
        if trackedIndex then
            ctx.buffState[ctx.trackedBuffKey(settings.trackedBuffs[trackedIndex])] = nil
            table.remove(settings.trackedBuffs, trackedIndex)
        elseif mode == "aura" and ctx.trackedCooldownIsHardcoded(row.name or row.pattern, row.id) then
            table.remove(settings.detectedSkills, index)
        else
            local recipe = ctx.detectedRecipeRow(row, mode)
            if recipe then table.insert(settings.trackedBuffs, recipe) end
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
        if row then
            if row.kind == "buff" then
                ctx.setToggleButton(ui.auraButton, ctx.detectedBuffTrackedIndex(row, "aura") ~= nil, "Aura")
                ctx.setToggleButton(ui.gliderButton, ctx.detectedBuffTrackedIndex(row, "glider") ~= nil, "Glid")
                ctx.setToggleButton(ui.mountButton, ctx.detectedBuffTrackedIndex(row, "mount") ~= nil, "Mount")
                ui.gliderButton:Show(true)
                ui.mountButton:Show(true)
            else
                ctx.setToggleButton(ui.auraButton, ctx.trackedSkillIndex(row.name or row.pattern, row.id) ~= nil, "Skill")
                ui.gliderButton:Show(false)
                ui.mountButton:Show(false)
            end
            ctx.setToggleButton(ui.detailsButton, settings.detectedDetailsIndex == i, "Info")
            ctx.setEquipIcon(ui.icon, row.icon or (row.kind == "buff" and ctx.buffIconById(row.id) or ctx.skillIconById(row.id)))
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
    if wnd.details then
        local detailRow = settings.detectedSkills and settings.detectedSkills[settings.detectedDetailsIndex or 0]
        wnd.details:SetText(DetectedSkills.DetailText(detailRow))
    end
end

return DetectedSkills
