-- Offline test for the muscle relaxant (DanTraits_Relaxant.lua, the "cyclobenzaprine"
-- entry in DanTraits_Meds.lua): the bottle is on the medication list, one tablet covers
-- about 8 hours, drowsy while it works and far drowsier drunk, stiffness fades twice as
-- fast, a pulled muscle's pain floor and held stiffness halve (DanTraits_Fitness.lua's
-- strainRelief), a Bad Back's relief factor (backRelief), less training experience and a
-- likelier pull, and nothing once it wears off (with its notice).
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = { MedSideEffectChance = 0 } }
UIManager = { FadeOut = function() end, FadeIn = function() end }
MoodleType.HEAVY_LOAD = "heavy"
for _, n in ipairs({ "Torso_Upper", "Torso_Lower", "UpperArm_L", "UpperArm_R" }) do BodyPartType[n] = n end
ISTimedActionQueue = { getTimedActionQueue = function() return { queue = {} } end }

H.load("Faint", "Meds", "FitnessData", "Fitness", "Relaxant")
H.expectEvery("minute", "Relaxant")

local newPlayer = H.factory({}, function(p)
  p.getVehicle = function() return nil end
  p.getFitness = function() return { init = function() end, getCurrentExe = function() return nil end,
    setCurrentExercise = function() end, incRegularity = function() end, getRegularity = function() return 0 end } end
  p._parts = {}
  for _, n in ipairs({ "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Torso_Upper", "Torso_Lower",
                       "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }) do
    local part = { _s = 0 }
    function part:getStiffness() return self._s end
    function part:setStiffness(v) self._s = v end
    p._parts[n] = part
  end
  local bdFn = p.getBodyDamage
  p.getBodyDamage = function()
    local bd = bdFn()
    bd.getBodyPart = function(_, t) return p._parts[t] end
    bd.getThermoregulator = function() return { getMetabolicRate = function() return 0 end } end
    return bd
  end
  p._moodles = {}
  p.getMoodles = function() return { getMoodleLevel = function(_, t) return p._moodles[t] or 0 end } end
end)

local function step(n)
  for _ = 1, n do
    H.hours = H.hours + 1 / 60
    H.minute()
  end
end

H.hours, H.timeOfDay = 100, 12

-- 1. on the list: the bottle's type is the drug; anyone can take it
assert(DanTraits_DrugOfItem("Cyclobenzaprine") == "cyclobenzaprine", "the bottle is the drug")
local p = newPlayer(); H.current = p
local d = DanTraits_Data(p)
assert(not DanTraits_RelaxantOn(p), "not taken: off")
H.near(DanTraits_RunHooks("stiffFade", 1, p, d), 1, 1e-12, "not taken: stiffness as usual")
DanTraits_RunHooks("pill", nil, p, "Cyclobenzaprine")
assert(DanTraits_RelaxantOn(p), "a tablet: on")

-- 2. what it is for, while covered
H.near(DanTraits_RunHooks("stiffFade", 1, p, d), 2, 1e-12, "stiffness fades twice as fast")
H.near(DanTraits_RunHooks("strainRelief", 1, p, d), 0.5, 1e-12, "a pulled muscle: half")
H.near(DanTraits_RunHooks("backRelief", 1, p, d, false), 0.5, 1e-12, "a Bad Back: half")
H.near(DanTraits_RunHooks("backRelief", 1, p, d, true), 0.65, 1e-12, "thrown out: a third off")
H.near(DanTraits_RunHooks("fitnessXp", 1, p, d, "pushups"), 0.85, 1e-12, "training on it: x0.85")
H.near(DanTraits_RunHooks("fitnessStrain", 0.01, p, d, {}), 0.015, 1e-12, "a pull half as likely again")

-- 3. a pulled muscle, through Fitness: the pain floor and the held stiffness halve
d.ftStrain = { g = "arms", part = "UpperArm_L", h = 30 }
step(1)
H.near(d.painFloors.FitStrain.floor, 12.5, 1e-9, "the pull's pain floor: 25 halved")
H.near(p._parts.UpperArm_L._s, 15, 1e-9, "held at 15 stiffness, not 30")
H.near(d.ftStrain.h, 30 - 1 / 60, 1e-9, "and it heals no sooner")

-- 4. drowsy while it works, far drowsier drunk; asleep, nothing extra
p._st.fatigue = 0
step(60)
local sober = p._st.fatigue
H.near(sober, 60 * 0.0003, 1e-6, "an hour awake: the drowsiness")
p._moodles.drunk = 1
p._st.fatigue = 0
step(60)
H.near(p._st.fatigue, 60 * (0.0003 + 0.0008), 1e-6, "with a drink: much drowsier")
p._moodles.drunk = 0

-- 5. about 8 hours, then it wears off with a notice and does nothing
H.clearHalo()
step(6 * 60 - 1)
assert(DanTraits_RelaxantOn(p), "still working at 8 hours")
step(10)
assert(not DanTraits_RelaxantOn(p), "worn off just after 8 hours")
local said = false
for _, t in ipairs(H.halo) do if t == "UI_DanTraits_RelaxantLapse" then said = true end end
assert(said, "with its notice")
H.near(DanTraits_RunHooks("strainRelief", 1, p, d), 1, 1e-12, "worn off: the pull hurts again")
step(1)
H.near(p._parts.UpperArm_L._s, 30, 1e-9, "and stiffens again")

-- 6. too many at once: the overdose, with the heart strain Heart Condition reads
local o = newPlayer(); H.current = o
for _ = 1, 3 do DanTraits_RunHooks("pill", nil, o, "Cyclobenzaprine") end
step(1)
assert(DanTraits_MedHeartStrain(o), "three at once: a racing heart")

H.pass()
