-- Project Zomboid Vitality Project: Age.
-- Every character is in their 20s, 30s, 40s or 50s and carries one Age trait.
-- The 30s are the game as it is. The creation screen makes the player pick
-- an age before anything else (DanTraits_Client.lua); "In Their 30s" costs
-- 0. A character with no Age trait at spawn (an old save, or a route that
-- skipped the screen) is granted the sandbox default's. The four
-- traits exclude each other (scripts/DanTraits.txt). docs/age.md has the
-- whole system in one place.
--
-- Experience: a new character's levels in their profession's main skill (the
-- one the profession boosts most; every one of them on a tie) change by age:
-- -2 / 0 / +2 / +3 by default (the 30s had +1 until 2026-10-09; the 20s had 0
-- until Age 2.0, 2026-10-31: the young start barely trained). Every other
-- skill the profession boosts moves with it: -1 in the 20s, +1 in the 40s,
-- +2 in the 50s: years on the job teach the whole trade. Nothing goes under
-- 0, and the profession's XP rate (its XPBoostMap) is never touched, so a
-- 20s Carpenter at Carpentry 1 still trains it at the Carpenter's +125%.
-- Fitness and Strength never get age's levels: age is years of practice, not
-- a better body (a Fitness Instructor's main skill is Sprinting). The
-- Unemployed have no main skill and get the levels in Maintenance (nothing
-- to lose in the 20s). DanTraits_AgeLevels works that out for the spawn code
-- here and for the creation screen (DanTraits_Client.lua), so the two agree.
--
-- The body: the AGE table below is every number. Younger recovers and trains
-- faster, older slower:
--   endurance   endurance recovery (enduranceRegen)
--   xp          Fitness and Strength experience (Events.AddXP)
--   heal        scratches and cuts close (their clocks, each minute) and an
--               unstitched deep wound heals (woundHeal, WoundCare)
--   stiff       stiffness after exertion fades (each part, each minute)
--   wakes       the interruptions counted in the sleep score (nightWakes,
--               Vitality: the wakes over the one every night has)
--   cells       red cells rebuild after blood loss (bloodCellRebuild, Blood)
--   concussion  a concussion heals (concussionHeal)
--   hangover    hangover severity (hangoverSeverity)
--   learn       experience on every skill but Fitness and Strength
--               (Events.AddXP): the 20s learn faster across the board
--   learn3      experience on any skill under level 3 (Events.AddXP): the
--               young pick things up, the old do not
--   combat      experience on the weapon skills, Aiming and Reloading: the
--               20s pick up fighting a little faster too
--   trade       experience on the skills the profession boosts: the trade
--               you know keeps coming
--   hunger      how fast hunger builds (the hungerRise stat delta pipeline)
--   clear       how fast things clear: caffeine (caffeineClearance), a
--               hangover's hours (hangoverHours, divided), drunkenness and
--               food sickness (whatever they fell by since last minute,
--               x this), and the half-life of daily and course medication
--               (medHalfLife, divided; rescue drugs are left alone)
--
-- Age pricing (DanTraits_AgeRules, read by DanTraits_AgeSurcharge): a trait
-- can cost more or fewer points in a band, drawn beside its cost on the
-- creation screen and taken off Points to Spend. Positive takes points (the
-- script's sign): Strong +4 in the 50s; Fit -1 in the 20s is a point cheaper;
-- a +1 on a trait that gives points means it gives one fewer.
-- The head (Age 2.0, 2026-10-31: the body forgives, the head does not; the
-- 20s only):
--   panic       panic builds (the panicRise stat delta pipeline; Seen It
--               All's 50s x0.8 is the mirror)
--   habit       the smoking and drinking habit meters build, and their daily
--               caps (habitGain, read by Smoker and Dependent)
--   craving     cravings come sooner: a Smoker's withdrawal builds, an
--               Alcoholic's and a Caffeine Dependent's dry hours to it are
--               divided (cravingOnset)
--   anger       the irritability a craving holds (angerFloor, Smoker and
--               Dependent)
--   episode     Spiraling's episode chance (mddEpisode, MDD)
--   schizo      Schizophrenia's episode chance (schizoChance, Hallucinations)
--   dia         Type 2 resistance, added (diaResistance, Diabetes)
--   brittle     Brittle: fracture chance (brittleChance)
--   arthritis   Arthritis: joint factor, so flares come sooner (arthritisJoint)
--   heart       Heart Condition: chest pain chance (DanTraits_AgeHeart, read by Heart)
--   gym         Gym Regular: starting regularity, at least this (gymRegularity)
--   handyLevels Handy: levels on top of vanilla's at spawn, by skill name. The
--               40s and 50s get +1 Carpentry
--   handyAll    Handy: levels on every skill Handy boosts (read from its
--               definition, so a mod that changes Handy is followed): the
--               20s have vanilla's four (Carpentry, Maintenance, Carving,
--               Masonry) taken back and train those skills faster instead
--               (handyXp, Events.AddXP): young hands learn the trade, they do
--               not arrive knowing it
-- The traits some ages cannot take (In Their 20s: Arthritis, Brittle, Type 2,
-- Hard of Hearing; the traits of one age) are DanTraits_AgeRules' too.
--
-- Trait costs are fixed by the script, so age is priced through the Age
-- traits' own cost and changes what other traits do: In Their 20s costs 5
-- points, the 40s cost nothing and the 50s give 6 back (Age 2.0; the 20s
-- cost 6 and the 40s gave 2 until then). (The flat re-pricing of a few
-- vanilla traits, age aside, is DanTraits_VanillaPrices.lua.) The one exception is the body
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
    [20] = { levels = -2, side = -1, endurance = 1.25, xp = 1.5, heal = 1.5, stiff = 1.5, wakes = 0.8,
             cells = 1.15, concussion = 1.2, hangover = 0.85, dia = -0.05, heart = 0.8, gym = 65,
             learn = 1.15, learn3 = 1.3, combat = 1.15, hunger = 1.15, clear = 1.2,
             panic = 1.15, habit = 1.3, craving = 1.25, anger = 1.25, episode = 1.3, schizo = 1.25,
             handyAll = -1, handyXp = 1.5 },
    [30] = { levels = 0 },
    [40] = { levels = 2, side = 1, endurance = 0.92, xp = 0.9, heal = 0.9, stiff = 0.85, wakes = 1.15,
             cells = 0.8, concussion = 0.75, hangover = 1.25, dia = 0.1, heart = 1.25,
             brittle = 1.25, arthritis = 1.3, handyLevels = { Woodwork = 1 },
             trade = 1.1, hunger = 0.95, clear = 0.9 },
    [50] = { levels = 3, side = 2, endurance = 0.85, xp = 0.8, heal = 0.8, stiff = 0.7, wakes = 1.3,
             cells = 0.65, concussion = 0.6, hangover = 1.5, dia = 0.2, heart = 1.5,
             brittle = 1.5, arthritis = 1.6, handyLevels = { Woodwork = 1 },
             learn3 = 0.9, trade = 1.15, hunger = 0.9, clear = 0.8 },
}
-- Age pricing and the traits only some ages may take are one table since Age
-- 2.0: DanTraits_AgeRules (DanTraits_AgeRules.lua). DanTraits_AgeSurcharge
-- below reads it.
local AGE_LEARN_BELOW = 3      -- learn3: skills under this level
-- vanilla Handy's XP boosts (game 42.21): the skills handyAll and handyXp speak
-- of, when Handy's definition cannot be read (a mod may change the list)
local HANDY_FALLBACK = { "Woodwork", "Maintenance", "Carving", "Masonry" }
local AGE_TRAIT = { [20] = "age20s", [30] = "age30s", [40] = "age40s", [50] = "age50s" }
local AGE_BANDS = { 20, 30, 40, 50 }
local AGE_MAX_LEVEL = 10
-- the weapon skills, Aiming and Reloading, for `combat` when Burnout's parent-based
-- check (DanTraits_StrainIsCombatPerk) is not loaded
local AGE_COMBAT = { "Axe", "Blunt", "SmallBlunt", "LongBlade", "SmallBlade", "Spear", "Aiming", "Reloading" }
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

-- the band's levels on the main skill: the sandbox's number (negative takes levels off)
local function bonusLevels(band)
    return math.floor(DanTraits_SandboxNum("AgeBonus" .. band .. "s", AGE[band].levels))
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

-- the skills Handy boosts, from its definition; the fallback list when it
-- cannot be read (the tests, or a boot before the scripts): { perk, ... }
local handyCache = nil
local function handyPerks()
    if handyCache then return handyCache end
    local list = {}
    pcall(function()
        local def = CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.HANDY)
        local map = def and def:getXpBoosts()
        if map then
            for perk in pairs(transformIntoKahluaTable(map)) do list[#list + 1] = perk end
        end
    end)
    if #list == 0 then
        for _, name in ipairs(HANDY_FALLBACK) do list[#list + 1] = Perks[name] end
        return list   -- not cached: the definition may be readable later
    end
    handyCache = list
    return list
end
DanTraits_AgeHandyPerks = handyPerks

-- The levels age gives (or takes from) a new character: { perk = levels },
-- negative for levels off (the spawn code stops at 0; the creation screen
-- shows them greyed).
--   boosts  the profession's XP boosts as a Lua table (nil for none)
--   band    20, 30, 40 or 50
--   handy   whether the character has vanilla Handy
--   bonus   the band's main-skill levels; nil reads the sandbox (the creation
--           screen passes the new game's value, SandboxVars is stale there).
--           0 is "no age levels at all", side skills included.
function DanTraits_AgeLevels(boosts, band, handy, bonus)
    local out = {}
    local info = AGE[band] or AGE[30]
    bonus = tonumber(bonus) or bonusLevels(band)
    local main, rest = professionSkills(boosts)
    if bonus ~= 0 then
        local to = main
        if #to == 0 and bonus > 0 then to = { Perks.Maintenance } end   -- nothing to take from the Unemployed
        for _, perk in ipairs(to) do out[perk] = bonus end
        if info.side then
            for _, perk in ipairs(rest) do out[perk] = info.side end
        end
    end
    if handy and info.handyAll then
        for _, perk in ipairs(handyPerks()) do
            local v = (out[perk] or 0) + info.handyAll
            out[perk] = v ~= 0 and v or nil
        end
    end
    if handy and info.handyLevels then
        for name, n in pairs(info.handyLevels) do
            local perk = Perks[name]
            local v = (out[perk] or 0) + n
            out[perk] = v ~= 0 and v or nil
        end
    end
    return out
end

-- the extra points a trait costs in that band (0 for most traits and bands;
-- negative is cheaper); `kind` is the trait's type, as the creation screen
-- holds it. The rows are DanTraits_AgeRules'.
function DanTraits_AgeSurcharge(band, kind)
    if not band or kind == nil or not DanTraits_AgeRuleFor then return 0 end
    local row = DanTraits_AgeRuleFor(kind)
    if not row or not row.price then return 0 end
    return row.price[band] or 0
end

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
-- for the other files that give levels at spawn (DanTraits_VanillaPrices.lua)
DanTraits_AddLevels = addLevels
DanTraits_LoseLevels = loseLevels

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
    local levels = DanTraits_AgeLevels(professionBoosts(player), band, hasVanillaTrait(player, "base:handy"), nil)
    for perk, count in pairs(levels) do
        if count > 0 then addLevels(player, perk, count) else loseLevels(player, perk, -count) end
    end
end

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
-- the head rows
DanTraits_AddHook("panicRise", scales("panic"))
DanTraits_AddHook("habitGain", scales("habit"))
DanTraits_AddHook("cravingOnset", scales("craving"))
DanTraits_AddHook("angerFloor", scales("anger"))
DanTraits_AddHook("mddEpisode", scales("episode"))
DanTraits_AddHook("schizoChance", scales("schizo"))
-- the morning wake is everyone's: only the wakes over it are scaled (x1.3 on
-- an unbroken night charged the 50s 0.3 of a wake for nothing)
DanTraits_AddHook("nightWakes", function(wakes, player)
    local k = ageValue(player, "wakes")
    if not k then return nil end
    return 1 + (wakes - 1) * k
end)
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

local inList = DanTraits_InList

local function isHandySkill(perk)
    for _, p in ipairs(handyPerks()) do
        if p == perk then return true end
    end
    return false
end

-- a weapon skill, Aiming or Reloading (Burnout's check by the perk's parent when it
-- is loaded, else the vanilla list)
local function isCombatPerk(perk)
    if DanTraits_StrainIsCombatPerk then return DanTraits_StrainIsCombatPerk(perk) end
    for _, name in ipairs(AGE_COMBAT) do
        if Perks[name] == perk then return true end
    end
    return false
end
DanTraits_AgeIsCombatPerk = isCombatPerk   -- Natural (DanTraits_AgeTraits.lua)

-- Experience by band: Fitness and Strength (xp); every other skill (learn:
-- the 20s learn faster across the board); any other skill under level 3
-- (learn3: the young pick things up, the old do not); the weapon skills,
-- Aiming and Reloading (combat); the skills the profession boosts (trade: the
-- trade you know keeps coming); Handy's skills with Handy (handyXp: the 20s
-- train them instead of starting with the levels). The factors multiply.
local function onAgeAddXP(player, perk, amount)
    if not player or not perk or not amount or amount <= 0 then return end
    local k = 1
    if Perks and (perk == Perks.Fitness or perk == Perks.Strength) then
        k = ageValue(player, "xp") or 1
    else
        local all = ageValue(player, "learn")
        if all and all ~= 1 then k = k * all end
        local learn = ageValue(player, "learn3")
        if learn and learn ~= 1 then
            local level = AGE_LEARN_BELOW
            pcall(function() level = player:getPerkLevel(perk) end)
            if level < AGE_LEARN_BELOW then k = k * learn end
        end
        local combat = ageValue(player, "combat")
        if combat and combat ~= 1 and isCombatPerk(perk) then k = k * combat end
        local trade = ageValue(player, "trade")
        if trade and trade ~= 1 then
            local main, rest = DanTraits_AgeProfessionSkills(player)
            if inList(main, perk) or inList(rest, perk) then k = k * trade end
        end
        local handy = ageValue(player, "handyXp")
        if handy and handy ~= 1 and isHandySkill(perk) and hasVanillaTrait(player, "base:handy") then
            k = k * handy
        end
    end
    if k == 1 then return end
    DanTraits_XpFactor(player, perk, amount, k)
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
    -- the healPace hook (Fast Recovery hurries the clocks); 1 is no change
    heal = tonumber(DanTraits_RunHooks("healPace", heal or 1, player, d)) or heal
    if heal == 1 then heal = nil end
    -- the stiffFade hook (Fitness: stretching hurries the fade); 1 is no change
    stiff = tonumber(DanTraits_RunHooks("stiffFade", stiff or 1, player, d)) or stiff
    if stiff == 1 then stiff = nil end
    if not heal and not stiff then
        d.ageParts = nil
        return
    end
    d.ageParts = d.ageParts or {}
    DanTraits_EachPart(player, function(part, name)
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
    end, "Age")
end

-- Fitness: muscles recover at the band's stiffness pace (faster young, slower old)
DanTraits_AddHook("fitnessRecovery", function(rate, player)
    local k = ageValue(player, "stiff")
    if k then return rate * k end
    return nil
end)

DanTraits_OnPlayerReady("Age", onAgeCreate, 50)   -- the age band's trait and starting levels
Events.AddXP.Add(onAgeAddXP)
DanTraits_Every("minute", "Age", updateAgeMinute, 23.5)
