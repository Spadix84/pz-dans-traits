-- Offline test for DanTraits_Arthritis.lua: the joint factor from weather,
-- the stiffness floor on hands and legs, the combat-speed scaling, and the
-- fumble chance carried over from Fumbler with a flare on top, the weak swing
-- a slip makes and when a slip throws the weapon instead.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Arthritis")
H.expectHooks("OnWeaponSwing", "OnPlayerAttackFinished")
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

-- 2. the stiffness floor: 12 on the eight joint parts warm and dry, 45 in a full flare; a higher value is left; the head is untouched
minute()
assert(p._parts.Hand_L._stiff == 12 and p._parts.LowerLeg_R._stiff == 12 and p._parts.Head._stiff == 0, "floor 12 on joints only")
p._parts.Hand_L._stiff = 30; minute(); assert(p._parts.Hand_L._stiff == 30, "exercise stiffness above the floor is left alone")
H.climate.temp = -5; minute()
assert(p._parts.Hand_L._stiff == 45 and p._parts.UpperLeg_L._stiff == 45, "full flare: 45")
assert(halo[#halo] == "UI_DanTraits_ArthritisFlare", "flare notice on crossing 0.5")
local n = #halo; minute(); assert(#halo == n, "notice once per flare")
H.climate.temp = 20; minute(); assert(p._md.DanTraits.artJoint == 0, "factor tracked")

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

H.pass()
