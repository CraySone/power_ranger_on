-- Hidden weapon proc tracker (ported from the standalone Weapon_Proc addon).
-- Detects the hidden mainhand procs by watching player stat jumps in
-- api.Unit:UnitModifierInfo("player"):
--   Nodachi/Katana  melee_critical_mul  +900   (100% crit on next hit)
--   Long/Shortspear ignore_armor        +8000  (armor penetration)
--   Staff           magic_penetration   +8000  (magic penetration)
-- Shows a small styled status bar (READY / armed proc / cooldown), optionally a
-- green "Proc Ready" popup above the player's head (same rise/fade treatment as
-- the No Owners Mark alert), and optionally reports the consumed proc hit's
-- damage to chat (fed by the existing COMBAT_MSG pipeline in target_overlay).

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
    playerName = nil,
    lastHit = nil,
    pendingReportUntil = nil,
    pendingReportName = nil,
    popupUntil = nil,
    popupStartedAt = nil,
    popupLastY = nil
}

local UPDATE_MS = 100
local WEAPON_SCAN_MS = 2000
local POPUP_MS = 1600
local POPUP_W = 130
local POPUP_H = 18
local HIT_MATCH_MS = 1500
local BAR_W = 150
local BAR_H = 36

local COLOR_READY = {0.38, 0.95, 0.44, 1}
local COLOR_ARMED = {0.45, 0.72, 1, 1}
local COLOR_COOLDOWN = {1, 0.35, 0.32, 1}

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

local function getPlayerName()
    if WeaponProc.playerName then return WeaponProc.playerName end
    local info = safeCall(function() return api.Unit:UnitInfo("player") end)
    local name = type(info) == "table" and tostring(info.name or "") or ""
    if name ~= "" then WeaponProc.playerName = name end
    return WeaponProc.playerName
end

local function reportHit(displayName, hit)
    pcall(function()
        api.Log:Info(string.format("[Weapon Proc] %s: %s hit %s for %s damage.",
            tostring(displayName), tostring(hit.skill or "Attack"), tostring(hit.target or "target"),
            tostring(math.floor((tonumber(hit.damage) or 0) + 0.5))))
    end)
end

local function procConsumed(currentTime)
    local proc = WeaponProc.activeProc
    WeaponProc.activeProc = nil
    WeaponProc.cooldownUntil = currentTime + (WeaponProc.weaponCooldownMs > 0 and WeaponProc.weaponCooldownMs or 10000)
    if not proc or WeaponProc.settings.weaponProcDamageChat ~= true then return end
    local hit = WeaponProc.lastHit
    if hit and currentTime - hit.time <= HIT_MATCH_MS then
        reportHit(proc.displayName, hit)
    else
        -- Stat drop can land a frame before the COMBAT_MSG; report the next hit.
        WeaponProc.pendingReportUntil = currentTime + HIT_MATCH_MS
        WeaponProc.pendingReportName = proc.displayName
    end
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

local function createAlert()
    local alert = api.Interface:CreateEmptyWindow("PowerRangerWeaponProcReady", "UIParent")
    alert:SetExtent(POPUP_W, POPUP_H)
    if alert.Clickable then alert:Clickable(false) end
    alert.label = UiHelpers.Label(alert, "power_ranger_weapon_proc_ready_label", "Proc Ready", 0, 0, POPUP_W, POPUP_H, 13, COLOR_READY, ALIGN.CENTER)
    if alert.label.style.SetShadow then alert.label.style:SetShadow(true) end
    alert:Show(false)
    WeaponProc.alert = alert
end

local function showPopup(currentTime)
    if not WeaponProc.alert then createAlert() end
    WeaponProc.popupUntil = currentTime + POPUP_MS
    WeaponProc.popupStartedAt = currentTime
    WeaponProc.popupLastY = nil
    WeaponProc.alert.label:SetText("Proc Ready")
    if WeaponProc.alert.label.style and WeaponProc.alert.label.style.SetColor then
        WeaponProc.alert.label.style:SetColor(COLOR_READY[1], COLOR_READY[2], COLOR_READY[3], 1)
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
    if alert.label and alert.label.style and alert.label.style.SetColor then
        alert.label.style:SetColor(COLOR_READY[1], COLOR_READY[2], COLOR_READY[3], alpha)
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

