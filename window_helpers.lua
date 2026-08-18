-- Power Ranger window helper adapter for AddonUILib.
--
-- No implementation. Maps the old WindowHelpers.* names onto AddonUILib.Window.*, same as
-- ui_helpers.lua does for the widget primitives. See AddonUILib/ADAPTERS.md.

local api = require("api")

local WindowHelpers = {}

local ok, AddonUILib = pcall(require, "AddonUILib/init")
if not ok or type(AddonUILib) ~= "table" then
    AddonUILib = nil
    pcall(function()
        api.Log:Err("[Power Ranger ON] AddonUILib is missing or failed to load. Windows will not position or drag correctly.")
    end)
end

-- Clamp lives in Core, not Window -- it is a plain numeric helper.
function WindowHelpers.Clamp(value, minValue, maxValue)
    if AddonUILib then return AddonUILib.Core.Clamp(value, minValue, maxValue) end
    value = tonumber(value) or minValue
    if maxValue < minValue then return minValue end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function WindowHelpers.SafePosition(x, y, width, height)
    if AddonUILib then return AddonUILib.Window.SafePosition(x, y, width, height) end
    return x, y
end

-- Mouse position in UI units. api.Input:GetMousePos() returns SCREEN pixels, and every
-- widget offset is in UI units -- they only agree at UI scale 1.0. Use this for any
-- click-to-set control.
function WindowHelpers.MouseUI()
    if AddonUILib then return AddonUILib.Window.MouseUI() end
    local ok, mx, my = pcall(function() return api.Input:GetMousePos() end)
    if not ok then return nil, nil end
    return mx, my
end

function WindowHelpers.UIScale()
    if AddonUILib then return AddonUILib.Window.UIScale() end
    return 1
end

function WindowHelpers.Position(window)
    if AddonUILib then return AddonUILib.Window.Position(window) end
    return nil, nil
end

function WindowHelpers.SavePosition(window, settings, keyX, keyY, saveSettings)
    if not AddonUILib then return end
    return AddonUILib.Window.SavePosition(window, settings, keyX, keyY, saveSettings)
end

function WindowHelpers.ApplyDrag(window, handle, settings, keyX, keyY, saveSettings, allowPlainDrag)
    if not AddonUILib then return end
    return AddonUILib.Window.ApplyDrag(window, handle, settings, keyX, keyY, saveSettings, allowPlainDrag)
end

function WindowHelpers.ApplyHandleDrag(window, handle, settings, keyX, keyY, saveSettings)
    if not AddonUILib then return end
    return AddonUILib.Window.ApplyHandleDrag(window, handle, settings, keyX, keyY, saveSettings)
end

return WindowHelpers
