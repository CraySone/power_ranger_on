-- Big skill icon over the character when a tracked cooldown finishes.
--
-- Deliberately its own module rather than a hook into weapon_proc's popup: that one only
-- animates while WeaponProc.Update runs, which is gated on the weapon proc being enabled,
-- so reusing it would have tied cooldown alerts to an unrelated setting.
--
-- Icon only, no label -- the point is to recognise the skill at a glance. Several
-- cooldowns can finish on the same tick, so alerts queue instead of overwriting each
-- other, and one widget is reused for the whole queue.

local api = require("api")
local IconWidgets = require("power_ranger_on/icon_widgets")

local ReadyPopup = {
    settings = nil,
    window = nil,
    icon = nil,
    queue = {},
    current = nil,
    startedAt = nil,
    applyDrag = nil,
    moveMode = false
}

local POPUP_MS = 1500
local BASE_SIZE = 72
local MAX_QUEUE = 4

-- Must forward THREE results: GetUnitScreenPosition returns x, y, z and a single-value
-- wrapper silently dropped y/z, so the over-the-character branch could never be taken.
local function safeCall(fn)
    local ok, a, b, c = pcall(fn)
    if ok then return a, b, c end
    return nil
end

local function now()
    return tonumber(safeCall(function() return api.Time:GetUiMsec() end)) or 0
end

local function enabled()
    return ReadyPopup.settings ~= nil and ReadyPopup.settings.cooldownReadyPopup == true
end

local function scaleLevel()
    return math.max(0, math.min(6, tonumber(ReadyPopup.settings and ReadyPopup.settings.cooldownReadyPopupScale) or 0))
end

local function iconSize()
    return math.floor((BASE_SIZE * (1 + (scaleLevel() * 0.3))) + 0.5)
end

-- Click-through in normal use, pickable in Move mode.
--
-- These two calls are what make the popup ignore clicks over the world -- but they apply to
-- the WHOLE window, so while they are set its own drag handle can never receive a press
-- either. Setting them once at creation is what stopped this popup being draggable: the
-- handle appeared in Move mode and did nothing. Move mode has to lift them and restore them.
local function applyPickState(window, moveMode)
    if not window then return end
    if window.Clickable then pcall(function() window:Clickable(moveMode == true) end) end
    if window.EnablePick then pcall(function() window:EnablePick(moveMode == true) end) end
end

