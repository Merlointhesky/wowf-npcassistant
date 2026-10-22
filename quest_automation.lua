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

-- Safe Item Details Fetcher (extended)
local function GetItemDetails(itemLink)
    if not itemLink then return nil end

    local name, link, rarity, ilvl, reqLevel, itemType, subType,
          count, equipLoc, icon, price, classID, subclassID,
          bindType, isQuestItem, itemID = nil

    if C_Item and C_Item.GetItemInfo then
        name, link, rarity, ilvl, reqLevel, itemType, subType,
        count, equipLoc, icon, price, classID, subclassID,
        bindType, isQuestItem, itemID = C_Item.GetItemInfo(itemLink)
    end
    if not name and GetItemInfo then
        name, link, rarity, ilvl, reqLevel, itemType, subType,
        count, equipLoc, icon, price, classID, subclassID,
        bindType, isQuestItem, itemID = GetItemInfo(itemLink)
    end
    if not name then return nil end

    -- Additional fields
    local armor = nil
    local dmgMin, dmgMax, speed = nil, nil, nil
    if C_Item and C_Item.GetItemInfo then
        armor = select(14, C_Item.GetItemInfo(itemLink))
        dmgMin, dmgMax, speed = select(15, 16, 17, C_Item.GetItemInfo(itemLink))
    end

    local stats = {}
    if C_Item and C_Item.GetItemStats then
        stats = C_Item.GetItemStats(itemLink) or {}
    elseif GetItemStats then
        stats = GetItemStats(itemLink) or {}
    end

    local effects = {}
    if C_Item and C_Item.GetItemSpell then
        local spellID = C_Item.GetItemSpell(itemLink)
        if spellID then
            if C_Spell and C_Spell.GetSpellInfo then
                local spellInfo = C_Spell.GetSpellInfo(spellID)
                table.insert(effects, (spellInfo and spellInfo.name) or tostring(spellID))
            elseif GetSpellInfo then
                table.insert(effects, GetSpellInfo(spellID) or "")
            end
        end
    elseif GetItemSpell then
        local spellID = GetItemSpell(itemLink)
        if spellID then
            if C_Spell and C_Spell.GetSpellInfo then
                local spellInfo = C_Spell.GetSpellInfo(spellID)
                table.insert(effects, (spellInfo and spellInfo.name) or tostring(spellID))
            elseif GetSpellInfo then
                table.insert(effects, GetSpellInfo(spellID) or "")
            end
        end
    end


    return {
        name = name,
        rarity = rarity or 0,
        ilvl = ilvl or 0,
        reqLevel = reqLevel or 0,
        equipLoc = equipLoc or "",
        classID = classID,
        subclassID = subclassID,
        armor = armor or 0,
        dmgMin = dmgMin,
        dmgMax = dmgMax,
        speed = speed,
        stats = stats,
        effects = effects,
    }
end

-- Helper: armor ranking (Cloth=1, Leather=2, Mail=3, Plate=4)
local function ArmorRank(subclassID)
    return subclassID or 0
end

-- Helper to resolve Blizzard global string placeholders
local function ResolveName(name)
    if type(name) == "string" and _G[name] then
        return _G[name]
    end
    return name
end

