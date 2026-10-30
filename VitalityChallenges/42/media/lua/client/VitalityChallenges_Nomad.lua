-- Nomad: a year after the outbreak, in a December blizzard, on a road in the far
-- south-west corner of the map (965, 14833). The goal is the top floor of the
-- Louisville tower, the floor Top of the World starts on (12785, 1527, floor
-- 26): about 17,800 tiles in a straight line, on foot. No car will start.
-- One life. CDDA's world settings (Insane population, power and water off, no
-- loot respawn, 1-hour days), its car settings left alone. Settle anywhere.
--
-- The kit: worn winter clothes (not fresh; fingerless gloves with a hole,
-- boots at a quarter), a big hiking bag with a tent and a sleeping bag on its
-- strap, a fanny pack, three days of food (FOOD below), a full canteen, a
-- camping first aid kit with a random few things, a flashlight, a full lighter
-- and a nearly empty bottle of fluid, two bars of soap, a tin opener, a
-- painkiller bottle with one left, and a paper map of the whole route with
-- the tower circled. A main weapon and a belt weapon by profession, some traits
-- better ones (VC.weaponsFor, in VitalityChallenges_Kit.lua). Foraging +2, First Aid +1, Lightfooted +1.
-- With the Vitality Project: its starting medication, one more of each daily
-- drug, antidepressants and iron pills for the two traits without a kit, all
-- in the fanny pack.
--
-- Three days of food, by the game's own numbers (Nutrition.updateCalories,
-- 42.x bytecode): per game second, walking burns 0.13 x 0.6 = 0.078 kcal
-- (281 an hour), jogging 0.13 (468), sprinting 0.169 (608), sleeping 0.003
-- (11, more in the cold), all x weight / 80. A day of 8 hours walking, 8 awake
-- and still and 8 asleep comes to about 2,800; three is 8,400. FOOD is 8,373.

require "VitalityChallenges_Core"
require "VitalityChallenges_Kit"
require "VitalityChallenges_Rules"
local VC = VitalityChallenges

local START_X, START_Y = 965, 14833
local TOWER_X, TOWER_Y, TOWER_TOP = 12785, 1527, 26
local TOWER_REACH = 30                      -- tiles either side of the tower's middle that count as the tower
local MAP_ID = "VC_NomadMap"
local MAP_BOUNDS = { 700, 1100, 13300, 15100 }   -- the paper map: start to tower with a margin

local CLOTHES_DIRT = { 0.2, 0.35 }          -- per covered part: worn for days, not filthy
local GLOVES_CONDITION = 0.45
local BOOTS_CONDITION = 0.25

local CLOTHES = {
    "Base.Tshirt_WhiteLongSleeve",
    "Base.Shirt_Lumberjack",
    "Base.Jumper_RoundNeck",
    "Base.Jacket_HuntingCamo",              -- a light jacket (0.45), not a padded one: you stay cold
    "Base.Trousers_Denim",
    "Base.Socks_Heavy",
    "Base.Hat_Beany",
    "Base.Belt2",                           -- the belt's two slots carry the belt weapon
}

-- kcal from the item scripts; tins open with the tin opener
local FOOD = {
    { "Base.PeanutButter" },                -- 2660
    { "Base.Chocolate" },                   --  850
    { "Base.BeefJerky", count = 2 },        --  820
    { "Base.GranolaBar", count = 3 },       --  810
    { "Base.SunflowerSeeds", count = 2 },   --  710
    { "Base.DriedApricots" },               --  241
    { "Base.Peanuts", count = 2 },          --  322
    { "Base.Crackers" },                    --   70
    { "Base.CannedCornedBeef" },            --  720
    { "Base.CannedBolognese" },             --  540
    { "Base.TunaTin" },                     --  370
    { "Base.CannedChili" },                 --  260   = 8373
}

local BAG = {
    { "Base.TentBlue_Packed" },
    { "Base.CanteenMilitaryFull" },
    { "Base.TinOpener" },
    { "Base.HandTorch" },                   -- its one battery inside, no spare
    { "Base.Soap2", count = 2 },
    { "Base.LighterFluid", uses = 2 },      -- 2 of 20: nearly empty
}

local FANNY = {
    { "Base.Lighter" },                     -- full
    { "Base.Pills", uses = 1 },             -- one painkiller left
}

local FIRST_AID_EXTRAS = { "Base.Disinfectant", "Base.AlcoholWipes", "Base.Tweezers", "Base.SutureNeedle", "Base.CottonBalls" }
local FIRST_AID_PICK = 3
local ANTIBIOTICS_IN = 5                    -- one kit in five has them

local SKILLS = { PlantScavenging = 2, Doctor = 1, Lightfoot = 1 }

