-- options.lua for ForeverNPCAssistant
local addonName, FNPA = ...
FNPA = FNPA or _G.ForeverNPCAssistant

local defaults = {
    autoAccept = true,
    acceptLowLevelQuests = false,
    autoComplete = true,
    autoSkipGossip = true,
    rewardHighlight = true,
    autoEquipPrompt = true,
    minimapPos = 225,
    debugUI = false,
}

local configFrame = CreateFrame("Frame", "ForeverNPCAssistantOptionsPanel", UIParent, "BackdropTemplate,BasicFrameTemplateWithInset")
configFrame:SetSize(330, 320)
configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
configFrame:SetMovable(true)
configFrame:EnableMouse(true)
configFrame:RegisterForDrag("LeftButton")
configFrame:SetScript("OnDragStart", configFrame.StartMoving)
configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
configFrame:SetFrameStrata("DIALOG")
configFrame:Hide()

if configFrame.TitleText then
    configFrame.TitleText:SetText("Forever NPC Assistant")
end

local optionCheckButtons = {}

function FNPA:RefreshOptionCheckboxes()
    if not ForeverNPCAssistantDB then return end
    for key, cb in pairs(optionCheckButtons) do
        cb:SetChecked(ForeverNPCAssistantDB[key] and true or false)
    end
end

local function ToggleOptions()
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        FNPA:RefreshOptionCheckboxes()
        configFrame:Show()
    end
end
FNPA.ToggleOptions = ToggleOptions

local function InitOptionsPanel()
    local function createCheck(label, settingKey, yOffset)
        local cb = CreateFrame("CheckButton", "ForeverNPCAssistantCheck_" .. settingKey, configFrame, "InterfaceOptionsCheckButtonTemplate")
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, yOffset)

        local cbName = (cb.GetName and cb:GetName()) or ("ForeverNPCAssistantCheck_" .. settingKey)
        local text = cb.Text or _G[cbName .. "Text"]
        if text and text.SetText then text:SetText(label) end

        cb:SetChecked(ForeverNPCAssistantDB[settingKey])
        cb:SetScript("OnClick", function(self)
            ForeverNPCAssistantDB[settingKey] = self:GetChecked() and true or false
            if settingKey == "debugUI" and ForeverNPCAssistantDB.debugUI then
                FNPA:SetupDebugHooks()
            end
        end)
        optionCheckButtons[settingKey] = cb
    end

    createCheck("Auto-accept quests", "autoAccept", -40)
    createCheck("Always auto-accept low-level quests", "acceptLowLevelQuests", -68)
    createCheck("Auto-complete simple quests", "autoComplete", -96)
    createCheck("Auto-skip gossip & vendor dialogs", "autoSkipGossip", -124)
    createCheck("Highlight upgrade quest rewards", "rewardHighlight", -152)
    createCheck("Prompt to equip upgrade rewards", "autoEquipPrompt", -180)
    createCheck("Debug UI & event logging", "debugUI", -208)

    local testBtn = CreateFrame("Button", nil, configFrame, "GameMenuButtonTemplate")
    testBtn:SetPoint("BOTTOMLEFT", 20, 16)
    testBtn:SetSize(130, 24)
    testBtn:SetText("Test Popup")
    testBtn:SetScript("OnClick", function()
        if FNPA.TestUpgradePopup then
            FNPA:TestUpgradePopup()
        end
    end)

    local closeBtn = CreateFrame("Button", nil, configFrame, "GameMenuButtonTemplate")
    closeBtn:SetPoint("BOTTOMRIGHT", -20, 16)
    closeBtn:SetSize(130, 24)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        configFrame:Hide()
    end)
end

local function UpdateMinimapButtonPosition(button, angle)
    local width = (Minimap and Minimap:GetWidth()) or 140
    if width == 0 then width = 140 end
    local radius = (width / 2) + 12
    local rad = math.rad(angle)
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap or UIParent, "CENTER", x, y)
end

local minimapButton = nil

