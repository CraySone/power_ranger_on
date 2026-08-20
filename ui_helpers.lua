-- Power Ranger UI adapter for AddonUILib.
--
-- This file holds NO implementation. It exists because this addon predates the shared
-- library and has ~120 call sites written against the old `UiHelpers.*` names; the adapter
-- maps those names onto AddonUILib so none of them had to change.
--
-- A NEW addon does not need a file like this. It calls AddonUILib directly:
--
--     local ok, AddonUILib = pcall(require, "AddonUILib/init")
--     local ui = ok and AddonUILib.For("MyAddon", { accent = AddonUILib.ACCENT.cyan })
--     ui.Label(panel, "my_label", "Hello", 10, 10, 120, 14, 11, ui.colors.muted, ALIGN.LEFT)
--
-- See AddonUILib/ADAPTERS.md for the migration pattern and a name-mapping table.

local api = require("api")

local UiHelpers = {}

-- pcall: require RAISES when the folder is missing, and an unguarded raise here would fail
-- this addon's OnLoad entirely. Failing loudly beats failing silently -- a missing library
-- used to fall back to a duplicate local copy, which meant nobody noticed it was gone.
local ok, AddonUILib = pcall(require, "AddonUILib/init")
if not ok or type(AddonUILib) ~= "table" then
    AddonUILib = nil
    pcall(function()
        api.Log:Err("[Power Ranger ON] AddonUILib is missing or failed to load. Install the AddonUILib folder; UI will not render correctly without it.")
    end)
end

UiHelpers.library = AddonUILib
UiHelpers.libraryVersion = AddonUILib and AddonUILib.VERSION or nil

-- The one place this addon picks its colour. Change the accent here and every section
-- title, panel stripe and highlight follows.
local ui = AddonUILib and AddonUILib.For("power_ranger_on", { accent = AddonUILib.ACCENT.gold }) or nil
UiHelpers.ui = ui

-- Call sites that pass an explicit palette keep winning; the bound accent palette is only
-- the default. That is what makes adopting the library a visual no-op here.
local function palette(colors)
    if type(colors) == "table" then return colors end
    return ui and ui.colors or {}
end

-- No-op stand-ins so a missing library degrades to "nothing renders" rather than a hard
-- crash mid-layout. Every function below returns nil in that state.
local function unavailable() return nil end

-- Re-lays every device-pixel line the library drew, if the UI scale has changed since the
-- last pass. This window is built during OnLoad, when GetUIScale() still reads 1, so every
-- border in it was laid at the wrong scale until this runs. Cheap when nothing changed.
-- Returns: didRelay, scale, registeredCount
function UiHelpers.RefreshScale()
    if not AddonUILib then return false, 1, 0 end
    return AddonUILib.Core.RefreshPx()
end

-- Rejects NaN and infinity. tonumber() accepts NaN and `if x then` passes it, so every
-- ordinary guard lets it through -- and NaN is contagious, so one bad sample entering a
-- running average poisons it for the rest of the session.
function UiHelpers.Finite(v)
    if not AddonUILib then
        v = tonumber(v)
        if v == nil or v ~= v or v >= 1e308 or v <= -1e308 then return nil end
        return v
    end
    return AddonUILib.Core.Finite(v)
end

function UiHelpers.SetTextColor(widget, color)
    if not AddonUILib then return unavailable() end
    return AddonUILib.Core.SetTextColor(widget, color)
end

function UiHelpers.AddBg(parent, r, g, b, a)
    if not AddonUILib then return unavailable() end
    return AddonUILib.Core.AddBg(parent, r, g, b, a)
end

function UiHelpers.Label(parent, id, text, x, y, w, h, size, color, align)
    if not AddonUILib then return unavailable() end
    return AddonUILib.Text.Label(parent, id, text, x, y, w, h, size, color, align)
end

function UiHelpers.ChildLabel(parent, id, text, x, y, w, h, size, color, align)
    if not AddonUILib then return unavailable() end
    return AddonUILib.Text.ChildLabel(parent, id, text, x, y, w, h, size, color, align)
end

function UiHelpers.FlatButton(parent, id, text, x, y, w, h, tone, onClick, colors)
    if not AddonUILib then return unavailable() end
    return AddonUILib.Button.Flat(parent, id, text, x, y, w, h, tone, onClick, palette(colors))
end

function UiHelpers.ChildFlatButton(parent, id, text, x, y, w, h, tone, onClick, colors, align)
    if not AddonUILib then return unavailable() end
    return AddonUILib.Button.ChildFlat(parent, id, text, x, y, w, h, tone, onClick, palette(colors), align)
end

function UiHelpers.Panel(parent, id, x, y, w, h, colors)
    if not AddonUILib then return unavailable() end
    return AddonUILib.Panel.Plain(parent, id, x, y, w, h, palette(colors))
end

function UiHelpers.SectionPanel(parent, id, x, y, w, h, titleText, colors)
    if not AddonUILib then return unavailable() end
    return AddonUILib.Panel.Section(parent, id, x, y, w, h, titleText, palette(colors))
end

function UiHelpers.SetToggleButton(btn, enabled, text, colors)
    if not AddonUILib then return unavailable() end
    return AddonUILib.Button.SetToggle(btn, enabled, text, palette(colors))
end

-- Slider.Create builds the track, fill, steppers and value label as one control, so it
-- replaces five hand-placed widgets per row. It also owns the click-to-set geometry, which
-- is what the local registerSlider stamping existed to work around.
function UiHelpers.Slider(parent, id, x, y, w, opts)
    if not AddonUILib then return unavailable() end
    opts = type(opts) == "table" and opts or {}
    if opts.colors == nil then opts.colors = ui and ui.colors or {} end
    return AddonUILib.Slider.Create(parent, id, x, y, w, opts)
end

function UiHelpers.ColorCube(parent, id, x, y, key, onClick)
    if not AddonUILib then return unavailable() end
    return AddonUILib.Button.ColorCube(parent, id, x, y, key, onClick)
end

return UiHelpers
