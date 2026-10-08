-- Project Zomboid Vitality Project: Heart Condition.
--
-- A weak heart that only shows itself under strain. Nothing can happen while
-- the vanilla Endurance moodle (the lungs) is off: every minute it shows, there
-- is a chance of chest pain (angina), higher the deeper the moodle, and higher
-- again when panicking, with age (the 40s and 50s; lower in the 20s), for a smoker (by the nicotine meter), with
-- caffeine working, and for a Run Down body (Vitality; Fit and Thriving lower
-- it); twice as likely with too many inhaler puffs or caffeine pills in you. Chest pain lasts 15 to 30 minutes: a pain floor, and endurance recovers
-- at a third of the speed (the enduranceRegen hook of the stat delta
-- pipeline). Resting (spending no endurance, not running) lets it pass twice
-- as fast. Pushing on through it risks a heart attack. Pushing is what you do,
-- not how worn out you are: sprinting, or still spending endurance while the
-- Endurance moodle is at 2 or more (the same reading of exertion as Asthma:
-- endurance being spent, not endurance being low; chest pain itself slows the
-- recovery, so a low moodle alone would leave no way to rest it off). A heart
-- attack: you go down (the shared pass-out, DanTraits_Faint.lua, deep: nothing
-- wakes you) for 5 to 15 game minutes with health lost, endurance emptied, and
-- a day after of weak recovery.
--
-- Beta blockers, the game's own pills (PillsBeta), are the daily medication,
-- kept by the shared medication system (DanTraits_Meds.lua): a pill a day
-- keeps them in the system, and as they build up over three days, chest pain
-- and heart attacks fall to a quarter as likely. A missed dose lets them fade
-- slowly, and you are told when they wear off. A new character starts on
-- them, fully built up, with two bottles.
--
-- Mod data: hcCovered (the beta blockers were in the system, for the
-- wearing-off notice), hcAnginaMin (minutes of chest pain left), hcPushing
-- (pushing on this minute), hcEndPrev (endurance a minute ago), hcWeakH (hours
-- of weak recovery left), hcAttacks, hcEpisodes.
-- Console: heart angina | heart attack | heart beta
require "DanTraits"
require "DanTraits_Meds"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local clamp01 = DanTraits_Clamp01
local fraction = DanTraits_StatFraction

