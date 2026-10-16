-- Offline test for the drink wrap as its readers see it: Diabetes wraps
-- ISDrinkFluidAction.updateEat and vanilla calls it on every tick of the action
-- (jobDelta) and once more from complete() (delta 1). Caffeine and Lactose read
-- the "drink" hook, Delicate Stomach (DanTraits_AgeTraits.lua) the "alcoholDrunk"
-- hook; each must see one drink with the whole amount, not one sip per tick
-- (review 2026-10-16 A1.1: all three were dosed per tick). The readers are the
-- real files here, co-loaded with the wrap; test_diabetes.lua pins the wrap's own
-- shape with stand-in hooks.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }
-- what AgeTraits touches at load
CharacterProfessionDefinition = { getCharacterProfessionDefinition = function() return { getXpBoosts = function() return nil end } end }
function transformIntoKahluaTable(t) return t end
ISReadABook = { getDuration = function() return 400 end, isValid = function() return true end }
MoodleType.HEAVY_LOAD = "heavy"
ClimbOverFenceState = { instance = function() return {} end }
ClimbThroughWindowState = { instance = function() return {} end }
BodyPartType.Torso_Lower = "Torso_Lower"
BodyPartType.getDisplayName = function(kind) return kind end
-- vanilla's drink action: a sip takes `sip` litres, never below empty
ISDrinkFluidAction = { updateEat = function(self)
  self.fluidContainer._amount = math.max(0, self.fluidContainer._amount - (self.sip or 0))
end }

H.load("Age", "AgeTraits", "Caffeine", "Lactose", "Diabetes")
assert(ISDrinkFluidAction.DanTraitsWraps and ISDrinkFluidAction.DanTraitsWraps["updateEat:drink-intake"], "the wrap is on")

-- count how often each registered reader is called (the hooks run through
-- DanTraits_Hooks, so wrapping the entries counts the real functions)
local calls = { drink = 0, alcoholDrunk = 0 }
local readers = { drink = #DanTraits_Hooks.drink, alcoholDrunk = #DanTraits_Hooks.alcoholDrunk }
assert(readers.drink == 2 and readers.alcoholDrunk == 1, "Caffeine and Lactose on drink, Delicate Stomach on alcoholDrunk: got " .. readers.drink .. "/" .. readers.alcoholDrunk)
for name, list in pairs({ drink = DanTraits_Hooks.drink, alcoholDrunk = DanTraits_Hooks.alcoholDrunk }) do
  for i, fn in ipairs(list) do
    list[i] = function(...) calls[name] = calls[name] + 1; return fn(...) end
  end
end

-- a fluid container: `fluid` names what is in it (the game's type string), `alcohol` > 0 makes it a drink
local function container(fluid, litres, alcohol)
  return { _amount = litres,
    getAmount = function(self) return self._amount end,
    getProperties = function() return { getCarbohydrates = function() return 0 end, getCalories = function() return 0 end,
                                        getAlcohol = function() return alcohol or 0 end } end,
    getPrimaryFluid = function(self) if self._amount > 0 then return { getFluidTypeString = function() return fluid end } end end,
    getRatioForFluid = function() return 1 end }
end
-- ten ticks of the action, then complete(): the shape vanilla drives the wrap in
local function drink(player, can)
  local act = setmetatable({ character = player, fluidContainer = can, sip = can._amount / 10 }, { __index = ISDrinkFluidAction })
  for _ = 1, 10 do act:updateEat(0.1) end
  act:updateEat(1)
  return act
end

local p = H.player({ traits = { "caffeine", "lactose", "delicatestomach" }, hunger = 0.8 })
H.current = p
local d = DanTraits_Data(p)

-- 1. a mug of coffee (400 mg a litre, 0.3 l): one dose of 120, which counts as a
--    full dose (40 or more resets the dry clock); ten doses of 12 would only have
--    taken 2.4 dry hours off each
d.cafLevel, d.cafDryHours = 0, 30
local coffee = drink(p, container("Coffee", 0.3))
assert(calls.drink == 2, "the drink hook ran once per reader, got " .. calls.drink)
H.near(d.cafLevel, 120, 1e-9, "Caffeine: the whole mug")
H.near(d.cafDryHours, 0, 1e-9, "Caffeine: one dose of 120 is a full dose, the clock resets")
assert(rawget(coffee, "danDrink") == nil, "the running total is cleared")
assert((d.lacPending or 0) == 0 and calls.alcoholDrunk == 0, "coffee is not dairy and not alcohol")

-- 2. a glass of milk (0.3 l, a full flare's worth): one dose of 1 for Lactose,
--    one notice; Caffeine is asked and says nothing
H.clearHalo()
drink(p, container("Milk", 0.3))
assert(calls.drink == 4, "both readers once more, got " .. calls.drink)
H.near(d.lacPending, 1, 1e-9, "Lactose: the whole glass as one dose")
assert(d.lacOnset == 30, "the onset clock started once")
local notices = 0
for _, t in ipairs(H.halo) do if t == "UI_DanTraits_LactoseAte" then notices = notices + 1 end end
assert(notices == 1, "one notice for one glass, got " .. notices)
H.near(d.cafLevel, 120, 1e-9, "Caffeine: milk adds nothing")

-- 3. a bottle of beer (0.33 l, alcoholic) on a mostly empty stomach: Delicate
--    Stomach once, with the whole bottle (10 food sickness for 0.33 l)
p._st.foodsick = 0
drink(p, container("Beer", 0.33, 0.05))
assert(calls.alcoholDrunk == 1, "alcoholDrunk once, got " .. calls.alcoholDrunk)
assert(calls.drink == 6, "the drink hook still runs for an alcoholic drink")
H.near(p._st.foodsick, 10, 1e-9, "Delicate Stomach: the whole bottle, once")
-- a smaller bottle pro rata, and a full stomach is spared
drink(p, container("Beer", 0.11, 0.05))
H.near(p._st.foodsick, 10 + 10 / 3, 1e-9, "a third of a bottle: a third of the sickness")
p._st.hunger = 0.2
drink(p, container("Beer", 0.33, 0.05))
H.near(p._st.foodsick, 10 + 10 / 3, 1e-9, "fed: nothing")
assert(calls.alcoholDrunk == 3, "the reader was still asked each time")

-- 4. without the traits the readers are called and do nothing
local plain = H.player({ hunger = 0.8 }); H.current = plain
drink(plain, container("Coffee", 0.3))
drink(plain, container("Beer", 0.33, 0.05))
assert(plain._st.foodsick == 0 and (plain._md.DanTraits == nil or (plain._md.DanTraits.cafLevel == nil and plain._md.DanTraits.lacPending == nil)), "no trait: nothing recorded")

H.pass()
