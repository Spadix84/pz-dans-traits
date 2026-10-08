-- Project Zomboid Vitality Project: Steady Hands.
--
-- Vanilla Dexterous folded in (granted with it, like Deep Sleeper's Wakeful:
-- faster inventory transfers), plus a surgeon's hands for the wound care
-- overhaul (DanTraits_WoundCare.lua):
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
--     action computes in new(); equipping from the inventory is untouched)
-- Hands that shake are not steady: while alcohol withdrawal has the shakes on
-- (DanTraits_Dependent.lua) or a diabetic low does (DanTraits_Diabetes.lua),
-- the work done then gets none of it (the splint and the speed; stitches
-- already in hold as well as they were sewn).
-- Not with Dexterous (it is already in here) or All Thumbs.
require "DanTraits"

local hasTrait = DanTraits_HasTrait

local SH_BADSET        = 0.5     -- bad-set and rough-stitch chance x this
local SH_TEAR          = 0.5     -- stitch tear chance x this
local SH_FAST          = 0.75    -- first aid time x this
local SH_FAST_ACTIONS  = { "ISStitch", "ISRemoveGlass", "ISRemoveBullet" }
local SH_RELOAD        = 1.25    -- ReloadSpeed x this (reloading and racking)
local SH_HOLSTER       = 1.25    -- hotbar draw and holster speed x this
local SH_HOLSTER_ACTIONS = { "ISEquipWeaponAction", "ISUnequipAction", "ISAttachItemHotbar", "ISDetachItemHotbar" }

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

-- quicker to the belt and back: each hotbar action sets its animation speed
-- (and sometimes its time) in new(); ISDetachItemHotbar is client-only, so
-- it is only there to wrap once the game has started
local function wrapHolster()
    for _, name in ipairs(SH_HOLSTER_ACTIONS) do
        DanTraits_Wrap(_G[name], "new", "steady-holster", function(original, self, character, ...)
            local o = original(self, character, ...)
            if type(o) == "table" and o.fromHotbar and steady(character) then
                if type(o.animSpeed) == "number" and o.animSpeed > 0 then o.animSpeed = o.animSpeed * SH_HOLSTER end
                if type(o.maxTime) == "number" and o.maxTime > 1 then o.maxTime = o.maxTime / SH_HOLSTER end
            end
            return o
        end)
    end
end

wrapReload()
wrapHolster()
Events.OnGameStart.Add(function() wrapReload(); wrapHolster() end)

local function grant(player) DanTraits_GrantFoldIn(player, "steadyhands", "DEXTROUS", "shDexGranted") end

Events.OnCreatePlayer.Add(function(playerNum, player) grant(player) end)
Events.OnGameStart.Add(function() grant(getSpecificPlayer(0)) end)
