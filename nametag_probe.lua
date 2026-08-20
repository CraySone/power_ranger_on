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
-- The per-value button list lived here. The guided SWEEP below replaces it: a wall of
-- 25 buttons invited exactly the free-clicking that produced two dumps with no usable
-- observations in them.


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

-- The call an observation belongs to. Stamping "OBSERVED: x" on its own only pairs correctly
-- if the tester alternates strictly call/observe -- the first run batched three calls then
-- three observations, and the transcript could not say which caused what. Naming the call
-- inside the observation makes the pairing impossible to lose.
local lastCall = "(nothing yet)"

-- Chat scrolls away and cannot be diffed, and this probe's output is a sequence you want to
-- compare against what you saw on screen. Written after every call as well as on demand, so
-- a crash mid-probe does not lose the run.
local DUMP_PATH = "power_ranger_on/nametag_probe_dump.txt"

-- api.File:Write runs its argument through serializeTable, so a single joined string comes
-- back out as one escaped Lua string literal with a trailing backslash on every line. Passing
-- the TABLE writes a readable list instead.
local function writeDump()
    local lines = {
        "X2NameTag probe -- power_ranger_on",
        "Each line is a call and what it returned. Whether it CHANGED anything is only",
        "visible in game: none of these methods has a getter.",
        ""
    }
    for i = 1, #transcript do lines[#lines + 1] = transcript[i] end
    return (pcall(function() api.File:Write(DUMP_PATH, lines) end))
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

-- === GUIDED SWEEP ==========================================================================
--
-- Two rounds of free-clicking produced 28 calls and no usable observations, because the
-- protocol asked the tester to remember a second click AFTER walking to a window and looking
-- at the world. That does not survive contact with actually looking.
--
-- So the probe asks instead. It applies one value, then puts two yes/no questions on screen
-- and will not move on until both are answered. The answer for the value is recorded with the
-- value, so nothing can drift out of pairing, and it advances by itself.
--
-- SWEEP contains only the two methods that could plausibly separate categories.
-- SetDrawNameTag is already known to be all-or-nothing and is not worth a step here.
-- ROUND TWO. The first full sweep settled two of these:
--
--   SetNameTagMode(0)      hides PLAYER names and keeps NPC names -- the exact inverse of
--                          what is wanted, but proof the engine discriminates by category
--                          rather than being all-or-nothing underneath.
--   SetNameTagMode(1..5)   no change.
--   FactionSelection(any)  no change at all, including 255. Inert as called: either it wants
--                          a different argument shape, or an apply step after it.
--
-- That leaves SetNameTag, the one method never called and the most generically named.
-- api.Nametag enumerates exactly ten categories through its colour commands -- friendly,
-- friendly_npc, neutral, party, raid, raidpk, pk, enemy, monster, pirate -- so
-- SetNameTag(category, visible) is the obvious shape to try. Sweeping (n, 0) for n = 0..9
-- asks whether any single category can be switched off on its own.
local SWEEP = {
    { fn = "SetNameTag", args = {0, 0}, label = "SetNameTag(0, 0)" },
    { fn = "SetNameTag", args = {1, 0}, label = "SetNameTag(1, 0)" },
    { fn = "SetNameTag", args = {2, 0}, label = "SetNameTag(2, 0)" },
    { fn = "SetNameTag", args = {3, 0}, label = "SetNameTag(3, 0)" },
    { fn = "SetNameTag", args = {4, 0}, label = "SetNameTag(4, 0)" },
    { fn = "SetNameTag", args = {5, 0}, label = "SetNameTag(5, 0)" },
    { fn = "SetNameTag", args = {6, 0}, label = "SetNameTag(6, 0)" },
    { fn = "SetNameTag", args = {7, 0}, label = "SetNameTag(7, 0)" },
    { fn = "SetNameTag", args = {8, 0}, label = "SetNameTag(8, 0)" },
    { fn = "SetNameTag", args = {9, 0}, label = "SetNameTag(9, 0)" },
    -- Single-argument forms, in case it is a plain on/off rather than per-category.
    { fn = "SetNameTag", args = {0}, label = "SetNameTag(0)" },
    { fn = "SetNameTag", args = {1}, label = "SetNameTag(1)" },
    -- Re-checked last, since mode 0 is the one known lever and the sweep leaves it set.
    { fn = "SetNameTagMode", args = {0}, label = "SetNameTagMode(0)" },
    { fn = "SetNameTagFactionSelection", args = {255}, label = "FactionSelection(255)" }
}

local sweepIndex = 0
local sweepNpc = nil        -- nil = not answered yet for the current step

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
    lastCall = entry.label
    local ok, result = pcall(function() return fn(obj, unpack(entry.args)) end)
    if ok then
        record(entry.label .. "  ->  OK, returned " .. describe(result))
    else
        record(entry.label .. "  ->  ERROR: " .. describe(result))
    end
    writeDump()
end

