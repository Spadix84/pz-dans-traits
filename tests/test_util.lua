-- Offline test for DanTraits_Util.lua: the shared one-liners. FloorUp never
-- overshoots and respects the stat's maximum, StatAdd clamps both ways, Roll
-- has hard edges at 0 and 1, RollPercent goes through ZombRand, BadMoodle
-- maps 0 to 0.5 and 1 to 0 and hands the right thresholds to the framework,
-- the pain-floor rule (floor minus painReduction, the largest source wins, applied
-- once a minute), and the part, asleep and sandbox helpers fail soft.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Util", "DanTraits")   -- core too: the pain-floor applier is a system it registers
local near = H.near

-- Clamp01 / StatMax
assert(DanTraits_Clamp01(-3) == 0 and DanTraits_Clamp01(0.4) == 0.4 and DanTraits_Clamp01(7) == 1, "clamp01")
assert(DanTraits_StatMax(CharacterStat.PAIN) == 100 and DanTraits_StatMax(CharacterStat.STRESS) == 1, "stat max")
assert(DanTraits_StatMax(nil) == 1 and DanTraits_StatMax({}) == 1, "unknown stat: 1")
assert(DanTraits_StatMax({ getMaximumValue = function() return 0 end }) == 1, "zero max: 1")

-- FloorUp: raises by at most the ramp, never above the floor, never above the max
local p = H.player(); local stats = p:getStats()
local PAIN, STRESS = CharacterStat.PAIN, CharacterStat.STRESS
p._st.pain = 10
DanTraits_FloorUp(stats, PAIN, 40, 5)
assert(p._st.pain == 15, "ramps by 5")
DanTraits_FloorUp(stats, PAIN, 40, 100)
assert(p._st.pain == 40, "never above the floor")
DanTraits_FloorUp(stats, PAIN, 40, 5)
assert(p._st.pain == 40, "at the floor: unchanged")
p._st.pain = 70
DanTraits_FloorUp(stats, PAIN, 40, 5)
assert(p._st.pain == 70, "above the floor: never lowered")
p._st.stress = 0.9
DanTraits_FloorUp(stats, STRESS, 250, 500)
assert(p._st.stress == 1, "never above the stat's maximum")

-- PainFloor: the largest source wins, once a minute, on the head; the game takes the pain reduction off (H.pain models it)
do
  local q = H.player(); H.current = q
  local d = q._md.DanTraits or {}; q._md.DanTraits = d
  H.setPain(q, 0)
  DanTraits_PainFloor(q, d, "a", 60, 5); DanTraits_PainFloor(q, d, "b", 40, 20)
  assert(H.pain(q) == 0, "registering does not touch the stat")
  H.minute()
  assert(H.pain(q) == 5, "the larger floor (60) applies with its own ramp (5), not the smaller one's")
  assert(d.painFloors == nil and d.painHurting.a == 60 and d.painHurting.b == 40, "cleared, and kept as the who-is-hurting list")
  H.minute()
  assert(H.pain(q) == 5, "nothing registered: nothing applied")
  q._pr = 30
  DanTraits_PainFloor(q, d, "a", 60, 100); DanTraits_PainFloor(q, d, "b", 40, 100)
  H.minute()
  assert(H.pain(q) == 30, "reduction 30 lowers 60 to 30, not to 0")
  assert(d.painHurting.a == 60 and d.painHurting.b == 40, "the list holds the floors as registered")
  H.setPain(q, 0)
  DanTraits_PainFloor(q, d, "c", 15, 100)
  H.minute()
  assert(H.pain(q) == 0, "a floor of 15 with reduction 30 does nothing")
  q._pr = 0; H.setPain(q, 50)
  DanTraits_PainFloor(q, d, "a", 20, 100); H.minute()
  assert(H.pain(q) == 50, "never lowers pain already above the floor")
  q._pr = 0; H.setPain(q, 0)
  DanTraits_PainFloor(q, d, "a", 20, 100); DanTraits_PainFloor(q, d, "a", 35, 100); H.minute()
  assert(H.pain(q) == 35, "a source registering twice keeps its latest floor")
  DanTraits_PainFloor(nil, nil, "a", 10, 1); DanTraits_PainFloor(q, d, nil, 10, 1)
  -- a held floor outlives its minute (a ten-minute system passes 11), then drops
  d.painFloors = nil
  DanTraits_PainFloor(q, d, "w", 20, 1, 3)
  H.minute(); H.minute()
  assert(d.painFloors and d.painFloors.w and d.painFloors.w.hold == 1, "held for its minutes")
  H.minute()
  assert(d.painFloors == nil, "then dropped")
  -- a burst adds on top of the head and fades with it
  H.setPain(q, 0); DanTraits_PainBurst(q, 25)
  assert(H.pain(q) == 25, "a burst of 25")
  H.current = nil
