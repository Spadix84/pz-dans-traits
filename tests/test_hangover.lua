-- Offline test for DanTraits_Hangover.lua: load builds while drunk, the
-- hangover waits for waking, lasts at least six hours after it, fades,
-- pauses for a drink, and lowers the night's sleep quality.
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

-- 2. sobering up while asleep: pending; waking starts it, 6 h + 6 h x severity (1/3)
p._asleep = true; p._st.intox = 0; minute()
assert(md(p).hoPending and not md(p).hoActive, "sobered up asleep: waits for waking")
near(md(p).hoSeverity, 1 / 3, 1e-6, "severity = load / 3")
assert(md(p).hoLoad == 0, "load spent")
p._asleep = false; minute()
assert(md(p).hoActive and not md(p).hoPending, "awake: hangover starts")
near(md(p).hoHoursLeft, 8 - 1 / 60, 1e-6, "6 + 6/3 hours, one minute run")
assert(halo[#halo] == "UI_DanTraits_Hangover1", "notice")

-- 3. symptoms: pain and mood floors ramp at 1 a minute toward severity x strength; thirst creeps
for _ = 1, 20 do minute() end
near(p._st.pain, 35 / 3, 1.0, "headache floor ~11.7")
near(p._st.unhappy, 25 / 3, 1.0, "mood floor ~8.3")
assert(p._st.thirst > 0 and p._st.fatigue > 0, "thirst and fatigue creep")
assert(p._st.foodsick == 0, "mild: no nausea")
-- painkillers lower the floor by their strength instead of removing it
p._st.pain = 0; p._pr = 30; for _ = 1, 5 do minute() end; assert(p._st.pain == 0, "a reduction of 30 swallows a floor of ~11")
p._st.pain = 0; p._pr = 5; for _ = 1, 20 do minute() end
assert(p._st.pain > 0 and p._st.pain < 35 / 3 - 4, "a reduction of 5 lowers the floor by 5, not to 0: " .. p._st.pain)
p._pr = 0; p._painFx = 1; p._st.pain = 0; for _ = 1, 20 do minute() end
assert(p._st.pain > 35 / 3 - 4, "the painkiller timer alone no longer switches the floor off"); p._painFx = 0

-- 4. hair of the dog: a drink hides symptoms and stops the clock, and builds toward the next one
local left = md(p).hoHoursLeft
p._st.intox = 50; p._st.pain = 0; for _ = 1, 30 do minute() end
assert(md(p).hoHoursLeft == left, "clock paused while drinking")
assert(p._st.pain == 0, "no headache while drunk")
assert(md(p).hoLoad > 0, "the next one is building")
p._st.intox = 0; minute()
assert(md(p).hoActive and md(p).hoLoad == 0 and math.abs(md(p).hoHoursLeft - (left - 1 / 60)) < 1e-9, "sobering with a small load (< 0.5): no new hangover, the old one just resumes")

-- 5. it ends after its time; the last two hours fade
local d = md(p); d.hoHoursLeft = 1.0; d.hoSeverity = 1.0; p._st.pain = 0
minute(); near(p._st.pain, 1, 1e-6, "ramping toward a faded floor (35 x 0.5)")
for _ = 1, 30 do minute() end; near(p._st.pain, 13.5, 1.0, "climbs at 1 a minute until it meets the falling floor (35 x (60-k)/120 at minute k: k = 13.5)")
for _ = 1, 40 do minute() end
assert(not md(p).hoActive and md(p).hoSeverity == 0, "over")
assert(halo[#halo] == "+UI_DanTraits_HangoverOver", "good news")

-- 6. sobering while awake starts it straight away; sleeping through part of it gives 6 h back on waking
local q = H.player(); H.current = q
q._st.intox = 100; for _ = 1, 180 do minute() end   -- 3 h blind drunk: load 3 -> severity 1
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
t._md.DanTraits = { depTolerance = 1 }
t._st.intox = 100; for _ = 1, 180 do minute() end; t._st.intox = 0; minute()
near(md(t).hoSeverity, 0.7, 1e-6, "severity x 0.7 at full tolerance")

-- 8. the night quality hook: pending or active hangover lowers it by 30% x severity; drinking counts by load
local n = H.player(); H.current = n
assert(DanTraits_RunHooks("nightQuality", 0.8, n, {}) == 0.8, "nothing: untouched")
near(DanTraits_RunHooks("nightQuality", 0.8, n, { hoPending = true, hoSeverity = 1 }), 0.56, 1e-9, "pending, full: x 0.7")
near(DanTraits_RunHooks("nightQuality", 0.8, n, { hoDrinking = true, hoLoad = 1.5 }), 0.8 * (1 - 0.3 * 0.5), 1e-9, "still drunk: by load")

H.pass()
