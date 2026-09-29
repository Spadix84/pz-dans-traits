-- Offline test for DanTraits.lua's shared helpers. So far: DanTraits_Wrap, the
-- one way files wrap a game method. Wrapping twice with the same tag wraps
-- once; different tags each add a layer and all of them run, innermost first;
-- a class without the method is left alone; a derived class keeps its own
-- tags apart from its parent's.
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

H.pass()
