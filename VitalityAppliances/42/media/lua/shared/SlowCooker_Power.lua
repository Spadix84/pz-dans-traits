-- Generator load. The game charges every switched-on IsoStove the same 0.09 L/h of
-- fuel (IsoStove.getGeneratorPowerConsumption): oven, microwave or slow cooker. That's
-- Java and can't be overridden, so this works on the generator's total instead.
--
-- A generator recalculates its load only when something in range changes (an
-- appliance switched on or off, a chunk loading), listing what it powers as
-- "<name> x<count> (<L/h>)". It burns fuel once a game hour from the total, and saves
-- the total with the game. So once a minute, any generator whose total changed since
-- it was last corrected has the slow cookers on its list taken back off at the stove
-- rate and charged at SlowCooker.POWER_DRAW instead.
require "SlowCooker_Core"

SlowCooker.POWER_DRAW = 0.02     -- L/h a running cooker costs (default fuel use); a stove is 0.09
SlowCooker.STOVE_DRAW = 0.09     -- what the game charges any switched-on IsoStove
SlowCooker.RESCAN_HOURS = 6      -- how often a running cooker looks again for generators

local generators = {}            -- IsoGenerators found near running cookers
local corrected = {}             -- generator -> the raw total last set here
local scanned = {}               -- cooker -> world hour it last looked for generators

-- The name the generator lists the cooker under: the same as the game builds it.
function SlowCooker.powerName()
    if SlowCooker.POWER_NAME then return SlowCooker.POWER_NAME end
    local sprite = getSprite and getSprite(SlowCooker.TILESET .. "_0")
    local props = sprite and sprite:getProperties()
    if not props or not props:has("CustomName") then return nil end
    local name = props:get("CustomName")
    if props:has("GroupName") then name = props:get("GroupName") .. " " .. name end
    SlowCooker.POWER_NAME = Translator.getMoveableDisplayName(name)
    return SlowCooker.POWER_NAME
end

local function fuelMultiplier()
    return tonumber(SandboxVars and SandboxVars.GeneratorFuelConsumption) or 1
end

-- How many slow cookers this generator charged for at its last recalculation.
function SlowCooker.countedBy(gen)
    local name = SlowCooker.powerName()
    if not name then return 0 end
    local prefix = name .. " x"
    local items = gen:getItemsPowered()
    for i = 0, items:size() - 1 do
        local line = items:get(i)
        if string.sub(line, 1, #prefix) == prefix then
            return tonumber(string.match(string.sub(line, #prefix + 1), "^(%d+)")) or 0
        end
    end
    return 0
end

-- Charge this generator's slow cookers at POWER_DRAW. Safe to call any number of
-- times: it only acts after the game has recalculated the total.
function SlowCooker.fixGenerator(gen)
    if not gen:isActivated() then
        corrected[gen] = nil
        return false
    end
    local mult = fuelMultiplier()
    if mult <= 0 then return false end
    local raw = gen:getTotalPowerUsing() / mult
    local last = corrected[gen]
    if last and math.abs(raw - last) < 0.0005 then return false end
    local n = SlowCooker.countedBy(gen)
    if n == 0 then
        corrected[gen] = nil
        return false
    end
    local fixed = math.max(0, raw - n * (SlowCooker.STOVE_DRAW - SlowCooker.POWER_DRAW))
    gen:setTotalPowerUsing(fixed)
    corrected[gen] = fixed
    return true
end

local function gone(obj)
    return obj:getObjectIndex() == -1 or obj:getSquare() == nil
end

function SlowCooker.addGenerator(gen)
    for i = 1, #generators do
        if generators[i] == gen then return end
    end
    table.insert(generators, gen)
end

-- Generators within the game's power range of a cooker.
function SlowCooker.scanGenerators(obj)
    local square = obj:getSquare()
    if not square then return end
    local range = tonumber(SandboxVars and SandboxVars.GeneratorTileRange) or 20
    local levels = tonumber(SandboxVars and SandboxVars.GeneratorVerticalPowerRange) or 3
    local cell = getCell()
    local x0, y0, z0 = square:getX(), square:getY(), square:getZ()
    for z = z0 - levels, z0 + levels do
        for x = x0 - range, x0 + range do
            for y = y0 - range, y0 + range do
                local sq = cell:getGridSquare(x, y, z)
                local gen = sq and sq:getGenerator()
                if gen then SlowCooker.addGenerator(gen) end
            end
        end
    end
end

-- Called for each cooker every game minute. A running cooker off the grid looks for
-- the generators powering it when it starts, then every few hours in case one was
-- added.
function SlowCooker.watchPower(obj, running, now)
    if not running then
        scanned[obj] = nil
        return
    end
    local square = obj:getSquare()
    if not square or square:hasGridPower() then return end
    local last = scanned[obj]
    if last == nil or now - last >= SlowCooker.RESCAN_HOURS then
        scanned[obj] = now
        SlowCooker.scanGenerators(obj)
    end
end

-- Every game minute, after the cookers.
function SlowCooker.fixGenerators()
    for i = #generators, 1, -1 do
        local gen = generators[i]
        if gone(gen) then
            corrected[gen] = nil
            table.remove(generators, i)
        else
            SlowCooker.fixGenerator(gen)
        end
    end
end

-- Forget cookers that unloaded or were picked up.
function SlowCooker.forgetCooker(obj)
    scanned[obj] = nil
end
