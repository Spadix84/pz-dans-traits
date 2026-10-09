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

-- a dim room (between the dark and lit readings) unless a test says otherwise
local newPlayer = H.factory({ traits = { "migraine" } }, function(p) p._light = 0.425 end)
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

-- 1b. a fever adds 2.0 at full fever, guarded on the getter existing
DanTraits_InfectionFever = function() return 0.5 end
near(DanTraits_MigraineChance(p), 0.3 + 1.0, 1e-9, "half a fever +1")
DanTraits_InfectionFever = function() return 1 end
near(DanTraits_MigraineChance(p), 0.3 + 2.0, 1e-9, "full fever +2")
DanTraits_InfectionFever = nil
near(DanTraits_MigraineChance(p), 0.3, 1e-9, "no Infection loaded: nothing")

-- 1c. caffeine withdrawal adds 2.0 at full withdrawal, guarded on the getter existing
local withdrawal = 0
DanTraits_CaffeineWithdrawalOf = function() return withdrawal end
near(DanTraits_MigraineChance(p), 0.3, 1e-9, "no withdrawal: nothing")
withdrawal = 1; near(DanTraits_MigraineChance(p), 0.3 + 2.0, 1e-9, "full caffeine withdrawal +2")
withdrawal = 0.5; near(DanTraits_MigraineChance(p), 0.3 + 1.0, 1e-9, "half +1")
DanTraits_CaffeineWithdrawalOf = nil
near(DanTraits_MigraineChance(p), 0.3, 1e-9, "no Caffeine loaded: nothing")

-- 1d. heat: the hotter of the air (27 C to full at 35) and the body (37.5 to full at 38.5), +2 at full
H.climate.temp = 31; near(DanTraits_MigraineChance(p), 0.3 + 1.0, 1e-9, "31 C: half heat +1")
H.climate.temp = 40; near(DanTraits_MigraineChance(p), 0.3 + 2.0, 1e-9, "40 C: full heat +2")
H.climate.temp = 20; p._st.temperature = 38.0; near(DanTraits_MigraineChance(p), 0.3 + 1.0, 1e-9, "body at 38: half heat +1")
H.climate.temp = 33; near(DanTraits_MigraineChance(p), 0.3 + 1.5, 1e-9, "the hotter of the two counts, not both")
H.climate.temp = 20; p._st.temperature = 37
near(DanTraits_MigraineChance(p), 0.3, 1e-9, "37 C body, 20 C air: nothing")

-- 1e. corpses within three tiles: +0.5 each, counting three at most
H.corpses = 2; near(DanTraits_MigraineChance(p), 0.3 + 1.0, 1e-9, "two corpses +1")
H.corpses = 9; near(DanTraits_MigraineChance(p), 0.3 + 1.5, 1e-9, "a pile counts as three: +1.5")
H.corpses = 0

-- 1f. a storm on the way: forecast to start within twelve hours and not raining yet, +1.5 (it is noon)
H.climate.forecast = { { "storm", 20 } }; near(DanTraits_MigraineChance(p), 0.3 + 1.5, 1e-9, "storm tonight +1.5")
H.climate.forecast = { nil, { "blizzard", 0 } }; near(DanTraits_MigraineChance(p), 0.3 + 1.5, 1e-9, "blizzard at midnight +1.5")
H.climate.forecast = { { "rain", 23 }, { "tropical", 6 } }; near(DanTraits_MigraineChance(p), 0.3 + 1.5, 1e-9, "two in a row count once")
H.climate.forecast = { nil, { "storm", 6 } }; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "eighteen hours off: not yet")
H.climate.forecast = { { "storm", 9 } }; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "started this morning: arrived")
H.climate.forecast = { { "storm", 0, true } }; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "carried over from yesterday: arrived")
H.climate.forecast = { { "storm", 20 } }; H.timeOfDay = 8; near(DanTraits_MigraineChance(p), 0.3 + 1.5, 1e-9, "at eight, twelve hours ahead: counts")
H.timeOfDay = 7; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "at seven, thirteen hours ahead: not yet")
H.timeOfDay = nil
H.climate.rain = 0.5; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "once the rain has started: nothing")
H.climate.rain = 0; H.climate.forecast = nil
near(DanTraits_MigraineChance(p), 0.3, 1e-9, "clear forecast: nothing")

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
near(H.pain(q), 40, 1.0, "pain ramping toward 60 at 1 a minute (40 minutes in)")
near(q._st.foodsick, 40, 1.0, "nausea ramping toward 50 (40 minutes in)"); near(q._st.unhappy, 15, 1.0, "mood floor 15")
assert(q._st.stress > 0, "stress creeps")
near(M(q).migHoursLeft, 6 - 40 / 60, 1e-9, "clock at full rate")

