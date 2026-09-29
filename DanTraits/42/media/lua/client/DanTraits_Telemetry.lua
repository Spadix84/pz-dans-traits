-- Project Zomboid Vitality Project: live telemetry and a command channel for the companion
-- dashboard (tools/dashboard.py in the mod folder).
--
-- Twice a second (real time) the whole picture is written as JSON to
-- <user>/Zomboid/Lua/DanTraits_Telemetry.json: vanilla stats, body, the
-- mod-data table every trait keeps its state in, and a few derived values.
-- Once a second <user>/Zomboid/Lua/DanTraits_Commands.txt is read, each
-- line run as a command, and the file emptied. Single player only.
--
-- Commands (one per line):
--   set <key> <value>        mod-data field: set glucose 40 / set asthma 0.9 / set mddEpisode true / set x nil
--   stat <NAME> <value>      CharacterStat: stat PANIC 100 / stat ENDURANCE 0.2
--   weight <kg>              body weight
--   health <percent>         overall health
--   inject <doses>           insulin
--   carbs <grams> [fast|slow]
--   metformin | inhaler
--   mdd start [severity] [hours] | mdd end
--   episode <name>           charge, sound, whisper, thump, glass, footsteps, panic
--   give <Module.Item> [n]
--   fracture                 Brittle: snap a random limb
--   drop                     Arthritis: drop the held weapon
--   cough [radius]           Asthma: one cough (zombies hear it)
--   gluten <carbs> [now]     Gluten: dose in carbs; "now" skips the 20-minute onset
--   antidep                  MDD: as if an antidepressant was swallowed
--   attrib on|off|reset      which trait moved which stat (DanTraits_Attrib.lua)
--   blood <vol> [cells] | blood debug on|off | blood reset   blood (DanTraits_Blood.lua)
--   infect <part> [L] | contaminate <part> [min] | sepsis <0..1> | antibiotic | infection clear   (DanTraits_Infection.lua)
--   tear <part> | dressing <part> <life> | badset <part> | breakbone <part> [time] | firstaid <level>   (DanTraits_WoundCare.lua)
--   concussion <0..1> | concussion fall <amount> | concussion clear | faint fall | faint out [min]   (DanTraits_Concussion.lua, DanTraits_Faint.lua)
--   wound <part> <kind>      a wound for testing: scratch | cut | deep | glass (deep, shard lodged)
--   halo <text>
--   echo <text>
local TELEMETRY_FILE = "DanTraits_Telemetry.json"
local COMMAND_FILE   = "DanTraits_Commands.txt"
local WRITE_EVERY_MS = 500
local READ_EVERY_MS  = 1000
local LOG_KEEP       = 25

local log = {}
local function logLine(text)
    table.insert(log, 1, { t = getTimestampMs and getTimestampMs() or 0, text = tostring(text) })
    while #log > LOG_KEEP do table.remove(log) end
    print("[DanTraits telemetry] " .. tostring(text))
end

-- the story so far: OnStoryEvent from any mod (DanTraits.lua), newest first,
-- stamped with the game clock
local STORY_KEEP = 40
local story = {}
local function onStoryEvent(player, ev)
    if type(ev) ~= "table" then return end
    local clock
    pcall(function()
        local gt = getGameTime()
        -- whole numbers by hand: Kahlua's tostring can say "4.0"
        local function int(n) return (string.gsub(tostring(math.floor(n or 0)), "%.0+$", "")) end
        local function two(n) n = math.floor(n or 0); return (n < 10 and "0" or "") .. int(n) end
        -- the game counts days and months from 0
        clock = int(gt:getDay() + 1) .. "/" .. int(gt:getMonth() + 1) .. " " .. two(gt:getHour()) .. ":" .. two(gt:getMinutes())
    end)
    table.insert(story, 1, { clock = clock, source = tostring(ev.source or "?"), kind = tostring(ev.kind or "?"),
        text = tostring(ev.text or ""), tone = tostring(ev.tone or "") })
    while #story > STORY_KEEP do table.remove(story) end
end

-- JSON --------------------------------------------------------------------------
local function jsonString(s)
    s = s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\"
        elseif c == "\n" then return "\\n" elseif c == "\r" then return "\\r" elseif c == "\t" then return "\\t"
        else return string.format("\\u%04x", string.byte(c)) end
    end)
    return '"' .. s .. '"'
end

