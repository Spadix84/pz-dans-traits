-- Offline test for DanTraits_Dependent.lua (Alcoholic): the alcoholism meter
-- fills with habitual drinking and grants the trait, withdrawal scales with
-- it, a sober month cures it, and a drink after that can bring it back.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = { INTOXICATION = { getMaximumValue = function() return 100 end }, STRESS = "stress", PAIN = "pain", UNHAPPINESS = "unhappy", FOOD_SICKNESS = "sick", PANIC = "panic", FATIGUE = "fatigue" }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = { dependent = "dependent" }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
local rolls, nextRoll = 0, 9999
function ZombRand() rolls = rolls + 1; return nextRoll end

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Dependent" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or {}) do traits[t] = true end
  local st = { stress = 0, pain = 0, unhappy = 0, sick = 0, panic = 0, fatigue = 0, intox = 0 }
  local md = {}
  return { hasTrait = function(_, t) return traits[t] == true end, isDead = function() return false end,
    getModData = function() return md end,
    getCharacterTraits = function() return { add = function(_, e) traits[e] = true end, remove = function(_, e) traits[e] = nil end } end,
    getStats = function() return { get = function(_, k) if k == CharacterStat.INTOXICATION then return st.intox end return st[k] end,
                                   set = function(_, k, v) st[k] = v end } end,
    setBumpType = function(self, t) self._bump = t end, setVariable = function(self, k, v) self._vars[k] = v end,
    isAsleep = function(self) return self._asleep end,
    _st = st, _md = md, _traits = traits, _vars = {} }
end
local current
function getSpecificPlayer() return current end
local ten = handlers.EveryTenMinutes
local function H(p) return p._md.DanTraits end
local function near(a, b, eps, msg) assert(math.abs(a - b) <= eps, msg .. ": expected " .. b .. ", got " .. a) end
local function run(p, intox, hours) p._st.intox = intox; for _ = 1, math.floor(hours * 6 + 0.5) do ten() end end

-- 1. one blind-drunk night is not a habit: the meter fills at most 0.08 a day
local p = makePlayer(); current = p
run(p, 100, 10)
near(H(p).depTolerance, 0.08, 1e-9, "daily cap")
assert(not p._traits.dependent, "one night: no trait")

-- 2. a heavy night once a week never adds up
for _ = 1, 8 do run(p, 0, 14 + 6 * 24); run(p, 100, 10) end
assert(not p._traits.dependent and H(p).depTolerance < 0.1, "weekly binge: no trait")

