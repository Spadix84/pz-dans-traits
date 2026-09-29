-- Project Zomboid Vitality Project: wound infection (health overhaul, phase 2).
--
-- Not a trait: every character has it. Replaces vanilla's wound infection,
-- which starts on a per-tick roll (1 in 40000 less a set amount per wound
-- type, dirty clothes and so on, never under 1 in 5000), creeps up by
-- 0.00001 a tick, is pushed back by alcohol, garlic and one antibiotic, and
-- costs health only when the Sick moodle is already at its worst from food
-- or zombie infection (BodyPart.DamageUpdate, BodyDamage.Update).
--
-- Here, per wounded body part, a chance each game hour that the wound
-- takes an infection (INF_HAZARD by wound, x dressing, clothes, cleaning):
--   contaminated  hidden, INF_INCUBATE_H hours; disinfectant or garlic on
--                 the wound clears it completely.
--   local         the wound's infection level (the game's own, shown in the
--                 health panel, and what its pain reads) climbs INF_GROW a
--                 day and the wound stops healing. Disinfectant and garlic
--                 push it back while it is under INF_SPREAD_L.
--   spreading     at INF_SPREAD_L the infection gets into the body (a whole-
--                 body score, infS): fever, tiredness, thirst. Only
--                 antibiotics touch it now.
--   sepsis        infS past INF_SEPSIS: high fever, health draining faster
--                 the worse it gets. Untreated, about two days.
-- Fever is the game's SICKNESS stat, which nothing in vanilla sets: it
-- raises the body's set point 2 C per unit (Thermoregulator) and feeds the
-- Sick moodle (Moodle.Update: apparent infection / 100 + SICKNESS).
--
-- Antibiotics: the game's own pills, one a dose (a box of 12 is a course,
-- a dose every eight hours for four days). Each dose tops up a level in the
-- blood that halves every INF_ABX_HALF hours; at INF_ABX_MIN or more the
-- infection falls back, under it the infection picks up again. Cleared
-- before INF_COURSE doses and left there, it has a coin flip to come back,
-- as an infection inside (on no wound) that only antibiotics clear.
-- Vanilla's one-shot effect (ReduceInfectionPower 50) is undone.
--
-- Zombie infection is untouched.
--
-- Hooks offered: infectionHazard (h, player, part) and infectionGrowth (1,
-- player). Subscribers: Diabetes (high sugar: both), Vitality (both, both
-- ways), Anemia (growth), Smoker (growth, by the meter).
require "DanTraits"

local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood or DanTraits_Notify
local traitData = DanTraits_Data
local hasVanillaTrait = DanTraits_HasVanillaTrait

-- chance per game hour that a wound takes an infection, open and unwashed
local INF_HAZARD = { scratch = 0.01, cut = 0.02, deep = 0.04, bite = 0.06, burn = 0.03, lodged = 0.06 }
local INF_STITCHED     = 0.5     -- x a deep wound's share once stitched
local INF_BANDAGED     = 0.5     -- x under a clean bandage
local INF_DIRTY_BANDAGE = 3      -- x under a spent or dirty bandage
local INF_CLOTHES      = 1.5     -- x for each: dirty, bloody clothing over it
local INF_CLEANED      = 0.2     -- x once the wound has been disinfected
local INF_PRONE        = 1.3     -- x Prone to Illness
local INF_RESILIENT    = 0.7     -- x Resilient
local INF_INCUBATE_H   = { 8, 16 }  -- contaminated, before it shows
local INF_START_L      = 1       -- infection level when it shows
local INF_GROW         = 2       -- infection level per game day, untreated
local INF_TOPICAL      = 3       -- level per day off, disinfectant or garlic, under INF_SPREAD_L
local INF_ABX_L        = 4       -- level per day off, on antibiotics
local INF_NOHEAL_L     = 2       -- the wound stops healing at this level
local INF_SPREAD_L     = 5       -- the body is involved at this level
local INF_S_GROW       = 0.6     -- whole-body score per day at level 10 (scaled from INF_SPREAD_L)
local INF_S_FIGHT      = 0.2     -- per day the body clears on its own, nothing spreading
local INF_S_ABX        = 0.4     -- per day off, on antibiotics
local INF_FEVER        = 0.2     -- fever shows at this score
local INF_SEPSIS       = 0.6     -- sepsis at this score
local INF_SHOCK        = 0.85    -- septic shock at this score
local INF_SICKNESS     = { 0.2, 0.9 }   -- SICKNESS from fever to septic shock (x2 C)
local INF_HEALTH       = { 0.15, 1.5 }  -- health per minute from sepsis to the worst
local INF_FATIGUE      = 0.0006  -- tiredness per minute at full fever, awake
local INF_THIRST       = 0.0004  -- thirst per minute at full fever
local INF_ABX_HALF     = 6       -- hours for the antibiotic level to halve
local INF_ABX_MIN      = 0.5     -- therapeutic from here
local INF_COURSE       = 10      -- doses for a finished course
local INF_RELAPSE_H    = 24      -- hours off antibiotics after an unfinished course...
local INF_RELAPSE      = 0.5     -- ...then this chance it comes back
local INF_RELAPSE_L    = 3       -- at this level

