-- Project Zomboid Vitality Project: Vitality.
-- Not a trait: every character has it (sandbox option VitalityEnabled; off:
-- nothing scores or moves, DanTraits_VitalityEffect is 0 so every reader is neutral). Three slow scores (diet, exercise,
-- sleep) roll into one Vitality value (0..1, 0.5 neutral) that takes about
-- three days to cross a tier. Fresh produce, fresh meat and cooked dishes
-- with several ingredients score high; canned and dried food is neutral;
-- packaged snacks, candy, soda, rotten and burnt food score low; eating the
-- same few things all week costs a little, variety earns a little (what
-- counts as junk, fresh or cooked is read from the tags of DanTraits_Food.lua). Exercise
-- is the fitness system's regularity, or a day's activity (the metabolic rate
-- above rest) up to neutral. Sleep is scored per night, not per
-- nap: segments broken by less than an hour awake (night terrors, a quick
-- check outside; three hours for Restless Sleeper, who sleeps in two
-- halves) count as one night, hours are summed against what the
-- character needs (five for Needs Less Sleep, nine for Needs More Sleep,
-- seven otherwise), how rested they woke counts as much as the hours, and
-- each interruption costs a little. Above neutral: faster endurance
-- recovery (through the enduranceRegen hook of the stat delta pipeline), a lift
-- to mood and stress, slow health regeneration and better resistance to
-- catching a cold (the catchCold hook), and at Thriving a kilo on the base carry
-- weight. Below neutral: the reverse (health is never drained by this). The traits read the same value: asthma builds
-- slower or faster, diabetes resistance and insulin sensitivity shift,
-- depressive episodes come rarer or more often; a wound infection is less or
-- more likely to take hold and to climb (the infectionHazard and
-- infectionGrowth hooks), and the body clears an infection, a concussion, an
-- unstitched deep wound and a smoker's lungs faster or slower (the
-- infectionFight, concussionHeal, woundHeal and lungHeal hooks).
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local foodTags = DanTraits_FoodTags

