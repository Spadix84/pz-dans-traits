-- Project Zomboid Vitality Project: the traits only one age can take.
-- DanTraits_AgeOnly says which bands may take each; the creation screen
-- (DanTraits_Client.lua) offers a trait only to those bands and drops it if
-- the age changes. Nothing here checks the band again after creation: a
-- character who has the trait has it. docs/age.md lists them.
--
--   20s      Green (-4)           every skill the occupation boosts starts a level
--                                 lower (DanTraits_AgeLevels in DanTraits_Age.lua)
--            Quick Study (+4)     a skill below level 5 gains experience x1.4
--   40s 50s  Reading Glasses (-2) starts with a pair; without glasses on, reading
--                                 takes x1.5 as long and needs a properly lit room
--            Bad Back (-4)        a heavy load builds lower-back pain; rest eases it
--            Bad Knees (-3)       running, sprinting and climbing build knee pain
--            Old Hand (+4)        every skill the occupation boosts gains experience
--                                 x1.25 (the main skill only until 2026-10-07)
--   50s      Old Injury (-3)      one limb is always a little stiff, and stiffer and
--                                 sore in the cold and damp (Arthritis's weather
--                                 reading, on one part)
--            Set in Their Ways (-2) skills the occupation does not boost gain
--                                 experience x0.85
--
-- The second eight (2026-10-07), one perk and one flaw of each band's own
-- (Bounces Back, the 20s perk, was folded into Thick Skull the same day:
-- DanTraits_Positives.lua):
--   Bottomless Pit (20s, gives 6): hunger x1.3 on top of the band, and the
--     Hungry moodle costs mood from Hungry up.
--   Seen It All (50s, costs 3): panic builds x0.6, Fear of Blood faints half
--     as often, Germaphobe's filth stress half. Not with Cowardly.
--   Pace Yourself (40s, costs 2): a tenth of the endurance a swing or a
--     sprint spends is given back.
--   Settled (40s, gives 4 since 2026-10-08, was 2): a night anywhere but a bed in a house scores 0.2
--     worse, and so does the first night in a new bed.
--   Old Bones Know Rain (50s, costs 1): once a day, tomorrow's storm, heavy
--     rain, blizzard or a night below freezing is felt in the joints today.
--   Cast Iron (50s, costs 2): medication side effects half as often, the
--     overdose line a pill higher.
--   Delicate Stomach (40s and 50s, gives 2): a junk meal brings food
--     sickness, so does a drink on an empty stomach. Not with Iron Gut.
-- Mod data: rgGiven; bbLoad; bkLoad, bkClimbing; oiPart, oiFlare; pyEnd;
-- stChecked, stInHouse, stNewBed, stLastBed; obDay.
require "DanTraits"
require "DanTraits_Age"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local clamp01 = DanTraits_Clamp01

DanTraits_AgeOnly = {
    green          = { [20] = true },
    quickstudy     = { [20] = true },
    bottomlesspit  = { [20] = true },
    readingglasses = { [40] = true, [50] = true },
    badback        = { [40] = true, [50] = true },
    badknees       = { [40] = true, [50] = true },
    oldhand        = { [40] = true, [50] = true },
    delicatestomach = { [40] = true, [50] = true },
    paceyourself   = { [40] = true },
    settled        = { [40] = true },
    oldinjury      = { [50] = true },
    setinways      = { [50] = true },
    seenitall      = { [50] = true },
    castiron       = { [50] = true },
    oldbones       = { [50] = true },
}

