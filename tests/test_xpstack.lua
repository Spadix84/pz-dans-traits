-- Offline test for experience with Age, AgeTraits and Vitality loaded together (the
-- game's load order). Each listens to Events.AddXP and adds its own share on top of
-- what the game gave; the game fires the event for those additions too, so the
-- shares stack. Today they stack as sums (each adds its share of the original
-- amount) except where one handler sees another's addition: Age's quiet top-up is
-- hidden from Vitality (DanTraits_AgeXpBusy) and from AgeTraits (DanTraits_AgeXpAdjust
-- refuses while Age adjusts), while Vitality's own addition is seen by both. The
-- sums pinned here are today's; review 2026-10-08 item 11 may make them products
-- (1.2 x 1.4 = 1.68, 1.5 x 1.5 = 2.25, 1.5 x 1.4 x 1.5 = 3.15), and then this test
-- changes with it.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }
CharacterProfessionDefinition = { getCharacterProfessionDefinition = function() return { getXpBoosts = function() return nil end } end }
function transformIntoKahluaTable(t) return t end
ISReadABook = { getDuration = function() return 400 end, isValid = function() return true end }
MoodleType.HEAVY_LOAD = "heavy"
ClimbOverFenceState = { instance = function() return {} end }
ClimbThroughWindowState = { instance = function() return {} end }
BodyPartType.Torso_Lower = "Torso_Lower"
BodyPartType.getDisplayName = function(kind) return kind end

-- the body's two perks are objects in the game (Age asks them the XP a level holds)
local function perk(name) return { name = name, getTotalXpForLevel = function(_, level) return level * 100 end } end
Perks = { Fitness = perk("Fitness"), Strength = perk("Strength") }

H.load("Age", "AgeTraits", "Vitality")
assert(#H.handlers.AddXP == 3, "three AddXP handlers: Age, AgeTraits, Vitality (got " .. #H.handlers.AddXP .. ")")

-- a character whose experience goes through the game's XP object, which fires
-- the AddXP event for every addition, the quiet ones (callLua false) included
local newPlayer = H.factory(nil, function(p, o)
  p._levels, p._total, p._calls = o.levels or {}, {}, {}
  p.getDescriptor = function() return { getCharacterProfession = function() return "unemployed" end } end
  p.getPerkLevel = function(_, perk) return p._levels[perk] or 0 end
  p.getXp = function()
    return {
      getXP = function(_, perk) return p._total[perk] or 0 end,
      setXPToLevel = function() end,
      AddXP = function(_, perk, amount, callLua, boost)
        p._calls[#p._calls + 1] = { perk = perk, amount = amount, quiet = callLua == false and boost == false }
        p._total[perk] = (p._total[perk] or 0) + amount
        H.fire("AddXP", p, perk, amount)
      end,
    }
  end
  if o.thriving then DanTraits_Data(p).vitality = 0.9 end   -- Thriving: the top tier (0.8 and up)
end)
-- the game adds `amount` and fires the event; what the skill ends up with, over amount
local function gain(p, perk, amount)
  p._total[perk] = (p._total[perk] or 0) + amount
  H.fire("AddXP", p, perk, amount)
  return p._total[perk] / amount
end
local near = H.near

-- 1. one at a time, as the single-file tests have them
near(gain(newPlayer({ traits = { "age20s" } }), "Cooking", 10), 1.2, 1e-9, "20s on a new skill: x1.2")
near(gain(newPlayer({ traits = { "age20s" } }), Perks.Fitness, 10), 1.5, 1e-9, "20s on Fitness: x1.5")
near(gain(newPlayer({ traits = { "quickstudy" } }), "Cooking", 10), 1.4, 1e-9, "Quick Study under level 5: x1.4")
near(gain(newPlayer({ thriving = true }), Perks.Fitness, 10), 1.5, 1e-9, "Thriving on Fitness: x1.5")
near(gain(newPlayer({ thriving = true }), "Cooking", 10), 1, 1e-9, "Thriving on Cooking: nothing")
near(gain(newPlayer(), Perks.Fitness, 10), 1, 1e-9, "30s, neutral, no trait: the game's own")

-- 2. stacked, today's sums
near(gain(newPlayer({ traits = { "age20s", "quickstudy" } }), "Cooking", 10), 1.6, 1e-9,
  "20s + Quick Study under level 3: 1 + 0.2 + 0.4 (Quick Study does not see Age's quiet top-up)")
near(gain(newPlayer({ traits = { "age20s" }, thriving = true }), Perks.Fitness, 10), 2.25, 1e-9,
  "20s + Thriving on Fitness: 1 + 0.5 + 0.5 + Age's 0.5 on Vitality's half (Vitality does not see Age's)")
near(gain(newPlayer({ traits = { "age20s", "quickstudy" }, thriving = true }), Perks.Fitness, 10), 2.85, 1e-9,
  "all three on Fitness: 1 + 0.5 + 0.4 + 0.5, then Age's 0.5 and Quick Study's 0.4 on Vitality's half")

-- 3. the quiet top-up is quiet: Age's additions pass callLua false, Vitality's do not;
--    nothing loops (every handler refuses its own echo)
local p = newPlayer({ traits = { "age20s", "quickstudy" }, thriving = true })
gain(p, Perks.Fitness, 10)
local quiet, loud = 0, 0
for _, c in ipairs(p._calls) do if c.quiet then quiet = quiet + 1 else loud = loud + 1 end end
assert(quiet == 4 and loud == 1, "four quiet top-ups (Age x2, Quick Study x2), one Vitality addition: got " .. quiet .. "/" .. loud)
near(p._total[Perks.Fitness], 28.5, 1e-9, "and it stops there")

-- 4. the 50s lose a fifth on Fitness: the take-back is seen by nobody (nothing listens
--    to a loss); Age taxes Vitality's addition but not Quick Study's, which goes
--    through Age's own adder and so finds it busy
near(gain(newPlayer({ traits = { "age50s" } }), Perks.Fitness, 10), 0.8, 1e-9, "50s on Fitness: x0.8")
near(gain(newPlayer({ traits = { "age50s", "quickstudy" } }), Perks.Fitness, 10), 1.2, 1e-9, "50s + Quick Study on Fitness: 1 - 0.2 + 0.4")
near(gain(newPlayer({ traits = { "age50s" }, thriving = true }), Perks.Fitness, 10), 1.2, 1e-9, "50s + Thriving: 1 - 0.2 + 0.5 - 0.1 (a fifth of Vitality's half)")
-- never under the level held: at level 1 with 101 XP there is 1 to take, not 2
local held = newPlayer({ traits = { "age50s" }, levels = { [Perks.Fitness] = 1 } })
held._total[Perks.Fitness] = 91
near(gain(held, Perks.Fitness, 10), 10, 1e-9, "101 XP at level 1 (100 held): 1 taken back, total 100")

H.pass()
