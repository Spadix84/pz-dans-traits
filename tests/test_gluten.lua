
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
-- Offline test for DanTraits_Gluten.lua: what counts as wheat, the dose from
-- eating it (through the wrapped eat action, whole or interrupted), the onset
-- and ramp, the symptom floors, decay and a second meal during a flare.
H.events()
H.stubs()

-- vanilla eat action stub
local eaten = {}
ISEatFoodAction = { complete = function(self) eaten[#eaten+1] = { "complete", self.item.name }; return true end,
                    eat = function(self, food, pct) eaten[#eaten+1] = { "eat", self.item.name, pct } end }

H.load("Dependent", "MDD", "Brittle", "Arthritis", "Jinxed", "BadDay", "Hallucinations", "Asthma", "Gluten", "Vegetarian", "Diabetes")
H.expectEvery("minute", "Gluten")
assert(ISEatFoodAction.DanTraitsWraps and ISEatFoodAction.DanTraitsWraps["complete:core-eat"], "hooks in place")

local function item(name, carbs, hunger)
  return { name = name, getType = function() return name end, getCarbohydrates = function() return carbs end, getHungChange = function() return hunger or -0.1 end }
end
local build = H.factory()
local function newPlayer(hasGluten, asleep) return build({ traits = hasGluten and { "gluten" } or {}, asleep = asleep }) end
local halo = H.halo
local minute = H.minute

-- 1. what counts as wheat
local yes = { "Bread", "BreadSlices", "BagelPlain", "PastaBowl", "Ramen", "NoodleSoup", "Cereal", "Crackers", "CookiesOatmeal", "PieApple", "PizzaWhole", "Sandwich", "Burger", "BeerBottle", "Gingerbreadman", "MeatSteamBun", "BunsHamburger", "Tortilla", "Cornbread", "PotatoPancakes" }
local no  = { "Rice", "Potato", "Corn", "Apple", "Steak", "WhiteCrappie", "Poppies", "GamePieceRed", "TortillaChips", "Oatmeal", "OatsRaw", "GranolaBar", "Cornflour2", "RiceCake" }
for _, n in ipairs(yes) do assert(DanTraits_IsWheat(item(n, 10)), n .. " should be wheat") end
for _, n in ipairs(no) do assert(not DanTraits_IsWheat(item(n, 10)), n .. " should be safe") end
print("wheat list: " .. #yes .. " wheat, " .. #no .. " safe")

-- 2. eating: only the trait, only wheat, dose from carbs, fallback from hunger
local p = newPlayer(true); H.current = p
local plain = newPlayer(false)
assert(not DanTraits_OnEat(plain, item("Bread", 99), 1) and plain._md.DanTraits == nil, "no trait: nothing")
assert(not DanTraits_OnEat(p, item("Rice", 648), 1), "rice: nothing")
assert(DanTraits_OnEat(p, item("Bread", 99), 1), "bread: dose")
assert(math.abs(p._md.DanTraits.glutenPending - 1.98) < 1e-9 and p._md.DanTraits.glutenOnset == 20, "loaf = 1.98 doses, 20 min onset")
assert(halo[#halo] == "UI_DanTraits_GlutenAte", "told what happened")
local q = newPlayer(true); H.current = q
assert(DanTraits_OnEat(q, item("BeerBottle", 0, -0.1), 1) and math.abs(q._md.DanTraits.glutenPending - 0.6) < 1e-9, "no nutrition data: 10 hunger x 3 = 30 carbs = 0.6")

-- 3. the action wrapper: complete uses the action percentage; eat uses percentage x progress
local act = setmetatable({ character = q, item = item("BreadSlices", 33), percentage = 0.5 }, { __index = ISEatFoodAction })
q._md.DanTraits.glutenPending = 0
act:complete(); assert(math.abs(q._md.DanTraits.glutenPending - 0.33) < 1e-9 and eaten[#eaten][1] == "complete", "complete: half a slice = 16.5 carbs")
q._md.DanTraits.glutenPending = 0
act:eat(act.item, 0.5); assert(math.abs(q._md.DanTraits.glutenPending - 0.165) < 1e-9 and eaten[#eaten][3] == 0.5, "interrupted: 0.5 x 0.5 of a slice")
q._md.DanTraits.glutenPending = 0
act:eat(act.item, 0.97); assert(math.abs(q._md.DanTraits.glutenPending - 0.33) < 1e-9, "over 95% counts as all")

-- 4. onset, ramp, tiers: nothing for 20 minutes, then a full flare 30 minutes later
H.current = p; H.clearHalo()
for _ = 1, 20 do minute() end
assert(p._md.DanTraits.gluten == 0 and p._st.pain == 0, "quiet during onset")
minute(); assert(math.abs(p._md.DanTraits.gluten - 1/30) < 1e-9, "ramp starts")
for _ = 1, 29 do minute() end
assert(p._md.DanTraits.gluten == 1, "full flare after 30 min of ramp")
assert(halo[1] == "UI_DanTraits_GlutenTier1" and halo[2] == "UI_DanTraits_GlutenTier2" and halo[3] == "UI_DanTraits_GlutenTier3", "tier notices in order")

-- 5. symptoms held up to floors that scale with the flare; painkillers only buy time
assert(p._st.pain == 45 and p._st.foodsick == 55 and p._st.unhappy == 25 and p._st.stress > 0, string.format("floors: pain %s sick %s unhappy %s stress %s", p._st.pain, p._st.foodsick, p._st.unhappy, p._st.stress))
p._st.pain = 0; minute(); assert(p._st.pain == 3, "pain climbs back 3 per minute after painkillers")
p._st.pain = 80; minute(); assert(p._st.pain == 80, "a higher pain from a wound is left alone")

-- 6. decay once the dose is spent: ten hours awake, faster asleep
while p._md.DanTraits.glutenPending > 0 do minute() end
local f0 = p._md.DanTraits.gluten
minute(); assert(math.abs((f0 - p._md.DanTraits.gluten) - 1/600) < 1e-9, "decays 1/600 per minute")
local sl = newPlayer(true, true); H.current = sl; sl._md.DanTraits = { gluten = 0.5, glutenPending = 0 }
minute(); assert(math.abs((0.5 - sl._md.DanTraits.gluten) - 1.5/600) < 1e-9, "asleep decays 1.5x")

-- 7. a second meal during a flare stacks straight in, no new onset wait
H.current = p; local g = p._md.DanTraits.gluten
DanTraits_OnEat(p, item("Crackers", 12), 1)
assert(p._md.DanTraits.glutenOnset == 0 or p._md.DanTraits.glutenOnset == nil or p._md.DanTraits.glutenOnset <= 0, "no fresh onset mid-flare")
minute(); assert(p._md.DanTraits.gluten > g, "stacks")
H.pass()
