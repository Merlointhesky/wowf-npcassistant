-- gossip_automation.lua for ForeverNPCAssistant
local addonName, FNPA = ...
FNPA = FNPA or _G.ForeverNPCAssistant
FNPA.Events = FNPA.Events or {}

-- Track accepted and attempted quests so multi-quest NPCs rotate cleanly
local recentlyAcceptedQuests = {}
local lastAttemptedQuestKey = nil
local lastAttemptedQuestAt = 0

local function GetNow()
    return (GetTime and GetTime()) or 0
end

local function StripColorCodes(text)
    if type(text) ~= "string" then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function IsInteractionAllowed()
    if IsShiftKeyDown and IsShiftKeyDown() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    return true
end

local function IsGossipSkipAllowed()
    if FNPA.settings and FNPA.settings.autoSkipGossip == false then return false end
    return IsInteractionAllowed()
end

local function IsAutoAcceptAllowed()
    if FNPA.settings and FNPA.settings.autoAccept == false then return false end
    return IsInteractionAllowed()
end

local function IsAutoCompleteAllowed()
    if FNPA.settings and FNPA.settings.autoComplete == false then return false end
    return IsInteractionAllowed()
end

-------------------------------------------------------------------------------
-- Low-Level (Trivial) Quest Tracking & Threshold Detection
-------------------------------------------------------------------------------
function FNPA:IsTrackingLowLevelQuests()
    -- 1. Modern C_Minimap tracking API
    if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
        local ok, num = pcall(C_Minimap.GetNumTrackingTypes)
        if ok and type(num) == "number" and num > 0 then
            local trivialName = (type(MINIMAP_TRACKING_TRIVIAL_QUESTS) == "string" and MINIMAP_TRACKING_TRIVIAL_QUESTS:lower()) or "low level"
            for i = 1, num do
                local okInfo, a, b, c = pcall(C_Minimap.GetTrackingInfo, i)
                if okInfo then
                    local name, active, spellID
                    if type(a) == "table" then
                        name = a.name
                        active = a.active
                        spellID = a.spellID
                    else
                        name = a
                        active = c
                    end
                    local lowerName = type(name) == "string" and name:lower() or ""
                    if spellID == 135982 or lowerName == trivialName or lowerName:find("trivial") or lowerName:find("low level") or lowerName:find("low%-level") then
                        return active and true or false
                    end
                end
            end
        end
    end

    -- 2. Legacy GetNumTrackingTypes / GetTrackingInfo
    if GetNumTrackingTypes and GetTrackingInfo then
        local ok, num = pcall(GetNumTrackingTypes)
        if ok and type(num) == "number" and num > 0 then
            local trivialName = (type(MINIMAP_TRACKING_TRIVIAL_QUESTS) == "string" and MINIMAP_TRACKING_TRIVIAL_QUESTS:lower()) or "low level"
            for i = 1, num do
                local okInfo, name, _, active = pcall(GetTrackingInfo, i)
                if okInfo and type(name) == "string" then
                    local lowerName = name:lower()
                    if lowerName == trivialName or lowerName:find("trivial") or lowerName:find("low level") or lowerName:find("low%-level") then
                        return active and true or false
                    end
                end
            end
        end
    end

    -- 3. Classic / Forever C_CVar or GetCVar fallbacks
    local cvarNames = { "showLowLevelQuests", "trackLowLevelQuests", "trivialQuests" }
    for _, cvar in ipairs(cvarNames) do
        if C_CVar and C_CVar.GetCVarBool then
            local ok, val = pcall(C_CVar.GetCVarBool, cvar)
            if ok and val == true then return true end
        elseif GetCVarBool then
            local ok, val = pcall(GetCVarBool, cvar)
            if ok and val == true then return true end
        end
    end

    return false
end

function FNPA:ShouldAcceptLowLevelQuests()
    if self.settings and self.settings.acceptLowLevelQuests then
        return true
    end
    return self:IsTrackingLowLevelQuests()
end

