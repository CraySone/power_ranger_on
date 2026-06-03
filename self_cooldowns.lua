local api = require("api")

local SelfCooldowns = {}

local function panelWidth(panel, scale, gliderCount, mountCount, equipmentVisible)
    local count = math.max(equipmentVisible and 3 or 0, tonumber(gliderCount) or 0, tonumber(mountCount) or 0)
    return math.floor((math.max(panel.minWidth, panel.left + (count * panel.iconStep) + 4) * scale) + 0.5)
end

local function setEquipmentVisible(wnd, visible)
    if not wnd or not wnd.equipIcons then return end
    for i, icon in ipairs(wnd.equipIcons) do
        icon:Show(visible)
        if wnd.equipLabels[i] then wnd.equipLabels[i]:Show(visible) end
    end
end

local function positionEquipmentRow(ctx, y)
    local wnd = ctx.selfWnd
    if not wnd or not wnd.equipIcons then return end
    local scale = ctx.scale()
    local panel = ctx.panel
    local xs = { panel.left, panel.left + 42, panel.left + 84 }
    for i, icon in ipairs(wnd.equipIcons) do
        local x = math.floor((xs[i] * scale) + 0.5)
        local iconY = math.floor((y * scale) + 0.5)
        icon:SetExtent(math.floor((24 * scale) + 0.5), math.floor((24 * scale) + 0.5))
        icon:RemoveAllAnchors()
        icon:AddAnchor("TOPLEFT", wnd, x, iconY)
        if icon.timerLabel then
            icon.timerLabel:SetExtent(math.floor((24 * scale) + 0.5), math.floor((24 * scale) + 0.5))
            icon.timerLabel.style:SetFontSize(math.floor((10 * scale) + 0.5))
        end
        wnd.equipLabels[i]:RemoveAllAnchors()
        wnd.equipLabels[i]:SetExtent(math.floor((46 * scale) + 0.5), math.floor((10 * scale) + 0.5))
        wnd.equipLabels[i].style:SetFontSize(math.floor((7 * scale) + 0.5))
        wnd.equipLabels[i]:AddAnchor("TOPLEFT", wnd, math.floor(((xs[i] - 10) * scale) + 0.5), math.floor(((y + 24) * scale) + 0.5))
    end
end

local function resizePanel(ctx, gliderCount, mountCount, cooldownsVisible, equipmentVisible)
    local wnd = ctx.selfWnd
    if not wnd then return end
    local panel = ctx.panel
    local scale = ctx.scale()
    local width = panelWidth(panel, scale, gliderCount, mountCount, equipmentVisible)
    local baseHeight = cooldownsVisible and (equipmentVisible and panel.height or 104) or (equipmentVisible and 60 or panel.headerHeight)
    local height = math.floor((baseHeight * scale) + 0.5)
    local equipY = cooldownsVisible and panel.equipY or panel.gliderY
    if equipmentVisible and wnd._equipY ~= equipY then
        positionEquipmentRow(ctx, equipY)
        wnd._equipY = equipY
    end
    setEquipmentVisible(wnd, equipmentVisible)
    if wnd._lastWidth ~= width or wnd._lastHeight ~= height then
        wnd:SetExtent(width, height)
        if wnd.header then wnd.header:SetExtent(width, math.floor((panel.headerHeight * scale) + 0.5)) end
        if wnd.dragHandle then wnd.dragHandle:SetExtent(width, math.floor((panel.headerHeight * scale) + 0.5)) end
        if wnd.title then
            wnd.title:RemoveAllAnchors()
            wnd.title:AddAnchor("TOPLEFT", wnd, math.floor((8 * scale) + 0.5), math.floor((3 * scale) + 0.5))
            wnd.title:SetExtent(math.floor((110 * scale) + 0.5), math.floor((14 * scale) + 0.5))
            wnd.title.style:SetFontSize(math.floor((11 * scale) + 0.5))
        end
        if wnd.status then
            if wnd.status.RemoveAllAnchors then wnd.status:RemoveAllAnchors() end
            wnd.status:SetExtent(math.max(math.floor((46 * scale) + 0.5), width - math.floor((116 * scale) + 0.5)), math.floor((14 * scale) + 0.5))
            wnd.status.style:SetFontSize(math.floor((10 * scale) + 0.5))
            wnd.status:AddAnchor("TOPLEFT", wnd, math.floor((112 * scale) + 0.5), math.floor((3 * scale) + 0.5))
        end
        wnd._lastWidth = width
        wnd._lastHeight = height
    end
