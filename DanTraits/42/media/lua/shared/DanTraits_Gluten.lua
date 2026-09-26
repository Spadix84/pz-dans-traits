-- Dan's Traits: Gluten Intolerance.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

-- Gluten Intolerance ----------------------------------------------------------
-- Wheat in a meal sets off a flare (0..1 in mod data): nothing for a while,
-- then it builds over half an hour and takes most of a day to fade. While it
-- lasts it holds pain, food sickness (the vanilla Queasy moodle) and low mood
-- up to a floor that scales with the flare, so painkillers only buy a little
-- time. The game has no grain tag, so wheat is a name list; the dose is the
-- carbohydrates in the portion eaten, with a hunger-based fallback for foods
-- that carry no nutrition data. Rice, potatoes, corn and fruit are safe.
local GLUTEN_WORDS = {
    "bread", "bagel", "baguette", "croissant", "pasta", "macaroni", "spaghetti", "lasagn", "ramen", "noodle",
    "cereal", "cracker", "cookie", "cake", "pie", "dough", "pancake", "waffle", "sandwich", "burger", "pizza",
    "beer", "biscuit", "muffin", "cupcake", "donut", "pretzel", "flour", "toast", "buns", "steambun", "pastry",
    "tortilla", "burrito", "dumpling", "gingerbread",
}
local GLUTEN_SAFE_PART  = { "crappie", "poppies", "piece", "chips", "cornflour", "rice" }   -- anywhere in the name
local GLUTEN_SAFE_EXACT = { "oatmeal", "oatsraw", "granolabar" }                              -- whole name
local GLUTEN_DOSE_FULL     = 50      -- carbs of wheat in one sitting for a full flare (a loaf is 99, a slice 33)
local GLUTEN_CARBS_PER_HUNGER = 3    -- carbs assumed per hunger point for foods with no nutrition data
local GLUTEN_ONSET_MIN     = 20      -- minutes before the first symptoms
local GLUTEN_RAMP_MIN      = 30      -- minutes over which a full dose becomes a full flare
local GLUTEN_DECAY         = 1 / 600 -- per minute: ten hours from a full flare to clear
local GLUTEN_DECAY_ASLEEP  = 1.5     -- multiplier while asleep
local GLUTEN_PAIN_MAX      = 45      -- pain floor at a full flare (0..100)
local GLUTEN_PAIN_RAMP     = 3       -- per minute towards the floor
local GLUTEN_SICK_MAX      = 55      -- food sickness floor at a full flare (0..100): Queasy, then Nauseous
local GLUTEN_SICK_RAMP     = 2
local GLUTEN_UNHAPPY_MAX   = 25
local GLUTEN_UNHAPPY_RAMP  = 1
local GLUTEN_STRESS_PER_MIN = 0.001  -- at a full flare (0..1 scale)
local GLUTEN_TIER          = { 0.25, 0.5, 0.75 }

local function glutenData(player)
    local d = traitData(player)
    d.gluten = d.gluten or 0
    d.glutenPending = d.glutenPending or 0
    return d
end

local function glutenTier(flare)
    local tier = 0
    for i, threshold in ipairs(GLUTEN_TIER) do
        if flare >= threshold then tier = i end
    end
    return tier
end

function DanTraits_IsWheat(item)
    local ok, name = pcall(function() return string.lower(tostring(item:getType())) end)
    if not ok or not name then return false end
    for _, exact in ipairs(GLUTEN_SAFE_EXACT) do
        if name == exact then return false end
    end
    for _, part in ipairs(GLUTEN_SAFE_PART) do
        if name:find(part, 1, true) then return false end
    end
    for _, word in ipairs(GLUTEN_WORDS) do
        if name:find(word, 1, true) then return true end
    end
    return false
end

-- carbs in the portion about to be eaten
local function glutenDose(item, fraction)
    local carbs = 0
    pcall(function() carbs = item:getCarbohydrates() or 0 end)
    if carbs <= 0 then
        local hunger = 0
        pcall(function() hunger = math.abs(item:getHungChange() or 0) * 100 end)
        carbs = hunger * GLUTEN_CARBS_PER_HUNGER
    end
    return carbs * math.max(0, math.min(1, fraction or 1))
end

-- called from the core eat hook with the portion actually eaten
-- a dose straight in carbs (the dashboard's gluten command); now = skip the onset wait
function DanTraits_GlutenDose(player, carbs, now)
    local d = glutenData(player)
    d.glutenPending = d.glutenPending + (carbs or GLUTEN_DOSE_FULL) / GLUTEN_DOSE_FULL
    if now then d.glutenOnset = 0 elseif (d.glutenOnset or 0) <= 0 and d.gluten <= 0 then d.glutenOnset = GLUTEN_ONSET_MIN end
    notify(player, "UI_DanTraits_GlutenAte")
end

function DanTraits_GlutenOnEat(player, item, fraction)
    if not hasTrait(player, "gluten") then return false end
    if not DanTraits_IsWheat(item) then return false end
    local dose = glutenDose(item, fraction)
    if dose <= 0 then return false end
    local d = glutenData(player)
    d.glutenPending = d.glutenPending + dose / GLUTEN_DOSE_FULL
    if (d.glutenOnset or 0) <= 0 and d.gluten <= 0 then d.glutenOnset = GLUTEN_ONSET_MIN end
    notify(player, "UI_DanTraits_GlutenAte")
    return true
end

local function updateGlutenMinute(player, d)
    if not hasTrait(player, "gluten") then return end
    d = glutenData(player)
    local asleep = false
    pcall(function() asleep = player:isAsleep() end)
    local before = d.gluten

    if d.glutenPending > 0 and (d.glutenOnset or 0) > 0 then
        d.glutenOnset = d.glutenOnset - 1                 -- waiting for it to hit
    elseif d.glutenPending > 0 then
        local step = math.min(d.glutenPending, 1 / GLUTEN_RAMP_MIN)
        d.glutenPending = d.glutenPending - step
        d.gluten = math.min(1, d.gluten + step)
        if d.gluten > 1 - 1e-6 then d.gluten = 1 end
    else
        d.gluten = math.max(0, d.gluten - GLUTEN_DECAY * (asleep and GLUTEN_DECAY_ASLEEP or 1))
    end

    local flare = d.gluten
    local tierBefore, tierAfter = glutenTier(before), glutenTier(flare)
    if tierAfter > tierBefore then notify(player, "UI_DanTraits_GlutenTier" .. tierAfter) end
    if flare <= 0 then return end

    pcall(function()
        local stats = player:getStats()
        local function floorUp(stat, target, ramp)
            local value = stats:get(stat) or 0
            if value < target then stats:set(stat, math.min(100, value + math.min(ramp, target - value))) end
        end
        floorUp(CharacterStat.PAIN, flare * GLUTEN_PAIN_MAX, GLUTEN_PAIN_RAMP)
        floorUp(CharacterStat.FOOD_SICKNESS, flare * GLUTEN_SICK_MAX, GLUTEN_SICK_RAMP)
        floorUp(CharacterStat.UNHAPPINESS, flare * GLUTEN_UNHAPPY_MAX, GLUTEN_UNHAPPY_RAMP)
        stats:set(CharacterStat.STRESS, math.min(1, (stats:get(CharacterStat.STRESS) or 0) + flare * GLUTEN_STRESS_PER_MIN))
    end)
end

local function onGlutenMinute()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    updateGlutenMinute(player, traitData(player))
end
Events.EveryOneMinute.Add(onGlutenMinute)
