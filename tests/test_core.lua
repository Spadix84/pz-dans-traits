-- Offline test for DanTraits.lua's shared helpers. So far: DanTraits_Wrap, the
-- one way files wrap a game method. Wrapping twice with the same tag wraps
-- once; different tags each add a layer and all of them run, innermost first;
-- a class without the method is left alone; a derived class keeps its own
-- tags apart from its parent's. And DanTraits_HasVanillaTrait's cache: one walk
-- of getKnownTraits per game minute, a re-walk after DanTraits_TraitsChanged,
-- OnGameStart or OnCreatePlayer, and a separate answer per player object.
-- And DanTraits_RetireTraits: retired traits swapped out of a loaded character.
-- And DanTraits_Guard: a hook that throws is logged once per tag and leaves the
-- value alone; under DanTraits_STRICT (the tests) it raises instead.
-- And DanTraits_SetTrait: a mod key or "base:CONST", added or taken off once,
-- the vanilla cache refreshed, false for a reference that names nothing.
-- And DanTraits_StartingKit: the spec a file registers for what a new
-- character with its trait begins with, run once by core's create handler.
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

-- 7. mod-data renames: old keys move to their prefixed names once, on OnCreatePlayer / OnGameStart;
-- a new key that already exists wins and the old one is still cleared; retired keys are dropped;
-- a second run finds nothing
do
  local p = H.player()
  p._md.DanTraits = { withdrawing = true, dryHours = 12, depTolerance = 0.4, earlyRiserApplied = true,
    mealPrepperApplied = true, gymRegularApplied = true, deepSleeperWakeful = true, alcMeter = 0.9, vitDiet = 0.5,
    hcCovered = true, epCovered = true, vitCarryDelta = 1 }
  H.current = p
  H.fire("OnGameStart")
  local d = p._md.DanTraits
  assert(d.alcWithdrawing == true and d.alcDryHours == 12, "withdrawing and dryHours moved")
  assert(d.alcMeter == 0.9, "an existing new key is not clobbered by the old one")
  assert(d.posEarlyRiser == true and d.posMealPrepper == true and d.gymApplied == true and d.slWakefulGranted == true, "the applied flags moved")
  assert(d.withdrawing == nil and d.dryHours == nil and d.depTolerance == nil and d.earlyRiserApplied == nil
    and d.mealPrepperApplied == nil and d.gymRegularApplied == nil and d.deepSleeperWakeful == nil, "old keys cleared")
  assert(d.vitDiet == 0.5, "other keys untouched")
  assert(d.hcCovered == nil and d.epCovered == nil and d.vitCarryDelta == nil, "retired keys dropped")
  assert(DanTraits_MigrateModData(p) == 0, "second run: nothing left to do")

  -- OnCreatePlayer migrates too (before the trait files' starts read the new names)
  local q = H.player()
  q._md.DanTraits = { depTolerance = 0.25, gymRegularApplied = false }
  H.fire("OnCreatePlayer", 0, q)
  assert(q._md.DanTraits.alcMeter == 0.25 and q._md.DanTraits.gymApplied == false and q._md.DanTraits.depTolerance == nil, "OnCreatePlayer migrates, false values included")
end

-- retired traits (2026-10-07): taken off a loaded character, and the one that took its place given
do
  local r = H.player({ traits = { "jinxed", "ironstomach", "bouncesback", "brittle" } })
  assert(DanTraits_RetireTraits(r) == 3, "three retired traits found")
  local t = r._traits
  assert(not t.jinxed and not t.ironstomach and not t.bouncesback, "all three taken off")
  assert(t["base:irongut"] and t.thickskull and t.brittle, "Iron Gut and Thick Skull in their place; others untouched")
  assert(DanTraits_RetireTraits(r) == 0, "nothing the second time")
  local both = H.player({ traits = { "bouncesback", "thickskull" } })
  H.fire("OnCreatePlayer", 0, both)
  assert(not both._traits.bouncesback and both._traits.thickskull, "already has the replacement: just the old one off")
  assert(DanTraits_RetireTraits(nil) == 0, "no player")
end

-- 8b. DanTraits_SetTrait: the one runtime add / remove
do
  local p = H.player({ vanilla = { "base:smoker" } })
  H.current = p
  assert(DanTraits_SetTrait(p, "caffeine", true) == true and p._traits.caffeine and p._adds == 1, "a mod key is added")
  assert(DanTraits_SetTrait(p, "caffeine", true) == true and p._adds == 1, "already there: left alone, still true")
  assert(DanTraits_SetTrait(p, "caffeine", false) == true and not p._traits.caffeine, "taken off")
  assert(DanTraits_SetTrait(p, "caffeine", false) == true and p._adds == 1, "already gone: left alone")
  assert(DanTraits_HasVanillaTrait(p, "base:smoker") == true, "the cache sees the smoker")
  assert(DanTraits_SetTrait(p, "base:SMOKER", false) == true and not p._traits["base:smoker"], "a vanilla constant by base:NAME")
  assert(DanTraits_HasVanillaTrait(p, "base:smoker") == false, "and the vanilla cache was refreshed")
  assert(DanTraits_SetTrait(p, "base:NO_SUCH_TRAIT", true) == false and DanTraits_SetTrait(p, nil, true) == false, "nothing to name: false")
  assert(DanTraits_SetTrait(nil, "caffeine", true) == false, "no player: false")
  local stubborn = H.player()
  stubborn.getCharacterTraits = function() error("no traits") end
  assert(DanTraits_SetTrait(stubborn, "caffeine", true) == false, "a failing game call: false, no error")
end

-- 8c. DanTraits_StartingKit: trait (a key or a test), the once flag, the hours gate, meds, always
-- versus the Starting Medication items, prepare on each item, in registration order
do
  local started = {}
  DanTraits_MedStart = function(player, id) started[#started + 1] = id end
  local prepared = 0
  DanTraits_StartingKit({ trait = "heart", flag = "kitA", meds = { "beta" }, always = { "Base.Meter" },
    items = function(player) return { "Base.PillsBeta", "Base.PillsBeta" } end,
    prepare = function(item) prepared = prepared + 1; item._kit = true end })
  DanTraits_StartingKit({ trait = function(player) return player._special == true end, flag = "kitB",
    setup = function(player, d) d.kitBSetup = true end, items = { "Base.Special" } })
  local function types(p) local t = {} for _, it in ipairs(p._inv) do t[#t + 1] = it:getFullType() end return table.concat(t, ",") end
  local p = H.player({ traits = { "heart" }, hours = 0 })
  H.fire("OnCreatePlayer", 0, p)
  assert(types(p) == "Base.Meter,Base.PillsBeta,Base.PillsBeta" and p._md.DanTraits.kitA == true, "the kit: " .. types(p))
  assert(table.concat(started, ",") == "beta" and prepared == 3 and p._inv[1]._kit, "built up on the drug, every item prepared")
  assert(p._md.DanTraits.kitB == nil, "another trait's kit: not this character's")
  H.fire("OnCreatePlayer", 0, p)
  assert(#p._inv == 3 and #started == 1, "once")
  local old = H.player({ traits = { "heart" }, hours = 3 })
  H.fire("OnCreatePlayer", 0, old)
  assert(#old._inv == 0 and (old._md.DanTraits == nil or old._md.DanTraits.kitA == nil), "an old save: nothing, and not marked")
  SandboxVars = { DanTraits = { StartingMedication = false } }
  local bare = H.player({ traits = { "heart" }, hours = 0 })
  H.fire("OnCreatePlayer", 0, bare)
  assert(types(bare) == "Base.Meter" and bare._md.DanTraits.kitA == true and #started == 2, "option off: only what is always given, still built up, still marked")
  SandboxVars = nil
  local sp = H.player({ hours = 0 }); sp._special = true
  H.fire("OnCreatePlayer", 0, sp)
  assert(types(sp) == "Base.Special" and sp._md.DanTraits.kitBSetup == true and sp._md.DanTraits.kitB == true, "a tested trait, setup first")
  assert(DanTraits_GiveStartingKit(H.player({ hours = 0 }), { trait = "heart" }) == false, "no trait: false")
  DanTraits_MedStart = nil
end

-- 9. DanTraits_Guard: in the game a throwing hook is logged once per tag, then quiet, and the
-- value hooks around it still run; a second broken hook under the same name is its own tag.
-- The tests run with DanTraits_STRICT, where the same error raises out of RunHooks.
do
  local lines = {}
  local realPrint = print
  print = function(...) lines[#lines + 1] = table.concat({ ... }, " ") end
  DanTraits_STRICT = false
  DanTraits_AddHook("guardTest", function(v) error("boom") end)
  DanTraits_AddHook("guardTest", function(v) return v + 1 end)
  assert(DanTraits_RunHooks("guardTest", 1) == 2, "the throwing hook leaves the value alone, the next still adjusts it")
  assert(#lines == 1 and lines[1]:find("hook:guardTest#1", 1, true) and lines[1]:find("boom"), "logged once, by tag: " .. table.concat(lines, "|"))
  DanTraits_RunHooks("guardTest", 1); DanTraits_RunHooks("guardTest", 1)
  assert(#lines == 1, "and not again")
  DanTraits_AddHook("guardTest", function(v) error("bang") end)
  assert(DanTraits_RunHooks("guardTest", 1) == 2 and #lines == 2 and lines[2]:find("hook:guardTest#3", 1, true), "another broken hook is another tag, logged once too")
  -- a Later job the same way, named by its tag
  DanTraits_Later(1, function() error("late boom") end, "test-later")
  H.fire("OnTick")
  assert(#lines == 3 and lines[3]:find("test-later failed", 1, true) and lines[3]:find("late boom"), "a Later job that throws is logged once by its tag: " .. tostring(lines[3]))
  DanTraits_STRICT = true
  local ok, err = pcall(DanTraits_RunHooks, "guardTest", 1)
  assert(not ok and tostring(err):find("hook:guardTest#1 failed", 1, true) and tostring(err):find("boom"), "STRICT (the tests): it raises instead: " .. tostring(err))
  assert(#lines == 3, "STRICT: already logged, so no new line")
  print = realPrint
  DanTraits_Hooks.guardTest = nil
  -- the guard itself: pcall's shape, so callers can read the result
  local okG, res = DanTraits_Guard("test-guard", function(a, b) return a + b end, 2, 3)
  assert(okG == true and res == 5, "a call that works returns ok and its result")
end

H.pass()
