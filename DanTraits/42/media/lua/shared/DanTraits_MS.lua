-- Project Zomboid Vitality Project: Multiple Sclerosis.
--
-- Heat is the enemy, and no pill helps with it (Uhthoff's phenomenon: a
-- small rise in body temperature stops damaged nerves carrying signals). A
-- heat load (0..1) follows the warmth around you, and your own body
-- temperature when exercise or too many clothes push it up. It builds over
-- about half an hour and fades over about twenty minutes once you cool off,
-- twice as fast when you are wet; every drink knocks some off.
--   Warm (0.25): tired sooner, endurance comes back slower. Nothing else.
--   Hot (0.5): the hands go stiff and clumsy (the game's own stiffness on
--     hands and forearms: slower and sore), a swing can throw the weapon,
--     and the pain climbs.
--   Overheated (0.8): severe pain, and every minute a chance the hands give
--     out and drop whatever they hold.
-- The game turns the stiffness into pain of its own, so the pain floor here
-- is set lower than the pain you feel (about 60 in all at a full load).
-- Cooling off clears it quickly: the stiffness MS put on (heat's or a
-- flare's) eases 2 a minute once the cause has passed, and MS's pain
-- leaves the head 3 a minute, where the game alone would take hours and an
-- hour.
--
-- Flares (relapses) come about once a month, more often with a fever or
-- under stress, and last three to six days: heat hits half as hard again,
-- the legs stiffen, the hands are weaker and you tire much faster. Outside a
-- flare there is still MS fatigue (you tire a fifth faster) and a little
-- stiffness in the legs.
--
-- The 1993 medicine cabinet, three pill bottles of this mod's. Each pill
-- tops up a level that decays like Epilepsy's anticonvulsants and works
-- while it is at least half a pill:
--   Prednisone (a steroid): a flare runs out three times as fast. Does
--     nothing outside one. Makes you hungry. Halves every 24 hours: one a day.
--   Baclofen: all the stiffness above, heat's included, is halved. Makes you
--     a little drowsy. Halves every 12 hours.
--   Amantadine: MS fatigue (baseline and flare) cut to 40%. Dry mouth (a
--     little thirstier). Halves every 12 hours.
-- A new character starts with a bottle of baclofen and one of amantadine.
-- Prednisone has to be found.
--
-- Mod data: msHeat (the heat load), msTier (the last heat notice's tier),
-- msHands, msLegs, msPainHead (what MS last held the hands, legs and head at,
-- for easing it off),
-- msFlareH (hours of flare left), msFlares (count), msPred, msBac, msAman
-- (the medication levels), msKitGiven.
-- Console: ms heat <0..1> | ms flare | ms end | ms pill <pred|bac|aman>
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local clamp01 = DanTraits_Clamp01
local fraction = DanTraits_StatFraction

-- heat
local MS_AIR_FROM      = 24      -- degrees C: the air starts to count here...
local MS_AIR_FULL      = 34      -- ...and is at its worst here
local MS_AIR_WEIGHT    = 0.7     -- warm air alone tops out at this load (overheating needs exertion or a flare)
local MS_BODY_FROM     = 37.2    -- body temperature from which it counts...
local MS_BODY_FULL     = 38.4    -- ...to a full load here
local MS_WET_COOL      = 0.6     -- soaked through, the air counts this much less
local MS_RISE_MIN      = 1 / 30  -- load gained a minute toward a higher target
local MS_FALL_MIN      = 1 / 20  -- load lost a minute toward a lower one...
local MS_FALL_WET      = 2       -- ...x this when wet
local MS_WET_AT        = 0.25    -- wetness (0..1) that counts as wet
local MS_DRINK_COOL    = 0.4     -- load off per litre drunk
local MS_TIER          = { 0.25, 0.5, 0.8 }   -- warm | hot | overheated
-- what the heat does
local MS_HEAT_FATIGUE  = 0.0004  -- tiredness a minute at a full load (from warm)
local MS_HEAT_REGEN    = 0.5     -- endurance recovery x (1 - this x load) from warm
local MS_HAND_HOT      = 20      -- stiffness floor on hands and forearms at hot...
local MS_HAND_STIFF    = 55      -- ...rising to this at a full load
local MS_PAIN_HOT      = 12      -- pain floor at hot...
local MS_PAIN          = 35      -- ...rising to this at a full load (the stiff hands add their own: about 60 in all)
local MS_PAIN_RAMP     = 5
local MS_FUMBLE_HOT    = 5       -- percent added to a swing's drop chance at hot...
local MS_FUMBLE        = 15      -- ...rising to this at a full load
local MS_GIVE_OUT_MIN  = 0.05    -- chance a minute, overheated, that the hands give out
-- flares
local MS_FLARE_H       = 1 / 720 -- flares an hour (about one a month)
local MS_FLARE_FEVER   = 2       -- x (1 + this x fever)
local MS_FLARE_STRESS  = 1       -- x (1 + this x stress)
local MS_FLARE_HOURS   = { 72, 144 }
local MS_FLARE_HEAT    = 1.5     -- the heat target x this in a flare
local MS_FLARE_REGEN   = 0.7     -- endurance recovery x this in a flare
-- everyday symptoms
local MS_FATIGUE       = 0.0002  -- tiredness a minute awake (about a fifth faster)...
local MS_FLARE_FATIGUE = 0.0004  -- ...and this more in a flare
local MS_LEG_STIFF     = 8       -- stiffness floor on the legs...
local MS_LEG_FLARE     = 35      -- ...in a flare
local MS_HAND_FLARE    = 20      -- hands and forearms in a flare
-- recovery: MS takes back what it put on (the game's own easing is slow:
-- stiffness about 0.3 a minute, head pain about 1)
local MS_EASE_STIFF    = 2       -- stiffness off a minute, down to the current floor
local MS_EASE_PAIN     = 2       -- head pain off a minute on top of the game's 1
-- medication
local MS_MED_ON        = 0.5     -- a level that works
local MS_PRED_BURN     = 3       -- flare hours gone per hour on prednisone
local MS_PRED_HUNGER   = 0.0002  -- hunger a minute while prednisone works (anyone)
local MS_BAC_STIFF     = 0.5     -- stiffness x this on baclofen
local MS_BAC_DROWSY    = 0.0001  -- side effect: tiredness a minute while baclofen works, awake (anyone)
local MS_AMAN_FATIGUE  = 0.4     -- MS fatigue x this on amantadine
local MS_AMAN_THIRST   = 0.0001  -- side effect: thirst a minute while amantadine works (dry mouth; anyone)
local MS_MEDS = {
    { key = "msPred", item = "prednisone", half = 24, lapse = "UI_DanTraits_MSPredLapse" },
    { key = "msBac",  item = "baclofen",   half = 12, lapse = "UI_DanTraits_MSBacLapse" },
    { key = "msAman", item = "amantadine", half = 12, lapse = "UI_DanTraits_MSAmanLapse" },
}
local MS_KIT = { "DanTraits.Baclofen", "DanTraits.Amantadine" }

local HANDS = { "Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R" }
local LEGS = { "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }

local function on(d, key) return (d[key] or 0) >= MS_MED_ON end

local function tierOf(load)
    local tier = 0
    for i, at in ipairs(MS_TIER) do if load >= at then tier = i end end
    return tier
end

-- 0..1 from a start point to a full point
local function over(value, from, full) return clamp01((value - from) / (full - from)) end

-- 0..1 how hot it is for this character right now, before the lag
local function heatTarget(player, d)
    local air, body, wet = 0, 0, 0
    pcall(function() air = over(getClimateManager():getAirTemperatureForCharacter(player) or 0, MS_AIR_FROM, MS_AIR_FULL) end)
    pcall(function() wet = fraction(player:getStats(), CharacterStat.WETNESS) end)
    pcall(function()
        local t = player:getStats():get(CharacterStat.TEMPERATURE)
        if type(t) == "number" and t > 30 then body = over(t, MS_BODY_FROM, MS_BODY_FULL) end
    end)
    local target = math.max(MS_AIR_WEIGHT * air * (1 - MS_WET_COOL * wet), body)
    if (d.msFlareH or 0) > 0 then target = target * MS_FLARE_HEAT end
    return clamp01(target), wet
end
DanTraits_MSHeatTarget = heatTarget

-- drop whatever is in either hand at the character's feet
local function handsGiveOut(player)
    local square = player:getCurrentSquare()
    if not square then return false end
    local dropped, held = false, {}
    pcall(function() held[#held + 1] = player:getPrimaryHandItem() end)
    pcall(function()
        local second = player:getSecondaryHandItem()
        if second ~= held[1] then held[#held + 1] = second end   -- a two-handed weapon is in both
    end)
    for _, item in ipairs(held) do
        if item then
            pcall(function()
                player:removeFromHands(item)
                player:getInventory():Remove(item)
                square:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
                dropped = true
            end)
        end
    end
    if dropped then notify(player, "UI_DanTraits_MSHandsGiveOut") end
    return dropped
end

-- what MS holds a group of parts at now, and how far to take its earlier
-- stiffness back: the ceiling falls MS_EASE_STIFF a minute toward the floor
local function easing(d, key, floor)
    local before = d[key] or 0
    local ceiling = math.max(floor, before - MS_EASE_STIFF)
    d[key] = ceiling > 0 and ceiling or nil
    return before - ceiling
end

-- raise each part to its floor; while easing, take back as much as the
-- ceiling fell, never below it (so only what MS put on comes off)
local function setFloors(player, d, hands, legs)
    local groups = { { HANDS, hands, easing(d, "msHands", hands) }, { LEGS, legs, easing(d, "msLegs", legs) } }
    pcall(function()
        local bd = player:getBodyDamage()
        for _, g in ipairs(groups) do
            local floor, ease = g[2], g[3]
            for _, name in ipairs(g[1]) do
                local part = bd:getBodyPart(BodyPartType[name])
                if part then
                    local stiff = part:getStiffness() or 0
                    if stiff < floor then part:setStiffness(floor)
                    elseif ease > 0 and stiff > floor then part:setStiffness(math.max(floor, stiff - ease)) end
                end
            end
        end
    end)
end

-- MS's pain floor this minute; once it drops, take MS's share off the head
-- faster than the game would (other sources' floors are put back at order 95)
local function easePain(player, d, floor)
    local target = floor / DanTraits_PAIN_PART_RATIO
    local before = d.msPainHead or 0
    if target >= before then
        d.msPainHead = target > 0 and target or nil
        return
    end
    local ceiling = math.max(target, before - MS_EASE_PAIN - 1)
    d.msPainHead = ceiling > 0 and ceiling or nil
    pcall(function()
        local head = player:getBodyDamage():getBodyPart(BodyPartType.Head)
        local cur = head:getAdditionalPain() or 0
        if cur > ceiling then head:setAdditionalPain(math.max(ceiling, cur - MS_EASE_PAIN)) end
    end)
end

local function updateMeds(player, d)
    for _, med in ipairs(MS_MEDS) do
        local level = d[med.key] or 0
        if level > 0 then
            local was = level >= MS_MED_ON
            level = level * 0.5 ^ (1 / (med.half * 60))
            if level < 0.01 then level = 0 end
            d[med.key] = level > 0 and level or nil
            if was and level < MS_MED_ON and hasTrait(player, "ms") then notify(player, med.lapse) end
        end
    end
    -- side effects, for anyone taking them
    local stats = player:getStats()
    if on(d, "msPred") then DanTraits_StatAdd(stats, CharacterStat.HUNGER, MS_PRED_HUNGER) end
    if on(d, "msBac") and not DanTraits_Asleep(player) then DanTraits_StatAdd(stats, CharacterStat.FATIGUE, MS_BAC_DROWSY) end
    if on(d, "msAman") then DanTraits_StatAdd(stats, CharacterStat.THIRST, MS_AMAN_THIRST) end
end

local function startFlare(player, d)
    d.msFlareH = DanTraits_RandRange(MS_FLARE_HOURS[1], MS_FLARE_HOURS[2])
    d.msFlares = (d.msFlares or 0) + 1
    notify(player, "UI_DanTraits_MSFlare")
end

local function flareRate(player, d)
    local rate = MS_FLARE_H
    if DanTraits_InfectionFever then
        local ok, fever = pcall(DanTraits_InfectionFever, player)
        if ok then rate = rate * (1 + MS_FLARE_FEVER * clamp01(tonumber(fever) or 0)) end
    end
    return rate * (1 + MS_FLARE_STRESS * fraction(player:getStats(), CharacterStat.STRESS))
end
DanTraits_MSFlareRate = flareRate

local function updateFlare(player, d)
    if (d.msFlareH or 0) > 0 then
        d.msFlareH = d.msFlareH - (on(d, "msPred") and MS_PRED_BURN or 1) / 60
        if d.msFlareH <= 0 then
            d.msFlareH = nil
            DanTraits_NotifyGood(player, "UI_DanTraits_MSFlareEnds")
        end
    elseif DanTraits_Roll(flareRate(player, d) / 60) then
        startFlare(player, d)
    end
end

local function updateHeat(player, d)
    local target, wet = heatTarget(player, d)
    local load = d.msHeat or 0
    if target > load then
        load = math.min(target, load + MS_RISE_MIN)
    else
        load = math.max(target, load - MS_FALL_MIN * (wet >= MS_WET_AT and MS_FALL_WET or 1))
    end
    d.msHeat = load > 0 and load or nil
    local tier, before = tierOf(load), d.msTier or 0
    if tier > before then notify(player, "UI_DanTraits_MSHeat" .. tier) end
    if tier == 0 and before > 0 then DanTraits_NotifyGood(player, "UI_DanTraits_MSCooled") end
    d.msTier = tier > 0 and tier or nil
    return load
end

local function updateMSMinute(player, d)
    updateMeds(player, d)
    if not hasTrait(player, "ms") then
        d.msHeat, d.msTier, d.msFlareH = nil, nil, nil
        d.msHands, d.msLegs, d.msPainHead = nil, nil, nil
        return
    end
    updateFlare(player, d)
    local load = updateHeat(player, d)
    local flaring = (d.msFlareH or 0) > 0
    local stats = player:getStats()

    -- fatigue: MS's own, a flare's, and the heat's
    if not DanTraits_Asleep(player) then
        local tired = MS_FATIGUE + (flaring and MS_FLARE_FATIGUE or 0)
        if on(d, "msAman") then tired = tired * MS_AMAN_FATIGUE end
        if load >= MS_TIER[1] then tired = tired + MS_HEAT_FATIGUE * load end
        DanTraits_StatAdd(stats, CharacterStat.FATIGUE, tired)
    end

    -- stiffness: hands from heat (hot and up) or a flare, legs always
    local hands = 0
    if load >= MS_TIER[2] then hands = MS_HAND_HOT + (MS_HAND_STIFF - MS_HAND_HOT) * over(load, MS_TIER[2], 1) end
    if flaring then hands = math.max(hands, MS_HAND_FLARE) end
    local legs = flaring and MS_LEG_FLARE or MS_LEG_STIFF
    if on(d, "msBac") then hands, legs = hands * MS_BAC_STIFF, legs * MS_BAC_STIFF end
    setFloors(player, d, hands, legs)

    local pain = 0
    if load >= MS_TIER[2] then
        pain = MS_PAIN_HOT + (MS_PAIN - MS_PAIN_HOT) * over(load, MS_TIER[2], 1)
        DanTraits_PainFloor(player, d, "ms", pain, MS_PAIN_RAMP)
    end
    easePain(player, d, pain)
    if load >= MS_TIER[3] and not (DanTraits_IsPassedOut and DanTraits_IsPassedOut(player))
        and DanTraits_Roll(MS_GIVE_OUT_MIN) then
        handsGiveOut(player)
    end
end

-- a swing can throw the weapon when the heat is in the hands
DanTraits_AddHook("swingDrop", function(chance, player)
    if not hasTrait(player, "ms") then return nil end
    local d = player:getModData().DanTraits
    local load = d and d.msHeat or 0
    if load < MS_TIER[2] then return nil end
    return chance + MS_FUMBLE_HOT + (MS_FUMBLE - MS_FUMBLE_HOT) * over(load, MS_TIER[2], 1)
end)

DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d or not hasTrait(player, "ms") then return nil end
    local k = 1
    if (d.msHeat or 0) >= MS_TIER[1] then k = k * (1 - MS_HEAT_REGEN * d.msHeat) end
    if (d.msFlareH or 0) > 0 then k = k * MS_FLARE_REGEN end
    if k == 1 then return nil end
    return delta * k
end)

-- a drink cools you down a little
DanTraits_AddHook("drink", function(_, player, container, litres)
    local d = player and player:getModData().DanTraits
    if not d or not d.msHeat then return nil end
    d.msHeat = math.max(0, d.msHeat - MS_DRINK_COOL * (tonumber(litres) or 0))
    return nil
end)

function DanTraits_TakeMSMed(player, which, amount)
    local d = DanTraits_Data(player)
    for _, med in ipairs(MS_MEDS) do
        if med.item == which then
            d[med.key] = (d[med.key] or 0) + (amount or 1)
            return d[med.key]
        end
    end
    return nil
end

DanTraits_AddHook("pill", function(_, player, kind)
    DanTraits_TakeMSMed(player, string.lower(tostring(kind or "")), 1)
    return nil
end)

local MS_ITEMS = { ["DanTraits.Prednisone"] = true, ["DanTraits.Baclofen"] = true, ["DanTraits.Amantadine"] = true }
function DanTraits_IsMSMed(item)
    local ok, res = pcall(function() return MS_ITEMS[item:getFullType()] == true end)
    return ok and res == true
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.ms = function(player, args)
    local d = DanTraits_Data(player)
    if args[1] == "heat" and tonumber(args[2]) then d.msHeat = clamp01(tonumber(args[2])) return "heat load " .. tostring(d.msHeat) end
    if args[1] == "flare" then startFlare(player, d) return "flare for " .. tostring(math.floor(d.msFlareH)) .. " hours" end
    if args[1] == "end" then d.msFlareH = nil return "flare over" end
    if args[1] == "pill" then
        local names = { pred = "prednisone", bac = "baclofen", aman = "amantadine" }
        local level = DanTraits_TakeMSMed(player, names[args[2] or ""] or args[2] or "", 1)
        if level then return args[2] .. " level " .. tostring(level) end
    end
    return "ms heat <0..1> | ms flare | ms end | ms pill <pred|bac|aman> (heat " .. tostring(d.msHeat or 0)
        .. ", target " .. tostring((heatTarget(player, d))) .. ", flare hours " .. tostring(d.msFlareH or 0) .. ")"
end

-- start with a bottle of baclofen and one of amantadine
local function onMSCreatePlayer(playerNum, player)
    if not player or not hasTrait(player, "ms") then return end
    local d = DanTraits_Data(player)
    if d.msKitGiven or player:getHoursSurvived() > 0 then return end
    d.msKitGiven = true
    for _, item in ipairs(MS_KIT) do
        pcall(function() player:getInventory():AddItem(item) end)
    end
end

DanTraits_Every("minute", "MS", updateMSMinute, 40)
Events.OnCreatePlayer.Add(onMSCreatePlayer)
