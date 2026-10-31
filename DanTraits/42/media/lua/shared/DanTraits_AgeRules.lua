-- Project Zomboid Vitality Project: the age rules, one table.
--
-- One row per trait that age treats specially: the bands that may take it
-- (`only`; a trait with no `only` is for every age) and what it costs more or
-- fewer in a band (`price`, the game's sign: positive takes points, so a +1 on
-- a trait that gives points means it gives one fewer). Keys are a mod trait's
-- registry key ("arthritis") or a vanilla trait's lower-case id
-- ("base:strong"; `const` names its CharacterTrait constant, for the
-- description line). The creation screen hides a trait the chosen band cannot
-- take and takes it back off when the age changes (DanTraits_Client.lua,
-- DanTraits_TIYL.lua); the surcharge is drawn beside the cost and taken off
-- Points to Spend (DanTraits_AgeSurcharge in DanTraits_Age.lua reads here).
-- Nothing checks the band again after creation: a character who has a trait
-- has it.
--
-- Until Age 2.0 (2026-10-31) this was three things: the script's exclusions
-- (In Their 20s against Arthritis), the age-only table (DanTraits_AgeOnly, 15
-- traits, in DanTraits_AgeTraits.lua) and the price table (AGE_PRICE in
-- DanTraits_Age.lua). DanTraits_AgeOnly is still built from here for the
-- files and tests that read it. The 2.0 pass added the 20s lock-outs the
-- user ticked: Hard of Hearing (age-related hearing loss), Brittle (bone
-- density is a later-life loss) and Type 2 Diabetes (which had a +1 price
-- row instead); Heart Condition stays available at full price in every band
-- (the user's call), and the 50s are locked out of nothing (Athletic at 55
-- is allowed, just dearer).
--
-- The band line is written into each gated trait's description at boot
-- ("Age: 40s, 50s"), the way DanTraits_VanillaPrices.lua writes its reasons.
-- docs/age.md has the table in prose.
require "DanTraits"

local NOT20 = { [30] = true, [40] = true, [50] = true }
local OLDER = { [40] = true, [50] = true }

DanTraits_AgeRules = {
    -- the body costs more to keep with age
    ["base:strong"]         = { price = { [40] = 2, [50] = 4 }, const = "STRONG" },
    ["base:athletic"]       = { price = { [40] = 2, [50] = 4 }, const = "ATHLETIC" },
    ["base:stout"]          = { price = { [40] = 1, [50] = 2 }, const = "STOUT" },
    ["base:fit"]            = { price = { [20] = -1, [40] = 1, [50] = 2 }, const = "FIT" },
    -- learning is cheap young and dear old
    ["base:fastlearner"]    = { price = { [20] = -1, [50] = 1 }, const = "FAST_LEARNER" },
    ["base:slowlearner"]    = { price = { [20] = 1, [50] = 1 }, const = "SLOW_LEARNER" },     -- gives a point fewer, young or old
    -- a hearty appetite is natural young
    ["base:heartyappetite"] = { price = { [20] = 1, [50] = -1 }, const = "HEARTY_APPETITE" },  -- gives a point fewer young, one more old
    -- age-related hearing loss
    ["base:hardofhearing"]  = { only = NOT20, const = "HARD_OF_HEARING" },
    -- the cheap habits (1 point) are harder kept old: 2 in the 40s, 3 in the 50s (2026-10-16)
    gymregular      = { price = { [40] = 1, [50] = 2 } },
    mealprepper     = { price = { [40] = 1, [50] = 2 } },
    earlyriser      = { price = { [40] = 1, [50] = 2 } },
    -- the conditions the 20s band itself softens give fewer points young
    -- (2026-10-10): the band's endurance, healing, blood, strain and resistance
    -- factors already take part of the sting out, so a stack of them must not
    -- come at full price. (Smoker, Dependent and Type 2 had rows here until
    -- Age 2.0: the first two are full price with the head rows, the third is a
    -- lock-out below.)
    ms              = { price = { [20] = 3 } },   -- endurance, stiffness
    heart           = { price = { [20] = 3 } },   -- strain x0.8, endurance
    asthma          = { price = { [20] = 2 } },   -- endurance x1.25 on the halved tier
    hemophilia      = { price = { [20] = 2 } },   -- wounds close x1.5, red cells x1.15
    anemia          = { price = { [20] = 1 } },   -- red cells x1.15, endurance
    -- the conditions of later life: not in the 20s
    arthritis       = { only = NOT20 },
    brittle         = { only = NOT20 },           -- the x1.25 / x1.5 fracture rows stay in the band table
    diabetes2       = { only = NOT20 },
    gout            = { only = NOT20 },           -- the Age 2.0 conditions of later life
    thyroid         = { only = NOT20 },
    -- the traits of one age (DanTraits_AgeTraits.lua)
    quickstudy      = { only = { [20] = true } },
    bottomlesspit   = { only = { [20] = true } },
    natural         = { only = { [20] = true } },   -- Age 2.0: Green's slot
    hotheaded       = { only = { [20] = true } },
    restless        = { only = { [20] = true } },
    readingglasses  = { only = OLDER },
    badback         = { only = OLDER },
    badknees        = { only = OLDER },
    oldhand         = { only = OLDER },
    delicatestomach = { only = OLDER },
    paceyourself    = { only = { [40] = true } },
    settled         = { only = { [40] = true } },
    oldinjury       = { only = { [50] = true } },
    setinways       = { only = { [50] = true } },
    seenitall       = { only = { [50] = true } },
    castiron        = { only = { [50] = true } },
    oldbones        = { only = { [50] = true } },
}

