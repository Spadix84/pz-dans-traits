-- Project Zomboid Vitality Project: blood (health overhaul, phase 1).
--
-- Not a trait: every character has it. Bleeding drains blood instead of
-- health. Two stores, as fractions of normal:
--   volume     what a bleed takes; low volume is shock. Tiers follow the four
--              classes of haemorrhage: under 15% lost nothing shows; 15-30%
--              pale and weak; 30-40% light-headed, can't sprint, anxious;
--              40%+ shock, draining health; half gone is death. Refills in
--              about a day with enough to drink (and makes you thirsty).
--   red cells  lost with the blood, rebuilt over about a week: food, sleep
--              and Vitality help (Anaemic rebuilds slower and spends iron).
--              While short, endurance recovers slower (through the enduranceRegen
--              hook of the stat delta pipeline) and tiredness comes
--              sooner, after the volume is back.
--
-- Each bleeding part loses blood by its bleeding time (the game's own clock
-- for how bad the bleed is), where it is (neck worst, then head, thigh,
-- groin, torso) and how it is dressed: a bandage slows it to a tenth, a
-- shard or bullet left in bleeds through the bandage, a spent (soaked)
-- bandage only halves it, stitches stop it.
--
-- Vanilla's health loss from bleeding is given back tick by tick. What
-- vanilla does (BodyPart.DamageUpdate, read from the jar), all x the part's
-- damageScaler x the game-time multiplier:
--   bleeding, unbandaged: BodyDamage.ReduceGeneralHealth(0.2857 x bleedingTime / 10),
--     then OnPlayerGetDamage(char, "BLEEDING", that amount). Bandaged: nothing.
--   wound damage to the part itself, never reported: deep wound, not stitched,
--     -3.125 (bandaged -1.5625); scratch -0.9375, cut -1.875, bite -2.1875,
--     unbandaged only. Kept: the injury hurts until it is dressed and stitched.
--   a shard left in holds bleedingTime and deepWoundTime at 3 or more (the
--     wound never closes) and grows wound infection ten times faster.
--   a bandage clears the bleeding/cut/deep wound/stitched flags but keeps
--     their times (and runs bleedingTime down ten times faster); stitching
--     zeroes bleedingTime and deepWoundTime.
-- Overall health is 100 - sum((100 - part health) x part damage modifier)
-- (BodyDamage.calculateOverallHealth), and ReduceGeneralHealth(x) takes
-- x / 17 / modifier off every part, so the refund puts exactly that back.
-- (AddGeneralHealth is not its inverse: it spreads over damaged parts only.)
-- Vanilla's regeneration also goes only to parts under 100, so overall
-- health moves differently depending on which parts are damaged.
--
-- In shock you can pass out for 5 to 15 game minutes (DanTraits_Faint.lua),
-- 2% a minute, 6% bleeding out, no more than once in half an hour.
require "DanTraits"

local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local traitData = DanTraits_Data
local fraction = DanTraits_StatFraction

local BL_RATE          = 0.008   -- volume per game minute at bleeding time 10, unbandaged, an arm
local BL_BANDAGED      = 0.1     -- x rate under a bandage
local BL_LODGED        = 0.35    -- x rate under a bandage with a shard or bullet still in
local BL_SOAKED        = 0.5     -- x rate under a spent (soaked, dirty) bandage
local BL_PART = { Neck = 3.0, Head = 1.5, UpperLeg_L = 1.5, UpperLeg_R = 1.5, Groin = 1.5,
                  Torso_Upper = 1.2, Torso_Lower = 1.2, Hand_L = 0.7, Hand_R = 0.7, Foot_L = 0.7, Foot_R = 0.7 }
