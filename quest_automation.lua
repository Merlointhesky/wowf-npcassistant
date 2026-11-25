-- quest_automation.lua for ForeverNPCAssistant (Modern 16001 Engine)
local addonName, FNPA = ...
FNPA = FNPA or _G.ForeverNPCAssistant
FNPA.Events = FNPA.Events or {}

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

local function StripColorCodes(text)
    if type(text) ~= "string" then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
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

local SLOT_LABELS = {
    [1] = "Head",
    [2] = "Neck",
    [3] = "Shoulder",
    [4] = "Shirt",
    [5] = "Chest",
    [6] = "Waist",
    [7] = "Legs",
    [8] = "Feet",
    [9] = "Wrist",
    [10] = "Hands",
    [11] = "Finger 1",
    [12] = "Finger 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
    [18] = "Ranged / Relic",
    [19] = "Tabard",
}

-- Ordered stat display list and normalized key mapping
local STAT_DISPLAY_ORDER = {
    "Strength",
    "Agility",
    "Stamina",
    "Intellect",
    "Spirit",
    "Attack Power",
    "Ranged Attack Power",
    "Spell Power",
    "Healing",
    "Critical Strike",
    "Hit",
    "Haste",
    "Defense",
    "Block Value",
    "Block",
    "Dodge",
    "Parry",
    "Mana per 5 sec",
    "Health per 5 sec",
    "Arcane Resistance",
    "Fire Resistance",
    "Frost Resistance",
    "Nature Resistance",
    "Shadow Resistance",
    "All Resistances",
}

local GLOBAL_STAT_MAP = {
    ITEM_MOD_STRENGTH_SHORT = "Strength",
    ITEM_MOD_AGILITY_SHORT = "Agility",
    ITEM_MOD_STAMINA_SHORT = "Stamina",
    ITEM_MOD_INTELLECT_SHORT = "Intellect",
    ITEM_MOD_SPIRIT_SHORT = "Spirit",
    ITEM_MOD_ATTACK_POWER_SHORT = "Attack Power",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "Ranged Attack Power",
    ITEM_MOD_SPELL_POWER_SHORT = "Spell Power",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "Spell Power",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "Healing",
    ITEM_MOD_CRIT_RATING_SHORT = "Critical Strike",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "Critical Strike",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "Critical Strike",
    ITEM_MOD_HIT_RATING_SHORT = "Hit",
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "Hit",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "Hit",
    ITEM_MOD_HASTE_RATING_SHORT = "Haste",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Defense",
    ITEM_MOD_BLOCK_VALUE_SHORT = "Block Value",
    ITEM_MOD_BLOCK_RATING_SHORT = "Block",
    ITEM_MOD_DODGE_RATING_SHORT = "Dodge",
    ITEM_MOD_PARRY_RATING_SHORT = "Parry",
    ITEM_MOD_MANA_REGENERATION_SHORT = "Mana per 5 sec",
    ITEM_MOD_HEALTH_REGEN_SHORT = "Health per 5 sec",
    RESISTANCE0_NAME = "Armor",
    RESISTANCE1_NAME = "Holy Resistance",
    RESISTANCE2_NAME = "Fire Resistance",
    RESISTANCE3_NAME = "Nature Resistance",
    RESISTANCE4_NAME = "Frost Resistance",
    RESISTANCE5_NAME = "Shadow Resistance",
    RESISTANCE6_NAME = "Arcane Resistance",
}

local PRIMARY_STAT_PATTERNS = {
    { pattern = "^([%+%-]%d+)%s+[Ss]trength$", stat = "Strength" },
    { pattern = "^([%+%-]%d+)%s+[Aa]gility$", stat = "Agility" },
    { pattern = "^([%+%-]%d+)%s+[Ss]tamina$", stat = "Stamina" },
    { pattern = "^([%+%-]%d+)%s+[Ii]ntellect$", stat = "Intellect" },
    { pattern = "^([%+%-]%d+)%s+[Ss]pirit$", stat = "Spirit" },
    { pattern = "^([%+%-]%d+)%s+[Aa]ttack [Pp]ower$", stat = "Attack Power" },
    { pattern = "^([%+%-]%d+)%s+[Ss]pell [Pp]ower$", stat = "Spell Power" },
    { pattern = "^([%+%-]%d+)%s+[Dd]efense$", stat = "Defense" },
    { pattern = "^([%+%-]%d+)%s+[Aa]rcane [Rr]esistance$", stat = "Arcane Resistance" },
    { pattern = "^([%+%-]%d+)%s+[Ff]ire [Rr]esistance$", stat = "Fire Resistance" },
    { pattern = "^([%+%-]%d+)%s+[Ff]rost [Rr]esistance$", stat = "Frost Resistance" },
    { pattern = "^([%+%-]%d+)%s+[Nn]ature [Rr]esistance$", stat = "Nature Resistance" },
    { pattern = "^([%+%-]%d+)%s+[Ss]hadow [Rr]esistance$", stat = "Shadow Resistance" },
    { pattern = "^([%+%-]%d+)%s+[Aa]ll [Rr]esistances$", stat = "All Resistances" },
}

local EQUIP_BONUS_PATTERNS = {
    { pattern = "([%+%-]?%d+)%s+[Aa]ttack [Pp]ower", stat = "Attack Power" },
    { pattern = "[Aa]ttack [Pp]ower%s+by%s+(%d+)", stat = "Attack Power" },
    { pattern = "[Rr]anged [Aa]ttack [Pp]ower%s+by%s+(%d+)", stat = "Ranged Attack Power" },
    { pattern = "damage and healing done by magical spells and effects by up to (%d+)", stat = "Spell Power" },
    { pattern = "spell power by (%d+)", stat = "Spell Power" },
    { pattern = "healing done by spells and effects by up to (%d+)", stat = "Healing" },
    { pattern = "healing done by up to (%d+)", stat = "Healing" },
    { pattern = "restores (%d+) mana per 5 sec", stat = "Mana per 5 sec" },
    { pattern = "restores (%d+) health per 5 sec", stat = "Health per 5 sec" },
    { pattern = "[Dd]efense%s+increased%s+by%s+(%d+)", stat = "Defense" },
    { pattern = "increases defense rating by (%d+)", stat = "Defense" },
    { pattern = "block value of your shield by (%d+)", stat = "Block Value" },
    { pattern = "critical strike.-by (%d+)", stat = "Critical Strike" },
    { pattern = "chance to hit.-by (%d+)", stat = "Hit" },
}

-------------------------------------------------------------------------------
-- Hidden Tooltip Scanner for Accurate Item Stats, Armor, Weapon DPS & Usability
-------------------------------------------------------------------------------
local scanTooltip = CreateFrame("GameTooltip", "FNPAItemScanTooltip", UIParent, "GameTooltipTemplate")

