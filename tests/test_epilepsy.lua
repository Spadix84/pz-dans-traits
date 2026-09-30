-- Offline test for DanTraits_Epilepsy.lua: the seizure rate and its
-- triggers, anticonvulsants (level, protection, decay, the wearing-off
-- notice), the aura then the seizure (fall, dropped weapon, out cold), a
-- seizure asleep, the aftermath, and the bottle.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
UIManager = { FadeOut = function() end, FadeIn = function() end }
H.load("Faint", "Epilepsy")
H.expectEvery("minute", "Epilepsy")

local near = H.near
local BASE = 1 / 192

-- 1. the rate: rested, calm and well it is the base; triggers multiply
local p = H.player({ traits = { "epilepsy" } }); H.current = p
local d = DanTraits_Data(p)
near(DanTraits_SeizureRate(p, d), BASE, 1e-12, "base rate")
p._st.fatigue = 0.75; near(DanTraits_SeizureRate(p, d), BASE * 5, 1e-12, "tired: halfway past 0.5 is x5")
p._st.fatigue = 0
p._st.stress = 0.5; near(DanTraits_SeizureRate(p, d), BASE * 1.5, 1e-12, "stress x1.5")
p._st.stress = 0
DanTraits_AlcoholWithdrawal = function() return 0.5 end
near(DanTraits_SeizureRate(p, d), BASE * 4, 1e-12, "withdrawal x(1 + 6 x 0.5)")
DanTraits_AlcoholWithdrawal = nil
DanTraits_ConcussionStrength = function() return 0.2 end
near(DanTraits_SeizureRate(p, d), BASE * 2, 1e-12, "concussion x(1 + 5 x 0.2)")
DanTraits_ConcussionStrength = nil
DanTraits_Dehydration = function() return 0.5 end
near(DanTraits_SeizureRate(p, d), BASE * 2, 1e-12, "dehydration x(1 + 2 x 0.5)")
DanTraits_Dehydration = nil
DanTraits_DiaLow = function() return 1 end
near(DanTraits_SeizureRate(p, d), BASE * 4, 1e-12, "a bad diabetic low x(1 + 3)")
DanTraits_DiaLow = nil

-- 2. anticonvulsants: a pill is a level of 1, protection cuts seizures to a tenth
DanTraits_RunHooks("pill", nil, p, "Anticonvulsants")
near(d.epMeds, 1, 1e-9, "one pill")
near(DanTraits_SeizureRate(p, d), BASE * 0.1, 1e-12, "protected x0.1")
H.mins(720)
near(d.epMeds, 0.5, 1e-3, "halved in 12 hours")
H.clearHalo()
H.mins(10)
assert(#H.halo == 1 and H.halo[1] == "UI_DanTraits_EpilepsyMedsLapse", "wearing off: one notice")
d.epMeds = 0

-- 3. a roll gives the aura (five to ten minutes of warning; the harness's
--    dice give eight), and then the seizure
local dropped = 0
DanTraits_FumbleDrop = function() dropped = dropped + 1 end
H.rollf = 0
H.minute()
assert(d.epAuraMin == 8 and H.halo[#H.halo] == "UI_DanTraits_EpilepsyAura", "aura first")
H.rollf = 0.99
H.mins(7)
assert(d.epAuraMin == 1 and not d.epSeizures, "still coming")
H.minute()
assert(d.epAuraMin == 0 and not d.epSeizures, "game minutes up, but under 30 real seconds: still the warning")
H.now = H.now + 30000
H.minute()
assert(d.epSeizures == 1 and H.halo[#H.halo] == "UI_DanTraits_EpilepsySeizure", "seizure")
assert(dropped == 1 and p._bump == "stagger" and DanTraits_IsPassedOut(p), "dropped, fell, out")
near(p._st.fatigue, 0.3, 1e-9, "exhausted")

-- 4. the aftermath: headache and low mood, fading over the hour
H.minute()
assert(H.pain(p) > 0 and p._st.unhappy > 0, "headache and low mood after")
assert(d.epAfterMin == 59, "the hour runs down")

-- 4b. asleep: no warning, no fall, nothing dropped; it wakes you and the night scores worse
H.now = H.now + 60000; DanTraits_FaintTick()
H.hours = H.hours + 1; DanTraits_FaintTick()
local s = H.player({ traits = { "epilepsy" }, asleep = true }); H.current = s
local sd = DanTraits_Data(s)
H.clearHalo()
dropped = 0
H.rollf = 0
H.minute()
H.rollf = 0.99
assert(sd.epAuraMin == 8 and #H.halo == 0, "asleep: no aura notice")
H.mins(8)
assert(sd.epSeizures == 1 and H.halo[#H.halo] == "UI_DanTraits_EpilepsyNight", "a seizure in the night")
assert(dropped == 0 and not s._bump and not DanTraits_IsPassedOut(s), "no fall, nothing dropped")
assert(s._woke == 1 and not s._asleep, "it wakes you")
near(DanTraits_RunHooks("nightQuality", 1, s, sd), 0.7, 1e-9, "the night scores worse")
near(DanTraits_RunHooks("nightQuality", 1, s, sd), 1, 1e-9, "once")

-- 5. without the trait nothing happens, but a pill still counts
local plain = H.player(); H.current = plain
H.rollf = 0
H.minute()
assert(not DanTraits_Data(plain).epAuraMin, "no trait: no seizures")
H.rollf = 0.99

-- 6. a new character starts with a bottle, once
local n = H.player({ traits = { "epilepsy" } }); H.current = n
H.fire("OnCreatePlayer", 0, n); H.fire("OnCreatePlayer", 0, n)
assert(#n._inv == 1 and n._inv[1]._type == "DanTraits.Anticonvulsants", "one bottle")
assert(DanTraits_IsAnticonvulsants(n._inv[1]), "and it is recognised")

-- 7. at the wheel: no fall, no sitting on the floor, and the engine is cut; a passenger's is not
local sent = {}
function sendClientCommand(_, module, command) sent[#sent + 1] = module .. " " .. command end
local function inCar(driving)
  local c = H.player({ traits = { "epilepsy" } }); H.current = c
  local car = { getDriver = function() return driving and c or nil end }
  c.getVehicle = function() return car end
  c._events = 0
  c.reportEvent = function() c._events = c._events + 1 end
  c.isSitOnGround = function() return false end
  return c, DanTraits_Data(c)
end
H.now = H.now + 600000; H.hours = H.hours + 10; DanTraits_FaintTick()   -- anyone still out comes round
local c, cd = inCar(true)
H.rollf = 0; H.minute(); H.rollf = 0.99
H.mins(8); H.now = H.now + 30000; H.minute()
assert(cd.epSeizures == 1 and DanTraits_IsPassedOut(c), "out cold at the wheel")
assert(not c._bump, "no fall out of the seat")
assert(#sent == 1 and sent[1] == "vehicle shutOff", "the engine cut out")
H.now = H.now + 5000; DanTraits_FaintTick(); DanTraits_FaintTick()
assert(c._events == 0, "not made to sit on the floor")
H.now = H.now + 600000; H.hours = H.hours + 10; DanTraits_FaintTick()
local pas, pd = inCar(false)
H.rollf = 0; H.minute(); H.rollf = 0.99
H.mins(8); H.now = H.now + 30000; H.minute()
assert(pd.epSeizures == 1 and #sent == 1 and not pas._bump, "a passenger: out, no fall, the driver's engine left alone")

H.pass()
