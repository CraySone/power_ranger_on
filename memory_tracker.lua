-- Client memory watch: a live readout plus escalating warnings before the client crashes.
--
-- ArcheAge's client leaks virtual memory during long sessions -- worst in prolonged combat
-- and heavy population events -- and eventually dies. The fix is to relog before it does,
-- which only works if you can see it coming. This is the seeing-it-coming part.
--
-- The idea and the thresholds come from Mike's CrashAge; the sampling and warning logic here
-- are a reimplementation in this addon's style rather than a port of his code.
--
-- WHAT THE ENGINE ACTUALLY GIVES US (ADDONBRAIN api.lua:354):
--
--     function ADDON_API.GetMemoryUsage()
--       local stats = UIParent:GetVirtualMemoryStats()
--       if stats == nil then return nil end
--       return stats.usage
--     end
--
-- Two consequences drive everything below. It returns **nil** whenever the stats block is
-- unavailable, so every read is optional and a nil must never be treated as zero -- zero
-- would read as "memory is fine" and suppress exactly the warning you need. And the UNIT is
-- not documented: in practice the value arrives already in MB on some builds and in bytes on
-- others, so it has to be inferred per sample.

local api = require("api")

local MemoryTracker = {
    settings = nil,
    notify = nil,
    currentMB = nil,
    -- Thresholds already announced this session. Cleared when memory drops back down, so a
    -- session that recovers can warn again rather than going quiet for good.
    announced = {},
    criticalLatched = false,
    elapsed = 0,
    lastSampleAt = nil,
    window = nil,
    label = nil,
    applyDrag = nil,
    moveMode = false,
    unavailable = false
}

-- Below this the value is already megabytes; above it, bytes. A real client sitting at
-- 2800 MB reports either 2800 or 2936012800, and nothing plausible sits between -- no client
-- uses 100 GB, and none survives at 100 KB. CrashAge draws the line in the same place.
local MB_CUTOFF = 100000
local SAMPLE_MS = 2000
local WARN_HOLD_MS = 6000
local RECOVER_MARGIN = 100

local function safeCall(fn)
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

local function now()
    return tonumber(safeCall(function() return api.Time:GetUiMsec() end)) or 0
end

function MemoryTracker.CriticalMB()
    local value = tonumber(MemoryTracker.settings and MemoryTracker.settings.memoryCriticalMB)
    if not value or value <= 0 then return 3000 end
    return value
end

-- Warning milestones, DERIVED from the one number the player actually knows: roughly where
-- their client dies. CrashAge asks for a comma-separated list as well as a critical value,
-- which means parsing free text and defending against every way it can be mistyped, to
-- express something that is always "warn me a bit before the end". Two fixed steps back from
-- critical say the same thing with one setting and nothing to get wrong.
function MemoryTracker.Thresholds()
    local critical = MemoryTracker.CriticalMB()
    return {critical - 200, critical - 100}
end

-- Returns megabytes, or nil when the engine has nothing for us.
function MemoryTracker.Sample()
    local raw = safeCall(function() return api.GetMemoryUsage() end)
    raw = tonumber(raw)
    if not raw or raw <= 0 then return nil end
    if raw >= MB_CUTOFF then raw = raw / 1024 / 1024 end
    return math.floor(raw + 0.5)
end

-- Green well below the ceiling, white approaching it, amber near it, red at it. Ratios rather
-- than absolute numbers, so the ramp follows the player's own critical setting.
--
-- These are TEXT colours and are deliberately NOT taken from the caller's palette. Doing that
-- was a bug: this addon's COLORS.active is {0.12, 0.28, 0.15} -- a dark green FILL tone for
-- painting a button background -- and as 10px text on an already-dark button it reads as
-- grey. A palette's fill tones and its text tones are not interchangeable.
local RAMP = {
    safe     = {0.38, 0.95, 0.44, 1},
    watch    = {1.00, 1.00, 1.00, 1},
    warn     = {1.00, 0.84, 0.00, 1},
    critical = {1.00, 0.42, 0.40, 1}
}

function MemoryTracker.ToneFor(mb)
    local critical = MemoryTracker.CriticalMB()
    local ratio = (tonumber(mb) or 0) / math.max(1, critical)
    if ratio >= 0.95 then return RAMP.critical end
    if ratio >= 0.85 then return RAMP.warn end
    if ratio >= 0.70 then return RAMP.watch end
    return RAMP.safe