-- 4. daylight outdoors: half-speed recovery and more pain; painkillers lower the floor and, once, cut the time by 40%
q._outside = true; H.climate.night = 0
local before = M(q).migHoursLeft
H.setPain(q, 0); for _ = 1, 10 do minute() end
near(M(q).migHoursLeft, before - 5 / 60, 1e-9, "half rate in the glare")
assert(H.pain(q) == 10, "pain climbing toward 75 (60 + 15 glare)")
assert(M(q).migGlare == 1, "full sun: the moodle at its worst")
q._outside = false; H.climate.night = 1
before = M(q).migHoursLeft
q._painFx = 1; H.setPain(q, 0); minute()
near(M(q).migHoursLeft, before * 0.9 - 1 / 60, 1e-9, "painkillers barely touch it: remaining time x 0.9")
assert(H.pain(q) == 1, "the painkiller timer alone does not stop the floor (it ramps 1 a minute)")
-- the head climbs to the full 60 at 1 a minute and the game takes the 30 off
q._pr = 30; H.setPain(q, 0); for _ = 1, 60 do minute() end
assert(H.pain(q) == 30, "a pain reduction of 30 lowers the floor 60 to 30, not to 0: " .. H.pain(q))
q._pr = 70; H.setPain(q, 0); minute(); assert(H.pain(q) == 0, "a reduction above the floor does nothing"); q._pr = 0
before = M(q).migHoursLeft; minute(); near(M(q).migHoursLeft, before - 1 / 60, 1e-9, "the cut happens once")
q._painFx = 0

-- 4b. awake out of the sun, the room's light: lit adds 10 pain and slows the clock to 0.75, dark speeds it to 1.25
local kept = M(q).migHoursLeft
q._light = 0.8; before = M(q).migHoursLeft
H.setPain(q, 0); for _ = 1, 80 do minute() end
near(M(q).migHoursLeft, before - 80 * 0.75 / 60, 1e-9, "three-quarter rate in a lit room")
assert(H.pain(q) == 70, "lit room: floor 60 + 10: " .. H.pain(q))
q._light = 0.1; before = M(q).migHoursLeft
H.setPain(q, 0); for _ = 1, 80 do minute() end
near(M(q).migHoursLeft, before - 80 * 1.25 / 60, 1e-9, "a quarter faster in the dark")
assert(H.pain(q) == 60, "dark room: the plain floor: " .. H.pain(q))
assert(M(q).migGlare == nil, "dark room: the light adds nothing, no moodle")
q._light = 0.5125; before = M(q).migHoursLeft; minute()
near(M(q).migHoursLeft, before - (1 - 0.25 * 0.5) / 60, 1e-9, "half-lit: halfway")
q._light = 0.425; M(q).migHoursLeft = kept

-- 4c. sunglasses halve the light's extra pain: listed ones, or anything named sunglasses or shades
kept = M(q).migHoursLeft
q._light = 0.8
q._worn = { { type = "Base.Glasses_Sun", name = "Sunglasses" } }
H.setPain(q, 0); for _ = 1, 80 do minute() end
assert(H.pain(q) == 65, "lit room in sunglasses: 60 + 10 x 0.5: " .. H.pain(q))
near(M(q).migGlare, 5 / 15, 1e-9, "the Light Too Bright moodle reads the light's 5 against the sun's 15")
q._worn = { { type = "OtherMod.CoolShades", name = "Cool Shades" } }
H.setPain(q, 0); for _ = 1, 80 do minute() end
assert(H.pain(q) == 65, "another mod's shades count by name: " .. H.pain(q))
q._worn = { { type = "Base.Glasses_Normal", name = "Prescription Glasses" } }
H.setPain(q, 0); for _ = 1, 80 do minute() end
assert(H.pain(q) == 70, "clear glasses do nothing: " .. H.pain(q))
near(M(q).migGlare, 10 / 15, 1e-9, "a lit room: 10 of the sun's 15")
q._worn = {}; q._light = 0.425; M(q).migHoursLeft = kept