local function vitOn() return DanTraits_SandboxOn("VitalityEnabled") end
-- diet
local VIT_MEAL_KCAL_FULL    = 4000    -- calories of consistent eating to move the diet score most of the way (about two days)
local VIT_MEAL_W_MAX        = 0.35    -- one meal can never move it more than this
local VIT_MEAL_W_MIN        = 0.01
local VIT_KCAL_PER_HUNGER   = 1500    -- fallback for items with no calorie data: hunger -0.2 = 300 kcal
local VIT_GRADE_FRESH       = 0.30    -- fresh produce or meat, on top of the 0.5 neutral
local VIT_GRADE_COOKED      = 0.10
local VIT_GRADE_INGREDIENT  = 0.10    -- per ingredient in a dish, up to three
local VIT_GRADE_JUNK        = -0.35   -- packaged snacks, candy, soda
local VIT_GRADE_ROTTEN      = -0.50
local VIT_GRADE_BURNT       = -0.30
local VIT_VARIETY_HOURS     = 72      -- window for counting distinct food types
local VIT_VARIETY           = { [0] = -0.10, -0.05, -0.05, 0, 0, 0.05, 0.10 }  -- by distinct types, capped at six
local VIT_STARVE_HUNGER     = 0.5     -- hunger above this (0..1) drags the diet score down
local VIT_STARVE_RATE       = 1 / 4320 -- per minute: three days from full to empty
local VIT_MEALS_KEEP        = 10
-- sleep
local VIT_SLEEP_FULL_HOURS  = 7       -- hours that count as a full night...
local VIT_SLEEP_LESS_HOURS  = 5       -- ...with Needs Less Sleep
local VIT_SLEEP_MORE_HOURS  = 9       -- ...with Needs More Sleep
local VIT_SLEEP_W           = 0.35    -- how much one night moves the sleep score
local VIT_SLEEP_REST_WEIGHT = 0.5     -- share of a night's quality that is "woke up rested" (the rest is hours)
local VIT_NIGHT_GAP_MIN     = DanTraits_NIGHT.gapMin   -- awake this long and the night is over; shorter and the next sleep is the same night
local VIT_NIGHT_WAKE_COST   = 0.05    -- quality lost per interruption (night terrors, getting up to check a noise)
local VIT_NIGHT_WAKE_MAX    = 0.2
-- last night, felt today: a bad night sets a "sleep debt" (0..1) that wears
-- off over the day and is eased by a nap
local VIT_DEBT_HOURS        = 14      -- awake hours for a full debt to clear
local VIT_DEBT_NAP_HOURS    = 2       -- a nap this long halves the debt
local VIT_DEBT_NAP_MAX      = DanTraits_NIGHT.napMaxHours   -- sleeps shorter than this count as naps, not nights
local VIT_DEBT_MOOD_FLOOR   = 25      -- unhappiness floor at a full debt
local VIT_DEBT_STRESS       = 0.0008  -- stress per minute at a full debt
local VIT_DEBT_FATIGUE      = 0.0006  -- fatigue per minute at a full debt (you tire earlier)
local VIT_DEBT_TIER         = { 0.25, 0.5, 0.75 }   -- Rough Night | Bad Night's Sleep | Barely Slept
local VIT_AWAKE_TIRED_HOURS = 20      -- awake longer than this and the sleep score drifts down
local VIT_AWAKE_RATE        = 1 / 1440
-- activity: a hard day's running, fighting and work counts as exercise up to
-- neutral; past that only training (fitness regularity) lifts it. Read from
-- the body's metabolic rate (METs: about 1.5 standing idle), effort above
-- VIT_ACTIVE_REST_MET summed as MET-minutes over a rolling day (d.vitActivity,
-- decaying with a one-day time constant, so it settles at the daily total)
local VIT_ACTIVE_REST_MET   = 3.0     -- measured in game: idle 1.5, walking about 3, chopping about 5.5, sprinting 7 to 8; walking does not count
local VIT_ACTIVE_DAY_TARGET = 150     -- MET-minutes above rest a day for full credit (about 30 to 50 minutes of hard effort)
local VIT_ACTIVE_CAP        = 0.5     -- the most the exercise score gets from activity alone
local VIT_ACTIVE_DECAY      = 1 / 1440
-- combine
local VIT_W_DIET, VIT_W_EXERCISE, VIT_W_SLEEP = 0.5, 0.3, 0.2
local VIT_SMOOTH            = 1 / 180 -- per minute toward the target (a few hours)
local VIT_TIER              = { 0.2, 0.4, 0.6, 0.8 }   -- Run Down | Sluggish | - | Fit | Thriving
local VIT_DEADZONE          = 0.1     -- no effect within this of 0.5
-- a new character starts neutral: for the first day the target never falls
-- below 0.5 (exercise regularity starts at 0 and variety at none, which alone
-- pull a fresh character to Sluggish within hours). Anything that lifts it,
-- a positive trait, still counts.
local VIT_GRACE_HOURS       = 24
-- negative Vitality traits (none yet) go here: they skip the grace
local VIT_NO_GRACE_TRAITS   = {}
-- effects at full strength (e = -1 or +1)
local VIT_CARRY_KG          = 1       -- kilos added to the base carry weight (an int, 8 by default, scaled by strength: about 12%) at Thriving, removed at Run Down
local VIT_CARRY_EFFECT      = 0.5     -- |effect| needed for the step (0.5 is exactly the Thriving and Run Down tier lines)
local VIT_ENDURANCE_REGEN   = 0.20
local VIT_MOOD_LIFT         = 0.15    -- unhappiness removed per minute at +1
local VIT_STRESS_LIFT       = 0.0005
local VIT_MOOD_FLOOR        = 20      -- unhappiness floor at -1
local VIT_MOOD_RAMP         = 1
local VIT_HEALTH_REGEN      = 0.03    -- health per minute at +1 (about two an hour); never drains
local VIT_COLD              = 0.30    -- cold catching x (1 - this x e)
-- what the traits read
local VIT_ASTHMA_BUILD      = 0.30    -- irritation build-up x (1 - this x e)
local VIT_DIA_RESISTANCE    = 0.15    -- Type 2 resistance - this x e
local VIT_DIA_SENSITIVITY   = 0.15    -- insulin effect x (1 + this x e)
local VIT_MDD_ONSET         = 0.30    -- episode chance x (1 - this x e)
local VIT_INF_HAZARD        = 0.25    -- wound infection chance x (1 - this x e)
local VIT_INF_GROWTH        = 0.25    -- infection climb x (1 - this x e)
local VIT_INF_FIGHT         = 0.30    -- the body's clearance of an infection with nothing spreading x (1 + this x e)
local VIT_CC_HEAL           = 0.25    -- concussion healing x (1 + this x e)
local VIT_WOUND_HEAL        = 0.25    -- unstitched deep wound healing x (1 + this x e)
local VIT_LUNG_HEAL         = 0.25    -- a smoker's lungs recovering x (1 + this x e)
local VIT_XP_TIER           = 4       -- Thriving: Fitness and Strength experience is multiplied...
local VIT_XP_MULT           = 1.5     -- ...by this

