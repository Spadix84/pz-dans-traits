-- Dan's Vanilla Fixes: rarity colours for modded items in Item Rarity UI.
-- (Was the separate ItemRarityModdedItems mod; the global keeps that name.)
-- Item Rarity UI is not required: without it this does nothing.
--
-- Item Rarity UI colours item names from a table it built ahead of time from
-- the vanilla loot lists, so anything a mod adds (and anything a game update
-- added since) has no entry and shows grey as Unknown. This fills the gaps
-- when a game starts, after every mod's loot has been merged in, using
-- Item Rarity UI's own method:
--
--   for every loot list an item is in:
--     chance += weight / listTotal * min(listItems, 30)/30 * min(listTotal, 10)/10
--
--   under 1%   Legendary (needs 3+ lists, otherwise Rare)
--   under 4%   Epic      (needs 2+ lists, otherwise Uncommon)
--   under 12%  Rare
--   under 40%  Uncommon
--   otherwise  Common
--
-- The lists are ProceduralDistributions, the room and container
-- distributions and the vehicle distributions, as in Item Rarity UI. An item
-- in none of them is looked for in the bag and clutter lists; one in no list
-- at all is Crafted when a recipe makes it, otherwise Uncommon (Item Rarity
-- UI's own default). Checked against the game's lists (42.21): 93% of the
-- vanilla items land in the same tier as Item Rarity UI's table, 99% within
-- one; the rest is the game changing since that table was made.
--
-- Items Item Rarity UI already knows, and its hand-set overrides, are never
-- touched. Another mod can set a tier by hand the same way Item Rarity UI
-- does: ItemRarityUI.rarityOverrides["Module.Item"] = "epic".

-- No require "ItemRarityUI": the work waits for OnGameStart, when every mod's
-- files have loaded, and apply() checks that Item Rarity UI is there.

ItemRarityModdedItems = ItemRarityModdedItems or {}
local M = ItemRarityModdedItems

M.LIST_CAP_ITEMS = 30
M.LIST_CAP_WEIGHT = 10
M.LEGENDARY = 0.01
M.EPIC = 0.04
M.RARE = 0.12
M.UNCOMMON = 0.4
M.LEGENDARY_MIN_LISTS = 3
M.EPIC_MIN_LISTS = 2

local function fullType(name)
    if string.find(name, "%.") then return name end
    return "Base." .. name
end

-- One loot list: { "Item", weight, "Item", weight, ... }. Adds each item's
-- share to acc[fullType] = { chance, occurrences }.
local function addList(acc, items)
    local n, total = 0, 0
    for i = 1, #items, 2 do
        local w = tonumber(items[i + 1])
        if type(items[i]) == "string" and w then
            n = n + 1
            total = total + w
        end
    end
    if n == 0 or total <= 0 then return end
    local listWeight = (math.min(n, M.LIST_CAP_ITEMS) / M.LIST_CAP_ITEMS)
        * (math.min(total, M.LIST_CAP_WEIGHT) / M.LIST_CAP_WEIGHT)
    for i = 1, #items, 2 do
        local w = tonumber(items[i + 1])
        if type(items[i]) == "string" and w then
            local key = fullType(items[i])
            local a = acc[key]
            if not a then
                a = { chance = 0, occurrences = 0 }
                acc[key] = a
            end
            a.chance = a.chance + w / total * listWeight
            a.occurrences = a.occurrences + 1
        end
    end
end

-- Every "items" list anywhere under t. Tables reached twice (room aliases
-- such as SuburbsDistributions.clinic = medical) are counted once.
local function walk(acc, t, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
        if type(v) == "table" then
            if k == "items" then
                if not seen[v] then
                    seen[v] = true
                    addList(acc, v)
                end
            else
                walk(acc, v, seen)
            end
        end
    end
end

-- A flat junk table: ClutterTables.X and BagsAndContainers.X are either the
-- list itself or hold it under .items.
local function walkFlat(acc, group, seen)
    if type(group) ~= "table" then return end
    for _, t in pairs(group) do
        if type(t) == "table" and not seen[t] then
            if t.items then
                walk(acc, t, seen)
            else
                seen[t] = true
                addList(acc, t)
            end
        end
    end
end

-- Returns main, extra: main from the lists Item Rarity UI reads, extra from
-- the bag and clutter lists (used only for items main does not have). The
-- bag and clutter lists go first so that the containers pointing at them
-- (junk = ClutterTables.BinJunk) do not count them again in main: Item
-- Rarity UI leaves them out, and counting them puts vanilla items a tier off.
function M.scanLoot()
    local main, extra, seen = {}, {}, {}
    walkFlat(extra, BagsAndContainers, seen)
    walkFlat(extra, ClutterTables, seen)
    walkFlat(extra, VehicleClutterTables, seen)
    if ProceduralDistributions and ProceduralDistributions.list then
        walk(main, ProceduralDistributions.list, seen)
    end
    walk(main, SuburbsDistributions or (Distributions and Distributions[1]), seen)
    walk(main, VehicleDistributions and VehicleDistributions[1], seen)
    return main, extra
end

function M.tier(chance, occurrences)
    if chance < M.LEGENDARY then
        return occurrences >= M.LEGENDARY_MIN_LISTS and "legendary" or "rare"
    elseif chance < M.EPIC then
        return occurrences >= M.EPIC_MIN_LISTS and "epic" or "uncommon"
    elseif chance < M.RARE then
        return "rare"
    elseif chance < M.UNCOMMON then
        return "uncommon"
    end
    return "common"
end

local function isCrafted(script)
    local ok, v = pcall(function() return script:isCraftRecipeProduct() end)
    return ok and v == true
end

-- Fills ItemRarityUI.itemRarities for every item script it lacks. Returns
-- the number of items added.
function M.apply()
    local ui = ItemRarityUI
    if not ui or not ui.rarityTiers then return 0 end   -- Item Rarity UI is not active
    if ui.loadRarityData and not ui.dataLoaded then ui.loadRarityData() end
    ui.itemRarities = ui.itemRarities or {}
    local known = ui.itemRarities
    local main, extra = M.scanLoot()
    local all = getScriptManager():getAllItems()
    local added, byTier = 0, {}
    for i = 0, all:size() - 1 do
        local script = all:get(i)
        local key = script:getFullName()
        if key and not known[key] then
            local loot = main[key] or extra[key]
            local rarity
            if loot then
                rarity = M.tier(loot.chance, loot.occurrences)
            elseif isCrafted(script) then
                rarity = "crafted"
            else
                rarity = "uncommon"
            end
            local tierData = ui.rarityTiers[rarity]
            if tierData then
                known[key] = {
                    chance = loot and loot.chance or 0,
                    rarity = rarity,
                    occurrences = loot and loot.occurrences or 0,
                    color = tierData.color,
                }
                added = added + 1
                byTier[rarity] = (byTier[rarity] or 0) + 1
            end
        end
    end
    local parts = {}
    for _, name in ipairs({ "legendary", "epic", "rare", "uncommon", "common", "crafted" }) do
        if byTier[name] then parts[#parts + 1] = name .. " " .. byTier[name] end
    end
    print("[ItemRarityModdedItems] Added rarity for " .. added .. " items Item Rarity UI did not know ("
        .. table.concat(parts, ", ") .. ")")
    return added
end

local done = false
local function onGameStart()
    if done then return end
    done = true
    local ok, err = pcall(M.apply)
    if not ok then print("[ItemRarityModdedItems] Failed: " .. tostring(err)) end
end

Events.OnGameStart.Add(onGameStart)
