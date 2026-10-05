-- Project Zomboid Vitality Project: the traits only one age can take.
-- DanTraits_AgeOnly says which bands may take each; the creation screen
-- (DanTraits_Client.lua) offers a trait only to those bands and drops it if
-- the age changes. Nothing here checks the band again after creation: a
-- character who has the trait has it. docs/age.md lists them.
--
--   20s      Green (-4)           every skill the occupation boosts starts a level
--                                 lower (DanTraits_AgeLevels in DanTraits_Age.lua)
--            Quick Study (+4)     a skill below level 3 gains experience x1.25
--   40s 50s  Reading Glasses (-2) starts with a pair; without glasses on, reading
--                                 takes x1.5 as long and needs a properly lit room
--            Bad Back (-4)        a heavy load builds lower-back pain; rest eases it
--            Bad Knees (-3)       running, sprinting and climbing build knee pain
--            Old Hand (+4)        the occupation's main skill gains experience x1.25
--   50s      Old Injury (-3)      one limb is always a little stiff, and stiffer and
--                                 sore in the cold and damp (Arthritis's weather
--                                 reading, on one part)
--            Set in Their Ways (-2) skills the occupation does not boost gain
--                                 experience x0.85
--
-- Mod data: rgGiven; bbLoad; bkLoad, bkClimbing; oiPart, oiFlare.
require "DanTraits"
require "DanTraits_Age"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local clamp01 = DanTraits_Clamp01

DanTraits_AgeOnly = {
    green          = { [20] = true },
    quickstudy     = { [20] = true },
    readingglasses = { [40] = true, [50] = true },
    badback        = { [40] = true, [50] = true },
    badknees       = { [40] = true, [50] = true },
    oldhand        = { [40] = true, [50] = true },
    oldinjury      = { [50] = true },
    setinways      = { [50] = true },
}

-- experience
local QS_BELOW       = 3       -- Quick Study: skills under this level...
local QS_XP          = 1.25    -- ...gain experience x this
local OH_XP          = 1.25    -- Old Hand: the occupation's main skill x this
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
        if inList(main, perk) then
            if old then k = k * OH_XP end
        elseif set and not inList(rest, perk) then
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

local function updateAgeTraitsMinute(player, d)
    updateBadBack(player, d)
    updateBadKnees(player, d)
    updateOldInjury(player, d)
end

wrapReading()
Events.OnGameStart.Add(wrapReading)
Events.OnCreatePlayer.Add(onAgeTraitsCreatePlayer)
Events.AddXP.Add(onAgeTraitsAddXP)
DanTraits_Every("minute", "AgeTraits", updateAgeTraitsMinute, 40)
DanTraits_Every("frame", "AgeTraits", updateBadKneesFrame, 40)
