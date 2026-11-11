-- Slow Cooker API for other mods. Everything here is safe to call from a shared or
-- client Lua file at load time; see API.md beside the mod for examples.
--
--   local ok = pcall(require, "SlowCooker_API")
--   if ok and SlowCooker and SlowCooker.API_VERSION then
--       SlowCooker.addRecipe({ ... })
--   end
--
-- Ingredients have to be foods the game allows in a stew (their item script lists
-- "Stew" in EvolvedRecipe): the dish is made by the game's own evolved recipe.
require "SlowCooker_Core"
require "SlowCooker_Food"
require "SlowCooker_Recipes"
require "SlowCooker_Power"

SlowCooker.API_VERSION = 1

local function warn(msg) print("[SlowCooker] " .. msg) end

local function validItems(items, where)
    if type(items) ~= "table" or #items == 0 then
        error("SlowCooker: " .. where .. " needs a list of item full types", 3)
    end
    for _, t in ipairs(items) do
        if type(t) ~= "string" or not t:find("%.") then
            error("SlowCooker: " .. where .. ": '" .. tostring(t) .. "' is not a full type like Base.Beef", 3)
        end
    end
end

-- Recipes -------------------------------------------------------------------------

-- def = {
--   id     = "mymod_gumbo",                     unique; prefix it with your mod's name
--   level  = 4,                                 Cooking level that unlocks it (0-10)
--   name   = "IGUI_MyMod_Gumbo" or "Gumbo",      translation key or plain text
--   groups = {                                  what has to go in
--     { label = "IGUI_MyMod_Seafood", need = 1, items = { "Base.Shrimp", "Base.Crayfish" } },
--     { label = "Rice", need = 1, items = { "Base.Rice" } },
--     { label = "IGUI_SlowCooker_Extras", need = 0, items = { "Base.Onion" } },  -- optional
--   },
--   unhappy = -20, boredom = -20,               optional: the dish's mood bonus (default as built-in)
-- }
-- need = 2 asks for two different items from the group. Returns the recipe table.
-- A recipe card is any literature item with LearnedRecipes = SlowCooker_<id>.
function SlowCooker.addRecipe(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
        error("SlowCooker.addRecipe: needs a table with a string id", 2)
    end
    if def.id == SlowCooker.FREEFORM or SlowCooker.recipeById(def.id) then
        error("SlowCooker.addRecipe: a recipe called '" .. def.id .. "' already exists", 2)
    end
    local level = tonumber(def.level) or 0
    if type(def.groups) ~= "table" or #def.groups == 0 then
        error("SlowCooker.addRecipe: '" .. def.id .. "' needs at least one ingredient group", 2)
    end
    local recipe = { id = def.id, level = math.max(0, math.min(10, level)), name = def.name or def.id,
        groups = {}, unhappy = def.unhappy, boredom = def.boredom, mod = def.mod }
    for i, g in ipairs(def.groups) do
        validItems(g.items, "recipe '" .. def.id .. "' group " .. i)
        local items = {}
        for _, t in ipairs(g.items) do table.insert(items, t) end
        table.insert(recipe.groups, { label = g.label or "IGUI_SlowCooker_Extras",
            need = math.max(0, tonumber(g.need) or 1), items = items })
    end
    -- Keep the list in unlock order (the window shows it as it is).
    local at = #SlowCooker.RECIPES + 1
    for i, r in ipairs(SlowCooker.RECIPES) do
        if r.level > recipe.level then at = i break end
    end
    table.insert(SlowCooker.RECIPES, at, recipe)
    return recipe
end

-- Take a recipe out, built-in or not (for overhauls). Returns true if it was there.
function SlowCooker.removeRecipe(id)
    for i, r in ipairs(SlowCooker.RECIPES) do
        if r.id == id then
            table.remove(SlowCooker.RECIPES, i)
            return true
        end
    end
    return false
end

-- Add items to one of a recipe's groups, found by its position or its label, e.g.
-- SlowCooker.addIngredients("chili", "IGUI_SlowCooker_Meat", { "MyMod.Bison" }).
-- With no such group, a new optional group of extras is added. Returns true if added.
function SlowCooker.addIngredients(recipeId, group, items)
    validItems(items, "addIngredients('" .. tostring(recipeId) .. "')")
    local recipe = SlowCooker.recipeById(recipeId)
    if not recipe then
        warn("addIngredients: no recipe '" .. tostring(recipeId) .. "'")
        return false
    end
    local target = type(group) == "number" and recipe.groups[group] or nil
    if not target then
        for _, g in ipairs(recipe.groups) do
            if g.label == group then target = g break end
        end
    end
    if not target then
        target = { label = type(group) == "string" and group or "IGUI_SlowCooker_Extras", need = 0, items = {} }
        table.insert(recipe.groups, target)
    end
    for _, t in ipairs(items) do
        local have = false
        for _, v in ipairs(target.items) do if v == t then have = true break end end
        if not have then table.insert(target.items, t) end
    end
    return true
end

-- The recipes, in unlock order (the live table: read it, change it with the calls above).
function SlowCooker.getRecipes() return SlowCooker.RECIPES end

-- Serving --------------------------------------------------------------------------

-- An empty bowl type and the full bowl it becomes, e.g. ("MyMod.WoodBowl", "MyMod.WoodBowlStew").
-- The full one should be a Food item like Base.StewBowl.
function SlowCooker.addBowl(emptyType, fullType)
    validItems({ emptyType, fullType }, "addBowl")
    SlowCooker.BOWLS[emptyType] = fullType
end

-- An empty pot type and the full pot it becomes, e.g. ("MyMod.Cauldron", "MyMod.CauldronStew").
function SlowCooker.addPot(emptyType, fullType)
    validItems({ emptyType, fullType }, "addPot")
    SlowCooker.POTS[emptyType] = fullType
end

-- Power -----------------------------------------------------------------------------

-- Generator fuel a running cooker uses, in litres an hour at the default fuel use
-- (the sandbox multiplier applies on top). Default 0.02; the game's stoves are 0.09.
function SlowCooker.setPowerDraw(litresPerHour)
    local v = tonumber(litresPerHour)
    if not v or v < 0 then error("SlowCooker.setPowerDraw: needs 0 or more litres an hour", 2) end
    SlowCooker.POWER_DRAW = v
end

-- Questions -------------------------------------------------------------------------

-- Did this food come out of a slow cooker? Returns true and the recipe id (nil for
-- plain crock stew). Bowls and pots served from the crock count.
function SlowCooker.isHomeCooked(item)
    if not item or not item.getModData then return false end
    local md = item:getModData()
    local home = md.slowCookerHome == true
    if not home and item.getFullType then home = item:getFullType() == SlowCooker.DISH end
    if not home then return false end
    return true, md.slowCookerDish
end

-- Does this player know the recipe (by level, booklet or card)?
function SlowCooker.playerKnows(player, recipeId)
    local recipe = SlowCooker.recipeById(recipeId)
    return recipe ~= nil and SlowCooker.knows(player, recipe)
end

-- Events ----------------------------------------------------------------------------
--   "dishMade"  fn(character, dish, recipe)        ingredients went into the crock;
--                                                   recipe is nil for plain crock stew
--   "served"    fn(character, dish, filled, kind)   kind is "bowl" or "pot"; dish is
--                                                   what's left in the crock (nil if emptied)
-- Called where the action completes (on the server in multiplayer). An error in one
-- listener is logged and doesn't stop the others.
SlowCooker.listeners = SlowCooker.listeners or { dishMade = {}, served = {} }

function SlowCooker.on(event, fn)
    local list = SlowCooker.listeners[event]
    if not list then error("SlowCooker.on: unknown event '" .. tostring(event) .. "'", 2) end
    if type(fn) ~= "function" then error("SlowCooker.on: needs a function", 2) end
    table.insert(list, fn)
end

function SlowCooker.off(event, fn)
    local list = SlowCooker.listeners[event] or {}
    for i = #list, 1, -1 do
        if list[i] == fn then table.remove(list, i) end
    end
end

function SlowCooker.fire(event, ...)
    for _, fn in ipairs(SlowCooker.listeners[event] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then warn("a '" .. event .. "' listener failed: " .. tostring(err)) end
    end
end

-- Missing items in any recipe (a typo, or a mod that isn't loaded) are reported once
-- the scripts are in; the window just won't offer them.
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        local sm = getScriptManager()
        for _, r in ipairs(SlowCooker.RECIPES) do
            for _, g in ipairs(r.groups) do
                for _, t in ipairs(g.items) do
                    if not sm:FindItem(t) then warn("recipe '" .. r.id .. "': no item " .. t) end
                end
            end
        end
    end)
end
