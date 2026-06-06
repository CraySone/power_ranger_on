local api = require("api")
local UiHelpers = require("power_ranger_on/ui_helpers")
local ResourceLookup = require("power_ranger_on/resource_lookup")

local OwnersMark = {
    settings = nil,
    applyDrag = nil,
    window = nil,
    alert = nil,
    elapsed = 0,
    ownExpiration = nil,
    targetMark = nil,
    lastVehicleId = nil,
    hadVehicle = false,
    wasBound = false,
    warnedVehicleKey = nil,
    popupUntil = nil
}

local BUFF_ID = 4867
local ICON_FALLBACK_PATH = "Game\\ui\\icon\\icon_skill_will19.dds"
local UPDATE_MS = 50
local DISPLAY_LATENCY_MS = 750
local POPUP_MS = 1800
local POPUP_W = 130
local POPUP_H = 18
local cachedMarkIconPath = nil

local function safeCall(fn)
    local ok, a, b, c = pcall(fn)
    if ok then return a, b, c end
    return nil
end

local function unitId(token)
    local id = safeCall(function() return api.Unit:GetUnitId(token) end)
    if id == nil or tostring(id) == "" or tostring(id) == "0" then return nil end
    return id
end

local function unitInfo(token)
    local id = unitId(token)
    if not id then return nil end
    return safeCall(function() return api.Unit:GetUnitInfoById(id) end)
        or safeCall(function() return api.Unit:UnitInfo(token) end)
end

local function isOwnTarget()
    local targetInfo = unitInfo("target")
    local playerInfo = unitInfo("player")
    if not targetInfo or not playerInfo then return false end
    local owner = tostring(targetInfo.owner_name or targetInfo.ownerName or targetInfo.owner or "")
    local player = tostring(playerInfo.name or playerInfo.unitName or "")
    return owner ~= "" and player ~= "" and owner == player
end

local function buffPath(buff)
    if type(buff) ~= "table" then return nil end
    local path = buff.path or buff.icon or buff.iconPath or buff.icon_path
        or buff.iconTexture or buff.icon_texture or buff.texture or buff.dds
    if path and tostring(path) ~= "" then return tostring(path) end
    return nil
end

local function iconPath()
    if cachedMarkIconPath ~= nil then return cachedMarkIconPath or nil end
    local path = ResourceLookup.BuffIconById(BUFF_ID)
        or ICON_FALLBACK_PATH
    cachedMarkIconPath = path or false
    return path
end

local function findMark(token)
    local count = tonumber(safeCall(function() return api.Unit:UnitBuffCount(token) end)) or 0
    for i = 1, count do
        local buff = safeCall(function() return api.Unit:UnitBuff(token, i) end)
        if buff and tonumber(buff.buff_id or buff.buffId) == BUFF_ID then
            return {
                timeLeft = math.max(0, tonumber(buff.timeLeft or buff.time_left) or 0),
                path = buffPath(buff) or iconPath()
            }
        end
    end
    return nil
end

local function isBoundSlave()
    return safeCall(function()
        return X2Player ~= nil and X2Player.IsBoundSlave ~= nil and X2Player:IsBoundSlave() == true
    end) == true
end

local function vehicleContextKey()
    if isBoundSlave() then
        return "bound:" .. tostring(unitId("slave") or "vehicle"), true
    end

    local slaveId = unitId("slave")
    if slaveId then return "slave:" .. tostring(slaveId), true end

    return nil, false
end

local function createWindow()
    local settings = OwnersMark.settings
    local window = api.Interface:CreateEmptyWindow("PowerRangerOwnersMark", "UIParent")
    window:SetExtent(112, 38)
    window:AddAnchor("TOPLEFT", "UIParent", settings.ownersMarkX or 500, settings.ownersMarkY or 180)
    window.bg = UiHelpers.AddBg(window, 0.025, 0.03, 0.04, 0.78)
    window.icon = CreateItemIconButton("power_ranger_owners_mark_icon", window)
    window.icon:SetExtent(32, 32)
    window.icon:AddAnchor("TOPLEFT", window, 3, 3)
    window.icon:Clickable(false)
    F_SLOT.ApplySlotSkin(window.icon, window.icon.back, SLOT_STYLE.DEFAULT)
    local path = iconPath()
    if path then F_SLOT.SetIconBackGround(window.icon, path) end
    window.label = UiHelpers.Label(window, "power_ranger_owners_mark_label", "Owner's Mark", 40, 3, 68, 14, 10, {0.62, 0.82, 1, 1}, ALIGN.LEFT)
    window.time = UiHelpers.Label(window, "power_ranger_owners_mark_time", "", 40, 17, 68, 17, 14, {1, 1, 1, 1}, ALIGN.LEFT)
    window.dragHandle = window:CreateChildWidget("emptywidget", "power_ranger_owners_mark_drag", 0, true)
    window.dragHandle:SetExtent(112, 38)
    window.dragHandle:AddAnchor("TOPLEFT", window, 0, 0)
    OwnersMark.applyDrag(window, window.dragHandle, "ownersMarkX", "ownersMarkY")
    OwnersMark.window = window
