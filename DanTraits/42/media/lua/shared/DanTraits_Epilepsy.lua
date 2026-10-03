-- Project Zomboid Vitality Project: Epilepsy.
--
-- Seizures. Well rested, sober, well and calm, one comes about once in eight
-- days; the triggers multiply that: tiredness (the Tired moodle's range,
-- hardest near exhaustion), alcohol withdrawal and a hangover, a fever (wound
-- infection), a concussion, stress, dehydration, a diabetic low, and bright
-- daylight on a sensitive brain.
-- Anticonvulsants (a pill bottle of this mod's, found with the other
-- prescriptions) are the answer, kept by the shared medication system
-- (DanTraits_Meds.lua): a pill every 12 hours keeps them in the system, and as
-- they build up over five days seizures fall to a tenth as likely. A missed
-- dose lets them fade slowly, and you are told when they wear off. A new
-- character starts on them, fully built up, with a bottle.
--
-- A seizure gives a warning (an aura: a notice, then five to ten game
-- minutes and never under 30 real seconds, time to get out of a fight or
-- stop the car; at the wheel regardless, the engine cuts out, see
-- DanTraits_Faint.lua). Then you drop
-- whatever is in your hands and go down (the shared pass-out,
-- DanTraits_Faint.lua, deep: nothing wakes you) for 2 to 5 game minutes, can
-- knock your head (a concussion, DanTraits_Concussion.lua), and come round
-- confused and exhausted: an hour of headache and low mood. Asleep there is
-- no warning and no fall: the seizure wakes you, aching and worn out, and the
-- night scores worse. One that comes while you are already out cold (a faint,
-- a knockout) is only the aftermath.
--
-- Mod data: epCovered (the anticonvulsants were in the system, for the
-- wearing-off notice), epAuraMin (minutes to the seizure), epAuraMs (the real-time
-- floor on that warning), epAfterMin (minutes
-- of the aftermath), epSeizures, epNight (a seizure broke this sleep).
-- Console: epilepsy seize | epilepsy aura | epilepsy pill
require "DanTraits"
require "DanTraits_Meds"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local clamp01 = DanTraits_Clamp01
local fraction = DanTraits_StatFraction

local EP_BASE_H        = 1 / 192 -- seizures an hour with nothing bringing one on (one in eight days)
local EP_TIRED_FROM    = 0.5     -- tiredness (0..1) from which it counts...
local EP_TIRED         = 8       -- ...x (1 + this x how far past it, 0..1)
local EP_WITHDRAWAL    = 6       -- x (1 + this x alcohol withdrawal)
local EP_HANGOVER      = 2       -- x (1 + this x hangover)
local EP_FEVER         = 4       -- x (1 + this x fever)
local EP_CONCUSSION    = 5       -- x (1 + this x concussion)
local EP_STRESS        = 1       -- x (1 + this x stress)
local EP_DEHYDRATION   = 2       -- x (1 + this x dehydration)
local EP_LOW_SUGAR     = 3       -- x (1 + this x how bad a diabetic low is)
local EP_BRIGHT        = 1.5     -- in bright daylight
local EP_MEDS_CUT      = 0.1     -- seizures x this, fully built up
local EP_AURA_MIN      = { 5, 10 }   -- game minutes of warning before the seizure...
local EP_AURA_REAL_S   = 30      -- ...but never under this many real seconds (the default day passes 5 game minutes in about 12)
local EP_NIGHT_CUT     = 0.3     -- a night broken by a seizure scores x (1 - this)
local EP_OUT_MIN       = { 2, 5 }    -- game minutes down
local EP_KNOCK         = 0.25    -- chance the fall knocks the head...
local EP_KNOCK_SCORE   = 0.3     -- ...this hard (concussion score)
local EP_PAIN_BURST    = 20
local EP_FATIGUE       = 0.3     -- tiredness added
local EP_AFTER_MIN     = 60      -- the aftermath
local EP_AFTER_PAIN    = 25      -- pain floor through it
local EP_AFTER_SAD     = 30      -- unhappiness floor through it
local EP_MEDS_ITEM     = "DanTraits.Anticonvulsants"

local function num(fn)
    local v = 0
    pcall(function() v = fn() or 0 end)
    return tonumber(v) or 0
