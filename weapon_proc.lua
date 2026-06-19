-- Hidden weapon proc tracker (ported from the standalone Weapon_Proc addon).
-- Detects the hidden mainhand procs by watching player stat jumps in
-- api.Unit:UnitModifierInfo("player"):
--   Nodachi/Katana  melee_critical_mul  +900   (100% crit on next hit)
--   Long/Shortspear ignore_armor        +8000  (armor penetration)
--   Staff           magic_penetration   +8000  (magic penetration)
-- Shows a small styled status bar (READY / armed proc / cooldown), optionally a
-- green "Proc Ready" popup above the player's head (same rise/fade treatment as
-- the No Owners Mark alert), and an optional Zeal indicator (buff 495) tucked
-- into the title row so it needs no extra window space.

local api = require("api")
local UiHelpers = require("power_ranger_on/ui_helpers")

local WeaponProc = {
    settings = nil,
    applyDrag = nil,
    window = nil,
    alert = nil,
    elapsed = 0,
    scanElapsed = 0,
    weaponKind = nil,
    weaponCooldownMs = 0,
    lastModifierInfo = nil,
    activeProc = nil,
    cooldownUntil = 0,
    wasReady = true,
    zealOn = false,
    zealTimeLeft = 0,
    popupUntil = nil,
    popupStartedAt = nil,
    popupLastY = nil
}

local UPDATE_MS = 100
local WEAPON_SCAN_MS = 2000
local POPUP_MS = 1600
local POPUP_W = 130
local POPUP_H = 18
local BASE_W = 150
local BASE_H = 36
-- Zeal is player buff 495 (same id the Zeal Combat Text addon + CombatLogPro use). The old
-- 494 entry matched a different buff and made the indicator flicker/behave oddly -- removed.
local ZEAL_BUFF_IDS = { [495] = true }

local COLOR_READY = {0.38, 0.95, 0.44, 1}
local COLOR_ARMED = {0.45, 0.72, 1, 1}
local COLOR_COOLDOWN = {1, 0.35, 0.32, 1}
-- Matches the Zeal Combat Text addon's zeal-damage colour (light purple).
local COLOR_ZEAL = {0.93, 0.4, 0.75, 1}
local COLOR_ZEAL_OFF = {0.4, 0.4, 0.46, 1}

local PROCS = {
    { name = "crit", statName = "melee_critical_mul", threshold = 900, displayName = "100% CRIT" },
    { name = "armorPen", statName = "ignore_armor", threshold = 8000, displayName = "ARMOR PEN" },
    { name = "magicPen", statName = "magic_penetration", threshold = 8000, displayName = "MAGIC PEN" }
}

local function safeCall(fn)
    local ok, a, b, c = pcall(fn)
    if ok then return a, b, c end
    return nil
end

local function now()
    return tonumber(safeCall(function() return api.Time:GetUiMsec() end)) or 0
end

local function enabled()
    return WeaponProc.settings ~= nil and WeaponProc.settings.weaponProcEnabled == true
end

local function zealEnabled()
    return WeaponProc.settings ~= nil and WeaponProc.settings.weaponProcZeal == true
end

local function scaleLevel()
    local level = tonumber(WeaponProc.settings and WeaponProc.settings.weaponProcScaleLevel) or 0
    if level < 0 then return 0 end
    if level > 6 then return 6 end
    return level
end

-- Scale a base pixel value by the current level (0 = 1.0x ... 6 = ~1.9x).
local function S(value)
    return math.max(1, math.floor((tonumber(value) or 0) * (1 + (scaleLevel() * 0.15)) + 0.5))
end

-- Mainhand category decides whether a proc weapon is equipped and which
-- cooldown applies (the proc itself is still detected through the stat jump).
local function scanWeapon()
    local tooltip = safeCall(function() return api.Equipment:GetEquippedItemTooltipText("player", EQUIP_SLOT.MAINHAND) end)
    local category = type(tooltip) == "table" and string.lower(tostring(tooltip.category or "")) or ""
    if category == "" then return nil, 0, category end
    if category:find("katana", 1, true) then return "katana", 45000, category end
    if category:find("nodachi", 1, true) then return "nodachi", 30000, category end
    if category:find("shortspear", 1, true) then return "shortspear", 30000, category end
    if category:find("spear", 1, true) then return "longspear", 10000, category end
    if category:find("staff", 1, true) then return "staff", 20000, category end
    return nil, 0, category
