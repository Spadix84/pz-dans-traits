-- Offline test for the fitness overhaul (DanTraits_FitnessData.lua, DanTraits_Fitness.lua,
-- DanTraits_FitnessActions.lua; plans/fitness-overhaul.md): load and recovery by muscle
-- group, the states and the experience they give, a pulled muscle, Pumped, stretching and
-- Loosened Up, jogging / carrying / hard work counted by themselves, overtraining, plans,
-- magazines, the hooks other systems read, and the wraps on the game's fitness action.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }
MoodleType.HEAVY_LOAD = "heavy"
BodyPartType.Torso_Upper, BodyPartType.Torso_Lower = "Torso_Upper", "Torso_Lower"
BodyPartType.UpperArm_L, BodyPartType.UpperArm_R = "UpperArm_L", "UpperArm_R"
FitnessExercises = { exercisesType = {
  squats = { type = "squats", stiffness = "legs" }, pushups = { type = "pushups", stiffness = "arms,chest" },
  situp = { type = "situp", stiffness = "abs" }, burpees = { type = "burpees", stiffness = "legs,arms,chest" },
  barbellcurl = { type = "barbellcurl", stiffness = "arms,chest", item = "Base.BarBell" },
} }

-- the game's fitness action, as far as the wraps need it
local seen = {}
ISFitnessAction = {
  start = function(self) seen.startAnim = self.exercise end,
  serverStart = function(self) seen.serverType = self.exeDataType; self.fitness:setCurrentExercise(self.exeDataType) end,
  exeLooped = function(self) seen.repDuring = DanTraits_FitRep and DanTraits_FitRep.key; self.repnb = (self.repnb or 0) + 1 end,
  animEvent = function(self, event) seen.animEvent = event end,
  update = function() end,
}

-- the action queue: H.action is at its head
ISTimedActionQueue = { getTimedActionQueue = function() return { queue = { H.action } } end }
local stopped = 0
local function fitnessAction(key)
  return { Type = "ISFitnessAction", exeDataType = key, isStarted = function() return true end, character = H.current,
           forceStop = function() stopped = stopped + 1; H.action = nil end }
end
local function stretchAction() return { Type = "ISDanTraitsStretchAction" } end

