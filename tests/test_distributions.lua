local handlers = {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) handlers[k] = f end }; rawset(t, k, e); return e end })
local logged = {}
local realprint = print
print = function(s) logged[#logged+1] = s end
function require() end
local function L() return { "PillsBeta", 1 } end
ProceduralDistributions = { list = {} }
for _, n in ipairs({ "BathroomCabinet","BathroomCounter","BathroomShelf","MedicalCabinet","MedicalClinicDrugs","MedicalClinicOutfit","MedicalStorageDrugs","MedicalStorageOutfit","HospitalRoomShelves","DoctorTools","NurseTools","AmbulanceDriverTools","StoreShelfMedical","SafehouseMedical","SafehouseMedical_Mid","SafehouseMedical_Late","DerelictHouseDrugs","DrugShackDrugs","ArmyStorageMedical","ArmyBunkerMedical","TestingLab","KitchenRandom","PrisonCellRandom" }) do
  ProceduralDistributions.list[n] = { rolls = 1, items = L() }
end
SuburbsDistributions = { all = { medicine = { items = L() }, inventoryfemale = { items = L() }, inventorymale = { items = L() } },
  Bag_FannyPackFront = { items = L() }, Bag_FannyPackBack = { items = L() }, MedicalCache1 = { MedicalBox = { items = L() } } }
BagsAndContainers = { HandbagsAndPurses = { items = L() } }
ClutterTables = { ClosetItems = L() }
assert(loadfile("../DanTraits/42/media/lua/server/Items/DanTraits_Distributions.lua"))()
assert(handlers.OnPreDistributionMerge, "hook registered")
handlers.OnPreDistributionMerge()
realprint(logged[1])
assert(logged[1]:find("added to 31 loot lists") and not logged[1]:find("not found"), "all lists found")
local bc = ProceduralDistributions.list.BathroomCabinet.items
assert(bc[3] == "DanTraits.Inhaler" and bc[4] == 1, "appended as name, weight")
assert(SuburbsDistributions.all.inventorymale.items[4] == 0.1, "zombie pockets weight")
assert(ClutterTables.ClosetItems[3] == "DanTraits.Inhaler" and ClutterTables.ClosetItems[4] == 0.01, "flat clutter list")
assert(SuburbsDistributions.MedicalCache1.MedicalBox.items[4] == 5, "nested path")
-- a missing list is reported, not fatal
ProceduralDistributions.list.TestingLab = nil
logged = {}
handlers.OnPreDistributionMerge()
assert(logged[1]:find("added to 30 loot lists; not found: TestingLab"), logged[1])
realprint("distribution tests passed")
