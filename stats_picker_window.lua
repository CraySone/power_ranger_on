-- Target Stats picker: choose, per class profile, which target stats the intel
-- window shows. Profile chooser on top, stat categories as tabs, zebra toggle rows.
-- Replaces the old inline "Profile stats" grid in the main settings window.

local api = require("api")
local UiHelpers = require("power_ranger_on/ui_helpers")
local ClassIntelProfiles = require("power_ranger_on/class_intel_profiles")
local TargetStatsCatalog = require("power_ranger_on/target_stats_catalog")

local StatsPicker = {
    wnd = nil,
    ctx = nil,
    category = "core"
}

local WIDTH = 560
local HEIGHT = 580
local RED = {0.24, 0.09, 0.09, 0.95}
local OPACITY_TRACK_X = 140
local OPACITY_TRACK_W = 300
local OPACITY_MAX = 20
local MAX_ROWS = 10
local LIST_X = 16
local LIST_Y = 114
local ROW_STEP = 31

local function currentProfileKey(settings)
    return settings.classIntelEditProfile or "general"
end

local function refreshRows()
    local wnd = StatsPicker.wnd
    local ctx = StatsPicker.ctx
    if not wnd or not ctx then return end
    local settings = ctx.settings
    ClassIntelProfiles.Ensure(settings)
    local profileKey = currentProfileKey(settings)
    local profile = settings.classIntelProfiles[profileKey] or {}

    for _, entry in ipairs(wnd.profileButtons) do
        entry.btn:SetTone(entry.key == profileKey and ctx.colors.active or ctx.colors.button)
    end
    for _, entry in ipairs(wnd.categoryButtons) do
        entry.btn:SetTone(entry.key == StatsPicker.category and ctx.colors.blue or ctx.colors.button)
    end
    if wnd.hGapValue then wnd.hGapValue:SetText(tostring(settings.statsColGap or 0)) end
    if wnd.vGapValue then wnd.vGapValue:SetText(tostring(settings.statsRowGap or 0)) end
    if wnd.opacityValue then
        local level = math.max(0, math.min(OPACITY_MAX, tonumber(settings.statsOpacityLevel) or 10))
        wnd.opacityValue:SetText(string.format("%.2f", level / 10))
        if wnd.opacityFill then
            if level > 0 then
                wnd.opacityFill:SetExtent(math.max(1, math.floor((level / OPACITY_MAX) * (OPACITY_TRACK_W - 2))), 14)
                wnd.opacityFill:Show(true)
            else
                wnd.opacityFill:Show(false)
            end
        end
    end

    local stats = TargetStatsCatalog.ByCategory(StatsPicker.category)
    for i = 1, MAX_ROWS do
        local slot = wnd.rows[i]
        local stat = stats[i]
        if stat then
            slot.stat = stat
            slot.label:SetText(stat.label .. (stat.suffix == "%" and " (%)" or ""))
            UiHelpers.SetToggleButton(slot.toggle, profile[stat.key] == true, "Show", ctx.colors)
            slot.cube._colorKey = stat.key
            local color = ctx.settingColor(stat.key)
            slot.cube._fill:SetColor(color[1], color[2], color[3], color[4])
            slot.bg:Show(true)
            slot.label:Show(true)
            slot.toggle:Show(true)
            slot.cube:Show(true)
        else
            slot.stat = nil
            slot.bg:Show(false)
            slot.label:Show(false)
            slot.toggle:Show(false)
            slot.cube:Show(false)
        end
    end
end

-- Explicit false, never nil: Ensure() re-seeds nil core stats from the profile
-- defaults on the next load, which would undo the clear.
local function clearStats(stats)
    local ctx = StatsPicker.ctx
    if not ctx then return end
    local settings = ctx.settings
    ClassIntelProfiles.Ensure(settings)
    local profile = settings.classIntelProfiles[currentProfileKey(settings)]
    if type(profile) ~= "table" then return end
    for _, stat in ipairs(stats) do
        profile[stat.key] = false
    end
    ctx.save()
    refreshRows()
end

-- Click-to-set on the opacity track: convert mouse X (screen) to a 0..1 fraction
-- relative to the track's left edge, using the picker window's current X.
local function setOpacityFromMouse()
    local wnd = StatsPicker.wnd
    local ctx = StatsPicker.ctx
    if not wnd or not ctx or not ctx.setStatsOpacity then return end
    local okPos, mx = pcall(function() return api.Input:GetMousePos() end)
    if not okPos or not tonumber(mx) then return end
    local winX = ctx.windowX and ctx.windowX(wnd) or nil
    if not tonumber(winX) then winX = ctx.settings.statsPickerX or 420 end
    local trackLeft = tonumber(winX) + OPACITY_TRACK_X
    ctx.setStatsOpacity((tonumber(mx) - trackLeft) / OPACITY_TRACK_W)
    refreshRows()
end

