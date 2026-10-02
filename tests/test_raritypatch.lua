-- Offline test for the Item Rarity UI patch in Dan's Vanilla Fixes
-- (DansVanillaFixes/42/media/lua/client/DansVanillaFixes_ItemRarity.lua):
-- the tiers and their list minimums, alias tables counted once, bag and
-- clutter lists only as a fallback, crafted and default items, and that
-- items Item Rarity UI already knows are left alone. Then, when the game and
-- Item Rarity UI are installed, the real loot lists with this mod's loot
-- merged in: vanilla items must mostly agree with Item Rarity UI's own table,
-- and every Vitality Project item must get a tier from its loot.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local HERE = arg[0]:match("^(.*)[/\\]") or "."
local PATCH = HERE .. "/../DansVanillaFixes/42/media/lua/client/DansVanillaFixes_ItemRarity.lua"

local function color(r) return { r = r, g = r, b = r } end
local function newUI(known)
  ItemRarityUI = {
    dataLoaded = true,
    itemRarities = known or {},
    rarityOverrides = {},
    rarityTiers = { legendary = { color = color(1) }, epic = { color = color(0.9) }, rare = { color = color(0.8) },
      uncommon = { color = color(0.7) }, common = { color = color(0.6) }, crafted = { color = color(0.5) },
      unknown = { color = color(0.4) } },
  }
