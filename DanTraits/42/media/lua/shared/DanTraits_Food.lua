-- Project Zomboid Vitality Project: the one food classifier.
--
-- The game has no grain, meat, junk or caffeine tag on an item, so the traits
-- that care what was eaten (Vitality's diet grade, Gluten Intolerance,
-- Diabetes, Vegetarian, Anaemic, Caffeine Dependent) each used to carry a name
-- list of their own, with the same words in two or three of them ("cookie",
-- "cake", "burger", "chocolate") and a different safe-list in each. This file
-- is the one list. It requires nothing and is loaded by DanTraits.lua right
-- after DanTraits_Util, so a trait file that requires "DanTraits" reads
-- `local foodTags = DanTraits_FoodTags` at the top and asks for the tag it needs.
--
--   DanTraits_FoodTags(item)  a table of tags for the item (a Food; anything
--                             that fails to answer counts as plain):
--     junk        packaged snacks, candy, soda, by name (false for the safe names)
--     junkSafe    the name is on the junk safe-list, so not junk even if packaged
--     wheat       wheat by name, or a wheat ingredient in an evolved dish
--     fastCarb    sugar that hits fast (diabetes)
--     meat        flesh by food type, by name, or a meat ingredient in a dish
--     iron        0..1, how much of a full meat portion of iron it carries (1
--                 for meat, fish, game and insects by type or name, else 0)
--     egg         an egg           greens   vegetables, herbs, beans
--     caffeine    caffeine in one whole item (0 for none); fluids and pills are
--                 not items here: Caffeine keeps its per-litre and pill tables
--     canned      "canned" or "dried" in the name
--     rotten burnt packaged fresh cooked   the item's own state, read when asked
--     ingredients how many things went into an evolved dish
--
-- The name and food-type tags depend only on the item's type, so they are
-- worked out once per getFullType() and remembered; the tags that vary per
-- instance (state, dish contents) are read from the item the first time a
-- consumer asks for them, so a consumer that wants one tag makes exactly the
-- game calls it always did. An item that has no full type (a test double) is
-- classified each time, not remembered. Every game call is inside pcall.
--
-- The table below is the UNION of the six old lists. Where the same word means
-- different things to different traits each tag is decided on its own: a word
-- carries only the tags it earns, and a safe word cancels one tag, never the
-- others (rice cake is not wheat but is still junk sugar). The conflicts:
--   burger        wheat AND meat: the bun and the patty, so both traits get it
--   jerky         junk AND meat: a packaged snack that is also flesh
--   pie           wheat and fast carb, not junk (a slice of fruit pie is food)
--   cereal        wheat and fast carb, not junk
--   beer          wheat only, not junk and not a fast carb
--   chocolate     junk, fast carb; its caffeine is a PREFIX rule (a type that
--                 starts with "chocolate"), as it always was, so a chocolate
--                 cake or ice cream cone adds sugar but no caffeine
--   crappie       meat (a fish), and wheat-safe because it contains "pie"
--   graham        meat-safe because it contains "ham"; graham crackers are
--                 still wheat by "cracker"
--   eggplant      not an egg (Anaemic used to count it as one: "egg" is inside
--                 the word) and not meat
--   rice          not wheat; ricecake is still a cake for junk and sugar
--   oatmeal, oatsraw, granolabar   not wheat, as whole names only
--   chips         not wheat (crisps, corn chips) but junk; chipsbowl is not junk
-- Food types come from a second small table (FOOD_TYPES, whole lowercase
-- name). Dish ingredients (an evolved dish lists its parts as "Base.Steak")
-- contribute meat and wheat only: junk, sugar and iron stay the dish's own.