-- Classic / Forever gray quest level cutoff relative to player level
function FNPA:IsQuestLevelTrivial(questLevel)
    questLevel = tonumber(questLevel)
    if not questLevel or questLevel <= 0 then return false end
    local playerLevel = (UnitLevel and UnitLevel("player")) or 60
    local cutoff
    if playerLevel <= 5 then
        cutoff = 0
    elseif playerLevel <= 39 then
        cutoff = playerLevel - math.floor(playerLevel / 10) - 5
    else
        cutoff = playerLevel - math.floor(playerLevel / 5) - 1
    end
    return questLevel <= cutoff
end

function FNPA:IsQuestTrivialInfo(isTrivialFlag, questLevel)
    if isTrivialFlag == true or isTrivialFlag == 1 then
        return true
    end
    if isTrivialFlag == false then
        return false
    end
    return self:IsQuestLevelTrivial(questLevel)
end

-------------------------------------------------------------------------------
-- Quest Log & Rotation State Helpers
-------------------------------------------------------------------------------
function FNPA:IsQuestAlreadyPickedUp(questID, title)
    local numID = tonumber(questID)
    if numID and numID > 0 then
        if C_QuestLog then
            if C_QuestLog.IsOnQuest then
                local ok, onQuest = pcall(C_QuestLog.IsOnQuest, numID)
                if ok and onQuest then return true end
            end
            if C_QuestLog.GetLogIndexForQuestID then
                local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, numID)
                if ok and idx and idx > 0 then return true end
            end
        end
        if recentlyAcceptedQuests["id:" .. numID] and (GetNow() - recentlyAcceptedQuests["id:" .. numID]) < 30 then
            return true
        end
    end

    local cleanTitle = StripColorCodes(title or "")
    if cleanTitle ~= "" then
        if recentlyAcceptedQuests["title:" .. cleanTitle:lower()] and (GetNow() - recentlyAcceptedQuests["title:" .. cleanTitle:lower()]) < 30 then
            return true
        end
        if GetNumQuestLogEntries and GetQuestLogTitle then
            local ok, numEntries = pcall(GetNumQuestLogEntries)
            if ok and type(numEntries) == "number" then
                for i = 1, numEntries do
                    local qTitle, _, _, isHeader, _, _, _, qID = GetQuestLogTitle(i)
                    if not isHeader then
                        if numID and numID > 0 and qID == numID then
                            return true
                        end
                        if qTitle and StripColorCodes(qTitle):lower() == cleanTitle:lower() then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

function FNPA:MarkQuestAccepted(questID, title)
    local now = GetNow()
    local numID = tonumber(questID)
    if numID and numID > 0 then
        recentlyAcceptedQuests["id:" .. numID] = now
    end
    local cleanTitle = StripColorCodes(title or "")
    if cleanTitle ~= "" then
        recentlyAcceptedQuests["title:" .. cleanTitle:lower()] = now
    end
end

local function BuildQuestCandidateKey(questID, title, index)
    local numID = tonumber(questID)
    if numID and numID > 0 then
        return "id:" .. numID
    end
    local cleanTitle = StripColorCodes(title or "")
    if cleanTitle ~= "" then
        return "title:" .. cleanTitle:lower()
    end
    return "idx:" .. tostring(index or 1)
end

