-- Offline test for DanTraits_AgeTraits.lua, the traits only one age can take: which
-- bands may take each (DanTraits_AgeOnly); Green's lost levels at spawn; the experience
-- traits (Quick Study, Old Hand, Set in Their Ways); Reading Glasses (the pair at the
-- start, slower reading and no reading in dim light without glasses on); Bad Back and
-- Bad Knees (the load, the notices, the pain); Old Injury (the part, the floor, the flare).
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }

local PROFS = { carpenter = { Woodwork = 4, Carving = 1, Masonry = 1 }, unemployed = nil }
CharacterProfessionDefinition = { getCharacterProfessionDefinition = function(prof)
  return { getXpBoosts = function() return PROFS[prof] end }
end }
function transformIntoKahluaTable(t) return t end
ISReadABook = { getDuration = function(self) return self.time or 400 end, isValid = function() return true end }
MoodleType.HEAVY_LOAD = "heavy"
local fence, window = { name = "fence" }, { name = "window" }
ClimbOverFenceState = { instance = function() return fence end }
ClimbThroughWindowState = { instance = function() return window end }
BodyPartType.Torso_Lower = "Torso_Lower"
BodyPartType.getDisplayName = function(kind) return "the " .. kind end

H.load("Age", "Arthritis", "AgeTraits")
H.expectHooks("OnCreatePlayer", "AddXP")
H.expectEvery("minute", "AgeTraits")
H.expectEvery("frame", "AgeTraits")

local function newPart(name)
  local part = { _pain = 0, _stiff = 0 }
  function part:getType() return name end
  function part:getAdditionalPain() return self._pain end
  function part:setAdditionalPain(v) self._pain = v end
  function part:getStiffness() return self._stiff end
  function part:setStiffness(v) self._stiff = v end
  function part:getScratchTime() return 0 end
  function part:getCutTime() return 0 end
  return part
end
local PART_NAMES = { "Torso_Lower", "LowerLeg_L", "LowerLeg_R", "UpperLeg_L", "UpperLeg_R", "ForeArm_L", "ForeArm_R" }

