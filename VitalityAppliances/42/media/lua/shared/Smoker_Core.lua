-- Brick Smoker: a masonry smoker, built outdoors. A wood fire in the firebox smokes
-- meat, poultry and fish in the chamber above over game hours.
--
--   * 8 hours of smoke: Smoked (ready to eat, keeps about two weeks).
--   * 24 hours of smoke: Smoke-Dried (jerky-like, lighter, keeps about four months).
--   * While the fire burns nothing in the chamber spoils. Out, it ages as normal.
--
-- Each piece keeps its own nutrition: the smoked item is a new item (so its shelf
-- life comes from the item script and is saved like any other), with the hunger,
-- calories and macros of the piece that went in. Smoked meat still goes in stews.
--
-- The smoker's state lives in the object's mod data: fuel (hours), lit, and the
-- world time it last ran, so a trip away is caught up when the area loads again.
-- The fire, the smoking and the item swaps run where the world does: singleplayer
-- or the multiplayer host (server/Smoker_Server.lua ticks it).
Smoker = Smoker or {}

Smoker.TILESET = "crafted_smoker_01"
Smoker.LIT_OFFSET = 4             -- tiles 0-3 are the smoker, 4-7 the same views lit
Smoker.SMOKED_HOURS = 8
Smoker.DRIED_HOURS = 24
Smoker.MAX_FUEL_HOURS = 24        -- the firebox holds about four logs
Smoker.MIN_LIGHT_HOURS = 0.25     -- fuel needed before it will light
Smoker.SMOKED_WEIGHT = 0.85       -- share of the weight left after smoking
Smoker.DRIED_WEIGHT = 0.6         -- after smoke-drying, of the smoked weight

-- Other mods: use Smoker_API.lua (and API.md) rather than these tables directly.

-- Hours of fire per item, by full type ("MyMod.Log") or, for vanilla wood, short type.
-- Wood only: paper and rags make a fire but not smoke anyone wants on their dinner.
-- Close to the vanilla campfire values.
Smoker.FUEL = {
    Log = 6.0, Firewood = 2.0, Plank = 2.0, PercedWood = 2.0, UnusableWood = 1.4,
    TreeBranch = 1.0, TreeBranch2 = 1.0, Charcoal = 1.0, CharcoalCrafted = 1.0,
    Pinecone = 0.5, WoodenStick = 0.25, WoodenStick2 = 0.25, Twigs = 0.25,
}

-- Food types that smoke. Processed foods of those types are left out below.
Smoker.FOOD_TYPES = {
    Beef = "meat", Meat = "meat", Venison = "meat", Game = "meat", Sausage = "meat", Bacon = "meat",
    Poultry = "poultry", Fish = "fish", Seafood = "fish",
}
Smoker.EXCLUDE = {
    ["Base.ChickenNuggets"] = true, ["Base.FishFingers"] = true, ["Base.Hotdog_single"] = true,
    ["Base.ShrimpFriedCraft"] = true, ["Base.BaconBits"] = true, ["Base.TunaTinOpen"] = true,
    ["Base.CannedSardinesOpen"] = true, ["Base.CannedCornedBeefOpen"] = true,
    ["Base.CannedBologneseOpen"] = true, ["Base.CannedChiliOpen"] = true,
}

-- Items that smoke whatever their food type, as their kind (Smoker.addSmokable).
-- These skip the food-type, cookable and packaged checks and beat EXCLUDE.
Smoker.ITEMS = {}

-- What each kind becomes. Poultry dries into the same jerky as meat. A kind with no
-- DRIED entry stops at Smoked (Smoker.addKind).
Smoker.SMOKED = { meat = "Base.SmokedMeat", poultry = "Base.SmokedPoultry", fish = "Base.SmokedFish" }
Smoker.DRIED = { meat = "Base.SmokeDriedMeat", poultry = "Base.SmokeDriedMeat", fish = "Base.SmokeDriedFish" }

local smokers = {}

-- Events ------------------------------------------------------------------------------
-- Smoker.on / Smoker.off are documented in Smoker_API.lua. Fired where the world runs
-- (singleplayer, or the server in multiplayer). A failing listener is logged and
-- doesn't stop the others.
Smoker.listeners = Smoker.listeners or { lit = {}, putOut = {}, fuelAdded = {}, smoked = {} }

