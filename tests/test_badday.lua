-- Offline test for DanTraits_BadDay.lua: the opening applies once (drunk, a cold, a shard in the
-- groin, no clothes, soaked), is idempotent when the character is created again (a reload), does
-- nothing after the first hour or without the trait; the fire starts once, only indoors; and the
-- console replay (`badday`, DanTraits_BadDayReplay, plan 21) clears the flags and applies again.
-- No balance dial is tested here: they wait for a play test (plans/21-bad-day-balance.md).
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

H.pass()
