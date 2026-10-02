-- Loot for Project Zomboid Vitality Project.
-- Each mod item spawns as itself, weighted like the other prescription
-- bottles: common wherever medicine is kept, rare in pockets and bags.
-- Weights are relative to the other entries in the same list (for scale:
-- beta blockers are 1 in a bathroom cabinet, 20 in a doctor's bag, 0.1 on a
-- zombie). Insulin also turns up in fridges, where people keep it. Sun block
-- is not medicine: it is as common as toothpaste (10 in a bathroom cabinet,
-- 20 on a toiletry shelf), and turns up in lockers, camping gear and glove boxes.
require "Items/ProceduralDistributions"
require "Items/Distributions"

-- The prescription bottles (anticonvulsants and the MS pills) are found in
-- the same places: this spread, times each bottle's own commonness.
local PRESCRIPTION = {
    procedural = {
        BathroomCabinet = 0.8, BathroomCounter = 0.4, BathroomShelf = 0.4,
        MedicalCabinet = 2, MedicalClinicDrugs = 4, MedicalStorageDrugs = 6, HospitalRoomShelves = 4,
        DoctorTools = 5, NurseTools = 2, AmbulanceDriverTools = 1, StoreShelfMedical = 2,
        SafehouseMedical = 5, SafehouseMedical_Mid = 2, SafehouseMedical_Late = 1,
        DerelictHouseDrugs = 0.5, DrugShackDrugs = 0.5, ArmyStorageMedical = 2, TestingLab = 3,
        KitchenRandom = 0.05,
    },
    suburbs = {
        { { "all", "medicine", "items" }, 0.8 },
        { { "all", "inventoryfemale", "items" }, 0.08 },
        { { "all", "inventorymale", "items" }, 0.08 },
        { { "MedicalCache1", "MedicalBox", "items" }, 3 },
    },
    bags = { HandbagsAndPurses = 0.02 },
    clutter = { ClosetItems = 0.01 },
}