end

function MemoryTracker.LabelText()
    if MemoryTracker.unavailable then return "Mem n/a" end
    if not MemoryTracker.currentMB then return "Mem --" end
    return "Mem " .. tostring(MemoryTracker.currentMB)
end

-- ---------------------------------------------------------------------------------------
-- Warning banner
--
-- Same chrome as the cooldown popup -- dark plate, 1px border, flat text -- so the addon
-- speaks with one voice. It is a separate widget rather than a ReadyPopup queue entry
-- because that one is icon-only by design (recognise the skill at a glance), and a memory
-- warning has no icon and everything to say in words.

local function createWindow()
    if MemoryTracker.window then return MemoryTracker.window end
    local settings = MemoryTracker.settings
    if not settings then return nil end

    local window = api.Interface:CreateEmptyWindow("powerRangerMemoryWarning", "UIParent")
    window:SetExtent(300, 44)
    window:AddAnchor("TOPLEFT", "UIParent",
        tonumber(settings.memoryWarnX) or 700, tonumber(settings.memoryWarnY) or 220)
    -- Over the world, so it must never swallow a click. Both calls are required.
    if window.Clickable then window:Clickable(false) end
    if window.EnablePick then window:EnablePick(false) end

    local border = window:CreateColorDrawable(0, 0, 0, 0.92, "background")
    border:AddAnchor("TOPLEFT", window, 0, 0)
    border:AddAnchor("BOTTOMRIGHT", window, 0, 0)
    border:Show(true)
    local body = window:CreateColorDrawable(0.06, 0.06, 0.068, 0.96, "background")
    body:AddAnchor("TOPLEFT", window, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", window, -1, -1)
    body:Show(true)

    local label = window:CreateChildWidget("label", "power_ranger_memory_warn_label", 0, true)
    label:SetExtent(288, 36)
    label:AddAnchor("TOPLEFT", window, 6, 4)
    if label.style then
        label.style:SetFontSize(13)
        label.style:SetAlign(ALIGN.CENTER)
    end
    if label.Clickable then label:Clickable(false) end
    if label.EnablePick then label:EnablePick(false) end
    label:Show(true)
    MemoryTracker.label = label

    -- Full-size drag handle, so it is shown ONLY in Move mode. Left live it would eat every
    -- click over the banner -- the trap the guild label and the CD popup both hit.
    local handle = window:CreateChildWidget("emptywidget", "power_ranger_memory_warn_drag", 0, true)
    handle:SetExtent(300, 44)
    handle:AddAnchor("TOPLEFT", window, 0, 0)
    handle:Show(false)
    window.dragHandle = handle
    if MemoryTracker.applyDrag then
        MemoryTracker.applyDrag(window, handle, "memoryWarnX", "memoryWarnY")
    end

    window:Show(false)
    MemoryTracker.window = window
    return window
end

function MemoryTracker.SetMoveMode(on)
    MemoryTracker.moveMode = on == true
    local window = createWindow()
    if not window then return end

    -- The banner is click-through in normal use, which also stops its own drag handle from
    -- ever receiving a press. Move mode has to lift that on the WINDOW, not just arm the
    -- handle -- with EnablePick(false) still set the handle is visible and inert, which is
    -- exactly "it shows the move box but will not move".
    if window.Clickable then pcall(function() window:Clickable(MemoryTracker.moveMode) end) end
    if window.EnablePick then pcall(function() window:EnablePick(MemoryTracker.moveMode) end) end

    if window.dragHandle then
        if window.dragHandle.Clickable then
            pcall(function() window.dragHandle:Clickable(MemoryTracker.moveMode) end)
        end
        window.dragHandle:Show(MemoryTracker.moveMode)
    end

    if MemoryTracker.moveMode then
        MemoryTracker.ShowWarning("Memory warning position", nil, true)
    else
        -- Leaving move mode must clear the sample banner. It was shown sticky (hideAt = 0),
        -- so nothing else will ever take it down and it sits on screen for the rest of the
        -- session.
        MemoryTracker.HideWarning()
    end
end

-- sticky = stay until dismissed by a later call; used for Move mode and the critical alert.
function MemoryTracker.ShowWarning(text, tone, sticky)
    local window = createWindow()
    if not window or not MemoryTracker.label then return end
    MemoryTracker.label:SetText(tostring(text or ""))
    if MemoryTracker.label.style then
        local c = tone or {1, 1, 1, 1}
        MemoryTracker.label.style:SetColor(c[1], c[2], c[3], c[4] or 1)
    end
    MemoryTracker.hideAt = sticky and 0 or (now() + WARN_HOLD_MS)
    window:Show(true)
end

function MemoryTracker.HideWarning()
    if MemoryTracker.window then MemoryTracker.window:Show(false) end
    MemoryTracker.hideAt = nil
end

-- ---------------------------------------------------------------------------------------

function MemoryTracker.Init(settings, applyDrag, notify)
    MemoryTracker.settings = settings
    MemoryTracker.applyDrag = applyDrag
    MemoryTracker.notify = notify
    MemoryTracker.announced = {}
    MemoryTracker.criticalLatched = false
    MemoryTracker.currentMB = nil
    MemoryTracker.unavailable = false
end

-- Called on every sample. Split out so the threshold logic can be reasoned about without
-- the widget code around it.
function MemoryTracker.Evaluate(mb)
    local critical = MemoryTracker.CriticalMB()

    if mb >= critical then
        if not MemoryTracker.criticalLatched then
            MemoryTracker.criticalLatched = true
            MemoryTracker.ShowWarning(
                "MEMORY " .. mb .. " MB\nRelog now to avoid a crash",
                MemoryTracker.ToneFor(mb), true)
            if MemoryTracker.notify then
                MemoryTracker.notify("Memory at " .. mb .. " MB -- relog soon to avoid a client crash.")
            end
        end
        return
    end

    -- Hysteresis: only clear the latch once memory has fallen meaningfully below the ceiling,
    -- so a value oscillating across the line does not re-alarm on every sample.
    if MemoryTracker.criticalLatched and mb < (critical - RECOVER_MARGIN) then
        MemoryTracker.criticalLatched = false
        MemoryTracker.HideWarning()
    end

    for _, threshold in ipairs(MemoryTracker.Thresholds()) do
        if mb >= threshold and not MemoryTracker.announced[threshold] then
            MemoryTracker.announced[threshold] = true
            MemoryTracker.ShowWarning("Memory " .. mb .. " MB",
                MemoryTracker.ToneFor(mb), false)
        elseif mb < (threshold - RECOVER_MARGIN) and MemoryTracker.announced[threshold] then
            -- Rearm, so a session that recovers and climbs again still warns.
            MemoryTracker.announced[threshold] = nil
        end
    end
end

-- dt in milliseconds, from the addon's existing update tick.
function MemoryTracker.Update(dt)
    local settings = MemoryTracker.settings
    if not settings then return end

    if MemoryTracker.hideAt and MemoryTracker.hideAt > 0 and now() >= MemoryTracker.hideAt then
        MemoryTracker.HideWarning()
    end

    if settings.memoryWatchEnabled ~= true then
        MemoryTracker.HideWarning()
        return
    end

    MemoryTracker.elapsed = MemoryTracker.elapsed + (tonumber(dt) or 0)
    local interval = math.max(500, (tonumber(settings.memorySampleMs) or SAMPLE_MS))
    if MemoryTracker.elapsed < interval then return end
    MemoryTracker.elapsed = 0

    local mb = MemoryTracker.Sample()
    if not mb then
        -- Distinct from "0 MB". The readout says n/a and no warning fires, because an absent
        -- reading is not evidence that memory is fine.
        MemoryTracker.unavailable = true
        return
    end
    MemoryTracker.unavailable = false
    MemoryTracker.currentMB = mb
    MemoryTracker.lastSampleAt = now()
    MemoryTracker.Evaluate(mb)
end

function MemoryTracker.Cleanup()
    if MemoryTracker.window then
        pcall(function() MemoryTracker.window:Show(false) end)
    end
    MemoryTracker.window = nil
    MemoryTracker.label = nil
    MemoryTracker.announced = {}
    MemoryTracker.criticalLatched = false
    MemoryTracker.currentMB = nil
    MemoryTracker.elapsed = 0
    MemoryTracker.hideAt = nil
end

return MemoryTracker
