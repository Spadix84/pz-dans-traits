-- Offline test for DanTraits_Telemetry.lua: JSON encoder, snapshot, command channel.
local lists, handlers = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = { PANIC = "panic", ENDURANCE = "endurance", FATIGUE = "fatigue", THIRST = "thirst", HUNGER = "hunger", UNHAPPINESS = "unhappy", STRESS = "stress", BOREDOM = "boredom", INTOXICATION = "intox", FOOD_SICKNESS = "foodsick", PAIN = "pain" }
local now = 1000
function getTimestampMs() return now end
function isGamePaused() return false end
function getGameTime() return { getDay = function() return 3 end, getHour = function() return 14 end, getMinutes = function() return 30 end, getMonth = function() return 7 end } end
function getClimateManager() return { getAirTemperatureForCharacter = function() return 21.5 end } end
local halos = {}
HaloTextHelper = { addBadText = function(_, t) halos[#halos + 1] = t end }
-- fake files
local files = {}
function getFileWriter(name, create, append)
    if not append then files[name] = "" end
    return { write = function(_, s) files[name] = (files[name] or "") .. s end, close = function() end }
end
function getFileReader(name, create)
    local text = files[name] or ""
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    local i = 0
    return { readLine = function() i = i + 1; return lines[i] end, close = function() end }
end
local printed = {}
local realPrint = print
print = function(s) printed[#printed + 1] = tostring(s) end

assert(loadfile("../DanTraits/42/media/lua/client/DanTraits_Telemetry.lua"))()
print = realPrint
handlers.OnTick = handlers.OnTick or handlers.OnTickEvenPaused
assert(handlers.OnTick and handlers.OnGameStart, "hooks in place")

-- 1. the encoder
local enc = DanTraits_JsonEncode
assert(enc(nil) == "null" and enc(true) == "true" and enc(12) == "12" and enc(1.5) == "1.5" and enc(0/0) == "null")
assert(enc("a\"b\n") == '"a\\"b\\n"', enc("a\"b\n"))
assert(enc({}) == "{}" and enc({ 1, 2, 3 }) == "[1,2,3]")
assert(enc({ b = 1, a = { x = true } }) == '{"a":{"x":true},"b":1}', enc({ b = 1, a = { x = true } }))
assert(enc({ { dose = 2, t = 5 } }) == '[{"dose":2,"t":5}]')
assert(enc(110.123456) == "110.1235" and enc(12.0) == "12" and enc(0.5) == "0.5" and enc(2.10) == "2.1", enc(110.123456) .. " " .. enc(12.0) .. " " .. enc(2.10))

-- 2. a player, a tick, a telemetry file
local st = { panic = 12, endurance = 0.8, unhappy = 40 }
local md = { DanTraits = { glucose = 143.2, diaInsulin = { { dose = 2, t = 10 } }, asthma = 0.3 } }
local inv = {}
local player = {
    isDead = function() return false end, getHoursSurvived = function() return 5.5 end,
    getStats = function() return { get = function(_, k) return st[k] end, set = function(_, k, v) st[k] = v end } end,
    getCharacterTraits = function() return { getKnownTraits = function() return { size = function() return 2 end, get = function(_, i) return ({ "DanTraits:diabetes1", "brave" })[i + 1] end } end } end,
    getBodyDamage = function() return { getOverallBodyHealth = function() return 88 end, isInfected = function() return false end, RestoreToFullHealth = function() st.health = 100 end, ReduceGeneralHealth = function(_, n) st.health = st.health - n end } end,
    getNutrition = function() return { getWeight = function() return st.weight or 82 end, getCalories = function() return 1200 end, setWeight = function(_, w) st.weight = w end } end,
    isAsleep = function() return false end, isOutside = function() return true end, isRunning = function() return false end, isSprinting = function() return false end,
    getModData = function() return md end,
    getInventory = function() return { AddItem = function(_, n) inv[#inv + 1] = n end } end,
}
function getSpecificPlayer() return player end
DanTraits_HasTrait = function(_, k) return k == "diabetes1" end
DanTraits_DiaResistance = function() return 0.4 end
DanTraits_DiaTier = function(g) return 0, (g >= 180) and 1 or 0 end
DanTraits_SwingDropChance = function() return 3.5 end
local injected
DanTraits_DiaInject = function(_, n) injected = n; return n end
local episodes = {}
DanTraits_Episodes = { charge = function() episodes[#episodes + 1] = "charge" end }

handlers.OnTick()                       -- first tick: writes (lastWrite 0 -> now 1000)
assert(files["DanTraits_Telemetry.json"], "telemetry written")
local out = files["DanTraits_Telemetry.json"]
assert(out:find('"glucose":143.2', 1, true) and out:find('"panic":12', 1, true) and out:find('"traits":["DanTraits:diabetes1","brave"]', 1, true), out)
assert(out:find('"insulinDoses":2', 1, true) and out:find('"diaResistance":0.4', 1, true) and out:find('"diaHigh":0', 1, true), out)
assert(out:find('"health":88', 1, true) and out:find('"temperature":21.5', 1, true), out)
print("SAMPLE:" .. out)

-- 3. throttling: nothing happens 100 ms later, a write happens 500 ms later
files["DanTraits_Telemetry.json"] = nil
now = 1100; handlers.OnTick(); assert(files["DanTraits_Telemetry.json"] == nil, "no write inside 500 ms")
now = 1500; handlers.OnTick(); assert(files["DanTraits_Telemetry.json"], "write at 500 ms")

-- 4. commands: read, run, file emptied, results logged into the next snapshot
files["DanTraits_Commands.txt"] = "set glucose 40\nstat PANIC 100\nweight 110\ninject 3\ncarbs 25 slow\nmdd start 0.7 30\nepisode charge\ngive DanTraits.InsulinPen 2\nhealth 40\nhalo Shaky\nbogus 1\n\n"
now = 2100; handlers.OnTick()
assert(md.DanTraits.glucose == 40 and st.panic == 100 and st.weight == 110 and injected == 3, "set/stat/weight/inject ran")
assert(md.DanTraits.diaSlow == 25 and md.DanTraits.mddEpisode == true and md.DanTraits.mddSeverity == 0.7 and md.DanTraits.mddHoursLeft == 30, "carbs/mdd ran")
assert(#episodes == 1 and #inv == 2 and st.health == 40 and halos[1] == "Shaky", "episode/give/health/halo ran")
assert(files["DanTraits_Commands.txt"] == "", "command file emptied")
local snap = files["DanTraits_Telemetry.json"]
assert(snap:find("unknown command: bogus", 1, true) and snap:find("set glucose = 40", 1, true), "results in the log")
-- nothing to read: file untouched, no new log entries
local before = #DanTraits_JsonEncode({})
now = 3200; handlers.OnTick()
assert(files["DanTraits_Commands.txt"] == "", "empty stays empty")
assert(DanTraits_RunCommand(player, "set mddEpisode false") == "set mddEpisode = false" and md.DanTraits.mddEpisode == false)
assert(DanTraits_RunCommand(player, "set glucose nil") == "set glucose = nil" and md.DanTraits.glucose == nil)
assert(DanTraits_RunCommand(player, "stat NOPE 1"):find("unknown"), "bad stat reported")
assert(DanTraits_RunCommand(player, "   ") == nil, "blank ignored")

-- 5. story events land in the snapshot, newest first, stamped with the game clock
assert(handlers.OnStoryEvent, "listens for story events")
handlers.OnStoryEvent(player, { source = "DanTraits", kind = "SmokerCraving", text = "I need a cigarette", tone = "bad" })
handlers.OnStoryEvent(player, { source = "OtherMod", kind = "Found", text = "Found a <photo>", tone = "good" })
handlers.OnStoryEvent(player, "not a table")
now = 4000; handlers.OnTick()
snap = files["DanTraits_Telemetry.json"]
local a, b = snap:find('"text":"Found a <photo>"', 1, true), snap:find('"text":"I need a cigarette"', 1, true)
assert(a and b and a < b, "both events, newest first: " .. snap)
assert(snap:find('"clock":"4/8 14:30"', 1, true) and snap:find('"source":"OtherMod"', 1, true), snap)
print("telemetry: all checks passed")
