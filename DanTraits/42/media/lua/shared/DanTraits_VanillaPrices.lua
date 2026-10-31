-- Project Zomboid Vitality Project: the vanilla traits this mod re-prices.
--
-- Vanilla's trait definitions are left alone. Until Age 2.0 (2026-10-31) the
-- script redefined seven of them wholesale (Fear of Blood, Smoker, Iron Gut,
-- Resilient, Keen Cook, Blacksmith Knowledge, Cat's Eyes) to change their
-- cost, which clashed with any other mod that touched the same trait and lost
-- every field a game update added. Now the cost change is a flat delta in the
-- table below, drawn beside the trait's own cost on the creation screen and
-- taken off Points to Spend the way the age surcharge is (DanTraits_Client.lua,
-- DanTraits_TIYL.lua); the vanilla definition stands, whatever another mod
-- does to it. The game's sign: positive takes points (Resilient costs 6 more
-- for the Knox roll, DanTraits_Knox.lua), negative gives them (Fear of Blood
-- gives one more for the faint, DanTraits_Hemophobia.lua). Smoker is not
-- here: the mod has a Smoker of its own (DanTraits_Smoker.lua).
--
-- Two of them also gave a level the redefinition carried as an XP boost: Keen
-- Cook +1 Short Blade (knife work) and Blacksmith Knowledge +1 Short Blunt
-- (hammer work). Those are given at spawn here, the way age gives its levels
-- (DanTraits_AddLevels, DanTraits_Age.lua), and shown on the creation screen's
-- Major Skills list the same way (DanTraits_VanillaLevels, read by the client).
--
-- The reason for each delta is appended to the trait's description at boot
-- (CharacterTraitDefinition:setDescription, text only, once), so the row says
-- why: "Vitality: +6, a chance to beat the Knox infection". A row with no
-- delta (Outdoorsman) only gets its line: the translation files used to
-- override the vanilla description keys for that, which is the same kind of
-- clash the redefinitions were.
require "DanTraits"

local hasVanillaTrait = DanTraits_HasVanillaTrait
local traitData = DanTraits_Data

-- lower-case trait id -> { delta, why }; `why` is the text key of the line added to the description
local PRICES = {
    ["base:hemophobic"]  = { delta = -1, why = "UI_DanTraits_PriceWhyHemophobic" },
    ["base:irongut"]     = { delta = 2,  why = "UI_DanTraits_PriceWhyIronGut" },
    ["base:resilient"]   = { delta = 6,  why = "UI_DanTraits_PriceWhyResilient" },
    ["base:cook"]        = { delta = 1,  why = "UI_DanTraits_PriceWhyCook" },
    ["base:blacksmith"]  = { delta = 1,  why = "UI_DanTraits_PriceWhyBlacksmith" },
    ["base:nightvision"] = { delta = -2, why = "UI_DanTraits_PriceWhyNightVision" },
    -- no price change, only the line: what the mod adds to the trait (DanTraits_Sunburn.lua)
    ["base:outdoorsman"]  = { delta = 0,  why = "UI_DanTraits_PriceWhyOutdoorsman" },
}
-- lower-case trait id -> skill name -> levels at spawn
local LEVELS = {
    ["base:cook"]       = { SmallBlade = 1 },
    ["base:blacksmith"] = { SmallBlunt = 1 },
}
-- the CharacterTrait constant for each, for the description line
local CONSTS = {
    ["base:hemophobic"] = "HEMOPHOBIC", ["base:irongut"] = "IRON_GUT", ["base:resilient"] = "RESILIENT",
    ["base:cook"] = "COOK", ["base:blacksmith"] = "BLACKSMITH", ["base:nightvision"] = "NIGHT_VISION",
    ["base:outdoorsman"] = "OUTDOORSMAN",
}

-- the flat extra a trait costs (negative: gives); `kind` is the trait's type,
-- as the creation screen holds it, or its lower-case id
function DanTraits_PriceDelta(kind)
    if kind == nil then return 0 end
    local row = PRICES[string.lower(tostring(kind))]
    return row and row.delta or 0
end

-- the table, for the docs and the tests
function DanTraits_PriceRows() return PRICES end
function DanTraits_LevelRows() return LEVELS end

-- everything a trait costs on top of its own cost at creation: the age
-- surcharge for the band (0 without a band) and the flat delta
function DanTraits_TraitExtra(band, kind)
    local age = 0
    if band and DanTraits_AgeSurcharge then age = DanTraits_AgeSurcharge(band, kind) end
    return age + DanTraits_PriceDelta(kind), age
end

-- the levels the vanilla traits a character has give at spawn: { perk = levels }.
-- `has(kind)` says whether the character has the lower-case trait id.
function DanTraits_VanillaLevels(has)
    local out = {}
    for kind, skills in pairs(LEVELS) do
        if has(kind) then
            for name, n in pairs(skills) do
                local perk = Perks and Perks[name]
                if perk then out[perk] = (out[perk] or 0) + n end
            end
        end
    end
    return out
end

-- at spawn: the levels, once per character
local function onPricesCreate(player)
    if not player then return end
    local hours = 0
    pcall(function() hours = player:getHoursSurvived() or 0 end)
    if hours > 0 then return end
    local d = traitData(player)
    if d.vanLevelsApplied then return end
    if not DanTraits_AddLevels then return end
    d.vanLevelsApplied = true
    local levels = DanTraits_VanillaLevels(function(kind) return hasVanillaTrait(player, kind) end)
    for perk, count in pairs(levels) do DanTraits_AddLevels(player, perk, count) end
end
DanTraits_OnPlayerReady("VanillaPrices", onPricesCreate, 55)

-- the description line, once per definition (idempotent: the line is looked for first)
local function describe()
    if not CharacterTraitDefinition or not CharacterTrait then return 0 end
    local done = 0
    for kind, row in pairs(PRICES) do
        pcall(function()
            local trait = CharacterTrait[CONSTS[kind]]
            local def = trait and CharacterTraitDefinition.getCharacterTraitDefinition(trait)
            if not def then return end
            local line
            if row.delta == 0 then line = getText(row.why)
            else line = getText(row.why, row.delta > 0 and ("+" .. row.delta) or tostring(row.delta)) end
            local desc = tostring(def:getDescription() or "")
            if string.find(desc, line, 1, true) then return end
            def:setDescription(desc .. "<br>" .. line)
            done = done + 1
        end)
    end
    return done
end
DanTraits_VanillaPricesDescribe = describe

Events.OnGameBoot.Add(describe)
Events.OnMainMenuEnter.Add(describe)
Events.OnGameStart.Add(describe)
