-- Project Zomboid Vitality Project: Age.
-- Every character is in their 20s, 30s or 40s. The 30s are the default and
-- have no trait: pick neither Age trait and that is what you get. The
-- 20s and 40s traits are mutually exclusive, so every character has
-- exactly one age.
--
-- Experience: a new character gets extra levels in their profession's main
-- skill (the one the profession boosts most; all of them on a tie): none in
-- the 20s, one in the 30s and 40s by default. Unemployed has no main skill.
--
-- Trait costs are fixed by the script, so age is priced through the Age
-- traits' own cost and changes what other traits do, never how much they
-- cost. The rule that keeps that honest: age may make a negative harsher or
-- lock it out, and may make a positive stronger only where the Age trait
-- pays for it.
--   Handy        20s: can't be taken (mutually exclusive). 40s: +1 Carpentry.
--   Gym Regular  20s: regularity starts at 65 instead of 50.
--   Arthritis    20s: can't be taken. 40s: the weather gets into the joints
--                faster (joint factor x1.3), so flares come sooner.
--   Red cells    (bloodCellRebuild, Blood) 20s: rebuild x1.15. 40s: x0.8.
--   Concussion   (concussionHeal) 20s: heals x1.2. 40s: x0.75.
--   Hangover     (hangoverSeverity) 20s: severity x0.85. 40s: x1.25.
--   Type 2       (diaResistance, Diabetes) 20s: resistance -0.05. 40s: +0.1.
--   Brittle      (brittleChance) 40s: the fracture chance x1.25.
-- The 40s rows are all harsher negatives (the trait pays +1), the 20s rows
-- gentler ones (the trait costs -2).
--
-- Sandbox (page DanTraits): AgeEnabled turns all of this off (the Age traits
-- then do nothing), AgeBonus20s/30s/40s set the profession levels, and
-- AgeDefault is the age of a character who picks neither trait.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local hasVanillaTrait = DanTraits_HasVanillaTrait
local traitData = DanTraits_Data

local AGE_BONUS           = { [20] = 0, [30] = 1, [40] = 1 }  -- profession levels, when sandbox has none
local AGE_HANDY_LEVELS    = 1       -- 40s with Handy: extra Carpentry levels
local AGE_GYM_REGULARITY  = 65      -- 20s with Gym Regular: starting regularity
local AGE_ARTHRITIS_MULT  = 1.3     -- 40s with Arthritis: joint factor x this
local AGE_CELLS_20      = 1.15    -- red cells rebuild x this in the 20s...
local AGE_CELLS_40      = 0.8     -- ...and this in the 40s
local AGE_CONCUSSION_20 = 1.2     -- concussion heals x this in the 20s...
local AGE_CONCUSSION_40 = 0.75    -- ...and this in the 40s
local AGE_HANGOVER_20   = 0.85    -- hangover severity x this in the 20s...
local AGE_HANGOVER_40   = 1.25    -- ...and this in the 40s
local AGE_DIA_20        = -0.05   -- Type 2 resistance plus this in the 20s...
local AGE_DIA_40        = 0.1     -- ...and this in the 40s
local AGE_BRITTLE_40    = 1.25    -- Brittle: fracture chance x this in the 40s
local AGE_MAX_LEVEL       = 10

local function sandbox()
    return (SandboxVars and SandboxVars.DanTraits) or {}
end

local function ageEnabled()
    return DanTraits_SandboxOn("AgeEnabled")
end

-- 20, 30 or 40; age rounds down to its decade
local function roundBand(age)
    age = tonumber(age) or 30
    if age < 30 then return 20 end
    if age < 40 then return 30 end
    return 40
end

local function ageBand(player)
    if hasTrait(player, "age20s") then return 20 end
    if hasTrait(player, "age40s") then return 40 end
    return roundBand(sandbox().AgeDefault)
end
DanTraits_AgeBand = function(player)
    if not ageEnabled() then return 30 end
    return ageBand(player)
end

local function bonusLevels(band)
    local v = tonumber(sandbox()["AgeBonus" .. band .. "s"])
    if v == nil then v = AGE_BONUS[band] end
    return math.max(0, math.floor(v))
end

