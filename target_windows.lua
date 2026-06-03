local api = require("api")

local TargetWindows = {}

function TargetWindows.CreateModelOverlay(ctx)
    local config = ctx.config
    local colors = ctx.colors
    local label = ctx.label
    local applyReadableTextStyle = ctx.applyReadableTextStyle
    local canvas = api.Interface:CreateEmptyWindow("TargetOverlayMain")
    canvas:SetExtent(1, 1)
    canvas:Show(true)

    local armorIcon = CreateItemIconButton("armorBuffIcon", canvas)
    F_SLOT.ApplySlotSkin(armorIcon, armorIcon.back, SLOT_STYLE.DEFAULT)
    armorIcon:Clickable(false)
    armorIcon:SetExtent(config.buffIconSize, config.buffIconSize)
    armorIcon:AddAnchor("LEFT", canvas, "RIGHT", config.armorBuffOffset, 0)
    armorIcon:Show(false)

    local weaponIcon = CreateItemIconButton("weaponBuffIcon", canvas)
    F_SLOT.ApplySlotSkin(weaponIcon, weaponIcon.back, SLOT_STYLE.DEFAULT)
    weaponIcon:Clickable(false)
    weaponIcon:SetExtent(config.buffIconSize, config.buffIconSize)
    weaponIcon:AddAnchor("RIGHT", canvas, "LEFT", config.weaponBuffOffset, 0)
    weaponIcon:Show(false)

    local pdefTitle = canvas:CreateChildWidget("label", "targetPdefTitle", 0, true)
    pdefTitle:SetExtent(54, 13)
    pdefTitle.style:SetFontSize(10)
    applyReadableTextStyle(pdefTitle, true)
    pdefTitle.style:SetAlign(ALIGN.CENTER)
    pdefTitle.style:SetColor(1, 1, 1, 1)
    pdefTitle:AddAnchor("RIGHT", weaponIcon, "LEFT", 0, -5)
    pdefTitle:SetText("PDef")
    pdefTitle:Show(false)

    local pdefValue = canvas:CreateChildWidget("label", "targetPdefValue", 0, true)
    pdefValue:SetExtent(54, 13)
    pdefValue.style:SetFontSize(10)
    applyReadableTextStyle(pdefValue, true)
    pdefValue.style:SetAlign(ALIGN.CENTER)
    pdefValue.style:SetColor(1, 1, 1, 1)
    pdefValue:AddAnchor("TOP", pdefTitle, "BOTTOM", 0, -1)
    pdefValue:Show(false)

    local mdefTitle = canvas:CreateChildWidget("label", "targetMdefTitle", 0, true)
    mdefTitle:SetExtent(54, 13)
    mdefTitle.style:SetFontSize(10)
    applyReadableTextStyle(mdefTitle, true)
    mdefTitle.style:SetAlign(ALIGN.CENTER)
    mdefTitle.style:SetColor(1, 1, 1, 1)
    mdefTitle:AddAnchor("LEFT", armorIcon, "RIGHT", -3, -5)
    mdefTitle:SetText("MDef")
    mdefTitle:Show(false)

    local mdefValue = canvas:CreateChildWidget("label", "targetMdefValue", 0, true)
    mdefValue:SetExtent(54, 13)
    mdefValue.style:SetFontSize(10)
    applyReadableTextStyle(mdefValue, true)
    mdefValue.style:SetAlign(ALIGN.CENTER)
    mdefValue.style:SetColor(1, 1, 1, 1)
    mdefValue:AddAnchor("TOP", mdefTitle, "BOTTOM", 0, -1)
    mdefValue:Show(false)

    local roleIcon = canvas:CreateImageDrawable("Textures/Defaults/White.dds", "overlay")
    roleIcon:SetExtent(config.roleIconSize, config.roleIconSize)
    roleIcon:SetVisible(false)
    roleIcon:SetSRGB(false)

    local gearscore = canvas:CreateChildWidget("label", "targetGearscore", 0, true)
    gearscore:SetAutoResize(false)
    gearscore:SetExtent(90, config.fontSize + 4)
    gearscore.style:SetFontSize(config.fontSize)
    applyReadableTextStyle(gearscore, true)
    gearscore.style:SetAlign(ALIGN.CENTER)
    gearscore:AddAnchor("TOP", canvas, "BOTTOM", 0, config.gearscoreOffset)
    gearscore:Show(false)

    local classLabel = canvas:CreateChildWidget("label", "targetClass", 0, true)
    classLabel:SetExtent(180, 16)
    classLabel.style:SetFontSize(config.fontSize)
    applyReadableTextStyle(classLabel, true)
    classLabel.style:SetAlign(ALIGN.CENTER)
    classLabel.style:SetColor(1, 1, 1, 1)
    classLabel:AddAnchor("TOP", gearscore, "BOTTOM", -10, -1)
    classLabel:Show(false)

    local rangeCanvas = api.Interface:CreateEmptyWindow("PowerRangerModelRange", "UIParent")
    rangeCanvas:SetExtent(86, config.fontSize + 6)
    if rangeCanvas.Clickable then rangeCanvas:Clickable(false) end
    local rangeLabel = label(rangeCanvas, "targetRange", "", 0, 0, 86, config.fontSize + 6, config.fontSize, colors.gold, ALIGN.CENTER)
    applyReadableTextStyle(rangeLabel, true)
    rangeLabel:Show(false)
    rangeCanvas:Show(false)

    return {
        canvas = canvas,
        armorBuffIcon = armorIcon,
        weaponBuffIcon = weaponIcon,
        targetPdefTitleLabel = pdefTitle,
        targetPdefValueLabel = pdefValue,
        targetMdefTitleLabel = mdefTitle,
        targetMdefValueLabel = mdefValue,
        targetRoleIcon = roleIcon,
        targetGearscoreLabel = gearscore,
        targetClassLabel = classLabel,
        targetRangeCanvas = rangeCanvas,
        targetRangeLabel = rangeLabel
    }