-- Diff generator between two item detail tables (Refined Display with Weapons)
local function CompareItemDetails(new, old)
    local lines = {}
    local function add(label, delta, isPos)
        local colour = isPos and "|cFF00FF00" or "|cFFFF0000"
        label = ResolveName(label)
        table.insert(lines, string.format("%s: %s%+d|r", label, colour, delta))
    end

    if new.ilvl ~= old.ilvl then add("Item Level", new.ilvl - old.ilvl, new.ilvl > old.ilvl) end
    
    if new.rarity ~= old.rarity then 
        local RARITY_NAMES = {
            [0] = "|cFF9D9D9DPoor|r",
            [1] = "|cFFFFFFFFCommon|r",
            [2] = "|cFF1EFF00Uncommon|r",
            [3] = "|cFF0070DDRare|r",
            [4] = "|cFFA335EEEpic|r",
            [5] = "|cFFFF8000Legendary|r",
            [6] = "|cFFE6CC80Artifact|r",
            [7] = "|cFF00CCFFHeirloom|r"
        }
        local newRarityText = RARITY_NAMES[new.rarity] or "Unknown"
        local oldRarityText = RARITY_NAMES[old.rarity] or "Unknown"
        table.insert(lines, string.format("Rarity: %s > %s", oldRarityText, newRarityText))
    end
    
    local nr, orank = ArmorRank(new.subclassID), ArmorRank(old.subclassID)
    if nr > 0 and orank > 0 and nr ~= orank then
        local names = {[1]="Cloth",[2]="Leather",[3]="Mail",[4]="Plate"}
        local colour = nr > orank and "|cFF00FF00" or "|cFFFF0000"
        table.insert(lines, string.format("Armor Type: %s%s > %s|r", colour, names[nr] or "None", names[orank] or "None"))
    end

    -- Weapon specific stats (ClassID 2 = Weapons)
    if new.classID == 2 then
        if new.dmgMin and old.dmgMin and new.dmgMin ~= old.dmgMin then add("Min Damage", new.dmgMin - old.dmgMin, new.dmgMin > old.dmgMin) end
        if new.dmgMax and old.dmgMax and new.dmgMax ~= old.dmgMax then add("Max Damage", new.dmgMax - old.dmgMax, new.dmgMax > old.dmgMax) end
        if new.speed and old.speed and new.speed ~= old.speed then 
            -- Weapon speed is shown directly instead of +/- since slower is sometimes better for certain classes
            table.insert(lines, string.format("Weapon Speed: %.2f > %.2f", old.speed, new.speed))
        end
    end
    
    for stat, newVal in pairs(new.stats or {}) do
        local oldVal = (old.stats or {})[stat] or 0
        if newVal ~= oldVal then add(ResolveName(stat), newVal - oldVal, newVal > oldVal) end
    end
    for stat, oldVal in pairs(old.stats or {}) do
        if not (new.stats or {})[stat] then add(ResolveName(stat), -oldVal, false) end
    end
    
    local function set(t) local s = {} for _,v in ipairs(t) do s[v]=true end return s end
    local neff = set(new.effects or {})
    local oeff = set(old.effects or {})
    for e,_ in pairs(neff) do
        local name = ResolveName(e)
        if not oeff[e] then table.insert(lines, string.format("|cFF00FF00+%s|r", name)) end
    end
    for e,_ in pairs(oeff) do
        local name = ResolveName(e)
        if not neff[e] then table.insert(lines, string.format("|cFFFF0000-%s|r", name)) end
    end
    
    return table.concat(lines, "\n")
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

-- Merge multiple equipped item links into a single detail table for diff comparison
local function MergeEquippedInfo(links)
    local merged = { stats = {}, effects = {} }
    for _, l in ipairs(links) do
        local info = GetItemDetails(l)
        if info then
            merged.ilvl = math.max(merged.ilvl or 0, info.ilvl or 0)
            merged.rarity = math.max(merged.rarity or 0, info.rarity or 0)
            merged.armor = (merged.armor or 0) + (info.armor or 0)
            merged.dmgMin = math.max(merged.dmgMin or 0, info.dmgMin or 0)
            merged.dmgMax = math.max(merged.dmgMax or 0, info.dmgMax or 0)
            merged.speed = info.speed or merged.speed
            merged.subclassID = info.subclassID or merged.subclassID
            for k,v in pairs(info.stats or {}) do merged.stats[k] = (merged.stats[k] or 0) + v end
            for _,e in ipairs(info.effects or {}) do table.insert(merged.effects, e) end
        end
    end
    return merged
end

