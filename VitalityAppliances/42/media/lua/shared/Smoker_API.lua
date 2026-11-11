-- Brick Smoker API for other mods. Everything here is safe to call from a shared or
-- client Lua file at load time; see API.md beside the mod for examples.
--
--   local ok = pcall(require, "Smoker_API")
--   if ok and Smoker and Smoker.API_VERSION then
--       Smoker.setFuel("MyMod.HickoryChunks", 3)
--   end
--
-- What a food turns into is decided by its "kind". The built-in kinds are "meat",
-- "poultry" and "fish"; a food's kind comes from its own registration
-- (addSmokable), else its script's FoodType (addFoodType).
require "Smoker_Core"

Smoker.API_VERSION = 1

local function warn(msg) print("[BrickSmoker] " .. msg) end

local function fullType(t, where)
    if type(t) ~= "string" or not t:find("%.") then
        error("Smoker." .. where .. ": '" .. tostring(t) .. "' is not a full type like Base.Steak", 3)
    end
end

local function knownKind(kind, where)
    if type(kind) ~= "string" or not Smoker.SMOKED[kind] then
        error("Smoker." .. where .. ": no kind '" .. tostring(kind) .. "' (add it with Smoker.addKind first)", 3)
    end
end

-- Fuel ---------------------------------------------------------------------------------

-- Hours of fire one of this item gives. hours nil or 0 stops it being fuel.
--   Smoker.setFuel("MyMod.HickoryChunks", 3)
function Smoker.setFuel(itemType, hours)
    fullType(itemType, "setFuel")
    hours = tonumber(hours)
    Smoker.FUEL[itemType] = (hours and hours > 0) and hours or nil
    -- Vanilla wood is keyed by its short type too; clear that so "no" means no.
    if not Smoker.FUEL[itemType] and itemType:sub(1, 5) == "Base." then
        Smoker.FUEL[itemType:sub(6)] = nil
    end
end

-- Hours of fire for an item type (full type), or nil.
function Smoker.getFuel(itemType)
    return Smoker.FUEL[itemType] or (type(itemType) == "string" and Smoker.FUEL[itemType:match("%.(.+)$") or ""]) or nil
end

-- How many hours of fuel the firebox holds (default 24).
function Smoker.setFuelCapacity(hours)
    hours = tonumber(hours)
    if not hours or hours <= 0 then error("Smoker.setFuelCapacity: needs a positive number of hours", 2) end
    Smoker.MAX_FUEL_HOURS = hours
end

-- Food -----------------------------------------------------------------------------------

-- A kind: what its foods turn into. driedType nil means it stops at Smoked.
-- Calling it for an existing kind changes that kind's products.
--   Smoker.addKind("cheese", "MyMod.SmokedCheese")                        -- no dried stage
--   Smoker.addKind("sausage", "MyMod.SmokedSausage", "MyMod.DrySausage")
-- Products should be Food items. The smoker gives them the hunger, calories, macros
-- and (scaled) weight of the food that went in, and its name ("Smoked %1").
function Smoker.addKind(kind, smokedType, driedType)
    if type(kind) ~= "string" or kind == "" then error("Smoker.addKind: needs a kind name", 2) end
    fullType(smokedType, "addKind")
    if driedType ~= nil then fullType(driedType, "addKind") end
    Smoker.SMOKED[kind] = smokedType
    Smoker.DRIED[kind] = driedType
end

-- This item smokes as this kind, whatever its food type, even if it's packaged,
-- not cookable or on the built-in exclude list.
--   Smoker.addSmokable("MyMod.BisonSteak", "meat")
function Smoker.addSmokable(itemType, kind)
    fullType(itemType, "addSmokable")
    knownKind(kind, "addSmokable")
    Smoker.ITEMS[itemType] = kind
    Smoker.EXCLUDE[itemType] = nil
end

