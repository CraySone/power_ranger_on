-- TEMPORARY. Delete this file and its button once the X2NameTag surface is understood.
--
-- WHY IT EXISTS. Turning NPC names off is a client option, but ADDON_API exposes no wrapper
-- for it -- api.Nametag only sets colours, and it does that through Console:ExecuteString,
-- which is not in the sandbox. What IS in the sandbox (sandbox.lua:315, both client builds)
-- is the raw engine object X2NameTag, and addonbrain_probe found six functions on it:
--
--     SetDrawNameTag  SetNameTag  SetNameTagFactionSelection
--     SetNameTagMode  SetNameTageFadeOutDistance  SetSelfNameTagVisible
--
-- Names only. The probe never called them, so no signature is known, and no addon on disk
-- uses any of them. This window calls them one at a time and reports what came back.
--
-- READ THIS BEFORE CLICKING. These write real client settings and there are NO GETTERS, so
-- nothing here can read your current values back or restore them. Note what your nametag
-- options look like before you start. Every call is pcall'd, so a wrong argument type errors
-- into the log rather than taking the addon down -- but a call that SUCCEEDS with a value you
-- did not intend has changed a setting, and only the client's own options window can put it
-- back.

local api = require("api")
local UiHelpers = require("power_ranger_on/ui_helpers")
local SettingsUi = require("power_ranger_on/settings_ui")

local NametagProbe = {
    window = nil,
    resultLabel = nil,
    ctx = nil,
    log = {}
}

local WIDTH, HEIGHT = 620, 470
local MAX_LOG = 12

-- The engine object is a sandbox global, not something on `api`. It may simply be absent on
-- a build that does not export it, hence the guard on every access.
local function nameTag()
    local ok, obj = pcall(function() return X2NameTag end)
    if not ok then return nil end
    if type(obj) ~= "table" then return nil end
    return obj
end

-- Every candidate call, in the order worth trying: the most likely master switch first, so a
-- single click can answer the actual question before anything else is touched.
--
-- Booleans AND integers are offered for the same method on purpose -- the engine's other
-- setters take 0/1 (SetOptionItemValue does), but Lua bindings often accept either, and which
-- one a method wants is exactly what is unknown here.
local CALLS = {
    { group = "Master switch -- most likely to be the NPC name toggle" },
    { fn = "SetDrawNameTag", args = {0},     label = "SetDrawNameTag(0)" },
    { fn = "SetDrawNameTag", args = {1},     label = "SetDrawNameTag(1)" },
    { fn = "SetDrawNameTag", args = {false}, label = "SetDrawNameTag(false)" },
    { fn = "SetDrawNameTag", args = {true},  label = "SetDrawNameTag(true)" },

    { group = "Mode -- the client's option has several states, not just on/off" },
    { fn = "SetNameTagMode", args = {0}, label = "SetNameTagMode(0)" },
    { fn = "SetNameTagMode", args = {1}, label = "SetNameTagMode(1)" },
    { fn = "SetNameTagMode", args = {2}, label = "SetNameTagMode(2)" },
    { fn = "SetNameTagMode", args = {3}, label = "SetNameTagMode(3)" },

    { group = "Faction selection -- may be the per-category filter" },
    { fn = "SetNameTagFactionSelection", args = {0}, label = "SetNameTagFactionSelection(0)" },
    { fn = "SetNameTagFactionSelection", args = {1}, label = "SetNameTagFactionSelection(1)" },
    { fn = "SetNameTagFactionSelection", args = {2}, label = "SetNameTagFactionSelection(2)" },

    { group = "Self -- safe to test, the effect is obvious and only affects you" },
    { fn = "SetSelfNameTagVisible", args = {0}, label = "SetSelfNameTagVisible(0)" },
    { fn = "SetSelfNameTagVisible", args = {1}, label = "SetSelfNameTagVisible(1)" },

    { group = "Fade distance -- confirms the argument convention (engine's typo, not ours)" },
    { fn = "SetNameTageFadeOutDistance", args = {50},  label = "SetNameTageFadeOutDistance(50)" },
    { fn = "SetNameTageFadeOutDistance", args = {200}, label = "SetNameTageFadeOutDistance(200)" }
}

local function describe(value)
    local t = type(value)
    if t == "nil" then return "nil" end
    if t == "boolean" then return value and "true" or "false" end
    if t == "number" or t == "string" then return tostring(value) end
    return t
end

-- Everything recorded this session, oldest first, for the file dump. The on-screen log is
-- capped at MAX_LOG so it fits the pane; this one is not, because the point of the file is
-- having the whole sequence afterwards.
local transcript = {}

-- Chat scrolls away and cannot be diffed, and this probe's output is a sequence you want to
-- compare against what you saw on screen. Written after every call as well as on demand, so
-- a crash mid-probe does not lose the run.
local DUMP_PATH = "power_ranger_on/nametag_probe_dump.txt"

