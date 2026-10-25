-- Base Unloader: the part with no game objects in it. Container keys, the
-- saved data (names, rules, plans), grouping the items to unload, the rules
-- that say where an item type goes, suggesting a home for what has none, and
-- planning one trip: what to carry and where to walk, nearest first.
--
-- The client files (BaseUnloader_Scan, _Run, _UI, _Menu) turn the game's
-- objects into the plain records this file works on:
--
--   an item       { id, fullType, category, name, weight, favorite, equipped, food, perishable, longLife }
--   a container   { key, kind, x, y, z, free, contents = { [fullType] = n }, cats = { [category] = n } }
--
-- so every rule here can be tested offline.

BaseUnloader = BaseUnloader or {}
local BU = BaseUnloader

BU.VERSION = "0.1.0"
BU.NEVER_OFF = 1000000000     -- Food.getOffAgeMax() for food that never goes off
BU.MAX_LOAD_LEVEL = 2         -- default sandbox MaxLoad: the highest Heavy Load moodle level a run may reach
BU.LOAD_STEP = 0.25           -- each Heavy Load level is another quarter of the max weight
BU.LONG_LIFE_DAYS = 90        -- food that takes this long to rot (ramen, mac and cheese, oats, pet food) lives on a shelf
BU.FLOOR_COST = 40            -- a change of floor costs this many tiles of walking in the planner (the stairs are never next to you)
BU.CAT_PREFIX = "cat:"        -- a rule keyed "cat:Food" sends a whole display category
BU.LAUNDRY_TAG = "Laundry"    -- the tag (not a game category) that marks where dirty clothes go
BU.LAUNDRY_KINDS = { clothingdryerbasic = 1, clothingwasher = 2 }   -- the laundry cart, then the washer
BU.GARBAGE_TAG = "Garbage"
BU.GARBAGE_KINDS = { bin = true, dumpster = true, composter = true }
BU.COLD_KINDS = { freezer = 1, icecream = 1, fridge = 2 }           -- fresh food: a freezer, else a fridge

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
--   offLimits[key]       containers a run never picks itself: only types dragged onto them and one-offs go in
--   tags[key]            { [category] = true }: the categories a container takes
--   lastTags             the last set of categories given by hand, sorted, for "apply to this one
--                        too"; forgotten when a game starts (it is for the container after this one,
--                        not for next week)
--   zones                the base zones drawn: { { name, x1, y1, x2, y2, z } }, corners inclusive;
--                        pieces with the same name are one zone
--   stock[piece key]     what one piece of zone held when last looked at (BU.pieceKey): { zone =
--                        its name, at = world hours, items = { { t = fullType, n = name, c = category,
--                        k = container key, cn = container name, q = how many } } }, so the counts
--                        hold while you are away
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
    d.offLimits = d.offLimits or {}
    d.tags = d.tags or {}
    d.zones = d.zones or {}
    d.stock = d.stock or {}
    -- rules keyed by category are from before the tags; the resolver never reads
    -- them, and left in place they muted the suggestions for that whole category
    local stale = {}
    for k in pairs(d.rules) do
        if type(k) == "string" and k:sub(1, #BU.CAT_PREFIX) == BU.CAT_PREFIX then stale[#stale + 1] = k end
    end
    for _, k in ipairs(stale) do d.rules[k] = nil end
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

-- where an item goes by the player's word alone: a one-off for this very item
-- first, then its type's rule; nil when nothing says. (Whole-category rules,
-- "cat:Food", went with the category tags; BU.store drops any left in a save.)
function BU.destinationOf(item, rules, oneOffs)
    if oneOffs and item.id ~= nil and oneOffs[item.id] then return oneOffs[item.id] end
    if not rules then return nil end
    if item.fullType and rules[item.fullType] then return rules[item.fullType] end
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
    "Garbage", "Gardening", "Household", "Instrument", "Junk", "Key", "Laundry", "LightSource", "Literature", "Material",
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

