# Vitality Challenges changelog

Challenge scenarios for the game's Challenges menu, from the Vitality Project. Runs on its
own; reaches the Vitality Project's systems when it is loaded. Replaces the old local-only
Dan's Challenges mod (archived in `plans/archive/DanChallenges-2026-10-27.zip`, git-ignored).

## 0.1.0 (in progress)

- **Shared pieces moved into the frame** (2026-10-29, review C7). The paper map's `LootMaps.Init`
  is one `VC.paperMap(id, bounds, stamps)` in Kit, used by Nomad and The Last Broadcast; the
  weapon-by-profession and trait tables are Kit's `VC.weaponsFor(player)` / `VC.forged(level)`
  (The Last Broadcast no longer depends on Nomad loading first); `VC.used`, `VC.hour` and
  `VC.worldHours` replace the copies in each file. The Last Broadcast silences every channel the
  radio script manager lists (`getChannelsList`, as the game's own radio debugger does) instead of
  a hand-kept list of 18 uuids, so a station a game update adds goes quiet too. Its test
  scaffolding (low population, one dead, the stocked studio, the step van) is now
  `VitalityChallenges_Dev.lua`, reached through `VC.dev` hooks that do nothing without the file;
  TEST is still on there for play-testing, off before release.
- **The Last Broadcast: the walk there costs nothing** (2026-10-29, review; `B.settle`). The
  first evening, meant as the time to reach the studio, still took 15% of the listeners and
  said "Nobody heard you tonight"; a player airing the first show on the second evening started
  down 6 listeners. `settle` returns "grace" for it: no loss, no word. The second evening is a
  miss, the third the failure, as before. (The Rosewood start's rule, no deadline at all until
  the first show, is still to build.)
- **No station of ours in every save** (2026-10-29, review; `server/VitalityChallenges_Radio.lua`).
  The 96.4 "Vitality Challenges" channel was registered into every save that loaded the mod,
  challenge or not, and kept in its radio mod data, with nothing airing on it. Only LBMW is looked
  up now; the spare comes back with the challenge that needs it.
- **A vanilla script never talks over a line** (2026-10-29, review; `airText`): a channel script
  that started since the hour's silencing is nulled before each line goes out.
- **Map circles, second fix** (2026-10-29): the circle still did not show. A map item's marks
  that are not the player's are cleared when the game loads its default annotations
  (`WorldMapSymbols.clearDefaultAnnotations` keeps only user-defined symbols), so a game mark
  never survives. `VC.stampMap` now draws the circle as an ordinary mark, once per map item (a
  mod-data flag), saved with the item like a mark you drew yourself.
- **The Last Broadcast's show window laid out again** (2026-10-29): the tick boxes were drawn
  at the whole list's height (`ISTickBox`'s height argument is one box's size) and spilled over
  the labels and buttons. Now, top to bottom: the title; listeners and shows aired on their own
  lines; "Tonight's segments" with the boxes and why one cannot go in; how every show opens and
  ends; a green "Ready" or the reason in red; the buttons. The window widens to its longest line.
- **Map circles fixed** (2026-10-28): neither Nomad's nor The Last Broadcast's paper map showed
  its circle. The stamp asked the map's v1 API for symbols, which it does not have (the error was
  swallowed, the "stamped" flag set anyway). `VC.stampMap` now marks the map the way the game's own
  annotated maps do: through the v3 API, a symbol that is not the player's, drawn each time the
  map opens. Maps already in a save get the circle the next time they are opened.
- **The Last Broadcast's start moved** (2026-10-28) from the lake (the map site's hover was ~20
  tiles off) into the lakeside house's hall, from the map's own room data.
