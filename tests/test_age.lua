-- Offline test for DanTraits_Age.lua: the age band (trait, else the sandbox
-- default, rounded down), the Age trait every character is given, the
-- profession's main-skill levels once per new character (ties, Fitness and
-- Strength never the main skill, Maintenance for the Unemployed, Handy's
-- Carpentry), DanTraits_AgeLevels (what the creation screen shows), and every
-- effect: nil in the 30s and with age off, the band's number otherwise;
-- Fitness and Strength experience; the scratch, cut and stiffness pacing.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }

local PROFS = {
  carpenter = { Woodwork = 4, Carving = 1, Masonry = 1 },
  chef = { Cooking = 4, Butchering = 2 },
  twotop = { Cooking = 2, Carving = 2, Masonry = 1 },
  instructor = { Fitness = 3, Sprinting = 2, Strength = 1 },
  unemployed = nil,
}
-- boost levels come back as Java Integers
local function integer(n) return { intValue = function() return n end } end
CharacterProfessionDefinition = { getCharacterProfessionDefinition = function(prof)
  return { getXpBoosts = function()
    local b = PROFS[prof]
    if not b then return nil end
    local out = {}
    for k, v in pairs(b) do out[k] = integer(v) end
    return out
  end }
end }
function transformIntoKahluaTable(t) return t end

H.load("Age", "GymRegular")
H.expectHooks("OnCreatePlayer", "AddXP")
H.expectEvery("minute", "Age")

local function newPart(name)
  local part = { _scratch = 0, _cut = 0, _stiff = 0 }
  function part:getType() return name end
  function part:getScratchTime() return self._scratch end
  function part:setScratchTime(v) self._scratch = v end
  function part:getCutTime() return self._cut end
  function part:setCutTime(v) self._cut = v end
  function part:getStiffness() return self._stiff end
  function part:setStiffness(v) self._stiff = v end
  function part:getAdditionalPain() return 0 end
  function part:setAdditionalPain() end
  return part
end

