-- Project Zomboid Vitality Project: the reload crash in the game's own script.
--
-- ISReloadWeaponAction.setReloadSpeed (every reload, rack and magazine action
-- calls it) checks for an ammo strap by name without checking that one is
-- worn. Wearing anything tagged for quick reloads (a chest rig, an ALICE belt
-- or a shoulder holster: reloadfastmagazines) with no strap, a shotgun or a
-- gun with no magazine (or a melee weapon in hand, loading a magazine) ends in
-- strap:getClothingItemName() on nil. The action never gets its ammo count
-- either, so its update() errors every frame until it is cancelled and the gun
-- is never loaded.
--
-- On exactly that path the strap's x1.15 cannot apply (no strap, and no tag for
-- this ammo), so the speed is the rest of the game's sum; everything else goes
-- to the game's function untouched. This is the innermost wrap: Steady Hands
-- and Essential Tremor require this file first, so theirs go around it and
-- still apply.
require "TimedActions/ISReloadWeaponAction"
require "DanTraits"

-- the game's function would index a missing strap: its own conditions, in order
local function strapCrash(character)
    if character:getWornItem(ItemBodyLocation.AMMO_STRAP) then return false end
    local gun = character:getPrimaryHandItem()
    if not gun then return false end
    local function equipped(tag) return character:hasEquippedTag(tag) end
    local function worn(tag) return character:hasWornTag(tag) end
    if not (equipped(ItemTag.RELOAD_FAST_SHELLS) or equipped(ItemTag.RELOAD_FAST_BULLETS)
            or equipped(ItemTag.RELOAD_FAST_MAGAZINES) or worn(ItemTag.RELOAD_FAST_MAGAZINES)) then
        return false
    end
    if gun:getAmmoType() == AmmoType.SHOTGUN_SHELLS then
        return not (equipped(ItemTag.RELOAD_FAST_SHELLS) or worn(ItemTag.RELOAD_FAST_SHELLS))
    end
    if gun:getMagazineType() then return false end
    return not (equipped(ItemTag.RELOAD_FAST_BULLETS) or worn(ItemTag.RELOAD_FAST_BULLETS))
end

-- the game's sum with no strap bonus
local function plainSpeed(character, rack)
    local level = character:getPerkLevel(Perks.Reloading)
    local speed = 0.8
    if rack then
        speed = speed + level * 0.04
    else
        speed = speed + level * 0.10 - character:getMoodles():getMoodleLevel(MoodleType.PANIC) * 0.05
    end
    local vehicle = character:getVehicle()
    if vehicle and vehicle:getDriver() == character then speed = speed * 0.8 end
    character:setVariable("ReloadSpeed", speed)
end

DanTraits_Wrap(ISReloadWeaponAction, "setReloadSpeed", "strap-guard", function(original, character, rack)
    if strapCrash(character) then return plainSpeed(character, rack) end
    return original(character, rack)
end)
