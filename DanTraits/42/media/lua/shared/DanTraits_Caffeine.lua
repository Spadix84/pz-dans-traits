-- Project Zomboid Vitality Project: Caffeine Dependent.
-- Caffeine in the body is tracked as a level that halves every five hours.
-- Coffee, tea, cola, coffee liqueur and hot chocolate add to it through the
-- drink hook by fluid and litres; instant coffee, chocolate-covered coffee
-- beans, chocolate, cocoa and tea bags through the eat hook; the game's
-- vitamin pills (pictured as caffeine pills) through the pill hook (the food
-- amounts are the caffeine tag of DanTraits_Food.lua; fluids and pills stay here). Once
-- the level has sat under CAF_SATED for twelve hours withdrawal starts: a
-- headache (a DanTraits_PainFloor floor), tiredness, low mood and creeping stress, at full strength from
-- thirty hours dry, and then fading out over the rest of the week as the
-- habit breaks. Any real dose resets the clock. Smoking speeds up the
-- half-life (the "caffeineClearance" hook, DanTraits_Smoker.lua). Every dose, trait or not,
-- is also passed to the sleep system: caffeine makes light wake you.
-- Migraines read the withdrawal (DanTraits_CaffeineWithdrawalOf).
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local foodTags = DanTraits_FoodTags

