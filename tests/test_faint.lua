-- Offline test for DanTraits_Faint.lua in a vehicle: a fainting driver's
-- engine is cut by the direct call (B42 has no "shutOff" client command, so
-- sending one succeeds and the car drives on with a blacked-out driver; review
-- 2026-10-16 A1.2), a passenger's is not, and there is no fall in a seat. The
-- fall, the sit and the wake are covered end to end in test_concussion.lua.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
UIManager = { FadeOut = function() end, FadeIn = function() end, setFadeBeforeUI = function() end }
local commands = {}
function sendClientCommand(_, module, command) commands[#commands + 1] = module .. ":" .. command end
H.load("Faint")

local newPlayer = H.factory(nil, function(p)
  p.setBlockMovement = function(_, b) p._blocked = b end
  p.setIgnoreMovement = function() end
  p.setAuthorizeMeleeAction = function() end
  p.setAuthorizeShoveStomp = function() end
  p.isSitOnGround = function() return p._sitting == true end
  p.reportEvent = function(_, e) if e == "EventSitOnGround" then p._sitting = true end end
  local limb = { getScratchTime = function() return 0 end, getCutTime = function() return 0 end,
    getBiteTime = function() return 0 end, getDeepWoundTime = function() return 0 end }
  p.getBodyDamage = function() return {
    getBodyParts = function() return { size = function() return 1 end, get = function() return limb end } end } end
end)
local tick = H.on("OnTick")
local function out(p) return DanTraits_IsPassedOut(p) end
local function wake(minutes) H.hours = H.hours + minutes / 60; H.now = H.now + 60000; tick() end
local function car(driver)
  local c = { _on = true }
  function c:getDriver() return driver end
  function c:shutOff() self._on = false end
  return c
end

-- 1. the driver faints: the engine is cut, no fall, no client command
local p = newPlayer(); H.current = p
local mine = car(p)
p.getVehicle = function() return mine end
assert(DanTraits_PassOut(p, 5), "out")
assert(out(p) and p._blocked, "blacked out and held")
assert(mine._on == false, "the driver's engine is cut by car:shutOff()")
assert(#commands == 0, "not through a client command (B42 has no handler for one)")
assert(p._bump == nil, "no fall in a seat")
wake(6); assert(not out(p), "comes round")

-- 2. a passenger faints: the engine runs on
p = newPlayer(); H.current = p
local other = newPlayer()
local theirs = car(other)
p.getVehicle = function() return theirs end
assert(DanTraits_PassOut(p, 5), "out")
assert(theirs._on == true, "a passenger does not stop the car")
wake(6)

-- 3. on foot: the fall
p = newPlayer(); H.current = p
assert(DanTraits_PassOut(p, 5), "out")
assert(p._bump == "stagger", "the fall")
wake(6)

H.pass()
