-- Vitality Challenges: The Last Broadcast's station, the part that only keeps
-- score (plans/last-broadcast.md). The world side (the studio, the generator,
-- going on air) is VitalityChallenges_LastBroadcast.lua; the window and the
-- timed action are VitalityChallenges_OnAir.lua.
--
-- A show is a running order: the station ID and the day, then the segments
-- picked at the desk (the weather; places you have been since the last show),
-- then the sign-off. Each line is aired on its own on LBMW 93.2 and said by
-- the character, one every few seconds by its length.
--
-- One show a night, started between 18:00 and 19:00. The evening is settled
-- at 20:00 (a show started at 18:59 is over by then): a show aired resets the
-- count of evenings missed in a row; a second evening missed in a row is more
-- than two days between shows and fails the challenge (the game carries on).
-- The walk there gets one more: the first show is due by the third evening.
-- Thirty shows win it.
--
-- Listeners are the score: word of mouth brings a share of them again after
-- every show, plus a little for each segment, a running order unlike the
-- last one, and each fresh place named; a missed evening loses a share.

VitalityChallenges = VitalityChallenges or {}
local VC = VitalityChallenges
local B = {}
VC.broadcast = B

B.CHANNEL = "68775c28-19e1-4737-9ba5-ce681d15f52d"   -- LBMW - Kentucky Radio, vanilla's own (93.2)
B.SLOT_HOUR = 18
B.SLOT_END = 19
B.SETTLE_HOUR = 20
B.SHOWS_TO_WIN = 30
B.MISSED_MAX = 1          -- evenings missed in a row allowed (two in a row: more than two days between shows)
B.MISSED_START = -1       -- the walk there: this many evenings free before the first show (nothing lost, nothing said)
B.START_DAY = 14          -- the story's day at the start: vanilla's stations are all gone by 13
B.LISTENERS_START = 40
B.GROWTH = 0.08           -- word of mouth: this share of the audience again after a show...
B.SHOW_BASE = 6           -- ...plus this...
B.PER_SEGMENT = 5         -- ...this for each segment between the ID and the sign-off...
B.FRESH = 6               -- ...this for a running order unlike the last show's...
B.PER_PLACE = 4           -- ...and this for each fresh place named
B.MISSED_LOSS = 0.15      -- a missed evening loses this share
B.PLACES_PER_SHOW = 2
B.STOCKED_AT = 12         -- items left in a room's containers from which it still has stock
B.GAP_MS = { 3500, 7000 } -- a line's time on air, real milliseconds, by its length...
B.GAP_BASE_MS = 2500
B.GAP_PER_CHAR_MS = 45    -- ...this much a character on top of the base

-- the segments a running order can hold, in the order they air
B.SEGMENTS = { "weather", "places" }

-- room names worth telling people about, and what to call them on air
B.PLACES = {
    pharmacy = "pharmacy", pharmacystorage = "pharmacy", medclinic = "clinic", medicalstorage = "clinic",
    grocery = "grocery", grocerystorage = "grocery", generalstore = "store", generalstorestorage = "store",
    gasstore = "gasstation", gasstorage = "gasstation", gunstore = "gunstore", gunstorestorage = "gunstore",
    armysurplus = "armysurplus", toolstore = "hardware", toolstorestorage = "hardware",
    electronicsstore = "electronics", policestorage = "police", hospitalroom = "hospital",
    liquorstore = "liquor", bakery = "bakery", butcher = "butcher", campingstore = "camping",
    sportstore = "sports", clothesstore = "clothes", spiffo_dining = "restaurant", pizzawhirled = "restaurant",
    restaurant = "restaurant", dinerkitchen = "restaurant",
}

local function text(key, ...)
    if getText then return getText(key, ...) end
    return key
end

local function variant(prefix, n)
    return text(prefix .. "_" .. tostring(ZombRand(n) + 1))
end

function B.dayKey(gt)
    return gt:getYear() * 400 + gt:getMonth() * 32 + gt:getDay()
end

-- the story's day: day 14 at the start, one more each calendar day since
function B.storyDay(state, key)
    return B.START_DAY + math.max(0, (key or 0) - (state.startKey or key or 0))
end

function B.init(state, key)
    if state.lbStarted then return end
    state.lbStarted = true
    state.startKey = key
    state.shows = 0
    state.missedInRow = B.MISSED_START
    state.listeners = B.LISTENERS_START
    state.peak = B.LISTENERS_START
    state.places = {}
end

-- a line's time on air in real milliseconds
function B.lineGap(s)
    local ms = B.GAP_BASE_MS + B.GAP_PER_CHAR_MS * #tostring(s or "")
    return math.max(B.GAP_MS[1], math.min(B.GAP_MS[2], ms))
end

-- eight-point compass from the station to a place (x east, y south): a
-- diagonal unless one axis is under tan(22.5 degrees) of the other
local TAN_22 = 0.4142
function B.compass(dx, dy)
    local ax, ay = math.abs(dx), math.abs(dy)
    local ns, ew = dy < 0 and "n" or "s", dx < 0 and "w" or "e"
    if ay <= ax * TAN_22 then return ew end
    if ax <= ay * TAN_22 then return ns end
    return ns .. ew
end

