-- Vitality Challenges: what a challenge dresses and packs a character with.
-- Every call is guarded on its own, like the scene's.
--
--   VC.profession(player)       "base:carpenter" (lowercase), or ""
--   VC.hasTrait(player, id)     a vanilla id ("base:brawler"); a bare key ("renfaire")
--                               asks the Vitality Project, false without it
--   VC.undress(player)          every worn and held item off and gone
--   VC.wear(player, type, opts) put on a new garment or bag; opts.condition 0..1 of
--                               its max, opts.dirt { lo, hi } per covered part 0..1,
--                               opts.hole a BloodBodyPartType name for the hole
--   VC.put(container, entry)    entry is a type or { type, count, uses, condition, water };
--                               returns the last item made
--   VC.condition(item, f)       f of the item's max condition
--   VC.used(item, range)        a weapon from home: condition somewhere in range (VC.USED)
--   VC.uses(item, n)            a drainable down to n uses
--   VC.levels(player, perk, n)  n levels up (not past 10), XP at the new level
--   VC.hold(player, item)       in the hands (both for a two-handed weapon)
--   VC.attach(player, item, only)  onto the first free hotbar slot that takes it, of the
--                               slot types in only ({ "Back" }) when given; false if none
--   VC.containerOf(item)        a bag's inventory
--   VC.worn(player, type)       the worn item of that full type, or nil
--   VC.weaponsFor(player)       the weapons a character brings from home: { main, belt,
--                               mainFull, beltFull, gifts, ankle } by profession and traits
--   VC.forged(level)            the best blade a Blacksmith level can make
--   VC.paperMap(mapId, bounds, stamps)  a paper map of its own: the LootMaps.Init for
--                               mapId, bounds { x1, y1, x2, y2 } in squares, each stamp
--                               { x, y, symbol, rgb } (a red "Circle" by default)
--   VC.stampMap(mapUI, id, x, y, rgb)  a mark on a paper map, from its LootMaps.Init

require "ISUI/Maps/ISMapDefinitions"

VitalityChallenges = VitalityChallenges or {}
local VC = VitalityChallenges

local MAX_LEVEL = 10
VC.USED = { 0.6, 0.8 }   -- a weapon from home: condition between these of its max

