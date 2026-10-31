-- Project Zomboid Vitality Project: Dynamic Traits and Expanded Moodles (DTEM,
-- Workshop 3791764362, mod id DynamicTraits) compatibility.
require "DanTraits"

-- Does nothing unless DTEM is in the activated mod list. No dependency either
-- way. Two jobs, both installed at boot and again at the main menu and at
-- game start (each is idempotent):
--
--   1. Hide DTEM's four duplicate traits on the creation screen (our Alcoholic,
--      Caffeine Dependent, Asthma and Bad Knees stand in).
--   2. When DTEM hands a character its Alcoholic or Addicted to Caffeine in
--      play, swap it for ours within a minute and say so over the head. Ours
--      are never taken off when DTEM takes its own away.
--
-- Until Age 2.0 (2026-10-31) there was a third: re-applying the six vanilla
-- trait definitions this mod's script overrode (Keen Cook, Iron Gut,
-- Resilient, Fear of Blood, Smoker, Cat's Eyes) after DTEM's boot pass had
-- replaced them. The script no longer redefines any vanilla trait: the price
-- changes are flat deltas drawn on the creation screen
-- (DanTraits_VanillaPrices.lua), which apply whatever DTEM does to the
-- definitions, and Smoker is the mod's own trait (DanTraits_Smoker.lua).
--
-- What was established before this was written (2026-10-09, game 42.21, DTEM
-- as installed that day; read from projectzomboid.jar with a class-file
-- disassembler and from DTEM's Lua):
--
--   * B42 has no TraitFactory: the class is not in the jar and vanilla Lua
--     never names it. DTEM ships two version folders, 42.0 and 42.20; the
--     game loads the highest folder not above its own version, so a 42.21
--     game loads 42.20. The 42.0 folder calls the missing TraitFactory and
--     would error on its first line; it is dead code on a current game.
--   * 42.20 brings its own Lua TraitFactory (shared/NPCs/DTB42Compat.lua).
--     TraitFactory.addTrait("Smoker", ...) lowercases the name, looks up the
--     vanilla trait CharacterTrait.get(ResourceLocation.of("base:smoker")) and
--     only registers a new "dynamictraits:<name>" trait when no vanilla one
--     exists. So DTEM's "Smoker", "Cook", "IronGut", "Resilient",
--     "Hemophobic", "NightVision" and "Asthmatic" ARE the base: traits; its
--     "Alcoholic", "AddictedToCaffeine" and "BrittleKnees" are
--     dynamictraits:alcoholic, dynamictraits:addictedtocaffeine and
--     dynamictraits:brittleknees. A character's getKnownTraits lists them
--     under those ids (CharacterTrait.toString is the ResourceLocation's
--     "namespace:path"), so DanTraits_HasVanillaTrait sees every one of them.
--     There is no player:HasTrait(String) in B42; DTEM 42.20 routes its 400-odd
--     HasTrait calls through its own DTHasTrait, which calls
--     player:hasTrait(CharacterTrait), the same call we make.
--   * The shim's CharacterTraitDefinition.addCharacterTraitDefinition REPLACES
--     a trait's definition with a fresh one (so a script override of a vanilla
--     trait was lost at DTEM's boot pass: the reason the mod stopped overriding).
--   * In play DTEM adds and removes traits with DTAddTrait / DTRemoveTrait
--     (getCharacterTraits():add / :remove plus modifyTraitXPBoost), on a
--     counter it keeps in the player's mod data: DTEMalcoholicTrait below
--     -44640 adds its Alcoholic, above 44640 takes it off;
--     DTEMaddictedToCaffeineTrait at -20160 / 20160 likewise. The add repeats
--     every minute while the counter is past the mark and the trait is
--     missing, so a swap has to zero the counter too or DTEM hands the trait
--     straight back (and shows its own halo every minute).
--   * DTEM hands out base:resilient free in play by body condition. The Knox
--     roll keys off a Resilient chosen at creation (DanTraits_Knox.lua), so
--     that gives nothing extra.
--
-- Written 2026-10-09 in a side worktree and brought into master on
-- 2026-10-29; still never run in the game. Still to verify in the game: that
-- the 42.20 folder is the one loaded (the console shows "DT B42 compat"
-- lines), the creation-screen costs with both mods on, and one swap.
local MOD_ID = "DynamicTraits"
local NS = "dynamictraits"

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

-- a CharacterTrait by id ("dynamictraits:alcoholic"); nil when unknown
local function traitById(id)
    local trait = nil
    pcall(function() trait = CharacterTrait.get(ResourceLocation.of(id)) end)
    return trait
end

local function hideDuplicates()
    if hidden or not DanTraits_HideAtCreation then return end
    for _, id in ipairs(HIDDEN) do DanTraits_HideAtCreation(id) end
    hidden = true
end

-- the one line at boot, at the main menu and at game start
local function install()
    active = dtemActive()
    if not active then return end
    hideDuplicates()
    print("[DanTraits] Dynamic Traits found: duplicates hidden, addiction swap on")
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