local function vitData(player)
    local d = traitData(player)
    d.vitDiet = d.vitDiet or 0.5
    d.vitExercise = d.vitExercise or 0
    d.vitSleep = d.vitSleep or 0.5
    d.vitality = d.vitality or 0.5
    d.vitFoodTypes = d.vitFoodTypes or {}
    return d
end

local clamp01 = DanTraits_Clamp01

-- 0..1 grade for a portion of food: 0.5 is "does no harm"
function DanTraits_GradeFood(item)
    local tags = foodTags(item)
    if tags.rotten then return 0.5 + VIT_GRADE_ROTTEN, "rotten" end
    if tags.burnt then return 0.5 + VIT_GRADE_BURNT, "burnt" end
    local packaged = tags.packaged
    local unhappy = 0
    pcall(function() unhappy = item:getUnhappyChange() or 0 end)
    local junk = tags.junk
    if not tags.junkSafe and packaged and unhappy < 0 then junk = true end
    if junk then return 0.5 + VIT_GRADE_JUNK, "junk" end
    local grade, why = 0.5, "plain"
    local ingredients = tags.ingredients
    if packaged or tags.canned then
        why = "packaged"
    elseif tags.fresh then
        grade = grade + VIT_GRADE_FRESH
        why = "fresh"
    end
    if tags.cooked then grade = grade + VIT_GRADE_COOKED; why = why .. ", cooked" end
    if ingredients > 0 then
        grade = grade + math.min(3, ingredients) * VIT_GRADE_INGREDIENT
        why = why .. ", " .. ingredients .. " ingredient" .. (ingredients > 1 and "s" or "")
    end
    return clamp01(grade), why
end

local hasVanillaTrait = DanTraits_HasVanillaTrait

local function sleepNeed(player)
    if hasVanillaTrait(player, "base:needslesssleep") then return VIT_SLEEP_LESS_HOURS end
    if hasVanillaTrait(player, "base:needsmoresleep") then return VIT_SLEEP_MORE_HOURS end
    return VIT_SLEEP_FULL_HOURS
end
DanTraits_VitalitySleepNeed = sleepNeed

local function pruneTypes(player, d, hour)
    local count = 0
    local window = DanTraits_RunHooks("varietyHours", VIT_VARIETY_HOURS, player)   -- Meal Prepper stretches it
    for foodType, at in pairs(d.vitFoodTypes) do
        if hour - at > window then d.vitFoodTypes[foodType] = nil else count = count + 1 end
    end
    d.vitVariety = count
    return count
