-- Loot for Dan's Climate Control: where a Window Air Conditioner turns up.
-- It is boxed stock in an appliance shop and a big store's electronics aisle,
-- now and then on a hardware store's shelves, and rarely in a warehouse crate
-- or somebody's garage. Weights are relative to the other entries in the same
-- list (for scale: a microwave is 30 on an appliance shop's shelf, 4 in a
-- Gigamart aisle and 0.1 in an electronics crate; a cooler is 1 on a hardware
-- shelf). Sandbox WindowACLoot is a percent on top: 100 the default, 0 none.
require "Items/ProceduralDistributions"

local ITEM = "Base.WindowAC"

-- ProceduralDistributions.list[name].items
local PLACES = {
    ElectronicStoreAppliances = 10,   -- one roll a shelf: about one shelf in ten
    GigamartHouseElectronics = 1.5,
    ToolStoreMisc = 1,
    CrateElectronics = 0.3,           -- warehouses and storage rooms
    GarageTools = 0.2,
    CrateTools = 0.1,
    CrateRandomJunk = 0.1,
}

-- the sandbox percent as a factor: 1 without the option (an old save, the tests)
local function lootScale()
    local sv = SandboxVars and SandboxVars.DansClimate
    local pct = sv and tonumber(sv.WindowACLoot)
    if not pct then return 1 end
    return math.max(0, pct) / 100
end

local function addLoot()
    local k = lootScale()
    if k <= 0 then return end
    local added, missing = 0, {}
    for name, weight in pairs(PLACES) do
        local entry = ProceduralDistributions and ProceduralDistributions.list and ProceduralDistributions.list[name]
        if entry and type(entry.items) == "table" then
            table.insert(entry.items, ITEM)
            table.insert(entry.items, weight * k)
            added = added + 1
        else
            missing[#missing + 1] = name
        end
    end
    if not (isDebugEnabled and isDebugEnabled()) then return end
    print("[DansClimate] " .. ITEM .. " added to " .. added .. " loot lists" .. (#missing > 0 and ("; not found: " .. table.concat(missing, ", ")) or ""))
end

Events.OnPreDistributionMerge.Add(addLoot)