end

local function createAlert()
    local alert = api.Interface:CreateEmptyWindow("PowerRangerNoOwnersMarkAlert", "UIParent")
    alert:SetExtent(POPUP_W, POPUP_H)
    if alert.Clickable then alert:Clickable(false) end
    alert.label = UiHelpers.Label(alert, "power_ranger_no_owners_mark_label", "No Owners Mark", 0, 0, POPUP_W, POPUP_H, 13, {1, 0.18, 0.14, 1}, ALIGN.CENTER)
    if alert.label.style.SetShadow then alert.label.style:SetShadow(true) end
    alert:Show(false)
    OwnersMark.alert = alert
end

local function showPopup(now)
    if not OwnersMark.alert then createAlert() end
    OwnersMark.popupUntil = now + POPUP_MS
    OwnersMark.popupStartedAt = now
    OwnersMark.popupLastY = nil
    OwnersMark.alert.label:SetText("No Owners Mark")
    if OwnersMark.alert.label.style and OwnersMark.alert.label.style.SetColor then
        OwnersMark.alert.label.style:SetColor(1, 0.18, 0.14, 1)
    end
    OwnersMark.alert:Show(true)
end

local function updatePopup(now)
    local alert = OwnersMark.alert
    if not alert then return end
    if not OwnersMark.popupUntil or OwnersMark.popupUntil <= now then
        alert:Show(false)
        return
    end
    local progress = 0
    if OwnersMark.popupStartedAt and OwnersMark.popupUntil > OwnersMark.popupStartedAt then
        progress = math.max(0, math.min(1, (now - OwnersMark.popupStartedAt) / (OwnersMark.popupUntil - OwnersMark.popupStartedAt)))
    end
    local eased = 1 - ((1 - progress) * (1 - progress) * (1 - progress))
    local fadeStart = 0.58
    local alpha = 1
    if progress > fadeStart then
        alpha = math.max(0, 1 - ((progress - fadeStart) / (1 - fadeStart)))
    end
    if alert.label and alert.label.style and alert.label.style.SetColor then
        alert.label.style:SetColor(1, 0.18, 0.14, alpha)
    end
    local rise = 8 + (eased * 34)
    local x, y, z = safeCall(function() return api.Unit:GetUnitScreenPosition("player") end)
    if tonumber(x) and tonumber(y) and tonumber(z) and tonumber(z) >= 0 then
        local targetY = tonumber(y) - 42 - rise
        local lastY = tonumber(OwnersMark.popupLastY)
        if lastY then targetY = lastY + ((targetY - lastY) * 0.35) end
        OwnersMark.popupLastY = targetY
        alert:RemoveAllAnchors()
        alert:AddAnchor("BOTTOM", "UIParent", "TOPLEFT", tonumber(x), math.floor(targetY + 0.5))
    else
        alert:RemoveAllAnchors()
        alert:AddAnchor("CENTER", "UIParent", "CENTER", 0, math.floor(-86 - rise + 0.5))
    end
    alert:Show(true)
end

local function warnMissing()
    local text = "[Power Ranger ON] Warning: vehicle dismissed without an active Owner's Mark."
    showPopup(tonumber(safeCall(function() return api.Time:GetUiMsec() end)) or 0)
    if api.Log and api.Log.Warning then
        local ok = pcall(function() api.Log:Warning(text) end)
        if ok then return end
    end
    if api.Log and api.Log.Info then pcall(function() api.Log:Info(text) end) end
end

