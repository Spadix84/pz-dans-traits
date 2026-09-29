-- Offline test for DanTraits_Smoker.lua: the nicotine meter hooks a regular
-- smoker, a cigarette buzzes the uninitiated and relieves only the craving
-- in a Smoker, withdrawal builds at the habit's pace and brings
-- irritability, three weeks clean cures it, cues and relapse after that,
-- nicotine gum, lungs, the cough, and the caffeine and sleep hooks.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.roll = 999999                 -- ZombRand: no chance-based roll succeeds unless a test says so
H.load("Smoker")
local halo, near, mins = H.halo, H.near, H.mins
local drunk = 0
DanTraits_DrunkLevel = function() return drunk end

local minute = H.minute
local function md(p) return p._md.DanTraits end
local function item(kind) return { getType = function() return kind end, getOnEat = function() return "" end } end

-- a cigarette the way the game does it: our pre-hook, vanilla's effect, then a frame
local function smoke(p, kind, vanilla)
  kind = kind or "CigaretteSingle"
  DanTraits_OnEat(p, item(kind), 1)
  if vanilla then vanilla(p._st) end
  H.fire("OnTick")
end
local function vanillaNonSmoker(st) st.foodsick = st.foodsick + 14 end
local function vanillaSmoker(st) st.nw = 0; st.stress = math.max(0, st.stress - 0.05) end