end

local function logWeaponScan(kind, category)
    if WeaponProc.settings.debugLogging ~= true then return end
    pcall(function()
        api.Log:Info(string.format("[Weapon Proc] mainhand category '%s' -> %s", tostring(category), kind or "no proc weapon"))
    end)
end

-- Zeal is a player buff (id 495) granting bonus crit damage; same detection
-- CombatLogPro / Zeal Combat Text use. Scanned on the throttled tick, not every frame.
-- Returns isActive, remainingMs for the Zeal buff (494/495).
local function scanZeal()
    local count = tonumber(safeCall(function() return api.Unit:UnitBuffCount("player") end)) or 0
    for i = 1, count do
        local buff = safeCall(function() return api.Unit:UnitBuff("player", i) end)
        if type(buff) == "table" and ZEAL_BUFF_IDS[tonumber(buff.buff_id or buff.buffId)] then
            return true, tonumber(buff.timeLeft or buff.time_left) or 0
        end
    end
    return false, 0
end

local function procConsumed(currentTime)
    WeaponProc.activeProc = nil
    WeaponProc.cooldownUntil = currentTime + (WeaponProc.weaponCooldownMs > 0 and WeaponProc.weaponCooldownMs or 10000)
end

local function detectStatChanges(currentTime)
    local modInfo = safeCall(function() return api.Unit:UnitModifierInfo("player") end)
    if type(modInfo) ~= "table" then return end
    local last = WeaponProc.lastModifierInfo
    if last then
        for _, def in ipairs(PROCS) do
            local current = tonumber(modInfo[def.statName])
            local previous = tonumber(last[def.statName])
            if current and previous then
                local diff = current - previous
                if diff >= def.threshold and not WeaponProc.activeProc then
                    WeaponProc.activeProc = { statName = def.statName, displayName = def.displayName }
                elseif diff < -50 and WeaponProc.activeProc and WeaponProc.activeProc.statName == def.statName then
                    procConsumed(currentTime)
                end
            end
        end
    end
    WeaponProc.lastModifierInfo = modInfo
end

-- Over-the-character popup size is independent of the bar scale (own 0..6 setting).
local function popupScaleLevel()
    return math.max(0, math.min(6, tonumber(WeaponProc.settings and WeaponProc.settings.weaponProcPopupScale) or 0))
end

local function createAlert()
    local mul = 1 + (popupScaleLevel() * 0.3)
    local pw, ph = math.floor((POPUP_W * mul) + 0.5), math.floor((POPUP_H * mul) + 0.5)
    local font = math.max(8, math.floor((13 * mul) + 0.5))
    local alert = api.Interface:CreateEmptyWindow("PowerRangerWeaponProcReady", "UIParent")
    alert:SetExtent(pw, ph)
    if alert.Clickable then alert:Clickable(false) end
    alert.label = UiHelpers.Label(alert, "power_ranger_weapon_proc_ready_label", "Proc Ready", 0, 0, pw, ph, font, COLOR_READY, ALIGN.CENTER)
    if alert.label.style.SetShadow then alert.label.style:SetShadow(true) end
    alert:Show(false)
    alert.builtPopupScale = popupScaleLevel()
    WeaponProc.alert = alert
end

-- text/color let the same popup serve both "Proc Ready" and "Zeal Ready".
local function showPopup(currentTime, text, color)
    if not WeaponProc.alert or WeaponProc.alert.builtPopupScale ~= popupScaleLevel() then
        if WeaponProc.alert then
            pcall(function() WeaponProc.alert:Show(false) end)
            pcall(function() api.Interface:Free(WeaponProc.alert) end)
            WeaponProc.alert = nil
        end
        createAlert()
    end
    WeaponProc.popupUntil = currentTime + POPUP_MS
    WeaponProc.popupStartedAt = currentTime
    WeaponProc.popupLastY = nil
    WeaponProc.popupColor = color or COLOR_READY
    WeaponProc.alert.label:SetText(text or "Proc Ready")
    local c = WeaponProc.popupColor
    if WeaponProc.alert.label.style and WeaponProc.alert.label.style.SetColor then
        WeaponProc.alert.label.style:SetColor(c[1], c[2], c[3], 1)
    end
    WeaponProc.alert:Show(true)
