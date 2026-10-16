# Changelog

All notable changes to the Vitality Project. The Workshop page carries a shorter
version of each entry (`workshop/changelog.txt`); this file has the detail.

## Unreleased

### New

- **Home**, for everyone (sandbox option Home, `DanTraits_Home.lua`, minute order 11): where you
  sleep most nights becomes home. Each night Vitality scores (not a nap, not in a vehicle) is filed
  where the character fell asleep, the building's footprint (`IsoGridSquare.getBuildingDef`) or
  the spot in the open; three of the last seven nights in one place make it home, with a notice,
  and when more of them are somewhere new home moves there (ties go to the newer place). Nights at
  home count up (half strength at three, full at seven; a night away does not take them down).
  At home (the footprint plus four tiles, or twenty tiles of a camp), awake: boredom, unhappiness
  and stress ease each minute, a night slept there scores up to +0.05 (the `nightQuality` hook),
  and `ISReadABook` runs up to a tenth faster. Two days away and you miss it: over the next day the
  strength climbs with an unhappiness floor of 15; walking back in takes 15 unhappiness and a
  tenth of stress off at once, with a notice. New moodle **Home** (Settling In / At Home on the
  good side, Missing Home / Homesick on the bad), the 21st fed from `DanTraits_Moodles.lua`.
- **Homebody (-2)**, new trait: home does twice the good (the drains, the night bonus at +0.1,
  reading a fifth faster); misses it after a day away, with a floor of 30, stress on top and
  nights slept away at -0.1. Not with Nomad.
- **Nomad (+3)**, new trait: no home, nothing missed, nothing tracked; a night slept with no
  building around (outdoors, a tent, a car) scores +0.1. Not with Homebody or Settled.

- **Laundry**, for everyone (its own sandbox page, Vitality: Laundry; master switch LaundryEnabled;
  `DanTraits_Laundry*.lua`, design and as-built notes in `plans/laundry.md`). Each garment keeps a
  little state in its mod data (`DTL`), made the first time it is seen.
  - Hand washing has floors, moved here from Dan's Vanilla Fixes: each patch of blood and dirt only
    comes down to 40% without soap, 20% with soap or cleaning liquid; a carried **washboard** (new
    item; loot, a carpentry recipe or a Carving 2 recipe) makes it 25% / 10% for a scrub half as
    long again. A wash with nothing to gain is refused with the reason. Only a washing machine gets
    clothes fully clean. Take A Bath And Shower's bath wash keeps the same floors.
  - Wringing stops at 50% wet (shoes 70%). Worn clothes keep 25% of the game's drying each minute
    (sandbox Drying on the Body; the game dries a soaked shirt on the body in about 20 minutes,
    measured in play) and every hour worn damp adds 25 odour. A garment 30% wet or more for 6 hours
    (worn hours x1.5) turns musty until washed.
  - Odour from wear, hard work and heat, by layer (against the skin full, outer layers half,
    accessories none). Moodle **Stale Clothes** (odour 50: +0.5 unhappiness an hour, to 20) and
    **Musty Clothes** (musty or 80: +1 an hour, to 30); on its good side **Fresh Clothes** when
    everything worn (shoes aside) is clean, dry and under odour 15 (-0.5 unhappiness and -0.01
    stress an hour) and **Line-Dried** when half of it dried on a clothesline in daylight since its
    last wash (twice that). Germaphobe x2 both ways, and stale clothes count as dirty for its
    clothing share. A musty garment over a wound counts as dirty clothing for infection. Freshen up
    clothes at a water source for clean but stale garments.
  - Blood left 3 days sets into a stain (half of it, at most 20%: under the game's bloody line)
    that no wash, machine included, gets under; **Bleach stains out** at a water source (0.1 L a
    garment). Each wash may take a condition point (hand 1%, washboard 3%, machine 4%, bleach 25%;
    never a hole, never under 1). Washing machines are watched while they run near you.
  - Dry by the fire at a lit campfire, fireplace, barbecue or stove. Clotheslines: the pulley
    posts in yards each get a container of 15, and **Put up a clothesline** (two long sticks,
    planks or saplings and two rope, twine, strips or wire) places a five-tile line like the map's;
    lines dry by the weather and air odour down to 30 in daylight; rain soaks them.
  - A worn poncho takes the blood and dirt for the parts it covers; the garbage bag poncho tears
    as it is used: 20% for a condition point each minute blood or dirt lands on it (or on the
    clothes under it), 10% each ten minutes of hard work or heat (a rough no-skill recipe added). **Fabric protector** (new item) and **fabric
    wax** (two candles and a tin) halve what a garment takes, for about three washes.
  - Tooltip lines on garments; a debug-only `laundry` dashboard command for play-testing.
- **Laundry traits** (`DanTraits_LaundryTraits.lua`, through laundry's hooks, so they do nothing
  with laundry off; each has its own icon):
  - **Sweaty (-2)**: sweat odour x1.75. **Cool Customer (+3)**: x0.5 (odour from wearing clothes
    damp is not sweat and is not changed). Not with each other.
  - **Slob (+2)**: the laundry moodle is not shown, so neither Stale/Musty nor Fresh/Line-Dried
    touches mood; musty clothes still count for infection. Not with Germaphobe or Homemaker.
  - **Homemaker (+4)**: a hand wash uses the washboard's floors and takes odour out without soap;
    a washboard's floors are halved; every wash's fabric wear chance halved (machine and bleach
    too); Line-Dried x1.5. Not with Slob.
  - **Sensitive Skin (-2)**: each worn garment against the skin (shoes aside) that is damp (30%+),
    musty (counts 2) or never washed holds discomfort at 20, +10 for each more, up to 50, awake,
    with a notice. The starting outfit is marked washed (`ok` in the garment's state, a starting
    kit); a tooltip line names a never-washed garment.
  - Other traits: Nomad x0.5 on Stale/Musty mood (rate and cap); Homebody x2 on Line-Dried when
    most of it dried on a clothesline at home (`sh`); Asthma +0.08 airway irritation a garment
    bleached indoors (`DanTraits_AsthmaFumes`: dust mask halves, gas mask stops); Fear of Blood
    +0.05 stress a bloody garment washed or bleached; Bad Back +0.06 load a garment scrubbed on a
    washboard (`DanTraits_BadBackStrain`, the same load and notices as a heavy pack).
  - Laundry's hooks: `laundryOdour`, `laundryMood`, `laundryFresh`, `laundryMoodle`,
    `laundrySkilled`, `laundryAtHome`, `laundryWashed`, `laundryTooltip`.
- **Sandbox pages**: the options are split into Vitality: General, Health, Daily Life, Laundry and Reading.
  Option names are unchanged, so saved settings keep their values.

### Changed

- **Germaphobe** gives 8 points (was 4).
- **Rough Night less often.** A night's hours half was hours slept over 7 (5 or 9 with the sleep
  traits), but the game wakes you when tiredness runs out, so a half-tired character slept about
  four hours, woke rested and still scored under 0.8; a lit room or one wake then tipped it into
  Rough Night (any score under 0.75). The hours half now takes the larger of that and the share of
  bedtime fatigue cleared by morning (`vitNightBedFatigue`, the highest at the start of any sleep
  that night), when bedtime fatigue was at least 0.1. Four hours from half tired to rested is a
  full night; an alarm at 0.4 after going to bed at 0.8 still counts by the hours.

