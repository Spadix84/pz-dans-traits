# Community feedback, 2026-10-08

Sources: the Steam Workshop comments (16, no discussion threads) and the
r/projectzomboid launch thread (91 comments). Scraped 2026-10-08, when the mod
had about 300 current installs.

Tiers sort by size. **Tier 1** is about an evening each, and two of its items
were promised publicly for Saturday's update. **Tier 2** takes a few sessions,
or is a compatibility test. **Tier 3** needs a design document first. Anything
not finished by Saturday (2026-10-10) moves to `plans/backlog.md`.

**Status:** *open* = not started. *partly* = some of it exists. *parked* = you
set it aside earlier. Handles link to each person's profile, and the speech
bubble links to the comment itself.

## Tier 1: quick, and the promises

| # | Request | Who | Status | Notes |
|---|---|---|---|---|
| 1 | **Car-crash concussions are far too easy.** At 60 km/h or more, hitting a single zombie, or running over a corpse in a car at 20% condition (the suspension clips), gave a severe concussion, a blackout and a crash into a fence. | [kiiri](https://steamcommunity.com/id/4uck_1t) (Steam) | built 2026-10-09 (by speed lost), unplayed, **promised** | You replied that it's a bug. The cause: `DanTraits_Concussion.lua` judges a CARCRASHDAMAGE event by the car's *top speed* over the last second (`CC_CRASH_KMH`, `recentTopSpeed`). So any event the game counts as a crash at speed concusses you, even when the car barely slows down. Fix: judge by how much speed the car *lost* (top speed minus speed straight after), or require damage to the car as well. Hitting a zombie or a suspension clip loses almost no speed. |
| 2 | **Clashes with Dynamic Traits and Expanded Moodles.** Also overlaps with Evolving Traits World and More Traits, which has its own caffeine dependence. | [chuchu](https://steamcommunity.com/id/tsundebear) (Steam) | open, **promised** | On Steam you promised the "evolving traits situation" for Saturday's deploy. chuchu's correction says the real clash is Dynamic Traits and Expanded Moodles (DTEM). Find out what collides: duplicate traits, moodles, or both. Then either patch around it or list it as incompatible on the Workshop page. |
| 3 | **Pictures of the conditions and items on the Workshop page.** | [TheLurkiest](https://steamcommunity.com/profiles/76561198002640790) (Steam) | open | Use the trait icons, moodle icons and item icons already made, and screenshots. No code. |
| 4 | **Detailed documentation of the mechanics.** | [joesii](https://www.reddit.com/user/joesii) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd5zibf/)) | partly | `docs/field-guide.html` exists and has been fact-checked. Link it from the Workshop page (the artifact, or GitHub Pages). |
| 5 | **Is it safe to add mid-save?** | [showmethecoin](https://www.reddit.com/user/showmethecoin) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd5pn2d/)) | open | Add an FAQ line to the Workshop page: what an existing character gets (an Age trait, no starting kits). The same FAQ can explain the point sign, which [dubyakay](https://www.reddit.com/user/dubyakay) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pdf56a5/)) asked about: the game shows it correctly, but the Reddit post used the opposite sign. |
| 6 | **A sleep mask that cancels the bright-room penalty.** | [showmethecoin](https://www.reddit.com/user/showmethecoin) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd5pn2d/)) | open | Already in `plans/backlog.md`, sized S. Sleep scores a lit room as dark while the mask is worn. |

## Tier 2: a few sessions, and compatibility checks

| # | Request | Who | Status | Notes |
|---|---|---|---|---|
| 7 | **Sandbox multipliers for blood-loss rate and concussion severity.** A bullet in the neck plus one more hit almost always kills (with A-Life NPCs). | [kiiri](https://steamcommunity.com/id/4uck_1t) (Steam) | open | Two number options (default 100%) applied in Blood's part rate and Concussion's score. Small code, but every bleed path needs testing. |
| 8 | **A tourniquet** to stop limb bleeding (kiiri asked for "a hemostatic agent or a tourniquet"). | [kiiri](https://steamcommunity.com/id/4uck_1t) (Steam) | partly | The clotting powder, built 2026-10-07, covers the hemostatic agent. A tourniquet for arms and legs would stop a limb bleed outright, at the cost of pain and limb damage if left on too long. |
| 9 | **An ice pack eases a migraine.** They also suggested being well fed as a comfort. | [Dry-Pangolin6579](https://www.reddit.com/user/Dry-Pangolin6579) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd942lb/)) | open | `Base.Coldpack` is a vanilla item, and Dan's Vanilla Fixes already gives it a chill level. An "apply to head" action would shorten the attack or ease its pain, more when the pack is frozen. |
| 10 | **A long-term migraine preventive**, like the seizure meds. | [ShotgunFiend](https://www.reddit.com/user/ShotgunFiend) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pdflbux/)) | open | Their example, Emgality, was approved in 2018, too late for 1993. Period-correct preventives are propranolol or amitriptyline. A daily build-up drug through the meds registry would cut attack frequency and severity. |
| 11 | **Compatibility with Wounds Overhaul.** | [Soulhaste](https://steamcommunity.com/id/Soulhaste) (Steam) | open | You said you would test it. Both mods rewrite wounds, so it is probably incompatible. Test, then list the result on the Workshop page. |
| 12 | **Compatibility with Simple Overhaul Traits and Occupations (SOTO).** | [TheGloriousUllr](https://www.reddit.com/user/TheGloriousUllr) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd3qei9/)) | open | Untested. The risk is trait or profession overrides, especially Age's levels on the creation screen. |
| 13 | **Compatibility with Evolving Traits World (ETW).** | [Pixie_OwO](https://www.reddit.com/user/Pixie_OwO) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd658kx/)), [Supalova](https://www.reddit.com/user/Supalova) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pde4otl/)), [chuchu](https://steamcommunity.com/id/tsundebear) | parked 2026-10-03 | ETW hands out and removes Smoker, which collides with this mod's Smoker. Three people have now asked. |
| 14 | **Running with Mattnetic's Alcoholic Trait.** | [Crafty-Reputation995](https://www.reddit.com/user/Crafty-Reputation995) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd5fdw4/)) | open | This was a question about where the design came from, not a request. Running both mods probably means two withdrawal systems at once. Worth a line on the Workshop page. |

## Tier 3: needs a design document first

| # | Request | Who | Status | Notes |
|---|---|---|---|---|
| 15 | **Multiplayer**, including how A Really Bad Day works there. Amplify uses the mod in MP for Renaissance Faire Geek's Long Blade and Spear. | [KP](https://steamcommunity.com/id/kheiplang), [Amplify](https://steamcommunity.com/id/Amplify_FA) (Steam); [PudgyElderGod](https://www.reddit.com/user/PudgyElderGod) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd3nw00/)) | partly | `plans/multiplayer.md` is drafted and the spike hasn't been run. You told Amplify you'd test on your son's server. |
| 16 | **Allergies, with an epi-pen.** | [TheLurkiest](https://steamcommunity.com/profiles/76561198002640790) (Steam) | open | A new condition: triggers (bee stings while foraging, certain foods, pollen), anaphylaxis, the epi-pen as a rescue item. |
| 17 | **Fructose intolerance.** | [PrestigiousSpell6669](https://www.reddit.com/user/PrestigiousSpell6669) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd5ynff/)) | parked 2026-10-03 | Would follow the Gluten and Lactose pattern (fruit, honey, jam, sweets). |
| 18 | **Moodle art.** | [Bucky_2028](https://www.reddit.com/user/Bucky_2028) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd3t1oa/)) | open | They like the concept, not the pixel art. An art pass if a contributor turns up. |

## Already built: thank-you list for the update notes

Shipped in **1.1.0**:

- [Cultural_Prune8416](https://www.reddit.com/user/Cultural_Prune8416) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd3nm6n/)): Arthritis grip slips became weak swings, not thrown weapons, with a sandbox option. Saturday's update adds flare relief (warm clothes, painkillers, prednisone).
- [Fatt3stAveng3r](https://www.reddit.com/user/Fatt3stAveng3r) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd3r88n/)): sumatriptan, with the tired and clumsy day after. Twice as common in Saturday's update.
- [apexium](https://www.reddit.com/user/apexium) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pdcjcom/)): Starting Medication (a Migraines character starts with the last two sumatriptan), painkillers barely touching a migraine, and personal migraine triggers.
- [ShotgunFiend](https://www.reddit.com/user/ShotgunFiend) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pddjn7t/)): heat as a migraine trigger, and Migraines at -8.
- [Dry-Pangolin6579](https://www.reddit.com/user/Dry-Pangolin6579) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd942lb/)): corpse smell and incoming storms as migraine triggers.
- [caveramag](https://www.reddit.com/user/caveramag) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd3yqyy/)): stitching is a First Aid roll, so rough stitches at low skill.
- [RichieRocket](https://www.reddit.com/user/RichieRocket) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd4c1ha/)): the concussion headache that comes back days later.
- [_Denizen_](https://www.reddit.com/user/_Denizen_) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd5wcdr/)): a sandbox option to hide the Nicotine Craving moodle.
- [Wagwan-piff-ting42](https://www.reddit.com/user/Wagwan-piff-ting42) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd79ltw/)) and [Zombie804Slayer](https://www.reddit.com/user/Zombie804Slayer) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd43962/)): their thread prompted cutting Thriving's Fitness and Strength bonus from x2 to x1.5.

Coming in **Saturday's update**:

- [kiiri](https://steamcommunity.com/id/4uck_1t) (Steam): clotting powder, a way to stop bleeding (asked for a hemostatic agent on 2026-10-06).
- [Amplify](https://steamcommunity.com/id/Amplify_FA) (Steam): Iron Stomach and Iron Gut were the same trait, so Iron Stomach is now part of Iron Gut.
- [SpartanXIII](https://www.reddit.com/user/SpartanXIII) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd497vk/)) and [Cat_Security](https://www.reddit.com/user/Cat_Security) ([💬](https://www.reddit.com/r/projectzomboid/comments/1wujbhm/_/pd9gic4/)), both Type 1: not a request, but worth a shout-out alongside "Knowing your insulin" (dose ranges by First Aid level, and the Living With Type 1 magazine).