end

local function updatePopup(currentTime)
    local alert = WeaponProc.alert
    if not alert then return end
    if not WeaponProc.popupUntil or WeaponProc.popupUntil <= currentTime then
        alert:Show(false)
        return
    end
    local progress = 0
    if WeaponProc.popupStartedAt and WeaponProc.popupUntil > WeaponProc.popupStartedAt then
        progress = math.max(0, math.min(1, (currentTime - WeaponProc.popupStartedAt) / (WeaponProc.popupUntil - WeaponProc.popupStartedAt)))
    end
    local eased = 1 - ((1 - progress) * (1 - progress) * (1 - progress))
    local fadeStart = 0.58
    local alpha = 1
    if progress > fadeStart then
        alpha = math.max(0, 1 - ((progress - fadeStart) / (1 - fadeStart)))
    end
    local c = WeaponProc.popupColor or COLOR_READY
    if alert.label and alert.label.style and alert.label.style.SetColor then
        alert.label.style:SetColor(c[1], c[2], c[3], alpha)
    end
    local rise = 8 + (eased * 34)
    local x, y, z = safeCall(function() return api.Unit:GetUnitScreenPosition("player") end)
    if tonumber(x) and tonumber(y) and tonumber(z) and tonumber(z) >= 0 then
        local targetY = tonumber(y) - 42 - rise
        local lastY = tonumber(WeaponProc.popupLastY)
        if lastY then targetY = lastY + ((targetY - lastY) * 0.35) end
        WeaponProc.popupLastY = targetY
        alert:RemoveAllAnchors()
        alert:AddAnchor("BOTTOM", "UIParent", "TOPLEFT", tonumber(x), math.floor(targetY + 0.5))
    else
        alert:RemoveAllAnchors()
        alert:AddAnchor("CENTER", "UIParent", "CENTER", 0, math.floor(-86 - rise + 0.5))
    end
    alert:Show(true)
end

local function applyOpacity()
    local window = WeaponProc.window
    if not window then return end
    local level = tonumber(WeaponProc.settings and WeaponProc.settings.weaponProcOpacityLevel) or 8
    if level < 0 then level = 0 elseif level > 10 then level = 10 end
    local opacity = level / 10
    window.borderBg:SetColor(0, 0, 0, 0.92 * opacity)
    window.bodyBg:SetColor(0.05, 0.05, 0.06, 0.85 * opacity)
end

