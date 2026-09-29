-- Project Zomboid Vitality Project: Vitality.
-- Not a trait: every character has it. Three slow scores (diet, exercise,
-- sleep) roll into one Vitality value (0..1, 0.5 neutral) that takes about
-- three days to cross a tier. Fresh produce, fresh meat and cooked dishes
-- with several ingredients score high; canned and dried food is neutral;
-- packaged snacks, candy, soda, rotten and burnt food score low; eating the
-- same few things all week costs a little, variety earns a little. Exercise
-- is the fitness system's regularity. Sleep is scored per night, not per
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
-- depressive episodes come rarer or more often.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

local VIT_ENABLED           = true
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
local VIT_NIGHT_GAP_MIN     = 60      -- awake this long and the night is over; shorter and the next sleep is the same night
local VIT_NIGHT_WAKE_COST   = 0.05    -- quality lost per interruption (night terrors, getting up to check a noise)
local VIT_NIGHT_WAKE_MAX    = 0.2
-- last night, felt today: a bad night sets a "sleep debt" (0..1) that wears
-- off over the day and is eased by a nap
local VIT_DEBT_HOURS        = 14      -- awake hours for a full debt to clear
local VIT_DEBT_NAP_HOURS    = 2       -- a nap this long halves the debt
local VIT_DEBT_NAP_MAX      = 3       -- sleeps shorter than this count as naps, not nights
local VIT_DEBT_MOOD_FLOOR   = 25      -- unhappiness floor at a full debt
local VIT_DEBT_STRESS       = 0.0008  -- stress per minute at a full debt
local VIT_DEBT_FATIGUE      = 0.0006  -- fatigue per minute at a full debt (you tire earlier)
local VIT_DEBT_TIER         = { 0.25, 0.5, 0.75 }   -- Rough Night | Bad Night's Sleep | Barely Slept
local VIT_AWAKE_TIRED_HOURS = 20      -- awake longer than this and the sleep score drifts down
local VIT_AWAKE_RATE        = 1 / 1440
-- combine
local VIT_W_DIET, VIT_W_EXERCISE, VIT_W_SLEEP = 0.5, 0.3, 0.2
local VIT_SMOOTH            = 1 / 180 -- per minute toward the target (a few hours)
local VIT_TIER              = { 0.2, 0.4, 0.6, 0.8 }   -- Run Down | Sluggish | - | Fit | Thriving
local VIT_DEADZONE          = 0.1     -- no effect within this of 0.5
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
local VIT_XP_TIER           = 4       -- Thriving: Fitness and Strength experience is multiplied...
local VIT_XP_MULT           = 2       -- ...by this

local JUNK_WORDS = {
    "candy", "chocolate", "chips", "crisps", "soda", "pop", "cola", "cookie", "cake", "donut", "doughnut", "gum",
    "lollipop", "marshmallow", "icecream", "tvdinner", "twinkie", "hostess", "jerky", "poptart", "cupcake", "candycane",
    "gummy", "caramel", "toffee", "fudge", "sugar",
}
local JUNK_SAFE = { "sugarcane", "chipsbowl" }

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
    local name = ""
    pcall(function() name = string.lower(tostring(item:getType() or "")) end)
    local function flag(method)
        local ok, res = pcall(function() return item[method](item) end)
        return ok and res == true
    end
    if flag("isRotten") then return 0.5 + VIT_GRADE_ROTTEN, "rotten" end
    if flag("isBurnt") then return 0.5 + VIT_GRADE_BURNT, "burnt" end
    local packaged = flag("isPackaged")
    local unhappy = 0
    pcall(function() unhappy = item:getUnhappyChange() or 0 end)
    local junk = false
    for _, safe in ipairs(JUNK_SAFE) do if name:find(safe, 1, true) then junk = nil end end
    if junk ~= nil then
        for _, word in ipairs(JUNK_WORDS) do if name:find(word, 1, true) then junk = true end end
        if packaged and unhappy < 0 then junk = true end
    end
    if junk then return 0.5 + VIT_GRADE_JUNK, "junk" end
    local grade, why = 0.5, "plain"
    local ingredients = 0
    pcall(function() if item:haveExtraItems() then ingredients = item:getExtraItems():size() end end)
    local cooked = flag("isCooked")
    if packaged or name:find("canned", 1, true) or name:find("dried", 1, true) then
        why = "packaged"
    elseif flag("isFresh") then
        grade = grade + VIT_GRADE_FRESH
        why = "fresh"
    end
    if cooked then grade = grade + VIT_GRADE_COOKED; why = why .. ", cooked" end
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

local function pruneTypes(d, hour)
    local count = 0
    for foodType, at in pairs(d.vitFoodTypes) do
        if hour - at > DanTraits_RunHooks("varietyHours", VIT_VARIETY_HOURS) then d.vitFoodTypes[foodType] = nil else count = count + 1 end
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
    if not VIT_ENABLED or not player or not item then return false end
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
    if not VIT_ENABLED or not player or not litres or litres <= 0 then return false end
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
    if not VIT_ENABLED or not player then return 0 end
    local d = player:getModData().DanTraits
    if not d or d.vitality == nil then return 0 end
    return effectOf(d.vitality)
end

