
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
-- Offline test for DanTraits_ALife.lua (Project A-Life compatibility): the
-- phantom guard. With A-Life absent it installs nothing. With it present,
-- three of A-Life's gates (horde steering, attack policy, the sight check)
-- refuse a live Schizophrenia phantom and pass every other zombie through
-- untouched, a missing gate is skipped, and a second install does not wrap
-- twice. Also here: a phantom another mod un-parks is parked again on the
-- next tick (DanTraits_Hallucinations.lua).
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
H.pass()
