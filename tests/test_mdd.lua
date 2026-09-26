local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
BodyPartType = { Groin = "Groin", ForeArm_L=1, ForeArm_R=2, LowerLeg_L=3, LowerLeg_R=4, Hand_L=5, Hand_R=6, Torso_Upper=7 }
CharacterStat = { INTOXICATION = "intox", STRESS = "stress", PAIN = "pain", UNHAPPINESS = "unhappy", FATIGUE = "fatigue", PANIC = "panic", ENDURANCE = "endurance", FOOD_SICKNESS = "foodsick", WETNESS = { getMaximumValue = function() return 100 end } }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = { spiraling = "spiraling", arthritis = "arthritis" }
ArrayList = { new = function() return { add = function() end } end }
IsoFireManager = { explode = function() end }
function instanceof() return false end
ItemBodyLocation = { MASK = "mask", MASK_EYES = "maskeyes", MASK_FULL = "maskfull" }
function getWorld() return { getFreeEmitter = function() return { playSound = function() return 1 end, setPos = function() end } end } end
function getTexture() return "TEX" end
function getGameTime() return { getHour = function() return 12 end } end
local rng = {}
function ZombRand(a, b) local v = table.remove(rng, 1); if v == nil then v = 0 end; return v end
function getClimateManager() return { getAirTemperatureForCharacter = function() return 20 end } end
function getCell() return { getGridSquare = function() return { getObjects = function() return { size = function() return 0 end } end, getDeadBodys = function() return { size = function() return 0 end } end } end } end
function addSound() end
function isNight() return false end
DanTraitsTestCharge = false
FitnessExercises = { exercisesType = { squats = {}, pushups = {}, situps = {}, burpees = {} } }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
local pillsSwallowed = 0
ISTakePillAction = { complete = function(self) pillsSwallowed = pillsSwallowed + 1; self.character._depress = 6600; return true end }
DanTraitsTestEpisode = false

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Dependent", "DanTraits_MDD", "DanTraits_Brittle", "DanTraits_Arthritis", "DanTraits_Jinxed", "DanTraits_BadDay", "DanTraits_Hallucinations", "DanTraits_Asthma", "DanTraits_Gluten", "DanTraits_Vegetarian", "DanTraits_Diabetes" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end