local newPlayer = H.factory(nil, function(p, o)
  local levels = {}
  for k, v in pairs(PROFS[o.prof or "carpenter"] or {}) do levels[k] = v end
  for k, v in pairs(o.levels or {}) do levels[k] = v end
  p._levels, p._xpTotal, p._xpCalls, p._xpSet = levels, o.xp or {}, {}, {}
  p.getDescriptor = function() return { getCharacterProfession = function() return o.prof or "carpenter" end } end
  p.getPerkLevel = function(_, perk) return levels[perk] or 0 end
  p.LevelPerk = function(_, perk) levels[perk] = (levels[perk] or 0) + 1 end
  p.LoseLevel = function(_, perk) levels[perk] = (levels[perk] or 0) - 1 end
  p.getXp = function()
    return {
      setXPToLevel = function(_, perk, lvl) p._xpSet[perk] = lvl end,
      getXP = function(_, perk) return p._xpTotal[perk] or 0 end,
      AddXP = function(_, perk, amount)
        p._xpCalls[#p._xpCalls + 1] = { perk = perk, amount = amount }
        H.fire("AddXP", p, perk, amount)   -- the game fires the event even with callLua false
      end,
    }
  end
  p.getCurrentState = function() return p._state end
end)
local function body(traits, o)
  o = o or {}
  o.traits = traits
  local parts, byName = {}, {}
  for _, name in ipairs(PART_NAMES) do parts[#parts + 1] = newPart(name); byName[name] = parts[#parts] end
  o.parts = parts
  o.moodles = o.moodles or {}
  local p = newPlayer(o)
  H.current = p
  return p, byName
end

-- 1. who may take what
local function bands(key) local t = {}; for _, b in ipairs({ 20, 30, 40, 50 }) do if DanTraits_AgeOnly[key][b] then t[#t + 1] = b end end return table.concat(t, ",") end
assert(bands("green") == "20" and bands("quickstudy") == "20", "the 20s traits")
assert(bands("bottomlesspit") == "20", "the second 20s trait")
assert(DanTraits_AgeOnly.bouncesback == nil, "Bounces Back is folded into Thick Skull: no age band")
assert(bands("paceyourself") == "40" and bands("settled") == "40", "the 40s' own")
assert(bands("seenitall") == "50" and bands("castiron") == "50" and bands("oldbones") == "50", "the 50s' own")
assert(bands("delicatestomach") == "40,50", "Delicate Stomach: the 40s and 50s")
assert(bands("readingglasses") == "40,50" and bands("badback") == "40,50" and bands("badknees") == "40,50" and bands("oldhand") == "40,50", "the 40s and 50s traits")
assert(bands("oldinjury") == "50" and bands("setinways") == "50", "the 50s traits")

-- 2. Green: every skill the occupation boosts a level lower at spawn, never under 0
local g = newPlayer({ traits = { "age20s", "green" } }); H.fire("OnCreatePlayer", 0, g)
assert(g._levels.Woodwork == 3 and g._levels.Carving == 0 and g._levels.Masonry == 0, "Green carpenter: 4/1/1 -> 3/0/0")
assert(g._xpSet.Woodwork == 3 and g._xpSet.Carving == 0, "XP put at the new levels")
H.fire("OnCreatePlayer", 0, g); assert(g._levels.Woodwork == 3, "once only")
local lv = DanTraits_AgeLevels({ Woodwork = 4, Carving = 1, Fitness = 1 }, 20, false, nil, true)
assert(lv.Woodwork == -1 and lv.Carving == -1 and lv.Fitness == nil, "Green in the levels: -1 each, Fitness left alone")
lv = DanTraits_AgeLevels({ Woodwork = 4, Carving = 1 }, 20, false, 1, true)
assert(lv.Woodwork == nil and lv.Carving == -1, "against a sandbox level for the 20s: the main skill nets out")
lv = DanTraits_AgeLevels(nil, 20, false, nil, true)
local n = 0; for _ in pairs(lv) do n = n + 1 end
assert(n == 0, "Unemployed Green: no skills to lose")
local zero = newPlayer({ traits = { "age20s", "green" }, levels = { Carving = 0 } }); H.fire("OnCreatePlayer", 0, zero)
assert(zero._levels.Carving == 0, "a skill at 0 stays at 0")

-- 3. the experience traits
local function perk(name) return { name = name, getTotalXpForLevel = function(_, level) return level * 100 end } end
-- the harness names perks by plain strings: give those the one Perk method the code calls
string.getTotalXpForLevel = function(_, level) return level * 100 end
Perks.Fitness, Perks.Strength = perk("Fitness"), perk("Strength")
local xp = H.on("AddXP")
local function gain(p, what, amount) local before = #p._xpCalls; xp(p, what, amount); local c = p._xpCalls[#p._xpCalls]; return #p._xpCalls > before and c.amount or 0 end
-- Quick Study: under level 3 only
local q = newPlayer({ traits = { "quickstudy" }, levels = { Cooking = 2, Tailoring = 4, Woodwork = 5 } })
H.near(gain(q, "Cooking", 8), 3.2, 1e-9, "Quick Study: x1.4 under level 5")
H.near(gain(q, "Tailoring", 8), 3.2, 1e-9, "level 4 still counts")
assert(gain(q, "Woodwork", 8) == 0, "nothing at level 5 or above")
H.near(gain(q, "Farming", 4), 1.6, 1e-9, "a skill never touched counts as level 0")
-- Old Hand: every skill the occupation boosts (the main skill only until 2026-10-07)
local o = newPlayer({ traits = { "oldhand" } })
H.near(gain(o, "Woodwork", 8), 2, 1e-9, "Old Hand: the main skill a quarter faster")
H.near(gain(o, "Carving", 8), 2, 1e-9, "and the occupation's other skills too")
assert(gain(o, "Cooking", 8) == 0, "not skills outside the occupation")
assert(gain(o, Perks.Fitness, 8) == 0, "Fitness is age's business")
local idle = newPlayer({ traits = { "oldhand" }, prof = "unemployed" })
H.near(gain(idle, "Maintenance", 8), 2, 1e-9, "Unemployed Old Hand: Maintenance")
-- Set in Their Ways: outside the occupation, never under the level held
local s = newPlayer({ traits = { "setinways" }, xp = { Cooking = 500 } })
H.near(gain(s, "Cooking", 10), -1.5, 1e-9, "Set in Their Ways: 15% taken back outside the occupation")
assert(gain(s, "Woodwork", 10) == 0 and gain(s, "Carving", 10) == 0, "the occupation's own skills untouched")
assert(gain(s, Perks.Fitness, 10) == 0, "Fitness is age's business, not this trait's")
s._levels.Tailoring = 2; s._xpTotal.Tailoring = 200.5
H.near(gain(s, "Tailoring", 10), -0.5, 1e-9, "stops at the level's threshold")
-- together, and a plain character
local both = newPlayer({ traits = { "oldhand", "setinways" }, xp = { Cooking = 500 } })
H.near(gain(both, "Woodwork", 8), 2, 1e-9, "both: main skill faster")
H.near(gain(both, "Carving", 8), 2, 1e-9, "both: the other occupation skills faster")
H.near(gain(both, "Cooking", 100), -15, 1e-9, "both: outside slower")
assert(gain(newPlayer(), "Cooking", 8) == 0, "no trait: nothing")

-- 4. Reading Glasses: a pair at the start; slow and light-hungry without glasses on
local r = newPlayer({ traits = { "age40s", "readingglasses" } }); H.fire("OnCreatePlayer", 0, r)
assert(#r._inv == 1 and r._inv[1]._type == "Base.Glasses_Reading", "starts with a pair")
H.fire("OnCreatePlayer", 0, r); assert(#r._inv == 1, "one pair only")
local loaded = newPlayer({ traits = { "readingglasses" }, hours = 5 }); H.fire("OnCreatePlayer", 0, loaded)
assert(#loaded._inv == 0, "not for a character already in play")
local function reading(who, time) return setmetatable({ character = who, time = time }, { __index = ISReadABook }) end
r._light = 0.7
assert(reading(r, 400):getDuration() == 600, "no glasses on: half as long again")
assert(reading(newPlayer(), 400):getDuration() == 400, "no trait: vanilla's time")
assert(reading(r):isValid() == true, "a lit room: can read")
r._light = 0.3
H.clearHalo()
local action = reading(r)
assert(action:isValid() == false and action:isValid() == false, "dim: cannot read")
assert(#H.halo == 1 and H.halo[1] == "UI_DanTraits_GlassesTooDim", "told once per attempt")
for _, kind in ipairs({ "Base.Glasses_Reading", "Base.Glasses_Prescription_Sun", "Base.Glasses_Normal" }) do
  r._worn = { { type = kind, name = "glasses" } }
  assert(reading(r, 400):getDuration() == 400 and reading(r):isValid() == true, kind .. " on: reads as anyone")
end
r._worn = { { type = "Base.Glasses_Sun", name = "Sunglasses" } }
assert(reading(r, 400):getDuration() == 600 and DanTraits_NeedsGlasses(r), "sunglasses are not reading glasses")
r._worn = {}

-- 5. Bad Back: a heavy load builds it, rest eases it, the pain is in the lower back
local b, parts = body({ "badback" }, { moodles = { heavy = 2 } })
H.clearHalo()
H.mins(37)   -- 0.008 a minute: just short of 0.3
assert(#H.halo == 0, "nothing said yet")
H.mins(1); assert(H.halo[1] == "UI_DanTraits_BackAche", "the ache notice at 0.3")
H.near(b._md.DanTraits.bbLoad, 0.304, 1e-9, "load after 38 minutes at level 2")
assert(parts.Torso_Lower._pain > 0 and parts.Torso_Lower._pain <= 45 * 0.304 + 1e-9, "pain on the lower back, up to the load's share")
assert(parts.LowerLeg_L._pain == 0, "nowhere else")
b._moodles.heavy = 4
H.mins(25); assert(H.halo[2] == "UI_DanTraits_BackBad", "the bad notice at 0.7")
H.mins(100); H.near(b._md.DanTraits.bbLoad, 1, 1e-9, "capped at 1")
H.near(parts.Torso_Lower._pain, 45, 1e-9, "full pain at a full load")
b._moodles.heavy = 0
H.mins(125); H.near(b._md.DanTraits.bbLoad, 0.5, 1e-9, "eases 0.004 a minute with the load off")
b._asleep = true
H.mins(63); assert(b._md.DanTraits.bbLoad == nil and H.halo[#H.halo] == "+UI_DanTraits_BackEased", "twice as fast asleep, then gone with a good notice")
local plain = body({}, { moodles = { heavy = 4 } }); H.mins(60)
assert(plain._md.DanTraits.bbLoad == nil, "no trait: nothing")

-- 6. Bad Knees: running, sprinting and each climb
local k, legs = body({ "badknees" })
k._run = true; H.mins(10); H.near(k._md.DanTraits.bkLoad, 0.1, 1e-9, "running: 0.01 a minute")
k._run = false; k._sprint = true; H.clearHalo(); H.mins(5)
H.near(k._md.DanTraits.bkLoad, 0.3, 1e-9, "sprinting: 0.04 a minute")
assert(H.halo[1] == "UI_DanTraits_KneesAche", "the ache notice")
assert(legs.LowerLeg_L._pain > 0 and legs.LowerLeg_L._pain == legs.LowerLeg_R._pain and legs.Torso_Lower._pain == 0, "pain in both lower legs")
k._sprint = false
k._state = fence; H.frame(k); H.frame(k); H.frame(k)
H.near(k._md.DanTraits.bkLoad, 0.38, 1e-9, "a climb counts once, however many frames it lasts")
k._state = nil; H.frame(k); k._state = window; H.frame(k)
H.near(k._md.DanTraits.bkLoad, 0.46, 1e-9, "the next climb counts again")
k._state = nil; H.frame(k)
H.mins(92); assert(k._md.DanTraits.bkLoad == nil and H.halo[#H.halo] == "+UI_DanTraits_KneesEased", "eases 0.005 a minute, then settles")
local still = body({}); still._state = fence; H.frame(still)
assert(still._md.DanTraits.bkLoad == nil, "no trait: a climb is just a climb")

-- 7. Old Injury: one limb, told once; a floor of stiffness, more and sore in the cold
H.climate.temp = 20
H.rng = { 3 }
local i, limbs = body({ "oldinjury" })
H.clearHalo(); H.minute()
assert(i._md.DanTraits.oiPart == "UpperLeg_R", "the fourth of six parts, by the roll")
assert(H.halo[1] == "UI_DanTraits_OldInjuryPart:the UpperLeg_R" and #H.halo == 1, "told which, once")
assert(limbs.UpperLeg_R._stiff == 10 and limbs.UpperLeg_L._stiff == 0 and limbs.UpperLeg_R._pain == 0, "warm and dry: a floor of 10 on that part only, no pain")
H.minute(); assert(#H.halo == 1 and i._md.DanTraits.oiPart == "UpperLeg_R", "the part is kept")
H.climate.temp = 0
H.minute()
assert(H.halo[2] == "UI_DanTraits_OldInjuryFlare", "the cold: a flare notice")
assert(limbs.UpperLeg_R._stiff == 35 and limbs.UpperLeg_R._pain > 0, "stiff to 35 and sore")
H.mins(10); assert(#H.halo == 2 and limbs.UpperLeg_R._pain == 20, "no repeat notice; pain up to 20")
H.climate.temp = 20

-- 9. the second eight ------------------------------------------------------------
-- (Bounces Back moved to Thick Skull: test_positives.lua)
local plain9 = newPlayer()
local bb = newPlayer({ traits = { "bouncesback" } })
H.near(DanTraits_RunHooks("passOutMinutes", 10, bb), 10, 1e-9, "a leftover Bounces Back does nothing here")
-- Bottomless Pit: hunger x1.3, and the Hungry moodle costs mood from level 2
local bp = newPlayer({ traits = { "bottomlesspit" }, moodles = {} }); H.current = bp
H.near(DanTraits_RunHooks("hungerRise", 0.01, bp), 0.013, 1e-12, "hunger x1.3")
H.near(DanTraits_RunHooks("hungerRise", 0.01, plain9), 0.01, 1e-12, "others as is")
bp._moodles[MoodleType.HUNGRY] = 1; H.minute(); H.near(bp._st.unhappy, 0, 1e-9, "peckish: nothing")
bp._moodles[MoodleType.HUNGRY] = 2; H.minute(); H.near(bp._st.unhappy, 0.1, 1e-9, "Hungry: 0.1 a minute")
bp._moodles[MoodleType.HUNGRY] = 3; H.minute(); H.near(bp._st.unhappy, 0.3, 1e-9, "Very Hungry: 0.2")
bp._asleep = true; H.minute(); H.near(bp._st.unhappy, 0.3, 1e-9, "asleep: nothing"); bp._asleep = false
-- Seen It All: panic, Fear of Blood faints and filth stress
local si = newPlayer({ traits = { "seenitall" } })
H.near(DanTraits_RunHooks("panicRise", 10, si), 6, 1e-9, "panic builds x0.6")
H.near(DanTraits_RunHooks("fearFaint", 0.2, si), 0.1, 1e-9, "faints half as often")
H.near(DanTraits_RunHooks("filthStress", 0.002, si), 0.001, 1e-12, "filth weighs half")
H.near(DanTraits_RunHooks("panicRise", 10, plain9), 10, 1e-9, "others as is")
-- Pace Yourself: a tenth of what a swing or sprint spent comes back, and the pipeline is told
local py = newPlayer({ traits = { "paceyourself" } }); H.current = py
py._st.endurance = 1; H.frame(py)
py._st.endurance = 0.9; H.frame(py); H.near(py._st.endurance, 0.9, 1e-9, "a fall while idle: not a swing, nothing back")
py._st.endurance = 0.8; py._attacking = true; H.frame(py)
H.near(py._st.endurance, 0.81, 1e-9, "a fall while attacking: a tenth back")
H.near(py._md.DanTraits.deltaLast.enduranceRegen, 0.81, 1e-9, "the recovery pipeline is told, so the refund is not read as recovery")
py._attacking = false; py._sprint = true; py._st.endurance = 0.71; H.frame(py)
H.near(py._st.endurance, 0.72, 1e-9, "sprinting too")
py._sprint = false; py._st.endurance = 0.9; H.frame(py); H.near(py._st.endurance, 0.9, 1e-9, "a rise is left alone")
local notpy = newPlayer(); H.current = notpy
notpy._st.endurance = 1; H.frame(notpy); notpy._st.endurance = 0.8; notpy._attacking = true; H.frame(notpy)
H.near(notpy._st.endurance, 0.8, 1e-9, "others: nothing")
-- Settled: a bed in a house, the same bed as last time
local function bed(x, room)
  return { getSquare = function() return { getX = function() return x end, getY = function() return 0 end, getZ = function() return 0 end, getRoom = function() return room end } end }
end
local st = newPlayer({ traits = { "settled" } }); H.current = st
local sd = DanTraits_Data(st)
st._asleep = true; st._bed = bed(10, { name = "bedroom" }); H.minute()
assert(sd.stInHouse == true and sd.stNewBed == true and sd.stLastBed == "10,0,0", "first night: a house bed, and new")
H.near(DanTraits_RunHooks("nightQuality", 0.8, st, sd), 0.6, 1e-9, "the first night in a new bed scores 0.2 worse")
assert(sd.stNewBed == nil, "and the bed is known from then on")
st._asleep = false; H.minute(); st._asleep = true; H.minute()
assert(sd.stInHouse == true and not sd.stNewBed, "the same bed again: nothing new")
assert(DanTraits_RunHooks("nightQuality", 0.8, st, sd) == 0.8, "a known house bed: the night as it was")
st._asleep = false; H.minute(); st._bed = bed(20, nil); st._asleep = true; H.minute()
assert(sd.stInHouse == false, "a bed with no room (outdoors, a tent): not a house")
H.near(DanTraits_RunHooks("nightQuality", 0.8, st, sd), 0.6, 1e-9, "0.2 worse")
st._asleep = false; H.minute(); st._bed = nil; st._asleep = true; H.minute()
assert(sd.stInHouse == false, "the floor: not a house")
H.near(DanTraits_RunHooks("nightQuality", 0.8, st, sd), 0.6, 1e-9, "0.2 worse, every night")
assert(DanTraits_RunHooks("nightQuality", 0.8, plain9, DanTraits_Data(plain9)) == 0.8, "others as is")
st._asleep = false
-- Old Bones Know Rain: once a day from 6, tomorrow's weather
local ob = newPlayer({ traits = { "oldbones" } }); H.current = ob
H.hours = 24 * 5 + 5; H.climate.forecast = { nil, { "storm", 14 } }
H.minute(); assert(H.halo[#H.halo] ~= "UI_DanTraits_OldBonesRain", "before 6: not yet")
H.hours = 24 * 5 + 7; H.minute()
assert(H.halo[#H.halo] == "UI_DanTraits_OldBonesRain", "from 6: a storm tomorrow is felt today")
local said = #H.halo; H.hours = 24 * 5 + 12; H.minute(); assert(#H.halo == said, "once a day")
H.hours = 24 * 6 + 7; H.climate.forecast = { nil, { nil, 0, nil, -3 } }; H.minute()
assert(H.halo[#H.halo] == "UI_DanTraits_OldBonesCold", "a freezing night tomorrow")
H.hours = 24 * 7 + 7; H.climate.forecast = { nil, { nil, 0, nil, 12 } }; said = #H.halo; H.minute()
assert(#H.halo == said, "mild tomorrow: nothing to say")
H.climate.forecast = nil
-- Cast Iron: side effects half as often, the overdose line a pill higher
local ci = newPlayer({ traits = { "castiron" } })
H.near(DanTraits_RunHooks("medSideChance", 0.1, ci), 0.05, 1e-12, "side effects x0.5")
H.near(DanTraits_RunHooks("medOverAt", 3, ci), 4, 1e-9, "overdose at 4, not 3")
H.near(DanTraits_RunHooks("medOverAt", 3, plain9), 3, 1e-9, "others as is")
-- Delicate Stomach: junk food and a drink on an empty stomach
DanTraits_GradeFood = function(item) return item.grade, item.why end
local ds = newPlayer({ traits = { "delicatestomach" } }); H.current = ds
DanTraits_RunHooks("eat", nil, ds, { grade = 0.3, why = "junk" }, 1)
H.near(ds._st.foodsick, 15, 1e-9, "a whole junk meal: 15 food sickness")
DanTraits_RunHooks("eat", nil, ds, { grade = 0.3, why = "junk" }, 0.5)
H.near(ds._st.foodsick, 22.5, 1e-9, "half a meal: half")
DanTraits_RunHooks("eat", nil, ds, { grade = 0.7, why = "fresh, cooked" }, 1)
H.near(ds._st.foodsick, 22.5, 1e-9, "good food: nothing")
ds._st.hunger = 0.6; DanTraits_RunHooks("alcoholDrunk", nil, ds, {})
H.near(ds._st.foodsick, 32.5, 1e-9, "a drink on an empty stomach: 10")
ds._st.hunger = 0.2; DanTraits_RunHooks("alcoholDrunk", nil, ds, {})
H.near(ds._st.foodsick, 32.5, 1e-9, "fed: nothing")
local notds = newPlayer(); H.current = notds
DanTraits_RunHooks("eat", nil, notds, { grade = 0.3, why = "junk" }, 1)
H.near(notds._st.foodsick, 0, 1e-9, "others: nothing")
DanTraits_GradeFood = nil

H.pass()