local function NormalizeStatName(rawKey)
    if not rawKey then return nil end
    if GLOBAL_STAT_MAP[rawKey] then
        return GLOBAL_STAT_MAP[rawKey]
    end
    if type(rawKey) == "string" and _G[rawKey] and type(_G[rawKey]) == "string" then
        return _G[rawKey]
    end
    return tostring(rawKey)
end

local function IsRedColor(r, g, b)
    if not r or not g or not b then return false end
    return (r > 0.85 and g < 0.25 and b < 0.25)
end

local function ParseTooltipLinesForItem(details, lines)
    local hasParsedStats = false

    for _, line in ipairs(lines) do
        local leftText = StripColorCodes(line.leftText or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local rightText = StripColorCodes(line.rightText or ""):gsub("^%s+", ""):gsub("%s+$", "")

        -- Check red text for unusable equip proficiency (ignore level red text if already checked)
        if IsRedColor(line.leftR, line.leftG, line.leftB) then
            local lowerLeft = leftText:lower()
            if not lowerLeft:find("^requires level") and not lowerLeft:find("durability") and leftText ~= "" then
                details.hasRedRestriction = true
            end
        end
        if IsRedColor(line.rightR, line.rightG, line.rightB) and rightText ~= "" then
            details.hasRedRestriction = true
        end

        if leftText ~= "" then
            -- Item Level
            local ilvlMatch = leftText:match("^[Ii]tem [Ll]evel%s+(%d+)")
            if ilvlMatch then
                details.ilvl = tonumber(ilvlMatch) or details.ilvl
            end

            -- Armor
            local armorMatch = leftText:match("^(%d+)%s+[Aa]rmor$")
            if armorMatch then
                details.armor = tonumber(armorMatch) or details.armor
            end

            -- Shield Block
            local blockMatch = leftText:match("^(%d+)%s+[Bb]lock$")
            if blockMatch then
                details.stats["Block Value"] = (details.stats["Block Value"] or 0) + (tonumber(blockMatch) or 0)
                hasParsedStats = true
            end

            -- Weapon Damage (e.g. "12 - 23 Damage" or "12 - 23 Fire Damage")
            local dMin, dMax = leftText:match("^(%d+)%s*%-%s*(%d+)%s+.-Damage$")
            if dMin and dMax then
                details.dmgMin = (details.dmgMin or 0) + tonumber(dMin)
                details.dmgMax = (details.dmgMax or 0) + tonumber(dMax)
            end

            -- Weapon DPS (e.g. "(14.5 damage per second)" or "(14.50 damage per second)")
            local dpsMatch = leftText:match("%((%d+%.?%d*)%s+damage per second%)")
            if dpsMatch then
                details.dps = tonumber(dpsMatch)
            end

            -- Primary & Secondary +Stat lines (e.g. "+5 Stamina", "+12 Attack Power")
            for _, p in ipairs(PRIMARY_STAT_PATTERNS) do
                local val = leftText:match(p.pattern)
                if val then
                    details.stats[p.stat] = (details.stats[p.stat] or 0) + (tonumber(val) or 0)
                    hasParsedStats = true
                    break
                end
            end

            -- Green "Equip:", "Use:", "Chance on hit:" effects
            local lower = leftText:lower()
            if lower:find("^equip:") or lower:find("^use:") or lower:find("^chance on hit:") then
                local matchedNumericEquip = false
                if lower:find("^equip:") then
                    for _, ep in ipairs(EQUIP_BONUS_PATTERNS) do
                        local val = lower:match(ep.pattern)
                        if val then
                            details.stats[ep.stat] = (details.stats[ep.stat] or 0) + (tonumber(val) or 0)
                            hasParsedStats = true
                            matchedNumericEquip = true
                            break
                        end
                    end
                end
                if not matchedNumericEquip then
                    table.insert(details.effects, leftText)
                end
            end
        end

        if rightText ~= "" then
            -- Weapon Speed (e.g. "Speed 2.60")
            local speedMatch = rightText:match("[Ss]peed%s+(%d+%.?%d*)")
            if speedMatch then
                details.speed = tonumber(speedMatch)
            end
        end
    end

    if not details.dps and details.dmgMin and details.dmgMax and details.speed and details.speed > 0 then
        details.dps = ((details.dmgMin + details.dmgMax) / 2) / details.speed
    end

    return hasParsedStats
end

local function ScanTooltipForItem(details, itemLink, inventorySlot)
    local collectedLines = {}

    -- 1. Try modern C_TooltipInfo first if available
    if C_TooltipInfo then
        local ok, data = false, nil
        if inventorySlot and C_TooltipInfo.GetInventoryItem then
            ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", inventorySlot)
        elseif itemLink and C_TooltipInfo.GetHyperlink then
            ok, data = pcall(C_TooltipInfo.GetHyperlink, itemLink)
        end
        if ok and data and type(data.lines) == "table" and #data.lines > 0 then
            for _, l in ipairs(data.lines) do
                local lc = l.leftColor
                local rc = l.rightColor
                table.insert(collectedLines, {
                    leftText = l.leftText,
                    rightText = l.rightText,
                    leftR = lc and lc.r, leftG = lc and lc.g, leftB = lc and lc.b,
                    rightR = rc and rc.r, rightG = rc and rc.g, rightB = rc and rc.b,
                })
            end
        end
    end

    -- 2. Fallback / supplement with hidden GameTooltip scan
    if #collectedLines == 0 and scanTooltip then
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTooltip:ClearLines()
        local ok = false
        if inventorySlot then
            ok = pcall(scanTooltip.SetInventoryItem, scanTooltip, "player", inventorySlot)
        end
        if (not ok or (scanTooltip:NumLines() or 0) == 0) and itemLink then
            scanTooltip:ClearLines()
            ok = pcall(scanTooltip.SetHyperlink, scanTooltip, itemLink)
        end
        if ok then
            local numLines = scanTooltip:NumLines() or 0
            for i = 1, numLines do
                local leftFS = _G["FNPAItemScanTooltipTextLeft" .. i]
                local rightFS = _G["FNPAItemScanTooltipTextRight" .. i]
                local lText = leftFS and leftFS.GetText and leftFS:GetText() or nil
                local rText = rightFS and rightFS.GetText and rightFS:GetText() or nil
                local lr, lg, lb = nil, nil, nil
                local rr, rg, rb = nil, nil, nil
                if leftFS and leftFS.GetTextColor then lr, lg, lb = leftFS:GetTextColor() end
                if rightFS and rightFS.GetTextColor then rr, rg, rb = rightFS:GetTextColor() end
                table.insert(collectedLines, {
                    leftText = lText,
                    rightText = rText,
                    leftR = lr, leftG = lg, leftB = lb,
                    rightR = rr, rightG = rg, rightB = rb,
                })
            end
        end
    end

    return ParseTooltipLinesForItem(details, collectedLines)
end

-- Safe Item Details Fetcher (extended with Tooltip Scanner)
local function GetItemDetails(itemLink, inventorySlot)
    if not itemLink and inventorySlot then
        itemLink = GetInventoryItemLink("player", inventorySlot)
    end
    if not itemLink then return nil end

    local name, link, rarity, ilvl, reqLevel, itemType, subType,
          count, equipLoc, icon, price, classID, subclassID,
          bindType = nil

    if C_Item and C_Item.GetItemInfo then
        name, link, rarity, ilvl, reqLevel, itemType, subType,
        count, equipLoc, icon, price, classID, subclassID,
        bindType = C_Item.GetItemInfo(itemLink)
    end
    if not name and GetItemInfo then
        name, link, rarity, ilvl, reqLevel, itemType, subType,
        count, equipLoc, icon, price, classID, subclassID,
        bindType = GetItemInfo(itemLink)
    end
    if not name then return nil end

    local details = {
        name = name,
        link = link or itemLink,
        rarity = rarity or 0,
        ilvl = ilvl or 0,
        reqLevel = reqLevel or 0,
        equipLoc = equipLoc or "",
        icon = icon,
        price = price or 0,
        classID = classID,
        subclassID = subclassID,
        armor = 0,
        dmgMin = nil,
        dmgMax = nil,
        speed = nil,
        dps = nil,
        stats = {},
        effects = {},
        hasRedRestriction = false,
        inventorySlot = inventorySlot,
    }

    -- Scan tooltip for exact Armor, Weapon Damage/Speed/DPS, Primary Stats, Equip Effects & Red Proficiency lines
    local hasTooltipStats = ScanTooltipForItem(details, itemLink, inventorySlot)

    -- Fallback to GetItemStats only if tooltip scan found no stats
    if not hasTooltipStats then
        local rawStats = nil
        if C_Item and C_Item.GetItemStats then
            rawStats = C_Item.GetItemStats(itemLink)
        elseif GetItemStats then
            rawStats = {}
            GetItemStats(itemLink, rawStats)
        end
        if type(rawStats) == "table" then
            for k, v in pairs(rawStats) do
                local normName = NormalizeStatName(k)
                if normName == "Armor" then
                    if details.armor == 0 then details.armor = tonumber(v) or 0 end
                elseif normName and tonumber(v) and tonumber(v) ~= 0 then
                    details.stats[normName] = (details.stats[normName] or 0) + tonumber(v)
                end
            end
        end
    end

    -- Fallback effect detection if tooltip wasn't ready
    if #details.effects == 0 then
        local spellName, spellID = nil, nil
        if C_Item and C_Item.GetItemSpell then
            spellName, spellID = C_Item.GetItemSpell(itemLink)
        elseif GetItemSpell then
            spellName, spellID = GetItemSpell(itemLink)
        end
        if spellName and type(spellName) == "string" and spellName ~= "" then
            table.insert(details.effects, "Effect: " .. spellName)
        elseif spellID and C_Spell and C_Spell.GetSpellInfo then
            local spellInfo = C_Spell.GetSpellInfo(spellID)
            if spellInfo and spellInfo.name then
                table.insert(details.effects, "Effect: " .. spellInfo.name)
            end
        end
    end

    return details
end

-------------------------------------------------------------------------------
-- Target Equipped Item Resolution (Fixes Dual-Slot & 1H/2H Weapon Detection)
-------------------------------------------------------------------------------
-- Returns:
--   comparisonList: array of { slot = number, link = string, details = table } for the target replaced item(s)
--   allEquippedList: array of { slot = number, link = string, details = table } for ALL items currently in compatible slots
--   hasEmptySlot: boolean (true if a compatible slot is completely empty)
local function ResolveTargetEquippedItems(newItemDetails)
    if not newItemDetails or not newItemDetails.equipLoc then
        return {}, {}, false
    end

    local equipLoc = newItemDetails.equipLoc
    local slots = EQUIP_LOC_TO_SLOTS[equipLoc]
    if not slots then
        return {}, {}, false
    end

    local comparisonList = {}
    local allEquippedList = {}
    local hasEmptySlot = false

    -- Case 1: New item is a Two-Handed Weapon -> replaces BOTH Main Hand (16) and Off-Hand (17)
    if equipLoc == "INVTYPE_2HWEAPON" then
        local mhLink = GetInventoryItemLink("player", 16)
        local ohLink = GetInventoryItemLink("player", 17)
        if mhLink then
            local d = GetItemDetails(mhLink, 16)
            if d then
                local entry = { slot = 16, link = mhLink, details = d }
                table.insert(comparisonList, entry)
                table.insert(allEquippedList, entry)
            end
        else
            hasEmptySlot = true
        end
        if ohLink then
            local d = GetItemDetails(ohLink, 17)
            if d then
                local entry = { slot = 17, link = ohLink, details = d }
                table.insert(comparisonList, entry)
                table.insert(allEquippedList, entry)
            end
        end
        return comparisonList, allEquippedList, (#comparisonList == 0)
    end

    -- Case 2: New item is an Off-Hand / Shield / Holdable -> replaces Off-Hand (17), or Main Hand (16) if 2H is equipped
    if equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_WEAPONOFFHAND" then
        local ohLink = GetInventoryItemLink("player", 17)
        if ohLink then
            local d = GetItemDetails(ohLink, 17)
            if d then
                local entry = { slot = 17, link = ohLink, details = d }
                table.insert(comparisonList, entry)
                table.insert(allEquippedList, entry)
            end
        else
            -- Check if player is currently holding a 2H weapon in slot 16
            local mhLink = GetInventoryItemLink("player", 16)
            if mhLink then
                local mhDetails = GetItemDetails(mhLink, 16)
                if mhDetails and mhDetails.equipLoc == "INVTYPE_2HWEAPON" then
                    local entry = { slot = 16, link = mhLink, details = mhDetails }
                    table.insert(comparisonList, entry)
                    table.insert(allEquippedList, entry)
                else
                    hasEmptySlot = true
                end
            else
                hasEmptySlot = true
            end
        end
        return comparisonList, allEquippedList, hasEmptySlot
    end

    -- Case 3: New item is a One-Handed Weapon ("INVTYPE_WEAPON")
    -- Compare against Main Hand (16) by default; only compare against Off-Hand (17) if a weapon is equipped there and has lower ilvl
    if equipLoc == "INVTYPE_WEAPON" then
        local mhLink = GetInventoryItemLink("player", 16)
        local ohLink = GetInventoryItemLink("player", 17)
        local mhDetails = mhLink and GetItemDetails(mhLink, 16) or nil
        local ohDetails = ohLink and GetItemDetails(ohLink, 17) or nil

        if mhDetails then
            table.insert(allEquippedList, { slot = 16, link = mhLink, details = mhDetails })
        else
            hasEmptySlot = true
        end

        -- Only include Off-Hand if it's an actual weapon (classID == 2), not a shield or caster off-hand frill
        if ohDetails and ohDetails.classID == 2 then
            table.insert(allEquippedList, { slot = 17, link = ohLink, details = ohDetails })
        end

        if mhDetails and ohDetails and ohDetails.classID == 2 then
            -- Both hands have weapons equipped: target the lower ilvl weapon for primary stat diff
            if ohDetails.ilvl < mhDetails.ilvl then
                table.insert(comparisonList, { slot = 17, link = ohLink, details = ohDetails })
            else
                table.insert(comparisonList, { slot = 16, link = mhLink, details = mhDetails })
            end
        elseif mhDetails then
            table.insert(comparisonList, { slot = 16, link = mhLink, details = mhDetails })
        elseif ohDetails and ohDetails.classID == 2 then
            table.insert(comparisonList, { slot = 17, link = ohLink, details = ohDetails })
        end

        return comparisonList, allEquippedList, (#allEquippedList == 0)
    end

    -- Case 4: Dual-slot accessories (Rings: {11, 12}, Trinkets: {13, 14}) or Single-slot armor
    local lowestEntry = nil
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local d = GetItemDetails(link, slot)
            if d then
                local entry = { slot = slot, link = link, details = d }
                table.insert(allEquippedList, entry)
                if not lowestEntry or d.ilvl < lowestEntry.details.ilvl then
                    lowestEntry = entry
                end
            end
        else
            hasEmptySlot = true
        end
    end

    if lowestEntry then
        table.insert(comparisonList, lowestEntry)
    end

    return comparisonList, allEquippedList, hasEmptySlot
end

-- Merge one or more equipped item entries into a single baseline table for stat comparison
local function MergeEquippedInfo(entries)
    local merged = {
        ilvl = 0,
        rarity = 0,
        armor = 0,
        dmgMin = nil,
        dmgMax = nil,
        speed = nil,
        dps = nil,
        subclassID = nil,
        stats = {},
        effects = {},
    }

    for _, entry in ipairs(entries or {}) do
        local info = entry.details or GetItemDetails(entry.link, entry.slot)
        if info then
            merged.ilvl = math.max(merged.ilvl or 0, info.ilvl or 0)
            merged.rarity = math.max(merged.rarity or 0, info.rarity or 0)
            merged.armor = (merged.armor or 0) + (info.armor or 0)
            if info.dmgMin then merged.dmgMin = math.max(merged.dmgMin or 0, info.dmgMin) end
            if info.dmgMax then merged.dmgMax = math.max(merged.dmgMax or 0, info.dmgMax) end
            if info.dps then merged.dps = math.max(merged.dps or 0, info.dps) end
            merged.speed = info.speed or merged.speed
            merged.subclassID = info.subclassID or merged.subclassID
            for k, v in pairs(info.stats or {}) do
                merged.stats[k] = (merged.stats[k] or 0) + v
            end
            for _, e in ipairs(info.effects or {}) do
                table.insert(merged.effects, e)
            end
        end
    end

    return merged
end

-------------------------------------------------------------------------------
-- Color-Coded Stat Comparison Generator (+Green / -Red)
-------------------------------------------------------------------------------
local function BuildStatComparisonLines(new, old)
    local lines = {}

    local function addIntDelta(label, newVal, oldVal)
        newVal = tonumber(newVal) or 0
        oldVal = tonumber(oldVal) or 0
        local delta = newVal - oldVal
        if delta ~= 0 then
            local color = (delta > 0) and "|cFF00FF00" or "|cFFFF4444"
            table.insert(lines, string.format("%s%+d %s|r |cFFAAAAAA(%d -> %d)|r", color, delta, label, oldVal, newVal))
        end
    end

    local function addFloatDelta(label, newVal, oldVal)
        newVal = tonumber(newVal) or 0
        oldVal = tonumber(oldVal) or 0
        local delta = newVal - oldVal
        if math.abs(delta) >= 0.05 then
            local color = (delta > 0) and "|cFF00FF00" or "|cFFFF4444"
            table.insert(lines, string.format("%s%+.1f %s|r |cFFAAAAAA(%.1f -> %.1f)|r", color, delta, label, oldVal, newVal))
        end
    end

    -- 1. Item Level
    if (new.ilvl or 0) > 0 and (old.ilvl or 0) > 0 and new.ilvl ~= old.ilvl then
        addIntDelta("Item Level", new.ilvl, old.ilvl)
    end

    -- 2. Weapon DPS & Damage
    if new.classID == 2 or (new.dps and new.dps > 0) or (old.dps and old.dps > 0) then
        if (new.dps or 0) > 0 or (old.dps or 0) > 0 then
            addFloatDelta("Weapon DPS", new.dps or 0, old.dps or 0)
        end
        if new.speed and old.speed and math.abs(new.speed - old.speed) >= 0.05 then
            table.insert(lines, string.format("|cFFFFD100Speed:|r %.2fs -> %.2fs", old.speed, new.speed))
        end
    end

    -- 3. Armor
    if (new.armor or 0) ~= (old.armor or 0) then
        addIntDelta("Armor", new.armor or 0, old.armor or 0)
    end

    -- 4. Primary & Secondary Stats (in clean canonical order first, then any remaining custom keys)
    local handledStats = {}
    for _, statName in ipairs(STAT_DISPLAY_ORDER) do
        local nVal = (new.stats and new.stats[statName]) or 0
        local oVal = (old.stats and old.stats[statName]) or 0
        if nVal ~= 0 or oVal ~= 0 then
            handledStats[statName] = true
            addIntDelta(statName, nVal, oVal)
        end
    end

    for statName, nVal in pairs(new.stats or {}) do
        if not handledStats[statName] then
            handledStats[statName] = true
            local oVal = (old.stats and old.stats[statName]) or 0
            addIntDelta(statName, nVal, oVal)
        end
    end
    for statName, oVal in pairs(old.stats or {}) do
        if not handledStats[statName] then
            handledStats[statName] = true
            addIntDelta(statName, 0, oVal)
        end
    end

    -- 5. Special Effects ("Equip:", "Use:", "Chance on hit:")
    local newEffSet, oldEffSet = {}, {}
    for _, e in ipairs(new.effects or {}) do newEffSet[e] = true end
    for _, e in ipairs(old.effects or {}) do oldEffSet[e] = true end

    for _, e in ipairs(new.effects or {}) do
        if not oldEffSet[e] then
            table.insert(lines, "|cFF00FF00+ " .. e .. "|r")
        end
    end
    for _, e in ipairs(old.effects or {}) do
        if not newEffSet[e] then
            table.insert(lines, "|cFFFF4444- " .. e .. "|r")
        end
    end

    return lines
end

-------------------------------------------------------------------------------
-- Upgrade Evaluation Logic (Returns Numerical Score)
-------------------------------------------------------------------------------
local CLASS_STAT_WEIGHTS = {
    WARRIOR = { ["Strength"] = 2.2, ["Stamina"] = 1.5, ["Agility"] = 1.4, ["Attack Power"] = 1.0, ["Critical Strike"] = 1.8, ["Defense"] = 1.2 },
    PALADIN = { ["Strength"] = 1.8, ["Stamina"] = 1.5, ["Intellect"] = 1.2, ["Spirit"] = 0.8, ["Attack Power"] = 0.9, ["Spell Power"] = 1.0, ["Healing"] = 1.0 },
    HUNTER  = { ["Agility"] = 2.4, ["Ranged Attack Power"] = 1.2, ["Attack Power"] = 1.0, ["Stamina"] = 1.2, ["Intellect"] = 0.8, ["Critical Strike"] = 1.8 },
    ROGUE   = { ["Agility"] = 2.4, ["Strength"] = 1.2, ["Attack Power"] = 1.1, ["Stamina"] = 1.2, ["Critical Strike"] = 1.8, ["Hit"] = 1.8 },
    PRIEST  = { ["Intellect"] = 2.2, ["Spirit"] = 1.8, ["Spell Power"] = 1.5, ["Healing"] = 1.5, ["Stamina"] = 1.2, ["Mana per 5 sec"] = 2.0 },
    SHAMAN  = { ["Strength"] = 1.5, ["Agility"] = 1.4, ["Intellect"] = 1.6, ["Spirit"] = 1.2, ["Stamina"] = 1.4, ["Spell Power"] = 1.2, ["Attack Power"] = 0.9 },
    MAGE    = { ["Intellect"] = 2.4, ["Spell Power"] = 1.8, ["Spirit"] = 1.4, ["Stamina"] = 1.2, ["Critical Strike"] = 1.5 },
    WARLOCK = { ["Intellect"] = 2.2, ["Spell Power"] = 1.9, ["Stamina"] = 1.6, ["Spirit"] = 1.1, ["Critical Strike"] = 1.5 },
    DRUID   = { ["Intellect"] = 1.6, ["Agility"] = 1.6, ["Strength"] = 1.5, ["Spirit"] = 1.4, ["Stamina"] = 1.5, ["Spell Power"] = 1.2, ["Attack Power"] = 0.9 },
}

local function GetPlayerStatWeight(statName)
    local _, classFile = UnitClass("player")
    local classTable = classFile and CLASS_STAT_WEIGHTS[classFile]
    if classTable and classTable[statName] then
        return classTable[statName]
    end
    return 1.0
end

local function GetItemUpgradeScore(itemLink)
    local item = GetItemDetails(itemLink)
    if not item or not item.equipLoc or item.equipLoc == "" or not EQUIP_LOC_TO_SLOTS[item.equipLoc] then
        return 0
    end

    -- Filter out non-gear, profession tools, and items requiring a higher level
    if item.classID ~= 2 and item.classID ~= 4 then return 0 end
    if item.reqLevel > (UnitLevel("player") or 60) then return 0 end
    if item.classID == 2 and (item.subclassID == 14 or item.subclassID == 20) then return 0 end

    -- Reject items with red proficiency text in tooltip (e.g. Plate on a Mage)
    if item.hasRedRestriction then
        return 0
    end

    local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
    local usable = true
    if C_PlayerInfo and C_PlayerInfo.CanUseItem and itemID then
        usable = C_PlayerInfo.CanUseItem(itemID)
    elseif C_Item and C_Item.IsUsableItem then
        usable = C_Item.IsUsableItem(itemLink)
    elseif IsUsableItem then
        usable = IsUsableItem(itemLink)
    end
    if usable == false then return 0 end

    local comparisonList, _, hasEmptySlot = ResolveTargetEquippedItems(item)

    -- 1. Empty compatible slot check
    if hasEmptySlot and #comparisonList == 0 then
        return 10 + (item.ilvl or 1)
    end
    if hasEmptySlot and (item.equipLoc == "INVTYPE_FINGER" or item.equipLoc == "INVTYPE_TRINKET") then
        return 10 + (item.ilvl or 1)
    end

    -- 2. Compare against target equipped item(s)
    local old = MergeEquippedInfo(comparisonList)
    local score = 0

    -- Armor Type Rank (Cloth=1, Leather=2, Mail=3, Plate=4)
    local isBodyArmor = (item.classID == 4 and item.subclassID and item.subclassID >= 1 and item.subclassID <= 4)
    if isBodyArmor and old.subclassID then
        if item.subclassID > old.subclassID then score = score + 3 end
        if item.subclassID < old.subclassID then score = score - 5 end
    end

    -- Weapon DPS delta
    if item.classID == 2 and (item.dps or old.dps) then
        local dpsDelta = (item.dps or 0) - (old.dps or 0)
        score = score + (dpsDelta * 2.5)
    end

    -- Armor value delta
    if (item.armor or 0) > (old.armor or 0) then score = score + 1 end
    if (item.armor or 0) < (old.armor or 0) then score = score - 1 end

    -- Class-Weighted Stats Aggregate
    local newStatScore = 0
    for k, v in pairs(item.stats or {}) do
        newStatScore = newStatScore + (v * GetPlayerStatWeight(k))
    end
    local oldStatScore = 0
    for k, v in pairs(old.stats or {}) do
        oldStatScore = oldStatScore + (v * GetPlayerStatWeight(k))
    end

    score = score + (newStatScore - oldStatScore)

    -- Special Effects count
    local newEffCount = item.effects and #item.effects or 0
    local oldEffCount = old.effects and #old.effects or 0
    if newEffCount > oldEffCount then score = score + 2 end

    -- Item Level tiebreaker
    if (item.ilvl or 0) > (old.ilvl or 0) then score = score + 0.5 end
    if (item.ilvl or 0) < (old.ilvl or 0) then score = score - 0.5 end

    return score
end

-------------------------------------------------------------------------------
-- Safe Item Equip Queue (handles Bag arrival & Combat Lockdown)
-------------------------------------------------------------------------------
local pendingEquipItemLink = nil

local function IsItemInPlayerBags(itemLink)
    local targetID = tonumber(itemLink and itemLink:match("item:(%d+)"))
    if not targetID then return true end

    for bag = 0, 4 do
        local numSlots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag))
                      or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
        for slot = 1, numSlots do
            local slotLink = (C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot))
                          or (GetContainerItemLink and GetContainerItemLink(bag, slot))
            if slotLink then
                local id = tonumber(slotLink:match("item:(%d+)"))
                if id and id == targetID then
                    return true
                end
            end
        end
    end
    return false
