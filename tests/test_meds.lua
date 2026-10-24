-- Offline test for DanTraits_Meds.lua, the shared medication system: the
-- level and its half-life, build-up and fading, rescue drugs, the daily side
-- effect roll (and the sandbox chance), overdose, vanilla beta blockers losing
-- their own effect, diazepam's panic drop, old saves carried across, the
-- random fill of spawned bottles and the vanilla item patch.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
UIManager = { FadeOut = function() end, FadeIn = function() end }
H.load("Faint", "Meds")
H.expectEvery("minute", "Meds")
H.expectEvery("frame", "Meds")
H.expectHooks("OnGameBoot", "OnFillContainer")

local near = H.near
H.hours = 100

-- 1. a dose: the item finds its drug, the level halves on the drug's half-life
local p = H.player(); H.current = p
assert(DanTraits_DrugOfItem("PillsBeta") == "beta" and DanTraits_DrugOfItem("Diazepam") == "diazepam", "items map to drugs")
assert(DanTraits_DrugOfItem("Pills") == "painkillers" and DanTraits_DrugOfItem("Bandage") == nil, "painkillers are on the list, a bandage is not")
DanTraits_RunHooks("pill", nil, p, "Anticonvulsants")
local lvl, built = DanTraits_MedState(p, "anticonvulsant")
assert(lvl == 1 and built == 0, "one pill, nothing built yet")
assert(DanTraits_MedCovered(p, "anticonvulsant") and DanTraits_MedEffect(p, "anticonvulsant") == 0, "covered, but no effect yet")
H.mins(720)
near(DanTraits_MedState(p, "anticonvulsant"), 0.5, 1e-3, "halved in 12 hours")

-- 2. build-up: full after buildDays covered; fading to nothing after fadeDays without
local b = H.player(); H.current = b
local bd = DanTraits_Data(b)
DanTraits_MedTake(b, "metformin", 1)
for _ = 1, 24 do H.mins(60); end
near(DanTraits_MedEffect(b, "metformin"), 0.5, 0.01, "a day of cover: half built (two days to build)")
DanTraits_MedTake(b, "metformin", 1)
H.mins(1440)
near(DanTraits_MedEffect(b, "metformin"), 1, 0.002, "two days: fully built")
bd.meds.metformin.lvl = 0
H.mins(1440)
near(DanTraits_MedEffect(b, "metformin"), 0.5, 0.01, "a missed day: half gone, not all")
H.mins(1440)
near(DanTraits_MedEffect(b, "metformin"), 0, 1e-9, "two missed days: nothing left")

-- 3. a rescue drug works at once while it is in the system
local r = H.player(); H.current = r
DanTraits_RunHooks("pill", nil, r, "Diazepam")
assert(DanTraits_MedEffect(r, "diazepam") == 1, "diazepam: full effect at once")
H.mins(100)
assert(DanTraits_MedEffect(r, "diazepam") == 0, "worn off after about an hour and a half")

-- 4. diazepam takes panic down at the vanilla beta blocker rate (0.6 a tick), not asleep
local z = H.player(); H.current = z
DanTraits_MedTake(z, "diazepam", 1)
z._st.panic = 50
H.frame(z); near(z._st.panic, 49.4, 1e-9, "0.6 a tick")
z._asleep = true; H.frame(z); near(z._st.panic, 49.4, 1e-9, "asleep: none"); z._asleep = false
local none = H.player(); H.current = none; none._st.panic = 50
H.frame(none); near(none._st.panic, 50, 1e-9, "no diazepam: none")

-- 5. vanilla beta blockers: the game's own panic timers are put back after the pill
local v = H.player(); H.current = v
v._beta, v._betaD = 0, 0
-- the pill action runs prePill, the vanilla effect, then pill (DanTraits.lua)
DanTraits_RunHooks("prePill", nil, v, "PillsBeta")
v._beta, v._betaD = 6600, 1
DanTraits_RunHooks("pill", nil, v, "PillsBeta")
assert(v._beta == 0 and v._betaD == 0, "vanilla beta blocker effect undone")
near(DanTraits_MedState(v, "beta"), 1, 1e-9, "and the dose counted")

