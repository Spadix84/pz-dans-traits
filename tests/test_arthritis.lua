-- Offline test for DanTraits_Arthritis.lua: the joint factor from weather,
-- the stiffness floor on hands and legs, the combat-speed scaling, and the
-- fumble chance carried over from Fumbler with a flare on top, the weak swing
-- a slip makes and when a slip throws the weapon instead.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Arthritis")
H.expectHooks("OnWeaponSwing", "OnPlayerAttackFinished", "OnCreatePlayer")
H.expectEvery("minute", "Arthritis")
H.expectEvery("frame", "Arthritis")

-- every named body part gets a stiffness; the joint parts are the ones the trait touches
local newPlayer = H.factory({ traits = { "arthritis" } }, function(p)
  local parts = {}
  for name in pairs(BodyPartType) do parts[name] = { _stiff = 0, getStiffness = function(self) return self._stiff end, setStiffness = function(self, v) self._stiff = v end } end
  p._parts = parts
  p.getBodyDamage = function() return { getBodyPart = function(_, name) return parts[name] end } end
end)
local halo, near = H.halo, H.near
local minute, frame, swing = H.minute, H.frame, H.on("OnWeaponSwing")

-- 1. the joint factor: warm and dry 0; 7.5 C half; 0 C full; rain outdoors 0.7 x intensity; soaked 0.7; humid 0.35
local p = newPlayer(); H.current = p
near(DanTraits_ArthritisJoint(p), 0, 1e-9, "warm and dry")
H.climate.temp = 7.5; near(DanTraits_ArthritisJoint(p), 0.5, 1e-9, "7.5 C: half")
H.climate.temp = -5; near(DanTraits_ArthritisJoint(p), 1, 1e-9, "freezing: full"); H.climate.temp = 20
H.climate.rain = 1; near(DanTraits_ArthritisJoint(p), 0, 1e-9, "rain, but indoors")
p._outside = true; near(DanTraits_ArthritisJoint(p), 0.7, 1e-9, "rain outdoors: 0.7"); p._outside = false; H.climate.rain = 0
p._st.wetness = 100; near(DanTraits_ArthritisJoint(p), 0.7, 1e-9, "soaked: 0.7"); p._st.wetness = 0
H.climate.humidity = 0.9; near(DanTraits_ArthritisJoint(p), 0.35, 1e-9, "humid: 0.35"); H.climate.humidity = 0.5

