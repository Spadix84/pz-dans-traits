-- The Slow Cooker window's recipes: Kentucky home cooking, 1993.
--
-- Every ingredient here is one the game already allows in a stew, because the
-- dish is made by the game's own evolved recipe (CrockStew in the item script).
-- That keeps nutrition, partial use of big items and the ingredient list exactly
-- as the game does them, and lets other mods (Vitality) read what went in.
--
-- A recipe is groups of ingredients. A group with need = 0 is optional extras;
-- need = 2 asks for two different items from the group (burgoo's two meats).
-- A named dish gets its name and a mood bonus over plain crock stew.
require "SlowCooker_Core"

local BEANS = { "Base.DriedWhiteBeans", "Base.DriedKidneyBeans", "Base.DriedBlackBeans", "Base.Blackbeans",
    "Base.OpenBeans", "Base.BeanBowl" }
local POTATO = { "Base.Potato", "Base.CannedPotatoOpen", "Base.CannedPotato_Open" }
local CARROT = { "Base.Carrots", "Base.CannedCarrotsOpen", "Base.CannedCarrots_Open" }
local CORN = { "Base.Corn", "Base.CornFrozen", "Base.CannedCornOpen" }
local TOMATO = { "Base.Tomato", "Base.CannedTomatoOpen", "Base.CannedTomato_Open", "Base.TomatoPaste" }
local SEASON = { "Base.Salt", "Base.Pepper" }

local function join(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, v in ipairs(list) do table.insert(out, v) end
    end
    return out
end

local function group(label, need, items) return { label = label, need = need, items = items } end
local function extras(items) return group("IGUI_SlowCooker_Extras", 0, items) end

SlowCooker.FREEFORM = "crockstew"
SlowCooker.MAX_INGREDIENTS = 12   -- the evolved recipe's MaxItems
SlowCooker.BOOKLET_RECIPE = "SlowCookerFavorites"   -- learned from the booklet: every recipe
SlowCooker.DISH_UNHAPPY = -20     -- a named dish's mood bonus over plain stew, for the whole crock
SlowCooker.DISH_BOREDOM = -20

SlowCooker.RECIPES = {
    { id = "soupbeans", level = 0, name = "IGUI_SlowCooker_Dish_soupbeans", groups = {
        group("IGUI_SlowCooker_Beans", 1, BEANS),
        group("IGUI_SlowCooker_Ham", 1, { "Base.HamSlice", "Base.Bacon", "Base.BaconRashers", "Base.BaconBits" }),
        extras(join({ "Base.Onion", "Base.Garlic", "Base.Cornbread" }, SEASON)),
    } },
    { id = "chili", level = 0, name = "IGUI_SlowCooker_Dish_chili", groups = {
        group("IGUI_SlowCooker_Meat", 1, { "Base.MincedMeat", "Base.Beef", "Base.Steak", "Base.MeatPatty", "Base.Venison" }),
        group("IGUI_SlowCooker_Beans", 1, { "Base.DriedKidneyBeans", "Base.OpenBeans", "Base.Blackbeans",
            "Base.DriedBlackBeans", "Base.CannedChiliOpen" }),
        group("IGUI_SlowCooker_Tomato", 1, TOMATO),
        extras(join({ "Base.Onion", "Base.BellPepper", "Base.PepperJalapeno", "Base.PepperJalapenoDried",
            "Base.Garlic", "Base.Cheese", "Base.Crackers" }, SEASON)),
    } },
    { id = "beefstew", level = 2, name = "IGUI_SlowCooker_Dish_beefstew", groups = {
        group("IGUI_SlowCooker_Beef", 1, { "Base.Beef", "Base.Steak", "Base.Venison", "Base.CannedCornedBeefOpen" }),
        group("IGUI_SlowCooker_Potato", 1, POTATO),
        group("IGUI_SlowCooker_Carrot", 1, CARROT),
        extras(join({ "Base.Onion", "Base.Peas", "Base.Greenpeas", "Base.CannedPeasOpen", "Base.BouillonCube",
            "Base.Gravy", "Base.Flour2", "Base.Thyme", "Base.ThymeDried" }, SEASON)),
    } },
    { id = "cornchowder", level = 2, name = "IGUI_SlowCooker_Dish_cornchowder", groups = {
        group("IGUI_SlowCooker_Corn", 1, CORN),
        group("IGUI_SlowCooker_Potato", 1, POTATO),
        extras(join({ "Base.Bacon", "Base.BaconBits", "Base.BaconRashers", "Base.Onion", "Base.Butter",
            "Base.Cheese", "Base.Crackers" }, SEASON)),
    } },
    { id = "potroast", level = 4, name = "IGUI_SlowCooker_Dish_potroast", groups = {
        group("IGUI_SlowCooker_Beef", 1, { "Base.Beef", "Base.Steak", "Base.Venison" }),
        group("IGUI_SlowCooker_Potato", 1, POTATO),
        group("IGUI_SlowCooker_Carrot", 1, CARROT),
        group("IGUI_SlowCooker_Onion", 1, { "Base.Onion", "Base.GreenOnions", "Base.PowderedOnion" }),
        extras(join({ "Base.Garlic", "Base.Rosemary", "Base.RosemaryDried", "Base.Thyme", "Base.ThymeDried",
            "Base.Gravy", "Base.BouillonCube" }, SEASON)),
    } },
    { id = "sloppyjoes", level = 4, name = "IGUI_SlowCooker_Dish_sloppyjoes", groups = {
        group("IGUI_SlowCooker_Mince", 1, { "Base.MincedMeat", "Base.MeatPatty" }),
        group("IGUI_SlowCooker_Tomato", 1, { "Base.TomatoPaste", "Base.CannedTomatoOpen", "Base.CannedTomato_Open",
            "Base.Tomato", "Base.CannedBologneseOpen" }),
        extras(join({ "Base.Onion", "Base.BellPepper", "Base.BunsHamburger_single" }, SEASON)),
    } },
    { id = "chickendumplings", level = 6, name = "IGUI_SlowCooker_Dish_chickendumplings", groups = {
        group("IGUI_SlowCooker_Chicken", 1, { "Base.Chicken", "Base.ChickenFillet", "Base.ChickenWings",
            "Base.TurkeyFillet", "Base.TurkeyLegs" }),
        group("IGUI_SlowCooker_Dumplings", 1, { "Base.Flour2", "Base.Biscuit" }),
        extras(join({ "Base.Carrots", "Base.Onion", "Base.Butter", "Base.Peas", "Base.Greenpeas",
            "Base.BouillonCube", "Base.Thyme", "Base.Parsley" }, SEASON)),
    } },
    { id = "pulledpork", level = 6, name = "IGUI_SlowCooker_Dish_pulledpork", groups = {
        group("IGUI_SlowCooker_Pork", 1, { "Base.Pork", "Base.PorkChop" }),
        extras(join({ "Base.Onion", "Base.Garlic", "Base.TomatoPaste", "Base.Lard", "Base.PepperJalapeno",
            "Base.BunsHamburger_single" }, SEASON)),
    } },
    { id = "burgoo", level = 8, name = "IGUI_SlowCooker_Dish_burgoo", groups = {
        group("IGUI_SlowCooker_TwoMeats", 2, { "Base.Beef", "Base.Pork", "Base.PorkChop", "Base.Chicken",
            "Base.ChickenFillet", "Base.MuttonChop", "Base.Venison", "Base.Rabbitmeat", "Base.Smallanimalmeat",
            "Base.Smallbirdmeat", "Base.TurkeyFillet" }),
        group("IGUI_SlowCooker_Corn", 1, CORN),
        group("IGUI_SlowCooker_Potato", 1, POTATO),
        extras(join({ "Base.Tomato", "Base.CannedTomatoOpen", "Base.Cabbage", "Base.Carrots", "Base.Onion",
            "Base.Peas", "Base.BellPepper" }, SEASON)),
    } },
}

-- A plain search: other mods add and remove recipes (SlowCooker_API.lua).
function SlowCooker.recipeById(id)
    for _, r in ipairs(SlowCooker.RECIPES) do
        if r.id == id then return r end
    end
    return nil
end

local function cookingLevel(player)
    local level = 0
    pcall(function() level = player:getPerkLevel(Perks.Cooking) end)
    return level
end

local function learned(player, name)
    local known = false
    pcall(function() known = player:isRecipeKnown(name) end)
    return known == true
end

function SlowCooker.hasBooklet(player) return learned(player, SlowCooker.BOOKLET_RECIPE) end

-- The recipe learned from this dish's card (SlowCookerCard_<id>).
function SlowCooker.cardRecipe(recipe) return "SlowCooker_" .. recipe.id end
function SlowCooker.hasCard(player, recipe) return learned(player, SlowCooker.cardRecipe(recipe)) end

-- Known by Cooking level, the booklet, or the dish's own recipe card.
function SlowCooker.knows(player, recipe)
    return cookingLevel(player) >= recipe.level or SlowCooker.hasBooklet(player)
        or SlowCooker.hasCard(player, recipe)
end

-- Recipes that unlock at exactly this Cooking level (for the level-up notice).
function SlowCooker.unlockedAt(level)
    local out = {}
    for _, r in ipairs(SlowCooker.RECIPES) do
        if r.level == level and level > 0 then table.insert(out, r) end
    end
    return out
end

-- Does this choice of items (full types) make the recipe? Returns ok and, if not,
-- the label of the first group that's short.
function SlowCooker.check(recipe, chosen)
    for _, g in ipairs(recipe.groups) do
        if g.need > 0 then
            local types = {}
            local count = 0
            for _, t in ipairs(chosen) do
                for _, want in ipairs(g.items) do
                    if t == want and not types[t] then
                        types[t] = true
                        count = count + 1
                    end
                end
            end
            if count < g.need then return false, g.label end
        end
    end
    return true
end

-- Which group an item belongs to in this recipe (nil: not part of it).
function SlowCooker.groupOf(recipe, fullType)
    for _, g in ipairs(recipe.groups) do
        for _, want in ipairs(g.items) do
            if want == fullType then return g end
        end
    end
    return nil
end

-- Turn a crock of stew into the named dish.
function SlowCooker.nameDish(dish, recipe)
    dish:setName(getText(recipe.name))
    dish:setCustomName(true)
    local md = dish:getModData()
    md.slowCookerDish = recipe.id
    md.slowCookerHome = true
    dish:setUnhappyChange(dish:getUnhappyChangeUnmodified() + (recipe.unhappy or SlowCooker.DISH_UNHAPPY))
    dish:setBoredomChange(dish:getBoredomChangeUnmodified() + (recipe.boredom or SlowCooker.DISH_BOREDOM))
end

function SlowCooker.evolvedRecipe()
    local sm = getScriptManager()
    for _, name in ipairs({ "CrockStew", "Base.CrockStew" }) do
        local ok, r = pcall(function() return sm:getEvolvedRecipe(name) end)
        if ok and r then return r end
    end
    local all = sm:getAllEvolvedRecipesList()
    for i = 0, all:size() - 1 do
        local e = all:get(i)
        if e:getOriginalname() == "CrockStew" or e:getResultItem() == "CrockOfStew" then return e end
    end
    return nil
end
