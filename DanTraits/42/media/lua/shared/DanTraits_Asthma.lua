-- Project Zomboid Vitality Project: Brittle Asthma.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

-- Brittle Asthma -------------------------------------------------------------
-- Airway irritation (0..1) lives in mod data. It rises with cold air, nearby
-- corpses, exertion and a wound infection's fever (no mask helps), falls when resting in clean warm air, and drives
-- four tiers: warning, halved endurance recovery (the enduranceRegen hook of
-- the stat delta pipeline), no recovery plus coughing, and
-- a full attack that drains endurance and health (to a 20% floor) while the
-- player coughs loudly enough to pull zombies. The inhaler item knocks it
-- down by half. Coughs are real world sounds: zombies hear them. They go
-- through the one shared cough (DanTraits_Cough in DanTraits_Util.lua, one gap
-- of a few minutes across Asthma and Smoker); only an attack's burst forces it.
-- Smoking makes it worse two ways (Smoker lives in DanTraits_Smoker.lua): each
-- cigarette adds airway irritation (DanTraits_AsthmaSmoked, called from
-- Smoker's dose), and damaged lungs (d.nicLungs, read straight from mod data)
-- raise the exertion and sprint build and slow every recovery.
-- An attack that has emptied endurance for ASTHMA_FAINT_AFTER_MIN minutes in a
-- row can black you out (once per attack, a deep faint: DanTraits_PassOut).
-- While out you are not exerting, so nothing builds and irritation decays at
-- the attack rate; the attack itself carries on.
local ASTHMA_DECAY_CALM     = 0.004   -- per minute, resting in clean warm air (about four hours to clear fully)
local ASTHMA_DECAY_ASLEEP   = 0.008
local ASTHMA_DECAY_ATTACK   = 0.001   -- an attack does not meaningfully ease on its own
local ASTHMA_COLD_TEMP_C    = 10
local ASTHMA_COLD_RATE      = 0.005   -- per minute below the temperature
local ASTHMA_CORPSE_RATE    = 0.004   -- per minute per corpse within 3 tiles, up to 3
local ASTHMA_EXERT_ENDURANCE = 0.4    -- exertion build-up starts once endurance is under this
local ASTHMA_EXERT_RATE     = 0.014   -- per minute while exerted
local ASTHMA_SPRINT_RATE    = 0.008   -- per minute while sprinting or running (exercise is the classic trigger)
local ASTHMA_PANIC_MIN      = 20      -- panic below this (out of 100) does nothing
local ASTHMA_PANIC_RATE     = 0.010   -- per minute at maximum panic, scaling up linearly from the minimum; masks do not help
local ASTHMA_TIER           = { 0.25, 0.50, 0.75, 0.90 }
local ASTHMA_ATTACK_ENDS_AT = 0.75    -- hysteresis: an attack lasts until irritation drops below this
local ASTHMA_COUGH_MIN_T2   = 6       -- minutes between coughs at tier 2 (plus up to 4 more)
local ASTHMA_COUGH_RADIUS_T2 = 6
local ASTHMA_COUGH_MIN_T3   = 2       -- minutes between coughs at tier 3 (plus up to 2 more)
local ASTHMA_COUGH_RADIUS_T3 = 10
local ASTHMA_COUGH_RADIUS_T4 = 30
local ASTHMA_ATTACK_END_DRAIN = 0.15  -- endurance per minute during an attack (empty in ~6 min)
local ASTHMA_ATTACK_HP_DRAIN  = 0.75  -- overall health per minute during an attack
local ASTHMA_HEALTH_FLOOR     = 15    -- attack never takes health below this (%)
local ASTHMA_ATTACK_PANIC     = 5     -- panic added per minute during an attack (out of 100)
local ASTHMA_SMOKE        = 0.12    -- irritation added per cigarette (times the dose), no mask helps
local ASTHMA_LUNGS_BUILD    = 0.5     -- exertion and sprint build x (1 + this x lungs)
local ASTHMA_LUNGS_DECAY    = 0.3     -- decay x (1 - this x lungs)
local ASTHMA_FAINT_AFTER_MIN = 3   -- consecutive minutes of an attack with endurance at 0...
local ASTHMA_FAINT          = 0.15    -- ...then a chance per minute of passing out
local ASTHMA_FAINT_MIN      = { 2, 5 }   -- game minutes out (deep: stays down)
local ASTHMA_INHALER_RELIEF   = 0.5
local ASTHMA_INHALER_PANIC    = 10    -- a puff sets the heart racing (out of 100)
local ASTHMA_WAKE_TIER        = 3     -- asleep at this tier or worse: you wake up gasping
local ASTHMA_FEVER_RATE     = 0.004   -- per minute at full fever (wound infection), passive: no mask helps
local ASTHMA_MASK_GAS_PASSIVE = 0.2   -- multiplier on non-environmental build-up with a gas mask

local function asthmaData(player)
    local d = traitData(player)
    d.asthma = d.asthma or 0
    return d
end

-- 0 none, 1 dust/surgical (halves environmental), 2 gas mask / respirator
local function asthmaMaskLevel(player)
    local level = 0
    pcall(function()
        for _, loc in ipairs({ ItemBodyLocation.MASK_FULL, ItemBodyLocation.MASK_EYES, ItemBodyLocation.MASK }) do
            local item = loc and player:getWornItem(loc)
            if item then
                local name = tostring(item:getType() or "")
                local where = tostring(item:getBodyLocation() or "")
                if name:lower():find("gasmask") or name:lower():find("respirator") or where:find("maskeyes") or where:find("maskfull") then
                    level = 2
                elseif level < 1 then
                    level = 1
                end
            end
        end
    end)
    return level
end

local function asthmaCorpsesNearby(player)
    local count = 0
    pcall(function()
        local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
        local cell = getCell()
        for dx = -3, 3 do
            for dy = -3, 3 do
                local sq = cell:getGridSquare(px + dx, py + dy, pz)
                local bodies = sq and sq:getDeadBodys()
                if bodies then count = count + bodies:size() end
            end
        end
    end)
    return count
end

local function asthmaTierOf(irritation)
    local tier = 0
    for i, threshold in ipairs(ASTHMA_TIER) do
        if irritation >= threshold then tier = i end
    end
    return tier
end

-- the shared cough (Util): one gap for everyone, an attack's burst forces it
local function asthmaCough(player, radius, force)
    return DanTraits_Cough(player, radius, "asthma", force)
end

-- Moodle Framework is client side and optional; without it the trait still
-- works, you just do not get the icon.
local function asthmaUpdateMoodle(player, irritation)
    DanTraits_BadMoodle(player, "AirwayIrritation", irritation, { thresholds = { 0.05, 0.125, 0.25, 0.375 } })
end

local function asthmaSetIrritation(player, d, value, quiet)
    value = math.max(0, math.min(1, value))
    local before = asthmaTierOf(d.asthma or 0)
    d.asthma = value

    -- attack state with hysteresis
    if not d.asthmaAttack and value >= ASTHMA_TIER[4] then
        d.asthmaAttack = true
        notify(player, "UI_DanTraits_AsthmaTier4")
        d.asthmaShownTier = 4
    elseif d.asthmaAttack and value < ASTHMA_ATTACK_ENDS_AT then
        d.asthmaAttack = false
        d.asthmaFainted, d.asthmaEmptyMin = nil, nil
        DanTraits_NotifyGood(player, "UI_DanTraits_AsthmaRelief")
        d.asthmaShownTier = asthmaTierOf(value)
    end

    local after = asthmaTierOf(value)
    if not quiet and not d.asthmaAttack and after > before and after >= 1 and after <= 3 then
        notify(player, "UI_DanTraits_AsthmaTier" .. after)
    end
    asthmaUpdateMoodle(player, value)
end

-- effective tier for penalties: an attack in progress counts as 4 until it ends
local function asthmaEffectiveTier(d)
    if d.asthmaAttack then return 4 end
    return math.min(3, asthmaTierOf(d.asthma or 0))
end

local function updateAsthmaMinute(player, d)
    if not hasTrait(player, "asthma") then return end
    d = asthmaData(player)
    local stats = player:getStats()
    local irritation = d.asthma
    local mask = asthmaMaskLevel(player)
    local asleep = DanTraits_Asleep(player)
    local out = DanTraits_IsPassedOut and DanTraits_IsPassedOut(player)
    local lungs = d.nicLungs or 0   -- a smoker's lungs (Smoker keeps it for everyone who has ever smoked)

    -- build-up
    local envMult = (mask == 2) and 0 or ((mask == 1) and 0.5 or 1)
    local passiveMult = (mask == 2) and ASTHMA_MASK_GAS_PASSIVE or 1
    local build = 0
    -- during an attack its own endurance drain and panic do not feed it, or it
    -- could never end: resting in clean warm air it eases at the attack rate
    -- (about four hours), running or cold air still keep it going
    local attack = d.asthmaAttack == true
    if not asleep then   -- (a faint ends the exertion and the panic, not the cold or the corpses)
        local temp = nil
        pcall(function() temp = getClimateManager():getAirTemperatureForCharacter(player, false) end)
        if temp and temp < ASTHMA_COLD_TEMP_C then
            build = build + ASTHMA_COLD_RATE * envMult
        end
        local corpses = math.min(3, asthmaCorpsesNearby(player))
        if corpses > 0 then
            build = build + ASTHMA_CORPSE_RATE * corpses * envMult
        end
        if not out and not attack and stats:get(CharacterStat.ENDURANCE) < ASTHMA_EXERT_ENDURANCE then
            build = build + ASTHMA_EXERT_RATE * passiveMult * (1 + ASTHMA_LUNGS_BUILD * lungs)
        end
        local moving = false
        pcall(function() moving = player:isSprinting() or player:isRunning() end)
        if moving and not out then
            build = build + ASTHMA_SPRINT_RATE * passiveMult * (1 + ASTHMA_LUNGS_BUILD * lungs)
        end
        -- panic: racing heart, fast shallow breathing. Internal, so no mask helps.
        local panic = 0
        pcall(function() panic = stats:get(CharacterStat.PANIC) or 0 end)
        if panic > ASTHMA_PANIC_MIN and not out and not attack then
            build = build + ASTHMA_PANIC_RATE * ((panic - ASTHMA_PANIC_MIN) / (100 - ASTHMA_PANIC_MIN))
        end
    end

    if DanTraits_InfectionFever then pcall(function() build = build + ASTHMA_FEVER_RATE * DanTraits_InfectionFever(player) end) end
    if build > 0 then
        if DanTraits_VitalityAsthmaBuild then build = build * DanTraits_VitalityAsthmaBuild(player) end
        irritation = irritation + build
    else
        local decay = asleep and ASTHMA_DECAY_ASLEEP or ASTHMA_DECAY_CALM
        if d.asthmaAttack then decay = ASTHMA_DECAY_ATTACK end
        irritation = irritation - decay * (1 - ASTHMA_LUNGS_DECAY * lungs)
    end
    asthmaSetIrritation(player, d, irritation)

    -- tier effects that run on the minute
    local tier = asthmaEffectiveTier(d)
    if asleep and tier >= ASTHMA_WAKE_TIER then
        -- you cannot sleep through this
        pcall(function() player:forceAwake() end)
        notify(player, "UI_DanTraits_AsthmaWake")
        asthmaCough(player, ASTHMA_COUGH_RADIUS_T3)
    end
    if tier == 2 and not asleep then
        d.asthmaCoughIn = (d.asthmaCoughIn or (ASTHMA_COUGH_MIN_T2 + ZombRand(5))) - 1
        if d.asthmaCoughIn <= 0 then
            asthmaCough(player, ASTHMA_COUGH_RADIUS_T2)
            d.asthmaCoughIn = ASTHMA_COUGH_MIN_T2 + ZombRand(5)
        end
    elseif tier == 3 and not asleep then
        d.asthmaCoughIn = (d.asthmaCoughIn or (ASTHMA_COUGH_MIN_T3 + ZombRand(3))) - 1
        if d.asthmaCoughIn <= 0 then
            asthmaCough(player, ASTHMA_COUGH_RADIUS_T3)
            d.asthmaCoughIn = ASTHMA_COUGH_MIN_T3 + ZombRand(3)
        end
    elseif tier == 4 then
        -- constant coughing: a burst of two or three spread over the minute (forced past the gap)
        asthmaCough(player, ASTHMA_COUGH_RADIUS_T4, true)
        for n = 1, 1 + ZombRand(2) do
            DanTraits_Later(n * (700 + ZombRand(500)), function()
                if player and not player:isDead() then asthmaCough(player, ASTHMA_COUGH_RADIUS_T4, true) end
            end)
        end
        pcall(function()
            stats:set(CharacterStat.ENDURANCE, math.max(0, stats:get(CharacterStat.ENDURANCE) - ASTHMA_ATTACK_END_DRAIN))
        end)
        -- not being able to breathe is terrifying, and the panic feeds the attack
        pcall(function()
            stats:set(CharacterStat.PANIC, math.min(100, (stats:get(CharacterStat.PANIC) or 0) + ASTHMA_ATTACK_PANIC))
        end)
        pcall(function()
            local bd = player:getBodyDamage()
            if bd:getOverallBodyHealth() > ASTHMA_HEALTH_FLOOR then
                bd:ReduceGeneralHealth(math.min(ASTHMA_ATTACK_HP_DRAIN, bd:getOverallBodyHealth() - ASTHMA_HEALTH_FLOOR))
            end
        end)
        -- an attack that has emptied you for a few minutes running can black you out
        local empty = false
        pcall(function() empty = (stats:get(CharacterStat.ENDURANCE) or 0) <= 0 end)
        d.asthmaEmptyMin = empty and ((d.asthmaEmptyMin or 0) + 1) or 0
        if d.asthmaEmptyMin >= ASTHMA_FAINT_AFTER_MIN and not d.asthmaFainted and not out and not asleep
                and DanTraits_PassOut and DanTraits_Roll(ASTHMA_FAINT) then
            if DanTraits_PassOut(player, DanTraits_RandRange(ASTHMA_FAINT_MIN[1], ASTHMA_FAINT_MIN[2]), "UI_DanTraits_AsthmaBlackout", true) then
                d.asthmaFainted = true
            end
        end
    end
end

-- Claw back endurance regeneration according to tier, through the stat delta
-- pipeline (DanTraits_Util.lua): half at tier 2, none from tier 3.
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not hasTrait(player, "asthma") then return nil end
    local tier = asthmaEffectiveTier(asthmaData(player))
    if tier == 2 then return delta * 0.5 elseif tier >= 3 then return 0 end
    return nil
end)