local function refreshOwnMark(now)
    local found = nil
    for _, token in ipairs({"slave", "playerpet", "playerpet1", "playerpet2"}) do
        found = findMark(token)
        if found then break end
    end
    -- Some vehicles expose their Owner's Mark buff only through the target token.
    -- This feeds the personal timer only; warning state never depends on targeting.
    if not found and isOwnTarget() then found = findMark("target") end
    if found then OwnersMark.ownExpiration = now + found.timeLeft end

    local vehicleKey, hasVehicle = vehicleContextKey()
    local bound = isBoundSlave()
    if hasVehicle and OwnersMark.lastVehicleId ~= vehicleKey then
        OwnersMark.warnedVehicleKey = nil
    end
    if OwnersMark.wasBound and not bound
        and OwnersMark.settings.showOwnOwnersMark == true
        and OwnersMark.settings.warnMissingOwnersMark == true
        and (not OwnersMark.ownExpiration or OwnersMark.ownExpiration <= now) then
        OwnersMark.warnedVehicleKey = vehicleKey or OwnersMark.lastVehicleId or "released"
        warnMissing()
    end
    if OwnersMark.hadVehicle and not hasVehicle
        and OwnersMark.settings.showOwnOwnersMark == true
        and OwnersMark.settings.warnMissingOwnersMark == true
        and OwnersMark.warnedVehicleKey ~= (vehicleKey or OwnersMark.lastVehicleId or "released")
        and (not OwnersMark.ownExpiration or OwnersMark.ownExpiration <= now) then
        OwnersMark.warnedVehicleKey = vehicleKey or OwnersMark.lastVehicleId or "released"
        warnMissing()
    end
    OwnersMark.hadVehicle = hasVehicle
    OwnersMark.wasBound = bound
    OwnersMark.lastVehicleId = vehicleKey

    if OwnersMark.settings.showOwnOwnersMark ~= true then
        if OwnersMark.window then OwnersMark.window:Show(false) end
        return
    end
    local remaining = OwnersMark.ownExpiration and OwnersMark.ownExpiration - now or 0
    if remaining <= 0 then
        OwnersMark.ownExpiration = nil
        if OwnersMark.window then OwnersMark.window:Show(false) end
        return
    end
    if not OwnersMark.window then createWindow() end
    OwnersMark.window.time:SetText(string.format("%.0fs", math.max(0, remaining - DISPLAY_LATENCY_MS) / 1000))
    OwnersMark.window:Show(true)
end

local function refreshTargetMark()
    if OwnersMark.settings.showTargetOwnersMark ~= true then
        OwnersMark.targetMark = nil
        return
    end
    local mark = findMark("target")
    if mark then
        mark.path = mark.path or iconPath()
        OwnersMark.targetMark = mark
    else
        OwnersMark.targetMark = nil
    end
end

function OwnersMark.Init(settings, applyDrag)
    OwnersMark.settings = settings
    OwnersMark.applyDrag = applyDrag
    OwnersMark.elapsed = UPDATE_MS
    OwnersMark.hadVehicle = unitId("slave") ~= nil
    OwnersMark.wasBound = isBoundSlave()
end

function OwnersMark.Update(dt)
    if not OwnersMark.settings then return end
    local now = tonumber(safeCall(function() return api.Time:GetUiMsec() end)) or 0
    updatePopup(now)
    OwnersMark.elapsed = OwnersMark.elapsed + (tonumber(dt) or 0)
    if OwnersMark.elapsed < UPDATE_MS then return end
    OwnersMark.elapsed = 0
    refreshOwnMark(now)
    refreshTargetMark()
end

function OwnersMark.GetTargetMark()
    return OwnersMark.targetMark
end

function OwnersMark.Refresh()
    if OwnersMark.settings and OwnersMark.settings.showOwnOwnersMark ~= true and OwnersMark.window then
        OwnersMark.window:Show(false)
    end
    if OwnersMark.settings and OwnersMark.settings.showTargetOwnersMark ~= true then
        OwnersMark.targetMark = nil
    end
end

function OwnersMark.Cleanup()
    if OwnersMark.window then OwnersMark.window:Show(false) end
    if OwnersMark.alert then OwnersMark.alert:Show(false) end
    OwnersMark.window = nil
    OwnersMark.alert = nil
    OwnersMark.settings = nil
    OwnersMark.applyDrag = nil
    OwnersMark.ownExpiration = nil
    OwnersMark.targetMark = nil
    OwnersMark.lastVehicleId = nil
    OwnersMark.hadVehicle = false
    OwnersMark.wasBound = false
    OwnersMark.warnedVehicleKey = nil
    OwnersMark.popupUntil = nil
    OwnersMark.popupStartedAt = nil
    OwnersMark.popupLastY = nil
end

return OwnersMark
