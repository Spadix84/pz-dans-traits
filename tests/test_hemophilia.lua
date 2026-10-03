-- Offline test for DanTraits_Hemophilia.lua: bleeds never run down while
-- unbandaged, open wounds reopen, extra health loss per open bleed, and a
-- bandage stops all of it.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Hemophilia")
H.expectEvery("minute", "Hemophilia")

local function part(o)
  o = o or {}
  local p = { _bleeding = o.bleeding or false, _time = o.time or 0, _bandaged = o.bandaged or false, _stemmed = false,
    _scratched = o.scratched or false, _cut = o.cut or false, _deep = o.deep or false, _stitched = o.stitched or false }
  function p:bleeding() return self._bleeding end
  function p:getBleedingTime() return self._time end
  function p:setBleedingTime(t) self._time = t end
  function p:setBleeding(b) self._bleeding = b end
  function p:bandaged() return self._bandaged end
  function p:IsBleedingStemmed() return self._stemmed end
  function p:stitched() return self._stitched end
  function p:scratched() return self._scratched end
  function p:isCut() return self._cut end
  function p:deepWounded() return self._deep end
  return p
end

local newPlayer = H.factory({ traits = { "hemophilia" } })
local halo = H.halo
local minute = H.minute

-- 1. an unbandaged bleed: its clock is held at the floor and health drops 0.35 a minute
local a = part({ bleeding = true, time = 1.0 })
local p = newPlayer({ parts = { a, part() } }); H.current = p
minute()
assert(a._time == 5.0, "bleeding time held up to 5, got " .. a._time)
assert(math.abs(p._health - 99.65) < 1e-9, "0.35 health per open bleed per minute, got " .. p._health)
assert(p._md.DanTraits.hemoOpen == 1, "one open bleed")
a._time = 8.0; minute(); assert(a._time == 8.0, "a longer clock is left alone")

-- 2. bandaged: no floor, no extra loss
a._bandaged = true; a._time = 1.0; local h = p._health; minute()
assert(a._time == 1.0 and p._health == h and p._md.DanTraits.hemoOpen == 0, "bandaged: vanilla takes over")

-- 3. an unbandaged scratch that is not bleeding starts bleeding again, with a notice; a stitched cut does not
local s = part({ scratched = true })
local st = part({ cut = true, stitched = true })
local q = newPlayer({ parts = { s, st } }); H.current = q
minute()
assert(s._bleeding and s._time == 5.0, "scratch reopened")
assert(not st._bleeding, "stitched: closed")
assert(halo[#halo] == "UI_DanTraits_HemoBleeding", "warned")
local n = #halo; minute(); assert(#halo == n, "warned once per episode")
assert(math.abs(q._health - (100 - 0.7)) < 1e-9, "two minutes of one open bleed")

-- 4. two open bleeds: double the loss; health can reach zero but not below
local b1, b2 = part({ bleeding = true, time = 9 }), part({ bleeding = true, time = 9 })
local r = newPlayer({ parts = { b1, b2 } }); H.current = r
minute(); assert(math.abs(r._health - 99.3) < 1e-9, "two bleeds: 0.7 a minute")
r._health = 0.5; minute(); assert(r._health == 0, "clamped at zero")

-- 5. no trait: nothing
local x = part({ bleeding = true, time = 1.0 })
local none = newPlayer({ traits = {}, parts = { x } }); H.current = none
minute(); assert(x._time == 1.0 and none._health == 100, "no trait: untouched")

-- 6. the blood hook: open x1.5, a clean bandage x4 (a tenth becomes two fifths),
--    and a soaked bandage or one over a shard never worse than no bandage
local function bleed(pl, rate, bandaged, open) return DanTraits_RunHooks("bloodBleed", rate, pl, a, bandaged, open) end
local function near(v, want, msg) assert(math.abs(v - want) < 1e-12, msg .. ": got " .. v .. ", want " .. want) end
near(bleed(p, 0.01, false, 0.01), 0.015, "open: x1.5")
near(bleed(p, 0.001, true, 0.01), 0.004, "clean bandage: two fifths")
near(bleed(p, 0.005, true, 0.01), 0.015, "soaked bandage: capped at the open rate, not x2")
near(bleed(p, 0.0035, true, 0.01), 0.014, "bandage over a shard: x1.4, under the cap")
near(bleed(p, 0.005, true, nil), 0.02, "no open rate given: x4 as before")
near(bleed(none, 0.005, true, 0.01), 0.005, "no trait: as is")

H.pass()
