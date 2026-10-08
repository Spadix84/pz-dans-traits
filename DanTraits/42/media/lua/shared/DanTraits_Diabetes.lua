-- Project Zomboid Vitality Project: Diabetes.
-- Depends on the helpers DanTraits.lua exports.
require "DanTraits"
require "DanTraits_Meds"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local floorUp = DanTraits_FloorUp
local statAdd = DanTraits_StatAdd
local foodTags = DanTraits_FoodTags
local DRINK = DanTraits_DRINK           -- the named thresholds (DanTraits_Util.lua)
local intoxOf = DanTraits_Intoxication  -- 0..1 intoxication (the raw stat is 0..100)

-- Diabetes (Type 1 "diabetes1", Type 2 "diabetes2") -------------------------
-- A hidden blood sugar value (mg/dL) lives in mod data. Carbohydrates in
-- what you eat and drink push it up, absorbed fast (sugar, candy, soda,
-- fruit) or slow (bread, pasta, potatoes). Adrenaline (panic) pushes it up
-- too. Running, exertion and sleep pull it down, alcohol pulls it down for
-- as long as you are drunk, and above 180 the kidneys dump sugar, which is
-- what makes you thirsty. Type 1: the body makes no insulin, so sugar creeps
-- up on its own and only injected insulin brings it down. Type 2: the body's
-- own insulin still works, but with a resistance set by body weight, eased
-- by regular exercise and metformin; the heavier you are, the higher sugar
-- settles and the longer a meal takes to clear. Either type can inject
-- insulin, and either type can go low from it. Symptoms are deliberately
-- vague: the same "can't focus" shows up high or low. A glucose meter and
-- test strips give a number.
-- At the worst low (under 40) there is also a small chance each minute of
-- blacking out for 5 to 20 game minutes (a shallow faint: a wound wakes you),
-- not more than once in half an hour; the health drain carries on meanwhile.
-- Sugar above 180 also feeds wound infection and
-- slows healing (the Infection file's hazard and growth hooks).
-- Drinks reach the character through ISDrinkFluidAction.updateEat, wrapped
-- here through DanTraits_Wrap with the tag "drink-intake" (carbohydrates, the
-- Vitality drink hook and the `drink` hook); Alcohol adds its own layer to the
-- same method and the two chain.
local DIA_START             = 110
local DIA_MIN, DIA_MAX      = 20, 600
local DIA_CARB_MGDL         = 4.0     -- mg/dL per gram of carbohydrate absorbed with nothing to meet it
local DIA_FAST_RATE         = 2 / 30  -- per minute, fraction of pending fast carbs absorbed (most of it inside half an hour)
local DIA_SLOW_RATE         = 2 / 120 -- per minute, slow carbs (most of it inside two hours)
local DIA_T1_DRIFT          = 0.17    -- per minute, creep with no insulin on board (about 10 an hour)
local DIA_T2_SETPOINT       = 100     -- where a Type 2 body settles with no resistance
local DIA_T2_SETPOINT_RES   = 120     -- added to the setpoint at full resistance
local DIA_T2_RATE           = 0.012   -- per minute, fraction of the gap to the setpoint the body closes at no resistance
local DIA_T2_RATE_RES_CUT   = 0.6     -- that rate x (1 - this x resistance)
local DIA_T2_WEIGHT_LOW     = 75      -- kg: no resistance at or below
local DIA_T2_WEIGHT_HIGH    = 110     -- kg: full resistance at or above (before exercise and pills)
local DIA_T2_EXERCISE_CUT   = 0.25    -- resistance removed at full exercise regularity
local DIA_T2_PILL_CUT       = 0.35    -- resistance removed by metformin, fully built up (DanTraits_Meds.lua: a pill a day, two days to build)
local DIA_RENAL_ABOVE       = 180
local DIA_RENAL_RATE        = 0.002   -- per minute x (glucose - 180)
local DIA_EXERCISE_DROP     = 0.5     -- per minute while running, sprinting or exerted
local DIA_EXERT_ENDURANCE   = 0.6     -- "exerted" means endurance under this
local DIA_SLEEP_DROP        = 0.05    -- per minute asleep
local DIA_PANIC_MIN         = 30      -- panic below this (out of 100) does nothing
local DIA_PANIC_RISE        = 0.15    -- per minute at full panic, scaling linearly from the minimum (was 0.4: too fast in play)
local DIA_ALCOHOL_DROP      = 0.35    -- per minute while intoxicated: the liver is busy with the drink
local DIA_INHALER_RISE      = 15      -- a puff of a rescue inhaler
local DIA_DOSE_MGDL         = 50      -- one pen dose lowers blood sugar by this much in total
local DIA_INSULIN_ONSET     = 15      -- minutes before a dose starts working
local DIA_INSULIN_PEAK      = 75      -- minutes to peak action
local DIA_INSULIN_END       = 240     -- minutes until it is spent
local DIA_INSULIN_RES_CUT   = 0.5     -- insulin effect x (1 - this x resistance) for Type 2
local DIA_INSULIN_FIT_BONUS = 0.2     -- insulin effect x (1 + this x exercise regularity)
local DIA_LOW               = { 70, 55, 40 }
local DIA_HIGH              = { 180, 250, 350 }
local DIA_LOW_FUMBLE        = { 4, 8, 14 }        -- percent added to every weapon swing (see Fumbler)
local DIA_LOW_END_DRAIN     = { 0, 0.03, 0.08 }   -- endurance per minute
local DIA_LOW_FATIGUE       = { 0.001, 0.003, 0.005 }
local DIA_LOW_PANIC         = { 1, 2, 4 }         -- per minute (out of 100): adrenaline, which also pushes sugar back up
local DIA_LOW_UNHAPPY_FLOOR = { 10, 25, 40 }
local DIA_LOW_HP_DRAIN      = 0.5                 -- per minute at the worst tier, down to the floor
local DIA_LOW_FAINT         = 0.04                -- per minute at the worst tier: a chance of blacking out
local DIA_LOW_FAINT_MIN     = { 5, 20 }           -- game minutes out (shallow: a new wound wakes you)
local DIA_LOW_FAINT_GAP     = 30                  -- minutes between blackouts (d.diaFaintGap)
local DIA_HIGH_THIRST       = { 0.002, 0.004, 0.006 }  -- per minute (0..1)
local DIA_HIGH_FATIGUE      = { 0.0005, 0.0015, 0.003 }
local DIA_HIGH_UNHAPPY_FLOOR = { 0, 15, 30 }
local DIA_HIGH_SICK_FLOOR   = { 0, 20, 50 }       -- food sickness (Queasy, then Nauseous)
local DIA_HIGH_HP_DRAIN     = 0.3                 -- per minute at the worst tier...
local DIA_HIGH_DRAIN_AFTER  = 2                   -- ...once this many hours have been spent up there (d.diaKetoHours):
                                                  -- a spike after a meal costs nothing, hours of it do (2026-10-08)
local DIA_FEVER_RISE        = 0.1                 -- mg/dL per minute at full fever: illness raises blood sugar (sick day rules)
local DIA_HEALTH_FLOOR      = 15                  -- percent: symptoms stop short of this...
local DIA_KETO_HOURS        = 24                  -- ...until you have spent this long above the top threshold, then the floor is gone
local DIA_MDD_UNHAPPY_MULT  = 1.5                 -- high-sugar mood floor during a depressive episode
local DIA_HALO_MIN          = { 10, 5, 3 }        -- minutes between symptom messages by tier, plus up to as many again
local DIA_MOODLE_TIER       = { 0.3, 0.6, 0.9 }   -- the BloodSugar moodle: value tier / 3, one moodle level per tier
local DIA_STAT_RAMP         = 2                   -- per minute towards a mood/sickness floor
local DIA_INF_HAZARD       = 1.0                 -- wound infection chance x (1 + this x t), t = 0 at DIA_HIGH[1] up to 1 at DIA_HIGH[3]
local DIA_INF_GROWTH       = 0.5                 -- infection climb x (1 + this x t): high sugar feeds it and slows healing

local INSULIN_ITEM   = "DanTraits.InsulinPen"
local METER_ITEM     = "DanTraits.GlucoseMeter"
local STRIPS_ITEM    = "DanTraits.TestStrips"
local METFORMIN_ITEM = "DanTraits.Metformin"

local function diaHas(player)
    return hasTrait(player, "diabetes1") or hasTrait(player, "diabetes2")
end
DanTraits_IsDiabetic = diaHas

local function diaData(player)
    local d = traitData(player)
    d.glucose = d.glucose or DIA_START
    d.diaFast = d.diaFast or 0
    d.diaSlow = d.diaSlow or 0
    d.diaInsulin = d.diaInsulin or {}
    d.diaKetoHours = d.diaKetoHours or 0
    return d
end

local function diaClamp(g) return math.max(DIA_MIN, math.min(DIA_MAX, g)) end

-- foods whose sugar hits fast (the fastCarb tag of DanTraits_Food.lua); everything else with carbohydrates is slow
function DanTraits_IsFastCarb(item)
    return foodTags(item).fastCarb == true
end

-- 0..1 insulin resistance for Type 2 (always 0 for Type 1)
local function diaResistance(player, d)
    if not hasTrait(player, "diabetes2") then return 0 end
    local weight = 80
    pcall(function() weight = player:getNutrition():getWeight() or weight end)
    local res = (weight - DIA_T2_WEIGHT_LOW) / (DIA_T2_WEIGHT_HIGH - DIA_T2_WEIGHT_LOW)
    res = res - DIA_T2_EXERCISE_CUT * (DanTraits_MddRegularity and DanTraits_MddRegularity(player) or 0)
    if DanTraits_MedEffect then res = res - DIA_T2_PILL_CUT * DanTraits_MedEffect(player, "metformin") end
    if DanTraits_VitalityDiaResistance then res = res + DanTraits_VitalityDiaResistance(player) end   -- fit: lower, run down: higher
    res = DanTraits_RunHooks("diaResistance", res, player, d)   -- Age: higher in the 40s, lower in the 20s
    return math.max(0, math.min(1, res))
end
DanTraits_DiaResistance = function(player) return diaResistance(player, diaData(player)) end

-- fraction of a dose delivered in minute t (triangle: onset, peak, spent)
local function diaInsulinProfile(t)
    if t < DIA_INSULIN_ONSET or t >= DIA_INSULIN_END then return 0 end
    local area = (DIA_INSULIN_END - DIA_INSULIN_ONSET) / 2
    if t < DIA_INSULIN_PEAK then
        return (t - DIA_INSULIN_ONSET) / (DIA_INSULIN_PEAK - DIA_INSULIN_ONSET) / area
    end
    return (DIA_INSULIN_END - t) / (DIA_INSULIN_END - DIA_INSULIN_PEAK) / area
end

-- how hard a dose hits: resistance blunts it, fitness and Vitality sharpen it
local function diaSensitivity(player, res, fitness)
    local k = (1 - DIA_INSULIN_RES_CUT * res) * (1 + DIA_INSULIN_FIT_BONUS * fitness)
    if DanTraits_VitalityDiaSensitivity then k = k * DanTraits_VitalityDiaSensitivity(player) end
    return k
end

-- called from the eat hook with the portion actually eaten
function DanTraits_DiaOnEat(player, item, fraction)
    if not diaHas(player) then return false end
    local carbs = 0
    pcall(function() carbs = item:getCarbohydrates() or 0 end)
    carbs = carbs * math.max(0, math.min(1, fraction or 1))
    if carbs <= 0 then return false end
    local d = diaData(player)
    if DanTraits_IsFastCarb(item) then d.diaFast = d.diaFast + carbs else d.diaSlow = d.diaSlow + carbs end
    return true
end

-- called from the drink hook with the carbohydrates in what was swallowed (drinks are all fast)
function DanTraits_DiaOnDrink(player, carbs)
    if not diaHas(player) or not carbs or carbs <= 0 then return false end
    local d = diaData(player)
    d.diaFast = d.diaFast + carbs
    return true
end

function DanTraits_DiaOnInhaler(player)
    if not diaHas(player) then return end
    local d = diaData(player)
    d.glucose = diaClamp(d.glucose + DIA_INHALER_RISE)
end

-- called by the injection action; returns the doses actually injected
function DanTraits_DiaInject(player, doses)
    if not player or not diaHas(player) then return 0 end
    doses = math.max(0, math.floor(doses or 1))
    if doses == 0 then return 0 end
    local d = diaData(player)
    table.insert(d.diaInsulin, { dose = doses, t = 0 })
    return doses
end

-- called by the metformin action
-- (the medication system keeps the level; true when it does something for this character)
function DanTraits_DiaOnPill(player)
    if not player then return false end
    if DanTraits_MedTake then DanTraits_MedTake(player, "metformin", 1) end
    return diaHas(player)
end

-- called by the meter action: the number, and whether it is out of range
function DanTraits_DiaRead(player)
    if not player then return nil end
    local g
    if diaHas(player) then g = diaData(player).glucose else g = 85 + ZombRand(30) end
    g = math.floor(g + 0.5)
    return g, (g < DIA_LOW[1] or g >= DIA_HIGH[1])
end

-- Knowing your insulin --------------------------------------------------------
-- What a Type 1 character can work out about insulin, by First Aid, or from
-- the magazine Living With Type 1 (DanTraits.InsulinMag, which teaches the
-- knowledge flag DIA_KNOW_RECIPE the way vanilla's Herbalist magazine does):
--   level 1 (First Aid 3-5): a food's or a sugary drink's tooltip says whether its sugar hits fast
--     or slowly, and gives a wide range of doses to cover it.
--   level 2 (First Aid 6-8): a narrow range; the meter adds how much insulin is
--     still working.
--   level 3 (First Aid 9-10, or the magazine at any level): the exact doses
--     for this body (fitness and Vitality counted), and the meter adds what it
--     takes to bring sugar back to 110: more doses, or grams of fast sugar.
-- Doses to cover a food: carbohydrates x DIA_CARB_MGDL / (DIA_DOSE_MGDL x
-- sensitivity), about one dose per 12.5 g. Type 2 is not told doses: its own
-- insulin covers most of a meal, so the Type 1 sum would overdose it.
local DIA_KNOW_FA     = { 3, 6, 9 }   -- First Aid for levels 1, 2, 3
local DIA_KNOW_RECIPE = "DanTraitsInsulinDosing"
local DIA_KNOW_RANGE  = { 0.6, 0.8 }  -- levels 1 and 2: doses x this, rounded down, to doses x (2 - this), rounded up
local DIA_TARGET      = 110           -- the meter's correction aims here

-- isRecipeActuallyKnown, not isRecipeKnown: the latter answers true for any
-- name the game has no recipe of that name for (found in play 2026-10-08)
local function diaKnowsDosing(player)
    local known = false
    pcall(function() known = player:isRecipeActuallyKnown(DIA_KNOW_RECIPE) end)
    return known == true
end

-- 0 to 3; 0 for anyone without Type 1
function DanTraits_DiaKnowledge(player)
    if not player or not hasTrait(player, "diabetes1") then return 0 end
    if diaKnowsDosing(player) then return 3 end
    local fa = 0
    pcall(function() fa = player:getPerkLevel(Perks.Doctor) or 0 end)
    local level = 0
    for i, need in ipairs(DIA_KNOW_FA) do if fa >= need then level = i end end
    return level
end

local function diaFitness(player)
    return DanTraits_MddRegularity and DanTraits_MddRegularity(player) or 0
end

-- what an item would put in: carbohydrates, whether they hit fast, and
-- whether it is something to ask at all. A food counts by its own
-- carbohydrates (as DanTraits_DiaOnEat does); a drink in a fluid container
-- (a bottle of pop, a carton of juice, a mug of milk) by everything in the
-- container, all of it fast (as the drink hook counts it). Water, fuel and
-- anything else with no sugar in it is not asked about.
local function diaItemCarbs(item)
    local isFood = false
    pcall(function() isFood = instanceof(item, "Food") end)
    if isFood then
        local carbs = 0
        pcall(function() carbs = item:getCarbohydrates() or 0 end)
        return carbs, carbs > 0 and DanTraits_IsFastCarb(item), true
    end
    local carbs = 0
    pcall(function()
        local fc = item:getFluidContainer()
        if fc and not fc:isEmpty() then carbs = fc:getProperties():getCarbohydrates() or 0 end
    end)
    return carbs, true, carbs > 0
end

-- doses a food or a drink takes for this Type 1 body, and whether its sugar is fast
function DanTraits_DiaFoodDoses(player, item)
    local carbs, fast = diaItemCarbs(item)
    if carbs <= 0 then return 0, false end
    local k = diaSensitivity(player, 0, diaFitness(player))
    return carbs * DIA_CARB_MGDL / (DIA_DOSE_MGDL * k), fast
end

-- where sugar would peak over the next four hours if this food went in now
-- with its doses: the model's own minute steps for carbohydrates, insulin
-- (what is on board as well), Type 1's creep and the kidneys, nothing else
-- (no exercise, sleep or drink). The doses are given for an ordinary body, so
-- the sensitivity cancels out of the insulin step.
local DIA_SIM_MINUTES = DIA_INSULIN_END
local function diaPeakIfDosed(d, carbs, fast, doses)
    local g = d.glucose
    local f = d.diaFast + (fast and carbs or 0)
    local s = d.diaSlow + (fast and 0 or carbs)
    local shots = {}
    for _, shot in ipairs(d.diaInsulin or {}) do shots[#shots + 1] = { dose = shot.dose, t = shot.t } end
    shots[#shots + 1] = { dose = doses, t = 0 }
    local peak = g
    for _ = 1, DIA_SIM_MINUTES do
        local a, b = f * DIA_FAST_RATE, s * DIA_SLOW_RATE
        f, s = f - a, s - b
        g = g + (a + b) * DIA_CARB_MGDL + DIA_T1_DRIFT
        for _, shot in ipairs(shots) do
            g = g - shot.dose * DIA_DOSE_MGDL * diaInsulinProfile(shot.t)
            shot.t = shot.t + 1
        end
        if g > DIA_RENAL_ABOVE then g = g - (g - DIA_RENAL_ABOVE) * DIA_RENAL_RATE end
        if g > peak then peak = g end
    end
    return peak
end

-- nil if the whole thing is safe to eat dosed, else how many parts to eat it
-- in (2 to 4), or 5 for "a little at a time"
function DanTraits_DiaParts(player, item)
    local carbs, fast = diaItemCarbs(item)
    if carbs <= 0 then return nil end
    local d = diaData(player)
    local doses = carbs * DIA_CARB_MGDL / DIA_DOSE_MGDL
    if diaPeakIfDosed(d, carbs, fast, doses) < DIA_HIGH[3] then return nil end
    for n = 2, 4 do
        if diaPeakIfDosed(d, carbs / n, fast, doses / n) < DIA_HIGH[3] then return n end
    end
    return 5
end

local function oneDecimal(x) return string.format("%.1f", math.floor(x * 10 + 0.5) / 10) end

-- the lines a food's or a drink's tooltip gets (already translated), or nil
function DanTraits_DiaFoodLines(player, item)
    local level = DanTraits_DiaKnowledge(player)
    if level == 0 or not item then return nil end
    local _, _, ask = diaItemCarbs(item)
    if not ask then return nil end
    local doses, fast = DanTraits_DiaFoodDoses(player, item)
    if doses <= 0 then return { getText("Tooltip_DanTraits_DiaNone") } end
    local lines = { getText(fast and "Tooltip_DanTraits_DiaFast" or "Tooltip_DanTraits_DiaSlow") }
    if level >= 3 then
        lines[2] = getText("Tooltip_DanTraits_DiaExact", oneDecimal(doses))
        -- too much sugar at once lands before the insulin can catch it: say how to split it
        local parts = DanTraits_DiaParts(player, item)
        if parts then lines[3] = getText("Tooltip_DanTraits_DiaParts" .. parts) end
    else
        -- the ranges use an ordinary body, not this one: only level 3 knows its own
        local base = doses * diaSensitivity(player, 0, diaFitness(player))
        local k = DIA_KNOW_RANGE[level]
        local lo = math.max(0, math.floor(base * k))
        local hi = math.max(lo + 1, math.ceil(base * (2 - k)))
        lines[2] = getText("Tooltip_DanTraits_DiaRange", lo, hi)
    end
    return lines
end

-- doses still to come from what was injected (the same minute steps the model takes)
local function diaInsulinLeft(d)
    local left = 0
    for _, shot in ipairs(d.diaInsulin or {}) do
        for t = math.max(0, shot.t), DIA_INSULIN_END - 1 do left = left + shot.dose * diaInsulinProfile(t) end
    end
    return left
end
DanTraits_DiaInsulinLeft = function(player) return diaInsulinLeft(diaData(player)) end

-- the meter's extra lines: { key, arg } pairs, good = true when nothing needs doing
function DanTraits_DiaMeterAdvice(player, g)
    local level = DanTraits_DiaKnowledge(player)
    if level < 2 then return {} end
    local d = diaData(player)
    local onBoard = diaInsulinLeft(d)
    local out = { { "UI_DanTraits_DiaOnBoard", oneDecimal(onBoard) } }
    if level < 3 then return out end
    local k = diaSensitivity(player, 0, diaFitness(player))
    -- where sugar is heading: now, plus food still going in, minus insulin still working
    local heading = g + (d.diaFast + d.diaSlow) * DIA_CARB_MGDL - onBoard * DIA_DOSE_MGDL * k
    local gap = heading - DIA_TARGET
    if gap >= DIA_DOSE_MGDL * k * 0.5 then
        out[#out + 1] = { "UI_DanTraits_DiaCorrect", math.floor(gap / (DIA_DOSE_MGDL * k) + 0.5) }
    elseif gap <= -DIA_CARB_MGDL * 5 then
        out[#out + 1] = { "UI_DanTraits_DiaEat", math.floor(-gap / DIA_CARB_MGDL / 5 + 0.5) * 5 }
    else
        out[#out + 1] = { "UI_DanTraits_DiaSteady", nil, true }
    end
    return out
end

-- The meter remembers its last reading, for its tooltip: the number, when,
-- and the advice it gave then (as text keys, so it is said in the reader's
-- language; marked as of then, because insulin on board goes stale).
-- Item mod data DanTraitsLast = { g, h (world-age hours), advice = { {key, arg, good} } }.
function DanTraits_DiaMeterRecord(item, value, advice)
    if not item or not value then return end
    pcall(function()
        local h = getGameTime():getWorldAgeHours()
        local keep = {}
        for i, line in ipairs(advice or {}) do keep[i] = { line[1], line[2], line[3] == true } end
        item:getModData().DanTraitsLast = { g = value, h = h, advice = keep }
    end)
end

-- the meter's tooltip lines (already translated), or nil before its first reading
function DanTraits_DiaMeterLines(item)
    if not item or not DanTraits_IsMeter(item) then return nil end
    local last
    pcall(function() last = item:getModData().DanTraitsLast end)
    if type(last) ~= "table" or not last.g then return nil end
    local ago = 0
    pcall(function() ago = math.max(0, getGameTime():getWorldAgeHours() - (last.h or 0)) end)
    local line
    if ago < 1 then line = getText("Tooltip_DanTraits_MeterLastMin", last.g, math.floor(ago * 60 + 0.5))
    elseif ago < 48 then line = getText("Tooltip_DanTraits_MeterLastHours", last.g, math.floor(ago + 0.5))
    else line = getText("Tooltip_DanTraits_MeterLastDays", last.g, math.floor(ago / 24 + 0.5)) end
    local lines = { line }
    for _, a in ipairs(last.advice or {}) do
        if a[2] ~= nil then lines[#lines + 1] = getText(a[1], a[2]) else lines[#lines + 1] = getText(a[1]) end
    end
    return lines
end

local function diaTier(g)
    local low, high = 0, 0
    for i, threshold in ipairs(DIA_LOW) do if g < threshold then low = i end end
    for i, threshold in ipairs(DIA_HIGH) do if g >= threshold then high = i end end
    return low, high
end
DanTraits_DiaTier = diaTier

-- vague on purpose: three of the six messages are shared between low and high
local function diaHalo(player, d, low, high)
    local tier = math.max(low, high)
    if tier == 0 then d.diaHaloIn = nil; return end
    local drunk = false
    pcall(function() drunk = intoxOf(player) > DRINK.tipsy end)
    if drunk then return end   -- too drunk to notice
    d.diaHaloIn = (d.diaHaloIn or (DIA_HALO_MIN[tier] + ZombRand(DIA_HALO_MIN[tier]))) - 1
    if d.diaHaloIn > 0 then return end
    d.diaHaloIn = DIA_HALO_MIN[tier] + ZombRand(DIA_HALO_MIN[tier])
    local prefix = low > 0 and "UI_DanTraits_DiaLow" or "UI_DanTraits_DiaHigh"
    local n = 6
    if tier >= 3 then n = 7 end   -- the seventh message is the one that gives it away
    notify(player, prefix .. (ZombRand(n) + 1))
end

-- the BloodSugar moodle: the worse of the two tiers, high and low alike, so
-- it tells you something is wrong, not which way (that is the meter's job).
-- Hidden while drunk, like the messages.
local function diaMoodle(player, d, low, high)
    local tier = math.max(low, high)
    if tier > 0 then
        local drunk = false
        pcall(function() drunk = intoxOf(player) > DRINK.tipsy end)
        if drunk then tier = 0 end
    end
    if tier == 0 and not d.diaMoodle then return end
    d.diaMoodle = tier > 0 or nil
    DanTraits_BadMoodle(player, "BloodSugar", tier / 3, DIA_MOODLE_TIER)
end

-- a bad low can put you on the floor (DanTraits_Faint.lua); glucose keeps falling while out.
-- A refused faint (already out) does not spend the gap.
local function diaBlackout(player, d)
    if not DanTraits_PassOut or (d.diaFaintGap or 0) > 0 or not DanTraits_Roll(DIA_LOW_FAINT) then return end
    if DanTraits_PassOut(player, DanTraits_RandRange(DIA_LOW_FAINT_MIN[1], DIA_LOW_FAINT_MIN[2]), "UI_DanTraits_DiaBlackout") then
        d.diaFaintGap = DIA_LOW_FAINT_GAP
    end
end

local function updateDiabetesMinute(player, d)
    if not diaHas(player) then
        if d and d.diaMoodle then diaMoodle(player, d, 0, 0) end
        return
    end
    d = diaData(player)
    local stats = player:getStats()
    local g = d.glucose
    local asleep, moving, drunk, endurance, panic = false, false, false, 1, 0
    asleep = DanTraits_Asleep(player)
    pcall(function() moving = player:isSprinting() or player:isRunning() end)
    pcall(function() drunk = intoxOf(player) > DRINK.tipsy end)
    pcall(function() endurance = stats:get(CharacterStat.ENDURANCE) or 1 end)
    pcall(function() panic = stats:get(CharacterStat.PANIC) or 0 end)
    local res = diaResistance(player, d)
    local fitness = DanTraits_MddRegularity and DanTraits_MddRegularity(player) or 0

    -- carbohydrates being absorbed
    local fast = d.diaFast * DIA_FAST_RATE
    local slow = d.diaSlow * DIA_SLOW_RATE
    d.diaFast = d.diaFast - fast
    d.diaSlow = d.diaSlow - slow
    if d.diaFast < 0.01 then d.diaFast = 0 end
    if d.diaSlow < 0.01 then d.diaSlow = 0 end
    g = g + (fast + slow) * DIA_CARB_MGDL

    -- injected insulin on board
    local sensitivity = diaSensitivity(player, res, fitness)
    local keep = {}
    for _, shot in ipairs(d.diaInsulin) do
        g = g - shot.dose * DIA_DOSE_MGDL * diaInsulinProfile(shot.t) * sensitivity
        shot.t = shot.t + 1
        if shot.t < DIA_INSULIN_END then keep[#keep + 1] = shot end
    end
    d.diaInsulin = keep

    -- the body's own regulation: none for Type 1, resistance-limited for Type 2
    if hasTrait(player, "diabetes1") then
        g = g + DIA_T1_DRIFT
    else
        local setpoint = DIA_T2_SETPOINT + DIA_T2_SETPOINT_RES * res
        g = g + (setpoint - g) * DIA_T2_RATE * (1 - DIA_T2_RATE_RES_CUT * res)
    end

    -- everything else
    if g > DIA_RENAL_ABOVE then g = g - (g - DIA_RENAL_ABOVE) * DIA_RENAL_RATE end
    if moving or endurance < DIA_EXERT_ENDURANCE then g = g - DIA_EXERCISE_DROP end
    if asleep then g = g - DIA_SLEEP_DROP end
    if drunk then g = g - DIA_ALCOHOL_DROP end
    if panic > DIA_PANIC_MIN then g = g + (panic - DIA_PANIC_MIN) / (100 - DIA_PANIC_MIN) * DIA_PANIC_RISE end
    g = g + DIA_FEVER_RISE * DanTraits_Strength("DanTraits_InfectionFever", player)

    g = diaClamp(g)
    d.glucose = g

    -- symptoms
    local low, high = diaTier(g)
    if high >= 3 then d.diaKetoHours = d.diaKetoHours + 1 / 60 else d.diaKetoHours = math.max(0, d.diaKetoHours - 1 / 60) end
    diaHalo(player, d, low, high)
    diaMoodle(player, d, low, high)
    if (d.diaFaintGap or 0) > 0 then d.diaFaintGap = d.diaFaintGap - 1 end
    d.diaFumble = low > 0 and DIA_LOW_FUMBLE[low] or 0
    d.diaLow = low > 0 and low or nil
    if low == 0 and high == 0 then return end

    -- the symptoms (the stat helpers never throw; the body-damage calls are the game's)
    local function drainHealth(perMinute, floorOff)
        pcall(function()
            local bd = player:getBodyDamage()
            local floor = floorOff and 0 or DIA_HEALTH_FLOOR
            if bd:getOverallBodyHealth() > floor then
                bd:ReduceGeneralHealth(math.min(perMinute, bd:getOverallBodyHealth() - floor))
            end
        end)
    end
    if low > 0 then
        if DIA_LOW_END_DRAIN[low] > 0 then statAdd(stats, CharacterStat.ENDURANCE, -DIA_LOW_END_DRAIN[low]) end
        statAdd(stats, CharacterStat.FATIGUE, DIA_LOW_FATIGUE[low])
        statAdd(stats, CharacterStat.PANIC, DIA_LOW_PANIC[low])
        floorUp(stats, CharacterStat.UNHAPPINESS, DIA_LOW_UNHAPPY_FLOOR[low], DIA_STAT_RAMP)
        if low >= 3 then
            drainHealth(DIA_LOW_HP_DRAIN, false)
            if not asleep then diaBlackout(player, d) end
        end
    else
        statAdd(stats, CharacterStat.THIRST, DIA_HIGH_THIRST[high])
        statAdd(stats, CharacterStat.FATIGUE, DIA_HIGH_FATIGUE[high])
        local mood = DIA_HIGH_UNHAPPY_FLOOR[high]
        if d.mddEpisode then mood = mood * DIA_MDD_UNHAPPY_MULT end
        floorUp(stats, CharacterStat.UNHAPPINESS, mood, DIA_STAT_RAMP)
        floorUp(stats, CharacterStat.FOOD_SICKNESS, DIA_HIGH_SICK_FLOOR[high], DIA_STAT_RAMP)
        if high >= 3 and d.diaKetoHours >= DIA_HIGH_DRAIN_AFTER then
            drainHealth(DIA_HIGH_HP_DRAIN, d.diaKetoHours >= DIA_KETO_HOURS)
        end
    end
end

-- 0..1 how bad a low is now (a third a tier), 0 for anyone else; Epilepsy and
-- Steady Hands read it
function DanTraits_DiaLow(player)
    if not player or not diaHas(player) then return 0 end
    return (diaData(player).diaLow or 0) / #DIA_LOW
end

-- shakiness adds to every weapon swing, Fumbler or not
function DanTraits_ExtraFumble(player)
    if not player or not diaHas(player) then return 0 end
    return diaData(player).diaFumble or 0
end

function DanTraits_IsInsulin(item) return DanTraits_IsItem(item, INSULIN_ITEM) end
function DanTraits_IsMeter(item) return DanTraits_IsItem(item, METER_ITEM) end
function DanTraits_IsStrips(item) return DanTraits_IsItem(item, STRIPS_ITEM) end
function DanTraits_IsMetformin(item) return DanTraits_IsItem(item, METFORMIN_ITEM) end

-- Type 1 starts with a meter, strips and three pens; Type 2 with a meter, strips and metformin.
-- With the Starting Medication sandbox option off, only the meter and strips.
local function onDiabetesCreatePlayer(playerNum, player)
    if not player or not diaHas(player) then return end
    local d = diaData(player)
    if d.diaKitGiven or player:getHoursSurvived() > 0 then return end
    d.diaKitGiven = true
    pcall(function()
        local inv = player:getInventory()
        inv:AddItem(METER_ITEM)
        inv:AddItem(STRIPS_ITEM)
        if DanTraits_SandboxOn("StartingMedication") then
            if hasTrait(player, "diabetes1") then
                for _ = 1, 3 do inv:AddItem(INSULIN_ITEM) end
            else
                inv:AddItem(METFORMIN_ITEM)
            end
        end
    end)
    if hasTrait(player, "diabetes2") and DanTraits_MedStart then DanTraits_MedStart(player, "metformin") end
end

DanTraits_Every("minute", "Diabetes", updateDiabetesMinute, 40)
Events.OnCreatePlayer.Add(onDiabetesCreatePlayer)

-- Drinks are fluid containers, not food: hook the drink action and read the
-- carbohydrates of the fluid times the litres that actually went down. The
-- container's properties are totals for what is in it (measured in game: a
-- mug of 0.2 l cola reports 20.8 g, 0.1 l reports 10.4 g), so divide by the
-- amount for per litre.
local function wrapDrinkAction()
    DanTraits_Wrap(ISDrinkFluidAction, "updateEat", "drink-intake", function(original, self, ...)
        local before, perLitre, kcalPerLitre = 0, 0, 0
        pcall(function()
            before = self.fluidContainer:getAmount() or 0
            if before > 0 then perLitre = (self.fluidContainer:getProperties():getCarbohydrates() or 0) / before end
        end)
        pcall(function()
            if before > 0 then kcalPerLitre = (self.fluidContainer:getProperties():getCalories() or 0) / before end
        end)
        -- the fluid is read before the sip: the last one empties the container,
        -- and an empty container has no fluid to name (the "drink" hook's
        -- subscribers, Caffeine and Lactose, are handed the name and its share)
        local name, ratio = DanTraits_FluidName(self.fluidContainer), DanTraits_FluidRatio(self.fluidContainer)
        local result = original(self, ...)
        pcall(function()
            local after = self.fluidContainer:getAmount() or before
            local litres = before - after
            if litres > 0 and perLitre > 0 then DanTraits_DiaOnDrink(self.character, litres * perLitre) end
            if litres > 0 and DanTraits_VitalityOnDrink then DanTraits_VitalityOnDrink(self.character, litres, perLitre, kcalPerLitre) end
            if litres > 0 then DanTraits_RunHooks("drink", nil, self.character, self.fluidContainer, litres, name, ratio) end
        end)
        return result
    end)
end
wrapDrinkAction()
Events.OnGameStart.Add(wrapDrinkAction)


-- high blood sugar feeds a wound infection and slows healing: the Infection
-- file's hazard and growth hooks, scaled by how far up the high band we are
local function infectionSugar(player)
    if not diaHas(player) then return 0 end
    local d = player:getModData().DanTraits
    if not d or not d.glucose then return 0 end
    return math.max(0, math.min(1, (d.glucose - DIA_HIGH[1]) / (DIA_HIGH[3] - DIA_HIGH[1])))
end
DanTraits_AddHook("infectionHazard", function(h, player)
    local t = infectionSugar(player)
    if t <= 0 then return nil end
    return h * (1 + DIA_INF_HAZARD * t)
end)
DanTraits_AddHook("infectionGrowth", function(k, player)
    local t = infectionSugar(player)
    if t <= 0 then return nil end
    return k * (1 + DIA_INF_GROWTH * t)
end)