-- with the Vitality Project: one more of each daily drug, and the two traits with no kit
local MED_EXTRA = {
    { trait = "heart", item = "Base.PillsBeta" },
    { trait = "epilepsy", item = "DanTraits.Anticonvulsants" },
    { trait = "diabetes1", item = "DanTraits.InsulinPen" },
    { trait = "diabetes2", item = "DanTraits.Metformin" },
    { trait = "ms", item = "DanTraits.Baclofen" },
    { trait = "spiraling", item = "Base.PillsAntiDep" },             -- Major Depressive Disorder: no kit of its own
    { trait = "anemia", item = "DanTraits.IronPills" },              -- Anaemic: no kit of its own
}
-- what goes in the fanny pack when the game or Vitality's kits leave it loose
local MEDS = {
    ["Base.Pills"] = true, ["Base.PillsBeta"] = true, ["Base.PillsAntiDep"] = true,
    ["DanTraits.Anticonvulsants"] = true, ["DanTraits.Metformin"] = true, ["DanTraits.Baclofen"] = true,
    ["DanTraits.Amantadine"] = true, ["DanTraits.Prednisone"] = true, ["DanTraits.IronPills"] = true,
    ["DanTraits.Sumatriptan"] = true, ["DanTraits.Nitroglycerin"] = true, ["DanTraits.Inhaler"] = true,
    ["DanTraits.InsulinPen"] = true,
}

local TAG = "vcNomad"   -- item mod data: "main", "belt" or "bedroll", for the hotbar on the first minute
-- the hotbar slots each may go on; a main weapon the back will not take stays in the hands
local SLOTS = {
    belt = { "SmallBeltLeft", "SmallBeltRight", "HolsterRight", "HolsterLeft" },
    ankle = { "HolsterAnkle" },
    main = { "Back" },
    bedroll = { "BedrollBottomBig" },
}

-- the map ------------------------------------------------------------------------------

VC.paperMap(MAP_ID, MAP_BOUNDS, { { x = TOWER_X, y = TOWER_Y } })   -- the tower circled

local function paperMap(container)
    local map = VC.put(container, "Base.Map")
    if not map then return end
    pcall(function()
        map:setMapID(MAP_ID)
        map:setName(getText("IGUI_VC_NomadMap"))
        map:setCustomName(true)
    end)
end

-- the kit ----------------------------------------------------------------------------

local function tag(item, slot) if item then item:getModData()[TAG] = slot end end

local function dress(player)
    VC.undress(player)
    for _, t in ipairs(CLOTHES) do VC.wear(player, t, { dirt = CLOTHES_DIRT }) end
    VC.wear(player, "Base.Shoes_HikingBoots", { dirt = CLOTHES_DIRT, condition = BOOTS_CONDITION })
    VC.wear(player, "Base.Gloves_FingerlessGloves", { dirt = CLOTHES_DIRT, condition = GLOVES_CONDITION,
        hole = ZombRand(2) == 0 and "Hand_L" or "Hand_R" })
end

