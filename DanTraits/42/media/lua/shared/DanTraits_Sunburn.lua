-- Project Zomboid Vitality Project: sunburn.
-- Not a trait: every character has it (sandbox option SunburnEnabled; off:
-- no exposure builds and any burn heals at once).
--
-- Not a wound either: nothing to bandage, nothing to stitch, no infection.
-- It is a state on the body part, kept in mod data, that hurts and heals on
-- its own in a day. Each minute outdoors in sunshine (day, no rain, not heavily
-- overcast), every body part no worn clothing covers builds exposure; about
-- three hours of full summer sun burns bare skin, less in cool weather (the
-- sun counts for nothing at 5 C and fully from 20 C), and none in shade or
-- indoors, where exposure fades again over four hours. A hat covers the head,
-- shoes the feet, a shirt the torso and arms: whatever the clothing's own
-- covered parts say. A burnt part hurts for 24 hours, the last six easing off,
-- and staying out in the sun on it starts the day over. The pain is a floor
-- (DanTraits_PainFloor: a painkiller clears it while it works), bigger the more
-- of you is burnt, and a burnt night scores worse (the nightQuality hook).
-- The health panel shows "Sunburnt" on the part (client/DanTraits_HealthPanel.lua).
--
-- Mod data: sbExp[part] (0..1 exposure), sbBurn[part] (hours left),
-- sbWarned (the "skin is hot" notice this spell).
-- Console: sunburn <part|all> | sunburn clear
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
local SB_PAIN_BASE     = 4       -- pain floor: this...
local SB_PAIN_PER      = 3       -- ...plus this a burnt part...
local SB_PAIN_MAX      = 35      -- ...up to this
local SB_NIGHT_CUT     = 0.2     -- the night's score x (1 - this x share of the body burnt)

local PARTS = { "Head", "Neck", "Torso_Upper", "Torso_Lower", "Groin", "UpperArm_L", "UpperArm_R",
                "ForeArm_L", "ForeArm_R", "Hand_L", "Hand_R", "UpperLeg_L", "UpperLeg_R",
                "LowerLeg_L", "LowerLeg_R", "Foot_L", "Foot_R" }
DanTraits_SunburnParts = PARTS

local function sandboxOn() return DanTraits_SandboxOn("SunburnEnabled") end

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
        sun = warm * (1 - SB_CLOUD_CUT * clamp01(c:getCloudIntensity() or 0))
    end)
    return sun
end
DanTraits_SunOn = sunOn

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

local function updateSunburnMinute(player, d)
    if not sandboxOn() then
        d.sbExp, d.sbBurn, d.sbWarned = nil, nil, nil
        return
    end
    d.sbExp = d.sbExp or {}
    local sun = sunOn(player)
    local covered = sun > 0 and coveredParts(player) or {}
    local hottest, newBurn = 0, false
    for _, name in ipairs(PARTS) do
        local exp = d.sbExp[name] or 0
        if sun > 0 and not covered[name] then
            exp = exp + sun / SB_BURN_MIN
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
    if newBurn then notify(player, "UI_DanTraits_SunburnBurnt") end

    -- the burns: heal, and hurt while they last
    if not d.sbBurn then return end
    local pain, any = 0, false
    for name, hours in pairs(d.sbBurn) do
        hours = hours - 1 / 60
        if hours <= 0 then
            d.sbBurn[name] = nil
        else
            d.sbBurn[name] = hours
            any = true
            pain = pain + SB_PAIN_PER * burnStrength(hours)
        end
    end
    if not any then
        d.sbBurn = nil
        DanTraits_NotifyGood(player, "UI_DanTraits_SunburnHealed")
        return
    end
    DanTraits_PainFloor(player, d, "sunburn", math.min(SB_PAIN_MAX, SB_PAIN_BASE + pain), 2)
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
    local want = args[1]
    if not want then return "sunburn <part|all> | sunburn clear (sun now " .. tostring(sunOn(player)) .. ")" end
    d.sbBurn = d.sbBurn or {}
    for _, name in ipairs(PARTS) do
        if want == "all" or string.lower(name) == string.lower(want) then d.sbBurn[name] = SB_BURN_H end
    end
    return tostring(burntCount(d)) .. " part(s) sunburnt"
end

DanTraits_Every("minute", "Sunburn", updateSunburnMinute, 40)