local function createWindow()
    local settings = WeaponProc.settings
    local w, h = S(BASE_W), S(BASE_H)
    local window = api.Interface:CreateEmptyWindow("PowerRangerWeaponProc", "UIParent")
    window:SetExtent(w, h)
    window:AddAnchor("TOPLEFT", "UIParent", settings.weaponProcX or 500, settings.weaponProcY or 230)
    window.borderBg = UiHelpers.AddBg(window, 0, 0, 0, 0.92)
    local body = window:CreateColorDrawable(0.05, 0.05, 0.06, 0.85, "background")
    body:AddAnchor("TOPLEFT", window, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", window, -1, -1)
    body:Show(true)
    window.bodyBg = body
    -- Compact window, exactly as before: header row "WEAPON PROC" (left) + "ZEAL" (right),
    -- and one status line below -- proc READY/armed/cooldown on the left, the Zeal status
    -- (same READY / active-timer treatment) on the right.
    window.titleLabel = UiHelpers.Label(window, "power_ranger_weapon_proc_title", "WEAPON PROC", S(8), S(4), S(80), S(12), S(9), {0.64, 0.66, 0.70, 1}, ALIGN.LEFT)
    window.zealHeader = UiHelpers.Label(window, "power_ranger_weapon_proc_zeal_header", "ZEAL", w - S(48), S(4), S(40), S(12), S(9), {0.64, 0.66, 0.70, 1}, ALIGN.RIGHT)
    window.zealHeader:Show(false)
    window.status = UiHelpers.Label(window, "power_ranger_weapon_proc_status", "", S(8), S(16), w - S(16), S(17), S(14), COLOR_READY, ALIGN.LEFT)
    window.zealLabel = UiHelpers.Label(window, "power_ranger_weapon_proc_zeal", "", w - S(54), S(16), S(48), S(17), S(14), COLOR_READY, ALIGN.RIGHT)
    window.zealLabel:Show(false)
    window.dragHandle = window:CreateChildWidget("emptywidget", "power_ranger_weapon_proc_drag", 0, true)
    window.dragHandle:SetExtent(w, h)
    window.dragHandle:AddAnchor("TOPLEFT", window, 0, 0)
    WeaponProc.applyDrag(window, window.dragHandle, "weaponProcX", "weaponProcY")
    window.builtScaleLevel = scaleLevel()
    WeaponProc.window = window
    applyOpacity()
end

-- Free + nil the window so the next show rebuilds it at the current scale.
local function rebuildWindow()
    if WeaponProc.window then
        pcall(function() WeaponProc.window:Show(false) end)
        pcall(function() api.Interface:Free(WeaponProc.window) end)
        WeaponProc.window = nil
    end
end

local function setStatus(text, color)
    if not WeaponProc.window then createWindow() end
    if WeaponProc.window.builtScaleLevel ~= scaleLevel() then
        rebuildWindow()
        createWindow()
    end
    WeaponProc.window.status:SetText(text)
    if WeaponProc.window.status.style and WeaponProc.window.status.style.SetColor then
        WeaponProc.window.status.style:SetColor(color[1], color[2], color[3], 1)
    end
    WeaponProc.window:Show(true)
end

local function updateZealIndicator()
    local window = WeaponProc.window
    if not window or not window.zealLabel then return end
    if not zealEnabled() then
        if window.zealHeader then window.zealHeader:Show(false) end
        window.zealLabel:Show(false)
        if window.status then window.status:SetExtent(S(BASE_W) - S(16), S(17)) end
        return
    end
    -- Zeal on: shrink the proc readout to the left so the Zeal status sits on the right of the
    -- same line, with the same treatment as the proc -- green "READY" when it can proc, or its
    -- remaining timer in the Zeal combat-text colour (magenta) while the buff is active. (Zeal
    -- has no separate cooldown like the weapon proc, so there's no red cooldown state.)
    if window.status then window.status:SetExtent(S(86), S(17)) end
    if window.zealHeader then window.zealHeader:Show(true) end
    local text, color
    if WeaponProc.zealOn then
        text = string.format("%.1fs", math.max(0, (tonumber(WeaponProc.zealTimeLeft) or 0) / 1000))
        color = COLOR_ZEAL
    else
        text = "READY"
        color = COLOR_READY
    end
    window.zealLabel:SetText(text)
    if window.zealLabel.style and window.zealLabel.style.SetColor then
        window.zealLabel.style:SetColor(color[1], color[2], color[3], 1)
    end
    window.zealLabel:Show(true)
end

local function updateBar(currentTime)
    -- Scan Zeal every display tick (not the 2s weapon scan) so its timer counts down smoothly.
    if zealEnabled() then
        local wasZealOn = WeaponProc.zealOn
        WeaponProc.zealOn, WeaponProc.zealTimeLeft = scanZeal()
        -- Zeal just dropped (active -> ready): tick "Zeal Ready" over the character.
        if wasZealOn and not WeaponProc.zealOn and WeaponProc.settings.weaponProcReadyPopup ~= false then
            showPopup(currentTime, "Zeal Ready", COLOR_ZEAL)
        end
    end
    if not WeaponProc.weaponKind then
        -- Zeal-only mode: no proc weapon, but Zeal tracking keeps the window up.
        setStatus("No proc Wep", COLOR_ZEAL_OFF)
        WeaponProc.wasReady = true
        updateZealIndicator()
        return
    end
    if WeaponProc.activeProc then
        setStatus(WeaponProc.activeProc.displayName, COLOR_ARMED)
        WeaponProc.wasReady = false
        updateZealIndicator()
        return
    end
    if currentTime < WeaponProc.cooldownUntil then
        setStatus(string.format("%.1fs", (WeaponProc.cooldownUntil - currentTime) / 1000), COLOR_COOLDOWN)
        WeaponProc.wasReady = false
        updateZealIndicator()
        return
    end
    if not WeaponProc.wasReady then
        WeaponProc.wasReady = true
        if WeaponProc.settings.weaponProcReadyPopup ~= false then
            showPopup(currentTime, "Proc Ready", COLOR_READY)
        end
    end
    setStatus("READY", COLOR_READY)
    updateZealIndicator()
end

local function resetEngine()
    WeaponProc.lastModifierInfo = nil
    WeaponProc.activeProc = nil
    WeaponProc.cooldownUntil = 0
    WeaponProc.wasReady = true
    WeaponProc.zealOn = false
end

function WeaponProc.Init(settings, applyDrag)
    WeaponProc.settings = settings
    WeaponProc.applyDrag = applyDrag
    WeaponProc.elapsed = UPDATE_MS
    WeaponProc.scanElapsed = WEAPON_SCAN_MS
end

function WeaponProc.Update(dt)
    if not WeaponProc.settings then return end
    if not enabled() then
        if WeaponProc.window then WeaponProc.window:Show(false) end
        if WeaponProc.alert then WeaponProc.alert:Show(false) end
        return
    end
    local currentTime = now()
    updatePopup(currentTime)
    WeaponProc.elapsed = WeaponProc.elapsed + (tonumber(dt) or 0)
    WeaponProc.scanElapsed = WeaponProc.scanElapsed + (tonumber(dt) or 0)
    if WeaponProc.scanElapsed >= WEAPON_SCAN_MS then
        WeaponProc.scanElapsed = 0
        local kind, cooldown, category = scanWeapon()
        if kind ~= WeaponProc.weaponKind or not WeaponProc.scannedOnce then
            if kind ~= WeaponProc.weaponKind then resetEngine() end
            WeaponProc.scannedOnce = true
            logWeaponScan(kind, category)
        end
        WeaponProc.weaponKind = kind
        WeaponProc.weaponCooldownMs = cooldown
    end
    -- Hide only when there's nothing to show: no proc weapon AND no Zeal tracking.
    if not WeaponProc.weaponKind and not zealEnabled() then
        if WeaponProc.window then WeaponProc.window:Show(false) end
        return
    end
    -- Detect every frame (like the original Weapon_Proc): a throttled sampler can
    -- miss a proc that triggers and is consumed between two samples, because the
    -- stat diff nets out to zero. Only the bar text is throttled.
    if WeaponProc.weaponKind then detectStatChanges(currentTime) end
    if WeaponProc.elapsed < UPDATE_MS then return end
    WeaponProc.elapsed = 0
    updateBar(currentTime)
end

function WeaponProc.Refresh()
    if not enabled() then
        if WeaponProc.window then WeaponProc.window:Show(false) end
        if WeaponProc.alert then WeaponProc.alert:Show(false) end
        resetEngine()
    else
        -- Rebuild at the new scale if it changed; force an immediate rescan so the
        -- bar reflects the current weapon/zeal without the 2s wait.
        if WeaponProc.window and WeaponProc.window.builtScaleLevel ~= scaleLevel() then
            rebuildWindow()
        end
        WeaponProc.scanElapsed = WEAPON_SCAN_MS
        applyOpacity()
    end
end

function WeaponProc.Cleanup()
    if WeaponProc.window then WeaponProc.window:Show(false) end
    if WeaponProc.alert then WeaponProc.alert:Show(false) end
    WeaponProc.window = nil
    WeaponProc.alert = nil
    WeaponProc.settings = nil
    WeaponProc.applyDrag = nil
    WeaponProc.weaponKind = nil
    WeaponProc.popupUntil = nil
    WeaponProc.popupStartedAt = nil
    WeaponProc.popupLastY = nil
    resetEngine()
end

return WeaponProc