-- 1b. warm clothes: the cold is read from the joints' skin (the game's thermoregulator, which clothing feeds); the air only without a reading
local JOINT_NAMES = { "Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R", "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }
for _, name in ipairs(JOINT_NAMES) do p._parts[name].getSkinTemperature = function(self) return self._skin or 0 end end
local function skin(t) for _, name in ipairs(JOINT_NAMES) do p._parts[name]._skin = t end end
DanTraits_Data(p)
H.climate.temp = -5
skin(33); near(DanTraits_ArthritisJoint(p), 0, 1e-9, "freezing air, joints warm under good clothes: no cold at all")
near(p._md.DanTraits.artSkin, 33, 1e-9, "the mean skin temperature is kept for tuning")
skin(28); near(DanTraits_ArthritisJoint(p), 0.5, 1e-9, "skin 28: half")
skin(23); near(DanTraits_ArthritisJoint(p), 1, 1e-9, "skin 23: everything")
skin(28); p._parts.Hand_L._skin = 23; p._parts.Hand_R._skin = 23
near(DanTraits_ArthritisJoint(p), (6 * 0.5 + 2 * 1) / 8, 1e-9, "the joints average: bare hands count against warm legs")
p._parts.Head._skin = 10; near(DanTraits_ArthritisJoint(p), (6 * 0.5 + 2 * 1) / 8, 1e-9, "a cold head is not a joint")
skin(0); near(DanTraits_ArthritisJoint(p), 1, 1e-9, "no skin reading: the air decides, as before")
near(p._md.DanTraits.artSkin, 0, 1e-9, "and no mean is reported")
H.climate.temp = 20

-- 2. the stiffness floor: 12 on the eight joint parts warm and dry, 45 in a full flare; a higher value is left; the head is untouched
minute()
assert(p._parts.Hand_L._stiff == 12 and p._parts.LowerLeg_R._stiff == 12 and p._parts.Head._stiff == 0, "floor 12 on joints only")
p._parts.Hand_L._stiff = 30; minute(); assert(p._parts.Hand_L._stiff == 30, "exercise stiffness above the floor is left alone")
H.climate.temp = -5; minute()
assert(p._parts.Hand_L._stiff == 45 and p._parts.UpperLeg_L._stiff == 45, "full flare: 45")
assert(halo[#halo] == "UI_DanTraits_ArthritisFlare", "flare notice on crossing 0.5")
local n = #halo; minute(); assert(#halo == n, "notice once per flare")
H.climate.temp = 20; minute(); assert(p._md.DanTraits.artJoint == 0, "factor tracked")

-- 2b. relief: painkillers halve the weather's share while in the system, prednisone cuts it to a third; the stronger counts
local eff = {}
DanTraits_MedEffect = function(who, id) return eff[id] or 0 end
near(DanTraits_ArthritisRelief(p), 1, 1e-9, "nothing in the system: x1")
H.climate.temp = -5
local function floors() for _, part in pairs(p._parts) do part._stiff = 0 end end
eff.painkillers = 1; floors(); minute()
near(p._md.DanTraits.artJoint, 0.5, 1e-9, "painkillers: a full flare felt as half")
near(p._md.DanTraits.artWeather, 1, 1e-9, "the weather itself unchanged")
near(p._md.DanTraits.artRelief, 0.5, 1e-9, "and the factor recorded")
near(p._parts.Hand_L._stiff, 12 + 33 * 0.5, 1e-9, "stiffness floor 28.5, not 45")
eff.prednisone = 1; floors(); minute()
near(p._md.DanTraits.artJoint, 0.35, 1e-9, "prednisone as well: a third (the stronger counts, no stacking)")
near(p._parts.Hand_L._stiff, 12 + 33 * 0.35, 1e-9, "floor 23.55")
eff.painkillers = 0; floors(); minute()
near(p._md.DanTraits.artJoint, 0.35, 1e-9, "prednisone alone: still a third")
eff = {}; floors(); minute()
near(p._md.DanTraits.artJoint, 1, 1e-9, "worn off: the full flare")
DanTraits_MedEffect = nil
H.climate.temp = 20; minute()

-- 3. combat speed: scaled once per new value, 15% slower warm, 30% in a full flare
p._cs = 1.0; frame(p); near(p._cs, 0.85, 1e-9, "x 0.85")
frame(p); near(p._cs, 0.85, 1e-9, "not scaled again")
p._cs = 1.0; p._md.DanTraits.artJoint = 1; frame(p); near(p._cs, 0.70, 1e-9, "full flare: x 0.70")
p._cs = 0; frame(p); assert(p._cs == 0, "zero is left alone")

-- 4. grip: 1% calm; panic, pain, fatigue add as before; a full flare adds 4
local g = newPlayer(); H.current = g
near(DanTraits_FumbleChance(g), 1, 1e-9, "calm: 1%")
g._st.panic = 100; g._st.pain = 100; g._st.fatigue = 1; near(DanTraits_FumbleChance(g), 18, 1e-9, "terrified, hurt, exhausted: 18%")
g._md.DanTraits = { artJoint = 1 }; near(DanTraits_FumbleChance(g), 22, 1e-9, "and flaring: 22%")
g._st.panic, g._st.pain, g._st.fatigue = 0, 0, 0
near(DanTraits_GripSlipChance(g), 5, 1e-9, "slip: 1 + 4 flare")
near(DanTraits_SwingDropChance(g), 0, 1e-9, "Arthritis alone never throws the weapon outright")

-- a weapon whose damage can be read and set, with mod data
local function weapon(min, max)
  local w = { _min = min, _max = max, _md = {} }
  w.getMinDamage = function(self) return self._min end
  w.getMaxDamage = function(self) return self._max end
  w.setMinDamage = function(self, v) self._min = v end
  w.setMaxDamage = function(self, v) self._max = v end
  w.getModData = function(self) return self._md end
  return w
end

-- 5. a slip out of a flare: the swing is weak (35% damage) until the attack finishes; nothing dropped
g._md.DanTraits.artJoint = 0.2   -- a mild flare: slip 1 + 0.8
local bat = weapon(1.0, 2.0)
H.clearHalo()
H.rng = { 17 }; swing(g, bat)
assert(#g._dropped == 0 and halo[#halo] == "UI_DanTraits_GripSlip", "roll 17 < 18: slipped, kept")
near(bat._min, 0.35, 1e-9, "min damage x 0.35"); near(bat._max, 0.70, 1e-9, "max damage x 0.35")
assert(bat._md.DanTraitsSlip.min == 1.0 and bat._md.DanTraitsSlip.max == 2.0, "originals kept on the weapon")
H.on("OnPlayerAttackFinished")(g, bat)
assert(bat._min == 1.0 and bat._max == 2.0 and bat._md.DanTraitsSlip == nil, "attack finished: damage back")
H.rng = { 18 }; swing(g, bat); assert(bat._min == 1.0 and #halo == 1, "roll 18: a clean swing")

-- 6. if the attack never reports finishing, the damage comes back after three seconds
H.now = 1000
H.rng = { 0 }; swing(g, bat); near(bat._min, 0.35, 1e-9, "weakened")
H.now = 3999; frame(g); near(bat._min, 0.35, 1e-9, "2.999 s: still weak")
H.now = 4000; frame(g); assert(bat._min == 1.0 and bat._max == 2.0, "3 s: put back")
-- a second slip before the first is put back keeps the true originals
H.rng = { 0 }; swing(g, bat); H.rng = { 0 }; swing(g, bat)
assert(bat._md.DanTraitsSlip.min == 1.0, "originals not overwritten by the weak values")
H.on("OnPlayerAttackFinished")(g, bat); assert(bat._min == 1.0, "back after a double slip")
-- left weak by a save mid-swing: the next swing puts it right first
local saved = weapon(0.35, 0.7); saved._md.DanTraitsSlip = { min = 1.0, max = 2.0 }
H.rng = { 999 }; swing(g, saved); assert(saved._min == 1.0 and saved._max == 2.0 and saved._md.DanTraitsSlip == nil, "leftover weakening undone")

-- 7. in a bad flare (0.5 and over) one slip in three throws the weapon; the sandbox option stops it
g._md.DanTraits.artJoint = 1
H.rng = { 0, 32 }; swing(g, weapon(1, 2)); assert(#g._dropped == 1 and halo[#halo] == "UI_DanTraits_FumblerDrop", "full flare, 32 < 33: thrown")
local kept = weapon(1, 2)
H.rng = { 0, 33 }; swing(g, kept); assert(#g._dropped == 1 and kept._min == 0.35, "33: weak swing instead")
H.on("OnPlayerAttackFinished")(g, kept)
SandboxVars = { DanTraits = { ArthritisWeaponDrop = false } }
local safe = weapon(1, 2)
H.rng = { 0, 0 }; swing(g, safe); assert(#g._dropped == 1 and safe._min == 0.35, "option off: never thrown, weak swing")
H.on("OnPlayerAttackFinished")(g, safe)
SandboxVars = nil
g._md.DanTraits.artJoint = 0.49
local mild = weapon(1, 2)
H.rng = { 0, 0 }; swing(g, mild); assert(#g._dropped == 1 and mild._min == 0.35, "under a bad flare: never thrown")
H.on("OnPlayerAttackFinished")(g, mild)

-- 8. other traits' shakes still throw the weapon outright, before any slip roll
local none = newPlayer({ traits = {} }); H.current = none
near(DanTraits_SwingDropChance(none), 0, 1e-9, "no trait: never")
near(DanTraits_GripSlipChance(none), 0, 1e-9, "no trait: no slip")
DanTraits_ExtraFumble = function() return 3 end
near(DanTraits_SwingDropChance(none), 3, 1e-9, "other traits' shakiness still applies")
H.rng = { 29 }; swing(none, weapon(1, 2)); assert(#none._dropped == 1, "29 < 30: thrown by the shakes")
DanTraits_ExtraFumble = nil
minute(); assert(none._parts.Hand_L._stiff == 0, "no trait: no stiffness")

-- 9. a new Arthritis character starts with a bottle of painkillers, once; not with Starting Medication off
local function bottles(who)
  local n = 0
  local items = who:getInventory():getItems()
  for i = 0, items:size() - 1 do if items:get(i):getFullType() == "Base.Pills" then n = n + 1 end end
  return n
end
SandboxVars = SandboxVars or {}; SandboxVars.DanTraits = SandboxVars.DanTraits or {}
local fresh = newPlayer({ hours = 0 })
H.fire("OnCreatePlayer", 0, fresh)
assert(bottles(fresh) == 1 and fresh._md.DanTraits.artKitGiven == true, "one bottle at the start")
H.fire("OnCreatePlayer", 0, fresh)
assert(bottles(fresh) == 1, "not again on a later load")
local old = newPlayer({ hours = 40 })
H.fire("OnCreatePlayer", 0, old)
assert(bottles(old) == 0, "an existing character (an old save) gets nothing")
SandboxVars.DanTraits.StartingMedication = false
local none = newPlayer({ hours = 0 })
H.fire("OnCreatePlayer", 0, none)
assert(bottles(none) == 0 and none._md.DanTraits.artKitGiven == true, "Starting Medication off: no bottle")
SandboxVars.DanTraits.StartingMedication = nil
local plain = H.player({ hours = 0 })
H.fire("OnCreatePlayer", 0, plain)
assert(bottles(plain) == 0, "no trait: nothing")

H.pass()
