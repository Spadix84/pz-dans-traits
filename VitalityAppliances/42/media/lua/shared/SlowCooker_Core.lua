-- Slow Cooker: an IsoStove whose container type the game doesn't treat as an oven
-- or microwave, so it has no temperature of its own, no metal-sparking and no burn
-- timer. The game's IsoStove still handles on/off, power loss and generator load.
--
-- How the cooking works (Food.update, Build 42):
--   * Food cooks only while its own heat is above 1.6, gaining heat/1.5 per minute.
--   * If its container is at 1.6 or below, that gain is cut to 5%.
-- So the container is held at exactly 1.6 and the food's heat just above it. The
-- game's own cooking then nearly stops, and this file supplies the rest of the rate.
-- Finishing is still left to the game: once the cooking time passes MinutesToCook
-- its own code marks the food cooked or swaps in the cooked item. After that the
-- time is held below MinutesToBurn, so food can stay in as long as you like.
--
-- The cooker holds only the stoneware crock (empty, or a dish cooking in it). While
-- it runs, food in it doesn't age: like a real keep-warm setting, a pot left on all
-- day is still good. Switched off or without power it spoils at the normal rate.
require "TimedActions/ISToggleStoveAction"

SlowCooker = SlowCooker or {}

SlowCooker.TILESET = "appliances_slowcooker_01"
SlowCooker.ON_OFFSET = 4          -- tiles 0-3 are the cooker, 4-7 the same view switched on
SlowCooker.CONTAINER_TEMP = 1.6
SlowCooker.FOOD_HEAT = 1.7
-- Cooking minutes added per game minute. With the game's own 5% trickle
-- (1.7 / 1.5 * 0.05 = 0.057) food cooks at 0.25 a minute, four times slower than a
-- stove: a 50-minute soup takes 3h20, a 70-minute stew 4h40.
SlowCooker.COOK_RATE = 0.193
SlowCooker.PAST_DONE = 0.5        -- how far past MinutesToCook the time is held
SlowCooker.CROCK = "Base.SlowCookerCrock"
SlowCooker.DISH = "Base.CrockOfStew"

local cookers = {}

function SlowCooker.spriteNames()
    local names = {}
    for i = 0, SlowCooker.ON_OFFSET - 1 do
        table.insert(names, SlowCooker.TILESET .. "_" .. i)
    end
    return names
end

local function spriteIndex(obj)
    local sprite = obj:getSprite()
    local name = sprite and sprite:getName()
    if not name then return nil end
    local prefix = SlowCooker.TILESET .. "_"
    if string.sub(name, 1, string.len(prefix)) ~= prefix then return nil end
    return tonumber(string.sub(name, string.len(prefix) + 1))
end

function SlowCooker.isCooker(obj)
    return obj ~= nil and instanceof(obj, "IsoStove") and spriteIndex(obj) ~= nil
end

-- The container's accept function (ItemContainer.setAcceptItemFunction): only the crock.
function SlowCooker.acceptItem(container, item)
    local t = item and item:getFullType()
    return t == SlowCooker.CROCK or t == SlowCooker.DISH
end

-- Not saved with the container, so it's set again whenever a cooker loads.
function SlowCooker.limitContainer(obj)
    local container = obj:getContainer()
    if container and container:getAcceptItemFunction() ~= "SlowCooker.acceptItem" then
        container:setAcceptItemFunction("SlowCooker.acceptItem")
    end
end

function SlowCooker.register(obj)
    SlowCooker.limitContainer(obj)
    for i = 1, #cookers do
        if cookers[i] == obj then return end
    end
    table.insert(cookers, obj)
end

function SlowCooker.cookFood(food, minutes)
    if food:isBurnt() or food:isFrozen() then return end
    if food:getHeat() < SlowCooker.FOOD_HEAT then
        food:setHeat(SlowCooker.FOOD_HEAT)
    end

    local toCook, toBurn = food:getMinutesToCook(), food:getMinutesToBurn()
    local time = food:getCookingTime()
    local tight = toBurn <= toCook + 1      -- no gap to hold in: the game would burn it
    local hold = tight and math.max(toBurn - 1, 0) or (toCook + SlowCooker.PAST_DONE)

    if food:isCooked() then
        if time > hold then food:setCookingTime(hold) end
        return
    end

    time = time + minutes * SlowCooker.COOK_RATE
    if time >= hold then
        food:setCookingTime(hold)
        if tight then food:setCooked(true) end
    else
        food:setCookingTime(time)
    end
end

-- Keep-warm: hold the age a food had when it went in (or when the power came
-- back). Clearing the mark when it stops lets it age again from there.
function SlowCooker.keepWarm(food, running)
    local md = food:getModData()
    if not running then
        md.slowCookerAge = nil
        return
    end
    local held = md.slowCookerAge
    if held == nil then
        md.slowCookerAge = food:getAge()
    elseif food:getAge() > held then
        food:setAge(held)
        if isServer() then sendItemStats(food) end
    end
end

local function syncOverlay(obj, running)
    local index = spriteIndex(obj)
    if index == nil or index >= SlowCooker.ON_OFFSET then return end
    local want = running and (SlowCooker.TILESET .. "_" .. (index + SlowCooker.ON_OFFSET)) or nil
    local current = obj:getOverlaySprite()
    local have = current and current:getName() or nil
    if have ~= want then
        obj:setOverlaySprite(want, isServer())
    end
end

function SlowCooker.update(obj, now)
    local container = obj:getContainer()
    if not container then return end
    now = now or getGameTime():getWorldAgeHours()

    -- Time since the last run also covers the base being unloaded during a trip away.
    local md = obj:getModData()
    local last = md.slowCookerLast or now
    md.slowCookerLast = now

    local running = obj:Activated() and container:isPowered() and not obj:isBroken()
    local temp = running and SlowCooker.CONTAINER_TEMP or 0
    if container:getCustomTemperature() ~= temp then
        container:setCustomTemperature(temp)
    end
    syncOverlay(obj, running)
    if SlowCooker.watchPower then SlowCooker.watchPower(obj, running, now) end

    local minutes = math.max(0, (now - last) * 60)
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if instanceof(item, "Food") then
            SlowCooker.keepWarm(item, running)
            if running and item:isCookable() then
                SlowCooker.cookFood(item, minutes)
            end
        end
    end
    if not running then return end
    -- Items added since the last run only start updating once on this list. Repeats
    -- are safe: the game skips anything already on it.
    container:addItemsToProcessItems()
end

local function loaded(obj)
    local square = obj:getSquare()
    return square ~= nil and obj:getObjectIndex() ~= -1
        and getCell():getGridSquare(square:getX(), square:getY(), square:getZ()) == square
end

function SlowCooker.tick()
    local now = getGameTime():getWorldAgeHours()
    for i = #cookers, 1, -1 do
        local obj = cookers[i]
        if loaded(obj) then
            SlowCooker.update(obj, now)
        else
            table.remove(cookers, i)
            if SlowCooker.forgetCooker then SlowCooker.forgetCooker(obj) end
        end
    end
    -- Generator load: see SlowCooker_Power.lua.
    if SlowCooker.fixGenerators then SlowCooker.fixGenerators() end
end

-- React straight away to the on/off button instead of on the next game minute.
local complete = ISToggleStoveAction.complete
function ISToggleStoveAction:complete()
    local result = complete(self)
    if SlowCooker.isCooker(self.object) then
        SlowCooker.register(self.object)
        SlowCooker.update(self.object)
    end
    return result
end
