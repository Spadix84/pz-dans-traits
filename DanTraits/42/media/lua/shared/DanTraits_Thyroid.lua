-- Project Zomboid Vitality Project: Underactive Thyroid (Age 2.0, 2026-10-31; the 40s and 50s).
--
-- The purest "find your medication" condition. Untreated (thUntreated, 0..1:
-- one minus how well levothyroxine is working), the body runs slow:
-- tiredness builds faster (the fatigueRise stat delta pipeline), the mood
-- sits a little low (unhappiness every waking minute), the cold bites
-- (below TH_COLD_C the tiredness and the mood cost more), and weight comes on
-- easier (a slow drift upward while under TH_WEIGHT_CAP). One daily pill of
-- levothyroxine (new bottle, the shared medication system's "levothyroxine":
-- a week to build up, a week to fade) removes all of it; running out brings it
-- back over that week. A new character starts with a full bottle, already in
-- the system (Starting Medication).
--
-- Mod data: thUntreated, thTold, thKitGiven.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local clamp01 = DanTraits_Clamp01

local TH_FATIGUE      = 0.15    -- tiredness builds x (1 + this x untreated)
local TH_MOOD         = 0.0004  -- unhappiness (fraction of its range) a waking minute at fully untreated
local TH_COLD_C       = 12      -- air below this: the cold bites...
local TH_COLD_FATIGUE = 0.1     -- ...tiredness x (1 + this x untreated) more...
local TH_COLD_MOOD    = 2       -- ...and the mood cost x this
local TH_GAIN_KG_DAY  = 0.05    -- weight drifts up this much a day at fully untreated...
local TH_WEIGHT_CAP   = 95      -- ...while under this
local TH_TOLD_AT      = 0.5     -- untreated crossing this upward: a notice
local TH_START_PILLS  = "DanTraits.Levothyroxine"

local function has(player) return player ~= nil and hasTrait(player, "thyroid") end

local function untreatedOf(player)
    local d = player and player:getModData().DanTraits
    if not d or not has(player) then return 0 end
    return d.thUntreated or 0
end
DanTraits_ThyroidUntreated = untreatedOf

local function cold(player)
    local air = DanTraits_AirTemp(player)
    return type(air) == "number" and air < TH_COLD_C
end

local function updateThyroidMinute(player, d)
    local e = 0
    if DanTraits_MedEffect then e = clamp01(tonumber(DanTraits_MedEffect(player, "levothyroxine")) or 0) end
    local u = 1 - e
    if (d.thUntreated or 0) < TH_TOLD_AT and u >= TH_TOLD_AT and not d.thTold then
        d.thTold = true
        notify(player, "UI_DanTraits_ThyroidLow")
    elseif u < TH_TOLD_AT then
        d.thTold = nil
    end
    d.thUntreated = u
    if u <= 0 then return end
    if not DanTraits_Asleep(player) then
        local mood = TH_MOOD * u
        if cold(player) then mood = mood * TH_COLD_MOOD end
        DanTraits_StatAdd(player:getStats(), CharacterStat.UNHAPPINESS, mood * DanTraits_StatMax(CharacterStat.UNHAPPINESS))
    end
    -- weight comes on easier
    pcall(function()
        local n = player:getNutrition()
        local w = tonumber(n:getWeight())
        if w and w < TH_WEIGHT_CAP then n:setWeight(math.min(TH_WEIGHT_CAP, w + TH_GAIN_KG_DAY * u / 1440)) end
    end)
end

local function clearThyroid(player, d)
    if d then d.thUntreated, d.thTold = nil, nil end
end

-- tiredness builds faster, more so in the cold
DanTraits_AddHook("fatigueRise", function(delta, player)
    local u = untreatedOf(player)
    if u <= 0 or DanTraits_Asleep(player) then return nil end
    local k = 1 + TH_FATIGUE * u
    if cold(player) then k = k * (1 + TH_COLD_FATIGUE * u) end
    return delta * k
end)

DanTraits_Every("minute", "Thyroid", updateThyroidMinute, 40, { trait = "thyroid", clear = clearThyroid })

DanTraits_StartingKit({ trait = "thyroid", flag = "thKitGiven", items = { TH_START_PILLS }, meds = { "levothyroxine" } })