end

local function TryExecuteEquip(itemLink)
    if not itemLink then return false end
    if InCombatLockdown and InCombatLockdown() then
        pendingEquipItemLink = itemLink
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Forever NPC Assistant]|r In combat — will equip " .. itemLink .. " when combat ends.")
        return false
    end

    if EquipItemByName then
        EquipItemByName(itemLink)
        return true
    elseif C_Item and C_Item.EquipItemByName then
        C_Item.EquipItemByName(itemLink)
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- Custom Side-by-Side Item Preview Window
-------------------------------------------------------------------------------
local promptFrame = CreateFrame("Frame", "FNPAEquipPromptFrame", UIParent, "BackdropTemplate,BasicFrameTemplateWithInset")
promptFrame:SetSize(560, 380)
promptFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
promptFrame:SetMovable(true)
promptFrame:EnableMouse(true)
promptFrame:RegisterForDrag("LeftButton")
promptFrame:SetScript("OnDragStart", promptFrame.StartMoving)
promptFrame:SetScript("OnDragStop", promptFrame.StopMovingOrSizing)
promptFrame:SetFrameStrata("DIALOG")
promptFrame:Hide()

if promptFrame.TitleText then
    promptFrame.TitleText:SetText("Forever NPC Assistant — Upgrade Found!")
