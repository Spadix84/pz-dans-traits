-- Offline test for server/Items/DanTraits_Distributions.lua: on
-- OnPreDistributionMerge the Inhaler is appended (as name, weight) to every
-- loot list it knows, at each list's own shape (procedural rooms, zombie
-- pockets, bags, the flat clutter list, a nested path), and a list missing
-- from this build is reported (debug mode only), not fatal.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
function isDebugEnabled() return true end   -- the report only prints in debug mode
local logged = {}
local realprint = print
print = function(s) logged[#logged+1] = s end
local function L() return { "PillsBeta", 1 } end
ProceduralDistributions = { list = {} }
for _, n in ipairs({ "BathroomCabinet","BathroomCounter","BathroomShelf","MedicalCabinet","MedicalClinicDrugs","MedicalClinicOutfit","MedicalStorageDrugs","MedicalStorageOutfit","HospitalRoomShelves","DoctorTools","NurseTools","AmbulanceDriverTools","StoreShelfMedical","SafehouseMedical","SafehouseMedical_Mid","SafehouseMedical_Late","DerelictHouseDrugs","DrugShackDrugs","ArmyStorageMedical","ArmyBunkerMedical","TestingLab","KitchenRandom","PrisonCellRandom" }) do
  ProceduralDistributions.list[n] = { rolls = 1, items = L() }
end
SuburbsDistributions = { all = { medicine = { items = L() }, inventoryfemale = { items = L() }, inventorymale = { items = L() } },
  Bag_FannyPackFront = { items = L() }, Bag_FannyPackBack = { items = L() }, MedicalCache1 = { MedicalBox = { items = L() } } }
BagsAndContainers = { HandbagsAndPurses = { items = L() } }
ClutterTables = { ClosetItems = L() }
H.load("server/Items/DanTraits_Distributions.lua")
H.expectHooks("OnPreDistributionMerge")
H.fire("OnPreDistributionMerge")
realprint(logged[1])
assert(logged[1]:find("added to 31 loot lists") and not logged[1]:find("not found"), "all lists found")
local bc = ProceduralDistributions.list.BathroomCabinet.items
-- inhalers: x1.5 since 2026-10-07 (and sandbox InhalerLoot on top, below)
assert(bc[3] == "DanTraits.Inhaler", "appended as name, weight")
H.near(bc[4], 1.5, 1e-9, "inhaler: bathroom cabinet 1 x1.5")
H.near(SuburbsDistributions.all.inventorymale.items[4], 0.15, 1e-9, "zombie pockets weight")
assert(ClutterTables.ClosetItems[3] == "DanTraits.Inhaler", "flat clutter list")
H.near(ClutterTables.ClosetItems[4], 0.015, 1e-9, "flat clutter weight")
H.near(SuburbsDistributions.MedicalCache1.MedicalBox.items[4], 7.5, 1e-9, "nested path")
-- the prescription bottles share one spread of places, each times its own commonness
local function weightOf(list, name)
  for i = 1, #list, 2 do if list[i] == name then return list[i + 1] end end
end
for name, k in pairs({ Anticonvulsants = 1, Prednisone = 1.25, Baclofen = 1, Amantadine = 0.75 }) do
  local full = "DanTraits." .. name
  H.near(weightOf(bc, full), 0.8 * k, 1e-9, name .. ": bathroom cabinet")
  H.near(weightOf(ProceduralDistributions.list.DoctorTools.items, full), 5 * k, 1e-9, name .. ": doctor's bag")
  H.near(weightOf(SuburbsDistributions.MedicalCache1.MedicalBox.items, full), 3 * k, 1e-9, name .. ": medical cache")
  H.near(weightOf(BagsAndContainers.HandbagsAndPurses.items, full), 0.02 * k, 1e-9, name .. ": handbags")
  H.near(weightOf(ClutterTables.ClosetItems, full), 0.01 * k, 1e-9, name .. ": closet clutter")
end
-- the pill caddy: uncommon, likeliest on a pharmacy shelf, on the odd zombie; a found one holds pills
assert(weightOf(ProceduralDistributions.list.StoreShelfMedical.items, "DanTraits.PillCaddy") == 3, "caddy on pharmacy shelves")
-- Living With Type 1: health-magazine places, a pharmacy shelf, rarely a bathroom
assert(weightOf(ProceduralDistributions.list.StoreShelfMedical.items, "DanTraits.InsulinMag") == 1, "magazine on pharmacy shelves")
assert(weightOf(ProceduralDistributions.list.BathroomShelf.items, "DanTraits.InsulinMag") == 0.05, "magazine, rarely, on a bathroom shelf")
assert(weightOf(ProceduralDistributions.list.BathroomCabinet.items, "DanTraits.PillCaddy") == 0.5, "caddy in bathroom cabinets")
assert(weightOf(SuburbsDistributions.all.inventoryfemale.items, "DanTraits.PillCaddy") == 0.02, "caddy on a zombie")
assert(SuburbsDistributions.PillCaddy and SuburbsDistributions.PillCaddy.rolls == 2, "a found caddy rolls its contents twice")
assert(weightOf(SuburbsDistributions.PillCaddy.items, "Base.Pills") == 10, "painkillers likeliest")
assert(weightOf(SuburbsDistributions.PillCaddy.items, "DanTraits.Sumatriptan") == 2, "sumatriptan as likely as diazepam")
assert(weightOf(SuburbsDistributions.PillCaddy.items, "DanTraits.Prednisone") == 1, "the MS pills rarest")
for i = 1, #SuburbsDistributions.PillCaddy.items, 2 do
  assert(type(SuburbsDistributions.PillCaddy.items[i]) == "string" and type(SuburbsDistributions.PillCaddy.items[i + 1]) == "number", "name, weight pairs")
end
-- a missing list is reported, not fatal
ProceduralDistributions.list.TestingLab = nil
logged = {}
H.fire("OnPreDistributionMerge")
assert(logged[1]:find("added to 30 loot lists; not found: TestingLab"), logged[1])
-- outside debug mode the lists are still filled, silently
function isDebugEnabled() return false end
logged = {}
H.fire("OnPreDistributionMerge")
assert(#logged == 0, "no report outside debug mode")
-- sandbox InhalerLoot: a percent on top of the x1.5; 0 adds none
ProceduralDistributions.list.NurseTools.items = L()
SandboxVars = { DanTraits = { InhalerLoot = 200 } }
H.fire("OnPreDistributionMerge")
H.near(weightOf(ProceduralDistributions.list.NurseTools.items, "DanTraits.Inhaler"), 2 * 1.5 * 2, 1e-9, "InhalerLoot 200: twice the weight")
ProceduralDistributions.list.NurseTools.items = L()
SandboxVars = { DanTraits = { InhalerLoot = 0 } }
H.fire("OnPreDistributionMerge")
assert(weightOf(ProceduralDistributions.list.NurseTools.items, "DanTraits.Inhaler") == nil, "InhalerLoot 0: no inhalers")
assert(weightOf(ProceduralDistributions.list.NurseTools.items, "DanTraits.Anticonvulsants") ~= nil, "other items unaffected")
SandboxVars = nil
print = realprint
H.pass()
