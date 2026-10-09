
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
-- Offline test for DanTraits_MDD.lua: pain and stress drag mood, episodes
-- (onset chance, the refractory window, the mood floor and what lifts it,
-- outdoors as a rolling day), antidepressants (a pill a day, the 14-day
-- build-up, side effects, discontinuation), and the Fumbler shakiness.
H.events()
H.stubs()
local pillsSwallowed = 0
ISTakePillAction = { complete = function(self) pillsSwallowed = pillsSwallowed + 1; self.character._depress = 6600; return true end }

H.load("Dependent", "MDD", "Brittle", "Arthritis", "BadDay", "Hallucinations", "Asthma", "Gluten", "Vegetarian", "Meds", "Diabetes")

-- the trait under test is Spiraling unless a test asks for another
local newPlayer = H.factory({ traits = { "spiraling" } })
local halo = H.halo
local minute, ten = H.minute, H.ten

-- 1. pain and stress drag mood down all the time, episode or not
local p = newPlayer({ pain = 50, stress = 0.5 }); H.current = p
minute(); assert(math.abs(p._st.unhappy - 0.9) < 1e-9, "pain 50 -> +0.5, stress 0.5 -> +0.4 per minute, got " .. p._st.unhappy)
local calm = newPlayer({}); H.current = calm
minute(); assert(calm._st.unhappy == 0, "calm and unhurt: nothing")

