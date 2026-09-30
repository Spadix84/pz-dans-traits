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
-- Not with Dexterous (it is already in here) or All Thumbs.
require "DanTraits"

local hasTrait = DanTraits_HasTrait

local SH_BADSET        = 0.5     -- bad-set chance x this
local SH_TEAR          = 0.5     -- stitch tear chance x this
local SH_FAST          = 0.75    -- first aid time x this
local SH_FAST_ACTIONS  = { "ISStitch", "ISRemoveGlass", "ISRemoveBullet" }

local function steady(player) return player ~= nil and hasTrait(player, "steadyhands") end

DanTraits_AddHook("splintBadSet", function(chance, setter)
    if not steady(setter) then return nil end
    return chance * SH_BADSET
end)

DanTraits_AddHook("stitchTear", function(chance, player)
    if not steady(player) then return nil end
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
DanTraits_GrantSteadyHands = grant

Events.OnCreatePlayer.Add(function(playerNum, player) grant(player) end)
Events.OnGameStart.Add(function() grant(getSpecificPlayer(0)) end)
