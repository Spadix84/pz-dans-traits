local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
-- Offline test for DanTraits_Bandits.lua (Bandits compatibility). With Bandits
-- absent it installs nothing. With it present: a live Schizophrenia phantom is
-- taken back out of Bandits' zombie lists and parked again on every zombie
-- update (after Bandits' own handler), a plain zombie or bandit is left alone;
-- a bandit hit (BanditServer.Commands.PlayerDamage) is reported once with its
-- healthDrop, all of it on the head for a head hit, nothing for a graze or a
-- shot clothing stopped, nothing for another player; and the report reaches
-- Brittle and Concussion through DanTraits_OtherHit.
H.events()
H.stubs()
function isClient() return false end
function isServer() return false end
BodyPartType.ToIndex = function(t) return t == "Head" and 0 or 5 end
function getCell() return { getGridSquare = function(_, x, y, z)
  return { getX = function() return x end, getY = function() return y end, getZ = function() return z end,
    isFree = function() return true end, isCanSee = function() return true end, isOutside = function() return true end,
    getObjects = function() return { size = function() return 0 end } end }
end } end

local spawned
local function body(id)
  local z = { id = id, useless = false, removed = 0 }
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
  return z
end
function addZombiesInOutfit()
  spawned = body(77)
  return { size = function() return 1 end, get = function() return spawned end }
end

H.load("Hallucinations", "Brittle", "Faint", "Concussion", "Bandits")
local player = H.player({ traits = { "schizophrenia" } })
player.getForwardDirection = function() return { getX = function() return 1 end, getY = function() return 0 end } end
player.getX = function() return 100 end
player.getY = function() return 50 end
player.getCurrentSquare = function() return { isOutside = function() return true end } end
player.isPerformingAttackAnimation = function() return false end
H.current = player

-- 1. no Bandits: nothing installed
BanditZombie = nil
DanTraits_BanditsInstall()
assert(H.handlers.OnZombieUpdate == nil or #H.handlers.OnZombieUpdate == 0, "no zombie handler without Bandits")

-- 2. Bandits present: its own handler first (as at game start), then ours
local function cacheAdd(z)
  for _, key in ipairs({ "Cache", "CacheLight" }) do BanditZombie[key][z.id] = z end
  if z.bandit then BanditZombie.CacheLightB[z.id] = z else BanditZombie.CacheLightZ[z.id] = z end
  if not z.bandit then z.useless = false end   -- Bandits' UpdateZombies un-parks every plain zombie
end
BanditZombie = { Cache = {}, CacheLight = {}, CacheLightZ = {}, CacheLightB = {} }
BanditUtils = { GetZombieID = function(z) return z.id end }
local damageCalls = {}
BanditServer = { Commands = { PlayerDamage = function(p, args) damageCalls[#damageCalls + 1] = args; return "done" end } }
Events.OnZombieUpdate.Add(cacheAdd)
DanTraits_BanditsInstall()
DanTraits_BanditsInstall()
assert(#H.handlers.OnZombieUpdate == 2, "one handler of ours, after Bandits'")
local update = H.on("OnZombieUpdate")

assert(DanTraits_episodeCharge(player) == true, "phantom spawned")
local phantom, zombie, bandit = spawned, body(1), body(2)
bandit.bandit = true
update(phantom); update(zombie); update(bandit)
for _, key in ipairs({ "Cache", "CacheLight", "CacheLightZ", "CacheLightB" }) do
  assert(BanditZombie[key][77] == nil, "phantom out of " .. key)
end
assert(phantom.useless == true, "phantom parked again after Bandits woke it")
assert(BanditZombie.CacheLightZ[1] == zombie and zombie.useless == false, "a plain zombie stays a target, awake")
assert(BanditZombie.CacheLightB[2] == bandit, "a bandit stays a bandit")

-- once it is gone it is a zombie like any other
for i = 1, 240 do H.fire("OnTick") end
assert(phantom.removed == 2, "released")
update(phantom)
assert(BanditZombie.CacheLightZ[77] == phantom, "a released body is listed again")

-- 3. bandit hits: reported once, by healthDrop, all on the head for a head hit
local heads, limbs = {}, {}
local realHead, realBrittle = DanTraits_HeadHit, DanTraits_BrittleHit
DanTraits_HeadHit = function(p, lost) heads[#heads + 1] = lost end
DanTraits_BrittleHit = function(p, damage) limbs[#limbs + 1] = damage end
local hit = function(p, args) return BanditServer.Commands.PlayerDamage(p, args) end

assert(hit(player, { bodyPartIndex = 5, healthDrop = 10, cut = true }) == "done", "Bandits' command still runs, result intact")
assert(#damageCalls == 1 and damageCalls[1].cut == true, "its args reach it")
assert(#heads == 0 and limbs[1] == 10, "a body shot: Brittle hears 10, the head nothing")
hit(player, { bodyPartIndex = 0, healthDrop = 75, bullet = true })
assert(heads[1] == 75 and limbs[2] == 75, "a head shot: all 75 on the head")
hit(player, { bodyPartIndex = 3, scratched = true })
hit(player, { bodyPartIndex = 3, hole = true, holeAllLayers = false })
hit(player, { bodyPartIndex = 3, healthDrop = 0 })
assert(#limbs == 2 and #heads == 1, "a graze or a stopped shot: no hit")
local other = H.player({})
hit(other, { bodyPartIndex = 0, healthDrop = 20 })
assert(#limbs == 2 and #heads == 1, "another player: no hit")
assert(#damageCalls == 6, "every command reached Bandits")

-- 4. through to the real systems: a bandit bat to the head concusses (certain at 20), a body blow can snap a Brittle limb
DanTraits_HeadHit, DanTraits_BrittleHit = realHead, realBrittle
local function part(name)
  local x = { _name = name, _health = 100, _fracture = 0 }
  function x:getType() return self._name end
  function x:getHealth() return self._health end
  function x:getFractureTime() return self._fracture end
  function x:setFractureTime(t) self._fracture = t end
  return x
end
local arm = part("ForeArm_L")
local brittle = H.player({ traits = { "brittle" }, parts = { arm } })
brittle.getBodyPartClothingDefense = function() return 0 end
H.current = brittle
H.rng = { 0, 0, 10 }
hit(brittle, { bodyPartIndex = 5, healthDrop = 8 })
assert(arm._fracture == 50, "a bandit blow rolls Brittle: the arm snaps")
H.rollf = 0
hit(brittle, { bodyPartIndex = 0, healthDrop = 20 })
local d = brittle._md.DanTraits
assert(d and (d.ccScore or 0) > 0, "a bandit blow to the head: concussed")
assert(DanTraits_HeadHit(other, 20) == 0, "the head scale is the local player's only")
H.pass()
