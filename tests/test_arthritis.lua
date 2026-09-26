-- Offline test for DanTraits_Arthritis.lua: the joint factor from weather,
-- the stiffness floor on hands and legs, the combat-speed scaling, and the
-- fumble chance carried over from Fumbler with a flare on top.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = { INTOXICATION = "intox", STRESS = "stress", PAIN = "pain", PANIC = "panic", FATIGUE = "fatigue", WETNESS = { getMaximumValue = function() return 100 end } }
BodyPartType = { Hand_L = "Hand_L", Hand_R = "Hand_R", ForeArm_L = "ForeArm_L", ForeArm_R = "ForeArm_R", UpperLeg_L = "UpperLeg_L", UpperLeg_R = "UpperLeg_R", LowerLeg_L = "LowerLeg_L", LowerLeg_R = "LowerLeg_R", Head = "Head" }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = { arthritis = "arthritis" }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
local rng = {}
function ZombRand(a, b) local v = table.remove(rng, 1); if v == nil then v = 0 end; return v end
local climate = { temp = 20, rain = 0, humidity = 0.5 }
function getClimateManager() return { getAirTemperatureForCharacter = function() return climate.temp end, getRainIntensity = function() return climate.rain end, getHumidity = function() return climate.humidity end } end

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Arthritis" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.OnWeaponSwing and handlers.EveryOneMinute and handlers.OnPlayerUpdate, "hooks in place")

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or { "arthritis" }) do traits[t] = true end
  local st = { pain = o.pain or 0, panic = o.panic or 0, fatigue = o.fatigue or 0, wetness = o.wet or 0 }
  local md, parts, dropped = {}, {}, {}
  for name in pairs(BodyPartType) do parts[name] = { _stiff = 0, getStiffness = function(self) return self._stiff end, setStiffness = function(self, v) self._stiff = v end } end
  local p = { hasTrait = function(_, t) return traits[t] == true end, isDead = function() return false end,
    isOutside = function(self) return self._outside end, getModData = function() return md end,
    getStats = function() return { get = function(_, k) if k == CharacterStat.WETNESS then return st.wetness end return st[k] end, set = function(_, k, v) st[k] = v end } end,
    getBodyDamage = function() return { getBodyPart = function(_, name) return parts[name] end } end,
    getCombatSpeed = function(self) return self._cs end, setCombatSpeed = function(self, v) self._cs = v end,
    getPrimaryHandItem = function() return { name = "bat" } end, getCurrentSquare = function() return { AddWorldInventoryItem = function(_, it) dropped[#dropped+1] = it end } end,
    removeFromHands = function() end, getInventory = function() return { Remove = function() end } end,
    _st = st, _md = md, _parts = parts, _dropped = dropped, _outside = false, _cs = 1.0 }
  return p
end
local current
function getSpecificPlayer() return current end
local minute, frame, swing = handlers.EveryOneMinute, handlers.OnPlayerUpdate, handlers.OnWeaponSwing
local function near(a, b, eps, msg) assert(math.abs(a - b) <= eps, msg .. ": expected " .. b .. ", got " .. a) end

-- 1. the joint factor: warm and dry 0; 7.5 C half; 0 C full; rain outdoors 0.7 x intensity; soaked 0.7; humid 0.35
local p = makePlayer(); current = p
near(DanTraits_ArthritisJoint(p), 0, 1e-9, "warm and dry")
climate.temp = 7.5; near(DanTraits_ArthritisJoint(p), 0.5, 1e-9, "7.5 C: half")
climate.temp = -5; near(DanTraits_ArthritisJoint(p), 1, 1e-9, "freezing: full"); climate.temp = 20
climate.rain = 1; near(DanTraits_ArthritisJoint(p), 0, 1e-9, "rain, but indoors")
p._outside = true; near(DanTraits_ArthritisJoint(p), 0.7, 1e-9, "rain outdoors: 0.7"); p._outside = false; climate.rain = 0
p._st.wetness = 100; near(DanTraits_ArthritisJoint(p), 0.7, 1e-9, "soaked: 0.7"); p._st.wetness = 0
climate.humidity = 0.9; near(DanTraits_ArthritisJoint(p), 0.35, 1e-9, "humid: 0.35"); climate.humidity = 0.5

-- 2. the stiffness floor: 12 on the eight joint parts warm and dry, 45 in a full flare; a higher value is left; the head is untouched
minute()
assert(p._parts.Hand_L._stiff == 12 and p._parts.LowerLeg_R._stiff == 12 and p._parts.Head._stiff == 0, "floor 12 on joints only")
p._parts.Hand_L._stiff = 30; minute(); assert(p._parts.Hand_L._stiff == 30, "exercise stiffness above the floor is left alone")
climate.temp = -5; minute()
assert(p._parts.Hand_L._stiff == 45 and p._parts.UpperLeg_L._stiff == 45, "full flare: 45")
assert(halo[#halo] == "UI_DanTraits_ArthritisFlare", "flare notice on crossing 0.5")
local n = #halo; minute(); assert(#halo == n, "notice once per flare")
climate.temp = 20; minute(); assert(p._md.DanTraits.artJoint == 0, "factor tracked")

-- 3. combat speed: scaled once per new value, 15% slower warm, 30% in a full flare
p._cs = 1.0; frame(p); near(p._cs, 0.85, 1e-9, "x 0.85")
frame(p); near(p._cs, 0.85, 1e-9, "not scaled again")
p._cs = 1.0; p._md.DanTraits.artJoint = 1; frame(p); near(p._cs, 0.70, 1e-9, "full flare: x 0.70")
p._cs = 0; frame(p); assert(p._cs == 0, "zero is left alone")

-- 4. grip: 1% calm; panic, pain, fatigue add as before; a full flare adds 4
local g = makePlayer(); current = g
near(DanTraits_FumbleChance(g), 1, 1e-9, "calm: 1%")
g._st.panic = 100; g._st.pain = 100; g._st.fatigue = 1; near(DanTraits_FumbleChance(g), 18, 1e-9, "terrified, hurt, exhausted: 18%")
g._md.DanTraits = { artJoint = 1 }; near(DanTraits_FumbleChance(g), 22, 1e-9, "and flaring: 22%")
g._st.panic, g._st.pain, g._st.fatigue = 0, 0, 0
near(DanTraits_SwingDropChance(g), 5, 1e-9, "1 + 4 flare")
rng = { 49 }; swing(g, { name = "bat" }); assert(#g._dropped == 1 and halo[#halo] == "UI_DanTraits_FumblerDrop", "roll 49 < 50: dropped")
rng = { 50 }; swing(g, { name = "bat" }); assert(#g._dropped == 1, "roll 50: kept")
local none = makePlayer({ traits = {} }); current = none
near(DanTraits_SwingDropChance(none), 0, 1e-9, "no trait: never")
DanTraits_ExtraFumble = function() return 3 end
near(DanTraits_SwingDropChance(none), 3, 1e-9, "other traits' shakiness still applies")
DanTraits_ExtraFumble = nil
minute(); assert(none._parts.Hand_L._stiff == 0, "no trait: no stiffness")

print("test_arthritis: all passed")