local function createWindow()
    local settings = ReadyPopup.settings or {}
    local size = iconSize()
    local window = api.Interface:CreateEmptyWindow("PowerRangerCooldownReady", "UIParent")
    window:SetExtent(size, size)
    -- Anchored to a saved screen position rather than to the character, so it can be put
    -- wherever it is actually visible mid-fight. Drag it in Move mode.
    window:AddAnchor("TOPLEFT", "UIParent", settings.cooldownReadyPopupX or 700, settings.cooldownReadyPopupY or 420)
    -- Sits over the world during a fight and must not swallow clicks -- except in Move mode.
    applyPickState(window, ReadyPopup.moveMode)
    -- No addBg: a plate behind the icon would just be a grey box over the world.
    ReadyPopup.icon = IconWidgets.Create(window, "power_ranger_cooldown_ready_icon", 0, 0, size, nil)
    if ReadyPopup.icon.Clickable then ReadyPopup.icon:Clickable(false) end
    if ReadyPopup.icon.EnablePick then ReadyPopup.icon:EnablePick(false) end
    -- applyDrag forces Clickable(true) on the handle, so it is only shown in Move mode --
    -- otherwise this rectangle would eat every click over the icon (same trap as the guild
    -- label's full-size drag handle).
    window.dragHandle = window:CreateChildWidget("emptywidget", "power_ranger_cd_popup_drag", 0, true)
    window.dragHandle:SetExtent(size, size)
    window.dragHandle:AddAnchor("TOPLEFT", window, 0, 0)
    window.dragHandle:Show(false)
    if ReadyPopup.applyDrag then
        ReadyPopup.applyDrag(window, window.dragHandle, "cooldownReadyPopupX", "cooldownReadyPopupY")
    end
    window:Show(false)
    window.builtScale = scaleLevel()
    ReadyPopup.window = window
end

function ReadyPopup.Init(settings, applyDrag)
    ReadyPopup.settings = settings
    ReadyPopup.applyDrag = applyDrag
    ReadyPopup.queue = {}
    ReadyPopup.current = nil
    ReadyPopup.moveMode = false
end

-- Move mode pins the popup on screen with a sample icon so it can be dragged; the 1.5s
-- lifetime of a real alert is far too short to grab. Toggling it off saves the position.
function ReadyPopup.SetMoveMode(on)
    ReadyPopup.moveMode = on == true
    applyPickState(ReadyPopup.window, ReadyPopup.moveMode)
    if not ReadyPopup.moveMode then
        ReadyPopup.current = nil
        ReadyPopup.queue = {}
        if ReadyPopup.window then ReadyPopup.window:Show(false) end
    end
end

function ReadyPopup.IsMoveMode()
    return ReadyPopup.moveMode == true
end

-- Fires the popup with a known-good icon so the alert path can be proven independently of
-- the cooldown runtime. If nothing appears the popup is at fault; if this works but real
-- cooldowns stay silent the problem is upstream in announceReady.
function ReadyPopup.Test()
    if not enabled() then return false end
    ReadyPopup.current = nil
    ReadyPopup.queue = {}
    ReadyPopup.Show("__test__", "Game\\ui\\icon\\icon_skill_karon01.dds")
    return true
end

-- Called from the cooldown runtime the moment a row goes ready. iconPath is what gets
-- shown; a cooldown with no resolvable icon is skipped rather than flashing an empty box.
function ReadyPopup.Show(name, iconPath)
    if not enabled() then return end
    local path = iconPath and tostring(iconPath) or ""
    if path == "" then return end
    local key = tostring(name or path)
    if ReadyPopup.current == key then return end
    for _, queued in ipairs(ReadyPopup.queue) do
        if queued.key == key then return end
    end
    if #ReadyPopup.queue >= MAX_QUEUE then return end
    ReadyPopup.queue[#ReadyPopup.queue + 1] = { key = key, path = path }
end

local function beginNext(currentTime)
    local entry = table.remove(ReadyPopup.queue, 1)
    if not entry then return false end
    if not ReadyPopup.window or ReadyPopup.window.builtScale ~= scaleLevel() then
        if ReadyPopup.window then
            pcall(function() ReadyPopup.window:Show(false) end)
            pcall(function() api.Interface:Free(ReadyPopup.window) end)
            ReadyPopup.window = nil
            ReadyPopup.icon = nil
        end
        createWindow()
    end
    ReadyPopup.current = entry.key
    ReadyPopup.startedAt = currentTime
    IconWidgets.Set(ReadyPopup.icon, entry.path)
    ReadyPopup.window:Show(true)
    return true
end

function ReadyPopup.Update(dt)
    if not enabled() then
        if ReadyPopup.window then ReadyPopup.window:Show(false) end
        ReadyPopup.current = nil
        if #ReadyPopup.queue > 0 then ReadyPopup.queue = {} end
        return
    end
    local currentTime = now()
    local size = iconSize()

    -- Move mode: pinned, fully opaque, draggable. No timer, no fade.
    if ReadyPopup.moveMode then
        if not ReadyPopup.window or ReadyPopup.window.builtScale ~= scaleLevel() then
            if ReadyPopup.window then
                pcall(function() ReadyPopup.window:Show(false) end)
                pcall(function() api.Interface:Free(ReadyPopup.window) end)
                ReadyPopup.window = nil
                ReadyPopup.icon = nil
            end
            createWindow()
        end
        IconWidgets.Set(ReadyPopup.icon, "Game\ui\icon\icon_skill_karon01.dds")
        if ReadyPopup.window.SetAlpha then pcall(function() ReadyPopup.window:SetAlpha(1) end) end
        if ReadyPopup.icon then ReadyPopup.icon:SetExtent(size, size) end
        ReadyPopup.window:SetExtent(size, size)
        if ReadyPopup.window.dragHandle then
            ReadyPopup.window.dragHandle:SetExtent(size, size)
            ReadyPopup.window.dragHandle:Show(true)
        end
        ReadyPopup.window:Show(true)
        return
    end

    if not ReadyPopup.current then
        if not beginNext(currentTime) then return end
    end
    local window = ReadyPopup.window
    if not window then return end
    local progress = 0
    if ReadyPopup.startedAt then
        progress = math.max(0, math.min(1, (currentTime - ReadyPopup.startedAt) / POPUP_MS))
    end
    if progress >= 1 then
        ReadyPopup.current = nil
        if not beginNext(currentTime) then window:Show(false) end
        return
    end
    -- Late fade only; the position is fixed, so no rise animation to fight the anchor.
    local fadeStart = 0.62
    local alpha = 1
    if progress > fadeStart then
        alpha = math.max(0, 1 - ((progress - fadeStart) / (1 - fadeStart)))
    end
    if window.SetAlpha then pcall(function() window:SetAlpha(alpha) end) end
    if ReadyPopup.icon then ReadyPopup.icon:SetExtent(size, size) end
    window:SetExtent(size, size)
    if window.dragHandle then window.dragHandle:Show(false) end
    window:Show(true)
end

function ReadyPopup.Cleanup()
    if ReadyPopup.window then ReadyPopup.window:Show(false) end
    ReadyPopup.window = nil
    ReadyPopup.icon = nil
    ReadyPopup.settings = nil
    ReadyPopup.queue = {}
    ReadyPopup.current = nil
    ReadyPopup.startedAt = nil
    ReadyPopup.applyDrag = nil
    ReadyPopup.moveMode = false
end

return ReadyPopup