end

-- seizures x this: down to EP_MEDS_CUT as anticonvulsants build up
local function medsCut(player)
    local effect = DanTraits_MedEffect and DanTraits_MedEffect(player, "anticonvulsant") or 0
    return 1 - (1 - EP_MEDS_CUT) * effect
end

-- seizures an hour now
local function seizureRate(player, d)
    local stats = player:getStats()
    local rate = EP_BASE_H
    local tired = fraction(stats, CharacterStat.FATIGUE)
    if tired > EP_TIRED_FROM then rate = rate * (1 + EP_TIRED * (tired - EP_TIRED_FROM) / (1 - EP_TIRED_FROM)) end
    if DanTraits_AlcoholWithdrawal then rate = rate * (1 + EP_WITHDRAWAL * clamp01(num(function() return DanTraits_AlcoholWithdrawal(player) end))) end
    if DanTraits_HangoverStrength then rate = rate * (1 + EP_HANGOVER * clamp01(num(function() return DanTraits_HangoverStrength(player) end))) end
    if DanTraits_InfectionFever then rate = rate * (1 + EP_FEVER * clamp01(num(function() return DanTraits_InfectionFever(player) end))) end
    if DanTraits_ConcussionStrength then rate = rate * (1 + EP_CONCUSSION * clamp01(num(function() return DanTraits_ConcussionStrength(player) end))) end
    rate = rate * (1 + EP_STRESS * fraction(stats, CharacterStat.STRESS))
    if DanTraits_Dehydration then rate = rate * (1 + EP_DEHYDRATION * clamp01(num(function() return DanTraits_Dehydration(player) end))) end
    if DanTraits_DiaLow then rate = rate * (1 + EP_LOW_SUGAR * clamp01(num(function() return DanTraits_DiaLow(player) end))) end
    if DanTraits_InBrightLight then
        local ok, bright = pcall(DanTraits_InBrightLight, player)
        if ok and bright then rate = rate * EP_BRIGHT end
    end
    rate = rate * medsCut(player)
    return rate
end
DanTraits_SeizureRate = seizureRate

local function aura(player, d)
    d.epAuraMin = math.floor(DanTraits_RandRange(EP_AURA_MIN[1], EP_AURA_MIN[2] + 1))
    -- asleep you feel nothing coming (and there is nothing to get clear of)
    if DanTraits_Asleep(player) then return end
    pcall(function() d.epAuraMs = getTimestampMs() + EP_AURA_REAL_S * 1000 end)
    notify(player, "UI_DanTraits_EpilepsyAura")
end

local function seize(player, d)
    d.epAuraMin, d.epAuraMs = nil, nil
    d.epSeizures = (d.epSeizures or 0) + 1
    d.epAfterMin = EP_AFTER_MIN
    local stats = player:getStats()
    if DanTraits_Asleep(player) then
        -- in bed: no fall, nothing dropped; it wakes you and spoils the night
        d.epNight = true
        if DanTraits_PainBurst then DanTraits_PainBurst(player, EP_PAIN_BURST) end
        DanTraits_StatAdd(stats, CharacterStat.FATIGUE, EP_FATIGUE)
        pcall(function() player:forceAwake() end)
        notify(player, "UI_DanTraits_EpilepsyNight")
        return
    end
    if DanTraits_IsPassedOut and DanTraits_IsPassedOut(player) then
        -- already out cold: nothing more to fall from
        DanTraits_StatAdd(stats, CharacterStat.FATIGUE, EP_FATIGUE)
        return
    end
    if DanTraits_FumbleDrop then pcall(DanTraits_FumbleDrop, player) end
    if DanTraits_KnockHead then pcall(DanTraits_KnockHead, player, EP_KNOCK, EP_KNOCK_SCORE) end
    if DanTraits_PainBurst then DanTraits_PainBurst(player, EP_PAIN_BURST) end
    DanTraits_StatAdd(stats, CharacterStat.FATIGUE, EP_FATIGUE)
    notify(player, "UI_DanTraits_EpilepsySeizure")
    if DanTraits_PassOut then
        DanTraits_PassOut(player, DanTraits_RandRange(EP_OUT_MIN[1], EP_OUT_MIN[2]), "UI_DanTraits_EpilepsyComeRound", true)
    elseif DanTraits_Collapse then
        DanTraits_Collapse(player)
    end
