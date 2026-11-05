# Catchable illness: player reference

What each illness does in the build deployed on 2026-11-03 (`DanTraits_Illness.lua`, `DanTraits_Fever.lua`). The numbers come from the code. None of it has been seen in game yet.

## How every illness works

- **Caught → hidden → sick → over.** Once caught, an illness stays hidden for a while (the incubation), then runs a course. It climbs to its peak and eases off to nothing. Some leave you immune for a time.
- **The peak is rolled when it starts.** Prone to Illness makes it worse (×1.14). Resilient makes it milder (×0.84). The flu and pneumonia are 30% worse for the at-risk groups: Asthma, Heart Condition, Smoker, Diabetes (Type 1 or 2) and the 50s.
- **One fever.** Every illness, and an infected wound, adds to one fever: the worst one plus half of each of the others. A total past 1 is dangerous and drains health. Painkillers and cold medicine lower the fever you feel but not the danger. A fever from an illness also makes a wound infection grow faster and clear more slowly.
- **What changes how long it lasts** (no trait does):

  | What you're doing | Speed of the illness |
  |---|---|
  | Asleep | ×1.3 |
  | Asleep at home | ×1.5 (a camp becomes home after 3 nights slept there; Nomads never get this) |
  | Running or sprinting | ×0.8, so it drags on |
  | On antibiotics (bacterial ones only) | ×2.5, and the symptoms are 30% milder |

- **Herbs** (2026-11-04): the game's own herbs, eaten or as a spice in a mug of tea or a dish, ease one kind of symptom for 3 hours. They are gentler than the medicine; dried herbs count the same. You get the notice "That helps, a little" when a herb touches something you have.

  | Herb | Eases |
  |---|---|
  | Lemongrass | nausea ×0.7 |
  | Ginger Root | nausea ×0.8 |
  | Mint, pickled ginger | nausea ×0.85 |
  | Chamomile | cramps ×0.8 |
  | Common Mallow | cough and cold ×0.8 |
  | Thyme | cough and cold ×0.9 |
  | Honey | cough and cold ×0.9, aches ×0.9 |
  | Black Sage | aches and a sore throat ×0.8 |

- **Antibiotics** count once the level is 0.5 or more. One pill gives 1, and the level halves every 6 hours. In practice that is a pill about every 8 hours, three a day.

### Traits and states that change the chance of catching something

| | Chance |
|---|---|
| Prone to Illness | ×1.3 |
| Resilient | ×0.7 |
| Vitality: Thriving / Run Down | down to ×0.75 / up to ×1.25 |
| Age: 20s / 30s / 40s / 50s | ×0.85 / ×1 / ×1.15 / ×1.35 |
| Very tired | up to ×1.3 |
| Hungry | up to ×1.2 |
| Stressed | up to ×1.2 |
| Smoker (the cold, the flu, pneumonia) | ×1.15 |
| Iron Gut / Weak Stomach (food poisoning only) | ×0.5 / ×1.5 |
| Sandbox Illness Frequency | ×(percent / 100) |

On the cold's wet-and-cold route, the game itself applies Prone to Illness, Resilient and Outdoorsman to its cold meter. We apply age, tiredness, hunger, stress and Smoker on top.

### Time frames at a glance

"Rested" means about 12 hours of sleep a day at a home or camp, and no running. That is about 20% faster. A Nomad resting rough gets about 13% faster.

| Illness | Hidden for | Untreated | Rested | On antibiotics | Antibiotics + rested | Immune after |
|---|---|---|---|---|---|---|
| Common cold | 12-36 h | 3-7 days | 2½-5½ days | no effect (viral) | n/a | 3-5 weeks |
| Flu | 1-3 days | 5-10 days | 4-8 days | no effect (viral) | n/a | 120-150 days (the season) |
| Pneumonia | 6-12 h | 10-21 days | 8-17 days | 4-8½ days | 3¼-6¾ days | none |
| Strep throat | 1-2 days | 7-10 days | 5½-8 days | 2¾-4 days | 2¼-3¼ days | 1-2 months |
| Stomach bug | 12-48 h | 1-3 days | 19-58 h | no effect (viral) | n/a | 4-8 weeks |
| Food poisoning | 6-24 h | 1-2 days | 19-38 h | 10-19 h | 8-15 h | none |

---

## Common cold (viral): severity 1/5

**How you catch it:**
- Being wet and cold. The game's own cold meter fills, and at 90 (of 100) there's a 75% chance a cold takes. The meter starts again either way.
- A small background chance as well: 0.04% an hour, doubled November to March.
- A cold that something else starts (vanilla, A Really Bad Day, another mod) is taken over by this system.

