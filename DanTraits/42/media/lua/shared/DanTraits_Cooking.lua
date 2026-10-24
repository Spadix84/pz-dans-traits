-- Project Zomboid Vitality Project: cooking (plans/cooking-overhaul.md).
-- Not a trait: everyone has it (sandbox option CookingEnabled; off: nothing
-- is tracked and the moodle shows nothing). A proper cooked meal does more
-- than fill you: a mood afterglow for a few hours, and for training, more
-- experience and one more buff picked by what the dish is mostly.
--
-- A proper meal is CK_MEAL_KCAL of one dish tier (bites of it within
-- CK_BITE_GAP minutes add up). The tier: Home-cooked (an evolved dish with two
-- ingredients or more; one never cooked, a sandwich or a salad, stops here),
-- Hearty (cooked, three ingredients, the cook at Cooking 3), Chef's (cooked,
-- four ingredients or three and a spice, the cook at Cooking 7). None for
-- burnt, rotten, a raw dish that should be cooked, or under two ingredients;
-- stale drops a tier. The cook's level is stamped on the dish as ingredients
-- go in (ISAddItemInRecipe:complete); without the stamp, the eater's.
--
-- Good Meal (the afterglow): unhappiness and stress paid back a minute at a
-- time while awake, a base by tier plus a share of the meal's own drop (the
-- game writes the ingredients' and spices' mood onto the dish), for 3 to 5
-- hours; x1.25 at home (x1.5 a Homebody), x0.5 the same dish within a day,
-- none for a texture Sensory Issues cannot stand. A new meal replaces it only
-- if it pays more than is left. Depression's comfort-food timer runs as long.
--
-- Fuelled (4 h): Fitness and Strength experience up by tier (the
-- fitnessXpAll hook of Fitness). One more by what the dish is mostly, its
-- protein, carbs and fat as calories against a line each: Recovering
-- (protein: muscles recover faster, fitnessRecovery), Energised (carbs: part
-- of the endurance spent comes back), Full (fat: hunger rises slower,
-- hungerRise). A new meal replaces them at the same tier or better, or when
-- under an hour is left. Training stuffed can give a side stitch.
--
-- Diet goals (the fitness window): Bulk, Strength experience +10% while the
-- game has you putting on weight; Cut, Fitness experience +10% while losing
-- it, and the loss a quarter faster. Fuelled with a hard day's training in,
-- weight drifts back toward normal.
--
-- Mod data (ck prefix): ckBite { type, tier, kcal, unhappy, stress, p, c, f,
-- min } (the meal being eaten), ckGlow { tier, min, max, unhappy, stress }
-- (left to pay, a minute's worth = total / max), ckFuel { tier, min },
-- ckMacro { kind, tier, min }, ckDishes[fullType] (hour last a proper meal),
-- ckEnd (endurance last minute), ckStitch (minutes of stitch left),
-- ckStitchCool, ckDiet ("bulk" | "cut"), ckMoodle.
require "DanTraits"
pcall(function() require "TimedActions/ISAddItemInRecipe" end)

local clamp01 = DanTraits_Clamp01
local hasTrait = DanTraits_HasTrait

local function cookOn() return DanTraits_SandboxOn("CookingEnabled") end
local function fitOn() return DanTraits_SandboxOn("FitnessEnabled") end

-- what makes a meal, and its tier
local CK_MEAL_KCAL     = 300      -- a proper meal
local CK_BITE_GAP      = 60       -- minutes: bites of one dish this close together are one meal
local CK_HEARTY_LEVEL  = 3        -- Cooking level for Hearty...
local CK_HEARTY_ING    = 3        -- ...and ingredients
local CK_CHEF_LEVEL    = 7
local CK_CHEF_ING      = 4        -- or one fewer with a spice
-- Good Meal, by tier (1 Home-cooked, 2 Hearty, 3 Chef's)
local CK_GLOW_UNHAPPY  = { 6, 10, 15 }        -- unhappiness paid back over the glow (0..100)
local CK_GLOW_STRESS   = { 0.03, 0.05, 0.08 } -- stress (0..1)
local CK_GLOW_SHARE    = { 0.25, 0.5, 0.75 }  -- plus this share of the meal's own drop
local CK_GLOW_HOURS    = { 3, 4, 5 }
local CK_HOME          = 1.25
local CK_HOMEBODY      = 1.5
local CK_SAME_DISH_H   = 24
local CK_SAME_DISH     = 0.5
-- training
local CK_FUEL_MIN      = 240
local CK_FUEL_XP       = { 0.05, 0.10, 0.15 }
local CK_REPLACE_LEFT  = 60       -- under this many minutes left, any proper meal replaces the buffs
local CK_MACRO = {
    protein = { line = 0.25, minutes = 360, k = { 0.10, 0.20, 0.30 } },   -- recovery x (1 + k)
    carbs   = { line = 0.50, minutes = 180, k = { 0.05, 0.10, 0.15 } },   -- endurance spent given back
    fat     = { line = 0.40, minutes = 240, k = { 0.05, 0.10, 0.15 } },   -- hunger rise x (1 - k)
}
local CK_KCAL_G        = { protein = 4, carbs = 4, fat = 9 }
-- a side stitch: training stuffed
local CK_STITCH_CHANCE = { [3] = 0.02, [4] = 0.05 }   -- a minute, by the Food Eaten moodle's level
local CK_STITCH_STIFF  = 25
local CK_STITCH_MIN    = 20       -- the moodle's bad side shows this long
local CK_STITCH_COOL   = 60
-- diet goals and weight
local CK_DIET_XP       = 0.10
local CK_CUT_LOSS      = 0.25     -- the game's loss a minute, this much more
local CK_LOSS_KG_S     = 8.5e-6   -- the game's loss rate (Nutrition.updateWeight), kilos a second at full
local CK_LOSS_FULL     = 2500     -- calories under the line for the full rate
local CK_DRIFT_KG_DAY  = 0.2
local CK_DRIFT_LOW     = 78
local CK_DRIFT_HIGH    = 82
local CK_DRIFT_HARD    = 20       -- hard training minutes today for the drift

local TIER_KEYS = { "Home", "Hearty", "Chef" }
DanTraits_CookTierKeys = TIER_KEYS

local function nowHours()
    local h = 0
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return tonumber(h) or 0
end

local function ckData(player)
    local d = DanTraits_Data(player)
    d.ckDishes = d.ckDishes or {}
    return d
end

-- the dish -----------------------------------------------------------------------------

local function call(item, method, default)
    local v = default
    pcall(function() v = item[method](item) end)
    if v == nil then return default end
    return v
end

local function ingredients(item)
    local n = 0
    pcall(function() if item:haveExtraItems() then n = item:getExtraItems():size() end end)
    return tonumber(n) or 0
end

local function spiced(item)
    local yes = false
    pcall(function()
        local spices = item:getSpices()
        yes = spices ~= nil and spices:size() > 0
    end)
    return yes
end

local function cookingLevel(player)
    local level = 0
    pcall(function() level = player:getPerkLevel(Perks.Cooking) or 0 end)
    return tonumber(level) or 0
end

-- the cook's level stamped on the dish, else the eater's
local function cookOf(player, item)
    local stamp = nil
    pcall(function() stamp = item:getModData().dtCook end)
    stamp = tonumber(stamp)
    if stamp then return stamp end
    return cookingLevel(player)
end

-- 0 (not a proper dish), 1 Home-cooked, 2 Hearty, 3 Chef's
local function dishTier(player, item)
    if not item then return 0 end
    if call(item, "isBurnt", false) or call(item, "isRotten", false) then return 0 end
    local n = ingredients(item)
    if n < 2 then return 0 end
    local cooked = call(item, "isCooked", false) == true
    local cookable = call(item, "isCookable", false) == true
    if cookable and not cooked then return 0 end
    local tier = 1
    if cooked then
        local level = cookOf(player, item)
        if level >= CK_CHEF_LEVEL and (n >= CK_CHEF_ING or (n >= CK_CHEF_ING - 1 and spiced(item))) then
            tier = 3
        elseif level >= CK_HEARTY_LEVEL and n >= CK_HEARTY_ING then
            tier = 2
        end
    end
    -- stale (past fresh, not rotten): a tier down
    if call(item, "isFresh", true) == false then tier = math.max(1, tier - 1) end
    return tier
end
DanTraits_CookTier = dishTier

-- what the dish is mostly: "protein", "carbs", "fat" or nil (no data), from
-- grams (or the item's own)
local function macroOf(p, c, f)
    local kcal = { protein = (p or 0) * CK_KCAL_G.protein, carbs = (c or 0) * CK_KCAL_G.carbs, fat = (f or 0) * CK_KCAL_G.fat }
    local total = kcal.protein + kcal.carbs + kcal.fat
    if total <= 0 then return nil end
    local best, score = nil, -1
    for _, kind in ipairs({ "protein", "carbs", "fat" }) do
        local s = kcal[kind] / total / CK_MACRO[kind].line
        if s > score then best, score = kind, s end
    end
    return best
end
DanTraits_CookMacro = macroOf

function DanTraits_CookMacroOf(item)
    return macroOf(call(item, "getProteins", 0), call(item, "getCarbohydrates", 0), call(item, "getLipids", 0))
end

-- the meal -----------------------------------------------------------------------------

-- the glow's totals for a meal: base by tier plus a share of what the dish
-- itself lifted (negative changes are lifts), times home and the same dish
local function glowTotals(player, d, tier, unhappy, stress, fullType)
    local share = CK_GLOW_SHARE[tier]
    local u = CK_GLOW_UNHAPPY[tier] + share * math.max(0, -(unhappy or 0))
    local s = CK_GLOW_STRESS[tier] + share * math.max(0, -(stress or 0))
    local k = 1
    if d.hmAtHome then k = hasTrait(player, "homebody") and CK_HOMEBODY or CK_HOME end
    local last = fullType and d.ckDishes[fullType]
    if last and nowHours() - last < CK_SAME_DISH_H then k = k * CK_SAME_DISH end
    return u * k, s * k
end

local function glowLeft(g)
    if not g or (g.min or 0) <= 0 then return 0 end
    return g.unhappy * g.min / g.max
end

local function startGlow(player, d, tier, unhappy, stress, fullType)
    local u, s = glowTotals(player, d, tier, unhappy, stress, fullType)
    if u <= glowLeft(d.ckGlow) then return false end
    local minutes = CK_GLOW_HOURS[tier] * 60
    d.ckGlow = { tier = tier, min = minutes, max = minutes, unhappy = u, stress = s }
    -- Depression: a good meal is comfort food for as long as it glows
    if hasTrait(player, "spiraling") then d.mddFoodTimer = math.max(d.mddFoodTimer or 0, minutes) end
    return true
end

local function replaces(running, tier)
    return not running or (running.min or 0) <= 0 or tier >= (running.tier or 0) or running.min < CK_REPLACE_LEFT
end

local function startFuel(d, tier, kind)
    local fuelled = false
    if replaces(d.ckFuel, tier) then
        d.ckFuel = { tier = tier, min = CK_FUEL_MIN }
        fuelled = true
    end
    if kind and replaces(d.ckMacro, tier) then
        d.ckMacro = { kind = kind, tier = tier, min = CK_MACRO[kind].minutes }
    end
    return fuelled
end

-- a proper meal went down
local function onMeal(player, d, meal)
    local kind = macroOf(meal.p, meal.c, meal.f)
    local glow = true
    if DanTraits_SensoryFood and meal.item and DanTraits_SensoryFood(player, meal.item) == "disliked" then glow = false end
    if glow then startGlow(player, d, meal.tier, meal.unhappy, meal.stress, meal.type) end
    if fitOn() then startFuel(d, meal.tier, kind) end   -- Fuelled is a training buff: nothing to fuel with Fitness off
    if meal.type then d.ckDishes[meal.type] = nowHours() end
    local tierText = getText("IGUI_DanTraits_CookTier_" .. TIER_KEYS[meal.tier])
    if kind then
        DanTraits_NotifyFmtGood(player, "UI_DanTraits_CookMealMacro", tierText, getText("IGUI_DanTraits_CookMacro_" .. kind))
    else
        DanTraits_NotifyFmtGood(player, "UI_DanTraits_CookMeal", tierText)
    end
end

-- the eat hook: a bite of a dish; bites of the same one close together add up
local function onEat(_, player, item, fraction)
    if not cookOn() or not player or not item then return nil end
    fraction = math.max(0, math.min(1, tonumber(fraction) or 1))
    if fraction <= 0 then return nil end
    local tier = dishTier(player, item)
    if tier <= 0 then return nil end
    local d = ckData(player)
    local fullType = tostring(call(item, "getFullType", "?"))
    local now = nowHours() * 60
    local b = d.ckBite
    if not b or b.type ~= fullType or now - (b.at or 0) > CK_BITE_GAP or b.done then
        b = { type = fullType, tier = tier, kcal = 0, unhappy = 0, stress = 0, p = 0, c = 0, f = 0 }
        d.ckBite = b
    end
    b.at = now
    b.tier = math.min(b.tier, tier)
    b.kcal = b.kcal + (tonumber(call(item, "getCalories", 0)) or 0) * fraction
    b.unhappy = b.unhappy + (tonumber(call(item, "getUnhappyChange", 0)) or 0) * fraction
    b.stress = b.stress + (tonumber(call(item, "getStressChange", 0)) or 0) * fraction
    b.p = b.p + (tonumber(call(item, "getProteins", 0)) or 0) * fraction
    b.c = b.c + (tonumber(call(item, "getCarbohydrates", 0)) or 0) * fraction
    b.f = b.f + (tonumber(call(item, "getLipids", 0)) or 0) * fraction
    if b.kcal >= CK_MEAL_KCAL then
        b.done = true
        onMeal(player, d, { tier = b.tier, unhappy = b.unhappy, stress = b.stress, p = b.p, c = b.c, f = b.f,
                            type = fullType, item = item })
    end
    return nil
end
DanTraits_AddHook("eat", onEat)

-- the cook's stamp: the highest Cooking level of anyone who put an ingredient in
local function wrapRecipe()
    if not ISAddItemInRecipe then return end
    DanTraits_Wrap(ISAddItemInRecipe, "complete", "cooking-stamp", function(original, self, ...)
        local res = original(self, ...)
        pcall(function()
            local dish = self.baseItem
            if dish and self.character and cookOn() then
                local md = dish:getModData()
                md.dtCook = math.max(tonumber(md.dtCook) or 0, cookingLevel(self.character))
            end
        end)
        return res
    end)
end
wrapRecipe()
Events.OnGameStart.Add(wrapRecipe)

-- what is running --------------------------------------------------------------------------

local function running(t) return t ~= nil and (t.min or 0) > 0 end

-- the buff of this kind's strength now, 0 when it is not running
local function macroK(d, kind)
    local m = d and d.ckMacro
    if not running(m) or m.kind ~= kind then return 0 end
    return CK_MACRO[kind].k[m.tier] or 0
end
DanTraits_CookMacroK = function(player, kind)
    if not player or not cookOn() then return 0 end
    return macroK(DanTraits_Data(player), kind)
end

function DanTraits_CookFuelTier(player)
    if not player or not cookOn() then return 0 end
    local f = DanTraits_Data(player).ckFuel
    return running(f) and f.tier or 0
end

function DanTraits_CookSetDiet(player, diet)
    if not player then return false end
    if diet ~= "bulk" and diet ~= "cut" then diet = nil end
    DanTraits_Data(player).ckDiet = diet
    return true
end

local function nutritionFlag(player, method)
    local yes = false
    pcall(function() yes = player:getNutrition()[method](player:getNutrition()) == true end)
    return yes
end

-- the minute ----------------------------------------------------------------------------

local function clearCooking(d)
    d.ckBite, d.ckGlow, d.ckFuel, d.ckMacro, d.ckEnd = nil, nil, nil, nil, nil
    d.ckStitch, d.ckStitchCool, d.ckMoodle = nil, nil, 0
end

local function tick(t)
    if running(t) then t.min = t.min - 1 end
end

-- training, jogging or running this minute (stretching and hard work aside)
local function exerting(player)
    if DanTraits_FitTrainingNow then
        local key, spec = DanTraits_FitTrainingNow(player)
        if key and spec and not spec.stretch then
            for _, kind in ipairs(spec.kinds or {}) do
                if kind == "work" then return false end
            end
            return true
        end
    end
    local moving, run = false, false
    pcall(function()
        moving = player:isPlayerMoving() == true
        run = player:isRunning() == true or player:isSprinting() == true
    end)
    return moving and run
end

local function stitchMinute(player, d, asleep)
    if (d.ckStitch or 0) > 0 then d.ckStitch = d.ckStitch - 1 end
    if (d.ckStitchCool or 0) > 0 then d.ckStitchCool = d.ckStitchCool - 1 return end
    if asleep or not exerting(player) then return end
    local level = 0
    pcall(function() level = player:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) or 0 end)
    local chance = CK_STITCH_CHANCE[math.min(4, tonumber(level) or 0)]
    if not chance or not DanTraits_Roll(chance) then return end
    pcall(function()
        local part = player:getBodyDamage():getBodyPart(BodyPartType.Torso_Lower)
        if part and (part:getStiffness() or 0) < CK_STITCH_STIFF then part:setStiffness(CK_STITCH_STIFF) end
    end)
    d.ckStitch, d.ckStitchCool = CK_STITCH_MIN, CK_STITCH_COOL
    DanTraits_Notify(player, "UI_DanTraits_CookStitch")
end

-- Energised: part of the endurance spent since last minute comes back
local function enduranceMinute(player, d)
    local stats = player:getStats()
    local now = nil
    pcall(function() now = stats:get(CharacterStat.ENDURANCE) end)
    now = tonumber(now)
    if not now then return end
    local k = macroK(d, "carbs")
    local last = d.ckEnd
    if k > 0 and last and now < last then
        local back = (last - now) * k
        now = math.min(DanTraits_StatMax(CharacterStat.ENDURANCE), now + back)
        pcall(function() stats:set(CharacterStat.ENDURANCE, now) end)
        -- the frame pipeline must not take this for the body's own recovery
        if DanTraits_DeltaRemember then DanTraits_DeltaRemember(d, "enduranceRegen", now) end
    end
    d.ckEnd = now
end

local function weightMinute(player, d)
    local diet = fitOn() and d.ckDiet or nil
    local n = nil
    pcall(function() n = player:getNutrition() end)
    if not n then return end
    local w = nil
    pcall(function() w = n:getWeight() end)
    w = tonumber(w)
    if not w then return end
    local change = 0
    -- Cut: the game's loss, a quarter faster
    if diet == "cut" and nutritionFlag(player, "isDecWeight") then
        local cal = 0
        pcall(function() cal = n:getCalories() or 0 end)
        change = change - CK_CUT_LOSS * CK_LOSS_KG_S * 60 * math.min(1, math.abs(tonumber(cal) or 0) / CK_LOSS_FULL)
    end
    -- well fed and trained today: back toward normal
    local trained = false
    if DanTraits_FitHardMinutes and DanTraits_FitLog and DanTraits_FitDayIndex then
        trained = DanTraits_FitHardMinutes(DanTraits_FitLog(d, DanTraits_FitDayIndex())) >= CK_DRIFT_HARD
    end
    if fitOn() and trained and running(d.ckFuel) then
        local step = CK_DRIFT_KG_DAY / 1440
        if w < CK_DRIFT_LOW and diet ~= "cut" then change = change + math.min(step, CK_DRIFT_LOW - w) end
        if w > CK_DRIFT_HIGH and diet ~= "bulk" then change = change - math.min(step, w - CK_DRIFT_HIGH) end
    end
    if change ~= 0 then pcall(function() n:setWeight(w + change) end) end
end

local function moodleLevel(d)
    if (d.ckStitch or 0) > 0 then return 1 end
    local best = 0
    if running(d.ckGlow) then best = math.max(best, d.ckGlow.tier) end
    if running(d.ckFuel) then best = math.max(best, d.ckFuel.tier) end
    if best >= 3 then return -2 end
    if best >= 1 then return -1 end
    return 0
end

local function updateCookingMinute(player, d)
    if not cookOn() then clearCooking(d) return end
    ckData(player)
    local asleep = DanTraits_Asleep(player)
    -- the afterglow: a minute's worth, awake
    local g = d.ckGlow
    if running(g) then
        if not asleep then
            local stats = player:getStats()
            DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -g.unhappy / g.max)
            DanTraits_StatAdd(stats, CharacterStat.STRESS, -g.stress / g.max)
        end
        tick(g)
        if g.min <= 0 then d.ckGlow = nil end
    end
    tick(d.ckFuel)
    if d.ckFuel and d.ckFuel.min <= 0 then d.ckFuel = nil end
    tick(d.ckMacro)
    if d.ckMacro and d.ckMacro.min <= 0 then d.ckMacro = nil end
    enduranceMinute(player, d)
    stitchMinute(player, d, asleep)
    weightMinute(player, d)
    -- dishes eaten more than a day ago are forgotten
    local now = nowHours()
    for t, at in pairs(d.ckDishes) do
        if now - at >= CK_SAME_DISH_H then d.ckDishes[t] = nil end
    end
    d.ckMoodle = moodleLevel(d)
end

DanTraits_Every("minute", "Cooking", updateCookingMinute, 40)

-- hooks ---------------------------------------------------------------------------------

-- Recovering: protein speeds the muscles' recovery
DanTraits_AddHook("fitnessRecovery", function(mult, player, d)
    if not cookOn() then return nil end
    local k = macroK(d, "protein")
    if k <= 0 then return nil end
    return mult * (1 + k)
end)

-- Full: hunger rises slower
DanTraits_AddHook("hungerRise", function(delta, player, d)
    if not cookOn() then return nil end
    local k = macroK(d or DanTraits_Data(player), "fat")
    if k <= 0 then return nil end
    return delta * (1 - k)
end)

-- Fuelled, and the diet goals: every Fitness and Strength gain
DanTraits_AddHook("fitnessXpAll", function(k, player, d, perk)
    if not cookOn() or not d then return nil end
    local add = 0
    if running(d.ckFuel) then add = add + (CK_FUEL_XP[d.ckFuel.tier] or 0) end
    local isStrength = Perks and perk == Perks.Strength
    if d.ckDiet == "bulk" and isStrength and nutritionFlag(player, "isIncWeight") then add = add + CK_DIET_XP end
    if d.ckDiet == "cut" and not isStrength and nutritionFlag(player, "isDecWeight") then add = add + CK_DIET_XP end
    if add <= 0 then return nil end
    return k * (1 + add)
end)
