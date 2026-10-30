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
-- Vitality drink hook, the `drink` hook and `alcoholDrunk`, each once per
-- drink with the litres swallowed); Alcohol adds its own layer to the same
-- method and the two chain.
-- the numbers, one table so the minute function reads them through one upvalue
local DIA = {
    START                = 110,
    MIN                  = 20,
    MAX                  = 600,
    CARB_MGDL            = 4.0,                    -- mg/dL per gram of carbohydrate absorbed with nothing to meet it
    FAST_RATE            = 2 / 30,                 -- per minute, fraction of pending fast carbs absorbed (most of it inside half an hour)
    SLOW_RATE            = 2 / 120,                -- per minute, slow carbs (most of it inside two hours)
    T1_DRIFT             = 0.17,                   -- per minute, creep with no insulin on board (about 10 an hour)
    T2_SETPOINT          = 100,                    -- where a Type 2 body settles with no resistance
    T2_SETPOINT_RES      = 120,                    -- added to the setpoint at full resistance
    T2_RATE              = 0.012,                  -- per minute, fraction of the gap to the setpoint the body closes at no resistance
    T2_RATE_RES_CUT      = 0.6,                    -- that rate x (1 - this x resistance)
    T2_WEIGHT_LOW        = 75,                     -- kg: no resistance at or below
    T2_WEIGHT_HIGH       = 110,                    -- kg: full resistance at or above (before exercise and pills)
    T2_EXERCISE_CUT      = 0.25,                   -- resistance removed at full exercise regularity
    T2_PILL_CUT          = 0.35,                   -- resistance removed by metformin, fully built up (DanTraits_Meds.lua: a pill a day, two days to build)
    RENAL_ABOVE          = 180,
    RENAL_RATE           = 0.002,                  -- per minute x (glucose - 180)
    EXERCISE_DROP        = 0.5,                    -- per minute while running, sprinting or exerted
    EXERT_ENDURANCE      = 0.6,                    -- "exerted" means endurance under this AND still being spent (Asthma's test)
    TRAIN_DROP           = 1.0,                    -- per minute of a workout (DanTraits_Fitness.lua: the window's exercises, a loaded carry, a jog)
    AFTER_DROP           = 0.2,                    -- per minute after one, x the afterglow left (Pumped, fading over its hours)
    T2_AFTER_CUT         = 0.1,                    -- Type 2 resistance off, x the afterglow left
    SLEEP_DROP           = 0.05,                   -- per minute asleep
    PANIC_MIN            = 30,                     -- panic below this (out of 100) does nothing
    PANIC_RISE           = 0.15,                   -- per minute at full panic, scaling linearly from the minimum (was 0.4: too fast in play)
    ALCOHOL_DROP         = 0.35,                   -- per minute while intoxicated: the liver is busy with the drink
    INHALER_RISE         = 15,                     -- a puff of a rescue inhaler
    DOSE_MGDL            = 50,                     -- one pen dose lowers blood sugar by this much in total
    INSULIN_ONSET        = 15,                     -- minutes before a dose starts working
    INSULIN_PEAK         = 75,                     -- minutes to peak action
    INSULIN_END          = 240,                    -- minutes until it is spent
    INSULIN_RES_CUT      = 0.5,                    -- insulin effect x (1 - this x resistance) for Type 2
    INSULIN_FIT_BONUS    = 0.2,                    -- insulin effect x (1 + this x exercise regularity)
    LOW                  = { 70, 55, 40 },
    HIGH                 = { 180, 250, 350 },
    LOW_FUMBLE           = { 4, 8, 14 },           -- percent added to every weapon swing (see Fumbler)
    LOW_END_DRAIN        = { 0, 0.03, 0.08 },      -- endurance per minute
    LOW_FATIGUE          = { 0.001, 0.003, 0.005 },
    LOW_PANIC            = { 1, 2, 4 },            -- per minute (out of 100): adrenaline, which also pushes sugar back up
    LOW_UNHAPPY_FLOOR    = { 10, 25, 40 },
    LOW_HP_DRAIN         = 0.5,                    -- per minute at the worst tier, down to the floor
    LOW_FAINT            = 0.04,                   -- per minute at the worst tier: a chance of blacking out
    LOW_FAINT_MIN        = { 5, 20 },              -- game minutes out (shallow: a new wound wakes you)
    LOW_FAINT_GAP        = 30,                     -- minutes between blackouts (d.diaFaintGap)
    NIGHT_LOW_TIER       = 2,                      -- a low at this tier or worse while asleep wakes you, drenched in sweat...
    NIGHT_CUT            = 0.3,                    -- ...and that night scores x (1 - this) (nightQuality)
    HIGH_THIRST          = { 0.002, 0.004, 0.006 },   -- per minute (0..1)
    HIGH_FATIGUE         = { 0.0005, 0.0015, 0.003 },
    HIGH_UNHAPPY_FLOOR   = { 0, 15, 30 },
    HIGH_SICK_FLOOR      = { 0, 20, 50 },          -- food sickness (Queasy, then Nauseous)
    HIGH_HP_DRAIN        = 0.3,                    -- per minute at the worst tier...
    HIGH_DRAIN_AFTER     = 2,                      -- ...once this many hours have been spent up there (d.diaKetoHours):
    -- a spike after a meal costs nothing, hours of it do (2026-10-08)
    FEVER_RISE           = 0.1,                    -- mg/dL per minute at full fever: illness raises blood sugar (sick day rules)
    HEALTH_FLOOR         = 15,                     -- percent: symptoms stop short of this...
    KETO_DAYS            = 1,                      -- ...and above the top threshold for hours on end the floor sinks, gone after
    -- this many days (sandbox UntreatedDiabetesDays: 0 never, 1 the old day)
    MDD_UNHAPPY_MULT     = 1.5,                    -- high-sugar mood floor during a depressive episode
    HALO_MIN             = { 10, 5, 3 },           -- minutes between symptom messages by tier, plus up to as many again
    MOODLE_TIER          = { 0.3, 0.6, 0.9 },      -- the BloodSugar moodle: value tier / 3, one moodle level per tier
    STAT_RAMP            = 2,                      -- per minute towards a mood/sickness floor
    INF_HAZARD           = 1.0,                    -- wound infection chance x (1 + this x t), t = 0 at DIA.HIGH[1] up to 1 at DIA.HIGH[3]
    INF_GROWTH           = 0.5,                    -- infection climb x (1 + this x t): high sugar feeds it and slows healing

}
local INSULIN_ITEM   = "DanTraits.InsulinPen"
local VIAL_ITEM      = "DanTraits.InsulinVial"      -- the same insulin, drawn up with a syringe
local SYRINGE_ITEM   = "DanTraits.InsulinSyringe"   -- never used up
local METER_ITEM     = "DanTraits.GlucoseMeter"
local STRIPS_ITEM    = "DanTraits.TestStrips"
local METFORMIN_ITEM = "DanTraits.Metformin"

local function diaHas(player)
    return hasTrait(player, "diabetes1") or hasTrait(player, "diabetes2")
end
DanTraits_IsDiabetic = diaHas

local function diaData(player)
    local d = traitData(player)
    d.glucose = d.glucose or DIA.START
    d.diaFast = d.diaFast or 0
    d.diaSlow = d.diaSlow or 0
    d.diaInsulin = d.diaInsulin or {}
    d.diaKetoHours = d.diaKetoHours or 0
    return d
end

local function diaClamp(g) return math.max(DIA.MIN, math.min(DIA.MAX, g)) end

-- foods whose sugar hits fast (the fastCarb tag of DanTraits_Food.lua); everything else with carbohydrates is slow
function DanTraits_IsFastCarb(item)
    return foodTags(item).fastCarb == true
end

-- 0..1 insulin resistance for Type 2 (always 0 for Type 1)
local function diaResistance(player, d)
    if not hasTrait(player, "diabetes2") then return 0 end
    local weight = 80
    pcall(function() weight = player:getNutrition():getWeight() or weight end)
    local res = (weight - DIA.T2_WEIGHT_LOW) / (DIA.T2_WEIGHT_HIGH - DIA.T2_WEIGHT_LOW)
    res = res - DIA.T2_EXERCISE_CUT * (DanTraits_MddRegularity and DanTraits_MddRegularity(player) or 0)
    if DanTraits_MedEffect then res = res - DIA.T2_PILL_CUT * DanTraits_MedEffect(player, "metformin") end
    if DanTraits_VitalityDiaResistance then res = res + DanTraits_VitalityDiaResistance(player) end   -- fit: lower, run down: higher
    if DanTraits_FitAfterglow then res = res - DIA.T2_AFTER_CUT * DanTraits_FitAfterglow(player) end   -- a workout's hours after
    res = DanTraits_RunHooks("diaResistance", res, player, d)   -- Age: higher in the 40s, lower in the 20s
    return math.max(0, math.min(1, res))
end
DanTraits_DiaResistance = function(player) return diaResistance(player, diaData(player)) end

-- fraction of a dose delivered in minute t (triangle: onset, peak, spent)
local function diaInsulinProfile(t)
    if t < DIA.INSULIN_ONSET or t >= DIA.INSULIN_END then return 0 end
    local area = (DIA.INSULIN_END - DIA.INSULIN_ONSET) / 2
    if t < DIA.INSULIN_PEAK then
        return (t - DIA.INSULIN_ONSET) / (DIA.INSULIN_PEAK - DIA.INSULIN_ONSET) / area
    end
    return (DIA.INSULIN_END - t) / (DIA.INSULIN_END - DIA.INSULIN_PEAK) / area
end

-- how hard a dose hits: resistance blunts it, fitness and Vitality sharpen it
local function diaSensitivity(player, res, fitness)
    local k = (1 - DIA.INSULIN_RES_CUT * res) * (1 + DIA.INSULIN_FIT_BONUS * fitness)
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
    d.glucose = diaClamp(d.glucose + DIA.INHALER_RISE)
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
    return g, (g < DIA.LOW[1] or g >= DIA.HIGH[1])
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
-- Doses to cover a food: carbohydrates x DIA.CARB_MGDL / (DIA.DOSE_MGDL x
-- sensitivity), about one dose per 12.5 g. Type 2 is not told doses: its own
-- insulin covers most of a meal, so the Type 1 sum would overdose it.
-- The forecast behind the splitting advice and the meter's correction is the
-- model's own minute steps (diaProject: carbohydrates, insulin on board at
-- this body's sensitivity, Type 1's creep, the kidneys) run four hours ahead,
-- nothing else (no exercise, sleep or drink). Both aim where sugar settles
-- once everything on board has worked, creep and all: a Type 1 at 120 with
-- nothing working is told the dose the next four hours need, not "steady",
-- and one at 100 with two doses working is told to eat. A reading under the
-- low line is low now: it is told to eat unless the sugar already going in
-- covers it, and is never told to inject.
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
    if DanTraits_Is(item, "Food") then
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
    return carbs * DIA.CARB_MGDL / (DIA.DOSE_MGDL * k), fast
end

-- the next four hours if this food went in now with its doses (the header's
-- forecast): where sugar would peak, and where it settles at the end. The
-- insulin on board hits at this body's sensitivity k, as the live model
-- applies it; the new doses are given for an ordinary body (DanTraits_DiaParts),
-- so the sensitivity cancels out of their step.
local DIA_SIM_MINUTES = DIA.INSULIN_END
local function diaProject(d, carbs, fast, doses, k)
    local g = d.glucose
    local f = d.diaFast + (fast and carbs or 0)
    local s = d.diaSlow + (fast and 0 or carbs)
    local shots = {}
    for _, shot in ipairs(d.diaInsulin or {}) do shots[#shots + 1] = { dose = shot.dose * k, t = shot.t } end
    if doses > 0 then shots[#shots + 1] = { dose = doses, t = 0 } end
    local peak = g
    for _ = 1, DIA_SIM_MINUTES do
        local a, b = f * DIA.FAST_RATE, s * DIA.SLOW_RATE
        f, s = f - a, s - b
        g = g + (a + b) * DIA.CARB_MGDL + DIA.T1_DRIFT
        for _, shot in ipairs(shots) do
            g = g - shot.dose * DIA.DOSE_MGDL * diaInsulinProfile(shot.t)
            shot.t = shot.t + 1
        end
        if g > DIA.RENAL_ABOVE then g = g - (g - DIA.RENAL_ABOVE) * DIA.RENAL_RATE end
        if g > peak then peak = g end
    end
    return peak, g
end

-- nil if the whole thing is safe to eat dosed, else how many parts to eat it
-- in (2 to 4), or 5 for "a little at a time"
function DanTraits_DiaParts(player, item)
    local carbs, fast = diaItemCarbs(item)
    if carbs <= 0 then return nil end
    local d = diaData(player)
    local k = diaSensitivity(player, 0, diaFitness(player))
    local doses = carbs * DIA.CARB_MGDL / DIA.DOSE_MGDL
    if diaProject(d, carbs, fast, doses, k) < DIA.HIGH[3] then return nil end
    for n = 2, 4 do
        if diaProject(d, carbs / n, fast, doses / n, k) < DIA.HIGH[3] then return n end
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
        for t = math.max(0, shot.t), DIA.INSULIN_END - 1 do left = left + shot.dose * diaInsulinProfile(t) end
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
    -- where sugar settles once the food going in and the insulin working have done,
    -- with four hours of Type 1's creep and what the kidneys dump above 180 (the
    -- forecast's own steps, from this reading)
    local _, settles = diaProject({ glucose = g, diaFast = d.diaFast, diaSlow = d.diaSlow, diaInsulin = d.diaInsulin }, 0, true, 0, k)
    local gap = settles - DIA_TARGET
    -- low now: short unless the sugar already going in covers it (no waiting on the creep)
    local lowNow = g < DIA.LOW[1]
    if lowNow then gap = math.min(gap, g + (d.diaFast + d.diaSlow) * DIA.CARB_MGDL - DIA_TARGET) end
    if gap <= -DIA.CARB_MGDL * 5 then
        out[#out + 1] = { "UI_DanTraits_DiaEat", math.floor(-gap / DIA.CARB_MGDL / 5 + 0.5) * 5 }
    elseif not lowNow and gap >= DIA.DOSE_MGDL * k * 0.5 then
        out[#out + 1] = { "UI_DanTraits_DiaCorrect", math.floor(gap / (DIA.DOSE_MGDL * k) + 0.5) }
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
        local h = DanTraits_WorldHours()
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
    pcall(function() ago = math.max(0, DanTraits_WorldHours() - (last.h or 0)) end)
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
    for i, threshold in ipairs(DIA.LOW) do if g < threshold then low = i end end
    for i, threshold in ipairs(DIA.HIGH) do if g >= threshold then high = i end end
    return low, high
end
DanTraits_DiaTier = diaTier

-- vague on purpose: three of the six messages are shared between low and high
-- a low in the night: at DIA.NIGHT_LOW_TIER or worse asleep you wake drenched
-- in sweat, once per low (diaNightWoke), and the night is scored lower
-- (diaNightLow, read once by the nightQuality hook below)
local function diaNightLow(player, d, low, asleep)
    if low <= 0 then d.diaNightWoke = nil return end
    if not asleep or low < DIA.NIGHT_LOW_TIER or d.diaNightWoke then return end
    d.diaNightWoke, d.diaNightLow = true, true
    pcall(function() player:forceAwake() end)
    notify(player, "UI_DanTraits_DiaNightLow")
end

local function diaHalo(player, d, low, high)
    local tier = math.max(low, high)
    if tier == 0 then d.diaHaloIn = nil; return end
    if DanTraits_IsTipsy(player) then return end   -- too drunk to notice
    d.diaHaloIn = (d.diaHaloIn or (DIA.HALO_MIN[tier] + ZombRand(DIA.HALO_MIN[tier]))) - 1
    if d.diaHaloIn > 0 then return end
    d.diaHaloIn = DIA.HALO_MIN[tier] + ZombRand(DIA.HALO_MIN[tier])
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
        if DanTraits_IsTipsy(player) then tier = 0 end
    end
    if tier == 0 and not d.diaMoodle then return end
    d.diaMoodle = tier > 0 or nil
    DanTraits_BadMoodle(player, "BloodSugar", tier / 3, DIA.MOODLE_TIER)
end

-- a bad low can put you on the floor (DanTraits_Faint.lua); glucose keeps falling while out.
-- A refused faint (already out) does not spend the gap.
local function diaBlackout(player, d)
    if not DanTraits_PassOut or (d.diaFaintGap or 0) > 0 or not DanTraits_Roll(DIA.LOW_FAINT) then return end
    if DanTraits_PassOut(player, DanTraits_RandRange(DIA.LOW_FAINT_MIN[1], DIA.LOW_FAINT_MIN[2]), "UI_DanTraits_DiaBlackout") then
        d.diaFaintGap = DIA.LOW_FAINT_GAP
    end
end

-- the health floor for hours spent above the top threshold: DIA.HEALTH_FLOOR
-- when the drain starts, sinking in a straight line to 0 at the sandbox's
-- UntreatedDiabetesDays (1: a day, as before 2026-10-20; 0: it never sinks)
function DanTraits_DiaHighFloor(hours)
    local days = DanTraits_SandboxNum("UntreatedDiabetesDays", DIA.KETO_DAYS)
    if days <= 0 then return DIA.HEALTH_FLOOR end
    local span = days * 24 - DIA.HIGH_DRAIN_AFTER
    if span <= 0 then return 0 end
    local t = ((hours or 0) - DIA.HIGH_DRAIN_AFTER) / span
    return DIA.HEALTH_FLOOR * math.max(0, math.min(1, 1 - t))
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
    local f = DanTraits_Frame(player)   -- the movement snapshot (DanTraits.lua)
    moving = f.sprinting or f.running
    drunk = DanTraits_IsTipsy(player)
    pcall(function() endurance = stats:get(CharacterStat.ENDURANCE) or 1 end)
    -- low endurance alone is an asthma attack, angina's regen cut, blood loss or spoons
    -- holding it down for hours; exercise is endurance going down this minute
    local spending = endurance < (d.diaEndPrev or endurance) - 1e-6
    d.diaEndPrev = endurance
    pcall(function() panic = stats:get(CharacterStat.PANIC) or 0 end)
    local res = diaResistance(player, d)
    local fitness = DanTraits_MddRegularity and DanTraits_MddRegularity(player) or 0

    -- carbohydrates being absorbed
    local fast = d.diaFast * DIA.FAST_RATE
    local slow = d.diaSlow * DIA.SLOW_RATE
    d.diaFast = d.diaFast - fast
    d.diaSlow = d.diaSlow - slow
    if d.diaFast < 0.01 then d.diaFast = 0 end
    if d.diaSlow < 0.01 then d.diaSlow = 0 end
    g = g + (fast + slow) * DIA.CARB_MGDL

    -- injected insulin on board
    local sensitivity = diaSensitivity(player, res, fitness)
    local keep = {}
    for _, shot in ipairs(d.diaInsulin) do
        g = g - shot.dose * DIA.DOSE_MGDL * diaInsulinProfile(shot.t) * sensitivity
        shot.t = shot.t + 1
        if shot.t < DIA.INSULIN_END then keep[#keep + 1] = shot end
    end
    d.diaInsulin = keep

    -- the body's own regulation: none for Type 1, resistance-limited for Type 2
    if hasTrait(player, "diabetes1") then
        g = g + DIA.T1_DRIFT
    else
        local setpoint = DIA.T2_SETPOINT + DIA.T2_SETPOINT_RES * res
        g = g + (setpoint - g) * DIA.T2_RATE * (1 - DIA.T2_RATE_RES_CUT * res)
    end

    -- everything else
    if g > DIA.RENAL_ABOVE then g = g - (g - DIA.RENAL_ABOVE) * DIA.RENAL_RATE end
    -- a workout burns more than running about; stretching and hard work count as
    -- the exertion they are. After one, the muscles keep drawing sugar in for hours.
    local trainKey = DanTraits_FitTrainingNow and DanTraits_FitTrainingNow(player) or nil
    if trainKey and trainKey ~= "dtstretch" and trainKey ~= "dtwork" then
        g = g - DIA.TRAIN_DROP
    elseif moving or (spending and endurance < DIA.EXERT_ENDURANCE) then
        g = g - DIA.EXERCISE_DROP
    end
    if DanTraits_FitAfterglow then g = g - DIA.AFTER_DROP * DanTraits_FitAfterglow(player) end
    if asleep then g = g - DIA.SLEEP_DROP end
    if drunk then g = g - DIA.ALCOHOL_DROP end
    if panic > DIA.PANIC_MIN then g = g + (panic - DIA.PANIC_MIN) / (100 - DIA.PANIC_MIN) * DIA.PANIC_RISE end
    g = g + DIA.FEVER_RISE * DanTraits_Strength("DanTraits_InfectionFever", player)

    g = diaClamp(g)
    d.glucose = g

    -- symptoms
    local low, high = diaTier(g)
    if high >= 3 then d.diaKetoHours = d.diaKetoHours + 1 / 60 else d.diaKetoHours = math.max(0, d.diaKetoHours - 1 / 60) end
    diaHalo(player, d, low, high)
    diaMoodle(player, d, low, high)
    if (d.diaFaintGap or 0) > 0 then d.diaFaintGap = d.diaFaintGap - 1 end
    d.diaFumble = low > 0 and DIA.LOW_FUMBLE[low] or 0
    d.diaLow = low > 0 and low or nil
    diaNightLow(player, d, low, asleep)
    if low == 0 and high == 0 then return end

    -- the symptoms (the stat helpers never throw; the body-damage calls are the game's)
    local function drainHealth(perMinute, floor)
        pcall(function()
            local bd = player:getBodyDamage()
            if bd:getOverallBodyHealth() > floor then
                bd:ReduceGeneralHealth(math.min(perMinute, bd:getOverallBodyHealth() - floor))
            end
        end)
    end
    if low > 0 then
        if DIA.LOW_END_DRAIN[low] > 0 then statAdd(stats, CharacterStat.ENDURANCE, -DIA.LOW_END_DRAIN[low]) end
        statAdd(stats, CharacterStat.FATIGUE, DIA.LOW_FATIGUE[low])
        statAdd(stats, CharacterStat.PANIC, DIA.LOW_PANIC[low])
        floorUp(stats, CharacterStat.UNHAPPINESS, DIA.LOW_UNHAPPY_FLOOR[low], DIA.STAT_RAMP)
        if low >= 3 then
            drainHealth(DIA.LOW_HP_DRAIN, DIA.HEALTH_FLOOR)
            if not asleep then diaBlackout(player, d) end
        end
    else
        statAdd(stats, CharacterStat.THIRST, DIA.HIGH_THIRST[high])
        statAdd(stats, CharacterStat.FATIGUE, DIA.HIGH_FATIGUE[high])
        local mood = DIA.HIGH_UNHAPPY_FLOOR[high]
        if d.mddEpisode then mood = mood * DIA.MDD_UNHAPPY_MULT end
        floorUp(stats, CharacterStat.UNHAPPINESS, mood, DIA.STAT_RAMP)
        floorUp(stats, CharacterStat.FOOD_SICKNESS, DIA.HIGH_SICK_FLOOR[high], DIA.STAT_RAMP)
        if high >= 3 and d.diaKetoHours >= DIA.HIGH_DRAIN_AFTER then
            drainHealth(DIA.HIGH_HP_DRAIN, DanTraits_DiaHighFloor(d.diaKetoHours))
        end
    end
end

-- 0..1 how bad a low is now (a third a tier), 0 for anyone else; Epilepsy and
-- Steady Hands read it
function DanTraits_DiaLow(player)
    if not player or not diaHas(player) then return 0 end
    return (diaData(player).diaLow or 0) / #DIA.LOW
end

-- shakiness adds to every weapon swing, Fumbler or not
function DanTraits_ExtraFumble(player)
    if not player or not diaHas(player) then return 0 end
    return diaData(player).diaFumble or 0
end

-- a pen or a vial; a vial needs a syringe to inject (DanTraits_InsulinSyringeFor)
function DanTraits_IsInsulin(item) return DanTraits_IsItem(item, INSULIN_ITEM) or DanTraits_IsItem(item, VIAL_ITEM) end
function DanTraits_IsInsulinVial(item) return DanTraits_IsItem(item, VIAL_ITEM) end
function DanTraits_IsSyringe(item) return DanTraits_IsItem(item, SYRINGE_ITEM) end

-- what it takes to inject from this item: true for a pen, the first syringe
-- carried (bags too) for a vial, nil when a vial has none to draw it up with
function DanTraits_InsulinSyringeFor(player, item)
    if not DanTraits_IsInsulinVial(item) then return true end
    local found
    pcall(function()
        local all = player:getInventory():getAllEvalRecurse(DanTraits_IsSyringe)
        if all and all:size() > 0 then found = all:get(0) end
    end)
    return found
end
function DanTraits_IsMeter(item) return DanTraits_IsItem(item, METER_ITEM) end
function DanTraits_IsStrips(item) return DanTraits_IsItem(item, STRIPS_ITEM) end
function DanTraits_IsMetformin(item) return DanTraits_IsItem(item, METFORMIN_ITEM) end

-- Type 1 starts with a meter, strips, a syringe and three pens; Type 2 with a meter, strips and
-- metformin, built up. With the Starting Medication sandbox option off, the meter and strips
-- (and Type 1's syringe, for the vials it will have to find or make).
DanTraits_StartingKit({
    trait = diaHas, flag = "diaKitGiven",
    setup = function(player) diaData(player) end,   -- the starting sugar
    always = function(player)
        if hasTrait(player, "diabetes1") then return { METER_ITEM, STRIPS_ITEM, SYRINGE_ITEM } end
        return { METER_ITEM, STRIPS_ITEM }
    end,
    items = function(player)
        if hasTrait(player, "diabetes1") then return { INSULIN_ITEM, INSULIN_ITEM, INSULIN_ITEM } end
        return { METFORMIN_ITEM }
    end,
    meds = function(player) if hasTrait(player, "diabetes2") then return { "metformin" } end end,
})

DanTraits_Every("minute", "Diabetes", updateDiabetesMinute, 40)

-- Animal insulin: butchering a mammal gives its pancreas, for the extraction
-- recipes in DanTraits.txt. The game's AnimalPartsDefinitions keeps one parts
-- list per kind, shared by every breed and sex (all the adult pigs read one
-- table), so each list gets the entry once. One per carcass ("nb" is a fixed
-- count: ButcheringUtil.addAnimalPart skips its size and skill scaling).
-- Rats, mice and birds give none.
local PANCREAS_ITEM       = "DanTraits.Pancreas"
local PANCREAS_SMALL_ITEM = "DanTraits.PancreasSmall"
local PANCREAS_OF = {
    cowangus = PANCREAS_ITEM, bullangus = PANCREAS_ITEM, cowcalfangus = PANCREAS_ITEM,
    cowsimmental = PANCREAS_ITEM, bullsimmental = PANCREAS_ITEM, cowcalfsimmental = PANCREAS_ITEM,
    cowholstein = PANCREAS_ITEM, bullholstein = PANCREAS_ITEM, cowcalfholstein = PANCREAS_ITEM,
    sowlandrace = PANCREAS_ITEM, boarlandrace = PANCREAS_ITEM, pigletlandrace = PANCREAS_SMALL_ITEM,
    sowlargeblack = PANCREAS_ITEM, boarlargeblack = PANCREAS_ITEM, pigletlargeblack = PANCREAS_SMALL_ITEM,
    ewesuffolk = PANCREAS_ITEM, ramsuffolk = PANCREAS_ITEM, lambsuffolk = PANCREAS_SMALL_ITEM,
    ewerambouillet = PANCREAS_ITEM, ramrambouillet = PANCREAS_ITEM, lambrambouillet = PANCREAS_SMALL_ITEM,
    ewefriesian = PANCREAS_ITEM, ramfriesian = PANCREAS_ITEM, lambfriesian = PANCREAS_SMALL_ITEM,
    doewhitetailed = PANCREAS_ITEM, buckwhitetailed = PANCREAS_ITEM, fawnwhitetailed = PANCREAS_SMALL_ITEM,
    rabdoeswamp = PANCREAS_SMALL_ITEM, rabbuckswamp = PANCREAS_SMALL_ITEM,
    rabdoeappalachian = PANCREAS_SMALL_ITEM, rabbuckappalachian = PANCREAS_SMALL_ITEM,
    rabdoecottontail = PANCREAS_SMALL_ITEM, rabbuckcottontail = PANCREAS_SMALL_ITEM,
    raccoonsowgrey = PANCREAS_SMALL_ITEM, raccoonboargrey = PANCREAS_SMALL_ITEM,
}

function DanTraits_AddPancreasParts()
    local defs = AnimalPartsDefinitions and AnimalPartsDefinitions.animals
    if type(defs) ~= "table" then return 0 end
    local added = 0
    for animal, item in pairs(PANCREAS_OF) do
        local parts = type(defs[animal]) == "table" and defs[animal].parts
        if type(parts) == "table" then
            local has = false
            for _, part in pairs(parts) do
                if type(part) == "table" and (part.item == PANCREAS_ITEM or part.item == PANCREAS_SMALL_ITEM) then has = true end
            end
            if not has then
                table.insert(parts, { item = item, nb = 1 })
                added = added + 1
            end
        end
    end
    return added
end

DanTraits_AddPancreasParts()   -- vanilla's shared definitions load before the mods'
if Events and Events.OnGameBoot then Events.OnGameBoot.Add(DanTraits_AddPancreasParts) end   -- and again, if not

-- Drinks are fluid containers, not food: hook the drink action and read the
-- carbohydrates of the fluid times the litres that actually went down. The
-- container's properties are totals for what is in it (measured in game: a
-- mug of 0.2 l cola reports 20.8 g, 0.1 l reports 10.4 g), so divide by the
-- amount for per litre.
--
-- One drink, one report. Vanilla calls updateEat(jobDelta) from update() on
-- every tick of the action and updateEat(1) from complete() (B42
-- ISDrinkFluidAction.lua), so every sip reaches this wrap. The sips are summed
-- on the action object (danDrink) and handed on once: when the action
-- completes (delta 1), when it is stopped or performed, or when the fluid
-- changes under it. The readers (DiaOnDrink, the Vitality drink hook, the
-- `drink` hook for Caffeine and Lactose, `alcoholDrunk` for Delicate Stomach)
-- are therefore called once per drink with the whole amount, not once per tick.
local function flushDrink(self)
    local p = rawget(self, "danDrink")
    if not p then return end
    self.danDrink = nil
    if p.litres <= 0 then return end
    if p.carbs > 0 then DanTraits_DiaOnDrink(self.character, p.carbs) end
    if DanTraits_VitalityOnDrink then
        DanTraits_VitalityOnDrink(self.character, p.litres, p.carbs / p.litres, p.kcal / p.litres)
    end
    DanTraits_RunHooks("drink", nil, self.character, self.fluidContainer, p.litres, p.name, p.ratio)
    if p.alcoholic then DanTraits_RunHooks("alcoholDrunk", nil, self.character, self.fluidContainer, p.litres) end
end

local function wrapDrinkAction()
    DanTraits_Wrap(ISDrinkFluidAction, "updateEat", "drink-intake", function(original, self, delta, ...)
        local before, carbsTotal, kcalTotal, alcohol = 0, 0, 0, 0
        pcall(function() before = self.fluidContainer:getAmount() or 0 end)
        if before > 0 then
            pcall(function() carbsTotal = self.fluidContainer:getProperties():getCarbohydrates() or 0 end)
            pcall(function() kcalTotal = self.fluidContainer:getProperties():getCalories() or 0 end)
            pcall(function() alcohol = self.fluidContainer:getProperties():getAlcohol() or 0 end)
        end
        -- the fluid is read before the sip: the last one empties the container,
        -- and an empty container has no fluid to name (the "drink" hook's
        -- subscribers, Caffeine and Lactose, are handed the name and its share)
        local name, ratio = DanTraits_FluidName(self.fluidContainer), DanTraits_FluidRatio(self.fluidContainer)
        local result = original(self, delta, ...)
        local after = before
        pcall(function() after = self.fluidContainer:getAmount() or before end)
        local litres = before - after
        local p = rawget(self, "danDrink")
        if p and before > 0 and p.name ~= name then flushDrink(self); p = nil end
        if litres > 0 then
            if not p then
                p = { litres = 0, carbs = 0, kcal = 0, name = name, ratio = ratio, alcoholic = false }
                self.danDrink = p
            end
            p.litres = p.litres + litres
            p.carbs = p.carbs + litres * carbsTotal / before
            p.kcal = p.kcal + litres * kcalTotal / before
            if alcohol > 0 then p.alcoholic = true end
        end
        if (tonumber(delta) or 0) >= 1 then flushDrink(self) end
        return result
    end)
    -- a drink cancelled part way (stop) still went down; perform is the belt to complete's braces
    for _, method in ipairs({ "stop", "perform" }) do
        DanTraits_Wrap(ISDrinkFluidAction, method, "drink-intake", function(original, self, ...)
            flushDrink(self)
            return original(self, ...)
        end)
    end
end
wrapDrinkAction()
Events.OnGameStart.Add(wrapDrinkAction)


-- high blood sugar feeds a wound infection and slows healing: the Infection
-- file's hazard and growth hooks, scaled by how far up the high band we are
local function infectionSugar(player)
    if not diaHas(player) then return 0 end
    local d = player:getModData().DanTraits
    if not d or not d.glucose then return 0 end
    return math.max(0, math.min(1, (d.glucose - DIA.HIGH[1]) / (DIA.HIGH[3] - DIA.HIGH[1])))
end
-- a night with a low in it scores lower (Vitality scores the night; the flag is set by diaNightLow)
DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not d or not d.diaNightLow then return nil end
    d.diaNightLow = nil
    return quality * (1 - DIA.NIGHT_CUT)
end)

DanTraits_AddHook("infectionHazard", function(h, player)
    local t = infectionSugar(player)
    if t <= 0 then return nil end
    return h * (1 + DIA.INF_HAZARD * t)
end)
DanTraits_AddHook("infectionGrowth", function(k, player)
    local t = infectionSugar(player)
    if t <= 0 then return nil end
    return k * (1 + DIA.INF_GROWTH * t)
end)