**Effects:**
- The game's own cold: sneezing and coughing that zombies hear, and the cold moodle. Its strength follows the illness (game strength 20 → 70).
- Tiredness.
- A small fever only near the peak (up to 0.25).
- **The danger isn't the cold itself.** While it runs it can turn into pneumonia or strep.

**How long:** hidden 12-36 h, then 3-7 days (2½-5½ rested). Immune for 3-5 weeks after.

**Wilderness / primitive run:**
- **Prevent it:** stay dry. Get out of rain gear and wet clothes by a fire, don't wade or swim in the cold months, and carry a spare dry layer. Outdoorsman and Resilient help the meter fill more slowly.
- **Once you have it:**
  - Hole up at camp and sleep a lot.
  - Don't run, and don't let yourself get soaked or chilled. Each of those multiplies the pneumonia chance.
  - Stay out of stealth work and away from hordes; the cough gives you away. A tissue or toilet paper in the inventory muffles it (vanilla).
- **Herbs:** Common Mallow (×0.8) or thyme or honey (×0.9), in a tea or eaten, cut the coughing for 3 hours. Take one before you have to move quietly.

---

## Flu (viral): severity 3/5 (4/5 for the at-risk groups)

**How you catch it:** 0.03% an hour, November to March only. The smoker and the resistance modifiers apply. After one bout you are immune for the rest of the season (120-150 days).

**Effects:**
- A high fever (up to 0.7).
- Aches: a pain floor up to 30.
- Stamina held under half at the peak.
- Heavy tiredness, some thirst.
- The game's cold cough, which zombies hear.
- 30% worse peak for Asthma, Heart Condition, Smoker, Diabetes and the 50s.
- The biggest danger is pneumonia on top of it. The two fevers stack to about 1.15, a dangerous fever that drains health.

**How long:** hidden 1-3 days, then 5-10 days (4-8 rested). Antibiotics do nothing.

**Wilderness / primitive run:**
- **Prepare before winter:** stock the camp with water, food and firewood for a week. A sick player at half stamina can't forage, chop or fight.
- **Lower the odds:** keep Vitality high (good meals), sleep well and stay fed. Tiredness, hunger and stress each raise the chance.
- **Once it hits:**
  - Bed rest at the camp, warm and dry, and keep drinking.
  - Above all, don't run and don't get soaked or chilled. With the flu, pneumonia is 2.5× likelier than with a cold.
- No primitive remedy changes the course. Mallow, thyme or honey quiet the cough, and Black Sage or honey take the edge off the aches.

---

## Pneumonia (bacterial): severity 4/5 (5/5 on top of the flu, or for the at-risk groups)

**How you catch it:** only while a cold or the flu is running. The chance per hour scales with that illness's severity: 0.04% for a cold, 0.1% for the flu, at full severity. It is multiplied by:

| Condition | Multiplier |
|---|---|
| Running or sprinting | ×3 |
| Soaked (wetness 50+) | ×2 |
| Chilled (body under 36 °C) | ×1.5 |
| Smoker | ×1.5 |
| Asthma | ×1.5 |

The multipliers stack: an asthmatic smoker running in the rain with the flu is about 13× the base.

**Effects:**
- A high fever (up to 0.8).
- Chest pain: a pain floor up to 25.
- Stamina held down to 0.4 at the peak.
- Heavy tiredness.
- The cough.
- **Past severity 0.7, health drains directly:** up to 0.08 a minute at full severity. That bites for the at-risk groups, whose peak is usually 1. An average healthy peak (about 0.8) only touches it briefly.
- **With the flu:** the stacked fever goes past 1 and drains a further ~0.3 health a minute.
- The 50% rule is the margin: the second illness only adds half its fever.

**How long:** hidden 6-12 h, then 10-21 days untreated (8-17 rested). On antibiotics 4-8½ days (3¼-6¾ rested), which means about 12-25 pills.

**Wilderness / primitive run:** this is the one that can end a primitive run. There are no antibiotics, so it runs its full two to three weeks.
- **Prevention is the whole game.** The moment a cold or the flu shows:
  - stop running;
  - stay dry and warm (a fire, a shelter, dry clothes);
  - don't smoke.
- **Once it hits:**
  - Full bed rest at an established camp, which gives the ×1.5 home speed. Have water and food in reach.
  - Keep wounds clean: the fever speeds infection.
