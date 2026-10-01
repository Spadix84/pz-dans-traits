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
assert(DanTraits_DrugOfItem("Pills") == nil, "painkillers are not on the list")
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

H.pass()
