-- Project Zomboid Vitality Project: sunburn.
-- Not a trait: every character has it (sandbox option SunburnEnabled; off:
-- no exposure builds and any burn heals at once).
--
-- Not a wound either: nothing to bandage, nothing to stitch, no infection.
-- It is a state on the body part, kept in mod data, that hurts and heals on
-- its own in a day. Each minute outdoors in sunshine (day, no rain, not heavily
-- overcast), every body part no worn clothing covers builds exposure; about
-- three hours of full summer sun burns bare skin, less in cool weather (the
-- sun counts for nothing at 5 C and fully from 20 C), less early and late in
-- the day (full from 11 to 3, half at 9 and at 5, nothing before 7 or after
-- 7 in the evening), and none in shade or indoors, where exposure fades again
-- over four hours. A hat covers the head,
-- shoes the feet, a shirt the torso and arms: whatever the clothing's own
-- covered parts say. A burnt part hurts for 24 hours, the last six easing off,
-- and staying out in the sun on it starts the day over. The pain is on the
-- burnt part itself (its additional pain, topped up each minute against the
-- game's own decay, never lowered: a wound there still hurts as it did), so
-- the health panel shows the arm hurting, not the head. The game's PAIN stat
-- is a weighted sum over the parts (measured 2026-09-29: 30 on the head reads
-- about 28, on a forearm 18, on the chest 20, and ten parts at 30 pin it at
-- 100), so one burnt part is a nuisance and a whole body burnt is agony, the
-- stat at its maximum, for most of a day. A painkiller clears it while it
-- works, as it does any pain. A burnt night scores worse (the nightQuality
-- hook).
-- The health panel shows "Sunburnt" on the part (client/DanTraits_HealthPanel.lua).
--
-- Skin toughens: every time you burn, the skin you are left with takes longer
-- to burn again (a tan, 0..1: a quarter a burn; at full it takes three times
-- the sun, nine hours of the midday kind, which a day outdoors never adds up
-- to). It fades over a month out of the sun. Outdoorsman skin is used to
-- it: twice the sun to burn (the vanilla trait, reworked in place).
--
-- Sun block (the Sunblock item, 8 applications, common in bathrooms, on
-- toiletry shelves and in lockers): one application keeps the sun off all
-- bare skin for 8 hours. It does nothing for a burn you already have. You are
-- told when it wears off.
--
-- Mod data: sbExp[part] (0..1 exposure), sbBurn[part] (hours left),
-- sbWarned (the "skin is hot" notice this spell), sbTan (0..1), sbBlockMin
-- (minutes of sun block left).
-- Console: sunburn <part|all> | sunburn clear | sunburn block [minutes] | sunburn tan <0..1>
require "DanTraits"

local notify = DanTraits_Notify
local clamp01 = DanTraits_Clamp01

local SB_BURN_MIN      = 180     -- minutes of full sun on bare skin to burn
local SB_FADE_MIN      = 240     -- minutes out of the sun for exposure to fade from full
local SB_WARN_AT       = 0.7     -- exposure at which "your skin feels hot"
local SB_TEMP_NONE     = 5       -- air temperature (C) at which the sun burns nothing...
local SB_TEMP_FULL     = 20      -- ...and fully from here
local SB_NIGHT         = 0.5     -- night strength over this: no sun
local SB_RAIN          = 0.1     -- rain over this: no sun
local SB_CLOUD_CUT     = 0.8     -- sun x (1 - this x cloud)
local SB_BURN_H        = 24      -- hours a burn lasts
local SB_EASE_H        = 6       -- the last hours ease off
local SB_PART_PAIN     = 20      -- additional pain held on each burnt part (the head alone reads about 18 on the stat)
local SB_PAIN_RAMP     = 4       -- a part's pain rises toward that by at most this a minute
local SB_NIGHT_CUT     = 0.2     -- the night's score x (1 - this x share of the body burnt)
local SB_NOON_FROM     = 11      -- the sun is at full strength from this hour...
local SB_NOON_TO       = 15      -- ...to this one...
local SB_NOON_SLOPE    = 4       -- ...and falls to nothing this many hours either side
local SB_TAN_BURN      = 0.25    -- tan gained each time you burn
local SB_TAN_MORE      = 2       -- minutes to burn x (1 + this x tan)
local SB_TAN_FADE_DAYS = 30      -- days for a full tan to fade
local SB_BLOCK_MIN     = 480     -- minutes one application of sun block lasts
local SB_BLOCK         = 0       -- exposure x this while it is on
local SB_BLOCK_ITEM    = "DanTraits.Sunblock"
local SB_OUTDOORSMAN   = 2       -- Outdoorsman: minutes to burn x this

local PARTS = { "Head", "Neck", "Torso_Upper", "Torso_Lower", "Groin", "UpperArm_L", "UpperArm_R",
                "ForeArm_L", "ForeArm_R", "Hand_L", "Hand_R", "UpperLeg_L", "UpperLeg_R",
                "LowerLeg_L", "LowerLeg_R", "Foot_L", "Foot_R" }
DanTraits_SunburnParts = PARTS

local function sandboxOn() return DanTraits_SandboxOn("SunburnEnabled") end

-- 0..1: how high the sun is by the clock (the hour with its fraction)
local function sunHeight(hour)
    if hour < SB_NOON_FROM then return clamp01(1 - (SB_NOON_FROM - hour) / SB_NOON_SLOPE) end
    if hour > SB_NOON_TO then return clamp01(1 - (hour - SB_NOON_TO) / SB_NOON_SLOPE) end
    return 1
end
DanTraits_SunHeight = sunHeight

local function hourNow()
    local hour
    pcall(function() hour = getGameTime():getTimeOfDay() end)
    if type(hour) ~= "number" then pcall(function() hour = getGameTime():getHour() end) end
    return tonumber(hour) or 12
end

-- 0..1: how hard the sun is beating down on this character now
local function sunOn(player)
    local outside = false
    pcall(function() outside = player:isOutside() end)
    if not outside then return 0 end
    local sun = 0
    pcall(function()
        local c = getClimateManager()
        if (c:getNightStrength() or 0) > SB_NIGHT then return end
        if (c:getRainIntensity() or 0) > SB_RAIN then return end
        local warm = clamp01(((c:getAirTemperatureForCharacter(player) or 0) - SB_TEMP_NONE) / (SB_TEMP_FULL - SB_TEMP_NONE))
        sun = warm * (1 - SB_CLOUD_CUT * clamp01(c:getCloudIntensity() or 0)) * sunHeight(hourNow())
    end)
    return sun
end
DanTraits_SunOn = sunOn

-- minutes of full sun on bare skin to burn this character: longer with a
-- tan, and for an Outdoorsman
local function burnMinutes(d, player)
    local m = SB_BURN_MIN * (1 + SB_TAN_MORE * clamp01(d.sbTan or 0))
    if player and DanTraits_HasVanillaTrait(player, "base:outdoorsman") then m = m * SB_OUTDOORSMAN end
    return m
end
DanTraits_SunBurnMinutes = burnMinutes

-- sun block: minutes left, for the moodle and the dashboard
function DanTraits_SunblockLeft(player)
    local d = player and player:getModData().DanTraits
    return d and d.sbBlockMin or 0
end

function DanTraits_ApplySunblock(player, minutes)
    local d = DanTraits_Data(player)
    d.sbBlockMin = math.max(d.sbBlockMin or 0, minutes or SB_BLOCK_MIN)
    DanTraits_NotifyGood(player, "UI_DanTraits_SunblockOn")
    return d.sbBlockMin
end

function DanTraits_IsSunblock(item)
    local ok, res = pcall(function() return item:getFullType() == SB_BLOCK_ITEM end)
    return ok and res == true
end

DanTraits_AddHook("pill", function(_, player, kind)
    if string.lower(tostring(kind or "")) == "sunblock" then DanTraits_ApplySunblock(player) end
    return nil
end)

-- the parts worn clothing covers, by name ("Torso_Upper"): each worn item's
-- covered parts (BloodBodyPartType, named like the body parts)
local function coveredParts(player)
    local covered = {}
    local worn
    pcall(function() worn = player:getWornItems() end)
    if not worn then return covered end
    local n = 0
    pcall(function() n = worn:size() end)
    for i = 0, n - 1 do
        pcall(function()
            local item = worn:getItemByIndex(i)
            -- only clothing has covered parts (asking a bag would log a stack trace)
            if not item or not instanceof(item, "Clothing") then return end
            local parts = item:getCoveredParts()
            for j = 0, parts:size() - 1 do covered[tostring(parts:get(j))] = true end
        end)
    end
    return covered
end
DanTraits_SunCovered = coveredParts

local function burntCount(d)
    local n = 0
    for _, hours in pairs(d.sbBurn or {}) do if hours > 0 then n = n + 1 end end
    return n
end

-- 0..1 how much a burn still hurts: full, then easing over the last hours
local function burnStrength(hours) return clamp01(hours / SB_EASE_H) end

-- raise the part's additional pain toward target, by at most the ramp; never lower it
local function hurtPart(bd, name, target)
    pcall(function()
        local part = bd:getBodyPart(BodyPartType[name])
        if not part then return end
        local now = part:getAdditionalPain() or 0
        if now < target then part:setAdditionalPain(math.min(100, target, now + SB_PAIN_RAMP)) end
    end)
end
DanTraits_SunburnHurtPart = hurtPart

local function updateSunburnMinute(player, d)
    if not sandboxOn() then
        d.sbExp, d.sbBurn, d.sbWarned, d.sbBlockMin = nil, nil, nil, nil
        return
    end
    d.sbExp = d.sbExp or {}
    local sun = sunOn(player)
    -- sun block wears off by the clock, in the sun or out of it
    if (d.sbBlockMin or 0) > 0 then
        sun = sun * SB_BLOCK
        d.sbBlockMin = d.sbBlockMin - 1
        if d.sbBlockMin <= 0 then
            d.sbBlockMin = nil
            notify(player, "UI_DanTraits_SunblockOff")
        end
    end
    -- a tan fades out of use
    if (d.sbTan or 0) > 0 then
        d.sbTan = d.sbTan - 1 / (SB_TAN_FADE_DAYS * 1440)
        if d.sbTan <= 0 then d.sbTan = nil end
    end
    local covered = sun > 0 and coveredParts(player) or {}
    local hottest, newBurn = 0, false
    local toBurn = burnMinutes(d, player)
    for _, name in ipairs(PARTS) do
        local exp = d.sbExp[name] or 0
        if sun > 0 and not covered[name] then
            exp = exp + sun / toBurn
            if exp >= 1 then
                d.sbBurn = d.sbBurn or {}
                if (d.sbBurn[name] or 0) <= 0 then newBurn = true end
                d.sbBurn[name] = SB_BURN_H
                exp = 0
            end
        elseif exp > 0 then
            exp = math.max(0, exp - 1 / SB_FADE_MIN)
        end
        d.sbExp[name] = exp > 0 and exp or nil
        if exp > hottest then hottest = exp end
    end
    if hottest >= SB_WARN_AT and not d.sbWarned then
        d.sbWarned = true
        notify(player, "UI_DanTraits_SunburnHot")
    elseif hottest < SB_WARN_AT / 2 then
        d.sbWarned = nil
    end
    if newBurn then
        notify(player, "UI_DanTraits_SunburnBurnt")
        d.sbTan = clamp01((d.sbTan or 0) + SB_TAN_BURN)
    end
    d.sbHot = hottest > 0 and hottest or nil

    -- the burns: heal, and hurt where they are while they last
    if not d.sbBurn then return end
    local any = false
    local bd
    pcall(function() bd = player:getBodyDamage() end)
    for name, hours in pairs(d.sbBurn) do
        hours = hours - 1 / 60
        if hours <= 0 then
            d.sbBurn[name] = nil
        else
            d.sbBurn[name] = hours
            any = true
            if bd then hurtPart(bd, name, SB_PART_PAIN * burnStrength(hours)) end
        end
    end
    if not any then
        d.sbBurn = nil
        DanTraits_NotifyGood(player, "UI_DanTraits_SunburnHealed")
    end
end
DanTraits_updateSunburnMinute = updateSunburnMinute

-- 0..1 share of the body burnt, for the night's score and the dashboard
function DanTraits_SunburnShare(player)
    local d = player and player:getModData().DanTraits
    if not d then return 0 end
    return burntCount(d) / #PARTS
end

DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not d or not d.sbBurn then return nil end
    return quality * (1 - SB_NIGHT_CUT * clamp01(burntCount(d) / #PARTS * 2))
end)

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.sunburn = function(player, args)
    local d = DanTraits_Data(player)
    if args[1] == "clear" then d.sbBurn, d.sbExp = nil, nil return "sunburn cleared" end
    if args[1] == "block" then
        local minutes = tonumber(args[2])
        if minutes and minutes <= 0 then d.sbBlockMin = nil return "sun block off" end
        return "sun block on for " .. tostring(DanTraits_ApplySunblock(player, minutes)) .. " minutes"
    end
    if args[1] == "tan" then
        d.sbTan = clamp01(tonumber(args[2]) or 0)
        return "tan " .. tostring(d.sbTan) .. ": " .. tostring(burnMinutes(d, player)) .. " minutes of full sun to burn"
    end
    local want = args[1]
    if not want then return "sunburn <part|all> | sunburn clear | sunburn block [minutes] | sunburn tan <0..1> (sun now " .. tostring(sunOn(player)) .. ")" end
    d.sbBurn = d.sbBurn or {}
    for _, name in ipairs(PARTS) do
        if want == "all" or string.lower(name) == string.lower(want) then d.sbBurn[name] = SB_BURN_H end
    end
    return tostring(burntCount(d)) .. " part(s) sunburnt"
end

DanTraits_Every("minute", "Sunburn", updateSunburnMinute, 40)
