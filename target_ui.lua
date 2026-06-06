local UiHelpers = require("power_ranger_on/ui_helpers")

local TargetUi = {}

function TargetUi.Context(colors, cycleColor)
    local ctx = {}
    ctx.addBg = UiHelpers.AddBg
    ctx.label = UiHelpers.Label
    ctx.flatButton = function(parent, id, text, x, y, w, h, tone, onClick)
        return UiHelpers.FlatButton(parent, id, text, x, y, w, h, tone, onClick, colors)
    end
    ctx.panel = function(parent, id, x, y, w, h)
        return UiHelpers.Panel(parent, id, x, y, w, h, colors)
    end
    ctx.sectionPanel = function(parent, id, x, y, w, h, titleText)
        return UiHelpers.SectionPanel(parent, id, x, y, w, h, titleText, colors)
    end
    ctx.colorCube = function(parent, id, x, y, key)
        return UiHelpers.ColorCube(parent, id, x, y, key, function(self)
            if cycleColor then cycleColor(self._colorKey) end
        end)
    end
    ctx.setToggleButton = function(btn, enabled, text)
        return UiHelpers.SetToggleButton(btn, enabled, text, colors)
    end
    return ctx
end

return TargetUi