local STAGE_NOTICE = { [2] = "UI_DanTraits_InfectionLocal", [3] = "UI_DanTraits_InfectionFever", [4] = "UI_DanTraits_InfectionSepsis" }

local clamp01 = DanTraits_Clamp01

local function sandboxOn() return DanTraits_SandboxOn("InfectionEnabled") end
function DanTraits_InfectionActive() return sandboxOn() end

local num = DanTraits_PartNum
local is = DanTraits_PartIs

local roll = DanTraits_Roll
local randRange = DanTraits_RandRange

local function infData(player)
    local d = traitData(player)
    d.infParts = d.infParts or {}
    d.infS = d.infS or 0
    d.infAbx = d.infAbx or 0
    d.infDoses = d.infDoses or 0
    return d
end

-- a fresh alcohol-soaked dressing (BodyPart keeps that in a field with no
-- getter; the dressing's type says it: Base.AlcoholBandage and so on)
local function alcoholBandage(part)
    local kind = ""
    pcall(function() kind = tostring(part:getBandageType() or "") end)
    return string.find(kind, "Alcohol", 1, true) ~= nil
end

-- chance per game hour this part takes an infection; 0 for no wound
local function hazardOf(player, part, rec)
    local h = 0
    if num(part, "getScratchTime") > 0 then h = h + INF_HAZARD.scratch end
    if num(part, "getCutTime") > 0 then h = h + INF_HAZARD.cut end
    if num(part, "getDeepWoundTime") > 0 then h = h + INF_HAZARD.deep
    elseif num(part, "getStitchTime") > 0 then h = h + INF_HAZARD.deep * INF_STITCHED end
    if num(part, "getBiteTime") > 0 then h = h + INF_HAZARD.bite end
    if num(part, "getBurnTime") > 0 then h = h + INF_HAZARD.burn end
    if is(part, "haveGlass") or is(part, "haveBullet") then h = h + INF_HAZARD.lodged end
    if h <= 0 then return 0 end
    if num(part, "getAlcoholLevel") > 0 or num(part, "getGarlicFactor") > 0 then return 0 end
    if is(part, "bandaged") then
        local life = num(part, "getBandageLife")
        if life <= 0 or is(part, "isBandageDirty") then h = h * INF_DIRTY_BANDAGE
        elseif alcoholBandage(part) then return 0
        else h = h * INF_BANDAGED end
    end
    if is(part, "hasDirtyClothing") then h = h * INF_CLOTHES end
    if is(part, "hasBloodyClothing") then h = h * INF_CLOTHES end
    if rec and rec.clean then h = h * INF_CLEANED end
    if hasVanillaTrait(player, "base:pronetoillness") then h = h * INF_PRONE end
    if hasVanillaTrait(player, "base:resilient") then h = h * INF_RESILIENT end
    return DanTraits_RunHooks("infectionHazard", h, player, part)
end
DanTraits_InfectionHazard = hazardOf

local function woundOpen(part)
    return num(part, "getScratchTime") > 0 or num(part, "getCutTime") > 0 or num(part, "getDeepWoundTime") > 0
        or num(part, "getBiteTime") > 0 or num(part, "getBurnTime") > 0 or num(part, "getStitchTime") > 0
end

-- push our level into the game's, which draws the health panel and the pain
local function showLevel(part, level)
    pcall(function()
        if level > 0 then
            part:setInfectedWound(true)
            part:setWoundInfectionLevel(level)
        elseif is(part, "isInfectedWound") or num(part, "getWoundInfectionLevel") > 0 then
            part:setWoundInfectionLevel(0)
            part:setInfectedWound(false)
        end
    end)
end

-- an infected wound does not heal: its clocks are held where they were
local HEAL_CLOCKS = { { "getScratchTime", "setScratchTime" }, { "getCutTime", "setCutTime" }, { "getDeepWoundTime", "setDeepWoundTime" } }
local function holdHealing(part, rec)
    rec.held = rec.held or {}
    for _, c in ipairs(HEAL_CLOCKS) do
        local now = num(part, c[1])
        local was = rec.held[c[1]]
        if was and now < was and now > 0 then
            pcall(function() part[c[2]](part, was) end)
        else
            rec.held[c[1]] = now
        end
    end
end

local function abxOn(d) return (d.infAbx or 0) >= INF_ABX_MIN end

-- one part, one minute; returns its infection level
local function updatePart(player, d, part, name, perMin)
    local rec = d.infParts[name]
    local treated = num(part, "getAlcoholLevel") > 0 or num(part, "getGarlicFactor") > 0
    if treated and woundOpen(part) then
        rec = rec or {}
        d.infParts[name] = rec
        rec.clean = true
    end
    if not rec or (not rec.inc and (rec.L or 0) <= 0) then
        -- no infection: maybe one takes hold
        if not woundOpen(part) then
            -- healed: nothing to catch, and the cleaning is forgotten
            d.infParts[name] = nil
            showLevel(part, 0)
            return 0
        end
        local hazard = hazardOf(player, part, rec)
        if hazard > 0 and roll(hazard / 60) then
            rec = rec or {}
            d.infParts[name] = rec
            rec.inc = randRange(INF_INCUBATE_H[1], INF_INCUBATE_H[2]) * 60
            rec.L = 0
        end
        showLevel(part, 0)
        return 0
    end
    if rec.inc then
        -- contaminated: cleaning now ends it
        if treated then
            rec.inc, rec.L = nil, 0
            showLevel(part, 0)
            return 0
        end
        rec.inc = rec.inc - 1
        if rec.inc <= 0 then
            rec.inc = nil
            rec.L = INF_START_L
            showLevel(part, rec.L)
            return rec.L
        else
            showLevel(part, 0)
            return 0
        end
    end
    local L = rec.L or 0
    if not woundOpen(part) then
        -- the wound closed under a small infection (it cannot close over a
        -- bigger one, see holdHealing): the body finishes it off
        d.infParts[name] = nil
        showLevel(part, 0)
        return 0
    end
    if abxOn(d) then
        L = L - INF_ABX_L * perMin
    elseif treated and L < INF_SPREAD_L then
        L = L - INF_TOPICAL * perMin
    else
        L = L + INF_GROW * perMin * DanTraits_RunHooks("infectionGrowth", 1, player)
    end
    L = math.max(0, math.min(10, L))
    rec.L = L
    if L >= INF_NOHEAL_L then holdHealing(part, rec) else rec.held = nil end
    if L <= 0 then
        d.infParts[name] = rec.clean and { clean = true } or nil
    end
    showLevel(part, L)
    return L
end

-- bad side only: 0.5 none; lvl1 local, lvl2 fever, lvl3 sepsis, lvl4 septic shock
local INF_MOODLE_TIER = { thresholds = { 0.05, 0.15, 0.3, 0.45 } }
local function updateMoodle(player, stage, S)
    local v = 0
    if stage >= 2 then v = 0.2 end
    if stage >= 3 then v = 0.5 end
    if stage >= 4 then v = 0.8 end
    if S >= INF_SHOCK then v = 1 end
    DanTraits_BadMoodle(player, "Infection", v, INF_MOODLE_TIER)
end

local statAdd = DanTraits_StatAdd

local function updateInfectionMinute(player, d)
    if not sandboxOn() then return end
    d = infData(player)
    local perMin = 1 / 1440
    -- vanilla's one antibiotic, spent here instead
    pcall(function() if player:getReduceInfectionPower() > 0 then player:setReduceInfectionPower(0) end end)
    -- the antibiotic level decays
    if d.infAbx > 0 then
        d.infAbx = d.infAbx * 0.5 ^ (1 / (INF_ABX_HALF * 60))
        if d.infAbx < 0.01 then d.infAbx = 0 end
    end

    local maxL, contaminated = 0, false
    pcall(function()
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            local name = tostring(part:getType())
            local L = updatePart(player, d, part, name, perMin)
            if L > maxL then maxL = L end
            local rec = d.infParts[name]
            if rec and rec.inc then contaminated = true end
        end
    end)
    local woundL = maxL
    -- a relapse: infection left inside after an unfinished course, on no
    -- wound in particular; grows like one, and only antibiotics clear it
    if (d.infFocus or 0) > 0 then
        local F = d.infFocus
        if abxOn(d) then F = F - INF_ABX_L * perMin
        else F = F + INF_GROW * perMin * DanTraits_RunHooks("infectionGrowth", 1, player) end
        F = math.max(0, math.min(10, F))
        d.infFocus = F > 0 and F or nil
        if F > maxL then maxL = F end
    end
    d.infMaxL = maxL

    -- the whole body
    local S = d.infS
    if abxOn(d) then
        S = S - INF_S_ABX * perMin
    elseif maxL >= INF_SPREAD_L then
        S = S + INF_S_GROW * perMin * (maxL - INF_SPREAD_L + 1) / (10 - INF_SPREAD_L + 1) * DanTraits_RunHooks("infectionGrowth", 1, player)
    else
        S = S - INF_S_FIGHT * perMin
    end
    S = clamp01(S)
    d.infS = S

    -- the course: cleared before it was finished, and then left off
    if maxL <= 0 and S <= 0 and not contaminated then
        if d.infActive and d.infDoses > 0 and d.infDoses < INF_COURSE then d.infUnfinished = true end
        d.infActive = false
    elseif maxL > 0 or S > 0 then
        d.infActive = true
    end
    if d.infUnfinished then
        if d.infDoses >= INF_COURSE then
            d.infUnfinished, d.infOffH = nil, nil
        elseif not abxOn(d) then
            d.infOffH = (d.infOffH or 0) + 1 / 60
            if d.infOffH >= INF_RELAPSE_H then
                d.infUnfinished, d.infOffH = nil, nil
                if roll(INF_RELAPSE) then
                    d.infFocus = INF_RELAPSE_L
                    d.infActive = true
                    notify(player, "UI_DanTraits_InfectionRelapse")
                end
            end
        end
    end
    if not d.infActive and not d.infUnfinished then d.infDoses = 0 end

    local stage = 0
    if contaminated then stage = 1 end
    if maxL > 0 then stage = 2 end
    if S >= INF_FEVER then stage = 3 end
    if S >= INF_SEPSIS then stage = 4 end
    local before = d.infStage or 0
    -- (a relapse inside has its own notice, and no wound to be hot and red)
    if stage > before and STAGE_NOTICE[stage] and (stage ~= 2 or woundL > 0) then notify(player, STAGE_NOTICE[stage])
    elseif stage < 3 and before >= 3 then notifyGood(player, "UI_DanTraits_InfectionFeverBreaks") end
    d.infStage = stage
    updateMoodle(player, stage, S)

    -- fever and what comes with it
    local stats = player:getStats()
    local fever = 0
    if S >= INF_FEVER then fever = (S - INF_FEVER) / (1 - INF_FEVER) end
    d.infFever = fever
    local sickness = 0
    if S >= INF_FEVER then sickness = INF_SICKNESS[1] + (INF_SICKNESS[2] - INF_SICKNESS[1]) * fever end
    -- SICKNESS is held at the fever's level, up or down; if something else
    -- has it higher than we left it, that is theirs and left alone
    local held = d.infSickness or 0
    pcall(function()
        local now = stats:get(CharacterStat.SICKNESS) or 0
        if now < sickness or (held > 0 and now > sickness and math.abs(now - held) < 0.002) then
            stats:set(CharacterStat.SICKNESS, sickness)
        end
    end)
    d.infSickness = sickness
    pcall(function() d.infBodyTemp = stats:get(CharacterStat.TEMPERATURE) end)
    if fever > 0 then
        local asleep = DanTraits_Asleep(player)
        if not asleep then statAdd(stats, CharacterStat.FATIGUE, INF_FATIGUE * fever) end
        statAdd(stats, CharacterStat.THIRST, INF_THIRST * fever)
    end
    if S >= INF_SEPSIS then
        local t = (S - INF_SEPSIS) / (1 - INF_SEPSIS)
        local health = INF_HEALTH[1] + (INF_HEALTH[2] - INF_HEALTH[1]) * t
        pcall(function() player:getBodyDamage():ReduceGeneralHealth(health) end)
    end
end
DanTraits_updateInfectionMinute = updateInfectionMinute

-- a dose: from eating the game's Antibiotics, or the console
function DanTraits_TakeAntibiotic(player, amount)
    local d = infData(player)
    amount = amount or 1
    d.infAbx = (d.infAbx or 0) + amount
    d.infDoses = (d.infDoses or 0) + amount
    -- vanilla's one-shot effect is set inside the eat; undo it once it has been
    if DanTraits_Later then
        DanTraits_Later(2, function() pcall(function() player:setReduceInfectionPower(0) end) end)
    end
    return d.infAbx
end

DanTraits_AddHook("eat", function(_, player, item, fraction)
    if not player or not item or not sandboxOn() then return nil end
    local kind = ""
    pcall(function() kind = tostring(item:getType()) end)
    if kind == "Antibiotics" then DanTraits_TakeAntibiotic(player, math.min(1, fraction or 1)) end
    return nil
end)

-- 0..1 fever, for other systems
function DanTraits_InfectionFever(player)
    local d = player and player:getModData().DanTraits
    return (d and d.infFever) or 0
end

-- console: infect <part> [level] | contaminate <part> | sepsis <score> | antibiotic | infection clear
local function partName(arg) return DanTraits_PartNames[string.lower(tostring(arg or ""))] end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.infect = function(player, args)
    local name = partName(args[1])
    if not name then return "infect <part> [level 0..10]" end
    local d = infData(player)
    d.infParts[name] = { L = math.max(0, math.min(10, tonumber(args[2]) or INF_START_L)) }
    return "infected " .. name .. " at " .. tostring(d.infParts[name].L)
end
DanTraits_ExtraCommands.contaminate = function(player, args)
    local name = partName(args[1])
    if not name then return "contaminate <part>" end
    local d = infData(player)
    d.infParts[name] = { inc = tonumber(args[2]) or 60, L = 0 }
    return "contaminated " .. name .. ", shows in " .. tostring(d.infParts[name].inc) .. " min"
end
DanTraits_ExtraCommands.sepsis = function(player, args)
    local d = infData(player)
    d.infS = clamp01(tonumber(args[1]) or 0)
    return "infection score " .. tostring(d.infS)
end
DanTraits_ExtraCommands.antibiotic = function(player)
    return "antibiotic level " .. tostring(DanTraits_TakeAntibiotic(player, 1))
end
DanTraits_ExtraCommands.infection = function(player, args)
    if args[1] ~= "clear" then return "infection clear" end
    local d = infData(player)
    d.infParts, d.infS, d.infAbx, d.infDoses, d.infUnfinished, d.infOffH, d.infActive, d.infFocus = {}, 0, 0, 0, nil, nil, false, nil
    return "infection cleared"
end

DanTraits_Every("minute", "Infection", updateInfectionMinute, 23)
