-- Offline test for Dan's Vanilla Fixes cold packs and coolers
-- (DansVanillaFixes/42/media/lua/shared/DansVanillaFixes_Coolers.lua and
-- client/DansVanillaFixes_CoolersClient.lua): charging in a freezer, a fridge
-- and the cold air, warming up loose, packs in a cooler adding up, the food
-- ageing at the fridge rate while the cooler is cold, the names, and the
-- watch list.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local HERE = arg[0]:match("^(.*)[/\\]") or "."
local ROOT = HERE .. "/../DansVanillaFixes/42/media/lua/"

local TEXT = { IGUI_DVF_PackFrozen = "Frozen", IGUI_DVF_PackCold = "Cold", IGUI_DVF_PackCool = "Cool",
  IGUI_DVF_CoolerCold = "Cold, %1 h" }
getText = function(k, a) return (TEXT[k] or k):gsub("%%1", tostring(a)) end
SandboxVars = { FridgeFactor = 3, FoodRotSpeed = 3, DansVanillaFixes = { ColdPackHours = 6 } }
local hours = 100
getGameTime = function() return { getWorldAgeHours = function() return hours end } end
local air = 20
getClimateManager = function() return { getAirTemperatureForSquare = function() return air end } end

-- a square, containers and items, just enough of each
local square = { getX = function() return 1 end, getY = function() return 2 end, getZ = function() return 0 end }
local loadedSquare = square
getCell = function() return { getGridSquare = function() return loadedSquare end } end

local function list(t)
  return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end
local function container(o)
  o = o or {}
  local c = { items = {}, kind = o.kind, powered = o.powered, holder = o.holder, who = o.who, parent = o.parent }
  function c:getItems() return list(self.items) end
  function c:getContainingItem() return self.holder end
  function c:isPowered() return self.powered == true end
  function c:isFridge() return self.kind == "fridge" end
  function c:isFreezer() return self.kind == "freezer" end
  function c:getCharacter() return self.who end
  function c:getVehiclePart() return nil end
  function c:getParent() return self.parent end
  function c:getSourceGrid() return square end
  return c
end
local NAMES = { ["Base.Coldpack"] = "Cold Pack", ["Base.Cooler"] = "Cooler", ["Base.Milk"] = "Milk",
  ["Base.Beans"] = "Beans", ["Base.Bag_Schoolbag"] = "School Bag" }
local nextId = 0
local function item(fullType, o)
  o = o or {}
  nextId = nextId + 1
  local it = { fullType = fullType, md = {}, name = NAMES[fullType], id = nextId, custom = false,
    age = o.age or 0, offAgeMax = o.offAgeMax or 5, frozen = o.frozen, food = o.food, world = o.world }
  function it:getFullType() return self.fullType end
  function it:getID() return self.id end
  function it:getModData() return self.md end
  function it:getName() return self.name end
  function it:setName(n) self.name = n end
  function it:setCustomName(b) self.custom = b end
  function it:getScriptItem() local n = NAMES[self.fullType]; return { getDisplayName = function() return n end } end
  function it:getWorldItem() return self.world end
  function it:getContainer() return self.container end
  function it:getAge() return self.age end
  function it:setAge(a) self.age = a end
  function it:getOffAgeMax() return self.offAgeMax end
  function it:isFrozen() return self.frozen == true end
  function it:IsInventoryContainer() return self.inv ~= nil end
  function it:getInventory() return self.inv end
  function it:getOutermostContainer()   -- vanilla: walk up, stop below the floor
    if self.world then return nil end
    local c = self.container
    while c and c.holder do
      if c.holder.world then return c end
      c = c.holder.container
    end
    return c
  end
  if fullType == "Base.Cooler" or fullType == "Base.Bag_Schoolbag" then it.inv = container({ holder = it }) end
  return it
