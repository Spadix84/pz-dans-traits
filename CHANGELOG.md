# Changelog

All notable changes to the Vitality Project. The Workshop page carries a shorter
version of each entry (`workshop/changelog.txt`); this file has the detail.

## Unreleased

### Age, reworked: four decades, felt every day

Age used to show only when something rare happened (blood loss, a concussion, a hangover).
It now sits on the everyday systems. The whole system is written up in `docs/age.md`.

- **In Their 50s (-4)**, a new band: three extra profession levels, and the slowest body.
- **Prices changed sides.** In Their 20s now costs 6 points (it gave 2) and In Their 40s
  gives 2 (it cost 1): youth is the advantage in play, age is the trade for skill.
- **Profession levels** in the main skill are 0 / 1 / 2 / 3 (the 40s had 1), and in the
  40s and 50s every other skill the profession boosts gets one level too. Fitness and
  Strength never get age's levels (a Fitness Instructor's main skill is Sprinting). The
  Unemployed get the levels in Maintenance.
- **Every day**, by band (20s / 40s / 50s against the 30s): endurance recovery x1.25 /
  x0.92 / x0.85; Fitness and Strength experience x1.5 / x0.9 / x0.8; scratches, cuts and
  unstitched deep wounds heal x1.5 / x0.9 / x0.8; stiffness fades x1.5 / x0.85 / x0.7;
  night wakes count x0.8 / x1.15 / x1.3 in the sleep score.
- **The 50s on the existing effects:** red cells x0.65, concussion x0.6, hangover x1.5,
  Type 2 resistance +0.2, Brittle x1.5, Arthritis joint factor x1.6, Heart Condition x1.5,
  Handy +1 Carpentry.
- **Everyone carries an Age trait.** Pick none and In Their 30s (cost 0, not in the
  creation lists) is given at the start. The four exclude each other.
- **The creation screen shows age's levels:** in the Major Skills list, "(+N age)" after
  the skill and the extra bars in blue. The XP rate column counts only the game's levels.
- **Sandbox:** Default Age goes to 59; Profession Levels (40s) defaults to 2; new
  Profession Levels (50s), default 3.
- **Heart Condition** reads the age band instead of the traits, so Default Age and the
  Age switch count for it.

Old saves: nobody's skills change. A character with no Age trait is given the default
band's the first time the save loads. Characters already in their 20s or 40s feel the
everyday effects from then on. A saved sandbox keeps its old Profession Levels (40s).

For mod authors: `DanTraits_AgeLevels(boosts, band, handy, bonus)` and
`DanTraits_AgeRoundBand(age)` are new; `DanTraits_AgeBand` can return 50; Age subscribes
to `enduranceRegen`, `woundHeal` and `nightWakes`, and runs a minute step at order 23.5.

## 1.1.0 - 2026-10-03

Everything since the first public upload (1.0.0, 2026-09-30). Singleplayer, Build 42.
Safe to update mid-save: old medication levels are carried onto the shared system the
first time each turns up, and existing Migraines characters get their personal triggers
the first time the mod runs.

### New trait: Multiple Sclerosis (-15)

- Heat is the enemy, and no medicine helps with it. A heat load follows the warm air
  (24 to 34 C) and your body temperature (exercise, too many clothes), building over about
  half an hour and fading over twenty minutes once cool, twice as fast wet. A drink
  straight from a tap, well or river takes some off; bottles do not.
- Three tiers. Warm: tire sooner, endurance back slower. Hot: stiff, sore, clumsy hands
  (the game's stiffness on hands and forearms), swings can throw the weapon (5% rising to
  15%), pain rising to about 60. Overheated: severe pain and a 5% chance a minute the hands
  give out and drop what they hold (not while asleep or in a vehicle). Cooling off clears
  it within about half an hour, and MS takes back its own stiffness and pain.
- You warm up a tenth faster than anyone else, and discomfort (the Uncomfortable moodle:
  clothes, a cramped car, wet) wears you down: extra stress, and spoons spent half as fast
  again at full discomfort.
- Flares about once a month (likelier with fever, stress, or hours spent at the wall) for
  three to six days: the heat hits half as hard again, stiff legs, weak hands, exhaustion.
- Starts at -1 Fitness and -1 Strength; cannot be taken with Athletic or Strong.
- Three 1993 MS pills (new items, on the shared medication system): **Prednisone** makes a
  flare pass three times as fast from the first pill (hunger while you take it);
  **Baclofen** builds up over two days to halve the stiffness (mild drowsiness);
  **Amantadine** builds up over three days to add two spoons to every morning (dry mouth).
  Starts on baclofen and amantadine, built up, with a 30-pill bottle of each.
