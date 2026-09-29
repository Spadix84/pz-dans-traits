-- Offline test for DanTraits_Arthritis.lua: the joint factor from weather,
-- the stiffness floor on hands and legs, the combat-speed scaling, and the
-- fumble chance carried over from Fumbler with a flare on top.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Arthritis")
H.expectHooks("OnWeaponSwing", "EveryOneMinute", "OnPlayerUpdate")

-- every named body part gets a stiffness; the joint parts are the ones the trait touches
local newPlayer = H.factory({ traits = { "arthritis" } }, function(p)
  local parts = {}
  for name in pairs(BodyPartType) do parts[name] = { _stiff = 0, getStiffness = function(self) return self._stiff end, setStiffness = function(self, v) self._stiff = v end } end
  p._parts = parts
  p.getBodyDamage = function() return { getBodyPart = function(_, name) return parts[name] end } end
end)
local halo, near = H.halo, H.near
local minute, frame, swing = H.on("EveryOneMinute"), H.on("OnPlayerUpdate"), H.on("OnWeaponSwing")

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
near(DanTraits_SwingDropChance(g), 5, 1e-9, "1 + 4 flare")
H.rng = { 49 }; swing(g, { name = "bat" }); assert(#g._dropped == 1 and halo[#halo] == "UI_DanTraits_FumblerDrop", "roll 49 < 50: dropped")
H.rng = { 50 }; swing(g, { name = "bat" }); assert(#g._dropped == 1, "roll 50: kept")
local none = newPlayer({ traits = {} }); H.current = none
near(DanTraits_SwingDropChance(none), 0, 1e-9, "no trait: never")
DanTraits_ExtraFumble = function() return 3 end
near(DanTraits_SwingDropChance(none), 3, 1e-9, "other traits' shakiness still applies")
DanTraits_ExtraFumble = nil
minute(); assert(none._parts.Hand_L._stiff == 0, "no trait: no stiffness")

H.pass()