end

-- StatAdd: clamps to 0..max, quietly
p._st.stress = 0.9
DanTraits_StatAdd(stats, STRESS, 0.5)
assert(p._st.stress == 1, "capped at max")
DanTraits_StatAdd(stats, STRESS, -3)
assert(p._st.stress == 0, "floored at 0")
DanTraits_StatAdd(stats, PAIN, 30)
assert(p._st.pain == 100, "0..100 stat capped at 100")
DanTraits_StatAdd(stats, nil, 1)
DanTraits_StatAdd(nil, STRESS, 1)

-- Roll: 0 never, 1 always, else the float compared with the chance
local calls = 0
local realFloat = ZombRandFloat
function ZombRandFloat(lo, hi) calls = calls + 1; return realFloat(lo, hi) end
H.rollf = 0.5
assert(DanTraits_Roll(0) == false and DanTraits_Roll(-1) == false, "0 never")
assert(DanTraits_Roll(1) == true and DanTraits_Roll(2) == true, "1 always")
assert(calls == 0, "the edges do not spend a random number")
assert(DanTraits_Roll(0.6) == true and DanTraits_Roll(0.4) == false, "compares")
assert(calls == 2, "one random number per real roll")
ZombRandFloat = nil
math.randomseed(1)
local _ = DanTraits_Roll(0.5)                       -- falls back to math.random without error
local r = DanTraits_RandRange(2, 4)
assert(r >= 2 and r <= 4, "fallback range")
ZombRandFloat = realFloat
near(DanTraits_RandRange(2, 4), 3, 1e-9, "stub midpoint")

-- RollPercent: ZombRand(1000000) < pct x 10000
H.rng = { 49999, 50000 }
assert(DanTraits_RollPercent(5) == true, "49999 < 50000")
assert(DanTraits_RollPercent(5) == false, "50000 is not")
H.rng = { 0 }
assert(DanTraits_RollPercent(0) == false, "0 percent never fires, even on a 0")

-- parts
local got
local body = { getBodyPart = function(_, t) got = t; return { type = t } end }
p.getBodyDamage = function() return body end
assert(DanTraits_PartNames.forearm_l == "ForeArm_L" and DanTraits_PartNames.belly == "Torso_Lower", "names")
assert(DanTraits_PartOf(p, "Hand_R").type == "Hand_R" and got == "Hand_R", "case-insensitive lookup")
assert(DanTraits_PartOf(p, "elbow") == nil and DanTraits_PartOf(p, nil) == nil, "unknown name: nil")
local part = { bleeding = function() return true end, age = function() return 7 end, odd = function() return "yes" end,
               boom = function() error("no") end }
assert(DanTraits_PartIs(part, "bleeding") == true and DanTraits_PartIs(part, "odd") == false, "is: only true is true")
assert(DanTraits_PartIs(part, "boom") == false and DanTraits_PartIs(part, "missing") == false, "is fails soft")
assert(DanTraits_PartNum(part, "age") == 7 and DanTraits_PartNum(part, "boom") == 0, "num")
assert(DanTraits_PartNum(part, "odd") == 0 and DanTraits_PartNum(part, "missing") == 0, "num of junk is 0")

-- asleep
assert(DanTraits_Asleep(H.player({ asleep = true })) == true and DanTraits_Asleep(H.player()) == false, "asleep")
assert(DanTraits_Asleep({}) == false and DanTraits_Asleep(nil) == false, "asleep fails soft")

-- sandbox
SandboxVars = nil
assert(DanTraits_SandboxOn("BloodEnabled") == true, "no sandbox table: on")
SandboxVars = { DanTraits = {} }
assert(DanTraits_SandboxOn("BloodEnabled") == true, "option absent: on")
SandboxVars = { DanTraits = { BloodEnabled = false, InfectionEnabled = true } }
assert(DanTraits_SandboxOn("BloodEnabled") == false and DanTraits_SandboxOn("InfectionEnabled") == true, "option read")
SandboxVars = nil

