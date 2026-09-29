-- Project Zomboid Vitality Project: wound care (health overhaul, phase 3).
--
-- Not a trait: every character has it. Wounds are ongoing work:
--   dressings  a bandage wears out over about a day (WC_AGE_H life an
--              hour; a bandage starts near 5, a rag near 3), faster wet and
--              faster still soaking up blood. Spent (the game's "dirty":
--              life 0), it only half slows a bleed (DanTraits_Blood.lua) and
--              invites infection (DanTraits_Infection.lua). Change it.
--   deep       an unstitched deep wound heals at WC_UNSTITCHED of the speed
--   wounds     (the woundHeal hook: Vitality, Smoker), and hard use of the
--              limb can open it bleeding again.
--   stitches   fresh stitches can tear: sprinting or running on a stitched
--              leg, swinging a weapon with a stitched arm, either on the
--              torso. They hold better as they heal (the game's stitch
--              time climbs to 50; past 40 they are sound). Torn, the wound
--              is open and bleeding again, and needs stitching again.
--   splints    setting one is a First Aid roll (WC_BADSET by level): set
--              badly, the bone heals at half the speed and hurts more; take
--              it off and set it again. Walking on a broken leg with no
--              splint makes the break worse.
--
-- Vanilla (BodyPart.DamageUpdate, read from the jar): bandageLife drains
-- 0.005 a tick while a deep wound bleeds (in play: a fresh bandage spent in
-- about four minutes) and 0.0001 over stitches; both are undone here, and
-- the wear above replaces them. isBandageDirty is just life <= 0. A bandage clears the part's stitched
-- flag and keeps stitchTime, so stitches are read from stitchTime here.
-- setStitched(false) on a flagged part reopens it (deep wound and bleeding
-- times from the stitch time); under a bandage the times are set directly.
-- A splint heals a fracture at 5e-5 x splintFactor a tick, (level + 1) / 2
-- from ISSplint; unsplinted 5e-6.
-- ISSplint.complete is wrapped through DanTraits_Wrap (DanTraits.lua), tag
-- "woundcare-splint-set", so Fear of Blood can layer on the splint action too.
require "DanTraits"

local traitData = DanTraits_Data

