local api = require("api")

local EventWindow = {}

function EventWindow.Create(onCombatMessage, onSkillEvent)
    local wnd = api.Interface:CreateEmptyWindow("PowerRangerEvents", "UIParent")
    wnd:SetExtent(1, 1)
    wnd:AddAnchor("TOPLEFT", "UIParent", 0, 0)
    if wnd.Clickable then wnd:Clickable(false) end
    wnd:SetHandler("OnEvent", function(self, event, ...)
        if event == "COMBAT_MSG" then
            onCombatMessage(...)
        elseif event == "SPELLCAST_START" or event == "SPELLCAST_SUCCEEDED" or event == "SPELLCAST_STOP" then
            onSkillEvent(event, ...)
        end
    end)
    wnd:Show(true)
    return wnd
end

return EventWindow
