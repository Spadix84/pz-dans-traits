-- Project Zomboid Vitality Project: strain, the cumulative cost of fighting.
-- Not a trait: every character has it (sandbox option StrainEnabled; off:
-- nothing is tracked, the moodle shows nothing, experience is the game's and
-- the four strain traits do nothing). Design: plans/strain.md; the numbers were
-- tuned with plans/strain_sim.py and ST below must match its P table.
--
-- Stress is a bar that empties itself: a character who fought hordes for
-- three days is fine after a quiet afternoon. Strain (d.strain, 0..100) is
-- the memory. It fills with fighting and shocks and drains over days with
-- rest, sleep and comforts. It never touches damage, accuracy, endurance or
-- swing speed: it slows what the fighting teaches.
--
-- Fills:
--   a kill            ST.KILL x (1 + k / ST.KILL_RAMP), k the kills since the last
--                     night's sleep; a kill from a vehicle counts ST.VEHICLE of one
--   panic over 40     ST.PANIC a minute
--   a new wound       scratch, laceration, deep wound (ST.WOUND); knocked down ST.KNOCK
--   a bite            ST.BITE; health under 25: ST.LOW_HEALTH once a day (shocks)
--   illness           fever, sepsis, food sickness, pain (an hour's worth at full)
--   withdrawal        an Alcoholic sober by stage, a Smoker by nicotine withdrawal
--   a hangover        ST.HANGOVER when one starts
-- Drains:
--   a calm hour       awake, no fight in the last ST.CALM_AFTER_H hours, anywhere
--   a night           ST.SLEEP_BED in a bed, ST.SLEEP_ROUGH without, x the night's quality
--   comforts          a shower or bath, fresh clothes, a Good Meal (by tier), an hour
--                     of reading or of a handheld game (SpiffBoy), Pumped: once a
--                     day full, the second half, then nothing; x1.5 at home (Homebody
--                     x2); four different ones in a day make that day's comforts x1.25
--   drink and smoke   being drunk (up to ST.DRINK_CAP a day), a cigarette (up to
--                     ST.CIG_CAP); an Alcoholic's drink and a Smoker's cigarette a quarter
-- A fever halves what calm hours and sleep take off. Combat strain (kills,
-- panic, wounds, knockdowns) is x0.6 for the Desensitized. The first week
-- counts half (sandbox StrainEarlyDays for how long, StrainEarlyRate for how much).
--
-- Tiers: At Ease (under 10, combat experience x1.1), Frayed (25), Worn Down
-- (50, unhappiness held at 15), Burnt Out (75, at 30), Breaking Point (100).
-- Combat experience (weapon skills, Aiming, Reloading, Strength, Fitness)
-- falls from x1 at 25 to x0.75 at 50, x0.4 at 75 and x0.15 at 100 (never under
-- sandbox StrainXpFloor); every other skill takes half that penalty, only over
-- 50. Taken back after the game adds it (Events.AddXP, DanTraits_AgeXpAdjust:
-- never below the level held), skipping Age's own quiet top-ups.
--
-- Breaking Point (sandbox StrainBreakdown): at 100 strain holds there until
-- the character breaks down. That waits for a safe moment (awake, no fight
-- for ST.BREAK_CALM_MIN minutes, no zombie within ST.BREAK_TILES), then the
-- character sits down where they are (ISStrainBreakdownAction) and cannot do
-- anything else for a while. Walking away or a zombie coming close ends it
-- unfinished, and it comes again at the next safe moment. Finished, strain
-- drops to ST.BREAK_RESET.
--
-- Traits: Level Headed (strain gained x0.5), High Strung (x1.5), Unwinds
-- Easily (every drain x1.5), Can't Switch Off (every drain x0.67, the variety
-- bonus needs five).
--
-- The links (phase 2). Panic counts only with a zombie within
-- ST.PANIC_ZOMBIE_TILES (an asthma attack, a hallucination or bleeding has
-- its own costs). MDD episodes, hallucinations, migraines, MS flares and
-- seizures come x DanTraits_StrainFactor (x2 Burnt Out); a Burnt Out
-- ex-smoker gets the cue cravings; a sensory overload starting adds
-- ST.OVERLOAD (DanTraits_Sensory.lua). Vitality's target (the vitalityTarget
-- hook) is held under Thriving while Burnt Out and lifted At Ease. Comforts:
-- Pumped x2 for an Endorphin Junkie, fresh clothes x2 and Line-Dried a
-- comfort of its own for a Homemaker, a Good Meal a tier up for Keen Cook,
-- every comfort but a meal or a workout at half in a depressive episode; a
-- Nomad's home bonus is any bed slept in twice of the last seven nights.
--
-- The API, for every system that feeds it (phase 2 of the design moves the
-- comfort watchers below into their own systems):
--   DanTraits_StrainAdd(player, source, amount, combat)   returns what was added
--   DanTraits_StrainEase(player, source, amount)          returns what came off
--   DanTraits_StrainComfort(player, kind, amount)         the once-a-day comfort rules
--   DanTraits_StrainLevel(player), DanTraits_StrainTier(player)
--   DanTraits_StrainXpMult(player, perk)
--
-- Mod data (st prefix): strain, stDay (the calendar day the counts are for),
-- stKills (since the last night), stFightH (world hours of the last fight),
-- stUsed (comfort uses today), stLastAt (game hours each comfort last
-- counted), stComfort (comforts eased today, before the variety bonus),
-- stVariety, stDrink, stCigs, stReadMin, stGameMin, stLowDay, stToday / stYesterday
-- (each source's total, + gained, - eased), stTold (the tier last told),
-- stBreak ("pending" | "active"), stBreakTry, stAsleep, stBed, stSleptMin,
-- stMark / stMarkMin / stTrend (the last hour's change), stWounds (per part:
-- which wounds it had), stKnocked, stHangover, stGlowMin, stPump, stFresh.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local hasVanillaTrait = DanTraits_HasVanillaTrait
local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood

local function strainOn() return DanTraits_SandboxOn("StrainEnabled") end

local ST = {
    -- fills
    KILL = 0.1,              -- a melee kill...
    KILL_RAMP = 100,         -- ...x (1 + kills since the last night / this)
    VEHICLE = 1 / 3,         -- a kill from a vehicle counts this share of one (cost and count)
    PANIC_AT = 40,           -- panic (0..100) over this...
    PANIC = 0.1,             -- ...costs this a minute
    WOUND = { scratch = 1, cut = 2, deep = 3 },
    BITE = 50,
    KNOCK = 1.5,             -- knocked down
    LOW_HEALTH_AT = 25,      -- overall health under this...
    LOW_HEALTH = 50,         -- ...costs this, once a day
    FEVER = 0.25,            -- an hour at full fever (a spreading wound infection)
    SEPSIS = 0.5,            -- an hour, on top
    FOOD_SICK = 0.15,        -- an hour at full food sickness
    PAIN = 0.15,             -- an hour at full pain
    ALC = { 0.15, 0.3, 0.5 },   -- an hour awake, an Alcoholic in craving, shakes, delirium
    NIC = 0.1,               -- an hour awake at full nicotine withdrawal
    HANGOVER = 2,
    -- drains
    CALM = 0.375,            -- an hour awake...
    CALM_AFTER_H = 2,        -- ...this long after the last fight
    SICK_REST = 0.5,         -- calm hours and sleep x this with a fever
    SLEEP_BED = 4,           -- a night x its quality
    SLEEP_ROUGH = 2,
    SLEEP_MIN_H = 3,         -- shorter is a nap (Vitality off: the fallback counts its own)
    COMFORT = { shower = 2, laundry = 2, read = 2, pumped = 2, game = 2 },
    MEAL = { 2, 3, 4 },      -- a Good Meal by the dish's tier
    REPEAT = { 1, 0.5 },     -- the first and second of a comfort in a day; then nothing
    DEBOUNCE_H = 0.5,        -- the same comfort again this soon is the same one
    HOME = 1.5, HOMEBODY = 2,
    VARIETY_N = 4, VARIETY = 1.25,
    READ_MIN = 60,           -- minutes of reading for one comfort
    GAME_MIN = 60,           -- minutes of a handheld game for one (DanTraits_SpiffBoy.lua)
    DRUNK = 2, TIPSY = 0.75, -- an hour at Drunk 2+, at Drunk 1
    DRINK_CAP = 8,
    CIG = 0.75, CIG_CAP = 3,
    ADDICT = 0.25,           -- an Alcoholic's drink, a Smoker's cigarette
    -- who
    DESENSITIZED = 0.6,      -- combat strain
    LEVEL_HEADED = 0.5, HIGHLY_STRUNG = 1.5,
    UNWINDS = 1.5, CANT_SWITCH = 0.67, CANT_SWITCH_VARIETY = 5,
    -- tiers
    TIERS = { 25, 50, 75, 100 },
    AT_EASE = 10,
    FLOOR = { 0, 15, 30, 30 },   -- unhappiness held up by tier
    FLOOR_RAMP = 0.5,
    XP = { { 25, 1.0 }, { 50, 0.75 }, { 75, 0.4 }, { 100, 0.15 } },
    XP_EASE = 1.1,
    XP_OTHER_FROM = 50,
    -- Breaking Point
    BREAK_CALM_MIN = 10,
    BREAK_TILES = 12,
    BREAK_NEAR_TILES = 4,    -- a zombie this close ends it
    BREAK_RESET = 60,
    BREAK_RETRY_MIN = 5,     -- queued and not started: try again after this
    BREAK_SAD = 50,
    -- the links (phase 2)
    CONDITION = 4 / 3,       -- MDD, Hallucinations, Migraine, MS, Epilepsy: chance x (1 + this x strain/100)
    PANIC_ZOMBIE_TILES = 15, -- panic counts only with a zombie this close
    EPISODE_COMFORT = 0.5,   -- a depressive episode: comforts x this, but not a meal or a workout
    ENDORPHIN = 2,           -- Endorphin Junkie: Pumped
    HOMEMAKER = 2,           -- Homemaker: fresh clothes; and Line-Dried is a comfort of its own
    LINE_DRIED = 2,
    OVERLOAD = 5,            -- Sensory Issues: a meltdown or a shutdown starting
    NOMAD_WINDOW = 7, NOMAD_NIGHTS = 2,   -- Nomad: a bed slept in twice of the last seven nights is home
    VIT_CAP = 0.79,          -- Burnt Out: Vitality's target held under Thriving
    VIT_EASE = 0.05,         -- At Ease: Vitality's target this much higher
}
DanTraits_StrainST = ST   -- tests

-- clock and data ---------------------------------------------------------------------

local function nowHours()
    local h = 0
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h
end

-- the calendar day: midnight to midnight
local function dayIndex()
    local day = 0
    pcall(function()
        local gt = getGameTime()
        day = math.floor((gt:getWorldAgeHours() - (gt:getTimeOfDay() or 0)) / 24 + 0.5)
    end)
    return day
end

local function newDay(d)
    local day = dayIndex()
    if d.stDay == day then return end
    d.stDay = day
    d.stUsed, d.stLastAt, d.stComfort, d.stVariety = {}, {}, 0, nil
    d.stDrink, d.stCigs, d.stReadMin, d.stGameMin = 0, 0, 0, 0
    d.stYesterday, d.stToday = d.stToday, {}
end

local function tally(d, source, amount)
    d.stToday = d.stToday or {}
    d.stToday[source] = (d.stToday[source] or 0) + amount
end

local function tierOf(s)
    return DanTraits_TierOf(s, ST.TIERS)
end

local function early(player)
    local days = DanTraits_SandboxNum("StrainEarlyDays", 7)
    local hours = 0
    pcall(function() hours = player:getHoursSurvived() or 0 end)
    return hours < days * 24
end

-- the tier notices: each climb (again after falling back under it), and At
-- Ease once a climb to Worn Down or worse is all behind you
local function tell(player, d, s)
    local tier = tierOf(s)
    if tier > (d.stTold or 0) then notify(player, "UI_DanTraits_Strain" .. tier) end
    d.stTold = tier
    d.stPeak = math.max(d.stPeak or 0, tier)
    if s < ST.AT_EASE then
        if d.stPeak >= 2 then notifyGood(player, "UI_DanTraits_StrainAtEase") end
        d.stPeak = 0
    end
end

local function setStrain(player, d, s)
    s = math.max(0, math.min(100, s))
    d.strain = s
    if s >= 100 and not d.stBreak and DanTraits_SandboxOn("StrainBreakdown") then
        d.stBreak = "pending"
        notify(player, "UI_DanTraits_StrainBreaking")
    end
    tell(player, d, s)
end

-- the API -----------------------------------------------------------------------------

function DanTraits_StrainLevel(player)
    if not player or not strainOn() then return 0 end
    return DanTraits_Data(player).strain or 0
end

function DanTraits_StrainTier(player)
    return tierOf(DanTraits_StrainLevel(player))
end

-- the conditions' multiplier on an episode or attack chance: x1 at no
-- strain, about x1.33 Frayed, x2 Burnt Out, x2.33 at breaking point
function DanTraits_StrainFactor(player)
    return 1 + ST.CONDITION * DanTraits_StrainLevel(player) / 100
end

-- strain gained: amount before the multipliers; combat marks a fight (the
-- calm clock starts over) and takes the Desensitized cut
function DanTraits_StrainAdd(player, source, amount, combat)
    amount = tonumber(amount) or 0
    if not player or amount <= 0 or not strainOn() then return 0 end
    local d = DanTraits_Data(player)
    newDay(d)
    local k = DanTraits_SandboxNum("StrainGain", 100) / 100
    if early(player) then k = k * DanTraits_SandboxNum("StrainEarlyRate", 50) / 100 end
    if hasTrait(player, "levelheaded") then k = k * ST.LEVEL_HEADED end
    if hasTrait(player, "highlystrung") then k = k * ST.HIGHLY_STRUNG end
    if combat then
        d.stFightH = nowHours()
        if hasVanillaTrait(player, "base:desensitized") then k = k * ST.DESENSITIZED end
    end
    local add = amount * k
    if add <= 0 then return 0 end
    tally(d, source, add)
    setStrain(player, d, (d.strain or 0) + add)
    return add
end

-- the multiplier on every drain
local function easeMult(player)
    local k = DanTraits_SandboxNum("StrainEase", 100) / 100
    if hasTrait(player, "unwindseasily") then k = k * ST.UNWINDS end
    if hasTrait(player, "cantswitchoff") then k = k * ST.CANT_SWITCH end
    return k
end

-- strain off: amount before the multipliers. Nothing comes off while a
-- breakdown is waiting: it has to happen first.
function DanTraits_StrainEase(player, source, amount)
    amount = tonumber(amount) or 0
    if not player or amount <= 0 or not strainOn() then return 0 end
    local d = DanTraits_Data(player)
    newDay(d)
    if d.stBreak then return 0 end
    local s = d.strain or 0
    local off = math.min(s, amount * easeMult(player))
    if off <= 0 then return 0 end
    tally(d, source, -off)
    setStrain(player, d, s - off)
    return off
end

-- a Nomad: no home, but a bed slept in twice of the last seven nights does
-- for comforts (DanTraits_Home.lua's place helpers)
local function nomadAtHome(player, d)
    local nights = d.stNomadNights
    if not nights or not DanTraits_HomeSamePlace or not DanTraits_HomeAtPlace then return false end
    local x, y = nil, nil
    pcall(function() x, y = player:getX(), player:getY() end)
    if not x then return false end
    for i = 1, #nights do
        if DanTraits_HomeAtPlace(nights[i], x, y) then
            local n = 0
            for j = 1, #nights do if DanTraits_HomeSamePlace(nights[i], nights[j]) then n = n + 1 end end
            if n >= ST.NOMAD_NIGHTS then return true end
        end
    end
    return false
end

local function atHomeMult(player, d)
    if hasTrait(player, "nomad") then return nomadAtHome(player, d) and ST.HOME or 1 end
    if not d.hmAtHome or not DanTraits_HomeStrength or DanTraits_HomeStrength(player) <= 0 then return 1 end
    return hasTrait(player, "homebody") and ST.HOMEBODY or ST.HOME
end

-- what the traits and conditions make of one comfort
local function comfortMult(player, d, kind)
    local k = 1
    if kind == "pumped" and hasTrait(player, "endorphinjunkie") then k = k * ST.ENDORPHIN end
    if kind == "laundry" and hasTrait(player, "homemaker") then k = k * ST.HOMEMAKER end
    -- a depressive episode: comforts feel hollow, but food and exercise still reach it
    if d.mddEpisode and kind ~= "meal" and kind ~= "pumped" and hasTrait(player, "spiraling") then k = k * ST.EPISODE_COMFORT end
    return k
end

-- a comfort: the first today in full, the second at half, then nothing (the
-- same one within ST.DEBOUNCE_H is the same one); x1.5 at home; the day's
-- ST.VARIETY_N-th different comfort makes the day's comforts x ST.VARIETY
-- (this one, and a top-up for the ones before it)
function DanTraits_StrainComfort(player, kind, amount)
    amount = tonumber(amount) or ST.COMFORT[kind] or 0
    if not player or amount <= 0 or not strainOn() then return 0 end
    local d = DanTraits_Data(player)
    newDay(d)
    d.stUsed, d.stLastAt = d.stUsed or {}, d.stLastAt or {}
    local now = nowHours()
    local last = d.stLastAt[kind]
    if last and now - last < ST.DEBOUNCE_H then return 0 end
    d.stLastAt[kind] = now
    local uses = (d.stUsed[kind] or 0) + 1
    d.stUsed[kind] = uses
    local share = ST.REPEAT[uses] or 0
    if share <= 0 then return 0 end
    local base = amount * share * atHomeMult(player, d) * comfortMult(player, d, kind)
    local need = hasTrait(player, "cantswitchoff") and ST.CANT_SWITCH_VARIETY or ST.VARIETY_N
    local kinds = 0
    for _, n in pairs(d.stUsed) do if n > 0 then kinds = kinds + 1 end end
    local amountNow = base
    if kinds >= need then
        amountNow = base * ST.VARIETY
        if not d.stVariety then
            d.stVariety = true
            amountNow = amountNow + (d.stComfort or 0) * (ST.VARIETY - 1)
            notifyGood(player, "UI_DanTraits_StrainDayOff")
        end
    end
    d.stComfort = (d.stComfort or 0) + base
    return DanTraits_StrainEase(player, "comfort:" .. kind, amountNow)
end

-- experience ---------------------------------------------------------------------------

local function isCombatPerk(perk)
    if not perk or not Perks then return false end
    if perk == Perks.Strength or perk == Perks.Fitness then return true end
    local parent = nil
    pcall(function() parent = perk:getParent() end)
    return parent ~= nil and (parent == Perks.Combat or parent == Perks.Firearm)
end
DanTraits_StrainIsCombatPerk = isCombatPerk

local function curve(s)
    local pts = ST.XP
    if s <= pts[1][1] then return pts[1][2] end
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        if s <= b[1] then return a[2] + (b[2] - a[2]) * (s - a[1]) / (b[1] - a[1]) end
    end
    return pts[#pts][2]
end

-- the experience multiplier on this skill now
function DanTraits_StrainXpMult(player, perk)
    if not player or not strainOn() then return 1 end
    local s = DanTraits_Data(player).strain or 0
    local floor = DanTraits_SandboxNum("StrainXpFloor", 15) / 100
    local m = math.max(math.min(1, floor), curve(s))
    if isCombatPerk(perk) then
        if s < ST.AT_EASE then return ST.XP_EASE end
        return m
    end
    if s <= ST.XP_OTHER_FROM then return 1 end
    return 1 - (1 - m) / 2
end

-- after the game adds it: the difference, through Age's quiet adjust (never
-- below the level held; while it runs, its own event is skipped here)
local function onStrainAddXP(player, perk, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 or not player or not strainOn() then return end
    if not DanTraits_AgeXpAdjust or (DanTraits_AgeXpBusy and DanTraits_AgeXpBusy()) then return end
    local m = DanTraits_StrainXpMult(player, perk)
    if m == 1 then return end
    DanTraits_AgeXpAdjust(player, perk, amount * (m - 1))
end
if Events and Events.AddXP then Events.AddXP.Add(onStrainAddXP) end

-- kills -------------------------------------------------------------------------------

function DanTraits_StrainKill(player, fromVehicle)
    if not player or not strainOn() then return 0 end
    local d = DanTraits_Data(player)
    local share = fromVehicle and ST.VEHICLE or 1
    d.stKills = (d.stKills or 0) + share
    return DanTraits_StrainAdd(player, fromVehicle and "vehicleKill" or "kill", ST.KILL * share * (1 + d.stKills / ST.KILL_RAMP), true)
end

local function onZombieDead(zombie)
    if not zombie or not strainOn() then return end
    local killer = nil
    pcall(function() killer = zombie:getAttackedBy() end)
    if not killer then return end
    for i = 0, 3 do
        local player = getSpecificPlayer(i)
        if player and player == killer then
            local inCar = false
            pcall(function() inCar = player:getVehicle() ~= nil end)
            DanTraits_StrainKill(player, inCar)
            return
        end
    end
end
DanTraits_StrainOnZombieDead = onZombieDead
if Events and Events.OnZombieDead then Events.OnZombieDead.Add(function(z) DanTraits_Guard("Strain kill", onZombieDead, z) end) end

-- wounds: a wound a part did not have last minute
local WOUNDS = { { "scratch", "getScratchTime" }, { "cut", "getCutTime" }, { "deep", "getDeepWoundTime" }, { "bite", "getBiteTime" } }

local function scanWounds(player, d)
    local seen = d.stWounds or {}
    d.stWounds = seen
    local first = d.stWoundsSeen == nil
    d.stWoundsSeen = true
    DanTraits_EachPart(player, function(part, name)
        local key = tostring(name)
        local had = seen[key] or {}
        local now = {}
        for _, w in ipairs(WOUNDS) do
            local on = DanTraits_PartNum(part, w[2]) > 0
            now[w[1]] = on or nil
            if on and not had[w[1]] and not first then
                if w[1] == "bite" then
                    d.stFightH = nowHours()
                    DanTraits_StrainAdd(player, "bite", ST.BITE, false)
                else
                    DanTraits_StrainAdd(player, w[1], ST.WOUND[w[1]], true)
                end
            end
        end
        seen[key] = now
    end, "Strain")
end

-- knocked down: watched every frame (it is over in seconds)
local function updateStrainFrame(player, d)
    if not strainOn() then return end
    local down = false
    pcall(function() down = player:isKnockedDown() == true end)
    if down and not d.stKnocked then DanTraits_StrainAdd(player, "knocked", ST.KNOCK, true) end
    d.stKnocked = down or nil
end

-- sleep -------------------------------------------------------------------------------

local function feverish(player, d)
    return (DanTraits_Strength("DanTraits_InfectionFever", player) or 0) > 0 or (d.infStage or 0) >= 4
end

local function sleepEase(player, d, quality)
    local amount = (d.stBed == false and ST.SLEEP_ROUGH or ST.SLEEP_BED) * DanTraits_Clamp01(quality)
    if feverish(player, d) then amount = amount * ST.SICK_REST end
    d.stKills = 0
    return DanTraits_StrainEase(player, "sleep", amount)
end

DanTraits_AddHook("nightScored", function(_, player, d, quality, hours, wakes, isNap)
    if not d or isNap or not strainOn() then return nil end
    sleepEase(player, d, quality or 0)
    -- a Nomad's beds, for nomadAtHome
    if d.stSleepLoc and d.stBed then
        local nights = d.stNomadNights or {}
        d.stNomadNights = nights
        nights[#nights + 1] = d.stSleepLoc
        while #nights > ST.NOMAD_WINDOW do table.remove(nights, 1) end
    end
    d.stSleepLoc = nil
    return nil
end)

-- Vitality: Burnt Out holds its target under Thriving; At Ease lifts it a little
DanTraits_AddHook("vitalityTarget", function(target, player, d)
    if not d or not strainOn() then return nil end
    local s = d.strain or 0
    if tierOf(s) >= 3 then return math.min(target, ST.VIT_CAP) end
    if s < ST.AT_EASE then return target + ST.VIT_EASE end
    return nil
end)

local function inBed(player)
    local bed, car = nil, nil
    pcall(function() bed = player:getBed() end)
    pcall(function() car = player:getVehicle() end)
    return bed ~= nil and car == nil
end

local function trackSleep(player, d)
    local asleep = DanTraits_Asleep(player)
    if asleep then
        if not d.stAsleep then
            d.stBed, d.stSleptMin = inBed(player), 0
            d.stSleepLoc = DanTraits_HomePlaceOf and DanTraits_HomePlaceOf(player) or nil
        end
        d.stAsleep = true
        d.stSleptMin = (d.stSleptMin or 0) + 1
        return true
    end
    if d.stAsleep and not DanTraits_SandboxOn("VitalityEnabled") then
        -- Vitality scores the nights; without it, a long enough sleep counts on its own
        local hours = (d.stSleptMin or 0) / 60
        if hours >= ST.SLEEP_MIN_H then sleepEase(player, d, math.min(1, hours / 7)) end
    end
    d.stAsleep, d.stSleptMin = nil, nil
    return false
end

-- comforts the other systems leave in mod data (phase 2 moves these into them) ---------

local function watchComforts(player, d, asleep)
    -- the first look after a load only notes what is already running
    local first = not d.stWatched
    d.stWatched = true
    -- a new Good Meal afterglow (DanTraits_Cooking.lua: a fresh one starts full)
    local g = d.ckGlow
    local gmin = g and tonumber(g.min) or nil
    if gmin and not first and (d.stGlowMin == nil or gmin > d.stGlowMin) then
        -- Keen Cook (and the cooks' profession version) eats a tier up
        local tier = tonumber(g.tier) or 1
        if hasVanillaTrait(player, "base:cook") or hasVanillaTrait(player, "base:cook2") then tier = tier + 1 end
        DanTraits_StrainComfort(player, "meal", ST.MEAL[math.max(1, math.min(3, tier))])
    end
    d.stGlowMin = gmin
    -- Pumped starts (DanTraits_Fitness.lua)
    local pump = (d.ftPumpMin or 0) > 0
    if pump and not first and not d.stPump then DanTraits_StrainComfort(player, "pumped") end
    d.stPump = pump or nil
    -- into fresh clothes (DanTraits_Laundry.lua: Fresh Clothes or Line-Dried)
    local fresh = (tonumber(d.lnMoodle) or 0) < 0
    if fresh and not first and not d.stFresh then DanTraits_StrainComfort(player, "laundry") end
    d.stFresh = fresh or nil
    -- Homemaker: clothes off the line are a comfort of their own
    local dried = (tonumber(d.lnMoodle) or 0) <= -2
    if dried and not first and not d.stDried and hasTrait(player, "homemaker") then DanTraits_StrainComfort(player, "linedried", ST.LINE_DRIED) end
    d.stDried = dried or nil
    -- an hour of reading
    if not asleep then
        local reading = false
        pcall(function()
            local q = ISTimedActionQueue.getTimedActionQueue(player)
            local a = q and q.queue and q.queue[1]
            reading = a ~= nil and a.Type == "ISReadABook"
        end)
        if reading then
            d.stReadMin = (d.stReadMin or 0) + 1
            if d.stReadMin % ST.READ_MIN == 0 then DanTraits_StrainComfort(player, "read") end
        end
        -- an hour of a handheld game
        if DanTraits_ScreenTime and DanTraits_ScreenTime(player) == "game" then
            d.stGameMin = (d.stGameMin or 0) + 1
            if d.stGameMin % ST.GAME_MIN == 0 then DanTraits_StrainComfort(player, "game") end
        end
    end
    -- a hangover starts (DanTraits_Hangover.lua)
    local hung = d.hoActive == true
    if hung and not first and not d.stHangover then DanTraits_StrainAdd(player, "hangover", ST.HANGOVER, false) end
    d.stHangover = hung or nil
end

-- washing: vanilla's wash-yourself, and Take A Bath And Shower's bath or shower
function DanTraits_StrainWashed(player)
    return DanTraits_StrainComfort(player, "shower")
end

local function wrapWash()
    local cls = ISWashYourself
    if not cls then return end
    local method = cls.complete and "complete" or "perform"
    DanTraits_Wrap(cls, method, "strain-wash", function(original, self, ...)
        local result = original(self, ...)
        DanTraits_Guard("Strain wash", DanTraits_StrainWashed, self.character)
        return result
    end)
end

local bathHooked = false
local function hookBath()
    wrapWash()
    if bathHooked then return end
    local ev = Events and Events.OnBathingEnd
    if type(ev) ~= "table" or type(ev.Add) ~= "function" then return end
    bathHooked = true
    ev.Add(function(character) DanTraits_Guard("Strain bath", DanTraits_StrainWashed, character) end)
end
hookBath()
if Events and Events.OnGameStart then Events.OnGameStart.Add(hookBath) end

-- a cigarette or cigar (the eat action) or a pack or chewing tobacco (the pill action)
local function onTobacco(player, kind, item, portion)
    if not player or not DanTraits_NicotineOf or not strainOn() then return end
    local cigs = DanTraits_NicotineOf(kind, item)
    if not cigs then return end
    local d = DanTraits_Data(player)
    newDay(d)
    local amount = math.min(ST.CIG_CAP - (d.stCigs or 0), ST.CIG * cigs * (tonumber(portion) or 1))
    if amount <= 0 then return end
    d.stCigs = (d.stCigs or 0) + amount
    if hasVanillaTrait(player, "base:smoker") then amount = amount * ST.ADDICT end
    DanTraits_StrainEase(player, "smoke", amount)
end
DanTraits_AddHook("eat", function(_, player, item, portion)
    if not item then return nil end
    local kind = ""
    pcall(function() kind = item:getType() end)
    onTobacco(player, kind, item, portion)
    return nil
end)
DanTraits_AddHook("prePill", function(_, player, kind, item)
    onTobacco(player, kind, item, 1)
    return nil
end)

-- Breaking Point --------------------------------------------------------------------------

-- a zombie within tiles of the character
local function zombieWithin(player, tiles)
    local near = false
    pcall(function()
        local list = getCell():getZombieList()
        local x, y, z = player:getX(), player:getY(), player:getZ()
        for i = 0, list:size() - 1 do
            local zed = list:get(i)
            local dx, dy = zed:getX() - x, zed:getY() - y
            if math.abs(zed:getZ() - z) < 1 and dx * dx + dy * dy <= tiles * tiles and not zed:isDead() then
                near = true
                return
            end
        end
    end)
    return near
end
DanTraits_StrainZombieWithin = zombieWithin

-- the breakdown action asks: time to stop?
function DanTraits_StrainDanger(player)
    return zombieWithin(player, ST.BREAK_NEAR_TILES)
end

function DanTraits_StrainBreakdownStart(player)
    local d = DanTraits_Data(player)
    d.stBreak = "active"
    local line = getText("UI_DanTraits_StrainBreakLine" .. tostring(ZombRand(3) + 1))
    pcall(function() player:Say(line) end)
end

-- stopped before the end: it comes again
function DanTraits_StrainBreakdownStop(player)
    local d = DanTraits_Data(player)
    if d.stBreak == "active" then d.stBreak = "pending" end
    d.stBreakTry = nil
end

function DanTraits_StrainBreakdownDone(player)
    local d = DanTraits_Data(player)
    d.stBreak, d.stBreakTry = nil, nil
    d.strain = math.min(d.strain or 0, ST.BREAK_RESET)
    d.stTold = tierOf(d.strain)
    notifyGood(player, "UI_DanTraits_StrainBrokeDown")
end

local function tryBreakdown(player, d, asleep)
    if d.stBreak ~= "pending" or asleep then return end
    if d.stBreakTry and d.stBreakTry > 0 then
        d.stBreakTry = d.stBreakTry - 1
        return
    end
    if (nowHours() - (d.stFightH or -1000)) * 60 < ST.BREAK_CALM_MIN then return end
    if zombieWithin(player, ST.BREAK_TILES) then return end
    if not (ISTimedActionQueue and ISStrainBreakdownAction) then return end
    d.stBreakTry = ST.BREAK_RETRY_MIN
    pcall(function()
        ISTimedActionQueue.clear(player)
        ISTimedActionQueue.add(ISStrainBreakdownAction:new(player))
    end)
end

-- the minute ------------------------------------------------------------------------------

local function stand(d)
    d.stMoodle = 0
end

local function updateStrainMinute(player, d)
    if not strainOn() then stand(d) return end
    newDay(d)
    d.strain = d.strain or 0
    if d.stBreak and not DanTraits_SandboxOn("StrainBreakdown") then d.stBreak, d.stBreakTry = nil, nil end
    local asleep = trackSleep(player, d)
    local stats = player:getStats()
    local now = nowHours()

    -- fights and shocks
    local panic = 0
    pcall(function() panic = stats:get(CharacterStat.PANIC) or 0 end)
    -- only the fight's panic: an asthma attack, a hallucination or bleeding has its own costs
    if panic > ST.PANIC_AT and zombieWithin(player, ST.PANIC_ZOMBIE_TILES) then DanTraits_StrainAdd(player, "panic", ST.PANIC, true) end
    scanWounds(player, d)
    local health = 100
    pcall(function() health = player:getBodyDamage():getOverallBodyHealth() or 100 end)
    if health < ST.LOW_HEALTH_AT and d.stLowDay ~= d.stDay then
        d.stLowDay = d.stDay
        d.stFightH = now
        DanTraits_StrainAdd(player, "lowHealth", ST.LOW_HEALTH, false)
    end

    -- illness, awake or asleep
    local sick = 0
    local fever = DanTraits_Strength("DanTraits_InfectionFever", player) or 0
    sick = sick + fever * ST.FEVER
    if (d.infStage or 0) >= 4 then sick = sick + ST.SEPSIS end
    sick = sick + DanTraits_StatFraction(stats, CharacterStat.FOOD_SICKNESS) * ST.FOOD_SICK
    sick = sick + DanTraits_StatFraction(stats, CharacterStat.PAIN) * ST.PAIN
    if sick > 0 then DanTraits_StrainAdd(player, "illness", sick / 60, false) end

    if not asleep then
        -- withdrawal
        if d.alcWithdrawing and hasTrait(player, "dependent") then
            local rate = ST.ALC[math.max(1, math.min(3, tonumber(d.alcStage) or 1))]
            DanTraits_StrainAdd(player, "withdrawal", rate / 60, false)
        end
        local nic = DanTraits_NicotineWithdrawal and (tonumber(DanTraits_NicotineWithdrawal(player)) or 0) or 0
        if nic > 0 and hasVanillaTrait(player, "base:smoker") then DanTraits_StrainAdd(player, "withdrawal", nic * ST.NIC / 60, false) end

        -- calm
        if (now - (d.stFightH or -1000)) >= ST.CALM_AFTER_H then
            local calm = ST.CALM / 60
            if feverish(player, d) then calm = calm * ST.SICK_REST end
            DanTraits_StrainEase(player, "calm", calm)
        end

        -- drink: up to the day's cap; an Alcoholic's a quarter
        local level = DanTraits_MoodleLevel(player, "DRUNK", CharacterStat.INTOXICATION, DanTraits_DRUNK_LEVELS)
        local rate = level >= 2 and ST.DRUNK or (level == 1 and ST.TIPSY or 0)
        local room = ST.DRINK_CAP - (d.stDrink or 0)
        if rate > 0 and room > 0 then
            local amount = math.min(room, rate / 60)
            d.stDrink = (d.stDrink or 0) + amount
            if hasTrait(player, "dependent") then amount = amount * ST.ADDICT end
            DanTraits_StrainEase(player, "drink", amount)
        end
    end

    watchComforts(player, d, asleep)

    -- what it does
    local s = d.strain or 0
    local tier = tierOf(s)
    if d.stBreak == "active" then
        DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, ST.BREAK_SAD, ST.FLOOR_RAMP * 4)
    elseif (ST.FLOOR[tier] or 0) > 0 and not asleep then
        DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, ST.FLOOR[tier], ST.FLOOR_RAMP)
    end
    tryBreakdown(player, d, asleep)

    -- the hour's trend, for the health panel
    d.stMarkMin = (d.stMarkMin or 0) + 1
    if d.stMarkMin >= 60 then
        d.stTrend = s - (d.stMark or s)
        d.stMark, d.stMarkMin = s, 0
    end

    -- the moodle: At Ease on the good side; Frayed, Worn Down, Burnt Out, Breaking Point on the bad
    if d.stBreak then d.stMoodle = 4
    elseif tier > 0 then d.stMoodle = math.min(3, tier)
    elseif s < ST.AT_EASE then d.stMoodle = -1
    else d.stMoodle = 0 end
end

-- for the health panel: the tier (0..4, or -1 At Ease) and which way it is going
function DanTraits_StrainSummary(player)
    if not player or not strainOn() then return nil end
    local d = DanTraits_Data(player)
    local trend = tonumber(d.stTrend) or 0
    local way = "steady"
    if trend > 0.25 then way = "rising" elseif trend < -0.25 then way = "easing" end
    return { moodle = d.stMoodle or 0, way = way }
end

DanTraits_Every("minute", "Strain", updateStrainMinute, 45)
DanTraits_Every("frame", "StrainKnock", updateStrainFrame, 40)

-- console: strain | strain set <0..100> | strain kill [n] | strain comfort <kind>
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.strain = function(player, args)
    local d = DanTraits_Data(player)
    local op = args[1]
    if op == "set" then
        d.stBreak = nil
        setStrain(player, d, tonumber(args[2]) or 0)
    elseif op == "kill" then
        for _ = 1, tonumber(args[2]) or 1 do DanTraits_StrainKill(player, false) end
    elseif op == "comfort" and args[2] then
        DanTraits_StrainComfort(player, args[2], ST.COMFORT[args[2]] or ST.MEAL[2])
    end
    local parts = {}
    for k, v in pairs(d.stToday or {}) do parts[#parts + 1] = k .. " " .. (v >= 0 and "+" or "") .. string.format("%.1f", v) end
    table.sort(parts)
    return "strain " .. string.format("%.1f", d.strain or 0) .. " (tier " .. tostring(tierOf(d.strain or 0))
        .. (d.stBreak and (", breakdown " .. d.stBreak) or "") .. "), kills since sleep " .. string.format("%.1f", d.stKills or 0)
        .. ", today: " .. (#parts > 0 and table.concat(parts, ", ") or "nothing")
end
