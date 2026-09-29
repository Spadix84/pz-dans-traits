-- Offline test for DanTraits_Dependent.lua (Alcoholic): the alcoholism meter
-- fills with habitual drinking and grants the trait, withdrawal scales with
-- it, a sober month cures it, and a drink after that can bring it back.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.roll = 9999
H.load("Dependent")
local collapsed, knocked = 0, {}
DanTraits_Collapse = function() collapsed = collapsed + 1; return true end
DanTraits_KnockHead = function(_, chance, score) knocked[#knocked + 1] = { chance, score }; return 0 end
local halo, near = H.halo, H.near
local ten = H.ten
local function md(p) return p._md.DanTraits end
local function run(p, intox, hours) p._st.intox = intox; for _ = 1, math.floor(hours * 6 + 0.5) do ten() end end

-- 1. one blind-drunk night is not a habit: the meter fills at most 0.08 a day
local p = H.player(); H.current = p
run(p, 100, 10)
near(md(p).depTolerance, 0.08, 1e-9, "daily cap")
assert(not p._traits.dependent, "one night: no trait")

-- 2. a heavy night once a week never adds up
for _ = 1, 8 do run(p, 0, 14 + 6 * 24); run(p, 100, 10) end
assert(not p._traits.dependent and md(p).depTolerance < 0.1, "weekly binge: no trait")

-- 3. drinking hard every day does: 5 h at 50%, 19 h sober, about 0.054 a day net
local q = H.player(); H.current = q
local days = 0
while not q._traits.dependent and days < 30 do run(q, 50, 5); run(q, 0, 19); days = days + 1 end
assert(days == 6, "gained on day 6, got day " .. days)
assert(halo[#halo] == "UI_DanTraits_AlcoholicGained", "notice")

-- 4. withdrawal scales with the meter: at 0.5 craving from 18 h, stress 0.01 per ten minutes
local w = H.player({ traits = { "dependent" } }); H.current = w
ten()
near(md(w).depTolerance, 0.5, 1e-3, "taken at creation: starts at 0.5")
run(w, 0, 17.5); assert(not md(w).withdrawing, "not yet at 17.5 h")
run(w, 0, 1); assert(md(w).withdrawing, "craving by 18.5 h")
assert(halo[#halo] == "UI_DanTraits_DependentCraving", "craving notice")
local s = w._st.stress; ten(); near(w._st.stress - s, 0.02 * md(w).depTolerance, 1e-9, "stress 0.02 x meter")
assert(w._st.unhappy > 0, "low mood")
assert(w._st.pain == 0, "no pain yet")
run(w, 0, 20); assert(w._st.pain > 0, "pain by 38 h (48 x 0.76)")
assert(halo[#halo] == "UI_DanTraits_AlcoholicShakes" and md(w).alcStage == 2, "the shakes")
assert(w._st.foodsick > 0 and w._st.foodsick <= 40 * 0.5, "nausea floor 40 x w")
near(DanTraits_RunHooks("swingDrop", 1, w), 1 + 10 * md(w).alcW, 1e-9, "shaking hands: swing drop chance")
near(DanTraits_RunHooks("sleepWake", 1, w, md(w)), 1 + 2 * md(w).alcW, 1e-9, "light sleep")
near(DanTraits_RunHooks("nightQuality", 1, w, md(w)), 1 - 0.4 * md(w).alcW, 1e-9, "poor sleep")
run(w, 0, 60); assert(md(w).alcStage == 2, "meter under 0.6: never delirium")

-- 4b. a heavy drinker reaches delirium: seizures and hallucinations
local dt = H.player({ traits = { "dependent" } }); H.current = dt
dt._md.DanTraits = { alcInit = true, depTolerance = 1 }
run(dt, 0, 37.5); assert(md(dt).alcStage == 2, "37.5 h: shakes only")
run(dt, 0, 1); assert(md(dt).alcStage == 3 and halo[#halo] == "UI_DanTraits_AlcoholicDelirium", "delirium by 38.5 h (72 x 0.525, the meter slipping)")
H.roll = 0; local pain = dt._st.pain; ten(); H.roll = 9999
assert(collapsed == 1 and dt._bump == nil, "seizure: the shared fall, no fall code of its own")
assert(#knocked == 1 and knocked[1][1] == 0.3 and knocked[1][2] == 0.35, "seizure: a chance to concuss")
assert(dt._st.pain >= math.min(100, pain + 25) and dt._st.panic >= 40 and halo[#halo] == "UI_DanTraits_AlcoholicSeizure", "seizure: hurt and scared")
dt._asleep = true; H.roll = 0; ten(); H.roll = 9999; dt._asleep = false
assert(collapsed == 1 and #knocked == 1, "no seizure asleep")
-- the acute phase holds five days, then fades to a fifth by day ten
local wPeak = md(dt).alcW
run(dt, 0, 240 - md(dt).dryHours)
near(md(dt).alcW, md(dt).depTolerance * 0.2, 1e-3, "lingering at a fifth")
assert(md(dt).alcW < wPeak * 0.25, "well down from the peak")
local ok = pcall(function() H.roll = 0; ten() end); H.roll = 9999; assert(ok, "no hallucination set loaded: nothing breaks")
run(dt, 50, 1 / 6); assert(not md(dt).withdrawing and md(dt).alcStage == 0 and md(dt).alcShakes == 0, "a drink ends it all")
assert(DanTraits_RunHooks("swingDrop", 1, dt) == 1, "steady hands again")

-- 5. a full meter needs a real drink
H.current = w; md(w).depTolerance = 1
run(w, 20, 1 / 6); assert(md(w).dryHours > 0, "20% is not a drink at a full meter (needs > 45%)")
run(w, 50, 1 / 6); assert(md(w).dryHours == 0 and not md(w).withdrawing, "50% is")
assert(halo[#halo] == "UI_DanTraits_DependentSated", "sated notice")

-- 6. a sober month cures it; the meter drains to nothing along the way
run(w, 0, 719)
assert(w._traits.dependent, "719 h: still an alcoholic")
run(w, 0, 1)
assert(not w._traits.dependent and md(w).alcEx and md(w).depTolerance == 0, "30 days: cured")
assert(halo[#halo] == "+UI_DanTraits_AlcoholicCured", "good news")

-- 7. relapse: one roll per drinking session, a win brings the trait back at 0.5
H.roll = 99; H.rolls = 0
run(w, 5, 1)
assert(H.rolls == 1 and not w._traits.dependent, "lucky: one roll for the session, no relapse")
run(w, 0, 1); H.roll = 0
run(w, 5, 1 / 6)
assert(H.rolls == 2 and w._traits.dependent, "next session: relapse")
near(md(w).depTolerance, 0.5, 1e-3, "back at 0.5")
assert(halo[#halo] == "UI_DanTraits_AlcoholicRelapse", "relapse notice")

-- 8. hangover tolerance only for Alcoholics
assert(DanTraits_AlcoholTolerance(q) > 0 and DanTraits_AlcoholTolerance(p) == 0, "tolerance read")

-- 9. withdrawal strength for other systems (Hallucinations): 0 without the trait or while not withdrawing, else the stored strength
local other = H.player(); other._md.DanTraits = { withdrawing = true, alcW = 0.7 }
assert(DanTraits_AlcoholWithdrawal(other) == 0, "no trait: 0")
local dry = H.player({ traits = { "dependent" } }); dry._md.DanTraits = { withdrawing = true, alcW = 0.7 }
near(DanTraits_AlcoholWithdrawal(dry), 0.7, 1e-12, "withdrawing: the strength")
dry._md.DanTraits.withdrawing = false
assert(DanTraits_AlcoholWithdrawal(dry) == 0, "not withdrawing: 0")
assert(DanTraits_AlcoholWithdrawal(H.player({ traits = { "dependent" } })) == 0, "nothing tracked: 0")

H.pass()
