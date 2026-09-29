-- Offline test for DanTraits_Telemetry.lua: JSON encoder, snapshot, command channel.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.now = 1000
function isGamePaused() return false end
function getGameTime() return { getDay = function() return 3 end, getHour = function() return 14 end, getMinutes = function() return 30 end, getMonth = function() return 7 end } end
H.climate.temp = 21.5
local halos = H.halo
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

H.load("client/DanTraits_Telemetry.lua")
print = realPrint
local tickName = H.handlers.OnTick and "OnTick" or "OnTickEvenPaused"
local tick = H.on(tickName)
H.expectHooks(tickName, "OnGameStart")

-- 1. the encoder
local enc = DanTraits_JsonEncode
assert(enc(nil) == "null" and enc(true) == "true" and enc(12) == "12" and enc(1.5) == "1.5" and enc(0/0) == "null")
assert(enc("a\"b\n") == '"a\\"b\\n"', enc("a\"b\n"))
assert(enc({}) == "{}" and enc({ 1, 2, 3 }) == "[1,2,3]")
assert(enc({ b = 1, a = { x = true } }) == '{"a":{"x":true},"b":1}', enc({ b = 1, a = { x = true } }))
assert(enc({ { dose = 2, t = 5 } }) == '[{"dose":2,"t":5}]')
assert(enc(110.123456) == "110.1235" and enc(12.0) == "12" and enc(0.5) == "0.5" and enc(2.10) == "2.1", enc(110.123456) .. " " .. enc(12.0) .. " " .. enc(2.10))