end

function TargetWindows.CreateTargetInfo(ctx)
    local colors = ctx.colors
    local settings = ctx.settings or {}
    local label = ctx.label
    local wnd = api.Interface:CreateEmptyWindow("PowerRangerTargetInfo", "UIParent")
    wnd:SetExtent(430, 150)
    local x, y = ctx.safePosition(settings.targetWindowX, settings.targetWindowY, 430, 150)
    wnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    if wnd.Clickable then wnd:Clickable(false) end
    wnd.bg = ctx.addBg(wnd, 0, 0, 0, 0.62)
    local header = wnd:CreateColorDrawable(0.06, 0.075, 0.095, 0.76, "background")
    header:SetExtent(430, 22)
    header:AddAnchor("TOPLEFT", wnd, 0, 0)
    header:Show(true)
    wnd.header = header
    local title = label(wnd, "power_ranger_target_info_title", "Power Ranger ON", 8, 3, 414, 16, 14, colors.gold, ALIGN.LEFT)
    title:Clickable(false)
    wnd.title = title
    wnd.simpleMeta = label(wnd, "power_ranger_target_info_simple_meta", "", 8, 18, 414, 14, 11, colors.white, ALIGN.LEFT)
    wnd.simpleMeta:Clickable(false)
    wnd.simpleMeta:Show(false)
    local dragHandle = wnd:CreateChildWidget("emptywidget", "power_ranger_target_info_drag", 0, true)
    dragHandle:SetExtent(430, 22)
    dragHandle:AddAnchor("TOPLEFT", wnd, 0, 0)
    dragHandle:Show(true)
    wnd.dragHandle = dragHandle
    ctx.applyHandleDrag(wnd, dragHandle, "targetWindowX", "targetWindowY")
    wnd.rows = {}
    wnd.simpleValues = {}
    for i = 1, 16 do
        wnd.rows[i] = label(wnd, "power_ranger_info_row_" .. i, "", 12, 30, 198, 16, 12, colors.white, ALIGN.LEFT)
        wnd.rows[i]:Clickable(false)
        wnd.simpleValues[i] = label(wnd, "power_ranger_info_simple_value_" .. i, "", 12, 30, 96, 16, 12, colors.white, ALIGN.LEFT)
        wnd.simpleValues[i]:Clickable(false)
        wnd.simpleValues[i]:Show(false)
    end
    wnd:Show(false)
    return wnd
end

function TargetWindows.CreateOwnership(ctx)
    local colors = ctx.colors
    local settings = ctx.settings or {}
    local label = ctx.label
    local wnd = api.Interface:CreateEmptyWindow("PowerRangerOwnershipInfo", "UIParent")
    wnd:SetExtent(360, 42)
    local x, y = ctx.safePosition(settings.ownershipWindowX, settings.ownershipWindowY, 360, 42)
    wnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    if wnd.Clickable then wnd:Clickable(false) end
    wnd.title = label(wnd, "power_ranger_ownership_title", "", 4, 0, 352, 20, 15, colors.white, ALIGN.LEFT)
    wnd.title:Clickable(false)
    wnd.meta = label(wnd, "power_ranger_ownership_meta", "", 4, 20, 352, 16, 11, colors.white, ALIGN.LEFT)
    wnd.meta:Clickable(false)
    ctx.applyReadableTextStyle(wnd.title, true)
    ctx.applyReadableTextStyle(wnd.meta, true)
    local dragHandle = wnd:CreateChildWidget("emptywidget", "power_ranger_ownership_drag", 0, true)
    dragHandle:SetExtent(360, 42)
    dragHandle:AddAnchor("TOPLEFT", wnd, 0, 0)
    dragHandle:Show(true)
    wnd.dragHandle = dragHandle
    ctx.applyHandleDrag(wnd, dragHandle, "ownershipWindowX", "ownershipWindowY")
    wnd:Show(false)
    return wnd
