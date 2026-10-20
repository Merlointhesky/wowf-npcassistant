-- core.lua for ForeverNPCAssistant
local addonName, FNPA = ...
_G.ForeverNPCAssistant = FNPA

FNPA.Events = FNPA.Events or {}

-- Silent debug logger (no chat spam)
function FNPA:DebugLog(msg) end

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