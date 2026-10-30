-- Vitality Challenges: the test scaffolding for The Last Broadcast, off before
-- release (TEST below, or delete the file). With it on: the lowest zombie
-- population, one dead in the studio and none in the street, the studio stocked
-- with a bit of everything, and a step van near the start, as new, full tank,
-- the same stock in the back, its key in your pocket.
--
-- VitalityChallenges_LastBroadcast.lua reaches these through VC.dev, which is
-- nil when the file is absent or TEST is off, so every hook is then a no-op:
--   VC.dev.population(sandbox)     the sandbox table, before the world loads
--   VC.dev.dead(inside, yard)      the studio's dead to place instead
--   VC.dev.stock(building, floor)  the stock into the building's containers
--   VC.dev.spawnVan(state, player) the van, once its square has loaded

require "VitalityChallenges_Core"
require "VitalityChallenges_Kit"
local VC = VitalityChallenges

local TEST = true
local TEST_VAN = { script = "Base.StepVan", x = 12287, y = 3803, dir = "S" }
local DEAD_INSIDE, DEAD_YARD = 1, 0

-- the test stock: a bit of everything, spread over the studio's containers
local TEST_STOCK = {
    -- food and water
    { "Base.TinnedSoup", count = 4 }, { "Base.TinnedBeans", count = 4 }, { "Base.CannedBolognese", count = 3 },
    { "Base.CannedCorn", count = 3 }, { "Base.TunaTin", count = 3 }, { "Base.CannedChili", count = 3 },
    { "Base.Crackers", count = 2 }, { "Base.PeanutButter" }, { "Base.GranolaBar", count = 4 },
    { "Base.Pop", count = 4 }, { "Base.WaterBottle", count = 4, water = 1 }, { "Base.TinOpener" },
    -- medical
    { "Base.Bandage", count = 6 }, { "Base.AlcoholBandage", count = 2 }, { "Base.Disinfectant" },
    { "Base.AlcoholWipes" }, { "Base.Pills" }, { "Base.PillsBeta" }, { "Base.PillsVitamins" },
    { "Base.PillsAntiDep" }, { "Base.Antibiotics" }, { "Base.Splint", count = 2 },
    { "Base.SutureNeedle", count = 2 }, { "Base.SutureNeedleHolder" }, { "Base.Tweezers" },
    -- fuel and light
    { "Base.PetrolCan", count = 2 }, { "Base.Battery", count = 6 }, { "Base.HandTorch" },
    { "Base.Candle", count = 2 }, { "Base.Lighter" }, { "Base.Matches" },
    -- tools
    { "Base.Hammer" }, { "Base.NailsBox" }, { "Base.Saw" }, { "Base.Screwdriver" }, { "Base.Wrench" },
    { "Base.DuctTape" }, { "Base.Rope" }, { "Base.Plank", count = 6 }, { "Base.ElectronicsScrap", count = 4 },
    -- weapons
    { "Base.Axe" }, { "Base.Machete" }, { "Base.Crowbar" }, { "Base.BaseballBat" },
    { "Base.Shotgun" }, { "Base.ShotgunShellsBox", count = 2 },
    { "Base.Pistol" }, { "Base.9mmClip", count = 2 }, { "Base.Bullets9mmBox", count = 2 },
    -- carrying
    { "Base.Bag_DuffelBag" }, { "Base.Bag_ALICEpack" },
}

local function population(t)
    t.Zombies = 5                   -- Low, the thinnest crowd short of none
    t.ZombieConfig = {
        PopulationMultiplier = ZombiePopulationMultiplier and ZombiePopulationMultiplier.Low or "0.15",
        PopulationStartMultiplier = 0.5,
        PopulationPeakMultiplier = 0.5,
    }
end

local function dead() return DEAD_INSIDE, DEAD_YARD end

-- the test stock, dealt out over the containers in the building (the floor
-- square when there are none)
local function stock(building, floor)
    local containers = {}
    for x = building[1], building[3] do
        for y = building[2], building[4] do
            pcall(function()
                local objects = getCell():getGridSquare(x, y, 0):getObjects()
                for j = 0, objects:size() - 1 do
                    local obj = objects:get(j)
                    for k = 0, obj:getContainerCount() - 1 do
                        containers[#containers + 1] = obj:getContainerByIndex(k)
                    end
                end
            end)
        end
    end
    for i, entry in ipairs(TEST_STOCK) do
        if #containers > 0 then
            VC.put(containers[(i - 1) % #containers + 1], entry)
        elseif floor then
            for _ = 1, entry.count or 1 do
                pcall(function()
                    local item = floor:AddWorldInventoryItem(entry[1], ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0)
                    if entry.water then item:getFluidContainer():addFluid(Fluid.Water, entry.water) end
                end)
            end
        end
    end
end

-- the test van, once its square has loaded
local function spawnVan(state, player)
    if state.vanReady or not getCell():getGridSquare(TEST_VAN.x, TEST_VAN.y, 0) then return end
    local van = VC.vehicle(TEST_VAN.script, TEST_VAN.x, TEST_VAN.y, 0, TEST_VAN.dir)
    if not van then return end
    state.vanReady = true
    pcall(function() van:repair() end)
    pcall(function()
        local tank = van:getPartById("GasTank")
        tank:setContainerContentAmount(tank:getContainerCapacity())
    end)
    pcall(function() van:setLocked(false) end)
    pcall(function() player:getInventory():AddItem(van:createVehicleKey()) end)
    local back
    pcall(function() back = van:getPartById("TruckBed"):getItemContainer() end)
    if back then
        for _, entry in ipairs(TEST_STOCK) do VC.put(back, entry) end
    end
end

if TEST then
    VC.dev = { TEST = true, population = population, dead = dead, stock = stock, spawnVan = spawnVan }
end
