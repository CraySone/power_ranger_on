-- Node Tracker's own settings window.
--
-- Everything node-related lives here rather than in the main settings shell: that window is
-- already ~1360px tall and another full section would push it past a 1080p screen. This
-- follows the addon's existing pattern for sub-features (cooldown managers, detected skills,
-- stats picker all get their own window).
--
-- The spot panels are a direct port of the Land Barons "Cooled Tree Trunk Spots" /
-- "Dried Up Mineral Water Spots" blocks: a count line, a name edit, then
-- Capture Spot / List Spots / Clear Spots. Capture saves where you are STANDING, which is
-- how fixed-location nodes get remembered independently of hover autotracking.

local api = require("api")
local UiHelpers = require("power_ranger_on/ui_helpers")
local NodeTracker = require("power_ranger_on/node_tracker")

local NodeWindow = {
    window = nil,
    listWindow = nil,
    listKind = nil,
    edits = {},
    labels = {},
    buttons = {},
    ctx = nil
}

local W = 520
local H = 560
local LIST_W = 520
local LIST_H = 420
local LIST_ROWS = 12

-- Kinds that support manual spot capture. Fish schools roam, so they are hover-only.
local SPOT_KINDS = {
    { key = "log", title = "Cooled Tree Trunk Spots" },
    { key = "water", title = "Dried Up Mineral Water Spots" }
}

local function colors()
    return (NodeWindow.ctx and NodeWindow.ctx.colors) or {}
end

local function save()
    if NodeWindow.ctx and NodeWindow.ctx.saveSettings then NodeWindow.ctx.saveSettings() end
end

local function settings()
    return NodeWindow.ctx and NodeWindow.ctx.settings or nil
end

local function makeEdit(parent, id, x, y, w, h)
    local edit
    if W_CTRL and W_CTRL.CreateEdit then
        edit = W_CTRL.CreateEdit(id, parent)
    else
        edit = parent:CreateChildWidget("edit", id, 0, true)
    end
    edit:SetExtent(w, h)
    edit:AddAnchor("TOPLEFT", parent, x, y)
    edit:SetText("")
    edit:Show(true)
    return edit
end

-- ============================================================
-- SPOT LIST WINDOW
-- ============================================================

