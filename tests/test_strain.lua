-- Offline test for DanTraits_Strain.lua: kills (the day's ramp, vehicles),
-- panic, new wounds, bites, low health, illness, withdrawal, hangovers; calm
-- hours, nights (bed, rough, naps, the kill count reset), comforts (once a
-- day, half the second time, debounce, home, the variety bonus), drink and
-- tobacco; the first week, the four traits and Desensitized; tiers, notices,
-- the moodle and the unhappiness floors; the experience curve and its
-- take-back; Breaking Point; the comfort watchers; the sandbox switch; and
-- that the numbers agree with plans/strain_sim.py's standard days.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }
H.load("Strain", "Moodles")
H.expectHooks("AddXP", "OnZombieDead", "OnGameStart")
H.expectEvery("minute", "Strain")
H.expectEvery("frame", "StrainKnock")

local near = H.near
local minute = H.minute
local ST = DanTraits_StrainST

-- the clock: world hours, with the time of day following them
local function at(hours)
  H.hours = hours
  H.timeOfDay = hours % 24
end

-- a player past the first week, standing still; o.hours for a newer one
local newPlayer = H.factory({ hours = 500 }, function(p, o)
  p._vehicle, p._knocked = nil, false
  p.getVehicle = function() return p._vehicle end
  p.isKnockedDown = function() return p._knocked end
  p.Say = function(_, line) p._said = line end
end)
local function data(p) return DanTraits_Data(p) end
local function strain(p) return data(p).strain or 0 end
local function setStrain(p, v) data(p).strain = v end

-- a fresh player at noon on day 100, the watchers' first look done
local function fresh(o)
  at(2400 + 12)
  local p = newPlayer(o)
  H.current = p
  minute()
  setStrain(p, 0)
  data(p).stToday = {}
  data(p).stFightH = H.hours   -- no calm credit unless a test wants it
  H.clearHalo()
  return p
end

local function halo(text)
  for _, h in ipairs(H.halo) do if h == text then return true end end
  return false
end

-- 1. kills: 0.1 x (1 + k/100), k counted since the last night
local p = fresh()
for _ = 1, 25 do DanTraits_StrainKill(p, false) end
near(strain(p), 0.1 * (25 + 25 * 26 / 200), 1e-6, "25 kills")
near(data(p).stKills, 25, 1e-9, "kills counted")
local before = strain(p)
DanTraits_StrainKill(p, true)
near(strain(p) - before, 0.1 / 3 * (1 + (25 + 1 / 3) / 100), 1e-6, "a vehicle kill is a third of one")
-- through the game's event: only the player's own kills
p = fresh()
H.fire("OnZombieDead", { getAttackedBy = function() return p end })
near(strain(p), 0.1 * 1.01, 1e-6, "OnZombieDead: the player's kill")
H.fire("OnZombieDead", { getAttackedBy = function() return {} end })
H.fire("OnZombieDead", { getAttackedBy = function() return nil end })
near(strain(p), 0.1 * 1.01, 1e-6, "someone else's kill and an unknown one cost nothing")
p._vehicle = {}
H.fire("OnZombieDead", { getAttackedBy = function() return p end })
near(data(p).stKills, 1 + 1 / 3, 1e-9, "from a car: a third of a kill")
assert(data(p).stToday.kill and data(p).stToday.vehicleKill, "the day's tally names both")

-- 2. the first week counts half; the traits; Desensitized on combat only
p = fresh({ hours = 24 })
DanTraits_StrainAdd(p, "test", 10, true)
near(strain(p), 5, 1e-9, "day two: half")
SandboxVars.DanTraits.StrainEarlyRate = 0
p = fresh({ hours = 24 })
DanTraits_StrainAdd(p, "test", 10, true)
near(strain(p), 0, 1e-9, "grace at 0%: nothing")
SandboxVars.DanTraits.StrainEarlyDays = 0
p = fresh({ hours = 24 })
DanTraits_StrainAdd(p, "test", 10, true)
near(strain(p), 10, 1e-9, "no grace days: in full")
SandboxVars.DanTraits.StrainEarlyRate, SandboxVars.DanTraits.StrainEarlyDays = nil, nil
p = fresh({ traits = { "levelheaded" } })
DanTraits_StrainAdd(p, "test", 10, false)
near(strain(p), 5, 1e-9, "Level Headed: half")
p = fresh({ traits = { "highlystrung" } })
DanTraits_StrainAdd(p, "test", 10, false)
near(strain(p), 15, 1e-9, "High Strung: x1.5")
p = fresh({ vanilla = { "base:desensitized" } })
DanTraits_StrainAdd(p, "test", 10, true)
near(strain(p), 6, 1e-9, "Desensitized: combat x0.6")
DanTraits_StrainAdd(p, "bite", 10, false)
near(strain(p), 16, 1e-9, "Desensitized: a shock in full")
SandboxVars.DanTraits.StrainGain = 200
p = fresh()
DanTraits_StrainAdd(p, "test", 10, false)
near(strain(p), 20, 1e-9, "sandbox StrainGain 200")
SandboxVars.DanTraits.StrainGain = nil

-- 3. panic over 40 with a zombie within 15 tiles costs 0.1 a minute and counts as a fight
local cellBefore = getCell
local nearZombies = {}
getCell = function()
  return { getZombieList = function()
    return { size = function() return #nearZombies end, get = function(_, i) return nearZombies[i + 1] end }
  end }
end
local function zed(x, y)
  return { getX = function() return x end, getY = function() return y end, getZ = function() return 0 end, isDead = function() return false end }
end
p = fresh({ panic = 50 })
at(H.hours + 5); data(p).stFightH = H.hours - 5
minute()
near(strain(p), 0, 1e-9, "panic with no zombie about (asthma, a hallucination): nothing")
nearZombies = { zed(20, 10) }
minute()
near(strain(p), 0.1, 1e-6, "a panicked minute in a fight")
near(data(p).stFightH, H.hours, 1e-9, "panic is a fight")
nearZombies = { zed(40, 10) }
minute()
near(strain(p), 0.1, 1e-6, "the nearest zombie 30 tiles off: not this fight")
getCell = cellBefore

-- 4. wounds: only new ones, and not on the first look
local function part(name)
  local t = { _name = name, _scratch = 0, _cut = 0, _deep = 0, _bite = 0 }
  function t:getType() return self._name end
  function t:getScratchTime() return self._scratch end
  function t:getCutTime() return self._cut end
  function t:getDeepWoundTime() return self._deep end
  function t:getBiteTime() return self._bite end
  return t
end
local arm = part("ForeArm_L")
arm._scratch = 5   -- had before the first look
p = fresh({ parts = { arm } })
minute()
near(strain(p), 0, 1e-9, "a scratch it already had costs nothing")
arm._cut = 3; minute()
near(strain(p), 2, 1e-9, "a new laceration: 2")
minute()
near(strain(p), 2, 1e-9, "the same laceration next minute: nothing more")
arm._bite = 1; minute()
near(strain(p), 52, 1e-9, "a bite: 50")
arm._scratch, arm._cut = 0, 0; minute()
arm._scratch = 2; minute()
near(strain(p), 53, 1e-9, "healed, then scratched again: 1")

-- 5. health under 25: 50, once a day
p = fresh()
p._health = 20
minute()
near(strain(p), 50, 1e-9, "near death: 50")
minute()
near(strain(p), 50, 1e-9, "once a day")
at(H.hours + 24); minute()
assert(strain(p) > 99, "the next day again")

-- 6. illness: fever, sepsis, food sickness, pain (an hour's worth at full)
p = fresh({ foodsick = 100 })
minute()
near(strain(p), 0.15 / 60, 1e-9, "a minute of full food sickness")
p = fresh({ pain = 50 })
minute()
near(strain(p), 0.5 * 0.15 / 60, 1e-9, "a minute at half pain")
DanTraits_InfectionFever = function() return 1 end
p = fresh()
data(p).infStage = 4
minute()
near(strain(p), (0.25 + 0.5) / 60, 1e-9, "a minute of full fever and sepsis")
DanTraits_InfectionFever = nil

-- 7. withdrawal: an Alcoholic sober by stage, a Smoker by withdrawal; awake only
p = fresh({ traits = { "dependent" } })
data(p).alcWithdrawing, data(p).alcStage = true, 2
minute()
near(strain(p), 0.3 / 60, 1e-9, "an Alcoholic with the shakes")
p._asleep = true; minute()
near(strain(p), 0.3 / 60, 1e-9, "not while asleep")
DanTraits_NicotineWithdrawal = function() return 0.5 end
p = fresh({ vanilla = { "base:smoker" } })
minute()
near(strain(p), 0.5 * 0.1 / 60, 1e-9, "a Smoker at half withdrawal")
p = fresh()
minute()
near(strain(p), 0, 1e-9, "not a Smoker: nothing")
DanTraits_NicotineWithdrawal = nil

-- 8. calm hours: two hours after the last fight, 0.375 an hour; half with a fever
p = fresh()
setStrain(p, 20)
at(H.hours + 1); minute()
near(strain(p), 20, 1e-9, "an hour after a fight: not calm yet")
at(H.hours + 1.5); minute()
near(strain(p), 20 - 0.375 / 60, 1e-9, "calm: a minute's worth off")
DanTraits_InfectionFever = function() return 0.4 end
setStrain(p, 20); minute()
assert(strain(p) > 20 - 0.375 / 60, "feverish: calm takes off less")
DanTraits_InfectionFever = nil

-- 9. nights: a bed x quality, rough at 2, naps nothing; the kill count starts over
p = fresh()
setStrain(p, 30); data(p).stKills = 80
p._bed = {}; p._asleep = true; minute()
p._asleep = false
DanTraits_RunHooks("nightScored", nil, p, data(p), 0.75, 8, 1, false)
near(strain(p), 30 - 3, 1e-9, "a night in bed at 0.75: 3 off")
near(data(p).stKills, 0, 1e-9, "a night's sleep starts the kill count over")
DanTraits_RunHooks("nightScored", nil, p, data(p), 1, 1, 1, true)
near(strain(p), 27, 1e-9, "a nap: nothing")
minute()   -- awake
p._bed = nil; p._asleep = true; minute(); p._asleep = false
DanTraits_RunHooks("nightScored", nil, p, data(p), 1, 8, 1, false)
near(strain(p), 25, 1e-9, "sleeping rough: 2")

-- 10. comforts: once a day, half the second time, debounced; x1.5 at home
p = fresh()
setStrain(p, 50)
near(DanTraits_StrainComfort(p, "shower"), 2, 1e-9, "a shower: 2")
near(DanTraits_StrainComfort(p, "shower"), 0, 1e-9, "the same shower again: nothing")
at(H.hours + 1)
near(DanTraits_StrainComfort(p, "shower"), 1, 1e-9, "a second shower: half")
at(H.hours + 1)
near(DanTraits_StrainComfort(p, "shower"), 0, 1e-9, "a third: nothing")
at(H.hours + 24)
near(DanTraits_StrainComfort(p, "shower"), 2, 1e-9, "the next day: in full again")
DanTraits_HomeStrength = function() return 1 end
p = fresh(); setStrain(p, 50); data(p).hmAtHome = true
near(DanTraits_StrainComfort(p, "laundry"), 3, 1e-9, "at home: x1.5")
p = fresh({ traits = { "homebody" } }); setStrain(p, 50); data(p).hmAtHome = true
near(DanTraits_StrainComfort(p, "laundry"), 4, 1e-9, "a Homebody at home: x2")
-- the full day off (the design's target: about 30 with sleep and calm hours)
p = fresh(); setStrain(p, 80); data(p).hmAtHome = true
local eased = 0
for _, c in ipairs({ { "shower", 2 }, { "laundry", 2 }, { "meal", 3 }, { "read", 2 }, { "pumped", 2 } }) do
  eased = eased + DanTraits_StrainComfort(p, c[1], c[2])
  at(H.hours + 1)
end
near(eased, 11 * 1.5 * 1.25, 1e-9, "five comforts at home with the variety bonus")
assert(halo("+UI_DanTraits_StrainDayOff"), "the day off is told")
p = fresh({ traits = { "cantswitchoff" } }); setStrain(p, 80)
for _, k in ipairs({ "shower", "laundry", "meal", "read" }) do DanTraits_StrainComfort(p, k, 2); at(H.hours + 1) end
assert(not data(p).stVariety, "Can't Switch Off: four is not enough")
p = fresh({ traits = { "unwindseasily" } }); setStrain(p, 50)
near(DanTraits_StrainComfort(p, "shower"), 3, 1e-9, "Unwinds Easily: x1.5")
DanTraits_HomeStrength = nil

-- 11. drink: by Drunk level, up to 8 a day; an Alcoholic's a quarter
p = fresh({ intox = 40 })   -- Drunk 2
setStrain(p, 50)
minute()
near(strain(p), 50 - 2 / 60, 1e-9, "a minute drunk")
data(p).stDrink = 8; minute()
near(strain(p), 50 - 2 / 60, 1e-9, "the day's cap reached")
p = fresh({ intox = 40, traits = { "dependent" } }); setStrain(p, 50)
minute()
near(strain(p), 50 - 0.25 * 2 / 60, 1e-9, "an Alcoholic: a quarter")
-- tobacco through the eat hook
DanTraits_NicotineOf = function(kind) if kind == "Cigarettes" then return 1, true end return nil end
p = fresh(); setStrain(p, 50)
DanTraits_RunHooks("eat", nil, p, { getType = function() return "Cigarettes" end }, 1)
near(strain(p), 50 - 0.75, 1e-9, "a cigarette: 0.75")
for _ = 1, 5 do DanTraits_RunHooks("eat", nil, p, { getType = function() return "Cigarettes" end }, 1) end
near(strain(p), 50 - 3, 1e-9, "up to 3 a day")
p = fresh({ vanilla = { "base:smoker" } }); setStrain(p, 50)
DanTraits_RunHooks("eat", nil, p, { getType = function() return "Cigarettes" end }, 1)
near(strain(p), 50 - 0.75 * 0.25, 1e-9, "a Smoker: a quarter")
DanTraits_RunHooks("eat", nil, p, { getType = function() return "Apple" end }, 1)
near(strain(p), 50 - 0.75 * 0.25, 1e-9, "food is not tobacco")
DanTraits_NicotineOf = nil

-- 12. the watchers: a new Good Meal, Pumped, fresh clothes, an hour of reading, a hangover
p = fresh(); setStrain(p, 50)
data(p).ckGlow = { tier = 3, min = 300, max = 300 }; minute()
near(strain(p), 46, 1e-9, "a Chef's meal: 4")
data(p).ckGlow.min = 299; minute()
near(strain(p), 46, 1e-9, "the same afterglow running down: nothing")
data(p).ftPumpMin = 180; minute()
near(strain(p), 44, 1e-9, "Pumped: 2")
data(p).lnMoodle = 1; minute()
data(p).lnMoodle = -1; minute()
near(strain(p), 42, 1e-9, "into fresh clothes: 2")
ISTimedActionQueue = { getTimedActionQueue = function() return { queue = { { Type = "ISReadABook" } } } end }
H.mins(59)
near(strain(p), 42, 1e-9, "59 minutes of reading: not yet")
minute()
-- the fourth different comfort today: 2 x1.25, and a quarter of the 8 before it
near(strain(p), 42 - 2.5 - 2, 1e-9, "an hour of reading: 2, and the day-off bonus")
ISTimedActionQueue = nil
data(p).hoActive = true; minute()
near(strain(p), 37.5 + 2, 1e-9, "a hangover: 2 on")
-- after a load, what is already running does not count
p = fresh()
data(p).stWatched = nil
data(p).ckGlow = { tier = 2, min = 100, max = 300 }; data(p).ftPumpMin = 50; data(p).lnMoodle = -1
setStrain(p, 50); minute()
near(strain(p), 50, 1e-9, "a loaded save: nothing counted twice")
-- washing
p = fresh(); setStrain(p, 50)
near(DanTraits_StrainWashed(p), 2, 1e-9, "a wash or a bath: a shower's worth")

-- 13. tiers, notices, the moodle, the floors
p = fresh()
DanTraits_StrainAdd(p, "test", 30, false)
assert(halo("UI_DanTraits_Strain1"), "Frayed told")
minute()
near(DanTraits_MoodleLevels(p, data(p)).Strain, 1, 0, "moodle: Frayed")
DanTraits_StrainAdd(p, "test", 30, false)
assert(halo("UI_DanTraits_Strain2"), "Worn Down told")
p._st.unhappy = 0
H.mins(60)
near(p._st.unhappy, 15, 1e-6, "Worn Down holds unhappiness at 15")
setStrain(p, 5); data(p).stFightH = H.hours - 5; H.clearHalo()
DanTraits_StrainEase(p, "test", 1)
assert(halo("+UI_DanTraits_StrainAtEase"), "At Ease told after a bad stretch")
minute()
near(DanTraits_MoodleLevels(p, data(p)).Strain, -1, 0, "moodle: At Ease")

-- 14. experience: the curve, half for other skills over 50, x1.1 at ease
local sword = { getParent = function() return "Combat" end }
local rifle = { getParent = function() return "Firearm" end }
local cooking = { getParent = function() return "Crafting" end }
assert(DanTraits_StrainIsCombatPerk(sword) and DanTraits_StrainIsCombatPerk(rifle), "weapons and firearms are combat")
assert(DanTraits_StrainIsCombatPerk(Perks.Strength) and DanTraits_StrainIsCombatPerk(Perks.Fitness), "Strength and Fitness too")
assert(not DanTraits_StrainIsCombatPerk(cooking), "cooking is not")
p = fresh()
local function mult(s, perk) setStrain(p, s); return DanTraits_StrainXpMult(p, perk) end
near(mult(5, sword), 1.1, 1e-9, "at ease: x1.1")
near(mult(5, cooking), 1, 1e-9, "at ease: other skills x1")
near(mult(20, sword), 1, 1e-9, "under 25: x1")
near(mult(50, sword), 0.75, 1e-9, "50: x0.75")
near(mult(75, sword), 0.4, 1e-9, "75: x0.4")
near(mult(100, sword), 0.15, 1e-9, "100: x0.15")
near(mult(50, cooking), 1, 1e-9, "other skills: untouched up to 50")
near(mult(75, cooking), 0.7, 1e-9, "other skills at 75: half the penalty")
SandboxVars.DanTraits.StrainXpFloor = 50
near(mult(100, sword), 0.5, 1e-9, "the sandbox floor")
SandboxVars.DanTraits.StrainXpFloor = nil
-- the take-back, through Age's quiet adjust
local adjusted = {}
DanTraits_AgeXpAdjust = function(_, perk, extra) adjusted[#adjusted + 1] = { perk, extra } end
DanTraits_AgeXpBusy = function() return false end
setStrain(p, 75)
H.fire("AddXP", p, sword, 10)
near(adjusted[1][2], -6, 1e-9, "x0.4 at 75: 6 of 10 taken back")
setStrain(p, 5)
H.fire("AddXP", p, sword, 10)
near(adjusted[2][2], 1, 1e-9, "at ease: 1 added")
setStrain(p, 20)
H.fire("AddXP", p, sword, 10)
assert(#adjusted == 2, "x1: nothing to adjust")
DanTraits_AgeXpBusy = function() return true end
setStrain(p, 75)
H.fire("AddXP", p, sword, 10)
assert(#adjusted == 2, "Age's own top-up is left alone")
DanTraits_AgeXpAdjust, DanTraits_AgeXpBusy = nil, nil

-- 15. Breaking Point: held at 100 until a safe moment, then the breakdown, then 60
local queued = {}
ISTimedActionQueue = { clear = function() end, add = function(a) queued[#queued + 1] = a end,
                       getTimedActionQueue = function() return { queue = {} } end }
ISStrainBreakdownAction = { new = function(_, player) return { character = player } end }
local zombies = {}
getCell = function()
  return { getZombieList = function()
    return { size = function() return #zombies end, get = function(_, i) return zombies[i + 1] end }
  end }
end
local function zombie(x, y)
  return { getX = function() return x end, getY = function() return y end, getZ = function() return 0 end, isDead = function() return false end }
end
p = fresh()
DanTraits_StrainAdd(p, "test", 120, false)
near(strain(p), 100, 1e-9, "capped at 100")
assert(data(p).stBreak == "pending" and halo("UI_DanTraits_StrainBreaking"), "the breakdown is coming")
near(DanTraits_StrainEase(p, "test", 10), 0, 1e-9, "nothing eases it until it happens")
minute()
assert(#queued == 0, "five minutes after a fight: not yet")
near(DanTraits_MoodleLevels(p, data(p)).Strain, 4, 0, "moodle: Breaking Point")
at(H.hours + 1); zombies = { zombie(15, 10) }
minute()
assert(#queued == 0, "a zombie five tiles off: not safe")
zombies = { zombie(40, 40) }
minute()
assert(#queued == 1, "calm and alone: it comes")
DanTraits_StrainBreakdownStart(p)
assert(data(p).stBreak == "active" and p._said, "it starts: a line said")
DanTraits_StrainBreakdownStop(p)
assert(data(p).stBreak == "pending", "walked away: it comes again")
zombies = { zombie(12, 12) }
assert(DanTraits_StrainDanger(p), "a zombie within four tiles stops it")
zombies = {}
DanTraits_StrainBreakdownStart(p)
DanTraits_StrainBreakdownDone(p)
near(strain(p), 60, 1e-9, "done: down to 60")
assert(data(p).stBreak == nil and halo("+UI_DanTraits_StrainBrokeDown"), "over, and told")
SandboxVars.DanTraits.StrainBreakdown = false
p = fresh()
DanTraits_StrainAdd(p, "test", 120, false)
assert(data(p).stBreak == nil, "Breaking Point off: no breakdown")
SandboxVars.DanTraits.StrainBreakdown = nil
ISTimedActionQueue, ISStrainBreakdownAction = nil, nil

-- 16. knocked down: 1.5, once per fall
p = fresh()
p._knocked = true
H.frame(p); H.frame(p)
near(strain(p), 1.5, 1e-9, "knocked down: 1.5 once")
p._knocked = false; H.frame(p); p._knocked = true; H.frame(p)
near(strain(p), 3, 1e-9, "down again: 1.5 more")

-- 17. the sandbox switch: nothing tracked, the moodle out, experience the game's
SandboxVars.DanTraits.StrainEnabled = false
p = fresh({ panic = 90 })
DanTraits_StrainKill(p, false)
minute()
near(strain(p), 0, 1e-9, "off: nothing gained")
near(DanTraits_MoodleLevels(p, data(p)).Strain, 0, 0, "off: no moodle")
near(DanTraits_StrainXpMult(p, sword), 1, 0, "off: experience untouched")
SandboxVars.DanTraits.StrainEnabled = nil

-- 18. the design's standard days (plans/strain_sim.py)
local function outing(kills, panicMin, wounds)
  local q = fresh()
  for _ = 1, kills do DanTraits_StrainKill(q, false) end
  DanTraits_StrainAdd(q, "panic", ST.PANIC * panicMin, true)
  for _, w in ipairs(wounds) do DanTraits_StrainAdd(q, w, ST.WOUND[w] or ST.KNOCK, true) end
  return strain(q)
end
near(outing(25, 10, { "scratch" }), 4.8, 0.05, "quiet supply run: about +5")
near(outing(75, 30, { "scratch", "scratch", "cut" }), 17.35, 0.05, "busy day: about +17")
near(outing(150, 60, { "scratch", "scratch", "scratch", "cut", "cut", "knock" }), 40.8, 0.05, "horde day: about +41")

-- 19. phase 2: the links
-- the conditions' factor
p = fresh()
near(DanTraits_StrainFactor(p), 1, 1e-9, "no strain: x1")
setStrain(p, 75)
near(DanTraits_StrainFactor(p), 2, 1e-9, "Burnt Out: x2")
SandboxVars.DanTraits.StrainEnabled = false
near(DanTraits_StrainFactor(p), 1, 1e-9, "strain off: x1")
SandboxVars.DanTraits.StrainEnabled = nil
-- Endorphin Junkie's Pumped, Homemaker's fresh clothes and Line-Dried, Keen Cook's meal
p = fresh({ traits = { "endorphinjunkie" } }); setStrain(p, 50)
near(DanTraits_StrainComfort(p, "pumped"), 4, 1e-9, "Endorphin Junkie: Pumped x2")
p = fresh({ traits = { "homemaker" } }); setStrain(p, 50)
near(DanTraits_StrainComfort(p, "laundry"), 4, 1e-9, "Homemaker: fresh clothes x2")
data(p).lnMoodle = 0; minute()
data(p).lnMoodle = -2; minute()
near(data(p).stToday["comfort:linedried"] or 0, -2, 1e-9, "Homemaker: Line-Dried, a comfort of its own")
p = fresh(); setStrain(p, 50); data(p).lnMoodle = 0; minute(); data(p).lnMoodle = -2; minute()
assert(not (data(p).stToday["comfort:linedried"]), "anyone else: Line-Dried is just fresh clothes")
p = fresh({ vanilla = { "base:cook" } }); setStrain(p, 50)
data(p).ckGlow = { tier = 1, min = 180, max = 180 }; minute()
near(strain(p), 47, 1e-9, "Keen Cook: a Home-cooked meal counts as Hearty (3)")
-- a depressive episode: comforts at half, but not a meal or a workout
p = fresh({ traits = { "spiraling" } }); setStrain(p, 50); data(p).mddEpisode = true
near(DanTraits_StrainComfort(p, "shower"), 1, 1e-9, "an episode: a shower at half")
near(DanTraits_StrainComfort(p, "pumped"), 2, 1e-9, "an episode: a workout in full")
near(DanTraits_StrainComfort(p, "meal", 3), 3, 1e-9, "an episode: a meal in full")
-- a Nomad: a bed slept in twice is home for comforts
DanTraits_HomePlaceOf = function(q) return { x = q._x or 10, y = 10 } end
DanTraits_HomeSamePlace = function(a, b) return a and b and a.x == b.x and a.y == b.y end
DanTraits_HomeAtPlace = function(home, x, y) return home.x == x and home.y == y end
p = fresh({ traits = { "nomad" } }); setStrain(p, 80)
p.getX = function() return p._x or 10 end
local function nightHere()
  p._bed = {}; p._asleep = true; minute(); p._asleep = false
  DanTraits_RunHooks("nightScored", nil, p, data(p), 1, 8, 1, false); minute()
end
nightHere()
near(DanTraits_StrainComfort(p, "shower"), 2, 1e-9, "a Nomad, one night here: no home bonus")
nightHere()
at(H.hours + 24)
near(DanTraits_StrainComfort(p, "shower"), 3, 1e-9, "two nights in this bed: x1.5")
p._x = 50
near(DanTraits_StrainComfort(p, "laundry"), 2, 1e-9, "somewhere else: no bonus")
DanTraits_HomePlaceOf, DanTraits_HomeSamePlace, DanTraits_HomeAtPlace = nil, nil, nil
-- Vitality's target
p = fresh(); setStrain(p, 80)
near(DanTraits_RunHooks("vitalityTarget", 0.9, p, data(p)), 0.79, 1e-9, "Burnt Out: under Thriving")
setStrain(p, 30)
near(DanTraits_RunHooks("vitalityTarget", 0.9, p, data(p)), 0.9, 1e-9, "Frayed: left alone")
setStrain(p, 5)
near(DanTraits_RunHooks("vitalityTarget", 0.5, p, data(p)), 0.55, 1e-9, "At Ease: lifted")

-- 20. the health panel's summary: the tier and the last hour's way
p = fresh()
DanTraits_StrainAdd(p, "test", 30, false)
data(p).stMarkMin, data(p).stMark = 59, 20
minute()
local sum = DanTraits_StrainSummary(p)
assert(sum.moodle == 1 and sum.way == "rising", "summary: Frayed and rising")

-- 21. the console
DanTraits_StrainLevel(p)
local out = DanTraits_ExtraCommands.strain(p, { "set", "42" })
assert(out:find("strain 42.0", 1, true), "console: set and report (" .. out .. ")")

H.pass()
