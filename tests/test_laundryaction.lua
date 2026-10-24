-- Offline test for shared/TimedActions/ISLaundryAction.lua (the six kinds: bleach,
-- fire, protect, putup, takedown, sheet: new, isValid, start, update, stop, perform) and the
-- world-object menus of client/DanTraits_LaundryClient.lua (the clothesline menu,
-- the water source's Freshen and Bleach, the fire's Dry by the Fire, and the
-- inventory menu's Protect Fabric), fired through OnFillWorldObjectContextMenu and
-- OnFillInventoryObjectContextMenu as the game does. test_laundry.lua covers the
-- laundry rules the action calls; nothing there loads the action or clicks a menu.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }

local function list(t)
  return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end

-- the game's classes by `kind`; a bag or the player's inventory by its item list
instanceof = function(o, cls)
  if cls == "ItemContainer" then return type(o) == "table" and (o.getItems or o.AddItem) ~= nil end
  return type(o) == "table" and o.kind == cls
end

-- a garment: per-part blood and dirt (0..1), totals counted the game's way
local function garment(parts, opts)
  opts = opts or {}
  local g = { kind = "Clothing", blood = {}, dirt = {}, names = {}, bloodLevel = 0, dirtiness = 0,
              wet = opts.wet or 0, md = {}, cond = 10, type = opts.type or "Base.Tshirt_White", jobDelta = -1 }
  for name, v in pairs(parts or {}) do
    g.names[#g.names + 1] = name
    g.blood[name], g.dirt[name] = v[1], v[2]
  end
  table.sort(g.names)
  function g:getBloodClothingType() return self.names end
  function g:getCoveredParts() return list(self.names) end
  function g:getBlood(p) return self.blood[p] end
  function g:getDirt(p) return self.dirt[p] end
  function g:setBlood(p, v) self.blood[p] = v end
  function g:setDirt(p, v) self.dirt[p] = v end
  function g:setBloodLevel(v) self.bloodLevel = v end
  function g:setDirtiness(v) self.dirtiness = v end
  function g:getDirtiness() return self.dirtiness end
  function g:getBloodlevel() return self.bloodLevel end
  function g:isBloody() return self.bloodLevel > 0 end
  function g:getWetness() return self.wet end
  function g:setWetness(v) self.wet = v end
  function g:updateWetness() end
  function g:getModData() return self.md end
  function g:getBodyLocation() return "base:tshirt" end
  function g:getCondition() return self.cond end
  function g:setCondition(v) self.cond = v end
  function g:getFullType() return self.type end
  function g:getName() return "Garment" end
  function g:setJobDelta(d) self.jobDelta = d end
  function g:setJobType(t) self.jobType = t end
  function g:getContainer() return { Remove = function() g.removed = true end } end
  return g
end
local function totals(item, field, key)
  local sum = 0
  for _, p in ipairs(item.names) do sum = sum + item[field][p] end
  item[key] = #item.names > 0 and sum / #item.names * 100 or 0
end
BloodClothingType = {
  getCoveredParts = function(names) return list(names) end,
  calcTotalBloodLevel = function(item) totals(item, "blood", "bloodLevel") end,
  calcTotalDirtLevel = function(item) totals(item, "dirt", "dirtiness") end,
}
local synced = 0
syncItemFields = function() synced = synced + 1 end
syncVisuals = function() end

-- other carried things: a bottle of bleach, a can of fabric protector, line materials
local function thing(fullType)
  local it = { kind = "Normal", type = fullType, md = {} }
  function it:getFullType() return self.type end
  function it:getModData() return self.md end
  function it:setJobDelta(d) self.jobDelta = d end
  function it:setJobType(t) self.jobType = t end
  -- removing it from its container takes it off whoever carries it
  function it:getContainer()
    return { Remove = function()
      it.removed = true
      local carried = it.owner and it.owner._carried or {}
      for i, x in ipairs(carried) do if x == it then table.remove(carried, i); break end end
    end }
  end
  return it
end
Fluid = { Bleach = "bleach" }
local function bottle(litres)
  local it = thing("Base.BleachBottle")
  it.litres = litres
  local fc = { contains = function(_, f) return f == "bleach" and it.litres > 0 end, getAmount = function() return it.litres end,
               Empty = function() it.litres = 0 end, adjustAmount = function(_, v) it.litres = v end }
  function it:getFluidContainer() return fc end
  return it
end
local function protector(uses)
  local it = thing("DanTraits.FabricProtector")
  it.uses = uses
  function it:getCurrentUses() return self.uses end
  function it:Use() self.uses = self.uses - 1 end
  return it
end

-- vanilla's wash and wring actions (LaundryWash wraps them at load), the menu class
-- the client wraps, the action queue, the walks, the menus
ISWashClothing = { complete = function() return true end, getDuration = function() return 200 end,
                   GetSoapRemaining = function(soaps) return soaps and soaps.uses or 0 end, GetRequiredWater = function() return 6 end }
ISWringClothing = { complete = function() return true end, isValid = function() return true end, getDuration = function() return 50 end }
local washCalls = {}
ISWorldObjectContextMenu = {
  onWashClothing = function(playerObj, sink, soapList, washList, single) washCalls[#washCalls + 1] = { sink = sink, list = washList, single = single } end,
  addToolTip = function() return {} end,
  fetchVars = {},
}
local queue = {}
ISTimedActionQueue = { add = function(a) queue[#queue + 1] = a; return a end }
ISWalkToTimedAction = { new = function(_, playerObj, sq) return { Type = "walk", sq = sq } end }
ISInventoryPaneContextMenu = { transferIfNeeded = function() end }
ISInventoryPane = { getActualItems = function(items) return items end }
luautils = { walkAdj = function() return true end, walkAdjObject = function() return true end }
local function newContext()
  local ctx = { options = {}, subs = {} }
  function ctx:addOption(name, target, fn, ...)
    local o = { name = name, target = target, fn = fn, args = { ... } }
    self.options[#self.options + 1] = o
    return o
  end
  function ctx:addSubMenu(parent, sub) self.subs[parent] = sub end
  function ctx:find(name) for _, o in ipairs(self.options) do if o.name == name then return o end end end
  function ctx:click(name)
    local o = assert(self:find(name), "no option " .. name)
    return o.fn(o.target, table.unpack(o.args))
  end
  return ctx
end
ISContextMenu = { getNew = function() return newContext() end }
Metabolics = { LightDomestic = "light" }
CharacterActionAnims = { Craft = "Craft" }
DanShared_Tooltip = { add = function() end }

-- the base class: derive gives a class whose new() builds instances; jobDelta is set by the test
ISBaseTimedAction = {}
function ISBaseTimedAction:derive(name)
  local c = { Type = name }
  c.__index = c
  setmetatable(c, self)
  self.__index = self
  return c
end
function ISBaseTimedAction:new(character)
  local o = setmetatable({}, self)
  o.character = character
  return o
end
function ISBaseTimedAction:getJobDelta() return self._delta or 0 end
function ISBaseTimedAction:perform() self._performed = (self._performed or 0) + 1 end
function ISBaseTimedAction:stop() self._stopped = (self._stopped or 0) + 1 end
function ISBaseTimedAction:setActionAnim(a) self._anim = a end
function ISBaseTimedAction:setAnimVariable(k, v) self._animVar = v end
function ISBaseTimedAction:setOverrideHandModels() end

-- squares, world objects and line containers (as test_laundry.lua's clothesline section)
local grid = {}
local function square(x, y, opts)
  opts = opts or {}
  local sq = { x = x, y = y, objs = {}, floor = true, free = opts.free ~= false, dropped = {} }
  function sq:getX() return self.x end
  function sq:getY() return self.y end
  function sq:getZ() return 0 end
  function sq:hasFloor() return self.floor end
  function sq:isFree() return self.free end
  function sq:getObjects() return list(self.objs) end
  function sq:AddTileObject(o) self.objs[#self.objs + 1] = o end
  function sq:RemoveTileObject(o) for i, x in ipairs(self.objs) do if x == o then table.remove(self.objs, i) end end end
  function sq:transmitRemoveItemFromSquare() end
  function sq:AddWorldInventoryItem(item) self.dropped[#self.dropped + 1] = item end
  grid[x .. "," .. y] = sq
  return sq
end
getCell = function() return { getGridSquare = function(_, x, y) return grid[x .. "," .. y] end } end
isServer = function() return false end
getSprite = function(name) return { name = name } end
IsoObject = { new = function(a1, a2, a3)
  local sq, sprite = a2, a3   -- (cell, square, sprite) or (square, name)
  if a3 == nil then sq, sprite = a1, { name = a2 } end
  local o = { sq = sq, sprite = sprite.name, md = {} }
  function o:getSprite() return { getName = function() return o.sprite end } end
  function o:getSquare() return o.sq end
  function o:getModData() return o.md end
  function o:getContainer() return o.c end
  function o:setContainer(c) o.c = c end
  return o
end }
ItemContainer = { new = function(_, sq, parent)
  local c = { items = {} }
  function c:setCapacity(n) self.cap = n end
  function c:setExplored() end
  function c:getItems() return list(self.items) end
  function c:Remove(item) for i, x in ipairs(self.items) do if x == item then table.remove(self.items, i) end end end
  return c
end }
-- a plain object standing on a square (what a right-click on the ground hands the menu)
local function groundObject(sq)
  local o = { kind = "IsoObject", sq = sq }
  function o:getSquare() return self.sq end
  function o:getModData() return {} end
  function o:getSprite() return nil end
  sq.objs[#sq.objs + 1] = o
  return o
end
local function fireplace(sq, lit)
  local o = { kind = "IsoFireplace", sq = sq, lit = lit }
  function o:getSquare() return self.sq end
  function o:isLit() return self.lit end
  function o:getModData() return {} end
  function o:getSprite() return nil end
  sq.objs[#sq.objs + 1] = o
  return o
end
local function sink(water)
  local s = { water = water }
  function s:hasWater() return true end
  function s:getFluidAmount() return self.water end
  function s:useFluid(n) self.water = self.water - n end
  return s
end

H.load("Laundry", "LaundryWash", "LaundryDry", "LaundryGear", "client/DanTraits_LaundryClient.lua",
       "shared/TimedActions/ISLaundryAction.lua")
local L = DanTraits_Laundry
assert(ISLaundryAction and ISLaundryAction.Type == "ISLaundryAction", "the action class is derived")
H.expectHooks("OnFillWorldObjectContextMenu", "OnFillInventoryObjectContextMenu")

-- a character: what is carried, what is worn (worn items are carried too), what was done to them
local function person()
  local p = H.player()
  p._carried, p._wornList, p._faced, p._added, p._instant = {}, {}, 0, {}, false
  p.getInventory = function()
    return {
      getItems = function() return list(p._carried) end,
      containsRecursive = function(_, it) for _, x in ipairs(p._carried) do if x == it then return true end end return false end,
      getSoapList = function() return p._soaps end,
      AddItem = function(_, t) p._added[#p._added + 1] = t end,
    }
  end
  p.getWornItems = function()
    return { size = function() return #p._wornList end, getItemByIndex = function(_, i) return p._wornList[i + 1] end }
  end
  p.isEquippedClothing = function(_, it) for _, x in ipairs(p._wornList) do if x == it then return true end end return false end
  p.isTimedActionInstant = function() return p._instant end
  p.faceThisObject = function() p._faced = p._faced + 1 end
  p.setMetabolicTarget = function(_, m) p._met = m end
  return p
end
local function carry(p, it) p._carried[#p._carried + 1] = it; it.owner = p; return it end
local function wear(p, g) p._wornList[#p._wornList + 1] = g; return carry(p, g) end
local function menu(p, worldobjects, test)
  H.current = p
  local ctx = newContext()
  H.fire("OnFillWorldObjectContextMenu", 0, ctx, worldobjects, test == true)
  return ctx
end
local function stained(g)
  L.state(g, true).st = { Torso = 0.2 }
  return g
end
local halo = H.halo

-- 1. new(): the kind sets the label, the time and what the character faces; instant actions take a tick
do
  local p = person()
  local shirt, bleach, basin = garment({ Torso = { 0.6, 0.5 } }), bottle(0.3), sink(10)
  local a = ISLaundryAction:new(p, shirt, "bleach", basin, bleach, 6)
  assert(a.kind == "bleach" and a.bleach == bleach and a.faceTo == basin and a.water == 6, "bleach: the bottle, the sink, the water")
  assert(a.label == "ContextMenu_DanTraits_BleachStains" and a.maxTime == 300 and a.stopOnWalk and a.stopOnRun, "bleach: label and time")
  local fire = fireplace(square(11, 10), true)
  local wet = garment({}, { wet = 100 })
  local f = ISLaundryAction:new(p, wet, "fire", fire)
  assert(f.startWet == 100 and f.maxTime == 2000 and f.faceTo == fire and f.label == "ContextMenu_DanTraits_DryByFire", "fire: 100 wetness at 0.05 a tick is 2000 ticks")
  wet.wet = 2
  assert(ISLaundryAction:new(p, wet, "fire", fire).maxTime == 60, "fire: never under 60 ticks")
  local g = ISLaundryAction:new(p, shirt, "protect", nil, protector(1))
  assert(g.agent and g.maxTime == 150 and g.label == "ContextMenu_DanTraits_ProtectFabric", "protect: the agent")
  local u = ISLaundryAction:new(p, thing("Base.LongStick"), "putup", square(20, 20), "ew")
  assert(u.dir == "ew" and u.maxTime == 400 and u.label == "ContextMenu_DanTraits_PutUpLine", "putup: the direction")
  local post = IsoObject.new(square(21, 21), "appliances_laundry_01_26")
  local t = ISLaundryAction:new(p, nil, "takedown", post)
  assert(t.item == nil and t.faceTo == post and t.maxTime == 200, "takedown: no item, faces the post")
  p._instant = true
  assert(ISLaundryAction:new(p, shirt, "bleach", basin, bleach, 6).maxTime == 1, "instant actions take one tick")
end

-- 2. bleach: valid with 0.1 l of bleach carried and the water for a wash in the sink
do
  local p = person()
  local shirt, bleach, basin = carry(p, stained(garment({ Torso = { 0.6, 0.5 } }))), carry(p, bottle(0.3)), sink(10)
  shirt.bloodLevel = 60   -- the game's own total for the one part
  local a = ISLaundryAction:new(p, shirt, "bleach", basin, bleach, 6)
  assert(a:isValid(), "valid")
  bleach.litres = 0.05; assert(not a:isValid(), "not enough bleach"); bleach.litres = 0.3
  basin.water = 5; assert(not a:isValid(), "not enough water"); basin.water = 10
  p._carried = { shirt }; assert(not a:isValid(), "the bottle was put down"); p._carried = { shirt, bleach }
  p._carried = { bleach }; assert(not a:isValid(), "the shirt was put down"); p._carried = { shirt, bleach }
  assert(not ISLaundryAction:new(p, shirt, "bleach", basin, nil, 6):isValid(), "no bottle at all")
  -- start, a tick, perform: the stain and all the blood out, dirt to the soap floor, soaked,
  -- a tenth of a litre of bleach and the wash's water gone, the laundryWashed hook told
  local washed = {}
  DanTraits_AddHook("laundryWashed", function(_, who, item, how, bloody) washed[#washed + 1] = { who = who, item = item, how = how, bloody = bloody } end)
  a:start()
  assert(a._anim == "ScrubClothWithSoap" and shirt.jobType == a.label and shirt.jobDelta == 0, "start: the scrub animation, the job on the item")
  a._delta = 0.4; a:update()
  assert(shirt.jobDelta == 0.4 and p._faced == 1 and p._met == "light", "update: the bar, facing the sink, light work")
  H.clearHalo()
  a:perform()
  assert(shirt.blood.Torso == 0 and not L.hasStain(shirt), "blood and stain out")
  H.near(shirt.dirt.Torso, 0.2, 1e-9, "dirt to the hand-and-soap floor")
  assert(shirt.wet == 100 and shirt.jobDelta == 0, "soaked, the bar cleared")
  H.near(bleach.litres, 0.2, 1e-9, "a tenth of a litre of bleach used")
  assert(basin.water == 4, "the wash's water used")
  assert(halo[#halo] == "+UI_DanTraits_Bleached", "the notice")
  assert(#washed == 1 and washed[1].who == p and washed[1].item == shirt and washed[1].how == "bleach" and washed[1].bloody == true, "laundryWashed: bleach, and it was bloody")
  assert(a._performed == 1 and synced == 1, "the base perform ran once, the item synced")
  -- the last of the bottle empties it; stop clears the bar
  bleach.litres, basin.water = 0.1, 10
  local b = ISLaundryAction:new(p, shirt, "bleach", basin, bleach, 6)
  assert(b:isValid(), "exactly 0.1 l is enough")
  b._delta = 0.5; b:update(); b:stop()
  assert(shirt.jobDelta == 0 and b._stopped == 1, "stop: the bar cleared, the base stop ran")
  b:perform(); assert(bleach.litres == 0, "the bottle is empty")
end

-- 3. fire: valid while a lit fire is within reach; the garment dries as the bar fills
do
  local p = person()
  local sq = square(11, 10)
  local fire = fireplace(sq, true)
  local wet = carry(p, garment({}, { wet = 100 }))
  L.state(wet, true).dh = 5
  local a = ISLaundryAction:new(p, wet, "fire", fire)
  assert(a:isValid(), "lit and next to it")
  fire.lit = false; assert(not a:isValid(), "the fire went out"); fire.lit = true
  fire.sq = square(14, 14); assert(not a:isValid(), "too far"); fire.sq = sq
  p._carried = {}; assert(not a:isValid(), "the garment was put down"); p._carried = { wet }
  a:start()
  assert(a._anim == "Loot" and a._animVar == "", "the loot animation")
  a._delta = 0.5; a:update()
  assert(wet.wet == 50, "half way: half dry")
  a._delta = 0.25; a:update()
  assert(wet.wet == 50, "the bar never wets it again")
  a._delta = 0.9; a:update()
  H.near(wet.wet, 10, 1e-9, "nine tenths")
  a:perform()
  assert(wet.wet == 0 and L.state(wet).dh == nil, "dry, and the damp clock is cleared")
end

-- 4. protect: one use of the carried protector treats the garment
do
  local p = person()
  local shirt, can = carry(p, garment({})), carry(p, protector(1))
  local a = ISLaundryAction:new(p, shirt, "protect", nil, can)
  assert(a:isValid(), "a use left")
  can.uses = 0; assert(not a:isValid(), "empty"); can.uses = 1
  p._carried = { shirt }; assert(not a:isValid(), "put down"); p._carried = { shirt, can }
  a:start(); assert(a._anim == "Craft", "the craft animation")
  H.clearHalo()
  a:perform()
  assert(can.uses == 0 and L.state(shirt).pr == 1 and halo[#halo] == "+UI_DanTraits_Protected", "one use gone, the garment treated, the notice")
end

-- 5. putup and takedown: the line's five squares must be clear floor; the posts go up
--    on perform; a built post can be taken down, a wire or a map post cannot
local row = {}
for x = 30, 34 do row[#row + 1] = square(x, 30) end
square(30, 31, { free = false })
square(30, 29)   -- beside the first post: somewhere to stand
do
  local p = person()
  local a0 = ISLaundryAction:new(p, nil, "putup", row[1], "ew")
  assert(not a0:isValid(), "no materials")
  local sticks = { carry(p, thing("Base.LongStick")), carry(p, thing("Base.Plank")) }
  carry(p, thing("Base.Rope")); carry(p, thing("Base.Twine"))
  local a = ISLaundryAction:new(p, sticks[1], "putup", row[1], "ew")
  assert(a:isValid(), "two posts, two ties, five clear squares")
  assert(not ISLaundryAction:new(p, sticks[1], "putup", row[1], "ns"):isValid(), "north-south: blocked")
  row[3].free = false; assert(not a:isValid(), "someone stood on the line"); row[3].free = true
  a:start(); assert(a._anim == "Loot" and a._animVar == "Mid", "the mid loot animation")
  H.clearHalo()
  a:perform()
  assert(row[1].objs[1] and row[1].objs[1].sprite == "appliances_laundry_01_26" and row[5].objs[1].sprite == "appliances_laundry_01_27", "posts at both ends")
  assert(row[3].objs[1].md.dtlWire, "wire between")
  assert(sticks[1].removed and sticks[2].removed, "the materials are used")
  assert(halo[#halo] == "+UI_DanTraits_LineUp", "the notice")
  local post, wire = row[1].objs[1], row[3].objs[1]
  local t = ISLaundryAction:new(p, nil, "takedown", post)
  assert(t:isValid(), "a built post comes down")
  assert(not ISLaundryAction:new(p, nil, "takedown", wire):isValid(), "a wire is not the handle")
  local loose = IsoObject.new(nil, "appliances_laundry_01_26"); loose.md.dtlBuilt = true
  assert(not ISLaundryAction:new(p, nil, "takedown", loose):isValid(), "a post off the map")
  t:perform()
  for n = 1, 5 do assert(#row[n].objs == 0, "square " .. n .. " cleared") end
  assert(#p._added == 4, "two sticks and two twine back")
end

-- 6. the clothesline menu: offered on the ground with the materials to hand, the blocked
--    direction greyed; clicking walks to a square off the line and queues the action;
--    on a built line the menu offers to take it down instead
do
  local p = person()
  local ground = groundObject(row[1])
  local ctx = menu(p, { ground })
  assert(ctx:find("ContextMenu_DanTraits_PutUpLine") == nil, "no materials: nothing offered")
  carry(p, thing("Base.LongStick")); carry(p, thing("Base.LongStick")); carry(p, thing("Base.Twine")); carry(p, thing("Base.Twine"))
  ctx = menu(p, { ground })
  local parent = assert(ctx:find("ContextMenu_DanTraits_PutUpLine"), "offered with the materials")
  assert(parent.toolTip and parent.toolTip.description == "Tooltip_DanTraits_ClotheslineBuild", "the parent explains")
  local sub = assert(ctx.subs[parent], "with a sub menu")
  local ew, ns = assert(sub:find("ContextMenu_DanTraits_Line_ew")), assert(sub:find("ContextMenu_DanTraits_Line_ns"))
  assert(not ew.notAvailable, "east-west is clear")
  assert(ns.notAvailable and ns.toolTip.description == "Tooltip_DanTraits_LineBlocked", "north-south is greyed, and says why")
  queue = {}
  sub:click("ContextMenu_DanTraits_Line_ew")
  assert(#queue == 2 and queue[1].Type == "walk" and queue[1].sq == grid["30,29"], "first a walk to the square beside the post, off the line")
  local act = queue[2]
  assert(act.Type == "ISLaundryAction" and act.kind == "putup" and act.source == row[1] and act.dir == "ew" and act.item == p._carried[1], "then the action")
  assert(act:isValid(), "and it is valid as queued")
  act:perform()
  assert(#p._carried == 0, "the materials left the inventory")
  -- a right-click on the post's square: take it down, and no second line is offered there
  ctx = menu(p, { ground })
  assert(ctx:find("ContextMenu_DanTraits_PutUpLine") == nil, "no second line on top of the first")
  queue = {}
  ctx:click("ContextMenu_DanTraits_TakeDownLine")
  assert(#queue == 1 and queue[1].kind == "takedown" and queue[1].source == row[1].objs[2] and L.isBuiltLine(queue[1].source), "take-down queued on the post")
  assert(queue[1]:isValid(), "valid")
  queue[1]:perform()
  assert(#row[1].objs == 1 and row[1].objs[1] == ground, "the line is gone, the ground object stays")
  -- off, or the game's test pass: nothing
  assert(#menu(p, { ground }, true).options == 0, "the test pass adds nothing")
  SandboxVars.DanTraits.LaundryClotheslines = false
  assert(menu(p, { ground }):find("ContextMenu_DanTraits_PutUpLine") == nil, "clotheslines off: not offered")
  SandboxVars.DanTraits.LaundryClotheslines = nil
end

-- 7. the water source: Freshen Up for stale clean garments (worn ones too), Bleach
--    Stains for stained ones, greyed without bleach; the clicks
do
  local p = person()
  local basin = sink(10)
  local stale = carry(p, garment({ Torso = { 0, 0 } })); L.state(stale, true).o = 60
  local wornStale = wear(p, garment({ Torso = { 0, 0 } })); L.state(wornStale, true).o = 90
  local marked = carry(p, stained(garment({ Torso = { 0.2, 0 } }))); marked.bloodLevel = 20
  carry(p, garment({ Torso = { 0, 0 } }))   -- clean and fresh: nothing to offer
  local ctx = menu(p, { basin })
  local freshen = assert(ctx:find("ContextMenu_DanTraits_Freshen:2"), "two stale garments to freshen")
  local bleachOpt = assert(ctx:find("ContextMenu_DanTraits_BleachStainsN:1"), "one stained garment")
  assert(bleachOpt.notAvailable and bleachOpt.toolTip.description == "Tooltip_DanTraits_NeedBleach", "no bleach carried: greyed")
  p._soaps = { uses = 3 }
  washCalls = {}
  ctx:click("ContextMenu_DanTraits_Freshen:2")
  assert(#washCalls == 1 and washCalls[1].sink == basin and #washCalls[1].list == 2 and washCalls[1].single == nil, "Freshen: the game's wash with the two garments")
  assert(washCalls[1].list[1] == stale and washCalls[1].list[2] == wornStale, "the stale ones, worn included")
  local bleach = carry(p, bottle(0.3))
  ctx = menu(p, { basin })
  bleachOpt = assert(ctx:find("ContextMenu_DanTraits_BleachStainsN:1"))
  assert(not bleachOpt.notAvailable, "with bleach: offered")
  queue = {}
  ctx:click("ContextMenu_DanTraits_BleachStainsN:1")
  assert(#queue == 1 and queue[1].kind == "bleach" and queue[1].item == marked and queue[1].source == basin and queue[1].bleach == bleach and queue[1].water == 6, "the bleach action, with the wash's water")
  assert(queue[1]:isValid(), "valid as queued")
  -- the water source is found through the game's own fetch too (a list of objects here; a
  -- single Java object is also read, but a Lua table standing in for one would be walked as a list)
  ISWorldObjectContextMenu.fetchVars.storeWater = { basin }
  assert(menu(p, {}):find("ContextMenu_DanTraits_BleachStainsN:1"), "the sink from fetchVars")
  ISWorldObjectContextMenu.fetchVars.storeWater = nil
  assert(menu(p, {}):find("ContextMenu_DanTraits_BleachStainsN:1") == nil, "no water: nothing")
  -- no soap: the Freshen wash still runs (odour comes out without it)
  p._soaps = nil
  washCalls = {}
  menu(p, { basin }):click("ContextMenu_DanTraits_Freshen:2")
  assert(#washCalls == 1, "no soap: the wash still runs for a stale garment")
end

-- 8. by the fire: carried damp garments, not the worn ones; one action each
do
  local p = person()
  local hearth = square(11, 11)
  local fire = fireplace(hearth, true)
  local ctx = menu(p, { fire })
  assert(ctx:find("ContextMenu_DanTraits_DryByFireN:1") == nil, "nothing damp: nothing offered")
  local damp, soaked = carry(p, garment({}, { wet = 40 })), carry(p, garment({}, { wet = 100 }))
  wear(p, garment({}, { wet = 100 }))      -- worn: dries on the body
  carry(p, garment({}, { wet = 5 }))       -- dry enough
  ctx = menu(p, { fire })
  assert(ctx:find("ContextMenu_DanTraits_DryByFireN:2"), "two damp carried garments")
  queue = {}
  ctx:click("ContextMenu_DanTraits_DryByFireN:2")
  assert(#queue == 2 and queue[1].kind == "fire" and queue[1].item == damp and queue[2].item == soaked and queue[1].source == fire, "one fire action each")
  assert(queue[1].startWet == 40 and queue[2].startWet == 100 and queue[1]:isValid(), "from each one's own wetness")
  fire.lit = false
  assert(menu(p, { fire }):find("ContextMenu_DanTraits_DryByFireN:2") == nil, "the fire is out: nothing")
  -- the inventory menu: Dry by the Fire for a damp garment with a fire in reach, Protect Fabric with a protector carried
  fire.lit = true
  local inv = newContext()
  H.fire("OnFillInventoryObjectContextMenu", 0, inv, { damp })
  assert(inv:find("ContextMenu_DanTraits_DryByFire") and inv:find("ContextMenu_DanTraits_ProtectFabric") == nil, "a damp garment by a fire; no protector yet")
  local can = carry(p, protector(2))
  inv = newContext()
  H.fire("OnFillInventoryObjectContextMenu", 0, inv, { damp, soaked })
  queue = {}
  inv:click("ContextMenu_DanTraits_ProtectFabric")
  assert(#queue == 2 and queue[1].kind == "protect" and queue[1].agent == can and queue[2].item == soaked, "a protect action per garment, the carried can")
  assert(queue[1]:isValid(), "valid")
end

-- 10. sheet: one dryer sheet from the box into an idle dryer without one
do
  local p = person()
  local box = carry(p, protector(20))
  box.type = "DanTraits.DryerSheets"
  local on = false
  local dryer = { kind = "IsoClothingDryer", md = {}, getModData = function(self) return self.md end,
                  isActivated = function() return on end, getContainer = function() return { getItems = function() return list({}) end } end }
  local a = ISLaundryAction:new(p, box, "sheet", dryer)
  assert(a.faceTo == dryer and a.maxTime == 40 and a.label == "ContextMenu_DanTraits_DryerSheet", "sheet: faces the dryer")
  assert(a:isValid(), "valid: a box with sheets, an idle dryer")
  on = true; assert(not a:isValid(), "not while it runs"); on = false
  a:start(); assert(a._anim == "Loot", "the loot animation")
  H.clearHalo()
  a:perform()
  assert(box.uses == 19 and L.hasSheet(dryer) and halo[#halo] == "+UI_DanTraits_SheetIn", "one sheet used, in the dryer, the notice")
  assert(not ISLaundryAction:new(p, box, "sheet", dryer):isValid(), "one in already: not a second")
  dryer.md.dtlSheet = nil
  box.uses = 0
  assert(not ISLaundryAction:new(p, box, "sheet", dryer):isValid(), "an empty box")
end

-- 9. laundry off: the menus add nothing
do
  SandboxVars.DanTraits.LaundryEnabled = false
  local p = person()
  carry(p, stained(garment({ Torso = { 0.2, 0 } }))); carry(p, bottle(0.3))
  assert(#menu(p, { sink(10) }).options == 0, "off: no water options")
  SandboxVars.DanTraits.LaundryEnabled = nil
end

H.pass()
