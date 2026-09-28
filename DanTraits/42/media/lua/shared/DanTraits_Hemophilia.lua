-- Project Zomboid Vitality Project: Hemophilia.
-- Blood does not clot. A bleeding body part keeps bleeding until it is
-- bandaged (the game's own clock, which normally runs the bleed down, is
-- held up every minute), and any open wound that is not bandaged or stitched
-- starts bleeding again. With the blood system on (DanTraits_Blood.lua) the
-- blood goes faster: half as fast again open, and a bandage only slows it to
-- two fifths instead of a tenth, so only stitches really stop it. With the
-- blood system off, every unbandaged bleed costs extra health instead. A
-- scratch is a bandage or a slow death; a bite is what it always was.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

local HEMO_BLEED_FLOOR  = 5.0     -- bleeding time is never allowed under this while unbandaged
local HEMO_DAMAGE       = 0.35    -- health per minute per unbandaged bleeding part, on top of vanilla
local HEMO_HEALTH_FLOOR = 0       -- it will kill you
local HEMO_BLOOD_OPEN   = 1.5     -- blood system: x blood lost from an open bleed
local HEMO_BLOOD_BANDAGED = 4     -- blood system: x blood lost under a bandage (a tenth becomes two fifths)

local function bloodOn() return DanTraits_BloodActive and DanTraits_BloodActive() end

DanTraits_AddHook("bloodBleed", function(rate, player, _, bandaged)
    if not hasTrait(player, "hemophilia") then return nil end
    return rate * (bandaged and HEMO_BLOOD_BANDAGED or HEMO_BLOOD_OPEN)
end)

local function partIs(part, method)
    local ok, res = pcall(function() return part[method](part) end)
    return ok and res == true
end

local function updateHemophiliaMinute(player, d)
    if not hasTrait(player, "hemophilia") then return end
    local bd = player:getBodyDamage()
    local open, reopened = 0, 0
    pcall(function()
        local parts = bd:getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            local covered = partIs(part, "bandaged") or partIs(part, "IsBleedingStemmed")
            if partIs(part, "bleeding") then
                if not covered then
                    open = open + 1
                    local t = 0
                    pcall(function() t = part:getBleedingTime() or 0 end)
                    if t < HEMO_BLEED_FLOOR then pcall(function() part:setBleedingTime(HEMO_BLEED_FLOOR) end) end
                end
            elseif not covered and not partIs(part, "stitched")
                and (partIs(part, "scratched") or partIs(part, "isCut") or partIs(part, "deepWounded")) then
                pcall(function() part:setBleeding(true) end)
                pcall(function() part:setBleedingTime(HEMO_BLEED_FLOOR) end)
                reopened = reopened + 1
                open = open + 1
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
DanTraits_updateHemophiliaMinute = updateHemophiliaMinute

local function onHemophiliaMinute()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    updateHemophiliaMinute(player, traitData(player))
end

Events.EveryOneMinute.Add(onHemophiliaMinute)