local function createWindow()
    local settings = WeaponProc.settings
    local window = api.Interface:CreateEmptyWindow("PowerRangerWeaponProc", "UIParent")
    window:SetExtent(BAR_W, BAR_H)
    window:AddAnchor("TOPLEFT", "UIParent", settings.weaponProcX or 500, settings.weaponProcY or 230)
    UiHelpers.AddBg(window, 0, 0, 0, 0.92)
    local body = window:CreateColorDrawable(0.05, 0.05, 0.06, 0.85, "background")
    body:AddAnchor("TOPLEFT", window, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", window, -1, -1)
    body:Show(true)
    window.titleLabel = UiHelpers.Label(window, "power_ranger_weapon_proc_title", "WEAPON PROC", 8, 4, BAR_W - 16, 12, 9, {0.64, 0.66, 0.70, 1}, ALIGN.LEFT)
    window.status = UiHelpers.Label(window, "power_ranger_weapon_proc_status", "", 8, 16, BAR_W - 16, 17, 14, COLOR_READY, ALIGN.LEFT)
    window.dragHandle = window:CreateChildWidget("emptywidget", "power_ranger_weapon_proc_drag", 0, true)
    window.dragHandle:SetExtent(BAR_W, BAR_H)
    window.dragHandle:AddAnchor("TOPLEFT", window, 0, 0)
    WeaponProc.applyDrag(window, window.dragHandle, "weaponProcX", "weaponProcY")
    WeaponProc.window = window
end

local function setStatus(text, color)
    if not WeaponProc.window then createWindow() end
    WeaponProc.window.status:SetText(text)
    if WeaponProc.window.status.style and WeaponProc.window.status.style.SetColor then
        WeaponProc.window.status.style:SetColor(color[1], color[2], color[3], 1)
    end
    WeaponProc.window:Show(true)
end

local function updateBar(currentTime)
    if WeaponProc.activeProc then
        setStatus(WeaponProc.activeProc.displayName, COLOR_ARMED)
        WeaponProc.wasReady = false
        return
    end
    if currentTime < WeaponProc.cooldownUntil then
        setStatus(string.format("%.1fs", (WeaponProc.cooldownUntil - currentTime) / 1000), COLOR_COOLDOWN)
        WeaponProc.wasReady = false
        return
    end
    if not WeaponProc.wasReady then
        WeaponProc.wasReady = true
        if WeaponProc.settings.weaponProcReadyPopup ~= false then
            showPopup(currentTime)
        end
    end
    setStatus("READY", COLOR_READY)
end

local function resetEngine()
    WeaponProc.lastModifierInfo = nil
    WeaponProc.activeProc = nil
    WeaponProc.cooldownUntil = 0
    WeaponProc.wasReady = true
    WeaponProc.lastHit = nil
    WeaponProc.pendingReportUntil = nil
    WeaponProc.pendingReportName = nil
end

function WeaponProc.Init(settings, applyDrag)
    WeaponProc.settings = settings
    WeaponProc.applyDrag = applyDrag
    WeaponProc.elapsed = UPDATE_MS
    WeaponProc.scanElapsed = WEAPON_SCAN_MS
end

-- True when the COMBAT_MSG subscription is needed for the damage chat report.
function WeaponProc.NeedsCombatEvents()
    return enabled() and WeaponProc.settings.weaponProcDamageChat == true
end

-- Fed from target_overlay's COMBAT_MSG handler. args are the varargs after
-- (targetUnitId, combatEvent, source, target): args[2] = skill, args[4] = damage.
function WeaponProc.OnCombatMessage(source, target, args)
    if not WeaponProc.NeedsCombatEvents() then return end
    local playerName = getPlayerName()
    if not playerName or tostring(source or "") ~= playerName then return end
    local damage = math.abs(tonumber(args and args[4]) or 0)
    if damage <= 0 then return end
    local currentTime = now()
    local hit = { time = currentTime, damage = damage, skill = tostring(args[2] or "Attack"), target = tostring(target or "") }
    if WeaponProc.pendingReportUntil and currentTime <= WeaponProc.pendingReportUntil then
        local name = WeaponProc.pendingReportName
        WeaponProc.pendingReportUntil = nil
        WeaponProc.pendingReportName = nil
        reportHit(name, hit)
        return
    end
    WeaponProc.lastHit = hit
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
    if not WeaponProc.weaponKind then
        if WeaponProc.window then WeaponProc.window:Show(false) end
        return
    end
    -- Detect every frame (like the original Weapon_Proc): a throttled sampler can
    -- miss a proc that triggers and is consumed between two samples, because the
    -- stat diff nets out to zero. Only the bar text is throttled.
    detectStatChanges(currentTime)
    if WeaponProc.pendingReportUntil and currentTime > WeaponProc.pendingReportUntil then
        WeaponProc.pendingReportUntil = nil
        WeaponProc.pendingReportName = nil
    end
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
        -- Force an immediate weapon rescan so the bar appears without the 2s wait.
        WeaponProc.scanElapsed = WEAPON_SCAN_MS
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
    WeaponProc.playerName = nil
    WeaponProc.popupUntil = nil
    WeaponProc.popupStartedAt = nil
    WeaponProc.popupLastY = nil
    resetEngine()
end

return WeaponProc