local BL_TIER          = { 0.15, 0.30, 0.40, 0.45 }  -- volume lost: pale | light-headed | shock | bleeding out
local BL_DEATH         = 0.50    -- volume lost: the heart stops
local BL_MOODLE_TIER   = { BL_TIER[1] / BL_DEATH, BL_TIER[2] / BL_DEATH, BL_TIER[3] / BL_DEATH, BL_TIER[4] / BL_DEATH }  -- the moodle's tiers, as fractions of the way to death
local BL_VOL_DAY       = 0.35    -- volume refilled per game day, well watered
local BL_VOL_THIRST    = 1.5     -- thirst per unit of volume refilled
local BL_THIRST_OK     = 0.25    -- refills at full rate under this thirst...
local BL_THIRST_DRY    = 0.75    -- ...and not at all over this
local BL_CELL_DAY      = 0.05    -- red cells rebuilt per game day, fed and rested
local BL_CELL_ASLEEP   = 1.5     -- x while asleep
local BL_CELL_HUNGRY   = 0.25    -- x when starving (hunger 0.7 and over), full rate under 0.35
local BL_CELL_VITALITY = 0.25    -- x (1 + this x Vitality effect)
local BL_CELL_WEAK     = 0.9     -- short of red cells under this...
local BL_CELL_FLOOR    = 0.5     -- ...fully short at this
local BL_WEAK_ENDURANCE = 0.5    -- endurance recovery x (1 - this x weakness)
local BL_WEAK_FATIGUE  = 0.0003  -- tiredness per minute awake at full weakness
local BL_ENDURANCE     = { 0.25, 0.5, 0.8, 0.9 }    -- endurance recovery cut, by tier
local BL_PANIC         = { 0, 0.2, 0.4, 0.6 }       -- panic floor (fraction), by tier
local BL_ENDURANCE_CAP = { 1, 1, 0.3, 0.15 }        -- endurance ceiling, by tier
local BL_SHOCK_HEALTH  = 0.5     -- health per minute entering shock...
local BL_SHOCK_HEALTH_MAX = 3    -- ...rising to this by BL_DEATH
local BL_DEATH_HEALTH  = 10      -- health per minute past BL_DEATH
local BL_FAINT         = { 0, 0, 0.02, 0.06 }  -- chance a minute of passing out, by tier (shock, bleeding out)
local BL_FAINT_MIN     = { 5, 15 }  -- game minutes out
local BL_FAINT_GAP     = 30      -- minutes before it can happen again

local clamp01 = DanTraits_Clamp01

local function sandboxOn() return DanTraits_SandboxOn("BloodEnabled") end
function DanTraits_BloodActive() return sandboxOn() end

local function blData(player)
    local d = traitData(player)
    if d.bloodVol == nil then d.bloodVol = 1 end
    if d.bloodCells == nil then d.bloodCells = 1 end
    return d
end

local function tierOf(lost) return DanTraits_TierOf(lost, BL_TIER) end

-- 0..1 how short of red cells
local function weaknessOf(cells)
    return clamp01((BL_CELL_WEAK - cells) / (BL_CELL_WEAK - BL_CELL_FLOOR))
end

-- the exact inverse of BodyDamage.ReduceGeneralHealth(amount)
local function undoGeneralHealthLoss(player, amount)
    return pcall(function()
        local parts = player:getBodyDamage():getBodyParts()
        local n = parts:size()
        for i = 0, n - 1 do
            local modifier = BodyPartType.getDamageModifyer(i)
            if modifier and modifier > 0 then parts:get(i):AddHealth(amount / n / modifier) end
        end
    end)
end

local function onBloodGetDamage(character, damageType, amount)
    if damageType ~= "BLEEDING" or not sandboxOn() then return end
    local player = getSpecificPlayer(0)
    if not player or character ~= player then return end
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    local d = traitData(player)
    if undoGeneralHealthLoss(player, amount) then
        d.bloodRefunded = (d.bloodRefunded or 0) + amount
    end
end

local partIs = DanTraits_PartIs