local function writeDump()
    local lines = {
        "X2NameTag probe -- power_ranger_on",
        "Each line: the call, then what it returned. Whether it CHANGED anything is only",
        "visible in game -- these methods have no getters.",
        ""
    }
    for i = 1, #transcript do lines[#lines + 1] = transcript[i] end
    return (pcall(function() api.File:Write(DUMP_PATH, table.concat(lines, "\n")) end))
end

local function record(text)
    table.insert(NametagProbe.log, 1, text)
    transcript[#transcript + 1] = text
    while #NametagProbe.log > MAX_LOG do table.remove(NametagProbe.log) end
    if NametagProbe.resultLabel then
        NametagProbe.resultLabel:SetText(table.concat(NametagProbe.log, "\n"))
    end
    pcall(function() api.Log:Info("[PR nametag probe] " .. text) end)
end

local function invoke(entry)
    local obj = nameTag()
    if not obj then
        record("X2NameTag is not available in this sandbox.")
        return
    end
    local fn = obj[entry.fn]
    if type(fn) ~= "function" then
        record(entry.fn .. " -- absent on this build")
        return
    end
    -- Called with the object as self, matching how the engine's own objects are invoked
    -- (X2Unit:UnitInfo(unit) etc). If a method turns out to be a plain function this is the
    -- first thing to try changing.
    local ok, result = pcall(function() return fn(obj, unpack(entry.args)) end)
    if ok then
        record(entry.label .. "  ->  OK, returned " .. describe(result))
    else
        record(entry.label .. "  ->  ERROR: " .. describe(result))
    end
    writeDump()
end

function NametagProbe.Open(ctx)
    NametagProbe.ctx = ctx or NametagProbe.ctx
    if NametagProbe.window then
        NametagProbe.window:Show(true)
        if NametagProbe.window.Raise then NametagProbe.window:Raise() end
        return
    end
    local ctxRef = NametagProbe.ctx or {}
    local colors = ctxRef.colors or {}

    local wnd = SettingsUi.CreateShell({
        id = "PowerRangerNametagProbe",
        title = "X2NameTag probe  (temporary)",
        width = WIDTH,
        height = HEIGHT,
        x = 420, y = 180,
        xKey = "nametagProbeX", yKey = "nametagProbeY",
        colors = colors,
        safePosition = ctxRef.safePosition,
        applyDrag = ctxRef.applyDrag,
        closeButtonId = "power_ranger_nametag_probe_close",
        onClose = function() wnd:Show(false) end
    })
    if not wnd then return end
    NametagProbe.window = wnd

    UiHelpers.Label(wnd, "power_ranger_nametag_probe_warn",
        "These write real client settings and there are no getters to read them back.",
        16, 44, 560, 14, 11, colors.danger or {1, 0.42, 0.40, 1}, ALIGN.LEFT)
    UiHelpers.Label(wnd, "power_ranger_nametag_probe_warn2",
        "Note your nametag options before clicking. Only the client's options window can undo them.",
        16, 60, 560, 14, 10, colors.muted or {0.64, 0.66, 0.70, 1}, ALIGN.LEFT)

    local y = 84
    for index, entry in ipairs(CALLS) do
        if entry.group then
            UiHelpers.Label(wnd, "power_ranger_nametag_group_" .. index, entry.group,
                16, y + 4, 560, 14, 10, colors.gold or {1, 0.84, 0, 1}, ALIGN.LEFT)
            y = y + 20
        else
            UiHelpers.FlatButton(wnd, "power_ranger_nametag_call_" .. index, entry.label,
                16, y, 250, 20, colors.blue or {0.16, 0.24, 0.38, 0.95},
                function() invoke(entry) end, colors)
            y = y + 22
        end
    end

    UiHelpers.FlatButton(wnd, "power_ranger_nametag_dump", "Write dump file", 286, 76, 150, 20,
        colors.blue or {0.16, 0.24, 0.38, 0.95}, function()
            record(writeDump() and ("dump written to " .. DUMP_PATH) or "dump FAILED to write")
        end, colors)

    UiHelpers.Label(wnd, "power_ranger_nametag_result_title", "Results (newest first)",
        286, 104, 300, 14, 11, colors.gold or {1, 0.84, 0, 1}, ALIGN.LEFT)
    NametagProbe.resultLabel = UiHelpers.Label(wnd, "power_ranger_nametag_result", "",
        286, 122, 316, 300, 10, colors.white or {1, 1, 1, 1}, ALIGN.LEFT)

    -- Reports whether the object is reachable at all before anything is clicked, so an absent
    -- X2NameTag is distinguishable from a method that silently does nothing.
    local obj = nameTag()
    if not obj then
        record("X2NameTag NOT reachable from this sandbox.")
    else
        local names = {}
        for key, value in pairs(obj) do
            if type(value) == "function" then names[#names + 1] = key end
        end
        table.sort(names)
        record("X2NameTag reachable, " .. #names .. " functions: " .. table.concat(names, ", "))
    end

    wnd:Show(true)
end

function NametagProbe.Cleanup()
    if NametagProbe.window then pcall(function() NametagProbe.window:Show(false) end) end
    NametagProbe.window = nil
    NametagProbe.resultLabel = nil
    NametagProbe.log = {}
end

return NametagProbe
