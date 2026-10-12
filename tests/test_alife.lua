
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
-- Offline test for DanTraits_ALife.lua (Project A-Life compatibility): the
-- phantom guard. With A-Life absent it installs nothing. With it present,
-- three of A-Life's gates (horde steering, attack policy, the sight check)
-- refuse a live Schizophrenia phantom and pass every other zombie through
-- untouched, a missing gate is skipped, and a second install does not wrap
-- twice. Also here: a phantom another mod un-parks is parked again on the
-- next tick (DanTraits_Hallucinations.lua). And NPC hits: A-Life's three ways
-- of hurting the player are measured and reported as one hit each
-- (DanTraits_MeasureHit -> DanTraits_OtherHit -> Concussion's head scale and
-- Brittle's roll), never twice when nested, not at all when the game reported
-- the hit itself, and an attack on anyone else passes straight through.
H.events()
H.stubs()
function ZombRand(a, b) return 0 end
function isClient() return false end
function isServer() return false end
function getCell() return { getGridSquare = function(_, x, y, z)
  return { getX = function() return x end, getY = function() return y end, getZ = function() return z end,
    isFree = function() return true end, isCanSee = function() return true end, isOutside = function() return true end,
    getObjects = function() return { size = function() return 0 end } end }
end } end

local spawned
function addZombiesInOutfit()
  local z = { useless = false, removed = 0 }
  for _, n in ipairs({ "setCollidable", "setSolid", "setInvincible", "setAvoidDamage", "setNoTeeth", "setWalkType",
      "setSpeedTypeFromWalkType", "faceThisObject", "setTarget", "playSound", "setAlpha", "setTargetAlpha",
      "pathToLocationF" }) do z[n] = function() end end
  z.setUseless = function(_, v) z.useless = v end
  z.isUseless = function() return z.useless end
  z.DistTo = function() return 6 end
  z.isAttacking = function() return false end
  z.getTarget = function() return nil end
  z.removeFromWorld = function() z.removed = z.removed + 1 end
  z.removeFromSquare = function() z.removed = z.removed + 1 end
  spawned = z
  return { size = function() return 1 end, get = function() return z end }
end

H.load("Hallucinations", "ALife")
local tick = H.on("OnTick")
local player = H.player({ traits = { "schizophrenia" } })
player.getForwardDirection = function() return { getX = function() return 1 end, getY = function() return 0 end } end
player.getX = function() return 100 end
player.getY = function() return 50 end
player.getCurrentSquare = function() return { isOutside = function() return true end } end
player.getModData = function() return {} end
player.isPerformingAttackAnimation = function() return false end

-- 1. no A-Life: nothing to install, and a later install still works
ProjectALife = nil
DanTraits_ALifeInstall()

-- 2. A-Life present (its Perception gate missing, as in an older build)
local calls = { steers = 0, attack = 0 }
ProjectALife = {
  HordeRelations = { steersHere = function(zombie) calls.steers = calls.steers + 1; return true end },
  TargetPolicy = { canAttack = function(target, stamp) calls.attack = calls.attack + 1; return true, stamp end },
  Perception = {},
}
DanTraits_ALifeInstall()
assert(ProjectALife.Perception.quietRefuses == nil, "a missing gate is not invented")

assert(DanTraits_episodeCharge(player) == true, "phantom spawned")
local phantom, zombie = spawned, {}
assert(DanTraits_IsPhantom(phantom) and not DanTraits_IsPhantom(zombie), "phantom known, a plain zombie is not")

assert(ProjectALife.HordeRelations.steersHere(phantom) == false and calls.steers == 0, "horde never steers a phantom")
assert(ProjectALife.HordeRelations.steersHere(zombie) == true and calls.steers == 1, "horde steers a plain zombie")
local ok, why = ProjectALife.TargetPolicy.canAttack(phantom)
assert(ok == false and why == "target_phantom" and calls.attack == 0, "NPCs never attack a phantom")
ok, why = ProjectALife.TargetPolicy.canAttack(zombie, "stamp")
assert(ok == true and why == "stamp" and calls.attack == 1, "other targets pass through, arguments and results intact")

-- 3. a second install does not wrap again
DanTraits_ALifeInstall()
ProjectALife.HordeRelations.steersHere(zombie)
assert(calls.steers == 2, "wrapped once")

-- 4. un-parked by another mod: parked again on the next tick
assert(phantom.useless == true, "parked at spawn")
phantom.useless = false
tick(); assert(phantom.useless == true and phantom.removed == 0, "parked again, still charging")

-- 5. once it is gone it is a zombie like any other (the reuse pool hands it out again)
for i = 1, 240 do tick() end
assert(phantom.removed == 2 and not DanTraits_IsPhantom(phantom), "released")
assert(ProjectALife.HordeRelations.steersHere(phantom) == true, "a released body is steered again")

-- 6. hits: the three ways in, measured by what they take off the body
local heads, limbs = {}, {}
DanTraits_HeadHit = function(p, lost) heads[#heads + 1] = lost end
DanTraits_BrittleHit = function(p, damage) limbs[#limbs + 1] = damage end
local function part(name)
  local x = { _name = name, _health = 100 }
  function x:getType() return self._name end
  function x:getHealth() return self._health end
  return x
end
local head, chest = part("Head"), part("Torso_Upper")
local victim = H.player({ parts = { head, chest } }); H.current = victim
local someone = H.player({})

local strikes = 0
ProjectALife = {
  Combat = { resolveAttack = function(actor, shell, target, shove, reaction)
    strikes = strikes + 1
    if target == victim then head._health = head._health - 12; chest._health = chest._health - 3 end
    return true, reaction
  end },
  ModuleGunner = { grazePlayer = function(shell, weapon, body)
    if body == victim then chest._health = chest._health - 5 end
    return true
  end },
  Executor = { woundPlayer = function(victimArg, weaponType, weapon, part)
    if victimArg == victim then chest._health = chest._health - 4 end
    return true
  end },
}
DanTraits_ALifeInstall = nil
H.load("ALife")
DanTraits_ALifeInstall()

local ok2, reaction = ProjectALife.Combat.resolveAttack({}, {}, victim, false, "Shot")
assert(ok2 == true and reaction == "Shot" and strikes == 1, "the attack runs, results intact")
assert(#heads == 1 and heads[1] == 12 and #limbs == 1 and limbs[1] == 15, "a blow to the head: 12 off the head, 15 in all")
assert(ProjectALife.ModuleGunner.grazePlayer({}, {}, victim) == true, "graze runs")
assert(#heads == 1 and limbs[2] == 5, "a graze on the chest: Brittle hears 5, the head nothing")
ProjectALife.Executor.woundPlayer(victim, "Base.Pistol", nil, 4)
assert(limbs[3] == 4, "a relayed wound: 4")

-- an attack on an NPC or a zombie, or on another player, passes through unmeasured
ProjectALife.Combat.resolveAttack({}, {}, someone, false)
ProjectALife.Combat.resolveAttack({}, {}, {}, false)
assert(strikes == 3 and #limbs == 3 and #heads == 1, "other targets: no hit reported")

-- nothing taken off (a miss, a shove): no hit
local before = #limbs
assert(DanTraits_MeasureHit(victim, function() return "missed" end) == "missed", "result passed back")
assert(#limbs == before and #heads == 1, "no damage: nothing reported")

-- nested: an attack that ends in the wound function is one hit, not two
local inner = ProjectALife.Executor.woundPlayer
local outerOriginal = function(actor, shell, target) chest._health = chest._health - 2; inner(target, "Base.Bat", nil, -1); return true end
local outer = function(...) return DanTraits_MeasureHit(victim, outerOriginal, ...) end
outer({}, {}, victim)
assert(#limbs == before + 1 and limbs[#limbs] == 6, "nested calls: one hit of 2 + 4")

-- the game reported the hit itself (Hit fires WEAPONHIT): not counted again
DanTraits_MeasureHit(victim, function() chest._health = chest._health - 7; H.fire("OnPlayerGetDamage", victim, "WEAPONHIT", 7) end)
assert(#limbs == before + 1, "a hit the game reported: not doubled")
-- ...but a bleeding tick meanwhile does not count as that
DanTraits_MeasureHit(victim, function() chest._health = chest._health - 3; H.fire("OnPlayerGetDamage", victim, "BLEEDING", 0.1) end)
assert(limbs[#limbs] == 3, "a bleeding report meanwhile: still measured")

-- an error in A-Life's function reaches its caller, and the next hit is still measured
local okE, err = pcall(DanTraits_MeasureHit, victim, function() error("boom") end)
assert(not okE and tostring(err):find("boom"), "the error passes on")
ProjectALife.ModuleGunner.grazePlayer({}, {}, victim)
assert(limbs[#limbs] == 5, "measuring again after an error")
H.pass()
