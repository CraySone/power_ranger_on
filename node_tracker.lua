-- Resource node tracker: dried mineral water, cooled tree trunks, fish schools and the
-- Working Settler Gamekeeper. Hover one and its respawn timer is saved against that
-- world position, so the same node updates in place instead of piling up duplicates.
--
-- Ported from the Land Barons - Arise farm tracker (tax_tracker/farmsystem.lua), but a
-- STANDALONE implementation: its own listener, its own spot store under Power Ranger's
-- settings, nothing shared with tax_tracker and nothing to drift out of sync. If
-- tax_tracker is loaded with its autotracker on, this module stands down entirely and
-- lets it own the job -- same pattern as the BetterBars stand-down in hp_percent_bars.
--
-- Detection is hover-driven (DRAW_DOODAD_TOOLTIP), not world scanning, which is why it
-- works at all: the sandbox blocks UNIT_ENTERED_SIGHT / UNIT_LEAVED_SIGHT.

local api = require("api")
local UiHelpers = require("power_ranger_on/ui_helpers")

local NodeTracker = {
    settings = nil,
    applyDrag = nil,
    window = nil,
    listener = nil,
    listening = false,
    lastInfo = nil,
    rows = {},
    elapsed = 0,
    sessionId = nil,
    conflict = false,
    -- Collapsed/expanded state per group, runtime only -- same as farmsystem's
    -- autotrackerExpandedGroups.
    expanded = {},
    page = 1,
    announced = {}
}