-- Upgrade Evaluation Logic (Returns Numerical Score)
local function GetItemUpgradeScore(itemLink)
    local item = GetItemDetails(itemLink)
    if not item or not item.equipLoc or item.equipLoc == "" or not EQUIP_LOC_TO_SLOTS[item.equipLoc] then
        return 0
    end

    -- Filter out non-gear and high-level items
    if item.classID ~= 2 and item.classID ~= 4 then return 0 end
    if item.reqLevel > UnitLevel("player") then return 0 end
    local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
    if (item.classID == 2 and (item.subclassID == 14 or item.subclassID == 20)) then return 0 end -- Profession tools

    -- Check usability
    local usable = true
    if C_PlayerInfo and C_PlayerInfo.CanUseItem and itemID then
        usable = C_PlayerInfo.CanUseItem(itemID)
    elseif C_Item and C_Item.IsUsableItem then
        usable = C_Item.IsUsableItem(itemLink)
    elseif IsUsableItem then
        usable = IsUsableItem(itemLink)
    end
    if usable == false then return 0 end

    -- Gather Equipped Links for Score Comparison
    local slots = EQUIP_LOC_TO_SLOTS[item.equipLoc]
    local eqLinks = {}
    
    if item.equipLoc == "INVTYPE_2HWEAPON" then
        local mh = GetInventoryItemLink("player", 16)
        local oh = GetInventoryItemLink("player", 17)
        if mh then table.insert(eqLinks, mh) end
        if oh then table.insert(eqLinks, oh) end
    else
        local lowestSlot, lowestILvl = nil, 99999
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
                break -- Found an empty slot
            end
        end
        if lowestSlot then
            local link = GetInventoryItemLink("player", lowestSlot)
            if link then table.insert(eqLinks, link) end
        end
    end

    -- 1. EMPTY SLOT CHECK (Default Score: 5)
    if #eqLinks == 0 then
        return 5
    end

    -- 2. SCORE CALCULATION
    local old = MergeEquippedInfo(eqLinks)
    local score = 0

    -- Armor Type Upgrades/Downgrades
    local isBodyArmor = (item.classID == 4 and item.subclassID and item.subclassID >= 1 and item.subclassID <= 4)
    if isBodyArmor and old.subclassID then
        if item.subclassID > old.subclassID then score = score + 3 end
        if item.subclassID < old.subclassID then score = score - 5 end
    end

    -- Raw Armor Value
    if (item.armor or 0) > (old.armor or 0) then score = score + 1 end
    if (item.armor or 0) < (old.armor or 0) then score = score - 1 end

    -- Total Stats Aggregate
    local newStatTotal = 0
    for _, v in pairs(item.stats or {}) do newStatTotal = newStatTotal + v end
    local oldStatTotal = 0
    for _, v in pairs(old.stats or {}) do oldStatTotal = oldStatTotal + v end
    
    if newStatTotal > oldStatTotal then score = score + (newStatTotal - oldStatTotal) end
    if newStatTotal < oldStatTotal then score = score - (oldStatTotal - newStatTotal) end

    -- Additional Effects/Spells Check
    local newEffCount = item.effects and #item.effects or 0
    local oldEffCount = old.effects and #old.effects or 0
    if newEffCount > oldEffCount then score = score + 2 end

    -- Base Item Level Fallback
    if item.ilvl > old.ilvl then score = score + 1 end

    return score
end

-------------------------------------------------------------------------------
-- Custom Side-by-Side Item Preview Window
-------------------------------------------------------------------------------
local promptFrame = CreateFrame("Frame", "FNPAEquipPromptFrame", UIParent, "BackdropTemplate,BasicFrameTemplateWithInset")
promptFrame:SetSize(520, 360)
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

-- Equip Button (Moved to Top Right)
local equipBtn = CreateFrame("Button", "FNPAEquipButton", promptFrame, "UIPanelButtonTemplate")
equipBtn:SetSize(110, 22)
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

-- Ignore Button (Moved to Top Right, beside Equip)
local ignoreBtn = CreateFrame("Button", "FNPAIgnoreButton", promptFrame, "UIPanelButtonTemplate")
ignoreBtn:SetSize(80, 22)
ignoreBtn:SetText("Ignore")
ignoreBtn:SetScript("OnClick", function()
    promptFrame:Hide()
end)

ignoreBtn:ClearAllPoints()
ignoreBtn:SetPoint("TOPRIGHT", promptFrame, "TOPRIGHT", -12, -48)
equipBtn:ClearAllPoints()
equipBtn:SetPoint("RIGHT", ignoreBtn, "LEFT", -8, 0)

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
    leftLabel:SetPoint("TOPLEFT", promptFrame, "TOPLEFT", 20, -74)
    newTooltip:SetPoint("TOPLEFT", leftLabel, "BOTTOMLEFT", 0, -4)

    -- Anchor Right Column
    local rightX = (newTooltip:GetWidth() or 200) + 45
    rightLabel:ClearAllPoints()
    rightLabel:SetPoint("TOPLEFT", promptFrame, "TOPLEFT", rightX, -74)

    if #eqLinks >= 1 then
        eqTooltip1:SetOwner(promptFrame, "ANCHOR_NONE")
        eqTooltip1:SetHyperlink(eqLinks[1])
        eqTooltip1:SetPoint("TOPLEFT", rightLabel, "BOTTOMLEFT", 0, -4)
        eqTooltip1:Show()

        if #eqLinks >= 2 then
            eqTooltip2:SetOwner(promptFrame, "ANCHOR_NONE")
            eqTooltip2:SetHyperlink(eqLinks[2])
            eqTooltip2:SetPoint("TOPLEFT", eqTooltip1, "BOTTOMLEFT", 0, -6)
            eqTooltip2:Show()
        end

        local equippedInfo = MergeEquippedInfo(eqLinks)
        local diffText = CompareItemDetails(item, equippedInfo)
        if diffText and diffText ~= "" then
            newTooltip:AddLine(diffText)
            newTooltip:Show() -- Refresh sizing with added line
        end
    else
        emptySlotText:ClearAllPoints()
        emptySlotText:SetPoint("TOPLEFT", rightLabel, "BOTTOMLEFT", 10, -20)
        emptySlotText:Show()
    end

    -- Calculate Dynamic Frame Sizing with safety minimums
    local leftH = math.max(newTooltip:GetHeight() or 0, 80)
    local rightH = 0
    if eqTooltip1:IsShown() then rightH = rightH + math.max(eqTooltip1:GetHeight() or 0, 80) end
    if eqTooltip2:IsShown() then rightH = rightH + math.max(eqTooltip2:GetHeight() or 0, 80) + 6 end
    if emptySlotText:IsShown() then rightH = 40 end

    local rightW = math.max(eqTooltip1:IsShown() and (eqTooltip1:GetWidth() or 140) or 140, eqTooltip2:IsShown() and (eqTooltip2:GetWidth() or 0) or 0)
    local totalW = (newTooltip:GetWidth() or 200) + rightW + 65
    local totalH = math.max(leftH, rightH) + 100

    promptFrame:SetSize(math.max(totalW, 440), math.max(totalH, 280))
    promptFrame:Show()
