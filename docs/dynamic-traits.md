# Dynamic Traits and Expanded Moodles: how the two mods meet

Dynamic Traits and Expanded Moodles (DTEM, Workshop 3791764362, mod id `DynamicTraits`,
by PepperCat) re-prices the vanilla traits, adds its own, and hands traits out and takes
them away in play. chuchu reported on Steam that it clashes with this mod. This page is
what was found on 2026-10-09 by reading DTEM's Lua and the game's jar (game 42.21), and
what `DanTraits_DTEM.lua` does about it. The adapter was written that day in a side
worktree and brought into master on 2026-10-29 (Smoker's cost had moved to -5 in the
meantime). Nothing on this page has been seen in the game yet; the in-game checks are at
the end.

## What was established

**B42 has no TraitFactory.** The class is not in `projectzomboid.jar` and vanilla Lua never
names it. DTEM ships two version folders, `42.0` and `42.20`. The game loads the highest
folder that is not above its own version, so a 42.21 game loads `42.20`. The `42.0` folder
calls the missing TraitFactory on the first line of its trait pass and would stop there; it
is dead code on a current game. (The first read of DTEM, on 2026-10-09 before this file,
was of `42.0`.)

**DTEM 42.20 brings its own TraitFactory**, written in Lua (`shared/NPCs/DTB42Compat.lua`)
on top of B42's `CharacterTraitDefinition`. Its `TraitFactory.addTrait("Smoker", ...)`
lowercases the name and looks for the vanilla trait `base:smoker` first; only a name no
vanilla trait has becomes a new `dynamictraits:<name>` trait. So:

| DTEM name | The trait it is | What DTEM does to it |
|---|---|---|
| Cook | `base:cook` (ours: 4, +1 Short Blade) | 3, Cooking +2 only, vanilla's recipes |
| IronGut | `base:irongut` (ours: 4) | 5 |
| Resilient | `base:resilient` (ours: 10, the Knox roll) | 0, a hidden profession trait; given free in play by body condition |
| Hemophobic | `base:hemophobic` (ours: -6) | -8 |
| Smoker | `base:smoker` (ours: -5 since 1.4.0) | -4 |
| NightVision | `base:nightvision` (ours: 1) | 4 |
| Asthmatic | `base:asthmatic` (vanilla, -5; our Asthma excludes it) | 0, a hidden profession trait; given and taken in play |
| Alcoholic | `dynamictraits:alcoholic` (new) | -8; given and taken in play by a drink counter |
| AddictedToCaffeine | `dynamictraits:addictedtocaffeine` (new) | -4; given and taken in play by a caffeine counter |
| BrittleKnees | `dynamictraits:brittleknees` (new) | 0, a hidden profession trait; given and taken in play |

**Our checks see all of them.** A character's `getKnownTraits` lists traits by their
resource location (`CharacterTrait.toString` is `namespace:path`), so
`DanTraits_HasVanillaTrait(player, "base:smoker")` is true for a DTEM-given Smoker and
`"dynamictraits:alcoholic"` names DTEM's Alcoholic. There is no `player:HasTrait(String)`
in B42; DTEM 42.20 routes its own checks through `DTHasTrait`, which calls
`player:hasTrait(CharacterTrait)`, the same call we make.

**DTEM's re-declaration replaces our script definitions.** The shim calls
`CharacterTraitDefinition.addCharacterTraitDefinition(trait, name, cost, description,
isProfessionTrait)`, which in the jar is `new CharacterTraitDefinition(...)` followed by
`Map.put`: the definition our `media/scripts/DanTraits.txt` block made is thrown away and
a fresh one, with no XP boosts, recipes or exclusions until DTEM adds its own, takes its
place. That happens at `OnGameBoot`, after the scripts have loaded. The constructor runs the
name and description through `Translator.getText`, so a translation key is the right thing
to pass back. There is no `setCost`; re-applying an override means re-adding the definition
the same way and putting our boosts, recipes and exclusions back.
`CharacterTraitDefinition.setMutualExclusive(a, b)` is static, adds both directions and
calls `updateMutualExclusiveTraits`, which walks every definition, so the exclusions other
traits declare against these six (Straight Edge against Smoker) come back too.

**In play** DTEM adds and removes traits with `DTAddTrait` / `DTRemoveTrait`
(`getCharacterTraits():add` / `:remove` plus `modifyTraitXPBoost`), driven by counters in
the player's mod data: `DTEMalcoholicTrait` below -44640 adds its Alcoholic and above 44640
takes it off; `DTEMaddictedToCaffeineTrait` at -20160 / 20160 likewise. The add repeats
every minute while the counter is past the mark and the trait is missing (with DTEM's own
red halo each time), so taking its trait off has to start the counter over too.

## What DanTraits_DTEM.lua does

Nothing unless `getActivatedMods():contains("DynamicTraits")`. No dependency either way.
Runs at boot, at the main menu and at game start, each time idempotent, and logs one line:

    [DanTraits] Dynamic Traits found: overrides re-applied (base:cook, ...)/skipped (already ours), duplicates hidden, addiction swap on

1. **Overrides re-applied.** For each of the six, if the definition's cost is not ours or
   it has become a profession trait, the definition is re-added with our cost and UI keys,
   then our XP boosts, granted recipes and exclusions. The table in the Lua file mirrors
   the script; `tests/check_dtem_overrides.py` fails when they drift apart. A definition
   already at our cost is left as it is (the main-menu and game-start passes after boot).
2. **Duplicates hidden** at creation: `dynamictraits:alcoholic`,
   `dynamictraits:addictedtocaffeine`, `base:asthmatic` and `dynamictraits:brittleknees`
   go into `DanTraits_HIDDEN_AT_CREATION` (core), which the creation screen filter in
   `DanTraits_Client.lua` reads. Our Alcoholic, Caffeine Dependent, Asthma and Bad Knees
   stand in.
3. **Addiction swap**, every game minute: a character carrying DTEM's Alcoholic has it taken
   off and gets our Alcoholic (`dependent`) through `DanTraits_SetTrait`, DTEM's counter is
   set to 0 so it does not hand the trait straight back, and a halo says "Alcoholic: the
   Vitality Project's version takes over" (once; a character who already had ours gets no
   halo). Addicted to Caffeine becomes our Caffeine Dependent the same way. When DTEM takes
   its own trait away, ours stays: ours are never removed by this file.

Not handled: DTEM also gives `base:resilient` free in play by body condition, which gives
the Knox roll for nothing. Its pass-out from exhaustion, anger from drunkenness, fractures
under load and smoker cough all stack with ours (see the Workshop FAQ: pick one mod for
addictions).

## In-game checks still owed

With both mods on (DTEM loaded, in either order):

1. The console at boot shows `DT B42 compat` lines (the `42.20` folder loaded) and our one
   `Dynamic Traits found` line naming the re-applied overrides.
2. On the character creation screen: Resilient costs 10 and sits in the positive list, Keen
   Cook costs 4 and its tooltip lists Short Blade, Iron Gut 4, Fear of Blood -6, Smoker -5,
   Cat's Eyes 1. One Alcoholic (ours, -4), one Caffeine Dependent, one Asthma, one Bad Knees (with an
   age picked).
3. In play, give a character DTEM's Alcoholic (console: `getPlayer():getModData().DTEMalcoholicTrait = -45000`,
   then wait a minute for DTEM to add it). Within the next minute it should be gone, our
   Alcoholic on, the halo shown, and `getPlayer():getModData().DTEMalcoholicTrait` back at 0.
4. Return to the main menu and start again: the costs hold (the main-menu pass).
