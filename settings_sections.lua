local SettingsSections = {}

-- Every section panel sits at this x inside the settings window.
local PANEL_X = 18

-- registerSlider lived here: it stamped a click-to-set track's geometry onto the widget so
-- the handler and the fill could not drift from the layout. Every slider now comes from
-- AddonUILib, which derives both from the same arguments by construction, so there is
-- nothing left to stamp.

function SettingsSections.BuildTargetOverhead(wnd, ctx)
    local colors = ctx.colors
    local sectionPanel = ctx.sectionPanel
    local label = ctx.label
    local flatButton = ctx.flatButton
    local colorCube = ctx.colorCube
    local toggleSetting = ctx.toggleSetting
    local shiftUiScale = ctx.shiftUiScale
    local shiftCompactModelLeft = ctx.shiftCompactModelLeft
    local shiftCompactModelY = ctx.shiftCompactModelY
    local shiftModelRangeOffset = ctx.shiftModelRangeOffset
    local cycleOverlayTextStyle = ctx.cycleOverlayTextStyle

    local p = sectionPanel(wnd, "power_ranger_model_panel", 18, 52, 584, 190, "Target Overhead")
    label(p, "power_ranger_model_compact_only", "Compact only", 16, 35, 86, 14, 10, colors.gold, ALIGN.LEFT)
    label(p, "power_ranger_scale_label", "Scale", 116, 35, 36, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_scale_down", "-", 154, 32, 22, 20, colors.button, function() shiftUiScale(-1) end)
    wnd.scaleValue = label(p, "power_ranger_scale_value", "0", 178, 35, 20, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_scale_up", "+", 200, 32, 22, 20, colors.button, function() shiftUiScale(1) end)
    wnd.shadowBtn = flatButton(p, "power_ranger_toggle_text_style", "", 394, 32, 154, 20, colors.active, cycleOverlayTextStyle)

    wnd.modelBtn = flatButton(p, "power_ranger_toggle_model", "", 16, 58, 86, 22, colors.active, function() toggleSetting("showModelOverlay") end)
    wnd.armorBtn = flatButton(p, "power_ranger_toggle_armor", "", 108, 58, 86, 22, colors.active, function() toggleSetting("showArmorIcon") end)
    wnd.weaponBtn = flatButton(p, "power_ranger_toggle_weapon", "", 200, 58, 86, 22, colors.active, function() toggleSetting("showWeaponIcon") end)
    wnd.modelGsBtn = flatButton(p, "power_ranger_toggle_model_gs", "", 292, 58, 82, 22, colors.active, function() toggleSetting("showModelGearscore") end)
    wnd.modelClassBtn = flatButton(p, "power_ranger_toggle_model_class", "", 380, 58, 82, 22, colors.active, function() toggleSetting("showModelClass") end)
    wnd.modelRangeBtn = flatButton(p, "power_ranger_toggle_model_range", "", 468, 58, 82, 22, colors.active, function() toggleSetting("showModelRange") end)
    -- Mirrors the whole compact block (GS + class text and the armor/weapon icons) to the
    -- other side of the target's health bar.
    wnd.modelSideBtn = flatButton(p, "power_ranger_toggle_model_side", "", 468, 86, 82, 22, colors.blue, function() toggleSetting("overheadOnRight") end)

    label(p, "power_ranger_model_color_label", "Colors", 16, 94, 44, 14, 10, colors.muted, ALIGN.LEFT)
    label(p, "power_ranger_model_color_dist", "Dist", 72, 94, 28, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.modelRange = colorCube(p, "power_ranger_model_color_range", 102, 90, "modelRange")
    label(p, "power_ranger_model_color_gs", "GS", 136, 94, 22, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.modelGearscore = colorCube(p, "power_ranger_model_color_gs_cube", 160, 90, "modelGearscore")
    label(p, "power_ranger_model_color_class", "Class", 196, 94, 42, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.modelClass = colorCube(p, "power_ranger_model_color_class_cube", 238, 90, "modelClass")

    label(p, "power_ranger_model_pos_label", "Overhead position", 16, 122, 96, 14, 10, colors.gold, ALIGN.LEFT)
    label(p, "power_ranger_model_left_label", "X", 126, 122, 12, 14, 10, colors.white, ALIGN.LEFT)
    flatButton(p, "power_ranger_model_left_down", "-", 144, 118, 22, 20, colors.button, function() shiftCompactModelLeft(-1) end)
    wnd.modelLeftValue = label(p, "power_ranger_model_left_value", "45", 168, 121, 28, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_model_left_up", "+", 198, 118, 22, 20, colors.button, function() shiftCompactModelLeft(1) end)
    label(p, "power_ranger_model_y_label", "Y", 238, 122, 12, 14, 10, colors.white, ALIGN.LEFT)
    flatButton(p, "power_ranger_model_y_down", "-", 256, 118, 22, 20, colors.button, function() shiftCompactModelY(-2) end)
    wnd.modelYValue = label(p, "power_ranger_model_y_value", "0", 280, 121, 28, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_model_y_up", "+", 310, 118, 22, 20, colors.button, function() shiftCompactModelY(2) end)

    label(p, "power_ranger_range_controls_label", "Range", 16, 148, 44, 14, 10, colors.gold, ALIGN.LEFT)
    label(p, "power_ranger_model_range_scale_label", "Size", 70, 148, 30, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_model_range_scale_down", "-", 104, 144, 22, 20, colors.button, function() shiftUiScale(-1, "modelRangeScaleLevel") end)
    wnd.modelRangeScaleValue = label(p, "power_ranger_model_range_scale_value", "0", 128, 147, 24, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_model_range_scale_up", "+", 154, 144, 22, 20, colors.button, function() shiftUiScale(1, "modelRangeScaleLevel") end)
    label(p, "power_ranger_model_range_x_label", "X", 196, 148, 12, 14, 10, colors.white, ALIGN.LEFT)
    flatButton(p, "power_ranger_model_range_x_down", "-", 214, 144, 22, 20, colors.button, function() shiftModelRangeOffset("x", -2) end)
    wnd.modelRangeXValue = label(p, "power_ranger_model_range_x_value", "0", 238, 147, 28, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_model_range_x_up", "+", 268, 144, 22, 20, colors.button, function() shiftModelRangeOffset("x", 2) end)
    label(p, "power_ranger_model_range_y_label", "Y", 310, 148, 12, 14, 10, colors.white, ALIGN.LEFT)
    flatButton(p, "power_ranger_model_range_y_down", "-", 328, 144, 22, 20, colors.button, function() shiftModelRangeOffset("y", -2) end)
    wnd.modelRangeYValue = label(p, "power_ranger_model_range_y_value", "0", 352, 147, 28, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_model_range_y_up", "+", 382, 144, 22, 20, colors.button, function() shiftModelRangeOffset("y", 2) end)
    return p
end

function SettingsSections.BuildGuildLabel(wnd, ctx, y)
    local colors = ctx.colors
    local p = ctx.sectionPanel(wnd, "power_ranger_guild_label_panel", 18, y or 254, 584, 74, "Guild Label")
    ctx.label(p, "power_ranger_guild_label_hint", "Target guild name", 16, 34, 150, 14, 10, colors.gold, ALIGN.LEFT)
    wnd.guildFamilyLabelBtn = ctx.flatButton(p, "power_ranger_toggle_guild_family_label", "", 176, 30, 100, 22, colors.active, function() ctx.toggleSetting("showGuildFamilyLabel") end)
    ctx.label(p, "power_ranger_guild_family_guild_size_label", "Size", 294, 34, 34, 14, 10, colors.muted, ALIGN.LEFT)
    ctx.flatButton(p, "power_ranger_guild_family_guild_size_down", "-", 332, 30, 22, 20, colors.button, function() ctx.shiftGuildFamilyScale(-1, "guildFamilyGuildScaleLevel") end)
    wnd.guildFamilyGuildScaleValue = ctx.label(p, "power_ranger_guild_family_guild_size_value", "0", 356, 33, 24, 14, 10, colors.white, ALIGN.CENTER)
    ctx.flatButton(p, "power_ranger_guild_family_guild_size_up", "+", 382, 30, 22, 20, colors.button, function() ctx.shiftGuildFamilyScale(1, "guildFamilyGuildScaleLevel") end)
    ctx.label(p, "power_ranger_guild_family_guild_color_label", "Color", 426, 34, 34, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.guildFamilyGuild = ctx.colorCube(p, "power_ranger_guild_family_guild_color", 466, 30, "guildFamilyGuild")
    return p
end

function SettingsSections.BuildIntelWindow(wnd, ctx)
    local colors = ctx.colors
    local sectionPanel = ctx.sectionPanel
    local label = ctx.label
    local flatButton = ctx.flatButton
    local colorCube = ctx.colorCube
    local toggleSetting = ctx.toggleSetting
    local shiftUiScale = ctx.shiftUiScale
    local shiftSimpleSpacing = ctx.shiftSimpleSpacing
    local shiftGuildFamilyScale = ctx.shiftGuildFamilyScale or shiftUiScale
    local fields = ctx.fields or {}

    local p = sectionPanel(wnd, "power_ranger_window_panel", 18, 254, 584, 344, "Stats Window")
    local function band(id, y, h)
        local bg = p:CreateColorDrawable(0.07, 0.075, 0.085, 0.62, "background")
        bg:SetExtent(552, h)
        bg:AddAnchor("TOPLEFT", p, 16, y)
        bg:Show(true)
        return bg
    end

    band("display", 30, 56)
    label(p, "power_ranger_stats_display_title", "Display", 24, 36, 60, 14, 10, colors.gold, ALIGN.LEFT)
    wnd.targetWindowBtn = flatButton(p, "power_ranger_toggle_window", "", 92, 32, 118, 22, colors.active, function() toggleSetting("showTargetWindow") end)
    wnd.compactWindowBtn = flatButton(p, "power_ranger_toggle_compact_window", "", 218, 32, 90, 22, colors.active, function() toggleSetting("compactTargetWindow") end)
    wnd.testWindowBtn = flatButton(p, "power_ranger_toggle_test_window", "", 316, 32, 126, 22, colors.active, function() toggleSetting("testTargetWindow") end)
    label(p, "power_ranger_intel_scale_label", "Scale", 458, 36, 38, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_intel_scale_down", "-", 498, 32, 22, 20, colors.button, function() shiftUiScale(-1, "targetWindowScaleLevel") end)
    wnd.intelScaleValue = label(p, "power_ranger_intel_scale_value", "0", 522, 35, 20, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_intel_scale_up", "+", 544, 32, 22, 20, colors.button, function() shiftUiScale(1, "targetWindowScaleLevel") end)
    label(p, "power_ranger_simple_spacing_label", "Simple spacing", 24, 66, 90, 14, 10, colors.muted, ALIGN.LEFT)
    label(p, "power_ranger_simple_columns_label", "Columns", 128, 66, 52, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_simple_columns_down", "-", 184, 62, 22, 20, colors.button, function() shiftSimpleSpacing("simpleColumnGap", -1, 0, 73) end)
    wnd.simpleColumnGapValue = label(p, "power_ranger_simple_columns_value", "0", 208, 65, 22, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_simple_columns_up", "+", 232, 62, 22, 20, colors.button, function() shiftSimpleSpacing("simpleColumnGap", 1, 0, 73) end)
    label(p, "power_ranger_simple_lines_label", "Lines", 284, 66, 38, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_simple_lines_down", "-", 326, 62, 22, 20, colors.button, function() shiftSimpleSpacing("simpleLineGap", -1, 0, 23) end)
    wnd.simpleLineGapValue = label(p, "power_ranger_simple_lines_value", "0", 350, 65, 22, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_simple_lines_up", "+", 374, 62, 22, 20, colors.button, function() shiftSimpleSpacing("simpleLineGap", 1, 0, 23) end)

    band("labels", 94, 56)
    label(p, "power_ranger_stats_labels_title", "Guild/Fam label", 24, 104, 96, 14, 10, colors.gold, ALIGN.LEFT)
    wnd.guildFamilyLabelBtn = flatButton(p, "power_ranger_toggle_guild_family_label", "", 124, 100, 126, 20, colors.active, function() toggleSetting("showGuildFamilyLabel") end)
    label(p, "power_ranger_guild_family_guild_size_label", "Guild size", 264, 104, 54, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_guild_family_guild_size_down", "-", 320, 100, 22, 20, colors.button, function() shiftGuildFamilyScale(-1, "guildFamilyGuildScaleLevel") end)
    wnd.guildFamilyGuildScaleValue = label(p, "power_ranger_guild_family_guild_size_value", "0", 344, 103, 24, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_guild_family_guild_size_up", "+", 370, 100, 22, 20, colors.button, function() shiftGuildFamilyScale(1, "guildFamilyGuildScaleLevel") end)
    label(p, "power_ranger_guild_family_family_size_label", "Fam size", 402, 104, 48, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_guild_family_family_size_down", "-", 452, 100, 22, 20, colors.button, function() shiftGuildFamilyScale(-1, "guildFamilyFamilyScaleLevel") end)
    wnd.guildFamilyFamilyScaleValue = label(p, "power_ranger_guild_family_family_size_value", "0", 476, 103, 24, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_guild_family_family_size_up", "+", 502, 100, 22, 20, colors.button, function() shiftGuildFamilyScale(1, "guildFamilyFamilyScaleLevel") end)
    label(p, "power_ranger_guild_family_guild_color_label", "Guild", 404, 128, 34, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.guildFamilyGuild = colorCube(p, "power_ranger_guild_family_guild_color", 442, 124, "guildFamilyGuild")
    label(p, "power_ranger_guild_family_family_color_label", "Fam", 470, 128, 28, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.guildFamilyFamily = colorCube(p, "power_ranger_guild_family_family_color", 500, 124, "guildFamilyFamily")

    band("profiles", 158, 82)
    label(p, "power_ranger_class_profile_title", "Profile stats", 24, 164, 92, 14, 10, colors.gold, ALIGN.LEFT)
    label(p, "power_ranger_class_profile_hint1", "All target stats moved into their own picker window:", 24, 188, 330, 14, 10, colors.muted, ALIGN.LEFT)
    label(p, "power_ranger_class_profile_hint2", "pick a profile on top, then toggle stats per category.", 24, 206, 330, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_stats_picker_open", "Open Stats Picker", 380, 188, 162, 26, colors.blue, function()
        if ctx.openStatsPicker then ctx.openStatsPicker() end
    end)

    band("identity", 248, 64)
    label(p, "power_ranger_stats_field_title", "Identity fields", 24, 254, 96, 14, 10, colors.gold, ALIGN.LEFT)
    wnd.fieldButtons = {}
    for i, field in ipairs(fields) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local x = 24 + (col * 134)
        local y = 276 + (row * 24)
        local tone = row % 2 == 0 and 0.08 or 0.12
        local blueTone = row % 2 == 0 and 0.095 or 0.135
        local bg = p:CreateColorDrawable(tone, tone, blueTone, 0.72, "background")
        bg:SetExtent(124, 22)
        bg:AddAnchor("TOPLEFT", p, x - 4, y - 1)
        bg:Show(true)
        wnd.fieldButtons[field.key] = flatButton(p, "power_ranger_info_field_" .. field.key, "", x, y, 94, 20, colors.active, function() toggleSetting(field.setting) end)
        wnd.colorCubes[field.key] = colorCube(p, "power_ranger_info_color_" .. field.key, x + 102, y, field.key)
    end
    return p
end

function SettingsSections.BuildSelfCooldowns(wnd, ctx)
    local colors = ctx.colors
    local sectionPanel = ctx.sectionPanel
    local label = ctx.label
    local flatButton = ctx.flatButton
    local toggleSetting = ctx.toggleSetting
    local shiftUiScale = ctx.shiftUiScale
    -- No shiftSelfOpacity / setSelfOpacityFromMouse locals: the AddonUILib slider owns the
    -- steppers and the click mapping for this row.
    local toggleProbeLogging = ctx.toggleProbeLogging
    local openDetectedSkillsWindow = ctx.openDetectedSkillsWindow
    local openCooldownManagerWindow = ctx.openCooldownManagerWindow or function() end

    local p = sectionPanel(wnd, "power_ranger_self_panel", 18, ctx.y or 566, 584, 182, "Self Cooldowns & Gear")
    label(p, "power_ranger_self_hint", "Known cooldown auras stay ID-based.", 14, 32, 260, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.nuziImportBtn = flatButton(p, "power_ranger_toggle_nuzi_cd_import", "", 286, 29, 104, 20, colors.blue, function() toggleSetting("importNuziCooldowns") end)
    label(p, "power_ranger_self_scale_label", "Scale", 410, 32, 40, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_self_scale_down", "-", 452, 29, 24, 20, colors.button, function() shiftUiScale(-1, "selfScaleLevel") end)
    wnd.selfScaleValue = label(p, "power_ranger_self_scale_value", "0", 480, 32, 24, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_self_scale_up", "+", 508, 29, 24, 20, colors.button, function() shiftUiScale(1, "selfScaleLevel") end)
    wnd.selfBtn = flatButton(p, "power_ranger_toggle_self", "", 16, 58, 86, 24, colors.active, function() toggleSetting("showSelfPanel") end)
    wnd.selfCdBtn = flatButton(p, "power_ranger_toggle_self_cd", "", 108, 58, 96, 24, colors.active, function() toggleSetting("showSelfCooldowns") end)
    wnd.selfEquipmentBtn = flatButton(p, "power_ranger_toggle_self_equipment", "", 210, 58, 94, 24, colors.active, function() toggleSetting("showSelfEquipment") end)
    wnd.selfBorderBtn = flatButton(p, "power_ranger_toggle_self_border", "", 310, 58, 82, 24, colors.active, function() toggleSetting("showSelfBorder") end)
    wnd.probeLogBtn = flatButton(p, "power_ranger_probe_log", "", 398, 58, 58, 24, colors.blue, toggleProbeLogging)
    flatButton(p, "power_ranger_detected_open", "Detected", 462, 58, 88, 24, colors.blue, openDetectedSkillsWindow)
    label(p, "power_ranger_self_opacity_label", "Opacity", 16, 92, 54, 14, 10, colors.muted, ALIGN.LEFT)
    -- FIRST slider migrated to AddonUILib. One call replaces the track, the fill, the two
    -- steppers and the value label -- and the click-to-set geometry comes from the same x/w
    -- the track is drawn with, so registerSlider's stamping is not needed here.
    --
    -- The other three opacity sliders are deliberately left hand-rolled for now: they are the
    -- control group. If this one misbehaves and they do not, the library is the difference.
    wnd.selfOpacitySlider = ctx.slider(p, "power_ranger_self_opacity", 78, 91, 312, {
        window = wnd,
        parentOffsetX = PANEL_X,
        fallbackX = ctx.settings and ctx.settings.settingsX or nil,
        min = 0,
        max = 10,
        step = 1,
        get = function() return ctx.settings and ctx.settings.selfOpacityLevel or 8 end,
        set = function(v) ctx.setSelfOpacityLevel(v) end,
        format = function(v) return string.format("%.2f", v / 10) end
    })
    label(p, "power_ranger_cd_manager_title", "Cooldown managers", 16, 114, 128, 14, 11, colors.gold, ALIGN.LEFT)
    flatButton(p, "power_ranger_cd_manager_gliders", "Gliders", 150, 110, 118, 22, colors.blue, function() openCooldownManagerWindow("glider") end)
    flatButton(p, "power_ranger_cd_manager_mounts", "Auras/Mounts", 276, 110, 118, 22, colors.blue, function() openCooldownManagerWindow("other") end)
    flatButton(p, "power_ranger_cd_manager_equipment", "Equipment", 402, 110, 118, 22, colors.blue, function() toggleSetting("showSelfEquipment") end)
    label(p, "power_ranger_cd_manager_hint", "Sorting, show toggles, and per-device skills.", 16, 136, 520, 14, 10, colors.muted, ALIGN.LEFT)

    -- Cooldown ready popup. Test fires it directly (bypassing the cooldown runtime) so a
    -- silent alert can be pinned on the popup or on what feeds it; Move pins it on screen
    -- so it can be dragged, which its 1.5s lifetime otherwise makes impossible.
    label(p, "power_ranger_cd_ready_label", "CD Popup", 16, 161, 132, 14, 10, colors.gold, ALIGN.LEFT)
    flatButton(p, "power_ranger_cd_ready_test", "Test", 154, 158, 60, 20, colors.blue, function()
        local popup = require("power_ranger_on/ready_popup")
        if not popup.Test() and ctx.notify then
            ctx.notify("CD Popup is off - turn it on first.", true)
        end
    end)
    -- Move arms BOTH on-screen popups -- the cooldown icon and the memory warning banner.
    -- They are the same kind of thing (a transient plate over the world) and the Client
    -- Options row has no space left for a second Move button, so one control covers both.
    wnd.cooldownReadyMoveBtn = flatButton(p, "power_ranger_cd_ready_move", "Move", 220, 158, 60, 20, colors.button, function()
        local popup = require("power_ranger_on/ready_popup")
        local on = not popup.IsMoveMode()
        popup.SetMoveMode(on)
        pcall(function() require("power_ranger_on/memory_tracker").SetMoveMode(on) end)
        if ctx.refreshSettingsButtons then ctx.refreshSettingsButtons() end
    end)
    wnd.cooldownReadyPopupBtn = flatButton(p, "power_ranger_cd_ready_popup", "", 286, 158, 118, 20, colors.active, function()
        toggleSetting("cooldownReadyPopup")
    end)
    label(p, "power_ranger_cd_ready_hint", "Move: drag both popups.", 412, 161, 130, 14, 10, colors.muted, ALIGN.LEFT)
    return p
end

function SettingsSections.BuildHotSwapLauncher(wnd, ctx, y)
    local colors = ctx.colors
    local p = ctx.sectionPanel(wnd, "power_ranger_hot_swap_panel", 18, y, 584, 82, "Hot Swap")
    local hotSwap = require("power_ranger_on/hot_swap")
    local refresh = ctx.refreshSettingsButtons or function() end
    ctx.label(p, "power_ranger_hot_swap_hint", "Embedded gear sets and auto triggers.", 14, 32, 210, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.hotSwapEnabledBtn = ctx.flatButton(p, "power_ranger_hot_swap_enabled", "", 234, 28, 82, 22, colors.active, function()
        if hotSwap and hotSwap.SetEnabled then hotSwap.SetEnabled(not hotSwap.IsEnabled()) end
        refresh()
    end)
    wnd.hotSwapFloatBtn = ctx.flatButton(p, "power_ranger_hot_swap_float", "", 322, 28, 82, 22, colors.active, function()
        if hotSwap and hotSwap.SetFloatShown then hotSwap.SetFloatShown(not hotSwap.IsFloatShown()) end
        refresh()
    end)
    ctx.flatButton(p, "power_ranger_hot_swap_settings_open", "Settings", 410, 28, 132, 22, colors.blue, function()
        if hotSwap and hotSwap.toggleSettings then hotSwap.toggleSettings() end
    end)
    ctx.label(p, "power_ranger_debug_hint", "Debug logging", 14, 60, 104, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.debugLogBtn = ctx.flatButton(p, "power_ranger_debug_logging", "", 234, 55, 82, 22, colors.button, function()
        ctx.toggleSetting("debugLogging")
    end)
    -- TEMPORARY, alongside nametag_probe.lua. Remove both once the X2NameTag surface is known.
    ctx.flatButton(p, "power_ranger_nametag_probe_open", "Nametag probe", 324, 55, 118, 22, colors.blue, function()
        if ctx.openNametagProbe then ctx.openNametagProbe() end
    end)
    return p
end

function SettingsSections.BuildClientOptions(wnd, ctx, y)
    local colors = ctx.colors
    -- 182 tall: rows at 34 / 64 / 94 / 124 / 154. Default appearances and the float bar share
    -- one row -- layout axis, then the float toggle, then Default App itself.
    local p = ctx.sectionPanel(wnd, "power_ranger_client_options_panel", 18, y, 584, 182, "Client Options")
    ctx.label(p, "power_ranger_default_appearance_label", "Default appearances", 14, 34, 120, 14, 10, colors.gold, ALIGN.LEFT)
    ctx.label(p, "power_ranger_default_appearance_hint", "Float bar shows while any button is on.", 140, 34, 132, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.floatAxisBtn = ctx.flatButton(p, "power_ranger_float_axis", "", 276, 29, 60, 22, colors.blue, function()
        if ctx.toggleSetting then ctx.toggleSetting("optionFloatVertical") end
        if ctx.refreshClientOptionButtons then ctx.refreshClientOptionButtons() end
    end)
    wnd.floatOptionButtonsBtn = ctx.flatButton(p, "power_ranger_float_option_buttons", "", 342, 29, 100, 22, colors.active, function()
        if ctx.toggleSetting then ctx.toggleSetting("showFloatOptionButtons") end
        if ctx.refreshClientOptionButtons then ctx.refreshClientOptionButtons() end
    end)
    wnd.defaultAppearancesBtn = ctx.flatButton(p, "power_ranger_default_appearances", "", 448, 29, 100, 22, colors.active, function()
        if ctx.toggleDefaultAppearances then ctx.toggleDefaultAppearances() end
    end)
    ctx.label(p, "power_ranger_ui_hp_percent_label", "UI HP/MP percent", 14, 64, 132, 14, 10, colors.gold, ALIGN.LEFT)
    wnd.uiHpPercentHint = ctx.label(p, "power_ranger_ui_hp_percent_hint", "Shows percent text inside unit-frame bars.", 152, 64, 268, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.uiHpPercentBtn = ctx.flatButton(p, "power_ranger_ui_hp_percent", "", 428, 59, 118, 22, colors.active, function()
        -- BetterBars already owns these labels, so ours stands down and the button
        -- becomes a shortcut into its settings instead. "ADDON_SETTINGS_OPENED" +
        -- the addon name is BetterBars' own open hook (BetterBars/main.lua:2297).
        if require("power_ranger_on/hp_percent_bars").HasConflict() then
            pcall(function() require("api"):Emit("ADDON_SETTINGS_OPENED", "BetterBars") end)
            return
        end
        if ctx.toggleSetting then ctx.toggleSetting("showUiHpPercent") end
    end)

    -- Node tracker gets its own window: the main shell is already ~1360px tall and another
    -- full section would push it past a 1080p screen.
    ctx.label(p, "power_ranger_node_label", "Node tracker", 14, 94, 132, 14, 10, colors.gold, ALIGN.LEFT)
    wnd.nodeTrackerHint = ctx.label(p, "power_ranger_node_hint", "Water, logs, fish, gamekeeper spots and timers.", 152, 94, 260, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.nodeTrackerBtn = ctx.flatButton(p, "power_ranger_node_open", "Node Tracker", 428, 89, 118, 22, colors.blue, function()
        if ctx.openNodeWindow then ctx.openNodeWindow() end
    end)

    -- Client memory watch. One row, because the shell is already at the ~1360px ceiling a
    -- 1080p screen allows and a second row would push it off.
    --
    -- Only the critical number is configurable: warnings are derived from it (-200, -100).
    -- The player knows roughly where their client dies; asking them to also compose a list
    -- of warning points is asking the same question twice.
    ctx.label(p, "power_ranger_memory_label", "Client memory", 14, 124, 104, 14, 10, colors.gold, ALIGN.LEFT)
    ctx.label(p, "power_ranger_memory_hint", "Warns before the client runs out and crashes.", 122, 124, 152, 14, 10, colors.muted, ALIGN.LEFT)
    ctx.label(p, "power_ranger_memory_crit_label", "Crit", 278, 124, 26, 14, 10, colors.muted, ALIGN.LEFT)
    ctx.flatButton(p, "power_ranger_memory_crit_down", "-", 304, 119, 24, 22, colors.button, function()
        if ctx.shiftMemoryCritical then ctx.shiftMemoryCritical(-1) end
    end)
    wnd.memoryCriticalValue = ctx.label(p, "power_ranger_memory_crit_value", "3000", 330, 124, 42, 14, 10, colors.white, ALIGN.CENTER)
    ctx.flatButton(p, "power_ranger_memory_crit_up", "+", 374, 119, 24, 22, colors.button, function()
        if ctx.shiftMemoryCritical then ctx.shiftMemoryCritical(1) end
    end)
    wnd.memoryFloatBtn = ctx.flatButton(p, "power_ranger_memory_float", "", 404, 119, 66, 22, colors.active, function()
        if ctx.toggleSetting then ctx.toggleSetting("memoryFloatButton") end
        if ctx.refreshClientOptionButtons then ctx.refreshClientOptionButtons() end
    end)
    wnd.memoryWatchBtn = ctx.flatButton(p, "power_ranger_memory_watch", "", 476, 119, 70, 22, colors.active, function()
        if ctx.toggleSetting then ctx.toggleSetting("memoryWatchEnabled") end
        if ctx.refreshClientOptionButtons then ctx.refreshClientOptionButtons() end
    end)

    -- "Only use my portal": stops other players' portals pulling you through. A CLIENT option,
    -- not one of ours -- it has a real getter, so nothing is persisted on our side and the
    -- button reads the game's own value. Change it in the client's options window and this
    -- shows the new state rather than a stale copy.
    ctx.label(p, "power_ranger_portal_label", "Portals", 14, 154, 104, 14, 10, colors.gold, ALIGN.LEFT)
    ctx.label(p, "power_ranger_portal_hint", "Blocks other players' portals pulling you through.", 122, 154, 276, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.portalFloatBtn = ctx.flatButton(p, "power_ranger_portal_float", "", 404, 149, 66, 22, colors.active, function()
        if ctx.toggleSetting then ctx.toggleSetting("portalFloatButton") end
        if ctx.refreshClientOptionButtons then ctx.refreshClientOptionButtons() end
    end)
    wnd.onlyMyPortalBtn = ctx.flatButton(p, "power_ranger_only_my_portal", "", 476, 149, 70, 22, colors.active, function()
        if ctx.toggleOnlyMyPortal then ctx.toggleOnlyMyPortal() end
    end)
    return p
end

function SettingsSections.BuildTravelTools(wnd, ctx, y)
    local colors = ctx.colors
    local p = ctx.sectionPanel(wnd, "power_ranger_travel_tools_panel", 18, y, 584, 132, "Travel & Ownership")
    local labelX, toggleX, controlX = 14, 112, 250
    local row1, row2, row3 = 30, 58, 86
    if not ctx.targetApiDisabled then
        ctx.label(p, "power_ranger_ownership_hint", "Ownership", labelX, row1 + 5, 86, 14, 10, colors.muted, ALIGN.LEFT)
        wnd.ownershipBtn = ctx.flatButton(p, "power_ranger_toggle_ownership", "", toggleX, row1, 118, 22, colors.active, function()
            ctx.toggleSetting("showOwnershipLabels")
        end)
        ctx.label(p, "power_ranger_ownership_scale_label", "Scale", controlX, row1 + 5, 48, 14, 10, colors.muted, ALIGN.LEFT)
        ctx.flatButton(p, "power_ranger_ownership_scale_down", "-", controlX + 58, row1 + 1, 22, 20, colors.button, function() ctx.shiftUiScale(-1, "ownershipScaleLevel") end)
        wnd.ownershipScaleValue = ctx.label(p, "power_ranger_ownership_scale_value", "0", controlX + 82, row1 + 4, 28, 14, 10, colors.white, ALIGN.CENTER)
        ctx.flatButton(p, "power_ranger_ownership_scale_up", "+", controlX + 114, row1 + 1, 22, 20, colors.button, function() ctx.shiftUiScale(1, "ownershipScaleLevel") end)
    else
        ctx.label(p, "power_ranger_target_api_disabled", "Target ownership labels are parked after the API lock.", labelX, row1 + 5, 380, 14, 10, colors.muted, ALIGN.LEFT)
    end

    ctx.label(p, "power_ranger_speed_hint", "Speed", labelX, row2 + 5, 86, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.speedMeterBtn = ctx.flatButton(p, "power_ranger_speed_toggle", "", toggleX, row2, 118, 22, colors.active, function()
        ctx.toggleSetting("showSpeedMeter")
    end)
    ctx.label(p, "power_ranger_speed_opacity_label", "Opacity", controlX, row2 + 5, 52, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.speedOpacitySlider = ctx.slider(p, "power_ranger_speed_opacity", controlX + 58, row2 + 4, 132, {
        window = wnd,
        parentOffsetX = PANEL_X,
        min = 0, max = 10, step = 1,
        get = function() return ctx.settings and ctx.settings.speedMeterOpacityLevel or 8 end,
        set = function(v) ctx.setSpeedOpacityLevel(v) end,
        format = function(v) return string.format("%.2f", v / 10) end
    })

    ctx.label(p, "power_ranger_mark_hint", "Owner's Mark", labelX, row3 + 5, 86, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.ownOwnersMarkBtn = ctx.flatButton(p, "power_ranger_own_mark_toggle", "", toggleX, row3, 118, 22, colors.active, function()
        ctx.toggleSetting("showOwnOwnersMark")
    end)
    wnd.targetOwnersMarkBtn = ctx.flatButton(p, "power_ranger_target_mark_toggle", "", controlX, row3, 118, 22, colors.active, function()
        ctx.toggleSetting("showTargetOwnersMark")
    end)
    -- DEPRECATED (June 2026 API lock): the missing-mark warning reads the mark buff off the
    -- restricted vehicle/target tokens to confirm it's missing, so it can't be trusted. Toggle
    -- parked; logic kept behind a deprecation flag.
    local warnX = controlX + 126
    ctx.label(p, "power_ranger_mark_parked", "Missing warning parked (API lock)", warnX, row3 + 5, 200, 14, 10, colors.muted, ALIGN.LEFT)
    ctx.label(p, "power_ranger_mark_opacity_label", "Mark opacity", labelX, 116, 86, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.ownersMarkOpacitySlider = ctx.slider(p, "power_ranger_mark_opacity", toggleX, 115, 132, {
        window = wnd,
        parentOffsetX = PANEL_X,
        min = 0, max = 10, step = 1,
        get = function() return ctx.settings and ctx.settings.ownersMarkOpacityLevel or 8 end,
        set = function(v) ctx.setOwnersMarkOpacityLevel(v) end,
        format = function(v) return string.format("%.2f", v / 10) end
    })

    return p
end

function SettingsSections.BuildWeaponProc(wnd, ctx, y)
    local colors = ctx.colors
    local p = ctx.sectionPanel(wnd, "power_ranger_weapon_proc_panel", 18, y, 584, 140, "Weapon Proc")
    ctx.label(p, "power_ranger_weapon_proc_hint", "Hidden mainhand proc tracker: Nodachi/Katana crit, Spear/Staff pen. Shift-drag the bar.", 14, 30, 560, 14, 10, colors.muted, ALIGN.LEFT)
    -- Row 1: feature toggles.
    wnd.weaponProcBtn = ctx.flatButton(p, "power_ranger_weapon_proc_toggle", "", 16, 50, 150, 22, colors.active, function()
        ctx.toggleSetting("weaponProcEnabled")
    end)
    wnd.weaponProcPopupBtn = ctx.flatButton(p, "power_ranger_weapon_proc_popup", "", 174, 50, 150, 22, colors.active, function()
        ctx.toggleSetting("weaponProcReadyPopup")
    end)
    wnd.weaponProcZealBtn = ctx.flatButton(p, "power_ranger_weapon_proc_zeal", "", 332, 50, 150, 22, colors.active, function()
        ctx.toggleSetting("weaponProcZeal")
    end)
    -- Row 2: scale + opacity.
    ctx.label(p, "power_ranger_weapon_proc_scale_label", "Scale", 16, 82, 40, 14, 10, colors.muted, ALIGN.LEFT)
    ctx.flatButton(p, "power_ranger_weapon_proc_scale_down", "-", 56, 80, 24, 20, colors.button, function() ctx.shiftWeaponProcScale(-1) end)
    wnd.weaponProcScaleValue = ctx.label(p, "power_ranger_weapon_proc_scale_value", "0", 84, 83, 24, 14, 10, colors.white, ALIGN.CENTER)
    ctx.flatButton(p, "power_ranger_weapon_proc_scale_up", "+", 112, 80, 24, 20, colors.button, function() ctx.shiftWeaponProcScale(1) end)
    ctx.label(p, "power_ranger_weapon_proc_opacity_label", "Opacity", 152, 84, 50, 14, 10, colors.muted, ALIGN.LEFT)
    -- The row whose hardcoded handler geometry (x=348 w=110) disagreed with its layout
    -- (x=208 w=218) and made clicks land at half scale. Both now come from these arguments.
    wnd.weaponProcOpacitySlider = ctx.slider(p, "power_ranger_weapon_proc_opacity", 208, 82, 218, {
        window = wnd,
        parentOffsetX = PANEL_X,
        min = 0, max = 10, step = 1,
        get = function() return ctx.settings and ctx.settings.weaponProcOpacityLevel or 8 end,
        set = function(v) ctx.setWeaponProcOpacityLevel(v) end,
        format = function(v) return string.format("%.2f", v / 10) end
    })
    -- Row 3: size of the "Proc Ready" / "Zeal Ready" popup that floats over the character.
    ctx.label(p, "power_ranger_weapon_proc_popup_scale_label", "Popup size (over character)", 16, 114, 180, 14, 10, colors.muted, ALIGN.LEFT)
    ctx.flatButton(p, "power_ranger_weapon_proc_popup_scale_down", "-", 200, 112, 24, 20, colors.button, function() ctx.shiftWeaponProcPopupScale(-1) end)
    wnd.weaponProcPopupScaleValue = ctx.label(p, "power_ranger_weapon_proc_popup_scale_value", "0", 228, 115, 24, 14, 10, colors.white, ALIGN.CENTER)
    ctx.flatButton(p, "power_ranger_weapon_proc_popup_scale_up", "+", 256, 112, 24, 20, colors.button, function() ctx.shiftWeaponProcPopupScale(1) end)
    return p
end

return SettingsSections
