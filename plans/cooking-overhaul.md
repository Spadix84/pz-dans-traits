# Cooking overhaul

Agreed 2026-10-20: a proper cooked meal gives a mood afterglow for a few
hours (for everyone, training or not), and feeds the fitness system: more
training experience, and one more buff picked by what the dish is mostly
(protein, carbs or fat). Bulk and Cut diet goals in the fitness window. Small,
percentage buffs on things you already do; never flat stats or free XP.

Not a trait: everyone has it, behind the sandbox option `CookingEnabled`
(default on). The training buffs need Fitness Training on as well; the mood
afterglow, Energised and Full do not.

## 0. What vanilla does (read from the game, 2026-10-20)

Read from `projectzomboid.jar` with a small class-file disassembler (no JDK on
this machine; `jdis.py` in that session's scratchpad).

- **Protein already pays Strength.** `IsoGameCharacter$XP.AddXP`: Strength
  experience x1.5 while the body's protein store (`Nutrition.getProteins`) is
  over 50 and under 300; x0.7 under -300. Nothing else in the Java reads
  protein, carbs or fat except the weight code, so protein does **not** speed
  healing in vanilla. So the protein buff here is recovery only, never more
  Strength experience.
- **Fitness is blocked by weight.** `Nutrition.canAddFitnessXp`: no Fitness
  experience at Fitness 6+ while Emaciated, Obese or Very Underweight, nor at
  9+ with any weight trouble.
- **Weight follows the calorie store.** `Nutrition.updateWeight`: weight goes
  up while the store is over 1000 + (weight - 80) x 40 (700 with Weight Gain
  under 90 kg, 1800 with Weight Loss over 70), at 1.3e-5 kg a second x
  min(1, store / 4000), x2 with carbs or fat over 400, x3 over 700; it goes
  down while the store is under min(0, (weight - 70) x 30), at 8.5e-6 kg a
  second x min(1, |store| / 2500). `isIncWeight` / `isDecWeight` say which is
  happening. The store drains by activity (x0.6 walking, x1 running, x1.3
  sprinting, a trickle at rest or asleep).
- **Dishes carry their mood.** `EvolvedRecipe.addItem` writes the
  ingredients' unhappiness, boredom and stress onto the dish (spices lower
  them, `useSpice`); a unique recipe adds its bonus. So the dish's own
  `getUnhappyChange()` is the right thing to read: it is what the meal gives.
- `Food.getUnhappyChange()` adds the dish's state: +30 frozen (not ice
  cream), +20 burnt, +10 stale, +20 rotten, +2 a bad-cold cooked dish eaten
  cold, -2 a good-hot cooked dish eaten hot (heat over 1.3).
  `getStressChange()`: /4 burnt, /1.3 stale, /2 rotten, x1.3 cooked.
- `BodyDamage.JustAteFood` adds `getUnhappyChange() x fraction` to
  UNHAPPINESS (0..100) and boredom the same way, x1.25 for a good change and
  x0.75 for a bad one when eaten from a plate or with a utensil.
  `IsoGameCharacter.Eat` adds `getStressChange() x fraction` to STRESS.
- The Food Eaten moodle (`MoodleType.FOOD_EATEN`): Satiated, Well Fed,
  Stuffed, Full to Bursting.
- `ISAddItemInRecipe:complete` (shared Lua) calls `recipe:addItem` and runs
  wherever the action completes (the server in multiplayer).

## 1. A proper meal

A **proper meal** is at least 300 kcal of one dish tier. Bites of the same
dish within an hour add up, so a bowl eaten in quarters still counts.

The dish's **tier**:

| Tier | Needs |
|---|---|
| Home-cooked | an evolved dish with 2+ ingredients; a dish that is never cooked (a sandwich, a salad) tops out here |
| Hearty | cooked, 3+ ingredients, the cook at Cooking 3+ |
| Chef's | cooked, 4+ ingredients (or 3 and a spice), the cook at Cooking 7+ |

None for burnt, rotten, uncooked (a stew still raw) or fewer than two
ingredients. Stale drops a tier (not below Home-cooked). The cook's level is
stamped on the dish when an ingredient goes in (`ISAddItemInRecipe:complete`,
the highest level of anyone who added one); a dish without the stamp (made
before this, or the stamp lost when it was poured out) reads the eater's.

## 2. Good Meal: the mood afterglow

The afterglow pays back unhappiness and stress over a few hours, awake:

