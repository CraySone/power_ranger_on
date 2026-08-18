-- Power Ranger icon adapter for AddonUILib.
--
-- No implementation. Maps the old IconWidgets.* names onto AddonUILib.Icon.*.
--
-- Note the internal cache fields changed name (_lastPath -> _addonUiLibLastPath). Nothing in
-- this addon reads them directly, and the only effect is that the first repaint after
-- updating re-uploads each texture once.

local api = require("api")

local IconWidgets = {}

local ok, AddonUILib = pcall(require, "AddonUILib/init")
if not ok or type(AddonUILib) ~= "table" then
    AddonUILib = nil
    pcall(function()
        api.Log:Err("[Power Ranger ON] AddonUILib is missing or failed to load. Cooldown and equipment icons will not render.")
    end)
end

function IconWidgets.Create(parent, id, x, y, size, addBg)
    if not AddonUILib then return nil end
    return AddonUILib.Icon.Create(parent, id, x, y, size, addBg)
end

function IconWidgets.Set(icon, path)
    if not AddonUILib then return end
    return AddonUILib.Icon.Set(icon, path)
end

function IconWidgets.SetCached(icon, path)
    if not AddonUILib then return end
    return AddonUILib.Icon.SetCached(icon, path)
end

-- Keeps an empty slot frame visible instead of hiding it.
function IconWidgets.SetEquip(icon, path)
    if not AddonUILib then return end
    return AddonUILib.Icon.SetEquip(icon, path)
end

function IconWidgets.SetCooldown(icon, path, state, seconds)
    if not AddonUILib then return end
    return AddonUILib.Icon.SetCooldown(icon, path, state, seconds)
end

-- Same as SetCooldown but a nil path leaves the empty slot frame in the layout.
function IconWidgets.SetCooldownSkill(icon, path, state, seconds)
    if not AddonUILib then return end
    return AddonUILib.Icon.SetCooldownSkill(icon, path, state, seconds)
end

function IconWidgets.ClearCooldown(icon)
    if not AddonUILib then return end
    return AddonUILib.Icon.Clear(icon)
end

return IconWidgets
