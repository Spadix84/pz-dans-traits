-- Offline test for DanTraits_MS.lua: the heat target from air, body
-- temperature, wetness and a flare; the lag; the tiers and their notices;
-- what each tier does (fatigue, hand stiffness, pain, fumbles, hands giving
-- out); flares and prednisone; baclofen and amantadine; a drink cooling you;
-- the starting bottles.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Arthritis", "MS")
H.expectEvery("minute", "MS")

local near = H.near

-- every named body part gets a stiffness (as in test_arthritis)
local newPlayer = H.factory({ traits = { "ms" } }, function(p)
  local parts = {}
  for name in pairs(BodyPartType) do parts[name] = { _stiff = 0, getStiffness = function(self) return self._stiff end, setStiffness = function(self, v) self._stiff = v end } end
  p._parts = parts
  local bd = p.getBodyDamage()
  bd.getBodyPart = function(_, name) return parts[name] or p._head end
  p.getBodyDamage = function() return bd end
end)

-- 1. the target: cool air nothing; 29 C half of the air's 0.7; 34 C the air's 0.7;
--    soaked takes 60% off the air; a hot body counts in full; a flare x1.5
local p = newPlayer(); H.current = p
local d = DanTraits_Data(p)
H.climate.temp = 20
near(DanTraits_MSHeatTarget(p, d), 0, 1e-9, "cool: nothing")
H.climate.temp = 29; near(DanTraits_MSHeatTarget(p, d), 0.35, 1e-9, "29 C: 0.35")
H.climate.temp = 34; near(DanTraits_MSHeatTarget(p, d), 0.7, 1e-9, "34 C: 0.7")
p._st.wetness = 100; near(DanTraits_MSHeatTarget(p, d), 0.28, 1e-9, "soaked: 0.7 x 0.4"); p._st.wetness = 0
H.climate.temp = 20; p._st.temperature = 37.8; near(DanTraits_MSHeatTarget(p, d), 0.5, 1e-9, "body 37.8: 0.5")
p._st.temperature = 39; near(DanTraits_MSHeatTarget(p, d), 1, 1e-9, "body 39: full")
p._st.temperature = 0.5; near(DanTraits_MSHeatTarget(p, d), 0, 1e-9, "a nonsense body reading is ignored")
H.climate.temp = 29; d.msFlareH = 10; near(DanTraits_MSHeatTarget(p, d), 0.525, 1e-9, "flare x1.5"); d.msFlareH = nil

