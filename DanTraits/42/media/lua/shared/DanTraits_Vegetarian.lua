-- Dan's Traits: Vegetarian.
require "DanTraits"

local hasTrait = DanTraits_HasTrait

-- Vegetarian ------------------------------------------------------------------
-- Meat, poultry, fish, seafood, insects and pet food are refused outright:
-- the Eat option is greyed out with a reason, and the eat action itself will
-- not start or finish on them (so hotbar and other mods' shortcuts are
-- covered too). Eggs and dairy are fine. Detection is the item's FoodType
-- first, then its name, then the ingredients of an evolved dish (a stew with
-- a steak in it is not vegetarian).
local MEAT_FOOD_TYPES = {
    Meat = true, Beef = true, Poultry = true, Fish = true, Seafood = true, Sausage = true, Bacon = true,
    Game = true, Venison = true, Insect = true, Roe = true, DogFood = true, CatFood = true, Stock = true,
}
local MEAT_WORDS = {
    "meat", "beef", "steak", "bacon", "ham", "pork", "chicken", "turkey", "sausage", "salami", "pepperoni", "bologna",
    "hotdog", "burger", "jerky", "fish", "salmon", "trout", "tuna", "sardine", "shrimp", "crab", "lobster", "oyster",
    "squid", "venison", "rabbit", "squirrel", "frog", "mouse", "deadrat", "ratking", "bird", "crappie", "bass", "perch",
    "pike", "dogfood", "catfood", "liver", "kidney", "ribs", "lamb", "mutton", "duck", "goose",
    "worm", "cricket", "grasshopper", "cockroach", "maggot", "termite", "centipede", "millipede", "slug", "snail",
    "cicada", "beetle", "larva",
}
local MEAT_SAFE_PART = { "graham", "kidneybean", "gooseberr", "crabapple", "grated", "eggplant" }

local function meatName(name)
    if not name or name == "" then return false end
    for _, part in ipairs(MEAT_SAFE_PART) do
        if name:find(part, 1, true) then return false end
    end
    for _, word in ipairs(MEAT_WORDS) do
        if name:find(word, 1, true) then return true end
    end
    return false
end

function DanTraits_IsMeat(item)
    if not item then return false end
    local foodType
    pcall(function() foodType = item:getFoodType() end)
    if foodType ~= nil and MEAT_FOOD_TYPES[tostring(foodType)] then return true end
    local name
    pcall(function() name = string.lower(tostring(item:getType())) end)
    if meatName(name) then return true end
    -- evolved dish: look at what went into it
    local extras
    pcall(function() if item:haveExtraItems() then extras = item:getExtraItems() end end)
    if extras then
        for i = 0, extras:size() - 1 do
            local full = string.lower(tostring(extras:get(i)))
            local short = full:match("%.(.*)$") or full
            if meatName(short) then return true end
        end
    end
    return false
end

-- true when this character will not eat this item
function DanTraits_RefusesFood(player, item)
    return hasTrait(player, "vegetarian") and DanTraits_IsMeat(item)
end
