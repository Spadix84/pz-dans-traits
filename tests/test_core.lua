-- Offline test for DanTraits.lua's shared helpers. So far: DanTraits_Wrap, the
-- one way files wrap a game method. Wrapping twice with the same tag wraps
-- once; different tags each add a layer and all of them run, innermost first;
-- a class without the method is left alone; a derived class keeps its own
-- tags apart from its parent's. And DanTraits_HasVanillaTrait's cache: one walk
-- of getKnownTraits per game minute, a re-walk after DanTraits_TraitsChanged,
-- OnGameStart or OnCreatePlayer, and a separate answer per player object.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("DanTraits")
assert(type(DanTraits_Wrap) == "function", "DanTraits_Wrap is exported")

local log = {}
local function make() return { run = function(self, x) log[#log + 1] = "base"; return x + 1 end } end

-- 1. the same tag twice: one layer
local A = make()
assert(DanTraits_Wrap(A, "run", "one", function(orig, self, x) log[#log + 1] = "one"; return orig(self, x) * 10 end) == true, "first wrap reports success")
assert(DanTraits_Wrap(A, "run", "one", function(orig, self, x) log[#log + 1] = "one-again"; return orig(self, x) end) == true, "second wrap with the same tag reports success")
log = {}
local got = A:run(1)
assert(got == 20, "wrapped once: (1 + 1) x 10, got " .. tostring(got))
assert(table.concat(log, ",") == "one,base", "only the first wrapper ran: " .. table.concat(log, ","))

-- 2. two tags: both run; the one added first is innermost (runs closest to the original)
local B = make()
DanTraits_Wrap(B, "run", "first", function(orig, self, x) log[#log + 1] = "first-in"; local r = orig(self, x); log[#log + 1] = "first-out"; return r + 100 end)
DanTraits_Wrap(B, "run", "second", function(orig, self, x) log[#log + 1] = "second-in"; local r = orig(self, x); log[#log + 1] = "second-out"; return r * 2 end)
log = {}
local r = B:run(1)
assert(table.concat(log, ",") == "second-in,first-in,base,first-out,second-out", "layer order: " .. table.concat(log, ","))
assert(r == (1 + 1 + 100) * 2, "results chain outward: got " .. tostring(r))

-- 3. the tag is per method: the same tag on another method is a separate wrap
local C = make(); C.other = function(self) return "orig" end
DanTraits_Wrap(C, "run", "shared", function(orig, self, x) return orig(self, x) end)
assert(DanTraits_Wrap(C, "other", "shared", function(orig, self) return "wrapped-" .. orig(self) end) == true and C:other() == "wrapped-orig", "same tag on a different method wraps")

-- 4. nothing to wrap: no class, no method, not a function
assert(DanTraits_Wrap(nil, "run", "x", function() end) == false, "no class")
assert(DanTraits_Wrap({}, "run", "x", function() end) == false, "no method")
assert(DanTraits_Wrap({ run = 5 }, "run", "x", function() end) == false, "method is not a function")

-- 5. a derived class does not inherit its parent's tags (the vanilla actions all derive from one base)
local Parent = make()
local Child = setmetatable({}, { __index = Parent })
DanTraits_Wrap(Parent, "run", "t", function(orig, self, x) return orig(self, x) + 1000 end)
assert(DanTraits_Wrap(Child, "run", "t", function(orig, self, x) return orig(self, x) + 5000 end) == true, "child wraps despite the parent's tag")
assert(Child:run(1) == 1 + 1 + 1000 + 5000, "child layer sits on the inherited parent method, got " .. tostring(Child:run(1)))
assert(Parent:run(1) == 1 + 1 + 1000, "parent untouched by the child's wrap")

-- 6. vanilla trait lookups are cached per game minute
do
  local walks = 0
  local p = H.player({ vanilla = { "base:smoker" } })
  local traits = p:getCharacterTraits()
  local realKnown = traits.getKnownTraits
  traits.getKnownTraits = function(...) walks = walks + 1; return realKnown(...) end
  p.getCharacterTraits = function() return traits end
  H.hours = 100
  for _ = 1, 10 do assert(DanTraits_HasVanillaTrait(p, "base:smoker") == true, "smoker seen") end
  assert(DanTraits_HasVanillaTrait(p, "base:asthmatic") == false, "an absent trait is absent")
  assert(walks == 1, "eleven lookups in one minute walk once, walked " .. walks)

  -- a trait added behind the mod's back is seen once the game minute moves on
  traits:add("base:asthmatic")
  assert(DanTraits_HasVanillaTrait(p, "base:asthmatic") == false, "still the snapshot within the minute")
  H.hours = 100 + 1 / 60 + 0.001
  assert(DanTraits_HasVanillaTrait(p, "base:asthmatic") == true, "seen the next minute")
  assert(walks == 2, "one more walk for the new minute, walked " .. walks)

  -- DanTraits_TraitsChanged forces a re-walk inside the same minute
  traits:remove("base:smoker")
  assert(DanTraits_HasVanillaTrait(p, "base:smoker") == true, "stale until told")
  DanTraits_TraitsChanged(p)
  assert(DanTraits_HasVanillaTrait(p, "base:smoker") == false, "TraitsChanged forces a re-walk")
  assert(walks == 3, "walked " .. walks)

  -- another player object gets its own walk; nil player is false
  local q = H.player({ vanilla = { "base:smoker" } })
  assert(DanTraits_HasVanillaTrait(q, "base:smoker") == true, "a different player is not answered from the cache")
  assert(DanTraits_HasVanillaTrait(nil, "base:smoker") == false, "no player")

  -- OnGameStart and OnCreatePlayer invalidate too
  DanTraits_HasVanillaTrait(p, "base:smoker")
  local before = walks
  traits:add("base:smoker")
  H.fire("OnGameStart")
  assert(DanTraits_HasVanillaTrait(p, "base:smoker") == true and walks == before + 1, "OnGameStart invalidates")
  traits:remove("base:smoker")
  H.fire("OnCreatePlayer", 0, p)
  assert(DanTraits_HasVanillaTrait(p, "base:smoker") == false, "OnCreatePlayer invalidates")
end

H.pass()