- Moodles: MS Heat (heat sensitive, too hot, overheated), MS Flare, Spoons.

### New system: spoons, an energy budget (Multiple Sclerosis)

- You wake with a day's spoons (12; sandbox option **MS Spoons a Day**, 0 turns the budget
  off and brings back the old fatigue drip). The refill is set by the night the mod already
  scores for everyone: hours slept, how rested you woke, waking, light, fever. A bad night
  gives fewer, never under a third; a flare caps it at eight. An hour after getting up,
  Vitality scores the night for real and the count is corrected.
- Everything you do spends them by effort (the game's metabolic rate: idle a spoon every
  two and a half hours, sprinting about three an hour), faster in the heat (x1 + load), in a
  flare (x1.5), in pain, panicking, hungry or uncomfortable.
- Reading or writing costs a fifth of what the minute would otherwise, after every
  multiplier, and counts as rest however heavy the bag beside you.
- At half, a warning; at three or fewer, stiff legs and slow stamina; at none, the wall:
  heavy tiredness, legs like a flare's, stamina at a crawl, a swing that can throw the
  weapon, and every hour you push on borrowed from tomorrow's refill (up to six) and a
  likelier flare.
- Sitting still, not hungry, not laden, gives back half a spoon an hour, up to two a day; a
  nap up to four. A mug of coffee hides the wall for an hour, then it lands. Each morning
  you are told the count.

### New system: shared medication

- Every medication in the mod (insulin, metformin, the inhaler, iron pills, nicotine gum,
  anticonvulsants, the MS pills, sumatriptan, diazepam) and vanilla's beta blockers,
  painkillers, sleeping tablets, caffeine pills and antidepressants now go through one
  system: a level in the blood with a half-life, a build-up over days for the daily drugs
  (a paler moodle until it is built), rescue drugs that act at once, and a wearing-off
  notice when the level drops under protection.
- Side effects: a daily roll per drug (sandbox option **Medication Side Effect Chance**,
  default 3%), each drug's own (drowsiness, dry mouth, hunger, a stomach that shows the Sick
  moodle). Too many doses at once is an overdose that lasts.
- **Diazepam** (new item): the panic drop vanilla beta blockers used to give. Beta blockers
  now do only what the Heart Condition trait needs, once a day.
- Bottles hold 30 pills. Tooltips are short stacked lines. Notices over the head stay ten
  seconds.
- Sandbox option **Starting Medication** (on): new characters with a medical trait start
  with their medication (the MS bottles, two beta blocker bottles, the inhaler, two
  sumatriptan tablets, and so on); off, they find their own.

### New item: Pill Caddy

- A rare weekly pill organiser that goes on the belt and holds medication only. Capacity 1
  (Organized makes it 2). A new character with a medical trait has a 1% chance to start
  with one; otherwise pharmacies and medicine cabinets.

### Migraines

- **Sumatriptan** (new item, rare): the migraine pill. Taken during the aura, the attack
  that follows is half as bad. Taken during an attack, it is over within two hours with the
  pain and nausea halved. Once per attack. The day after, you are heavy-limbed and a little
  clumsy (3% grip slip), shown by a Heavy-Limbed moodle for the day. Found where other
  prescriptions are, but rarer. New Migraines
  characters start with two tablets.
- Personal triggers: each character has three triggers that hit twice as hard; the rest
  count for half. You are not told which: once a trigger has brought on two attacks, your
  character works it out and tells you.
- New triggers: heat (hot weather or overheating), the smell of corpses close by, and a
  storm on the way (in the twelve hours before the forecast says it starts, so once per
  storm at most).
- Cost -10 (was -6). Ordinary painkillers barely touch an attack now (their timer keeps 35%
  during one); sumatriptan is what works.
- Stronger nausea: food sickness up to 50 at full severity (was 30), so an untreated attack
  shows the Queasy moodle. Sumatriptan halves it.
- Room light counts, not only the sun: awake in a lit room an attack hurts more (+10 pain)
  and lasts longer (0.75 speed); in a dark room it passes a quarter faster.
- Sunglasses halve the pain the light adds (sun or a lit room). Every tinted pair in the
  game counts (19 items), and any other mod's worn item named sunglasses or shades.
