local SettingsSections = {}

function SettingsSections.BuildTargetOverhead(wnd, ctx)
    local colors = ctx.colors
    local sectionPanel = ctx.sectionPanel
    local label = ctx.label
    local flatButton = ctx.flatButton
    local colorCube = ctx.colorCube
    local toggleSetting = ctx.toggleSetting
    local shiftUiScale = ctx.shiftUiScale
    local shiftCompactModelLeft = ctx.shiftCompactModelLeft
    local shiftModelRangeOffset = ctx.shiftModelRangeOffset
    local cycleOverlayTextStyle = ctx.cycleOverlayTextStyle

    local p = sectionPanel(wnd, "power_ranger_model_panel", 18, 52, 584, 168, "Target Overhead")
    wnd.modelCompactBtn = flatButton(p, "power_ranger_toggle_model_compact", "", 16, 32, 116, 20, colors.active, function() toggleSetting("compactModelOverlay") end)
    label(p, "power_ranger_scale_label", "Scale", 144, 35, 36, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_scale_down", "-", 182, 32, 22, 20, colors.button, function() shiftUiScale(-1) end)
    wnd.scaleValue = label(p, "power_ranger_scale_value", "0", 206, 35, 20, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_scale_up", "+", 228, 32, 22, 20, colors.button, function() shiftUiScale(1) end)
    label(p, "power_ranger_model_left_label", "Left", 266, 35, 28, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_model_left_down", "-", 296, 32, 22, 20, colors.button, function() shiftCompactModelLeft(-1) end)
    wnd.modelLeftValue = label(p, "power_ranger_model_left_value", "45", 320, 35, 26, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_model_left_up", "+", 348, 32, 22, 20, colors.button, function() shiftCompactModelLeft(1) end)
    wnd.shadowBtn = flatButton(p, "power_ranger_toggle_text_style", "", 388, 32, 154, 20, colors.active, cycleOverlayTextStyle)
    wnd.modelBtn = flatButton(p, "power_ranger_toggle_model", "", 16, 56, 126, 24, colors.active, function() toggleSetting("showModelOverlay") end)
    wnd.armorBtn = flatButton(p, "power_ranger_toggle_armor", "", 152, 56, 126, 24, colors.active, function() toggleSetting("showArmorIcon") end)
    wnd.weaponBtn = flatButton(p, "power_ranger_toggle_weapon", "", 288, 56, 126, 24, colors.active, function() toggleSetting("showWeaponIcon") end)
    wnd.roleBtn = flatButton(p, "power_ranger_toggle_role", "", 424, 56, 126, 24, colors.active, function() toggleSetting("showRoleIcon") end)
    wnd.modelGsBtn = flatButton(p, "power_ranger_toggle_model_gs", "", 16, 84, 126, 24, colors.active, function() toggleSetting("showModelGearscore") end)
    wnd.modelClassBtn = flatButton(p, "power_ranger_toggle_model_class", "", 152, 84, 126, 24, colors.active, function() toggleSetting("showModelClass") end)
    wnd.modelRangeBtn = flatButton(p, "power_ranger_toggle_model_range", "", 288, 84, 126, 24, colors.active, function() toggleSetting("showModelRange") end)
    wnd.modelDefBtn = flatButton(p, "power_ranger_toggle_model_def", "", 424, 84, 126, 24, colors.active, function() toggleSetting("showModelDefense") end)
    label(p, "power_ranger_model_color_label", "Colors", 16, 116, 44, 14, 10, colors.muted, ALIGN.LEFT)
    label(p, "power_ranger_model_color_dist", "Dist", 72, 116, 28, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.modelRange = colorCube(p, "power_ranger_model_color_range", 102, 112, "modelRange")
    label(p, "power_ranger_model_color_gs", "GS", 132, 116, 22, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.modelGearscore = colorCube(p, "power_ranger_model_color_gs_cube", 156, 112, "modelGearscore")
    label(p, "power_ranger_model_color_class", "Class", 188, 116, 42, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.modelClass = colorCube(p, "power_ranger_model_color_class_cube", 230, 112, "modelClass")
    label(p, "power_ranger_model_range_scale_label", "Range size", 16, 144, 70, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_model_range_scale_down", "-", 92, 140, 24, 20, colors.button, function() shiftUiScale(-1, "modelRangeScaleLevel") end)
    wnd.modelRangeScaleValue = label(p, "power_ranger_model_range_scale_value", "0", 120, 143, 24, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_model_range_scale_up", "+", 148, 140, 24, 20, colors.button, function() shiftUiScale(1, "modelRangeScaleLevel") end)
    label(p, "power_ranger_model_range_pos_label", "Pos", 194, 144, 24, 14, 10, colors.muted, ALIGN.LEFT)
    label(p, "power_ranger_model_range_x_label", "X", 224, 144, 12, 14, 10, colors.white, ALIGN.LEFT)
    flatButton(p, "power_ranger_model_range_x_down", "-", 240, 140, 22, 20, colors.button, function() shiftModelRangeOffset("x", -2) end)
    wnd.modelRangeXValue = label(p, "power_ranger_model_range_x_value", "0", 264, 143, 28, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_model_range_x_up", "+", 294, 140, 22, 20, colors.button, function() shiftModelRangeOffset("x", 2) end)
    label(p, "power_ranger_model_range_y_label", "Y", 326, 144, 12, 14, 10, colors.white, ALIGN.LEFT)
    flatButton(p, "power_ranger_model_range_y_down", "-", 342, 140, 22, 20, colors.button, function() shiftModelRangeOffset("y", -2) end)
    wnd.modelRangeYValue = label(p, "power_ranger_model_range_y_value", "0", 366, 143, 28, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_model_range_y_up", "+", 396, 140, 22, 20, colors.button, function() shiftModelRangeOffset("y", 2) end)
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
    local fields = ctx.fields or {}

    local p = sectionPanel(wnd, "power_ranger_window_panel", 18, 232, 584, 229, "Intel Window")
    wnd.targetWindowBtn = flatButton(p, "power_ranger_toggle_window", "", 16, 32, 124, 22, colors.active, function() toggleSetting("showTargetWindow") end)
    wnd.compactWindowBtn = flatButton(p, "power_ranger_toggle_compact_window", "", 148, 32, 96, 22, colors.active, function() toggleSetting("compactTargetWindow") end)
    wnd.testWindowBtn = flatButton(p, "power_ranger_toggle_test_window", "", 252, 32, 142, 22, colors.active, function() toggleSetting("testTargetWindow") end)
    label(p, "power_ranger_intel_scale_label", "Scale", 406, 36, 40, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_intel_scale_down", "-", 448, 32, 24, 20, colors.button, function() shiftUiScale(-1, "targetWindowScaleLevel") end)
    wnd.intelScaleValue = label(p, "power_ranger_intel_scale_value", "0", 476, 35, 24, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_intel_scale_up", "+", 504, 32, 24, 20, colors.button, function() shiftUiScale(1, "targetWindowScaleLevel") end)
    label(p, "power_ranger_simple_spacing_label", "Simple spacing", 16, 64, 92, 14, 10, colors.muted, ALIGN.LEFT)
    label(p, "power_ranger_simple_columns_label", "Columns", 116, 64, 54, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_simple_columns_down", "-", 174, 60, 24, 20, colors.button, function() shiftSimpleSpacing("simpleColumnGap", -1, 0, 73) end)
    wnd.simpleColumnGapValue = label(p, "power_ranger_simple_columns_value", "0", 202, 63, 24, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_simple_columns_up", "+", 230, 60, 24, 20, colors.button, function() shiftSimpleSpacing("simpleColumnGap", 1, 0, 73) end)
    label(p, "power_ranger_simple_lines_label", "Lines", 282, 64, 38, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_simple_lines_down", "-", 324, 60, 24, 20, colors.button, function() shiftSimpleSpacing("simpleLineGap", -1, 0, 23) end)
    wnd.simpleLineGapValue = label(p, "power_ranger_simple_lines_value", "0", 352, 63, 24, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_simple_lines_up", "+", 380, 60, 24, 20, colors.button, function() shiftSimpleSpacing("simpleLineGap", 1, 0, 23) end)
    label(p, "power_ranger_ownership_label", "Land / vehicle ownership", 16, 92, 148, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.ownershipBtn = flatButton(p, "power_ranger_toggle_ownership", "", 168, 88, 142, 20, colors.active, function() toggleSetting("showOwnershipLabels") end)
    label(p, "power_ranger_ownership_scale_label", "Scale", 326, 92, 40, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_ownership_scale_down", "-", 368, 88, 24, 20, colors.button, function() shiftUiScale(-1, "ownershipScaleLevel") end)
    wnd.ownershipScaleValue = label(p, "power_ranger_ownership_scale_value", "0", 396, 91, 24, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_ownership_scale_up", "+", 424, 88, 24, 20, colors.button, function() shiftUiScale(1, "ownershipScaleLevel") end)
    wnd.fieldButtons = {}
    for i, field in ipairs(fields) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local x = 16 + (col * 138)
        local y = 118 + (row * 27)
        local tone = row % 2 == 0 and 0.08 or 0.12
        local blueTone = row % 2 == 0 and 0.095 or 0.135
        local bg = p:CreateColorDrawable(tone, tone, blueTone, 0.72, "background")
        bg:SetExtent(128, 22)
        bg:AddAnchor("TOPLEFT", p, x - 4, y - 1)
        bg:Show(true)
        wnd.fieldButtons[field.key] = flatButton(p, "power_ranger_info_field_" .. field.key, "", x, y, 98, 20, colors.active, function() toggleSetting(field.setting) end)
        wnd.colorCubes[field.key] = colorCube(p, "power_ranger_info_color_" .. field.key, x + 106, y, field.key)
    end
    return p
end

function SettingsSections.BuildSelfCooldowns(wnd, ctx)
    local colors = ctx.colors
    local sectionPanel = ctx.sectionPanel
    local label = ctx.label
    local flatButton = ctx.flatButton
    local createIcon = ctx.createIcon
    local cooldownEdit = ctx.cooldownEdit
    local toggleSetting = ctx.toggleSetting
    local shiftUiScale = ctx.shiftUiScale
    local toggleProbeLogging = ctx.toggleProbeLogging
    local openDetectedSkillsWindow = ctx.openDetectedSkillsWindow
    local shiftCooldownSettingsPage = ctx.shiftCooldownSettingsPage
    local moveCooldownSetting = ctx.moveCooldownSetting
    local toggleCooldownSetting = ctx.toggleCooldownSetting
    local removeCooldownSetting = ctx.removeCooldownSetting

    local p = sectionPanel(wnd, "power_ranger_self_panel", 18, 473, 584, 318, "Self Cooldowns & Gear")
    label(p, "power_ranger_self_hint", "Known cooldown auras stay ID-based.", 14, 32, 264, 14, 10, colors.muted, ALIGN.LEFT)
    wnd.nuziImportBtn = flatButton(p, "power_ranger_toggle_nuzi_cd_import", "", 286, 29, 104, 20, colors.blue, function() toggleSetting("importNuziCooldowns") end)
    label(p, "power_ranger_self_scale_label", "Scale", 410, 32, 40, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_self_scale_down", "-", 452, 29, 24, 20, colors.button, function() shiftUiScale(-1, "selfScaleLevel") end)
    wnd.selfScaleValue = label(p, "power_ranger_self_scale_value", "0", 480, 32, 24, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_self_scale_up", "+", 508, 29, 24, 20, colors.button, function() shiftUiScale(1, "selfScaleLevel") end)
    wnd.selfBtn = flatButton(p, "power_ranger_toggle_self", "", 16, 58, 98, 24, colors.active, function() toggleSetting("showSelfPanel") end)
    wnd.selfCdBtn = flatButton(p, "power_ranger_toggle_self_cd", "", 120, 58, 104, 24, colors.active, function() toggleSetting("showSelfCooldowns") end)
    wnd.selfEquipmentBtn = flatButton(p, "power_ranger_toggle_self_equipment", "", 230, 58, 110, 24, colors.active, function() toggleSetting("showSelfEquipment") end)
    wnd.probeLogBtn = flatButton(p, "power_ranger_probe_log", "", 346, 58, 72, 24, colors.blue, toggleProbeLogging)
    flatButton(p, "power_ranger_detected_open", "Detected", 424, 58, 110, 24, colors.blue, openDetectedSkillsWindow)
    label(p, "power_ranger_cd_glider_title", "Gliders", 16, 90, 64, 14, 11, colors.gold, ALIGN.LEFT)
    wnd.cooldownGliderPageLabel = label(p, "power_ranger_cd_glider_page_label", "", 88, 91, 190, 13, 10, colors.muted, ALIGN.LEFT)
    wnd.cooldownGliderPrevBtn = flatButton(p, "power_ranger_cd_glider_page_prev", "<", 466, 87, 30, 22, colors.button, function() shiftCooldownSettingsPage(-1, "glider") end)
    wnd.cooldownGliderNextBtn = flatButton(p, "power_ranger_cd_glider_page_next", ">", 502, 87, 30, 22, colors.button, function() shiftCooldownSettingsPage(1, "glider") end)
    label(p, "power_ranger_cd_other_title", "Mounts / Skills", 16, 198, 120, 14, 11, colors.gold, ALIGN.LEFT)
    wnd.cooldownOtherPageLabel = label(p, "power_ranger_cd_other_page_label", "", 146, 199, 190, 13, 10, colors.muted, ALIGN.LEFT)
    wnd.cooldownOtherPrevBtn = flatButton(p, "power_ranger_cd_other_page_prev", "<", 466, 195, 30, 22, colors.button, function() shiftCooldownSettingsPage(-1, "other") end)
    wnd.cooldownOtherNextBtn = flatButton(p, "power_ranger_cd_other_page_next", ">", 502, 195, 30, 22, colors.button, function() shiftCooldownSettingsPage(1, "other") end)
    wnd.cooldownGliderRows = {}
    wnd.cooldownOtherRows = {}

    local function createRows(rows, prefix, group, startY)
        for i = 1, 3 do
            local y = startY + ((i - 1) * 28)
            local root = p:CreateChildWidget("emptywidget", prefix .. "_row_" .. i, 0, true)
            root:SetExtent(552, 26)
            root:AddAnchor("TOPLEFT", p, 16, y)
            local tone = i % 2 == 0 and 0.11 or 0.075
            local blueTone = i % 2 == 0 and 0.125 or 0.09
            local bg = root:CreateColorDrawable(tone, tone, blueTone, 0.74, "background")
            bg:AddAnchor("TOPLEFT", root, 0, 0)
            bg:AddAnchor("BOTTOMRIGHT", root, 0, 0)
            bg:Show(true)
            local rowIcon = createIcon(root, prefix .. "_icon_" .. i, 3, 2, 22)
            local nameLabel = label(root, prefix .. "_name_" .. i, "", 32, 6, 136, 14, 10, colors.white, ALIGN.LEFT)
            local sourceLabel = label(root, prefix .. "_source_" .. i, "", 172, 6, 122, 14, 10, colors.muted, ALIGN.LEFT)
            local cdField = cooldownEdit(root, prefix .. "_cd_" .. i, 302, 3, 40, 20)
            local rowIndex = i
            local upBtn = flatButton(root, prefix .. "_up_" .. i, "^", 350, 2, 28, 22, colors.button, function() moveCooldownSetting(rowIndex, -1, group) end)
            local downBtn = flatButton(root, prefix .. "_down_" .. i, "v", 382, 2, 28, 22, colors.button, function() moveCooldownSetting(rowIndex, 1, group) end)
            local btn = flatButton(root, prefix .. "_toggle_" .. i, "", 418, 2, 72, 22, colors.active, function() toggleCooldownSetting(rowIndex, group) end)
            local removeBtn = flatButton(root, prefix .. "_remove_" .. i, "Del", 498, 2, 42, 22, {0.24, 0.09, 0.09, 0.95}, function() removeCooldownSetting(rowIndex, group) end)
            nameLabel:Clickable(false)
            sourceLabel:Clickable(false)
            removeBtn:Show(false)
            rows[i] = { root = root, icon = rowIcon, name = nameLabel, source = sourceLabel, cd = cdField, up = upBtn, down = downBtn, button = btn, remove = removeBtn }
        end
    end
    createRows(wnd.cooldownGliderRows, "power_ranger_cd_glider", "glider", 112)
    createRows(wnd.cooldownOtherRows, "power_ranger_cd_other", "other", 220)
    return p
end

function SettingsSections.BuildHotSwapLauncher(wnd, ctx, y)
    local colors = ctx.colors
    local p = ctx.sectionPanel(wnd, "power_ranger_hot_swap_panel", 18, y, 584, 56, "Hot Swap")
    ctx.label(p, "power_ranger_hot_swap_hint", "Manage embedded gear sets and open direction.", 14, 32, 290, 14, 10, colors.muted, ALIGN.LEFT)
    ctx.flatButton(p, "power_ranger_hot_swap_settings_open", "Hot Swap Settings", 398, 28, 144, 22, colors.blue, function()
        local hotSwap = require("power_ranger_on/hot_swap")
        if hotSwap and hotSwap.toggleSettings then hotSwap.toggleSettings() end
    end)
    return p
end

return SettingsSections
