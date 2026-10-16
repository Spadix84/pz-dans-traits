-- Project Zomboid Vitality Project: the laundry traits, and what other traits
-- feel of laundry. Laundry itself (DanTraits_Laundry.lua) names no trait but
-- Germaphobe; everything here goes through its hooks, so with laundry off
-- (LaundryEnabled) none of it does anything.
--
--   Sweaty (-2)          clothes go stale x1.75 as fast. Not with Cool Customer.
--   Cool Customer (+3)   clothes go stale at half the rate. Not with Sweaty.
--   Slob (+2)            stale and musty clothes cost no mood, and Fresh Clothes
--                        gives none: the moodle is not shown. Musty clothes over
--                        a wound still count for infection. Not with Germaphobe
--                        or Homemaker.
--   Homemaker (+4)       a hand wash gets clothes as clean as a washboard, a
--                        washboard twice as clean; washing wears fabric half as
--                        much; Line-Dried lifts x1.5. Not with Slob.
--   Sensitive Skin (-2)  damp, musty or never-washed clothes against the skin
--                        itch: discomfort, more with each garment. The clothes
--                        you start in count as washed. Bleaching stings the
--                        hands (discomfort per garment), and the sun burns the
--                        skin in two hours, not three (DanTraits_Sunburn.lua).
-- Hooks into other traits:
--   Nomad        stale and musty clothes bother you half as much
--   Homebody     Line-Dried on a clothesline at home lifts x2
--   Asthma       bleaching indoors irritates the airway (a mask helps)
--   Fear of Blood  washing a bloody garment is stressful
--   Bad Back     scrubbing on a washboard strains the back, garment by garment
require "DanTraits"
require "DanTraits_Laundry"

local L = DanTraits_Laundry
local hasTrait = DanTraits_HasTrait

local LT = {
    SWEATY        = 1.75,   -- odour x this
    COOL          = 0.5,
    HOMEMAKER_LINE = 1.5,   -- Line-Dried lift x this
    HOMEBODY_LINE = 2,      -- ...on a line at home
    NOMAD_MOOD    = 0.5,    -- Stale/Musty mood x this
    SKIN_BASE     = 20,     -- discomfort with one itchy garment...
    SKIN_PER      = 10,     -- ...and this for each one more (a musty one counts twice)
    SKIN_CAP      = 50,
    SKIN_RAMP     = 1,      -- discomfort per minute at most, rising
    BLEACH_FUMES  = 0.08,   -- airway irritation per garment bleached indoors
    BLEACH_SKIN   = 15,     -- discomfort per garment bleached, Sensitive Skin
    BLOOD_STRESS  = 0.05,   -- stress per bloody garment washed (0..1)
    BOARD_STRAIN  = 0.06,   -- back load per garment scrubbed on a washboard
}
DanTraits_LaundryTraitsC = LT

-- odour ------------------------------------------------------------------------------

DanTraits_AddHook("laundryOdour", function(k, player)
    if hasTrait(player, "sweaty") then return k * LT.SWEATY end
    if hasTrait(player, "coolcustomer") then return k * LT.COOL end
    return nil
end)

-- mood -------------------------------------------------------------------------------

DanTraits_AddHook("laundryMoodle", function(level, player)
    if hasTrait(player, "slob") then return 0 end
    return nil
end)

DanTraits_AddHook("laundryMood", function(k, player)
    if hasTrait(player, "slob") then return 0 end
    if hasTrait(player, "nomad") then return k * LT.NOMAD_MOOD end
    return nil
end)

DanTraits_AddHook("laundryFresh", function(k, player, level, d)
    if hasTrait(player, "slob") then return 0 end
    if level > -2 then return nil end
    if hasTrait(player, "homemaker") then k = k * LT.HOMEMAKER_LINE end
    if d and d.lnHomeLine and hasTrait(player, "homebody") then k = k * LT.HOMEBODY_LINE end
    return k
end)

