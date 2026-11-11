-- Historical Weather: Knox County's real weather from 9 July 1993 to 9 July 1995.
--
-- The record (HistoricalWeather_Data.lua, one row a day, built by tools/build_data.py from
-- NOAA's Barbourville, KY station) has a day's high and low, how much rain fell and whether
-- it snowed. This file turns that into the hour's weather and puts it into the game's
-- climate through the mod slot every ClimateFloat has (setModdedValue): the game blends it
-- over its own value, never saves it, and lets an admin's weather override win. Outside
-- those two years every slot is released and the game's own weather comes back.
--
-- While the record runs, the game is told not to start weather of its own
-- (setEnabledWeatherGeneration(false); not saved either, so it is asked again at every load)
-- and any storm already going is stopped, so no storm of the game's own drifts across a
-- dry day in the record. That part is done where the weather is decided: single player or
-- the server. Every machine sets the mod slots, from the same date, to the same values.
--
-- The hour's weather:
--   temperature  low at 06:00, high at 15:00, a cosine between, down to the next day's low
--   rain/snow    the day's rain spell (start, hours, intensity), with half-hour edges; snow
--                when the hour is at or below 0.5 C, or 3 C on a day the record has snowfall
--   clouds       overcast in the rain, gathering three hours before it and clearing two
--                after; otherwise from the day's spread of temperature (a wide one is a clear
--                sky, a narrow one a grey day)
--   fog          early-morning fog after a wet day, and valley fog on clear autumn mornings
--   wind         a breeze that picks up in the afternoon, stronger in the rain
--   thunder      thunder clouds through the rain on the record's heavy summer days
-- A day with no temperature in the record leaves the temperature to the game, handed over
-- gradually across the stretch of the curve that runs into or out of the gap; a day with
-- no rain figure leaves the rain, clouds and fog to the game.

HistoricalWeather = HistoricalWeather or {}
local HW = HistoricalWeather

local floor, cos, pi, min, max = math.floor, math.cos, math.pi, math.min, math.max

-- days since 1 March of year 0 for a date (month 1..12): Howard Hinnant's days_from_civil
local function dayNumber(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = floor(y / 400)
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
    return era * 146097 + doe
end
HW.dayNumber = dayNumber

HW.FIRST = dayNumber(1993, 7, 9)   -- row 1 of the record

local function data() return HistoricalWeather_Data or {} end
local function row(i) return data()[i] end
function HW.days() local n = 0; for _ in pairs(data()) do n = n + 1 end; return n end

-- the row number for a calendar date (month 1..12), nil outside the record
function HW.index(y, m, d)
    local i = dayNumber(y, m, d) - HW.FIRST + 1
    if row(i) then return i end
    return nil
end

local function clamp(v, lo, hi) return max(lo, min(hi, v)) end
local function ease(a, b, t) return a + (b - a) * (1 - cos(pi * clamp(t, 0, 1))) / 2 end

local function high(i) local r = row(i); return r and r[1] end
local function low(i) local r = row(i); return r and r[2] end

-- temperature (C) at hour h (0..24) of row i, and how much of it to use (0..1): the rest is
-- the game's own temperature. The curve runs between anchors (a low at 06:00, a high at
-- 15:00). Where one end of a stretch is missing (the edge of a gap in the record) the known
-- end is held and handed over to the game across the stretch, so there is no jump. At the
-- very start and end of the record the hand-over runs from or to midnight, where the record
-- starts and stops. nil, 0 where the record has neither end.
function HW.temperature(i, h)
    local a, b, t, fade
    if h < 6 then          -- from yesterday's afternoon high down to this morning's low
        a, b, t = high(i - 1), low(i), (h + 9) / 15
        fade = row(i - 1) and t or h / 6
    elseif h < 15 then     -- up to the afternoon high
        a, b, t = low(i), high(i), (h - 6) / 9
        fade = t
    else                   -- down towards tomorrow morning's low
        a, b, t = high(i), low(i + 1), (h - 15) / 15
        fade = row(i + 1) and t or (h - 15) / 9
    end
    if a and b then return ease(a, b, t), 1 end
    if a then return a, 1 - ease(0, 1, fade) end
    if b then return b, ease(0, 1, fade) end
    return nil, 0
end

-- the rain spell of row i in hours from that day's 00:00: start, finish, intensity.
-- nil when the record has no rain figure that day; false when it stayed dry
local function spell(i)
    local r = row(i)
    if not r then return nil end
    if r[3] == false then return nil end
    if r[3] == nil or (r[4] or 0) <= 0 then return false end
    local s = 7 + r[3]
    return s, s + r[4], r[5]
end