end
local function scripts(list)
  local items = {}
  for _, s in ipairs(list) do
    items[#items + 1] = { getFullName = function() return s[1] end, isCraftRecipeProduct = function() return s[2] == true end }
  end
  getScriptManager = function()
    return { getAllItems = function() return { size = function() return #items end, get = function(_, i) return items[i + 1] end } end }
  end
end
local function quiet(fn) local p = print; print = function() end; local r = fn(); print = p; return r end

function require() end
newUI()
dofile(PATCH)
local M = ItemRarityModdedItems
H.expectHooks("OnGameStart")

-- tiers and their minimums
assert(M.tier(0.005, 3) == "legendary" and M.tier(0.005, 2) == "rare", "legendary needs 3 lists")
assert(M.tier(0.02, 2) == "epic" and M.tier(0.02, 1) == "uncommon", "epic needs 2 lists")
assert(M.tier(0.1, 1) == "rare" and M.tier(0.3, 1) == "uncommon" and M.tier(0.5, 1) == "common", "upper tiers")

-- a full list (30 entries, total weight 30) counts at full strength: chance = weight / total
local function fullList(name, w)
  local t = { name, w }
  for i = 1, 29 do t[#t + 1] = "Base.Filler" .. i; t[#t + 1] = (30 - w) / 29 end
  return t
end
local shared = { rolls = 1, items = fullList("Mod.Shared", 3) }
ProceduralDistributions = { list = { A = { items = fullList("Mod.Common", 15) }, B = shared } }
SuburbsDistributions = { clinic = { shelves = shared }, medical = { shelves = shared },   -- one table, two names
  all = { inventorymale = { items = { "Mod.Small", 1 } } } }                               -- 1 item, total 1: scaled to 1/300
VehicleDistributions = { { glovebox = { junk = nil } } }
ClutterTables = { ClosetItems = { "Mod.Closet", 1, "Base.Filler1", 1 }, BinJunk = { rolls = 1, items = { "Mod.Common", 100 } } }
BagsAndContainers = { Purse = { items = { "Mod.Bag", 1 } } }
SuburbsDistributions.bin = { junk = ClutterTables.BinJunk }   -- the clutter list a container points at
local main, extra = M.scanLoot()
H.near(main["Mod.Common"].chance, 0.5, 1e-9, "full list: weight / total")
assert(main["Mod.Common"].occurrences == 1, "a clutter list a container points at is not counted in main")
assert(main["Mod.Shared"].occurrences == 1, "one table under two room names counts once")
H.near(main["Mod.Small"].chance, 1 / 300, 1e-9, "a one-item list of weight 1 counts 1/30 x 1/10")
assert(not main["Mod.Closet"] and extra["Mod.Closet"] and extra["Mod.Bag"], "bags and clutter are the fallback")

-- apply: known items untouched, loot, fallback, crafted, default
newUI({ ["Base.Axe"] = { rarity = "rare", chance = 0.1, occurrences = 5, color = color(0.8) } })
scripts({ { "Base.Axe" }, { "Mod.Common" }, { "Mod.Small" }, { "Mod.Closet" }, { "Mod.Made", true }, { "Mod.Nowhere" } })
assert(quiet(M.apply) == 5, "five added")
local R = ItemRarityUI.itemRarities
assert(R["Base.Axe"].chance == 0.1 and R["Base.Axe"].occurrences == 5, "known item left alone")
assert(R["Mod.Common"].rarity == "common" and R["Mod.Common"].color == ItemRarityUI.rarityTiers.common.color, "from loot, with its colour")
assert(R["Mod.Small"].rarity == "rare", "one list under 1% is Rare, not Legendary")
assert(R["Mod.Closet"].occurrences == 1, "clutter-only item tiered from the clutter list")
assert(R["Mod.Made"].rarity == "crafted" and R["Mod.Nowhere"].rarity == "uncommon", "crafted, else uncommon")

-- Item Rarity UI not loaded: does nothing
ItemRarityUI = nil
assert(quiet(M.apply) == 0, "no Item Rarity UI, nothing to do")

-- the real lists, when the game and Item Rarity UI are installed
local GAME = "C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/media/lua/server/"
local IRUI = "C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3662387304/mods/item-rarity-ui/42/media/lua/shared/ItemRarityData.lua"
if not (loadfile(GAME .. "Items/ProceduralDistributions.lua") and loadfile(IRUI)) then
  print("raritypatch: game or Item Rarity UI not installed, real-list check skipped")
else
  ProceduralDistributions, SuburbsDistributions, Distributions, VehicleDistributions = nil, nil, nil, nil
  ClutterTables, BagsAndContainers, VehicleClutterTables = nil, nil, nil
  for _, f in ipairs({ "Items/Distribution_BagsAndContainers.lua", "Items/Distribution_BinJunk.lua",
      "Items/Distribution_ClosetJunk.lua", "Items/Distribution_CounterJunk.lua", "Items/Distribution_DeskJunk.lua",
      "Items/Distribution_ShelfJunk.lua", "Items/Distribution_SideTableJunk.lua",
      "Vehicles/VehicleDistribution_GloveBoxJunk.lua", "Vehicles/VehicleDistribution_SeatJunk.lua",
      "Vehicles/VehicleDistribution_TrunkJunk.lua", "Items/ProceduralDistributions.lua", "Items/Distributions.lua",
      "Vehicles/VehicleDistributions.lua" }) do
    dofile(GAME .. f)
  end
  quiet(function() H.load("server/Items/DanTraits_Distributions.lua"); H.fire("OnPreDistributionMerge") end)
  local data = dofile(IRUI)
  main = M.scanLoot()
  local n, same = 0, 0
  for k, d in pairs(data) do
    local a = main[k]
    if a and d.chance > 0 then
      n = n + 1
      if M.tier(a.chance, a.occurrences) == d.rarity then same = same + 1 end
    end
  end
  print(string.format("raritypatch: %d of %d vanilla items in Item Rarity UI's tier (%.0f%%)", same, n, 100 * same / n))
  assert(n > 2000 and same / n > 0.9, "vanilla items mostly agree with Item Rarity UI's table")
  for _, name in ipairs({ "Inhaler", "InsulinPen", "GlucoseMeter", "TestStrips", "IronPills", "Metformin",
      "NicotineGum", "Anticonvulsants", "Sunblock" }) do
    local a = main["DanTraits." .. name]
    assert(a, name .. " found in the loot lists")
    print(string.format("raritypatch: DanTraits.%s %s (%.4f, %d lists)", name, M.tier(a.chance, a.occurrences), a.chance, a.occurrences))
  end
end

H.pass("raritypatch")
