-- Offline test for the laundry traits (DanTraits_LaundryTraits.lua): Sweaty
-- and Cool Customer's odour, Slob's missing moodle, Homemaker's floors, wear
-- and Line-Dried, Sensitive Skin's itch, and the hooks into Nomad, Homebody,
-- Asthma, Fear of Blood and Bad Back. Laundry off: none of it.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()

local function list(t)
  return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end

local function garment(parts, opts)
  opts = opts or {}
  local g = { kind = "Clothing", blood = {}, dirt = {}, names = {}, bloodLevel = 0, dirtiness = 0,
              wet = opts.wet or 0, md = {}, cond = opts.cond or 10, loc = opts.loc or "base:tshirt",
              type = opts.type or "Base.Tshirt_White" }
  for name, v in pairs(parts or {}) do
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
  function g:getWetness() return self.wet end
  function g:setWetness(v) self.wet = v end
  function g:updateWetness() end
  function g:getModData() return self.md end
  function g:getBodyLocation() return self.loc end
  function g:getCondition() return self.cond end
  function g:setCondition(v) self.cond = v end
  function g:getFullType() return self.type end
  function g:getName() return "Garment" end
  function g:isDirty() return self.dirtiness > 15 end
  function g:isBloody() return self.bloodLevel > 25 end
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
instanceof = function(o, cls) return type(o) == "table" and o.kind == cls end
syncItemFields = function() end
syncVisuals = function() end

ISWashClothing = {}
function ISWashClothing:complete()
  for _, p in ipairs(self.item.names) do self.item:setBlood(p, 0); self.item:setDirt(p, 0) end
  self.item:setWetness(100)
  return true
end
function ISWashClothing:getDuration() return 200 end
ISWringClothing = {}
function ISWringClothing:complete() return true end
function ISWringClothing:isValid() return true end
function ISWringClothing:getDuration() return 1 end

