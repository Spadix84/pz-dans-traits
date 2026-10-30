-- Dan's Vanilla Fixes: item names coloured by how rare the item is, after
-- Item Rarity UI (Endi Monan), without its Rarity column in the inventory.
-- Sandbox option Rarity Colours (Item Info page) turns it off.
--
-- Item Rarity UI read its tiers from a table built ahead of time from the
-- vanilla lists, so modded items (and anything newer than the table) came out
-- grey as Unknown. This works out every item's tier when a game starts, from
-- the loot lists as they are then, after every mod's loot has been merged
-- in, using Item Rarity UI's method:
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
-- distributions and the vehicle distributions. An item in none of them is
-- looked for in the bag and clutter lists; one in no list at all is Crafted
-- when a recipe makes it, otherwise Uncommon. Checked against the game's
-- lists (42.21): 93% of the vanilla items land in the same tier as Item
-- Rarity UI's table, 99% within one.
--
-- The name in the inventory list takes the tier's colour (Common keeps the
-- pane's own colour; an Unwanted item stays greyed out), with vanilla's
-- inventory or CleanUI's, and the tooltip says the tier in the same colour. Another mod can set a tier by hand:
-- DVF_Rarity.overrides["Module.Item"] = "epic".
--
-- With Item Rarity UI itself still on, this steps aside and only fills the
-- items its table lacks, as it did before.
require "ISUI/ISInventoryPane"
require "DanShared_Tooltip"

DVF_Rarity = DVF_Rarity or {}
local M = DVF_Rarity

M.LIST_CAP_ITEMS = 30
M.LIST_CAP_WEIGHT = 10
M.LEGENDARY = 0.01
M.EPIC = 0.04
M.RARE = 0.12
M.UNCOMMON = 0.4
M.LEGENDARY_MIN_LISTS = 3
M.EPIC_MIN_LISTS = 2

M.TIERS = {
    legendary = { key = "Legendary", r = 1.0, g = 0.5, b = 0.0 },
    epic = { key = "Epic", r = 0.7, g = 0.3, b = 0.9 },
    rare = { key = "Rare", r = 0.4, g = 0.6, b = 1.0 },
    uncommon = { key = "Uncommon", r = 0.3, g = 0.9, b = 0.3 },
    common = { key = "Common", r = 0.7, g = 0.7, b = 0.7 },
    crafted = { key = "Crafted", r = 0.5, g = 0.85, b = 0.85 },
}

-- every character starts with keys: the loot lists make them look rare
M.overrides = M.overrides or {}
for _, t in ipairs({ "Base.KeyRing", "Base.Key1", "Base.CarKey" }) do
    if M.overrides[t] == nil then M.overrides[t] = "common" end
end

M.data = M.data or {}   -- fullType -> { rarity, chance, occurrences }
M.ready = false
M.iruiActive = false

local function opt(name, default)
    local o = SandboxVars and SandboxVars.DansVanillaFixes
    local v = o and o[name]
    if v == nil then return default end
    return v
end

function M.enabled()
    return M.ready and not M.iruiActive and opt("RarityColours", true)
end

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

-- Returns main, extra: main from the room, container, procedural and vehicle
-- lists, extra from the bag and clutter lists (used only for items main does
-- not have). The bag and clutter lists go first so that the containers
-- pointing at them (junk = ClutterTables.BinJunk) do not count them again in
-- main: Item Rarity UI leaves them out, and counting them puts vanilla items
-- a tier off.
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

-- The tier name for an item's full type, or nil before the game has started.
function M.rarityOf(ft)
    local o = ft and M.overrides[ft]
    if o and M.TIERS[o] then return o end
    local d = ft and M.data[ft]
    return d and d.rarity or nil
end

function M.colourOf(ft)
    local r = M.rarityOf(ft)
    return r and M.TIERS[r] or nil
end