local function prescription(name, commonness)
    local spec = { name = name, procedural = {}, suburbs = {}, bags = {}, clutter = {} }
    for list, weight in pairs(PRESCRIPTION.procedural) do spec.procedural[list] = weight * commonness end
    for _, s in ipairs(PRESCRIPTION.suburbs) do spec.suburbs[#spec.suburbs + 1] = { s[1], s[2] * commonness } end
    for list, weight in pairs(PRESCRIPTION.bags) do spec.bags[list] = weight * commonness end
    for list, weight in pairs(PRESCRIPTION.clutter) do spec.clutter[list] = weight * commonness end
    return spec
end

local ITEMS = {
    {
        name = "DanTraits.Inhaler",
        -- ProceduralDistributions.list[name].items
        procedural = {
            BathroomCabinet = 1, BathroomCounter = 0.5, BathroomShelf = 0.5,
            MedicalCabinet = 2, MedicalClinicDrugs = 4, MedicalClinicOutfit = 0.5,
            MedicalStorageDrugs = 8, MedicalStorageOutfit = 0.5, HospitalRoomShelves = 6,
            DoctorTools = 10, NurseTools = 2, AmbulanceDriverTools = 2, StoreShelfMedical = 2,
            SafehouseMedical = 10, SafehouseMedical_Mid = 5, SafehouseMedical_Late = 2,
            DerelictHouseDrugs = 2, DrugShackDrugs = 2,
            ArmyStorageMedical = 4, ArmyBunkerMedical = 0.5, TestingLab = 4,
            KitchenRandom = 0.05, PrisonCellRandom = 0.05,
        },
        -- SuburbsDistributions: path into the table, then weight
        suburbs = {
            { { "all", "medicine", "items" }, 1 },
            { { "all", "inventoryfemale", "items" }, 0.1 },   -- zombie pockets
            { { "all", "inventorymale", "items" }, 0.1 },
            { { "Bag_FannyPackFront", "items" }, 0.01 },
            { { "Bag_FannyPackBack", "items" }, 0.01 },
            { { "MedicalCache1", "MedicalBox", "items" }, 5 },
        },
        bags = { HandbagsAndPurses = 0.02 },      -- BagsAndContainers[name].items
        clutter = { ClosetItems = 0.01 },         -- ClutterTables[name] (flat item/weight list)
    },
    {
        name = "DanTraits.InsulinPen",
        procedural = {
            BathroomCabinet = 0.5, MedicalCabinet = 1.5, MedicalClinicDrugs = 4,
            MedicalStorageDrugs = 8, HospitalRoomShelves = 4, DoctorTools = 6, NurseTools = 2,
            AmbulanceDriverTools = 3, StoreShelfMedical = 1.5,
            SafehouseMedical = 6, SafehouseMedical_Mid = 3, SafehouseMedical_Late = 1,
            ArmyStorageMedical = 3, ArmyBunkerMedical = 0.5, TestingLab = 3,
            FridgeGeneric = 0.3, FridgeRich = 0.5, FridgeOther = 0.3, FridgeTrailerPark = 0.3,
            FridgeHoarder = 0.5, FridgeMedical = 6, FridgeOffice = 0.2, FridgeBreakRoom = 0.2,
        },
        suburbs = {
            { { "all", "medicine", "items" }, 0.5 },
            { { "all", "inventoryfemale", "items" }, 0.05 },
            { { "all", "inventorymale", "items" }, 0.05 },
            { { "MedicalCache1", "MedicalBox", "items" }, 4 },
        },
        bags = { HandbagsAndPurses = 0.01 },
        clutter = {},
    },
    {
        name = "DanTraits.GlucoseMeter",
        procedural = {
            BathroomCabinet = 0.5, BathroomCounter = 0.3, MedicalCabinet = 1, MedicalClinicDrugs = 2,
            MedicalStorageDrugs = 3, HospitalRoomShelves = 3, DoctorTools = 4, NurseTools = 2,
            AmbulanceDriverTools = 3, StoreShelfMedical = 2,
            SafehouseMedical = 3, SafehouseMedical_Mid = 2, SafehouseMedical_Late = 1,
            ArmyStorageMedical = 1, TestingLab = 2, DerelictHouseDrugs = 0.5,
        },
        suburbs = {
            { { "all", "medicine", "items" }, 0.3 },
            { { "MedicalCache1", "MedicalBox", "items" }, 2 },
        },
        bags = { HandbagsAndPurses = 0.01 },
        clutter = { ClosetItems = 0.01 },
    },
    {
        name = "DanTraits.TestStrips",
        procedural = {
            BathroomCabinet = 0.8, BathroomCounter = 0.3, MedicalCabinet = 1.5, MedicalClinicDrugs = 4,
            MedicalStorageDrugs = 6, HospitalRoomShelves = 4, DoctorTools = 4, NurseTools = 2,
            AmbulanceDriverTools = 3, StoreShelfMedical = 3,
            SafehouseMedical = 4, SafehouseMedical_Mid = 2, SafehouseMedical_Late = 1,
            ArmyStorageMedical = 2, TestingLab = 3, DerelictHouseDrugs = 0.5,
        },
        suburbs = {
            { { "all", "medicine", "items" }, 0.5 },
            { { "all", "inventoryfemale", "items" }, 0.05 },
            { { "all", "inventorymale", "items" }, 0.05 },
            { { "MedicalCache1", "MedicalBox", "items" }, 3 },
        },
        bags = { HandbagsAndPurses = 0.02 },
        clutter = { ClosetItems = 0.01 },
    },
    {
        name = "DanTraits.Metformin",
        procedural = {
            BathroomCabinet = 1, BathroomCounter = 0.5, BathroomShelf = 0.5,
            MedicalCabinet = 2, MedicalClinicDrugs = 4, MedicalStorageDrugs = 8, HospitalRoomShelves = 4,
            DoctorTools = 6, NurseTools = 2, AmbulanceDriverTools = 1, StoreShelfMedical = 3,
            SafehouseMedical = 6, SafehouseMedical_Mid = 3, SafehouseMedical_Late = 1,
            DerelictHouseDrugs = 1, DrugShackDrugs = 1, ArmyStorageMedical = 2, TestingLab = 3,
            KitchenRandom = 0.05,
        },
        suburbs = {
            { { "all", "medicine", "items" }, 1 },
            { { "all", "inventoryfemale", "items" }, 0.1 },
            { { "all", "inventorymale", "items" }, 0.1 },
            { { "MedicalCache1", "MedicalBox", "items" }, 4 },
        },
        bags = { HandbagsAndPurses = 0.02 },
        clutter = { ClosetItems = 0.01 },
    },
    prescription("DanTraits.Anticonvulsants", 1),   -- Epilepsy: like metformin, a little rarer
    prescription("DanTraits.Prednisone", 1.25),     -- MS: an everyday steroid, more common than most prescriptions
    prescription("DanTraits.Baclofen", 1),          -- MS
    prescription("DanTraits.Amantadine", 0.75),     -- MS: a little rarer
    {
        -- anti-anxiety pills: the vanilla beta blocker's old job, found where
        -- prescriptions are, a little more often in a drug shack
        name = "DanTraits.Diazepam",
        procedural = {
            BathroomCabinet = 1, BathroomCounter = 0.5, BathroomShelf = 0.5,
            MedicalCabinet = 2, MedicalClinicDrugs = 4, MedicalStorageDrugs = 8, HospitalRoomShelves = 4,
            DoctorTools = 6, NurseTools = 2, AmbulanceDriverTools = 2, StoreShelfMedical = 3,
            SafehouseMedical = 5, SafehouseMedical_Mid = 3, SafehouseMedical_Late = 1,
            DerelictHouseDrugs = 2, DrugShackDrugs = 3, ArmyStorageMedical = 2, TestingLab = 2,
            KitchenRandom = 0.05, BedroomSidetable = 0.05,
        },
        suburbs = {
            { { "all", "medicine", "items" }, 1 },
            { { "all", "inventoryfemale", "items" }, 0.1 },
            { { "all", "inventorymale", "items" }, 0.1 },
            { { "MedicalCache1", "MedicalBox", "items" }, 3 },
        },
        bags = { HandbagsAndPurses = 0.03 },
        clutter = { ClosetItems = 0.01 },
    },
    {
        -- common, like the other toiletries (for scale: toothpaste is 10 in a
        -- bathroom cabinet and 20 on a shop's toiletry shelf, a comb 6)
        name = "DanTraits.Sunblock",
        procedural = {
            BathroomCabinet = 8, BathroomCounter = 8, BathroomCounterNoMeds = 8, BathroomShelf = 6,
            GigamartToiletries = 15, GasStoreToiletries = 12, PharmacyCosmetics = 10, GigamartCosmetics = 8,
            StoreShelfMedical = 4,
            PoolLockers = 15, GolfLockers = 8, BaseballLockers = 6, GymLockers = 4, FishingLockers = 6,
            SeasonalWorkerLockers = 8, RangerLockers = 6, SchoolLockers = 1, Locker = 1, LockerClassy = 2,
            CampingStoreGear = 10, CampingLockers = 8, CrateCamping = 6, FishingStoreGear = 6,
            SportStoreAccessories = 4,
            BedroomDresser = 1, BedroomSidetable = 1, DresserGeneric = 1,
        },
        suburbs = {
            { { "all", "inventoryfemale", "items" }, 0.2 },
            { { "all", "inventorymale", "items" }, 0.1 },
            { { "Bag_FannyPackFront", "items" }, 0.5 },
            { { "Bag_FannyPackBack", "items" }, 0.5 },
        },
        bags = { HandbagsAndPurses = 1 },
        clutter = { ClosetItems = 0.5, GloveBoxItems = 2 },
    },
    {
        name = "DanTraits.IronPills",
        procedural = {
            BathroomCabinet = 1.5, BathroomCounter = 0.5, BathroomShelf = 0.5,
            MedicalCabinet = 2, MedicalClinicDrugs = 3, MedicalStorageDrugs = 6, HospitalRoomShelves = 3,
            DoctorTools = 3, NurseTools = 2, StoreShelfMedical = 4,
            SafehouseMedical = 4, SafehouseMedical_Mid = 2, SafehouseMedical_Late = 1,
            DerelictHouseDrugs = 1, ArmyStorageMedical = 1, TestingLab = 1,
            KitchenRandom = 0.1, CrateMedical = 2, GroceryBag = 0.05,
        },
        suburbs = {
            { { "all", "medicine", "items" }, 1.5 },
            { { "all", "inventoryfemale", "items" }, 0.1 },
            { { "all", "inventorymale", "items" }, 0.05 },
            { { "MedicalCache1", "MedicalBox", "items" }, 3 },
        },
        bags = { HandbagsAndPurses = 0.03 },
        clutter = { ClosetItems = 0.01 },
    },
    {
        -- not medicine here: it turns up rarely where the cigarettes are
        -- (for scale, a pack is 20 to 50 behind a tobacco counter, 4 on a bar)
        name = "DanTraits.NicotineGum",
        procedural = {
            StoreCounterTobacco = 1, GasStoreSpecial = 1, TobaccoStoreCigarettes = 2,
            BarCounterMisc = 0.2, MechanicShelfMisc = 0.1, JanitorMisc = 0.1,
            CarDealerDesk = 0.3, OfficeDeskStressed = 0.5, JackiesDesk = 0.2,
            SafehouseFood_Mid = 0.3, KitchenRandom = 0.03, BedroomSidetable = 0.05,
            SecurityDesk = 0.05, PrisonCellRandom = 0.05, StoreShelfMedical = 0.3,
        },
        suburbs = {
            { { "all", "inventoryfemale", "items" }, 0.005 },
            { { "all", "inventorymale", "items" }, 0.005 },
        },
        bags = { HandbagsAndPurses = 0.03 },
        clutter = { DeskItems = 0.1 },
    },
    {
        -- a rare find: a weekly pill organiser in a medicine cabinet, a bedside
        -- drawer, a handbag, or for sale on a pharmacy shelf
        name = "DanTraits.PillCaddy",
        procedural = {
            BathroomCabinet = 0.05, BathroomCounter = 0.03, BedroomSidetable = 0.02,
            MedicalCabinet = 0.1, MedicalClinicDrugs = 0.2, MedicalStorageDrugs = 0.1,
            StoreShelfMedical = 0.3, HospitalRoomShelves = 0.1, SafehouseMedical = 0.3,
        },
        suburbs = {
            { { "all", "medicine", "items" }, 0.05 },
        },
        bags = { HandbagsAndPurses = 0.01 },
        clutter = {},
    },
}

local function append(list, name, weight)
    if type(list) ~= "table" then return false end
    table.insert(list, name)
    table.insert(list, weight)
    return true
end

local function walk(root, path)
    local node = root
    for _, key in ipairs(path) do
        if type(node) ~= "table" then return nil end
        node = node[key]
    end
    return node
end

local function addLoot(spec)
    local added, missing = 0, {}
    for name, weight in pairs(spec.procedural) do
        local entry = ProceduralDistributions and ProceduralDistributions.list and ProceduralDistributions.list[name]
        if entry and append(entry.items, spec.name, weight) then added = added + 1 else missing[#missing + 1] = name end
    end
    for _, s in ipairs(spec.suburbs) do
        local path, weight = s[1], s[2]
        if append(walk(SuburbsDistributions, path), spec.name, weight) then added = added + 1 else missing[#missing + 1] = table.concat(path, ".") end
    end
    for name, weight in pairs(spec.bags) do
        local entry = BagsAndContainers and BagsAndContainers[name]
        if entry and append(entry.items, spec.name, weight) then added = added + 1 else missing[#missing + 1] = "BagsAndContainers." .. name end
    end
    for name, weight in pairs(spec.clutter) do
        if append(ClutterTables and ClutterTables[name], spec.name, weight) then added = added + 1 else missing[#missing + 1] = "ClutterTables." .. name end
    end
    if not (isDebugEnabled and isDebugEnabled()) then return end
    print("[DanTraits] " .. spec.name .. " added to " .. added .. " loot lists" .. (#missing > 0 and ("; not found: " .. table.concat(missing, ", ")) or ""))
end

local function addAllLoot()
    for _, spec in ipairs(ITEMS) do addLoot(spec) end
end

Events.OnPreDistributionMerge.Add(addAllLoot)