-- precipitation 0..1 at hour h of row i, nil when it is the game's to decide. The record's
-- rain days run from 07:00 to 07:00, so before 07:00 it is yesterday's spell that counts
-- (a spell always ends inside its own 24 hours)
function HW.precipitation(i, h)
    local j, x = i, h
    if h < 7 then j, x = i - 1, h + 24 end
    local s, f, k = spell(j)
    if s == nil then return nil end
    if s and x >= s and x < f then
        local edge = min(1, (x - s) / 0.5, (f - x) / 0.5)
        return k * (0.3 + 0.7 * edge)
    end
    return 0
end

-- how near the hour is to rain, 0..1 (1 in it), from the spells of yesterday, today and tomorrow
local function nearRain(i, h)
    local near = 0
    for d = -1, 1 do
        local s, f = spell(i + d)
        if s then
            s, f = s + 24 * d, f + 24 * d
            local v
            if h < s then v = 1 - (s - h) / 3
            elseif h >= f then v = 1 - (h - f) / 2
            else v = 1 end
            near = max(near, v)
        end
    end
    return clamp(near, 0, 1)
end

-- the clear-or-grey of a dry day from its spread of temperature
local function dryCloud(i)
    local hi, lo = high(i), low(i)
    if hi == nil or lo == nil then return 0.35 end
    return 0.1 + 0.75 * clamp((14 - (hi - lo)) / 10, 0, 1)
end

function HW.clouds(i, h)
    local p = HW.precipitation(i, h)
    if p == nil then return nil end
    if p > 0 then return 0.8 + 0.2 * p end
    return max(dryCloud(i), 0.9 * nearRain(i, h))
end

local function rainedOn(i)
    local r = row(i)
    return r ~= nil and r[3] ~= nil and r[3] ~= false and (r[5] or 0) * (r[4] or 0) >= 0.6
end

-- m: the month (1..12), for the autumn valley fog
function HW.fog(i, h, m)
    local p = HW.precipitation(i, h)
    if p == nil then return nil end
    if p > 0 or h < 3 or h > 10 then return 0 end
    local bell = h < 6 and (h - 3) / 3 or 1 - (h - 6) / 4      -- thickest at dawn, gone by 10:00
    local clear = dryCloud(i) < 0.35 and nearRain(i, h) == 0
    if rainedOn(i - 1) and clear then return 0.45 * bell end
    if clear and m >= 8 and m <= 10 then return 0.3 * bell end
    return 0
end

function HW.wind(i, h)
    local p = HW.precipitation(i, h) or 0
    local day = h >= 9 and h <= 19 and (1 - cos(pi * (h - 9) / 10)) / 2 or 0
    local w = 0.05 + 0.08 * day
    if p > 0 then w = max(w, 0.12 + 0.25 * p) end
    return w
end

-- a thunderstorm going on at hour h of row i: its strength 0..1, the hours it has left and
-- the row it belongs to (a storm from yesterday evening can run past midnight); nil if none
function HW.storm(i, h)
    local j, x = i, h
    if h < 7 then j, x = i - 1, h + 24 end
    local r = row(j)
    if not (r and r[7]) then return nil end
    local s, f, k = spell(j)
    if not s or x < s or x >= f then return nil end
    return { strength = clamp(0.4 + 0.6 * k, 0, 1), hours = f - x, day = j }
end

-- the hour's weather for a calendar date and hour; nil outside the record
function HW.at(y, m, d, h)
    local i = HW.index(y, m, d)
    if not i then return nil end
    local temp, share = HW.temperature(i, h)
    if share <= 0 then temp = nil end
    local r = row(i)
    local snowLine = r[6] and 3 or 0.5
    return {
        index = i, temperature = temp, share = share, precipitation = HW.precipitation(i, h), clouds = HW.clouds(i, h),
        fog = HW.fog(i, h, m), wind = HW.wind(i, h), snowLine = snowLine, storm = HW.storm(i, h),
    }
end

-- the game ------------------------------------------------------------------------------
-- Once every ten game minutes (a quarter of a real minute at the default day length). The
-- game keeps a mod slot's value until it is changed, so only a value that has moved is sent
-- (about every value is a straight lookup, nothing searched); everything is sent again once an
-- hour and at load, in case anything else touched the slots.
local held = false        -- whether this machine holds the mod slots
local sky = false         -- whether the game's own weather is switched off (here, if we decide it)
local sent = {}           -- slot name -> the value last sent, or false when released
local sentShare = {}      -- slot name -> the share last sent (how much of the value is used)
local ticks = 0           -- updates since everything was last sent
local thunderDay = nil    -- the row whose thunderstorm has been started
local EPS = 0.002

local function float(climate, name)
    local id = ClimateManager and ClimateManager[name]
    return id and climate:getClimateFloat(id)
end

-- share: how much of v to use, the rest the game's own (1 when not given)
local function set(climate, name, v, all, share)
    share = share or 1
    local last = sent[name]
    if not all and last ~= nil then
        if v == nil and last == false then return end
        if v ~= nil and last ~= false and math.abs(v - last) < EPS
            and math.abs(share - (sentShare[name] or 1)) < EPS then return end
    end
    local f = float(climate, name)
    if not f then return end
    if v == nil then
        f:setEnableModded(false)
        sent[name] = false
    else
        f:setEnableModded(true)
        f:setModdedValue(v)
        f:setModdedInterpolate(share)
        sent[name] = v
        sentShare[name] = share
    end