- **Smoke gets into your clothes** (`DanTraits_Smoker.lua`): for six hours after any cigarette, cigar or pipe, habit or not, worn clothes go stale half as fast again (x1.5 on the laundry odour rate, on top of Sweaty or Cool Customer).
- **The headache after a concussion feeds Migraine** (`DanTraits_Migraine.lua`, `DanTraits_Hallucinations.lua`): the post-concussion headache (`DanTraits_ConcussionLateStrength`, which outlasts the score) was read by nothing; it now adds up to 2.0 to the migraine chance, beside the concussion itself, and keeps Schizophrenia's panic bouts down the way the concussion does.
- **Hangovers and dehydration know each other** (`DanTraits_Dehydration.lua`, `DanTraits_Migraine.lua`): a hangover builds the dehydration load on its own (Thirsty's pace times its strength; drinking water still drains it, slower), a hangover starting on a dehydrated body is up to half as bad again, and Migraine's thirst trigger reads the hours-long load as well as the moment's thirst.
### Fixed

- **A drink counted once per tick, not once per drink** (`DanTraits_Diabetes.lua`): vanilla calls `ISDrinkFluidAction:updateEat` on every tick of the action and once more from `complete()`, and the `drink` and `alcoholDrunk` hooks fired on each call. Delicate Stomach got +10 food sickness per tick of a beer (Nauseous in ten ticks), Caffeine to Sleep saw a mug of coffee as a run of tiny doses (minutes of caffeine hours instead of six), Lactose Intolerant got a halo and a story line per sip, and Vitality logged a meal per sip. The wrap now sums the sips on the action and reports once, with the litres, when the drink completes, is stopped, or the fluid changes; `alcoholDrunk` carries the litres (Delicate Stomach doses pro rata to a 0.33 l bottle, capped at one); Lactose notifies only on the first dose of a brewing flare.
- **A fainting driver's car never stopped** (`DanTraits_Faint.lua`): the engine was cut through the `vehicle shutOff` client command, which B42 does not handle (its own exit-vehicle code has that line commented out), with `car:shutOff()` only as a fallback for a thrown error. Now the direct call, as vanilla's shut-off action does. New `tests/test_faint.lua`.
- **Antibiotics taken before an infection showed were thrown away** (`DanTraits_Infection.lua`): while a wound was only contaminated the dose count was zeroed every minute, so a course started on a dirty bite read as a fresh count when the infection showed, and finishing it early left an unfinished course and a relapse roll. The count is kept while any part is contaminated; a wound cleaned before it shows still resets it.
- **A bandage on a hemophiliac soaked at the plain rate** (`DanTraits_Blood.lua`, `DanTraits_WoundCare.lua`): `DanTraits_BloodPartRate` was the raw per-part rate, and the `bloodBleed` hooks (Hemophilia x2.5 under a dressing, Good Clotter x0.75) ran only in Blood's own minute. The export is now the hooked rate, so a hemophiliac's dressing needs changing sooner and a Good Clotter's lasts longer, as the trait texts say.
- **The food classifier misread real B42 names** (`DanTraits_Food.lua`): chamomile was meat ("ham"), so a Vegetarian refused the tea; a turkey egg was meat; gummy fish and worms were meat with full iron for an Anaemic; opened canned soups and anything poppy were junk ("pop"), so Delicate Stomach and the diet grade fired on soup; jelly beans and chocolate-covered coffee beans were greens. Seven `FoodType = Candy` items carried no junk tag at all. Safe words for each, and the Candy and Chocolate food types are junk and fast sugar whatever the name. `tests/fixtures/foods_b42.lua` is the game's food list and the test runs the classifier over it.
- **Diabetes counted any low endurance as exercise** (`DanTraits_Diabetes.lua`): endurance under 0.6 from an asthma attack, angina's recovery cut, blood loss, anaemia or the spoons wall dropped sugar 0.5 a minute for as long as it stayed low, on top of any insulin. Exercise is now endurance going down this minute (Asthma's test), or running or sprinting.
- **Heart Condition fed on its own angina surcharge** (`DanTraits_Heart.lua`): the minute's "endurance spent" included the frame handler's 1.5x swing surcharge during chest pain (and the week's spending stage), so a swing in chest pain fed strain at 1.5x and deepened the angina. The surcharge comes off the minute's baseline as it is charged. Decided and written in the header: what other systems take (an asthma attack, blood loss, the spoons wall) still counts as strain.
- **Epilepsy: an aura that began asleep seized an awake player with no warning** (`DanTraits_Epilepsy.lua`): the notice and the 30-second real-time floor were skipped when the aura started in sleep, so anything that woke the character inside the window (an asthma gasp, a light sleeper's wake, the alarm) ran the countdown out and the seizure came the awake way, unannounced. The first awake minute now gives the notice and the floor. The minute handler also rolled for a new aura during the hour's aftermath, when a head knock multiplies the rate x6; no roll there now.
- **Laundry: a machine wash was marked while the machine was merely running, and a stacked washer-dryer was not a washer** (`DanTraits_Laundry.lua`): every ten-minute tick an activated washer held a garment marked it washed, so load, start, pull the clothes straight out gave odour 0, musty cleared, a wash counted and a wear roll on garments still at full blood. A garment is marked only once the cycle has finished with it (every part at blood 0 and dirt 0, and soaked). `IsoStackedWasherDryer`, which the washer menu already loads, is now read as a washer through its own `isWasherActivated()` and washer drum, so its cycle keeps the mod's bookkeeping (and a set-in stain).
- **Laundry's tooltip strip drew on top of the shared strip** (`client/DanTraits_LaundryClient.lua`): it kept its own `ISToolTipInv:render` wrap at the same place `DanShared_Tooltip.lua` draws, so with Dan's Vanilla Fixes' item info on, every garment with a laundry line showed two boxes painted over each other. The lines now register with the shared strip (`DanShared_Tooltip.add("laundry", 22, ...)`, between Reading's and item info's).
- **Vitality switched off left a sleep debt three systems kept reading** (`DanTraits_Vitality.lua`, `DanTraits_Sleep.lua`): the off branch gave back the carry kilo and zeroed the moodles but left `vitSleepDebt`, which MDD (episode chance x2), Hallucinations and Migraine's sleep trigger read for the rest of the save; and with nothing scoring the night, Sleep's light tally grew for ever. Off now clears the debt and the night in progress, and Sleep drops its tally on waking when there is no scorer.
- **A cancelled meal reached every eat reader at 0%, and Spiraling ignored the portion** (`DanTraits.lua`, `DanTraits_MDD.lua`): vanilla calls `eat(item, jobDelta)` on every cancel and the core wrap passed 0 through; the other readers scale by the fraction and did nothing, but `DanTraits_MddOnEat` took no fraction, so starting a comfort food and cancelling gave three hours of relief. The core wrap now stops at 0%, and the relief is the portion's share of the three hours (a running timer is never shortened).
- **Asthma, MS, Arthritis and Migraines left their state behind when the trait went** (`DanTraits.lua`, `DanTraits_Asthma.lua`, `DanTraits_MS.lua`, `DanTraits_Arthritis.lua`, `DanTraits_Migraine.lua`): a trait taken off mid-game (the console, another mod, a save loaded without it) left an asthma attack, its cough gap and the Airway Irritation moodle on; MS's and Arthritis's stiffness floors on the parts and MS's head pain; a migraine's aura or attack and its moodle (the backlog's stuck Migraine moodle). `DanTraits_Every` takes `{ trait = key, clear = fn }` now: the system runs only while the character has the trait and its clear runs once when that stops (also once at the first sight of a character without it, so a stale save is put right), and the four files register one. The hand-rolled stand-downs in Blood, Infection, Concussion and WoundCare are unchanged.
- **Diabetes: the meter's advice disagreed with the model it summarised** (`DanTraits_Diabetes.lua`): the level-3 correction summed the sugar going in and the insulin working but not Type 1's creep (0.17 a minute, 41 over the four hours a dose takes) or the kidneys dumping sugar above 180, both of which the live model applies, so a Type 1 at 115 with nothing working read "steady" and was at 156 four hours later; and the food forecast behind the splitting advice counted the insulin on board at face value, not at this body's sensitivity. One projection now (`diaProject`, the model's own steps four hours ahead) serves both: the correction aims where sugar settles once everything on board has worked (120 with nothing working is one dose, 400 is five, not seven; 100 with two doses working is "eat"), a reading under the low line is told to eat unless the sugar going in covers it and is never told to inject, and the forecast scales the insulin on board.
- **Sunburn inside a car** (`DanTraits_Sunburn.lua`): the sun gate was `isOutside()`, which for a seated character is the vehicle's square's flag, so three hours of noon driving burnt the head, neck and hands. A seat in a vehicle (`getVehicle()`, the shape `DanTraits_Faint.lua` uses) is shade now: nothing builds, exposure fades as indoors.
- **Brittle rolled a fracture on fire, infection, hunger and thirst** (`DanTraits_Brittle.lua`): the raw damage handler's only gate was 2 damage or more, and B42 reports fire, a wound infection, hunger and thirst taking health off through the same `OnPlayerGetDamage`, so standing in a fire could snap a limb at 20% a report. Only a hit the game reports as one (`WEAPONHIT`, from `IsoGameCharacter.Hit`) rolls now; falls and crashes still come through Concussion's impact hook. The test uses the real damage type (it used "BLUNT", which is not one).
- **Spoons: a nap inside the night window refilled the pool again** (`DanTraits_Spoons.lua`): Spoons closed its own night after an hour awake while Vitality holds a Restless Sleeper's open for three, so a half-hour nap ninety minutes after getting up counted as a fresh morning (a full refill and a second morning notice), which Vitality's scoring of the one night then took back; and a nap zeroed the count of what was spent since the morning, so a night re-scored after one forgave the day's spending. The night now stays open for Vitality's gap (the `nightGap` hook) and a nap leaves the count alone.
- **Small, confirmed maths** (`DanTraits.lua`, `DanTraits_Sleep.lua`, `DanTraits_Age.lua`, `DanTraits_Smoker.lua`, `DanTraits_Vitality.lua`, `DanTraits_Migraine.lua`): Age scaled the night's wake count before Restless Sleeper's free wake came off (by load order), so a 50s Restless Sleeper paid 0.6 of the free wake, and it scaled the morning wake too, so an unbroken night cost the 50s 0.3 of a wake. `DanTraits_AddHook` takes an order now (lower first, default 100): Sleep's free wake runs at 10, and Age scales only the wakes over the one every night has. Smoker's withdrawal hunger went through the `hungerRise` pipeline the next minute and was scaled again by Age and Bottomless Pit; it is told to the pipeline (`DanTraits_DeltaRemember`, as Pace Yourself does). A nap moved Vitality's sleep score though the header (and `plans/spoon-theory-ms.md`) say a nap is not scored; it eases the debt and leaves the score alone now. Migraines counted a painkiller taken before the attack as the attack's first dose (the one-off 10% cut); only a pill taken in the attack (the pain effect rising past what it was, `migMedsSeen`) counts.
- **Infrastructure** (`DanTraits.lua`, `DanTraits_Asthma.lua`, `DanTraits_Infection.lua`, `DanTraits_Smoker.lua`, `DanTraits_Util.lua`, `client/DanTraits_HealthPanel.lua`, `DansVanillaFixes_Coolers.lua`): the three `DanTraits_Later` jobs with no tag (Asthma's cough burst, Infection's undo of vanilla's antibiotic effect, Smoker's dose) shared the one "later" log slot, so after the first failure the other two were silent for ever; each has its tag (`DanTraits_LaterPending` is readable by the tests, which pin them). `DanTraits_PanicDecay` called `stats:get` and `stats:set` bare against Util's own header; both are guarded. The health panel re-wrapped itself when another mod wrapped `doDrawItem` after it and a second world was loaded, and every mod line then showed twice; the inner layer now finds itself inside the outer's call and passes through. Dan's Vanilla Fixes' coolers called the game unguarded every ten minutes and on every inventory refresh (`squareOf`, `airTemp`, `place`, `coolFood`, `label`); every call is guarded, the two-argument `getAirTemperatureForSquare` falls back to the plain one, and the air reads 20 C when it cannot be read.
- **Laundry, smaller** (`DanTraits_LaundryWash.lua`, `DanTraits_LaundryDry.lua`, `client/DanTraits_LaundryClient.lua`, `DanTraits_Bathing.lua`): "Wring" was still offered by the game's own menu between the mod's line and vanilla's (only `isValid` is the mod's) and then silently never started; it refuses with "As wrung out as it will get", once (the header no longer claims it is not offered). Putting up a clothesline could be cancelled by the character standing on one of its own squares (the action re-checks every square is free each tick, and the walk could end on the first wire square): the walk now goes to a square beside or behind the first post, off the line (`L.lineStandSquare`). The clothes you bathe or shower in got the hand-wash floors without Homemaker's; the bath passes it now. A bath still does not count as a wash (the plan did not say it should; noted in `plans/laundry.md` as open, with the starting outfit's day and a half of Fresh Clothes).

