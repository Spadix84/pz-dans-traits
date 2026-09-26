-- Loot for Dan's Traits.
-- Each mod item spawns as itself, weighted like the other prescription
-- bottles: common wherever medicine is kept, rare in pockets and bags.
-- Weights are relative to the other entries in the same list (for scale:
-- beta blockers are 1 in a bathroom cabinet, 20 in a doctor's bag, 0.1 on a
-- zombie). Insulin also turns up in fridges, where people keep it.
require "Items/ProceduralDistributions"
require "Items/Distributions"

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
    print("[DanTraits] " .. spec.name .. " added to " .. added .. " loot lists" .. (#missing > 0 and ("; not found: " .. table.concat(missing, ", ")) or ""))
end

local function addAllLoot()
    for _, spec in ipairs(ITEMS) do addLoot(spec) end
end

Events.OnPreDistributionMerge.Add(addAllLoot)