-- 4d. the attack blurs: Short Sighted is flipped while it and wearing glasses agree, and put back after
local SS = CharacterTrait.SHORT_SIGHTED
assert(q._traits[SS] and M(q).migBlur == false and q._vision > 0, "no glasses, not short-sighted: flipped on for the blur")
q._glasses = true; minute()
assert(not q._traits[SS] and M(q).migBlur == false, "glasses put on: flipped off, so the two still disagree")
q._glasses = false; minute(); assert(q._traits[SS], "glasses off again: back on")
kept = M(q).migHoursLeft; M(q).migHoursLeft = 1 / 60; minute()
assert(not M(q).migActive and not q._traits[SS] and M(q).migBlur == nil, "attack over: the character's own state is back")
M(q).migActive, M(q).migHoursLeft, M(q).migSinceEnd = true, kept, 0
local ss = newPlayer({ traits = { "migraine" }, vanilla = { SS } }); H.current = ss
ss._md.DanTraits = { migActive = true, migHoursLeft = 3, migSeverity = 0.5, migSinceEnd = 0, migStrong = { "sleep", "thirst", "stress" } }
local before = ss._vision; minute()
assert(ss._traits[SS] and M(ss).migBlur == nil and ss._vision == before, "short-sighted without glasses: blurred already, nothing flipped")
ss._glasses = true; minute()
assert(not ss._traits[SS] and M(ss).migBlur == true, "short-sighted in glasses: flipped off for the attack")
ss._traits["migraine"] = nil; minute()
assert(ss._traits[SS] and M(ss).migBlur == nil, "the Migraines trait gone mid-attack: Short Sighted given back")
H.current = q

