-- Power Ranger settings-shell adapter for AddonUILib.
--
-- No implementation. CreateShell's option names are unchanged, including compatButtonId /
-- onCompat and the resulting wnd.compatModeBtn that refreshSettingsButtons looks up.

local api = require("api")

local SettingsUi = {}

local ok, AddonUILib = pcall(require, "AddonUILib/init")
if not ok or type(AddonUILib) ~= "table" then
    AddonUILib = nil
    pcall(function()
        api.Log:Err("[Power Ranger ON] AddonUILib is missing or failed to load. Settings windows will not open.")
    end)
end

function SettingsUi.CreateShell(opts)
    if not AddonUILib then return nil end
    return AddonUILib.Window.CreateShell(opts)
end

return SettingsUi