-- Kahlua (the game's Lua) has no `next` and an incomplete string.format, so
-- emptiness is checked with pairs and numbers are formatted by hand.
local function isEmpty(t)
    for _ in pairs(t) do return false end
    return true
end

local function jsonNumber(n)
    if n ~= n or n == math.huge or n == -math.huge then return "null" end
    if n == math.floor(n) and math.abs(n) < 1e15 then
        local text = tostring(n)
        return (text:gsub("%.0+$", ""))
    end
    local text = string.format("%.4f", n)
    text = text:gsub("0+$", ""):gsub("%.$", "")
    return text
end

local encode
local function isArray(t)
    local n = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then return false end
        n = n + 1
    end
    return n == #t
end
encode = function(v, depth)
    depth = depth or 0
    local kind = type(v)
    if v == nil then return "null"
    elseif kind == "boolean" then return v and "true" or "false"
    elseif kind == "number" then return jsonNumber(v)
    elseif kind == "string" then return jsonString(v)
    elseif kind == "table" then
        if depth > 8 then return '"..."' end
        if isEmpty(v) then return "{}" end
        local parts = {}
        if isArray(v) then
            for i = 1, #v do parts[#parts + 1] = encode(v[i], depth + 1) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k, _ in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local value = v[k]
            if value == nil then value = v[tonumber(k)] end
            parts[#parts + 1] = jsonString(k) .. ":" .. encode(value, depth + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return jsonString(tostring(v))
end
DanTraits_JsonEncode = encode

-- Snapshot ------------------------------------------------------------------------
local STAT_NAMES = { "PANIC", "ENDURANCE", "FATIGUE", "THIRST", "HUNGER", "UNHAPPINESS", "STRESS", "BOREDOM",
    "INTOXICATION", "FOOD_SICKNESS", "PAIN", "WETNESS", "DRUNKENNESS", "SICKNESS", "ANGER", "NICOTINE_WITHDRAWAL" }

local function safe(fn, default)
    local ok, res = pcall(fn)
    if ok and res ~= nil then return res end
    return default
end

local function snapshot(player)
    local stats = player:getStats()
    local out = { t = safe(function() return getTimestampMs() end, 0) }
    out.hoursSurvived = safe(function() return player:getHoursSurvived() end, 0)
    out.paused = safe(function() return isGamePaused() end, false)
    out.game = {
        day = safe(function() return getGameTime():getDay() end),
        hour = safe(function() return getGameTime():getHour() end),
        minute = safe(function() return getGameTime():getMinutes() end),
        month = safe(function() return getGameTime():getMonth() end),
    }
    local traits = {}
    pcall(function()
        local known = player:getCharacterTraits():getKnownTraits()
        for i = 0, known:size() - 1 do traits[#traits + 1] = tostring(known:get(i)) end
    end)
    out.traits = traits
    local s = {}
    for _, name in ipairs(STAT_NAMES) do
        local stat = CharacterStat and CharacterStat[name]
        if stat then s[name:lower()] = safe(function() return stats:get(stat) end) end
    end
    out.stats = s
    out.body = {
        health = safe(function() return player:getBodyDamage():getOverallBodyHealth() end),
        weight = safe(function() return player:getNutrition():getWeight() end),
        calories = safe(function() return player:getNutrition():getCalories() end),
        asleep = safe(function() return player:isAsleep() end, false),
        outside = safe(function() return player:isOutside() end, false),
        running = safe(function() return player:isRunning() or player:isSprinting() end, false),
        temperature = safe(function() return getClimateManager():getAirTemperatureForCharacter(player, false) end),
        infected = safe(function() return player:getBodyDamage():isInfected() end, false),
    }
    local md = player:getModData()
    out.mod = md and md.DanTraits or {}
    local derived = {}
    -- only ask a trait about itself when the character has it: the getters
    -- create the trait's mod-data block as a side effect, which would make an
    -- empty card appear for everyone
    local has = function(key) return DanTraits_HasTrait and DanTraits_HasTrait(player, key) end
    local diabetic = has("diabetes1") or has("diabetes2")
    if diabetic and DanTraits_DiaResistance then derived.diaResistance = safe(function() return DanTraits_DiaResistance(player) end) end
    if DanTraits_DiaTier and out.mod.glucose then
        local low, high = DanTraits_DiaTier(out.mod.glucose)
        derived.diaLow, derived.diaHigh = low, high
    end
    if out.mod.diaInsulin then
        local doses = 0
        for _, shot in ipairs(out.mod.diaInsulin) do doses = doses + (shot.dose or 0) end
        derived.insulinDoses = doses
    end
    if DanTraits_SwingDropChance then derived.swingDrop = safe(function() return DanTraits_SwingDropChance(player) end) end
    if has("spiraling") and DanTraits_MddBenefit then derived.mddBenefit = safe(function() return DanTraits_MddBenefit(player) end) end
    if DanTraits_MddRegularity then derived.exerciseRegularity = safe(function() return DanTraits_MddRegularity(player) end) end
    out.derived = derived
    if DanTraits_AttribReport then out.attrib = safe(function() return DanTraits_AttribReport(player) end) end
    if DanTraits_ActiveMoodles then out.moodles = safe(function() return DanTraits_ActiveMoodles(player) end) end
    if #log > 0 then out.log = log end   -- an empty Lua table would encode as {} and confuse the page
    if #story > 0 then out.story = story end
    return out
end

local function writeTelemetry(player)
    local ok, err = pcall(function()
        local text = encode(snapshot(player))
        local writer = getFileWriter(TELEMETRY_FILE, true, false)
        writer:write(text)
        writer:close()
    end)
    if not ok then print("[DanTraits telemetry] write failed: " .. tostring(err)) end
end

-- Commands ------------------------------------------------------------------------
local function parseValue(text)
    if text == nil then return nil end
    if text == "true" then return true elseif text == "false" then return false elseif text == "nil" then return nil end
    local n = tonumber(text)
    if n ~= nil then return n end
    return text
end

local function modData(player)
    local md = player:getModData()
    md.DanTraits = md.DanTraits or {}
    return md.DanTraits
end

local commands = {}

function commands.set(player, args)
    local key, value = args[1], parseValue(args[2])
    if not key then return "set: need a key" end
    modData(player)[key] = value
    return "set " .. key .. " = " .. tostring(value)
end

function commands.stat(player, args)
    local name, value = string.upper(args[1] or ""), tonumber(args[2])
    local stat = CharacterStat and CharacterStat[name]
    if not stat or value == nil then return "stat: unknown stat or value (" .. name .. ")" end
    player:getStats():set(stat, value)
    return "stat " .. name .. " = " .. value
end

function commands.weight(player, args)
    local kg = tonumber(args[1])
    if not kg then return "weight: need kg" end
    player:getNutrition():setWeight(kg)
    return "weight = " .. kg
end

function commands.health(player, args)
    local pct = tonumber(args[1])
    if not pct then return "health: need percent" end
    local bd = player:getBodyDamage()
    bd:RestoreToFullHealth()
    if pct < 100 then bd:ReduceGeneralHealth(100 - pct) end
    return "health = " .. pct
end

function commands.inject(player, args)
    if not DanTraits_DiaInject then return "inject: diabetes not loaded" end
    local n = DanTraits_DiaInject(player, tonumber(args[1]) or 1)
    return "injected " .. n .. " dose(s)"
end

function commands.carbs(player, args)
    local grams = tonumber(args[1])
    if not grams then return "carbs: need grams" end
    local d = modData(player)
    if args[2] == "slow" then d.diaSlow = (d.diaSlow or 0) + grams else d.diaFast = (d.diaFast or 0) + grams end
    return "carbs +" .. grams .. " " .. (args[2] == "slow" and "slow" or "fast")
end

function commands.metformin(player)
    if not DanTraits_DiaOnPill then return "metformin: diabetes not loaded" end
    return "metformin: " .. tostring(DanTraits_DiaOnPill(player))
end

function commands.inhaler(player)
    if not DanTraits_UseInhaler then return "inhaler: asthma not loaded" end
    return "inhaler: " .. tostring(DanTraits_UseInhaler(player))
end

function commands.mdd(player, args)
    local d = modData(player)
    if args[1] == "start" then
        d.mddEpisode = true
        d.mddSeverity = tonumber(args[2]) or 1
        d.mddHoursLeft = tonumber(args[3]) or 48
        d.mddSinceEnd = 0
        return "mdd episode started: severity " .. d.mddSeverity .. ", " .. d.mddHoursLeft .. " h"
    elseif args[1] == "end" then
        d.mddEpisode = false
        d.mddHoursLeft = 0
        d.mddSinceEnd = 0
        return "mdd episode ended"
    end
    return "mdd: start [severity] [hours] | end"
end

function commands.episode(player, args)
    local fn = DanTraits_Episodes and DanTraits_Episodes[args[1] or ""]
    if not fn then return "episode: unknown (charge, sound, whisper, thump, glass, footsteps, panic)" end
    fn(player)
    return "episode " .. args[1]
end

function commands.give(player, args)
    local item, n = args[1], tonumber(args[2]) or 1
    if not item then return "give: need Module.Item" end
    for _ = 1, n do player:getInventory():AddItem(item) end
    return "gave " .. n .. " x " .. item
end

-- trait add|remove <key>: a mod key (caffeine, diabetes1) or a vanilla
-- CharacterTrait name (smoker, thin_skinned). Creation-time extras (the
-- diabetes kit) are not handed out; use give.
function commands.trait(player, args)
    local op, key = string.lower(args[1] or ""), args[2]
    if (op ~= "add" and op ~= "remove") or not key then return "trait: add|remove <key>" end
    local entry = DanTraitsRegistry and DanTraitsRegistry[string.lower(key)]
    if not entry and CharacterTrait then entry = CharacterTrait[string.upper(key)] end
    if not entry then return "trait: unknown " .. key end
    local traits = player:getCharacterTraits()
    if op == "add" then traits:add(entry) else traits:remove(entry) end
    if DanTraits_TraitsChanged then DanTraits_TraitsChanged(player) end
    return "trait " .. op .. " " .. tostring(entry)
end

function commands.fracture(player)
    if not DanTraits_BrittleFracture then return "fracture: brittle not loaded" end
    return "fracture: " .. tostring(DanTraits_BrittleFracture(player))
end

function commands.drop(player)
    if not DanTraits_FumbleDrop then return "drop: arthritis not loaded" end
    return "drop: " .. tostring(DanTraits_FumbleDrop(player))
end

function commands.cough(player, args)
    if not DanTraits_Cough then return "cough: util not loaded" end
    local radius = tonumber(args[1]) or 10
    DanTraits_Cough(player, radius, "console", true)
    return "cough, radius " .. radius
end

function commands.gluten(player, args)
    if not DanTraits_GlutenDose then return "gluten: not loaded" end
    local carbs = tonumber(args[1]) or 50
    DanTraits_GlutenDose(player, carbs, args[2] == "now")
    return "gluten dose " .. carbs .. " carbs" .. (args[2] == "now" and " (no onset wait)" or "")
end

function commands.antidep(player)
    if not DanTraits_MddOnPill then return "antidep: mdd not loaded" end
    return "antidepressant: " .. tostring(DanTraits_MddOnPill(player))
end

function commands.attrib(player, args)
    if not DanTraits_AttribSet then return "attrib: not loaded" end
    if args[1] == "on" then DanTraits_AttribSet(true); return "attribution on"
    elseif args[1] == "off" then DanTraits_AttribSet(false); return "attribution off"
    elseif args[1] == "reset" then DanTraits_AttribReset(); return "attribution reset" end
    return "attrib: on | off | reset"
end

function commands.halo(player, args)
    local text = table.concat(args, " ")
    HaloTextHelper.addBadText(player, text)
    return "halo: " .. text
end

function commands.echo(player, args)
    return table.concat(args, " ")
end

function commands.badday(player, args)
    if not DanTraits_BadDayReplay then return "badday: not loaded" end
    return DanTraits_BadDayReplay(player, args[1] == "fire")
end

local function runCommand(player, line)
    local args = {}
    -- no string.gmatch in the game's Lua: walk the words with find
    local pos = 1
    while true do
        local s, e = string.find(line, "%S+", pos)
        if not s then break end
        args[#args + 1] = string.sub(line, s, e)
        pos = e + 1
    end
    if #args == 0 then return nil end
    local name = string.lower(table.remove(args, 1))
    -- other files add theirs to DanTraits_ExtraCommands
    local handler = commands[name] or (DanTraits_ExtraCommands and DanTraits_ExtraCommands[name])
    if not handler then return "unknown command: " .. name end
    local ok, res = pcall(handler, player, args)
    if not ok then return name .. " failed: " .. tostring(res) end
    return res
end
DanTraits_RunCommand = runCommand

local function readCommands(player)
    local lines = {}
    local ok = pcall(function()
        local reader = getFileReader(COMMAND_FILE, true)
        if not reader then return end
        local line = reader:readLine()
        while line ~= nil do
            if line:match("%S") then lines[#lines + 1] = line end
            line = reader:readLine()
        end
        reader:close()
    end)
    if not ok or #lines == 0 then return end
    pcall(function()
        local writer = getFileWriter(COMMAND_FILE, true, false)
        writer:write("")
        writer:close()
    end)
    for _, line in ipairs(lines) do
        local res = runCommand(player, line)
        if res then logLine(res) end
    end
end

-- Driver --------------------------------------------------------------------------
local lastWrite, lastRead = 0, 0
local function onTick()
    local now = getTimestampMs()
    if now - lastWrite < WRITE_EVERY_MS and now - lastRead < READ_EVERY_MS then return end
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    if now - lastRead >= READ_EVERY_MS then
        lastRead = now
        readCommands(player)
    end
    if now - lastWrite >= WRITE_EVERY_MS then
        lastWrite = now
        writeTelemetry(player)
    end
end
-- OnTick stops while the game is paused; the even-paused variant keeps the
-- readout and the command channel alive through a pause (falls back if the
-- event does not exist).
local tickEvent = Events.OnTickEvenPaused or Events.OnTick
tickEvent.Add(onTick)
Events.OnGameStart.Add(function() logLine("telemetry started") end)
if Events.OnStoryEvent then Events.OnStoryEvent.Add(onStoryEvent) end
