# Catchable illness and the shared fever

Designed 2026-10-13 (backlog), settled with the user 2026-11-02. Phase 0, phase 1 and the
symptom medicine built 2026-11-02, phase 2 (flu, pneumonia, strep) 2026-11-03; waterborne,
phase 3 and the doctors section are designed, not built.

## Decisions (user, 2026-11-02)

1. **The game's cold is taken over, not replaced.** The game keeps its own wet-and-cold
   accumulator (`catchACold`), its sneezes and coughs (zombies hear them, a tissue
   muffles them) and its cold moodle. We decide when a cold starts (an incubation first),
   how bad it gets and how long it lasts, and set `hasACold` / `coldStrength` from that.
   A cold started by anything else (the game, A Really Bad Day, another mod) is adopted.
2. **The game's food sickness stays.** Spoiled and raw food still turns the stomach at
   once; food poisoning is a delayed illness on top, at its own odds.
3. **Fevers add up, and two together can kill.** The worst fever counts in full, every
   other one at half. Past 1 the fever itself drains health. An illness's fever also
   weakens the body against a wound infection, so a cold or the flu on top of an
   infected wound tips it into sepsis sooner.
4. **Built in phases** (below).
5. **No tetanus.**
6. **Waterborne gut infection waits** for an in-game look at the game's own tainted water.

## Phase 0: one fever (built)

`DanTraits_Fever.lua`. Sources register `DanTraits_FeverSource(name, fn)`; `fn(player, d)`
gives 0..1. Each minute (order 23.2, after Infection, before Age) the fever system:

- composes `total = worst + FEVER_STACK x (sum of the rest)`; `DanTraits_Fever(player)` is
  that, capped at 1, for the readers; `DanTraits_FeverTotal` uncapped;
- is the only writer of the game's `SICKNESS`: `0.2 + 0.7 x min(1, total)` while there is
  a fever, held there up or down, someone else's higher value left alone (the rule
  Infection had);
- brings the fever's tiredness and thirst, for every source;
- past `total` 1, drains health (a dangerous fever), with a notice once.

The nine readers (Sleep, Migraine, Heart, Epilepsy, MS, Hallucinations, Asthma, Diabetes,
Strain) read `DanTraits_Fever`, so an illness's fever does what an infection's did.
`DanTraits_InfectionFever` stays as Infection's own source.

The antibiotic level moved here too (`DanTraits_AntibioticDose`, `DanTraits_AntibioticOn`;
key `infAbx` kept), decaying at order 22.9 so Infection still sees it decayed first. With
wound infection switched off the game's antibiotic still counts for the illnesses (its
own effect left alone).

With only Infection plugged in, nothing a player sees changes.

## Phase 1: the engine and three illnesses (built)

`DanTraits_Illness.lua`, one data table `ILLNESSES`, one engine. Each illness:

- **caught** (hidden, `inc` hours) -> **sick** (a course of `len` hours, severity rising to
  a peak at `peakAt` of the way and easing to nothing) -> **immune** until a world hour.
- the peak is rolled at onset and scaled by the body's resistance then;
- the clock runs faster at rest (asleep x1.3, asleep at home x1.5) and slower exerting
  (x0.8); antibiotics speed a bacterial one (x2.5) and do nothing for a viral one;
- symptoms come from primitives already in the mod: the fever source, the game's food
  sickness (a floor), thirst, a pain floor, tiredness, the game's cold.

**Resistance** (`DanTraits_IllnessResistance`, a multiplier on every chance to catch):
Prone to Illness x1.3, Resilient x0.7, age (20s x0.85, 40s x1.15, 50s x1.35, the
`illness` row of the Age band table), Vitality x(1 - 0.25 e), sleep debt up to x1.3,
hunger up to x1.2, stress up to x1.2, and Smoker x1.15 for the cold.
The sandbox's Illness Frequency multiplies all of it.

| Illness | Kind | Caught by | Hidden | Course | Symptoms at the peak |
|---|---|---|---|---|---|
| Common cold | viral | the game's wet-and-cold meter reaching 90 (instead of the game's 100 and an instant cold), plus a small chance an hour (x2 November to March) | 12-36 h | 3-7 days | the game's cold up to its Nasty level, a low fever only in a bad one, tiredness |
| Stomach bug | viral | eating with dirty or bloody hands (12% a full meal at the filthiest) | 12-48 h | 1-3 days | nausea (food sickness 50), cramps, thirst x3, a low fever |
| Food poisoning | bacterial | rotten food 30%, raw meat or fish 35%, stale 4% a full meal (Iron Gut x0.5, Weak Stomach x1.5) | 6-24 h | 1-2 days | sick (food sickness 70), cramps, thirst x5 (dehydration kills), a fever |

Immunity after: a cold 3-5 weeks, the stomach bug 4-8 weeks; food poisoning none.

**Telling what you have:** a Health section on the health panel by First Aid, as Blood:
0-2 symptoms only ("a runny nose and a cough", "an upset stomach", "feverish");
3-5 a guess ("a cold, by the look of it", "a stomach bug, or something eaten");
6-8 the name, viral or bacterial, the day, worse or easing, the fever to a tenth of a degree;
9-10 how long it has left and what is brewing.

**Sandbox** (page Health): Catchable Illness (master), Illness Frequency (0-300%),
Common Cold, Stomach Bug, Food Poisoning.

**Target** for the tuning pass: a careful player catches about one cold a winter and the
flu now and then; a careless one is ill every couple of weeks.

## Symptom medicine (built 2026-11-02, the user's ask)