end

local function recordMeal(player, d, name, grade, kcal, why)
    local hour = 0
    pcall(function() hour = player:getHoursSurvived() end)
    local w = math.max(VIT_MEAL_W_MIN, math.min(VIT_MEAL_W_MAX, kcal / VIT_MEAL_KCAL_FULL))
    d.vitDiet = clamp01(d.vitDiet + (grade - d.vitDiet) * w)
    d.vitMeals = d.vitMeals or {}
    table.insert(d.vitMeals, 1, { name = name, grade = grade, kcal = math.floor(kcal + 0.5), hour = hour, why = why })
    while #d.vitMeals > VIT_MEALS_KEEP do table.remove(d.vitMeals) end
end

-- called from the core eat hook with the portion actually eaten
function DanTraits_VitalityOnEat(player, item, fraction)
    if not vitOn() or not player or not item then return false end
    fraction = math.max(0, math.min(1, fraction or 1))
    if fraction <= 0 then return false end
    local d = vitData(player)
    local kcal = 0
    pcall(function() kcal = item:getCalories() or 0 end)
    if kcal <= 0 then
        pcall(function() kcal = math.abs(item:getHungChange() or 0) * VIT_KCAL_PER_HUNGER end)
    end
    kcal = kcal * fraction
    if kcal <= 0 then return false end
    local grade, why = DanTraits_GradeFood(item)
    grade = clamp01(DanTraits_RunHooks("foodGrade", grade, player, item, why))
    local name, foodType = "?", nil
    pcall(function() name = tostring(item:getType()) end)
    pcall(function() foodType = item:getFoodType() end)
    if foodType ~= nil and tostring(foodType) ~= "NoExplicit" then
        local hour = 0
        pcall(function() hour = player:getHoursSurvived() end)
        d.vitFoodTypes[tostring(foodType)] = hour
    end
    recordMeal(player, d, name, grade, kcal, why)
    return true
end

-- called from the drink hook: litres swallowed, and the fluid's per-litre carbohydrates and calories
function DanTraits_VitalityOnDrink(player, litres, carbsPerLitre, kcalPerLitre)
    if not vitOn() or not player or not litres or litres <= 0 then return false end
    local kcal = (kcalPerLitre or 0) * litres
    if kcal <= 0 then return false end
    local grade, why = 0.5, "drink"
    if (carbsPerLitre or 0) >= 50 then grade, why = 0.5 + VIT_GRADE_JUNK, "sugary drink" end
    recordMeal(player, vitData(player), "drink", grade, kcal, why)
    return true
end

-- -1..1 effect strength from the vitality value, with a dead zone around neutral
local function effectOf(v)
    if v >= 0.5 + VIT_DEADZONE then return (v - 0.5 - VIT_DEADZONE) / (0.5 - VIT_DEADZONE) end
    if v <= 0.5 - VIT_DEADZONE then return (v - 0.5 + VIT_DEADZONE) / (0.5 - VIT_DEADZONE) end
    return 0
end
DanTraits_VitalityEffectOf = effectOf

function DanTraits_VitalityEffect(player)
    if not vitOn() or not player then return 0 end
    local d = player:getModData().DanTraits
    if not d or d.vitality == nil then return 0 end
    return effectOf(d.vitality)
end

-- 0 Run Down, 1 Sluggish, 2 neutral, 3 Fit, 4 Thriving
local function tierOf(v) return DanTraits_TierOf(v, VIT_TIER) end
DanTraits_VitalityTier = tierOf

local function updateMoodle(player, v)
    if not MF or not MF.getMoodle then return end
    pcall(function()
        local moodle = MF.getMoodle("Vitality", player:getPlayerNum())
        if not moodle then return end
        moodle:setThresholds(nil, nil, VIT_TIER[1], VIT_TIER[2], VIT_TIER[3], VIT_TIER[4])
        moodle:setValue(v)
    end)
end

