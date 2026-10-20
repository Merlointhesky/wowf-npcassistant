-- vendor_automation.lua
-- Automates opening vendor dialogs with a 2-step gossip that has a single selectable option for WoW Forever v1.6

local addon = _G.ForeverNPCAssistant
local debug = addon.debug

local function isTwoStepSingleOption()
    if C_GossipInfo and C_GossipInfo.GetNumOptions then
        local num = C_GossipInfo.GetNumOptions()
        if num ~= 2 then return false end
        local selectable = 0
        local options = C_GossipInfo.GetOptions()
        for i = 1, num do
            local opt = options[i]
            if opt and not opt.disabled then selectable = selectable + 1 end
        end
        return selectable == 1
    end
    if GetGossipOptions then
        local opts = { GetGossipOptions() }
        if #opts ~= 2 then return false end
        local selectable = 0
        for _, o in ipairs(opts) do if not o.disabled then selectable = selectable + 1 end end
        return selectable == 1
    end
    return false
end

local function openVendor()
    if C_Vendor and C_Vendor.Show then
        C_Vendor.Show()
        debug('Vendor opened via C_Vendor.Show')
    elseif OpenVendor then
        OpenVendor()
        debug('Vendor opened via legacy OpenVendor')
    else
        debug('No vendor open API available')
    end
end

local frame = CreateFrame('Frame')
frame:RegisterEvent('GOSSIP_SHOW')
frame:SetScript('OnEvent', function(self, event, ...)
    if event == 'GOSSIP_SHOW' and isTwoStepSingleOption() then
        local options = C_GossipInfo.GetOptions() or { GetGossipOptions() }
        for i = 1, 2 do
            local opt = options[i]
            if opt and not opt.disabled then
                SelectGossipOption(i)
                debug('Selected gossip option ' .. i)
                break
            end
        end
        openVendor()
    end
end)

return {}
