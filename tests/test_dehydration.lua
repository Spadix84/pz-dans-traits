-- Offline test for DanTraits_Dehydration.lua: the load builds only at
-- Thirsty or worse, faster the thirstier, and drains once watered; its
-- headache, tiredness and slower endurance; the notices; the switch.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Dehydration")
H.expectEvery("minute", "Dehydration")

local near = H.near
local p = H.player(); H.current = p
local d = DanTraits_Data(p)

-- 1. Slightly Thirsty: nothing; Thirsty: builds at 1/480 a minute; Parched twice that
p._st.thirst = 0.15; H.mins(60); assert(not d.dhLoad, "slightly thirsty: nothing")
p._st.thirst = 0.3; H.mins(60); near(d.dhLoad, 60 / 480, 1e-9, "thirsty")
p._st.thirst = 0.75; H.mins(60); near(d.dhLoad, 60 / 480 + 120 / 480, 1e-9, "parched: twice as fast")
assert(H.halo[#H.halo] == "UI_DanTraits_DehydrationTier1", "a thirst headache")

-- 2. the effects scale with the load
H.minute()
assert(H.pain(p) > 0, "headache")
assert(p._st.fatigue > 0, "tiredness")
near(DanTraits_RunHooks("enduranceRegen", 1, p, d), 1 - 0.4 * d.dhLoad, 1e-9, "slower endurance")

-- 3. a drink: the load drains in about two hours, with a notice
p._st.thirst = 0.05
H.mins(120)
assert(not d.dhLoad, "drained")
assert(H.halo[#H.halo] == "+UI_DanTraits_DehydrationEased", "rehydrated")
near(DanTraits_RunHooks("enduranceRegen", 1, p, d), 1, 1e-9, "endurance as before")

-- 4. the moodle is read when the game has one
MoodleType.THIRST = "thirst"
local m = H.player({ moodles = { thirst = 4 } }); H.current = m
H.mins(10)
near(DanTraits_Data(m).dhLoad, 30 / 480, 1e-9, "dying of thirst: three times")

-- 4b. a hangover builds the load on its own at Thirsty's pace x its strength; watered, the drain still wins
local hv = 0
DanTraits_HangoverStrength = function() return hv end
local h = H.player(); H.current = h; local hd = DanTraits_Data(h)
h._st.thirst = 0.05; hv = 1; H.mins(60); assert(not hd.dhLoad, "watered and hungover: nothing builds")
h._st.thirst = 0.3; H.mins(60); near(hd.dhLoad, 120 / 480, 1e-9, "thirsty and hungover: twice Thirsty's pace")
h._st.thirst = 0.05; H.mins(20); near(hd.dhLoad, 120 / 480 - 60 / 480, 1e-9, "watered: drains, at three quarters of the pace")
hv = 0; H.mins(10); near(hd.dhLoad, 60 / 480 - 40 / 480, 1e-9, "sober: the full drain")
-- and a hangover starting on a dehydrated body is worse: severity x (1 + 0.5 x load)
hd.dhLoad = 0.5
near(DanTraits_RunHooks("hangoverSeverity", 0.6, h), 0.6 * 1.25, 1e-9, "half dehydrated: x1.25")
hd.dhLoad = nil
near(DanTraits_RunHooks("hangoverSeverity", 0.6, h), 0.6, 1e-9, "watered: untouched")
DanTraits_HangoverStrength = nil; H.current = m

-- 5. off: nothing builds and any load clears
SandboxVars = { DanTraits = { DehydrationEnabled = false } }
H.minute()
assert(not DanTraits_Data(m).dhLoad, "off: cleared")
SandboxVars = nil

H.pass()
