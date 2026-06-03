local api = require("api")

local UiHelpers = {}

function UiHelpers.SetTextColor(widget, color)
    if widget and widget.style and widget.style.SetColor and type(color) == "table" then
        widget.style:SetColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

function UiHelpers.AddBg(parent, r, g, b, a)
    local bg = parent:CreateColorDrawable(r, g, b, a, "background")
    bg:AddAnchor("TOPLEFT", parent, 0, 0)
    bg:AddAnchor("BOTTOMRIGHT", parent, 0, 0)
    bg:Show(true)
    return bg
end

function UiHelpers.Label(parent, id, text, x, y, w, h, size, color, align)
    local l = api.Interface:CreateWidget("label", id, parent)
    l:SetExtent(w, h)
    l:AddAnchor("TOPLEFT", parent, x, y)
    l.style:SetFontSize(size or 12)
    l.style:SetAlign(align or ALIGN.LEFT)
    if l.style.SetShadow then l.style:SetShadow(false) end
    if l.style.SetOutline then l.style:SetOutline(false) end
    UiHelpers.SetTextColor(l, color or {1, 1, 1, 1})
    l:SetText(text or "")
    l:Show(true)
    return l
end

function UiHelpers.ChildLabel(parent, id, text, x, y, w, h, size, color, align)
    local widget = parent:CreateChildWidget("label", id, 0, true)
    widget:SetExtent(w, h)
    widget:AddAnchor("TOPLEFT", parent, x, y)
    widget.style:SetFontSize(size or 11)
    widget.style:SetAlign(align or ALIGN.LEFT)
    UiHelpers.SetTextColor(widget, color or {1, 1, 1, 1})
    widget:SetText(text or "")
    widget:Show(true)
    return widget
end

function UiHelpers.FlatButton(parent, id, text, x, y, w, h, tone, onClick, colors)
    colors = colors or {}
    local buttonTone = tone or colors.button or {0.14, 0.14, 0.16, 0.95}
    local white = colors.white or {1, 1, 1, 1}
    local btn = api.Interface:CreateWidget("button", id, parent)
    btn:SetExtent(w, h)
    btn:AddAnchor("TOPLEFT", parent, x, y)
    btn:SetText("")
    local border = btn:CreateColorDrawable(0, 0, 0, 0.92, "background")
    border:AddAnchor("TOPLEFT", btn, 0, 0)
    border:AddAnchor("BOTTOMRIGHT", btn, 0, 0)
    border:Show(true)
    local fill = btn:CreateColorDrawable(buttonTone[1], buttonTone[2], buttonTone[3], buttonTone[4], "background")
    fill:AddAnchor("TOPLEFT", btn, 1, 1)
    fill:AddAnchor("BOTTOMRIGHT", btn, -1, -1)
    fill:Show(true)
    local txt = UiHelpers.Label(btn, id .. "_txt", text, 1, 2, w - 2, h - 4, 11, white, ALIGN.CENTER)
    txt:Clickable(false)
    btn._fill = fill
    btn._text = txt
    function btn:SetCleanText(value) self._text:SetText(value or "") end
    function btn:SetTone(color) self._fill:SetColor(color[1], color[2], color[3], color[4]) end
    if onClick then btn:SetHandler("OnClick", onClick) end
    btn:Show(true)
    return btn
end

function UiHelpers.ChildFlatButton(parent, id, text, x, y, w, h, tone, onClick, colors, align)
    colors = colors or {}
    local buttonTone = tone or colors.button or {0.14, 0.14, 0.16, 0.95}
    local white = colors.white or {1, 1, 1, 1}
    local button = parent:CreateChildWidget("button", id, 0, true)
    button:SetExtent(w, h)
    button:AddAnchor("TOPLEFT", parent, x, y)
    button:SetText("")
    local border = button:CreateColorDrawable(0, 0, 0, 0.92, "background")
    border:AddAnchor("TOPLEFT", button, 0, 0)
    border:AddAnchor("BOTTOMRIGHT", button, 0, 0)
    border:Show(true)
    local fill = button:CreateColorDrawable(buttonTone[1], buttonTone[2], buttonTone[3], buttonTone[4], "background")
    fill:AddAnchor("TOPLEFT", button, 1, 1)
    fill:AddAnchor("BOTTOMRIGHT", button, -1, -1)
    fill:Show(true)
    local textLabel = UiHelpers.ChildLabel(button, id .. "_text", text, 4, 2, w - 8, h - 4, 11, white, align or ALIGN.LEFT)
    textLabel:Clickable(false)
    button.cleanFill = fill
    button.cleanLabel = textLabel
    function button:SetCleanText(value) self.cleanLabel:SetText(value or "") end
    function button:SetTone(value) self.cleanFill:SetColor(value[1], value[2], value[3], value[4]) end
    if onClick then button:SetHandler("OnClick", onClick) end
    button:Show(true)
    return button
end

function UiHelpers.Panel(parent, id, x, y, w, h, colors)
    colors = colors or {}
    local panelColor = colors.panel or {0.045, 0.045, 0.052, 0.84}
    local p = parent:CreateChildWidget("emptywidget", id, 0, true)
    p:SetExtent(w, h)
    p:AddAnchor("TOPLEFT", parent, x, y)
    UiHelpers.AddBg(p, panelColor[1], panelColor[2], panelColor[3], panelColor[4])
    p:Show(true)
    return p
end

function UiHelpers.SectionPanel(parent, id, x, y, w, h, titleText, colors)
    colors = colors or {}
    local gold = colors.gold or {1, 0.84, 0, 1}
    local p = UiHelpers.Panel(parent, id, x, y, w, h, colors)
    local header = p:CreateColorDrawable(0.09, 0.09, 0.11, 0.95, "background")
    header:SetExtent(w, 24)
    header:AddAnchor("TOPLEFT", p, 0, 0)
    header:Show(true)
    local accent = p:CreateColorDrawable(1, 0.84, 0, 0.85, "background")
    accent:SetExtent(4, 24)
    accent:AddAnchor("TOPLEFT", p, 0, 0)
    accent:Show(true)
    UiHelpers.Label(p, id .. "_title", titleText or "", 14, 4, w - 28, 16, 12, gold, ALIGN.LEFT)
    return p
end

function UiHelpers.SetToggleButton(btn, enabled, text, colors)
    if not btn then return end
    colors = colors or {}
    btn:SetCleanText((text or "") .. (enabled and " ON" or " OFF"))
    btn:SetTone(enabled and (colors.active or {0.12, 0.28, 0.15, 0.95}) or (colors.button or {0.14, 0.14, 0.16, 0.95}))
end

function UiHelpers.ColorCube(parent, id, x, y, key, onClick)
    local btn = api.Interface:CreateWidget("button", id, parent)
    btn:SetExtent(20, 20)
    btn:AddAnchor("TOPLEFT", parent, x, y)
    btn:SetText("")
    local border = btn:CreateColorDrawable(0, 0, 0, 0.96, "background")
    border:AddAnchor("TOPLEFT", btn, 0, 0)
    border:AddAnchor("BOTTOMRIGHT", btn, 0, 0)
    border:Show(true)
    local fill = btn:CreateColorDrawable(1, 1, 1, 1, "background")
    fill:AddAnchor("TOPLEFT", btn, 3, 3)
    fill:AddAnchor("BOTTOMRIGHT", btn, -3, -3)
    fill:Show(true)
    btn._fill = fill
    btn._colorKey = key
    if onClick then btn:SetHandler("OnClick", onClick) end
    btn:Show(true)
    return btn
end

return UiHelpers
