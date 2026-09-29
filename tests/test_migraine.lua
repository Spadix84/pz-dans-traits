-- Offline test for DanTraits_Migraine.lua: the chance curve, the aura, the
-- attack's symptoms, painkillers, light and sleep, and the refractory day.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local debt, hangover = 0, 0
function DanTraits_SleepDebt() return debt end
function DanTraits_HangoverStrength() return hangover end

H.load("Migraine")
H.expectEvery("minute", "Migraine")
H.expectEvery("ten", "Migraine")

local newPlayer = H.factory({ traits = { "migraine" } })
local halo, near = H.halo, H.near
local minute, ten = H.minute, H.ten
local function M(p) return p._md.DanTraits end

-- 1. the chance: 0.3% calm; sleep debt, thirst, stress, hangover and bright daylight outdoors add
local p = newPlayer(); H.current = p
near(DanTraits_MigraineChance(p), 0.3, 1e-9, "base")
debt = 1; near(DanTraits_MigraineChance(p), 2.8, 1e-9, "full sleep debt +2.5"); debt = 0
p._st.thirst = 0.65; near(DanTraits_MigraineChance(p), 1.3, 1e-9, "half thirst past 30% +1"); p._st.thirst = 0
p._st.stress = 1; near(DanTraits_MigraineChance(p), 2.3, 1e-9, "full stress +2"); p._st.stress = 0
hangover = 0.5; near(DanTraits_MigraineChance(p), 1.3, 1e-9, "half a hangover +1"); hangover = 0
p._outside = true; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "outside at night: nothing")
H.climate.night = 0; near(DanTraits_MigraineChance(p), 1.8, 1e-9, "bright day outdoors +1.5")
H.climate.cloud = 0.8; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "overcast: no glare"); H.climate.cloud = 0
H.climate.rain = 0.5; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "rain: no glare"); H.climate.rain = 0
p._outside = false; H.climate.night = 1

-- 1b. a fever adds 2.0 at full fever (plan 10), guarded on the getter existing
DanTraits_InfectionFever = function() return 0.5 end
near(DanTraits_MigraineChance(p), 0.3 + 1.0, 1e-9, "half a fever +1")
DanTraits_InfectionFever = function() return 1 end
near(DanTraits_MigraineChance(p), 0.3 + 2.0, 1e-9, "full fever +2")
DanTraits_InfectionFever = nil
near(DanTraits_MigraineChance(p), 0.3, 1e-9, "no Infection loaded: nothing")

-- 2. no roll inside the 24 h refractory window from creation; then a roll that misses, then one that hits: aura first
local q = newPlayer(); H.current = q
q._md.DanTraits = { migSinceEnd = 0 }
H.rng = {}; for _ = 1, 6 * 24 do ten() end
assert(not M(q).migAuraLeft and not M(q).migActive, "no roll while refractory (a 0 roll would have hit)")
H.rng = { 9999 }; ten(); assert(not M(q).migAuraLeft, "roll above the chance: nothing")
H.rng = { 0, 50 }; ten()
assert(M(q).migAuraLeft and not M(q).migActive, "aura started")
near(M(q).migSeverity, 1.0, 1e-9, "severity 0.5 + 0.50")
assert(halo[#halo] == "UI_DanTraits_MigraineAura", "aura notice")
ten(); assert(M(q).migAuraLeft, "no second roll during an aura")

-- 3. twenty minutes later the attack: 3 + 3 x 1 = 6 hours; pain, nausea, mood floors ramp; stress creeps
for _ = 1, 20 do minute() end
assert(M(q).migActive and halo[#halo] == "UI_DanTraits_MigraineStart", "attack started")
near(M(q).migHoursLeft, 6, 1e-9, "six hours")
for _ = 1, 40 do minute() end
near(q._st.pain, 40, 1.0, "pain ramping toward 60 at 1 a minute (40 minutes in)")
near(q._st.foodsick, 30, 1.0, "nausea floor 30"); near(q._st.unhappy, 15, 1.0, "mood floor 15")
assert(q._st.stress > 0, "stress creeps")
near(M(q).migHoursLeft, 6 - 40 / 60, 1e-9, "clock at full rate")

-- 4. daylight outdoors: half-speed recovery and more pain; painkillers lower the floor and, once, cut the time by 40%
q._outside = true; H.climate.night = 0
local before = M(q).migHoursLeft
q._st.pain = 0; for _ = 1, 10 do minute() end
near(M(q).migHoursLeft, before - 5 / 60, 1e-9, "half rate in the glare")
assert(q._st.pain == 10, "pain climbing toward 75 (60 + 15 glare)")
q._outside = false; H.climate.night = 1
before = M(q).migHoursLeft
q._painFx = 1; q._st.pain = 0; minute()
near(M(q).migHoursLeft, before * 0.6 - 1 / 60, 1e-9, "painkillers: remaining time x 0.6")
assert(q._st.pain == 1, "the painkiller timer alone does not stop the floor (it ramps 1 a minute)")
q._pr = 30; q._st.pain = 0; for _ = 1, 45 do minute() end
assert(q._st.pain == 30, "a pain reduction of 30 lowers the floor 60 to 30, not to 0: " .. q._st.pain)
q._pr = 70; q._st.pain = 0; minute(); assert(q._st.pain == 0, "a reduction above the floor does nothing"); q._pr = 0
before = M(q).migHoursLeft; minute(); near(M(q).migHoursLeft, before - 1 / 60, 1e-9, "the cut happens once")
q._painFx = 0

-- 5. sleeping it off runs the clock at double speed; it ends, refractory starts, moodle cleared
q._asleep = true; q._st.pain = 0
before = M(q).migHoursLeft; for _ = 1, 30 do minute() end
near(M(q).migHoursLeft, before - 1, 1e-9, "double rate asleep"); assert(q._st.pain == 0, "no symptoms applied while asleep")
M(q).migHoursLeft = 1 / 60; q._asleep = false; minute()
assert(not M(q).migActive and M(q).migSinceEnd == 0 and halo[#halo] == "+UI_DanTraits_MigraineEnd", "over")
H.rng = { 0, 0 }; ten(); assert(not M(q).migAuraLeft, "refractory again")

-- 6. no trait: nothing
local n = newPlayer({ traits = {} }); H.current = n
H.rng = { 0, 0 }; n._md.DanTraits = { migSinceEnd = 99 }; ten(); minute()
assert(not M(n).migAuraLeft and not M(n).migActive, "no trait: untouched")

H.pass()