-- From a list of eligible available quest candidates, pick the next unaccepted one,
-- rotating past the most recently attempted candidate if it is still in the list.
local function ChooseNextQuestCandidate(candidates)
    if #candidates == 0 then return nil end

    -- 1. Prefer candidates that haven't been picked up yet
    local unpicked = {}
    for _, c in ipairs(candidates) do
        if not FNPA:IsQuestAlreadyPickedUp(c.questID, c.title) then
            table.insert(unpicked, c)
        end
    end

    local pool = (#unpicked > 0) and unpicked or candidates
    if #pool == 1 then
        local chosen = pool[1]
        lastAttemptedQuestKey = chosen.key
        lastAttemptedQuestAt = GetNow()
        return chosen
    end

    -- 2. If multiple quests are available, rotate past the last attempted one
    local startIdx = 1
    if lastAttemptedQuestKey and (GetNow() - lastAttemptedQuestAt) < 15 then
        for i, c in ipairs(pool) do
            if c.key == lastAttemptedQuestKey then
                startIdx = (i % #pool) + 1
                break
            end
        end
    end

    local chosen = pool[startIdx]
    lastAttemptedQuestKey = chosen.key
    lastAttemptedQuestAt = GetNow()
    return chosen
end

-------------------------------------------------------------------------------
-- Gossip Frame Quest & Option Automation (GOSSIP_SHOW)
-------------------------------------------------------------------------------
local function TrySelectGossipActiveQuest(activeQuests)
    if not IsAutoCompleteAllowed() then return false end

    if C_GossipInfo and C_GossipInfo.GetActiveQuests and type(activeQuests) == "table" then
        for idx, q in ipairs(activeQuests) do
            if type(q) == "table" and q.isComplete then
                if q.questID and C_GossipInfo.SelectActiveQuest then
                    FNPA:DebugLog("Selecting completable modern gossip active questID: " .. tostring(q.questID))
                    C_GossipInfo.SelectActiveQuest(q.questID)
                    return true
                elseif SelectGossipActiveQuest then
                    FNPA:DebugLog("Selecting completable gossip active quest index: " .. tostring(idx))
                    SelectGossipActiveQuest(idx)
                    return true
                end
            end
        end
    elseif GetGossipActiveQuests and SelectGossipActiveQuest then
        local raw = { GetGossipActiveQuests() }
        if #raw > 0 then
            -- Legacy returns 6 values per quest: title, level, isLowLevel, isComplete, isLegendary, isIgnored
            -- (or 4 in older 1.12: title, level, isLowLevel, isComplete)
            local stride = (#raw >= 6 and type(raw[4]) == "boolean" and type(raw[5]) == "boolean") and 6 or 4
            local qIndex = 1
            for i = 1, #raw, stride do
                local isComplete = raw[i + 3]
                if isComplete then
                    FNPA:DebugLog("Selecting completable legacy gossip active quest index: " .. tostring(qIndex))
                    SelectGossipActiveQuest(qIndex)
                    return true
                end
                qIndex = qIndex + 1
            end
        end
    end

    return false
end

local function TrySelectGossipAvailableQuest(availQuests)
    if not IsAutoAcceptAllowed() then return false end
    local allowLowLevel = FNPA:ShouldAcceptLowLevelQuests()
    local candidates = {}

    if C_GossipInfo and C_GossipInfo.GetAvailableQuests and type(availQuests) == "table" and #availQuests > 0 then
        for idx, q in ipairs(availQuests) do
            if type(q) == "table" then
                local isTrivial = FNPA:IsQuestTrivialInfo(q.isTrivial, q.questLevel)
                if not q.isIgnored and (not isTrivial or allowLowLevel) then
                    table.insert(candidates, {
                        index = idx,
                        orderIndex = q.orderIndex,
                        questID = q.questID,
                        title = q.title,
                        key = BuildQuestCandidateKey(q.questID, q.title, idx),
                        modern = true,
                    })
                else
                    FNPA:DebugLog("Skipping low-level/ignored gossip quest: " .. tostring(q.title))
                end
            end
        end
    elseif GetGossipAvailableQuests and SelectGossipAvailableQuest then
        local raw = { GetGossipAvailableQuests() }
        if #raw > 0 then
            -- Legacy returns 7 values per quest (title, level, isTrivial, frequency, isRepeatable, isLegendary, isIgnored)
            -- or 5/3 values in older clients
            local stride = 7
            if #raw % 7 ~= 0 then
                stride = (#raw % 5 == 0) and 5 or 3
            end
            local qIndex = 1
            for i = 1, #raw, stride do
                local title = raw[i]
                local level = raw[i + 1]
                local isTrivialFlag = raw[i + 2]
                local isIgnored = (stride >= 7) and raw[i + 6] or false
                local isTrivial = FNPA:IsQuestTrivialInfo(isTrivialFlag, level)
                if not isIgnored and (not isTrivial or allowLowLevel) then
                    table.insert(candidates, {
                        index = qIndex,
                        title = title,
                        key = BuildQuestCandidateKey(nil, title, qIndex),
                        modern = false,
                    })
                else
                    FNPA:DebugLog("Skipping low-level/ignored legacy gossip quest: " .. tostring(title))
                end
                qIndex = qIndex + 1
            end
        end
    end

    local chosen = ChooseNextQuestCandidate(candidates)
    if not chosen then return false end

    if chosen.modern then
        if chosen.questID and C_GossipInfo.SelectAvailableQuest then
            FNPA:DebugLog("Selecting modern gossip available questID: " .. tostring(chosen.questID) .. " (" .. tostring(chosen.title) .. ")")
            C_GossipInfo.SelectAvailableQuest(chosen.questID)
            return true
        elseif C_GossipInfo.SelectAvailableQuest then
            FNPA:DebugLog("Selecting modern gossip available quest index: " .. tostring(chosen.index))
            C_GossipInfo.SelectAvailableQuest(chosen.orderIndex or chosen.index)
            return true
        elseif SelectGossipAvailableQuest then
            SelectGossipAvailableQuest(chosen.index)
            return true
        end
    elseif SelectGossipAvailableQuest then
        FNPA:DebugLog("Selecting legacy gossip available quest index: " .. tostring(chosen.index) .. " (" .. tostring(chosen.title) .. ")")
        SelectGossipAvailableQuest(chosen.index)
        return true
    end

    return false
end

FNPA.Events["GOSSIP_SHOW"] = function(self)
    FNPA:DebugLog("GossipAutomation event: GOSSIP_SHOW")
    if not IsInteractionAllowed() then return end

    local attempts = 0

    local function checkGossip()
        if not IsInteractionAllowed() then return end
        attempts = attempts + 1
        local numModernOpts, numActive, numAvail = 0, 0, 0

        if C_GossipInfo and (C_GossipInfo.GetOptions or C_GossipInfo.GetAvailableQuests) then
            local options = (C_GossipInfo.GetOptions and C_GossipInfo.GetOptions()) or {}
            local activeQuests = (C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()) or {}
            local availQuests = (C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests()) or {}

            numModernOpts = #options
            numActive = #activeQuests
            numAvail = #availQuests

            -- 1. Turn in completable active quests first
            if numActive > 0 and TrySelectGossipActiveQuest(activeQuests) then
                return
            end

            -- 2. Pick up available quests (rotating across multiple quests & respecting low-level filter)
            if numAvail > 0 and TrySelectGossipAvailableQuest(availQuests) then
                return
            end

            -- 3. Auto-skip single gossip option only when no quests are present on the NPC
            if IsGossipSkipAllowed() and numModernOpts == 1 and numActive == 0 and numAvail == 0 then
                local optID = options[1].gossipOptionID
                if optID and C_GossipInfo.SelectOption then
                    FNPA:DebugLog("Selecting modern gossip option ID: " .. tostring(optID))
                    C_GossipInfo.SelectOption(optID)
                elseif C_GossipInfo.SelectOptionByIndex and options[1].orderIndex then
                    FNPA:DebugLog("Selecting modern gossip orderIndex: " .. tostring(options[1].orderIndex))
                    C_GossipInfo.SelectOptionByIndex(options[1].orderIndex)
                elseif C_GossipInfo.SelectOption then
                    C_GossipInfo.SelectOption(1)
                elseif SelectGossipOption then
                    SelectGossipOption(1)
                end
                return
            end
        else
            local legacyNum = GetNumGossipOptions and GetNumGossipOptions() or 0
            local legacyActive = GetNumGossipActiveQuests and GetNumGossipActiveQuests() or 0
            local legacyAvail = GetNumGossipAvailableQuests and GetNumGossipAvailableQuests() or 0

            numActive = legacyActive
            numAvail = legacyAvail

            if legacyActive > 0 and TrySelectGossipActiveQuest(nil) then
                return
            end

            if legacyAvail > 0 and TrySelectGossipAvailableQuest(nil) then
                return
            end

            if IsGossipSkipAllowed() and legacyNum == 1 and legacyActive == 0 and legacyAvail == 0 then
                if SelectGossipOption then
                    FNPA:DebugLog("Selecting legacy gossip option 1")
                    SelectGossipOption(1)
                end
                return
            end
        end

        -- Delegate to 2-step single selectable option vendor check if available
        if FNPA.CheckTwoStepVendorGossip and FNPA:CheckTwoStepVendorGossip() then
            return
        end

        if numModernOpts == 0 and numActive == 0 and numAvail == 0 and attempts < 4 then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.05, checkGossip)
            end
        end
    end

    checkGossip()
end

-------------------------------------------------------------------------------
-- Dedicated Quest Greeting Frame Automation (QUEST_GREETING)
-------------------------------------------------------------------------------
FNPA.Events["QUEST_GREETING"] = function(self)
    FNPA:DebugLog("GossipAutomation event: QUEST_GREETING")
    if not IsInteractionAllowed() then return end

    local attempts = 0

    local function checkGreeting()
        if not IsInteractionAllowed() then return end
        attempts = attempts + 1

        local numGreetingOpts = GetNumGreetingOptions and GetNumGreetingOptions() or 0
        local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
        local numAvail = GetNumAvailableQuests and GetNumAvailableQuests() or 0

        -- 1. Check active quests that are ready to turn in
        if IsAutoCompleteAllowed() and numActive > 0 and SelectActiveQuest then
            for i = 1, numActive do
                local _, isComplete = nil, false
                if GetActiveTitle then
                    _, isComplete = GetActiveTitle(i)
                end
                if isComplete then
                    FNPA:DebugLog("Selecting completable greeting active quest index: " .. tostring(i))
                    SelectActiveQuest(i)
                    return
                end
            end
        end

        -- 2. Check available quests to pick up (rotating through unaccepted quests & filtering low-level)
        if IsAutoAcceptAllowed() and numAvail > 0 and SelectAvailableQuest then
            local allowLowLevel = FNPA:ShouldAcceptLowLevelQuests()
            local candidates = {}

            for i = 1, numAvail do
                local title = GetAvailableTitle and GetAvailableTitle(i) or nil
                local isTrivialFlag, _, _, _, questID = nil, nil, nil, nil, nil
                if GetAvailableQuestInfo then
                    isTrivialFlag, _, _, _, questID = GetAvailableQuestInfo(i)
                end
                local level = GetAvailableLevel and GetAvailableLevel(i) or nil
                local isTrivial = FNPA:IsQuestTrivialInfo(isTrivialFlag, level)

                if not isTrivial or allowLowLevel then
                    table.insert(candidates, {
                        index = i,
                        questID = questID,
                        title = title,
                        key = BuildQuestCandidateKey(questID, title, i),
                    })
                else
                    FNPA:DebugLog("Skipping low-level greeting quest: " .. tostring(title))
                end
            end

            local chosen = ChooseNextQuestCandidate(candidates)
            if chosen then
                FNPA:DebugLog("Selecting greeting available quest index: " .. tostring(chosen.index) .. " (" .. tostring(chosen.title) .. ")")
                SelectAvailableQuest(chosen.index)
                return
            end
        end

        -- 3. Single greeting option fallback when no quests are available
        if IsGossipSkipAllowed() and numGreetingOpts == 1 and numActive == 0 and numAvail == 0 then
            if SelectGreetingOption then
                FNPA:DebugLog("Selecting greeting option 1")
                SelectGreetingOption(1)
                return
            end
        end

        if numGreetingOpts == 0 and numActive == 0 and numAvail == 0 and attempts < 4 then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.05, checkGreeting)
            end
        end
    end

    checkGreeting()
end
