-- Offline test for DanTraits_Heart.lua: chest pain only while the Endurance
-- moodle shows, the multipliers, beta blockers (level, protection, decay),
-- chest pain easing at rest, a heart attack when pushing on, the slower
-- endurance recovery, the wearing-off notice, and the starting bottles.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
UIManager = { FadeOut = function() end, FadeIn = function() end }
H.load("Faint", "Meds", "Heart")
H.expectEvery("minute", "Heart")
H.expectHooks("OnCreatePlayer")

local near = H.near

-- 1. no Endurance moodle: no chance at all; the moodle's depth sets it
local p = H.player({ traits = { "heart" } }); H.current = p
local d = DanTraits_Data(p)
near(DanTraits_HeartEpisodeChance(p, d), 0, 1e-12, "rested: never")
p._st.endurance = 0.6; near(DanTraits_HeartEpisodeChance(p, d), 0.002, 1e-12, "moodle 1")
p._st.endurance = 0.4; near(DanTraits_HeartEpisodeChance(p, d), 0.005, 1e-12, "moodle 2")
p._st.endurance = 0.05; near(DanTraits_HeartEpisodeChance(p, d), 0.03, 1e-12, "moodle 4")
p._st.endurance = 0.4
p._st.panic = 80; near(DanTraits_HeartEpisodeChance(p, d), 0.0075, 1e-12, "panicking x1.5")
p._st.panic = 0
local old = H.player({ traits = { "heart", "age40s" }, endurance = 0.4 })
near(DanTraits_HeartEpisodeChance(old, DanTraits_Data(old)), 0.00625, 1e-12, "40s x1.25")

-- 2. beta blockers (the shared medication system): a pill is a level of 1, but
--    protection comes with the build-up; fully built up the chance is a quarter
DanTraits_RunHooks("pill", nil, p, "PillsBeta")
near(DanTraits_MedState(p, "beta"), 1, 1e-9, "one pill")
assert(H.halo[#H.halo] == "+UI_DanTraits_HeartBeta", "the heart settles")
near(DanTraits_HeartEpisodeChance(p, d), 0.005, 1e-12, "first pill: not built up yet")
d.meds.beta.built = 0.5
near(DanTraits_HeartEpisodeChance(p, d), 0.005 * 0.625, 1e-12, "half built up: x0.625")
d.meds.beta.built = 1
near(DanTraits_HeartEpisodeChance(p, d), 0.00125, 1e-12, "built up x0.25")

-- 3. chest pain starts on a roll, holds pain and slows endurance recovery
H.rollf = 0
H.minute()
assert(d.hcAnginaMin and d.hcAnginaMin > 0, "chest pain started")
assert(H.halo[#H.halo] == "UI_DanTraits_HeartChestPain", "chest pain notice")
near(DanTraits_RunHooks("enduranceRegen", 1, p, d), 0.33, 1e-9, "endurance recovery cut")

-- 4. at rest it passes twice as fast, and eases with a notice
H.rollf = 0.99
p._st.endurance = 1
local left = d.hcAnginaMin
H.minute(); near(d.hcAnginaMin, left - 2, 1e-9, "resting: two minutes a minute")
H.mins(20)
assert(d.hcAnginaMin == 0, "passed")
assert(H.halo[#H.halo] == "+UI_DanTraits_HeartEased", "eased notice")
assert(H.pain(p) > 0, "the pain floor held while it lasted")

-- 5. worn out but standing still is not pushing on: however the dice fall, no heart attack,
--    and the chest pain passes at the resting rate
local s = H.player({ traits = { "heart" }, endurance = 0.2 }); H.current = s
local sd = DanTraits_Data(s)
sd.hcAnginaMin = 20
H.rollf = 0
H.minute(); H.minute()
assert(not sd.hcAttacks and not sd.hcPushing, "resting at a deep moodle: no heart attack")
near(sd.hcAnginaMin, 16, 1e-9, "and it passes twice as fast")
-- jogging on (running, endurance held by the test) is neither rest nor pushing
s._run = true
H.minute()
near(sd.hcAnginaMin, 15, 1e-9, "running: a minute a minute")
assert(not sd.hcAttacks, "still no heart attack")
s._run = false

-- 5b. pushing on through chest pain (still spending endurance at moodle 2, or sprinting): a heart attack
local q = H.player({ traits = { "heart" }, endurance = 0.45 }); H.current = q
local qd = DanTraits_Data(q)
qd.hcAnginaMin = 20
H.rollf = 0.99
H.minute()                      -- the first minute only takes the reading
q._st.endurance = 0.4           -- and now it has fallen: spending
H.rollf = 0
H.minute()
assert(qd.hcAttacks == 1, "heart attack")
assert(q._health == 85 and q._st.endurance == 0, "health lost and endurance emptied")
assert(DanTraits_IsPassedOut(q), "down")
assert(q._bump == "stagger", "fell")
near(DanTraits_RunHooks("enduranceRegen", 1, q, qd), 0.6, 1e-9, "a day of weak recovery")
H.rollf = 0.99
H.now = H.now + 60000; DanTraits_FaintTick()   -- q comes round: one faint at a time
H.hours = H.hours + 1; DanTraits_FaintTick()
local sp = H.player({ traits = { "heart" }, sprint = true }); H.current = sp
DanTraits_Data(sp).hcAnginaMin = 20
H.rollf = 0
H.minute()
assert(DanTraits_Data(sp).hcAttacks == 1, "sprinting through it: a heart attack")
H.rollf = 0.99

-- 6. the beta blocker level halves in a day, anyone's; the one with the
--    condition is told when it stops protecting, once
local r = H.player(); H.current = r
DanTraits_TakeBetaBlocker(r, 1)
H.mins(1440)
near(DanTraits_MedState(r, "beta"), 0.5, 1e-3, "halved in a day (one pill a day)")
H.clearHalo()
H.mins(10)
assert(#H.halo == 0, "no condition: no wearing-off notice")
local w = H.player({ traits = { "heart" } }); H.current = w
DanTraits_TakeBetaBlocker(w, 1)
H.clearHalo()
H.mins(1450)
local lapses = 0
for _, t in ipairs(H.halo) do if t == "UI_DanTraits_HeartBetaLapse" then lapses = lapses + 1 end end
assert(lapses == 1, "wearing off: one notice")

-- 7. a new character starts on them, fully built up, with two bottles, once
local n = H.player({ traits = { "heart" } }); H.current = n
H.fire("OnCreatePlayer", 0, n)
H.fire("OnCreatePlayer", 0, n)
assert(#n._inv == 2 and n._inv[1]._type == "Base.PillsBeta" and n._inv[2]._type == "Base.PillsBeta", "two bottles of beta blockers")
local lvl, built = DanTraits_MedState(n, "beta")
assert(lvl == 1 and built == 1, "dosed this morning and fully built up")
-- the Starting Medication sandbox option off: no bottles, still dosed this morning
SandboxVars = { DanTraits = { StartingMedication = false } }
local nm = H.player({ traits = { "heart" } }); H.current = nm
H.fire("OnCreatePlayer", 0, nm)
assert(#nm._inv == 0 and select(2, DanTraits_MedState(nm, "beta")) == 1, "off: no bottles, still on them")
SandboxVars = nil

-- 8. an old save's level carries across, a protecting one as fully built up
local o = H.player({ traits = { "heart" } }); H.current = o
DanTraits_Data(o).hcBeta = 0.8
lvl, built = DanTraits_MedState(o, "beta")
assert(lvl == 0.8 and built == 1 and DanTraits_Data(o).hcBeta == nil, "old level moved over")

H.pass()
