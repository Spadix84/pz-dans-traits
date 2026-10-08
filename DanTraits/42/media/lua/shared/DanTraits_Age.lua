-- Project Zomboid Vitality Project: Age.
-- Every character is in their 20s, 30s, 40s or 50s and carries one Age trait.
-- The 30s are the game as it is. The creation screen makes the player pick
-- an age before anything else (DanTraits_Client.lua); "In Their 30s" costs
-- 0. A character with no Age trait at spawn (an old save, or a route that
-- skipped the screen) is granted the sandbox default's. The four
-- traits exclude each other (scripts/DanTraits.txt). docs/age.md has the
-- whole system in one place.
--
-- Experience: a new character gets extra levels in their profession's main
-- skill (the one the profession boosts most; every one of them on a tie):
-- 0 / 1 / 2 / 3 by default. Every other skill the profession boosts gets
-- one level in the 40s and two in the 50s: years on the job teach the whole
-- trade. Fitness and Strength never get age's levels: age is years of
-- practice, not a better body (a Fitness Instructor's main skill is
-- Sprinting). The Unemployed have no main skill and get the levels in
-- Maintenance. DanTraits_AgeLevels works that out for the spawn code here
-- and for the creation screen (DanTraits_Client.lua), so the two agree.
--
-- The body: the AGE table below is every number. Younger recovers and trains
-- faster, older slower:
--   endurance   endurance recovery (enduranceRegen)
--   xp          Fitness and Strength experience (Events.AddXP)
--   heal        scratches and cuts close (their clocks, each minute) and an
--               unstitched deep wound heals (woundHeal, WoundCare)
--   stiff       stiffness after exertion fades (each part, each minute)
--   wakes       night wakes counted in the sleep score (nightWakes, Vitality)
--   cells       red cells rebuild after blood loss (bloodCellRebuild, Blood)
--   concussion  a concussion heals (concussionHeal)
--   hangover    hangover severity (hangoverSeverity)
--   learn3      experience on any skill under level 3 (Events.AddXP): the
--               young pick things up, the old do not
--   trade       experience on the skills the profession boosts: the trade
--               you know keeps coming
--   hunger      how fast hunger builds (the hungerRise stat delta pipeline)
--   clear       how fast things clear: caffeine (caffeineClearance), a
--               hangover's hours (hangoverHours, divided), drunkenness and
--               food sickness (whatever they fell by since last minute,
--               x this), and the half-life of daily and course medication
--               (medHalfLife, divided; rescue drugs are left alone)
--
-- Age pricing (AGE_PRICE, DanTraits_AgeSurcharge): a trait can cost more or
-- fewer points in a band, drawn beside its cost on the creation screen and
-- taken off Points to Spend. Positive takes points (the script's sign):
-- Strong +4 in the 50s; Fit -1 in the 20s is a point cheaper; a +1 on a
-- trait that gives points means it gives one fewer.
--   dia         Type 2 resistance, added (diaResistance, Diabetes)
--   brittle     Brittle: fracture chance (brittleChance)
--   arthritis   Arthritis: joint factor, so flares come sooner (arthritisJoint)
--   heart       Heart Condition: chest pain chance (DanTraits_AgeHeart, read by Heart)
--   gym         Gym Regular: starting regularity, at least this (gymRegularity)
--   handy       Handy: extra Carpentry levels at spawn
-- In Their 20s cannot be taken with Handy or Arthritis (the script).
-- The traits only one age can take are in DanTraits_AgeTraits.lua.
--
-- Trait costs are fixed by the script, so age is priced through the Age
-- traits' own cost and changes what other traits do: In Their 20s costs 6
-- points, the 40s give 2 back and the 50s 6. The one exception is the body
-- traits: staying Strong or Athletic costs 2 points more in the 40s and 4 in
-- the 50s, Stout or Fit 1 and 2 (AGE_BODY and `body` below). The creation
-- screen takes it off the points to spend (DanTraits_AgeSurcharge, read by
-- DanTraits_Client.lua); nothing changes after creation.
--
-- Sandbox (page DanTraits): AgeEnabled turns all of this off (the Age traits
-- are then hidden at character creation, DanTraits_Client.lua),
-- AgeBonus20s/30s/40s/50s set the profession levels, and AgeDefault is the
-- age of a character who picks no Age trait.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local hasVanillaTrait = DanTraits_HasVanillaTrait
local traitData = DanTraits_Data
local num = DanTraits_PartNum

local AGE = {
    [20] = { levels = 0, endurance = 1.25, xp = 1.5, heal = 1.5, stiff = 1.5, wakes = 0.8,
             cells = 1.15, concussion = 1.2, hangover = 0.85, dia = -0.05, heart = 0.8, gym = 65,
             learn3 = 1.2, hunger = 1.15, clear = 1.2 },
    [30] = { levels = 1 },
    [40] = { levels = 2, side = 1, endurance = 0.92, xp = 0.9, heal = 0.9, stiff = 0.85, wakes = 1.15,
             cells = 0.8, concussion = 0.75, hangover = 1.25, dia = 0.1, heart = 1.25,
             brittle = 1.25, arthritis = 1.3, handy = 1,
             trade = 1.1, hunger = 0.95, clear = 0.9 },
    [50] = { levels = 3, side = 2, endurance = 0.85, xp = 0.8, heal = 0.8, stiff = 0.7, wakes = 1.3,
             cells = 0.65, concussion = 0.6, hangover = 1.5, dia = 0.2, heart = 1.5,
             brittle = 1.5, arthritis = 1.6, handy = 1,
             learn3 = 0.9, trade = 1.15, hunger = 0.9, clear = 0.8 },
}
-- Age pricing: trait (lower-case type, as the creation screen holds it) ->
-- band -> points more (or fewer, negative). The body costs more to keep with
-- age; learning is cheap young and dear old; a hearty appetite is natural
-- young. (Light Eater had a row until 2026-10-07; taken out as not worth it.)
local AGE_PRICE = {
    ["base:strong"]         = { [40] = 2, [50] = 4 },
    ["base:athletic"]       = { [40] = 2, [50] = 4 },
    ["base:stout"]          = { [40] = 1, [50] = 2 },
    ["base:fit"]            = { [20] = -1, [40] = 1, [50] = 2 },
    ["base:fastlearner"]    = { [20] = -1, [50] = 1 },
    ["base:slowlearner"]    = { [20] = 1, [50] = 1 },      -- gives a point fewer, young or old
    ["base:heartyappetite"] = { [20] = 1, [50] = -1 },     -- gives a point fewer young, one more old
}
local AGE_LEARN_BELOW = 3      -- learn3: skills under this level
local AGE_TRAIT = { [20] = "age20s", [30] = "age30s", [40] = "age40s", [50] = "age50s" }
local AGE_BANDS = { 20, 30, 40, 50 }
local AGE_MAX_LEVEL = 10
local AGE_GREEN = 1            -- Green: levels off every skill the profession boosts
local AGE_CLOCK_MIN = 0.01     -- a hurried scratch or cut stops here; the game closes it

local function sandbox()
    return (SandboxVars and SandboxVars.DanTraits) or {}
end

local function ageEnabled()
    return DanTraits_SandboxOn("AgeEnabled")
end

-- 20, 30, 40 or 50; age rounds down to its decade
local function roundBand(age)
    age = tonumber(age) or 30
    if age < 30 then return 20 end
    if age < 40 then return 30 end
    if age < 50 then return 40 end
    return 50
end
DanTraits_AgeRoundBand = roundBand

local function ageBand(player)
    for _, band in ipairs(AGE_BANDS) do
        if hasTrait(player, AGE_TRAIT[band]) then return band end
    end
    return roundBand(sandbox().AgeDefault)
end
DanTraits_AgeBand = function(player)
    if not ageEnabled() then return 30 end
    return ageBand(player)
end

-- the band's number for one effect; nil in the 30s, with age off, or when the
-- band has nothing to say about it
local function ageValue(player, key)
    if not ageEnabled() then return nil end
    return AGE[ageBand(player)][key]
end

local function bonusLevels(band)
    local v = tonumber(sandbox()["AgeBonus" .. band .. "s"])
    if v == nil then v = AGE[band].levels end
    return math.max(0, math.floor(v))
end

-- the most-boosted skills in a profession's XP boosts (perk -> level, the
-- levels numbers or Java Integers), Fitness and Strength aside, and the
-- other skills it boosts: { perk, ... }, { perk, ... }; both empty for no boosts
local function professionSkills(boosts)
    local out, rest = {}, {}
    if not boosts then return out, rest end
    local best = 0
    local levels = {}
    for perk, level in pairs(boosts) do
        if perk ~= Perks.Fitness and perk ~= Perks.Strength then
            local n = level
            if type(level) ~= "number" then n = level:intValue() end
            levels[#levels + 1] = { perk = perk, level = n }
            if n > best then best = n end
        end
    end
    if best <= 0 then return out, rest end
    for _, e in ipairs(levels) do
        if e.level == best then out[#out + 1] = e.perk
        elseif e.level > 0 then rest[#rest + 1] = e.perk end
    end
    return out, rest
end

-- The levels age gives a new character: { perk = levels }.
--   boosts  the profession's XP boosts as a Lua table (nil for none)
--   band    20, 30, 40 or 50
--   handy   whether the character has vanilla Handy
--   bonus   the band's profession levels; nil reads the sandbox (the creation
--           screen passes the new game's value, SandboxVars is stale there)
--   green   whether the character has Green (DanTraits_AgeTraits.lua): every
--           skill the profession boosts a level lower, so a count can be negative
function DanTraits_AgeLevels(boosts, band, handy, bonus, green)
    local out = {}
    local info = AGE[band] or AGE[30]
    bonus = tonumber(bonus) or bonusLevels(band)
    local main, rest = professionSkills(boosts)
    if bonus > 0 then
        local to = main
        if #to == 0 then to = { Perks.Maintenance } end
        for _, perk in ipairs(to) do out[perk] = bonus end
        if info.side then
            for _, perk in ipairs(rest) do out[perk] = info.side end
        end
    end
    if green then
        for _, list in ipairs({ main, rest }) do
            for _, perk in ipairs(list) do
                local n = (out[perk] or 0) - AGE_GREEN
                out[perk] = n ~= 0 and n or nil
            end
        end
    end
    if handy and info.handy then
        out[Perks.Woodwork] = (out[Perks.Woodwork] or 0) + info.handy
    end
    return out
end

-- the extra points a trait costs in that band (0 for most traits and bands;
-- negative is cheaper); `kind` is the trait's type, as the creation screen holds it
function DanTraits_AgeSurcharge(band, kind)
    if not band or kind == nil then return 0 end
    local row = AGE_PRICE[string.lower(tostring(kind))]
    if not row then return 0 end
    return row[band] or 0
end

-- the whole pricing table, for the docs and the dashboard
function DanTraits_AgePrices() return AGE_PRICE end

local function professionBoosts(player)
    local boosts = nil
    pcall(function()
        local prof = player:getDescriptor():getCharacterProfession()
        local def = CharacterProfessionDefinition.getCharacterProfessionDefinition(prof)
        local map = def and def:getXpBoosts()
        if map then boosts = transformIntoKahluaTable(map) end
    end)
    return boosts
end

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

-- lower a skill by that many levels (not under 0) and put its XP at the new level
local function loseLevels(player, perk, count)
    local lost = 0
    pcall(function()
        for _ = 1, count do
            if player:getPerkLevel(perk) <= 0 then break end
            player:LoseLevel(perk)
            lost = lost + 1
        end
        if lost > 0 then player:getXp():setXPToLevel(perk, player:getPerkLevel(perk)) end
    end)
    return lost
end

-- The skills of the player's profession: the main ones (Maintenance for the
-- Unemployed) and the others it boosts. Read from the profession once per
-- player object; the experience traits ask on every gain.
local skillsCache = { player = nil, main = nil, rest = nil }
function DanTraits_AgeProfessionSkills(player)
    local c = skillsCache
    if c.player ~= player or not c.main then
        local main, rest = professionSkills(professionBoosts(player))
        if #main == 0 then main = { Perks.Maintenance } end
        c.player, c.main, c.rest = player, main, rest
    end
    return c.main, c.rest
end

-- everyone carries their age: a character with no Age trait gets the band's
-- (a new one who picked none, or an old save from before the 30s had a trait)
local function grantAgeTrait(player, band)
    for _, b in ipairs(AGE_BANDS) do
        if hasTrait(player, AGE_TRAIT[b]) then return false end
    end
    return DanTraits_SetTrait(player, AGE_TRAIT[band], true)
end

local function onAgeCreate(player)
    if not player or not ageEnabled() then return end
    local band = ageBand(player)
    grantAgeTrait(player, band)
    local hours = 0
    pcall(function() hours = player:getHoursSurvived() or 0 end)
    if hours > 0 then return end
    local d = traitData(player)
    if d.ageApplied then return end
    d.ageApplied = true
    d.ageBand = band
    local levels = DanTraits_AgeLevels(professionBoosts(player), band, hasVanillaTrait(player, "base:handy"), nil,
        hasTrait(player, "green"))
    for perk, count in pairs(levels) do
        if count > 0 then addLevels(player, perk, count) else loseLevels(player, perk, -count) end
    end
end

local function onAgeCreatePlayer(playerNum, player) onAgeCreate(player) end

-- a hook that multiplies by the band's number for `key`
local function scales(key)
    return function(value, player)
        local k = ageValue(player, key)
        if not k then return nil end
        return value * k
    end
end

DanTraits_AddHook("enduranceRegen", scales("endurance"))
DanTraits_AddHook("woundHeal", scales("heal"))
DanTraits_AddHook("nightWakes", scales("wakes"))
DanTraits_AddHook("bloodCellRebuild", scales("cells"))
DanTraits_AddHook("concussionHeal", scales("concussion"))
DanTraits_AddHook("hangoverSeverity", scales("hangover"))
DanTraits_AddHook("brittleChance", scales("brittle"))
DanTraits_AddHook("hungerRise", scales("hunger"))
DanTraits_AddHook("caffeineClearance", scales("clear"))

-- a hook that divides by the band's number for `key` (a time that a faster
-- clearance shortens)
local function shortens(key)
    return function(value, player)
        local k = ageValue(player, key)
        if not k or k == 0 then return nil end
        return value / k
    end
end

DanTraits_AddHook("hangoverHours", shortens("clear"))
-- daily and course medication only (DanTraits_Meds.lua runs the hook for those kinds)
DanTraits_AddHook("medHalfLife", shortens("clear"))

-- Type 2 resistance (Diabetes; added before the clamp)
DanTraits_AddHook("diaResistance", function(res, player)
    local plus = ageValue(player, "dia")
    if not plus then return nil end
    return res + plus
end)

-- Gym Regular: young habits stick
DanTraits_AddHook("gymRegularity", function(target, player)
    local floor = ageValue(player, "gym")
    if not floor then return nil end
    return math.max(target, floor)
end)

-- Arthritis: older joints feel the weather sooner
DanTraits_AddHook("arthritisJoint", function(joint, player)
    local k = ageValue(player, "arthritis")
    if not k then return nil end
    return math.min(1, joint * k)
end)

-- Heart Condition: the chest pain chance, x this (1 in the 30s and with age off)
function DanTraits_AgeHeart(player)
    return ageValue(player, "heart") or 1
end

-- Add experience to a skill (or take it back, extra < 0) without the game's
-- multipliers. A slower learner never drops under the level they hold. For
-- the handlers of Events.AddXP, which fires after the game has added the
-- experience. The game fires the event for this addition too, callLua false
-- or not, so while it runs further adjustments are dropped and
-- DanTraits_AgeXpBusy() tells other handlers to leave it alone.
local xpAdjusting = false

function DanTraits_AgeXpBusy() return xpAdjusting end

function DanTraits_AgeXpAdjust(player, perk, extra)
    if xpAdjusting then return end
    xpAdjusting = true
    pcall(function()
        local xp = player:getXp()
        if extra < 0 then
            local held = perk:getTotalXpForLevel(player:getPerkLevel(perk))
            extra = -math.min(-extra, math.max(0, xp:getXP(perk) - held))
        end
        if extra ~= 0 then xp:AddXP(perk, extra, false, false, false, false) end
    end)
    xpAdjusting = false
end

local function inList(list, perk)
    for _, p in ipairs(list or {}) do
        if p == perk then return true end
    end
    return false
end

-- Experience by band: Fitness and Strength (xp); any other skill under
-- level 3 (learn3: the young pick things up, the old do not); the skills the
-- profession boosts (trade: the trade you know keeps coming). The factors
-- multiply.
local function onAgeAddXP(player, perk, amount)
    if not player or not perk or not amount or amount <= 0 then return end
    local k = 1
    if Perks and (perk == Perks.Fitness or perk == Perks.Strength) then
        k = ageValue(player, "xp") or 1
    else
        local learn = ageValue(player, "learn3")
        if learn and learn ~= 1 then
            local level = AGE_LEARN_BELOW
            pcall(function() level = player:getPerkLevel(perk) end)
            if level < AGE_LEARN_BELOW then k = k * learn end
        end
        local trade = ageValue(player, "trade")
        if trade and trade ~= 1 then
            local main, rest = DanTraits_AgeProfessionSkills(player)
            if inList(main, perk) or inList(rest, perk) then k = k * trade end
        end
    end
    if k == 1 then return end
    DanTraits_AgeXpAdjust(player, perk, amount * (k - 1))
end

-- Each minute: whatever a scratch's or cut's clock, or a part's stiffness,
-- fell by since the last look is stretched (older) or hurried (younger).
-- Only falls are touched, and nothing that reached zero is brought back.
-- Runs after Infection (which holds an infected wound's clocks where they
-- were, so there is no fall to see) and before the floors Arthritis and MS
-- put on stiffness, which win.
local AGE_CLOCKS = { { "getScratchTime", "setScratchTime" }, { "getCutTime", "setCutTime" } }

-- the value to write for something that fell from `was` to `now`, or nil
local function paced(was, now, k, min)
    if not was or now >= was or now <= 0 then return nil end
    return math.max(min, was - (was - now) * k)
end

-- Clearance: whatever drunkenness and food sickness fell by since the last
-- look is hurried (young) or stretched (old). Only falls are touched. Food
-- sickness is also the delta pipeline's: the pipeline is told the new value
-- so it does not read a stretched fall as a rise.
local AGE_CLEARS = {
    { stat = "INTOXICATION", key = "intox" },
    { stat = "FOOD_SICKNESS", key = "sick", pipeline = "foodSicknessRise" },
}

local function updateAgeClearance(player, d)
    local clear = ageValue(player, "clear")
    if not clear or clear == 1 then d.ageClear = nil return end
    d.ageClear = d.ageClear or {}
    pcall(function()
        local stats = player:getStats()
        for _, c in ipairs(AGE_CLEARS) do
            local stat = CharacterStat[c.stat]
            local now = tonumber(stats:get(stat)) or 0
            local was = d.ageClear[c.key]
            local new = nil
            if was and now < was then new = math.max(0, was - (was - now) * clear) end   -- a fall to nothing still lingers for the old
            if new and new ~= now then
                pcall(function() stats:set(stat, new) end)
                now = new
                if c.pipeline then DanTraits_DeltaRemember(d, c.pipeline, now) end
            end
            d.ageClear[c.key] = now
        end
    end)
end

local function updateAgeMinute(player, d)
    updateAgeClearance(player, d)
    local heal, stiff = ageValue(player, "heal"), ageValue(player, "stiff")
    if not heal and not stiff then
        d.ageParts = nil
        return
    end
    d.ageParts = d.ageParts or {}
    local parts = player:getBodyDamage():getBodyParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local name = tostring(part:getType())
        local rec = d.ageParts[name] or {}
        local kept = false     -- Kahlua has no next(): note whether rec holds anything
        if heal then
            for _, c in ipairs(AGE_CLOCKS) do
                local now = num(part, c[1])
                local new = paced(rec[c[1]], now, heal, AGE_CLOCK_MIN)
                if new then
                    pcall(function() part[c[2]](part, new) end)
                    now = new
                end
                rec[c[1]] = now > 0 and now or nil
                kept = kept or now > 0
            end
        end
        if stiff then
            local now = num(part, "getStiffness")
            local new = paced(rec.stiff, now, stiff, 0)
            if new then
                pcall(function() part:setStiffness(new) end)
                now = new
            end
            rec.stiff = now > 0 and now or nil
            kept = kept or now > 0
        end
        d.ageParts[name] = kept and rec or nil
    end
end

Events.OnCreatePlayer.Add(onAgeCreatePlayer)
Events.AddXP.Add(onAgeAddXP)
DanTraits_Every("minute", "Age", updateAgeMinute, 23.5)
