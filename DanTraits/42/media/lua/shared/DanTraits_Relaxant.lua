-- Project Zomboid Vitality Project: the muscle relaxant (DanTraits.Cyclobenzaprine,
-- 1993's usual prescription for a strain or a bad back). Not a trait: anyone
-- can take it. The dose, the drowsiness and dry mouth while it works, the
-- side effects and too many at once are the shared medication list's
-- (DanTraits_Meds.lua, "cyclobenzaprine": one covers about 8 hours). While
-- covered, this file does what it is for:
--   * stiffness anywhere fades twice as fast (Age's stiffFade hook), so
--     sore muscles hurt less;
--   * a pulled muscle hurts and stiffens half as much (strainRelief,
--     DanTraits_Fitness.lua); it heals no sooner;
--   * a Bad Back's pain and stiffness halve, a thrown-out one's ease by a
--     third (backRelief, DanTraits_AgeTraits.lua); the load and the chance of
--     throwing it out are unchanged;
-- and what comes with it:
--   * training on it: Fitness and Strength experience x0.85 (the muscles
--     will not push), and a pull is half as likely again (the warning ache is
--     masked);
--   * drink on top: much drowsier (RX_DRUNK_FATIGUE a minute awake, at any
--     level of the Drunk moodle).
require "DanTraits"

local RX_ID            = "cyclobenzaprine"
local RX_STIFF_FADE    = 2       -- stiffness fades x this
local RX_STRAIN        = 0.5     -- a pulled muscle's pain and held stiffness x this
local RX_BACK          = 0.5     -- a Bad Back's pain and stiffness x this...
local RX_BACK_OUT      = 0.65    -- ...and thrown out
local RX_XP            = 0.85    -- Fitness and Strength experience from training x this
local RX_STRAIN_RISK   = 1.5     -- the chance of a pull x this
local RX_DRUNK_FATIGUE = 0.0008  -- tiredness a minute, awake, drunk on top of it

local function covered(player)
    return player ~= nil and DanTraits_MedCovered ~= nil and DanTraits_MedCovered(player, RX_ID)
end
DanTraits_RelaxantOn = covered

DanTraits_AddHook("stiffFade", function(k, player)
    if covered(player) then return k * RX_STIFF_FADE end
    return nil
end)

DanTraits_AddHook("strainRelief", function(k, player)
    if covered(player) then return k * RX_STRAIN end
    return nil
end)

DanTraits_AddHook("backRelief", function(k, player, d, out)
    if covered(player) then return k * (out and RX_BACK_OUT or RX_BACK) end
    return nil
end)

DanTraits_AddHook("fitnessXp", function(k, player)
    if covered(player) then return k * RX_XP end
    return nil
end)

DanTraits_AddHook("fitnessStrain", function(risk, player)
    if covered(player) then return risk * RX_STRAIN_RISK end
    return nil
end)

local function updateRelaxantMinute(player, d)
    if not covered(player) or DanTraits_Asleep(player) then return end
    local drunk = 0
    pcall(function() drunk = player:getMoodles():getMoodleLevel(MoodleType.DRUNK) or 0 end)
    if drunk > 0 then DanTraits_StatAdd(player:getStats(), CharacterStat.FATIGUE, RX_DRUNK_FATIGUE) end
end

DanTraits_Every("minute", "Relaxant", updateRelaxantMinute, 60)