-- experience
local QS_BELOW       = 5       -- Quick Study: skills under this level...
local QS_XP          = 1.4     -- ...gain experience x this (on top of the 20s band's x1.2 under level 3)
-- Bottomless Pit
local BP_HUNGER      = 1.3     -- hunger builds x this (on top of the 20s band's x1.15)
local BP_UNHAPPY     = { 0, 0, 0.1, 0.2, 0.2 }   -- unhappiness a minute awake by the Hungry moodle's level
-- Seen It All
local SI_PANIC       = 0.6     -- panic builds x this
local SI_FAINT       = 0.5     -- Fear of Blood faints x this
local SI_FILTH       = 0.5     -- Germaphobe's filth stress x this
-- Pace Yourself
local PY_SAVE        = 0.1     -- endurance spent swinging or sprinting, this share given back
-- Settled
local ST_PENALTY     = 0.2     -- off the night's quality (0..1) for a night off a house bed, or the first in a new one
-- Old Bones Know Rain
local OB_HOUR        = 6       -- the forecast is read once a day from this hour
local OB_COLD_C      = 0       -- tomorrow's lowest below this: a cold snap
-- Cast Iron
local CI_SIDE        = 0.5     -- side effects x this
local CI_OVER        = 1       -- the overdose line this many pills higher
-- Delicate Stomach
local DS_JUNK_SICK   = 15      -- food sickness from a whole junk meal
local DS_DRINK_SICK  = 10      -- food sickness from a drink on an empty stomach...
local DS_DRINK_HUNGER = 0.5    -- ...which is hunger over this
local OH_XP          = 1.25    -- Old Hand: every skill the occupation boosts x this
local SW_XP          = 0.85    -- Set in Their Ways: skills outside the occupation x this
-- Reading Glasses
local RG_ITEM        = "Base.Glasses_Reading"
local RG_SLOW        = 1.5     -- reading time x this without glasses on
local RG_LIGHT       = 0.45    -- and no reading under this light level (0.25 is a dark room, 0.6 a lit one)
-- Bad Back
local BB_RISE        = 0.004   -- load per minute per level of the Heavy Load moodle (level 2: full in about 2 hours)
local BB_EASE        = 0.004   -- off per minute with no heavy load...
local BB_EASE_ASLEEP = 2       -- ...x this asleep
local BB_PAIN        = 45      -- lower-back pain at a full load
-- Bad Knees
local BK_RUN         = 0.01    -- load per minute running
local BK_SPRINT      = 0.04    -- per minute sprinting
local BK_CLIMB       = 0.08    -- per fence, wall or window climbed
local BK_EASE        = 0.005   -- off per minute otherwise
local BK_PAIN        = 35      -- pain in each lower leg at a full load
-- both
local ACHE_NOTICE    = 0.3     -- load crossing this upward: a notice...
local ACHE_BAD       = 0.7     -- ...and this: a worse one
local ACHE_RAMP      = 5       -- pain added per minute at most
-- Old Injury
local OI_PARTS       = { "ForeArm_L", "ForeArm_R", "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }
local OI_STIFF_BASE  = 10      -- stiffness floor on the part, warm and dry
local OI_STIFF_FLARE = 35      -- floor in the full cold and damp
local OI_PAIN        = 20      -- pain on the part in the full cold and damp
local OI_FLARE       = 0.5     -- weather factor crossing this upward: a notice, and the pain starts

-- experience -------------------------------------------------------------------
local function inList(list, perk)
    for _, p in ipairs(list) do
        if p == perk then return true end
    end
    return false
end

local function xpFactor(player, perk)
    local k = 1
    if hasTrait(player, "quickstudy") then
        local level = QS_BELOW
        pcall(function() level = player:getPerkLevel(perk) end)
        if level < QS_BELOW then k = k * QS_XP end
    end
    -- Fitness and Strength are the body's, and age has its own say on them
    if Perks and (perk == Perks.Fitness or perk == Perks.Strength) then return k end
    local old, set = hasTrait(player, "oldhand"), hasTrait(player, "setinways")
    if old or set then
        local main, rest = DanTraits_AgeProfessionSkills(player)
        if inList(main, perk) or inList(rest, perk) then
            if old then k = k * OH_XP end
        elseif set then
            k = k * SW_XP
        end
    end
    return k
end

local function onAgeTraitsAddXP(player, perk, amount)
    if not player or not perk or not amount or amount <= 0 then return end
    local k = xpFactor(player, perk)
    if k ~= 1 then DanTraits_AgeXpAdjust(player, perk, amount * (k - 1)) end
end

-- Reading Glasses ----------------------------------------------------------------
-- anything worn that corrects sight: reading glasses and the prescription kinds
local function wearingGlasses(player)
    local found = false
    pcall(function()
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(i)
            local kind = item and item:getFullType() or ""
            if kind == "Base.Glasses" or kind == "Base.Glasses_Normal" or kind == "Base.Glasses_CatsEye"
                    or kind:find("Glasses_Reading", 1, true) or kind:find("Prescription", 1, true) then
                found = true
                return
            end
        end
    end)
    return found
end

local function needsGlasses(player)
    return hasTrait(player, "readingglasses") and not wearingGlasses(player)
end
DanTraits_NeedsGlasses = needsGlasses

local function tooDimToRead(player)
    local level = 1
    pcall(function()
        local square = player:getCurrentSquare()
        if square then level = square:getLightLevel(player:getPlayerNum()) end
    end)
    return level < RG_LIGHT
end

local function wrapReading()
    DanTraits_Wrap(ISReadABook, "getDuration", "glasses-read", function(original, self, ...)
        local t = original(self, ...)
        if type(t) == "number" and t > 1 and needsGlasses(self.character) then t = t * RG_SLOW end
        return t
    end)
    DanTraits_Wrap(ISReadABook, "isValid", "glasses-light", function(original, self, ...)
        if needsGlasses(self.character) and tooDimToRead(self.character) then
            if not self.danTraitsGlassesShown then
                self.danTraitsGlassesShown = true
                notify(self.character, "UI_DanTraits_GlassesTooDim")
            end
            return false
        end
        return original(self, ...)
    end)
end

local function onAgeTraitsCreatePlayer(playerNum, player)
    if not player then return end
    local d = DanTraits_Data(player)
    local new = true
    pcall(function() new = (player:getHoursSurvived() or 0) <= 0 end)
    if hasTrait(player, "readingglasses") and not d.rgGiven and new then
        d.rgGiven = true
        pcall(function() player:getInventory():AddItem(RG_ITEM) end)
    end
end

-- aches --------------------------------------------------------------------------
-- raise the part's additional pain toward target, by at most the ramp; never lower it
local function hurtPart(player, name, target)
    if target <= 0 then return end
    pcall(function()
        local part = player:getBodyDamage():getBodyPart(BodyPartType[name])
        if not part then return end
        local now = part:getAdditionalPain() or 0
        if now < target then part:setAdditionalPain(math.min(100, target, now + ACHE_RAMP)) end
    end)
end

-- move a load and say so when it crosses a line; returns the new load
local function ache(player, before, now, startKey, badKey, easedKey)
    now = clamp01(now)
    if now >= ACHE_BAD and before < ACHE_BAD then notify(player, badKey)
    elseif now >= ACHE_NOTICE and before < ACHE_NOTICE then notify(player, startKey)
    elseif now <= 0 and before > 0 then notifyGood(player, easedKey) end
    return now
end

local function heavyLoadLevel(player)
    local level = 0
    if MoodleType and MoodleType.HEAVY_LOAD then
        pcall(function() level = player:getMoodles():getMoodleLevel(MoodleType.HEAVY_LOAD) or 0 end)
    end
    return level
end

local function updateBadBack(player, d)
    if not hasTrait(player, "badback") then
        d.bbLoad = nil
        return
    end
    local before = d.bbLoad or 0
    local level = heavyLoadLevel(player)
    local now = before
    if level > 0 then
        now = before + BB_RISE * level
    else
        now = before - BB_EASE * (DanTraits_Asleep(player) and BB_EASE_ASLEEP or 1)
    end
    now = ache(player, before, now, "UI_DanTraits_BackAche", "UI_DanTraits_BackBad", "UI_DanTraits_BackEased")
    d.bbLoad = now > 0 and now or nil
    hurtPart(player, "Torso_Lower", BB_PAIN * now)
end

local function updateBadKnees(player, d)
    if not hasTrait(player, "badknees") then
        d.bkLoad, d.bkClimbing = nil, nil
        return
    end
    local before = d.bkLoad or 0
    local sprinting, running = false, false
    pcall(function() sprinting = player:isSprinting() end)
    pcall(function() running = player:isRunning() end)
    local now = before
    if sprinting then now = before + BK_SPRINT
    elseif running then now = before + BK_RUN
    else now = before - BK_EASE end
    now = ache(player, before, now, "UI_DanTraits_KneesAche", "UI_DanTraits_KneesBad", "UI_DanTraits_KneesEased")
    d.bkLoad = now > 0 and now or nil
    hurtPart(player, "LowerLeg_L", BK_PAIN * now)
    hurtPart(player, "LowerLeg_R", BK_PAIN * now)
end

-- per frame: each climb counts once, when it starts
local function isClimbing(player)
    local climbing = false
    pcall(function()
        local state = player:getCurrentState()
        if not state then return end
        climbing = (ClimbOverFenceState ~= nil and state == ClimbOverFenceState.instance())
            or (ClimbThroughWindowState ~= nil and state == ClimbThroughWindowState.instance())
            or (ClimbOverWallState ~= nil and state == ClimbOverWallState.instance())
    end)
    return climbing
end

local function updateBadKneesFrame(player, d)
    if not hasTrait(player, "badknees") then return end
    local climbing = isClimbing(player)
    if climbing and not d.bkClimbing then
        local before = d.bkLoad or 0
        d.bkLoad = ache(player, before, before + BK_CLIMB, "UI_DanTraits_KneesAche", "UI_DanTraits_KneesBad", "UI_DanTraits_KneesEased")
    end
    d.bkClimbing = climbing or nil
end

-- Old Injury ---------------------------------------------------------------------
local function partLabel(player, name)
    local label = nil
    pcall(function() label = BodyPartType.getDisplayName(BodyPartType[name]) end)
    return label or name
end

local function updateOldInjury(player, d)
    if not hasTrait(player, "oldinjury") then
        d.oiFlare = nil
        return
    end
    if not d.oiPart then
        d.oiPart = OI_PARTS[ZombRand(#OI_PARTS) + 1] or OI_PARTS[1]
        DanTraits_NotifyFmt(player, "UI_DanTraits_OldInjuryPart", partLabel(player, d.oiPart))
    end
    local weather = DanTraits_ArthritisJoint and DanTraits_ArthritisJoint(player) or 0
    local flaring = weather >= OI_FLARE
    if flaring and not d.oiFlare then notify(player, "UI_DanTraits_OldInjuryFlare") end
    d.oiFlare = flaring or nil
    local floor = OI_STIFF_BASE + (OI_STIFF_FLARE - OI_STIFF_BASE) * weather
    pcall(function()
        local part = player:getBodyDamage():getBodyPart(BodyPartType[d.oiPart])
        if part and (part:getStiffness() or 0) < floor then part:setStiffness(floor) end
    end)
    if flaring then hurtPart(player, d.oiPart, OI_PAIN * weather) end
end

-- Bottomless Pit ----------------------------------------------------------------
DanTraits_AddHook("hungerRise", function(delta, player)
    if not hasTrait(player, "bottomlesspit") then return nil end
    return delta * BP_HUNGER
end)

local function updateBottomlessPit(player, d)
    if not hasTrait(player, "bottomlesspit") or DanTraits_Asleep(player) then return end
    local level = 0
    pcall(function() level = player:getMoodles():getMoodleLevel(MoodleType.HUNGRY) or 0 end)
    local unhappy = BP_UNHAPPY[level + 1] or 0
    if unhappy > 0 then DanTraits_StatAdd(player:getStats(), CharacterStat.UNHAPPINESS, unhappy) end
end

-- Seen It All ----------------------------------------------------------------------
DanTraits_AddHook("panicRise", function(delta, player)
    if not hasTrait(player, "seenitall") then return nil end
    return delta * SI_PANIC
end)
DanTraits_AddHook("fearFaint", function(chance, player)
    if not hasTrait(player, "seenitall") then return nil end
    return chance * SI_FAINT
end)
DanTraits_AddHook("filthStress", function(stress, player)
    if not hasTrait(player, "seenitall") then return nil end
    return stress * SI_FILTH
end)

-- Pace Yourself -------------------------------------------------------------------
-- per frame: endurance that went on a swing or a sprint since the last frame,
-- a share of it given back; the delta pipeline is told so it does not read
-- the refund as recovery
local function updatePaceYourself(player, d)
    if not hasTrait(player, "paceyourself") then d.pyEnd = nil return end
    local stats = player:getStats()
    local now = tonumber(stats:get(CharacterStat.ENDURANCE))
    if not now then return end
    local was = d.pyEnd
    if was and now < was then
        local working = false
        pcall(function() working = player:isAttacking() or player:isSprinting() end)
        if working then
            local back = (was - now) * PY_SAVE
            DanTraits_StatAdd(stats, CharacterStat.ENDURANCE, back)
            now = math.min(1, now + back)
            DanTraits_DeltaRemember(d, "enduranceRegen", now)
        end
    end
    d.pyEnd = now
end

-- Settled -------------------------------------------------------------------------
-- where the sleeper lies is read once per sleep: the game's bed object, its
-- square's room (nil outdoors or in a tent), and whether it is the same bed
-- as last time
local function bedKey(bed)
    local key = nil
    pcall(function() local sq = bed:getSquare(); key = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() end)
    return key
end

local function updateSettled(player, d)
    if not hasTrait(player, "settled") then return end
    if not DanTraits_Asleep(player) then d.stChecked = nil return end
    if d.stChecked then return end
    d.stChecked = true
    local inHouse, key = false, nil
    pcall(function()
        local bed = player:getBed()
        if bed then
            key = bedKey(bed)
            inHouse = bed:getSquare() ~= nil and bed:getSquare():getRoom() ~= nil
        end
    end)
    d.stInHouse = inHouse
    d.stNewBed = key ~= nil and key ~= d.stLastBed
    d.stLastBed = key
end

DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not hasTrait(player, "settled") or not d then return nil end
    local worse = (not d.stInHouse) or d.stNewBed
    d.stNewBed = nil
    if not worse then return nil end
    return quality - ST_PENALTY
end)

-- Old Bones Know Rain -------------------------------------------------------------
-- once a day from OB_HOUR, tomorrow's forecast: a storm, heavy rain or a
-- blizzard, or a lowest temperature below freezing, is felt in the joints today
local function tomorrowLooks()
    local rain, cold = false, false
    pcall(function()
        local day = getClimateManager():getClimateForecaster():getForecast(1)
        if not day then return end
        rain = day:isHasStorm() or day:isHasTropicalStorm() or day:isHasHeavyRain() or day:isHasBlizzard()
        local t = day:getTemperature()
        if t and t:getTotalMin() <= OB_COLD_C then cold = true end
    end)
    return rain, cold
end

local function updateOldBones(player, d)
    if not hasTrait(player, "oldbones") or DanTraits_Asleep(player) then return end
    local hours = 0
    pcall(function() hours = getGameTime():getWorldAgeHours() or 0 end)
    local today = math.floor(hours / 24)
    if d.obDay == today or hours - today * 24 < OB_HOUR then return end
    d.obDay = today
    local rain, cold = tomorrowLooks()
    if rain then notify(player, "UI_DanTraits_OldBonesRain")
    elseif cold then notify(player, "UI_DanTraits_OldBonesCold") end
end

-- Cast Iron -------------------------------------------------------------------------
DanTraits_AddHook("medSideChance", function(chance, player)
    if not hasTrait(player, "castiron") then return nil end
    return chance * CI_SIDE
end)
DanTraits_AddHook("medOverAt", function(overAt, player)
    if not hasTrait(player, "castiron") then return nil end
    return overAt + CI_OVER
end)

-- Delicate Stomach ---------------------------------------------------------------
DanTraits_AddHook("eat", function(_, player, item, fraction)
    if not hasTrait(player, "delicatestomach") or not DanTraits_GradeFood then return nil end
    local grade, why = DanTraits_GradeFood(item)
    if tostring(why) ~= "junk" then return nil end
    DanTraits_StatAdd(player:getStats(), CharacterStat.FOOD_SICKNESS, DS_JUNK_SICK * (tonumber(fraction) or 1))
    return nil
end)
DanTraits_AddHook("alcoholDrunk", function(_, player)
    if not hasTrait(player, "delicatestomach") then return nil end
    local hunger = 0
    pcall(function() hunger = player:getStats():get(CharacterStat.HUNGER) or 0 end)
    if hunger <= DS_DRINK_HUNGER then return nil end
    DanTraits_StatAdd(player:getStats(), CharacterStat.FOOD_SICKNESS, DS_DRINK_SICK)
    return nil
end)

local function updateAgeTraitsMinute(player, d)
    updateBadBack(player, d)
    updateBadKnees(player, d)
    updateOldInjury(player, d)
    updateBottomlessPit(player, d)
    updateSettled(player, d)
    updateOldBones(player, d)
end

wrapReading()
Events.OnGameStart.Add(wrapReading)
Events.OnCreatePlayer.Add(onAgeTraitsCreatePlayer)
Events.AddXP.Add(onAgeTraitsAddXP)
DanTraits_Every("minute", "AgeTraits", updateAgeTraitsMinute, 40)
DanTraits_Every("frame", "AgeTraits", function(player, d) updateBadKneesFrame(player, d); updatePaceYourself(player, d) end, 40)
