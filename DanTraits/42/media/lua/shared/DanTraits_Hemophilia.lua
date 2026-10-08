-- Project Zomboid Vitality Project: Hemophilia.
-- Blood does not clot. A bleeding body part keeps bleeding until it is
-- bandaged: the game's own clock, which normally runs the bleed down, is
-- held where it is every minute the part is uncovered. A bandage runs the
-- clock down as it always did, and what it gains is kept: the clock is
-- remembered under the dressing, so a change of bandage picks up where the
-- old one left off instead of starting the bleed over. Any open wound that is
-- not bandaged or stitched, and whose clock has not been run to nothing,
-- starts bleeding again. With the blood system on (DanTraits_Blood.lua) the
-- blood goes faster: half as fast again open, and a bandage only slows it to
-- a quarter instead of a tenth; a soaked one, or one over a shard, is never
-- worse than anyone else's open wound, so only stitches really stop a deep
-- wound and only time under a bandage stops a scratch. With the blood system
-- off, every unbandaged bleed costs extra health instead. A scratch is a
-- bandage, kept on, or a slow death; a bite is what it always was.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify

local HEMO_REOPEN_TIME  = 5.0     -- bleeding time an open wound starts bleeding again at, when nothing is remembered
local HEMO_DAMAGE       = 0.35    -- health per minute per unbandaged bleeding part, on top of vanilla
local HEMO_HEALTH_FLOOR = 0       -- it will kill you
local HEMO_BLOOD_OPEN   = 1.5     -- blood system: x blood lost from an open bleed
local HEMO_BLOOD_BANDAGED = 2.5   -- blood system: x blood lost under a bandage (a tenth becomes a quarter)
local HEMO_BLOOD_SOAKED_CAP = 1.0 -- blood system: a bandage never leaks more than this x the plain open rate

local function bloodOn() return DanTraits_BloodActive and DanTraits_BloodActive() end

-- A bandage leaks two and a half times as much, but never more than anyone
-- else's open wound: a soaked one (x0.5 normally) would otherwise come out
-- at x1.25, so change a soaked bandage, and a bandage over a shard (x0.35,
-- x0.875 here) stays under the cap.
DanTraits_AddHook("bloodBleed", function(rate, player, _, bandaged, open)
    if not hasTrait(player, "hemophilia") then return nil end
    if not bandaged then return rate * HEMO_BLOOD_OPEN end
    local leaked = rate * HEMO_BLOOD_BANDAGED
    if open then leaked = math.min(leaked, open * HEMO_BLOOD_SOAKED_CAP) end
    return leaked
end)

local partIs = DanTraits_PartIs

local function partKey(part, i)
    local key = nil
    pcall(function() key = tostring(part:getType()) end)
    return key or tostring(i)
end

-- The clock, held and remembered (d.hemoClock[part] = the bleeding time
-- last seen). Uncovered and bleeding: never lower than remembered (the game
-- would run it down; it does not clot), and remembered follows it up (a new
-- wound on the same part). Covered: the dressing runs it down and the memory
-- follows, so taking the dressing off keeps the gain. Not bleeding, uncovered,
-- wounded and not stitched: it opens again at the remembered time, or at
-- HEMO_REOPEN_TIME if nothing is remembered; a clock a bandage ran to nothing
-- stays at nothing, and the wound is as closed as it gets. Healed: forgotten.
local function updateHemophiliaMinute(player, d)
    if not hasTrait(player, "hemophilia") then return end
    local bd = player:getBodyDamage()
    local open, reopened = 0, 0
    d.hemoClock = d.hemoClock or {}
    local clock = d.hemoClock
    pcall(function()
        local parts = bd:getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            local key = partKey(part, i)
            local covered = partIs(part, "bandaged") or partIs(part, "IsBleedingStemmed")
            local wounded = partIs(part, "scratched") or partIs(part, "isCut") or partIs(part, "deepWounded")
            local t = 0
            pcall(function() t = tonumber(part:getBleedingTime()) or 0 end)
            if covered then
                if wounded or t > 0 then clock[key] = t else clock[key] = nil end
            elseif partIs(part, "bleeding") or t > 0 then
                local held = clock[key]
                if held and t < held then
                    t = held
                    pcall(function() part:setBleedingTime(t) end)
                else
                    clock[key] = t
                end
                if t > 0 then open = open + 1 end
            elseif wounded and not partIs(part, "stitched") then
                local held = clock[key]
                if held == nil or held > 0 then
                    t = held or HEMO_REOPEN_TIME
                    pcall(function() part:setBleeding(true) end)
                    pcall(function() part:setBleedingTime(t) end)
                    clock[key] = t
                    reopened = reopened + 1
                    open = open + 1
                end
            elseif not wounded then
                clock[key] = nil
            end
        end
    end)
    d.hemoOpen = open
    if reopened > 0 and not d.hemoWarned then
        d.hemoWarned = true
        notify(player, "UI_DanTraits_HemoBleeding")
    end
    if open == 0 then d.hemoWarned = false return end
    if bloodOn() then return end
    pcall(function()
        local health = bd:getOverallBodyHealth() or 100
        local loss = math.min(HEMO_DAMAGE * open, math.max(0, health - HEMO_HEALTH_FLOOR))
        if loss > 0 then bd:ReduceGeneralHealth(loss) end
    end)
end

DanTraits_Every("minute", "Hemophilia", updateHemophiliaMinute, 21)
