-- Project Zomboid Vitality Project: fitness (plans/fitness-overhaul.md).
-- Not a trait: everyone has it (sandbox option FitnessEnabled; off: nothing
-- is tracked and the moodles show nothing). Vanilla training is a radio
-- button and a number of minutes; this gives it a body that tires, recovers
-- and rewards a routine.
--
-- Four muscle groups (arms, chest, core, legs: the game's stiffness areas).
-- Each minute of training adds load to the exercise's groups (FIT_LOAD_MIN,
-- x the exercise's share and intensity: 30 minutes of one exercise is a full
-- load of 1). Load falls by FIT_RECOVER_H an hour, twice that asleep, times
-- the fitnessRecovery hook (Vitality, Age's band) and the bonuses below.
--
-- A group's state: Ready (recovered, trained 20 to 96 hours ago: the moment
-- to train it again), Rested, Recovering, Sore (load over 0.6), Overworked
-- (over 1). Experience from a rep is scaled by the state each group of the
-- exercise was in when the session reached it (the lowest of them): x1.25
-- Ready, x0.6 Sore, x0.3 Overworked, and x0.5 past 45 minutes on a group in
-- one session. Training a sore group can pull a muscle (sandbox FitnessStrain):
-- a pain floor, the part held stiff, that group off limits, for a day and a
-- half. 15 minutes in a session and you are Pumped for 3 hours (mood, stress
-- and boredom ease). Ten minutes of stretching and you are Loosened Up for 4
-- hours (faster recovery, Arthritis eased). Seven hard days in a row and you
-- are Overtrained until two easy ones.
--
-- Jogging, carrying a heavy load and hard work (chopping, digging, fighting)
-- count by themselves (DanTraits_FitnessData's hidden exercises, with their
-- own regularity). Everyday activity loads a quarter as much as training,
-- never past Sore (only the window's exercises overwork a group), and never
-- pulls a muscle (2026-10-26: a looting trip and five kills left every group
-- Overworked, a game minute being a few real seconds). A plan (DanTraits_FIT_PLANS) sets each day a target; every
-- target day of the last seven done is On Plan: experience and recovery
-- x1.15, Vitality's exercise score +0.1. Magazines add a lasting bonus to all
-- Fitness and Strength experience.
--
-- Mod data (ft prefix): ftLoad[group], ftLast[group] (hour last trained),
-- ftSess (the session: min, stretch, carried[g], ready[g], load[g]), ftGap
-- (minutes since the last training minute), ftLog[day][exercise] (minutes),
-- ftDay, ftStrain { g, part, h }, ftPumpMin, ftPumpMax, ftLastPump, ftRestless,
-- ftLooseMin, ftHardStreak, ftRestStreak, ftOvertrained, ftPlan, ftPlanStart,
-- ftOnPlan, ftMissDay, ftBackDay, ftWeeks, ftBench, ftStretchingNow,
-- ftTrainingNow; the moodle levels ftMoodle, ftPumpMoodle, ftOverMoodle.
require "DanTraits"
require "DanTraits_FitnessData"

local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local clamp01 = DanTraits_Clamp01

local function fitOn() return DanTraits_SandboxOn("FitnessEnabled") end
local function strainOn() return DanTraits_SandboxOn("FitnessStrain") end

-- load and recovery
local FIT_LOAD_MIN       = 1 / 30   -- load a minute of effort at share 1, intensity 1
local FIT_REP_EFFORT     = 0.5      -- minutes of effort a rep is worth (a set of 50 to exhaustion: 25, a load of 0.83)
local FIT_RECOVER_H      = 1 / 36   -- load off an hour awake
local FIT_SLEEP_RECOVER  = 2        -- x asleep
-- states
local FIT_READY_LOAD     = 0.15
local FIT_READY_FROM_H   = 20
local FIT_READY_UNTIL_H  = 96
local FIT_SORE_LOAD      = 0.6
local FIT_OVER_LOAD      = 1.0
local FIT_XP_READY       = 1.25
local FIT_XP_SORE        = 0.6
local FIT_XP_OVER        = 0.3
local FIT_LONG_LOAD      = 1.5      -- this much load on a group in one session (45 minutes)...
local FIT_XP_LONG        = 0.5      -- ...and experience from it halves
local FIT_XP_CAP         = 2        -- every boost on one gain together (Ready, plan, bench, traits, magazines, food) tops out here
-- a pulled muscle
local FIT_STRAIN_SORE    = 0.02     -- a minute, at a carried load of 1 (rising from 0 at 0.6)
local FIT_STRAIN_LONG    = 0.01     -- a minute, 0.5 load past the long-session line
local FIT_STRAIN_IMPROV  = 1.5      -- risk x with improvised weights
local FIT_STRAIN_BENCH   = 0.5      -- risk x at a weight bench
local FIT_STRAIN_HOURS   = 36
local FIT_STRAIN_PAIN    = 25       -- pain floor
local FIT_STRAIN_STIFF   = 30       -- the part's stiffness held at least this
-- sessions
local FIT_SESSION_GAP    = 10       -- minutes without training that end a session
local FIT_PUMP_AFTER     = 15       -- training minutes in a session for Pumped
local FIT_PUMP_MIN       = 180
local FIT_PUMP_STRESS    = 0.0004   -- a minute, Pumped and awake
local FIT_PUMP_UNHAPPY   = 0.05
local FIT_PUMP_BOREDOM   = 0.1
local FIT_PUMP_MDD       = 0.8      -- Depression's exercise relief reads at least this while Pumped
-- stretching
local FIT_LOOSE_AFTER    = 10       -- stretching minutes for Loosened Up
local FIT_LOOSE_MIN      = 240
local FIT_STRETCH_RECOVER = 2       -- recovery x while stretching
local FIT_LOOSE_RECOVER  = 1.25     -- recovery x while Loosened Up
local FIT_STRETCH_STIFF  = 2        -- stiffness fades x this while stretching...
local FIT_LOOSE_STIFF    = 1.25     -- ...and this while Loosened Up
local FIT_STRETCH_STRESS = 0.0003   -- a minute, stretching
local FIT_LOOSE_RELIEF   = 0.9      -- Arthritis's joints and MS's symptoms x this while Loosened Up
-- a fit body eases Arthritis and MS (never away): up to FIT_BODY_RELIEF off at
-- Fitness and Strength 10 / 10, by their levels, while it is kept up (Vitality's
-- exercise score, or the exercise regularity, at FIT_BODY_KEPT or more for all of it)
local FIT_BODY_RELIEF    = 0.2
local FIT_BODY_KEPT      = 0.5
-- overtraining
-- a hard day, for overtraining: this many minutes of hard training, plus
-- FIT_HARD_PER_LEVEL for each level of Fitness and Strength (a 5 / 5 character:
-- 100 minutes; 2 / 2: 64; 10 / 10: 160). Plans' targets are separate (20).
local FIT_HARD_BASE      = 40
local FIT_HARD_PER_LEVEL = 6        -- a level of either skill
local FIT_LEVEL_UNREAD   = 5        -- each skill's level when it cannot be read
local FIT_OVER_STREAK    = 7
local FIT_OVER_REST      = 2
local FIT_XP_OVERTRAINED = 0.7
local FIT_OVER_NIGHT     = 0.05
local FIT_OVER_ENDURANCE = 0.9
-- plans
local FIT_PLAN_BONUS     = 0.15     -- on plan: experience and recovery x (1 + this)
local FIT_PLAN_EXERCISE  = 0.1
-- equipment
local FIT_BENCH_XP       = 1.15
local FIT_BENCH_RADIUS   = 3
local FIT_BENCH_NAMES    = { Fitness_Contraption = true }
local FIT_IMPROV_MIN_K   = 0.5
local FIT_IMPROV_MAX_K   = 1.2
-- the counted-by-themselves exercises
local FIT_WORK_MET       = 5        -- metabolic rate for hard work
local FIT_REG_STEPS      = { dtjog = 2, dtcarry = 2, dtwork = 1 }   -- incRegularity calls a minute
-- everyday activity (the hidden exercises): load x this, never past max (Sore at most)
local EVERYDAY = { keys = { dtjog = true, dtcarry = true, dtwork = true }, load = 0.25, max = FIT_OVER_LOAD }
local FIT_LOG_DAYS       = 8
-- the fitness traits (scripts/DanTraits.txt, "Fitness traits"), one table to
-- keep the file's upvalues down:
--   wc Well Conditioned, nr Natural Runner, pl Weightlifter, ds Regimented,
--   ls Lingering Soreness, ip Injury Prone, ea Exercise Averse, ix Inflexible,
--   ej Endorphin Junkie; bb Bad Back (an age trait, AgeTraits.lua)
local TR = {
    wcRecover = 1.5, wcReady = 14, wcHeal = 2,
    lsRecover = 0.6, lsReady = 30,
    nrJogLoad = 0.5, nrJogCount = 2, nrRunXp = 1.25,
    plXp = 1.2,
    dsPlan = 2, dsForgive = 1,       -- the plan bonus x this; missed target days a week forgiven
    ipRisk = 2, ipHours = 54,
    eaPlan = 0.5, eaBoredom = 0.15, eaUnhappy = 0.05,   -- a training minute adds the boredom and unhappiness
    ixStretch = 0.5,                 -- stretching's boosts keep this share
    ixFade = 0.7,                    -- stiffness fades x this otherwise
    ixLooseRelief = 0.95, ixArthritis = 1.1,   -- Loosened Up eases half as much; the joints worse otherwise
    ejPumpMin = 360, ejLift = 2, ejRestlessH = 48, ejBoredom = 30, ejBoredomRamp = 0.5, ejStress = 0.15, ejStressRamp = 0.002,
    bbCore = 1.5,                    -- Bad Back: a pull in the core x this likelier
    bbLift = 0.008,                  -- Bad Back: back load a minute of a two-handed improvised lift
}
local hasTrait = DanTraits_HasTrait

-- time ----------------------------------------------------------------------------

local function nowHours()
    local h = 0
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return tonumber(h) or 0
end

-- the calendar day as a number (midnight to midnight)
local function dayIndex()
    local h, tod = 0, 0
    pcall(function()
        local gt = getGameTime()
        h, tod = gt:getWorldAgeHours(), gt:getTimeOfDay()
    end)
    return math.floor(((tonumber(h) or 0) - (tonumber(tod) or 0)) / 24 + 0.5)
end
DanTraits_FitDayIndex = dayIndex

local function fitData(player)
    local d = DanTraits_Data(player)
    d.ftLoad = d.ftLoad or {}
    d.ftLast = d.ftLast or {}
    d.ftLog = d.ftLog or {}
    return d
end

local function dayLog(d, day)
    d.ftLog = d.ftLog or {}
    local key = tostring(day)
    local log = d.ftLog[key]
    if not log then
        log = {}
        d.ftLog[key] = log
    end
    return log
end
function DanTraits_FitLog(d, day)
    return (d and d.ftLog and d.ftLog[tostring(day)]) or {}
end

-- the day's minutes ----------------------------------------------------------------

local function hasKind(spec, kind)
    for _, k in ipairs(spec and spec.kinds or {}) do
        if k == kind then return true end
    end
    return false
end

-- minutes of exercises of any of these kinds (each exercise once)
local function kindMinutes(log, kinds)
    local total = 0
    for key, minutes in pairs(log or {}) do
        local spec = DanTraits_FitExercise(key)
        for _, kind in ipairs(kinds) do
            if hasKind(spec, kind) then
                total = total + (tonumber(minutes) or 0)
                break
            end
        end
    end
    return total
end

-- hard minutes: training that is not stretching or work. A jog and a loaded
-- carry count half (2026-10-23, user's call): most looting is a loaded carry,
-- and at full weight a week of walking home encumbered was Overtrained
local FIT_HARD_HALF = { cardio = true, carry = true }
local function hardMinutes(log)
    local total = 0
    for key, minutes in pairs(log or {}) do
        local spec = DanTraits_FitExercise(key)
        if spec and not hasKind(spec, "mobility") and not hasKind(spec, "work") then
            local weight = 1
            for kind in pairs(FIT_HARD_HALF) do
                if hasKind(spec, kind) then weight = 0.5 end
            end
            total = total + (tonumber(minutes) or 0) * weight
        end
    end
    return total
end
DanTraits_FitHardMinutes = hardMinutes

-- a day's progress on a target: minutes, minutes needed, done
function DanTraits_FitTargetProgress(log, target)
    local t = DanTraits_FIT_TARGETS[target]
    if not t then return 0, 0, false end
    if t.rest then
        -- only the window's exercises break a rest day: running, carrying and
        -- fighting are everyday life (2026-10-26)
        local trained = {}
        for key, minutes in pairs(log or {}) do
            if not EVERYDAY.keys[key] then trained[key] = minutes end
        end
        local hard = hardMinutes(trained)
        return hard, DanTraits_FIT_REST_MAX, hard < DanTraits_FIT_REST_MAX
    end
    local minutes
    if t.hard then
        minutes = hardMinutes(log) + 0.5 * kindMinutes(log, { "work" })
    else
        minutes = kindMinutes(log, t.kinds)
    end
    return minutes, t.min, minutes >= t.min
end

-- plans ------------------------------------------------------------------------------

-- the plan's target for that day, nil without a plan or before it began
function DanTraits_FitPlanDay(d, day)
    local plan = d and DanTraits_FitPlan(d.ftPlan)
    if not plan or not d.ftPlanStart or day < d.ftPlanStart then return nil end
    return plan.days[((day - d.ftPlanStart) % 7) + 1]
end

-- On plan: a target day done in the last seven (today counts once it is),
-- and no missed target day in the last FIT_MISS_DAYS: a miss costs the bonus
-- for the two days after it, then it is back. The first `forgive` misses of
-- the last seven are let off (Regimented). Returns on, and when off for a
-- miss, the day missed and the day the bonus comes back.
local FIT_MISS_DAYS = 2
local function onPlan(d, today, forgive)
    if not DanTraits_FitPlan(d.ftPlan) then return false end
    local any, misses = false, {}
    for day = today - 6, today do   -- the last seven days, today included (the window draws the same seven)
        local target = DanTraits_FitPlanDay(d, day)
        if target and target ~= "rest" then
            local _, _, done = DanTraits_FitTargetProgress(DanTraits_FitLog(d, day), target)
            if done then
                any = true
            elseif day < today then
                misses[#misses + 1] = day
            end
        end
    end
    local latest = nil
    for i = (forgive or 0) + 1, #misses do
        if misses[i] >= today - FIT_MISS_DAYS then latest = misses[i] end
    end
    if latest then return false, latest, latest + FIT_MISS_DAYS + 1 end
    return any
end
DanTraits_FitOnPlan = onPlan

-- the on-plan bonus: doubled for the Regimented, halved for the Exercise Averse
local function planBonus(player)
    local bonus = FIT_PLAN_BONUS
    if hasTrait(player, "regimented") then bonus = bonus * TR.dsPlan end
    if hasTrait(player, "exerciseaverse") then bonus = bonus * TR.eaPlan end
    return bonus
end
DanTraits_FitPlanBonus = planBonus

function DanTraits_FitSetPlan(player, id)
    if not player then return false end
    local d = fitData(player)
    if id == nil or id == "" then
        d.ftPlan, d.ftPlanStart, d.ftOnPlan = nil, nil, nil
        return true
    end
    local plan = DanTraits_FitPlan(id)
    if not plan or not DanTraits_FitKnowsPlan(player, plan) then return false end
    d.ftPlan, d.ftPlanStart = id, dayIndex()
    d.ftOnPlan = false
    return true
end

-- the groups --------------------------------------------------------------------------

-- hours after training before a recovered group is Ready
local function readyFrom(player)
    if player and hasTrait(player, "wellconditioned") then return TR.wcReady end
    if player and hasTrait(player, "lingeringsoreness") then return TR.lsReady end
    return FIT_READY_FROM_H
end

function DanTraits_FitGroupState(player, d, g)
    d = d or fitData(player)
    if d.ftStrain and d.ftStrain.g == g then return "strained" end
    local load = (d.ftLoad or {})[g] or 0
    if load > FIT_OVER_LOAD then return "overworked" end
    if load > FIT_SORE_LOAD then return "sore" end
    if load >= FIT_READY_LOAD then return "recovering" end
    local last = (d.ftLast or {})[g]
    if last then
        local since = nowHours() - last
        if since >= readyFrom(player) and since <= FIT_READY_UNTIL_H then return "ready" end
    end
    return "rested"
end

-- the factor for one group in this session (its load when the session reached it)
local function groupFactor(d, g)
    local sess = d.ftSess or {}
    local carried = sess.carried and sess.carried[g]
    if carried == nil then carried = (d.ftLoad or {})[g] or 0 end
    local k = 1
    if carried > FIT_OVER_LOAD then
        k = FIT_XP_OVER
    elseif carried > FIT_SORE_LOAD then
        k = FIT_XP_SORE
    elseif sess.ready and sess.ready[g] then
        k = FIT_XP_READY
    end
    if ((sess.load or {})[g] or 0) > FIT_LONG_LOAD then k = k * FIT_XP_LONG end
    return k
end

local function itemKg(item)
    if not item then return 0 end
    local kg = 0
    pcall(function() kg = item:getActualWeight() end)
    if not kg or kg <= 0 then pcall(function() kg = item:getWeight() end) end
    return tonumber(kg) or 0
end
DanTraits_FitItemKg = itemKg

local function heldKg(player)
    local a, b = nil, nil
    pcall(function() a, b = player:getPrimaryHandItem(), player:getSecondaryHandItem() end)
    return math.max(itemKg(a), itemKg(b))
end

-- what an improvised weight is worth: its kilos against the real thing's
local function improvisedFactor(player, def)
    local ref = def and def.dtRef
    if not ref then return 1 end
    local kg = heldKg(player)
    if kg <= 0 then return 1 end
    return math.max(FIT_IMPROV_MIN_K, math.min(FIT_IMPROV_MAX_K, kg / ref))
end

-- everything that scales a rep's experience
local function trainingFactor(player, d, key)
    local spec = DanTraits_FitExercise(key)
    if not spec then return 1 end
    local k, any = 1, false
    for g, _ in pairs(spec.load or {}) do
        local f = groupFactor(d, g)
        if not any or f < k then k = f end
        any = true
    end
    if d.ftOvertrained then k = k * FIT_XP_OVERTRAINED end
    if d.ftOnPlan then k = k * (1 + planBonus(player)) end
    local def = FitnessExercises and FitnessExercises.exercisesType and FitnessExercises.exercisesType[key]
    if spec.improvised then k = k * improvisedFactor(player, def) end
    if (spec.weights or spec.improvised) and d.ftBench then k = k * FIT_BENCH_XP end
    if (spec.weights or spec.improvised) and hasTrait(player, "weightlifter") then k = k * TR.plXp end
    return DanTraits_RunHooks("fitnessXp", k, player, d, key)
end
DanTraits_FitTrainingFactor = trainingFactor

-- what the character is doing --------------------------------------------------------

local function queueHead(player)
    local action = nil
    pcall(function()
        local q = ISTimedActionQueue.getTimedActionQueue(player)
        action = q and q.queue and q.queue[1]
    end)
    return action
end

-- the exercise this minute, and whether it is the window's (or stretching)
local function currentExercise(player)
    local action = queueHead(player)
    if action then
        if action.Type == "ISFitnessAction" and action.exeDataType then
            local started = true
            if action.isStarted then pcall(function() started = action:isStarted() end) end
            if started then return action.exeDataType, true end
        elseif action.Type == "ISDanTraitsStretchAction" then
            return "dtstretch", true
        end
    end
    if DanTraits_Asleep(player) then return nil end
    local vehicle, moving, running, sprinting = false, false, false, false
    pcall(function()
        vehicle = player:getVehicle() ~= nil
        moving = player:isPlayerMoving() == true
        running = player:isRunning() == true
        sprinting = player:isSprinting() == true
    end)
    if vehicle then return nil end
    if moving and running and not sprinting then return "dtjog" end
    local heavy = 0
    pcall(function() heavy = player:getMoodles():getMoodleLevel(MoodleType.HEAVY_LOAD) or 0 end)
    if moving and heavy >= 1 then return "dtcarry" end
    local met = 0
    pcall(function() met = player:getBodyDamage():getThermoregulator():getMetabolicRate() or 0 end)
    if met >= FIT_WORK_MET and not running and not sprinting then return "dtwork" end
    return nil
end
DanTraits_FitCurrentExercise = currentExercise

-- regularity for the hidden exercises, the way the game raises it (never
-- while the window's exercise is running: that one is the current exercise).
-- init() once a session first, so the game has read our entries.
local fitInited = {}
local function addRegularity(player, key, steps)
    pcall(function()
        local fitness = player:getFitness()
        if not fitInited[player] then
            fitness:init()
            fitInited[player] = true
        end
        if fitness:getCurrentExe() ~= nil then return end
        fitness:setCurrentExercise(key)
        for _ = 1, steps do fitness:incRegularity() end
        fitness:setCurrentExercise(nil)
    end)
end

local function benchNearby(player)
    local found = false
    pcall(function()
        local cell = getCell()
        local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
        for dx = -FIT_BENCH_RADIUS, FIT_BENCH_RADIUS do
            for dy = -FIT_BENCH_RADIUS, FIT_BENCH_RADIUS do
                local sq = cell:getGridSquare(px + dx, py + dy, pz)
                local objects = sq and sq:getObjects()
                for i = 0, (objects and objects:size() or 0) - 1 do
                    local props = objects:get(i):getProperties()
                    if props and props:has("CustomName") and FIT_BENCH_NAMES[props:get("CustomName")] then
                        found = true
                        return
                    end
                end
            end
        end
    end)
    return found
end
DanTraits_FitBenchNearby = benchNearby

local function stopFitnessAction(player)
    local action = queueHead(player)
    if action and action.Type == "ISFitnessAction" then
        pcall(function() action:forceStop() end)
    end
end

-- a pulled muscle --------------------------------------------------------------------

local function groupName(g) return string.lower(getText("IGUI_DanTraits_FitGroup_" .. g)) end   -- "the arms"

local function pullMuscle(player, d, g)
    local parts = DanTraits_FIT_PARTS[g] or {}
    local part = parts[1]
    if #parts > 1 then part = parts[(ZombRand and ZombRand(#parts) or 0) + 1] or part end
    d.ftStrain = { g = g, part = part, h = hasTrait(player, "injuryprone") and TR.ipHours or FIT_STRAIN_HOURS }
    DanTraits_NotifyFmt(player, "UI_DanTraits_FitStrained", groupName(g))
    stopFitnessAction(player)
end

-- `scale`: the share of a minute this roll is for (a rep is FIT_REP_EFFORT)
local function rollStrain(player, d, spec, scale)
    local sess = d.ftSess
    local worst, risk = nil, 0
    for g, _ in pairs(spec.load or {}) do
        local carried = (sess.carried or {})[g] or 0
        local r = FIT_STRAIN_SORE * math.max(0, (carried - FIT_SORE_LOAD) / (FIT_OVER_LOAD - FIT_SORE_LOAD))
            + FIT_STRAIN_LONG * math.max(0, (((sess.load or {})[g] or 0) - FIT_LONG_LOAD) / 0.5)
        if r > risk then worst, risk = g, r end
    end
    if not worst or risk <= 0 then return end
    if spec.improvised and not hasTrait(player, "weightlifter") then risk = risk * FIT_STRAIN_IMPROV end
    if (spec.weights or spec.improvised) and d.ftBench then risk = risk * FIT_STRAIN_BENCH end
    if hasTrait(player, "injuryprone") then risk = risk * TR.ipRisk end
    if worst == "core" and hasTrait(player, "badback") then risk = risk * TR.bbCore end
    risk = tonumber(DanTraits_RunHooks("fitnessStrain", risk, player, d, spec)) or risk
    if DanTraits_Roll(risk * (scale or 1)) then pullMuscle(player, d, worst) end
end

local function strainMinute(player, d, asleep)
    local s = d.ftStrain
    if not s then return end
    s.h = (s.h or 0) - (asleep and 2 or 1) * (hasTrait(player, "wellconditioned") and TR.wcHeal or 1) / 60
    if s.h <= 0 then
        d.ftStrain = nil
        notifyGood(player, "UI_DanTraits_FitStrainHealed")
        return
    end
    -- the strainRelief hook (a muscle relaxant): the pain and the stiffness held, x this
    local relief = tonumber(DanTraits_RunHooks("strainRelief", 1, player, d)) or 1
    DanTraits_PainFloor(player, d, "FitStrain", FIT_STRAIN_PAIN * relief, 1, 2)
    pcall(function()
        local part = player:getBodyDamage():getBodyPart(BodyPartType[s.part])
        local floor = FIT_STRAIN_STIFF * relief
        if part and (part:getStiffness() or 0) < floor then part:setStiffness(floor) end
    end)
end

-- training: effort -------------------------------------------------------------------
-- Effort is counted in minutes of training. Jogging, carrying, hard work and
-- stretching add a minute each minute; the window's exercises add
-- FIT_REP_EFFORT a rep (DanTraits_FitOnRep, from the rep the game counts), so
-- a set of slow squats and a set of fast push-ups load the muscles alike.
-- The day's log, Pumped, the load, the strain roll and the plans all read
-- effort; the plans show a window exercise's as reps.

local function addEffort(player, d, key, spec, amount, today)
    local now = nowHours()
    local log = dayLog(d, today)
    local runner = key == "dtjog" and hasTrait(player, "naturalrunner")
    if runner then amount = amount * TR.nrJogCount end   -- a Natural Runner's jog counts double
    log[key] = (log[key] or 0) + amount
    local sess = d.ftSess
    local work = hasKind(spec, "work")
    if not work then
        sess.min = (sess.min or 0) + amount
        if sess.min >= FIT_PUMP_AFTER and not hasTrait(player, "exerciseaverse") then
            if (d.ftPumpMin or 0) <= 0 then notifyGood(player, "UI_DanTraits_FitPumped") end
            local junkie = hasTrait(player, "endorphinjunkie")
            d.ftPumpMax = junkie and TR.ejPumpMin or FIT_PUMP_MIN
            d.ftPumpMin = d.ftPumpMax
            d.ftLastPump = now
            d.ftRestless = nil
        end
    end
    -- Bad Back: a two-handed lift of something awkward goes on the back's load
    if key == "dtimprovcurl" and DanTraits_BadBackStrain then DanTraits_BadBackStrain(player, TR.bbLift * amount) end
    local everyday = EVERYDAY.keys[key]
    local intensity = (spec.intensity or 1) * (runner and TR.nrJogLoad or 1) * (everyday and EVERYDAY.load or 1)
    sess.carried, sess.ready, sess.load = sess.carried or {}, sess.ready or {}, sess.load or {}
    for g, share in pairs(spec.load or {}) do
        if sess.carried[g] == nil then
            sess.ready[g] = DanTraits_FitGroupState(player, d, g) == "ready"
            sess.carried[g] = d.ftLoad[g] or 0
        end
        local add = FIT_LOAD_MIN * amount * share * intensity / (runner and TR.nrJogCount or 1)
        if everyday then add = math.max(0, math.min(add, EVERYDAY.max - (d.ftLoad[g] or 0))) end
        d.ftLoad[g] = (d.ftLoad[g] or 0) + add
        sess.load[g] = (sess.load[g] or 0) + add
        d.ftLast[g] = now
    end
    if strainOn() and not d.ftStrain and not everyday then rollStrain(player, d, spec, amount) end
end

-- a session: a new one after FIT_SESSION_GAP minutes without training
local function session(d)
    if not d.ftSess or (d.ftGap or 0) > FIT_SESSION_GAP then d.ftSess = {} end
    d.ftGap = 0
    return d.ftSess
end

-- a rep of the window's exercise (DanTraits_FitnessActions.lua calls this
-- after the game counted it)
function DanTraits_FitOnRep(player, key)
    if not player or not key or not fitOn() then return end
    local spec = DanTraits_FitExercise(key)
    if not spec or spec.stretch then return end
    local d = fitData(player)
    if d.ftStrain and (spec.load or {})[d.ftStrain.g] then return end
    session(d)
    addEffort(player, d, key, spec, FIT_REP_EFFORT, dayIndex())
end

-- a training minute: everything for jogging, carrying, hard work and
-- stretching; for the window's exercises (counted by the rep) only what is
-- read by the minute
local function trainMinute(player, d, key, spec, windowed, today)
    -- a strained group is off limits in the window
    if windowed and d.ftStrain and (spec.load or {})[d.ftStrain.g] then
        DanTraits_NotifyFmt(player, "UI_DanTraits_FitStrainedStop", groupName(d.ftStrain.g))
        stopFitnessAction(player)
        return
    end
    d.ftTrainingNow = key
    if spec.stretch then
        local sess = d.ftSess
        dayLog(d, today)[key] = (dayLog(d, today)[key] or 0) + 1
        sess.stretch = (sess.stretch or 0) + 1
        d.ftStretchingNow = true
        if sess.stretch >= FIT_LOOSE_AFTER then
            if (d.ftLooseMin or 0) <= 0 then notifyGood(player, "UI_DanTraits_FitLoosened") end
            d.ftLooseMin = FIT_LOOSE_MIN
        end
        DanTraits_StatAdd(player:getStats(), CharacterStat.STRESS, -FIT_STRETCH_STRESS)
        return
    end
    -- Exercise Averse: hates every minute of it
    if not hasKind(spec, "work") and hasTrait(player, "exerciseaverse") then
        local stats = player:getStats()
        DanTraits_StatAdd(stats, CharacterStat.BOREDOM, TR.eaBoredom)
        DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, TR.eaUnhappy)
    end
    if spec.weights or spec.improvised then d.ftBench = benchNearby(player) or nil else d.ftBench = nil end
    if windowed then return end   -- the reps carry the rest
    addEffort(player, d, key, spec, 1, today)
    local steps = FIT_REG_STEPS[key]
    if steps then addRegularity(player, key, steps) end
end

-- recovery ----------------------------------------------------------------------------

-- a boost from stretching: an Inflexible character keeps only part of it
local function stretchK(player, k)
    if hasTrait(player, "inflexible") then return 1 + (k - 1) * TR.ixStretch end
    return k
end

local function recoveryMult(player, d, asleep)
    local mult = asleep and FIT_SLEEP_RECOVER or 1
    if d.ftStretchingNow then
        mult = mult * stretchK(player, FIT_STRETCH_RECOVER)
    elseif (d.ftLooseMin or 0) > 0 then
        mult = mult * stretchK(player, FIT_LOOSE_RECOVER)
    end
    if d.ftOnPlan then mult = mult * (1 + planBonus(player)) end
    if hasTrait(player, "wellconditioned") then mult = mult * TR.wcRecover end
    if hasTrait(player, "lingeringsoreness") then mult = mult * TR.lsRecover end
    local _, _, magazines = DanTraits_FitMagazineBonus(player)
    mult = mult * (1 + magazines)
    return tonumber(DanTraits_RunHooks("fitnessRecovery", mult, player, d)) or mult
end
DanTraits_FitRecoveryMult = recoveryMult

local function recover(player, d, asleep)
    local fall = FIT_RECOVER_H / 60 * recoveryMult(player, d, asleep)
    for _, g in ipairs(DanTraits_FIT_GROUPS) do
        local load = d.ftLoad[g]
        if load then
            -- the fitnessGroupRecovery hook: one group's own pace (a hot water bottle on it)
            load = load - fall * (tonumber(DanTraits_RunHooks("fitnessGroupRecovery", 1, player, d, g)) or 1)
            d.ftLoad[g] = load > 0 and load or nil
        end
    end
end

-- days --------------------------------------------------------------------------------

-- the minutes of hard training that make a hard day for this body
local function hardDay(player)
    local fit, str = FIT_LEVEL_UNREAD, FIT_LEVEL_UNREAD
    pcall(function() fit = player:getPerkLevel(Perks.Fitness) end)
    pcall(function() str = player:getPerkLevel(Perks.Strength) end)
    return FIT_HARD_BASE + FIT_HARD_PER_LEVEL * ((tonumber(fit) or FIT_LEVEL_UNREAD) + (tonumber(str) or FIT_LEVEL_UNREAD))
end
DanTraits_FitHardDay = hardDay

local function finishDay(player, d, day)
    local hard = hardMinutes(DanTraits_FitLog(d, day)) >= hardDay(player)
    if hard then
        d.ftHardStreak, d.ftRestStreak = (d.ftHardStreak or 0) + 1, 0
    else
        d.ftHardStreak, d.ftRestStreak = 0, (d.ftRestStreak or 0) + 1
        if d.ftOvertrained and d.ftRestStreak >= FIT_OVER_REST then
            d.ftOvertrained = nil
            notifyGood(player, "UI_DanTraits_FitOvertrainedOver")
        end
    end
    -- the end of a plan's week: every target day of it done
    if d.ftPlanStart and DanTraits_FitPlan(d.ftPlan) and day >= d.ftPlanStart + 6 and (day - d.ftPlanStart) % 7 == 6 then
        local all = true
        for x = day - 6, day do
            local target = DanTraits_FitPlanDay(d, x)
            if target and target ~= "rest" then
                local _, _, done = DanTraits_FitTargetProgress(DanTraits_FitLog(d, x), target)
                if not done then all = false end
            end
        end
        if all then
            d.ftWeeks = (d.ftWeeks or 0) + 1
            notifyGood(player, "UI_DanTraits_FitWeekDone")
        end
    end
end

local function rollDays(player, d, today)
    local last = d.ftDay
    d.ftDay = today
    if not last or today <= last then return end
    for day = last, math.min(today - 1, last + FIT_LOG_DAYS) do finishDay(player, d, day) end
    for key, _ in pairs(d.ftLog) do
        local day = tonumber(key)
        if not day or day < today - FIT_LOG_DAYS then d.ftLog[key] = nil end
    end
end

-- the minute ---------------------------------------------------------------------------

-- sandbox off: everything but the plan chosen goes (the log and the day too, or
-- a week later, switched back on, rollDays would replay stale days with their
-- notices and the hard streak would carry on; 2026-10-22)
local function clearFitness(player, d)
    d.ftLoad, d.ftSess, d.ftStrain, d.ftPumpMin, d.ftLooseMin, d.ftOvertrained = nil, nil, nil, nil, nil, nil
    d.ftOnPlan, d.ftBench, d.ftStretchingNow, d.ftTrainingNow, d.ftRestless = nil, nil, nil, nil, nil
    d.ftMissDay, d.ftBackDay, d.ftLastPump, d.ftPumpMax, d.ftGap = nil, nil, nil, nil, nil
    d.ftLog, d.ftLast, d.ftDay, d.ftHardStreak, d.ftRestStreak, d.ftWeeks = nil, nil, nil, nil, nil, nil
    d.ftMoodle, d.ftPumpMoodle, d.ftOverMoodle = 0, 0, 0
end

local function moodleLevels(d)
    local worst = 0
    for _, load in pairs(d.ftLoad or {}) do worst = math.max(worst, load) end
    if d.ftStrain then
        d.ftMoodle = 3
    elseif worst > FIT_OVER_LOAD then
        d.ftMoodle = 2
    elseif worst > FIT_SORE_LOAD then
        d.ftMoodle = 1
    else
        d.ftMoodle = 0
    end
    if (d.ftPumpMin or 0) > 0 then
        d.ftPumpMoodle = -2
    elseif (d.ftLooseMin or 0) > 0 then
        d.ftPumpMoodle = -1
    elseif d.ftRestless then
        d.ftPumpMoodle = 1   -- Endorphin Junkie, two days without a workout
    else
        d.ftPumpMoodle = 0
    end
    d.ftOverMoodle = d.ftOvertrained and 1 or 0
end

local function updateFitnessMinute(player, d)
    if not fitOn() then clearFitness(player, d) return end
    fitData(player)
    local today = dayIndex()
    rollDays(player, d, today)
    local asleep = DanTraits_Asleep(player)
    d.ftStretchingNow, d.ftTrainingNow = nil, nil

    -- training this minute, and the session it belongs to
    local key, windowed = currentExercise(player)
    local spec = key and DanTraits_FitExercise(key)
    if spec then
        session(d)
        trainMinute(player, d, key, spec, windowed, today)
    else
        d.ftGap = (d.ftGap or 0) + 1
        if d.ftGap > FIT_SESSION_GAP then d.ftSess, d.ftBench = nil, nil end
    end

    -- overtraining: the hard days in a row, today's included once it is hard
    local streak = (d.ftHardStreak or 0) + (hardMinutes(DanTraits_FitLog(d, today)) >= hardDay(player) and 1 or 0)
    if not d.ftOvertrained and streak >= FIT_OVER_STREAK then
        d.ftOvertrained = true
        notify(player, "UI_DanTraits_FitOvertrained")
    end
    -- on or off the plan, and why (the window shows it); a notice when it changes
    local was = d.ftOnPlan
    local on, missDay, backDay = onPlan(d, today, hasTrait(player, "regimented") and TR.dsForgive or 0)
    d.ftOnPlan, d.ftMissDay, d.ftBackDay = on, missDay, backDay
    if on and not was then
        notifyGood(player, "UI_DanTraits_FitOnPlanNow")
    elseif was and not on and missDay then
        notify(player, "UI_DanTraits_FitOffPlanNow")
    end

    recover(player, d, asleep)
    strainMinute(player, d, asleep)

    -- Pumped (an Endorphin Junkie's lifts twice as much) and Loosened Up
    local junkie = hasTrait(player, "endorphinjunkie")
    if (d.ftPumpMin or 0) > 0 then
        d.ftPumpMin = d.ftPumpMin - 1
        if not asleep then
            local stats = player:getStats()
            local lift = junkie and TR.ejLift or 1
            DanTraits_StatAdd(stats, CharacterStat.STRESS, -FIT_PUMP_STRESS * lift)
            DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -FIT_PUMP_UNHAPPY * lift)
            DanTraits_StatAdd(stats, CharacterStat.BOREDOM, -FIT_PUMP_BOREDOM * lift)
        end
    end
    -- an Endorphin Junkie two days without a workout: restless (the clock starts with the character)
    if junkie then
        local now = nowHours()
        d.ftLastPump = d.ftLastPump or now
        if (d.ftPumpMin or 0) <= 0 and now - d.ftLastPump >= TR.ejRestlessH then
            if not d.ftRestless then notify(player, "UI_DanTraits_FitRestless") end
            d.ftRestless = true
            local stats = player:getStats()
            DanTraits_FloorUp(stats, CharacterStat.BOREDOM, TR.ejBoredom, TR.ejBoredomRamp)
            DanTraits_FloorUp(stats, CharacterStat.STRESS, TR.ejStress, TR.ejStressRamp)
        end
    else
        d.ftRestless, d.ftLastPump = nil, nil
    end
    if (d.ftLooseMin or 0) > 0 and not d.ftStretchingNow then d.ftLooseMin = d.ftLooseMin - 1 end
    moodleLevels(d)
end

-- hooks the other systems offer ---------------------------------------------------------

local function fitD(player) return player and fitOn() and DanTraits_Data(player) or nil end

DanTraits_AddHook("nightQuality", function(quality, player, d)
    if fitOn() and d and d.ftOvertrained then return quality - FIT_OVER_NIGHT end
    return nil
end)

DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if fitOn() and d and d.ftOvertrained then return delta * FIT_OVER_ENDURANCE end
    return nil
end)

-- how much a fit body eases a chronic condition, 0..FIT_BODY_RELIEF: the
-- levels of Fitness and Strength, while the training is kept up
local function bodyRelief(player, d)
    local fit, str = 0, 0
    pcall(function() fit = player:getPerkLevel(Perks.Fitness) or 0 end)
    pcall(function() str = player:getPerkLevel(Perks.Strength) or 0 end)
    local levels = clamp01(((tonumber(fit) or 0) + (tonumber(str) or 0)) / 20)
    local kept = d.vitExercise or 0
    if DanTraits_MddRegularity then kept = math.max(kept, DanTraits_MddRegularity(player) or 0) end
    return FIT_BODY_RELIEF * levels * clamp01(kept / FIT_BODY_KEPT)
end
DanTraits_FitBodyRelief = function(player) local d = fitD(player); return d and bodyRelief(player, d) or 0 end

-- the factor on a chronic condition's symptoms: the body's relief, and
-- stretching's (an Inflexible character's half as much)
local function conditionFactor(player, d)
    local k = 1 - bodyRelief(player, d)
    if (d.ftLooseMin or 0) > 0 then
        k = k * (hasTrait(player, "inflexible") and TR.ixLooseRelief or FIT_LOOSE_RELIEF)
    end
    return k
