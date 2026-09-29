-- Offline test for the drivers in DanTraits.lua (DanTraits_Every): registrations
-- run in order (order, then label, then registration), one system's error
-- never stops the next, a dead player runs nothing, the frame driver skips
-- non-local players, and each system runs under its own attribution label.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("DanTraits")

-- exactly one handler per cadence, owned by core
assert(#H.handlers.EveryOneMinute == 1 and #H.handlers.EveryTenMinutes == 1 and #H.handlers.OnPlayerUpdate == 1, "one handler each")

-- attribution: record the label every system runs under (Attrib is not loaded here)
local labels = {}
DanTraits_Track = function(label, fn, ...) labels[#labels + 1] = label; return fn(...) end

local p = H.player()
H.current = p
local log = {}
local function rec(name) return function(player, d) log[#log + 1] = name; assert(player == p and d == p._md.DanTraits, "player and data") end end
local function ran() local s = table.concat(log, ","); log = {}; return s end

-- 1. order first, then label, then registration order; default order is 100
assert(DanTraits_Every("minute", "Vitality", rec("vit"), 90))
assert(DanTraits_Every("minute", "Sleep", rec("sleep"), 10))
assert(DanTraits_Every("minute", "Zeta", rec("zeta"), 40))
assert(DanTraits_Every("minute", "Alpha", rec("alpha"), 40))
assert(DanTraits_Every("minute", "Late", rec("late")))
assert(DanTraits_Every("minute", "Alpha", rec("alpha2"), 40))   -- same label and order: after the first
assert(DanTraits_Every("minute", "Blood", rec("blood"), 20))
H.minute()
assert(ran() == "sleep,blood,alpha,alpha2,zeta,vit,late", "minute order")
-- the stat delta pipeline (order 0) is registered by core and runs first
assert(table.concat(labels, ",") == "Delta:catchCold,Delta:foodSicknessRise,Sleep,Blood,Alpha,Alpha,Zeta,Vitality,Late", "run under own labels: " .. table.concat(labels, ","))

-- 2. the cadences are separate lists
DanTraits_Every("ten", "MDD", rec("mdd"), 40)
DanTraits_Every("ten", "Dependent", rec("dep"), 10)
DanTraits_Every("ten", "Hallucinations", rec("hall"), 90)
DanTraits_Every("frame", "Vitality", rec("fvit"), 90)
DanTraits_Every("frame", "Blood", rec("fblood"), 20)
H.ten()
assert(ran() == "dep,mdd,hall", "ten order")
H.frame(p)
assert(ran() == "fblood,fvit", "frame order")
H.expectEvery("minute", "Sleep"); H.expectEvery("ten", "MDD"); H.expectEvery("frame", "Blood")
assert(not pcall(H.expectEvery, "frame", "Sleep"), "expectEvery notices a missing system")

-- 3. a system that throws does not stop the next, and keeps being called
local lines = {}
local realPrint = print
print = function(...) lines[#lines + 1] = table.concat({ ... }, " ") end
DanTraits_Every("minute", "Broken", function() log[#log + 1] = "broken"; error("boom") end, 30)
H.minute()
assert(ran() == "sleep,blood,broken,alpha,alpha2,zeta,vit,late", "a throwing system does not stop the rest")
H.minute()
print = realPrint
assert(ran() == "sleep,blood,broken,alpha,alpha2,zeta,vit,late", "and is still called next minute")
assert(#lines == 1 and lines[1]:find("Broken") and lines[1]:find("boom"), "the error is logged once: " .. table.concat(lines, "|"))

-- 4. a dead player runs nothing, on every cadence
local dead = H.player()
dead.isDead = function() return true end
H.current = dead
H.minute(); H.ten(); H.frame(dead)
assert(ran() == "", "dead player: nothing ran")
H.current = nil
H.minute(); H.ten()
assert(ran() == "", "no player: nothing ran")

-- 5. the frame driver skips a player who is not local, or none at all
H.current = p
local remote = H.player()
remote.isLocalPlayer = function() return false end
H.frame(remote)
assert(ran() == "", "non-local player skipped")
H.frame(nil)
assert(ran() == "", "no player skipped")
H.frame(p)
assert(ran() == "fblood,fvit", "the local player runs")

-- 6. bad registrations are refused, not stored
assert(DanTraits_Every("hourly", "X", rec("x")) == false, "unknown cadence")
assert(DanTraits_Every("minute", "X", nil) == false, "no function")
assert(#DanTraits_Drivers.minute == 10, "refused ones were not added")

-- 7. without Attrib (no DanTraits_Track) the systems still run
DanTraits_Track = nil
H.minute()
assert(ran() == "sleep,blood,broken,alpha,alpha2,zeta,vit,late", "runs without Track")

H.pass()
