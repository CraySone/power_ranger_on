local OverlayUtils = require("power_ranger_on/overlay_utils")

local IconWidgets = {}

local function decorateCooldownIcon(icon, parent, id, size)
    if not icon then return end
    local overlay = icon:CreateColorDrawable(0, 0, 0, 0.62, "overlay")
    overlay:AddAnchor("TOPLEFT", icon, 0, 0)
    overlay:AddAnchor("BOTTOMRIGHT", icon, 0, 0)
    overlay:Show(false)
    icon.cooldownOverlay = overlay

    local timer = parent:CreateChildWidget("label", id .. "_timer", 0, true)
    timer:SetExtent(size, size)
    timer:AddAnchor("CENTER", icon, 0, 0)
    timer.style:SetFontSize(10)
    timer.style:SetAlign(ALIGN.CENTER)
    if timer.style.SetShadow then timer.style:SetShadow(false) end
    if timer.style.SetOutline then timer.style:SetOutline(false) end
    timer.style:SetColor(1, 1, 1, 1)
    timer:SetText("")
    timer:Show(false)
    timer:Clickable(false)
    icon.timerLabel = timer
end

function IconWidgets.Create(parent, id, x, y, size, addBg)
    local icon = nil
    if CreateItemIconButton then
        local ok, created = pcall(function() return CreateItemIconButton(id, parent) end)
        if ok then icon = created end
    end
    if icon then
        icon:SetExtent(size, size)
        icon:AddAnchor("TOPLEFT", parent, x, y)
        if icon.Clickable then icon:Clickable(false) end
        if F_SLOT and F_SLOT.ApplySlotSkin and SLOT_STYLE then
            pcall(function() F_SLOT.ApplySlotSkin(icon, icon.back, SLOT_STYLE.DEFAULT) end)
        end
        icon:Show(false)
        decorateCooldownIcon(icon, parent, id, size)
        return icon
    end

    local holder = parent:CreateChildWidget("emptywidget", id, 0, true)
    holder:SetExtent(size, size)
    holder:AddAnchor("TOPLEFT", parent, x, y)
    if addBg then addBg(holder, 0, 0, 0, 0.48) end
    holder:Show(false)
    decorateCooldownIcon(holder, parent, id, size)
    return holder
end

function IconWidgets.Set(icon, path)
    if not icon then return end
    if not path or tostring(path) == "" then
        icon:Show(false)
        return
    end
    local ok = false
    if F_SLOT and F_SLOT.SetIconBackGround then
        ok = pcall(function() F_SLOT.SetIconBackGround(icon, tostring(path)) end)
    end
    if not ok and icon.SetTgaTexture then
        ok = pcall(function() icon:SetTgaTexture(tostring(path)) end)
    end
    icon:Show(ok == true)
end

function IconWidgets.SetCached(icon, path)
    if not icon then return end
    path = path and tostring(path) or nil
    if icon._lastPath == path and icon._lastVisible ~= nil then
        icon:Show(icon._lastVisible)
        return
    end
    icon._lastPath = path
    if path and path ~= "" then
        IconWidgets.Set(icon, path)
        icon._lastVisible = true
    else
        icon:Show(false)
        icon._lastVisible = false
    end
end

function IconWidgets.SetEquip(icon, path)
    if not icon then return end
    path = path and tostring(path) or nil
    if path and path ~= "" then
        IconWidgets.SetCached(icon, path)
        return
    end
    if icon._lastPath ~= "__empty" then
        if F_SLOT and F_SLOT.SetIconBackGround then
            pcall(function() F_SLOT.SetIconBackGround(icon, nil) end)
        end
        if F_SLOT and F_SLOT.ApplySlotSkin and SLOT_STYLE and icon.back then
            pcall(function() F_SLOT.ApplySlotSkin(icon, icon.back, SLOT_STYLE.DEFAULT) end)
        end
        icon._lastPath = "__empty"
    end
    icon._lastVisible = true
    icon:Show(true)
end

function IconWidgets.SetCooldown(icon, path, state, seconds)
    IconWidgets.SetCached(icon, path)
    if not icon then return end
    local active = state == "active" or state == "cooldown"
    if icon.cooldownOverlay then icon.cooldownOverlay:Show(active) end
    if icon.timerLabel then
        if state == "active" then
            icon.timerLabel:SetText(OverlayUtils.cooldownTimerText(seconds) or "ON")
            icon.timerLabel:Show(true)
        elseif state == "cooldown" and seconds then
            icon.timerLabel:SetText(OverlayUtils.cooldownTimerText(seconds) or "")
            icon.timerLabel:Show(true)
        else
            icon.timerLabel:SetText("")
            icon.timerLabel:Show(false)
        end
    end
end

function IconWidgets.SetCooldownSkill(icon, path, state, seconds)
    if path then
        IconWidgets.SetCooldown(icon, path, state, seconds)
        return
    end
    IconWidgets.SetEquip(icon, nil)
    local active = state == "active" or state == "cooldown"
    if icon.cooldownOverlay then icon.cooldownOverlay:Show(active) end
    if icon.timerLabel then
        if state == "cooldown" and seconds then
            icon.timerLabel:SetText(OverlayUtils.cooldownTimerText(seconds) or "")
            icon.timerLabel:Show(true)
        elseif state == "active" then
            icon.timerLabel:SetText(OverlayUtils.cooldownTimerText(seconds) or "ON")
            icon.timerLabel:Show(true)
        else
            icon.timerLabel:SetText("")
            icon.timerLabel:Show(false)
        end
    end
end

return IconWidgets
