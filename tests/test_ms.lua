-- Offline test for DanTraits_MS.lua: the heat target from air, body
-- temperature, wetness and a flare; the lag; the tiers and their notices;
-- what each tier does (fatigue, hand stiffness, pain, fumbles, hands giving
-- out); flares and prednisone; baclofen and amantadine; a drink from a tap cooling you;
-- the starting bottles; cooling off taking back MS's stiffness and pain; the
-- pills on the shared medication system (build-up, old saves).
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
-- the game's drink-from-a-tap action, as far as MS's wrap needs it
ISTakeWaterAction = { transferFluid = function() end }
H.load("Arthritis", "Meds", "Spoons", "MS")
H.expectEvery("minute", "MS"); H.expectEvery("minute", "Spoons")

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
H.climate.temp = 20; p._st.temperature = 37.8; near(DanTraits_MSHeatTarget(p, d), (37.88 - 37.2) / 1.2, 1e-9, "body 37.8 counts as 37.88 (the rise over 37 x1.1): 0.57")
p._st.temperature = 39; near(DanTraits_MSHeatTarget(p, d), 1, 1e-9, "body 39: full")
p._st.temperature = 0.5; near(DanTraits_MSHeatTarget(p, d), 0, 1e-9, "a nonsense body reading is ignored")
H.climate.temp = 29; d.msFlareH = 10; near(DanTraits_MSHeatTarget(p, d), 0.525, 1e-9, "flare x1.5"); d.msFlareH = nil

