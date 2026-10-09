-- Offline test for DanTraits_Knox.lua: Resilient's hidden roll against the
-- Knox infection (sandbox KnoxSurviveChance, 25 by default), made once per
-- infection; a lucky one is cleared (parts, body, clock, infection and fever
-- stats) when the infection has run its break point, with a notice; an
-- unlucky one is left to vanilla; no roll without Resilient; a new infection
-- rolls again; the console command.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Knox")
H.expectEvery("minute", "Knox")

local minute = H.minute

-- a body that can be infected: one arm, the body's flag, clock and mortality
local function newPlayer(o)
  o = o or {}
  local p = H.player({ vanilla = o.vanilla })
  local arm = { _inf = o.infected or false }
  function arm:getType() return "ForeArm_L" end
  function arm:IsInfected() return self._inf end
  function arm:SetInfected(b) self._inf = b end
  p._arm = arm
  p._bd = { infected = o.infected or false, time = o.infected and 5 or -1, mort = o.infected and 48 or -1 }
  p.getBodyDamage = function()
    return {
      isInfected = function() return p._bd.infected end,
      setInfected = function(_, b) p._bd.infected = b end,
      setInfectionTime = function(_, v) p._bd.time = v end,
      setInfectionMortalityDuration = function(_, v) p._bd.mort = v end,
      pickMortalityDuration = function() return 48 end,
      getBodyParts = function() return { size = function() return 1 end, get = function() return arm end } end,
      getBodyPart = function() return arm end,
    }
  end
  H.current = p
  return p
end
local function D(p) return p._md.DanTraits end

-- 1. lucky: rolled once, hidden; nothing before the break point (0.55 with the harness's midpoint)
local p = newPlayer({ vanilla = { "base:resilient" }, infected = true })
H.rng = { 0 }
H.clearHalo()
p._st.zinf = 30; minute()
assert(D(p).knox and D(p).knox.lucky == true, "rolled lucky")
H.near(D(p).knox.breakAt, 0.55, 1e-9, "breaks between 40% and 70%")
assert(p._bd.infected and #H.halo == 0, "still sick, and nothing said")
local rolls = H.rolls
p._st.zinf = 50; minute(); assert(p._bd.infected and H.rolls == rolls, "not yet; no second roll")
p._st.zinf = 60; p._st.zfever = 40; minute()
assert(not p._bd.infected and not p._arm._inf, "the body and the arm cleared")
assert(p._bd.time == -1 and p._bd.mort == -1, "the clock reset")
assert(p._st.zinf == 0 and p._st.zfever == 0, "infection and fever stats at 0")
assert(H.halo[1] == "+UI_DanTraits_KnoxBeaten", "a good notice")
assert(D(p).knox == nil, "forgotten")

-- 2. unlucky: left to vanilla, right to the end
local u = newPlayer({ vanilla = { "base:resilient" }, infected = true })
H.rng = { 999999 }
u._st.zinf = 99; minute()
assert(D(u).knox.lucky == false and u._bd.infected, "unlucky: still infected at 99%")
minute(); assert(u._bd.infected, "and stays so")

-- 3. no Resilient: no roll at all
local n = newPlayer({ infected = true })
rolls = H.rolls
n._st.zinf = 90; minute()
assert(H.rolls == rolls and (D(n) == nil or D(n).knox == nil) and n._bd.infected, "no trait: no roll")

-- 4. a new infection rolls again
u._bd.infected = false; H.current = u; minute()
assert(D(u).knox == nil, "healthy: the roll is forgotten")
u._bd.infected = true; u._st.zinf = 10; H.rng = { 0 }; minute()
assert(D(u).knox.lucky == true, "the next infection rolls fresh")

-- 5. the sandbox chance: 0 never, 100 always
SandboxVars = { DanTraits = { KnoxSurviveChance = 0 } }
local z = newPlayer({ vanilla = { "base:resilient" }, infected = true }); H.rng = { 0 }; minute()
assert(D(z).knox.lucky == false, "0%: never")
SandboxVars = { DanTraits = { KnoxSurviveChance = 100 } }
local a = newPlayer({ vanilla = { "base:resilient" }, infected = true }); H.rng = { 999999 }; minute()
assert(D(a).knox.lucky == true, "100%: always")
SandboxVars = nil

-- 6. the console: infect, force the roll, jump the infection
local c = newPlayer({ vanilla = { "base:resilient" } })
local text = DanTraits_ExtraCommands.knox(c, { "infect" })
assert(c._bd.infected and c._arm._inf and c._bd.mort == 48, "knox infect: " .. text)
DanTraits_ExtraCommands.knox(c, { "lucky" })
text = DanTraits_ExtraCommands.knox(c, { "jump", "60" })
assert(c._st.zinf == 60 and text:find("lucky true", 1, true), text)
minute(); assert(not c._bd.infected, "a forced lucky roll breaks at 60%")
assert(DanTraits_ExtraCommands.knox(c, {}):find("not rolled", 1, true), "status")

H.pass()
