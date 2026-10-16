-- Offline test for laundry (DanTraits_Laundry.lua, DanTraits_LaundryWash.lua,
-- DanTraits_LaundryDry.lua, DanTraits_LaundryGear.lua, client/DanTraits_LaundryClient.lua,
-- and the bath floors in DanTraits_Bathing.lua): the hand-wash and washboard
-- floors on every patch (moved from Dan's Vanilla Fixes), set-in stains as a
-- floor of their own, odour and must washed out, no wash when nothing would
-- come off, wringing leaving clothes damp, the damp clock (worn counts 1.5x),
-- sweat by layer, the moodle and its small lift on unhappiness, washers,
-- bleach, fabric wear, ponchos and fabric protector, the clothesline weather,
-- the wash menu filter, the bath floors and the master switch.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()

local function list(t)
  return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end

-- a garment: per-part blood and dirt (0..1), totals counted the game's way
local function garment(kind, parts, opts)
  opts = opts or {}
  local g = { kind = kind, blood = {}, dirt = {}, names = {}, bloodLevel = 0, dirtiness = 0,
              wet = opts.wet or 0, md = {}, cond = opts.cond or 10, loc = opts.loc or "base:tshirt",
              type = opts.type or "Base.Tshirt_White" }
  for name, v in pairs(parts) do
    g.names[#g.names + 1] = name
    g.blood[name], g.dirt[name] = v[1], v[2]
  end
  table.sort(g.names)
  function g:getBloodClothingType() return self.names end
  function g:getCoveredParts() return list(self.names) end
  function g:getBlood(p) return self.blood[p] end
  function g:getDirt(p) return self.dirt[p] end
  function g:setBlood(p, v) self.blood[p] = v end
  function g:setDirt(p, v) self.dirt[p] = v end
  function g:setBloodLevel(v) self.bloodLevel = v end
  function g:setDirtiness(v) self.dirtiness = v end
  function g:getDirtiness() return self.dirtiness end
  function g:getBloodlevel() return self.bloodLevel end
  function g:getWetness() return self.wet end
  function g:setWetness(v) self.wet = v end
  function g:updateWetness() end
  function g:getModData() return self.md end
  function g:getBodyLocation() return self.loc end
  function g:getCondition() return self.cond end
  function g:setCondition(v) self.cond = v end
  function g:getFullType() return self.type end
  function g:getName() return "Garment" end
  function g:getContainer() return { Remove = function() g.removed = true end } end
  return g
end

local function totals(item, field, key)
  local sum = 0
  for _, p in ipairs(item.names) do sum = sum + item[field][p] end
  item[key] = #item.names > 0 and sum / #item.names * 100 or 0
end
BloodClothingType = {
  getCoveredParts = function(names) return list(names) end,
  calcTotalBloodLevel = function(item) totals(item, "blood", "bloodLevel") end,
  calcTotalDirtLevel = function(item) totals(item, "dirt", "dirtiness") end,
}
instanceof = function(o, cls)
  if cls == "ItemContainer" then return type(o) == "table" and (o.getItems or o.AddItem) ~= nil end
  return type(o) == "table" and o.kind == cls
end
syncItemFields = function() end
syncVisuals = function() end

-- vanilla's actions, cut down
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
function ISWashClothing:getDuration() return 200 end
function ISWashClothing.GetSoapRemaining(soaps) return soaps.uses end
function ISWashClothing.GetRequiredWater() return 6 end
ISWringClothing = {}
function ISWringClothing:complete() self.item:setWetness(math.min(self.item:getWetness(), 10)); return true end
function ISWringClothing:isValid() return self.item:getWetness() > 10 end
function ISWringClothing:getDuration() return math.ceil(self.item:getWetness() * 5) end

local menuCalls = {}
ISWorldObjectContextMenu = {
  onWashClothing = function(playerObj, sink, soapList, washList, single)
    menuCalls[#menuCalls + 1] = { list = washList, single = single }
  end,
}

SandboxVars = { DanTraits = {} }
local tooltipSources = {}
DanShared_Tooltip = { add = function(id, order, fn) tooltipSources[id] = { order = order, fn = fn } end }
H.load("Laundry", "LaundryWash", "LaundryDry", "LaundryGear", "Bathing", "client/DanTraits_LaundryClient.lua")
local L = DanTraits_Laundry
assert(L and L.on(), "loaded and on by default")
H.expectEvery("minute", "Laundry")
H.expectEvery("ten", "Laundry")

-- a character: worn items and carried items are tables of garments
local function person(o)
  local p = H.player(o)
  p._wornList, p._carried = {}, {}
  p.getWornItems = function()
    return { size = function() return #p._wornList end, getItemByIndex = function(_, i) return p._wornList[i + 1] end }
  end
  p.getInventory = function()
    return {
      getItems = function() return list(p._carried) end,
      getFirstTypeRecurse = function(_, t)
        for _, it in ipairs(p._carried) do if it.type == t then return it end end
      end,
      getSoapList = function() return p._soaps or { uses = 0 } end,
    }
  end
  p.removeWornItem = function(_, item)
    for i, it in ipairs(p._wornList) do if it == item then table.remove(p._wornList, i) end end
  end
  return p
end
local function wear(p, g) p._wornList[#p._wornList + 1] = g; p._carried[#p._carried + 1] = g end
local function carry(p, g) p._carried[#p._carried + 1] = g end

local player = person()
H.current = player
local function wash(item, soap, who)
  return ISWashClothing.complete({ item = item, character = who or player, noSoap = not soap })
end

-- 1. layers by body location
do
  assert(L.layer(garment("Clothing", {}, { loc = "base:tshirt" })) == 1, "a t-shirt sweats in full")
  assert(L.layer(garment("Clothing", {}, { loc = "base:jacket" })) == 0.5, "a jacket half")
  assert(L.layer(garment("Clothing", {}, { loc = "base:necklace" })) == 0, "a necklace not at all")
  assert(L.layer(garment("InventoryContainer", {})) == 0, "a bag is not clothing")
end

-- 2. hand washing: 40% without soap, 20% with; odour and must out; the count
do
  local shirt = garment("Clothing", { Torso = { 0.9, 1.0 }, UpperArmL = { 0.5, 0.6 } })
  L.state(shirt, true).o, L.state(shirt, true).m = 90, true
  wash(shirt)
  H.near(shirt.blood.Torso, 0.4, 1e-9, "no soap: blood floor")
  H.near(shirt.dirt.UpperArmL, 0.4, 1e-9, "no soap: dirt floor on the second part")
  H.near(shirt.dirtiness, 40, 1e-9, "Dirty total counted again")
  assert(shirt.wet == 100, "vanilla still soaks it")
  local s = L.state(shirt)
  assert(s.o == 30 and not s.m and s.n == 1, "no soap: odour down to 30, must gone, one wash")
  local pants = garment("Clothing", { UpperLegL = { 1.0, 1.0 }, UpperLegR = { 0.0, 0.7 } })
  L.state(pants, true).o = 70
  wash(pants, true)
  H.near(pants.blood.UpperLegL, 0.2, 1e-9, "soap: 20%")
  assert(pants.blood.UpperLegR == 0, "a clean patch stays clean")
  assert(L.state(pants).o == 0, "soap: odour all gone")
end

-- 3. nothing to gain: no wash, no water, says why; a stale clean shirt is worth washing
do
  H.clearHalo()
  local runs, used = vanillaRuns, water
  local tee = garment("Clothing", { Torso = { 0.4, 0.38 } })
  assert(wash(tee) == true, "the action still completes")
  assert(vanillaRuns == runs and water == used and tee.wet == 0, "nothing would come off: vanilla never runs")
  assert(H.halo[#H.halo] == "IGUI_DanTraits_WashNeedsSoap", "says it needs soap")
  wash(garment("Clothing", { Torso = { 0.2, 0.1 } }), true)
  assert(H.halo[#H.halo] == "IGUI_DanTraits_WashNeedsBoard", "with soap: a washboard or a machine")
  local stale = garment("Clothing", { Torso = { 0, 0 } })
  L.state(stale, true).o = 60
  wash(stale)
  assert(vanillaRuns == runs + 1 and L.state(stale).o == 30, "a stale clean shirt is washed: odour down")
end

-- 4. the washboard: lower floors, longer scrub
do
  local board = garment("Normal", {}, { type = "DanTraits.Washboard" })
  carry(player, board)
  local shirt = garment("Clothing", { Torso = { 1, 1 } })
  wash(shirt)
  H.near(shirt.blood.Torso, 0.25, 1e-9, "washboard, no soap: 25%")
  local shirt2 = garment("Clothing", { Torso = { 1, 1 } })
  wash(shirt2, true)
  H.near(shirt2.dirt.Torso, 0.10, 1e-9, "washboard, soap: 10%")
  local t = ISWashClothing.getDuration({ item = shirt, character = player })
  assert(t == 300, "half as long again, got " .. tostring(t))
  player._carried = {}
  assert(ISWashClothing.getDuration({ item = shirt, character = player }) == 200, "without it: vanilla time")
  H.clearHalo()
  wash(garment("Clothing", { Torso = { 0.2, 0.1 } }), true, player)
  assert(H.halo[#H.halo] == "IGUI_DanTraits_WashNeedsBoard", "no board: suggests one")
end

-- 5. bags follow the floors; rags wash as vanilla
do
  local bag = garment("InventoryContainer", { Back = { 0.8, 0.8 } })
  wash(bag)
  H.near(bag.blood.Back, 0.4, 1e-9, "bag: floored")
  local rag = { kind = "Normal", bloodLevel = 1, setBloodLevel = function(self, v) self.bloodLevel = v end }
  local runs = vanillaRuns
  wash(rag)
  assert(vanillaRuns == runs + 1 and rag.bloodLevel == 0, "non-clothing: vanilla, fully clean")
end

-- 6. the sandbox floors, and laundry off is vanilla
do
  SandboxVars.DanTraits = { LaundryHandFloor = 60, LaundryHandSoapFloor = 0 }
  local a = garment("Clothing", { Torso = { 1, 1 } })
  wash(a)
  H.near(a.dirt.Torso, 0.6, 1e-9, "LaundryHandFloor 60")
  local b = garment("Clothing", { Torso = { 1, 1 } })
  wash(b, true)
  assert(b.dirt.Torso == 0, "LaundryHandSoapFloor 0: vanilla clean")
  SandboxVars.DanTraits = { LaundryHandFloor = 250 }
  assert(L.floor("hand", false) == 1, "clamped to 100%")
  SandboxVars.DanTraits = { LaundryEnabled = false }
  local c = garment("Clothing", { Torso = { 1, 1 } })
  wash(c)
  assert(c.dirt.Torso == 0 and L.state(c) == nil, "laundry off: vanilla wash, nothing tracked")
  SandboxVars.DanTraits = {}
end

-- 7. wringing leaves it damp (shoes damper); not offered at the line; off is vanilla
do
  local shirt = garment("Clothing", {}, { wet = 100 })
  local act = { item = shirt, character = player }
  setmetatable(act, { __index = ISWringClothing })
  assert(act:isValid(), "soaked: worth wringing")
  H.near(act:getDuration(), 250, 1e-9, "only the water that comes out takes time")
  act:complete()
  assert(shirt.wet == 50, "wrung to 50, got " .. tostring(shirt.wet))
  assert(not act:isValid(), "at the line: not offered again")
  local shoes = garment("Clothing", {}, { wet = 100, loc = "base:shoes" })
  ISWringClothing.complete({ item = shoes, character = player })
  assert(shoes.wet == 70, "shoes: 70")
  local damp = garment("Clothing", {}, { wet = 30 })
  ISWringClothing.complete({ item = damp, character = player })
  assert(damp.wet == 30, "already under the line: as it was")
  SandboxVars.DanTraits = { LaundryEnabled = false }
  local off = garment("Clothing", {}, { wet = 100 })
  ISWringClothing.complete({ item = off, character = player })
  assert(off.wet == 10, "off: vanilla 10")
  SandboxVars.DanTraits = {}
end

-- 8. the damp clock: 6 hours damp is musty; worn counts 1.5x; drying starts it over
do
  local g = garment("Clothing", {}, { wet = 100 })
  L.sight(g, false, 0)
  L.sight(g, false, 5)
  assert(not L.state(g).m, "5 hours: not yet")
  H.near(L.mustyIn(g), 1, 1e-9, "an hour left")
  L.sight(g, false, 6)
  local s = L.state(g)
  assert(s.m and s.o == 80, "6 hours: musty, odour 80")
  assert(L.mustyIn(g) == nil, "musty: no countdown")
  local worn = garment("Clothing", {}, { wet = 100 })
  L.sight(worn, true, 0)
  L.sight(worn, true, 4)
  assert(L.state(worn).m, "worn: 4 hours count as 6")
  local dried = garment("Clothing", {}, { wet = 100 })
  L.sight(dried, true, 0)
  L.sight(dried, true, 3)
  dried.wet = 5
  L.sight(dried, true, 3.1)
  dried.wet = 100
  L.sight(dried, true, 3.2)
  L.sight(dried, true, 6)
  assert(not L.state(dried).m, "dried in between: the clock started over")
  SandboxVars.DanTraits = { LaundryDampHours = 2 }
  local quick = garment("Clothing", {}, { wet = 40 })
  L.sight(quick, false, 0); L.sight(quick, false, 2)
  assert(L.state(quick).m, "LaundryDampHours 2")
  SandboxVars.DanTraits = {}
end

-- 9. sweat by layer and work; the sandbox rate
do
  local r = L.rate(0, 0)
  H.near(r, 0.4, 1e-9, "just worn: 0.4 an hour")
  H.near(L.rate(1, 1), 2.9, 1e-9, "hard work in the heat")
  local tee = garment("Clothing", {}, { loc = "base:tshirt" })
  local coat = garment("Clothing", {}, { loc = "base:jacket" })
  L.sweat(tee, 2, 10); L.sweat(coat, 2, 10)
  assert(L.state(tee).o == 20 and L.state(coat).o == 10, "the jacket half as fast")
  L.sweat(tee, 100, 10)
  assert(L.state(tee).o == 100, "capped at 100")
  SandboxVars.DanTraits = { LaundryOdourRate = 0 }
  assert(L.rate(1, 1) == 0, "rate 0: never stale")
  SandboxVars.DanTraits = {}
end

-- 10. the clock: worn clothes sweat, the moodle, the small lift on unhappiness
do
  local p = person({ unhappy = 0 })
  H.current = p
  local tee = garment("Clothing", {}, { loc = "base:tshirt" })
  wear(p, tee)
  L.state(tee, true).o = 49.95
  H.mins(10); H.ten()
  assert(L.state(tee).o > 50, "ten minutes worn: over the line")
  local d = DanTraits_Data(p)
  assert(d.lnMoodle == 1, "Stale Clothes")
  H.mins(60)
  H.near(p._st.unhappy, 0.5, 1e-6, "half a point of unhappiness an hour")
  p._st.unhappy = 25
  H.mins(10)
  assert(p._st.unhappy == 25, "over the cap: nothing more")
  L.state(tee).m = true
  H.ten()
  assert(d.lnMoodle == 2, "musty: the second level")
  H.mins(60)
  H.near(p._st.unhappy, 26, 1e-6, "musty: a point an hour, cap 30")
  SandboxVars.DanTraits = { LaundryMood = 0 }
  p._st.unhappy = 0
  H.mins(30)
  assert(p._st.unhappy == 0, "LaundryMood 0: the moodle costs nothing")
  SandboxVars.DanTraits = {}
  local g = person({ unhappy = 0, traits = { "germaphobe" } })
  H.current = g
  local gt = garment("Clothing", {}, { loc = "base:tshirt" })
  wear(g, gt)
  L.state(gt, true).o = 60
  H.ten(); H.mins(60)
  H.near(g._st.unhappy, 1, 1e-6, "Germaphobe: twice as much")
  assert(L.staleParts(g).Torso == nil and next(L.staleParts(g)) == nil, "no covered parts on this shirt")
  gt.names = { "Torso_Upper" }
  assert(L.staleParts(g).Torso_Upper, "Germaphobe reads the stale part")
  SandboxVars.DanTraits = { LaundryEnabled = false }
  H.mins(1)
  assert(DanTraits_Data(g).lnMoodle == nil, "off: no moodle")
  SandboxVars.DanTraits = {}
  H.current = player
end

-- 11. set-in stains: half the blood after 3 days, capped; washes stop at it; bleach clears it
do
  local g = garment("Clothing", { Torso = { 0.6, 0 } })
  L.sight(g, false, 0)
  L.sight(g, false, 71)
  assert(not L.hasStain(g), "under 3 days: no stain")
  L.sight(g, false, 72)
  assert(L.hasStain(g) and L.state(g).st.Torso == 0.2, "set: half of 0.6, capped at 0.2")
  wash(g, true)
  H.near(g.blood.Torso, 0.2, 1e-9, "soap cannot take it under the stain")
  g.blood.Torso = 0
  L.machineWashed(g)
  H.near(g.blood.Torso, 0.2, 1e-9, "a machine wash leaves the stain")
  assert(L.state(g).o == 0, "and the odour is gone")
  L.bleach(g)
  assert(not L.hasStain(g) and g.blood.Torso == 0 and g.wet == 100, "bleach: stain and blood out, soaked")
  SandboxVars.DanTraits = { LaundryStainDays = 0 }
  local h = garment("Clothing", { Torso = { 0.6, 0 } })
  L.sight(h, false, 0); L.sight(h, false, 500)
  assert(not L.hasStain(h), "LaundryStainDays 0: no stains")
  SandboxVars.DanTraits = {}
end

-- 12. washers: marked while running, the effects land when the garment is next seen
do
  local g = garment("Clothing", {}, { wet = 0 })
  L.state(g, true).o = 70
  L.state(g).mw = true
  L.sight(g, false, 1000)
  assert(L.state(g).o == 0 and not L.state(g).mw and L.state(g).n == 1, "machine washed when seen")
  local container = { getItems = function() return list({ g }) end }
  local washer = { kind = "IsoClothingWasher", isActivated = function() return true end, getContainer = function() return container end }
  assert(L.runningWasher(washer) == container, "a running washer")
  washer.isActivated = function() return false end
  assert(L.runningWasher(washer) == nil, "an idle one")
  local combo = { kind = "IsoCombinationWasherDryer", isActivated = function() return true end,
                  isModeWasher = function() return false end, getContainer = function() return container end }
  assert(L.runningWasher(combo) == nil, "a combo drying is not washing")
  local stacked = { kind = "IsoStackedWasherDryer", isWasherActivated = function() return true end,
                    getContainerByType = function(_, t) return t == "clothingwasher" and container or nil end }
  assert(L.runningWasher(stacked) == container, "a stacked washer-dryer washing (its own switch and drum)")
  stacked.isWasherActivated = function() return false end
  assert(L.runningWasher(stacked) == nil, "its washer off")
  -- marked only once the cycle has finished with the garment (blood 0, dirt 0, soaked): pulled out
  -- early it was a wash at full blood (review 2026-10-16 A1.9)
  local bloody = garment("Clothing", { Torso = { 0.5, 0.2 } }, { wet = 100 })
  local dry = garment("Clothing", { Torso = { 0, 0 } }, { wet = 0 })
  local done = garment("Clothing", { Torso = { 0, 0 } }, { wet = 100 })
  local drum = { getItems = function() return list({ bloody, dry, done }) end }
  local running = { kind = "IsoClothingWasher", isActivated = function() return true end, getContainer = function() return drum end }
  assert(L.markWasher(running), "a running washer is a running washer")
  assert((L.state(done) or {}).mw == true, "the finished garment is marked")
  assert(not (L.state(bloody) or {}).mw and not (L.state(dry) or {}).mw, "a garment still bloody, or not yet wet, is not")
  bloody.blood.Torso, bloody.dirt.Torso = 0, 0
  L.markWasher(running)
  assert((L.state(bloody) or {}).mw == true, "once the cycle has it clean and soaked, it is")
end

-- 13. fabric wear: a roll per wash, never under 1, off means off
do
  H.rollf = 0.001
  local g = garment("Clothing", { Torso = { 1, 1 } }, { cond = 5 })
  wash(g, true)
  assert(g.cond == 4, "a hand wash cost a point")
  local worn = garment("Clothing", {}, { cond = 1 })
  assert(not L.wear(worn, "bleach") and worn.cond == 1, "never under 1")
  SandboxVars.DanTraits = { LaundryWear = 1 }
  local off = garment("Clothing", {}, { cond = 5 })
  assert(not L.wear(off, "bleach") and off.cond == 5, "Off: no wear")
  SandboxVars.DanTraits = {}
  H.rollf = 0.99
end

-- 14. a poncho takes the hits under it; a garbage bag poncho tears; fabric protector halves them
do
  local p = person()
  H.current = p
  local shirt = garment("Clothing", { Torso_Upper = { 0, 0 }, UpperLeg_L = { 0, 0 } })
  local poncho = garment("Clothing", { Torso_Upper = { 0, 0 } }, { type = "Base.PonchoGarbageBag", loc = "base:jackethat", cond = 1 })
  wear(p, shirt); wear(p, poncho)
  H.mins(1)
  shirt.blood.Torso_Upper, shirt.blood.UpperLeg_L = 0.5, 0.5
  H.mins(1)
  assert(shirt.blood.Torso_Upper == 0, "under the poncho: taken back off")
  assert(shirt.blood.UpperLeg_L == 0.5, "where it does not cover: stays")
  H.rollf = 0.001
  shirt.blood.Torso_Upper = 0.3
  H.mins(1)
  assert(poncho.removed and #p._wornList == 1, "at condition 1 the garbage bag poncho tore apart")
  H.rollf = 0.99
  local tee = garment("Clothing", { Torso_Upper = { 0, 0 } })
  wear(p, tee)
  L.protect(tee)
  H.mins(1)
  tee.dirt.Torso_Upper = 0.4
  H.mins(1)
  H.near(tee.dirt.Torso_Upper, 0.2, 1e-9, "protected: half stays")
  assert(L.protection(tee) < 1, "and it wears a little")
  local pr = L.protection(tee)
  tee.dirt.Torso_Upper = 0.9
  wash(tee, true)
  H.near(L.protection(tee), pr - 0.34, 1e-9, "a wash takes a third")
  SandboxVars.DanTraits = { LaundryPoncho = false }
  tee.dirt.Torso_Upper = 0.6
  H.mins(1); tee.dirt.Torso_Upper = 0.9; H.mins(1)
  assert(tee.dirt.Torso_Upper == 0.9, "LaundryPoncho off: no shield")
  SandboxVars.DanTraits = {}
  H.current = player
end

-- 15. the clothesline weather
do
  H.climate.temp, H.climate.rain = 25, 0
  local cm = getClimateManager
  getClimateManager = function()
    local c = cm()
    c.getTemperature = function() return H.climate.temp end
    c.getWindIntensity = function() return 0 end
    c.getDayLightStrength = function() return 1 end
    return c
  end
  local w = L.lineWeather(true)
  H.near(w.rate, 40 * 1.5 * 1.3, 1e-9, "warm clear day: 78 an hour")
  assert(w.airing, "daylight airs it")
  local g = garment("Clothing", {}, { wet = 100 })
  L.state(g, true).o = 60
  L.lineItem(g, w, 1)
  H.near(g.wet, 22, 1e-9, "an hour on the line")
  assert(L.state(g).o == 55, "aired 5")
  L.lineItem(g, w, 10)
  assert(g.wet == 0 and L.state(g).o == 30, "dry, and airing stops at 30")
  H.climate.rain = 0.5
  w = L.lineWeather(true)
  L.lineItem(g, w, 1)
  assert(g.wet == 20, "rain soaks it again")
  local roof = L.lineWeather(false)
  H.near(roof.rate, 24, 1e-9, "under a roof: 0.6x, no weather")
  H.climate.rain = 0
  getClimateManager = cm
end

-- 16. the wash menu drops what cannot get cleaner
do
  H.clearHalo()
  menuCalls = {}
  local dirty = garment("Clothing", { Torso = { 0, 0.9 } })
  local done = garment("Clothing", { Torso = { 0.3, 0.3 } })
  ISWorldObjectContextMenu.onWashClothing(player, "sink", { uses = 0 }, { dirty, done }, nil)
  assert(#menuCalls == 1 and #menuCalls[1].list == 1 and menuCalls[1].list[1] == dirty, "no soap: only the dirty one")
  ISWorldObjectContextMenu.onWashClothing(player, "sink", { uses = 3 }, { dirty, done }, nil)
  assert(#menuCalls[2].list == 2, "with soap both have something to lose")
  ISWorldObjectContextMenu.onWashClothing(player, "sink", { uses = 0 }, nil, done)
  assert(#menuCalls == 2 and H.halo[#H.halo] == "IGUI_DanTraits_WashNeedsSoap", "nothing queued, and says why")
end

-- 17. tooltip lines
do
  local g = garment("Clothing", { Torso = { 0, 0 } }, { wet = 100 })
  L.sight(g, false, 2000)
  local lines = L.tooltipLines(g)
  assert(lines and lines[1][1] == "Tooltip_DanTraits_DampHours:6", "damp: hours to musty")
  L.state(g).m = true
  assert(L.tooltipLines(g)[1][1] == "Tooltip_DanTraits_Musty", "musty first")
  assert(L.tooltipLines(garment("Clothing", {})) == nil, "a fresh dry garment: nothing")
  -- through the shared strip, not a render wrap of its own (two boxes painted over each other
  -- with item info on; review 2026-10-16 A1.10)
  local src = tooltipSources.laundry
  assert(src and src.order == 22, "registered with DanShared_Tooltip at 22 (after Reading's 20, before item info's 25)")
  local strip = src.fn(nil, g)
  local lines = L.tooltipLines(g)
  assert(strip and #strip == #lines and strip[1][1] == lines[1][1], "the same lines")
  assert(type(strip[1][2]) == "number" and type(strip[1][3]) == "number" and type(strip[1][4]) == "number", "as { text, r, g, b }")
  assert(strip[1][2] == 1 and strip[1][3] == 0.75, "a bad line in the warning colour")
  assert(src.fn(nil, garment("Clothing", {})) == nil, "nothing for a fresh dry garment")
  assert(not (ISToolTipInv and ISToolTipInv.DanTraitsWraps and ISToolTipInv.DanTraitsWraps["render:laundry-info"]), "no render wrap of its own")
end

-- 18. Infection: a musty garment over a wound counts as dirty clothing there
do
  local p = person()
  local shirt = garment("Clothing", { Torso_Upper = { 0, 0 } })
  wear(p, shirt)
  local part = { getType = function() return "Torso_Upper" end, hasDirtyClothing = function() return false end }
  assert(DanTraits_RunHooks("infectionHazard", 2, p, part) == 2, "fresh: as it was")
  L.state(shirt, true).m = true
  assert(DanTraits_RunHooks("infectionHazard", 2, p, part) == 3, "musty: x1.5")
  part.hasDirtyClothing = function() return true end
  assert(DanTraits_RunHooks("infectionHazard", 2, p, part) == 2, "already dirty: nothing on top")
end

-- 19. Take A Bath And Shower: the clothes washed in the bath are floored too
do
  local bather = person()
  bather._soaps = { uses = 0 }
  local shirt = garment("Clothing", { Torso_Upper = { 1, 1 }, Torso_Lower = { 0.1, 0.3 } })
  local worn = list({ { getItem = function() return shirt end } })
  local called = 0
  TABAS_BathingUtils = { cleaningWornItems = function(character, wornItems)
    called = called + 1
    for i = 0, wornItems:size() - 1 do
      local it = wornItems:get(i):getItem()
      for _, name in ipairs(it.names) do it:setBlood(name, 0); it:setDirt(name, 0) end
    end
    return 1, true
  end }
  DanTraits_BathingInstallClothes(); DanTraits_BathingInstallClothes()
  local a, b = TABAS_BathingUtils.cleaningWornItems(bather, worn, 0.1, 1)
  assert(called == 1 and a == 1 and b == true, "the original ran once and its answer came back")
  H.near(shirt.blood.Torso_Upper, 0.4, 1e-9, "no soap: 40%")
  H.near(shirt.dirt.Torso_Lower, 0.3, 1e-9, "a patch under the floor stays")
  bather._soaps.uses = 3
  shirt.blood.Torso_Upper = 1
  TABAS_BathingUtils.cleaningWornItems(bather, worn, 0.1, 1)
  H.near(shirt.blood.Torso_Upper, 0.2, 1e-9, "soap to hand: 20%")
  TABAS_BathingUtils = nil
end

-- 20. clotheslines: a post gets a container through the game's three-argument
--     constructor (the five-argument one threw on every post, every ten minutes:
--     2026-10-11); one put up from Lua, then taken down again
do
  local made = 0
  ItemContainer = { new = function(...)
    made = made + 1
    assert(select("#", ...) == 3, "ItemContainer.new takes (type, square, parent), got " .. select("#", ...))
    local c = { items = {} }
    function c:setCapacity(n) self.cap = n end
    function c:setExplored() end
    function c:getItems() return list(self.items) end
    function c:Remove(item) for i, x in ipairs(self.items) do if x == item then table.remove(self.items, i) end end end
    return c
  end }
  local grid = {}
  local function square(x, y, opts)
    opts = opts or {}
    local sq = { x = x, y = y, objs = {}, floor = opts.floor ~= false, free = opts.free ~= false, dropped = {} }
    function sq:getX() return self.x end
    function sq:getY() return self.y end
    function sq:getZ() return 0 end
    function sq:hasFloor() return self.floor end
    function sq:isFree() return self.free end
    function sq:getObjects() return list(self.objs) end
    function sq:AddTileObject(o) self.objs[#self.objs + 1] = o end
    function sq:RemoveTileObject(o) for i, x in ipairs(self.objs) do if x == o then table.remove(self.objs, i) end end end
    function sq:transmitRemoveItemFromSquare() end
    function sq:AddWorldInventoryItem(item) self.dropped[#self.dropped + 1] = item end
    grid[x .. "," .. y] = sq
    return sq
  end
  getCell = function() return { getGridSquare = function(_, x, y) return grid[x .. "," .. y] end } end
  isServer = function() return false end
  IsoObject = { new = function(sq, sprite)
    local o = { sq = sq, sprite = sprite, md = {} }
    function o:getSprite() return { getName = function() return o.sprite end } end
    function o:getSquare() return o.sq end
    function o:getModData() return o.md end
    function o:getContainer() return o.c end
    function o:setContainer(c) o.c = c end
    return o
  end }
  getSprite = function(name) return { name = name } end
  IsoObject.new = function(a1, a2, a3)
    -- (cell, square, sprite) or (square, name)
    local sq, sprite = a2, a3
    if a3 == nil then sq, sprite = a1, { name = a2 } end
    local o = { sq = sq, sprite = sprite.name, md = {} }
    function o:getSprite() return { getName = function() return o.sprite end } end
    function o:getSquare() return o.sq end
    function o:getModData() return o.md end
    function o:getContainer() return o.c end
    function o:setContainer(c) o.c = c end
    return o
  end
  local row = {}
  for x = 10, 14 do row[#row + 1] = square(x, 10) end
  local a, b = row[1], row[5]
  square(10, 11, { free = false })
  local sqs = L.lineSquares(a, "ew")
  assert(sqs and #sqs == 5 and sqs[5] == b, "east-west: five clear squares")
  assert(L.lineSquares(a, "ns") == nil, "north-south: blocked")
  assert(L.lineSquares(row[2], "ew") == nil, "not enough squares beyond: nothing")

  local p = person()
  local function item(t)
    local it = { type = t }
    function it:getFullType() return self.type end
    function it:getContainer() return { Remove = function() it.used = true end } end
    return it
  end
  carry(p, item("Base.LongStick"))
  carry(p, item("Base.Rope"))
  assert(L.lineMaterials(p) == nil, "one of each: not enough")
  carry(p, item("Base.Plank")); carry(p, item("Base.Twine"))
  local mats = L.lineMaterials(p)
  assert(mats and #mats.posts == 2 and #mats.ties == 2, "two posts and two ties")
  assert(L.putUpLine(p, a, "ew", mats), "put up")
  assert(a.objs[1].sprite == "appliances_laundry_01_26" and b.objs[1].sprite == "appliances_laundry_01_27", "the posts at the ends")
  for n = 2, 4 do assert(row[n].objs[1].sprite == "appliances_laundry_01_30" and row[n].objs[1].md.dtlWire, "wire on " .. n) end
  assert(made == 2 and a.objs[1].c.cap == 15 and row[3].objs[1].c == nil, "a container on each post, none on the wire")
  assert(mats.posts[1].used and mats.ties[2].used, "the materials are used")
  assert(L.isBuiltLine(b.objs[1]) and not L.isBuiltLine(row[3].objs[1]), "posts are the built line, wires not")

  -- a post whose sprite name reads empty still counts by its mark
  local blank = IsoObject.new(row[3], "x")
  blank.getSprite = function() return { getName = function() return nil end } end
  blank.md.dtlBuilt = true
  assert(L.isLinePost(blank), "an unnamed built post is still a post")

  local shirt = garment("Clothing", {}, { wet = 100 })
  table.insert(b.objs[1].c.items, shirt)
  p._added = {}
  p.getInventory = function() return { AddItem = function(_, t) p._added[#p._added + 1] = t end } end
  assert(L.takeDownLine(p, row[3].objs[1]), "taken down from a wire")
  for n = 1, 5 do assert(#row[n].objs == 0, "square " .. n .. " cleared") end
  assert(b.dropped[1] == shirt, "what hung on it is on the floor")
  assert(#p._added == 4, "two long sticks and two twine back")

  local mapPost = IsoObject.new(a, "appliances_laundry_01_29")
  assert(L.ensureLine(mapPost) and not L.isBuiltLine(mapPost), "a map post gets a container but cannot be taken down")
end

-- 21. the debug command answers every subcommand without an error
do
  H.load("client/DanTraits_LaundryCommands.lua")
  local p = person()
  H.current = p
  p.isOutside = function() return true end
  p.getX = function() return 10 end
  p.getY = function() return 10 end
  local tee = garment("Clothing", { Torso_Upper = { 0, 0 } }, { wet = 0 })
  tee.getConditionMax = function() return 10 end
  wear(p, tee)
  local cmd = DanTraits_ExtraCommands.laundry
  assert(cmd(p, {}):find("^moodle "), "report")
  assert(cmd(p, { "dirty", "0.5", "0.4" }):find("1 worn") and tee.blood.Torso_Upper == 0.5, "dirty")
  assert(cmd(p, { "soak" }):find("wetness 100") and tee.wet == 100, "soak")
  assert(cmd(p, { "odour", "60" }):find("moodle 1"), "odour sets the moodle")
  assert(cmd(p, { "musty" }):find("moodle 2"), "musty")
  assert(cmd(p, { "stain", "0.2" }) and L.hasStain(tee), "stain")
  assert(cmd(p, { "age", "6" }):find("back 6"), "age")
  assert(cmd(p, { "tick" }):find("^tick"), "tick")
  assert(cmd(p, { "all" }):find("MUSTY"), "all lists the musty tee")
  assert(cmd(p, { "clear" }):find("1 garments") and tee.wet == 0 and not L.state(tee).m and (L.state(tee).o or 0) < 1, "clear")
  assert(cmd(p, { "lines" }):find("^lines:"), "lines")
  assert(cmd(p, { "washers" }):find("^washers"), "washers")
  assert(cmd(p, { "heat" }):find("^heat"), "heat")
  assert(cmd(p, { "nonsense" }):find("^laundry:"), "usage on an unknown subcommand")
end

-- 22. worn clothes dry at a quarter of the game's pace, and worn damp they go stale faster
do
  local g = garment("Clothing", {}, { wet = 100 })
  L.bodyDry(g, 10)                     -- the first reading
  g.wet = 80                           -- the game dried 20 in a minute
  L.bodyDry(g, 10 + 1 / 60)
  H.near(g.wet, 95, 1e-9, "a quarter of the drying kept")
  g.wet = 100                          -- washed again: a rise is left alone
  L.bodyDry(g, 10 + 2 / 60)
  assert(g.wet == 100, "rises untouched")
  g.wet = 40                           -- put back on after drying in a bag (an old reading)
  L.bodyDry(g, 11)
  assert(g.wet == 40, "an old reading is not continued from")
  SandboxVars.DanTraits = { LaundryBodyDryRate = 100 }
  g.wet = 20
  L.bodyDry(g, 11 + 1 / 60)
  assert(g.wet == 20, "100%: the game's own speed")
  SandboxVars.DanTraits = {}
  local damp = garment("Clothing", {}, { wet = 60, loc = "base:tshirt" })
  local dry = garment("Clothing", {}, { wet = 0, loc = "base:tshirt" })
  L.sweat(damp, 0.4, 1); L.sweat(dry, 0.4, 1)
  H.near(L.state(damp).o, 25.4, 1e-9, "an hour worn damp: 25 more")
  H.near(L.state(dry).o, 0.4, 1e-9, "dry: just the wear")
end

-- 23. fresh clothes: the good side of the moodle, and what it does
do
  local p = person({ unhappy = 50, stress = 0.5 })
  H.current = p
  local tee = garment("Clothing", {}, { loc = "base:tshirt" })
  local pants = garment("Clothing", {}, { loc = "base:pants" })
  for _, g in ipairs({ tee, pants }) do
    g.isDirty = function(self) return self.dirtiness > 15 end
    g.isBloody = function(self) return self.bloodLevel > 25 end
    wear(p, g)
  end
  local boots = garment("Clothing", {}, { loc = "base:shoes" })
  boots.isDirty = function() return true end
  boots.isBloody = function() return false end
  wear(p, boots)
  assert(L.wornLevel(p) == -1, "clean, dry and fresh (muddy shoes aside): Fresh Clothes")
  H.ten(); H.mins(60)
  H.near(p._st.unhappy, 49.5, 1e-6, "half a point of unhappiness off an hour")
  H.near(p._st.stress, 0.49, 1e-6, "and a little stress")
  L.state(tee, true).sun = true
  assert(L.wornLevel(p) == -2, "half of it dried on a line in the sun: Line-Dried")
  tee.wet = 40
  assert(L.wornLevel(p) == 0, "one garment still damp: nothing")
  tee.wet = 0
  tee.dirtiness = 20
  assert(L.wornLevel(p) == 0, "one garment dirty: nothing")
  tee.dirtiness = 0
  L.state(pants, true).o = 20
  assert(L.wornLevel(p) == 0, "one garment past fresh: nothing")
  L.state(pants).o = 60
  assert(L.wornLevel(p) == 1, "stale wins over fresh")
  L.state(pants).o = 0
  L.state(tee).sun = true
  local snap = L.snapshot(tee)
  L.afterHandWash(tee, snap, "hand", true)
  assert(not L.state(tee).sun, "a wash clears the line-dried mark")
  local line = garment("Clothing", {}, { wet = 50 })
  L.lineItem(line, { rain = 0, rate = 40, airing = true }, 1)
  assert(L.state(line).sun, "dried on a line in daylight: marked")
  local night = garment("Clothing", {}, { wet = 50 })
  L.lineItem(night, { rain = 0, rate = 20, airing = false }, 1)
  assert(not (L.state(night) or {}).sun, "at night: not")
  H.current = player
end

H.pass("laundry")