local function CreateMinimapButton()
    if not Minimap or minimapButton then return end

    local button = CreateFrame("Button", "ForeverNPCAssistantMiniMapButton", Minimap)
    minimapButton = button
    button:SetSize(33, 33)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(10)

    -- Inner Icon (Official Blizzard Dimensions)
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(21, 21)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    -- Circular Tracking Border Overlay (Official Blizzard Dimensions)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    UpdateMinimapButtonPosition(button, ForeverNPCAssistantDB.minimapPos or 225)

    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            ForeverNPCAssistantDB.minimapPos = angle
            UpdateMinimapButtonPosition(self, angle)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function() self.isDragging = false end)
        else
            self.isDragging = false
        end
    end)

    button:SetScript("OnMouseUp", function(self, btn)
        if not self.isDragging and btn == "LeftButton" then
            ToggleOptions()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Forever NPC Assistant", 1, 1, 1)
        if ForeverNPCAssistantDB then
            local trackingLow = FNPA.IsTrackingLowLevelQuests and FNPA:IsTrackingLowLevelQuests()
            local lowStatus = ForeverNPCAssistantDB.acceptLowLevelQuests and "|cff00ff00Always|r"
                or (trackingLow and "|cff00ff00Auto (Minimap Tracking)|r" or "|cffffaa00Ignored|r")
            GameTooltip:AddDoubleLine("Auto-Accept Quests:", ForeverNPCAssistantDB.autoAccept and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
            GameTooltip:AddDoubleLine("Low-Level Quests:", lowStatus)
            GameTooltip:AddDoubleLine("Auto-Complete Quests:", ForeverNPCAssistantDB.autoComplete and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
            GameTooltip:AddDoubleLine("Auto-Skip Gossip:", ForeverNPCAssistantDB.autoSkipGossip and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
            GameTooltip:AddDoubleLine("Highlight Upgrades:", ForeverNPCAssistantDB.rewardHighlight and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
            GameTooltip:AddDoubleLine("Equip Upgrade Prompt:", ForeverNPCAssistantDB.autoEquipPrompt and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Hold Shift when talking to NPCs to pause automation.", 1, 0.82, 0, true)
        GameTooltip:AddLine("Left-click to open options.", 0.2, 1, 0.2, true)
        GameTooltip:AddLine("Drag to position around minimap.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button:Show()
end

FNPA.Events = FNPA.Events or {}

FNPA.Events["ADDON_LOADED"] = function(self, loadedAddon)
    if loadedAddon == addonName or loadedAddon == "ForeverNPCAssistant" then
        if type(ForeverNPCAssistantDB) ~= "table" then
            ForeverNPCAssistantDB = {}
        end
        for k, v in pairs(defaults) do
            if ForeverNPCAssistantDB[k] == nil then
                ForeverNPCAssistantDB[k] = v
            end
        end
        FNPA.settings = ForeverNPCAssistantDB

        InitOptionsPanel()
        CreateMinimapButton()
        if FNPA.settings.debugUI then
            FNPA:SetupDebugHooks()
        end
    end
end

FNPA.Events["PLAYER_LOGIN"] = function(self)
    if type(ForeverNPCAssistantDB) == "table" then
        CreateMinimapButton()
    end
end

-- Slash Commands (/npcassist and /fnpa)
SLASH_FOREVERNPCASSISTANT1 = "/npcassist"
SLASH_FOREVERNPCASSISTANT2 = "/fnpa"
SlashCmdList["FOREVERNPCASSISTANT"] = function(msg)
    local cleanMsg = msg and (strtrim and strtrim(msg) or msg:gsub("^%s*(.-)%s*$", "%1")):lower() or ""
    if cleanMsg == "on" then
        if ForeverNPCAssistantDB then
            ForeverNPCAssistantDB.autoAccept = true
            ForeverNPCAssistantDB.autoComplete = true
            ForeverNPCAssistantDB.autoSkipGossip = true
            FNPA:RefreshOptionCheckboxes()
            print("|cff00ff00[Forever NPC Assistant]|r Automation enabled.")
        end
    elseif cleanMsg == "off" then
        if ForeverNPCAssistantDB then
            ForeverNPCAssistantDB.autoAccept = false
            ForeverNPCAssistantDB.autoComplete = false
            ForeverNPCAssistantDB.autoSkipGossip = false
            FNPA:RefreshOptionCheckboxes()
            print("|cff00ff00[Forever NPC Assistant]|r Automation disabled.")
        end
    elseif cleanMsg == "status" then
        if ForeverNPCAssistantDB then
            local trackingLow = FNPA.IsTrackingLowLevelQuests and FNPA:IsTrackingLowLevelQuests()
            local lowStatus = ForeverNPCAssistantDB.acceptLowLevelQuests and "|cff00ff00ON (Always)|r"
                or (trackingLow and "|cff00ff00ON (Tracking Low-Level Quests)|r" or "|cffffaa00Ignored (Default)|r")
            print("|cff00ff00[Forever NPC Assistant] Status:|r")
            print("  Auto-Accept Quests: " .. (ForeverNPCAssistantDB.autoAccept and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
            print("  Low-Level Quests: " .. lowStatus)
            print("  Auto-Complete Quests: " .. (ForeverNPCAssistantDB.autoComplete and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
            print("  Auto-Skip Gossip: " .. (ForeverNPCAssistantDB.autoSkipGossip and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
            print("  Highlight Upgrades: " .. (ForeverNPCAssistantDB.rewardHighlight and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
            print("  Equip Upgrade Prompt: " .. (ForeverNPCAssistantDB.autoEquipPrompt and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        end
    elseif cleanMsg == "lowlevel" or cleanMsg == "low" or cleanMsg == "trivial" then
        if ForeverNPCAssistantDB then
            ForeverNPCAssistantDB.acceptLowLevelQuests = not ForeverNPCAssistantDB.acceptLowLevelQuests
            FNPA:RefreshOptionCheckboxes()
            print("|cff00ff00[Forever NPC Assistant]|r Always auto-accept low-level quests: " .. (ForeverNPCAssistantDB.acceptLowLevelQuests and "|cff00ff00ON|r" or "|cffff0000OFF (follows minimap tracking)|r"))
        end
    elseif cleanMsg == "debug" then
        if ForeverNPCAssistantDB then
            ForeverNPCAssistantDB.debugUI = not ForeverNPCAssistantDB.debugUI
            if ForeverNPCAssistantDB.debugUI then FNPA:SetupDebugHooks() end
            FNPA:RefreshOptionCheckboxes()
            print("|cff00ff00[Forever NPC Assistant]|r Debug logging: " .. (ForeverNPCAssistantDB.debugUI and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        end
    elseif cleanMsg == "test" then
        if FNPA.TestUpgradePopup then
            FNPA:TestUpgradePopup()
        end
    elseif cleanMsg == "help" then
        print("|cff00ff00Forever NPC Assistant commands:|r")
        print("  |cffffff00/npcassist|r (or |cffffff00/fnpa|r) - Toggle configuration window")
        print("  |cffffff00/npcassist on|r / |cffffff00off|r - Enable or disable NPC automation")
        print("  |cffffff00/npcassist lowlevel|r - Toggle always auto-accepting low-level quests")
        print("  |cffffff00/npcassist status|r - Show current settings")
        print("  |cffffff00/npcassist test|r - Preview upgrade equip popup")
        print("  |cffffff00/npcassist debug|r - Toggle debug logging")
    else
        ToggleOptions()
    end
end
