-- quest_automation.lua for ForeverNPCAssistant (Modern 16001 Engine)
local addonName, FNPA = ...

local function isEnabled(settingKey)
    if FNPA.settings and FNPA.settings[settingKey] ~= nil then
        return FNPA.settings[settingKey]
    end
    return true
end

local function isSimpleReward()
    local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
    return numChoices <= 1
end

-- Slot mapping table
local EQUIP_LOC_TO_SLOTS = {
    INVTYPE_HEAD = {1},
    INVTYPE_NECK = {2},
    INVTYPE_SHOULDER = {3},
    INVTYPE_BODY = {4},
    INVTYPE_CHEST = {5},
    INVTYPE_ROBE = {5},
    INVTYPE_WAIST = {6},
    INVTYPE_LEGS = {7},
    INVTYPE_FEET = {8},
    INVTYPE_WRIST = {9},
    INVTYPE_HAND = {10},
    INVTYPE_FINGER = {11, 12},
    INVTYPE_TRINKET = {13, 14},
    INVTYPE_CLOAK = {15},
    INVTYPE_WEAPON = {16, 17},
    INVTYPE_SHIELD = {17},
    INVTYPE_2HWEAPON = {16},
    INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_WEAPONOFFHAND = {17},
    INVTYPE_HOLDABLE = {17},
    INVTYPE_RANGED = {18},
    INVTYPE_THROWN = {18},
    INVTYPE_RANGEDRIGHT = {18},
    INVTYPE_RELIC = {18},
    INVTYPE_TABARD = {19},
}

-- Safe Item Details Fetcher
local function GetItemDetails(itemLink)
    if not itemLink then return nil end

    local name, link, rarity, ilvl, reqLevel, itemType, subType, count, equipLoc, icon, price, classID, subclassID

    if C_Item and C_Item.GetItemInfo then
        name, link, rarity, ilvl, reqLevel, itemType, subType, count, equipLoc, icon, price, classID, subclassID = C_Item.GetItemInfo(itemLink)
    end
    if not name and GetItemInfo then
        name, link, rarity, ilvl, reqLevel, itemType, subType, count, equipLoc, icon, price, classID, subclassID = GetItemInfo(itemLink)
    end

    if not name then return nil end

    return {
        name = name,
        rarity = rarity or 0,
        ilvl = ilvl or 0,
        reqLevel = reqLevel or 0,
        equipLoc = equipLoc or "",
        classID = classID,
        subclassID = subclassID,
    }
end

-- Calculates equipped item level, rarity, and armor type (Cloth=1, Leather=2, Mail=3, Plate=4)
local function GetEquippedItemLevel(equipLoc)
    local slots = EQUIP_LOC_TO_SLOTS[equipLoc]
    if not slots then return nil end

    local lowestILvl = 99999
    local lowestRarity = 999
    local equippedArmorSubclass = nil
    local has2H = false
    local mainHandILvl = nil
    local mainHandRarity = nil

    local mhLink = GetInventoryItemLink("player", 16)
    if mhLink then
        local mhInfo = GetItemDetails(mhLink)
        if mhInfo and mhInfo.equipLoc == "INVTYPE_2HWEAPON" then
            has2H = true
            mainHandILvl = mhInfo.ilvl
            mainHandRarity = mhInfo.rarity
        end
    end

    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local info = GetItemDetails(link)
            if info then
                if info.ilvl < lowestILvl then
                    lowestILvl = info.ilvl
                    lowestRarity = info.rarity
                    if info.classID == 4 and info.subclassID and info.subclassID >= 1 and info.subclassID <= 4 then
                        equippedArmorSubclass = info.subclassID
                    end
                end
            end
        else
            if slot == 17 and has2H then
                if mainHandILvl and mainHandILvl < lowestILvl then
                    lowestILvl = mainHandILvl
                    lowestRarity = mainHandRarity or 0
                end
            else
                return 0, 0, nil
            end
        end
    end

    if lowestILvl == 99999 then return 0, 0, nil end
    return lowestILvl, lowestRarity, equippedArmorSubclass
end