-- tag a container with every category found inside it (cats: { [category] = n });
-- returns how many tags were new
function BU.tagFromContents(tags, key, cats)
    local added = 0
    for cat, n in pairs(cats or {}) do
        if n > 0 and not BU.hasTag(tags, key, cat) then
            BU.setTag(tags, key, cat, true)
            added = added + 1
        end
    end
    return added
end

-- a container's tags as a sorted list
function BU.tagsOf(tags, key)
    local out = {}
    for cat in pairs(tags[key] or {}) do out[#out + 1] = cat end
    table.sort(out)
    return out
end

-- The last categories set by hand, kept so the next container can take the
-- same set in one click. A container left with no tags changes nothing.
function BU.noteTags(store, key)
    local list = BU.tagsOf(store.tags, key)
    if #list > 0 then store.lastTags = list end
end

-- the remembered set, when there is one and the container does not already have exactly it
function BU.lastTagsFor(store, key)
    local last = store.lastTags
    if not last or #last == 0 then return nil end
    local have = BU.tagsOf(store.tags, key)
    if #have == #last then
        local same = true
        for i, cat in ipairs(last) do
            if have[i] ~= cat then same = false end
        end
        if same then return nil end
    end
    return last
end

-- every one of these containers loses its tags; returns how many had any
function BU.clearTagsOf(tags, keys)
    local n = 0
    for _, key in ipairs(keys) do
        if tags[key] then tags[key] = nil; n = n + 1 end
    end
    return n
end

-- the container's tags become the remembered set, replacing what it had
function BU.applyLastTags(store, key)
    local last = store.lastTags
    if not last or #last == 0 then return false end
    store.tags[key] = nil
    for _, cat in ipairs(last) do BU.setTag(store.tags, key, cat, true) end
    return true
end

-- Where dirty or bloody clothing goes: a container tagged Laundry, else the
-- laundry cart, else the washer; the one with most room. nil with none about.
-- hidden (optional, a set of keys): containers never picked by their kind
function BU.laundryDestination(item, tags, containers, hidden)
    if not item.laundry then return nil end
    local best, bestRank, room = nil, 99, -1
    for _, c in ipairs(containers) do
        local rank = nil
        if BU.hasTag(tags, c.key, BU.LAUNDRY_TAG) then
            rank = 0
        elseif BU.LAUNDRY_KINDS[string.lower(c.kind or "")] and not (hidden and hidden[c.key]) then
            rank = BU.LAUNDRY_KINDS[string.lower(c.kind or "")]
        end
        if rank and (rank < bestRank or (rank == bestRank and (c.free or 0) > room)) then
            best, bestRank, room = c, rank, c.free or 0
        end
    end
    return best and best.key or nil
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

-- the resolver ---------------------------------------------------------------------------------

local function lowerKind(c) return string.lower(c.kind or "") end
local function isBin(c) return BU.GARBAGE_KINDS[lowerKind(c)] == true end
local function isLaundryKind(c) return BU.LAUNDRY_KINDS[lowerKind(c)] ~= nil end
local function isColdKind(c) return BU.COLD_KINDS[lowerKind(c)] ~= nil end
-- any fridge or freezer, a modded one too (its type names it)
local function isCold(c)
    local k = lowerKind(c)
    return isColdKind(c) or string.find(k, "fridge", 1, true) ~= nil or string.find(k, "freezer", 1, true) ~= nil
end

-- does this item belong in the cold: fresh food that goes off within LONG_LIFE_DAYS
-- (only food is ever perishable)
function BU.wantsCold(item)
    return item.perishable == true and not item.longLife and not item.rotten and not item.stale
end

-- has the container room for the item, counting what this step already planned into it
local function roomFor(c, item, use)
    if c.free == nil then return true end
    return (c.free - (use and use[c.key] or 0)) >= (item.weight or 0)
end

-- the container scoring highest; ties go to the one with most room
local function most(cands, score)
    local best, bestN, room = nil, 0, -1
    for _, c in ipairs(cands) do
        local n = score(c) or 0
        if n > bestN or (n == bestN and n > 0 and (c.free or 0) > room) then best, bestN, room = c, n, c.free or 0 end
    end
    return best
end

local function nearest(cands, pos)
    local best, bestD = nil, nil
    for _, c in ipairs(cands) do
        local d = pos and BU.dist(pos, c) or 0
        if bestD == nil or d < bestD then best, bestD = c, d end
    end
    return best
end

-- Where an item goes, and why. In order:
--   oneoff    a drop with Ctrl for this very item
--   laundry   dirty or bloody clothing: a Laundry-tagged container, the cart, the washer
--   garbage   stale or rotten perishable food: a Garbage-tagged container or a bin
--   rule      the type's assigned container (the player's word beats every inference below)
--   contains  a container that already holds that very item type
--   freezer   fresh perishable food (not long-life): a freezer, else a fridge
--   tag       a container tagged with the item's category
--   category  a container that already holds that category
--   nearest   the closest container nothing points at (no rule, no tag, not cold, not a bin, not laundry)
-- A freezer or fridge is only ever picked by contains or category for food that
-- wants the cold (BU.wantsCold); a can, a bag of chips or a hammer goes there
-- only by a rule or a tag.
-- Every stage but oneoff only considers containers with room for the item, so a
-- full shelf hands on to the next stage; nothing with room anywhere returns nil.
-- An off-limits container is left out of every stage but oneoff and rule: only
-- what the player sent there by hand goes in.
-- ctx: { rules, tags, oneOffs, containers, use, pos, sourceKey, hidden, offLimits, ruleCounts }
function BU.resolve(item, ctx)
    local one = ctx.oneOffs and item.id ~= nil and (ctx.oneOffs[item.id] or ctx.oneOffs[tostring(item.id)]) or nil
    if one then return one, "oneoff" end
    local rule = ctx.rules and item.fullType and ctx.rules[item.fullType] or nil
    local open, shown, ruleOpen = {}, {}, false
    for _, c in ipairs(ctx.containers or {}) do
        if c.key ~= ctx.sourceKey and not c.pinned and roomFor(c, item, ctx.use) then
            if c.key == rule then ruleOpen = true end
            if not (ctx.offLimits and ctx.offLimits[c.key]) then
                open[#open + 1] = c
                if not (ctx.hidden and ctx.hidden[c.key]) then shown[#shown + 1] = c end
            end
        end
    end
    -- a hidden container is never inferred into by its kind; a tag on it is the
    -- player's own word and still counts
    local hidden = ctx.hidden or {}
    if item.laundry then
        local k = BU.laundryDestination(item, ctx.tags, open, hidden)
        if k then return k, "laundry" end
    end
    local perishable = item.food and item.perishable
    if perishable and (item.rotten or item.stale) then
        local bin = most(open, function(c)
            if BU.hasTag(ctx.tags, c.key, BU.GARBAGE_TAG) then return 2 end
            if isBin(c) and not hidden[c.key] then return 1 end
            return 0
        end)
        if bin then return bin.key, "garbage" end
    end
    -- what the player dragged there by hand wins over every inference below
    -- (2026-10-22: it used to come after contains and freezer, so a rule for
    -- hammers never won while any shelf already held one). Laundry and rubbish
    -- come first still: a rule for shirts is for clean ones
    if ruleOpen then return rule, "rule" end
    local cold = BU.wantsCold(item)
    local matchable = shown
    if not cold then
        matchable = {}
        for _, c in ipairs(shown) do
            if not isCold(c) then matchable[#matchable + 1] = c end
        end
    end
    local holds = most(matchable, function(c) return c.contents and item.fullType and c.contents[item.fullType] or 0 end)
    if holds then return holds.key, "contains" end
    if cold then
        local cold = most(shown, function(c)
            local rank = BU.COLD_KINDS[lowerKind(c)]
            if rank == 1 then return 2 end
            if rank == 2 then return 1 end
            return 0
        end)
        if cold then return cold.key, "freezer" end
    end
    local tagged = BU.tagDestination(item, ctx.tags, open)
    if tagged then return tagged, "tag" end
    local cat = most(matchable, function(c) return c.cats and item.category and c.cats[item.category] or 0 end)
    if cat then return cat.key, "category" end
    local free = {}
    for _, c in ipairs(shown) do
        local pointed = (ctx.ruleCounts and ctx.ruleCounts[c.key] or 0) > 0 or (ctx.tags and ctx.tags[c.key] ~= nil)
        if not pointed and not isCold(c) and not isBin(c) and not isLaundryKind(c) then free[#free + 1] = c end
    end
    local near = nearest(free, ctx.pos)
    if near then return near.key, "nearest" end
    return nil
end

-- the items -----------------------------------------------------------------------------

-- what a run leaves alone: favourites and anything worn or held
function BU.movable(item)
    return not item.favorite and not item.equipped
end

-- Every item of a step through the resolver, bags unpacked: what is inside a
-- bag goes where it belongs first, and a bag stays put while anything inside
-- it is going somewhere this step. Once nothing inside has a home (or it is
-- empty) the bag goes by its own rule, with whatever is left in it. A record
-- marks a bag with `bag`, and the bag it sits in with `parent` (that bag's id).
-- Inner bags are decided before the bags they sit in. Returns the items with a
-- destination (`dest` set; ctx.use counts their weight) and how many have
-- nowhere to go (not counting what rides in a bag that moves).
function BU.route(pool, ctx)
    ctx.use = ctx.use or {}
    local byId = {}
    for _, r in ipairs(pool) do
        if r.id ~= nil then byId[tostring(r.id)] = r end
    end
    local function eachParent(r, fn)
        local p, n = r.parent ~= nil and byId[tostring(r.parent)] or nil, 0
        while p and n < 8 do
            fn(p)
            n = n + 1
            p = p.parent ~= nil and byId[tostring(p.parent)] or nil
        end
    end
    local items, held = {}, {}
    local function place(r)
        r.dest = BU.resolve(r, ctx)
        if not r.dest then return end
        ctx.use[r.dest] = (ctx.use[r.dest] or 0) + (r.weight or 0)
        items[#items + 1] = r
        eachParent(r, function(p) held[p] = true end)
    end
    local bags = {}
    for i, r in ipairs(pool) do
        r.dest = nil
        if BU.movable(r) then
            if r.bag then
                local depth = 0
                eachParent(r, function() depth = depth + 1 end)
                bags[#bags + 1] = { r = r, depth = depth, i = i }
            else
                place(r)
            end
        end
    end
    table.sort(bags, function(a, b)
        if a.depth ~= b.depth then return a.depth > b.depth end
        return a.i < b.i
    end)
    for _, b in ipairs(bags) do
        if not held[b.r] then place(b.r) end
    end
    local nowhere = 0
    for _, r in ipairs(pool) do
        if BU.movable(r) and not r.dest and not held[r] then
            local rides = false
            eachParent(r, function(p) if p.dest then rides = true end end)
            if not rides then nowhere = nowhere + 1 end
        end
    end
    return items, nowhere
end

-- the items grouped by type, each group with its count and weight, sorted by name
function BU.groups(items)
    local byType, list = {}, {}
    for _, item in ipairs(items) do
        if BU.movable(item) then
            local gkey = item.fullType .. (item.laundry and "|laundry" or "")
            local g = byType[gkey]
            if not g then
                g = { fullType = item.fullType, name = item.name, category = item.category, count = 0, weight = 0,
                      items = {}, food = item.food, perishable = item.perishable, longLife = item.longLife,
                      laundry = item.laundry == true }
                byType[gkey] = g
                list[#list + 1] = g
            end
            g.count = g.count + 1
            g.weight = g.weight + (item.weight or 0)
            g.items[#g.items + 1] = item
        end
    end
    table.sort(list, function(a, b)
        if a.name == b.name then
            if a.fullType == b.fullType then return (a.laundry and 1 or 0) < (b.laundry and 1 or 0) end
            return a.fullType < b.fullType
        end
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
-- container of a kind that suits the category. Fridges and freezers only for
-- food that wants the cold (BU.wantsCold). Returns { [fullType] = key }.
function BU.suggest(groups, containers, rules)
    local out = {}
    for _, g in ipairs(groups) do
        local probe = { fullType = g.fullType, category = g.category }
        if not BU.destinationOf(probe, rules, nil) then
            local cold = BU.wantsCold({ perishable = g.perishable, longLife = g.longLife })
            local cands = containers
            if not cold then
                cands = {}
                for _, c in ipairs(containers) do
                    if not isCold(c) then cands[#cands + 1] = c end
                end
            end
            local best, bestN = nil, 0
            for _, c in ipairs(cands) do
                local n = c.contents and c.contents[g.fullType] or 0
                if n > bestN then best, bestN = c, n end
            end
            if not best and cold then
                local room = -1
                for _, c in ipairs(containers) do
                    if isCold(c) and (c.free or 0) > room then best, room = c, c.free or 0 end
                end
            end
            if not best then
                for _, c in ipairs(cands) do
                    local n = c.cats and g.category and c.cats[g.category] or 0
                    if n > bestN then best, bestN = c, n end
                end
            end
            if not best and g.category and BU.KIND_HINTS[g.category] then
                local rank = 99
                for _, c in ipairs(cands) do
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
-- still takes); from: where the character stands; budget: what may still be
-- added to the character's load before it passes the allowed Heavy Load level
-- (BU.loadBudget); bags: the worn bags, { left = room in weight, keep = the
-- share of an item's weight that still counts once inside (1 - reduction),
-- ok = optional function(item) -> may it go in }. Containers are visited
-- nearest first from the character, then from the last stop. Each item goes in
-- the worn bag with the best reduction that has room for it, else in the
-- hands; it is taken while what it costs there fits the budget and its
-- container has room. Nothing goes past the budget: an item that would not
-- fit even with an empty load is left (skipped.tooHeavy). Every destination
-- is tried, so the bags fill even once the hands are full. A taken item's
-- .into is its bag (nil: the hands).
-- Returns { stops = { { key, items } }, weight (the load added), skipped = { noRoom, noContainer, tooHeavy } }.
function BU.trip(items, containers, from, budget, bags)
    local byKey = containerByKey(containers)
    local byDest, order = {}, {}
    local skipped = { noRoom = 0, noContainer = 0, tooHeavy = 0 }
    for _, item in ipairs(items) do
        item.into = nil
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
    local sorted = {}
    for _, b in ipairs(bags or {}) do
        sorted[#sorted + 1] = { bag = b, left = b.left or 0, keep = math.max(0, math.min(1, b.keep or 1)) }
    end
    table.sort(sorted, function(a, b) return a.keep < b.keep end)
    local full = math.max(0, budget or 0)
    -- the cheapest place it could ride on an empty load: if even that is over, it never fits
    local function bestCost(item, w)
        for _, b in ipairs(sorted) do
            if (b.bag.left or 0) >= w and (not b.bag.ok or b.bag.ok(item)) then return w * b.keep end
        end
        return w
    end
    local function place(item, w)
        for _, b in ipairs(sorted) do
            if b.left >= w and (not b.bag.ok or b.bag.ok(item)) then return b, w * b.keep end
        end
        return nil, w
    end
    local stops, weight, left = {}, 0, full
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
            if room ~= nil and w > room then
                skipped.noRoom = skipped.noRoom + 1
            elseif bestCost(item, w) > full + 1e-6 then
                skipped.tooHeavy = skipped.tooHeavy + 1
            else
                local b, cost = place(item, w)
                if cost <= left + 1e-6 then
                    take[#take + 1] = item
                    left = left - cost
                    weight = weight + cost
                    if b then
                        b.left = b.left - w
                        item.into = b.bag
                    end
                    if room ~= nil then room = room - w end
                end
            end
        end
        if #take > 0 then
            stops[#stops + 1] = { key = key, items = take }
            here = c
        end
    end
    return { stops = stops, weight = weight, skipped = skipped }
end

-- what may still be added to a load: up to `level` of the Heavy Load moodle
-- (the game: level 1 over max weight, 2 over 1.25x, 3 over 1.5x, 4 over 1.75x),
-- so at level 2 the load stops at 1.5x the max weight
function BU.loadBudget(maxWeight, carried, level)
    level = math.max(0, math.min(4, math.floor(tonumber(level) or BU.MAX_LOAD_LEVEL)))
    local cap = (maxWeight or 0) * (1 + BU.LOAD_STEP * level)
    return math.max(0, cap - (carried or 0))
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

-- zones ---------------------------------------------------------------------------------------

-- The base zones the player drew (store.zones), as areas: { name, rects =
-- { { x1, y1, x2, y2, z } } }, the corners inclusive. A rect counts on its own
-- floor and `floors` above and below (a zone round the ground floor takes in
-- the upstairs).

BU.ZONE_MAX = 60        -- the longest side a piece of zone may have, in tiles

-- a drawn piece may be saved: 1 to ZONE_MAX tiles each way
function BU.zoneSizeOk(w, h)
    return w >= 1 and h >= 1 and w <= BU.ZONE_MAX and h <= BU.ZONE_MAX
end

-- a new piece from two corners in any order; returns it
function BU.addZone(store, name, ax, ay, bx, by, z)
    local zone = { name = name, x1 = math.min(ax, bx), y1 = math.min(ay, by), x2 = math.max(ax, bx), y2 = math.max(ay, by), z = z or 0 }
    table.insert(store.zones, zone)
    return zone
end

function BU.removeZone(store, zone)
    for i = #store.zones, 1, -1 do
        if store.zones[i] == zone then table.remove(store.zones, i) end
    end
    BU.dropStaleStock(store)
end

-- a piece renamed: it joins the zone of that name, or starts its own
function BU.renameZone(store, zone, name)
    if not name or name == "" then return end
    zone.name = name
    BU.dropStaleStock(store)
end

-- a piece's key in store.stock: its name and corners, so a renamed or moved piece counts afresh
function BU.pieceKey(zone)
    return string.format("%s|%d,%d,%d,%d,%d", zone.name, zone.x1, zone.y1, zone.x2, zone.y2, zone.z)
end

-- counts kept for a piece that is gone (removed, renamed) are dropped
function BU.dropStaleStock(store)
    local keys = {}
    for _, z in ipairs(store.zones) do keys[BU.pieceKey(z)] = true end
    local gone = {}
    for key in pairs(store.stock) do
        if not keys[key] then gone[#gone + 1] = key end
    end
    for _, key in ipairs(gone) do store.stock[key] = nil end
end

-- the name offered for a new piece: the last one drawn (to add to it), else "Base"
function BU.nextZoneName(store, base)
    local last = store.zones[#store.zones]
    return last and last.name or base or "Base"
end

-- the drawn pieces as areas, one per name, in the order first drawn
function BU.zoneAreas(zones)
    local out, byName = {}, {}
    for _, z in ipairs(zones or {}) do
        local area = byName[z.name]
        if not area then
            area = { name = z.name, rects = {} }
            byName[z.name] = area
            out[#out + 1] = area
        end
        area.rects[#area.rects + 1] = { x1 = z.x1, y1 = z.y1, x2 = z.x2, y2 = z.y2, z = z.z }
    end
    return out
end

-- how far (x, y) is from the nearest edge of an area, 0 inside it
function BU.areaDistance(area, x, y)
    local best
    for _, r in ipairs(area.rects) do
        local dx = math.max(r.x1 - x, 0, x - r.x2)
        local dy = math.max(r.y1 - y, 0, y - r.y2)
        local d = math.sqrt(dx * dx + dy * dy)
        if not best or d < best then best = d end
    end
    return best or math.huge
end

-- which area a square is in: the index, nil outside them all. A zone drawn on
-- the square's own floor beats one drawn on another floor; then the first.
function BU.areaAt(areas, x, y, z, floors)
    local near
    for i, area in ipairs(areas) do
        for _, r in ipairs(area.rects) do
            if x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 then
                if r.z == z then return i end
                if not near and math.abs(r.z - z) <= (floors or 0) then near = i end
            end
        end
    end
    return near
end

-- the areas within reach of (x, y), nearest first, each with only its pieces
-- in reach (two bases both called "Base" stay apart)
function BU.nearAreas(areas, x, y, reach)
    local out = {}
    for _, area in ipairs(areas) do
        local near = { name = area.name, rects = {} }
        for _, r in ipairs(area.rects) do
            if BU.areaDistance({ rects = { r } }, x, y) <= reach then near.rects[#near.rects + 1] = r end
        end
        if #near.rects > 0 then
            near.distance = BU.areaDistance(near, x, y)
            out[#out + 1] = near
        end
    end
    table.sort(out, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

-- stock --------------------------------------------------------------------------------------

-- What a zone holds, from item records each carrying the container they sit in
-- (key and name): one entry per container and type, with how many.
function BU.stockOf(records)
    local byKey, items = {}, {}
    for _, r in ipairs(records) do
        local k = (r.containerKey or "?") .. "|" .. r.fullType
        local e = byKey[k]
        if not e then
            e = { t = r.fullType, n = r.name or r.fullType, c = r.category or "", k = r.containerKey, cn = r.containerName or "", q = 0 }
            byKey[k] = e
            items[#items + 1] = e
        end
        e.q = e.q + 1
    end
    return items
end

-- how many of a type the base holds, by every zone's last count: the total
-- and { { zone, q } } most first
function BU.stockCount(stock, fullType)
    local total, sums = 0, {}
    for _, s in pairs(stock or {}) do
        local q = 0
        for _, e in ipairs(s.items or {}) do
            if e.t == fullType then q = q + e.q end
        end
        if q > 0 and s.zone then
            total = total + q
            sums[s.zone] = (sums[s.zone] or 0) + q
        end
    end
    local byZone = {}
    for zone, q in pairs(sums) do byZone[#byZone + 1] = { zone = zone, q = q } end
    table.sort(byZone, function(a, b)
        if a.q ~= b.q then return a.q > b.q end
        return a.zone < b.zone
    end)
    return total, byZone
end

-- every piece's entries in one list for the inventory window, each with its
-- zone and how old the count is (hours; nil for a piece just looked at, a key
-- in `fresh`). The same type in the same container is one row.
function BU.stockRows(stock, now, fresh)
    local out, byKey = {}, {}
    for pieceKey, s in pairs(stock or {}) do
        local age = nil
        if not (fresh and fresh[pieceKey]) and now and s.at then age = math.max(0, now - s.at) end
        for _, e in ipairs(s.items or {}) do
            local k = (s.zone or "?") .. "|" .. tostring(e.k) .. "|" .. e.t
            local row = byKey[k]
            if row then
                row.count = row.count + e.q
                if age and (not row.age or age > row.age) then row.age = age end
            else
                row = { fullType = e.t, name = e.n, category = e.c, key = e.k, container = e.cn, count = e.q, zone = s.zone or "?", age = age }
                byKey[k] = row
                out[#out + 1] = row
            end
        end
    end
    return out
end

-- the inventory window's order: by a field, then name, then zone, then container
function BU.sortStock(rows, field, desc)
    field = field or "name"
    table.sort(rows, function(a, b)
        local fa, fb = a[field], b[field]
        if fa ~= fb then
            if desc then return fa > fb end
            return fa < fb
        end
        if a.name ~= b.name then return a.name < b.name end
        if a.zone ~= b.zone then return a.zone < b.zone end
        return (a.container or "") < (b.container or "")
    end)
    return rows
end

-- a row matches the search: in one field, or in any of them
function BU.stockMatch(row, text, field)
    if not text or text == "" then return true end
    text = string.lower(text)
    local fields = field and field ~= "all" and { field } or { "name", "category", "zone", "container" }
    for _, f in ipairs(fields) do
        local v = row[f]
        if v and string.find(string.lower(tostring(v)), text, 1, true) then return true end
    end
    return false
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
