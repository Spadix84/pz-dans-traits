-- Project Zomboid Vitality Project: the Angry moodle, given something to do.
-- For everyone, trait or not.
--
-- Vanilla keeps an anger stat and shows it as the Angry moodle (Irritated,
-- Annoyed, Angry, Furious), but nothing in the game reads it. Here it is
-- nicotine withdrawal that raises it (DanTraits_Smoker.lua); another mod's
-- anger counts the same. By moodle level, from Annoyed (level 2) up; Irritated
-- is only the warning:
--
-- Rough. A melee hit has an extra chance to wear the weapon, on top of the
-- game's own roll (never the last point: anger does not break a weapon, the
-- game's wear does). At Furious every melee swing costs extra endurance.
--
-- Loud. From Angry (level 3) the character now and then curses out loud, and
-- zombies nearby hear it. Not asleep, and not inside the gap the one shared
-- cough keeps (d.coughGap, DanTraits_Util.lua), which a curse starts too.
--
-- Can't concentrate. A book, magazine or anything else read takes longer
-- (ISReadABook's time, set when the reading starts).
--
-- Sloppy fine work. Splints set badly and stitches come out rough more often
-- (the splintBadSet and stitchPoor hooks of DanTraits_WoundCare.lua, for
-- whoever does the work), and installing or removing a vehicle part is less
-- likely to succeed and more likely to damage the part
-- (VehicleUtils.calculateInstallationSuccess, which the mechanics window
-- reads too, so the chance it shows is the angry one).
--
-- The AngerEffects sandbox option turns all of it off.
--
-- Mod data: angCurses (count, for the console and tests); shares coughGap.
require "DanTraits"

local sandboxOn = DanTraits_SandboxOn
local roll = DanTraits_Roll

-- by moodle level 1..4 (Irritated, Annoyed, Angry, Furious)
local ANG_WEAR         = { 0, 0.5, 1, 1.5 }      -- extra weapon wear rolls per hit, as a share of the game's chance
local ANG_SWING_END    = { 0, 0, 0, 0.004 }      -- endurance off every melee swing
local ANG_CURSE        = { 0, 0, 1.5, 4 }        -- percent a minute to curse out loud
local ANG_CURSE_RADIUS = { 0, 0, 8, 14 }         -- tiles zombies hear it from
local ANG_READ         = { 1, 1.15, 1.3, 1.5 }   -- reading time x this
local ANG_SLOPPY       = { 1, 1.25, 1.5, 2 }     -- bad splint and rough stitch chance x this
local ANG_MECH         = { 0, 5, 10, 20 }        -- points off a vehicle part's success chance, and onto its failure chance
local ANG_CURSE_LINES  = 5                       -- UI_DanTraits_AngerCurse1..n
local ANG_CURSE_GAP_MIN = 3
-- the anger stat (0..1) each level starts at, when the moodle cannot be read
local ANG_LEVELS       = { 0.1, 0.25, 0.5, 0.75 }

-- the Angry moodle's level, 0..4 (0 with the sandbox option off)
local function angerLevel(player)
    if not player or not sandboxOn("AngerEffects") then return 0 end
    local level
    if MoodleType and MoodleType.ANGRY then
        pcall(function() level = player:getMoodles():getMoodleLevel(MoodleType.ANGRY) end)
    end
    if type(level) ~= "number" then
        local anger = 0
        pcall(function() anger = player:getStats():get(CharacterStat.ANGER) or 0 end)
        level = DanTraits_TierOf(anger, ANG_LEVELS)
    end
    return math.max(0, math.min(4, level))
end
DanTraits_AngerLevel = angerLevel

local function isLocal(player)
    return player ~= nil and player == getSpecificPlayer(0)
end

local function melee(weapon)
    local ok, res = pcall(function() return not weapon:isRanged() and weapon:getType() ~= "BareHands" end)
    return ok and res == true
end

-- rough ----------------------------------------------------------------------
-- a hit that landed: the game has made its own wear roll, this is the extra one
local function onWeaponHit(owner, weapon)
    if not weapon or not isLocal(owner) then return end
    local extra = ANG_WEAR[angerLevel(owner)] or 0
    if extra <= 0 or not melee(weapon) then return end
    pcall(function()
        local condition = weapon:getCondition()
        if condition <= 1 then return end
        local odds = weapon:getConditionLowerChance() * 2 + owner:getMaintenanceMod() * 2
        if odds > 0 and roll(extra / odds) then weapon:setCondition(condition - 1) end
    end)
end

local function onWeaponSwing(player, weapon)
    if not weapon or not isLocal(player) then return end
    local cost = ANG_SWING_END[angerLevel(player)] or 0
    if cost <= 0 or not melee(weapon) then return end
    DanTraits_StatAdd(player:getStats(), CharacterStat.ENDURANCE, -cost)
end

-- loud -----------------------------------------------------------------------
local function curse(player, d, radius)
    local line = getText("UI_DanTraits_AngerCurse" .. tostring(ZombRand(ANG_CURSE_LINES) + 1))
    pcall(function() player:Say(line) end)
    pcall(function() addSound(player, player:getX(), player:getY(), player:getZ(), radius, radius) end)
    d.angCurses = (d.angCurses or 0) + 1
end

local function updateAngerMinute(player, d)
    local level = angerLevel(player)
    local chance = ANG_CURSE[level] or 0
    if chance <= 0 or DanTraits_Asleep(player) then return end
    local now = 0
    pcall(function() now = getGameTime():getWorldAgeHours() end)
    if (d.coughGap or 0) > now then return end
    if not DanTraits_RollPercent(chance) then return end
    curse(player, d, ANG_CURSE_RADIUS[level])
    d.coughGap = now + ANG_CURSE_GAP_MIN / 60
end

-- sloppy fine work -------------------------------------------------------------
local function sloppy(chance, setter)
    local k = ANG_SLOPPY[angerLevel(setter)] or 1
    if k == 1 then return nil end
    return chance * k
end
DanTraits_AddHook("splintBadSet", sloppy)
DanTraits_AddHook("stitchPoor", sloppy)

-- can't concentrate, and the vehicle parts (VehicleUtils loads after this file:
-- wrapped again on OnGameStart)
local function wrapAnger()
    DanTraits_Wrap(ISReadABook, "getDuration", "anger-read", function(original, self, ...)
        local t = original(self, ...)
        if type(t) == "number" and t > 1 then t = t * (ANG_READ[angerLevel(self.character)] or 1) end
        return t
    end)
    -- a plain function, not a method: the wrap's `self` is its first argument
    DanTraits_Wrap(VehicleUtils, "calculateInstallationSuccess", "anger-mechanics", function(original, perks, chr, ...)
        local success, failure = original(perks, chr, ...)
        local off = ANG_MECH[angerLevel(chr)] or 0
        if off > 0 and type(success) == "number" and type(failure) == "number" then
            success = math.max(0, success - off)
            failure = math.min(100, failure + off)
        end
        return success, failure
    end)
end
wrapAnger()
Events.OnGameStart.Add(wrapAnger)

-- console: anger <0..1> | anger curse
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.anger = function(player, args)
    local d = DanTraits_Data(player)
    if args[1] == "curse" then
        curse(player, d, ANG_CURSE_RADIUS[4])
        return "cursed out loud (" .. tostring(d.angCurses) .. " so far)"
    end
    local value = tonumber(args[1])
    if not value then return "anger <0..1> | anger curse   (level now " .. tostring(angerLevel(player)) .. ")" end
    value = DanTraits_Clamp01(value)
    pcall(function() player:getStats():set(CharacterStat.ANGER, value) end)
    return "anger " .. tostring(value) .. " (the game drains it; a Smoker's craving holds its own floor)"
end

Events.OnWeaponHitXp.Add(onWeaponHit)
Events.OnWeaponSwing.Add(onWeaponSwing)
DanTraits_Every("minute", "Anger", updateAngerMinute, 40)
