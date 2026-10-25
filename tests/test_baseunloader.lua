-- Offline test for Base Unloader (BaseUnloader/42/media/lua): the core's keys,
-- rules, grouping, suggestions, trip planning and labels; the scan of a small
-- fake base (zone, rows, names, places); whole runs driven through a fake
-- action queue (trips within the carry weight, delivery nearest first, the
-- trunk lid opened on the way, a run from the character's own bags, an
-- interruption then Resume from the saved plan, the stuck guard); and the
-- context menu entries, with the window and menu files loaded against stub UI.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local HERE = arg[0]:match("^(.*)[/\\]") or "."
local ROOT = HERE .. "/../BaseUnloader/42/media/lua/"

local function load(rel)
  local chunk, err = loadfile(ROOT .. rel)
  if not chunk then error(err, 0) end
  chunk()
end

local function list(t)
  return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

-- the game ------------------------------------------------------------------------------

getTextOrNull = function() return nil end
SandboxVars = { BaseUnloader = { Radius = 5, Pad = 2, Floors = 0, Laundry = true } }
ModData = nil

local squares = {}      -- "x,y,z" -> square
local vehicles = {}
getCell = function()
  return {
    getGridSquare = function(_, x, y, z) return squares[x .. "," .. y .. "," .. z] end,

  }
end

function instanceof(obj, cls)
  if type(obj) ~= "table" then return false end
  if cls == "InventoryContainer" then return obj._bag == true end
  if cls == "BaseVehicle" then return obj._vehicle == true end
  if cls == "InventoryItem" then return obj._item == true end
  if cls == "IsoPlayer" or cls == "IsoGameCharacter" then return obj._player == true end
  if cls == "ItemContainer" then return obj._cont == true end
  return false
end

-- a container: kind, capacity, and what it refuses (a type it does not allow)
local function Cont(kind, capacity, opts)
  opts = opts or {}
  local c = { _cont = true, _items = {}, _kind = kind, _capacity = capacity, _custom = nil, _parent = nil, _refuse = opts.refuse }
  function c:getItems() return list(self._items) end
  function c:getType() return self._kind end
  function c:getCapacity() return self._capacity end
  function c:getCapacityWeight()
    local w = 0
    for _, it in ipairs(self._items) do
      if it._inv and it:isEquipped() then
        -- as the game: a worn bag's contents weigh in at (1 - reduction)
        w = w + it:getActualWeight() + it._inv:getCapacityWeight() * (1 - it:getWeightReduction() / 100)
      else
        w = w + it:getUnequippedWeight()
      end
    end
    return w
  end
  function c:getCustomName() return self._custom end
  function c:setCustomName(n) self._custom = n end
  function c:getParent() return self._parent end
  function c:getVehiclePart() return self._part end
  function c:getContainingItem() return self._containing end
  function c:isInCharacterInventory(player) return self._owner == player end
  function c:getEffectiveCapacity() return self._capacity * (self._eff or 1) end
  function c:hasRoomFor(_, it)
    if self._refuse and it:getFullType() == self._refuse then return false end
    return self:getCapacityWeight() + it:getUnequippedWeight() <= self:getEffectiveCapacity() + 0.0001
  end
  function c:contains(it)
    for _, x in ipairs(self._items) do if x == it then return true end end
    return false
  end
  function c:add(it)
    self._items[#self._items + 1] = it
    it._container = self
  end
  function c:remove(it)
    for i, x in ipairs(self._items) do if x == it then table.remove(self._items, i); return end end
  end
  return c
end

local nextId = 100
-- an item: o = { type, cat, weight, name, favorite, equipped, food, offAge, bag = { capacity, reduction } }
local function Item(o)
  nextId = nextId + 1
  local it = { _item = true, _id = nextId, _o = o }
  function it:getID() return self._id end
  function it:getFullType() return o.type end
  function it:getDisplayCategory() return o.cat end
  function it:getDisplayName() return o.name or o.type end
  -- as the game: the actual weight is the item's own (an empty bag's), the
  -- unequipped weight adds what is inside
  function it:getActualWeight() return o.weight or 1 end
  function it:getUnequippedWeight()
    local w = o.weight or 1
    if self._inv then w = w + self._inv:getCapacityWeight() end
    return w
  end
  function it:isFavorite() return o.favorite == true end
  function it:isEquipped() return o.equipped == true end
  function it:isWorn() return o.equipped == true end
  function it:IsFood() return o.food == true end
  function it:IsClothing() return o.clothing == true end
  function it:isDirty() return o.dirty == true end
  function it:getBloodLevel() return o.blood or 0 end
  function it:getOffAgeMax() return o.offAge or 1000000000 end
  function it:isRotten() return o.rotten == true end
  function it:isFrozen() return o.frozen == true end
  function it:getAge() return o.age or 0 end
  function it:getOffAge() return o.staleAt or 1000000000 end
  function it:getContainer() return self._container end
  if o.bag then
    it._bag = true
    it._inv = Cont("bag", o.bag.capacity)
    it._inv._containing = it
    function it:getInventory() return self._inv end
    function it:getWeightReduction() return o.bag.reduction or 0 end
  end
  return it
end