local function updateDebtMoodle(player, debt)
    DanTraits_BadMoodle(player, "SleptBadly", debt, VIT_DEBT_TIER)
end

function DanTraits_SleepDebt(player)
    local d = player and player:getModData().DanTraits
    return d and d.vitSleepDebt or 0
end

local function updateVitalityMinute(player, d)
    if not vitOn() then
        if d and d.vitCarryKg and d.vitCarryKg ~= 0 then   -- switched off: give back the kilo
            pcall(function() player:setMaxWeightBase(d.vitCarryBase or (player:getMaxWeightBase() - d.vitCarryKg)) end)
            d.vitCarryKg = 0
        end
        updateMoodle(player, 0.5)
        updateDebtMoodle(player, 0)
        return
    end
    d = vitData(player)
    local stats = player:getStats()
    local hour, asleep, fatigue, hunger = 0, false, 0, 0
    pcall(function() hour = player:getHoursSurvived() end)
    asleep = DanTraits_Asleep(player)
    pcall(function() fatigue = stats:get(CharacterStat.FATIGUE) or 0 end)
    pcall(function() hunger = stats:get(CharacterStat.HUNGER) or 0 end)

    -- diet: starving drags it down; variety is read for the combined score
    if hunger > VIT_STARVE_HUNGER then d.vitDiet = clamp01(d.vitDiet - VIT_STARVE_RATE) end
    local variety = pruneTypes(player, d, hour)
    local dietEffective = clamp01(d.vitDiet + VIT_VARIETY[math.min(6, variety)])

    -- exercise: the fitness system's regularity, or the day's activity up to neutral
    local met = 0
    if not asleep then pcall(function() met = player:getBodyDamage():getThermoregulator():getMetabolicRate() or 0 end) end
    d.vitActivity = (d.vitActivity or 0) * (1 - VIT_ACTIVE_DECAY) + math.max(0, met - VIT_ACTIVE_REST_MET)
    local active = VIT_ACTIVE_CAP * math.min(1, d.vitActivity / VIT_ACTIVE_DAY_TARGET)
    local trained = DanTraits_MddRegularity and DanTraits_MddRegularity(player) or 0
    d.vitExercise = clamp01(math.max(trained, active))

    -- sleep: segments accumulate into a night; the night is scored once the
    -- character has been up for an hour. Long stretches awake wear the score down.
    if asleep then
        if not d.vitAsleep then d.vitAsleep = true; d.vitSleepStart = hour end
        d.vitAwakeMin = 0
    else
        if d.vitAsleep then
            d.vitAsleep = false
            local slept = math.max(0, hour - (d.vitSleepStart or hour))
            d.vitNightHours = (d.vitNightHours or 0) + slept
            d.vitNightWakes = (d.vitNightWakes or 0) + 1
            d.vitNightFatigue = fatigue
        end
        d.vitAwakeMin = (d.vitAwakeMin or 0) + 1
        -- the gap and the wake count are offered to the traits (Restless Sleeper sleeps in two halves)
        if (d.vitNightHours or 0) > 0 and d.vitAwakeMin >= DanTraits_RunHooks("nightGap", VIT_NIGHT_GAP_MIN, player) then
            local need = sleepNeed(player)
            local quality = clamp01(d.vitNightHours / need) * (1 - VIT_SLEEP_REST_WEIGHT) + (1 - (d.vitNightFatigue or 0)) * VIT_SLEEP_REST_WEIGHT
            local wakes = DanTraits_RunHooks("nightWakes", d.vitNightWakes or 1, player)
            quality = quality - math.min(VIT_NIGHT_WAKE_MAX, math.max(0, wakes - 1) * VIT_NIGHT_WAKE_COST)
            quality = clamp01(DanTraits_RunHooks("nightQuality", quality, player, d, d.vitNightHours))
            d.vitSleep = clamp01(d.vitSleep + (quality - d.vitSleep) * VIT_SLEEP_W)
            d.vitLastSleepHours = d.vitNightHours
            d.vitLastSleepWakes = d.vitNightWakes
            d.vitLastSleepQuality = quality
            if d.vitNightHours < VIT_DEBT_NAP_MAX then
                d.vitSleepDebt = (d.vitSleepDebt or 0) * (1 - 0.5 * math.min(1, d.vitNightHours / VIT_DEBT_NAP_HOURS))
            else
                d.vitSleepDebt = 1 - quality
                local tier = DanTraits_TierOf(d.vitSleepDebt, VIT_DEBT_TIER)
                if tier > 0 then notify(player, "UI_DanTraits_SleptBadly" .. tier) end
            end
            -- the scored night, for anything that refills on it (the spoon budget, DanTraits_Spoons.lua)
            DanTraits_RunHooks("nightScored", nil, player, d, quality, d.vitNightHours, wakes, d.vitNightHours < VIT_DEBT_NAP_MAX)
            d.vitNightHours, d.vitNightWakes, d.vitNightFatigue = 0, 0, nil
        end
        if d.vitAwakeMin > VIT_AWAKE_TIRED_HOURS * 60 then d.vitSleep = clamp01(d.vitSleep - VIT_AWAKE_RATE) end
        if (d.vitSleepDebt or 0) > 0 then d.vitSleepDebt = math.max(0, d.vitSleepDebt - 1 / (VIT_DEBT_HOURS * 60)) end
    end
    local debt = d.vitSleepDebt or 0
    updateDebtMoodle(player, debt)
    if debt > 0 and not asleep then
        DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, VIT_DEBT_MOOD_FLOOR * debt, VIT_MOOD_RAMP)
        DanTraits_StatAdd(stats, CharacterStat.STRESS, VIT_DEBT_STRESS * debt)
        DanTraits_StatAdd(stats, CharacterStat.FATIGUE, VIT_DEBT_FATIGUE * debt)
    end

    -- combine, slowly
    local target = VIT_W_DIET * dietEffective + VIT_W_EXERCISE * d.vitExercise + VIT_W_SLEEP * d.vitSleep
    if hour < VIT_GRACE_HOURS then
        local grace = true
        for _, key in ipairs(VIT_NO_GRACE_TRAITS) do if hasTrait(player, key) then grace = false end end
        if grace then target = math.max(target, 0.5) end
    end
    d.vitTarget = target
    local before = tierOf(d.vitality)
    d.vitality = clamp01(d.vitality + (target - d.vitality) * VIT_SMOOTH)
    local tier = tierOf(d.vitality)
    if tier ~= before and tier ~= 2 then notify(player, "UI_DanTraits_VitTier" .. tier) end
    if tier ~= before and tier == 2 then
        DanTraits_NotifyGood(player, "UI_DanTraits_VitTier2")
    end
    updateMoodle(player, d.vitality)

    -- effects
    local e = effectOf(d.vitality)
    d.vitEffect = e
    pcall(function()
        -- carry weight: the base is an int the game never saves or changes
        -- (8 from the constructor, times a strength multiplier for the real
        -- figure), so the effect is a whole kilo on it, applied against a
        -- remembered base rather than reconstructed from the current value:
        -- fractional writes were truncated and the reconstruction then
        -- ratcheted the base down a kilo at a time. If the current value is
        -- not what was last set (reload, another mod), adopt it as the base.
        local current = player:getMaxWeightBase()
        local applied = d.vitCarryKg or 0
        local base = d.vitCarryBase
        if base == nil or current ~= base + applied then
            base, applied = current, 0
            d.vitCarryBase = base
        end
        local kg = 0
        if e >= VIT_CARRY_EFFECT then kg = VIT_CARRY_KG elseif e <= -VIT_CARRY_EFFECT then kg = -VIT_CARRY_KG end
        if kg ~= applied then player:setMaxWeightBase(base + kg) end
        d.vitCarryKg = kg
    end)
    if e > 0 then
        DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -VIT_MOOD_LIFT * e)
        DanTraits_StatAdd(stats, CharacterStat.STRESS, -VIT_STRESS_LIFT * e)
    elseif e < 0 then
        DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, VIT_MOOD_FLOOR * -e, VIT_MOOD_RAMP)
    end
    pcall(function()
        local bd = player:getBodyDamage()
        if e > 0 and bd:getOverallBodyHealth() < 100 then bd:AddGeneralHealth(VIT_HEALTH_REGEN * e) end
    end)