local CAF_HALF_LIFE_H   = 5       -- hours for the level to halve
local CAF_SATED         = 60      -- level above which the dry clock does not run
local CAF_DOSE_MIN      = 40      -- a dose smaller than this does not reset the clock
local CAF_ONSET_H       = 12      -- dry hours before withdrawal
local CAF_FULL_H        = 30      -- dry hours at full strength
local CAF_FADE_FROM_H   = 72      -- from here the habit breaks...
local CAF_FADE_TO_H     = 168     -- ...and by here it is gone
local CAF_PAIN          = 15      -- pain floor at full withdrawal (lowered by the body's pain reduction, see DanTraits_PainFloor)
local CAF_MOOD          = 15      -- unhappiness floor
local CAF_RAMP          = 1
local CAF_FATIGUE       = 0.0006  -- per minute at full withdrawal
local CAF_STRESS        = 0.0002

-- per litre of fluid
local CAF_FLUID = {
    coffee = 400, tea = 150, cola = 100, coladiet = 100, coffeeliqueur = 100, milkchocolate = 20, sodapop = 40,
}
local CAF_PILL = { pillsvitamins = 200 }

local DECAY = 0.5 ^ (1 / (CAF_HALF_LIFE_H * 60))

local function cafData(player)
    local d = traitData(player)
    d.cafLevel = d.cafLevel or 0
    d.cafDryHours = d.cafDryHours or 0
    return d
end

local function dose(player, amount, what)
    if not player or not amount or amount <= 0 then return false end
    -- anyone's sleep feels it (DanTraits_Sleep.lua); the habit is the trait's
    if DanTraits_SleepOnCaffeine then pcall(DanTraits_SleepOnCaffeine, player, amount) end
    if not hasTrait(player, "caffeine") then return false end
    local d = cafData(player)
    d.cafLevel = d.cafLevel + amount
    d.cafLastDose = what
    if amount >= CAF_DOSE_MIN then
        d.cafDryHours = 0
        if d.cafWithdrawing then
            d.cafWithdrawing = false
            DanTraits_NotifyGood(player, "UI_DanTraits_CaffeineSated")
        end
    end
    return true
end
DanTraits_CaffeineDose = dose

-- 0..1 withdrawal strength from hours dry
local function withdrawal(hours)
    if hours < CAF_ONSET_H then return 0 end
    if hours < CAF_FULL_H then return (hours - CAF_ONSET_H) / (CAF_FULL_H - CAF_ONSET_H) end
    if hours < CAF_FADE_FROM_H then return 1 end
    if hours < CAF_FADE_TO_H then return 1 - (hours - CAF_FADE_FROM_H) / (CAF_FADE_TO_H - CAF_FADE_FROM_H) end
    return 0
end
DanTraits_CaffeineWithdrawal = withdrawal

-- 0..1 withdrawal strength of this character now (0 without the trait); read by Migraine
function DanTraits_CaffeineWithdrawalOf(player)
    if not player or not hasTrait(player, "caffeine") then return 0 end
    local d = player:getModData().DanTraits
    return (d and d.cafWithdraw) or 0
end

local floorUp = DanTraits_FloorUp

local function updateCaffeineMinute(player, d)
    if not hasTrait(player, "caffeine") then return end
    d = cafData(player)
    -- smokers clear it faster (DanTraits_Smoker.lua)
    d.cafLevel = d.cafLevel * DECAY ^ DanTraits_RunHooks("caffeineClearance", 1, player)
    if d.cafLevel < 0.5 then d.cafLevel = 0 end
    if d.cafLevel >= CAF_SATED then
        d.cafDryHours = 0
        d.cafWithdraw = 0
        return
    end
    d.cafDryHours = d.cafDryHours + 1 / 60
    local w = withdrawal(d.cafDryHours)
    d.cafWithdraw = w
    if w > 0 and not d.cafWithdrawing then
        d.cafWithdrawing = true
        notify(player, "UI_DanTraits_CaffeineCraving")
    elseif w <= 0 and d.cafWithdrawing and d.cafDryHours >= CAF_FADE_TO_H then
        d.cafWithdrawing = false
        DanTraits_NotifyGood(player, "UI_DanTraits_CaffeineBroken")
    end
    if w <= 0 then return end
    local asleep = DanTraits_Asleep(player)
    if asleep then return end
    pcall(function()
        local stats = player:getStats()
        DanTraits_PainFloor(player, d, "caffeine", CAF_PAIN * w, CAF_RAMP)
        floorUp(stats, CharacterStat.UNHAPPINESS, CAF_MOOD * w, CAF_RAMP)
        stats:set(CharacterStat.FATIGUE, math.min(1, (stats:get(CharacterStat.FATIGUE) or 0) + CAF_FATIGUE * w))
        stats:set(CharacterStat.STRESS, math.min(1, (stats:get(CharacterStat.STRESS) or 0) + CAF_STRESS * w))
    end)
end
DanTraits_updateCaffeineMinute = updateCaffeineMinute

-- intake -------------------------------------------------------------------
local function fluidName(container)
    local name = nil
    pcall(function()
        local fluid = container:getPrimaryFluid()
        if fluid then name = string.lower(tostring(fluid:getFluidTypeString())) end
    end)
    return name
end

local function fluidRatio(container)
    local ratio = 1
    pcall(function()
        local fluid = container:getPrimaryFluid()
        if fluid then ratio = container:getRatioForFluid(fluid) or 1 end
    end)
    return ratio
end

DanTraits_AddHook("drink", function(_, player, container, litres)
    if not container or not litres or litres <= 0 then return nil end
    local name = fluidName(container)
    local perLitre = name and CAF_FLUID[name]
    if not perLitre then return nil end
    dose(player, perLitre * litres * fluidRatio(container), name)
    return nil
end)

local function onEat(player, item, fraction)
    if not player or not item then return false end
    local name = ""
    pcall(function() name = string.lower(tostring(item:getType() or "")) end)
    local amount = foodTags(item).caffeine   -- per whole item: instant coffee, beans, cocoa, tea bags, chocolate
    if amount <= 0 then return false end
    return dose(player, amount * math.max(0, math.min(1, fraction or 1)), name)
end
DanTraits_CaffeineOnEat = onEat
DanTraits_AddHook("eat", function(_, player, item, fraction) onEat(player, item, fraction) return nil end)

DanTraits_AddHook("pill", function(_, player, kind)
    local amount = CAF_PILL[string.lower(tostring(kind or ""))]
    if amount then dose(player, amount, kind) end
    return nil
end)

DanTraits_Every("minute", "Caffeine", updateCaffeineMinute, 40)
