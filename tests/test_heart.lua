-- Offline test for DanTraits_Heart.lua: chest pain only while the Endurance
-- moodle shows, the multipliers, beta blockers (level, protection, decay),
-- chest pain easing at rest, a heart attack when pushing on, the slower
-- endurance recovery, and the starting bottle.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
UIManager = { FadeOut = function() end, FadeIn = function() end }
H.load("Faint", "Heart")
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

-- 2. beta blockers: a pill is a level of 1, protection cuts the chance to a quarter
DanTraits_RunHooks("pill", nil, p, "PillsBeta")
near(d.hcBeta, 1, 1e-9, "one pill")
assert(H.halo[#H.halo] == "+UI_DanTraits_HeartBeta", "the heart settles")
near(DanTraits_HeartEpisodeChance(p, d), 0.00125, 1e-12, "protected x0.25")

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

-- 5. pushing on through chest pain: a heart attack
local q = H.player({ traits = { "heart" }, endurance = 0.4 }); H.current = q
local qd = DanTraits_Data(q)
qd.hcAnginaMin = 20
H.rollf = 0
H.minute()
assert(qd.hcAttacks == 1, "heart attack")
assert(q._health == 85 and q._st.endurance == 0, "health lost and endurance emptied")
assert(DanTraits_IsPassedOut(q), "down")
assert(q._bump == "stagger", "fell")
near(DanTraits_RunHooks("enduranceRegen", 1, q, qd), 0.6, 1e-9, "a day of weak recovery")
H.rollf = 0.99

-- 6. the beta blocker level halves in 12 hours, anyone's
local r = H.player(); H.current = r
local rd = DanTraits_Data(r)
DanTraits_TakeBetaBlocker(r, 1)
H.mins(720)
near(rd.hcBeta, 0.5, 1e-3, "halved in 12 hours")

-- 7. a new character starts with a bottle, once
local n = H.player({ traits = { "heart" } }); H.current = n
H.fire("OnCreatePlayer", 0, n)
H.fire("OnCreatePlayer", 0, n)
assert(#n._inv == 1 and n._inv[1]._type == "Base.PillsBeta", "one bottle of beta blockers")

H.pass()