-- 3. drinking hard every day does: 5 h at 50%, 19 h sober, about 0.054 a day net
local q = makePlayer(); current = q
local days = 0
while not q._traits.dependent and days < 30 do run(q, 50, 5); run(q, 0, 19); days = days + 1 end
assert(days == 6, "gained on day 6, got day " .. days)
assert(halo[#halo] == "UI_DanTraits_AlcoholicGained", "notice")

-- 4. withdrawal scales with the meter: at 0.5 craving from 18 h, stress 0.01 per ten minutes
local w = makePlayer({ traits = { "dependent" } }); current = w
ten()
near(H(w).depTolerance, 0.5, 1e-3, "taken at creation: starts at 0.5")
run(w, 0, 17.5); assert(not H(w).withdrawing, "not yet at 17.5 h")
run(w, 0, 1); assert(H(w).withdrawing, "craving by 18.5 h")
assert(halo[#halo] == "UI_DanTraits_DependentCraving", "craving notice")
local s = w._st.stress; ten(); near(w._st.stress - s, 0.02 * H(w).depTolerance, 1e-9, "stress 0.02 x meter")
assert(w._st.unhappy > 0, "low mood")
assert(w._st.pain == 0, "no pain yet")
run(w, 0, 20); assert(w._st.pain > 0, "pain by 38 h (48 x 0.76)")
assert(halo[#halo] == "UI_DanTraits_AlcoholicShakes" and H(w).alcStage == 2, "the shakes")
assert(w._st.sick > 0 and w._st.sick <= 40 * 0.5, "nausea floor 40 x w")
near(DanTraits_RunHooks("swingDrop", 1, w), 1 + 10 * H(w).alcW, 1e-9, "shaking hands: swing drop chance")
near(DanTraits_RunHooks("sleepWake", 1, w, H(w)), 1 + 2 * H(w).alcW, 1e-9, "light sleep")
near(DanTraits_RunHooks("nightQuality", 1, w, H(w)), 1 - 0.4 * H(w).alcW, 1e-9, "poor sleep")
run(w, 0, 60); assert(H(w).alcStage == 2, "meter under 0.6: never delirium")

-- 4b. a heavy drinker reaches delirium: seizures and hallucinations
local dt = makePlayer({ traits = { "dependent" } }); current = dt
dt._md.DanTraits = { alcInit = true, depTolerance = 1 }
run(dt, 0, 37.5); assert(H(dt).alcStage == 2, "37.5 h: shakes only")
run(dt, 0, 1); assert(H(dt).alcStage == 3 and halo[#halo] == "UI_DanTraits_AlcoholicDelirium", "delirium by 38.5 h (72 x 0.525, the meter slipping)")
nextRoll = 0; local pain = dt._st.pain; ten(); nextRoll = 9999
assert(dt._bump == "stagger" and dt._vars.BumpFall == true, "seizure: knocked down")
assert(dt._st.pain >= math.min(100, pain + 25) and dt._st.panic >= 40 and halo[#halo] == "UI_DanTraits_AlcoholicSeizure", "seizure: hurt and scared")
dt._asleep = true; dt._bump = nil; nextRoll = 0; ten(); nextRoll = 9999; dt._asleep = false
assert(dt._bump == nil, "no seizure asleep")
-- the acute phase holds five days, then fades to a fifth by day ten
local wPeak = H(dt).alcW
run(dt, 0, 240 - H(dt).dryHours)
near(H(dt).alcW, H(dt).depTolerance * 0.2, 1e-3, "lingering at a fifth")
assert(H(dt).alcW < wPeak * 0.25, "well down from the peak")
local ok = pcall(function() nextRoll = 0; ten() end); nextRoll = 9999; assert(ok, "no hallucination set loaded: nothing breaks")
run(dt, 50, 1 / 6); assert(not H(dt).withdrawing and H(dt).alcStage == 0 and H(dt).alcShakes == 0, "a drink ends it all")
assert(DanTraits_RunHooks("swingDrop", 1, dt) == 1, "steady hands again")

-- 5. a full meter needs a real drink
current = w; H(w).depTolerance = 1
run(w, 20, 1 / 6); assert(H(w).dryHours > 0, "20% is not a drink at a full meter (needs > 45%)")
run(w, 50, 1 / 6); assert(H(w).dryHours == 0 and not H(w).withdrawing, "50% is")
assert(halo[#halo] == "UI_DanTraits_DependentSated", "sated notice")

-- 6. a sober month cures it; the meter drains to nothing along the way
run(w, 0, 719)
assert(w._traits.dependent, "719 h: still an alcoholic")
run(w, 0, 1)
assert(not w._traits.dependent and H(w).alcEx and H(w).depTolerance == 0, "30 days: cured")
assert(halo[#halo] == "+UI_DanTraits_AlcoholicCured", "good news")

-- 7. relapse: one roll per drinking session, a win brings the trait back at 0.5
nextRoll = 99; rolls = 0
run(w, 5, 1)
assert(rolls == 1 and not w._traits.dependent, "lucky: one roll for the session, no relapse")
run(w, 0, 1); nextRoll = 0
run(w, 5, 1 / 6)
assert(rolls == 2 and w._traits.dependent, "next session: relapse")
near(H(w).depTolerance, 0.5, 1e-3, "back at 0.5")
assert(halo[#halo] == "UI_DanTraits_AlcoholicRelapse", "relapse notice")

-- 8. hangover tolerance only for Alcoholics
assert(DanTraits_AlcoholTolerance(q) > 0 and DanTraits_AlcoholTolerance(p) == 0, "tolerance read")

print("test_alcoholic: all passed")
