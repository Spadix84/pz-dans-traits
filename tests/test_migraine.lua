-- Offline test for DanTraits_Migraine.lua: the chance curve, the aura, the
-- attack's symptoms, painkillers, light and sleep, and the refractory day.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = { INTOXICATION = "intox", STRESS = "stress", PAIN = "pain", UNHAPPINESS = "unhappy", FATIGUE = "fatigue", THIRST = "thirst", FOOD_SICKNESS = "foodsick" }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = { migraine = "migraine" }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
local rng = {}
function ZombRand(a, b) local v = table.remove(rng, 1); if v == nil then v = 0 end; return v end
local climate = { night = 1, rain = 0, cloud = 0 }
function getClimateManager() return { getNightStrength = function() return climate.night end, getRainIntensity = function() return climate.rain end, getCloudIntensity = function() return climate.cloud end } end
local debt, hangover = 0, 0
function DanTraits_SleepDebt() return debt end
function DanTraits_HangoverStrength() return hangover end
MF = nil

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Migraine" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.EveryOneMinute and handlers.EveryTenMinutes, "hooks in place")

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or { "migraine" }) do traits[t] = true end
  local st = { stress = o.stress or 0, pain = 0, unhappy = 0, fatigue = 0, thirst = o.thirst or 0, foodsick = 0 }
  local md = {}
  return { hasTrait = function(_, t) return traits[t] == true end, isDead = function() return false end,
    isAsleep = function(self) return self._asleep end, isOutside = function(self) return self._outside end,
    getModData = function() return md end,
    getStats = function() return { get = function(_, k) return st[k] end, set = function(_, k, v) st[k] = v end } end,
    getPainEffect = function(self) return self._meds or 0 end,
    _st = st, _md = md, _asleep = false, _outside = false }
end
local current
function getSpecificPlayer() return current end
local minute, ten = handlers.EveryOneMinute, handlers.EveryTenMinutes
local function M(p) return p._md.DanTraits end
local function near(a, b, eps, msg) assert(math.abs(a - b) <= eps, msg .. ": expected " .. b .. ", got " .. a) end

-- 1. the chance: 0.3% calm; sleep debt, thirst, stress, hangover and bright daylight outdoors add
local p = makePlayer(); current = p
near(DanTraits_MigraineChance(p), 0.3, 1e-9, "base")
debt = 1; near(DanTraits_MigraineChance(p), 2.8, 1e-9, "full sleep debt +2.5"); debt = 0
p._st.thirst = 0.65; near(DanTraits_MigraineChance(p), 1.3, 1e-9, "half thirst past 30% +1"); p._st.thirst = 0
p._st.stress = 1; near(DanTraits_MigraineChance(p), 2.3, 1e-9, "full stress +2"); p._st.stress = 0
hangover = 0.5; near(DanTraits_MigraineChance(p), 1.3, 1e-9, "half a hangover +1"); hangover = 0
p._outside = true; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "outside at night: nothing")
climate.night = 0; near(DanTraits_MigraineChance(p), 1.8, 1e-9, "bright day outdoors +1.5")
climate.cloud = 0.8; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "overcast: no glare"); climate.cloud = 0
climate.rain = 0.5; near(DanTraits_MigraineChance(p), 0.3, 1e-9, "rain: no glare"); climate.rain = 0
p._outside = false; climate.night = 1

-- 2. no roll inside the 24 h refractory window from creation; then a roll that misses, then one that hits: aura first
local q = makePlayer(); current = q
q._md.DanTraits = { migSinceEnd = 0 }
rng = {}; for _ = 1, 6 * 24 do ten() end
assert(not M(q).migAuraLeft and not M(q).migActive, "no roll while refractory (a 0 roll would have hit)")
rng = { 9999 }; ten(); assert(not M(q).migAuraLeft, "roll above the chance: nothing")
rng = { 0, 50 }; ten()
assert(M(q).migAuraLeft and not M(q).migActive, "aura started")
near(M(q).migSeverity, 1.0, 1e-9, "severity 0.5 + 0.50")
assert(halo[#halo] == "UI_DanTraits_MigraineAura", "aura notice")
ten(); assert(M(q).migAuraLeft, "no second roll during an aura")

-- 3. twenty minutes later the attack: 3 + 3 x 1 = 6 hours; pain, nausea, mood floors ramp; stress creeps
for _ = 1, 20 do minute() end
assert(M(q).migActive and halo[#halo] == "UI_DanTraits_MigraineStart", "attack started")
near(M(q).migHoursLeft, 6, 1e-9, "six hours")
for _ = 1, 40 do minute() end
near(q._st.pain, 40, 1.0, "pain ramping toward 60 at 1 a minute (40 minutes in)")
near(q._st.foodsick, 30, 1.0, "nausea floor 30"); near(q._st.unhappy, 15, 1.0, "mood floor 15")
assert(q._st.stress > 0, "stress creeps")
near(M(q).migHoursLeft, 6 - 40 / 60, 1e-9, "clock at full rate")

-- 4. daylight outdoors: half-speed recovery and more pain; painkillers hold the floor off and, once, cut the time by 40%
q._outside = true; climate.night = 0
local before = M(q).migHoursLeft
q._st.pain = 0; for _ = 1, 10 do minute() end
near(M(q).migHoursLeft, before - 5 / 60, 1e-9, "half rate in the glare")
assert(q._st.pain == 10, "pain climbing toward 75 (60 + 15 glare)")
q._outside = false; climate.night = 1
before = M(q).migHoursLeft
q._meds = 1; q._st.pain = 0; minute()
near(M(q).migHoursLeft, before * 0.6 - 1 / 60, 1e-9, "painkillers: remaining time x 0.6")
assert(q._st.pain == 0, "no pain floor while they work")
before = M(q).migHoursLeft; minute(); near(M(q).migHoursLeft, before - 1 / 60, 1e-9, "the cut happens once")
q._meds = 0

-- 5. sleeping it off runs the clock at double speed; it ends, refractory starts, moodle cleared
q._asleep = true; q._st.pain = 0
before = M(q).migHoursLeft; for _ = 1, 30 do minute() end
near(M(q).migHoursLeft, before - 1, 1e-9, "double rate asleep"); assert(q._st.pain == 0, "no symptoms applied while asleep")
M(q).migHoursLeft = 1 / 60; q._asleep = false; minute()
assert(not M(q).migActive and M(q).migSinceEnd == 0 and halo[#halo] == "+UI_DanTraits_MigraineEnd", "over")
rng = { 0, 0 }; ten(); assert(not M(q).migAuraLeft, "refractory again")

-- 6. no trait: nothing
local n = makePlayer({ traits = {} }); current = n
rng = { 0, 0 }; n._md.DanTraits = { migSinceEnd = 99 }; ten(); minute()
assert(not M(n).migAuraLeft and not M(n).migActive, "no trait: untouched")

print("test_migraine: all passed")