-- 6. side effects: the first dose of a game day rolls (3%); a hit runs for sideH hours
local s = H.player(); H.current = s
local sd = DanTraits_Data(s)
H.rollf = 0.5
DanTraits_MedTake(s, "metformin", 1)
H.minute(); assert(s._st.foodsick == 0, "a missed roll: nothing")
H.rollf = 0.01
DanTraits_MedTake(s, "metformin", 1)
H.minute(); assert(s._st.foodsick == 0, "same day: no second roll")
H.hours = H.hours + 24
DanTraits_MedTake(s, "metformin", 1)
assert(H.halo[#H.halo] == "UI_DanTraits_MedSide_metformin", "a hit on a new day: notice")
H.rollf = 0.99
for _ = 1, 15 do H.minute() end
assert(s._st.foodsick == 15, "upset stomach: sickness up to 15")
H.mins(480)
assert(sd.meds.metformin.sideMin == nil, "over after eight hours")
-- beta blockers' side effect slows endurance recovery
sd.meds.beta = { lvl = 0, built = 0, sideMin = 30 }
near(DanTraits_RunHooks("enduranceRegen", 1, s, sd), 0.8, 1e-9, "stamina slower")
-- sandbox 0: no side effects at all
SandboxVars = { DanTraits = { MedSideEffectChance = 0 } }
near(DanTraits_RunHooks("enduranceRegen", 1, s, sd), 1, 1e-9, "off: nothing")
H.hours = H.hours + 24
H.rollf = 0
sd.meds.metformin.day = nil
DanTraits_MedTake(s, "metformin", 1)
assert(sd.meds.metformin.sideMin == nil, "off: never rolls")
SandboxVars = nil
H.rollf = 0.99

-- 7. too many: the overdose effect runs while the level is over, with one notice
local o = H.player(); H.current = o
DanTraits_MedTake(o, "diazepam", 3)
H.clearHalo()
H.minute(); H.minute()
local notices = 0
for _, t in ipairs(H.halo) do if t == "UI_DanTraits_MedOver_diazepam" then notices = notices + 1 end end
assert(notices == 1 and o._st.fatigue > 0, "overdose: drowsy, one notice")
near(DanTraits_RunHooks("enduranceRegen", 1, o, DanTraits_Data(o)), 0.7, 1e-9, "and sluggish")

-- 8. a new character on a drug starts dosed and built up; old saves carry across
local n = H.player(); H.current = n
DanTraits_MedStart(n, "anticonvulsant")
lvl, built = DanTraits_MedState(n, "anticonvulsant")
assert(lvl == 1 and built == 1, "started built up")
local old = H.player(); H.current = old
local od = DanTraits_Data(old)
od.epMeds, od.diaMedMinutes, od.hcBeta = 0.3, 720, 0
lvl, built = DanTraits_MedState(old, "anticonvulsant")
assert(lvl == 0.3 and built == 0, "an old level under protection: carried, not built")
lvl, built = DanTraits_MedState(old, "metformin")
assert(lvl == 0.5 and built == 1, "old metformin cover: half a day is a protecting level")
assert(od.epMeds == nil and od.diaMedMinutes == nil and od.hcBeta == nil, "old keys cleared")

-- 9. spawned bottles: 30% to 100% full, once
local bottle = { _md = {}, getModData = function(self) return self._md end,
                 setUsedDelta = function(self, x) self._delta = x end }
H.rng = { 0 }
assert(DanTraits_MedRandomFill(bottle) and bottle._delta == 0.3, "emptiest: 30%")
bottle._delta = nil
assert(not DanTraits_MedRandomFill(bottle) and bottle._delta == nil, "never twice")

-- 10. vanilla items: our tooltips, 30-pill daily bottles
local params = {}
getScriptManager = function()
  return { getItem = function(_, name) return { DoParam = function(_, s) params[#params + 1] = name .. " " .. s end } end }
end
DanTraits_MedPatchScripts()
local joined = table.concat(params, "|")
assert(joined:find("Base.PillsBeta Tooltip = Tooltip_DanTraits_PillsBeta", 1, true), "beta blocker tooltip")
assert((joined .. "|"):find("Base.PillsBeta UseDelta = 0.0333|", 1, true), "beta blockers: 30 pills (0.0333 exactly: 1/30 itself counts as 29)")
assert(joined:find("Base.Pills Tooltip = Tooltip_DanTraits_Painkillers", 1, true), "painkiller tooltip")
assert(not joined:find("Base.Pills UseDelta", 1, true), "painkiller bottle size unchanged")
getScriptManager = nil

-- 11. everything else that is taken is on the list
for item, id in pairs({ inhaler = "inhaler", NicotineGum = "nicotinegum", Pills = "painkillers",
                        PillsSleepingTablets = "sleepingtablets", PillsVitamins = "caffeinepills",
                        InsulinPen = "insulin", Prednisone = "prednisone", Baclofen = "baclofen", Amantadine = "amantadine" }) do
  assert(DanTraits_DrugOfItem(item) == id, item .. " is " .. id)
end
-- five puffs close together overdo it and strain the heart; four do not
local ih = H.player(); H.current = ih
for _ = 1, 4 do DanTraits_MedTake(ih, "inhaler", 1) end
H.clearHalo(); H.minute()
assert(not DanTraits_MedHeartStrain(ih) and #H.halo == 0, "four puffs: fine")
DanTraits_MedTake(ih, "inhaler", 1); H.minute()
assert(DanTraits_MedHeartStrain(ih) and H.halo[#H.halo] == "UI_DanTraits_MedOver_inhaler", "five: too many, the heart strained")
local st = ih._st.stress; H.minute(); assert(ih._st.stress > st, "jittery: stress climbs")
H.mins(90); assert(not DanTraits_MedHeartStrain(ih), "and it passes as the puffs wear off")
-- caffeine pills: four strain the heart too
local cp = H.player(); H.current = cp
for _ = 1, 4 do DanTraits_MedTake(cp, "caffeinepills", 1) end
H.minute(); assert(DanTraits_MedHeartStrain(cp), "four caffeine pills: heart strain")
-- painkillers: three are not too many, four are
local pk = H.player(); H.current = pk
for _ = 1, 3 do DanTraits_MedTake(pk, "painkillers", 1) end
H.minute()
assert(not DanTraits_Data(pk).meds.painkillers.over, "three painkillers: not an overdose")
DanTraits_MedTake(pk, "painkillers", 1); H.minute()
assert(DanTraits_Data(pk).meds.painkillers.over, "four: strong nausea")
near(pk._st.foodsick, 1, 1e-9, "food sickness climbing toward 60")
H.mins(30); assert(DanTraits_Data(pk).meds.painkillers.over, "still over once the level has fallen back (four hours)")
H.mins(4 * 60 + 30); assert(not DanTraits_Data(pk).meds.painkillers.over, "and over after that")
near(pk._st.foodsick, 60, 1e-9, "the nausea got to 60")
-- an overdose of sleeping tablets can black you out, but never in your sleep
local sl = H.player(); H.current = sl
for _ = 1, 3 do DanTraits_MedTake(sl, "sleepingtablets", 1) end
local fainted = 0
local passOut = DanTraits_PassOut
DanTraits_PassOut = function() fainted = fainted + 1 end
sl._asleep = true; H.rollf = 0; H.minute(); assert(fainted == 0, "asleep: no blackout")
sl._asleep = false; H.minute(); assert(fainted == 1, "awake: the blackout roll")
H.rollf = 0.99; DanTraits_PassOut = passOut
-- insulin: the doses on board, from Diabetes' own list
local ins = H.player(); H.current = ins
DanTraits_Data(ins).diaInsulin = { { dose = 2, t = 10 }, { dose = 1, t = 0 } }
near(DanTraits_MedState(ins, "insulin"), 3, 1e-9, "three doses on board")
-- prednisone's side effect is strong enough to beat the game easing stress
near(DanTraits_Drugs.prednisone.side.stress, 0.001, 1e-12, "prednisone side: 0.001 stress a minute")

-- 12. hooks for Age and Cast Iron: medHalfLife (daily and course drugs only), medSideChance, medOverAt
local slow = H.player(); H.current = slow
local slowMe = slow
DanTraits_AddHook("medHalfLife", function(h, player) if player == slowMe then return h * 2 end end)
DanTraits_MedTake(slow, "anticonvulsant", 1); DanTraits_MedTake(slow, "diazepam", 1)
H.mins(180)
near(DanTraits_MedState(slow, "anticonvulsant"), 0.5 ^ (3 / 24), 1e-3, "a daily drug's half-life doubled: 3 hours leaves 0.917, not 0.841")
near(DanTraits_MedState(slow, "diazepam"), 0.5 ^ (3 / 1.5), 1e-3, "a rescue drug: its own half-life, hook or no hook")
local hardy = H.player(); H.current = hardy
local hardyMe = hardy
DanTraits_AddHook("medSideChance", function(c, player) if player == hardyMe then return 0 end end)
SandboxVars = SandboxVars or {}; SandboxVars.DanTraits = SandboxVars.DanTraits or {}
SandboxVars.DanTraits.MedSideEffectChance = 100
DanTraits_MedTake(hardy, "beta", 1)
assert(DanTraits_Data(hardy).meds.beta.sideMin == nil, "a side chance of 0 from the hook: no side effect even at 100%")
SandboxVars.DanTraits.MedSideEffectChance = nil
DanTraits_AddHook("medOverAt", function(at, player) if player == hardyMe then return at + 1 end end)
DanTraits_Data(hardy).meds.beta.lvl = 3.5; H.mins(1)
assert(not DanTraits_Data(hardy).meds.beta.over, "3.5 beta blockers with the line at 4: not over")
DanTraits_Data(hardy).meds.beta.lvl = 4.5; H.mins(1)
assert(DanTraits_Data(hardy).meds.beta.over, "4.5: over")

-- 13. the schedule: the daily drugs for the traits a character has; each dose noted,
--     due two hours before the interval is up, missed once it wears off, nothing once off it
do
  local function wait(m) H.mins(m); H.hours = H.hours + m / 60 end
  local sc = H.player({ traits = { "heart", "epilepsy" } }); H.current = sc
  local list = DanTraits_MedSchedule(sc)
  assert(#list == 2 and list[1] == "anticonvulsant" and list[2] == "beta", "heart and epilepsy: " .. table.concat(list, ", "))
  assert(#DanTraits_MedSchedule(H.player()) == 0, "no trait: nothing on the schedule")
  assert(DanTraits_MedSince(sc, "beta") == nil and DanTraits_MedDue(sc, "beta") == 0 and DanTraits_MedDueLevel(sc) == 0, "never taken: nothing due")
  DanTraits_RunHooks("pill", nil, sc, "PillsBeta")
  near(DanTraits_MedSince(sc, "beta"), 0, 1e-9, "the dose is noted")
  near(DanTraits_MedNextIn(sc, "beta"), 22, 1e-9, "once a day: due in 22 hours")
  wait(21 * 60)
  assert(DanTraits_MedDue(sc, "beta") == 0, "21 hours: not yet")
  wait(60)
  assert(DanTraits_MedDue(sc, "beta") == 1 and DanTraits_MedDueLevel(sc) == 1, "22 hours: due")
  wait(3 * 60)
  assert(not DanTraits_MedCovered(sc, "beta") and DanTraits_MedDue(sc, "beta") == 2, "25 hours: worn off, missed")
  DanTraits_MedTake(sc, "beta", 1)
  assert(DanTraits_MedDue(sc, "beta") == 0 and DanTraits_MedDueLevel(sc) == 0, "taken: nothing to do")
  -- every 12 hours: due at 10
  DanTraits_MedTake(sc, "anticonvulsant", 1)
  wait(10 * 60)
  assert(DanTraits_MedDue(sc, "anticonvulsant") == 1, "anticonvulsants: due at 10 hours")
  -- off it: once the effect has faded there is nothing to miss
  local off = H.player({ traits = { "heart" } }); H.current = off
  DanTraits_Data(off).meds = { beta = { lvl = 0.2, built = 0.3 } }
  assert(DanTraits_MedDue(off, "beta") == 2, "worn off with some effect left: missed")
  DanTraits_Data(off).meds.beta.built = 0
  assert(DanTraits_MedDue(off, "beta") == 0, "nothing left: off it")
  -- an old save (no note of the last dose): not due until it wears off
  DanTraits_Data(off).meds.beta = { lvl = 0.9, built = 1 }
  assert(DanTraits_MedNextIn(off, "beta") == nil and DanTraits_MedDue(off, "beta") == 0, "unknown last dose, covered: nothing due")
  -- a character who starts on it took this morning's
  local st = H.player({ traits = { "heart" } }); H.current = st
  DanTraits_MedStart(st, "beta")
  near(DanTraits_MedSince(st, "beta"), 0, 1e-9, "starting on it: dosed now")
  -- the antidepressant has its own state; a dose is still noted
  local ad = H.player({ traits = { "spiraling" } }); H.current = ad
  assert(DanTraits_MedSchedule(ad)[1] == "antidepressant", "Depression: antidepressants on the schedule")
  DanTraits_RunHooks("pill", nil, ad, "PillsAntiDep")
  near(DanTraits_MedSince(ad, "antidepressant"), 0, 1e-9, "an antidepressant dose is noted")
end

H.pass()
