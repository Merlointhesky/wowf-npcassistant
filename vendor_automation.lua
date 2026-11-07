-- vendor_automation.lua for ForeverNPCAssistant
-- Automates opening vendor dialogs with a 2-step gossip that has a single selectable option for WoW Forever v1.6
local addonName, FNPA = ...
FNPA = FNPA or _G.ForeverNPCAssistant

local function openVendor()
    if C_Vendor and C_Vendor.Show then
        C_Vendor.Show()
        FNPA:DebugLog("Vendor opened via C_Vendor.Show")
    elseif OpenVendor then
        OpenVendor()
        FNPA:DebugLog("Vendor opened via legacy OpenVendor")
    end
end

function FNPA:CheckTwoStepVendorGossip()
    if self.settings and self.settings.autoSkipGossip == false then return false end
    if IsShiftKeyDown and IsShiftKeyDown() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    if C_GossipInfo and C_GossipInfo.GetOptions then
        local activeQuests = (C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()) or {}
        local availQuests = (C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests()) or {}
        if #activeQuests > 0 or #availQuests > 0 then return false end

        local options = C_GossipInfo.GetOptions() or {}
        if #options ~= 2 then return false end

        local selectableIdx = nil
        local selectableOpt = nil
        local selectableCount = 0

        for i = 1, 2 do
            local opt = options[i]
            if opt and not opt.disabled then
                selectableCount = selectableCount + 1
                selectableIdx = i
                selectableOpt = opt
            end
        end

        if selectableCount == 1 and selectableOpt then
            if selectableOpt.gossipOptionID and C_GossipInfo.SelectOption then
                C_GossipInfo.SelectOption(selectableOpt.gossipOptionID)
            elseif C_GossipInfo.SelectOption then
                C_GossipInfo.SelectOption(selectableIdx)
            elseif SelectGossipOption then
                SelectGossipOption(selectableIdx)
            end
            FNPA:DebugLog("Selected 2-step vendor gossip option " .. tostring(selectableIdx))
            openVendor()
            return true
        end
    end

    return false
end
