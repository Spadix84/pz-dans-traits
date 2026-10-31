-- Project Zomboid Vitality Project: Steady Hands.
--
-- Dexterous's quick hands, carried by the trait itself (the inventory
-- transfer, drop, pick-up and grab actions take half the time: the same
-- x0.5 vanilla's Lua gives Dexterous, applied through each action's
-- adjustMaxTime, which ISBaseTimedAction:create runs once; what the game's
-- Java reads Dexterous for is not copied), plus a surgeon's hands for the
-- wound care overhaul (DanTraits_WoundCare.lua):
--   splints you set go wrong half as often (the splintBadSet hook, read for
--     whoever sets it, patient or not)
--   stitches you put in come out rough half as often (the stitchPoor hook,
--     likewise for whoever stitches)
--   your fresh stitches tear half as often under strain (the stitchTear hook)
--   stitching, pulling out glass or a bullet, and splinting take a quarter
--     less time
--   a gun hand: reloading and racking run a quarter faster (the game's
--     ReloadSpeed variable, set by ISReloadWeaponAction.setReloadSpeed for
--     every reload action and read by the reload animations as their speed;
--     an ammo strap's x1.15 stacks), and a weapon goes to and from the belt a
--     quarter faster (the hotbar's AttachItemSpeed, the animSpeed each hotbar
--     action computes in new() from adjustMaxTime; equipping from the
--     inventory is untouched)
-- Hands that shake are not steady: while alcohol withdrawal has the shakes on
-- (DanTraits_Dependent.lua) or a diabetic low does (DanTraits_Diabetes.lua),
-- the work done then gets none of it (the splint and the speed; stitches
-- already in hold as well as they were sewn).
-- Not with Dexterous (the same effect) or All Thumbs. A character the old
-- version granted Dexterous to has it taken off once (DanTraits_UngrantFoldIn).
require "DanTraits"

local hasTrait = DanTraits_HasTrait

local SH_BADSET        = 0.5     -- bad-set and rough-stitch chance x this
local SH_TEAR          = 0.5     -- stitch tear chance x this
local SH_FAST          = 0.75    -- first aid time x this
local SH_FAST_ACTIONS  = { "ISStitch", "ISRemoveGlass", "ISRemoveBullet" }
local SH_RELOAD        = 1.25    -- ReloadSpeed x this (reloading and racking)
local SH_HOLSTER       = 1.25    -- hotbar draw and holster speed x this
local SH_HOLSTER_ACTIONS = { "ISEquipWeaponAction", "ISUnequipAction", "ISAttachItemHotbar", "ISDetachItemHotbar" }
local SH_TRANSFER      = 0.5     -- transfers, drops, pick-ups and grabs take x this (vanilla Dexterous's x0.5)
-- the actions vanilla's Lua halves for Dexterous; the grab is client-only
local SH_TRANSFER_ACTIONS = { "ISInventoryTransferAction", "ISDropWorldItemAction", "ISDropVehicleItemAction",
                              "ISPickUpGroundCoverItem", "ISGrabItemAction" }

local function has(player) return player ~= nil and hasTrait(player, "steadyhands") end

-- whether something has this character's hands shaking now
local function shaking(player)
    local shakes = false
    pcall(function()
        local d = player:getModData().DanTraits
        if d and (d.alcShakes or 0) > 0 then shakes = true end
    end)
    if not shakes then shakes = DanTraits_Strength("DanTraits_DiaLow", player) > 0 end   -- a diabetic low, 0 without Diabetes
    return shakes
end

-- steady now: the trait, and nothing shaking the hands
local function steady(player) return has(player) and not shaking(player) end

DanTraits_AddHook("splintBadSet", function(chance, setter)
    if not steady(setter) then return nil end
    return chance * SH_BADSET
end)

DanTraits_AddHook("stitchPoor", function(chance, setter)
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

-- quicker to do (getDuration on each, and the splint's own time)
local function wrapSteady()
    local fast = {}
    for _, name in ipairs(SH_FAST_ACTIONS) do fast[#fast + 1] = actionClass(name) end
    DanTraits_ScaleActionTime(fast, "steady-fast", steady, SH_FAST)
end
wrapSteady()
Events.OnGameStart.Add(wrapSteady)

-- quicker with a gun: the reload speed the game works out for every reload
-- and rack, raised after it is set
local function wrapReload()
    DanTraits_Wrap(ISReloadWeaponAction, "setReloadSpeed", "steady-reload", function(original, character, ...)
        local result = original(character, ...)
        if steady(character) then
            pcall(function()
                local speed = character:getVariableFloat("ReloadSpeed", 1.0)
                if type(speed) == "number" and speed > 0 then character:setVariable("ReloadSpeed", speed * SH_RELOAD) end
            end)
        end
        return result
    end)
end

-- quicker to the belt and back: each hotbar action's new() works out its
-- animation speed as maxTime / adjustMaxTime(maxTime), and create() takes
-- adjustMaxTime(maxTime) as its time, so a shorter adjustMaxTime from the
-- hotbar does both (new() itself is never wrapped: see DanTraits_Wrap).
-- ISDetachItemHotbar is client-only, so it is only there to wrap once the
-- game has started
local function wrapHolster()
    for _, name in ipairs(SH_HOLSTER_ACTIONS) do
        DanTraits_Wrap(_G[name], "adjustMaxTime", "steady-holster", function(original, self, ...)
            local t = original(self, ...)
            if type(t) == "number" and t > 1 and self.fromHotbar and steady(self.character) then t = t / SH_HOLSTER end
            return t
        end)
    end
end

-- quick hands: the time each action settles on (adjustMaxTime, run once by
-- ISBaseTimedAction:create) halved; a character with vanilla Dexterous too
-- (another mod's doing: the two exclude each other here) is not halved twice
local function wrapTransfers()
    for _, name in ipairs(SH_TRANSFER_ACTIONS) do
        DanTraits_Wrap(_G[name], "adjustMaxTime", "steady-transfer", function(original, self, ...)
            local t = original(self, ...)
            if type(t) == "number" and t > 1 and steady(self.character)
                and not DanTraits_HasVanillaTrait(self.character, "base:dextrous") then
                t = t * SH_TRANSFER
            end
            return t
        end)
    end
end

-- the rest of a drag: the inventory pane queues one transfer action per item and
-- ISInventoryTransferAction:checkQueueList merges the others into the first's
-- queueList, each with the time its own new() computed; the reset for each next
-- item takes that time straight, never through adjustMaxTime. Each merged entry
-- is halved once, as it is merged (a flag on the entry; the entry in hand has
-- already been through create)
local function scaleQueue(self)
    local list = self and self.queueList
    if type(list) ~= "table" or not steady(self.character)
        or DanTraits_HasVanillaTrait(self.character, "base:dextrous") then return end
    for _, q in ipairs(list) do
        if type(q) == "table" and not q.danSteady then
            q.danSteady = true
            if type(q.time) == "number" and q.time > 1 then q.time = q.time * SH_TRANSFER end
        end
    end
end

local function wrapQueue()
    DanTraits_Wrap(ISInventoryTransferAction, "checkQueueList", "steady-queue", function(original, self, ...)
        local r = original(self, ...)
        pcall(scaleQueue, self)
        return r
    end)
end
DanTraits_SteadyScaleQueue = scaleQueue   -- tests

wrapReload()
wrapHolster()
wrapTransfers()
wrapQueue()
Events.OnGameStart.Add(function() wrapReload(); wrapHolster(); wrapTransfers(); wrapQueue() end)

-- the Dexterous the old version granted comes off, once
local function ungrant(player) DanTraits_UngrantFoldIn(player, "DEXTROUS", "shDexGranted") end

DanTraits_OnPlayerReady("SteadyHands", ungrant, 75)