end

--- Hook GetQuestReward to trigger the preview prompt when selecting an upgrade reward
if hooksecurefunc then
    hooksecurefunc("GetQuestReward", function(choiceIndex)
        local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
        local chosenIndex = (choiceIndex and choiceIndex > 0) and choiceIndex or ((numChoices == 1) and 1 or 0)
        
        if chosenIndex > 0 then
            local link = GetQuestItemLink("choice", chosenIndex)
            if link and GetItemUpgradeScore(link) > 0 then
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.5, function()
                        FNPA:PromptEquipUpgrade(link)
                    end)
                end
            end
        end
    end)
end

-- Highlight Green Box Overlay for Quest Choices (Top Scorer Only)
local function HighlightRewardUpgrades()
    if not isEnabled("rewardHighlight") then return end

    -- 1. CLEAR PHASE
    for i = 1, 20 do
        local b = QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons and QuestInfoRewardsFrame.RewardButtons[i]
        if not b then b = _G["QuestInfoItem" .. i] or _G["QuestItem" .. i] end
        
        if b then
            if b.fnpaGreenBox then b.fnpaGreenBox:Hide() end
            if b.fnpaUpgradeText then b.fnpaUpgradeText:Hide() end
        end
    end

    local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if numChoices <= 1 then return end

    -- 2. EVALUATION PHASE: Find the best upgrade score
    local bestScore = 0
    local bestChoiceIndex = 0

    for i = 1, numChoices do
        local link = GetQuestItemLink("choice", i)
        if link then
            local score = GetItemUpgradeScore(link)
            if score > bestScore then
                bestScore = score
                bestChoiceIndex = i
            end
        end
    end

    -- 3. HIGHLIGHT PHASE: Apply UI highlight to the single best choice
    if bestChoiceIndex > 0 then
        local button = nil
        
        -- Safely find the exact choice button
        for j = 1, 20 do
            local b = QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons and QuestInfoRewardsFrame.RewardButtons[j]
            if not b then b = _G["QuestInfoItem" .. j] or _G["QuestItem" .. j] end
            
            if b and b:IsShown() and b.type == "choice" and b:GetID() == bestChoiceIndex then
                button = b
                break
            end
        end

        -- Fallback for custom UIs
        if not button then
            button = QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons and QuestInfoRewardsFrame.RewardButtons[bestChoiceIndex]
            if not button then button = _G["QuestInfoItem" .. bestChoiceIndex] or _G["QuestItem" .. bestChoiceIndex] end
        end

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

            button.fnpaGreenBox:Show()
            button.fnpaUpgradeText:Show()
        end
    end
end

local function IsQuestWindowOpen()
    return (QuestFrame and QuestFrame:IsShown())
        or (QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown())
        or (QuestInfoFrame and QuestInfoFrame:IsShown())
end

FNPA.frame = CreateFrame("Frame")
FNPA.frame:RegisterEvent("QUEST_DETAIL")
FNPA.frame:RegisterEvent("QUEST_PROGRESS")
FNPA.frame:RegisterEvent("QUEST_COMPLETE")
FNPA.frame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
FNPA.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

FNPA.frame:SetScript("OnEvent", function(self, event, ...)
    -- Safe execution to prevent silent breaks if debug functionality isn't loaded
    if FNPA.DebugLog then
        FNPA:DebugLog("QuestAutomation event: " .. tostring(event))
    end
    
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