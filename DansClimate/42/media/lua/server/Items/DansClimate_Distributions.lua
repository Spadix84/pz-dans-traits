-- Loot for Dan's Climate Control: where a Window Air Conditioner and a Space Heater
-- turn up, and the central units and the two manuals that teach installing them.
-- The first two are boxed stock in an appliance shop and a big store's electronics
-- aisle, now and then on a hardware store's shelves, and rarely in a warehouse crate or
-- somebody's garage; a heater is also the thing at the back of a bedroom closet.
-- Weights are relative to the other entries in the same list (for scale: a microwave
-- is 30 on an appliance shop's shelf, 4 in a Gigamart aisle and 0.1 in an electronics
-- crate; a cooler is 1 on a hardware shelf). Each item has a sandbox percent on top:
-- 100 the default, 0 none.
--
-- A furnace and a central air conditioner are rare: stock in an appliance shop, a
-- generator room's spare, a crate in a warehouse. The manuals are rarer than anything
-- else here: where the game keeps its last volume of a trade's skill books (weight 2
-- on a bookshop's or a hardware store's book shelf, 1 in a library), at a tenth of that
-- or less.
require "Items/ProceduralDistributions"

-- item, its sandbox option, and ProceduralDistributions.list[name].items weights
local LOOT = {
    {
        item = "Base.WindowAC", option = "WindowACLoot",
        places = {
            ElectronicStoreAppliances = 10,   -- one roll a shelf: about one shelf in ten
            GigamartHouseElectronics = 1.5,
            ToolStoreMisc = 1,
            CrateElectronics = 0.3,           -- warehouses and storage rooms
            GarageTools = 0.2,
            CrateTools = 0.1,
            CrateRandomJunk = 0.1,
        },
    },
    {
        item = "Base.Mov_SpaceHeater", option = "SpaceHeaterLoot",
        places = {
            ElectronicStoreAppliances = 10,
            GigamartHouseElectronics = 1.5,
            ToolStoreMisc = 1,
            CrateElectronics = 0.3,
            GarageTools = 0.3,
            ClosetShelfGeneric = 0.2,         -- homes: a rare find, there are a lot of closets
            CrateRandomJunk = 0.1,
        },
    },
    {
        item = "Base.HVACFurnace", option = "CentralUnitLoot",
        places = {
            ElectronicStoreAppliances = 2,
            GeneratorRoom = 1,
            CrateGenerator = 0.5,             -- beside the 10 a generator has there
            ToolStoreMisc = 0.2,
            CrateMetalwork = 0.1,
            CrateElectronics = 0.1,
        },
    },
    {
        item = "Base.HVACCondenser", option = "CentralUnitLoot",
        places = {
            ElectronicStoreAppliances = 2,
            GeneratorRoom = 1,
            CrateGenerator = 0.5,
            ToolStoreMisc = 0.2,
            CrateMetalwork = 0.1,
            CrateElectronics = 0.1,
        },
    },
    {
        item = "Base.BookHVACHeating", option = "CentralBookLoot",
        places = {
            BookstoreBlueCollar = 0.2,
            ToolStoreBooks = 0.2,
            EngineerTools = 0.2,
            GeneratorRoom = 0.2,
            UniversityLibraryBooks = 0.1,
            BookstoreBooks = 0.1,
            LibraryBooks = 0.05,
            ElectricianTools = 0.05,
            MetalWorkerTools = 0.05,
            CrateBooks = 0.02,
        },
    },
    {
        item = "Base.BookHVACCooling", option = "CentralBookLoot",
        places = {
            BookstoreBlueCollar = 0.2,
            ToolStoreBooks = 0.2,
            EngineerTools = 0.2,
            GeneratorRoom = 0.2,
            UniversityLibraryBooks = 0.1,
            BookstoreBooks = 0.1,
            LibraryBooks = 0.05,
            ElectricianTools = 0.05,
            MetalWorkerTools = 0.05,
            CrateBooks = 0.02,
        },
    },
}

-- the sandbox percent as a factor: 1 without the option (an old save, the tests)
local function lootScale(option)
    local sv = SandboxVars and SandboxVars.DansClimate
    local pct = sv and tonumber(sv[option])
    if not pct then return 1 end
    return math.max(0, pct) / 100
end

local function addItem(entry)
    local k = lootScale(entry.option)
    if k <= 0 then return end
    local added, missing = 0, {}
    for name, weight in pairs(entry.places) do
        local list = ProceduralDistributions and ProceduralDistributions.list and ProceduralDistributions.list[name]
        if list and type(list.items) == "table" then
            table.insert(list.items, entry.item)
            table.insert(list.items, weight * k)
            added = added + 1
        else
            missing[#missing + 1] = name
        end
    end
    if not (isDebugEnabled and isDebugEnabled()) then return end
    table.sort(missing)
    print("[DansClimate] " .. entry.item .. " added to " .. added .. " loot lists" .. (#missing > 0 and ("; not found: " .. table.concat(missing, ", ")) or ""))
end

local function addLoot()
    for _, entry in ipairs(LOOT) do addItem(entry) end
end

Events.OnPreDistributionMerge.Add(addLoot)
