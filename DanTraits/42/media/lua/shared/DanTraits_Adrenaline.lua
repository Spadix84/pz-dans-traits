-- Project Zomboid Vitality Project: the adrenaline auto-injector
-- (DanTraits.AdrenalineInjector). Not a trait: anyone can use one, once. A
-- burst of energy for an emergency, at a price.
--
-- The rush (AD_RUSH_MIN, two game hours): the shot takes all the tiredness
-- off and holds it there, endurance fills up and comes back half as fast
-- again, stress climbs to a floor, the hands shake (a swing can drop the
-- weapon) and a Heart Condition builds strain three times as fast
-- (DanTraits_Heart.lua reads DanTraits_AdrenalineRush).
--
-- The heart: every shot has a 1 in 4 chance of a heart attack, and each shot
-- within a day adds another 1 in 4 (the second is 1 in 2, the fourth is
-- certain). It is decided at the jab but lands 5 to 40 minutes into the rush,
-- so you never know whether you got away with it. The attack is Heart
-- Condition's own (DanTraits_HeartAttack): down for 5 to 15 minutes, health
-- lost and a week of recovery, for anyone.
--
-- Beta blockers blunt it (they block what adrenaline acts on): built up in
-- full, the shot takes off half the tiredness, refills half the missing
-- endurance, and the heart attack is half as likely.
--
-- The crash: the shot does not take the tiredness away, it borrows it. What
-- it took off is kept (adDebt), and when the rush ends it comes back over
-- half an hour with a quarter on top, plus a little more (AD_CRASH_BASE)
-- for the rush itself, capped at fully exhausted. Then six hours Crashing:
-- endurance comes back at half speed, low mood, a dull headache, the shakes
-- for the first hour. Asleep, the crash passes four times as fast. Another
-- shot during the crash puts the debt off again with what was still owed
-- added, so the next crash is worse, and it rolls the heart again (not while
-- an attack from an earlier shot is already on its way: that timer stands).
--
-- Mod data: adShots (world hours of each shot in the last day), adRushMin
-- (minutes of rush left), adHold (the tiredness held to during the rush),
-- adDebt (tiredness owed), adAttackIn (minutes until the heart attack, nil
-- none coming), adRetFrom / adRetTo / adRetMin (the tiredness coming back),
-- adCrashMin (minutes of crash left).
-- Console: adrenaline | adrenaline shot | adrenaline crash | adrenaline clear
require "DanTraits"

local notify = DanTraits_Notify

local AD_ITEM          = "adrenalineinjector"   -- lower-case item type
local AD_RUSH_MIN      = 120     -- minutes of rush
local AD_WEARING_MIN   = 20      -- the last minutes of it show as wearing off
local AD_RISK          = 0.25    -- chance of a heart attack, x each shot within AD_WINDOW_H (this one included)
local AD_WINDOW_H      = 24
local AD_ATTACK_IN     = { 5, 40 }   -- minutes into the rush the attack lands
local AD_BETA_CUT      = 0.5     -- fully built-up beta blockers: the lift and the risk x this
local AD_REGEN         = 1.5     -- endurance recovery x this during the rush
local AD_STRESS        = 0.3     -- stress floor during the rush...
local AD_STRESS_RAMP   = 0.02    -- ...climbed to this a minute
local AD_SHAKE_DROP    = 3       -- percent added to a swing's drop chance: the rush, and the crash's first hour
-- the crash
local AD_INTEREST      = 1.25    -- the tiredness owed comes back x this...
local AD_CRASH_BASE    = 0.15    -- ...plus this
local AD_RETURN_MIN    = 30      -- minutes it takes to come back
local AD_CRASH_H       = 6
local AD_CRASH_SHAKE_MIN = 60    -- the first minutes of the crash shake
local AD_CRASH_REGEN   = 0.5     -- endurance recovery x this
local AD_CRASH_SAD     = 20      -- unhappiness floor...
local AD_CRASH_RAMP    = 1       -- ...climbed to this a minute
local AD_CRASH_PAIN    = 10      -- headache (a DanTraits_PainFloor floor)
local AD_ASLEEP_FASTER = 4       -- crash minutes gone per minute asleep

