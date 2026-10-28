-- Vitality Challenges: the frame every challenge in this mod is built on.
--
-- The game's side (media/lua/client/Challenge/ChallengeData.lua and
-- OptionScreens/ChallengeList.lua): a table handed to addChallenge from
-- Events.OnChallengeQuery, with id, gameMode (also the save folder's name),
-- world, image + video (the menu shows a preview only with both), a spawn
-- (x, y, z or getSpawnRegion) and four functions it calls on the chosen
-- challenge only:
--   OnInitWorld   every world load, before the world exists: SandboxVars go here
--   AddPlayer     OnCreatePlayer: a new character, and every load of one
--   RemovePlayer  OnPlayerDeath
--   Render        every frame (OnPostUIDraw)
-- The menu's name and description are Challenge_<id>_name and _desc.
--
-- VitalityChallenges.define(spec) builds that table from a plain spec:
--   id, mode (gameMode; default id), world (default Muldraugh), image, video
--   x, y, z, or spawns = { {x, y, z}, ... } for the game to pick one from
--   zombiesPerChunk = { min, max }
--   sandbox          merged into SandboxVars on every world load (nested tables merge);
--                    a function returning the table is called at that moment instead
--   start            { hour = 0..24, weather = { stage = "storm", hours = 6 } }: once per world
--   scene(ctx)       once per world, at game start: vehicles, bodies, fires
--   player(p, ctx)   once per character; everyCharacter = false keeps it to the
--                    world's first one, so a respawn arrives without the scenario
--   firstMinute(ctx) once per world, on the first game minute, after every
--                    mod's own character setup (the place to reach other mods)
--   everyMinute / everyHour / everyDay(ctx), render(ctx), death(p, ctx)
--   noDriving, oneLife, goal   rules, in VitalityChallenges_Rules.lua
-- "Once" is kept in the world's ModData and the character's mod data, never
-- guessed from hours survived, so a save in the first minute or a reload
-- does not run a setup twice. ctx = { id, spec, state (this challenge's
-- saved table), vitality (the Vitality Project is loaded) }.

require "VitalityChallenges_Scene"

VitalityChallenges = VitalityChallenges or {}
local VC = VitalityChallenges
VC.challenges = VC.challenges or {}
-- rules any challenge can switch on (VitalityChallenges_Rules.lua), each
-- { name, init = fn(c), addPlayer = fn(c, player, ctx) -> true to stop the
-- setup, death = fn(c, player, ctx) }
VC.rules = VC.rules or {}

local MOD_KEY = "VitalityChallenges"

-- a broken hook is logged and the game carries on; the tests set VC.STRICT
local function guard(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        print("[VitalityChallenges] " .. label .. ": " .. tostring(err))
        if VC.STRICT then error(err, 0) end
    end
    return ok
end
VC.guard = guard

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

-- from's values into into, nested tables merged rather than replaced
function VC.merge(into, from)
    for k, v in pairs(from) do
        if type(v) == "table" and type(into[k]) == "table" then
            VC.merge(into[k], v)
        else
            into[k] = copy(v)
        end
    end
    return into
end

local function worldState(id)
    local root = ModData.getOrCreate(MOD_KEY)
    if type(root[id]) ~= "table" then root[id] = {} end
    return root[id]
end

local function context(c)
    return { id = c.id, spec = c.spec, state = worldState(c.id), vitality = DanTraits_Data ~= nil }
end
VC.context = context

local function call(c, name, ...)
    local fn = c.spec[name]
    if fn then return guard(c.id .. "." .. name, fn, ...) end
    return true
end

-- the challenge being played, if it is one of ours
function VC.current()
    local ok, id = pcall(function()
        return getCore():isChallenge() and getCore():getChallengeID() or nil
    end)
    return ok and id and VC.challenges[id] or nil
end

-- lifecycle ---------------------------------------------------------------------

local function onGameStart(c)
    local ctx = context(c)
    local s = ctx.state
    if s.started then return end
    s.started = true
    local start = c.spec.start or {}
    if start.hour then guard(c.id .. ".start.hour", VC.setTime, start.hour) end
    if start.weather then guard(c.id .. ".start.weather", VC.weather, start.weather.stage, start.weather.hours) end
    call(c, "scene", ctx)
end

local function onMinute(c)
    local ctx = context(c)
    if not ctx.state.firstMinute then
        ctx.state.firstMinute = true
        call(c, "firstMinute", ctx)
    end
    call(c, "everyMinute", ctx)
end

local function initWorld(c)
    local spec = c.spec
    local sandbox = spec.sandbox
    if type(sandbox) == "function" then sandbox = sandbox() end
    if sandbox and SandboxVars then VC.merge(SandboxVars, sandbox) end
    for _, rule in ipairs(VC.rules) do
        if rule.init then guard(rule.name .. ".init", rule.init, c) end
    end
    Events.OnGameStart.Add(function() onGameStart(c) end)
    if spec.firstMinute or spec.everyMinute then Events.EveryOneMinute.Add(function() onMinute(c) end) end
    if spec.everyHour then Events.EveryHours.Add(function() call(c, "everyHour", context(c)) end) end
    if spec.everyDay then Events.EveryDays.Add(function() call(c, "everyDay", context(c)) end) end
end

local function addPlayer(c, player)
    if not player then return end
    for _, rule in ipairs(VC.rules) do
        if rule.addPlayer then
            local stop = false
            guard(rule.name .. ".addPlayer", function() stop = rule.addPlayer(c, player, context(c)) end)
            if stop then return end
        end
    end
    local md = player:getModData()
    md[MOD_KEY] = type(md[MOD_KEY]) == "table" and md[MOD_KEY] or {}
    if md[MOD_KEY][c.id] then return end
    md[MOD_KEY][c.id] = true
    local ctx = context(c)
    if c.spec.everyCharacter == false then
        if ctx.state.firstCharacter then return end
        ctx.state.firstCharacter = true
    end
    call(c, "player", player, ctx)
end

function VC.define(spec)
    if type(spec.id) ~= "string" then error("a challenge needs an id", 2) end
    local c = {
        id = spec.id,
        gameMode = spec.mode or spec.id,
        world = spec.world or "Muldraugh, KY",
        image = spec.image,
        video = spec.video,
        x = spec.x, y = spec.y, z = spec.z,
        spec = spec,
    }
    if spec.zombiesPerChunk then
        c.zombiesMinPerChunk, c.zombiesMaxPerChunk = spec.zombiesPerChunk[1], spec.zombiesPerChunk[2]
    end
    if spec.spawns then
        local first = spec.spawns[1]
        c.x, c.y, c.z = c.x or first.x, c.y or first.y, c.z or first.z
        c.getSpawnRegion = function()
            local points = {}
            for i, p in ipairs(spec.spawns) do points[i] = { posX = p.x, posY = p.y, posZ = p.z or 0 } end
            return { { name = c.name, points = { unemployed = points } } }
        end
    end
    c.z = c.z or 0
    c.OnInitWorld = function() initWorld(c) end
    c.AddPlayer = function(_, player) addPlayer(c, player) end
    c.RemovePlayer = function(player)
        for _, rule in ipairs(VC.rules) do
            if rule.death then guard(rule.name .. ".death", rule.death, c, player, context(c)) end
        end
        if spec.death then call(c, "death", player, context(c)) end
    end
    c.Render = function() if spec.render then call(c, "render", context(c)) end end
    VC.challenges[spec.id] = c
    Events.OnChallengeQuery.Add(function() addChallenge(c) end)
    return c
end
