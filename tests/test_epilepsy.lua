-- Offline test for DanTraits_Epilepsy.lua: the seizure rate and its
-- triggers, anticonvulsants (level, protection, decay), the aura then the
-- seizure (fall, dropped weapon, out cold), the aftermath, and the bottle.
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

-- 2. anticonvulsants: a pill is a level of 1, protection cuts seizures to a tenth
DanTraits_RunHooks("pill", nil, p, "Anticonvulsants")
near(d.epMeds, 1, 1e-9, "one pill")
near(DanTraits_SeizureRate(p, d), BASE * 0.1, 1e-12, "protected x0.1")
H.mins(720)
near(d.epMeds, 0.5, 1e-3, "halved in 12 hours")
d.epMeds = 0

-- 3. a roll gives the aura, and two minutes later the seizure
local dropped = 0
DanTraits_FumbleDrop = function() dropped = dropped + 1 end
H.rollf = 0
H.minute()
assert(d.epAuraMin == 2 and H.halo[#H.halo] == "UI_DanTraits_EpilepsyAura", "aura first")
H.rollf = 0.99
H.minute()
assert(d.epAuraMin == 1 and not d.epSeizures, "still coming")
H.minute()
assert(d.epSeizures == 1 and H.halo[#H.halo] == "UI_DanTraits_EpilepsySeizure", "seizure")
assert(dropped == 1 and p._bump == "stagger" and DanTraits_IsPassedOut(p), "dropped, fell, out")
near(p._st.fatigue, 0.3, 1e-9, "exhausted")

-- 4. the aftermath: headache and low mood, fading over the hour
H.minute()
assert(H.pain(p) > 0 and p._st.unhappy > 0, "headache and low mood after")
assert(d.epAfterMin == 59, "the hour runs down")

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

H.pass()
