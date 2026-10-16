-- Offline test for a night slept with Sleep and Vitality loaded together, and the
-- other files with a say in it (Age, AgeTraits' Settled, Dependent, Hangover, Home,
-- Smoker), in the order the game loads them. Vitality scores the night and runs the
-- nightGap, nightWakes and nightQuality hooks; Sleep hands over how dark it was,
-- and takes a Restless Sleeper's free wake off before Age scales the rest (order
-- 10 against Age's default 100: review 2026-10-16 A2.19, a 50s Restless Sleeper
-- paid for the free wake); the five night hooks compose in load order, each on
-- what the one before left. No single-file test sees any of this: test_sleep.lua
-- stands in for Age and runs the hooks by hand, test_vitality.lua loads no Sleep.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }
H.roll = 9999   -- no chance roll succeeds: the light wakes nobody, no nightmares
-- what AgeTraits and Home touch at load
CharacterProfessionDefinition = { getCharacterProfessionDefinition = function() return { getXpBoosts = function() return nil end } end }
function transformIntoKahluaTable(t) return t end
ISReadABook = { getDuration = function() return 400 end, isValid = function() return true end }
MoodleType.HEAVY_LOAD = "heavy"
ClimbOverFenceState = { instance = function() return {} end }
ClimbThroughWindowState = { instance = function() return {} end }
BodyPartType.Torso_Lower = "Torso_Lower"
BodyPartType.getDisplayName = function(kind) return kind end
local woken = {}
function getSleepingEvent() return { wakeUp = function(_, p) woken[#woken + 1] = p; p._asleep = false end } end

H.load("Age", "AgeTraits", "Dependent", "Hangover", "Home", "Sleep", "Smoker", "Vitality")
H.expectEvery("minute", "Sleep")
H.expectEvery("minute", "Vitality")
assert(#DanTraits_Hooks.nightQuality == 7, "Settled, Dependent, Hangover, Home, Sleep (dark, fever), Smoker: got " .. #DanTraits_Hooks.nightQuality)
assert(#DanTraits_Hooks.nightWakes == 2 and #DanTraits_Hooks.nightGap == 1, "Sleep and Age on the wakes, Sleep on the gap")

local minute, near = H.minute, H.near
local function V(p) return p._md.DanTraits end
-- a sleep: into bed at `from` game hours this tired, up at `to` that tired, the room
-- this light (0.1 is dark, 0.9 lit); the minute in bed lets Sleep read the room
local function sleep(p, from, to, bedFatigue, wokeFatigue, light)
  p._light = light
  p._st.fatigue = bedFatigue; p._asleep = true; p._hours = from; minute()
  p._hours = to; p._asleep = false; p._st.fatigue = wokeFatigue
end
local function up(p, minutes) for _ = 1, minutes do minute() end end

-- 1. a plain sleeper's night: six hours of seven, up a little tired, scored an hour
--    after rising (the nightGap); Sleep's darkness lands on it (+0.1 dark, -0.15 lit)
local dark = H.player({ hours = 100 }); H.current = dark
sleep(dark, 100, 106, 0.05, 0.2, 0.1)
up(dark, 59)
assert(V(dark).vitLastSleepQuality == nil, "59 minutes up: not scored yet")
up(dark, 1)
local base = (6 / 7) * 0.5 + (1 - 0.2) * 0.5   -- hours and rest, half each
near(V(dark).vitLastSleepQuality, base + 0.1, 1e-9, "dark room: Sleep's +0.1 on Vitality's score")
near(V(dark).vitSleep, 0.5 + (base + 0.1 - 0.5) * 0.35, 1e-9, "the sleep score moved by a night's share")
assert(V(dark).slNightMin == 0 and V(dark).slNightDark == 0, "Sleep's tally was consumed by the scoring")
assert(#woken == 0, "nothing woke anyone")
local lit = H.player({ hours = 100 }); H.current = lit
sleep(lit, 100, 106, 0.05, 0.2, 0.9)
up(lit, 60)
near(V(lit).vitLastSleepQuality, base - 0.15, 1e-9, "lit room: -0.15")

-- 2. a 50s Restless Sleeper in three sittings: the two wakes between them are counted
--    (3), Sleep takes the free one off first (2), then Age scales what is over the
--    morning wake (1 + 1 x 1.3 = 2.3): 1.3 wakes at 0.05 each come off. Age first
--    would have made it 3.6 - 1 = 2.6 wakes (1.6 x 0.05 off)
local rs = H.player({ hours = 100, traits = { "age50s" }, vanilla = { "base:insomniac" } }); H.current = rs
sleep(rs, 100, 102, 0.05, 0.3, 0.1); up(rs, 20)
sleep(rs, 102 + 20 / 60, 104, 0.3, 0.25, 0.1); up(rs, 20)
sleep(rs, 104 + 20 / 60, 106 + 40 / 60, 0.25, 0.2, 0.1)
up(rs, 60)
assert(V(rs).vitLastSleepQuality == nil, "a Restless Sleeper's night is scored after the longer gap (180 min)")
up(rs, 120)
near(V(rs).vitLastSleepHours, 6, 1e-9, "the three sittings are one six-hour night")
assert(V(rs).vitLastSleepWakes == 3, "three wakes counted, got " .. tostring(V(rs).vitLastSleepWakes))
near(DanTraits_RunHooks("nightWakes", 3, rs), 2.3, 1e-9, "the chain: Sleep's free wake, then Age's x1.3 on the rest")
near(V(rs).vitLastSleepQuality, base - 1.3 * 0.05 + 0.1, 1e-9, "the night: 1.3 wakes' cost, Sleep's dark bonus")
local plainRs = H.player({ hours = 100, vanilla = { "base:insomniac" } })
near(DanTraits_RunHooks("nightWakes", 3, plainRs), 2, 1e-9, "30s: the free wake only")
local fifties = H.player({ hours = 100, traits = { "age50s" } })
near(DanTraits_RunHooks("nightWakes", 3, fifties), 3.6, 1e-9, "50s without the trait: both extra wakes scaled")
near(DanTraits_RunHooks("nightWakes", 1, fifties), 1, 1e-9, "an unbroken night costs the 50s nothing")

-- 3. the five night hooks together, in load order, each on what the one before
--    left: Settled's first night in a strange bed (-0.2), alcohol withdrawal at
--    half (x 0.8), a half hangover (x 0.85), a night at a full-strength home
--    (+0.05), a dark room (+0.1), nicotine withdrawal at half (x 0.9)
local all = H.player({ hours = 100, traits = { "age50s", "settled", "dependent" }, vanilla = { "base:smoker" } }); H.current = all
local d = DanTraits_Data(all)
d.stInHouse, d.stNewBed = false, false
d.alcWithdrawing, d.alcW = true, 0.5
d.hoActive, d.hoSeverity = true, 0.5
d.hmHome, d.hmNights, d.hmNightLoc = { x = 10, y = 10, z = 0 }, 7, { x = 10, y = 10, z = 0 }
d.slNightMin, d.slNightDark = 10, 10
d.nicWithdraw = 0.5
local q = DanTraits_RunHooks("nightQuality", 0.8, all, d)
near(q, (((0.8 - 0.2) * 0.8 * 0.85) + 0.05 + 0.1) * 0.9, 1e-9, "the chain in load order")
-- the same states one at a time, so a change in any one file shows up by name
local function alone(set)
  local p = H.player({ hours = 100, traits = { "age50s", "settled", "dependent" }, vanilla = { "base:smoker" } })
  local pd = DanTraits_Data(p)
  pd.stInHouse, pd.stNewBed = true, false   -- Settled's usual bed unless the case says otherwise
  set(pd)
  return DanTraits_RunHooks("nightQuality", 0.8, p, pd)
end
near(alone(function(pd) pd.stInHouse = false end), 0.6, 1e-9, "Settled off a house bed: -0.2")
near(alone(function(pd) pd.stInHouse, pd.stNewBed = true, true end), 0.6, 1e-9, "Settled's first night in a new bed: -0.2")
near(alone(function(pd) pd.stInHouse, pd.stNewBed = true, false end), 0.8, 1e-9, "Settled in the usual bed: nothing")
near(alone(function(pd) pd.alcWithdrawing, pd.alcW = true, 0.5 end), 0.8 * 0.8, 1e-9, "Dependent: x (1 - 0.4 w)")
near(alone(function(pd) pd.hoActive, pd.hoSeverity = true, 0.5 end), 0.8 * 0.85, 1e-9, "Hangover: x (1 - 0.3 severity)")
near(alone(function(pd) pd.hmHome, pd.hmNights, pd.hmNightLoc = { x = 10, y = 10, z = 0 }, 7, { x = 10, y = 10, z = 0 } end), 0.85, 1e-9, "Home: +0.05 x strength")
near(alone(function(pd) pd.slNightMin, pd.slNightDark = 10, 10 end), 0.9, 1e-9, "Sleep: a dark night +0.1")
near(alone(function(pd) pd.nicWithdraw = 0.5 end), 0.8 * 0.9, 1e-9, "Smoker: x (1 - 0.2 w)")
near(alone(function() end), 0.8, 1e-9, "nothing staged: untouched")

H.pass()
