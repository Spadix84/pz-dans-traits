-- Offline test for DanTraits_Brittle.lua: a hit under 2 damage never fractures; a roll under 20
-- fractures one of the six limbs (fracture time 40..79) with a notice; a limb that is already
-- fractured is skipped; no trait, no effect.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Brittle")
H.expectHooks("OnPlayerGetDamage")

local LIMBS = { "ForeArm_L", "ForeArm_R", "LowerLeg_L", "LowerLeg_R", "Hand_L", "Hand_R" }

local function limb(name, fractureTime)
  local p = { _name = name, _fracture = fractureTime or 0 }
  function p:getType() return self._name end
  function p:getFractureTime() return self._fracture end
  function p:setFractureTime(t) self._fracture = t end
  return p
end

local function limbs(fractured)
  local list = {}
  for _, n in ipairs(LIMBS) do list[#list + 1] = limb(n, fractured and fractured[n]) end
  return list
end

local newPlayer = H.factory({ traits = { "brittle" } })
local halo = H.halo
local hit = H.on("OnPlayerGetDamage")

-- 1. under 2 damage: not even a roll
local parts = limbs()
local p = newPlayer({ parts = parts }); H.current = p
H.rolls = 0
hit(p, "BLUNT", 1.9); hit(p, "BLUNT", nil); hit(p, "BLUNT", 0)
assert(H.rolls == 0, "a light hit does not roll")
for _, x in ipairs(parts) do assert(x._fracture == 0, "nothing fractured") end
assert(#halo == 0, "no notice")

-- 2. a solid hit but the roll is 20 or more: safe
H.rng = { 20 }; hit(p, "BLUNT", 5)
for _, x in ipairs(parts) do assert(x._fracture == 0, "roll 20: safe") end
H.rng = { 99 }; hit(p, "BLUNT", 5)
for _, x in ipairs(parts) do assert(x._fracture == 0, "roll 99: safe") end
assert(#halo == 0, "still no notice")

-- 3. roll 19 fractures exactly the picked limb, time 40 + the second roll
for index = 0, 5 do
  local ps = limbs()
  local q = newPlayer({ parts = ps }); H.current = q
  H.clearHalo()
  H.rng = { 19, index, 39 }; hit(q, "BLUNT", 2)
  for i, x in ipairs(ps) do
    if i == index + 1 then assert(x._fracture == 79, LIMBS[i] .. " fractured at 40 + 39, got " .. x._fracture)
    else assert(x._fracture == 0, LIMBS[i] .. " untouched") end
  end
  assert(halo[#halo] == "UI_DanTraits_BrittleSnap" and #halo == 1, "one snap notice")
end
local lo = limbs(); local q = newPlayer({ parts = lo }); H.current = q
H.rng = { 0, 0, 0 }; hit(q, "BLUNT", 2)
assert(lo[1]._fracture == 40, "fracture time floor is 40, got " .. lo[1]._fracture)

-- 4. the picked limb is already fractured: skipped, no notice, time not reset
local broken = limbs({ Hand_L = 55 })
local r = newPlayer({ parts = broken }); H.current = r
H.clearHalo()
H.rng = { 0, 4, 7 }; hit(r, "BLUNT", 9)
assert(broken[5]._fracture == 55, "an already-fractured limb keeps its time")
assert(#halo == 0, "no notice when nothing new snaps")
for i, x in ipairs(broken) do if i ~= 5 then assert(x._fracture == 0, "no other limb picked") end end

-- 5. the limb is missing from the body: nothing happens
local none = newPlayer({ parts = {} }); H.current = none
H.rng = { 0, 0, 0 }; hit(none, "BLUNT", 9)
assert(#halo == 0, "no such limb: no notice")

-- 6. without the trait: no roll at all
local plain = limbs()
local other = newPlayer({ traits = {}, parts = plain }); H.current = other
H.rolls = 0; hit(other, "BLUNT", 30)
assert(H.rolls == 0, "no trait: no roll")
for _, x in ipairs(plain) do assert(x._fracture == 0, "no trait: nothing fractures") end

H.pass()