end

local SLOTS = { "FLOAT_TEMPERATURE", "FLOAT_PRECIPITATION_INTENSITY", "FLOAT_CLOUD_INTENSITY", "FLOAT_FOG_INTENSITY",
    "FLOAT_WIND_INTENSITY" }

local function snowBool(climate)
    local id = ClimateManager and ClimateManager.BOOL_IS_SNOW
    return id and climate:getClimateBool(id)
end

-- the snow switch: true/false held, nil released
local function setSnow(climate, v, all)
    if not all and sent.snow ~= nil and sent.snow == (v == nil and "off" or v) then return end
    local b = snowBool(climate)
    if not b then return end
    if v == nil then
        b:setEnableModded(false)
        sent.snow = "off"
    else
        b:setEnableModded(true)
        b:setModdedValue(v)
        sent.snow = v
    end
end

local function release(climate)
    for _, name in ipairs(SLOTS) do set(climate, name, nil, true) end
    setSnow(climate, nil, true)
    held = false
end

-- the weather is decided here: single player, or the server
local function decides() return not (isClient and isClient()) end

local function takeSky(climate)
    if sky or not decides() then return end
    climate:setEnabledWeatherGeneration(false)
    climate:stopWeatherAndThunder()
    sky = true
end

local function giveSky(climate)
    if not sky then return end
    climate:setEnabledWeatherGeneration(true)
    sky = false
end

-- thunder clouds for a storm in the record, the way the game's own storms start them: a
-- cloud crosses the map at a random heading for the hours the rain has left, with lightning
-- and thunder as often as it is strong; a strong one (two clouds) heads for a player
local function thunder(climate, storm)
    if not storm or storm.day == thunderDay or not decides() then return end
    thunderDay = storm.day
    local clouds = climate:getThunderStorm()
    if not clouds or clouds:HasActiveThunderClouds() then return end
    local k = storm.strength
    local heading = ZombRand and ZombRand(360) or 0
    for _ = 1, (k > 0.7 and 2 or 1) do
        clouds:startThunderCloud(k, heading, 8000 * k, k, 0.6 * k, storm.hours, k > 0.7)
    end
end

-- all: send every value, not just the ones that moved
function HW.update(all)
    local climate = getClimateManager and getClimateManager()
    local gt = getGameTime and getGameTime()
    if not climate or not gt then return end
    local w = HW.at(gt:getYear(), gt:getMonth() + 1, gt:getDay() + 1, gt:getTimeOfDay())
    if not w then
        if held then release(climate) end
        giveSky(climate)
        return
    end
    ticks = ticks + 1
    if all == true or ticks >= 6 or not held then all, ticks = true, 0 else all = false end
    takeSky(climate)
    set(climate, "FLOAT_TEMPERATURE", w.temperature, all, w.share)
    set(climate, "FLOAT_PRECIPITATION_INTENSITY", w.precipitation, all)
    set(climate, "FLOAT_CLOUD_INTENSITY", w.clouds, all)
    set(climate, "FLOAT_FOG_INTENSITY", w.fog, all)
    set(climate, "FLOAT_WIND_INTENSITY", w.wind, all)
    if w.precipitation and w.precipitation > 0 then
        -- the air as it is (the game's own blended in at the edge of a gap)
        local t = (w.temperature and w.share >= 1) and w.temperature or climate:getTemperature()
        setSnow(climate, t <= w.snowLine, all)
    else
        setSnow(climate, nil, all)
    end
    thunder(climate, w.storm)
    held = true
end

-- what the hour is doing, for the console: HistoricalWeather.report()
function HW.report()
    local gt = getGameTime()
    local w = HW.at(gt:getYear(), gt:getMonth() + 1, gt:getDay() + 1, gt:getTimeOfDay())
    if not w then return "outside the record (9 Jul 1993 - 9 Jul 1995): the game's own weather" end
    local function n(v) return v == nil and "game" or string.format("%.2f", v) end
    local temp = n(w.temperature)
    if w.temperature and w.share < 1 then temp = temp .. string.format(" (%d%% of it, the rest the game's)", floor(w.share * 100 + 0.5)) end
    return string.format("day %d: %s C, rain %s, clouds %s, fog %s, wind %s%s",
        w.index, temp, n(w.precipitation), n(w.clouds), n(w.fog), n(w.wind),
        w.storm and string.format(", thunderstorm %.2f for %.1f h more", w.storm.strength, w.storm.hours) or "")
end

local function everything() HW.update(true) end
if Events then
    if Events.EveryTenMinutes then Events.EveryTenMinutes.Add(HW.update) end
    if Events.OnGameStart then Events.OnGameStart.Add(everything) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(everything) end
end
