-- Project Zomboid Vitality Project: the one fever (plans/illness.md, phase 0).
--
-- Not a trait: every character has it. Anything that makes a fever is a
-- source: DanTraits_FeverSource(name, fn), fn(player, d) giving 0..1 (wound
-- infection, DanTraits_Infection.lua; each illness, DanTraits_Illness.lua).
-- Once a minute (order 23.2, after Infection, before Age) this composes them:
--
--   total = the worst + FEVER_STACK x the sum of the rest
--
-- so a second fever on top of a bad one makes it worse, not just the same.
-- DanTraits_Fever(player) is that capped at 1, and what every system that
-- reacts to a fever reads (a bad night, migraines, seizures, MS flares, the
-- heart, blood sugar, asthma, hallucinations, burnout);
-- DanTraits_FeverTotal(player) is uncapped.
--
-- The fever is the game's SICKNESS stat, which nothing in vanilla sets: it
-- raises the body's set point 2 C per unit (Thermoregulator) and feeds the
-- Sick moodle. This is its only writer: FEVER_SICKNESS from the first of a
-- fever to a full one, held there up or down; a higher value someone else
-- left is theirs and left alone. A fever tires you (awake) and makes you
-- thirsty. Past a total of 1 it is a dangerous fever: health drains,
-- FEVER_DANGER_HEALTH per minute from 1 to FEVER_DANGER_TOP, with a notice
-- once. An infected wound in sepsis with the flu on top is how that happens.
--
-- Fever reducers (DanTraits_Meds.lua: the game's painkillers, the night-time
-- and daytime cold medicines, all acetaminophen or aspirin) take FEVER_REDUCE
-- off what is felt and read while they work: SICKNESS, the temperature, the
-- tiredness and thirst, and every reader. They mask it: the dangerous fever
-- reads the fever as it really is (DanTraits_FeverRaw), so medicine alone
-- does not save a body past 1.
--
-- The antibiotic level lives here too, so a course counts for an infected
-- wound and a bacterial illness alike: DanTraits_AntibioticDose(player, n)
-- tops it up (DanTraits_TakeAntibiotic in Infection does, with the course
-- count), it halves every ABX_HALF hours (order 22.9, before Infection reads
-- it), and DanTraits_AntibioticOn(player) is whether it is high enough to
-- work. With wound infection switched off the game's own antibiotic still
-- counts here (its own effect is then left alone).
--
-- Mod data: fevTotal (the last minute's total, as felt), fevRaw (as it is), fevHeld (the SICKNESS it
-- held), fevDanger (the notice was given), fevBodyTemp (the game's body
-- temperature, for the readouts), infAbx (the antibiotic level; the key
-- predates this file).
-- Console: fever (what each source gives and the total)
require "DanTraits"

local notify = DanTraits_Notify
local statAdd = DanTraits_StatAdd

local FEVER_STACK         = 0.5     -- every fever but the worst counts this much
local FEVER_SICKNESS      = { 0.2, 0.9 }   -- SICKNESS at the first of a fever and at a full one (x2 C)
local FEVER_FATIGUE       = 0.0006  -- tiredness per minute at a full fever, awake
local FEVER_THIRST        = 0.0004  -- thirst per minute at a full fever
local FEVER_DANGER_TOP    = 1.5     -- the total where the dangerous fever is at its worst
local FEVER_DANGER_HEALTH = { 0.1, 0.8 }   -- health per minute just past 1 and at FEVER_DANGER_TOP
local FEVER_REDUCE        = 0.6     -- x the felt fever while a fever reducer works...
local FEVER_REDUCERS      = { "painkillers", "nightcold", "daycold" }   -- ...these (DanTraits_Meds.lua ids)
local ABX_HALF            = 6       -- hours for the antibiotic level to halve
local ABX_MIN             = 0.5     -- therapeutic from here

local sources = {}   -- { name, fn } in registration order
DanTraits_FeverSources = sources   -- read-only view for the tests

