-- Project Zomboid Vitality Project: the traits only one age can take.
-- Which bands may take each is a row of DanTraits_AgeRules
-- (DanTraits_AgeRules.lua, which also builds DanTraits_AgeOnly from them);
-- the creation screen (DanTraits_Client.lua) offers a trait only to those
-- bands and drops it if the age changes. Nothing here checks the band again
-- after creation: a character who has the trait has it. docs/age.md lists them.
--
--   20s      Quick Study (+4)     a skill below level 5 gains experience x1.4
--            Natural (+3)         the weapon skills, Aiming and Reloading gain
--                                 experience x1.25 (Age 2.0, 2026-10-31)
--            Hot-Headed (-3)      anger builds x1.5 (the angerFloor hook the
--                                 cravings' irritability reads) and falls x0.7
--                                 (the angerFall hook, DanTraits_Anger.lua)
--            Restless (-3)        the Itchy Feet want builds x2 and bites x2
--                                 (DanTraits_AgeWants.lua)
--            (Green, -4, every skill the occupation boosts a level lower, was
--            the 20s flaw until Age 2.0, 2026-10-31: the band takes the levels
--            itself now. Retired: DanTraits_RETIRED in DanTraits.lua.)
--   40s 50s  Reading Glasses (-2) starts with a pair; without glasses on, reading
--                                 takes x1.5 as long and needs a properly lit room
--            Bad Back (-8)        a heavy load builds lower-back pain and stiff legs
--                                 (slower walking); rest eases it; a sore back under
--                                 load can be thrown out (four hours of severe pain,
--                                 no running); core training eases it
--            Bad Knees (-3)       running, sprinting, climbing and stomping build knee
--                                 pain; walking never rests them, sitting rests them
--                                 faster, a comfy chair faster still
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
--   Seen It All (50s, costs 3): panic builds x0.8, Fear of Blood faints half
--     as often, Germaphobe's filth stress half. Not with Cowardly.
--   Pace Yourself (40s, costs 4 since 2026-10-14, was 2): a tenth of the endurance a swing or a
--     sprint spends is given back.
--   Settled (40s, gives 4 since 2026-10-08, was 2): a night anywhere but a bed in a house scores 0.2
--     worse, and so does the first night in a new bed.
--   Old Bones Know Rain (50s, costs 1): once a day, tomorrow's storm, heavy
--     rain, blizzard or a night below freezing is felt in the joints today.
--   Cast Iron (50s, costs 2): medication side effects half as often, the
--     overdose line a pill higher.
--   Delicate Stomach (40s and 50s, gives 2): a junk meal brings food
--     sickness, so does a drink on an empty stomach. Not with Iron Gut.
-- Mod data: rgGiven; bbLoad; bkLoad, bkClimbing, bkStomping; oiPart, oiFlare; pyEnd;
-- stChecked, stInHouse, stNewBed, stLastBed; obDay.
require "DanTraits"
require "DanTraits_Age"
require "DanTraits_AgeRules"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local clamp01 = DanTraits_Clamp01

-- (DanTraits_AgeOnly, the bands by registry key, is built in DanTraits_AgeRules.lua)

-- experience
local QS_BELOW       = 5       -- Quick Study: skills under this level...
local QS_XP          = 1.4     -- ...gain experience x this (on top of the 20s band's x1.3 under level 3)
local NT_XP          = 1.25    -- Natural: the weapon skills, Aiming and Reloading x this
local HH_RISE        = 1.5     -- Hot-Headed: the irritability a craving holds x this...
local HH_FALL        = 0.7     -- ...and anger falls x this
-- Bottomless Pit
local BP_HUNGER      = 1.3     -- hunger builds x this (on top of the 20s band's x1.15)
local BP_UNHAPPY     = { 0, 0, 0.1, 0.2, 0.2 }   -- unhappiness a minute awake by the Hungry moodle's level
-- Seen It All
local SI_PANIC       = 0.8     -- panic builds x this (0.6 until 2026-10-09: with Brave it was near-immunity)
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
local DS_DRINK_LITRES = 0.33   -- the drink that gives the whole DS_DRINK_SICK (a bottle of beer); less is pro rata
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
local BB_PAIN        = 60      -- lower-back pain at a full load (45 until 2026-10-18)
local BB_STIFF_BACK  = 30      -- lower-back stiffness at a full load (the game: clumsier)...
local BB_STIFF_LEGS  = 25      -- ...and on the thighs (the game: slower walking)
-- thrown out: a sore back under load gives way
local BB_OUT_FROM    = 0.5     -- back load from which it can go...
local BB_OUT_CHANCE  = 0.004   -- ...a minute, rising from 0 at BB_OUT_FROM to this at a full load
local BB_OUT_HEAVY   = 2       -- under Heavy Load this level or more, or lifting (DanTraits_BadBackStrain this minute)
local BB_OUT_MIN     = 240     -- four hours
local BB_OUT_PAIN    = 85      -- lower-back pain while it is out
local BB_OUT_BACK    = 70      -- lower-back stiffness
local BB_OUT_LEGS    = 40      -- stiffness on the thighs
local BB_OUT_AGAIN_D = 7       -- days after a throw-out it is likelier again...
local BB_OUT_AGAIN   = 2       -- ...this many times
-- a trained core (DanTraits_Fitness.lua: minutes over the last seven days on
-- sit-ups, burpees, carries) makes a stronger back, unless it was thrown out lately
local BB_CORE_FULL   = 90      -- minutes a week for the full benefit
local BB_CORE_RISE   = 0.4     -- the load builds x (1 - this x conditioning)
local BB_CORE_OUT    = 0.5     -- a throw-out x (1 - this x conditioning)
local BB_TIER        = { 0.3, 0.7 }   -- the Back Strain moodle: Aching Back, Bad Back; 3 thrown out
-- Bad Knees
local BK_RUN         = 0.01    -- load per minute running
local BK_SPRINT      = 0.04    -- per minute sprinting
local BK_CLIMB       = 0.08    -- per fence, wall or window climbed
local BK_STOMP       = 0.02    -- per stomp
local BK_EASE        = 0.005   -- off per minute standing still (walking holds the load where it is)
local BK_EASE_SIT    = 2       -- x sitting (on the ground or a seat) or lying asleep...
local BK_EASE_COMFY  = 3       -- ...x in a comfy chair: a seat the game would also let you sleep on (a sofa, an armchair)
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
local inList = DanTraits_InList

local function xpFactor(player, perk)
    local k = 1
    if hasTrait(player, "quickstudy") then
        local level = QS_BELOW
        pcall(function() level = player:getPerkLevel(perk) end)
        if level < QS_BELOW then k = k * QS_XP end
    end
    -- Fitness and Strength are the body's, and age has its own say on them
    if Perks and (perk == Perks.Fitness or perk == Perks.Strength) then return k end
    if hasTrait(player, "natural") and DanTraits_AgeIsCombatPerk and DanTraits_AgeIsCombatPerk(perk) then k = k * NT_XP end
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
    if k ~= 1 then DanTraits_XpFactor(player, perk, amount, k) end
end

-- Hot-Headed: the irritability a craving holds, and how fast anger falls
DanTraits_AddHook("angerFloor", function(k, player)
    if not hasTrait(player, "hotheaded") then return nil end
    return k * HH_RISE
end)
DanTraits_AddHook("angerFall", function(k, player)
    if not hasTrait(player, "hotheaded") then return nil end
    return k * HH_FALL
end)

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

local function onAgeTraitsCreate(player)
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
    DanTraits_PartPainAtLeast(player, name, target, ACHE_RAMP)
end

-- move a load and say so when it crosses a line; returns the new load
local function ache(player, before, now, startKey, badKey, easedKey)
    now = clamp01(now)
    if now >= ACHE_BAD and before < ACHE_BAD then notify(player, badKey)
    elseif now >= ACHE_NOTICE and before < ACHE_NOTICE then notify(player, startKey)
    elseif now <= 0 and before > 0 then notifyGood(player, easedKey) end
    return now
end

local function heavyLoadLevel(player) return DanTraits_MoodleLevel(player, "HEAVY_LOAD") end

-- raise a part's stiffness to at least this (the game eases it back by itself)
local stiffPart = DanTraits_PartStiffAtLeast

local bbDay = DanTraits_WorldDay

-- 0..1: how trained the core is this week; nothing for a while after a throw-out
local function backConditioning(player, d)
    if (d.bbOutDay or -1000) > bbDay() - BB_OUT_AGAIN_D then return 0 end
    local minutes = DanTraits_FitWeekMinutes and DanTraits_FitWeekMinutes(player, "core") or 0
    return clamp01(minutes / BB_CORE_FULL)
end
DanTraits_BackConditioning = function(player) return backConditioning(player, DanTraits_Data(player)) end

local function throwOut(player, d)
    d.bbOutMin = BB_OUT_MIN
    d.bbOutDay = bbDay()
    d.bbLoad = 1
    notify(player, "UI_DanTraits_BackOut")
end

local function updateBadBack(player, d)
    if not hasTrait(player, "badback") then
        d.bbLoad, d.bbOutMin, d.bbMoodle, d.bbLifted = nil, nil, nil, nil
        return
    end
    local before = d.bbLoad or 0
    local level = heavyLoadLevel(player)
    local cond = backConditioning(player, d)
    local now = before
    if level > 0 then
        now = before + BB_RISE * level * (1 - BB_CORE_RISE * cond)
    elseif (d.bbOutMin or 0) <= 0 then
        now = before - BB_EASE * (DanTraits_Asleep(player) and BB_EASE_ASLEEP or 1)
    end
    now = ache(player, before, now, "UI_DanTraits_BackAche", "UI_DanTraits_BackBad", "UI_DanTraits_BackEased")
    d.bbLoad = now > 0 and now or nil

    -- thrown out: a sore back under a heavy load, or a lift, can give way
    local lifting = d.bbLifted
    d.bbLifted = nil
    if (d.bbOutMin or 0) <= 0 and now > BB_OUT_FROM and (level >= BB_OUT_HEAVY or lifting) then
        local chance = BB_OUT_CHANCE * (now - BB_OUT_FROM) / (1 - BB_OUT_FROM) * (1 - BB_CORE_OUT * cond)
        if (d.bbOutDay or -1000) > bbDay() - BB_OUT_AGAIN_D then chance = chance * BB_OUT_AGAIN end
        if DanTraits_Roll(chance) then throwOut(player, d) end
    end

    -- the backRelief hook (a muscle relaxant): the pain and stiffness x this
    -- (the load and the chance of throwing it out are left alone)
    local relief = tonumber(DanTraits_RunHooks("backRelief", 1, player, d, (d.bbOutMin or 0) > 0)) or 1
    if (d.bbOutMin or 0) > 0 then
        d.bbOutMin = d.bbOutMin - 1
        hurtPart(player, "Torso_Lower", BB_OUT_PAIN * relief)
        stiffPart(player, "Torso_Lower", BB_OUT_BACK * relief)
        stiffPart(player, "UpperLeg_L", BB_OUT_LEGS * relief)
        stiffPart(player, "UpperLeg_R", BB_OUT_LEGS * relief)
        if d.bbOutMin <= 0 then
            d.bbOutMin = nil
            notifyGood(player, "UI_DanTraits_BackOutOver")
        end
    else
        hurtPart(player, "Torso_Lower", BB_PAIN * now * relief)
        stiffPart(player, "Torso_Lower", BB_STIFF_BACK * now * relief)
        stiffPart(player, "UpperLeg_L", BB_STIFF_LEGS * now * relief)
        stiffPart(player, "UpperLeg_R", BB_STIFF_LEGS * now * relief)
    end
    -- the Back Strain moodle (DanTraits_Moodles.lua)
    d.bbMoodle = (d.bbOutMin or 0) > 0 and 3 or DanTraits_TierOf(d.bbLoad or 0, BB_TIER)
end

-- strain from work other than carrying (laundry's washboard,
-- DanTraits_LaundryTraits.lua; an improvised lift, DanTraits_Fitness.lua): the
-- same load, so it eases the same way, and a lift this minute can throw it out
function DanTraits_BadBackStrain(player, amount)
    if not player or not hasTrait(player, "badback") then return false end
    local d = DanTraits_Data(player)
    local before = d.bbLoad or 0
    local add = (tonumber(amount) or 0) * (1 - BB_CORE_RISE * backConditioning(player, d))
    local now = ache(player, before, before + add, "UI_DanTraits_BackAche", "UI_DanTraits_BackBad", "UI_DanTraits_BackEased")
    d.bbLoad = now > 0 and now or nil
    d.bbLifted = true
    return true
end

-- heat on a sore back (a hot water bottle, DanTraits_HotWaterBottle.lua): the
-- load eases by `amount` more, and a thrown-out back's minutes run `outMin`
-- a minute faster (it still ends in updateBadBack, with its notice)
function DanTraits_BadBackEase(player, amount, outMin)
    if not player or not hasTrait(player, "badback") then return false end
    local d = DanTraits_Data(player)
    if (d.bbOutMin or 0) > 0 then
        d.bbOutMin = math.max(1, d.bbOutMin - (tonumber(outMin) or 0))
        return true
    end
    local before = d.bbLoad or 0
    if before <= 0 then return true end
    local now = ache(player, before, before - (tonumber(amount) or 0), "UI_DanTraits_BackAche", "UI_DanTraits_BackBad", "UI_DanTraits_BackEased")
    d.bbLoad = now > 0 and now or nil
    return true
end

-- per frame, while the back is out: no running, no sprinting
local function updateBadBackFrame(player, d)
    if (d.bbOutMin or 0) <= 0 or not hasTrait(player, "badback") then return end
    local tried = false
    pcall(function()
        if player:isSprinting() then player:setSprinting(false); tried = true end
        if player:isRunning() then player:setRunning(false); tried = true end
    end)
    if tried then pcall(function() player:setMoodleCantSprint(true) end) end
end

-- how the knees are resting: 0 walking (no rest), 1 standing still, BK_EASE_SIT
-- sitting or asleep, BK_EASE_COMFY in a seat you could sleep on
local function kneeRest(player)
    local sitting, comfy, moving = false, false, false
    pcall(function() sitting = player:isSitOnGround() == true end)
    pcall(function() if player:isSittingOnFurniture() then
        sitting = true
        local props = player:getSitOnFurnitureObject():getProperties()
        comfy = props:get("BedType") ~= nil or (IsoFlagType and props:has(IsoFlagType.bed) == true)
    end end)
    if comfy then return tonumber(DanTraits_RunHooks("kneeRest", BK_EASE_COMFY, player, true)) or BK_EASE_COMFY end   -- Comfort matters more (the 50s want)
    if sitting or DanTraits_Asleep(player) then return BK_EASE_SIT end
    pcall(function() moving = player:isPlayerMoving() == true end)
    return moving and 0 or 1
end

local function updateBadKnees(player, d)
    if not hasTrait(player, "badknees") then
        d.bkLoad, d.bkClimbing, d.bkStomping = nil, nil, nil
        return
    end
    local before = d.bkLoad or 0
    local sprinting, running = false, false
    pcall(function() sprinting = player:isSprinting() end)
    pcall(function() running = player:isRunning() end)
    local now = before
    if sprinting then now = before + BK_SPRINT
    elseif running then now = before + BK_RUN
    else now = before - BK_EASE * kneeRest(player) end
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

local function isStomping(player)
    local stomping = false
    pcall(function() stomping = player:isPerformingStompAnimation() == true end)
    return stomping
end

-- per frame: each climb and each stomp counts once, when it starts
local function updateBadKneesFrame(player, d)
    if not hasTrait(player, "badknees") then return end
    local climbing = isClimbing(player)
    if climbing and not d.bkClimbing then
        local before = d.bkLoad or 0
        d.bkLoad = ache(player, before, before + BK_CLIMB, "UI_DanTraits_KneesAche", "UI_DanTraits_KneesBad", "UI_DanTraits_KneesEased")
    end
    d.bkClimbing = climbing or nil
    local stomping = isStomping(player)
    if stomping and not d.bkStomping then
        local before = d.bkLoad or 0
        d.bkLoad = ache(player, before, before + BK_STOMP, "UI_DanTraits_KneesAche", "UI_DanTraits_KneesBad", "UI_DanTraits_KneesEased")
    end
    d.bkStomping = stomping or nil
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
    stiffPart(player, d.oiPart, OI_STIFF_BASE + (OI_STIFF_FLARE - OI_STIFF_BASE) * weather)
    if flaring then hurtPart(player, d.oiPart, OI_PAIN * weather) end
end

-- Bottomless Pit ----------------------------------------------------------------
DanTraits_AddHook("hungerRise", function(delta, player)
    if not hasTrait(player, "bottomlesspit") then return nil end
    return delta * BP_HUNGER
end)

local function updateBottomlessPit(player, d)
    if not hasTrait(player, "bottomlesspit") or DanTraits_Asleep(player) then return end
    local level = DanTraits_MoodleLevel(player, "HUNGRY")
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
    local hours = DanTraits_WorldHours()
    local today = math.floor(hours / 24)   -- DanTraits_WorldDay, from the same reading
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
-- once per drink (the Diabetes drink wrap sums the sips), with the litres swallowed
DanTraits_AddHook("alcoholDrunk", function(_, player, _, litres)
    if not hasTrait(player, "delicatestomach") then return nil end
    local hunger = 0
    pcall(function() hunger = player:getStats():get(CharacterStat.HUNGER) or 0 end)
    if hunger <= DS_DRINK_HUNGER then return nil end
    local share = litres and math.min(1, litres / DS_DRINK_LITRES) or 1
    DanTraits_StatAdd(player:getStats(), CharacterStat.FOOD_SICKNESS, DS_DRINK_SICK * share)
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
DanTraits_OnPlayerReady("AgeTraits", onAgeTraitsCreate, 55)   -- Reading Glasses' pair
Events.AddXP.Add(onAgeTraitsAddXP)
DanTraits_Every("minute", "AgeTraits", updateAgeTraitsMinute, 40)
DanTraits_Every("frame", "AgeTraits", function(player, d) updateBadKneesFrame(player, d); updatePaceYourself(player, d); updateBadBackFrame(player, d) end, 40)
