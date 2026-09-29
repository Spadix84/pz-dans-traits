-- Offline test for DanTraits_Attrib.lua: handler wrapping, crediting, nesting, windows.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
MoodleType = { UNHAPPY = "UNHAPPY", WET = "WET", BORED = "BORED" }
H.hours = 10
local player = H.player({ unhappy = 10, stress = 0.1, fatigue = 0.2, health = 90, moodles = { UNHAPPY = 2, WET = 1 } })
local st = player._st
H.current = player
-- which file each closure "came from"
local fileOf = {}
function getFilenameOfClosure(fn) return fileOf[fn] end

H.load("shared/DanTraits_Attrib.lua")

local function mdd() st.unhappy = st.unhappy + 5 end
local function vit() st.unhappy = st.unhappy - 1; st.stress = st.stress + 0.05 end
local function other() st.unhappy = st.unhappy + 100 end
fileOf[mdd] = "C:/Users/x/Zomboid/mods/DanTraits/42/media/lua/shared/DanTraits_MDD.lua"
fileOf[vit] = "media\\lua\\shared\\DanTraits_Vitality.lua"
fileOf[other] = "C:/mods/SomeoneElse/media/lua/shared/Other.lua"
Events.EveryOneMinute.Add(mdd)
Events.OnPlayerUpdate.Add(vit)
Events.EveryOneMinute.Add(other)

-- 1. ours are wrapped, the other mod's handler is passed through as-is
assert(H.handlers.EveryOneMinute[1] ~= mdd and H.handlers.OnPlayerUpdate[1] ~= vit, "ours wrapped")
assert(H.handlers.EveryOneMinute[2] == other, "others untouched")
assert(#DanTraits_AttribState.wrapped == 2 and DanTraits_AttribState.wrapped[1] == "MDD / EveryOneMinute", DanTraits_AttribState.wrapped[1])
Events.EveryOneMinute.Remove(mdd)
assert(#H.handlers.EveryOneMinute == 1, "remove finds the wrapper")
Events.EveryOneMinute.Add(mdd)

-- 2. off by default: handlers still run, nothing recorded
H.fire("OnPlayerUpdate")
assert(st.unhappy == 9, "handler ran while off")
assert(DanTraits_AttribReport(player).enabled == false and DanTraits_AttribReport(player).windows == nil)

-- 3. on: each handler's change goes to its file, the rest is left over
DanTraits_AttribSet(true)
st.unhappy = 10
DanTraits_AttribReport(player)         -- opens this minute's bucket (in game, every tick does)
H.fire("EveryOneMinute")                -- other +100 (unattributed), MDD +5
H.fire("OnPlayerUpdate")                 -- Vitality -1, stress +0.05
st.unhappy = st.unhappy + 3            -- the game, between handlers
local r = DanTraits_AttribReport(player)
assert(r.enabled and #r.windows == 3, "10 min, 60 min, since reset")
local w = r.windows[1]
local function near(a, b) return math.abs(a - b) < 1e-6 end
assert(near(w.sources.MDD.unhappiness, 5) and near(w.sources.Vitality.unhappiness, -1), "credited per file")
assert(near(w.sources.Vitality.stress, 0.05) and w.sources.MDD.stress == nil, "only what moved")
assert(near(w.total.unhappiness, 107), "net change " .. tostring(w.total.unhappiness))
assert(w.sources.Other == nil, "other mods are not named")

-- 4. nesting: an outer handler only keeps what its children did not do
local function tenMin() st.stress = st.stress + 0.2; DanTraits_Track("Dependent", function() st.stress = st.stress + 0.3 end) end
fileOf[tenMin] = "shared/DanTraits.lua"
Events.EveryTenMinutes.Add(tenMin)
H.fire("EveryTenMinutes")
w = DanTraits_AttribReport(player).windows[1]
assert(near(w.sources.core.stress, 0.2) and near(w.sources.Dependent.stress, 0.3), "nested split")

-- 5. errors still reach the caller, and the depth unwinds
local function broken() st.unhappy = st.unhappy + 1; error("boom") end
fileOf[broken] = "DanTraits_Broken.lua"
Events.EveryOneMinute.Add(broken)
local ok, err = pcall(H.handlers.EveryOneMinute[#H.handlers.EveryOneMinute])
assert(not ok and tostring(err):find("boom"), "error rethrown")
w = DanTraits_AttribReport(player).windows[1]
assert(near(w.sources.Broken.unhappiness, 1), "change before the error still credited")

-- 6. windows: an hour later the 10-minute window has forgotten, since-reset has not
H.hours = H.hours + 1
H.fire("OnPlayerUpdate")
r = DanTraits_AttribReport(player)
assert(r.windows[1].sources.MDD == nil and near(r.windows[1].sources.Vitality.unhappiness, -1), "10 min window moved on")
assert(near(r.windows[3].sources.MDD.unhappiness, 5), "since reset keeps it")
DanTraits_AttribReset()
r = DanTraits_AttribReport(player)
assert(r.windows[3].sources.MDD == nil, "reset clears")

-- 7. moodles
local m = DanTraits_ActiveMoodles(player)
assert(m.unhappy == 2 and m.wet == 1 and m.bored == nil, "active moodles")
H.pass()