- **The Last Broadcast, phase 2** (2026-10-28, `_LastBroadcast`, `_Broadcast`, `_OnAir`,
  server `_Radio`; design in `plans/last-broadcast.md`): day 14 (23 July), power and water off,
  08:00, one life. You start in a lakeside house in south Louisville (12240, 3683) with a school
  bag, two days of food, water, a flashlight, a radio already on 93.2, a used weapon by
  profession and a paper map with Jackie Jaye's studio circled (12482, 3912). When the studio
  first loads: three dead inside, eight in the street, a generator outside (connected, a third
  full, 70%) and a microphone on the desk. Right-click in the studio for tonight's show: the
  listeners, the running order (the weather, from tomorrow's real forecast; places you have
  been since the last show, with how far, which way and whether there is stock left) and Go on
  air between 18:00 and 19:00 with power. Each line goes out on LBMW's own 93.2 and over your
  head in turn. Walking off or losing power cuts the show and it does not count. On air the
  station makes a sound every five minutes, carrying further with more listeners. Settled at
  20:00: two evenings missed in a row fail the run (the first show is due by the third evening);
  thirty shows win it; the game carries on either way. Vanilla's stations are switched off, so
  the dial is quiet. Placeholder menu art (28 Minutes Later's).
- **The frame** (2026-10-27), `VitalityChallenges_Core.lua`: `VitalityChallenges.define(spec)`
  builds the table the game's challenge code wants (`media/lua/client/Challenge/ChallengeData.lua`)
  from a plain spec: sandbox values merged into SandboxVars on every load, a start hour and
  weather, a scene and a character setup, a first-minute hook for reaching other mods, minute,
  hour and day hooks, render and death. Setups run once, kept in the world's ModData and the
  character's mod data rather than guessed from hours survived. `everyCharacter = false` keeps the
  character setup to the world's first character. `spawns` gives the game several spawn points.
- **Scene helpers** (2026-10-27), `VitalityChallenges_Scene.lua`: place a car facing a direction,
  wreck it with storage left whole (a battered trunk holds nothing), load its trunk, corpses,
  zombies, a fracture, a cut, stats, time of day and a weather stage. Each call is guarded.
- **Pile-Up** (2026-10-27), rebuilt from the old mod: the first night, 11 PM, a 6-hour
  thunderstorm, 1-hour days; you crashed into the tail of the map's highway traffic jam at
  11643, 8710 with a broken, unsplinted lower leg (fracture 30, pain 30), a cut head, Tired,
  panicked and stressed. Your sedan is dead (engine 0, 0-2 fuel, unlocked) with 19 things in the
  trunk; three bodies around it. Thin early population (0.3x start, 1.5x peak on day 28), spawn
  area cleared, no starter kit. A respawn arrives whole. With the Vitality Project: a certain
  knock to the head (strength 0.35) on the first minute. Fixed from the old one: comments that
  gave the start as 9 or 10 PM, and the `hourOfDay` field the game never reads for a challenge.
- **Rules** (2026-10-27), `VitalityChallenges_Rules.lua`, switched on in the spec: `noDriving`
  (ISStartVehicleEngine and ISHotwireVehicle isValid say "It won't turn over.", an engine running
  under the driver is shut off on the minute), `oneLife` (the death screen's continue button off
  like CDDA's, the walk added to its lines; a new character in that world is told and sent to the
  main menu), `goal` (a box and a floor: reaching it shows a summary and play goes on). The walk is
  tallied (tiles on foot, a move over 60 tiles in a minute or in a vehicle not counted; kills;
  days) and each ending appended to `Zomboid/Lua/VitalityChallenges.txt`. The frame gained
  `VC.rules` hooks and a sandbox that may be a function.
- **Kit helpers** (2026-10-27), `VitalityChallenges_Kit.lua`: profession and trait checks (vanilla
  ids, or Vitality keys through DanTraits_HasTrait), undress, wear (condition, per-part dirt, a
  hole), put (count, uses, condition, water), levels, hold, attach to a free hotbar slot of given
  types, a worn item by type.
- **Nomad** (2026-10-27), `VitalityChallenges_Nomad.lua`, id VC_Nomad, mode "Nomad": spawn 965,
  14833; reach floor 26 within 30 tiles of 12785, 1527 (the floor Top of the World starts on).
  A Really CD DA's world settings (December, a year on, Insane, power and water off, no loot
  respawn, 1-hour days), a 12-hour blizzard at the 9 AM start, no driving, one life. Vanilla Top
  of the World image and video. The kit: long-sleeve T-shirt, flannel shirt, round-neck jumper,
  light hunting jacket, jeans, heavy socks, beanie, belt, hiking boots at 25%, fingerless gloves
  at 45% with a hole in one hand, everything 20-35% dirty; big hiking bag (tent inside, sleeping
  bag strapped under it on the first minute), fanny pack (full lighter, painkillers with one
  left); food 8,373 kcal (peanut butter, chocolate, 2 jerky, 3 granola bars, 2 sunflower seeds,
  dried apricots, 2 peanuts, crackers, corned beef, bolognese, tuna, chili) and a tin opener; full
  military canteen; flashlight; 2 soap; lighter fluid at 2 of 20; camping first aid kit (2-4
  bandages, 3 of disinfectant / wipes / tweezers / suture needle / cotton balls, antibiotics 1 in
  5); a paper map (own map id, start to tower) with the tower circled in red once. Foraging +2,
  First Aid +1, Lightfooted +1. Weapons by profession, used (60-80%), the main on the back when
  it fits, else in the hands, the belt one on the belt or holster (police and veteran: a holster
  and a loaded pistol); the park ranger's fire-hardened spear full. Trait head starts, all vanilla items at full condition: Brawler (a baseball bat with spikes),
  Baseball Player (a can-reinforced bat), Hunter (hunting knife on the belt, or in the bag beside a
  pistol), Handy (claw hammer), Bushcrafter (hand axe), Whittler (pocket knife), Blacksmith
  Knowledge (the best weapon its starting Blacksmith level can forge: crude knife at 0, small
  knife 1, long crude knife 3, hatchet 4, hunting knife 5, simple shortsword 6, simple sword 8),
  Target Shooter (an SN38 revolver, empty, in an ankle holster), Vitality's Renaissance Faire Geek
  (crude short sword; never matches without Vitality). With Vitality: Starting Medication
  forced on, one more beta blocker, anticonvulsant, insulin pen, metformin or baclofen, a bottle
  of antidepressants (MDD) or iron pills (Anaemic), every med into the fanny pack (the bag when it
  is full). Calories from Nutrition.updateCalories: walking 0.078 kcal per game second, still
  0.016, asleep 0.003, x weight/80; a day of 8 h each is about 2,800.
