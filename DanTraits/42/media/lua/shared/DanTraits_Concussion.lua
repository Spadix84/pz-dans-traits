-- Project Zomboid Vitality Project: concussion (health overhaul, phase 5).
--
-- Not a trait: every character has it. A hard knock to the head leaves a
-- concussion, a score (ccScore, 0..1) that sets how bad it is:
--   mild      (under CC_MODERATE) a headache, drowsy
--   moderate  sick to the stomach too, light hurts, slow to get your breath
--             back (the enduranceRegen hook of the stat delta pipeline), and running can bring on a dizzy spell (a fall)
--   severe    (CC_SEVERE and over) all of it worse; the blow itself knocks
--             you out for 5 to 15 game minutes (DanTraits_Faint.lua)
-- Rest heals it, sleep twice as fast; running, sprinting and fighting
-- stop it healing and make it a little worse. A second knock while still
-- concussed lands on top of the first. It brings on migraine attacks
-- (Migraines) and makes light wake you more easily (sleep and light).
--
-- What counts as a knock (the game's own damage reports, OnPlayerGetDamage):
--   FALLDOWN       a fall: the amount is the health it cost (vanilla
--                  IsoGameCharacter.handleLandingImpact; 1000 for a lethal
--                  one). The last one is kept in ccLastImpact.
--   CARCRASHDAMAGE, CARHITDAMAGE   a car crash, being hit by a car
--   WEAPONHIT      a weapon hit (other players, or mods that add them) that
--                  took health off the head
-- A helmet (the head's clothing defense, CC_HELMET or more) makes a
-- concussion less likely and less bad.
--
-- Hook offered: concussionHeal (the score healed a minute, player, d);
-- Vitality speeds it up or slows it.
require "DanTraits"

local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood or DanTraits_Notify
local traitData = DanTraits_Data
local fraction = DanTraits_StatFraction

local CC_MIN_IMPACT    = 3       -- a fall or crash costing under this: no concussion
local CC_SURE_IMPACT   = 15      -- ...certain from here (in play a second-floor drop costs
                                 -- about 5, a third-floor one about 7: the rest of a fall's
                                 -- harm goes to the legs as wounds and breaks)
local CC_BASE          = 0.25    -- how bad at the least...
local CC_PER_IMPACT    = 0.04    -- ...plus this per point over the minimum
local CC_HEAD_SURE     = 20      -- a weapon taking this much off the head: certain
local CC_HEAD_PER      = 0.025   -- how bad per point off the head, over CC_BASE
local CC_HELMET        = 50      -- head clothing defense counted as a helmet
local CC_HELMET_CHANCE = 0.4     -- x chance with a helmet
local CC_HELMET_SCORE  = 0.6     -- x how bad with a helmet
local CC_STACK         = 0.5     -- a second knock adds this x the smaller of the two
local CC_MODERATE      = 0.4
local CC_SEVERE        = 0.7
local CC_KO_MIN        = { 5, 15 }   -- severe: minutes out cold, from CC_SEVERE to 1
local CC_KO_MODERATE   = 0.25    -- moderate: chance of a brief blackout...
local CC_KO_BRIEF      = { 1, 3 }    -- ...this many minutes
local CC_HEAL_DAY      = 0.25    -- score healed a game day awake at rest
local CC_HEAL_ASLEEP   = 2       -- x asleep
local CC_STRAIN        = 0.0005  -- score added a minute running, sprinting or fighting
local CC_PAIN          = { 15, 35 }  -- head pain floor: this, plus this x score
local CC_LIGHT_PAIN    = 10      -- more in bright daylight (moderate and worse)
local CC_SICK          = 0.3     -- food sickness floor x score (moderate and worse)
local CC_FATIGUE       = 0.0003  -- tiredness a minute awake x score
local CC_ENDURANCE     = 0.3     -- endurance recovery x (1 - this x score)
local CC_DIZZY         = 0.18    -- chance a minute of running of a dizzy fall x score (moderate and worse)
local CC_WAKE          = 1       -- light wakes you (1 + this x score) times as easily
local CC_TIER          = { 0.02, CC_MODERATE, CC_SEVERE }

local clamp01 = DanTraits_Clamp01

local function sandboxOn() return DanTraits_SandboxOn("ConcussionEnabled") end
function DanTraits_ConcussionActive() return sandboxOn() end

local roll = DanTraits_Roll
local randRange = DanTraits_RandRange

-- 0..1, for other systems (Migraines, the health panel)
function DanTraits_ConcussionStrength(player)
    local d = player and player:getModData().DanTraits
    return (d and d.ccScore) or 0
end

local function helmeted(player)
    local defense = 0
    pcall(function()
        defense = player:getBodyPartClothingDefense(BodyPartType.ToIndex(BodyPartType.Head), false, false) or 0
    end)
    return defense >= CC_HELMET
end
DanTraits_Helmeted = helmeted

local function headPart(player)
    local part = nil
    pcall(function() part = player:getBodyDamage():getBodyPart(BodyPartType.Head) end)
    return part
end

-- a knock: chance 0..1 that it concusses, and how bad (0..1)
function DanTraits_KnockHead(player, chance, score)
    if not player or player:isDead() or not sandboxOn() then return 0 end
    if helmeted(player) then chance, score = chance * CC_HELMET_CHANCE, score * CC_HELMET_SCORE end
    if not roll(chance) then return 0 end
    local d = traitData(player)
    local old = d.ccScore or 0
    local new = clamp01(math.max(old, score) + CC_STACK * math.min(old, score))
    d.ccScore = new
    if score >= CC_SEVERE or new >= CC_SEVERE and old > 0 then
        local t = clamp01((new - CC_SEVERE) / (1 - CC_SEVERE))
        if DanTraits_PassOut then DanTraits_PassOut(player, CC_KO_MIN[1] + (CC_KO_MIN[2] - CC_KO_MIN[1]) * t, "UI_DanTraits_ConcussionComeTo", true) end
    elseif new >= CC_MODERATE and roll(CC_KO_MODERATE) then
        if DanTraits_PassOut then DanTraits_PassOut(player, randRange(CC_KO_BRIEF[1], CC_KO_BRIEF[2]), "UI_DanTraits_ConcussionComeTo", true) end
    else
        notify(player, new >= CC_MODERATE and "UI_DanTraits_ConcussionModerate" or "UI_DanTraits_ConcussionMild")
    end
    return new
end

-- a fall or crash costing this much health
local function impactKnock(player, amount)
    if amount < CC_MIN_IMPACT or amount >= 1000 then return 0 end
    local chance = clamp01((amount - CC_MIN_IMPACT) / (CC_SURE_IMPACT - CC_MIN_IMPACT))
    local score = clamp01(CC_BASE + CC_PER_IMPACT * (amount - CC_MIN_IMPACT))
    return DanTraits_KnockHead(player, chance, score)
end
DanTraits_ImpactKnock = impactKnock

local headWas = nil   -- the head's health last frame, for weapon hits
local function onConcussionDamage(character, damageType, amount)
    if not sandboxOn() then return end
    local player = getSpecificPlayer(0)
    if not player or character ~= player then return end
    amount = tonumber(amount) or 0
    if damageType == "FALLDOWN" or damageType == "CARCRASHDAMAGE" or damageType == "CARHITDAMAGE" then
        traitData(player).ccLastImpact = damageType .. " " .. tostring(math.floor(amount * 100 + 0.5) / 100)
        impactKnock(player, amount)
    elseif damageType == "WEAPONHIT" then
        local head = headPart(player)
        local now = nil
        pcall(function() now = head:getHealth() end)
        if now and headWas and now < headWas then
            local lost = headWas - now
            DanTraits_KnockHead(player, clamp01(lost / CC_HEAD_SURE), clamp01(CC_BASE + CC_HEAD_PER * lost))
        end
    end
end

-- per frame: the head's health (for the next weapon hit), whether the player ran
local ran = false
local function updateConcussionFrame(player)
    local head = headPart(player)
    if head then pcall(function() headWas = head:getHealth() end) end
    local okS, sprinting = pcall(function() return player:isSprinting() end)
    local okR, running = pcall(function() return player:isRunning() end)
    if (okS and sprinting) or (okR and running) then ran = true end
end
DanTraits_updateConcussionFrame = updateConcussionFrame

-- slower endurance recovery, through the stat delta pipeline (DanTraits_Util.lua)
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    local s = d and d.ccScore or 0
    if s <= 0 or not sandboxOn() then return nil end
    return delta * (1 - CC_ENDURANCE * s)
end)

local fought = false
local function onConcussionSwing(character)
    local player = getSpecificPlayer(0)
    if player and character == player then fought = true end
end

local function updateMoodle(player, s)
    DanTraits_BadMoodle(player, "Concussion", s, CC_TIER)
end

local function inBright(player)
    if not DanTraits_InBrightLight then return false end
    local ok, res = pcall(DanTraits_InBrightLight, player)
    return ok and res == true
end

local function updateConcussionMinute(player, d)
    if not sandboxOn() then return end
    local strained = ran or fought
    ran, fought = false, false
    local s = d.ccScore or 0
    if s <= 0 then
        if d.ccTier and d.ccTier > 0 then d.ccTier = 0 end
        updateMoodle(player, 0)
        return
    end
    local asleep = DanTraits_Asleep(player)
    if strained then
        s = s + CC_STRAIN
    else
        s = s - DanTraits_RunHooks("concussionHeal", CC_HEAL_DAY / 1440 * (asleep and CC_HEAL_ASLEEP or 1), player, d)
    end
    s = clamp01(s)
    if s < 0.005 then s = 0 end
    d.ccScore = s > 0 and s or nil
    local tier = 0
    for i, threshold in ipairs(CC_TIER) do if s >= threshold then tier = i end end
    if tier == 0 and (d.ccTier or 0) > 0 then notifyGood(player, "UI_DanTraits_ConcussionClear") end
    d.ccTier = tier
    updateMoodle(player, s)
    if s <= 0 then return end

    -- the headache
    local head = headPart(player)
    local pain = CC_PAIN[1] + CC_PAIN[2] * s
    if s >= CC_MODERATE and inBright(player) then pain = pain + CC_LIGHT_PAIN end
    if head then
        pcall(function() if head:getAdditionalPain() < pain then head:setAdditionalPain(pain) end end)
    end
    local stats = player:getStats()
    if s >= CC_MODERATE then
        pcall(function()
            -- straight to the floor (a ramp as wide as the stat), recorded as a mod floor
            local stat = CharacterStat.FOOD_SICKNESS
            local max = DanTraits_StatMax(stat)
            DanTraits_FloorUp(stats, stat, CC_SICK * s * max, max)
        end)
        if strained and not asleep and roll(CC_DIZZY * s) then
            if DanTraits_Collapse then DanTraits_Collapse(player) end
            notify(player, "UI_DanTraits_ConcussionDizzy")
        end
    end
    if not asleep then
        pcall(function() stats:set(CharacterStat.FATIGUE, math.min(1, (stats:get(CharacterStat.FATIGUE) or 0) + CC_FATIGUE * s)) end)
    end
end
DanTraits_updateConcussionMinute = updateConcussionMinute

-- light wakes a concussed sleeper more easily
DanTraits_AddHook("sleepWake", function(m, player)
    local s = DanTraits_ConcussionStrength(player)
    if s <= 0 then return nil end
    return m * (1 + CC_WAKE * s)
end)

-- console: concussion <score> | concussion fall <amount> | concussion clear
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.concussion = function(player, args)
    local d = traitData(player)
    if args[1] == "clear" then d.ccScore = nil; return "concussion cleared" end
    if args[1] == "fall" then
        local amount = tonumber(args[2]) or 30
        return "a fall costing " .. tostring(amount) .. ": concussion " .. tostring(impactKnock(player, amount))
    end
    local s = tonumber(args[1])
    if not s then return "concussion <0..1> | concussion fall <amount> | concussion clear" end
    return "concussion " .. tostring(DanTraits_KnockHead(player, 1, clamp01(s)))
end

Events.OnPlayerGetDamage.Add(onConcussionDamage)
DanTraits_Every("minute", "Concussion", updateConcussionMinute, 24)
DanTraits_Every("frame", "Concussion", function(player)
    if sandboxOn() then updateConcussionFrame(player) end
end, 24)
Events.OnWeaponSwing.Add(onConcussionSwing)
