-- Offline test for DanTraits_SteadyHands.lua: Dexterous granted once,
-- splint and stitch chances halved for the right person, and quicker
-- surgery and splinting.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
CharacterTrait.DEXTROUS = "base:dextrous"
ISStitch = { getDuration = function() return 200 end }
ISRemoveGlass = { getDuration = function() return 100 end }
ISRemoveBullet = { getDuration = function() return 1 end }
ISSplint = { new = function(self, character) return { character = character, maxTime = 120 } end }
H.load("SteadyHands")
H.expectHooks("OnCreatePlayer", "OnGameStart")

local near = H.near
local steady = H.player({ traits = { "steadyhands" } }); H.current = steady
local plain = H.player()

-- 1. Dexterous comes with it, once
H.fire("OnCreatePlayer", 0, steady)
assert(steady._traits["base:dextrous"], "Dexterous granted")
H.fire("OnGameStart")
assert(steady._adds == 1, "granted once")
H.fire("OnCreatePlayer", 0, plain)
assert(not plain._traits["base:dextrous"], "not for others")

-- 2. the setter's splints and the player's stitches
near(DanTraits_RunHooks("splintBadSet", 0.5, steady), 0.25, 1e-9, "bad set halved for a steady setter")
near(DanTraits_RunHooks("splintBadSet", 0.5, plain), 0.5, 1e-9, "anyone else as is")
near(DanTraits_RunHooks("stitchTear", 0.04, steady), 0.02, 1e-9, "stitch tear halved")

-- 3. a quarter quicker at stitching, glass and splints; a 1-tick action untouched
local function run(class, who) return setmetatable({ character = who }, { __index = class }):getDuration() end
near(run(ISStitch, steady), 150, 1e-9, "stitching")
near(run(ISRemoveGlass, steady), 75, 1e-9, "glass")
near(run(ISStitch, plain), 200, 1e-9, "others as is")
near(run(ISRemoveBullet, steady), 1, 1e-9, "instant stays instant")
near(ISSplint:new(steady).maxTime, 90, 1e-9, "splint")
near(ISSplint:new(plain).maxTime, 120, 1e-9, "others' splints as is")

-- 4. shaking hands are not steady: the shakes of alcohol withdrawal or a diabetic low
DanTraits_Data(steady).alcShakes = 3
near(DanTraits_RunHooks("splintBadSet", 0.5, steady), 0.5, 1e-9, "the shakes: a splint like anyone's")
near(run(ISStitch, steady), 200, 1e-9, "and no quicker")
near(DanTraits_RunHooks("stitchTear", 0.04, steady), 0.02, 1e-9, "stitches already in still hold")
DanTraits_Data(steady).alcShakes = 0
DanTraits_DiaLow = function(who) return who == steady and 1 / 3 or 0 end
near(ISSplint:new(steady).maxTime, 120, 1e-9, "low blood sugar: no quicker")
DanTraits_DiaLow = nil
near(ISSplint:new(steady).maxTime, 90, 1e-9, "steady again")

H.pass()
