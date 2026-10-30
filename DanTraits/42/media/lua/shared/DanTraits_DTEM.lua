-- Project Zomboid Vitality Project: Dynamic Traits and Expanded Moodles (DTEM,
-- Workshop 3791764362, mod id DynamicTraits) compatibility.
require "DanTraits"

-- Does nothing unless DTEM is in the activated mod list. No dependency either
-- way. Three jobs, all installed at boot and again at the main menu and at
-- game start (each is idempotent):
--
--   1. Re-apply our six vanilla trait overrides after DTEM has re-priced them.
--   2. Hide DTEM's four duplicate traits on the creation screen (our Alcoholic,
--      Caffeine Dependent, Asthma and Bad Knees stand in).
--   3. When DTEM hands a character its Alcoholic or Addicted to Caffeine in
--      play, swap it for ours within a minute and say so over the head. Ours
--      are never taken off when DTEM takes its own away.
--
-- What was established before this was written (2026-10-09, game 42.21, DTEM
-- as installed that day; read from projectzomboid.jar with a class-file
-- disassembler and from DTEM's Lua; nothing here has run in the game yet):
--
--   * B42 has no TraitFactory: the class is not in the jar and vanilla Lua
--     never names it. DTEM ships two version folders, 42.0 and 42.20; the
--     game loads the highest folder not above its own version, so a 42.21
--     game loads 42.20. The 42.0 folder (the one read on 2026-10-09 before
--     this file) calls the missing TraitFactory and would error on its first
--     line; it is dead code on a current game.
--   * 42.20 brings its own Lua TraitFactory (shared/NPCs/DTB42Compat.lua).
--     TraitFactory.addTrait("Smoker", ...) lowercases the name, looks up the
--     vanilla trait CharacterTrait.get(ResourceLocation.of("base:smoker")) and
--     only registers a new "dynamictraits:<name>" trait when no vanilla one
--     exists. So DTEM's "Smoker", "Cook", "IronGut", "Resilient",
--     "Hemophobic", "NightVision" and "Asthmatic" ARE base:smoker, base:cook,
--     base:irongut, base:resilient, base:hemophobic, base:nightvision and
--     base:asthmatic; its "Alcoholic", "AddictedToCaffeine" and
--     "BrittleKnees" are dynamictraits:alcoholic, dynamictraits:addictedtocaffeine
--     and dynamictraits:brittleknees. A character's getKnownTraits lists them
--     under those ids (CharacterTrait.toString is the ResourceLocation's
--     "namespace:path"), so DanTraits_HasVanillaTrait sees every one of them.
--     There is no player:HasTrait(String) in B42; DTEM 42.20 routes its 400-odd
--     HasTrait calls through its own DTHasTrait, which calls
--     player:hasTrait(CharacterTrait), the same call we make.
--   * The shim then calls CharacterTraitDefinition.addCharacterTraitDefinition
--     (trait, name, cost, description, isProfessionTrait[, disabledInMP]). In
--     the jar that is `new CharacterTraitDefinition(...)` followed by Map.put:
--     it REPLACES the definition our media/scripts/DanTraits.txt block made,
--     with a fresh object whose XP boosts, granted recipes and exclusions are
--     empty until DTEM adds its own. So DTEM's OnGameBoot pass leaves Keen
--     Cook at 3 without our Short Blade, Iron Gut at 5, Resilient at 0 as a
--     hidden profession trait, Fear of Blood at -8, Smoker at -4 (ours was -4
--     then too; -5 since the 1.4.0 balance pass, so it is re-applied now)
--     and Cat's Eyes at 4. The constructor runs the name and the description
--     through Translator.getText, so a translation key is the right thing to
--     pass. There is no setCost: re-applying means re-adding the definition
--     the same way and putting our boosts, recipes and exclusions back.
--     setMutualExclusive(a, b) is static, adds both directions and calls
--     updateMutualExclusiveTraits, which walks every definition, so the
--     exclusions other traits declare against these six (Straight Edge
--     against Smoker, say) come back too.
--   * In play DTEM adds and removes traits with DTAddTrait / DTRemoveTrait
--     (getCharacterTraits():add / :remove plus modifyTraitXPBoost), on a
--     counter it keeps in the player's mod data: DTEMalcoholicTrait below
--     -44640 adds its Alcoholic, above 44640 takes it off;
--     DTEMaddictedToCaffeineTrait at -20160 / 20160 likewise. The add repeats
--     every minute while the counter is past the mark and the trait is
--     missing, so a swap has to zero the counter too or DTEM hands the trait
--     straight back (and shows its own halo every minute).
--
-- Written 2026-10-09 in a side worktree and brought into master on
-- 2026-10-29 (the Smoker cost updated); still never run in the game.
--
-- Still to verify in the game: that the 42.20 folder is the one loaded (the
-- console shows "DT B42 compat" lines), the creation-screen costs with both
-- mods on, and one swap. DTEM also hands out base:resilient free in play by
-- body condition; that still gives the Knox roll for nothing and is not
-- handled here.
local MOD_ID = "DynamicTraits"
local NS = "dynamictraits"

-- The six overrides, mirrored from media/scripts/DanTraits.txt: cost, UI
-- keys, exclusions, XP boosts and granted recipes. tests/test_dtem.lua reads
-- the script and fails when the two drift apart. `const` is the CharacterTrait
-- constant's name; the id is the fallback lookup.
local OVERRIDES = {
    { id = "base:cook", const = "COOK", cost = 4, name = "UI_trait_Cook", desc = "UI_trait_CookDesc",
      excludes = { "base:cook2" },
      xp = { { "Cooking", 2 }, { "Butchering", 1 }, { "SmallBlade", 1 } },
      recipes = { "MakeCakeBatter", "MakePieDough", "MakeBreadDough", "MakeBaguetteDough", "MakeBiscuits",
                  "MakeChocolateChipCookieDough", "MakeOatmealCookieDough", "MakeShortbreadCookieDough",
                  "MakeSugarCookieDough", "MakePizza", "MakeFriedOnionRings", "MakeFriedShrimp", "MakeCabbageRolls",
                  "MakeJar", "MakeGuacamole" } },
    { id = "base:irongut", const = "IRON_GUT", cost = 4, name = "UI_trait_IronGut", desc = "UI_trait_IronGutDesc",
      excludes = { "base:weakstomach" } },
    { id = "base:resilient", const = "RESILIENT", cost = 10, name = "UI_trait_resilient", desc = "UI_trait_resilientdesc",
      excludes = { "base:pronetoillness" } },
    { id = "base:hemophobic", const = "HEMOPHOBIC", cost = -6, name = "UI_trait_Hemophobic", desc = "UI_trait_HemophobicDesc",
      excludes = { "base:desensitized" } },
    { id = "base:smoker", const = "SMOKER", cost = -5, name = "UI_trait_Smoker", desc = "UI_trait_SmokerDesc",
      excludes = { "base:athletic" } },
    { id = "base:nightvision", const = "NIGHT_VISION", cost = 1, name = "UI_trait_NightVision", desc = "UI_trait_NightVisionDesc" },
}
DanTraits_DTEM_OVERRIDES = OVERRIDES   -- read-only view for the tests

-- DTEM's duplicates of our traits, hidden at creation while it is active
local HIDDEN = { NS .. ":alcoholic", NS .. ":addictedtocaffeine", "base:asthmatic", NS .. ":brittleknees" }

-- the two DTEM adds in play, and ours that take their place
local SWAPS = {
    { theirs = NS .. ":alcoholic", ours = "dependent", counter = "DTEMalcoholicTrait", text = "UI_DanTraits_DTEMAlcoholic" },
    { theirs = NS .. ":addictedtocaffeine", ours = "caffeine", counter = "DTEMaddictedToCaffeineTrait", text = "UI_DanTraits_DTEMCaffeine" },
}

local active = nil      -- nil until the mod list has been read
local hidden = false

local function dtemActive()
    local found = false
    pcall(function()
        if type(getActivatedMods) == "function" then found = getActivatedMods():contains(MOD_ID) == true end
    end)
    return found
end

-- a CharacterTrait by id ("base:smoker", "dynamictraits:alcoholic"); nil when unknown
local function traitById(id, const)
    local trait = nil
    if const and CharacterTrait then trait = CharacterTrait[const] end
    if trait == nil then
        pcall(function() trait = CharacterTrait.get(ResourceLocation.of(id)) end)
    end
    return trait
end

-- true when the definition already carries our cost and is offered as a plain trait
local function isOurs(def, o)
    local same = false
    pcall(function() same = def:getCost() == o.cost and not def:isFree() end)
    return same
end

-- re-add one override: the definition, then its boosts, recipes and exclusions
local function reapplyOne(o)
    local trait = traitById(o.id, o.const)
    if trait == nil then return false end
    local def = nil
    pcall(function() def = CharacterTraitDefinition.getCharacterTraitDefinition(trait) end)
    if def ~= nil and isOurs(def, o) then return nil end     -- already ours: nothing to do
    local ok = pcall(function()
        def = CharacterTraitDefinition.addCharacterTraitDefinition(trait, o.name, o.cost, o.desc, false)
    end)
    if not ok or def == nil then return false end
    for _, boost in ipairs(o.xp or {}) do
        pcall(function() def:addXPBoost(Perks[boost[1]], boost[2]) end)
    end
    for _, recipe in ipairs(o.recipes or {}) do
        pcall(function() def:addGrantedRecipe(recipe) end)
    end
    for _, other in ipairs(o.excludes or {}) do
        local otherTrait = traitById(other)
        if otherTrait ~= nil then pcall(function() CharacterTraitDefinition.setMutualExclusive(trait, otherTrait) end) end
    end
    -- and whatever other definitions declare against this one (Straight Edge against Smoker)
    pcall(function() def:updateMutualExclusiveTraits() end)
    return true
end

-- every override; returns the names re-applied and the names that failed
local function reapply()
    local done, failed = {}, {}
    for _, o in ipairs(OVERRIDES) do
        local result = reapplyOne(o)
        if result == true then done[#done + 1] = o.id elseif result == false then failed[#failed + 1] = o.id end
    end
    return done, failed
end
DanTraits_DTEMReapply = reapply

local function hideDuplicates()
    if hidden or not DanTraits_HideAtCreation then return end
    for _, id in ipairs(HIDDEN) do DanTraits_HideAtCreation(id) end
    hidden = true
end

-- the one line at boot, at the main menu and at game start
local function install()
    active = dtemActive()
    if not active then return end
    local done, failed = reapply()
    hideDuplicates()
    local what = #done > 0 and ("re-applied (" .. table.concat(done, ", ") .. ")") or "skipped (already ours)"
    if #failed > 0 then what = what .. ", failed (" .. table.concat(failed, ", ") .. ")" end
    print("[DanTraits] Dynamic Traits found: overrides " .. what .. ", duplicates hidden, addiction swap on")
end
DanTraits_DTEMInstall = install

-- take DTEM's trait off a character; true when it is gone afterwards
local function removeTheirs(player, id)
    local trait = traitById(id)
    if trait == nil then return false end
    local gone = false
    pcall(function()
        local traits = player:getCharacterTraits()
        if traits:get(trait) then
            traits:remove(trait)
            pcall(function() player:modifyTraitXPBoost(trait, true) end)
        end
        gone = traits:get(trait) ~= true
    end)
    DanTraits_TraitsChanged(player)
    return gone
end

-- every minute: a DTEM addiction on the character becomes ours
local function swap(player, d)
    if not active then return end
    for _, s in ipairs(SWAPS) do
        if DanTraits_HasVanillaTrait(player, s.theirs) then
            local had = DanTraits_HasTrait(player, s.ours)
            removeTheirs(player, s.theirs)
            if not had then DanTraits_SetTrait(player, s.ours, true) end
            -- DTEM re-adds its trait every minute while its counter is past the mark: start it over
            pcall(function()
                local md = player:getModData()
                if type(md[s.counter]) == "number" then md[s.counter] = 0 end
            end)
            if not had then DanTraits_Notify(player, s.text) end
            print("[DanTraits] Dynamic Traits gave " .. s.theirs .. ": swapped for " .. s.ours)
        end
    end
end
DanTraits_Every("minute", "DTEM", swap, 100)

Events.OnGameBoot.Add(install)
Events.OnMainMenuEnter.Add(install)
Events.OnGameStart.Add(install)
