-- core.lua for ForeverNPCAssistant (WoW Forever 1.6 / Interface 16001)
local addonName, FNPA = ...
_G.ForeverNPCAssistant = FNPA

FNPA.Events = FNPA.Events or {}

-- Silent debug logger (enabled via options or /npcassist debug)
function FNPA:DebugLog(msg)
    if self.settings and self.settings.debugUI then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[FNPA Debug]|r " .. tostring(msg))
    end
end

-- Legacy alias used by submodules
FNPA.debug = function(msg)
    FNPA:DebugLog(msg)
end

-- Centralized Event Frame
local eventFrame = CreateFrame("Frame", "ForeverNPCAssistantEventFrame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if FNPA.Events and FNPA.Events[event] then
        FNPA.Events[event](FNPA, ...)
    end
end)

function FNPA:RegisterEventSafe(event)
    pcall(function()
        eventFrame:RegisterEvent(event)
    end)
end

FNPA:RegisterEventSafe("ADDON_LOADED")
FNPA:RegisterEventSafe("PLAYER_LOGIN")
FNPA:RegisterEventSafe("GOSSIP_SHOW")
FNPA:RegisterEventSafe("QUEST_GREETING")
FNPA:RegisterEventSafe("QUEST_DETAIL")
FNPA:RegisterEventSafe("QUEST_PROGRESS")
FNPA:RegisterEventSafe("QUEST_COMPLETE")
FNPA:RegisterEventSafe("QUEST_ACCEPT_CONFIRM")
FNPA:RegisterEventSafe("QUEST_ACCEPTED")
FNPA:RegisterEventSafe("QUEST_TURNED_IN")
FNPA:RegisterEventSafe("GET_ITEM_INFO_RECEIVED")
FNPA:RegisterEventSafe("BAG_UPDATE_DELAYED")
FNPA:RegisterEventSafe("PLAYER_REGEN_ENABLED")

-- Safe UI Panel Debug Hooks (only hooks ShowUIPanel/HideUIPanel once when requested)
local debugHooksInstalled = false
function FNPA:SetupDebugHooks()
    if debugHooksInstalled then return end
    if not self.settings or not self.settings.debugUI then return end
    debugHooksInstalled = true

    if hooksecurefunc then
        hooksecurefunc("ShowUIPanel", function(frame)
            if not FNPA.settings or not FNPA.settings.debugUI then return end
            local name = frame and frame.GetName and frame:GetName() or "<unnamed>"
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100[FNPA Debug] ShowUIPanel:|r " .. tostring(name))
        end)
        hooksecurefunc("HideUIPanel", function(frame)
            if not FNPA.settings or not FNPA.settings.debugUI then return end
            local name = frame and frame.GetName and frame:GetName() or "<unnamed>"
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100[FNPA Debug] HideUIPanel:|r " .. tostring(name))
        end)
    end
end
