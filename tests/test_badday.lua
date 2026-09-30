-- Offline test for DanTraits_BadDay.lua: the opening applies once (drunk, a cold, a shard in the
-- groin, no clothes, soaked), is idempotent when the character is created again (a reload), does
-- nothing after the first hour or without the trait; the fire starts once, only indoors; and the
-- console replay (`badday`, DanTraits_BadDayReplay) clears the flags and applies again.
-- No balance dial is tested here: they wait for a play test (README, Status and known issues).
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("BadDay")
H.expectHooks("OnCreatePlayer", "OnGameStart")

local exploded = {}
IsoFireManager = { explode = function(_, square, power) exploded[#exploded + 1] = { square = square, power = power } end }
function getCell() return "cell" end
ArrayList = { new = function() local l = { _n = {} }; function l:add(x) self._n[#self._n + 1] = x end; return l end }

local function groinPart()
  local g = { _name = "Groin", _shards = 0, _wet = nil }
  function g:getType() return self._name end
  function g:generateDeepShardWound() self._shards = self._shards + 1 end
  function g:setWetness(w) self._wet = w end
  return g
end

-- a character of the opening: a groin, the cold setters, a worn shirt, and a room (or none)
local function newPlayer(o)
  o = o or {}
  local groin = groinPart()
  local p = H.player({ traits = o.trait == false and {} or { "badday" }, hours = o.hours or 0, parts = { groin } })
  p._groin, p._cold = groin, { strength = nil, has = nil, catch = nil }
  local base = p.getBodyDamage
  p.getBodyDamage = function()
    local bd = base()
    bd.setHasACold = function(_, b) p._cold.has = b end
    bd.setColdStrength = function(_, v) p._cold.strength = v end
    bd.setTimeToSneezeOrCough = function() end
    bd.getBodyParts = function() return { size = function() return 1 end, get = function() return groin end } end
    return bd
  end
  p._worn = { "shirt", "jeans" }
  p.getWornItems = function()
    return { size = function() return #p._worn end, getItemByIndex = function(_, i) return p._worn[i + 1] end }
  end
  p.removeWornItem = function(_, item) p._removedWorn = (p._removedWorn or 0) + 1 end
  p.clearWornItems = function() p._cleared = true end
  local square = nil
  if o.room then
    local far = { getX = function() return 30 end, getY = function() return 30 end }
    local room = { getName = function() return "bedroom" end,
      getRandomSquare = function() return far end,
      getSquares = function() return { size = function() return 0 end } end }
    local building = { getRandomRoomExcluding = function() return room end }
    room.getBuilding = function() return building end
    square = { getRoom = function() return room end }
  end
  p.getCurrentSquare = function() return square end
  return p
end

-- 1. a fresh character with the trait: the whole opening, once
local p = newPlayer({ room = true }); H.current = p
H.fire("OnCreatePlayer", 0, p)
assert(p._st.intox == 100, "intoxication 100")
assert(p._cold.has == true and p._cold.strength == 50.0, "a cold at strength 50")
assert(p._groin._shards == 1, "one shard in the groin")
assert(p._cleared and p._removedWorn == 2, "no clothes left")
assert(p._st.wetness == 100 and p._groin._wet == 100, "soaked: stat and body parts")
assert(p._md.DanTraits.badDayApplied == true, "marked applied")

-- 2. created again (a reload, a respawn on the same character): nothing is applied twice
p._st.intox = 40; p._cold.strength = 20; p._removedWorn = nil
H.fire("OnCreatePlayer", 0, p)
assert(p._groin._shards == 1 and p._st.intox == 40 and p._cold.strength == 20 and p._removedWorn == nil, "idempotent")

-- 3. past the first hour: not a fresh character, nothing happens
local old = newPlayer({ hours = 3 }); H.current = old
H.fire("OnCreatePlayer", 0, old)
assert(old._groin._shards == 0 and old._st.intox == 0, "after the first hour: nothing")
assert(old._md.DanTraits == nil or not old._md.DanTraits.badDayApplied, "and not marked applied")

-- 4. without the trait: nothing
local plain = newPlayer({ trait = false }); H.current = plain
H.fire("OnCreatePlayer", 0, plain)
assert(plain._groin._shards == 0 and plain._st.intox == 0, "no trait: nothing")

-- 5. the fire: once, from a room far enough away, with a notice; not again on the next start
p = newPlayer({ room = true }); H.current = p
H.clearHalo()
H.fire("OnGameStart")
assert(#exploded == 1 and exploded[1].power == 100000 and H.halo[#H.halo] == "UI_DanTraits_BadDayFire", "fire lit, announced")
H.fire("OnGameStart"); assert(#exploded == 1, "the fire starts only once")
-- outdoors: no house to burn
local outside = newPlayer(); H.current = outside
H.fire("OnGameStart"); assert(#exploded == 1, "outdoors: no fire")

-- 6. the replay: flags cleared, the body's part applied again, no first-hour gate, the fire only on request
p = newPlayer({ room = true, hours = 50 }); H.current = p
p._md.DanTraits = { badDayApplied = true, badDayFireDone = true }
local text = DanTraits_BadDayReplay(p)
assert(text == "badday: opening replayed", text)
assert(p._groin._shards == 1 and p._st.intox == 100 and p._cold.strength == 50.0 and p._cleared, "replayed on a character past the first hour")
assert(p._md.DanTraits.badDayApplied == true and p._md.DanTraits.badDayFireDone == nil, "applied flag set, fire flag cleared")
assert(#exploded == 1, "no fire without the argument")
DanTraits_BadDayReplay(p); assert(p._groin._shards == 2, "each replay applies again (the console is for balancing)")
text = DanTraits_BadDayReplay(p, true)
assert(#exploded == 2 and text:find("fire started", 1, true), "badday fire lights it: " .. text)
local indoorsless = newPlayer({ hours = 50 })
text = DanTraits_BadDayReplay(indoorsless, true)
assert(#exploded == 2 and text:find("no fire", 1, true), "outdoors: says why there is no fire: " .. text)
assert(DanTraits_BadDayReplay(nil) == "badday: no player", "no player")

-- 7. the console command in Telemetry reaches it (see test_telemetry.lua for the harness of that file)
H.load("client/DanTraits_Telemetry.lua")
local reply = DanTraits_RunCommand(newPlayer({ hours = 9 }), "badday")
assert(reply == "badday: opening replayed", "the badday console command: " .. tostring(reply))

-- 8. the sewing kit: a needle and thread in another house 15 to 40 tiles away, once, safe from
-- Jinxed, put back if the game fills that container afterwards
local noRoom = function() return nil end
local own, other, farHouse = { getRandomRoomExcluding = noRoom }, { getRandomRoomExcluding = noRoom }, { getRandomRoomExcluding = noRoom }
local function container(kind, x, y)
  local c = { _kind = kind, _items = {} }
  local sq = { getX = function() return x end, getY = function() return y end, getZ = function() return 0 end }
  function c:getType() return self._kind end
  function c:getParent() return { getSquare = function() return sq end } end
  function c:containsType(t) for _, it in ipairs(self._items) do if it._type == t then return true end end return false end
  function c:AddItem(full)
    local md = {}
    local it = { _type = (string.gsub(full, "^Base%.", "")), getModData = function() return md end }
    self._items[#self._items + 1] = it
    return it
  end
  return c
end
local squares = {}
local function place(x, y, building, cont)
  local room = { getBuilding = function() return building end }
  local objs = {}
  if cont then objs[1] = { getContainerCount = function() return 1 end, getContainerByIndex = function() return cont end } end
  squares[x .. "," .. y] = { getRoom = function() return room end,
    getObjects = function() return { size = function() return #objs end, get = function(_, i) return objs[i + 1] end } end }
end
local ownDrawer = container("sidetable", 108, 100)  -- own house, 8 tiles
local fridge = container("fridge", 120, 100)         -- another house, but a fridge
local drawer = container("dresser", 125, 100)        -- another house, 25 tiles: the one
local distant = container("counter", 150, 100)       -- 50 tiles: only if nothing nearer
local tooClose = container("counter", 105, 100)      -- another house but 5 tiles
place(100, 100, own); place(108, 100, own, ownDrawer); place(120, 100, other, fridge)
place(125, 100, other, drawer); place(150, 100, farHouse, distant); place(105, 100, other, tooClose)
function getCell() return { getGridSquare = function(_, x, y, z) return z == 0 and squares[x .. "," .. y] or nil end } end
p = newPlayer(); H.current = p
p.getX = function() return 100 end; p.getY = function() return 100 end
p.getCurrentSquare = function() return squares["100,100"] end
H.fire("OnGameStart")
assert(#drawer._items == 2 and drawer._items[1]._type == "Needle" and drawer._items[2]._type == "Thread", "needle and thread in the dresser next door")
assert(#fridge._items == 0 and #ownDrawer._items == 0 and #distant._items == 0 and #tooClose._items == 0, "nowhere else")
assert(drawer._items[1]:getModData().DanTraitsKeep == true, "marked to keep")
local spot = p._md.DanTraits.badDayKit
assert(spot and spot.x == 125 and spot.kind == "dresser", "the spot is remembered")
H.fire("OnGameStart"); assert(#drawer._items == 2, "placed once")
-- the game fills that container later and the kit is gone: back it goes; other containers are left alone
drawer._items = {}
H.fire("OnFillContainer", "bedroom", "dresser", drawer)
assert(#drawer._items == 2, "refilled container gets the kit back")
H.fire("OnFillContainer", "bedroom", "counter", distant); assert(#distant._items == 0, "not another container")
-- nothing in range in other houses: out to 60, then the own house
squares["125,100"] = nil; squares["120,100"] = nil
local p2 = newPlayer(); p2.getX = p.getX; p2.getY = p.getY; p2.getCurrentSquare = p.getCurrentSquare
assert(DanTraits_BadDayPlaceKit(p2).x == 150, "out to 60 tiles when nothing nearer")
squares["150,100"] = nil
assert(DanTraits_BadDayPlaceKit(p2).x == 108, "own house far room as the last resort")
squares["108,100"] = nil
assert(DanTraits_BadDayPlaceKit(p2) == nil, "no container at all: no kit")

-- 9. Jinxed never takes the kit
H.load("Jinxed")
local jp = newPlayer(); jp.getX = p.getX; H.current = jp
DanTraits_HasTrait = function(_, k) return k == "jinxed" end
local jc = container("dresser", 1, 1); jc:AddItem("Base.Needle"):getModData().DanTraitsKeep = true
jc.getItems = function(self) local items = self._items; return { size = function() return #items end, get = function(_, i) return items[i + 1] end } end
jc.Remove = function(self, it) for i, x in ipairs(self._items) do if x == it then table.remove(self._items, i) end end end
local realRand = ZombRand; ZombRand = function() return 0 end
H.fire("OnFillContainer", "bedroom", "dresser", jc)
ZombRand = realRand
assert(#jc._items == 1, "Jinxed leaves the kit")

H.pass()
