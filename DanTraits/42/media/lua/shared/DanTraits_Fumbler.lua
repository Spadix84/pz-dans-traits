-- Project Zomboid Vitality Project: Fumbler.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify

-- Fumbler -------------------------------------------------------------------
-- A steady hand drops one swing in a hundred; a shaking, hurting, exhausted
-- one drops far more.
local FUMBLE_BASE       = 1     -- percent per weapon swing, calm and rested
local FUMBLE_PANIC      = 6     -- added at full panic
local FUMBLE_PAIN       = 6     -- added at full pain
local FUMBLE_FATIGUE    = 5     -- added at full fatigue

local function fumbleChance(player)
    local chance = FUMBLE_BASE
    pcall(function()
        local stats = player:getStats()
        chance = chance
            + (stats:get(CharacterStat.PANIC) or 0) / 100 * FUMBLE_PANIC
            + (stats:get(CharacterStat.PAIN) or 0) / 100 * FUMBLE_PAIN
            + (stats:get(CharacterStat.FATIGUE) or 0) * FUMBLE_FATIGUE
    end)
    return chance
end
DanTraits_FumbleChance = fumbleChance

-- Other traits (low blood sugar) add shakiness on top, Fumbler or not.
function DanTraits_SwingDropChance(player)
    local chance = hasTrait(player, "fumbler") and fumbleChance(player) or 0
    if DanTraits_ExtraFumble then
        local ok, extra = pcall(DanTraits_ExtraFumble, player)
        if ok and extra then chance = chance + extra end
    end
    return chance
end

-- drop whatever is in the primary hand at the character's feet; true if something dropped
local function dropWeapon(player)
    local item = player:getPrimaryHandItem()
    local square = player:getCurrentSquare()
    if not item or not square then return false end

    player:removeFromHands(item)
    player:getInventory():Remove(item)
    square:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
    notify(player, "UI_DanTraits_FumblerDrop")
    return true
end
DanTraits_FumbleDrop = dropWeapon

local function onWeaponSwing(player, weapon)
    if not weapon then return end
    local chance = DanTraits_SwingDropChance(player)
    if chance <= 0 then return end
    if ZombRand(1000) >= chance * 10 then return end
    dropWeapon(player)
end

Events.OnWeaponSwing.Add(onWeaponSwing)