-- BadMoodle
local seen
local function moodleFor(name)
  seen = { name = name }
  return { setThresholds = function(_, a, b, c, d) seen.th = { a, b, c, d } end,
           setValue = function(_, v) seen.value = v end }
end
MF = { getMoodle = function(name, num) seen = nil; local m = moodleFor(name); seen.num = num; return m end }
p.getPlayerNum = function() return 0 end
DanTraits_BadMoodle(p, "Hangover", 0, { 0.25, 0.5, 0.75 })
assert(seen.name == "Hangover" and seen.num == 0, "asks for the named moodle of this player")
assert(seen.value == 0.5, "0 is no moodle: 0.5")
assert(seen.th[1] == nil, "3 tiers: the first threshold is left unset")
DanTraits_BadMoodle(p, "Hangover", 1, { 0.25, 0.5, 0.75 })
assert(seen.value == 0, "1 is the worst: 0")
near(seen.th[2], 0.125, 1e-12, "3 tiers: the worst tier is the lowest threshold"); near(seen.th[3], 0.25, 1e-12); near(seen.th[4], 0.375, 1e-12)
DanTraits_BadMoodle(p, "BloodLoss", 0.5, { 0.3, 0.6, 0.8, 0.9 })
near(seen.value, 0.25, 1e-12, "half way: 0.25")
near(seen.th[1], 0.05, 1e-12, "4 tiers: all four thresholds"); near(seen.th[2], 0.1, 1e-12); near(seen.th[3], 0.2, 1e-12); near(seen.th[4], 0.35, 1e-12)
DanTraits_BadMoodle(p, "Infection", 0.2, { thresholds = { 0.05, 0.15, 0.3, 0.45 } })
near(seen.value, 0.4, 1e-12, "hand-set thresholds, same value mapping")
assert(seen.th[1] == 0.05 and seen.th[2] == 0.15 and seen.th[3] == 0.3 and seen.th[4] == 0.45, "hand-set thresholds pass through")
-- no framework, or one without the moodle: nothing happens
seen = nil; MF = nil
DanTraits_BadMoodle(p, "Hangover", 1, { 0.25, 0.5, 0.75 })
MF = { getMoodle = function() return nil end }
DanTraits_BadMoodle(p, "Hangover", 1, { 0.25, 0.5, 0.75 })
MF = { getMoodle = function() error("boom") end }
DanTraits_BadMoodle(p, "Hangover", 1, { 0.25, 0.5, 0.75 })
assert(seen == nil, "nothing was set")
MF = nil

-- Cough: the game's own triggerCough at radius 35 or unspecified, voice sound plus addSound for a quieter
-- one; one gap (3 game minutes) across callers unless forced; who and how many are recorded
do
  local cp = H.player(); H.current = cp
  H.sounds = {}; local base = cp._coughs
  assert(DanTraits_Cough(cp, 35, "smoker") and cp._coughs == base + 1 and #H.sounds == 0, "radius 35: the game's own cough, no extra sound")
  assert(not DanTraits_Cough(cp, 35, "asthma") and cp._coughs == base + 1, "inside the gap: refused")
  assert(DanTraits_Cough(cp, 35, "asthma", true) and cp._coughs == base + 2, "forced: goes through")
  H.hours = H.hours + 2 / 60
  assert(not DanTraits_Cough(cp, 6, "asthma"), "two minutes on: still inside the gap")
  H.hours = H.hours + 1 / 60 + 1e-6
  assert(DanTraits_Cough(cp, 6, "asthma") and H.sounds[#H.sounds] == 6, "three minutes on: a quiet cough is a sound at its radius")
  local dd = cp._md.DanTraits
  assert(dd.coughs == 3 and dd.lastCoughWhy == "asthma", "records the count and the last reason")
  local bare = H.player(); bare.triggerCough = nil; H.current = bare; H.sounds = {}
  assert(DanTraits_Cough(bare, 35, "smoker") and H.sounds[#H.sounds] == 35, "no triggerCough: falls back to a sound at the radius")
end

H.pass()
