-- Percent text inside the stock unit-frame HP/MP bars.
--
-- This module patches label:SetText on the native player/target/target-of-target/
-- watch-target frames, so it has to coexist with other addons that patch the same
-- labels (BetterBars uses the label.SetTextOrig convention). Three rules keep that
-- safe, and breaking any one of them caused a real bug in the field:
--
--   1. The wrapper captures the true native SetText as a closure upvalue. The old
--      version looked the original up by field name at call time, so a second
--      patch pass could end up with Orig pointing at a previous wrapper -- that
--      wrapper then called itself forever. That was the "huge FPS drop with
--      BetterBars" report.
--   2. restoreLabel() no-ops unless we actually patched. The old version re-anchored
--      and re-styled the labels on every Apply(false), including the one that runs at
--      login when the setting is OFF, which stomped BetterBars' centered bars every
--      single login ("my name bars keep resetting").
--   3. Patching is idempotent and re-checked on a slow tick, so an addon that loads
--      after us (or a frame that is not ready at login) is repaired automatically
--      instead of needing the user to toggle the setting off and on again.

local api = require("api")

local HpPercentBars = {
    frames = {},
    enabled = false,
    cache = {},
    healElapsed = 0,
    conflict = false
}

local CACHE_TTL_MS = 250
-- Cheap identity checks over 8 labels; only does real work when something clobbered us.
local SELF_HEAL_MS = 2000
-- Guards against a pathological wrapper chain left by an old build.
local MAX_UNWRAP = 8

local FRAME_SPECS = {
    { unit = "player", uic = UIC.PLAYER_UNITFRAME },
    { unit = "target", uic = UIC.TARGET_UNITFRAME },
    { unit = "targettarget", uic = UIC.TARGET_OF_TARGET_FRAME },
    { unit = "watchtarget", uic = UIC.WATCH_TARGET_FRAME }
}

local function safeCall(fn)
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

local function formatPercent(unit, kind)
    local cacheKey = tostring(unit or "") .. ":" .. tostring(kind or "health")
    local now = (api.Time and api.Time.GetUiMsec and api.Time:GetUiMsec()) or 0
    local cached = HpPercentBars.cache[cacheKey]
    if cached and now - cached.time < CACHE_TTL_MS then
        return cached.value
    end
    local current
    local max
    if kind == "mana" then
        current = tonumber(safeCall(function() return api.Unit:UnitMana(unit) end))
        max = tonumber(safeCall(function() return api.Unit:UnitMaxMana(unit) end))
    else
        current = tonumber(safeCall(function() return api.Unit:UnitHealth(unit) end))
        max = tonumber(safeCall(function() return api.Unit:UnitMaxHealth(unit) end))
    end
    if not current or not max or max <= 0 then
        HpPercentBars.cache[cacheKey] = { time = now, value = nil }
        return nil
    end
    local percent = math.floor(((current / max) * 100) + 0.5)
    percent = math.max(0, math.min(100, percent))
    local value = string.format("%d%%", percent)
    HpPercentBars.cache[cacheKey] = { time = now, value = value }
    return value
end

local function prefixFor(kind)
    return kind == "mana" and "_powerRangerMpPercent" or "_powerRangerHpPercent"
end

-- The real game SetText, never one of our wrappers. Our own wrapper reference is kept
-- on the label (not in a module local) so it is still recognisable after a /reload,
-- which wipes module state but leaves the patched widget in place.
local function resolveNative(label, prefix)
    local ourWrapper = label[prefix .. "Wrapper"]
    local candidate = label.SetTextOrig or label.SetText
    local guard = 0
    while ourWrapper ~= nil and candidate == ourWrapper and guard < MAX_UNWRAP do
        candidate = label[prefix .. "Native"]
        guard = guard + 1
    end
    if type(candidate) ~= "function" then return nil end
    if ourWrapper ~= nil and candidate == ourWrapper then return nil end
    return candidate
end

local function patchLabel(unit, bar, label, kind)
    if not bar or not label then return end
    local prefix = prefixFor(kind)
    local native = resolveNative(label, prefix)
    if not native then return end

    -- Already installed against the same native: nothing to do. This is what makes the
    -- self-heal tick almost free and stops repeated Apply() calls from stacking wrappers.
    if label[prefix .. "Patched"] == true
        and label.SetText == label[prefix .. "Wrapper"]
        and label[prefix .. "Native"] == native then
        return
    end

    if label[prefix .. "Patched"] ~= true then
        -- First patch on this label: remember exactly what we have to hand back.
        label[prefix .. "PrevSetText"] = label.SetText
        label[prefix .. "PrevSetTextOrig"] = label.SetTextOrig
        label:RemoveAllAnchors()
        label:AddAnchor("CENTER", bar, "CENTER", 0, 0)
        if label.style then
            label.style:SetFontSize((FONT_SIZE and FONT_SIZE.MIDDLE) or 14)
            label.style:SetAlign(ALIGN.CENTER)
        end
    end

    label[prefix .. "Patched"] = true
    label[prefix .. "Native"] = native
    label[prefix .. "Unit"] = unit
    label[prefix .. "Kind"] = kind

    -- unit/kind/native are upvalues, so this can never resolve back to itself.
    local wrapper = function(self, text)
        local value = formatPercent(unit, kind)
        native(self, value or tostring(text or ""))
    end
    label[prefix .. "Wrapper"] = wrapper
    label.SetText = wrapper

    local value = formatPercent(unit, kind)
    if value then label:SetText(value) end