Rescue drugs in `DanTraits_Meds.lua`, all on a 1993 shelf, generic names with the active drug on
the tooltip. They ease symptoms, never the course (`DanTraits_IllnessRelief`, the best cover of
each kind):

| Item | Drug | Eases | Cost |
|---|---|---|---|
| Pink Stomach Relief (8 doses) | bismuth subsalicylate | nausea x0.6, cramps x0.6, the runs' thirst x0.7 | too much: queasy, on edge |
| Motion Sickness Tablets (12) | dimenhydrinate | nausea x0.5 | drowsy; dry mouth |
| Promethazine (20, prescription) | promethazine | nausea x0.25 | very drowsy; too many: faint |
| Night-Time Cold and Flu Liquid (6) | acetaminophen, dextromethorphan, doxylamine | the cold shown x0.5, fever reducer | puts you to sleep; too much: the liver |
| Daytime Cold and Flu Capsules (16) | acetaminophen, dextromethorphan, pseudoephedrine | the cold shown x0.6, fever reducer | jittery; too many: the heart |
| DM Cough Syrup (8) | dextromethorphan, guaifenesin | the cold shown x0.5 | too much: dizzy and strange |

Antihistamines ease a cold x0.8. Fever reducers (those two and the game's painkillers) take 40%
off the felt fever but not the danger past 1. Phase 2 adds the flu to what the cold medicines
ease.

Herbs (2026-11-04, the user's ask after the primitive-run write-up in `plans/illness-reference.md`):
the game's own, eaten or as a spice in a hot drink or a dish, for 3 hours (`HERBS`; dried counts
the same). The game's own herb effects were being undone by the illness floors within minutes.

| Herb | Eases |
|---|---|
| Lemongrass | nausea x0.7 |
| Ginger Root / pickled ginger, Mint | nausea x0.8 / x0.85 |
| Chamomile | cramps x0.8 |
| Common Mallow / Thyme | the cold shown x0.8 / x0.9 |
| Honey | the cold and aches x0.9 |
| Black Sage | aches x0.8 (every illness's pain floor: `ache`) |

## Doctors as a needed role (the user's goal, 2026-11-02)

The user wants doctors to be a role a play group needs. What already points that way: the health
panel reads the examiner's First Aid (a doctor sees a patient with their own skill), Blood is
relayed to a doctor in multiplayer, stitching and splinting are First Aid rolls, and the illness
section only names an illness (and so viral or bacterial, so whether antibiotics will help) from
First Aid 6. To build on it:

- **Relay the illness section to a doctor** in multiplayer, as Blood is (`DanTraits_BloodRelay.lua`);
  today it shows on your own panel only.
- **Prescription knowledge:** promethazine, antibiotics and the strong drugs dosed right only by
  someone with First Aid (a wrong dose wastes it or overdoses); a doctor giving them to a patient
  (a timed action on another player) counts the doctor's skill.
- **Treatments only a doctor can do:** IV fluids for a dehydrated patient (food poisoning, the
  stomach bug), draining an abscess, setting and checking breaks, and later the pneumonia and
  flu care of phase 2.
- **Diagnosis aids** (Home Doctor book, thermometer) that help a layperson a little and a doctor
  more.
- All of it waits on the multiplayer sync layer (`plans/multiplayer.md`).

## Phase 2: the dangerous ones (built 2026-11-03, but waterborne)

Three more rows in `ILLNESSES`, and three new things the engine does: `endCap` (endurance held
under 1 - endCap x severity), `health` (a drain from severity `healthFrom` up), `risky` (peak
x1.3 for Asthma, Heart Condition, Smoker, Diabetes and the 50s). `shows`: the cold, the flu and
pneumonia all drive the game's cold, the worst of them, so the coughing is the game's own.

| Illness | Kind | Caught by | Hidden | Course | At the peak |
|---|---|---|---|---|---|
| Flu | viral | 0.03% an hour, November to March only; immune 120-150 days after (the season) | 1-3 days | 5-10 days | fever 0.7, aches (pain 30), endurance under half, coughing |
| Pneumonia | bacterial | while a cold or the flu runs: 0.04% (cold) or 0.1% (flu) an hour x severity, x3 running or sprinting, x2 soaked (wetness 50+), x1.5 chilled (body under 36 C), x1.5 Smoker, x1.5 Asthma | 6-12 h | 10-21 days (4-8 on antibiotics) | fever 0.8, chest pain 25, endurance down to 0.4, health 0.08 a minute at full severity (from 0.7) |
| Strep throat | bacterial | 0.05% an hour while a cold runs, 0.005% otherwise | 1-2 days | 7-10 days (3-4 on antibiotics) | fever 0.4, sore throat (pain 20) |

What kills: the flu at 0.7 with pneumonia at 0.8 stacks to 1.15, a dangerous fever (about
0.3 health a minute), and fever reducers do not stop it. Antibiotics take pneumonia's fever to
0.56 and the stack under 1. So the flu on its own is days in bed; pneumonia on top of it needs
antibiotics within hours.

Still to do from this phase:
- **Waterborne gut infection** (bacterial): after the in-game look at tainted water.
- Diagnosis aids: the Home Doctor book and a thermometer in Dan's Vanilla Fixes.

## Phase 3: catching it from others (designed)

Sick A-Life NPCs, bandits and co-op players nearby add to the hazard; a coughing player
spreads the cold and the flu. Singleplayer first, multiplayer after the sync layer
(`plans/multiplayer.md`).

## Not doing

Tetanus. Vitamins as a cure (they may nudge resistance later).