end

-- Header Text
local headerText = promptFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
headerText:SetPoint("TOPLEFT", promptFrame, "TOPLEFT", 18, -32)
headerText:SetText("Would you like to equip your new quest reward?")

-- Equip Button (Top Right)
local equipBtn = CreateFrame("Button", "FNPAEquipButton", promptFrame, "UIPanelButtonTemplate")
equipBtn:SetSize(115, 24)
equipBtn:SetText("Equip Upgrade")
equipBtn:SetScript("OnClick", function()
    local link = promptFrame.newItemLink
    promptFrame:Hide()
    if link then
        if IsItemInPlayerBags(link) then
            TryExecuteEquip(link)
        else
            pendingEquipItemLink = link
            if C_Timer and C_Timer.After then
                C_Timer.After(0.3, function()
                    if pendingEquipItemLink == link and IsItemInPlayerBags(link) then
                        pendingEquipItemLink = nil
                        TryExecuteEquip(link)
                    end
                end)
            end
        end
    end
end)

-- Ignore Button (Top Right, beside Equip)
local ignoreBtn = CreateFrame("Button", "FNPAIgnoreButton", promptFrame, "UIPanelButtonTemplate")
ignoreBtn:SetSize(80, 24)
ignoreBtn:SetText("Ignore")
ignoreBtn:SetScript("OnClick", function()
    promptFrame:Hide()
end)

