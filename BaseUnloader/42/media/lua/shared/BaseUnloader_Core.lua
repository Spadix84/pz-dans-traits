-- Base Unloader: the part with no game objects in it. Container keys, the
-- saved data (names, rules, plans), grouping the items to unload, the rules
-- that say where an item type goes, suggesting a home for what has none, and
-- planning one trip: what to carry and where to walk, nearest first.
--
-- The client files (BaseUnloader_Scan, _Run, _UI, _Menu) turn the game's
-- objects into the plain records this file works on:
--
--   an item       { id, fullType, category, name, weight, favorite, equipped, food, perishable }
--   a container   { key, kind, x, y, z, free, contents = { [fullType] = n }, cats = { [category] = n } }
--
-- so every rule here can be tested offline.

BaseUnloader = BaseUnloader or {}
local BU = BaseUnloader

BU.VERSION = "0.1.0"
BU.NEVER_OFF = 1000000000     -- Food.getOffAgeMax() for food that never goes off
BU.FLOOR_COST = 40            -- a change of floor costs this many tiles of walking in the planner (the stairs are never next to you)
BU.CAT_PREFIX = "cat:"        -- a rule keyed "cat:Food" sends a whole display category

-- keys ------------------------------------------------------------------------------

-- A world container has no stable id, so it is keyed by where it is, what it
-- is and which of its object's containers it is (a fridge has two).
function BU.key(x, y, z, kind, index)
    return string.format("%d,%d,%d:%s:%d", x, y, z, kind or "?", index or 0)
end

function BU.parseKey(key)
    if type(key) ~= "string" then return nil end
    local x, y, z, kind, index = string.match(key, "^(-?%d+),(-?%d+),(-?%d+):([^:]*):(%d+)$")
    if not x then return nil end
    return { x = tonumber(x), y = tonumber(y), z = tonumber(z), kind = kind, index = tonumber(index) }
end

-- the saved data ----------------------------------------------------------------------

-- One table per save, in the world's mod data when the game offers it
-- (ModData.getOrCreate), else a table that lives for the session.
--   names[key]           what the player called a container
--   rules[fullType]      the key of the container that item type goes in
--   rules["cat:<cat>"]   the key a whole display category goes in
--   plans[who]           an unfinished run: { source, oneOffs, carried }
--   hidden[key]          containers kept out of the window's list
--   tags[key]            { [category] = true }: the categories a container takes
function BU.store()
    if BU._store then return BU._store end
    local d
    pcall(function()
        if ModData and ModData.getOrCreate then d = ModData.getOrCreate("BaseUnloader") end
    end)
    d = d or {}
    d.names = d.names or {}
    d.rules = d.rules or {}
    d.plans = d.plans or {}
    d.hidden = d.hidden or {}
    d.tags = d.tags or {}
    BU._store = d
    return d
end

-- a new save was loaded: read its table afresh
function BU.resetStore()
    BU._store = nil
end

-- rules -------------------------------------------------------------------------------

function BU.catKey(category)
    return BU.CAT_PREFIX .. tostring(category or "?")
end

-- where an item goes: a one-off for this very item first, then its type's
-- rule, then its category's; nil when nothing says
function BU.destinationOf(item, rules, oneOffs)
    if oneOffs and item.id ~= nil and oneOffs[item.id] then return oneOffs[item.id] end
    if not rules then return nil end
    if item.fullType and rules[item.fullType] then return rules[item.fullType] end
    if item.category and rules[BU.catKey(item.category)] then return rules[BU.catKey(item.category)] end
    return nil
end

-- key nil clears the rule
function BU.setRule(rules, ruleKey, key)
    rules[ruleKey] = key
end

-- every rule pointing at a container that is gone or being cleared
function BU.clearRulesTo(rules, key)
    local n = 0
    for k, v in pairs(rules) do
        if v == key then rules[k] = nil; n = n + 1 end
    end
    return n
end

-- how many rules point at each container key
function BU.ruleCounts(rules)
    local counts = {}
    for _, key in pairs(rules) do counts[key] = (counts[key] or 0) + 1 end
    return counts
end

-- tags --------------------------------------------------------------------------------