function DanTraits_FeverSource(name, fn)
    if type(fn) ~= "function" then return end
    for _, s in ipairs(sources) do
        if s.name == name then s.fn = fn return end
    end
    sources[#sources + 1] = { name = name, fn = fn }
end

-- each source's fever now: { name = 0..1 }, and the composed total
local function readSources(player, d)
    local values, list = {}, {}
    for _, s in ipairs(sources) do
        local ok, v = pcall(s.fn, player, d)
        v = ok and tonumber(v) or 0
        v = math.max(0, math.min(1, v))
        values[s.name] = v
        if v > 0 then list[#list + 1] = v end
    end
    table.sort(list, function(a, b) return a > b end)
    local total = list[1] or 0
    for i = 2, #list do total = total + FEVER_STACK * list[i] end
    return total, values
end
DanTraits_FeverCompose = readSources   -- tests and the console

-- 0..1, for the systems that react to a fever
function DanTraits_Fever(player)
    local d = player and player:getModData().DanTraits
    return math.min(1, (d and d.fevTotal) or 0)
end

function DanTraits_FeverTotal(player)
    local d = player and player:getModData().DanTraits
    return (d and d.fevTotal) or 0
end

-- the fever as it really is, under any fever reducer
function DanTraits_FeverRaw(player)
    local d = player and player:getModData().DanTraits
    return (d and (d.fevRaw or d.fevTotal)) or 0
end

local function reduced(player)
    if not DanTraits_MedCovered then return false end
    for _, id in ipairs(FEVER_REDUCERS) do
        if DanTraits_MedCovered(player, id) then return true end
    end
    return false
end

-- the antibiotic level -------------------------------------------------------

function DanTraits_AntibioticDose(player, amount)
    local d = DanTraits_Data(player)
    d.infAbx = (d.infAbx or 0) + (amount or 1)
    return d.infAbx
end

function DanTraits_AntibioticOn(player)
    local d = player and player:getModData().DanTraits
    return ((d and d.infAbx) or 0) >= ABX_MIN
end

local function decayAntibiotic(player, d)
    if (d.infAbx or 0) <= 0 then return end
    d.infAbx = d.infAbx * 0.5 ^ (1 / (ABX_HALF * 60))
    if d.infAbx < 0.01 then d.infAbx = 0 end
end

-- the game's pill, with wound infection off (Infection takes it when on)
DanTraits_AddHook("eat", function(_, player, item, fraction)
    if not player or not item or DanTraits_SandboxOn("InfectionEnabled") then return nil end
    local kind = ""
    pcall(function() kind = tostring(item:getType()) end)
    if kind == "Antibiotics" then DanTraits_AntibioticDose(player, math.min(1, fraction or 1)) end
    return nil
end)

-- the minute -------------------------------------------------------------------

local function updateFeverMinute(player, d)
    -- a save from before this file: the sickness Infection held is ours to let go
    if d.infSickness ~= nil then
        if d.fevHeld == nil then d.fevHeld = d.infSickness end
        d.infSickness, d.infBodyTemp = nil, nil
    end
    local raw = readSources(player, d)
    local total = raw
    if raw > 0 and reduced(player) then total = raw * FEVER_REDUCE end
    d.fevTotal, d.fevRaw = total, raw
    local stats = player:getStats()
    local sickness = 0
    if total > 0 then sickness = FEVER_SICKNESS[1] + (FEVER_SICKNESS[2] - FEVER_SICKNESS[1]) * math.min(1, total) end
    -- held at the fever's level, up or down; if something else has it higher
    -- than we left it, that is theirs and left alone
    local held = d.fevHeld or 0
    pcall(function()
        local now = stats:get(CharacterStat.SICKNESS) or 0
        if now < sickness or (held > 0 and now > sickness and math.abs(now - held) < 0.002) then
            stats:set(CharacterStat.SICKNESS, sickness)
        end
    end)
    d.fevHeld = sickness
    pcall(function() d.fevBodyTemp = stats:get(CharacterStat.TEMPERATURE) end)
    if raw <= 0 then
        d.fevDanger = nil
        return
    end
    local f = math.min(1, total)
    if not DanTraits_Asleep(player) then statAdd(stats, CharacterStat.FATIGUE, FEVER_FATIGUE * f) end
    statAdd(stats, CharacterStat.THIRST, FEVER_THIRST * f)
    if raw > 1 then
        local t = math.min(1, (raw - 1) / (FEVER_DANGER_TOP - 1))
        local health = FEVER_DANGER_HEALTH[1] + (FEVER_DANGER_HEALTH[2] - FEVER_DANGER_HEALTH[1]) * t
        pcall(function() player:getBodyDamage():ReduceGeneralHealth(health) end)
        if not d.fevDanger then
            d.fevDanger = true
            notify(player, "UI_DanTraits_FeverDanger")
        end
    elseif raw < 0.9 then
        d.fevDanger = nil
    end
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.fever = function(player)
    local total, values = readSources(player, DanTraits_Data(player))
    local parts = {}
    for _, s in ipairs(sources) do parts[#parts + 1] = s.name .. " " .. string.format("%.2f", values[s.name] or 0) end
    return "fever " .. string.format("%.2f", total) .. " (" .. table.concat(parts, ", ") .. ")"
end

DanTraits_Every("minute", "Antibiotics", decayAntibiotic, 22.9)
DanTraits_Every("minute", "Fever", updateFeverMinute, 23.2)
