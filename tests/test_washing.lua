-- Offline test for hand washing in Dan's Vanilla Fixes
-- (DansVanillaFixes/42/media/lua/shared/DansVanillaFixes_Washing.lua and
-- client/DansVanillaFixes_WashingClient.lua): the soap and no-soap floors on
-- every patch of blood and dirt, patches already under the floor left alone,
-- the garment totals counted again, no wash when nothing would come off,
-- non-clothing left to vanilla, the sandbox floors, and the wash menu
-- dropping garments that cannot get cleaner.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local HERE = arg[0]:match("^(.*)[/\\]") or "."
local ROOT = HERE .. "/../DansVanillaFixes/42/media/lua/"

local function list(t)
  return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end

-- a garment: per-part blood and dirt (0..1), totals counted the game's way
local function garment(kind, parts)
  local g = { kind = kind, blood = {}, dirt = {}, names = {}, bloodLevel = 0, dirtiness = 0, wet = 0 }
  for name, v in pairs(parts) do
    g.names[#g.names + 1] = name
    g.blood[name], g.dirt[name] = v[1], v[2]
  end
  table.sort(g.names)
  function g:getBloodClothingType() return self.names end
  function g:getBlood(p) return self.blood[p] end
  function g:getDirt(p) return self.dirt[p] end
  function g:setBlood(p, v) self.blood[p] = v end
  function g:setDirt(p, v) self.dirt[p] = v end
  function g:setBloodLevel(v) self.bloodLevel = v end
  function g:setDirtiness(v) self.dirtiness = v end
  function g:getDirtiness() return self.dirtiness end
  function g:setWetness(v) self.wet = v end
  return g
end

local totalsCalls = 0
local function totals(item, field, key)
  local sum = 0
  for _, p in ipairs(item.names) do sum = sum + item[field][p] end
  item[key] = #item.names > 0 and sum / #item.names * 100 or 0
end
local function gameTotals()
  BloodClothingType = {
    getCoveredParts = function(names) return list(names) end,
    calcTotalBloodLevel = function(item) totalsCalls = totalsCalls + 1; totals(item, "blood", "bloodLevel") end,
    calcTotalDirtLevel = function(item) totals(item, "dirt", "dirtiness") end,
  }
end
gameTotals()

instanceof = function(o, cls)
  return type(o) == "table" and o.kind == cls
end
syncItemFields = function() end
syncVisuals = function() end

-- vanilla's complete(), cut down: every covered part to zero, soaked, water used
local water, vanillaRuns = 0, 0
ISWashClothing = {}
function ISWashClothing:complete()
  vanillaRuns = vanillaRuns + 1
  local item = self.item
  if item.kind == "Clothing" or item.kind == "InventoryContainer" then
    for _, p in ipairs(item.names) do item:setBlood(p, 0); item:setDirt(p, 0) end
    if item.kind == "Clothing" then item:setWetness(100); item:setDirtiness(0) end
  end
  if item.setBloodLevel then item:setBloodLevel(0) end
  water = water + 1
  return true
end
function ISWashClothing.GetSoapRemaining(soaps) return soaps.uses end

local menuCalls = {}
ISWorldObjectContextMenu = {
  onWashClothing = function(playerObj, sink, soapList, washList, single)
    menuCalls[#menuCalls + 1] = { list = washList, single = single }
  end,
}

SandboxVars = { DansVanillaFixes = {} }
dofile(ROOT .. "shared/DansVanillaFixes_Washing.lua")
dofile(ROOT .. "client/DansVanillaFixes_WashingClient.lua")
local W = DVF_Washing

local player = {}
local function wash(item, soap)
  return ISWashClothing.complete({ item = item, character = player, noSoap = not soap })
end

-- 1. no soap: everything down to 40%, totals follow
do
  local shirt = garment("Clothing", { Torso = { 0.9, 1.0 }, UpperArmL = { 0.5, 0.6 } })
  wash(shirt)
  H.near(shirt.blood.Torso, 0.4, 1e-9, "no soap: blood floor")
  H.near(shirt.dirt.Torso, 0.4, 1e-9, "no soap: dirt floor")
  H.near(shirt.blood.UpperArmL, 0.4, 1e-9, "no soap: second part floored too")
  H.near(shirt.dirtiness, 40, 1e-9, "no soap: Dirty total counted again")
  H.near(shirt.bloodLevel, 40, 1e-9, "no soap: Bloody total counted again")
  assert(shirt.wet == 100, "vanilla still soaks it")
  assert(water == 1, "water used")
end

-- 2. soap: down to 20%
do
  local pants = garment("Clothing", { UpperLegL = { 1.0, 1.0 }, UpperLegR = { 0.0, 0.7 } })
  wash(pants, true)
  H.near(pants.blood.UpperLegL, 0.2, 1e-9, "soap: blood floor")
  H.near(pants.dirt.UpperLegR, 0.2, 1e-9, "soap: dirt floor")
  assert(pants.blood.UpperLegR == 0, "a clean patch stays clean")
  H.near(pants.dirtiness, 20, 1e-9, "soap: Dirty total")
  H.near(pants.bloodLevel, 10, 1e-9, "soap: Bloody total is the average of the parts")
end

-- 3. patches already under the floor are never made dirtier
do
  local jacket = garment("Clothing", { Torso = { 0.3, 0.9 }, Back = { 0.1, 0.05 } })
  wash(jacket)
  H.near(jacket.blood.Torso, 0.3, 1e-9, "under the floor: blood left as it was")
  H.near(jacket.dirt.Torso, 0.4, 1e-9, "over the floor: down to it")
  H.near(jacket.blood.Back, 0.1, 1e-9, "under the floor stays")
  H.near(jacket.dirt.Back, 0.05, 1e-9, "under the floor stays")
end

-- 4. nothing to gain: no wash, no water, says why
do
  H.clearHalo()
  local runs, used = vanillaRuns, water
  local tee = garment("Clothing", { Torso = { 0.4, 0.38 } })
  assert(wash(tee) == true, "the action still completes")
  assert(vanillaRuns == runs and water == used, "nothing would come off: vanilla never runs")
  assert(tee.wet == 0, "not soaked for nothing")
  assert(H.halo[#H.halo] == "IGUI_DVF_WashNeedsSoap", "says it needs soap")
  wash(garment("Clothing", { Torso = { 0.2, 0.1 } }), true)
  assert(H.halo[#H.halo] == "IGUI_DVF_WashNeedsMachine", "with soap: says it needs a machine")
  assert(vanillaRuns == runs, "still no wash")
  -- the same tee with soap has 18% to lose
  wash(tee, true)
  assert(vanillaRuns == runs + 1, "soap gets it further")
  H.near(tee.blood.Torso, 0.2, 1e-9, "soap takes the rest down to 20%")
end

-- 5. bags follow the floors; rags, bandages and weapons wash as vanilla
do
  local bag = garment("InventoryContainer", { Back = { 0.8, 0.8 } })
  wash(bag)
  H.near(bag.blood.Back, 0.4, 1e-9, "bag: floored")
  local rag = { kind = "Normal", bloodLevel = 1, setBloodLevel = function(self, v) self.bloodLevel = v end }
  local runs = vanillaRuns
  wash(rag)
  assert(vanillaRuns == runs + 1 and rag.bloodLevel == 0, "non-clothing: vanilla, fully clean")
end

-- 6. sandbox floors, and 0 is vanilla
do
  SandboxVars.DansVanillaFixes = { WashFloorNoSoap = 60, WashFloorSoap = 0 }
  local a = garment("Clothing", { Torso = { 1, 1 } })
  wash(a)
  H.near(a.dirt.Torso, 0.6, 1e-9, "WashFloorNoSoap 60")
  local b = garment("Clothing", { Torso = { 1, 1 } })
  wash(b, true)
  assert(b.dirt.Torso == 0 and b.blood.Torso == 0, "WashFloorSoap 0: as clean as vanilla")
  SandboxVars.DansVanillaFixes = { WashFloorNoSoap = 250 }
  assert(W.floor(false) == 1, "clamped to 100%")
  SandboxVars = nil
  assert(W.floor(false) == 0.4 and W.floor(true) == 0.2, "no sandbox: defaults 40 and 20")
  SandboxVars = { DansVanillaFixes = {} }
end

-- 7. without the game's total counters the totals are worked out here
do
  local saved = BloodClothingType
  BloodClothingType = { getCoveredParts = saved.getCoveredParts }
  local s = garment("Clothing", { Torso = { 1, 1 }, Back = { 0, 0.2 } })
  wash(s)
  H.near(s.dirtiness, 30, 1e-9, "fallback Dirty total")
  H.near(s.bloodLevel, 20, 1e-9, "fallback Bloody total")
  BloodClothingType = saved
end

-- 8. the menu: garments that cannot get cleaner are dropped before queueing
do
  H.clearHalo()
  menuCalls = {}
  local dirty = garment("Clothing", { Torso = { 0, 0.9 } })
  local done = garment("Clothing", { Torso = { 0.3, 0.3 } })
  ISWorldObjectContextMenu.onWashClothing(player, "sink", { uses = 0 }, { dirty, done }, nil)
  assert(#menuCalls == 1 and #menuCalls[1].list == 1 and menuCalls[1].list[1] == dirty, "no soap: only the dirty one is queued")
  ISWorldObjectContextMenu.onWashClothing(player, "sink", { uses = 3 }, { dirty, done }, nil)
  assert(#menuCalls[2].list == 2, "with soap both have something to lose")
  ISWorldObjectContextMenu.onWashClothing(player, "sink", { uses = 0 }, nil, done)
  assert(#menuCalls == 2, "a single garment at the floor: nothing queued")
  assert(H.halo[#H.halo] == "IGUI_DVF_WashNeedsSoap", "and says why")
  ISWorldObjectContextMenu.onWashClothing(player, "sink", nil, nil, dirty)
  assert(#menuCalls == 3 and menuCalls[3].list[1] == dirty and menuCalls[3].single == nil, "a single dirty garment goes through as a list")
end

-- 9. the console report
do
  local a = garment("Clothing", { Torso = { 0.5, 0.25 } })
  BloodClothingType.calcTotalBloodLevel(a); BloodClothingType.calcTotalDirtLevel(a)
  a.getName = function() return "T-shirt" end
  a.getBloodlevel = function(self) return self.bloodLevel end
  local clean = garment("Clothing", { Torso = { 0, 0 } })
  local carried = { a, clean, { kind = "Normal" } }
  local p = { getInventory = function() return { getItems = function() return list(carried) end } end }
  clean.getBloodlevel = function() return 0 end
  assert(W.report(p) == "T-shirt 25/50", "report: name dirt/blood, clean ones left out")
  carried = {}
  assert(W.report(p) == "nothing dirty carried", "report: nothing")
end

H.pass("washing")
