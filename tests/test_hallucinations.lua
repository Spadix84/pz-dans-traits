-- Offline test for DanTraits_SchizoChance in DanTraits_Hallucinations.lua: the
-- chance an episode starts (per ten minutes): the base, vanilla stress,
-- unhappiness, tiredness and night, and the mod's own signals (a wound
-- infection's fever). Each signal is read from its getter when that is loaded.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local hour = 12
function getGameTime() return { getHour = function() return hour end } end

H.load("Hallucinations")
H.expectEvery("ten", "Hallucinations")

local newPlayer = H.factory({ traits = { "schizophrenia" } })
local near = H.near
local p = newPlayer(); H.current = p
local chance = DanTraits_SchizoChance

-- 1. the vanilla terms
near(chance(p), 0.12, 1e-9, "base, by day, calm")
p._st.stress = 1; near(chance(p), 0.42, 1e-9, "full stress +0.30"); p._st.stress = 0
p._st.unhappy = 100; near(chance(p), 0.32, 1e-9, "full unhappiness +0.20"); p._st.unhappy = 0
p._st.fatigue = 1; near(chance(p), 0.32, 1e-9, "full fatigue +0.20"); p._st.fatigue = 0
hour = 23; near(chance(p), 0.20, 1e-9, "night +0.08"); hour = 12

-- 2. a fever is delirium: +0.30 at full fever, nothing when Infection is not loaded
DanTraits_InfectionFever = function() return 1 end
near(chance(p), 0.42, 1e-9, "full fever +0.30")
DanTraits_InfectionFever = function() return 0.5 end
near(chance(p), 0.27, 1e-9, "half fever +0.15")
DanTraits_InfectionFever = nil
near(chance(p), 0.12, 1e-9, "no Infection: nothing")

-- 3. the mod's own signals: sleep debt +0.25, concussion +0.20, alcohol withdrawal +0.30, each only when its getter is loaded
local debt, concussion, withdrawal = 0, 0, 0
DanTraits_SleepDebt = function() return debt end
DanTraits_ConcussionStrength = function() return concussion end
DanTraits_AlcoholWithdrawal = function() return withdrawal end
near(chance(p), 0.12, 1e-9, "getters loaded, all quiet: the base")
debt = 1; near(chance(p), 0.37, 1e-9, "full sleep debt +0.25"); debt = 0
concussion = 1; near(chance(p), 0.32, 1e-9, "full concussion +0.20"); concussion = 0
withdrawal = 1; near(chance(p), 0.42, 1e-9, "full withdrawal +0.30"); withdrawal = 0.5
near(chance(p), 0.27, 1e-9, "half withdrawal +0.15"); withdrawal = 0
debt, concussion, withdrawal = 1, 1, 1
DanTraits_InfectionFever = function() return 1 end
near(chance(p), 0.12 + 0.25 + 0.20 + 0.30 + 0.30, 1e-9, "all four together")
DanTraits_InfectionFever = nil
DanTraits_SleepDebt, DanTraits_ConcussionStrength, DanTraits_AlcoholWithdrawal = nil, nil, nil
near(chance(p), 0.12, 1e-9, "none loaded: the base")

-- 4. the panic bout is the harshest: roll < 15 is a bout, but not for a character already down (a concussion or a fever):
-- that roll becomes a whisper (panic +8 rather than +35)
local function episode(setup)
  local q = newPlayer(); H.current = q
  setup()
  H.rng = { 0, 0 }; H.ten(); H.rng = {}
  return q._st.panic
end
assert(episode(function() end) >= 35, "well: a panic bout")
DanTraits_ConcussionStrength = function() return 0.4 end
assert(episode(function() end) == 8, "concussed: a whisper instead")
DanTraits_ConcussionStrength = function() return 0 end
DanTraits_InfectionFever = function() return 0.4 end
assert(episode(function() end) == 8, "feverish: a whisper instead")
DanTraits_InfectionFever = function() return 0 end
assert(episode(function() end) >= 35, "recovered: a panic bout again")
DanTraits_ConcussionStrength, DanTraits_InfectionFever = nil, nil

H.pass()