end

-- the wearing-off notice, once each time the level drops under protection
local function medsNotice(player, d)
    local covered = DanTraits_MedCovered and DanTraits_MedCovered(player, "anticonvulsant") or false
    if d.epCovered and not covered and hasTrait(player, "epilepsy") then notify(player, "UI_DanTraits_EpilepsyMedsLapse") end
    d.epCovered = covered or nil
end

local function updateEpilepsyMinute(player, d)
    if not hasTrait(player, "epilepsy") then
        d.epAuraMin, d.epAuraMs, d.epAfterMin, d.epNight, d.epCovered = nil, nil, nil, nil, nil
        return
    end
    medsNotice(player, d)
    if (d.epAfterMin or 0) > 0 then
        d.epAfterMin = d.epAfterMin - 1
        local left = clamp01(d.epAfterMin / EP_AFTER_MIN)
        DanTraits_PainFloor(player, d, "epilepsy", EP_AFTER_PAIN * left, 5)
        pcall(function() DanTraits_FloorUp(player:getStats(), CharacterStat.UNHAPPINESS, EP_AFTER_SAD * left, 2) end)
    end
    if d.epAuraMin then
        d.epAuraMin = math.max(0, d.epAuraMin - 1)
        local waited = true
        pcall(function() waited = getTimestampMs() >= (d.epAuraMs or 0) end)
        if d.epAuraMin <= 0 and waited then seize(player, d) end
        return
    end
    if DanTraits_IsPassedOut and DanTraits_IsPassedOut(player) then return end
    if DanTraits_Roll(seizureRate(player, d) / 60) then aura(player, d) end
end

-- a dose by hand (the console); a swallowed pill reaches the medication system itself
function DanTraits_TakeAnticonvulsant(player, amount)
    local level = DanTraits_MedTake(player, "anticonvulsant", amount or 1)
    DanTraits_Data(player).epCovered = DanTraits_MedCovered(player, "anticonvulsant") or nil
    return level
end

-- a seizure in the night: the sleep it broke scores worse (the flag is spent
-- when the night is scored)
DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not d or not d.epNight then return nil end
    d.epNight = nil
    return quality * (1 - EP_NIGHT_CUT)
end)

function DanTraits_IsAnticonvulsants(item) return DanTraits_IsItem(item, EP_MEDS_ITEM) end

-- after the medication system has taken the dose (it loads first)
DanTraits_AddHook("pill", function(_, player, kind)
    if DanTraits_DrugOfItem(kind) == "anticonvulsant" then
        DanTraits_Data(player).epCovered = DanTraits_MedCovered(player, "anticonvulsant") or nil
    end
    return nil
end)

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.epilepsy = function(player, args)
    local d = DanTraits_Data(player)
    if args[1] == "seize" then seize(player, d) return "seizure" end
    if args[1] == "aura" then aura(player, d) return "aura: a seizure in " .. tostring(d.epAuraMin) .. " minutes" end
    if args[1] == "pill" then return "anticonvulsant level " .. tostring(DanTraits_TakeAnticonvulsant(player, 1)) end
    return "epilepsy seize | epilepsy aura | epilepsy pill (seizures an hour now " .. tostring(seizureRate(player, d)) .. ")"
end

-- start on anticonvulsants, fully built up, with a bottle (none if the
-- Starting Medication sandbox option is off)
local function onEpilepsyCreatePlayer(playerNum, player)
    if not player or not hasTrait(player, "epilepsy") then return end
    local d = DanTraits_Data(player)
    if d.epKitGiven or player:getHoursSurvived() > 0 then return end
    d.epKitGiven = true
    DanTraits_MedStart(player, "anticonvulsant")
    if not DanTraits_SandboxOn("StartingMedication") then return end
    pcall(function() player:getInventory():AddItem(EP_MEDS_ITEM) end)
end

DanTraits_Every("minute", "Epilepsy", updateEpilepsyMinute, 40)
Events.OnCreatePlayer.Add(onEpilepsyCreatePlayer)