-- This item never smokes (it can't go in the chamber).
--   Smoker.removeSmokable("Base.Sausage")
function Smoker.removeSmokable(itemType)
    fullType(itemType, "removeSmokable")
    Smoker.ITEMS[itemType] = nil
    Smoker.EXCLUDE[itemType] = true
end

-- Every cookable, unpackaged food with this FoodType (from its item script) smokes as
-- this kind. kind nil removes the food type.
--   Smoker.addFoodType("Mutton", "meat")
function Smoker.addFoodType(foodType, kind)
    if type(foodType) ~= "string" or foodType == "" then error("Smoker.addFoodType: needs a FoodType", 2) end
    if kind ~= nil then knownKind(kind, "addFoodType") end
    Smoker.FOOD_TYPES[foodType] = kind
end

-- Hours of smoke to Smoked, and to Smoke-Dried (defaults 8 and 24). Counted from when
-- the food went in, so dried must be more than smoked.
function Smoker.setTimes(smokedHours, driedHours)
    smokedHours, driedHours = tonumber(smokedHours), tonumber(driedHours)
    if not smokedHours or smokedHours <= 0 or not driedHours or driedHours <= smokedHours then
        error("Smoker.setTimes: needs 0 < smoked hours < dried hours", 2)
    end
    Smoker.SMOKED_HOURS, Smoker.DRIED_HOURS = smokedHours, driedHours
end

-- Questions ----------------------------------------------------------------------------

-- Did this food come out of a smoker? Returns true, its stage ("smoked", "dried" or
-- "done"), its kind, and the name of what went in ("Venison"). False for anything else.
function Smoker.isSmokedFood(item)
    local stage = Smoker.stage(item)
    if stage == nil or stage == "raw" then return false end
    local md = item:getModData()
    return true, stage, Smoker.kindOf(item), md.smokerName
end

-- Also: Smoker.canSmoke(item), can it go in the chamber? (Raw food that smokes and
-- isn't rotten or burnt, or something already smoked.) Smoker.stage(item) and
-- Smoker.kindOf(item) give the details.

-- Hours of smoke so far towards the next stage, the hours that stage needs (nil when
-- finished), and the stage.
function Smoker.getProgress(item)
    local hours, need = Smoker.progress(item)
    return hours, need, Smoker.stage(item)
end

-- The smoker on a square, or nil.
function Smoker.findOnSquare(square)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        if Smoker.isSmoker(objects:get(i)) then return objects:get(i) end
    end
    return nil
end

-- Also available, on a smoker object:
--   Smoker.isSmoker(obj), Smoker.isLit(obj), Smoker.fuelHours(obj), Smoker.room(obj),
--   Smoker.isOutdoors(obj), Smoker.lightProblem(obj) -> nil or a translation key.
-- And, run where the world runs (singleplayer, or the server in multiplayer):
--   Smoker.addFuel(obj, hours) -> hours added, Smoker.light(obj, nil, character) -> ok,
--   Smoker.extinguish(obj, reason, character).

-- Events -------------------------------------------------------------------------------
--   "lit"        fn(character, smoker)                  character nil if a mod lit it
--   "putOut"     fn(character, smoker, reason)          reason "player", "fuel" (burned
--                                                       out) or "roof" (roofed over);
--                                                       character nil unless "player"
--   "fuelAdded"  fn(character, smoker, item, hours)     hours actually added
--   "smoked"     fn(smoker, food, product, stage)       food (gone now) became product;
--                                                       stage is the product's
-- Called where the world runs (on the server in multiplayer). An error in one
-- listener is logged and doesn't stop the others.
function Smoker.on(event, fn)
    local list = Smoker.listeners[event]
    if not list then error("Smoker.on: unknown event '" .. tostring(event) .. "'", 2) end
    if type(fn) ~= "function" then error("Smoker.on: needs a function", 2) end
    table.insert(list, fn)
end

function Smoker.off(event, fn)
    local list = Smoker.listeners[event] or {}
    for i = #list, 1, -1 do
        if list[i] == fn then table.remove(list, i) end
    end
end

-- Registered items that don't exist (a typo, or a mod that isn't loaded) are reported
-- once the scripts are in. They just never turn up.
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        local sm = getScriptManager()
        local function check(t, what)
            if type(t) == "string" and t:find("%.") and not sm:FindItem(t) then
                warn(what .. ": no item " .. t)
            end
        end
        for kind, t in pairs(Smoker.SMOKED) do check(t, "kind '" .. kind .. "' smoked product") end
        for kind, t in pairs(Smoker.DRIED) do check(t, "kind '" .. kind .. "' dried product") end
        for t in pairs(Smoker.ITEMS) do check(t, "smokable") end
        for t in pairs(Smoker.FUEL) do check(t, "fuel") end
    end)
end