- **A crash was judged against whoever came next** (`DanTraits_Concussion.lua`): the car's top speed, a crash waiting on the speed after it, the head's last reading and the minute's strain flags were module state, tied to no character, so a multiplayer respawn or a second split-screen player in the window after a crash would have been knocked for it. They are per player object now (a weak table); a character that is gone takes its state with it.
- **The clocks ran for player 0 only** (`DanTraits.lua`, `DanTraits_Util.lua`): the minute and ten-minute drivers ran every system for `getSpecificPlayer(0)` while the frame driver ran every local player, so split-screen player 1 got the frame systems and the delta pipeline but no minute system, pain floor or moodle. They run for every local player now, each once. `DanTraits_FloorUp` booked its floor flag on player 0 whatever stats it was handed; it books it on the player the drivers are running for (`DanTraits_RunningFor`).
### Other mods

- **This Is Your Life** (Workshop 3773911887): the age traits work in its Personnel Assessment
  folder (reported on the Workshop page). The folder lists every trait with a cost above or
  below zero straight from the game's definitions and greys the ones the vanilla screen would
  not offer, so In Their 30s (cost 0) never appeared, every other trait sat greyed as
  "unavailable with the current game settings" until an age was picked, and Approve and Continue
  only checked the points. `DanTraits_TIYL.lua` now takes the rows the vanilla screen would hide
  out of the folder (the gate, the other ages' traits, retired traits), puts In Their 30s at the
  top of the positive list, writes the age surcharge under a trait's cost, and holds Continue
  (and a controller's A) until an age is chosen. Everything else (points, Major Skills, Random,
  saved builds) already went through the hidden vanilla screen. The hide rules moved into one
  function in `DanTraits_Client.lua` (`DanTraits_Creation.hides`) that both screens use.
- **Project A-Life**: a ringing house alarm filled the error log, two errors a tick for as long
  as it rang (`ALifeInvestigation.lua:89-92`). A-Life's `OnWorldSound` handler asks the sound's
  source `isOutside()` and `getModData()`, and an alarm's source is the game's `zombie.iso.Alarm`,
  which is not an IsoObject and has neither; its `pcall` caught them but B42 logs them anyway.
  The handler is registered by reference, so `DanTraits_ALife.lua` takes it off the event and
  adds it back behind a wrapper that passes a source that is not an IsoObject as nil. Its NPCs
  still hear the alarm. The load line now reads `..., sound true; hits 3/3`.

### Dan's Vanilla Fixes: shop cigarettes come full (2026-10-12)

- A cigarette pack is tagged `lessfull`, so the loot roll (`ItemPickerJava.randomizeUses`) leaves
  every one it spawns part-smoked, gas station shelves included. `DansVanillaFixes_StoreStock.lua`
  fills packs back up on `OnFillContainer` in the rooms vanilla stocks from its retail cigarette
  tables (StoreCounterTobacco, GasStoreSpecial, TobaccoStoreCigarettes): conveniencestore,
  cornerstore, cornerstorecounter, fossoil, gas2go, gasstore, generalstore, liquorstore,
  tobaccostorage, tobaccostore, zippeestore. Packs anywhere else keep vanilla's roll. Only newly
  filled containers; shelves already looted or seen keep what they had.

## 1.2.1 - 2026-10-10

### Fixed

- **No weapon or tool could be equipped in multiplayer** (reported on the Workshop page the day
  1.2.0 went out: the item appears for a frame and is gone, error at ISEquipWeaponAction.lua:297
  from DanTraits_SteadyHands.lua:102). Steady Hands' quicker draw wrapped the equip actions'
  `new()`, and in multiplayer the game reads `new()`'s own parameter names to know what to send,
  then rebuilds the action on the server with them. The wrapper's `(self, ...)` has no names, so
  the server got no character and every equip, unequip and belt action failed, for everyone
  with the mod, trait or not. The quicker draw now shortens `adjustMaxTime` instead (the game
  works the animation speed out from it), and splints are slowed and sped through
  `getDuration`, so no timed action's `new()` is touched any more. `DanTraits_Wrap` refuses
  `new` from now on.
- Changing occupation cannot slip a trait past the age gate (see 1.2.0, Age).

### Dan's Vanilla Fixes: reading for pleasure (2026-10-12)

Reading was a vending machine: ten minutes, a fixed drop in boredom, stress and unhappiness at the
end, once per title. Now it is something to carry on a run (design and as-built notes:
`plans/reading.md`; its own sandbox page, Dan's Vanilla Fixes: Reading, with a master switch).

- **Every vanilla title is tagged**: 1,177 books, 224 comics and 167 magazines get a genre family
  (18 of them, folded from the game's 55 book subjects and 24 magazine subjects; comics by the
  words in their titles), a page count (softcovers 180-380, hardcovers 250-500, serious reading
  300-650, kids' books 24-64, comics 24-48, magazines 60-140, newspapers 12-40, each title its own)
  and a hidden quality of one to five stars, most at two or three. The table is generated from the
  game jar by `DansVanillaFixes/tools/gen_reading_data.py` (a bytecode walk of the `Book`,
  `ComicBook` and `Magazine` registries), with hand fixes in `DansVanillaFixes_ReadingBooks.lua`.
- **Long reads.** A novel is 1.5 minutes a page, picture media half a minute, scaled by the server's
  own Minutes Per Page; Fast Reader, Slow Reader, reading glasses, sitting and other mods' wraps
  carry over, because the time is scaled from vanilla's own answer. A 350-page novel is about nine
  hours, six with Fast Reader. The relief arrives **per page** (a novel's vanilla totals spread
  over 300 pages, so a long book gives more; comics, magazines and newspapers keep their totals)
  and vanilla's lump at the end is cancelled. Stats stop at zero, as before.
- **Bookmarks.** Progress is kept per character per title and on the copy; a read that stops
  resumes where it was, on any copy. Right-click **Read a chapter (~30 min)** reads a chapter's
  worth and stops, without the title being marked read.
- **Taste.** Each character likes one family and dislikes another (never Kids or Humor), hidden
  until about 30 pages in a family bring a notice: "You're really into this.", "Not your kind of
  book." or "It's fine." A liked book does x1.25, a disliked one x0.5 and adds a little boredom
  every twenty minutes. The tooltip shows the genre, the verdict once known, the pages read of the
  total, and your verdict after finishing.
- **Good Read**, a new moodle (Moodle Framework), on finishing a book: Good Read, Great Read
  (four or five stars, or a liked genre) or Loved It (both, with a quarter more strength). It
  lasts 12 to 48 hours by quality (12 for a comic or magazine, never above Good Read; nothing for a
  newspaper), a quarter longer for Classics. While it runs, boredom and unhappiness ease a little
  each minute, plus the genre's bonus: Horror eases panic, Thrillers and True Stories ease stress,
  Romance unhappiness, Sci-Fi boredom, Westerns endurance, Faith stress and unhappiness, Sports
  +5% Fitness and Strength XP, Science & Nature +5% Foraging XP, Self-Help +5% XP to seven
  practical skills (the XP ones only when no skill book's multiplier is running). A stronger finish
  replaces the moodle; a weaker one only refreshes it if it would last longer.
- **Re-reads** give a fifth of the drip in the liked family only (sandbox switch), and no moodle.
- **Real books**: about 200 titles from before July 1993, title and author only, with their real
  page counts and a quality by hand. A novel in loot has an 8% chance (sandbox) of being one from
  the same genre; it is named like a vanilla book and read-tracking works on it unchanged.
- **This Is Your Life**: books you finish and tastes you find out go in its survivor journal, as
  dated lines ("July 12, 1993 - Finished "Jurassic Park". Loved it.").
- Books from other mods get a neutral fallback (Popular Fiction, 120 pages, three stars, no moodle).
  Skill books, recipe magazines, fliers, brochures and the old newspapers are untouched.
- Multiplayer: the stat changes run on the client that owns the character, as vanilla's do; the
  mod is still singleplayer-only in practice.

### Vitality: hooks into the reading overhaul (2026-10-12)

- `DanTraits_Reading.lua`: with Dan's Vanilla Fixes' reading on, a page does 15% more good at
  home by the home's strength (30% for a Homebody), half as much when concussed (and takes a
  quarter longer), and a Really Bad Day's first day gets a quarter more comfort from any book.
  In their 40s a reader without reading glasses takes a tenth longer per page, in their 50s 15%.

## 1.2.0 - 2026-10-10

### Dan's Vanilla Fixes: load the washer in one click (2026-10-09)

- Right-click a washing machine (or a combo washer/dryer set to wash, or a stacked pair's
  washer): **Put dirty clothes in the washer (N)** walks you over and moves every garment you
  carry that the game calls Dirty or Bloody, bags included, into it with the game's own
  transfer actions. What you are wearing stays on. Greyed with the reason when nothing you
  carry needs it or the machine is running.

### Dan's Vanilla Fixes: a collection checklist (2026-10-09)

Nobody remembers which Carpentry volume is already on the shelf at base. Each character now
keeps a checklist of what they own (design: `plans/collection-checklist.md`).

- **A Collection button** (a clipboard) under the sidebar's buttons opens a window with a tab
  each for Skill Books (a row per skill, a box per volume), Magazines (the ones that teach
  recipes; no seed packets), VHS, Home VHS and CD (by title), Key Rings, Mementos and Tools
  (hand tools, hammers, axes, wrenches and garden tools: about 135), with a search box, a Hide
  collected tick and a count. Items from other mods are listed too.
- **Tick what you have**, in the window or with right-click > Add to collection (Remove from
  collection takes it off). Nothing is ticked for you.
- **Ticking sets the game's Unwanted** on that item for this character: every copy goes grey
  and Take All passes it by. Unticking clears it again, unless it was Unwanted before you
  ticked it. Tapes and CDs are never set Unwanted (it would grey out every tape).
- **The tooltip** of anything on the list says "In your collection" (green) or "Not in your
  collection yet" (grey).
- One checklist per character; a new character starts empty.

### Age, reworked: four decades, felt every day

Age used to show only when something rare happened (blood loss, a concussion, a hangover).
It now sits on the everyday systems. The whole system is written up in `docs/age.md`.

- **In Their 50s (-6)**, a new band: three extra profession levels, and the slowest body.
- **Prices changed sides.** In Their 20s now costs 6 points (it gave 2) and In Their 40s
  gives 2 (it cost 1): youth is the advantage in play, age is the trade for skill.
- **Profession levels** in the main skill are 0 / 0 / 2 / 3 (the 40s had 1; the 30s get
  none, they are the game as it is), and every
  other skill the profession boosts gets one level in the 40s and two in the 50s. Fitness and
  Strength never get age's levels (a Fitness Instructor's main skill is Sprinting). The
  Unemployed get the levels in Maintenance.
- **Every day**, by band (20s / 40s / 50s against the 30s): endurance recovery x1.25 /
  x0.92 / x0.85; Fitness and Strength experience x1.5 / x0.9 / x0.8; scratches, cuts and
  unstitched deep wounds heal x1.5 / x0.9 / x0.8; stiffness fades x1.5 / x0.85 / x0.7;
  night wakes count x0.8 / x1.15 / x1.3 in the sleep score.
- **The 50s on the existing effects:** red cells x0.65, concussion x0.6, hangover x1.5,
  Type 2 resistance +0.2, Brittle x1.5, Arthritis joint factor x1.6, Heart Condition x1.5,
  Handy +1 Carpentry.
- **The mind and the metabolism, by band** (2026-10-07). Any skill under level 3 trains
  x1.2 in the 20s and x0.9 in the 50s; the profession's own skills train x1.1 in the 40s
  and x1.15 in the 50s. Hunger builds x1.15 / x0.95 / x0.9. Caffeine, drink, food sickness
  and daily or course medication clear x1.2 / x0.9 / x0.8: a young body burns through
  everything, an old one holds a dose a fifth longer and a hangover too. Rescue drugs
  (diazepam, painkillers, the inhaler) keep their own half-life.
- **Age pricing.** A trait can cost more or fewer points in a band, drawn beside its cost
  (red dearer, green cheaper) and taken off Points to Spend. Strong and Athletic +2 / +4 in
  the 40s / 50s, Stout +1 / +2, Fit -1 in the 20s then +1 / +2; Fast Learner -1 in the 20s
  and +1 in the 50s; Slow Learner gives a point fewer young or old; Hearty Appetite gives a
  point fewer in the 20s and one more in the 50s. The conditions the 20s band itself softens
  give fewer points young (2026-10-10), so a stack of negatives no longer comes at full price
  while the young body takes the sting out: Multiple Sclerosis and Heart Condition 3 fewer,
  Asthma and Hemophilia 2, Type 2, Anaemic, Smoker and Alcoholic 1. The traits are unchanged
  and existing characters are not affected.
- **Fifteen traits only one age can take.** 20s: Green (-4, the levels only: it does not
  slow experience), Quick Study (+4, now x1.4 under level 5), Bottomless Pit (-6). 40s: Pace Yourself (+2), Settled
  (-4). 40s and 50s: Reading Glasses (-2), Bad Back (-4), Bad Knees (-3), Old Hand (+4),
  Delicate Stomach (-2). 50s: Old Injury (-3), Set in Their Ways (-2), Seen It All (+3),
  Cast Iron (+2), Old Bones Know Rain (+1). Every band has a perk and a flaw of its own. The
  creation screen offers each only to its age and takes it back off if the age changes.
  `docs/age.md` says what each does. New hooks for mod authors: `hungerRise` and `panicRise`
  (stat delta pipelines), `medHalfLife`, `medSideChance`, `medOverAt`, `passOutMinutes`,
  `tripAfterMinutes`, `fearFaint`, `filthStress`, `alcoholDrunk`.
- **Age traits have icons.** The four Age traits are a disc in the
  band's colour with the decade on it; the fifteen age-only traits have a picture each
  (drawn by `DanTraits/tools/make_icons.py`, 18 x 18 like vanilla's).
- **Shorter trait descriptions.** Every trait's creation-screen text is rewritten in
  vanilla's style: two to four short lines, the headline effects only, so the tooltips
  are about vanilla's size. The numbers live in the README and `docs/age.md`.
- **Fixed: In Their 20s did not hide Arthritis or Handy** when the age was picked first
  (the game only checks an exclusion from the side of the trait in the list). The creation
  screen now checks from both sides, for every trait, so one-sided exclusions such as
  Multiple Sclerosis with Athletic and Strong work in either order too.
- **Fixed: a drink showed the Antidepressants moodle** on a character without Major
  Depressive Disorder. Vanilla's drink gives a full antidepressant dose along with the
  beta-blocker and painkiller ones the mod already undoes; the antidepressant timer is now
  put back as well, so only a pill starts it. Antidepressants taken earlier keep working.
- **Everyone carries an Age trait, and the age comes first.** The creation screen offers
  nothing but the four Age traits until one is chosen (In Their 30s at 0 points among
  them); then the rest appears. Next is greyed until then, with the reason as its tooltip
  and on the screen. Random picks an age first. A preset loads as it was and is gated
  after (found in play: loaded onto an empty screen, a preset kept only its age and what
  came after it in the save, because the game read its traits out of the gated lists).
  Changing occupation cannot slip a trait past the gate either (found in play: clicking
  through Blacksmith and Repairman left Blacksmith Knowledge and Inventive on offer, because
  the game puts an old occupation's excluded traits straight back into the lists).
  Age off in the sandbox: no gate and no Age traits. The four exclude each other.
  Default Age now only applies to a character who reaches the world with no Age trait (an
  old save), since nobody picks none any more.
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

### Hemophilia: punishing, survivable

A neck scratch, bandaged at once and the bandage changed whenever it soaked, killed a
hemophiliac in play (2026-10-05). Three causes, three changes.

- **The bleeding clock is held, not floored.** Hemophilia used to keep an uncovered bleed's
  clock at 5 or more, so every bandage change reset the bleed to 5 however far the old
  bandage had run it down. It now holds the clock where it is while the part is uncovered,
  remembers it under the dressing, and a new bandage carries on from there. A wound whose
  clock a bandage ran to nothing stays closed when the bandage comes off; a scratch can
  therefore end, which it could not before (scratches cannot be stitched).
- **A bandage slows a hemophiliac's bleed to a quarter** (x2.5 the normal bandaged rate;
  it was two fifths, x4).
- **A soaked bandage, or one over a shard, is capped at a plain character's open rate**
  (it was capped at the hemophiliac's open rate, x1.5, so a soaked bandage was as bad as
  none).

On the neck (x3) with the clock at 5, per game minute of blood volume: open 1.8% (as before),
clean bandage 0.3% (was 0.48%), soaked 1.2% (was 1.8%). The cost stays at -10.

### Arthritis: warm clothes and two pills take the edge off a flare

A flare is the stiffness floor rising from 12 to 45 on eight joints, attacks up to 15% slower
on top of the usual 15%, slips 4% likelier, and past half a flare the odd slip throwing the
weapon. Three ways to ease it, none of which touches the everyday stiffness:

- **Warm clothes count.** The cold is now read from the joints' own skin temperature (the
  game's thermoregulator, fed by clothing, wind and wet; normal skin is 33 C, and the cold is
  everything at 23) as the mean over the eight joints, so a bare hand counts against a warm
  leg. The air temperature decides only when there is no reading. `artSkin` in the mod data
  is the mean skin temperature, for tuning.
- **Painkillers halve a flare** while they are in the system (the shared medication system's
  level: about two hours a pill, a few with two). The same bottle that eased the ache.
- **Prednisone cuts a flare to a third** while taken, and now says it treats arthritis; its
  wearing-off notice reaches Arthritis characters too. The stronger of the two counts; they
  do not stack.
- A dosed full flare sits exactly at half, and the weapon-drop line is now "past half", so a
  character on painkillers never throws the weapon. `artWeather` and `artRelief` in the mod
  data show the flare before relief and the factor applied.
- A new Arthritis character starts with a bottle of painkillers under Starting Medication.

### Heart Condition, rebuilt: strain, not a dice roll

In play it never fired: nothing could happen until the Endurance moodle showed, beta
blockers started fully built at a quarter, and a heart attack needed you to keep pushing
through the pain. Ten points for nothing. It is now a strain meter, like Asthma's
irritation, and the trait costs 12 (was 10).

- **Strain** builds every minute from endurance spent, sprinting and running, the Endurance
  moodle's depth, panic from half way up, carrying over capacity and cold air; it drains at
  rest. Age, a smoking habit, caffeine, a Run Down body, a stimulant overdose and every
  heart attack survived (a fifth each, for good) make it build faster; beta blockers make it
  build half as fast. The Chest Pain moodle shows it from 0.4 (Heart Working Hard) and 0.75
  (Heart Pounding); at 1 it is chest pain. `hcStrain` in the mod data; `heart` on the console.
- **Chest pain does something:** no running or sprinting (the game's Restricted Movement
  moodle on an attempt) and swings cost half as much again, on top of the pain floor and the
  endurance recovery at a third. Strain falls back to 0.8, not zero.
- **Pushing on** now includes trying to run or sprint and swinging, not only spending at a
  deep moodle. The heart attack chance a minute is unchanged (8%).
- **A week to recover**, in three stages (the new Weak Heart moodle): endurance recovery
  x0.5 / x0.65 / x0.8, effort (swings, sprinting, running) x1.5 / x1.3 / x1.15, melee damage
  x0.5 / x0.65 / x0.8 (through Arthritis's weaken-and-restore, now shared as
  `DanTraits_WeakenWeapon`). It was a day at x0.6 recovery.
- **Scars:** each attack makes strain build a fifth faster for good; a second attack within
  a day drops health to the floor (10) instead of taking 15. Through the week after, pushing
  on through chest pain is x2 / x1.5 / x1.25 as likely to bring another attack, stage by
  stage (found in play: a second attack was slow to come for a heart that had just failed).
- **Beta blockers halve, not quarter**, and a new character starts on them built up half way
  with one bottle (was fully built, two bottles). While built up, endurance comes back a tenth
  slower, for anyone on them.
- **Nitroglycerin** (new item, 25 tablets): the rescue drug, on the medication system. One
  under the tongue ends chest pain within a minute and halves the strain, then half an hour of
  headache. Two within an hour: the blood pressure drops, faints. Where prescriptions are
  (0.9 of an ordinary one's rate), in a found Pill Caddy, and a new Heart Condition character
  starts with a bottle.
- **Not with Athletic** any more (Fit is still allowed): the endurance pool made the strain too
  easy to stay under.
- The strain feeds nothing else yet; `DanTraits_HeartStrain(player)` reads it.

### Bad Knees: rest is posture

- Walking never rests the knees: the load holds. Standing still eases it as before (0.005 a
  minute), sitting on the ground or a chair, or sleeping, twice as fast, and a seat the game
  would also let you sleep on (a sofa, an armchair) three times as fast.
- Stomping counts: 0.02 of load per stomp, on top of running, sprinting and climbing.

### Take A Bath And Shower: supported

Read against its 42.20 files. Its body wash is the same per-part visual Germaphobe reads
(so the relief comes on its own), its wetness cools Multiple Sclerosis as rain does, its
water temperature moves body heat (a hot bath warms an MS character: intended both sides),
and its bath salts are its own features (a calming salt gives the game's beta-blocker
effect, a happy one the antidepressant effect; MDD's regimen zeroes that one each minute).
Two things needed code, both inert without the mod:

- `DanTraits_Bathing.lua`: a bath or shower washes sun block off (its OnBathingEnd event).
- Dan's Vanilla Fixes, `DansVanillaFixes_Bathing.lua`: the hand-wash floors apply to the
  clothes you bathe in (it washed them to spotless, a little each tick): the soap floor
  with soap or shampoo to hand, the no-soap floor without. Only a washing machine gets a
  garment fully clean.

### Bandits supported, NPC hits count (2026-10-10)

Read against Bandits (`Bandits2`, 42.21) and its add-ons (Bandits Creator, Uncensored Bandit
Lines, Improved AI & Radio Expansion; nothing in those touches us), and Project A-Life 1.3.15.
Both new pieces do nothing without the mod they are for.

- **Bandits and the Hallucinations phantom** (`DanTraits_Bandits.lua`): bandits are zombie
  bodies, and Bandits lists every other zombie for its bandits to target and shoot, and wakes
  every plain zombie it updates. The phantom is taken back out of its lists and parked again
  on every update, so no bandit, hostile or friendly, opens fire at something only you can
  see.
- **NPC hits now count for Brittle and Concussion.** The game reports a weapon hit only from
  its own hit code (checked in the game's classes); Bandits and A-Life hurt the player another
  way, which reported nothing, so neither a bandit's bullet to the head nor an A-Life blow
  could concuss you or snap a Brittle limb. Now a bandit hit is reported by its own damage
  (all of it on the head for a head hit), and each A-Life attack, graze or relayed wound by
  what it took off you. Same scales as any weapon hit: 20 off the head is a certain
  concussion. A helmet still helps, except against a bandit head shot, which knocks it off
  first. New shared helpers `DanTraits_OtherHit` / `DanTraits_MeasureHit` (Util),
  `DanTraits_HeadHit` (Concussion) and `DanTraits_BrittleHit` (Brittle).

### Germaphobe: bloody clothes and a bloody weapon count

- Clothes count when bloody, not only when dirty (the game keeps the two flags apart; only
  the dirt one was read).
- The blood on the weapon in either hand counts: the game's 0 to 100 blood level, worth up
  to 0.5 of grime, so a dripping axe alone keeps a Germaphobe over the stress line until it
  is washed.

### Brittle: a bump is not a break

A Brittle character fractured an arm in a crash too small to leave a scratch. The game
reports an 11 km/h bump as 2-3 damage, which cleared Brittle's flat "2 damage or more"
gate, so a tap at a fence rolled the same 20% as a real hit.

- Falls, car crashes and being hit by a car no longer roll on the raw damage. They go out on
  Concussion's new `impact` hook with the concussion chance its scale gives them (crashes by
  the speed the car lost), and Brittle rolls 20% x 2 x that chance: nothing under the floor
  (25 km/h lost, a fall under 3), about 22% for a fence at 50 km/h, 40% for a wall at 70, about
  7% for a second-floor drop. Weapon and zombie hits keep the flat 20% at 2 damage or more.
- The impact judgement runs with Concussion switched off too; only the concussion itself is
  gated. Mod authors: `DanTraits_AddHook("impact", function(_, player, chance, amount, kind))`,
  kind is "fall", "crash" or "hit".

### Fixed: in-game text that said something the code does not

A fact-check of the field guide against the code (plans/field-guide-review-2026-10-08.md)
found the game's own text wrong in places. The Thriving moodle said Fitness and Strength
train twice as fast (x1.5). Hemophilia said only bandages slow a bleed (stitches stop a deep
wound, clotting powder halves one). Gym Regular left out the 20s' head start, Set in Their
Ways left out that Fitness and Strength are exempt, and the Starting Medication tooltip left
out Multiple Sclerosis (baclofen, amantadine) and Arthritis (painkillers). The field guide,
README and docs/age.md got the same pass; docs/age.md wrongly said the band's learning
factors multiply with Quick Study, Old Hand and Set in Their Ways: they add.

### Fixed: car crashes concussed far too easily (2026-10-09)

The game reports a crash (CARCRASHDAMAGE) for running down a zombie or a corpse at speed,
not just for hitting a wall, and the mod judged every such report by the car's top speed over
the last second. So a single zombie at 60 km/h, or a car at 20% condition whose suspension
clipped a corpse, gave a severe concussion and a blackout though the car barely slowed
(reported by kiiri on Steam). A crash is now judged by the speed the car lost: its top speed
in the second before, less the lowest speed read in the quarter second after. The report
comes mid-impact, so the knock waits that quarter second for the reading. A zombie hit that
loses under 25 km/h gives nothing; a fence or wall at 50 km/h, stopped dead, concusses about
as it did (half a chance, moderate), and 70 to 0 is still certain and severe. If no speed can
be read after (thrown clear, the car gone) the top speed alone decides, as before.

### Fixed: Straight Edge smoked off a stove with I Don't Need A Lighter (2026-10-09)

Straight Edge refuses tobacco through the game's eat action, which is how a cigarette is
smoked with a lighter, a match, or (in B42) a lit stove or fire nearby. The mod I Don't Need
A Lighter lights one off a stove, a fire or the car's lighter with timed actions of its own,
and takes a cigarette out of a pack with another, so none of them went through the eat
action and a Straight Edge character could smoke a cigar off the oven. Those actions (and
TrueSmoking's) are now refused the same way when the mod is loaded, with the same notice,
and their Smoke options on the stove and in the inventory ("Smoke (Stove)") are greyed out
with the reason.

### Fixed: Straight Edge's tobacco check errored on non-food items (2026-10-09)

Straight Edge asks of every item whether it holds nicotine, and the inventory's right-click
menu asks that of the items there. For anything not tobacco by name it then read the item's
OnEat, which only food has: on a shirt or a hammer the call was to nil. A pcall caught it, so
the answer was right, but the game logged an error each time, and in debug mode (Break On
Error) each one froze the game. `DanTraits_NicotineOf` now reads OnEat only when the item has
it.

### Fixed: the pause menu was hidden while passed out

The game draws its screen fade after the UI unless told to draw it before, which vanilla
sleep does. The mod's blackouts (concussion knockout, shock, seizures, a diabetic low,
Fear of Blood) did not, so the black covered the pause menu as well and Escape did nothing
you could see. The fade is now drawn before the UI, as in sleep: the menu, the inventory
and the moodles show over the black.

### Fixed: time could not be sped up while passed out

The game drops back to normal speed every frame a player is falling or has just moved, so
the fast-forward buttons would not stay on during a blackout, and a fifteen-minute heart
attack had to be sat through in real time. Now time runs fast on its own once the first
eight real seconds are over (the speed controls' third step), as it does asleep, and goes
back to normal when you come round. A paused game stays paused. Single player.

### Fixed: coming round standing up

After a heart attack the character came round on their feet. You now come round sitting on
the floor where you fell (sat down again a few frames on, in case letting go of the movement
block stood you up) and get up yourself with a movement key. In a vehicle you stay in the seat.

### Fixed: Concussion and Wound Care did not stand down when switched off mid-save

Turning either option off in a running save left its effects on: the Concussion moodle and
tier stayed, and Migraines, Epilepsy and Hallucinations went on reading the concussion;
Wound Care's rough-stitch records kept telling Infection the stitches were rough. Both now
stand down the next minute, as Blood Loss and Infection already did (2026-10-08). The
concussion score and the headache to come are kept and resume if it is switched back on.

### Pill Caddy: the right weight, easier to find, sometimes full

- **Fixed: on the belt, the caddy's tab showed the whole carried weight** ("12.3 / 1").
  Attaching an item to the belt makes the character the parent of the item's container,
  and the game reports a character-parented container's weight as everything the
  character carries (and skips the Organized bonus on it). No vanilla container goes on
  a belt, so only the caddy hit it. Its container is now unparented whenever the inventory
  window refreshes, before its tab is made: the tab reads the caddy's own contents, and
  Organized gives it 2 as intended.
- **Uncommon, not rare:** ten times as likely wherever it was found (0.5 in a bathroom
  cabinet, 3 on a pharmacy shelf: a tenth of a bottle of beta blockers, about a first aid
  kit), and now on the odd zombie's belt.
- **Found caddies may have medication in them:** two rolls over the vanilla pills,
  antibiotics and the mod's bottles (painkillers and vitamins likeliest, the MS pills
  rarest). Bottles come part-used like any looted bottle.

### Sumatriptan, easier to find

- Twice as likely wherever it was found: 0.8 of an ordinary prescription bottle (was 0.4),
  so a little rarer than anticonvulsants or baclofen rather than the rarest pill in the
  mod. In a found Pill Caddy it is as likely as diazepam (2, was 1).

### New item: clotting powder

- **Clotting Powder** (styptic powder, 5 uses): right-click a bleeding part in the health
  panel, dressing off, and pack the wound. A scratch or cut stops bleeding there and then.
  A deep wound's bleeding time is halved and, for 12 game hours, it loses blood at a quarter
  of the rate; it still needs stitches. Dress it after: a bandage over the powder leaves a
  fortieth of the open bleed and soaks that much slower.
- It stings: 20 pain on the part, less half the First Aid level. 100 - 4 x First Aid ticks
  to apply, 5 First Aid xp, like a bandage.
- A shard or bullet still in: the bleeding time stays and the rate is only x0.6.
  Hemophilia: nothing stops, the rate halves.
- The clot ends after 12 hours, when the part stops bleeding, or when the wound tears or
  opens again (wound care). The health panel shows "Packed with clotting powder".
- Fear of Blood: 10% faint when it's done on a bleeding wound, and 25% slower, like a bandage.
- Loot: medicine cabinets 3 (a bandage is 6), first aid kits 6 (disinfectant 4, a bandage 20), doctors' bags,
  ambulances, safehouse medical, army medical, pet shops and pet crates (vets and groomers
  used it), salon counters, a little in bathroom cabinets, hunting lockers and camping gear.
- Mod authors: `DanTraits_BloodPartRate(part, player)` takes the player now; with it the
  rate includes the clot (`DanTraits_ClotFactor`). Called with the part alone it is as before.

### Steady Hands, quicker with a gun

- Reloading and racking run a quarter faster: the game's reload speed (Reloading skill,
  panic, an ammo strap's x1.15, which stacks) is raised by x1.25 after it is worked out.
- A weapon goes to and from the belt a quarter faster (the hotbar's draw, holster, attach
  and detach). Equipping from the inventory is unchanged.
- Not while your hands shake, like the rest of the trait.
- Steady Hands already could not be taken with Dexterous or All Thumbs; the exclusion fix
  above means that now holds whichever is picked first.

### Knowing your insulin (2026-10-08)

A Type 1 character can now work out insulin doses instead of guessing. One pen dose covers about
12.5 g of carbohydrate (`DIA_CARB_MGDL` 4 / `DIA_DOSE_MGDL` 50).

- **First Aid 3-5:** a food's tooltip says whether its sugar hits fast or slowly, and gives a
  wide range of doses (the true number x0.6 rounded down to x1.4 rounded up).
- **First Aid 6-8:** a narrower range (x0.8 to x1.2), and the glucose meter adds how much
  insulin is still working.
- **First Aid 9-10, or the magazine:** the exact doses for this body (fitness and Vitality
  counted), and the meter adds what it takes to bring sugar back to 110: more doses, or grams
  of fast sugar, counting the insulin still working and the food still going in.
- **New item: Living With Type 1** (`DanTraits.InsulinMag`), a magazine. Reading it teaches the
  knowledge flag `DanTraitsInsulinDosing` (as vanilla's Herbalist magazine teaches Herbalist),
  which gives the top tier at any First Aid. Hospital magazine racks, medical offices, waiting
  rooms, pharmacies, bookstore and library medical shelves, rarely a bathroom or bedside.
- **Drinks too:** a bottle, carton or mug with sugar in it shows the same lines for everything
  in it, always fast sugar (as the drink hook counts it). Water, fuel and other sugarless fluids
  show nothing.
- Type 2 is not told doses: its own insulin covers most of a meal.
- The insulin pen's menu offers 3 doses as well as 1, 2, 4 and 8.
- **Too much at once (found in play):** a dosed 110 g chocolate bar still peaked at 505, because
  fast sugar lands inside half an hour and insulin peaks at 75 minutes. The top tier now adds
  "Too much sugar at once: eat half (a third, a quarter, a little) at a time" when a four-hour
  forecast of the dosed food from the current state (sugar, food still going in, insulin on
  board) would pass 350 (`DanTraits_DiaParts`). A loaf of bread, a can of pop and a carton of
  milk eat whole.
- **High blood sugar costs health only after two hours over 350** (`DIA_HIGH_DRAIN_AFTER`,
  counted on `diaKetoHours`, which ebbs at the same pace below). It cost health from the first
  minute, so the spike above took 27; nausea, thirst and mood are unchanged.
- **The glucose meter's tooltip** keeps its last reading, how long ago, and the advice it gave
  then (item mod data `DanTraitsLast`).
- **Fixed (found in play):** the insulin pen counted a full pen as one dose: the uses helper
  read `getCurrentUsesFloat()`, which is how full it is (0 to 1), not a count. It now reads
  `getCurrentUses()`, so 2 to 8 doses can be injected at once. The magazine's knowledge check
  used `isRecipeKnown`, which answers true for any name that is not a real recipe, so everyone
  read as having read it; it now uses `isRecipeActuallyKnown`.
- For mod authors: `DanTraits_DiaKnowledge(player)` (0 to 3), `DanTraits_DiaFoodDoses`,
  `DanTraits_DiaFoodLines`, `DanTraits_DiaMeterAdvice`, `DanTraits_DiaInsulinLeft`; the tooltip
  strip is `client/DanTraits_InsulinInfo.lua` (a wrap of `ISToolTipInv.render`).

### Balance pass (2026-10-07)

Costs below use the script's sign: positive costs points, negative gives them.

- **Old Hand** (still 4, 40s and 50s) now speeds up every skill the occupation boosts by
  x1.25, not just the main skill.
- **Settled gives 4** (was 2, 2026-10-08).
- **In Their 50s gives 6** (was 4). **Bottomless Pit gives 6** (was 3). **Alcoholic gives
  4** (was 2). **Germaphobe gives 4** (was 3). **Fast Recovery** stays at 8 (it was
  briefly 6) and is not taken with Hemophilia.
- **Asthma** (was Brittle Asthma) **gives 10** (was 8). Inhalers turn up half as often
  again, and the new sandbox option Inhaler Loot (percent, default 100) sets the rate on top.
- **Iron Gut costs 4** (vanilla 2) and takes in Iron Stomach: on top of vanilla's lower food
  illness chance, rotten and burnt food hurts the diet half as much and food sickness climbs
  half as fast. Iron Stomach is retired.
- **Thick Skull** (still 2, any age) takes in Bounces Back: faints, knockouts and shock half
  as long, and the day after a sumatriptan too. Bounces Back is retired.
- **Resilient costs 10** (vanilla 4) and can beat the Knox virus: a hidden roll the first
  minute the body is infected (sandbox option Resilient: Knox Survival Chance, default 25%).
  A lucky character gets sick like anyone else, and when the infection has run 40 to 70% of
  its course the fever breaks and it is gone. Every new infection rolls again.
  `DanTraits_Knox.lua`; console `knox [infect|lucky|unlucky|jump <percent>]`.
- **New trait: Grit (+8).** Pain is felt 35% less: each minute Grit holds its own share of
  the body's pain reduction (the same lever drink relief uses) at 35% of the pain that would
  be felt without it, so the moodle and everything pain drives settle a third lower.
  Painkillers are untouched.
- **Jinxed is retired.**
- **A Really Bad Day gives 8** (was 12), and the glass shard in the groin is now an
  infected laceration on the left forearm (already at the local stage: it won't heal, and
  spreads in about a day and a half untreated), "so it's at least survivable" until proper
  balance is worked out. The kit next door is disinfectant and a bandage now (a cut can't be
  stitched). With Wound Infection off the game's own infected wound is used.
- **Keen Cook costs 4** (vanilla 3) and adds a level of Short Blade to vanilla's +2 Cooking
  and +1 Butchering (2026-10-08).
- **Light Eater** is no longer priced by age.
- **Green's** description says it does not change experience gain.

Old saves: a character with a retired trait has it taken off when the save loads, and gets
Iron Gut in place of Iron Stomach and Thick Skull in place of Bounces Back. The retired traits
stay registered (and hidden at creation) so those saves load.

For mod authors: `DanTraits_RETIRED` and `DanTraits_RetireTraits(player)` (DanTraits.lua),
`DanTraits_InfectWound(player, part, level)` (Infection), and a loot spec's `boost` and
`sandbox` fields (Distributions).

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