end

-- endurance recovery and cold catching go through the stat delta pipeline
-- (DanTraits_Util.lua): Vitality only says by how much, the pipeline applies it
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not vitOn() or not d or d.vitality == nil then return nil end
    return delta * (1 + VIT_ENDURANCE_REGEN * effectOf(d.vitality))
end)
DanTraits_AddHook("catchCold", function(delta, player, d)
    if not vitOn() or not d or d.vitality == nil then return nil end
    return delta * (1 - VIT_COLD * effectOf(d.vitality))
end)

-- what the traits read: multipliers and offsets from the current effect
function DanTraits_VitalityAsthmaBuild(player) return 1 - VIT_ASTHMA_BUILD * DanTraits_VitalityEffect(player) end
function DanTraits_VitalityDiaResistance(player) return -VIT_DIA_RESISTANCE * DanTraits_VitalityEffect(player) end
function DanTraits_VitalityDiaSensitivity(player) return 1 + VIT_DIA_SENSITIVITY * DanTraits_VitalityEffect(player) end
function DanTraits_VitalityMddOnset(player) return 1 - VIT_MDD_ONSET * DanTraits_VitalityEffect(player) end

-- wound infection (DanTraits_Infection.lua): Run Down invites it, Thriving fights it
DanTraits_AddHook("infectionHazard", function(h, player)
    local e = DanTraits_VitalityEffect(player)
    if e == 0 then return nil end
    return h * (1 - VIT_INF_HAZARD * e)
end)
DanTraits_AddHook("infectionGrowth", function(k, player)
    local e = DanTraits_VitalityEffect(player)
    if e == 0 then return nil end
    return k * (1 - VIT_INF_GROWTH * e)
end)

