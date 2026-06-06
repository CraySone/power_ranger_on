local api = require("api")
local UiHelpers = require("power_ranger_on/ui_helpers")

local TravelSpeed = {
    settings = nil,
    save = nil,
    applyDrag = nil,
    window = nil,
    elapsed = 0,
    clock = 0,
    lastPosition = nil,
    lastSampleTime = nil,
    samples = {},
    smoothedSpeed = 0
}

local UPDATE_MS = 120
local SAMPLE_WINDOW_MS = 900
local MAX_SAMPLE_MS = 450
local MAX_SAMPLE_DISTANCE = 12
local MIN_SPEED = 0.05

local function safeCall(fn)
    local ok, a, b, c = pcall(fn)
    if ok then return a, b, c end
    return nil
end

local function getPosition()
    local x, y, z = safeCall(function() return api.Unit:UnitWorldPosition("player") end)
    if tonumber(x) == nil then return nil, nil end
    return tonumber(x), tonumber(y) or tonumber(z)
end

local function getVehicleSpeed()
    if not api.SiegeWeapon or not api.SiegeWeapon.GetSiegeWeaponSpeed then return 0 end
    return math.abs(tonumber(safeCall(function() return api.SiegeWeapon:GetSiegeWeaponSpeed() end)) or 0)
end

local function hasSummonedVehicle()
    local bound = safeCall(function()
        return X2Player ~= nil
            and X2Player.IsBoundSlave ~= nil
            and X2Player:IsBoundSlave() == true
    end)
    if bound == true then return true end

    local id = safeCall(function() return api.Unit:GetUnitId("slave") end)
    return id ~= nil and tostring(id) ~= "" and tostring(id) ~= "0"
end

local function resetSamples()
    TravelSpeed.lastPosition = nil
    TravelSpeed.lastSampleTime = nil
    TravelSpeed.samples = {}
    TravelSpeed.smoothedSpeed = 0
end

local function sampleMovement(delta)
    TravelSpeed.clock = TravelSpeed.clock + delta
    local x, z = getPosition()
    if x == nil or z == nil then
        resetSamples()
        return
    end

    local previous = TravelSpeed.lastPosition
    local previousTime = TravelSpeed.lastSampleTime
    if previous and previousTime and TravelSpeed.clock > previousTime then
        local deltaMs = TravelSpeed.clock - previousTime
        local dx, dz = x - previous.x, z - previous.z
        local distance = math.sqrt((dx * dx) + (dz * dz))
        if deltaMs > MAX_SAMPLE_MS or distance > MAX_SAMPLE_DISTANCE then
            TravelSpeed.samples = {}
        elseif deltaMs >= 80 then
            table.insert(TravelSpeed.samples, {
                distance = distance,
                duration = deltaMs,
                time = TravelSpeed.clock
            })
        end
    end

    TravelSpeed.lastPosition = {x = x, z = z}
    TravelSpeed.lastSampleTime = TravelSpeed.clock

    local distance, duration = 0, 0
    local kept = {}
    for _, sample in ipairs(TravelSpeed.samples) do
        if TravelSpeed.clock - sample.time <= SAMPLE_WINDOW_MS then
            table.insert(kept, sample)
            distance = distance + sample.distance
            duration = duration + sample.duration
        end
    end
    TravelSpeed.samples = kept
    local measured = duration > 0 and distance / (duration / 1000) or 0
    local alpha = measured >= TravelSpeed.smoothedSpeed and 0.28 or 0.4
    TravelSpeed.smoothedSpeed = TravelSpeed.smoothedSpeed + ((measured - TravelSpeed.smoothedSpeed) * alpha)
    if measured <= MIN_SPEED and TravelSpeed.smoothedSpeed <= MIN_SPEED then
        TravelSpeed.smoothedSpeed = 0
    end
end