end

function TargetWindows.CreateSelf(ctx)
    local colors = ctx.colors
    local settings = ctx.settings or {}
    local panel = ctx.selfPanel
    local label = ctx.label
    local wnd = api.Interface:CreateEmptyWindow("PowerRangerSelf", "UIParent")
    wnd:SetExtent(panel.minWidth, panel.height)
    local x, y = ctx.safePosition(settings.selfX, settings.selfY, panel.minWidth, panel.height)
    wnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    if wnd.Clickable then wnd:Clickable(false) end
    ctx.addBg(wnd, 0, 0, 0, 0.62)
    wnd.header = wnd:CreateColorDrawable(0.06, 0.075, 0.095, 0.76, "background")
    wnd.header:SetExtent(panel.minWidth, panel.headerHeight)
    wnd.header:AddAnchor("TOPLEFT", wnd, 0, 0)
    wnd.header:Show(true)
    local title = label(wnd, "power_ranger_self_title", "Self CDs", 8, 3, 110, 14, 11, colors.gold, ALIGN.LEFT)
    title:Clickable(false)
    wnd.title = title
    wnd.dragHandle = wnd:CreateChildWidget("emptywidget", "power_ranger_self_drag", 0, true)
    wnd.dragHandle:SetExtent(panel.minWidth, panel.headerHeight)
    wnd.dragHandle:AddAnchor("TOPLEFT", wnd, 0, 0)
    wnd.dragHandle:Show(true)
    ctx.applyHandleDrag(wnd, wnd.dragHandle, "selfX", "selfY")
    wnd.status = label(wnd, "power_ranger_self_status", "", 112, 3, 48, 14, 10, colors.muted, ALIGN.RIGHT)
    wnd.status:Clickable(false)
    wnd.gliderIcons = {}
    wnd.gliderLabels = {}
    wnd.mountIcons = {}
    wnd.mountLabels = {}
    for i = 1, panel.maxRowIcons do
        local xPos = panel.left + ((i - 1) * panel.iconStep)
        wnd.gliderIcons[i] = ctx.createIcon(wnd, "power_ranger_self_glider_cd_icon_" .. i, xPos, panel.gliderY, panel.iconSize)
        wnd.gliderLabels[i] = label(wnd, "power_ranger_self_glider_cd_label_" .. i, "", xPos - 3, panel.gliderY + 28, 34, 10, 7, colors.white, ALIGN.CENTER)
        wnd.mountIcons[i] = ctx.createIcon(wnd, "power_ranger_self_mount_cd_icon_" .. i, xPos, panel.mountY, panel.iconSize)
        wnd.mountLabels[i] = label(wnd, "power_ranger_self_mount_cd_label_" .. i, "", xPos - 3, panel.mountY + 28, 34, 10, 7, colors.white, ALIGN.CENTER)
        wnd.gliderLabels[i]:Clickable(false)
        wnd.mountLabels[i]:Clickable(false)
    end
    wnd.equipIcons = {}
    wnd.equipLabels = {}
    wnd.equipIcons[1] = ctx.createIcon(wnd, "power_ranger_self_equip_weapon", panel.left, panel.equipY, 24)
    wnd.equipLabels[1] = label(wnd, "power_ranger_self_equip_weapon_label", "Weapon", panel.left - 10, panel.equipY + 24, 46, 10, 7, colors.muted, ALIGN.CENTER)
    wnd.equipIcons[2] = ctx.createIcon(wnd, "power_ranger_self_equip_offhand", panel.left + 42, panel.equipY, 24)
    wnd.equipLabels[2] = label(wnd, "power_ranger_self_equip_offhand_label", "Offhand", panel.left + 32, panel.equipY + 24, 46, 10, 7, colors.muted, ALIGN.CENTER)
    wnd.equipIcons[3] = ctx.createIcon(wnd, "power_ranger_self_equip_glider", panel.left + 84, panel.equipY, 24)
    wnd.equipLabels[3] = label(wnd, "power_ranger_self_equip_glider_label", "Glider", panel.left + 74, panel.equipY + 24, 46, 10, 7, colors.muted, ALIGN.CENTER)
    wnd.equipLabels[1]:Clickable(false)
    wnd.equipLabels[2]:Clickable(false)
    wnd.equipLabels[3]:Clickable(false)
    wnd:Show(false)
    return wnd
end

return TargetWindows