ignoreBtn:ClearAllPoints()
ignoreBtn:SetPoint("TOPRIGHT", promptFrame, "TOPRIGHT", -14, -30)
equipBtn:ClearAllPoints()
equipBtn:SetPoint("RIGHT", ignoreBtn, "LEFT", -8, 0)

-- Embedded Tooltip 1 (New Upgrade + Stat Diff)
local newTooltip = CreateFrame("GameTooltip", "FNPANewItemTooltip", promptFrame, "GameTooltipTemplate")
newTooltip:SetFrameLevel(promptFrame:GetFrameLevel() + 5)

-- Embedded Tooltip 2 (Currently Equipped Item 1)
local eqTooltip1 = CreateFrame("GameTooltip", "FNPAEquippedItemTooltip1", promptFrame, "GameTooltipTemplate")
eqTooltip1:SetFrameLevel(promptFrame:GetFrameLevel() + 5)

-- Embedded Tooltip 3 (Currently Equipped Item 2 - for Off-Hand or 2nd Ring/Trinket)
local eqTooltip2 = CreateFrame("GameTooltip", "FNPAEquippedItemTooltip2", promptFrame, "GameTooltipTemplate")
eqTooltip2:SetFrameLevel(promptFrame:GetFrameLevel() + 5)

-- Empty Slot Fallback Text
local emptySlotText = promptFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptySlotText:SetText("(Nothing Currently Equipped in Slot)")