-- 2. the lag: a thirtieth a minute up x1.1 (MS warms up faster), a twentieth down, twice as fast wet; notices per tier
H.climate.temp = 40; H.clearHalo()
H.mins(9); near(d.msHeat, 0.33, 1e-9, "nine minutes up: 0.33")
assert(H.halo[#H.halo] == "UI_DanTraits_MSHeat1", "warm notice")
H.mins(7); near(d.msHeat, 16 * 1.1 / 30, 1e-9, "sixteen minutes: past 0.5")
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
near(p._parts.Hand_L._stiff, 20 + 35 * (load - 0.5) / 0.5, 1e-9, "hands stiff with the heat: 20 at hot to 55")
assert(p._parts.Head._stiff == 0, "the head is left alone")
near(p._parts.LowerLeg_L._stiff, 8, 1e-9, "legs: the everyday floor")
near(d.painHurting.ms, 12 + 23 * (load - 0.5) / 0.5, 1e-6, "pain floor between 12 and 35")
near(DanTraits_SwingDropChance(p), 5 + 10 * (load - 0.5) / 0.5, 1e-9, "a swing can throw the weapon: 5% at hot to 15%")
assert(#p._dropped == 0, "hot is not yet overheated: nothing given out")

-- 4. overheated: the hands give out (5% a minute); warm is no fumble, no pain
d.msHeat = 1; H.climate.temp = 60; p._st.temperature = 40; H.clearHalo()
H.rollf = 0.04; H.minute(); H.rollf = 0.99
assert(#p._dropped == 1 and H.halo[#H.halo] == "UI_DanTraits_MSHandsGiveOut", "a roll under 5%: hands give out")
near(d.painHurting.ms, 35, 1e-9, "full load: a floor of 35 (the stiff hands add the rest)")
near(p._parts.Hand_L._stiff, 55, 1e-9, "full load: hands at 55")
-- asleep or in a vehicle the hands hold on, whatever the roll
H.rollf = 0.04
p._asleep = true; H.minute(); p._asleep = false
assert(#p._dropped == 1, "asleep: nothing dropped")
p.getVehicle = function() return {} end; H.minute(); p.getVehicle = nil
assert(#p._dropped == 1, "in a vehicle: nothing dropped on the road")
H.minute(); H.rollf = 0.99
assert(#p._dropped == 2, "awake and on foot again: they can give out")
local w = newPlayer(); H.current = w
local wd = DanTraits_Data(w)
wd.msHeat = 0.3; H.climate.temp = 30; w._st.temperature = 0
H.minute(w)
assert(not (wd.painHurting and wd.painHurting.ms), "warm: no pain floor")
near(DanTraits_SwingDropChance(w), 0, 1e-9, "warm: no fumble")
near(w._parts.Hand_L._stiff, 0, 1e-9, "warm: the hands are fine")
DanTraits_SpoonsSet(w, 6); local load = wd.msHeat   -- under the cap, so the idle rest shows; the load Spoons reads this minute
H.minute(w)
near(6 - wd.spPool, (1 / 160) * (1 + load) - 0.01, 1e-9, "tiring: the warmth spends spoons x (1 + load) (less the idle rest)")
near(DanTraits_RunHooks("enduranceRegen", 1, w, wd), 1 - 0.5 * wd.msHeat, 1e-9, "endurance comes back slower")

-- 4b. discomfort (the game's Uncomfortable stat) wears MS down: stress on top of the game's, and spoons x (1 + 0.5 x it)
w._st.stress = 0; w._st.discomfort = 0.5; H.minute(w)
near(w._st.stress, 0.0002, 1e-9, "half uncomfortable: 0.0002 stress a minute")
DanTraits_SpoonsSet(w, 6); load = wd.msHeat; H.minute(w)
near(6 - wd.spPool, (1 / 160) * (1 + load) * 1.25 - 0.01, 1e-9, "...and the spoons go x1.25")
w._st.discomfort = 0; w._st.stress = 0; H.minute(w); assert(w._st.stress == 0, "comfortable: nothing")
w._asleep = true; w._st.discomfort = 1; H.minute(w); assert(w._st.stress == 0, "asleep: nothing"); w._asleep = false; w._st.discomfort = 0

-- 5. a drink straight from a tap or a river cools: 0.4 a litre; filling a
--    bottle there, or drinking from one, does not
wd.msHeat = 0.6
local tap = { getFluidAmount = function() return 10 end }
ISTakeWaterAction.transferFluid({ character = w, waterObject = tap }, 0.5)
near(wd.msHeat, 0.4, 1e-9, "half a litre from the tap: 0.2 off")
ISTakeWaterAction.transferFluid({ character = w, waterObject = tap, item = {} }, 0.5)
near(wd.msHeat, 0.4, 1e-9, "filling a bottle at the tap: nothing")
DanTraits_RunHooks("drink", nil, w, nil, 0.5)
near(wd.msHeat, 0.4, 1e-9, "drinking from a bottle: nothing")
ISTakeWaterAction.transferFluid({ character = w, waterObject = { getFluidAmount = function() return 0.1 end } }, 0.5)
near(wd.msHeat, 0.36, 1e-9, "a nearly dry source: only what it held")

-- 6. everyday fatigue is the spoon budget (test_spoons.lua): no drip while spoons are on;
--    with the sandbox count at 0 the old drip is back, cut by amantadine; none asleep
local f = newPlayer(); H.current = f
local fd = DanTraits_Data(f)
H.climate.temp = 15
H.minute(f); near(f._st.fatigue, 0, 1e-12, "spoons on: no drip (the budget tires you instead)")
assert(fd.spPool and fd.spCap == 12, "MS draws on a 12-spoon pool")
SandboxVars = { DanTraits = { MSSpoons = 0 } }
H.minute(f); assert(fd.spPool == nil, "spoons off: the pool goes")
f._st.fatigue = 0; H.minute(f); near(f._st.fatigue, 0.0002, 1e-9, "spoons off: a fifth faster to tire")
DanTraits_RunHooks("pill", nil, f, "Amantadine")
near(DanTraits_MedState(f, "amantadine"), 1, 1e-9, "a pill: level 1")
f._st.fatigue = 0; H.minute(f); near(f._st.fatigue, 0.0002, 1e-7, "the first pill: not built up yet")
fd.meds.amantadine.built = 1   -- days of doses
f._st.fatigue = 0; H.minute(f); near(f._st.fatigue, 0.00008, 1e-7, "amantadine built up: x0.4")
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
near(f._parts.LowerLeg_R._stiff, 33, 1e-9, "after the flare the legs ease 2 a minute")
H.mins(5); near(f._parts.LowerLeg_R._stiff, 23, 1e-9, "...and keep easing")
H.mins(20); near(f._parts.LowerLeg_R._stiff, 8, 1e-9, "...down to the everyday floor, no further")
near(f._parts.Hand_R._stiff, 0, 1e-9, "the flare's weak hands go too")

SandboxVars = nil   -- the budget back on

-- 8. baclofen halves the stiffness, heat's and legs' alike
local b = newPlayer(); H.current = b
local bd = DanTraits_Data(b)
DanTraits_RunHooks("pill", nil, b, "Baclofen")
bd.meds.baclofen.built = 1   -- days of doses
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
bd.meds.baclofen.lvl = 1; H.mins(720); near(DanTraits_MedState(b, "baclofen"), 0.5, 1e-3, "halved in 12 hours")
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
local lvl, built = DanTraits_MedState(k, "baclofen")
assert(lvl >= 1 and built == 1, "starts on baclofen, fully built up")
lvl, built = DanTraits_MedState(k, "amantadine")
assert(lvl >= 1 and built == 1, "and amantadine")
assert(DanTraits_MedState(k, "prednisone") == 0, "prednisone has to be found")
SandboxVars = { DanTraits = { StartingMedication = false } }
local k2 = newPlayer(); H.current = k2
H.fire("OnCreatePlayer", 0, k2)
lvl, built = DanTraits_MedState(k2, "baclofen")
assert(#k2._inv == 0 and lvl >= 1 and built == 1, "Starting Medication off: no bottles, still on the drugs")
SandboxVars = nil

-- 12. the moodles
H.load("Moodles")
local function level(name, who, data) return DanTraits_MoodleLevels(who, data)[name] end
local m = newPlayer(); local md = DanTraits_Data(m)
assert(level("MSHeat", m, md) == 0 and level("MSFlare", m, md) == 0, "nothing to show")
md.msHeat = 0.3; assert(level("MSHeat", m, md) == 1, "heat sensitive")
md.msHeat = 0.6; assert(level("MSHeat", m, md) == 2, "too hot")
md.msHeat = 0.9; assert(level("MSHeat", m, md) == 3, "overheated")
md.msFlareH = 5; assert(level("MSFlare", m, md) == 2, "a flare")
md.meds = { prednisone = { lvl = 1, built = 0 } }; assert(level("MSFlare", m, md) == 1, "a flare on prednisone (works at once)")
md.spFelt = 3; assert(level("Spoons", m, md) == 3, "the wall (the spoon budget's felt tier)")
assert(DanTraits_IsMSMed({ getFullType = function() return "DanTraits.Baclofen" end }), "baclofen is an MS pill")
assert(not DanTraits_IsMSMed({ getFullType = function() return "Base.PillsBeta" end }), "beta blockers are not")

-- 13. cooling off takes back what MS put on: stiffness 2 a minute, head
--     pain 2 a minute on top of the game's own 1 (not simulated here), and
--     nothing that MS didn't add
local e = newPlayer(); H.current = e
local ed = DanTraits_Data(e)
e._head.getStiffness = function() return 0 end; e._head.setStiffness = function() end
e._parts.Head = e._head
ed.msHeat = 1; H.climate.temp = 60; e._st.temperature = 40
H.mins(10)
near(e._parts.Hand_L._stiff, 55, 1e-9, "overheated: hands at 55")
near(H.pain(e), 35, 1e-6, "overheated: MS's floor reached")
H.climate.temp = 15; e._st.temperature = 0; ed.msHeat = 0.2
e._parts.Hand_L._stiff = 70   -- the game's own strain from a fight on top
H.minute()
near(e._parts.Hand_R._stiff, 53, 1e-9, "cool: the hands ease 2 a minute")
near(e._parts.Hand_L._stiff, 68, 1e-9, "strain on top eases at the same pace")
near(e._head._pain, 35 / DanTraits_PAIN_PART_RATIO - 2, 1e-6, "the head pain eases 2 a minute (plus the game's 1)")
H.mins(9)
near(e._parts.Hand_R._stiff, 35, 1e-9, "ten minutes: 35")
H.mins(20)
near(e._parts.Hand_R._stiff, 0, 1e-9, "half an hour: the hands are clear")
near(e._parts.Hand_L._stiff, 15, 1e-9, "and only MS's 55 came off the strained hand")
assert(ed.msHands == nil and ed.msPainHead == nil, "nothing left to ease")
near(e._parts.LowerLeg_L._stiff, 8, 1e-9, "the everyday legs are left alone")
e._parts.Hand_R._stiff = 40; H.minute()
near(e._parts.Hand_R._stiff, 40, 1e-9, "stiffness MS never put on is the game's to ease")
-- baclofen taken while stiff halves it, and the hands come down to it
ed.msHeat = 1; H.climate.temp = 60; e._st.temperature = 40; H.mins(3)
DanTraits_RunHooks("pill", nil, e, "Baclofen"); ed.meds.baclofen.built = 1
H.minute(); near(e._parts.Hand_R._stiff, 53, 1e-9, "baclofen: easing toward half")
H.mins(15); near(e._parts.Hand_R._stiff, 27.5, 1e-9, "baclofen: settled at 27.5")
H.climate.temp = 20

-- 14. half built up, half the effect: baclofen at 50% takes a quarter off
local q = newPlayer(); H.current = q
local qd = DanTraits_Data(q)
DanTraits_TakeMSMed(q, "baclofen", 1); qd.meds.baclofen.built = 0.5
H.climate.temp = 15; q._st.temperature = 0
H.minute(); near(q._parts.LowerLeg_L._stiff, 8 * 0.75, 1e-2, "legs: 8 x (1 - 0.5 x 0.5) (the build-up climbs a little that minute)")
-- prednisone works at once, no build-up
qd.msFlareH = 10; DanTraits_TakeMSMed(q, "prednisone", 1)
local before = qd.msFlareH; H.minute(); near(before - qd.msFlareH, 3 / 60, 1e-6, "prednisone: three hours an hour from the first pill")
qd.msFlareH = nil

-- 15. an old save's MS levels are carried across, fully built up
local o = newPlayer(); H.current = o
local od = DanTraits_Data(o)
od.medsMigrated = true; od.msPred, od.msBac, od.msAman = 0.9, 1.2, 0.3
lvl, built = DanTraits_MedState(o, "baclofen")
near(lvl, 1.2, 1e-9, "baclofen carried"); assert(built == 1, "a working level counts as built up")
lvl, built = DanTraits_MedState(o, "amantadine")
near(lvl, 0.3, 1e-9, "amantadine carried"); assert(built == 0, "a lapsed level is not")
near(DanTraits_MedState(o, "prednisone"), 0.9, 1e-9, "prednisone carried")
assert(od.msPred == nil and od.msBac == nil and od.msAman == nil, "the old keys go")

H.pass()
