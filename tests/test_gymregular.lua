-- Offline test for DanTraits_GymRegular.lua: a new character with the trait
-- has every exercise's regularity raised to 50 through the fitness system's
-- own incRegularity, once, without lowering anything a profession gave.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = { gymregular = "gymregular" }
FitnessExercises = { exercisesType = { squats = {}, pushups = {}, situp = {}, burpees = {}, barbellcurl = {}, dumbbellpress = {}, bicepscurl = {} } }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_GymRegular" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.OnCreatePlayer and handlers.OnGameStart, "hooks in place")

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

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or { "gymregular" }) do traits[t] = true end
  local md = {}
  local fitness = makeFitness(o.preset)
  return { hasTrait = function(_, t) return traits[t] == true end, isDead = function() return false end,
    getModData = function() return md end, getHoursSurvived = function() return o.hours or 0 end,
    getFitness = function() return fitness end, _md = md, _fit = fitness }
end
local current
function getSpecificPlayer() return current end

-- 1. fresh character: every exercise at 50 or a hair over, one init, done flag set, exercise cleared after
local p = makePlayer(); handlers.OnCreatePlayer(0, p)
for name in pairs(FitnessExercises.exercisesType) do
  local v = p._fit:getRegularity(name)
  assert(v >= 50 and v < 50.1, name .. " at 50, got " .. v)
end
assert(p._fit._inits == 1, "init called once")
assert(p._fit._current == nil, "current exercise cleared")
assert(p._md.DanTraits.gymRegularApplied == true, "marked applied")
local incs = p._fit._incs
assert(incs > 7 * 700 and incs < 7 * 740, "about 726 steps per exercise, got " .. incs)

-- 2. once only: a second creation event and game start add nothing
handlers.OnCreatePlayer(0, p); current = p; handlers.OnGameStart()
assert(p._fit._incs == incs, "not applied twice")

-- 3. a profession preset above 50 is kept, one below is topped up, nothing lowered
local pro = makePlayer({ preset = { squats = 58, pushups = 41 } }); handlers.OnCreatePlayer(0, pro)
assert(pro._fit:getRegularity("squats") == 58, "58 left alone")
assert(pro._fit:getRegularity("pushups") >= 50 and pro._fit:getRegularity("pushups") < 50.1, "41 topped up to 50")
assert(pro._fit:getRegularity("burpees") >= 50, "others filled")

-- 4. no trait: nothing; not a new character: nothing
local none = makePlayer({ traits = {} }); handlers.OnCreatePlayer(0, none)
assert(none._fit._incs == 0 and none._fit._inits == 0, "no trait: untouched")
local old = makePlayer({ hours = 5 }); handlers.OnCreatePlayer(0, old)
assert(old._fit._incs == 0, "existing character: untouched")

-- 5. fitness not ready at creation: not marked done, retried at game start
local late = makePlayer(); late._fit._broken = true
handlers.OnCreatePlayer(0, late)
assert(not (late._md.DanTraits or {}).gymRegularApplied, "failure is not marked applied")
late._fit._broken = false; late._fit._map = {}
current = late; handlers.OnGameStart()
assert(late._fit:getRegularity("situp") >= 50 and late._md.DanTraits.gymRegularApplied, "applied on the retry")

-- 6. a stuck incRegularity (value not moving) ends instead of spinning
local stuck = makePlayer(); stuck._fit.incRegularity = function(self) self._incs = self._incs + 1 end
handlers.OnCreatePlayer(0, stuck)
assert(stuck._fit._incs == 7, "one probe per exercise, then stop; got " .. stuck._fit._incs)
assert(not stuck._md.DanTraits.gymRegularApplied, "stuck: not marked applied")

print("test_gymregular: all passed")