-- 5. sleeping it off runs the clock at double speed; it ends, refractory starts, moodle cleared
q._asleep = true; H.setPain(q, 0)
before = M(q).migHoursLeft; for _ = 1, 30 do minute() end
near(M(q).migHoursLeft, before - 1, 1e-9, "double rate asleep"); assert(H.pain(q) == 0, "no symptoms applied while asleep")
M(q).migHoursLeft = 1 / 60; q._asleep = false; minute()
assert(not M(q).migActive and M(q).migSinceEnd == 0 and halo[#halo] == "+UI_DanTraits_MigraineEnd", "over")
H.rng = { 0, 0 }; ten(); assert(not M(q).migAuraLeft, "refractory again")

-- 6. no trait: nothing
local n = newPlayer({ traits = {} }); H.current = n
H.rng = { 0, 0 }; n._md.DanTraits = { migSinceEnd = 99 }; ten(); minute()
assert(not M(n).migAuraLeft and not M(n).migActive, "no trait: untouched")
assert(not M(n).migStrong, "no trait: no triggers drawn")

-- 7. personal triggers: three drawn once (here the 2nd, then the 6th of what is left, then the 1st), x2; the other five x0.5
local t = newPlayer(); H.current = t
t._md.DanTraits = { migSinceEnd = 0 }
H.rng = { 1, 5, 0 }; ten()
local strong = M(t).migStrong
assert(#strong == 3 and strong[1] == "thirst" and strong[2] == "corpses" and strong[3] == "sleep", "drawn: " .. table.concat(strong, ","))
H.rng = { 0, 0, 0 }; ten(); assert(M(t).migStrong == strong, "drawn once")
near(DanTraits_MigraineChance(t), 0.3, 1e-9, "the base is nobody's trigger")
t._st.stress = 1; near(DanTraits_MigraineChance(t), 0.3 + 1.0, 1e-9, "stress is not one of theirs: x0.5")
t._st.stress = 0; H.corpses = 2; near(DanTraits_MigraineChance(t), 0.3 + 2.0, 1e-9, "corpses are: x2")
local _, cause = DanTraits_MigraineChance(t); assert(cause == "corpses", "the cause: the biggest personal share")
H.corpses = 0
DanTraits_InfectionFever = function() return 1 end
near(DanTraits_MigraineChance(t), 0.3 + 2.0, 1e-9, "fever counts the same for everyone")
_, cause = DanTraits_MigraineChance(t); assert(cause == nil, "fever is not a personal trigger")
DanTraits_InfectionFever = nil

-- 8. working them out: the cause is kept from the aura to the end; a strong one caught twice is named, once
local function attackBy(p, why)
  M(p).migSinceEnd = 99; H.corpses = (why == "corpses") and 3 or 0; p._st.stress = (why == "stress") and 1 or 0
  H.rng = { 0, 0 }; ten()
  assert(M(p).migCause == why, "cause noted at the aura: " .. tostring(M(p).migCause))
  for _ = 1, 20 do minute() end
  M(p).migHoursLeft = 1 / 60; minute()
  H.corpses = 0; p._st.stress = 0
end
H.clearHalo()
attackBy(t, "corpses"); assert(M(t).migSeen.corpses == 1 and not M(t).migKnown.corpses, "once: not yet")
attackBy(t, "corpses"); assert(M(t).migKnown.corpses and halo[#halo] == "UI_DanTraits_MigraineTrigger_corpses", "twice: worked out")
local nHalo = #halo
attackBy(t, "corpses"); assert(halo[#halo] ~= "UI_DanTraits_MigraineTrigger_corpses" and #halo > nHalo, "said once")
attackBy(t, "stress"); attackBy(t, "stress")
assert(M(t).migSeen.stress == 2 and not M(t).migKnown.stress, "a weak trigger is never named")

-- 9. sumatriptan: in the aura, the attack is half as bad; in an attack, over within two hours, pain and nausea halved
local covered = false
DanTraits_MedCovered = function(_, id) return id == "sumatriptan" and covered end
local s1 = newPlayer(); H.current = s1
s1._md.DanTraits = { migSinceEnd = 99, migStrong = { "sleep", "thirst", "stress" } }
H.rng = { 0, 50 }; ten(); near(M(s1).migSeverity, 1.0, 1e-9, "severity 1")
covered = true; H.clearHalo(); minute()
near(M(s1).migSeverity, 0.5, 1e-9, "taken in the aura: halved"); assert(halo[#halo] == "+UI_DanTraits_MigraineTriptan", "relief notice")
for _ = 1, 20 do minute() end
assert(M(s1).migActive, "the attack still comes")
near(M(s1).migHoursLeft, 3 + 3 * 0.5 - 1 / 60, 1e-6, "no second use in the attack")
local moodleValue
MF = { getMoodle = function() return { setThresholds = function() end, setValue = function(_, v) moodleValue = v end } end }
H.setPain(s1, 0); for _ = 1, 60 do minute() end
assert(H.pain(s1) == 30, "taken in the aura: pain floor 60 x 0.5 severity, not halved again: " .. H.pain(s1))
M(s1).migSeverity = 0.3; minute()
assert(moodleValue <= 0.5 * (1 - 0.5), "a halved attack still shows as Migraine, not Aura: " .. tostring(moodleValue))
MF = nil
covered = false
local s2 = newPlayer(); H.current = s2
s2._md.DanTraits = { migSinceEnd = 99, migStrong = { "sleep", "thirst", "stress" } }
H.rng = { 0, 50 }; ten(); for _ = 1, 20 do minute() end
assert(M(s2).migActive, "attack on"); near(M(s2).migHoursLeft, 6, 1e-6, "six hours")
covered = true; minute()
near(M(s2).migHoursLeft, 2 - 1 / 60, 1e-9, "in the attack: two hours left")
H.setPain(s2, 0); for _ = 1, 60 do minute() end
assert(H.pain(s2) == 30, "pain floor halved to 30: " .. H.pain(s2))
near(s2._st.foodsick, 25, 1.0, "nausea halved to 25")
covered = false
DanTraits_MedCovered = nil

-- 10. the day after sumatriptan, for anyone: tired and a little clumsy (the grip slip hook), for 24 hours
local a = newPlayer({ traits = {} }); H.current = a
H.clearHalo()
DanTraits_RunHooks("pill", nil, a, "Sumatriptan")
assert(M(a).tripAfterMin == 1440 and halo[#halo] == "UI_DanTraits_TriptanAfter", "after-effect starts")
near(DanTraits_RunHooks("gripSlip", 0, a), 3, 1e-9, "a swing can slip: +3%")
local f0 = a._st.fatigue or 0; minute(); near(a._st.fatigue, f0 + 0.0002, 1e-9, "a little more tired a minute")
M(a).tripAfterMin = 1; minute(); assert(M(a).tripAfterMin == nil, "over after a day")
near(DanTraits_RunHooks("gripSlip", 0, a), 0, 1e-9, "steady again")

-- 11. painkillers in an attack keep a third of their usual relief; out of one, all of it
local pk = newPlayer(); H.current = pk
pk.setPainEffect = function(self, v) self._painFx = v end
pk._md.DanTraits = { migActive = true, migHoursLeft = 3, migSeverity = 1 }
pk._painFx = 0
DanTraits_RunHooks("prePill", nil, pk, "Pills"); pk._painFx = 5400; DanTraits_RunHooks("pill", nil, pk, "Pills")
near(pk._painFx, 5400 * 0.35, 1e-6, "a third of the timer")
M(pk).migActive = false; pk._painFx = 0
DanTraits_RunHooks("prePill", nil, pk, "Pills"); pk._painFx = 5400; DanTraits_RunHooks("pill", nil, pk, "Pills")
assert(pk._painFx == 5400, "no attack: the full dose")

-- 12. a new character: triggers drawn, and a pack of sumatriptan down to two of six, once; none with the option off
local nc = newPlayer(); H.current = nc
H.fire("OnCreatePlayer", 0, nc); H.fire("OnCreatePlayer", 0, nc)
assert(#nc._inv == 1 and nc._inv[1]._type == "DanTraits.Sumatriptan", "one pack")
near(nc._inv[1]._used, 2 / 6, 1e-9, "two tablets left")
assert(M(nc).migStrong and #M(nc).migStrong == 3, "triggers drawn at creation")
SandboxVars = { DanTraits = { StartingMedication = false } }
local nm = newPlayer(); H.current = nm
H.fire("OnCreatePlayer", 0, nm)
assert(#nm._inv == 0, "Starting Medication off: no pack")
SandboxVars = nil

H.pass()
