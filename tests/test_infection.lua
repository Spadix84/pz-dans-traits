-- Offline test for DanTraits_Infection.lua: the chance a wound takes an
-- infection (by wound, dressing, clothes, cleaning, traits); contamination
-- and cleaning it off; local growth, topical treatment under the spread
-- level only, and held healing; the whole-body score, fever (SICKNESS),
-- sepsis health loss; antibiotics (vanilla's pill, level and half-life,
-- missed doses, unfinished course and relapse); vanilla's own infection
-- and one-shot antibiotic undone; the sandbox switch; the commands.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local later = {}

H.load("Infection")
function DanTraits_Later(_, fn) later[#later + 1] = fn end
local function runLater() for _, fn in ipairs(later) do fn() end later = {} end
H.expectEvery("minute", "Infection")

local function makePart(name)
  local p = { _name = name, _t = { scratch = 0, cut = 0, deep = 0, bite = 0, burn = 0, stitch = 0 }, _alcohol = 0, _garlic = 0,
    _bandaged = false, _life = 0, _dirtyBandage = false, _dirty = false, _bloody = false, _glass = false,
    _infected = false, _level = 0 }
  function p:getType() return self._name end
  function p:getScratchTime() return self._t.scratch end
  function p:setScratchTime(v) self._t.scratch = v end
  function p:getCutTime() return self._t.cut end
  function p:setCutTime(v) self._t.cut = v end
  function p:getDeepWoundTime() return self._t.deep end
  function p:setDeepWoundTime(v) self._t.deep = v end
  function p:getBiteTime() return self._t.bite end
  function p:getBurnTime() return self._t.burn end
  function p:getStitchTime() return self._t.stitch end
  function p:haveGlass() return self._glass end
  function p:haveBullet() return false end
  function p:getAlcoholLevel() return self._alcohol end
  function p:getGarlicFactor() return self._garlic end
  function p:bandaged() return self._bandaged end
  function p:getBandageLife() return self._life end
  function p:isBandageDirty() return self._dirtyBandage end
  p._bandageType = "Base.Bandage"
  function p:getBandageType() return self._bandageType end
  function p:hasDirtyClothing() return self._dirty end
  function p:hasBloodyClothing() return self._bloody end
  function p:isInfectedWound() return self._infected end
  function p:setInfectedWound(b) self._infected = b end
  function p:getWoundInfectionLevel() return self._level end
  function p:setWoundInfectionLevel(v) self._level = v end
  return p
end

-- two parts, and the game's infection-power timer that the antibiotic sets
local build = H.factory(nil, function(p)
  p._parts[1], p._parts[2] = makePart("Hand_L"), makePart("ForeArm_L")
  p._rip = 0
  p.getReduceInfectionPower = function() return p._rip end
  p.setReduceInfectionPower = function(_, v) p._rip = v end
end)
local function newPlayer(vanillaTraits) return build({ vanilla = vanillaTraits }) end
local halo, near, mins = H.halo, H.near, H.mins
local minute = H.minute
local function D(p) return p._md.DanTraits end
local function arm(p) return p._parts[2] end

-- 1. hazard per game hour, by wound and care
local p = newPlayer(); H.current = p
local a = arm(p)
assert(DanTraits_InfectionHazard(p, a) == 0, "no wound, no chance")
a._t.deep = 10; near(DanTraits_InfectionHazard(p, a), 0.04, 1e-12, "open deep wound: 4%/h")
a._t.scratch = 5; near(DanTraits_InfectionHazard(p, a), 0.05, 1e-12, "plus a scratch")
a._t.scratch = 0; a._glass = true; near(DanTraits_InfectionHazard(p, a), 0.10, 1e-12, "a shard left in")
a._glass = false; a._bandaged, a._life = true, 3; near(DanTraits_InfectionHazard(p, a), 0.02, 1e-12, "clean bandage: half")
a._bandageType = "Base.AlcoholBandage"; assert(DanTraits_InfectionHazard(p, a) == 0, "a fresh alcohol bandage: none"); a._bandageType = "Base.Bandage"
a._life = 0; near(DanTraits_InfectionHazard(p, a), 0.12, 1e-12, "spent bandage: x3")
a._bandaged = false; a._dirty, a._bloody = true, true; near(DanTraits_InfectionHazard(p, a), 0.04 * 2.25, 1e-12, "dirty and bloody clothes")
a._dirty, a._bloody = false, false
near(DanTraits_InfectionHazard(p, a, { clean = true }), 0.008, 1e-12, "disinfected once: a fifth")
a._alcohol = 2; assert(DanTraits_InfectionHazard(p, a) == 0, "alcohol still on it: none"); a._alcohol = 0
a._t.deep, a._t.stitch = 0, 20; near(DanTraits_InfectionHazard(p, a), 0.02, 1e-12, "stitched: half a deep wound")
local prone = newPlayer({ "base:pronetoillness" }); arm(prone)._t.deep = 10
near(DanTraits_InfectionHazard(prone, arm(prone)), 0.052, 1e-12, "Prone to Illness x1.3")
local tough = newPlayer({ "base:resilient" }); arm(tough)._t.deep = 10
near(DanTraits_InfectionHazard(tough, arm(tough)), 0.028, 1e-12, "Resilient x0.7")

-- 2. taking hold: contaminated (hidden) first, then local
p = newPlayer(); H.current = p; a = arm(p); a._t.deep = 10
H.rollf = 0.99; mins(30); assert(D(p).infParts.ForeArm_L == nil, "unlucky rolls: nothing")
H.rollf = 0; minute(); H.rollf = 0.99
local rec = D(p).infParts.ForeArm_L
near(rec.inc, 12 * 60, 1e-9, "contaminated: twelve hours (the middle of 8-16) to show")
assert(D(p).infStage == 1 and a._level == 0 and not a._infected, "hidden: nothing on the health panel")
mins(12 * 60)
near(D(p).infParts.ForeArm_L.L, 1, 1e-9, "shows at level 1")
assert(a._infected and a._level == 1 and D(p).infStage == 2, "local: on the panel")
assert(halo[#halo] == "UI_DanTraits_InfectionLocal", "notice")

-- 3. cleaning during contamination ends it, and marks the wound cleaned
p = newPlayer(); H.current = p; a = arm(p); a._t.deep = 10
H.rollf = 0; minute(); H.rollf = 0.99
assert(D(p).infParts.ForeArm_L.inc, "contaminated")
a._alcohol = 4; minute()
rec = D(p).infParts.ForeArm_L
assert(rec.inc == nil and (rec.L or 0) == 0 and rec.clean, "disinfected: gone, and remembered as cleaned")

-- 4. vanilla's own infection is cleared, its one-shot antibiotic undone
p = newPlayer(); H.current = p; a = arm(p); a._t.cut = 5
a._infected, a._level = true, 0.3; p._rip = 50; minute()
assert(not a._infected and a._level == 0 and p._rip == 0, "vanilla's roll and antibiotic undone")

-- 5. local growth, topical treatment works under the spread level only, healing held
p = newPlayer(); H.current = p; a = arm(p); a._t.deep = 10
DanTraits_ExtraCommands.infect(p, { "forearm_l", "2" })
mins(720); near(D(p).infParts.ForeArm_L.L, 3, 1e-6, "half a day untreated: +1")
a._t.deep = 8; minute(); assert(a._t.deep == 10, "infected wound does not heal")
a._garlic = 1; mins(480); near(D(p).infParts.ForeArm_L.L, 3 + 2 / 1440 - 3 * 480 / 1440, 1e-6, "garlic pushes it back")
a._garlic = 0; D(p).infParts.ForeArm_L.L = 6; a._alcohol = 4; minute()
assert(D(p).infParts.ForeArm_L.L > 6, "past the spread level, disinfectant does nothing"); a._alcohol = 0

-- 6. spreading: the whole body; fever from SICKNESS, sepsis takes health
p = newPlayer(); H.current = p; a = arm(p); a._t.deep = 10
DanTraits_ExtraCommands.infect(p, { "forearm_l", "10" })
minute(); near(D(p).infS, 0.6 / 1440, 1e-9, "level 10: 0.6 a day")
DanTraits_ExtraCommands.infect(p, { "forearm_l", "5" }); D(p).infS = 0; minute()
near(D(p).infS, 0.6 / 1440 / 6, 1e-6, "level 5: a sixth of that (the level grew a hair first)")
DanTraits_ExtraCommands.sepsis(p, { "0.3" }); DanTraits_ExtraCommands.infect(p, { "forearm_l", "7" }); minute()
assert(D(p).infStage == 3 and halo[#halo] == "UI_DanTraits_InfectionFever", "fever at 0.2+")
near(p._st.sickness, 0.2 + 0.7 * (D(p).infS - 0.2) / 0.8, 1e-6, "SICKNESS from the score")
assert(p._st.fatigue > 0 and p._st.thirst > 0, "tired and thirsty")
-- the fever eases: SICKNESS comes down with it, not just up
local high = p._st.sickness; D(p).infS = 0.25; minute()
assert(p._st.sickness < high, "SICKNESS follows the fever down")
D(p).infS = 0.1; DanTraits_ExtraCommands.infect(p, { "forearm_l", "1" }); minute()
assert(p._st.sickness == 0, "no fever: SICKNESS back to 0")
D(p).infS = 0.3; minute(); p._st.sickness = 0.7; minute()
near(p._st.sickness, 0.7, 1e-9, "someone else's higher sickness is theirs")
p._st.sickness = 0; DanTraits_ExtraCommands.infect(p, { "forearm_l", "7" })
local h = p._health; D(p).infS = 0.8; minute()
near(h - p._health, 0.15 + 1.35 * ((D(p).infS - 0.6) / 0.4), 1e-3, "sepsis takes health")
assert(D(p).infStage == 4, "sepsis stage")
-- sepsis is delirium: a phantom episode from the Hallucinations set, awake, at a small chance a minute
local heard = 0
DanTraits_Episodes = { whisper = function() heard = heard + 1 end, footsteps = function() heard = heard + 1 end,
  sound = function() heard = heard + 1 end, thump = function() heard = heard + 1 end }
H.rollf = 0.99; D(p).infS = 0.8; minute(); assert(heard == 0, "no roll, no delirium")
H.rollf = 0.01; minute(); assert(heard == 1, "sepsis: an episode on a hit")
D(p).infS = 0.5; minute(); assert(heard == 1, "fever alone is not delirium")
D(p).infS = 0.8; p._asleep = true; minute(); assert(heard == 1, "asleep: none")
p._asleep = false
DanTraits_Episodes = nil; D(p).infS = 0.8; minute()
H.rollf = 0.99

-- 7. antibiotics: vanilla's pill is a dose; the level halves every 6 h; therapeutic from 0.5
p = newPlayer(); H.current = p; a = arm(p); a._t.deep = 10
DanTraits_ExtraCommands.infect(p, { "forearm_l", "7" }); D(p).infS = 0.5
p._rip = 0
DanTraits_RunHooks("eat", nil, p, { getType = function() return "Antibiotics" end }, 1)
p._rip = 50; runLater(); assert(p._rip == 0, "vanilla's one-shot undone after the eat")
assert(D(p).infAbx == 1 and D(p).infDoses == 1, "a dose")
local L0, S0 = D(p).infParts.ForeArm_L.L, D(p).infS
mins(60); near(D(p).infParts.ForeArm_L.L, L0 - 4 / 24, 1e-6, "on antibiotics: level falls 4 a day")
near(D(p).infS, S0 - 0.4 / 24, 1e-6, "and the whole body 0.4 a day")
mins(5 * 60); near(D(p).infAbx, 0.5, 1e-3, "six hours: halved")
local L1 = D(p).infParts.ForeArm_L.L; mins(60)
assert(D(p).infParts.ForeArm_L.L > L1, "a missed dose: it picks up again")

-- 8. fever breaks under antibiotics; cleared before a full course, then stopped: relapse
p = newPlayer(); H.current = p; a = arm(p); a._t.deep = 10
DanTraits_ExtraCommands.infect(p, { "forearm_l", "1" }); D(p).infS = 0.25
minute(); assert(D(p).infStage == 3, "fever")
for _ = 1, 3 do DanTraits_TakeAntibiotic(p, 1); mins(8 * 60) end
assert(string.find(halo[#halo], "UI_DanTraits_InfectionFeverBreaks", 1, true), "fever breaks (a good notice where DanTraits_NotifyGood exists)")
assert(D(p).infParts.ForeArm_L == nil and D(p).infS == 0, "cleared")
assert(D(p).infUnfinished, "three doses: unfinished course")
-- the last dose is still working for a couple of hours, then 24 h off; the
-- wound has closed, so nothing new can take
a._t.deep = 0
H.rollf = 0; mins(27 * 60); H.rollf = 0.99
assert(D(p).infFocus and D(p).infFocus > 0 and halo[#halo] == "UI_DanTraits_InfectionRelapse", "relapse, inside")
local F = D(p).infFocus; DanTraits_TakeAntibiotic(p, 1); mins(60); assert(D(p).infFocus < F, "antibiotics work on it")

-- 9. a finished course: no relapse
p = newPlayer(); H.current = p; a = arm(p); a._t.deep = 10
DanTraits_ExtraCommands.infect(p, { "forearm_l", "1" })
for _ = 1, 10 do DanTraits_TakeAntibiotic(p, 1); mins(8 * 60) end
assert(not D(p).infUnfinished, "ten doses: finished")
a._t.deep = 0
H.rollf = 0; mins(48 * 60); H.rollf = 0.99
assert(not D(p).infFocus, "no relapse")

-- 10. a small infection on a wound that closes goes with it; SICKNESS ours only
p = newPlayer(); H.current = p; a = arm(p); a._t.scratch = 3
DanTraits_ExtraCommands.infect(p, { "forearm_l", "1" }); minute()
a._t.scratch = 0; minute(); assert(D(p).infParts.ForeArm_L == nil and not a._infected, "closed: cleared")
p._st.sickness = 0.4; minute(); assert(p._st.sickness == 0.4, "someone else's sickness is left alone")

-- 11. the sandbox switch
SandboxVars = { DanTraits = { InfectionEnabled = false } }
p = newPlayer(); H.current = p; a = arm(p); a._t.cut = 5; a._infected, a._level = true, 2; minute()
assert(a._infected and a._level == 2, "off: vanilla's infection stands")
SandboxVars = nil

-- 12. commands
p = newPlayer(); H.current = p
assert(string.find(DanTraits_ExtraCommands.contaminate(p, { "forearm_l", "5" }), "shows in 5 min", 1, true), "contaminate")
assert(DanTraits_ExtraCommands.infect(p, { "tail" }) == "infect <part> [level 0..10]", "usage")
assert(DanTraits_ExtraCommands.infection(p, { "clear" }) == "infection cleared" and D(p).infS == 0, "clear")

-- 13. the hook subscribers: hazard and growth move by the stated factor, and
-- say nothing without their trait. Loaded only now: Vitality runs for
-- everyone and would drift the earlier sections' numbers.
H.load("Diabetes", "Vitality", "Anemia", "Smoker")
p = newPlayer(); H.current = p; a = arm(p); a._t.deep = 10
near(DanTraits_RunHooks("infectionGrowth", 1, p), 1, 1e-12, "nobody special: growth untouched")
local function subject(o) local q = build(o); H.current = q; arm(q)._t.deep = 10; return q end
local dia = subject({ traits = { "diabetes1" } }); DanTraits_Data(dia).glucose = 180
near(DanTraits_InfectionHazard(dia, arm(dia)), 0.04, 1e-12, "Diabetes at 180: no effect")
DanTraits_Data(dia).glucose = 350
near(DanTraits_InfectionHazard(dia, arm(dia)), 0.08, 1e-12, "Diabetes at 350: hazard x2")
near(DanTraits_RunHooks("infectionGrowth", 1, dia), 1.5, 1e-12, "Diabetes at 350: growth x1.5")
DanTraits_Data(dia).glucose = 265
near(DanTraits_RunHooks("infectionGrowth", 1, dia), 1.25, 1e-12, "Diabetes halfway up the band: x1.25")
DanTraits_Data(dia).glucose = 350
DanTraits_ExtraCommands.infect(dia, { "forearm_l", "2" }); minute()
near(D(dia).infParts.ForeArm_L.L - 2, 2 / 1440 * 1.5, 1e-5, "Diabetes: the level itself climbs x1.5 a minute")
local vit = subject({}); DanTraits_Data(vit).vitality = 1.0
near(DanTraits_InfectionHazard(vit, arm(vit)), 0.03, 1e-12, "Thriving: hazard x0.75")
near(DanTraits_RunHooks("infectionGrowth", 1, vit), 0.75, 1e-12, "Thriving: growth x0.75")
DanTraits_Data(vit).vitality = 0.0
near(DanTraits_InfectionHazard(vit, arm(vit)), 0.05, 1e-12, "Run Down: hazard x1.25")
near(DanTraits_RunHooks("infectionGrowth", 1, vit), 1.25, 1e-12, "Run Down: growth x1.25")
DanTraits_Data(vit).vitality = 0.5
near(DanTraits_InfectionHazard(vit, arm(vit)), 0.04, 1e-12, "neutral Vitality: hazard untouched")
local ane = subject({ traits = { "anemia" } }); DanTraits_Data(ane).anIron = 0
near(DanTraits_RunHooks("infectionGrowth", 1, ane), 1.3, 1e-12, "no iron: growth x1.3")
near(DanTraits_InfectionHazard(ane, arm(ane)), 0.04, 1e-12, "iron does not touch the hazard")
DanTraits_Data(ane).anIron = 0.8
near(DanTraits_RunHooks("infectionGrowth", 1, ane), 1, 1e-12, "plenty of iron: untouched")
local smk = subject({ vanilla = { "base:smoker" } }); DanTraits_Data(smk).nicMeter = 1
near(DanTraits_RunHooks("infectionGrowth", 1, smk), 1.2, 1e-12, "Smoker at a full meter: growth x1.2")
DanTraits_Data(smk).nicMeter = 0.5
near(DanTraits_RunHooks("infectionGrowth", 1, smk), 1.1, 1e-12, "half a meter: x1.1")
local ex = subject({}); DanTraits_Data(ex).nicMeter = 1
near(DanTraits_RunHooks("infectionGrowth", 1, ex), 1, 1e-12, "a meter without the trait: untouched")

-- 14. Vitality's own hooks (its effect stubbed): the body clears an infection with nothing spreading x (1 + 0.3 e)
local vitE = 0
DanTraits_VitalityEffect = function() return vitE end
for _, case in ipairs({ { 1, 1.3 }, { -1, 0.7 }, { 0, 1 } }) do
  vitE = case[1]
  p = build({}); H.current = p; DanTraits_Data(p).infS = 0.5
  minute(); near(0.5 - D(p).infS, 0.2 / 1440 * case[2], 1e-9, "fight x" .. case[2] .. " at e = " .. case[1])
end
vitE = 1; p = build({}); H.current = p; arm(p)._t.deep = 10
near(DanTraits_InfectionHazard(p, arm(p)), 0.03, 1e-12, "stubbed e = 1: hazard x0.75")
vitE = -1; near(DanTraits_InfectionHazard(p, arm(p)), 0.05, 1e-12, "stubbed e = -1: hazard x1.25")

H.pass()
