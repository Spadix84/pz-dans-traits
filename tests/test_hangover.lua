-- Offline test for DanTraits_Hangover.lua: load builds while drunk, the
-- hangover waits for waking, lasts at least six hours after it, fades,
-- pauses for a drink, lowers the night's sleep quality, slows endurance
-- recovery, hurts more in daylight and halves a painkiller's relief.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Dependent", "Hangover")
H.expectEvery("minute", "Hangover")

local halo, near = H.halo, H.near
local minute, ten = H.minute, H.ten
local function md(p) return p._md.DanTraits end

-- 1. a light buzz builds nothing; two hours at 60% intoxication builds one drunk-hour
local p = H.player(); H.current = p
p._st.intox = 15; for _ = 1, 60 do minute() end
assert(md(p).hoLoad == 0, "under the buzz line: no load")
p._st.intox = 60; for _ = 1, 120 do minute() end
near(md(p).hoLoad, 1.0, 1e-6, "(0.6-0.2)/0.8 per hour x 2 h")
assert(not md(p).hoActive, "still drunk: no hangover yet")

-- 2. sobering up while asleep: pending; waking starts it, 6 h + 6 h x severity (1/2)
p._asleep = true; p._st.intox = 0; minute()
assert(md(p).hoPending and not md(p).hoActive, "sobered up asleep: waits for waking")
near(md(p).hoSeverity, 1 / 2, 1e-6, "severity = load / 2")
assert(md(p).hoLoad == 0, "load spent")
p._asleep = false; minute()
assert(md(p).hoActive and not md(p).hoPending, "awake: hangover starts")
near(md(p).hoHoursLeft, 9 - 1 / 60, 1e-6, "6 + 6/2 hours, one minute run")
assert(halo[#halo] == "UI_DanTraits_Hangover1", "notice")

-- 3. symptoms: pain and mood floors ramp at 1 a minute toward severity x strength; thirst creeps
for _ = 1, 20 do minute() end
near(H.pain(p), 35 / 2, 1.0, "headache floor 17.5")
near(p._st.unhappy, 25 / 2, 1.0, "mood floor 12.5")
assert(p._st.thirst > 0 and p._st.fatigue > 0, "thirst and fatigue creep")
assert(p._st.foodsick == 0, "mild: no nausea")
-- painkillers lower the floor by their strength instead of removing it
H.setPain(p, 0); p._pr = 30; for _ = 1, 5 do minute() end; assert(H.pain(p) == 0, "a reduction of 30 swallows a floor of 17.5")
H.setPain(p, 0); p._pr = 5; for _ = 1, 20 do minute() end
assert(H.pain(p) > 0 and H.pain(p) < 35 / 2 - 4, "a reduction of 5 lowers the floor by 5, not to 0: " .. H.pain(p))
p._pr = 0; p._painFx = 1; H.setPain(p, 0); for _ = 1, 20 do minute() end
assert(H.pain(p) > 35 / 2 - 4, "the painkiller timer alone no longer switches the floor off"); p._painFx = 0
-- endurance comes back slower while it is felt
near(DanTraits_RunHooks("enduranceRegen", 0.1, p, md(p)), 0.1 * (1 - 0.4 * 0.5), 1e-9, "endurance recovery cut by 40% x strength")
-- bright daylight outdoors: the headache is worse
DanTraits_InBrightLight = function() return true end
for _ = 1, 20 do minute() end
near(H.pain(p), 45 / 2, 1.0, "in the sun: floor (35 + 10) x 0.5")
DanTraits_InBrightLight = nil; H.setPain(p, 0)
-- a painkiller while hungover works half as long
p._painFx = 100; DanTraits_RunHooks("prePill", nil, p, "Pills"); p._painFx = 5500; DanTraits_RunHooks("pill", nil, p, "Pills")
near(p._painFx, 2800, 1e-6, "half of what the pill added to the timer")
md(p).migActive = true; DanTraits_RunHooks("prePill", nil, p, "Pills"); p._painFx = 8200; DanTraits_RunHooks("pill", nil, p, "Pills")
near(p._painFx, 8200, 1e-6, "a migraine attack has its own rule: the hangover's stands aside")
md(p).migActive = nil; p._painFx = 0

-- 4. hair of the dog: a drink hides symptoms and stops the clock, and builds toward the next one
local left = md(p).hoHoursLeft
p._st.intox = 50; H.setPain(p, 0); for _ = 1, 30 do minute() end
assert(md(p).hoHoursLeft == left, "clock paused while drinking")
assert(H.pain(p) == 0, "no headache while drunk")
assert(DanTraits_RunHooks("enduranceRegen", 0.1, p, md(p)) == 0.1, "nor the endurance cut")
p._painFx = 0; DanTraits_RunHooks("prePill", nil, p, "Pills"); p._painFx = 5400; DanTraits_RunHooks("pill", nil, p, "Pills")
assert(p._painFx == 5400, "a painkiller taken drunk works as usual"); p._painFx = 0
assert(md(p).hoLoad > 0, "the next one is building")
p._st.intox = 0; minute()
assert(md(p).hoActive and md(p).hoLoad == 0 and math.abs(md(p).hoHoursLeft - (left - 1 / 60)) < 1e-9, "sobering with a small load (< 0.5): no new hangover, the old one just resumes")

-- 5. it ends after its time; the last two hours fade
local d = md(p); d.hoHoursLeft = 1.0; d.hoSeverity = 1.0; H.setPain(p, 0)
minute(); near(H.pain(p), 1, 1e-6, "ramping toward a faded floor (35 x 0.5)")
for _ = 1, 30 do minute() end; near(H.pain(p), 13.5, 1.0, "climbs at 1 a minute until it meets the falling floor (35 x (60-k)/120 at minute k: k = 13.5)")
for _ = 1, 40 do minute() end
assert(not md(p).hoActive and md(p).hoSeverity == 0, "over")
assert(halo[#halo] == "+UI_DanTraits_HangoverOver", "good news")

-- 6. sobering while awake starts it straight away; sleeping through part of it gives 6 h back on waking
local q = H.player(); H.current = q
q._st.intox = 100; for _ = 1, 180 do minute() end   -- 3 h blind drunk: load 3 -> severity 1 (full from 2)
q._st.intox = 0; minute()
assert(md(q).hoActive, "started awake"); near(md(q).hoSeverity, 1, 1e-6, "full severity")
near(md(q).hoHoursLeft, 12 - 1 / 60, 1e-6, "12 hours")
for _ = 1, 8 * 60 do minute() end
q._asleep = true; for _ = 1, 60 do minute() end   -- clock stops asleep
near(md(q).hoHoursLeft, 4 - 1 / 60, 1e-6, "paused during sleep")
q._asleep = false; minute()
near(md(q).hoHoursLeft, 6 - 1 / 60, 1e-6, "at least six hours after waking")
-- severe: nausea floor too
q._st.foodsick = 0; for _ = 1, 10 do minute() end; assert(q._st.foodsick > 0, "severe: queasy")

-- 7. tolerance blunts it: an Alcoholic at a full meter tolerance gets 70%
local t = H.player({ traits = { "dependent" } }); H.current = t
t._md.DanTraits = { alcMeter = 1 }
t._st.intox = 100; for _ = 1, 120 do minute() end; t._st.intox = 0; minute()   -- load 2: full before the cut
near(md(t).hoSeverity, 0.7, 1e-6, "severity x 0.7 at full tolerance")

-- 8. the night quality hook: pending or active hangover lowers it by 30% x severity; drinking counts by load
local n = H.player(); H.current = n
assert(DanTraits_RunHooks("nightQuality", 0.8, n, {}) == 0.8, "nothing: untouched")
near(DanTraits_RunHooks("nightQuality", 0.8, n, { hoPending = true, hoSeverity = 1 }), 0.56, 1e-9, "pending, full: x 0.7")
near(DanTraits_RunHooks("nightQuality", 0.8, n, { hoDrinking = true, hoLoad = 1.5 }), 0.8 * (1 - 0.3 * 0.75), 1e-9, "still drunk: by load")

-- the hangoverSeverity hook (Age) acts on the severity before the tolerance cut
DanTraits_AddHook("hangoverSeverity", function(sev, player) if player._aged then return sev * 1.5 end return nil end)
local ag = H.player(); H.current = ag; ag._aged = true
ag._st.intox = 0; ag._md.DanTraits = { hoLoad = 1.0, hoDrinking = true }; minute()
near(md(ag).hoSeverity, 0.75, 1e-6, "load 1.0 is 1/2, x1.5 from the hook")
-- the smallest hangover there is: any load past the minimum is at least 0.4
local sm = H.player(); H.current = sm
sm._md.DanTraits = { hoLoad = 0.5, hoDrinking = true }; minute()
near(md(sm).hoSeverity, 0.4, 1e-6, "load 0.5 would be 0.25: the floor is 0.4")

-- sandbox: HangoverEnabled = false builds no load and ends a hangover in progress
local so = H.player(); H.current = so
so._md.DanTraits = { hoLoad = 0, hoActive = true, hoSeverity = 0.5, hoHoursLeft = 8 }
SandboxVars = { DanTraits = { HangoverEnabled = false } }
minute(); assert(not md(so).hoActive and md(so).hoLoad == 0 and md(so).hoHoursLeft == 0, "off: the hangover ends")
so._st.intox = 60; for _ = 1, 60 do minute() end
assert(md(so).hoLoad == 0 and not md(so).hoDrinking, "off: drinking builds nothing")
SandboxVars = nil

H.pass()