-- how fast the body clears what ails it: an infection, a concussion, an
-- unstitched deep wound, a smoker's lungs (each system offers the hook)
local function healsBy(k)
    return function(rate, player)
        local e = DanTraits_VitalityEffect(player)
        if e == 0 then return nil end
        return rate * (1 + k * e)
    end
end
DanTraits_AddHook("infectionFight", healsBy(VIT_INF_FIGHT))
DanTraits_AddHook("concussionHeal", healsBy(VIT_CC_HEAL))
DanTraits_AddHook("woundHeal", healsBy(VIT_WOUND_HEAL))
DanTraits_AddHook("lungHeal", healsBy(VIT_LUNG_HEAL))

-- Thriving: Fitness and Strength experience is x1.5. The event fires after
-- the game adds the experience; half of it is added again, guarded
-- against re-entry since that addition fires the event too.
local xpReentry = false
local function onAddXP(player, perk, amount)
    if xpReentry or not vitOn() or not player or not perk or not amount or amount <= 0 then return end
    if DanTraits_AgeXpBusy and DanTraits_AgeXpBusy() then return end   -- age's quiet top-up
    if not (Perks and (perk == Perks.Fitness or perk == Perks.Strength)) then return end
    local d = player:getModData().DanTraits
    if not d or d.vitality == nil or tierOf(d.vitality) < VIT_XP_TIER then return end
    xpReentry = true
    pcall(function() player:getXp():AddXP(perk, amount * (VIT_XP_MULT - 1)) end)
    xpReentry = false
end
Events.AddXP.Add(onAddXP)

DanTraits_Every("minute", "Vitality", updateVitalityMinute, 90)
