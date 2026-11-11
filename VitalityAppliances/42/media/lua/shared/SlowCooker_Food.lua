-- Moving a meal out of the crock: a bowl at a time, or all of it into a cooking pot.
-- Plain functions on items so the tests can drive them; the timed actions in
-- TimedActions/ call them from complete().
require "SlowCooker_Core"

SlowCooker.SERVING = 0.15        -- hunger in one bowl, the same as the game's bowl of stew
SlowCooker.LAST_SCRAPS = 0.03    -- less than this left after a bowl: that bowl takes it all

SlowCooker.BOWLS = {
    ["Base.Bowl"] = "Base.StewBowl",
    ["Base.ClayBowl"] = "Base.StewBowlClay",
}
SlowCooker.POTS = {
    ["Base.Pot"] = "Base.PotOfStew",
    ["Base.PotForged"] = "Base.PotForgedStew",
}

local function try(fn) pcall(fn) end

-- What to call the meal: the recipe's name, or the name the game gave the stew.
function SlowCooker.mealName(dish)
    local id = dish:getModData().slowCookerDish
    local recipe = id and SlowCooker.recipeById and SlowCooker.recipeById(id)
    if recipe then return getText(recipe.name) end
    local name = dish:getDisplayName()
    local script = dish:getScriptItem()
    if script and name == script:getDisplayName() then
        return getText("ContextMenu_EvolvedRecipe_Stew")   -- nothing in it named it yet
    end
    return name
end

-- Everything that makes the meal what it is, from one food item to another.
function SlowCooker.copyFood(src, dst)
    dst:setHungChange(src:getHungChange())
    dst:setBaseHunger(src:getBaseHunger())
    dst:setThirstChange(src:getThirstChangeUnmodified())
    dst:setUnhappyChange(src:getUnhappyChangeUnmodified())
    dst:setBoredomChange(src:getBoredomChangeUnmodified())
    dst:setCalories(src:getCalories())
    dst:setCarbohydrates(src:getCarbohydrates())
    dst:setProteins(src:getProteins())
    dst:setLipids(src:getLipids())
    dst:setAge(src:getAge())
    dst:setCooked(src:isCooked())
    dst:setHeat(src:getHeat())
    try(function() dst:setBurnt(src:isBurnt()) end)
    try(function() dst:setTainted(src:isTainted()) end)
    try(function() dst:setPoisonPower(src:getPoisonPower()) end)
    try(function() dst:setFoodSicknessChange(src:getFoodSicknessChange()) end)
    local extra = src:getExtraItems()
    if extra then
        for i = 0, extra:size() - 1 do dst:addExtraItem(extra:get(i)) end
    end
    try(function() if src:getSpices() then dst:setSpices(src:getSpices()) end end)
    local from, to = src:getModData(), dst:getModData()
    for k, v in pairs(from) do
        if k ~= "slowCookerAge" then to[k] = v end
    end
    to.slowCookerHome = true      -- it came out of the crock: home cooking (read by Vitality)
end

local function scale(food, f)
    food:multiplyFoodValues(f)
    food:setBaseHunger(food:getBaseHunger() * f)
end

-- Share of the dish that one bowl takes.
function SlowCooker.servingShare(dish)
    local left = math.abs(dish:getHungChange())
    if left <= SlowCooker.SERVING + SlowCooker.LAST_SCRAPS then return 1 end
    return SlowCooker.SERVING / left
end

-- Fills a new bowl item from the dish. Returns the bowl and whether the crock is
-- now empty. The caller swaps the items in their containers.
function SlowCooker.fillBowl(dish, bowlType, make)
    local bowl = make(bowlType)
    local share = SlowCooker.servingShare(dish)
    SlowCooker.copyFood(dish, bowl)
    scale(bowl, share)
    bowl:setName(getText("Tooltip_food_Bowl", SlowCooker.mealName(dish)))
    bowl:setCustomName(true)
    if share >= 1 then return bowl, true end
    scale(dish, 1 - share)
    return bowl, false
end

-- The whole meal into a pot.
function SlowCooker.fillPot(dish, potType, make)
    local pot = make(potType)
    SlowCooker.copyFood(dish, pot)
    if dish:getModData().slowCookerDish or dish:isCustomName() then
        pot:setName(SlowCooker.mealName(dish))
        pot:setCustomName(true)
    end
    return pot
end
