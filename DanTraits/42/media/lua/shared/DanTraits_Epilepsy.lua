-- Project Zomboid Vitality Project: Epilepsy.
--
-- Seizures. Well rested, sober, well and calm, one comes about once in eight
-- days; the triggers multiply that: tiredness (the Tired moodle's range,
-- hardest near exhaustion), alcohol withdrawal and a hangover, a fever (wound
-- infection), a concussion, stress, and bright daylight on a sensitive brain.
-- Anticonvulsants (a pill bottle of this mod's, found with the other
-- prescriptions) are the answer: each pill tops up a level that halves every
-- 12 hours, and while it is at least half a pill, seizures are a tenth as
-- likely. A pill every 12 hours keeps it there. A new character starts with
-- a bottle.
--
-- A seizure gives a moment's warning (an aura: a notice, then two game
-- minutes). Then you drop whatever is in your hands and go down (the shared
-- pass-out, DanTraits_Faint.lua, deep: nothing wakes you) for 2 to 5 game
-- minutes, can knock your head (a concussion, DanTraits_Concussion.lua), and
-- come round confused and exhausted: an hour of headache and low mood.
--
-- Mod data: epMeds (the level), epAuraMin (minutes to the seizure),
-- epAfterMin (minutes of the aftermath), epSeizures.
-- Console: epilepsy seize | epilepsy aura | epilepsy pill
require "DanTraits"

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
local EP_BRIGHT        = 1.5     -- in bright daylight
local EP_MEDS_HALF_H   = 12      -- hours for the anticonvulsant level to halve
local EP_MEDS_ON       = 0.5     -- level at which it protects
local EP_MEDS_CUT      = 0.1     -- seizures x this while protected
local EP_AURA_MIN      = 2       -- warning before the seizure
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

local function protected(d) return (d.epMeds or 0) >= EP_MEDS_ON end

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
    if DanTraits_InBrightLight then
        local ok, bright = pcall(DanTraits_InBrightLight, player)
        if ok and bright then rate = rate * EP_BRIGHT end
    end
    if protected(d) then rate = rate * EP_MEDS_CUT end
    return rate
end
DanTraits_SeizureRate = seizureRate

local function aura(player, d)
    d.epAuraMin = EP_AURA_MIN
    notify(player, "UI_DanTraits_EpilepsyAura")
end

local function seize(player, d)
    d.epAuraMin = nil
    d.epSeizures = (d.epSeizures or 0) + 1
    d.epAfterMin = EP_AFTER_MIN
    local stats = player:getStats()
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

local function updateEpilepsyMinute(player, d)
    if (d.epMeds or 0) > 0 then
        d.epMeds = d.epMeds * 0.5 ^ (1 / (EP_MEDS_HALF_H * 60))
        if d.epMeds < 0.01 then d.epMeds = 0 end
    end
    if not hasTrait(player, "epilepsy") then
        d.epAuraMin, d.epAfterMin = nil, nil
        return
    end
    if (d.epAfterMin or 0) > 0 then
        d.epAfterMin = d.epAfterMin - 1
        local left = clamp01(d.epAfterMin / EP_AFTER_MIN)
        DanTraits_PainFloor(player, d, "epilepsy", EP_AFTER_PAIN * left, 5)
        pcall(function() DanTraits_FloorUp(player:getStats(), CharacterStat.UNHAPPINESS, EP_AFTER_SAD * left, 2) end)
    end
    if d.epAuraMin then
        d.epAuraMin = d.epAuraMin - 1
        if d.epAuraMin <= 0 then seize(player, d) end
        return
    end
    if DanTraits_IsPassedOut and DanTraits_IsPassedOut(player) then return end
    if DanTraits_Roll(seizureRate(player, d) / 60) then aura(player, d) end
end
DanTraits_updateEpilepsyMinute = updateEpilepsyMinute

function DanTraits_TakeAnticonvulsant(player, amount)
    local d = DanTraits_Data(player)
    d.epMeds = (d.epMeds or 0) + (amount or 1)
    return d.epMeds
end

function DanTraits_IsAnticonvulsants(item)
    local ok, res = pcall(function() return item:getFullType() == EP_MEDS_ITEM end)
    return ok and res == true
end

DanTraits_AddHook("pill", function(_, player, kind)
    if string.lower(tostring(kind or "")) == "anticonvulsants" then DanTraits_TakeAnticonvulsant(player, 1) end
    return nil
end)

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.epilepsy = function(player, args)
    local d = DanTraits_Data(player)
    if args[1] == "seize" then seize(player, d) return "seizure" end
    if args[1] == "aura" then aura(player, d) return "aura: a seizure in " .. EP_AURA_MIN .. " minutes" end
    if args[1] == "pill" then return "anticonvulsant level " .. tostring(DanTraits_TakeAnticonvulsant(player, 1)) end
    return "epilepsy seize | epilepsy aura | epilepsy pill (seizures an hour now " .. tostring(seizureRate(player, d)) .. ")"
end

-- start with a bottle of anticonvulsants
local function onEpilepsyCreatePlayer(playerNum, player)
    if not player or not hasTrait(player, "epilepsy") then return end
    local d = DanTraits_Data(player)
    if d.epKitGiven or player:getHoursSurvived() > 0 then return end
    d.epKitGiven = true
    pcall(function() player:getInventory():AddItem(EP_MEDS_ITEM) end)
end

DanTraits_Every("minute", "Epilepsy", updateEpilepsyMinute, 40)
Events.OnCreatePlayer.Add(onEpilepsyCreatePlayer)