local function createWindow()
    local settings = TravelSpeed.settings
    local window = api.Interface:CreateEmptyWindow("PowerRangerTravelSpeed", "UIParent")
    window:SetExtent(178, 42)
    window:AddAnchor("TOPLEFT", "UIParent", settings.speedMeterX or 300, settings.speedMeterY or 180)
    window.bg = UiHelpers.AddBg(window, 0.025, 0.03, 0.04, 0.76)
    window.accent = window:CreateColorDrawable(1, 0.84, 0, 0.86, "background")
    window.accent:SetExtent(3, 42)
    window.accent:AddAnchor("TOPLEFT", window, 0, 0)
    window.accent:Show(true)
    window.value = UiHelpers.Label(window, "power_ranger_speed_value", "0.0 m/s", 10, 4, 110, 21, 18, {1, 1, 1, 1}, ALIGN.LEFT)
    window.source = UiHelpers.Label(window, "power_ranger_speed_source", "IDLE", 120, 8, 48, 14, 10, {0.64, 0.66, 0.70, 1}, ALIGN.RIGHT)
    window.barBg = window:CreateColorDrawable(0.08, 0.09, 0.11, 0.96, "background")
    window.barBg:SetExtent(158, 6)
    window.barBg:AddAnchor("TOPLEFT", window, 10, 30)
    window.barBg:Show(true)
    window.bar = window:CreateColorDrawable(1, 0.84, 0, 0.9, "overlay")
    window.bar:SetExtent(1, 6)
    window.bar:AddAnchor("TOPLEFT", window, 10, 30)
    window.bar:Show(false)
    window.dragHandle = window:CreateChildWidget("emptywidget", "power_ranger_speed_drag", 0, true)
    window.dragHandle:SetExtent(178, 42)
    window.dragHandle:AddAnchor("TOPLEFT", window, 0, 0)
    TravelSpeed.applyDrag(window, window.dragHandle, "speedMeterX", "speedMeterY")
    TravelSpeed.window = window
end

local function render()
    local settings = TravelSpeed.settings
    if settings.showSpeedMeter ~= true or not hasSummonedVehicle() then
        if TravelSpeed.window then TravelSpeed.window:Show(false) end
        resetSamples()
        return
    end
    if not TravelSpeed.window then createWindow() end
    local opacity = math.max(0, math.min(10, tonumber(settings.speedMeterOpacityLevel) or 8)) / 10
    if TravelSpeed.window.bg then
        TravelSpeed.window.bg:SetColor(0.025, 0.03, 0.04, opacity)
        TravelSpeed.window.bg:Show(opacity > 0)
    end
    if TravelSpeed.window.accent then
        TravelSpeed.window.accent:SetColor(1, 0.84, 0, math.max(0.22, opacity))
    end

    local vehicleSpeed = getVehicleSpeed()
    local speed = vehicleSpeed > MIN_SPEED and vehicleSpeed or TravelSpeed.smoothedSpeed
    local source = vehicleSpeed > MIN_SPEED and "VEHICLE" or (speed > MIN_SPEED and "TRAVEL" or "IDLE")
    TravelSpeed.window.value:SetText(string.format("%.1f m/s", speed))
    TravelSpeed.window.source:SetText(source)
    local width = math.floor(math.min(1, speed / 20) * 158 + 0.5)
    TravelSpeed.window.bar:SetExtent(math.max(1, width), 6)
    TravelSpeed.window.bar:Show(width > 0)
    TravelSpeed.window:Show(true)
end

function TravelSpeed.Init(settings, save, applyDrag)
    TravelSpeed.settings = settings
    TravelSpeed.save = save
    TravelSpeed.applyDrag = applyDrag
    resetSamples()
    render()
end

function TravelSpeed.Update(dt)
    if not TravelSpeed.settings
        or TravelSpeed.settings.showSpeedMeter ~= true
        or not hasSummonedVehicle() then
        if TravelSpeed.window then TravelSpeed.window:Show(false) end
        resetSamples()
        return
    end
    TravelSpeed.elapsed = TravelSpeed.elapsed + (tonumber(dt) or 0)
    if TravelSpeed.elapsed < UPDATE_MS then return end
    local elapsed = TravelSpeed.elapsed
    TravelSpeed.elapsed = 0
    sampleMovement(elapsed)
    render()
end

function TravelSpeed.Refresh()
    render()
end

function TravelSpeed.Cleanup()
    if TravelSpeed.window then TravelSpeed.window:Show(false) end
    TravelSpeed.window = nil
    TravelSpeed.settings = nil
    TravelSpeed.save = nil
    TravelSpeed.applyDrag = nil
    resetSamples()
end

return TravelSpeed
