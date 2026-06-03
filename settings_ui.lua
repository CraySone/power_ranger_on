local api = require("api")
local UiHelpers = require("power_ranger_on/ui_helpers")

local SettingsUi = {}

function SettingsUi.CreateShell(opts)
    opts = opts or {}
    local colors = opts.colors or {}
    local width = opts.width or 620
    local height = opts.height or 760
    local safePosition = opts.safePosition
    local x = opts.x or opts.defaultX or 0
    local y = opts.y or opts.defaultY or 0
    if safePosition then
        x, y = safePosition(x, y, width, height)
    end

    local wnd = api.Interface:CreateEmptyWindow(opts.id or "PowerRangerSettings", "UIParent")
    wnd:SetExtent(width, height)
    wnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    UiHelpers.AddBg(wnd, 0, 0, 0, 0.96)

    local dark = colors.dark or {0.06, 0.06, 0.068, 0.96}
    local body = wnd:CreateColorDrawable(dark[1], dark[2], dark[3], dark[4], "background")
    body:AddAnchor("TOPLEFT", wnd, 1, 1)
    body:AddAnchor("BOTTOMRIGHT", wnd, -1, -1)
    body:Show(true)

    local header = wnd:CreateColorDrawable(0.09, 0.09, 0.11, 0.98, "background")
    header:SetExtent(width - 2, 34)
    header:AddAnchor("TOPLEFT", wnd, 1, 1)
    header:Show(true)

    local title = UiHelpers.Label(wnd, (opts.id or "PowerRangerSettings") .. "_title", opts.title or "", 16, 8, 320, 18, 14, colors.gold or {1, 0.84, 0, 1}, ALIGN.LEFT)
    if opts.applyDrag then
        opts.applyDrag(wnd, title, opts.xKey, opts.yKey, true)
    end

    if opts.compatButtonId and opts.onCompat then
        wnd.compatModeBtn = UiHelpers.FlatButton(wnd, opts.compatButtonId, "", width - 206, 7, 160, 22, colors.blue or {0.16, 0.21, 0.30, 0.96}, opts.onCompat, colors)
    end
    UiHelpers.FlatButton(wnd, opts.closeButtonId or ((opts.id or "PowerRangerSettings") .. "_close"), "X", width - 36, 7, 22, 22, colors.button or {0.14, 0.14, 0.16, 0.95}, opts.onClose, colors)
    wnd.colorCubes = {}
    return wnd
end

return SettingsUi
