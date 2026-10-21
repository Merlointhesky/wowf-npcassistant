-- core.lua for ForeverNPCAssistant
local addonName, FNPA = ...
_G.ForeverNPCAssistant = FNPA

FNPA.Events = FNPA.Events or {}

-- Silent debug logger (no chat spam)
function FNPA:DebugLog(msg)
    if self.settings and self.settings.debugUI then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[FNPA Debug] " .. msg)
    end
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

-- Debug UI hooks (optional)
function FNPA:SetupDebugHooks()
    if not self.settings or not self.settings.debugUI then return end
    hooksecurefunc("ShowUIPanel", function(frame)
        local name = frame.GetName and frame:GetName() or "<unnamed>"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100[FNPA Debug] Show: " .. name)
    end)
    hooksecurefunc("HideUIPanel", function(frame)
        local name = frame.GetName and frame:GetName() or "<unnamed>"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100[FNPA Debug] Hide: " .. name)
    end)
    local mt = getmetatable(CreateFrame("Frame"))
    if mt then
        hooksecurefunc(mt, "Show", function(self)
            local name = self.GetName and self:GetName() or "<unnamed>"
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100[FNPA Debug] Show: " .. name)
        end)
        hooksecurefunc(mt, "Hide", function(self)
            local name = self.GetName and self:GetName() or "<unnamed>"
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100[FNPA Debug] Hide: " .. name)
        end)
    end
end