| | Home-cooked | Hearty | Chef's |
|---|---|---|---|
| Unhappiness, base | 6 | 10 | 15 |
| plus this share of the meal's own unhappiness drop | 25% | 50% | 75% |
| Stress, base | 0.03 | 0.05 | 0.08 |
| plus this share of the meal's own stress drop | 25% | 50% | 75% |
| Lasts | 3 h | 4 h | 5 h |

- At home (the Home moodle's At Home), x1.25; a Homebody x1.5.
- The same dish (full type) eaten within the last day: x0.5.
- Sensory Issues: a disliked texture gives no afterglow.
- A new meal only replaces the glow if it would pay more unhappiness than
  is left to come.
- Depression: a Good Meal holds the comfort-food timer for the glow's
  length (the timer is `mddFoodTimer`, three hours from any food that lifts
  mood).

## 3. The training buffs

Every proper meal makes you **Fuelled** for 4 hours: Fitness and Strength
experience +5 / +10 / +15% by tier (a new `fitnessXpAll` hook in Fitness's
experience handler, so jogging and the game's own gains count too).

One more buff by what the dish is mostly, read from its protein, carbs and
fat as calories (4, 4 and 9 a gram) against a line for each (protein 25% of
the calories, carbs 50%, fat 40%): the one furthest over its line wins.

| Mostly | Buff | Home-cooked / Hearty / Chef's | Lasts |
|---|---|---|---|
| Protein | Recovering: muscle groups recover faster (`fitnessRecovery`) | +10 / 20 / 30% | 6 h |
| Carbs | Energised: endurance spent is partly given back | 5 / 10 / 15% | 3 h |
| Fat | Full: hunger rises slower (`hungerRise`) | 5 / 10 / 15% | 4 h |

A new meal replaces Fuelled and the macro buff when its tier is at least the
running one's, or the running one has under an hour left.

**Side stitch.** Training, jogging or running while Stuffed (Food Eaten 3)
rolls 2% a minute, Full to Bursting 5%: the lower torso stiffens to 25 (pain,
like soreness), a notice, then no roll for an hour.

## 4. Diet goals and weight

A **Diet** drop-down next to the plan in the fitness window: none, Bulk or
Cut (needs Fitness Training).

- **Bulk:** Strength experience +10% while the game says you are putting on
  weight (`isIncWeight`).
- **Cut:** Fitness experience +10% while you are losing weight
  (`isDecWeight`), and the loss goes a quarter faster.
- **Back toward normal:** Fuelled and with a hard day's training in (20 hard
  minutes), weight under 78 kg rises and over 82 falls by 0.2 kg a day (not
  down on Bulk, not up on Cut).

## 5. The cap

All of Fitness's boosts on one gain (Ready, plan, bench, Weightlifter,
magazines, Fuelled, diet) top out at x2 before the sandbox's Training
Experience (%) applies. Reductions (Sore, Overworked, Overtrained) are not
capped. Vanilla's protein x1.5 and Vitality's Thriving x1.5 are outside it.

## 6. What shows

- Moodle **Good Meal**: good side Good Meal (Home-cooked or Hearty), Great
  Meal (Chef's), while the afterglow or Fuelled runs; bad side Side Stitch for
  20 minutes after one.
- A notice when a meal lands: the tier and what it was mostly.
- A line on a dish's tooltip: its tier for you and what it is mostly.
- The fitness window: the diet drop-down, and Fuelled / the macro buff in the
  bonuses line.

## Left out

- Warmth from a hot meal: writing body heat means the thermoregulator, which
  is not verified from Lua. Vanilla's -2 unhappiness for a good-hot dish stays.
- Healing from protein (not vanilla's, and not wanted on top of Blood and
  WoundCare).
- Carry weight, max endurance, flat stats, XP for eating.
- Multiplayer: the cook's stamp is item mod data written where the action
  completes; whether it reaches the eater's client is unverified, and the
  eater's own level is the fallback.

## As built (2026-10-20)

`shared/DanTraits_Cooking.lua` (minute order 40, label Cooking; the eat hook;
the stamp wrap), the `fitnessXpAll` hook and the x2 cap in
`DanTraits_Fitness.lua`, the diet drop-down and status in
`client/DanTraits_FitnessUI.lua`, the tooltip line in
`client/DanTraits_CookingClient.lua`, the Good Meal moodle in
`DanTraits_Moodles.lua` (icon `ui/GoodMeal.png`, 16x16 art doubled),
`tests/test_cooking.lua`. Cooking runs at minute order 40 before Fitness (by
label), so it reads the exercise Fitness marked the minute before. 86/86,
lint clean. Unplayed. Russian text not added.
