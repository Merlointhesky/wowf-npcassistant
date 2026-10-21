-- options.lua for ForeverNPCAssistant
local addonName, FNPA = ...

local defaults = {
    autoAccept = true,
    autoComplete = true,
    autoSkipGossip = true,
    rewardHighlight = true,
    minimapPos = 225,
    debugUI = false,
}

local configFrame = CreateFrame("Frame", "ForeverNPCAssistantOptionsPanel", UIParent, "BackdropTemplate,BasicFrameTemplateWithInset")
configFrame:SetSize(280, 220)
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

local function ToggleOptions()
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
end

local function InitOptionsPanel()
    local function createCheck(label, settingKey, yOffset)
        local cb = CreateFrame("CheckButton", "ForeverNPCAssistantCheck_" .. settingKey, configFrame, "InterfaceOptionsCheckButtonTemplate")
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, yOffset)
        
        local text = cb.Text or _G[cb:GetName() .. "Text"]
        if text then text:SetText(label) end

        cb:SetChecked(ForeverNPCAssistantDB[settingKey])
        cb:SetScript("OnClick", function(self)
            ForeverNPCAssistantDB[settingKey] = self:GetChecked() and true or false
        end)
    end

    createCheck("Auto-accept quests", "autoAccept", -45)
    createCheck("Auto-complete simple quests", "autoComplete", -75)
    createCheck("Auto-skip gossip dialogs", "autoSkipGossip", -105)
    createCheck("Highlight upgrade quest rewards", "rewardHighlight", -135)
    createCheck("Debug UI window events", "debugUI", -165)
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

local function CreateMinimapButton()
    if not Minimap then return end

    local button = CreateFrame("Button", "ForeverNPCAssistantMiniMapButton", Minimap)
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
        GameTooltip:AddLine("Left-click to open options.", 0.2, 1, 0.2, true)
        GameTooltip:AddLine("Drag to position around minimap.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button:Show()
end

FNPA.Events = FNPA.Events or {}

FNPA.Events["ADDON_LOADED"] = function(self, loadedAddon)
    if loadedAddon == addonName then
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
        -- Initialize debug UI hooks if enabled
        if FNPA.settings.debugUI then
            FNPA:SetupDebugHooks()
        end
    end
end