-- Column Labels
local leftLabel = promptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
leftLabel:SetText("|cFF00FF00[New Quest Reward]|r")

local rightLabel = promptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rightLabel:SetText("|cFFFF5555[Currently Equipped]|r")

local function PopulateEmbeddedEquippedTooltip(tooltip, entry)
    tooltip:SetOwner(promptFrame, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:ClearLines()

    local populated = false
    if entry.slot then
        local ok = pcall(tooltip.SetInventoryItem, tooltip, "player", entry.slot)
        if ok and (tooltip:NumLines() or 0) > 0 then
            populated = true
        end
    end
    if not populated and entry.link then
        tooltip:ClearLines()
        pcall(tooltip.SetHyperlink, tooltip, entry.link)
    end
    tooltip:Show()
end

local function UpdatePromptLayout()
    if not promptFrame:IsShown() then return end

    local leftW = math.max(newTooltip:GetWidth() or 220, 220)
    local leftH = math.max(newTooltip:GetHeight() or 100, 100)

    local rightX = leftW + 36
    rightLabel:ClearAllPoints()
    rightLabel:SetPoint("TOPLEFT", promptFrame, "TOPLEFT", rightX, -64)

    local rightH = 0
    local rightW = 200

    if eqTooltip1:IsShown() then
        eqTooltip1:ClearAllPoints()
        eqTooltip1:SetPoint("TOPLEFT", rightLabel, "BOTTOMLEFT", 0, -4)
        rightH = rightH + math.max(eqTooltip1:GetHeight() or 80, 80)
        rightW = math.max(rightW, eqTooltip1:GetWidth() or 200)
    end

    if eqTooltip2:IsShown() then
        eqTooltip2:ClearAllPoints()
        if eqTooltip1:IsShown() then
            eqTooltip2:SetPoint("TOPLEFT", eqTooltip1, "BOTTOMLEFT", 0, -8)
        else
            eqTooltip2:SetPoint("TOPLEFT", rightLabel, "BOTTOMLEFT", 0, -4)
        end
        rightH = rightH + math.max(eqTooltip2:GetHeight() or 80, 80) + 8
        rightW = math.max(rightW, eqTooltip2:GetWidth() or 200)
    end

    if emptySlotText:IsShown() then
        emptySlotText:ClearAllPoints()
        if eqTooltip1:IsShown() then
            emptySlotText:SetPoint("TOPLEFT", eqTooltip1, "BOTTOMLEFT", 4, -10)
            rightH = rightH + 28
        else
            emptySlotText:SetPoint("TOPLEFT", rightLabel, "BOTTOMLEFT", 4, -16)
            rightH = 40
        end
    end

    local totalW = math.max(leftW + rightW + 56, 480)
    local totalH = math.max(leftH, rightH) + 92

    promptFrame:SetSize(totalW, math.max(totalH, 260))
end

function FNPA:PromptEquipUpgrade(newItemLink)
    if not newItemLink then return end
    if not isEnabled("autoEquipPrompt") then return end

    local item = GetItemDetails(newItemLink)
    if not item or not item.equipLoc or not EQUIP_LOC_TO_SLOTS[item.equipLoc] then return end

    promptFrame.newItemLink = newItemLink

    -- Resolve target equipped item(s) and all compatible equipped items
    local comparisonList, allEquippedList, hasEmptySlot = ResolveTargetEquippedItems(item)

    -- Populate Left Tooltip (New Upgrade)
    newTooltip:SetOwner(promptFrame, "ANCHOR_NONE")
    newTooltip:ClearAllPoints()
    newTooltip:ClearLines()
    newTooltip:SetHyperlink(newItemLink)

    -- Reset Right Tooltips
    eqTooltip1:Hide()
    eqTooltip2:Hide()
    emptySlotText:Hide()

    leftLabel:ClearAllPoints()
    leftLabel:SetPoint("TOPLEFT", promptFrame, "TOPLEFT", 18, -64)
    newTooltip:SetPoint("TOPLEFT", leftLabel, "BOTTOMLEFT", 0, -4)

    -- Populate Right Column (Target Equipped Item(s))
    local displayList = (#allEquippedList > 0) and allEquippedList or comparisonList

    if #displayList >= 1 then
        local primarySlotName = SLOT_LABELS[displayList[1].slot] or "Equipped"
        if #displayList >= 2 then
            local secondSlotName = SLOT_LABELS[displayList[2].slot] or "Slot 2"
            rightLabel:SetText(string.format("|cFFFF5555[Currently Equipped: %s & %s]|r", primarySlotName, secondSlotName))
        else
            rightLabel:SetText(string.format("|cFFFF5555[Currently Equipped: %s]|r", primarySlotName))
        end

        PopulateEmbeddedEquippedTooltip(eqTooltip1, displayList[1])

        if #displayList >= 2 then
            PopulateEmbeddedEquippedTooltip(eqTooltip2, displayList[2])
        elseif hasEmptySlot then
            emptySlotText:SetText("|cFF00FF00(2nd Slot Empty — Will Fill Empty Slot)|r")
            emptySlotText:Show()
        end

        -- Append Stat Differences (+Green / -Red) onto the New Item Tooltip
        local compareTarget = (#comparisonList > 0) and comparisonList or { displayList[1] }
        local equippedMerged = MergeEquippedInfo(compareTarget)
        local diffLines = BuildStatComparisonLines(item, equippedMerged)

        if #diffLines > 0 then
            local targetLabel = (compareTarget[1] and SLOT_LABELS[compareTarget[1].slot]) or "Equipped"
            if #compareTarget > 1 then targetLabel = "Equipped Weapons" end
            newTooltip:AddLine(" ")
            newTooltip:AddLine("|cFFFFD100Stat Changes vs. " .. targetLabel .. ":|r")
            for _, line in ipairs(diffLines) do
                newTooltip:AddLine("  " .. line)
            end
        end
    else
        rightLabel:SetText("|cFFFF5555[Currently Equipped]|r")
        emptySlotText:SetText("(Nothing Equipped in This Slot)")
        emptySlotText:Show()

        -- Even when slot is empty, show net gained stats in green
        local emptyBaseline = MergeEquippedInfo({})
        local diffLines = BuildStatComparisonLines(item, emptyBaseline)
        if #diffLines > 0 then
            newTooltip:AddLine(" ")
            newTooltip:AddLine("|cFFFFD100Stats Gained (Empty Slot):|r")
            for _, line in ipairs(diffLines) do
                newTooltip:AddLine("  " .. line)
            end
        end
    end

    newTooltip:Show()
    promptFrame:Show()
    UpdatePromptLayout()

    -- Re-adjust layout next frame after WoW finishes calculating tooltip dimensions
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, UpdatePromptLayout)
    end
end

-- Hook GetQuestReward to trigger the preview prompt for choice OR guaranteed upgrade rewards
if hooksecurefunc then
    hooksecurefunc("GetQuestReward", function(choiceIndex)
        if not isEnabled("autoEquipPrompt") then return end

        local upgradeLink = nil
        local bestScore = 0

        -- 1. Check selected choice reward
        local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
        local chosenIndex = (choiceIndex and choiceIndex > 0) and choiceIndex or ((numChoices == 1) and 1 or 0)
        if chosenIndex > 0 and GetQuestItemLink then
            local choiceLink = GetQuestItemLink("choice", chosenIndex)
            if choiceLink then
                local score = GetItemUpgradeScore(choiceLink)
                if score > bestScore then
                    bestScore = score
                    upgradeLink = choiceLink
                end
            end
        end

        -- 2. Also check guaranteed (fixed) quest rewards if no choice upgrade was selected
        local numRewards = GetNumQuestRewards and GetNumQuestRewards() or 0
        if numRewards > 0 and GetQuestItemLink then
            for i = 1, numRewards do
                local rewLink = GetQuestItemLink("reward", i)
                if rewLink then
                    local score = GetItemUpgradeScore(rewLink)
                    if score > bestScore then
                        bestScore = score
                        upgradeLink = rewLink
                    end
                end
            end
        end

        if upgradeLink and bestScore > 0 then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.35, function()
                    FNPA:PromptEquipUpgrade(upgradeLink)
                end)
            else
                FNPA:PromptEquipUpgrade(upgradeLink)
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

-------------------------------------------------------------------------------
-- Centralized Event Handlers
-------------------------------------------------------------------------------
local function IsCurrentQuestDetailTrivial()
    if C_QuestLog and C_QuestLog.IsQuestTrivial and GetQuestID then
        local qID = GetQuestID()
        if qID and qID > 0 then
            local ok, trivial = pcall(C_QuestLog.IsQuestTrivial, qID)
            if ok and trivial ~= nil then
                return trivial and true or false
            end
        end
    end
    if IsCurrentQuestTrivial then
        local ok, trivial = pcall(IsCurrentQuestTrivial)
        if ok and trivial ~= nil then
            return trivial and true or false
        end
    end
    if GetQuestLevel and FNPA.IsQuestLevelTrivial then
        local ok, level = pcall(GetQuestLevel)
        if ok and level then
            return FNPA:IsQuestLevelTrivial(level)
        end
    end
    return false
end

local function ShouldContinueMultiQuestNpc()
    if IsShiftKeyDown and IsShiftKeyDown() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if GossipFrame and GossipFrame:IsShown() then return true end
    if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown() then return true end
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
        local avail = C_GossipInfo.GetAvailableQuests() or {}
        local active = (C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()) or {}
        if #avail > 0 or #active > 0 then return true end
    end
    if GetNumAvailableQuests and (GetNumAvailableQuests() or 0) > 0 then return true end
    if GetNumActiveQuests and (GetNumActiveQuests() or 0) > 0 then return true end
    return false
end

local function ScheduleMultiQuestContinuation()
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(0.25, function()
        if not ShouldContinueMultiQuestNpc() then return end
        if QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then return end
        if QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown() then return end
        if QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then return end

        if GossipFrame and GossipFrame:IsShown() and FNPA.Events["GOSSIP_SHOW"] then
            FNPA:DebugLog("Continuing multi-quest rotation on GossipFrame")
            FNPA.Events["GOSSIP_SHOW"](FNPA)
        elseif QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown() and FNPA.Events["QUEST_GREETING"] then
            FNPA:DebugLog("Continuing multi-quest rotation on QuestFrameGreetingPanel")
            FNPA.Events["QUEST_GREETING"](FNPA)
        elseif C_GossipInfo and C_GossipInfo.GetAvailableQuests and #(C_GossipInfo.GetAvailableQuests() or {}) > 0 and FNPA.Events["GOSSIP_SHOW"] then
            FNPA:DebugLog("Continuing multi-quest rotation via C_GossipInfo")
            FNPA.Events["GOSSIP_SHOW"](FNPA)
        end
    end)
end

FNPA.Events["QUEST_DETAIL"] = function(self)
    FNPA:DebugLog("QuestAutomation event: QUEST_DETAIL")
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if not isEnabled("autoAccept") then return end

    -- Check if the quest is trivial (low-level) and should be ignored
    local allowLowLevel = (FNPA.ShouldAcceptLowLevelQuests and FNPA:ShouldAcceptLowLevelQuests()) or false
    if not allowLowLevel and IsCurrentQuestDetailTrivial() then
        FNPA:DebugLog("QUEST_DETAIL: Ignoring low-level quest offer")
        return
    end

    local function doAcceptQuest()
        if IsShiftKeyDown and IsShiftKeyDown() then return end
        if not isEnabled("autoAccept") then return end
        if not allowLowLevel and IsCurrentQuestDetailTrivial() then return end

        local qID = GetQuestID and GetQuestID() or nil
        local qTitle = GetTitleText and GetTitleText() or nil
        local detailVisible = (QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown())
                           or (QuestFrame and QuestFrame:IsShown())
                           or (qID and qID > 0)

        if detailVisible and AcceptQuest then
            if FNPA.MarkQuestAccepted then
                FNPA:MarkQuestAccepted(qID, qTitle)
            end
            FNPA:DebugLog("Accepting quest: " .. tostring(qTitle or qID or ""))
            AcceptQuest()
            if QuestGetAutoAccept and QuestGetAutoAccept() and CloseQuest then
                CloseQuest()
            end
            ScheduleMultiQuestContinuation()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, doAcceptQuest)
    else
        doAcceptQuest()
    end
end

FNPA.Events["QUEST_ACCEPTED"] = function(self, arg1, arg2)
    local questID = (type(arg2) == "number" and arg2 > 0) and arg2 or (type(arg1) == "number" and arg1 or nil)
    local title = GetTitleText and GetTitleText() or nil
    if FNPA.MarkQuestAccepted then
        FNPA:MarkQuestAccepted(questID, title)
    end
    if isEnabled("autoAccept") then
        ScheduleMultiQuestContinuation()
    end
end

FNPA.Events["QUEST_TURNED_IN"] = function(self, questID)
    if isEnabled("autoAccept") or isEnabled("autoComplete") then
        ScheduleMultiQuestContinuation()
    end
end

FNPA.Events["QUEST_PROGRESS"] = function(self)
    FNPA:DebugLog("QuestAutomation event: QUEST_PROGRESS")
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if not isEnabled("autoComplete") then return end

    if IsQuestCompletable and IsQuestCompletable() then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function() CompleteQuest() end)
        else
            CompleteQuest()
        end
    end
