-- Offline test for DanTraits_Alcohol.lua: a drink no longer counts as a
-- beta blocker and a painkiller; instead the Drunk moodle floors the body's
-- pain reduction by level and speeds panic decay each tick. DanTraits_Diabetes
-- is loaded too: both wrap ISDrinkFluidAction.updateEat, and the meds restore
-- and the `drink` hook must both work (they once shared a guard flag, so only
-- one of them was ever installed).
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = { INTOXICATION = { getMaximumValue = function() return 100 end }, PANIC = "panic", PAIN = "pain", STRESS = "stress", UNHAPPINESS = "unhappy", FATIGUE = "fatigue", ENDURANCE = "endurance", FOOD_SICKNESS = "foodsick", THIRST = "thirst", WETNESS = { getMaximumValue = function() return 100 end } }
-- stubs the Diabetes file wants at load (copied from test_diabetes.lua)
BodyPartType = { Groin = "Groin", ForeArm_L=1, ForeArm_R=2, LowerLeg_L=3, LowerLeg_R=4, Hand_L=5, Hand_R=6, Torso_Upper=7 }
ArrayList = { new = function() return { add = function() end } end }
IsoFireManager = { explode = function() end }
function instanceof() return false end
ItemBodyLocation = { MASK = "mask", MASK_EYES = "maskeyes", MASK_FULL = "maskfull" }
function getWorld() return { getFreeEmitter = function() return { playSound = function() return 1 end, setPos = function() end } end } end
function getTexture() return "TEX" end
function getGameTime() return { getHour = function() return 12 end } end
function ZombRand() return 0 end
function getClimateManager() return { getAirTemperatureForCharacter = function() return 20 end } end
function getCell() return { getGridSquare = function() return { getObjects = function() return { size = function() return 0 end } end, getDeadBodys = function() return { size = function() return 0 end } end } end } end
function addSound() end
function isNight() return false end
DanTraitsTestCharge = false
FitnessExercises = { exercisesType = { squats = {}, pushups = {}, situps = {}, burpees = {} } }
MoodleType = { DRUNK = "drunk" }
GameTime = { getInstance = function() return { getThirtyFPSMultiplier = function() return 1 end } end }
HaloTextHelper = { addBadText = function() end, addGoodText = function() end }
function getText(k) return k end
DanTraitsRegistry = {}
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }

-- vanilla-shaped drink action: updateEat reaches DrinkFluid, which for any
-- alcohol at all sets the beta-blocker and painkiller timers in full; the
-- container also loses a sip, as the real fluid container does
ISDrinkFluidAction = {}
function ISDrinkFluidAction:updateEat(delta)
  self.character:DrinkFluid(self.fluidContainer, delta)
  self.fluidContainer._amount = self.fluidContainer._amount - 0.1
end

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Diabetes", "DanTraits_Alcohol" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.EveryOneMinute and handlers.OnPlayerUpdate, "hooks in place")
local drinkWraps = ISDrinkFluidAction.DanTraitsWraps
assert(drinkWraps and drinkWraps["updateEat:alcohol-relief"] and drinkWraps["updateEat:drink-intake"], "both drink layers installed")

local function makePlayer(o)
  o = o or {}
  local st = { panic = 0, pain = 0, intox = 0 }
  local md = {}
  local p = { isDead = function() return false end, isAsleep = function(self) return self._asleep end,
    getModData = function() return md end,
    getStats = function() return { get = function(_, k) if k == CharacterStat.INTOXICATION then return st.intox end return st[k] end,
                                   set = function(_, k, v) st[k] = v end } end,
    getBodyDamage = function(self) return { getPainReduction = function() return self._pr end, setPainReduction = function(_, v) self._pr = v end } end,
    getBetaEffect = function(self) return self._beta end, setBetaEffect = function(self, v) self._beta = v end,
    getBetaDelta = function(self) return self._betaD end, setBetaDelta = function(self, v) self._betaD = v end,
    getPainEffect = function(self) return self._painFx end, setPainEffect = function(self, v) self._painFx = v end,
    getPainDelta = function(self) return self._painD end, setPainDelta = function(self, v) self._painD = v end,
    DrinkFluid = function(self, container, delta)
      local alcohol = container:getProperties():getAlcohol()
      if alcohol > 0 then
        self._beta, self._betaD = 6600, self._betaD + 0.2 * alcohol
        self._painFx, self._painD = 5400, self._painD + 0.2 * alcohol
      end
    end,
    _st = st, _md = md, _asleep = false, _pr = 0, _beta = 0, _betaD = 0, _painFx = 0, _painD = 0, _level = nil }
  if not o.noMoodles then
    p.getMoodles = function(self) return { getMoodleLevel = function() return self._level end } end
  end
  return p