-- Applies the next value and asks about it. Called once to begin, then after each answered
-- pair.
local function sweepStep()
    sweepNpc = nil
    sweepIndex = sweepIndex + 1
    if sweepIndex > #SWEEP then
        record("SWEEP COMPLETE -- see the dump file for the table.")
        NametagProbe.SetPrompt("Sweep complete. Send me the dump file.")
        writeDump()
        return
    end
    local entry = SWEEP[sweepIndex]
    invoke(entry)
    NametagProbe.SetPrompt(string.format("Step %d/%d -- %s applied.  Can you still see NPC names?",
        sweepIndex, #SWEEP, entry.label))
end

-- Two questions per value: NPC names visible, then player names visible. Recorded together so
-- the pair is meaningful on its own line.
local function sweepAnswer(visible)
    if sweepIndex < 1 or sweepIndex > #SWEEP then return end
    local entry = SWEEP[sweepIndex]
    if sweepNpc == nil then
        sweepNpc = visible
        NametagProbe.SetPrompt(string.format("Step %d/%d -- %s.  And PLAYER names?",
            sweepIndex, #SWEEP, entry.label))
        return
    end
    local verdict = "  <-- NPC HIDDEN, PLAYERS KEPT"
    if sweepNpc or not visible then verdict = "" end
    record(string.format("RESULT  %-24s npc=%s  player=%s%s",
        entry.label, sweepNpc and "yes" or "no", visible and "yes" or "no", verdict))
    writeDump()
    sweepStep()
end

function NametagProbe.StartSweep()
    sweepIndex = 0
    record("=== GUIDED SWEEP START -- stand where an NPC and a player are both visible ===")
    sweepStep()
end

function NametagProbe.SetPrompt(text)
    if NametagProbe.promptLabel then
        pcall(function() NametagProbe.promptLabel:SetText(text or "") end)
    end
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
        "Writes real client settings. There are no getters, so nothing here can read your",
        16, 42, 580, 14, 11, colors.danger or {1, 0.42, 0.40, 1}, ALIGN.LEFT)
    UiHelpers.Label(wnd, "power_ranger_nametag_probe_warn2",
        "values back or restore them. Only the client's own options window can undo it.",
        16, 58, 580, 14, 11, colors.danger or {1, 0.42, 0.40, 1}, ALIGN.LEFT)

    -- THE GUIDED SWEEP is the whole point of the window. Two rounds of free-clicking produced
    -- 28 calls and no usable observations, because the protocol relied on the tester
    -- remembering a second click after walking away to look at the world. This applies one
    -- value, asks two yes/no questions about it, and advances by itself -- so an answer can
    -- never end up paired with the wrong value.
    NametagProbe.promptLabel = UiHelpers.Label(wnd, "power_ranger_nametag_prompt",
        "Press Start. Stand where an NPC and a player are both visible.",
        16, 84, 580, 16, 12, colors.gold or {1, 0.84, 0, 1}, ALIGN.LEFT)

    UiHelpers.FlatButton(wnd, "power_ranger_nametag_sweep", "Start sweep", 16, 106, 120, 24,
        colors.blue or {0.16, 0.24, 0.38, 0.95}, function() NametagProbe.StartSweep() end, colors)
    UiHelpers.FlatButton(wnd, "power_ranger_nametag_yes", "Yes, visible", 146, 106, 120, 24,
        colors.active or {0.12, 0.28, 0.15, 0.95}, function() sweepAnswer(true) end, colors)
    UiHelpers.FlatButton(wnd, "power_ranger_nametag_no", "No, hidden", 276, 106, 120, 24,
        colors.button or {0.14, 0.14, 0.16, 0.95}, function() sweepAnswer(false) end, colors)
    UiHelpers.FlatButton(wnd, "power_ranger_nametag_dump", "Write dump", 406, 106, 120, 24,
        colors.button or {0.14, 0.14, 0.16, 0.95}, function()
            record(writeDump() and ("dump written to " .. DUMP_PATH) or "dump FAILED to write")
        end, colors)

    -- The three values the sweep does not cover, because they are already understood or are
    -- about you rather than about categories. Handy for putting nametags back afterwards.
    UiHelpers.Label(wnd, "power_ranger_nametag_extra_title", "Direct calls",
        16, 142, 200, 14, 11, colors.gold or {1, 0.84, 0, 1}, ALIGN.LEFT)
    local EXTRAS = {
        { fn = "SetDrawNameTag", args = {1}, label = "SetDrawNameTag(1) -- all back on" },
        { fn = "SetDrawNameTag", args = {0}, label = "SetDrawNameTag(0) -- all off" },
        { fn = "SetSelfNameTagVisible", args = {1}, label = "SetSelfNameTagVisible(1)" },
        { fn = "SetSelfNameTagVisible", args = {0}, label = "SetSelfNameTagVisible(0)" }
    }
    local ey = 160
    for index, entry in ipairs(EXTRAS) do
        UiHelpers.FlatButton(wnd, "power_ranger_nametag_extra_" .. index, entry.label,
            16, ey, 240, 20, colors.button or {0.14, 0.14, 0.16, 0.95},
            function() invoke(entry) end, colors)
        ey = ey + 22
    end

    UiHelpers.Label(wnd, "power_ranger_nametag_result_title", "Log (newest first)",
        276, 142, 300, 14, 11, colors.gold or {1, 0.84, 0, 1}, ALIGN.LEFT)
    NametagProbe.resultLabel = UiHelpers.Label(wnd, "power_ranger_nametag_result", "",
        276, 160, 326, 280, 10, colors.white or {1, 1, 1, 1}, ALIGN.LEFT)

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
