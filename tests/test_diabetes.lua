-- Offline test for the Diabetes traits (run with fengari; stubs stand in for the game).
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()

H.load("Dependent", "MDD", "Brittle", "Arthritis", "BadDay", "Hallucinations", "Asthma", "Gluten", "Vegetarian", "Meds", "Diabetes", "Alcohol")
H.expectHooks("OnCreatePlayer")
H.expectEvery("minute", "Diabetes")
local drinkWraps = ISDrinkFluidAction.DanTraitsWraps
assert(drinkWraps and drinkWraps["updateEat:drink-intake"] and drinkWraps["updateEat:alcohol-relief"], "both drink layers installed (Diabetes and Alcohol share updateEat)")

local newPlayer = H.factory({ traits = { "diabetes1" } })
local halo, near = H.halo, H.near
local minute = H.minute
local function item(name, carbs) return { getType = function() return name end, getCarbohydrates = function() return carbs end, getHungChange = function() return -0.1 end, getUnhappyChange = function() return 0 end } end
local function g(p) return p._md.DanTraits.glucose end

-- 1. what counts as a fast carb
for _, n in ipairs({ "Chocolate", "CandyPackage", "Lollipop", "Sugar", "Honey", "JamStrawberry", "Apple", "Banana", "IcecreamConeChoc", "CakeSlice", "Cereal", "Milk" }) do assert(DanTraits_IsFastCarb(item(n, 10)), n .. " should be fast") end
for _, n in ipairs({ "Bread", "Rice", "Potato", "PastaBowl", "Corn", "Popcorn", "Steak", "Crackers" }) do assert(not DanTraits_IsFastCarb(item(n, 10)), n .. " should be slow") end

-- 2. no trait: nothing is tracked, no shakiness
local plain = newPlayer({ traits = {} }); H.current = plain
assert(not DanTraits_DiaOnEat(plain, item("Bread", 99), 1) and plain._md.DanTraits == nil, "no trait: nothing")
minute(); assert(plain._md.DanTraits == nil or plain._md.DanTraits.glucose == nil, "no trait: no glucose model")
assert(DanTraits_ExtraFumble(plain) == 0 and DanTraits_SwingDropChance(plain) == 0, "no trait: no shakiness")

-- 3. Type 1 with nothing on board creeps up about 10 an hour
local t1 = newPlayer(); H.current = t1
for _ = 1, 60 do minute() end
near(g(t1), 110 + 0.17 * 60, 0.01, "T1 drift over an hour")

-- 4. a loaf of bread (99 slow carbs) is worth about 400 with no insulin (minus what the kidneys dump above 180)
local loaf = newPlayer(); H.current = loaf
assert(DanTraits_DiaOnEat(loaf, item("Bread", 99), 1) and loaf._md.DanTraits.diaSlow == 99 and loaf._md.DanTraits.diaFast == 0, "bread queued as slow")
for _ = 1, 30 do minute() end
local half = g(loaf)
for _ = 1, 210 do minute() end
assert(half > 200 and half < 320, "half an hour in: partway up, got " .. half)
assert(g(loaf) > 350 and g(loaf) < 470, "four hours in: high, got " .. g(loaf))
assert(DanTraits_DiaTier(g(loaf)) == 0 and select(2, DanTraits_DiaTier(g(loaf))) == 3, "top high tier")

-- 5. a candy bar hits fast: most of it inside half an hour; eating a quarter counts a quarter
local candy = newPlayer(); H.current = candy
assert(DanTraits_DiaOnEat(candy, item("Chocolate", 110), 0.25) and math.abs(candy._md.DanTraits.diaFast - 27.5) < 1e-9, "a quarter of the bar")
for _ = 1, 30 do minute() end
assert(candy._md.DanTraits.diaFast < 27.5 * 0.15, "most of the fast carbs absorbed in 30 min, left " .. candy._md.DanTraits.diaFast)
assert(g(candy) > 110 + 27.5 * 4 * 0.8, "and turned into sugar, got " .. g(candy))