-- Upgrade Evaluation Logic
local function IsItemUpgrade(itemLink)
    local item = GetItemDetails(itemLink)
    if not item or not item.equipLoc or item.equipLoc == "" or not EQUIP_LOC_TO_SLOTS[item.equipLoc] then
        return false
    end

    if item.reqLevel > UnitLevel("player") then return false end

    local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
    local isProfessionTool = (item.classID == 2 and (item.subclassID == 14 or item.subclassID == 20))

    if item.classID == 2 or item.classID == 4 then
        local usable = true
        if C_PlayerInfo and C_PlayerInfo.CanUseItem and itemID then
            usable = C_PlayerInfo.CanUseItem(itemID)
        elseif C_Item and C_Item.IsUsableItem then
            usable = C_Item.IsUsableItem(itemLink)
        elseif IsUsableItem then
            usable = IsUsableItem(itemLink)
        end

        if usable == false then return false end
    end

    if isProfessionTool then return false end

    local currentIlvl, currentRarity, currentArmorSubclass = GetEquippedItemLevel(item.equipLoc)
    if not currentIlvl then return false end

    if currentIlvl == 0 then return true end

    local isBodyArmor = (item.classID == 4 and item.subclassID and item.subclassID >= 1 and item.subclassID <= 4)
    if isBodyArmor and currentArmorSubclass then
        if item.subclassID < currentArmorSubclass then
            return (item.rarity > currentRarity and item.ilvl > currentIlvl)
        end
    end

    return (item.ilvl > currentIlvl and item.rarity >= currentRarity)
end

-------------------------------------------------------------------------------
-- Custom Side-by-Side Item Preview Window
-------------------------------------------------------------------------------
local promptFrame = CreateFrame("Frame", "FNPAEquipPromptFrame", UIParent, "BackdropTemplate,BasicFrameTemplateWithInset")
promptFrame:SetSize(520, 320)
promptFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
promptFrame:SetMovable(true)
promptFrame:EnableMouse(true)
promptFrame:RegisterForDrag("LeftButton")
promptFrame:SetScript("OnDragStart", promptFrame.StartMoving)
promptFrame:SetScript("OnDragStop", promptFrame.StopMovingOrSizing)
promptFrame:SetFrameStrata("DIALOG")
promptFrame:Hide()

if promptFrame.TitleText then
    promptFrame.TitleText:SetText("FNPA - Upgrade Found!")
end

-- Header Text
local headerText = promptFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
headerText:SetPoint("TOP", promptFrame, "TOP", 0, -28)
headerText:SetText("Would you like to equip your new quest reward?")

-- Embedded Tooltip 1 (New Upgrade)
local newTooltip = CreateFrame("GameTooltip", "FNPANewItemTooltip", promptFrame, "GameTooltipTemplate")
newTooltip:SetFrameLevel(promptFrame:GetFrameLevel() + 5)

-- Embedded Tooltip 2 (Currently Equipped Item 1)
local eqTooltip1 = CreateFrame("GameTooltip", "FNPAEquippedItemTooltip1", promptFrame, "GameTooltipTemplate")
eqTooltip1:SetFrameLevel(promptFrame:GetFrameLevel() + 5)

-- Embedded Tooltip 3 (Currently Equipped Item 2 - for Off-Hand when replacing with 2H)
local eqTooltip2 = CreateFrame("GameTooltip", "FNPAEquippedItemTooltip2", promptFrame, "GameTooltipTemplate")
eqTooltip2:SetFrameLevel(promptFrame:GetFrameLevel() + 5)

-- Empty Slot Fallback Text
local emptySlotText = promptFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptySlotText:SetText("(Nothing Equipped)")

-- Column Labels
local leftLabel = promptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
leftLabel:SetText("|cFF00FF00[New Upgrade]|r")

local rightLabel = promptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rightLabel:SetText("|cFFFF5555[Currently Equipped]|r")

-- Equip Button
local equipBtn = CreateFrame("Button", "FNPAEquipButton", promptFrame, "UIPanelButtonTemplate")
equipBtn:SetSize(120, 24)
equipBtn:SetText("Equip Upgrade")
equipBtn:SetScript("OnClick", function()
    if promptFrame.newItemLink then
        if EquipItemByName then
            EquipItemByName(promptFrame.newItemLink)
        elseif C_Item and C_Item.EquipItemByName then
            C_Item.EquipItemByName(promptFrame.newItemLink)
        end
    end
    promptFrame:Hide()
end)

-- Ignore Button
local ignoreBtn = CreateFrame("Button", "FNPAIgnoreButton", promptFrame, "UIPanelButtonTemplate")
ignoreBtn:SetSize(100, 24)
ignoreBtn:SetText("Ignore")
ignoreBtn:SetScript("OnClick", function()
    promptFrame:Hide()
end)