-- the row for a trait: its type as the creation screen holds it (a
-- CharacterTrait, whose tostring is "dantraits:arthritis" or "base:strong"),
-- a registry key, or a lower-case id. nil for a trait age has nothing to say about.
function DanTraits_AgeRuleFor(kind)
    if kind == nil then return nil end
    local rules = DanTraits_AgeRules
    local id = string.lower(tostring(kind))
    local row = rules[id]
    if row then return row end
    local short = string.match(id, "^dantraits:(.+)$")
    if short and rules[short] then return rules[short] end
    if DanTraitsRegistry then
        for key, r in pairs(rules) do
            if DanTraitsRegistry[key] == kind then return r end
        end
    end
    return nil
end

-- the bands that may take the trait ({ [40] = true, ... }), or nil for every age
function DanTraits_AgeRuleBands(kind)
    local row = DanTraits_AgeRuleFor(kind)
    return row and row.only or nil
end

-- the mod traits of one age, by registry key (what DanTraits_AgeTraits.lua
-- and the tests read): key -> the bands
DanTraits_AgeOnly = {}
for key, row in pairs(DanTraits_AgeRules) do
    if row.only and not string.find(key, ":", 1, true) then DanTraits_AgeOnly[key] = row.only end
end

-- the price table as the docs and the dashboard read it: lower-case full id -> band -> extra
function DanTraits_AgePrices()
    local out = {}
    for key, row in pairs(DanTraits_AgeRules) do
        if row.price then
            local id = string.find(key, ":", 1, true) and key or ("dantraits:" .. key)
            out[id] = row.price
        end
    end
    return out
end

-- "20s" / "40s, 50s": the bands a row allows, in order
local function bandsText(only)
    local parts = {}
    for _, band in ipairs({ 20, 30, 40, 50 }) do
        if only[band] then parts[#parts + 1] = band .. "s" end
    end
    return table.concat(parts, ", ")
end
DanTraits_AgeBandsText = bandsText

-- the band line on each gated trait's description, once per definition
local function describe()
    if not CharacterTraitDefinition then return 0 end
    local done = 0
    for key, row in pairs(DanTraits_AgeRules) do
        if row.only then
            pcall(function()
                local trait
                if row.const then trait = CharacterTrait and CharacterTrait[row.const]
                else trait = DanTraitsRegistry and DanTraitsRegistry[key] end
                local def = trait and CharacterTraitDefinition.getCharacterTraitDefinition(trait)
                if not def then return end
                local line = getText("UI_DanTraits_AgeOnlyLine", bandsText(row.only))
                local desc = tostring(def:getDescription() or "")
                if string.find(desc, line, 1, true) then return end
                def:setDescription(desc .. "<br>" .. line)
                done = done + 1
            end)
        end
    end
    return done
end
DanTraits_AgeRulesDescribe = describe

Events.OnGameBoot.Add(describe)
Events.OnMainMenuEnter.Add(describe)
Events.OnGameStart.Add(describe)
