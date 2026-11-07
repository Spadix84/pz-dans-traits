-- Project Zomboid Vitality Project: catchable illness (plans/illness.md, phase 1).
--
-- Not a trait: every character can catch these. One table (ILLNESSES), one
-- engine. Each illness is:
--   caught   hidden for `inc` hours (rolled);
--   sick     a course of `len` hours (rolled): severity climbs to its peak
--            `peakAt` of the way through, then eases to nothing. The peak is
--            rolled at onset and made worse by a weak body (resistance then,
--            to the PEAK_RESIST power). The course runs faster asleep (more so
--            at home), slower running or sprinting, and a bacterial one much
--            faster on antibiotics (DanTraits_AntibioticOn, shared with wound
--            infection), which do nothing for a viral one;
--   over     immune for `immune` hours (rolled), if it leaves immunity.
-- Symptoms are the primitives the mod already has: a fever (each illness is a
-- source of the one fever, DanTraits_Fever.lua), the game's food sickness
-- (a floor), thirst, a pain floor, tiredness, and the game's own cold.
--
--   Common cold (viral)      the game's wet-and-cold meter (catchACold, which
--                            reads Prone to Illness, Resilient and Outdoorsman
--                            itself) catches it at COLD_CATCH_AT, not at the
--                            game's 100 and at once: a COLD_CATCH chance, then
--                            the incubation; and a small chance an hour
--                            (twice that November to March). We set the
--                            game's cold (hasACold, coldStrength) from the
--                            course, so its sneezes and coughs (zombies hear
--                            them, a tissue muffles them) and its moodle stay.
--                            A cold anything else starts (the game, A Really
--                            Bad Day, another mod) is adopted.
--   Stomach bug (viral)      eating with dirty or bloody hands (the game's
--                            visual blood and dirt on them).
--   Food poisoning (bact.)   rotten, raw (the game's dangerous uncooked) or
--                            stale food; on top of the game's own food
--                            sickness, which still comes at once. Thirst
--                            climbs hard: drink, or the game's Dying of
--                            Thirst costs health.
--   Flu (viral, phase 2)     a small chance an hour, November to March only;
--                            immune for the rest of the season after. A high
--                            fever, aches, endurance held down, coughing (the
--                            game's cold); worse for Asthma, Heart Condition,
--                            Smoker, Diabetes and the 50s (peak x RISK).
--   Pneumonia (bacterial)    a cold or the flu going to the chest: a chance
--                            an hour by its severity, three times running or
--                            sprinting, twice soaked, half again chilled, a
--                            smoker or asthmatic. A high fever, endurance held
--                            down, a rattling cough, and past healthFrom
--                            severity health drains. Weeks untreated; on
--                            antibiotics a few days. On top of the flu the
--                            stacked fever is what kills.
--   Strep throat (bacterial) most often while a cold runs. A sore throat
--                            (pain), a fever; a week or more, two or three
--                            days on antibiotics.
--
-- Resistance (DanTraits_IllnessResistance, x every chance to catch): Prone to
-- Illness, Resilient, Vitality, age (DanTraits_AgeIllness), sleep debt,
-- hunger, stress, and Smoker for the cold. Sandbox: IllnessEnabled (all of
-- it), IllnessFrequency (percent, x every chance), IllnessCold,
-- IllnessStomachBug, IllnessFoodPoisoning, IllnessFlu, IllnessPneumonia,
-- IllnessStrep.
--
-- Medicine eases the symptoms, never the course (DanTraits_Meds.lua; the
-- best cover of each kind counts, DanTraits_IllnessRelief): nausea (the food
-- sickness floor) bismuth x0.6, dimenhydrinate x0.5, promethazine x0.25;
-- cramps and the runs' thirst, bismuth; the cold's strength as the game shows
-- it (sneezes, coughs, the moodle) night-time cold liquid x0.5, daytime
-- capsules x0.6, cough syrup x0.5, antihistamines x0.8. The fever reducers
-- are DanTraits_Fever.lua's.
--
-- Herbs (the game's own, eaten or as a spice in a hot drink or a dish) are a
-- gentler relief of one kind for HERB_H hours, the strongest of each kind
-- counting (HERBS): Lemongrass, ginger and mint for nausea, chamomile for
-- cramps, Common Mallow, thyme and honey for the cough, Black Sage and honey
-- for aches (every illness's pain floor). The game's own effect (Lemongrass's
-- -12 food sickness, Black Sage's pain relief) still lands once, but our
-- floors would undo it within minutes; this is what lasts. The one relief
-- with no medicine needed: a primitive run's only help.
--
-- An illness's fever also weakens the body against a wound infection (the
-- infectionGrowth and infectionFight hooks): a cold on an infected wound
-- tips it into sepsis sooner.
--
-- Mod data: ill (by id: { inc = minutes } while hidden, { t, len, peak, sev,
-- fev } while sick), illImmune (by id: the world hour it lasts to), illFever
-- (the worst illness fever, last minute), illColdHeld / illColdStrength (we
-- set the game's cold), illHerb (by relief kind: { k, to = world hour }),
-- illPainNow (the minute's worst ache, while it runs).
-- Console: ill [<id> [now]] | ill clear  (ids: cold, flu, pneumonia, strep, stomach, food)
require "DanTraits"
require "DanTraits_Fever"

local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local hasTrait = DanTraits_HasTrait
local hasVanillaTrait = DanTraits_HasVanillaTrait
local clamp01 = DanTraits_Clamp01
local over = DanTraits_Over
local roll = DanTraits_Roll
local randRange = DanTraits_RandRange

local ILL = {
    COLD_CATCH_AT  = 90,       -- the game's wet-and-cold meter (0..100): here a cold may take (the game's own takes at 100, at once)
    COLD_CATCH     = 0.75,     -- ...this chance (a virus has to be about too); the meter starts again either way
    COLD_BASE_H    = 0.0004,   -- chance an hour of a cold from nowhere in particular (a doorknob, a cough)...
    COLD_WINTER    = 2,        -- ...x this November to March
    COLD_STRENGTH  = { 20, 70 },   -- the game's cold strength at the first of a cold and at a full one (a runny nose to a nasty cold)
    STOMACH_MEAL   = 0.12,     -- chance a full meal brings the stomach bug, x hand grime (0..1)...
    STOMACH_FROM   = 0.1,      -- ...grime under this is clean enough
    FOOD_ROTTEN    = 0.30,     -- chance a full portion brings food poisoning: rotten...
    FOOD_RAW       = 0.35,     -- ...raw meat, fish or eggs (the game's dangerous uncooked)...
    FOOD_STALE     = 0.04,     -- ...stale
    FOOD_COOKED    = 0.5,      -- rotten but cooked: x this
    FOOD_IRON_GUT  = 0.5,
    FOOD_WEAK      = 1.5,      -- Weak Stomach
    PRONE          = 1.3,      -- Prone to Illness
    RESILIENT      = 0.7,
    VITALITY       = 0.25,     -- x (1 - this x Vitality's effect, -1..1)
    SLEEP_DEBT     = 0.3,      -- up to x (1 + this) with tiredness from SLEEP_FROM to SLEEP_FULL
    SLEEP_FROM     = 0.5,
    SLEEP_FULL     = 0.9,
    HUNGER         = 0.2,      -- up to x (1 + this) with hunger from HUNGER_FROM to HUNGER_FULL
    HUNGER_FROM    = 0.3,
    HUNGER_FULL    = 0.7,
    STRESS         = 0.2,      -- x (1 + this x stress)
    SMOKER         = 1.15,     -- the cold only
    PEAK_RESIST    = 0.5,      -- the peak x resistance^this at onset
    REST_ASLEEP    = 1.3,      -- the course runs x this asleep...
    REST_HOME      = 1.5,      -- ...asleep at home
    EXERTING       = 0.8,      -- ...running or sprinting
    ABX_PACE       = 2.5,      -- a bacterial illness on antibiotics: the course x this...
    ABX_EASE       = 0.7,      -- ...and its severity x this
    FLU_BASE_H     = 0.0003,   -- chance an hour of the flu, November to March only
    PNEU_COLD_H    = 0.0004,   -- chance an hour, x severity, a cold goes to the chest...
    PNEU_FLU_H     = 0.001,    -- ...or the flu does
    PNEU_EXERT     = 3,        -- ...x this running or sprinting
    PNEU_WET       = 2,        -- ...x this soaked (wetness from PNEU_WET_AT)
    PNEU_WET_AT    = 0.5,
    PNEU_CHILLED   = 1.5,      -- ...x this with the body under PNEU_CHILL_C
    PNEU_CHILL_C   = 36,
    PNEU_SMOKER    = 1.5,      -- ...x this a smoker, and again for Asthma
    PNEU_ASTHMA    = 1.5,
    STREP_COLD_H   = 0.0005,   -- chance an hour of strep while a cold runs...
    STREP_BASE_H   = 0.00005,  -- ...and from nowhere in particular
    RISK           = 1.3,      -- the flu and pneumonia peak x this for Asthma, Heart Condition, Smoker, Diabetes and the 50s
    INF_GROWTH     = 0.5,      -- an illness's fever: a wound infection grows x (1 + this x fever)...
    INF_FIGHT      = 0.5,      -- ...and the body clears one x (1 - this x fever)
    SICK_RAMP      = 1,        -- food sickness rises at most this a minute toward the floor
    PAIN_RAMP      = 1,
    HERB_H         = 3,        -- hours a herb's relief lasts
}
DanTraits_ILL = ILL   -- tests

-- inc, len, immune in hours; peak 0..1; fever = feverMax x over(severity, feverFrom, 1);
-- fatigue and thirst a minute, sick (food sickness floor) and pain at full severity;
-- gut: the stomach medicines ease its cramps and thirst; shows: it drives the
-- game's cold (sneezes, coughs, the moodle); endCap: endurance held under
-- 1 - this x severity; health: per minute from severity healthFrom to full;
-- risky: the RISK groups get it worse; lungs: Smoker catches more
local ILLNESSES = {
    cold = { option = "IllnessCold", kind = "viral", lungs = true, shows = true,
             inc = { 12, 36 }, len = { 72, 168 }, peakAt = 0.35, peak = { 0.4, 0.9 }, immune = { 21 * 24, 35 * 24 },
             feverFrom = 0.6, feverMax = 0.25, fatigue = 0.0002, thirst = 0, sick = 0, pain = 0,
             onset = "UI_DanTraits_IllColdOnset", over = "UI_DanTraits_IllColdOver" },
    stomach = { option = "IllnessStomachBug", kind = "viral", gut = true,
             inc = { 12, 48 }, len = { 24, 72 }, peakAt = 0.3, peak = { 0.5, 1 }, immune = { 28 * 24, 56 * 24 },
             feverFrom = 0, feverMax = 0.15, fatigue = 0.0002, thirst = 0.0006, sick = 50, pain = 15,
             onset = "UI_DanTraits_IllStomachOnset", over = "UI_DanTraits_IllStomachOver" },
    food = { option = "IllnessFoodPoisoning", kind = "bacterial", gut = true,
             inc = { 6, 24 }, len = { 24, 48 }, peakAt = 0.25, peak = { 0.5, 1 }, immune = nil,
             feverFrom = 0, feverMax = 0.35, fatigue = 0.0003, thirst = 0.0012, sick = 70, pain = 25,
             onset = "UI_DanTraits_IllFoodOnset", over = "UI_DanTraits_IllFoodOver" },
    -- phase 2 (2026-11-03): one flu strain a winter, so immune for the season
    flu = { option = "IllnessFlu", kind = "viral", lungs = true, shows = true, risky = true,
             inc = { 24, 72 }, len = { 120, 240 }, peakAt = 0.25, peak = { 0.6, 1 }, immune = { 120 * 24, 150 * 24 },
             feverFrom = 0, feverMax = 0.7, fatigue = 0.0006, thirst = 0.0002, sick = 0, pain = 30, endCap = 0.5,
             onset = "UI_DanTraits_IllFluOnset", over = "UI_DanTraits_IllFluOver" },
    -- a cold or the flu gone to the chest: antibiotics, or weeks
    pneumonia = { option = "IllnessPneumonia", kind = "bacterial", lungs = true, shows = true, risky = true,
             inc = { 6, 12 }, len = { 240, 504 }, peakAt = 0.4, peak = { 0.6, 1 }, immune = nil,
             feverFrom = 0, feverMax = 0.8, fatigue = 0.0008, thirst = 0.0003, sick = 0, pain = 25, endCap = 0.6,
             health = 0.08, healthFrom = 0.7,
             onset = "UI_DanTraits_IllPneumoniaOnset", over = "UI_DanTraits_IllPneumoniaOver" },
    -- strep throat, often after a cold
    strep = { option = "IllnessStrep", kind = "bacterial",
             inc = { 24, 48 }, len = { 168, 240 }, peakAt = 0.3, peak = { 0.5, 0.9 }, immune = { 30 * 24, 60 * 24 },
             feverFrom = 0, feverMax = 0.4, fatigue = 0.0003, thirst = 0.0001, sick = 0, pain = 20,
             onset = "UI_DanTraits_IllStrepOnset", over = "UI_DanTraits_IllStrepOver" },
}
local ILL_ORDER = { "cold", "flu", "pneumonia", "strep", "stomach", "food" }

-- symptom relief: drug id (DanTraits_Meds.lua) -> x on the symptom while it is working
local RELIEF = {
    nausea = { bismuth = 0.6, dimenhydrinate = 0.5, promethazine = 0.25 },   -- the food sickness floor
    cramps = { bismuth = 0.6 },                                              -- the pain floor
    runs   = { bismuth = 0.7 },                                              -- the thirst
    cold   = { nightcold = 0.5, daycold = 0.6, coughsyrup = 0.5, antihistamine = 0.8 },   -- the game's cold strength
    ache   = {},                                                             -- every illness's pain floor: herbs only (HERBS)
}
DanTraits_IllnessReliefTable = RELIEF

-- the game's herbs (item type, lower case) -> relief kind -> x, for ILL.HERB_H
-- hours; weaker than the medicine, and dried counts the same
local HERBS = {
    lemongrass = { nausea = 0.7 },
    gingerroot = { nausea = 0.8 }, gingerpickled = { nausea = 0.85 },
    mintherb = { nausea = 0.85 }, mintherbdried = { nausea = 0.85 },
    chamomile = { cramps = 0.8 }, chamomiledried = { cramps = 0.8 },
    commonmallow = { cold = 0.8 }, commonmallowdried = { cold = 0.8 },
    thyme = { cold = 0.9 }, thymedried = { cold = 0.9 },
    honey = { cold = 0.9, ache = 0.9 },
    blacksage = { ache = 0.8 }, blacksagedried = { ache = 0.8 },
}
DanTraits_IllnessHerbs = HERBS
local HERB_KINDS = { "nausea", "cramps", "ache", "cold" }

-- the best relief working for one kind of symptom (1: none): a medicine
-- (DanTraits_Meds.lua) or a herb still working
function DanTraits_IllnessRelief(player, kind)
    local best = 1
    if DanTraits_MedCovered then
        for id, k in pairs(RELIEF[kind] or {}) do
            if k < best and DanTraits_MedCovered(player, id) then best = k end
        end
    end
    local d = player and player:getModData().DanTraits
    local herb = d and d.illHerb and d.illHerb[kind]
    if herb and herb.to > DanTraits_WorldHours() and herb.k < best then best = herb.k end
    return best
end
local relief = DanTraits_IllnessRelief
DanTraits_Illnesses = ILLNESSES
DanTraits_IllnessOrder = ILL_ORDER

local function sandboxOn() return DanTraits_SandboxOn("IllnessEnabled") end
local function on(id) return sandboxOn() and DanTraits_SandboxOn(ILLNESSES[id].option) end
local function frequency() return math.max(0, DanTraits_SandboxNum("IllnessFrequency", 100)) / 100 end

local function illData(player)
    local d = DanTraits_Data(player)
    d.ill = d.ill or {}
    d.illImmune = d.illImmune or {}
    return d
end

local function statOf(player, stat)
    local v = 0
    pcall(function() v = player:getStats():get(stat) or 0 end)
    return tonumber(v) or 0
end

-- x every chance to catch something; lungs: the cold's extras; catchCold: for
-- the game's cold meter, which reads the two traits itself and has Vitality's
-- own hook on it
local function resistance(player, lungs, catchCold)
    local k = 1
    if not catchCold then
        if hasVanillaTrait(player, "base:pronetoillness") then k = k * ILL.PRONE end
        if hasVanillaTrait(player, "base:resilient") then k = k * ILL.RESILIENT end
        if DanTraits_VitalityEffect then
            local ok, e = pcall(DanTraits_VitalityEffect, player)
            if ok and tonumber(e) then k = k * (1 - ILL.VITALITY * tonumber(e)) end
        end
    end
    if DanTraits_AgeIllness then k = k * (tonumber(DanTraits_AgeIllness(player)) or 1) end
    k = k * (1 + ILL.SLEEP_DEBT * over(statOf(player, CharacterStat.FATIGUE), ILL.SLEEP_FROM, ILL.SLEEP_FULL))
    k = k * (1 + ILL.HUNGER * over(statOf(player, CharacterStat.HUNGER), ILL.HUNGER_FROM, ILL.HUNGER_FULL))
    k = k * (1 + ILL.STRESS * clamp01(statOf(player, CharacterStat.STRESS)))
    if lungs and (hasTrait(player, "smoker") or hasVanillaTrait(player, "base:smoker")) then k = k * ILL.SMOKER end
    return k
end
DanTraits_IllnessResistance = resistance

local function smoker(player) return hasTrait(player, "smoker") or hasVanillaTrait(player, "base:smoker") end

-- the flu and pneumonia are worse for: Asthma, Heart Condition, Smoker, Diabetes, the 50s
local function atRisk(player)
    if smoker(player) then return true end
    for _, id in ipairs({ "asthma", "heart", "diabetes1", "diabetes2" }) do
        if hasTrait(player, id) then return true end
    end
    return DanTraits_AgeBand ~= nil and DanTraits_AgeBand(player) == 50
end
DanTraits_IllnessAtRisk = atRisk

-- caught: hidden for the incubation; nothing if it is already running, the
-- body is immune, or it is switched off
local function catch(player, d, id)
    if not on(id) or d.ill[id] then return false end
    if (d.illImmune[id] or 0) > DanTraits_WorldHours() then return false end
    local def = ILLNESSES[id]
    d.ill[id] = { inc = math.max(1, math.floor(randRange(def.inc[1], def.inc[2]) * 60)) }
    return true
end

-- the symptoms start; floor: a severity the peak is at least (an adopted cold)
local function onset(player, d, id, floor)
    local def = ILLNESSES[id]
    local peak = randRange(def.peak[1], def.peak[2]) * resistance(player, def.lungs) ^ ILL.PEAK_RESIST
    if def.risky and atRisk(player) then peak = peak * ILL.RISK end
    peak = math.max(0.2, floor or 0, math.min(1, peak))
    d.ill[id] = { t = 0, len = randRange(def.len[1], def.len[2]), peak = math.min(1, peak), sev = 0, fev = 0 }
    notify(player, def.onset)
end

-- 0..1 of the peak, x through the course: from a fifth up to the peak, then down to nothing
local function shape(x, peakAt)
    if x <= 0 then return 0.2 end
    if x < peakAt then return 0.2 + 0.8 * x / peakAt end
    return clamp01((1 - x) / (1 - peakAt))
end
DanTraits_IllnessShape = shape

local function atHome(player, d)
    if not DanTraits_HomeStrength or not DanTraits_HomeAtPlace then return false end
    if (DanTraits_HomeStrength(player) or 0) <= 0 then return false end
    local x, y = 0, 0
    pcall(function() x, y = player:getX(), player:getY() end)
    return DanTraits_HomeAtPlace(d.hmHome, x, y) == true
end

-- how fast the course runs this minute (x real time)
local function pace(player, d, def)
    local k = 1
    if DanTraits_Asleep(player) then
        k = atHome(player, d) and ILL.REST_HOME or ILL.REST_ASLEEP
    else
        local hard = false
        pcall(function() hard = player:isRunning() or player:isSprinting() end)
        if hard then k = ILL.EXERTING end
    end
    if def.kind == "bacterial" and DanTraits_AntibioticOn(player) then k = k * ILL.ABX_PACE end
    return k
end

local function symptoms(player, d, id, rec)
    local def = ILLNESSES[id]
    local s = rec.sev
    if def.kind == "bacterial" and DanTraits_AntibioticOn(player) then s = s * ILL.ABX_EASE end
    rec.fev = def.feverMax * over(s, def.feverFrom, 1)
    local stats = player:getStats()
    if def.fatigue > 0 and not DanTraits_Asleep(player) then DanTraits_StatAdd(stats, CharacterStat.FATIGUE, def.fatigue * s) end
    if def.thirst > 0 then DanTraits_StatAdd(stats, CharacterStat.THIRST, def.thirst * s * (def.gut and relief(player, "runs") or 1)) end
    if def.sick > 0 then DanTraits_FloorUp(stats, CharacterStat.FOOD_SICKNESS, def.sick * s * relief(player, "nausea"), ILL.SICK_RAMP) end
    if def.pain > 0 then
        -- the worst illness's ache is the one floor (the minute sets it once, the floors are max-like)
        local floor = def.pain * s * (def.gut and relief(player, "cramps") or 1) * relief(player, "ache")
        if floor > (d.illPainNow or 0) then d.illPainNow = floor end
    end
    if def.endCap then
        local cap = 1 - def.endCap * s
        pcall(function()
            if (stats:get(CharacterStat.ENDURANCE) or 1) > cap then stats:set(CharacterStat.ENDURANCE, cap) end
        end)
    end
    if def.health and s > def.healthFrom then
        pcall(function() player:getBodyDamage():ReduceGeneralHealth(def.health * over(s, def.healthFrom, 1)) end)
    end
end

-- the cold -------------------------------------------------------------------

local function bodyOf(player)
    local bd
    pcall(function() bd = player:getBodyDamage() end)
    return bd
end

local function winter()
    local month = 6
    pcall(function() month = getGameTime():getMonth() end)
    return month >= 10 or month <= 2   -- 0-based: November to March
end

-- adopt a cold someone else started, run the game's wet-and-cold meter our
-- way, and the background chance
local function coldChances(player, d)
    if not on("cold") then return end
    local bd = bodyOf(player)
    if not bd then return end
    local has = false
    pcall(function() has = bd:isHasACold() end)
    local rec = d.ill.cold
    if has and not d.illColdHeld and not (rec and rec.len) then
        local strength = ILL.COLD_STRENGTH[1]
        pcall(function() strength = bd:getColdStrength() or strength end)
        d.ill.cold = nil
        onset(player, d, "cold", over(strength, ILL.COLD_STRENGTH[1], ILL.COLD_STRENGTH[2]))
        d.illColdHeld = true
    end
    local meter = 0
    pcall(function() meter = bd:getCatchACold() or 0 end)
    if meter >= ILL.COLD_CATCH_AT then
        pcall(function() bd:setCatchACold(0) end)
        DanTraits_DeltaRemember(d, "catchCold", 0)
        if roll(ILL.COLD_CATCH) then catch(player, d, "cold") end
    end
    local h = ILL.COLD_BASE_H * (winter() and ILL.COLD_WINTER or 1) * resistance(player, true) * frequency()
    if roll(h / 60) then catch(player, d, "cold") end
end

-- the flu's season, and what a cold or the flu can turn into
local function otherChances(player, d)
    local k = frequency()
    if winter() and roll(ILL.FLU_BASE_H * resistance(player, true) * k / 60) then catch(player, d, "flu") end
    local cold, flu = d.ill.cold, d.ill.flu
    local chest = math.max(cold and cold.len and (cold.sev or 0) * ILL.PNEU_COLD_H or 0,
                           flu and flu.len and (flu.sev or 0) * ILL.PNEU_FLU_H or 0)
    if chest > 0 and on("pneumonia") and not d.ill.pneumonia then
        local h = chest * resistance(player, true) * k
        local hard = false
        pcall(function() hard = player:isRunning() or player:isSprinting() end)
        if hard then h = h * ILL.PNEU_EXERT end
        if statOf(player, CharacterStat.WETNESS) / 100 >= ILL.PNEU_WET_AT then h = h * ILL.PNEU_WET end
        local temp = statOf(player, CharacterStat.TEMPERATURE)
        if temp > 20 and temp < ILL.PNEU_CHILL_C then h = h * ILL.PNEU_CHILLED end
        if smoker(player) then h = h * ILL.PNEU_SMOKER end
        if hasTrait(player, "asthma") then h = h * ILL.PNEU_ASTHMA end
        if roll(h / 60) then catch(player, d, "pneumonia") end
    end
    local strep = ILL.STREP_BASE_H + ((cold and cold.len) and ILL.STREP_COLD_H or 0)
    if roll(strep * resistance(player, false) * k / 60) then catch(player, d, "strep") end
end
DanTraits_IllnessOtherChances = otherChances   -- tests

-- the game's cold follows ours (a cold, the flu, pneumonia: the worst of
-- them); let go of it once none is left
local function driveCold(player, d)
    local bd = bodyOf(player)
    if not bd then return end
    local worst, any = 0, false
    for _, id in ipairs(ILL_ORDER) do
        local rec = d.ill[id]
        if ILLNESSES[id].shows and rec and rec.len and on(id) then
            any = true
            worst = math.max(worst, clamp01(rec.sev or 0))
        end
    end
    if any then
        local shown = worst * relief(player, "cold")
        local strength = ILL.COLD_STRENGTH[1] + (ILL.COLD_STRENGTH[2] - ILL.COLD_STRENGTH[1]) * shown
        pcall(function()
            bd:setHasACold(true)
            bd:setColdStrength(strength)
        end)
        d.illColdHeld, d.illColdStrength = true, strength
    elseif d.illColdHeld then
        pcall(function()
            bd:setHasACold(false)
            bd:setColdStrength(0)
        end)
        d.illColdHeld, d.illColdStrength = nil, nil
    end
end

-- the minute -------------------------------------------------------------------

-- switched off mid-game: let go of the game's cold and the fevers; the
-- illnesses are kept and resume if it is switched back on
local function standDown(player, d)
    for _, id in ipairs(ILL_ORDER) do
        local rec = d.ill[id]
        if rec then rec.fev = 0 end
    end
    d.illFever = 0
    if d.illColdHeld then
        local bd = bodyOf(player)
        if bd then pcall(function() bd:setHasACold(false); bd:setColdStrength(0) end) end
        d.illColdHeld, d.illColdStrength = nil, nil
    end
end

local function updateIllnessMinute(player, d)
    d = illData(player)
    if not sandboxOn() then standDown(player, d) return end
    coldChances(player, d)
    otherChances(player, d)
    local now = DanTraits_WorldHours()
    local fever = 0
    d.illPainNow = 0
    for _, id in ipairs(ILL_ORDER) do
        local def, rec = ILLNESSES[id], d.ill[id]
        if rec and not on(id) then
            d.ill[id], rec = nil, nil
        end
        if rec and rec.inc then
            rec.inc = rec.inc - 1
            if rec.inc <= 0 then
                onset(player, d, id)
                rec = d.ill[id]
            end
        end
        if rec and rec.len then
            rec.t = rec.t + pace(player, d, def) / 60
            if rec.t >= rec.len then
                d.ill[id] = nil
                if def.immune then d.illImmune[id] = now + randRange(def.immune[1], def.immune[2]) end
                notifyGood(player, def.over)
            else
                rec.sev = rec.peak * shape(rec.t / rec.len, def.peakAt)
                symptoms(player, d, id, rec)
                fever = math.max(fever, rec.fev or 0)
            end
        end
        if d.illImmune[id] and d.illImmune[id] <= now then d.illImmune[id] = nil end
    end
    d.illFever = fever
    if d.illHerb then
        for kind, rec in pairs(d.illHerb) do
            if rec.to <= now then d.illHerb[kind] = nil end
        end
    end
    if d.illPainNow > 0 then DanTraits_PainFloor(player, d, "illness", d.illPainNow, ILL.PAIN_RAMP) end
    d.illPainNow = nil
    driveCold(player, d)
end

-- each illness is its own source of the one fever
for _, id in ipairs(ILL_ORDER) do
    DanTraits_FeverSource(id, function(player, d)
        if not sandboxOn() then return 0 end
        local rec = d and d.ill and d.ill[id]
        return (rec and rec.fev) or 0
    end)
end

-- the worst illness fever, 0..1
function DanTraits_IllnessFever(player)
    if not sandboxOn() then return 0 end
    local d = player and player:getModData().DanTraits
    return (d and d.illFever) or 0
end

-- a sick body fights a wound infection worse
DanTraits_AddHook("infectionGrowth", function(k, player)
    local f = DanTraits_IllnessFever(player)
    if f <= 0 then return nil end
    return k * (1 + ILL.INF_GROWTH * f)
end)
DanTraits_AddHook("infectionFight", function(k, player)
    local f = DanTraits_IllnessFever(player)
    if f <= 0 then return nil end
    return k * (1 - ILL.INF_FIGHT * f)
end)

-- the game's cold meter, by the body's resistance and the sandbox
DanTraits_AddHook("catchCold", function(delta, player)
    if not on("cold") then return nil end
    return delta * resistance(player, true, true) * frequency()
end)

-- eating -----------------------------------------------------------------------

-- 0..1: the blood and dirt on the hands (the game's visual)
local function handsGrime(player)
    local total, n = 0, 0
    pcall(function()
        local visual = player:getHumanVisual()
        for _, name in ipairs({ "Hand_L", "Hand_R" }) do
            local part = BloodBodyPartType[name]
            total = total + math.min(1, (visual:getBlood(part) or 0) + (visual:getDirt(part) or 0))
            n = n + 1
        end
    end)
    if n == 0 then return 0 end
    return total / n
end
DanTraits_IllnessHandsGrime = handsGrime

-- the chance a full portion of this brings food poisoning
local function foodRisk(food)
    local rotten, raw, cooked, fresh, burnt = false, false, false, true, false
    pcall(function() rotten = food:isRotten() == true end)
    pcall(function() raw = food:isbDangerousUncooked() == true end)
    pcall(function() cooked = food:isCooked() == true end)
    pcall(function() fresh = food:isFresh() ~= false end)
    pcall(function() burnt = food:isBurnt() == true end)
    if rotten then return ILL.FOOD_ROTTEN * (cooked and ILL.FOOD_COOKED or 1) end
    if raw and not cooked then return ILL.FOOD_RAW end
    if not fresh and not burnt then return ILL.FOOD_STALE end
    return 0
end
DanTraits_IllnessFoodRisk = foodRisk

-- the herbs in what was eaten: the item itself, or a spice or ingredient of a
-- hot drink or a dish
local function herbsIn(item)
    local out = {}
    local t
    pcall(function() t = string.lower(tostring(item:getType())) end)
    if t and HERBS[t] then out[#out + 1] = t end
    for _, getter in ipairs({ "getSpices", "getExtraItems" }) do
        pcall(function()
            local list = item[getter](item)
            if not list then return end
            for i = 0, list:size() - 1 do
                local full = string.lower(tostring(list:get(i)))
                local short = full:match("%.(.*)$") or full
                if HERBS[short] then out[#out + 1] = short end
            end
        end)
    end
    return out
end
DanTraits_IllnessHerbsIn = herbsIn

-- does this kind of relief touch anything running now
local function herbMatters(d, kind)
    for _, id in ipairs(ILL_ORDER) do
        local def, rec = ILLNESSES[id], d.ill[id]
        if rec and rec.len then
            if (kind == "nausea" and def.sick > 0) or (kind == "cramps" and def.gut)
                or (kind == "cold" and def.shows) or (kind == "ache" and def.pain > 0) then
                return true
            end
        end
    end
    return false
end

-- a herb's relief starts (or starts again); a weaker one leaves a stronger
-- one still working alone
local function takeHerbs(player, d, item)
    local found = herbsIn(item)
    if #found == 0 then return end
    local now = DanTraits_WorldHours()
    d.illHerb = d.illHerb or {}
    local helps = false
    for _, name in ipairs(found) do
        for _, kind in ipairs(HERB_KINDS) do
            local k = HERBS[name][kind]
            if k then
                local rec = d.illHerb[kind]
                if not rec or rec.to <= now or k <= rec.k then d.illHerb[kind] = { k = k, to = now + ILL.HERB_H } end
                if herbMatters(d, kind) then helps = true end
            end
        end
    end
    if helps then notifyGood(player, "UI_DanTraits_IllHerbHelps") end
end

DanTraits_AddHook("eat", function(_, player, item, fraction)
    if not player or not item or not sandboxOn() then return nil end
    local d = illData(player)
    takeHerbs(player, d, item)
    local k = resistance(player, false) * frequency() * math.min(1, tonumber(fraction) or 1)
    -- the stomach bug: what is on the hands goes down with the food
    local grime = handsGrime(player)
    if grime > ILL.STOMACH_FROM and roll(ILL.STOMACH_MEAL * grime * k) then catch(player, d, "stomach") end
    -- food poisoning: what the food itself carries
    local p = foodRisk(item)
    if p > 0 then
        if hasVanillaTrait(player, "base:irongut") then p = p * ILL.FOOD_IRON_GUT end
        if hasVanillaTrait(player, "base:weakstomach") then p = p * ILL.FOOD_WEAK end
        if roll(p * k) then catch(player, d, "food") end
    end
    return nil
end)

-- what the health panel reads ---------------------------------------------------

-- the illnesses running, in order: { id, kind, brewing, inH, day, rising, sev, leftH }
function DanTraits_IllnessState(player)
    local out = {}
    local d = player and player:getModData().DanTraits
    if not d or not d.ill or not sandboxOn() then return out end
    for _, id in ipairs(ILL_ORDER) do
        local rec, def = d.ill[id], ILLNESSES[id]
        if rec and rec.inc then
            out[#out + 1] = { id = id, kind = def.kind, brewing = true, inH = rec.inc / 60 }
        elseif rec and rec.len then
            out[#out + 1] = { id = id, kind = def.kind, day = math.floor(rec.t / 24) + 1,
                rising = rec.t / rec.len < def.peakAt, sev = rec.sev or 0, leftH = math.max(0, rec.len - rec.t) }
        end
    end
    return out
end

-- for other mods (DanTraits_API.lua): catch an illness by id, hidden for its
-- incubation, or with now = true start the symptoms at once. Returns true when
-- it took (nothing while it already runs, the body is immune, or it is off).
function DanTraits_IllnessCatch(player, id, now)
    if not player or not ILLNESSES[id] or not sandboxOn() then return false end
    local d = illData(player)
    if not catch(player, d, id) then return false end
    if now then onset(player, d, id) end
    return true
end

-- console ------------------------------------------------------------------------

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.ill = function(player, args)
    local d = illData(player)
    local id = args[1]
    if id == "clear" then
        d.ill, d.illImmune, d.illFever = {}, {}, 0
        driveCold(player, d)
        return "illnesses cleared"
    end
    if id and ILLNESSES[id] then
        d.ill[id], d.illImmune[id] = nil, nil
        if not catch(player, d, id) then return id .. " is switched off" end
        if args[2] == "now" then onset(player, d, id) end
        return id .. (args[2] == "now" and " started" or " caught, shows in " .. tostring(d.ill[id].inc) .. " min")
    end
    local parts = {}
    for _, key in ipairs(ILL_ORDER) do
        local rec = d.ill[key]
        if rec and rec.inc then parts[#parts + 1] = key .. " in " .. tostring(rec.inc) .. " min"
        elseif rec and rec.len then parts[#parts + 1] = key .. string.format(" %.0f/%.0f h sev %.2f fever %.2f", rec.t, rec.len, rec.sev or 0, rec.fev or 0) end
    end
    local now = DanTraits_WorldHours()
    for _, kind in ipairs(HERB_KINDS) do
        local h = d.illHerb and d.illHerb[kind]
        if h and h.to > now then parts[#parts + 1] = string.format("herb %s x%.2f %.1f h", kind, h.k, h.to - now) end
    end
    if #parts == 0 then return "ill [cold|flu|pneumonia|strep|stomach|food [now]] | ill clear: nothing running" end
    return table.concat(parts, "; ")
end

DanTraits_Every("minute", "Illness", updateIllnessMinute, 22.5)