local function firstAidKit(bag)
    local kit = VC.containerOf(VC.put(bag, "Base.FirstAidKit_Camping"))
    if not kit then return end
    VC.put(kit, { "Base.Bandage", count = 2 + ZombRand(3) })
    local pool = {}
    for i, t in ipairs(FIRST_AID_EXTRAS) do pool[i] = t end
    for _ = 1, math.min(FIRST_AID_PICK, #pool) do
        VC.put(kit, table.remove(pool, ZombRand(#pool) + 1))
    end
    if ZombRand(ANTIBIOTICS_IN) == 0 then VC.put(kit, "Base.Antibiotics") end
end

local function pack(player, bag, fanny)
    for _, entry in ipairs(FOOD) do VC.put(bag, entry) end
    for _, entry in ipairs(BAG) do VC.put(bag, entry) end
    for _, entry in ipairs(FANNY) do VC.put(fanny, entry) end
    firstAidKit(bag)
    paperMap(bag)
    -- loose in the inventory until the first minute straps it under the bag
    tag(VC.put(player:getInventory(), "Base.SleepingBag_Green_Packed"), "bedroll")
end

local function loadPistol(gun)
    pcall(function()
        gun:setContainsClip(true)
        gun:setCurrentAmmoCount(gun:getMaxAmmo())
    end)
end

local function arm(player, bag)
    local w = VC.weaponsFor(player)
    local inv = player:getInventory()
    local main = VC.put(inv, w.main)
    if w.mainFull then VC.condition(main, 1) else VC.used(main) end
    tag(main, "main")
    VC.hold(player, main)
    if w.belt == "Base.Pistol" then VC.wear(player, "Base.HolsterSimple") end
    local belt = VC.put(inv, w.belt)
    if w.belt == "Base.Pistol" then loadPistol(belt) elseif not w.beltFull then VC.used(belt) end
    tag(belt, "belt")
    for _, t in ipairs(w.gifts) do VC.put(bag, t) end
    if w.ankle then
        VC.wear(player, "Base.HolsterAnkle")
        local gun = VC.put(inv, w.ankle)
        pcall(function()
            gun:setCurrentAmmoCount(0)
            gun:setRoundChambered(false)
        end)
        tag(gun, "ankle")
    end
end

-- with Vitality: the extra bottles, then every loose med into the fanny pack (the bag when it is full)
local function meds(player)
    local inv = player:getInventory()
    if DanTraits_HasTrait then
        for _, m in ipairs(MED_EXTRA) do
            if DanTraits_HasTrait(player, m.trait) then VC.put(inv, m.item) end
        end
    end
    local fanny = VC.containerOf(VC.worn(player, "Base.Bag_FannyPackFront"))
    local bag = VC.containerOf(VC.worn(player, "Base.Bag_BigHikingBag"))
    local loose = {}
    pcall(function()
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if MEDS[item:getFullType()] then loose[#loose + 1] = item end
        end
    end)
    for _, item in ipairs(loose) do
        local into = fanny
        if not (into and into:hasRoomFor(player, item)) then into = bag end
        if into then
            pcall(function()
                inv:Remove(item)
                into:AddItem(item)
            end)
        end
    end
end

local function strapOn(player)
    local tagged = {}
    pcall(function()
        local items = player:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local slot = item:getModData()[TAG]
            if slot then tagged[slot] = item end
        end
    end)
    for _, slot in ipairs({ "belt", "ankle", "main", "bedroll" }) do
        local item = tagged[slot]
        if item then
            item:getModData()[TAG] = nil
            local ok = VC.attach(player, item, SLOTS[slot])
            if not ok and slot == "bedroll" then
                -- no strap: into the bag
                local bag = VC.containerOf(VC.worn(player, "Base.Bag_BigHikingBag"))
                if bag then pcall(function() player:getInventory():Remove(item); bag:AddItem(item) end) end
            end
        end
    end
end

-- the challenge ------------------------------------------------------------------------

VC.define({
    id = "VC_Nomad",
    mode = "Nomad",
    world = "Muldraugh, KY",
    x = START_X, y = START_Y, z = 0,
    -- the vanilla Top of the World art: it is the same tower
    image = "media/lua/client/Challenge/top_of_the_world.png",
    video = "top_of_the_world.bik",
    everyCharacter = false,
    noDriving = true,
    oneLife = true,
    goal = { x1 = TOWER_X - TOWER_REACH, y1 = TOWER_Y - TOWER_REACH,
             x2 = TOWER_X + TOWER_REACH, y2 = TOWER_Y + TOWER_REACH, z = TOWER_TOP },

    -- A Really CD DA's OnInitWorld, values as the game sets them
    sandbox = function()
        local t = {
            Zombies = 1, Distribution = 1, DayLength = 3, StartMonth = 12, StartTime = 2,
            WaterShutModifier = -1, ElecShutModifier = -1, LootItemRemovalList = "",
            Temperature = 3, Rain = 3, ErosionSpeed = 1, Farming = 3, NatureAbundance = 5,
            PlantResilience = 3, PlantAbundance = 3, Alarm = 3, LockedHouses = 3,
            FoodRotSpeed = 3, FridgeFactor = 3, LootRespawn = 1, StatsDecrease = 3,
            StarterKit = false, TimeSinceApo = 13, MultiHitZombies = false,
            MultiplierConfig = { XPMultiplierGlobal = 1, XPMultiplierGlobalToggle = true },
            ZombieConfig = { PopulationMultiplier = ZombiePopulationMultiplier and ZombiePopulationMultiplier.Insane or "2.5" },
        }
        -- Vitality's starting kits, whatever its sandbox page says
        if SandboxVars and SandboxVars.DanTraits then t.DanTraits = { StartingMedication = true } end
        return t
    end,

    start = { weather = { stage = "blizzard", hours = 12 } },

    player = function(player)
        dress(player)
        local bag = VC.containerOf(VC.wear(player, "Base.Bag_BigHikingBag"))
        local fanny = VC.containerOf(VC.wear(player, "Base.Bag_FannyPackFront"))
        pack(player, bag, fanny)
        arm(player, bag)
        for perk, n in pairs(SKILLS) do VC.levels(player, Perks[perk], n) end
    end,

    -- the hotbar exists by now, and Vitality's own kits have been dealt
    firstMinute = function()
        local player = getSpecificPlayer(0)
        if not player then return end
        strapOn(player)
        meds(player)
    end,
})

VC.nomad = { FOOD = FOOD, MED_EXTRA = MED_EXTRA, MAP_ID = MAP_ID }   -- tests