function Smoker.fire(event, ...)
    for _, fn in ipairs(Smoker.listeners[event] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then print("[BrickSmoker] a '" .. event .. "' listener failed: " .. tostring(err)) end
    end
end

-- The smoker object ------------------------------------------------------------------
function Smoker.spriteNames()
    local names = {}
    for i = 0, Smoker.LIT_OFFSET - 1 do
        table.insert(names, Smoker.TILESET .. "_" .. i)
    end
    return names
end

local function spriteIndex(obj)
    local sprite = obj:getSprite()
    local name = sprite and sprite:getName()
    if not name then return nil end
    local prefix = Smoker.TILESET .. "_"
    if string.sub(name, 1, string.len(prefix)) ~= prefix then return nil end
    return tonumber(string.sub(name, string.len(prefix) + 1))
end

function Smoker.isSmoker(obj)
    if obj == nil then return false end
    local i = spriteIndex(obj)
    return i ~= nil and i < Smoker.LIT_OFFSET and obj:getContainer() ~= nil
end

function Smoker.fuelHours(obj) return obj:getModData().smokerFuel or 0 end
function Smoker.isLit(obj) return obj:getModData().smokerLit == true end
function Smoker.room(obj) return math.max(0, Smoker.MAX_FUEL_HOURS - Smoker.fuelHours(obj)) end

function Smoker.isOutdoors(obj)
    local square = obj:getSquare()
    return square ~= nil and square:isOutside()
end

-- Food -------------------------------------------------------------------------------
local function try(fn)
    local ok, v = pcall(fn)
    if ok then return v end
    return nil
end

local function kindFor(map, fullType)
    for kind, t in pairs(map) do
        if t == fullType then return kind end
    end
    return nil
end

-- The kind of a food: "meat", "poultry", "fish" or one a mod added. A smoked item
-- remembers the kind it was made as; otherwise it's the item's own registration,
-- then its food type.
function Smoker.kindOf(item)
    local md = item:getModData()
    if md.smokerKind then return md.smokerKind end
    local t = item:getFullType()
    if Smoker.ITEMS[t] then return Smoker.ITEMS[t] end
    local ft = try(function() return item:getFoodType() end)
    return ft and Smoker.FOOD_TYPES[ft] or kindFor(Smoker.SMOKED, t) or kindFor(Smoker.DRIED, t)
end

-- Where a food is:
--   "raw"     smokes into its kind's Smoked item
--   "smoked"  dries into its kind's Smoke-Dried item
--   "dried"   a Smoke-Dried item: finished
--   "done"    a Smoked item whose kind has no dried stage: finished
--   nil       doesn't smoke
function Smoker.stage(item)
    if not item or not instanceof(item, "Food") then return nil end
    local t = item:getFullType()
    if kindFor(Smoker.DRIED, t) then return "dried" end
    if kindFor(Smoker.SMOKED, t) then
        return Smoker.DRIED[Smoker.kindOf(item)] and "smoked" or "done"
    end
    local kind = Smoker.kindOf(item)
    if not kind or not Smoker.SMOKED[kind] then return nil end
    if Smoker.ITEMS[t] then return "raw" end
    if Smoker.EXCLUDE[t] then return nil end
    if try(function() return item:isPackaged() end) then return nil end
    if not item:isCookable() then return nil end
    return "raw"
end

function Smoker.isFinished(stage) return stage == "dried" or stage == "done" end

-- Can it go in the chamber? Raw meat that's already rotten or burnt can't be saved.
function Smoker.canSmoke(item)
    local stage = Smoker.stage(item)
    if stage == nil then return false end
    if stage == "raw" and (item:isBurnt() or try(function() return item:isRotten() end)) then return false end
    return true
end

-- The container's accept function (ItemContainer.setAcceptItemFunction).
function Smoker.acceptItem(container, item)
    return Smoker.canSmoke(item)
end

-- Not saved with the container, so it's set again whenever a smoker loads.
function Smoker.limitContainer(obj)
    local container = obj:getContainer()
    if container and container:getAcceptItemFunction() ~= "Smoker.acceptItem" then
        container:setAcceptItemFunction("Smoker.acceptItem")
    end
end

-- Hours of smoke towards the next stage, and the hours that stage needs.
function Smoker.progress(item)
    local stage = Smoker.stage(item)
    local hours = item:getModData().smokerHours or 0
    if stage == "raw" then return hours, Smoker.SMOKED_HOURS end
    if stage == "smoked" then return hours, Smoker.DRIED_HOURS end
    return hours, nil
end

local function baseName(item)
    return item:getModData().smokerName or item:getDisplayName()
end

-- The smoked (or smoke-dried) item made from src. The caller swaps them over.
-- make(fullType) makes an item: instanceItem in the game, a stand-in in the tests.
function Smoker.makeProduct(src, fullType, dried, make)
    local dst = make(fullType)
    dst:setHungChange(src:getHungChange())
    dst:setBaseHunger(src:getBaseHunger())
    dst:setCalories(src:getCalories())
    dst:setCarbohydrates(src:getCarbohydrates())
    dst:setProteins(src:getProteins())
    dst:setLipids(src:getLipids())
    dst:setAge(0)
    try(function()
        dst:setActualWeight(src:getActualWeight() * (dried and Smoker.DRIED_WEIGHT or Smoker.SMOKED_WEIGHT))
        dst:setCustomWeight(true)
    end)
    try(function() dst:setTainted(src:isTainted()) end)
    try(function() dst:setPoisonPower(src:getPoisonPower()) end)

    local name = baseName(src)
    local from, to = src:getModData(), dst:getModData()
    for k, v in pairs(from) do
        if k ~= "smokerAge" then to[k] = v end
    end
    to.smokerName = name
    to.smokerKind = Smoker.kindOf(src)
    dst:setName(getText(dried and "IGUI_Smoker_DriedName" or "IGUI_Smoker_SmokedName", name))
    dst:setCustomName(true)
    return dst
end

-- Add hours of smoke to one item. Returns the item that should now be in the
-- chamber: itself, or the product it turned into (maybe past both stages at once,
-- after a long trip away).
function Smoker.smokeItem(item, hours, make)
    local stage = Smoker.stage(item)
    if stage ~= "raw" and stage ~= "smoked" then return item end
    if stage == "raw" and not Smoker.canSmoke(item) then return item end
    local md = item:getModData()
    md.smokerHours = (md.smokerHours or 0) + hours
    if stage == "raw" and md.smokerHours >= Smoker.SMOKED_HOURS then
        local kind = Smoker.kindOf(item)
        local out = Smoker.makeProduct(item, Smoker.SMOKED[kind], false, make)
        out:getModData().smokerHours = md.smokerHours
        return Smoker.smokeItem(out, 0, make)
    end
    if stage == "smoked" and md.smokerHours >= Smoker.DRIED_HOURS then
        local kind = Smoker.kindOf(item)
        local out = Smoker.makeProduct(item, Smoker.DRIED[kind], true, make)
        out:getModData().smokerHours = md.smokerHours
        return out
    end
    return item
end

-- While the fire burns: hold the age a food had when the fire caught it.
function Smoker.keepFresh(food, burning)
    local md = food:getModData()
    if not burning then
        md.smokerAge = nil
        return
    end
    local held = md.smokerAge
    if held == nil then
        md.smokerAge = food:getAge()
    elseif food:getAge() > held then
        food:setAge(held)
        if isServer() then sendItemStats(food) end
    end
end

-- The fire ---------------------------------------------------------------------------
local function syncOverlay(obj)
    local index = spriteIndex(obj)
    if index == nil or index >= Smoker.LIT_OFFSET then return end
    local want = Smoker.isLit(obj) and (Smoker.TILESET .. "_" .. (index + Smoker.LIT_OFFSET)) or nil
    local current = obj:getOverlaySprite()
    local have = current and current:getName() or nil
    if have ~= want then
        obj:setOverlaySprite(want, isServer())
    end
end

local function changed(obj)
    syncOverlay(obj)
    if isServer() then obj:transmitModData() end
end

function Smoker.register(obj)
    Smoker.limitContainer(obj)
    for i = 1, #smokers do
        if smokers[i] == obj then return end
    end
    table.insert(smokers, obj)
end

-- Hours of fire an item gives, or nil if it isn't smoker fuel.
function Smoker.fuelValue(item)
    if not item then return nil end
    return Smoker.FUEL[item:getFullType()] or Smoker.FUEL[item:getType()]
end

-- Returns the hours actually added (the firebox only holds so much).
function Smoker.addFuel(obj, hours)
    local md = obj:getModData()
    local add = math.min(hours, Smoker.room(obj))
    md.smokerFuel = Smoker.fuelHours(obj) + add
    changed(obj)
    return add
end

-- Can it be lit now? nil, or the translation key of the reason not.
function Smoker.lightProblem(obj)
    if Smoker.isLit(obj) then return "IGUI_Smoker_AlreadyLit" end
    if not Smoker.isOutdoors(obj) then return "IGUI_Smoker_NotOutdoors" end
    if Smoker.fuelHours(obj) < Smoker.MIN_LIGHT_HOURS then return "IGUI_Smoker_NoFuel" end
    return nil
end

-- character: who lit it (nil if a mod did), passed on to "lit" listeners.
function Smoker.light(obj, now, character)
    if Smoker.lightProblem(obj) then return false end
    local md = obj:getModData()
    md.smokerLit = true
    md.smokerLast = now or getGameTime():getWorldAgeHours()
    Smoker.register(obj)
    changed(obj)
    Smoker.fire("lit", character, obj)
    return true
end

local function released(obj)
    local items = obj:getContainer() and obj:getContainer():getItems()
    if items then
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if instanceof(item, "Food") then Smoker.keepFresh(item, false) end
        end
    end
end

-- Putting it out keeps what's left of the fuel for next time. reason is "player"
-- (the default), or whatever a mod passes; the fire going out by itself is "fuel"
-- or "roof" (see Smoker.update).
function Smoker.extinguish(obj, reason, character)
    local md = obj:getModData()
    if not md.smokerLit then return end
    md.smokerLit = false
    changed(obj)
    released(obj)
    Smoker.fire("putOut", character, obj, reason or "player")
end


local function swap(container, old, new)
    container:DoRemoveItem(old)
    sendRemoveItemFromContainer(container, old)
    container:AddItem(new)
    sendAddItemToContainer(container, new)
end

-- Run one smoker up to now: burn fuel, smoke and keep its food.
function Smoker.update(obj, now, make)
    local container = obj:getContainer()
    if not container then return end
    now = now or getGameTime():getWorldAgeHours()
    make = make or instanceItem
    local md = obj:getModData()
    local last = md.smokerLast or now
    md.smokerLast = now
    local elapsed = math.max(0, now - last)

    local burning = Smoker.isLit(obj)
    local smoke, outReason = 0, nil
    if burning then
        if not Smoker.isOutdoors(obj) then
            md.smokerLit = false             -- someone roofed it over: the fire chokes
            outReason = "roof"
        else
            local fuel = Smoker.fuelHours(obj)
            smoke = math.min(elapsed, fuel)
            md.smokerFuel = math.max(0, fuel - elapsed)
            if md.smokerFuel <= 0 then
                md.smokerLit = false
                outReason = "fuel"
            end
        end
    end

    local items = container:getItems()
    local list = {}
    for i = 0, items:size() - 1 do table.insert(list, items:get(i)) end
    for _, item in ipairs(list) do
        if instanceof(item, "Food") then
            local out = item
            if smoke > 0 then out = Smoker.smokeItem(item, smoke, make) end
            if out ~= item then
                swap(container, item, out)
                Smoker.fire("smoked", obj, item, out, Smoker.stage(out))
            elseif smoke > 0 and isServer() then
                sendItemStats(item)
            end
            Smoker.keepFresh(out, burning and Smoker.isLit(obj))
        end
    end
    if burning ~= Smoker.isLit(obj) or smoke > 0 then changed(obj) end
    if outReason then Smoker.fire("putOut", nil, obj, outReason) end
end

local function loaded(obj)
    local square = obj:getSquare()
    return square ~= nil and obj:getObjectIndex() ~= -1
        and getCell():getGridSquare(square:getX(), square:getY(), square:getZ()) == square
end

-- Every ten game minutes: lit smokers only. One that's gone out drops off the list.
function Smoker.tick()
    local now = getGameTime():getWorldAgeHours()
    for i = #smokers, 1, -1 do
        local obj = smokers[i]
        if loaded(obj) then
            Smoker.update(obj, now)
            if not Smoker.isLit(obj) then table.remove(smokers, i) end
        else
            table.remove(smokers, i)
        end
    end
end

-- Found as it loads: set the container rule, and pick up a fire left burning.
function Smoker.onLoad(obj)
    if not Smoker.isSmoker(obj) then return end
    Smoker.limitContainer(obj)
    if Smoker.isLit(obj) then
        Smoker.register(obj)
        Smoker.update(obj)
    end
end
