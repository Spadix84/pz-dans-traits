-- Project Zomboid Vitality Project: stat attribution for the dashboard.
--
-- Answers "what is pushing unhappiness (or stress, fatigue...) up?". Every
-- event handler registered from a DanTraits file is wrapped: the tracked
-- stats are read before and after it runs and the difference is credited to
-- that file (MDD, Vitality, Hangover...). Whatever the stats did that no
-- wrapped handler accounts for is the game itself, other mods, or actions
-- (eating, reading, pills), and the dashboard shows it as the remainder
-- next to the active moodles.
--
-- Loaded by DanTraits.lua before any trait file registers a handler. The
-- clock systems (minute, ten-minute, frame) register with DanTraits_Every and
-- are credited by the label they give there; every other handler is credited
-- by its file's name. Handlers from other mods pass through untouched. Measuring costs two reads of each
-- tracked stat per handler call, so it only runs while switched on: the
-- dashboard switches it on when it opens ("attrib on" / "attrib off").
-- Single player only; nothing is installed on a server.

local STATS = { "UNHAPPINESS", "STRESS", "ANGER", "BOREDOM", "PANIC", "FATIGUE", "ENDURANCE", "PAIN", "HUNGER", "THIRST",
    "FOOD_SICKNESS", "SICKNESS", "INTOXICATION", "WETNESS" }
local EVENTS = { "EveryOneMinute", "EveryTenMinutes", "EveryHours", "OnPlayerUpdate", "OnTick", "OnTickEvenPaused",
    "OnWeaponSwing", "OnPlayerGetDamage", "AddXP" }
local WINDOWS = { 10, 60 }         -- game minutes
local KEEP_MINUTES = 60
local EPS = 1e-7

local A = { enabled = false, wrapped = {}, buckets = {}, cum = nil }
DanTraits_AttribState = A

