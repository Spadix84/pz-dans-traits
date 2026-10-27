-- Spiffo Pup: the pet's rules, apart from the screens. A pup is a plain table
-- of numbers and flags, the same shape it has in the save (Pup.write), so
-- the time the console was off is caught up from the save alone.
--
-- Needs: food, fun and clean, 0..100. Each game hour food falls FOOD_FALL and
-- fun FUN_FALL; every MESS_HOURS a mess takes MESS_CLEAN off clean. With the
-- lights off the pup sleeps and all of it runs at SLEEP_RATE (the mess clock
-- too). Any need at 0 makes it sick; sick for SICK_HOURS, it runs away. Care
-- that lifts every need above 0 makes it well again.

require "VitalityCartridges/Core"

VitalityCartridges.SpiffoPup = VitalityCartridges.SpiffoPup or {}

local Pup = {}
VitalityCartridges.SpiffoPup.Pup = Pup

Pup.FULL = 100
Pup.FOOD_FALL = 8                -- a game hour
Pup.FUN_FALL = 6
Pup.MESS_HOURS = 6
Pup.MESS_CLEAN = 25
Pup.MESS_MAX = 4                 -- four messes take clean to 0
Pup.SLEEP_RATE = 0.5
Pup.SICK_HOURS = 24
Pup.FEED = 40
Pup.CATCH_FUN = 10               -- a catch in the play game

local STEP_HOURS = 1             -- the longest step of a catch-up, so a mess lands on its hour
local EPS = 1e-6                 -- hours: sums of minutes come out a hair off the round number

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function readNumber(v, lo, hi, default)
    if type(v) ~= "number" or v ~= v then return default end
    return clamp(v, lo, hi)
end

-- a new pup, just out of its egg, at the given hours of its clock; world says
-- whether those are the world's hours (from Vitality) or the console's own
function Pup.new(at, world)
    return {
        food = Pup.FULL, fun = Pup.FULL, clean = Pup.FULL,
        messes = 0, messClock = 0,
        sick = false, sickHours = 0,
        lights = true, age = 0,
        at = at, world = world == true,
        gone = false,
    }
end

-- the pup kept in a save, every value checked; nil when the save holds none
function Pup.read(saved)
    if type(saved) ~= "table" then return nil end
    local p = Pup.new(readNumber(saved.at, 0, 1e9, 0), saved.world == true)
    if type(saved.at) ~= "number" then p.world = false end
    p.food = readNumber(saved.food, 0, Pup.FULL, Pup.FULL)
    p.fun = readNumber(saved.fun, 0, Pup.FULL, Pup.FULL)
    p.clean = readNumber(saved.clean, 0, Pup.FULL, Pup.FULL)
    p.messes = math.floor(readNumber(saved.messes, 0, Pup.MESS_MAX, 0))
    p.messClock = readNumber(saved.messClock, 0, Pup.MESS_HOURS, 0)
    p.sickHours = readNumber(saved.sickHours, 0, Pup.SICK_HOURS, 0)
    p.lights = saved.lights ~= false
    p.age = readNumber(saved.age, 0, 1e7, 0)
    p.sick = Pup.lowest(p) <= 0
    if not p.sick then p.sickHours = 0 end
    return p
end

-- the pup as the save keeps it
function Pup.write(p)
    return {
        food = p.food, fun = p.fun, clean = p.clean,
        messes = p.messes, messClock = p.messClock,
        sickHours = p.sickHours, lights = p.lights, age = p.age,
        at = p.at, world = p.world,
    }
end

function Pup.lowest(p)
    return math.min(p.food, p.fun, p.clean)
end

-- hours of the pup's life pass: the needs fall, messes come, sickness counts
function Pup.advance(p, hours)
    local left = hours
    while left > EPS and not p.gone do
        local rate = p.lights and 1 or Pup.SLEEP_RATE
        local toMess = (Pup.MESS_HOURS - p.messClock) / rate
        local mess = toMess <= math.min(left, STEP_HOURS) + EPS
        local step = mess and math.min(toMess, left) or math.min(left, STEP_HOURS)
        local foodFall, funFall = Pup.FOOD_FALL * rate, Pup.FUN_FALL * rate
        if p.sick then
            p.sickHours = p.sickHours + step
        else
            -- the hour a need reaches 0 inside this step (clean only falls at a mess)
            local zero = math.min(p.food / foodFall, p.fun / funFall)
            if zero <= step then
                p.sick = true
                p.sickHours = step - zero
            end
        end
        p.food = math.max(0, p.food - foodFall * step)
        p.fun = math.max(0, p.fun - funFall * step)
        p.age = p.age + step
        left = left - step
        if mess then
            p.messClock = 0
            p.messes = math.min(p.messes + 1, Pup.MESS_MAX)
            p.clean = math.max(0, p.clean - Pup.MESS_CLEAN)
            if p.clean <= 0 and not p.sick then
                p.sick = true
                p.sickHours = 0
            end
        else
            p.messClock = p.messClock + step * rate
        end
        if p.sickHours >= Pup.SICK_HOURS - EPS then p.gone = true end
    end
end

-- after care: every need above 0 again makes it well
local function checkWell(p)
    if p.sick and Pup.lowest(p) > 0 then
        p.sick = false
        p.sickHours = 0
    end
end

-- the care actions: each returns whether it did anything
function Pup.feed(p)
    if p.food >= Pup.FULL then return false end
    p.food = math.min(Pup.FULL, p.food + Pup.FEED)
    checkWell(p)
    return true
end

function Pup.play(p, catches)
    p.fun = math.min(Pup.FULL, p.fun + catches * Pup.CATCH_FUN)
    checkWell(p)
    return true
end

function Pup.clean(p)
    if p.messes == 0 and p.clean >= Pup.FULL then return false end
    p.clean = Pup.FULL
    p.messes = 0
    checkWell(p)
    return true
end

function Pup.toggleLights(p)
    p.lights = not p.lights
    return true
end