local UPDATE_MS = 250
-- Geometry copied from the Land Barons tracking window (farmsystem's AUTO_* constants) so
-- the two read as the same tool: 760 wide, 11 rows of 24px starting at y=64, and the same
-- "110 + rows*24" height rule with 125 when empty.
local AUTO_W = 760
local AUTO_ROWS = 11
local AUTO_ROW_H = 24
local AUTO_FIRST_Y = 64
-- Column geometry copied verbatim from farmsystem's AUTO_* constants.
local AUTO_LOCATION_X = 30
local AUTO_LOCATION_W = 210
local AUTO_ENTITY_X = 246
local AUTO_ENTITY_W = 150
local AUTO_QTY_X = 402
local AUTO_QTY_W = 34
local AUTO_EARLIEST_X = 442
local AUTO_TIME_W = 110
local AUTO_LATEST_X = 558
-- The saved position is the PLAYER's, captured while hovering, so two hovers of the same
-- node can be an interaction-range apart. The radius has to exceed that without swallowing
-- a genuinely different node nearby. Squared, in world units (~metres).
local MATCH_RADIUS2 = 25 * 25

-- FARM_UI tones copied from farmsystem so the chrome matches shade for shade.
local FARM_BUTTON = {0.11, 0.11, 0.13, 0.92}
local FARM_RED = {0.24, 0.09, 0.09, 0.95}
local COLOR_HEAD = {0.64, 0.66, 0.70, 1}
local COLOR_READY = {0.38, 0.95, 0.44, 1}
local COLOR_SOON = {1, 0.78, 0.28, 1}
local COLOR_WAIT = {0.72, 0.76, 0.84, 1}

-- Name matchers lifted verbatim from farmsystem so the two addons agree on what counts.
local KINDS = {
    {
        key = "water", label = "Water",
        match = function(lower) return lower:find("dried up mineral water", 1, true) ~= nil end
    },
    {
        key = "log", label = "Log",
        match = function(lower) return lower:find("cooled tree trunk", 1, true) ~= nil end
    },
    {
        key = "npc", label = "NPC",
        match = function(lower) return lower:find("working settler gamekeeper", 1, true) ~= nil end
    }
}

-- Both names per fish: schooling (non-fed) and feeding frenzy (fed). Hardcoded so an
-- unrelated mob cannot register itself as a fish hole.
local FISH_NAMES = {"Bluefin Tuna", "Sturgeon", "Sailfish", "Blue Marlin"}
local FISH_MATCH = {}
for _, fish in ipairs(FISH_NAMES) do
    FISH_MATCH["schooling " .. fish:lower()] = true
    FISH_MATCH[fish:lower() .. " feeding frenzy"] = true
end
KINDS[#KINDS + 1] = {
    key = "fish", label = "Fish",
    match = function(lower) return FISH_MATCH[lower] == true end
}

local function safeCall(fn)
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

-- Two independent flags, same split as Land Barons: the WINDOW can stay open while the
-- autotracker is paused, and the title says so. Autotracking is what turns a hover into a
-- node, so pausing it stops new entries without hiding what you already have.
local function enabled()
    return NodeTracker.settings ~= nil and NodeTracker.settings.nodeTrackerEnabled == true
end

local function autotracking()
    return NodeTracker.settings ~= nil and NodeTracker.settings.nodeAutotrackEnabled == true
end

function NodeTracker.IsAutotracking()
    return autotracking() and not NodeTracker.HasConflict()
end

-- tax_tracker's scanModifier, same option set: capture only while a modifier is held so a
-- casual hover does not register a node. "any" = any of the three, "none" = no key needed.
NodeTracker.MODIFIERS = {"any", "ctrl", "alt", "shift", "none"}
NodeTracker.MODIFIER_LABELS = {
    any = "Alt/Shift/Ctrl", ctrl = "Ctrl", alt = "Alt", shift = "Shift", none = "No key"
}

function NodeTracker.CaptureModifier()
    local value = tostring(NodeTracker.settings and NodeTracker.settings.nodeCaptureModifier or "none")
    if NodeTracker.MODIFIER_LABELS[value] == nil then return "none" end
    return value
end

function NodeTracker.CycleCaptureModifier()
    local current = NodeTracker.CaptureModifier()
    local index = 1
    for i, name in ipairs(NodeTracker.MODIFIERS) do
        if name == current then index = i break end
    end
    index = index + 1
    if index > #NodeTracker.MODIFIERS then index = 1 end
    if NodeTracker.settings then
        NodeTracker.settings.nodeCaptureModifier = NodeTracker.MODIFIERS[index]
    end
end

local function modifierHeld()
    local mode = NodeTracker.CaptureModifier()
    if mode == "none" then return true end
    local ctrl = safeCall(function() return api.Input:IsControlKeyDown() end) == true
    local alt = safeCall(function() return api.Input:IsAltKeyDown() end) == true
    local shift = safeCall(function() return api.Input:IsShiftKeyDown() end) == true
    if mode == "ctrl" then return ctrl end
    if mode == "alt" then return alt end
    if mode == "shift" then return shift end
    return ctrl or alt or shift
end

-- Per-kind capture filter, the node-tracker equivalent of tax_tracker's entity filter.
function NodeTracker.KindEnabled(kindKey)
    local settings = NodeTracker.settings
    if not settings then return true end
    if type(settings.nodeKinds) ~= "table" then settings.nodeKinds = {} end
    return settings.nodeKinds[kindKey] ~= false
end

function NodeTracker.ToggleKind(kindKey)
    local settings = NodeTracker.settings
    if not settings then return end
    if type(settings.nodeKinds) ~= "table" then settings.nodeKinds = {} end
    settings.nodeKinds[kindKey] = not NodeTracker.KindEnabled(kindKey)
end

local function scaleLevel()
    return math.max(0, math.min(6, tonumber(NodeTracker.settings and NodeTracker.settings.nodeTrackerScaleLevel) or 0))
end

local function S(value)
    return math.max(1, math.floor((tonumber(value) or 0) * (1 + (scaleLevel() * 0.15)) + 0.5))
end

-- ============================================================
-- TIME
-- ============================================================

-- Saved captureUiMsec values belong to a previous client uptime, so the precise
-- millisecond path is only trusted for entries captured in THIS session.
local function sessionId()
    if not NodeTracker.sessionId then
        local localTime = safeCall(function() return api.Time:GetLocalTime() end)
        local uiMs = safeCall(function() return api.Time:GetUiMsec() end)
        NodeTracker.sessionId = tostring(localTime or "session") .. ":" .. tostring(uiMs or 0)
    end
    return NodeTracker.sessionId
end

local function dateToUnix(year, month, day, hour, min, sec)
    local daysInMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    local function isLeap(y)
        return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
    end
    local days = 0
    for y = 1970, year - 1 do
        days = days + (isLeap(y) and 366 or 365)
    end
    for m = 1, month - 1 do
        days = days + daysInMonth[m]
        if m == 2 and isLeap(year) then days = days + 1 end
    end
    days = days + (day - 1)
    return days * 86400 + hour * 3600 + min * 60 + sec
end

-- Only ever used as a difference (expiry - now), so the absolute epoch offset that
-- farmsystem applies here is irrelevant and omitted -- it cancels out either way.
local function nowUnix()
    local t = safeCall(function() return api.Time:TimeToDate(api.Time:GetLocalTime()) end)
    if type(t) ~= "table" then return 0 end
    return dateToUnix(t.year or 1970, t.month or 1, t.day or 1, t.hour or 0, t.minute or 0, t.second or 0)
end

local function remainingSeconds(spot)
    if not spot then return 0 end
    local nowMs = safeCall(function() return api.Time:GetUiMsec() end) or 0
    -- Same-session entries keep millisecond accuracy.
    if spot.captureSession == sessionId() and spot.captureUiMsec and spot.displayTime and nowMs >= spot.captureUiMsec then
        return math.ceil(((spot.captureUiMsec + (spot.displayTime * 1000)) - nowMs) / 1000)
    end
    local expiry = tonumber(spot.expiryUnix)
    if not expiry then return 0 end
    return expiry - nowUnix()
end

-- ============================================================
-- POSITION  (ported verbatim -- the shape fallbacks and the coefficient are load-bearing)
-- ============================================================

local function parsePlayerSextants()
    local ok, r1, r2, r3, r4, r5, r6, r7, r8 = pcall(api.Map.GetPlayerSextants, api.Map)
    if not ok then return nil end
    if type(r1) == "table" and r2 == nil then
        local t = r1
        if t.longitude or t.deg_long then
            return t.longitude or "E", tonumber(t.deg_long) or 0, tonumber(t.min_long) or 0, tonumber(t.sec_long) or 0,
                   t.latitude or "N", tonumber(t.deg_lat) or 0, tonumber(t.min_lat) or 0, tonumber(t.sec_lat) or 0
        end
        if type(t.longitude) == "table" and type(t.latitude) == "table" then
            local L, A = t.longitude, t.latitude
            return L.dir or "E", tonumber(L.deg) or 0, tonumber(L.min) or 0, tonumber(L.sec) or 0,
                   A.dir or "N", tonumber(A.deg) or 0, tonumber(A.min) or 0, tonumber(A.sec) or 0
        end
        if t.longitudeDir then
            return t.longitudeDir or "E", tonumber(t.longitudeDeg) or 0, tonumber(t.longitudeMin) or 0, tonumber(t.longitudeSec) or 0,
                   t.latitudeDir or "N", tonumber(t.latitudeDeg) or 0, tonumber(t.latitudeMin) or 0, tonumber(t.latitudeSec) or 0
        end
        if type(t[1]) == "string" and type(t[2]) == "number" then
            return t[1], tonumber(t[2]) or 0, tonumber(t[3]) or 0, tonumber(t[4]) or 0,
                   t[5], tonumber(t[6]) or 0, tonumber(t[7]) or 0, tonumber(t[8]) or 0
        end
        return nil
    end
    if type(r1) == "string" and type(r2) == "number" and type(r5) == "string" and type(r6) == "number" then
        return r1, tonumber(r2) or 0, tonumber(r3) or 0, tonumber(r4) or 0,
               r5, tonumber(r6) or 0, tonumber(r7) or 0, tonumber(r8) or 0
    end
    return nil
end

local function dmsToSigned(dir, d, m, s)
    local val = (tonumber(d) or 0) + ((tonumber(m) or 0) / 60) + ((tonumber(s) or 0) / 3600)
    if dir == "W" or dir == "S" then val = -val end
    return val
end

local COORD_COEF = 0.00097657363894522145695357130138029
local function lonLatToWorldXY(lon, lat)
    return (lon + 21) / COORD_COEF, (lat + 28) / COORD_COEF
end

local function capturePlayerPosition()
    local ew, ld, lm, ls, ns, pd, pm, ps = parsePlayerSextants()
    local ok, ax, ay, az = pcall(api.Unit.UnitWorldPosition, api.Unit, "player")
    if not ok then ax, ay, az = 0, 0, 0 end
    if type(ax) == "table" then ax, ay, az = ax.x or ax[1] or 0, ax.y or ax[2] or 0, ax.z or ax[3] or 0 end
    local zoneGroup = safeCall(function() return api.Unit:GetCurrentZoneGroup() end) or 0
    if not ew then
        -- No sextants (not carrying one): raw world position still groups nodes correctly.
        return { sextants = "", worldX = tonumber(ax) or 0, worldY = tonumber(ay) or 0, zone = zoneGroup }
    end
    local wx, wy = lonLatToWorldXY(dmsToSigned(ew, ld, lm, ls), dmsToSigned(ns, pd, pm, ps))
    return {
        sextants = string.format("%s %d %d' %d\", %s %d %d' %d\"", ew, ld, lm, ls, ns, pd, pm, ps),
        worldX = wx, worldY = wy, zone = zoneGroup
    }
end

local function distance2(a, b)
    local dx = (tonumber(a.worldX) or 0) - (tonumber(b.worldX) or 0)
    local dy = (tonumber(a.worldY) or 0) - (tonumber(b.worldY) or 0)
    return dx * dx + dy * dy
end

-- ============================================================
-- STORE
-- ============================================================
--
-- TWO separate stores, mirroring Land Barons exactly:
--
--   settings.nodeSpots  -- captured LOCATIONS. No timer, never shown in the tracking
--                          window. Only cooled tree trunks and mineral water use them;
--                          they are the container a hovered node's timer is filed under.
--   settings.nodeTimers -- the actual tracked NODES with respawn timers. This is what the
--                          tracking window shows.
--
-- Routing on hover (farmsystem doodad handler):
--   log / water -> nearest captured spot in the same zone. NO spot means NOTHING is
--                  tracked and the player is told to capture the spot first.
--   fish / npc  -> an automatic per-zone container, no spot needed (schools and the
--                  gamekeeper are not fixed single locations).

local function spots()
    local settings = NodeTracker.settings
    if not settings then return {} end
    if type(settings.nodeSpots) ~= "table" then settings.nodeSpots = {} end
    return settings.nodeSpots
end

local function timers()
    local settings = NodeTracker.settings
    if not settings then return {} end
    if type(settings.nodeTimers) ~= "table" then settings.nodeTimers = {} end
    return settings.nodeTimers
end

local function classify(name)
    local lower = string.lower(tostring(name or ""))
    if lower == "" then return nil end
    for _, kind in ipairs(KINDS) do
        if kind.match(lower) then return kind end
    end
    return nil
end

-- One definition of the group key so the render list and the group delete can never
-- disagree. Grouped by container + entity name, matching farmsystem's farm.id + doodad
-- name. A printable separator on purpose: the original \0 escape got mangled into a real
-- NUL byte in the source once already.
local function groupKeyOf(entry)
    return tostring(entry.container) .. "~|~" .. tostring(entry.sourceName)
        .. "~|~" .. tostring(entry.owner or "")
end

-- farmsystem's normalizeName: everything from the first symbol character onward is cut,
-- so "Cooled Tree Trunk (Marcala)" and "Cooled Tree Trunk: ready" collapse to one entity.
-- Without this every punctuation variant of the same node became its own group, which is
-- what made differentiating them feel worse here than in Land Barons.
local function normalizeNodeName(value)
    local text = tostring(value or "")
    local head = text:match("^([^%(%)%[%]%{%}%:%,%;%/%\\%.%!%?]+)") or text
    return head:match("^%s*(.-)%s*$") or head
end

local function kindNeedsSpot(kindKey)
    return kindKey == "log" or kindKey == "water"
end

-- Nearest captured spot of this kind in the same zone. No distance cap, matching
-- findNearestCooledTreeSpot: a zone only holds a handful of these and the player is
-- standing at one when it fires.
local function findSpot(kindKey, pos)
    local best, bestD2
    for _, spot in ipairs(spots()) do
        if spot.kind == kindKey and spot.worldX and spot.worldY then
            local sameZone = not pos.zone or not spot.zone or tostring(spot.zone) == tostring(pos.zone)
            if sameZone then
                local d2 = distance2(spot, pos)
                if not bestD2 or d2 < bestD2 then
                    best, bestD2 = spot, d2
                end
            end
        end
    end
    return best
end

local function countOfKind(kindKey)
    local count = 0
    for _, spot in ipairs(spots()) do
        if spot.kind == kindKey then count = count + 1 end
    end
    return count
end

function NodeTracker.Kinds()
    return KINDS
end

function NodeTracker.KindLabel(kindKey)
    for _, kind in ipairs(KINDS) do
        if kind.key == kindKey then return kind.label end
    end
    return tostring(kindKey or "")
end

function NodeTracker.ModifierLabel()
    return NodeTracker.MODIFIER_LABELS[NodeTracker.CaptureModifier()] or "No key"
end

function NodeTracker.SpotsOfKind(kindKey)
    local out = {}
    for _, spot in ipairs(spots()) do
        if spot.kind == kindKey then out[#out + 1] = spot end
    end
    return out
end

function NodeTracker.Timers()
    return timers()
end

-- Manual capture: saves where the player is STANDING as a named location. A spot has no
-- timer and never appears in the tracking window -- it is the anchor that later hovers
-- file their timers under.
function NodeTracker.CaptureSpot(kindKey, customName)
    if not NodeTracker.settings then return false, "Node tracker is not ready yet." end
    if NodeTracker.HasConflict() then
        return false, "Land Barons is installed and owns node tracking. Capture spots there."
    end
    if not kindNeedsSpot(kindKey) then
        return false, "Only tree trunk and mineral water use spots."
    end
    local label = NodeTracker.KindLabel(kindKey)
    local pos = capturePlayerPosition()
    if not pos then return false, "Could not read your position." end
    local existing = findSpot(kindKey, pos)
    if existing and distance2(existing, pos) <= MATCH_RADIUS2 then
        return false, string.format("Already saved here as '%s'.", tostring(existing.name or label))
    end
    local name = tostring(customName or "")
    name = name:match("^%s*(.-)%s*$") or ""
    if name == "" then
        name = string.format("%s #%d", label, countOfKind(kindKey) + 1)
    end
    table.insert(spots(), {
        kind = kindKey,
        label = label,
        name = name,
        worldX = pos.worldX,
        worldY = pos.worldY,
        zone = pos.zone,
        sextants = pos.sextants
    })
    return true
end

function NodeTracker.ForgetSpot(spotName)
    local list = spots()
    for i = #list, 1, -1 do
        if list[i].name == spotName then table.remove(list, i) end
    end
    -- Timers filed under a deleted spot have nowhere to belong.
    local tlist = timers()
    for i = #tlist, 1, -1 do
        if tlist[i].container == spotName then table.remove(tlist, i) end
    end
end

function NodeTracker.ClearKind(kindKey)
    local list = spots()
    for i = #list, 1, -1 do
        if list[i].kind == kindKey then table.remove(list, i) end
    end
    local tlist = timers()
    for i = #tlist, 1, -1 do
        if tlist[i].kind == kindKey then table.remove(tlist, i) end
    end
end

-- Clears TIMERS only; captured spots survive, which is what the tracking window's Clear
-- button should do (Land Barons' clearAutotrackerWindow does not delete spots either).
-- Delete one timer row, or a whole group (a header's Del button).
function NodeTracker.ForgetTimer(target)
    local list = timers()
    for i = #list, 1, -1 do
        if list[i] == target then table.remove(list, i) end
    end
end

function NodeTracker.ForgetGroup(key)
    local list = timers()
    for i = #list, 1, -1 do
        local entry = list[i]
        if groupKeyOf(entry) == key then
            table.remove(list, i)
        end
    end
    NodeTracker.expanded[key] = nil
end

function NodeTracker.ForgetAll()
    if NodeTracker.settings then NodeTracker.settings.nodeTimers = {} end
end

-- Record (or refresh) a hovered node. Returns changed, message.
function NodeTracker.Record(info)
    -- Not gated on the WINDOW being open: capturing is what opens it.
    if not autotracking() or NodeTracker.conflict then return false end
    if type(info) ~= "table" or not info.name then return false end
    local kind = classify(info.name)
    if not kind then return false end
    if not NodeTracker.KindEnabled(kind.key) then return false end
    if not modifierHeld() then return false end
    local displayTime = tonumber(info.displayTime) or 0
    if displayTime <= 0 then return false end

    local pos = capturePlayerPosition()
    if not pos then return false end

    local container
    if kindNeedsSpot(kind.key) then
        local spot = findSpot(kind.key, pos)
        if not spot then
            -- Exactly the Land Barons behaviour: refuse and say why. Without a captured
            -- spot there is no container for this timer.
            return false, string.format(
                "No captured %s spot in this zone. Capture the spot first in the Node Tracker window.",
                string.lower(kind.label))
        end
        container = spot.name
    else
        -- Fish schools and the gamekeeper are not fixed points: one automatic container
        -- per zone, created on demand.
        container = string.format("%s (Zone %s)", kind.label, tostring(pos.zone or "?"))
    end

    -- Backdated a full second, exactly as farmsystem does (GetUiMsec() - 500 - 500): the
    -- tooltip value is already about a second stale by the time the event reaches us, so
    -- without this every timer here runs a second fast compared to Land Barons.
    local nowMs = (safeCall(function() return api.Time:GetUiMsec() end) or 0) - 1000
    local expiry = nowUnix() + displayTime
    local sourceName = normalizeNodeName(info.name)
    local owner = tostring(info.owner or "")

    -- Dedup on REMAINING TIME within 2s, against name + owner -- farmsystem's rule. It
    -- compares the existing entry's live remaining against the newly reported one, which is
    -- millisecond-accurate, instead of comparing whole-second expiry stamps where rounding
    -- on both sides alone could drift a couple of seconds. A re-hover is ignored outright
    -- rather than refreshed; only a genuinely different node earns a row.
    local list = timers()
    for _, entry in ipairs(list) do
        if entry.container == container
            and entry.sourceName == sourceName
            and tostring(entry.owner or "") == owner then
            if math.abs(remainingSeconds(entry) - displayTime) < 2 then
                return false
            end
        end
    end

    table.insert(list, {
        kind = kind.key,
        label = kind.label,
        container = container,
        sourceName = sourceName,
        owner = owner,
        displayTime = displayTime,
        captureUiMsec = nowMs,
        captureSession = sessionId(),
        expiryUnix = expiry
    })
    -- Tracking a node pops the window open, exactly like the Land Barons autotracker.
    if NodeTracker.settings then NodeTracker.settings.nodeTrackerEnabled = true end
    return true
end

-- Drop timers that finished a while ago so the window does not fill with dead rows.
local function pruneTimers()
    local list = timers()
    for i = #list, 1, -1 do
        if remainingSeconds(list[i]) < -120 then table.remove(list, i) end
    end
end

-- ============================================================
-- TAX_TRACKER STAND-DOWN
-- ============================================================

-- GetSettings returns an empty table for an addon that is not loaded, so a non-empty
-- table means tax_tracker is present. We only stand down when its autotracker is
-- actually ON -- otherwise it is installed but not doing this job, and stepping back
-- would leave nobody tracking.
-- pairs, not next: the addon sandbox exposes only a small set of base globals
-- (print/string/table/math/pairs/ipairs/tonumber/tostring/type/pcall/xpcall/unpack/
-- getmetatable). `next`, `select`, `setmetatable` and `rawget` are NOT among them.
local function isEmptyTable(value)
    if type(value) ~= "table" then return true end
    for _ in pairs(value) do return false end
    return true
end

-- Being LOADED at all is enough to stand down completely -- not just when its autotracker
-- happens to be on. The reason is the spot store: each addon keeps its own captured
-- log/water spots and a spot saved in one is invisible to the other, so running both would
-- quietly build two divergent databases. Same reasoning as the BetterBars stand-down.
function NodeTracker.HasConflict()
    local root = safeCall(function() return api.GetSettings("tax_tracker") end)
    if type(root) ~= "table" then return false end
    -- `enabled` is the framework's own flag, and the exact condition it uses to decide
    -- whether to call an addon's OnLoad (addons.lua LoadAddons). Presence of the settings
    -- table proves nothing: InitAddons writes a branch for every addon FOUND ON DISK, so a
    -- disabled Land Barons still has a non-empty settings table and would have blocked us.
    return root.enabled == true
end

-- ============================================================
-- DOODAD LISTENER
-- ============================================================

-- Its own window with RegisterEvent, and it must NOT be hidden: hidden windows do not
-- receive events in this engine.
local function createListener()
    if NodeTracker.listener then return end
    local listener = api.Interface:CreateEmptyWindow("powerRangerNodeListener")
    function listener:OnEvent(event, ...)
        if event == "DRAW_DOODAD_TOOLTIP" then
            local info = unpack(arg)
            if type(info) == "table" then NodeTracker.lastInfo = info end
        elseif event == "DRAW_DOODAD_SIGN_TAG" then
            local tag = unpack(arg)
            if tag == nil or tag == "" then NodeTracker.lastInfo = nil end
        end
    end
    listener:SetHandler("OnEvent", listener.OnEvent)
    NodeTracker.listener = listener
end

local function setListening(on)
    if on then
        createListener()
        if NodeTracker.listener and not NodeTracker.listening then
            pcall(function() NodeTracker.listener:RegisterEvent("DRAW_DOODAD_TOOLTIP") end)
            pcall(function() NodeTracker.listener:RegisterEvent("DRAW_DOODAD_SIGN_TAG") end)
            NodeTracker.listening = true
        end
    else
        NodeTracker.lastInfo = nil
        if NodeTracker.listener and NodeTracker.listening then
            pcall(function() NodeTracker.listener:UnregisterEvent("DRAW_DOODAD_TOOLTIP") end)
            pcall(function() NodeTracker.listener:UnregisterEvent("DRAW_DOODAD_SIGN_TAG") end)
            NodeTracker.listening = false
        end
    end
end

-- ============================================================
-- WINDOW
-- ============================================================

local function applyOpacity()
    local window = NodeTracker.window
    if not window or not window.bg then return end
    local level = tonumber(NodeTracker.settings and NodeTracker.settings.nodeTrackerOpacityLevel) or 8
    level = math.max(0, math.min(10, level))
    window.bg:SetColor(0, 0, 0, 0.62 * (level / 10))
end

-- Per-kind tint on the group labels, same values farmsystem uses in
-- _applyGroupLabelColor so the two windows colour-code identically.
local KIND_COLOR = {
    fish = {0.42, 0.72, 1.00, 1.00},
    npc = {0.40, 0.92, 0.55, 1.00},
    water = {0.55, 0.90, 0.95, 1.00},
    log = {1.00, 0.90, 0.40, 1.00}
}

local function applyGroupColor(widget, kindKey)
    if not widget or not widget.style or not widget.style.SetColor then return end
    local c = KIND_COLOR[kindKey]
    if c then
        widget.style:SetColor(c[1], c[2], c[3], c[4])
    else
        widget.style:SetColor(1, 1, 1, 1)
    end
end

local function fitText(value, maxLen)
    value = tostring(value or "")
    if #value <= maxLen then return value end
    return value:sub(1, math.max(1, maxLen - 1)) .. "."
end

local function formatTime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds <= 0 then return "Ready" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%dh %02dm %02ds", h, m, s) end
    if m > 0 then return string.format("%dm %02ds", m, s) end
    return string.format("%ds", s)
end

local function makeLabel(parent, id, x, w)
    local lbl = parent:CreateChildWidget("label", id, 0, true)
    lbl:SetExtent(w, 22)
    lbl:AddAnchor("LEFT", parent, x, 0)
    if lbl.style then
        lbl.style:SetFontSize((FONT_SIZE and FONT_SIZE.SMALL) or 14)
        lbl.style:SetAlign(ALIGN.LEFT)
    end
    lbl:SetText("")
    lbl:Show(true)
    return lbl
end

-- The expand/collapse checkbutton, built with the same check_button.dds cell coords
-- farmsystem uses so it looks identical.
local function makeToggle(parent, id)
    local toggle = parent:CreateChildWidget("checkbutton", id, 0, true)
    toggle:SetExtent(18, 17)
    toggle:AddAnchor("LEFT", parent, 2, 0)
    local coords = { {0,0,18,17},{0,0,18,17},{0,0,18,17},{0,17,18,17},{18,0,18,17},{18,17,18,17} }
    local bgs = {}
    for j = 1, 6 do
        bgs[j] = toggle:CreateImageDrawable("ui/button/check_button.dds", "background")
        bgs[j]:SetExtent(16, 16)
        bgs[j]:SetCoords(coords[j][1], coords[j][2], coords[j][3], coords[j][4])
        bgs[j]:AddAnchor("CENTER", toggle, 0, 0)
    end
    toggle:SetNormalBackground(bgs[1])
    toggle:SetHighlightBackground(bgs[2])
    toggle:SetPushedBackground(bgs[3])
    toggle:SetDisabledBackground(bgs[4])
    toggle:SetCheckedBackground(bgs[5])
    toggle:SetDisabledCheckedBackground(bgs[6])
    return toggle
end

local function createWindow()
    local settings = NodeTracker.settings
    local window = api.Interface:CreateEmptyWindow("PowerRangerNodeTracker", "UIParent")
    window:SetExtent(AUTO_W, 220)
    if settings.nodeTrackerX and settings.nodeTrackerY then
        window:AddAnchor("TOPLEFT", "UIParent", settings.nodeTrackerX, settings.nodeTrackerY)
    else
        window:AddAnchor("CENTER", "UIParent", 380, -110)
    end
    local bg = window:CreateColorDrawable(0, 0, 0, 0.62, "background")
    bg:AddAnchor("TOPLEFT", window, 0, 0)
    bg:AddAnchor("BOTTOMRIGHT", window, 0, 0)
    bg:Show(true)
    window.bg = bg

    local title = window:CreateChildWidget("label", "power_ranger_node_title", 0, true)
    title:SetText("Tracking Window")
    title:SetExtent(300, 24)
    title:AddAnchor("TOPLEFT", window, 12, 10)
    if title.style then
        title.style:SetFontSize((FONT_SIZE and FONT_SIZE.LARGE) or 18)
        title.style:SetAlign(ALIGN.LEFT)
    end
    if ApplyTextColor and FONT_COLOR then pcall(function() ApplyTextColor(title, FONT_COLOR.DEFAULT) end) end
    title:Show(true)
    window.titleLbl = title

    -- Clear / Hide use the flat FARM_UI.button tone, matching ftStyleButton rather than the
    -- game's default skin. Positions are farmsystem's: -72 and -10 from TOPRIGHT.
    UiHelpers.FlatButton(window, "power_ranger_node_clear_btn", "Clear", AUTO_W - 128, 8, 56, 24, FARM_BUTTON, function()
        NodeTracker.ForgetAll()
        if NodeTracker.onChanged then NodeTracker.onChanged() end
    end)
    UiHelpers.FlatButton(window, "power_ranger_node_hide_btn", "Hide", AUTO_W - 64, 8, 54, 24, FARM_BUTTON, function()
        if NodeTracker.settings then NodeTracker.settings.nodeTrackerEnabled = false end
        if NodeTracker.onChanged then NodeTracker.onChanged() end
        window:Show(false)
    end)

    local hdr = window:CreateChildWidget("emptywidget", "power_ranger_node_header", 0, true)
    hdr:SetExtent(AUTO_W - 24, 22)
    hdr:AddAnchor("TOPLEFT", window, 12, 38)
    local hdrBg = hdr:CreateColorDrawable(0.08, 0.11, 0.16, 0.68, "background")
    hdrBg:AddAnchor("TOPLEFT", hdr, 0, 0)
    hdrBg:AddAnchor("BOTTOMRIGHT", hdr, 0, 0)
    hdrBg:Show(true)
    hdr:Show(true)
    local function headerLabel(id, text, x, w)
        local lbl = makeLabel(hdr, id, x, w)
        lbl:SetExtent(w, 20)
        lbl:SetText(text)
        if ApplyTextColor and FONT_COLOR then pcall(function() ApplyTextColor(lbl, FONT_COLOR.DEFAULT) end) end
        return lbl
    end
    headerLabel("power_ranger_node_h_loc", "Location", AUTO_LOCATION_X, AUTO_LOCATION_W)
    headerLabel("power_ranger_node_h_ent", "Entity", AUTO_ENTITY_X, AUTO_ENTITY_W)
    headerLabel("power_ranger_node_h_qty", "Qty", AUTO_QTY_X, AUTO_QTY_W)
    headerLabel("power_ranger_node_h_earliest", "Earliest", AUTO_EARLIEST_X, AUTO_TIME_W)
    headerLabel("power_ranger_node_h_latest", "Latest", AUTO_LATEST_X, AUTO_TIME_W)
    headerLabel("power_ranger_node_h_del", "Del", AUTO_W - 68, 40)

    -- Rows are pre-allocated and reconfigured per paint. farmsystem destroys and recreates
    -- them on every rebuild, which is fine at its on-demand cadence but would leak widgets
    -- here: this window repaints on a 250ms tick.
    window.rows = {}
    for i = 1, AUTO_ROWS do
        local row = window:CreateChildWidget("emptywidget", "power_ranger_node_row_" .. i, 0, true)
        row:SetExtent(AUTO_W - 24, 23)
        row:AddAnchor("TOPLEFT", window, 12, AUTO_FIRST_Y + ((i - 1) * AUTO_ROW_H))
        local rowBg = row:CreateColorDrawable(0.08, 0.10, 0.13, 0.58, "background")
        rowBg:AddAnchor("TOPLEFT", row, 0, 0)
        rowBg:AddAnchor("BOTTOMRIGHT", row, 0, 0)
        rowBg:Show(true)
        row:Show(false)

        local toggle = makeToggle(row, "power_ranger_node_exp_" .. i)
        toggle:SetHandler("OnCheckChanged", function(self)
            local key = self._groupKey
            if key then
                NodeTracker.expanded[key] = self:GetChecked() and true or nil
            end
        end)
        toggle:Show(false)

        -- Red flat button, font 10, 38x20 at the row's right edge -- ftStyleButton(FARM_UI.red, 10).
        local delBtn = UiHelpers.FlatButton(row, "power_ranger_node_del_" .. i, "Del", AUTO_W - 24 - 42, 1, 38, 20, FARM_RED, function(self)
            if self._groupKey then
                NodeTracker.ForgetGroup(self._groupKey)
            elseif self._timer then
                NodeTracker.ForgetTimer(self._timer)
            end
            if NodeTracker.onChanged then NodeTracker.onChanged() end
        end)
        delBtn:Show(false)

        window.rows[i] = {
            row = row,
            bg = rowBg,
            toggle = toggle,
            del = delBtn,
            loc = makeLabel(row, "power_ranger_node_r_loc_" .. i, AUTO_LOCATION_X, AUTO_LOCATION_W),
            ent = makeLabel(row, "power_ranger_node_r_ent_" .. i, AUTO_ENTITY_X, AUTO_ENTITY_W),
            qty = makeLabel(row, "power_ranger_node_r_qty_" .. i, AUTO_QTY_X, AUTO_QTY_W),
            earliest = makeLabel(row, "power_ranger_node_r_early_" .. i, AUTO_EARLIEST_X, AUTO_TIME_W),
            latest = makeLabel(row, "power_ranger_node_r_late_" .. i, AUTO_LATEST_X, AUTO_TIME_W),
            entryName = makeLabel(row, "power_ranger_node_r_ename_" .. i, AUTO_LOCATION_X, AUTO_ENTITY_X + AUTO_ENTITY_W - AUTO_LOCATION_X),
            entryTime = makeLabel(row, "power_ranger_node_r_etime_" .. i, AUTO_EARLIEST_X, AUTO_TIME_W + 30)
        }
    end

    -- Prev / page / Next, farmsystem's geometry and the game's default button skin.
    local prevBtn = window:CreateChildWidget("button", "power_ranger_node_prev", 0, true)
    if ApplyButtonSkin and BUTTON_BASIC then pcall(function() ApplyButtonSkin(prevBtn, BUTTON_BASIC.DEFAULT) end) end
    prevBtn:SetExtent(70, 24)
    prevBtn:AddAnchor("BOTTOMLEFT", window, 12, -10)
    prevBtn:SetText("Prev")
    prevBtn:SetHandler("OnClick", function()
        NodeTracker.page = math.max(1, NodeTracker.page - 1)
    end)
    prevBtn:Show(true)
    window.prevBtn = prevBtn

    local pageLbl = window:CreateChildWidget("label", "power_ranger_node_page", 0, true)
    pageLbl:SetExtent(80, 24)
    pageLbl:AddAnchor("BOTTOM", window, 0, -10)
    pageLbl:SetText("1 / 1")
    if pageLbl.style then
        pageLbl.style:SetFontSize((FONT_SIZE and FONT_SIZE.SMALL) or 14)
        pageLbl.style:SetAlign(ALIGN.CENTER)
    end
    if ApplyTextColor and FONT_COLOR then pcall(function() ApplyTextColor(pageLbl, FONT_COLOR.DEFAULT) end) end
    pageLbl:Show(true)
    window.pageLbl = pageLbl

    local nextBtn = window:CreateChildWidget("button", "power_ranger_node_next", 0, true)
    if ApplyButtonSkin and BUTTON_BASIC then pcall(function() ApplyButtonSkin(nextBtn, BUTTON_BASIC.DEFAULT) end) end
    nextBtn:SetExtent(70, 24)
    nextBtn:AddAnchor("BOTTOMRIGHT", window, -12, -10)
    nextBtn:SetText("Next")
    nextBtn:SetHandler("OnClick", function()
        NodeTracker.page = NodeTracker.page + 1
    end)
    nextBtn:Show(true)
    window.nextBtn = nextBtn

    window.emptyLbl = window:CreateChildWidget("label", "power_ranger_node_empty", 0, true)
    window.emptyLbl:SetExtent(AUTO_W - 24, 20)
    window.emptyLbl:AddAnchor("TOPLEFT", window, 12, AUTO_FIRST_Y)
    if window.emptyLbl.style then
        window.emptyLbl.style:SetFontSize((FONT_SIZE and FONT_SIZE.SMALL) or 14)
        window.emptyLbl.style:SetAlign(ALIGN.LEFT)
    end
    window.emptyLbl:Show(false)

    if window.EnableDrag then window:EnableDrag(true) end
    if window.RegisterForDrag then window:RegisterForDrag("LeftButton") end
    window:SetHandler("OnDragStart", function()
        if window.StartMoving then window:StartMoving() end
        if api.Cursor and api.Cursor.ClearCursor then api.Cursor:ClearCursor() end
    end)
    local function stopDrag()
        if window.StopMovingOrSizing then window:StopMovingOrSizing() end
        if api.Cursor and api.Cursor.ClearCursor then api.Cursor:ClearCursor() end
        if window.GetEffectiveOffset and NodeTracker.settings then
            local x, y = window:GetEffectiveOffset()
            if tonumber(x) and tonumber(y) then
                NodeTracker.settings.nodeTrackerX = math.floor(tonumber(x) + 0.5)
                NodeTracker.settings.nodeTrackerY = math.floor(tonumber(y) + 0.5)
                if NodeTracker.onChanged then NodeTracker.onChanged() end
            end
        end
    end
    window:SetHandler("OnDragStop", stopDrag)
    window:SetHandler("OnDragEnd", stopDrag)

    NodeTracker.window = window
    applyOpacity()
end

local function rebuildWindow()
    if not NodeTracker.window then return end
    pcall(function() NodeTracker.window:Show(false) end)
    pcall(function() api.Interface:Free(NodeTracker.window) end)
    NodeTracker.window = nil
end

-- Flat render list of header rows with their (optional) expanded entry rows, exactly the
-- shape farmsystem's buildAutotrackerRenderList produces. Grouped by container + entity
-- name, so every trunk at one spot collapses under a single openable header.
local function buildRenderList()
    local order, groups = {}, {}
    for _, entry in ipairs(timers()) do
        local key = groupKeyOf(entry)
        if not groups[key] then
            groups[key] = { key = key, container = entry.container, name = entry.sourceName,
                owner = entry.owner, kind = entry.kind, label = entry.label, entries = {} }
            order[#order + 1] = key
        end
        table.insert(groups[key].entries, entry)
    end
    local rows = {}
    for _, key in ipairs(order) do
        local group = groups[key]
        rows[#rows + 1] = { type = "header", group = group }
        if NodeTracker.expanded[key] then
            local sorted = {}
            for _, entry in ipairs(group.entries) do sorted[#sorted + 1] = entry end
            table.sort(sorted, function(a, b) return remainingSeconds(a) < remainingSeconds(b) end)
            for _, entry in ipairs(sorted) do
                rows[#rows + 1] = { type = "entry", group = group, entry = entry }
            end
        end
    end
    return rows
end

local function groupExtreme(group, kind)
    local val = nil
    for _, entry in ipairs(group.entries) do
        local t = remainingSeconds(entry)
        if kind == "earliest" then
            if val == nil or t < val then val = t end
        else
            if val == nil or t > val then val = t end
        end
    end
    return val
end

local function paint()
    if not NodeTracker.window then createWindow() end
    local window = NodeTracker.window
    pruneTimers()
    local rows = buildRenderList()

    window.titleLbl:SetText(autotracking() and "Tracking Window" or "Tracking Window (Paused)")

    if #rows == 0 then
        window:SetExtent(AUTO_W, 125)
        window.emptyLbl:SetText(autotracking() and "Waiting for hover..." or "Autotracker is off")
        window.emptyLbl:Show(true)
        window.pageLbl:SetText("1 / 1")
        if window.prevBtn.Enable then window.prevBtn:Enable(false) end
        if window.nextBtn.Enable then window.nextBtn:Enable(false) end
        for i = 1, AUTO_ROWS do window.rows[i].row:Show(false) end
        window:Show(true)
        return
    end

    window.emptyLbl:Show(false)
    local totalPages = math.max(1, math.ceil(#rows / AUTO_ROWS))
    if NodeTracker.page > totalPages then NodeTracker.page = totalPages end
    if NodeTracker.page < 1 then NodeTracker.page = 1 end
    window.pageLbl:SetText(string.format("%d / %d", NodeTracker.page, totalPages))
    if window.prevBtn.Enable then window.prevBtn:Enable(NodeTracker.page > 1) end
    if window.nextBtn.Enable then window.nextBtn:Enable(NodeTracker.page < totalPages) end
    local startIdx = ((NodeTracker.page - 1) * AUTO_ROWS) + 1
    local endIdx = math.min(startIdx + AUTO_ROWS - 1, #rows)
    local visible = math.max(1, endIdx - startIdx + 1)
    window:SetExtent(AUTO_W, 110 + (visible * AUTO_ROW_H))

    for i = 1, AUTO_ROWS do
        local ui = window.rows[i]
        local item = rows[startIdx + i - 1]
        if not item then
            ui.row:Show(false)
        elseif item.type == "header" then
            local group = item.group
            ui.bg:SetColor(0.08, 0.10, 0.13, 0.58)
            ui.toggle._groupKey = group.key
            ui.toggle:SetChecked(NodeTracker.expanded[group.key] and true or false)
            ui.toggle:Show(true)
            ui.loc:SetText(fitText(group.container, 31))
            ui.ent:SetText(fitText(group.name, 22))
            ui.qty:SetText("x" .. tostring(#group.entries))
            ui.earliest:SetText(formatTime(groupExtreme(group, "earliest") or 0))
            ui.latest:SetText(formatTime(groupExtreme(group, "latest") or 0))
            applyGroupColor(ui.loc, group.kind)
            applyGroupColor(ui.ent, group.kind)
            ui.loc:Show(true) ui.ent:Show(true) ui.qty:Show(true)
            ui.earliest:Show(true) ui.latest:Show(true)
            ui.entryName:Show(false) ui.entryTime:Show(false)
            ui.del._groupKey = group.key
            ui.del._timer = nil
            ui.del:Show(true)
            ui.row:Show(true)
        else
            ui.bg:SetColor(0.02, 0.02, 0.02, 0.35)
            ui.toggle:Show(false)
            ui.loc:Show(false) ui.ent:Show(false) ui.qty:Show(false)
            ui.earliest:Show(false) ui.latest:Show(false)
            ui.entryName:SetText("  " .. fitText(item.entry.sourceName, 48))
            ui.entryTime:SetText(formatTime(remainingSeconds(item.entry)))
            ui.entryName:Show(true) ui.entryTime:Show(true)
            ui.del._groupKey = nil
            ui.del._timer = item.entry
            ui.del:Show(true)
            ui.row:Show(true)
        end
    end
    window:Show(true)
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

function NodeTracker.Init(settings, applyDrag)
    NodeTracker.settings = settings
    NodeTracker.applyDrag = applyDrag
    NodeTracker.elapsed = UPDATE_MS
    NodeTracker.announced = {}
    NodeTracker.Refresh()
end

function NodeTracker.Update(dt)
    if not NodeTracker.settings then return end
    NodeTracker.elapsed = NodeTracker.elapsed + (tonumber(dt) or 0)
    if NodeTracker.elapsed < UPDATE_MS then return end
    NodeTracker.elapsed = 0
    NodeTracker.conflict = NodeTracker.HasConflict()
    if NodeTracker.conflict then
        if NodeTracker.window then NodeTracker.window:Show(false) end
        setListening(false)
        return
    end
    -- Only listen while autotracking: a paused tracker keeps its window but stops turning
    -- hovers into nodes, and there is no point holding the event subscription.
    setListening(autotracking())
    -- Recording runs BEFORE the window check so a capture can pop the window open even when
    -- it was closed -- which is the Land Barons behaviour.
    if NodeTracker.lastInfo then
        local changed, message = NodeTracker.Record(NodeTracker.lastInfo)
        NodeTracker.lastInfo = nil
        if changed and NodeTracker.onChanged then NodeTracker.onChanged() end
        -- Same message once per zone-visit, not once per hover frame.
        if message and message ~= NodeTracker.lastMessage and NodeTracker.onMessage then
            NodeTracker.lastMessage = message
            NodeTracker.onMessage(message)
        elseif changed then
            NodeTracker.lastMessage = nil
        end
    end
    if not enabled() then
        if NodeTracker.window then NodeTracker.window:Show(false) end
        return
    end
    paint()
end

function NodeTracker.Refresh()
    NodeTracker.conflict = NodeTracker.HasConflict()
    if not enabled() or NodeTracker.conflict then
        if NodeTracker.window then NodeTracker.window:Show(false) end
        setListening(false)
        return
    end
    if NodeTracker.window and NodeTracker.window.builtScale ~= scaleLevel() then rebuildWindow() end
    applyOpacity()
    setListening(autotracking())
end

function NodeTracker.Cleanup()
    setListening(false)
    if NodeTracker.window then NodeTracker.window:Show(false) end
    NodeTracker.window = nil
    NodeTracker.listener = nil
    NodeTracker.settings = nil
    NodeTracker.applyDrag = nil
    NodeTracker.lastInfo = nil
    NodeTracker.announced = {}
end

return NodeTracker