local newPlayer = H.factory(nil, function(p, o)
  local levels, xpSet = {}, {}
  for k, v in pairs(PROFS[o.prof or "carpenter"] or {}) do levels[k] = v end
  p._levels, p._xp, p._xpTotal, p._xpCalls = levels, xpSet, o.xp or {}, {}
  p.getDescriptor = function() return { getCharacterProfession = function() return o.prof or "carpenter" end } end
  p.getPerkLevel = function(_, perk) return levels[perk] or 0 end
  p.LevelPerk = function(_, perk) levels[perk] = (levels[perk] or 0) + 1 end
  p.getXp = function()
    return {
      setXPToLevel = function(_, perk, lvl) xpSet[perk] = lvl end,
      getXP = function(_, perk) return p._xpTotal[perk] or 0 end,
      AddXP = function(_, perk, amount, callLua, boost, remote, extra)
        p._xpCalls[#p._xpCalls + 1] = { perk = perk, amount = amount, quiet = callLua == false and boost == false }
        p._xpTotal[perk] = (p._xpTotal[perk] or 0) + amount
        H.fire("AddXP", p, perk, amount)   -- the game fires the event even with callLua false
      end,
    }
  end
  p.getFitness = function() return { init = function() end, getRegularity = function() return 0 end,
    setCurrentExercise = function() end, incRegularity = function() end } end
end)
local function aged(key, o)
  o = o or {}
  o.traits = { key }
  return newPlayer(o)
end
local function create(p) H.fire("OnCreatePlayer", 0, p); return p end

-- 1. band: trait first, else sandbox default rounded down, 30 when unset
assert(DanTraits_AgeBand(aged("age20s")) == 20, "20s trait")
assert(DanTraits_AgeBand(aged("age30s")) == 30, "30s trait")
assert(DanTraits_AgeBand(aged("age40s")) == 40, "40s trait")
assert(DanTraits_AgeBand(aged("age50s")) == 50, "50s trait")
assert(DanTraits_AgeBand(newPlayer()) == 30, "no trait: 30s")
SandboxVars.DanTraits.AgeDefault = 47
assert(DanTraits_AgeBand(newPlayer()) == 40, "default 47 rounds to 40s")
assert(DanTraits_AgeBand(aged("age30s")) == 30, "a 30s trait beats the default")
SandboxVars.DanTraits.AgeDefault = 29
assert(DanTraits_AgeBand(newPlayer()) == 20, "default 29 rounds to 20s")
SandboxVars.DanTraits.AgeDefault = 58
assert(DanTraits_AgeBand(newPlayer()) == 50, "default 58 rounds to 50s")
SandboxVars.DanTraits.AgeDefault = nil
assert(DanTraits_AgeRoundBand(50) == 50 and DanTraits_AgeRoundBand(49) == 40 and DanTraits_AgeRoundBand(nil) == 30, "rounding")

-- 2. 30s carpenter: +1 Woodwork (main skill only), XP set to the new level, once only;
--    and the 30s trait is granted
local p = create(newPlayer())
assert(p._levels.Woodwork == 5, "carpenter 4 -> 5, got " .. p._levels.Woodwork)
assert(p._levels.Carving == 1 and p._levels.Masonry == 1, "side skills untouched")
assert(p._xp.Woodwork == 5, "xp set to level 5")
assert(p._md.DanTraits.ageApplied and p._md.DanTraits.ageBand == 30, "marked applied, band 30")
assert(p._traits.age30s == true and p._adds == 1, "In Their 30s granted")
create(p)
assert(p._levels.Woodwork == 5 and p._adds == 1, "not applied or granted twice")

-- 3. the other bands: 0 / 2 / 3 levels; a picked trait is kept and nothing else granted
local young = create(aged("age20s"))
assert(young._levels.Woodwork == 4, "20s: no bonus")
assert(young._adds == 0 and not young._traits.age30s, "a picked age: nothing granted")
local forty, fifty = create(aged("age40s")), create(aged("age50s"))
assert(forty._levels.Woodwork == 6 and forty._levels.Carving == 2 and forty._levels.Masonry == 2, "40s: +2 main, +1 each side skill")
assert(fifty._levels.Woodwork == 7 and fifty._levels.Carving == 3 and fifty._levels.Masonry == 3, "50s: +3 main, +2 each side skill")
assert(young._levels.Carving == 1 and young._levels.Masonry == 1, "20s: no side levels")

-- 4. Handy: +1 Carpentry on top in the 40s and 50s only
local handy = create(newPlayer({ traits = { "age40s" }, vanilla = { "base:handy" } }))
assert(handy._levels.Woodwork == 7, "40s Handy carpenter: +2 +1, got " .. handy._levels.Woodwork)
local handyChef = create(newPlayer({ traits = { "age50s" }, vanilla = { "base:handy" }, prof = "chef" }))
assert(handyChef._levels.Cooking == 7 and handyChef._levels.Butchering == 4 and handyChef._levels.Woodwork == 1, "50s Handy chef: +3 Cooking, +2 Butchering, +1 Carpentry")
assert(create(newPlayer({ vanilla = { "base:handy" } }))._levels.Woodwork == 5, "30s Handy: no extra")

-- 5. ties all get the levels; Fitness and Strength are never the main skill;
--    the Unemployed get Maintenance; capped at 10
local tie = create(newPlayer({ prof = "twotop", traits = { "age50s" } }))
assert(tie._levels.Cooking == 5 and tie._levels.Carving == 5 and tie._levels.Masonry == 3, "tied main skills both +3, the side skill +2")
local coach = create(newPlayer({ prof = "instructor", traits = { "age40s" } }))
assert(coach._levels.Fitness == 3 and coach._levels.Strength == 1 and coach._levels.Sprinting == 4, "instructor: Sprinting, never Fitness or Strength (not as side skills either)")
local jobless = create(newPlayer({ prof = "unemployed" }))
assert(jobless._levels.Maintenance == 1, "unemployed 30s: +1 Maintenance")
assert(create(newPlayer({ prof = "unemployed", traits = { "age50s" } }))._levels.Maintenance == 3, "unemployed 50s: +3 Maintenance")
local joblessYoung = create(newPlayer({ prof = "unemployed", traits = { "age20s" } }))
assert(joblessYoung._levels.Maintenance == nil, "unemployed 20s: nothing")
SandboxVars.DanTraits.AgeBonus30s = 5
local maxed = newPlayer(); maxed._levels.Woodwork = 8; create(maxed)
assert(maxed._levels.Woodwork == 10, "capped at 10, got " .. maxed._levels.Woodwork)
SandboxVars.DanTraits.AgeBonus30s = nil

-- 6. sandbox levels respected; an old save gets its trait and no levels; age off does nothing
SandboxVars.DanTraits.AgeBonus50s = 1
assert(create(aged("age50s"))._levels.Woodwork == 5, "sandbox 50s bonus 1")
SandboxVars.DanTraits.AgeBonus50s = 0
local none = create(aged("age50s"))
assert(none._levels.Woodwork == 4 and none._levels.Carving == 1, "sandbox 50s bonus 0: no side levels either")
SandboxVars.DanTraits.AgeBonus50s = nil
local loaded = create(newPlayer({ hours = 10 }))
assert(loaded._levels.Woodwork == 4 and not loaded._md.DanTraits, "old save: skills and mod data untouched")
assert(loaded._traits.age30s == true, "old save: given its Age trait")
SandboxVars.DanTraits.AgeDefault = 45
assert(create(newPlayer({ hours = 10 }))._traits.age40s == true, "old save, default 45: the 40s trait")
assert(create(newPlayer({ hours = 10, traits = { "age20s" } }))._adds == 0, "old save with a trait: nothing granted")
SandboxVars.DanTraits.AgeDefault = nil
SandboxVars.DanTraits.AgeEnabled = false
local off = create(newPlayer({ traits = { "age40s" }, vanilla = { "base:handy" } }))
assert(off._levels.Woodwork == 4, "age disabled: no levels")
assert(create(newPlayer())._adds == 0, "age disabled: no trait granted")
assert(DanTraits_AgeBand(aged("age50s")) == 30, "age disabled: everyone counts as the 30s")
SandboxVars.DanTraits.AgeEnabled = nil

-- 7. DanTraits_AgeLevels: what the creation screen asks (boosts, band, Handy, the new game's bonus)
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end return n end
local lv = DanTraits_AgeLevels({ Woodwork = integer(4), Carving = integer(1) }, 40, false)
assert(lv.Woodwork == 2 and lv.Carving == 1 and count(lv) == 2, "40s carpenter: Woodwork 2, Carving 1")
lv = DanTraits_AgeLevels({ Woodwork = integer(4), Carving = integer(1) }, 30, false)
assert(lv.Woodwork == 1 and count(lv) == 1, "30s carpenter: the main skill only")
lv = DanTraits_AgeLevels({ Woodwork = integer(4) }, 50, true)
assert(lv.Woodwork == 4, "50s Handy carpenter: 3 + 1 on the same skill")
lv = DanTraits_AgeLevels({ Cooking = 4, Woodwork = 1 }, 50, true)
assert(lv.Cooking == 3 and lv.Woodwork == 3, "Handy's Carpentry on top of the side levels")
lv = DanTraits_AgeLevels({ Sprinting = 2, Fitness = 3, Strength = 1, Lightfoot = 1 }, 50, false)
assert(lv.Sprinting == 3 and lv.Lightfoot == 2 and count(lv) == 2, "Fitness and Strength get nothing, main or side")
lv = DanTraits_AgeLevels({ Cooking = 2, Carving = 2 }, 30, true)
assert(lv.Cooking == 1 and lv.Carving == 1 and count(lv) == 2, "30s tie, plain numbers, Handy adds nothing")
lv = DanTraits_AgeLevels(nil, 50, false)
assert(lv.Maintenance == 3 and count(lv) == 1, "no boosts: Maintenance")
lv = DanTraits_AgeLevels({ Fitness = 1, Strength = 1 }, 40, false)
assert(lv.Maintenance == 2 and count(lv) == 1, "only body stats boosted: Maintenance")
assert(count(DanTraits_AgeLevels({ Woodwork = 4 }, 20, false)) == 0, "20s: nothing")
assert(DanTraits_AgeLevels({ Woodwork = 4 }, 20, false, 2).Woodwork == 2, "the passed bonus wins over the default")
assert(count(DanTraits_AgeLevels({ Woodwork = 4, Carving = 1 }, 50, false, 0)) == 0, "a passed bonus of 0: nothing, side skills included")

-- 7b. age pricing: the body costs more with age, learning is cheap young and dear old,
--     a hearty appetite natural young; negative is cheaper
for _, big in ipairs({ "base:strong", "base:athletic", "Base:Strong" }) do
  assert(DanTraits_AgeSurcharge(20, big) == 0 and DanTraits_AgeSurcharge(30, big) == 0, big .. ": nothing in the 20s and 30s")
  assert(DanTraits_AgeSurcharge(40, big) == 2 and DanTraits_AgeSurcharge(50, big) == 4, big .. ": 2 and 4")
end
assert(DanTraits_AgeSurcharge(20, "base:stout") == 0 and DanTraits_AgeSurcharge(40, "base:stout") == 1 and DanTraits_AgeSurcharge(50, "base:stout") == 2, "Stout: 1 and 2")
assert(DanTraits_AgeSurcharge(20, "base:fit") == -1 and DanTraits_AgeSurcharge(40, "base:fit") == 1 and DanTraits_AgeSurcharge(50, "base:fit") == 2, "Fit: a point cheaper young, 1 and 2 old")
assert(DanTraits_AgeSurcharge(20, "base:fastlearner") == -1 and DanTraits_AgeSurcharge(40, "base:fastlearner") == 0 and DanTraits_AgeSurcharge(50, "base:fastlearner") == 1, "Fast Learner: -1 / 0 / +1")
assert(DanTraits_AgeSurcharge(20, "base:slowlearner") == 1 and DanTraits_AgeSurcharge(50, "base:slowlearner") == 1, "Slow Learner gives a point fewer, young or old")
assert(DanTraits_AgeSurcharge(20, "base:heartyappetite") == 1 and DanTraits_AgeSurcharge(50, "base:heartyappetite") == -1, "Hearty Appetite: a point fewer young, one more old")
assert(DanTraits_AgeSurcharge(20, "base:lighteater") == 0 and DanTraits_AgeSurcharge(50, "base:lighteater") == 0, "Light Eater: no age price (taken out 2026-10-07)")
assert(DanTraits_AgeSurcharge(50, "base:brave") == 0 and DanTraits_AgeSurcharge(50, "age50s") == 0, "other traits: nothing")
assert(DanTraits_AgeSurcharge(nil, "base:strong") == 0 and DanTraits_AgeSurcharge(30, "base:fit") == 0, "no band, or the 30s: nothing")
assert(DanTraits_AgePrices()["base:fit"][20] == -1, "the table is readable")

-- 8. hooks with a floor or a cap: Gym Regular 65 in the 20s only; Arthritis joint in the 40s and 50s
assert(DanTraits_RunHooks("gymRegularity", 50, aged("age20s")) == 65, "20s gym 65")
assert(DanTraits_RunHooks("gymRegularity", 80, aged("age20s")) == 80, "20s gym: never lowered")
assert(DanTraits_RunHooks("gymRegularity", 50, newPlayer()) == 50, "30s gym 50")
assert(DanTraits_RunHooks("gymRegularity", 50, aged("age50s")) == 50, "50s gym 50")
H.near(DanTraits_RunHooks("arthritisJoint", 0.5, aged("age40s")), 0.65, 1e-9, "40s joint x1.3")
H.near(DanTraits_RunHooks("arthritisJoint", 0.5, aged("age50s")), 0.8, 1e-9, "50s joint x1.6")
assert(DanTraits_RunHooks("arthritisJoint", 0.9, aged("age40s")) == 1, "capped at 1")
assert(DanTraits_RunHooks("arthritisJoint", 0.5, newPlayer()) == 0.5, "30s joint unchanged")

-- 9. every other hook: [name, value, 20s, 40s, 50s] (false: says nothing); nil in the 30s and with age off
local bands = { aged("age20s"), aged("age40s"), aged("age50s") }
local mid = newPlayer()
local function silent(name, value, player, msg)
  for _, fn in ipairs(DanTraits_Hooks[name]) do assert(fn(value, player) == nil, name .. " should say nothing: " .. msg) end
end
local HOOKS = {
  { "enduranceRegen", 0.01, 0.0125, 0.0092, 0.0085 },
  { "woundHeal", 0.35, 0.525, 0.315, 0.28 },
  { "nightWakes", 4, 3.2, 4.6, 5.2 },
  { "bloodCellRebuild", 0.02, 0.023, 0.016, 0.013 },
  { "concussionHeal", 0.001, 0.0012, 0.00075, 0.0006 },
  { "hangoverSeverity", 0.6, 0.51, 0.75, 0.9 },
  { "diaResistance", 0.5, 0.45, 0.6, 0.7 },
  { "brittleChance", 20, false, 25, 30 },
  { "hungerRise", 0.01, 0.0115, 0.0095, 0.009 },
  { "caffeineClearance", 1, 1.2, 0.9, 0.8 },
  { "hangoverHours", 12, 10, 12 / 0.9, 15 },
  { "medHalfLife", 24, 20, 24 / 0.9, 30 },
}
for _, row in ipairs(HOOKS) do
  local name, value = row[1], row[2]
  silent(name, value, mid, "30s")
  silent(name, value, aged("age30s"), "30s trait")
  for i, player in ipairs(bands) do
    local want = row[i + 2]
    if want then H.near(DanTraits_RunHooks(name, value, player), want, 1e-9, name .. " band " .. i)
    else silent(name, value, player, "band " .. i) end
  end
  SandboxVars.DanTraits.AgeEnabled = false
  for i, player in ipairs(bands) do silent(name, value, player, "age off, band " .. i) end
  SandboxVars.DanTraits.AgeEnabled = nil
end
SandboxVars.DanTraits.AgeDefault = 47
H.near(DanTraits_RunHooks("hangoverSeverity", 0.6, newPlayer()), 0.75, 1e-9, "sandbox default age 47 counts as the 40s")
SandboxVars.DanTraits.AgeDefault = nil
-- Heart reads its factor directly
assert(DanTraits_AgeHeart(mid) == 1, "heart 30s")
H.near(DanTraits_AgeHeart(bands[1]), 0.8, 1e-9, "heart 20s")
H.near(DanTraits_AgeHeart(bands[2]), 1.25, 1e-9, "heart 40s")
H.near(DanTraits_AgeHeart(bands[3]), 1.5, 1e-9, "heart 50s")

-- 10. Fitness and Strength experience: the difference is added quietly (no event, no
--     multipliers); other skills, losses and the 30s are left alone
local function perk(name) return { name = name, getTotalXpForLevel = function(_, level) return level * 100 end } end
Perks.Fitness, Perks.Strength = perk("Fitness"), perk("Strength")
local xp = H.on("AddXP")
local y = aged("age20s")
xp(y, Perks.Fitness, 10)
assert(#y._xpCalls == 1 and y._xpCalls[1].perk == Perks.Fitness and y._xpCalls[1].quiet, "20s: one quiet top-up")
H.near(y._xpCalls[1].amount, 5, 1e-9, "20s: half as much again")
xp(y, Perks.Strength, 4); H.near(y._xpCalls[2].amount, 2, 1e-9, "Strength too")
xp(y, "Woodwork", 10); xp(y, Perks.Fitness, -3); xp(y, Perks.Fitness, 0)
assert(#y._xpCalls == 2, "other skills and losses untouched")
local m = newPlayer(); xp(m, Perks.Fitness, 10); assert(#m._xpCalls == 0, "30s: nothing")
-- the 50s give a fifth back, but never drop under the level they hold (level 2 = 200 XP)
local o = aged("age50s", { xp = { [Perks.Fitness] = 250 } }); o._levels[Perks.Fitness] = 2
xp(o, Perks.Fitness, 10)
H.near(o._xpCalls[1].amount, -2, 1e-9, "50s: a fifth taken back")
o._xpTotal[Perks.Fitness] = 201
xp(o, Perks.Fitness, 10)
H.near(o._xpCalls[2].amount, -1, 1e-9, "stops at the level's threshold")
o._xpTotal[Perks.Fitness] = 200
xp(o, Perks.Fitness, 10)
assert(#o._xpCalls == 2, "on the threshold: nothing to take")
SandboxVars.DanTraits.AgeEnabled = false
xp(y, Perks.Fitness, 10); assert(#y._xpCalls == 2, "age off: nothing")
SandboxVars.DanTraits.AgeEnabled = nil

-- 10b. learning by band: any skill under level 3 (the young pick things up, the old do not),
--      and the skills the profession boosts (the trade you know keeps coming); the factors multiply
local y2 = aged("age20s"); y2._levels.Cooking = 1
xp(y2, "Cooking", 10); H.near(y2._xpCalls[1].amount, 2, 1e-9, "20s, a new skill: x1.2")
y2._levels.Cooking = 3; xp(y2, "Cooking", 10); assert(#y2._xpCalls == 1, "at level 3: nothing more")
y2._levels.Woodwork = 5; xp(y2, "Woodwork", 10); assert(#y2._xpCalls == 1, "the 20s have no trade bonus")
local f = aged("age40s"); f._levels.Woodwork = 5; f._levels.Cooking = 1
xp(f, "Woodwork", 10); H.near(f._xpCalls[1].amount, 1, 1e-9, "40s, the main skill: x1.1")
xp(f, "Carving", 10); H.near(f._xpCalls[2].amount, 1, 1e-9, "a side skill of the trade too")
xp(f, "Cooking", 10); assert(#f._xpCalls == 2, "40s, a new skill outside the trade: the plain rate")
local cook = perk("Cooking")   -- a take-back reads the perk's level threshold, so a real perk object
local o2 = aged("age50s", { xp = { [cook] = 150 } }); o2._levels.Woodwork = 5; o2._levels[cook] = 1
xp(o2, "Woodwork", 10); H.near(o2._xpCalls[1].amount, 1.5, 1e-9, "50s, the trade: x1.15")
xp(o2, cook, 10); H.near(o2._xpCalls[2].amount, -1, 1e-9, "50s, a new skill: x0.9, taken back quietly")
o2._levels.Masonry = 1
xp(o2, "Masonry", 10); H.near(o2._xpCalls[3].amount, 10 * (1.15 * 0.9 - 1), 1e-9, "a trade skill still under 3: both factors")
local m2 = newPlayer(); m2._levels.Cooking = 1; xp(m2, "Cooking", 10); assert(#m2._xpCalls == 0, "30s: nothing")

-- 10c. clearance: whatever drunkenness and food sickness fell by since the last minute is
--      hurried (20s) or stretched (50s); rises and the 30s are left alone; the food sickness
--      pipeline is told the new value
local function clearing(player, stat, from, to)
  player._st[stat] = from; H.minute(); player._st[stat] = to; H.minute(); return player._st[stat]
end
local yc = aged("age20s"); H.current = yc
H.near(clearing(yc, "intox", 50, 40), 38, 1e-9, "20s: a fall of 10 becomes 12")
H.near(clearing(yc, "foodsick", 30, 20), 18, 1e-9, "food sickness too")
H.near(yc._md.DanTraits.deltaLast.foodSicknessRise, 18, 1e-9, "the pipeline is told")
yc._st.intox = 60; H.minute(); H.near(yc._st.intox, 60, 1e-9, "a rise is left alone")
local oc = aged("age50s"); H.current = oc
H.near(clearing(oc, "intox", 50, 40), 42, 1e-9, "50s: a fall of 10 becomes 8")
H.near(clearing(oc, "foodsick", 30, 0), 6, 1e-9, "cleared outright: some lingers")
local mc = newPlayer(); H.current = mc
H.near(clearing(mc, "intox", 50, 40), 40, 1e-9, "30s: as the game left it")

-- 11. scratches, cuts and stiffness: each minute's fall is hurried (20s) or stretched (40s, 50s)
local function body(key)
  local arm, leg = newPart("ForeArm_L"), newPart("LowerLeg_R")
  local player = key and aged(key, { parts = { arm, leg } }) or newPlayer({ parts = { arm, leg } })
  H.current = player
  return player, arm, leg
end
local q, arm, leg = body("age50s")
arm._scratch, arm._cut, leg._stiff = 10, 20, 50
H.minute()   -- the first look only remembers
assert(arm._scratch == 10 and arm._cut == 20 and leg._stiff == 50, "first minute: nothing moved")
arm._scratch, arm._cut, leg._stiff = 9, 19.5, 48
H.minute()
H.near(arm._scratch, 9.2, 1e-9, "50s scratch: a point of healing becomes 0.8")
H.near(arm._cut, 19.6, 1e-9, "50s cut")
H.near(leg._stiff, 48.6, 1e-9, "50s stiffness: 2 off becomes 1.4")
arm._scratch = 8.2; leg._stiff = 60   -- stiffness went up (exertion): left alone, remembered
H.minute()
H.near(arm._scratch, 8.4, 1e-9, "paced from what was written last minute")
assert(leg._stiff == 60, "a rise is not touched")
arm._scratch, arm._cut, leg._stiff = 0, 0, 0   -- healed (or cleared by the game)
H.minute()
assert(arm._scratch == 0 and arm._cut == 0 and leg._stiff == 0, "nothing that reached zero is brought back")
assert(q._md.DanTraits.ageParts.ForeArm_L == nil and q._md.DanTraits.ageParts.LowerLeg_R == nil, "healed parts forgotten")

q, arm, leg = body("age20s")
arm._scratch, leg._stiff = 10, 50
H.minute()
arm._scratch, leg._stiff = 9, 48
H.minute()
H.near(arm._scratch, 8.5, 1e-9, "20s scratch: a point becomes 1.5")
H.near(leg._stiff, 47, 1e-9, "20s stiffness: 2 off becomes 3")
arm._scratch, leg._stiff = 8.4, 46.5
H.minute(); arm._scratch, leg._stiff = 0.2, 0.5; H.minute()
assert(arm._scratch == 0.01, "a hurried scratch stops just short: the game closes it, got " .. arm._scratch)
assert(leg._stiff == 0, "hurried stiffness stops at 0")

q, arm, leg = body(nil)   -- the 30s: nothing touched, nothing remembered
arm._scratch = 10; H.minute(); arm._scratch = 9; H.minute()
assert(arm._scratch == 9 and q._md.DanTraits.ageParts == nil, "30s: left alone")
q, arm, leg = body("age50s")
arm._scratch = 10; H.minute()
SandboxVars.DanTraits.AgeEnabled = false
arm._scratch = 9; H.minute()
assert(arm._scratch == 9 and q._md.DanTraits.ageParts == nil, "age off: left alone, state dropped")
SandboxVars.DanTraits.AgeEnabled = nil

H.pass()
