-- Shared harness for the offline tests (run by fengari, standard Lua 5.3).
-- Every test starts with
--
--   local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
--
-- which finds this file next to the test wherever it is run from (`cd tests`
-- or the repo root). Then, in this order: H.events(), H.stubs(), any stub the
-- test needs different (set it after H.stubs()), H.load(...), and the test.
--
--   H.events([opts])   install Events. Add appends to H.handlers[name] (a
--                      list, in registration order), Remove takes one out.
--                      opts.absent = { Name = true } keeps Events.Name nil
--                      until something assigns it (the story test).
--   H.fire(name, ...)  call every handler registered for name, in order.
--   H.on(name)         a function that fires name (for `local minute = ...`).
--   H.only(name)       assert exactly one handler is registered; return it.
--   H.expectHooks(...) assert each named event has a handler ("hooks in place").
--   H.minute()         fire core's one EveryOneMinute handler (it runs every loaded
--   H.ten()            system in DanTraits_Every order); H.ten fires EveryTenMinutes.
--   H.frame(player)    fire core's one OnPlayerUpdate handler for that player (the
--                      frame systems run on it, like a frame of the game).
--   H.expectEvery(cadence, label)  assert the loaded file registered that system
--                      with DanTraits_Every ("minute" | "ten" | "frame").
--   H.stubs()          the common game stubs (see the list in the function).
--                      Knobs: H.halo (every notice; good ones are "+" prefixed;
--                      H.clearHalo() empties it in place), H.rng (a queue of
--                      ZombRand results, used first), H.roll (ZombRand once the
--                      queue is empty, default 0), H.rollf (ZombRandFloat(0, 1),
--                      default 0.99: nothing chance-based fires), H.rolls (how
--                      often ZombRand was called), H.now (getTimestampMs),
--                      H.hours (world age in game hours), H.climate,
--                      H.corpses, H.sounds, H.current (the player that
--                      getSpecificPlayer returns).
--   H.load(...)        load mod files. A short name ("Smoker" or
--                      "DanTraits_Smoker") comes from lua/shared, and the core
--                      is loaded first if it is not already. A name with a
--                      slash ("client/DanTraits_Telemetry.lua") is relative to
--                      lua/ and loads on its own.
--   H.player(opts)     a fake player, a superset of what the tests needed:
--                      opts.traits / opts.vanilla (one set: hasTrait, and
--                      getCharacterTraits with add, remove, get, getKnownTraits),
--                      opts.st = { stat = value } plus the stat names as
--                      shortcuts (stress = 0.5), asleep, outside, sprint, run,
--                      hours, health, parts, weight, regularity, moodles (a
--                      table, else the player has no moodle API), noMoodles,
--                      painReduction (the body's pain reduction, default 0).
--                      Fields for assertions: _st (stats by short name), _md,
--                      _traits, _health, _pr, _painFx, _asleep, _inv, _dropped,
--                      _coughs, _woke, _bump, _vars, _carry, _catch, _adds.
--   H.factory(defaults, decorate)  a player constructor with defaults merged
--                      under the caller's opts, and decorate(p, opts) to add
--                      what only one test needs.
--   H.near(a, b, eps, msg), H.mins(n[, fn]) (fn defaults to H.minute),
--   H.pass([name]) prints "<name>: all checks passed".
local H = {}

local here = (debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]")) or "."
H.root = here .. "/../DanTraits/42/media/lua"

H.handlers = {}
H.halo = {}
H.rng = {}
H.roll = 0
H.rollf = 0.99
H.rolls = 0
H.now = 0
H.hours = 100
H.corpses = 0
H.sounds = {}
H.climate = { temp = 20, rain = 0, humidity = 0.5, night = 1, cloud = 0 }

-- events ---------------------------------------------------------------------

function H.events(opts)
  opts = opts or {}
  H.handlers = {}
  local handlers = H.handlers
  local events
  events = setmetatable({}, { __index = function(_, name)
    if opts.absent and opts.absent[name] then return nil end
    local e = {
      Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end,
      Remove = function(f)
        local list = handlers[name]
        if not list then return end
        for i, g in ipairs(list) do if g == f then table.remove(list, i); return end end
      end,
    }
    rawset(events, name, e)
    return e
  end })
  Events = events
  return handlers
end

function H.fire(name, ...)
  local list = H.handlers[name]
  if not list then return end
  local copy = {}
  for i, f in ipairs(list) do copy[i] = f end
  for _, f in ipairs(copy) do f(...) end
end

function H.on(name)
  return function(...) return H.fire(name, ...) end
end

function H.only(name)
  local list = H.handlers[name]
  assert(list and #list == 1, name .. ": expected exactly one handler, have " .. tostring(list and #list or 0))
  return list[1]
end

function H.expectHooks(...)
  for _, name in ipairs({ ... }) do
    assert(H.handlers[name] and #H.handlers[name] > 0, "hooks in place: " .. name)
  end
end

-- the clock drivers: core registers one handler per cadence (DanTraits_Every)
-- the pain stat as the game builds it from the head's additional pain (the
-- pain floors write there; see DanTraits_Util.lua): part pain x ratio, less
-- the body's pain reduction. setPain puts the head where the stat reads v.
local function headOf(p) return p:getBodyDamage():getBodyPart("Head") end
function H.pain(p)
  local v = (headOf(p):getAdditionalPain() or 0) * DanTraits_PAIN_PART_RATIO - (p._pr or 0)
  return math.floor(math.max(0, v) * 1e6 + 0.5) / 1e6
end
function H.setPain(p, v)
  local part = v > 0 and (v + (p._pr or 0)) / DanTraits_PAIN_PART_RATIO or 0
  headOf(p):setAdditionalPain(part)
  -- the floors ramp from what they last applied; start them from here
  local d = p._md.DanTraits
  if d and d.painAdd then d.painAdd = part end
end

function H.minute() return H.only("EveryOneMinute")() end
function H.ten() return H.only("EveryTenMinutes")() end
function H.frame(player) return H.only("OnPlayerUpdate")(player) end

function H.expectEvery(cadence, label)
  for _, e in ipairs(DanTraits_Drivers[cadence] or {}) do
    if e.label == label then return end
  end
  error("DanTraits_Every: nothing registered for " .. cadence .. " " .. label, 2)
end

-- stubs ----------------------------------------------------------------------

-- CharacterStat entries: constant name, the short name the fake player keeps
-- it under, the game's maximum
local STATS = {
  { "INTOXICATION", "intox", 100 }, { "STRESS", "stress", 1 }, { "PAIN", "pain", 100 },
  { "UNHAPPINESS", "unhappy", 100 }, { "FATIGUE", "fatigue", 1 }, { "PANIC", "panic", 100 },
  { "ENDURANCE", "endurance", 1 }, { "FOOD_SICKNESS", "foodsick", 100 }, { "THIRST", "thirst", 1 },
  { "HUNGER", "hunger", 1 }, { "BOREDOM", "boredom", 100 }, { "ANGER", "anger", 1 },
  { "NICOTINE_WITHDRAWAL", "nw", 0.51 }, { "WETNESS", "wetness", 100 },
  { "SICKNESS", "sickness", 1 }, { "TEMPERATURE", "temperature", 1 },
}

function H.clearHalo()
  for i = #H.halo, 1, -1 do H.halo[i] = nil end
end

local function loudList() return { size = function() return 0 end } end

function H.stubs()
  require = function() end
  SandboxVars = nil
  MF = nil
  RenderEffectType = nil
  DanTraitsTestCharge = false
  DanTraitsTestEpisode = false
  DanTraitsRegistry = setmetatable({}, { __index = function(_, key) return key end })

  function getText(k, a) if a ~= nil then return k .. ":" .. tostring(a) end return k end
  HaloTextHelper = {
    addBadText = function(_, t) H.halo[#H.halo + 1] = t end,
    addGoodText = function(_, t) H.halo[#H.halo + 1] = "+" .. t end,
  }

  function ZombRand() H.rolls = H.rolls + 1; if #H.rng > 0 then return table.remove(H.rng, 1) end return H.roll end
  function ZombRandFloat(lo, hi) if lo == 0 and hi == 1 then return H.rollf end return (lo + hi) / 2 end
  function getSpecificPlayer() return H.current end
  function getTimestampMs() return H.now end
  function getGameTime()
    return { getHour = function() return 12 end, getWorldAgeHours = function() return H.hours end }
  end
  GameTime = { getInstance = function()
    return { getWorldAgeHours = function() return H.hours end, getThirtyFPSMultiplier = function() return 1 end }
  end }

  CharacterStat = {}
  for _, s in ipairs(STATS) do
    local max = s[3]
    CharacterStat[s[1]] = { name = s[2], getMaximumValue = function() return max end }
  end
  CharacterTrait = { SMOKER = "base:smoker", NEEDS_LESS_SLEEP = "base:needslesssleep" }
  MoodleType = { DRUNK = "drunk" }
  ItemBodyLocation = { MASK = "mask", MASK_EYES = "maskeyes", MASK_FULL = "maskfull" }
  BodyPartType = { Head = "Head" }
  for _, n in ipairs({ "Groin", "Head", "Neck", "Torso_Upper", "Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R",
                       "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }) do BodyPartType[n] = n end
  Perks = setmetatable({}, { __index = function(_, k) return k end })
  FitnessExercises = { exercisesType = { squats = {}, pushups = {}, situps = {}, burpees = {} } }

  ISEatFoodAction = { complete = function() return true end, eat = function() end,
                      isValid = function() return true end, isValidStart = function() return true end }
  ISTakePillAction = { complete = function() return true end }
  -- vanilla drink action stub: drinking removes `sip` litres from the container
  ISDrinkFluidAction = { updateEat = function(self) self.fluidContainer._amount = self.fluidContainer._amount - (self.sip or 0) end }

  ArrayList = { new = function() return { add = function() end } end }
  IsoFireManager = { explode = function() end }
  function instanceof() return false end
  function getTexture() return "TEX" end
  function isNight() return false end
  function addSound(_, _, _, _, radius) H.sounds[#H.sounds + 1] = radius end
  function getWorld()
    return { getFreeEmitter = function() return { playSound = function() return 1 end, setPos = function() end } end }
  end
  function getCell()
    return { getGridSquare = function(_, x, y)
      local bodies = (x == 10 and y == 10) and H.corpses or 0
      return { getObjects = loudList, getDeadBodys = function() return { size = function() return bodies end } end }
    end }
  end
  function getClimateManager()
    local c = H.climate
    return {
      getAirTemperatureForCharacter = function() return c.temp end, getRainIntensity = function() return c.rain end,
      getHumidity = function() return c.humidity end, getNightStrength = function() return c.night end,
      getCloudIntensity = function() return c.cloud end,
    }
  end
end

-- load -------------------------------------------------------------------------

local loaded = {}

local function loadFile(path)
  local chunk, err = loadfile(path)
  if not chunk then error(err, 0) end
  chunk()
end

-- The game loads the core, which requires DanTraits_Attrib, DanTraits_Util then
-- DanTraits_Food (require is a stub here). Util and Food need nothing, so they go
-- in first, once, before any file: the core, a trait file, or a client file that
-- reads their globals.
local function ensureUtil()
  if loaded.DanTraits_Util then return end
  loaded.DanTraits_Util = true
  loadFile(H.root .. "/shared/DanTraits_Util.lua")
  loaded.DanTraits_Food = true
  loadFile(H.root .. "/shared/DanTraits_Food.lua")
end

function H.load(...)
  ensureUtil()
  for _, name in ipairs({ ... }) do
    if name:find("/", 1, true) then
      loadFile(H.root .. "/" .. name)
    else
      if not name:find("^DanTraits") then name = "DanTraits_" .. name end
      if name ~= "DanTraits_Util" and name ~= "DanTraits_Food" then
        if name ~= "DanTraits" and not loaded.DanTraits then H.load("DanTraits") end
        loadFile(H.root .. "/shared/" .. name .. ".lua")
        loaded[name] = true
      end
    end
  end
end

-- the player -------------------------------------------------------------------

local function statKey(k)
  if type(k) == "table" then return k.name end
  return k
end

local function newItem(fullType)
  local item = { _type = fullType, _md = {} }
  function item:getFullType() return self._type end
  function item:getType() return (self._type:gsub("^.*%.", "")) end
  function item:hasModData() return true end
  function item:getModData() return self._md end
  function item:setName(n) self._name = n end
  function item:setCustomName() end
  function item:setTexture(x) self._tex = x end
  return item
end

function H.player(o)
  o = o or {}
  local st = {}
  for _, s in ipairs(STATS) do st[s[2]] = 0 end
  st.endurance = 1
  for k, v in pairs(o.st or {}) do st[k] = v end
  for _, s in ipairs(STATS) do if o[s[2]] ~= nil then st[s[2]] = o[s[2]] end end

  local traits, order = {}, {}
  for _, list in ipairs({ o.traits or {}, o.vanilla or {} }) do
    for _, t in ipairs(list) do if not traits[t] then traits[t] = true; order[#order + 1] = t end end
  end
  local md, parts, inv, dropped = {}, o.parts or {}, {}, {}

  local p
  p = {
    _st = st, _md = md, _traits = traits, _o = o, _parts = parts, _inv = inv, _dropped = dropped, _vars = {},
    _asleep = o.asleep == true, _outside = o.outside == true, _sprint = o.sprint == true, _run = o.run == true,
    _moving = false, _health = o.health or 100, _hours = o.hours or 0, _carry = 8, _catch = 0, _pr = o.painReduction or 0,
    _painFx = 0, _painD = 0, _beta = 0, _betaD = 0, _depress = 0, _since = 10, _cs = 1.0, _light = 0,
    _tablets = 0, _coughs = 0, _woke = 0, _adds = 0, _cantSprint = false,
    _weight = o.weight or 80, _regularity = o.regularity or {},
  }
  p.isDead = function() return false end
  p.isAsleep = function() return p._asleep end
  p.isOutside = function() return p._outside end
  p.isSprinting = function() return p._sprint end
  p.setSprinting = function(_, b) p._sprint = b end
  p.isRunning = function() return p._run end
  p.isPlayerMoving = function() return p._moving end
  p.setMoodleCantSprint = function(_, b) p._cantSprint = b end
  p.getModData = function() return md end
  p.getHoursSurvived = function() return p._hours end
  p.getPlayerNum = function() return 0 end
  p.isLocalPlayer = function() return true end
  p.getX = function() return 10 end
  p.getY = function() return 10 end
  p.getZ = function() return 0 end

  -- a head for pain floors when the test gives no parts of its own
  p._head = { _pain = 0 }
  function p._head:getType() return "Head" end
  function p._head:getAdditionalPain() return self._pain end
  function p._head:setAdditionalPain(v) self._pain = v end

  p.hasTrait = function(_, t) return traits[t] == true end
  p.getCharacterTraits = function()
    return {
      add = function(_, t)
        p._adds = p._adds + 1
        if not traits[t] then traits[t] = true; order[#order + 1] = t end
      end,
      remove = function(_, t)
        traits[t] = nil
        for i, x in ipairs(order) do if x == t then table.remove(order, i); break end end
      end,
      get = function(_, t) return traits[t] == true end,
      getKnownTraits = function()
        local list = {}
        for _, t in ipairs(order) do if traits[t] then list[#list + 1] = t end end
        return { size = function() return #list end, get = function(_, i) return list[i + 1] end }
      end,
    }
  end

  p.getStats = function()
    return {
      get = function(_, k) return st[statKey(k)] end,
      set = function(_, k, v) local n = statKey(k); if n ~= nil then st[n] = v end end,
    }
  end

  p.getBodyDamage = function()
    return {
      getOverallBodyHealth = function() return p._health end,
      ReduceGeneralHealth = function(_, n) p._health = p._health - n end,
      AddGeneralHealth = function(_, n) p._health = math.min(100, p._health + n) end,
      getCatchACold = function() return p._catch end, setCatchACold = function(_, v) p._catch = v end,
      getPainReduction = function() return p._pr end, setPainReduction = function(_, v) p._pr = v end,
      isInfected = function() return false end,
      getBodyParts = function() return { size = function() return #parts end, get = function(_, i) return parts[i + 1] end } end,
      getBodyPart = function(_, t)
        for _, x in ipairs(parts) do if x:getType() == t then return x end end
        if t == "Head" then return p._head end
      end,
    }
  end

  -- pills: the game's beta blocker and painkiller timers
  p.getPainEffect = function() return p._painFx end
  p.setPainEffect = function(_, v) p._painFx = v end
  p.getPainDelta = function() return p._painD end
  p.setPainDelta = function(_, v) p._painD = v end
  p.getBetaEffect = function() return p._beta end
  p.setBetaEffect = function(_, v) p._beta = v end
  p.getBetaDelta = function() return p._betaD end
  p.setBetaDelta = function(_, v) p._betaD = v end
  p.getDepressEffect = function() return p._depress end
  p.setDepressEffect = function(_, v) p._depress = v end
  p.getSleepingTabletEffect = function() return p._tablets end

  p.getTimeSinceLastSmoke = function() return p._since end
  p.setTimeSinceLastSmoke = function(_, v) p._since = v end
  p.triggerCough = function() p._coughs = p._coughs + 1 end
  p.playerVoiceSound = function() p._coughs = p._coughs + 1 end
  p.forceAwake = function() p._asleep = false; p._woke = p._woke + 1 end
  p.setBumpType = function(_, t) p._bump = t end
  p.setVariable = function(_, k, v) p._vars[k] = v end

  p.getNutrition = function()
    return { getWeight = function() return p._weight end, setWeight = function(_, w) p._weight = w end,
             getCalories = function() return 1200 end }
  end
  p.getFitness = function()
    return { getRegularity = function(_, name) return p._regularity[name] or 0 end }
  end
  p.getCombatSpeed = function() return p._cs end
  p.setCombatSpeed = function(_, v) p._cs = v end
  p.getMaxWeightBase = function() return p._carry end
  p.setMaxWeightBase = function(_, v) p._carry = math.floor(v) end   -- an int in the game

  p.getInventory = function()
    return {
      AddItem = function(_, t) local it = newItem(t); inv[#inv + 1] = it; return it end,
      Remove = function() end, contains = function() return true end,
      getItems = function() return { size = function() return #inv end, get = function(_, i) return inv[i + 1] end } end,
    }
  end
  p.getPrimaryHandItem = function() return { name = "bat" } end
  p.removeFromHands = function() end
  p.getCurrentSquare = function()
    return {
      AddWorldInventoryItem = function(_, it) dropped[#dropped + 1] = it end,
      getLightLevel = function(_, n) assert(n == 0, "per-player light"); return p._light end,
      isOutside = function() return p._outside end,
    }
  end

  if o.moodles then
    p._moodles = o.moodles
    p.getMoodles = function() return { getMoodleLevel = function(_, t) return p._moodles[t] or 0 end } end
  end
  return p
end

function H.factory(defaults, decorate)
  return function(o)
    local merged = {}
    for k, v in pairs(defaults or {}) do merged[k] = v end
    for k, v in pairs(o or {}) do merged[k] = v end
    local p = H.player(merged)
    if decorate then decorate(p, merged) end
    return p
  end
end

-- helpers ------------------------------------------------------------------------

function H.near(a, b, eps, msg)
  assert(math.abs(a - b) <= eps, tostring(msg) .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

function H.mins(n, fn)
  fn = fn or H.minute
  for _ = 1, n do fn() end
end

function H.pass(name)
  name = name or (arg and arg[0] and arg[0]:match("([^/\\]+)%.lua$")) or "test"
  print(name .. ": all checks passed")
end

return H
