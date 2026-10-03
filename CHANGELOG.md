# Changelog

All notable changes to the Vitality Project. The Workshop page carries a shorter
version of each entry (`workshop/changelog.txt`); this file has the detail.

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
  clumsy (3% grip slip). Found where other prescriptions are, but rarer. New Migraines
  characters start with two tablets.
- Personal triggers: each character has three triggers that hit twice as hard; the rest
  count for half. You are not told which: once a trigger has brought on two attacks, your
  character works it out and tells you.
- New triggers: heat (hot weather or overheating), the smell of corpses close by, and a
  storm on the way.
- Cost -8 (was -6). Ordinary painkillers barely touch an attack now (their timer keeps 35%
  during one); sumatriptan is what works.

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

### Arthritis

- A slipping grip now makes a weak swing (0.35x damage for that swing) instead of throwing
  the weapon. Only in a bad flare (cold and damp) can a slip still send the weapon to the
  ground, and the new sandbox option **Arthritis Drops Weapons** turns that off.

### Smoker

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
- New hooks: `nightScored` (Vitality has scored the night), `spoonCap`, `spoonSpend`,
  `spoonRefill` (the spoon budget), `gripSlip` (Arthritis), `stitchPoor` (wound care),
  `prePill` from the mod's own pill action as well as vanilla's.
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
