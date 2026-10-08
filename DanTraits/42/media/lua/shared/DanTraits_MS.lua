-- Project Zomboid Vitality Project: Multiple Sclerosis.
--
-- Heat is the enemy, and no pill helps with it (Uhthoff's phenomenon: a
-- small rise in body temperature stops damaged nerves carrying signals). A
-- heat load (0..1) follows the warmth around you, and your own body
-- temperature when exercise or too many clothes push it up. It builds over
-- about half an hour (a tenth faster than the file's base rate: MS warms up
-- quicker, and every tenth of a degree the body is over 37 counts a tenth
-- more; the game's thermoregulator itself has no hook to speed up) and
-- fades over about twenty minutes once you cool off,
-- twice as fast when you are wet; a drink straight from a tap, a well or a
-- river knocks some off.
--   Warm (0.25): tired sooner, endurance comes back slower. Nothing else.
--   Hot (0.5): the hands go stiff and clumsy (the game's own stiffness on
--     hands and forearms: slower and sore), a swing can throw the weapon,
--     and the pain climbs.
--   Overheated (0.8): severe pain, and every minute a chance the hands give
--     out and drop whatever they hold (not asleep, nor in a vehicle).
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
-- flare there is still a little stiffness in the legs.
--
-- MS fatigue is a budget: the spoons (DanTraits_Spoons.lua, which keeps the
-- pool, the refill from the night's score, the spending and the tiers). MS
-- registers as a user, sets the cap (the sandbox count, two thirds of it in a
-- flare), multiplies the spending by the heat (x (1 + load)) and a flare
-- (x1.5), adds amantadine's spoons to the refill, and reads the tier back:
-- running on empty stiffens the legs (20), the wall stiffens them like a flare
-- (35) and lets a swing throw the weapon (5%), and hours borrowed raise the
-- flare rate (x (1 + 0.1 x hours)). With the sandbox count at 0 there is no
-- budget and the old drip is back: you tire a fifth faster, twice that in a
-- flare, more in the heat, cut to 40% by amantadine.
--
-- The 1993 medicine cabinet, three pill bottles of this mod's, kept by the
-- shared medication system (DanTraits_Meds.lua: levels, half-lives, build-up,
-- side effects, overdose, wearing-off notices). This file reads how well
-- each is working (0..1):
--   Prednisone (a steroid): works at once. A flare runs out three times as
--     fast. Does nothing outside one. Makes you hungry. One a day.
--   Baclofen: builds up over 2 days, then all the stiffness above, heat's
--     included, is halved. Makes you a little drowsy. One every 12 hours.
--   Amantadine: builds up over 3 days, then MS fatigue (baseline and flare)
--     is cut to 40%. Dry mouth (a little thirstier). One every 12 hours.
-- A new character starts on baclofen and amantadine, fully built up, and with a
-- bottle of each unless the Starting Medication sandbox option is off.
-- Prednisone has to be found.
--
-- Mod data: msHeat (the heat load), msTier (the last heat notice's tier),
-- msHands, msLegs, msPainHead (what MS last held the hands, legs and head at,
-- for easing it off),
-- msFlareH (hours of flare left), msFlares (count), msKitGiven. The pills
-- live in the medication system's meds table.
-- Console: ms heat <0..1> | ms flare | ms end | ms pill <pred|bac|aman>
require "DanTraits"
require "DanTraits_Meds"
require "DanTraits_Spoons"

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
local MS_WARM_FASTER   = 1.1     -- MS warms up this much faster: the load rises x this, and body heat over 37 counts x this
local MS_RISE_MIN      = 1 / 30 * MS_WARM_FASTER  -- load gained a minute toward a higher target
local MS_BODY_BASE     = 37      -- body heat is measured as the rise over this
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
-- discomfort (the game's Uncomfortable moodle: clothes, a cramped car, wet) wears MS down
local MS_DISCOMFORT_COST   = 0.5     -- spoons spent x (1 + this x discomfort)
local MS_DISCOMFORT_STRESS = 0.0004  -- stress a minute at full discomfort, on top of the game's own
local MS_FATIGUE       = 0.0002  -- tiredness a minute awake (about a fifth faster)...
local MS_FLARE_FATIGUE = 0.0004  -- ...and this more in a flare
local MS_LEG_STIFF     = 8       -- stiffness floor on the legs...
local MS_LEG_FLARE     = 35      -- ...in a flare
local MS_HAND_FLARE    = 20      -- hands and forearms in a flare
-- recovery: MS takes back what it put on (the game's own easing is slow:
-- stiffness about 0.3 a minute, head pain about 1)
local MS_EASE_STIFF    = 2       -- stiffness off a minute, down to the current floor
local MS_EASE_PAIN     = 2       -- head pain off a minute on top of the game's 1
-- medication (DanTraits_Meds.lua keeps the levels; these are what a pill
-- working fully does, scaled by how well it is working)
local MS_PRED_BURN     = 3       -- flare hours gone per hour on prednisone
local MS_BAC_STIFF     = 0.5     -- stiffness x this on baclofen
local MS_AMAN_FATIGUE  = 0.4     -- MS fatigue x this on amantadine (the no-budget drip only)
-- the spoon budget (DanTraits_Spoons.lua)
local MS_SPOONS_DEFAULT   = 12   -- spoons a day (sandbox MSSpoons; 0 is no budget)
local MS_SPOON_FLARE      = 2 / 3 -- the cap x this in a flare
local MS_SPOON_FLARE_COST = 1.5  -- spending x this in a flare (the heat adds x (1 + load))
local MS_SPOON_AMAN       = 2    -- spoons amantadine adds to the morning refill, fully built up
local MS_LEG_LOW          = 20   -- legs stiffness floor running on empty (the wall: the flare's)
local MS_SPOON_FUMBLE     = 5    -- percent added to a swing's drop chance at the wall
local MS_SPOON_DEBT_FLARE = 0.1  -- flare rate x (1 + this x hours borrowed)
local MS_KIT = { "DanTraits.Baclofen", "DanTraits.Amantadine" }
local MS_START = { "baclofen", "amantadine" }   -- a new character is on these

local HANDS = { "Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R" }
local LEGS = { "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }

-- 0..1: how well an MS pill is working (the medication system)
local function effect(player, id)
    return DanTraits_MedEffect and DanTraits_MedEffect(player, id) or 0
end

local function tierOf(load) return DanTraits_TierOf(load, MS_TIER) end

-- the spoon budget: the sandbox count a day, 0 for none
local function spoonCount()
    local sv = SandboxVars and SandboxVars.DanTraits
    local v = sv and tonumber(sv.MSSpoons)
    if v == nil then return MS_SPOONS_DEFAULT end
    return math.max(0, math.floor(v))
end
local function spoonsOn() return spoonCount() > 0 end
local function spoonTier(player) return DanTraits_SpoonTier and DanTraits_SpoonTier(player) or 0 end

-- 0..1 from a start point to a full point
local over = DanTraits_Over

-- 0..1 how hot it is for this character right now, before the lag
local function heatTarget(player, d)
    local air, body, wet = 0, 0, 0
    air = over(DanTraits_AirTemp(player) or 0, MS_AIR_FROM, MS_AIR_FULL)
    pcall(function() wet = fraction(player:getStats(), CharacterStat.WETNESS) end)
    pcall(function()
        local t = player:getStats():get(CharacterStat.TEMPERATURE)
        -- the rise over 37 counts a tenth more: MS warms up faster
        if type(t) == "number" and t > 30 then body = over(MS_BODY_BASE + (t - MS_BODY_BASE) * MS_WARM_FASTER, MS_BODY_FROM, MS_BODY_FULL) end
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

-- not while out cold or asleep, nor in a vehicle (what the hands drop would
-- be left on the road behind)
local function handsCanGiveOut(player)
    if DanTraits_IsPassedOut and DanTraits_IsPassedOut(player) then return false end
    if DanTraits_Asleep(player) then return false end
    local inVehicle = false
    pcall(function() inVehicle = player:getVehicle() ~= nil end)
    return not inVehicle
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

local function startFlare(player, d)
    d.msFlareH = DanTraits_RandRange(MS_FLARE_HOURS[1], MS_FLARE_HOURS[2])
    d.msFlares = (d.msFlares or 0) + 1
    notify(player, "UI_DanTraits_MSFlare")
end

local function flareRate(player, d)
    local rate = MS_FLARE_H
    rate = rate * (1 + MS_FLARE_FEVER * DanTraits_Strength("DanTraits_InfectionFever", player))
    rate = rate * (1 + MS_FLARE_STRESS * fraction(player:getStats(), CharacterStat.STRESS))
    if spoonsOn() and DanTraits_SpoonDebt then rate = rate * (1 + MS_SPOON_DEBT_FLARE * DanTraits_SpoonDebt(player)) end
    return rate
end
DanTraits_MSFlareRate = flareRate

local function updateFlare(player, d)
    if (d.msFlareH or 0) > 0 then
        d.msFlareH = d.msFlareH - (1 + (MS_PRED_BURN - 1) * effect(player, "prednisone")) / 60
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
    if not hasTrait(player, "ms") then
        d.msHeat, d.msTier, d.msFlareH = nil, nil, nil
        d.msHands, d.msLegs, d.msPainHead = nil, nil, nil
        return
    end
    updateFlare(player, d)
    local load = updateHeat(player, d)
    local flaring = (d.msFlareH or 0) > 0
    local stats = player:getStats()

    -- fatigue: the spoon budget's (DanTraits_Spoons.lua), or with no budget the
    -- old drip: MS's own, a flare's, and the heat's
    if not spoonsOn() and not DanTraits_Asleep(player) then
        local tired = MS_FATIGUE + (flaring and MS_FLARE_FATIGUE or 0)
        tired = tired * (1 - (1 - MS_AMAN_FATIGUE) * effect(player, "amantadine"))
        if load >= MS_TIER[1] then tired = tired + MS_HEAT_FATIGUE * load end
        DanTraits_StatAdd(stats, CharacterStat.FATIGUE, tired)
    end

    -- stiffness: hands from heat (hot and up) or a flare, legs always
    local hands = 0
    if load >= MS_TIER[2] then hands = MS_HAND_HOT + (MS_HAND_STIFF - MS_HAND_HOT) * over(load, MS_TIER[2], 1) end
    if flaring then hands = math.max(hands, MS_HAND_FLARE) end
    local legs = flaring and MS_LEG_FLARE or MS_LEG_STIFF
    if spoonsOn() then
        local sp = spoonTier(player)
        if sp >= 3 then legs = math.max(legs, MS_LEG_FLARE) elseif sp == 2 then legs = math.max(legs, MS_LEG_LOW) end
    end
    local relax = 1 - (1 - MS_BAC_STIFF) * effect(player, "baclofen")
    hands, legs = hands * relax, legs * relax
    setFloors(player, d, hands, legs)

    -- discomfort gets to you: stress on top of the game's own (and spoons, in the spend hook)
    if not DanTraits_Asleep(player) then
        local discomfort = fraction(stats, CharacterStat.DISCOMFORT)
        if discomfort > 0 then DanTraits_StatAdd(stats, CharacterStat.STRESS, MS_DISCOMFORT_STRESS * discomfort) end
    end

    local pain = 0
    if load >= MS_TIER[2] then
        pain = MS_PAIN_HOT + (MS_PAIN - MS_PAIN_HOT) * over(load, MS_TIER[2], 1)
        DanTraits_PainFloor(player, d, "ms", pain, MS_PAIN_RAMP)
    end
    easePain(player, d, pain)
    if load >= MS_TIER[3] and handsCanGiveOut(player) and DanTraits_Roll(MS_GIVE_OUT_MIN) then
        handsGiveOut(player)
    end
end

-- a swing can throw the weapon when the heat is in the hands, or at the wall
DanTraits_AddHook("swingDrop", function(chance, player)
    if not hasTrait(player, "ms") then return nil end
    local d = player:getModData().DanTraits
    local load = d and d.msHeat or 0
    local add = 0
    if load >= MS_TIER[2] then add = add + MS_FUMBLE_HOT + (MS_FUMBLE - MS_FUMBLE_HOT) * over(load, MS_TIER[2], 1) end
    if spoonsOn() and spoonTier(player) >= 3 then add = add + MS_SPOON_FUMBLE end
    if add <= 0 then return nil end
    return chance + add
end)

-- the spoon budget: MS draws on it unless the sandbox count is 0
DanTraits_SpoonsUse(function(player) return spoonsOn() and hasTrait(player, "ms") end)
DanTraits_AddHook("spoonCap", function(cap, player, d)
    if not hasTrait(player, "ms") then return nil end
    cap = spoonCount()
    if d and (d.msFlareH or 0) > 0 then cap = cap * MS_SPOON_FLARE end
    return cap
end)
DanTraits_AddHook("spoonRefill", function(extra, player, d)
    if not hasTrait(player, "ms") then return nil end
    return extra + MS_SPOON_AMAN * effect(player, "amantadine")
end)
DanTraits_AddHook("spoonSpend", function(cost, player, d)
    if not d or not hasTrait(player, "ms") then return nil end
    cost = cost * (1 + (d.msHeat or 0))
    if (d.msFlareH or 0) > 0 then cost = cost * MS_SPOON_FLARE_COST end
    cost = cost * (1 + MS_DISCOMFORT_COST * fraction(player:getStats(), CharacterStat.DISCOMFORT))
    return cost
end)

DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d or not hasTrait(player, "ms") then return nil end
    local k = 1
    if (d.msHeat or 0) >= MS_TIER[1] then k = k * (1 - MS_HEAT_REGEN * d.msHeat) end
    if (d.msFlareH or 0) > 0 then k = k * MS_FLARE_REGEN end
    if k == 1 then return nil end
    return delta * k
end)

-- a drink straight from a tap, a well or a river cools you down a little
-- (not one from a bottle or a mug: that may be hot, or not water)
function DanTraits_MSDrinkCool(player, litres)
    local d = player and player:getModData().DanTraits
    if not d or not d.msHeat then return end
    d.msHeat = math.max(0, d.msHeat - MS_DRINK_COOL * (tonumber(litres) or 0))
end

-- The game drinks from a world source in ISTakeWaterAction:transferFluid:
-- with no item to fill, the water goes straight into the character, as much
-- as was asked for or as much as the source still held.
local function wrapWorldDrink()
    DanTraits_Wrap(ISTakeWaterAction, "transferFluid", "ms-drink", function(original, self, amount, ...)
        local litres = 0
        pcall(function()
            if not self.item then litres = math.min(tonumber(amount) or 0, self.waterObject:getFluidAmount() or 0) end
        end)
        local result = original(self, amount, ...)
        if litres > 0 then pcall(DanTraits_MSDrinkCool, self.character, litres) end
        return result
    end)
end
wrapWorldDrink()
Events.OnGameStart.Add(wrapWorldDrink)

-- a dose by hand (the console); a swallowed pill reaches the medication system itself
function DanTraits_TakeMSMed(player, which, amount)
    if not DanTraits_Drugs or not DanTraits_Drugs[which] then return nil end
    return DanTraits_MedTake(player, which, amount or 1)
end

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
    if args[1] == "spoons" then
        if args[2] == "debt" and tonumber(args[3]) then d.spDebt = math.max(0, tonumber(args[3])) return "spoon debt " .. tostring(d.spDebt) .. " h" end
        if tonumber(args[2]) and DanTraits_SpoonsSet then DanTraits_SpoonsSet(player, tonumber(args[2])) end
        return "spoons " .. tostring(d.spPool or "off") .. " of " .. tostring(d.spCap or spoonCount()) .. ", tier " .. tostring(d.spFelt or 0)
            .. ", debt " .. tostring(d.spDebt or 0) .. " h, rest " .. tostring(d.spRest or 0) .. ", nap " .. tostring(d.spNap or 0) .. ", mask " .. tostring(d.spMask or 0) .. " min"
    end
    return "ms heat <0..1> | ms flare | ms end | ms pill <pred|bac|aman> | ms spoons [n | debt <h>] (heat " .. tostring(d.msHeat or 0)
        .. ", target " .. tostring((heatTarget(player, d))) .. ", flare hours " .. tostring(d.msFlareH or 0)
        .. ", spoons " .. tostring(d.spPool or "off") .. ", debt " .. tostring(d.spDebt or 0) .. ")"
end

-- start on baclofen and amantadine, fully built up, and with a bottle of each
-- unless the Starting Medication sandbox option is off
local function onMSCreatePlayer(playerNum, player)
    if not player or not hasTrait(player, "ms") then return end
    local d = DanTraits_Data(player)
    if d.msKitGiven or player:getHoursSurvived() > 0 then return end
    d.msKitGiven = true
    for _, id in ipairs(MS_START) do DanTraits_MedStart(player, id) end
    if not DanTraits_SandboxOn("StartingMedication") then return end
    for _, item in ipairs(MS_KIT) do
        pcall(function() player:getInventory():AddItem(item) end)
    end
end

DanTraits_Every("minute", "MS", updateMSMinute, 40)
Events.OnCreatePlayer.Add(onMSCreatePlayer)