-- the stats that exist in this build, plus overall health as "health"
local keys, statObjs = {}, {}
local function resolveStats()
    if #keys > 0 or not CharacterStat then return end
    for _, name in ipairs(STATS) do
        local stat = CharacterStat[name]
        if stat then
            keys[#keys + 1] = string.lower(name)
            statObjs[#statObjs + 1] = stat
        end
    end
    keys[#keys + 1] = "health"
end

-- reads into buf (reused, indexed like keys); callers pcall it
local function readInto(player, buf)
    local stats = player:getStats()
    for i = 1, #statObjs do buf[i] = stats:get(statObjs[i]) or 0 end
    buf[#keys] = player:getBodyDamage():getOverallBodyHealth() or 0
end

local function copy(buf)
    local out = {}
    for i = 1, #keys do out[i] = buf[i] end
    return out
end

local function gameMinute()
    local ok, h = pcall(function() return getGameTime():getWorldAgeHours() end)
    return math.floor(((ok and h) or 0) * 60)
end

-- the bucket for the current game minute; a new minute takes `start` (the
-- stats before whatever is being measured) as its starting point and drops
-- buckets that fell out of the longest window
local function bucket(start)
    local m = gameMinute()
    local b = A.buckets[m]
    if b then return b end
    b = { start = copy(start), src = {} }
    A.buckets[m] = b
    for k, _ in pairs(A.buckets) do
        if k <= m - KEEP_MINUTES then A.buckets[k] = nil end
    end
    if not A.cum then A.cum = { start = copy(start), src = {}, since = m } end
    return b
end

local function credit(src, label, i, d)
    local row = src[label]
    if not row then row = {}; src[label] = row end
    row[i] = (row[i] or 0) + d
end

-- Measuring: frames nest (the minute, ten-minute and frame drivers in
-- DanTraits.lua run every system through DanTraits_Track); each frame credits
-- only what its children did not.
local depth = 0
local befores, afters, childs = {}, {}, {}

local function run(label, fn, ...)
    if not A.enabled then return fn(...) end
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player or #keys == 0 then return fn(...) end
    local d = depth + 1
    local before = befores[d] or {}; befores[d] = before
    if not pcall(readInto, player, before) then return fn(...) end
    local child = childs[d] or {}; childs[d] = child
    for i = 1, #keys do child[i] = 0 end
    depth = d
    local ok, err = pcall(fn, ...)
    depth = d - 1
    local after = afters[d] or {}; afters[d] = after
    if pcall(readInto, player, after) then
        local b = bucket(before)
        local parent = childs[d - 1]
        for i = 1, #keys do
            local total = after[i] - before[i]
            if parent and d > 1 then parent[i] = parent[i] + total end
            local own = total - child[i]
            if own > EPS or own < -EPS then
                credit(b.src, label, i, own)
                credit(A.cum.src, label, i, own)
            end
        end
    end
    if not ok then error(err) end
end

-- for code that runs several systems from one handler (the drivers in DanTraits.lua, DanTraits_Every)
function DanTraits_Track(label, fn, ...)
    return run(label, fn, ...)
end

local function labelFor(fn)
    if not getFilenameOfClosure then return nil end
    local ok, path = pcall(getFilenameOfClosure, fn)
    if not ok or type(path) ~= "string" then return nil end
    local base = string.match(path, "([^/\\]+)%.lua$")
    if not base or string.sub(base, 1, 9) ~= "DanTraits" then return nil end
    if base == "DanTraits" then return "core" end
    if base == "DanTraits_Telemetry" then return "dashboard commands" end
    return (string.gsub(string.sub(base, 11), "_", " "))
end

local function install()
    if isServer and isServer() then return end
    if not Events then return end
    for _, name in ipairs(EVENTS) do
        local ev = Events[name]
        local add = ev and ev.Add
        if add then
            local originals = {}
            ev.Add = function(fn)
                local label = labelFor(fn)
                if not label then return add(fn) end
                local wrapped = function(...) return run(label, fn, ...) end
                originals[fn] = wrapped
                A.wrapped[#A.wrapped + 1] = label .. " / " .. name
                return add(wrapped)
            end
            local remove = ev.Remove
            if remove then
                ev.Remove = function(fn)
                    local wrapped = originals[fn]
                    if wrapped then originals[fn] = nil; return remove(wrapped) end
                    return remove(fn)
                end
            end
        end
    end
end

-- Report --------------------------------------------------------------------------
local function sumWindow(minutes, now, cur)
    local src, start, startMinute = {}, nil, nil
    for m, b in pairs(A.buckets) do
        if m > now - minutes then
            if not startMinute or m < startMinute then startMinute, start = m, b.start end
            for label, row in pairs(b.src) do
                for i, v in pairs(row) do credit(src, label, i, v) end
            end
        end
    end
    return src, start, startMinute
end

local function toNamed(src, start, cur)
    local out = { total = {}, sources = {} }
    if start then
        for i = 1, #keys do out.total[keys[i]] = cur[i] - start[i] end
    end
    for label, row in pairs(src) do
        local named = {}
        for i, v in pairs(row) do named[keys[i]] = v end
        out.sources[label] = named
    end
    return out
end

function DanTraits_AttribReport(player)
    resolveStats()
    local out = { enabled = A.enabled, wrapped = A.wrapped }
    if not A.enabled or not player then return out end
    local current = {}
    if not pcall(readInto, player, current) then return out end
    bucket(current)
    local now = gameMinute()
    local windows = {}
    for _, minutes in ipairs(WINDOWS) do
        local src, start, startMinute = sumWindow(minutes, now, current)
        local w = toNamed(src, start, current)
        w.name = minutes .. " game min"
        w.span = startMinute and (now - startMinute + 1) or 0
        windows[#windows + 1] = w
    end
    if A.cum then
        local w = toNamed(A.cum.src, A.cum.start, current)
        w.name = "since reset"
        w.span = now - A.cum.since + 1
        windows[#windows + 1] = w
    end
    out.windows = windows
    return out
end

function DanTraits_AttribSet(on)
    resolveStats()
    A.enabled = on and true or false
    A.buckets = {}
    A.cum = nil
end

function DanTraits_AttribReset()
    A.buckets = {}
    A.cum = nil
end

-- the moodles showing right now, as { name = level }: the game's own reasons
local MOODLES = { "UNHAPPY", "STRESS", "BORED", "PANIC", "TIRED", "ENDURANCE", "PAIN", "HUNGRY", "THIRST", "SICK",
    "HAS_A_COLD", "DRUNK", "WET", "UNCOMFORTABLE", "NOXIOUS_SMELL", "HYPOTHERMIA", "HYPERTHERMIA", "WINDCHILL",
    "INJURED", "BLEEDING", "HEAVY_LOAD", "ANGRY", "FOOD_EATEN", "ZOMBIE", "CANT_SPRINT" }
function DanTraits_ActiveMoodles(player)
    local out = {}
    if not MoodleType or not player then return out end
    local ok, moodles = pcall(function() return player:getMoodles() end)
    if not ok or not moodles then return out end
    for _, name in ipairs(MOODLES) do
        local mt = MoodleType[name]
        if mt then
            local okL, level = pcall(function() return moodles:getMoodleLevel(mt) end)
            if okL and level and level > 0 then out[string.lower(name)] = level end
        end
    end
    return out
end

resolveStats()
install()