- Blurred vision for the attack: the game's own Short Sighted blur, with its shorter sight
  and worse aim. The game only blurs when Short Sighted and wearing glasses disagree, so the
  attack flips the trait while they agree and puts it back when it ends.
- New moodle, Light Too Bright, during an attack: how much pain the light is adding (Too
  Bright in a dimly lit room or a lit room in sunglasses, Light Hurts in a lit room or the
  sun through sunglasses, Blinding in the sun). Gone in the dark.

### Wound care

- Stitching is a First Aid roll. At low First Aid, stitches can come out rough (45% at
  level 0, 5% less a level, never under 3%; a suture needle or needle holder cuts that to
  0.6x, Steady Hands halves it): they knit at half speed, tear twice as easily, ache, and
  let infection in until they are sound. At First Aid 3 or higher you can tell a rough job,
  and the health panel shows it. Take the stitches out and try again.

### Concussion

- The headache after: a concussion can leave a headache that comes back one to two days
  later, often after the knock itself has cleared, and worse than it. Sleep gets you through
  it half again as fast; daylight makes it worse.

### New system: anger has effects

- The vanilla Angry moodle (Irritated, Annoyed, Angry, Furious) does nothing in the base
  game. It now costs everyone, from Annoyed up; Irritated is only the warning. Nicotine
  withdrawal is what raises it in this mod (to Angry at full withdrawal); anger from another
  mod counts the same.
- Rough: each melee hit has an extra chance to wear the weapon (x1.5, x2, x2.5 the game's own
  wear at Annoyed, Angry, Furious), never its last point. Furious swings cost extra endurance.
- Loud: from Angry up the character curses out loud (1.5% a minute, 4% at Furious), heard at
  8 or 14 tiles. Not asleep, and it shares the cough's three-minute gap.
- Can't concentrate: reading takes x1.15, x1.3, x1.5 as long.
- Sloppy fine work: bad splints and rough stitches x1.25, x1.5, x2; a vehicle part's success
  chance down 5, 10, 20 points and its failure chance up by the same (the mechanics window
  shows it).
- The Angry moodle's descriptions say what it costs. Sandbox option Anger Has Effects
  (default on) turns it all off. Console: `anger <0..1>`, `anger curse`.

### Drink relief

- Being drunk lifts the mood, by Drunk level, each minute awake: unhappiness -0.05, -0.12,
  -0.3, -0.5 (of 100), stress -0.0005 to -0.004 (of 1), boredom -0.1 to -0.6 (of 100). Three
  hours at the top level clears a severe mood. Vanilla only ties mood to the volume drunk
  and gives no stress relief. Under the Drink Relief sandbox option. A depressive episode's
  floor is applied after it and holds.

### Hangovers

- Easier to earn a bad one: full severity at 2 drunk-hours (was 3), and the mildest hangover
  is 0.4 strength (was 0.25).
- Endurance recovers up to 40% slower while it is felt, by its strength.
- Bright daylight outdoors adds 10 to the headache (45 at full strength in the sun).
- Painkillers only dull it: a pill taken while hungover keeps half its usual time. During a
  migraine attack the migraine's own, harsher rule applies and the two do not compound.

### Depression

- New moodle, Antidepressants (good side only): paler green while a pill's coverage is
  running, full green once two unbroken weeks have brought the regimen to full benefit, and
  gone when coverage runs out, so the icon going out is the reminder. It shows through an
  episode. For a character without Major Depressive Disorder it shows while the game's own
  antidepressant effect runs.

### Hemophilia

- Costs -10 (was -8): it plays as designed and is very punishing. Existing characters are
  unaffected.

### Arthritis

- A slipping grip now makes a weak swing (0.35x damage for that swing) instead of throwing
  the weapon. Only in a bad flare (cold and damp) can a slip still send the weapon to the
  ground, and the new sandbox option **Arthritis Drops Weapons** turns that off.

### Smoker

- Cravings build half as fast: a Smoker taken at creation now reaches withdrawal at half
  vanilla's pace (it was vanilla's pace), and every habit level is halved with it, so a
  heavy smoker builds at 0.875x vanilla instead of 1.75x. Drink still speeds it up 1.5x.
- New sandbox option **Nicotine Craving Moodle** (on): off hides the craving moodle and its
  notice, so you read the craving from irritability and stress instead.

### Caffeine Dependent

