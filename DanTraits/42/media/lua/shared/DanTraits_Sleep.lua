-- Project Zomboid Vitality Project: sleep and light.
-- Not a trait: every character has it (sandbox option SleepLightEnabled; off:
-- the light reads as neutral, so no faster or slower rest, no light wakes, and
-- the night's score ignores it). While asleep, the light on the
-- character's square is read every minute (the same per-player light level
-- the game's reading check uses). Dark sleep is deeper: tiredness drains
-- faster and the night scores better. Light sleep is shallow: tiredness
-- drains slower, the night scores worse, and anything brighter than about
-- reading light can wake you, more often the brighter it is. Exhaustion,
-- drink and sleeping pills let you sleep through it. Each wake also counts
-- as an interruption in Vitality's night score. Curtains and light
-- switches matter now. (With Vitality off nothing scores the night, so the
-- night's light tally is dropped on waking instead of growing for ever.)
--
-- How easily light wakes you depends on who you are:
--   Restless Sleeper, Night Owl, Cat's Eyes: x1.5 each. Restless Sleeper
--     sleeps in two halves (vanilla halves the sleep), so Vitality counts
--     two sleeps up to three hours apart as one night and does not charge
--     for the wake between them.
--   Caffeine, anyone: a full dose (a mug of coffee) keeps you on edge for
--     six hours, less for a smaller one: x2 while it lasts. A smoker clears
--     it faster, so theirs wears off sooner.
--   Other trait files add their own through the "sleepWake" hook
--     (a depressive episode, a migraine, Night Shift by day, Tinnitus).
--   The cost of bright light (slower rest, a worse score) goes through the
--     "sleepBright" hook (Night Shift by day).
--   A wound infection's fever, anyone: the night scores x0.7 at full fever
--     and light wakes you x1.5 as easily.
--   Deep Sleeper: x0.25.
-- Desensitized: the things you have seen come back at night. A chance each
-- hour asleep of waking from a nightmare, stressed and low.
--
-- Clothes in bed (sandbox option SleepClothesEnabled): sleeping dressed is
-- shallower sleep, like a lit room. Sleepwear is free: underwear, socks, a
-- T-shirt, tank top or short-sleeved shirt, shorts, a bath robe, and anything
-- that is not really clothing (jewellery, glasses, make-up, bandages). Each
-- other worn thing costs its slot's weight (jeans 0.25, a jacket 0.3, boots
-- 0.25, a backpack 0.3...), up to 1 for fully dressed: tiredness drains up to
-- 12% slower and the night scores up to 0.1 worse. Warm clothes cost nothing
-- in the cold, so winter never asks you to strip and freeze: their weight
-- fades from full at 20C air (as the game reads it for the character,
-- indoors included) to none at 10C, and none at all while you have the Cold
-- moodle. Gear (shoes, bags, belts, holsters, armour, masks) costs the same
-- whatever the weather. Deep Sleeper pays half. Waking after an hour or more
-- of a badly dressed sleep says so. "Undress and Sleep" under the game's
-- Sleep option takes it all off, puts the bags down and sleeps
-- (media/lua/client/DanTraits_SleepMenu.lua).
--
-- Deep Sleeper: Wakeful folded in (the vanilla trait is granted, so the
-- shorter sleep and Vitality's five-hour night come with it; Wakeful itself
-- is hidden at character creation, see media/lua/client). On top of that,
-- light rarely wakes you, bright light costs half as much rest, and the dark
-- does you more good.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local hasVanillaTrait = DanTraits_HasVanillaTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local fraction = DanTraits_StatFraction

local SL_DARK           = DanTraits_NIGHT.dark    -- light level at or below this: fully dark
local SL_BRIGHT         = DanTraits_NIGHT.bright  -- at or above this: fully lit (the midpoint, 0.425, is about vanilla's reading threshold)
local SL_REST_DARK      = 0.15    -- tiredness drains this much faster, fully dark...
local SL_REST_BRIGHT    = 0.15    -- ...and this much slower, fully lit
local SL_QUALITY_DARK   = DanTraits_NIGHT.qualityDark    -- added to the night's score after a dark night...
local SL_QUALITY_BRIGHT = DanTraits_NIGHT.qualityBright  -- ...taken off after a lit one
local SL_WAKE_HOUR      = 0.5     -- chance per hour of waking, fully lit
local SL_WAKE_SETTLE    = 30      -- minutes asleep before light (or a nightmare) can wake you
local SL_WAKE_TIRED     = 0.7     -- wake chance x (1 - this x fatigue): the exhausted sleep through it
local SL_WAKE_DRUNK     = 0.9     -- wake chance x (1 - this x intoxication)
-- who you are
local RS_WAKE           = 1.5     -- Restless Sleeper
local RS_NIGHT_GAP_MIN  = 180     -- two sleeps this close together are one night
local NO_WAKE           = 1.5     -- Night Owl
local NV_WAKE           = 1.5     -- Cat's Eyes
local CAF_WAKE          = 2       -- while caffeine is working
local CAF_FULL_DOSE     = 80      -- caffeine units (Caffeine Dependent's scale: a mug of coffee is about 100)...
local CAF_HOURS         = 6       -- ...that keep you on edge this long; a smaller dose, pro rata
local DES_NIGHTMARE_HOUR = 0.08   -- Desensitized: chance per hour asleep of a nightmare
local DES_STRESS        = 0.15
local DES_UNHAPPY       = 10
-- Deep Sleeper
local DS_WAKE           = 0.25    -- light wake chance x this
local DS_REST_BRIGHT    = 0.5     -- bright-light rest and score penalties x this
local DS_REST_DARK      = 1.5     -- dark rest and score bonuses x this
local SL_FEVER_CUT      = 0.3     -- the night's score x (1 - this x fever)
local SL_FEVER_WAKE     = 0.5     -- light wakes you x (1 + this x fever)
-- clothes in bed
local CL_REST           = 0.12    -- tiredness drains this much slower, fully dressed...
local CL_QUALITY        = 0.10    -- ...and this much is taken off the night's score
local CL_WARM_COLD      = 10      -- air at or below this (C): warm clothes are free...
local CL_WARM_FULL      = 20      -- ...at or above this, they cost in full
local CL_NOTIFY         = 0.25    -- waking after a sleep dressed at least this badly...
local CL_NOTIFY_MIN     = 60      -- ...and at least this long says so
local CL_STRIP_WARM     = 0.5     -- Undress and Sleep takes warm clothes off only while they cost at least this share (15C and up)
-- what each body location costs; warm ones fade in the cold. A location not
-- listed (sleepwear, jewellery, make-up, bandages) is free. Keyed the way
-- DanTraits_BodyLocation spells them: B42's own ids, no underscores
-- (base:sweaterhat); the B41 spellings are kept for the mods that still use them
local CL_SLOTS = {}
for loc, w in pairs({
    shirt = 0.15, sweater = 0.2, sweaterhat = 0.25, jersey = 0.15, fulltop = 0.2, torso1 = 0.1,
    torso1legs1 = 0.15, legs1 = 0.1, pants = 0.25, pantsskinny = 0.3, pantsextra = 0.15, skirt = 0.1,
    longskirt = 0.15, dress = 0.15, longdress = 0.2, boilersuit = 0.4, fullsuit = 0.4, bodycostume = 0.3,
    jacket = 0.3, jacketsuit = 0.3, jackethat = 0.35, jacketbulky = 0.45, jackethatbulky = 0.5,
    jacketdown = 0.45, fullrobe = 0.1, torsoextra = 0.15, torsoextravest = 0.1, hat = 0.1,
    fullhat = 0.15, scarf = 0.05, neck = 0.05, hands = 0.1, handsleft = 0.05, handsright = 0.05,
}) do CL_SLOTS[loc] = { w = w, warm = true } end
for loc, w in pairs({
    shoes = 0.25, belt = 0.05, beltextra = 0.05, back = 0.3, satchel = 0.15, fannypackfront = 0.05,
    fannypackback = 0.05, webbing = 0.2, ammostrap = 0.1, shoulderholster = 0.1, ankleholster = 0.05,
    torsoextravestbullet = 0.3, cuirass = 0.4, shoulderpadleft = 0.1, shoulderpadright = 0.1,
    sportshoulderpad = 0.3, sportshoulderpadontop = 0.3, elbowleft = 0.05, elbowright = 0.05,
    kneeleft = 0.05, kneeright = 0.05, forearmleft = 0.05, forearmright = 0.05, thighleft = 0.05,
    thighright = 0.05, calfleft = 0.05, calfright = 0.05, gaiterleft = 0.05, gaiterright = 0.05,
    gorget = 0.15, codpiece = 0.1, mask = 0.05, maskeyes = 0.1, maskfull = 0.2, fullsuithead = 0.3,
    fullsuitheadscba = 0.4, scba = 0.4, scbanotank = 0.3,
}) do CL_SLOTS[loc] = { w = w } end

local clamp01 = DanTraits_Clamp01

-- -1 (fully lit) .. +1 (fully dark), from a light level
local function darknessOf(light)
    return 1 - 2 * clamp01((light - SL_DARK) / (SL_BRIGHT - SL_DARK))
end
DanTraits_SleepDarkness = darknessOf

local function lightLevel(player)
    local light = nil
    pcall(function()
        local square = player:getCurrentSquare() or player:getSquare()
        if square then light = square:getLightLevel(player:getPlayerNum()) end
    end)
    return light
end

-- a multiplier on a good (dark > 0) or bad (dark < 0) effect, for the trait
local function scaled(player, dark, good, bad)
    local deep = hasTrait(player, "deepsleeper")
    if dark > 0 then return good * dark * (deep and DS_REST_DARK or 1) end
    return bad * dark * DanTraits_RunHooks("sleepBright", deep and DS_REST_BRIGHT or 1, player)   -- Night Shift
end

-- how much warm clothes count: 0 in the cold (or while you feel it), 1 when warm
local function clothesWarmth(player)
    if DanTraits_MoodleLevel(player, "HYPOTHERMIA") > 0 then return 0 end
    local air = DanTraits_AirTemp(player)
    if type(air) ~= "number" then return 1 end
    return clamp01((air - CL_WARM_COLD) / (CL_WARM_FULL - CL_WARM_COLD))
end

-- 0 (sleepwear) .. 1 (fully dressed): how badly dressed for bed, given the weather
local function clothesCost(player)
    if not DanTraits_SandboxOn("SleepClothesEnabled") then return 0 end
    local warmth, cost = nil, 0
    pcall(function()
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(i)
            local slot = CL_SLOTS[DanTraits_BodyLocation(item)]
            if slot then
                if slot.warm and warmth == nil then warmth = clothesWarmth(player) end
                cost = cost + slot.w * (slot.warm and warmth or 1)
            end
        end
    end)
    return math.min(1, cost)
end
DanTraits_SleepClothesCost = clothesCost

local function isBag(item) return DanTraits_Is(item, "InventoryContainer") end

-- what Undress and Sleep (media/lua/client/DanTraits_SleepMenu.lua) takes
-- off: every worn thing that costs sleep, except warm clothes once the cold
-- has taken most of their cost away (they keep you warm through the night).
-- Worn bags and bags in the hands go on the floor instead. Two lists of items.
function DanTraits_SleepUndressList(player)
    local clothes, bags = {}, {}
    if not DanTraits_SandboxOn("SleepClothesEnabled") then return clothes, bags end
    local warmth = nil
    pcall(function()
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(i)
            local slot = CL_SLOTS[DanTraits_BodyLocation(item)]
            if slot then
                if slot.warm and warmth == nil then warmth = clothesWarmth(player) end
                if isBag(item) then bags[#bags + 1] = item
                elseif not slot.warm or warmth >= CL_STRIP_WARM then clothes[#clothes + 1] = item end
            end
        end
    end)
    for _, hand in ipairs({ "getPrimaryHandItem", "getSecondaryHandItem" }) do
        local item = nil
        pcall(function() item = player[hand](player) end)
        local seen = false
        for _, b in ipairs(bags) do if b == item then seen = true end end
        if item and not seen and isBag(item) then bags[#bags + 1] = item end
    end
    return clothes, bags
end

-- the cost of sleeping dressed, for the trait (Deep Sleeper pays half)
local function clothesScaled(player, clothes, full)
    return full * clothes * (hasTrait(player, "deepsleeper") and DS_REST_BRIGHT or 1)
end

-- how easily light wakes this character: 1 is everyone
local function wakeMultiplier(player, d)
    local m = 1
    if hasVanillaTrait(player, "base:insomniac") then m = m * RS_WAKE end
    if hasVanillaTrait(player, "base:nightowl") then m = m * NO_WAKE end
    if hasVanillaTrait(player, "base:nightvision") then m = m * NV_WAKE end
    if d and (d.slCaffeineHours or 0) > 0 then m = m * CAF_WAKE end
    m = DanTraits_RunHooks("sleepWake", m, player, d)
    if hasTrait(player, "deepsleeper") then m = m * DS_WAKE end
    return m
end
DanTraits_SleepWakeMultiplier = wakeMultiplier

-- percent chance, this minute, that the light wakes you
local function wakeChance(player, dark, fatigue, intox, d)
    if dark >= 0 then return 0 end
    local chance = SL_WAKE_HOUR / 60 * -dark
    chance = chance * (1 - SL_WAKE_TIRED * clamp01(fatigue)) * (1 - SL_WAKE_DRUNK * clamp01(intox))
    return math.max(0, chance * wakeMultiplier(player, d) * 100)
end
DanTraits_SleepWakeChance = wakeChance

-- caffeine, for everyone: called by the Caffeine file for every dose it sees
function DanTraits_SleepOnCaffeine(player, amount)
    if not player or not amount or amount <= 0 then return end
    local d = traitData(player)
    local hours = CAF_HOURS * math.min(1, amount / CAF_FULL_DOSE)
    hours = hours / DanTraits_RunHooks("caffeineClearance", 1, player)   -- a smoker's wears off sooner
    d.slCaffeineHours = math.max(d.slCaffeineHours or 0, hours)
end

local function wakeUp(player, textKey)
    local ok = pcall(function() getSleepingEvent():wakeUp(player) end)
    if not ok then pcall(function() player:forceAwake() end) end
    notify(player, textKey)
end

local function nightmare(player, d)
    d.slNightmares = (d.slNightmares or 0) + 1
    d.slAsleepMin, d.slLastFatigue = nil, nil
    pcall(function()
        local stats = player:getStats()
        stats:set(CharacterStat.STRESS, math.min(1, (stats:get(CharacterStat.STRESS) or 0) + DES_STRESS))
        stats:set(CharacterStat.UNHAPPINESS, math.min(100, (stats:get(CharacterStat.UNHAPPINESS) or 0) + DES_UNHAPPY))
    end)
    wakeUp(player, "UI_DanTraits_SleepNightmare")
end

local function updateSleepMinute(player, d)
    if (d.slCaffeineHours or 0) > 0 then
        d.slCaffeineHours = d.slCaffeineHours - 1 / 60
        if d.slCaffeineHours < 1e-6 then d.slCaffeineHours = 0 end
    end
    local stats = player:getStats()
    local asleep, fatigue = false, 0
    asleep = DanTraits_Asleep(player)
    pcall(function() fatigue = stats:get(CharacterStat.FATIGUE) or 0 end)
    if not asleep then
        if (d.slClothMin or 0) >= CL_NOTIFY_MIN and d.slClothSum / d.slClothMin >= CL_NOTIFY then
            notify(player, "UI_DanTraits_SleepClothed")
        end
        d.slAsleepMin, d.slLastFatigue, d.slClothSum, d.slClothMin = nil, nil, nil, nil
        if (d.slNightMin or 0) > 0 and not DanTraits_SandboxOn("VitalityEnabled") then
            d.slNightDark, d.slNightClothes, d.slNightMin = 0, 0, 0   -- no scorer to hand it to
        end
        return
    end
    local light = lightLevel(player)
    if light == nil then return end
    local dark = DanTraits_SandboxOn("SleepLightEnabled") and darknessOf(light) or 0   -- off: light counts as neutral everywhere
    local clothes = clothesCost(player)
    d.slLight, d.slDark, d.slClothes = light, dark, clothes
    d.slAsleepMin = (d.slAsleepMin or 0) + 1
    d.slNightDark = (d.slNightDark or 0) + dark
    d.slNightClothes = (d.slNightClothes or 0) + clothes
    d.slNightMin = (d.slNightMin or 0) + 1
    d.slClothSum = (d.slClothSum or 0) + clothes
    d.slClothMin = (d.slClothMin or 0) + 1

    -- rest: scale however much tiredness the game took off since last minute
    local last = d.slLastFatigue or fatigue
    if fatigue < last then
        local rate = 1 + scaled(player, dark, SL_REST_DARK, SL_REST_BRIGHT) - clothesScaled(player, clothes, CL_REST)
        fatigue = clamp01(last - (last - fatigue) * rate)
        pcall(function() stats:set(CharacterStat.FATIGUE, fatigue) end)
    end
    d.slLastFatigue = fatigue

    if d.slAsleepMin < SL_WAKE_SETTLE then return end
    -- nightmares: sleeping pills do not keep them away
    if hasVanillaTrait(player, "base:desensitized") and ZombRand(10000) < DES_NIGHTMARE_HOUR / 60 * 10000 then
        nightmare(player, d)
        return
    end
    -- light: not on sleeping pills
    local tablets = 0
    pcall(function() tablets = player:getSleepingTabletEffect() or 0 end)
    if tablets > 0 then return end
    local chance = wakeChance(player, dark, fatigue, fraction(stats, CharacterStat.INTOXICATION), d)
    d.slWakeChance = chance
    if chance > 0 and ZombRand(10000) < chance * 100 then
        d.slLightWakes = (d.slLightWakes or 0) + 1
        d.slAsleepMin, d.slLastFatigue = nil, nil
        wakeUp(player, "UI_DanTraits_SleepLightWoke")
    end
end

-- the night's score: how dark it was, and how dressed you were, on average, while asleep
DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not d or not d.slNightMin or d.slNightMin <= 0 then return nil end
    local dark = d.slNightDark / d.slNightMin
    local clothes = (d.slNightClothes or 0) / d.slNightMin
    d.slLastNightDark, d.slLastNightClothes = dark, clothes
    d.slNightDark, d.slNightClothes, d.slNightMin = 0, 0, 0
    return clamp01(quality + scaled(player, dark, SL_QUALITY_DARK, SL_QUALITY_BRIGHT)
        - clothesScaled(player, clothes, CL_QUALITY))
end)

-- a fever is a bad night: a worse score, and lighter sleep (DanTraits_Infection.lua)
local function feverOf(player) return DanTraits_Strength("DanTraits_InfectionFever", player) end
DanTraits_AddHook("nightQuality", function(quality, player)
    local fever = feverOf(player)
    if fever <= 0 then return nil end
    return quality * (1 - SL_FEVER_CUT * fever)
end)
DanTraits_AddHook("sleepWake", function(m, player)
    local fever = feverOf(player)
    if fever <= 0 then return nil end
    return m * (1 + SL_FEVER_WAKE * fever)
end)

-- Restless Sleeper: two halves are one night, and the wake between them is
-- free (order 10: it comes off before Age scales the rest; by load order Age
-- would run first and a 50s Restless Sleeper paid 0.6 of the free wake)
DanTraits_AddHook("nightGap", function(minutes, player)
    if not hasVanillaTrait(player, "base:insomniac") then return nil end
    return math.max(minutes, RS_NIGHT_GAP_MIN)
end)
DanTraits_AddHook("nightWakes", function(wakes, player)
    if not hasVanillaTrait(player, "base:insomniac") then return nil end
    return math.max(1, wakes - 1)
end, 10)

-- Deep Sleeper carries Wakeful with it: granted once, whenever the trait is
-- first seen (new character, or added later)
local function grantWakeful(player)
    DanTraits_GrantFoldIn(player, "deepsleeper", "NEEDS_LESS_SLEEP", "slWakefulGranted")
end

DanTraits_OnPlayerReady("Sleep", grantWakeful, 70)
DanTraits_Every("minute", "Sleep", updateSleepMinute, 10)
