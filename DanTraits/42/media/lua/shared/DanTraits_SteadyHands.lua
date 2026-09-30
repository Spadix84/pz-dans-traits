-- Project Zomboid Vitality Project: Steady Hands.
--
-- Vanilla Dexterous folded in (granted with it, like Deep Sleeper's Wakeful:
-- faster inventory transfers), plus a surgeon's hands for the wound care
-- overhaul (DanTraits_WoundCare.lua):
--   splints you set go wrong half as often (the splintBadSet hook, read for
--     whoever sets it, patient or not)
--   your fresh stitches tear half as often under strain (the stitchTear hook)
--   stitching, pulling out glass or a bullet, and splinting take a quarter
--     less time
-- Hands that shake are not steady: while alcohol withdrawal has the shakes on
-- (DanTraits_Dependent.lua) or a diabetic low does (DanTraits_Diabetes.lua),
-- the work done then gets none of it (the splint and the speed; stitches
-- already in hold as well as they were sewn).
-- Not with Dexterous (it is already in here) or All Thumbs.
require "DanTraits"

local hasTrait = DanTraits_HasTrait

local SH_BADSET        = 0.5     -- bad-set chance x this
local SH_TEAR          = 0.5     -- stitch tear chance x this
local SH_FAST          = 0.75    -- first aid time x this
local SH_FAST_ACTIONS  = { "ISStitch", "ISRemoveGlass", "ISRemoveBullet" }

local function has(player) return player ~= nil and hasTrait(player, "steadyhands") end

-- whether something has this character's hands shaking now
local function shaking(player)
    local shakes = false
    pcall(function()
        local d = player:getModData().DanTraits
        if d and (d.alcShakes or 0) > 0 then shakes = true end
    end)
    if not shakes and DanTraits_DiaLow then
        local ok, low = pcall(DanTraits_DiaLow, player)
        shakes = ok and (tonumber(low) or 0) > 0
    end
    return shakes
end

-- steady now: the trait, and nothing shaking the hands
local function steady(player) return has(player) and not shaking(player) end

DanTraits_AddHook("splintBadSet", function(chance, setter)
    if not steady(setter) then return nil end
    return chance * SH_BADSET
end)

DanTraits_AddHook("stitchTear", function(chance, player)
    if not has(player) then return nil end
    return chance * SH_TEAR
end)

local function actionClass(name)
    local classes = { ISStitch = ISStitch, ISRemoveGlass = ISRemoveGlass, ISRemoveBullet = ISRemoveBullet }
    return classes[name]
end

local function wrapSteady()
    for _, name in ipairs(SH_FAST_ACTIONS) do
        DanTraits_Wrap(actionClass(name), "getDuration", "steady-fast", function(original, self, ...)
            local t = original(self, ...)
            if type(t) == "number" and t > 1 and steady(self.character) then t = t * SH_FAST end
            return t
        end)
    end
    -- the splint sets its time in new(), not getDuration()
    DanTraits_Wrap(ISSplint, "new", "steady-splint-fast", function(original, self, character, ...)
        local o = original(self, character, ...)
        pcall(function() if o.maxTime and o.maxTime > 1 and steady(character) then o.maxTime = o.maxTime * SH_FAST end end)
        return o
    end)
end
wrapSteady()
Events.OnGameStart.Add(wrapSteady)

local function grant(player) DanTraits_GrantFoldIn(player, "steadyhands", "DEXTROUS", "shDexGranted") end

Events.OnCreatePlayer.Add(function(playerNum, player) grant(player) end)
Events.OnGameStart.Add(function() grant(getSpecificPlayer(0)) end)