local function createWindow()
    local ctx = StatsPicker.ctx
    local colors = ctx.colors
    local settings = ctx.settings
    local x, y = ctx.safePosition(settings.statsPickerX or 420, settings.statsPickerY or 180, WIDTH, HEIGHT)

    local wnd = api.Interface:CreateEmptyWindow("PowerRangerStatsPicker", "UIParent")
    wnd:SetExtent(WIDTH, HEIGHT)
    wnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    UiHelpers.AddBg(wnd, 0, 0, 0, 0.96)
    local body = wnd:CreateColorDrawable(0.06, 0.06, 0.068, 0.96, "background")
    body:AddAnchor("TOPLEFT", wnd, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", wnd, -1, -1)
    body:Show(true)
    local topbar = wnd:CreateColorDrawable(0.18, 0.18, 0.20, 0.96, "background")
    topbar:SetExtent(WIDTH - 2, 30)
    topbar:AddAnchor("TOPLEFT", wnd, 1, 1)
    topbar:Show(true)

    local title = ctx.label(wnd, "power_ranger_stats_picker_title", "Target Stats", 12, 7, 240, 16, 13, colors.gold, ALIGN.LEFT)
    ctx.applyDrag(wnd, title, "statsPickerX", "statsPickerY", true)
    ctx.flatButton(wnd, "power_ranger_stats_picker_close", "X", WIDTH - 32, 5, 22, 20, colors.button, function()
        wnd:Show(false)
    end)

    ctx.label(wnd, "power_ranger_stats_picker_profile_label", "Profile", 16, 46, 56, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.profileButtons = {}
    for i, entry in ipairs(ClassIntelProfiles.PROFILES) do
        local btn = ctx.flatButton(wnd, "power_ranger_stats_picker_profile_" .. entry.key, entry.label, 80 + ((i - 1) * 78), 42, 74, 22, colors.button, function()
            ClassIntelProfiles.SetEditProfile(StatsPicker.ctx.settings, entry.key)
            StatsPicker.ctx.save()
            refreshRows()
        end)
        wnd.profileButtons[#wnd.profileButtons + 1] = { key = entry.key, btn = btn }
    end

    wnd.categoryButtons = {}
    for i, cat in ipairs(TargetStatsCatalog.CATEGORIES) do
        local catX = 16 + (((i - 1) % 7) * 78)
        local catY = 68 + (math.floor((i - 1) / 7) * 22)
        local btn = ctx.flatButton(wnd, "power_ranger_stats_picker_cat_" .. cat.key, cat.label, catX, catY, 74, 20, colors.button, function()
            StatsPicker.category = cat.key
            refreshRows()
        end)
        wnd.categoryButtons[#wnd.categoryButtons + 1] = { key = cat.key, btn = btn }
    end

    local listBg = wnd:CreateColorDrawable(0, 0, 0, 0.52, "background")
    listBg:SetExtent(528, (MAX_ROWS * ROW_STEP) + 6)
    listBg:AddAnchor("TOPLEFT", wnd, LIST_X, LIST_Y)
    listBg:Show(true)

    wnd.rows = {}
    for i = 1, MAX_ROWS do
        local rowY = LIST_Y + 4 + ((i - 1) * ROW_STEP)
        local tone = i % 2 == 1 and {0.08, 0.08, 0.095, 0.72} or {0.12, 0.12, 0.135, 0.72}
        local bg = wnd:CreateColorDrawable(tone[1], tone[2], tone[3], tone[4], "background")
        bg:SetExtent(520, 28)
        bg:AddAnchor("TOPLEFT", wnd, LIST_X + 4, rowY)
        bg:Show(false)
        local label = ctx.label(wnd, "power_ranger_stats_picker_row_label_" .. i, "", LIST_X + 14, rowY + 7, 250, 14, 11, colors.white, ALIGN.LEFT)
        label:Show(false)
        local slotIndex = i
        local toggle = ctx.flatButton(wnd, "power_ranger_stats_picker_row_toggle_" .. i, "", LIST_X + 290, rowY + 3, 110, 22, colors.button, function()
            local slot = StatsPicker.wnd.rows[slotIndex]
            if not slot or not slot.stat then return end
            ClassIntelProfiles.ToggleStat(StatsPicker.ctx.settings, slot.stat.key)
            StatsPicker.ctx.save()
            refreshRows()
        end)
        toggle:Show(false)
        local cube = UiHelpers.ColorCube(wnd, "power_ranger_stats_picker_row_cube_" .. i, LIST_X + 460, rowY + 4, nil, function(self)
            if self._colorKey then
                StatsPicker.ctx.cycleColor(self._colorKey)
                refreshRows()
            end
        end)
        cube:Show(false)
        wnd.rows[i] = { bg = bg, label = label, toggle = toggle, cube = cube }
    end

    -- Expanded stats-window spacing (horizontal/vertical). Lets the user open up
    -- the layout so long Effective-stat values don't crowd the next column.
    if ctx.shiftStatsSpacing then
        ctx.label(wnd, "power_ranger_stats_picker_spacing_label", "Stats window spacing", 16, HEIGHT - 144, 160, 14, 10, colors.muted, ALIGN.LEFT)
        ctx.label(wnd, "power_ranger_stats_picker_hgap_label", "Horizontal", 188, HEIGHT - 144, 64, 14, 10, colors.white, ALIGN.LEFT)
        ctx.flatButton(wnd, "power_ranger_stats_picker_hgap_down", "-", 256, HEIGHT - 146, 22, 20, colors.button, function()
            ctx.shiftStatsSpacing("statsColGap", -4); refreshRows()
        end)
        wnd.hGapValue = ctx.label(wnd, "power_ranger_stats_picker_hgap_value", "0", 280, HEIGHT - 143, 26, 14, 10, colors.white, ALIGN.CENTER)
        ctx.flatButton(wnd, "power_ranger_stats_picker_hgap_up", "+", 308, HEIGHT - 146, 22, 20, colors.button, function()
            ctx.shiftStatsSpacing("statsColGap", 4); refreshRows()
        end)
        ctx.label(wnd, "power_ranger_stats_picker_vgap_label", "Vertical", 348, HEIGHT - 144, 50, 14, 10, colors.white, ALIGN.LEFT)
        ctx.flatButton(wnd, "power_ranger_stats_picker_vgap_down", "-", 402, HEIGHT - 146, 22, 20, colors.button, function()
            ctx.shiftStatsSpacing("statsRowGap", -2); refreshRows()
        end)
        wnd.vGapValue = ctx.label(wnd, "power_ranger_stats_picker_vgap_value", "0", 426, HEIGHT - 143, 26, 14, 10, colors.white, ALIGN.CENTER)
        ctx.flatButton(wnd, "power_ranger_stats_picker_vgap_up", "+", 454, HEIGHT - 146, 22, 20, colors.button, function()
            ctx.shiftStatsSpacing("statsRowGap", 2); refreshRows()
        end)
    end

    -- Background opacity for the intel / stats window, mirroring the other opacity
    -- sliders (track click + -/+). 1.00 = current look; lower = more see-through.
    if ctx.setStatsOpacity then
        ctx.label(wnd, "power_ranger_stats_picker_opacity_label", "Window opacity", 16, HEIGHT - 114, 120, 14, 10, colors.muted, ALIGN.LEFT)
        wnd.opacityTrack = ctx.flatButton(wnd, "power_ranger_stats_picker_opacity_track", "", OPACITY_TRACK_X, HEIGHT - 115, OPACITY_TRACK_W, 16, {0.10, 0.10, 0.11, 0.96}, setOpacityFromMouse)
        wnd.opacityFill = wnd.opacityTrack:CreateColorDrawable(1, 0.84, 0, 0.55, "background")
        wnd.opacityFill:AddAnchor("TOPLEFT", wnd.opacityTrack, 1, 1)
        wnd.opacityFill:SetExtent(1, 14)
        wnd.opacityFill:Show(false)
        ctx.flatButton(wnd, "power_ranger_stats_picker_opacity_down", "-", 446, HEIGHT - 116, 22, 20, colors.button, function()
            ctx.shiftStatsOpacity(-1); refreshRows()
        end)
        wnd.opacityValue = ctx.label(wnd, "power_ranger_stats_picker_opacity_value", "1.00", 470, HEIGHT - 113, 40, 14, 10, colors.white, ALIGN.CENTER)
        ctx.flatButton(wnd, "power_ranger_stats_picker_opacity_up", "+", 512, HEIGHT - 116, 22, 20, colors.button, function()
            ctx.shiftStatsOpacity(1); refreshRows()
        end)
    end

    ctx.label(wnd, "power_ranger_stats_picker_clear_label", "Reset (selected profile)", 16, HEIGHT - 82, 200, 14, 10, colors.muted, ALIGN.LEFT)
    ctx.flatButton(wnd, "power_ranger_stats_picker_clear_page", "Clear Page", 300, HEIGHT - 86, 118, 22, RED, function()
        clearStats(TargetStatsCatalog.ByCategory(StatsPicker.category))
    end)
    ctx.flatButton(wnd, "power_ranger_stats_picker_clear_all", "Clear All", 426, HEIGHT - 86, 118, 22, RED, function()
        clearStats(TargetStatsCatalog.STATS)
    end)

    ctx.label(wnd, "power_ranger_stats_picker_hint1", "Stats apply to the selected profile; targets are matched to a profile by class.", 16, HEIGHT - 56, 528, 14, 10, colors.muted, ALIGN.LEFT)
    ctx.label(wnd, "power_ranger_stats_picker_hint2", "Core stats also show in the compact window. Other stats show in the expanded stats window.", 16, HEIGHT - 40, 528, 14, 10, colors.muted, ALIGN.LEFT)

    wnd:Show(false)
    return wnd
end

function StatsPicker.Open(ctx)
    StatsPicker.ctx = ctx
    if not StatsPicker.wnd then
        StatsPicker.wnd = createWindow()
    end
    refreshRows()
    StatsPicker.wnd:Show(true)
end

function StatsPicker.Refresh()
    if StatsPicker.wnd and StatsPicker.wnd:IsVisible() then refreshRows() end
end

function StatsPicker.Cleanup()
    if StatsPicker.wnd then StatsPicker.wnd:Show(false) end
    StatsPicker.wnd = nil
    StatsPicker.ctx = nil
end

return StatsPicker