local function tierOf(v)
    local tier = 0
    for i, threshold in ipairs(VIT_TIER) do if v >= threshold then tier = i end end
    return tier   -- 0 Run Down, 1 Sluggish, 2 neutral, 3 Fit, 4 Thriving
end
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
    if not VIT_ENABLED then return end
    d = vitData(player)
    local stats = player:getStats()
    local hour, asleep, fatigue, hunger = 0, false, 0, 0
    pcall(function() hour = player:getHoursSurvived() end)
    asleep = DanTraits_Asleep(player)
    pcall(function() fatigue = stats:get(CharacterStat.FATIGUE) or 0 end)
    pcall(function() hunger = stats:get(CharacterStat.HUNGER) or 0 end)

    -- diet: starving drags it down; variety is read for the combined score
    if hunger > VIT_STARVE_HUNGER then d.vitDiet = clamp01(d.vitDiet - VIT_STARVE_RATE) end
    local variety = pruneTypes(d, hour)
    local dietEffective = clamp01(d.vitDiet + VIT_VARIETY[math.min(6, variety)])

    -- exercise: the fitness system's regularity
    d.vitExercise = clamp01(DanTraits_MddRegularity and DanTraits_MddRegularity(player) or 0)

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
                local tier = 0
                for i, threshold in ipairs(VIT_DEBT_TIER) do if d.vitSleepDebt >= threshold then tier = i end end
                if tier > 0 then notify(player, "UI_DanTraits_SleptBadly" .. tier) end
            end
            d.vitNightHours, d.vitNightWakes, d.vitNightFatigue = 0, 0, nil
        end
        if d.vitAwakeMin > VIT_AWAKE_TIRED_HOURS * 60 then d.vitSleep = clamp01(d.vitSleep - VIT_AWAKE_RATE) end
        if (d.vitSleepDebt or 0) > 0 then d.vitSleepDebt = math.max(0, d.vitSleepDebt - 1 / (VIT_DEBT_HOURS * 60)) end
    end
    local debt = d.vitSleepDebt or 0
    updateDebtMoodle(player, debt)
    if debt > 0 and not asleep then
        pcall(function()
            DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, VIT_DEBT_MOOD_FLOOR * debt, VIT_MOOD_RAMP)
            DanTraits_StatAdd(stats, CharacterStat.STRESS, VIT_DEBT_STRESS * debt)
            DanTraits_StatAdd(stats, CharacterStat.FATIGUE, VIT_DEBT_FATIGUE * debt)
        end)
    end

    -- combine, slowly
    local target = VIT_W_DIET * dietEffective + VIT_W_EXERCISE * d.vitExercise + VIT_W_SLEEP * d.vitSleep
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
        d.vitCarryDelta = nil
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
    pcall(function()
        if e > 0 then
            DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -VIT_MOOD_LIFT * e)
            DanTraits_StatAdd(stats, CharacterStat.STRESS, -VIT_STRESS_LIFT * e)
        elseif e < 0 then
            DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, VIT_MOOD_FLOOR * -e, VIT_MOOD_RAMP)
        end
    end)
    pcall(function()
        local bd = player:getBodyDamage()
        if e > 0 and bd:getOverallBodyHealth() < 100 then bd:AddGeneralHealth(VIT_HEALTH_REGEN * e) end
    end)
end
DanTraits_updateVitalityMinute = updateVitalityMinute

-- endurance recovery and cold catching go through the stat delta pipeline
-- (DanTraits_Util.lua): Vitality only says by how much, the pipeline applies it
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not VIT_ENABLED or not d or d.vitality == nil then return nil end
    return delta * (1 + VIT_ENDURANCE_REGEN * effectOf(d.vitality))
end)
DanTraits_AddHook("catchCold", function(delta, player, d)
    if not VIT_ENABLED or not d or d.vitality == nil then return nil end
    return delta * (1 - VIT_COLD * effectOf(d.vitality))
end)

-- what the traits read: multipliers and offsets from the current effect
function DanTraits_VitalityAsthmaBuild(player) return 1 - VIT_ASTHMA_BUILD * DanTraits_VitalityEffect(player) end
function DanTraits_VitalityDiaResistance(player) return -VIT_DIA_RESISTANCE * DanTraits_VitalityEffect(player) end
function DanTraits_VitalityDiaSensitivity(player) return 1 + VIT_DIA_SENSITIVITY * DanTraits_VitalityEffect(player) end
function DanTraits_VitalityMddOnset(player) return 1 - VIT_MDD_ONSET * DanTraits_VitalityEffect(player) end

-- Thriving: Fitness and Strength experience is doubled. The event fires after
-- the game adds the experience; the same amount is added again, guarded
-- against re-entry since that addition fires the event too.
local xpReentry = false
local function onAddXP(player, perk, amount)
    if xpReentry or not VIT_ENABLED or not player or not perk or not amount or amount <= 0 then return end
    if not (Perks and (perk == Perks.Fitness or perk == Perks.Strength)) then return end
    local d = player:getModData().DanTraits
    if not d or d.vitality == nil or tierOf(d.vitality) < VIT_XP_TIER then return end
    xpReentry = true
    pcall(function() player:getXp():AddXP(perk, amount * (VIT_XP_MULT - 1)) end)
    xpReentry = false
end
Events.AddXP.Add(onAddXP)

DanTraits_Every("minute", "Vitality", updateVitalityMinute, 90)
