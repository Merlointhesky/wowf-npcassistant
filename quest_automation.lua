-- quest_automation.lua for ForeverNPCAssistant
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

-- Calculate equipped item level, rarity, and armor type (Cloth=1, Leather=2, Mail=3, Plate=4)
local function GetEquippedItemLevel(equipLoc)
    local slots = EQUIP_LOC_TO_SLOTS[equipLoc]
    if not slots then return nil end

    local lowestILvl = 99999
    local lowestRarity = 999
    local equippedArmorSubclass = nil
    local has2H = false
    local mainHandILvl = nil
    local mainHandRarity = nil

    -- Check if player is holding a 2H Weapon in MainHand
    if equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" then
        local mhLink = GetInventoryItemLink("player", 16)
        if mhLink then
            local mhEquipLoc, ilvl, rarity
            if C_Item and C_Item.GetItemInfo then
                _, _, rarity, ilvl, _, _, _, _, mhEquipLoc = C_Item.GetItemInfo(mhLink)
            elseif GetItemInfo then
                _, _, rarity, ilvl, _, _, _, _, mhEquipLoc = GetItemInfo(mhLink)
            end
            if mhEquipLoc == "INVTYPE_2HWEAPON" then
                has2H = true
                mainHandILvl = ilvl or 0
                mainHandRarity = rarity or 0
            end
        end
    end

    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local ilvl, rarity, classID, subclassID
            if C_Item and C_Item.GetItemInfo then
                _, _, rarity, ilvl, _, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(link)
            elseif GetItemInfo then
                _, _, rarity, ilvl, _, _, _, _, _, _, _, classID, subclassID = GetItemInfo(link)
            end

            ilvl = ilvl or 0
            if ilvl < lowestILvl then
                lowestILvl = ilvl
                lowestRarity = rarity or 0
                if classID == 4 and subclassID and subclassID >= 1 and subclassID <= 4 then
                    equippedArmorSubclass = subclassID
                end
            end
        else
            -- Empty slot handling
            if slot == 17 and has2H then
                if mainHandILvl and mainHandILvl < lowestILvl then
                    lowestILvl = mainHandILvl
                    lowestRarity = mainHandRarity or 0
                end
            else
                return 0, 0, nil -- Empty slot means equipped ilvl is 0
            end
        end
    end

    if lowestILvl == 99999 then return 0, 0, nil end
    return lowestILvl, lowestRarity, equippedArmorSubclass
end

-- Upgrade Evaluation Logic with Armor Hierarchy Rules
local function IsItemUpgrade(itemLink)
    if not itemLink then return false end

    local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
    local itemName, _, rarity, ilvl, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID

    if C_Item and C_Item.GetItemInfo then
        itemName, _, rarity, ilvl, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID = C_Item.GetItemInfo(itemLink)
    elseif GetItemInfo then
        itemName, _, rarity, ilvl, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID = GetItemInfo(itemLink)
    end

    if not equipLoc or equipLoc == "" or not EQUIP_LOC_TO_SLOTS[equipLoc] then
        return false
    end

    -- 1. Check Level Requirement
    if reqLevel and reqLevel > UnitLevel("player") then
        return false
    end

    -- 2. Check Item Usability (Class / Armor / Weapon restrictions)
    local isUsable = true
    local isProfessionTool = (classID == 2 and (subclassID == 14 or subclassID == 20))

    if classID == 2 or classID == 4 then
        local usable = true
        if C_PlayerInfo and C_PlayerInfo.CanUseItem and itemID then
            usable = C_PlayerInfo.CanUseItem(itemID)
        elseif C_Item and C_Item.IsUsableItem then
            usable = C_Item.IsUsableItem(itemLink)
        elseif IsUsableItem then
            usable = IsUsableItem(itemLink)
        end

        if usable == false then
            isUsable = false
        end
    end

    if not isUsable or isProfessionTool then
        return false
    end

    -- 3. Item Level & Armor Hierarchy Comparison
    local currentIlvl, currentRarity, currentArmorSubclass = GetEquippedItemLevel(equipLoc)
    rarity = rarity or 0

    if ilvl and currentIlvl then
        -- Empty slot: any usable item is an upgrade
        if currentIlvl == 0 then
            return true
        end

        -- Armor Type Hierarchy Check (Cloth=1 < Leather=2 < Mail=3 < Plate=4)
        local isBodyArmor = (classID == 4 and subclassID and subclassID >= 1 and subclassID <= 4)
        if isBodyArmor and currentArmorSubclass then
            if subclassID < currentArmorSubclass then
                -- Reward is a lower armor type (e.g., Cloth reward vs equipped Leather/Mail)
                -- Only allow upgrade flag if reward strictly outranks equipped by rarity AND ilvl!
                if rarity > currentRarity and ilvl > currentIlvl then
                    return true
                else
                    return false
                end
            end
        end

        -- Standard Upgrade Check (Same or higher armor type)
        if ilvl > currentIlvl and rarity >= (currentRarity or 0) then
            return true
        end
    end

    return false
end

local function HighlightRewardUpgrades()
    if not isEnabled("rewardHighlight") then return end

    local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if numChoices <= 1 then return end

    for i = 1, numChoices do
        local link = GetQuestItemLink("choice", i)
        local button = nil

        if QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons then
            button = QuestInfoRewardsFrame.RewardButtons[i]
        end
        if not button then
            button = _G["QuestInfoItem" .. i] or _G["QuestItem" .. i]
        end

        if button then
            local targetFrame = button.Icon or button.icon or button

            -- Create Prominent Large Green Square Overlay (-10 / +10 padding offset)
            if not button.fnpaOverlay then
                local overlay = button:CreateTexture(nil, "OVERLAY", nil, 7)
                overlay:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                overlay:SetBlendMode("ADD")
                overlay:SetVertexColor(0, 1, 0, 1) -- Glowing Bright Green
                overlay:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", -10, 10)
                overlay:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", 10, -10)
                button.fnpaOverlay = overlay
            end

            -- Create Green Upgrade Arrow
            if not button.fnpaUpgradeText then
                local txt = button:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                txt:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", 2, -2)
                txt:SetText("|cff00ff00^|r")
                local font = txt:GetFont()
                if font then txt:SetFont(font, 18, "OUTLINE") end
                button.fnpaUpgradeText = txt
            end

            if link and IsItemUpgrade(link) then
                button.fnpaOverlay:Show()
                button.fnpaUpgradeText:Show()
            else
                button.fnpaOverlay:Hide()
                button.fnpaUpgradeText:Hide()
            end
        end
    end
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
                if QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then
                    AcceptQuest()
                end
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
                    local choiceIndex = (GetNumQuestChoices() == 1) and 1 or