end

FNPA.Events["QUEST_COMPLETE"] = function(self)
    FNPA:DebugLog("QuestAutomation event: QUEST_COMPLETE")
    if IsShiftKeyDown and IsShiftKeyDown() then
        HighlightRewardUpgrades()
        return
    end

    if isEnabled("autoComplete") and isSimpleReward() then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function()
                local choiceIndex = (GetNumQuestChoices and GetNumQuestChoices() == 1) and 1 or 0
                GetQuestReward(choiceIndex)
            end)
        else
            local choiceIndex = (GetNumQuestChoices and GetNumQuestChoices() == 1) and 1 or 0
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
end

FNPA.Events["QUEST_ACCEPT_CONFIRM"] = function(self)
    FNPA:DebugLog("QuestAutomation event: QUEST_ACCEPT_CONFIRM")
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if not isEnabled("autoAccept") then return end
    if ConfirmAcceptQuest then ConfirmAcceptQuest() end
end

FNPA.Events["GET_ITEM_INFO_RECEIVED"] = function(self)
    if IsQuestWindowOpen() then
        HighlightRewardUpgrades()
    end
    if promptFrame and promptFrame:IsShown() and promptFrame.newItemLink then
        FNPA:PromptEquipUpgrade(promptFrame.newItemLink)
    end
end

FNPA.Events["BAG_UPDATE_DELAYED"] = function(self)
    if pendingEquipItemLink and IsItemInPlayerBags(pendingEquipItemLink) then
        local link = pendingEquipItemLink
        pendingEquipItemLink = nil
        TryExecuteEquip(link)
    end
end

FNPA.Events["PLAYER_REGEN_ENABLED"] = function(self)
    if pendingEquipItemLink and IsItemInPlayerBags(pendingEquipItemLink) then
        local link = pendingEquipItemLink
        pendingEquipItemLink = nil
        TryExecuteEquip(link)
    end
end

-- Diagnostic helper to test the Upgrade Popup with any currently equipped item
function FNPA:TestUpgradePopup()
    for _, slot in ipairs({ 16, 5, 1, 7, 11, 13, 3, 8, 9, 10 }) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            self:PromptEquipUpgrade(link)
            return
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Forever NPC Assistant]|r No equipped gear found to preview.")
end