-- Works out every item script's tier. Returns the number of items. With no
-- loot lists in reach (nothing to go on) it leaves everything uncoloured.
function M.compute()
    local main, extra = M.scanLoot()
    local any = false
    for _ in pairs(main) do any = true break end
    if not any then
        print("[DVF Rarity] No loot lists found, rarity colours off")
        return 0
    end
    local data, count, byTier = {}, 0, {}
    local all = getScriptManager():getAllItems()
    for i = 0, all:size() - 1 do
        local script = all:get(i)
        local key = script:getFullName()
        if key then
            local loot = main[key] or extra[key]
            local rarity
            if loot then
                rarity = M.tier(loot.chance, loot.occurrences)
            elseif isCrafted(script) then
                rarity = "crafted"
            else
                rarity = "uncommon"
            end
            data[key] = { rarity = rarity, chance = loot and loot.chance or 0, occurrences = loot and loot.occurrences or 0 }
            count = count + 1
            byTier[rarity] = (byTier[rarity] or 0) + 1
        end
    end
    M.data = data
    M.ready = true
    local parts = {}
    for _, name in ipairs({ "legendary", "epic", "rare", "uncommon", "common", "crafted" }) do
        if byTier[name] then parts[#parts + 1] = name .. " " .. byTier[name] end
    end
    print("[DVF Rarity] Rarity for " .. count .. " items (" .. table.concat(parts, ", ") .. ")")
    return count
end

-- Item Rarity UI on as well: give it the tiers its table lacks. Returns the
-- number added.
function M.fillItemRarityUI()
    local ui = ItemRarityUI
    if not ui or not ui.rarityTiers then return 0 end
    if ui.loadRarityData and not ui.dataLoaded then ui.loadRarityData() end
    ui.itemRarities = ui.itemRarities or {}
    local known, added = ui.itemRarities, 0
    for key, d in pairs(M.data) do
        local tierData = not known[key] and ui.rarityTiers[d.rarity]
        if tierData then
            known[key] = { chance = d.chance, rarity = d.rarity, occurrences = d.occurrences, color = tierData.color }
            added = added + 1
        end
    end
    print("[DVF Rarity] Item Rarity UI is on: added " .. added .. " items its table lacked")
    return added
end

function M.apply()
    M.compute()
    M.iruiActive = ItemRarityUI ~= nil and ItemRarityUI.rarityTiers ~= nil
    if M.iruiActive and M.ready then M.fillItemRarityUI() end
end

-- the inventory list -------------------------------------------------------------

-- Which item a name belongs to: vanilla's renderdetails, and CleanUI's that
-- replaces it, add each row to pane.items just before drawing it, the
-- stack's table for a stack's own row and the bare item for the rows of an
-- opened stack. So text drawn in the name column while the last row is a
-- stack's table is that stack's name, however the pane places, colours or
-- shortens it (CleanUI has its own name colour, padding and "..."). An
-- Unwanted item keeps its greyed name, the red of a full container stays
-- red, and a Common item keeps the pane's own colour. The names of dragged
-- items (doDragged) are left alone: no rows are added while they are drawn.
function M.nameColour(pane, text, x, r, g, b)
    if type(text) ~= "string" or (r == 0.7 and g == 0 and b == 0) then return nil end
    local rows = pane.items
    local row = rows and rows[#rows]
    if type(row) ~= "table" or type(row.items) ~= "table" then return nil end
    local left, right = pane.column2 or 0, pane.column3
    if x < left or (right and x >= right) then return nil end
    local item = row.items[1]
    if not item then return nil end
    local ok, unwanted = pcall(item.isUnwanted, item, getSpecificPlayer(pane.player))
    if ok and unwanted then return nil end
    local rarity = M.rarityOf(item:getFullType())
    if rarity == "common" then return nil end
    return rarity and M.TIERS[rarity] or nil
end

local ours = {}   -- the wrappers, so a class is never wrapped twice

-- Wraps cls.renderdetails. CleanUI swaps the global ISInventoryPane between
-- two classes of its own, so every class a pane can come from is wrapped.
function M.wrapPane(cls)
    if type(cls) ~= "table" or type(cls.renderdetails) ~= "function" or ours[cls.renderdetails] then return end
    local original = cls.renderdetails
    local wrapper = function(self, doDragged)
        if doDragged or not M.enabled() then return original(self, doDragged) end
        local own = rawget(self, "drawText")
        local draw = self.drawText
        self.drawText = function(pane, text, x, y, r, g, b, a, font)
            local c = M.nameColour(pane, text, x, r, g, b)
            if c then r, g, b = c.r, c.g, c.b end
            return draw(pane, text, x, y, r, g, b, a, font)
        end
        local ok, res = pcall(original, self, doDragged)
        self.drawText = own
        if not ok then error(res) end
        return res
    end
    ours[wrapper] = true
    cls.renderdetails = wrapper
end

function M.wrapPanes()
    M.wrapPane(ISInventoryPane)
    M.wrapPane(CleanUI_Clean_ISInventoryPane)
    M.wrapPane(CleanUI_Vanilla_ISInventoryPane)
end

M.wrapPanes()

-- the tooltip ----------------------------------------------------------------------

function M.lines(player, item)
    if not M.enabled() then return nil end
    local tier = M.TIERS[M.rarityOf(item:getFullType()) or ""]
    if not tier then return nil end
    local name = getText("IGUI_DVF_Rarity_" .. tier.key)
    return { { getText("IGUI_DVF_Rarity_Line", name), tier.r, tier.g, tier.b } }
end

DanShared_Tooltip.add("rarity", 5, M.lines)

local done = false
local function onGameStart()
    if done then return end
    done = true
    pcall(M.wrapPanes)   -- CleanUI's classes exist by now
    local ok, err = pcall(M.apply)
    if not ok then print("[DVF Rarity] Failed: " .. tostring(err)) end
end

Events.OnGameStart.Add(onGameStart)