local function try(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

-- who --------------------------------------------------------------------------------

function VC.profession(player)
    return try(function() return string.lower(tostring(player:getDescriptor():getCharacterProfession())) end) or ""
end

function VC.hasTrait(player, id)
    if not string.find(id, ":", 1, true) then
        return DanTraits_HasTrait ~= nil and DanTraits_HasTrait(player, id) == true
    end
    local found = false
    pcall(function()
        local known = player:getCharacterTraits():getKnownTraits()
        for i = 0, known:size() - 1 do
            if string.lower(tostring(known:get(i))) == id then found = true end
        end
    end)
    return found
end

-- clothes ----------------------------------------------------------------------------

function VC.undress(player)
    local inv = player:getInventory()
    try(function() player:setPrimaryHandItem(nil) end)
    try(function() player:setSecondaryHandItem(nil) end)
    local worn = {}
    try(function()
        local list = player:getWornItems()
        for i = 0, list:size() - 1 do worn[#worn + 1] = list:getItemByIndex(i) end
    end)
    for _, item in ipairs(worn) do
        try(function() player:removeWornItem(item) end)
        try(function() inv:Remove(item) end)
    end
    try(function() player:clearWornItems() end)
end

function VC.condition(item, f)
    if not item then return end
    try(function() item:setCondition(math.max(1, math.floor(item:getConditionMax() * f + 0.5))) end)
end

function VC.used(item, range)
    range = range or VC.USED
    VC.condition(item, range[1] + (range[2] - range[1]) * ZombRandFloat(0, 1))
end

function VC.dirty(item, lo, hi)
    try(function()
        local covered = BloodClothingType.getCoveredParts(item:getBloodClothingType())
        for i = 0, covered:size() - 1 do
            item:setDirt(covered:get(i), lo + (hi - lo) * ZombRandFloat(0, 1))
        end
        BloodClothingType.calcTotalDirtLevel(item)
    end)
end

function VC.wear(player, fullType, opts)
    opts = opts or {}
    local item = try(function() return player:getInventory():AddItem(fullType) end)
    if not item then return nil end
    try(function()
        local where = item:canBeEquipped()
        if where == nil or where == "" then where = item:getBodyLocation() end
        player:setWornItem(where, item)
    end)
    if opts.condition then VC.condition(item, opts.condition) end
    if opts.dirt then VC.dirty(item, opts.dirt[1], opts.dirt[2]) end
    if opts.hole then try(function() player:addHole(BloodBodyPartType[opts.hole]) end) end
    return item
end

-- things -----------------------------------------------------------------------------

function VC.uses(item, n)
    if not item then return end
    try(function() item:setCurrentUses(math.min(n, item:getMaxUses())) end)
end

function VC.containerOf(item)
    return item and try(function() return item:getItemContainer() end) or nil
end

function VC.worn(player, fullType)
    return try(function()
        local list = player:getWornItems()
        for i = 0, list:size() - 1 do
            local item = list:getItemByIndex(i)
            if item and item:getFullType() == fullType then return item end
        end
        return nil
    end)
end

function VC.put(container, entry)
    if not container then return nil end
    local spec = type(entry) == "table" and entry or { entry }
    local last
    for _ = 1, spec.count or 1 do
        local item = try(function() return container:AddItem(spec[1]) end)
        if item then
            if spec.uses then VC.uses(item, spec.uses) end
            if spec.condition then VC.condition(item, spec.condition) end
            if spec.water then try(function() item:getFluidContainer():addFluid(Fluid.Water, spec.water) end) end
            last = item
        end
    end
    return last
end

-- a mark on a paper map, from its LootMaps.Init (each time the map is opened),
-- through the v3 API (the v1 API that sets the bounds has no symbols v2). It is
-- drawn as the player's own mark, once per map item: a map item's marks that
-- are not the player's are cleared when the game loads its default annotations,
-- so a game mark never shows. Being the player's, it is saved with the item
-- (and can be erased like any other mark).
VC.MAP_RED = { 0.65, 0.054, 0.054 }
function VC.stampMap(mapUI, symbolID, x, y, rgb)
    local item = mapUI.mapObj or mapUI.mapItem
    local md = item and try(function() return item:getModData() end)
    local key = "vcStamp:" .. symbolID .. ":" .. x .. "," .. y
    if md and md[key] then return true end
    local ok, err = pcall(function()
        local symbol = mapUI.javaObject:getAPIv3():getSymbolsAPIv2():addTexture(symbolID, x, y)
        symbol:setRGBA(rgb[1], rgb[2], rgb[3], 1.0)
        symbol:setAnchor(0.5, 0.5)
        symbol:setScale(ISMap.SCALE)
    end)
    if not ok then
        print("[VitalityChallenges] map stamp: " .. tostring(err))
        return false
    end
    if md then md[key] = true end
    if item then try(function() item:syncItemFields() end) end
    return true
end

-- a challenge's own paper map: the game calls LootMaps.Init[mapId] each time a map
-- item with that id is opened; this sets it up like the game's own maps (its tiles,
-- the default style, the bounds, the paper overlay) and stamps each mark
function VC.paperMap(mapId, bounds, stamps)
    LootMaps.Init[mapId] = function(mapUI)
        local mapAPI = mapUI.javaObject:getAPIv1()
        MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
        MapUtils.initDefaultStyleV3(mapUI)
        mapAPI:setBoundsInSquares(bounds[1], bounds[2], bounds[3], bounds[4])
        MapUtils.overlayPaper(mapUI)
        for _, s in ipairs(stamps or {}) do
            VC.stampMap(mapUI, s.symbol or "Circle", s.x, s.y, s.rgb or VC.MAP_RED)
        end
    end
end

-- arms ---------------------------------------------------------------------------

-- main / belt by profession; main goes on the back when the back slot takes it, else in the hands
local WEAPONS = {
    ["base:unemployed"]         = { "Base.BaseballBat", "Base.KitchenKnife" },
    ["base:fitnessinstructor"]  = { "Base.BaseballBat", "Base.KitchenKnife" },
    ["base:tailor"]             = { "Base.BaseballBat", "Base.Scissors" },
    ["base:burgerflipper"]      = { "Base.MeatCleaver", "Base.KitchenKnife" },
    ["base:chef"]               = { "Base.MeatCleaver", "Base.KitchenKnife" },
    ["base:burglar"]            = { "Base.Crowbar", "Base.Screwdriver" },
    ["base:carpenter"]          = { "Base.Hammer", "Base.Screwdriver" },
    ["base:constructionworker"] = { "Base.Shovel", "Base.Hammer" },
    ["base:doctor"]             = { "Base.BaseballBat", "Base.Scalpel" },
    ["base:nurse"]              = { "Base.BaseballBat", "Base.Scalpel" },
    ["base:electrician"]        = { "Base.PipeWrench", "Base.Screwdriver" },
    ["base:repairman"]          = { "Base.PipeWrench", "Base.Screwdriver" },
    ["base:engineer"]           = { "Base.PipeWrench", "Base.Screwdriver" },
    ["base:mechanics"]          = { "Base.TireIron", "Base.Wrench" },
    ["base:metalworker"]        = { "Base.Sword_Scrap", "Base.BallPeenHammer" },
    ["base:smither"]            = { "Base.CrudeSword", "Base.BallPeenHammer" },
    ["base:farmer"]             = { "Base.GardenFork", "Base.HandScythe" },
    ["base:rancher"]            = { "Base.GardenFork", "Base.HandScythe" },   -- the game has no pitchfork
    ["base:fisherman"]          = { "Base.SpearCrafted", "Base.HuntingKnife" },
    ["base:fireofficer"]        = { "Base.Axe", "Base.HandAxe" },
    ["base:lumberjack"]         = { "Base.WoodAxe", "Base.HandAxe" },
    ["base:parkranger"]         = { "Base.SpearCraftedFireHardened", "Base.HuntingKnife", mainFull = true },
    ["base:policeofficer"]      = { "Base.Nightstick", "Base.Pistol" },
    ["base:securityguard"]      = { "Base.Nightstick", "Base.KitchenKnife" },
    ["base:veteran"]            = { "Base.Machete", "Base.Pistol" },
}
local DEFAULT_WEAPONS = { "Base.BaseballBat", "Base.KitchenKnife" }   -- a modded profession

-- a trait's head start, every item vanilla and at full condition: belt (a better
-- belt weapon; into the bag when the belt holds a pistol), give (a spare in the
-- bag), forge (the best weapon the character's Blacksmith level can make, FORGED),
-- ankle (in an ankle holster, unloaded). Faire Geek is the Vitality Project's and
-- never matches without it.
local BOOSTS = {
    { trait = "base:brawler", give = "Base.BaseballBat_Spiked" },
    { trait = "base:baseballplayer", give = "Base.BaseballBat_Can" },
    { trait = "base:hunter", belt = "Base.HuntingKnife" },
    { trait = "base:handy", give = "Base.Hammer" },
    { trait = "base:wildernessknowledge", give = "Base.HandAxe" },   -- Bushcrafter
    { trait = "base:whittler", give = "Base.KnifePocket" },
    { trait = "base:blacksmith", forge = true },                     -- Blacksmith Knowledge
    { trait = "base:target_shooter", ankle = "Base.Revolver_Short" },
    { trait = "renfaire", give = "Base.CrudeShortSword" },           -- Vitality's Renaissance Faire Geek
}

-- what a smith can make at a starting Blacksmith level, best first: the forge
-- recipe's SkillRequired (recipes_blacksmith_blades.txt), each finished by an
-- assembly recipe that needs Maintenance 1 (the trait gives it)
local FORGED = {
    { 8, "Base.CrudeSword" },           -- Forge_Crude_Sword_Blade
    { 6, "Base.CrudeShortSword" },      -- Forge_Crude_Shortsword_Blade
    { 5, "Base.HuntingKnifeForged" },   -- Forge_Hunting_Knife_Blade
    { 4, "Base.HandAxeForged" },        -- Forge_Hand_Axe_Head
    { 3, "Base.LongCrudeKnife" },       -- Forge_Long_Crude_Blade
    { 1, "Base.SmallKnife" },           -- Forge_Small_Knife
    { 0, "Base.CrudeKnife" },           -- Forge_Crude_Blade
}

function VC.forged(level)
    for _, f in ipairs(FORGED) do
        if level >= f[1] then return f[2] end
    end
    return FORGED[#FORGED][2]
end

-- the profession's pair, after the traits: { main, belt, mainFull, beltFull, gifts, ankle }
function VC.weaponsFor(player)
    local row = WEAPONS[VC.profession(player)] or DEFAULT_WEAPONS
    local out = { main = row[1], belt = row[2], mainFull = row.mainFull == true, gifts = {} }
    for _, b in ipairs(BOOSTS) do
        if VC.hasTrait(player, b.trait) then
            if b.belt then
                if out.belt == "Base.Pistol" then out.gifts[#out.gifts + 1] = b.belt else out.belt, out.beltFull = b.belt, true end
            end
            if b.give then out.gifts[#out.gifts + 1] = b.give end
            if b.forge then
                local level = 0
                pcall(function() level = player:getPerkLevel(Perks.Blacksmith) end)
                out.gifts[#out.gifts + 1] = VC.forged(level)
            end
            if b.ankle then out.ankle = b.ankle end
        end
    end
    return out
end

VC.arms = { WEAPONS = WEAPONS, BOOSTS = BOOSTS, FORGED = FORGED }   -- tests

function VC.levels(player, perk, n)
    local added = 0
    pcall(function()
        for _ = 1, n do
            if player:getPerkLevel(perk) >= MAX_LEVEL then break end
            player:LevelPerk(perk)
            added = added + 1
        end
        if added > 0 then player:getXp():setXPToLevel(perk, player:getPerkLevel(perk)) end
    end)
    return added
end

function VC.hold(player, item)
    if not item then return end
    try(function()
        player:setPrimaryHandItem(item)
        if item:isTwoHandWeapon() then player:setSecondaryHandItem(item) end
    end)
end

-- the hotbar: the slots come from what is worn (a belt's two, a holster, the
-- big bag's bedroll strap; the back is always there), so this runs once the
-- character is dressed and the hotbar exists
function VC.attach(player, item, only)
    if not item then return false end
    local allowed
    if only then
        allowed = {}
        for _, t in ipairs(only) do allowed[t] = true end
    end
    local done = false
    pcall(function()
        local bar = getPlayerHotbar(player:getPlayerNum())
        if not bar then return end
        bar.needsRefresh = true
        bar.wornItems = nil
        bar:refresh()
        local kind = item:getAttachmentType()
        for i, slot in ipairs(bar.availableSlot) do
            local where = slot.def and slot.def.attachments and slot.def.attachments[kind]
            if where and not bar.attachedItems[i] and (not allowed or allowed[slot.slotType]) then
                if player:isHandItem(item) then player:removeFromHands(item) end
                bar:attachItem(item, where, i, slot.def, false)
                done = true
                break
            end
        end
        if done then bar:reloadIcons() end
    end)
    return done
end