local worldHours = DanTraits_WorldHours

local function getStat(stats, stat)
    local v = 0
    pcall(function() v = stats:get(stat) or 0 end)
    return tonumber(v) or 0
end

local function setStat(stats, stat, v)
    pcall(function() stats:set(stat, v) end)
end

function DanTraits_IsAdrenaline(item)
    local ok, res = pcall(function() return string.lower(tostring(item:getType())) == AD_ITEM end)
    return ok and res == true
end

-- the rush is running: Heart Condition reads it
function DanTraits_AdrenalineRush(player)
    local d = player and DanTraits_Data(player)
    return d ~= nil and (d.adRushMin or 0) > 0
end

local function crashing(d) return (d.adCrashMin or 0) > 0 end

local function shaking(d)
    if (d.adRushMin or 0) > 0 then return true end
    return crashing(d) and d.adCrashMin > AD_CRASH_H * 60 - AD_CRASH_SHAKE_MIN
end

-- the shots in the last day, this one included
local function countShot(d, now)
    local kept = {}
    for _, h in ipairs(d.adShots or {}) do
        if now - h < AD_WINDOW_H then kept[#kept + 1] = h end
    end
    kept[#kept + 1] = now
    d.adShots = kept
    return #kept
end

-- the chance this shot brings on a heart attack
function DanTraits_AdrenalineRisk(shots, beta)
    return math.min(1, AD_RISK * shots) * (1 - AD_BETA_CUT * (beta or 0))
end

local function shot(player)
    local d = DanTraits_Data(player)
    local stats = player:getStats()
    local shots = countShot(d, worldHours())
    local beta = DanTraits_MedEffect and DanTraits_MedEffect(player, "beta") or 0
    local cut = 1 - AD_BETA_CUT * beta
    local fatigue = getStat(stats, CharacterStat.FATIGUE)
    -- in the middle of a crash: what had still to come back is owed again
    local owed = 0
    if (d.adRetMin or 0) > 0 then owed = math.max(0, (d.adRetTo or 0) - fatigue) end
    local lift = fatigue * cut
    d.adDebt = (d.adDebt or 0) + lift + owed
    d.adHold = fatigue - lift
    setStat(stats, CharacterStat.FATIGUE, d.adHold)
    local endurance = getStat(stats, CharacterStat.ENDURANCE)
    setStat(stats, CharacterStat.ENDURANCE, endurance + (1 - endurance) * cut)
    d.adRushMin = AD_RUSH_MIN
    d.adCrashMin, d.adRetFrom, d.adRetTo, d.adRetMin = nil, nil, nil, nil
    if DanTraits_FrameWake then DanTraits_FrameWake(player) end   -- the stamina pipeline reads the rush on the frames: into the frame set now
    if not d.adAttackIn and DanTraits_Roll(DanTraits_AdrenalineRisk(shots, beta)) then
        d.adAttackIn = math.floor(DanTraits_RandRange(AD_ATTACK_IN[1], AD_ATTACK_IN[2]))
    end
    notify(player, shots > 1 and "UI_DanTraits_AdrenalineAgain" or "UI_DanTraits_AdrenalineShot")
end
DanTraits_AdrenalineShot = shot

local function startCrash(player, d, stats)
    local from = getStat(stats, CharacterStat.FATIGUE)
    local to = math.min(1, (d.adDebt or 0) * AD_INTEREST + AD_CRASH_BASE)
    d.adRetFrom, d.adRetTo, d.adRetMin = from, math.max(from, to), AD_RETURN_MIN
    d.adDebt, d.adHold = nil, nil
    d.adCrashMin = AD_CRASH_H * 60
    notify(player, "UI_DanTraits_AdrenalineCrash")
end

local function updateAdrenalineMinute(player, d)
    if d.adAttackIn and not (DanTraits_IsPassedOut and DanTraits_IsPassedOut(player)) then
        d.adAttackIn = d.adAttackIn - 1
        if d.adAttackIn <= 0 then
            d.adAttackIn = nil
            if DanTraits_HeartAttack then DanTraits_HeartAttack(player) end
        end
    end
    local stats = player:getStats()
    if (d.adRushMin or 0) > 0 then
        d.adRushMin = d.adRushMin - 1
        if getStat(stats, CharacterStat.FATIGUE) > (d.adHold or 0) then setStat(stats, CharacterStat.FATIGUE, d.adHold or 0) end
        DanTraits_FloorUp(stats, CharacterStat.STRESS, AD_STRESS, AD_STRESS_RAMP)
        if d.adRushMin <= 0 then
            d.adRushMin = nil
            startCrash(player, d, stats)
        end
        return
    end
    if not crashing(d) then return end
    if (d.adRetMin or 0) > 0 then
        d.adRetMin = d.adRetMin - 1
        local from, to = d.adRetFrom or 0, d.adRetTo or 0
        local target = to - (to - from) * d.adRetMin / AD_RETURN_MIN
        if getStat(stats, CharacterStat.FATIGUE) < target then setStat(stats, CharacterStat.FATIGUE, target) end
        if d.adRetMin <= 0 then d.adRetFrom, d.adRetTo, d.adRetMin = nil, nil, nil end
    end
    DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, AD_CRASH_SAD, AD_CRASH_RAMP)
    DanTraits_PainFloor(player, d, "adrenaline", AD_CRASH_PAIN, 1)
    d.adCrashMin = d.adCrashMin - (DanTraits_Asleep(player) and AD_ASLEEP_FASTER or 1)
    if d.adCrashMin <= 0 then
        d.adCrashMin = nil
        DanTraits_NotifyGood(player, "UI_DanTraits_AdrenalineCleared")
    end
end

-- the Adrenaline moodle: -2 the rush, -1 wearing off; 2 the tiredness coming
-- back and the shakes, 1 the rest of the crash (the heart attack coming is never shown)
function DanTraits_AdrenalineMoodle(player, d)
    if (d.adRushMin or 0) > 0 then return d.adRushMin <= AD_WEARING_MIN and -1 or -2 end
    if not crashing(d) then return 0 end
    if (d.adRetMin or 0) > 0 or shaking(d) then return 2 end
    return 1
end

DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d then return nil end
    if (d.adRushMin or 0) > 0 then return delta * AD_REGEN end
    if crashing(d) then return delta * AD_CRASH_REGEN end
    return nil
end)

