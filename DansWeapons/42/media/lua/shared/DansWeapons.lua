-- Dan's Weapons: the little code the weapons need. The items, models and recipes are
-- scripts (media/scripts/DansWeapons_*.txt); this is what they name:
--
--   OnBreak.<weapon>        each item's OnBreak: what is left when it breaks
--   DansWeapons.dismantle   the reclaim recipes' OnCreate: each part's wear
--
-- Both run wherever the game runs them (the server in multiplayer), so this is shared.

DansWeapons = DansWeapons or {}

-- the game's own table of break handlers (media/lua/shared/Items/OnBreak.lua); whichever
-- file loads first makes it
OnBreak = OnBreak or {}

-- What each weapon is made of, for breaking and for taking apart:
--   head       what did the hitting; it comes back with the head's condition (or, for a
--              thing with no condition of its own like the padlock, as it was: whole = true)
--   shaft      what a reclaim recipe gives back for the handle, with the shaft's condition
--   broken     what is left in the hands when it breaks, and brokenDead: with no condition
--              left (the game's way for a knife's or an axe's handle) rather than a random one
--   splinters  wood on the ground when it breaks
--   scatter    more bits on the ground: { type, how many }
DansWeapons.PARTS = {
    ["Base.HockeyStickCleaver"] = { head = "Base.MeatCleaver", shaft = "Base.IceHockeyStick",
                                    broken = "Base.LongStick_Broken", splinters = true },
    ["Base.BreadKnifeGlaive"]   = { head = "Base.BreadKnife", shaft = "Base.LongHandle",
                                    broken = "Base.LongHandle_Broken", splinters = true },
    -- the cutlery is bent past saving, bar a fork and a knife
    ["Base.CutleryMace"]        = { broken = "Base.Handle", brokenDead = true, splinters = true,
                                    scatter = { { "Base.Fork", 1 }, { "Base.ButterKnife", 1 } } },
    -- the sock tears and the padlock drops out
    ["Base.LockInASock"]        = { head = "Base.Padlock", whole = true,
                                    broken = "Base.RippedSheets", brokenDead = true },
    ["Base.SockFlail"]          = { head = "Base.Padlock", whole = true,
                                    broken = "Base.SmallHandle", brokenDead = true },
}

-- As the game's knife spears break: splinters on the ground, the head back (at the feet
-- of whatever was hit, not stuck in it), and what is left of the handle in the hands.
function DansWeapons.breakWeapon(item, player)
    if not item then return end
    local parts = DansWeapons.PARTS[item:getFullType()]
    if not parts then return end
    if parts.splinters then OnBreak.GroundHandler(item, player, "Base.Splinters") end
    if parts.scatter then
        for _, bit in ipairs(parts.scatter) do
            for _ = 1, bit[2] do OnBreak.GroundHandler(item, player, bit[1]) end
        end
    end
    if parts.head then
        OnBreak.HeadHandler(item, player, parts.head, false, nil, nil, parts.whole == true)
    end
    OnBreak.HandleHandler(item, player, parts.broken, parts.brokenDead == true)
end

function OnBreak.HockeyStickCleaver(item, player) DansWeapons.breakWeapon(item, player) end
function OnBreak.BreadKnifeGlaive(item, player) DansWeapons.breakWeapon(item, player) end
function OnBreak.CutleryMace(item, player) DansWeapons.breakWeapon(item, player) end
function OnBreak.LockInASock(item, player) DansWeapons.breakWeapon(item, player) end
function OnBreak.SockFlail(item, player) DansWeapons.breakWeapon(item, player) end

-- Taking one apart: the head gets the head's condition and edge, the shaft the shaft's.
-- The game's dismantleSpear does the same but only knows its long stick.
function DansWeapons.dismantle(craftRecipeData, character)
    local used = craftRecipeData:getAllConsumedItems()
    local weapon, parts = nil, nil
    for i = 0, used:size() - 1 do
        local it = used:get(i)
        local p = DansWeapons.PARTS[it:getFullType()]
        if p then weapon, parts = it, p end
    end
    if not weapon then return end
    local made = craftRecipeData:getAllCreatedItems()
    for i = 0, made:size() - 1 do
        local it = made:get(i)
        local kind = it:getFullType()
        if kind == parts.shaft then
            it:setConditionFrom(weapon)
        elseif kind == parts.head and not parts.whole then
            if weapon:hasHeadCondition() then
                it:setConditionFromHeadCondition(weapon)
            else
                it:setConditionFrom(weapon)
            end
            if it:hasSharpness() and weapon:hasSharpness() then it:setSharpnessFrom(weapon) end
        end
        it:copyBloodLevelFrom(weapon)
    end
end
