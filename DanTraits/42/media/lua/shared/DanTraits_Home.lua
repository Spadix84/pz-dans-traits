-- Project Zomboid Vitality Project: home.
-- Not a trait: every character has it (sandbox option HomeEnabled; off:
-- nothing is tracked, the moodle shows nothing and the two traits do
-- nothing). Vanilla gives you no reason to be at your base: boredom climbs
-- indoors and every clock that matters rewards leaving. Home gives the base
-- a pull of its own.
--
-- Where you sleep is where you live. Each night (a sleep Vitality scores as a
-- night, not a nap; see DanTraits_Vitality.lua's nightScored hook) records
-- where the character fell asleep: the square, and the building's footprint
-- when there is one. A night in a vehicle records nothing (a car is not a
-- place, and it moves). The last HM_WINDOW nights are kept. Two nights are
-- the same place if they share a building, or lie within HM_SAME_TILES of
-- each other outdoors (a tent, a camp, a built base with no building
-- definition). Home is the place with most of those nights, with a floor of
-- HM_MIN_NIGHTS: fewer than that anywhere and there is no home yet, which is
-- week one. Sleep HM_MIN_NIGHTS of the last HM_WINDOW nights somewhere new
-- and home moves there, with a notice; nothing else has to be done.
--
-- d.hmNights is how many nights have been slept at the current home. Nights
-- away do not take it down, they just do not add; it starts over only when
-- home itself moves. Its strength (DanTraits_HomeStrength) is half at
-- HM_MIN_NIGHTS and full at HM_FULL_NIGHTS.
--
-- At home (inside the building's footprint plus HM_PAD tiles, or within
-- HM_RADIUS of the camp), awake, by strength: boredom, unhappiness and
-- stress ease each minute, a night slept at home scores a little better (the
-- nightQuality hook), and reading goes a little faster (ISReadABook's
-- duration). Away from home for HM_AWAY_ONSET_H hours, you miss it: over
-- HM_AWAY_RAMP_H more the Missing Home / Homesick moodle rises and an
-- unhappiness floor comes up with it. Walking back in lifts it at once, with
-- a drop in unhappiness and stress and a notice.
--
-- Homebody (-2): home does twice the good (HB_MULT on the drains, the night
--   bonus and the reading cut), and homesickness comes after HB_ONSET_H hours
--   instead, with a higher floor (HB_FLOOR), stress on top (HB_STRESS) and
--   worse nights slept away (HB_NIGHT_AWAY). Not with Nomad.
-- Nomad (+3): no place is home and none is missed. Nothing here tracks or
--   applies, and a night slept with no building around (outdoors, a tent, a
--   car) scores NM_ROUGH better. Not with Homebody or Settled (the 40s
--   trait that sleeps badly in a new bed).
--
-- Mod data (hm prefix): hmNights (list of the last nights' places), hmHome
-- (the place: x, y, z, b = { x1, y1, x2, y2 } for a building), hmNights (the
-- count at this home), hmNightLoc (where this sleep began, cleared when it
-- is scored), hmAwayH (hours since last at home), hmSick (0..1 homesick
-- strength), hmAtHome, hmMoodle (the level DanTraits_Moodles.lua shows).
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local clamp01 = DanTraits_Clamp01

local function homeOn() return DanTraits_SandboxOn("HomeEnabled") end

-- where home is
local HM_WINDOW        = 7       -- nights remembered
local HM_MIN_NIGHTS    = 3       -- of them at one place, for it to be home
local HM_FULL_NIGHTS   = 7       -- nights at home for full strength
local HM_SAME_TILES    = 15      -- two camps this close are the same place
local HM_PAD           = 4       -- tiles around a building that still count as home
local HM_RADIUS        = 20      -- tiles around a camp with no building
-- at home, awake, per minute at full strength
local HM_BOREDOM       = 0.3     -- boredom off per minute (0..100)
local HM_UNHAPPY       = 0.08    -- unhappiness off per minute (0..100)
local HM_STRESS        = 0.0004  -- stress off per minute (0..1)
local HM_NIGHT         = 0.05    -- added to a night's score slept at home
local HM_READ          = 0.1     -- reading time x (1 - this)
-- missing home
local HM_AWAY_ONSET_H  = 48      -- hours away before you miss it...
local HM_AWAY_RAMP_H   = 24      -- ...and this many more to miss it fully
local HM_SICK_FLOOR    = 15      -- unhappiness floor, missing home fully
local HM_SICK_RAMP     = 0.5     -- the floor's climb per minute
local HM_SICK_TIER2    = 0.5     -- homesick (the second level) from this strength
local HM_RETURN_UNHAPPY = 15     -- unhappiness off on walking back in, x strength
local HM_RETURN_STRESS = 0.1     -- stress off on walking back in, x strength
-- Homebody
local HB_MULT          = 2       -- the drains, the night bonus and the reading cut x this
local HB_ONSET_H       = 24      -- misses home after this long away
local HB_FLOOR         = 30      -- unhappiness floor, homesick fully
local HB_STRESS        = 0.0004  -- stress per minute, homesick fully
local HB_NIGHT_AWAY    = 0.1     -- off a night's score slept away from home
-- Nomad
local NM_ROUGH         = 0.1     -- added to a night's score slept with no building around

-- the place -------------------------------------------------------------------------

-- where the character is now: nil in a vehicle or with no square. A place is
-- { x, y, z } and, inside a building, b = { x1, y1, x2, y2 } (its footprint).
local function placeOf(player)
    local place = nil
    pcall(function()
        if player:getVehicle() then return end
        local sq = player:getCurrentSquare() or player:getSquare()
        if not sq then return end
        place = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
        -- the building's definition: the square keeps it (B42 IsoGridSquare.getBuildingDef);
        -- older builds go through the building
        local def = sq.getBuildingDef and sq:getBuildingDef() or nil
        if not def then
            local building = sq:getBuilding()
            def = building and building:getDef()
        end
        if def then place.b = { def:getX(), def:getY(), def:getX2(), def:getY2() } end
    end)
    return place
end
DanTraits_HomePlaceOf = placeOf

local function dist(a, b)
    local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function sameBounds(a, b)
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

-- two places are the same: one building, or two camps close together
local function samePlace(a, b)
    if not a or not b then return false end
    if a.b and b.b then return sameBounds(a.b, b.b) end
    if a.b or b.b then return false end
    return dist(a, b) <= HM_SAME_TILES
end
DanTraits_HomeSamePlace = samePlace

-- is (x, y) at this home: inside the building's footprint plus the pad, or
-- within the radius of the camp
local function atPlace(home, x, y)
    if not home then return false end
    if home.b then
        local b = home.b
        return x >= b[1] - HM_PAD and x <= b[3] + HM_PAD and y >= b[2] - HM_PAD and y <= b[4] + HM_PAD
    end
    return dist(home, { x = x, y = y }) <= HM_RADIUS
end
DanTraits_HomeAtPlace = atPlace

-- the place with most of the remembered nights (ties: the most recent), and
-- how many; nil under the floor
local function pickHome(nights)
    local best, bestN = nil, 0
    for i = #nights, 1, -1 do
        local n = 0
        for j = 1, #nights do
            if samePlace(nights[i], nights[j]) then n = n + 1 end
        end
        if n > bestN then best, bestN = nights[i], n end
    end
    if bestN < HM_MIN_NIGHTS then return nil, bestN end
    return best, bestN
end
DanTraits_HomePick = pickHome

-- how much home this is: 0 with no home or too few nights, half at the
-- floor, full at HM_FULL_NIGHTS; a Homebody's counts double
local function strength(player, d)
    if not d or not d.hmHome or (d.hmNights or 0) < HM_MIN_NIGHTS then return 0 end
    local s = 0.5 + 0.5 * (d.hmNights - HM_MIN_NIGHTS) / (HM_FULL_NIGHTS - HM_MIN_NIGHTS)
    return clamp01(s)
end
local function mult(player) return hasTrait(player, "homebody") and HB_MULT or 1 end

function DanTraits_HomeStrength(player)
    if not player or not homeOn() or hasTrait(player, "nomad") then return 0 end
    return strength(player, DanTraits_Data(player))
end
function DanTraits_HomeSick(player)
    if not player or not homeOn() then return 0 end
    return DanTraits_Data(player).hmSick or 0
end

-- the nights ------------------------------------------------------------------------

-- a night was scored (Vitality): file where it began, and see where home is
local function onNightScored(_, player, d, quality, hours, wakes, isNap)
    if not d then return nil end
    local loc = d.hmNightLoc
    d.hmNightLoc = nil
    if isNap or not loc or not homeOn() or hasTrait(player, "nomad") then return nil end
    local nights = d.hmNightList or {}
    d.hmNightList = nights
    nights[#nights + 1] = loc
    while #nights > HM_WINDOW do table.remove(nights, 1) end

    local home, n = pickHome(nights)
    if not home then return nil end
    if d.hmHome and samePlace(home, d.hmHome) then
        -- the same home: another night here (one slept elsewhere does not count)
        if samePlace(loc, d.hmHome) then d.hmNights = (d.hmNights or 0) + 1 end
        return nil
    end
    -- a new home, or the first: the nights here so far count
    local had = d.hmHome ~= nil
    d.hmHome = { x = home.x, y = home.y, z = home.z, b = home.b }
    d.hmNights = n
    d.hmSick, d.hmAwayH = 0, 0
    notifyGood(player, had and "UI_DanTraits_HomeMoved" or "UI_DanTraits_HomeFound")
    return nil
end
DanTraits_AddHook("nightScored", onNightScored)

-- a night slept at home scores better; a Homebody's night away scores worse;
-- a Nomad's night under the sky scores better
DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not d or not homeOn() then return nil end
    local loc = d.hmNightLoc
    if hasTrait(player, "nomad") then
        if loc and not loc.b then return quality + NM_ROUGH end
        return nil
    end
    local s = strength(player, d)
    if s <= 0 or not loc then return nil end
    if samePlace(loc, d.hmHome) then return quality + HM_NIGHT * s * mult(player) end
    if hasTrait(player, "homebody") then return quality - HB_NIGHT_AWAY end
    return nil
end)

-- the minute -------------------------------------------------------------------------

local function stillHere(player, d)
    d.hmAtHome, d.hmMoodle, d.hmSick = nil, 0, 0
end

local function updateHomeMinute(player, d)
    if not homeOn() or hasTrait(player, "nomad") then
        -- off, or a Nomad: nothing tracked; the sleep spot is still noted
        -- for Nomad's night under the sky
        if not homeOn() then stillHere(player, d) return end
    end
    local asleep = DanTraits_Asleep(player)
    if asleep then
        if not d.hmAsleep then
            d.hmAsleep = true
            if d.hmNightLoc == nil then d.hmNightLoc = placeOf(player) or false end
        end
    else
        d.hmAsleep = false
    end
    if hasTrait(player, "nomad") then stillHere(player, d) return end

    -- where we are
    local x, y = nil, nil
    pcall(function() x, y = player:getX(), player:getY() end)
    local atHome = x ~= nil and atPlace(d.hmHome, x, y)
    d.hmAtHome = atHome
    local s = strength(player, d)
    local stats = player:getStats()

    -- away, and back
    local sick = d.hmSick or 0
    if atHome then
        if sick > 0 then
            -- good to be home
            DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -HM_RETURN_UNHAPPY * sick)
            DanTraits_StatAdd(stats, CharacterStat.STRESS, -HM_RETURN_STRESS * sick)
            notifyGood(player, "UI_DanTraits_HomeReturn")
        end
        d.hmAwayH, sick = 0, 0
    else
        d.hmAwayH = (d.hmAwayH or 0) + 1 / 60
        if s > 0 then
            local onset = hasTrait(player, "homebody") and HB_ONSET_H or HM_AWAY_ONSET_H
            local was = sick
            sick = clamp01((d.hmAwayH - onset) / HM_AWAY_RAMP_H)
            if sick > 0 and was <= 0 then notify(player, "UI_DanTraits_Homesick") end
        else
            sick = 0
        end
    end
    d.hmSick = sick

    -- what it does, awake
    if not asleep then
        if atHome and s > 0 then
            local k = s * mult(player)
            DanTraits_StatAdd(stats, CharacterStat.BOREDOM, -DanTraits_RunHooks("homeBoredom", HM_BOREDOM * k, player))   -- ADHD: half
            DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -HM_UNHAPPY * k)
            DanTraits_StatAdd(stats, CharacterStat.STRESS, -HM_STRESS * k)
        elseif sick > 0 then
            local homebody = hasTrait(player, "homebody")
            DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, (homebody and HB_FLOOR or HM_SICK_FLOOR) * sick, HM_SICK_RAMP)
            if homebody then DanTraits_StatAdd(stats, CharacterStat.STRESS, HB_STRESS * sick) end
        end
    end

    -- the moodle: Settling In / At Home on the good side, Missing Home / Homesick on the bad
    if atHome and s > 0 then
        d.hmMoodle = s >= 1 and -2 or -1
    elseif sick > 0 then
        d.hmMoodle = sick >= HM_SICK_TIER2 and 2 or 1
    else
        d.hmMoodle = 0
    end
end

-- books go faster at home (ISReadABook's duration, like Anger's and Reading
-- Glasses' wraps; wrapped again on OnGameStart in case the class loads late)
local function wrapHome()
    DanTraits_Wrap(ISReadABook, "getDuration", "home-read", function(original, self, ...)
        local t = original(self, ...)
        if type(t) ~= "number" or t <= 1 then return t end
        local player = self.character
        if not player or not homeOn() then return t end
        local d = DanTraits_Data(player)
        if not d.hmAtHome then return t end
        local s = DanTraits_HomeStrength(player)
        if s <= 0 then return t end
        return t * (1 - HM_READ * s * mult(player))
    end)
end
wrapHome()
Events.OnGameStart.Add(wrapHome)

DanTraits_Every("minute", "Home", updateHomeMinute, 11)
