
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
-- Offline test for DanTraits_Asthma.lua: irritation build-up from cold air,
-- exertion, corpses and panic; masks; the attack tiers and their effects; the
-- inhaler and the starting kit; coughs and waking the sleeper.
H.events()
H.stubs()
local moodleValues = {}
MF = { getMoodle = function(name, num) return { setThresholds = function() end, setValue = function(_, v) moodleValues[#moodleValues+1] = v end } end }

H.load("Dependent", "MDD", "Brittle", "Arthritis", "Jinxed", "BadDay", "Hallucinations", "Asthma", "Gluten", "Vegetarian", "Diabetes")
H.expectHooks("OnCreatePlayer")
H.expectEvery("minute", "Asthma")
H.expectEvery("frame", "Delta:enduranceRegen")   -- Asthma subscribes to the pipeline

-- every player here has the trait
local newPlayer = H.factory({ traits = { "asthma" } }, function(p, o)
  p.getWornItem = function(_, loc) return (o.worn or {})[loc] end
end)
local halo = H.halo
local minute, frame = H.minute, H.frame
local function irritation(p) return p._md.DanTraits.asthma end

-- 1. warm, calm, rested: nothing builds; stays at 0
local p = newPlayer({}); H.current = p
for _ = 1, 30 do minute() end
assert(irritation(p) == 0, "clean air stays at 0")
print("clean warm air, 30 min: irritation " .. irritation(p))

-- 2. cold air + exertion (endurance low and still being spent) builds: 0.005 + 0.014 = 0.019 per minute -> 0.90 after ~48 minutes
H.climate.temp = 0; p._st.endurance = 0.3
local m = 0
while not p._md.DanTraits.asthmaAttack and m < 200 do p._st.endurance = math.max(0.001, p._st.endurance - 0.002); minute(); m = m + 1 end
print("cold + exhausted: attack after " .. m .. " minutes (irritation " .. string.format("%.2f", irritation(p)) .. ")")
assert(p._md.DanTraits.asthmaAttack and m >= 47 and m <= 49, "attack at 0.90 after ~48 min at 0.019/min, got " .. m)
assert(halo[1] == "UI_DanTraits_AsthmaTier1" and halo[2] == "UI_DanTraits_AsthmaTier2" and halo[3] == "UI_DanTraits_AsthmaTier3" and halo[4] == "UI_DanTraits_AsthmaTier4", "tier notices in order")
assert(moodleValues[#moodleValues] < 0.06, "moodle value maps to bad level 4")

-- 3. attack effects on the minute: endurance drain, health drain to the 15% floor, loud coughs
p._st.endurance = 1.0
local hBefore = p._health
minute()
assert(p._st.endurance == 0.85, "endurance drains 0.15 per minute in an attack")
assert(p._health == hBefore - 0.75 and H.sounds[#H.sounds] == 30, "health drains 0.75, cough heard at 30 tiles")
for _ = 1, 400 do minute() end
assert(p._health == 15, "health floor holds at 15")
print("attack: endurance " .. p._st.endurance .. ", health floored at " .. p._health .. ", coughs " .. p._coughs)

-- 4. per-frame regen clawback: in an attack, no regeneration sticks
p._st.endurance = 0.2; frame(p); p._st.endurance = 0.3; frame(p)
assert(p._st.endurance == 0.2, "no endurance regen during attack")

-- 5. inhaler: -0.5 and the attack ends (hysteresis: needs < 0.75)
local before = irritation(p)
assert(DanTraits_UseInhaler(p))
local panicBefore = p._st.panic
assert(not p._md.DanTraits.asthmaAttack and irritation(p) == math.max(0, before - 0.5), "inhaler ends the attack")
do
  local n = 0
  for _, t in ipairs(halo) do if t == "+UI_DanTraits_AsthmaRelief" then n = n + 1 end end
  assert(n == 1, "one relief notice, not two, got " .. n)
end
assert(p._st.panic == math.min(100, panicBefore + 10), "inhaler sets the heart racing: +10 panic")
print(string.format("inhaler: %.2f -> %.2f, attack over, tier now %d", before, irritation(p), (function() local t=0 for i,th in ipairs({0.25,0.5,0.75,0.9}) do if irritation(p) >= th then t = i end end return t end)()))

-- 6. tier 2 halves regen: set irritation to 0.6 by hand
p._md.DanTraits.asthma = 0.6; p._md.DanTraits.asthmaAttack = false
p._st.endurance = 0.2; DanTraits_DeltaRemember(p._md.DanTraits, "enduranceRegen", 0.2)
p._st.endurance = 0.4; frame(p)
assert(math.abs(p._st.endurance - 0.3) < 1e-9, "tier 2 keeps half of the gain")
print("tier 2: regen 0.2 -> 0.4 clawed back to " .. p._st.endurance)

-- 7. masks: gas mask ignores cold and corpses, dust mask halves them
H.climate.temp = 0; H.corpses = 3; p._st.endurance = 1.0
local q = newPlayer({ worn = { maskeyes = { getType = function() return "Hat_GasMask" end, getBodyLocation = function() return "base:maskeyes" end } } }); H.current = q
for _ = 1, 10 do minute() end
assert(irritation(q) == 0, "gas mask: no environmental build-up")
local r = newPlayer({ worn = { mask = { getType = function() return "Hat_DustMask" end, getBodyLocation = function() return "base:mask" end } } }); H.current = r
minute()
assert(math.abs(irritation(r) - (0.005 + 0.012) * 0.5) < 1e-9, "dust mask halves cold+corpse build-up")
local u = newPlayer({}); H.current = u
minute()
assert(math.abs(irritation(u) - 0.017) < 1e-9, "no mask: full cold+corpse build-up")
print(string.format("masks: none %.3f, dust %.3f, gas %.3f per minute", irritation(u), irritation(r), irritation(q)))

-- 8. sleeping in clean air clears twice as fast
H.climate.temp = 20; H.corpses = 0
local sl = newPlayer({ asleep = true }); H.current = sl; sl._md.DanTraits = { asthma = 0.5 }
minute()
assert(math.abs(irritation(sl) - 0.492) < 1e-9, "asleep decay 0.008")
print("asleep decay: 0.500 -> " .. string.format("%.3f", irritation(sl)))

-- 9. starting kit: one real inhaler item, given once
local nw = newPlayer({}); H.fire("OnCreatePlayer", 0, nw)
assert(#nw._inv == 1 and nw._inv[1]._type == "DanTraits.Inhaler", "starts with a DanTraits.Inhaler")
assert(DanTraits_IsInhaler(nw._inv[1]), "item check by full type")
assert(not DanTraits_IsInhaler({ getFullType = function() return "Base.PillsBeta" end }), "beta blockers are not inhalers")
assert(not DanTraits_IsInhaler(nil), "nil safe")
H.fire("OnCreatePlayer", 0, nw); assert(#nw._inv == 1, "only once")
assert(#(H.handlers.OnFillContainer or {}) == 2, "no inhaler container conversion hook: only Jinxed and Bad Day's sewing kit register OnFillContainer")
print("new character gets 1 " .. nw._inv[1]._type)
-- 10. panic: nothing under 20, linear to 0.008/min at 100, and a gas mask does not help
local pn = newPlayer({}); H.current = pn
pn._st.panic = 10; minute(); assert(irritation(pn) == 0, "slight panic ignored")
pn._st.panic = 100; minute()
assert(math.abs(irritation(pn) - 0.010) < 1e-9, "max panic builds 0.010/min, got " .. irritation(pn))
pn._st.panic = 60; local before10 = irritation(pn); minute()
assert(math.abs((irritation(pn) - before10) - 0.005) < 1e-9, "panic 60 builds half rate")
local pg = newPlayer({ worn = { maskfull = { getType = function() return "Hat_GasMask" end, getBodyLocation = function() return "maskfull" end } } }); H.current = pg
pg._st.panic = 100; minute()
assert(math.abs(irritation(pg) - 0.010) < 1e-9, "gas mask does not blunt panic build-up")
print("panic: 10 -> 0, 100 -> +0.010/min, 60 -> +0.005/min, gas mask irrelevant")
-- 11. an attack raises panic 5 per minute, capped at 100
local pa = newPlayer({}); H.current = pa
pa._md.DanTraits = pa._md.DanTraits or {}; pa._md.DanTraits.asthma = 0.95; pa._md.DanTraits.asthmaAttack = true
pa._st.panic = 0; minute(); assert(pa._st.panic == 5, "attack adds 5 panic per minute, got " .. tostring(pa._st.panic))
pa._st.panic = 98; minute(); assert(pa._st.panic == 100, "panic capped at 100")
print("attack: +5 panic per minute, capped at 100")
-- 12. exertion: under 40% endurance and still being spent builds; above 40%, or worn down but resting, does not
local ex = newPlayer({ endurance = 0.36 }); H.current = ex; H.climate.temp = 20; H.corpses = 0
minute(); ex._st.endurance = 0.35; minute()
assert(math.abs(irritation(ex) - 0.014) < 1e-9, "endurance falling at 35% counts as exertion")
local ex2 = newPlayer({ endurance = 0.46 }); H.current = ex2
minute(); ex2._st.endurance = 0.45; minute(); assert(irritation(ex2) == 0, "endurance 45% does not")
local worn = newPlayer({ endurance = 0.21 }); H.current = worn
for _ = 1, 30 do minute() end
assert(irritation(worn) == 0, "worn down to 21% (blood loss, anaemia) but resting: nothing builds")
worn._st.endurance = 0.22; minute(); assert(irritation(worn) == 0, "recovering: nothing builds")
print("exertion: spending at 35% builds 0.014/min; 45%, or resting worn down, nothing")

-- 13. tier 2 coughs now and then (6 tiles); tier 1 never
local c2 = newPlayer({}); H.current = c2; c2._md.DanTraits = { asthma = 0.6 }
for _ = 1, 8 do minute() end
assert(c2._coughs >= 1 and H.sounds[#H.sounds] == 6, "tier 2 coughs within 6 minutes at 6 tiles")
local c1 = newPlayer({}); H.current = c1; c1._md.DanTraits = { asthma = 0.3 }
for _ = 1, 20 do minute() end
assert(c1._coughs == 0, "tier 1 does not cough")
print("tier 2 coughs: " .. c2._coughs .. " in 8 min, tier 1: " .. c1._coughs)

-- 14. asleep at tier 3 or worse: woken up; tier 2 sleeps on
local w3 = newPlayer({ asleep = true }); H.current = w3; w3._md.DanTraits = { asthma = 0.8 }
minute(); assert(w3._woke == 1 and not w3._asleep and halo[#halo] == "UI_DanTraits_AsthmaWake", "tier 3 wakes the sleeper")
local w2 = newPlayer({ asleep = true }); H.current = w2; w2._md.DanTraits = { asthma = 0.6 }
minute(); assert(w2._woke == 0 and w2._asleep, "tier 2 sleeps on")
print("sleep: tier 3 woke=" .. w3._woke .. ", tier 2 woke=" .. w2._woke)

-- 15. a fever irritates the airway: +0.004 a minute at full fever, whatever the mask (DanTraits_InfectionFever)
local feverish = newPlayer({}); H.current = feverish; feverish._md.DanTraits = { asthma = 0.3 }
minute(); H.near(irritation(feverish), 0.296, 1e-9, "no fever: calm air decays 0.004")
feverish._md.DanTraits.asthma = 0.3
DanTraits_InfectionFever = function() return 1 end
minute(); H.near(irritation(feverish), 0.304, 1e-9, "full fever: +0.004, so no decay that minute")
feverish._md.DanTraits.asthma = 0.3
DanTraits_InfectionFever = function() return 0.5 end
minute(); H.near(irritation(feverish), 0.302, 1e-9, "half fever: +0.002")
DanTraits_InfectionFever = nil
-- 15. an attack that has emptied endurance for three minutes running can black you out, once per attack
local passCalls, passResult = {}, true
DanTraits_PassOut = function(_, minutes, key, deep) passCalls[#passCalls + 1] = { minutes = minutes, key = key, deep = deep }; return passResult end
local fa = newPlayer({}); H.current = fa
fa._md.DanTraits = { asthma = 0.95, asthmaAttack = true }
H.rollf = 0
fa._st.endurance = 0; minute(); fa._st.endurance = 0; minute()
assert(#passCalls == 0, "two empty minutes: not yet")
fa._st.endurance = 0; minute()
assert(#passCalls == 1 and passCalls[1].key == "UI_DanTraits_AsthmaBlackout" and passCalls[1].deep == true, "third empty minute: a deep faint")
assert(passCalls[1].minutes >= 2 and passCalls[1].minutes <= 5, "for 2 to 5 minutes")
assert(fa._md.DanTraits.asthmaAttack, "the attack is not cleared")
for _ = 1, 5 do fa._st.endurance = 0; minute() end
assert(#passCalls == 1, "once per attack")
-- endurance coming back resets the count
local fb = newPlayer({}); H.current = fb
fb._md.DanTraits = { asthma = 0.95, asthmaAttack = true }
fb._st.endurance = 0; minute(); fb._st.endurance = 0; minute(); fb._st.endurance = 1.0; minute(); fb._st.endurance = 0; minute()
assert(#passCalls == 1, "a break in the empty run starts the count again")
-- the attack ends, the next one can faint again; a refused faint (already out) is not spent
H.current = fa; DanTraits_UseInhaler(fa)
assert(not fa._md.DanTraits.asthmaAttack and not fa._md.DanTraits.asthmaFainted, "attack over: the once-per-attack flag clears")
passResult = false
fa._md.DanTraits.asthma = 0.95
for _ = 1, 4 do fa._st.endurance = 0; minute() end
assert(#passCalls == 3 and not fa._md.DanTraits.asthmaFainted, "a refused faint is not spent (asked again the third and fourth empty minute)")
passResult = true; fa._st.endurance = 0; minute()
assert(#passCalls == 4 and fa._md.DanTraits.asthmaFainted, "and the next attack faints")
-- while out nothing builds and irritation decays at the attack rate
DanTraits_IsPassedOut = function() return true end
local fo = newPlayer({}); H.current = fo
fo._md.DanTraits = { asthma = 0.95, asthmaAttack = true }; fo._st.panic = 100; fo._st.endurance = 0
minute()
H.near(fo._md.DanTraits.asthma, 0.95 - 0.001, 1e-9, "out: no exertion or panic build, the attack rate of decay")
DanTraits_IsPassedOut = nil; DanTraits_PassOut = nil; H.rollf = 0.99
print("asthma blackout: once per attack, after three empty minutes")
-- an attack's own drain and panic do not feed it: resting in warm clean air it
-- eases at the attack rate and ends in about four hours; running keeps it going
local rest = newPlayer({}); H.current = rest; H.climate.temp = 20; H.corpses = 0
rest._md.DanTraits = { asthma = 1.0, asthmaAttack = true }; rest._st.panic = 100; rest._st.endurance = 0
minute()
H.near(rest._md.DanTraits.asthma, 1.0 - 0.001, 1e-9, "resting: empty and panicking, yet it eases")
local mins = 1
while rest._md.DanTraits.asthmaAttack and mins < 400 do rest._st.panic = 100; rest._st.endurance = 0; minute(); mins = mins + 1 end
assert(not rest._md.DanTraits.asthmaAttack and mins >= 240 and mins <= 260, "ends after about four hours at rest, got " .. mins .. " min")
local runner = newPlayer({ sprint = true }); H.current = runner
runner._md.DanTraits = { asthma = 0.95, asthmaAttack = true }; runner._st.endurance = 0
minute()
assert(runner._md.DanTraits.asthma > 0.95, "running through an attack still feeds it")
print("attack at rest ends in about four hours; running feeds it")

-- 16. one cough: a single gap across callers, the attack's burst forces it, a cigarette irritates, lungs hurt
do
  local cg = newPlayer({}); H.current = cg; cg._md.DanTraits = { asthma = 0.6 }
  H.hours = H.hours + 1
  cg._md.DanTraits.asthmaCoughIn = 1; minute()
  assert(cg._coughs == 1, "tier 2 window: a cough")
  cg._md.DanTraits.asthmaCoughIn = 1; minute()
  assert(cg._coughs == 1, "a second window in the same three minutes: no second cough")
  H.hours = H.hours + 3 / 60 + 1e-6
  cg._md.DanTraits.asthmaCoughIn = 1; minute()
  assert(cg._coughs == 2, "gap passed: coughs again")
  assert(cg._md.DanTraits.lastCoughWhy == "asthma" and cg._md.DanTraits.coughs == 2, "recorded")
  -- an attack coughs through the gap
  cg._md.DanTraits.asthma = 0.95; cg._md.DanTraits.asthmaAttack = true
  local n = cg._coughs; minute()
  assert(cg._coughs >= n + 1, "attack: forced past the gap")
  -- the rest of the burst lands within about a second (Later counts frames), and not after the attack ends
  local tick = H.on("OnTick")
  local first = cg._coughs
  for _ = 1, 150 do tick() end
  assert(cg._coughs >= first + 1, "the burst's later coughs land within 150 frames")
  cg._md.DanTraits.asthma = 0.95; cg._md.DanTraits.asthmaAttack = true
  minute(); local afterMinute = cg._coughs
  cg._md.DanTraits.asthmaAttack = false   -- the inhaler, before the burst lands
  for _ = 1, 150 do tick() end
  assert(cg._coughs == afterMinute, "a burst landing after the attack ended is dropped")
  -- the shared gap: a smoker's cough right before blocks a tier 2 window
  local cs = newPlayer({}); H.current = cs; cs._md.DanTraits = { asthma = 0.6 }
  H.hours = H.hours + 1
  assert(DanTraits_Cough(cs, 35, "smoker") and cs._coughs == 1)
  cs._md.DanTraits.asthmaCoughIn = 1; minute()
  assert(cs._coughs == 1, "Smoker's cough and Asthma's share the gap")
  -- a cigarette adds 0.12 irritation per dose, for a Brittle Asthma character only, mask or none
  local sm = newPlayer({ worn = { maskeyes = { getType = function() return "Hat_GasMask" end, getBodyLocation = function() return "base:maskeyes" end } } }); H.current = sm
  sm._md.DanTraits = { asthma = 0.1 }
  assert(DanTraits_AsthmaSmoked(sm, 1)); H.near(sm._md.DanTraits.asthma, 0.22, 1e-9, "a cigarette: +0.12, no mask help")
  DanTraits_AsthmaSmoked(sm, 0.5); H.near(sm._md.DanTraits.asthma, 0.28, 1e-9, "half a dose: half")
  local nonAsthmatic = H.player({ traits = {} }); H.current = nonAsthmatic
  assert(not DanTraits_AsthmaSmoked(nonAsthmatic, 1), "no trait: nothing")
  -- damaged lungs: exertion builds 1.5x and every recovery is 0.7x
  local lg = newPlayer({ endurance = 0.35 }); H.current = lg; lg._md.DanTraits = { asthma = 0, asthmaEndPrev = 0.36, nicLungs = 1 }
  minute(); H.near(lg._md.DanTraits.asthma, 0.014 * 1.5, 1e-9, "nicLungs = 1: exertion build x 1.5")
  local lg2 = newPlayer({ asleep = true }); H.current = lg2; lg2._md.DanTraits = { asthma = 0.5, nicLungs = 1 }
  minute(); H.near(lg2._md.DanTraits.asthma, 0.5 - 0.008 * 0.7, 1e-9, "nicLungs = 1: decay x 0.7")
  local lg3 = newPlayer({ endurance = 0.35 }); H.current = lg3; lg3._md.DanTraits = { asthma = 0, asthmaEndPrev = 0.36, nicLungs = 0.5 }
  minute(); H.near(lg3._md.DanTraits.asthma, 0.014 * 1.25, 1e-9, "half-damaged lungs: x 1.25")
  print("one cough shared, cigarette irritates, lungs speed the build")
end

H.pass()