local function fill(c, n, o)
  local made = {}
  for i = 1, n do
    local it = Item(o)
    c:add(it)
    made[#made + 1] = it
  end
  return made
end

-- a square with world objects (each a list of containers) and a room name
local function Sq(x, y, z, room)
  local sq = { _x = x, _y = y, _z = z, _objs = {}, _room = room }
  function sq:getX() return self._x end
  function sq:getY() return self._y end
  function sq:getZ() return self._z end
  function sq:getObjects() return list(self._objs) end
  function sq:getRoom() if self._room then return { getName = function() return self._room end } end return nil end
  function sq:getBuildingDef() return self._def end
  function sq:getBuilding() return nil end
  function sq:getVehicleContainer() return self._vehicle end
  function sq:getWorldObjects()
    local wobs = {}
    for _, it in ipairs(self._floor or {}) do wobs[#wobs + 1] = { getItem = function() return it end } end
    return list(wobs)
  end
  squares[x .. "," .. y .. "," .. z] = sq
  return sq
end

local function Obj(sq, conts)
  local obj = { _sq = sq, _conts = conts }
  for _, c in ipairs(conts) do c._parent = obj end
  function obj:getContainer() return self._conts[1] end
  function obj:getContainerCount() return #self._conts end
  function obj:getContainerByIndex(i) return self._conts[i + 1] end
  function obj:getSquare() return self._sq end
  function obj:setHighlighted() end
  function obj:setHighlightColor() end
  sq._objs[#sq._objs + 1] = obj
  return obj
end

local function Player(sq)
  local p = { _player = true, _sq = sq, _inv = Cont("none", 1000) }
  p._inv._owner = p
  function p:getInventory() return self._inv end
  p._max = 12
  function p:getMaxWeight() return self._max end
  function p:getPlayerNum() return 0 end
  function p:getUsername() return "dan" end
  function p:isDead() return false end
  function p:getCurrentSquare() return self._sq end
  function p:getSquare() return self._sq end
  function p:getX() return self._sq._x end
  function p:getY() return self._sq._y end
  function p:getZ() return self._sq._z end
  function p:getVehicle() return self._veh end
  return p
end

-- the action queue: actions pile up, run() performs them in order
local queue = { queue = {} }
local walks = {}
local walkResult = true
ISTimedActionQueue = {
  add = function(action) queue.queue[#queue.queue + 1] = action end,
  getTimedActionQueue = function() return queue end,
}
ISBaseTimedAction = { Type = "ISBaseTimedAction" }
ISBaseTimedAction.__index = ISBaseTimedAction
function ISBaseTimedAction:derive(name)
  local d = { Type = name }
  d.__index = d
  setmetatable(d, self)
  return d
end
function ISBaseTimedAction:new(character)
  local o = { character = character }
  setmetatable(o, self)
  return o
end
function ISBaseTimedAction:perform() end
function ISBaseTimedAction:stop() end
ISInventoryTransferAction = { new = function(_, character, item, src, dest)
  return { Type = "transfer", character = character, item = item, src = src, dest = dest }
end }
ISOpenVehicleDoor = { new = function(_, character, vehicle, part) return { Type = "door", part = part } end }
ISUnlockVehicleDoor = { new = function(_, character, part) return { Type = "unlock", part = part } end }
luautils = { walkToContainer = function(container, num)
  walks[#walks + 1] = container
  if walkResult == "error" then error("luautils.walkToContainer()") end
  return walkResult
end }

local doorsOpened = 0
local function runQueue()
  local n = 0
  while #queue.queue > 0 do
    local a = table.remove(queue.queue, 1)
    n = n + 1
    if a.Type == "transfer" then
      if a.src:contains(a.item) and a.dest:hasRoomFor(nil, a.item) then
        a.src:remove(a.item)
        a.dest:add(a.item)
      end
    elseif a.Type == "door" then
      doorsOpened = doorsOpened + 1
      a.part._door._open = true
    elseif a.perform then
      a:perform()
    end
  end
  return n
end

local function clearQueue() queue.queue = {} end

-- run a whole job: ticks until the run is over (or the cap); onStep(steps) after each
local onStep = nil
local function drive(maxSteps)
  local steps = 0
  while count(BU_Run.active) > 0 and steps < (maxSteps or 60) do
    H.fire("OnTick")
    runQueue()
    if onStep then onStep(steps) end
    H.fire("OnTick")
    steps = steps + 1
  end
  return steps
end

load("shared/BaseUnloader_Core.lua")
load("client/BaseUnloader_Scan.lua")
load("client/BaseUnloader_Run.lua")
local BU, S, R = BaseUnloader, BU_Scan, BU_Run

-- the core ---------------------------------------------------------------------------------

do
  local key = BU.key(10, -3, 0, "crate", 1)
  assert(key == "10,-3,0:crate:1", "key format: " .. key)
  local k = BU.parseKey(key)
  assert(k.x == 10 and k.y == -3 and k.z == 0 and k.kind == "crate" and k.index == 1, "key parses back")
  assert(BU.parseKey("rubbish") == nil and BU.parseKey(nil) == nil, "bad keys parse to nil")

  local rules = {}
  BU.setRule(rules, "Base.Axe", "A")
  BU.setRule(rules, BU.catKey("Food"), "F")
  assert(BU.destinationOf({ fullType = "Base.Axe", category = "Weapon" }, rules) == "A", "type rule")
  assert(BU.destinationOf({ fullType = "Base.Beans", category = "Food" }, rules) == nil, "a whole-category rule is a thing of the past (tags do that now)")
  local st = BU.store(); st.rules[BU.catKey("Food")] = "F"; BU.resetStore()
  assert(BU.store().rules[BU.catKey("Food")] == nil and BU.store().rules["Base.Axe"] == nil, "a save's stale category rules are dropped on load")
  assert(BU.destinationOf({ fullType = "Base.Hat", category = "Clothing" }, rules) == nil, "no rule")
  assert(BU.destinationOf({ id = 5, fullType = "Base.Axe" }, rules, { [5] = "X" }) == "X", "a one-off beats the rule")
  assert(BU.clearRulesTo(rules, "A") == 1 and rules["Base.Axe"] == nil, "clearRulesTo")
  BU.setRule(rules, "Base.Saw", "F")
  assert(BU.ruleCounts(rules)["F"] == 2, "ruleCounts")

  local items = {
    { id = 1, fullType = "Base.Axe", name = "Axe", category = "Weapon", weight = 3 },
    { id = 2, fullType = "Base.Axe", name = "Axe", category = "Weapon", weight = 3 },
    { id = 3, fullType = "Base.Beans", name = "Beans", category = "Food", weight = 0.8, food = true },
    { id = 4, fullType = "Base.Gold", name = "Gold", category = "Jewel", weight = 0.1, favorite = true },
    { id = 5, fullType = "Base.Bag", name = "Bag", category = "Container", weight = 1, equipped = true },
  }
  local groups = BU.groups(items)
  assert(#groups == 2, "favourites and worn things are not grouped: " .. #groups)
  assert(groups[1].name == "Axe" and groups[1].count == 2 and groups[1].weight == 6, "axes grouped and weighed")
  assert(groups[2].name == "Beans", "sorted by name")

  -- suggestions: contents, then the fridge for perishables, then the category, then the kind
  local containers = {
    { key = "W", kind = "wardrobe", x = 0, y = 0, z = 0, free = 20, contents = {}, cats = { Clothing = 3 } },
    { key = "F", kind = "fridge", x = 1, y = 0, z = 0, free = 5, contents = { ["Base.Beans"] = 2 }, cats = { Food = 2 } },
    { key = "Z", kind = "freezer", x = 1, y = 0, z = 0, free = 9, contents = {}, cats = {} },
    { key = "C", kind = "crate", x = 2, y = 0, z = 0, free = 30, contents = {}, cats = { Weapon = 1 } },
    { key = "K", kind = "counter", x = 3, y = 0, z = 0, free = 10, contents = {}, cats = {} },
  }
  local gs = {
    { fullType = "Base.Beans", category = "Food", perishable = false },
    { fullType = "Base.Steak", category = "Food", perishable = true },
    { fullType = "Base.Ramen", category = "Food", perishable = true, longLife = true },
    { fullType = "Base.Hat", category = "Clothing" },
    { fullType = "Base.Axe", category = "Weapon" },
    { fullType = "Base.Rope", category = "Material" },
    { fullType = "Base.Odd", category = "Odd" },
  }
  local picks = BU.suggest(gs, containers, { ["Base.Rope"] = "W" })
  -- 2026-10-17: shelf food was going into the freezer; a can never goes in the cold unless a rule says so
  assert(picks["Base.Beans"] == "K", "canned beans skip the fridge that holds beans: the counter: " .. tostring(picks["Base.Beans"]))
  assert(picks["Base.Steak"] == "Z", "perishable food goes to the coldest with most room")
  assert(picks["Base.Ramen"] == "K", "long-life food (a year to rot) is shelf food: " .. tostring(picks["Base.Ramen"]))
  assert(picks["Base.Hat"] == "W", "clothing goes with the clothing")
  assert(picks["Base.Axe"] == "C", "a weapon goes with the weapon")
  assert(picks["Base.Rope"] == nil, "a type with a rule is not suggested")
  assert(picks["Base.Odd"] == nil, "nothing suits it: no suggestion")

  -- the resolver keeps shelf food out of the cold; only a rule or tag puts it there
  local fridgeFull = {
    { key = "Z", kind = "freezer", x = 1, y = 0, z = 0, free = 50, contents = { ["Base.Chips"] = 3 }, cats = { Food = 20 } },
    { key = "M", kind = "minifridge2", x = 1, y = 0, z = 0, free = 50, contents = {}, cats = { Food = 9 } },
    { key = "S", kind = "shelves", x = 4, y = 0, z = 0, free = 50, contents = {}, cats = { Food = 1 } },
  }
  local function where(item, rules)
    return (BU.resolve(item, { rules = rules or {}, tags = {}, containers = fridgeFull, use = {}, pos = { x = 0, y = 0, z = 0 } }))
  end
  assert(where({ fullType = "Base.Chips", category = "Food", food = true, perishable = false }) == "S", "chips the freezer holds go to the shelf")
  assert(where({ fullType = "Base.Beans", category = "Food", food = true, perishable = false }) == "S", "a can skips the food-filled freezer")
  assert(where({ fullType = "Base.Ramen", category = "Food", food = true, perishable = true, longLife = true }) == "S", "long-life food too")
  assert(where({ fullType = "Base.Steak", category = "Food", food = true, perishable = true }) == "Z", "fresh meat still to the freezer")
  assert(where({ fullType = "Base.Milk", category = "Food", food = true, perishable = true, stale = true }) == "S", "stale food with no bin: not the cold")
  assert(where({ fullType = "Base.Beans", category = "Food", food = true }, { ["Base.Beans"] = "Z" }) == "Z", "a rule still puts it in the freezer")
  assert(where({ fullType = "Base.Hammer", category = "Tool" }) == "S", "a hammer never lands in a fridge (a modded one either)")
  assert(BU.wantsCold({ food = true, perishable = true }) and not BU.wantsCold({ food = true, perishable = true, longLife = true }), "wantsCold")

  -- tags: a category's home among the tagged containers
  local tags = {}
  BU.setTag(tags, "W", "Clothing", true)
  BU.setTag(tags, "C", "Clothing", true)
  BU.setTag(tags, "C", "Tool", true)
  assert(BU.hasTag(tags, "C", "Tool") and not BU.hasTag(tags, "W", "Tool"), "setTag / hasTag")
  assert(table.concat(BU.tagsOf(tags, "C"), ",") == "Clothing,Tool", "tagsOf sorted")
  assert(BU.tagDestination({ fullType = "Base.Hat", category = "Clothing" }, tags, containers) == "C", "most room wins among the tagged")
  containers[1].contents["Base.Hat"] = 1
  assert(BU.tagDestination({ fullType = "Base.Hat", category = "Clothing" }, tags, containers) == "W", "a container already holding the type wins")
  containers[1].contents["Base.Hat"] = nil
  assert(BU.tagDestination({ fullType = "Base.Axe", category = "Weapon" }, tags, containers) == nil, "no tag, no home")
  BU.setTag(tags, "C", "Tool", false)
  BU.setTag(tags, "C", "Clothing", false)
  assert(tags["C"] == nil, "the last tag off removes the entry")
  assert(BU.tagFromContents(tags, "C", { Food = 3, Tool = 1, Junk = 0 }) == 2, "two categories with items inside become tags")
  assert(BU.hasTag(tags, "C", "Food") and BU.hasTag(tags, "C", "Tool") and not BU.hasTag(tags, "C", "Junk"), "the empty one is skipped")
  assert(BU.tagFromContents(tags, "C", { Food = 3 }) == 0, "nothing new the second time")
  tags["C"] = nil
  -- the last set given by hand goes onto the next container in one click
  local st = { tags = {} }
  assert(BU.lastTagsFor(st, "A") == nil and not BU.applyLastTags(st, "A"), "nothing remembered yet")
  BU.setTag(st.tags, "A", "Food", true)
  BU.setTag(st.tags, "A", "Cooking", true)
  BU.noteTags(st, "A")
  assert(table.concat(st.lastTags, ",") == "Cooking,Food", "noteTags keeps the sorted set")
  assert(BU.lastTagsFor(st, "A") == nil, "not offered where it is already the set")
  BU.setTag(st.tags, "B", "Tool", true)
  assert(table.concat(BU.lastTagsFor(st, "B"), ",") == "Cooking,Food", "offered on another container")
  assert(BU.applyLastTags(st, "B"), "applied")
  assert(table.concat(BU.tagsOf(st.tags, "B"), ",") == "Cooking,Food", "the set replaces what B had")
  st.tags["A"] = nil
  BU.noteTags(st, "A")
  assert(table.concat(st.lastTags, ",") == "Cooking,Food", "clearing a container keeps the remembered set")
  st.tags["B"]["Tool"] = true
  assert(st.lastTags[3] == nil, "the remembered set is a copy, not B's table")
  -- the laundry: a tagged container first, else the cart, else the washer
  local laundry = { { key = "L1", kind = "clothingwasher", free = 20 }, { key = "L2", kind = "clothingdryerbasic", free = 5 },
                    { key = "L3", kind = "clothingdryerbasic", free = 9 }, { key = "W", kind = "wardrobe", free = 50 } }
  assert(BU.laundryDestination({ laundry = true }, {}, laundry) == "L3", "the cart with most room")
  assert(BU.laundryDestination({ laundry = true }, {}, { laundry[1], laundry[4] }) == "L1", "the washer when there is no cart")
  assert(BU.laundryDestination({ laundry = true }, { W = { Laundry = true } }, laundry) == "W", "a container tagged Laundry beats both")
  assert(BU.laundryDestination({ laundry = false }, {}, laundry) == nil, "clean clothes are not laundry")
  -- the resolver, stage by stage
  do
    local base = {
      { key = "FR", kind = "fridge", x = 1, y = 0, z = 0, free = 10, contents = { ["Base.Steak"] = 1 }, cats = { Food = 1 } },
      { key = "FZ", kind = "freezer", x = 2, y = 0, z = 0, free = 10, contents = {}, cats = {} },
      { key = "BIN", kind = "bin", x = 3, y = 0, z = 0, free = 10, contents = {}, cats = {} },
      { key = "WR", kind = "wardrobe", x = 4, y = 0, z = 0, free = 10, contents = { ["Base.Shirt"] = 2 }, cats = { Clothing = 2 } },
      { key = "CR", kind = "crate", x = 5, y = 0, z = 0, free = 10, contents = {}, cats = { Tool = 1 } },
      { key = "LK", kind = "locker", x = 9, y = 0, z = 0, free = 10, contents = {}, cats = {} },
      { key = "SM", kind = "crate", x = 1, y = 1, z = 0, free = 0.2, contents = {}, cats = {} },
      { key = "CART", kind = "clothingdryerbasic", x = 6, y = 0, z = 0, free = 10, contents = {}, cats = {} },
    }
    local ctx = { rules = { ["Base.Hammer"] = "LK", ["Base.Nail"] = "SM" }, tags = { CR = { Material = true } },
                  containers = base, pos = { x = 0, y = 0, z = 0 }, ruleCounts = { LK = 1, SM = 1 } }
    local function go(item) return BU.resolve(item, ctx) end
    local k, how = go({ id = 1, fullType = "Base.Axe", category = "Weapon", weight = 1 })
    assert(k == "WR" and how == "nearest", "nothing fits an axe: the nearest container nothing points at: " .. tostring(k) .. " " .. tostring(how))
    -- with the wardrobe spoken for too, the locker is the only free container; then none
    ctx.ruleCounts = { WR = 1, SM = 1 }
    k, how = go({ id = 1, fullType = "Base.Axe", category = "Weapon", weight = 1 })
    assert(k == "LK" and how == "nearest", "the locker is the only free container: " .. tostring(k) .. " " .. tostring(how))
    ctx.ruleCounts = { WR = 1, LK = 1, SM = 1 }
    k, how = go({ id = 1, fullType = "Base.Axe", category = "Weapon", weight = 1 })
    assert(k == nil, "with every plain container spoken for (cold, bins and laundry never count), an axe has nowhere")
    ctx.ruleCounts = { LK = 1, SM = 1 }
    k, how = go({ id = 2, fullType = "Base.Shirt", category = "Clothing", weight = 0.5 })
    assert(k == "WR" and how == "contains", "a shirt joins the shirts")
    k, how = go({ id = 3, fullType = "Base.Hat", category = "Clothing", weight = 0.5 })
    assert(k == "WR" and how == "category", "a hat joins the clothing")
    k, how = go({ id = 4, fullType = "Base.Hammer", category = "Tool", weight = 1 })
    assert(k == "LK" and how == "rule", "the rule for hammers")
    k, how = go({ id = 5, fullType = "Base.Plank", category = "Material", weight = 2 })
    assert(k == "CR" and how == "tag", "the Material tag")
    k, how = go({ id = 6, fullType = "Base.Saw", category = "Tool", weight = 1 })
    assert(k == "CR" and how == "category", "a saw joins the tool in the crate")
    k, how = go({ id = 7, fullType = "Base.Nail", category = "Material", weight = 1 })
    assert(k == "CR" and how == "tag", "a rule to a full container hands on to the next stage")
    k, how = go({ id = 8, fullType = "Base.Steak", category = "Food", weight = 1, food = true, perishable = true })
    assert(k == "FR" and how == "contains", "fresh steak joins the steak in the fridge")
    k, how = go({ id = 9, fullType = "Base.Chicken", category = "Food", weight = 1, food = true, perishable = true })
    assert(k == "FZ" and how == "freezer", "fresh chicken, new to the base, goes to the freezer")
    k, how = go({ id = 10, fullType = "Base.Chicken", category = "Food", weight = 1, food = true, perishable = true, stale = true })
    assert(k == "BIN" and how == "garbage", "stale chicken goes to the bin")
    k, how = go({ id = 11, fullType = "Base.Steak", category = "Food", weight = 1, food = true, perishable = true, rotten = true })
    assert(k == "BIN" and how == "garbage", "rotten steak goes to the bin, not to the steak")
    k, how = go({ id = 12, fullType = "Base.Beans", category = "Food", weight = 1, food = true, perishable = false })
    -- changed 2026-10-17 (tins were filling the freezer): shelf food never joins the food in the cold
    assert(k ~= "FR" and k ~= "FZ", "tinned food is not fresh: not the fridge or freezer: " .. tostring(k) .. " " .. tostring(how))
    k, how = go({ id = 13, fullType = "Base.Shirt", category = "Clothing", weight = 0.5, laundry = true })
    assert(k == "CART" and how == "laundry", "a dirty shirt goes to the cart before the shirts")
    ctx.oneOffs = { ["13"] = "CR" }
    k, how = go({ id = 13, fullType = "Base.Shirt", category = "Clothing", weight = 0.5, laundry = true })
    assert(k == "CR" and how == "oneoff", "a one-off beats everything")
    ctx.oneOffs = nil
    ctx.hidden = { WR = true }
    k, how = go({ id = 2, fullType = "Base.Shirt", category = "Clothing", weight = 0.5 })
    assert(k ~= "WR", "a hidden container is not inferred into: " .. tostring(k))
    -- nor by its kind: a hidden freezer, bin or laundry cart (2026-10-22); a tag on it still counts
    ctx.hidden = { FZ = true, BIN = true, CART = true }
    k, how = go({ id = 9, fullType = "Base.Chicken", category = "Food", weight = 1, food = true, perishable = true })
    assert(k == "FR" and how == "freezer", "a hidden freezer hands fresh food to the fridge: " .. tostring(k))
    k, how = go({ id = 10, fullType = "Base.Chicken", category = "Food", weight = 1, food = true, perishable = true, stale = true })
    assert(k ~= "BIN", "a hidden bin takes no rubbish: " .. tostring(k))
    k, how = go({ id = 13, fullType = "Base.Shirt", category = "Clothing", weight = 0.5, laundry = true })
    assert(k ~= "CART", "a hidden cart takes no laundry: " .. tostring(k))
    ctx.tags.CART = { Laundry = true }
    k, how = go({ id = 13, fullType = "Base.Shirt", category = "Clothing", weight = 0.5, laundry = true })
    assert(k == "CART" and how == "laundry", "tagged Laundry by hand, hidden or not, it does")
    ctx.tags.CART = nil
    ctx.hidden = nil
    -- a rule beats what a shelf already holds (2026-10-22: contains came first, so a rule for a
    -- type never won while any shelf held one)
    ctx.rules["Base.Shirt"] = "LK"
    k, how = go({ id = 2, fullType = "Base.Shirt", category = "Clothing", weight = 0.5 })
    assert(k == "LK" and how == "rule", "the shirt rule beats the shirts in the wardrobe: " .. tostring(k) .. " " .. tostring(how))
    ctx.rules["Base.Shirt"] = nil
    -- off limits: nothing automatic, but a rule or a one-off still lands there
    ctx.offLimits = { WR = true, CR = true, CART = true, FZ = true }
    k, how = go({ id = 2, fullType = "Base.Shirt", category = "Clothing", weight = 0.5 })
    assert(k ~= "WR", "an off-limits container is not inferred into: " .. tostring(k))
    k, how = go({ id = 5, fullType = "Base.Plank", category = "Material", weight = 2 })
    assert(k ~= "CR", "an off-limits container's tags are ignored: " .. tostring(k))
    k, how = go({ id = 13, fullType = "Base.Shirt", category = "Clothing", weight = 0.5, laundry = true })
    assert(k ~= "CART", "dirty clothes skip an off-limits laundry cart: " .. tostring(k))
    k, how = go({ id = 9, fullType = "Base.Chicken", category = "Food", weight = 1, food = true, perishable = true })
    assert(k == "FR" and how == "freezer", "an off-limits freezer hands fresh food to the fridge: " .. tostring(k) .. " " .. tostring(how))
    ctx.rules["Base.Axe"] = "WR"
    k, how = go({ id = 1, fullType = "Base.Axe", category = "Weapon", weight = 1 })
    assert(k == "WR" and how == "rule", "a type dragged onto an off-limits container still goes there")
    ctx.rules["Base.Axe"] = nil
    ctx.oneOffs = { ["5"] = "CR" }
    k, how = go({ id = 5, fullType = "Base.Plank", category = "Material", weight = 2 })
    assert(k == "CR" and how == "oneoff", "a one-off to an off-limits container still goes there")
    ctx.oneOffs = nil
    ctx.offLimits = nil
    ctx.use = { WR = 9.8 }
    k, how = go({ id = 2, fullType = "Base.Shirt", category = "Clothing", weight = 0.5 })
    assert(k ~= "WR", "room already planned into a container counts: " .. tostring(k))
    ctx.use = nil
  end
  local split = BU.groups({ { id = 1, fullType = "Base.Shirt", name = "Shirt", category = "Clothing", weight = 0.5 },
                            { id = 2, fullType = "Base.Shirt", name = "Shirt", category = "Clothing", weight = 0.5, laundry = true } })
  assert(#split == 2 and not split[1].laundry and split[2].laundry, "dirty shirts group apart from clean ones")

  -- a trip: nearest first, within the budget and the containers' room
  local trip = BU.trip({
    { id = 1, weight = 3, dest = "C" }, { id = 2, weight = 3, dest = "C" }, { id = 3, weight = 3, dest = "C" },
    { id = 4, weight = 0.8, dest = "F" }, { id = 5, weight = 0.8, dest = "F" },
    { id = 6, weight = 1, dest = "GONE" }, { id = 7, weight = 50, dest = "W" },
  }, containers, { x = 0, y = 0, z = 0 }, 7)
  assert(trip.skipped.noContainer == 1, "an item for a missing container is counted")
  assert(trip.skipped.noRoom == 1, "an item too heavy for its container is counted")
  assert(trip.stops[1].key == "F", "the nearest stop first: " .. tostring(trip.stops[1].key))
  assert(#trip.stops[1].items == 2 and #trip.stops[2].items == 1, "two tins then one axe fit 7")
  assert(trip.weight == 4.6, "trip weight " .. trip.weight)
  -- 2026-10-17: never past the load limit, not even for one item; worn bags first, at their reduction
  local heavy = BU.trip({ { id = 1, weight = 20, dest = "C" } }, containers, { x = 0, y = 0, z = 0 }, 7)
  assert(#heavy.stops == 0 and heavy.skipped.tooHeavy == 1, "an item over the whole budget is left, and counted")
  local pack = { left = 9, keep = 0.5 }
  local light = BU.trip({ { id = 1, weight = 3, dest = "C" }, { id = 2, weight = 3, dest = "C" },
                          { id = 3, weight = 3, dest = "C" }, { id = 4, weight = 3, dest = "C" } },
                        containers, { x = 0, y = 0, z = 0 }, 6, { pack })
  local li = light.stops[1].items
  assert(#li == 3 and light.weight == 4.5, "three in the half-weight bag (4.5), the fourth in the hands would pass 6: " .. #li .. " " .. light.weight)
  assert(li[1].into == pack and li[3].into == pack, "they ride in the bag")
  local better = { left = 3, keep = 0.2 }
  local two = BU.trip({ { id = 1, weight = 3, dest = "C" }, { id = 2, weight = 3, dest = "C" } },
                      containers, { x = 0, y = 0, z = 0 }, 10, { pack, better })
  assert(two.stops[1].items[1].into == better and two.stops[1].items[2].into == pack, "the best reduction fills first")
  local picky = { left = 9, keep = 0.5, ok = function(item) return item.id ~= 2 end }
  local refused = BU.trip({ { id = 1, weight = 1, dest = "C" }, { id = 2, weight = 1, dest = "C" } },
                          containers, { x = 0, y = 0, z = 0 }, 10, { picky })
  assert(refused.stops[1].items[2].into == nil and refused.weight == 1.5, "a bag that will not take it: the hands, at full weight")
  -- hands full, bag not: the bag still takes what is for a later stop
  local bagged = BU.trip({ { id = 1, weight = 5, dest = "F" }, { id = 2, weight = 1, dest = "C" }, { id = 3, weight = 1, dest = "W" } },
                         containers, { x = 1, y = 0, z = 0 }, 5.5, { { left = 4, keep = 0.5 } })
  assert(#bagged.stops == 2 and bagged.stops[2].items[1].id == 2, "every destination is tried once the hands are full: " .. #bagged.stops)
  -- the budget: up to the Heavy Load level (2: 1.5x the max weight)
  assert(BU.loadBudget(10, 0, 2) == 15 and BU.loadBudget(10, 14, 2) == 1 and BU.loadBudget(10, 20, 2) == 0, "level 2 is 1.5x")
  assert(BU.loadBudget(10, 0, 0) == 10 and BU.loadBudget(10, 0, 4) == 20 and BU.loadBudget(10, 0, nil) == 15, "levels 0, 4 and the default")
  local stops, lost = BU.deliveryOrder({ { id = 1, dest = "C" }, { id = 2, dest = "W" }, { id = 3, dest = "GONE" } }, containers, { x = 2, y = 0, z = 0 })
  assert(stops[1].key == "C" and stops[2].key == "W" and #lost == 1, "delivery nearest first, the lost one apart")

  assert(BU.dist({ x = 0, y = 0, z = 0 }, { x = 3, y = 4, z = 1 }) == 5 + BU.FLOOR_COST, "a floor costs")
  -- the tour: nearest-next alone walks 20 along this line; two-opt finds the 16
  local line = { { key = "a", x = 1, y = 0, z = 0 }, { key = "b", x = -2, y = 0, z = 0 }, { key = "c", x = 3, y = 0, z = 0 }, { key = "d", x = -4, y = 0, z = 0 } }
  local origin = { x = 0, y = 0, z = 0 }
  local order = BU.tour(line, origin, origin)
  local keys = {}
  for i, p in ipairs(order) do keys[i] = p.key end
  assert(BU.tourCost(order, origin, origin) <= 16.01, "two-opt uncrosses the line: " .. table.concat(keys, "") .. " costs " .. BU.tourCost(order, origin, origin))
  -- a stop upstairs waits until the floor is done, however close it is on the map
  local floors = { { key = "up", x = 1, y = 0, z = 1 }, { key = "b", x = 5, y = 0, z = 0 }, { key = "c", x = 6, y = 0, z = 0 } }
  order = BU.tour(floors, origin, nil)
  assert(order[1].key == "b" and order[2].key == "c" and order[3].key == "up", "same floor first: " .. order[1].key .. order[2].key .. order[3].key)
  assert(#BU.tour({}, origin, nil) == 0 or BU.tour({}, origin, nil)[1] == nil, "an empty tour")
  assert(BU.compass(0, -5) == "N" and BU.compass(5, 5) == "SE" and BU.compass(10, 1) == "E" and BU.compass(0, 0) == nil, "compass")
  local which, n = BU.floorKey(0); assert(which == "Ground" and n == nil, "ground")
  which, n = BU.floorKey(-1); assert(which == "Basement" and n == 1, "basement")
  which, n = BU.floorKey(2); assert(which == "Upper" and n == 2, "upper")
  assert(BU.roomWords("livingroom") == "Living room" and BU.roomWords("tool_shed") == "Tool shed" and BU.roomWords("") == nil, "room words")
  assert(BU.fmtWeight(3) == "3" and BU.fmtWeight(2.25) == "2.3" and BU.fmtWeight(0.1) == "0.1", "weights")

  -- the store: a world table when ModData offers one, else its own
  BU.resetStore()
  local given = {}
  ModData = { getOrCreate = function(name) assert(name == "BaseUnloader"); return given end }
  assert(BU.store() == given and given.rules ~= nil, "store comes from ModData")
  ModData = nil
  BU.resetStore()
  assert(BU.store() ~= given, "and is its own table without it")
end

-- the base ----------------------------------------------------------------------------------

-- the source crate at (10,10), the player beside it, four homes about the house
local crateSq = Sq(10, 10, 0, "garage")
local source = Cont("crate", 50)
Obj(crateSq, { source })
local axes = fill(source, 3, { type = "Base.Axe", cat = "Weapon", weight = 3, name = "Axe" })
local beans = fill(source, 5, { type = "Base.CannedBeans", cat = "Food", weight = 0.8, name = "Canned Beans", food = true })
local bandages = fill(source, 2, { type = "Base.Bandage", cat = "FirstAid", weight = 0.1, name = "Bandage" })
local hats = fill(source, 1, { type = "Base.Hat", cat = "Clothing", weight = 0.5, name = "Hat" })
fill(source, 1, { type = "Base.Ring", cat = "Jewel", weight = 0.1, name = "Ring", favorite = true })

local medSq = Sq(11, 10, 0, "garage")
local medicine = Cont("medicine", 10)
Obj(medSq, { medicine })
fill(medicine, 2, { type = "Base.Bandage", cat = "FirstAid", weight = 0.1 })

local fridgeSq = Sq(12, 10, 0, "kitchen")
local fridge, freezer = Cont("fridge", 20), Cont("freezer", 20)
Obj(fridgeSq, { fridge, freezer })
fill(fridge, 1, { type = "Base.CannedBeans", cat = "Food", weight = 0.8, food = true })

local wardrobeSq = Sq(14, 12, 0, "bedroom")
local wardrobe = Cont("wardrobe", 20)
Obj(wardrobeSq, { wardrobe })
fill(wardrobe, 2, { type = "Base.Shirt", cat = "Clothing", weight = 0.5 })

local shedSq = Sq(13, 7, 0, nil)      -- outside: no room
local shed = Cont("crate", 30)
Obj(shedSq, { shed })

Sq(30, 30, 0, "far")                  -- a square off in the distance
Obj(squares["30,30,0"], { Cont("crate", 30) })

local playerSq = Sq(10, 11, 0, "garage")
local player = Player(playerSq)
H.current = player

do
  local src = S.objectSource(squares["10,10,0"]._objs[1], source, nil)
  assert(src.kind == "object" and src.key == "10,10,0:crate:0" and src.label == "IGUI_ContainerTitle_crate" or src.label == "crate", "source key and label")
  local zone = S.zone(player, S.sourceSquare(src))
  assert(zone.x1 == 5 and zone.x2 == 15 and zone.z1 == 0 and zone.z2 == 0, "zone is the radius about the source")
  local rows = S.containers(zone, source)
  assert(#rows == 5, "five containers in the zone, the source left out, the far crate out: " .. #rows)
  local byKey = {}
  for _, row in ipairs(rows) do byKey[row.key] = row end
  local wr = byKey["14,12,0:wardrobe:0"]
  assert(wr and wr.room == "Bedroom" and wr.place == "Bedroom, IGUI_BU_Floor_Ground", "room and floor: " .. tostring(wr and wr.place))
  assert(wr.contents["Base.Shirt"] == 2 and wr.cats.Clothing == 2 and wr.used == 1 and wr.capacity == 20, "histograms and fill")
  local fz = byKey["12,10,0:freezer:1"]
  assert(fz and fz.kind == "freezer", "the second container of an object has index 1")
  local sh = byKey["13,7,0:crate:0"]
  assert(sh.place == "IGUI_BU_Tiles:4, IGUI_BU_Floor_Ground", "no room: distance and direction: " .. sh.place)
  assert(rows[#rows].room == nil, "rooms sort before the outdoors")

  -- names: on the container, saved for the key, else the kind
  S.rename(wardrobe, wr.key, "Winter clothes")
  assert(wardrobe:getCustomName() == "Winter clothes" and BU.store().names[wr.key] == "Winter clothes", "rename sets both")
  wardrobe._custom = nil
  local name, named = S.nameOf(wardrobe, wr.key)
  assert(name == "Winter clothes" and named and wardrobe:getCustomName() == "Winter clothes", "a saved name is put back on the container")
  S.rename(wardrobe, wr.key, "")
  assert(wardrobe:getCustomName() == nil and BU.store().names[wr.key] == nil, "an empty name clears")

  -- resolve finds the container again from its key
  local found = S.resolve(fz.key)
  assert(found and found.container == freezer, "resolve by key")
  assert(S.resolve("1,1,0:crate:0") == nil, "nothing there")

  -- item records
  local recs = S.items(source)
  assert(#recs == 12, "twelve items in the crate: " .. #recs)
  local fav = 0
  for _, r in ipairs(recs) do if r.favorite then fav = fav + 1 end end
  assert(fav == 1 and #BU.groups(recs) == 4, "the favourite ring is listed but not grouped")

  -- suggestions off the real rows: beans with beans, bandages with bandages, hat with the shirts
  local picks = BU.suggest(BU.groups(recs), rows, {})
  -- changed 2026-10-17: a can is never suggested for the cold, even beside the one tin already in the fridge
  assert(picks["Base.CannedBeans"] ~= "12,10,0:fridge:0" and picks["Base.CannedBeans"] ~= "12,10,0:freezer:1",
    "beans not to the fridge or freezer: " .. tostring(picks["Base.CannedBeans"]))
  assert(picks["Base.Bandage"] == "11,10,0:medicine:0", "bandages to the cabinet")
  assert(picks["Base.Hat"] == wr.key, "hat to the wardrobe")
  assert(picks["Base.Axe"] == wr.key, "nothing holds weapons: the kind hint picks the wardrobe")
end

-- a run ---------------------------------------------------------------------------------------

do
  local rules = BU.store().rules
  rules["Base.Axe"] = "13,7,0:crate:0"
  rules["Base.CannedBeans"] = "12,10,0:fridge:0"
  rules[BU.catKey("FirstAid")] = "11,10,0:medicine:0"
  rules["Base.Hat"] = "14,12,0:wardrobe:0"
  -- a worn bag with room, half weight inside
  local bag = Item({ type = "Base.Bag", cat = "Container", weight = 1, name = "Bag", equipped = true, bag = { capacity = 8, reduction = 50 } })
  player._inv:add(bag)

  local src = S.objectSource(squares["10,10,0"]._objs[1], source, nil)
  H.clearHalo()
  walks = {}
  player._max = 6     -- up to Heavy Load 2: a load of 9, the bag's contents at half
  local peak = 0
  onStep = function() peak = math.max(peak, player._inv:getCapacityWeight()) end
  R.start(player, src, {})
  assert(R.isRunning(player) and R.hasPlan(player), "running with a saved plan")
  local steps = drive()
  onStep = nil
  assert(peak <= 9 + 1e-6 and peak > 6, "loaded past the carry weight but never past 1.5x it (Heavy Load 2): " .. peak)
  assert(count(R.active) == 0, "the run ended in " .. steps .. " steps")
  assert(#shed._items == 3 and #fridge._items == 6 and #medicine._items == 4 and #wardrobe._items == 3, "everything put away: "
    .. #shed._items .. " " .. #fridge._items .. " " .. #medicine._items .. " " .. #wardrobe._items)
  assert(#source._items == 1 and source._items[1]:getFullType() == "Base.Ring", "the favourite stays in the crate")
  assert(#player._inv._items == 1 and #bag._inv._items == 0, "the bag and the hands are empty again")
  assert(not R.hasPlan(player), "a finished run forgets its plan")
  local done = false
  for _, t in ipairs(H.halo) do if t == "+IGUI_BU_Done:11" then done = true end end
  assert(done, "the summary counts 11 items")
  -- 9 of axes alone outweigh the 12 budget with 4 of beans: two loads at least
  local loads = 0
  for _, c in ipairs(walks) do if c == source then loads = loads + 1 end end
  assert(loads >= 2 and loads <= 4, "two to four trips to the crate: " .. loads)
  assert(walks[1] == source, "the first walk is to the source")
  player._max = 12
end

-- an interruption, then Resume from the saved plan -------------------------------------------------

do
  fill(source, 4, { type = "Base.CannedBeans", cat = "Food", weight = 0.8, name = "Canned Beans", food = true })
  local src = S.objectSource(squares["10,10,0"]._objs[1], source, nil)
  H.clearHalo()
  R.start(player, src, {})
  H.fire("OnTick")                 -- the load step is queued
  assert(#queue.queue > 0, "actions queued")
  clearQueue()                     -- a zombie: the game clears the queue
  H.fire("OnTick")
  assert(count(R.active) == 0 and R.hasPlan(player), "paused, plan kept")
  local paused = false
  for _, t in ipairs(H.halo) do if t == "IGUI_BU_Paused" then paused = true end end
  assert(paused, "told it paused")
  assert(#source._items == 5, "nothing moved")
  -- as if after a reload: the runner is empty, the store still has the plan
  R.active = {}
  assert(R.resume(player), "resume takes the plan up")
  drive()
  assert(#fridge._items == 10 and #source._items == 1, "the beans got there after all")
  assert(not R.hasPlan(player), "and the plan is done")
  -- forgetting a plan
  R.start(player, src, {})
  R.forget(player)
  assert(not R.hasPlan(player) and not R.isRunning(player), "forget drops both")
end

-- the stuck guard ------------------------------------------------------------------------------------

do
  local picky = Cont("locker", 30, { refuse = "Base.Brick" })
  Obj(Sq(9, 10, 0, "garage"), { picky })
  BU.store().rules["Base.Brick"] = "9,10,0:locker:0"
  fill(source, 2, { type = "Base.Brick", cat = "Material", weight = 1, name = "Brick" })
  local src = S.objectSource(squares["10,10,0"]._objs[1], source, nil)
  H.clearHalo()
  R.start(player, src, {})
  drive()
  local stuck = false
  for _, t in ipairs(H.halo) do
    if t == "IGUI_BU_Stuck" or t == "IGUI_BU_Paused" then stuck = true end
  end
  assert(not stuck, "a container that refuses the item does not stall the run")
  assert(count(R.active) == 0 and not R.hasPlan(player), "the run finished and forgot its plan")
  assert(#picky._items == 0, "nothing was forced into the locker")
  local bricksLeft = 0
  for _, it in ipairs(source._items) do if it:getFullType() == "Base.Brick" then bricksLeft = bricksLeft + 1 end end
  assert(bricksLeft == 0, "the bricks went to the next container in the chain instead")
  -- the bricks were loaded into the bag: take them out of the world again
  local bagItem = player._inv._items[1]
  for _, holder in ipairs({ player._inv, bagItem._inv }) do
    local bricks = {}
    for _, it in ipairs(holder._items) do if it:getFullType() == "Base.Brick" then bricks[#bricks + 1] = it end end
    for _, it in ipairs(bricks) do holder:remove(it) end
  end
  BU.store().rules["Base.Brick"] = nil
  local left = {}
  for _, it in ipairs(source._items) do if it:getFullType() == "Base.Brick" then left[#left + 1] = it end end
  for _, it in ipairs(left) do source:remove(it) end
end

-- a vehicle source ---------------------------------------------------------------------------------------

do
  local trunk = Cont("TruckBed", 60)
  local door = { _open = false, isOpen = function(self) return self._open end, isLocked = function() return false end }
  local vpart = { _door = door }
  function vpart:getItemContainer() return trunk end
  function vpart:getDoor() return self._door end
  function vpart:getInventoryItem() return {} end
  function vpart:getArea() return "TruckBed" end
  function vpart:getIndex() return 3 end
  local vehicle = { _vehicle = true, _sq = Sq(10, 12, 0, nil) }
  function vehicle:getPartById(id) if id == "TruckBed" then return vpart end return nil end
  function vehicle:getPartCount() return 1 end
  function vehicle:getPartByIndex() return vpart end
  function vehicle:getId() return 7 end
  function vehicle:getSquare() return self._sq end
  function vpart:getVehicle() return vehicle end
  trunk._parent = vehicle
  trunk._part = vpart
  vehicle._sq._vehicle = vehicle
  vehicles[#vehicles + 1] = vehicle
  fill(trunk, 3, { type = "Base.Hat", cat = "Clothing", weight = 0.5, name = "Hat" })

  local src = S.vehicleSource(vehicle)
  assert(src and src.kind == "vehicle" and src.id == 7 and src.container == trunk, "the trunk is the source")
  local saved = S.saveSource(src)
  local back = S.loadSource(saved, player)
  assert(back and back.vehicle == vehicle, "a vehicle is found again by id")
  -- a run on the glove box resumes on the glove box, not the trunk (2026-10-22)
  local glove = Cont("glovebox", 5)
  local gpart = { _c = glove }
  function gpart:getItemContainer() return self._c end
  function gpart:getId() return "GloveBox" end
  function gpart:getVehicle() return vehicle end
  function gpart:getDoor() return nil end
  function gpart:getInventoryItem() return {} end
  glove._parent, glove._part = vehicle, gpart
  local byId = vehicle.getPartById
  function vehicle:getPartById(id) if id == "GloveBox" then return gpart end return byId(self, id) end
  local gsrc = S.vehicleSource(vehicle, gpart)
  assert(S.saveSource(gsrc).part == "GloveBox", "the part is saved with the source")
  local gback = S.loadSource(S.saveSource(gsrc), player)
  assert(gback and gback.vpart == gpart and gback.container == glove, "the glove box again")
  assert(S.loadSource(S.saveSource(src), player).container == trunk, "and the trunk is still the trunk")
  assert(S.loadSource({ kind = "vehicle", id = 99, x = 10, y = 12, z = 0 }, player) == nil, "a gone vehicle is not")
  assert(S.findVehicle(7, 13, 15, 0) == vehicle, "found a few tiles off where it was parked")
  assert(S.loadSource({ kind = "object", key = "14,12,0:wardrobe:0" }, player).container == wardrobe, "an object source by key")

  doorsOpened = 0
  walks = {}
  H.clearHalo()
  R.start(player, src, {})
  drive()
  assert(doorsOpened >= 1 and door._open, "the trunk lid was opened on the way")
  assert(#wardrobe._items == 6 and #trunk._items == 0, "hats from the trunk to the wardrobe")
  assert(walks[1] == trunk, "walked to the trunk first")

  -- a full bag in the trunk is unpacked: hats to the wardrobe, then the empty bags by their rule
  local duffel = Item({ type = "Base.Bag_DuffelBag", cat = "Bag", weight = 1, name = "Duffel Bag", bag = { capacity = 20 } })
  trunk:add(duffel)
  fill(duffel._inv, 2, { type = "Base.Hat", cat = "Clothing", weight = 0.5, name = "Hat" })
  local pouch = Item({ type = "Base.Pouch", cat = "Bag", weight = 0.2, name = "Pouch", bag = { capacity = 2 } })
  duffel._inv:add(pouch)
  fill(pouch._inv, 1, { type = "Base.Hat", cat = "Clothing", weight = 0.5, name = "Hat" })
  local rec = S.itemRecord(duffel)
  assert(rec.bag and math.abs(rec.weight - 2.7) < 1e-6, "a full bag weighs its contents too: " .. tostring(rec.weight))
  local all = S.allItems(trunk)
  assert(#all == 5, "the trunk's walk opens the bags: " .. #all)
  local hatInPouch
  for _, r in ipairs(all) do if r.item._container == pouch._inv then hatInPouch = r end end
  assert(hatInPouch and hatInPouch.from == pouch._inv and hatInPouch.parent == pouch:getID(), "an item knows the bag it sits in")
  BU.store().rules["Base.Bag_DuffelBag"] = "14,12,0:wardrobe:0"
  BU.store().rules["Base.Pouch"] = "14,12,0:wardrobe:0"
  local wardrobeBefore = #wardrobe._items
  R.start(player, S.vehicleSource(vehicle), {})
  drive()
  assert(#trunk._items == 0, "the trunk is empty: " .. #trunk._items)
  assert(#wardrobe._items == wardrobeBefore + 5, "all three hats to the wardrobe, out of both bags, then the bags")
  assert(duffel._container == wardrobe and pouch._container == wardrobe, "both bags by their rule")
  assert(#duffel._inv._items == 0 and #pouch._inv._items == 0, "and they went empty")
  BU.store().rules["Base.Bag_DuffelBag"] = nil
  BU.store().rules["Base.Pouch"] = nil
  -- out of the world again, for the checks below that count the wardrobe
  while #wardrobe._items > wardrobeBefore do wardrobe:remove(wardrobe._items[#wardrobe._items]) end
end

-- the core's routing with bags: inner first, a bag waits for what is going out of it ------------------------

do
  local conts = { { key = "a", free = 100, x = 0, y = 0, z = 0 }, { key = "b", free = 100, x = 1, y = 0, z = 0 } }
  local function ctx()
    return { rules = { ["T.Hat"] = "a", ["T.Bag"] = "b" }, containers = conts, use = {}, pos = { x = 0, y = 0, z = 0 },
             ruleCounts = { a = 1, b = 1 } }
  end
  local A = { id = 1, fullType = "T.Bag", bag = true, weight = 1 }
  local hat = { id = 2, fullType = "T.Hat", parent = 1, weight = 0.5 }
  local B = { id = 3, fullType = "T.Bag", bag = true, parent = 1, weight = 0.3 }
  local junk = { id = 4, fullType = "T.Junk", parent = 3, weight = 0.1 }
  local items, nowhere = BU.route({ A, hat, B, junk }, ctx())
  assert(#items == 2 and hat.dest == "a" and B.dest == "b" and A.dest == nil, "the hat goes, the inner bag goes with its junk, the outer bag waits")
  assert(nowhere == 0, "the junk rides in its bag, the waiting bag is not 'nowhere': " .. nowhere)
  items, nowhere = BU.route({ A }, ctx())
  assert(#items == 1 and A.dest == "b" and nowhere == 0, "emptied, the bag goes by its rule")
  local box = { id = 5, fullType = "T.Box", bag = true, weight = 1 }
  local odd = { id = 6, fullType = "T.Junk", parent = 5, weight = 0.1 }
  items, nowhere = BU.route({ box, odd }, ctx())
  assert(#items == 0 and nowhere == 2, "a bag with no home and nothing going out of it: both nowhere")
  local worn = { id = 7, fullType = "T.Bag", bag = true, equipped = true }
  local inWorn = { id = 8, fullType = "T.Hat", parent = 7, weight = 0.5 }
  items = BU.route({ worn, inWorn }, ctx())
  assert(#items == 1 and inWorn.dest == "a" and worn.dest == nil, "a worn bag stays on; what is in it goes")
  local c = ctx()
  BU.route({ A, hat }, c)
  assert(c.use.a == 0.5 and c.use.b == nil, "a waiting bag reserves no room")
end

-- what I am carrying ----------------------------------------------------------------------------------------

do
  local bag = player._inv._items[1]
  assert(bag and bag._bag, "the worn bag is still there")
  fill(bag._inv, 2, { type = "Base.CannedBeans", cat = "Food", weight = 0.8, name = "Canned Beans", food = true })
  fill(player._inv, 1, { type = "Base.Hat", cat = "Clothing", weight = 0.5, name = "Hat" })
  fill(player._inv, 1, { type = "Base.Mystery", cat = "Odd", weight = 0.5, name = "Mystery" })
  local src = S.selfSource(player)
  H.clearHalo()
  walks = {}
  R.start(player, src, {})
  drive()
  assert(#fridge._items == 12 and #wardrobe._items == 7, "beans from the bag and the hat from the hands put away")
  assert(#player._inv._items == 1, "only the bag stays; the odd item found the nearest free container: " .. #player._inv._items)
  assert(#bag._inv._items == 0, "the bag is empty")
  for _, c in ipairs(walks) do assert(c ~= player._inv, "no walk to oneself") end
end

-- a put-away run that cannot deliver gives up on the item and ends; it never spins on it
-- (2026-10-22: with the bag as the source, the next load routed the item straight back to the
-- same container every tick and the character froze)
do
  -- the locker's rule says bricks, the locker refuses them
  BU.store().rules["Base.Brick"] = "9,10,0:locker:0"
  local brick = fill(player._inv, 1, { type = "Base.Brick", cat = "Material", weight = 1, name = "Brick" })[1]
  H.clearHalo()
  R.start(player, S.selfSource(player), {})
  local steps = drive(40)
  assert(count(R.active) == 0 and not R.hasPlan(player), "refused: the run ended")
  assert(steps <= 4, "and did not spin: " .. steps .. " steps")
  local stuck = false
  for _, t in ipairs(H.halo) do if t == "IGUI_BU_Stuck" then stuck = true end end
  assert(not stuck, "given up, not stuck")
  player._inv:remove(brick)
  BU.store().rules["Base.Brick"] = nil
  -- a container that cannot be reached
  fill(player._inv, 1, { type = "Base.CannedBeans", cat = "Food", weight = 0.8, name = "Canned Beans", food = true })
  walkResult = false
  H.clearHalo()
  R.start(player, S.selfSource(player), {})
  steps = drive(40)
  walkResult = true
  assert(count(R.active) == 0 and not R.hasPlan(player), "unreachable: the run ended")
  assert(steps <= 4, "and did not spin: " .. steps .. " steps")
  assert(#player._inv._items == 2, "the beans stay in hand")
  player._inv:remove(player._inv._items[2])
end

-- a tagged container as the fallback home -----------------------------------------------------------------------

do
  BU.store().rules["Base.Hat"] = nil
  BU.setTag(BU.store().tags, "13,7,0:crate:0", "Clothing", true)
  -- gloves: nothing in the base holds any, so the Clothing tag decides (the wardrobe's clothing comes after tags)
  fill(source, 2, { type = "Base.Gloves", cat = "Clothing", weight = 0.5, name = "Gloves" })
  local before = #shed._items
  local src = S.objectSource(squares["10,10,0"]._objs[1], source, nil)
  R.start(player, src, {})
  drive()
  assert(#shed._items == before + 2, "gloves went to the crate tagged Clothing: " .. #shed._items)
  BU.store().tags["13,7,0:crate:0"] = nil
  BU.store().rules["Base.Hat"] = "14,12,0:wardrobe:0"
end

-- dirty clothes go to the laundry cart ----------------------------------------------------------------------------------

do
  local cart = Cont("clothingdryerbasic", 20)
  Obj(Sq(9, 11, 0, "bathroom"), { cart })
  BU.store().rules["Base.Shirt"] = "14,12,0:wardrobe:0"
  fill(source, 1, { type = "Base.Shirt", cat = "Clothing", weight = 0.5, name = "Shirt", clothing = true })
  fill(source, 1, { type = "Base.Shirt", cat = "Clothing", weight = 0.5, name = "Shirt", clothing = true, dirty = true })
  fill(source, 1, { type = "Base.Shirt", cat = "Clothing", weight = 0.5, name = "Shirt", clothing = true, blood = 0.3 })
  local recs = S.items(source)
  local dirty = 0
  for _, r in ipairs(recs) do if r.laundry then dirty = dirty + 1 end end
  assert(dirty == 2, "the dirty and the bloody shirt are laundry: " .. dirty)
  local wardrobeBefore = #wardrobe._items
  local src = S.objectSource(squares["10,10,0"]._objs[1], source, nil)
  R.start(player, src, {})
  drive()
  assert(#cart._items == 2, "two shirts in the laundry cart: " .. #cart._items)
  assert(#wardrobe._items == wardrobeBefore + 1, "the clean one in the wardrobe")
  -- the option off: all three would have gone to the wardrobe
  SandboxVars.BaseUnloader.Laundry = false
  fill(source, 1, { type = "Base.Shirt", cat = "Clothing", weight = 0.5, name = "Shirt", clothing = true, dirty = true })
  assert(not S.items(source)[#source._items].laundry, "with the option off a dirty shirt is just a shirt")
  SandboxVars.BaseUnloader.Laundry = true
  for _, it in ipairs({ source._items[#source._items] }) do source:remove(it) end
  BU.store().rules["Base.Shirt"] = nil
end

-- items with nowhere to go take no bag room ---------------------------------------------------------------------------

do
  -- an anvil no container has room for, listed before three planks for the shed:
  -- the anvil takes no room in the bag or the budget, so the planks go in one load
  BU.store().rules["Base.Anvil"] = "1,1,0:crate:0"
  BU.store().rules["Base.Plank"] = "13,7,0:crate:0"
  fill(source, 1, { type = "Base.Anvil", cat = "Tool", weight = 40, name = "Anvil" })
  fill(source, 3, { type = "Base.Plank", cat = "Material", weight = 2, name = "Plank" })
  local shedBefore = #shed._items
  local src = S.objectSource(squares["10,10,0"]._objs[1], source, nil)
  walks = {}
  H.clearHalo()
  R.start(player, src, {})
  drive()
  assert(#shed._items == shedBefore + 3, "all three planks arrived: " .. (#shed._items - shedBefore))
  local loads = 0
  for _, c in ipairs(walks) do if c == source then loads = loads + 1 end end
  assert(loads == 1, "in a single load, the anvil not counted against the bag: " .. loads)
  local nowhere = false
  for _, t in ipairs(H.halo) do if t == "IGUI_BU_Nowhere:1" then nowhere = true end end
  assert(nowhere, "the anvil is reported once as having nowhere to go")
  local anvils = {}
  for _, it in ipairs(source._items) do if it:getFullType() == "Base.Anvil" then anvils[#anvils + 1] = it end end
  assert(#anvils == 1, "the anvil stays in the crate")
  source:remove(anvils[1])
  BU.store().rules["Base.Anvil"] = nil
  BU.store().rules["Base.Plank"] = nil
end

-- a container the game counts as full: the overflow goes next door -----------------------------------------------

do
  -- a tin with a nominal 4 but, for this character, room for 2; a crate tagged Material with plenty
  local tin = Cont("counter", 4)
  tin._eff = 0.5
  Obj(Sq(11, 11, 0, "garage"), { tin })
  BU.store().rules["Base.Nail"] = "11,11,0:counter:0"
  BU.setTag(BU.store().tags, "13,7,0:crate:0", "Material", true)
  fill(source, 3, { type = "Base.Nail", cat = "Material", weight = 1, name = "Nail" })
  local shedBefore = #shed._items
  local src = S.objectSource(squares["10,10,0"]._objs[1], source, nil)
  local zone = S.zone(player, crateSq)
  local rows = S.containers(zone, source, player)
  local tinRow
  for _, row in ipairs(rows) do if row.key == "11,11,0:counter:0" then tinRow = row end end
  assert(tinRow and tinRow.capacity == 2 and tinRow.free == 2, "the row carries the effective capacity: " .. tostring(tinRow and tinRow.capacity))
  H.clearHalo()
  R.start(player, src, {})
  drive()
  assert(#tin._items == 2, "two nails fit the tin: " .. #tin._items)
  assert(#shed._items == shedBefore + 1, "the third went to the crate tagged Material")
  local stuck = false
  for _, t in ipairs(H.halo) do if t == "IGUI_BU_Stuck" or t == "IGUI_BU_Paused" then stuck = true end end
  assert(not stuck, "no pause or stuck on a full container")
  -- and when the game says no at the shelf itself (the bag was loaded on a stale count)
  fill(source, 1, { type = "Base.Nail", cat = "Material", weight = 1, name = "Nail" })
  R.start(player, src, {})
  H.fire("OnTick")                      -- loaded for the tin, as the planner saw room...
  tin._eff = 0.25                       -- ...but by the time of the delivery it has none
  drive()
  assert(#shed._items == shedBefore + 2, "the game's own refusal at the shelf reroutes to the tagged crate")
  BU.store().rules["Base.Nail"] = nil
  BU.store().tags["13,7,0:crate:0"] = nil
end

-- cannot reach / in a vehicle ---------------------------------------------------------------------------------

do
  fill(source, 1, { type = "Base.Hat", cat = "Clothing", weight = 0.5, name = "Hat" })
  local src = S.objectSource(squares["10,10,0"]._objs[1], source, nil)
  walkResult = "error"
  H.clearHalo()
  R.start(player, src, {})
  drive(3)
  local told = false
  for _, t in ipairs(H.halo) do if t == "IGUI_BU_LeaveVehicle" then told = true end end
  assert(told and count(R.active) == 0, "walking from inside a vehicle pauses with the message")
  R.forget(player)
  walkResult = false
  H.clearHalo()
  R.start(player, src, {})
  drive(3)
  told = false
  for _, t in ipairs(H.halo) do if t == "IGUI_BU_CantReach" then told = true end end
  assert(told, "an unreachable source pauses with the message")
  R.forget(player)
  walkResult = true
end

-- the window and the menus load against stub UI ------------------------------------------------------------------

local function class(name)
  local c = { Type = name }
  c.__index = c
  function c.derive(base, n)
    local d = setmetatable({ Type = n }, { __index = base })
    d.__index = d
    return d
  end
  function c.new(self) return setmetatable({}, self) end
  return c
end
ISScrollingListBox = class("ISScrollingListBox")
ISCollapsableWindow = class("ISCollapsableWindow")
ISButton = class("ISButton")
ISTextEntryBox = class("ISTextEntryBox")
ISTextBox = class("ISTextBox")
ISContextMenu = class("ISContextMenu")
ISTickBox = class("ISTickBox")
ISComboBox = class("ISComboBox")
ISModalDialog = class("ISModalDialog")
ISAddDesignationAnimalZoneUI = class("ISAddDesignationAnimalZoneUI")
ISInventoryPane = { getActualItems = function(items) return items end }
local vanillaBackpackMenu = 0
ISInventoryPage = { onBackpackRightMouseDown = function() vanillaBackpackMenu = vanillaBackpackMenu + 1 end }
local playerMenu
getPlayerContextMenu = function() return playerMenu end
ISVehicleMenu = { FillMenuOutsideVehicle = function() return "vanilla" end }
UIFont = { Small = "small", Medium = "medium" }
getTextManager = function() return { getFontHeight = function() return 12 end, MeasureStringX = function() return 40 end } end
ISMouseDrag = {}
getSoundManager = function() return { playUISound = function() end } end
load("client/BaseUnloader_Zones.lua")
load("client/BaseUnloader_Stock.lua")
load("client/BaseUnloader_UI.lua")
load("client/BaseUnloader_Menu.lua")
local M = BU_Menu

-- a context menu that records its options
local function Menu()
  local m = { names = {}, subs = {} }
  function m:addOption(name, target, fn, a, b)
    self.names[#self.names + 1] = name
    return { name = name, target = target, fn = fn, a = a, b = b }
  end
  function m:addSubMenu(option, sub) self.subs[option.name] = sub end
  return m
end
function ISContextMenu:getNew(parent) return Menu() end

do
  -- right-click a crate in the world
  local menu = Menu()
  M.onWorldMenu(0, menu, { squares["10,10,0"]._objs[1] }, false)
  assert(menu.names[1] == "ContextMenu_BU_Title", "a Base Unloader entry")
  local sub = menu.subs["ContextMenu_BU_Title"]
  assert(sub.names[1] == "ContextMenu_BU_Unload" and sub.names[2] == "ContextMenu_BU_RenameContainer" and sub.names[3] == "IGUI_BU_TagFromContents" and sub.names[4] == "IGUI_BU_Categories" and sub.names[5] == "IGUI_BU_OffLimitsOn" and sub.names[6] == "ContextMenu_BU_Zones" and sub.names[7] == "ContextMenu_BU_Stock" and #sub.names == 7, "unload, rename, from-contents, categories, off limits, then zones and inventory, no plan: " .. table.concat(sub.names, ","))
  -- with a plan saved, Resume and Forget join
  BU.store().plans["dan"] = { source = { kind = "self" }, oneOffs = {}, carried = {} }
  menu = Menu()
  M.onWorldMenu(0, menu, {}, false)
  sub = menu.subs["ContextMenu_BU_Title"]
  assert(sub and sub.names[1] == "ContextMenu_BU_Resume" and sub.names[2] == "ContextMenu_BU_Forget", "resume and forget on an empty square")
  BU.store().plans["dan"] = nil
  -- the test pass adds nothing
  menu = Menu()
  M.onWorldMenu(0, menu, { squares["10,10,0"]._objs[1] }, true)
  assert(#menu.names == 0, "nothing on the test pass")
  -- items in a loot window: unload their container; my own items: put away
  menu = Menu()
  M.onInventoryMenu(0, menu, { wardrobe._items[1] })
  assert(menu.subs["ContextMenu_BU_Title"].names[1] == "ContextMenu_BU_Unload", "unload the wardrobe from its items")
  menu = Menu()
  M.onInventoryMenu(0, menu, { player._inv._items[1] })
  assert(menu.subs["ContextMenu_BU_Title"].names[1] == "ContextMenu_BU_PutAway", "put away from my own items")
  -- the vehicle menu keeps vanilla's result and adds the trunk option
  menu = Menu()
  local result = ISVehicleMenu.FillMenuOutsideVehicle(0, menu, vehicles[1], false)
  assert(result == "vanilla", "vanilla's return passes through")
  assert(menu.subs["ContextMenu_BU_Title"].names[1] == "ContextMenu_BU_UnloadTrunk", "unload trunk")
  menu = Menu()
  ISVehicleMenu.FillMenuOutsideVehicle(0, menu, vehicles[1], true)
  assert(#menu.names == 0, "nothing on the vehicle test pass")
  -- right-click on a container icon in the loot window: vanilla's menu first, then ours with the categories
  playerMenu = Menu()
  local button = { parent = { parent = { player = 0 } }, inventory = wardrobe }
  ISInventoryPage.onBackpackRightMouseDown(button, 0, 0)
  assert(vanillaBackpackMenu == 1, "vanilla's handler ran")
  sub = playerMenu.subs["ContextMenu_BU_Title"]
  assert(sub and sub.names[1] == "ContextMenu_BU_Unload" and sub.names[2] == "IGUI_BU_TagFromContents" and sub.names[3] == "IGUI_BU_Categories", "unload, from-contents and categories on the icon menu: " .. table.concat(sub and sub.names or {}, ","))
  M.onTagFromContents({ key = "14,12,0:wardrobe:0", cats = { Clothing = 2 } }, 0)
  assert(BU.hasTag(BU.store().tags, "14,12,0:wardrobe:0", "Clothing"), "tagged from contents off the icon menu")
  BU.store().tags["14,12,0:wardrobe:0"] = nil
  assert(sub.names[#sub.names] == "IGUI_BU_OffLimitsOn", "off limits last on the icon menu: " .. table.concat(sub.names, ","))
  M.onSetOffLimits({ key = "14,12,0:wardrobe:0" }, 0, true)
  assert(BU.store().offLimits["14,12,0:wardrobe:0"] == true, "off limits from the menu")
  playerMenu = Menu()
  ISInventoryPage.onBackpackRightMouseDown(button, 0, 0)
  local offSub = playerMenu.subs["ContextMenu_BU_Title"]
  assert(offSub.names[#offSub.names] == "IGUI_BU_OffLimitsOff", "the menu offers to lift it")
  M.onSetOffLimits({ key = "14,12,0:wardrobe:0" }, 0, false)
  assert(BU.store().offLimits["14,12,0:wardrobe:0"] == nil, "lifted from the menu")
  local cats = sub.subs["IGUI_BU_Categories"]
  assert(cats and #cats.names > 20, "the category list is there")
  local foodOpt
  for _, n in ipairs(cats.names) do if n == "[  ] Food" then foodOpt = n end end
  assert(foodOpt, "Food is offered, unticked")
  M.onToggleTag({ key = "14,12,0:wardrobe:0" }, 0, "Food")
  assert(BU.hasTag(BU.store().tags, "14,12,0:wardrobe:0", "Food"), "the tag is set from the menu")
  -- the remembered set is what was composed: a tick-off does not shrink it (2026-10-22)
  M.onToggleTag({ key = "14,12,0:wardrobe:0" }, 0, "Cooking")
  assert(table.concat(BU.store().lastTags, ",") == "Cooking,Food", "remembered as ticked on")
  M.onToggleTag({ key = "14,12,0:wardrobe:0" }, 0, "Cooking")
  assert(not BU.hasTag(BU.store().tags, "14,12,0:wardrobe:0", "Cooking") and table.concat(BU.store().lastTags, ",") == "Cooking,Food", "ticked off: the set remembered stands")
  BU.store().lastTags = { "Food" }   -- as the first tick left it, so the menu below has no "same as last" line
  playerMenu = Menu()
  ISInventoryPage.onBackpackRightMouseDown(button, 0, 0)
  cats = playerMenu.subs["ContextMenu_BU_Title"].subs["IGUI_BU_Categories"]
  local ticked = false
  for _, n in ipairs(cats.names) do if n == "[x] Food" then ticked = true end end
  assert(ticked and playerMenu.subs["ContextMenu_BU_Title"].names[4] == "IGUI_BU_ClearTags", "ticked, with Clear its categories")
  M.onClearTags({ key = "14,12,0:wardrobe:0" }, 0)
  assert(BU.store().tags["14,12,0:wardrobe:0"] == nil, "cleared from the menu")
  -- a bag's own icon and the floor get nothing from us
  playerMenu = Menu()
  ISInventoryPage.onBackpackRightMouseDown({ parent = { parent = { player = 0 } }, inventory = player._inv._items[1]._inv }, 0, 0)
  assert(playerMenu.subs["ContextMenu_BU_Title"] == nil or #playerMenu.names == 0, "nothing on a bag's icon")

  -- sitting in a vehicle: no options anywhere
  player._veh = vehicles[1]
  menu = Menu()
  M.onWorldMenu(0, menu, { squares["10,10,0"]._objs[1] }, false)
  assert(#menu.names == 0, "no world options from a seat")
  menu = Menu()
  M.onInventoryMenu(0, menu, { wardrobe._items[1] })
  assert(#menu.names == 0, "no inventory options from a seat")
  menu = Menu()
  assert(ISVehicleMenu.FillMenuOutsideVehicle(0, menu, vehicles[1], false) == "vanilla" and #menu.names == 0, "no trunk option from a seat")
  player._veh = nil
end

-- the window's pure parts: destination labels and assignments without widgets
do
  local win = setmetatable({ character = player, playerNum = 0, oneOffs = {}, rows = {}, byKey = {}, groups = {}, ruleCounts = {} }, BU_Window)
  win.fill = function() end
  win.source = { kind = "object", key = "10,10,0:crate:0" }
  local zone = S.zone(player, crateSq)
  win.rows = S.containers(zone, source)
  for _, row in ipairs(win.rows) do win.byKey[row.key] = row end
  local recs = { { id = 1, fullType = "Base.Saw", name = "Saw", category = "Tool", weight = 1 },
                 { id = 2, fullType = "Base.Saw", name = "Saw", category = "Tool", weight = 1 } }
  win.groups = BU.groups(recs)
  local g = win.groups[1]
  win.ruleCounts = BU.ruleCounts(BU.store().rules)
  local name0, how0 = win:destinationLabel(g)
  assert(how0 == "nearest", "with no rule a saw goes to the nearest free container: " .. tostring(how0))
  local wr = win.byKey["14,12,0:wardrobe:0"]
  win:assignGroup(g, wr, false)
  local name, how = win:destinationLabel(g)
  assert(name == wr.name and how == "rule", "a drop makes a type rule: " .. tostring(name) .. " " .. tostring(how))
  win:assignGroup(g, win.byKey["13,7,0:crate:0"], true)
  name, how = win:destinationLabel(g)
  assert(how == "oneoff", "Ctrl-drop makes one-offs that win")
  win.oneOffs[2] = nil
  name, how = win:destinationLabel(g)
  assert(how == "mixed", "half the items one-off reads mixed")
  win:unassign(g)
  win.ruleCounts = BU.ruleCounts(BU.store().rules)
  local _, howU = win:destinationLabel(g)
  assert(howU ~= "rule" and howU ~= "oneoff" and BU.store().rules["Base.Saw"] == nil, "unassign clears rule and one-offs")
  win:dropItems({ Item({ type = "Base.Saw", cat = "Tool" }) }, wr, false)
  assert(BU.store().rules["Base.Saw"] == wr.key, "items dragged from the inventory window set the rule")
  win:clearRulesTo(wr)
  assert(BU.store().rules["Base.Saw"] == nil, "clearRulesTo from the window")
  assert(not win:isAssigned(g), "a type with no rule and no one-off is unassigned, whatever the resolver infers")
  win:sendUnassigned(wr)
  assert(BU.store().rules["Base.Saw"] == wr.key and win:isAssigned(g), "send every type without a rule here")
  -- hiding: kept by key in the store, out of Suggest's reach
  local shed = win.byKey["13,7,0:crate:0"]
  assert(not win:isHidden(shed), "shown to start")
  win:setHidden(shed, true)
  assert(win:isHidden(shed) and BU.store().hidden[shed.key] == true, "hidden by key")
  local seen = {}
  for _, row in ipairs(win:visibleRows()) do seen[row.key] = true end
  assert(not seen[shed.key] and seen[wr.key], "visibleRows leaves the hidden one out")
  win:setHidden(shed, false)
  assert(BU.store().hidden[shed.key] == nil, "shown again")
  -- off limits: kept by key, out of Suggest's and Auto-tag's reach
  win:setOffLimits(shed, true)
  assert(win:isOffLimits(shed) and BU.store().offLimits[shed.key] == true, "off limits by key")
  seen = {}
  for _, row in ipairs(win:visibleRows()) do seen[row.key] = true end
  assert(not seen[shed.key] and seen[wr.key], "visibleRows leaves the off-limits one out")
  win:setOffLimits(shed, false)
  assert(BU.store().offLimits[shed.key] == nil, "open again")
  -- tags: the fallback home, shown as "tag"; cleared rules fall back to it
  win:unassign(g)
  win:toggleTag(shed, "Tool")
  assert(BU.hasTag(BU.store().tags, shed.key, "Tool"), "toggleTag on")
  name, how = win:destinationLabel(g)
  assert(name == shed.name and how == "tag", "a tagged container takes the category: " .. tostring(name) .. " " .. tostring(how))
  assert(win:tagLabel(shed) == "Tool", "tag label")
  win:toggleTag(shed, "Tool")
  local _, howT = win:destinationLabel(g)
  assert(howT ~= "tag" and BU.store().tags[shed.key] == nil, "toggleTag off")
  -- auto-tag: the wardrobe (shirts and hats) and the fridge (beans) take their categories
  local tagged = win:autoTag()
  assert(tagged >= 2, "containers with contents were tagged: " .. tagged)
  assert(BU.hasTag(BU.store().tags, wr.key, "Clothing"), "the wardrobe is tagged Clothing")
  assert(BU.hasTag(BU.store().tags, "12,10,0:fridge:0", "Food"), "the fridge is tagged Food")
  assert(win:autoTag() == 0, "a second pass adds nothing")
  -- clear all: every container in this base, hidden ones too, only after a yes; other bases keep theirs
  win:setHidden(wr, true)
  BU.store().tags["99,99,0:crate:0"] = { Tool = true }
  BU.store().rules["Base.Saw"] = wr.key
  local before = win:taggedCount()
  assert(before >= 2, "tagged containers counted: " .. before)
  win:onClearAllTags({ internal = "NO" })
  assert(win:taggedCount() == before, "No leaves the tags")
  win:onClearAllTags({ internal = "YES" })
  assert(win:taggedCount() == 0 and BU.store().tags[wr.key] == nil, "Yes clears them all, the hidden one too")
  assert(BU.hasTag(BU.store().tags, "99,99,0:crate:0", "Tool"), "a container outside this base keeps its tags")
  assert(BU.store().rules["Base.Saw"] == wr.key, "assignments stay")
  assert(win:clearAllTags() == 0, "nothing left to clear")
  BU.store().tags["99,99,0:crate:0"] = nil
  BU.store().rules["Base.Saw"] = nil
  win:setHidden(wr, false)
  for _, row in ipairs(win.rows) do BU.store().tags[row.key] = nil end
  local cats = win:categories()
  local hasFood, hasOdd = false, false
  for _, c in ipairs(cats) do if c == "Food" then hasFood = true end if c == "Tool" then hasOdd = true end end
  assert(hasFood and hasOdd, "the standard categories are offered")
  -- several groups dropped together
  local recs2 = { { id = 7, fullType = "Base.Hammer", name = "Hammer", category = "Tool", weight = 1 } }
  local g2 = BU.groups(recs2)[1]
  win:assignGroups({ g, g2 }, wr, false)
  assert(BU.store().rules["Base.Saw"] == wr.key and BU.store().rules["Base.Hammer"] == wr.key, "assignGroups sets a rule per type")
  win:unassignGroups({ g, g2 })
  assert(BU.store().rules["Base.Saw"] == nil and BU.store().rules["Base.Hammer"] == nil, "unassignGroups clears them")
end

-- base zones: the core's area helpers
do
  local house = { name = "House", rects = { { x1 = 0, y1 = 0, x2 = 9, y2 = 9, z = 0 } } }
  local loft = { name = "Loft", rects = { { x1 = 0, y1 = 0, x2 = 4, y2 = 4, z = 1 } } }
  assert(BU.areaDistance(house, 5, 5) == 0 and BU.areaDistance(house, 12, 9) == 3 and BU.areaDistance(house, 12, 13) == 5, "distance to the nearest edge")
  local areas = { house, loft }
  assert(BU.areaAt(areas, 2, 2, 0, 3) == 1, "the ground floor zone on the ground floor")
  assert(BU.areaAt(areas, 2, 2, 1, 3) == 2, "a zone drawn on this floor beats one drawn below")
  assert(BU.areaAt(areas, 8, 8, 1, 3) == 1, "upstairs of the house zone, outside the loft, is the house")
  assert(BU.areaAt(areas, 8, 8, 1, 0) == nil, "with no floors searched the house zone stays on its floor")
  assert(BU.areaAt(areas, 20, 2, 0, 3) == nil, "outside every zone")
  local near = BU.nearAreas({ { name = "Far", rects = { { x1 = 50, y1 = 0, x2 = 55, y2 = 5, z = 0 } } }, loft, house }, 12, 2, 10)
  assert(#near == 2 and near[1].name == "House" and near[2].name == "Loft", "within reach, nearest first")
  -- two bases both called "Base": only the piece in reach comes along
  local split = BU.nearAreas({ { name = "Base", rects = { { x1 = 0, y1 = 0, x2 = 3, y2 = 3, z = 0 }, { x1 = 200, y1 = 0, x2 = 203, y2 = 3, z = 0 } } } }, 1, 1, 40)
  assert(#split == 1 and #split[1].rects == 1 and split[1].rects[1].x1 == 0, "the far piece of the same name stays behind")

  -- drawing, naming, renaming, removing
  local store = { zones = {}, stock = {} }
  assert(BU.nextZoneName(store, "Base") == "Base", "the first zone is offered as Base")
  local a = BU.addZone(store, "House", 5, 9, 1, 2, 0)
  assert(a.x1 == 1 and a.y1 == 2 and a.x2 == 5 and a.y2 == 9 and a.z == 0, "corners put in order")
  assert(BU.nextZoneName(store, "Base") == "House", "the next piece is offered the last name, to add to it")
  local b = BU.addZone(store, "House", 6, 2, 8, 4, 0)
  local c = BU.addZone(store, "Shed", 20, 20, 22, 22, 0)
  local za = BU.zoneAreas(store.zones)
  assert(#za == 2 and za[1].name == "House" and #za[1].rects == 2 and za[2].name == "Shed", "pieces of one name are one zone, in the order drawn")
  assert(BU.zoneSizeOk(1, 1) and BU.zoneSizeOk(BU.ZONE_MAX, 3) and not BU.zoneSizeOk(BU.ZONE_MAX + 1, 3) and not BU.zoneSizeOk(0, 4), "size limits")
  store.stock[BU.pieceKey(c)] = { zone = "Shed", at = 1, items = {} }
  BU.renameZone(store, c, "House")
  assert(#BU.zoneAreas(store.zones) == 1 and store.stock["Shed|20,20,22,22,0"] == nil, "a renamed piece joins that zone; its old count goes")
  BU.renameZone(store, c, "")
  assert(c.name == "House", "an empty name changes nothing")
  BU.removeZone(store, b)
  assert(#store.zones == 2 and store.zones[1] == a and store.zones[2] == c, "removed")

  -- the stock helpers
  local recs = { { fullType = "Base.Axe", name = "Axe", category = "Weapon", containerKey = "k1", containerName = "Crate" },
                 { fullType = "Base.Axe", name = "Axe", category = "Weapon", containerKey = "k1", containerName = "Crate" },
                 { fullType = "Base.Axe", name = "Axe", category = "Weapon", containerKey = "k2", containerName = "Shelf" },
                 { fullType = "Base.Saw", name = "Saw", category = "Tool", containerKey = nil, containerName = "On the floor" } }
  local items = BU.stockOf(recs)
  assert(#items == 3 and items[1].q == 2 and items[1].cn == "Crate" and items[2].q == 1 and items[3].k == nil, "one entry per container and type")
  local stock = {
    ["House|1"] = { zone = "House", at = 10, items = items },
    ["House|2"] = { zone = "House", at = 4, items = { { t = "Base.Axe", n = "Axe", c = "Weapon", k = "k9", cn = "Box", q = 5 } } },
    ["Shed|1"] = { zone = "Shed", at = 2, items = { { t = "Base.Axe", n = "Axe", c = "Weapon", k = "k3", cn = "Bin", q = 1 } } },
  }
  local total, byZone = BU.stockCount(stock, "Base.Axe")
  assert(total == 9 and byZone[1].zone == "House" and byZone[1].q == 8 and byZone[2].zone == "Shed", "counted across pieces, by zone, most first")
  assert(BU.stockCount(stock, "Base.Hammer") == 0, "none")
  local rows = BU.stockRows(stock, 50, { ["House|1"] = true })
  assert(#rows == 5, "a row per zone, container and type: " .. #rows)
  local fresh, stale = 0, 0
  for _, r in ipairs(rows) do if r.age then stale = stale + 1 else fresh = fresh + 1 end end
  assert(fresh == 3 and stale == 2, "pieces counted now have no age, the rest their age")
  BU.sortStock(rows, "count", true)
  assert(rows[1].count == 5, "sorted by count, most first")
  BU.sortStock(rows, "zone")
  assert(rows[#rows].zone == "Shed", "sorted by zone")
  assert(BU.stockMatch({ name = "Axe", category = "Weapon", zone = "House", container = "Crate" }, "crat", "all"), "matches any field")
  assert(not BU.stockMatch({ name = "Axe", category = "Weapon", zone = "House", container = "Crate" }, "crat", "name"), "or just the one")
  assert(BU.stockMatch({ name = "Axe" }, "", "name"), "an empty search matches")
end

-- the scan with base zones: only what is inside them, each row knowing its zone
do
  local store = BU.store()
  BU.addZone(store, "House", 11, 10, 12, 10, 0)     -- the medicine cabinet and the fridge
  BU.addZone(store, "House", 14, 12, 14, 12, 0)     -- the wardrobe: a second piece of the house
  BU.addZone(store, "Shed", 13, 7, 13, 7, 0)
  BU.addZone(store, "Far", 30, 30, 30, 30, 0)       -- out of reach
  SandboxVars.BaseUnloader.ZoneReach = 15
  local zone = S.zone(player, crateSq)
  assert(zone.areas and #zone.areas == 2, "two areas within reach: " .. tostring(zone.areas and #zone.areas))
  assert(zone.areas[1].name == "House" and #zone.areas[1].rects == 2 and zone.areas[2].name == "Shed", "pieces of one name are one zone, nearest first")
  local rows = S.containers(zone, source, player)
  local byKey = {}
  for _, row in ipairs(rows) do byKey[row.key] = row end
  assert(#rows == 5, "the medicine cabinet, fridge, freezer, wardrobe and shed crate: " .. #rows)
  assert(byKey["11,10,0:medicine:0"].area == 1 and byKey["12,10,0:freezer:1"].area == 1 and byKey["14,12,0:wardrobe:0"].area == 1, "in the house area")
  assert(byKey["13,7,0:crate:0"].area == 2, "the shed crate in the shed area")
  assert(not byKey["30,30,0:crate:0"], "the far zone is out of reach")

  -- the window: zone by zone, tagged apart from the rest
  local added, win_c = {}, nil
  local function fakeList()
    return { clear = function() added = {} end, getYScroll = function() return 0 end, setYScroll = function() end,
             getScrollHeight = function() return 0 end, setScrollHeight = function() end,
             addItem = function(self, text, item) local it = { height = 10, item = item }; if self == win_c then added[#added + 1] = item end; return it end }
  end
  local win = setmetatable({ character = player, playerNum = 0, oneOffs = {}, groups = {}, ruleCounts = {}, source = { kind = "object" } }, BU_Window)
  win_c = fakeList()
  win.containerList = win_c
  win.itemList = fakeList()
  win.filterBox = { getInternalText = function() return "" end }
  win.zone, win.rows = zone, rows
  BU.store().tags["14,12,0:wardrobe:0"] = { Clothing = true }
  win:fill()
  local seq = {}
  for _, it in ipairs(added) do seq[#seq + 1] = it.header and it.text or it.key end
  local text = table.concat(seq, " | ")
  assert(seq[1] == "IGUI_BU_Zone:House" and seq[2] == "IGUI_BU_Tagged:1" and seq[3] == "14,12,0:wardrobe:0" and seq[4] == "IGUI_BU_Untagged:3", "house: tagged first: " .. text)
  assert(seq[8] == "IGUI_BU_Zone:Shed" and seq[9] == "IGUI_BU_Untagged:1" and seq[10] == "13,7,0:crate:0" and #seq == 10, "then the shed: " .. text)
  assert(added[1].style == "zone" and added[2].style == "tagged" and added[4].style == "untagged", "header styles")
  -- no zone drawn: one heading with the note
  local saved = store.zones
  store.zones = {}
  win.zone = S.zone(player, crateSq)
  win.rows = S.containers(win.zone, source, player)
  win:fill()
  assert(added[1].text == "IGUI_BU_NoZone:" .. #win.rows and added[1].note == "IGUI_BU_NoZoneNote" and added[2].style == "tagged", "no zone: the old search under one heading: " .. tostring(added[1].text))
  BU.store().tags["14,12,0:wardrobe:0"] = nil
  store.zones = saved

  -- the stock: what every loaded piece holds, the floor too, kept per piece
  local floorSaw = Item({ type = "Base.Saw", cat = "Tool", name = "Saw" })
  squares["11,10,0"]._floor = { floorSaw }
  local counted = S.refreshStock(store)
  assert(counted[BU.pieceKey(store.zones[1])] and counted[BU.pieceKey(store.zones[3])], "the loaded pieces were counted")
  local bandages = BU.stockCount(store.stock, "Base.Bandage")
  local shirts, byZone = BU.stockCount(store.stock, "Base.Shirt")
  local function held(c, t) local n = 0; for _, it in ipairs(c._items) do if it:getFullType() == t then n = n + 1 end end; return n end
  local wantB, wantS = held(medicine, "Base.Bandage"), held(wardrobe, "Base.Shirt")
  assert(wantB > 0 and bandages == wantB and shirts == wantS and byZone[1].zone == "House", "the medicine cabinet's bandages and the wardrobe's shirts: " .. bandages .. "/" .. wantB .. " " .. shirts .. "/" .. wantS)
  assert(BU.stockCount(store.stock, "Base.Saw") == 1, "the saw on the floor counts")
  -- the house out of range: its count stands
  local savedSq = squares["11,10,0"]
  squares["11,10,0"] = nil
  local counted2 = S.refreshStock(store)
  assert(not counted2[BU.pieceKey(store.zones[1])] and BU.stockCount(store.stock, "Base.Bandage") == wantB, "a piece out of range keeps its last count")
  squares["11,10,0"] = savedSq
  squares["11,10,0"]._floor = nil

  -- the item menu says how many are at base, and opens the inventory searched for it
  local opened
  local realOpen = BU_StockWindow.open
  BU_StockWindow.open = function(_, search) opened = search end
  local menu = Menu()
  M.addStockLine(menu, player, wardrobe._items[1])
  assert(menu.names[1] == "ContextMenu_BU_AtBase:" .. wantS, "the shirts at base: " .. tostring(menu.names[1]))
  menu = Menu()
  M.addStockLine(menu, player, Item({ type = "Base.Hammer", cat = "Tool" }))
  assert(menu.names[1] == "ContextMenu_BU_AtBaseNone", "none of these")
  menu = Menu()
  M.onInventoryMenu(0, menu, { wardrobe._items[1] })
  assert(menu.names[1] == "ContextMenu_BU_AtBase:" .. wantS and menu.names[2] == "ContextMenu_BU_Title", "the at-base line on the item's own menu, first")
  menu = Menu()
  M.onInventoryMenu(0, menu, { wardrobe._items[1], Item({ type = "Base.Hammer", cat = "Tool" }) })
  assert(menu.names[1] == "ContextMenu_BU_Title", "no at-base line for two types")
  M.onStock(player, "Shirt")
  assert(opened == "Shirt", "the line opens the base inventory searched for the item")
  BU_StockWindow.open = realOpen
  -- the world menu always offers the zones and the inventory
  menu = Menu()
  M.onWorldMenu(0, menu, {}, false)
  local sub = menu.subs["ContextMenu_BU_Title"]
  assert(sub and sub.names[#sub.names - 1] == "ContextMenu_BU_Zones" and sub.names[#sub.names] == "ContextMenu_BU_Stock", "zones and inventory at the foot")

  for i = #store.zones, 1, -1 do table.remove(store.zones, i) end
  store.stock = {}
  SandboxVars.BaseUnloader.ZoneReach = nil
end

H.pass("baseunloader")