DanTraits_AddHook("swingDrop", function(chance, player)
    local d = player and player:getModData().DanTraits
    if not d or not shaking(d) then return nil end
    return chance + AD_SHAKE_DROP
end)

DanTraits_AddHook("pill", function(_, player, kind)
    if not player or string.lower(tostring(kind or "")) ~= AD_ITEM then return nil end
    shot(player)
    return nil
end)

-- Console --------------------------------------------------------------------------
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.adrenaline = function(player, args)
    local d = DanTraits_Data(player)
    if args[1] == "shot" then shot(player) return "adrenaline shot" end
    if args[1] == "crash" then
        d.adRushMin = nil
        startCrash(player, d, player:getStats())
        return "adrenaline crash"
    end
    if args[1] == "clear" then
        d.adShots, d.adRushMin, d.adHold, d.adDebt, d.adAttackIn = nil, nil, nil, nil, nil
        d.adRetFrom, d.adRetTo, d.adRetMin, d.adCrashMin = nil, nil, nil, nil
        return "adrenaline cleared"
    end
    return string.format("rush %d min, debt %.2f, crash %d min, attack in %s, shots today %d | adrenaline shot | adrenaline crash | adrenaline clear",
        d.adRushMin or 0, d.adDebt or 0, d.adCrashMin or 0, tostring(d.adAttackIn or "none"), #(d.adShots or {}))
end

DanTraits_Every("minute", "Adrenaline", updateAdrenalineMinute, 35)
