-- Project Zomboid Vitality Project: spoons, an energy budget (spoon theory).
--
-- Not a trait: a pool that a trait can draw on (Multiple Sclerosis does, see
-- DanTraits_MS.lua; a trait registers with DanTraits_SpoonsUse). You wake with
-- a number of spoons. Every minute awake costs some, by what you are doing
-- (the metabolic rate the game keeps: idle 1.5, walking 3, chopping 5.5,
-- sprinting 8), more in pain, panicking or hungry, and the trait's own
-- "spoonSpend" hook (MS: the heat, a flare). Run out and you have hit the
-- wall for the day: heavy tiredness and slow stamina (the trait adds its own,
-- MS stiffens the legs). Each hour awake at the wall is borrowed from
-- tomorrow. True rest (sitting, reading, lying down: idle, no heavy load, not
-- hungry, not driving) gives a little back, up to two a day. Reading or
-- writing costs a fifth of what the minute would otherwise (SP_READ_COST,
-- applied after the heat, a flare and hunger have had their say) and is rest
-- however heavy the bag beside you.
--
-- Sleep is the refill, and the night system already scores it. When the
-- character gets up, a provisional refill is set from what is known then:
-- hours slept this night (Vitality's running total plus this segment), how
-- rested they woke, how dark it was (the Sleep file's running darkness).
-- An hour later Vitality scores the night for real (the "nightScored" hook:
-- quality with the wake count and the Sleep and Infection adjustments) and
-- the pool is corrected to it, less whatever was spent since getting up.
--   refill = cap x (SP_FLOOR + (1 - SP_FLOOR) x quality) - debt + "spoonRefill"
-- A nap (under three hours, Vitality's rule) adds up to SP_NAP_MAX a day
-- without resetting. The cap is SP_CAP unless a "spoonCap" hook says
-- otherwise (MS: the sandbox count, two thirds of it in a flare).
--
-- Tiers on the pool: 1 at or under half (moodle only; a notice once a day),
-- 2 at SP_LOW or fewer (stamina x0.7, tiring), 3 at nothing (stamina x0.4,
-- very tired, "You've hit the wall"). A real caffeine dose
-- (DanTraits_SpoonMask, called by the Caffeine file) hides one tier for an
-- hour; no spoons are gained and the tier lands when it ends.
--
-- Mod data: spPool, spCap, spDebt (hours borrowed), spRest (got back by rest
-- today), spNap (from naps today), spWallMin, spMask (minutes), spSpent
-- (since getting up), spTier, spFelt (the tier after the coffee mask; the
-- moodle shows this), spAsleep, spSleepStart, spHalfTold, spDebtPaid,
-- spLastQuality, spNightOpen (the morning refill has happened and Vitality
-- has not closed the night yet: a second sleep in that hour is the same
-- night, not a new one), spAwakeMin (minutes up, closes the night without
-- Vitality).
require "DanTraits"

local notify = DanTraits_Notify
local traitData = DanTraits_Data
local clamp01 = DanTraits_Clamp01
local fraction = DanTraits_StatFraction

local SP_CAP          = 12       -- spoons on a normal day (a trait's "spoonCap" hook can change it)
local SP_FLOOR        = 1 / 3    -- the worst night still refills this share of the cap
local SP_NIGHT_H      = DanTraits_NIGHT.napMaxHours   -- a sleep this long is a night; shorter is a nap (Vitality's rule)
local SP_NAP_MAX      = 4        -- the most naps give back in a day...
local SP_NAP_FULL_H   = 3        -- ...a nap this long in the dark would give all of it
local SP_REST_MIN     = 0.01     -- a minute of true rest gives this back (half a spoon an hour)...
local SP_REST_MAX     = 2        -- ...up to this a day
local SP_BASE_MIN     = 1 / 160  -- a minute awake costs this (an idle 16-hour day: 6)
local SP_MET_REST     = 1.5      -- the metabolic rate at rest...
local SP_MET_MIN      = 0.0075   -- ...and the cost per MET-minute above it (sprinting: about 3 an hour)
local SP_REST_MET     = 1.8      -- under this you are resting
local SP_READ_COST    = 0.2      -- reading or writing (the game's reading flag) costs this share of the minute,
                                 -- whatever the heat, a flare or hunger made of it: pages are not a day's work
local SP_CARRY_HEAVY  = 0.8      -- carrying more than this share of capacity is not rest
local SP_HUNGRY       = 0.25     -- hunger above this (the Hungry moodle) is not rest...
local SP_HUNGRY_COST  = 1.2      -- ...and costs x this
local SP_PAIN_COST    = 0.3      -- cost x (1 + this x pain + ...
local SP_PANIC_COST   = 0.3      -- ... this x panic)
local SP_DEBT_MAX     = 6        -- hours that can be borrowed
local SP_MASK_MIN     = 60       -- a full caffeine dose hides a tier this long...
local SP_MASK_DOSE    = 40       -- ...a smaller dose pro rata
local SP_LOW          = 3        -- spoons or fewer is running on empty (a quarter of a small cap)
local SP_LOW_FATIGUE  = 0.0004   -- tiredness a minute running on empty...
local SP_WALL_FATIGUE = 0.0010   -- ...and at the wall
local SP_LOW_REGEN    = 0.7      -- endurance recovery x this running on empty...
local SP_WALL_REGEN   = 0.4      -- ...and at the wall
local SP_BAD_NIGHT    = 0.6      -- a night under this quality is "a bad night" in the morning notice
local SP_DARK_GOOD    = DanTraits_NIGHT.qualityDark    -- the Sleep file's score bonus for a dark night...
local SP_DARK_BAD     = DanTraits_NIGHT.qualityBright  -- ...and penalty for a lit one (the provisional score)

local SP_NIGHT_GAP_MIN = DanTraits_NIGHT.gapMin   -- awake this long after a night: the next sleep is a new one (Vitality's gap)

local KEYS = { "spPool", "spCap", "spDebt", "spRest", "spNap", "spWallMin", "spMask", "spSpent", "spTier", "spFelt",
               "spAsleep", "spSleepStart", "spHalfTold", "spDebtPaid", "spLastQuality", "spNightOpen", "spAwakeMin" }

-- who draws on the pool: each trait registers a test of its own
local users = {}
function DanTraits_SpoonsUse(fn) users[#users + 1] = fn end
local function using(player)
    if not player then return false end
    for _, fn in ipairs(users) do
        local ok, res = pcall(fn, player)
        if ok and res == true then return true end
    end
    return false
end

local function capOf(player, d)
    local cap = tonumber(DanTraits_RunHooks("spoonCap", SP_CAP, player, d)) or SP_CAP
    return math.max(1, cap)
end

local function metOf(player)
    local met = SP_MET_REST
    pcall(function() met = player:getBodyDamage():getThermoregulator():getMetabolicRate() or SP_MET_REST end)
    return met
end

-- how dark it has been this night so far: -1 (lit) .. +1 (dark), from the Sleep file's running total
local function darkSoFar(d)
    if (d.slNightMin or 0) <= 0 then return 0 end
    return (d.slNightDark or 0) / d.slNightMin
end

local function refill(player, d, cap, quality)
    local extra = tonumber(DanTraits_RunHooks("spoonRefill", 0, player, d)) or 0
    return cap * (SP_FLOOR + (1 - SP_FLOOR) * clamp01(quality)) - (d.spDebtPaid or 0) + extra
end

-- the night as it looks when the character gets up, before Vitality has scored it
local function provisionalQuality(player, d, hours, fatigue)
    local need = DanTraits_VitalitySleepNeed and DanTraits_VitalitySleepNeed(player) or 7
    local q = 0.5 * math.min(1, hours / need) + 0.5 * (1 - clamp01(fatigue))
    local dark = darkSoFar(d)
    if dark > 0 then q = q + SP_DARK_GOOD * dark else q = q + SP_DARK_BAD * dark end
    return clamp01(q)
end

local function morningNotice(player, d)
    local n = math.floor(d.spPool + 0.5)
    if (d.spDebtPaid or 0) > 0 then
        DanTraits_NotifyFmt(player, "UI_DanTraits_SpoonsTodayDebt", n)
    elseif (d.spLastQuality or 1) < SP_BAD_NIGHT then
        DanTraits_NotifyFmt(player, "UI_DanTraits_SpoonsTodayBad", n)
    else
        DanTraits_NotifyFmtGood(player, "UI_DanTraits_SpoonsToday", n)
    end
end

-- just up: a night resets the pool (provisionally), a nap tops it up. A night
-- slept in two halves (Restless Sleeper; Vitality joins them when the gap is
-- under an hour) refills once: the second half re-scores the same night,
-- keeps the debt it paid and what was spent between, and says nothing.
local function wake(player, d, cap, hours, fatigue)
    local q = provisionalQuality(player, d, hours, fatigue)
    if hours >= SP_NIGHT_H then
        local first = not d.spNightOpen
        if first then
            d.spDebtPaid = d.spDebt or 0
            d.spDebt, d.spRest, d.spNap, d.spWallMin, d.spHalfTold, d.spSpent = 0, 0, 0, 0, nil, 0
            d.spNightOpen = true
        end
        d.spLastQuality = q
        d.spPool = math.max(0, math.min(cap, refill(player, d, cap, q) - (d.spSpent or 0)))
        if first then morningNotice(player, d) end
        return
    end
    d.spSpent = 0
    local gain = SP_NAP_MAX * math.min(1, hours / SP_NAP_FULL_H) * (0.5 + 0.5 * math.max(0, darkSoFar(d)))
    gain = math.max(0, math.min(gain, SP_NAP_MAX - (d.spNap or 0)))
    d.spNap = (d.spNap or 0) + gain
    d.spPool = math.min(cap, (d.spPool or 0) + gain)
end

-- Vitality has scored the night: correct the provisional refill (naps were applied on waking)
DanTraits_AddHook("nightScored", function(_, player, d, quality, hours, wakes, isNap)
    if isNap or not d or d.spPool == nil or not using(player) then return nil end
    local cap = d.spCap or SP_CAP
    d.spLastQuality = clamp01(tonumber(quality) or 0)
    d.spPool = math.max(0, math.min(cap, refill(player, d, cap, d.spLastQuality) - (d.spSpent or 0)))
    d.spNightOpen = nil
    return nil
end)

-- the game's flag while a book is read or something is written (ISReadABook, ISWriteSomething)
local function reading(player)
    local r = false
    pcall(function() r = player:isReading() == true end)
    return r
end

-- sitting with a book counts as rest whatever is in the bag beside you
local function resting(player, met, hungry, read)
    if hungry or met >= SP_REST_MET then return false end
    if read then return true end
    local heavy, inVehicle = false, false
    pcall(function() inVehicle = player:getVehicle() ~= nil end)
    pcall(function() heavy = (player:getInventory():getCapacityWeight() or 0) > SP_CARRY_HEAVY * (player:getMaxWeight() or 1) end)
    return not heavy and not inVehicle
end

local function tierOf(pool, cap)
    if pool <= 0 then return 3 end
    if pool <= math.min(SP_LOW, cap * 0.25) then return 2 end
    if pool <= cap * 0.5 then return 1 end
    return 0
end

local function updateSpoonsMinute(player, d)
    if not using(player) then
        if d.spPool ~= nil then for _, k in ipairs(KEYS) do d[k] = nil end end
        return
    end
    local cap = capOf(player, d)
    d.spCap = cap
    if d.spPool == nil then d.spPool = cap end   -- a new user starts the day full
    if d.spPool > cap then d.spPool = cap end     -- a flare's cap shrinks the pool

    local stats = player:getStats()
    local fatigue, hour = 0, 0
    pcall(function() fatigue = stats:get(CharacterStat.FATIGUE) or 0 end)
    pcall(function() hour = player:getHoursSurvived() or 0 end)
    local tier = tierOf(d.spPool, cap)
    if (d.spMask or 0) > 0 then
        d.spMask = d.spMask - 1
        if d.spMask <= 0 then
            d.spMask = nil
            if tier >= 2 then notify(player, "UI_DanTraits_SpoonsCoffeeGone") end
        end
    end

    if DanTraits_Asleep(player) then
        if not d.spAsleep then d.spAsleep, d.spSleepStart, d.spAwakeMin = true, hour, nil end
        d.spTier, d.spFelt = 0, 0
        return
    end
    if d.spAsleep then
        d.spAsleep = nil
        local hours = math.max(0, hour - (d.spSleepStart or hour))
        if DanTraits_SandboxOn("VitalityEnabled") then hours = hours + (d.vitNightHours or 0) end
        wake(player, d, cap, hours, fatigue)
        tier = tierOf(d.spPool, cap)
    end
    -- up for the gap: the night is over whether or not Vitality scored it
    if d.spNightOpen then
        d.spAwakeMin = (d.spAwakeMin or 0) + 1
        if d.spAwakeMin >= SP_NIGHT_GAP_MIN then d.spNightOpen, d.spAwakeMin = nil, nil end
    end

    -- spend
    local met = metOf(player)
    local cost = SP_BASE_MIN + SP_MET_MIN * math.max(0, met - SP_MET_REST)
    cost = cost * (1 + SP_PAIN_COST * fraction(stats, CharacterStat.PAIN) + SP_PANIC_COST * fraction(stats, CharacterStat.PANIC))
    local hungry = fraction(stats, CharacterStat.HUNGER) > SP_HUNGRY
    if hungry then cost = cost * SP_HUNGRY_COST end
    cost = math.max(0, tonumber(DanTraits_RunHooks("spoonSpend", cost, player, d)) or cost)
    local read = reading(player)
    if read then cost = cost * SP_READ_COST end
    local back = 0
    if resting(player, met, hungry, read) and (d.spRest or 0) < SP_REST_MAX then
        back = math.min(SP_REST_MIN, SP_REST_MAX - (d.spRest or 0))
        d.spPool = math.min(cap, d.spPool + back)
        d.spRest = (d.spRest or 0) + back
    end
    d.spPool = math.max(0, d.spPool - cost)
    d.spSpent = (d.spSpent or 0) + cost - back   -- net, so a re-scored night keeps what rest gave back
    if d.spPool <= 0 then
        d.spWallMin = (d.spWallMin or 0) + 1
        d.spDebt = math.min(SP_DEBT_MAX, (d.spDebt or 0) + 1 / 60)
    end

    -- the tier, and what the coffee hides
    tier = tierOf(d.spPool, cap)
    local felt = tier
    if (d.spMask or 0) > 0 and tier >= 2 then felt = tier - 1 end
    if tier >= 1 and not d.spHalfTold then
        d.spHalfTold = true
        notify(player, "UI_DanTraits_SpoonsHalf")
    end
    if felt >= 3 and (d.spFelt or 0) < 3 then notify(player, "UI_DanTraits_SpoonsWall") end
    d.spTier, d.spFelt = tier, felt
    if felt == 2 then DanTraits_StatAdd(stats, CharacterStat.FATIGUE, SP_LOW_FATIGUE)
    elseif felt >= 3 then DanTraits_StatAdd(stats, CharacterStat.FATIGUE, SP_WALL_FATIGUE) end
end

-- stamina comes back slower running on empty, slower still at the wall
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d or not d.spFelt or d.spFelt < 2 then return nil end
    return delta * (d.spFelt >= 3 and SP_WALL_REGEN or SP_LOW_REGEN)
end)

-- a real caffeine dose hides a tier for an hour (the Caffeine file calls this for every dose)
function DanTraits_SpoonMask(player, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 or not using(player) then return end
    local d = traitData(player)
    if d.spPool == nil then return end
    local fresh = (d.spMask or 0) <= 0
    d.spMask = math.max(d.spMask or 0, SP_MASK_MIN * math.min(1, amount / SP_MASK_DOSE))
    if fresh and (d.spTier or 0) >= 2 then notify(player, "UI_DanTraits_SpoonsCoffee") end
end

-- for the traits, the console and the dashboard
function DanTraits_SpoonTier(player)
    local d = player and player:getModData().DanTraits
    return d and d.spFelt or 0
end
function DanTraits_SpoonDebt(player)
    local d = player and player:getModData().DanTraits
    return d and d.spDebt or 0
end
function DanTraits_SpoonsSet(player, n)
    local d = traitData(player)
    if d.spPool == nil then return nil end
    d.spPool = math.max(0, math.min(d.spCap or SP_CAP, tonumber(n) or 0))
    return d.spPool
end

DanTraits_Every("minute", "Spoons", updateSpoonsMinute, 39)
