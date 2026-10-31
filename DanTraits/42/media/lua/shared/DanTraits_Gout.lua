-- Project Zomboid Vitality Project: Gout (Age 2.0, 2026-10-31; the 40s and 50s).
--
-- A urate meter (gtUrate, 0..1) that rich food and drink fill and plain food
-- and water drain. It rises with every protein- or fat-heavy meal (the Cooking
-- overhaul's macro of the dish, by the portion eaten), with drink (by how
-- drunk you are, every minute), with thirst (a dry body concentrates it) and
-- with crash dieting (a day on Cut: true, and a trap). It drains on its own
-- over about four days, faster with water. Allopurinol, the daily pill, cuts
-- every rise and hurries the drain by GT_ALLO at full effect; it is the only
-- real control.
--
-- Past GT_FLARE_AT a flare can start: a chance each minute that adds up to
-- GT_FLARE_PER_DAY a day at a full meter (every ten days or so eating like a
-- king, a month or more eating carefully, nearly never with allopurinol kept
-- up). A flare takes one foot for three to five days: severe pain in it (a
-- part pain floor at GT_PAIN, so the Pain moodle sits at severe and sleep
-- suffers), the leg stiff so walking is slow (the thigh and shin, as Bad
-- Back's thrown-out legs), and no running or sprinting while it lasts. A
-- second flare within GT_AGAIN_DAYS has a GT_AGAIN_SPREAD percent chance of
-- taking the knee of that side too. Colchicine, the rescue pill, ends a
-- flare within a day when taken in its first GT_COLCHICINE_WITHIN_H hours
-- (later it halves what is left); painkillers take the pain down a step while
-- they are in the system; the stiffness is not pain and neither touches it.
-- A new character starts with a bottle of allopurinol, already in the
-- system, and a bottle of painkillers (Starting Medication).
--
-- Mod data: gtUrate, gtFlareMin (minutes of the flare left; nil for none),
-- gtParts ({ "Foot_L" } or with the knee), gtFlares, gtLastFlareH, gtDosed,
-- gtHighTold, gtKitGiven.
-- Console: gout [flare|end|urate <0..1>].
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local traitData = DanTraits_Data
local fraction = DanTraits_StatFraction
local clamp01 = DanTraits_Clamp01

-- the meter
local GT_FALL_H         = 96      -- hours for a full meter to drain on plain food and water
local GT_MEAL_RICH      = 0.08    -- a protein- or fat-heavy meal (a whole one) adds this
local GT_DRINK          = 0.0004  -- per minute at full intoxication (an evening's drinking: about 0.1)
local GT_THIRST_FROM    = 0.25    -- thirst (0..1) from which the body is dry enough to count...
local GT_THIRST         = 0.0002  -- ...this much a minute
local GT_CUT            = 0.0001  -- per minute on a Cut diet (crash dieting; the Cooking overhaul's diet)
local GT_WATER          = 0.02    -- off per litre of water drunk
local GT_ALLO           = 0.6     -- allopurinol at full effect: rises x (1 - this), the drain x (1 + this)
local GT_HIGH_NOTICE    = 0.7     -- the meter crossing this upward: a notice
-- the flare
local GT_FLARE_AT       = 0.7     -- urate from which a flare can start...
local GT_FLARE_PER_DAY  = 0.1     -- ...with this chance a day at a full meter (0 at GT_FLARE_AT, linear)
local GT_FLARE_MIN      = { 4320, 7200 }   -- three to five days
local GT_COLCHICINE_MIN = 1440    -- a dosed flare has at most a day left...
local GT_COLCHICINE_WITHIN_H = 12 -- ...when the pill is taken this early; later it halves what is left
local GT_PAIN           = 65      -- pain on the flaring part (severe)
local GT_PAIN_RAMP      = 5       -- pain added a minute at most
local GT_PAINKILLER     = 0.6     -- pain x this while painkillers are in the system (a step down)
local GT_STIFF_LEG      = 40      -- stiffness floor on the leg of the flaring foot (the game: slower walking)
local GT_AGAIN_DAYS     = 30      -- a second flare within this many days...
local GT_AGAIN_SPREAD   = 25      -- ...has this percent chance of taking the knee too
local GT_FEET           = { "Foot_L", "Foot_R" }
local GT_KNEE           = { Foot_L = "LowerLeg_L", Foot_R = "LowerLeg_R" }
local GT_THIGH          = { Foot_L = "UpperLeg_L", Foot_R = "UpperLeg_R" }
local GT_START_ALLO     = "DanTraits.Allopurinol"
local GT_START_PILLS    = "Base.Pills"

local MIN_H = 1 / 60

local function has(player) return player ~= nil and hasTrait(player, "gout") end

local function goutData(player)
    local d = traitData(player)
    d.gtUrate = d.gtUrate or 0
    return d
end

-- 0..1 how well allopurinol is working
local function allopurinol(player)
    if not DanTraits_MedEffect then return 0 end
    return clamp01(tonumber(DanTraits_MedEffect(player, "allopurinol")) or 0)
end

local function inFlare(d) return (d.gtFlareMin or 0) > 0 end
DanTraits_GoutInFlare = function(player)
    local d = player and player:getModData().DanTraits
    return d ~= nil and inFlare(d)
end

-- the meter moved by `amount` (rises cut by allopurinol, falls hurried by it)
local function moveUrate(player, d, amount)
    local e = allopurinol(player)
    if amount > 0 then amount = amount * (1 - GT_ALLO * e) else amount = amount * (1 + GT_ALLO * e) end
    local was = d.gtUrate
    d.gtUrate = clamp01(d.gtUrate + amount)
    if was < GT_HIGH_NOTICE and d.gtUrate >= GT_HIGH_NOTICE and not d.gtHighTold then
        d.gtHighTold = true
        notify(player, "UI_DanTraits_GoutHigh")
    elseif d.gtUrate < GT_HIGH_NOTICE then
        d.gtHighTold = nil
    end
end

-- a flare starts in one foot; the knee too, sometimes, when the last one was recent
local function startFlare(player, d, forced)
    local now = DanTraits_WorldHours()
    local foot = GT_FEET[ZombRand(#GT_FEET) + 1] or GT_FEET[1]
    local parts = { foot }
    local recent = d.gtLastFlareH ~= nil and (now - d.gtLastFlareH) < GT_AGAIN_DAYS * 24
    if recent and (forced or DanTraits_RollPercent(GT_AGAIN_SPREAD)) then parts[#parts + 1] = GT_KNEE[foot] end
    d.gtParts = parts
    d.gtFlareMin = math.floor(DanTraits_RandRange(GT_FLARE_MIN[1], GT_FLARE_MIN[2]))
    d.gtFlares = (d.gtFlares or 0) + 1
    d.gtLastFlareH = now
    d.gtDosed = nil
    notify(player, #parts > 1 and "UI_DanTraits_GoutFlareKnee" or "UI_DanTraits_GoutFlare")
end

local function endFlare(player, d)
    d.gtFlareMin, d.gtParts, d.gtDosed = nil, nil, nil
    notifyGood(player, "UI_DanTraits_GoutFlareOver")
end

-- the pain's relief now: painkillers take it down a step
local function painScale(player)
    if not DanTraits_MedEffect then return 1 end
    local e = clamp01(tonumber(DanTraits_MedEffect(player, "painkillers")) or 0)
    return 1 - (1 - GT_PAINKILLER) * e
end

local function updateGoutMinute(player, d)
    d = goutData(player)
    local stats = player:getStats()
    -- the meter: drink, thirst and dieting raise it, time and water lower it
    local rise = 0
    pcall(function() rise = rise + GT_DRINK * fraction(stats, CharacterStat.INTOXICATION) end)
    pcall(function() if fraction(stats, CharacterStat.THIRST) >= GT_THIRST_FROM then rise = rise + GT_THIRST end end)
    if d.ckDiet == "cut" then rise = rise + GT_CUT end
    if rise > 0 then moveUrate(player, d, rise) end
    moveUrate(player, d, -MIN_H / GT_FALL_H)

    if inFlare(d) then
        d.gtFlareMin = d.gtFlareMin - 1
        if d.gtFlareMin <= 0 then endFlare(player, d) return end
        local pain = GT_PAIN * painScale(player)
        for _, part in ipairs(d.gtParts or {}) do
            DanTraits_PartPainAtLeast(player, part, pain, GT_PAIN_RAMP)
        end
        local foot = d.gtParts and d.gtParts[1]
        if foot and GT_THIGH[foot] then
            DanTraits_PartStiffAtLeast(player, GT_THIGH[foot], GT_STIFF_LEG)
            DanTraits_PartStiffAtLeast(player, GT_KNEE[foot], GT_STIFF_LEG)
        end
        return
    end
    -- no flare: can one start?
    if d.gtUrate <= GT_FLARE_AT then return end
    local chancePerMin = GT_FLARE_PER_DAY * (d.gtUrate - GT_FLARE_AT) / (1 - GT_FLARE_AT) / 1440
    if DanTraits_Roll(chancePerMin) then startFlare(player, d) end
end

-- per frame in a flare: no running, no sprinting
local function updateGoutFrame(player, d)
    if not inFlare(d) then return end
    local tried = false
    pcall(function()
        if player:isSprinting() then player:setSprinting(false); tried = true end
        if player:isRunning() then player:setRunning(false); tried = true end
    end)
    if tried then pcall(function() player:setMoodleCantSprint(true) end) end
end

-- the trait gone: the meter stays (harmless), the flare ends quietly
local function clearGout(player, d)
    if d then d.gtFlareMin, d.gtParts, d.gtDosed = nil, nil, nil end
end

-- rich food: a protein- or fat-heavy dish (the Cooking overhaul's macro), by the portion eaten
local function isRich(item)
    local macro = nil
    if DanTraits_CookMacroOf then
        local ok, m = pcall(DanTraits_CookMacroOf, item)
        if ok then macro = m end
    end
    return macro == "protein" or macro == "fat"
end
DanTraits_AddHook("eat", function(_, player, item, portion)
    if not has(player) or not item or not isRich(item) then return nil end
    local d = goutData(player)
    moveUrate(player, d, GT_MEAL_RICH * math.max(0, math.min(1, tonumber(portion) or 1)))
    return nil
end)

-- water lowers it
DanTraits_AddHook("drink", function(_, player, container, litres, name)
    if not has(player) then return nil end
    name = name or (DanTraits_FluidName and DanTraits_FluidName(container))
    if not name or string.lower(tostring(name)) ~= "water" then return nil end
    moveUrate(player, goutData(player), -GT_WATER * math.max(0, tonumber(litres) or 0))
    return nil
end)

-- colchicine during a flare: the flare has a day left at most (taken early), or half what it had
DanTraits_AddHook("pill", function(_, player, kind)
    if string.lower(tostring(kind or "")) ~= "colchicine" or not has(player) then return nil end
    local d = goutData(player)
    if not inFlare(d) then return nil end
    local since = DanTraits_WorldHours() - (d.gtLastFlareH or 0)
    if since <= GT_COLCHICINE_WITHIN_H then
        d.gtFlareMin = math.min(d.gtFlareMin, GT_COLCHICINE_MIN)
    else
        d.gtFlareMin = math.max(60, math.floor(d.gtFlareMin / 2))
    end
    d.gtDosed = true
    notifyGood(player, "UI_DanTraits_GoutColchicine")
    return nil
end)

-- read by Moodles: 0 none, 1 the meter high, 2 a flare with relief in the system, 3 a raw flare
function DanTraits_GoutMoodle(player, d)
    if not has(player) or not d then return 0 end
    if inFlare(d) then
        local covered = d.gtDosed or (DanTraits_MedCovered and DanTraits_MedCovered(player, "painkillers"))
        return covered and 2 or 3
    end
    if (d.gtUrate or 0) >= GT_FLARE_AT then return 1 end
    return 0
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.gout = function(player, args)
    local d = goutData(player)
    if args[1] == "flare" then startFlare(player, d, true)
    elseif args[1] == "end" then if inFlare(d) then endFlare(player, d) end
    elseif args[1] == "urate" then d.gtUrate = clamp01(tonumber(args[2]) or d.gtUrate) end
    return "gout: urate " .. string.format("%.2f", d.gtUrate) .. ", allopurinol " .. string.format("%.2f", allopurinol(player))
        .. (inFlare(d) and (", flare " .. d.gtFlareMin .. " min left in " .. table.concat(d.gtParts or {}, "+")) or ", no flare")
        .. ", flares " .. tostring(d.gtFlares or 0)
end

DanTraits_Every("minute", "Gout", updateGoutMinute, 40, { trait = "gout", clear = clearGout })
DanTraits_Every("frame", "Gout", updateGoutFrame, 40, { trait = "gout" })

DanTraits_StartingKit({ trait = "gout", flag = "gtKitGiven", items = { GT_START_ALLO, GT_START_PILLS }, meds = { "allopurinol" } })
