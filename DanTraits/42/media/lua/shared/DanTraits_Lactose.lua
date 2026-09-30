-- Project Zomboid Vitality Project: Lactose Intolerance.
--
-- Gluten Intolerance's milder cousin. Dairy (the dairy tag of
-- DanTraits_Food.lua: milk, cheese, butter, cream, yogurt, ice cream, pizza,
-- lasagne, a dish with cheese in it) and milk drunk from a carton or glass
-- (the drink hook, by the fluid's name: the game's are CowMilk, SheepMilk,
-- AnimalMilk and MilkChocolate, so any fluid with milk or cream in its name
-- counts, plant milks aside) set off a flare (0..1): half an hour
-- of nothing, then it builds over half an hour and takes about six hours to
-- fade. While it lasts it holds a little pain (cramps, through
-- DanTraits_PainFloor), food sickness (the vanilla Queasy moodle) and a low
-- mood up to a floor that scales with the flare. The dose is how filling the
-- portion was (a wedge of cheese is about a full flare), or the litres of milk.
--
-- Mod data: lacFlare, lacPending, lacOnset.
-- Console: lactose [units]
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local floorUp = DanTraits_FloorUp
local foodTags = DanTraits_FoodTags

local LAC_HUNGER_FULL   = 15      -- hunger points of dairy in one sitting for a full flare
local LAC_LITRES_FULL   = 0.3     -- litres of milk for a full flare
local LAC_ONSET_MIN     = 30      -- minutes before the first symptoms
local LAC_RAMP_MIN      = 30      -- minutes over which a full dose becomes a full flare
local LAC_DECAY         = 1 / 360 -- per minute: six hours from a full flare to clear
local LAC_DECAY_ASLEEP  = 1.5
local LAC_PAIN_MAX      = 25      -- pain floor at a full flare (0..100)
local LAC_PAIN_RAMP     = 2
local LAC_SICK_MAX      = 35      -- food sickness floor at a full flare (0..100): Queasy
local LAC_SICK_RAMP     = 2
local LAC_UNHAPPY_MAX   = 15
local LAC_UNHAPPY_RAMP  = 1
local LAC_TIER          = { 0.25, 0.6 }
local LAC_FLUID_WORDS   = { "milk", "cream" }             -- a fluid name (lowercase) with one of these in it counts...
local LAC_FLUID_SAFE    = { "coconut", "soy", "almond", "oat" }   -- ...unless it has one of these

local function lacData(player)
    local d = traitData(player)
    d.lacFlare = d.lacFlare or 0
    d.lacPending = d.lacPending or 0
    return d
end

local function tierOf(flare)
    local tier = 0
    for i, threshold in ipairs(LAC_TIER) do if flare >= threshold then tier = i end end
    return tier
end

function DanTraits_IsDairy(item)
    return foodTags(item).dairy == true
end

-- a fluid's name (lowercase, as DanTraits_FluidName gives it) -> whether it is dairy
local function dairyFluid(name)
    if type(name) ~= "string" then return false end
    for _, word in ipairs(LAC_FLUID_SAFE) do
        if string.find(name, word, 1, true) then return false end
    end
    for _, word in ipairs(LAC_FLUID_WORDS) do
        if string.find(name, word, 1, true) then return true end
    end
    return false
end
DanTraits_IsDairyFluid = dairyFluid

-- a dose in full-flare units; the onset clock starts if nothing is brewing
local function addDose(player, units, now)
    if units <= 0 then return false end
    local d = lacData(player)
    d.lacPending = d.lacPending + units
    if now then d.lacOnset = 0 elseif (d.lacOnset or 0) <= 0 and d.lacFlare <= 0 then d.lacOnset = LAC_ONSET_MIN end
    notify(player, "UI_DanTraits_LactoseAte")
    return true
end

function DanTraits_LactoseOnEat(player, item, fraction)
    if not hasTrait(player, "lactose") or not item or not DanTraits_IsDairy(item) then return false end
    local hunger = 0
    pcall(function() hunger = math.abs(item:getHungChange() or 0) * 100 end)
    return addDose(player, hunger * math.max(0, math.min(1, fraction or 1)) / LAC_HUNGER_FULL)
end

DanTraits_AddHook("eat", function(_, player, item, fraction)
    DanTraits_LactoseOnEat(player, item, fraction)
    return nil
end)

DanTraits_AddHook("drink", function(_, player, container, litres)
    if not hasTrait(player, "lactose") or not litres or litres <= 0 then return nil end
    local name = DanTraits_FluidName and DanTraits_FluidName(container)
    if dairyFluid(name) then addDose(player, litres / LAC_LITRES_FULL) end
    return nil
end)

local function updateLactoseMinute(player, d)
    if not hasTrait(player, "lactose") then return end
    d = lacData(player)
    local before = d.lacFlare
    if d.lacPending > 0 and (d.lacOnset or 0) > 0 then
        d.lacOnset = d.lacOnset - 1
    elseif d.lacPending > 0 then
        local step = math.min(d.lacPending, 1 / LAC_RAMP_MIN)
        d.lacPending = d.lacPending - step
        d.lacFlare = math.min(1, d.lacFlare + step)
    else
        d.lacFlare = math.max(0, d.lacFlare - LAC_DECAY * (DanTraits_Asleep(player) and LAC_DECAY_ASLEEP or 1))
    end
    local flare = d.lacFlare
    if tierOf(flare) > tierOf(before) then notify(player, "UI_DanTraits_LactoseTier" .. tierOf(flare)) end
    if flare <= 0 then return end
    DanTraits_PainFloor(player, d, "lactose", flare * LAC_PAIN_MAX, LAC_PAIN_RAMP)
    pcall(function()
        local stats = player:getStats()
        floorUp(stats, CharacterStat.FOOD_SICKNESS, flare * LAC_SICK_MAX, LAC_SICK_RAMP)
        floorUp(stats, CharacterStat.UNHAPPINESS, flare * LAC_UNHAPPY_MAX, LAC_UNHAPPY_RAMP)
    end)
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.lactose = function(player, args)
    addDose(player, tonumber(args[1]) or 1, true)
    return "lactose flare coming: " .. tostring(lacData(player).lacPending)
end

DanTraits_Every("minute", "Lactose", updateLactoseMinute, 40)
