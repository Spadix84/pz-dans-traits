-- Offline test for DanTraits_Caffeine.lua: intake through the drink, eat
-- and pill hooks, the five-hour half-life, withdrawal timing and fade.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = { INTOXICATION = "intox", STRESS = "stress", PAIN = "pain", UNHAPPINESS = "unhappy", FATIGUE = "fatigue", THIRST = "thirst", FOOD_SICKNESS = "foodsick" }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = { caffeine = "caffeine" }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Caffeine" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.EveryOneMinute, "hooks in place")

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or { "caffeine" }) do traits[t] = true end
  local st = { stress = 0, pain = 0, unhappy = 0, fatigue = 0, thirst = 0, foodsick = 0, intox = 0 }
  local md = {}
  return { hasTrait = function(_, t) return traits[t] == true end, isDead = function() return false end,
    isAsleep = function(self) return self._asleep end, getModData = function() return md end,
    getStats = function() return { get = function(_, k) return st[k] end, set = function(_, k, v) st[k] = v end } end,
    getPainEffect = function(self) return self._meds or 0 end, getInventory = function() return { Remove = function() end } end,
    _st = st, _md = md, _asleep = false }
end
local function container(fluid, ratio)
  return { getPrimaryFluid = function() return { getFluidTypeString = function() return fluid end } end, getRatioForFluid = function() return ratio or 1 end }
end
local function food(name) return { getType = function() return name end } end
local current
function getSpecificPlayer() return current end
local minute = handlers.EveryOneMinute
local function C(p) return p._md.DanTraits end
local function near(a, b, eps, msg) assert(math.abs(a - b) <= eps, msg .. ": expected " .. b .. ", got " .. a) end

-- 1. a mug of coffee (0.25 L of the Coffee fluid) is 100; tea 37.5; a can of cola (0.3 L) 30; water nothing; a 50/50 mix half
local p = makePlayer(); current = p
DanTraits_RunHooks("drink", nil, p, container("Coffee"), 0.25); near(C(p).cafLevel, 100, 1e-9, "coffee")
DanTraits_RunHooks("drink", nil, p, container("Tea"), 0.25); near(C(p).cafLevel, 137.5, 1e-9, "tea")
DanTraits_RunHooks("drink", nil, p, container("Cola"), 0.3); near(C(p).cafLevel, 167.5, 1e-9, "cola")
DanTraits_RunHooks("drink", nil, p, container("Water"), 1.0); near(C(p).cafLevel, 167.5, 1e-9, "water: nothing")
DanTraits_RunHooks("drink", nil, p, container("Coffee", 0.5), 0.25); near(C(p).cafLevel, 217.5, 1e-9, "half coffee, half milk: half the dose")

-- 2. food and pills: coffee beans, chocolate of any kind, instant coffee by fraction, vitamins as caffeine pills; bread nothing
local f = makePlayer(); current = f
DanTraits_RunHooks("eat", nil, f, food("ChocolateCoveredCoffeeBeans"), 1); near(C(f).cafLevel, 300, 1e-9, "beans")
DanTraits_RunHooks("eat", nil, f, food("Chocolate_SnikSnak"), 1); near(C(f).cafLevel, 315, 1e-9, "a chocolate bar")
DanTraits_RunHooks("eat", nil, f, food("Coffee2"), 0.1); near(C(f).cafLevel, 375, 1e-9, "a tenth of a jar of instant coffee")
DanTraits_RunHooks("eat", nil, f, food("Bread"), 1); near(C(f).cafLevel, 375, 1e-9, "bread: nothing")
DanTraits_RunHooks("pill", nil, f, "PillsVitamins"); near(C(f).cafLevel, 575, 1e-9, "vitamins are caffeine pills")
DanTraits_RunHooks("pill", nil, f, "Pills"); near(C(f).cafLevel, 575, 1e-9, "painkillers are not")
local none = makePlayer({ traits = {} }); current = none
DanTraits_RunHooks("drink", nil, none, container("Coffee"), 0.25); assert(none._md.DanTraits == nil or not none._md.DanTraits.cafLevel, "no trait: nothing tracked")

-- 3. half-life: five hours takes 200 to 100
local h = makePlayer(); current = h
DanTraits_CaffeineDose(h, 200, "test")
for _ = 1, 300 do minute() end
near(C(h).cafLevel, 100, 0.01, "halved after five hours")
assert(C(h).cafDryHours == 0, "100 is still sated")
for _ = 1, 230 do minute() end   -- 200 x 0.5^(530/300) = 58.8
assert(C(h).cafLevel < 60 and C(h).cafDryHours > 0, "under 60 it counts as dry")

-- 4. withdrawal: nothing at 12 h dry, half at 21 h, full at 30 h, still full at 72 h, gone by 168 h
local w = DanTraits_CaffeineWithdrawal
assert(w(11.9) == 0 and w(30) == 1 and w(72) == 1 and w(168) == 0, "curve ends")
near(w(21), 0.5, 1e-9, "ramping up"); near(w(120), 0.5, 1e-9, "fading out")

-- 5. in play: the clock runs while under 60, the craving notice comes at 12 h, symptoms scale, a coffee ends it
local d = makePlayer(); current = d
for _ = 1, 12 * 60 + 1 do minute() end
assert(C(d).cafWithdrawing and halo[#halo] == "UI_DanTraits_CaffeineCraving", "craving at 12 h")
for _ = 1, 18 * 60 do minute() end
near(C(d).cafWithdraw, 1, 1e-6, "full at 30 h")
near(d._st.pain, 15, 1.0, "headache floor 15"); near(d._st.unhappy, 15, 1.0, "mood floor 15")
assert(d._st.fatigue > 0 and d._st.stress > 0, "tired and stressed")
d._st.pain = 0; d._meds = 1; minute(); assert(d._st.pain == 0, "painkillers hold the headache off"); d._meds = 0
d._asleep = true; d._st.pain = 0; minute(); assert(d._st.pain == 0, "nothing while asleep"); d._asleep = false
DanTraits_RunHooks("drink", nil, d, container("Coffee"), 0.25)
assert(not C(d).cafWithdrawing and C(d).cafDryHours == 0 and halo[#halo] == "+UI_DanTraits_CaffeineSated", "a coffee resets it")
DanTraits_RunHooks("eat", nil, d, food("Chocolate"), 1)   -- 15: too small to reset the clock
minute(); assert(C(d).cafDryHours == 0, "still sated from the coffee")

-- 6. a week dry breaks the habit: withdrawal fades to nothing and says so
local b = makePlayer(); current = b
for _ = 1, 168 * 60 + 1 do minute() end
assert(C(b).cafWithdraw == 0 and not C(b).cafWithdrawing and halo[#halo] == "+UI_DanTraits_CaffeineBroken", "habit broken after a week")

print("test_caffeine: all passed")
