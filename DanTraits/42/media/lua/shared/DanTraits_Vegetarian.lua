-- Project Zomboid Vitality Project: Vegetarian.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local foodTags = DanTraits_FoodTags

-- Vegetarian ------------------------------------------------------------------
-- Meat, poultry, fish, seafood, insects and pet food are refused outright:
-- the Eat option is greyed out with a reason, and the eat action itself will
-- not start or finish on them (so hotbar and other mods' shortcuts are
-- covered too). Eggs and dairy are fine. Detection is the meat tag of
-- DanTraits_Food.lua: the item's FoodType first, then its name, then the
-- ingredients of an evolved dish (a stew with a steak in it is not vegetarian).
function DanTraits_IsMeat(item)
    if not item then return false end
    return foodTags(item).meat == true
end

-- why this character will not eat this item (a text key), or nil when they
-- will: Vegetarian's meat here, and any other file through the "refuseFood"
-- hook (value nil, player, item; return a text key to refuse). Straight Edge
-- refuses alcohol and tobacco that way. The notice is the key; the eat
-- option's grey-out tooltip is the same key with "Tooltip_" for "UI_".
function DanTraits_RefuseReason(player, item)
    if not item then return nil end
    if hasTrait(player, "vegetarian") and DanTraits_IsMeat(item) then return "UI_DanTraits_VegetarianRefuse" end
    return DanTraits_RunHooks("refuseFood", nil, player, item)
end

-- true when this character will not eat this item
function DanTraits_RefusesFood(player, item)
    return DanTraits_RefuseReason(player, item) ~= nil
end
