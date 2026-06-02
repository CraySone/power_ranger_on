local api = require("api")

local MichaelClient = {}

function MichaelClient:initializeMichaelClient()
    local configMenu = ADDON:GetContent(UIC.SYSTEM_CONFIG_FRAME)
    if not configMenu then return nil end

    if configMenu.michaelClient == nil then
        local michaelClient = configMenu:CreateChildWidget("label", "michaelClient", 0, true)
        michaelClient:AddAnchor("TOPLEFT", configMenu, -110, 5)
        michaelClient:SetExtent(110, 28)
        michaelClient:SetText("Addon Options")
        configMenu.michaelClient = michaelClient
        configMenu.michaelClient.addons = {}

        michaelClient.bg = michaelClient:CreateNinePartDrawable("ui/common/tab_list.dds", "background")
        michaelClient.bg:SetTextureInfo("bg_quest")
        michaelClient.bg:SetColor(0, 0, 0, 0.5)
        michaelClient.bg:AddAnchor("TOPLEFT", michaelClient, 0, 0)
        michaelClient.bg:AddAnchor("BOTTOMRIGHT", michaelClient, 0, 0)

        michaelClient.addonCount = 0
        function configMenu.michaelClient:AddAddon(title, callback)
            if self.addons[title] then
                self.addons[title]:SetHandler("OnClick", function() callback() end)
                self.addons[title]:Show(true)
                return
            end
            self.addonCount = self.addonCount + 1
            local addonButton = self:CreateChildWidget("button", "power_ranger_addon_option_" .. tostring(self.addonCount), 0, true)
            addonButton:SetText(title)
            addonButton:AddAnchor("TOPLEFT", michaelClient, 5, self.addonCount * 30)
            addonButton:SetExtent(100, 28)
            addonButton:SetHandler("OnClick", function() callback() end)
            addonButton:Show(true)
            self.addons[title] = addonButton

            local currentWidth = michaelClient.bg:GetWidth()
            michaelClient.bg:SetExtent(currentWidth, self.addonCount * 30)
            michaelClient.bg:RemoveAllAnchors()
            michaelClient.bg:AddAnchor("TOPLEFT", michaelClient, 0, 0)
            michaelClient.bg:AddAnchor("BOTTOMRIGHT", michaelClient, 0, self.addonCount * 30 + 10)
        end
    end

    return configMenu
end

function MichaelClient.OnUnload()
    local ok, configMenu = pcall(function() return ADDON:GetContent(UIC.SYSTEM_CONFIG_FRAME) end)
    if ok and configMenu and configMenu.michaelClient and configMenu.michaelClient.addons then
        local names = {"Power Ranger ON", "Power Ranger On"}
        for _, name in ipairs(names) do
            local button = configMenu.michaelClient.addons[name]
            if button then
                button:Show(false)
            end
        end
    end
end

return MichaelClient