-- 2. the lag: a thirtieth a minute up, a twentieth down, twice as fast wet; notices per tier
H.climate.temp = 40; H.clearHalo()
H.mins(9); near(d.msHeat, 0.3, 1e-9, "nine minutes up: 0.3")
assert(H.halo[#H.halo] == "UI_DanTraits_MSHeat1", "warm notice")
H.mins(7); near(d.msHeat, 16 / 30, 1e-9, "sixteen minutes: past 0.5")
assert(H.halo[#H.halo] == "UI_DanTraits_MSHeat2", "hot notice")
H.mins(10); near(d.msHeat, 0.7, 1e-9, "air alone tops out at 0.7")
H.mins(10); near(d.msHeat, 0.7, 1e-9, "and stays there")
H.climate.temp = 20; H.mins(4); near(d.msHeat, 0.5, 1e-9, "cooling a twentieth a minute")
p._st.wetness = 50; H.mins(1); near(d.msHeat, 0.4, 1e-9, "wet: twice as fast"); p._st.wetness = 0
H.clearHalo(); H.mins(10)
assert(d.msHeat == nil and H.halo[#H.halo] == "+UI_DanTraits_MSCooled", "cooled: cleared, a good notice")

-- 3. hot: hand stiffness, pain floor, fumbles; legs always a little stiff
d.msHeat = 0.625; d.msTier = 2; H.climate.temp = 32   -- target 0.56: drifts down slowly
for _, part in pairs(p._parts) do part._stiff = 0 end   -- the game eases stiffness itself; start clean
H.minute()
local load = d.msHeat
near(p._parts.Hand_L._stiff, 55 * (load - 0.25) / 0.75, 1e-9, "hands stiff with the heat")
assert(p._parts.Head._stiff == 0, "the head is left alone")
near(p._parts.LowerLeg_L._stiff, 8, 1e-9, "legs: the everyday floor")
near(d.painHurting.ms, 20 + 40 * (load - 0.5) / 0.5, 1e-6, "pain floor between 20 and 60")
near(DanTraits_SwingDropChance(p), 15 * (load - 0.25) / 0.75, 1e-9, "a swing can throw the weapon")
assert(#p._dropped == 0, "hot is not yet overheated: nothing given out")

-- 4. overheated: the hands give out (5% a minute); warm is no fumble, no pain
d.msHeat = 1; H.climate.temp = 60; p._st.temperature = 40; H.clearHalo()
H.rollf = 0.04; H.minute(); H.rollf = 0.99
assert(#p._dropped == 1 and H.halo[#H.halo] == "UI_DanTraits_MSHandsGiveOut", "a roll under 5%: hands give out")
near(d.painHurting.ms, 60, 1e-9, "severe pain at full load")
local w = newPlayer(); H.current = w
local wd = DanTraits_Data(w)
wd.msHeat = 0.3; H.climate.temp = 30; p._st.temperature = 0
H.minute(w)
assert(not (wd.painHurting and wd.painHurting.ms), "warm: no pain floor")
assert(DanTraits_SwingDropChance(w) > 0 and DanTraits_SwingDropChance(w) < 2, "warm: barely a fumble")
local before = w._st.fatigue
H.minute(w)
assert(w._st.fatigue > before, "tiring")
near(DanTraits_RunHooks("enduranceRegen", 1, w, wd), 1 - 0.5 * wd.msHeat, 1e-9, "endurance comes back slower")

-- 5. a drink cools: 0.4 a litre
wd.msHeat = 0.6
DanTraits_RunHooks("drink", nil, w, nil, 0.5)
near(wd.msHeat, 0.4, 1e-9, "half a litre: 0.2 off")

-- 6. everyday fatigue awake, cut by amantadine; none asleep
local f = newPlayer(); H.current = f
local fd = DanTraits_Data(f)
H.climate.temp = 15
H.minute(f); near(f._st.fatigue, 0.0002, 1e-9, "a fifth faster to tire")
DanTraits_RunHooks("pill", nil, f, "Amantadine")
near(fd.msAman, 1, 1e-9, "a pill: level 1")
f._st.fatigue = 0; H.minute(f); near(f._st.fatigue, 0.00008, 1e-7, "amantadine: x0.4")
assert(f._st.thirst > 0, "amantadine side effect: dry mouth")
f._st.fatigue = 0; f._asleep = true; H.minute(f); near(f._st.fatigue, 0, 1e-12, "asleep: nothing"); f._asleep = false

-- 7. flares: about one a month, more with stress or fever; prednisone burns it 3x faster
near(DanTraits_MSFlareRate(f, fd), 1 / 720, 1e-12, "base: once a month")
f._st.stress = 0.5; near(DanTraits_MSFlareRate(f, fd), 1.5 / 720, 1e-12, "stress x1.5"); f._st.stress = 0
DanTraits_InfectionFever = function() return 1 end
near(DanTraits_MSFlareRate(f, fd), 3 / 720, 1e-12, "fever x3"); DanTraits_InfectionFever = nil
H.clearHalo()
DanTraits_ExtraCommands.ms(f, { "flare" })
assert((fd.msFlareH or 0) >= 72 and fd.msFlareH <= 144 and H.halo[#H.halo] == "UI_DanTraits_MSFlare", "a flare of 3 to 6 days")
fd.msFlareH = 10
f._st.fatigue = 0; H.minute(f)
near(f._st.fatigue, (0.0002 + 0.0004) * 0.4, 1e-7, "flare fatigue, still on amantadine")
near(f._parts.LowerLeg_R._stiff, 35, 1e-9, "flare: legs stiff")
near(f._parts.Hand_R._stiff, 20, 1e-9, "flare: hands weak")
near(DanTraits_RunHooks("enduranceRegen", 1, f, fd), 0.7, 1e-9, "flare: endurance x0.7")
local h = fd.msFlareH
H.minute(f); near(h - fd.msFlareH, 1 / 60, 1e-9, "an hour an hour")
DanTraits_RunHooks("pill", nil, f, "Prednisone")
h = fd.msFlareH; H.minute(f); near(h - fd.msFlareH, 3 / 60, 1e-6, "prednisone: three hours an hour")
local hunger = f._st.hunger; H.minute(f); assert(f._st.hunger > hunger, "prednisone makes you hungry")
fd.msFlareH = 0.01; H.clearHalo(); H.minute(f)
assert(fd.msFlareH == nil and H.halo[#H.halo] == "+UI_DanTraits_MSFlareEnds", "the flare passes")

-- 8. baclofen halves the stiffness, heat's and legs' alike
local b = newPlayer(); H.current = b
local bd = DanTraits_Data(b)
DanTraits_RunHooks("pill", nil, b, "Baclofen")
bd.msHeat = 1; H.climate.temp = 60; b._st.temperature = 40
H.minute(b)
near(b._parts.Hand_L._stiff, 27.5, 1e-9, "full heat on baclofen: 55 x 0.5")
near(b._parts.UpperLeg_L._stiff, 4, 1e-9, "legs on baclofen: 8 x 0.5")
local nb = newPlayer({ traits = {} }); H.current = nb
DanTraits_RunHooks("pill", nil, nb, "Baclofen"); H.climate.temp = 15; nb._st.temperature = 0
H.minute(); near(nb._st.fatigue, 0.0001, 1e-9, "baclofen side effect: drowsy, even without MS")
H.current = b

-- 9. the levels decay: baclofen halves in 12 hours, then a wearing-off notice
H.climate.temp = 15; b._st.temperature = 0; bd.msHeat = nil
bd.msBac = 1; H.mins(720); near(bd.msBac, 0.5, 1e-3, "halved in 12 hours")
H.clearHalo(); H.mins(10)
local lapsed = false
for _, t in ipairs(H.halo) do if t == "UI_DanTraits_MSBacLapse" then lapsed = true end end
assert(lapsed, "wearing off: a notice")

-- 10. without the trait: nothing (but a pill still sets a level)
local none = newPlayer({ traits = {} }); H.current = none
local nd = DanTraits_Data(none)
H.climate.temp = 60; nd.msHeat = 1
H.minute(none)
assert(nd.msHeat == nil and none._parts.Hand_L._stiff == 0 and none._st.fatigue == 0, "no trait: no MS")
near(DanTraits_SwingDropChance(none), 0, 1e-9, "no trait: no fumble")
H.climate.temp = 20

-- 11. the starting bottles, once
local k = newPlayer(); H.current = k
H.fire("OnCreatePlayer", 0, k); H.fire("OnCreatePlayer", 0, k)
assert(#k._inv == 2, "two bottles, once")

-- 12. the moodles
H.load("Moodles")
local function level(name, who, data) return DanTraits_MoodleLevels(who, data)[name] end
local m = newPlayer(); local md = DanTraits_Data(m)
assert(level("MSHeat", m, md) == 0 and level("MSFlare", m, md) == 0, "nothing to show")
md.msHeat = 0.3; assert(level("MSHeat", m, md) == 1, "heat sensitive")
md.msHeat = 0.6; assert(level("MSHeat", m, md) == 2, "too hot")
md.msHeat = 0.9; assert(level("MSHeat", m, md) == 3, "overheated")
md.msFlareH = 5; assert(level("MSFlare", m, md) == 2, "a flare")
md.msPred = 1; assert(level("MSFlare", m, md) == 1, "a flare on prednisone")
assert(DanTraits_IsMSMed({ getFullType = function() return "DanTraits.Baclofen" end }), "baclofen is an MS pill")
assert(not DanTraits_IsMSMed({ getFullType = function() return "Base.PillsBeta" end }), "beta blockers are not")

H.pass()