-- a place seen: one entry a room, kept until a show names it
function B.visit(state, key, room, x, y, stocked)
    local kind = B.PLACES[room]
    if not kind then return false end
    state.places = state.places or {}
    for _, p in ipairs(state.places) do
        if p.key == key then return false end
    end
    table.insert(state.places, { key = key, kind = kind, x = x, y = y, stocked = stocked == true })
    return true
end

function B.freshPlaces(state, n)
    local out = {}
    for _, p in ipairs(state.places or {}) do
        if not p.aired then
            out[#out + 1] = p
            if n and #out >= n then break end
        end
    end
    return out
end

-- which segments can go in tonight, and why not: { weather = true, places = "IGUI_..." }
function B.available(state)
    local out = { weather = true }
    out.places = #B.freshPlaces(state) > 0 or "IGUI_VC_LB_NoPlaces"
    return out
end

local function orderKey(order)
    local parts = {}
    for _, id in ipairs(B.SEGMENTS) do
        if order[id] then parts[#parts + 1] = id end
    end
    return table.concat(parts, "+")
end

local function weatherLines(lines, forecast)
    lines[#lines + 1] = variant("IGUI_VC_LB_Weather", 3)
    local said = false
    if forecast and WeatherChannel and WeatherChannel.GetForecastString then
        pcall(function()
            lines[#lines + 1] = text("AEBS_Pre_tomorrow") .. WeatherChannel.GetForecastString(1, forecast)
            lines[#lines + 1] = WeatherChannel.GetForecastString(2, forecast)
            said = true
        end)
    end
    if not said then lines[#lines + 1] = text("IGUI_VC_LB_WeatherBlind") end
end

local function placeLines(lines, state, station)
    lines[#lines + 1] = variant("IGUI_VC_LB_Places", 3)
    for _, p in ipairs(B.freshPlaces(state, B.PLACES_PER_SHOW)) do
        local dx, dy = p.x - station.x, p.y - station.y
        local metres = math.floor(math.sqrt(dx * dx + dy * dy) / 10 + 0.5) * 10
        lines[#lines + 1] = text(p.stocked and "IGUI_VC_LB_PlaceStocked" or "IGUI_VC_LB_PlaceBare",
            text("IGUI_VC_LB_Place_" .. p.kind), tostring(metres), text("IGUI_VC_LB_Dir_" .. B.compass(dx, dy)))
    end
end

-- tonight's lines, in order: { text = ..., host = true }. opts: station {x, y},
-- clock (the time as a string), forecast (tomorrow's, from the climate forecaster)
function B.lines(state, order, key, opts)
    opts = opts or {}
    local lines = {}
    lines[#lines + 1] = variant("IGUI_VC_LB_Intro", 4)
    if (state.shows or 0) == 0 then lines[#lines + 1] = text("IGUI_VC_LB_FirstShow") end
    lines[#lines + 1] = text("IGUI_VC_LB_Time", opts.clock or "6:00", tostring(B.storyDay(state, key)))
    if order.weather then weatherLines(lines, opts.forecast) end
    if order.places and opts.station then placeLines(lines, state, opts.station) end
    if (state.shows or 0) + 1 == B.SHOWS_TO_WIN then lines[#lines + 1] = text("IGUI_VC_LB_Thirtieth") end
    lines[#lines + 1] = variant("IGUI_VC_LB_SignOff", 4)
    local out = {}
    for i, s in ipairs(lines) do out[i] = { text = s, host = true } end
    return out
end

-- a show aired in full: the count, the evening, the listeners. Returns the gain.
function B.aired(state, order, key)
    state.shows = (state.shows or 0) + 1
    state.lastShowKey = key
    state.missedInRow = 0
    local segments = 0
    for _, id in ipairs(B.SEGMENTS) do
        if order[id] then segments = segments + 1 end
    end
    local named = 0
    if order.places then
        for _, p in ipairs(B.freshPlaces(state, B.PLACES_PER_SHOW)) do
            p.aired = true
            named = named + 1
        end
    end
    local o = orderKey(order)
    local gain = math.floor((state.listeners or 0) * B.GROWTH + B.SHOW_BASE + B.PER_SEGMENT * segments
        + (o ~= state.lastOrder and B.FRESH or 0) + B.PER_PLACE * named + 0.5)
    state.lastOrder = o
    state.listeners = (state.listeners or 0) + gain
    state.peak = math.max(state.peak or 0, state.listeners)
    return gain
end

-- the evening settled at 20:00, once a day: "aired", "grace" (the walk there,
-- before the first show: no listeners lost, no word of it), "missed" or "failed"
-- ("failed" once only; after that the evenings are only counted)
function B.settle(state, key)
    if state.settledKey == key then return nil end
    state.settledKey = key
    if state.lastShowKey == key then return "aired" end
    if (state.missedInRow or 0) < 0 then
        state.missedInRow = state.missedInRow + 1
        return "grace"
    end
    state.missedInRow = (state.missedInRow or 0) + 1
    state.missed = (state.missed or 0) + 1
    state.listeners = math.floor((state.listeners or 0) * (1 - B.MISSED_LOSS))
    if state.missedInRow > B.MISSED_MAX and not state.failed and not state.won then
        state.failed = true
        return "failed"
    end
    return "missed"
end

function B.wonNow(state)
    if state.won or state.failed or (state.shows or 0) < B.SHOWS_TO_WIN then return false end
    state.won = true
    return true
end