local WC_AGE_H         = 0.2     -- bandage life lost an hour
local WC_WET           = 2       -- x (1 + this x wetness)
local WC_SOAK          = 1.5     -- bandage life lost per 1% of blood through it
local WC_UNSTITCHED    = 0.35    -- an unstitched deep wound heals at this speed
local WC_REOPEN_SWING  = 0.01    -- chance an unstitched deep wound opens, per swing with that arm
local WC_REOPEN_SPRINT = 0.03    -- ...per minute sprinting on that leg (running a third of it)
local WC_TEAR_SWING    = 0.02    -- chance fresh stitches tear, per swing with that arm
local WC_TEAR_SPRINT   = 0.05    -- ...per minute sprinting on that leg (running a third of it)
local WC_TORSO         = 0.3     -- torso: x the arm's per swing and the leg's per minute
local WC_TWO_HANDED    = 1.5     -- x for a two-handed swing
local WC_BANDAGE_HOLDS = 0.7     -- x under a bandage
local WC_SOUND_AT      = 40      -- stitch time: sound from here (the game's own line)
local WC_REOPEN_DEEP   = { 5, 10 }  -- deep wound time when torn open
local WC_REOPEN_BLEED  = { 3, 6 }   -- bleeding time when torn or opened
local WC_BADSET        = { 0.5, 0.06, 0.02 }  -- bad-set chance: at level 0, less per level, never under
local WC_BADSET_FACTOR = 0.5     -- x splint factor when set badly
local WC_BADSET_PAIN   = 15      -- pain held on a badly set bone
local WC_LIMP          = 1       -- fracture time added an hour moving on an unsplinted broken leg
                                 -- (one rate: the game won't let a broken leg run, though it
                                 -- still reports running while the run key is held)

local LEGS  = { UpperLeg_L = true, UpperLeg_R = true, LowerLeg_L = true, LowerLeg_R = true, Foot_L = true, Foot_R = true, Groin = true }
local ARMS_R = { Hand_R = true, ForeArm_R = true, UpperArm_R = true }
local ARMS_L = { Hand_L = true, ForeArm_L = true, UpperArm_L = true }
local TORSO = { Torso_Upper = true, Torso_Lower = true }

local function sandboxOn() return DanTraits_SandboxOn("WoundCareEnabled") end
function DanTraits_WoundCareActive() return sandboxOn() end

local num = DanTraits_PartNum
local is = DanTraits_PartIs
local roll = DanTraits_Roll
local randRange = DanTraits_RandRange

-- "Left Forearm" and so on, for the notices
local function partLabel(part)
    local label = nil
    pcall(function() label = BodyPartType.getDisplayName(part:getType()) end)
    return label or tostring(part:getType())
end
local function say(player, key, part)
    pcall(function() HaloTextHelper.addBadText(player, getText(key, partLabel(part))) end)
end

local function wcData(player)
    local d = traitData(player)
    d.wcParts = d.wcParts or {}
    return d
end
local function recOf(d, name)
    local rec = d.wcParts[name]
    if not rec then rec = {}; d.wcParts[name] = rec end
    return rec
end

-- 0..1 how well stitches hold; nil for no stitches
local function stitchStrength(part)
    local t = num(part, "getStitchTime")
    if t <= 0 then return nil end
    return math.min(1, t / WC_SOUND_AT)
end
DanTraits_StitchStrength = stitchStrength

local function wetness(player)
    local w = 0
    pcall(function() w = DanTraits_StatFraction(player:getStats(), CharacterStat.WETNESS) end)
    return w
end

-- tear open: stitches gone, deep wound and bleed back
local function tearOpen(player, part)
    local bandaged = is(part, "bandaged")
    pcall(function()
        if not bandaged then part:setStitched(false) end
        part:setStitchTime(0)
        part:setDeepWoundTime(randRange(WC_REOPEN_DEEP[1], WC_REOPEN_DEEP[2]))
        part:setBleedingTime(randRange(WC_REOPEN_BLEED[1], WC_REOPEN_BLEED[2]))
        if not bandaged then
            part:setDeepWounded(true)
            part:setBleeding(true)
        end
    end)
    say(player, "UI_DanTraits_StitchesTore", part)
end

local function openAgain(player, part)
    local bandaged = is(part, "bandaged")
    pcall(function()
        part:setBleedingTime(randRange(WC_REOPEN_BLEED[1], WC_REOPEN_BLEED[2]))
        if not bandaged then part:setBleeding(true) end
    end)
    say(player, "UI_DanTraits_WoundOpened", part)
end

-- one bout of strain on a part: a swing (chances per swing) or a minute on
-- the legs (chances per minute)
local function strain(player, part, tearChance, reopenChance)
    local s = stitchStrength(part)
    if is(part, "bandaged") then tearChance, reopenChance = tearChance * WC_BANDAGE_HOLDS, reopenChance * WC_BANDAGE_HOLDS end
    if s then
        if s < 1 and roll(tearChance * (1 - s)) then tearOpen(player, part) end
    elseif num(part, "getDeepWoundTime") > 0 and num(part, "getBleedingTime") <= 0 then
        if roll(reopenChance) then openAgain(player, part) end
    end
end
DanTraits_WoundStrain = strain

-- the bone-setting roll, by the setter's First Aid level
local function badSetChance(level)
    return math.max(WC_BADSET[3], WC_BADSET[1] - WC_BADSET[2] * (level or 0))
end
DanTraits_BadSetChance = badSetChance

function DanTraits_OnSplintSet(patient, part, level)
    if not patient or not part or not sandboxOn() then return false end
    local d = wcData(patient)
    local rec = recOf(d, tostring(part:getType()))
    rec.badSet = roll(badSetChance(level)) or nil
    if rec.badSet then
        pcall(function() part:setSplintFactor(part:getSplintFactor() * WC_BADSET_FACTOR) end)
        -- only someone who knows bones can tell
        if (level or 0) >= 3 then say(patient, "UI_DanTraits_BadSet", part) end
    end
    return rec.badSet == true
end

-- per frame: what the legs did this minute (false, "walk", "run", "sprint")
local moved = false
local function updateWoundFrame(player)
    local ok, sprinting = pcall(function() return player:isSprinting() end)
    local ok2, running = pcall(function() return player:isRunning() end)
    local ok3, moving = pcall(function() return player:isPlayerMoving() end)
    if ok and sprinting then moved = "sprint" elseif (ok2 and running) and moved ~= "sprint" then moved = "run"
    elseif ok3 and moving and not moved then moved = "walk" end
end
DanTraits_updateWoundFrame = updateWoundFrame

local function round2(x) return math.floor(x * 100 + 0.5) / 100 end

local function updatePart(player, d, part, name, wet, summary)
    local rec = d.wcParts[name]
    -- dressings: worn out here, or soaked by vanilla's own bleed drain;
    -- either way, say so once
    if is(part, "bandaged") then
        local life = num(part, "getBandageLife")
        -- vanilla's own drain (0.005 a tick under a bleeding deep wound: a
        -- bandage spent in minutes) is put back; a higher life is a new bandage
        local was = d.wcLife[name]
        if was and life < was then
            life = was
            pcall(function() part:setBandageLife(life) end)
        end
        if life > 0 then
            local loss = WC_AGE_H / 60 * (1 + WC_WET * wet)
            if DanTraits_BloodPartRate then
                local okR, rate = pcall(DanTraits_BloodPartRate, part)
                if okR and rate then loss = loss + rate * 100 * WC_SOAK end
            end
            life = math.max(0, life - loss)
            pcall(function() part:setBandageLife(life) end)
        end
        if life <= 0 and (d.wcLife[name] or 0) > 0 then say(player, "UI_DanTraits_DressingSpent", part) end
        d.wcLife[name] = life
        summary[#summary + 1] = name .. " dressing " .. tostring(round2(life))
    else
        d.wcLife[name] = nil
    end
    local s = stitchStrength(part)
    if s then summary[#summary + 1] = name .. " stitches " .. tostring(math.floor(s * 100)) .. "%" end
    -- unstitched deep wounds heal slowly
    local deep = num(part, "getDeepWoundTime")
    if deep > 0 and num(part, "getStitchTime") <= 0 then
        rec = rec or recOf(d, name)
        if rec.deep and deep < rec.deep then
            deep = rec.deep - (rec.deep - deep) * math.min(1, DanTraits_RunHooks("woundHeal", WC_UNSTITCHED, player, part))
            pcall(function() part:setDeepWoundTime(deep) end)
        end
        rec.deep = deep
        summary[#summary + 1] = name .. " deep wound, unstitched " .. tostring(round2(deep))
    elseif rec then
        rec.deep = nil
    end
    -- fractures
    local fracture = num(part, "getFractureTime")
    if fracture > 0 then
        summary[#summary + 1] = name .. " fracture " .. tostring(round2(fracture))
            .. (is(part, "isSplint") and (" splinted x" .. tostring(round2(num(part, "getSplintFactor")))) or " no splint")
            .. ((rec and rec.badSet) and " (set badly)" or "")
        if rec and rec.badSet and is(part, "isSplint") then
            pcall(function()
                if part:getAdditionalPain() < WC_BADSET_PAIN then part:setAdditionalPain(WC_BADSET_PAIN) end
            end)
        end
        if LEGS[name] and not is(part, "isSplint") and moved then
            local add = WC_LIMP / 60
            pcall(function() part:setFractureTime(fracture + add) end)
        end
    elseif rec and rec.badSet then
        rec.badSet = nil
    end
    -- the legs' minute of strain on stitches and open deep wounds
    if moved == "sprint" or moved == "run" then
        local k = moved == "sprint" and 1 or 1 / 3
        if LEGS[name] then strain(player, part, WC_TEAR_SPRINT * k, WC_REOPEN_SPRINT * k)
        elseif TORSO[name] then strain(player, part, WC_TEAR_SPRINT * k * WC_TORSO, WC_REOPEN_SPRINT * k * WC_TORSO) end
    end
    if rec and not rec.deep and not rec.badSet then d.wcParts[name] = nil end
end

local function updateWoundMinute(player, d)
    if not sandboxOn() then return end
    d = wcData(player)
    d.wcLife = d.wcLife or {}
    local wet = wetness(player)
    local summary = {}
    pcall(function()
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            updatePart(player, d, part, tostring(part:getType()), wet, summary)
        end
    end)
    d.wcSummary = table.concat(summary, ", ")
    d.wcMoved = moved or nil
    moved = false
end
DanTraits_updateWoundMinute = updateWoundMinute

-- a swing: strain on the arm(s) doing it, and a little on the torso
local function onSwing(character, weapon)
    if not sandboxOn() then return end
    local player = getSpecificPlayer(0)
    if not player or character ~= player then return end
    local twoHanded = false
    pcall(function() twoHanded = weapon and weapon:isTwoHandWeapon() end)
    local k = twoHanded and WC_TWO_HANDED or 1
    pcall(function()
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            local name = tostring(part:getType())
            if ARMS_R[name] or (twoHanded and ARMS_L[name]) then
                strain(player, part, WC_TEAR_SWING * k, WC_REOPEN_SWING * k)
            elseif TORSO[name] then
                strain(player, part, WC_TEAR_SWING * k * WC_TORSO, WC_REOPEN_SWING * k * WC_TORSO)
            end
        end
    end)
end
DanTraits_WoundOnSwing = onSwing

-- the splint action: roll the set once it is on
local function wrapSplint()
    DanTraits_Wrap(ISSplint, "complete", "woundcare-splint-set", function(original, self, ...)
        local result = original(self, ...)
        pcall(function()
            if self.doIt and self.bodyPart and self.bodyPart:isSplint() then
                DanTraits_OnSplintSet(self.otherPlayer or self.character, self.bodyPart, self.doctorLevel or 0)
            end
        end)
        return result
    end)
end
wrapSplint()
Events.OnGameStart.Add(wrapSplint)

-- console: tear <part> | dressing <part> <life> | badset <part> | breakbone <part> [time]
local partOf = DanTraits_PartOf
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.tear = function(player, args)
    local part = partOf(player, args[1])
    if not part then return "tear <part>" end
    tearOpen(player, part)
    return "tore " .. tostring(part:getType())
end
DanTraits_ExtraCommands.dressing = function(player, args)
    local part = partOf(player, args[1])
    if not part then return "dressing <part> <life>" end
    pcall(function() part:setBandageLife(tonumber(args[2]) or 0) end)
    local d = wcData(player)
    d.wcLife = d.wcLife or {}
    d.wcLife[tostring(part:getType())] = num(part, "getBandageLife")
    return "bandage life " .. tostring(num(part, "getBandageLife"))
end
DanTraits_ExtraCommands.breakbone = function(player, args)
    local part = partOf(player, args[1])
    if not part then return "breakbone <part>" end
    pcall(function() part:setFractureTime(tonumber(args[2]) or 50) end)
    return "broke " .. tostring(part:getType()) .. ", fracture time " .. tostring(num(part, "getFractureTime"))
end
DanTraits_ExtraCommands.firstaid = function(player, args)
    local level = tonumber(args[1])
    if not level then return "firstaid <level 0..10>" end
    pcall(function() player:setPerkLevelDebug(Perks.Doctor, math.max(0, math.min(10, math.floor(level)))) end)
    local now = -1
    pcall(function() now = player:getPerkLevel(Perks.Doctor) end)
    return "first aid " .. tostring(now)
end
DanTraits_ExtraCommands.badset = function(player, args)
    local part = partOf(player, args[1])
    if not part then return "badset <part>" end
    local d = wcData(player)
    recOf(d, tostring(part:getType())).badSet = true
    pcall(function() part:setSplintFactor(part:getSplintFactor() * WC_BADSET_FACTOR) end)
    return "badly set " .. tostring(part:getType())
end

DanTraits_Every("minute", "WoundCare", updateWoundMinute, 22)
DanTraits_Every("frame", "WoundCare", function(player)
    if sandboxOn() then updateWoundFrame(player) end
end, 22)
Events.OnWeaponSwing.Add(onSwing)