-- 2. no episode inside the 48 h refractory window; then the roll happens and can start one
local q = newPlayer({}); H.current = q
q._md.DanTraits = { mddSinceEnd = 0 }
H.rng = {}; for _ = 1, 6 * 48 do ten() end
assert(not q._md.DanTraits.mddEpisode, "no roll during refractory (a 0 roll would have started one)")
H.rng = { 99999 }; ten(); assert(not q._md.DanTraits.mddEpisode, "roll above the chance: no episode")
H.rng = { 0, 60, 24 }; ten()
assert(q._md.DanTraits.mddEpisode and q._md.DanTraits.mddSeverity == 1.0 and q._md.DanTraits.mddHoursLeft == 48, "episode: severity 0.4+0.6, 24+24 hours")
assert(halo[#halo] == "UI_DanTraits_MddStart", "start notice")

-- 3. the floor: 75 at full severity, approached at 2 per minute; a book's relief is undone
for _ = 1, 40 do minute() end
assert(q._st.unhappy == 75, "held at the floor, got " .. q._st.unhappy)
q._st.unhappy = 10; minute(); assert(q._st.unhappy == 12, "reading dropped it, it climbs back 2 a minute")
q._st.unhappy = 90; minute(); assert(q._st.unhappy == 90, "worse than the floor is left alone")

-- 4. relief: drink 20, cigarette 10 (for 2 h), comfort food 10 (3 h), exercise up to 15, outdoors up to 15
q._st.unhappy = 0
q._st.intox = 20; for _ = 1, 40 do minute() end; assert(q._st.unhappy == 55, "drunk: floor 75-20, got " .. q._st.unhappy); q._st.intox = 0
assert(DanTraits_MddOnSmoke(q, 1, true) and q._md.DanTraits.mddSmokeTimer == 120, "a cigarette: two hours of relief")
q._st.unhappy = 0; for _ = 1, 40 do minute() end; assert(q._st.unhappy == 65, "after a cigarette: 75-10, got " .. q._st.unhappy)
for _ = 1, 120 do minute() end; assert(q._st.unhappy == 75, "two hours later the cigarette has worn off")
DanTraits_MddOnEat(q, { getUnhappyChange = function() return -10 end })
q._st.unhappy = 0; for _ = 1, 40 do minute() end; assert(q._st.unhappy == 65, "comfort food: 75-10")
DanTraits_MddOnEat(q, { getUnhappyChange = function() return 5 end })
assert(q._md.DanTraits.mddFoodTimer < 180, "a joyless meal does not refresh it")
q._md.DanTraits.mddFoodTimer = 0
q._regularity = { squats = 100, pushups = 100, situps = 100, burpees = 0 }
assert(math.abs(DanTraits_MddRegularity(q) - 1) < 1e-9, "top three exercises count")
q._st.unhappy = 0; for _ = 1, 40 do minute() end; assert(q._st.unhappy == 60, "regular exercise: 75-15, got " .. q._st.unhappy)
q._regularity = {}
q._md.DanTraits.mddOutside = 240
q._st.unhappy = 0; minute(); minute(); assert(q._st.unhappy >= 2 and q._st.unhappy <= 4, "climbing")
for _ = 1, 40 do minute() end; assert(math.abs(q._st.unhappy - (75 - 15 * q._md.DanTraits.mddOutside / 240)) < 0.5, "outdoors: about 75-15, got " .. q._st.unhappy)
q._md.DanTraits.mddOutside = 0

-- 5. outdoors is a rolling day: a minute outside counts one, and fades
local o = newPlayer({ outside = true }); H.current = o
for _ = 1, 60 do minute() end
assert(o._md.DanTraits.mddOutside > 58 and o._md.DanTraits.mddOutside < 60, "an hour outside is about 60 minutes of credit")
o._outside = false; for _ = 1, 1440 do minute() end
assert(o._md.DanTraits.mddOutside < 25, "a day indoors fades most of it")

-- 6. the episode runs its hours down, faster with healthy habits, drinking deepens it, then ends with a notice
H.current = q; q._md.DanTraits.mddHoursLeft = 1; q._md.DanTraits.mddSeverity = 0.5
q._st.intox = 20; ten(); assert(math.abs(q._md.DanTraits.mddSeverity - 0.51) < 1e-9, "drunk: severity +0.01 per 10 min"); q._st.intox = 0
assert(math.abs(q._md.DanTraits.mddHoursLeft - (1 - 1/6)) < 1e-9, "10 minutes off with no habits")
q._regularity = { squats = 100, pushups = 100, situps = 100 }; q._md.DanTraits.mddOutside = 240
ten(); assert(math.abs(q._md.DanTraits.mddHoursLeft - (1 - 1/6 - 2/6)) < 1e-9, "full habits: 20 minutes off per tick")
q._md.DanTraits.mddHoursLeft = 0.1; ten()
assert(not q._md.DanTraits.mddEpisode and q._md.DanTraits.mddSinceEnd == 0 and halo[#halo] == "+UI_DanTraits_MddEnd", "episode over, refractory restarts")

-- 7. onset chance scales with stress, pain, fatigue and being shut in
local stressed = newPlayer({ stress = 1, pain = 100, fatigue = 1 }); H.current = stressed
stressed._md.DanTraits = { mddSinceEnd = 100, mddOutside = 0 }
-- chance = 0.0014 x 3 x 2.5 x 2 x 2 = 0.042 -> 4200 of 100000
H.rng = { 4199 }; ten(); assert(stressed._md.DanTraits.mddEpisode, "4199 < 4200 starts an episode under maximum pressure")
local fine = newPlayer({}); H.current = fine; fine._md.DanTraits = { mddSinceEnd = 100, mddOutside = 300 }
H.rng = { 141 }; ten(); assert(not fine._md.DanTraits.mddEpisode, "141 >= 140: calm life, roll misses")
H.rng = { 139 }; ten(); assert(fine._md.DanTraits.mddEpisode, "139 < 140 still can")

-- 8. Fumbler (Arthritis's grip): 1% base, up to +6 panic, +6 pain, +5 fatigue; ZombRand(1000) < chance x 10 slips (a weak swing, not a drop)
local f = newPlayer({ traits = { "arthritis" } }); H.current = f
assert(math.abs(DanTraits_FumbleChance(f) - 1) < 1e-9, "calm: 1%")
H.clearHalo()
H.rng = { 9 }; H.fire("OnWeaponSwing", f, {}); assert(#f._dropped == 0 and halo[#halo] == "UI_DanTraits_GripSlip", "9 < 10: slipped, kept")
H.clearHalo()
H.rng = { 10 }; H.fire("OnWeaponSwing", f, {}); assert(#halo == 0, "10 >= 10: a clean swing")
f._st.panic = 100; f._st.pain = 100; f._st.fatigue = 1
assert(math.abs(DanTraits_FumbleChance(f) - 18) < 1e-9, "worst case 18%")
-- 9. antidepressants: a pill is a day of coverage, the vanilla lift is cancelled, benefit builds over 14 days
local m = newPlayer({}); H.current = m
local pill = setmetatable({ character = m, item = { getType = function() return "PillsAntiDep" end } }, { __index = ISTakePillAction })
pill:complete(); assert(pillsSwallowed == 1 and m._depress == 0, "swallowed, vanilla effect cancelled")
assert(m._md.DanTraits.mddMedDays == 1, "one day of coverage")
pill:complete(); pill:complete(); pill:complete(); assert(m._md.DanTraits.mddMedDays == 3, "capped at three days ahead")
m._st.intox = 20; m._md.DanTraits.mddMedDays = 0; pill:complete(); assert(m._md.DanTraits.mddMedDays == 0.5, "drunk: half a dose"); m._st.intox = 0
local other = setmetatable({ character = m, item = { getType = function() return "Pills" end } }, { __index = ISTakePillAction })
m._md.DanTraits.mddMedDays = 0; other:complete(); assert(m._md.DanTraits.mddMedDays == 0, "painkillers are not antidepressants")
m._depress = 6600; minute(); assert(m._depress == 0, "a lingering vanilla effect is zeroed every minute")
-- one pill a day for 14 days: streak 14, benefit 1
m._md.DanTraits.mddMedDays = 0; m._md.DanTraits.mddMedStreak = 0
for day = 1, 14 do pill:complete(); for _ = 1, 144 do ten() end end
assert(math.abs(DanTraits_MddBenefit(m) - 1) < 1e-6, "14 unbroken days = full benefit, streak " .. m._md.DanTraits.mddMedStreak)
-- benefit blunts the drag, cuts the floor and the onset chance
m._st.pain = 100; m._st.unhappy = 0; minute(); assert(math.abs(m._st.unhappy - 0.7) < 1e-9, "full pain drag 1.0 x 0.7, got " .. m._st.unhappy); m._st.pain = 0
m._md.DanTraits.mddEpisode = true; m._md.DanTraits.mddSeverity = 1; m._md.DanTraits.mddHoursLeft = 48
m._st.unhappy = 0; for _ = 1, 40 do minute() end; assert(m._st.unhappy == 45, "floor 75 x 0.6 = 45, got " .. m._st.unhappy)
ten(); assert(math.abs(m._md.DanTraits.mddHoursLeft - (48 - (1/6) * 1.5)) < 1e-9, "episode runs down 1.5x faster on a working regimen")
m._md.DanTraits.mddEpisode = false; m._md.DanTraits.mddSinceEnd = 100; m._md.DanTraits.mddOutside = 300; m._st.fatigue = 0; m._st.stress = 0
H.rng = { 57 }; ten(); assert(not m._md.DanTraits.mddEpisode, "calm chance 140 x 0.4 = 56: a 57 misses")
m._md.DanTraits.mddEpisode = false
H.rng = { 55 }; ten(); assert(m._md.DanTraits.mddEpisode, "55 < 56 starts one")
m._md.DanTraits.mddEpisode = false

-- 10. side effects come from the medication system's daily roll (3%), not every early day;
--     lapsing after a week costs three rough days
local n = newPlayer({}); H.current = n; n._md.DanTraits = { mddSinceEnd = 0 }   -- inside the refractory window: no episode rolls
local npill = setmetatable({ character = n, item = { getType = function() return "PillsAntiDep" end } }, { __index = ISTakePillAction })
npill:complete(); for _ = 1, 15 do minute() end
assert(n._st.foodsick == 0, "a missed roll: no side effect")
local lvl, built = DanTraits_MedState(n, "antidepressant")
assert(lvl == 1 and built == 0, "the drug list reads the regimen: a day of cover, not built up yet")
n._md.DanTraits.meds.antidepressant.day = nil
H.rollf = 0.01; npill:complete(); H.rollf = 0.99
for _ = 1, 15 do minute() end
assert(n._st.foodsick == 15 and H.halo[#H.halo] == "UI_DanTraits_MedSide_antidepressant", "a hit on a new day: queasy to 15, with a notice")
n._st.foodsick = 0
n._md.DanTraits.mddMedDays = 0; n._md.DanTraits.mddMedStreak = 10
ten(); assert(n._md.DanTraits.mddWithdraw == 4320 and n._md.DanTraits.mddMedLapsed, "lapsed after 10 days: 3 days of discontinuation")
n._st.unhappy = 0; n._st.stress = 0; minute(); assert(n._st.unhappy >= 0.3 and n._st.unhappy < 0.31 and math.abs(n._st.stress - 0.001) < 1e-9, "discontinuation drags mood and stress (plus the new stress drag), got " .. n._st.unhappy)
for _ = 1, 143 do ten() end; assert(n._md.DanTraits.mddMedStreak < 10 - 2.9, "streak drains 3 days per day off them, now " .. n._md.DanTraits.mddMedStreak)
local short = newPlayer({}); H.current = short; short._md.DanTraits = { mddMedDays = 0, mddMedStreak = 3, mddSinceEnd = 0 }
ten(); assert((short._md.DanTraits.mddWithdraw or 0) == 0, "a three-day streak lapsing does not cause discontinuation")
-- 17. drinking counts past tipsy + 0.3 x tolerance; smoke is told by Smoker's dose, gum a little, the vanilla clock not at all
do
  local function episode(p, extra)
    p._md.DanTraits = { mddEpisode = true, mddSeverity = 1, mddHoursLeft = 48, mddSinceEnd = 0, alcInit = true }
    for k, v in pairs(extra or {}) do p._md.DanTraits[k] = v end
  end
  local function settle(p) p._st.unhappy = 0; for _ = 1, 40 do minute() end; return p._st.unhappy end
  local plainDrinker = newPlayer({}); H.current = plainDrinker; episode(plainDrinker)
  plainDrinker._st.intox = 20; assert(settle(plainDrinker) == 55, "no tolerance: intoxication 0.2 relieves (75 - 20)")
  local al = newPlayer({ traits = { "spiraling", "dependent" } }); H.current = al; episode(al, { alcMeter = 1 })
  al._st.intox = 20; assert(settle(al) == 75, "tolerance 1: intoxication 0.2 is not enough, no relief")
  al._st.intox = 40; assert(settle(al) == 55, "tolerance 1: intoxication 0.4 relieves")
  -- the same line for the severity creep
  local sv = newPlayer({ traits = { "spiraling", "dependent" } }); H.current = sv; episode(sv, { alcMeter = 1, mddSeverity = 0.5 })
  sv._st.intox = 20; ten(); assert(math.abs(sv._md.DanTraits.mddSeverity - 0.5) < 1e-9, "a sip an Alcoholic shrugs off does not deepen the episode")
  sv._st.intox = 40; ten(); assert(math.abs(sv._md.DanTraits.mddSeverity - 0.51) < 1e-9, "a real drink does")
  -- smoke
  local sm = newPlayer({}); H.current = sm; episode(sm)
  DanTraits_MddOnSmoke(sm, 3, true); assert(sm._md.DanTraits.mddSmokeTimer == 120, "a cigar is capped at one full dose")
  local gum = newPlayer({}); H.current = gum; episode(gum)
  DanTraits_MddOnSmoke(gum, 0.4, false); assert(math.abs(gum._md.DanTraits.mddSmokeTimer - 48) < 1e-9, "gum: 40% of the time")
  DanTraits_MddOnSmoke(gum, 0.4, false); assert(math.abs(gum._md.DanTraits.mddSmokeTimer - 48) < 1e-9, "gum never shortens an existing relief")
  assert(settle(gum) == 65, "and it gives the same 10 while it lasts")
  gum._since = 10; minute(); gum._since = 0; minute(); gum._md.DanTraits.mddSmokeTimer = 0
  assert(settle(gum) == 75, "the vanilla smoke clock going down means nothing now")
  local nonMdd = H.player({ traits = {} }); assert(not DanTraits_MddOnSmoke(nonMdd, 1, true), "no trait: nothing")
end

H.pass()
