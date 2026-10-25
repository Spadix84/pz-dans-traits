# Changelog

All notable changes to the Vitality Project. The Workshop page carries a shorter
version of each entry (`workshop/changelog.txt`); this file has the detail.

## Next (in progress)

### New

- **Strain** (2026-10-24, `DanTraits_Strain.lua` at minute order 45 plus the frame system
  `StrainKnock`, `ISStrainBreakdownAction`; design and tuning in `plans/strain.md` and
  `plans/strain_sim.py`; sandbox `StrainEnabled`, `StrainGain`, `StrainEase`, `StrainXpFloor`,
  `StrainEarlyDays`, `StrainBreakdown`). A slow 0-100 tank (`d.strain`) for everyone. Fills: a
  kill `0.1 x (1 + k/100)`, k the kills since the last night's sleep (`OnZombieDead`,
  `getAttackedBy`; from a vehicle a third, cost and count), a minute with panic over 40 `0.1`, a
  new scratch / laceration / deep wound `1 / 2 / 3` (a per-part scan each minute, so NPC mods'
  wounds count too), knocked down `1.5`, a bite `50`, overall health under 25 `50` once a day,
  an hour of full fever `0.25`, sepsis `0.5`, full food sickness `0.15`, full pain `0.15`, an
  Alcoholic sober `0.15 / 0.3 / 0.5` an hour by stage, a Smoker `0.1` an hour at full
  withdrawal, a hangover starting `2`. Drains: an hour awake two hours after the last fight
  `0.375` (anywhere), a night `4` in a bed or `2` rough x Vitality's quality (the `nightScored`
  hook; naps nothing; with Vitality off a sleep of 3 hours+ counts by its length), comforts
  `DanTraits_StrainComfort` once a day in full, the second half, then nothing, the same one
  within half an hour ignored, x1.5 at home (x2 Homebody), the fourth different one in a day
  makes the day's x1.25: a wash (`ISWashYourself`) or Take A Bath And Shower's bath `2`, into
  fresh clothes (Laundry's moodle going fresh) `2`, a Good Meal by tier `2 / 3 / 4`, an hour of
  reading `2`, Pumped starting `2`; Drunk 2+ `2` an hour, Drunk 1 `0.75`, up to `8` a day; a
  cigarette `0.75`, up to `3`; an Alcoholic's drink and a Smoker's cigarette a quarter. A fever
  halves calm hours and sleep. The first week x0.5; Desensitized x0.6 on combat strain.
  Tiers: At Ease (under 10), Frayed (25), Worn Down (50, unhappiness floor 15), Burnt Out (75,
  30), Breaking Point (100). Experience (`Events.AddXP`, taken back through
  `DanTraits_AgeXpAdjust`, Age's own top-ups skipped): weapon skills, Aiming, Reloading,
  Strength and Fitness x1.1 at ease, x1 to 25, x0.75 at 50, x0.4 at 75, x0.15 at 100 (never
  under `StrainXpFloor`); other skills half the penalty, only over 50. Breaking Point: strain
  holds at 100 (nothing eases it) until ten minutes without a fight and no zombie within 12
  tiles, then `ISStrainBreakdownAction` (sit down, about 30 seconds, a line said, unhappiness
  floor 50) ends with strain at 60; walking or a zombie within 4 tiles stops it and it comes
  again. Moodle: Strain. Health panel: a Strain section (the tier and the last hour's way,
  never the number). Console: `strain`, `strain set <n>`, `strain kill [n]`,
  `strain comfort <kind>`. API: `DanTraits_StrainAdd`, `DanTraits_StrainEase`,
  `DanTraits_StrainComfort`, `DanTraits_StrainLevel`, `DanTraits_StrainTier`,
  `DanTraits_StrainXpMult`.
- **Four strain traits:** Level Headed (+8, strain gained x0.5), High Strung (-6, x1.5),
  Unwinds Easily (+4, every drain x1.5), Can't Switch Off (-4, every drain x0.67, the variety
  bonus needs five). Each pair mutually exclusive.
- **Adrenaline auto-injector** (2026-10-24, `DanTraits_Adrenaline.lua` at minute order 35,
  item `DanTraits.AdrenalineInjector`, one use, its own "Inject adrenaline" option through
  `ISVitalityPillAction`, 40 ticks). For anyone. The rush, 120 minutes: tiredness taken off and
  held there (`adHold`), endurance filled, endurance recovery x1.5, stress floor 0.3 (ramp 0.02),
  `swingDrop` +3%, Heart Condition strain x3 (`HC_ADRENALINE`, read through
  `DanTraits_AdrenalineRush`). The heart: chance `min(1, 0.25 x shots in the last 24 hours)`,
  rolled at the jab and landing 5 to 40 minutes in (`adAttackIn`) as Heart Condition's own
  attack, now `DanTraits_HeartAttack` for anyone (the week of recovery already ran without the
  trait). Beta blockers, by how built up: the tiredness taken off, the missing endurance given
  back and the risk all x(1 - 0.5 x built). The crash: what the shot took off is owed
  (`adDebt`); at the end of the rush it comes back over 30 minutes as `debt x 1.25 + 0.15`
  (capped at 1), then 6 hours Crashing (endurance recovery x0.5, unhappiness floor 20, a pain
  floor of 10, `swingDrop` +3% for the first hour), 4x as fast asleep. A shot during the crash
  owes again what had still to come back. Moodle: Adrenaline (good: Adrenaline Rush, Wearing Off
  in the last 20 minutes; bad: Crashing while it comes back and shakes, then Comedown). Loot:
  rare, likeliest in an ambulance (3) or a doctor's bag (1.5), 0.1 in a bathroom cabinet, 0.01
  in a handbag. Console: `adrenaline`, `adrenaline shot | crash | clear`. Tests: test_adrenaline.

### Changed

- Alcoholic gives 6 points (was 4) and Smoker 5 (was 4): both now add strain while dry and
  ease only a quarter as much with a drink or a cigarette.
- **Cyclobenzaprine folded into baclofen** (2026-10-24): two muscle relaxants in the loot pool
  was one too many. Baclofen is now also the relaxant for anyone (`DanTraits_Relaxant.lua`
  reads `baclofen`'s cover): one covers about 12 hours (its half-life) with the same relief
  (stiffness fades x2, a pull's pain and held stiffness x0.5, a Bad Back x0.5 / x0.65 thrown
  out), baclofen's own drowsiness (0.0001 a minute, was 0.0003) and overdose (limp, barely
  awake; no racing heart), the drink drowsiness as before. Training on it (x0.85 Fitness and
  Strength experience, a pull x1.5 as likely) only for those without MS, whose daily pill it
  is. The lapse notice (`rxOn`) only for those without MS (MS has its own). Cyclobenzaprine no
  longer spawns (baclofen's commonness 1 to 1.3, its pill-caddy weight 1 to 2); the item stays
  for bottles already in a save and its tablet is a dose of baclofen; a save's
  `meds.cyclobenzaprine` level carries across to baclofen.

## 1.4.0 - 2026-10-24

### New

- **Fitness overhaul** (`DanTraits_FitnessData.lua`, `DanTraits_Fitness.lua` at minute order 40,
  `DanTraits_FitnessActions.lua`, `ISDanTraitsStretchAction`, `client/DanTraits_FitnessUI.lua`;
  design and as-built notes in `plans/fitness-overhaul.md`; sandbox `FitnessEnabled`,
  `FitnessStrain`). Four groups (arms, chest, core, legs). A training minute adds `1/30` load x the
  exercise's share x intensity (1.3 for burpees and weights); load falls `1/36` an hour, x2 asleep,
  x2 stretching or x1.25 Loosened Up, x1.15 on plan, x1.1 with Limber, then the new
  `fitnessRecovery` hook (Age's stiffness factor by band, Vitality `1 + 0.25e`). States: Ready
  (under 0.15, trained 20 to 96 h ago), Rested, Recovering (0.15+), Sore (0.6+), Overworked (1+),
  Pulled. A rep's XP (marked by wrapping `ISFitnessAction:exeLooped`) is scaled by the lowest
  group factor from the load it carried into the session (x1.25 Ready, x0.6 Sore, x0.3
  Overworked; x0.5 past 1.5 load in a session), x0.7 Overtrained, x1.15 on plan, x the improvised
  weight (kilos held / 6 or 5, 0.5 to 1.2), x1.15 within 3 tiles of a weight bench
  (`CustomName = Fitness_Contraption`), then the `fitnessXp` hook; applied through
  `DanTraits_AgeXpAdjust`, skipping Age's own top-ups. Pulled muscle: a minute's risk `0.02 x
  (carried - 0.6) / 0.4 + 0.01 x (session - 1.5) / 0.5`, x1.5 improvised, x0.5 at a bench,
  `fitnessStrain` hook; 36 h (x2 asleep), pain floor 25, the part's stiffness held at 30, the
  group refused in the window and a running exercise stopped. Pumped: 15 training minutes in a
  session (gaps of 10 or less join, hard work aside), 3 h of stress -0.0004, unhappiness -0.05,
  boredom -0.1 a minute, Depression's exercise relief at least 0.8 (new `mddExercise` hook).
  Loosened Up: 10 stretching minutes, 4 h, Arthritis's joint factor x0.7, stiffness fades x2
  stretching / x1.25 after (new `stiffFade` hook in Age's pacing). Overtrained: seven days in a
  row with 20 hard minutes, until two without; XP x0.7, nights -0.05, `enduranceRegen` x0.9.
- **Exercises:** added to `FitnessExercises.exercisesType` at load: Improvised Curl (barbell curl
  animation, two hands: log, propane tank, full bucket, sandbag, gravel bag, dirt bag, car
  batteries, tyre), One-Arm Curl and Overhead Press (biceps curl and dumbbell press animations:
  car batteries, paint cans, vinegar jug, flour), the heaviest carried at 1.5 kg or more;
  Stretching (`ISDanTraitsStretchAction`, the `TiredStretch` ext animation every 6 s, standing or
  sat); and three hidden ones counted per minute with their own regularity (2, 2 and 1
  `incRegularity` steps): jogging (running, not sprinting), loaded carry (heavy load 1+, moving),
  hard work (metabolic rate 5+). The window borrows animations by swapping `ExerciseType` at
  `start` and the type at `serverStart`. Right-click a weight bench or treadmill: Work Out.
- **Training plans:** Full Body (everyone), Upper/Lower, Push Pull Legs, First Five Miles,
  Strongman, Active Recovery; seven-day cycles of targets (20 minutes of a kind; stretching 15;
  rest under 20 hard minutes). On plan (every target day of the last seven done): XP and recovery
  x1.15, Vitality's exercise score +0.1 (new `exerciseScore` hook). Fitness Instructors know them
  all. The window shows the groups, the plan drop-down, today's target, seven days and bonuses.
- **Fitness magazines:** Iron Monthly: Upper/Lower and Push Pull Legs (Strength +10% each),
  Pavement: First Five Miles (Fitness +10%), Strongman Quarterly (both +5%), Limber (Fitness +10%,
  recovery +10%); `LearnedRecipes` knowledge flags read with `isRecipeActuallyKnown`; the bonus is
  on all Fitness or Strength XP. Loot, each: gym lockers 2, fitness trainer 3, boxing and pool
  lockers 1, sports closets and crates 1, school gym 0.5, library sports 1, magazine racks and
  crates 0.5, library magazines 0.3, living-room shelves 0.02.
- **Cooking overhaul** (`DanTraits_Cooking.lua` at minute order 40, `client/DanTraits_CookingClient.lua`;
  design and the vanilla facts it rests on in `plans/cooking-overhaul.md`; sandbox `CookingEnabled`).
  A proper meal is 300 kcal of one dish tier (bites of a dish within an hour add up, through the
  `eat` hook). Tier: Home-cooked (an evolved dish with 2+ ingredients; never-cooked dishes stop
  here), Hearty (cooked, 3+, Cooking 3), Chef's (cooked, 4+ or 3 and a spice, Cooking 7); none for
  burnt, rotten, raw-but-cookable or under 2 ingredients; stale drops a tier. The cook's level is
  stamped on the dish (`dtCook` mod data, wrapping `ISAddItemInRecipe:complete`), else the
  eater's. Good Meal afterglow: unhappiness 6 / 10 / 15 and stress 0.03 / 0.05 / 0.08, plus 25 /
  50 / 75% of the dish's own drop, paid evenly over 3 / 4 / 5 h awake; x1.25 at home (x1.5
  Homebody), x0.5 the same full type within 24 h, none for a Sensory Issues disliked texture;
  replaces a running glow only if it pays more than is left; holds Depression's `mddFoodTimer`.
  Fuelled 4 h: Fitness and Strength XP +5 / 10 / 15% (new `fitnessXpAll` hook in Fitness's
  experience handler). By the dish's protein, carbs and fat as calories against 25 / 50 / 40%:
  Recovering 6 h (`fitnessRecovery` x1.1 / 1.2 / 1.3), Energised 3 h (5 / 10 / 15% of the endurance
  spent each minute given back, `enduranceRegen` told), Full 4 h (`hungerRise` x0.95 / 0.9 /
  0.85). Side stitch: exercising at Food Eaten 3 (2% a minute) or 4 (5%): lower torso stiffness 25,
  an hour's cooldown. Diet goals (fitness window): Bulk, Strength XP +10% while `isIncWeight`;
  Cut, Fitness XP +10% while `isDecWeight` and a quarter more of the game's loss. Fuelled with 20
  hard minutes today, weight under 78 or over 82 drifts 0.2 kg a day toward it. New moodle Good
  Meal (Good Meal, Great Meal; bad side Side Stitch); a tooltip line on dishes.
- **Fitness experience cap:** the product of Fitness's factors on one gain (training factor,
  magazines, Natural Runner, `fitnessXpAll`) is capped at x2 before the `FitnessXp` sandbox pace.
- New moodles: Sore Muscles (Sore, Overworked, Pulled Muscle), Pumped (Loosened Up, Pumped; bad
  side Restless), Overtrained.
- **Fitness traits** (`DanTraits_Fitness.lua`, constants in its `TR` table): Well Conditioned (4:
  recovery x1.5, Ready from 14 h, strain heals x2; not with Lingering Soreness), Natural Runner (3:
  a jog minute logs and pumps as 2, legs load x0.5, Fitness XP x1.25 while running or sprinting
  outside a rep), Weightlifter (4: weights and improvised XP x1.2, no x1.5 improvised strain),
  Regimented (3: plan bonus x2, one missed target day in seven forgiven), Lingering Soreness (-3:
  recovery x0.6, Ready from 30 h), Injury Prone (-3: strain risk x2, 54 h), Exercise Averse (-3:
  never Pumped, +0.15 boredom and +0.05 unhappiness a training minute, plan bonus x0.5; not with
  Endorphin Junkie), Inflexible (-2: stretching boosts keep half, `stiffFade` x0.7 otherwise,
  `arthritisJoint` x1.1, x0.85 loosened), Endorphin Junkie (1: Pumped 360 min, lift x2; 48 h
  without, Restless: boredom floor 30, stress floor 0.15). Trait icons in `make_icons.py`.
- **Links:** Diabetes (both types) burns 1 mg/dL a minute of a workout instead of running's 0.5,
  then 0.2 x `DanTraits_FitAfterglow` (the Pumped share left); Type 2 resistance -0.1 x the
  afterglow. Asthma: a `breathless` exercise (burpees) builds as running does. Heart: `HC_LIFT`
  0.02 a minute of a heavy (intensity over 1) or improvised exercise. Brittle: 20 minutes today on
  exercises loading the legs at half a share or more (`DanTraits_FitLegMinutes`) puts 0.02 a day
  back. Bad Back: an improvised two-handed curl minute adds 0.008 through
  `DanTraits_BadBackStrain`, and core strain risk x1.5. Gym Regular knows Upper/Lower. MS left out
  on purpose.
- **Fitness, round two (2026-10-18, after the first play):** the window's section is now one child
  panel (`DanTraitsFitnessSection`), so it shows in replacement windows too (Neat Rocco's
  `NR_FitnessPanel` overrides `render` and restacks unknown children at the bottom); the improvised
  exercises are named for the stand-in carried by setting `exeData.name` when the list is built
  (Neat Rocco lists by it): `%1 Curls`, `%1 One-Arm Curls`, `%1 Overhead Press`; a hint says more
  plans come from magazines. Stretching has a progress bar (`setJobDelta` from the calendar).
  Overtraining's hard day is `40 + 6 x (Fitness + Strength)` minutes (was 20). Powerlifter is
  now Weightlifter, Disciplined now Regimented (Lifestyle: Hobbies has a Disciplined).
- **Arthritis and MS:** `conditionFactor` in Fitness: `1 - 0.2 x (Fitness + Strength) / 20 x
  kept` (kept: Vitality's exercise score or the regularity, over 0.5) x 0.9 Loosened Up (0.95
  Inflexible), on Arthritis's `arthritisJoint` (was x0.7 Loosened Up) and a new `msRelief` hook
  in MS (0.5..1) on its hand and leg stiffness, heat pain, the old fatigue drip and the spoons
  spent. Arthritis -12 (was -10), now not with Athletic, Fit, Strong or Stout; MS -16 (was -15),
  now also not with Fit or Stout.
- **Bad Back -8 (was -5):** pain 60 at a full load (was 45), stiffness 30 on the lower back and 25
  on the thighs x the load; thrown out past half a load under Heavy Load 2+ or a lift
  (`DanTraits_BadBackStrain` this minute), `0.004 x (load - 0.5) / 0.5` a minute, x2 for seven
  days after the last: 240 minutes of pain 85, stiffness 70 back / 40 thighs, no running or
  sprinting (frame). Core conditioning from `DanTraits_FitWeekMinutes(player, "core")` / 90: the
  load x (1 - 0.4c), a throw-out x (1 - 0.5c), nothing in the week after a throw-out. New moodle
  Back Strain (1 aching, 2 bad, 3 thrown out).
- **Sets in reps:** muscle load is counted per rep (`DanTraits_FitOnRep`, called from the
  `exeLooped` wrap after the game's rep; `FIT_REP_EFFORT` 0.5 minutes of effort a rep, so a set of
  50 is 25 effort minutes and 0.83 load) instead of per minute, which had loaded slow exercises
  (squats, about an in-game hour for 50) twice as hard for the same experience. Jogging,
  carrying, hard work and stretching stay per minute. The window's time box is a rep count
  (`IGUI_FitnessTime` overridden to "Reps (stretching: minutes)"; the count rides in
  `DanTraits_FitPendingReps`, the game's clock gets 240 minutes, the set ends on its last rep, and
  the bar is `setJobDelta(repnb / dtReps)`). Plan targets for the strength days show as reps (two
  to an effort minute: 40). New sandbox option `FitnessXp` (10 to 500, default 100): every
  Fitness and Strength gain x it/100.
- **Plans made plain:** `onPlan` now needs a target day done in the last seven and no unforgiven
  miss in the last `FIT_MISS_DAYS` (2) days, and returns the day missed and the day the bonus is
  back (`ftMissDay`, `ftBackDay`); the window shows on or off plan and why under today's target,
  and `UI_DanTraits_FitOnPlanNow` / `FitOffPlanNow` notices mark the change.
- **ADHD (-2)** (`DanTraits_ADHD.lua`, minute order 40, test_adhd.lua): registers the minute
  delta hook `boredomRise` (CharacterStat.BOREDOM) and returns each rise x1.5; falls untouched.
  `ISReadABook` at the head of the queue with a skill book (`SkillBook[item:getSkillTrained()]`)
  adds 0.3 boredom a minute (counted x1.5 by the next minute's pipeline) with one "so dull" notice
  per book id. A started action not in the exempt list (walk, path-find, vehicle enter/exit/seat,
  climb window, door, rest, sit, sensory stim) stops by `forceStop` (vanilla `stop` resets the
  queue) at `1/150` a minute x (1 + boredom 0..1), not with any Panic moodle, then not for 60
  game minutes (`adhdNext`). Hyperfocus: a minute with a started, non-exempt, non-skill-book
  action adds 1 to `adhdFocus`; at 20 (minus 5 x coffee) `adhdHyper`: `ISBaseTimedAction:adjustMaxTime`
  x0.85, `Events.AddXP` +10% through `DanTraits_AgeXpAdjust`, the boredom rise returns 0 and
  boredom eases 0.1 a minute (`DanTraits_DeltaRemember` after, so a wiped rise does not undo it),
  no drifting, no skill-book boredom; 3 minutes with an empty queue (`adhdIdle`; exempt actions
  neither build nor count as idle), any Panic moodle or sleep end it, drifting off resets the
  build. Moodle Hyperfocus (-1 from half the build, -2 locked in). Coffee: `dose()` in
  `DanTraits_Caffeine.lua` now calls `DanTraits_AdhdOnCaffeine` for anyone; `adhdCaf` halves every
  5 h, effect = level / 100: boredom multiplier 1.5 -> 1.25, drift x(1 - 0.5e), focus 5e minutes
  sooner. Novelty: the building footprint (`DanTraits_HomePlaceOf`) not in `adhdSeen` takes 15
  boredom and 3 unhappiness off, at most every 30 minutes (the spawn building and buildings found
  in the gap are not marked; the list restarts past 3000). Home's boredom relief now runs through
  a `homeBoredom` hook; ADHD halves it. Exclusive with Homebody. Console `adhd`, `adhd distract`,
  `adhd focus`. Icons in `make_icons.py` (trait, `ui/Hyperfocus`).
- **Sensory Issues (-8)** (`DanTraits_Sensory.lua`, `ISSensoryStimAction`,
  `client/DanTraits_SensoryClient.lua`, minute order 41): one sensory load (`siLoad`, 0..100) fed
  by six channels, each 0..1 and weighted (touch 1, grime 1, sound 1.5, crowd 2, light 0.7,
  smell 1). Touch: wool and knit garments 0.5 each, denim 0.15, tight headgear (fullhat, mask,
  maskeyes, maskfull, scba locations, helmets) 0.3, Laundry's `L.itch` count x0.2, wetness over
  30%. Grime: `DanTraits_GermGrime` from 0.1 to 0.6. Sound: the loudest `OnWorldSound` heard
  (radius 12 or more, full at 60, halved by distance), fading x0.5 a minute, plus Tinnitus ringing
  0.5, a running engine 0.3, `getIsThunderStorming` 0.3; ears: Deaf 0, Hard of Hearing 0.5, Keen
  Hearing 1.25, `Hat_EarMuffs` x0.4, `Hat_EarMuff_Protectors` x0.2 (were x0.6 and x0.3 until
  2026-10-19), `DanTraits.NCHeadphones` x0. Crowd: `getNumVisibleZombies`
  over one, full at ten, plus 0.15 per `getNumVeryCloseZombies`. Light: `DanTraits_InBrightLight`
  0.6, x0.4 with shades. Smell: corpses within 4 tiles, full at 6. The load closes a tenth of the
  gap to 100 x input/1.5 each minute when climbing and drains 0.75 a minute x calm (1.5 until 2026-10-20; indoors and
  clear 1.5, home 1.5, dark 1.3, sitting 1.2, asleep 4; asleep only touch counts, at half),
  blocked at input 1. Tiers 30/60/90 (an overload lasts until under 50, 70 until 2026-10-20): stress floors
  0.25/0.5/0.75 (ramp 0.02), unhappiness 25/40, `enduranceRegen` x0.8/0.6; an overload rolls
  meltdown (panic 40, anger 0.5) or shutdown (stamina x0.5, boredom and unhappiness 50). Input
  adds 0.0015 stress a minute per unit. Food: two safe and two disliked of eight texture groups
  (name words, food types and cancelling words, checked against the game's 722 foods; three
  ingredients or more is mixed; the first safe group is crunchy, mushy, plain or sweet); safe -20
  load, -10 unhappiness; disliked +10 load, +15 unhappiness, +0.1 stress and a 50% gag at 35%
  through (`ISEatFoodAction:update` wrap, `forceStop`); overloaded, `refuseFood` turns away all
  but safe food (food only: `instanceof(item, "Food")` first, since the hook runs on every right-clicked
  item and a food method called on clothing is logged by B42 even inside pcall); a neither food eaten three whole portions under the first tier is learned
  (`siLearned`). Stim action on fidget toys and plushes (walking allowed, running or aiming stops it): -30 load, -0.1 stress, half within an
  hour. Hooks: Migraine `overload` trigger (1.5 at full), `spoonSpend` x(1 + 0.5 load/100),
  `nightQuality` x0.85 when asleep at 60 or more, a garment tooltip line in `client/DanTraits_SensoryClient.lua` (`DanTraits_SensoryGarmentTip`: soft in green for
  cotton or a soft name, scratchy, rough or tight in red; independent of laundry). **Harsher (2026-10-20, the user: it reaches overwhelm fast enough but does not bite):** timed actions
  started at Overwhelmed x1.2 and overloaded x1.4 (`ISBaseTimedAction.adjustMaxTime`, beside ADHD's wrap); a
  meltdown throws down what is in the hands 10% a minute (`DanTraits_DropHeld`) and shouts 20% a minute (Say +
  `addSound` radius 20); a shutdown blocks sprinting (frame driver SensoryShutdown, the moodle on an
  attempt); every overload since the last sleep of 240 minutes in one go makes the input for 100 x0.85 (up to
  three, `siToll`), with notices for worn thin and slept off. The starting outfit counts as washed. **Take A Bath And Shower** (`DanTraits_Bathing.lua` now
  exports `DanTraits_BathingMode(player)`, "BATH"/"SHOWER" while its `tabas_IsBathing` flag is up, the
  mode from `OnBathingStart`, and `DanTraits_BathingWet(player)`, true until `tabas_HasBathingWet` clears):
  the drain x3 in a bath and x2 in a shower (`CALM_BATH`, `CALM_SHOWER`), and the bath's wetness is not a
  touch trigger. **Noise-cancelling headphones** (`DanTraits.NCHeadphones`,
  clothing on `base:hat`, the ear protectors' model): for anyone, worn they grant the game's Deaf trait
  (its audio reads it) on the minute and on `OnClothingUpdated`, taken back off when removed (`hpDeaf`
  marks ours; a deaf character is left alone); loot ElectronicStoreMusic 4, ArmyStorageElectronics 3,
  UniversityDesk_Therapy 2, a few others; icon in `make_icons.py`. Moodle SensoryLoad (level 3 meltdown, 4 shutdown),
  icons in `make_icons.py`. test_sensory.lua.

- **Dryer sheets** (`DanTraits.DryerSheets`, `DanTraits_Laundry.lua`, `ISLaundryAction` kind
  `sheet`, `client/DanTraits_LaundryWasher.lua`): a box of 20 (drainable, the tissue box model;
  laundry rooms 10, Gigamart cleaning 6, other cleaning shelves). Right-click a dryer (a combo set
  to dry, a stacked pair's dryer) with the box carried: Add a dryer sheet (N left), greyed while it
  runs or with a sheet in. The sheet is a flag on the machine's mod data (`dtlSheet`). Vanilla's
  dryer (`ClothingDryerLogic`, 42.21) runs 90 minutes and locks its drum, so the watch works like
  the washers': switched on through `ISToggleClothingDryer` / `ISToggleComboWasherDryer` (or seen
  running within 4 tiles, for a stacked pair's Java switch) a sheeted dryer joins `lnDryers`; each
  ten-minute look scents every garment in it under 10% wet (`ds`, the wash count it belongs to,
  counting a machine wash still pending), and once idle or switched off a last look does the same
  and spends the sheet. A scented garment gathers odour at half the rate (`SHEET_ODOUR`) until its
  next wash. Unworn clothes never gathered odour, so they stay fresh until worn either way.
  Sensitive Skin counts a scented garment against the skin as itchy; tooltips say "Dryer sheet:
  stays fresh longer" (and "Dryer-sheet perfume: it itches" for Sensitive Skin). Icon in
  `make_icons.py`; tests in test_laundry 24, test_laundryaction 10, test_laundrytraits 7,
  test_washer 4.
- **Sleeping in clothes** (`DanTraits_Sleep.lua`, sandbox `SleepClothesEnabled`). Each minute
  asleep, worn items are costed by body location (`CL_SLOTS`) and summed, capped at 1. Free
  (unlisted): underwear, socks, T-shirt, tank top, short-sleeved shirt, shorts, short pants, bath
  robe, jewellery, make-up, bandages. Warm slots (shirt 0.15, pants 0.25, sweater 0.2, jacket 0.3,
  bulky/down jacket 0.45-0.5, boilersuit 0.4, hats, gloves...) are scaled by warmth `(air - 10) /
  10` clamped 0..1, with `getAirTemperatureForCharacter(player, false)`, and are free at any
  Hypothermia moodle level; gear (shoes 0.25, backpack 0.3, webbing 0.2, armour pieces, masks,
  holsters, belts) always counts. Tiredness drains `x (1 - 0.12 x cost)` on top of the light
  factor, and the night's score loses `0.1 x` the average cost (in the same `nightQuality` hook
  as light, `d.slLastNightClothes`); Deep Sleeper pays half (`DS_REST_BRIGHT`). Waking after 60+
  minutes asleep at an average of 0.25+ shows "Slept badly in your clothes". Harness worn items
  take an optional `loc`; tests in test_sleep 12.
- **Undress and Sleep** (`client/DanTraits_SleepMenu.lua`, `DanTraits_SleepUndressList` in
  `DanTraits_Sleep.lua`, `ISDanTraitsBedtimeAction`). Inserted right after the game's own Sleep
  option (built in Java by `ISWorldObjectContextMenuLogic`; found by `onSelect ==
  ISWorldObjectContextMenu.onSleep` or by name, submenus searched 3 deep), so beds, sofas and the
  ground all get it. Sat or lying on the furniture, the game builds Sleep with `addGetUpOption`
  (target = the menu, `param1` = onSleep, `param2` = the bed): the bed is read from there and an
  `ISWaitWhileGettingUp` goes first (taking the menu for the bed threw in `onConfirmSleep`, found
  in play 2026-10-23); a target that is not an `IsoObject` leaves the option out. It is
  left out while that option is greyed (not tired, too early) or
  `SleepClothesEnabled` is off, greyed with a reason when nothing needs to come off. Takes off every
  worn item in `CL_SLOTS`, warm slots only at warmth 0.5+ (15C and up, never with the Cold moodle);
  worn `InventoryContainer`s and bags in either hand (a two-handed one once) are dropped. Queue:
  `luautils.walkAdj` to the bed (skipped on the ground or already sat on it), the game's
  `ISInventoryPaneContextMenu.unequipItem` per garment and `dropItem` per bag (to the floor), then
  a one-tick client action that calls `onConfirmSleep` with YES, so the game's sprite-grid pathing,
  zombie, pain and panic checks still run and the confirm dialog is skipped. On waking (minute
  order 90), the garments it took off (`d.slUndressed`, item IDs recorded when the bedtime action
  runs, so ones the player put back on by hand are left out) go back on through
  `ISInventoryPaneContextMenu.wearItem`, if still carried (`getItemWithIDRecursiv`) and not worn;
  the same once a refused sleep leaves the player idle and never asleep for 2 minutes. Bags stay
  on the floor. Tests in test_sleepmenu.
- **Hot water bottle** (`DanTraits_HotWaterBottle.lua` at minute order 20, `ISDanTraitsHeatAction`,
  `client/DanTraits_HotWaterBottleClient.lua`). Vanilla `Base.HotWaterBottle` (1 L, cookable,
  microwave-safe; loot's "HotWaterBottleEmpty" spawns it empty) counts as hot over `itemHeat` 1.6
  but cools to the room in about a minute of real time, so the bottle keeps its own warmth in item
  mod data (`dtHwbLeft` hours, `dtHwbAt`): stamped full (4) whenever seen over 1.6 with fluid in it,
  carried or in the cell's process list (stoves, microwaves, fires; empty on an MP client), and
  counted down lazily at 1 an hour, 2/3 asleep, 2 outdoors below 0C. Hot above 3, Warm above 1,
  then Tepid; emptied, it is forgotten. Held on a group (the action, 30 calendar minutes, Hot or
  Warm, carried): the new `fitnessGroupRecovery` hook in `recover()` gives that group x2 / x1.5;
  1 / 0.6 stiffness off each of its parts a minute (before Age at 23.5, which paces the fall); a
  pulled muscle there loses 4 / 2 minutes an extra minute (two hours a Hot session); on the core
  `DanTraits_BadBackEase` (new, AgeTraits) takes 0.004 / 0.0024 off the back's load, or runs a
  thrown-out back's minutes 1 / 0.5 faster; `arthritisJoint` x0.8 / x0.9, and x0.9 for an hour
  after. Asleep with a Hot or Warm bottle carried: every group x1.25 / x1.15, and minutes asleep
  at air 10C or below (or the Cold moodle) lift the night's score by up to 0.05 at four hours
  (`nightQuality`). The menu lists each group with its state; greyed with how to heat it when
  cold or empty. Tooltip line via `DanShared_Tooltip`. Tests in test_hotwaterbottle 10,
  test_agetraits (Bad Back ease).
- **Cyclobenzaprine** (`DanTraits_Relaxant.lua` at minute order 60, the `cyclobenzaprine`
  rescue drug in `DanTraits_Meds.lua`, item in `DanTraits.txt`, icon in `make_icons.py`). The
  usual 1993 prescription muscle relaxant (Flexeril). 20 tablets (UseDelta 0.05), taken with
  vanilla's Take Pills like sumatriptan; loot `prescription(..., 0.3)`, Pill Caddy contents
  weight 1, spawns 30-100% full. Half-life 8 h, covered at 0.5, over at 2.5 (overH 6: fatigue
  0.0015, faint 0.003, heart strain); taking: fatigue 0.0003 awake, thirst 0.0001; side: fatigue
  0.0006 for 6 h; lapse notice for anyone. Covered: `stiffFade` x2; new `strainRelief` hook in
  Fitness `strainMinute` (the pull's pain floor and held stiffness x0.5); new `backRelief` hook
  in AgeTraits `updateBadBack` (pain and stiffness x0.5, x0.65 thrown out; load and throw-out
  chance unchanged); `fitnessXp` x0.85, `fitnessStrain` x1.5; Drunk moodle at any level adds
  0.0008 fatigue a minute awake. Tests in test_relaxant 6, test_agetraits (backRelief).
- **Animal insulin** (`DanTraits_Diabetes.lua`, items and recipes in `DanTraits.txt`).
  `DanTraits_AddPancreasParts` inserts `{ item, nb = 1 }` into the vanilla
  `AnimalPartsDefinitions.animals[kind].parts` lists (shared per kind, so once per table, at load
  and again on `OnGameBoot`): `DanTraits.Pancreas` for adult cattle, calves, adult pigs, sheep and
  deer, `DanTraits.PancreasSmall` for piglets, lambs, fawns, rabbits and raccoons; none for rats,
  mice and birds. Both are Food after `Smallanimalmeat` (2 days fresh, 4 to rotten). The
  `DanTraitsExtractInsulin` / `DanTraitsExtractInsulinSmall` craftRecipes (`SliceMeat_Surface`,
  400, First Aid 2, `NeedToBeLearn`, `AutoLearnAny = Doctor:8`) take a sharp knife (kept), one
  Pancreas or four small ones (`IsUncookedFoodItem;ItemCount`; rotten and frozen refused by
  default), one use of `base:vinegar`, a `Base.RippedSheets` and 0.2 l of
  RubbingAlcohol/Vodka/Whiskey, and make one `DanTraits.InsulinVial` (40 doses, the pen's
  insulin). Taught by the new magazine `DanTraits.InsulinPapersMag` "The Insulin Papers". A vial
  injects through the same `ISDiabetesAction` as a pen, valid only while a
  `DanTraits.InsulinSyringe` is carried (`DanTraits_InsulinSyringeFor`, bags included; the menu
  greys with `Tooltip_DanTraits_NoSyringe`). Type 1's kit adds a syringe to the always-given
  items. The vial joins the `insulin` drug's items, the syringe the Pill Caddy's extras. Loot:
  vials in medical storage and fridges, syringes wherever medicine is kept plus drug shacks, the
  magazine at Living With Type 1's rate in the same lists, plus `TestingLab`. Icons in `make_icons.py`.
- **Diabetes sandbox options.** `InsulinLoot` (percent, pens, vials and syringes, through the
  loot spec's `sandbox` field like `InhalerLoot`) and `UntreatedDiabetesDays` (0 to 60, default 1):
  above 350 the health floor is now `DanTraits_DiaHighFloor(diaKetoHours)`, 15 at the two-hour
  drain start sinking linearly to 0 at `days x 24` hours (0: stays 15). At the default this
  replaces the old 15-until-24-hours-then-0 step with a slope ending at the same time. Tests in
  test_diabetes 12, test_actions 3, test_client 2 (the harness inventory gains `getAllEvalRecurse`).

- **Medication reminder** (`DanTraits_Meds.lua`, `DanTraits_Moodles.lua`, `DanTraits_HealthPanel.lua`): daily
  drugs and the antidepressant gain `everyH` (24 or 12) and `item` (the full type the name is read from), and every dose
  notes `meds[id].lastH` (world hours; `DanTraits_MedStart` too). `DanTraits_MedSchedule(player)` is the scheduled drugs
  for traits the character has; `DanTraits_MedDue` is 1 from `everyH - 2` hours after the last dose, 2 once out of the
  system with build-up left, 0 once that is gone; `DanTraits_MedSince`, `DanTraits_MedNextIn`, `DanTraits_MedInSystem`
  read the rest. New moodle MedsDue (the worst of the schedule; sandbox `MedReminderMoodle`, default on) with its icon in
  `make_icons.py`. The health panel's render is wrapped (OnGameStart, guarded against a second layer like doDrawItem):
  for your own character a Daily Medication header and a line per scheduled drug go where the body part list starts,
  and the list, its height and `allTextHeight` move down to fit. Tests in test_meds 13, test_moodles, test_healthpanel 11.

- **Blood readout on the health panel** (`DanTraits_Blood.lua`, `DanTraits_HealthPanel.lua`): a Blood section above
  Daily Medication, your own character only, by the examiner's First Aid level read live (the same bands as the body part
  lines). 0-2: how you look (no sign, worn down while red cells are short, pale and weak, pale and light-headed, in
  shock, close to death) and "still bleeding". 3-5: the class of blood loss (none, a little = class I, then II to IV by
  tier), bleeding slowly / steadily / heavily (under 0.1%, from 0.4% a minute), coming back or "needs water" (no
  refill), red cells low (`bloodWeak` > 0). 6-8: volume and red cells to the nearest 5%, the net loss or refill an hour.
  9-10: whole percentages, net loss to 0.1% an hour with the time to shock (60% volume) or to the heart giving out (50%),
  time back to full, time for red cells back to normal. The refill now notes the minute's gains (`bloodVolGain`,
  `bloodCellGain`) and `DanTraits_BloodState(player)` hands the panel volume, cells, loss, gains, tier, weakness and the
  shock and death edges (nil with the blood off). The sections share one 4 px gap each (`HP_GAP`, was `HP_MED_GAP`).
  Tests in test_blood 8b, test_healthpanel 12.
  A doctor sees a patient's blood too, at the doctor's level. Split-screen reads the patient's mod data; in
  multiplayer (each client runs its own players' blood) a relay asks the patient's client
  (`client/DanTraits_BloodRelay.lua`, `server/DanTraits_BloodRelay.lua`): `DanTraits_PatientBloodState(doctor,
  patient)` sends `bloodAsk` when the last answer is 3 s old (at most once a second) and returns it for 10 s; the server
  passes an ask on only within 4 tiles or in the same vehicle and no more than every 0.5 s per doctor, and passes a
  `bloodTell` back only to a doctor who asked about the sender in the last 5 s, keyed by the sender's online id and
  stripped to the panel's nine numbers (false with the blood off). Daily Medication stays your own (and split-screen).
  Tests in test_bloodrelay (new), test_healthpanel 12.

### Changed

- **Antidepressants build up in 3 days** (`MDD_MED_FULL_DAYS` 14 to 3). The streak cap (x4) is now 12 days, so a lapse
  starts costing benefit after about 3 days off instead of 14; discontinuation still needs a 7-day streak.
- **Wound Damage sandbox option** (`WoundDamageEnabled`, default on, Health page; Steam report from Arkantos Eli,
  2026-10-23). Blood Loss refunds vanilla's bleed health loss but keeps `BodyPart.DamageUpdate`'s wound damage to the
  part (deep wound unstitched 3.125, bandaged 1.5625; scratch 0.9375, cut 1.875, bite 2.1875 unbandaged; bullet left
  in 3.125 / 1.5625; x `damageScaler` 0.0057 x the game-time multiplier, through `CombatManager.applyDamage`). The neck
  weighs 0.7 in overall health (head 0.6, hand 0.1), so an open neck cut costs about 4.6x what the bleed refund gives
  back. Off (with Blood Loss on), the Blood frame driver gives the same amount back to each part
  (`refundWoundDamage`); invulnerable characters and parts at 0 are skipped. Burns and fractures stay vanilla. The
  Blood Loss tooltip, the Workshop FAQ and the systems chart now say the wound itself still hurts. test_blood 11b.

### Fixed

- **Dropped in a car, it stays in the car** (`DanTraits_DropHeld`, Util): a meltdown, a seizure, MS hands giving out or
  an Arthritis or shakes fumble while driving threw the item onto the road. In a vehicle it now goes into the seat's own
  container (`getPartForSeatContainer(getSeat(player))`) when there is room, else it just leaves the hands (and then
  says nothing: the "dropped" notice is for something that fell).
- **Review 2026-10-22 follow-ups** (`plans/review-2026-10-22.md`, found before any of this batch was played):
  `DanTraits_BodyLocation` in Util is the one spelling of a body location (B42's `base:sweaterhat`; Sleep's slot table
  kept underscores and missed 34 of 72 slots, Laundry and Sensory had their own copies); the hot water bottle's night
  count waits for Vitality's `nightGap` and a look at the bottle (`DanTraits_HwbStage`, the Hold action's `isValid`)
  no longer re-stamps its clock at the indoor rate; ADHD's `boredomRise` leaves rises flagged by another system's
  floor alone (hyperfocus was undoing Sensory's and Endorphin Junkie's floors every minute); Sensory's tier notices
  come again on the next climb (`siTold` follows the tier down, `siPeak` keeps the calm line) and
  `DanTraits_SensoryOverload` reads only during an overload (Migraine's trigger fired from Overwhelmed); Fitness counts
  reps on a multiplayer client off `ActiveAnimLooped` (vanilla's `exeLooped` runs on the server only, so no load, no
  Pumped and a set that never ended), `clearFitness` clears the log, day and streaks too (stale days replayed on
  re-enable), the plan week is seven days not eight, a pending rep count carries its exercise and is cleared on Cancel,
  the window no longer writes the shared exercise definition; Fuelled needs Fitness on; a sweat-damp garment taken off
  is on the ordinary damp clock (`sw` cleared off the body), `L.rainedOn` counts a drizzle (0.05) and the bath
  (`DanTraits_BathingWet`); Bad Back leaves no `bbMoodle = 0` on characters without it; ADHD never drifts off from an
  action under `DRIFT_MIN_TIME` 200 (a transfer, an equip: the queue behind it went too). 2026-10-23 (user's call): a
  jog or a loaded-carry minute is half a hard minute (`FIT_HARD_HALF` in `hardMinutes`) toward a rest day's 20 and the
  Overtrained streak; most looting is a loaded carry, and at full weight a week of walking home encumbered was
  Overtrained.
- **Machine washes lost** (`DanTraits_Laundry.lua`): a washer was watched only once the player
  stood within 4 tiles of it at a ten-minute look while it ran. Vanilla's cycle
  (`ClothingWasherLogic`, 42.21) takes 0.02 blood and dirt a minute off each part and switches
  itself off at 90 minutes, so a load started and left alone was never credited: the clothes kept
  their odour (Stale Clothes) and a wash count of 0 (Sensitive Skin's "unwashed" itch), dryer or
  not. Now the toggle actions (`ISToggleClothingWasher`, `ISToggleComboWasherDryer`) put the washer
  on the watch list when switched on and mark the finished load when switched off; setting a combo
  to dry marks it first (`ISSetComboWasherDryerMode`); a watched washer found idle marks what it
  left finished before dropping off. A pending machine wash lands on a worn garment within the
  minute, and the moodle level is worked out every minute, so a change of clothes shows at once.
- **Migraine left Short Sighted on** (`DanTraits_Migraine.lua`): the attack's blur flips Short
  Sighted and restores the character's own state from `migBlur` at the end. An attack on
  2026-10-18 ended (MigraineEnd fired) with `migBlur` gone and the trait still on; the likely cause
  is the open mod-data swap (`md.DanTraits` replaced by a copy from a minute earlier, seen with the
  2026-10-16 aura). Now `migSight` notes the character's own Short Sighted every ten minutes outside an
  attack, and the restore (attack end, Migraines removed) and a re-flip after a glasses change fall
  back to it when `migBlur` is missing.
- **Hard hats held Stale Clothes up** (`DanTraits_Laundry.lua`): every `hat`-slot item counted as a
  half layer that sweats, so ear protectors (`Hat_EarMuff_Protectors`, worn all day for Sensory
  Issues) reached odour 58 and kept the moodle at Stale Clothes on 2026-10-19 under an outfit that
  was otherwise all at 0 to 1.5 (read from `players.db`). New `L.isHard`: the ear protectors,
  `Hat_Army`, `Hat_ArmyWWII`, `Hat_ArmyDesert(New)`, `Hat_Fireman` and any type containing `Helmet`
  or `HardHat` are layer 0 (`fullhat` helmets were already). `L.sight` zeroes odour a hard item
  gathered before (not musty ones).
- **Half the wardrobe never sweated** (`DanTraits_Laundry.lua`): the `FULL`/`HALF` layer lists were
  written with underscores (`short_pants`, `tank_top`, `torso_extra_vest`, `underwear_bottom`,
  `short_sleeve_shirt`, `jacket_suit`, `long_skirt`...), but Build 42's body location ids have
  none (`shortpants`, `tanktop`, `torsoextravest`), so those garments were layer 0: never stale,
  and left out of the Fresh Clothes count. Both sides are now matched with underscores stripped
  (ids that keep one, like `jacket_bulky`, still match). Found 2026-10-20 reading the save: camo
  shorts and a vest at odour 0 under a shirt at 21.
- **Dryer loads never counted as dry** (`DanTraits_Laundry.lua`): vanilla's `ClothingDryerLogic`
  (42.21 bytecode) takes one wetness point a game minute for its 90-minute cycle, so a load soaked
  by the washer (100) comes out at 10, and `LN.DRY_AT` was 10 ("under this"). Clothes from the
  dryer were not fresh, kept their damp clock, and a dryer sheet (which scents only dry garments)
  never took. `DRY_AT` is now 15.
- **Sweat counted as worn damp** (`DanTraits_Laundry.lua`): in the heat the game wets worn clothes
  itself (`ClothingWetness`), and the laundry treated that like clothes put on wet: `LN.DAMP_WEAR`
  25 odour an hour, the musty clock at x1.5, and body drying held to `LaundryBodyDryRate`%. On a
  hot July day (2026-10-20) boots and socks washed and dried hours before read odour 58 and 38.
  `L.bodyDry` now marks a garment `sw` when it rises from under `DAMP_AT` while worn and no rain is
  falling on the wearer (new `L.rainedOn`: outside, `getRainIntensity` 0.1+); rain clears the mark,
  and so do drying under `DRY_AT` and any wash. A marked garment dries at the game's speed, gathers
  no damp-wear odour and keeps no damp hours (no "turns musty in" line either). Off the body the
  mark goes too (2026-10-22): a sweat-damp shirt bagged kept `sw` and never went musty; `sight()`
  now clears it when the garment is not worn, so it is on the ordinary damp clock in a bag.

## Base Unloader 0.1.0 - 2026-10-16 (separate mod, not yet play-tested)

- **Base Unloader** (`BaseUnloader/`): right-click the trunk, a container or your own items for a
  window of every container in the base (name, kind, room, floor, distance, fill); drag item types
  onto containers to set remembered rules, or drag items from the inventory windows; Suggest fills
  the gaps from what the base already holds; Start has the character load up within the carry
  weight and walk the base nearest first, trip after trip, opening a closed trunk lid on the way.
  Rename containers from the list or the world; the loot window shows the names. Runs pause on any
  interruption and Resume from the saved plan; two steps that move nothing stop the run. Sandbox:
  Nearby Radius, Building Margin, Floors Searched. Offline test `tests/test_baseunloader.lua`.
- **Bags are unpacked** (2026-10-17, `BU.route`, `S.allItems`): a bag in the trunk or a container is
  opened (three deep, as the character's own bags already were) and each item inside goes where it
  belongs, taken straight out of the bag (vanilla moves items out of bags in a trunk). A bag waits
  while anything inside it is going somewhere; once it is empty, or nothing left in it has a home,
  it goes by its own rule with whatever is left. Inner bags are decided first. The window lists
  what is inside bags too. A bag now counts at its full weight (`getUnequippedWeight`: the game's
  `getActualWeight` is the empty bag's), so a full duffel no longer overloads a trip as 1 kg.
- **Shelf food stays out of the freezer** (2026-10-17, play report): cans and snacks were going into
  the freezer because it already held food (the contains and category steps took any container),
  and food that takes a year to rot (ramen, mac and cheese, oats, pet food) counted as perishable.
  Now only fresh food that rots within 90 days (`BU.LONG_LIFE_DAYS`, `BU.wantsCold`) is sent to a
  fridge or freezer, by contains, category or Suggest; anything else goes there only by a rule or a
  tag. The nearest-free fallback and the new filter also recognise modded fridges and freezers by
  name (`isCold`), not only the vanilla types.
- **Trips stop at Heavy Load 2** (2026-10-17, user asked; sandbox Heaviest Load, `BU.loadBudget`):
  the game's Heavy Load moodle is the load over the max weight (level 1 over 1x, 2 over 1.25x, 3
  over 1.5x, 4 over 1.75x), and a run now never loads past the chosen level (default 2: 1.5x).
  Each item is costed where it rides: in the worn bag with the best weight reduction that has room
  (its weight x (1 - reduction), as the game counts a worn bag's contents), else in the hands at
  full weight; `BU.trip` assigns the bag (`item.into`) and the run puts it there. Bags only carried,
  not worn, are not used. Replaced: bagged items counting as free, and one item always taken however
  heavy; an item that cannot fit even on an empty load is left and reported ("too heavy to carry
  without going past the load limit").
- **Categories from an item, and the same set again** (2026-10-19, user asked): right-clicking an
  item in a world container's loot window now has the container's Categories submenu under Base
  Unloader, as the world and loot-window icon menus do (the shared `worldSource` check: not a bag,
  floor, body or vehicle). The last categories set by hand (a toggle or "Categories from what is
  inside"; Auto-tag and clearing leave it alone) are remembered per save (`store.lastTags`), and
  every category menu, the window's too, offers "Same categories as last: Food, Cooking" on any
  other container, which replaces its categories with that set (`BU.noteTags`, `BU.lastTagsFor`,
  `BU.applyLastTags`). Tag one cupboard, then one click per cupboard for the rest.
- **Off limits** (2026-10-21, user asked): any container can be marked "Off limits: only what I drag
  here" from the window's right-click menu or the world, loot-window icon and item menus (last
  entry, after the categories), and lifted again with "No longer off limits". Kept per save by key
  (`store.offLimits`). The resolver leaves an off-limits container out of every stage but a rule
  and a one-off: no laundry, bin, freezer, already-has-some, category tag, has-the-category or
  nearest-free picks, so a fridge marked off limits hands fresh food to the next fridge and its
  own tags are ignored. Suggest and Auto-tag skip it too. The window shows "(off limits)" by the
  name, greyed. Unlike Hide, it changes where things go, not what is listed.
- **Clear every container's categories** (2026-10-21, user asked): the window's container
  right-click menu has "Clear the categories of every container in this base" while any container
  in it is tagged. A Yes/No dialog names how many; Yes clears the tags of every container the
  window scanned, hidden and off-limits ones too (`BU.clearTagsOf`, `BU_Window:clearAllTags`).
  Containers in other bases, type assignments and the remembered "same categories as last" set
  are left alone.
- **The base is the zones you draw** (2026-10-24, user asked: runs kept going into the houses next
  door): base zones within reach of the source (sandbox Zone Reach, default 40 tiles) are the base,
  and only containers inside them are listed and used. The zones are Base Unloader's own
  (`store.zones`, `BaseUnloader_Zones.lua`), drawn with the game's click-and-drag zone tool
  (`BU_ZoneDraw` derives `ISAddDesignationAnimalZoneUI` and saves the rectangle itself, so nothing
  becomes an animal zone and pens never count). A first version read the animal zones; the user
  chose own zones after reading Home Inventory Improved. **Base zones...** on the world menu and a
  **Zones** button in the unloader window open the zone window: every piece listed with its size,
  floor and distance, Draw / Rename / Walk there / Remove, all pieces lit on the ground with their
  zone's name. Pieces with the same name are one zone (an L-shaped house is two rectangles), each
  side 1 to 60 tiles (`BU.ZONE_MAX`). A zone counts on its own floor and Floors Searched above and
  below, so one drawn round the ground floor takes in the upstairs; a zone drawn on a floor wins
  there (`BU.areaAt`). Two far-apart pieces with one name stay apart: only the pieces in reach come
  along (`BU.nearAreas`). With no zone in reach, the old building-plus-radius search is used, under
  a "no zone drawn" heading that says to draw one.
- **Base inventory** (2026-10-24, from Home Inventory Improved, `BaseUnloader_Stock.lua`): **Base
  inventory...** on the world menu opens a window of everything stored in every base zone
  (containers, bags in them three deep, the floor), one row per type per container with its icon,
  category, count, zone and container. Search in everything or one field, click a header to sort
  (again to reverse), Refresh to count again. Hover a row to light its container up, double-click to
  walk to it. Counts are kept per piece in the save (`store.stock`, `S.refreshStock`), so a zone out
  of range keeps its last count, shown grey with its age. Counted when the window opens and when a
  run ends.
- **How many at base** (2026-10-24, from Home Inventory Improved): right-click items of one type and
  the item's menu says "At base: 12 (House 8, Shed 4)", or "None of these at base", from the kept
  counts; click it for the base inventory searched for that item. Only once a base zone exists.
- **Smarter Storage names** (2026-10-24): a container with no name of ours or the game's takes the
  name Smarter Storage gave it (`SmarterStorage_Name` in the object's mod data).
- **Zones and tags in the window** (2026-10-24, user asked): the container list goes zone by zone,
  nearest first, each a strong band with its container count, then "Tagged (n)" in blue and "Not
  tagged (n)" in grey under it (the room headings went: the room is on each row's second line). A
  tagged row has a blue stripe and tint and its categories in blue; an untagged one reads "no
  categories".

## 1.3.0 - 2026-10-17

- **Review 2026-10-22** (`plans/review-2026-10-22.md`): a put-away run ("what I am carrying") that could not
  deliver an item re-routed it to the same container every tick and froze the character; the run now gives up on it
  (`giveUp`, `state.gaveUp`) and an empty step counts toward the stuck check (`stall`). A type rule now comes before
  the "already holds one" and freezer inferences (a rule for hammers never won while any shelf held one); laundry and
  rubbish still come first, a rule for shirts being for clean ones. Hidden containers are no longer inferred into by
  kind (a hidden fridge took all fresh food, a hidden bin all rubbish); a tag on one still counts. A run started on a
  glove box or seat resumes there, not on the trunk (`saveSource` keeps the part id). Whole-category rules (`cat:`),
  which nothing set any more but `suggest` still obeyed, are gone from `destinationOf`, the window's menu and, on
  load, from the save. "Same categories as last" is forgotten when a game starts and remembered only when a tag is
  ticked on, not after a tick-off.
### New

- **Companion link** (`DanTraits_Telemetry.lua`): the telemetry file is written while the companion app
  is running, not only in debug mode. The companion (its own repo, `pz-companion`, grown from the old
  `tools/dashboard.py`) rewrites `~/Zomboid/Lua/companion_link.txt` every 5 s with the unix time; the
  mod reads it every 10 s and treats a stamp under 60 s old as alive. The command channel (give, set
  health, run Lua) stays debug-only, and the snapshot now carries `debug` so the companion knows when
  to show it. Multiplayer: still off. `tools/dashboard.py` and `Dashboard.bat` are gone from this repo.
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

- **Reading: immersion.** The stress and unhappiness a page takes off now climb with how long you
  have been reading without stopping. A sitting's first pages give 0.4 of the page's rate; it
  climbs over the first hour (20 minutes for a comic, magazine or newspaper) to 1.3 and stays
  there. Boredom is untouched: a page is a page. Put the book down and pick the same title up
  within 15 game minutes and the sitting carries on from where it was (a zombie at the window
  does not undo an hour of reading); longer, or another title, starts cold. A chapter at a time
  (30 minutes) averages about 0.6 of the old rate; a three-hour sitting about 1.15, so an
  afternoon lost in a book does more than the same pages in snatches. `R.IMMERSION_*` in
  `DanTraits_Reading.lua`; the sitting is kept in the character's reading data (`sitting`).
- **Germaphobe** gives 8 points (was 4).
- **Bad Back** and **Bad Knees** give 5 points each (were 4 and 3); **Set in Their Ways** gives 4 (was 2).
- **Pace Yourself** costs 4 (was 2): a tenth of the endurance on swings and sprints was too cheap at 2.
- **Blacksmith Knowledge** (the pickable `base:blacksmith`) adds +1 Short Blunt to its XP boosts and costs 7 (was 6); recipes unchanged.
- **Handy** can be taken in the 20s again (no longer in In Their 20s' `MutuallyExclusiveTraits`), at vanilla's 8 points, but gives the 20s none of its four starting levels: Carpentry, Maintenance, Carving and Masonry are shown greyed on the creation screen and taken back at spawn (`handyLevels` in the band table, through `DanTraits_AgeLevels`), and those four skills train x1.5 instead (`handyXp`, in the `Events.AddXP` handler, multiplying with the band's other factors; vanilla's +75% boost on them stays). The 40s and 50s keep their +1 Carpentry. (It cost the 20s 10 for three days of this cycle.)
- **Gym Regular, Meal Prepper and Early Riser cost 2 in the 40s and 3 in the 50s** (1 everywhere else): three +1 / +2 rows in the age price table, shown in red beside the cost.
- **Rough Night less often.** A night's hours half was hours slept over 7 (5 or 9 with the sleep
  traits), but the game wakes you when tiredness runs out, so a half-tired character slept about
  four hours, woke rested and still scored under 0.8; a lit room or one wake then tipped it into
  Rough Night (any score under 0.75). The hours half now takes the larger of that and the share of
  bedtime fatigue cleared by morning (`vitNightBedFatigue`, the highest at the start of any sleep
  that night), when bedtime fatigue was at least 0.1. Four hours from half tired to rested is a
  full night; an alarm at 0.4 after going to bed at 0.8 still counts by the hours.
- **Alcohol withdrawal raises anger**, the way a Smoker's craving does (`DanTraits_Dependent.lua`):
  each ten-minute tick sets a held level (`alcAnger`) climbing 0.1 towards a floor of 0.3 x
  withdrawal strength while craving and 0.6 x from the shakes on, and every frame keeps the anger
  stat at or above it against vanilla's drain. Asleep, sated by a drink or cured, the held level
  is taken back off the stat. At the starting meter (0.5) that is Irritated, then Annoyed; at a
  full meter Annoyed, then Angry, with everything `DanTraits_Anger.lua` gives the moodle. The
  craving and shakes moodle texts say so. The hold runs only for a character with the trait, or
  with a hold still to take off (the trait just gone): it ran for everyone, writing `alcAnger = 0`
  into every character's mod data every ten minutes (review 2026-10-16 A2.22; pinned in
  `tests/test_alcoholic.lua`).
- **Arthritis** starting kit (Starting Medication) adds a quarter bottle of prednisone (5 of 20
  pills) beside the painkillers.

- **Smoke gets into your clothes** (`DanTraits_Smoker.lua`): for six hours after any cigarette, cigar or pipe, habit or not, worn clothes go stale half as fast again (x1.5 on the laundry odour rate, on top of Sweaty or Cool Customer).
- **The headache after a concussion feeds Migraine** (`DanTraits_Migraine.lua`, `DanTraits_Hallucinations.lua`): the post-concussion headache (`DanTraits_ConcussionLateStrength`, which outlasts the score) was read by nothing; it now adds up to 2.0 to the migraine chance, beside the concussion itself, and keeps Schizophrenia's panic bouts down the way the concussion does.
- **Hangovers and dehydration know each other** (`DanTraits_Dehydration.lua`, `DanTraits_Migraine.lua`): a hangover builds the dehydration load on its own (Thirsty's pace times its strength; drinking water still drains it, slower), a hangover starting on a dehydrated body is up to half as bad again, and Migraine's thirst trigger reads the hours-long load as well as the moment's thirst.
- **Heart Condition feels the blood, the iron, the fever and the cold** (`DanTraits_Heart.lua`): strain builds half as fast again with half the blood volume gone, up to half as fast again at a full iron deficit (Anaemic) or a full wound-infection fever, and a cold body (soaked, a night without a fire: 36 C down to 34) builds strain like cold air does, indoors or out.
- **Arthritis: morning stiffness** (`DanTraits_Arthritis.lua`): getting up from a night's sleep adds 15 to the joints' stiffness floor, fading over half an hour; a coffee or tea in that half hour halves what is left; a nap adds nothing; the floor never passes a full flare's 45.
- **Anaemic: coffee with your iron** (`DanTraits_Anemia.lua`): while caffeine is working (Sleep's six-hour clock), a meal or an iron pill gives half the iron, so the pills are best timed away from the coffee.
- **Sensitive Skin burns and stings** (`DanTraits_Sunburn.lua`, `DanTraits_LaundryTraits.lua`): the sun burns a sensitive skin in two hours of full sun, not three (stacking with a tan and Outdoorsman), and bleaching a garment stings the hands (15 discomfort a garment, with a notice).
- **Resilient beats the Knox virus once, 10% by default, less when Run Down** (`DanTraits_Knox.lua`, sandbox): the Knox Survival Chance is 10 by default (was 25; the option still runs to 100, so a save made before keeps its stored 25 and logs no error); a Run Down body (Vitality) has down to half of it, a fit one the full value, never more; it is beaten once only, and a second infection is not rolled, says so, and runs its course in six hours.
- **Tinnitus is read by the rest** (`DanTraits_Tinnitus.lua`, `DanTraits_Migraine.lua`, `DanTraits_Hallucinations.lua`): while the ears ring, a migraine is likelier (+1.5), Schizophrenia's whispers come easier (+0.15) and a night slept through it scores 15% lower.
- **Brittle: a bone score** (`DanTraits_Brittle.lua`): the fracture chance follows the bones (a fifth to start, a tenth with strong bones, three tenths with weak); they drift down 0.02 a day, regular exercise (Vitality) holds the drift, and dairy, greens and eggs put some back, at most 0.06 a day. Brittle with Lactose Intolerance pays for its calcium in cramps. Console `brittle bone [0..1]`.
- **Home is a comfort for Spiraling and a rest for MS** (`DanTraits_MDD.lua`, `DanTraits_Spoons.lua`): a depressive episode's floor eases by up to 10 at home (Homebody doubles it), and true rest at home gives MS up to half as many spoons again, under the same daily cap.
- **A Really Bad Day draws on the new systems** (`DanTraits_BadDay.lua`): the night's drinking leaves the body half dehydrated, in the summer months you fell asleep in the sun (head, neck and forearms burnt for twelve hours), and the kit next door holds a stale, never-washed t-shirt and jeans beside the disinfectant and bandage.
- **Arthritis and Old Injury feel the storm coming** (`DanTraits_Arthritis.lua`, `DanTraits_Util.lua`): the joints flare to at least 0.4 while a storm, heavy rain or a blizzard is forecast to start within twelve hours and it is not raining yet (Migraine's storm reader, now shared from Util as `DanTraits_StormComing`); Old Injury reads the same joint factor.
- **Nocturnal asthma and the night low** (`DanTraits_Asthma.lua`, `DanTraits_Diabetes.lua`): a night slept on an irritated airway scores lower (up to 30% at full irritation), and a diabetic low under 55 while asleep wakes you drenched in sweat, once per low, and costs that night 30%.
- **Wheat and dairy are junk to the diet score for the intolerant** (`DanTraits_Gluten.lua`, `DanTraits_Lactose.lua`): bread or cheese no longer scores "fresh, cooked" for a character it makes ill; it grades as junk.
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
- **Reading: a comfort re-read overwrote the finish record's verdict, and two "no glasses" rules stacked** (`DanTraits_Reading.lua`, `DanTraits_ReadingHooks.lua`): a re-read recomputed the verdict at level 0, so a book recorded "loved" became "great" in the tooltip and the journal; the record's verdict is kept. And ReadingHooks had a glasses list of its own (only `Base.Glasses_Reading` counted, for every 40s and 50s character) beside the Reading Glasses trait's rule, so the two disagreed about prescription glasses. One rule now: the trait's `DanTraits_NeedsGlasses`; the small-print extra on a page applies to whoever it says needs glasses.

- **A crash was judged against whoever came next** (`DanTraits_Concussion.lua`): the car's top speed, a crash waiting on the speed after it, the head's last reading and the minute's strain flags were module state, tied to no character, so a multiplayer respawn or a second split-screen player in the window after a crash would have been knocked for it. They are per player object now (a weak table); a character that is gone takes its state with it.
- **The clocks ran for player 0 only** (`DanTraits.lua`, `DanTraits_Util.lua`): the minute and ten-minute drivers ran every system for `getSpecificPlayer(0)` while the frame driver ran every local player, so split-screen player 1 got the frame systems and the delta pipeline but no minute system, pain floor or moodle. They run for every local player now, each once. `DanTraits_FloorUp` booked its floor flag on player 0 whatever stats it was handed; it books it on the player the drivers are running for (`DanTraits_RunningFor`).
- **"Read a chapter" on a multiplayer client** (`client/DanTraits_ReadingClient.lua`): the server rebuilds a timed action from `ISReadABook:new`'s own parameters, so the chapter flag set after `new()` never reached it and the server read the whole book, finishing the title when the client's chapter ended. The option is not offered on a multiplayer client; singleplayer and split-screen keep it. The laundry action's singleplayer shape (all the work in `perform()`, no `complete()`) is written down in its header and in `plans/multiplayer.md`.
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

### Reading for pleasure (built in Dan's Vanilla Fixes 2026-10-12, moved into Vitality 2026-10-15)

Reading was a vending machine: ten minutes, a fixed drop in boredom, stress and unhappiness at the
end, once per title. Now it is something to carry on a run (design and as-built notes:
`plans/reading.md`; its own sandbox page, Vitality: Reading, with a master switch).

- **Every vanilla title is tagged**: 1,177 books, 224 comics and 167 magazines get a genre family
  (18 of them, folded from the game's 55 book subjects and 24 magazine subjects; comics by the
  words in their titles), a page count (softcovers 180-380, hardcovers 250-500, serious reading
  300-650, kids' books 24-64, comics 24-48, magazines 60-140, newspapers 12-40, each title its own)
  and a hidden quality of one to five stars, most at two or three. The table is generated from the
  game jar by `DanTraits/tools/gen_reading_data.py` (a bytecode walk of the `Book`,
  `ComicBook` and `Magazine` registries), with hand fixes in `DanTraits_ReadingBooks.lua`.
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
  lasts about two days (48 hours) for a novel whatever its quality, 12 hours for a comic or
  magazine (never above Good Read; nothing for a newspaper), and carries **one buff, set by the
  genre**, which its description names with the hours left ("Horror: panic fades faster. About
  41 h left."). Stat buffs: Horror eases panic, Thrillers stress, Romance and Humor low moods,
  Popular Fiction and Kids boredom, Classics boredom and low moods, Faith stress and low moods,
  True Stories panic and stress, Westerns brings stamina back faster. XP buffs (+5%, only when no
  skill book's multiplier is running): Sports Fitness and Strength, Sci-Fi Electrical and
  Mechanics, Science First Aid and Foraging, History Aiming and Reloading, Fringe Trapping and
  Sneaking, Arts Carving and Pottery, Self-Help Cooking, Farming, Carpentry, Tailoring and
  Maintenance. Serious Reading makes books read a tenth faster. Every buff scales with the
  moodle's strength. Only one runs at a time: a new finish takes over when it is a higher level,
  or the same level with more time to run; otherwise the running buff stays as it is.
- **Re-reads** give a fifth of the drip in the liked family only (sandbox switch), and no moodle.
- **Real books**: about 200 titles from before July 1993, title and author only, with their real
  page counts and a quality by hand. A novel in loot has an 8% chance (sandbox) of being one from
  the same genre; it is named like a vanilla book and read-tracking works on it unchanged.
- **This Is Your Life**: books you finish and tastes you find out go in its survivor journal, as
  dated lines ("July 12, 1993 - Finished "Jurassic Park". Loved it.").
- Books from other mods get a neutral fallback (Popular Fiction, 120 pages, three stars, no moodle).
  Skill books, recipe magazines, fliers, brochures and the old newspapers are untouched.
- Multiplayer: the stat changes run on the client that owns the character, as vanilla's do;
  built for it (no wrap of `new`, `complete` handled on the server) but not yet tried on a server.
- **Vitality's say** (`DanTraits_ReadingHooks.lua`): a page does 15% more good at
  home by the home's strength (30% for a Homebody), half as much when concussed (and takes a
  quarter longer), and a Really Bad Day's first day gets a quarter more comfort from any book.
  In their 40s a reader without reading glasses takes a tenth longer per page, in their 50s 15%.
- **Moved from Dan's Vanilla Fixes** on 2026-10-15, so it ships with Vitality: the files are
  `DanTraits_Reading*.lua` (core, action, books, data, client, This Is Your Life), the API is
  `DanTraits_Reading` (was `DVF_Reading`), the options are `DanTraits.Reading*` on the Vitality:
  Reading page, and the text keys are `IGUI_DanTraits_*`. The save keys (`DVF_Reading` on the
  character, `DVF_ReadPages` on a copy, the `IGUI_DVF_BookTitle_` prefix of a real book) keep their
  old names, so bookmarks and real books in a save carry on. The tooltip strip is shared:
  `DanShared_Tooltip.lua` ships in both mods, identical (`deploy.py` refuses to deploy if they
  differ), and draws one strip whichever loads first.

### Laundry: load the washer in one click (built in Dan's Vanilla Fixes 2026-10-09, moved into Vitality 2026-10-15)

- Right-click a washing machine (or a combo washer/dryer set to wash, or a stacked pair's
  washer): **Put dirty clothes in the washer (N)** walks you over and moves every garment you
  carry that the game calls Dirty or Bloody, bags included, into it with the game's own
  transfer actions. What you are wearing stays on. Greyed with the reason when nothing you
  carry needs it or the machine is running.
- `DanTraits_LaundryWasher.lua` (was `DansVanillaFixes_WasherClient.lua`); the option is on whether
  or not the laundry rules are.

### Dan's Vanilla Fixes: item info in tooltips (2026-10-13)

Our own take on the parts of Better Item Info worth keeping (that mod replaced the item tooltip
and hid every Dan's Vanilla Fixes line under it). New sandbox page Dan's Vanilla Fixes: Item Info.

- **One strip** under vanilla's tooltip for every line
  (`DanShared_Tooltip.lua`, `DanShared_Tooltip.add(id, order, fn)`, shared with Vitality since the
  reading move): the reading lines (genre,
  pages read of the total, verdict), the item info below, then the collection line. The
  reading and collection lines used to be two strips that drew over each other.
- **Read time left** on skill books and on the novels, comics and magazines the reading overhaul
  handles: "Time to finish: about 3 h 40 min", from the read action's own duration, so Fast and
  Slow Reader, glasses, sitting, Anger, Home and the age traits all count. Nothing for a volume
  above your level + 1, for the illiterate, or one read through.
- **Uses left** on drainables ("Uses left: 7 of 20"); batteries and anything that runs on one
  show a charge in percent.
- **Weapon numbers by skill** (`DansVanillaFixes_ItemInfo.lua`): the skill it trains and your
  level, then damage from level 1, critical chance at 2 (vanilla's 3 a level), attack speed and
  reach at 3, knockback and endurance per swing at 4; firearms by Aiming (damage, critical
  chance, accuracy, range and noise). Maintenance 1 adds the condition in numbers, Maintenance 2
  how often a hit wears the weapon (vanilla's 1 in chance + 2 x the maintenance mod). Sandbox
  Weapon Numbers Need Skill off shows them all from the start.
- **Clothing**: the body parts covered, four a line, and for a garment you are not wearing how
  its insulation, wind and water resistance and running and combat speed compare with what you
  wear in that slot, one line each, green better, red worse (vanilla already compares bite,
  scratch and bullet defence).

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

## 1.2.0 - 2026-10-10

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
