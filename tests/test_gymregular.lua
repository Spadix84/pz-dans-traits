-- Offline test for DanTraits_GymRegular.lua: a new character with the trait
-- has every exercise's regularity raised to 50 through the fitness system's
-- own incRegularity, once, without lowering anything a profession gave.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
FitnessExercises = { exercisesType = { squats = {}, pushups = {}, situp = {}, burpees = {}, barbellcurl = {}, dumbbellpress = {}, bicepscurl = {} } }
H.load("GymRegular")
H.expectHooks("OnCreatePlayer", "OnGameStart")

-- a Fitness mock that behaves like the game's: init() applies a profession
-- preset once into an empty map, incRegularity adds a fixed step to the
-- current exercise and caps at 100
local function makeFitness(preset)
  local f = { _map = {}, _inits = 0, _incs = 0, _current = nil, _broken = false }
  function f:init()
    self._inits = self._inits + 1
    if next(self._map) == nil then for k, v in pairs(preset or {}) do self._map[k] = v end end
  end
  function f:getRegularity(name) return self._map[name] or 0 end
  function f:setCurrentExercise(name) self._current = name end
  function f:incRegularity()
    if self._broken then error("no current exercise") end
    assert(self._current, "incRegularity with no current exercise")
    self._incs = self._incs + 1
    self._map[self._current] = math.min(100, (self._map[self._current] or 0) + 0.0689)
  end
  return f
end

local newPlayer = H.factory({ traits = { "gymregular" } }, function(p, o)
  local fitness = makeFitness(o.preset)
  p._fit = fitness
  p.getFitness = function() return fitness end
end)

-- 1. fresh character: every exercise at 50 or a hair over, one init, done flag set, exercise cleared after
local p = newPlayer(); H.fire("OnCreatePlayer", 0, p)
for name in pairs(FitnessExercises.exercisesType) do
  local v = p._fit:getRegularity(name)
  assert(v >= 50 and v < 50.1, name .. " at 50, got " .. v)
end
assert(p._fit._inits == 1, "init called once")
assert(p._fit._current == nil, "current exercise cleared")
assert(p._md.DanTraits.gymApplied == true, "marked applied")
local incs = p._fit._incs
assert(incs > 7 * 700 and incs < 7 * 740, "about 726 steps per exercise, got " .. incs)

-- 2. once only: a second creation event and game start add nothing
H.fire("OnCreatePlayer", 0, p); H.current = p; H.fire("OnGameStart")
assert(p._fit._incs == incs, "not applied twice")

-- 3. a profession preset above 50 is kept, one below is topped up, nothing lowered
local pro = newPlayer({ preset = { squats = 58, pushups = 41 } }); H.fire("OnCreatePlayer", 0, pro)
assert(pro._fit:getRegularity("squats") == 58, "58 left alone")
assert(pro._fit:getRegularity("pushups") >= 50 and pro._fit:getRegularity("pushups") < 50.1, "41 topped up to 50")
assert(pro._fit:getRegularity("burpees") >= 50, "others filled")

-- 4. no trait: nothing; not a new character: nothing
local none = newPlayer({ traits = {} }); H.fire("OnCreatePlayer", 0, none)
assert(none._fit._incs == 0 and none._fit._inits == 0, "no trait: untouched")
local old = newPlayer({ hours = 5 }); H.fire("OnCreatePlayer", 0, old)
assert(old._fit._incs == 0, "existing character: untouched")

-- 5. fitness not ready at creation: not marked done, retried at game start
local late = newPlayer(); late._fit._broken = true
H.fire("OnCreatePlayer", 0, late)
assert(not (late._md.DanTraits or {}).gymApplied, "failure is not marked applied")
late._fit._broken = false; late._fit._map = {}
H.current = late; H.fire("OnGameStart")
assert(late._fit:getRegularity("situp") >= 50 and late._md.DanTraits.gymApplied, "applied on the retry")

-- 6. a stuck incRegularity (value not moving) ends instead of spinning
local stuck = newPlayer(); stuck._fit.incRegularity = function(self) self._incs = self._incs + 1 end
H.fire("OnCreatePlayer", 0, stuck)
assert(stuck._fit._incs == 7, "one probe per exercise, then stop; got " .. stuck._fit._incs)
assert(not stuck._md.DanTraits.gymApplied, "stuck: not marked applied")

H.pass()