local function makePlayer(o)
  o = o or {}
  local st = { pain = o.pain or 0, stress = o.stress or 0, unhappy = o.unhappy or 0, fatigue = o.fatigue or 0, intox = o.intox or 0, panic = o.panic or 0, endurance = 1, foodsick = 0 }
  local md = {}
  local dropped = {}
  local p = { hasTrait = function(_, t) return t == (o.trait or "spiraling") end, isDead = function() return false end,
    isAsleep = function() return false end, getModData = function() return md end,
    getStats = function() return { get = function(_, k) return st[k] end, set = function(_, k, v) st[k] = v end } end,
    isOutside = function() return o.outside == true end,
    getTimeSinceLastSmoke = function() return o.smoke or 10 end,
    getFitness = function() return { getRegularity = function(_, name) return (o.regularity or {})[name] or 0 end } end,
    getDepressEffect = function(self) return self._depress or 0 end, setDepressEffect = function(self, v) self._depress = v end,
    getPrimaryHandItem = function() return { name = "bat" } end, getCurrentSquare = function() return { AddWorldInventoryItem = function(_, it) dropped[#dropped+1] = it end } end,
    removeFromHands = function() end, getInventory = function() return { Remove = function() end } end,
    _st = st, _md = md, _o = o, _dropped = dropped }
  return p
end
local current
function getSpecificPlayer() return current end
local minute, ten = handlers.EveryOneMinute, handlers.EveryTenMinutes

-- 1. pain and stress drag mood down all the time, episode or not
local p = makePlayer({ pain = 50, stress = 0.5 }); current = p
minute(); assert(math.abs(p._st.unhappy - 0.9) < 1e-9, "pain 50 -> +0.5, stress 0.5 -> +0.4 per minute, got " .. p._st.unhappy)
local calm = makePlayer({}); current = calm
minute(); assert(calm._st.unhappy == 0, "calm and unhurt: nothing")

-- 2. no episode inside the 48 h refractory window; then the roll happens and can start one
local q = makePlayer({}); current = q
q._md.DanTraits = { mddSinceEnd = 0 }
rng = {}; for _ = 1, 6 * 48 do ten() end
assert(not q._md.DanTraits.mddEpisode, "no roll during refractory (a 0 roll would have started one)")
rng = { 99999 }; ten(); assert(not q._md.DanTraits.mddEpisode, "roll above the chance: no episode")
rng = { 0, 60, 24 }; ten()
assert(q._md.DanTraits.mddEpisode and q._md.DanTraits.mddSeverity == 1.0 and q._md.DanTraits.mddHoursLeft == 48, "episode: severity 0.4+0.6, 24+24 hours")
assert(halo[#halo] == "UI_DanTraits_MddStart", "start notice")

-- 3. the floor: 75 at full severity, approached at 2 per minute; a book's relief is undone
for _ = 1, 40 do minute() end
assert(q._st.unhappy == 75, "held at the floor, got " .. q._st.unhappy)
q._st.unhappy = 10; minute(); assert(q._st.unhappy == 12, "reading dropped it, it climbs back 2 a minute")
q._st.unhappy = 90; minute(); assert(q._st.unhappy == 90, "worse than the floor is left alone")

-- 4. relief: drink 20, cigarette 10 (for 2 h), comfort food 10 (3 h), exercise up to 15, outdoors up to 15
q._st.unhappy = 0
q._st.intox = 0.5; for _ = 1, 40 do minute() end; assert(q._st.unhappy == 55, "drunk: floor 75-20, got " .. q._st.unhappy); q._st.intox = 0
q._o.smoke = 10; minute(); q._o.smoke = 0; minute()   -- the timer reset marks a cigarette
q._st.unhappy = 0; for _ = 1, 40 do minute() end; assert(q._st.unhappy == 65, "after a cigarette: 75-10, got " .. q._st.unhappy)
for _ = 1, 120 do minute() end; assert(q._st.unhappy == 75, "two hours later the cigarette has worn off")
DanTraits_MddOnEat(q, { getUnhappyChange = function() return -10 end })
q._st.unhappy = 0; for _ = 1, 40 do minute() end; assert(q._st.unhappy == 65, "comfort food: 75-10")
DanTraits_MddOnEat(q, { getUnhappyChange = function() return 5 end })
assert(q._md.DanTraits.mddFoodTimer < 180, "a joyless meal does not refresh it")
q._md.DanTraits.mddFoodTimer = 0
q._o.regularity = { squats = 100, pushups = 100, situps = 100, burpees = 0 }
assert(math.abs(DanTraits_MddRegularity(q) - 1) < 1e-9, "top three exercises count")
q._st.unhappy = 0; for _ = 1, 40 do minute() end; assert(q._st.unhappy == 60, "regular exercise: 75-15, got " .. q._st.unhappy)
q._o.regularity = {}
q._md.DanTraits.mddOutside = 240
q._st.unhappy = 0; minute(); minute(); assert(q._st.unhappy >= 2 and q._st.unhappy <= 4, "climbing")
for _ = 1, 40 do minute() end; assert(math.abs(q._st.unhappy - (75 - 15 * q._md.DanTraits.mddOutside / 240)) < 0.5, "outdoors: about 75-15, got " .. q._st.unhappy)
q._md.DanTraits.mddOutside = 0

-- 5. outdoors is a rolling day: a minute outside counts one, and fades
local o = makePlayer({ outside = true }); current = o
for _ = 1, 60 do minute() end
assert(o._md.DanTraits.mddOutside > 58 and o._md.DanTraits.mddOutside < 60, "an hour outside is about 60 minutes of credit")
o._o.outside = false; for _ = 1, 1440 do minute() end
assert(o._md.DanTraits.mddOutside < 25, "a day indoors fades most of it")

-- 6. the episode runs its hours down, faster with healthy habits, drinking deepens it, then ends with a notice
current = q; q._md.DanTraits.mddHoursLeft = 1; q._md.DanTraits.mddSeverity = 0.5
q._st.intox = 0.5; ten(); assert(math.abs(q._md.DanTraits.mddSeverity - 0.51) < 1e-9, "drunk: severity +0.01 per 10 min"); q._st.intox = 0
assert(math.abs(q._md.DanTraits.mddHoursLeft - (1 - 1/6)) < 1e-9, "10 minutes off with no habits")
q._o.regularity = { squats = 100, pushups = 100, situps = 100 }; q._md.DanTraits.mddOutside = 240
ten(); assert(math.abs(q._md.DanTraits.mddHoursLeft - (1 - 1/6 - 2/6)) < 1e-9, "full habits: 20 minutes off per tick")
q._md.DanTraits.mddHoursLeft = 0.1; ten()
assert(not q._md.DanTraits.mddEpisode and q._md.DanTraits.mddSinceEnd == 0 and halo[#halo] == "+UI_DanTraits_MddEnd", "episode over, refractory restarts")

-- 7. onset chance scales with stress, pain, fatigue and being shut in
local stressed = makePlayer({ stress = 1, pain = 100, fatigue = 1 }); current = stressed
stressed._md.DanTraits = { mddSinceEnd = 100, mddOutside = 0 }
-- chance = 0.0014 x 3 x 2.5 x 2 x 2 = 0.042 -> 4200 of 100000
rng = { 4199 }; ten(); assert(stressed._md.DanTraits.mddEpisode, "4199 < 4200 starts an episode under maximum pressure")
local fine = makePlayer({}); current = fine; fine._md.DanTraits = { mddSinceEnd = 100, mddOutside = 300 }
rng = { 141 }; ten(); assert(not fine._md.DanTraits.mddEpisode, "141 >= 140: calm life, roll misses")
rng = { 139 }; ten(); assert(fine._md.DanTraits.mddEpisode, "139 < 140 still can")

-- 8. Fumbler: 1% base, up to +6 panic, +6 pain, +5 fatigue; ZombRand(1000) < chance x 10 drops the weapon
local f = makePlayer({ trait = "arthritis" }); current = f
assert(math.abs(DanTraits_FumbleChance(f) - 1) < 1e-9, "calm: 1%")
rng = { 9 }; handlers.OnWeaponSwing(f, {}); assert(#f._dropped == 1, "9 < 10: dropped")
rng = { 10 }; handlers.OnWeaponSwing(f, {}); assert(#f._dropped == 1, "10 >= 10: kept")
f._st.panic = 100; f._st.pain = 100; f._st.fatigue = 1
assert(math.abs(DanTraits_FumbleChance(f) - 18) < 1e-9, "worst case 18%")
rng = { 179 }; handlers.OnWeaponSwing(f, {}); assert(#f._dropped == 2, "179 < 180: dropped")
rng = { 180 }; handlers.OnWeaponSwing(f, {}); assert(#f._dropped == 2, "180: kept")
-- 9. antidepressants: a pill is a day of coverage, the vanilla lift is cancelled, benefit builds over 14 days
local m = makePlayer({}); current = m
local pill = setmetatable({ character = m, item = { getType = function() return "PillsAntiDep" end } }, { __index = ISTakePillAction })
pill:complete(); assert(pillsSwallowed == 1 and m._depress == 0, "swallowed, vanilla effect cancelled")
assert(m._md.DanTraits.mddMedDays == 1, "one day of coverage")
pill:complete(); pill:complete(); pill:complete(); assert(m._md.DanTraits.mddMedDays == 3, "capped at three days ahead")
m._st.intox = 0.5; m._md.DanTraits.mddMedDays = 0; pill:complete(); assert(m._md.DanTraits.mddMedDays == 0.5, "drunk: half a dose"); m._st.intox = 0
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
rng = { 57 }; ten(); assert(not m._md.DanTraits.mddEpisode, "calm chance 140 x 0.4 = 56: a 57 misses")
m._md.DanTraits.mddEpisode = false
rng = { 55 }; ten(); assert(m._md.DanTraits.mddEpisode, "55 < 56 starts one")
m._md.DanTraits.mddEpisode = false

-- 10. side effects in the first three days; lapsing after a week costs three rough days
local n = makePlayer({}); current = n; n._md.DanTraits = { mddSinceEnd = 0 }   -- inside the refractory window: no episode rolls
local npill = setmetatable({ character = n, item = { getType = function() return "PillsAntiDep" end } }, { __index = ISTakePillAction })
npill:complete(); for _ = 1, 15 do minute() end
assert(n._st.foodsick == 15 and n._st.fatigue > 0, "early days: queasy to 15 and tired")
n._md.DanTraits.mddMedStreak = 5; n._st.foodsick = 0; minute(); assert(n._st.foodsick == 0, "after three days the side effects are gone")
n._md.DanTraits.mddMedDays = 0; n._md.DanTraits.mddMedStreak = 10
ten(); assert(n._md.DanTraits.mddWithdraw == 4320 and n._md.DanTraits.mddMedLapsed, "lapsed after 10 days: 3 days of discontinuation")
n._st.unhappy = 0; n._st.stress = 0; minute(); assert(n._st.unhappy >= 0.3 and n._st.unhappy < 0.31 and math.abs(n._st.stress - 0.001) < 1e-9, "discontinuation drags mood and stress (plus the new stress drag), got " .. n._st.unhappy)
for _ = 1, 143 do ten() end; assert(n._md.DanTraits.mddMedStreak < 10 - 2.9, "streak drains 3 days per day off them, now " .. n._md.DanTraits.mddMedStreak)
local short = makePlayer({}); current = short; short._md.DanTraits = { mddMedDays = 0, mddMedStreak = 3, mddSinceEnd = 0 }
ten(); assert((short._md.DanTraits.mddWithdraw or 0) == 0, "a three-day streak lapsing does not cause discontinuation")
print("ALL OK")