end
local function container(alcohol)
  return { _amount = 1, getAmount = function(self) return self._amount end,
           getProperties = function() return { getAlcohol = function() return alcohol end, getCarbohydrates = function() return 0 end } end }
end
local lastContainer
local function drink(p, alcohol)
  lastContainer = container(alcohol)
  ISDrinkFluidAction.updateEat({ character = p, fluidContainer = lastContainer }, 0.1)
end
local drinkHook = {}
DanTraits_AddHook("drink", function(_, player, fluid, litres) drinkHook[#drinkHook + 1] = { player = player, fluid = fluid, litres = litres } end)
local current
function getSpecificPlayer() return current end
local minute, frame = handlers.EveryOneMinute, handlers.OnPlayerUpdate
local function near(a, b, eps, msg) assert(math.abs(a - b) <= eps, msg .. ": expected " .. b .. ", got " .. a) end

-- 1. a sip of whiskey no longer sets the pill timers
local p = makePlayer(); current = p; p._level = 0
drink(p, 0.004)
assert(p._beta == 0 and p._betaD == 0, "beta-blocker timer put back")
assert(p._painFx == 0 and p._painD == 0, "painkiller timer put back")

-- 1b. and the Diabetes layer on the same method still ran: the drink hook fired with the litres swallowed
assert(#drinkHook == 1 and drinkHook[1].player == p and drinkHook[1].fluid == lastContainer and math.abs(drinkHook[1].litres - 0.1) < 1e-9,
  "drink hook fired once with player, fluid and litres")

-- 2. pills taken earlier keep working
p._beta, p._betaD, p._painFx, p._painD = 3000, 1, 2000, 1
drink(p, 0.4)
assert(p._beta == 3000 and p._betaD == 1 and p._painFx == 2000 and p._painD == 1, "earlier pills untouched")

-- 3. a soft drink is left alone (the wrapper only steps in for alcohol)
local soft = makePlayer(); current = soft; soft._level = 0
soft.DrinkFluid = function(self) self._painFx = 7 end   -- some other effect on the character
drink(soft, 0)
assert(soft._painFx == 7, "non-alcoholic: nothing restored")
assert(#drinkHook == 3 and drinkHook[3].player == soft, "every drink (pills-taken case included) fires the drink hook, soft drinks too")

-- 4. pain: the reduction floor follows the Drunk level, steps down as you sober, keeps other sources
current = p
p._level = 2; minute(); near(p._pr, 40, 1e-9, "level 2: 40")
p._level = 4; minute(); near(p._pr, 80, 1e-9, "level 4: 80")
p._pr = p._pr + 10                                       -- a medicinal fluid's own reduction
p._level = 3; minute(); near(p._pr, 70, 1e-9, "level 3 with 10 from elsewhere: 60 + 10")
p._pr = p._pr - 0.3                                       -- vanilla decay over the minute
p._level = 1; minute(); near(p._pr, 29.7, 1e-9, "level 1: 20 + the other 9.7")
p._level = 0; minute(); near(p._pr, 9.7, 1e-9, "sober: only the other source is left")
assert(p._md.DanTraits.alcPainCut == 0, "bookkeeping cleared")
minute(); near(p._pr, 9.7, 1e-9, "sober and nothing applied: not touched")

-- 5. panic: level 4 takes the beta-blocker rate (0.6 a tick), level 1 a quarter of it; not while asleep or sober
p._st.panic = 50; p._level = 4; frame(p); near(p._st.panic, 49.4, 1e-9, "level 4: 0.6")
p._level = 1; frame(p); near(p._st.panic, 49.25, 1e-9, "level 1: 0.15")
p._asleep = true; frame(p); near(p._st.panic, 49.25, 1e-9, "asleep: none"); p._asleep = false
p._level = 0; frame(p); near(p._st.panic, 49.25, 1e-9, "sober: none")
p._st.panic = 0.1; p._level = 4; frame(p); assert(p._st.panic == 0, "clamped at zero")

-- 6. no moodle API: the level comes from intoxication (10/30/50/70)
local q = makePlayer({ noMoodles = true }); current = q
q._st.intox = 5; assert(DanTraits_DrunkLevel(q) == 0, "5%: sober")
q._st.intox = 15; assert(DanTraits_DrunkLevel(q) == 1, "15%: tipsy")
q._st.intox = 55; assert(DanTraits_DrunkLevel(q) == 3, "55%: level 3")
q._st.intox = 90; minute(); near(q._pr, 80, 1e-9, "90%: level 4 floor")

print("test_alcohol: all passed")
