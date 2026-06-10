local api = require("api")
local SettingsUi = require("power_ranger_on/settings_ui")
local UiHelpers = require("power_ranger_on/ui_helpers")
local OverlayUtils = require("power_ranger_on/overlay_utils")

local CooldownSkillsWindow = {}

local ROWS_PER_PAGE = 8
local INFO_ROWS_PER_PAGE = 4
local wnd = nil
local ctx = nil
local page = 1

local function colors()
    return ctx and ctx.colors or {}
end

local function short(value, len)
    if OverlayUtils and OverlayUtils.shortText then return OverlayUtils.shortText(value, len) end
    value = tostring(value or "")
    if #value <= len then return value end
    return string.sub(value, 1, math.max(1, len - 1)) .. "."
end

local function isCooldownRow(row)
    if type(row) ~= "table" then return false end
    if row.gliderPattern or row.category == "glider" or row.category == "mount" or row.category == "player" then return true end
    if row.recipeDeviceKind == "glider" or row.recipeDeviceKind == "mount" or row.recipeDeviceKind == "player" then return true end
    if row.recipeDeviceName or row.recipeDeviceKey then return true end
    if row.preferMountIcon then return true end
    return false
end

local function entries()
    local out = {}
    local settings = ctx and ctx.settings or {}
    for i, row in ipairs(settings.trackedBuffs or {}) do
        local entry = {kind = "buff", index = i, row = row}
        local matchesDevice = not ctx or not ctx.deviceKey or not ctx.deviceKeyForEntry or ctx.deviceKeyForEntry(entry) == ctx.deviceKey
        if matchesDevice and isCooldownRow(row) then out[#out + 1] = entry end
    end
    for i, row in ipairs(settings.trackedSkills or {}) do
        local entry = {kind = "skill", index = i, row = row}
        local matchesDevice = not ctx or not ctx.deviceKey or not ctx.deviceKeyForEntry or ctx.deviceKeyForEntry(entry) == ctx.deviceKey
        if matchesDevice and isCooldownRow(row) then out[#out + 1] = entry end
    end
    return out
end

local function triggerText(row)
    if not row then return "" end
    local parts = {}
    local function add(text)
        text = tostring(text or "")
        if text ~= "" then parts[#parts + 1] = text end
    end
    -- formatBuffId / explicit formatting: plain tostring (and table.concat, which uses
    -- it) renders 7-digit ids as "8.00021e+006" in this client.
    if row.id or row.buff_id then add("ID " .. OverlayUtils.formatBuffId(row.id or row.buff_id)) end
    local function idListText(list)
        local out = {}
        for i, value in ipairs(list) do out[i] = OverlayUtils.formatBuffId(value) end
        return table.concat(out, ",")
    end
    if type(row.buffIds) == "table" and row.buffIds[1] then add("IDs " .. idListText(row.buffIds)) end
    if type(row.buff_ids) == "table" and row.buff_ids[1] then add("IDs " .. idListText(row.buff_ids)) end
    if row.buffName then add("Aura " .. tostring(row.buffName)) end
    if row.mountManaSpent or row.petManaSpent or row.mana_trigger then add("Pet mana " .. tostring(row.mountManaSpent or row.petManaSpent or row.mana_trigger)) end
    if row.playerManaSpent or row.player_mana then add("Player mana " .. tostring(row.playerManaSpent or row.player_mana)) end
    if row.requiredBuffId or row.req_buff then add("Req " .. tostring(row.requiredBuffId or row.req_buff)) end
    if row.mountName or row.mount_name then add("Mount " .. tostring(row.mountName or row.mount_name)) end
    if type(row.mountNames) == "table" and row.mountNames[1] then add("Mount " .. tostring(row.mountNames[1])) end
    if #parts == 0 and row.pattern then add("Skill " .. tostring(row.pattern)) end
    if #parts == 0 then add(row.unit or row.source or "Aura") end
    return table.concat(parts, " | ")
end

local function recipeText(row)
    if not row then return "" end
    local parts = {}
    local function add(key, value)
        if type(value) == "table" then
            local items = {}
            for i, item in ipairs(value) do items[i] = tostring(item) end
            if items[1] then parts[#parts + 1] = key .. "=" .. table.concat(items, ",") end
        elseif value ~= nil and tostring(value) ~= "" then
            parts[#parts + 1] = key .. "=" .. tostring(value)
        end
    end
    add("unit", row.unit)
    add("id", row.id or row.buff_id)
    add("ids", row.buffIds or row.buff_ids)
    add("names", row.buffNames)
    add("name", row.buffName)
    add("petMana", row.mountManaSpent or row.petManaSpent or row.mana_trigger)
    add("playerMana", row.playerManaSpent or row.player_mana)
    add("req", row.requiredBuffId or row.req_buff)
    add("mount", row.mountNames or row.mountName or row.mount_name)
    add("items", row.itemTypes or row.itemType)
    add("glider", row.gliderPattern)
    add("cd", row.cooldown or row.cooldownSeconds)
    if row.cooldownStartsOnActive then add("starts", "active") end
    if row.cooldownOnlyOnActive then add("only", "active") end
    if row.fixedCooldown then add("fixed", true) end
    return table.concat(parts, "  ")
end

local function recipeLines(row)
    if not row then return "", "", "" end
    local function listText(value)
        if type(value) == "table" then
            local out = {}
            for i, item in ipairs(value) do out[i] = tostring(item) end
            return table.concat(out, ", ")
        end
        return tostring(value or "")
    end
    local trigger = triggerText(row)
    local gates = {}
    local flags = {}
    local function add(list, label, value)
        local text = listText(value)
        if text ~= "" then list[#list + 1] = label .. ": " .. text end
    end
    add(gates, "Mount", row.mountNames or row.mountName or row.mount_name)
    add(gates, "Items", row.itemTypes or row.itemType)
    add(gates, "Glider", row.gliderPattern)
    add(gates, "Required", row.requiredBuffIds or row.requiredBuffId or row.requiredBuffName)
    add(flags, "Cooldown", row.cooldown or row.cooldownSeconds)
    if row.cooldownStartsOnActive then flags[#flags + 1] = "starts while active" end
    if row.cooldownOnlyOnActive then flags[#flags + 1] = "trigger only" end
    if row.fixedCooldown then flags[#flags + 1] = "fixed" end
    if row.dynamicDisplay then flags[#flags + 1] = "dynamic display" end
    return "Trigger: " .. (trigger ~= "" and trigger or "none"),
        "Gate: " .. (#gates > 0 and table.concat(gates, " | ") or "none"),
        "Rules: " .. (#flags > 0 and table.concat(flags, " | ") or "none")
end

local function deviceText(row)
    if not row then return "" end
    return row.recipeDeviceName or row.source or row.mount or row.category or row.unit or ""
end

local function skillText(row)
    if not row then return "" end
    return row.recipeAbilityLabel or row.name or row.buffName or row.pattern or tostring(row.id or row.skillId or "")
end

local function iconPath(entry)
    if not ctx or not entry or not entry.row then return nil end
    local row = entry.row
    if (row.icon_type or row.iconType or row.icon_id or row.iconId) and ctx.cooldownRowIcon then
        local path = ctx.cooldownRowIcon(row)
        if path then return path end
    end
    if ctx.skillIconById then
        local path = ctx.skillIconById(row.id or row.skillId)
        if path then return path end
    end
    if ctx.buffIconById then
        local path = ctx.buffIconById(row.id or row.buff_id)
        if path then return path end
        if type(row.buffIds) == "table" and row.buffIds[1] then
            path = ctx.buffIconById(row.buffIds[1])
            if path then return path end
        end
    end
    if row.icon and row.icon ~= row.recipeDeviceIcon then return row.icon end
    return nil
end

local function setToggle(btn, enabled, text)
    UiHelpers.SetToggleButton(btn, enabled, text, colors())
end

local function saveAndRefresh()
    if ctx and ctx.save then ctx.save() end
    if ctx and ctx.refresh then ctx.refresh() end
end

local function refresh()
    if not wnd then return end
    local rows = entries()
    local infoMode = ctx and ctx.mode == "info"
    local pageSize = infoMode and INFO_ROWS_PER_PAGE or ROWS_PER_PAGE
    local maxPage = math.max(1, math.ceil(#rows / pageSize))
    if page > maxPage then page = maxPage end
    if page < 1 then page = 1 end
    if wnd.pageLabel then wnd.pageLabel:SetText(tostring(page) .. " / " .. tostring(maxPage)) end
    local startIndex = ((page - 1) * pageSize) + 1
    for i = 1, ROWS_PER_PAGE do
        local ui = wnd.rows[i]
        local entry = i <= pageSize and rows[startIndex + i - 1] or nil
        if entry then
            local row = entry.row
            local rowH = infoMode and 58 or 26
            local y = 82 + ((i - 1) * (infoMode and 62 or 30))
            ui.root:SetExtent(586, rowH)
            if ui.root.RemoveAllAnchors then ui.root:RemoveAllAnchors() end
            ui.root:AddAnchor("TOPLEFT", wnd, 16, y)
            ui.root:Show(true)
            if ctx and ctx.setEquipIcon then ctx.setEquipIcon(ui.icon, iconPath(entry)) end
            ui.skill._entryKind = entry.kind
            ui.skill._entryIndex = entry.index
            ui.skill._settingText = true
            ui.skill:SetText(tostring(row.customName or skillText(row)))
            ui.skill._settingText = false
            ui.device:SetText(infoMode and short(deviceText(row), 28) or short(deviceText(row), 13))
            ui.trigger:SetExtent(infoMode and 340 or 198, 12)
            ui.trigger:SetText(short(infoMode and recipeText(row) or triggerText(row), infoMode and 62 or 31))
            if ui.detail1 then
                local line1, line2, line3 = recipeLines(row)
                ui.detail1:SetText(short(line1, 78))
                ui.detail2:SetText(short(line2, 78))
                ui.detail3:SetText(short(line3, 78))
                ui.detail1:Show(infoMode)
                ui.detail2:Show(infoMode)
                ui.detail3:Show(infoMode)
            end
            ui.cd._settingText = true
            ui.cd.entryKind = entry.kind
            ui.cd.entryIndex = entry.index
            ui.cd:SetText(tostring(row.cooldown or row.cooldownSeconds or ""))
            ui.cd._settingText = false
            ui.cd:Show(not infoMode)
            ui.show:Show(not infoMode)
            if ui.delete then ui.delete:Show(not infoMode) end
            setToggle(ui.show, row.enabled ~= false and row.dynamicDisplay ~= true, "Show")
            ui.show._entryKind = entry.kind
            ui.show._entryIndex = entry.index
            if ui.dynamic then
                ui.dynamic:Show(not infoMode)
                setToggle(ui.dynamic, row.enabled ~= false and row.dynamicDisplay == true, "Dyn")
                ui.dynamic._entryKind = entry.kind
                ui.dynamic._entryIndex = entry.index
            end
            if ui.delete then
                ui.delete._entryKind = entry.kind
                ui.delete._entryIndex = entry.index
            end
        else
            ui.root:Show(false)
        end
    end
end

local function rowList(kind)
    local settings = ctx and ctx.settings or {}
    if kind == "skill" then return settings.trackedSkills end
    return settings.trackedBuffs
end

-- Editable name field. Shows the user's custom name, or the auto-detected name when
-- none is set. Typing stores row.customName (cleared back to auto when emptied), which
-- is what the overlay/self panel display and is preserved across reloads by the merge.
local function nameEdit(parent, id, x, y, w, h)
    local edit = W_CTRL and W_CTRL.CreateEdit and W_CTRL.CreateEdit(id, parent) or parent:CreateChildWidget("edit", id, 0, true)
    local border = parent:CreateColorDrawable(0, 0, 0, 0.95, "background")
    border:SetExtent(w + 2, h + 2)
    border:AddAnchor("TOPLEFT", parent, x - 1, y - 1)
    border:Show(true)
    edit:SetExtent(w, h)
    edit:AddAnchor("TOPLEFT", parent, x, y)
    local plate = edit:CreateColorDrawable(0.10, 0.10, 0.11, 0.96, "background")
    plate:AddAnchor("TOPLEFT", edit, 0, 0)
    plate:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
    plate:Show(true)
    if edit.SetMaxTextLength then edit:SetMaxTextLength(24) end
    if edit.style then
        edit.style:SetColor(1, 1, 1, 1)
        edit.style:SetAlign(ALIGN.LEFT)
        edit.style:SetFontSize(10)
    end
    edit:SetHandler("OnTextChanged", function(self)
        if self._settingText then return end
        local list = rowList(self._entryKind)
        local row = list and list[self._entryIndex]
        if not row then return end
        local text = tostring(self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        row.customName = text ~= "" and text or nil
        if ctx and ctx.save then ctx.save() end
    end)
    if edit.Raise then edit:Raise() end
    edit:Show(true)
    return edit
end

local function makeRow(parent, i)
    local c = colors()
    local y = 82 + ((i - 1) * 30)
    local root = parent:CreateChildWidget("emptywidget", "power_ranger_cd_skill_row_" .. i, 0, true)
    root:SetExtent(586, 26)
    root:AddAnchor("TOPLEFT", parent, 16, y)
    local tone = i % 2 == 0 and 0.11 or 0.075
    local bg = root:CreateColorDrawable(tone, tone, tone + 0.015, 0.74, "background")
    bg:AddAnchor("TOPLEFT", root, 0, 0)
    bg:AddAnchor("BOTTOMRIGHT", root, 0, 0)
    bg:Show(true)
    local icon = ctx.createIcon(root, "power_ranger_cd_skill_icon_" .. i, 4, 3, 20)
    local skill = nameEdit(root, "power_ranger_cd_skill_name_" .. i, 30, 5, 104, 16)
    local device = UiHelpers.ChildLabel(root, "power_ranger_cd_skill_device_" .. i, "", 138, 7, 88, 12, 10, c.muted, ALIGN.LEFT)
    local trigger = UiHelpers.ChildLabel(root, "power_ranger_cd_skill_trigger_" .. i, "", 230, 7, 168, 12, 10, c.muted, ALIGN.LEFT)
    local detail1 = UiHelpers.ChildLabel(root, "power_ranger_cd_skill_detail1_" .. i, "", 30, 22, 530, 11, 9, c.muted, ALIGN.LEFT)
    local detail2 = UiHelpers.ChildLabel(root, "power_ranger_cd_skill_detail2_" .. i, "", 30, 34, 530, 11, 9, c.muted, ALIGN.LEFT)
    local detail3 = UiHelpers.ChildLabel(root, "power_ranger_cd_skill_detail3_" .. i, "", 30, 46, 530, 11, 9, c.muted, ALIGN.LEFT)
    detail1:Show(false)
    detail2:Show(false)
    detail3:Show(false)
    local cd = ctx.cooldownEdit(root, "power_ranger_cd_skill_cd_" .. i, 402, 3, 38, 20)
    local show = UiHelpers.ChildFlatButton(root, "power_ranger_cd_skill_show_" .. i, "", 446, 2, 48, 22, c.active, function(self)
        local list = rowList(self._entryKind)
        local row = list and list[self._entryIndex]
        if not row then return end
        local isShow = row.enabled ~= false and row.dynamicDisplay ~= true
        if isShow then
            row.enabled = false
            row.dynamicDisplay = false
        else
            row.enabled = true
            row.dynamicDisplay = false
        end
        saveAndRefresh()
        refresh()
    end, c, ALIGN.CENTER)
    local dynamic = UiHelpers.ChildFlatButton(root, "power_ranger_cd_skill_dynamic_" .. i, "", 498, 2, 44, 22, c.button, function(self)
        local list = rowList(self._entryKind)
        local row = list and list[self._entryIndex]
        if not row then return end
        local isDynamic = row.enabled ~= false and row.dynamicDisplay == true
        if isDynamic then
            row.enabled = false
            row.dynamicDisplay = false
        else
            row.enabled = true
            row.dynamicDisplay = true
        end
        saveAndRefresh()
        refresh()
    end, c, ALIGN.CENTER)
    local delete = UiHelpers.ChildFlatButton(root, "power_ranger_cd_skill_delete_" .. i, "Del", 546, 2, 36, 22, c.danger, function(self)
        if ctx and ctx.removeSkill then
            ctx.removeSkill(self._entryKind, self._entryIndex)
            refresh()
        end
    end, c, ALIGN.CENTER)
    return {root = root, icon = icon, skill = skill, device = device, trigger = trigger, detail1 = detail1, detail2 = detail2, detail3 = detail3, cd = cd, show = show, dynamic = dynamic, delete = delete}
end

function CooldownSkillsWindow.Open(options)
    ctx = options or ctx or {}
    local c = colors()
    if wnd then
        if wnd.deviceLabel then
            local prefix = ctx.mode == "info" and "Recipe: " or "Device: "
            wnd.deviceLabel:SetText(ctx.deviceTitle and ctx.deviceTitle ~= "" and (prefix .. short(ctx.deviceTitle, 34)) or "All cooldown devices")
        end
        if wnd.triggerHead then wnd.triggerHead:SetText(ctx.mode == "info" and "Recipe structure" or "Tracked by") end
        if wnd.cdHead then wnd.cdHead:Show(ctx.mode ~= "info") end
        if wnd.showHead then wnd.showHead:Show(ctx.mode ~= "info") end
        if wnd.dynamicHead then wnd.dynamicHead:Show(ctx.mode ~= "info") end
        refresh()
        wnd:Show(true)
        return
    end
    local settings = ctx.settings or {}
    wnd = SettingsUi.CreateShell({
        id = "PowerRangerCooldownSkills",
        title = "Tracked Cooldown Skills",
        width = 620,
        height = 360,
        x = settings.cooldownSkillsX or 720,
        y = settings.cooldownSkillsY or 270,
        xKey = "cooldownSkillsX",
        yKey = "cooldownSkillsY",
        colors = c,
        safePosition = ctx.safePosition,
        applyDrag = ctx.applyDrag,
        closeButtonId = "power_ranger_cd_skills_close",
        onClose = function() wnd:Show(false) end
    })
    wnd.deviceLabel = UiHelpers.Label(wnd, "power_ranger_cd_skill_device_title", ctx.deviceTitle and ctx.deviceTitle ~= "" and ((ctx.mode == "info" and "Recipe: " or "Device: ") .. short(ctx.deviceTitle, 34)) or "All cooldown devices", 16, 36, 360, 14, 10, c.muted, ALIGN.LEFT)
    UiHelpers.Label(wnd, "power_ranger_cd_skill_head_skill", "Skill", 46, 54, 90, 14, 10, c.gold, ALIGN.LEFT)
    UiHelpers.Label(wnd, "power_ranger_cd_skill_head_device", "Device", 154, 54, 80, 14, 10, c.gold, ALIGN.LEFT)
    wnd.triggerHead = UiHelpers.Label(wnd, "power_ranger_cd_skill_head_trigger", ctx.mode == "info" and "Recipe structure" or "Tracked by", 246, 54, 160, 14, 10, c.gold, ALIGN.LEFT)
    wnd.cdHead = UiHelpers.Label(wnd, "power_ranger_cd_skill_head_cd", "CD", 434, 54, 34, 14, 10, c.gold, ALIGN.CENTER)
    wnd.showHead = UiHelpers.Label(wnd, "power_ranger_cd_skill_head_show", "Show", 448, 54, 44, 14, 10, c.gold, ALIGN.CENTER)
    wnd.dynamicHead = UiHelpers.Label(wnd, "power_ranger_cd_skill_head_dynamic", "Dyn", 500, 54, 40, 14, 10, c.gold, ALIGN.CENTER)
    wnd.cdHead:Show(ctx.mode ~= "info")
    wnd.showHead:Show(ctx.mode ~= "info")
    wnd.dynamicHead:Show(ctx.mode ~= "info")
    wnd.rows = {}
    for i = 1, ROWS_PER_PAGE do wnd.rows[i] = makeRow(wnd, i) end
    UiHelpers.FlatButton(wnd, "power_ranger_cd_skill_prev", "<", 16, 326, 34, 22, c.button, function()
        page = math.max(1, page - 1)
        refresh()
    end, c)
    wnd.pageLabel = UiHelpers.Label(wnd, "power_ranger_cd_skill_page", "1 / 1", 58, 330, 80, 14, 10, c.muted, ALIGN.CENTER)
    UiHelpers.FlatButton(wnd, "power_ranger_cd_skill_next", ">", 146, 326, 34, 22, c.button, function()
        page = page + 1
        refresh()
    end, c)
    refresh()
    wnd:Show(true)
end

function CooldownSkillsWindow.Refresh()
    refresh()
end

function CooldownSkillsWindow.Close()
    if wnd then wnd:Show(false) end
end

return CooldownSkillsWindow
