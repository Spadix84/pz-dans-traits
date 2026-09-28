-- Offline test for DanTraits_Smoker.lua: the nicotine meter hooks a regular
-- smoker, a cigarette buzzes the uninitiated and relieves only the craving
-- in a Smoker, withdrawal builds at the habit's pace and brings
-- irritability, three weeks clean cures it, cues and relapse after that,
-- nicotine gum, lungs, the cough, and the caffeine and sleep hooks.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
local function stat(name, max) return setmetatable({ name = name }, { __index = { getMaximumValue = function() return max end } }) end
CharacterStat = {
  NICOTINE_WITHDRAWAL = stat("nw", 0.51), STRESS = stat("stress", 1), UNHAPPINESS = stat("unhappy", 100),
  BOREDOM = stat("boredom", 100), FATIGUE = stat("fatigue", 1), HUNGER = stat("hunger", 1),
  FOOD_SICKNESS = stat("sick", 100), ANGER = stat("anger", 1), ENDURANCE = stat("endurance", 1),
  INTOXICATION = stat("intox", 100), PAIN = stat("pain", 100), PANIC = stat("panic", 100),
}
CharacterTrait = { SMOKER = "base:smoker" }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = {}
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
local nextRoll = 999999
function ZombRand() return nextRoll end

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Smoker" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
local drunk = 0
DanTraits_DrunkLevel = function() return drunk end

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or {}) do traits[t] = true end
  local st = { nw = 0, stress = 0, unhappy = 0, boredom = 0, fatigue = 0, hunger = 0, sick = 0, anger = 0, endurance = 1 }
  local md = {}
  local p
  p = { isDead = function() return false end, getModData = function() return md end,
    getCharacterTraits = function() return {
      add = function(_, e) traits[e] = true end, remove = function(_, e) traits[e] = nil end,
      getKnownTraits = function()
        local l = {}; for k in pairs(traits) do l[#l+1] = k end
        return { size = function() return #l end, get = function(_, i) return l[i + 1] end }
      end } end,
    getStats = function() return { get = function(_, k) return st[k.name] end, set = function(_, k, v) st[k.name] = v end } end,
    isAsleep = function() return p._asleep end, isSprinting = function() return false end, isRunning = function() return p._running end,
    triggerCough = function() p._coughs = p._coughs + 1 end,
    setTimeSinceLastSmoke = function(_, v) p._since = v end,
    _st = st, _md = md, _traits = traits, _coughs = 0 }
  return p
end
local current
function getSpecificPlayer() return current end
local minute = handlers.EveryOneMinute
local function H(p) return p._md.DanTraits end
local function near(a, b, eps, msg) assert(math.abs(a - b) <= eps, msg .. ": expected " .. b .. ", got " .. a) end
local function mins(n) for _ = 1, n do minute() end end
local function item(kind) return { getType = function() return kind end, getOnEat = function() return "" end } end

-- a cigarette the way the game does it: our pre-hook, vanilla's effect, then a frame
local function smoke(p, kind, vanilla)
  kind = kind or "CigaretteSingle"
  DanTraits_OnEat(p, item(kind), 1)
  if vanilla then vanilla(p._st) end
  handlers.OnTick()
end
local function vanillaNonSmoker(st) st.sick = st.sick + 14 end
local function vanillaSmoker(st) st.nw = 0; st.stress = math.max(0, st.stress - 0.05) end

-- 1. a first cigarette: a head rush, lifted mood, less bored, sharper; nauseous
local p = makePlayer(); current = p
p._st.unhappy, p._st.boredom, p._st.fatigue = 30, 40, 0.3
smoke(p, nil, vanillaNonSmoker)
near(p._st.unhappy, 22, 1e-9, "buzz: mood")
near(p._st.boredom, 25, 1e-9, "buzz: boredom")
near(p._st.fatigue, 0.27, 1e-9, "buzz: sharper")
near(p._st.sick, 14, 1e-9, "no tolerance: all the nausea")
assert(halo[#halo] == "+UI_DanTraits_SmokerBuzz", "head rush")
near(H(p).nicMeter, 0.025, 1e-9, "meter")
assert(not p._traits["base:smoker"], "one cigarette: no trait")
smoke(p, "Apple"); near(H(p).nicMeter, 0.025, 1e-9, "an apple is not tobacco")

-- 2. four a day hooks you in about a week; the buzz and the nausea fade on the way
local q = makePlayer(); current = q
local days, buzzDay3, sickDay5 = 0, nil, nil
while not q._traits["base:smoker"] and days < 30 do
  days = days + 1
  for _ = 1, 4 do
    local u, s = q._st.unhappy, q._st.sick
    q._st.unhappy = 50
    smoke(q, nil, vanillaNonSmoker)
    if days == 3 and not buzzDay3 then buzzDay3 = 50 - q._st.unhappy end
    if days == 5 and not sickDay5 then sickDay5 = q._st.sick - s end
  end
  if not q._traits["base:smoker"] then mins(1440) end
end
assert(days == 6, "hooked on day 6, got day " .. days)
assert(halo[#halo] == "UI_DanTraits_SmokerGained", "gained notice")
assert(buzzDay3 < 8 * 0.75 and buzzDay3 > 0, "day 3: the buzz is fading, got " .. buzzDay3)
assert(sickDay5 < 14 * 0.4, "day 5: much less nauseous, got " .. sickDay5)

-- 3. one a day never does
local r = makePlayer(); current = r
for _ = 1, 40 do smoke(r, nil, vanillaNonSmoker); mins(1440) end
assert(not r._traits["base:smoker"] and H(r).nicMeter < 0.03, "one a day: no trait")

-- 4. taken at creation: a half-full meter and years on the lungs; the craving builds at vanilla's pace
local s = makePlayer({ traits = { "base:smoker" } }); current = s
minute()
near(H(s).nicMeter, 0.5, 1e-3, "starts at 0.5")
near(H(s).nicLungs, 0.35, 1e-3, "starts with damaged lungs")
s._st.nw = s._st.nw + 0.001; minute()
near(s._st.nw, 0.001, 1e-6, "meter 0.5: vanilla pace")
H(s).nicMeter = 1
s._st.nw = s._st.nw + 0.001; minute()
near(s._st.nw, 0.001 + 0.001 * 1.75, 1e-5, "meter 1: 1.75x")
drunk = 2; local before = s._st.nw
s._st.nw = s._st.nw + 0.001; minute()
near(s._st.nw - before, 0.001 * 1.75 * 1.5, 1e-5, "drunk: faster still")
drunk = 0

-- 5. withdrawal: irritability up to Angry, hungrier, sleeping badly
s._st.nw = 0.51; H(s).nicLastW = 0.51
mins(60)
near(s._st.anger, 0.6, 1e-9, "full withdrawal: irritability 0.6")
assert(s._st.hunger > 0.01, "hungrier")
near(DanTraits_NicotineWithdrawal(s), 1, 1e-9, "withdrawal read by others")
near(DanTraits_RunHooks("sleepWake", 1, s, H(s)), 2, 1e-9, "light sleep")
near(DanTraits_RunHooks("nightQuality", 1, s, H(s)), 0.8, 1e-9, "poor night")
s._asleep = true; s._st.anger = 0; minute(); s._asleep = false
assert(s._st.anger == 0, "no irritability asleep")

-- 6. relief is the craving answered: a lot in full withdrawal, next to nothing chain-smoked
s._st.stress, s._st.unhappy = 0.5, 50
smoke(s, nil, vanillaSmoker)
near(s._st.stress, 0.45 - 0.1, 1e-9, "full craving: stress relief")
near(s._st.unhappy, 40, 1e-9, "full craving: mood relief")
assert(H(s).nicLastW == 0, "next craving starts from zero")
smoke(s, nil, vanillaSmoker)
near(s._st.stress, 0.30, 1e-9, "chain-smoked: vanilla's bit only")
near(s._st.unhappy, 40, 1e-9, "chain-smoked: no lift")
near(DanTraits_RunHooks("sleepWake", 1, s, H(s)), 1.5, 1e-9, "a cigarette before bed keeps you up")

-- 7. withdrawal peaks three days, then its ceiling winds down; three weeks cures
H(s).nicDryHours = 300; s._st.nw = 0.51; H(s).nicLastW = 0.51
minute()
near(s._st.nw, 0.51 * (1 - 0.75 * (300 + 1 / 60 - 72) / 432), 1e-4, "winding down")
H(s).nicDryHours = 503.9; mins(10)
assert(not s._traits["base:smoker"] and H(s).nicEx and s._st.nw == 0 and H(s).nicMeter == 0, "three weeks: cured")
assert(halo[#halo] == "+UI_DanTraits_SmokerCured", "cured notice")

-- 8. an ex-smoker: a bad moment brings a craving
s._st.stress = 0.6; s._st.anger = 0; minute()
assert(halo[#halo] == "UI_DanTraits_SmokerCue", "cue notice")
mins(30); assert(s._st.anger > 0.15 and s._st.anger <= 0.2, "cue: irritable")
local n = #halo; mins(60); assert(#halo == n, "one notice per cue")

-- 9. relapse: the first smoke of a session is a coin flip; a miss still hooks twice as fast
nextRoll = 999999
local m0 = H(s).nicMeter
smoke(s, nil, vanillaNonSmoker)
assert(not s._traits["base:smoker"], "lucky")
near(H(s).nicMeter - m0, 0.05, 1e-9, "kindling: double gain")
nextRoll = 0; smoke(s, nil, vanillaNonSmoker)
assert(not s._traits["base:smoker"], "same session: no second roll")
H(s).nicDryHours = 13; smoke(s, nil, vanillaNonSmoker); nextRoll = 999999
assert(s._traits["base:smoker"] and halo[#halo] == "UI_DanTraits_SmokerRelapse", "relapse")
near(H(s).nicMeter, 0.5, 1e-9, "back at 0.5")

-- 10. nicotine gum: most of the craving and the irritability gone, the clock still running
H(s).nicDryHours = 100; s._st.nw = 0.51; s._st.anger = 0.5
DanTraits_RunHooks("pill", nil, s, "NicotineGum")
near(s._st.nw, 0.51 * 0.4, 1e-9, "gum: craving")
near(s._st.anger, 0.2, 1e-9, "gum: irritability")
near(H(s).nicDryHours, 100, 1e-9, "gum: quitting clock untouched")
assert(halo[#halo] == "+UI_DanTraits_SmokerGum", "gum notice")

-- 11. a pack through the pill action; chewing tobacco spares the lungs
local lungs = H(s).nicLungs
DanTraits_RunHooks("prePill", nil, s, "CigarettePack", item("CigarettePack")); vanillaSmoker(s._st); handlers.OnTick()
near(H(s).nicLungs - lungs, 0.0004, 1e-9, "pack: a cigarette on the lungs")
assert(H(s).nicDryHours == 0, "pack: resets the clock")
lungs = H(s).nicLungs; H(s).nicDryHours = 5
DanTraits_RunHooks("prePill", nil, s, "TobaccoChewing", item("TobaccoChewing")); handlers.OnTick()
assert(H(s).nicLungs == lungs and H(s).nicDryHours == 0, "chewing: nicotine, no smoke")
smoke(s, "Cigar", vanillaSmoker); near(H(s).nicLungs - lungs, 0.0012, 1e-9, "a cigar is three")

-- 12. the lungs heal once the smoking stops, slowly
local l = makePlayer(); current = l
l._md.DanTraits = { nicMeter = 0, nicLungs = 0.5, nicSmokeHours = 0, nicEx = true, nicExHours = 99999 }
mins(60 * 23); near(H(l).nicLungs, 0.5, 1e-9, "no healing within a day")
mins(60 * 25); assert(H(l).nicLungs < 0.5 and H(l).nicLungs > 0.49, "healing")
-- endurance comes back slower
l._st.endurance = 0.5; DanTraits_updateSmokerFrame(l); l._st.endurance = 0.6; DanTraits_updateSmokerFrame(l)
near(l._st.endurance, 0.5 + 0.1 * (1 - 0.3 * H(l).nicLungs), 1e-9, "endurance recovery cut")

-- 13. the cough: worse lungs, a stronger habit, exertion and mornings
local c = makePlayer({ traits = { "base:smoker" } }); current = c
c._md.DanTraits = { nicInit = true, nicMeter = 1, nicLungs = 1, nicDryHours = 0 }
nextRoll = 5000                      -- a 0.5 % roll: beats 0.4 %/min resting, not 1.6 % exerted
H(c).nicLastW = 0; mins(5); assert(c._coughs == 0, "resting: no cough on this roll")
c._running = true; minute(); c._running = false
assert(c._coughs == 1, "exerted: cough")
minute(); c._running = true; minute(); c._running = false
assert(c._coughs == 1, "three minutes between coughs")
c._asleep = true; mins(90); c._asleep = false
assert(c._coughs == 1, "no cough asleep")
mins(3); assert(c._coughs == 2, "morning cough")
nextRoll = 999999

-- 14. caffeine: smoking speeds its clearance, and it wears off in days
local k = makePlayer(); current = k
for _ = 1, 10 do smoke(k, nil, vanillaNonSmoker) end
near(DanTraits_RunHooks("caffeineClearance", 1, k), 2, 1e-9, "ten cigarettes: twice as fast")
mins(39 * 60)
near(DanTraits_RunHooks("caffeineClearance", 1, k), 1.5, 1e-3, "39 h later: halfway back")
local z = makePlayer(); current = z
assert(DanTraits_RunHooks("caffeineClearance", 1, z) == 1, "never smoked: unchanged")
minute(); assert(H(z) == nil or H(z).nicMeter == nil, "never smoked: nothing stored")

print("test_smoker: all passed")