-- volume lost per minute from one part, before hooks; nil when not bleeding.
-- Read from the bleeding time, not the flag: a bandage clears the part's
-- bleeding, cut, deep wound and stitched flags and keeps the times
-- (BodyPart.setBandaged; taking it off sets the flags again from the
-- times). Stitching zeroes the bleeding time (BodyPart.setStitched).
local function partRate(part)
    local t = 0
    pcall(function() t = part:getBleedingTime() or 0 end)
    if t <= 0 then return nil end
    local name = ""
    pcall(function() name = tostring(part:getType()) end)
    local rate = BL_RATE * t / 10 * (BL_PART[name] or 1)
    local bandaged = partIs(part, "bandaged")
    if bandaged then
        local lodged = partIs(part, "haveGlass") or partIs(part, "haveBullet")
        local soaked = false
        pcall(function() soaked = part:getBandageLife() <= 0 end)
        rate = rate * ((soaked and BL_SOAKED) or (lodged and BL_LODGED) or BL_BANDAGED)
    end
    return rate, name, bandaged
end
DanTraits_BloodPartRate = partRate

local function round3(x) return DanTraits_Round(x, 3) end

-- how much blood is going, and from where
local function bleedMinute(player, d)
    local total, sources = 0, {}
    pcall(function()
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            local rate, name, bandaged = partRate(part)
            if rate then
                rate = DanTraits_RunHooks("bloodBleed", rate, player, part, bandaged)
                total = total + rate
                sources[#sources + 1] = name .. " " .. tostring(round3(rate * 100)) .. "%" .. (bandaged and " (bandaged)" or "")
            end
        end
    end)
    d.bloodSources = table.concat(sources, ", ")
    return total
end

local function refill(player, d, stats, asleep)
    -- volume: water drawn in from the gut, so it needs drinking
    if d.bloodVol < 1 then
        local thirst = fraction(stats, CharacterStat.THIRST)
        local rate = clamp01((BL_THIRST_DRY - thirst) / (BL_THIRST_DRY - BL_THIRST_OK))
        local gain = math.min(1 - d.bloodVol, DanTraits_RunHooks("bloodVolRefill", BL_VOL_DAY / 1440 * rate, player, d))
        if gain > 0 then
            d.bloodVol = d.bloodVol + gain
            DanTraits_StatAdd(stats, CharacterStat.THIRST, gain * BL_VOL_THIRST)
        end
    end
    -- red cells: slow, fed by food and rest
    if d.bloodCells < 1 then
        local hunger = fraction(stats, CharacterStat.HUNGER)
        local fed = 1 - (1 - BL_CELL_HUNGRY) * clamp01((hunger - 0.35) / 0.35)
        local vitality = 0
        if DanTraits_VitalityEffect then pcall(function() vitality = DanTraits_VitalityEffect(player) or 0 end) end
        local rate = BL_CELL_DAY / 1440 * fed * (asleep and BL_CELL_ASLEEP or 1) * (1 + BL_CELL_VITALITY * vitality)
        rate = DanTraits_RunHooks("bloodCellRebuild", rate, player, d)
        local gain = math.max(0, math.min(1 - d.bloodCells, rate))
        if gain > 0 then
            d.bloodCells = d.bloodCells + gain
            DanTraits_RunHooks("bloodCellsRebuilt", nil, player, gain)
        end
    end
end

local TIER_NOTICE = { "UI_DanTraits_BloodPale", "UI_DanTraits_BloodDizzy", "UI_DanTraits_BloodShock", "UI_DanTraits_BloodBleedingOut" }

local function updateMoodle(player, lost)
    DanTraits_BadMoodle(player, "BloodLoss", math.min(1, lost / BL_DEATH), BL_MOODLE_TIER)
end

-- switched off mid-game (sandbox, a server admin): stand down once, so the
-- tier, the weakness and the moodle do not stay on (Fear of Blood reads
-- bloodLossMin every minute). The volume and the red cells are kept and it
-- all resumes if it is switched back on.
local function standDown(player, d)
    if not d or ((d.bloodTier or 0) <= 0 and (d.bloodWeak or 0) <= 0 and (d.bloodLossMin or 0) <= 0) then return end
    d.bloodLossMin, d.bloodTier, d.bloodWeak = 0, 0, 0
    updateMoodle(player, 0)
end

local function updateBloodMinute(player, d)
    if not sandboxOn() then standDown(player, d) return end
    d = blData(player)
    local stats = player:getStats()
    local asleep = DanTraits_Asleep(player)
    local loss = math.min(d.bloodVol, bleedMinute(player, d))
    d.bloodLossMin = loss
    d.bloodVol = d.bloodVol - loss
    d.bloodCells = math.max(0, d.bloodCells - loss)
    refill(player, d, stats, asleep)

    local lost = clamp01(1 - d.bloodVol)
    local tier = tierOf(lost)
    local before = d.bloodTier or 0
    if tier > before then notify(player, TIER_NOTICE[tier])
    elseif tier < before and tier <= 1 and before >= 2 then notifyGood(player, "UI_DanTraits_BloodSteadier") end
    d.bloodTier = tier
    d.bloodWeak = weaknessOf(d.bloodCells)
    updateMoodle(player, lost)

    if tier >= 2 and not asleep then
        -- straight to the floor (a ramp as wide as the stat)
        pcall(function()
            local panic = CharacterStat.PANIC
            DanTraits_FloorUp(stats, panic, BL_PANIC[tier] * DanTraits_StatMax(panic), math.huge)
        end)
    end
    -- fainting spells in shock (DanTraits_Faint.lua)
    if (d.bloodFaintGap or 0) > 0 then d.bloodFaintGap = d.bloodFaintGap - 1 end
    if not asleep and (BL_FAINT[tier] or 0) > 0 and (d.bloodFaintGap or 0) <= 0 and DanTraits_PassOut then
        if DanTraits_Roll(BL_FAINT[tier]) then
            local minutes = DanTraits_RandRange(BL_FAINT_MIN[1], BL_FAINT_MIN[2])
            if DanTraits_PassOut(player, minutes, "UI_DanTraits_BloodComeTo") then
                d.bloodFaintGap = BL_FAINT_GAP
            end
        end
    end
    if tier >= 3 then
        local over = (lost - BL_TIER[3]) / (BL_DEATH - BL_TIER[3])
        local health = lost >= BL_DEATH and BL_DEATH_HEALTH
            or (BL_SHOCK_HEALTH + (BL_SHOCK_HEALTH_MAX - BL_SHOCK_HEALTH) * clamp01(over))
        pcall(function() player:getBodyDamage():ReduceGeneralHealth(health) end)
    end
    if d.bloodWeak > 0 and not asleep then
        DanTraits_StatAdd(stats, CharacterStat.FATIGUE, BL_WEAK_FATIGUE * d.bloodWeak)
    end
end

-- slower endurance recovery, through the stat delta pipeline (DanTraits_Util.lua)
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d or d.bloodVol == nil or not sandboxOn() then return nil end
    local tier = d.bloodTier or 0
    local weak = d.bloodWeak or 0
    if tier <= 0 and weak <= 0 then return nil end
    local cut = 1 - (tier > 0 and BL_ENDURANCE[tier] or 0)
    return delta * cut * (1 - BL_WEAK_ENDURANCE * weak)
end)

