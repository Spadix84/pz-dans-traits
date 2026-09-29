-- Offline test for DanTraits_Jinxed.lua: OnFillContainer with no player or no trait does nothing;
-- with the trait and a roll under 35 exactly one item leaves the container; a roll of 35 or more
-- leaves it alone; an empty or missing container is safe.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Jinxed")
H.expectHooks("OnFillContainer")

-- a container of n items that records what was removed
local function container(n)
  local items = {}
  for i = 1, n do items[i] = "item" .. i end
  local c = { _items = items, _removed = {} }
  function c:getItems()
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
  end
  function c:Remove(it)
    self._removed[#self._removed + 1] = it
    for i, x in ipairs(items) do if x == it then table.remove(items, i); break end end
  end
  return c
end

local fill = H.on("OnFillContainer")
local jinxed = H.player({ traits = { "jinxed" } })
local plain = H.player({ traits = {} })

-- 1. no player yet (containers fill before one exists): nothing, and no roll
H.current = nil
local c = container(4)
H.rolls = 0
fill("kitchen", "fridge", c)
assert(#c._removed == 0 and H.rolls == 0, "no player: nothing happens")

-- 2. a player without the trait
H.current = plain
fill("kitchen", "fridge", c)
assert(#c._removed == 0 and H.rolls == 0, "no trait: nothing happens")

-- 3. the trait and a roll under 35: exactly one item, the one the second roll picks
H.current = jinxed
H.rng = { 34, 2 }; fill("kitchen", "fridge", c)
assert(#c._removed == 1 and c._removed[1] == "item3", "removed the picked item, got " .. tostring(c._removed[1]))
assert(#c._items == 3, "three left")

-- 4. a roll of 35 or more: safe
local d = container(4)
H.rng = { 35 }; fill("kitchen", "fridge", d)
H.rng = { 99 }; fill("kitchen", "fridge", d)
assert(#d._removed == 0 and #d._items == 4, "roll 35+: nothing removed")

-- 5. an empty container is safe, and does not use the picking roll
local e = container(0)
H.rng = { 0, 0 }; fill("kitchen", "fridge", e)
assert(#e._removed == 0, "empty: nothing to remove")
H.rng = {}

-- 6. no container at all
H.rolls = 0
fill("kitchen", "fridge", nil)
assert(H.rolls == 0, "nil container: ignored before any roll")

-- 7. a container whose Remove throws must not break the fill
local f = container(2)
f.Remove = function() error("java said no") end
H.rng = { 0, 0 }
fill("kitchen", "fridge", f)

H.pass()
