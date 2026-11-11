-- Comfort: what the temperature around a character does to their mood and energy,
-- short of the game's own hypothermia and overheating. A 14 C house isn't dangerous,
-- but it is miserable; a warm room on a freezing night is worth having.
--
-- Everything here is this mod's own, so nothing else has to know about it:
--   * It works on the game's stats directly, with no other mod.
--   * With the Vitality Project loaded it goes through Vitality's hooks where there is
--     one (tiredness, a night's sleep, catching a cold, what home is worth), so its
--     share multiplies with Vitality's own instead of being counted twice.
--   * Moodle Framework, when it is there, shows the three moodles; without it the
--     character says a line when things change.
--
-- The reading, once a game minute for each local player:
--   feels   the air around the character, wind chill included outdoors. Indoors it is
--           the room's temperature from this mod's model.
--   warmth  0..1, how well dressed: the game's own clothing insulation over the body
--           (so wet, torn and worn-out clothes count for less), weighted by how much
--           skin each part is. Asleep, the bedclothes add BED_WARMTH to the cold end
--           only: in a warm room the covers come off, so bed never makes it too warm.
--           The game's numbers run well past 1: an item of insulation x counts
--           2x + x^3/2 on each part it covers (a T-shirt 0.4, jeans 1.6, a padded
--           jacket 2.3), layers add up, and each layer adds 0.05. NODE_FULL is what a
--           part has in full winter gear, and is 1 on our scale.
--   band    comfortable between low and high. Naked that is 21 to 27 C; every bit of
--           warmth lowers both ends (a T-shirt and jeans: about 16 to 25 C; a sweater
--           over it: about 14 to 24 C; full winter gear: about 4 to 20 C). Working
--           hard lowers the cold end further.
-- Too far under the band is chill, too far over is stuffy, each 0..1 and full at SPAN
-- degrees out. Comfortable indoors while it is cold or hot outside is cosy.
-- The three meters follow those targets over about an hour (RATE), so walking through
-- a cold hall does nothing and a night in a cold house does.
--
-- What they do, each scaled by the meter and the sandbox's Comfort Strength (%):
--   chill   awake: unhappiness and stress creep up (to a cap, never past it). Asleep:
--           a worse night. Colds catch easier (Vitality's catchCold).
--   stuffy  awake: tiredness builds faster, and a little unhappiness. Asleep: a worse
--           night.
--   cosy    awake: unhappiness and stress ease. A small buff, and home does more good
--           (Vitality's homeGood).
--
-- Kept in the player's ModData (DansClimateComfort): chill, stuffy, cosy, kind ("warm"
-- or "cool", which sort of cosy), the last reading (feels, low, high, warmth), and the
-- running sums of a sleep.
require "DansClimate_Climate"

DansClimate = DansClimate or {}
local Comfort = {}
DansClimate.Comfort = Comfort

Comfort.MODDATA = "DansClimateComfort"

-- the band
Comfort.LOW_BARE = 21          -- C: naked, at rest, colder than this is cold
Comfort.LOW_PER_WARMTH = 20    -- ...and this many degrees lower fully dressed for winter
Comfort.HIGH_BARE = 27         -- C: naked, warmer than this is too warm
Comfort.HIGH_PER_WARMTH = 8    -- ...and this many degrees lower in full winter gear
Comfort.NODE_FULL = 3.5        -- a body part's insulation, in the game's numbers, in full winter gear
Comfort.SPAN = 8               -- degrees outside the band at which a meter's target is full
Comfort.BED_WARMTH = 0.35      -- what the bedclothes add while asleep (the cold end only)
Comfort.MET_REST = 1.5         -- the game's metabolic rate at rest...
Comfort.MET_HARD = 4.5         -- ...and working hard, by which the cold end is
Comfort.ACTIVE_SHIFT = 5       -- ...this many degrees lower
-- cosy: comfortable indoors, the room really warm (or cool), and the weather not
Comfort.COSY_ROOM_WARM = 17    -- C: the room is at least this for warm-cosy
Comfort.COSY_OUT_COLD = 12     -- C: outside at or under this it starts...
Comfort.COSY_OUT_FULL = 0      -- ...and is full here
Comfort.COOL_ROOM_MAX = 26     -- C: the room is at most this for cool-cosy
Comfort.COOL_OUT_HOT = 28      -- C: outside at or over this it starts...
Comfort.COOL_OUT_FULL = 36     -- ...and is full here
Comfort.RATE = 1 / 60          -- a meter moves this much of its range a game minute

-- the effects, per game hour at a full meter
Comfort.CHILL_UNHAPPY = 2.0    -- unhappiness points (of 100)
Comfort.CHILL_STRESS = 0.02    -- stress (of 1)
Comfort.STUFFY_UNHAPPY = 1.0
Comfort.STUFFY_FATIGUE = 0.25  -- tiredness builds this much faster (x1.25)
Comfort.COSY_UNHAPPY = 2.0     -- eased
Comfort.COSY_STRESS = 0.03     -- eased
Comfort.UNHAPPY_CAP = 40       -- discomfort alone never pushes unhappiness past this...
Comfort.STRESS_CAP = 0.4       -- ...or stress past this
Comfort.NIGHT_COST = 0.15      -- a night slept in full discomfort is this much worse
Comfort.COLD_CATCH = 1.0       -- Vitality: colds catch this much easier in a full chill (x2)
Comfort.HOME_COSY = 0.25       -- Vitality: home does this much more good while cosy...
Comfort.HOME_BAD = 0.5         -- ...and this much less in a full chill or stuffiness
-- the moodles: a meter at or over these shows level 1 and level 2
Comfort.LEVELS = { 0.25, 0.65 }

local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

function Comfort.enabled()
    local sv = SandboxVars and SandboxVars.DansClimate
    return not (sv and sv.ComfortEnabled == false)
end

-- the sandbox's Comfort Strength (%) as a factor
function Comfort.strength()
    return math.max(0, DansClimate.Climate.sandbox("ComfortStrength", 100)) / 100
end

-- The Vitality Project's API, or nil without it.
function Comfort.vitality()
    local V = VitalityProject
    if V and V.API_VERSION and V.addHook then return V end
    return nil
end

function Comfort.data(player)
    local md = player:getModData()
    local d = md[Comfort.MODDATA]
    if not d then
        d = { chill = 0, stuffy = 0, cosy = 0 }
        md[Comfort.MODDATA] = d
    end
    return d
end

local function thermo(player)
    local bd = player:getBodyDamage()
    return bd and bd:getThermoregulator()
end

-- 0..1: how well dressed, from the game's own insulation of each body part
function Comfort.warmth(player)
    local t = thermo(player)
    if not t then return 0 end
    local sum, skin = 0, 0
    for i = 0, t:getNodeSize() - 1 do
        local node = t:getNode(i)
        if node and not node:isCore() then
            local surface = node:getSkinSurface() or 0
            sum = sum + math.min(1, math.max(0, node:getInsulation() or 0) / Comfort.NODE_FULL) * surface
            skin = skin + surface
        end
    end
    if skin <= 0 then return 0 end
    return clamp01(sum / skin)
end

-- the air around the character, wind chill included
function Comfort.feels(player)
    local t = thermo(player)
    local air = t and t:getTemperatureAirAndWind()
    if type(air) == "number" then return air end
    return getClimateManager():getAirTemperatureForCharacter(player, true)
end

-- The comfortable band for this much clothing and this much work. `covers` is extra
-- warmth that can be thrown off (bedclothes): it lowers the cold end and not the warm one.
function Comfort.band(warmth, met, covers)
    local work = clamp01(((met or Comfort.MET_REST) - Comfort.MET_REST) / (Comfort.MET_HARD - Comfort.MET_REST))
    local low = Comfort.LOW_BARE - Comfort.LOW_PER_WARMTH * clamp01(warmth + (covers or 0)) - Comfort.ACTIVE_SHIFT * work
    local high = Comfort.HIGH_BARE - Comfort.HIGH_PER_WARMTH * warmth
    return low, high
end

-- What the three meters are heading for, from a reading:
--   r = { feels, outside, warmth, met, indoors, asleep, vehicle }
-- Returns chill, stuffy, cosy (each 0..1), kind ("warm", "cool" or nil), low, high.
function Comfort.targets(r)
    local warmth = clamp01(r.warmth or 0)
    local low, high = Comfort.band(warmth, r.asleep and Comfort.MET_REST or r.met, r.asleep and Comfort.BED_WARMTH or 0)
    if r.vehicle then return 0, 0, 0, nil, low, high end   -- a car has its own heater and its own rules
    local chill = clamp01((low - r.feels) / Comfort.SPAN)
    local stuffy = clamp01((r.feels - high) / Comfort.SPAN)
    local cosy, kind = 0, nil
    if r.indoors and chill == 0 and stuffy == 0 and r.outside then
        local warm, cool = 0, 0
        if r.feels >= Comfort.COSY_ROOM_WARM then
            warm = clamp01((Comfort.COSY_OUT_COLD - r.outside) / (Comfort.COSY_OUT_COLD - Comfort.COSY_OUT_FULL))
        end
        if r.feels <= Comfort.COOL_ROOM_MAX then
            cool = clamp01((r.outside - Comfort.COOL_OUT_HOT) / (Comfort.COOL_OUT_FULL - Comfort.COOL_OUT_HOT))
        end
        if warm >= cool and warm > 0 then cosy, kind = warm, "warm" elseif cool > 0 then cosy, kind = cool, "cool" end
    end
    return chill, stuffy, cosy, kind, low, high
end

-- Read the character and the weather.
function Comfort.read(player)
    local t = thermo(player)
    local climate = getClimateManager()
    return {
        feels = Comfort.feels(player),
        outside = climate and climate:getTemperature() or nil,
        warmth = Comfort.warmth(player),
        met = t and t:getMetabolicRate() or Comfort.MET_REST,
        indoors = not player:isOutside(),
        asleep = player:isAsleep(),
        vehicle = player:getVehicle() ~= nil,
    }
end

local function approach(value, target, step)
    if value < target then return math.min(target, value + step) end
    return math.max(target, value - step)
end

-- the top of each stat's range, as the game keeps them
local TOP = { UNHAPPINESS = 100, STRESS = 1, FATIGUE = 1 }

-- Move a stat (by name) by an amount, inside its range; a rise stops at the cap.
local function add(stats, name, amount, cap)
    local stat = CharacterStat and CharacterStat[name]
    if not stat or amount == 0 then return end
    local now = stats:get(stat) or 0
    if amount > 0 then
        if cap and now >= cap then return end
        stats:set(stat, math.min(cap or TOP[name], now + amount))
    else
        stats:set(stat, math.max(0, now + amount))
    end
end

local function fatigueOf(stats)
    local stat = CharacterStat and CharacterStat.FATIGUE
    return stat and stats:get(stat) or nil
end

-- 0, 1 or 2 for a meter
function Comfort.level(value)
    if value >= Comfort.LEVELS[2] then return 2 end
    if value >= Comfort.LEVELS[1] then return 1 end
    return 0
end

-- One game minute for one character: move the meters, apply what they do.
function Comfort.minute(player)
    local d = Comfort.data(player)
    if not Comfort.enabled() then
        d.chill, d.stuffy, d.cosy, d.kind = 0, 0, 0, nil
        return d
    end
    local r = Comfort.read(player)
    if type(r.feels) ~= "number" then return d end
    local chill, stuffy, cosy, kind, low, high = Comfort.targets(r)
    d.chill = approach(d.chill or 0, chill, Comfort.RATE)
    d.stuffy = approach(d.stuffy or 0, stuffy, Comfort.RATE)
    d.cosy = approach(d.cosy or 0, cosy, Comfort.RATE)
    if kind then d.kind = kind elseif d.cosy == 0 then d.kind = nil end
    d.feels, d.low, d.high, d.warmth = r.feels, low, high, r.warmth

    local k = Comfort.strength()
    local stats = player:getStats()
    local vitality = Comfort.vitality()
    local fatigue = fatigueOf(stats)
    local bad = math.max(d.chill, d.stuffy)
    if r.asleep then
        if not d.asleep then d.nightSum, d.nightMinutes = 0, 0 end   -- a new sleep
        d.nightSum = (d.nightSum or 0) + bad
        d.nightMinutes = (d.nightMinutes or 0) + 1
        -- without Vitality's night score: sleep takes the tiredness off slower
        if not vitality and fatigue and d.lastFatigue and fatigue < d.lastFatigue then
            add(stats, "FATIGUE", (d.lastFatigue - fatigue) * Comfort.NIGHT_COST * bad * k)
        end
    elseif k > 0 then
        local hour = k / 60
        add(stats, "UNHAPPINESS", (Comfort.CHILL_UNHAPPY * d.chill + Comfort.STUFFY_UNHAPPY * d.stuffy) * hour, Comfort.UNHAPPY_CAP)
        add(stats, "STRESS", Comfort.CHILL_STRESS * d.chill * hour, Comfort.STRESS_CAP)
        add(stats, "UNHAPPINESS", -Comfort.COSY_UNHAPPY * d.cosy * hour)
        add(stats, "STRESS", -Comfort.COSY_STRESS * d.cosy * hour)
        -- without Vitality's fatigue pipeline: add our share of what tiredness rose
        if not vitality and fatigue and d.lastFatigue and fatigue > d.lastFatigue then
            add(stats, "FATIGUE", (fatigue - d.lastFatigue) * Comfort.STUFFY_FATIGUE * d.stuffy * k)
        end
    end
    d.asleep = r.asleep and true or nil
    d.lastFatigue = fatigueOf(stats)
    return d
end

-- What another mod may ask: the meters and the last reading. All zero for a character
-- never looked at, or with Comfort switched off.
function Comfort.get(player)
    local d = Comfort.data(player)
    return {
        chill = d.chill or 0, stuffy = d.stuffy or 0, cosy = d.cosy or 0, kind = d.kind,
        feels = d.feels, low = d.low, high = d.high, warmth = d.warmth,
    }
end

-- The Vitality Project's side: its hooks see our meters. Registered once.
function Comfort.hookVitality()
    local V = Comfort.vitality()
    if not V or Comfort.hooked then return false end
    Comfort.hooked = true
    -- tiredness builds faster when it is too warm
    V.addHook("fatigueRise", function(rise, player)
        if not Comfort.enabled() or not rise or rise <= 0 or player:isAsleep() then return nil end
        return rise * (1 + Comfort.STUFFY_FATIGUE * (Comfort.data(player).stuffy or 0) * Comfort.strength())
    end)
    -- a night slept cold or too warm scores worse
    V.addHook("nightQuality", function(quality, player)
        local d = Comfort.data(player)
        local minutes = d.nightMinutes or 0
        local mean = minutes > 0 and (d.nightSum or 0) / minutes or 0
        d.nightSum, d.nightMinutes = 0, 0
        if not Comfort.enabled() or not quality or mean <= 0 then return nil end
        return quality * (1 - Comfort.NIGHT_COST * mean * Comfort.strength())
    end)
    -- colds catch easier in a chill
    V.addHook("catchCold", function(rise, player)
        if not Comfort.enabled() or not rise or rise <= 0 then return nil end
        return rise * (1 + Comfort.COLD_CATCH * (Comfort.data(player).chill or 0) * Comfort.strength())
    end)
    -- home is worth more warm (or cool), less when it is miserable
    V.addHook("homeGood", function(good, player)
        if not Comfort.enabled() or not good then return nil end
        local d = Comfort.data(player)
        local k = Comfort.strength()
        return good * math.max(0, 1 + (Comfort.HOME_COSY * (d.cosy or 0) - Comfort.HOME_BAD * math.max(d.chill or 0, d.stuffy or 0)) * k)
    end)
    return true
end

function Comfort.everyMinute()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            local d = Comfort.minute(player)
            if Comfort.show then Comfort.show(player, d) end   -- the client's moodles and lines
        end
    end
end

-- Vitality is optional: ask for its API if it is installed, and hook in once the game
-- starts (its files may load after ours).
pcall(require, "DanTraits_API")
Events.OnGameStart.Add(Comfort.hookVitality)
if not isServer() then Events.EveryOneMinute.Add(Comfort.everyMinute) end

return Comfort
