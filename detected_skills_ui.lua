local api = require("api")

local DetectedSkillsUi = {}

function DetectedSkillsUi.Create(ctx)
    local colors = ctx.colors
    local label = ctx.label
    local flatButton = ctx.flatButton
    local panel = ctx.panel
    local createIcon = ctx.createIcon
    local applyDrag = ctx.applyDrag
    local safePosition = ctx.safePosition
    local settings = ctx.settings or {}

    local wnd = api.Interface:CreateEmptyWindow("PowerRangerDetectedSkills", "UIParent")
    wnd:SetExtent(640, 330)
    local x, y = safePosition(settings.detectedSkillsX, settings.detectedSkillsY, 640, 330)
    wnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    local outer = wnd:CreateColorDrawable(0, 0, 0, 0.96, "background")
    outer:AddAnchor("TOPLEFT", wnd, 0, 0)
    outer:AddAnchor("BOTTOMRIGHT", wnd, 0, 0)
    outer:Show(true)
    local body = wnd:CreateColorDrawable(colors.dark[1], colors.dark[2], colors.dark[3], colors.dark[4], "background")
    body:AddAnchor("TOPLEFT", wnd, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", wnd, -1, -1)
    body:Show(true)
    local header = wnd:CreateColorDrawable(0.09, 0.09, 0.11, 0.98, "background")
    header:SetExtent(638, 30)
    header:AddAnchor("TOPLEFT", wnd, 1, 1)
    header:Show(true)
    local title = label(wnd, "power_ranger_detected_title", "Detected Cooldowns", 14, 7, 250, 16, 13, colors.gold, ALIGN.LEFT)
    applyDrag(wnd, title, "detectedSkillsX", "detectedSkillsY")
    flatButton(wnd, "power_ranger_detected_clear", "Clear", 552, 5, 50, 20, colors.danger or colors.button, function()
        if ctx.clearDetected then ctx.clearDetected() end
    end)
    flatButton(wnd, "power_ranger_detected_close", "X", 606, 5, 22, 20, colors.button, function() wnd:Show(false) end)
    label(wnd, "power_ranger_detected_hint", "Rows show ID, buff/debuff name and mana delta. Use Glid/Mount when the current device matters.", 14, 36, 600, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.rows = {}
    for i = 1, 8 do
        local yPos = 56 + ((i - 1) * 31)
        local root = wnd:CreateChildWidget("emptywidget", "power_ranger_detected_row_" .. i, 0, true)
        root:SetExtent(612, 28)
        root:AddAnchor("TOPLEFT", wnd, 14, yPos)
        local tone = i % 2 == 0 and 0.11 or 0.075
        local blueTone = i % 2 == 0 and 0.125 or 0.09
        local bg = root:CreateColorDrawable(tone, tone, blueTone, 0.74, "background")
        bg:AddAnchor("TOPLEFT", root, 0, 0)
        bg:AddAnchor("BOTTOMRIGHT", root, 0, 0)
        bg:Show(true)
        local icon = createIcon(root, "power_ranger_detected_icon_" .. i, 4, 2, 24)
        local name = label(root, "power_ranger_detected_name_" .. i, "", 36, 4, 112, 14, 10, colors.white, ALIGN.LEFT)
        local meta = label(root, "power_ranger_detected_meta_" .. i, "", 152, 4, 274, 14, 10, colors.muted, ALIGN.LEFT)
        local seen = label(root, "power_ranger_detected_seen_" .. i, "", 428, 4, 32, 14, 10, colors.muted, ALIGN.LEFT)
        local rowIndex = i
        local auraBtn = flatButton(root, "power_ranger_detected_aura_" .. i, "", 462, 3, 48, 22, colors.active, function() ctx.toggleTracking(rowIndex, "aura") end)
        local gliderBtn = flatButton(root, "power_ranger_detected_glider_" .. i, "", 512, 3, 50, 22, colors.active, function() ctx.toggleTracking(rowIndex, "glider") end)
        local mountBtn = flatButton(root, "power_ranger_detected_mount_" .. i, "", 564, 3, 44, 22, colors.active, function() ctx.toggleTracking(rowIndex, "mount") end)
        name:Clickable(false)
        meta:Clickable(false)
        seen:Clickable(false)
        wnd.rows[i] = { root = root, icon = icon, name = name, meta = meta, seen = seen, auraButton = auraBtn, gliderButton = gliderBtn, mountButton = mountBtn }
    end
    wnd:Show(false)
    return wnd
end

return DetectedSkillsUi
