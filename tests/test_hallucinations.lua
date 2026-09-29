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

H.pass()
