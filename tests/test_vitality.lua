-- Offline test for DanTraits_Vitality.lua and its hooks into the other traits.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
Perks = { Fitness = 'fitness', Strength = 'strength', Woodwork = 'woodwork' }

H.load("Dependent", "MDD", "Brittle", "Arthritis", "Jinxed", "BadDay", "Hallucinations", "Asthma", "Gluten", "Vegetarian", "Diabetes", "Vitality")
H.expectEvery("minute", "Vitality")
H.expectEvery("frame", "Delta:enduranceRegen"); H.expectEvery("minute", "Delta:catchCold")   -- Vitality subscribes to the pipeline

-- experience goes through the XP object, whose AddXP fires the game's AddXP event
local newPlayer = H.factory(nil, function(p)
  p._xp = {}
  p.getXp = function() return { AddXP = function(_, perk, amount) p._xp[perk] = (p._xp[perk] or 0) + amount; H.fire("AddXP", p, perk, amount) end } end
end)
local halo, near = H.halo, H.near
local minute, frame = H.minute, H.frame
local function food(o)
  return { getType = function() return o.name end, getCalories = function() return o.kcal or 0 end, getHungChange = function() return o.hunger or -0.1 end,
    getCarbohydrates = function() return o.carbs or 0 end, getUnhappyChange = function() return o.unhappy or 0 end, getFoodType = function() return o.foodType end,
    isFresh = function() return o.fresh ~= false end, isRotten = function() return o.rotten == true end, isCooked = function() return o.cooked == true end,
    isBurnt = function() return o.burnt == true end, isPackaged = function() return o.packaged == true end,
    haveExtraItems = function() return (o.ingredients or 0) > 0 end, getExtraItems = function() return { size = function() return o.ingredients or 0 end } end }
end
local function V(p) return p._md.DanTraits end

-- 1. grading
local g = DanTraits_GradeFood
near(g(food({ name = "Carrot", foodType = "Vegetables" })), 0.8, 1e-9, "fresh carrot")
near(g(food({ name = "Steak", foodType = "Meat", cooked = true })), 0.9, 1e-9, "cooked steak")
near(g(food({ name = "Stew", cooked = true, ingredients = 4 })), 1.0, 1e-9, "cooked stew, 4 ingredients (capped)")
near(g(food({ name = "Salad", ingredients = 2 })), 1.0, 1e-9, "fresh salad, 2 ingredients")
near(g(food({ name = "CannedBeans", packaged = true })), 0.5, 1e-9, "canned: neutral")
near(g(food({ name = "Rice", packaged = true })), 0.5, 1e-9, "dry rice: neutral")
near(g(food({ name = "Crisps", packaged = true, unhappy = -5 })), 0.15, 1e-9, "chips: junk")
near(g(food({ name = "Chocolate", packaged = true })), 0.15, 1e-9, "chocolate by name: junk")
near(g(food({ name = "Peanuts", packaged = true, unhappy = -2 })), 0.15, 1e-9, "packaged and comforting: junk")
near(g(food({ name = "Steak", rotten = true })), 0.0, 1e-9, "rotten: 0")
near(g(food({ name = "Steak", burnt = true, cooked = true })), 0.2, 1e-9, "burnt: 0.2")