end
local function put(c, it) c.items[#c.items + 1] = it; it.container = c; return it end
local function take(c, it)
  for i, v in ipairs(c.items) do if v == it then table.remove(c.items, i) end end
  it.container = nil
end
instanceof = function(o, cls) return cls == "Food" and o.food == true end

local player = { getCurrentSquare = function() return square end, getVehicle = function() return nil end,
  isDead = function() return false end }
local pinv = container({ who = player })
player.getInventory = function() return pinv end
getNumActivePlayers = function() return 1 end
getSpecificPlayer = function() return player end

require = function() end
dofile(ROOT .. "shared/DansVanillaFixes_Coolers.lua")
dofile(ROOT .. "client/DansVanillaFixes_CoolersClient.lua")
local C = DVF_Coolers
H.expectHooks("OnGameBoot", "EveryTenMinutes", "OnRefreshInventoryWindowContainers")
local function chill(it) return it.md[C.KEY].c end

-- the step function: freezer, fridge, the air
H.near(C.stepPack(0, 2, "freezer", nil, 6), 3, 1e-9, "freezer: half full in 2 of its 4 h")
H.near(C.stepPack(0, 10, "freezer", nil, 6), 6, 1e-9, "freezer: stops at full")
H.near(C.stepPack(0, 1.5, "fridge", nil, 6), 1.5, 1e-9, "fridge: half its share in 1.5 h")
H.near(C.stepPack(0, 10, "fridge", nil, 6), 3, 1e-9, "fridge: stops at half")
H.near(C.stepPack(6, 4, "fridge", nil, 6), 4.5, 1e-9, "fridge: a frozen pack thaws towards half")
H.near(C.stepPack(6, 100, "fridge", nil, 6), 3, 1e-9, "fridge: ... and stops there")
H.near(C.stepPack(6, 1, "air", 20, 6), 3, 1e-9, "warm air: half gone in an hour")
H.near(C.stepPack(6, 5, "air", 20, 6), 0, 1e-9, "warm air: warm in two")
H.near(C.stepPack(2, 10, "air", 3, 6), 2, 1e-9, "cold air: holds")
H.near(C.stepPack(0, 4, "air", -5, 6), 3, 1e-9, "freezing air: half in 4 of 8 h")
assert(not C.packChanging(6, "freezer", nil, 6) and C.packChanging(5, "freezer", nil, 6), "changing: freezer")
assert(not C.packChanging(0, "air", 20, 6) and not C.packChanging(2, "air", 3, 6) and C.packChanging(2, "air", 20, 6),
  "changing: air")

-- a pack in a powered freezer, then in an unpowered one (just a box at room temperature)
local freezer = container({ kind = "freezer", powered = true, parent = { getSquare = function() return square end } })
local pack = put(freezer, item("Base.Coldpack"))
assert(C.settle(pack) == true and chill(pack) == 0, "first sight: warm, and charging")
assert(pack.name == "Cold Pack" and not pack.custom, "warm pack keeps its name")
hours = hours + 4
assert(C.settle(pack) == false, "full: nothing more to do")
H.near(chill(pack), 6, 1e-9, "freezer fills in 4 h")
assert(pack.name == "Cold Pack (Frozen)" and pack.custom, "named Frozen")
freezer.powered = false
hours = hours + 0.5
C.settle(pack)
H.near(chill(pack), 4.5, 1e-9, "power off: room air thaws it")
assert(pack.name == "Cold Pack (Frozen)", "still Frozen at 75%")
hours = hours + 0.5
C.settle(pack)
assert(pack.name == "Cold Pack (Cold)", "Cold at half")
hours = hours + 0.9
C.settle(pack)
assert(pack.name == "Cold Pack (Cool)", "Cool when nearly warm")
hours = hours + 1
C.settle(pack)
assert(chill(pack) == 0 and pack.name == "Cold Pack" and not pack.custom, "warm again, plain name")

-- a name the player chose is left alone
pack.name = "Bob"
pack.md[C.KEY].c = 6
C.settle(pack)
assert(pack.name == "Bob", "renamed pack keeps its name")
pack.name = "Cold Pack"

-- three packs in a cooler (on the floor) last three times as long, and the
-- food in it ages at the fridge rate
local floorWorld = { getSquare = function() return square end }
local cooler = item("Base.Cooler", { world = floorWorld })
local packs = {}
for i = 1, 3 do
  packs[i] = put(cooler.inv, item("Base.Coldpack"))
  C.state(packs[i], hours).c = 6
end
packs[3].md[C.KEY].c = 3        -- one from a fridge
local milk = put(cooler.inv, item("Base.Milk", { food = true, age = 1, offAgeMax = 5 }))
local beans = put(cooler.inv, item("Base.Beans", { food = true, age = 1, offAgeMax = 1000000000 }))
local fish = put(cooler.inv, item("Base.Milk", { food = true, age = 1, offAgeMax = 5, frozen = true }))
assert(C.settle(cooler) == true, "cold cooler keeps changing")
assert(cooler.name == "Cooler (Cold, 15 h)", "cooler shows its hours: " .. cooler.name)
hours = hours + 10
milk.age = milk.age + 10 / 24    -- what vanilla adds over the same 10 h
assert(C.settle(packs[1]) == true, "settling a pack in a cooler settles the cooler")
H.near(chill(packs[3]), 0, 1e-9, "smallest pack drains first")
H.near(chill(packs[1]) + chill(packs[2]), 5, 1e-9, "15 h less 10")
H.near(milk.age, 1 + 10 * 0.2 / 24, 1e-6, "milk aged at the fridge rate (0.2)")
assert(beans.age == 1 and fish.age == 1, "food that never spoils, and frozen food, untouched")
assert(cooler.name == "Cooler (Cold, 5 h)", "hours count down")
hours = hours + 8
milk.age = milk.age + 8 / 24
assert(C.settle(cooler) == false, "out of cold")
H.near(milk.age, 1 + 15 * 0.2 / 24 + 3 / 24, 1e-6, "cold for 5 of the 8 h, then the normal rate")
assert(cooler.name == "Cooler" and not cooler.custom and packs[1].name == "Cold Pack", "plain names again")

-- the sandbox sets the fridge rate and the rot speed
SandboxVars.FridgeFactor = 6
SandboxVars.FoodRotSpeed = 1
local m2 = item("Base.Milk", { food = true, age = 2 })
C.coolFood(m2, 24)
H.near(m2.age, 2 - 1.7, 1e-6, "fridge factor 0 at rot speed 1.7: no ageing at all")
SandboxVars.FridgeFactor, SandboxVars.FoodRotSpeed = 3, 3
C.coolFood(m2, 1000)
assert(m2.age == 0, "age never goes below zero")

-- a cooler in a powered fridge: its packs charge there, the food is the fridge's
local fridge = container({ kind = "fridge", powered = true, parent = { getSquare = function() return square end } })
local c2 = put(fridge, item("Base.Cooler"))
local p2 = put(c2.inv, item("Base.Coldpack"))
local m3 = put(c2.inv, item("Base.Milk", { food = true, age = 1 }))
assert(C.place(p2) == "fridge", "a pack in a cooler in a fridge is in the fridge")
C.settle(c2)
hours = hours + 3
C.settle(p2)
H.near(chill(p2), 3, 1e-9, "charged to the fridge's half")
assert(m3.age == 1 and c2.name == "Cooler", "no food change, no cold label in a fridge")

-- cold air: a pack carried outdoors in winter
local p3 = put(pinv, item("Base.Coldpack"))
air = -10
C.everyTen()
hours = hours + 8
C.everyTen()
H.near(chill(p3), 6, 1e-9, "eight hours out below freezing fills it")
air = 20
take(pinv, p3)

-- bag recursion and the ten-minute tick for what the player carries
local bag = put(pinv, item("Base.Bag_Schoolbag"))
local p4 = put(bag.inv, item("Base.Coldpack"))
C.everyTen()
p4.md[C.KEY].c = 6
hours = hours + 1
C.everyTen()
H.near(chill(p4), 3, 1e-9, "pack in a bag on the player warms up on the tick")

-- the watch list: a world cooler seen in a loot window stays watched while cold,
-- and drops off when it runs out or leaves the loaded map
local floor = container({})
local c3 = put(floor, item("Base.Cooler", { world = floorWorld }))
local p5 = put(c3.inv, item("Base.Coldpack"))
C.settle(c3)
p5.md[C.KEY].c = 1
C.onRefresh({ backpacks = { { inventory = floor } }, onCharacter = false }, "end")
assert(C.watchCount() >= 1, "cold world cooler watched")
local before = C.watchCount()
hours = hours + 2
C.everyTen()
assert(C.watchCount() == before - 1 and c3.name == "Cooler", "ran out: dropped")
p5.md[C.KEY].c = 6
C.onRefresh({ backpacks = { { inventory = c3.inv } }, onCharacter = false }, "end")
assert(C.watchCount() == before, "a cooler's own window watches it too")
loadedSquare = {}
C.everyTen()
assert(C.watchCount() == before - 1, "unloaded: dropped")
loadedSquare = square
C.onRefresh({ backpacks = { { inventory = floor } }, onCharacter = false }, "begin")
assert(C.watchCount() == before - 1, "only the end of a refresh counts")

-- the test report: carried and nearby packs and coolers, with their food
local fridgeObj = { getContainerCount = function() return 1 end, getContainerByIndex = function() return fridge end }
square.getWorldObjects = function() return list({ { getItem = function() return c3 end } }) end
square.getObjects = function() return list({ fridgeObj }) end
local rep = C.report(player, 0)
assert(rep:find("^h=") and rep:find("Cooler c=") and rep:find("Milk age") and rep:find("air 20.0C") and rep:find(" fridge"),
  "report: " .. rep)

-- other sandbox hours
SandboxVars.DansVanillaFixes.ColdPackHours = 12
assert(C.maxHours() == 12, "sandbox hours")
SandboxVars.DansVanillaFixes = nil
assert(C.maxHours() == 6, "default without the sandbox table")

H.pass("coolers")
