-- Offline test for DanTraits_Age.lua: the age band (trait, else the sandbox
-- default, rounded down), the profession's main-skill levels once per new
-- character, Handy's extra Carpentry in the 40s, and the Gym Regular and
-- Arthritis hooks.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
HaloTextHelper = { addBadText = function() end, addGoodText = function() end }
function getText(k) return k end
DanTraitsRegistry = { age20s = "age20s", age40s = "age40s", gymregular = "gymregular" }
FitnessExercises = { exercisesType = { squats = {}, pushups = {} } }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
SandboxVars = { DanTraits = {} }

Perks = { Woodwork = "Woodwork", Carving = "Carving", Masonry = "Masonry", Cooking = "Cooking", Butchering = "Butchering" }
local PROFS = {
  carpenter = { Woodwork = 4, Carving = 1, Masonry = 1 },
  chef = { Cooking = 4, Butchering = 2 },
  twotop = { Cooking = 2, Carving = 2, Masonry = 1 },
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

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Age", "DanTraits_GymRegular" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.OnCreatePlayer, "hooks in place")

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or {}) do traits[t] = true end
  local vanilla = o.vanilla or {}
  local md = {}
  local levels = {}
  for k, v in pairs(PROFS[o.prof or "carpenter"] or {}) do levels[k] = v end
  local xpSet = {}
  local p = {
    hasTrait = function(_, t) return traits[t] == true end, isDead = function() return false end,
    getModData = function() return md end, getHoursSurvived = function() return o.hours or 0 end,
    getDescriptor = function() return { getCharacterProfession = function() return o.prof or "carpenter" end } end,
    getPerkLevel = function(_, perk) return levels[perk] or 0 end,
    LevelPerk = function(_, perk) levels[perk] = (levels[perk] or 0) + 1 end,
    getXp = function() return { setXPToLevel = function(_, perk, lvl) xpSet[perk] = lvl end } end,
    getCharacterTraits = function() return { getKnownTraits = function()
      return { size = function() return #vanilla end, get = function(_, i) return vanilla[i + 1] end } end } end,
    getFitness = function() return { init = function() end, getRegularity = function() return 0 end,
      setCurrentExercise = function() end, incRegularity = function() end } end,
    _md = md, _levels = levels, _xp = xpSet,
  }
  return p
end

-- 1. band: trait first, else sandbox default rounded down, 30 when unset
assert(DanTraits_AgeBand(makePlayer({ traits = { "age20s" } })) == 20, "20s trait")
assert(DanTraits_AgeBand(makePlayer({ traits = { "age40s" } })) == 40, "40s trait")
assert(DanTraits_AgeBand(makePlayer()) == 30, "no trait: 30s")
SandboxVars.DanTraits.AgeDefault = 47
assert(DanTraits_AgeBand(makePlayer()) == 40, "default 47 rounds to 40s")
SandboxVars.DanTraits.AgeDefault = 29
assert(DanTraits_AgeBand(makePlayer()) == 20, "default 29 rounds to 20s")
SandboxVars.DanTraits.AgeDefault = nil

-- 2. 30s carpenter: +1 Woodwork (main skill only), XP set to the new level, once only
local p = makePlayer(); handlers.OnCreatePlayer(0, p)
assert(p._levels.Woodwork == 5, "carpenter 4 -> 5, got " .. p._levels.Woodwork)
assert(p._levels.Carving == 1 and p._levels.Masonry == 1, "side skills untouched")
assert(p._xp.Woodwork == 5, "xp set to level 5")
assert(p._md.DanTraits.ageApplied and p._md.DanTraits.ageBand == 30, "marked applied, band 30")
handlers.OnCreatePlayer(0, p)
assert(p._levels.Woodwork == 5, "not applied twice")

-- 3. 20s: no profession level
local young = makePlayer({ traits = { "age20s" } }); handlers.OnCreatePlayer(0, young)
assert(young._levels.Woodwork == 4, "20s: no bonus")

-- 4. 40s: +1 main skill; with Handy, +1 Carpentry on top
local old = makePlayer({ traits = { "age40s" } }); handlers.OnCreatePlayer(0, old)
assert(old._levels.Woodwork == 5, "40s: +1")
local handy = makePlayer({ traits = { "age40s" }, vanilla = { "base:handy" } }); handlers.OnCreatePlayer(0, handy)
assert(handy._levels.Woodwork == 6, "40s Handy: +2 Woodwork, got " .. handy._levels.Woodwork)
local handy30 = makePlayer({ vanilla = { "base:handy" } }); handlers.OnCreatePlayer(0, handy30)
assert(handy30._levels.Woodwork == 5, "30s Handy: no extra")

-- 5. ties all get the bonus; unemployed gets nothing; capped at 10
local tie = makePlayer({ prof = "twotop" }); handlers.OnCreatePlayer(0, tie)
assert(tie._levels.Cooking == 3 and tie._levels.Carving == 3 and tie._levels.Masonry == 1, "tied main skills both +1")
local jobless = makePlayer({ prof = "unemployed" }); handlers.OnCreatePlayer(0, jobless)
assert(next(jobless._levels) == nil, "unemployed: nothing")
SandboxVars.DanTraits.AgeBonus30s = 5
local maxed = makePlayer(); maxed._levels.Woodwork = 8; handlers.OnCreatePlayer(0, maxed)
assert(maxed._levels.Woodwork == 10, "capped at 10, got " .. maxed._levels.Woodwork)
SandboxVars.DanTraits.AgeBonus30s = nil

-- 6. sandbox bonus levels respected; existing characters and disabled age untouched
SandboxVars.DanTraits.AgeBonus40s = 2
local vet = makePlayer({ traits = { "age40s" } }); handlers.OnCreatePlayer(0, vet)
assert(vet._levels.Woodwork == 6, "sandbox 40s bonus 2")
SandboxVars.DanTraits.AgeBonus40s = nil
local loaded = makePlayer({ hours = 10 }); handlers.OnCreatePlayer(0, loaded)
assert(loaded._levels.Woodwork == 4 and not loaded._md.DanTraits, "existing character untouched")
SandboxVars.DanTraits.AgeEnabled = false
local off = makePlayer({ traits = { "age40s" }, vanilla = { "base:handy" } }); handlers.OnCreatePlayer(0, off)
assert(off._levels.Woodwork == 4, "age disabled: nothing")
assert(DanTraits_RunHooks("gymRegularity", 50, makePlayer({ traits = { "age20s" } })) == 50, "disabled: gym hook off")
SandboxVars.DanTraits.AgeEnabled = nil

-- 7. hooks: Gym Regular 65 in the 20s only; Arthritis joint x1.3 (capped) in the 40s only
assert(DanTraits_RunHooks("gymRegularity", 50, makePlayer({ traits = { "age20s" } })) == 65, "20s gym 65")
assert(DanTraits_RunHooks("gymRegularity", 50, makePlayer()) == 50, "30s gym 50")
assert(DanTraits_RunHooks("gymRegularity", 50, makePlayer({ traits = { "age40s" } })) == 50, "40s gym 50")
local j = DanTraits_RunHooks("arthritisJoint", 0.5, makePlayer({ traits = { "age40s" } }))
assert(math.abs(j - 0.65) < 1e-9, "40s joint 0.5 -> 0.65, got " .. j)
assert(DanTraits_RunHooks("arthritisJoint", 0.9, makePlayer({ traits = { "age40s" } })) == 1, "capped at 1")
assert(DanTraits_RunHooks("arthritisJoint", 0.5, makePlayer()) == 0.5, "30s joint unchanged")

print("age: all passed")