- A mug of coffee, tea or cocoa now counts. The game makes these as food items with the
  coffee, tea bag or cocoa as an ingredient, and the mod was only looking at the Coffee
  fluid, so a brewed mug never ended the withdrawal. A spoon of coffee in a mug is a full
  dose, a tea bag a small one, a can of cola a third of a coffee.
- A small dose now does something. A bar of chocolate or a can of cola never ended a
  craving (it still does not), but it used to be ignored outright. Now it puts the craving
  off: three hours for a bar, six for a can, and if that takes you back under the half-day
  mark the craving lifts until the clock catches up. Coffee, tea and caffeine pills still
  end it outright. The trait and moodle text say which is which.

### Alcoholic

- Feeling tipsy ends the craving at a normal habit; it took being drunk before.

### Vitality

- Thriving gives 1.5x Fitness and Strength experience (was 2x).

### Other mods

- **Project A-Life** (`ProjectALifeNPCs`): the Hallucinations phantom is a real zombie for a
  few seconds, and A-Life steers every zombie in the cell and has its NPCs shoot them. Its
  horde steering, attack policy and sight check now leave a phantom out
  (`DanTraits_ALife.lua`; does nothing without A-Life), and a phantom that another mod
  un-parks is parked again on the next tick.

### Fixed

- The last sip counts: Caffeine Dependent and Lactose Intolerant read the drink after each
  sip, and the sip that empties the mug left nothing to read, so the last of a coffee or a
  glass of milk never counted.
- Spoons: a night slept in two halves (Restless Sleeper, or waking and going straight back
  to bed) refilled twice and forgot the hours borrowed the day before.
- Blood loss: turning the blood system off mid-save left the last tier, the weakness and
  Fear of Blood's fainting running on stale numbers. It stands down now and resumes when
  switched back on.
- Sunburn: turning it off mid-save could leave the "skin feels hot" moodle on for good.
- A Really Bad Day: the container the needle and thread were placed in was restocked every
  time the game refilled it, forever with loot respawn on.
- Health panel: with the mod's wound infection switched off, an infected wound never showed
  at any First Aid level.
- Asthma: the cough countdown carried from one tier to the next.
- Blood loss: light-headed set the game's can't-sprint flag every frame, so the Restricted
  Movement moodle blinked on its own timer. The flag is now set only on an attempt to sprint.
- Hemophilia: a bandage's four-fold leak applied to soaked bandages and ones over a shard
  too, so a soaked bandage bled twice the normal rate, worse than no bandage at all (x1.5).
  A bandage is now never worse than bare skin; a clean one is unchanged at two fifths.
- Epilepsy and Heart Condition ran their medication notices for every character.
- Sandbox options: the Developer Tools option is gone; the dashboard's telemetry and
  command channel run in debug mode only.

### For mod authors

- `DanTraits_Util.lua` gained `DanTraits_Round`, `DanTraits_Over`, `DanTraits_TierOf`,
  `DanTraits_IsItem`, `DanTraits_ItemUses`, `DanTraits_FluidName`, `DanTraits_FluidRatio`,
  `DanTraits_AirTemp`, `DanTraits_PanicDecay`, `DanTraits_ScaleActionTime` and
  `DanTraits_HeadPainAtLeast`; the trait files use them instead of their own copies.
- The `drink` hook now receives the fluid's name and share as extra arguments, read before
  the sip.
- The `bloodBleed` hook now receives the part's unbandaged rate as a fifth argument.
- New hooks: `nightScored` (Vitality has scored the night), `spoonCap`, `spoonSpend`,
  `spoonRefill` (the spoon budget), `gripSlip` (Arthritis), `stitchPoor` (wound care),
  `prePill` from the mod's own pill action as well as vanilla's.
- New export: `DanTraits_IsPhantom(zombie)`, true for a live Hallucinations phantom, for
  mods that steer or target zombies.
- Four exports nothing used are gone: `DanTraits_GripRestore`, `DanTraits_MigraineParts`,
  `DanTraits_StormComing`, `DanTraits_SpoonsUsing`.

### Also released separately

- **Dan's Vanilla Fixes** (mod id `DansVanillaFixes`, a separate mod in this repo): cold packs
  that charge in a fridge (half way) or freezer (fully) and keep a cooler's food cold
  (sandbox option Cold Pack Hours, 6 per frozen pack), plus the Item Rarity UI patch that
  gives modded items a rarity.

### Known issues

- Multiplayer is untested and not supported.
- A Really Bad Day is not balanced yet.
- Bandages: replacing a bandage with a worse one within the same game minute can be read as
  vanilla's wear and undone.
