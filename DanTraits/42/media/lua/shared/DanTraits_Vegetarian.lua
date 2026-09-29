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

-- true when this character will not eat this item
function DanTraits_RefusesFood(player, item)
    return hasTrait(player, "vegetarian") and DanTraits_IsMeat(item)
end
