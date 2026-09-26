local handlers = {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) handlers[k] = f end }; rawset(t, k, e); return e end })
BodyPartType = { Groin = "Groin", ForeArm_L=1, ForeArm_R=2, LowerLeg_L=3, LowerLeg_R=4, Hand_L=5, Hand_R=6, Torso_Upper=7 }
CharacterStat = { INTOXICATION = "intox", STRESS = "stress", PAIN = "pain", UNHAPPINESS = "unhappy", FATIGUE = "fatigue", PANIC = "panic", ENDURANCE = "endurance", WETNESS = { getMaximumValue = function() return 100 end } }
HaloTextHelper = { addBadText = function() end, addGoodText = function() end }
function getText(k) return k end
DanTraitsRegistry = { schizophrenia = "schizophrenia" }
ArrayList = { new = function() return { add = function() end } end }
IsoFireManager = { explode = function() end }
function instanceof() return false end
function getWorld() return { getFreeEmitter = function() return { playSound = function() return 1 end, setPos = function() end } end } end
function getGameTime() return { getHour = function() return 12 end } end
function ZombRand(a, b) return 0 end
local mp = false
function isClient() return mp end
function isServer() return false end

-- squares: free & visible unless blocked
local blocked = false
function getCell() return { getGridSquare = function(_, x, y, z)
  if blocked then return nil end
  return { _x = x, _y = y, getX = function() return x end, getY = function() return y end, getZ = function() return z end,
    isFree = function() return true end, isCanSee = function() return true end, isOutside = function() return true end,
    getObjects = function() return { size = function() return 0 end } end }
end } end