function NodeWindow.RebuildList()
    local wnd = NodeWindow.listWindow
    if not wnd then return end
    local kind = NodeWindow.listKind
    local list = NodeTracker.SpotsOfKind(kind)
    wnd.titleLbl:SetText(string.format("%s spots (%d)", NodeTracker.KindLabel(kind), #list))
    for i = 1, LIST_ROWS do
        local row = wnd.rows[i]
        local spot = list[i]
        if spot then
            row.name:SetText(tostring(spot.name or ""))
            local where = spot.sextants
            if where == nil or where == "" then where = "Zone " .. tostring(spot.zone or "?") end
            row.where:SetText(where)
            row.del._spotName = spot.name
            row.name:Show(true)
            row.where:Show(true)
            row.del:Show(true)
        else
            row.name:Show(false)
            row.where:Show(false)
            row.del:Show(false)
        end
    end
    wnd:Show(true)
end

function NodeWindow.OpenList(kind)
    NodeWindow.listKind = kind
    if not NodeWindow.listWindow then
        local ctx = NodeWindow.ctx
        local wnd = require("power_ranger_on/settings_ui").CreateShell({
            id = "PowerRangerNodeSpotList",
            title = "Node Spots",
            width = LIST_W,
            height = LIST_H,
            x = 560,
            y = 260,
            xKey = "nodeSpotListX",
            yKey = "nodeSpotListY",
            colors = ctx.colors,
            safePosition = ctx.safePosition,
            applyDrag = ctx.applyDrag,
            onClose = function() NodeWindow.listWindow:Show(false) end
        })
        wnd.titleLbl = UiHelpers.Label(wnd, "power_ranger_node_list_count", "", 16, 44, 360, 16, 11, colors().gold, ALIGN.LEFT)
        wnd.rows = {}
        for i = 1, LIST_ROWS do
            local y = 68 + ((i - 1) * 26)
            wnd.rows[i] = {
                name = UiHelpers.Label(wnd, "power_ranger_node_list_name_" .. i, "", 16, y + 4, 150, 16, 10, colors().white, ALIGN.LEFT),
                where = UiHelpers.Label(wnd, "power_ranger_node_list_where_" .. i, "", 172, y + 4, 260, 16, 10, colors().muted, ALIGN.LEFT),
                del = UiHelpers.FlatButton(wnd, "power_ranger_node_list_del_" .. i, "X", W - 68, y, 24, 20, colors().red or {0.42, 0.10, 0.10, 0.95}, function(self)
                    if self._spotName then
                        NodeTracker.ForgetSpot(self._spotName)
                        save()
                        NodeWindow.RebuildList()
                        NodeWindow.Refresh()
                    end
                end, colors())
            }
        end
        NodeWindow.listWindow = wnd
    end
    NodeWindow.RebuildList()
end

-- ============================================================
-- MAIN WINDOW
-- ============================================================

function NodeWindow.Refresh()
    local wnd = NodeWindow.window
    if not wnd then return end
    local s = settings()
    if not s then return end
    local conflict = NodeTracker.HasConflict()
    local setToggle = NodeWindow.ctx.setToggleButton

    if conflict then
        NodeWindow.buttons.autotrack:SetCleanText("Land Barons")
        NodeWindow.buttons.autotrack:SetTone(colors().blue)
        NodeWindow.buttons.window:SetCleanText("handles nodes")
        NodeWindow.buttons.window:SetTone(colors().button)
    else
        setToggle(NodeWindow.buttons.autotrack, s.nodeAutotrackEnabled == true, "Autotracker")
        setToggle(NodeWindow.buttons.window, s.nodeTrackerEnabled == true, "Tracking window")
    end
    setToggle(NodeWindow.buttons.float, s.nodeFloatButton == true, "Float button")
    NodeWindow.buttons.modifier:SetCleanText("Capture: " .. NodeTracker.ModifierLabel())
    NodeWindow.buttons.modifier:SetTone(colors().blue)
    for _, kind in ipairs(NodeTracker.Kinds()) do
        local btn = NodeWindow.buttons["kind_" .. kind.key]
        if btn then setToggle(btn, NodeTracker.KindEnabled(kind.key), kind.label) end
    end
    for _, spec in ipairs(SPOT_KINDS) do
        local lbl = NodeWindow.labels["count_" .. spec.key]
        if lbl then
            lbl:SetText(string.format("%d saved spot(s)", #NodeTracker.SpotsOfKind(spec.key)))
        end
    end
end

local function buildSpotPanel(wnd, ctx, spec, y)
    local p = ctx.sectionPanel(wnd, "power_ranger_node_spot_" .. spec.key, 14, y, W - 28, 128, spec.title)
    NodeWindow.labels["count_" .. spec.key] = ctx.label(p, "power_ranger_node_spot_count_" .. spec.key, "", 16, 30, 400, 14, 10, colors().white, ALIGN.LEFT)
    ctx.label(p, "power_ranger_node_spot_namelbl_" .. spec.key, "Spot name", 16, 58, 70, 14, 10, colors().muted, ALIGN.LEFT)
    local plate = p:CreateColorDrawable(0.02, 0.02, 0.03, 0.92, "background")
    plate:SetExtent(268, 26)
    plate:AddAnchor("TOPLEFT", p, 92, 54)
    plate:Show(true)
    NodeWindow.edits[spec.key] = makeEdit(p, "power_ranger_node_spot_edit_" .. spec.key, 96, 56, 260, 22)

    ctx.flatButton(p, "power_ranger_node_spot_capture_" .. spec.key, "Capture Spot", 16, 92, 118, 22, colors().active, function()
        local edit = NodeWindow.edits[spec.key]
        local name = edit and edit.GetText and edit:GetText() or ""
        local ok, why = NodeTracker.CaptureSpot(spec.key, name)
        if not ok and ctx.notify then ctx.notify(why or "Could not capture this spot.", true) end
        if ok and edit and edit.SetText then edit:SetText("") end
        save()
        NodeWindow.Refresh()
        if NodeWindow.listWindow and NodeWindow.listKind == spec.key then NodeWindow.RebuildList() end
    end)
    ctx.flatButton(p, "power_ranger_node_spot_list_" .. spec.key, "List Spots", 142, 92, 100, 22, colors().button, function()
        NodeWindow.OpenList(spec.key)
    end)
    ctx.flatButton(p, "power_ranger_node_spot_clear_" .. spec.key, "Clear Spots", 250, 92, 100, 22, colors().red or {0.42, 0.10, 0.10, 0.95}, function()
        NodeTracker.ClearKind(spec.key)
        save()
        NodeWindow.Refresh()
        if NodeWindow.listWindow and NodeWindow.listKind == spec.key then NodeWindow.RebuildList() end
    end)
    return p
end

function NodeWindow.Open(ctx)
    NodeWindow.ctx = ctx
    if NodeWindow.window then
        NodeWindow.Refresh()
        NodeWindow.window:Show(true)
        return
    end
    local s = ctx.settings
    local wnd = require("power_ranger_on/settings_ui").CreateShell({
        id = "PowerRangerNodeSettings",
        title = "Node Tracker",
        width = W,
        height = H,
        x = s.nodeSettingsX or 520,
        y = s.nodeSettingsY or 200,
        xKey = "nodeSettingsX",
        yKey = "nodeSettingsY",
        colors = ctx.colors,
        safePosition = ctx.safePosition,
        applyDrag = ctx.applyDrag,
        onClose = function() NodeWindow.window:Show(false) end
    })

    local p = ctx.sectionPanel(wnd, "power_ranger_node_opts", 14, 44, W - 28, 148, "Tracking")
    NodeWindow.buttons.autotrack = ctx.flatButton(p, "power_ranger_node_w_autotrack", "", 16, 30, 150, 22, colors().active, function()
        if NodeTracker.HasConflict() then return end
        s.nodeAutotrackEnabled = not (s.nodeAutotrackEnabled == true)
        NodeTracker.Refresh()
        save()
        NodeWindow.Refresh()
        if ctx.refreshClientOptionButtons then ctx.refreshClientOptionButtons() end
    end)
    NodeWindow.buttons.window = ctx.flatButton(p, "power_ranger_node_w_window", "", 174, 30, 150, 22, colors().active, function()
        if NodeTracker.HasConflict() then return end
        s.nodeTrackerEnabled = not (s.nodeTrackerEnabled == true)
        NodeTracker.Refresh()
        save()
        NodeWindow.Refresh()
    end)
    NodeWindow.buttons.float = ctx.flatButton(p, "power_ranger_node_w_float", "", 332, 30, 150, 22, colors().active, function()
        s.nodeFloatButton = not (s.nodeFloatButton == true)
        save()
        NodeWindow.Refresh()
        if ctx.refreshClientOptionButtons then ctx.refreshClientOptionButtons() end
    end)

    ctx.label(p, "power_ranger_node_w_modlbl", "Capture key", 16, 66, 90, 14, 10, colors().muted, ALIGN.LEFT)
    NodeWindow.buttons.modifier = ctx.flatButton(p, "power_ranger_node_w_mod", "", 112, 62, 212, 22, colors().blue, function()
        NodeTracker.CycleCaptureModifier()
        save()
        NodeWindow.Refresh()
    end)
    ctx.flatButton(p, "power_ranger_node_w_clearall", "Clear timers", 332, 62, 150, 22, colors().red or {0.42, 0.10, 0.10, 0.95}, function()
        NodeTracker.ForgetAll()
        save()
        NodeWindow.Refresh()
        if NodeWindow.listWindow then NodeWindow.RebuildList() end
    end)

    ctx.label(p, "power_ranger_node_w_kindlbl", "Capture types", 16, 102, 90, 14, 10, colors().muted, ALIGN.LEFT)
    local x = 112
    for _, kind in ipairs(NodeTracker.Kinds()) do
        NodeWindow.buttons["kind_" .. kind.key] = ctx.flatButton(p, "power_ranger_node_w_kind_" .. kind.key, "", x, 98, 88, 22, colors().active, function()
            NodeTracker.ToggleKind(kind.key)
            save()
            NodeWindow.Refresh()
        end)
        x = x + 94
    end

    buildSpotPanel(wnd, ctx, SPOT_KINDS[1], 200)
    buildSpotPanel(wnd, ctx, SPOT_KINDS[2], 336)

    ctx.label(wnd, "power_ranger_node_w_hint", "Capture Spot saves where you are STANDING. Hover tracking fills timers.", 20, 478, W - 40, 14, 10, colors().muted, ALIGN.LEFT)

    NodeWindow.window = wnd
    NodeWindow.Refresh()
    wnd:Show(true)
end

function NodeWindow.Cleanup()
    if NodeWindow.window then NodeWindow.window:Show(false) end
    if NodeWindow.listWindow then NodeWindow.listWindow:Show(false) end
    NodeWindow.window = nil
    NodeWindow.listWindow = nil
    NodeWindow.edits = {}
    NodeWindow.labels = {}
    NodeWindow.buttons = {}
    NodeWindow.ctx = nil
end

return NodeWindow
