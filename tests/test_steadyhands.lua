-- Offline test for DanTraits_SteadyHands.lua: Dexterous granted once,
-- splint and stitch chances halved for the right person, and quicker
-- surgery and splinting; a quarter faster to reload, rack, draw and holster.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
CharacterTrait.DEXTROUS = "base:dextrous"
ISStitch = { getDuration = function() return 200 end }
ISRemoveGlass = { getDuration = function() return 100 end }
ISRemoveBullet = { getDuration = function() return 1 end }
ISSplint = { new = function(self, character) return { character = character, maxTime = 120 } end }
-- the game's reload speed: 0.8 at Reloading 0, set for every reload action
ISReloadWeaponAction = { setReloadSpeed = function(character, rack) character:setVariable("ReloadSpeed", rack and 0.8 or 0.9) end }
-- the hotbar actions: an animation speed and a time, worked out in new()
local function hotbarClass(maxTime, keepTime)
    return { new = function(self, character, item, fromHotbar)
        return { character = character, fromHotbar = fromHotbar, animSpeed = fromHotbar and 1.0 or nil, maxTime = keepTime and maxTime or (fromHotbar and -1 or maxTime) }
    end }
end
ISEquipWeaponAction = hotbarClass(20, true)
ISUnequipAction = hotbarClass(20, true)
ISAttachItemHotbar = hotbarClass(30)
ISDetachItemHotbar = nil   -- client-only: not there until the game starts
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

-- 5. reloading and racking a quarter faster: the game's speed, raised after it is set
ISReloadWeaponAction.setReloadSpeed(steady, false)
near(steady._vars.ReloadSpeed, 0.9 * 1.25, 1e-9, "reload speed x1.25")
ISReloadWeaponAction.setReloadSpeed(steady, true)
near(steady._vars.ReloadSpeed, 0.8 * 1.25, 1e-9, "racking too")
ISReloadWeaponAction.setReloadSpeed(plain, false)
near(plain._vars.ReloadSpeed, 0.9, 1e-9, "others reload as is")
DanTraits_Data(steady).alcShakes = 3
ISReloadWeaponAction.setReloadSpeed(steady, false)
near(steady._vars.ReloadSpeed, 0.9, 1e-9, "the shakes: no quicker")
DanTraits_Data(steady).alcShakes = 0

-- 6. to the belt and back a quarter faster; equipping from the inventory as is
local draw = ISEquipWeaponAction:new(steady, nil, true)
near(draw.animSpeed, 1.25, 1e-9, "draw animation x1.25")
near(draw.maxTime, 16, 1e-9, "and its time a fifth shorter")
local holster = ISUnequipAction:new(steady, nil, true)
near(holster.animSpeed, 1.25, 1e-9, "holster animation x1.25")
local attach = ISAttachItemHotbar:new(steady, nil, true)
near(attach.animSpeed, 1.25, 1e-9, "putting a weapon on the belt x1.25")
assert(attach.maxTime == -1, "an animation-timed action stays so")
local pocket = ISEquipWeaponAction:new(steady, nil, false)
assert(pocket.animSpeed == nil and pocket.maxTime == 20, "from the inventory: untouched")
assert(ISEquipWeaponAction:new(plain, nil, true).animSpeed == 1.0, "others draw as they did")
-- the client-only class arrives with the game, and is wrapped then
ISDetachItemHotbar = hotbarClass(25)
H.fire("OnGameStart")
near(ISDetachItemHotbar:new(steady, nil, true).animSpeed, 1.25, 1e-9, "taking a weapon off the belt x1.25, wrapped at game start")
near(ISDetachItemHotbar:new(steady, nil, true).animSpeed, 1.25, 1e-9, "wrapped once, not twice")

H.pass()