-- 2. a player, a tick, a telemetry file
local player = H.player({ hours = 5.5, outside = true, traits = { "DanTraits:diabetes1", "brave" }, panic = 12, endurance = 0.8, unhappy = 40 })
local st, md, inv = player._st, player._md, player._inv
md.DanTraits = { glucose = 143.2, diaInsulin = { { dose = 2, t = 10 } }, asthma = 0.3 }
player.getBodyDamage = function() return { getOverallBodyHealth = function() return 88 end, isInfected = function() return false end, RestoreToFullHealth = function() st.health = 100 end, ReduceGeneralHealth = function(_, n) st.health = st.health - n end } end
player.getNutrition = function() return { getWeight = function() return st.weight or 82 end, getCalories = function() return 1200 end, setWeight = function(_, w) st.weight = w end } end
H.current = player
DanTraits_HasTrait = function(_, k) return k == "diabetes1" end
DanTraits_DiaResistance = function() return 0.4 end
DanTraits_DiaTier = function(g) return 0, (g >= 180) and 1 or 0 end
DanTraits_SwingDropChance = function() return 3.5 end
local injected
DanTraits_DiaInject = function(_, n) injected = n; return n end
local episodes = {}
DanTraits_Episodes = { charge = function() episodes[#episodes + 1] = "charge" end }

tick()                       -- first tick: writes (lastWrite 0 -> now 1000)
assert(files["DanTraits_Telemetry.json"], "telemetry written")
local out = files["DanTraits_Telemetry.json"]
assert(out:find('"glucose":143.2', 1, true) and out:find('"panic":12', 1, true) and out:find('"traits":["DanTraits:diabetes1","brave"]', 1, true), out)
assert(out:find('"insulinDoses":2', 1, true) and out:find('"diaResistance":0.4', 1, true) and out:find('"diaHigh":0', 1, true), out)
assert(out:find('"health":88', 1, true) and out:find('"temperature":21.5', 1, true), out)
print("SAMPLE:" .. out)

-- 3. throttling: nothing happens 100 ms later, a write happens 500 ms later
files["DanTraits_Telemetry.json"] = nil
H.now = 1100; tick(); assert(files["DanTraits_Telemetry.json"] == nil, "no write inside 500 ms")
H.now = 1500; tick(); assert(files["DanTraits_Telemetry.json"], "write at 500 ms")

-- 4. commands: read, run, file emptied, results logged into the next snapshot
files["DanTraits_Commands.txt"] = "set glucose 40\nstat PANIC 100\nweight 110\ninject 3\ncarbs 25 slow\nmdd start 0.7 30\nepisode charge\ngive DanTraits.InsulinPen 2\nhealth 40\nhalo Shaky\nbogus 1\n\n"
H.now = 2100; tick()
assert(md.DanTraits.glucose == 40 and st.panic == 100 and st.weight == 110 and injected == 3, "set/stat/weight/inject ran")
assert(md.DanTraits.diaSlow == 25 and md.DanTraits.mddEpisode == true and md.DanTraits.mddSeverity == 0.7 and md.DanTraits.mddHoursLeft == 30, "carbs/mdd ran")
assert(#episodes == 1 and #inv == 2 and st.health == 40 and halos[1] == "Shaky", "episode/give/health/halo ran")
assert(files["DanTraits_Commands.txt"] == "", "command file emptied")
local snap = files["DanTraits_Telemetry.json"]
assert(snap:find("unknown command: bogus", 1, true) and snap:find("set glucose = 40", 1, true), "results in the log")
-- nothing to read: file untouched, no new log entries
local before = #DanTraits_JsonEncode({})
H.now = 3200; tick()
assert(files["DanTraits_Commands.txt"] == "", "empty stays empty")
assert(DanTraits_RunCommand(player, "set mddEpisode false") == "set mddEpisode = false" and md.DanTraits.mddEpisode == false)
assert(DanTraits_RunCommand(player, "set glucose nil") == "set glucose = nil" and md.DanTraits.glucose == nil)
assert(DanTraits_RunCommand(player, "stat NOPE 1"):find("unknown"), "bad stat reported")
assert(DanTraits_RunCommand(player, "   ") == nil, "blank ignored")

-- 5. story events land in the snapshot, newest first, stamped with the game clock
H.expectHooks("OnStoryEvent")
H.fire("OnStoryEvent", player, { source = "DanTraits", kind = "SmokerCraving", text = "I need a cigarette", tone = "bad" })
H.fire("OnStoryEvent", player, { source = "OtherMod", kind = "Found", text = "Found a <photo>", tone = "good" })
H.fire("OnStoryEvent", player, "not a table")
H.now = 4000; tick()
snap = files["DanTraits_Telemetry.json"]
local a, b = snap:find('"text":"Found a <photo>"', 1, true), snap:find('"text":"I need a cigarette"', 1, true)
assert(a and b and a < b, "both events, newest first: " .. snap)
assert(snap:find('"clock":"4/8 14:30"', 1, true) and snap:find('"source":"OtherMod"', 1, true), snap)
-- 6. the console commands that hand off to a trait file: with the target global missing each says so
-- ("not loaded"; cough is the exception, the util file always provides it), with a stub in place each calls it with the character and reports its answer
local run = DanTraits_RunCommand
-- trait add/remove takes a mod key or a vanilla name
local savedRegistry = DanTraitsRegistry
DanTraitsRegistry = { caffeine = "dantraits:caffeine" }
assert(run(player, "trait add caffeine") == "trait add dantraits:caffeine" and player:hasTrait("dantraits:caffeine"), "trait add mod key")
assert(run(player, "trait add SMOKER") == "trait add base:smoker" and player:hasTrait("base:smoker"), "trait add vanilla")
assert(run(player, "trait remove caffeine") == "trait remove dantraits:caffeine" and not player:hasTrait("dantraits:caffeine"), "trait remove")
assert(run(player, "trait add nope"):find("unknown", 1, true) and run(player, "trait"):find("add|remove", 1, true), "trait errors")
run(player, "trait remove smoker")
DanTraitsRegistry = savedRegistry
-- lua runs a line with player and d in scope (the game has loadstring; Lua 5.3 has load)
loadstring = loadstring or load
assert(run(player, "lua d.luaProbe = 7; return d.luaProbe + 1") == "lua: 8" and md.DanTraits.luaProbe == 7, "lua command")
assert(run(player, "lua return (("):find("^lua: "), "lua syntax error reported")
md.DanTraits.luaProbe = nil
for _, name in ipairs({ "metformin", "inhaler", "fracture", "drop", "gluten", "antidep", "attrib" }) do
  assert(run(player, name .. " on"):find("not loaded", 1, true), name .. ": says so when its file is missing")
end
local calls = {}
local function stub(global, result)
  _G[global] = function(...) calls[#calls + 1] = { global, ... }; return result end
end
local function last() return calls[#calls] end

stub("DanTraits_DiaOnPill", "taken")
assert(run(player, "metformin") == "metformin: taken" and last()[1] == "DanTraits_DiaOnPill" and last()[2] == player, "metformin")
stub("DanTraits_UseInhaler", true)
assert(run(player, "inhaler") == "inhaler: true" and last()[1] == "DanTraits_UseInhaler" and last()[2] == player, "inhaler")
stub("DanTraits_BrittleFracture", true)
assert(run(player, "fracture") == "fracture: true" and last()[1] == "DanTraits_BrittleFracture" and last()[2] == player, "fracture")
stub("DanTraits_FumbleDrop", true)
local dropped = run(player, "drop")
assert(dropped:find("^drop") and not dropped:find("not loaded", 1, true) and last()[1] == "DanTraits_FumbleDrop" and last()[2] == player, "drop: " .. tostring(dropped))
stub("DanTraits_Cough")
assert(run(player, "cough") == "cough, radius 10" and last()[1] == "DanTraits_Cough" and last()[3] == 10 and last()[4] == "console" and last()[5] == true, "cough default radius")
assert(run(player, "cough 25") == "cough, radius 25" and last()[3] == 25, "cough radius")
stub("DanTraits_GlutenDose")
assert(run(player, "gluten") == "gluten dose 50 carbs" and last()[3] == 50 and last()[4] == false, "gluten default dose, onset wait")
assert(run(player, "gluten 80 now") == "gluten dose 80 carbs (no onset wait)" and last()[3] == 80 and last()[4] == true, "gluten now")
stub("DanTraits_MddOnPill", "ok")
assert(run(player, "antidep") == "antidepressant: ok" and last()[1] == "DanTraits_MddOnPill" and last()[2] == player, "antidep")
local attribution
DanTraits_AttribSet = function(on) attribution = on end
DanTraits_AttribReset = function() attribution = "reset" end
assert(run(player, "attrib on") == "attribution on" and attribution == true, "attrib on")
assert(run(player, "attrib off") == "attribution off" and attribution == false, "attrib off")
assert(run(player, "attrib reset") == "attribution reset" and attribution == "reset", "attrib reset")
assert(run(player, "attrib what"):find("^attrib:"), "attrib usage")
assert(run(player, "echo hello  there world") == "hello there world", "echo joins the words")
assert(run(player, "echo") == "", "echo with nothing")
-- a handler that throws is reported, not raised
DanTraits_UseInhaler = function() error("boom") end
assert(run(player, "inhaler"):find("^inhaler failed"), "a failing command is reported")

H.pass()