-- Called by Smoker's dose (a cigarette, cigar or pipe: not gum or chewing tobacco):
-- the smoke itself irritates the airway, whatever mask is worn.
function DanTraits_AsthmaSmoked(player, dose)
    if not player or not hasTrait(player, "asthma") then return false end
    local d = asthmaData(player)
    asthmaSetIrritation(player, d, d.asthma + ASTHMA_SMOKE * (tonumber(dose) or 1))
    return true
end

-- Called by the inhaler action.
function DanTraits_UseInhaler(player)
    if not player then return false end
    if not hasTrait(player, "asthma") then return false end
    local d = asthmaData(player)
    asthmaSetIrritation(player, d, d.asthma - ASTHMA_INHALER_RELIEF, true)
    pcall(function()
        local stats = player:getStats()
        stats:set(CharacterStat.PANIC, math.min(100, (stats:get(CharacterStat.PANIC) or 0) + ASTHMA_INHALER_PANIC))
    end)
    if d.asthma < ASTHMA_TIER[3] then
        DanTraits_NotifyGood(player, "UI_DanTraits_AsthmaRelief")
    end
    if DanTraits_DiaOnInhaler then pcall(DanTraits_DiaOnInhaler, player) end
    return true
end

-- The inhaler is its own item (DanTraits.Inhaler, ten puffs); it spawns
-- through the loot tables in server/Items/DanTraits_Distributions.lua.
local INHALER_ITEM = "DanTraits.Inhaler"

function DanTraits_IsInhaler(item)
    if not item then return false end
    local ok, fullType = pcall(function() return item:getFullType() end)
    return ok and fullType == INHALER_ITEM
end

-- Start with one inhaler.
local function onAsthmaCreatePlayer(playerNum, player)
    if not player or not hasTrait(player, "asthma") then return end
    local d = asthmaData(player)
    if d.asthmaKitGiven or player:getHoursSurvived() > 0 then return end
    d.asthmaKitGiven = true
    pcall(function() player:getInventory():AddItem(INHALER_ITEM) end)
end

DanTraits_Every("minute", "Asthma", updateAsthmaMinute, 40)
Events.OnCreatePlayer.Add(onAsthmaCreatePlayer)
