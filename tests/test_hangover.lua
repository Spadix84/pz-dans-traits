-- Offline test for DanTraits_Hangover.lua: load builds while drunk, the
-- hangover waits for waking, lasts at least six hours after it, fades,
-- pauses for a drink, and lowers the night's sleep quality.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = { INTOXICATION = { getMaximumValue = function() return 100 end }, STRESS = "stress", PAIN = "pain", UNHAPPINESS = "unhappy", FATIGUE = "fatigue", THIRST = "thirst", FOOD_SICKNESS = "foodsick" }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = { dependent = "dependent" }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
MF = nil

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Dependent", "DanTraits_Hangover" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.EveryOneMinute and handlers.EveryTenMinutes, "hooks in place")

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or {}) do traits[t] = true end
  local st = { stress = 0, pain = 0, unhappy = 0, fatigue = 0, thirst = 0, foodsick = 0, intox = 0 }
  local md = {}
  local p = { hasTrait = function(_, t) return traits[t] == true end, isDead = function() return false end,
    isAsleep = function(self) return self._asleep end, getModData = function() return md end,
    getStats = function() return { get = function(_, k) if k == CharacterStat.INTOXICATION then return st.intox end return st[k] end,
                                   set = function(_, k, v) st[k] = v end } end,
    getPainEffect = function(self) return self._meds or 0 end,
    _st = st, _md = md, _asleep = false }
  return p
end
local current
function getSpecificPlayer() return current end
local minute, ten = handlers.EveryOneMinute, handlers.EveryTenMinutes
local function H(p) return p._md.DanTraits end
local function near(a, b, eps, msg) assert(math.abs(a - b) <= eps, msg .. ": expected " .. b .. ", got " .. a) end

-- 1. a light buzz builds nothing; two hours at 60% intoxication builds one drunk-hour
local p = makePlayer(); current = p
p._st.intox = 15; for _ = 1, 60 do minute() end
assert(H(p).hoLoad == 0, "under the buzz line: no load")
p._st.intox = 60; for _ = 1, 120 do minute() end
near(H(p).hoLoad, 1.0, 1e-6, "(0.6-0.2)/0.8 per hour x 2 h")
assert(not H(p).hoActive, "still drunk: no hangover yet")

-- 2. sobering up while asleep: pending; waking starts it, 6 h + 6 h x severity (1/3)
p._asleep = true; p._st.intox = 0; minute()
assert(H(p).hoPending and not H(p).hoActive, "sobered up asleep: waits for waking")
near(H(p).hoSeverity, 1 / 3, 1e-6, "severity = load / 3")
assert(H(p).hoLoad == 0, "load spent")
p._asleep = false; minute()
assert(H(p).hoActive and not H(p).hoPending, "awake: hangover starts")
near(H(p).hoHoursLeft, 8 - 1 / 60, 1e-6, "6 + 6/3 hours, one minute run")
assert(halo[#halo] == "UI_DanTraits_Hangover1", "notice")

-- 3. symptoms: pain and mood floors ramp at 1 a minute toward severity x strength; thirst creeps
for _ = 1, 20 do minute() end
near(p._st.pain, 35 / 3, 1.0, "headache floor ~11.7")
near(p._st.unhappy, 25 / 3, 1.0, "mood floor ~8.3")
assert(p._st.thirst > 0 and p._st.fatigue > 0, "thirst and fatigue creep")
assert(p._st.foodsick == 0, "mild: no nausea")
-- painkillers: the pain floor is not enforced while they work
p._st.pain = 0; p._meds = 1; minute(); assert(p._st.pain == 0, "painkillers: no headache floor"); p._meds = 0

-- 4. hair of the dog: a drink hides symptoms and stops the clock, and builds toward the next one
local left = H(p).hoHoursLeft
p._st.intox = 50; p._st.pain = 0; for _ = 1, 30 do minute() end
assert(H(p).hoHoursLeft == left, "clock paused while drinking")
assert(p._st.pain == 0, "no headache while drunk")
assert(H(p).hoLoad > 0, "the next one is building")
p._st.intox = 0; minute()
assert(H(p).hoActive and H(p).hoLoad == 0 and math.abs(H(p).hoHoursLeft - (left - 1 / 60)) < 1e-9, "sobering with a small load (< 0.5): no new hangover, the old one just resumes")

-- 5. it ends after its time; the last two hours fade
local d = H(p); d.hoHoursLeft = 1.0; d.hoSeverity = 1.0; p._st.pain = 0
minute(); near(p._st.pain, 1, 1e-6, "ramping toward a faded floor (35 x 0.5)")
for _ = 1, 30 do minute() end; near(p._st.pain, 13.5, 1.0, "climbs at 1 a minute until it meets the falling floor (35 x (60-k)/120 at minute k: k = 13.5)")
for _ = 1, 40 do minute() end
assert(not H(p).hoActive and H(p).hoSeverity == 0, "over")
assert(halo[#halo] == "+UI_DanTraits_HangoverOver", "good news")

-- 6. sobering while awake starts it straight away; sleeping through part of it gives 6 h back on waking
local q = makePlayer(); current = q
q._st.intox = 100; for _ = 1, 180 do minute() end   -- 3 h blind drunk: load 3 -> severity 1
q._st.intox = 0; minute()
assert(H(q).hoActive, "started awake"); near(H(q).hoSeverity, 1, 1e-6, "full severity")
near(H(q).hoHoursLeft, 12 - 1 / 60, 1e-6, "12 hours")
for _ = 1, 8 * 60 do minute() end
q._asleep = true; for _ = 1, 60 do minute() end   -- clock stops asleep
near(H(q).hoHoursLeft, 4 - 1 / 60, 1e-6, "paused during sleep")
q._asleep = false; minute()
near(H(q).hoHoursLeft, 6 - 1 / 60, 1e-6, "at least six hours after waking")
-- severe: nausea floor too
q._st.foodsick = 0; for _ = 1, 10 do minute() end; assert(q._st.foodsick > 0, "severe: queasy")

-- 7. tolerance blunts it: an Alcoholic at a full meter tolerance gets 70%
local t = makePlayer({ traits = { "dependent" } }); current = t
t._md.DanTraits = { depTolerance = 1 }
t._st.intox = 100; for _ = 1, 180 do minute() end; t._st.intox = 0; minute()
near(H(t).hoSeverity, 0.7, 1e-6, "severity x 0.7 at full tolerance")

-- 8. the night quality hook: pending or active hangover lowers it by 30% x severity; drinking counts by load
local n = makePlayer(); current = n
assert(DanTraits_RunHooks("nightQuality", 0.8, n, {}) == 0.8, "nothing: untouched")
near(DanTraits_RunHooks("nightQuality", 0.8, n, { hoPending = true, hoSeverity = 1 }), 0.56, 1e-9, "pending, full: x 0.7")
near(DanTraits_RunHooks("nightQuality", 0.8, n, { hoDrinking = true, hoLoad = 1.5 }), 0.8 * (1 - 0.3 * 0.5), 1e-9, "still drunk: by load")

print("test_hangover: all passed")
