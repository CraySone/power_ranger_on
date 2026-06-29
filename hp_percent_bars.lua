local api = require("api")

local HpPercentBars = {
    frames = {},
    enabled = false
}

local FRAME_SPECS = {
    { unit = "player", uic = UIC.PLAYER_UNITFRAME },
    { unit = "target", uic = UIC.TARGET_UNITFRAME },
    { unit = "targettarget", uic = UIC.TARGET_OF_TARGET_FRAME },
    { unit = "watchtarget", uic = UIC.WATCH_TARGET_FRAME }
}

local function safeCall(fn)
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

local function formatPercent(unit, kind)
    local current
    local max
    if kind == "mana" then
        current = tonumber(safeCall(function() return api.Unit:UnitMana(unit) end))
        max = tonumber(safeCall(function() return api.Unit:UnitMaxMana(unit) end))
    else
        current = tonumber(safeCall(function() return api.Unit:UnitHealth(unit) end))
        max = tonumber(safeCall(function() return api.Unit:UnitMaxHealth(unit) end))
    end
    if not current or not max or max <= 0 then return nil end
    local percent = math.floor(((current / max) * 100) + 0.5)
    percent = math.max(0, math.min(100, percent))
    return string.format("%d%%", percent)
end

local function rememberLabelState(label, prefix)
    if label[prefix .. "Orig"] then return end
    label[prefix .. "ExternalSetText"] = label.SetTextOrig and label.SetText or nil
    label[prefix .. "Orig"] = label.SetTextOrig or label.SetText
    label[prefix .. "Patched"] = false
end

local function patchLabel(unit, bar, label, kind)
    if not bar or not label then return end
    local prefix = kind == "mana" and "_powerRangerMpPercent" or "_powerRangerHpPercent"
    rememberLabelState(label, prefix)
    if label[prefix .. "Patched"] == true then return end
    label[prefix .. "Patched"] = true
    label[prefix .. "Unit"] = unit
    label[prefix .. "Kind"] = kind
    label[prefix .. "HadExternalPatch"] = label.SetTextOrig ~= nil
    label:RemoveAllAnchors()
    label:AddAnchor("CENTER", bar, "CENTER", 0, 0)
    if label.style then
        label.style:SetFontSize((FONT_SIZE and FONT_SIZE.MIDDLE) or 14)
        label.style:SetAlign(ALIGN.CENTER)
    end
    label.SetText = function(self, text)
        local key = self._powerRangerMpPercentKind and "_powerRangerMpPercent" or "_powerRangerHpPercent"
        local value = formatPercent(self[key .. "Unit"], self[key .. "Kind"])
        self[key .. "Orig"](self, value or tostring(text or ""))
    end
    local value = formatPercent(unit, kind)
    if value then label:SetText(value) end
end

local function restoreLabel(bar, label, kind)
    if not bar or not label then return end
    local prefix = kind == "mana" and "_powerRangerMpPercent" or "_powerRangerHpPercent"
    if label[prefix .. "Orig"] then
        label.SetText = label[prefix .. "Orig"]
    end
    label[prefix .. "Orig"] = nil
    label[prefix .. "Patched"] = nil
    label[prefix .. "Unit"] = nil
    label[prefix .. "Kind"] = nil
    local externalSetText = label[prefix .. "ExternalSetText"]
    local hadExternalPatch = label[prefix .. "HadExternalPatch"] == true
    if externalSetText then
        label.SetText = externalSetText
    end
    label[prefix .. "ExternalSetText"] = nil
    label[prefix .. "HadExternalPatch"] = nil
    if not hadExternalPatch then
        label:RemoveAllAnchors()
        label:AddAnchor("BOTTOMRIGHT", bar, -1, -1)
        if label.style then
            label.style:SetFontSize((FONT_SIZE and FONT_SIZE.SMALL) or 11)
            label.style:SetAlign(ALIGN.RIGHT)
        end
    end
end

local function patchFrame(unit, frame)
    if not frame then return end
    patchLabel(unit, frame.hpBar, frame.hpBar and frame.hpBar.hpLabel, "health")
    patchLabel(unit, frame.mpBar, frame.mpBar and frame.mpBar.mpLabel, "mana")
end

local function restoreFrame(frame)
    if not frame then return end
    restoreLabel(frame.hpBar, frame.hpBar and frame.hpBar.hpLabel, "health")
    restoreLabel(frame.mpBar, frame.mpBar and frame.mpBar.mpLabel, "mana")
end

function HpPercentBars.Apply(enabled)
    HpPercentBars.enabled = enabled == true
    for _, spec in ipairs(FRAME_SPECS) do
        local frame = HpPercentBars.frames[spec.unit] or safeCall(function() return ADDON:GetContent(spec.uic) end)
        HpPercentBars.frames[spec.unit] = frame
        if HpPercentBars.enabled then
            patchFrame(spec.unit, frame)
        else
            restoreFrame(frame)
        end
    end
end

function HpPercentBars.Refresh()
    if HpPercentBars.enabled then HpPercentBars.Apply(true) end
end

function HpPercentBars.Cleanup()
    HpPercentBars.Apply(false)
    HpPercentBars.frames = {}
end

return HpPercentBars
