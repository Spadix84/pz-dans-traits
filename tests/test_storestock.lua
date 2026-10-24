-- Offline test for Dan's Vanilla Fixes store stock
-- (DansVanillaFixes/42/media/lua/shared/DansVanillaFixes_StoreStock.lua): a
-- cigarette pack that spawns part-used in a shop room is filled back up; one
-- in a house, any other item, and a loot-table entry passed instead of a
-- container are left alone.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local HERE = arg[0]:match("^(.*)[/\\]") or "."
dofile(HERE .. "/../DansVanillaFixes/42/media/lua/shared/DansVanillaFixes_StoreStock.lua")
local fill = H.only("OnFillContainer")

local function pack(fullType, uses)
  local item = { uses = uses }
  function item:getFullType() return fullType end
  function item:getMaxUses() return 20 end
  function item:getCurrentUses() return self.uses end
  function item:setCurrentUses(n) self.uses = n end
  return item
end

local function container(list)
  return { getItems = function() return { size = function() return #list end, get = function(_, i) return list[i + 1] end } end,
    AddItem = function() end }
end

-- 1. a gas station shelf: part packs filled, a full one and other items untouched
local a, b, c, gum = pack("Base.CigarettePack", 7), pack("Base.CigarettePack", 20), pack("Base.CigarettePack", 1),
  pack("Base.Gum", 3)
fill("gasstore", "shelves", container({ a, b, c, gum }))
assert(a.uses == 20 and b.uses == 20 and c.uses == 20, "store packs are full")
assert(gum.uses == 3, "other items keep their roll")

-- 2. every retail room counts
for room in pairs(DVF_StoreStock.ROOMS) do
  local p = pack("Base.CigarettePack", 4)
  fill(room, "counter", container({ p }))
  assert(p.uses == 20, room .. ": filled")
end

-- 3. a house keeps vanilla's random pack
local home = pack("Base.CigarettePack", 5)
fill("bedroom", "sidetable", container({ home }))
assert(home.uses == 5, "a bedroom pack stays part-used")
fill(nil, "counter", container({ home }))
assert(home.uses == 5, "no room name: left alone")

-- 4. a loot-table entry instead of a container, and an item that throws
fill("gasstore", "counter", { "not a container" })
local broken = pack("Base.CigarettePack", 2)
broken.getMaxUses = function() error("no uses") end
local after = pack("Base.CigarettePack", 2)
fill("gasstore", "counter", container({ broken, after }))
assert(after.uses == 20, "an error on one item does not stop the rest")
H.pass()