local HC_EPISODE_MIN   = { 0.002, 0.005, 0.015, 0.03 }  -- chance a minute of chest pain, Endurance moodle 1..4
local HC_ENDURANCE_AT  = { 0.75, 0.5, 0.25, 0.1 }      -- endurance under which each moodle level shows (if the moodle cannot be read)
local HC_PANIC_AT      = 0.5     -- panic (0..1 of its range) over this...
local HC_PANIC         = 1.5     -- ...x this
local HC_SMOKER        = 0.5     -- x (1 + this x nicotine meter)
local HC_CAFFEINE      = 1.3     -- while caffeine is working (Sleep's six-hour clock)
local HC_STIM_OVER     = 2       -- while too many inhaler puffs or caffeine pills are in the system (DanTraits_Meds.lua)
local HC_VITALITY      = 0.3     -- x (1 - this x Vitality effect, -1..1)
local HC_ANGINA_MIN    = { 15, 30 }  -- minutes of chest pain
local HC_REST_FASTER   = 2       -- minutes of chest pain gone per minute at rest
local HC_PUSH_LEVEL    = 2       -- spending endurance at this Endurance moodle level or worse is pushing on
local HC_PAIN          = 40      -- pain floor during chest pain
local HC_PAIN_RAMP     = 5
local HC_REGEN         = 0.33    -- endurance recovery x this during chest pain...
local HC_WEAK_REGEN    = 0.6     -- ...and x this for a day after a heart attack
local HC_WEAK_H        = 24
local HC_ATTACK_MIN    = 0.08    -- chance a minute of a heart attack, pushing on through chest pain
local HC_ATTACK_OUT    = { 5, 15 }   -- game minutes down
local HC_ATTACK_HP     = 15      -- health lost...
local HC_HEALTH_FLOOR  = 10      -- ...never below this
local HC_ATTACK_SAD    = 30      -- unhappiness added
local HC_BETA_CUT      = 0.25    -- chest pain and heart attacks x this, fully built up
local HC_KIT_BOTTLES   = 2       -- bottles a new character starts with

local randRange = DanTraits_RandRange

-- 0..4: the vanilla Endurance moodle, or its level from the stat
local function enduranceLevel(player)
    local level
    if MoodleType and MoodleType.ENDURANCE then
        pcall(function() level = player:getMoodles():getMoodleLevel(MoodleType.ENDURANCE) end)
    end
    if type(level) == "number" then return level end
    local endurance = 1
    pcall(function() endurance = player:getStats():get(CharacterStat.ENDURANCE) or 1 end)
    level = 0
    for i, at in ipairs(HC_ENDURANCE_AT) do if endurance < at then level = i end end
    return level
end

-- chest pain and heart attacks x this: down to HC_BETA_CUT as beta blockers build up
local function betaCut(player)
    local effect = DanTraits_MedEffect and DanTraits_MedEffect(player, "beta") or 0
    return 1 - (1 - HC_BETA_CUT) * effect
end

-- chance a minute of chest pain now, 0 when the moodle is off
local function episodeChance(player, d)
    local level = enduranceLevel(player)
    if level <= 0 then return 0 end
    local chance = HC_EPISODE_MIN[math.min(level, #HC_EPISODE_MIN)]
    if fraction(player:getStats(), CharacterStat.PANIC) > HC_PANIC_AT then chance = chance * HC_PANIC end
    if DanTraits_AgeHeart then chance = chance * DanTraits_AgeHeart(player) end
    if DanTraits_IsSmoker and DanTraits_IsSmoker(player) then chance = chance * (1 + HC_SMOKER * clamp01(d.nicMeter or 0)) end
    if (d.slCaffeineHours or 0) > 0 then chance = chance * HC_CAFFEINE end
    if DanTraits_MedHeartStrain and DanTraits_MedHeartStrain(player) then chance = chance * HC_STIM_OVER end
    if DanTraits_VitalityEffect then chance = chance * (1 - HC_VITALITY * (tonumber(DanTraits_VitalityEffect(player)) or 0)) end   -- -1..1, so not DanTraits_Strength
    chance = chance * betaCut(player)
    return math.max(0, chance)
end
DanTraits_HeartEpisodeChance = episodeChance

local function startAngina(player, d)
    d.hcAnginaMin = randRange(HC_ANGINA_MIN[1], HC_ANGINA_MIN[2])
    d.hcEpisodes = (d.hcEpisodes or 0) + 1
    notify(player, "UI_DanTraits_HeartChestPain")
end

local function heartAttack(player, d)
    d.hcAnginaMin = 0
    d.hcWeakH = HC_WEAK_H
    d.hcAttacks = (d.hcAttacks or 0) + 1
    local stats = player:getStats()
    pcall(function() stats:set(CharacterStat.ENDURANCE, 0) end)
    DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, HC_ATTACK_SAD)
    pcall(function()
        local bd = player:getBodyDamage()
        local room = (bd:getOverallBodyHealth() or 0) - HC_HEALTH_FLOOR
        if room > 0 then bd:ReduceGeneralHealth(math.min(HC_ATTACK_HP, room)) end
    end)
    notify(player, "UI_DanTraits_HeartAttack")
    if DanTraits_PassOut then
        DanTraits_PassOut(player, randRange(HC_ATTACK_OUT[1], HC_ATTACK_OUT[2]), "UI_DanTraits_HeartComeRound", true)
    end
end

local function flag(player, method)
    local ok, res = pcall(function() return player[method](player) end)
    return ok and res == true
end

-- what the character did this minute: pushing (sprinting, or endurance fell
-- since the last minute at a deep Endurance moodle) and resting (neither
-- spending endurance nor running)
local function exertion(player, d)
    local endurance = 1
    pcall(function() endurance = player:getStats():get(CharacterStat.ENDURANCE) or 1 end)
    local spending = endurance < (d.hcEndPrev or endurance) - 1e-6
    d.hcEndPrev = endurance
    local sprinting = flag(player, "isSprinting")
    local pushing = sprinting or (spending and enduranceLevel(player) >= HC_PUSH_LEVEL)
    local resting = not spending and not sprinting and not flag(player, "isRunning")
    return pushing, resting
end

-- the wearing-off notice, once each time the level drops under protection
local function betaNotice(player, d)
    local covered = DanTraits_MedCovered and DanTraits_MedCovered(player, "beta") or false
    if d.hcCovered and not covered and hasTrait(player, "heart") then notify(player, "UI_DanTraits_HeartBetaLapse") end
    d.hcCovered = covered or nil
end

local function updateHeartMinute(player, d)
    if (d.hcWeakH or 0) > 0 then d.hcWeakH = math.max(0, d.hcWeakH - 1 / 60) end
    if not hasTrait(player, "heart") then
        d.hcAnginaMin, d.hcPushing, d.hcEndPrev, d.hcCovered = nil, nil, nil, nil
        return
    end
    betaNotice(player, d)
    local pushing, resting = exertion(player, d)
    d.hcPushing = nil
    if DanTraits_IsPassedOut and DanTraits_IsPassedOut(player) then return end
    if (d.hcAnginaMin or 0) > 0 then
        DanTraits_PainFloor(player, d, "heart", HC_PAIN, HC_PAIN_RAMP)
        if pushing then
            d.hcPushing = true
            if DanTraits_Roll(HC_ATTACK_MIN * betaCut(player)) then
                heartAttack(player, d)
                return
            end
            d.hcAnginaMin = d.hcAnginaMin - 1
        else
            d.hcAnginaMin = d.hcAnginaMin - (resting and HC_REST_FASTER or 1)
        end
        if d.hcAnginaMin <= 0 then
            d.hcAnginaMin = 0
            DanTraits_NotifyGood(player, "UI_DanTraits_HeartEased")
        end
        return
    end
    if DanTraits_Roll(episodeChance(player, d)) then startAngina(player, d) end
end

-- endurance recovers slower during chest pain, and for a day after an attack
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d then return nil end
    local k = 1
    if (d.hcAnginaMin or 0) > 0 then k = k * HC_REGEN end
    if (d.hcWeakH or 0) > 0 then k = k * HC_WEAK_REGEN end
    if k == 1 then return nil end
    return delta * k
end)

local function betaTaken(player)
    local d = DanTraits_Data(player)
    d.hcCovered = DanTraits_MedCovered(player, "beta") or nil
    if hasTrait(player, "heart") then DanTraits_NotifyGood(player, "UI_DanTraits_HeartBeta") end
end

-- a dose by hand (the console); a swallowed pill reaches the medication system itself
function DanTraits_TakeBetaBlocker(player, amount)
    local level = DanTraits_MedTake(player, "beta", amount or 1)
    betaTaken(player)
    return level
end

-- after the medication system has taken the dose (it loads first)
DanTraits_AddHook("pill", function(_, player, kind)
    if DanTraits_DrugOfItem(kind) == "beta" then betaTaken(player) end
    return nil
end)

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.heart = function(player, args)
    local d = DanTraits_Data(player)
    if args[1] == "angina" then startAngina(player, d) return "chest pain for " .. tostring(math.floor(d.hcAnginaMin)) .. " minutes" end
    if args[1] == "attack" then heartAttack(player, d) return "heart attack" end
    if args[1] == "beta" then return "beta blocker level " .. tostring(DanTraits_TakeBetaBlocker(player, 1)) end
    return "heart angina | heart attack | heart beta (chest pain chance now " .. tostring(episodeChance(player, d)) .. ")"
end

-- start on beta blockers, fully built up, with two bottles (none if the
-- Starting Medication sandbox option is off)
local HC_KIT = {}
for _ = 1, HC_KIT_BOTTLES do HC_KIT[#HC_KIT + 1] = "Base.PillsBeta" end
DanTraits_StartingKit({ trait = "heart", flag = "hcKitGiven", meds = { "beta" }, items = HC_KIT })

DanTraits_Every("minute", "Heart", updateHeartMinute, 40)