-- the display categories offered for tagging; any other seen on an item joins the list
BU.CATEGORIES = {
    "Accessory", "Ammo", "Bag", "Camping", "Clothing", "Communications", "Container", "Cooking",
    "Electronics", "Entertainment", "Explosives", "FirstAid", "Fishing", "Food", "Furniture",
    "Gardening", "Household", "Instrument", "Junk", "Key", "LightSource", "Literature", "Material",
    "Memento", "Mechanics", "Paint", "Security", "Sports", "Tool", "Trapping", "VehicleMaintenance",
    "WaterContainer", "Weapon", "WeaponPart",
}

function BU.setTag(tags, key, category, on)
    local t = tags[key]
    if on then
        if not t then t = {}; tags[key] = t end
        t[category] = true
    elseif t then
        t[category] = nil
        local any = false
        for _ in pairs(t) do any = true end
        if not any then tags[key] = nil end
    end
end

function BU.hasTag(tags, key, category)
    local t = tags[key]
    return t ~= nil and t[category] == true
end

-- a container's tags as a sorted list
function BU.tagsOf(tags, key)
    local out = {}
    for cat in pairs(tags[key] or {}) do out[#out + 1] = cat end
    table.sort(out)
    return out
end

-- Where an item's category is welcome: among the containers tagged with it,
-- the one already holding that type, else the one with most room. Rules
-- come first (see destinationOf); this is the fallback for whole categories.
function BU.tagDestination(item, tags, containers)
    if not item.category or not tags then return nil end
    local best, bestN, room = nil, 0, -1
    for _, c in ipairs(containers) do
        if BU.hasTag(tags, c.key, item.category) then
            local n = c.contents and item.fullType and c.contents[item.fullType] or 0
            if n > bestN then
                best, bestN = c, n
            elseif bestN == 0 and (c.free or 0) > room then
                best, room = c, c.free or 0
            end
        end
    end
    return best and best.key or nil
end

-- the items -----------------------------------------------------------------------------

-- what a run leaves alone: favourites and anything worn or held
function BU.movable(item)
    return not item.favorite and not item.equipped
end

-- the items grouped by type, each group with its count and weight, sorted by name
function BU.groups(items)
    local byType, list = {}, {}
    for _, item in ipairs(items) do
        if BU.movable(item) then
            local g = byType[item.fullType]
            if not g then
                g = { fullType = item.fullType, name = item.name, category = item.category, count = 0, weight = 0,
                      items = {}, food = item.food, perishable = item.perishable }
                byType[item.fullType] = g
                list[#list + 1] = g
            end
            g.count = g.count + 1
            g.weight = g.weight + (item.weight or 0)
            g.items[#g.items + 1] = item
        end
    end
    table.sort(list, function(a, b)
        if a.name == b.name then return a.fullType < b.fullType end
        return a.name < b.name
    end)
    return list
end

-- suggestions -------------------------------------------------------------------------------

local function containerByKey(containers)
    local byKey = {}
    for _, c in ipairs(containers) do byKey[c.key] = c end
    return byKey
end

-- container kinds that suit a display category, when nothing in the base says
-- otherwise; matched as a substring of the container type, lower case
BU.KIND_HINTS = {
    Food = { "fridge", "freezer", "counter", "shelves" },
    Clothing = { "wardrobe", "dresser", "clothingrack", "locker" },
    FirstAid = { "medicine", "counter" },
    Literature = { "shelves", "bookcase", "bookshelf", "desk" },
    Weapon = { "guncase", "gun", "locker", "wardrobe" },
    Ammo = { "guncase", "gun", "locker", "desk" },
    Tool = { "toolcabinet", "crate", "metal_shelves", "shelves" },
    Material = { "crate", "metal_shelves", "shelves" },
    Camping = { "crate", "wardrobe" },
    Electronics = { "desk", "shelves", "crate" },
}

local function isCold(c)
    local k = string.lower(c.kind or "")
    return string.find(k, "fridge", 1, true) ~= nil or string.find(k, "freezer", 1, true) ~= nil
end

local function kindMatches(c, hints)
    local k = string.lower(c.kind or "")
    for i, h in ipairs(hints) do
        if string.find(k, h, 1, true) then return i end
    end
    return nil
end

-- A home for each group that has no rule yet: the container already holding
-- most of that type; else, for perishable food, the fridge or freezer with
-- most room; else the container holding most of the category; else the first
-- container of a kind that suits the category. Returns { [fullType] = key }.
function BU.suggest(groups, containers, rules)
    local out = {}
    for _, g in ipairs(groups) do
        local probe = { fullType = g.fullType, category = g.category }
        if not BU.destinationOf(probe, rules, nil) then
            local best, bestN = nil, 0
            for _, c in ipairs(containers) do
                local n = c.contents and c.contents[g.fullType] or 0
                if n > bestN then best, bestN = c, n end
            end
            if not best and g.perishable then
                local room = -1
                for _, c in ipairs(containers) do
                    if isCold(c) and (c.free or 0) > room then best, room = c, c.free or 0 end
                end
            end
            if not best then
                for _, c in ipairs(containers) do
                    local n = c.cats and g.category and c.cats[g.category] or 0
                    if n > bestN then best, bestN = c, n end
                end
            end
            if not best and g.category and BU.KIND_HINTS[g.category] then
                local rank = 99
                for _, c in ipairs(containers) do
                    local r = kindMatches(c, BU.KIND_HINTS[g.category])
                    if r and r < rank then best, rank = c, r end
                end
            end
            if best then out[g.fullType] = best.key end
        end
    end
    return out
end

-- the trip ---------------------------------------------------------------------------------

-- walking cost between two places; a floor change costs FLOOR_COST tiles
function BU.dist(a, b)
    local dx, dy, dz = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy) + math.abs(dz) * BU.FLOOR_COST
end

-- The next trip. items: records with .dest (a container key) set, taken in the
-- order given; containers: the list of records (free = weight the container
-- still takes); from: where the character stands; budget: weight they can
-- still carry. Containers are visited nearest first from the character, then
-- from the last stop; a container's items are taken while they fit the budget
-- and the container's room. A single item heavier than the whole budget is
-- still taken when nothing else has been, so a heavy item never stalls a run.
-- An item's carry (what it costs to carry: zero once it fits a worn bag, set
-- by the caller) counts against the budget; its weight counts against the
-- container's room. Every destination is tried, so a bag's worth is taken
-- even when the hands are already full.
-- Returns { stops = { { key, items } }, weight (the carry total), skipped = { noRoom = n, noContainer = n } }.
function BU.trip(items, containers, from, budget)
    local byKey = containerByKey(containers)
    local byDest, order = {}, {}
    local skipped = { noRoom = 0, noContainer = 0 }
    for _, item in ipairs(items) do
        if item.dest then
            if byKey[item.dest] then
                if not byDest[item.dest] then byDest[item.dest] = {}; order[#order + 1] = item.dest end
                local list = byDest[item.dest]
                list[#list + 1] = item
            else
                skipped.noContainer = skipped.noContainer + 1
            end
        end
    end
    local stops, weight, left = {}, 0, budget or 0
    local here = from or { x = 0, y = 0, z = 0 }
    local remaining = {}
    for _, key in ipairs(order) do remaining[#remaining + 1] = key end
    while #remaining > 0 do
        local bestI, bestD = 1, nil
        for i, key in ipairs(remaining) do
            local d = BU.dist(here, byKey[key])
            if bestD == nil or d < bestD then bestI, bestD = i, d end
        end
        local key = table.remove(remaining, bestI)
        local c = byKey[key]
        local room = c.free
        local take = {}
        for _, item in ipairs(byDest[key]) do
            local w = item.weight or 0
            local cw = item.carry or w
            -- free to carry (it rides in a bag), within what the hands can still take, or the
            -- one item a trip always takes so a heavy item never stalls a run
            local fits = cw <= 0 or cw <= left or (weight == 0 and #take == 0)
            if room ~= nil and w > room then
                fits = false
                skipped.noRoom = skipped.noRoom + 1
            end
            if fits then
                take[#take + 1] = item
                left = left - cw
                weight = weight + cw
                if room ~= nil then room = room - w end
            end
        end
        if #take > 0 then
            stops[#stops + 1] = { key = key, items = take }
            here = c
        end
    end
    return { stops = stops, weight = weight, skipped = skipped }
end

-- A tour through the points (each with x, y, z) starting at `from` and, when
-- `back` is given, ending near it: nearest-next first, then two-opt until no
-- pair of legs can be uncrossed. The floor cost in dist keeps a floor's stops
-- together. Returns the points in visiting order.
function BU.tour(points, from, back)
    local n = #points
    if n <= 1 then return { points[1] } end
    local remaining, order = {}, {}
    for i, p in ipairs(points) do remaining[i] = p end
    local here = from or points[1]
    while #remaining > 0 do
        local bestI, bestD = 1, nil
        for i, p in ipairs(remaining) do
            local d = BU.dist(here, p)
            if bestD == nil or d < bestD then bestI, bestD = i, d end
        end
        here = table.remove(remaining, bestI)
        order[#order + 1] = here
    end
    -- two-opt: reversing order[i..j] swaps the legs into i and out of j
    local function at(i)
        if i == 0 then return from end
        if i == n + 1 then return back end
        return order[i]
    end
    local function leg(a, b)
        if not a or not b then return 0 end
        return BU.dist(a, b)
    end
    local improved, guard = true, 0
    while improved and guard < 50 do
        improved = false
        guard = guard + 1
        for i = 1, n - 1 do
            for j = i + 1, n do
                local before = leg(at(i - 1), order[i]) + leg(order[j], at(j + 1))
                local after = leg(at(i - 1), order[j]) + leg(order[i], at(j + 1))
                if after + 0.0001 < before then
                    local a, b = i, j
                    while a < b do
                        order[a], order[b] = order[b], order[a]
                        a, b = a + 1, b - 1
                    end
                    improved = true
                end
            end
        end
    end
    return order
end

-- the cost of walking a tour: from, every point in order, then back when given
function BU.tourCost(order, from, back)
    local total, here = 0, from
    for _, p in ipairs(order) do
        if here then total = total + BU.dist(here, p) end
        here = p
    end
    if back and here then total = total + BU.dist(here, back) end
    return total
end

-- the stops a delivery makes with what is already carried: a tour from where
-- the character stands, ending near `back` (the source, for the next load)
function BU.deliveryOrder(carried, containers, from, back)
    local byKey = containerByKey(containers)
    local byDest, points = {}, {}
    local lost = {}
    for _, item in ipairs(carried) do
        if item.dest and byKey[item.dest] then
            if not byDest[item.dest] then byDest[item.dest] = {}; points[#points + 1] = byKey[item.dest] end
            local list = byDest[item.dest]
            list[#list + 1] = item
        else
            lost[#lost + 1] = item
        end
    end
    local stops = {}
    for _, c in ipairs(BU.tour(points, from, back)) do
        stops[#stops + 1] = { key = c.key, items = byDest[c.key] }
    end
    return stops, lost
end

-- labels -------------------------------------------------------------------------------------

-- the floor as a translation key suffix: Ground, Basement or Upper with the number
function BU.floorKey(z)
    z = z or 0
    if z == 0 then return "Ground", nil end
    if z < 0 then return "Basement", -z end
    return "Upper", z
end

-- which way (dx, dy) points, in the game's frame (north is -y): N, NE, E ... or nil on the spot
function BU.compass(dx, dy)
    if dx == 0 and dy == 0 then return nil end
    local ax, ay = math.abs(dx), math.abs(dy)
    local ns = dy < 0 and "N" or "S"
    local ew = dx > 0 and "E" or "W"
    -- within about 22 degrees of an axis it is just that axis
    if ax >= ay * 2.414 then return ew end
    if ay >= ax * 2.414 then return ns end
    return ns .. ew
end

-- a room id as the game writes it ("livingroom", "bedroom", "kitchen") into words
BU.ROOM_WORDS = {
    livingroom = "Living room", diningroom = "Dining room", bedroom = "Bedroom", kitchen = "Kitchen",
    bathroom = "Bathroom", garage = "Garage", hall = "Hall", closet = "Closet", laundry = "Laundry",
    office = "Office", storage = "Storage", storageunit = "Storage unit", shed = "Shed", basement = "Basement",
    toolstore = "Tool store", warehouse = "Warehouse", restaurantkitchen = "Restaurant kitchen",
    gunstore = "Gun store", pharmacy = "Pharmacy", grocery = "Grocery", bar = "Bar", library = "Library",
}

function BU.roomWords(id)
    if not id or id == "" then return nil end
    local lower = string.lower(id)
    if BU.ROOM_WORDS[lower] then return BU.ROOM_WORDS[lower] end
    local s = string.gsub(lower, "_", " ")
    return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

-- weight as the inventory shows it: one decimal, no trailing .0
function BU.fmtWeight(w)
    w = math.floor((w or 0) * 10 + 0.5) / 10
    if w == math.floor(w) then return string.format("%d", w) end
    return string.format("%.1f", w)
end
