-- Project Zomboid Vitality Project: Heart Condition.
--
-- A weak heart that is pushed too hard. Strain (d.hcStrain, 0..1) builds
-- every minute from what the body is doing: endurance being spent, sprinting
-- and running, how winded you are while you keep at it (the vanilla Endurance moodle), panic from
-- half way up, carrying more than you can, cold air; and it drains at rest.
-- Age (the 40s and 50s; lower in the 20s), a smoking habit (the nicotine
-- meter), caffeine working, a Run Down body (Vitality), a stimulant overdose
-- (too many inhaler puffs or caffeine pills) and every heart attack already
-- survived make it build faster; beta blockers make it build slower. The
-- strain shows on the Chest Pain moodle from 0.4 (working hard) and 0.75
-- (pounding); at 1 it is chest pain (angina): 15 to 30 minutes of a pain
-- floor, endurance recovery at a third, no running or sprinting (the game's
-- Restricted Movement moodle on an attempt), and swings costing half as much
-- again. Resting (spending no endurance, not moving fast) lets it pass twice
-- as fast. Pushing on through it (spending endurance at Endurance moodle 2
-- or worse, trying to run or sprint, or swinging) risks a heart attack each
-- minute. A heart attack: you go down (the shared pass-out,
-- DanTraits_Faint.lua, deep: nothing wakes you) for 5 to 15 game minutes
-- with health lost, endurance emptied, and a week of recovery in three
-- stages: endurance comes back at x0.5 / x0.65 / x0.8, swings, sprinting
-- and running spend x1.5 / x1.3 / x1.15, melee weapons do x0.5 / x0.65 /
-- x0.8 damage (the Weak Heart moodle shows the stage). A second attack
-- within a day drops health to the floor. Each attack scars: strain builds a
-- fifth faster for good.
--
-- Beta blockers, the game's own pills (PillsBeta), are the daily medication,
-- kept by the shared medication system (DanTraits_Meds.lua): a pill a day
-- keeps them in the system, and as they build up over three days strain
-- builds half as fast and a heart attack is half as likely. While built up
-- endurance recovers a tenth slower, for anyone on them. A missed dose lets
-- them fade slowly, and you are told when they wear off. A new character
-- starts on them, built up half way, with one bottle, and a bottle of
-- nitroglycerin.
--
-- Nitroglycerin (DanTraits.Nitroglycerin) is the rescue drug: a tablet under
-- the tongue ends chest pain within a minute and takes half the strain off,
-- then half an hour of a headache. Two within an hour (the medication
-- system's overdose) and the blood pressure drops: faints.
--
-- Mod data: hcStrain (0..1), hcAnginaMin (minutes of chest pain left),
-- hcPushing (pushing on this minute), hcEndPrev (endurance a minute ago),
-- hcTried (tried to run or sprint since the last minute), hcWeakH (hours of
-- recovery left, 168 after an attack), hcAttacks (scars), hcLastAttackH
-- (world hours at the last attack), hcNitroMin (minutes of the nitroglycerin
-- headache left), hcEpisodes.
-- Console: heart | heart strain <0..1> | heart angina | heart attack | heart beta | heart nitro
require "DanTraits"
require "DanTraits_Meds"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local clamp01 = DanTraits_Clamp01
local fraction = DanTraits_StatFraction

-- strain built a minute (before the multipliers), by what the body is doing
local HC_SPEND         = 0.6     -- x endurance spent this minute (a hard minute of fighting spends about 0.1)
local HC_SPRINT        = 0.05    -- sprinting
local HC_RUN           = 0.02    -- running
local HC_WINDED        = 0.012   -- x the Endurance moodle level (1..4)
local HC_PANIC_AT      = 0.5     -- panic (0..1 of its range) over this...
local HC_PANIC         = 0.05    -- ...builds up to this at full panic
local HC_LOAD          = 0.02    -- carrying more than the character can
local HC_COLD_C        = 5       -- air under this, outdoors...
local HC_COLD          = 0.01    -- ...builds this
-- strain drained a minute
local HC_DRAIN_REST    = 0.08    -- resting: spending nothing, not running or sprinting (chest pain gone in 12 minutes from full)
local HC_DRAIN_LIGHT   = 0.03    -- light activity: spending, but the Endurance moodle is off
local HC_DRAIN_ASLEEP  = 0.1
local HC_ENDURANCE_AT  = { 0.75, 0.5, 0.25, 0.1 }  -- endurance under which each moodle level shows (if the moodle cannot be read)
-- multipliers on the build
local HC_SMOKER        = 0.5     -- x (1 + this x nicotine meter)
local HC_CAFFEINE      = 1.3     -- while caffeine is working (Sleep's six-hour clock)
local HC_STIM_OVER     = 2       -- while too many inhaler puffs or caffeine pills are in the system (DanTraits_Meds.lua)
local HC_VITALITY      = 0.3     -- x (1 - this x Vitality effect, -1..1)
local HC_SCAR          = 0.2     -- x (1 + this x heart attacks survived)
local HC_BETA_CUT      = 0.5     -- strain build and heart attacks x this, fully built up
local HC_BETA_REGEN    = 0.1     -- endurance recovery x (1 - this x built), anyone on beta blockers
-- the moodle and chest pain
local HC_WORKING       = 0.4     -- Chest Pain moodle 1 from this strain...
local HC_POUNDING      = 0.75    -- ...2 from this...
local HC_PAIN_AT       = 1       -- ...and chest pain at this
local HC_PAIN_RESET    = 0.8     -- strain after chest pain starts (a second bout needs more pushing, not a fresh start)
local HC_ANGINA_MIN    = { 15, 30 }  -- minutes of chest pain
local HC_REST_FASTER   = 2       -- minutes of chest pain gone per minute at rest
local HC_PUSH_LEVEL    = 2       -- spending endurance at this Endurance moodle level or worse is pushing on
local HC_PAIN          = 40      -- pain floor during chest pain
local HC_PAIN_RAMP     = 5
local HC_REGEN         = 0.33    -- endurance recovery x this during chest pain
local HC_PAIN_SWING    = 1.5     -- a swing spends x this during chest pain
local HC_ATTACK_MIN    = 0.08    -- chance a minute of a heart attack, pushing on through chest pain
-- a heart attack
local HC_ATTACK_OUT    = { 5, 15 }   -- game minutes down
local HC_ATTACK_HP     = 15      -- health lost...
local HC_HEALTH_FLOOR  = 10      -- ...never below this; a second attack within HC_SECOND_H goes straight to it
local HC_SECOND_H      = 24
local HC_ATTACK_SAD    = 30      -- unhappiness added
local HC_ATTACK_STRAIN = 0.5     -- strain after an attack
local HC_WEAK_H        = 168     -- a week of recovery, in three stages of HC_WEAK_H / 3
local HC_WEAK          = {       -- by stage (1 the first days): endurance recovery x, spending x, melee damage x,
    { regen = 0.5, spend = 1.5, damage = 0.5, attack = 2 },        -- and the chance of another attack through chest pain x
    { regen = 0.65, spend = 1.3, damage = 0.65, attack = 1.5 },    -- (2026-10-09: in play a second attack was slow to come
    { regen = 0.8, spend = 1.15, damage = 0.8, attack = 1.25 },    -- for a heart that had just failed)
}
-- nitroglycerin
local HC_NITRO_STRAIN  = 0.5     -- strain x this
local HC_NITRO_HEAD_MIN = 30     -- minutes of headache after
local HC_NITRO_HEAD_PAIN = 15    -- its pain floor
local HC_KIT_BETA      = 1       -- bottles of beta blockers a new character starts with (and one of nitroglycerin)
local HC_KIT_BUILT     = 0.5     -- how built up the beta blockers are at the start

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

-- strain build and heart attacks x this: down to HC_BETA_CUT as beta blockers build up
local function betaCut(player)
    local built = DanTraits_MedEffect and DanTraits_MedEffect(player, "beta") or 0
    return 1 - (1 - HC_BETA_CUT) * built
end

local function flag(player, method)
    local ok, res = pcall(function() return player[method](player) end)
    return ok and res == true
end

-- what the strain builds at this minute, x this (age, habits, the body, the scars, the pills)
local function strainRate(player, d)
    local rate = 1
    if DanTraits_AgeHeart then rate = rate * DanTraits_AgeHeart(player) end
    if DanTraits_IsSmoker and DanTraits_IsSmoker(player) then rate = rate * (1 + HC_SMOKER * clamp01(d.nicMeter or 0)) end
    if (d.slCaffeineHours or 0) > 0 then rate = rate * HC_CAFFEINE end
    if DanTraits_MedHeartStrain and DanTraits_MedHeartStrain(player) then rate = rate * HC_STIM_OVER end
    if DanTraits_VitalityEffect then rate = rate * (1 - HC_VITALITY * (tonumber(DanTraits_VitalityEffect(player)) or 0)) end   -- -1..1, so not DanTraits_Strength
    rate = rate * (1 + HC_SCAR * (d.hcAttacks or 0))
    rate = rate * betaCut(player)
    return math.max(0, rate)
end
DanTraits_HeartStrainRate = strainRate

local function overloaded(player)
    local over = false
    pcall(function()
        local inv = player:getInventory()
        over = inv:getCapacityWeight() > player:getMaxWeight()
    end)
    return over
end

-- the strain this minute builds (before strainRate), from what the body did
local function strainBuild(player, d, spent, level, moving)
    local build = HC_SPEND * spent
    local working = spent > 1e-6 or moving.sprint or moving.run
    if working then build = build + HC_WINDED * level end   -- winded AND still at it; standing still winded is rest
    if moving.sprint then build = build + HC_SPRINT elseif moving.run then build = build + HC_RUN end
    local panic = fraction(player:getStats(), CharacterStat.PANIC)
    if panic > HC_PANIC_AT then build = build + HC_PANIC * (panic - HC_PANIC_AT) / (1 - HC_PANIC_AT) end
    if overloaded(player) then build = build + HC_LOAD end
    if DanTraits_AirTemp and flag(player, "isOutside") then
        local temp = DanTraits_AirTemp(player)
        if temp and temp < HC_COLD_C then build = build + HC_COLD end
    end
    return build
end

-- the week after an attack: 0 none, 1 the first days (worst), 2, 3 the last
function DanTraits_HeartWeakStage(player, d)
    d = d or (player and DanTraits_Data(player))
    local h = d and d.hcWeakH or 0
    if h <= 0 then return 0 end
    local third = HC_WEAK_H / 3
    if h > 2 * third then return 1 elseif h > third then return 2 end
    return 3
end
local function weak(player, d)
    local stage = DanTraits_HeartWeakStage(player, d)
    return stage > 0 and HC_WEAK[stage] or nil
end

local function startAngina(player, d)
    d.hcAnginaMin = randRange(HC_ANGINA_MIN[1], HC_ANGINA_MIN[2])
    d.hcStrain = math.min(d.hcStrain or 0, HC_PAIN_RESET)
    d.hcEpisodes = (d.hcEpisodes or 0) + 1
    notify(player, "UI_DanTraits_HeartChestPain")
end

local function worldHours()
    local h = 0
    pcall(function() h = getGameTime():getWorldAgeHours() or 0 end)
    return h
end

local function heartAttack(player, d)
    d.hcAnginaMin = 0
    d.hcStrain = HC_ATTACK_STRAIN
    d.hcWeakH = HC_WEAK_H
    d.hcAttacks = (d.hcAttacks or 0) + 1
    local now = worldHours()
    local second = d.hcLastAttackH and (now - d.hcLastAttackH) < HC_SECOND_H
    d.hcLastAttackH = now
    local stats = player:getStats()
    pcall(function() stats:set(CharacterStat.ENDURANCE, 0) end)
    DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, HC_ATTACK_SAD)
    pcall(function()
        local bd = player:getBodyDamage()
        local room = (bd:getOverallBodyHealth() or 0) - HC_HEALTH_FLOOR
        if room > 0 then bd:ReduceGeneralHealth(second and room or math.min(HC_ATTACK_HP, room)) end
    end)
    notify(player, second and "UI_DanTraits_HeartAttackAgain" or "UI_DanTraits_HeartAttack")
    if DanTraits_PassOut then
        DanTraits_PassOut(player, randRange(HC_ATTACK_OUT[1], HC_ATTACK_OUT[2]), "UI_DanTraits_HeartComeRound", true)
    end
end

-- what the character did this minute: how much endurance went, whether they
-- are pushing (sprinting, trying to, or endurance fell at a deep Endurance
-- moodle) and resting (neither spending endurance nor moving fast)
local function exertion(player, d)
    local endurance = 1
    pcall(function() endurance = player:getStats():get(CharacterStat.ENDURANCE) or 1 end)
    local spent = math.max(0, (d.hcEndPrev or endurance) - endurance)
    d.hcEndPrev = endurance
    local moving = { sprint = flag(player, "isSprinting") or d.hcTried == "sprint", run = flag(player, "isRunning") or d.hcTried == "run" }
    d.hcTried = nil
    local level = enduranceLevel(player)
    local pushing = moving.sprint or (spent > 1e-6 and level >= HC_PUSH_LEVEL) or (d.hcAnginaMin or 0) > 0 and (moving.run or flag(player, "isAttacking"))
    local resting = spent <= 1e-6 and not moving.sprint and not moving.run
    return spent, level, moving, pushing, resting
end

-- (the wearing-off notice is the medication system's: beta's lapse in DanTraits_Meds.lua)
local function updateHeartMinute(player, d)
    if (d.hcWeakH or 0) > 0 then
        local before = DanTraits_HeartWeakStage(player, d)
        d.hcWeakH = math.max(0, d.hcWeakH - 1 / 60)
        local after = DanTraits_HeartWeakStage(player, d)
        if after ~= before then DanTraits_NotifyGood(player, after == 0 and "UI_DanTraits_HeartRecovered" or "UI_DanTraits_HeartStronger") end
    end
    if (d.hcNitroMin or 0) > 0 then
        d.hcNitroMin = d.hcNitroMin - 1
        DanTraits_PainFloor(player, d, "nitro", HC_NITRO_HEAD_PAIN, HC_PAIN_RAMP)
    end
    if not hasTrait(player, "heart") then
        d.hcStrain, d.hcAnginaMin, d.hcPushing, d.hcEndPrev, d.hcTried = nil, nil, nil, nil, nil
        return
    end
    local spent, level, moving, pushing, resting = exertion(player, d)
    d.hcPushing = nil
    if DanTraits_IsPassedOut and DanTraits_IsPassedOut(player) then return end
    local asleep = DanTraits_Asleep(player)
    local strain = d.hcStrain or 0
    local build = asleep and 0 or strainBuild(player, d, spent, level, moving)
    if build > 0 then
        strain = strain + build * strainRate(player, d)
    else
        strain = strain - (asleep and HC_DRAIN_ASLEEP or (resting and HC_DRAIN_REST or HC_DRAIN_LIGHT))
    end
    d.hcStrain = clamp01(strain)
    if (d.hcAnginaMin or 0) > 0 then
        DanTraits_PainFloor(player, d, "heart", HC_PAIN, HC_PAIN_RAMP)
        if pushing then
            d.hcPushing = true
            local stage = weak(player, d)
            if DanTraits_Roll(HC_ATTACK_MIN * betaCut(player) * (stage and stage.attack or 1)) then
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
    if d.hcStrain >= HC_PAIN_AT then startAngina(player, d) end
end

-- per frame (the local, living player): no running or sprinting through chest
-- pain, as Blood Loss does it (the game's Restricted Movement moodle only on
-- an attempt, or the icon blinks); swings cost more through chest pain, and
-- everything costs more in the week after an attack: the extra is taken off
-- as it is spent, and the delta pipeline is told so it is not read as recovery
local function updateHeartFrame(player, d)
    local angina = hasTrait(player, "heart") and (d.hcAnginaMin or 0) > 0
    local stage = weak(player, d)
    if not angina and not stage then d.hcEndFrame = nil return end
    if angina then
        local triedSprint, triedRun = flag(player, "isSprinting"), flag(player, "isRunning")
        if triedSprint then pcall(function() player:setSprinting(false) end) end
        if triedRun then pcall(function() player:setRunning(false) end) end
        if triedSprint or triedRun then
            d.hcTried = triedSprint and "sprint" or "run"
            pcall(function() player:setMoodleCantSprint(true) end)
        end
    end
    local stats = player:getStats()
    local now = tonumber(stats:get(CharacterStat.ENDURANCE))
    if not now then return end
    local was = d.hcEndFrame
    if was and now < was then
        local working = flag(player, "isAttacking") or flag(player, "isSprinting") or flag(player, "isRunning")
        if working then
            local mult = (stage and stage.spend or 1) * (angina and flag(player, "isAttacking") and HC_PAIN_SWING or 1)
            if mult > 1 then
                local extra = (was - now) * (mult - 1)
                DanTraits_StatAdd(stats, CharacterStat.ENDURANCE, -extra)
                now = math.max(0, now - extra)
                DanTraits_DeltaRemember(d, "enduranceRegen", now)
            end
        end
    end
    d.hcEndFrame = now
end

-- melee does less in the week after an attack (Arthritis owns the weaken-and-restore)
local function onHeartSwing(player, weapon)
    if not weapon or not player or player ~= getSpecificPlayer(0) or not DanTraits_WeakenWeapon then return end
    local d = DanTraits_Data(player)
    local stage = weak(player, d)
    if stage then DanTraits_WeakenWeapon(player, weapon, stage.damage) end
end

-- endurance recovers slower during chest pain, in the week after an attack,
-- and a tenth slower on beta blockers (anyone), through the stat delta pipeline
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    local k = 1
    if hasTrait(player, "heart") and (d.hcAnginaMin or 0) > 0 then k = k * HC_REGEN end
    local stage = weak(player, d)
    if stage then k = k * stage.regen end
    local built = DanTraits_MedEffect and DanTraits_MedEffect(player, "beta") or 0
    if built > 0 then k = k * (1 - HC_BETA_REGEN * built) end
    if k == 1 then return nil end
    return delta * k
end)