-- per frame: an endurance ceiling in shock (not a delta, so not the pipeline's),
-- no sprinting when light-headed
local function updateBloodFrame(player)
    local d = player:getModData().DanTraits
    if not d or d.bloodVol == nil then return end
    local tier = d.bloodTier or 0
    if tier > 0 then
        local stats = player:getStats()
        local endurance = stats:get(CharacterStat.ENDURANCE)
        if endurance > BL_ENDURANCE_CAP[tier] then
            endurance = BL_ENDURANCE_CAP[tier]
            pcall(function() stats:set(CharacterStat.ENDURANCE, endurance) end)
            -- tell the pipeline about the clamp so the next frame's regen is measured from it
            DanTraits_DeltaRemember(d, "enduranceRegen", endurance)
        end
    end
    if tier >= 2 then
        pcall(function() player:setSprinting(false) end)
        pcall(function() player:setMoodleCantSprint(true) end)
    end
end

-- Debugging: every part under full health, its change over the minute and
-- its weight in overall health: "UpperLeg_L 62.3 (-0.91) x0.2, ..."
local lastPartHealth = {}
local round2 = DanTraits_Round
local function partsLine(player)
    local out = {}
    pcall(function()
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            local h = part:getHealth()
            local name = tostring(part:getType())
            local was = lastPartHealth[name]
            lastPartHealth[name] = h
            if h < 99.995 or (was and was < 99.995) then
                local modifier = 0
                pcall(function() modifier = BodyPartType.getDamageModifyer(i) end)
                local change = was and (" (" .. tostring(round2(h - was)) .. ")") or ""
                out[#out + 1] = name .. " " .. tostring(round2(h)) .. change .. " x" .. tostring(round2(modifier))
            end
        end
    end)
    return table.concat(out, ", ")
end

local function updateBloodDebug(player, d)
    if not d.bloodDebug then return end
    d.bloodDbgParts = partsLine(player)
    local health = nil
    pcall(function() health = player:getBodyDamage():getOverallBodyHealth() end)
    if health and d.bloodDbgHealth then d.bloodDbgHealthMin = health - d.bloodDbgHealth end
    d.bloodDbgHealth = health
    d.bloodDbgRefundMin = (d.bloodRefunded or 0) - (d.bloodDbgRefundLast or 0)
    d.bloodDbgRefundLast = d.bloodRefunded or 0
end

-- console: blood <volume> [cells] | blood debug on|off | blood reset
function DanTraits_BloodCommand(player, args)
    local d = blData(player)
    local a = string.lower(tostring(args[1] or ""))
    if a == "debug" then
        d.bloodDebug = args[2] ~= "off"
        if not d.bloodDebug then d.bloodDbgParts, d.bloodDbgHealth, d.bloodDbgHealthMin, d.bloodDbgRefundMin = nil, nil, nil, nil end
        return "blood debug " .. (d.bloodDebug and "on" or "off")
    end
    if a == "reset" then
        d.bloodVol, d.bloodCells, d.bloodTier = 1, 1, 0
        return "blood: full"
    end
    local vol = tonumber(args[1])
    if not vol then return "blood <volume 0..1> [cells 0..1] | blood debug on|off | blood reset" end
    d.bloodVol = clamp01(vol)
    d.bloodCells = clamp01(tonumber(args[2]) or math.min(d.bloodCells, d.bloodVol))
    return "blood: volume " .. tostring(d.bloodVol) .. ", cells " .. tostring(d.bloodCells)
end

-- Wounds for testing, by short part name and kind. "glass" is a deep wound
-- with the shard still in it (the game's own shard wound).
function DanTraits_BloodTestWound(player, partName, kind)
    local typeName = DanTraits_PartNames[string.lower(tostring(partName or ""))]
    if not typeName then return "wound: part is one of hand/forearm/upperarm/thigh/shin/foot _l/_r, chest, belly, groin, head, neck" end
    local part = DanTraits_PartOf(player, partName)
    if not part then return "wound: no body part " .. typeName end
    kind = string.lower(tostring(kind or "deep"))
    local ok, err
    if kind == "glass" then
        ok, err = pcall(function() part:generateDeepShardWound() end)
    elseif kind == "deep" then
        ok, err = pcall(function() part:generateDeepWound() end)
    elseif kind == "cut" then
        ok, err = pcall(function() part:setCut(true) end)
    elseif kind == "scratch" then
        ok, err = pcall(function() part:setScratched(true, true) end)
    else
        return "wound: kind is scratch | cut | deep | glass"
    end
    if not ok then return "wound failed: " .. tostring(err) end
    local t = 0
    pcall(function() t = part:getBleedingTime() or 0 end)
    return "wound: " .. kind .. " on " .. typeName .. ", bleeding time " .. tostring(t)
end

-- console commands, picked up by the telemetry
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.blood = DanTraits_BloodCommand
DanTraits_ExtraCommands.wound = function(player, args) return DanTraits_BloodTestWound(player, args[1], args[2]) end

Events.OnPlayerGetDamage.Add(onBloodGetDamage)
DanTraits_Every("minute", "Blood", function(player, d)
    updateBloodMinute(player, d)
    updateBloodDebug(player, d)
end, 20)
DanTraits_Every("frame", "Blood", function(player)
    if sandboxOn() then updateBloodFrame(player) end
end, 20)