- **Herbs:** mallow, thyme or honey for the cough, and Black Sage or honey for the chest pain. They don't touch the fever or the health drain.
- **If the flu and pneumonia overlap with no antibiotics:**
  - The health drain only lasts while both are near their peaks, so being well fed and rested for the game's own healing matters.
  - Whether a healthy character survives it untreated is the open question for tomorrow's test (P5).

---

## Strep throat (bacterial): severity 2/5

**How you catch it:** 0.05% an hour while a cold is running, and 0.005% an hour otherwise, with the resistance modifiers. After it you're immune for 1-2 months.

**Effects:**
- A very sore throat: a pain floor up to 20.
- A fever up to 0.4.
- Some tiredness.
- No cough of its own.

**How long:** hidden 1-2 days, then 7-10 days (5½-8 rested). On antibiotics 2¾-4 days (2¼-3¼ rested), about 9-12 pills.

**Wilderness / primitive run:**
- It comes with colds, so avoid the cold (stay dry).
- Once you have it, rest at camp. It's a week of being sore and slightly feverish, not a threat by itself.
- Watch the fever if a wound is infected at the same time: the two add up.
- Black Sage (×0.8) or honey (×0.9) ease the sore throat for 3 hours.

---

## Stomach bug (viral): severity 2/5

**How you catch it:** eating with dirty or bloody hands, using the game's own blood and dirt on the hands.
- Hands under 10% dirty are clean enough.
- Above that, a full meal has a 12% × grime chance.
- A small snack counts for its share.

**Effects:**
- Nausea: the game's food sickness held up to 50.
- Cramps: a pain floor up to 15.
- Thirst from the runs.
- A low fever (up to 0.15) and tiredness.

**How long:** hidden 12-48 h, then 1-3 days (19-58 h rested). Antibiotics do nothing. Immune for 4-8 weeks.

**Wilderness / primitive run:**
- **Prevent it:** wash before you eat, at a river, lake, pond or rain collector. Wash after every fight, every butchering and every long forage.
- **Once you have it:**
  - Drink: boiled or clean water close to camp.
  - Rest.
  - Don't stack it with food poisoning by eating doubtful food while you're sick.
- **Herbs:** Lemongrass is the best (nausea ×0.7 for 3 hours), then Ginger Root (×0.8) and mint (×0.85). Chamomile tea eases the cramps (×0.8).

---

## Food poisoning (bacterial): severity 3/5

**How you catch it:** what the food itself carries, per full portion:

| Food | Chance |
|---|---|
| Rotten | 30% (15% if it was cooked) |
| Raw meat, fish or eggs (the game's "dangerous uncooked") | 35% |
| Stale | 4% |

Iron Gut halves the chance and Weak Stomach adds half again, plus the resistance modifiers. The game's own food sickness from bad food still comes at once, on top of this.

**Effects:**
- Nausea: food sickness held up to 70.
- Cramps: a pain floor up to 25.
- Hard thirst: up to about 0.07 an hour on top of normal, so full thirst in about half a day with nothing to drink. **Thirst is what kills.**
- A fever up to 0.35.

**How long:** hidden 6-24 h, then 1-2 days (19-38 h rested). On antibiotics 10-19 h (8-15 rested), about 2-3 pills. Never immune.

**Wilderness / primitive run:** the one you're most likely to get in the wild, and the easiest to avoid.
- **Food rules:**
  - Cook everything you hunt, trap or fish, and cook eggs.
  - Never eat rotten food. Cooking it only halves the risk.
  - Eat the catch while it's fresh, or dry or smoke it. Stale food carries a small risk.
- **Once you have it:**
  - Stay by water: camp at a river or keep plenty of boiled water stored.
  - Boil everything. Tainted water gives the game's own food sickness on top.
  - Rest it out. It's over in a day or two if you keep drinking.
- **Herbs:** Lemongrass for the nausea, chamomile for the cramps (see the stomach bug). Neither touches the thirst, so keep drinking.

---

## Gaps found while writing this

1. ~~Wild herbs did nothing against these illnesses.~~ Fixed 2026-11-04: herbs are now part of the illness relief (see "Herbs" at the top).
2. **No trait changes how long an illness lasts.** Traits change the chance of catching one and how bad the peak is, not the length. If Resilient or Prone to Illness should shorten or lengthen the course, that's a one-line change in `pace()`.
3. **Pneumonia's health drain is unmeasured in game.** `ReduceGeneralHealth` spreads the loss over the body parts, and the game's healing works against it. The real loss per day has to be watched (test P4).