function FNPA:PromptEquipUpgrade(newItemLink)
    if not newItemLink then return end
    promptFrame.newItemLink = newItemLink

    local item = GetItemDetails(newItemLink)
    if not item or not item.equipLoc or not EQUIP_LOC_TO_SLOTS[item.equipLoc] then return end

    -- Reset Tooltips
    newTooltip:SetOwner(promptFrame, "ANCHOR_NONE")
    newTooltip:ClearAllPoints()
    newTooltip:SetHyperlink(newItemLink)
    newTooltip:Show()

    eqTooltip1:SetOwner(promptFrame, "ANCHOR_NONE")
    eqTooltip1:ClearAllPoints()
    eqTooltip1:Hide()

    eqTooltip2:SetOwner(promptFrame, "ANCHOR_NONE")
    eqTooltip2:ClearAllPoints()
    eqTooltip2:Hide()

    emptySlotText:Hide()

    -- Gather Equipped Links
    local slots = EQUIP_LOC_TO_SLOTS[item.equipLoc]
    local eqLinks = {}

    if item.equipLoc == "INVTYPE_2HWEAPON" then
        local mhLink = GetInventoryItemLink("player", 16)
        local ohLink = GetInventoryItemLink("player", 17)
        if mhLink then table.insert(eqLinks, mhLink) end
        if ohLink then table.insert(eqLinks, ohLink) end
    elseif #slots > 1 then
        local lowestSlot = slots[1]
        local lowestILvl = 99999
        for _, slot in ipairs(slots) do
            local link = GetInventoryItemLink("player", slot)
            if link then
                local info = GetItemDetails(link)
                if info and info.ilvl < lowestILvl then
                    lowestILvl = info.ilvl
                    lowestSlot = slot
                end
            else
                lowestSlot = slot
                break
            end
        end
        local link = GetInventoryItemLink("player", lowestSlot)
        if link then table.insert(eqLinks, link) end
    else
        for _, slot in ipairs(slots) do
            local link = GetInventoryItemLink("player", slot)
            if link then table.insert(eqLinks, link) end
        end
    end

    -- Anchor Left Column
    leftLabel:ClearAllPoints()
    leftLabel:SetPoint("TOPLEFT", promptFrame, "TOPLEFT", 20, -48)
    newTooltip:SetPoint("TOPLEFT", leftLabel, "BOTTOMLEFT", 0, -4)

    -- Anchor Right Column
    local rightX = newTooltip:GetWidth() + 45
    rightLabel:ClearAllPoints()
    rightLabel:SetPoint("TOPLEFT", promptFrame, "TOPLEFT", rightX, -48)

    if #eqLinks >= 1 then
        eqTooltip1:SetHyperlink(eqLinks[1])
        eqTooltip1:SetPoint("TOPLEFT", rightLabel, "BOTTOMLEFT", 0, -4)
        eqTooltip1:Show()

        if #eqLinks >= 2 then
            eqTooltip2:SetHyperlink(eqLinks[2])
            eqTooltip2:SetPoint("TOPLEFT", eqTooltip1, "BOTTOMLEFT", 0, -6)
            eqTooltip2:Show()
        end
    else
        emptySlotText:ClearAllPoints()
        emptySlotText:SetPoint("TOPLEFT", rightLabel, "BOTTOMLEFT", 10, -20)
        emptySlotText:Show()
    end

    -- Calculate Dynamic Frame Sizing
    local leftH = newTooltip:GetHeight()
    local rightH = 0
    if eqTooltip1:IsShown() then rightH = rightH + eqTooltip1:GetHeight() end
    if eqTooltip2:IsShown() then rightH = rightH + eqTooltip2:GetHeight() + 6 end
    if emptySlotText:IsShown() then rightH = 40 end

    local rightW = math.max(eqTooltip1:IsShown() and eqTooltip1:GetWidth() or 140, eqTooltip2:IsShown() and eqTooltip2:GetWidth() or 0)
    local totalW = newTooltip:GetWidth() + rightW + 65
    local totalH = math.max(leftH, rightH) + 120

    promptFrame:SetSize(math.max(totalW, 420), math.max(totalH, 260))

    -- Position Bottom Action Buttons
    equipBtn:ClearAllPoints()
    equipBtn:SetPoint("BOTTOMRIGHT", promptFrame, "BOTTOMRIGHT", -20, 16)

    ignoreBtn:ClearAllPoints()
    ignoreBtn:SetPoint("RIGHT", equipBtn, "LEFT", -10, 0)

    promptFrame:Show()
end