-- 6. one dose: nothing for 15 minutes, then about 50 in total over four hours
local shot = newPlayer(); H.current = shot
assert(DanTraits_DiaInject(shot, 1) == 1 and #shot._md.DanTraits.diaInsulin == 1, "dose recorded")
for _ = 1, 15 do minute() end
near(g(shot), 110 + 0.17 * 15, 0.01, "no effect during onset")
for _ = 1, 225 do minute() end
near(g(shot), 110 + 0.17 * 240 - 50, 1.5, "one dose = about 50 by the time it is spent")
assert(#shot._md.DanTraits.diaInsulin == 0, "spent dose removed")
assert(DanTraits_DiaInject(shot, 0) == 0 and DanTraits_DiaInject(plain, 3) == 0, "zero doses / not diabetic: nothing")

-- 7. too much insulin sends you low; low tiers: shakiness, panic, endurance, mood, then health to a floor of 15
local low = newPlayer({ traits = { "diabetes1" } }); H.current = low
low._md.DanTraits = { glucose = 60 }; minute()
assert(DanTraits_ExtraFumble(low) == 4 and DanTraits_SwingDropChance(low) == 4, "under 70: +4% on every swing without Fumbler")
assert(low._st.panic == 1 and low._st.endurance == 1, "tier 1: panic only")
local low2 = newPlayer({ traits = { "diabetes1", "arthritis" } }); H.current = low2
low2._md.DanTraits = { glucose = 50 }; minute()
assert(DanTraits_ExtraFumble(low2) == 8 and DanTraits_SwingDropChance(low2) == 8, "under 55: +8% thrown outright, Arthritis or not, got " .. DanTraits_SwingDropChance(low2))
assert(math.abs(DanTraits_GripSlipChance(low2) - (1 + 2 / 100 * 6 + 0.003 * 5)) < 1e-9, "the arthritic slip is its own roll: 1 + panic and fatigue terms, got " .. DanTraits_GripSlipChance(low2))
assert(math.abs(low2._st.endurance - 0.97) < 1e-9 and low2._st.unhappy == 2, "tier 2: endurance drains, mood ramps toward 25")
local low3 = newPlayer({ health = 30 }); H.current = low3
low3._md.DanTraits = { glucose = 30 }
for _ = 1, 40 do minute() end
assert(low3._health == 15, "tier 3: health drains to the 15% floor, got " .. low3._health)
assert(DanTraits_ExtraFumble(low3) == 14, "tier 3: +14%")
-- a weapon swing rolls the shakiness even without Fumbler
H.rng = { 0 }; H.fire("OnWeaponSwing", low3, { name = "bat" })
assert(#low3._dropped == 1 and halo[#halo] == "UI_DanTraits_FumblerDrop", "shaky hands drop the weapon")

-- 8. high tiers: thirst, tiredness, then queasy and low, then health to the floor
local hi = newPlayer({ health = 30 }); H.current = hi
hi._md.DanTraits = { glucose = 300 }; minute()
near(hi._st.thirst, 0.004, 1e-9, "over 250: thirst per minute"); assert(hi._st.foodsick == 2 and hi._st.unhappy == 2, "over 250: queasy and low ramp in")
local hiMdd = newPlayer({ traits = { "diabetes1", "spiraling" } }); H.current = hiMdd
hiMdd._md.DanTraits = { glucose = 300, mddEpisode = true, mddSinceEnd = 0 }
for _ = 1, 30 do minute() end
assert(hiMdd._st.unhappy >= 22.5, "in a depressive episode the mood floor is x1.5 (22.5), got " .. hiMdd._st.unhappy)
local hi3 = newPlayer({ health = 30 }); H.current = hi3
hi3._md.DanTraits = { glucose = 500 }
-- since 2026-10-08 the first two hours up there cost no health: a spike after a meal is not ketoacidosis
for _ = 1, 119 do minute() end
assert(hi3._health == 30, "over 350 for under two hours: no health lost, got " .. hi3._health)
assert(hi3._st.foodsick > 40, "over 350: nauseous all the same")
for _ = 1, 60 do minute() end
assert(hi3._health == 15, "past two hours: health drains to the floor, got " .. hi3._health)
-- coming down and going straight back up counts the time already spent (it ebbs at the same pace)
local spike = newPlayer({ health = 30 }); H.current = spike
spike._md.DanTraits = { glucose = 500 }
for _ = 1, 90 do minute() end
spike._md.DanTraits.glucose = 200; for _ = 1, 30 do minute() end
spike._md.DanTraits.glucose = 500; for _ = 1, 59 do minute() end
assert(spike._health == 30, "90 up, 30 down, 59 up: still under two hours net, got " .. spike._health)
for _ = 1, 10 do minute() end
assert(spike._health < 30, "and then it starts")
-- a day above 350 and the floor is gone
H.current = hi3
hi3._md.DanTraits.diaKetoHours = 24; hi3._md.DanTraits.glucose = 500
for _ = 1, 10 do minute() end
assert(hi3._health < 15 and hi3._health > 11, "after a day of ketoacidosis health keeps falling, got " .. hi3._health)

-- 9. the messages are vague, spaced out, and hidden while drunk
H.clearHalo()
local sym = newPlayer(); H.current = sym
sym._md.DanTraits = { glucose = 60 }
for _ = 1, 9 do minute() end
assert(#halo == 0, "no message for the first ten minutes")
minute(); assert(#halo == 1 and halo[1] == "UI_DanTraits_DiaLow1", "then a vague one, got " .. tostring(halo[1]))
H.clearHalo()
local drunk = newPlayer({ intox = 20 }); H.current = drunk
drunk._md.DanTraits = { glucose = 60 }
for _ = 1, 30 do minute() end
assert(#halo == 0, "drunk: no warning signs")
H.clearHalo()
local worst = newPlayer(); H.current = worst
worst._md.DanTraits = { glucose = 30 }
H.rng = { 0, 0, 6 }   -- rolls: first timer, timer reset, then pick message 7
for _ = 1, 3 do minute() end
assert(halo[#halo] == "UI_DanTraits_DiaLow7", "at the worst tier the giveaway message is possible, got " .. tostring(halo[#halo]))

-- 9b. the BloodSugar moodle: one level per tier, high and low alike, cleared in range, hidden while drunk
do
  local mv
  MF = { getMoodle = function(name) assert(name == "BloodSugar", "moodle name " .. tostring(name)); return { setThresholds = function() end, setValue = function(_, v) mv = v end } end }
  local function level(v) return v <= 0.5 * (1 - 0.9) and 3 or v <= 0.5 * (1 - 0.6) and 2 or v <= 0.5 * (1 - 0.3) and 1 or 0 end
  local mp = newPlayer(); H.current = mp
  minute(); assert(mv == nil, "in range from the start: the moodle is never touched")
  for _, case in ipairs({ { 65, 1 }, { 50, 2 }, { 30, 3 }, { 200, 1 }, { 300, 2 }, { 400, 3 } }) do
    mp._md.DanTraits.glucose = case[1]; minute()
    assert(level(mv) == case[2], case[1] .. " mg/dL: moodle level " .. case[2] .. ", got value " .. tostring(mv))
  end
  mp._md.DanTraits.glucose = 110; minute()
  assert(mv == 0.5 and not mp._md.DanTraits.diaMoodle, "back in range: cleared")
  mv = nil; minute(); assert(mv == nil, "and left alone after that")
  local md = newPlayer({ intox = 20 }); H.current = md
  md._md.DanTraits = { glucose = 60 }; minute()
  assert(mv == nil, "drunk: no moodle")
  MF = nil
end

-- 10. alcohol pulls sugar down; panic pushes it up; running pulls it down
local booze = newPlayer({ intox = 20 }); H.current = booze; minute()
near(g(booze), 110 + 0.17 - 0.35, 1e-9, "drunk: -0.35 a minute")
local scared = newPlayer({ panic = 100 }); H.current = scared; minute()
near(g(scared), 110 + 0.17 + 0.15, 1e-9, "full panic: +0.15 a minute")
local jittery = newPlayer({ panic = 30 }); H.current = jittery; minute()
near(g(jittery), 110 + 0.17, 1e-9, "panic 30 or under: nothing")
local half = newPlayer({ panic = 65 }); H.current = half; minute()
near(g(half), 110 + 0.17 + 0.075, 1e-9, "panic 65: halfway between the minimum and full")
local runner = newPlayer({ sprint = true }); H.current = runner; minute()
near(g(runner), 110 + 0.17 - 0.5, 1e-9, "running: -0.5 a minute")

-- 11. Type 2: resistance from weight, eased by exercise and metformin; the body pulls sugar back to a setpoint
local heavy = newPlayer({ traits = { "diabetes2" }, weight = 110 }); H.current = heavy
near(DanTraits_DiaResistance(heavy), 1, 1e-9, "110 kg: full resistance")
local lean = newPlayer({ traits = { "diabetes2" }, weight = 75 }); H.current = lean
near(DanTraits_DiaResistance(lean), 0, 1e-9, "75 kg: none")
local mid = newPlayer({ traits = { "diabetes2" }, weight = 92.5, regularity = { squats = 100, pushups = 100, situps = 100 } }); H.current = mid
near(DanTraits_DiaResistance(mid), 0.5 - 0.25, 1e-9, "92.5 kg with full exercise: 0.25")
assert(DanTraits_DiaOnPill(mid), "metformin (the shared medication system)")
near(DanTraits_MedState(mid, "metformin"), 1, 1e-9, "a pill in the system")
near(DanTraits_DiaResistance(mid), 0.25, 1e-9, "first pill: not built up yet")
mid._md.DanTraits.meds.metformin.built = 1
near(DanTraits_DiaResistance(mid), 0, 1e-9, "built up, the pill takes the rest")
mid._md.DanTraits.meds = nil
-- heavy: sugar rises to rest around 220 on its own
H.current = heavy
for _ = 1, 600 do minute() end
assert(g(heavy) > 180 and g(heavy) < 225, "full resistance rests high, got " .. g(heavy))
-- lean: a spike clears in an hour or two
H.current = lean; lean._md.DanTraits.glucose = 300
for _ = 1, 120 do minute() end
assert(g(lean) < 150 and g(lean) > 100, "no resistance: a spike mostly clears in two hours, got " .. g(lean))
assert(not DanTraits_DiaOnPill(plain), "metformin does nothing for a non-diabetic")

-- 12. drinks: carbohydrates per litre x litres swallowed, always fast; the game's properties are totals for what is in the container
local sipper = newPlayer(); H.current = sipper
local can = { _amount = 0.3, getAmount = function(self) return self._amount end, getProperties = function(self) return { getCarbohydrates = function() return 104 * self._amount end } end }
local act = setmetatable({ character = sipper, fluidContainer = can, sip = 0.3 }, { __index = ISDrinkFluidAction })
act:updateEat(1)
near(sipper._md.DanTraits.diaFast, 31.2, 1e-9, "a can of cola: 31.2 g of fast carbs")
local water = { _amount = 1, getAmount = function(self) return self._amount end, getProperties = function() return { getCarbohydrates = function() return 0 end } end }
local act2 = setmetatable({ character = sipper, fluidContainer = water, sip = 0.5 }, { __index = ISDrinkFluidAction })
act2:updateEat(1); near(sipper._md.DanTraits.diaFast, 31.2, 1e-9, "water: nothing")
-- the same can in three sips still adds up to the whole can
local sips = newPlayer(); H.current = sips
local can2 = { _amount = 0.3, getAmount = function(self) return self._amount end, getProperties = function(self) return { getCarbohydrates = function() return 104 * self._amount end } end }
local act4 = setmetatable({ character = sips, fluidContainer = can2, sip = 0.1 }, { __index = ISDrinkFluidAction })
for _ = 1, 3 do act4:updateEat(1) end
near(sips._md.DanTraits.diaFast, 31.2, 1e-9, "three sips: 31.2 g")
H.current = sipper

-- 12b. Alcohol is loaded too and wraps the same method: the carbs and the drink hook still land
-- (an alcoholic fluid: the Alcohol layer runs, its meds snapshot is skipped because this player cannot report them)
local drinkHook = {}
DanTraits_AddHook("drink", function(_, player, fluid, litres) drinkHook[#drinkHook + 1] = { player = player, fluid = fluid, litres = litres } end)
local beer = { _amount = 0.5, getAmount = function(self) return self._amount end,
               getProperties = function(self) return { getCarbohydrates = function() return 40 * self._amount end, getAlcohol = function() return 0.05 end } end }
local act3 = setmetatable({ character = sipper, fluidContainer = beer, sip = 0.25 }, { __index = ISDrinkFluidAction })
act3:updateEat(1)
near(sipper._md.DanTraits.diaFast, 31.2 + 10, 1e-9, "a beer with Alcohol also loaded: 0.25 l x 40 g/l of carbs")
assert(#drinkHook == 1 and drinkHook[1].player == sipper and drinkHook[1].fluid == beer and math.abs(drinkHook[1].litres - 0.25) < 1e-9, "drink hook fired once with player, fluid and litres")

-- 13. the meter reads the number and says whether it is out of range; non-diabetics read normal
local reader = newPlayer(); H.current = reader; reader._md.DanTraits = { glucose = 143.4 }
local v, bad = DanTraits_DiaRead(reader); assert(v == 143 and bad == false, "reading 143, in range")
reader._md.DanTraits.glucose = 62.6; v, bad = DanTraits_DiaRead(reader); assert(v == 63 and bad == true, "63 is out of range")
H.rng = { 10 }; v, bad = DanTraits_DiaRead(plain); assert(v == 95 and bad == false, "non-diabetic: normal reading")

-- 14. starter kits
local kit1 = newPlayer(); H.fire("OnCreatePlayer", 0, kit1)
assert(#kit1._inv == 5 and kit1._inv[1]._type == "DanTraits.GlucoseMeter" and kit1._inv[2]._type == "DanTraits.TestStrips" and kit1._inv[5]._type == "DanTraits.InsulinPen", "Type 1: meter, strips, three pens")
local kit2 = newPlayer({ traits = { "diabetes2" } }); H.fire("OnCreatePlayer", 0, kit2)
assert(#kit2._inv == 3 and kit2._inv[3]._type == "DanTraits.Metformin", "Type 2: meter, strips, metformin")
assert(select(2, DanTraits_MedState(kit2, "metformin")) == 1, "and already on it, fully built up")
H.fire("OnCreatePlayer", 0, kit2); assert(#kit2._inv == 3, "given once")
local kit0 = newPlayer({ traits = {} }); H.fire("OnCreatePlayer", 0, kit0); assert(#kit0._inv == 0, "no trait: no kit")
SandboxVars = { DanTraits = { StartingMedication = false } }
local off1 = newPlayer(); H.fire("OnCreatePlayer", 0, off1)
assert(#off1._inv == 2 and off1._inv[2]._type == "DanTraits.TestStrips", "Starting Medication off, Type 1: meter and strips, no pens")
local off2 = newPlayer({ traits = { "diabetes2" } }); H.fire("OnCreatePlayer", 0, off2)
assert(#off2._inv == 2, "Type 2: no metformin")
SandboxVars = nil

-- 15. a puff of the inhaler nudges sugar up
local wheezy = newPlayer({ traits = { "diabetes1", "asthma" } }); H.current = wheezy
wheezy._md.DanTraits = { glucose = 100, asthma = 0.9 }
DanTraits_UseInhaler(wheezy); near(g(wheezy), 115, 1e-9, "inhaler: +15")

-- 16. the eat hook feeds the model through the wrapped action
local eater = newPlayer(); H.current = eater
local eatAct = setmetatable({ character = eater, item = item("Apple", 20), percentage = 0.5 }, { __index = ISEatFoodAction })
eatAct:complete(); near(eater._md.DanTraits.diaFast, 10, 1e-9, "half an apple through the eat action")

-- 17. illness raises blood sugar: +0.1 mg/dL a minute at full fever (DanTraits_InfectionFever)
local well, sick = newPlayer(), newPlayer()
H.current = well; minute(); local base = g(well) - 110
H.current = sick; DanTraits_InfectionFever = function() return 1 end; minute(); DanTraits_InfectionFever = nil
near(g(sick) - 110, base + 0.1, 1e-9, "full fever: +0.1 a minute")
-- 17. a bad low (under 40) can black you out: a shallow faint, at most once in 30 minutes,
--     and a PassOut that returns false (already out) does not spend the gap
local passCalls, passResult = {}, false
DanTraits_PassOut = function(_, minutes, key, deep) passCalls[#passCalls + 1] = { minutes = minutes, key = key, deep = deep }; return passResult end
local fnt = newPlayer(); H.current = fnt; fnt._md.DanTraits = { glucose = 30 }
H.rollf = 0.99; minute(); assert(#passCalls == 0, "no roll, no faint")
H.rollf = 0
passResult = false; minute(); minute()
assert(#passCalls == 2 and not (fnt._md.DanTraits.diaFaintGap and fnt._md.DanTraits.diaFaintGap > 0), "a refused faint does not spend the gap")
passResult = true; minute()
assert(#passCalls == 3 and passCalls[3].key == "UI_DanTraits_DiaBlackout" and not passCalls[3].deep, "faint: the blackout text, shallow")
assert(passCalls[3].minutes >= 5 and passCalls[3].minutes <= 20, "for 5 to 20 minutes")
assert(fnt._md.DanTraits.diaFaintGap == 30, "gap of 30 minutes")
for _ = 1, 29 do minute() end
assert(#passCalls == 3, "no second faint inside the gap")
minute(); assert(#passCalls == 4, "and one when the gap has passed")
local mildLow = newPlayer(); H.current = mildLow; mildLow._md.DanTraits = { glucose = 50 }; minute()
assert(#passCalls == 4, "tier 2: no blackout")
local sleepyLow = newPlayer({ asleep = true }); H.current = sleepyLow; sleepyLow._md.DanTraits = { glucose = 30 }; minute()
assert(#passCalls == 4, "asleep: no blackout")
H.rollf = 0.99; DanTraits_PassOut = nil
-- infection hooks: only for a diabetic, and only above 180
local function allNil(name, ...) for _, fn in ipairs(DanTraits_Hooks[name]) do assert(fn(1, ...) == nil, name .. ": should say nothing here") end end
local nd = H.player(); H.current = nd
DanTraits_Data(nd).glucose = 350
allNil("infectionHazard", nd, {}); allNil("infectionGrowth", nd)
local hd = newPlayer(); H.current = hd
minute(); allNil("infectionHazard", hd, {}); allNil("infectionGrowth", hd)
hd._md.DanTraits.glucose = 350
near(DanTraits_RunHooks("infectionHazard", 0.04, hd, {}), 0.08, 1e-12, "diabetic at 350: hazard x2")
near(DanTraits_RunHooks("infectionGrowth", 1, hd), 1.5, 1e-12, "diabetic at 350: growth x1.5")

-- knowing your insulin: First Aid 3 / 6 / 9 or the magazine, Type 1 only
local realInstanceof = instanceof
instanceof = function(obj, cls) if cls == "Food" then return type(obj) == "table" and obj.isFood == true end return realInstanceof(obj, cls) end
local function food(name, carbs) local f = item(name, carbs); f.isFood = true; return f end
local function knower(fa, recipe, traits)
  local p = newPlayer({ traits = traits }); H.current = p
  p.getPerkLevel = function(_, perk) return perk == Perks.Doctor and fa or 0 end
  p.isRecipeActuallyKnown = function(_, r) return recipe == true and r == "DanTraitsInsulinDosing" end
  return p
end
local bread, choc = food("Bread", 99), food("Chocolate", 50)
for fa, want in pairs({ [0] = 0, [2] = 0, [3] = 1, [5] = 1, [6] = 2, [8] = 2, [9] = 3, [10] = 3 }) do
  assert(DanTraits_DiaKnowledge(knower(fa)) == want, "First Aid " .. fa .. " gives knowledge " .. want)
end
assert(DanTraits_DiaKnowledge(knower(0, true)) == 3, "the magazine: exact at any First Aid")
assert(DanTraits_DiaKnowledge(knower(10, true, { "diabetes2" })) == 0, "Type 2 is never told doses")
assert(DanTraits_DiaKnowledge(knower(10, true, {})) == 0, "nor anyone without diabetes")
assert(DanTraits_DiaFoodLines(knower(2), bread) == nil, "First Aid 2: nothing on the tooltip")
near(DanTraits_DiaFoodDoses(knower(0), bread), 99 * 4 / 50, 1e-9, "a dose covers 12.5 g")
local l1 = DanTraits_DiaFoodLines(knower(3), bread)
assert(l1[1] == "Tooltip_DanTraits_DiaSlow" and l1[2] == "Tooltip_DanTraits_DiaRange:4", "level 1: slow, a wide range from 4 (7.9 x 0.6)")
local l2 = DanTraits_DiaFoodLines(knower(6), bread)
assert(l2[2] == "Tooltip_DanTraits_DiaRange:6", "level 2: a narrow range from 6 (7.9 x 0.8)")
local l3 = DanTraits_DiaFoodLines(knower(0, true), bread)
assert(l3[2] == "Tooltip_DanTraits_DiaExact:7.9", "level 3: exact, to a tenth: " .. tostring(l3[2]))
assert(DanTraits_DiaFoodLines(knower(9), choc)[1] == "Tooltip_DanTraits_DiaFast", "chocolate hits fast")
local none = DanTraits_DiaFoodLines(knower(9), food("Steak", 0))
assert(#none == 1 and none[1] == "Tooltip_DanTraits_DiaNone", "no carbohydrates: no insulin")
assert(DanTraits_DiaFoodLines(knower(9), item("Bread", 99)) == nil, "not a food item: nothing")
-- drinks: a fluid container counts by everything in it, all fast; water and fuel are not asked about
local function bottle(carbs, empty)
  return { getFluidContainer = function() return { isEmpty = function() return empty == true end,
    getProperties = function() return { getCarbohydrates = function() return carbs end } end } end }
end
local pop = DanTraits_DiaFoodLines(knower(9), bottle(50))
assert(pop[1] == "Tooltip_DanTraits_DiaFast" and pop[2] == "Tooltip_DanTraits_DiaExact:4.0", "a bottle of pop, 50 g: fast, 4 doses")
assert(DanTraits_DiaFoodLines(knower(3), bottle(50))[2] == "Tooltip_DanTraits_DiaRange:2", "level 1 on a drink: a range from 2 (4 x 0.6)")
assert(DanTraits_DiaFoodLines(knower(9), bottle(0)) == nil, "water: nothing")
assert(DanTraits_DiaFoodLines(knower(9), bottle(50, true)) == nil, "an empty bottle: nothing")
assert(DanTraits_DiaFoodLines(knower(2), bottle(50)) == nil, "First Aid 2: nothing on a drink either")
-- too much sugar at once: the exact tier says how to split it (a dosed chocolate bar peaked at 505 in play)
local splitter = knower(9); minute(); splitter._md.DanTraits.glucose = 125
local cl = DanTraits_DiaFoodLines(splitter, food("Chocolate", 110))
assert(cl[3] == "Tooltip_DanTraits_DiaParts2", "a whole 110 g bar from 125: eat half at a time, got " .. tostring(cl[3]))
assert(DanTraits_DiaFoodLines(splitter, bread)[3] == nil, "a loaf of bread is slow enough to eat whole")
assert(DanTraits_DiaFoodLines(splitter, bottle(31))[3] == nil, "a can of pop is fine")
assert(DanTraits_DiaFoodLines(knower(6), food("Chocolate", 110))[3] == nil, "only the exact tier warns")
splitter._md.DanTraits.glucose = 300
assert(DanTraits_DiaParts(splitter, food("Chocolate", 110)) == 5, "already at 300: a little at a time")
splitter._md.DanTraits.glucose = 125; splitter._md.DanTraits.diaFast = 60
assert(DanTraits_DiaParts(splitter, food("Chocolate", 50)) ~= nil, "sugar still going in counts")
-- the meter: level 2 adds the insulin still working, level 3 what to do
local m1 = knower(3); minute()
assert(#DanTraits_DiaMeterAdvice(m1, 250) == 0, "level 1: the meter says no more")
local m2 = knower(6); DanTraits_DiaInject(m2, 2)
near(DanTraits_DiaInsulinLeft(m2), 2, 0.01, "freshly injected: both doses still to come")
for _ = 1, 75 do minute() end
local left = DanTraits_DiaInsulinLeft(m2)
assert(left > 1 and left < 1.8, "75 minutes in, past the peak: some of it spent, " .. left)
local a2 = DanTraits_DiaMeterAdvice(m2, 200)
assert(#a2 == 1 and a2[1][1] == "UI_DanTraits_DiaOnBoard", "level 2: insulin still working only")
local m3 = knower(0, true); minute()
local hi = DanTraits_DiaMeterAdvice(m3, 250)
assert(hi[2][1] == "UI_DanTraits_DiaCorrect" and hi[2][2] == 3, "250, nothing on board: 3 doses to 110 (2.8)")
DanTraits_DiaInject(m3, 2)
assert(DanTraits_DiaMeterAdvice(m3, 250)[2][2] == 1, "with 2 doses already working: 1 more")
local lo = knower(0, true); minute()
local low = DanTraits_DiaMeterAdvice(lo, 60)
assert(low[2][1] == "UI_DanTraits_DiaEat" and low[2][2] == 15, "60: eat about 15 g (12.5, to the nearest 5)")
lo._md.DanTraits.diaFast = 10
assert(DanTraits_DiaMeterAdvice(lo, 60)[2][1] == "UI_DanTraits_DiaSteady", "60 with 10 g of sugar still going in: on course (heading for 100)")
assert(DanTraits_DiaMeterAdvice(knower(0, true), 120)[2][3] == true, "120: on course, said in green")
instanceof = realInstanceof
-- the meter's tooltip: its last reading, how long ago, and the advice it gave then
local meterMd = {}
local meterItem = { getFullType = function() return "DanTraits.GlucoseMeter" end, getModData = function() return meterMd end }
assert(DanTraits_DiaMeterLines(meterItem) == nil, "a meter never used: no strip")
assert(DanTraits_DiaMeterLines(bread) == nil, "not a meter: nothing")
H.hours = 100
DanTraits_DiaMeterRecord(meterItem, 250, { { "UI_DanTraits_DiaOnBoard", "0.0" }, { "UI_DanTraits_DiaCorrect", 3 } })
H.hours = 100.4
local ml = DanTraits_DiaMeterLines(meterItem)
assert(ml[1] == "Tooltip_DanTraits_MeterLastMin:250" and ml[2] == "UI_DanTraits_DiaOnBoard:0.0" and ml[3] == "UI_DanTraits_DiaCorrect:3", "250, 24 min ago, with the advice")
H.hours = 105
assert(DanTraits_DiaMeterLines(meterItem)[1] == "Tooltip_DanTraits_MeterLastHours:250", "hours later")
H.hours = 200
assert(DanTraits_DiaMeterLines(meterItem)[1] == "Tooltip_DanTraits_MeterLastDays:250", "days later")
DanTraits_DiaMeterRecord(meterItem, 120, { { "UI_DanTraits_DiaSteady", nil, true } })
ml = DanTraits_DiaMeterLines(meterItem)
assert(#ml == 2 and ml[2] == "UI_DanTraits_DiaSteady", "a new reading replaces the old; a line with no number")
DanTraits_DiaMeterRecord(meterItem, 90, {})
assert(#DanTraits_DiaMeterLines(meterItem) == 1, "low First Aid: the reading only")

-- the diaResistance hook (Age) is added before the clamp, for Type 2 only
DanTraits_AddHook("diaResistance", function(res) return res + 0.1 end)
near(DanTraits_DiaResistance(lean), 0.1, 1e-9, "75 kg plus the hook's 0.1")
near(DanTraits_DiaResistance(heavy), 1, 1e-9, "the clamp still holds")

H.pass()