-- nitroglycerin: the chest pain ends within a minute and half the strain goes; then the headache
DanTraits_AddHook("pill", function(_, player, kind)
    if string.lower(tostring(kind or "")) ~= "nitroglycerin" or not player then return nil end
    local d = DanTraits_Data(player)
    if (d.hcAnginaMin or 0) > 0 then d.hcAnginaMin = math.min(d.hcAnginaMin, 1) end
    d.hcStrain = (d.hcStrain or 0) * HC_NITRO_STRAIN
    d.hcNitroMin = HC_NITRO_HEAD_MIN
    DanTraits_NotifyGood(player, "UI_DanTraits_HeartNitro")
    return nil
end)

-- 0..1 how strained the heart is now (the dashboard, other systems)
function DanTraits_HeartStrain(player)
    local d = player and DanTraits_Data(player)
    return d and d.hcStrain or 0
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.heart = function(player, args)
    local d = DanTraits_Data(player)
    if args[1] == "angina" then startAngina(player, d) return "heart angina" end
    if args[1] == "attack" then heartAttack(player, d) return "heart attack" end
    if args[1] == "beta" then DanTraits_MedTake(player, "beta", 1) return "heart beta: level " .. tostring(DanTraits_MedState(player, "beta")) end
    if args[1] == "nitro" then DanTraits_RunHooks("pill", nil, player, "Nitroglycerin") return "heart nitro" end
    if args[1] == "strain" and tonumber(args[2]) then d.hcStrain = clamp01(tonumber(args[2])) return "heart strain " .. tostring(d.hcStrain) end
    return "heart: strain " .. tostring(DanTraits_Round(d.hcStrain or 0, 3)) .. " (x" .. tostring(DanTraits_Round(strainRate(player, d), 2)) .. " a minute), chest pain "
        .. tostring(d.hcAnginaMin or 0) .. " min, recovery stage " .. tostring(DanTraits_HeartWeakStage(player, d)) .. " (" .. tostring(DanTraits_Round(d.hcWeakH or 0, 1)) .. " h), attacks "
        .. tostring(d.hcAttacks or 0) .. " | heart strain <0..1> | heart angina | heart attack | heart beta | heart nitro"
end

-- a new character has lived with it: a bottle of beta blockers (the Starting
-- Medication option) and the pills built up half way, a bottle of
-- nitroglycerin, once
local HC_KIT = {}
for _ = 1, HC_KIT_BETA do HC_KIT[#HC_KIT + 1] = "Base.PillsBeta" end
HC_KIT[#HC_KIT + 1] = "DanTraits.Nitroglycerin"
DanTraits_StartingKit({
    trait = "heart", flag = "hcKitGiven", items = HC_KIT,
    setup = function(player, d)
        if not DanTraits_MedStart then return end
        DanTraits_MedStart(player, "beta")
        if d.meds and d.meds.beta then d.meds.beta.built = HC_KIT_BUILT end
    end,
    prepare = function(item) pcall(function() item:getModData().DanTraitsFilled = true end) end,   -- full bottles, not the random spawn fill
})

DanTraits_Every("minute", "Heart", updateHeartMinute, 40)
DanTraits_Every("frame", "Heart", updateHeartFrame, 40)
Events.OnWeaponSwing.Add(onHeartSwing)
