local api = require("api")

local WindowHelpers = {}

function WindowHelpers.Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if maxValue < minValue then return minValue end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function WindowHelpers.SafePosition(x, y, width, height)
    local screenWidth = tonumber(api.Interface:GetScreenWidth()) or 1920
    local screenHeight = tonumber(api.Interface:GetScreenHeight()) or 1080
    if screenWidth <= 0 then screenWidth = 1920 end
    if screenHeight <= 0 then screenHeight = 1080 end
    local pad = 12
    local maxX = screenWidth - (tonumber(width) or 1) - pad
    local maxY = screenHeight - (tonumber(height) or 1) - pad
    return WindowHelpers.Clamp(x, pad, maxX), WindowHelpers.Clamp(y, pad, maxY)
end

function WindowHelpers.Position(window)
    if not window then return nil, nil end
    if window.GetEffectiveOffset then
        local x, y = window:GetEffectiveOffset()
        if tonumber(x) and tonumber(y) then return x, y end
    end
    if window.GetOffset then
        local x, y = window:GetOffset()
        if tonumber(x) and tonumber(y) then return x, y end
    end
    return nil, nil
end

function WindowHelpers.SavePosition(window, settings, keyX, keyY, saveSettings)
    local x, y = WindowHelpers.Position(window)
    if not tonumber(x) or not tonumber(y) then return end
    settings[keyX] = math.floor(tonumber(x) + 0.5)
    settings[keyY] = math.floor(tonumber(y) + 0.5)
    if saveSettings then saveSettings() end
end

function WindowHelpers.ApplyDrag(window, handle, settings, keyX, keyY, saveSettings, allowPlainDrag)
    local function startDrag()
        if not allowPlainDrag and not (api.Input and api.Input:IsShiftKeyDown()) then return end
        if window.StartMoving then window:StartMoving() end
        if api.Cursor and api.Cursor.ClearCursor then api.Cursor:ClearCursor() end
    end
    local function stopDrag()
        if window.StopMovingOrSizing then window:StopMovingOrSizing() end
        if api.Cursor and api.Cursor.ClearCursor then api.Cursor:ClearCursor() end
        WindowHelpers.SavePosition(window, settings, keyX, keyY, saveSettings)
    end
    if window.EnableDrag then window:EnableDrag(true) end
    if window.RegisterForDrag then window:RegisterForDrag("LeftButton") end
    if window.SetHandler then
        window:SetHandler("OnDragStart", startDrag)
        window:SetHandler("OnDragStop", stopDrag)
        window:SetHandler("OnDragEnd", stopDrag)
    end
    if handle then
        if handle.EnableDrag then handle:EnableDrag(true) end
        if handle.RegisterForDrag then handle:RegisterForDrag("LeftButton") end
        if handle.SetHandler then
            handle:SetHandler("OnDragStart", startDrag)
            handle:SetHandler("OnDragStop", stopDrag)
            handle:SetHandler("OnDragEnd", stopDrag)
        end
    end
end

function WindowHelpers.ApplyHandleDrag(window, handle, settings, keyX, keyY, saveSettings)
    local function startDrag()
        if not (api.Input and api.Input:IsShiftKeyDown()) then return end
        if window.StartMoving then window:StartMoving() end
        if api.Cursor and api.Cursor.ClearCursor then api.Cursor:ClearCursor() end
    end
    local function stopDrag()
        if window.StopMovingOrSizing then window:StopMovingOrSizing() end
        if api.Cursor and api.Cursor.ClearCursor then api.Cursor:ClearCursor() end
        WindowHelpers.SavePosition(window, settings, keyX, keyY, saveSettings)
    end
    if handle then
        if handle.Clickable then handle:Clickable(true) end
        if handle.EnableDrag then handle:EnableDrag(true) end
        if handle.RegisterForDrag then handle:RegisterForDrag("LeftButton") end
        if handle.SetHandler then
            handle:SetHandler("OnDragStart", startDrag)
            handle:SetHandler("OnDragStop", stopDrag)
            handle:SetHandler("OnDragEnd", stopDrag)
        end
    end
end

return WindowHelpers