end

-- Arthritis: a fit body and stretched joints ache less (an Inflexible character's more, unstretched)
DanTraits_AddHook("arthritisJoint", function(joint, player)
    local d = fitD(player)
    if not d then return nil end
    local k = conditionFactor(player, d)
    if (d.ftLooseMin or 0) <= 0 and hasTrait(player, "inflexible") then k = k * TR.ixArthritis end
    if k == 1 then return nil end
    return joint * k
end)

-- Multiple Sclerosis: the same relief on its stiffness, pain and fatigue (DanTraits_MS.lua)
DanTraits_AddHook("msRelief", function(k, player)
    local d = fitD(player)
    if not d then return nil end
    return k * conditionFactor(player, d)
end)

-- Depression: a workout counts as exercise for the day
DanTraits_AddHook("mddExercise", function(regular, player)
    local d = fitD(player)
    if d and (d.ftPumpMin or 0) > 0 then return math.max(regular, FIT_PUMP_MDD) end
    return nil
end)

-- Vitality: a plan followed lifts the exercise score
DanTraits_AddHook("exerciseScore", function(score, player, d)
    if fitOn() and d and d.ftOnPlan then return clamp01(score + FIT_PLAN_EXERCISE) end
    return nil
end)

-- Age's stiffness pacing: stretching hurries the fade; an Inflexible
-- character's lingers the rest of the time
DanTraits_AddHook("stiffFade", function(k, player, d)
    if not fitOn() or not d then return nil end
    if d.ftStretchingNow then return k * stretchK(player, FIT_STRETCH_STIFF) end
    if (d.ftLooseMin or 0) > 0 then return k * stretchK(player, FIT_LOOSE_STIFF) end
    if hasTrait(player, "inflexible") then return k * TR.ixFade end
    return nil
end)

-- for the other systems: what is being trained this minute (a key and its
-- spec; stretching and hard work included, the caller decides), how much of
-- a workout's afterglow is left (0..1), and whether the legs had a day of it
function DanTraits_FitTrainingNow(player)
    local d = fitD(player)
    local key = d and d.ftTrainingNow
    if not key then return nil, nil end
    return key, DanTraits_FitExercise(key)
end
function DanTraits_FitAfterglow(player)
    local d = fitD(player)
    if not d or (d.ftPumpMin or 0) <= 0 then return 0 end
    return clamp01(d.ftPumpMin / (d.ftPumpMax or FIT_PUMP_MIN))
end
-- minutes over the last seven days (today included) on exercises that load
-- this group at half a share or more (Bad Back reads the core)
function DanTraits_FitWeekMinutes(player, group)
    local d = fitD(player)
    if not d then return 0 end
    local today, total = dayIndex(), 0
    for day = today - 6, today do
        for key, minutes in pairs(DanTraits_FitLog(d, day)) do
            local spec = DanTraits_FitExercise(key)
            if spec and ((spec.load or {})[group] or 0) >= 0.5 then total = total + (tonumber(minutes) or 0) end
        end
    end
    return total
end

-- minutes today on exercises that load the legs at half a share or more
function DanTraits_FitLegMinutes(player)
    local d = fitD(player)
    if not d then return 0 end
    local total = 0
    for key, minutes in pairs(DanTraits_FitLog(d, dayIndex())) do
        local spec = DanTraits_FitExercise(key)
        if spec and ((spec.load or {}).legs or 0) >= 0.5 then total = total + (tonumber(minutes) or 0) end
    end
    return total
end

-- experience --------------------------------------------------------------------------
-- A rep (DanTraits_FitnessActions marks it in DanTraits_FitRep) is scaled by
-- the training factor; any Fitness or Strength experience by the magazines
-- and the fitnessXpAll hook (Cooking), the whole capped at FIT_XP_CAP.
-- The adjustment goes through Age's quiet adjust, so neither Age nor
-- Vitality stacks on it, and Age's own top-ups are skipped here.
local xpBusy = false
local function adjustXp(player, perk, extra)
    xpBusy = true
    if DanTraits_AgeXpAdjust then
        DanTraits_AgeXpAdjust(player, perk, extra)
    elseif extra > 0 then
        pcall(function() player:getXp():AddXP(perk, extra, false, false, false, false) end)
    end
    xpBusy = false
end

local function onFitnessAddXP(player, perk, amount)
    if xpBusy or not player or not perk or not amount or amount <= 0 or not fitOn() then return end
    if DanTraits_AgeXpBusy and DanTraits_AgeXpBusy() then return end
    if not (Perks and (perk == Perks.Fitness or perk == Perks.Strength)) then return end
    local d = DanTraits_Data(player)
    local strength, fitness = DanTraits_FitMagazineBonus(player)
    local k = 1 + (perk == Perks.Strength and strength or fitness)
    local rep = DanTraits_FitRep
    if rep and rep.player == player and rep.key then
        k = k * trainingFactor(player, d, rep.key)
    elseif perk == Perks.Fitness and hasTrait(player, "naturalrunner") then
        -- a Natural Runner's running (the game's Fitness gain from it)
        local running = false
        pcall(function() running = player:isRunning() == true or player:isSprinting() == true end)
        if running then k = k * TR.nrRunXp end
    end
    -- every gain, the window's or not (Cooking: Fuelled, the diet goals)
    k = k * (tonumber(DanTraits_RunHooks("fitnessXpAll", 1, player, d, perk)) or 1)
    -- the boosts together top out here; the sandbox's pace is on top
    k = math.min(k, FIT_XP_CAP)
    -- the sandbox's pace for training: all Fitness and Strength experience x this
    k = k * math.max(0, DanTraits_SandboxNum("FitnessXp", 100)) / 100
    if math.abs(k - 1) < 0.001 then return end
    adjustXp(player, perk, amount * (k - 1))
end
Events.AddXP.Add(onFitnessAddXP)

DanTraits_Every("minute", "Fitness", updateFitnessMinute, 40)
