-- Offline test for the Diabetes traits (run with fengari; stubs stand in for the game).
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
BodyPartType = { Groin = "Groin", ForeArm_L=1, ForeArm_R=2, LowerLeg_L=3, LowerLeg_R=4, Hand_L=5, Hand_R=6, Torso_Upper=7 }
CharacterStat = { INTOXICATION = "intox", STRESS = "stress", PAIN = "pain", UNHAPPINESS = "unhappy", FATIGUE = "fatigue", PANIC = "panic", ENDURANCE = "endurance", FOOD_SICKNESS = "foodsick", THIRST = "thirst", WETNESS = { getMaximumValue = function() return 100 end } }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k, a) if a then return k .. ":" .. tostring(a) end return k end
DanTraitsRegistry = { diabetes1 = "diabetes1", diabetes2 = "diabetes2", arthritis = "arthritis", asthma = "asthma", spiraling = "spiraling", gluten = "gluten", vegetarian = "vegetarian" }
ArrayList = { new = function() return { add = function() end } end }
IsoFireManager = { explode = function() end }
function instanceof() return false end
ItemBodyLocation = { MASK = "mask", MASK_EYES = "maskeyes", MASK_FULL = "maskfull" }
function getWorld() return { getFreeEmitter = function() return { playSound = function() return 1 end, setPos = function() end } end } end
function getTexture() return "TEX" end
function getGameTime() return { getHour = function() return 12 end } end
local rng = {}
function ZombRand(a, b) local v = table.remove(rng, 1); if v == nil then v = 0 end; return v end
function getClimateManager() return { getAirTemperatureForCharacter = function() return 20 end } end
function getCell() return { getGridSquare = function() return { getObjects = function() return { size = function() return 0 end } end, getDeadBodys = function() return { size = function() return 0 end } end } end } end
function addSound() end
function isNight() return false end
DanTraitsTestCharge = false
FitnessExercises = { exercisesType = { squats = {}, pushups = {}, situps = {}, burpees = {} } }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
-- vanilla drink action stub: drinking removes `sip` litres from the container
ISDrinkFluidAction = { updateEat = function(self, delta) self.fluidContainer._amount = self.fluidContainer._amount - self.sip end }
DanTraitsTestEpisode = false

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Dependent", "DanTraits_MDD", "DanTraits_Brittle", "DanTraits_Arthritis", "DanTraits_Jinxed", "DanTraits_BadDay", "DanTraits_Hallucinations", "DanTraits_Asthma", "DanTraits_Gluten", "DanTraits_Vegetarian", "DanTraits_Diabetes", "DanTraits_Alcohol" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.EveryOneMinute and handlers.OnCreatePlayer, "hooks in place")
local drinkWraps = ISDrinkFluidAction.DanTraitsWraps
assert(drinkWraps and drinkWraps["updateEat:drink-intake"] and drinkWraps["updateEat:alcohol-relief"], "both drink layers installed (Diabetes and Alcohol share updateEat)")

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or { "diabetes1" }) do traits[t] = true end
  local st = { pain = 0, stress = 0, unhappy = 0, fatigue = 0, intox = o.intox or 0, panic = o.panic or 0, endurance = o.endurance or 1, foodsick = 0, thirst = 0 }
  local md, added, dropped = {}, {}, {}
  local p = { hasTrait = function(_, t) return traits[t] == true end, isDead = function() return false end,
    isAsleep = function() return o.asleep == true end, isSprinting = function() return o.running == true end, isRunning = function() return false end,
    getModData = function() return md end,
    getStats = function() return { get = function(_, k) return st[k] end, set = function(_, k, v) st[k] = v end } end,
    isOutside = function() return false end, getTimeSinceLastSmoke = function() return 10 end,
    getFitness = function() return { getRegularity = function(_, name) return (o.regularity or {})[name] or 0 end } end,
    getNutrition = function() return { getWeight = function() return o.weight or 80 end } end,
    getDepressEffect = function() return 0 end, setDepressEffect = function() end,
    getHoursSurvived = function() return 0 end,
    getInventory = function() return { AddItem = function(_, name) added[#added+1] = name end, Remove = function() end, contains = function() return true end } end,
    getPrimaryHandItem = function() return { name = "bat" } end, getCurrentSquare = function() return { AddWorldInventoryItem = function(_, it) dropped[#dropped+1] = it end } end,
    removeFromHands = function() end,
    _st = st, _md = md, _added = added, _dropped = dropped, _health = o.health or 100 }
  p.getBodyDamage = function() return { getOverallBodyHealth = function() return p._health end, ReduceGeneralHealth = function(_, n) p._health = p._health - n end } end
  return p
end
local current
function getSpecificPlayer() return current end
local minute = handlers.EveryOneMinute
local function item(name, carbs) return { getType = function() return name end, getCarbohydrates = function() return carbs end, getHungChange = function() return -0.1 end, getUnhappyChange = function() return 0 end } end
local function near(a, b, tol, what) assert(math.abs(a - b) <= tol, what .. ": expected " .. b .. " +/- " .. tol .. ", got " .. a) end
local function g(p) return p._md.DanTraits.glucose end

-- 1. what counts as a fast carb
for _, n in ipairs({ "Chocolate", "CandyPackage", "Lollipop", "Sugar", "Honey", "JamStrawberry", "Apple", "Banana", "IcecreamConeChoc", "CakeSlice", "Cereal", "Milk" }) do assert(DanTraits_IsFastCarb(item(n, 10)), n .. " should be fast") end
for _, n in ipairs({ "Bread", "Rice", "Potato", "PastaBowl", "Corn", "Popcorn", "Steak", "Crackers" }) do assert(not DanTraits_IsFastCarb(item(n, 10)), n .. " should be slow") end

-- 2. no trait: nothing is tracked, no shakiness
local plain = makePlayer({ traits = {} }); current = plain
assert(not DanTraits_DiaOnEat(plain, item("Bread", 99), 1) and plain._md.DanTraits == nil, "no trait: nothing")
minute(); assert(plain._md.DanTraits == nil or plain._md.DanTraits.glucose == nil, "no trait: no glucose model")
assert(DanTraits_ExtraFumble(plain) == 0 and DanTraits_SwingDropChance(plain) == 0, "no trait: no shakiness")

-- 3. Type 1 with nothing on board creeps up about 10 an hour
local t1 = makePlayer(); current = t1
for _ = 1, 60 do minute() end
near(g(t1), 110 + 0.17 * 60, 0.01, "T1 drift over an hour")

-- 4. a loaf of bread (99 slow carbs) is worth about 400 with no insulin (minus what the kidneys dump above 180)
local loaf = makePlayer(); current = loaf
assert(DanTraits_DiaOnEat(loaf, item("Bread", 99), 1) and loaf._md.DanTraits.diaSlow == 99 and loaf._md.DanTraits.diaFast == 0, "bread queued as slow")
for _ = 1, 30 do minute() end
local half = g(loaf)
for _ = 1, 210 do minute() end
assert(half > 200 and half < 320, "half an hour in: partway up, got " .. half)
assert(g(loaf) > 350 and g(loaf) < 470, "four hours in: high, got " .. g(loaf))
assert(DanTraits_DiaTier(g(loaf)) == 0 and select(2, DanTraits_DiaTier(g(loaf))) == 3, "top high tier")

-- 5. a candy bar hits fast: most of it inside half an hour; eating a quarter counts a quarter
local candy = makePlayer(); current = candy
assert(DanTraits_DiaOnEat(candy, item("Chocolate", 110), 0.25) and math.abs(candy._md.DanTraits.diaFast - 27.5) < 1e-9, "a quarter of the bar")
for _ = 1, 30 do minute() end
assert(candy._md.DanTraits.diaFast < 27.5 * 0.15, "most of the fast carbs absorbed in 30 min, left " .. candy._md.DanTraits.diaFast)
assert(g(candy) > 110 + 27.5 * 4 * 0.8, "and turned into sugar, got " .. g(candy))

-- 6. one dose: nothing for 15 minutes, then about 50 in total over four hours
local shot = makePlayer(); current = shot
assert(DanTraits_DiaInject(shot, 1) == 1 and #shot._md.DanTraits.diaInsulin == 1, "dose recorded")
for _ = 1, 15 do minute() end
near(g(shot), 110 + 0.17 * 15, 0.01, "no effect during onset")
for _ = 1, 225 do minute() end
near(g(shot), 110 + 0.17 * 240 - 50, 1.5, "one dose = about 50 by the time it is spent")
assert(#shot._md.DanTraits.diaInsulin == 0, "spent dose removed")
assert(DanTraits_DiaInject(shot, 0) == 0 and DanTraits_DiaInject(plain, 3) == 0, "zero doses / not diabetic: nothing")

-- 7. too much insulin sends you low; low tiers: shakiness, panic, endurance, mood, then health to a floor of 15
local low = makePlayer({ traits = { "diabetes1" } }); current = low
low._md.DanTraits = { glucose = 60 }; minute()
assert(DanTraits_ExtraFumble(low) == 4 and DanTraits_SwingDropChance(low) == 4, "under 70: +4% on every swing without Fumbler")
assert(low._st.panic == 1 and low._st.endurance == 1, "tier 1: panic only")
local low2 = makePlayer({ traits = { "diabetes1", "arthritis" } }); current = low2
low2._md.DanTraits = { glucose = 50 }; minute()
assert(DanTraits_ExtraFumble(low2) == 8 and math.abs(DanTraits_SwingDropChance(low2) - (1 + 8 + 2 / 100 * 6 + 0.003 * 5)) < 1e-9, "under 55 with Fumbler: 1 + 8 + panic and fatigue terms, got " .. DanTraits_SwingDropChance(low2))
assert(math.abs(low2._st.endurance - 0.97) < 1e-9 and low2._st.unhappy == 2, "tier 2: endurance drains, mood ramps toward 25")
local low3 = makePlayer({ health = 30 }); current = low3
low3._md.DanTraits = { glucose = 30 }
for _ = 1, 40 do minute() end
assert(low3._health == 15, "tier 3: health drains to the 15% floor, got " .. low3._health)
assert(DanTraits_ExtraFumble(low3) == 14, "tier 3: +14%")
-- a weapon swing rolls the shakiness even without Fumbler
rng = { 0 }; handlers.OnWeaponSwing(low3, { name = "bat" })
assert(#low3._dropped == 1 and halo[#halo] == "UI_DanTraits_FumblerDrop", "shaky hands drop the weapon")

-- 8. high tiers: thirst, tiredness, then queasy and low, then health to the floor
local hi = makePlayer({ health = 30 }); current = hi
hi._md.DanTraits = { glucose = 300 }; minute()
near(hi._st.thirst, 0.004, 1e-9, "over 250: thirst per minute"); assert(hi._st.foodsick == 2 and hi._st.unhappy == 2, "over 250: queasy and low ramp in")
local hiMdd = makePlayer({ traits = { "diabetes1", "spiraling" } }); current = hiMdd
hiMdd._md.DanTraits = { glucose = 300, mddEpisode = true, mddSinceEnd = 0 }
for _ = 1, 30 do minute() end
assert(hiMdd._st.unhappy >= 22.5, "in a depressive episode the mood floor is x1.5 (22.5), got " .. hiMdd._st.unhappy)
local hi3 = makePlayer({ health = 30 }); current = hi3
hi3._md.DanTraits = { glucose = 500 }
for _ = 1, 60 do minute() end
assert(hi3._health == 15, "over 350: health drains to the floor, got " .. hi3._health)
assert(hi3._st.foodsick > 40, "over 350: nauseous")
-- a day above 350 and the floor is gone
hi3._md.DanTraits.diaKetoHours = 24; hi3._md.DanTraits.glucose = 500
for _ = 1, 10 do minute() end
assert(hi3._health < 15 and hi3._health > 11, "after a day of ketoacidosis health keeps falling, got " .. hi3._health)

-- 9. the messages are vague, spaced out, and hidden while drunk
halo = {}
local sym = makePlayer(); current = sym
sym._md.DanTraits = { glucose = 60 }
for _ = 1, 9 do minute() end
assert(#halo == 0, "no message for the first ten minutes")
minute(); assert(#halo == 1 and halo[1] == "UI_DanTraits_DiaLow1", "then a vague one, got " .. tostring(halo[1]))
halo = {}
local drunk = makePlayer({ intox = 1 }); current = drunk
drunk._md.DanTraits = { glucose = 60 }
for _ = 1, 30 do minute() end
assert(#halo == 0, "drunk: no warning signs")
halo = {}
local worst = makePlayer(); current = worst
worst._md.DanTraits = { glucose = 30 }
rng = { 0, 0, 6 }   -- rolls: first timer, timer reset, then pick message 7
for _ = 1, 3 do minute() end
assert(halo[#halo] == "UI_DanTraits_DiaLow7", "at the worst tier the giveaway message is possible, got " .. tostring(halo[#halo]))

-- 10. alcohol pulls sugar down; panic pushes it up; running pulls it down
local booze = makePlayer({ intox = 1 }); current = booze; minute()
near(g(booze), 110 + 0.17 - 0.35, 1e-9, "drunk: -0.35 a minute")
local scared = makePlayer({ panic = 100 }); current = scared; minute()
near(g(scared), 110 + 0.17 + 0.15, 1e-9, "full panic: +0.15 a minute")
local jittery = makePlayer({ panic = 30 }); current = jittery; minute()
near(g(jittery), 110 + 0.17, 1e-9, "panic 30 or under: nothing")
local half = makePlayer({ panic = 65 }); current = half; minute()
near(g(half), 110 + 0.17 + 0.075, 1e-9, "panic 65: halfway between the minimum and full")
local runner = makePlayer({ running = true }); current = runner; minute()
near(g(runner), 110 + 0.17 - 0.5, 1e-9, "running: -0.5 a minute")

-- 11. Type 2: resistance from weight, eased by exercise and metformin; the body pulls sugar back to a setpoint
local heavy = makePlayer({ traits = { "diabetes2" }, weight = 110 }); current = heavy
near(DanTraits_DiaResistance(heavy), 1, 1e-9, "110 kg: full resistance")
local lean = makePlayer({ traits = { "diabetes2" }, weight = 75 }); current = lean
near(DanTraits_DiaResistance(lean), 0, 1e-9, "75 kg: none")
local mid = makePlayer({ traits = { "diabetes2" }, weight = 92.5, regularity = { squats = 100, pushups = 100, situps = 100 } }); current = mid
near(DanTraits_DiaResistance(mid), 0.5 - 0.25, 1e-9, "92.5 kg with full exercise: 0.25")
assert(DanTraits_DiaOnPill(mid) and mid._md.DanTraits.diaMedMinutes == 1440, "metformin: a day of cover")
near(DanTraits_DiaResistance(mid), 0, 1e-9, "and the pill takes the rest")
minute(); assert(mid._md.DanTraits.diaMedMinutes == 1439, "cover burns a minute a minute")
assert(DanTraits_DiaOnPill(mid) and DanTraits_DiaOnPill(mid) and mid._md.DanTraits.diaMedMinutes == 2880, "at most a day ahead")
-- heavy: sugar rises to rest around 220 on its own
current = heavy
for _ = 1, 600 do minute() end
assert(g(heavy) > 180 and g(heavy) < 225, "full resistance rests high, got " .. g(heavy))
-- lean: a spike clears in an hour or two
current = lean; lean._md.DanTraits.glucose = 300
for _ = 1, 120 do minute() end
assert(g(lean) < 150 and g(lean) > 100, "no resistance: a spike mostly clears in two hours, got " .. g(lean))
assert(not DanTraits_DiaOnPill(plain), "metformin does nothing for a non-diabetic")

-- 12. drinks: carbohydrates per litre x litres swallowed, always fast
local sipper = makePlayer(); current = sipper
local can = { _amount = 0.3, getAmount = function(self) return self._amount end, getProperties = function() return { getCarbohydrates = function() return 104 end } end }
local act = setmetatable({ character = sipper, fluidContainer = can, sip = 0.3 }, { __index = ISDrinkFluidAction })
act:updateEat(1)
near(sipper._md.DanTraits.diaFast, 31.2, 1e-9, "a can of cola: 31.2 g of fast carbs")
local water = { _amount = 1, getAmount = function(self) return self._amount end, getProperties = function() return { getCarbohydrates = function() return 0 end } end }
local act2 = setmetatable({ character = sipper, fluidContainer = water, sip = 0.5 }, { __index = ISDrinkFluidAction })
act2:updateEat(1); near(sipper._md.DanTraits.diaFast, 31.2, 1e-9, "water: nothing")

-- 12b. Alcohol is loaded too and wraps the same method: the carbs and the drink hook still land
-- (an alcoholic fluid: the Alcohol layer runs, its meds snapshot is skipped because this player cannot report them)
local drinkHook = {}
DanTraits_AddHook("drink", function(_, player, fluid, litres) drinkHook[#drinkHook + 1] = { player = player, fluid = fluid, litres = litres } end)
local beer = { _amount = 0.5, getAmount = function(self) return self._amount end,
               getProperties = function() return { getCarbohydrates = function() return 40 end, getAlcohol = function() return 0.05 end } end }
local act3 = setmetatable({ character = sipper, fluidContainer = beer, sip = 0.25 }, { __index = ISDrinkFluidAction })
act3:updateEat(1)
near(sipper._md.DanTraits.diaFast, 31.2 + 10, 1e-9, "a beer with Alcohol also loaded: 0.25 l x 40 g/l of carbs")
assert(#drinkHook == 1 and drinkHook[1].player == sipper and drinkHook[1].fluid == beer and math.abs(drinkHook[1].litres - 0.25) < 1e-9, "drink hook fired once with player, fluid and litres")

-- 13. the meter reads the number and says whether it is out of range; non-diabetics read normal
local reader = makePlayer(); current = reader; reader._md.DanTraits = { glucose = 143.4 }
local v, bad = DanTraits_DiaRead(reader); assert(v == 143 and bad == false, "reading 143, in range")
reader._md.DanTraits.glucose = 62.6; v, bad = DanTraits_DiaRead(reader); assert(v == 63 and bad == true, "63 is out of range")
rng = { 10 }; v, bad = DanTraits_DiaRead(plain); assert(v == 95 and bad == false, "non-diabetic: normal reading")

-- 14. starter kits
local kit1 = makePlayer(); handlers.OnCreatePlayer(0, kit1)
assert(#kit1._added == 5 and kit1._added[1] == "DanTraits.GlucoseMeter" and kit1._added[2] == "DanTraits.TestStrips" and kit1._added[5] == "DanTraits.InsulinPen", "Type 1: meter, strips, three pens")
local kit2 = makePlayer({ traits = { "diabetes2" } }); handlers.OnCreatePlayer(0, kit2)
assert(#kit2._added == 3 and kit2._added[3] == "DanTraits.Metformin", "Type 2: meter, strips, metformin")
handlers.OnCreatePlayer(0, kit2); assert(#kit2._added == 3, "given once")
local kit0 = makePlayer({ traits = {} }); handlers.OnCreatePlayer(0, kit0); assert(#kit0._added == 0, "no trait: no kit")

-- 15. a puff of the inhaler nudges sugar up
local wheezy = makePlayer({ traits = { "diabetes1", "asthma" } }); current = wheezy
wheezy._md.DanTraits = { glucose = 100, asthma = 0.9 }
DanTraits_UseInhaler(wheezy); near(g(wheezy), 115, 1e-9, "inhaler: +15")

-- 16. the eat hook feeds the model through the wrapped action
local eater = makePlayer(); current = eater
local eatAct = setmetatable({ character = eater, item = item("Apple", 20), percentage = 0.5 }, { __index = ISEatFoodAction })
eatAct:complete(); near(eater._md.DanTraits.diaFast, 10, 1e-9, "half an apple through the eat action")

print("diabetes: all checks passed")