-- Hook GetQuestReward to trigger the preview prompt when selecting an upgrade reward
if hooksecurefunc then
    hooksecurefunc("GetQuestReward", function(choiceIndex)
        local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
        local chosenIndex = (choiceIndex and choiceIndex > 0) and choiceIndex or ((numChoices == 1) and 1 or 0)
        
        if chosenIndex > 0 then
            local link = GetQuestItemLink("choice", chosenIndex)
            if link and IsItemUpgrade(link) then
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.5, function()
                        FNPA:PromptEquipUpgrade(link)
                    end)
                end
            end
        end
    end)
end

-- Highlight Green Box Overlay for Quest Choices
local function HighlightRewardUpgrades()
    if not isEnabled("rewardHighlight") then return end

    local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if numChoices <= 1 then return end

    for i = 1, numChoices do
        local link = GetQuestItemLink("choice", i)
        local button = QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons and QuestInfoRewardsFrame.RewardButtons[i]
        if not button then button = _G["QuestInfoItem" .. i] or _G["QuestItem" .. i] end

        if button then
            if not button.fnpaGreenBox then
                local box = CreateFrame("Frame", nil, button)
                box:SetAllPoints(button)
                box:SetFrameLevel(button:GetFrameLevel() + 10)

                local function createBorderLine()
                    local t = box:CreateTexture(nil, "OVERLAY")
                    if t.SetColorTexture then t:SetColorTexture(0, 1, 0, 1) else t:SetTexture(0, 1, 0, 1) end
                    return t
                end

                box.top = createBorderLine()
                box.top:SetPoint("TOPLEFT", box, "TOPLEFT", -2, 2)
                box.top:SetPoint("TOPRIGHT", box, "TOPRIGHT", 2, 2)
                box.top:SetHeight(3)

                box.bottom = createBorderLine()
                box.bottom:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", -2, -2)
                box.bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 2, -2)
                box.bottom:SetHeight(3)

                box.left = createBorderLine()
                box.left:SetPoint("TOPLEFT", box, "TOPLEFT", -2, 2)
                box.left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", -2, -2)
                box.left:SetWidth(3)

                box.right = createBorderLine()
                box.right:SetPoint("TOPRIGHT", box, "TOPRIGHT", 2, 2)
                box.right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 2, -2)
                box.right:SetWidth(3)

                button.fnpaGreenBox = box
            end

            if not button.fnpaUpgradeText then
                local targetFrame = button.Icon or button.icon or _G[button:GetName() .. "IconTexture"] or button
                local txt = button:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                txt:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", 1, -1)
                txt:SetText("|cff00ff00^|r")
                local font = txt:GetFont()
                if font then txt:SetFont(font, 20, "OUTLINE") end
                button.fnpaUpgradeText = txt
            end

            if link and IsItemUpgrade(link) then
                button.fnpaGreenBox:Show()
                button.fnpaUpgradeText:Show()
            else
                button.fnpaGreenBox:Hide()
                button.fnpaUpgradeText:Hide()
            end
        end
    end
end

local function IsQuestWindowOpen()
    return (QuestFrame and QuestFrame:IsShown())
        or (QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown())
        or (QuestInfoFrame and QuestInfoFrame:IsShown())
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

frame:SetScript("OnEvent", function(self, event, ...)
    if IsShiftKeyDown and IsShiftKeyDown() then return end

    if event == "QUEST_DETAIL" then
        if not isEnabled("autoAccept") then return end
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function()
                if QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then AcceptQuest() end
            end)
        else
            AcceptQuest()
        end

    elseif event == "QUEST_PROGRESS" then
        if not isEnabled("autoComplete") then return end
        if IsQuestCompletable() then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.15, function() CompleteQuest() end)
            else
                CompleteQuest()
            end
        end

    elseif event == "QUEST_COMPLETE" then
        if not isEnabled("autoComplete") then return end
        if isSimpleReward() then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.15, function()
                    local choiceIndex = (GetNumQuestChoices() == 1) and 1 or 0
                    GetQuestReward(choiceIndex)
                end)
            else
                local choiceIndex = (GetNumQuestChoices() == 1) and 1 or 0
                GetQuestReward(choiceIndex)
            end
        else
            if C_Timer and C_Timer.After then
                C_Timer.After(0.05, HighlightRewardUpgrades)
                C_Timer.After(0.2, HighlightRewardUpgrades)
                C_Timer.After(0.5, HighlightRewardUpgrades)
            else
                HighlightRewardUpgrades()
            end
        end

    elseif event == "QUEST_ACCEPT_CONFIRM" then
        if not isEnabled("autoAccept") then return end
        ConfirmAcceptQuest()

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if IsQuestWindowOpen() then HighlightRewardUpgrades() end
    end
end)