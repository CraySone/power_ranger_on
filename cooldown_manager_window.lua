local api = require("api")
local OverlayUtils = require("power_ranger_on/overlay_utils")

local Manager = {}
local windows = {}

local ROWS_PER_PAGE = 8

local function shortText(value, maxLen)
    if OverlayUtils and OverlayUtils.shortText then return OverlayUtils.shortText(value, maxLen) end
    value = tostring(value or "")
    if #value <= maxLen then return value end
    return string.sub(value, 1, math.max(1, maxLen - 1)) .. "."
end

local function tone(disabled, normal)
    if disabled then return {0.08, 0.08, 0.09, 0.95} end
    return normal
end

local function releaseWindow(group)
    local state = windows[group]
    if not state then return end
    local owner = state.owner
    if owner then
        if group == "glider" then
            owner.cooldownGliderRows = nil
            owner.cooldownGliderPageLabel = nil
            owner.cooldownGliderPrevBtn = nil
            owner.cooldownGliderNextBtn = nil
            owner.cooldownGliderShowAllBtn = nil
        else
            owner.cooldownOtherRows = nil
            owner.cooldownOtherPageLabel = nil
            owner.cooldownOtherPrevBtn = nil
            owner.cooldownOtherNextBtn = nil
            owner.cooldownOtherShowAllBtn = nil
        end
    end
    pcall(function() api.Interface:Free(state.wnd) end)
    windows[group] = nil
end

local function buildRows(state)
    local ctx = state.ctx
    local group = state.group
    local wnd = state.wnd
    local rows = {}
    for i = 1, ROWS_PER_PAGE do
        local y = 76 + ((i - 1) * 32)
        local root = wnd:CreateChildWidget("emptywidget", "power_ranger_cd_manager_" .. group .. "_row_" .. i, 0, true)
        root:SetExtent(566, 28)
        root:AddAnchor("TOPLEFT", wnd, 16, y)
        local stripe = i % 2 == 0 and 0.11 or 0.075
        local bg = root:CreateColorDrawable(stripe, stripe, stripe + 0.015, 0.78, "background")
        bg:AddAnchor("TOPLEFT", root, 0, 0)
        bg:AddAnchor("BOTTOMRIGHT", root, 0, 0)
        bg:Show(true)
        local icon = ctx.createIcon(root, "power_ranger_cd_manager_" .. group .. "_icon_" .. i, 3, 3, 22)
        local name = ctx.label(root, "power_ranger_cd_manager_" .. group .. "_name_" .. i, "", 32, 7, 178, 14, 10, ctx.colors.white, ALIGN.LEFT)
        local source = ctx.label(root, "power_ranger_cd_manager_" .. group .. "_source_" .. i, "", 214, 7, 72, 14, 10, ctx.colors.muted, ALIGN.LEFT)
        local info = ctx.flatButton(root, "power_ranger_cd_manager_" .. group .. "_info_" .. i, "Info", 292, 3, 42, 22, ctx.colors.blue, function()
            ctx.openCooldownSkillsWindow(i, group, "info")
        end, ALIGN.CENTER)
        local up = ctx.flatButton(root, "power_ranger_cd_manager_" .. group .. "_up_" .. i, "^", 338, 3, 26, 22, ctx.colors.button, function()
            ctx.moveCooldownSetting(i, -1, group)
        end, ALIGN.CENTER)
        local down = ctx.flatButton(root, "power_ranger_cd_manager_" .. group .. "_down_" .. i, "v", 368, 3, 26, 22, ctx.colors.button, function()
            ctx.moveCooldownSetting(i, 1, group)
        end, ALIGN.CENTER)
        local skills = ctx.flatButton(root, "power_ranger_cd_manager_" .. group .. "_skills_" .. i, "Skills", 398, 3, 52, 22, ctx.colors.blue, function()
            ctx.openCooldownSkillsWindow(i, group, "skills")
        end, ALIGN.CENTER)
        local show = ctx.flatButton(root, "power_ranger_cd_manager_" .. group .. "_show_" .. i, "", 454, 3, 58, 22, ctx.colors.active, function()
            ctx.toggleCooldownSetting(i, group)
        end, ALIGN.CENTER)
        local del = ctx.flatButton(root, "power_ranger_cd_manager_" .. group .. "_del_" .. i, "Del", 516, 3, 38, 22, ctx.colors.danger, function()
            ctx.removeCooldownSetting(i, group)
        end, ALIGN.CENTER)
        name:Clickable(false)
        source:Clickable(false)
        rows[i] = { root = root, icon = icon, name = name, source = source, info = info, up = up, down = down, skills = skills, button = show, del = del }
    end
    return rows
end