-- the profession's most-boosted skills: { perk, ... }
local function mainSkills(player)
    local out = {}
    pcall(function()
        local prof = player:getDescriptor():getCharacterProfession()
        local def = CharacterProfessionDefinition.getCharacterProfessionDefinition(prof)
        local boosts = def and def:getXpBoosts()
        if not boosts then return end
        local best = 0
        local levels = {}
        for perk, level in pairs(transformIntoKahluaTable(boosts)) do
            local n = level
            if type(level) ~= "number" then n = level:intValue() end
            levels[#levels + 1] = { perk = perk, level = n }
            if n > best then best = n end
        end
        if best <= 0 then return end
        for _, e in ipairs(levels) do
            if e.level == best then out[#out + 1] = e.perk end
        end
    end)
    return out
end
DanTraits_AgeMainSkills = mainSkills

-- raise a skill by that many levels (not past 10) and put its XP at the new level
local function addLevels(player, perk, count)
    local added = 0
    pcall(function()
        for _ = 1, count do
            if player:getPerkLevel(perk) >= AGE_MAX_LEVEL then break end
            player:LevelPerk(perk)
            added = added + 1
        end
        if added > 0 then player:getXp():setXPToLevel(perk, player:getPerkLevel(perk)) end
    end)
    return added
end

local function onAgeCreate(player)
    if not player or not ageEnabled() then return end
    local hours = 0
    pcall(function() hours = player:getHoursSurvived() or 0 end)
    if hours > 0 then return end
    local d = traitData(player)
    if d.ageApplied then return end
    local band = ageBand(player)
    d.ageApplied = true
    d.ageBand = band
    local bonus = bonusLevels(band)
    if bonus > 0 then
        for _, perk in ipairs(mainSkills(player)) do addLevels(player, perk, bonus) end
    end
    if band == 40 and hasVanillaTrait(player, "base:handy") then
        pcall(function() addLevels(player, Perks.Woodwork, AGE_HANDY_LEVELS) end)
    end
end

local function onAgeCreatePlayer(playerNum, player) onAgeCreate(player) end

-- Gym Regular: young habits stick
DanTraits_AddHook("gymRegularity", function(target, player)
    if not ageEnabled() or ageBand(player) ~= 20 then return nil end
    return math.max(target, AGE_GYM_REGULARITY)
end)

-- Arthritis: older joints feel the weather sooner
DanTraits_AddHook("arthritisJoint", function(joint, player)
    if not ageEnabled() or ageBand(player) ~= 40 then return nil end
    return math.min(1, joint * AGE_ARTHRITIS_MULT)
end)

-- the universal systems: the 40s pay for harsher ones (the trait gives +1), the
-- 20s get gentler ones (the trait costs -2); nil in the 30s and with age off
local function byBand(player, k20, k40)
    if not ageEnabled() then return nil end
    local band = ageBand(player)
    if band == 20 then return k20 elseif band == 40 then return k40 end
    return nil
end

-- red cells rebuild after blood loss (Blood)
DanTraits_AddHook("bloodCellRebuild", function(rate, player)
    local k = byBand(player, AGE_CELLS_20, AGE_CELLS_40)
    if not k then return nil end
    return rate * k
end)

-- concussion healing (Concussion)
DanTraits_AddHook("concussionHeal", function(rate, player)
    local k = byBand(player, AGE_CONCUSSION_20, AGE_CONCUSSION_40)
    if not k then return nil end
    return rate * k
end)

-- how bad a hangover is (Hangover)
DanTraits_AddHook("hangoverSeverity", function(severity, player)
    local k = byBand(player, AGE_HANGOVER_20, AGE_HANGOVER_40)
    if not k then return nil end
    return severity * k
end)

-- Type 2 resistance (Diabetes; added before the clamp)
DanTraits_AddHook("diaResistance", function(res, player)
    local plus = byBand(player, AGE_DIA_20, AGE_DIA_40)
    if not plus then return nil end
    return res + plus
end)

-- Brittle: older bones snap more easily (the 20s have nothing to add)
DanTraits_AddHook("brittleChance", function(chance, player)
    local k = byBand(player, 1, AGE_BRITTLE_40)
    if not k or k == 1 then return nil end
    return chance * k
end)

Events.OnCreatePlayer.Add(onAgeCreatePlayer)
