-- Offline test for DanTraits_Age.lua: the age band (trait, else the sandbox
-- default, rounded down), the profession's main-skill levels once per new
-- character, Handy's extra Carpentry in the 40s, and the Gym Regular and
-- Arthritis hooks.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }

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

H.load("Age", "GymRegular")
H.expectHooks("OnCreatePlayer")

local newPlayer = H.factory(nil, function(p, o)
  local levels, xpSet = {}, {}
  for k, v in pairs(PROFS[o.prof or "carpenter"] or {}) do levels[k] = v end
  p._levels, p._xp = levels, xpSet
  p.getDescriptor = function() return { getCharacterProfession = function() return o.prof or "carpenter" end } end
  p.getPerkLevel = function(_, perk) return levels[perk] or 0 end
  p.LevelPerk = function(_, perk) levels[perk] = (levels[perk] or 0) + 1 end
  p.getXp = function() return { setXPToLevel = function(_, perk, lvl) xpSet[perk] = lvl end } end
  p.getFitness = function() return { init = function() end, getRegularity = function() return 0 end,
    setCurrentExercise = function() end, incRegularity = function() end } end
end)

-- 1. band: trait first, else sandbox default rounded down, 30 when unset
assert(DanTraits_AgeBand(newPlayer({ traits = { "age20s" } })) == 20, "20s trait")
assert(DanTraits_AgeBand(newPlayer({ traits = { "age40s" } })) == 40, "40s trait")
assert(DanTraits_AgeBand(newPlayer()) == 30, "no trait: 30s")
SandboxVars.DanTraits.AgeDefault = 47
assert(DanTraits_AgeBand(newPlayer()) == 40, "default 47 rounds to 40s")
SandboxVars.DanTraits.AgeDefault = 29
assert(DanTraits_AgeBand(newPlayer()) == 20, "default 29 rounds to 20s")
SandboxVars.DanTraits.AgeDefault = nil

-- 2. 30s carpenter: +1 Woodwork (main skill only), XP set to the new level, once only
local p = newPlayer(); H.fire("OnCreatePlayer", 0, p)
assert(p._levels.Woodwork == 5, "carpenter 4 -> 5, got " .. p._levels.Woodwork)
assert(p._levels.Carving == 1 and p._levels.Masonry == 1, "side skills untouched")
assert(p._xp.Woodwork == 5, "xp set to level 5")
assert(p._md.DanTraits.ageApplied and p._md.DanTraits.ageBand == 30, "marked applied, band 30")
H.fire("OnCreatePlayer", 0, p)
assert(p._levels.Woodwork == 5, "not applied twice")

-- 3. 20s: no profession level
local young = newPlayer({ traits = { "age20s" } }); H.fire("OnCreatePlayer", 0, young)
assert(young._levels.Woodwork == 4, "20s: no bonus")

-- 4. 40s: +1 main skill; with Handy, +1 Carpentry on top
local old = newPlayer({ traits = { "age40s" } }); H.fire("OnCreatePlayer", 0, old)
assert(old._levels.Woodwork == 5, "40s: +1")
local handy = newPlayer({ traits = { "age40s" }, vanilla = { "base:handy" } }); H.fire("OnCreatePlayer", 0, handy)
assert(handy._levels.Woodwork == 6, "40s Handy: +2 Woodwork, got " .. handy._levels.Woodwork)
local handy30 = newPlayer({ vanilla = { "base:handy" } }); H.fire("OnCreatePlayer", 0, handy30)
assert(handy30._levels.Woodwork == 5, "30s Handy: no extra")

-- 5. ties all get the bonus; unemployed gets nothing; capped at 10
local tie = newPlayer({ prof = "twotop" }); H.fire("OnCreatePlayer", 0, tie)
assert(tie._levels.Cooking == 3 and tie._levels.Carving == 3 and tie._levels.Masonry == 1, "tied main skills both +1")
local jobless = newPlayer({ prof = "unemployed" }); H.fire("OnCreatePlayer", 0, jobless)
assert(next(jobless._levels) == nil, "unemployed: nothing")
SandboxVars.DanTraits.AgeBonus30s = 5
local maxed = newPlayer(); maxed._levels.Woodwork = 8; H.fire("OnCreatePlayer", 0, maxed)
assert(maxed._levels.Woodwork == 10, "capped at 10, got " .. maxed._levels.Woodwork)
SandboxVars.DanTraits.AgeBonus30s = nil

-- 6. sandbox bonus levels respected; existing characters and disabled age untouched
SandboxVars.DanTraits.AgeBonus40s = 2
local vet = newPlayer({ traits = { "age40s" } }); H.fire("OnCreatePlayer", 0, vet)
assert(vet._levels.Woodwork == 6, "sandbox 40s bonus 2")
SandboxVars.DanTraits.AgeBonus40s = nil
local loaded = newPlayer({ hours = 10 }); H.fire("OnCreatePlayer", 0, loaded)
assert(loaded._levels.Woodwork == 4 and not loaded._md.DanTraits, "existing character untouched")
SandboxVars.DanTraits.AgeEnabled = false
local off = newPlayer({ traits = { "age40s" }, vanilla = { "base:handy" } }); H.fire("OnCreatePlayer", 0, off)
assert(off._levels.Woodwork == 4, "age disabled: nothing")
assert(DanTraits_RunHooks("gymRegularity", 50, newPlayer({ traits = { "age20s" } })) == 50, "disabled: gym hook off")
SandboxVars.DanTraits.AgeEnabled = nil

-- 7. hooks: Gym Regular 65 in the 20s only; Arthritis joint x1.3 (capped) in the 40s only
assert(DanTraits_RunHooks("gymRegularity", 50, newPlayer({ traits = { "age20s" } })) == 65, "20s gym 65")
assert(DanTraits_RunHooks("gymRegularity", 50, newPlayer()) == 50, "30s gym 50")
assert(DanTraits_RunHooks("gymRegularity", 50, newPlayer({ traits = { "age40s" } })) == 50, "40s gym 50")
local j = DanTraits_RunHooks("arthritisJoint", 0.5, newPlayer({ traits = { "age40s" } }))
assert(math.abs(j - 0.65) < 1e-9, "40s joint 0.5 -> 0.65, got " .. j)
assert(DanTraits_RunHooks("arthritisJoint", 0.9, newPlayer({ traits = { "age40s" } })) == 1, "capped at 1")
assert(DanTraits_RunHooks("arthritisJoint", 0.5, newPlayer()) == 0.5, "30s joint unchanged")

H.pass()