local FOOD_WORDS = {
    -- candy, snacks and soda: junk, and mostly fast sugar
    candy = { junk = true, fastCarb = true }, lollipop = { junk = true, fastCarb = true },
    marshmallow = { junk = true, fastCarb = true }, caramel = { junk = true, fastCarb = true },
    toffee = { junk = true, fastCarb = true }, fudge = { junk = true, fastCarb = true },
    sugar = { junk = true, fastCarb = true }, chocolate = { junk = true, fastCarb = true },
    soda = { junk = true, fastCarb = true }, cola = { junk = true, fastCarb = true },
    icecream = { junk = true, fastCarb = true },
    chips = { junk = true }, crisps = { junk = true }, pop = { junk = true }, gum = { junk = true },
    doughnut = { junk = true }, tvdinner = { junk = true }, twinkie = { junk = true }, hostess = { junk = true },
    poptart = { junk = true }, candycane = { junk = true }, gummy = { junk = true },
    jerky = { junk = true, meat = true },
    -- baked goods: wheat, and the sweet ones fast sugar (cookies, cake and donuts junk too)
    cookie = { junk = true, wheat = true, fastCarb = true }, cake = { junk = true, wheat = true, fastCarb = true },
    donut = { junk = true, wheat = true, fastCarb = true }, cupcake = { junk = true, wheat = true, fastCarb = true },
    muffin = { wheat = true, fastCarb = true }, pie = { wheat = true, fastCarb = true },
    gingerbread = { wheat = true, fastCarb = true }, pancake = { wheat = true, fastCarb = true },
    waffle = { wheat = true, fastCarb = true }, cereal = { wheat = true, fastCarb = true },
    -- wheat: bread, pasta, dough
    bread = { wheat = true }, bagel = { wheat = true }, baguette = { wheat = true }, croissant = { wheat = true },
    pasta = { wheat = true }, macaroni = { wheat = true }, spaghetti = { wheat = true }, lasagn = { wheat = true },
    ramen = { wheat = true }, noodle = { wheat = true }, cracker = { wheat = true }, dough = { wheat = true },
    sandwich = { wheat = true }, pizza = { wheat = true }, beer = { wheat = true }, biscuit = { wheat = true },
    pretzel = { wheat = true }, flour = { wheat = true }, toast = { wheat = true }, buns = { wheat = true },
    steambun = { wheat = true }, pastry = { wheat = true }, tortilla = { wheat = true }, burrito = { wheat = true },
    dumpling = { wheat = true },
    burger = { wheat = true, meat = true },
    -- sugar that hits fast
    honey = { fastCarb = true }, jam = { fastCarb = true }, marmalade = { fastCarb = true },
    syrup = { fastCarb = true }, cone = { fastCarb = true }, juice = { fastCarb = true },
    apple = { fastCarb = true }, banana = { fastCarb = true }, orange = { fastCarb = true },
    grape = { fastCarb = true }, berr = { fastCarb = true }, cherr = { fastCarb = true },
    peach = { fastCarb = true }, pear = { fastCarb = true }, melon = { fastCarb = true },
    mango = { fastCarb = true }, pineapple = { fastCarb = true }, lemon = { fastCarb = true },
    lime = { fastCarb = true }, raisin = { fastCarb = true }, fruit = { fastCarb = true },
    milk = { fastCarb = true }, yogurt = { fastCarb = true }, pudding = { fastCarb = true },
    custard = { fastCarb = true }, jelly = { fastCarb = true }, granola = { fastCarb = true },
    -- meat: the ones that carry iron too, then the rest of the flesh, fish, insects and pet food
    meat = { meat = true, iron = 1 }, beef = { meat = true, iron = 1 }, pork = { meat = true, iron = 1 },
    chicken = { meat = true, iron = 1 }, fish = { meat = true, iron = 1 }, venison = { meat = true, iron = 1 },
    rabbit = { meat = true, iron = 1 },
    steak = { meat = true }, bacon = { meat = true }, ham = { meat = true }, turkey = { meat = true },
    sausage = { meat = true }, salami = { meat = true }, pepperoni = { meat = true }, bologna = { meat = true },
    hotdog = { meat = true }, salmon = { meat = true }, trout = { meat = true }, tuna = { meat = true },
    sardine = { meat = true }, shrimp = { meat = true }, crab = { meat = true }, lobster = { meat = true },
    oyster = { meat = true }, squid = { meat = true }, squirrel = { meat = true }, frog = { meat = true },
    mouse = { meat = true }, deadrat = { meat = true }, ratking = { meat = true }, bird = { meat = true },
    crappie = { meat = true }, bass = { meat = true }, perch = { meat = true }, pike = { meat = true },
    dogfood = { meat = true }, catfood = { meat = true }, liver = { meat = true }, kidney = { meat = true },
    ribs = { meat = true }, lamb = { meat = true }, mutton = { meat = true }, duck = { meat = true },
    goose = { meat = true }, worm = { meat = true }, cricket = { meat = true }, grasshopper = { meat = true },
    cockroach = { meat = true }, maggot = { meat = true }, termite = { meat = true }, centipede = { meat = true },
    millipede = { meat = true }, slug = { meat = true }, snail = { meat = true }, cicada = { meat = true },
    beetle = { meat = true }, larva = { meat = true },
    -- iron only (Anaemic's own words), eggs and greens
    game = { iron = 1 }, poultry = { iron = 1 }, seafood = { iron = 1 }, insect = { iron = 1 },
    egg = { egg = true },
    vegetables = { greens = true }, greens = { greens = true }, herb = { greens = true },
    beans = { greens = true }, leafy = { greens = true },
}

-- a word in the name that cancels one tag (never the others)
local FOOD_SAFE = {
    sugarcane = { junk = true }, chipsbowl = { junk = true },
    crappie = { wheat = true }, poppies = { wheat = true }, piece = { wheat = true }, chips = { wheat = true },
    cornflour = { wheat = true }, rice = { wheat = true },
    graham = { meat = true }, kidneybean = { meat = true }, gooseberr = { meat = true }, crabapple = { meat = true },
    grated = { meat = true }, eggplant = { meat = true, egg = true },
}

-- whole-name rules: a number sets a tag, false cancels it
local FOOD_EXACT = {
    oatmeal = { wheat = false }, oatsraw = { wheat = false }, granolabar = { wheat = false },
    coffee2 = { caffeine = 600 }, chocolatecoveredcoffeebeans = { caffeine = 300 },
    cocoapowder = { caffeine = 30 }, teabag2 = { caffeine = 40 },
}

-- the type starts with this (an exact rule for the same name wins)
local FOOD_PREFIX = {
    chocolate = { caffeine = 15 },
}

-- the game's food type, whole lowercase name
local FOOD_TYPES = {
    meat = { meat = true, iron = 1 }, beef = { meat = true, iron = 1 }, poultry = { meat = true, iron = 1 },
    fish = { meat = true, iron = 1 }, seafood = { meat = true, iron = 1 }, game = { meat = true, iron = 1 },
    venison = { meat = true, iron = 1 }, insect = { meat = true, iron = 1 },
    pork = { iron = 1 }, rabbit = { iron = 1 }, chicken = { iron = 1 },
    sausage = { meat = true }, bacon = { meat = true }, roe = { meat = true }, dogfood = { meat = true },
    catfood = { meat = true }, stock = { meat = true },
    egg = { egg = true },
    vegetables = { greens = true }, greens = { greens = true }, herb = { greens = true },
    beans = { greens = true }, leafy = { greens = true },
}

local NONE = {}
local typeMemo = {}   -- getFullType() -> { tags = the name tags, ft = the food-type tags once asked }
local nameMemo = {}   -- lowercase name -> the name tags (dish ingredients)

-- the tags a name earns
local function scanName(name)
    local hit, safe = {}, {}
    for word, tags in pairs(FOOD_WORDS) do
        if string.find(name, word, 1, true) then
            for tag, v in pairs(tags) do hit[tag] = v end
        end
    end
    for word, tags in pairs(FOOD_SAFE) do
        if string.find(name, word, 1, true) then
            for tag in pairs(tags) do safe[tag] = true end
        end
    end
    for prefix, tags in pairs(FOOD_PREFIX) do
        if string.find(name, prefix, 1, true) == 1 then
            for tag, v in pairs(tags) do hit[tag] = v end
        end
    end
    local exact = FOOD_EXACT[name]
    if exact then
        for tag, v in pairs(exact) do
            if v == false then safe[tag] = true else hit[tag] = v end
        end
    end
    return {
        junk = (hit.junk and not safe.junk) == true, junkSafe = safe.junk == true,
        wheat = (hit.wheat and not safe.wheat) == true, fastCarb = hit.fastCarb == true,
        meat = (hit.meat and not safe.meat) == true, egg = (hit.egg and not safe.egg) == true,
        greens = hit.greens == true, iron = hit.iron or 0, caffeine = hit.caffeine or 0,
        canned = string.find(name, "canned", 1, true) ~= nil or string.find(name, "dried", 1, true) ~= nil,
    }
end

local function tagsForName(name)
    local t = nameMemo[name]
    if not t then t = scanName(name); nameMemo[name] = t end
    return t
end

local function flag(item, method)
    local ok, res = pcall(function() return item[method](item) end)
    return ok and res == true
end

-- does any ingredient of an evolved dish have this name tag ("Base.Steak" -> "steak")
local function ingredientHas(item, tag)
    local extras
    pcall(function() if item:haveExtraItems() then extras = item:getExtraItems() end end)
    if not extras then return false end
    local found = false
    pcall(function()
        for i = 0, extras:size() - 1 do
            local full = string.lower(tostring(extras:get(i)))
            local short = full:match("%.(.*)$") or full
            if tagsForName(short)[tag] then found = true end
        end
    end)
    return found
end

-- the food-type tags of the item, asked of the game once per remembered type
local function typeTags(item, entry)
    if not entry.ft then
        local ft
        pcall(function() ft = item:getFoodType() end)
        entry.ft = (ft ~= nil and FOOD_TYPES[string.lower(tostring(ft))]) or NONE
    end
    return entry.ft
end

-- the tags read on first use; (item, entry) -> value, never nil
local LAZY = {
    wheat = function(item, entry) return entry.tags.wheat or ingredientHas(item, "wheat") end,
    meat = function(item, entry) return entry.tags.meat or typeTags(item, entry).meat == true or ingredientHas(item, "meat") end,
    iron = function(item, entry)
        if entry.tags.iron > 0 then return entry.tags.iron end
        return typeTags(item, entry).iron or 0
    end,
    egg = function(item, entry) return entry.tags.egg or typeTags(item, entry).egg == true end,
    greens = function(item, entry) return entry.tags.greens or typeTags(item, entry).greens == true end,
    rotten = function(item) return flag(item, "isRotten") end,
    burnt = function(item) return flag(item, "isBurnt") end,
    packaged = function(item) return flag(item, "isPackaged") end,
    fresh = function(item) return flag(item, "isFresh") end,
    cooked = function(item) return flag(item, "isCooked") end,
    ingredients = function(item)
        local n = 0
        pcall(function() if item:haveExtraItems() then n = item:getExtraItems():size() end end)
        return n
    end,
}

function DanTraits_FoodTags(item)
    local key
    pcall(function() key = item:getFullType() end)
    if key ~= nil then key = tostring(key) end
    local entry = key and typeMemo[key]
    if not entry then
        local name = ""
        pcall(function() name = string.lower(tostring(item:getType() or "")) end)
        entry = { tags = scanName(name) }
        if key then typeMemo[key] = entry end
    end
    local st = entry.tags
    return setmetatable({
        junk = st.junk, junkSafe = st.junkSafe, fastCarb = st.fastCarb, caffeine = st.caffeine, canned = st.canned,
    }, { __index = function(t, k)
        local get = LAZY[k]
        if not get then return nil end
        local v = get(item, entry)
        rawset(t, k, v)
        return v
    end })
end
