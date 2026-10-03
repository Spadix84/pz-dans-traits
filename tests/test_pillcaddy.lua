-- Offline test for the pill caddy: AcceptItemFunction.DanPillCaddy takes
-- vanilla pills, this mod's medication, MS pills and anything on the shared
-- drug list, and turns away everything else (bandages, food, another caddy).
-- The inventory window gives each caddy in the main inventory (belt included)
-- its own tab once, on the character's window only. Loot: rare, medicine only.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Meds", "PillCaddy", "server/Items/DanTraits_PillCaddyAccept.lua", "client/DanTraits_PillCaddyTab.lua")

local function item(fullType)
  return {
    _type = fullType, _inv = {},
    getFullType = function(self) return self._type end,
    getType = function(self) return (self._type:gsub("^.*%.", "")) end,
    getInventory = function(self) return self._inv end,
    getTex = function() return "tex" end,
    getName = function(self) return self:getType() end,
  }
end
local accept = AcceptItemFunction.DanPillCaddy
for _, t in ipairs({ "Base.Pills", "Base.PillsBeta", "Base.PillsAntiDep", "Base.PillsSleepingTablets",
    "Base.PillsVitamins", "Base.Antibiotics", "DanTraits.Diazepam", "DanTraits.Metformin",
    "DanTraits.Anticonvulsants", "DanTraits.InsulinPen", "DanTraits.Inhaler", "DanTraits.IronPills",
    "DanTraits.Baclofen", "DanTraits.Amantadine", "DanTraits.Prednisone" }) do
  assert(accept(nil, item(t)), "takes " .. t)
end
for _, t in ipairs({ "Base.Bandage", "Base.Splint", "Base.Apple", "DanTraits.GlucoseMeter",
    "DanTraits.TestStrips", "DanTraits.Sunblock", "DanTraits.PillCaddy" }) do
  assert(not accept(nil, item(t)), "turns away " .. t)
end
-- a drug added to the shared list later is taken without touching the caddy
DanTraits_Drugs.newdrug = { items = { "newpill" }, kind = "daily" }
assert(not accept(nil, item("DanTraits.NewPill")), "not on the list yet")
-- (DanTraits_DrugOfItem is built once at load; the caddy reads it live)
local real = DanTraits_DrugOfItem
DanTraits_DrugOfItem = function(k) if k == "newpill" then return "newdrug" end return real(k) end
assert(accept(nil, item("DanTraits.NewPill")), "takes a drug on the shared list")
DanTraits_DrugOfItem = real

-- the tab
H.expectHooks("OnRefreshInventoryWindowContainers")
local caddy, caddy2, bag = item("DanTraits.PillCaddy"), item("DanTraits.PillCaddy"), item("Base.Bag_Schoolbag")
local list = { bag, caddy, item("Base.Pills"), caddy2 }
local inv = { getItems = function() return { size = function() return #list end, get = function(_, i) return list[i + 1] end } end }
H.current = { getInventory = function() return inv end }
local function page(onCharacter)
  local p = { player = 0, onCharacter = onCharacter, backpacks = { { inventory = bag._inv } } }
  function p:addContainerButton(container, tex, name)
    table.insert(self.backpacks, { inventory = container, name = name })
  end
  return p
end
local p = page(true)
H.fire("OnRefreshInventoryWindowContainers", p, "begin")
assert(#p.backpacks == 1, "nothing added before the vanilla tabs are in")
H.fire("OnRefreshInventoryWindowContainers", p, "buttonsAdded")
assert(#p.backpacks == 3 and p.backpacks[2].inventory == caddy._inv and p.backpacks[3].inventory == caddy2._inv, "a tab per caddy")
-- held in the hands, vanilla already gave it a tab: no second one
p = page(true); table.insert(p.backpacks, { inventory = caddy._inv })
H.fire("OnRefreshInventoryWindowContainers", p, "buttonsAdded")
assert(#p.backpacks == 3, "no duplicate tab")
-- the loot window is left alone
p = page(false)
H.fire("OnRefreshInventoryWindowContainers", p, "buttonsAdded")
assert(#p.backpacks == 1, "loot window untouched")

-- loot: rare, only where medicine is kept
ProceduralDistributions = { list = {} }
for _, n in ipairs({ "BathroomCabinet", "BathroomCounter", "MedicalCabinet", "MedicalClinicDrugs", "MedicalStorageDrugs" }) do
  ProceduralDistributions.list[n] = { items = {} }
end
SuburbsDistributions = { all = { medicine = { items = {} } } }
BagsAndContainers, ClutterTables = {}, {}
H.load("server/Items/DanTraits_Distributions.lua")
H.fire("OnPreDistributionMerge")
local function weightIn(items)
  for i = 1, #items, 2 do if items[i] == "DanTraits.PillCaddy" then return items[i + 1] end end
end
assert(weightIn(ProceduralDistributions.list.MedicalClinicDrugs.items) == 0.4, "pharmacy shelves")
assert(weightIn(ProceduralDistributions.list.BathroomCabinet.items) == 0.1, "medicine cabinet, rare")
assert(weightIn(SuburbsDistributions.all.medicine.items) == 0.1, "house medicine")
for _, l in pairs(ProceduralDistributions.list) do
  assert(weightIn(l.items) <= 0.4, "rare everywhere")
end
H.pass()