local spawned = {}
local zdist = 6
local function makeZombie(x, y)
  local z = { calls = {}, alpha = 1, attacking = false, removed = 0 }
  local function rec(name) return function(_, ...) z.calls[name] = { ... } end end
  for _, n in ipairs({ "setCollidable", "setSolid", "setInvincible", "setAvoidDamage", "setNoTeeth", "setWalkType", "setSpeedTypeFromWalkType", "faceThisObject", "setTarget", "spottedNew", "playSound", "setTargetAlpha", "setReanimatedForGrappleOnly", "setUseless" }) do z[n] = rec(n) end
  z.paths = {}
  z.pathToLocationF = function(_, x, y, zz) z.paths[#z.paths + 1] = { x, y, zz } end
  z.setAlpha = function(_, pn, a) z.alpha = a end
  z.DistTo = function() return zdist end
  z.isAttacking = function() return z.attacking end
  z.target = nil
  z.getTarget = function() return z.target end
  z.removeFromWorld = function() z.removed = z.removed + 1 end
  z.removeFromSquare = function() z.removed = z.removed + 1 end
  return z
end
function addZombiesInOutfit(x, y, z, n, outfit, fem, ...)
  local zomb = makeZombie(x, y); spawned[#spawned + 1] = { zomb = zomb, x = x, y = y, longform = select("#", ...) > 0 }
  return { size = function() return 1 end, get = function() return zomb end }
end

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Dependent", "DanTraits_MDD", "DanTraits_Brittle", "DanTraits_Fumbler", "DanTraits_Jinxed", "DanTraits_BadDay", "DanTraits_Hallucinations", "DanTraits_Asthma", "DanTraits_Gluten", "DanTraits_Vegetarian", "DanTraits_Diabetes" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.OnTick, "tick hook")
local panic = 0
local player = { getForwardDirection = function() return { getX = function() return 1 end, getY = function() return 0 end } end,
  getX = function() return 100 end, getY = function() return 50 end, getZ = function() return 0 end,
  getCurrentSquare = function() return { isOutside = function() return true end } end, getPlayerNum = function() return 0 end,
  getStats = function() return { get = function(_, k) return k == "panic" and panic or 0 end, set = function(_, k, v) if k == "panic" then panic = v end end } end,
  hasTrait = function(_, t) return t == "schizophrenia" end, isDead = function() return false end, getModData = function() return {} end,
  attacking = false, isPerformingAttackAnimation = function(self) return self.attacking end, isAttacking = function() return true end }

-- 1. spawns 7 tiles ahead as a non-combatant sprinter that only paths to the player; panic added
assert(DanTraits_episodeCharge(player) == true, "charge spawned")
local s1 = spawned[1]; local z = s1.zomb
assert(s1.x == 107 and s1.y == 50, "7 tiles ahead: " .. s1.x .. "," .. s1.y)
assert(s1.longform, "invulnerable long form used")
assert(z.calls.setReanimatedForGrappleOnly == nil and z.calls.setUseless[1] == true, "useless, never grapple-only")
assert(z.calls.setCollidable[1] == false and z.calls.setSolid[1] == false, "no collision")
assert(z.calls.setInvincible[1] == true and z.calls.setAvoidDamage[1] == true and z.calls.setNoTeeth[1] == true, "cannot hurt or be hurt")
assert(z.calls.setWalkType[1] == "sprint1" and z.calls.setSpeedTypeFromWalkType, "sprinter")
assert(z.calls.setTarget == nil and z.calls.spottedNew == nil, "never given a target")
assert(#z.paths == 1 and z.paths[1][1] == 100 and z.paths[1][2] == 50, "paths to the player position")
assert(z.calls.playSound[1] == "MaleZombieVoiceA", "zombie vocal")
assert(panic == 15, "panic +15, got " .. panic)

-- 2. far away: re-aims every 10 frames, no fade; from 4 tiles it fades over 30 frames, re-applied on render, then removed
for i = 1, 20 do handlers.OnTick() end
assert(#z.paths == 3 and z.alpha == 1 and z.removed == 0, "re-pathed twice, no fade at 6 tiles (paths=" .. #z.paths .. ")")
zdist = 4.0
for i = 1, 15 do handlers.OnTick() end
assert(z.alpha > 0 and z.alpha < 1 and z.removed == 0, "fading: alpha " .. z.alpha)
z.alpha = 1; handlers.OnRenderTick(); assert(z.alpha < 1, "render tick re-applies the faded alpha")
for i = 1, 14 do handlers.OnTick() end
assert(z.alpha > 0 and z.removed == 0, "still fading")
handlers.OnTick(); assert(z.removed == 2, "faded out and removed from world and square")
assert(z.alpha == 1 and z.calls.setTargetAlpha[2] == 1, "alpha restored before release to the reuse pool")
assert(z.calls.setUseless[1] == false, "useless flag cleared before release")
assert(z.calls.setCollidable[1] == true and z.calls.setSolid[1] == true and z.calls.setInvincible[1] == false and z.calls.setAvoidDamage[1] == false and z.calls.setNoTeeth[1] == false, "combat and collision flags restored before release")
handlers.OnRenderTick(); assert(z.alpha == 1, "render tick no longer touches a released zombie")
handlers.OnTick(); assert(z.removed == 2, "removed only once")

-- 3. arrives (1.6 tiles) or somehow starts an attack: gone at once
zdist = 6; spawned = {}
assert(DanTraits_episodeCharge(player)); local z2 = spawned[1].zomb
zdist = 1.5; handlers.OnTick(); assert(z2.removed == 2, "removed on arrival")
zdist = 6; spawned = {}
assert(DanTraits_episodeCharge(player)); local z3 = spawned[1].zomb
z3.attacking = true; handlers.OnTick(); assert(z3.removed == 2, "removed if an attack ever starts")

-- 3b. the player swings, or the phantom somehow acquires a target: gone at once
zdist = 6; spawned = {}
assert(DanTraits_episodeCharge(player)); local z5 = spawned[1].zomb
player.attacking = true; handlers.OnTick(); assert(z5.removed == 2, "removed when the player attacks"); player.attacking = false
spawned = {}
assert(DanTraits_episodeCharge(player)); local z6 = spawned[1].zomb
z6.setTarget = function(_, t) z6.target = t end
z6.target = player; handlers.OnTick(); assert(z6.removed == 0 and z6.target == nil, "a target the game assigned is cleared, not fatal")
zdist = 1.6; handlers.OnTick(); assert(z6.removed == 2, "gone at 1.6 tiles, outside attack reach")

-- 4. never arrives: removed after the frame cap (fade starts 30 frames before)
spawned = {}; assert(DanTraits_episodeCharge(player)); local z4 = spawned[1].zomb
for i = 1, 239 do handlers.OnTick() end
assert(z4.removed == 2, "removed at the frame cap (" .. z4.removed .. ")")

-- 5. no usable square, or multiplayer: episode declines so the caller falls back to a sound
blocked = true; assert(DanTraits_episodeCharge(player) == false, "no square -> false"); blocked = false
mp = true; assert(DanTraits_episodeCharge(player) == false, "multiplayer -> false"); mp = false
print("phantom charge tests passed")