function Manager.Open(ctx, group)
    group = group == "glider" and "glider" or "other"
    if windows[group] and windows[group].wnd then
        windows[group].wnd:Show(true)
        if windows[group].wnd.Raise then windows[group].wnd:Raise() end
        if ctx.refreshSettingsButtons then ctx.refreshSettingsButtons() end
        return
    end

    local title = group == "glider" and "Glider Cooldowns" or "Mount & Skill Cooldowns"
    local wnd = api.Interface:CreateEmptyWindow("powerRangerCooldownManager_" .. group, "UIParent")
    wnd:SetExtent(598, 356)
    local keyPrefix = "cooldownManager" .. group
    local settings = ctx.settings or {}
    local x, y = settings[keyPrefix .. "X"] or 680, settings[keyPrefix .. "Y"] or 260
    if ctx.safePosition then x, y = ctx.safePosition(x, y, 598, 356) end
    wnd:AddAnchor("TOPLEFT", "UIParent", x, y)

    local outer = wnd:CreateColorDrawable(0, 0, 0, 0.96, "background")
    outer:AddAnchor("TOPLEFT", wnd, 0, 0)
    outer:AddAnchor("BOTTOMRIGHT", wnd, 0, 0)
    outer:Show(true)
    local body = wnd:CreateColorDrawable(0.055, 0.06, 0.07, 0.96, "background")
    body:AddAnchor("TOPLEFT", wnd, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", wnd, -1, -1)
    body:Show(true)
    local header = wnd:CreateColorDrawable(0.13, 0.15, 0.18, 0.96, "background")
    header:SetExtent(596, 34)
    header:AddAnchor("TOPLEFT", wnd, 1, 1)
    header:Show(true)

    ctx.label(wnd, "power_ranger_cd_manager_title_" .. group, title, 16, 8, 250, 18, 13, ctx.colors.gold, ALIGN.LEFT)
    local showAll = ctx.flatButton(wnd, "power_ranger_cd_manager_show_all_" .. group, "Show All", 292, 7, 84, 22, ctx.colors.active, function()
        ctx.toggleCooldownGroup(group)
    end, ALIGN.CENTER)
    local prev = ctx.flatButton(wnd, "power_ranger_cd_manager_prev_" .. group, "<", 386, 7, 28, 22, ctx.colors.button, function()
        ctx.shiftCooldownSettingsPage(-1, group)
    end, ALIGN.CENTER)
    local page = ctx.label(wnd, "power_ranger_cd_manager_page_" .. group, "", 420, 10, 106, 14, 10, ctx.colors.muted, ALIGN.CENTER)
    local next = ctx.flatButton(wnd, "power_ranger_cd_manager_next_" .. group, ">", 532, 7, 28, 22, ctx.colors.button, function()
        ctx.shiftCooldownSettingsPage(1, group)
    end, ALIGN.CENTER)
    ctx.flatButton(wnd, "power_ranger_cd_manager_close_" .. group, "X", 566, 7, 22, 22, ctx.colors.button, function()
        releaseWindow(group)
    end, ALIGN.CENTER)
    local dragHandle = wnd:CreateChildWidget("emptywidget", "power_ranger_cd_manager_drag_" .. group, 0, true)
    dragHandle:SetExtent(280, 34)
    dragHandle:AddAnchor("TOPLEFT", wnd, 1, 1)
    dragHandle:Show(true)
    if ctx.applyDrag then ctx.applyDrag(wnd, dragHandle, keyPrefix .. "X", keyPrefix .. "Y", true) end

    ctx.label(wnd, "power_ranger_cd_manager_hint_" .. group, "Sort, show, delete, and open per-device skills from here.", 16, 46, 410, 14, 10, ctx.colors.muted, ALIGN.LEFT)

    local state = { wnd = wnd, owner = ctx.owner, ctx = ctx, group = group }
    windows[group] = state
    local rows = buildRows(state)
    state.rows = rows
    if group == "glider" then
        ctx.owner.cooldownGliderRows = rows
        ctx.owner.cooldownGliderPageLabel = page
        ctx.owner.cooldownGliderPrevBtn = prev
        ctx.owner.cooldownGliderNextBtn = next
        ctx.owner.cooldownGliderShowAllBtn = showAll
    else
        ctx.owner.cooldownOtherRows = rows
        ctx.owner.cooldownOtherPageLabel = page
        ctx.owner.cooldownOtherPrevBtn = prev
        ctx.owner.cooldownOtherNextBtn = next
        ctx.owner.cooldownOtherShowAllBtn = showAll
    end
    wnd:Show(true)
    if ctx.refreshSettingsButtons then ctx.refreshSettingsButtons() end
end

function Manager.Cleanup()
    releaseWindow("glider")
    releaseWindow("other")
end

return Manager