-- what the other traits were told
local fumes, strain = {}, {}
DanTraits_AsthmaFumes = function(p, amount) fumes[#fumes + 1] = amount; return true end
DanTraits_BadBackStrain = function(p, amount) strain[#strain + 1] = amount; return true end

SandboxVars = { DanTraits = {} }
H.load("Laundry", "LaundryWash", "LaundryDry", "LaundryTraits")
local L = DanTraits_Laundry
local C = DanTraits_LaundryTraitsC
H.expectEvery("minute", "SensitiveSkin")

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
      AddItem = function() end,
    }
  end
  return p
end
local function wear(p, g) p._wornList[#p._wornList + 1] = g; p._carried[#p._carried + 1] = g end
local function wash(item, who, soap)
  return ISWashClothing.complete({ item = item, character = who, noSoap = not soap })
end

-- 1. Sweaty and Cool Customer: the odour rate, nothing else
do
  for _, case in ipairs({ { {}, 1 }, { { "sweaty" }, C.SWEATY }, { { "coolcustomer" }, C.COOL } }) do
    local p = person({ traits = case[1] })
    H.current = p
    local tee = garment(nil, { loc = "base:tshirt" })
    wear(p, tee)
    H.mins(10); H.ten()
    H.near(L.state(tee).o, L.rate(0, 0) * case[2] / 6, 1e-6, "ten quiet minutes x" .. case[2])
  end
  -- worn damp is not sweat: Cool Customer's damp shirt still sours
  local p = person({ traits = { "coolcustomer" } })
  H.current = p
  local damp = garment(nil, { loc = "base:tshirt", wet = 60 })
  wear(p, damp)
  H.mins(10); H.ten()
  assert(L.state(damp).o > 4, "damp wear is the clothes, not the sweat")
end

-- 2. Slob: no moodle, no mood, either way
do
  local p = person({ traits = { "slob" }, unhappy = 10, stress = 0.5 })
  H.current = p
  local tee = garment(nil, { loc = "base:tshirt" })
  wear(p, tee)
  L.state(tee, true).o = 90
  H.ten(); H.mins(60)
  assert(DanTraits_Data(p).lnMoodle == 0, "stale: no moodle shown")
  assert(p._st.unhappy == 10, "stale: no mood")
  L.state(tee).o = 0
  H.ten(); H.mins(60)
  assert(DanTraits_Data(p).lnMoodle == 0 and p._st.unhappy == 10 and p._st.stress == 0.5, "fresh: nothing either")
end

-- 3. Nomad: stale clothes bother them half as much (rate and cap)
do
  local p = person({ traits = { "nomad" }, unhappy = 0 })
  H.current = p
  local tee = garment(nil, { loc = "base:tshirt" })
  wear(p, tee)
  L.state(tee, true).o = 60
  H.ten(); H.mins(60)
  H.near(p._st.unhappy, 0.25, 1e-6, "a quarter point an hour")
  p._st.unhappy = 10.5
  H.mins(30)
  assert(p._st.unhappy == 10.5, "the cap is half too (10)")
end

-- 4. Homemaker: one floor better, odour out without soap, half the wear, Line-Dried x1.5
do
  local p = person({ traits = { "homemaker" } })
  H.current = p
  local shirt = garment({ Torso = { 1, 1 } })
  L.state(shirt, true).o = 70
  wash(shirt, p)
  H.near(shirt.blood.Torso, 0.25, 1e-9, "by hand: the washboard's floor")
  assert(L.state(shirt).o == 0, "no soap: odour all out")
  wear(p, garment(nil, { type = "DanTraits.Washboard", loc = "" }))
  local shirt2 = garment({ Torso = { 1, 1 } })
  wash(shirt2, p, true)
  H.near(shirt2.dirt.Torso, 0.05, 1e-9, "washboard and soap: half of 10%")
  assert(L.canGain(garment({ Torso = { 0.3, 0.3 } }), "hand", false, true), "the menu sees the better floor")
  assert(not L.canGain(garment({ Torso = { 0.3, 0.3 } }), "hand", false, false), "...that a plain hand wash lacks")
  -- wear: half the chance
  H.rollf = 0.007
  local a, b = garment(nil, { cond = 5 }), garment(nil, { cond = 5 })
  L.wear(a, "hand", false); L.wear(b, "hand", true)
  assert(a.cond == 4 and b.cond == 5, "a 0.7% roll wears a plain hand wash (1%), not a Homemaker's (0.5%)")
  H.rollf = 0.99
  -- Line-Dried
  local q = person({ traits = { "homemaker" }, unhappy = 50 })
  H.current = q
  local tee = garment(nil, { loc = "base:tshirt" })
  wear(q, tee)
  L.state(tee, true).sun = true
  H.ten(); H.mins(60)
  H.near(q._st.unhappy, 50 - 1.5, 1e-6, "Line-Dried lifts x1.5")
end

-- 5. Homebody: a line at home marks the garment; Line-Dried x2 when most of it was
do
  local p = person({ traits = { "homebody" }, unhappy = 50 })
  H.current = p
  DanTraits_HomeStrength = function() return 1 end
  DanTraits_HomeAtPlace = function(home, x, y) return x == 5 end
  DanTraits_Data(p).hmHome = { x = 5, y = 5 }
  assert(DanTraits_RunHooks("laundryAtHome", false, p, 5, 5, 0) == true, "the line at home")
  assert(DanTraits_RunHooks("laundryAtHome", false, p, 9, 5, 0) == false, "a line elsewhere")
  local tee = garment(nil, { loc = "base:tshirt", wet = 50 })
  L.lineItem(tee, { rain = 0, rate = 100, airing = true }, 1, true)
  assert(L.state(tee).sun and L.state(tee).sh, "dried at home: both marks")
  wear(p, tee)
  H.ten(); H.mins(60)
  assert(DanTraits_Data(p).lnHomeLine == true, "Line-Dried at home")
  H.near(p._st.unhappy, 50 - 2, 1e-6, "x2 for a Homebody")
  local snap = L.snapshot(tee)
  L.afterHandWash(tee, snap, "hand", true)
  assert(not L.state(tee).sh, "a wash clears it")
  local other = person({ traits = {} })
  assert(DanTraits_RunHooks("laundryAtHome", false, other, 5, 5, 0) == false, "not a Homebody: never")
  DanTraits_HomeStrength, DanTraits_HomeAtPlace = nil, nil
end

-- 6. washing tells the other traits: bleach indoors, blood, the washboard
do
  strain, fumes = {}, {}   -- the stubs take every call; the real ones check the trait
  local p = person({ traits = { "asthma", "badback" }, vanilla = { "base:hemophobic" }, stress = 0 })
  H.current = p
  local bloody = garment({ Torso = { 0.9, 0.2 } })
  bloody.bloodLevel = 90
  wash(bloody, p, true)
  H.near(p._st.stress, C.BLOOD_STRESS, 1e-9, "Fear of Blood: a bloody wash is stressful")
  wash(garment({ Torso = { 0, 0.9 } }), p, true)
  H.near(p._st.stress, C.BLOOD_STRESS, 1e-9, "a muddy one is not")
  assert(#strain == 0, "by hand: the back is fine")
  wear(p, garment(nil, { type = "DanTraits.Washboard", loc = "" }))
  wash(garment({ Torso = { 0.9, 0.9 } }), p, true)
  assert(#strain == 1 and strain[1] == C.BOARD_STRAIN, "a washboard: the back")
  DanTraits_RunHooks("laundryWashed", nil, p, garment(), "bleach", false)
  assert(#fumes == 1 and fumes[1] == C.BLEACH_FUMES, "bleach indoors: fumes")
  p._outside = true
  DanTraits_RunHooks("laundryWashed", nil, p, garment(), "bleach", false)
  assert(#fumes == 1, "outdoors: none")
end

-- 6b. Sensitive Skin: bleaching stings the hands, garment by garment
do
  local p = person({ traits = { "sensitiveskin" } })
  p._st.discomfort = 0
  H.clearHalo()
  DanTraits_RunHooks("laundryWashed", nil, p, garment(), "bleach", false)
  assert(p._st.discomfort == 15 and H.halo[#H.halo] == "UI_DanTraits_SkinBleach", "bleach: 15 discomfort and a notice")
  DanTraits_RunHooks("laundryWashed", nil, p, garment(), "board", false)
  assert(p._st.discomfort == 15, "a washboard: nothing")
end

-- 7. Sensitive Skin: never-washed, damp and musty clothes itch; the start outfit does not
do
  local p = person({ traits = { "sensitiveskin" }, discomfort = 0 })
  H.current = p
  local mine = garment(nil, { loc = "base:tshirt" })
  local pants = garment(nil, { loc = "base:pants" })
  wear(p, mine); wear(p, pants)
  local boots = garment(nil, { loc = "base:shoes" })
  wear(p, boots)
  H.fire("OnCreatePlayer", 0, p)
  assert(DanTraits_Data(p).lnSkinStart, "the start kit ran")
  assert(L.itch(p) == 0, "the clothes you start in")
  H.mins(5)
  assert(p._st.discomfort == 0, "no itch, no discomfort")
  local found = garment(nil, { loc = "base:shirt" })
  wear(p, found)
  assert(L.itch(p) == 1, "a found shirt itches")
  H.clearHalo()
  H.mins(30)
  H.near(p._st.discomfort, C.SKIN_BASE, 1e-9, "to 20")
  assert(H.halo[1] == "UI_DanTraits_SkinItch", "says so, once: " .. tostring(H.halo[1]))
  mine.wet = 40
  L.state(pants).m = true
  assert(L.itch(p) == 4, "damp counts 1, musty 2")
  H.mins(30)
  H.near(p._st.discomfort, C.SKIN_BASE + 3 * C.SKIN_PER, 1e-9, "more with each")
  assert(#H.halo == 1, "no second notice")
  local snap = L.snapshot(found)
  L.afterHandWash(found, snap, "hand", true)
  found.wet = 0
  mine.wet = 0
  L.state(pants).m = nil
  assert(L.itch(p) == 0, "washed and dry: no itch")
  local tip = DanTraits_RunHooks("laundryTooltip", {}, garment(nil, { loc = "base:tshirt" }))
  assert(#tip == 1 and tip[1][1] == "Tooltip_DanTraits_NeverWashed", "the tooltip says never washed")
  assert(#DanTraits_RunHooks("laundryTooltip", {}, mine) == 0, "not on a known clean one")
  assert(#DanTraits_RunHooks("laundryTooltip", {}, boots) == 0, "nor on shoes")
  -- laundry off: nothing
  p._st.discomfort = 0
  found.wet = 80
  SandboxVars.DanTraits = { LaundryEnabled = false }
  H.mins(10)
  assert(p._st.discomfort == 0, "laundry off: no itch")
  SandboxVars.DanTraits = {}
  local q = person({ discomfort = 0 })
  H.current = q
  wear(q, garment(nil, { loc = "base:tshirt" }))
  H.mins(10)
  assert(q._st.discomfort == 0, "without the trait: no itch")
  assert(#DanTraits_RunHooks("laundryTooltip", {}, garment(nil, { loc = "base:tshirt" })) == 0, "nor the line")
end

H.pass("laundrytraits")
