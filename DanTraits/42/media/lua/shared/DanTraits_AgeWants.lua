-- Project Zomboid Vitality Project: what each age wants (Age 2.0, 2026-10-31).
--
-- Each decade has one or two things it wants every day, shown as a moodle,
-- with a small reward for meeting it and a small cost for ignoring it.
-- Nothing lethal: texture. The whole suite sits behind one sandbox switch,
-- AgeWants (on by default; off: nothing here ticks, no want moodle shows, no
-- mood or stress moves, and Restless does nothing), and does nothing with Age
-- itself off. The band's own effects (levels, recovery, the head rows) are
-- not behind it: they are the age system.
--
-- 20s
--   Itchy Feet. Every minute the character's map cell (IF_CELL tiles square)
--     is noted; IF_DAYS days in the same cell and the want builds over the next
--     day: boredom climbs faster (the boredomRise stat delta pipeline, which
--     ADHD registers) and the mood dips a little each waking minute. Stepping
--     into a cell never visited (awCells remembers them, the spawn cell
--     included) clears it, lifts the mood and stress at once, and says so.
--     Restless (DanTraits_AgeTraits.lua): the days count double and the dip
--     and the lift are doubled.
--   Late sleeper. A night (not a nap) that ends before LS_EARLY o'clock: the
--     first hour after waking tiredness is held at the Drowsy edge unless a
--     coffee's worth of caffeine is in the system, and the night's sleep debt
--     counts x LS_DEBT. The deeper nights are the band's (x0.8 wakes).
-- 40s
--   Routine, lightly. A coffee or tea before RT_MORNING_END and a meal within
--     an hour of yesterday's main meal each give a touch of mood, once a day.
-- 50s
--   Creature of Habit. The same three (the same bed as last night, a meal at
--     yesterday's hour, a morning drink) each give a sliver of mood as they
--     happen, and the day is scored when the night is: kept when two of the
--     three held. CH_BROKE_DAYS disrupted days in a row bring the Out of
--     Routine moodle (the mood sinks a little each waking minute and the
--     night scores CH_NIGHT worse) until CH_KEPT_DAYS kept days clear it.
--   Feels the cold. The cold reaches the joints sooner (Arthritis's and Old
--     Injury's weather reading x FC_JOINT below FC_JOINT_C), the mood sinks a
--     little each waking minute out in the cold (below FC_BITE_C), and a cold
--     night scores FC_NIGHT worse unless a hot water bottle was in the bed.
--   Comfort matters more. Stiffness fades x CM_STIFF asleep in a bed in a
--     house (Age's stiffFade hook), and a seat you could sleep on rests Bad
--     Knees x CM_KNEES (the kneeRest hook in DanTraits_AgeTraits.lua).
-- Everyone: the band, and the want that is up, on the health panel
--   (DanTraits_AgeWantsLines, read by DanTraits_HealthPanel.lua).
--
-- Mod data (aw prefix): awCells (visited cells, "cx,cy" = true), awCell (the
-- cell now), awStayH (hours in it), awItchy (0..1), awSlowMin, awDay (the day
-- index scored), awMealHour, awMealHourY (today's and yesterday's main meal),
-- awMealBig, awDrink (a morning drink today), awDrinkY, awMealKeptY (yesterday's,
-- carried over at midnight for the night scored this morning), awBed (last night's bed), awKept,
-- awBroke (the streaks), awOut (out of routine), awColdNight.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local traitData = DanTraits_Data
local clamp01 = DanTraits_Clamp01

-- Itchy Feet
local IF_CELL        = 256     -- tiles to a map cell
local IF_DAYS        = 3       -- days in one cell before the want builds...
local IF_RAMP_H      = 24      -- ...to full over this many hours more
local IF_BOREDOM     = 0.5     -- boredom climbs x (1 + this x want)
local IF_MOOD        = 0.0002  -- unhappiness (fraction of its range) a waking minute at a full want
local IF_LIFT_MOOD   = 10      -- unhappiness off on new ground...
local IF_LIFT_STRESS = 0.05    -- ...and stress off
local RL_MULT        = 2       -- Restless: the days, the dip and the lift x this
-- Late sleeper
local LS_EARLY       = 7       -- a night ending before this o'clock...
local LS_SLOW_MIN    = 60      -- ...is slow to wake from for this long...
local LS_FATIGUE     = 0.62    -- ...tiredness held at least here (the Drowsy edge)
local LS_COFFEE      = 50      -- caffeine in the system that clears it (half a mug)
local LS_DEBT        = 1.25    -- the night's sleep debt x this
-- Routine, lightly (40s) and Creature of Habit (50s)
local RT_MORNING_END = 11      -- a coffee or tea before this o'clock is the morning drink
local RT_MEAL_HUNGER = 0.2     -- a food that takes at least this much hunger off is a meal
local RT_MEAL_WINDOW = 1       -- within this many hours of yesterday's main meal
local RT_TOUCH       = 2       -- unhappiness off for a routine kept (the 40s, each once a day)
local CH_SLIVER      = 1       -- unhappiness off for each habit kept (the 50s)
local CH_KEEP_OF     = 2       -- a day is kept when this many of the three held
local CH_BROKE_DAYS  = 3       -- disrupted days in a row that bring the moodle...
local CH_KEPT_DAYS   = 2       -- ...and kept days that clear it
local CH_MOOD        = 0.0002  -- unhappiness a waking minute while out of routine
local CH_NIGHT       = 0.1     -- off the night's quality while out of routine
-- Feels the cold
local FC_JOINT_C     = 15      -- air below this: the joints' weather reading x FC_JOINT
local FC_JOINT       = 1.2
local FC_BITE_C      = 10      -- air below this, awake: the mood sinks...
local FC_MOOD        = 0.0003  -- ...this much a minute
local FC_NIGHT       = 0.05    -- a cold night (air under FC_BITE_C when it is scored) scores this worse
-- Comfort matters more
local CM_STIFF       = 1.2     -- stiffness fades x this asleep in a bed in a house
local CM_KNEES       = 1.2     -- a seat you could sleep on rests Bad Knees x this

local function wantsOn(player)
    if not DanTraits_SandboxOn("AgeWants") or not DanTraits_SandboxOn("AgeEnabled") then return false end
    return player ~= nil and DanTraits_AgeBand ~= nil
end

local function band(player) return DanTraits_AgeBand(player) end

local function restless(player) return hasTrait(player, "restless") and RL_MULT or 1 end

-- Itchy Feet -------------------------------------------------------------------------
local function cellKey(player)
    local key = nil
    pcall(function() key = math.floor(player:getX() / IF_CELL) .. "," .. math.floor(player:getY() / IF_CELL) end)
    return key
end

local function liftOnNewGround(player, d)
    local k = restless(player)
    local stats = player:getStats()
    DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -IF_LIFT_MOOD * k)
    DanTraits_StatAdd(stats, CharacterStat.STRESS, -IF_LIFT_STRESS * k * DanTraits_StatMax(CharacterStat.STRESS))
    notifyGood(player, "UI_DanTraits_WantNewGround")
end

local function updateItchyFeet(player, d, awake)
    local key = cellKey(player)
    if not key then return end
    d.awCells = d.awCells or {}
    if d.awCell == nil then
        -- first sight: where you are counts as known
        d.awCells[key] = true
        d.awCell, d.awStayH = key, 0
    elseif key ~= d.awCell then
        local new = not d.awCells[key]
        d.awCells[key] = true
        d.awCell, d.awStayH = key, 0
        if new and (d.awItchy or 0) > 0 then
            -- the want's relief: fresh country means nothing to a character who is not itchy
            d.awItchy = 0
            liftOnNewGround(player, d)
        end
    else
        d.awStayH = (d.awStayH or 0) + restless(player) / 60
    end
    local over = (d.awStayH or 0) - IF_DAYS * 24
    local was = d.awItchy or 0
    d.awItchy = over > 0 and clamp01(over / IF_RAMP_H) or 0
    if was <= 0 and d.awItchy > 0 then notify(player, "UI_DanTraits_WantItchyFeet") end
    if d.awItchy > 0 and awake then
        DanTraits_StatAdd(player:getStats(), CharacterStat.UNHAPPINESS,
            IF_MOOD * d.awItchy * restless(player) * DanTraits_StatMax(CharacterStat.UNHAPPINESS))
    end
end

DanTraits_AddHook("boredomRise", function(delta, player, d)
    if not d or (d.awItchy or 0) <= 0 or not wantsOn(player) or band(player) ~= 20 then return nil end
    return delta * (1 + IF_BOREDOM * d.awItchy * restless(player))
end)

-- Late sleeper -------------------------------------------------------------------------
local function updateLateSleeper(player, d, awake)
    if (d.awSlowMin or 0) <= 0 then return end
    if not awake then return end
    if (d.cafLevel or 0) >= LS_COFFEE then d.awSlowMin = nil return end
    d.awSlowMin = d.awSlowMin - 1
    if d.awSlowMin <= 0 then d.awSlowMin = nil return end
    pcall(function()
        local stats = player:getStats()
        if (stats:get(CharacterStat.FATIGUE) or 0) < LS_FATIGUE then
            stats:set(CharacterStat.FATIGUE, LS_FATIGUE)
            -- the hold is the mod's, not a game rise: the fatigueRise pipeline must not scale the jump
            if DanTraits_DeltaRemember then DanTraits_DeltaRemember(d, "fatigueRise", LS_FATIGUE) end
        end
    end)
end

-- Routine (40s) and Creature of Habit (50s) ---------------------------------------------------
local function dayIndex() return DanTraits_DayIndex() end   -- midnight to midnight (Util), not the start hour

local function timeOfDay()
    local t = 12
    pcall(function() t = getGameTime():getTimeOfDay() end)
    return tonumber(t) or 12
end

local function routineBand(player)
    local b = band(player)
    return b == 40 or b == 50
end

-- a new day: yesterday's main meal is the one to match
local function rollDay(player, d)
    local today = dayIndex()
    if d.awDay == today then return end
    d.awDay = today
    -- yesterday's, for the night that is scored this morning
    d.awMealHourY, d.awDrinkY, d.awMealKeptY = d.awMealHour, d.awDrink, d.awMealKept
    d.awMealHour, d.awMealBig, d.awDrink, d.awMealKept, d.awMealTouch, d.awDrinkTouch = nil, nil, nil, nil, nil, nil
end

local function kept(player, d, flag, touch)
    local b = band(player)
    local off = b == 50 and CH_SLIVER or RT_TOUCH
    if d[touch] then return end   -- once a day each, the 50s' sliver too
    d[touch] = true
    DanTraits_StatAdd(player:getStats(), CharacterStat.UNHAPPINESS, -off)
end

-- a meal: the day's biggest so far sets the hour; one within the window of yesterday's keeps the routine
local function onMeal(player, d, hunger)
    rollDay(player, d)
    if hunger > (d.awMealBig or 0) then d.awMealBig, d.awMealHour = hunger, timeOfDay() end
    if d.awMealHourY and math.abs(timeOfDay() - d.awMealHourY) <= RT_MEAL_WINDOW then
        d.awMealKept = true
        kept(player, d, "awMealKept", "awMealTouch")
    end
end

local HOT_DRINKS = { coffee = true, tea = true }
local function onDrink(player, d, name)
    if not name or not HOT_DRINKS[string.lower(tostring(name))] then return end
    rollDay(player, d)
    if timeOfDay() >= RT_MORNING_END or d.awDrink then return end
    d.awDrink = true
    kept(player, d, "awDrink", "awDrinkTouch")
end

-- the bed's key, as Settled reads it: the square it stands on
local function bedKey(player)
    local key = nil
    pcall(function()
        local bed = player:getBed()
        if bed then
            local sq = bed:getSquare()
            if sq then key = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() end
        end
    end)
    return key
end

-- the night scored (Vitality): the 50s' day is judged, the 20s' early rise noted
local function onNightScored(_, player, d, quality, hours, wakes, isNap)
    if not d or isNap or not wantsOn(player) then return nil end
    local b = band(player)
    if b == 20 then
        if timeOfDay() < LS_EARLY then
            d.awSlowMin = LS_SLOW_MIN
            d.vitSleepDebt = clamp01((d.vitSleepDebt or 0) * LS_DEBT)
            notify(player, "UI_DanTraits_WantEarlyRise")
        end
        return nil
    end
    if b == 50 then
        rollDay(player, d)
        local key = bedKey(player)
        local first = d.awBed == nil and not d.awMealHourY   -- the first night: nothing to keep yet
        local sameBed = key ~= nil and key == d.awBed
        if sameBed then kept(player, d, "awBedKept", "awBedTouch") end
        d.awBed = key or d.awBed
        -- the day just ended: the meal and the drink as the midnight roll carried them over
        local held = (sameBed and 1 or 0) + (d.awMealKeptY and 1 or 0) + (d.awDrinkY and 1 or 0)
        d.awMealKeptY, d.awDrinkY, d.awBedKept = nil, nil, nil
        if first then return nil end
        if held >= CH_KEEP_OF then
            d.awKept, d.awBroke = (d.awKept or 0) + 1, 0
            if d.awOut and d.awKept >= CH_KEPT_DAYS then
                d.awOut = nil
                notifyGood(player, "UI_DanTraits_WantRoutineBack")
            end
        else
            d.awBroke, d.awKept = (d.awBroke or 0) + 1, 0
            if not d.awOut and d.awBroke >= CH_BROKE_DAYS then
                d.awOut = true
                notify(player, "UI_DanTraits_WantOutOfRoutine")
            end
        end
    end
    return nil
end
DanTraits_AddHook("nightScored", onNightScored)

-- Feels the cold ----------------------------------------------------------------------
local function coldAir(player, below)
    local air = DanTraits_AirTemp(player)
    return type(air) == "number" and air < below
end

DanTraits_AddHook("arthritisJoint", function(joint, player)
    if not wantsOn(player) or band(player) ~= 50 or not coldAir(player, FC_JOINT_C) then return nil end
    return math.min(1, joint * FC_JOINT)
end)

DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not d or not wantsOn(player) then return nil end
    local b = band(player)
    local q = quality
    if b == 50 and d.awOut then q = q - CH_NIGHT end
    if b == 50 and coldAir(player, FC_BITE_C) and not d.hwbBed then q = q - FC_NIGHT end
    if q == quality then return nil end
    return math.max(0, q)
end)

-- Comfort matters more ------------------------------------------------------------------
local function inHouseBed(player)
    local yes = false
    pcall(function()
        local bed = player:getBed()
        yes = bed ~= nil and bed:getSquare() ~= nil and bed:getSquare():getRoom() ~= nil
    end)
    return yes
end

DanTraits_AddHook("stiffFade", function(stiff, player)
    if not wantsOn(player) or band(player) ~= 50 or not DanTraits_Asleep(player) or not inHouseBed(player) then return nil end
    return stiff * CM_STIFF
end)

DanTraits_AddHook("kneeRest", function(ease, player, comfy)
    if not comfy or not wantsOn(player) or band(player) ~= 50 then return nil end
    return ease * CM_KNEES
end)

-- the minute --------------------------------------------------------------------------
local function updateWantsMinute(player, d)
    if not wantsOn(player) then
        if d.awItchy or d.awSlowMin then d.awItchy, d.awSlowMin = nil, nil end
        return
    end
    local awake = not DanTraits_Asleep(player)
    local b = band(player)
    if b == 20 then
        updateItchyFeet(player, d, awake)
        updateLateSleeper(player, d, awake)
    elseif b == 50 then
        rollDay(player, d)
        if awake then
            local mood = 0
            if d.awOut then mood = mood + CH_MOOD end
            if coldAir(player, FC_BITE_C) then mood = mood + FC_MOOD end
            if mood > 0 then
                DanTraits_StatAdd(player:getStats(), CharacterStat.UNHAPPINESS, mood * DanTraits_StatMax(CharacterStat.UNHAPPINESS))
            end
        end
    elseif b == 40 then
        rollDay(player, d)
    end
end

DanTraits_AddHook("eat", function(_, player, item, portion)
    if not item or not wantsOn(player) or not routineBand(player) then return nil end
    local hunger = 0
    pcall(function() hunger = -(item:getHungChange() or 0) end)
    hunger = hunger * math.max(0, math.min(1, tonumber(portion) or 1))
    if hunger >= RT_MEAL_HUNGER then onMeal(player, traitData(player), hunger) end
    return nil
end)

DanTraits_AddHook("drink", function(_, player, container, litres, name)
    if not wantsOn(player) or not routineBand(player) then return nil end
    name = name or (DanTraits_FluidName and DanTraits_FluidName(container))
    onDrink(player, traitData(player), name)
    return nil
end)

-- read by Moodles
function DanTraits_AgeWantsMoodle(player, d, which)
    if not d or not wantsOn(player) then return 0 end
    if which == "ItchyFeet" then
        if band(player) ~= 20 or (d.awItchy or 0) <= 0 then return 0 end
        return d.awItchy >= 0.5 and 2 or 1
    elseif which == "OutOfRoutine" then
        return (band(player) == 50 and d.awOut) and 1 or 0
    end
    return 0
end

-- for the health panel: the band's name key, and the want that is up (a text key or nil)
function DanTraits_AgeWantsLines(player)
    if not player or not DanTraits_AgeBand or not DanTraits_SandboxOn("AgeEnabled") then return nil end
    local b = band(player)
    local d = player:getModData().DanTraits or {}
    local want = nil
    if wantsOn(player) then
        if b == 20 and (d.awItchy or 0) > 0 then want = "UI_DanTraits_health_ItchyFeet"
        elseif b == 20 and (d.awSlowMin or 0) > 0 then want = "UI_DanTraits_health_SlowToWake"
        elseif b == 50 and d.awOut then want = "UI_DanTraits_health_OutOfRoutine" end
    end
    return "UI_trait_DanAge" .. b .. "s", want
end

DanTraits_Every("minute", "AgeWants", updateWantsMinute, 50)