-- Homebody: is this clothesline at home
DanTraits_AddHook("laundryAtHome", function(at, player, x, y)
    if not hasTrait(player, "homebody") or not DanTraits_HomeAtPlace or not DanTraits_HomeStrength then return nil end
    if DanTraits_HomeStrength(player) <= 0 then return false end
    return DanTraits_HomeAtPlace(DanTraits_Data(player).hmHome, x, y) == true
end)

-- washing ----------------------------------------------------------------------------

DanTraits_AddHook("laundrySkilled", function(skilled, player)
    if hasTrait(player, "homemaker") then return true end
    return nil
end)

local function outside(player)
    local out = true
    pcall(function() out = player:getCurrentSquare():isOutside() == true end)
    return out
end

DanTraits_AddHook("laundryWashed", function(_, player, item, method, bloody)
    if not player then return nil end
    if method == "bleach" and DanTraits_AsthmaFumes and not outside(player) then
        DanTraits_AsthmaFumes(player, LT.BLEACH_FUMES)
    end
    if method == "bleach" and hasTrait(player, "sensitiveskin") then
        DanTraits_StatAdd(player:getStats(), CharacterStat.DISCOMFORT, LT.BLEACH_SKIN)
        DanTraits_Notify(player, "UI_DanTraits_SkinBleach")
    end
    if bloody and DanTraits_HasVanillaTrait(player, "base:hemophobic") then
        DanTraits_StatAdd(player:getStats(), CharacterStat.STRESS, LT.BLOOD_STRESS)
    end
    if method == "board" and DanTraits_BadBackStrain then
        DanTraits_BadBackStrain(player, LT.BOARD_STRAIN)
    end
    return nil
end)

-- Sensitive Skin ---------------------------------------------------------------------

-- known clean: washed since laundry has known it, or the outfit you started in
local function knownClean(s) return s ~= nil and ((s.n or 0) > 0 or s.ok == true) end
L.knownClean = knownClean

-- how itchy: each garment against the skin (shoes aside) that is damp, musty or
-- never washed counts 1, a musty one 2
function L.itch(player)
    local n = 0
    for _, item in ipairs(L.worn(player)) do
        if L.layer(item) >= 1 and L.location(item) ~= "shoes" then
            local s = L.state(item, false)
            if s and s.m then n = n + 2
            elseif L.wetness(item) >= L.C.DAMP_AT or not knownClean(s) then n = n + 1 end
        end
    end
    return n
end

function L.itchDiscomfort(n)
    if n <= 0 then return 0 end
    return math.min(LT.SKIN_CAP, LT.SKIN_BASE + LT.SKIN_PER * (n - 1))
end

local function updateSkinMinute(player, d)
    if not L.on() or not hasTrait(player, "sensitiveskin") then
        d.lnItch = nil
        return
    end
    if DanTraits_Asleep(player) then return end
    local n = L.itch(player)
    if n > 0 and not d.lnItch then DanTraits_Notify(player, "UI_DanTraits_SkinItch") end
    d.lnItch = n > 0 or nil
    if n > 0 then DanTraits_FloorUp(player:getStats(), CharacterStat.DISCOMFORT, L.itchDiscomfort(n), LT.SKIN_RAMP) end
end
DanTraits_Every("minute", "SensitiveSkin", updateSkinMinute, 41)

-- the clothes you start in count as washed
DanTraits_StartingKit({
    trait = "sensitiveskin",
    flag = "lnSkinStart",
    setup = function(player)
        for _, item in ipairs(L.carried(player)) do
            if L.isClothing(item) then
                local s = L.state(item, true)
                if s then s.ok = true end
            end
        end
    end,
})

-- a garment's tooltip says it has never been washed, for whoever it would itch
DanTraits_AddHook("laundryTooltip", function(lines, item)
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player or not hasTrait(player, "sensitiveskin") or L.layer(item) < 1 or L.location(item) == "shoes" then return nil end
    if knownClean(L.state(item, false)) then return nil end
    lines[#lines + 1] = { getText("Tooltip_DanTraits_NeverWashed"), true }
    return lines
end)