end

local function restoreLabel(bar, label, kind)
    if not bar or not label then return end
    local prefix = prefixFor(kind)
    -- Never touch a label we did not patch. Apply(false) runs at every login.
    if label[prefix .. "Patched"] ~= true then return end

    local wrapper = label[prefix .. "Wrapper"]
    local native = label[prefix .. "Native"]
    if wrapper ~= nil and label.SetText == wrapper then
        label.SetText = label[prefix .. "PrevSetText"] or native
    end
    -- Someone chained onto us after we patched (BetterBars loading later); point their
    -- passthrough at the game function so removing us does not orphan their wrapper.
    if wrapper ~= nil and label.SetTextOrig == wrapper then
        label.SetTextOrig = native
    end

    local hadExternalPatch = label[prefix .. "PrevSetTextOrig"] ~= nil
    label[prefix .. "Patched"] = nil
    label[prefix .. "Wrapper"] = nil
    label[prefix .. "Native"] = nil
    label[prefix .. "Unit"] = nil
    label[prefix .. "Kind"] = nil
    label[prefix .. "PrevSetText"] = nil
    label[prefix .. "PrevSetTextOrig"] = nil

    -- Only restore the stock look if the label was stock when we found it. If another
    -- addon had already restyled it, leave its layout alone.
    if not hadExternalPatch then
        label:RemoveAllAnchors()
        label:AddAnchor("BOTTOMRIGHT", bar, -1, -1)
        if label.style then
            label.style:SetFontSize((FONT_SIZE and FONT_SIZE.SMALL) or 11)
            label.style:SetAlign(ALIGN.RIGHT)
        end
    end
end

local function patchFrame(unit, frame)
    if not frame then return end
    patchLabel(unit, frame.hpBar, frame.hpBar and frame.hpBar.hpLabel, "health")
    patchLabel(unit, frame.mpBar, frame.mpBar and frame.mpBar.mpLabel, "mana")
end

local function restoreFrame(frame)
    if not frame then return end
    restoreLabel(frame.hpBar, frame.hpBar and frame.hpBar.hpLabel, "health")
    restoreLabel(frame.mpBar, frame.mpBar and frame.mpBar.mpLabel, "mana")
end

local function frameFor(spec)
    local frame = HpPercentBars.frames[spec.unit] or safeCall(function() return ADDON:GetContent(spec.uic) end)
    HpPercentBars.frames[spec.unit] = frame
    return frame
end

-- BetterBars (and anything else using the same convention) parks the stock SetText on
-- label.SetTextOrig. We never set that field, so its presence means another bar addon
-- owns these labels. Two addons rewriting the same label only ever produces the wrong
-- format for one of them, so we stand down and let the dedicated bar addon win.
function HpPercentBars.HasConflict()
    for _, spec in ipairs(FRAME_SPECS) do
        local frame = frameFor(spec)
        if frame then
            local hpLabel = frame.hpBar and frame.hpBar.hpLabel
            local mpLabel = frame.mpBar and frame.mpBar.mpLabel
            if (hpLabel and hpLabel.SetTextOrig ~= nil) or (mpLabel and mpLabel.SetTextOrig ~= nil) then
                return true
            end
        end
    end
    return false
end

function HpPercentBars.Apply(enabled)
    HpPercentBars.enabled = enabled == true
    HpPercentBars.conflict = HpPercentBars.HasConflict()
    -- A conflicting addon can load after us, so this also has to undo a patch we
    -- already installed rather than just skipping the patch step.
    local shouldPatch = HpPercentBars.enabled and not HpPercentBars.conflict
    for _, spec in ipairs(FRAME_SPECS) do
        local frame = frameFor(spec)
        if shouldPatch then
            patchFrame(spec.unit, frame)
        else
            restoreFrame(frame)
        end
    end
end

-- Driven from the addon update loop. Re-asserts the patch on a slow tick so a frame that
-- was not ready at login, or an addon that patched after us, no longer needs the user to
-- toggle the setting twice.
function HpPercentBars.Tick(dt)
    if not HpPercentBars.enabled then return end
    HpPercentBars.healElapsed = HpPercentBars.healElapsed + (tonumber(dt) or 0)
    if HpPercentBars.healElapsed < SELF_HEAL_MS then return end
    HpPercentBars.healElapsed = 0
    HpPercentBars.Apply(true)
end

function HpPercentBars.Refresh()
    if HpPercentBars.enabled then HpPercentBars.Apply(true) end
end

function HpPercentBars.Cleanup()
    HpPercentBars.Apply(false)
    HpPercentBars.frames = {}
    HpPercentBars.cache = {}
    HpPercentBars.healElapsed = 0
end

return HpPercentBars
