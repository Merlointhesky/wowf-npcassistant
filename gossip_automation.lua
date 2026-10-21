-- gossip_automation.lua for ForeverNPCAssistant
local addonName, FNPA = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("QUEST_GREETING")

frame:SetScript("OnEvent", function(self, event, ...)
    FNPA:DebugLog("GossipAutomation event: " .. tostring(event))
    if FNPA.settings and FNPA.settings.autoSkipGossip == false then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end

    if event == "GOSSIP_SHOW" then
        local attempts = 0

        local function checkGossip()
            attempts = attempts + 1
            local numModernOpts, numActive, numAvail = 0, 0, 0

            if C_GossipInfo and C_GossipInfo.GetOptions then
                local options = C_GossipInfo.GetOptions() or {}
                local activeQuests = C_GossipInfo.GetActiveQuests() or {}
                local availQuests = C_GossipInfo.GetAvailableQuests() or {}

                numModernOpts = #options
                numActive = #activeQuests
                numAvail = #availQuests

                if numModernOpts == 1 and numActive == 0 and numAvail == 0 then
                    local optID = options[1].gossipOptionID
                    if optID then
                        C_GossipInfo.SelectOption(optID)
                    else
                        C_GossipInfo.SelectOption(1)
                    end
                    if SelectGossipOption then SelectGossipOption(1) end
                    return
                end
            else
                local legacyNum = GetNumGossipOptions and GetNumGossipOptions() or 0
                local legacyActive = GetNumGossipActiveQuests and GetNumGossipActiveQuests() or 0
                local legacyAvail = GetNumGossipAvailableQuests and GetNumGossipAvailableQuests() or 0

                if legacyNum == 1 and legacyActive == 0 and legacyAvail == 0 then
                    if SelectGossipOption then SelectGossipOption(1) end
                    return
                end
            end

            if numModernOpts == 0 and attempts < 4 then
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.05, checkGossip)
                end
            end
        end

        checkGossip()

    elseif event == "QUEST_GREETING" then
        local numGreetingOpts = GetNumGreetingOptions and GetNumGreetingOptions() or 0
        local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
        local numAvail = GetNumAvailableQuests and GetNumAvailableQuests() or 0

        if numGreetingOpts == 1 and numActive == 0 and numAvail == 0 then
            if SelectGreetingOption then SelectGreetingOption(1) end
        end
    end
end)