-- Age's quiet experience adjust, recorded (the real one is tested in test_age / test_xpstack)
local adjusts = {}
function DanTraits_AgeXpAdjust(player, perk, extra) adjusts[#adjusts + 1] = { perk = perk, extra = extra } end
function DanTraits_AgeXpBusy() return false end

H.load("FitnessData", "Fitness", "FitnessActions")
H.expectEvery("minute", "Fitness")
H.expectHooks("AddXP")

-- 1. the exercises added to the game's list, with the fields Java reads
local list = FitnessExercises.exercisesType
for _, key in ipairs({ "dtimprovcurl", "dtonearmcurl", "dtpress", "dtstretch", "dtjog", "dtcarry", "dtwork" }) do
  local e = list[key]
  assert(e and e.type == key and e.stiffness and e.xpMod ~= nil, key .. " added with type, stiffness and xpMod")
end
assert(list.dtimprovcurl.dtAnim == "barbellcurl" and list.dtimprovcurl.prop == "twohands", "improvised curl borrows the barbell curl")
assert(list.dtjog.dtHidden and list.dtstretch.dtCustom == "stretch", "jog hidden, stretch custom")
DanTraits_FitAddExercises()
assert(list.dtstretch.type == "dtstretch", "adding twice is harmless")
-- an exercise only the game (or another mod) knows loads its stiffness areas
local spec = DanTraits_FitExercise("situp")
assert(spec.load.core == 1 and spec.kinds[1] == "lower", "situp: core, lower")

local newPlayer = H.factory({}, function(p, o)
  p._reg, p._cur, p._incs = {}, nil, 0
  p.getFitness = function()
    return {
      init = function() end,
      getRegularity = function(_, name) return p._reg[name] or 0 end,
      getCurrentExe = function() return p._exeBusy end,
      setCurrentExercise = function(_, name) p._cur = name end,
      incRegularity = function() p._incs = p._incs + 1; p._reg[p._cur] = (p._reg[p._cur] or 0) + 0.07 end,
    }
  end
  p.getVehicle = function() return nil end
  p.isClimbing = function() return false end
  p._known = o.known or {}
  p.isRecipeActuallyKnown = function(_, r) return p._known[r] == true end
  p._met = 0
  p.getBodyDamage = (function(base)
    return function()
      local bd = base()
      bd.getThermoregulator = function() return { getMetabolicRate = function() return p._met end } end
      return bd
    end
  end)(p.getBodyDamage)
  p._stiff = {}
  p._parts = {}
  for _, n in ipairs({ "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Torso_Upper", "Torso_Lower",
                       "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }) do
    local part = { _n = n, _s = 0 }
    function part:getType() return self._n end
    function part:getStiffness() return self._s end
    function part:setStiffness(v) self._s = v end
    p._parts[#p._parts + 1] = part
  end
  local bdFn = p.getBodyDamage
  p.getBodyDamage = function()
    local bd = bdFn()
    bd.getBodyPart = function(_, t) for _, x in ipairs(p._parts) do if x._n == t then return x end end; return p._head end
    return bd
  end
  p.getXp = function() return { AddXP = function(_, perk, n) adjusts[#adjusts + 1] = { perk = perk, extra = n, direct = true } end } end
end)

-- a minute: the window's exercise does REPS_PER_MIN reps through the game's rep
-- (ISFitnessAction.exeLooped, wrapped), then the clock
local REPS_PER_MIN = 2
local function step(n)
  for _ = 1, n do
    H.hours = H.hours + 1 / 60
    for _ = 1, REPS_PER_MIN do
      local a = H.action
      if a and a.Type == "ISFitnessAction" then
        a.character = a.character or H.current
        ISFitnessAction.exeLooped(a)
      end
    end
    H.minute()
  end
end
local function data(p) return p:getModData().DanTraits end

-- 2. thirty minutes of push-ups: arms and chest loaded, logged, Pumped from 15 minutes, sore
H.hours, H.timeOfDay = 100, 12
local p = newPlayer(); H.current = p
H.action = fitnessAction("pushups")
step(14)
local d = data(p)
assert((d.ftPumpMin or 0) == 0, "not Pumped before 15 minutes")
step(16)
H.near(d.ftLoad.arms, 1.0 - 30 / 36 / 60, 0.02, "arms: a full load less half an hour's recovery")
H.near(d.ftLoad.chest, d.ftLoad.arms, 1e-9, "chest the same")
assert(d.ftLoad.legs == nil, "legs untouched")
local today = DanTraits_FitDayIndex()
assert(DanTraits_FitLog(d, today).pushups == 30, "30 minutes logged")
assert(d.ftPumpMin and d.ftPumpMin > 170, "Pumped")
assert(d.ftPumpMoodle == -2, "Pumped moodle")
assert(DanTraits_FitGroupState(p, d, "arms") == "sore", "arms sore, got " .. DanTraits_FitGroupState(p, d, "arms"))
assert(d.ftMoodle == 1, "Sore Muscles moodle level 1")
-- Pumped eases stress and mood while it runs
H.action = nil
p._st.stress, p._st.unhappy, p._st.boredom = 0.5, 50, 50
step(10)
assert(p._st.stress < 0.5 and p._st.unhappy < 50 and p._st.boredom < 50, "Pumped eases stress, mood, boredom")

-- 3. recovery: a day and a half awake clears it; asleep twice as fast
step(36 * 60)
assert(d.ftLoad.arms == nil, "recovered after 36 hours")
assert(DanTraits_FitGroupState(p, d, "arms") == "ready", "arms Ready 36 hours after training")
assert(DanTraits_FitGroupState(p, d, "legs") == "rested", "legs never trained: Rested")
local q = newPlayer(); H.current = q
q:getModData().DanTraits = { ftLoad = { legs = 0.5 }, ftLast = {}, ftLog = {} }
q._asleep = true
step(6 * 60)
H.near(data(q).ftLoad.legs, 0.5 - 6 / 36 * 2, 0.01, "asleep: twice the recovery")
q._asleep = false

-- 4. experience: a Ready group pays x1.25, a sore one x0.6, through Age's quiet adjust
H.current = p
H.action = fitnessAction("pushups")
step(1)   -- the session reaches arms and chest while they are Ready
adjusts = {}
DanTraits_FitRep = { player = p, key = "pushups" }
H.fire("AddXP", p, Perks.Strength, 10)
DanTraits_FitRep = nil
assert(#adjusts == 1 and math.abs(adjusts[1].extra - 2.5) < 1e-6, "Ready: +25% (got " .. tostring(adjusts[1] and adjusts[1].extra) .. ")")
-- the same session long past 45 minutes on the group: halved on top
step(50)
adjusts = {}
DanTraits_FitRep = { player = p, key = "pushups" }
H.fire("AddXP", p, Perks.Strength, 10)
DanTraits_FitRep = nil
H.near(adjusts[1].extra, 10 * (1.25 * 0.5 - 1), 1e-6, "past 45 minutes: x0.5")
-- a new session on sore muscles
H.action = nil
step(11)
H.action = fitnessAction("pushups")
H.rollf = 0.99   -- no strain this time
step(1)
adjusts = {}
DanTraits_FitRep = { player = p, key = "pushups" }
H.fire("AddXP", p, Perks.Strength, 10)
DanTraits_FitRep = nil
local carried = d.ftSess.carried.arms
assert(carried > 1, "carried in overworked: " .. carried)
H.near(adjusts[1].extra, 10 * (0.3 - 1), 1e-6, "Overworked going in: x0.3")
-- experience outside a rep is left alone (no magazines)
adjusts = {}
H.fire("AddXP", p, Perks.Strength, 10)
assert(#adjusts == 0, "a non-rep gain untouched")
-- Age's own top-up is not stacked on
DanTraits_AgeXpBusy = function() return true end
DanTraits_FitRep = { player = p, key = "pushups" }
H.fire("AddXP", p, Perks.Strength, 10)
DanTraits_FitRep = nil
DanTraits_AgeXpBusy = function() return false end
assert(#adjusts == 0, "Age busy: skipped")

-- 5. a pulled muscle: training overworked muscles, the roll comes up
H.rollf = 0
stopped = 0
step(1)
assert(d.ftStrain and (d.ftStrain.g == "arms" or d.ftStrain.g == "chest"), "pulled a muscle")
assert(stopped == 1, "the exercise stops")
assert(H.halo[#H.halo]:find("UI_DanTraits_FitStrained", 1, true), "notice")
step(1)
assert(d.painFloors and d.painFloors.FitStrain, "pain floor")
assert(d.ftMoodle == 3, "Pulled Muscle moodle")
local partName = d.ftStrain.part
local part
for _, x in ipairs(p._parts) do if x._n == partName then part = x end end
assert(part._s >= 30, "the part held stiff")
-- that group is off limits: push-ups stop at once and log nothing
local logged = DanTraits_FitLog(d, DanTraits_FitDayIndex()).pushups or 0
H.action = fitnessAction("pushups"); stopped = 0
step(1)
assert(stopped == 1 and (DanTraits_FitLog(d, DanTraits_FitDayIndex()).pushups or 0) == logged, "strained group refused")
-- squats are fine
H.action = fitnessAction("squats")
step(1)
assert((DanTraits_FitLog(d, DanTraits_FitDayIndex()).squats or 0) == 1, "another group trains")
H.action = nil
-- it heals in 36 hours (asleep counts double)
p._asleep = true
step(18 * 60 + 5)
p._asleep = false
assert(d.ftStrain == nil, "healed")
H.rollf = 0.99

-- strain off in the sandbox: never
local s = newPlayer(); H.current = s
SandboxVars.DanTraits.FitnessStrain = false
s:getModData().DanTraits = { ftLoad = { legs = 1.4 }, ftLast = {}, ftLog = {} }
H.rollf = 0
H.action = fitnessAction("squats")
step(5)
assert(data(s).ftStrain == nil, "FitnessStrain off: no strain")
SandboxVars.DanTraits.FitnessStrain = nil
H.rollf = 0.99
H.action = nil

-- 6. stretching: no load, recovery x2, Loosened Up after 10 minutes, stiffness hook, Arthritis eased
local st = newPlayer(); H.current = st
st:getModData().DanTraits = { ftLoad = { arms = 0.6 }, ftLast = {}, ftLog = {} }
H.action = stretchAction()
step(9)
local sd = data(st)
assert((sd.ftLooseMin or 0) == 0, "not loosened before 10 minutes")
H.near(sd.ftLoad.arms, 0.6 - 9 / 36 / 60 * 2, 1e-6, "stretching: recovery x2")
assert(DanTraits_RunHooks("stiffFade", 1, st, sd) == 2, "stiffness fades x2 while stretching")
step(1)
assert(sd.ftLooseMin == 240, "Loosened Up")
assert(sd.ftPumpMoodle == -1, "Loosened Up moodle")
assert(DanTraits_FitLog(sd, DanTraits_FitDayIndex()).dtstretch == 10, "stretch logged")
H.action = nil
step(1)
assert(DanTraits_RunHooks("stiffFade", 1, st, sd) == 1.25, "loosened: x1.25")
assert(math.abs(DanTraits_RunHooks("arthritisJoint", 1, st) - 0.9) < 1e-9, "Arthritis eased 10% while loosened")
assert(math.abs(DanTraits_RunHooks("msRelief", 1, st) - 0.9) < 1e-9, "MS eased 10% while loosened")
-- a fit body, kept up: up to 20% off at 10 / 10, by the levels
st.getPerkLevel = function() return 5 end
st:getModData().DanTraits.vitExercise = 0.5
H.near(DanTraits_FitBodyRelief(st), 0.1, 1e-9, "5 / 5, kept up: 10%")
H.near(DanTraits_RunHooks("msRelief", 1, st), 0.9 * 0.9, 1e-9, "the two together")
st:getModData().DanTraits.vitExercise = 0.25
H.near(DanTraits_FitBodyRelief(st), 0.05, 1e-9, "half kept up: half")
st.getPerkLevel = function() return 0 end

-- 7. jogging, carrying, hard work: counted, with their own regularity
local j = newPlayer(); H.current = j
j._run, j._moving = true, true
step(20)
local jd = data(j)
assert(DanTraits_FitLog(jd, DanTraits_FitDayIndex()).dtjog == 20, "20 jog minutes")
assert(j._incs == 40 and j._cur == nil, "two regularity steps a minute, current exercise cleared")
assert(jd.ftLoad.legs and jd.ftLoad.legs > 0.4, "legs loaded")
assert(jd.ftPumpMin > 0, "a 20-minute jog pumps")
-- not while the window's exercise is current
j._exeBusy = "squats"; j._incs = 0
step(1)
assert(j._incs == 0, "no regularity while another exercise is current")
j._exeBusy = nil
-- sprinting is not jogging
j._sprint = true
step(1)
assert(DanTraits_FitLog(jd, DanTraits_FitDayIndex()).dtjog == 21, "sprinting not counted")
j._sprint, j._run = false, false
-- a heavy load, moving: a carry
j._moodles = { heavy = 1 }
j.getMoodles = function() return { getMoodleLevel = function(_, t) return j._moodles[t] or 0 end } end
step(3)
assert(DanTraits_FitLog(jd, DanTraits_FitDayIndex()).dtcarry == 3, "carry minutes")
-- toward a rest day's limit and Overtrained, a jog or a carry minute is half a hard one (2026-10-23);
-- stretching and work are none
H.near(DanTraits_FitHardMinutes({ squats = 10, dtjog = 20, dtcarry = 10, dtstretch = 30, dtwork = 40 }), 10 + 10 + 5, 1e-9, "hard minutes: squats in full, jog and carry half, stretching and work not at all")
j._moodles = {}
-- hard work: a high metabolic rate standing still; no Pumped from it
local w = newPlayer(); H.current = w
w._met = 6
step(20)
local wd = data(w)
assert(DanTraits_FitLog(wd, DanTraits_FitDayIndex()).dtwork == 20, "work minutes")
assert((wd.ftPumpMin or 0) == 0, "work does not pump")
assert(wd.ftLoad.arms and wd.ftLoad.arms > 0, "work loads the arms a little")
w._met = 0

-- 8. plans: Full Body on day one, done with 20 minutes; on plan; a missed day ends it
local pl = newPlayer(); H.current = pl
H.hours = 1000
assert(DanTraits_FitSetPlan(pl, "full"), "Full Body is known to all")
assert(not DanTraits_FitSetPlan(pl, "ppl"), "Push Pull Legs needs its magazine")
local pd = data(pl)
local day0 = DanTraits_FitDayIndex()
assert(DanTraits_FitPlanDay(pd, day0) == "full", "day one: full")
H.action = fitnessAction("squats")
step(20)
H.action = nil
step(11)
assert(pd.ftOnPlan == true, "on plan once the day is done")
local function saidIt(key) for _, t in ipairs(H.halo) do if t:find(key, 1, true) then return true end end return false end
assert(saidIt("+UI_DanTraits_FitOnPlanNow"), "a notice going on plan")
adjusts = {}
pl._known = {}
-- the plan bonus lands on a rep
pd.ftSess = { carried = { legs = 0 }, ready = {}, load = {} }
DanTraits_FitRep = { player = pl, key = "squats" }
H.fire("AddXP", pl, Perks.Strength, 10)
DanTraits_FitRep = nil
H.near(adjusts[1].extra, 10 * (1.15 - 1), 1e-6, "on plan: x1.15")
-- Vitality's exercise score reads +0.1
H.near(DanTraits_RunHooks("exerciseScore", 0.5, pl, pd), 0.6, 1e-9, "exercise score +0.1 on plan")
-- day two is rest, day three full: skip day three and the plan is broken on day four
H.hours = H.hours + 24
step(1)
assert(DanTraits_FitPlanDay(pd, DanTraits_FitDayIndex()) == "rest", "day two: rest")
assert(pd.ftOnPlan == true, "a rest day keeps it")
H.hours = H.hours + 48
step(1)
assert(pd.ftOnPlan == false, "a missed full day: off plan")
assert(saidIt("UI_DanTraits_FitOffPlanNow"), "a notice going off")
assert(pd.ftMissDay == day0 + 2 and pd.ftBackDay == day0 + 5, "missed day three, back on day six")
-- the miss costs two days, not a week: day five (full) done, still off that day
H.hours = H.hours + 24
H.action = fitnessAction("squats")
step(20)
H.action = nil
step(1)
assert(pd.ftOnPlan == false, "still off the day after, job done or not")
H.clearHalo()
H.hours = H.hours + 24
step(1)
assert(pd.ftOnPlan == true and pd.ftMissDay == nil, "back on plan three days after the miss")
assert(saidIt("+UI_DanTraits_FitOnPlanNow"), "with a notice")
-- a plan never trained: off, with nothing missed to blame
local fresh = { ftPlan = "full", ftPlanStart = 50, ftLog = {} }
local on, miss = DanTraits_FitOnPlan(fresh, 50, 0)
assert(on == false and miss == nil, "not started: off, no miss")

-- a whole week done says so
local wk = newPlayer({ known = {} }); H.current = wk
H.hours = 2000
DanTraits_FitSetPlan(wk, "full")
local wkd = data(wk)
local start = wkd.ftPlanStart
for i = 0, 6 do
  local target = DanTraits_FitPlanDay(wkd, start + i)
  local log = {}
  if target == "full" then log.squats = 25 elseif target == "mobility" then log.dtstretch = 15 end
  wkd.ftLog[tostring(start + i)] = log
end
wkd.ftDay = start + 6
H.clearHalo()
H.hours = H.hours + 24 * 7
step(1)
local said = false
for _, t in ipairs(H.halo) do if t:find("FitWeekDone", 1, true) then said = true end end
assert(said and wkd.ftWeeks == 1, "a full week on the plan")

-- 9. overtraining: seven hard days in a row; two easy ones clear it
local ov = newPlayer(); H.current = ov
H.hours = 3000
local od = data(ov) or {}
ov:getModData().DanTraits = { ftLoad = {}, ftLast = {}, ftLog = {} }
od = data(ov)
local d0 = DanTraits_FitDayIndex()
od.ftDay = d0
for i = 0, 5 do od.ftLog[tostring(d0 + i)] = { squats = 110 } end
H.hours = H.hours + 24 * 6   -- six hard days finished
step(1)
assert(not od.ftOvertrained and od.ftHardStreak == 6, "six hard days: not yet")
od.ftLog[tostring(DanTraits_FitDayIndex())] = { squats = 110 }
step(1)
assert(od.ftOvertrained, "the seventh hard day: Overtrained")
assert(od.ftOverMoodle == 1, "Overtrained moodle")
H.near(DanTraits_RunHooks("nightQuality", 0.7, ov, od), 0.65, 1e-9, "nights worse")
H.near(DanTraits_RunHooks("enduranceRegen", 1, ov, od), 0.9, 1e-9, "endurance regen x0.9")
H.hours = H.hours + 24 * 3   -- the seventh day ends, then two easy days
step(1)
assert(not od.ftOvertrained, "two easy days: rested")
-- the hard day scales with the body: 40 minutes + 6 a level of Fitness and Strength
local lv = newPlayer(); lv.getPerkLevel = function(_, perk) return perk == Perks.Fitness and 2 or 3 end
assert(DanTraits_FitHardDay(lv) == 70, "2 / 3: 70 minutes")
lv.getPerkLevel = function() return 10 end
assert(DanTraits_FitHardDay(lv) == 160, "10 / 10: 160 minutes")
assert(DanTraits_FitHardDay(newPlayer()) == 100, "unread: 5 / 5, 100 minutes")
-- 25 minutes a day is not a hard day for a 5 / 5 body
local easy = newPlayer(); H.current = easy
easy:getModData().DanTraits = { ftLoad = {}, ftLast = {}, ftLog = {} }
local ed = data(easy)
local e0 = DanTraits_FitDayIndex()
ed.ftDay = e0
for i = 0, 7 do ed.ftLog[tostring(e0 + i)] = { squats = 25 } end
H.hours = H.hours + 24 * 7
step(1)
assert(not ed.ftOvertrained and (ed.ftHardStreak or 0) == 0, "a week of 25-minute sessions: not overtrained")

-- 10. magazines: Strength +10% each for the Iron Monthly pair, on any Strength gain
local mg = newPlayer({ known = { DanTraitsFitUpperLower = true, DanTraitsFitPPL = true } }); H.current = mg
step(1)
adjusts = {}
H.fire("AddXP", mg, Perks.Strength, 10)
H.near(adjusts[1].extra, 2, 1e-6, "two magazines: +20% Strength")
adjusts = {}
H.fire("AddXP", mg, Perks.Fitness, 10)
assert(#adjusts == 0, "no Fitness magazine: Fitness untouched")
assert(DanTraits_FitSetPlan(mg, "ppl"), "Push Pull Legs known from its magazine")
local strength, fitness, recovery = DanTraits_FitMagazineBonus(newPlayer({ known = {
  DanTraitsFitUpperLower = true, DanTraitsFitPPL = true, DanTraitsFitRun = true, DanTraitsFitStrongman = true, DanTraitsFitLimber = true } }))
H.near(strength, 0.25, 1e-9, "all five: Strength +25%")
H.near(fitness, 0.25, 1e-9, "all five: Fitness +25%")
H.near(recovery, 0.1, 1e-9, "Limber: recovery +10%")

-- 11. Depression reads a workout as exercise
local md = newPlayer(); H.current = md
md:getModData().DanTraits = { ftPumpMin = 60 }
assert(DanTraits_RunHooks("mddExercise", 0.2, md) == 0.8, "Pumped: exercise relief at least 0.8")
md:getModData().DanTraits.ftPumpMin = 0
assert(DanTraits_RunHooks("mddExercise", 0.2, md) == 0.2, "not Pumped: unchanged")

-- 12. the wraps: a borrowed animation at start and serverStart, the rep marked
local fit = { setCurrentExercise = function(_, k) seen.current = k end }
local action = { exercise = "dtimprovcurl", exeDataType = "dtimprovcurl", exeData = list.dtimprovcurl, fitness = fit, character = p }
ISFitnessAction.start(action)
assert(seen.startAnim == "barbellcurl" and action.exercise == "dtimprovcurl", "start plays the barbell curl, key restored")
ISFitnessAction.serverStart(action)
assert(seen.serverType == "barbellcurl" and seen.current == "dtimprovcurl" and action.exeDataType == "dtimprovcurl",
  "serverStart takes the barbell's period; regularity stays the new exercise's")
local plain = { exercise = "squats", exeDataType = "squats", exeData = list.squats, fitness = fit, character = p }
ISFitnessAction.start(plain)
assert(seen.startAnim == "squats", "a vanilla exercise is untouched")
ISFitnessAction.exeLooped(plain)
assert(seen.repDuring == "squats" and DanTraits_FitRep == nil, "the rep is marked during exeLooped only")

-- 13. the heaviest stand-in carried, at 1.5 kg or more
local function item(kg) return { getActualWeight = function() return kg end } end
local inv = { ["Base.Log"] = { item(9) }, ["Base.BucketEmpty"] = { item(1), item(11) }, ["Base.TirePiece"] = { item(3) } }
local carrier = newPlayer()
carrier.getInventory = function()
  return { getAllTypeRecurse = function(_, t)
    local l = inv[t] or {}
    return { size = function() return #l end, get = function(_, i) return l[i + 1] end }
  end }
end
local pick, kg = DanTraits_FitPickWeight(carrier, list.dtimprovcurl)
assert(pick == "Base.BucketEmpty" and kg == 11, "the full bucket is heaviest")
inv["Base.BucketEmpty"] = { item(1) }; inv["Base.Log"] = nil; inv["Base.TirePiece"] = nil
assert(DanTraits_FitPickWeight(carrier, list.dtimprovcurl) == nil, "an empty bucket does not count")

-- 14. improvised weights: experience by the kilos held
local im = newPlayer(); H.current = im
im.getPrimaryHandItem = function() return item(3) end
im.getSecondaryHandItem = function() return nil end
im:getModData().DanTraits = { ftLoad = {}, ftLast = {}, ftLog = {}, ftSess = { carried = { arms = 0, chest = 0 }, ready = {}, load = {} } }
H.near(DanTraits_FitTrainingFactor(im, data(im), "dtimprovcurl"), 0.5, 1e-9, "3 kg against a 6 kg barbell: x0.5")
im.getPrimaryHandItem = function() return item(9) end
H.near(DanTraits_FitTrainingFactor(im, data(im), "dtimprovcurl"), 1.2, 1e-9, "a 9 kg log: capped at x1.2")

-- 15. sandbox off: everything stands down
local off = newPlayer(); H.current = off
off:getModData().DanTraits = { ftLoad = { arms = 1 }, ftPumpMin = 50, ftStrain = { g = "arms", part = "UpperArm_L", h = 5 },
                                ftLog = { ["1"] = { squats = 30 } }, ftDay = 1, ftHardStreak = 6, ftPlan = "full" }
SandboxVars.DanTraits.FitnessEnabled = false
step(1)
local offd = data(off)
assert(offd.ftLoad == nil and offd.ftStrain == nil and offd.ftMoodle == 0 and offd.ftPumpMoodle == 0, "off: cleared")
-- the log, the day and the streaks go too, or a week later, back on, stale days replay with
-- their notices (2026-10-22); the plan chosen is kept
assert(offd.ftLog == nil and offd.ftDay == nil and offd.ftHardStreak == nil and offd.ftPlan == "full", "off: no stale days to replay, the plan kept")
adjusts = {}
H.fire("AddXP", mg, Perks.Strength, 10)
assert(#adjusts == 0, "off: no magazine bonus")
SandboxVars.DanTraits.FitnessEnabled = nil

-- 16. the fitness traits --------------------------------------------------------------
H.hours = 5000
local risks = {}
DanTraits_AddHook("fitnessStrain", function(risk) risks[#risks + 1] = risk; return 0 end)   -- record, and never pull

-- Well Conditioned: recovery x1.5, Ready from 14 hours, a pull heals twice as fast
local wc = newPlayer({ traits = { "wellconditioned" } }); H.current = wc
wc:getModData().DanTraits = { ftLoad = { legs = 0.5 }, ftLast = {}, ftLog = {}, ftStrain = { g = "chest", part = "Torso_Upper", h = 30 } }
step(6 * 60)
local wcd = data(wc)
H.near(wcd.ftLoad.legs, 0.5 - 6 / 36 * 1.5, 0.01, "Well Conditioned: recovery x1.5")
H.near(wcd.ftStrain.h, 30 - 6 * 2, 0.05, "Well Conditioned: a pull heals twice as fast")
wcd.ftLast.arms = H.hours - 15
assert(DanTraits_FitGroupState(wc, wcd, "arms") == "ready", "Well Conditioned: Ready at 15 hours")
local plainState = newPlayer()
assert(DanTraits_FitGroupState(plainState, { ftLoad = {}, ftLast = { arms = H.hours - 15 } }, "arms") == "rested", "anyone else: not yet at 15 hours")

-- Lingering Soreness: recovery x0.6, Ready only from 30 hours
local ls = newPlayer({ traits = { "lingeringsoreness" } }); H.current = ls
ls:getModData().DanTraits = { ftLoad = { legs = 0.5 }, ftLast = {}, ftLog = {} }
step(6 * 60)
H.near(data(ls).ftLoad.legs, 0.5 - 6 / 36 * 0.6, 0.01, "Lingering Soreness: recovery x0.6")
assert(DanTraits_FitGroupState(ls, { ftLoad = {}, ftLast = { arms = H.hours - 25 } }, "arms") == "rested", "Lingering Soreness: not Ready at 25 hours")
assert(DanTraits_FitGroupState(ls, { ftLoad = {}, ftLast = { arms = H.hours - 31 } }, "arms") == "ready", "Lingering Soreness: Ready at 31 hours")

-- Natural Runner: a jog minute counts double and loads the legs half as much; running Fitness XP x1.25
local nr = newPlayer({ traits = { "naturalrunner" } }); H.current = nr
nr._run, nr._moving = true, true
step(10)
local nrd = data(nr)
assert(DanTraits_FitLog(nrd, DanTraits_FitDayIndex()).dtjog == 20, "ten jog minutes count as twenty")
H.near(nrd.ftLoad.legs, 10 / 30 * 0.67 * 0.5, 0.01, "half the leg load")
assert(nrd.ftPumpMin and nrd.ftPumpMin > 0, "Pumped after ten minutes' jog (counted double)")
adjusts = {}
H.fire("AddXP", nr, Perks.Fitness, 10)
H.near(adjusts[1].extra, 2.5, 1e-6, "running: Fitness XP +25%")
nr._run, nr._moving = false, false
adjusts = {}
H.fire("AddXP", nr, Perks.Fitness, 10)
assert(#adjusts == 0, "not running: untouched")

-- Weightlifter: weights x1.2; improvised weights carry no extra strain risk
local pw = newPlayer({ traits = { "weightlifter" } }); H.current = pw
pw:getModData().DanTraits = { ftLoad = {}, ftLast = {}, ftLog = {}, ftSess = { carried = { arms = 0, chest = 0 }, ready = {}, load = {} } }
H.near(DanTraits_FitTrainingFactor(pw, data(pw), "barbellcurl"), 1.2, 1e-9, "Weightlifter: barbell x1.2")
H.near(DanTraits_FitTrainingFactor(pw, data(pw), "pushups"), 1, 1e-9, "Weightlifter: push-ups unchanged")
local function riskOf(player, key, load)
  H.current = player
  player:getModData().DanTraits = { ftLoad = { arms = load, chest = load, core = load, legs = load }, ftLast = {}, ftLog = {} }
  risks = {}
  H.action = fitnessAction(key)
  step(1)
  H.action = nil
  return risks[1]
end
local base = riskOf(newPlayer(), "dtimprovcurl", 0.8)
H.near(riskOf(pw, "dtimprovcurl", 0.8), base / 1.5, 1e-9, "Weightlifter: improvised no riskier than real weights")

-- Injury Prone: twice the risk; Bad Back: a pull in the core x1.5, and improvised lifts load the back
local ip = newPlayer({ traits = { "injuryprone" } })
local plainRisk = riskOf(newPlayer(), "pushups", 0.8)
H.near(riskOf(ip, "pushups", 0.8), plainRisk * 2, 1e-9, "Injury Prone: risk x2")
local bb = newPlayer({ traits = { "badback" } })
local plainCore = riskOf(newPlayer(), "situp", 0.8)
H.near(riskOf(bb, "situp", 0.8), plainCore * 1.5, 1e-9, "Bad Back: core pulls x1.5")
local backLoad = 0
DanTraits_BadBackStrain = function(_, amount) backLoad = backLoad + amount; return true end
riskOf(bb, "dtimprovcurl", 0)
H.near(backLoad, 0.008, 1e-12, "Bad Back: a minute of improvised curls loads the back")
DanTraits_BadBackStrain = nil
-- the pull itself: 54 hours for the Injury Prone
local hooks = DanTraits_Hooks.fitnessStrain
local recorder = table.remove(hooks)       -- let the roll through for this one
H.rollf = 0
riskOf(ip, "pushups", 1.2)
H.rollf = 0.99
assert(data(ip).ftStrain and data(ip).ftStrain.h > 53.9, "Injury Prone: a pull lasts 54 hours")
hooks[#hooks + 1] = recorder

-- Regimented: the plan bonus doubled, one missed day forgiven; Exercise Averse: halved
assert(math.abs(DanTraits_FitPlanBonus(newPlayer({ traits = { "regimented" } })) - 0.3) < 1e-9, "Regimented: +30%")
assert(math.abs(DanTraits_FitPlanBonus(newPlayer({ traits = { "exerciseaverse" } })) - 0.075) < 1e-9, "Exercise Averse: +7.5%")
local dd = { ftPlan = "full", ftPlanStart = 100, ftLog = { ["100"] = { squats = 25 } } }
assert(DanTraits_FitOnPlan(dd, 104, 0) == false, "day 102 missed: off plan")
assert(DanTraits_FitOnPlan(dd, 104, 1) == true, "one miss forgiven")
assert(DanTraits_FitOnPlan(dd, 106, 1) == false, "two misses: off plan even for the Regimented")

-- Exercise Averse: never Pumped; training bores and saddens
local ea = newPlayer({ traits = { "exerciseaverse" } }); H.current = ea
ea._st.boredom, ea._st.unhappy = 0, 0
H.action = fitnessAction("squats")
step(20)
H.action = nil
assert((data(ea).ftPumpMin or 0) == 0, "Exercise Averse: never Pumped")
assert(ea._st.boredom > 2.5 and ea._st.unhappy > 0.9, "Exercise Averse: bored and low after 20 minutes")

-- Inflexible: stretching keeps half its boost; stiffness lingers otherwise; Arthritis eased less, worse otherwise
local ix = newPlayer({ traits = { "inflexible" } }); H.current = ix
ix:getModData().DanTraits = { ftLoad = { arms = 0.6 }, ftLast = {}, ftLog = {} }
H.action = stretchAction()
step(4)
local ixd = data(ix)
H.near(ixd.ftLoad.arms, 0.6 - 4 / 36 / 60 * 1.5, 1e-6, "Inflexible: stretching recovers x1.5")
assert(DanTraits_RunHooks("stiffFade", 1, ix, ixd) == 1.5, "Inflexible: stiffness fades x1.5 stretching")
H.action = nil
step(1)
ixd.ftLooseMin = 0
assert(math.abs(DanTraits_RunHooks("stiffFade", 1, ix, ixd) - 0.7) < 1e-9, "Inflexible: stiffness lingers otherwise")
H.near(DanTraits_RunHooks("arthritisJoint", 1, ix), 1.1, 1e-9, "Inflexible: the joints worse")
ixd.ftLooseMin = 100
H.near(DanTraits_RunHooks("arthritisJoint", 1, ix), 0.95, 1e-9, "Inflexible, loosened: eased half as much")

-- Endorphin Junkie: Pumped six hours and twice as strong; two days without, Restless
local ej = newPlayer({ traits = { "endorphinjunkie" } }); H.current = ej
H.action = fitnessAction("squats")
step(15)
H.action = nil
local ejd = data(ej)
assert(ejd.ftPumpMin >= 359, "Endorphin Junkie: Pumped for six hours")
ej._st.stress = 0.5
step(1)
H.near(ej._st.stress, 0.5 - 0.0008, 1e-9, "twice the lift")
H.hours = H.hours + 49
ejd.ftPumpMin = 0
ej._st.boredom = 0
step(30)
assert(ejd.ftRestless and ejd.ftPumpMoodle == 1, "Restless after two days")
assert(ej._st.boredom > 0, "boredom creeps up")
H.action = fitnessAction("squats")
step(15)
H.action = nil
assert(not ejd.ftRestless and ejd.ftPumpMoodle == -2, "a workout ends it")

-- Gym Regular knows Upper/Lower
assert(DanTraits_FitSetPlan(newPlayer({ traits = { "gymregular" } }), "upperlower"), "Gym Regular: Upper/Lower known")

-- 17. what the other systems read
local ex = newPlayer(); H.current = ex
H.action = fitnessAction("burpees")
step(16)
local key, spec2 = DanTraits_FitTrainingNow(ex)
assert(key == "burpees" and spec2.breathless, "burpees now, breathless")
assert(DanTraits_FitLegMinutes(ex) == 16, "16 minutes on the legs")
H.action = nil
step(1)
assert(DanTraits_FitTrainingNow(ex) == nil, "nothing now")
H.near(DanTraits_FitAfterglow(ex), 178 / 180, 1e-9, "the afterglow fades from 1 (two minutes since the last training minute set it)")

-- 18. sets counted in reps, load by the rep, the sandbox's training pace
local rp = newPlayer(); H.current = rp
-- the window's count reaches the action at start; the set ends on its last rep, the bar counts it off
DanTraits_FitPendingReps[rp] = { reps = 3, key = "squats" }
local delta = nil
local set = { exercise = "squats", exeDataType = "squats", exeData = list.squats, character = rp, fitness = { setCurrentExercise = function() end },
              action = { setUseProgressBar = function() end }, setJobDelta = function(_, v) delta = v end }
local ended = 0
set.forceStop = function() ended = ended + 1 end
ISFitnessAction.start(set)
assert(set.dtReps == 3 and DanTraits_FitPendingReps[rp] == nil, "three reps asked for")
-- a count asked for another exercise (a set that never started) is dropped, not inherited (2026-10-22)
DanTraits_FitPendingReps[rp] = { reps = 5, key = "pushups" }
local other = { exercise = "squats", exeDataType = "squats", exeData = list.squats, character = rp, fitness = { setCurrentExercise = function() end },
                action = { setUseProgressBar = function() end } }
ISFitnessAction.start(other)
assert(other.dtReps == nil and DanTraits_FitPendingReps[rp] == nil, "a stale count for push-ups does not end a squat set")
ISFitnessAction.exeLooped(set); ISFitnessAction.update(set)
H.near(delta, 1 / 3, 1e-9, "the bar: one of three")
ISFitnessAction.exeLooped(set)
assert(ended == 0, "not yet")
ISFitnessAction.exeLooped(set)
assert(ended == 1, "the third rep ends the set")
-- a multiplayer client: the game counts reps on the server only (no exeLooped here), so the loop
-- event counts them, the muscles load and the set still ends (2026-10-22). Single-player's loop
-- event counts nothing twice
local spLegs = data(rp).ftLoad and data(rp).ftLoad.legs or 0
ISFitnessAction.animEvent(set, "ActiveAnimLooped")
assert(seen.animEvent == "ActiveAnimLooped" and ended == 1 and (data(rp).ftLoad.legs or 0) == spLegs, "single-player: the loop event is the game's alone")
isClient = function() return true end
local mpPlayer = newPlayer(); H.current = mpPlayer
DanTraits_FitPendingReps[mpPlayer] = { reps = 2, key = "squats" }
local mp = { exercise = "squats", exeDataType = "squats", exeData = list.squats, character = mpPlayer, fitness = { setCurrentExercise = function() end },
             action = { setUseProgressBar = function() end }, setJobDelta = function(_, v) delta = v end,
             isStarted = function() return true end }
local mpEnded = 0
mp.forceStop = function() mpEnded = mpEnded + 1 end
ISFitnessAction.start(mp)
assert(mp.dtReps == 2, "two reps asked for on the client")
ISFitnessAction.animEvent(mp, "ActiveAnimLooped"); ISFitnessAction.update(mp)
assert(mp.dtRepn == 1 and mpEnded == 0, "one loop: one rep counted, not over")
H.near(delta, 1 / 2, 1e-9, "the bar counts the client's reps")
assert((data(mpPlayer).ftLoad.legs or 0) > 0, "the rep loaded the legs on the client")
ISFitnessAction.animEvent(mp, "SomethingElse")
assert(mp.dtRepn == 1, "other events are not reps")
mp.isStarted = function() return false end
ISFitnessAction.animEvent(mp, "ActiveAnimLooped")
assert(mp.dtRepn == 1, "a loop before the action has started is not a rep")
mp.isStarted = function() return true end
ISFitnessAction.animEvent(mp, "ActiveAnimLooped")
assert(mp.dtRepn == 2 and mpEnded == 1, "the second loop ends the set")
isClient = function() return false end
H.current = rp
-- the same reps load the muscles alike however long they take: 50 reps of squats is 0.83 on the legs
local slow = newPlayer(); H.current = slow
for _ = 1, 50 do DanTraits_FitOnRep(slow, "squats") end
H.near(data(slow).ftLoad.legs, 50 * 0.5 / 30, 1e-9, "50 reps: a load of 0.83")
H.near(DanTraits_FitLog(data(slow), DanTraits_FitDayIndex()).squats, 25, 1e-9, "25 minutes of effort in the day's log")
-- a pulled muscle's group takes no reps
data(slow).ftStrain = { g = "legs", part = "UpperLeg_L", h = 10 }
DanTraits_FitOnRep(slow, "squats")
H.near(data(slow).ftLoad.legs, 50 * 0.5 / 30, 1e-9, "a pulled group: the rep counts for nothing")
-- the sandbox's pace: 200% doubles every Fitness and Strength gain
SandboxVars.DanTraits.FitnessXp = 200
local pace = newPlayer(); H.current = pace
adjusts = {}
H.fire("AddXP", pace, Perks.Fitness, 10)
H.near(adjusts[1].extra, 10, 1e-9, "200%: +10 on 10")
SandboxVars.DanTraits.FitnessXp = 50
adjusts = {}
H.fire("AddXP", pace, Perks.Strength, 10)
H.near(adjusts[1].extra, -5, 1e-9, "50%: half")
SandboxVars.DanTraits.FitnessXp = nil

H.pass()