-- 1. a first cigarette: a head rush, lifted mood, less bored, sharper; nauseous
local p = H.player(); H.current = p
p._st.unhappy, p._st.boredom, p._st.fatigue = 30, 40, 0.3
smoke(p, nil, vanillaNonSmoker)
near(p._st.unhappy, 22, 1e-9, "buzz: mood")
near(p._st.boredom, 25, 1e-9, "buzz: boredom")
near(p._st.fatigue, 0.27, 1e-9, "buzz: sharper")
near(p._st.foodsick, 14, 1e-9, "no tolerance: all the nausea")
assert(halo[#halo] == "+UI_DanTraits_SmokerBuzz", "head rush")
near(md(p).nicMeter, 0.025, 1e-9, "meter")
assert(not p._traits["base:smoker"], "one cigarette: no trait")
smoke(p, "Apple"); near(md(p).nicMeter, 0.025, 1e-9, "an apple is not tobacco")

-- 2. four a day hooks you in about a week; the buzz and the nausea fade on the way
local q = H.player(); H.current = q
local days, buzzDay3, sickDay5 = 0, nil, nil
while not q._traits["base:smoker"] and days < 30 do
  days = days + 1
  for _ = 1, 4 do
    local u, s = q._st.unhappy, q._st.foodsick
    q._st.unhappy = 50
    smoke(q, nil, vanillaNonSmoker)
    if days == 3 and not buzzDay3 then buzzDay3 = 50 - q._st.unhappy end
    if days == 5 and not sickDay5 then sickDay5 = q._st.foodsick - s end
  end
  if not q._traits["base:smoker"] then mins(1440) end
end
assert(days == 6, "hooked on day 6, got day " .. days)
assert(halo[#halo] == "UI_DanTraits_SmokerGained", "gained notice")
assert(buzzDay3 < 8 * 0.75 and buzzDay3 > 0, "day 3: the buzz is fading, got " .. buzzDay3)
assert(sickDay5 < 14 * 0.4, "day 5: much less nauseous, got " .. sickDay5)

-- 3. one a day never does
local r = H.player(); H.current = r
for _ = 1, 40 do smoke(r, nil, vanillaNonSmoker); mins(1440) end
assert(not r._traits["base:smoker"] and md(r).nicMeter < 0.03, "one a day: no trait")

-- 4. taken at creation: a half-full meter and years on the lungs; the craving builds at vanilla's pace
local s = H.player({ traits = { "base:smoker" } }); H.current = s
minute()
near(md(s).nicMeter, 0.5, 1e-3, "starts at 0.5")
near(md(s).nicLungs, 0.35, 1e-3, "starts with damaged lungs")
s._st.nw = s._st.nw + 0.001; minute()
near(s._st.nw, 0.001, 1e-6, "meter 0.5: vanilla pace")
md(s).nicMeter = 1
s._st.nw = s._st.nw + 0.001; minute()
near(s._st.nw, 0.001 + 0.001 * 1.75, 1e-5, "meter 1: 1.75x")
drunk = 2; local before = s._st.nw
s._st.nw = s._st.nw + 0.001; minute()
near(s._st.nw - before, 0.001 * 1.75 * 1.5, 1e-5, "drunk: faster still")
drunk = 0

-- 5. withdrawal: irritability up to Angry, hungrier, sleeping badly
s._st.nw = 0.51; md(s).nicLastW = 0.51
mins(60)
near(s._st.anger, 0.6, 0.003, "full withdrawal: irritability 0.6")
s._st.anger = 0.55; DanTraits_updateSmokerFrame(s)   -- vanilla's drain between minutes
assert(s._st.anger > 0.6, "held every frame: no dip under the level, no flicker")
assert(s._st.hunger > 0.01, "hungrier")
near(DanTraits_NicotineWithdrawal(s), 1, 1e-9, "withdrawal read by others")
near(DanTraits_RunHooks("sleepWake", 1, s, md(s)), 2, 1e-9, "light sleep")
near(DanTraits_RunHooks("nightQuality", 1, s, md(s)), 0.8, 1e-9, "poor night")
local craving = 0
for _, t in ipairs(halo) do if t == "UI_DanTraits_SmokerCraving" then craving = craving + 1 end end
assert(craving == 1, "says why it is angry, once: got " .. craving)
s._asleep = true; minute(); DanTraits_updateSmokerFrame(s); s._asleep = false
assert(s._st.anger < 0.01 and md(s).nicAnger == 0, "asleep: the irritability goes with the hold, not left to vanilla's drain")
mins(60); near(s._st.anger, 0.6, 0.003, "awake: back to irritable")

-- 6. relief is the craving answered: a lot in full withdrawal, next to nothing chain-smoked
s._st.stress, s._st.unhappy = 0.5, 50
smoke(s, nil, vanillaSmoker)
near(s._st.stress, 0.45 - 0.1, 1e-9, "full craving: stress relief")
near(s._st.unhappy, 40, 1e-9, "full craving: mood relief")
assert(s._st.anger < 0.01 and md(s).nicAnger == 0, "full craving: the irritability goes with it, got " .. s._st.anger)
assert(md(s).nicLastW == 0, "next craving starts from zero")
smoke(s, nil, vanillaSmoker)
near(s._st.stress, 0.30, 1e-9, "chain-smoked: vanilla's bit only")
near(s._st.unhappy, 40, 1e-9, "chain-smoked: no lift")
near(DanTraits_RunHooks("sleepWake", 1, s, md(s)), 1.5, 1e-9, "a cigarette before bed keeps you up")

-- 7. withdrawal peaks three days, then its ceiling winds down; three weeks cures
md(s).nicDryHours = 300; s._st.nw = 0.51; md(s).nicLastW = 0.51
minute()
near(s._st.nw, 0.51 * (1 - 0.75 * (300 + 1 / 60 - 72) / 432), 1e-4, "winding down")
md(s).nicDryHours = 503.9; mins(10)
assert(not s._traits["base:smoker"] and md(s).nicEx and s._st.nw == 0 and md(s).nicMeter == 0, "three weeks: cured")
assert(halo[#halo] == "+UI_DanTraits_SmokerCured", "cured notice")

-- 8. an ex-smoker: a bad moment brings a craving
s._st.stress = 0.6; s._st.anger = 0; minute()
assert(halo[#halo] == "UI_DanTraits_SmokerCue", "cue notice")
mins(30); assert(s._st.anger > 0.15 and s._st.anger <= 0.21, "cue: irritable")
local n = #halo; mins(60); assert(#halo == n, "one notice per cue")

-- 9. relapse: the first smoke of a session is a coin flip; a miss still hooks twice as fast
H.roll = 999999
local m0 = md(s).nicMeter
smoke(s, nil, vanillaNonSmoker)
assert(not s._traits["base:smoker"], "lucky")
near(md(s).nicMeter - m0, 0.05, 1e-9, "kindling: double gain")
H.roll = 0; smoke(s, nil, vanillaNonSmoker)
assert(not s._traits["base:smoker"], "same session: no second roll")
md(s).nicDryHours = 13; smoke(s, nil, vanillaNonSmoker); H.roll = 999999
assert(s._traits["base:smoker"] and halo[#halo] == "UI_DanTraits_SmokerRelapse", "relapse")
near(md(s).nicMeter, 0.5, 1e-9, "back at 0.5")

-- 10. nicotine gum: most of the craving and the irritability gone, the clock still running
md(s).nicDryHours = 100; s._st.nw = 0.51; s._st.anger = 0.5
DanTraits_RunHooks("pill", nil, s, "NicotineGum")
near(s._st.nw, 0.51 * 0.4, 1e-9, "gum: craving")
near(s._st.anger, 0.2, 1e-9, "gum: irritability")
near(md(s).nicDryHours, 100, 1e-9, "gum: quitting clock untouched")
assert(halo[#halo] == "+UI_DanTraits_SmokerGum", "gum notice")

-- 11. a pack through the pill action; chewing tobacco spares the lungs
local lungs = md(s).nicLungs
DanTraits_RunHooks("prePill", nil, s, "CigarettePack", item("CigarettePack")); vanillaSmoker(s._st); H.fire("OnTick")
near(md(s).nicLungs - lungs, 0.0004, 1e-9, "pack: a cigarette on the lungs")
assert(md(s).nicDryHours == 0, "pack: resets the clock")
lungs = md(s).nicLungs; md(s).nicDryHours = 5
DanTraits_RunHooks("prePill", nil, s, "TobaccoChewing", item("TobaccoChewing")); H.fire("OnTick")
assert(md(s).nicLungs == lungs and md(s).nicDryHours == 0, "chewing: nicotine, no smoke")
smoke(s, "Cigar", vanillaSmoker); near(md(s).nicLungs - lungs, 0.0012, 1e-9, "a cigar is three")

-- 12. the lungs heal once the smoking stops, slowly
local l = H.player(); H.current = l
l._md.DanTraits = { nicMeter = 0, nicLungs = 0.5, nicSmokeHours = 0, nicEx = true, nicExHours = 99999 }
mins(60 * 23); near(md(l).nicLungs, 0.5, 1e-9, "no healing within a day")
mins(60 * 25); assert(md(l).nicLungs < 0.5 and md(l).nicLungs > 0.49, "healing")
-- endurance comes back slower
l._st.endurance = 0.5; DanTraits_updateSmokerFrame(l); l._st.endurance = 0.6; DanTraits_updateSmokerFrame(l)
near(l._st.endurance, 0.5 + 0.1 * (1 - 0.3 * md(l).nicLungs), 1e-9, "endurance recovery cut")

-- 13. the cough: worse lungs, a stronger habit, exertion and mornings
local c = H.player({ traits = { "base:smoker" } }); H.current = c
c._md.DanTraits = { nicInit = true, nicMeter = 1, nicLungs = 1, nicDryHours = 0 }
H.roll = 5000                      -- a 0.5 % roll: beats 0.4 %/min resting, not 1.6 % exerted
md(c).nicLastW = 0; mins(5); assert(c._coughs == 0, "resting: no cough on this roll")
c._run = true; minute(); c._run = false
assert(c._coughs == 1, "exerted: cough")
minute(); c._run = true; minute(); c._run = false
assert(c._coughs == 1, "three minutes between coughs")
c._asleep = true; mins(90); c._asleep = false
assert(c._coughs == 1, "no cough asleep")
mins(3); assert(c._coughs == 2, "morning cough")
H.roll = 999999

-- 14. caffeine: smoking speeds its clearance, and it wears off in days
local k = H.player(); H.current = k
for _ = 1, 10 do smoke(k, nil, vanillaNonSmoker) end
near(DanTraits_RunHooks("caffeineClearance", 1, k), 2, 1e-9, "ten cigarettes: twice as fast")
mins(39 * 60)
near(DanTraits_RunHooks("caffeineClearance", 1, k), 1.5, 1e-3, "39 h later: halfway back")
local z = H.player(); H.current = z
assert(DanTraits_RunHooks("caffeineClearance", 1, z) == 1, "never smoked: unchanged")
minute(); assert(md(z) == nil or md(z).nicMeter == nil, "never smoked: nothing stored")

H.pass()