end

local function clearRow(icons, labels)
    for i, icon in ipairs(icons or {}) do
        icon:Show(false)
        if labels and labels[i] then labels[i]:SetText("") end
    end
end

local function ensureRow(ctx, icons, labels, prefix, y, wanted)
    local wnd = ctx.selfWnd
    if not wnd then return end
    local scale = ctx.scale()
    local panel = ctx.panel
    local count = math.max(tonumber(wanted) or 0, #icons)
    for i = #icons + 1, count do
        local x = math.floor(((panel.left + ((i - 1) * panel.iconStep)) * scale) + 0.5)
        icons[i] = ctx.createIcon(wnd, prefix .. "_icon_" .. i, x, math.floor((y * scale) + 0.5), math.floor((panel.iconSize * scale) + 0.5))
        labels[i] = ctx.label(wnd, prefix .. "_label_" .. i, "", math.floor(((panel.left + ((i - 1) * panel.iconStep) - 3) * scale) + 0.5), math.floor(((y + 28) * scale) + 0.5), math.floor((34 * scale) + 0.5), math.floor((10 * scale) + 0.5), math.floor((7 * scale) + 0.5), ctx.colors.white, ALIGN.CENTER)
        labels[i]:Clickable(false)
    end
    for i, icon in ipairs(icons) do
        local x = panel.left + ((i - 1) * panel.iconStep)
        local size = math.floor((panel.iconSize * scale) + 0.5)
        icon:SetExtent(size, size)
        icon:RemoveAllAnchors()
        icon:AddAnchor("TOPLEFT", wnd, math.floor((x * scale) + 0.5), math.floor((y * scale) + 0.5))
        if icon.timerLabel then
            icon.timerLabel:SetExtent(size, size)
            icon.timerLabel.style:SetFontSize(math.floor((10 * scale) + 0.5))
        end
        labels[i]:SetExtent(math.floor((34 * scale) + 0.5), math.floor((10 * scale) + 0.5))
        labels[i].style:SetFontSize(math.floor((7 * scale) + 0.5))
        labels[i]:RemoveAllAnchors()
        labels[i]:AddAnchor("TOPLEFT", wnd, math.floor(((x - 3) * scale) + 0.5), math.floor(((y + 28) * scale) + 0.5))
    end
end

local function renderRow(ctx, icons, labels, entries)
    for i, icon in ipairs(icons or {}) do
        local entry = entries and entries[i]
        if entry then
            ctx.setCooldownSkillIcon(icon, entry.icon, entry.state or "ready", entry.remain)
            if labels and labels[i] then labels[i]:SetText(ctx.shortText(entry.name, 7)) end
        else
            icon:Show(false)
            if labels and labels[i] then labels[i]:SetText("") end
        end
    end
end

local function trackedBuffEntry(ctx, row, st, glider, mount)
    local name = row.name or st.name or tostring(row.id)
    local iconState = "ready"
    local remain = nil
    if st.active then
        if (row.cooldownOnlyOnActive or ctx.isStarTriggerCooldown(row)) and st.readyAt then
            remain = math.max(0, math.ceil((st.readyAt - api.Time:GetUiMsec()) / 1000))
            iconState = "cooldown"
        else
            remain = ctx.buffRemainText(st.timeLeft)
            iconState = row.cooldownAura and "cooldown" or "active"
        end
    elseif st.readyAt then
        remain = math.max(0, math.ceil((st.readyAt - api.Time:GetUiMsec()) / 1000))
        iconState = "cooldown"
    end
    return {
        name = name,
        icon = (row.preferMountIcon and ((mount and mount.icon) or ctx.cooldownRowIcon(row) or st.icon)) or (row.gliderPattern and (ctx.cooldownRowIcon(row) or st.icon or (ctx.trackedGliderMatches(row, glider) and glider and glider.icon))) or (st.icon or ctx.cooldownRowIcon(row) or ctx.buffIconById(row.id)),
        state = iconState,
        remain = remain
    }
end

local function trackedSkillEntry(ctx, row, now)
    local key = ctx.trackedSkillCooldownKey(row)
    local cooldowns = ctx.skillCooldowns
    local cd = key ~= "" and cooldowns[key] or nil
    if cd and cd.readyAt and cd.readyAt > now then
        return {
            name = cd.name or row.name or row.id,
            icon = cd.icon or row.icon or ctx.skillIconById(row.id or row.skillId),
            state = "cooldown",
            remain = math.max(0, math.ceil((cd.readyAt - now) / 1000))
        }
    end
    if cd then cooldowns[key] = nil end
    return {
        name = row.name or row.pattern or row.id,
        icon = row.icon or ctx.skillIconById(row.id or row.skillId),
        state = "ready",
        remain = nil
    }
end

local function updateEquipmentIcons(ctx)
    local wnd = ctx.selfWnd
    if not wnd or not wnd.equipIcons then return end
    if ctx.settings.showSelfEquipment == false then
        setEquipmentVisible(wnd, false)
        return
    end
    setEquipmentVisible(wnd, true)
    local now = api.Time:GetUiMsec()
    if wnd._equipReady and now - ctx.lastEquipmentUpdate() < 1000 then return end
    ctx.setLastEquipmentUpdate(now)
    wnd._equipReady = true
    local weapon = ctx.equippedSnapshot(ctx.mainhandSlot()) or {}
    local offhand = ctx.equippedSnapshot(ctx.offhandSlot()) or {}
    local glider = ctx.equippedSnapshot(ctx.gliderSlot()) or {}
    ctx.setEquipIcon(wnd.equipIcons[1], weapon.icon)
    ctx.setEquipIcon(wnd.equipIcons[2], offhand.icon)
    ctx.setEquipIcon(wnd.equipIcons[3], glider.icon)
end

function SelfCooldowns.Update(ctx)
    local wnd = ctx.selfWnd
    if not wnd then return end
    local settings = ctx.settings
    if settings.showSelfPanel == false or ctx.shouldHideSelfPanel() then
        wnd:Show(false)
        return
    end
    if settings.showSelfCooldowns == false then
        if wnd.status then wnd.status:SetText("OFF") end
        clearRow(wnd.gliderIcons, wnd.gliderLabels)
        clearRow(wnd.mountIcons, wnd.mountLabels)
        resizePanel(ctx, 0, 0, false, settings.showSelfEquipment ~= false)
        updateEquipmentIcons(ctx)
        wnd:Show(true)
        return
    end

    local now = api.Time:GetUiMsec()
    if wnd.status then wnd.status:SetText(settings.skillProbeLogging and "LOG" or "") end
    updateEquipmentIcons(ctx)
    local glider = ctx.equippedGliderSnapshot()
    local mount = ctx.mountedPetSnapshot()
    local gliderEntries = {}
    local mountEntries = {}
    for _, row in ipairs(ctx.allTrackedBuffRows()) do
        if row.enabled ~= false then
            local key = ctx.trackedBuffKey(row)
            local st = ctx.buffState[key] or {}
            local visibleForGlider = row.gliderPattern or row.category == "glider" or ctx.trackedGliderMatches(row, glider) or st.active or st.readyAt
            if visibleForGlider then
                local entry = trackedBuffEntry(ctx, row, st, glider, mount)
                if row.gliderPattern or row.category == "glider" then
                    table.insert(gliderEntries, entry)
                else
                    table.insert(mountEntries, entry)
                end
            end
        end
    end
    for _, row in ipairs(ctx.allTrackedSkillRows()) do
        if row.enabled ~= false then
            table.insert(mountEntries, trackedSkillEntry(ctx, row, now))
        end
    end
    ensureRow(ctx, wnd.gliderIcons, wnd.gliderLabels, "power_ranger_self_glider_cd_dynamic", ctx.panel.gliderY, #gliderEntries)
    ensureRow(ctx, wnd.mountIcons, wnd.mountLabels, "power_ranger_self_mount_cd_dynamic", ctx.panel.mountY, #mountEntries)
    resizePanel(ctx, #gliderEntries, #mountEntries, true, settings.showSelfEquipment ~= false)
    renderRow(ctx, wnd.gliderIcons, wnd.gliderLabels, gliderEntries)
    renderRow(ctx, wnd.mountIcons, wnd.mountLabels, mountEntries)
    wnd:Show(true)
end

return SelfCooldowns