-- 2. a meal moves the diet score by its size; the meal list keeps ten
local p = newPlayer(); H.current = p
assert(DanTraits_VitalityOnEat(p, food({ name = "Carrot", kcal = 100, foodType = "Vegetables" }), 1), "ate")
near(V(p).vitDiet, 0.5 + (0.8 - 0.5) * (100 / 4000), 1e-9, "100 kcal carrot: small nudge")
assert(#V(p).vitMeals == 1 and V(p).vitMeals[1].name == "Carrot" and V(p).vitMeals[1].kcal == 100, "meal recorded")
V(p).vitDiet = 0.5
DanTraits_VitalityOnEat(p, food({ name = "Chocolate", kcal = 850, packaged = true }), 0.5)
near(V(p).vitDiet, 0.5 + (0.15 - 0.5) * (425 / 4000), 1e-9, "half a chocolate bar: 425 kcal of junk")
for i = 1, 12 do DanTraits_VitalityOnEat(p, food({ name = "Carrot" .. i, kcal = 10 }), 1) end
assert(#V(p).vitMeals == 10, "ten meals kept")
assert(not DanTraits_VitalityOnEat(p, food({ name = "Water", kcal = 0, hunger = 0 }), 1), "nothing in it: ignored")
local q = newPlayer(); H.current = q
DanTraits_VitalityOnEat(q, food({ name = "Mystery", kcal = 0, hunger = -0.2 }), 1)
assert(q._md.DanTraits.vitMeals[1].kcal == 300, "no calorie data: hunger fallback 300 kcal")
-- one meal is capped
local big = newPlayer(); H.current = big
DanTraits_VitalityOnEat(big, food({ name = "Feast", kcal = 9000, cooked = true, ingredients = 5 }), 1)
near(V(big).vitDiet, 0.5 + 0.5 * 0.35, 1e-9, "a giant meal moves it at most 35%")

-- 3. two days of good eating gets you most of the way; two days of chips the other way
local good = newPlayer(); H.current = good
for _ = 1, 6 do DanTraits_VitalityOnEat(good, food({ name = "Stew", kcal = 700, cooked = true, ingredients = 4 }), 1) end
assert(V(good).vitDiet > 0.8, "6 x 700 kcal stew: diet " .. V(good).vitDiet)
local bad = newPlayer(); H.current = bad
for _ = 1, 6 do DanTraits_VitalityOnEat(bad, food({ name = "Crisps", kcal = 700, packaged = true, unhappy = -5 }), 1) end
assert(V(bad).vitDiet < 0.3, "6 x 700 kcal chips: diet " .. V(bad).vitDiet)

-- 4. variety: distinct food types in three days
local v = newPlayer(); H.current = v
for i, t in ipairs({ "Vegetables", "Meat", "Fruits", "Egg", "Bread" }) do
  DanTraits_VitalityOnEat(v, food({ name = "F" .. i, kcal = 100, foodType = t }), 1)
end
DanTraits_VitalityOnEat(v, food({ name = "Choc", kcal = 100, foodType = "NoExplicit" }), 1)
minute(); assert(V(v).vitVariety == 5, "five types (NoExplicit not counted), got " .. tostring(V(v).vitVariety))
v._hours = 80; minute(); assert(V(v).vitVariety == 0, "all older than 72 h: pruned")

-- 5. drinks: cola is junk, milk is neutral, water nothing
local dr = newPlayer(); H.current = dr
DanTraits_VitalityOnDrink(dr, 0.3, 104, 400); assert(V(dr).vitMeals[1].why == "sugary drink" and V(dr).vitMeals[1].kcal == 120, "cola can")
DanTraits_VitalityOnDrink(dr, 0.3, 20, 250); assert(V(dr).vitMeals[1].grade == 0.5, "milk neutral")
assert(not DanTraits_VitalityOnDrink(dr, 0.5, 0, 0), "water: nothing")
-- through the wrapped drink action
local can = { _amount = 0.3, getAmount = function(self) return self._amount end, getProperties = function() return { getCarbohydrates = function() return 104 end, getCalories = function() return 400 end } end }
local act = setmetatable({ character = dr, fluidContainer = can, sip = 0.3 }, { __index = ISDrinkFluidAction })
act:updateEat(1); assert(#V(dr).vitMeals == 3 and V(dr).vitMeals[1].kcal == 120, "drink action feeds vitality")

-- 6. exercise and sleep
local fit = newPlayer({ regularity = { squats = 100, pushups = 100, situps = 100 } }); H.current = fit
minute(); near(V(fit).vitExercise, 1, 1e-9, "full regularity")
local sl = newPlayer(); H.current = sl
-- a full night, scored an hour after getting up
sl._asleep = true; sl._hours = 10; minute()
sl._hours = 17; sl._asleep = false; sl._st.fatigue = 0.1; minute()
assert(V(sl).vitSleep == 0.5 and V(sl).vitNightHours == 7 and V(sl).vitNightWakes == 1, "just up: night not scored yet")
for _ = 1, 59 do minute() end
local q1 = (7 / 7) * 0.5 + 0.9 * 0.5
near(V(sl).vitSleep, 0.5 + (q1 - 0.5) * 0.35, 1e-9, "an hour later: 7 h, woke rested, one wake: scored"); near(V(sl).vitLastSleepHours, 7, 1e-9, "last night 7 h")
assert(V(sl).vitNightHours == 0 and V(sl).vitLastSleepWakes == 1, "night reset")
-- night terrors: three segments with short wakes are one night, with a fragmentation penalty
local nt = newPlayer(); H.current = nt
nt._asleep = true; nt._hours = 100; minute()
nt._hours = 102; nt._asleep = false; nt._st.fatigue = 0.6; for _ = 1, 10 do minute() end     -- terror at 2 h, up 10 min
nt._asleep = true; minute(); nt._hours = 105; nt._asleep = false; for _ = 1, 20 do minute() end  -- again at 5 h, up 20 min
nt._asleep = true; minute(); nt._hours = 107.5; nt._asleep = false; nt._st.fatigue = 0.15
for _ = 1, 60 do minute() end
local q2 = math.min(1, 7.5 / 7) * 0.5 + 0.85 * 0.5   -- the hours term is capped before weighting
near(V(nt).vitLastSleepHours, 7.5, 1e-9, "segments summed to 7.5 h"); assert(V(nt).vitLastSleepWakes == 3, "three wakes")
near(V(nt).vitLastSleepQuality, q2 - 0.10, 1e-9, "quality: hours capped at 1, rested 0.85, minus 2 x 0.05")
near(V(nt).vitSleep, 0.5 + (q2 - 0.10 - 0.5) * 0.35, 1e-9, "one night's move, not three")
-- Needs Less Sleep: five hours is a full night
local wk = newPlayer({ vanilla = { "base:needslesssleep", "base:brave" } }); H.current = wk
assert(DanTraits_VitalitySleepNeed(wk) == 5 and DanTraits_VitalitySleepNeed(nt) == 7, "sleep need by trait")
wk._asleep = true; wk._hours = 200; minute(); wk._hours = 205; wk._asleep = false; wk._st.fatigue = 0; for _ = 1, 60 do minute() end
near(V(wk).vitLastSleepQuality, 1, 1e-9, "5 h fully rested is a perfect night for Wakeful")
local mo = newPlayer({ vanilla = { "base:needsmoresleep" } }); assert(DanTraits_VitalitySleepNeed(mo) == 9, "Sleepyhead needs 9")
-- long stretches awake wear it down
local awake = newPlayer(); H.current = awake; V(awake) ; minute()
awake._md.DanTraits.vitSleep = 0.8; awake._md.DanTraits.vitAwakeMin = 20 * 60
minute(); near(awake._md.DanTraits.vitSleep, 0.8 - 1 / 1440, 1e-9, "past 20 h awake: drifting down")

-- 7. starving drags diet down
local hungry = newPlayer({ hunger = 0.8 }); H.current = hungry
minute(); near(V(hungry).vitDiet, 0.5 - 1 / 4320, 1e-9, "hunger 0.8: diet slips")

-- 8. combining, smoothing, tiers and halos
local c = newPlayer({ regularity = { squats = 100, pushups = 100, situps = 100 } }); H.current = c
minute(); local d = V(c)
near(d.vitTarget, 0.5 * (0.5 - 0.10) + 0.3 * 1 + 0.2 * 0.5, 1e-9, "target: diet 0.5 with no variety (-0.1), exercise 1, sleep 0.5")
near(d.vitality, 0.5 + (d.vitTarget - 0.5) / 180, 1e-9, "moves 1/180 of the gap per minute")
H.clearHalo()
d.vitality = 0.59; d.vitDiet = 1; d.vitSleep = 1
for _ = 1, 30 do minute() end
assert(d.vitality > 0.6 and halo[1] == "UI_DanTraits_VitTier3", "crossed into Fit: halo, got " .. tostring(halo[1]))
H.clearHalo()
local low = newPlayer({ hunger = 0.8 }); H.current = low; minute()
local dl = V(low); dl.vitality = 0.41; dl.vitDiet = 0
for _ = 1, 30 do minute() end
assert(dl.vitality < 0.4 and halo[1] == "UI_DanTraits_VitTier1", "dropped to Sluggish: halo, got " .. tostring(halo[1]))
assert(DanTraits_VitalityTier(0.1) == 0 and DanTraits_VitalityTier(0.5) == 2 and DanTraits_VitalityTier(0.85) == 4, "tiers")

-- 9. effect curve: dead zone, then linear to +-1
local e = DanTraits_VitalityEffectOf
assert(e(0.5) == 0 and e(0.55) == 0 and e(0.45) == 0, "dead zone")
near(e(0.8), 0.5, 1e-9, "0.8 -> +0.5"); near(e(1.0), 1, 1e-9, "1.0 -> +1"); near(e(0.2), -0.5, 1e-9, "0.2 -> -0.5"); near(e(0), -1, 1e-9, "0 -> -1")

-- 10. effects at +1: carry +1 kg on the base, mood and stress lift, health regen, colds resisted; at -1 the reverse (no health drain)
local top = newPlayer({ unhappy = 50, stress = 0.5, health = 80 }); H.current = top; minute()
local dt = V(top); dt.vitality = 1; dt.vitDiet = 1; dt.vitSleep = 1
minute()
assert(dt.vitEffect > 0.99, "effect near +1"); assert(top._carry == 9 and dt.vitCarryBase == 8 and dt.vitCarryKg == 1, "carry base 8 -> 9, got " .. top._carry)
minute(); assert(top._carry == 9, "re-applied against the base, not stacked")
assert(top._st.unhappy < 50 and top._st.stress < 0.5, "mood and stress lifted")
assert(top._health > 80, "health mending")
-- the pipeline runs first in the minute, so it uses the effect of the score as it stood before this minute moved it
local e0 = DanTraits_VitalityEffectOf(dt.vitality)
top._catch = 10; minute(); near(top._catch, 10 * (1 - 0.3 * e0), 1e-6, "cold catching cut by 30% x effect")
local bot = newPlayer({ unhappy = 0, health = 80 }); H.current = bot; minute()
local db = V(bot); db.vitality = 0; db.vitDiet = 0; db.vitSleep = 0
for _ = 1, 25 do minute() end
assert(bot._carry == 7 and V(bot).vitCarryKg == -1, "carry base 8 -> 7, got " .. bot._carry); assert(bot._st.unhappy == 20, "mood held at the floor 20, got " .. bot._st.unhappy)
assert(bot._health == 80, "no health drain from vitality alone")
-- 10b. the base is an int: a small, drifting effect must never grind it down (it once fell from 8 to 3 a kilo per change)
local drift = newPlayer(); H.current = drift; minute()
for i = 1, 200 do V(drift).vitality = 0.39 + 0.02 * ((i % 3) - 1); minute() end   -- 0.37..0.41: effect flickers around the Sluggish line
assert(drift._carry == 8 and V(drift).vitCarryBase == 8, "small effect: base untouched, got " .. drift._carry)
V(drift).vitality = 0.1; minute(); assert(drift._carry == 7, "Run Down: -1")
V(drift).vitality = 0.5; minute(); assert(drift._carry == 8, "back to neutral: restored")
V(drift).vitality = 0.81; minute(); assert(drift._carry == 9, "just over the Thriving line (effect 0.5): +1")
V(drift).vitality = 0.79; minute(); assert(drift._carry == 8, "just under: nothing")
-- a reload resets the game's base to 8 while mod data still says +1 was applied: adopt 8, apply again
V(drift).vitality = 1; minute(); assert(drift._carry == 9)
drift._carry = 8; minute(); assert(drift._carry == 9 and V(drift).vitCarryBase == 8, "reload: re-applied on the fresh base once, got " .. drift._carry)
-- another mod moved the base: adopt it
drift._carry = 12; minute(); assert(drift._carry == 13 and V(drift).vitCarryBase == 12, "external base change adopted, got " .. drift._carry)
-- old saves carry the float delta field: cleared
V(drift).vitCarryDelta = -0.0047; minute(); assert(V(drift).vitCarryDelta == nil, "legacy delta dropped")
-- endurance regen per frame
local fr = newPlayer({ endurance = 0.5 }); H.current = fr; minute()
V(fr).vitality = 1; DanTraits_DeltaRemember(V(fr), "enduranceRegen", 0.5)
fr._st.endurance = 0.6; frame(fr); near(fr._st.endurance, 0.5 + 0.1 * 1.2, 1e-9, "regen x1.2 at +1")
V(fr).vitality = 0; DanTraits_DeltaRemember(V(fr), "enduranceRegen", 0.5); fr._st.endurance = 0.6; frame(fr); near(fr._st.endurance, 0.5 + 0.1 * 0.8, 1e-9, "regen x0.8 at -1")

-- 11. the traits read it
local t2 = newPlayer({ traits = { "diabetes2" }, weight = 92.5 }); H.current = t2; minute()
V(t2).vitality = 1; near(DanTraits_DiaResistance(t2), 0.5 - 0.15, 1e-9, "T2 resistance -0.15 at +1")
V(t2).vitality = 0; near(DanTraits_DiaResistance(t2), 0.5 + 0.15, 1e-9, "+0.15 at -1")
near(DanTraits_VitalityDiaSensitivity(t2), 0.85, 1e-9, "insulin x0.85 at -1")
near(DanTraits_VitalityAsthmaBuild(t2), 1.3, 1e-9, "asthma builds x1.3 at -1")
near(DanTraits_VitalityMddOnset(t2), 1.3, 1e-9, "episodes x1.3 at -1")
V(t2).vitality = 1; near(DanTraits_VitalityAsthmaBuild(t2), 0.7, 1e-9, "x0.7 at +1")
assert(DanTraits_VitalityEffect(newPlayer()) == 0, "no data yet: no effect")

-- 12. Thriving doubles Fitness and Strength experience, nothing else, and not below Thriving
local xp = newPlayer(); H.current = xp; minute()
V(xp).vitality = 0.85
xp:getXp():AddXP(Perks.Fitness, 10); assert(xp._xp.fitness == 20, "fitness x2, got " .. xp._xp.fitness)
xp:getXp():AddXP(Perks.Strength, 4); assert(xp._xp.strength == 8, "strength x2")
xp:getXp():AddXP(Perks.Woodwork, 5); assert(xp._xp.woodwork == 5, "other skills untouched")
V(xp).vitality = 0.7; xp:getXp():AddXP(Perks.Fitness, 10); assert(xp._xp.fitness == 30, "Fit tier: no bonus")

-- 13. slept badly: a bad night sets a debt that holds mood down and wears off over the day; a nap halves it
local sb = newPlayer({ unhappy = 0 }); H.current = sb; minute()
H.clearHalo()
sb._asleep = true; sb._hours = 300; minute(); sb._hours = 302.5; sb._asleep = false; sb._st.fatigue = 0.7
for _ = 1, 60 do minute() end
local q3 = math.min(1, 2.5 / 7) * 0.5 + 0.3 * 0.5      -- 0.3286
assert(V(sb).vitLastSleepHours == 2.5 and V(sb).vitNightHours == 0, "2.5 h before the gap: a nap, not a night")
near(V(sb).vitSleepDebt or 0, 0, 1e-9, "a nap with no prior debt leaves none")
sb._asleep = true; sb._hours = 310; minute(); sb._hours = 313.5; sb._asleep = false; sb._st.fatigue = 0.7
for _ = 1, 60 do minute() end
local q4 = math.min(1, 3.5 / 7) * 0.5 + 0.3 * 0.5      -- 0.4
local debt0 = 1 - q4
near(V(sb).vitSleepDebt, debt0 - 1 / (14 * 60), 1e-9, "3.5 h is a night: debt 0.6, scored on the 60th awake minute and decayed once")
assert(halo[#halo] == "UI_DanTraits_SleptBadly2", "told about the bad night, got " .. tostring(halo[#halo]))
assert(sb._st.unhappy > 0 and sb._st.stress > 0 and sb._st.fatigue > 0.7, "mood held down, stress and fatigue creeping")
local debtNow = V(sb).vitSleepDebt
for _ = 1, 30 do minute() end
near(V(sb).vitSleepDebt, debtNow - 30 / (14 * 60), 1e-9, "wears off linearly")
assert(sb._st.unhappy <= 25 * debtNow + 1, "mood floor scales with the debt")
-- a two-hour nap halves what is left
debtNow = V(sb).vitSleepDebt
sb._asleep = true; sb._hours = 320; minute(); sb._hours = 322; sb._asleep = false; for _ = 1, 60 do minute() end
near(V(sb).vitSleepDebt, (debtNow - 59 / (14 * 60)) * 0.5 - 1 / (14 * 60), 1e-9, "59 min wearing off, then the nap halves what is left, then one more minute")
-- a good night clears it
sb._asleep = true; sb._hours = 330; minute(); sb._hours = 338; sb._asleep = false; sb._st.fatigue = 0; H.clearHalo(); for _ = 1, 60 do minute() end
near(V(sb).vitSleepDebt, 0, 1e-9, "8 h fully rested: no debt"); assert(#halo == 0, "no complaint after a good night")
near(DanTraits_SleepDebt(sb), 0, 1e-9, "getter")

-- infection hooks: nothing at neutral, x(1 -/+ 0.25 e) either side
local function allNil(name, ...) for _, fn in ipairs(DanTraits_Hooks[name]) do assert(fn(1, ...) == nil, name .. ": should say nothing here") end end
local nv = newPlayer(); H.current = nv; minute(); V(nv).vitality = 0.5
allNil("infectionHazard", nv, {}); allNil("infectionGrowth", nv)
V(nv).vitality = 1.0
near(DanTraits_RunHooks("infectionHazard", 1, nv, {}), 0.75, 1e-9, "Thriving: hazard x0.75")
near(DanTraits_RunHooks("infectionGrowth", 1, nv), 0.75, 1e-9, "Thriving: growth x0.75")
V(nv).vitality = 0.0
near(DanTraits_RunHooks("infectionHazard", 1, nv, {}), 1.25, 1e-9, "Run Down: hazard x1.25")

-- the four healing hooks: nothing at neutral, x (1 + k e) either side
for _, h in ipairs({ { "infectionFight", 0.2, 0.3 }, { "concussionHeal", 0.25, 0.25 }, { "woundHeal", 0.35, 0.25 }, { "lungHeal", 0.001, 0.25 } }) do
  V(nv).vitality = 0.5
  for _, fn in ipairs(DanTraits_Hooks[h[1]]) do assert(fn(h[2], nv) == nil, h[1] .. ": nothing at neutral") end
  V(nv).vitality = 1.0
  near(DanTraits_RunHooks(h[1], h[2], nv), h[2] * (1 + h[3]), 1e-12, h[1] .. ": Thriving")
  V(nv).vitality = 0.0
  near(DanTraits_RunHooks(h[1], h[2], nv), h[2] * (1 - h[3]), 1e-12, h[1] .. ": Run Down")
end

H.pass()
