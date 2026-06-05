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
    local shiftGuildFamilyScale = ctx.shiftGuildFamilyScale or shiftUiScale
    local fields = ctx.fields or {}
    local classProfiles = ctx.classProfiles
    local cycleClassProfile = ctx.cycleClassProfile
    local toggleClassProfileStat = ctx.toggleClassProfileStat

    local p = sectionPanel(wnd, "power_ranger_window_panel", 18, 232, 584, 358, "Stats Window")
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
    label(p, "power_ranger_stats_labels_title", "Extra labels", 24, 100, 82, 14, 10, colors.gold, ALIGN.LEFT)
    wnd.ownershipBtn = flatButton(p, "power_ranger_toggle_ownership", "", 116, 96, 136, 20, colors.active, function() toggleSetting("showOwnershipLabels") end)
    label(p, "power_ranger_ownership_scale_label", "Scale", 266, 100, 38, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_ownership_scale_down", "-", 306, 96, 22, 20, colors.button, function() shiftUiScale(-1, "ownershipScaleLevel") end)
    wnd.ownershipScaleValue = label(p, "power_ranger_ownership_scale_value", "0", 330, 99, 22, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_ownership_scale_up", "+", 354, 96, 22, 20, colors.button, function() shiftUiScale(1, "ownershipScaleLevel") end)
    wnd.guildFamilyLabelBtn = flatButton(p, "power_ranger_toggle_guild_family_label", "", 116, 122, 136, 20, colors.active, function() toggleSetting("showGuildFamilyLabel") end)
    label(p, "power_ranger_guild_family_size_label", "Size", 266, 126, 30, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_guild_family_size_down", "-", 306, 122, 22, 20, colors.button, function() shiftGuildFamilyScale(-1, "guildFamilyLabelScaleLevel") end)
    wnd.guildFamilyScaleValue = label(p, "power_ranger_guild_family_size_value", "0", 330, 125, 22, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_guild_family_size_up", "+", 354, 122, 22, 20, colors.button, function() shiftGuildFamilyScale(1, "guildFamilyLabelScaleLevel") end)
    label(p, "power_ranger_guild_family_guild_color_label", "Guild", 404, 112, 34, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.guildFamilyGuild = colorCube(p, "power_ranger_guild_family_guild_color", 442, 108, "guildFamilyGuild")
    label(p, "power_ranger_guild_family_family_color_label", "Fam", 470, 112, 28, 14, 10, colors.white, ALIGN.LEFT)
    wnd.colorCubes.guildFamilyFamily = colorCube(p, "power_ranger_guild_family_family_color", 500, 108, "guildFamilyFamily")

    band("profiles", 158, 120)
    label(p, "power_ranger_class_profile_title", "Profile stats", 24, 164, 92, 14, 10, colors.gold, ALIGN.LEFT)
    label(p, "power_ranger_class_profile_label", "Edit", 154, 164, 28, 14, 10, colors.muted, ALIGN.LEFT)
    flatButton(p, "power_ranger_class_profile_prev", "<", 190, 160, 24, 20, colors.button, function() cycleClassProfile(-1) end)
    wnd.classIntelProfileLabel = label(p, "power_ranger_class_profile_value", "General", 220, 163, 116, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_class_profile_next", ">", 342, 160, 24, 20, colors.button, function() cycleClassProfile(1) end)
    wnd.classIntelFieldButtons = {}
    if classProfiles then
        for i, field in ipairs(classProfiles.STATS or {}) do
            local x = 24 + (((i - 1) % 4) * 134)
            local y = 194 + (math.floor((i - 1) / 4) * 28)
            local row = math.floor((i - 1) / 4)
            local tone = row % 2 == 0 and 0.08 or 0.12
            local blueTone = row % 2 == 0 and 0.095 or 0.135
            local bg = p:CreateColorDrawable(tone, tone, blueTone, 0.72, "background")
            bg:SetExtent(124, 22)
            bg:AddAnchor("TOPLEFT", p, x - 4, y - 1)
            bg:Show(true)
            wnd.classIntelFieldButtons[field.key] = flatButton(p, "power_ranger_class_profile_stat_" .. field.key, "", x, y, 94, 20, colors.active, function() toggleClassProfileStat(field.key) end)
            wnd.colorCubes[field.key] = colorCube(p, "power_ranger_class_profile_color_" .. field.key, x + 102, y, field.key)
        end
    end

    band("identity", 286, 54)
    label(p, "power_ranger_stats_field_title", "Identity fields", 24, 292, 96, 14, 10, colors.gold, ALIGN.LEFT)
    wnd.fieldButtons = {}
    for i, field in ipairs(fields) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local x = 24 + (col * 134)
        local y = 314 + (row * 25)
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
    local createIcon = ctx.createIcon
    local cooldownEdit = ctx.cooldownEdit
    local toggleSetting = ctx.toggleSetting
    local shiftUiScale = ctx.shiftUiScale
    local shiftSelfOpacity = ctx.shiftSelfOpacity
    local setSelfOpacityFromMouse = ctx.setSelfOpacityFromMouse
    local toggleProbeLogging = ctx.toggleProbeLogging
    local openDetectedSkillsWindow = ctx.openDetectedSkillsWindow
    local openCooldownSkillsWindow = ctx.openCooldownSkillsWindow
    local shiftCooldownSettingsPage = ctx.shiftCooldownSettingsPage
    local moveCooldownSetting = ctx.moveCooldownSetting
    local toggleCooldownSetting = ctx.toggleCooldownSetting
    local toggleCooldownGroup = ctx.toggleCooldownGroup
    local removeCooldownSetting = ctx.removeCooldownSetting

    local p = sectionPanel(wnd, "power_ranger_self_panel", 18, 602, 584, 344, "Self Cooldowns & Gear")
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
    wnd.selfOpacityTrack = flatButton(p, "power_ranger_self_opacity_track", "", 78, 91, 312, 16, {0.10, 0.10, 0.11, 0.96}, setSelfOpacityFromMouse)
    wnd.selfOpacityFill = wnd.selfOpacityTrack:CreateColorDrawable(1, 0.84, 0, 0.55, "background")
    wnd.selfOpacityFill:AddAnchor("TOPLEFT", wnd.selfOpacityTrack, 1, 1)
    wnd.selfOpacityFill:SetExtent(1, 14)
    wnd.selfOpacityFill:Show(false)
    flatButton(p, "power_ranger_self_opacity_down", "-", 404, 89, 24, 18, colors.button, function() shiftSelfOpacity(-1) end)
    wnd.selfOpacityValue = label(p, "power_ranger_self_opacity_value", "0.80", 432, 91, 42, 14, 10, colors.white, ALIGN.CENTER)
    flatButton(p, "power_ranger_self_opacity_up", "+", 478, 89, 24, 18, colors.button, function() shiftSelfOpacity(1) end)
    label(p, "power_ranger_cd_glider_title", "Gliders", 16, 116, 64, 14, 11, colors.gold, ALIGN.LEFT)
    wnd.cooldownGliderPageLabel = label(p, "power_ranger_cd_glider_page_label", "", 88, 117, 190, 13, 10, colors.muted, ALIGN.LEFT)
    wnd.cooldownGliderShowAllBtn = flatButton(p, "power_ranger_cd_glider_show_all", "Show All", 376, 113, 82, 22, colors.active, function() toggleCooldownGroup("glider") end)
    wnd.cooldownGliderPrevBtn = flatButton(p, "power_ranger_cd_glider_page_prev", "<", 466, 113, 30, 22, colors.button, function() shiftCooldownSettingsPage(-1, "glider") end)
    wnd.cooldownGliderNextBtn = flatButton(p, "power_ranger_cd_glider_page_next", ">", 502, 113, 30, 22, colors.button, function() shiftCooldownSettingsPage(1, "glider") end)
    label(p, "power_ranger_cd_other_title", "Mounts / Skills", 16, 224, 120, 14, 11, colors.gold, ALIGN.LEFT)
    wnd.cooldownOtherPageLabel = label(p, "power_ranger_cd_other_page_label", "", 146, 225, 190, 13, 10, colors.muted, ALIGN.LEFT)
    wnd.cooldownOtherShowAllBtn = flatButton(p, "power_ranger_cd_other_show_all", "Show All", 376, 221, 82, 22, colors.active, function() toggleCooldownGroup("other") end)
    wnd.cooldownOtherPrevBtn = flatButton(p, "power_ranger_cd_other_page_prev", "<", 466, 221, 30, 22, colors.button, function() shiftCooldownSettingsPage(-1, "other") end)
    wnd.cooldownOtherNextBtn = flatButton(p, "power_ranger_cd_other_page_next", ">", 502, 221, 30, 22, colors.button, function() shiftCooldownSettingsPage(1, "other") end)
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
            local nameLabel = label(root, prefix .. "_name_" .. i, "", 32, 6, 148, 14, 10, colors.white, ALIGN.LEFT)
            local sourceLabel = label(root, prefix .. "_source_" .. i, "", 184, 6, 72, 14, 10, colors.muted, ALIGN.LEFT)
            local rowIndex = i
            local infoBtn = flatButton(root, prefix .. "_info_" .. i, "Info", 264, 2, 42, 22, colors.blue, function() openCooldownSkillsWindow(rowIndex, group, "info") end)
            local upBtn = flatButton(root, prefix .. "_up_" .. i, "^", 310, 2, 26, 22, colors.button, function() moveCooldownSetting(rowIndex, -1, group) end)
            local downBtn = flatButton(root, prefix .. "_down_" .. i, "v", 340, 2, 26, 22, colors.button, function() moveCooldownSetting(rowIndex, 1, group) end)
            local skillsBtn = flatButton(root, prefix .. "_skills_" .. i, "Skills", 370, 2, 50, 22, colors.blue, function() openCooldownSkillsWindow(rowIndex, group, "skills") end)
            local btn = flatButton(root, prefix .. "_toggle_" .. i, "", 424, 2, 54, 22, colors.active, function() toggleCooldownSetting(rowIndex, group) end)
            local delBtn = flatButton(root, prefix .. "_delete_" .. i, "Del", 482, 2, 38, 22, colors.danger, function() removeCooldownSetting(rowIndex, group) end)
            nameLabel:Clickable(false)
            sourceLabel:Clickable(false)
            rows[i] = { root = root, icon = rowIcon, name = nameLabel, source = sourceLabel, info = infoBtn, up = upBtn, down = downBtn, skills = skillsBtn, button = btn, del = delBtn }
        end
    end
    createRows(wnd.cooldownGliderRows, "power_ranger_cd_glider", "glider", 138)
    createRows(wnd.cooldownOtherRows, "power_ranger_cd_other", "other", 246)
    return p
end

function SettingsSections.BuildHotSwapLauncher(wnd, ctx, y)
    local colors = ctx.colors
    local p = ctx.sectionPanel(wnd, "power_ranger_hot_swap_panel", 18, y, 584, 56, "Hot Swap")
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
    return p
end

return SettingsSections
