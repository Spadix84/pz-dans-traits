-- Offline test for DanTraits_Heart.lua (the strain rebuild of 2026-10-09): the
-- strain meter and what feeds it, the multipliers, chest pain at full strain
-- (no running or sprinting, dearer swings, a third of the recovery, twice as
-- fast to pass at rest), a heart attack when pushing on and the week after in
-- three stages (recovery, spending, melee damage), a second attack within a
-- day, nitroglycerin and its overdose, beta blockers halving and slowing
-- recovery a tenth, the wearing-off notice, and the starting kit.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
UIManager = { FadeOut = function() end, FadeIn = function() end, setFadeBeforeUI = function() end }
local weakened = {}
DanTraits_WeakenWeapon = function(player, weapon, scale) weakened[#weakened + 1] = scale end
H.load("Faint", "Meds", "Heart", "Age")
H.expectEvery("minute", "Heart")
H.expectEvery("frame", "Heart")
H.expectHooks("OnCreatePlayer", "OnWeaponSwing")

local near = H.near
local function D(p) return DanTraits_Data(p) end

-- 1. the rate: age, scars, beta blockers (the build x this)
local p = H.player({ traits = { "heart" } }); H.current = p
local d = D(p)
near(DanTraits_HeartStrainRate(p, d), 1, 1e-12, "plain: x1")
local old = H.player({ traits = { "heart", "age40s" } })
near(DanTraits_HeartStrainRate(old, D(old)), 1.25, 1e-12, "40s x1.25")
local older = H.player({ traits = { "heart", "age50s" } })
near(DanTraits_HeartStrainRate(older, D(older)), 1.5, 1e-12, "50s x1.5")
local young = H.player({ traits = { "heart", "age20s" } })
near(DanTraits_HeartStrainRate(young, D(young)), 0.8, 1e-12, "20s x0.8")
d.hcAttacks = 2; near(DanTraits_HeartStrainRate(p, d), 1.4, 1e-12, "two attacks survived: x1.4"); d.hcAttacks = nil
DanTraits_RunHooks("pill", nil, p, "PillsBeta")
near(DanTraits_MedState(p, "beta"), 1, 1e-9, "one pill")
near(DanTraits_HeartStrainRate(p, d), 1, 1e-12, "first pill: not built up yet")
d.meds.beta.built = 0.5; near(DanTraits_HeartStrainRate(p, d), 0.75, 1e-12, "half built up: x0.75")
d.meds.beta.built = 1; near(DanTraits_HeartStrainRate(p, d), 0.5, 1e-12, "built up: x0.5")
near(DanTraits_RunHooks("enduranceRegen", 1, p, d), 0.9, 1e-9, "on beta blockers: recovery a tenth slower")
local anyone = H.player(); H.current = anyone
DanTraits_RunHooks("pill", nil, anyone, "PillsBeta"); D(anyone).meds.beta.built = 1
near(DanTraits_RunHooks("enduranceRegen", 1, anyone, D(anyone)), 0.9, 1e-9, "anyone on them: the same")
d.meds = nil

-- 2. what feeds the strain: endurance spent, sprinting, running, the Endurance moodle, panic; rest drains it
H.current = p
H.minute()                                   -- seeds the endurance reading
near(d.hcStrain, 0, 1e-12, "resting: nothing")
p._st.endurance = 0.9; H.minute()
near(d.hcStrain, 0.06, 1e-9, "0.1 endurance spent: +0.06")
p._sprint = true; H.minute()
near(d.hcStrain, 0.11, 1e-9, "sprinting: +0.05")
p._sprint = false; p._run = true; H.minute()
near(d.hcStrain, 0.13, 1e-9, "running: +0.02")
p._run = false; p._st.panic = 100; H.minute()
near(d.hcStrain, 0.18, 1e-9, "full panic: +0.05 (from half way up)")
p._st.panic = 0; p._st.endurance = 0.4; H.minute()
near(d.hcStrain, 0.18 + 0.6 * 0.5 + 0.012 * 2, 1e-9, "a deep spend at Endurance moodle 2: the spend and the moodle")
H.minute()
near(d.hcStrain, 0.18 + 0.6 * 0.5 + 0.012 * 2 - 0.08, 1e-9, "still, spending nothing: rest drains 0.08")
p._asleep = true; H.minute()
near(d.hcStrain, 0.18 + 0.6 * 0.5 + 0.012 * 2 - 0.18, 1e-9, "asleep: 0.1")
p._asleep = false
local sm = H.player({ traits = { "heart", "age40s" }, endurance = 0.9 }); H.current = sm
H.minute(); sm._st.endurance = 0.8; H.minute()
near(D(sm).hcStrain, 0.06 * 1.25, 1e-9, "the rate multiplies the build")

-- 3. at full strain: chest pain, the strain falls back to 0.8
H.current = p
p._st.endurance = 1; H.minute()              -- rested: the reading is 1 again
d.hcStrain = 0.97; p._st.endurance = 0.9; H.minute()
assert(d.hcAnginaMin and d.hcAnginaMin >= 15, "chest pain started")
near(d.hcStrain, 0.8, 1e-9, "strain back to 0.8")
assert(H.halo[#H.halo] == "UI_DanTraits_HeartChestPain", "chest pain notice")
assert(d.hcEpisodes == 1, "counted")
near(DanTraits_RunHooks("enduranceRegen", 1, p, d), 0.33, 1e-9, "endurance recovery cut")

-- 4. through chest pain: no sprinting or running, swings cost half as much again
p._sprint = true; H.frame(p)
assert(p._sprint == false and d.hcTried == "sprint", "a sprint is stopped and remembered")
p._run = true; H.frame(p)
assert(d.hcTried == "run" or d.hcTried == "sprint", "a run is remembered too")
p._run = false
p._st.endurance = 1; DanTraits_DeltaRemember(d, "enduranceRegen", 1); H.frame(p)   -- (told to the regen pipeline, or it reads the jump as recovery and trims it)
p._attacking = true; p._st.endurance = 0.9; H.frame(p)
near(p._st.endurance, 0.85, 1e-9, "a swing that spent 0.1 spends 0.15")
p._attacking = false
H.frame(p)                                   -- nothing happens with no fall

-- 5. at rest it passes twice as fast, and eases with a notice
H.rollf = 0.99
d.hcTried = nil
p._st.endurance = 1
H.minute()                                   -- the endurance rose: spent 0, resting
local left = d.hcAnginaMin
H.minute(); near(d.hcAnginaMin, left - 2, 1e-9, "resting: two minutes a minute")
H.mins(20)
assert(d.hcAnginaMin == 0, "passed")
assert(H.halo[#H.halo] == "+UI_DanTraits_HeartEased", "eased notice")
assert(H.pain(p) > 0, "the pain floor held while it lasted")

-- 6. pushing on through chest pain (spending at Endurance moodle 2, or a swing): a heart attack
local q = H.player({ traits = { "heart" }, endurance = 0.45 }); H.current = q
local qd = D(q)
qd.hcAnginaMin = 20
H.rollf = 0.99
H.minute()                      -- the first minute only takes the reading
q._st.endurance = 0.4           -- and now it has fallen: spending at moodle 2
H.rollf = 0
H.minute()
assert(qd.hcAttacks == 1, "heart attack")
assert(q._health == 85 and q._st.endurance == 0, "health lost and endurance emptied")
assert(DanTraits_IsPassedOut(q), "down")
near(qd.hcStrain, 0.5, 1e-9, "strain set to 0.5")
near(qd.hcWeakH, 168, 1e-9, "a week of recovery")
assert(H.halo[#H.halo] == "UI_DanTraits_HeartAttack", "the notice")

-- 7. the week after, in three stages: recovery, spending, melee damage; notices as each passes
assert(DanTraits_HeartWeakStage(q, qd) == 1, "stage 1")
near(DanTraits_RunHooks("enduranceRegen", 1, q, qd), 0.5, 1e-9, "stage 1: recovery x0.5")
H.rollf = 0.99
H.now = H.now + 60000; DanTraits_FaintTick()   -- q comes round
H.hours = H.hours + 1; DanTraits_FaintTick()
assert(not DanTraits_IsPassedOut(q), "up again")
q._st.endurance = 1; DanTraits_DeltaRemember(qd, "enduranceRegen", 1); H.frame(q)
q._run = true; q._st.endurance = 0.9; H.frame(q)
near(q._st.endurance, 0.85, 1e-9, "stage 1: running that spent 0.1 spends 0.15")
q._run = false
H.fire("OnWeaponSwing", q, { getModData = function() return {} end })
assert(weakened[#weakened] == 0.5, "stage 1: melee x0.5")
qd.hcWeakH = 100
assert(DanTraits_HeartWeakStage(q, qd) == 2, "stage 2")
near(DanTraits_RunHooks("enduranceRegen", 1, q, qd), 0.65, 1e-9, "stage 2: recovery x0.65")
H.fire("OnWeaponSwing", q, { getModData = function() return {} end })
assert(weakened[#weakened] == 0.65, "stage 2: melee x0.65")
qd.hcWeakH = 10
near(DanTraits_RunHooks("enduranceRegen", 1, q, qd), 0.8, 1e-9, "stage 3: recovery x0.8")
qd.hcWeakH = 112 + 1 / 120
H.clearHalo(); H.minute()
assert(DanTraits_HeartWeakStage(q, qd) == 2 and H.halo[#H.halo] == "+UI_DanTraits_HeartStronger", "stage 1 to 2: a little stronger")
qd.hcWeakH = 1 / 120
H.clearHalo(); H.minute()
assert(qd.hcWeakH == 0 and H.halo[#H.halo] == "+UI_DanTraits_HeartRecovered", "the week over: recovered")
near(DanTraits_RunHooks("enduranceRegen", 1, q, qd), 1, 1e-9, "recovery back to normal")
H.fire("OnWeaponSwing", q, { getModData = function() return {} end })
assert(weakened[#weakened] == 0.65, "no weakening once recovered")
-- a sprint through chest pain is pushing on too
local sp = H.player({ traits = { "heart" }, sprint = true }); H.current = sp
D(sp).hcAnginaMin = 20
H.rollf = 0
H.minute()
assert(D(sp).hcAttacks == 1, "sprinting through it: a heart attack")
H.rollf = 0.99

-- 8. a second attack within a day drops health to the floor
local s2 = H.player({ traits = { "heart" }, endurance = 0.45 }); H.current = s2
local s2d = D(s2)
s2d.hcAttacks, s2d.hcLastAttackH = 1, H.hours - 10
s2d.hcAnginaMin = 20
H.rollf = 0.99; H.minute()
s2._st.endurance = 0.4; H.rollf = 0; H.minute()
assert(s2d.hcAttacks == 2 and s2._health == 10, "a second attack in a day: health to the floor, got " .. tostring(s2._health))
assert(H.halo[#H.halo] == "UI_DanTraits_HeartAttackAgain", "its own notice")
H.rollf = 0.99
local s3 = H.player({ traits = { "heart" }, endurance = 0.45 }); H.current = s3
D(s3).hcAttacks, D(s3).hcLastAttackH = 1, H.hours - 30
D(s3).hcAnginaMin = 20
H.minute(); s3._st.endurance = 0.4; H.rollf = 0; H.minute(); H.rollf = 0.99
assert(s3._health == 85, "a day or more later: the usual 15")

-- 9. nitroglycerin: chest pain gone within a minute, half the strain off, then a headache; two in an hour is too many
local n = H.player({ traits = { "heart" } }); H.current = n
local nd = D(n)
nd.hcAnginaMin, nd.hcStrain = 20, 0.8
H.clearHalo()
DanTraits_RunHooks("pill", nil, n, "Nitroglycerin")
assert(nd.hcAnginaMin == 1 and H.halo[#H.halo] == "+UI_DanTraits_HeartNitro", "the pain is on its way out")
near(nd.hcStrain, 0.4, 1e-9, "half the strain gone")
assert(nd.hcNitroMin == 30, "half an hour of headache")
H.minute(); H.minute()
assert(nd.hcAnginaMin == 0, "chest pain over")
assert(H.pain(n) > 0, "the headache's pain floor")
DanTraits_MedTake(n, "nitroglycerin", 1); DanTraits_MedTake(n, "nitroglycerin", 1)
H.minute()
assert(nd.meds.nitroglycerin.over == true, "two within an hour: too much")
-- anyone can take it: the headache, no chest pain to end
local any = H.player(); H.current = any
DanTraits_RunHooks("pill", nil, any, "Nitroglycerin")
assert(D(any).hcNitroMin == 30 and (D(any).hcAnginaMin or 0) == 0, "no condition: just the headache")

-- 10. the beta blocker level halves in a day, anyone's; the one with the
--     condition is told when it stops protecting, once
local r = H.player(); H.current = r
DanTraits_MedTake(r, "beta", 1)
H.mins(1440)
near(DanTraits_MedState(r, "beta"), 0.5, 1e-3, "halved in a day (one pill a day)")
H.clearHalo()
H.mins(10)
assert(#H.halo == 0, "no condition: no wearing-off notice")
local w = H.player({ traits = { "heart" } }); H.current = w
DanTraits_MedTake(w, "beta", 1)
H.clearHalo()
H.mins(1450)
local lapses = 0
for _, t in ipairs(H.halo) do if t == "UI_DanTraits_HeartBetaLapse" then lapses = lapses + 1 end end
assert(lapses == 1, "wearing off: one notice")

-- 11. a new character starts on beta blockers built up half way, with one bottle and a bottle of nitroglycerin, once
local k = H.player({ traits = { "heart" } }); H.current = k
H.fire("OnCreatePlayer", 0, k)
H.fire("OnCreatePlayer", 0, k)
assert(#k._inv == 2 and k._inv[1]._type == "Base.PillsBeta" and k._inv[2]._type == "DanTraits.Nitroglycerin", "one bottle of each")
local lvl, built = DanTraits_MedState(k, "beta")
assert(lvl == 1 and built == 0.5, "dosed this morning, half built up")
SandboxVars = { DanTraits = { StartingMedication = false } }
local km = H.player({ traits = { "heart" } }); H.current = km
H.fire("OnCreatePlayer", 0, km)
assert(#km._inv == 0 and select(2, DanTraits_MedState(km, "beta")) == 0.5, "off: no bottles, still on them")
SandboxVars = nil

-- 12. without the trait: nothing tracked, the week's effects and the headache still run for anyone
local plain = H.player({ endurance = 0.9 }); H.current = plain
H.minute(); plain._st.endurance = 0.5; H.minute()
assert(D(plain).hcStrain == nil, "no trait: no strain")
D(plain).hcWeakH = 150
near(DanTraits_RunHooks("enduranceRegen", 1, plain, D(plain)), 0.5, 1e-9, "the week after an attack runs on whoever has it")

H.pass()
